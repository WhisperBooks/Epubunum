(* @abstract(The website's leaderboard for EpubBuilder's benchmarks
  (https://leaderboard.epubunum.com): this installation made known once,
  and scores sent.)

  Owner, 2026-11-23: "We can have our own leaderboard as well.
  Submissions can be via POST to a PHP endpoint on the website. As this
  will allow both Steam and non-Steam ..."; asked whether the Steam
  builds send to both boards: "yes send to both"; asked what a user is
  called there: "for now anonymous is fine". The site's side is
  web/leaderboard (its README has the endpoints).

  The site ranks MACHINES. An installation is a random id made here (no
  machine or user name: the privacy rule); the site answers its
  registration with a key, and a score needs both. The caller keeps the
  two in its settings and gives them with every call; WebBoardSubmit's
  answers carry them back when they were made or changed.

  What is sent: at registration the operating system, the processor's
  name and the memory in GB; with a score the benchmark, the time, the
  recording's length, the words and the words matched, the model's file
  name, the device's description, the build and the moment, and - an
  NVIDIA card's only - the power it drew (uGpuPower). No name and
  no Steam id for now.

  WebBoardSubmit works in a thread of its own (one at a time) and answers
  on the main thread, once for each score. Nothing here is needed by the
  program: with no network, or the site away, the answer says so and the
  benchmark's result stands (a Steam program never needs an outside
  site). *)
unit uWebBoard;

interface

uses
  System.SysUtils;

const
  { The site. }
  WEB_BOARD_URL = 'https://leaderboard.epubunum.com';

type
  { A score for the site. }
  TWebBoardScore = record
    { The board: 'benchmark_short_fast' ... (the names of Steam's). }
    Board: string;
    { The transcription's time, ms. }
    ScoreMs: Integer;
    { The chapter material's length, ms. }
    AudioMs: Integer;
    { Its words. }
    Words: Integer;
    { Of them, matched to what was heard. }
    Matched: Integer;
    { The model's file name ('ggml-base.bin'). }
    Model: string;
    { The device's description ('NVIDIA GeForce RTX 5090 Laptop GPU'). }
    Device: string;
    { 'cpu' or 'gpu'. }
    Kind: string;
    { 'CPU', 'Vulkan', 'Metal' ... }
    Backend: string;
    { The program's build stamp. }
    Build: string;
    { 'steam' or 'direct'. }
    Channel: string;
    { When it ran, UTC. }
    RanAt: TDateTime;
    { What the card drew over the run, W: the average (0 = not known -
      uGpuPower reads NVIDIA's cards only). }
    AverageWatts: Integer;
    { The highest reading, W (0 = not known). }
    PeakWatts: Integer;
    { The limit the card was held to, W (0 = not known). }
    LimitWatts: Integer;
  end;

  { What the site said of a score. }
  TWebBoardResult = record
    { The board. }
    Board: string;
    { The site took the score. }
    Ok: Boolean;
    { Why not. }
    Error: string;
    { Taken but not shown until a person has looked (too fast to be
      believed at once). }
    Pending: Boolean;
    { It is this machine's best there. }
    Improved: Boolean;
    { This machine's place on the board (0 = it has no row). }
    Place: Integer;
    { The board's rows. }
    Count: Integer;
    { This machine's best there, ms. }
    BestMs: Integer;
    { The installation's id to keep. }
    InstallId: string;
    { Its key to keep ('' when there is none). }
    Key: string;
  end;

  { A score's answer. }
  TWebBoardEvent = procedure(const AResult: TWebBoardResult) of object;

{ Sends AScores to the site, one after another, registering first when
  AKey is '' (and again, as a new installation, when the site no longer
  knows the id). AOnDone is called on the main thread once for each
  score; AInstallId '' has one made. }
procedure WebBoardSubmit(const AInstallId, AKey: string; const AScores: TArray<TWebBoardScore>;
  AOnDone: TWebBoardEvent);

{ No answer is given from now on (the window closes). }
procedure WebBoardForget;

implementation

uses
  System.Classes, System.JSON, System.SyncObjs, System.Net.HttpClient, System.Net.URLClient,
  uMachine;

const
  { How long the site may take to be reached, and to answer, ms. }
  WEB_BOARD_TIMEOUT = 15000;

type
  { The scores of one call on their way. }
  TWebBoardJob = class(TThread)
  private
    { The installation's id. }
    FInstallId: string;
    { Its key. }
    FKey: string;
    { The scores. }
    FScores: TArray<TWebBoardScore>;
    { Who is told. }
    FOnDone: TWebBoardEvent;
    { POSTs ABody (freed here) to APath of the site.
      @param(AStatus the HTTP status)
      @param(AAnswer the answer's JSON, to be freed - nil when it was
        not JSON)
      Raises when the site was not reached. }
    procedure Post(AClient: THTTPClient; const APath: string; ABody: TJSONObject; out AStatus: Integer;
      out AAnswer: TJSONObject);
    { Makes the installation known: FKey is the site's key.
      @returns('' when it worked, else why not) }
    function Register(AClient: THTTPClient): string;
    { Sends a score.
      @param(AStatus the HTTP status, 0 when the site was not reached)
      @returns(the site's answer) }
    function Send(AClient: THTTPClient; const AScore: TWebBoardScore; out AStatus: Integer): TWebBoardResult;
    { Gives AResult to FOnDone on the main thread. }
    procedure Tell(const AResult: TWebBoardResult);
  protected
    { Registers when needed and sends the scores. }
    procedure Execute; override;
  public
    { A job, started at once and freed when it ends. }
    constructor Create(const AInstallId, AKey: string; const AScores: TArray<TWebBoardScore>;
      AOnDone: TWebBoardEvent);
  end;

var
  { 1 while a job talks to the site (the next waits: two would register
    the same installation twice). }
  GBusy: Integer = 0;
  { The id the last job ended with: a job started before it reached the
    caller's settings uses it. }
  GInstallId: string = '';
  { Its key. }
  GKey: string = '';
  { WebBoardForget was called. }
  GForget: Boolean = False;

{ A new installation id: a random UUID in lower case, without braces. }
function NewInstallId: string;
begin
  Result := LowerCase(TGUID.NewGuid.ToString);
  Result := StringReplace(StringReplace(Result, '{', '', []), '}', '', []);
end;

{ The site's own word for a refusal, or the HTTP status. }
function WhyNot(AAnswer: TJSONObject; AStatus: Integer): string;
begin
  Result := '';
  if AAnswer <> nil then
    Result := AAnswer.GetValue<string>('error', '');
  if Result = '' then
    Result := Format('the site answered %d', [AStatus]);
end;

constructor TWebBoardJob.Create(const AInstallId, AKey: string; const AScores: TArray<TWebBoardScore>;
  AOnDone: TWebBoardEvent);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FInstallId := AInstallId;
  FKey := AKey;
  FScores := Copy(AScores);
  FOnDone := AOnDone;
end;

procedure TWebBoardJob.Post(AClient: THTTPClient; const APath: string; ABody: TJSONObject; out AStatus: Integer;
  out AAnswer: TJSONObject);
var
  Source: TStringStream;
  Resp: IHTTPResponse;
  Value: TJSONValue;
begin
  AStatus := 0;
  AAnswer := nil;
  try
    Source := TStringStream.Create(ABody.ToJSON, TEncoding.UTF8);
  finally
    ABody.Free;
  end;
  try
    Resp := AClient.Post(WEB_BOARD_URL + APath, Source);
  finally
    Source.Free;
  end;
  AStatus := Resp.StatusCode;
  Value := TJSONObject.ParseJSONValue(Resp.ContentAsString(TEncoding.UTF8));
  if Value is TJSONObject then
    AAnswer := TJSONObject(Value)
  else
    Value.Free;
end;

function TWebBoardJob.Register(AClient: THTTPClient): string;
var
  Body, Answer: TJSONObject;
  Status: Integer;
  Cpu: string;
  Memory: UInt64;
begin
  FKey := '';
  Body := TJSONObject.Create;
  Body.AddPair('install_id', FInstallId);
  // what the machine is - never what it is called
  Body.AddPair('os', TOSVersion.ToString);
  Cpu := MachineCpu;
  if Cpu <> '' then
    Body.AddPair('cpu', Cpu);
  Memory := MachineMemory;
  if Memory > 0 then
    Body.AddPair('memory_gb', TJSONNumber.Create(Integer(Round(Memory / (1024.0 * 1024.0 * 1024.0)))));
  try
    Post(AClient, '/api/register.php', Body, Status, Answer);
  except
    on E: Exception do
      Exit('the site was not reached: ' + E.Message);
  end;
  try
    if (Status = 200) and (Answer <> nil) then
      FKey := Answer.GetValue<string>('key', '');
    if FKey <> '' then
      Result := ''
    else
      Result := WhyNot(Answer, Status);
  finally
    Answer.Free;
  end;
end;

function TWebBoardJob.Send(AClient: THTTPClient; const AScore: TWebBoardScore; out AStatus: Integer): TWebBoardResult;
var
  Body, Answer: TJSONObject;
begin
  Result := Default(TWebBoardResult);
  Result.Board := AScore.Board;
  Body := TJSONObject.Create;
  Body.AddPair('install_id', FInstallId);
  Body.AddPair('key', FKey);
  Body.AddPair('benchmark', AScore.Board);
  Body.AddPair('score_ms', TJSONNumber.Create(AScore.ScoreMs));
  Body.AddPair('audio_ms', TJSONNumber.Create(AScore.AudioMs));
  Body.AddPair('words', TJSONNumber.Create(AScore.Words));
  Body.AddPair('words_matched', TJSONNumber.Create(AScore.Matched));
  Body.AddPair('model', AScore.Model);
  Body.AddPair('device', AScore.Device);
  Body.AddPair('device_kind', AScore.Kind);
  Body.AddPair('backend', AScore.Backend);
  Body.AddPair('build', AScore.Build);
  Body.AddPair('channel', AScore.Channel);
  Body.AddPair('ran_at', FormatDateTime('yyyy"-"mm"-"dd hh":"nn":"ss', AScore.RanAt));
  if AScore.AverageWatts > 0 then
    Body.AddPair('avg_watts', TJSONNumber.Create(AScore.AverageWatts));
  if AScore.PeakWatts > 0 then
    Body.AddPair('peak_watts', TJSONNumber.Create(AScore.PeakWatts));
  if AScore.LimitWatts > 0 then
    Body.AddPair('limit_watts', TJSONNumber.Create(AScore.LimitWatts));
  try
    Post(AClient, '/api/submit.php', Body, AStatus, Answer);
  except
    on E: Exception do
    begin
      AStatus := 0;
      Result.Error := 'the site was not reached: ' + E.Message;
      Exit;
    end;
  end;
  try
    if (AStatus = 200) and (Answer <> nil) and Answer.GetValue<Boolean>('ok', False) then
    begin
      Result.Ok := True;
      Result.Pending := SameText(Answer.GetValue<string>('status', ''), 'pending');
      Result.Improved := Answer.GetValue<Boolean>('improved', False);
      Result.Place := Answer.GetValue<Integer>('place', 0);
      Result.Count := Answer.GetValue<Integer>('count', 0);
      Result.BestMs := Answer.GetValue<Integer>('best_ms', 0);
    end
    else
      Result.Error := WhyNot(Answer, AStatus);
  finally
    Answer.Free;
  end;
end;

procedure TWebBoardJob.Tell(const AResult: TWebBoardResult);
var
  Answer: TWebBoardResult;
  Done: TWebBoardEvent;
begin
  Answer := AResult;
  Answer.InstallId := FInstallId;
  Answer.Key := FKey;
  Done := FOnDone;
  TThread.Queue(nil,
    procedure
    begin
      if not GForget and Assigned(Done) then
        Done(Answer);
    end);
end;

procedure TWebBoardJob.Execute;
var
  Client: THTTPClient;
  I, Status: Integer;
  Why: string;
  Answer: TWebBoardResult;
begin
  // one job at a time
  while TInterlocked.CompareExchange(GBusy, 1, 0) <> 0 do
    Sleep(100);
  try
    // what a job before this one was given
    if GInstallId <> '' then
    begin
      FInstallId := GInstallId;
      FKey := GKey;
    end;
    if FInstallId = '' then
    begin
      FInstallId := NewInstallId;
      FKey := '';
    end;
    Why := '';
    Client := nil;
    try
      try
        Client := THTTPClient.Create;
        Client.UserAgent := 'EpubBuilder';
        Client.ContentType := 'application/json';
        Client.ConnectionTimeout := WEB_BOARD_TIMEOUT;
        Client.ResponseTimeout := WEB_BOARD_TIMEOUT;
        if FKey = '' then
          Why := Register(Client);
        for I := 0 to High(FScores) do
        begin
          if GForget then
            Break;
          if Why <> '' then
          begin
            // not registered: nothing can be sent
            Answer := Default(TWebBoardResult);
            Answer.Board := FScores[I].Board;
            Answer.Error := Why;
            Tell(Answer);
            Continue;
          end;
          Answer := Send(Client, FScores[I], Status);
          if Status = 401 then
          begin
            // the site no longer knows this installation: a new one
            FInstallId := NewInstallId;
            Why := Register(Client);
            if Why = '' then
              Answer := Send(Client, FScores[I], Status)
            else
              Answer.Error := Why;
          end;
          Tell(Answer);
        end;
      except
        on E: Exception do
        begin
          // every score is answered (a second answer is ignored by the
          // caller, whose score is no longer on its way)
          Answer := Default(TWebBoardResult);
          Answer.Error := E.Message;
          for I := 0 to High(FScores) do
          begin
            Answer.Board := FScores[I].Board;
            Tell(Answer);
          end;
        end;
      end;
    finally
      Client.Free;
    end;
    GInstallId := FInstallId;
    GKey := FKey;
  finally
    TInterlocked.Exchange(GBusy, 0);
  end;
end;

procedure WebBoardSubmit(const AInstallId, AKey: string; const AScores: TArray<TWebBoardScore>;
  AOnDone: TWebBoardEvent);
var
  Job: TWebBoardJob;
begin
  if Length(AScores) = 0 then
    Exit;
  Job := TWebBoardJob.Create(AInstallId, AKey, AScores, AOnDone);
  Job.Start;
end;

procedure WebBoardForget;
begin
  GForget := True;
end;

end.
