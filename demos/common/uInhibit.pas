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

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  {$IF Defined(MACOS) and not Defined(IOS)}
  Macapi.CoreFoundation,
  {$ENDIF}
  {$IF Defined(LINUX) and not Defined(ANDROID)}
  Posix.Unistd,
  {$ENDIF}
  System.SysUtils;

var
  { Starts not yet stopped, per kind. }
  GCount: array[TInhibitKind] of Integer;
  { See InhibitText. }
  GText: string;

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

var
  { The assertion held per kind (0 = none). }
  GAssertion: array[TInhibitKind] of UInt32;

{ AText as a CFString (the caller releases it). }
function CFStr(const AText: string): CFStringRef;
begin
  Result := CFStringCreateWithCString(nil, PAnsiChar(UTF8String(AText)), kCFStringEncodingUTF8);
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
  // the computer: logind, while the descriptor is open
  if ((GCount[ikSleep] > 0) or (GCount[ikDisplay] > 0)) and (GFd < 0) then
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

initialization

finalization
  {$IF Defined(LINUX) and not Defined(ANDROID)}
  CloseAll;
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  SetThreadExecutionState(ES_CONT);
  {$ENDIF}
end.
