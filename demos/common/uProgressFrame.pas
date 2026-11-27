(* @abstract(A progress frame over a window - a title, a bar and its count
  from 0 to 100 %.)

  A progress frame over a window, for whatever takes long enough to look
  like the program has died (owner, 2026-11-27 13:14: "When something may
  take some time there should be some kind of progress bar on-screen
  indicating what was going on ... a child frame with a count from 0 -
  100 at which point the media is ready and it vanishes. Title the frame
  with whatever is going on - e.g. Opening Book"). Zip 388.

  The window is dimmed under it and takes no taps while it shows. It has
  a title (what is going on), a line for what it is about (a book's
  title), a line for the step under way, a bar and its count, 0 - 100 %.

  The count comes from the caller's steps (Step: never backwards). Where
  a step is long and says nothing until it ends (a thread reading a
  book), Creep moves the count on by itself towards the step's end, ever
  more slowly, so the bar is seen to move - it gets there only when the
  step does (Step). The count shows 100 only at Finish, which takes the
  frame away.

  Built in code (no .fmx): a TRectangle over the whole window (Align
  Contents), the frame centred in it.
*)

unit uProgressFrame;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  FMX.Types, FMX.Controls, FMX.Objects, FMX.StdCtrls, FMX.Graphics;

type
  { The progress frame: Start, Step / Creep, Finish. Its parent is the
    window (or the control it is over). }
  TProgressFrame = class(TRectangle)
  private
    { The frame itself (centred). }
    FPanel: TRectangle;
    { What is going on ("Opening book"). }
    FTitle: TLabel;
    { What it is about (the book's title). }
    FDetail: TLabel;
    { The step under way. }
    FStage: TLabel;
    { The count, "37 %". }
    FCount: TLabel;
    { The bar's track. }
    FTrack: TRectangle;
    { The bar. }
    FBar: TRectangle;
    { The count, 0 - 100. }
    FPercent: Single;
    { Where Creep is going (no further than this). }
    FGoal: Single;
    { Creep's pace: seconds to go about two thirds of the way left. }
    FPace: Single;
    { When the timer last moved the count (ms). }
    FLastTick: UInt64;
    { Creep's timer. }
    FTimer: TTimer;
    { Shown (Start to Finish). }
    FActive: Boolean;
    { Creep's step. }
    procedure TimerTick(Sender: TObject);
    { The bar and the count from FPercent. }
    procedure ShowPercent;
    { The frame and its parts placed for the window's size. }
    procedure Place;
    { A label of the frame.
      @param(ASize  its text size)
      @param(ABold  bold)
      @returns(the label) }
    function MakeLabel(ASize: Single; ABold: Boolean): TLabel;
  protected
    { The window's size changed: the frame placed again. }
    procedure Resize; override;
  public
    { Made hidden; its parent is set by the caller.
      @param(AOwner  the owner) }
    constructor Create(AOwner: TComponent); override;
    { Shown at 0 %, over everything.
      @param(ATitle  what is going on ("Opening book"))
      @param(ADetail  what it is about (a book's title; '' = none)) }
    procedure Start(const ATitle, ADetail: string);
    { A step reached: the count at least APercent (never back), the step
      under way said; Creep stops there.
      @param(APercent  0 - 99)
      @param(AStage  the step now under way ('' = as it was)) }
    procedure Step(APercent: Single; const AStage: string);
    { The count moves on by itself towards AGoal (never reaching it) -
      for a long step that says nothing until it ends.
      @param(AGoal  where the step ends, 0 - 99)
      @param(APace  seconds to go about two thirds of the way) }
    procedure Creep(AGoal, APace: Single);
    { 100 %, and gone. }
    procedure Finish;
    { Its colours (the reader's theme).
      @param(ABack  the frame's)
      @param(AText  the text's)
      @param(ATrack  the bar's track)
      @param(ABar  the bar) }
    procedure SetColours(ABack, AText, ATrack, ABar: TAlphaColor);
    { Shown: Start to Finish. }
    property Active: Boolean read FActive;
    { The count, 0 - 100. }
    property Percent: Single read FPercent;
  end;

implementation

const
  { The frame's widest (px). }
  FRAME_WIDTH = 480;
  { The frame's height (px). }
  FRAME_HEIGHT = 156;
  { Its inner margin (px). }
  FRAME_PAD = 20;
  { The count's width (px). }
  COUNT_WIDTH = 64;
  { Creep's timer (ms). }
  CREEP_MS = 50;

constructor TProgressFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Visible := False;
  // over the whole window, the window dimmed; taps stop here
  Align := TAlignLayout.Contents;
  Fill.Color := $70000000;
  Stroke.Kind := TBrushKind.None;
  HitTest := True;
  FPanel := TRectangle.Create(Self);
  FPanel.Parent := Self;
  FPanel.HitTest := False;
  FPanel.XRadius := 10;
  FPanel.YRadius := 10;
  FPanel.Stroke.Kind := TBrushKind.None;
  FTitle := MakeLabel(20, True);
  FDetail := MakeLabel(15, False);
  FStage := MakeLabel(13, False);
  FCount := MakeLabel(15, True);
  FCount.TextSettings.HorzAlign := TTextAlign.Trailing;
  FTrack := TRectangle.Create(Self);
  FTrack.Parent := FPanel;
  FTrack.HitTest := False;
  FTrack.Stroke.Kind := TBrushKind.None;
  FTrack.XRadius := 5;
  FTrack.YRadius := 5;
  FBar := TRectangle.Create(Self);
  FBar.Parent := FTrack;
  FBar.HitTest := False;
  FBar.Stroke.Kind := TBrushKind.None;
  FBar.XRadius := 5;
  FBar.YRadius := 5;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := CREEP_MS;
  FTimer.OnTimer := TimerTick;
  SetColours($FF23262E, $FFE8E8E8, $FF34405A, $FF62A0EA);
end;

function TProgressFrame.MakeLabel(ASize: Single; ABold: Boolean): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := FPanel;
  Result.HitTest := False;
  Result.WordWrap := False;
  Result.StyledSettings := Result.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size,
    TStyledSetting.Style];
  Result.TextSettings.Font.Size := ASize;
  if ABold then
    Result.TextSettings.Font.Style := [TFontStyle.fsBold];
  Result.TextSettings.Trimming := TTextTrimming.Character;
end;

procedure TProgressFrame.SetColours(ABack, AText, ATrack, ABar: TAlphaColor);
begin
  FPanel.Fill.Color := ABack;
  FTitle.TextSettings.FontColor := AText;
  FDetail.TextSettings.FontColor := AText;
  FStage.TextSettings.FontColor := AText;
  FCount.TextSettings.FontColor := AText;
  FTrack.Fill.Color := ATrack;
  FBar.Fill.Color := ABar;
end;

procedure TProgressFrame.Place;
var
  W, Inner: Single;
begin
  W := Min(FRAME_WIDTH, Max(160, Width - 32));
  FPanel.SetBounds(Round((Width - W) / 2), Round((Height - FRAME_HEIGHT) / 2), W, FRAME_HEIGHT);
  Inner := W - 2 * FRAME_PAD;
  FTitle.SetBounds(FRAME_PAD, 14, Inner, 30);
  FDetail.SetBounds(FRAME_PAD, 46, Inner, 24);
  FStage.SetBounds(FRAME_PAD, 72, Inner, 22);
  FTrack.SetBounds(FRAME_PAD, 112, Max(10, Inner - COUNT_WIDTH - 10), 12);
  FCount.SetBounds(FRAME_PAD + Inner - COUNT_WIDTH, 102, COUNT_WIDTH, 30);
  ShowPercent;
end;

procedure TProgressFrame.Resize;
begin
  inherited;
  if FPanel <> nil then
    Place;
end;

procedure TProgressFrame.ShowPercent;
var
  W: Single;
begin
  W := FTrack.Width * EnsureRange(FPercent, 0, 100) / 100;
  FBar.SetBounds(0, 0, W, FTrack.Height);
  FBar.Visible := W >= 1;
  // whole numbers, 100 only when done
  FCount.Text := Format('%d %%', [Trunc(EnsureRange(FPercent, 0, 100))]);
end;

procedure TProgressFrame.Start(const ATitle, ADetail: string);
begin
  FTitle.Text := ATitle;
  FDetail.Text := ADetail;
  FDetail.Visible := ADetail <> '';
  FStage.Text := '';
  FPercent := 0;
  FGoal := 0;
  FTimer.Enabled := False;
  FActive := True;
  Visible := True;
  Place;
  BringToFront;
end;

procedure TProgressFrame.Step(APercent: Single; const AStage: string);
begin
  if not FActive then
    Exit;
  FPercent := Max(FPercent, Min(APercent, 99));
  FGoal := FPercent;
  FTimer.Enabled := False;
  if AStage <> '' then
    FStage.Text := AStage;
  ShowPercent;
  // over what came up meanwhile (a page, the library)
  BringToFront;
end;

procedure TProgressFrame.Creep(AGoal, APace: Single);
begin
  if not FActive then
    Exit;
  FGoal := Min(AGoal, 99);
  FPace := Max(0.1, APace);
  FLastTick := TThread.GetTickCount64;
  FTimer.Enabled := FGoal > FPercent;
end;

procedure TProgressFrame.TimerTick(Sender: TObject);
var
  Now64: UInt64;
  Secs: Single;
begin
  Now64 := TThread.GetTickCount64;
  Secs := (Now64 - FLastTick) / 1000;
  FLastTick := Now64;
  if not FActive or (FGoal <= FPercent) then
  begin
    FTimer.Enabled := False;
    Exit;
  end;
  // a share of the way left, by the time gone: ever slower, never there
  FPercent := FPercent + (FGoal - FPercent) * (1 - Exp(-Secs / FPace));
  ShowPercent;
end;

procedure TProgressFrame.Finish;
begin
  FTimer.Enabled := False;
  if not FActive then
    Exit;
  FPercent := 100;
  ShowPercent;
  FActive := False;
  Visible := False;
end;

end.
