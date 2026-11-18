(* @abstract(Steam for EpubReader and EpubBuilder, switched by the build
  configuration: everything Steam is here, behind STEAMBUILD.)

  The projects' "Steam" configuration (a child of Release) and
  "SteamDebug" (a child of Debug) define STEAMBUILD; Debug and Release do
  not. Without STEAMBUILD this unit uses nothing of TSteamAPI, so a
  non-Steam build needs TSteamAPI neither installed nor built, and its
  functions answer "not a Steam build" (owner, 2026-11-17: "This component
  should be easy to select or deselect from the build process").

  With STEAMBUILD, SteamStartup (called in the .dpr after
  Application.Initialize, before any form) starts TSteamAPI (FMX) with the
  program's AppID, as TSteamAPI's demos do (docs/Launcher.md there):
  @unorderedList(
    @item(SteamDebug: SetAppIdEnvironment - no steam_appid.txt, no
      relaunch: run and debug from the IDE with Steam running.)
    @item(Steam: RestartIfNecessary - started outside Steam (a double
      click), Steam starts and launches the program itself; this copy
      ends before it makes a window. Started by Steam: it carries on.))
  When Steam cannot be started (not installed, not logged in), the program
  carries on without it and says so in its log: neither program uses a
  Steam feature yet. The Steam library (steam_api64.dll,
  libsteam_api.so, libsteam_api.dylib) is found next to the program or,
  on macOS, in the bundle's Contents/MacOS or Contents/Frameworks.

  Built with STEAMBUILD, the program links TSteamAPI's runtime packages'
  units (Steamworks, SteamworksFMX) from Delphi's Dcp folder: build them
  for the platform first, as for EpubUnum's own packages. *)
unit uSteam;

interface

uses
  System.SysUtils, System.Classes, FMX.Forms;

{ Starts Steam in a Steam build (nothing in another).
  @param(AAppID  the program's Steam AppID)
  @returns(False when Steam is launching the program itself: end now,
    before any form) }
function SteamStartup(AAppID: Cardinal): Boolean;

{ True in a Steam build (STEAMBUILD defined).
  @returns(the answer) }
function SteamBuild: Boolean;

{ True when Steam was started and runs.
  @returns(the answer) }
function SteamRunning: Boolean;

{ True when Steam runs in Big Picture (desktop Big Picture or Game Mode)
  - known from SteamStartup on, before any form. The window is made full
  screen by TSteamAPI (BigPictureWindow bpwFullScreen); the forms leave
  out what Big Picture has no use for (EpubReader: the menu bar).
  @returns(the answer; False outside a Steam build) }
function SteamBigPicture: Boolean;

{ One line for the logs: 'not a Steam build', or 'Steam build, AppID N:
  Steam running' / '... not running (why)'.
  @returns(the line) }
function SteamText: string;

{ The display AForm is on, for the logs: its size in units, pixels and
  mm, Big Picture, Steam hardware and the UI scale TSteamAPI suggests
  (Steamworks.FMX.Screen). Call it once the form is shown.
  @param(AForm the form)
  @returns(one line; 'screen: not measured (not a Steam build)' without
    STEAMBUILD) }
function SteamScreenText(AForm: TCommonCustomForm): string;

type
  { How a Steam DLC stands for this user (SteamDlcState). }
  TSteamDlcState = (
    { No Steam (not a Steam build, or Steam not running). }
    sdsNoSteam,
    { Not in the user's account. }
    sdsNotOwned,
    { In the account, not installed. }
    sdsOwned,
    { Owned and installed (in the program's folder). }
    sdsInstalled);

{ How DLC AAppID stands: ISteamApps BIsDlcInstalled / BIsSubscribedApp.
  @param(AAppID  the DLC's AppID)
  @returns(sdsNoSteam outside a Steam build or without Steam) }
function SteamDlcState(AAppID: Cardinal): TSteamDlcState;

{ Gets DLC AAppID: owned - Steam installs it (InstallDLC); not owned - its
  store page in the Steam overlay, where a free DLC is added to the
  account (Steam then installs it). The program must be started again to
  use what the DLC brings (ggml finds its backends at start-up).
  @param(AAppID  the DLC's AppID)
  @returns(a line for the log: what was done, or why not) }
function SteamGetDlc(AAppID: Cardinal): string;

{ What SteamStartup and Steam said before the program's log was open
  (one line each; the forms write them into their logs).
  @returns(the lines) }
function SteamNotes: TArray<string>;

implementation

{$IFDEF STEAMBUILD}
uses
  Steamworks.Types, Steamworks.SDKTypes, Steamworks.Core, Steamworks.Components, Steamworks.FMX,
  Steamworks.FMX.Screen, Steamworks.Plugin.Apps, Steamworks.Plugin.Friends, uDebugLog;

type
  { Receives TSteamAPI's events (they are methods of an object). }
  TSteamHost = class
  public
    { Steam's own lines worth keeping (info and up): kept for SteamNotes
      until the debug log is open, then straight into it (TSteamAPI's
      late Big Picture line comes after the form logged the notes). }
    procedure SteamLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
    { Steam did not start: why (no message box - the program carries on). }
    procedure SteamInitFailed(Sender: TObject; AResult: Integer; const AMessage: string);
    { Steam launches the program itself: this copy ends (in the .dpr,
      before any form, not through the component). }
    procedure SteamRestart(Sender: TObject; var ATerminate: Boolean);
  end;

var
  { The component (no owner: freed in finalization, before the Steamworks
    units' own finalization). }
  GSteam: TSteamAPI = nil;
  { Its event receiver. }
  GHost: TSteamHost = nil;
  { Steam asked for a relaunch. }
  GRestart: Boolean = False;
  { Why Steam did not start. }
  GFailure: string = '';
{$ENDIF}

var
  { The AppID given to SteamStartup. }
  GAppID: Cardinal = 0;
  { See SteamNotes. }
  GNotes: TArray<string>;

{ Adds a line to SteamNotes. }
procedure Note(const AText: string);
begin
  GNotes := GNotes + [AText];
end;

{$IFDEF STEAMBUILD}
procedure TSteamHost.SteamLog(Sender: TObject; ALevel: TSteamLogLevel; const AMessage: string);
begin
  if ALevel < sllInfo then
    Exit;
  if DebugLogFile <> '' then
    DebugLog('Steam: ' + AMessage)
  else
    Note('Steam: ' + AMessage);
end;

procedure TSteamHost.SteamInitFailed(Sender: TObject; AResult: Integer; const AMessage: string);
begin
  GFailure := AMessage;
end;

procedure TSteamHost.SteamRestart(Sender: TObject; var ATerminate: Boolean);
begin
  GRestart := True;
  // the .dpr ends the program before any form is made
  ATerminate := False;
end;
{$ENDIF}

function SteamStartup(AAppID: Cardinal): Boolean;
begin
  Result := True;
  GAppID := AAppID;
  {$IFDEF STEAMBUILD}
  GHost := TSteamHost.Create;
  GSteam := TSteamAPI.Create(nil);
  GSteam.AppID := AAppID;
  {$IFDEF DEBUG}
  // development: Steam gets the AppID from the environment; no relaunch
  GSteam.SetAppIdEnvironment := True;
  GSteam.RestartIfNecessary := False;
  {$ELSE}
  // started outside Steam: Steam starts (if it is not running) and
  // launches the program itself
  GSteam.RestartIfNecessary := True;
  {$ENDIF}
  // Big Picture: full screen - no caption, frame or taskbar (maximised
  // kept all three, owner 2026-11-17)
  GSteam.BigPictureWindow := bpwFullScreen;
  GSteam.OnLog := GHost.SteamLog;
  GSteam.OnInitFailed := GHost.SteamInitFailed;
  GSteam.OnRestartRequired := GHost.SteamRestart;
  // running: SteamText says so (the forms log it); otherwise why not
  if GSteam.Open then
    Exit;
  if GRestart then
  begin
    Note(Format('Steam build, AppID %d: started outside Steam - Steam launches it itself', [AAppID]));
    Result := False;
  end
  else
    Note(Format('Steam build, AppID %d: Steam did not start (%s) - carrying on without it', [AAppID,
      GFailure]));
  {$ENDIF}
end;

function SteamBuild: Boolean;
begin
  {$IFDEF STEAMBUILD}
  Result := True;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function SteamRunning: Boolean;
begin
  {$IFDEF STEAMBUILD}
  Result := (GSteam <> nil) and GSteam.IsRunning;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function SteamBigPicture: Boolean;
begin
  {$IFDEF STEAMBUILD}
  Result := (GSteam <> nil) and GSteam.IsRunning and GSteam.InBigPicture;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function SteamText: string;
begin
  if not SteamBuild then
    Result := 'not a Steam build'
  else if SteamRunning then
    Result := Format('Steam build, AppID %d: Steam running', [GAppID])
  {$IFDEF STEAMBUILD}
  else if GFailure <> '' then
    Result := Format('Steam build, AppID %d: Steam not running (%s)', [GAppID, GFailure])
  {$ENDIF}
  else
    Result := Format('Steam build, AppID %d: Steam not running', [GAppID]);
end;

function SteamScreenText(AForm: TCommonCustomForm): string;
begin
  {$IFDEF STEAMBUILD}
  try
    Result := SteamScreenInfo(AForm).Text;
  except
    on E: Exception do
      Result := 'screen: not measured (' + E.ClassName + ': ' + E.Message + ')';
  end;
  {$ELSE}
  Result := 'screen: not measured (not a Steam build)';
  {$ENDIF}
end;

function SteamNotes: TArray<string>;
begin
  Result := GNotes;
end;

{$IFDEF STEAMBUILD}
{ ISteamApps' plug-in while Steam runs (linked by this unit: registered at
  start-up, initialised with Steam). }
function AppsPlugin: TSteamAppsPlugin;
begin
  Result := nil;
  if SteamRunning then
    Result := TSteamAppsPlugin(Steam.FindPlugin(TSteamAppsPlugin));
end;
{$ENDIF}

function SteamDlcState(AAppID: Cardinal): TSteamDlcState;
{$IFDEF STEAMBUILD}
var
  P: TSteamAppsPlugin;
{$ENDIF}
begin
  Result := sdsNoSteam;
  {$IFDEF STEAMBUILD}
  P := AppsPlugin;
  if (P = nil) or (AAppID = 0) then
    Exit;
  if P.BIsDlcInstalled(AAppID) then
    Result := sdsInstalled
  else if P.BIsSubscribedApp(AAppID) then
    Result := sdsOwned
  else
    Result := sdsNotOwned;
  {$ENDIF}
end;

function SteamGetDlc(AAppID: Cardinal): string;
{$IFDEF STEAMBUILD}
var
  F: TSteamFriendsPlugin;
{$ENDIF}
begin
  case SteamDlcState(AAppID) of
    sdsInstalled:
      Result := 'It is installed: start the program again to use it.';
    sdsOwned:
      begin
        {$IFDEF STEAMBUILD}
        AppsPlugin.InstallDLC(AAppID);
        {$ENDIF}
        Result := 'Steam is installing it (Steam''s Downloads page shows it): start the program again when it ' +
          'has finished.';
      end;
    sdsNotOwned:
      begin
        Result := Format('Its store page: https://store.steampowered.com/app/%d - add it to your account ' +
          '(it is free); Steam then installs it. Start the program again when it has finished.', [AAppID]);
        {$IFDEF STEAMBUILD}
        F := TSteamFriendsPlugin(Steam.FindPlugin(TSteamFriendsPlugin));
        if F <> nil then
        begin
          F.ActivateGameOverlayToStore(AAppID, k_EOverlayToStoreFlag_None);
          Result := 'Its store page is open in the Steam overlay: add it to your account (it is free); Steam ' +
            'then installs it. Start the program again when it has finished.';
        end;
        {$ENDIF}
      end;
  else
    Result := 'Steam is not running: start the program from Steam.';
  end;
end;

{$IFDEF STEAMBUILD}
initialization

finalization
  // before the Steamworks units' finalization (they were initialised first)
  FreeAndNil(GSteam);
  FreeAndNil(GHost);
{$ENDIF}
end.
