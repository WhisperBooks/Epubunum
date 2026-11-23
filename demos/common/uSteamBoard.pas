(* @abstract(Steam leaderboards for EpubBuilder's benchmarks: a score
  sent, the user's rank and the top rows read.)

  Owner, 2026-11-23: "leaderboards before benchmark mode"; asked where the
  scores are kept, the owner chose Steam's leaderboards (TSteamAPI wraps
  ISteamUserStats). A board ranks Steam users, one row each: a user's
  best score is kept (k_ELeaderboardUploadScoreMethodKeepBest), with up
  to 64 numbers of the program's own beside it (the "details").

  SteamBoardSubmit sends a score and then reads the board; SteamBoardRead
  only reads - a page of rows from the top, or the page with the user's
  own row in its middle. Both answer later, on the main thread, through the event
  given - TSteamAPI delivers Steam's call results from its own timer.
  One request is a chain of Steam calls: the board found (made when a
  score is sent and it is not there yet), the score sent, the user's own
  row, the top rows, and the names of the users in them (Steam may have
  to fetch those: waited for briefly).

  The names are Steam's persona names. They are given to the caller for
  the screen only: nothing here writes a name to a log (the privacy
  rule).

  Built without STEAMBUILD, or with Steam not running, both answer at
  once with Ok False and why. *)
unit uSteamBoard;

interface

uses
  System.SysUtils;

const
  { The most numbers a row can carry beside its score (Steam's limit). }
  STEAM_BOARD_DETAILS_MAX = 64;

type
  { A row of a leaderboard. }
  TSteamBoardRow = record
    { Its place, 1 the best. }
    Rank: Integer;
    { The user's Steam name ('' when Steam does not know it yet). }
    Name: string;
    { The score. }
    Score: Integer;
    { The program's numbers beside the score. }
    Details: TArray<Integer>;
    { It is this user's row. }
    Me: Boolean;
  end;

  { What a request brought. }
  TSteamBoardResult = record
    { The board asked for. }
    Board: string;
    { The board was read. }
    Ok: Boolean;
    { Why not. }
    Error: string;
    { A score was sent and Steam took it. }
    Uploaded: Boolean;
    { The score sent is the user's best so far (Steam kept it). }
    Improved: Boolean;
    { The user's place (0 = no row on this board). }
    Rank: Integer;
    { The user's score on the board (their best). }
    Best: Integer;
    { The program's numbers beside that score. }
    BestDetails: TArray<Integer>;
    { The rows of the board. }
    Count: Integer;
    { The rows read: a page from First on. }
    Rows: TArray<TSteamBoardRow>;
    { The place of the first of Rows. }
    First: Integer;
    { The page around the user was asked for. }
    AskedAround: Boolean;
    { Rows is that page (the user has a row); else the top. }
    Around: Boolean;
  end;

  { A request has ended. }
  TSteamBoardEvent = procedure(const AResult: TSteamBoardResult) of object;

{ Sends AScore to the board ABoard (made if it is not there: lowest score
  first, shown as a time in milliseconds), keeping the user's best, then
  reads the user's row and the top ATop rows.
  @param(ABoard    the board's name in Steamworks)
  @param(AScore    the score: milliseconds)
  @param(ADetails  numbers kept beside it (STEAM_BOARD_DETAILS_MAX at most))
  @param(ATop      how many of the top rows to read (0 = none))
  @param(AOnDone   called once, later (at once when Steam is not there)) }
procedure SteamBoardSubmit(const ABoard: string; AScore: Integer; const ADetails: TArray<Integer>; ATop: Integer;
  AOnDone: TSteamBoardEvent);

{ Reads the user's row and a page of ARows rows of the board ABoard: the
  top ones, or - AAround, and the user has a row - those around the
  user's own. That page is worked out from the user's place and the
  board's size, so it is full whenever the board has ARows rows: near
  the top or the bottom the user is not in its middle.
  @param(ABoard   the board's name in Steamworks)
  @param(ARows    how many rows to read)
  @param(AAround  the page around the user, not the top)
  @param(AOnDone  called once, later (at once when Steam is not there)) }
procedure SteamBoardRead(const ABoard: string; ARows: Integer; AAround: Boolean; AOnDone: TSteamBoardEvent);

{ The requests still running answer nobody (the window is closing). }
procedure SteamBoardsForget;

{ AText as numbers for a row's details: four characters a number, ASCII
  (others become '?'), AMax numbers at most.
  @returns(the numbers) }
function SteamBoardPackText(const AText: string; AMax: Integer): TArray<Integer>;

{ The text SteamBoardPackText made ANumbers from, read from AFirst on.
  @returns(the text) }
function SteamBoardUnpackText(const ANumbers: TArray<Integer>; AFirst: Integer): string;

implementation

uses
  {$IFDEF STEAMBUILD}
  System.StrUtils, System.Math, System.Generics.Collections, FMX.Types,
  Steamworks.Types, Steamworks.SDKTypes, Steamworks.Core, Steamworks.Callbacks, Steamworks.Plugin.User,
  Steamworks.Plugin.UserStats, Steamworks.Plugin.Friends,
  {$ENDIF}
  System.Classes, uDebugLog, uSteam;

function SteamBoardPackText(const AText: string; AMax: Integer): TArray<Integer>;
var
  I, N: Integer;
  C: Cardinal;
  V: Cardinal;
begin
  V := 0;
  N := (Length(AText) + 3) div 4;
  if N > AMax then
    N := AMax;
  SetLength(Result, N);
  for I := 0 to N * 4 - 1 do
  begin
    if I mod 4 = 0 then
      V := 0;
    C := 0;
    if I < Length(AText) then
    begin
      C := Ord(AText[I + 1]);
      if (C < 32) or (C > 126) then
        C := Ord('?');
    end;
    V := V or (C shl (8 * (I mod 4)));
    if I mod 4 = 3 then
      Result[I div 4] := Integer(V);
  end;
end;

function SteamBoardUnpackText(const ANumbers: TArray<Integer>; AFirst: Integer): string;
var
  I, K: Integer;
  C: Cardinal;
begin
  Result := '';
  for I := AFirst to High(ANumbers) do
    for K := 0 to 3 do
    begin
      C := (Cardinal(ANumbers[I]) shr (8 * K)) and $FF;
      // the end of the text; anything unprintable is not ours
      if (C < 32) or (C > 126) then
        Exit(Trim(Result));
      Result := Result + Char(C);
    end;
  Result := Trim(Result);
end;

{$IFDEF STEAMBUILD}
const
  { Names Steam has to fetch are waited for this long, ms. }
  NAMES_WAIT_MS = 1500;

type
  { One request: its chain of Steam calls. Freed after it has answered. }
  TSteamBoardJob = class
  private
    { What it answers with. }
    FRes: TSteamBoardResult;
    { The score to send. }
    FScore: Integer;
    { The numbers beside it. }
    FDetails: TArray<Integer>;
    { A score is sent (else the board is only read). }
    FUpload: Boolean;
    { The rows asked for. }
    FTop: Integer;
    { The page around the user, not the top. }
    FAround: Boolean;
    { Who is answered (nil = nobody). }
    FOnDone: TSteamBoardEvent;
    { The board. }
    FHandle: SteamLeaderboard_t;
    { The users of FRes.Rows. }
    FIds: TArray<TSteamID>;
    { Waits for the names (NAMES_WAIT_MS). }
    FTimer: TTimer;
    { It has answered. }
    FDone: Boolean;
    { ISteamUserStats. }
    function Stats: TSteamUserStatsPlugin;
    { This user. }
    function MyId: TSteamID;
    { Answers Ok False. }
    procedure Fail(const AWhy: string);
    { Answers, and frees the job once the handler it is in has returned. }
    procedure Finish;
    { The board was found (or made). }
    procedure Found(const AData: TSteamCallbackData; AIOFailure: Boolean);
    { The score was sent. }
    procedure Sent(const AData: TSteamCallbackData; AIOFailure: Boolean);
    { The user's own row came. }
    procedure Mine(const AData: TSteamCallbackData; AIOFailure: Boolean);
    { The top rows came. }
    procedure Top(const AData: TSteamCallbackData; AIOFailure: Boolean);
    { Asks for the user's own row. }
    procedure ReadMine;
    { The rows' names, then the answer. }
    procedure Names;
    { FTimer: the names waited for. }
    procedure NamesTimer(Sender: TObject);
  public
    { Takes itself off GJobs and Steam's pending calls. }
    destructor Destroy; override;
    { Starts the chain. }
    procedure Start;
  end;

var
  { The requests running. }
  GJobs: TList<TSteamBoardJob> = nil;

destructor TSteamBoardJob.Destroy;
begin
  FreeAndNil(FTimer);
  if GJobs <> nil then
    GJobs.Remove(Self);
  try
    // its call results still to come are dropped
    if SteamRunning then
      Steam.Dispatcher.RemoveOwner(Self);
  except
    // Steam is going down: nothing left to drop
  end;
  inherited;
end;

function TSteamBoardJob.Stats: TSteamUserStatsPlugin;
begin
  Result := nil;
  if SteamRunning then
    Result := TSteamUserStatsPlugin(Steam.FindPlugin(TSteamUserStatsPlugin));
  if (Result <> nil) and not Result.Active then
    Result := nil;
end;

function TSteamBoardJob.MyId: TSteamID;
var
  U: TSteamUserPlugin;
begin
  Result := TSteamID.Create(0);
  U := TSteamUserPlugin(Steam.FindPlugin(TSteamUserPlugin));
  if (U <> nil) and U.Active then
    Result := U.GetSteamID;
end;

procedure TSteamBoardJob.Fail(const AWhy: string);
begin
  FRes.Ok := False;
  FRes.Error := AWhy;
  DebugLog(Format('leaderboard %s: %s', [FRes.Board, AWhy]));
  Finish;
end;

procedure TSteamBoardJob.Finish;
var
  Done: TSteamBoardEvent;
begin
  if FDone then
    Exit;
  FDone := True;
  Done := FOnDone;
  FOnDone := nil;
  try
    if Assigned(Done) then
      Done(FRes);
  finally
    // not inside Steam's handler: once it has returned
    TThread.ForceQueue(nil,
      procedure
      begin
        Free;
      end);
  end;
end;

procedure TSteamBoardJob.Start;
var
  S: TSteamUserStatsPlugin;
  Call: SteamAPICall_t;
begin
  S := Stats;
  if S = nil then
  begin
    Fail('Steam is not running');
    Exit;
  end;
  try
    // a score makes the board when it is not there yet; reading does not
    if FUpload then
      Call := S.FindOrCreateLeaderboardAsync(FRes.Board, k_ELeaderboardSortMethodAscending,
        k_ELeaderboardDisplayTypeTimeMilliSeconds, Found)
    else
      Call := S.FindLeaderboardAsync(FRes.Board, Found);
    if Call = k_uAPICallInvalid then
      Fail('Steam did not take the request');
  except
    on E: Exception do
      Fail(E.ClassName + ': ' + E.Message);
  end;
end;

procedure TSteamBoardJob.Found(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: LeaderboardFindResult_t;
  S: TSteamUserStatsPlugin;
  P: Pointer;
begin
  if FDone then
    Exit;
  S := Stats;
  if AIOFailure or (AData.Data = nil) or (S = nil) then
  begin
    Fail('Steam did not answer (no connection?)');
    Exit;
  end;
  R := PLeaderboardFindResult_t(AData.Data)^;
  if R.m_bLeaderboardFound = 0 then
  begin
    Fail('the leaderboard is not there yet');
    Exit;
  end;
  FHandle := R.m_hSteamLeaderboard;
  if not FUpload then
  begin
    ReadMine;
    Exit;
  end;
  try
    P := nil;
    if Length(FDetails) > 0 then
      P := @FDetails[0];
    if S.UploadLeaderboardScoreAsync(FHandle, k_ELeaderboardUploadScoreMethodKeepBest, FScore, P, Length(FDetails),
      Sent) = k_uAPICallInvalid then
      Fail('Steam did not take the score');
  except
    on E: Exception do
      Fail(E.ClassName + ': ' + E.Message);
  end;
end;

procedure TSteamBoardJob.Sent(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: LeaderboardScoreUploaded_t;
begin
  if FDone then
    Exit;
  if AIOFailure or (AData.Data = nil) then
  begin
    Fail('the score was not sent (no connection?)');
    Exit;
  end;
  R := PLeaderboardScoreUploaded_t(AData.Data)^;
  if R.m_bSuccess = 0 then
  begin
    Fail('Steam did not accept the score');
    Exit;
  end;
  FRes.Uploaded := True;
  FRes.Improved := R.m_bScoreChanged <> 0;
  DebugLog(Format('leaderboard %s: score %d sent%s', [FRes.Board, FScore, IfThen(FRes.Improved,
    ' - the best so far', ' - an earlier one is better')]));
  ReadMine;
end;

procedure TSteamBoardJob.ReadMine;
var
  S: TSteamUserStatsPlugin;
begin
  S := Stats;
  try
    if (S = nil) or (S.DownloadLeaderboardEntriesAsync(FHandle, k_ELeaderboardDataRequestGlobalAroundUser, 0, 0,
      Mine) = k_uAPICallInvalid) then
      Fail('Steam did not take the request');
  except
    on E: Exception do
      Fail(E.ClassName + ': ' + E.Message);
  end;
end;

procedure TSteamBoardJob.Mine(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: LeaderboardScoresDownloaded_t;
  S: TSteamUserStatsPlugin;
  E: LeaderboardEntry_t;
  Det: array[0..STEAM_BOARD_DETAILS_MAX - 1] of Int32;
  I, K, N: Integer;
  Me: TSteamID;
begin
  if FDone then
    Exit;
  S := Stats;
  if AIOFailure or (AData.Data = nil) or (S = nil) then
  begin
    Fail('Steam did not answer (no connection?)');
    Exit;
  end;
  R := PLeaderboardScoresDownloaded_t(AData.Data)^;
  try
    Me := MyId;
    // every row is read: Steam frees them then
    for I := 0 to R.m_cEntryCount - 1 do
    begin
      FillChar(Det, SizeOf(Det), 0);
      if S.GetDownloadedLeaderboardEntry(R.m_hSteamLeaderboardEntries, I, E, @Det[0], Length(Det)) and
        (E.m_steamIDUser = Me) then
      begin
        FRes.Rank := E.m_nGlobalRank;
        FRes.Best := E.m_nScore;
        N := E.m_cDetails;
        if N > Length(Det) then
          N := Length(Det);
        if N < 0 then
          N := 0;
        SetLength(FRes.BestDetails, N);
        for K := 0 to N - 1 do
          FRes.BestDetails[K] := Det[K];
      end;
    end;
    FRes.Count := S.GetLeaderboardEntryCount(FHandle);
    FRes.Ok := True;
    if FTop <= 0 then
    begin
      Finish;
      Exit;
    end;
    // the page: the top, or the one with the user's row in its middle -
    // moved up or down where the board ends, so that it is full
    FRes.First := 1;
    FRes.Around := FAround and (FRes.Rank > 0);
    if FRes.Around then
      FRes.First := EnsureRange(FRes.Rank - FTop div 2, 1, Max(1, FRes.Count - FTop + 1));
    if S.DownloadLeaderboardEntriesAsync(FHandle, k_ELeaderboardDataRequestGlobal, FRes.First,
      FRes.First + FTop - 1, Top) = k_uAPICallInvalid then
      // the rank is known: answered without the rows
      Finish;
  except
    on X: Exception do
      Fail(X.ClassName + ': ' + X.Message);
  end;
end;

procedure TSteamBoardJob.Top(const AData: TSteamCallbackData; AIOFailure: Boolean);
var
  R: LeaderboardScoresDownloaded_t;
  S: TSteamUserStatsPlugin;
  E: LeaderboardEntry_t;
  Det: array[0..STEAM_BOARD_DETAILS_MAX - 1] of Int32;
  I, K, N: Integer;
  Row: TSteamBoardRow;
  Me: TSteamID;
begin
  if FDone then
    Exit;
  S := Stats;
  if AIOFailure or (AData.Data = nil) or (S = nil) then
  begin
    // the rank is known: answered without the rows
    Finish;
    Exit;
  end;
  R := PLeaderboardScoresDownloaded_t(AData.Data)^;
  try
    Me := MyId;
    for I := 0 to R.m_cEntryCount - 1 do
    begin
      FillChar(Det, SizeOf(Det), 0);
      if not S.GetDownloadedLeaderboardEntry(R.m_hSteamLeaderboardEntries, I, E, @Det[0], Length(Det)) then
        Continue;
      Row := Default(TSteamBoardRow);
      Row.Rank := E.m_nGlobalRank;
      Row.Score := E.m_nScore;
      Row.Me := E.m_steamIDUser = Me;
      N := E.m_cDetails;
      if N > Length(Det) then
        N := Length(Det);
      if N < 0 then
        N := 0;
      SetLength(Row.Details, N);
      for K := 0 to N - 1 do
        Row.Details[K] := Det[K];
      FRes.Rows := FRes.Rows + [Row];
      FIds := FIds + [E.m_steamIDUser];
    end;
  except
    on X: Exception do
      DebugLog(Format('leaderboard %s: rows: %s: %s', [FRes.Board, X.ClassName, X.Message]));
  end;
  Names;
end;

procedure TSteamBoardJob.Names;
var
  F: TSteamFriendsPlugin;
  I: Integer;
  Waiting: Boolean;
begin
  Waiting := False;
  try
    F := TSteamFriendsPlugin(Steam.FindPlugin(TSteamFriendsPlugin));
    if (F <> nil) and F.Active then
      for I := 0 to High(FIds) do
        // True: Steam is fetching the name
        if not FRes.Rows[I].Me and F.RequestUserInformation(FIds[I], True) then
          Waiting := True;
  except
    on X: Exception do
      DebugLog(Format('leaderboard %s: names: %s: %s', [FRes.Board, X.ClassName, X.Message]));
  end;
  if Waiting and (FTimer = nil) then
  begin
    FTimer := TTimer.Create(nil);
    FTimer.Interval := NAMES_WAIT_MS;
    FTimer.OnTimer := NamesTimer;
    FTimer.Enabled := True;
    Exit;
  end;
  NamesTimer(nil);
end;

procedure TSteamBoardJob.NamesTimer(Sender: TObject);
var
  F: TSteamFriendsPlugin;
  I: Integer;
begin
  if FTimer <> nil then
    FTimer.Enabled := False;
  if FDone then
    Exit;
  try
    F := TSteamFriendsPlugin(Steam.FindPlugin(TSteamFriendsPlugin));
    if (F <> nil) and F.Active then
      for I := 0 to High(FIds) do
        if FRes.Rows[I].Me then
          FRes.Rows[I].Name := F.GetPersonaName
        else
          FRes.Rows[I].Name := F.GetFriendPersonaName(FIds[I]);
  except
    on X: Exception do
      DebugLog(Format('leaderboard %s: names: %s: %s', [FRes.Board, X.ClassName, X.Message]));
  end;
  Finish;
end;

{ A request made and started. }
procedure StartJob(const ABoard: string; AUpload: Boolean; AScore: Integer; const ADetails: TArray<Integer>;
  ATop: Integer; AAround: Boolean; AOnDone: TSteamBoardEvent);
var
  J: TSteamBoardJob;
begin
  if GJobs = nil then
    GJobs := TList<TSteamBoardJob>.Create;
  J := TSteamBoardJob.Create;
  GJobs.Add(J);
  J.FRes := Default(TSteamBoardResult);
  J.FRes.Board := ABoard;
  J.FUpload := AUpload;
  J.FScore := AScore;
  J.FDetails := Copy(ADetails, 0, STEAM_BOARD_DETAILS_MAX);
  J.FTop := ATop;
  J.FAround := AAround;
  J.FRes.AskedAround := AAround;
  J.FOnDone := AOnDone;
  J.Start;
end;
{$ENDIF}

{$IFNDEF STEAMBUILD}
{ Answers at once: not a Steam build. }
procedure NoSteam(const ABoard: string; AOnDone: TSteamBoardEvent);
var
  R: TSteamBoardResult;
begin
  R := Default(TSteamBoardResult);
  R.Board := ABoard;
  R.Error := 'not a Steam build';
  if Assigned(AOnDone) then
    AOnDone(R);
end;
{$ENDIF}

procedure SteamBoardSubmit(const ABoard: string; AScore: Integer; const ADetails: TArray<Integer>; ATop: Integer;
  AOnDone: TSteamBoardEvent);
begin
  {$IFDEF STEAMBUILD}
  StartJob(ABoard, True, AScore, ADetails, ATop, False, AOnDone);
  {$ELSE}
  NoSteam(ABoard, AOnDone);
  {$ENDIF}
end;

procedure SteamBoardRead(const ABoard: string; ARows: Integer; AAround: Boolean; AOnDone: TSteamBoardEvent);
begin
  {$IFDEF STEAMBUILD}
  StartJob(ABoard, False, 0, nil, ARows, AAround, AOnDone);
  {$ELSE}
  NoSteam(ABoard, AOnDone);
  {$ENDIF}
end;

procedure SteamBoardsForget;
{$IFDEF STEAMBUILD}
var
  I: Integer;
{$ENDIF}
begin
  {$IFDEF STEAMBUILD}
  if GJobs = nil then
    Exit;
  for I := 0 to GJobs.Count - 1 do
    GJobs[I].FOnDone := nil;
  {$ENDIF}
end;

{$IFDEF STEAMBUILD}
initialization

finalization
  // the jobs left take themselves off the list as they go
  if GJobs <> nil then
  begin
    while GJobs.Count > 0 do
      GJobs[GJobs.Count - 1].Free;
    FreeAndNil(GJobs);
  end;
{$ENDIF}
end.
