program EpubReader;

{ EpubReader - reads an EPUB book in a Skia-drawn view (TEpubView) and, for
  a book with media overlays, plays its audio with the words highlighted as
  they are read. The library comes from the runtime packages EpubUnum and
  EpubUnumFMX (Delphi's Dcp folder) - build them first.

  Skia is enabled for this project (Project > Enable Skia: the SKIA define
  and Skia's library deployed next to the program). TEpubView draws with
  Skia whatever FMX's canvas is; the IDE's "GlobalUseSkia := True;" line is
  NOT kept - FmxSkiaCanvas switches FMX's own canvas to Skia only under
  Wine / Proton when TSAPI_FMX_CANVAS asks for it.

  Platform fixes (from TSteamAPI, unchanged copies - see README.md):
  FmxLinuxGtkGlobal (Steam's Linux runtime), FmxWineCanvas + FmxSkiaCanvas
  (a Windows build under Wine / Proton), src/EpubReader.sh (the ICU
  launcher for SteamOS). }

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Skia,
  // Linux inside Steam's runtime: GTK made globally visible before any form
  FmxLinuxGtkGlobal in 'src\FmxLinuxGtkGlobal.pas',
  // Windows build under Wine / Proton: FMX draws with GDI+, because Wine's
  // Direct2D leaves FMX windows white; a no-op on Windows and elsewhere
  FmxWineCanvas in 'src\FmxWineCanvas.pas',
  // ... and Skia's raster / Vulkan canvas when TSAPI_FMX_CANVAS asks for it
  FmxSkiaCanvas in 'src\FmxSkiaCanvas.pas',
  uDebugLog in '..\common\uDebugLog.pas',
  // Steam: only in the Steam / SteamDebug configurations (STEAMBUILD)
  uSteam in '..\common\uSteam.pas',
  uMain in 'src\uMain.pas' {frmMain};

{$R *.res}

const
  { EpubReader's Steam AppID (used by the Steam / SteamDebug configurations). }
  STEAM_APP_ID = 5639840;

begin
{$IFDEF DEBUG}
  // Debug builds list leaked blocks when the program ends (Windows)
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}
{$IFDEF POSIX}
  // start-up markers on stderr: under Steam's Linux runtime a crash before
  // the form's OnCreate leaves no log, and stderr is what the launch
  // options can capture (%command% > file 2>&1) - as TSteamAPI's demos
  WriteLn(ErrOutput, 'start-up: units initialised');
{$ENDIF}
  Application.Initialize;
  // a Steam build started outside Steam: Steam launches it itself, and
  // this copy ends before it makes a window (nothing in other builds)
  if not SteamStartup(STEAM_APP_ID) then
    Exit;
  Application.CreateForm(TfrmMain, frmMain);
{$IFDEF POSIX}
  WriteLn(ErrOutput, 'start-up: Application.Run');
{$ENDIF}
  Application.Run;
end.
