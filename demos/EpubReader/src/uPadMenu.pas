{ @abstract(EpubReader's pad menu: a list over the page, driven by the pad
  (up / down / choose / back, left / right for a value) and still usable
  with the mouse or a touch.)

  Owner, 2026-11-18: Big Picture needs a way to the reader's commands
  with a pad - the menu bar is not shown there, and Exit was only
  Steam's own. The menu knows nothing of the reader: the program gives
  it a title and the rows' texts, moves it with Move, and reads Selected
  when the pad chooses; a click or tap on a row selects it and calls
  OnChoose. A row's text can change while it shows (SetText: "Text size
  < 18 >"). Long lists (the contents) scroll to keep the selected row in
  view. }
unit uPadMenu;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Objects, FMX.StdCtrls, FMX.Layouts, FMX.Graphics;

type
  { A row was clicked or tapped: its index. }
  TPadMenuChooseEvent = procedure(Sender: TObject; AIndex: Integer) of object;

  { The menu: see the unit's text. }
  TPadMenu = class(TComponent)
  private
    { The shade over the whole window (a click on it closes the menu). }
    FShade: TRectangle;
    { The box in the middle. }
    FBox: TRectangle;
    { The title. }
    FTitle: TLabel;
    { The rows' scroll box. }
    FScroll: TVertScrollBox;
    { The rows' backgrounds. }
    FRows: TArray<TRectangle>;
    { The rows' texts. }
    FTexts: TArray<TLabel>;
    { The selected row (-1 = none). }
    FSelected: Integer;
    { Colours: the box, the text, the selected row. }
    FBack, FFore, FAccent: TAlphaColor;
    { Text size. }
    FFontSize: Single;
    { See OnChoose. }
    FOnChoose: TPadMenuChooseEvent;
    { See OnClose. }
    FOnClose: TNotifyEvent;
    { The rows drawn as selected or not. }
    procedure Paint;
    { The selected row scrolled into view. }
    procedure KeepVisible;
    { A row clicked. }
    procedure RowClick(Sender: TObject);
    { The shade clicked: closed. }
    procedure ShadeClick(Sender: TObject);
    { The rows freed. }
    procedure ClearRows;
    { Height of a row. }
    function RowHeight: Single;
  public
    { The menu over AParent (the form), hidden.
      @param(AOwner  the owner, frees it)
      @param(AParent  where it shows: the whole of it is shaded) }
    constructor Create(AOwner: TComponent; AParent: TFmxObject); reintroduce;
    { Shows ATitle with rows AItems, ASelected selected.
      @param(ATitle  the title)
      @param(AItems  the rows' texts)
      @param(ASelected  the row selected first) }
    procedure Show(const ATitle: string; const AItems: array of string; ASelected: Integer);
    { Hides the menu. }
    procedure Hide;
    { True while it shows.
      @returns(the answer) }
    function Showing: Boolean;
    { Moves the selection by ADelta rows (wrapping at the ends).
      @param(ADelta  rows, negative upwards) }
    procedure Move(ADelta: Integer);
    { Changes row AIndex's text.
      @param(AIndex  the row)
      @param(AText  its text) }
    procedure SetText(AIndex: Integer; const AText: string);
    { The colours: box, text, selected row (the reader's theme).
      @param(ABack  the box)
      @param(AFore  the text)
      @param(AAccent  the selected row) }
    procedure SetColors(ABack, AFore, AAccent: TAlphaColor);
    { The selected row (-1 = none). }
    property Selected: Integer read FSelected;
    { Text size (set before Show). }
    property FontSize: Single read FFontSize write FFontSize;
    { A row clicked or tapped (already selected). }
    property OnChoose: TPadMenuChooseEvent read FOnChoose write FOnChoose;
    { Closed by a click beside the box. }
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
  end;

implementation

const
  { The box's width as a share of the window's, at most. }
  BOX_SHARE = 0.6;
  { Rows shown at most before the list scrolls. }
  MAX_ROWS = 12;
  { Padding inside the box. }
  PAD = 16;

constructor TPadMenu.Create(AOwner: TComponent; AParent: TFmxObject);
begin
  inherited Create(AOwner);
  FSelected := -1;
  FFontSize := 22;
  FBack := TAlphaColors.White;
  FFore := TAlphaColors.Black;
  FAccent := $FFC8DCF0;
  FShade := TRectangle.Create(Self);
  FShade.Parent := AParent;
  FShade.Align := TAlignLayout.Contents;
  FShade.Fill.Color := $80000000;
  FShade.Stroke.Kind := TBrushKind.None;
  FShade.HitTest := True;
  FShade.OnClick := ShadeClick;
  FShade.Visible := False;
  FBox := TRectangle.Create(Self);
  FBox.Parent := FShade;
  FBox.Align := TAlignLayout.Center;
  FBox.Stroke.Kind := TBrushKind.None;
  FBox.XRadius := 8;
  FBox.YRadius := 8;
  FBox.HitTest := True;
  FBox.Padding.Rect := TRectF.Create(PAD, PAD, PAD, PAD);
  FTitle := TLabel.Create(Self);
  FTitle.Parent := FBox;
  FTitle.Align := TAlignLayout.Top;
  FTitle.StyledSettings := FTitle.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size,
    TStyledSetting.Style];
  FTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
  FTitle.HitTest := False;
  FScroll := TVertScrollBox.Create(Self);
  FScroll.Parent := FBox;
  FScroll.Align := TAlignLayout.Client;
  FScroll.ShowScrollBars := False;
end;

function TPadMenu.RowHeight: Single;
begin
  Result := Round(FFontSize * 1.8);
end;

procedure TPadMenu.ClearRows;
var
  I: Integer;
begin
  for I := 0 to High(FRows) do
    FRows[I].Free;
  FRows := nil;
  FTexts := nil;
end;

procedure TPadMenu.Show(const ATitle: string; const AItems: array of string; ASelected: Integer);
var
  I: Integer;
  R: TRectangle;
  L: TLabel;
  W, H: Single;
begin
  ClearRows;
  FTitle.Text := ATitle;
  FTitle.TextSettings.Font.Size := FFontSize;
  FTitle.TextSettings.FontColor := FFore;
  FTitle.Height := RowHeight;
  for I := 0 to High(AItems) do
  begin
    R := TRectangle.Create(Self);
    R.Parent := FScroll;
    R.Position.Y := I * RowHeight;
    R.Height := RowHeight;
    R.Width := 100;
    R.Align := TAlignLayout.Top;
    R.Stroke.Kind := TBrushKind.None;
    R.XRadius := 4;
    R.YRadius := 4;
    R.Tag := I;
    R.HitTest := True;
    R.OnClick := RowClick;
    L := TLabel.Create(R);
    L.Parent := R;
    L.Align := TAlignLayout.Client;
    L.Margins.Left := PAD / 2;
    L.StyledSettings := L.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
    L.TextSettings.Font.Size := FFontSize;
    L.TextSettings.FontColor := FFore;
    L.Text := AItems[I];
    L.HitTest := False;
    FRows := FRows + [R];
    FTexts := FTexts + [L];
  end;
  // the box: wide enough for a long row, at most BOX_SHARE of the window;
  // as tall as MAX_ROWS rows
  W := FFontSize * 22;
  if FShade.Parent is TCommonCustomForm then
    W := Min(W, TCommonCustomForm(FShade.Parent).ClientWidth * BOX_SHARE)
  else if FShade.Parent is TControl then
    W := Min(W, TControl(FShade.Parent).Width * BOX_SHARE);
  H := 2 * PAD + RowHeight * (1 + Min(Length(AItems), MAX_ROWS));
  FBox.Fill.Color := FBack;
  FBox.Width := Max(W, FFontSize * 12);
  FBox.Height := H;
  FSelected := EnsureRange(ASelected, -1, High(FRows));
  if (FSelected < 0) and (Length(FRows) > 0) then
    FSelected := 0;
  FShade.Visible := True;
  FShade.BringToFront;
  Paint;
  KeepVisible;
end;

procedure TPadMenu.Hide;
begin
  FShade.Visible := False;
  ClearRows;
  FSelected := -1;
end;

function TPadMenu.Showing: Boolean;
begin
  Result := FShade.Visible;
end;

procedure TPadMenu.Move(ADelta: Integer);
var
  N: Integer;
begin
  N := Length(FRows);
  if N = 0 then
    Exit;
  FSelected := ((FSelected + ADelta) mod N + N) mod N;
  Paint;
  KeepVisible;
end;

procedure TPadMenu.SetText(AIndex: Integer; const AText: string);
begin
  if (AIndex >= 0) and (AIndex <= High(FTexts)) then
    FTexts[AIndex].Text := AText;
end;

procedure TPadMenu.SetColors(ABack, AFore, AAccent: TAlphaColor);
begin
  FBack := ABack;
  FFore := AFore;
  FAccent := AAccent;
end;

procedure TPadMenu.Paint;
var
  I: Integer;
begin
  for I := 0 to High(FRows) do
    if I = FSelected then
      FRows[I].Fill.Color := FAccent
    else
      FRows[I].Fill.Color := TAlphaColors.Null;
end;

procedure TPadMenu.KeepVisible;
var
  Top, View: Single;
begin
  if (FSelected < 0) or (FSelected > High(FRows)) then
    Exit;
  Top := FSelected * RowHeight;
  View := FScroll.Height;
  if Top < FScroll.ViewportPosition.Y then
    FScroll.ViewportPosition := TPointF.Create(0, Top)
  else if Top + RowHeight > FScroll.ViewportPosition.Y + View then
    FScroll.ViewportPosition := TPointF.Create(0, Top + RowHeight - View);
end;

procedure TPadMenu.RowClick(Sender: TObject);
var
  I: Integer;
begin
  I := (Sender as TRectangle).Tag;
  FSelected := I;
  Paint;
  // later: the choice may close the menu, which frees this row
  TThread.ForceQueue(nil,
    procedure
    begin
      if Showing and Assigned(FOnChoose) then
        FOnChoose(Self, I);
    end);
end;

procedure TPadMenu.ShadeClick(Sender: TObject);
begin
  // a click on the box itself is the box's (HitTest), not the shade's
  if Assigned(FOnClose) then
    FOnClose(Self)
  else
    Hide;
end;

end.
