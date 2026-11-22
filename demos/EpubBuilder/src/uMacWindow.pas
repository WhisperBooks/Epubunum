{ @abstract(macOS: EpubBuilder's window made full screen in Big Picture,
  through Cocoa.)

  Owner, 2026-11-21 (zip 210): "Big Picture fails - when app starts it
  starts in normal mode not full screen ... I got the correct view just in
  a Window". Owner, 2026-11-22, after zip 210 (FMX's FullScreen asked for
  again, three times): "Mac Big Picture - Still not Full Screen".

  FMX's FullScreen is not trusted here: it can read True while the window
  is an ordinary one (FMX keeps its own idea of the state), and its
  request is ignored by macOS when the window may not have a full-screen
  Space of its own (its collection behaviour). So the window's real state
  is read from the NSWindow (MacIsFullScreen), full screen is allowed
  before it is asked for (MacMakeFullScreen), and if macOS still says no,
  the window covers the screen with the menu bar and the Dock hidden
  (MacCoverScreen).

  Game Mode does not do it: macOS turns Game Mode on for a game that is
  already full screen; it does not make a window full screen.

  Other systems: MacIsFullScreen reads FMX's FullScreen; the others do
  nothing. }
unit uMacWindow;

interface

uses
  FMX.Forms;

{ Whether AForm's window is full screen: on macOS its real state - in a
  full-screen Space of its own, or covering the screen by MacCoverScreen.
  @param(AForm  the form)
  @returns(the answer; other systems: AForm.FullScreen) }
function MacIsFullScreen(AForm: TCommonCustomForm): Boolean;

{ macOS: makes AForm's window full screen the Mac's way (a Space of its
  own): full screen allowed for it first, the program and the window
  brought to the front, then asked for. Done only while the window is not
  full screen (asking again would take it out).
  @param(AForm  the form)
  @returns(a line for the debug log: what was found and done) }
function MacMakeFullScreen(AForm: TCommonCustomForm): string;

{ macOS: when MacMakeFullScreen did not take - the window without a frame,
  over the whole display, the menu bar and the Dock hidden while the
  program is in front.
  @param(AForm  the form)
  @returns(a line for the debug log) }
function MacCoverScreen(AForm: TCommonCustomForm): string;

implementation

uses
  {$IF Defined(MACOS) and not Defined(IOS)}
  Macapi.AppKit, Macapi.CocoaTypes, FMX.Platform.Mac, FMX.Types,
  {$ENDIF}
  System.SysUtils;

{$IF Defined(MACOS) and not Defined(IOS)}
const
  { NSWindowStyleMaskFullScreen: the window is in full screen. }
  MAC_STYLE_FULL_SCREEN = NSUInteger(1) shl 14;
  { NSWindowCollectionBehaviorFullScreenPrimary: the window may have a
    full-screen Space. }
  MAC_BEHAVIOUR_PRIMARY = NSUInteger(1) shl 7;
  { NSWindowCollectionBehaviorFullScreenAuxiliary: shown beside another's
    full screen only. }
  MAC_BEHAVIOUR_AUXILIARY = NSUInteger(1) shl 8;
  { NSWindowCollectionBehaviorFullScreenNone: never full screen. }
  MAC_BEHAVIOUR_NONE = NSUInteger(1) shl 9;
  { NSApplicationPresentationHideDock. }
  MAC_HIDE_DOCK = NSUInteger(1) shl 1;
  { NSApplicationPresentationHideMenuBar (needs MAC_HIDE_DOCK). }
  MAC_HIDE_MENU_BAR = NSUInteger(1) shl 3;

var
  { MacCoverScreen has covered the screen with this form's window. }
  GCovered: TCommonCustomForm;

{ The NSWindow of AForm, or nil before it has one. }
function WindowOf(AForm: TCommonCustomForm): NSWindow;
begin
  Result := nil;
  if (AForm = nil) or (AForm.Handle = nil) then
    Exit;
  Result := WindowHandleToPlatform(AForm.Handle).Wnd;
end;

{ The application object. }
function MacApp: NSApplication;
begin
  Result := TNSApplication.Wrap(TNSApplication.OCClass.sharedApplication);
end;
{$ENDIF}

function MacIsFullScreen(AForm: TCommonCustomForm): Boolean;
{$IF Defined(MACOS) and not Defined(IOS)}
var
  W: NSWindow;
{$ENDIF}
begin
  {$IF Defined(MACOS) and not Defined(IOS)}
  Result := False;
  if (GCovered <> nil) and (GCovered = AForm) then
    Exit(True);
  W := WindowOf(AForm);
  if W = nil then
    Exit;
  Result := (NSUInteger(W.styleMask) and MAC_STYLE_FULL_SCREEN) <> 0;
  {$ELSE}
  Result := (AForm <> nil) and AForm.FullScreen;
  {$ENDIF}
end;

function MacMakeFullScreen(AForm: TCommonCustomForm): string;
{$IF Defined(MACOS) and not Defined(IOS)}
var
  W: NSWindow;
  Before, Behaviour: NSUInteger;
{$ENDIF}
begin
  {$IF Defined(MACOS) and not Defined(IOS)}
  W := WindowOf(AForm);
  if W = nil then
    Exit('no window yet');
  if MacIsFullScreen(AForm) then
    Exit('already full screen');
  Before := NSUInteger(W.collectionBehavior);
  // full screen allowed: Primary on, Auxiliary and None off (a window
  // without Primary ignores toggleFullScreen without a word)
  Behaviour := (Before or MAC_BEHAVIOUR_PRIMARY) and not (MAC_BEHAVIOUR_AUXILIARY or MAC_BEHAVIOUR_NONE);
  if Behaviour <> Before then
    W.setCollectionBehavior(Behaviour);
  MacApp.activateIgnoringOtherApps(True);
  W.makeKeyAndOrderFront(nil);
  W.toggleFullScreen(nil);
  Result := Format('FMX full screen %s, visible %s, collection behaviour $%x -> $%x, full screen asked for',
    [BoolToStr(AForm.FullScreen, True), BoolToStr(W.isVisible, True), Before, Behaviour]);
  {$ELSE}
  Result := 'not macOS';
  {$ENDIF}
end;

function MacCoverScreen(AForm: TCommonCustomForm): string;
{$IF Defined(MACOS) and not Defined(IOS)}
var
  W: NSWindow;
  F: NSRect;
{$ENDIF}
begin
  {$IF Defined(MACOS) and not Defined(IOS)}
  if WindowOf(AForm) = nil then
    Exit('no window yet');
  // the menu bar and the Dock hidden while this program is in front
  MacApp.setPresentationOptions(MAC_HIDE_DOCK or MAC_HIDE_MENU_BAR);
  // no title bar or frame (FMX may make the window again for it: it is
  // looked up after)
  AForm.BorderStyle := TFmxFormBorderStyle.None;
  W := WindowOf(AForm);
  if (W = nil) or (W.screen = nil) then
    Exit('no window or display after the frame was taken off');
  // the whole display (Cocoa's frame, in points from the bottom left - the
  // display's own)
  F := W.screen.frame;
  W.setFrame(F, True);
  MacApp.activateIgnoringOtherApps(True);
  W.makeKeyAndOrderFront(nil);
  GCovered := AForm;
  Result := Format('the window covers the display (%.0f x %.0f points), menu bar and Dock hidden',
    [F.size.width, F.size.height]);
  {$ELSE}
  Result := 'not macOS';
  {$ENDIF}
end;

end.
