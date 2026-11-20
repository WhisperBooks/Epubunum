program EpubBuilder;

{ EpubBuilder - makes a read-along EPUB: an EPUB on one side, its audio
  files on the other, Create. It transcribes the audio with TWhisper (word
  times by DTW), aligns the words with the book's own words and writes a
  copy of the book with EPUB 3 media overlays and the audio inside - the
  book EpubReader then reads aloud with the words highlighted. The steps
  are those of the file pipeline (EpubConsole --words, WhisperConsole
  --align-words --timings, EpubConsole --overlay), done in one program.

  Needs TWhisper's runtime package WhisperAPI (and TFFMpegAPI's
  FFmpegAPI, which it requires) built as well as EpubUnum's: their DCUs
  come from Delphi's Dcp folder. At run time: whisper.cpp's libraries
  (TWhisper's redistributable_bin) and FFmpeg 8's shared libraries next to
  the program or on PATH, and a Whisper model file (ggml-*.bin). }

uses
  System.StartUpCopy,
  FMX.Forms,
  // Linux inside Steam's runtime: GTK made globally visible before any form
  // (FMX crashes there without it - TSteamAPI's fmx-steamos-gtk3-bug.md);
  // an unchanged copy of TSteamAPI's, as EpubReader's
  FmxLinuxGtkGlobal in 'src\FmxLinuxGtkGlobal.pas',
  // Windows build under Wine / Proton: FMX draws with GDI+, because Wine's
  // Direct2D leaves FMX windows white; a no-op on Windows and elsewhere
  FmxWineCanvas in 'src\FmxWineCanvas.pas',
  uDebugLog in '..\common\uDebugLog.pas',
  // keeps the computer awake while it works (SteamOS sleeps on no input)
  uInhibit in '..\common\uInhibit.pas',
  // memory cards' Books / Audio / Transcribed folders (Steam hardware)
  uCards in '..\common\uCards.pas',
  uRedraw in '..\common\uRedraw.pas',
  // the folders shared by EpubBuilder and EpubReader (Documents/EpubUnum)
  uEpubUnum in '..\common\uEpubUnum.pas',
  // the link: BookManager and EpubReader connect (Indy)
  uLink in '..\common\uLink.pas',
  // Steam's Exit Game (SIGTERM): saved before the end
  uQuitSignal in '..\common\uQuitSignal.pas',
  // Steam: only in the Steam / SteamDebug configurations (STEAMBUILD)
  uSteam in '..\common\uSteam.pas',
  // the pad in Big Picture: Steam Input with the reader's manifest (one per
  // Steam app) and the reader's pad menu
  uSteamPad in '..\common\uSteamPad.pas',
  uPadMenu in '..\EpubReader\src\uPadMenu.pas',
  uReaderInput in '..\EpubReader\src\uReaderInput.pas',
  uMachine in '..\common\uMachine.pas',
  uCalibration in 'src\uCalibration.pas',
  uHistory in 'src\uHistory.pas',
  uModels in 'src\uModels.pas',
  // a book's cover: the Covers folder, the audiobook's art
  uCovers in 'src\uCovers.pas',
  // the cover chooser (thumbnails)
  uCoverPick in 'src\uCoverPick.pas',
  uBuilder in 'src\uBuilder.pas' {frmBuilder};

{$R *.res}

const
  { EpubBuilder's Steam AppID (used by the Steam / SteamDebug configurations). }
  STEAM_APP_ID = 5639910;

begin
{$IFDEF DEBUG}
  // Debug builds list leaked blocks when the program ends (Windows)
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}
  Application.Initialize;
  // a Steam build started outside Steam: Steam launches it itself, and
  // this copy ends before it makes a window (nothing in other builds)
  if not SteamStartup(STEAM_APP_ID) then
    Exit;
  Application.CreateForm(TfrmBuilder, frmBuilder);
  Application.Run;
end.
