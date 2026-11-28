(* @abstract(The reader's sound, behind one interface: @link(TReaderPlayer)
  is what uMain plays a book's audio with, whatever plays it underneath.)

  The desktop programs (Windows, macOS, Linux) play through FFmpegAPI's
  TFFmpegAudioPlayer (uPlayerFFmpeg). A phone, a tablet and a TV box decode
  AAC and MP3 themselves, and FFmpeg's libraries are not shipped there
  (owner, 2026-11-18: no FFmpeg on mobile; 2026-11-25: Android first, then
  iOS, both from this program): each gets a player of its own behind this
  class - Android's android.media.MediaPlayer (uPlayerAndroid), iOS's
  AVFoundation AVPlayer (uPlayerIOS, zip 403).

  Every time is in seconds of the audio file. The methods are called from
  the window's thread. *)
unit uPlayer;

interface

uses
  System.SysUtils;

type
  { The sound of the reader: one audio file at a time, played from a place
    in it, at a speed, with the place being heard told back for the
    highlight. }
  TReaderPlayer = class abstract
  protected
    { Getter of @link(Speed). }
    function GetSpeed: Double; virtual; abstract;
    { Setter of @link(Speed). }
    procedure SetSpeed(AValue: Double); virtual; abstract;
  public
    { Makes AFileName the file that is played (nothing is heard yet).
      @raises(Exception when the file cannot be opened) }
    procedure Open(const AFileName: string); virtual; abstract;
    { Makes ASize bytes at AOffset of AFileName the file that is played,
      with no copy made: a book's audio as it lies in the book (stored, not
      compressed). Zip 321: copying 900 MB out of a book froze the phone
      for nine seconds.
      @returns(@false when this player cannot - the caller extracts the
        file and calls Open; the answer here)
      @raises(Exception when it can but the part cannot be opened) }
    function OpenPart(const AFileName: string; AOffset, ASize: Int64): Boolean; virtual;
    { Makes the sound at AUrl (http://) the file that is played, streamed:
      a book streamed from BookManager (zip 392).
      @returns(@false when this player cannot - the caller extracts the
        file and calls Open; the answer here)
      @raises(Exception when it can but the address cannot be opened) }
    function OpenUrl(const AUrl: string): Boolean; virtual;
    { Plays the open file from AFrom to its end. }
    procedure Play(AFrom: Double); virtual; abstract;
    { Plays the open file from AFrom and stops at ATo (a word, a sentence). }
    procedure PlayRange(AFrom, ATo: Double); virtual; abstract;
    { Stops the sound where it is; @link(Resume) goes on from there. }
    procedure Pause; virtual; abstract;
    { Goes on after @link(Pause). }
    procedure Resume; virtual; abstract;
    { The place being HEARD now, for the highlight.
      @returns(seconds into the file) }
    function Position: Double; virtual; abstract;
    { @true once the file (or the range of PlayRange) has been played to its
      end.
      @returns(the answer) }
    function Ended: Boolean; virtual; abstract;
    { What went wrong while playing; '' when nothing did.
      @returns(the message) }
    function LastError: string; virtual; abstract;
    { The file that is open; '' when none is.
      @returns(the file name) }
    function FileName: string; virtual; abstract;
    { What plays the sound, for the log: the library and the output
      ('FFmpeg 8.0 ...; WASAPI, 48000 Hz').
      @returns(the description) }
    function Description: string; virtual; abstract;
    { Why the sound is silent although the player was made ('' when all is
      well) - a sound output that could not be opened.
      @returns(the note) }
    function Note: string; virtual; abstract;
    { The speed, 1 = as recorded; the pitch is kept.
      @raises(Exception when the speed cannot be changed here) }
    property Speed: Double read GetSpeed write SetSpeed;
  end;

{ Makes the player of this platform.
  @returns(the player)
  @raises(Exception when there is none - FFmpeg's libraries not found on a
    desktop; no player written yet for this platform) }
function ReaderPlayerCreate: TReaderPlayer;

implementation

{$IF Defined(ANDROID)}
uses
  uPlayerAndroid;
{$ELSEIF Defined(IOS)}
uses
  uPlayerIOS;
{$ELSE}
uses
  uPlayerFFmpeg;
{$ENDIF}

function TReaderPlayer.OpenPart(const AFileName: string; AOffset, ASize: Int64): Boolean;
begin
  Result := False;
end;

function TReaderPlayer.OpenUrl(const AUrl: string): Boolean;
begin
  Result := False;
end;

{$IF Defined(ANDROID)}

function ReaderPlayerCreate: TReaderPlayer;
begin
  Result := TAndroidReaderPlayer.Create;
end;

{$ELSEIF Defined(IOS)}

function ReaderPlayerCreate: TReaderPlayer;
begin
  // AVFoundation's AVPlayer (zip 403)
  Result := TIOSReaderPlayer.Create;
end;

{$ELSE}

function ReaderPlayerCreate: TReaderPlayer;
begin
  Result := TFFmpegReaderPlayer.Create;
end;

{$ENDIF}

end.
