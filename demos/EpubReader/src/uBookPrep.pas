(* @abstract(Books prepared in the background - one at a time, in a
  thread - so that even a book's first open takes the fast path.)

  Owner, 2026-11-27 13:53 - 13:59 (zip 390): the books of the library are
  read, indexed and given their chapters in the background, while the
  library is quiet or a book is being read, so that opening one is the
  indexed open (about a second) even the first time - on the Shield, a
  first open was 8 - 19 s from its USB drive.

  This unit knows nothing of books: the reader gives it the job (what
  "prepare" means) and the list of names, in the order wanted. It keeps:

  @unorderedList(
    @item(the LIST of names still to do (SetList replaces it; Remove
      takes one out);)
    @item(the CURRENT job - one at a time, in its own thread - and how far
      it is (0 - 100, told by the job);)
    @item(a QUIET time (Hold): no job starts before it - after the library
      has read its books, after an open;)
    @item(PAUSE / Resume: while a book is being opened no job starts, and
      the current one is asked to stop at its next stage (it is put back
      first in the list, to be done again later);)
    @item(OnDone, in the window's thread, after each job: done, stopped or
      failed.))

  The job is asked to stop only between its stages (AStop): a stage
  already under way (a book's read) runs to its end.

  A job never waits for the window's thread, so closing the program never
  waits for a job: Shutdown asks it to stop and leaves it - the object
  stays (not freed) until the program ends. *)

unit uBookPrep;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections;

type
  { What happened to a job: done (the book is ready), stopped (asked to,
    between stages - back in the list), failed (an exception: not tried
    again this run). }
  TBookPrepOutcome = (bpoDone, bpoStopped, bpoFailed);

  { The job: prepares book AName. AStop: True when it should stop (asked
    between its stages; then it returns False). AProgress: how far it is,
    0 - 100. Raises when the book cannot be prepared.
    @returns(True: prepared; False: stopped) }
  TBookPrepJob = reference to function(const AName: string; const AStop: TFunc<Boolean>;
    const AProgress: TProc<Integer>): Boolean;

  { After a job, in the window's thread: the book, what happened, the
    exception's message (bpoFailed), the time it took (ms). }
  TBookPrepDone = reference to procedure(const AName: string; AOutcome: TBookPrepOutcome; const AMessage: string;
    AMs: UInt64);

  { The background preparation: one worker thread, one book at a time. }
  TBookPrep = class
  private
    { Guards everything below. }
    FLock: TCriticalSection;
    { Wakes the worker (a new list, a resume, shut down). }
    FWake: TEvent;
    { The worker. }
    FThread: TThread;
    { The job. }
    FJob: TBookPrepJob;
    { After each job. }
    FOnDone: TBookPrepDone;
    { The names still to do, the first next. }
    FList: TList<string>;
    { The names that failed this run (not given out again). }
    FFailed: TList<string>;
    { The current job's book ('' = none). }
    FCurrent: string;
    { How far it is, 0 - 100. }
    FProgress: Integer;
    { The current job is asked to stop. }
    FStop: Boolean;
    { No job starts while a book is being opened. }
    FPaused: Boolean;
    { No job starts before this tick (TThread.GetTickCount64). }
    FQuietUntil: UInt64;
    { Shutdown: the worker ends after its job. }
    FClosing: Boolean;
    { The worker's loop. }
    procedure Run;
    { The next name to do, under the lock ('' = none now). }
    function TakeNext: string;
    { Tells OnDone, in the window's thread (its own copies of the values).
      @param(AName  the book)
      @param(AOutcome  what happened)
      @param(AMessage  the exception's message)
      @param(AMs  the time it took) }
    procedure QueueDone(const AName: string; AOutcome: TBookPrepOutcome; const AMessage: string; AMs: UInt64);
    { Current's reader. }
    function GetCurrent: string;
    { Progress's reader. }
    function GetProgress: Integer;
    { Count's reader. }
    function GetCount: Integer;
  public
    { The worker started (it waits for a list).
      @param(AJob  what preparing a book is)
      @param(AOnDone  told after each job, in the window's thread) }
    constructor Create(const AJob: TBookPrepJob; const AOnDone: TBookPrepDone);
    { Not to be called while the worker runs: Shutdown instead. }
    destructor Destroy; override;
    { The names to do, in order (the current job's book and the failed
      ones are left out of it here).
      @param(ANames  the books) }
    procedure SetList(const ANames: TArray<string>);
    { Takes AName out of the list (a book opened the usual way).
      @param(AName  the book) }
    procedure Remove(const AName: string);
    { The books that failed may be tried again with the next list (zip
      392: a streamed book fails while its BookManager is away).
      @param(APrefix  only those whose names begin so) }
    procedure Forgive(const APrefix: string);
    { No job starts for AMs from now (one under way goes on).
      @param(AMs  how long) }
    procedure Hold(AMs: Cardinal);
    { A book is being opened: no job starts, and the current one stops at
      its next stage (and goes back first in the list). }
    procedure Pause;
    { Book AName is being opened - in one step, under the lock: no new job
      starts until Resume; when AName is the current job's book that job
      goes on and the answer is True (the open waits for it); else AName
      leaves the list and the current job stops at its next stage (False).
      @param(AName  the book)
      @returns(AName is the current job's: wait for it) }
    function OpenStarts(const AName: string): Boolean;
    { The open is over: jobs may start again (after Hold's quiet). }
    procedure Resume;
    { The program ends: no more jobs; the current one asked to stop. The
      worker is not waited for - this object is left to the program's
      end (not freed). }
    procedure Shutdown;
    { The current job's book ('' = none). }
    property Current: string read GetCurrent;
    { How far it is, 0 - 100. }
    property Progress: Integer read GetProgress;
    { Books still to do (not counting the current one). }
    property Count: Integer read GetCount;
  end;

implementation

constructor TBookPrep.Create(const AJob: TBookPrepJob; const AOnDone: TBookPrepDone);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FWake := TEvent.Create(nil, False, False, '');
  FList := TList<string>.Create;
  FFailed := TList<string>.Create;
  FJob := AJob;
  FOnDone := AOnDone;
  FThread := TThread.CreateAnonymousThread(Run);
  FThread.FreeOnTerminate := True;
  FThread.Start;
end;

destructor TBookPrep.Destroy;
begin
  FList.Free;
  FFailed.Free;
  FWake.Free;
  FLock.Free;
  inherited;
end;

function TBookPrep.GetCurrent: string;
begin
  FLock.Enter;
  try
    Result := FCurrent;
  finally
    FLock.Leave;
  end;
end;

function TBookPrep.GetProgress: Integer;
begin
  FLock.Enter;
  try
    Result := FProgress;
  finally
    FLock.Leave;
  end;
end;

function TBookPrep.GetCount: Integer;
begin
  FLock.Enter;
  try
    Result := FList.Count;
  finally
    FLock.Leave;
  end;
end;

procedure TBookPrep.SetList(const ANames: TArray<string>);
var
  Name: string;
begin
  FLock.Enter;
  try
    FList.Clear;
    for Name in ANames do
      if (Name <> '') and not SameText(Name, FCurrent) and not FFailed.Contains(Name) and
        not FList.Contains(Name) then
        FList.Add(Name);
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

procedure TBookPrep.Forgive(const APrefix: string);
var
  I: Integer;
begin
  FLock.Enter;
  try
    for I := FFailed.Count - 1 downto 0 do
      if FFailed[I].StartsWith(APrefix, True) then
        FFailed.Delete(I);
  finally
    FLock.Leave;
  end;
end;

procedure TBookPrep.Remove(const AName: string);
begin
  FLock.Enter;
  try
    FList.Remove(AName);
  finally
    FLock.Leave;
  end;
end;

procedure TBookPrep.Hold(AMs: Cardinal);
begin
  FLock.Enter;
  try
    FQuietUntil := TThread.GetTickCount64 + AMs;
  finally
    FLock.Leave;
  end;
end;

procedure TBookPrep.Pause;
begin
  FLock.Enter;
  try
    FPaused := True;
    FStop := FCurrent <> '';
  finally
    FLock.Leave;
  end;
end;

function TBookPrep.OpenStarts(const AName: string): Boolean;
begin
  FLock.Enter;
  try
    // no new job either way until the open is over (Resume)
    FPaused := True;
    Result := (FCurrent <> '') and SameText(FCurrent, AName);
    if Result then
      Exit;
    FList.Remove(AName);
    FStop := FCurrent <> '';
  finally
    FLock.Leave;
  end;
end;

procedure TBookPrep.Resume;
begin
  FLock.Enter;
  try
    FPaused := False;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

procedure TBookPrep.Shutdown;
begin
  FLock.Enter;
  try
    FClosing := True;
    FStop := True;
    FList.Clear;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

function TBookPrep.TakeNext: string;
begin
  Result := '';
  if FClosing or FPaused or (FList.Count = 0) or (TThread.GetTickCount64 < FQuietUntil) then
    Exit;
  Result := FList[0];
  FList.Delete(0);
  FCurrent := Result;
  FProgress := 0;
  FStop := False;
end;

procedure TBookPrep.Run;
var
  Name, Msg: string;
  Outcome: TBookPrepOutcome;
  Start, Took: UInt64;
begin
  while True do
  begin
    // a second at most between looks: the quiet time ends by itself
    FWake.WaitFor(1000);
    FLock.Enter;
    try
      if FClosing then
        Break;
      Name := TakeNext;
    finally
      FLock.Leave;
    end;
    if Name = '' then
      Continue;
    Msg := '';
    // set by every way out below - said so for the compiler (W1036)
    Outcome := bpoFailed;
    Start := TThread.GetTickCount64;
    try
      if FJob(Name,
        function: Boolean
        begin
          FLock.Enter;
          try
            Result := FStop or FClosing;
          finally
            FLock.Leave;
          end;
        end,
        procedure(APercent: Integer)
        begin
          FLock.Enter;
          try
            FProgress := APercent;
          finally
            FLock.Leave;
          end;
        end) then
        Outcome := bpoDone
      else
        Outcome := bpoStopped;
    except
      on E: Exception do
      begin
        Outcome := bpoFailed;
        Msg := E.Message;
      end;
    end;
    Took := TThread.GetTickCount64 - Start;
    FLock.Enter;
    try
      FCurrent := '';
      FProgress := 0;
      case Outcome of
        // stopped: done again later, first
        bpoStopped:
          if not FClosing then
            FList.Insert(0, Name);
        bpoFailed:
          FFailed.Add(Name);
      end;
      if FClosing then
        Break;
    finally
      FLock.Leave;
    end;
    QueueDone(Name, Outcome, Msg, Took);
  end;
end;

procedure TBookPrep.QueueDone(const AName: string; AOutcome: TBookPrepOutcome; const AMessage: string; AMs: UInt64);
var
  Done: TBookPrepDone;
begin
  Done := FOnDone;
  if not Assigned(Done) then
    Exit;
  TThread.Queue(nil,
    procedure
    begin
      Done(AName, AOutcome, AMessage, AMs);
    end);
end;

end.
