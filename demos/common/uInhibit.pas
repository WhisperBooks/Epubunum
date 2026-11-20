(* @abstract(Keeps the computer awake - and, when asked, its screen on -
  while a program works with nobody touching it.)

  Owner, 2026-11-18, on the Steam Machine: "The steam machine thinks
  Builder is "Inactivity" it seems cos it starts it's screen saver after a
  while". SteamOS (Game Mode) goes by input only: no controller or key
  for a while and the screen dims, then the machine sleeps - an hour's
  transcription with nobody at the controller is put to sleep half way.
  Laptops do the same on every system.

  @link(ikSleep) keeps the computer from sleeping (the screen may go
  dark): EpubBuilder while it builds, runs its queue, calibrates or
  downloads a model. @link(ikDisplay) keeps the screen on as well:
  EpubReader while it reads aloud (the words are followed on the screen).
  Starts are counted: each InhibitStart needs its InhibitStop.

  @unorderedList(
    @item(Windows: SetThreadExecutionState (ES_SYSTEM_REQUIRED, with
      ES_DISPLAY_REQUIRED for ikDisplay; ES_CONTINUOUS) - call from the
      main thread.)
    @item(macOS: IOKit power assertions PreventUserIdleSystemSleep /
      PreventUserIdleDisplaySleep.)
    @item(Linux (SteamOS too): over D-Bus, libdbus-1 loaded at run time
      (Steam's runtime has it): systemd-logind's Inhibit("sleep:idle",
      mode block) on the system bus - kept while its file descriptor is
      open - and for ikDisplay also org.freedesktop.ScreenSaver.Inhibit
      on the session bus (KDE, GNOME). Private connections, kept for the
      program's life, that never end the program when the bus goes away.
      Whether Steam's Game Mode honours them was not known when this was
      written: InhibitText says which calls worked, for the logs.))

  The speed (@link(InhibitSpeed)), apart from sleep - owner, 2026-11-19:
  "some people may desire power control ... saving power or time":
  @unorderedList(
    @item(macOS: full speed is NSProcessInfo's beginActivityWithOptions
      (user initiated, latency critical). Kept awake alone, the Mac does
      not run at full speed: with the display off macOS treats the program
      as background work (App Nap) - an M4's overnight queue, 2026-11-19:
      27.6x real time with the display on, 17.1x with it off, the switch
      within two minutes of each of 8 display changes, the aligning five
      times slower too. Saving: no activity (App Nap allowed).)
    @item(Windows: SetProcessInformation(ProcessPowerThrottling) - full
      speed opts out of EcoQoS, saving opts in.)
    @item(Linux: left to the system (a lower priority could not be taken
      back without privileges).))
  @link(OnBattery) tells mains from battery for an automatic choice.
  @link(GpuPreference) / @link(SetGpuPreference): Windows' per-program
  graphics preference (Settings > System > Display > Graphics), read by
  Windows when the program starts.

  Steam's Game Mode (owner, 2026-11-20, the Steam Machine): refusing sleep
  there leaves Steam stuck - its sleep timer blacks the screen, the
  machine cannot sleep, Steam's menu stops working, only restarting Steam
  helps. So there (@link(InhibitSetPauseForSleep)) ikSleep does not refuse
  sleep: it asks logind only for a few seconds' delay ("sleep", mode
  delay), and @link(InhibitPoll) announces logind's PrepareForSleep - the
  program pauses its work, then @link(InhibitLetSleep); after the wake the
  delay is asked for again by itself. @link(GameModeSession) tells Game
  Mode from the environment.

  Nothing here raises: a way that does not work is noted in InhibitText
  and the program carries on. *)
unit uInhibit;

interface

type
  { What is kept on. }
  TInhibitKind = (
    { The computer: no sleep while idle (the screen may go dark) - a
      long build. }
    ikSleep,
    { The computer and its screen - the reader while it reads aloud. }
    ikDisplay);

type
  { How fast the program may run with nobody using the computer. }
  TInhibitSpeed = (
    { As the system decides (the start). }
    isSystem,
    { Full speed: no App Nap (macOS), no EcoQoS (Windows). }
    isFast,
    { Power before speed: App Nap allowed (macOS), EcoQoS (Windows). }
    isSaving);

  { Windows' graphics preference for this program. }
  TGpuPreference = (
    { Windows decides (no preference stored). }
    gpSystem,
    { The power saving GPU (a laptop's integrated one). }
    gpSaving,
    { The high performance GPU. }
    gpFast);

  { What the system said about sleep (InhibitPoll). }
  TSleepSignal = (
    { Nothing new. }
    ssNone,
    { The system is about to sleep: pause the work, then InhibitLetSleep
      (within a few seconds - the system does not wait longer). }
    ssGoingToSleep,
    { The system woke up again (the delay is asked for again by itself). }
    ssWoke);

{ Steam's Game Mode (a gamescope session), from the environment.
  @param(AWhy  which variable said so, or why not)
  @returns(True in Game Mode) }
function GameModeSession(out AWhy: string): Boolean;

{ How ikSleep keeps the computer from now on - call before InhibitStart.
  False (the start): sleep refused. True (Linux only; elsewhere nothing
  changes): sleep allowed - only a few seconds' delay is asked for, and
  InhibitPoll says when the system goes to sleep and wakes.
  @param(AOn  pause for sleep instead of refusing it) }
procedure InhibitSetPauseForSleep(AOn: Boolean);

{ InhibitSetPauseForSleep's setting.
  @returns(True when sleep is paused for, not refused) }
function InhibitPauseForSleep: Boolean;

{ What the system said about sleep since the last call - call often (a few
  times a second) from the main thread while InhibitPauseForSleep. After
  ssWoke, InhibitText says how the delay was asked for again.
  @returns(the latest news) }
function InhibitPoll: TSleepSignal;

{ Lets the system sleep now (after ssGoingToSleep, once the work is
  paused): the delay is given back. }
procedure InhibitLetSleep;

{ Starts keeping AKind on (counted: each start needs its stop).
  @param(AKind  what is kept on)
  @param(AReason  why, in a few words (shown by some systems))
  @returns(True when a way of this system took it; InhibitText says
    which) }
function InhibitStart(AKind: TInhibitKind; const AReason: string): Boolean;

{ Ends one InhibitStart of AKind; at the last one the system may idle
  again.
  @param(AKind  what was kept on) }
procedure InhibitStop(AKind: TInhibitKind);

{ What the last InhibitStart / InhibitStop did, for the logs ('' before
  the first).
  @returns(the text) }
function InhibitText: string;

{ Sets how fast the program may run (the whole program, until the next
  call; isSystem at the end of the work).
  @param(ASpeed  the speed)
  @returns(what was done, for the logs) }
function InhibitSpeed(ASpeed: TInhibitSpeed): string;

{ The computer runs on its battery (False when it has none, or when it
  cannot be told).
  @returns(True on battery) }
function OnBattery: Boolean;

{ Windows' graphics preference stored for this program (gpSystem
  elsewhere).
  @returns(the preference) }
function GpuPreference: TGpuPreference;

{ Stores Windows' graphics preference for this program - Windows uses it
  when the program next starts. Other systems: nothing.
  @param(APreference  the preference; gpSystem removes it)
  @returns(True when it was stored) }
function SetGpuPreference(APreference: TGpuPreference): Boolean;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows, System.Win.Registry,
  {$ENDIF}
  {$IF Defined(MACOS) and not Defined(IOS)}
  Macapi.CoreFoundation,
  {$ENDIF}
  {$IF Defined(LINUX) and not Defined(ANDROID)}
  Posix.Unistd, System.IOUtils,
  {$ENDIF}
  System.SysUtils;

var
  { Starts not yet stopped, per kind. }
  GCount: array[TInhibitKind] of Integer;
  { See InhibitText. }
  GText: string;
  { See InhibitSetPauseForSleep. }
  GPauseForSleep: Boolean;

function GameModeSession(out AWhy: string): Boolean;
{$IF Defined(LINUX) and not Defined(ANDROID)}
var
  V: string;
{$ENDIF}
begin
  Result := False;
  AWhy := 'not Game Mode (no gamescope in the environment)';
  {$IF Defined(LINUX) and not Defined(ANDROID)}
  V := GetEnvironmentVariable('XDG_CURRENT_DESKTOP');
  if Pos('gamescope', LowerCase(V)) > 0 then
  begin
    AWhy := 'XDG_CURRENT_DESKTOP=' + V;
    Exit(True);
  end;
  V := GetEnvironmentVariable('GAMESCOPE_WAYLAND_DISPLAY');
  if V <> '' then
  begin
    AWhy := 'GAMESCOPE_WAYLAND_DISPLAY=' + V;
    Exit(True);
  end;
  V := GetEnvironmentVariable('SteamGamepadUI');
  if V = '1' then
  begin
    AWhy := 'SteamGamepadUI=1';
    Exit(True);
  end;
  {$ELSE}
  AWhy := 'not Linux';
  {$ENDIF}
end;

procedure InhibitSetPauseForSleep(AOn: Boolean);
begin
  {$IF Defined(LINUX) and not Defined(ANDROID)}
  GPauseForSleep := AOn;
  {$ELSE}
  GPauseForSleep := False;
  {$ENDIF}
end;

function InhibitPauseForSleep: Boolean;
begin
  Result := GPauseForSleep;
end;

function InhibitText: string;
begin
  Result := GText;
end;

{$IFDEF MSWINDOWS}
const
  { SetThreadExecutionState's flags. }
  ES_SYSTEM = $00000001;
  { The display too. }
  ES_DISPLAY = $00000002;
  { Until the next call. }
  ES_CONT = DWORD($80000000);

{ The thread's execution state from the counts. }
function Apply: Boolean;
var
  F: DWORD;
begin
  F := ES_CONT;
  if (GCount[ikSleep] > 0) or (GCount[ikDisplay] > 0) then
    F := F or ES_SYSTEM;
  if GCount[ikDisplay] > 0 then
    F := F or ES_DISPLAY;
  Result := SetThreadExecutionState(F) <> 0;
  if Result then
    GText := Format('SetThreadExecutionState($%x)', [F])
  else
    GText := 'SetThreadExecutionState failed';
end;
{$ENDIF}

{$IFDEF MSWINDOWS}
type
  { PROCESS_POWER_THROTTLING_STATE. }
  TPowerThrottling = record
    { PROCESS_POWER_THROTTLING_CURRENT_VERSION (1). }
    Version: ULONG;
    { What the call decides. }
    ControlMask: ULONG;
    { Which of those are on. }
    StateMask: ULONG;
  end;

const
  { ProcessPowerThrottling (PROCESS_INFORMATION_CLASS). }
  PROCESS_POWER_THROTTLING = 4;
  { PROCESS_POWER_THROTTLING_EXECUTION_SPEED: EcoQoS. }
  THROTTLE_SPEED = 1;
  { Windows' per-program graphics preferences (HKCU). }
  GPU_KEY = 'Software\Microsoft\DirectX\UserGpuPreferences';
  { The preference's name in a value's 'Name=Value;' list. }
  GPU_NAME = 'GpuPreference';

{$WARN SYMBOL_PLATFORM OFF}
{ SetProcessInformation (Windows 8 and later; 'delayed' is Windows-only -
  W1002, this unit's Windows part only). }
function SetProcessInformation(AProcess: THandle; AClass: Integer; AInfo: Pointer; ASize: DWORD): BOOL;
  stdcall; external kernel32 name 'SetProcessInformation' delayed;
{$WARN SYMBOL_PLATFORM ON}

{ EcoQoS on (AOn) or off, or left to Windows (not AControl). }
function WinSpeed(AControl, AOn: Boolean): string;
var
  T: TPowerThrottling;
begin
  T.Version := 1;
  T.ControlMask := 0;
  T.StateMask := 0;
  if AControl then
    T.ControlMask := THROTTLE_SPEED;
  if AControl and AOn then
    T.StateMask := THROTTLE_SPEED;
  try
    if SetProcessInformation(GetCurrentProcess, PROCESS_POWER_THROTTLING, @T, SizeOf(T)) then
      Result := Format('SetProcessInformation(PowerThrottling, control %d, state %d)', [T.ControlMask,
        T.StateMask])
    else
      Result := Format('SetProcessInformation(PowerThrottling) failed (%d)', [GetLastError]);
  except
    // not on this Windows (delayed: found at the first call)
    on E: Exception do
      Result := 'SetProcessInformation not available: ' + E.Message;
  end;
end;

{ The registry value's 'Name=Value;' list with GpuPreference set to
  AValue ('' removes it). }
function WithGpu(const AList, AValue: string): string;
var
  Parts: TArray<string>;
  P: string;
begin
  Result := '';
  Parts := AList.Split([';']);
  for P in Parts do
    if (Trim(P) <> '') and not ((Pos('=', P) > 0) and SameText(Trim(Copy(P, 1, Pos('=', P) - 1)), GPU_NAME)) then
      Result := Result + Trim(P) + ';';
  if AValue <> '' then
    Result := Result + GPU_NAME + '=' + AValue + ';';
end;
{$ENDIF}

{$IF Defined(MACOS) and not Defined(IOS)}
const
  { IOKit. }
  IOKitLib = '/System/Library/Frameworks/IOKit.framework/IOKit';
  { kIOPMAssertionLevelOn. }
  ASSERTION_ON = 255;

{ IOPMAssertionCreateWithName. }
function IOPMAssertionCreateWithName(AType: CFStringRef; ALevel: UInt32; AName: CFStringRef;
  out AId: UInt32): Int32; cdecl; external IOKitLib name 'IOPMAssertionCreateWithName';
{ IOPMAssertionRelease. }
function IOPMAssertionRelease(AId: UInt32): Int32; cdecl; external IOKitLib name 'IOPMAssertionRelease';

const
  { The Objective-C runtime. }
  ObjCLib = '/usr/lib/libobjc.dylib';
  { NSActivityUserInitiated: no App Nap, no idle system sleep. }
  ACTIVITY_USER_INITIATED = UInt64($00FFFFFF);
  { NSActivityLatencyCritical: no timer coalescing either. }
  ACTIVITY_LATENCY_CRITICAL = UInt64($FF00000000);

{ objc_getClass. }
function objc_getClass(AName: PAnsiChar): Pointer; cdecl; external ObjCLib name 'objc_getClass';
{ sel_registerName. }
function sel_registerName(AName: PAnsiChar): Pointer; cdecl; external ObjCLib name 'sel_registerName';
{ objc_msgSend for a message with no arguments that returns an object
  (each signature its own declaration: arm64 needs the exact one). }
function MsgSendObj(ASelf, AOp: Pointer): Pointer; cdecl; external ObjCLib name 'objc_msgSend';
{ objc_msgSend for beginActivityWithOptions:reason:. }
function MsgSendBegin(ASelf, AOp: Pointer; AOptions: UInt64; AReason: Pointer): Pointer; cdecl;
  external ObjCLib name 'objc_msgSend';
{ objc_msgSend for endActivity:. }
procedure MsgSendEnd(ASelf, AOp: Pointer; AActivity: Pointer); cdecl; external ObjCLib name 'objc_msgSend';

var
  { The assertion held per kind (0 = none). }
  GAssertion: array[TInhibitKind] of UInt32;
  { NSProcessInfo's activity, retained (nil = none). }
  GActivity: Pointer = nil;

{ AText as a CFString (the caller releases it). }
function CFStr(const AText: string): CFStringRef;
begin
  Result := CFStringCreateWithCString(nil, PAnsiChar(UTF8String(AText)), kCFStringEncodingUTF8);
end;

{ [NSProcessInfo processInfo]. }
function ProcessInfo: Pointer;
var
  C: Pointer;
begin
  Result := nil;
  C := objc_getClass('NSProcessInfo');
  if C <> nil then
    Result := MsgSendObj(C, sel_registerName('processInfo'));
end;

{ NSProcessInfo's activity begun (AOn) or ended.
  @returns(what was done) }
function ApplyActivity(AOn: Boolean; const AReason: string): string;
var
  P, A: Pointer;
  N: CFStringRef;
  R: string;
begin
  Result := '';
  if AOn then
  begin
    if GActivity <> nil then
      Exit('NSProcessInfo activity held already');
    P := ProcessInfo;
    if P = nil then
      Exit('no NSProcessInfo: macOS may slow the program down with the display off');
    R := AReason;
    if R = '' then
      R := 'Working';
    // a CFString is an NSString (toll-free bridged)
    N := CFStr(R);
    try
      A := MsgSendBegin(P, sel_registerName('beginActivityWithOptions:reason:'),
        ACTIVITY_USER_INITIATED or ACTIVITY_LATENCY_CRITICAL, N);
    finally
      CFRelease(N);
    end;
    if A = nil then
      Exit('NSProcessInfo activity not begun: macOS may slow the program down with the display off');
    // kept until endActivity: (the returned object may be autoreleased)
    GActivity := MsgSendObj(A, sel_registerName('retain'));
    Result := 'NSProcessInfo activity (user initiated, latency critical: no App Nap)';
  end
  else if GActivity <> nil then
  begin
    P := ProcessInfo;
    if P <> nil then
      MsgSendEnd(P, sel_registerName('endActivity:'), GActivity);
    MsgSendObj(GActivity, sel_registerName('release'));
    GActivity := nil;
    Result := 'NSProcessInfo activity ended (App Nap allowed)';
  end
  else
    Result := 'no NSProcessInfo activity (App Nap allowed)';
end;

const
  { The power source's type when on battery. }
  BATTERY_POWER = 'Battery Power';

{ IOPSCopyPowerSourcesInfo. }
function IOPSCopyPowerSourcesInfo: CFTypeRef; cdecl; external IOKitLib name 'IOPSCopyPowerSourcesInfo';
{ IOPSGetProvidingPowerSourceType. }
function IOPSGetProvidingPowerSourceType(ASnapshot: CFTypeRef): CFStringRef; cdecl;
  external IOKitLib name 'IOPSGetProvidingPowerSourceType';

{ The Mac's power source is its battery. }
function MacOnBattery: Boolean;
var
  Snap: CFTypeRef;
  T: CFStringRef;
  Buf: array[0..63] of AnsiChar;
begin
  Result := False;
  Snap := IOPSCopyPowerSourcesInfo;
  if Snap = nil then
    Exit;
  try
    T := IOPSGetProvidingPowerSourceType(Snap);
    if (T <> nil) and CFStringGetCString(T, @Buf[0], Length(Buf), kCFStringEncodingUTF8) then
      Result := string(UTF8String(PAnsiChar(@Buf[0]))) = BATTERY_POWER;
  finally
    CFRelease(Snap);
  end;
end;

{ The assertion of AKind taken or released from its count. }
function Apply(AKind: TInhibitKind; const AReason: string): Boolean;
const
  TYPES: array[TInhibitKind] of string = ('PreventUserIdleSystemSleep', 'PreventUserIdleDisplaySleep');
var
  T, N: CFStringRef;
  R: Int32;
begin
  Result := True;
  if (GCount[AKind] > 0) and (GAssertion[AKind] = 0) then
  begin
    T := CFStr(TYPES[AKind]);
    N := CFStr(AReason);
    try
      R := IOPMAssertionCreateWithName(T, ASSERTION_ON, N, GAssertion[AKind]);
    finally
      CFRelease(T);
      CFRelease(N);
    end;
    Result := R = 0;
    if Result then
      GText := Format('IOKit assertion %s (%d)', [TYPES[AKind], GAssertion[AKind]])
    else
    begin
      GAssertion[AKind] := 0;
      GText := Format('IOKit assertion %s failed (%d)', [TYPES[AKind], R]);
    end;
  end
  else if (GCount[AKind] = 0) and (GAssertion[AKind] <> 0) then
  begin
    IOPMAssertionRelease(GAssertion[AKind]);
    GText := Format('IOKit assertion %s released', [TYPES[AKind]]);
    GAssertion[AKind] := 0;
  end;
end;
{$ENDIF}

{$IF Defined(LINUX) and not Defined(ANDROID)}
type
  { DBusError (name, message, bit fields, padding) with room to spare. }
  TDBusError = record
    { Error name. }
    Name: PAnsiChar;
    { Error message. }
    Msg: PAnsiChar;
    { The rest, unread. }
    Rest: array[0..7] of Pointer;
  end;
  { DBusMessageIter (72 bytes on 64-bit), with room to spare. }
  TDBusIter = array[0..31] of Pointer;

const
  { DBUS_BUS_SESSION. }
  BUS_SESSION = 0;
  { DBUS_BUS_SYSTEM. }
  BUS_SYSTEM = 1;
  { Reply timeout, ms. }
  TIMEOUT_MS = 3000;

var
  { libdbus-1, 0 = not loaded. }
  GLib: HMODULE = 0;
  { The library was looked for. }
  GTried: Boolean = False;
  { dbus_error_init. }
  dbus_error_init: procedure(E: Pointer); cdecl;
  { dbus_error_free. }
  dbus_error_free: procedure(E: Pointer); cdecl;
  { dbus_bus_get_private. }
  dbus_bus_get_private: function(AType: Integer; E: Pointer): Pointer; cdecl;
  { dbus_connection_set_exit_on_disconnect. }
  dbus_connection_set_exit_on_disconnect: procedure(C: Pointer; AExit: Cardinal); cdecl;
  { dbus_message_new_method_call. }
  dbus_message_new_method_call: function(ADest, APath, AIface, AMethod: PAnsiChar): Pointer; cdecl;
  { dbus_message_iter_init_append. }
  dbus_message_iter_init_append: procedure(M: Pointer; It: Pointer); cdecl;
  { dbus_message_iter_append_basic. }
  dbus_message_iter_append_basic: function(It: Pointer; AType: Integer; AValue: Pointer): Cardinal; cdecl;
  { dbus_connection_send_with_reply_and_block. }
  dbus_connection_send_with_reply_and_block: function(C, M: Pointer; ATimeout: Integer; E: Pointer): Pointer; cdecl;
  { dbus_message_iter_init. }
  dbus_message_iter_init: function(M: Pointer; It: Pointer): Cardinal; cdecl;
  { dbus_message_iter_get_arg_type. }
  dbus_message_iter_get_arg_type: function(It: Pointer): Integer; cdecl;
  { dbus_message_iter_get_basic. }
  dbus_message_iter_get_basic: procedure(It: Pointer; AValue: Pointer); cdecl;
  { dbus_message_unref. }
  dbus_message_unref: procedure(M: Pointer); cdecl;
  { dbus_connection_close. }
  dbus_connection_close: procedure(C: Pointer); cdecl;
  { dbus_connection_unref. }
  dbus_connection_unref: procedure(C: Pointer); cdecl;
  { dbus_bus_add_match. }
  dbus_bus_add_match: procedure(C: Pointer; ARule: PAnsiChar; E: Pointer); cdecl;
  { dbus_connection_read_write. }
  dbus_connection_read_write: function(C: Pointer; ATimeout: Integer): Cardinal; cdecl;
  { dbus_connection_pop_message. }
  dbus_connection_pop_message: function(C: Pointer): Pointer; cdecl;
  { dbus_message_is_signal. }
  dbus_message_is_signal: function(M: Pointer; AIface, AName: PAnsiChar): Cardinal; cdecl;
  { The private bus connections (nil = not open). }
  GSystem: Pointer = nil;
  { The session bus. }
  GSession: Pointer = nil;
  { logind's inhibitor: kept while this descriptor is open (-1 = none). }
  GFd: Integer = -1;
  { org.freedesktop.ScreenSaver's cookie. }
  GCookie: Cardinal = 0;
  { GCookie is held. }
  GHasCookie: Boolean = False;
  { The system bus sends logind's PrepareForSleep here (InhibitPoll). }
  GMatched: Boolean = False;
  { Between ssGoingToSleep and ssWoke: the delay is not asked for again. }
  GAsleep: Boolean = False;
  { The reason given with the last InhibitStart (asked again after a
    wake). }
  GReason: string;

{ libdbus-1 and its functions. @returns(False when it is not there) }
function LoadDBus: Boolean;

  function P(const AName: string): Pointer;
  begin
    Result := GetProcAddress(GLib, PChar(AName));
    if Result = nil then
      raise Exception.Create('no ' + AName);
  end;

begin
  if GTried then
    Exit(GLib <> 0);
  GTried := True;
  GLib := LoadLibrary('libdbus-1.so.3');
  if GLib = 0 then
    Exit(False);
  try
    @dbus_error_init := P('dbus_error_init');
    @dbus_error_free := P('dbus_error_free');
    @dbus_bus_get_private := P('dbus_bus_get_private');
    @dbus_connection_set_exit_on_disconnect := P('dbus_connection_set_exit_on_disconnect');
    @dbus_message_new_method_call := P('dbus_message_new_method_call');
    @dbus_message_iter_init_append := P('dbus_message_iter_init_append');
    @dbus_message_iter_append_basic := P('dbus_message_iter_append_basic');
    @dbus_connection_send_with_reply_and_block := P('dbus_connection_send_with_reply_and_block');
    @dbus_message_iter_init := P('dbus_message_iter_init');
    @dbus_message_iter_get_arg_type := P('dbus_message_iter_get_arg_type');
    @dbus_message_iter_get_basic := P('dbus_message_iter_get_basic');
    @dbus_message_unref := P('dbus_message_unref');
    @dbus_connection_close := P('dbus_connection_close');
    @dbus_connection_unref := P('dbus_connection_unref');
    @dbus_bus_add_match := P('dbus_bus_add_match');
    @dbus_connection_read_write := P('dbus_connection_read_write');
    @dbus_connection_pop_message := P('dbus_connection_pop_message');
    @dbus_message_is_signal := P('dbus_message_is_signal');
  except
    FreeLibrary(GLib);
    GLib := 0;
  end;
  Result := GLib <> 0;
end;

{ AErr's text, freed. }
function ErrText(var AErr: TDBusError): string;
begin
  if AErr.Name <> nil then
    Result := string(UTF8String(AErr.Name)) + ': ' + string(UTF8String(AErr.Msg))
  else
    Result := 'no reply';
  dbus_error_free(@AErr);
end;

{ The private connection to bus ABus (opened once).
  @returns(nil with AWhy set when it cannot be opened) }
function Bus(ABus: Integer; out AWhy: string): Pointer;
var
  E: TDBusError;
begin
  AWhy := '';
  if ABus = BUS_SYSTEM then
    Result := GSystem
  else
    Result := GSession;
  if Result <> nil then
    Exit;
  dbus_error_init(@E);
  Result := dbus_bus_get_private(ABus, @E);
  if Result = nil then
  begin
    AWhy := ErrText(E);
    Exit;
  end;
  dbus_error_free(@E);
  // a bus that goes away must not end the program (libdbus' default)
  dbus_connection_set_exit_on_disconnect(Result, 0);
  if ABus = BUS_SYSTEM then
    GSystem := Result
  else
    GSession := Result;
end;

{ Calls AMethod with string arguments AArgs (and AUInt as a 'u' after
  them when AWithUInt). @returns(the reply - the caller unrefs it - or nil
  with AWhy set) }
function Call(ABus: Integer; const ADest, APath, AIface, AMethod: string; const AArgs: array of string;
  AWithUInt: Boolean; AUInt: Cardinal; out AWhy: string): Pointer;
var
  C, M: Pointer;
  It: TDBusIter;
  S: array of UTF8String;
  P: PAnsiChar;
  U: Cardinal;
  E: TDBusError;
  I: Integer;
begin
  Result := nil;
  C := Bus(ABus, AWhy);
  if C = nil then
    Exit;
  M := dbus_message_new_method_call(PAnsiChar(UTF8String(ADest)), PAnsiChar(UTF8String(APath)),
    PAnsiChar(UTF8String(AIface)), PAnsiChar(UTF8String(AMethod)));
  if M = nil then
  begin
    AWhy := 'no message';
    Exit;
  end;
  try
    FillChar(It, SizeOf(It), 0);
    dbus_message_iter_init_append(M, @It);
    // the strings stay alive until the call is made
    SetLength(S, Length(AArgs));
    for I := 0 to High(AArgs) do
    begin
      S[I] := UTF8String(AArgs[I]);
      P := PAnsiChar(S[I]);
      dbus_message_iter_append_basic(@It, Ord('s'), @P);
    end;
    if AWithUInt then
    begin
      U := AUInt;
      dbus_message_iter_append_basic(@It, Ord('u'), @U);
    end;
    dbus_error_init(@E);
    Result := dbus_connection_send_with_reply_and_block(C, M, TIMEOUT_MS, @E);
    if Result = nil then
      AWhy := ErrText(E)
    else
      dbus_error_free(@E);
  finally
    dbus_message_unref(M);
  end;
end;

{ The first argument of reply AReply when it is of type AType, into
  AValue. @returns(False when the reply has no such argument) }
function ReplyArg(AReply: Pointer; AType: AnsiChar; AValue: Pointer): Boolean;
var
  It: TDBusIter;
begin
  FillChar(It, SizeOf(It), 0);
  Result := (dbus_message_iter_init(AReply, @It) <> 0) and (dbus_message_iter_get_arg_type(@It) = Ord(AType));
  if Result then
    dbus_message_iter_get_basic(@It, AValue);
end;

{ Asks the system bus for logind's PrepareForSleep (read by InhibitPoll).
  @returns(what was done, for InhibitText) }
function AddSleepMatch: string;
var
  E: TDBusError;
begin
  dbus_error_init(@E);
  dbus_bus_add_match(GSystem, PAnsiChar(UTF8String('type=''signal'',interface=''org.freedesktop.login1.Manager'',' +
    'member=''PrepareForSleep''')), @E);
  if E.Name <> nil then
    Exit('PrepareForSleep not received: ' + ErrText(E));
  dbus_error_free(@E);
  GMatched := True;
  Result := 'listening for PrepareForSleep';
end;

{ logind's and the screen saver's inhibitors from the counts. }
function Apply(const AReason: string): Boolean;
var
  R: Pointer;
  Why, App, Done: string;
  Fd: Integer;
  Cookie: Cardinal;
begin
  Done := '';
  if not LoadDBus then
  begin
    GText := 'no libdbus-1.so.3: nothing keeps the computer awake';
    Exit(False);
  end;
  App := ChangeFileExt(ExtractFileName(ParamStr(0)), '');
  if AReason <> '' then
    GReason := AReason;
  // Steam's Game Mode: sleep is let happen - only a delay, to pause the
  // work first (refused, Steam was left stuck: owner, 2026-11-20)
  if GPauseForSleep and (GCount[ikDisplay] = 0) and (GCount[ikSleep] > 0) and (GFd < 0) and not GAsleep then
  begin
    R := Call(BUS_SYSTEM, 'org.freedesktop.login1', '/org/freedesktop/login1', 'org.freedesktop.login1.Manager',
      'Inhibit', ['sleep', App, GReason, 'delay'], False, 0, Why);
    if R <> nil then
    begin
      Fd := -1;
      if ReplyArg(R, 'h', @Fd) and (Fd >= 0) then
      begin
        GFd := Fd;
        Done := Done + Format('Game Mode - sleep allowed, the work pauses for it: logind sleep delay (fd %d)' +
          '; ', [Fd]);
      end
      else
        Done := Done + 'logind Inhibit (delay): no descriptor in the reply; ';
      dbus_message_unref(R);
    end
    else
      Done := Done + 'logind Inhibit (delay): ' + Why + '; ';
    if not GMatched and (GSystem <> nil) then
      Done := Done + AddSleepMatch + '; ';
  end
  // the computer: logind, while the descriptor is open
  else if not GPauseForSleep and ((GCount[ikSleep] > 0) or (GCount[ikDisplay] > 0)) and (GFd < 0) then
  begin
    R := Call(BUS_SYSTEM, 'org.freedesktop.login1', '/org/freedesktop/login1', 'org.freedesktop.login1.Manager',
      'Inhibit', ['sleep:idle', App, AReason, 'block'], False, 0, Why);
    if R <> nil then
    begin
      Fd := -1;
      if ReplyArg(R, 'h', @Fd) and (Fd >= 0) then
      begin
        GFd := Fd;
        Done := Done + Format('logind sleep:idle inhibitor (fd %d); ', [Fd]);
      end
      else
        Done := Done + 'logind Inhibit: no descriptor in the reply; ';
      dbus_message_unref(R);
    end
    else
      Done := Done + 'logind Inhibit: ' + Why + '; ';
  end
  else if (GCount[ikSleep] = 0) and (GCount[ikDisplay] = 0) and (GFd >= 0) then
  begin
    __close(GFd);
    GFd := -1;
    Done := Done + 'logind inhibitor released; ';
  end;
  // the screen: the session's screen saver
  if (GCount[ikDisplay] > 0) and not GHasCookie then
  begin
    R := Call(BUS_SESSION, 'org.freedesktop.ScreenSaver', '/org/freedesktop/ScreenSaver',
      'org.freedesktop.ScreenSaver', 'Inhibit', [App, AReason], False, 0, Why);
    if R <> nil then
    begin
      Cookie := 0;
      if ReplyArg(R, 'u', @Cookie) then
      begin
        GCookie := Cookie;
        GHasCookie := True;
        Done := Done + Format('ScreenSaver.Inhibit (cookie %d); ', [Cookie]);
      end;
      dbus_message_unref(R);
    end
    else
      Done := Done + 'ScreenSaver.Inhibit: ' + Why + '; ';
  end
  else if (GCount[ikDisplay] = 0) and GHasCookie then
  begin
    R := Call(BUS_SESSION, 'org.freedesktop.ScreenSaver', '/org/freedesktop/ScreenSaver',
      'org.freedesktop.ScreenSaver', 'UnInhibit', [], True, GCookie, Why);
    if R <> nil then
      dbus_message_unref(R);
    GHasCookie := False;
    Done := Done + 'ScreenSaver.UnInhibit; ';
  end;
  GText := Trim(Done);
  if GText.EndsWith(';') then
    GText := Copy(GText, 1, Length(GText) - 1);
  Result := (GFd >= 0) or GHasCookie;
end;

{ Everything released, the connections closed (at the end of the
  program). }
procedure CloseAll;
begin
  if GFd >= 0 then
  begin
    __close(GFd);
    GFd := -1;
  end;
  if GLib = 0 then
    Exit;
  if GSystem <> nil then
  begin
    dbus_connection_close(GSystem);
    dbus_connection_unref(GSystem);
    GSystem := nil;
  end;
  if GSession <> nil then
  begin
    // the screen saver forgets a connection's inhibits when it closes
    dbus_connection_close(GSession);
    dbus_connection_unref(GSession);
    GSession := nil;
  end;
end;
{$ENDIF}

function InhibitStart(AKind: TInhibitKind; const AReason: string): Boolean;
begin
  Inc(GCount[AKind]);
  try
    {$IF Defined(MSWINDOWS)}
    Result := Apply;
    {$ELSEIF Defined(MACOS) and not Defined(IOS)}
    Result := Apply(AKind, AReason);
    {$ELSEIF Defined(LINUX) and not Defined(ANDROID)}
    Result := Apply(AReason);
    {$ELSE}
    GText := 'not on this system';
    Result := False;
    {$ENDIF}
  except
    on E: Exception do
    begin
      GText := 'keeping awake failed: ' + E.Message;
      Result := False;
    end;
  end;
end;

procedure InhibitStop(AKind: TInhibitKind);
begin
  if GCount[AKind] <= 0 then
    Exit;
  Dec(GCount[AKind]);
  try
    {$IF Defined(MSWINDOWS)}
    Apply;
    {$ELSEIF Defined(MACOS) and not Defined(IOS)}
    Apply(AKind, '');
    {$ELSEIF Defined(LINUX) and not Defined(ANDROID)}
    Apply('');
    {$ENDIF}
  except
    on E: Exception do
      GText := 'releasing failed: ' + E.Message;
  end;
end;

function InhibitPoll: TSleepSignal;
{$IF Defined(LINUX) and not Defined(ANDROID)}
var
  M: Pointer;
  B: Cardinal;
begin
  Result := ssNone;
  if not GPauseForSleep or not GMatched or (GSystem = nil) then
    Exit;
  try
    // what has come in, without waiting
    dbus_connection_read_write(GSystem, 0);
    repeat
      M := dbus_connection_pop_message(GSystem);
      if M = nil then
        Break;
      try
        if dbus_message_is_signal(M, 'org.freedesktop.login1.Manager', 'PrepareForSleep') <> 0 then
        begin
          B := 0;
          if ReplyArg(M, 'b', @B) then
            if B <> 0 then
            begin
              GAsleep := True;
              Result := ssGoingToSleep;
            end
            else
            begin
              GAsleep := False;
              Result := ssWoke;
              // the delay again, for the next sleep
              Apply('');
            end;
        end;
      finally
        dbus_message_unref(M);
      end;
    until False;
  except
    on E: Exception do
      GText := 'reading the system bus failed: ' + E.Message;
  end;
end;
{$ELSE}
begin
  Result := ssNone;
end;
{$ENDIF}

procedure InhibitLetSleep;
begin
  {$IF Defined(LINUX) and not Defined(ANDROID)}
  if GFd >= 0 then
  begin
    __close(GFd);
    GFd := -1;
    GText := 'logind sleep delay given back: the computer sleeps';
  end
  else
    GText := 'no sleep delay was held';
  {$ENDIF}
end;

function InhibitSpeed(ASpeed: TInhibitSpeed): string;
begin
  try
    {$IF Defined(MSWINDOWS)}
    Result := WinSpeed(ASpeed <> isSystem, ASpeed = isSaving);
    {$ELSEIF Defined(MACOS) and not Defined(IOS)}
    Result := ApplyActivity(ASpeed = isFast, 'Building an audiobook');
    {$ELSE}
    Result := 'the speed is left to the system here';
    {$ENDIF}
  except
    on E: Exception do
      Result := 'setting the speed failed: ' + E.Message;
  end;
end;

function OnBattery: Boolean;
{$IF Defined(MSWINDOWS)}
var
  S: TSystemPowerStatus;
begin
  // ACLineStatus 0 = offline (255 = unknown: a desktop, mains)
  Result := GetSystemPowerStatus(S) and (S.ACLineStatus = 0);
end;
{$ELSEIF Defined(MACOS) and not Defined(IOS)}
begin
  try
    Result := MacOnBattery;
  except
    Result := False;
  end;
end;
{$ELSEIF Defined(LINUX) and not Defined(ANDROID)}
var
  D, Kind: string;
begin
  // a battery that discharges (a Steam Deck unplugged)
  Result := False;
  try
    if not TDirectory.Exists('/sys/class/power_supply') then
      Exit;
    for D in TDirectory.GetDirectories('/sys/class/power_supply') do
    begin
      if not FileExists(TPath.Combine(D, 'type')) or not FileExists(TPath.Combine(D, 'status')) then
        Continue;
      Kind := Trim(TFile.ReadAllText(TPath.Combine(D, 'type')));
      if SameText(Kind, 'Battery') and SameText(Trim(TFile.ReadAllText(TPath.Combine(D, 'status'))),
        'Discharging') then
        Exit(True);
    end;
  except
    Result := False;
  end;
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

function GpuPreference: TGpuPreference;
{$IFDEF MSWINDOWS}
var
  R: TRegistry;
  P, V: string;
begin
  Result := gpSystem;
  R := TRegistry.Create(KEY_READ);
  try
    R.RootKey := HKEY_CURRENT_USER;
    if R.OpenKeyReadOnly(GPU_KEY) and R.ValueExists(ParamStr(0)) then
      for P in R.ReadString(ParamStr(0)).Split([';']) do
        if (Pos('=', P) > 0) and SameText(Trim(Copy(P, 1, Pos('=', P) - 1)), GPU_NAME) then
        begin
          V := Trim(Copy(P, Pos('=', P) + 1, MaxInt));
          if V = '1' then
            Result := gpSaving
          else if V = '2' then
            Result := gpFast;
        end;
  except
    Result := gpSystem;
  end;
  R.Free;
end;
{$ELSE}
begin
  Result := gpSystem;
end;
{$ENDIF}

function SetGpuPreference(APreference: TGpuPreference): Boolean;
{$IFDEF MSWINDOWS}
const
  VALUES: array[TGpuPreference] of string = ('', '1', '2');
var
  R: TRegistry;
  Old, Value: string;
begin
  Result := False;
  R := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    try
      R.RootKey := HKEY_CURRENT_USER;
      if not R.OpenKey(GPU_KEY, True) then
        Exit;
      Old := '';
      if R.ValueExists(ParamStr(0)) then
        Old := R.ReadString(ParamStr(0));
      // other settings of the program in the same value are kept
      Value := WithGpu(Old, VALUES[APreference]);
      if Value = '' then
      begin
        if R.ValueExists(ParamStr(0)) then
          R.DeleteValue(ParamStr(0));
      end
      else
        R.WriteString(ParamStr(0), Value);
      Result := True;
    except
      Result := False;
    end;
  finally
    R.Free;
  end;
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

initialization

finalization
  {$IF Defined(LINUX) and not Defined(ANDROID)}
  CloseAll;
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  SetThreadExecutionState(ES_CONT);
  {$ENDIF}
end.
