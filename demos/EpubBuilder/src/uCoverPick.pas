(* @abstract(The cover chooser: the covers there are for a book, as
  thumbnails, over the window - clicked, or chosen with the pad.)

  Owner, 2026-11-20: "The user could pick from the options - show a
  thumbnail and let them choose". The first tile is Automatic (the rule of
  uCovers.ChooseCover); then the book's, the audiobook's and the Covers
  folder's pictures (uCovers.CoverOptions). The tile chosen now has a
  frame. *)
unit uCoverPick;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, FMX.Types, FMX.Controls, FMX.Objects,
  FMX.Layouts, FMX.StdCtrls, FMX.Graphics, uCovers;

type
  { Called with the choice ('' automatic, 'book', 'audio', a path), or
    not called when the chooser is closed without one. }
  TCoverChosen = reference to procedure(const AChoice: string);

  { The chooser, over AParent. }
  TCoverPicker = class
  private
    { The dimmed background (holds everything; Visible = showing). }
    FBack: TRectangle;
    { The panel. }
    FPanel: TRectangle;
    { Its title. }
    FTitle: TLabel;
    { The tiles' flow. }
    FFlow: TFlowLayout;
    { The scroll box around the flow. }
    FScroll: TVertScrollBox;
    { The tiles (the first: Automatic). }
    FTiles: array of TRectangle;
    { The choices of the tiles. }
    FChoices: array of string;
    { The tile with the frame. }
    FSelected: Integer;
    { Called on a choice. }
    FOnChosen: TCoverChosen;
    { Scale of the text and tiles (big screens). }
    FScale: Single;
    { A tile was clicked. }
    procedure TileClick(Sender: TObject);
    { The background was clicked: closed. }
    procedure BackClick(Sender: TObject);
    { The frame on tile FSelected. }
    procedure ShowSelected;
  public
    { Made (hidden) over AParent. AScale: 1 on a desk, more on a TV. }
    constructor Create(AParent: TFmxObject; AScale: Single);
    { Shows AOptions after a first tile AAutoCaption (choice ''; none when
      AAutoCaption is ''), the tile of ACurrent framed; AOnChosen gets the
      choice. }
    procedure Show(const ATitle, AAutoCaption: string; const AOptions: TCoverOptionArray; const ACurrent: string;
      const AOnChosen: TCoverChosen);
    { Hides it (no choice). }
    procedure Hide;
    { Moves the frame by ADelta tiles (the pad). }
    procedure Move(ADelta: Integer);
    { Chooses the framed tile (the pad's A). }
    procedure Choose;
    { It is showing. }
    function Showing: Boolean;
  end;

implementation

const
  { A tile's picture box, units (times the scale). }
  TILE_W = 180;
  { A tile's height, units: the picture and two lines. }
  TILE_H = 300;

constructor TCoverPicker.Create(AParent: TFmxObject; AScale: Single);
begin
  inherited Create;
  FScale := AScale;
  if FScale <= 0 then
    FScale := 1;
  FBack := TRectangle.Create(AParent);
  FBack.Parent := AParent;
  FBack.Align := TAlignLayout.Contents;
  FBack.Fill.Color := $C0000000;
  FBack.Stroke.Kind := TBrushKind.None;
  FBack.HitTest := True;
  FBack.OnClick := BackClick;
  FBack.Visible := False;
  FPanel := TRectangle.Create(FBack);
  FPanel.Parent := FBack;
  FPanel.Align := TAlignLayout.Center;
  FPanel.Fill.Color := $FF2B2B2B;
  FPanel.Stroke.Color := $FF808080;
  FPanel.XRadius := 8;
  FPanel.YRadius := 8;
  FPanel.Padding.Rect := RectF(12, 12, 12, 12);
  FPanel.HitTest := True;
  FTitle := TLabel.Create(FPanel);
  FTitle.Parent := FPanel;
  FTitle.Align := TAlignLayout.Top;
  FTitle.Height := 40 * FScale;
  FTitle.StyledSettings := [];
  FTitle.TextSettings.Font.Size := 18 * FScale;
  FTitle.TextSettings.FontColor := TAlphaColors.White;
  FScroll := TVertScrollBox.Create(FPanel);
  FScroll.Parent := FPanel;
  FScroll.Align := TAlignLayout.Client;
  FFlow := TFlowLayout.Create(FScroll);
  FFlow.Parent := FScroll;
  FFlow.Align := TAlignLayout.Top;
  FFlow.HorizontalGap := 12 * FScale;
  FFlow.VerticalGap := 12 * FScale;
end;

procedure TCoverPicker.Show(const ATitle, AAutoCaption: string; const AOptions: TCoverOptionArray;
  const ACurrent: string; const AOnChosen: TCoverChosen);

  procedure AddTile(const AChoice, ACaption: string; const AData: TBytes);
  var
    T: TRectangle;
    Img: TImage;
    L: TLabel;
    M: TMemoryStream;
  begin
    T := TRectangle.Create(FFlow);
    T.Parent := FFlow;
    T.Width := TILE_W * FScale;
    T.Height := TILE_H * FScale;
    T.Fill.Color := $FF3A3A3A;
    T.Stroke.Thickness := 4;
    T.Stroke.Color := $00000000;
    T.XRadius := 6;
    T.YRadius := 6;
    T.Padding.Rect := RectF(6, 6, 6, 6);
    T.Tag := Length(FTiles);
    T.HitTest := True;
    T.Cursor := crHandPoint;
    T.OnClick := TileClick;
    L := TLabel.Create(T);
    L.Parent := T;
    L.Align := TAlignLayout.Bottom;
    L.Height := 48 * FScale;
    L.StyledSettings := [];
    L.TextSettings.Font.Size := 12 * FScale;
    L.TextSettings.FontColor := TAlphaColors.White;
    L.TextSettings.WordWrap := True;
    L.TextSettings.HorzAlign := TTextAlign.Center;
    L.Text := ACaption;
    L.HitTest := False;
    if Length(AData) > 0 then
    begin
      Img := TImage.Create(T);
      Img.Parent := T;
      Img.Align := TAlignLayout.Client;
      Img.WrapMode := TImageWrapMode.Fit;
      Img.HitTest := False;
      M := TMemoryStream.Create;
      try
        M.WriteBuffer(AData[0], Length(AData));
        M.Position := 0;
        try
          Img.Bitmap.LoadFromStream(M);
        except
          // a picture FMX cannot read: the caption only
          L.Text := ACaption + ' (no preview)';
        end;
      finally
        M.Free;
      end;
    end
    else
    begin
      // Automatic: words in place of a picture
      L.Align := TAlignLayout.Client;
      L.TextSettings.VertAlign := TTextAlign.Center;
    end;
    FTiles := FTiles + [T];
    FChoices := FChoices + [AChoice];
  end;

var
  I, Cols, Rows: Integer;
  O: TCoverOption;
begin
  FOnChosen := AOnChosen;
  FTitle.Text := ATitle;
  for I := 0 to High(FTiles) do
    FTiles[I].Free;
  FTiles := nil;
  FChoices := nil;
  if AAutoCaption <> '' then
    AddTile('', AAutoCaption, nil);
  for O in AOptions do
    AddTile(O.Choice, O.Caption, O.Data);
  FSelected := 0;
  for I := 0 to High(FChoices) do
    if SameText(FChoices[I], ACurrent) then
      FSelected := I;
  // as wide as the window lets it, up to 6 tiles a row
  Cols := Length(FTiles);
  if Cols > 6 then
    Cols := 6;
  while (Cols > 1) and (Cols * (TILE_W + 12) * FScale + 40 > FBack.Width * 0.95) do
    Dec(Cols);
  Rows := (Length(FTiles) + Cols - 1) div Cols;
  FPanel.Width := Cols * (TILE_W + 12) * FScale + 36;
  FFlow.Width := Cols * (TILE_W + 12) * FScale;
  FFlow.Height := Rows * (TILE_H + 12) * FScale;
  FPanel.Height := FFlow.Height + FTitle.Height + 40;
  if FPanel.Height > FBack.Height * 0.9 then
    FPanel.Height := FBack.Height * 0.9;
  FBack.Visible := True;
  FBack.BringToFront;
  ShowSelected;
end;

procedure TCoverPicker.ShowSelected;
var
  I: Integer;
begin
  for I := 0 to High(FTiles) do
    if I = FSelected then
      FTiles[I].Stroke.Color := $FFFFC000
    else
      FTiles[I].Stroke.Color := $00000000;
end;

procedure TCoverPicker.Hide;
begin
  FBack.Visible := False;
  FOnChosen := nil;
end;

procedure TCoverPicker.Move(ADelta: Integer);
begin
  if Length(FTiles) = 0 then
    Exit;
  FSelected := (FSelected + ADelta + Length(FTiles)) mod Length(FTiles);
  ShowSelected;
end;

procedure TCoverPicker.Choose;
var
  P: TCoverChosen;
  C: string;
begin
  if (FSelected < 0) or (FSelected > High(FChoices)) then
    Exit;
  P := FOnChosen;
  C := FChoices[FSelected];
  Hide;
  if Assigned(P) then
    P(C);
end;

function TCoverPicker.Showing: Boolean;
begin
  Result := FBack.Visible;
end;

procedure TCoverPicker.TileClick(Sender: TObject);
begin
  FSelected := (Sender as TComponent).Tag;
  Choose;
end;

procedure TCoverPicker.BackClick(Sender: TObject);
begin
  // a click beside the panel closes it; on the panel nothing happens
  Hide;
end;

end.
