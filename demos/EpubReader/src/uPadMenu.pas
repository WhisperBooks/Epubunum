{ @abstract(EpubReader's pad menu: a list over the page, driven by the pad
  (up / down / choose / back, left / right for a value) and still usable
  with the mouse or a touch.)

  Owner, 2026-11-18: Big Picture needs a way to the reader's commands
  with a pad - the menu bar is not shown there, and Exit was only
  Steam's own; then "a menu option for Controls ... Make them look a
  little prettier too" and "Steam also supply all the controller glyphs".

  The menu knows nothing of the reader: the program gives it a title, the
  rows (text, a value on the right, Steam's pictures of the controls on
  the left) and a line of hints for the foot, moves it with Move, and
  reads Selected when the pad chooses; a click or tap on a row selects it
  and calls OnChoose. A row's value can change while it shows (SetValue:
  "< 18 >"). Long lists (the contents) scroll to keep the selected row in
  view. It fades in. }
unit uPadMenu;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math, System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Objects, FMX.StdCtrls, FMX.Layouts, FMX.Graphics, FMX.Ani,
  FMX.TextLayout;

type
  { A row was clicked or tapped: its index. }
  TPadMenuChooseEvent = procedure(Sender: TObject; AIndex: Integer) of object;

  { One row of the menu. }
  TPadMenuItem = record
    { The text. }
    Text: string;
    { On the right ('' = nothing): a setting's value, a control's name. }
    Value: string;
    { Pictures on the left (PNG files; '' or missing files are left out). }
    Glyphs: TArray<string>;
    { Shown faded: a row of less interest (EpubBuilder: a book already
      transcribed). }
    Dim: Boolean;
  end;

  { The menu: see the unit's text. }
  TPadMenu = class(TComponent)
  private
    { The shade over the whole window (a click on it closes the menu). }
    FShade: TRectangle;
    { The box in the middle. }
    FBox: TRectangle;
    { The title. }
    FTitle: TLabel;
    { The line under the title. }
    FRule: TLine;
    { A question's text, word-wrapped over the box's width, above its
      answers (ShowText; hidden otherwise). }
    FBody: TLabel;
    { The text ShowText passes to Show. }
    FBodyText: string;
    { The hints at the foot. }
    FFoot: TLabel;
    { The rows' scroll box. }
    FScroll: TVertScrollBox;
    { The rows' backgrounds. }
    FRows: TArray<TRectangle>;
    { The rows' values. }
    FValues: TArray<TLabel>;
    { The selected row (-1 = none). }
    FSelected: Integer;
    { Colours: the box, the text, the selected row. }
    FBack, FFore, FAccent: TAlphaColor;
    { Text size. }
    FFontSize: Single;
    { Pictures loaded, by file (freed with the menu). }
    FBitmaps: TObjectDictionary<string, TBitmap>;
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
    { The picture in AFile (loaded once; nil when it cannot be). }
    function Bitmap(const AFile: string): TBitmap;
    { AColor with alpha AAlpha (0 - 255). }
    function Faded(AColor: TAlphaColor; AAlpha: Byte): TAlphaColor;
  public
    { The menu over AParent (the form), hidden.
      @param(AOwner  the owner, frees it)
      @param(AParent  where it shows: the whole of it is shaded) }
    constructor Create(AOwner: TComponent; AParent: TFmxObject); reintroduce;
    { Frees the pictures. }
    destructor Destroy; override;
    { Shows ATitle with rows AItems, ASelected selected, AFoot at the foot.
      @param(ATitle  the title)
      @param(AItems  the rows)
      @param(ASelected  the row selected first)
      @param(AFoot  the hints at the foot ('' = none)) }
    procedure Show(const ATitle: string; const AItems: TArray<TPadMenuItem>; ASelected: Integer;
      const AFoot: string);
    { Shows a text - a question, a note - word-wrapped over a wide box,
      with AItems (its answers) below it (EpubBuilder in Big Picture: one
      text per row cut every line short, Steam Deck 2026-11-20).
      @param(ATitle  the box's title)
      @param(AText  the text (line breaks kept))
      @param(AItems  the answers)
      @param(ASelected  the answer selected first)
      @param(AFoot  the hints at the foot) }
    procedure ShowText(const ATitle, AText: string; const AItems: TArray<TPadMenuItem>; ASelected: Integer;
      const AFoot: string);
    { Hides the menu. }
    procedure Hide;
    { True while it shows.
      @returns(the answer) }
    function Showing: Boolean;
    { Moves the selection by ADelta rows (wrapping at the ends).
      @param(ADelta  rows, negative upwards) }
    procedure Move(ADelta: Integer);
    { Changes row AIndex's value.
      @param(AIndex  the row)
      @param(AValue  its value) }
    procedure SetValue(AIndex: Integer; const AValue: string);
    { Changes the hints at the foot while the menu shows (EpubBuilder: the
      build's progress).
      @param(AFoot  the new text ('' = hidden)) }
    procedure SetFoot(const AFoot: string);
    { The colours: box, text, selected row (the reader's theme).
      @param(ABack  the box)
      @param(AFore  the text)
      @param(AAccent  the selected row) }
    procedure SetColors(ABack, AFore, AAccent: TAlphaColor);
    { A row with text AText and value AValue.
      @param(AText  the text)
      @param(AValue  the value)
      @returns(the row) }
    class function Item(const AText: string; const AValue: string = ''): TPadMenuItem; static;
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
  BOX_SHARE = 0.7;
  { The box's height as a share of the window's, at most. }
  BOX_HEIGHT_SHARE = 0.85;
  { Rows shown at most before the list scrolls. }
  MAX_ROWS = 11;
  { Padding inside the box. }
  PAD = 20;
  { The fade-in, seconds. }
  FADE_S = 0.15;

class function TPadMenu.Item(const AText: string; const AValue: string): TPadMenuItem;
begin
  Result.Text := AText;
  Result.Value := AValue;
  Result.Glyphs := nil;
  Result.Dim := False;
end;

constructor TPadMenu.Create(AOwner: TComponent; AParent: TFmxObject);
begin
  inherited Create(AOwner);
  FBitmaps := TObjectDictionary<string, TBitmap>.Create([doOwnsValues]);
  FSelected := -1;
  FFontSize := 22;
  FBack := TAlphaColors.White;
  FFore := TAlphaColors.Black;
  FAccent := $FFD6E4F5;
  FShade := TRectangle.Create(Self);
  FShade.Parent := AParent;
  FShade.Align := TAlignLayout.Contents;
  FShade.Fill.Color := $A0000000;
  FShade.Stroke.Kind := TBrushKind.None;
  FShade.HitTest := True;
  FShade.OnClick := ShadeClick;
  FShade.Visible := False;
  FBox := TRectangle.Create(Self);
  FBox.Parent := FShade;
  FBox.Align := TAlignLayout.Center;
  FBox.XRadius := 16;
  FBox.YRadius := 16;
  FBox.Stroke.Thickness := 1;
  FBox.HitTest := True;
  FBox.Padding.Rect := TRectF.Create(PAD, PAD * 0.75, PAD, PAD * 0.75);
  FTitle := TLabel.Create(Self);
  FTitle.Parent := FBox;
  FTitle.Align := TAlignLayout.Top;
  FTitle.StyledSettings := FTitle.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size,
    TStyledSetting.Style];
  FTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
  FTitle.Margins.Left := PAD / 2;
  FTitle.HitTest := False;
  FRule := TLine.Create(Self);
  FRule.Parent := FBox;
  FRule.LineType := TLineType.Top;
  FRule.Align := TAlignLayout.Top;
  FRule.Height := 1;
  FRule.Position.Y := 10000;   // below the title
  FRule.Margins.Bottom := PAD / 2;
  FRule.HitTest := False;
  FBody := TLabel.Create(Self);
  FBody.Parent := FBox;
  FBody.Align := TAlignLayout.Top;
  FBody.Position.Y := 20000;   // below the rule
  FBody.StyledSettings := FBody.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  FBody.WordWrap := True;
  FBody.TextSettings.VertAlign := TTextAlign.Leading;
  FBody.Margins.Rect := TRectF.Create(PAD / 2, 0, PAD / 2, PAD / 2);
  FBody.HitTest := False;
  FBody.Visible := False;
  FFoot := TLabel.Create(Self);
  FFoot.Parent := FBox;
  FFoot.Align := TAlignLayout.Bottom;
  FFoot.StyledSettings := FFoot.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  FFoot.TextSettings.HorzAlign := TTextAlign.Center;
  FFoot.Margins.Top := PAD / 2;
  FFoot.HitTest := False;
  FScroll := TVertScrollBox.Create(Self);
  FScroll.Parent := FBox;
  FScroll.Align := TAlignLayout.Client;
  FScroll.ShowScrollBars := False;
end;

destructor TPadMenu.Destroy;
begin
  // the rows, box and shade are freed by their owner (this component) or
  // by the form they sit on, whichever goes first: freeing them here
  // could free them twice when the form went first
  FRows := nil;
  FValues := nil;
  FBitmaps.Free;
  inherited;
end;

function TPadMenu.Faded(AColor: TAlphaColor; AAlpha: Byte): TAlphaColor;
begin
  Result := (AColor and $00FFFFFF) or (TAlphaColor(AAlpha) shl 24);
end;

function TPadMenu.RowHeight: Single;
begin
  Result := Round(FFontSize * 2.0);
end;

function TPadMenu.Bitmap(const AFile: string): TBitmap;
begin
  Result := nil;
  if AFile = '' then
    Exit;
  if FBitmaps.TryGetValue(AFile, Result) then
    Exit;
  try
    if FileExists(AFile) then
      Result := TBitmap.CreateFromFile(AFile);
  except
    Result := nil;
  end;
  // a file that does not load is not tried again
  FBitmaps.Add(AFile, Result);
end;

procedure TPadMenu.ClearRows;
var
  I: Integer;
begin
  for I := 0 to High(FRows) do
    FRows[I].Free;
  FRows := nil;
  FValues := nil;
end;

procedure TPadMenu.Show(const ATitle: string; const AItems: TArray<TPadMenuItem>; ASelected: Integer;
  const AFoot: string);
var
  I, K, Pics: Integer;
  R: TRectangle;
  L, V: TLabel;
  Img: TImage;
  B: TBitmap;
  Icons: TLayout;
  W, H, MaxW, MaxH, Icon, BodyH: Single;
  Body: string;
  TL: TTextLayout;
begin
  // ShowText's text (a plain Show has none)
  Body := FBodyText;
  FBodyText := '';
  ClearRows;
  Icon := RowHeight * 0.8;
  // the widest picture column any row needs: the rows line up
  Pics := 0;
  for I := 0 to High(AItems) do
    Pics := Max(Pics, Length(AItems[I].Glyphs));
  FTitle.Text := ATitle;
  FTitle.TextSettings.Font.Size := FFontSize * 1.2;
  FTitle.TextSettings.FontColor := FFore;
  FTitle.Height := RowHeight;
  FRule.Stroke.Color := Faded(FFore, $40);
  FFoot.Text := AFoot;
  FFoot.Visible := AFoot <> '';
  FFoot.TextSettings.Font.Size := FFontSize * 0.75;
  FFoot.TextSettings.FontColor := Faded(FFore, $A0);
  FFoot.Height := FFontSize * 1.5;
  for I := 0 to High(AItems) do
  begin
    R := TRectangle.Create(Self);
    R.Parent := FScroll;
    R.Position.Y := I * RowHeight;
    R.Height := RowHeight;
    R.Width := 100;
    R.Align := TAlignLayout.Top;
    R.Stroke.Kind := TBrushKind.None;
    R.XRadius := 10;
    R.YRadius := 10;
    R.Tag := I;
    R.HitTest := True;
    R.OnClick := RowClick;
    R.Padding.Rect := TRectF.Create(PAD / 2, 0, PAD / 2, 0);
    if Pics > 0 then
    begin
      // the controls' pictures, in a column of the same width on every row
      Icons := TLayout.Create(R);
      Icons.Parent := R;
      Icons.Align := TAlignLayout.Left;
      Icons.Width := Pics * (Icon + 4) + PAD / 2;
      Icons.HitTest := False;
      for K := 0 to High(AItems[I].Glyphs) do
      begin
        B := Bitmap(AItems[I].Glyphs[K]);
        if B = nil then
          Continue;
        Img := TImage.Create(Icons);
        Img.Parent := Icons;
        Img.SetBounds(K * (Icon + 4), (RowHeight - Icon) / 2, Icon, Icon);
        Img.WrapMode := TImageWrapMode.Fit;
        Img.Bitmap.Assign(B);
        Img.HitTest := False;
      end;
    end;
    V := TLabel.Create(R);
    V.Parent := R;
    V.Align := TAlignLayout.Right;
    V.Width := FFontSize * 8;
    // no value: the text has the row's whole width (the empty column cut
    // short rows' text)
    V.Visible := AItems[I].Value <> '';
    V.StyledSettings := V.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
    V.TextSettings.Font.Size := FFontSize * 0.9;
    V.TextSettings.FontColor := Faded(FFore, $C0);
    V.TextSettings.HorzAlign := TTextAlign.Trailing;
    V.Text := AItems[I].Value;
    V.HitTest := False;
    L := TLabel.Create(R);
    L.Parent := R;
    L.Align := TAlignLayout.Client;
    L.StyledSettings := L.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
    L.TextSettings.Font.Size := FFontSize;
    if AItems[I].Dim then
      L.TextSettings.FontColor := Faded(FFore, $80)
    else
      L.TextSettings.FontColor := FFore;
    L.Text := AItems[I].Text;
    L.HitTest := False;
    FRows := FRows + [R];
    FValues := FValues + [V];
  end;
  // the box: wide enough for a long row, at most BOX_SHARE of the window;
  // as tall as MAX_ROWS rows (or the window allows)
  MaxW := 1E6;
  MaxH := 1E6;
  if FShade.Parent is TCommonCustomForm then
  begin
    MaxW := TCommonCustomForm(FShade.Parent).ClientWidth * BOX_SHARE;
    MaxH := TCommonCustomForm(FShade.Parent).ClientHeight * BOX_HEIGHT_SHARE;
  end
  else if FShade.Parent is TControl then
  begin
    MaxW := TControl(FShade.Parent).Width * BOX_SHARE;
    MaxH := TControl(FShade.Parent).Height * BOX_HEIGHT_SHARE;
  end;
  W := FFontSize * 24 + Pics * (Icon + 4);
  // a text: the widest box the window allows
  if Body <> '' then
    W := Max(W, MaxW);
  W := Max(Min(W, MaxW), FFontSize * 12);
  H := PAD * 1.5 + RowHeight * (1 + Min(Length(AItems), MAX_ROWS)) + PAD / 2 + 1;
  // the text's height at the box's width, measured
  BodyH := 0;
  FBody.Visible := Body <> '';
  if Body <> '' then
  begin
    FBody.TextSettings.Font.Size := FFontSize;
    FBody.TextSettings.FontColor := FFore;
    FBody.Text := Body;
    TL := TTextLayoutManager.DefaultTextLayout.Create;
    try
      TL.BeginUpdate;
      try
        TL.Font.Assign(FBody.TextSettings.Font);
        TL.WordWrap := True;
        TL.MaxSize := TPointF.Create(W - PAD * 3, 100000);
        TL.Text := Body;
      finally
        TL.EndUpdate;
      end;
      BodyH := TL.TextHeight + FFontSize * 0.5;
    finally
      TL.Free;
    end;
    FBody.Height := BodyH;
    H := H + BodyH + PAD / 2;
  end;
  if FFoot.Visible then
    H := H + FFoot.Height + PAD / 2;
  FBox.Fill.Color := FBack;
  FBox.Stroke.Color := Faded(FFore, $30);
  FBox.Width := W;
  FBox.Height := Min(H, MaxH);
  FSelected := EnsureRange(ASelected, -1, High(FRows));
  if (FSelected < 0) and (Length(FRows) > 0) then
    FSelected := 0;
  Paint;
  if not FShade.Visible then
  begin
    // a fade in when it opens (not when it changes list)
    FShade.Opacity := 0;
    FShade.Visible := True;
    TAnimator.AnimateFloat(FShade, 'Opacity', 1, FADE_S);
  end;
  FShade.BringToFront;
  KeepVisible;
end;

procedure TPadMenu.ShowText(const ATitle, AText: string; const AItems: TArray<TPadMenuItem>;
  ASelected: Integer; const AFoot: string);
begin
  FBodyText := AText;
  Show(ATitle, AItems, ASelected, AFoot);
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

procedure TPadMenu.SetValue(AIndex: Integer; const AValue: string);
begin
  if (AIndex >= 0) and (AIndex <= High(FValues)) then
    FValues[AIndex].Text := AValue;
end;

procedure TPadMenu.SetFoot(const AFoot: string);
begin
  if FFoot.Text = AFoot then
    Exit;
  FFoot.Text := AFoot;
  if FFoot.Visible <> (AFoot <> '') then
  begin
    FFoot.Visible := AFoot <> '';
    if FFoot.Height <= 0 then
      FFoot.Height := FFontSize * 1.5;
    FFoot.TextSettings.Font.Size := FFontSize * 0.75;
    FFoot.TextSettings.FontColor := Faded(FFore, $A0);
    // the box's height follows the foot
    if FFoot.Visible then
      FBox.Height := FBox.Height + FFoot.Height + PAD / 2
    else
      FBox.Height := FBox.Height - FFoot.Height - PAD / 2;
  end;
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
