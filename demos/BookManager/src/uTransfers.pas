(* @abstract(BookManager's threads: the transfers (files sent to EpubBuilder,
  books fetched from it, one at a time) and the poll (EpubBuilder's
  progress, log, books made and free space, about once a second).)

  Both call EpubBuilder with uLink's @link(TLinkClient) - a new one per
  call, made from @link(TLinkTargets) (where each builder is and its
  token), so a builder that moved to another address is followed. Their
  events come on the main thread (TThread.Queue); freeing a thread drops
  the events it queued that have not run yet. Freeing one also stops the
  call it is in (TLinkClient.Cancel closes its connection), so the
  program ends at once even when a builder went silent mid-transfer. *)
unit uTransfers;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections, uLink;

type
  { Where a builder is and the token BookManager has for it. }
  TLinkTarget = record
    { Its address. }
    Host: string;
    { Its HTTP port. }
    Port: Integer;
    { The token from pairing ('' = not paired). }
    Token: string;
    { How long a call waits for the connection, ms (0 = uLink's
      LINK_CONNECT_MS; a phone: LINK_CONNECT_PHONE_MS). }
    ConnectTimeout: Integer;
  end;

  { The builders' addresses and tokens, by the builder's id - for the
    threads (thread safe). }
  TLinkTargets = class
  private
    { Guards FItems. }
    FLock: TCriticalSection;
    { The builders, by id. }
    FItems: TDictionary<string, TLinkTarget>;
    { This program's name, sent when pairing. }
    FClientName: string;
  public
    { No builders yet.
      @param(AClientName  this program's name, e.g. 'BookManager on PC') }
    constructor Create(const AClientName: string);
    { Frees. }
    destructor Destroy; override;
    { Where the builder AId is now (its token kept). }
    procedure SetPlace(const AId, AHost: string; APort: Integer);
    { The builder AId's token ('' = not paired). }
    procedure SetToken(const AId, AToken: string);
    { How long calls to AId wait for the connection, ms (a phone:
      LINK_CONNECT_PHONE_MS). }
    procedure SetConnectTimeout(const AId: string; AMs: Integer);
    { The builder AId: False when not known. }
    function Get(const AId: string; out ATarget: TLinkTarget): Boolean;
    { A client for the builder AId (the caller frees it): nil when it is
      not known or not paired. }
    function NewClient(const AId: string): TLinkClient;
    { This program's name, sent when pairing. }
    property ClientName: string read FClientName;
  end;

  { Which way a transfer goes. }
  TTransferWay = (
    { A file sent to the builder. }
    twUpload,
    { A book fetched from the builder. }
    twDownload);

  { One transfer, as the worker gets it. }
  TTransferJob = record
    { Its number (the window's). }
    Id: Integer;
    { Which way. }
    Way: TTransferWay;
    { The builder's id. }
    BuilderId: string;
    { Sent: the file. Fetched: where it goes. }
    FileName: string;
    { Sent: 'book', 'audio' or 'cover'. }
    Kind: string;
    { Sent: the folder under the kind's folder ('' = none). }
    Dir: string;
    { Fetched: the book's path on the builder (as /books gives it). }
    RemotePath: string;
    { Sent: its place in its batch, '2/3' ('' = not said; the phone shows
      it with the progress). }
    Batch: string;
  end;

  { A transfer started. }
  TTransferStartEvent = procedure(AId: Integer) of object;
  { A transfer's progress: bytes done, of ATotal (0 = not known yet). }
  TTransferProgressEvent = procedure(AId: Integer; ADone, ATotal: Int64) of object;
  { A transfer ended: AOk; ASkipped (sent: the builder had that file
    already); AText - where the file is now, or what went wrong. }
  TTransferDoneEvent = procedure(AId: Integer; AOk, ASkipped: Boolean; const AText: string) of object;

  { Does the transfers, one at a time, in the order added. Made
    suspended: set the events, then Start. }
  TTransferWorker = class(TThread)
  private
    { The builders. }
    FTargets: TLinkTargets;
    { Guards FPending and FClient. }
    FLock: TCriticalSection;
    { The transfers waiting. }
    FPending: TList<TTransferJob>;
    { Set when one is added (or to stop). }
    FWake: TEvent;
    { The client of the transfer running (nil = none) - for Cancel. }
    FClient: TLinkClient;
    { The id of the transfer running (0 = none). }
    FRunning: Integer;
    { When the last progress was passed on (ms, TThread.GetTickCount). }
    FLastTick: Cardinal;
    { Backing field of OnStart. }
    FOnStart: TTransferStartEvent;
    { Backing field of OnProgress. }
    FOnProgress: TTransferProgressEvent;
    { Backing field of OnDone. }
    FOnDone: TTransferDoneEvent;
    { Does one transfer. }
    procedure Run(const AJob: TTransferJob);
    { OnStart, on the main thread. }
    procedure SendStart(AId: Integer);
    { OnProgress, on the main thread (at most five times a second, and the
      last). }
    procedure SendProgress(AId: Integer; ADone, ATotal: Int64);
    { OnDone, on the main thread. }
    procedure SendDone(AId: Integer; AOk, ASkipped: Boolean; const AText: string);
  protected
    { Takes the transfers in turn until terminated. }
    procedure Execute; override;
  public
    { Suspended.
      @param(ATargets  the builders (not owned)) }
    constructor Create(ATargets: TLinkTargets);
    { Stops the transfer running (a fetch's .part file stays: the next
      try goes on from it), drops those waiting, waits for the thread. }
    destructor Destroy; override;
    { Adds a transfer at the end. }
    procedure Add(const AJob: TTransferJob);
    { Stops the transfer AId: True when it was waiting (dropped - no OnDone
      comes for it); one running ends with OnDone ('cancelled'). }
    function Cancel(AId: Integer): Boolean;
    { Drops every transfer waiting (no OnDone for them) and stops the one
      running. }
    procedure CancelAll;
    { The id of the transfer running (0 = none). }
    function Running: Integer;
    { A transfer started. }
    property OnStart: TTransferStartEvent read FOnStart write FOnStart;
    { A transfer's progress. }
    property OnProgress: TTransferProgressEvent read FOnProgress write FOnProgress;
    { A transfer ended. }
    property OnDone: TTransferDoneEvent read FOnDone write FOnDone;
  end;

  { What one round of the poll brought. }
  TLinkPollResult = record
    { The round's builder (the window ignores rounds of one it left). }
    BuilderId: string;
    { Which following of it (TLinkPoller.Follow counts them). }
    Generation: Integer;
    { The calls worked. }
    Ok: Boolean;
    { What went wrong ('' when Ok). }
    Error: string;
    { /status: the progress, JSON. }
    Status: string;
    { /log: the lines new since the last round. }
    Lines: TArray<string>;
    { /books: JSON - '' when not asked this round. }
    Books: string;
    { /space: JSON - '' when not asked this round. }
    Space: string;
  end;

  { A round of the poll. }
  TLinkPollEvent = procedure(const AResult: TLinkPollResult) of object;

  { Asks the builder followed for its progress and new log lines about
    once a second, its free space every 10 s and its books made every
    20 s (or at once after WantBooks). A builder that does not answer is
    asked less often (2, 4, 8, 16, then every 30 s) and not at all while
    it is not heard (SetHeard: closed, asleep); Poke asks at once. Made
    suspended: set OnPoll, then Start. }
  TLinkPoller = class(TThread)
  private
    { The builders. }
    FTargets: TLinkTargets;
    { Guards the fields below. }
    FLock: TCriticalSection;
    { The builder followed ('' = none). }
    FBuilderId: string;
    { Counts Follow. }
    FGeneration: Integer;
    { The next log line wanted. }
    FLogNext: Integer;
    { The books are wanted in the next round. }
    FWantBooks: Boolean;
    { The free space is wanted in the next round. }
    FWantSpace: Boolean;
    { When the books were last asked (ms). }
    FBooksTick: Cardinal;
    { When the space was last asked (ms). }
    FSpaceTick: Cardinal;
    { Rounds in a row that got no answer (the pause grows with them). }
    FFailures: Integer;
    { The builder followed is heard on the network (it says where it is
      every two seconds): not heard, it is not asked. }
    FHeard: Boolean;
    { The client of the round running (nil = none) - stopped when the
      thread is freed. }
    FClient: TLinkClient;
    { Set to poll at once (Follow, WantBooks) or to stop. }
    FWake: TEvent;
    { Backing field of OnPoll. }
    FOnPoll: TLinkPollEvent;
    { One round for the builder AId. }
    procedure Round(const AId: string; AGeneration, AFrom: Integer; ABooks, ASpace: Boolean);
    { OnPoll, on the main thread. }
    procedure SendResult(const AResult: TLinkPollResult);
  protected
    { Polls until terminated. }
    procedure Execute; override;
  public
    { Suspended, following no builder.
      @param(ATargets  the builders (not owned)) }
    constructor Create(ATargets: TLinkTargets);
    { Stops the round running and waits for the thread. }
    destructor Destroy; override;
    { Follows the builder AId ('' = none) from its first log line kept;
      polls at once.
      @returns(the generation its rounds carry) }
    function Follow(const AId: string): Integer;
    { The books made, in the next round (at once). }
    procedure WantBooks;
    { Whether the builder followed is heard; heard again: asked at once. }
    procedure SetHeard(AHeard: Boolean);
    { Asks at once, the pause after failures forgotten. }
    procedure Poke;
    { A round. }
    property OnPoll: TLinkPollEvent read FOnPoll write FOnPoll;
  end;

implementation

uses
  System.Math, System.JSON;

const
  { Progress passed on at most this often (ms). }
  PROGRESS_MS = 200;
  { The poll's pause between rounds (ms). }
  POLL_MS = 1000;
  { The free space asked this often (ms). }
  SPACE_MS = 10000;
  { The books made asked this often (ms). }
  BOOKS_MS = 20000;
  { The longest pause after rounds with no answer (ms). }
  BACKOFF_MS = 30000;

{ TLinkTargets }

constructor TLinkTargets.Create(const AClientName: string);
begin
  inherited Create;
  FClientName := AClientName;
  FLock := TCriticalSection.Create;
  FItems := TDictionary<string, TLinkTarget>.Create;
end;

destructor TLinkTargets.Destroy;
begin
  FItems.Free;
  FLock.Free;
  inherited;
end;

procedure TLinkTargets.SetPlace(const AId, AHost: string; APort: Integer);
var
  T: TLinkTarget;
begin
  FLock.Enter;
  try
    if not FItems.TryGetValue(AId, T) then
      T := Default(TLinkTarget);
    T.Host := AHost;
    T.Port := APort;
    FItems.AddOrSetValue(AId, T);
  finally
    FLock.Leave;
  end;
end;

procedure TLinkTargets.SetToken(const AId, AToken: string);
var
  T: TLinkTarget;
begin
  FLock.Enter;
  try
    if not FItems.TryGetValue(AId, T) then
      T := Default(TLinkTarget);
    T.Token := AToken;
    FItems.AddOrSetValue(AId, T);
  finally
    FLock.Leave;
  end;
end;

procedure TLinkTargets.SetConnectTimeout(const AId: string; AMs: Integer);
var
  T: TLinkTarget;
begin
  FLock.Enter;
  try
    if not FItems.TryGetValue(AId, T) then
      T := Default(TLinkTarget);
    T.ConnectTimeout := AMs;
    FItems.AddOrSetValue(AId, T);
  finally
    FLock.Leave;
  end;
end;

function TLinkTargets.Get(const AId: string; out ATarget: TLinkTarget): Boolean;
begin
  FLock.Enter;
  try
    Result := FItems.TryGetValue(AId, ATarget);
  finally
    FLock.Leave;
  end;
end;

function TLinkTargets.NewClient(const AId: string): TLinkClient;
var
  T: TLinkTarget;
begin
  Result := nil;
  if (AId = '') or not Get(AId, T) or (T.Host = '') or (T.Port = 0) or (T.Token = '') then
    Exit;
  Result := TLinkClient.Create(T.Host, T.Port, FClientName, T.Token);
  if T.ConnectTimeout > 0 then
    Result.ConnectTimeout := T.ConnectTimeout;
end;

{ TTransferWorker }

constructor TTransferWorker.Create(ATargets: TLinkTargets);
begin
  FTargets := ATargets;
  FLock := TCriticalSection.Create;
  FPending := TList<TTransferJob>.Create;
  FWake := TEvent.Create(nil, False, False, '');
  inherited Create(True);
end;

destructor TTransferWorker.Destroy;
begin
  Terminate;
  if FLock <> nil then
    CancelAll;
  if FWake <> nil then
    FWake.SetEvent;
  // waits for Execute to end; drops the events queued and not run yet
  inherited;
  FPending.Free;
  FWake.Free;
  FLock.Free;
end;

procedure TTransferWorker.Add(const AJob: TTransferJob);
begin
  FLock.Enter;
  try
    FPending.Add(AJob);
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

function TTransferWorker.Cancel(AId: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  FLock.Enter;
  try
    for I := FPending.Count - 1 downto 0 do
      if FPending[I].Id = AId then
      begin
        FPending.Delete(I);
        Result := True;
      end;
    if (FRunning = AId) and (FClient <> nil) then
      FClient.Cancel;
  finally
    FLock.Leave;
  end;
end;

procedure TTransferWorker.CancelAll;
begin
  FLock.Enter;
  try
    FPending.Clear;
    if FClient <> nil then
      FClient.Cancel;
  finally
    FLock.Leave;
  end;
end;

function TTransferWorker.Running: Integer;
begin
  FLock.Enter;
  try
    Result := FRunning;
  finally
    FLock.Leave;
  end;
end;

procedure TTransferWorker.SendStart(AId: Integer);
begin
  Queue(
    procedure
    begin
      if Assigned(FOnStart) then
        FOnStart(AId);
    end);
end;

procedure TTransferWorker.SendProgress(AId: Integer; ADone, ATotal: Int64);
var
  Tick: Cardinal;
begin
  Tick := TThread.GetTickCount;
  if (Tick - FLastTick < PROGRESS_MS) and ((ATotal <= 0) or (ADone < ATotal)) then
    Exit;
  FLastTick := Tick;
  Queue(
    procedure
    begin
      if Assigned(FOnProgress) then
        FOnProgress(AId, ADone, ATotal);
    end);
end;

procedure TTransferWorker.SendDone(AId: Integer; AOk, ASkipped: Boolean; const AText: string);
var
  Text: string;
begin
  // a copy: the event runs later
  Text := AText;
  Queue(
    procedure
    begin
      if Assigned(FOnDone) then
        FOnDone(AId, AOk, ASkipped, Text);
    end);
end;

procedure TTransferWorker.Execute;
var
  Job: TTransferJob;
  Found: Boolean;
begin
  while not Terminated do
  begin
    Job := Default(TTransferJob);
    Found := False;
    FLock.Enter;
    try
      if FPending.Count > 0 then
      begin
        Job := FPending[0];
        FPending.Delete(0);
        FRunning := Job.Id;
        Found := True;
      end;
    finally
      FLock.Leave;
    end;
    if not Found then
    begin
      FWake.WaitFor(500);
      Continue;
    end;
    try
      Run(Job);
    finally
      FLock.Enter;
      try
        FRunning := 0;
      finally
        FLock.Leave;
      end;
    end;
  end;
end;

procedure TTransferWorker.Run(const AJob: TTransferJob);
var
  Client: TLinkClient;
  Id: Integer;
  Ok, Skipped: Boolean;
  Text: string;
begin
  Id := AJob.Id;
  Client := FTargets.NewClient(AJob.BuilderId);
  if Client = nil then
  begin
    SendDone(Id, False, False, 'not paired with it (or not heard yet)');
    Exit;
  end;
  Client.Batch := AJob.Batch;
  FLock.Enter;
  try
    FClient := Client;
  finally
    FLock.Leave;
  end;
  Ok := False;
  Skipped := False;
  Text := '';
  try
    SendStart(Id);
    FLastTick := 0;
    try
      if AJob.Way = twUpload then
      begin
        Text := Client.Upload(AJob.Kind, AJob.FileName, AJob.Dir, False,
          procedure(ADone, ATotal: Int64)
          begin
            SendProgress(Id, ADone, ATotal);
          end);
        Skipped := Client.Skipped;
      end
      else
      begin
        Client.Download(AJob.RemotePath, AJob.FileName,
          procedure(ADone, ATotal: Int64)
          begin
            SendProgress(Id, ADone, ATotal);
          end);
        Text := AJob.FileName;
      end;
      Ok := True;
    except
      on ELinkCancelled do
        Text := 'cancelled';
      on E: Exception do
        Text := E.Message;
    end;
  finally
    FLock.Enter;
    try
      FClient := nil;
    finally
      FLock.Leave;
    end;
    Client.Free;
  end;
  SendDone(Id, Ok, Skipped, Text);
end;

{ TLinkPoller }

constructor TLinkPoller.Create(ATargets: TLinkTargets);
begin
  FTargets := ATargets;
  FHeard := True;
  FLock := TCriticalSection.Create;
  FWake := TEvent.Create(nil, False, False, '');
  inherited Create(True);
end;

destructor TLinkPoller.Destroy;
begin
  Terminate;
  if FLock <> nil then
  begin
    FLock.Enter;
    try
      if FClient <> nil then
        FClient.Cancel;
    finally
      FLock.Leave;
    end;
  end;
  if FWake <> nil then
    FWake.SetEvent;
  inherited;
  FWake.Free;
  FLock.Free;
end;

function TLinkPoller.Follow(const AId: string): Integer;
begin
  FLock.Enter;
  try
    FBuilderId := AId;
    Inc(FGeneration);
    FLogNext := 0;
    FWantBooks := True;
    FWantSpace := True;
    FFailures := 0;
    FHeard := True;
    Result := FGeneration;
    // the round running is for the builder left: stopped
    if FClient <> nil then
      FClient.Cancel;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

procedure TLinkPoller.WantBooks;
begin
  FLock.Enter;
  try
    FWantBooks := True;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

procedure TLinkPoller.SetHeard(AHeard: Boolean);
var
  Back: Boolean;
begin
  FLock.Enter;
  try
    Back := AHeard and not FHeard;
    FHeard := AHeard;
    if Back then
      FFailures := 0;
  finally
    FLock.Leave;
  end;
  if Back then
    FWake.SetEvent;
end;

procedure TLinkPoller.Poke;
begin
  FLock.Enter;
  try
    FFailures := 0;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

procedure TLinkPoller.SendResult(const AResult: TLinkPollResult);
var
  R: TLinkPollResult;
begin
  // a copy: the event runs later
  R := AResult;
  Queue(
    procedure
    begin
      if Assigned(FOnPoll) then
        FOnPoll(R);
    end);
end;

procedure TLinkPoller.Round(const AId: string; AGeneration, AFrom: Integer; ABooks, ASpace: Boolean);
var
  R: TLinkPollResult;
  Client: TLinkClient;
  O: TJSONObject;
  A: TJSONArray;
  V: TJSONValue;
  Next: Integer;
  Lines: TList<string>;
begin
  R := Default(TLinkPollResult);
  R.BuilderId := AId;
  R.Generation := AGeneration;
  Next := AFrom;
  Client := FTargets.NewClient(AId);
  if Client = nil then
  begin
    R.Error := 'not paired with that EpubBuilder (or not heard yet)';
    SendResult(R);
    Exit;
  end;
  FLock.Enter;
  try
    FClient := Client;
  finally
    FLock.Leave;
  end;
  Lines := TList<string>.Create;
  try
    try
      O := Client.Status;
      try
        R.Status := O.ToJSON;
      finally
        O.Free;
      end;
      O := Client.Log(AFrom);
      try
        O.TryGetValue<Integer>('next', Next);
        A := nil;
        if O.TryGetValue<TJSONArray>('lines', A) and (A <> nil) then
          for V in A do
            Lines.Add(V.Value);
      finally
        O.Free;
      end;
      R.Lines := Lines.ToArray;
      if ASpace then
      begin
        O := Client.Space;
        try
          R.Space := O.ToJSON;
        finally
          O.Free;
        end;
      end;
      if ABooks then
      begin
        O := Client.Books;
        try
          R.Books := O.ToJSON;
        finally
          O.Free;
        end;
      end;
      R.Ok := True;
    except
      on E: Exception do
        R.Error := E.Message;
    end;
  finally
    FLock.Enter;
    try
      FClient := nil;
    finally
      FLock.Leave;
    end;
    Lines.Free;
    Client.Free;
  end;
  FLock.Enter;
  try
    // no answer: the next round waits longer (Execute)
    if AGeneration = FGeneration then
      if R.Ok then
        FFailures := 0
      else
        Inc(FFailures);
  finally
    FLock.Leave;
  end;
  if R.Ok then
  begin
    FLock.Enter;
    try
      // still the same following: the next round goes on from here
      if AGeneration = FGeneration then
      begin
        FLogNext := Next;
        if ABooks then
        begin
          FWantBooks := False;
          FBooksTick := TThread.GetTickCount;
        end;
        if ASpace then
        begin
          FWantSpace := False;
          FSpaceTick := TThread.GetTickCount;
        end;
      end;
    finally
      FLock.Leave;
    end;
  end;
  SendResult(R);
end;

procedure TLinkPoller.Execute;
var
  Id: string;
  Gen, From, Failures: Integer;
  Books, Space, Heard: Boolean;
  Tick, Pause: Cardinal;
begin
  while not Terminated do
  begin
    Tick := TThread.GetTickCount;
    FLock.Enter;
    try
      Id := FBuilderId;
      Gen := FGeneration;
      From := FLogNext;
      Books := FWantBooks or (Tick - FBooksTick >= BOOKS_MS);
      Space := FWantSpace or (Tick - FSpaceTick >= SPACE_MS);
      Heard := FHeard;
    finally
      FLock.Leave;
    end;
    // a builder not heard (closed, asleep) is not asked: SetHeard wakes
    // the thread when it is back
    if (Id <> '') and Heard then
      Round(Id, Gen, From, Books, Space);
    FLock.Enter;
    try
      Failures := FFailures;
    finally
      FLock.Leave;
    end;
    // 1 s; after rounds with no answer 2, 4, 8, 16, then 30 s
    Pause := POLL_MS;
    if Failures > 0 then
    begin
      Pause := Cardinal(POLL_MS) shl Min(Failures, 5);
      if Pause > BACKOFF_MS then
        Pause := BACKOFF_MS;
    end;
    if not Terminated then
      FWake.WaitFor(Pause);
  end;
end;

end.
