(* @abstract(The link between EpubBuilder and the programs that talk to it -
  BookManager (sends books and audio, receives the books made, shows the
  progress and the log) and EpubReader (copies the books made).)

  Owner, 2026-11-20: "Builder should be connectable to by Reader so Reader
  can get local copies of Transcribed epubs", a BookManager drop target
  ("drag a book to it and builder sticks it in books, drag audio -> audio,
  drag folder - send right bits to right locations"), "space-aware ... so
  we don't fill up the users build drive", and TSteamAPI's remote logger
  was "hard to connect to" - so nothing is typed:

  @unorderedList(
    @item(@bold(Found by itself): a builder says where it is every two
      seconds (UDP broadcast, port LINK_DISCOVERY_PORT, a line of JSON);
      @link(TLinkFinder) lists the builders heard.)
    @item(@bold(HTTP) (Indy - works on Linux and in Steam's runtime): the
      builder's @link(TLinkServer) on LINK_HTTP_PORT or the next free
      port; @link(TLinkClient) calls it.)
    @item(@bold(Paired once): a program asks (/pair), the builder shows a
      6-digit code, the program sends it back (/pair/confirm) and gets a
      token, kept on both sides. Every other call but /info needs it
      (header X-Link-Token).)
    @item(@bold(Space): an upload is checked first (/upload/check) and again
      when it starts: it never leaves less than LINK_RESERVE free on the
      drive it goes to.))

  Calls (JSON unless a file):
  @unorderedList(
    @item(GET /info - who it is (no token needed);)
    @item(POST /pair?client=NAME, POST /pair/confirm?client=NAME&code=N;)
    @item(GET /space - the books and audio folders and their free space;)
    @item(GET /books - the books made (the output folders);)
    @item(GET /book?path=P&offset=N - one of them, from byte N;)
    @item(POST /upload/check and POST /upload - a file into Books, Audio
      or Covers (headers X-Link-Kind book / audio / cover, X-Link-Name,
      X-Link-Dir,
      X-Link-Size); written as .part, put in place when whole;)
    @item(GET /status - the progress (what the builder last set);)
    @item(GET /log?from=N - the log lines from N on.)) *)
unit uLink;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.JSON, System.Generics.Collections, IdGlobal,
  IdContext, IdCustomHTTPServer, IdHTTPServer, IdHeaderList, IdUDPServer, IdUDPClient, IdSocketHandle,
  IdHTTP, IdComponent;

const
  { The builders say where they are on this UDP port. }
  LINK_DISCOVERY_PORT = 47820;
  { The builder's HTTP port (or one of the next nine, when taken). }
  LINK_HTTP_PORT = 47821;
  { The link's version (in /info and the announcements). }
  LINK_VERSION = 1;
  { Space an upload never takes: building needs room too (2 GiB). }
  LINK_RESERVE = Int64(2) * 1024 * 1024 * 1024;
  { A builder not heard for this long (s) leaves the finder's list. }
  LINK_GONE_SECONDS = 10;

type
  { A builder heard (TLinkFinder). }
  TLinkPeer = record
    { The builder's own id (it stays when its address changes). }
    Id: string;
    { 'EpubBuilder'. }
    App: string;
    { The machine's name. }
    Name: string;
    { Its address. }
    Host: string;
    { Its HTTP port. }
    Port: Integer;
    { When it was last heard. }
    Seen: TDateTime;
  end;

  { The builders heard. }
  TLinkPeerArray = array of TLinkPeer;

  { The builder shows a pairing code: AClient asked, ACode is the code. }
  TLinkPairCodeEvent = procedure(const AClient, ACode: string) of object;
  { A program was paired: its name and token (to keep). }
  TLinkPairedEvent = procedure(const AClient, AToken: string) of object;
  { A file was received: 'book' or 'audio', and where it is now. }
  TLinkReceivedEvent = procedure(const AKind, AFileName: string) of object;

  { The builder's side: says where it is, answers the calls. Its events
    come on the main thread. }
  TLinkServer = class
  private
    { The HTTP server. }
    FHttp: TIdHTTPServer;
    { Says where the builder is every two seconds. }
    FAnnouncer: TThread;
    { Guards the fields below (the server's threads read them). }
    FLock: TCriticalSection;
    { The builder's id (kept in its settings by the caller). }
    FId: string;
    { 'EpubBuilder'. }
    FApp: string;
    { The machine's name. }
    FName: string;
    { The HTTP port in use (0 = not started). }
    FPort: Integer;
    { The books folder. }
    FBooks: string;
    { The audio folder. }
    FAudio: string;
    { The covers folder (pictures named as a book: its cover). }
    FCovers: string;
    { The folders the books made are in. }
    FOutputs: TArray<string>;
    { The progress, as JSON. }
    FStatus: string;
    { The last log lines. }
    FLog: TStringList;
    { The number of the first line in FLog. }
    FLogBase: Integer;
    { The paired programs: token=name. }
    FTokens: TStringList;
    { The pairing code offered now ('' = none). }
    FPairCode: string;
    { The program it was offered to. }
    FPairClient: string;
    { Until when the code is good. }
    FPairUntil: TDateTime;
    { Wrong codes sent for FPairCode. }
    FPairWrong: Integer;
    { Backing field of OnPairCode. }
    FOnPairCode: TLinkPairCodeEvent;
    { Backing field of OnPaired. }
    FOnPaired: TLinkPairedEvent;
    { Backing field of OnReceived. }
    FOnReceived: TLinkReceivedEvent;
    { Answers a call. }
    procedure CommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
    { An upload's body goes straight into its .part file. }
    procedure CreatePostStream(AContext: TIdContext; AHeaders: TIdHeaderList; var VPostStream: TStream);
    { The token sent is a paired program's. }
    function TokenOk(const AToken: string): Boolean;
    { Checks an upload's headers: the file it goes to ('' and AWhy when it
      may not), its folder and size. }
    function UploadTarget(AHeaders: TIdHeaderList; out AFolder: string; out ASize: Int64;
      out AWhy: string): string;
    { The JSON of /books. }
    function BooksJson: string;
    { The file APath may be sent: an EPUB in an output folder. }
    function MayGet(const APath: string): Boolean;
    { The announcement (a line of JSON). }
    function Announcement: string;
  public
    { Not started yet (Start).
      @param(AApp  'EpubBuilder')
      @param(AName  the machine's name)
      @param(AId  the builder's id, kept between runs) }
    constructor Create(const AApp, AName, AId: string);
    { Stops and frees. }
    destructor Destroy; override;
    { Listens (LINK_HTTP_PORT or the next free one) and says where it is.
      @returns(what was done, for the log) }
    function Start: string;
    { Stops listening and saying. }
    procedure Stop;
    { The folders: books, audio, covers and those the books made are in. }
    procedure SetFolders(const ABooks, AAudio, ACovers: string; const AOutputs: TArray<string>);
    { The progress, as JSON (sent by /status). }
    procedure SetStatus(const AJson: string);
    { A log line (sent by /log). }
    procedure AddLog(const ALine: string);
    { The paired programs, token=name a line (from the settings). }
    procedure SetTokens(const AText: string);
    { The paired programs, token=name a line (to keep). }
    function TokensText: string;
    { The HTTP port in use (0 = not listening). }
    property Port: Integer read FPort;
    { A program asks to pair: show the code. }
    property OnPairCode: TLinkPairCodeEvent read FOnPairCode write FOnPairCode;
    { A program was paired: keep the tokens (TokensText). }
    property OnPaired: TLinkPairedEvent read FOnPaired write FOnPaired;
    { A file was received. }
    property OnReceived: TLinkReceivedEvent read FOnReceived write FOnReceived;
  end;

  { Lists the builders heard on the network (their announcements). Its
    event comes on the main thread. }
  TLinkFinder = class
  private
    { Hears the announcements. }
    FUdp: TIdUDPServer;
    { Guards FPeers. }
    FLock: TCriticalSection;
    { The builders heard. }
    FPeers: TLinkPeerArray;
    { Backing field of OnChange. }
    FOnChange: TNotifyEvent;
    { An announcement came. }
    procedure UdpRead(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
  public
    { Listens at once. }
    constructor Create;
    { Stops and frees. }
    destructor Destroy; override;
    { The builders heard in the last LINK_GONE_SECONDS. }
    function Peers: TLinkPeerArray;
    { A builder came, went or moved (called on the main thread; also call
      Peers now and then: one that stops saying goes quietly). }
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  { Called with the bytes done and the whole (0 = not known). }
  TLinkProgress = reference to procedure(ADone, ATotal: Int64);

  { The other programs' side: calls a builder. Blocking - use it from a
    thread for files. Raises ELinkError with the builder's message. }
  TLinkClient = class
  private
    { The builder's address. }
    FHost: string;
    { Its port. }
    FPort: Integer;
    { The token from pairing ('' = not paired). }
    FToken: string;
    { This program's name, sent when pairing. }
    FClient: string;
    { The progress callback of the transfer running. }
    FProgress: TLinkProgress;
    { The size of the transfer running. }
    FTotal: Int64;
    { The bytes of a download already there (resumed). }
    FOffset: Int64;
    { A new HTTP client with the token. }
    function NewHttp: TIdHTTP;
    { Indy's work event: FProgress. }
    procedure Work(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
    { GET APath: the answer's JSON (raises with the builder's message). }
    function GetJson(const APath: string): TJSONObject;
    { POST APath with no body: the answer's JSON. }
    function PostJson(const APath: string): TJSONObject;
  public
    { A client for the builder at AHost:APort.
      @param(AClient  this program's name, e.g. 'BookManager on PC') }
    constructor Create(const AHost: string; APort: Integer; const AClient, AToken: string);
    { /info: the builder's JSON (the caller frees it). }
    function Info: TJSONObject;
    { Asks to pair: the builder shows a code. }
    procedure PairAsk;
    { Sends the code shown: the token (also kept in Token). }
    function PairConfirm(const ACode: string): string;
    { /space (the caller frees it). }
    function Space: TJSONObject;
    { /books (the caller frees it). }
    function Books: TJSONObject;
    { /status (the caller frees it). }
    function Status: TJSONObject;
    { /log from line AFrom (the caller frees it). }
    function Log(AFrom: Integer): TJSONObject;
    { Downloads the book APath (as /books gives it) to AFileName - going on
      from a .part file of an earlier try. }
    procedure Download(const APath, AFileName: string; const AProgress: TLinkProgress);
    { Sends AFileName as AKind ('book' / 'audio') into the folder ADir of
      its kind ('' = the folder itself). Checked first (/upload/check).
      @returns(where the builder put it) }
    function Upload(const AKind, AFileName, ADir: string; const AProgress: TLinkProgress): string;
    { The token from pairing. }
    property Token: string read FToken;
  end;

  { A link call that did not work, with the builder's reason. }
  ELinkError = class(Exception);

{ The free space of the drive AFolder is on, bytes (-1 = not known). }
function LinkFreeSpace(const AFolder: string): Int64;

{ 'book', 'audio', 'cover' (a picture) or '' for a file name (by its
  extension). }
function LinkKindOf(const AFileName: string): string;

implementation

uses
  {$IFDEF MSWINDOWS} Winapi.Windows, {$ENDIF}
  {$IFDEF POSIX} Posix.SysStatvfs, {$ENDIF}
  System.IOUtils, System.StrUtils, System.DateUtils, System.NetEncoding;

const
  { Book files. }
  BOOK_EXTS: array[0..4] of string = ('.epub', '.mobi', '.prc', '.azw', '.azw3');
  { Audio files. }
  AUDIO_EXTS: array[0..8] of string = ('.m4b', '.m4a', '.aax', '.mp3', '.wav', '.flac', '.ogg', '.opus', '.aac');
  { Pictures (covers). }
  COVER_EXTS: array[0..4] of string = ('.jpg', '.jpeg', '.png', '.webp', '.gif');
  { Log lines kept for /log. }
  LOG_KEEP = 5000;
  { A pairing code is good this long (minutes). }
  PAIR_MINUTES = 5;

type
  { An upload's .part file: where it goes when whole, and how big. }
  TLinkPartStream = class(TFileStream)
  public
    { The .part file. }
    PartName: string;
    { The file it becomes. }
    FinalName: string;
    { 'book' or 'audio'. }
    Kind: string;
    { The size it must reach. }
    Size: Int64;
  end;

  { An upload refused: its body is read and dropped. }
  TLinkRefusedStream = class(TStream)
  public
    { Why. }
    Why: string;
    { Drops the bytes. }
    function Write(const Buffer; Count: Longint): Longint; override;
    { Nothing to read. }
    function Read(var Buffer; Count: Longint): Longint; override;
    { Always 0. }
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

  { Says where the builder is every two seconds. }
  TLinkAnnouncer = class(TThread)
  private
    { Whose announcement. }
    FServer: TLinkServer;
  protected
    { Broadcasts until terminated. }
    procedure Execute; override;
  public
    { For AServer. }
    constructor Create(AServer: TLinkServer);
  end;

function TLinkRefusedStream.Write(const Buffer; Count: Longint): Longint;
begin
  Result := Count;
end;

function TLinkRefusedStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result := 0;
end;

function TLinkRefusedStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  Result := 0;
end;

function LinkFreeSpace(const AFolder: string): Int64;
{$IFDEF MSWINDOWS}
var
  Free, Total: Int64;
begin
  Result := -1;
  if GetDiskFreeSpaceEx(PChar(IncludeTrailingPathDelimiter(AFolder)), Free, Total, nil) then
    Result := Free;
end;
{$ELSE}
{$IFDEF POSIX}
var
  S: _statvfs;
  M: TMarshaller;
begin
  Result := -1;
  if statvfs(MarshaledAString(M.AsAnsi(AFolder, CP_UTF8).ToPointer), S) = 0 then
    Result := Int64(S.f_bavail) * Int64(S.f_frsize);
end;
{$ELSE}
begin
  Result := -1;
end;
{$ENDIF}
{$ENDIF}

function LinkKindOf(const AFileName: string): string;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  if IndexText(Ext, BOOK_EXTS) >= 0 then
    Result := 'book'
  else if IndexText(Ext, AUDIO_EXTS) >= 0 then
    Result := 'audio'
  else if IndexText(Ext, COVER_EXTS) >= 0 then
    Result := 'cover'
  else
    Result := '';
end;

{ A file or folder name made safe: no folders, no '..', no characters
  file systems refuse ('' when nothing is left). }
function SafeName(const AName: string): string;
var
  C: Char;
begin
  Result := '';
  for C in AName do
    if CharInSet(C, ['/', '\', ':', '*', '?', '"', '<', '>', '|']) or (C < ' ') then
      Result := Result + '_'
    else
      Result := Result + C;
  Result := Trim(Result);
  if (Result = '.') or (Result = '..') then
    Result := '';
end;

{ A sub folder path made safe ('a/b' -> 'a' + delimiter + 'b'). }
function SafeDir(const ADir: string): string;
var
  Part, P: string;
begin
  Result := '';
  for Part in ADir.Replace('\', '/').Split(['/']) do
  begin
    P := SafeName(Part);
    if P <> '' then
      Result := IncludeTrailingPathDelimiter(Result) + P;
  end;
  if (Result <> '') and (Result[1] = PathDelim) then
    Delete(Result, 1, 1);
end;

{ The query value AName of a call: Indy's Params, else read from the query
  itself (a POST with no form body may leave Params empty). }
function QueryValue(ARequestInfo: TIdHTTPRequestInfo; const AName: string): string;
var
  Pair: string;
  P: Integer;
begin
  Result := ARequestInfo.Params.Values[AName];
  if Result <> '' then
    Exit;
  for Pair in ARequestInfo.QueryParams.Split(['&']) do
  begin
    P := Pos('=', Pair);
    if (P > 0) and SameText(Copy(Pair, 1, P - 1), AName) then
      Exit(TNetEncoding.URL.Decode(Copy(Pair, P + 1, MaxInt)));
  end;
end;

{ A JSON error. }
procedure SendError(AResponseInfo: TIdHTTPResponseInfo; ACode: Integer; const AText: string);
var
  O: TJSONObject;
begin
  O := TJSONObject.Create;
  try
    O.AddPair('ok', TJSONBool.Create(False));
    O.AddPair('error', AText);
    AResponseInfo.ResponseNo := ACode;
    AResponseInfo.ContentType := 'application/json; charset=utf-8';
    AResponseInfo.ContentText := O.ToJSON;
  finally
    O.Free;
  end;
end;

{ A JSON answer (AJson freed). }
procedure SendJson(AResponseInfo: TIdHTTPResponseInfo; AJson: TJSONObject);
begin
  try
    AResponseInfo.ResponseNo := 200;
    AResponseInfo.ContentType := 'application/json; charset=utf-8';
    AResponseInfo.ContentText := AJson.ToJSON;
  finally
    AJson.Free;
  end;
end;

{ TLinkAnnouncer }

constructor TLinkAnnouncer.Create(AServer: TLinkServer);
begin
  FServer := AServer;
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TLinkAnnouncer.Execute;
var
  Udp: TIdUDPClient;
  I: Integer;
begin
  Udp := TIdUDPClient.Create(nil);
  try
    Udp.BroadcastEnabled := True;
    while not Terminated do
    begin
      try
        Udp.Broadcast(FServer.Announcement, LINK_DISCOVERY_PORT, '255.255.255.255', IndyTextEncoding_UTF8);
      except
        // no network now (asleep, cable out): next time
      end;
      for I := 1 to 20 do
        if not Terminated then
          Sleep(100);
    end;
  finally
    Udp.Free;
  end;
end;

{ TLinkServer }

constructor TLinkServer.Create(const AApp, AName, AId: string);
begin
  inherited Create;
  FApp := AApp;
  FName := AName;
  FId := AId;
  FLock := TCriticalSection.Create;
  FLog := TStringList.Create;
  FTokens := TStringList.Create;
  FStatus := '{"busy":false}';
end;

destructor TLinkServer.Destroy;
begin
  Stop;
  FTokens.Free;
  FLog.Free;
  FLock.Free;
  inherited;
end;

function TLinkServer.Start: string;
var
  P: Integer;
  B: TIdSocketHandle;
begin
  Stop;
  FHttp := TIdHTTPServer.Create(nil);
  FHttp.OnCommandGet := CommandGet;
  FHttp.OnCreatePostStream := CreatePostStream;
  FHttp.ParseParams := True;
  FHttp.KeepAlive := False;
  for P := LINK_HTTP_PORT to LINK_HTTP_PORT + 9 do
  begin
    try
      FHttp.Bindings.Clear;
      B := FHttp.Bindings.Add;
      B.IP := '0.0.0.0';
      B.Port := P;
      B.IPVersion := Id_IPv4;
      FHttp.Active := True;
      FPort := P;
      Break;
    except
      FHttp.Active := False;
    end;
  end;
  if FPort = 0 then
  begin
    FreeAndNil(FHttp);
    Exit(Format('link: no free port from %d to %d - BookManager and EpubReader cannot connect',
      [LINK_HTTP_PORT, LINK_HTTP_PORT + 9]));
  end;
  FAnnouncer := TLinkAnnouncer.Create(Self);
  Result := Format('link: BookManager and EpubReader can connect (port %d; found by itself on the network, ' +
    'UDP %d)', [FPort, LINK_DISCOVERY_PORT]);
end;

procedure TLinkServer.Stop;
begin
  if FAnnouncer <> nil then
  begin
    FAnnouncer.Terminate;
    FAnnouncer.WaitFor;
    FreeAndNil(FAnnouncer);
  end;
  if FHttp <> nil then
  begin
    try
      FHttp.Active := False;
    except
      // stopping anyway
    end;
    FreeAndNil(FHttp);
  end;
  FPort := 0;
end;

function TLinkServer.Announcement: string;
var
  O: TJSONObject;
begin
  O := TJSONObject.Create;
  try
    O.AddPair('link', TJSONNumber.Create(LINK_VERSION));
    O.AddPair('app', FApp);
    O.AddPair('name', FName);
    O.AddPair('id', FId);
    O.AddPair('port', TJSONNumber.Create(FPort));
    Result := O.ToJSON;
  finally
    O.Free;
  end;
end;

procedure TLinkServer.SetFolders(const ABooks, AAudio, ACovers: string; const AOutputs: TArray<string>);
begin
  FLock.Enter;
  try
    FBooks := ABooks;
    FAudio := AAudio;
    FCovers := ACovers;
    FOutputs := Copy(AOutputs);
  finally
    FLock.Leave;
  end;
end;

procedure TLinkServer.SetStatus(const AJson: string);
begin
  FLock.Enter;
  try
    FStatus := AJson;
  finally
    FLock.Leave;
  end;
end;

procedure TLinkServer.AddLog(const ALine: string);
begin
  FLock.Enter;
  try
    FLog.Add(ALine);
    while FLog.Count > LOG_KEEP do
    begin
      FLog.Delete(0);
      Inc(FLogBase);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TLinkServer.SetTokens(const AText: string);
begin
  FLock.Enter;
  try
    FTokens.Text := AText;
  finally
    FLock.Leave;
  end;
end;

function TLinkServer.TokensText: string;
begin
  FLock.Enter;
  try
    Result := FTokens.Text;
  finally
    FLock.Leave;
  end;
end;

function TLinkServer.TokenOk(const AToken: string): Boolean;
begin
  if Length(AToken) < 16 then
    Exit(False);
  FLock.Enter;
  try
    Result := FTokens.IndexOfName(AToken) >= 0;
  finally
    FLock.Leave;
  end;
end;

function TLinkServer.UploadTarget(AHeaders: TIdHeaderList; out AFolder: string; out ASize: Int64;
  out AWhy: string): string;
var
  Kind, Name, Dir, Base, Folder: string;
  Free: Int64;
  N: Integer;
begin
  Result := '';
  AFolder := '';
  ASize := StrToInt64Def(AHeaders.Values['X-Link-Size'], -1);
  AWhy := '';
  if not TokenOk(AHeaders.Values['X-Link-Token']) then
  begin
    AWhy := 'not paired';
    Exit;
  end;
  Kind := LowerCase(AHeaders.Values['X-Link-Kind']);
  Name := SafeName(TNetEncoding.URL.Decode(AHeaders.Values['X-Link-Name']));
  Dir := SafeDir(TNetEncoding.URL.Decode(AHeaders.Values['X-Link-Dir']));
  if Name = '' then
  begin
    AWhy := 'no file name';
    Exit;
  end;
  if ASize < 0 then
  begin
    AWhy := 'no size given';
    Exit;
  end;
  FLock.Enter;
  try
    if Kind = 'book' then
      Base := FBooks
    else if Kind = 'audio' then
      Base := FAudio
    else if Kind = 'cover' then
      Base := FCovers
    else
      Base := '';
  finally
    FLock.Leave;
  end;
  if Base = '' then
  begin
    AWhy := 'not a book, audio or picture file';
    Exit;
  end;
  if LinkKindOf(Name) <> Kind then
  begin
    AWhy := Format('%s is not a %s file', [Name, Kind]);
    Exit;
  end;
  Folder := Base;
  if Dir <> '' then
    Folder := TPath.Combine(Base, Dir);
  ForceDirectories(Folder);
  // never fills the drive the builder works on
  Free := LinkFreeSpace(Folder);
  if (Free >= 0) and (ASize + LINK_RESERVE > Free) then
  begin
    AWhy := Format('not enough space: %s needs %.1f GB, %.1f GB free and %.0f GB kept for building',
      [Name, ASize / 1E9, Free / 1E9, LINK_RESERVE / 1E9]);
    Exit;
  end;
  // the same file there already: kept; another of that name: numbered
  Result := TPath.Combine(Folder, Name);
  N := 1;
  while FileExists(Result) and (TFile.GetSize(Result) <> ASize) do
  begin
    Inc(N);
    Result := TPath.Combine(Folder, Format('%s (%d)%s', [ChangeFileExt(Name, ''), N, ExtractFileExt(Name)]));
  end;
  AFolder := Folder;
end;

procedure TLinkServer.CreatePostStream(AContext: TIdContext; AHeaders: TIdHeaderList; var VPostStream: TStream);
var
  Target, Folder, Why: string;
  Size: Int64;
  S: TLinkPartStream;
  R: TLinkRefusedStream;
begin
  // only an upload's body goes to a file (X-Link-Upload: /upload/check
  // sends the same headers with no body); other calls are small
  if AHeaders.Values['X-Link-Upload'] <> '1' then
    Exit;
  Target := UploadTarget(AHeaders, Folder, Size, Why);
  if Target = '' then
  begin
    R := TLinkRefusedStream.Create;
    R.Why := Why;
    VPostStream := R;
    Exit;
  end;
  try
    S := TLinkPartStream.Create(Target + '.part', fmCreate);
    S.PartName := Target + '.part';
    S.FinalName := Target;
    S.Kind := LowerCase(AHeaders.Values['X-Link-Kind']);
    S.Size := Size;
    VPostStream := S;
  except
    on E: Exception do
    begin
      R := TLinkRefusedStream.Create;
      R.Why := 'cannot write ' + Target + ': ' + E.Message;
      VPostStream := R;
    end;
  end;
end;

function TLinkServer.MayGet(const APath: string): Boolean;
var
  F, Full: string;
begin
  Result := False;
  if not SameText(ExtractFileExt(APath), '.epub') or not FileExists(APath) then
    Exit;
  Full := ExpandFileName(APath);
  FLock.Enter;
  try
    for F in FOutputs do
      if (F <> '') and StartsText(IncludeTrailingPathDelimiter(ExpandFileName(F)), Full) then
        Exit(True);
  finally
    FLock.Leave;
  end;
end;

function TLinkServer.BooksJson: string;
var
  Root: TJSONObject;
  A: TJSONArray;
  O: TJSONObject;
  F, Folder: string;
  Folders: TArray<string>;
  Seen: TStringList;
begin
  FLock.Enter;
  try
    Folders := Copy(FOutputs);
  finally
    FLock.Leave;
  end;
  Root := TJSONObject.Create;
  Seen := TStringList.Create;
  try
    Seen.CaseSensitive := False;
    A := TJSONArray.Create;
    Root.AddPair('books', A);
    for Folder in Folders do
      if (Folder <> '') and TDirectory.Exists(Folder) then
        for F in TDirectory.GetFiles(Folder, '*', TSearchOption.soAllDirectories) do
        begin
          if not SameText(ExtractFileExt(F), '.epub') or (Seen.IndexOf(ExpandFileName(F)) >= 0) then
            Continue;
          Seen.Add(ExpandFileName(F));
          O := TJSONObject.Create;
          O.AddPair('path', F);
          O.AddPair('name', ExtractFileName(F));
          O.AddPair('folder', Folder);
          O.AddPair('size', TJSONNumber.Create(TFile.GetSize(F)));
          O.AddPair('modified', DateToISO8601(TFile.GetLastWriteTime(F), False));
          A.AddElement(O);
        end;
    Result := Root.ToJSON;
  finally
    Seen.Free;
    Root.Free;
  end;
end;

procedure TLinkServer.CommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo);
var
  Doc, Token, Client, Code, Path, Kind, Final: string;
  O, B: TJSONObject;
  A: TJSONArray;
  From, I, Last: Integer;
  Offset, Size: Int64;
  F: TFileStream;
  Part: TLinkPartStream;
  Folder, Why, BooksDir, AudioDir: string;
begin
  Doc := LowerCase(ARequestInfo.Document);
  Token := ARequestInfo.RawHeaders.Values['X-Link-Token'];
  try
    // who it is: no token needed
    if Doc = '/info' then
    begin
      O := TJSONObject.Create;
      O.AddPair('link', TJSONNumber.Create(LINK_VERSION));
      O.AddPair('app', FApp);
      O.AddPair('name', FName);
      O.AddPair('id', FId);
      O.AddPair('paired', TJSONBool.Create(TokenOk(Token)));
      SendJson(AResponseInfo, O);
      Exit;
    end;
    // pairing: the builder shows a code, the program sends it back
    if Doc = '/pair' then
    begin
      Client := Trim(QueryValue(ARequestInfo, 'client'));
      if Client = '' then
        Client := ARequestInfo.RemoteIP;
      FLock.Enter;
      try
        FPairCode := Format('%.6d', [Random(1000000)]);
        FPairClient := Client;
        FPairUntil := IncMinute(Now, PAIR_MINUTES);
        FPairWrong := 0;
        Code := FPairCode;
      finally
        FLock.Leave;
      end;
      if Assigned(FOnPairCode) then
        TThread.Queue(nil,
          procedure
          begin
            if Assigned(FOnPairCode) then
              FOnPairCode(Client, Code);
          end);
      O := TJSONObject.Create;
      O.AddPair('ok', TJSONBool.Create(True));
      O.AddPair('message', 'Type the code EpubBuilder shows');
      SendJson(AResponseInfo, O);
      Exit;
    end;
    if Doc = '/pair/confirm' then
    begin
      Client := Trim(QueryValue(ARequestInfo, 'client'));
      Code := Trim(QueryValue(ARequestInfo, 'code'));
      FLock.Enter;
      try
        if (FPairCode = '') or (Now > FPairUntil) then
        begin
          FPairCode := '';
          Why := 'no code is offered now: ask again';
        end
        else if Code <> FPairCode then
        begin
          Inc(FPairWrong);
          if FPairWrong >= 5 then
            FPairCode := '';
          Why := 'wrong code';
        end
        else
        begin
          Why := '';
          FPairCode := '';
          Token := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').Replace('-', '').ToLower;
          if Client = '' then
            Client := FPairClient;
          FTokens.Add(Token + '=' + Client);
        end;
      finally
        FLock.Leave;
      end;
      if Why <> '' then
      begin
        SendError(AResponseInfo, 403, Why);
        Exit;
      end;
      if Assigned(FOnPaired) then
        TThread.Queue(nil,
          procedure
          begin
            if Assigned(FOnPaired) then
              FOnPaired(Client, Token);
          end);
      O := TJSONObject.Create;
      O.AddPair('ok', TJSONBool.Create(True));
      O.AddPair('token', Token);
      SendJson(AResponseInfo, O);
      Exit;
    end;
    // everything else: paired programs only
    if not TokenOk(Token) then
    begin
      SendError(AResponseInfo, 401, 'not paired - pair with this EpubBuilder first');
      Exit;
    end;
    if Doc = '/space' then
    begin
      FLock.Enter;
      try
        BooksDir := FBooks;
        AudioDir := FAudio;
      finally
        FLock.Leave;
      end;
      O := TJSONObject.Create;
      B := TJSONObject.Create;
      B.AddPair('folder', BooksDir);
      B.AddPair('free', TJSONNumber.Create(LinkFreeSpace(BooksDir)));
      O.AddPair('books', B);
      B := TJSONObject.Create;
      B.AddPair('folder', AudioDir);
      B.AddPair('free', TJSONNumber.Create(LinkFreeSpace(AudioDir)));
      O.AddPair('audio', B);
      O.AddPair('reserve', TJSONNumber.Create(LINK_RESERVE));
      SendJson(AResponseInfo, O);
      Exit;
    end;
    if Doc = '/books' then
    begin
      AResponseInfo.ContentType := 'application/json; charset=utf-8';
      AResponseInfo.ContentText := BooksJson;
      Exit;
    end;
    if Doc = '/book' then
    begin
      Path := QueryValue(ARequestInfo, 'path');
      Offset := StrToInt64Def(QueryValue(ARequestInfo, 'offset'), 0);
      if not MayGet(Path) then
      begin
        SendError(AResponseInfo, 404, 'no such book');
        Exit;
      end;
      F := TFileStream.Create(Path, fmOpenRead or fmShareDenyWrite);
      Size := F.Size;
      if (Offset < 0) or (Offset > Size) then
        Offset := 0;
      F.Position := Offset;
      AResponseInfo.ResponseNo := 200;
      AResponseInfo.ContentType := 'application/epub+zip';
      AResponseInfo.CustomHeaders.Values['X-Link-Size'] := IntToStr(Size);
      AResponseInfo.CustomHeaders.Values['X-Link-Offset'] := IntToStr(Offset);
      AResponseInfo.ContentStream := F;
      AResponseInfo.ContentLength := Size - Offset;
      AResponseInfo.FreeContentStream := True;
      Exit;
    end;
    if Doc = '/upload/check' then
    begin
      Final := UploadTarget(ARequestInfo.RawHeaders, Folder, Size, Why);
      if Final = '' then
      begin
        SendError(AResponseInfo, 507, Why);
        Exit;
      end;
      O := TJSONObject.Create;
      O.AddPair('ok', TJSONBool.Create(True));
      O.AddPair('file', Final);
      O.AddPair('there', TJSONBool.Create(FileExists(Final)));
      SendJson(AResponseInfo, O);
      Exit;
    end;
    if Doc = '/upload' then
    begin
      if ARequestInfo.PostStream is TLinkRefusedStream then
      begin
        SendError(AResponseInfo, 507, TLinkRefusedStream(ARequestInfo.PostStream).Why);
        Exit;
      end;
      if not (ARequestInfo.PostStream is TLinkPartStream) then
      begin
        SendError(AResponseInfo, 400, 'no file sent');
        Exit;
      end;
      Part := TLinkPartStream(ARequestInfo.PostStream);
      Size := Part.Size;
      Final := Part.FinalName;
      Path := Part.PartName;
      Kind := Part.Kind;
      if Part.Seek(0, soEnd) <> Size then
      begin
        ARequestInfo.PostStream := nil;
        Part.Free;
        TFile.Delete(Path);
        SendError(AResponseInfo, 400, 'the file did not arrive whole');
        Exit;
      end;
      ARequestInfo.PostStream := nil;
      Part.Free;
      if FileExists(Final) then
        // the same file (same name and size): the new copy replaces it
        TFile.Delete(Final);
      TFile.Move(Path, Final);
      if Assigned(FOnReceived) then
        TThread.Queue(nil,
          procedure
          begin
            if Assigned(FOnReceived) then
              FOnReceived(Kind, Final);
          end);
      O := TJSONObject.Create;
      O.AddPair('ok', TJSONBool.Create(True));
      O.AddPair('file', Final);
      SendJson(AResponseInfo, O);
      Exit;
    end;
    if Doc = '/status' then
    begin
      FLock.Enter;
      try
        AResponseInfo.ContentText := FStatus;
      finally
        FLock.Leave;
      end;
      AResponseInfo.ContentType := 'application/json; charset=utf-8';
      Exit;
    end;
    if Doc = '/log' then
    begin
      From := StrToIntDef(QueryValue(ARequestInfo, 'from'), 0);
      O := TJSONObject.Create;
      A := TJSONArray.Create;
      FLock.Enter;
      try
        if From < FLogBase then
          From := FLogBase;
        Last := FLogBase + FLog.Count;
        for I := From to Last - 1 do
          A.Add(FLog[I - FLogBase]);
      finally
        FLock.Leave;
      end;
      O.AddPair('from', TJSONNumber.Create(From));
      O.AddPair('next', TJSONNumber.Create(Last));
      O.AddPair('lines', A);
      SendJson(AResponseInfo, O);
      Exit;
    end;
    SendError(AResponseInfo, 404, 'no such call: ' + ARequestInfo.Document);
  except
    on E: Exception do
      SendError(AResponseInfo, 500, E.Message);
  end;
end;

{ TLinkFinder }

constructor TLinkFinder.Create;
var
  B: TIdSocketHandle;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FUdp := TIdUDPServer.Create(nil);
  FUdp.ThreadedEvent := True;
  FUdp.OnUDPRead := UdpRead;
  FUdp.BroadcastEnabled := True;
  B := FUdp.Bindings.Add;
  B.IP := '0.0.0.0';
  B.Port := LINK_DISCOVERY_PORT;
  B.IPVersion := Id_IPv4;
  // the reader and BookManager on one machine both listen
  B.ReuseSocket := rsTrue;
  try
    FUdp.Active := True;
  except
    // the port taken without sharing: nothing is heard (a typed address
    // still works)
  end;
end;

destructor TLinkFinder.Destroy;
begin
  try
    FUdp.Active := False;
  except
    // ending anyway
  end;
  FUdp.Free;
  FLock.Free;
  inherited;
end;

procedure TLinkFinder.UdpRead(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
var
  V: TJSONValue;
  P: TLinkPeer;
  I: Integer;
  Changed: Boolean;
begin
  V := TJSONObject.ParseJSONValue(BytesToString(AData, IndyTextEncoding_UTF8));
  try
    if not (V is TJSONObject) then
      Exit;
    P := Default(TLinkPeer);
    if not TJSONObject(V).TryGetValue<string>('id', P.Id) or (P.Id = '') then
      Exit;
    TJSONObject(V).TryGetValue<string>('app', P.App);
    TJSONObject(V).TryGetValue<string>('name', P.Name);
    TJSONObject(V).TryGetValue<Integer>('port', P.Port);
    P.Host := ABinding.PeerIP;
    P.Seen := Now;
    if P.Port = 0 then
      Exit;
  finally
    V.Free;
  end;
  Changed := True;
  FLock.Enter;
  try
    I := 0;
    while (I <= High(FPeers)) and (FPeers[I].Id <> P.Id) do
      Inc(I);
    if I <= High(FPeers) then
    begin
      // heard before: a change only when it moved
      Changed := (FPeers[I].Host <> P.Host) or (FPeers[I].Port <> P.Port);
      FPeers[I] := P;
    end
    else
      FPeers := FPeers + [P];
  finally
    FLock.Leave;
  end;
  if Changed and Assigned(FOnChange) then
    TThread.Queue(nil,
      procedure
      begin
        if Assigned(FOnChange) then
          FOnChange(Self);
      end);
end;

function TLinkFinder.Peers: TLinkPeerArray;
var
  P: TLinkPeer;
begin
  Result := nil;
  FLock.Enter;
  try
    for P in FPeers do
      if SecondsBetween(Now, P.Seen) <= LINK_GONE_SECONDS then
        Result := Result + [P];
    FPeers := Copy(Result);
  finally
    FLock.Leave;
  end;
end;

{ TLinkClient }

constructor TLinkClient.Create(const AHost: string; APort: Integer; const AClient, AToken: string);
begin
  inherited Create;
  FHost := AHost;
  FPort := APort;
  FClient := AClient;
  FToken := AToken;
end;

function TLinkClient.NewHttp: TIdHTTP;
begin
  Result := TIdHTTP.Create(nil);
  Result.ConnectTimeout := 5000;
  Result.ReadTimeout := 60000;
  Result.Request.CustomHeaders.Values['X-Link-Token'] := FToken;
  Result.OnWork := Work;
end;

procedure TLinkClient.Work(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
begin
  if Assigned(FProgress) then
    FProgress(FOffset + AWorkCount, FTotal);
end;

{ The builder's message from an HTTP error's body. }
function ErrorText(E: EIdHTTPProtocolException): string;
var
  V: TJSONValue;
begin
  Result := E.Message;
  V := TJSONObject.ParseJSONValue(E.ErrorMessage);
  try
    if V is TJSONObject then
      TJSONObject(V).TryGetValue<string>('error', Result);
  finally
    V.Free;
  end;
end;

function TLinkClient.GetJson(const APath: string): TJSONObject;
var
  H: TIdHTTP;
  S: string;
  V: TJSONValue;
  Answer: TStringStream;
begin
  H := NewHttp;
  Answer := TStringStream.Create('', TEncoding.UTF8);
  try
    try
      // into a stream: UTF-8 whatever the answer's header says
      H.Get(Format('http://%s:%d%s', [FHost, FPort, APath]), Answer);
      S := Answer.DataString;
    except
      on E: EIdHTTPProtocolException do
        raise ELinkError.Create(ErrorText(E));
    end;
  finally
    Answer.Free;
    H.Free;
  end;
  V := TJSONObject.ParseJSONValue(S);
  if not (V is TJSONObject) then
  begin
    V.Free;
    raise ELinkError.Create('the builder''s answer is not JSON');
  end;
  Result := TJSONObject(V);
end;

function TLinkClient.PostJson(const APath: string): TJSONObject;
var
  H: TIdHTTP;
  Body, Answer: TStringStream;
  V: TJSONValue;
begin
  H := NewHttp;
  Body := TStringStream.Create('');
  Answer := TStringStream.Create('', TEncoding.UTF8);
  try
    try
      H.Post(Format('http://%s:%d%s', [FHost, FPort, APath]), Body, Answer);
    except
      on E: EIdHTTPProtocolException do
        raise ELinkError.Create(ErrorText(E));
    end;
    V := TJSONObject.ParseJSONValue(Answer.DataString);
  finally
    Answer.Free;
    Body.Free;
    H.Free;
  end;
  if not (V is TJSONObject) then
  begin
    V.Free;
    raise ELinkError.Create('the builder''s answer is not JSON');
  end;
  Result := TJSONObject(V);
end;

function TLinkClient.Info: TJSONObject;
begin
  Result := GetJson('/info');
end;

procedure TLinkClient.PairAsk;
begin
  PostJson('/pair?client=' + TNetEncoding.URL.Encode(FClient)).Free;
end;

function TLinkClient.PairConfirm(const ACode: string): string;
var
  O: TJSONObject;
begin
  O := PostJson('/pair/confirm?client=' + TNetEncoding.URL.Encode(FClient) + '&code=' +
    TNetEncoding.URL.Encode(Trim(ACode)));
  try
    Result := '';
    O.TryGetValue<string>('token', Result);
  finally
    O.Free;
  end;
  if Result = '' then
    raise ELinkError.Create('no token in the builder''s answer');
  FToken := Result;
end;

function TLinkClient.Space: TJSONObject;
begin
  Result := GetJson('/space');
end;

function TLinkClient.Books: TJSONObject;
begin
  Result := GetJson('/books');
end;

function TLinkClient.Status: TJSONObject;
begin
  Result := GetJson('/status');
end;

function TLinkClient.Log(AFrom: Integer): TJSONObject;
begin
  Result := GetJson('/log?from=' + IntToStr(AFrom));
end;

procedure TLinkClient.Download(const APath, AFileName: string; const AProgress: TLinkProgress);
var
  H: TIdHTTP;
  F: TFileStream;
  Part: string;
begin
  Part := AFileName + '.part';
  if FileExists(Part) then
    F := TFileStream.Create(Part, fmOpenReadWrite or fmShareDenyWrite)
  else
    F := TFileStream.Create(Part, fmCreate);
  try
    F.Seek(0, soEnd);
    FOffset := F.Size;
    FProgress := AProgress;
    H := NewHttp;
    try
      try
        H.Get(Format('http://%s:%d/book?path=%s&offset=%d', [FHost, FPort, TNetEncoding.URL.Encode(APath),
          FOffset]), F);
        FTotal := StrToInt64Def(H.Response.RawHeaders.Values['X-Link-Size'], F.Size);
      except
        on E: EIdHTTPProtocolException do
          raise ELinkError.Create(ErrorText(E));
      end;
    finally
      H.Free;
      FProgress := nil;
    end;
    if F.Size <> FTotal then
      raise ELinkError.CreateFmt('%s did not arrive whole (%d of %d bytes) - try again to go on', [APath,
        F.Size, FTotal]);
  finally
    F.Free;
  end;
  if FileExists(AFileName) then
    TFile.Delete(AFileName);
  TFile.Move(Part, AFileName);
end;

function TLinkClient.Upload(const AKind, AFileName, ADir: string; const AProgress: TLinkProgress): string;
var
  H: TIdHTTP;
  F: TFileStream;
  Answer, Empty: TStringStream;
  V: TJSONValue;
  Base: string;

  procedure Headers(AH: TIdHTTP);
  begin
    AH.Request.CustomHeaders.Values['X-Link-Kind'] := AKind;
    AH.Request.CustomHeaders.Values['X-Link-Name'] := TNetEncoding.URL.Encode(ExtractFileName(AFileName));
    AH.Request.CustomHeaders.Values['X-Link-Dir'] := TNetEncoding.URL.Encode(ADir);
    AH.Request.CustomHeaders.Values['X-Link-Size'] := IntToStr(TFile.GetSize(AFileName));
    AH.Request.ContentType := 'application/octet-stream';
  end;

begin
  Base := Format('http://%s:%d', [FHost, FPort]);
  // asked first: no gigabyte sent to be refused
  H := NewHttp;
  Answer := TStringStream.Create('', TEncoding.UTF8);
  Empty := TStringStream.Create('');
  F := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Headers(H);
    try
      H.Post(Base + '/upload/check', Empty, Answer);
    except
      on E: EIdHTTPProtocolException do
        raise ELinkError.Create(ErrorText(E));
    end;
    H.Free;
    H := NewHttp;
    Headers(H);
    H.Request.CustomHeaders.Values['X-Link-Upload'] := '1';
    Answer.Clear;
    FOffset := 0;
    FTotal := F.Size;
    FProgress := AProgress;
    try
      H.Post(Base + '/upload', F, Answer);
    except
      on E: EIdHTTPProtocolException do
        raise ELinkError.Create(ErrorText(E));
    end;
    V := TJSONObject.ParseJSONValue(Answer.DataString);
    try
      Result := '';
      if V is TJSONObject then
        TJSONObject(V).TryGetValue<string>('file', Result);
    finally
      V.Free;
    end;
  finally
    FProgress := nil;
    F.Free;
    Empty.Free;
    Answer.Free;
    H.Free;
  end;
end;

initialization
  Randomize;

end.
