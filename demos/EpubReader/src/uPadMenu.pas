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

  { The mouse was used on the menu in a way that is not a row's click:
    AGesture is PADMENU_RIGHT_CLICK, PADMENU_WHEEL_UP or
    PADMENU_WHEEL_DOWN. }
  TPadMenuGestureEvent = procedure(Sender: TObject; const AGesture: string) of object;

const
  { What OnGesture reports - the names of uReaderInput's READER_MENU_POINTER
    (tools/gen_reader_input.py's MENU_POINTER). }
  PADMENU_RIGHT_CLICK = 'right click';
  { The wheel turned away from the user. }
  PADMENU_WHEEL_UP = 'wheel up';
  { The wheel turned towards the user. }
  PADMENU_WHEEL_DOWN = 'wheel down';

type
  { One row of the menu. }
  TPadMenuItem = record
    { The text. }
    Text: string;
    { On the right ('' = nothing): a setting's value, a control's name. }
    Value: string;
    { A third column after the value, shown only by a Show given
      NextColumns (EpubBuilder's leaderboards: place and name, score,
      device). }
    Value2: string;
    { Pictures on the left (PNG files; '' or missing files are left out). }
    Glyphs: TArray<string>;
    { A key's name in the same column on the left, where a picture would be
      ('' = none): the keyboard's form of a row that names its button
      (EpubBuilder's calibration page, owner 2026-11-22: "Calibrate now is
      on the wrong side" - the key had been the value, on the right). }
    Key: string;
    { Shown faded: a row of less interest (EpubBuilder: a book already
      transcribed). }
    Dim: Boolean;
    { The row's text and values in this colour (0 = the menu's own:
      EpubBuilder's leaderboards show the user's own row in the frame's
      yellow, owner 2026-11-23). }
    Color: TAlphaColor;
    { A line of information, not a choice: the selection passes over it
      and a click on it does nothing (EpubBuilder: a benchmark's results,
      a table of text and value). }
    Info: Boolean;
  end;

  { One hint at the menu's foot: a control and what it does (owner's
    standing rule, 2026-11-22: a pad's buttons are shown as Steam's
    pictures of them - a PlayStation pad has no A or B - and the keys when
    the keyboard is in use). }
  TPadHint = record
    { Steam's PNG of the control ('' = none: Name is shown). }
    Glyph: string;
    { The control's or the key's name (shown without a picture). }
    Name: string;
    { What it does ('' = nothing after it: "<left> <right> change"). }
    Text: string;
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
    { Backing field of HiddenAt. }
    FHiddenAt: UInt64;
    { Colours: the box, the text, the selected row. }
    FBack, FFore, FAccent: TAlphaColor;
    { Text size. }
    FFontSize: Single;
    { Backing field of @link(TouchStyle). }
    FTouch: Boolean;
    { Pictures loaded, by file (freed with the menu). }
    FBitmaps: TObjectDictionary<string, TBitmap>;
    { See OnChoose. }
    FOnChoose: TPadMenuChooseEvent;
    { See OnClose. }
    FOnClose: TNotifyEvent;
    { See OnGesture. }
    FOnGesture: TPadMenuGestureEvent;
    { See OnPointer. }
    FOnPointer: TNotifyEvent;
    { When the mouse wheel last moved the selection (ms): one row per
      notch, not per event of a smooth wheel or a touch pad. }
    FWheelTick: UInt64;
    { See MinWidth. }
    FMinWidth: Single;
    { Each row is a line of information (TPadMenuItem.Info). }
    FInfo: TArray<Boolean>;
    { Backing field of @link(NextTitleCentered). }
    FTitleCentered: Boolean;
    { Backing field of @link(NextWidthShare). }
    FNextShare: Single;
    { Backing field of @link(NextColumns). }
    FNextColumns: TArray<Single>;
    { Backing field of @link(NextFrameColor). }
    FNextFrame: TAlphaColor;
    { Backing field of @link(NextHeightShare). }
    FNextHShare: Single;
    { The foot's hints as pictures and words (SetHints; nil = its text). }
    FHintBar: TLayout;
    { What FHintBar shows (SetHints draws it again only when it changes). }
    FHintKey: string;
    { The rows drawn as selected or not. }
    procedure Paint;
    { Takes the foot's hints away (its text shows again). }
    procedure ClearHints;
    { See HasHints. }
    function GetHasHints: Boolean;
    { How wide AText is on one line at font size ASize (the title's font
      family). }
    function TextW(const AText: string; ASize: Single): Single;
    { How wide the box must be for ATitle, AItems and AFoot at this font
      size, before the window's and BOX_MAX_WIDTH's limits (never under
      FFontSize x 24); AValueWidth: the value column's width (0 = no row
      has a value). }
    function Needed(const ATitle: string; const AItems: TArray<TPadMenuItem>; const AFoot: string;
      out AValueWidth: Single): Single;
    { The left column's width for AItems: the widest row of pictures, or
      of a key's name (TPadMenuItem.Key), with its gap; 0 = no row has
      either. }
    function LeftWidth(const AItems: TArray<TPadMenuItem>): Single;
    { The selected row scrolled into view. }
    procedure KeepVisible;
    { A row clicked. }
    procedure RowClick(Sender: TObject);
    { The shade clicked: closed. }
    procedure ShadeClick(Sender: TObject);
    { A mouse button pressed on the shade, the box or a row: the right
      one is OnGesture's PADMENU_RIGHT_CLICK. }
    procedure AnyMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    { The mouse wheel over the menu: OnGesture's PADMENU_WHEEL_UP or
      PADMENU_WHEEL_DOWN; with no OnGesture the selection moves a row
      itself (the rows' scroll box does not scroll by itself). }
    procedure AnyMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
    { The rows freed. }
    procedure ClearRows;
    { Height of a row. }
    function RowHeight: Single;
    { The title's height (a pad's row height, whatever the style). }
    function TitleHeight: Single;
    { The room between two rows (TouchStyle's buttons; 0 otherwise). }
    function RowGap: Single;
    { A row and the room after it. }
    function RowStep: Single;
    { The height of what the menu covers (the window's client height). }
    function ParentHeight: Single;
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
    { How wide Show would make the box for these, the window's limits
      aside: two forms of one list are given the same width with it (set
      MinWidth to the other form's).
      @param(ATitle  the title)
      @param(AItems  the rows)
      @param(AFoot  the hints at the foot)
      @returns(the width) }
    function WidthFor(const ATitle: string; const AItems: TArray<TPadMenuItem>; const AFoot: string): Single;
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
    { The foot as hints: each control's picture (else its name) and what it
      does, in a row in the middle. Show the menu first with HintsText of
      the same hints as its foot (the box is sized by it); they stay until
      the next Show or SetFoot. The same hints again draw nothing.
      @param(AHints  the hints) }
    procedure SetHints(const AHints: TArray<TPadHint>);
    { AHints as words ("Enter choose   Esc back"): the foot Show is given,
      which sizes the box.
      @param(AHints  the hints)
      @returns(the text) }
    class function HintsText(const AHints: TArray<TPadHint>): string; static;
    { A hint.
      @param(AGlyph  Steam's picture of the control ('' = none))
      @param(AName  its name)
      @param(AText  what it does)
      @returns(the hint) }
    class function Hint(const AGlyph, AName, AText: string): TPadHint; static;
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
    { When the box was last closed (TThread.GetTickCount64; 0 = never): a
      second tap that closed it must not reach what is under it
      (EpubReader's library opened a book, zip 366). }
    property HiddenAt: UInt64 read FHiddenAt;
    { Text size (set before Show). }
    property FontSize: Single read FFontSize write FFontSize;
    { A phone's or a tablet's menu (zip 345; owner: "Menu could do with
      proper buttons and be a bit larger ... These menus are really badly
      laid out"): each choice a button of its own - taller, a frame, room
      between them - the box nearly the window's width, a choice's text on
      one line (cut short with an ellipsis, never broken in the middle of
      a word), its value only as wide as it needs. Off (the default): the
      pad's list, as EpubBuilder and Big Picture have it. Set before Show. }
    property TouchStyle: Boolean read FTouch write FTouch;
    { The box is not made narrower than this by the next Show (0 = as its
      own rows need; the window's limits still hold). }
    property MinWidth: Single read FMinWidth write FMinWidth;
    { The foot shows hints (SetHints) rather than a text. }
    property HasHints: Boolean read GetHasHints;
    { The next Show (or ShowText) centres its title; it is left-aligned
      again after it. }
    property NextTitleCentered: Boolean read FTitleCentered write FTitleCentered;
    { The next Show (or ShowText) may be this share of the window wide
      (0 = BOX_SHARE, at most BOX_MAX_WIDTH; set: that share, no other
      limit - EpubBuilder's calibration page, 0.6, owner 2026-11-22: its
      answers were under the text); back to 0 after it. }
    property NextWidthShare: Single read FNextShare write FNextShare;
    { The next Show lays its rows out as a table of three columns - Text,
      Value, Value2 - each this share of a row's width (EpubBuilder's
      leaderboards, owner 2026-11-23: "95% wide with 3 columns
      40/10/50%"), and makes the box as wide as NextWidthShare allows.
      The value column is never narrower than its widest value (the
      third column gives way, and its text is made smaller - down to two
      thirds - when its widest entry would not fit). A row's Key, when rows have one, is a
      column of its own before the text, inside the text's share - a
      place on a leaderboard: right-aligned, in the text's size and
      colour, with room for seven digits whatever the rows hold (owner,
      2026-11-23: "the first column (rank) needs to be wider and the 2nd
      (nickname) correspondingly shorter ... there are now 4 columns").
      A row with no key and neither value keeps its text over the whole
      width. Three numbers; nil (as after the Show) = the
      usual text and value. }
    property NextColumns: TArray<Single> read FNextColumns write FNextColumns;
    { The next Show (or ShowText) frames its box in this colour, four
      thick (EpubBuilder's leaderboards: the yellow of its benchmarks'
      frames, owner 2026-11-23); 0 (as after the Show) = the usual thin
      frame. }
    property NextFrameColor: TAlphaColor read FNextFrame write FNextFrame;
    { The next Show (or ShowText) makes the box this share of the window
      tall, whatever its rows need (EpubBuilder's leaderboards, owner
      2026-11-23: "95% wide and high"; RowsThatFit says how many rows
      such a box holds); 0 (as after the Show) = as tall as its rows, at
      most MAX_ROWS of them. }
    property NextHeightShare: Single read FNextHShare write FNextHShare;
    { How many rows a box AHeightShare of the window tall shows without
      scrolling, at this font size (set FontSize first).
      @param(AHeightShare  the box's share of the window's height)
      @param(AFoot  the box has a foot (hints))
      @returns(the rows, 1 at least) }
    function RowsThatFit(AHeightShare: Single; AFoot: Boolean): Integer;
    { A row clicked or tapped (already selected). }
    property OnChoose: TPadMenuChooseEvent read FOnChoose write FOnChoose;
    { Closed by a click beside the box. }
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
    { The right mouse button pressed anywhere on the menu or its shade, or
      the wheel turned over it. The menu does not decide what they mean:
      the program asks its table of controls (EpubBuilder:
      uReaderInput.ReaderMenuPointerAction) and acts on the action. Not
      set: the right button does nothing and the wheel moves the
      selection. }
    property OnGesture: TPadMenuGestureEvent read FOnGesture write FOnGesture;
    { The mouse or a finger was used on the menu (a click or tap, the
      right button, the wheel), before what it does: the program's hints
      can name keys and the mouse then, not a pad's buttons. }
    property OnPointer: TNotifyEvent read FOnPointer write FOnPointer;
  end;

implementation

const
  { The box's width as a share of the window's, at most. }
  BOX_SHARE = 0.7;
  { The box's width at most, whatever the window's (owner, 2026-11-22:
    "max = 960"). }
  BOX_MAX_WIDTH = 960;
  { The box's height as a share of the window's, at most. }
  BOX_HEIGHT_SHARE = 0.85;
  { Rows shown at most before the list scrolls. }
  MAX_ROWS = 11;
  { TouchStyle: the box's width as a share of the window's ... }
  TOUCH_BOX_SHARE = 0.92;
  { ... and at most (a tablet, a phone held sideways). }
  TOUCH_BOX_MAX_WIDTH = 720;
  { Padding inside the box. }
  PAD = 20;
  { A table's key column (NextColumns) has room for this at least. }
  TABLE_KEY_ROOM = '0000000.';
  { The fade-in, seconds. }
  FADE_S = 0.15;

class function TPadMenu.Item(const AText: string; const AValue: string): TPadMenuItem;
begin
  // every field, the ones added later too: a record's numbers are not
  // cleared by themselves (zip 266's Color was left as it came - rows
  // drawn in whatever colour the memory held, most of them unseen)
  Result := Default(TPadMenuItem);
  Result.Text := AText;
  Result.Value := AValue;
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
  FShade.OnMouseDown := AnyMouseDown;
  FShade.OnMouseWheel := AnyMouseWheel;
  FShade.Visible := False;
  FBox := TRectangle.Create(Self);
  FBox.Parent := FShade;
  FBox.Align := TAlignLayout.Center;
  FBox.XRadius := 16;
  FBox.YRadius := 16;
  FBox.Stroke.Thickness := 1;
  FBox.HitTest := True;
  FBox.OnMouseDown := AnyMouseDown;
  FBox.OnMouseWheel := AnyMouseWheel;
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
  FScroll.OnMouseDown := AnyMouseDown;
  FScroll.OnMouseWheel := AnyMouseWheel;
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
  if FTouch then
    Result := Round(FFontSize * 2.6)
  else
    Result := Round(FFontSize * 2.0);
end;

function TPadMenu.TitleHeight: Single;
begin
  Result := Round(FFontSize * 2.0);
end;

function TPadMenu.RowGap: Single;
begin
  if FTouch then
    Result := Round(FFontSize * 0.5)
  else
    Result := 0;
end;

function TPadMenu.RowStep: Single;
begin
  Result := RowHeight + RowGap;
end;

function TPadMenu.ParentHeight: Single;
begin
  Result := 0;
  if FShade.Parent is TCommonCustomForm then
    Result := TCommonCustomForm(FShade.Parent).ClientHeight
  else if FShade.Parent is TControl then
    Result := TControl(FShade.Parent).Height;
end;

function TPadMenu.RowsThatFit(AHeightShare: Single; AFoot: Boolean): Integer;
var
  Room: Single;
begin
  // the box less what Show puts around the rows: its padding, the title,
  // the rule, the foot
  Room := ParentHeight * AHeightShare - (PAD * 1.5 + TitleHeight + PAD / 2 + 1);
  if AFoot then
    Room := Room - (FFontSize * 1.5 + PAD / 2);
  // a little to spare: a row cut in half is worse than a gap
  Result := Max(1, Trunc((Room - 2) / RowStep));
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
  FInfo := nil;
end;

function TPadMenu.TextW(const AText: string; ASize: Single): Single;
var
  Lay: TTextLayout;
begin
  Result := 0;
  if AText = '' then
    Exit;
  Lay := TTextLayoutManager.DefaultTextLayout.Create;
  try
    Lay.BeginUpdate;
    try
      Lay.Font.Family := FTitle.TextSettings.Font.Family;
      Lay.Font.Size := ASize;
      Lay.WordWrap := False;
      Lay.MaxSize := TPointF.Create(100000, 1000);
      Lay.Text := AText;
    finally
      Lay.EndUpdate;
    end;
    Result := Lay.TextWidth;
  finally
    Lay.Free;
  end;
end;

function TPadMenu.Needed(const ATitle: string; const AItems: TArray<TPadMenuItem>; const AFoot: string;
  out AValueWidth: Single): Single;
var
  I: Integer;
  RowW, Left: Single;
begin
  Left := LeftWidth(AItems);
  // the value column: as wide as its widest value, not under FFontSize x 8
  AValueWidth := 0;
  for I := 0 to Length(AItems) - 1 do
    AValueWidth := Max(AValueWidth, TextW(AItems[I].Value, FFontSize * 0.9));
  if AValueWidth > 0 then
    AValueWidth := Max(AValueWidth + 8, FFontSize * 8);
  // the widest of the title, the foot and the rows: nothing cut short
  // with "..." while the box may grow
  Result := Max(TextW(ATitle, FFontSize * 1.2), TextW(AFoot, FFontSize * 0.75)) + 8;
  for I := 0 to Length(AItems) - 1 do
  begin
    RowW := TextW(AItems[I].Text, FFontSize) + 8;
    if Left > 0 then
      RowW := RowW + Left;
    if AItems[I].Value <> '' then
      RowW := RowW + AValueWidth + PAD / 2;
    Result := Max(Result, RowW);
  end;
  // the box's padding and the rows' own; never narrower than it was
  Result := Max(Result + PAD * 3, FFontSize * 24 + Left);
end;

function TPadMenu.LeftWidth(const AItems: TArray<TPadMenuItem>): Single;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(AItems) do
  begin
    Result := Max(Result, Length(AItems[I].Glyphs) * (RowHeight * 0.8 + 4));
    if AItems[I].Key <> '' then
      Result := Max(Result, TextW(AItems[I].Key, FFontSize * 0.9) + 8);
  end;
  if Result > 0 then
    Result := Result + PAD / 2;
end;

function TPadMenu.WidthFor(const ATitle: string; const AItems: TArray<TPadMenuItem>; const AFoot: string): Single;
var
  ValW: Single;
begin
  Result := Needed(ATitle, AItems, AFoot, ValW);
end;

procedure TPadMenu.Show(const ATitle: string; const AItems: TArray<TPadMenuItem>; ASelected: Integer;
  const AFoot: string);
var
  I, K: Integer;
  R: TRectangle;
  L, V, V2, KeyL: TLabel;
  Img: TImage;
  B: TBitmap;
  Icons: TLayout;
  W, H, MaxW, MaxH, Icon, BodyH, ValW, Need, LeftW, Inner, ColText, ColValue, ThirdW, ThirdRoom, ThirdSize: Single;
  Body: string;
  TL: TTextLayout;
  Table: Boolean;
  Cols: TArray<Single>;
  Texts, Seconds: TArray<TLabel>;
begin
  // a table of three columns, for this Show only (NextColumns)
  Cols := FNextColumns;
  FNextColumns := nil;
  Table := Length(Cols) = 3;
  Texts := nil;
  Seconds := nil;
  // ShowText's text (a plain Show has none)
  Body := FBodyText;
  FBodyText := '';
  ClearRows;
  // the hints are the last Show's: SetHints gives this one's
  ClearHints;
  Icon := RowHeight * 0.8;
  // the widest picture (or key) column any row needs: the rows line up
  LeftW := LeftWidth(AItems);
  // a table's keys are drawn in the text's size, and their column is as
  // wide on every page: room for TABLE_KEY_ROOM at least
  if Table and (LeftW > 0) then
  begin
    LeftW := Max(LeftW, TextW(TABLE_KEY_ROOM, FFontSize) + 8 + PAD / 2);
    for I := 0 to High(AItems) do
      LeftW := Max(LeftW, TextW(AItems[I].Key, FFontSize) + 8 + PAD / 2);
  end;
  FTitle.Text := ATitle;
  // centred for this Show only (NextTitleCentered)
  if FTitleCentered then
    FTitle.TextSettings.HorzAlign := TTextAlign.Center
  else
    FTitle.TextSettings.HorzAlign := TTextAlign.Leading;
  FTitleCentered := False;
  FTitle.TextSettings.Font.Size := FFontSize * 1.2;
  FTitle.TextSettings.FontColor := FFore;
  FTitle.Height := TitleHeight;
  FRule.Stroke.Color := Faded(FFore, $40);
  FFoot.Text := AFoot;
  FFoot.Visible := AFoot <> '';
  FFoot.TextSettings.Font.Size := FFontSize * 0.75;
  FFoot.TextSettings.FontColor := Faded(FFore, $A0);
  FFoot.Height := FFontSize * 1.5;
  // the value column and the box as wide as the rows, the title and the
  // foot need at this font size (Needed)
  Need := Needed(ATitle, AItems, AFoot, ValW);
  for I := 0 to High(AItems) do
  begin
    R := TRectangle.Create(Self);
    R.Parent := FScroll;
    R.Position.Y := I * RowStep;
    R.Height := RowHeight;
    R.Width := 100;
    R.Align := TAlignLayout.Top;
    R.Stroke.Kind := TBrushKind.None;
    R.XRadius := 10;
    R.YRadius := 10;
    if FTouch then
    begin
      // a button: framed, room below it (not after a line of information)
      R.Margins.Bottom := RowGap;
      if not AItems[I].Info then
      begin
        R.Stroke.Kind := TBrushKind.Solid;
        R.Stroke.Color := Faded(FFore, $40);
        R.Stroke.Thickness := 1;
      end;
      R.XRadius := 12;
      R.YRadius := 12;
    end;
    R.Tag := I;
    FInfo := FInfo + [AItems[I].Info];
    R.HitTest := True;
    R.OnClick := RowClick;
    R.OnMouseDown := AnyMouseDown;
    R.OnMouseWheel := AnyMouseWheel;
    R.Padding.Rect := TRectF.Create(PAD / 2, 0, PAD / 2, 0);
    // (a table's line with no key and no values has the whole width)
    if (LeftW > 0) and not (Table and (AItems[I].Key = '') and (Length(AItems[I].Glyphs) = 0) and
      (AItems[I].Value = '') and (AItems[I].Value2 = '')) then
    begin
      // the controls' pictures (or the keys' names), in a column of the
      // same width on every row
      Icons := TLayout.Create(R);
      Icons.Parent := R;
      Icons.Align := TAlignLayout.Left;
      Icons.Width := LeftW;
      Icons.HitTest := False;
      if AItems[I].Key <> '' then
      begin
        KeyL := TLabel.Create(Icons);
        KeyL.Parent := Icons;
        KeyL.Align := TAlignLayout.Client;
        KeyL.StyledSettings := KeyL.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
        KeyL.TextSettings.Font.Size := FFontSize * 0.9;
        KeyL.TextSettings.FontColor := Faded(FFore, $C0);
        KeyL.TextSettings.WordWrap := False;
        if Table then
        begin
          // a table's first column: as its text, against the next column
          KeyL.TextSettings.Font.Size := FFontSize;
          if AItems[I].Color <> 0 then
            KeyL.TextSettings.FontColor := AItems[I].Color
          else if AItems[I].Dim then
            KeyL.TextSettings.FontColor := Faded(FFore, $80)
          else
            KeyL.TextSettings.FontColor := FFore;
          KeyL.TextSettings.HorzAlign := TTextAlign.Trailing;
          KeyL.Margins.Right := PAD / 2;
        end;
        KeyL.Text := AItems[I].Key;
        KeyL.HitTest := False;
      end;
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
    V.Width := Max(ValW, FFontSize * 8);
    // a button's value: only as wide as it is (the text has the rest)
    if FTouch and not Table then
    begin
      V.Width := TextW(AItems[I].Value, FFontSize * 0.9) + PAD;
      V.TextSettings.WordWrap := False;
    end;
    // no value: the text has the row's whole width (the empty column cut
    // short rows' text)
    V.Visible := (AItems[I].Value <> '') or (Table and (AItems[I].Value2 <> ''));
    V.StyledSettings := V.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
    V.TextSettings.Font.Size := FFontSize * 0.9;
    V.TextSettings.FontColor := Faded(FFore, $C0);
    if AItems[I].Color <> 0 then
      V.TextSettings.FontColor := AItems[I].Color;
    V.TextSettings.HorzAlign := TTextAlign.Trailing;
    V.Text := AItems[I].Value;
    V.HitTest := False;
    L := TLabel.Create(R);
    L.Parent := R;
    L.Align := TAlignLayout.Client;
    L.StyledSettings := L.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
    L.TextSettings.Font.Size := FFontSize;
    if AItems[I].Color <> 0 then
      L.TextSettings.FontColor := AItems[I].Color
    else if AItems[I].Dim then
      L.TextSettings.FontColor := Faded(FFore, $80)
    else
      L.TextSettings.FontColor := FFore;
    L.Text := AItems[I].Text;
    L.HitTest := False;
    // a button's text on one line: cut short at its end, never broken
    // inside a word ("Skia4D / elphi", the phone, 2026-11-26)
    if FTouch then
    begin
      L.TextSettings.WordWrap := False;
      L.TextSettings.Trimming := TTextTrimming.Character;
    end;
    // a table's third column (placed below, once the box's width is known)
    V2 := nil;
    if Table and V.Visible then
    begin
      V2 := TLabel.Create(R);
      V2.Parent := R;
      V2.StyledSettings := V2.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
      V2.TextSettings.Font.Size := FFontSize * 0.9;
      V2.TextSettings.FontColor := Faded(FFore, $C0);
      if AItems[I].Color <> 0 then
        V2.TextSettings.FontColor := AItems[I].Color;
      V2.TextSettings.WordWrap := False;
      V2.Text := AItems[I].Value2;
      V2.HitTest := False;
    end;
    Texts := Texts + [L];
    Seconds := Seconds + [V2];
    FRows := FRows + [R];
    FValues := FValues + [V];
  end;
  // the box: wide enough for its longest row, at most BOX_SHARE of the
  // window and BOX_MAX_WIDTH;
  // as tall as MAX_ROWS rows (or the window allows)
  MaxW := 1E6;
  MaxH := 1E6;
  if FShade.Parent is TCommonCustomForm then
  begin
    MaxW := TCommonCustomForm(FShade.Parent).ClientWidth * BOX_SHARE;
    MaxH := TCommonCustomForm(FShade.Parent).ClientHeight * BOX_HEIGHT_SHARE;
    if FNextShare > 0 then
      MaxW := TCommonCustomForm(FShade.Parent).ClientWidth * FNextShare;
  end
  else if FShade.Parent is TControl then
  begin
    MaxW := TControl(FShade.Parent).Width * BOX_SHARE;
    MaxH := TControl(FShade.Parent).Height * BOX_HEIGHT_SHARE;
    if FNextShare > 0 then
      MaxW := TControl(FShade.Parent).Width * FNextShare;
  end;
  // NextWidthShare: that share, for this Show only
  if FNextShare <= 0 then
    MaxW := Min(MaxW, BOX_MAX_WIDTH);
  // a touch menu: nearly the window's width, whatever its rows need
  if FTouch and (FNextShare <= 0) then
  begin
    if FShade.Parent is TCommonCustomForm then
      MaxW := Min(TCommonCustomForm(FShade.Parent).ClientWidth * TOUCH_BOX_SHARE, TOUCH_BOX_MAX_WIDTH)
    else if FShade.Parent is TControl then
      MaxW := Min(TControl(FShade.Parent).Width * TOUCH_BOX_SHARE, TOUCH_BOX_MAX_WIDTH);
    Need := MaxW;
  end;
  FNextShare := 0;
  W := Max(Need, FMinWidth);
  // a text, a table: the widest box the window allows
  if (Body <> '') or Table then
    W := Max(W, MaxW);
  W := Max(Min(W, MaxW), FFontSize * 12);
  H := PAD * 1.5 + TitleHeight + RowStep * Min(Length(AItems), MAX_ROWS) + PAD / 2 + 1;
  // the text's height at the box's width, measured
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
        // a little narrower than the label: the label's own drawing can
        // wrap a line the measure did not (EpubBuilder's calibration page,
        // 2026-11-22: its last answer pushed out of sight)
        TL.MaxSize := TPointF.Create(W - PAD * 4, 100000);
        TL.Text := Body;
      finally
        TL.EndUpdate;
      end;
      // a spare line for the same reason (half of one in a touch menu:
      // its box is wide, and the gap under the text looked lost)
      if FTouch then
        BodyH := TL.TextHeight + FFontSize * 0.75
      else
        BodyH := TL.TextHeight + FFontSize * 1.5;
    finally
      TL.Free;
    end;
    FBody.Height := BodyH;
    H := H + BodyH + PAD / 2;
  end;
  if FFoot.Visible then
    H := H + FFoot.Height + PAD / 2;
  if Table then
  begin
    // a row's width without the box's padding and its own (Needed adds
    // the same); the columns from the left: text, value, the rest
    // the key column is part of the first share: the text is that much
    // shorter
    Inner := Max(W - PAD * 3, FFontSize * 12);
    ColText := Max(Inner * Cols[0] - LeftW, FFontSize * 6);
    // the value column: its share, or its widest value when that is
    // wider - measured here (ValW is a menu's: eight font sizes at least,
    // which on the Deck took the third column's room: owner's screenshot,
    // 2026-11-23, the devices cut short)
    ColValue := 0;
    ThirdW := 0;
    for I := 0 to High(AItems) do
    begin
      ColValue := Max(ColValue, TextW(AItems[I].Value, FFontSize * 0.9) + 8);
      ThirdW := Max(ThirdW, TextW(AItems[I].Value2, FFontSize * 0.9) + 8);
    end;
    ColValue := Max(Inner * Cols[1], ColValue);
    // the third column has the rest; its text smaller when the widest
    // does not fit (not under two thirds of the menu's size)
    ThirdSize := FFontSize * 0.9;
    ThirdRoom := Inner - LeftW - ColText - ColValue - PAD;
    if (ThirdW > ThirdRoom) and (ThirdRoom > 0) then
      ThirdSize := Max(FFontSize * 0.66, ThirdSize * ThirdRoom / ThirdW);
    for I := 0 to High(Seconds) do
      if Seconds[I] <> nil then
      begin
        Seconds[I].TextSettings.Font.Size := ThirdSize;
        Texts[I].Align := TAlignLayout.Left;
        Texts[I].Width := ColText;
        Texts[I].Position.X := LeftW;
        FValues[I].Align := TAlignLayout.Left;
        FValues[I].Width := ColValue;
        FValues[I].Position.X := LeftW + ColText + 1;
        // the value against the third column, a gap between them
        FValues[I].TextSettings.HorzAlign := TTextAlign.Trailing;
        Seconds[I].Align := TAlignLayout.Client;
        Seconds[I].Margins.Left := PAD;
        Seconds[I].TextSettings.HorzAlign := TTextAlign.Leading;
      end;
  end;
  FBox.Fill.Color := FBack;
  FBox.Stroke.Color := Faded(FFore, $30);
  FBox.Stroke.Thickness := 1;
  // a frame of its own colour, for this Show only (NextFrameColor)
  if FNextFrame <> 0 then
  begin
    FBox.Stroke.Color := FNextFrame;
    FBox.Stroke.Thickness := 4;
  end;
  FNextFrame := 0;
  FBox.Width := W;
  FBox.Height := Min(H, MaxH);
  // that share of the window, for this Show only (NextHeightShare)
  if (FNextHShare > 0) and (ParentHeight > 0) then
    FBox.Height := ParentHeight * FNextHShare;
  FNextHShare := 0;
  FSelected := EnsureRange(ASelected, -1, High(FRows));
  if (FSelected < 0) and (Length(FRows) > 0) then
    FSelected := 0;
  // never on a line of information: the next choice after it
  if (FSelected >= 0) and FInfo[FSelected] then
  begin
    FSelected := FSelected - 1;
    Move(1);
  end;
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
  if FShade.Visible then
    FHiddenAt := TThread.GetTickCount64;
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
  N, K: Integer;
begin
  N := Length(FRows);
  if N = 0 then
    Exit;
  FSelected := ((FSelected + ADelta) mod N + N) mod N;
  // over lines of information (TPadMenuItem.Info), in the same direction;
  // a menu of nothing but them keeps the row reached
  K := 0;
  while (K < N) and (FSelected <= High(FInfo)) and FInfo[FSelected] do
  begin
    if ADelta < 0 then
      FSelected := (FSelected - 1 + N) mod N
    else
      FSelected := (FSelected + 1) mod N;
    Inc(K);
  end;
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
  if (FFoot.Text = AFoot) and (FHintBar = nil) then
    Exit;
  ClearHints;
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

procedure TPadMenu.ClearHints;
begin
  FreeAndNil(FHintBar);
  FHintKey := '';
end;

function TPadMenu.GetHasHints: Boolean;
begin
  Result := FHintBar <> nil;
end;

class function TPadMenu.Hint(const AGlyph, AName, AText: string): TPadHint;
begin
  Result.Glyph := AGlyph;
  Result.Name := AName;
  Result.Text := AText;
end;

class function TPadMenu.HintsText(const AHints: TArray<TPadHint>): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AHints) do
  begin
    if Result <> '' then
    begin
      // "Left Right change": a hint without words joins the next
      if (I > 0) and (AHints[I - 1].Text = '') then
        Result := Result + ' '
      else
        Result := Result + '   ';
    end;
    Result := Result + AHints[I].Name;
    if AHints[I].Text <> '' then
      Result := Result + ' ' + AHints[I].Text;
  end;
end;

procedure TPadMenu.SetHints(const AHints: TArray<TPadHint>);
var
  I: Integer;
  Key: string;
  X, H, G, Size, W: Single;
  B: TBitmap;
  Img: TImage;
  L: TLabel;
  Color: TAlphaColor;

  { A word of the row at X. }
  procedure Word(const AText: string);
  begin
    W := TextW(AText, Size) + 2;
    L := TLabel.Create(FHintBar);
    L.Parent := FHintBar;
    L.StyledSettings := L.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
    L.TextSettings.Font.Size := Size;
    L.TextSettings.FontColor := Color;
    L.TextSettings.WordWrap := False;
    L.TextSettings.VertAlign := TTextAlign.Center;
    L.HitTest := False;
    L.SetBounds(X, 0, W, H);
    L.Text := AText;
    X := X + W;
  end;

begin
  Key := '';
  for I := 0 to High(AHints) do
    Key := Key + AHints[I].Glyph + #1 + AHints[I].Name + #1 + AHints[I].Text + #2;
  if (FHintBar <> nil) and (Key = FHintKey) then
    Exit;
  ClearHints;
  if Length(AHints) = 0 then
    Exit;
  FHintKey := Key;
  Size := FFontSize * 0.75;
  Color := Faded(FFore, $A0);
  if FFoot.Height <= 0 then
    FFoot.Height := FFontSize * 1.5;
  FFoot.Visible := True;
  FFoot.Text := '';
  H := FFoot.Height;
  G := H * 0.9;
  FHintBar := TLayout.Create(Self);
  FHintBar.Parent := FFoot;
  FHintBar.HitTest := False;
  X := 0;
  for I := 0 to High(AHints) do
  begin
    // the control: Steam's picture, else its name
    B := Bitmap(AHints[I].Glyph);
    if B <> nil then
    begin
      Img := TImage.Create(FHintBar);
      Img.Parent := FHintBar;
      Img.SetBounds(X, (H - G) / 2, G, G);
      Img.WrapMode := TImageWrapMode.Fit;
      Img.Bitmap.Assign(B);
      Img.HitTest := False;
      X := X + G;
    end
    else
      Word(AHints[I].Name);
    X := X + 4;
    if AHints[I].Text <> '' then
    begin
      Word(AHints[I].Text);
      // the next hint at a distance
      if I < High(AHints) then
        X := X + Size * 1.5;
    end;
  end;
  // the row in the foot's middle
  FHintBar.SetBounds(Max(0, (FFoot.Width - X) / 2), 0, X, H);
  FHintBar.Align := TAlignLayout.Center;
  FHintBar.Width := X;
  FHintBar.Height := H;
end;

procedure TPadMenu.Paint;
var
  I: Integer;
begin
  for I := 0 to High(FRows) do
    if I = FSelected then
      FRows[I].Fill.Color := FAccent
    // a touch menu's buttons stand out from the box (not its lines of
    // information)
    else if FTouch and not ((I <= High(FInfo)) and FInfo[I]) then
      FRows[I].Fill.Color := Faded(FFore, $10)
    else
      FRows[I].Fill.Color := TAlphaColors.Null;
end;

procedure TPadMenu.KeepVisible;
var
  Top, View: Single;
begin
  if (FSelected < 0) or (FSelected > High(FRows)) then
    Exit;
  Top := FSelected * RowStep;
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
  // a line of information is not a choice
  if (I >= 0) and (I <= High(FInfo)) and FInfo[I] then
    Exit;
  FSelected := I;
  Paint;
  if Assigned(FOnPointer) then
    FOnPointer(Self);
  // later: the choice may close the menu, which frees this row
  TThread.ForceQueue(nil,
    procedure
    begin
      if Showing and Assigned(FOnChoose) then
        FOnChoose(Self, I);
    end);
end;

procedure TPadMenu.AnyMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if Button <> TMouseButton.mbRight then
    Exit;
  if Assigned(FOnPointer) then
    FOnPointer(Self);
  // later: what it means may show another list, which frees the row
  // clicked
  TThread.ForceQueue(nil,
    procedure
    begin
      if Showing and Assigned(FOnGesture) then
        FOnGesture(Self, PADMENU_RIGHT_CLICK);
    end);
end;

procedure TPadMenu.AnyMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
const
  { A row at most this often, ms. }
  WHEEL_MS = 60;
var
  T: UInt64;
begin
  Handled := True;
  if (WheelDelta = 0) or (Length(FRows) = 0) then
    Exit;
  T := TThread.GetTickCount64;
  if T - FWheelTick < WHEEL_MS then
    Exit;
  FWheelTick := T;
  if Assigned(FOnPointer) then
    FOnPointer(Self);
  if Assigned(FOnGesture) then
  begin
    if WheelDelta > 0 then
      FOnGesture(Self, PADMENU_WHEEL_UP)
    else
      FOnGesture(Self, PADMENU_WHEEL_DOWN);
  end
  else if WheelDelta > 0 then
    Move(-1)
  else
    Move(1);
end;

procedure TPadMenu.ShadeClick(Sender: TObject);
begin
  if Assigned(FOnPointer) then
    FOnPointer(Self);
  // a click on the box itself is the box's (HitTest), not the shade's
  if Assigned(FOnClose) then
    FOnClose(Self)
  else
    Hide;
end;

end.
