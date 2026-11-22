{ @abstract(EpubBuilder's benchmark progress: a bar per benchmark of the
  run, over the whole window.)

  Owner, 2026-11-22: "When a benchmark is run we should display a progress
  bar for it. At the top we can have a label with the benchmark name along
  with some very basic details - Text being transcribed by what device ...
  Under that is the progress bar. Under the progress bar left aligned is
  current runtime HH:MM:SS.nnn and right aligned is percentage of
  transcription done. In the middle ... a very simple description of
  what's happening under-the-hood ... This bar can take up to 80% of the
  screen width and 20% of the height ... up to 4 bars are shown with a gap
  vertically - the progress bar block should be aligned so the space on
  each side above/below and left/right are balanced."

  A unit of its own: TRectangle comes from FMX.Objects, whose TPath would
  hide System.IOUtils.TPath in uBuilder (zip 182's lesson). The window
  fills the rows (SetRow) from OnTick, ten times a second. }
unit uBenchProgress;

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.Types, System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Objects, FMX.Graphics;

type
  { The controls of one benchmark's block. }
  TBenchRow = record
    { The block: the three lines below, in a yellow frame with rounded
      corners (owner, 2026-11-22: four bars at once must be told apart). }
    Box: TRectangle;
    { The benchmark, its text and its device. }
    Title: TLabel;
    { The bar's track. }
    Track: TRectangle;
    { The bar's filled part. }
    Fill: TRectangle;
    { The time since the benchmark started (left). }
    Time: TLabel;
    { What is being done (middle). }
    Phase: TLabel;
    { The share of the transcription done (right). }
    Percent: TLabel;
    { The share shown, 0 .. 100 (the fill's width follows the track's). }
    Value: Double;
  end;

  { The view: an opaque layer over the whole window with a block per
    benchmark, centred, and on the desktop a Cancel button in its corner.
    Freeing it takes the layer away. }
  TBenchProgress = class(TComponent)
  private
    { The layer over the window. }
    FBack: TRectangle;
    { The blocks, in the run's order. }
    FRows: TArray<TBenchRow>;
    { The corner's button: Cancel, then Show / Hide results (nil without
      one). }
    FCancel: TButton;
    { Calls OnTick. }
    FTimer: TTimer;
    { The text's colour. }
    FTextColor: TAlphaColor;
    { Backing field of @link(OnTick). }
    FOnTick: TNotifyEvent;
    { Backing field of @link(OnButton). }
    FOnButton: TNotifyEvent;
    { The line above the blocks when there are more than MAX_VISIBLE
      ("Model 5 of 10"). }
    FHeader: TLabel;
    { The first block shown (more than MAX_VISIBLE: the rest scroll). }
    FTop: Integer;
    { The blocks' frame colour (the table's too). }
    FFrameColor: TAlphaColor;
    { ShowTable was called: the table in place of the blocks. }
    FTable: Boolean;
    { The table's frame. }
    FTableBox: TRectangle;
    { The table's title (centred). }
    FTableTitle: TLabel;
    { The line under the title. }
    FTableNote: TLabel;
    { The line under the table ('' = none). }
    FTableFootnote: TLabel;
    { The last line ('' = none). }
    FTableFoot: TLabel;
    { The table's cells, a row at a time; the first row is its heading. }
    FCells: TArray<TArray<TLabel>>;
    { A label in AParent with the view's colour. }
    function NewLabel(AParent: TFmxObject; AAlign: TTextAlign): TLabel;
    { Places the blocks in the layer: 95 % of its width, at most 20 % of
      its height each, a quarter of a block between two, the whole group
      in the middle. }
    procedure Arrange;
    { The layer's size changed. }
    procedure BackResized(Sender: TObject);
    { The timer: OnTick. }
    procedure TimerTick(Sender: TObject);
    { The corner's button: OnButton. }
    procedure CancelClick(Sender: TObject);
    { A click on the layer: OnButton while the table shows. }
    procedure BackClick(Sender: TObject);
    { Places the table (ShowTable) in the layer: as wide as a block, its
      lines as tall as the layer allows (at most 8 % of it each), in the
      middle. }
    procedure ArrangeTable;
  public
    { The view over AForm, a block per ATitles' line, dark or light
      (ADark), with a Cancel button when ACancel (the desktop; Big Picture
      cancels through the pad's menu). }
    constructor Create(AForm: TCommonCustomForm; const ATitles: TArray<string>; ADark, ACancel: Boolean);
      reintroduce;
    { Stops the timer; the layer goes with its owner (this view). }
    destructor Destroy; override;
    { Shows block AIndex: ATime on the left, APhase in the middle,
      APercent (0 .. 100) on the bar and on the right. }
    procedure SetRow(AIndex: Integer; const ATime, APhase: string; APercent: Double);
    { The corner's button says AText (nothing without the button).
      @param(AText  its text) }
    procedure SetButtonText(const AText: string);
    { The block being worked on: with more than MAX_VISIBLE blocks the view
      scrolls so it is the first of those shown, the next ones under it
      (at the end the last MAX_VISIBLE stay).
      @param(AIndex  the block) }
    procedure SetCurrent(AIndex: Integer);
    { The line above the blocks, shown when there are more than
      MAX_VISIBLE ("Model 5 of 10").
      @param(AText  the line) }
    procedure SetHeader(const AText: string);
    { The blocks make way for a table (owner, 2026-11-22: the calibration's
      results, and what they mean for some books): ATitle above it,
      ANote under the title (bold, in the frame's colour: what must not be
      missed), ACells a row at a time (the first row is the
      heading; the first column on the left, the others on the right),
      AFootnote (one line or more, sLineBreak between) and AFoot under it
      ('' = none). OnTick stops; a click
      anywhere on the layer, or on the corner's button, is OnButton. }
    procedure ShowTable(const ATitle, ANote: string; const ACells: TArray<TArray<string>>;
      const AFootnote, AFoot: string);
    { Ten times a second, for the window to fill the rows. }
    property OnTick: TNotifyEvent read FOnTick write FOnTick;
    { The corner's button was clicked (Cancel while it runs); while the
      table shows, also a click anywhere on the layer. }
    property OnButton: TNotifyEvent read FOnButton write FOnButton;
  end;

implementation

const
  { The layer, dark (the builder's dark window, uBuilder's
    PAD_DARK_WINDOW). }
  BACK_DARK = $FF1A1C22;
  { The layer, light. }
  BACK_LIGHT = $FFF2F2F2;
  { The text, dark. }
  TEXT_DARK = $FFE0E0E0;
  { The bar's track, dark. }
  TRACK_DARK = $FF34405A;
  { The bar's track, light. }
  TRACK_LIGHT = $FFD6D9DE;
  { The bar's filled part, dark. }
  FILL_DARK = $FF4A90D9;
  { The bar's filled part, light. }
  FILL_LIGHT = $FF2F6FBF;
  { A block's frame, dark. }
  FRAME_DARK = $FFE8C547;
  { A block's frame, light (a darker yellow: it shows on the light layer). }
  FRAME_LIGHT = $FFC99A06;
  { The space between a block's frame and what it holds, share of the
    block's height. }
  FRAME_PAD = 0.1;
  { Width of a block, share of the layer's (owner, 2026-11-22: 80 % cut
    the text off - "Lets give them 95%"). }
  BLOCK_WIDTH = 0.95;
  { Height of a block at most, share of the layer's. }
  BLOCK_HEIGHT = 0.2;
  { The gap between two blocks, share of a block's height. }
  BLOCK_GAP = 0.25;
  { Height the blocks may take together at most, share of the layer's. }
  BLOCKS_MAX = 0.9;
  { Blocks shown at once at most (owner, 2026-11-22: "Calibrate All" of
    ten models - the rest scroll, SetCurrent). }
  MAX_VISIBLE = 4;
  { The header line's height, share of a block's. }
  HEADER_HEIGHT = 0.35;
  { The table: a line's height at most, share of the layer's height. }
  TABLE_LINE_MAX = 0.08;
  { The table: the lines (in line heights) besides its rows - the title
    (1.4), the note, two gaps of a half, the footnote, the foot and the
    padding. }
  TABLE_EXTRA_LINES = 6.4;
  { The table: each column after the first, share of its width. }
  TABLE_COLUMN = 0.17;

constructor TBenchProgress.Create(AForm: TCommonCustomForm; const ATitles: TArray<string>; ADark, ACancel: Boolean);
var
  I: Integer;
  TrackColor, FillColor, FrameColor: TAlphaColor;
begin
  inherited Create(AForm);
  if ADark then
  begin
    FTextColor := TEXT_DARK;
    TrackColor := TRACK_DARK;
    FillColor := FILL_DARK;
    FrameColor := FRAME_DARK;
  end
  else
  begin
    FTextColor := TAlphaColors.Black;
    TrackColor := TRACK_LIGHT;
    FillColor := FILL_LIGHT;
    FrameColor := FRAME_LIGHT;
  end;
  FFrameColor := FrameColor;
  FBack := TRectangle.Create(Self);
  FBack.Parent := AForm;
  // the whole window, whatever else is aligned in it; clicks stop here
  FBack.Align := TAlignLayout.Contents;
  FBack.HitTest := True;
  FBack.Stroke.Kind := TBrushKind.None;
  if ADark then
    FBack.Fill.Color := BACK_DARK
  else
    FBack.Fill.Color := BACK_LIGHT;
  FBack.OnResized := BackResized;
  FBack.OnClick := BackClick;
  SetLength(FRows, Length(ATitles));
  for I := 0 to High(ATitles) do
  begin
    FRows[I].Box := TRectangle.Create(Self);
    FRows[I].Box.Parent := FBack;
    FRows[I].Box.Fill.Kind := TBrushKind.None;
    FRows[I].Box.Stroke.Kind := TBrushKind.Solid;
    FRows[I].Box.Stroke.Color := FrameColor;
    // owner, 2026-11-22: twice as thick as the first 2 px
    FRows[I].Box.Stroke.Thickness := 4;
    FRows[I].Title := NewLabel(FRows[I].Box, TTextAlign.Leading);
    FRows[I].Title.Text := ATitles[I];
    FRows[I].Track := TRectangle.Create(Self);
    FRows[I].Track.Parent := FRows[I].Box;
    FRows[I].Track.Stroke.Kind := TBrushKind.None;
    FRows[I].Track.Fill.Color := TrackColor;
    FRows[I].Fill := TRectangle.Create(Self);
    FRows[I].Fill.Parent := FRows[I].Track;
    FRows[I].Fill.Stroke.Kind := TBrushKind.None;
    FRows[I].Fill.Fill.Color := FillColor;
    FRows[I].Time := NewLabel(FRows[I].Box, TTextAlign.Leading);
    FRows[I].Phase := NewLabel(FRows[I].Box, TTextAlign.Center);
    FRows[I].Percent := NewLabel(FRows[I].Box, TTextAlign.Trailing);
    FRows[I].Value := 0;
  end;
  FHeader := NewLabel(FBack, TTextAlign.Center);
  FHeader.Visible := Length(ATitles) > MAX_VISIBLE;
  FTop := 0;
  if ACancel then
  begin
    FCancel := TButton.Create(Self);
    FCancel.Parent := FBack;
    FCancel.Text := 'Cancel';
    FCancel.Width := 140;
    FCancel.Height := 30;
    FCancel.OnClick := CancelClick;
  end;
  FBack.BringToFront;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 100;
  FTimer.OnTimer := TimerTick;
  FTimer.Enabled := True;
  Arrange;
end;

destructor TBenchProgress.Destroy;
begin
  if FTimer <> nil then
    FTimer.Enabled := False;
  inherited;
end;

function TBenchProgress.NewLabel(AParent: TFmxObject; AAlign: TTextAlign): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := AParent;
  Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Size, TStyledSetting.FontColor];
  Result.TextSettings.FontColor := FTextColor;
  Result.TextSettings.HorzAlign := AAlign;
  Result.TextSettings.VertAlign := TTextAlign.Center;
  Result.TextSettings.WordWrap := False;
  Result.TextSettings.Trimming := TTextTrimming.Character;
end;

procedure TBenchProgress.Arrange;
var
  W, H, BlockW, BlockH, Gap, Total, X, Y, Font, LineH, Pad, InW, InH, HeadH: Double;
  I, N, V: Integer;
begin
  // the table in place of the blocks
  if FTable then
  begin
    ArrangeTable;
    Exit;
  end;
  N := Length(FRows);
  if (FBack = nil) or (N = 0) then
    Exit;
  W := FBack.Width;
  H := FBack.Height;
  if (W <= 0) or (H <= 0) then
    Exit;
  // more than MAX_VISIBLE: that many at their full size, a header above
  V := Min(N, MAX_VISIBLE);
  BlockW := W * BLOCK_WIDTH;
  BlockH := H * BLOCK_HEIGHT;
  Gap := BlockH * BLOCK_GAP;
  HeadH := 0;
  if N > MAX_VISIBLE then
    HeadH := BlockH * HEADER_HEIGHT;
  Total := HeadH + V * BlockH + (V - 1) * Gap;
  if Total > H * BLOCKS_MAX then
  begin
    // four blocks on a short window: smaller, the same proportions
    if N > MAX_VISIBLE then
      BlockH := H * BLOCKS_MAX / (V + (V - 1) * BLOCK_GAP + HEADER_HEIGHT)
    else
      BlockH := H * BLOCKS_MAX / (V + (V - 1) * BLOCK_GAP);
    Gap := BlockH * BLOCK_GAP;
    if N > MAX_VISIBLE then
      HeadH := BlockH * HEADER_HEIGHT;
    Total := HeadH + V * BlockH + (V - 1) * Gap;
  end;
  // the same space left and right, above and below
  X := (W - BlockW) / 2;
  Y := (H - Total) / 2;
  // inside the frame: the same space on all four sides
  Pad := BlockH * FRAME_PAD;
  InW := BlockW - 2 * Pad;
  InH := BlockH - 2 * Pad;
  Font := EnsureRange(InH * 0.18, 11.0, 28.0);
  LineH := InH * 0.3;
  FHeader.Visible := N > MAX_VISIBLE;
  if FHeader.Visible then
  begin
    FHeader.SetBounds(X, Y, BlockW, HeadH);
    FHeader.TextSettings.Font.Size := Font;
    Y := Y + HeadH;
  end;
  FTop := EnsureRange(FTop, 0, N - V);
  for I := 0 to N - 1 do
  begin
    // only the blocks of the window [FTop, FTop + V)
    FRows[I].Box.Visible := (I >= FTop) and (I < FTop + V);
    if not FRows[I].Box.Visible then
      Continue;
    FRows[I].Box.SetBounds(X, Y + (I - FTop) * (BlockH + Gap), BlockW, BlockH);
    FRows[I].Box.XRadius := Pad;
    FRows[I].Box.YRadius := Pad;
    // the title, the bar, the line under it: a third of the inside each
    FRows[I].Title.SetBounds(Pad, Pad, InW, LineH);
    FRows[I].Track.SetBounds(Pad, Pad + InH * 0.35, InW, LineH);
    FRows[I].Track.XRadius := LineH / 6;
    FRows[I].Track.YRadius := LineH / 6;
    FRows[I].Fill.SetBounds(0, 0, InW * EnsureRange(FRows[I].Value, 0.0, 100.0) / 100, LineH);
    FRows[I].Fill.XRadius := LineH / 6;
    FRows[I].Fill.YRadius := LineH / 6;
    FRows[I].Time.SetBounds(Pad, Pad + InH * 0.7, InW, LineH);
    FRows[I].Phase.SetBounds(Pad, Pad + InH * 0.7, InW, LineH);
    FRows[I].Percent.SetBounds(Pad, Pad + InH * 0.7, InW, LineH);
    FRows[I].Title.TextSettings.Font.Size := Font;
    FRows[I].Time.TextSettings.Font.Size := Font;
    FRows[I].Phase.TextSettings.Font.Size := Font;
    FRows[I].Percent.TextSettings.Font.Size := Font;
  end;
  if FCancel <> nil then
    FCancel.SetBounds(W - FCancel.Width - 12, H - FCancel.Height - 12, FCancel.Width, FCancel.Height);
end;

procedure TBenchProgress.SetCurrent(AIndex: Integer);
var
  Top: Integer;
begin
  Top := EnsureRange(AIndex, 0, Max(0, Length(FRows) - MAX_VISIBLE));
  if Top = FTop then
    Exit;
  FTop := Top;
  Arrange;
end;

procedure TBenchProgress.SetHeader(const AText: string);
begin
  if FHeader <> nil then
    FHeader.Text := AText;
end;

procedure TBenchProgress.BackResized(Sender: TObject);
begin
  Arrange;
end;

procedure TBenchProgress.TimerTick(Sender: TObject);
begin
  if Assigned(FOnTick) then
    FOnTick(Self);
end;

procedure TBenchProgress.CancelClick(Sender: TObject);
begin
  if Assigned(FOnButton) then
    FOnButton(Self);
end;

procedure TBenchProgress.BackClick(Sender: TObject);
begin
  if FTable and Assigned(FOnButton) then
    FOnButton(Self);
end;

procedure TBenchProgress.ShowTable(const ATitle, ANote: string; const ACells: TArray<TArray<string>>;
  const AFootnote, AFoot: string);
var
  R, C: Integer;
  L: TLabel;
begin
  FTimer.Enabled := False;
  FTable := True;
  for R := 0 to High(FRows) do
    FRows[R].Box.Visible := False;
  FHeader.Visible := False;
  FTableBox := TRectangle.Create(Self);
  FTableBox.Parent := FBack;
  FTableBox.Fill.Kind := TBrushKind.None;
  FTableBox.Stroke.Kind := TBrushKind.Solid;
  FTableBox.Stroke.Color := FFrameColor;
  FTableBox.Stroke.Thickness := 4;
  // a click on it is the layer's
  FTableBox.HitTest := False;
  FTableTitle := NewLabel(FTableBox, TTextAlign.Center);
  FTableTitle.Text := ATitle;
  FTableNote := NewLabel(FTableBox, TTextAlign.Center);
  FTableNote.Text := ANote;
  // owner, 2026-11-22: stressed - the times are a rough guide only (bold,
  // in the frame's yellow)
  FTableNote.StyledSettings := FTableNote.StyledSettings - [TStyledSetting.Style];
  FTableNote.TextSettings.Font.Style := [TFontStyle.fsBold];
  FTableNote.TextSettings.FontColor := FFrameColor;
  FTableFootnote := NewLabel(FTableBox, TTextAlign.Leading);
  FTableFootnote.Text := AFootnote;
  FTableFoot := NewLabel(FTableBox, TTextAlign.Center);
  FTableFoot.Text := AFoot;
  SetLength(FCells, Length(ACells));
  for R := 0 to High(ACells) do
  begin
    SetLength(FCells[R], Length(ACells[R]));
    for C := 0 to High(ACells[R]) do
    begin
      if C = 0 then
        L := NewLabel(FTableBox, TTextAlign.Leading)
      else
        L := NewLabel(FTableBox, TTextAlign.Trailing);
      L.Text := ACells[R][C];
      // the heading in bold
      if R = 0 then
      begin
        L.StyledSettings := L.StyledSettings - [TStyledSetting.Style];
        L.TextSettings.Font.Style := [TFontStyle.fsBold];
      end;
      FCells[R][C] := L;
    end;
  end;
  if FCancel <> nil then
  begin
    FCancel.Text := 'OK';
    FCancel.BringToFront;
  end;
  Arrange;
end;

procedure TBenchProgress.ArrangeTable;
var
  W, H, LineH, Font, BoxW, BoxH, Pad, InW, ColW, FirstW, X, Y: Double;
  R, C, Cols, More: Integer;
begin
  W := FBack.Width;
  H := FBack.Height;
  if (W <= 0) or (H <= 0) or (FTableBox = nil) then
    Exit;
  // the footnote's lines after its first (TABLE_EXTRA_LINES has one)
  More := Length(FTableFootnote.Text) - Length(StringReplace(FTableFootnote.Text, #10, '', [rfReplaceAll]));
  LineH := Min(H * BLOCKS_MAX / (Length(FCells) + TABLE_EXTRA_LINES + More), H * TABLE_LINE_MAX);
  Font := EnsureRange(LineH * 0.55, 11.0, 32.0);
  BoxW := W * BLOCK_WIDTH;
  Pad := LineH * 0.5;
  BoxH := LineH * (Length(FCells) + TABLE_EXTRA_LINES + More);
  FTableBox.SetBounds((W - BoxW) / 2, (H - BoxH) / 2, BoxW, BoxH);
  FTableBox.XRadius := Pad;
  FTableBox.YRadius := Pad;
  InW := BoxW - 4 * Pad;
  Y := Pad;
  FTableTitle.SetBounds(2 * Pad, Y, InW, LineH * 1.4);
  FTableTitle.TextSettings.Font.Size := Font * 1.3;
  Y := Y + LineH * 1.4;
  FTableNote.SetBounds(2 * Pad, Y, InW, LineH);
  FTableNote.TextSettings.Font.Size := Font * 0.9;
  Y := Y + LineH * 1.5;
  // the first column takes what the others leave
  Cols := 0;
  for R := 0 to High(FCells) do
    Cols := Max(Cols, Length(FCells[R]));
  ColW := InW * TABLE_COLUMN;
  FirstW := InW - ColW * Max(0, Cols - 1);
  for R := 0 to High(FCells) do
  begin
    X := 2 * Pad;
    for C := 0 to High(FCells[R]) do
    begin
      if C = 0 then
      begin
        FCells[R][C].SetBounds(X, Y, FirstW, LineH);
        X := X + FirstW;
      end
      else
      begin
        FCells[R][C].SetBounds(X, Y, ColW, LineH);
        X := X + ColW;
      end;
      FCells[R][C].TextSettings.Font.Size := Font;
    end;
    Y := Y + LineH;
  end;
  Y := Y + LineH * 0.5;
  FTableFootnote.SetBounds(2 * Pad, Y, InW, LineH * (1 + More));
  FTableFootnote.TextSettings.Font.Size := Font * 0.8;
  Y := Y + LineH * (1 + More);
  FTableFoot.SetBounds(2 * Pad, Y, InW, LineH);
  FTableFoot.TextSettings.Font.Size := Font * 0.9;
  if FCancel <> nil then
    FCancel.SetBounds(W - FCancel.Width - 12, H - FCancel.Height - 12, FCancel.Width, FCancel.Height);
end;

procedure TBenchProgress.SetButtonText(const AText: string);
begin
  if FCancel <> nil then
    FCancel.Text := AText;
end;

procedure TBenchProgress.SetRow(AIndex: Integer; const ATime, APhase: string; APercent: Double);
begin
  if (AIndex < 0) or (AIndex > High(FRows)) then
    Exit;
  FRows[AIndex].Time.Text := ATime;
  FRows[AIndex].Phase.Text := APhase;
  FRows[AIndex].Percent.Text := Format('%.1f %%', [APercent]);
  FRows[AIndex].Value := APercent;
  FRows[AIndex].Fill.Width := FRows[AIndex].Track.Width * EnsureRange(APercent, 0.0, 100.0) / 100;
end;

end.
