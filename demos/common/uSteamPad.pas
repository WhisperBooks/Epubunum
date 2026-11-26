(* @abstract(A game pad through Steam Input, for EpubReader (and later
  EpubBuilder): the presses of one action set's buttons, with repeats, and
  one stick.)

  Owner, 2026-11-18: "we have no good control system for steam yet (next
  job)" - in Big Picture or on a Steam Machine the pad did nothing in the
  programs; Exit was only Steam's own. The program names its action set,
  its button actions and its stick action (as in its action manifest -
  EpubReader's comes from tools/gen_reader_input.py), starts it with the
  manifest's path, and calls Poll from a timer: Poll answers which
  buttons were pressed since the last call (a held button that repeats
  comes again after REPEAT_DELAY_MS, then every REPEAT_MS) and where the
  stick is. Every connected pad drives the program.

  Built without STEAMBUILD, or with Steam not running, nothing is pressed
  and Start says why (one line for the log). As TSteamAPI's SteamDemoPad
  does it: ISteamInput started with explicit RunFrame, the handles looked
  up again until the manifest is loaded (Steam loads it a little after
  SetInputActionManifestFilePath). *)
unit uSteamPad;

interface

uses
  System.SysUtils;

const
  { A held button that repeats: the first repeat after this (ms). }
  REPEAT_DELAY_MS = 400;
  { Then every (ms). }
  REPEAT_MS = 120;

type
  { The presses of one Poll: one entry per button of the constructor's
    list, True when pressed (or repeated) since the last Poll. }
  TSteamPadPresses = TArray<Boolean>;

  { How an action is reached on the pad in hand (TSteamPad.Origin): the
    control's name in Steam's language and Steam's picture of it. }
  TSteamPadOrigin = record
    { The control's name ('' = not bound, or no Steam). }
    Name: string;
    { Steam's PNG of it ('' = none). }
    Glyph: string;
  end;

  { The pad: see the unit's text. }
  TSteamPad = class
  private
    { The action set's name. }
    FSetName: string;
    { The button actions' names. }
    FNames: TArray<string>;
    { The stick action's name ('' = none). }
    FStickName: string;
    { Buttons that repeat while held. }
    FRepeats: TArray<Boolean>;
    { Held at the last Poll. }
    FHeld: TArray<Boolean>;
    { When a held button repeats next (ms, TThread.GetTickCount64). }
    FRepeatAt: TArray<UInt64>;
    { The buttons' handles. }
    FButtons: TArray<UInt64>;
    {$IFDEF STEAMBUILD}
    // used by Steam's code only: without it they were hints in every
    // other build (Android, a desktop's Debug; zip 341)
    { Handles: the set (0 = not yet). }
    FSet: UInt64;
    { The stick's handle. }
    FStick: UInt64;
    { All handles found. }
    FResolved: Boolean;
    { When the handles were last looked up (ms). }
    FLastResolve: UInt64;
    { The pad that pressed last (0 = none yet). }
    FActivePad: UInt64;
    { The pads at the last Poll. }
    FPads: TArray<UInt64>;
    {$ENDIF}
    { Started: ISteamInput runs and the manifest was given. }
    FStarted: Boolean;
    { Pads at the last Poll (for the log). }
    FPadCount: Integer;
    { What happened worth a line in the log since the last call of
      TakeNote. }
    FNote: string;
    {$IFDEF STEAMBUILD}
    { The pad whose controls Origin describes: the one that pressed last,
      else the first. }
    function TargetPad: UInt64;
    { The handles looked up again. }
    procedure Resolve;
    {$ENDIF}
  public
    { The action set ASet with button actions AButtons and stick action
      AStick ('' for none) - the names as in the manifest.
      @param(ASet  the action set)
      @param(AButtons  the button actions; Poll's presses in this order)
      @param(AStick  the stick action) }
    constructor Create(const ASet: string; const AButtons: array of string; const AStick: string);
    { Button AIndex repeats while held (lists, scrolling).
      @param(AIndex  the button's place in the constructor's list)
      @param(ARepeat  repeats) }
    procedure SetRepeat(AIndex: Integer; ARepeat: Boolean);
    { Starts ISteamInput and gives Steam the manifest.
      @param(AManifest  the manifest's full path)
      @returns(one line for the log) }
    function Start(const AManifest: string): string;
    { The presses since the last call, and the stick.
      @param(APresses  receives one entry per button)
      @param(AStickY  receives the stick's up / down, -1 .. 1 (up is
        positive); 0 without a stick)
      @returns(False when nothing is read: not started, or the manifest not
        loaded yet) }
    function Poll(out APresses: TSteamPadPresses; out AStickY: Single): Boolean;
    { A line worth logging since the last call ('' for none): the
      handles found, the number of pads changed, a failure.
      @returns(the line) }
    function TakeNote: string;
    { How action AIndex is reached on the pad in hand: of the controls
      bound to it, the one with the shortest name ("D-Pad Up" rather than
      "Left Stick Move Up"), with Steam's picture for a dark or a light
      background.
      @param(AIndex  a button's place in the constructor's list, or
        Count for the stick)
      @param(ADark  the pictures are shown on a dark background)
      @returns(empty Name and Glyph when not known) }
    function Origin(AIndex: Integer; ADark: Boolean): TSteamPadOrigin;
    { The pad in hand, for a title: "Xbox One / Series controller", ...
      @returns('' when there is none) }
    function PadName: string;
    { Number of buttons. }
    function Count: Integer;
    { True once started. }
    property Started: Boolean read FStarted;
    { Pads connected at the last Poll. }
    property PadCount: Integer read FPadCount;
  end;

implementation

uses
  {$IFDEF STEAMBUILD}
  Steamworks.Types, Steamworks.SDKTypes, Steamworks.Core, Steamworks.Plugin.Input,
  {$ENDIF}
  System.Classes;

const
  { The handles are looked up again this often until found (ms). }
  RESOLVE_RETRY_MS = 500;

{$IFDEF STEAMBUILD}
{ ISteamInput's plug-in when it has been started. }
function InputPlugin: TSteamInputPlugin;
begin
  Result := nil;
  if (Steam <> nil) and Steam.IsRunning then
    Result := TSteamInputPlugin(Steam.FindPlugin(TSteamInputPlugin));
end;
{$ENDIF}

constructor TSteamPad.Create(const ASet: string; const AButtons: array of string; const AStick: string);
var
  I: Integer;
begin
  inherited Create;
  FSetName := ASet;
  SetLength(FNames, Length(AButtons));
  for I := 0 to High(AButtons) do
    FNames[I] := AButtons[I];
  FStickName := AStick;
  SetLength(FRepeats, Length(FNames));
  SetLength(FHeld, Length(FNames));
  SetLength(FRepeatAt, Length(FNames));
  SetLength(FButtons, Length(FNames));
  FPadCount := -1;
end;

procedure TSteamPad.SetRepeat(AIndex: Integer; ARepeat: Boolean);
begin
  if (AIndex >= 0) and (AIndex <= High(FRepeats)) then
    FRepeats[AIndex] := ARepeat;
end;

function TSteamPad.Count: Integer;
begin
  Result := Length(FNames);
end;

function TSteamPad.TakeNote: string;
begin
  Result := FNote;
  FNote := '';
end;

function TSteamPad.Start(const AManifest: string): string;
{$IFDEF STEAMBUILD}
var
  P: TSteamInputPlugin;
{$ENDIF}
begin
  FStarted := False;
  {$IFDEF STEAMBUILD}
  P := InputPlugin;
  if P = nil then
    Exit('pad: Steam is not running - keyboard, mouse and touch only');
  try
    // explicit RunFrame: Poll calls it right before reading the actions
    if not P.Started and not P.Start(True) then
      Exit('pad: ISteamInput did not start - keyboard, mouse and touch only');
    if not P.SetInputActionManifestFilePath(AManifest) then
      Exit('pad: Steam refused the action manifest ' + AManifest);
    FStarted := True;
    FLastResolve := 0;
    Result := 'pad: Steam Input started, action manifest ' + AManifest;
  except
    on E: Exception do
      Result := 'pad: starting Steam Input failed: ' + E.ClassName + ': ' + E.Message;
  end;
  {$ELSE}
  Result := 'pad: not a Steam build - keyboard, mouse and touch only';
  {$ENDIF}
end;

{$IFDEF STEAMBUILD}
function TSteamPad.TargetPad: UInt64;
var
  Pad: UInt64;
begin
  for Pad in FPads do
    if Pad = FActivePad then
      Exit(Pad);
  if Length(FPads) > 0 then
    Result := FPads[0]
  else
    Result := 0;
end;
{$ENDIF}

function TSteamPad.Origin(AIndex: Integer; ADark: Boolean): TSteamPadOrigin;
{$IFDEF STEAMBUILD}
var
  P: TSteamInputPlugin;
  Pad: UInt64;
  Origins: TSteamInputOriginArray;
  Best: EInputActionOrigin;
  Name, Path: string;
  I: Integer;
  Styles: array[0..3] of UInt32;
{$ENDIF}
begin
  Result.Name := '';
  Result.Glyph := '';
  {$IFDEF STEAMBUILD}
  P := InputPlugin;
  Pad := TargetPad;
  if (P = nil) or not P.Started or not FResolved or (Pad = 0) then
    Exit;
  try
    if (AIndex >= 0) and (AIndex < Length(FNames)) then
      Origins := P.DigitalActionOrigins(Pad, FSet, FButtons[AIndex])
    else if (AIndex = Length(FNames)) and (FStick <> 0) then
      Origins := P.AnalogActionOrigins(Pad, FSet, FStick)
    else
      Exit;
    if Length(Origins) = 0 then
      Exit;
    Best := Origins[0];
    for I := 0 to High(Origins) do
    begin
      Name := P.GetStringForActionOrigin(Origins[I]);
      if (Result.Name = '') or ((Name <> '') and (Length(Name) < Length(Result.Name))) then
      begin
        Result.Name := Name;
        Best := Origins[I];
      end;
    end;
    // coloured face buttons first, on the background's style; then plain;
    // then white (knockout); then the legacy picture
    if ADark then
      Styles[0] := UInt32(ESteamInputGlyphStyle_Dark) or UInt32(ESteamInputGlyphStyle_SolidABXY)
    else
      Styles[0] := UInt32(ESteamInputGlyphStyle_Light) or UInt32(ESteamInputGlyphStyle_SolidABXY);
    if ADark then
      Styles[1] := UInt32(ESteamInputGlyphStyle_Dark)
    else
      Styles[1] := UInt32(ESteamInputGlyphStyle_Light);
    Styles[2] := UInt32(ESteamInputGlyphStyle_Knockout);
    Styles[3] := UInt32(ESteamInputGlyphStyle_Knockout) or UInt32(ESteamInputGlyphStyle_SolidABXY);
    for I := 0 to High(Styles) do
    begin
      Path := P.GetGlyphPNGForActionOrigin(Best, k_ESteamInputGlyphSize_Medium, Styles[I]);
      if (Path <> '') and FileExists(Path) then
      begin
        Result.Glyph := Path;
        Exit;
      end;
    end;
    Path := P.GetGlyphForActionOrigin_Legacy(Best);
    if (Path <> '') and FileExists(Path) then
      Result.Glyph := Path;
  except
    on E: Exception do
      FNote := 'pad: the controls'' names / pictures FAILED: ' + E.Message;
  end;
  {$ENDIF}
end;

function TSteamPad.PadName: string;
{$IFDEF STEAMBUILD}
var
  P: TSteamInputPlugin;
  Pad: UInt64;
{$ENDIF}
begin
  Result := '';
  {$IFDEF STEAMBUILD}
  P := InputPlugin;
  Pad := TargetPad;
  if (P = nil) or not P.Started or (Pad = 0) then
    Exit;
  try
    case P.GetInputTypeForHandle(Pad) of
      k_ESteamInputType_SteamController: Result := 'Steam Controller (2015)';
      k_ESteamInputType_XBox360Controller: Result := 'Xbox 360 controller';
      k_ESteamInputType_XBoxOneController: Result := 'Xbox controller';
      k_ESteamInputType_GenericGamepad: Result := 'game pad';
      k_ESteamInputType_PS4Controller: Result := 'PlayStation 4 controller';
      k_ESteamInputType_PS5Controller: Result := 'PlayStation 5 DualSense';
      k_ESteamInputType_SwitchJoyConPair: Result := 'Joy-Con pair';
      k_ESteamInputType_SwitchProController: Result := 'Switch Pro controller';
      k_ESteamInputType_Switch2ProController: Result := 'Switch 2 Pro controller';
      k_ESteamInputType_SteamDeckController: Result := 'Steam Deck';
      k_ESteamInputType_SteamOSHandheld: Result := 'SteamOS handheld';
      k_ESteamInputType_SteamController2026: Result := 'Steam Controller';
    else
      Result := 'controller';
    end;
  except
    Result := 'controller';
  end;
  {$ENDIF}
end;

{$IFDEF STEAMBUILD}
procedure TSteamPad.Resolve;
var
  P: TSteamInputPlugin;
  I: Integer;
  Missing: string;
begin
  FLastResolve := TThread.GetTickCount64;
  P := InputPlugin;
  if P = nil then
    Exit;
  if FSet = 0 then
    FSet := P.GetActionSetHandle(FSetName);
  if (FStick = 0) and (FStickName <> '') then
    FStick := P.GetAnalogActionHandle(FStickName);
  for I := 0 to High(FNames) do
    if FButtons[I] = 0 then
      FButtons[I] := P.GetDigitalActionHandle(FNames[I]);
  Missing := '';
  if FSet = 0 then
    Missing := Missing + ' ' + FSetName;
  if (FStickName <> '') and (FStick = 0) then
    Missing := Missing + ' ' + FStickName;
  for I := 0 to High(FNames) do
    if FButtons[I] = 0 then
      Missing := Missing + ' ' + FNames[I];
  FResolved := Missing = '';
  if FResolved then
    FNote := Format('pad: action set %s and its %d actions found', [FSetName, Length(FNames) +
      Ord(FStickName <> '')]);
end;
{$ENDIF}

function TSteamPad.Poll(out APresses: TSteamPadPresses; out AStickY: Single): Boolean;
{$IFDEF STEAMBUILD}
var
  P: TSteamInputPlugin;
  Pads: TSteamInputHandleArray;
  Pad: InputHandle_t;
  Down: TArray<Boolean>;
  D: InputDigitalActionData_t;
  A: InputAnalogActionData_t;
  I: Integer;
  Now_: UInt64;
{$ENDIF}
begin
  SetLength(APresses, Length(FNames));
  AStickY := 0;
  Result := False;
  if not FStarted then
    Exit;
  {$IFDEF STEAMBUILD}
  P := InputPlugin;
  if (P = nil) or not P.Started then
    Exit;
  Now_ := TThread.GetTickCount64;
  try
    P.RunFrame(False);
    Pads := P.ConnectedControllers;
    SetLength(FPads, Length(Pads));
    for I := 0 to High(Pads) do
      FPads[I] := Pads[I];
    if Length(Pads) <> FPadCount then
    begin
      FPadCount := Length(Pads);
      FNote := Format('pad: %d controller(s) connected', [FPadCount]);
    end;
    if not FResolved then
    begin
      if Now_ - FLastResolve >= RESOLVE_RETRY_MS then
        Resolve;
      if not FResolved then
        Exit;
    end;
    SetLength(Down, Length(FNames));
    for Pad in Pads do
    begin
      P.ActivateActionSet(Pad, FSet);
      for I := 0 to High(FNames) do
      begin
        D := P.GetDigitalActionData(Pad, FButtons[I]);
        if D.bState then
        begin
          Down[I] := True;
          // a new press: this pad is in the user's hands
          if not FHeld[I] then
            FActivePad := Pad;
        end;
      end;
      if FStick <> 0 then
      begin
        A := P.GetAnalogActionData(Pad, FStick);
        if Abs(A.y) > Abs(AStickY) then
          AStickY := A.y;
      end;
    end;
    for I := 0 to High(FNames) do
    begin
      if Down[I] and not FHeld[I] then
      begin
        APresses[I] := True;
        FRepeatAt[I] := Now_ + REPEAT_DELAY_MS;
      end
      else if Down[I] and FRepeats[I] and (Now_ >= FRepeatAt[I]) then
      begin
        APresses[I] := True;
        FRepeatAt[I] := Now_ + REPEAT_MS;
      end;
      FHeld[I] := Down[I];
    end;
    Result := True;
  except
    on E: Exception do
    begin
      // not read again: one line, then quiet
      FStarted := False;
      FNote := 'pad: reading the pad FAILED, it is no longer read: ' + E.ClassName + ': ' + E.Message;
    end;
  end;
  {$ENDIF}
end;

end.
