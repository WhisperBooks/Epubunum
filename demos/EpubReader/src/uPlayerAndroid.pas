(* @abstract(Android's sound for the reader: @link(TAndroidReaderPlayer) is
  uPlayer's TReaderPlayer over android.media.MediaPlayer.)

  Android decodes a book's audio itself (AAC in m4b / m4a, MP3), so no
  FFmpeg is shipped (owner, 2026-11-18). MediaPlayer is reached through
  Delphi's JNI bridge with imports of THIS unit's own (the few methods
  used, under names of their own), so that nothing depends on which of them
  a Delphi version's Androidapi.JNI.Media happens to have.

  What MediaPlayer does not do, and how it is done here:
  - a RANGE (PlayRange: a word, a sentence): there is no "stop at"; the
    place is looked at whenever the reader asks for Position or Ended
    (its play timer does, many times a second) and the sound paused at
    the range's end - so a range ends a timer's step late at most;
  - the SPEED: PlaybackParams.setSpeed (Android 6, API 23); setting it
    STARTS a prepared player, so it is only set while playing, and kept
    for the next start otherwise. The pitch is kept (setPitch 1);
  - a SEEK is not done at once: for a moment getCurrentPosition still says
    the old place - Position answers the place asked for meanwhile.

  Android only: an empty unit elsewhere. Phone, tablet and Android TV
  (Shield, Fire TV) alike. Called from the window's thread. *)
unit uPlayerAndroid;

interface

{$IFDEF ANDROID}

uses
  System.SysUtils, System.Classes,
  Androidapi.JNIBridge, Androidapi.JNI.JavaTypes, Androidapi.Helpers,
  uPlayer;

type
  JEpubPlaybackParams = interface;

  { android.media.PlaybackParams: the class side. }
  JEpubPlaybackParamsClass = interface(JObjectClass)
    ['{5C1B0E53-7C0E-4A0B-9B58-2A9E1F4C7D11}']
    { new PlaybackParams(). }
    function init: JEpubPlaybackParams; cdecl;
  end;

  { android.media.PlaybackParams (API 23): speed and pitch of a player. }
  [JavaSignature('android/media/PlaybackParams')]
  JEpubPlaybackParams = interface(JObject)
    ['{8E2F6A14-33B9-4D5E-8A70-6B1C9D2E4F32}']
    { The speed, 1 = as recorded. }
    function setSpeed(speed: Single): JEpubPlaybackParams; cdecl;
    { The pitch, 1 = unchanged. }
    function setPitch(pitch: Single): JEpubPlaybackParams; cdecl;
  end;

  { The import of android.media.PlaybackParams. }
  TJEpubPlaybackParams = class(TJavaGenericImport<JEpubPlaybackParamsClass, JEpubPlaybackParams>)
  end;

  JEpubMediaPlayer = interface;

  { android.media.MediaPlayer: the class side. }
  JEpubMediaPlayerClass = interface(JObjectClass)
    ['{A3D94C27-51E8-4F06-B2C1-7E5A0F3B9D43}']
    { new MediaPlayer(). }
    function init: JEpubMediaPlayer; cdecl;
  end;

  { android.media.MediaPlayer: the methods the reader uses. }
  [JavaSignature('android/media/MediaPlayer')]
  JEpubMediaPlayer = interface(JObject)
    ['{D47B1E90-6A2C-4B83-9F15-2C8E7A4D0B54}']
    { The file to play, by its path. }
    procedure setDataSource(path: JString); cdecl; overload;
    { A part of an open file to play: length bytes at offset. }
    procedure setDataSource(fd: JFileDescriptor; offset: Int64; length: Int64); cdecl; overload;
    { Makes the player ready (here: a local file, so at once). }
    procedure prepare; cdecl;
    { Plays, or goes on. }
    procedure start; cdecl;
    { Stops where it is. }
    procedure pause; cdecl;
    { Back to the state before setDataSource. }
    procedure reset; cdecl;
    { Gives the player's resources back. }
    procedure release; cdecl;
    { Goes to a place, milliseconds (the nearest sync frame before it). }
    procedure seekTo(msec: Integer); cdecl; overload;
    { Goes to a place, milliseconds, by a mode (API 26; 3 = the closest
      frame). }
    procedure seekTo(msec: Int64; mode: Integer); cdecl; overload;
    { The place, milliseconds. }
    function getCurrentPosition: Integer; cdecl;
    { The file's length, milliseconds. }
    function getDuration: Integer; cdecl;
    { Sound is being played. }
    function isPlaying: Boolean; cdecl;
    { Speed and pitch (API 23). Starts a prepared player. }
    procedure setPlaybackParams(params: JEpubPlaybackParams); cdecl;
  end;

  { The import of android.media.MediaPlayer. }
  TJEpubMediaPlayer = class(TJavaGenericImport<JEpubMediaPlayerClass, JEpubMediaPlayer>)
  end;

  { TReaderPlayer played by Android's MediaPlayer. }
  TAndroidReaderPlayer = class(TReaderPlayer)
  private
    { The player (nil until a file is opened). }
    FPlayer: JEpubMediaPlayer;
    { The open file ('' = none). }
    FFileName: string;
    { The file's length, seconds. }
    FDuration: Double;
    { The speed asked for. }
    FSpeed: Double;
    { Sound is meant to be heard (between a start and a pause / the end). }
    FPlaying: Boolean;
    { The file, or the range, has been played to its end. }
    FEnded: Boolean;
    { Where PlayRange stops, seconds; < 0 = at the file's end. }
    FRangeEnd: Double;
    { The place last asked for, seconds, and when (GetTickCount). }
    FSeekTarget: Double;
    { When the last start was (GetTickCount). }
    FStartTick: Cardinal;
    { What went wrong while playing. }
    FLastError: string;
    { No file open and nothing remembered of the last one; the player made,
      or put back to before its file. }
    procedure Forget;
    { Goes to AFrom and plays, at the speed. }
    procedure StartAt(AFrom: Double);
    { Sets the speed on the playing player. }
    procedure ApplySpeed;
    { The player's own place, seconds - the place asked for while a seek
      is still on its way. }
    function Place: Double;
    { Ends a range that has been played through, and sees the file's end. }
    procedure Watch;
  protected
    { Getter of Speed. }
    function GetSpeed: Double; override;
    { Setter of Speed. }
    procedure SetSpeed(AValue: Double); override;
  public
    { Makes the object; the player itself comes with the first file. }
    constructor Create;
    { Gives the player back. }
    destructor Destroy; override;
    { As TReaderPlayer. }
    procedure Open(const AFileName: string); override;
    { As TReaderPlayer: MediaPlayer plays a part of a file (as it does a
      sound inside an APK), so a book's stored audio needs no copy. }
    function OpenPart(const AFileName: string; AOffset, ASize: Int64): Boolean; override;
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
    { 'Android MediaPlayer (Android <version>)'. }
    function Description: string; override;
    { '' - Android has no separate sound output to fail. }
    function Note: string; override;
  end;

{$ENDIF}

implementation

{$IFDEF ANDROID}

const
  { MediaPlayer.SEEK_CLOSEST: the frame nearest the place, not the sync
    frame before it. }
  SEEK_CLOSEST = 3;
  { For this long after a seek or a start, milliseconds, the player may
    still say the old place, or that it is not playing. }
  SETTLE_MS = 400;
  { A place this far from the one asked for, seconds, is the old place. }
  SETTLE_FAR = 0.75;

constructor TAndroidReaderPlayer.Create;
begin
  inherited Create;
  FSpeed := 1;
  FRangeEnd := -1;
  FSeekTarget := -1;
end;

destructor TAndroidReaderPlayer.Destroy;
begin
  if FPlayer <> nil then
    try
      FPlayer.release;
    except
      // the program is closing: nothing to do about it
    end;
  FPlayer := nil;
  inherited;
end;

function TAndroidReaderPlayer.GetSpeed: Double;
begin
  Result := FSpeed;
end;

procedure TAndroidReaderPlayer.ApplySpeed;
begin
  if (FPlayer = nil) or not TOSVersion.Check(6) then
    Exit;
  FPlayer.setPlaybackParams(TJEpubPlaybackParams.JavaClass.init.setSpeed(FSpeed).setPitch(1));
end;

procedure TAndroidReaderPlayer.SetSpeed(AValue: Double);
begin
  if AValue <= 0 then
    Exit;
  FSpeed := AValue;
  // setting it starts a prepared player: only while playing (the next
  // start sets it otherwise)
  if FPlaying then
    ApplySpeed;
end;

procedure TAndroidReaderPlayer.Forget;
begin
  FPlaying := False;
  FEnded := False;
  FRangeEnd := -1;
  FSeekTarget := -1;
  FLastError := '';
  FFileName := '';
  FDuration := 0;
  if FPlayer = nil then
    FPlayer := TJEpubMediaPlayer.JavaClass.init
  else
    FPlayer.reset;
end;

procedure TAndroidReaderPlayer.Open(const AFileName: string);
begin
  Forget;
  FPlayer.setDataSource(StringToJString(AFileName));
  FPlayer.prepare;
  FDuration := FPlayer.getDuration / 1000;
  FFileName := AFileName;
end;

function TAndroidReaderPlayer.OpenPart(const AFileName: string; AOffset, ASize: Int64): Boolean;
var
  Stream: JFileInputStream;
begin
  Forget;
  // the player keeps a descriptor of its own: ours is closed once it is
  // ready
  Stream := TJFileInputStream.JavaClass.init(StringToJString(AFileName));
  try
    FPlayer.setDataSource(Stream.getFD, AOffset, ASize);
    FPlayer.prepare;
  finally
    Stream.close;
  end;
  FDuration := FPlayer.getDuration / 1000;
  FFileName := AFileName;
  Result := True;
end;

procedure TAndroidReaderPlayer.StartAt(AFrom: Double);
var
  Ms: Int64;
begin
  if (FPlayer = nil) or (FFileName = '') then
    Exit;
  if AFrom < 0 then
    AFrom := 0;
  Ms := Round(AFrom * 1000);
  if TOSVersion.Check(8) then
    FPlayer.seekTo(Ms, SEEK_CLOSEST)
  else
    FPlayer.seekTo(Integer(Ms));
  FSeekTarget := AFrom;
  FEnded := False;
  FPlayer.start;
  FStartTick := TThread.GetTickCount;
  FPlaying := True;
  if FSpeed <> 1 then
    ApplySpeed;
end;

procedure TAndroidReaderPlayer.Play(AFrom: Double);
begin
  FRangeEnd := -1;
  StartAt(AFrom);
end;

procedure TAndroidReaderPlayer.PlayRange(AFrom, ATo: Double);
begin
  FRangeEnd := ATo;
  StartAt(AFrom);
end;

procedure TAndroidReaderPlayer.Pause;
begin
  if (FPlayer = nil) or not FPlaying then
    Exit;
  FPlaying := False;
  FPlayer.pause;
end;

procedure TAndroidReaderPlayer.Resume;
begin
  if (FPlayer = nil) or (FFileName = '') or FPlaying then
    Exit;
  FEnded := False;
  FPlayer.start;
  FStartTick := TThread.GetTickCount;
  FPlaying := True;
  if FSpeed <> 1 then
    ApplySpeed;
end;

function TAndroidReaderPlayer.Place: Double;
begin
  Result := FPlayer.getCurrentPosition / 1000;
  // a seek still on its way: the player says the old place for a moment
  if (FSeekTarget >= 0) then
  begin
    if (Cardinal(TThread.GetTickCount - FStartTick) < SETTLE_MS) and (Abs(Result - FSeekTarget) > SETTLE_FAR) then
      Result := FSeekTarget
    else
      FSeekTarget := -1;
  end;
end;

procedure TAndroidReaderPlayer.Watch;
var
  P: Double;
begin
  if (FPlayer = nil) or not FPlaying then
    Exit;
  try
    P := Place;
    // the range has been played through: stop there
    if (FRangeEnd >= 0) and (P >= FRangeEnd) then
    begin
      FPlayer.pause;
      FPlaying := False;
      FEnded := True;
      Exit;
    end;
    // the file's end: the player stops by itself (not asked in the first
    // moment after a start, when it may not say "playing" yet)
    if (Cardinal(TThread.GetTickCount - FStartTick) >= SETTLE_MS) and not FPlayer.isPlaying then
    begin
      FPlaying := False;
      FEnded := True;
    end;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      FPlaying := False;
      FEnded := True;
    end;
  end;
end;

function TAndroidReaderPlayer.Position: Double;
begin
  Result := 0;
  if (FPlayer = nil) or (FFileName = '') then
    Exit;
  Watch;
  try
    Result := Place;
  except
    on E: Exception do
      FLastError := E.Message;
  end;
end;

function TAndroidReaderPlayer.Ended: Boolean;
begin
  Watch;
  Result := FEnded;
end;

function TAndroidReaderPlayer.LastError: string;
begin
  Result := FLastError;
end;

function TAndroidReaderPlayer.FileName: string;
begin
  Result := FFileName;
end;

function TAndroidReaderPlayer.Description: string;
begin
  Result := Format('Android MediaPlayer (Android %d.%d)', [TOSVersion.Major, TOSVersion.Minor]);
end;

function TAndroidReaderPlayer.Note: string;
begin
  Result := '';
end;

{ Registers this unit's Java imports with the JNI bridge. }
procedure RegisterTypes;
begin
  TRegTypes.RegisterType('uPlayerAndroid.JEpubPlaybackParams', TypeInfo(uPlayerAndroid.JEpubPlaybackParams));
  TRegTypes.RegisterType('uPlayerAndroid.JEpubMediaPlayer', TypeInfo(uPlayerAndroid.JEpubMediaPlayer));
end;

initialization
  RegisterTypes;

{$ENDIF}

end.
