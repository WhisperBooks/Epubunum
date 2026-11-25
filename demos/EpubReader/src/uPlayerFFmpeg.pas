(* @abstract(The desktop's sound for the reader: @link(TFFmpegReaderPlayer)
  is uPlayer's TReaderPlayer over FFmpegAPI's TFFmpegAudioPlayer.)

  What uMain did itself until zip 316: FFmpeg's libraries are loaded (any
  FFmpeg 8 build, GPL or LGPL - its licence is in the description), the
  player is made on them, and every call is handed on unchanged. Windows,
  macOS and Linux only: uPlayer does not use this unit on Android or iOS,
  so FFmpegAPI is not needed to build the reader there. *)
unit uPlayerFFmpeg;

interface

uses
  System.SysUtils,
  FFmpeg.API, FFmpeg.Player,
  uPlayer;

type
  { TReaderPlayer played by FFmpeg (streamed; WASAPI / PulseAudio / the
    Mac's output; Position is the sound being heard). }
  TFFmpegReaderPlayer = class(TReaderPlayer)
  private
    { FFmpeg's libraries. }
    FLib: TFFmpegLibrary;
    { The player on them. }
    FPlayer: TFFmpegAudioPlayer;
  protected
    { Getter of Speed. }
    function GetSpeed: Double; override;
    { Setter of Speed (raises without avfilter: 1x only). }
    procedure SetSpeed(AValue: Double); override;
  public
    { Loads FFmpeg (the program's folder, then the system) and makes the
      player.
      @raises(Exception when FFmpeg's libraries are not found) }
    constructor Create;
    { Frees the player, then the libraries. }
    destructor Destroy; override;
    { As TReaderPlayer. }
    procedure Open(const AFileName: string); override;
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
    { FFmpeg's description and the sound output's, on two lines. }
    function Description: string; override;
    { The player's OutputNote. }
    function Note: string; override;
  end;

implementation

constructor TFFmpegReaderPlayer.Create;
begin
  inherited Create;
  FLib := TFFmpegLibrary.Create('');
  try
    FPlayer := TFFmpegAudioPlayer.Create(FLib);
  except
    FreeAndNil(FLib);
    raise;
  end;
end;

destructor TFFmpegReaderPlayer.Destroy;
begin
  FreeAndNil(FPlayer);
  FreeAndNil(FLib);
  inherited;
end;

function TFFmpegReaderPlayer.GetSpeed: Double;
begin
  Result := FPlayer.Speed;
end;

procedure TFFmpegReaderPlayer.SetSpeed(AValue: Double);
begin
  FPlayer.Speed := AValue;
end;

procedure TFFmpegReaderPlayer.Open(const AFileName: string);
begin
  FPlayer.Open(AFileName);
end;

procedure TFFmpegReaderPlayer.Play(AFrom: Double);
begin
  FPlayer.Play(AFrom);
end;

procedure TFFmpegReaderPlayer.PlayRange(AFrom, ATo: Double);
begin
  FPlayer.PlayRange(AFrom, ATo);
end;

procedure TFFmpegReaderPlayer.Pause;
begin
  FPlayer.Pause;
end;

procedure TFFmpegReaderPlayer.Resume;
begin
  FPlayer.Resume;
end;

function TFFmpegReaderPlayer.Position: Double;
begin
  Result := FPlayer.Position;
end;

function TFFmpegReaderPlayer.Ended: Boolean;
begin
  Result := FPlayer.Ended;
end;

function TFFmpegReaderPlayer.LastError: string;
begin
  Result := FPlayer.LastError;
end;

function TFFmpegReaderPlayer.FileName: string;
begin
  Result := FPlayer.FileName;
end;

function TFFmpegReaderPlayer.Description: string;
begin
  Result := FLib.Description + sLineBreak + 'Sound output: ' + FPlayer.Output.Description;
end;

function TFFmpegReaderPlayer.Note: string;
begin
  Result := FPlayer.OutputNote;
end;

end.
