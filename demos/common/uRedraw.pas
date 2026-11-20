(* @abstract(Linux (Steam Game Mode): the window brought back after the
  display or Steam's screen saver - gamescope can show it black.)

  The Steam Machine, 2026-11-20: after the screen saver or a display that
  went off, the program stayed black, also after Steam button > Resume Game.
  Drawing the whole window every two seconds (zip 164) did not bring it
  back. So now, besides that:

  @unorderedList(
    @item(the window's size changes by one pixel and back - a new frame of
      a new size, which gamescope must take; full screen (Big Picture): out
      of full screen and back;)
    @item(that happens when the window is active again, when a display comes
      on (@code(/sys/class/drm/*/dpms)), when the timer was held up and
      (EpubBuilder) at the first pad press after a minute without one;)
    @item(each of these goes into the debug log (@code(redraw: ...)), so a
      test shows what the program heard.))

  Other systems: nothing (the object does nothing). *)
unit uRedraw;

interface

uses
  System.Classes, System.Types, FMX.Types, FMX.Forms;

type
  { Brings a window back on Linux: see the unit's description. One per
    window, owned by it. }
  TWindowRedraw = class(TComponent)
  private
    { The window. }
    FForm: TCommonCustomForm;
    { Every two seconds: the window drawn whole, the displays looked at. }
    FTimer: TTimer;
    { A third of a second after the size changed: the size put back. }
    FRestoreTimer: TTimer;
    { The window's place and size before the change. }
    FSaved: TRect;
    { The size is changed now (FRestoreTimer to put it back). }
    FChanged: Boolean;
    { The window was taken out of full screen now (FRestoreTimer to put it
      back). }
    FUnFull: Boolean;
    { The last tick (ms, TThread.GetTickCount64). }
    FLastTick: UInt64;
    { The last time the window was brought back (ms). }
    FLastKick: UInt64;
    { The last pad press (ms) - UserInput. }
    FLastInput: UInt64;
    { The displays as last read ('card0-HDMI-A-1=On ...'), '(none read)'
      when none could be read, '' before the first time. }
    FDisplays: string;
    { Draws the window and looks at the displays. }
    procedure Tick(Sender: TObject);
    { Puts the size back. }
    procedure Restore(Sender: TObject);
    { The connected displays and their power ('card0-HDMI-A-1=On'),
      sorted, one space apart; '' when none can be read. }
    function ReadDisplays: string;
  public
    { Starts it (Linux only).
      @param(AForm  the window, which owns the object) }
    constructor Create(AForm: TCommonCustomForm); reintroduce;
    { Brings the window back: drawn whole, its size changed by a pixel and
      back. Not more than once in two seconds.
      @param(AWhy  for the debug log) }
    procedure Kick(const AWhy: string);
    { The window is active again (OnActivate): logged and brought back. }
    procedure Activated;
    { The window is not active any more (OnDeactivate): logged. }
    procedure Deactivated;
    { A pad button was pressed: brought back when it is the first for a
      minute (the screen may have been black). }
    procedure UserInput;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.StrUtils, System.UITypes, uDebugLog;

const
  { Draw and look at the displays every ... ms. }
  TICK_MS = 2000;
  { A tick this late (ms): the program was held up. }
  LATE_MS = 10000;
  { Input after this long (ms) without any brings the window back. }
  QUIET_MS = 60000;
  { Not brought back more often than this (ms). }
  KICK_GAP_MS = 2000;
  { Linux: brought back; other systems: nothing. }
  REDRAW_ON = {$IF Defined(LINUX) and not Defined(ANDROID)} True {$ELSE} False {$ENDIF};

constructor TWindowRedraw.Create(AForm: TCommonCustomForm);
begin
  inherited Create(AForm);
  FForm := AForm;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := TICK_MS;
  FTimer.OnTimer := Tick;
  FTimer.Enabled := REDRAW_ON;
  FRestoreTimer := TTimer.Create(Self);
  FRestoreTimer.Interval := 500;
  FRestoreTimer.OnTimer := Restore;
  FRestoreTimer.Enabled := False;
  FLastInput := TThread.GetTickCount64;
  // not at start-up (the first activation): nothing to bring back yet
  FLastKick := FLastInput;
end;

function TWindowRedraw.ReadDisplays: string;
{$IF Defined(LINUX) and not Defined(ANDROID)}
var
  L: TStringList;
  D, Status, Power: string;
begin
  Result := '';
  L := TStringList.Create;
  try
    try
      // card0-HDMI-A-1, card1-DP-1 ... (not card0 itself); the entries are
      // links, which GetDirectories leaves out (zip 167 read none)
      for D in TDirectory.GetFileSystemEntries('/sys/class/drm', 'card*-*') do
      begin
        Status := '';
        Power := '?';
        if TFile.Exists(TPath.Combine(D, 'status')) then
          Status := Trim(TFile.ReadAllText(TPath.Combine(D, 'status')));
        if Status <> 'connected' then
          Continue;
        if TFile.Exists(TPath.Combine(D, 'dpms')) then
          Power := Trim(TFile.ReadAllText(TPath.Combine(D, 'dpms')));
        L.Add(ExtractFileName(D) + '=' + Power);
      end;
    except
      // not readable: what was read
    end;
    L.Sort;
    Result := Trim(ReplaceStr(L.Text, sLineBreak, ' '));
    if Result = '' then
      Result := '(none read)';
  finally
    L.Free;
  end;
end;
{$ELSE}
begin
  Result := '';
end;
{$ENDIF}

procedure TWindowRedraw.Tick(Sender: TObject);
var
  T: UInt64;
  Cur, Was: string;
begin
  try
    FForm.Invalidate;
    T := TThread.GetTickCount64;
    if (FLastTick <> 0) and (T - FLastTick > LATE_MS) then
      Kick(Format('the timer was held up %d s', [(T - FLastTick) div 1000]));
    FLastTick := T;
    Cur := ReadDisplays;
    if Cur <> FDisplays then
    begin
      Was := FDisplays;
      FDisplays := Cur;
      DebugLog('redraw: displays ' + Cur);
      // one that was off is on again
      if Was.Contains('=Off') and Cur.Contains('=On') then
        Kick('a display came on');
    end;
  except
    on E: Exception do
      DebugLog('redraw: ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TWindowRedraw.Kick(const AWhy: string);
var
  T: UInt64;
begin
  if not REDRAW_ON then
    Exit;
  T := TThread.GetTickCount64;
  if (FLastKick <> 0) and (T - FLastKick < KICK_GAP_MS) then
    Exit;
  FLastKick := T;
  try
    DebugLog(Format('redraw: %s - window %d x %d, active %s, state %d, full screen %s',
      [AWhy, FForm.Width, FForm.Height, BoolToStr(FForm.Active, True), Ord(FForm.WindowState),
      BoolToStr(FForm.FullScreen, True)]));
    FForm.Invalidate;
    if FChanged or FUnFull then
      Exit;
    // full screen (Big Picture): out of it and back - a new frame of a new
    // size (zip 167 left these alone: nothing changed)
    if FForm.FullScreen then
    begin
      FUnFull := True;
      FForm.FullScreen := False;
      FRestoreTimer.Enabled := True;
      Exit;
    end;
    if FForm.WindowState <> TWindowState.wsNormal then
      Exit;
    FSaved := TRect.Create(TPoint.Create(FForm.Left, FForm.Top), FForm.Width, FForm.Height);
    FChanged := True;
    FForm.SetBounds(FSaved.Left, FSaved.Top, FSaved.Width, FSaved.Height - 1);
    FRestoreTimer.Enabled := True;
  except
    on E: Exception do
      DebugLog('redraw: ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TWindowRedraw.Restore(Sender: TObject);
begin
  FRestoreTimer.Enabled := False;
  try
    if FUnFull then
      FForm.FullScreen := True
    else if FChanged then
      FForm.SetBounds(FSaved.Left, FSaved.Top, FSaved.Width, FSaved.Height);
    FForm.Invalidate;
  except
    on E: Exception do
      DebugLog('redraw: ' + E.ClassName + ': ' + E.Message);
  end;
  FChanged := False;
  FUnFull := False;
end;

procedure TWindowRedraw.Activated;
begin
  Kick('the window is active');
end;

procedure TWindowRedraw.Deactivated;
begin
  if REDRAW_ON then
    DebugLog('redraw: the window is not active');
end;

procedure TWindowRedraw.UserInput;
var
  T: UInt64;
begin
  if not REDRAW_ON then
    Exit;
  T := TThread.GetTickCount64;
  if T - FLastInput > QUIET_MS then
    Kick(Format('a pad press after %d s without one', [(T - FLastInput) div 1000]));
  FLastInput := T;
end;

end.
