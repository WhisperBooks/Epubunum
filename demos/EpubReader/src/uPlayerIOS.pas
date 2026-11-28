(* @abstract(iOS's sound for the reader: @link(TIOSReaderPlayer) is uPlayer's
  TReaderPlayer over AVFoundation's AVPlayer.)

  iPhone and iPad decode a book's audio themselves (AAC in m4b / m4a, MP3),
  so no FFmpeg is shipped there (owner, 2026-11-18).

  AVPlayer is called through objc_msgSend directly, typed as the C function
  each call is, with the objects held as their raw ids - NOT through
  Delphi's Objective-C bridge (TOCGenericImport). On the owner's iPad (zips
  403 - 405) every way of passing AVPlayer's times through Delphi failed
  with an access violation: the bridge's seekToTime:toleranceBefore:
  toleranceAfter: (403), then objc_msgSend typed with CMTime records by
  value and as a result (404, 405: the length came back 0.0 s and the
  seek raised). So here (zip 406) NO record crosses a call by value:
  - a seek passes the three CMTimes as POINTERS to copies - which is what
    the C calling convention of arm64 (AAPCS64) does for a record over 16
    bytes, written out;
  - a time is read with valueForKey: (an NSValue holding the CMTime) and
    getValue:size: (copied into a record here) - pointers only;
  - the player and its item are raw ids, retained and released here.
  Every other argument is a pointer, an integer or a float.

  What AVPlayer does not do, and how it is done here:
  - a PART of a file (the audio stored inside the book): AVPlayer plays a
    file or an address, not bytes M to M + N of a file - so the reader
    serves that part to itself on 127.0.0.1 (a small HTTP server here,
    with byte ranges, which AVPlayer asks for as it seeks); nothing is
    copied out of the book;
  - a book streamed from BookManager: its /slice address, as on Android;
  - opening is not at once (the item gets ready a moment later): a start
    asked for before then waits (Watch starts it when the item is ready);
  - a RANGE (PlayRange): no "stop at" - the place is looked at whenever
    the reader asks for Position or Ended, as on Android;
  - the SPEED: the player's rate, the pitch kept (the item's time-pitch
    algorithm for speech).

  The sound goes on with the screen locked and the switch on silent: the
  audio session's category is playback (spoken audio), and the app's
  Info.plist has the "audio" background mode.

  iOS only: an empty unit elsewhere. Zip 403 (owner 2026-11-27 22:15: "Now
  iOS then tvOS"). Called from the window's thread. *)
unit uPlayerIOS;

interface

{$IFDEF IOS}

uses
  System.SysUtils, System.Classes,
  uPlayer;

type
  { TReaderPlayer played by AVFoundation's AVPlayer. }
  TIOSReaderPlayer = class(TReaderPlayer)
  private
    { The player, a raw id, retained (nil until a file is opened). }
    FPlayer: Pointer;
    { Its item, a raw id, retained. }
    FItem: Pointer;
    { The open file ('' = none). }
    FFileName: string;
    { The file's length, seconds (0 until known). }
    FDuration: Double;
    { The speed asked for. }
    FSpeed: Double;
    { Sound is meant to be heard (between a start and a pause / the end). }
    FPlaying: Boolean;
    { The file, or the range, has been played to its end. }
    FEnded: Boolean;
    { Where PlayRange stops, seconds; < 0 = at the file's end. }
    FRangeEnd: Double;
    { The place last asked for, seconds (< 0 = none). }
    FSeekTarget: Double;
    { A start asked for before the item was ready: from here (< 0 = none). }
    FPendingFrom: Double;
    { When the last start was (GetTickCount). }
    FStartTick: Cardinal;
    { What went wrong while playing. }
    FLastError: string;
    { Why the sound may not be heard ('' = all is well). }
    FSessionNote: string;
    { The server of a book's stored audio on 127.0.0.1 (made on first use). }
    FLoopback: TObject;
    { The ready state was logged for this item. }
    FReadyLogged: Boolean;
    { No file open; the player and its item given back. }
    procedure Forget;
    { Makes the media at the NSURL AUrl (a raw id) the one played.
      @param(AUrl  an NSURL)
      @param(AName  the file, for FileName) }
    procedure OpenAt(AUrl: Pointer; const AName: string);
    { The item is ready to play. }
    function Ready: Boolean;
    { Goes to AFrom and plays, at the speed (when the item is ready; else
      waits for it). }
    procedure StartAt(AFrom: Double);
    { The player's place, seconds - the place asked for while a seek is on
      its way. }
    function Place: Double;
    { Starts a waiting start, ends a range played through, sees the end. }
    procedure Watch;
  protected
    { Getter of Speed. }
    function GetSpeed: Double; override;
    { Setter of Speed. }
    procedure SetSpeed(AValue: Double); override;
  public
    { Makes the object, and sets the app's audio session for playback. }
    constructor Create;
    { Gives the player back. }
    destructor Destroy; override;
    { As TReaderPlayer. }
    procedure Open(const AFileName: string); override;
    { As TReaderPlayer: the part served to the player from 127.0.0.1. }
    function OpenPart(const AFileName: string; AOffset, ASize: Int64): Boolean; override;
    { As TReaderPlayer: AVPlayer streams http itself, asking for ranges. }
    function OpenUrl(const AUrl: string): Boolean; override;
    { As TReaderPlayer. }
    procedure Play(AFrom: Double); override;
    { As TReaderPlayer. }
    procedure PlayRange(AFrom, ATo: Double); override;
    { As TReaderPlayer. }
    procedure Pause; override;
    { As TReaderPlayer. }
    procedure Resume; override;
    { As TReaderPlayer. }
    function Position: Double; override;
    { As TReaderPlayer. }
    function Ended: Boolean; override;
    { As TReaderPlayer. }
    function LastError: string; override;
    { As TReaderPlayer. }
    function FileName: string; override;
    { 'iOS AVPlayer (iOS <version>)'. }
    function Description: string; override;
    { Why the sound may not be heard - the audio session not set. }
    function Note: string; override;
  end;

{$ENDIF}

implementation

{$IFDEF IOS}

uses
  System.SyncObjs, System.Math, Posix.Dlfcn,
  IdHTTPServer, IdContext, IdCustomHTTPServer,
  uDebugLog;

const
  { For this long after a seek or a start, milliseconds, the player may
    still say the old place, or a rate of 0. }
  SETTLE_MS = 400;
  { A place this far from the one asked for, seconds, is the old place. }
  SETTLE_FAR = 0.75;
  { AVPlayerItem.status: ready. }
  ITEM_READY = 1;
  { AVPlayerItem.status: failed. }
  ITEM_FAILED = 2;
  { The ports the stored-audio server may take on 127.0.0.1. }
  LOOP_PORT_FIRST = 47890;
  { ... }
  LOOP_PORT_LAST = 47909;

type
  { A window of a file read as a file of its own: bytes AStart to AStart +
    ALength - 1 (the audio stored in a book). }
  TIOSWindowStream = class(TStream)
  private
    { The file (owned). }
    FFile: TFileStream;
    { The window's first byte in the file. }
    FStart: Int64;
    { Its length. }
    FLength: Int64;
    { The place in the window. }
    FPos: Int64;
  protected
    { The window's length. }
    function GetSize: Int64; override;
  public
    { Opens AFileName read only for its window. }
    constructor Create(const AFileName: string; AStart, ALength: Int64);
    { Frees the file. }
    destructor Destroy; override;
    { Reads within the window. }
    function Read(var Buffer; Count: Longint): Longint; override;
    { Refused: read only. }
    function Write(const Buffer; Count: Longint): Longint; override;
    { Moves within the window. }
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

  { The reader's own little server of a book's stored audio, on 127.0.0.1
    only: one part at a time, under a key the player's address carries. }
  TIOSLoopback = class
  private
    { The server. }
    FServer: TIdHTTPServer;
    { Guards the part. }
    FLock: TCriticalSection;
    { The book. }
    FFile: string;
    { The part's first byte in it. }
    FOffset: Int64;
    { Its length. }
    FSize: Int64;
    { The key ('' = nothing served). }
    FKey: string;
    { Its type ('audio/mp4', 'audio/mpeg'). }
    FMime: string;
    { The port taken. }
    FPort: Integer;
    { A call: the part, or the bytes of it asked for. }
    procedure CommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
  public
    { Starts the server on a free port. }
    constructor Create;
    { Stops it. }
    destructor Destroy; override;
    { Serves ASize bytes at AOffset of AFileName from now on.
      @returns(the address to play) }
    function Serve(const AFileName: string; AOffset, ASize: Int64): string;
  end;


type
  { CoreMedia's CMTime (24 bytes), declared here: a time as value /
    timescale. }
  TCMTime = record
    { The count. }
    Value: Int64;
    { Counts per second. }
    Timescale: Int32;
    { 1 = valid; 4, 8, 16 = +infinity, -infinity, indefinite. }
    Flags: UInt32;
    { (0) }
    Epoch: Int64;
  end;

  { A pointer to one. }
  PCMTime = ^TCMTime;

  { objc_msgSend for: no argument, an id back (or an NSInteger, or a C string). }
  TMsg0 = function(ASelf, ASel: Pointer): Pointer; cdecl;
  { ... one pointer argument, an id back. }
  TMsg1 = function(ASelf, ASel, A1: Pointer): Pointer; cdecl;
  { ... a float argument (setRate:). }
  TMsgSetFloat = procedure(ASelf, ASel: Pointer; AValue: Single); cdecl;
  { ... a float back (rate). }
  TMsgFloat = function(ASelf, ASel: Pointer): Single; cdecl;
  { ... seekToTime:toleranceBefore:toleranceAfter: - each CMTime as a
    pointer to a copy (AAPCS64's way for a record over 16 bytes). }
  TMsgSeek = procedure(ASelf, ASel: Pointer; ATime, ABefore, AAfter: PCMTime); cdecl;
  { ... getValue:size: (NSValue). }
  TMsgGetValue = procedure(ASelf, ASel, ABuffer: Pointer; ASize: NativeUInt); cdecl;
  { ... setCategory:mode:options:error: (a BOOL back). }
  TMsgCategory = function(ASelf, ASel, ACategory, AMode: Pointer; AOptions: NativeUInt; AError: Pointer): Byte;
    cdecl;
  { ... setActive:error: (a BOOL back). }
  TMsgActive = function(ASelf, ASel: Pointer; AActive: Byte; AError: Pointer): Byte; cdecl;
  { sel_registerName / objc_getClass. }
  TNameLookup = function(AName: MarshaledAString): Pointer; cdecl;

var
  { objc_msgSend (nil: not found - the calls raise). }
  GMsgSend: Pointer;
  { sel_registerName. }
  GSelRegister: TNameLookup;
  { objc_getClass. }
  GGetClass: TNameLookup;

{ objc_msgSend, sel_registerName and objc_getClass, found once. }
procedure FindRuntime;
var
  Lib: NativeUInt;
begin
  if GMsgSend <> nil then
    Exit;
  Lib := dlopen(MarshaledAString(UTF8String('/usr/lib/libobjc.A.dylib')), RTLD_LAZY);
  if Lib = 0 then
    raise Exception.Create('the Objective-C runtime not found');
  @GSelRegister := dlsym(Lib, MarshaledAString(UTF8String('sel_registerName')));
  @GGetClass := dlsym(Lib, MarshaledAString(UTF8String('objc_getClass')));
  if not Assigned(GSelRegister) or not Assigned(GGetClass) then
    raise Exception.Create('the Objective-C runtime''s functions not found');
  GMsgSend := dlsym(Lib, MarshaledAString(UTF8String('objc_msgSend')));
  if GMsgSend = nil then
    raise Exception.Create('objc_msgSend not found');
end;

{ The selector ANAME. }
function Sel(const AName: string): Pointer;
begin
  FindRuntime;
  Result := GSelRegister(MarshaledAString(UTF8String(AName)));
end;

{ The class ANAME (raises when there is none). }
function ClassOf(const AName: string): Pointer;
begin
  FindRuntime;
  Result := GGetClass(MarshaledAString(UTF8String(AName)));
  if Result = nil then
    raise Exception.Create('no class ' + AName);
end;

{ [AObject AName] - an id (or an integer) back. }
function Send0(AObject: Pointer; const AName: string): Pointer;
begin
  if AObject = nil then
    raise Exception.Create('no object for ' + AName);
  Result := TMsg0(GMsgSend)(AObject, Sel(AName));
end;

{ [AObject AName A1] - an id back. }
function Send1(AObject: Pointer; const AName: string; A1: Pointer): Pointer;
begin
  if AObject = nil then
    raise Exception.Create('no object for ' + AName);
  Result := TMsg1(GMsgSend)(AObject, Sel(AName), A1);
end;

{ An NSString of AText (autoreleased). }
function NSText(const AText: string): Pointer;
begin
  Result := Send1(ClassOf('NSString'), 'stringWithUTF8String:', MarshaledAString(UTF8String(AText)));
end;

{ The text of the NSString AString ('' for nil). }
function TextOf(AString: Pointer): string;
var
  P: MarshaledAString;
begin
  Result := '';
  if AString = nil then
    Exit;
  P := MarshaledAString(Send0(AString, 'UTF8String'));
  if P <> nil then
    Result := UTF8ToString(P);
end;

{ A CMTime of ASeconds (milliseconds kept). }
function SecondsTime(ASeconds: Double): TCMTime;
begin
  Result.Value := Round(ASeconds * 1000);
  Result.Timescale := 1000;
  // kCMTimeFlags_Valid
  Result.Flags := 1;
  Result.Epoch := 0;
end;

{ A CMTime's seconds (0 when it is not a number of seconds: not valid,
  indefinite, infinite). }
function TimeSeconds(const ATime: TCMTime): Double;
begin
  if ((ATime.Flags and 1) = 0) or ((ATime.Flags and $1C) <> 0) or (ATime.Timescale = 0) then
    Result := 0
  else
    Result := ATime.Value / ATime.Timescale;
end;

{ The CMTime AObject gives for the key AKey (currentTime, duration): an
  NSValue from valueForKey:, copied out with getValue:size:. }
function TimeOf(AObject: Pointer; const AKey: string): TCMTime;
var
  Box: Pointer;
begin
  Result := Default(TCMTime);
  Box := Send1(AObject, 'valueForKey:', NSText(AKey));
  if Box = nil then
    Exit;
  TMsgGetValue(GMsgSend)(Box, Sel('getValue:size:'), @Result, SizeOf(Result));
end;

{ The player AObject goes to ASeconds exactly (zero tolerances). }
procedure SeekTo(AObject: Pointer; ASeconds: Double);
var
  T, Before, After: TCMTime;
begin
  if AObject = nil then
    raise Exception.Create('no player to seek');
  T := SecondsTime(ASeconds);
  Before := SecondsTime(0);
  After := SecondsTime(0);
  TMsgSeek(GMsgSend)(AObject, Sel('seekToTime:toleranceBefore:toleranceAfter:'), @T, @Before, @After);
end;

{ The player AObject plays at ARate (0 stops). }
procedure SetRate(AObject: Pointer; ARate: Single);
begin
  if AObject = nil then
    raise Exception.Create('no player');
  TMsgSetFloat(GMsgSend)(AObject, Sel('setRate:'), ARate);
end;

{ The player AObject's rate (0: stopped). }
function RateOf(AObject: Pointer): Single;
begin
  if AObject = nil then
    raise Exception.Create('no player');
  Result := TMsgFloat(GMsgSend)(AObject, Sel('rate'));
end;

{ What the item AItem's error says. }
function ErrorText(AItem: Pointer): string;
begin
  Result := 'the audio could not be played';
  try
    Result := Result + ' - ' + TextOf(Send0(Send0(AItem, 'error'), 'localizedDescription'));
  except
    // the words alone
  end;
end;

{ TIOSWindowStream }

constructor TIOSWindowStream.Create(const AFileName: string; AStart, ALength: Int64);
begin
  inherited Create;
  FFile := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  FStart := AStart;
  FLength := ALength;
end;

destructor TIOSWindowStream.Destroy;
begin
  FFile.Free;
  inherited;
end;

function TIOSWindowStream.GetSize: Int64;
begin
  Result := FLength;
end;

function TIOSWindowStream.Read(var Buffer; Count: Longint): Longint;
var
  Left: Int64;
begin
  Result := 0;
  Left := FLength - FPos;
  if (Count <= 0) or (Left <= 0) then
    Exit;
  if Count > Left then
    Count := Longint(Left);
  FFile.Position := FStart + FPos;
  Result := FFile.Read(Buffer, Count);
  if Result > 0 then
    Inc(FPos, Result);
end;

function TIOSWindowStream.Write(const Buffer; Count: Longint): Longint;
begin
  raise EStreamError.Create('the book''s audio is read only');
end;

function TIOSWindowStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning:
      FPos := Offset;
    soCurrent:
      FPos := FPos + Offset;
    soEnd:
      FPos := FLength + Offset;
  end;
  if FPos < 0 then
    FPos := 0;
  if FPos > FLength then
    FPos := FLength;
  Result := FPos;
end;

{ TIOSLoopback }

constructor TIOSLoopback.Create;
var
  P: Integer;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FServer := TIdHTTPServer.Create(nil);
  FServer.OnCommandGet := CommandGet;
  FServer.KeepAlive := True;
  for P := LOOP_PORT_FIRST to LOOP_PORT_LAST do
    try
      FServer.Bindings.Clear;
      with FServer.Bindings.Add do
      begin
        IP := '127.0.0.1';
        Port := P;
      end;
      FServer.Active := True;
      FPort := P;
      Break;
    except
      // taken: the next
      FServer.Active := False;
    end;
  if FPort = 0 then
    raise Exception.Create('no port free on 127.0.0.1 for the book''s audio');
  DebugLog(Format('sound: the books'' stored audio served to the player on 127.0.0.1:%d', [FPort]));
end;

destructor TIOSLoopback.Destroy;
begin
  try
    FServer.Active := False;
  except
    // closing
  end;
  FServer.Free;
  FLock.Free;
  inherited;
end;

function TIOSLoopback.Serve(const AFileName: string; AOffset, ASize: Int64): string;
var
  F: TFileStream;
  H: TBytes;
  Ext: string;
begin
  // its type from its first bytes: an MP4 says "ftyp" at 4, an MP3 starts
  // with "ID3" or a frame's sync
  FMime := 'audio/mp4';
  Ext := '.m4a';
  SetLength(H, 12);
  F := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    F.Position := AOffset;
    if F.Read(H[0], 12) = 12 then
      if (H[0] = Ord('I')) and (H[1] = Ord('D')) and (H[2] = Ord('3')) or ((H[0] = $FF) and ((H[1] and $E0) = $E0))
      then
      begin
        FMime := 'audio/mpeg';
        Ext := '.mp3';
      end;
  finally
    F.Free;
  end;
  FLock.Enter;
  try
    FFile := AFileName;
    FOffset := AOffset;
    FSize := ASize;
    FKey := IntToHex(Random(MaxInt), 8) + IntToHex(Random(MaxInt), 8);
    Result := Format('http://127.0.0.1:%d/audio%s?k=%s', [FPort, Ext, FKey]);
  finally
    FLock.Leave;
  end;
end;

procedure TIOSLoopback.CommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo);
var
  Book, Key, Mime, Range, A, B: string;
  Offset, Size, First, Last: Int64;
  P: Integer;
  Partial: Boolean;
begin
  FLock.Enter;
  try
    Book := FFile;
    Offset := FOffset;
    Size := FSize;
    Key := FKey;
    Mime := FMime;
  finally
    FLock.Leave;
  end;
  if (Key = '') or (ARequestInfo.Params.Values['k'] <> Key) then
  begin
    AResponseInfo.ResponseNo := 404;
    Exit;
  end;
  First := 0;
  Last := Size - 1;
  Partial := False;
  // one range, "bytes=A-B", "bytes=A-" or "bytes=-N" (a player asks so)
  Range := Trim(ARequestInfo.RawHeaders.Values['Range']);
  if Range.StartsWith('bytes=', True) then
  begin
    Range := Trim(Copy(Range, 7, MaxInt));
    P := Pos(',', Range);
    if P > 0 then
      Range := Copy(Range, 1, P - 1);
    P := Pos('-', Range);
    if P > 0 then
    begin
      A := Trim(Copy(Range, 1, P - 1));
      B := Trim(Copy(Range, P + 1, MaxInt));
      if A = '' then
        First := Max(0, Size - StrToInt64Def(B, 0))
      else
      begin
        First := StrToInt64Def(A, -1);
        if B <> '' then
          Last := Min(Size - 1, StrToInt64Def(B, -1));
      end;
      Partial := True;
    end;
  end;
  AResponseInfo.CustomHeaders.Values['Accept-Ranges'] := 'bytes';
  if (First < 0) or (First > Last) then
  begin
    AResponseInfo.ResponseNo := 416;
    AResponseInfo.CustomHeaders.Values['Content-Range'] := Format('bytes */%d', [Size]);
    Exit;
  end;
  AResponseInfo.ContentType := Mime;
  if Partial then
  begin
    AResponseInfo.ResponseNo := 206;
    AResponseInfo.CustomHeaders.Values['Content-Range'] := Format('bytes %d-%d/%d', [First, Last, Size]);
  end
  else
    AResponseInfo.ResponseNo := 200;
  AResponseInfo.ContentLength := Last - First + 1;
  // (HEAD: the headers only)
  if not SameText(ARequestInfo.Command, 'HEAD') then
  begin
    AResponseInfo.ContentStream := TIOSWindowStream.Create(Book, Offset + First, Last - First + 1);
    AResponseInfo.FreeContentStream := True;
  end;
end;


{ TIOSReaderPlayer }

constructor TIOSReaderPlayer.Create;
var
  Session: Pointer;
begin
  inherited Create;
  FSpeed := 1;
  FRangeEnd := -1;
  FSeekTarget := -1;
  FPendingFrom := -1;
  FindRuntime;
  // heard with the switch on silent and the screen locked, as speech
  try
    Session := Send0(ClassOf('AVAudioSession'), 'sharedInstance');
    if Session = nil then
      FSessionNote := 'no audio session'
    else
    begin
      if TMsgCategory(GMsgSend)(Session, Sel('setCategory:mode:options:error:'),
        NSText('AVAudioSessionCategoryPlayback'), NSText('AVAudioSessionModeSpokenAudio'), 0, nil) = 0 then
        FSessionNote := 'the audio session''s category was not set (the switch on silent may mute the book)';
      TMsgActive(GMsgSend)(Session, Sel('setActive:error:'), 1, nil);
    end;
  except
    on E: Exception do
      FSessionNote := 'the audio session: ' + E.Message;
  end;
  if FSessionNote <> '' then
    DebugLog('sound: ' + FSessionNote)
  else
    DebugLog('sound: the audio session is playback, spoken audio');
end;

destructor TIOSReaderPlayer.Destroy;
begin
  try
    Forget;
  except
    // closing
  end;
  FLoopback.Free;
  inherited;
end;

function TIOSReaderPlayer.GetSpeed: Double;
begin
  Result := FSpeed;
end;

procedure TIOSReaderPlayer.SetSpeed(AValue: Double);
begin
  if AValue <= 0 then
    Exit;
  FSpeed := AValue;
  if FPlaying and Ready and (FPendingFrom < 0) then
    SetRate(FPlayer, FSpeed);
end;

procedure TIOSReaderPlayer.Forget;
begin
  FPlaying := False;
  FEnded := False;
  FRangeEnd := -1;
  FSeekTarget := -1;
  FPendingFrom := -1;
  FLastError := '';
  FFileName := '';
  FDuration := 0;
  FReadyLogged := False;
  if FPlayer <> nil then
  begin
    try
      Send0(FPlayer, 'pause');
    except
      on E: Exception do
        DebugLog('sound: not paused before being let go - ' + E.Message);
    end;
    Send0(FPlayer, 'release');
    FPlayer := nil;
  end;
  if FItem <> nil then
  begin
    Send0(FItem, 'release');
    FItem := nil;
  end;
end;

procedure TIOSReaderPlayer.OpenAt(AUrl: Pointer; const AName: string);
begin
  Forget;
  if AUrl = nil then
    raise Exception.Create('not an address the player takes: ' + AName);
  FItem := Send1(ClassOf('AVPlayerItem'), 'playerItemWithURL:', AUrl);
  if FItem = nil then
    raise Exception.Create('the player did not take ' + AName);
  Send0(FItem, 'retain');
  // the speed changed as speech, the pitch kept
  // (AVAudioTimePitchAlgorithmTimeDomain)
  try
    Send1(FItem, 'setAudioTimePitchAlgorithm:', NSText('TimeDomain'));
  except
    // the default one
  end;
  FPlayer := Send1(ClassOf('AVPlayer'), 'playerWithPlayerItem:', FItem);
  if FPlayer = nil then
    raise Exception.Create('no player made for ' + AName);
  Send0(FPlayer, 'retain');
  FFileName := AName;
end;

procedure TIOSReaderPlayer.Open(const AFileName: string);
begin
  OpenAt(Send1(ClassOf('NSURL'), 'fileURLWithPath:', NSText(AFileName)), AFileName);
end;

function TIOSReaderPlayer.OpenPart(const AFileName: string; AOffset, ASize: Int64): Boolean;
var
  Url: string;
begin
  if FLoopback = nil then
    FLoopback := TIOSLoopback.Create;
  Url := TIOSLoopback(FLoopback).Serve(AFileName, AOffset, ASize);
  OpenAt(Send1(ClassOf('NSURL'), 'URLWithString:', NSText(Url)), AFileName);
  Result := True;
end;

function TIOSReaderPlayer.OpenUrl(const AUrl: string): Boolean;
begin
  OpenAt(Send1(ClassOf('NSURL'), 'URLWithString:', NSText(AUrl)), AUrl);
  Result := True;
end;

function TIOSReaderPlayer.Ready: Boolean;
begin
  Result := (FItem <> nil) and (NativeInt(Send0(FItem, 'status')) = ITEM_READY);
end;

procedure TIOSReaderPlayer.StartAt(AFrom: Double);
begin
  if (FPlayer = nil) or (FFileName = '') then
    Exit;
  if AFrom < 0 then
    AFrom := 0;
  FEnded := False;
  FPlaying := True;
  FSeekTarget := AFrom;
  FStartTick := TThread.GetTickCount;
  // not ready yet: Watch starts it when it is
  if not Ready then
  begin
    FPendingFrom := AFrom;
    Exit;
  end;
  FPendingFrom := -1;
  // each step logged (zips 404 - 406: the iPad's access violations)
  DebugLog(Format('sound: to %.3f s', [AFrom]));
  SeekTo(FPlayer, AFrom);
  DebugLog(Format('sound: sought; rate %.2f', [FSpeed]));
  SetRate(FPlayer, FSpeed);
  DebugLog('sound: playing');
end;

procedure TIOSReaderPlayer.Play(AFrom: Double);
begin
  FRangeEnd := -1;
  StartAt(AFrom);
end;

procedure TIOSReaderPlayer.PlayRange(AFrom, ATo: Double);
begin
  FRangeEnd := ATo;
  StartAt(AFrom);
end;

procedure TIOSReaderPlayer.Pause;
begin
  if (FPlayer = nil) or not FPlaying then
    Exit;
  FPlaying := False;
  // a start still waiting: from there next time
  if FPendingFrom >= 0 then
  begin
    FSeekTarget := FPendingFrom;
    FPendingFrom := -1;
    Exit;
  end;
  Send0(FPlayer, 'pause');
end;

procedure TIOSReaderPlayer.Resume;
begin
  if (FPlayer = nil) or (FFileName = '') or FPlaying then
    Exit;
  FEnded := False;
  FPlaying := True;
  FStartTick := TThread.GetTickCount;
  if Ready then
    SetRate(FPlayer, FSpeed)
  else
    FPendingFrom := Max(0, FSeekTarget);
end;

function TIOSReaderPlayer.Place: Double;
begin
  if Ready then
    Result := TimeSeconds(TimeOf(FPlayer, 'currentTime'))
  else
    Result := Max(0, FSeekTarget);
  // a seek still on its way: the player says the old place for a moment
  if FSeekTarget >= 0 then
  begin
    if (Cardinal(TThread.GetTickCount - FStartTick) < SETTLE_MS) and (Abs(Result - FSeekTarget) > SETTLE_FAR) then
      Result := FSeekTarget
    else if Ready then
      FSeekTarget := -1;
  end;
end;

procedure TIOSReaderPlayer.Watch;
var
  P, From: Double;
  Status: NativeInt;
begin
  if FItem = nil then
    Exit;
  try
    Status := NativeInt(Send0(FItem, 'status'));
    if Status = ITEM_FAILED then
    begin
      if FLastError = '' then
      begin
        FLastError := ErrorText(FItem);
        DebugLog('sound: ' + FLastError);
      end;
      FPlaying := False;
      FEnded := True;
      Exit;
    end;
    if Status = ITEM_READY then
    begin
      if FDuration <= 0 then
        FDuration := TimeSeconds(TimeOf(FItem, 'duration'));
      if not FReadyLogged then
      begin
        FReadyLogged := True;
        DebugLog(Format('sound: ready, %.1f s long', [FDuration]));
      end;
      // a start asked for before: now
      if FPlaying and (FPendingFrom >= 0) then
      begin
        From := FPendingFrom;
        StartAt(From);
      end;
    end;
    if not FPlaying or (FPendingFrom >= 0) then
      Exit;
    P := Place;
    // the range has been played through: stop there
    if (FRangeEnd >= 0) and (P >= FRangeEnd) then
    begin
      Send0(FPlayer, 'pause');
      FPlaying := False;
      FEnded := True;
      Exit;
    end;
    // the file's end: the player stops by itself (rate 0 there; not asked
    // in the first moment after a start)
    if (Cardinal(TThread.GetTickCount - FStartTick) >= SETTLE_MS) and (RateOf(FPlayer) = 0) and (FDuration > 0) and
      (P >= FDuration - 0.5) then
    begin
      FPlaying := False;
      FEnded := True;
    end;
  except
    on E: Exception do
    begin
      DebugLog('sound: ' + E.ClassName + ' - ' + E.Message);
      FLastError := E.Message;
      FPlaying := False;
      FEnded := True;
    end;
  end;
end;

function TIOSReaderPlayer.Position: Double;
begin
  Result := 0;
  if (FPlayer = nil) or (FFileName = '') then
    Exit;
  Watch;
  try
    Result := Place;
  except
    on E: Exception do
    begin
      DebugLog('sound: the place not read - ' + E.ClassName + ': ' + E.Message);
      FLastError := E.Message;
    end;
  end;
end;

function TIOSReaderPlayer.Ended: Boolean;
begin
  Watch;
  Result := FEnded;
end;

function TIOSReaderPlayer.LastError: string;
begin
  Result := FLastError;
end;

function TIOSReaderPlayer.FileName: string;
begin
  Result := FFileName;
end;

function TIOSReaderPlayer.Description: string;
begin
  Result := Format('iOS AVPlayer (iOS %d.%d)', [TOSVersion.Major, TOSVersion.Minor]);
end;

function TIOSReaderPlayer.Note: string;
begin
  Result := FSessionNote;
end;

initialization
  // AVFoundation loaded (its classes are found by name at run time)
  dlopen(MarshaledAString(UTF8String('/System/Library/Frameworks/AVFoundation.framework/AVFoundation')), RTLD_LAZY);
  Randomize;

{$ENDIF}

end.
