(* @abstract(@link(TEpubView): shows a document of an EPUB book, drawn with
  Skia - reflowed text in the book's styles, its pictures, and a
  highlight that follows the narration.)

  Link it to a @code(TEpubUnum) (property @link(TEpubView.Epub)) and call
  @link(TEpubView.ShowDocument); the view lays the document out with
  Epub.Layout (blocks of styled runs) and Skia's paragraph engine, scrolls
  with the wheel and the keys, and highlights any range of the book's words
  (@link(TEpubView.Highlight)) - what a media overlay clip or an alignment
  points at. @link(TEpubView.OnWordClick) gives the word under a click (to
  start the audio there).

  Skia draws the view whatever FMX's own canvas is (GlobalUseSkia is not
  needed); the program needs Skia enabled (Project > Enable Skia) so its
  library (sk4d.dll / libsk4d.so / ...) is deployed. Same code on Windows,
  macOS, Linux (SteamOS included), Android and iOS. *)
unit Epub.FMX.View;

{$I ..\lib\Epub.inc}

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  System.Skia, FMX.Types, FMX.Controls, FMX.Skia,
  Epub.Css, Epub.Layout, Epub.Book, Epub.Components;

type
  { A word was clicked; AWord indexes the book's Words. }
  TEpubWordEvent = procedure(Sender: TObject; AWord: Integer) of object;

  { One laid-out block of the shown document. }
  TEpubViewItem = record
    { The block (index into the layout's Blocks). }
    Block: Integer;
    { Its paragraph (nil for a picture or a rule). }
    Paragraph: ISkParagraph;
    { Its picture (nil when none or unreadable). }
    Image: ISkImage;
    { Characters put in front of the block's text (the first-line indent). }
    Offset: Integer;
    { Left edge, px from the view's left. }
    X: Single;
    { Top, px from the document's top. }
    Top: Single;
    { Width, px. }
    Width: Single;
    { Height, px. }
    Height: Single;
    { A chapter break is drawn above it: the rule's middle, px from the
      document's top (0 = none). }
    RuleY: Single;
  end;
  { The laid-out blocks. }
  TEpubViewItemArray = array of TEpubViewItem;

  { Shows one document of a book, scrollable, with a word highlight. }
  [ComponentPlatformsAttribute(EPUB_COMPONENT_PLATFORMS)]
  TEpubView = class(TSkCustomControl)
  private
    { Backing field of @link(Epub). }
    FEpub: TCustomEpub;
    { Backing field of @link(Document). }
    FDocument: Integer;
    { Layout of the shown document (nil when none). }
    FLayout: TEpubDocLayout;
    { The component's BookSerial when FLayout was made. }
    FLayoutSerial: Integer;
    { The laid-out blocks. }
    FItems: TEpubViewItemArray;
    { Width the items were laid out for (-1 = lay out again). }
    FLaidOutWidth: Single;
    { Height of the whole document, px. }
    FContentHeight: Single;
    { Backing field of @link(ScrollPos). }
    FScroll: Single;
    { Where a smooth scroll is going (@link(ScrollToWord) with ACenter). }
    FScrollTarget: Single;
    { Moves FScroll towards FScrollTarget a step per tick (nil until the
      first smooth scroll). }
    FScrollTimer: TTimer;
    { Backing field of @link(FontSize). }
    FFontSize: Single;
    { Backing field of @link(FontFamily). }
    FFontFamily: string;
    { Backing field of @link(MonoFamily). }
    FMonoFamily: string;
    { Backing field of @link(LineHeight). }
    FLineHeight: Single;
    { Backing field of @link(ParagraphSpacing). }
    FParagraphSpacing: Single;
    { Backing field of @link(PageMargin). }
    FPageMargin: Single;
    { Backing field of @link(TextColor). }
    FTextColor: TAlphaColor;
    { Backing field of @link(BackgroundColor). }
    FBackgroundColor: TAlphaColor;
    { Backing field of @link(HighlightColor). }
    FHighlightColor: TAlphaColor;
    { Backing field of @link(LinkColor). }
    FLinkColor: TAlphaColor;
    { Backing field of @link(NoteColor). }
    FNoteColor: TAlphaColor;
    { Backing field of @link(ShowProgress). }
    FShowProgress: Boolean;
    { Backing field of @link(ChapterBreaks). }
    FChapterBreaks: TArray<Integer>;
    { First highlighted word (book index), -1 = none. }
    FHighFirst: Integer;
    { Last highlighted word. }
    FHighLast: Integer;
    { Backing field of @link(OnWordClick). }
    FOnWordClick: TEpubWordEvent;
    { Backing field of @link(OnDocumentChange). }
    FOnDocumentChange: TNotifyEvent;
    { Links to a book component. }
    procedure SetEpub(const AValue: TCustomEpub);
    { Font size; lays out again. }
    procedure SetFontSize(const AValue: Single);
    { Font family; lays out again. }
    procedure SetFontFamily(const AValue: string);
    { Line height; lays out again. }
    procedure SetLineHeight(const AValue: Single);
    { Scroll position (clamped). }
    procedure SetScrollPos(const AValue: Single);
    { Stops a smooth scroll where it is. }
    procedure StopScrolling;
    { Scrolls to ATarget smoothly - at once when it is far (another part
      of the document) or the view is not shown. }
    procedure SmoothScrollTo(ATarget: Single);
    { A step of the smooth scroll. }
    procedure ScrollTimer(Sender: TObject);
    { The top and height of the line word AWord (book index) is on, in
      the document (px); False when it has no line (a picture). }
    function WordLine(AWord: Integer; out ATop, AHeight: Single): Boolean;
    { A colour property changed: draw again. }
    procedure SetColor(const AIndex: Integer; const AValue: TAlphaColor);
    { A colour property's value. }
    function GetColor(const AIndex: Integer): TAlphaColor;
    { The book (nil when none is open). }
    function Book: TEpubBook;
    { True when FLayout is of the book that is open now (the component may
      have opened another one since). }
    function LayoutCurrent: Boolean;
    { Lays the items out for AWidth px. }
    procedure LayoutItems(AWidth: Single);
    { The Skia paragraph of block ABlock, AWidth px wide. }
    function MakeParagraph(const ABlock: TEpubBlock; AWidth: Single; out AOffset: Integer): ISkParagraph;
    { The item showing block ABlock, -1 when none. }
    function ItemOfBlock(ABlock: Integer): Integer;
    { Lays out again (font or size change). }
    procedure Relayout;
    { Height of the progress strip at the bottom, px (0 when not shown). }
    function FooterHeight: Single;
    { Height the text is shown in: the view less the progress strip. }
    function TextHeight: Single;
    { Shows or hides the progress strip. }
    procedure SetShowProgress(const AValue: Boolean);
    { Sets the chapter breaks; lays out again. }
    procedure SetChapterBreaks(const AValue: TArray<Integer>);
    { True when block ABlock of the shown document starts at a word of
      ChapterBreaks. }
    function BreakBefore(ABlock: Integer): Boolean;
    { Draws the progress strip in ARect. }
    procedure DrawFooter(const ACanvas: ISkCanvas; const ARect: TRectF);
  protected
    { Draws the visible blocks and the highlight. }
    procedure Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single); override;
    { Lays out again when the width changes. }
    procedure Resize; override;
    { Scrolls. }
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
    { Up / Down, Page Up / Page Down / Space, Home / End. }
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    { A click on a word raises OnWordClick. }
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    { Forgets a freed book component. }
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    { A view with reading defaults. }
    constructor Create(AOwner: TComponent); override;
    { Frees the layout. }
    destructor Destroy; override;
    { Shows document ADoc (index into the book's Documents) from the top. }
    procedure ShowDocument(ADoc: Integer);
    { Shows document ADoc at the element with id AId ('' = the top). }
    procedure ShowFragment(ADoc: Integer; const AId: string);
    { Highlights words AFirst..ALast (indexes into the book's Words); -1 =
      none. Does not scroll (see @link(ScrollToWord)). }
    procedure Highlight(AFirst, ALast: Integer);
    { Removes the highlight. }
    procedure ClearHighlight;
    { Shows word AWord (switching document when needed). ACenter = @false:
      scrolls only when it is not already well inside the view. ACenter =
      @true (reading along): scrolls smoothly so the word's LINE is in the
      middle of the view - each new line moves the text up by a line -
      except where the document's start or end does not allow it. }
    procedure ScrollToWord(AWord: Integer; ACenter: Boolean = False);
    { The word at a point of the view (book index), -1 when none. }
    function WordAt(X, Y: Single): Integer;
    { Scrolls one screen down (True) or up. }
    procedure Page(ADown: Boolean);
    { Clears the view (no document). }
    procedure Clear;
    { The shown document, -1 when none. }
    property Document: Integer read FDocument;
    { The shown document's layout (nil when none). }
    property Layout: TEpubDocLayout read FLayout;
    { Scroll position, px from the top. }
    property ScrollPos: Single read FScroll write SetScrollPos;
    { Height of the whole document, px. }
    property ContentHeight: Single read FContentHeight;
    { How far through the book the view is, 0 .. 1 (-1 when nothing is
      shown): the words of the documents before this one plus the share
      of this one's words above the top of the view (by height); 1 at the
      end of the last document. By words, so the text size does not
      change it. }
    function Progress: Single;
    { Words (book indexes) that start a chapter the book itself does not
      mark - an audiobook's chapters: the paragraph starting with one gets
      a short centred rule above it, with room around it (none at the very
      top of a document). Empty = none. }
    property ChapterBreaks: TArray<Integer> read FChapterBreaks write SetChapterBreaks;
  published
    { The book component whose book is shown. }
    property Epub: TCustomEpub read FEpub write SetEpub;
    { Base font size, px. }
    property FontSize: Single read FFontSize write SetFontSize;
    { Font family of the text. }
    property FontFamily: string read FFontFamily write SetFontFamily;
    { Font family of monospace text. }
    property MonoFamily: string read FMonoFamily write FMonoFamily;
    { Line height as a factor of the font size. }
    property LineHeight: Single read FLineHeight write SetLineHeight;
    { Space between paragraphs, em (paragraphs with a first-line indent get
      a third of it, as books set them). }
    property ParagraphSpacing: Single read FParagraphSpacing write FParagraphSpacing;
    { Margin round the text, px (not FMX's Padding, which TSkCustomControl
      publishes). }
    property PageMargin: Single read FPageMargin write FPageMargin;
    { Text colour. }
    property TextColor: TAlphaColor index 0 read GetColor write SetColor;
    { Page colour. }
    property BackgroundColor: TAlphaColor index 1 read GetColor write SetColor;
    { Colour behind the highlighted words. }
    property HighlightColor: TAlphaColor index 2 read GetColor write SetColor;
    { Colour of links. }
    property LinkColor: TAlphaColor index 3 read GetColor write SetColor;
    { Background of footnotes and other notes (blocks whose role is
      ewrNote: aside, epub:type / class footnote, endnote, note), so they
      can be told from the text; transparent (claNull) = not marked. }
    property NoteColor: TAlphaColor index 4 read GetColor write SetColor;
    { A strip at the bottom of the view with how far through the book it
      is (@link(Progress), as a percentage); the text scrolls above it. }
    property ShowProgress: Boolean read FShowProgress write SetShowProgress default False;
    { A word was clicked. }
    property OnWordClick: TEpubWordEvent read FOnWordClick write FOnWordClick;
    { Another document is shown. }
    property OnDocumentChange: TNotifyEvent read FOnDocumentChange write FOnDocumentChange;
    { Tab order (Align, Size, Visible, Enabled, ... are published by
      TSkCustomControl). }
    property TabOrder;
    { The view takes keyboard focus with Tab. }
    property TabStop;
  end;

implementation

const
  { The first-line indent is drawn as em spaces (U+2003) in front of the
    text: Skia's paragraph has no first-line indent of its own. }
  EM_SPACE = #$2003;
  { Default base font size, px. }
  DEFAULT_FONT_SIZE = 20;
  { Pictures are never taller than this part of the view. }
  IMAGE_MAX_VIEW = 0.85;
  { Wheel notches to lines. }
  WHEEL_LINES = 3;
  { One wheel notch. }
  WHEEL_DELTA = 120;

constructor TEpubView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DrawCacheKind := TSkDrawCacheKind.Never;   // the highlight changes often
  CanFocus := True;
  HitTest := True;
  FDocument := -1;
  FHighFirst := -1;
  FHighLast := -1;
  FLaidOutWidth := -1;
  FFontSize := DEFAULT_FONT_SIZE;
  FFontFamily := '';                 // '' = Skia's default sans serif
  FMonoFamily := 'monospace';
  FLineHeight := 1.4;
  FParagraphSpacing := 0.8;
  FPageMargin := 24;
  FTextColor := $FF222222;
  FBackgroundColor := $FFFBF7EF;     // warm paper
  FHighlightColor := $FFFFE08A;
  FLinkColor := $FF1A5FB4;
  FNoteColor := $FFEDE6D6;           // a shade darker than the paper
end;

destructor TEpubView.Destroy;
begin
  StopScrolling;
  FLayout.Free;
  inherited;
end;

procedure TEpubView.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FEpub) then
  begin
    FEpub := nil;
    Clear;
  end;
end;

procedure TEpubView.SetEpub(const AValue: TCustomEpub);
begin
  if FEpub = AValue then
    Exit;
  if FEpub <> nil then
    FEpub.RemoveFreeNotification(Self);
  FEpub := AValue;
  if FEpub <> nil then
    FEpub.FreeNotification(Self);
  Clear;
end;

function TEpubView.Book: TEpubBook;
begin
  if FEpub = nil then
    Result := nil
  else
    Result := FEpub.Book;
end;

function TEpubView.LayoutCurrent: Boolean;
begin
  Result := (FLayout <> nil) and (FEpub <> nil) and (FEpub.Book <> nil) and
    (FEpub.BookSerial = FLayoutSerial);
end;

function TEpubView.GetColor(const AIndex: Integer): TAlphaColor;
begin
  case AIndex of
    0: Result := FTextColor;
    1: Result := FBackgroundColor;
    2: Result := FHighlightColor;
    4: Result := FNoteColor;
  else
    Result := FLinkColor;
  end;
end;

procedure TEpubView.SetColor(const AIndex: Integer; const AValue: TAlphaColor);
begin
  case AIndex of
    0: FTextColor := AValue;
    1: FBackgroundColor := AValue;
    2: FHighlightColor := AValue;
    4: FNoteColor := AValue;
  else
    FLinkColor := AValue;
  end;
  if AIndex in [0, 3] then
    Relayout   // text colours are part of the paragraphs
  else
    Redraw;
end;

procedure TEpubView.SetFontSize(const AValue: Single);
begin
  if (AValue <= 0) or SameValue(AValue, FFontSize) then
    Exit;
  FFontSize := AValue;
  Relayout;
end;

procedure TEpubView.SetFontFamily(const AValue: string);
begin
  if AValue = FFontFamily then
    Exit;
  FFontFamily := AValue;
  Relayout;
end;

procedure TEpubView.SetLineHeight(const AValue: Single);
begin
  if (AValue <= 0) or SameValue(AValue, FLineHeight) then
    Exit;
  FLineHeight := AValue;
  Relayout;
end;

procedure TEpubView.Relayout;
begin
  FLaidOutWidth := -1;
  Redraw;
end;

procedure TEpubView.StopScrolling;
begin
  if FScrollTimer <> nil then
    FScrollTimer.Enabled := False;
end;

procedure TEpubView.SmoothScrollTo(ATarget: Single);
const
  { Ticks of the smooth scroll, ms. }
  TICK_MS = 15;
begin
  ATarget := Max(0, Min(ATarget, FContentHeight - TextHeight));
  if not Visible or (Abs(ATarget - FScroll) > TextHeight * 1.5) then
  begin
    ScrollPos := ATarget;
    Exit;
  end;
  FScrollTarget := ATarget;
  if FScrollTimer = nil then
  begin
    FScrollTimer := TTimer.Create(Self);
    FScrollTimer.Interval := TICK_MS;
    FScrollTimer.OnTimer := ScrollTimer;
  end;
  FScrollTimer.Enabled := True;
end;

procedure TEpubView.ScrollTimer(Sender: TObject);
const
  { Share of the way left that a tick moves (eases out). }
  EASE = 0.2;
var
  D: Single;
begin
  D := FScrollTarget - FScroll;
  if Abs(D) < 0.5 then
  begin
    FScroll := FScrollTarget;
    StopScrolling;
  end
  else
    FScroll := FScroll + D * EASE;
  Redraw;
end;

function TEpubView.WordLine(AWord: Integer; out ATop, AHeight: Single): Boolean;
var
  B: TEpubBook;
  Blk, K, I, Local, S: Integer;
  Boxes: TArray<TSkTextBox>;
  Block: TEpubBlock;
begin
  Result := False;
  ATop := 0;
  AHeight := 0;
  B := Book;
  if (B = nil) or not LayoutCurrent or (B.Words[AWord].Document <> FDocument) then
    Exit;
  Blk := B.BlockOfWord(FLayout, FDocument, AWord);
  if Blk < 0 then
    Exit;
  K := ItemOfBlock(Blk);
  if (K < 0) or (FItems[K].Paragraph = nil) then
    Exit;
  Block := FLayout.Blocks[Blk];
  Local := AWord - B.Documents[FDocument].FirstWord;
  for I := 0 to High(Block.Words) do
    if Block.Words[I].Word = Local then
    begin
      S := Block.Words[I].Start + FItems[K].Offset;
      Boxes := FItems[K].Paragraph.GetRectsForRange(S, S + Max(1, Block.Words[I].Length),
        TSkRectHeightStyle.Max, TSkRectWidthStyle.Tight);
      if Length(Boxes) = 0 then
        Exit;
      ATop := FItems[K].Top + Boxes[0].Rect.Top;
      AHeight := Boxes[0].Rect.Height;
      Exit(True);
    end;
end;

procedure TEpubView.SetScrollPos(const AValue: Single);
var
  V: Single;
begin
  // a scroll by the user (wheel, keys) or from code ends a smooth one
  StopScrolling;
  V := Min(AValue, FContentHeight - TextHeight);
  V := Max(V, 0);
  if SameValue(V, FScroll) then
    Exit;
  FScroll := V;
  Redraw;
end;

procedure TEpubView.Clear;
begin
  StopScrolling;
  FreeAndNil(FLayout);
  FItems := nil;
  FDocument := -1;
  FContentHeight := 0;
  FScroll := 0;
  FLaidOutWidth := -1;
  ClearHighlight;
end;

procedure TEpubView.ShowDocument(ADoc: Integer);
var
  B: TEpubBook;
begin
  B := Book;
  if (B = nil) or (ADoc < 0) or (ADoc > High(B.Documents)) then
  begin
    Clear;
    Exit;
  end;
  B.LoadText;   // word numbering of the book (highlights use it)
  // also when the document number is the same but the book is another one:
  // the layout kept was the first book's text
  if (ADoc <> FDocument) or not LayoutCurrent then
  begin
    FreeAndNil(FLayout);
    FItems := nil;
    FLayout := B.DocumentLayout(ADoc);
    FLayoutSerial := FEpub.BookSerial;
    FDocument := ADoc;
    FLaidOutWidth := -1;
    if Assigned(FOnDocumentChange) then
      FOnDocumentChange(Self);
  end;
  StopScrolling;
  FScroll := 0;
  Redraw;
end;

procedure TEpubView.ShowFragment(ADoc: Integer; const AId: string);
var
  I, K: Integer;
begin
  ShowDocument(ADoc);
  if not LayoutCurrent or (AId = '') then
    Exit;
  I := FLayout.IndexOfId(AId);
  if (I < 0) or (FLayout.Ids[I].Block < 0) then
    Exit;
  if FLaidOutWidth <> Width then
    LayoutItems(Width);
  K := ItemOfBlock(FLayout.Ids[I].Block);
  if K >= 0 then
    ScrollPos := FItems[K].Top - FPageMargin;
end;

procedure TEpubView.Highlight(AFirst, ALast: Integer);
begin
  if (AFirst = FHighFirst) and (ALast = FHighLast) then
    Exit;
  FHighFirst := AFirst;
  FHighLast := ALast;
  Redraw;
end;

procedure TEpubView.ClearHighlight;
begin
  Highlight(-1, -1);
end;

procedure TEpubView.ScrollToWord(AWord: Integer; ACenter: Boolean);
var
  B: TEpubBook;
  Doc, Blk, K: Integer;
  Top, Bottom, LineTop, LineHeight: Single;
begin
  B := Book;
  if (B = nil) or (AWord < 0) or (AWord >= B.WordCount) then
    Exit;
  Doc := B.Words[AWord].Document;
  if (Doc <> FDocument) or not LayoutCurrent then
    ShowDocument(Doc);
  Blk := B.BlockOfWord(FLayout, Doc, AWord);
  if Blk < 0 then
    Exit;
  if FLaidOutWidth <> Width then
    LayoutItems(Width);
  K := ItemOfBlock(Blk);
  if K < 0 then
    Exit;
  // reading along: the word's line in the middle, scrolled smoothly
  if ACenter then
  begin
    if WordLine(AWord, LineTop, LineHeight) then
      SmoothScrollTo(LineTop + LineHeight / 2 - TextHeight / 2)
    else
      SmoothScrollTo(FItems[K].Top + FItems[K].Height / 2 - TextHeight / 2);
    Exit;
  end;
  Top := FItems[K].Top;
  Bottom := Top + Min(FItems[K].Height, TextHeight / 2);
  // keep it in the upper two thirds; scroll only when it left that
  if (Top < FScroll) or (Bottom > FScroll + TextHeight * 2 / 3) then
    ScrollPos := Top - TextHeight / 4;
end;

procedure TEpubView.Page(ADown: Boolean);
var
  Step: Single;
begin
  Step := TextHeight - 2 * FFontSize * FLineHeight;
  if Step < FFontSize then
    Step := FFontSize;
  if ADown then
    ScrollPos := FScroll + Step
  else
    ScrollPos := FScroll - Step;
end;

function TEpubView.ItemOfBlock(ABlock: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FItems) do
    if FItems[I].Block = ABlock then
      Exit(I);
  Result := -1;
end;

function TEpubView.MakeParagraph(const ABlock: TEpubBlock; AWidth: Single; out AOffset: Integer): ISkParagraph;
var
  PS: ISkParagraphStyle;
  TS: ISkTextStyle;
  Builder: ISkParagraphBuilder;
  R, Indent: Integer;
  Run: TEpubRun;
  Weight: TSkFontWeight;
  Slant: TSkFontSlant;
  Deco: TSkTextDecorations;

  function NewStyle(ASize: Double): ISkTextStyle;
  begin
    Result := TSkTextStyle.Create;
    Result.Color := FTextColor;
    Result.FontSize := FFontSize * ASize;
    Result.HeightMultiplier := FLineHeight;
    if FFontFamily <> '' then
      Result.FontFamilies := [FFontFamily];
  end;

begin
  PS := TSkParagraphStyle.Create;
  case ABlock.Align of
    etaCenter: PS.TextAlign := TSkTextAlign.Center;
    etaEnd: PS.TextAlign := TSkTextAlign.Right;
    etaJustify: PS.TextAlign := TSkTextAlign.Justify;
  else
    PS.TextAlign := TSkTextAlign.Left;
  end;
  Builder := TSkParagraphBuilder.Create(PS);
  AOffset := 0;
  Indent := Round(ABlock.TextIndent);
  if (Indent > 0) and (ABlock.Kind = ebkParagraph) and (ABlock.Align <> etaCenter) then
  begin
    TS := NewStyle(1);
    Builder.PushStyle(TS);
    Builder.AddText(StringOfChar(EM_SPACE, Indent));
    Builder.Pop;
    AOffset := Indent;
  end;
  for R := 0 to High(ABlock.Runs) do
  begin
    Run := ABlock.Runs[R];
    TS := NewStyle(Run.Size);
    if ersBold in Run.Styles then
      Weight := TSkFontWeight.Bold
    else
      Weight := TSkFontWeight.Normal;
    if ersItalic in Run.Styles then
      Slant := TSkFontSlant.Italic
    else
      Slant := TSkFontSlant.Upright;
    TS.FontStyle := TSkFontStyle.Create(Weight, TSkFontWidth.Normal, Slant);
    Deco := [];
    if (ersUnderline in Run.Styles) or (ersLink in Run.Styles) then
      Include(Deco, TSkTextDecoration.Underline);
    if ersStrike in Run.Styles then
      Include(Deco, TSkTextDecoration.LineThrough);
    TS.Decorations := Deco;
    if ersLink in Run.Styles then
      TS.Color := FLinkColor;
    if (ersMono in Run.Styles) or (ABlock.Kind = ebkPreformatted) then
      TS.FontFamilies := [FMonoFamily];
    Builder.PushStyle(TS);
    Builder.AddText(Copy(ABlock.Text, Run.Start + 1, Run.Length));
    Builder.Pop;
  end;
  Result := Builder.Build;
  Result.Layout(AWidth);
end;

procedure TEpubView.LayoutItems(AWidth: Single);
var
  B: TEpubBook;
  I, N, Off: Integer;
  Blk: TEpubBlock;
  Y, X, W, Scale, MaxH: Single;
  Item: TEpubViewItem;
  Bytes: TBytes;
begin
  FItems := nil;
  FLaidOutWidth := AWidth;
  FContentHeight := 0;
  B := Book;
  if (B = nil) or (FLayout = nil) or (AWidth <= 2 * FPageMargin) then
    Exit;
  SetLength(FItems, FLayout.BlockCount);
  N := 0;
  Y := FPageMargin;
  MaxH := Max(Height * IMAGE_MAX_VIEW, FFontSize * 4);
  for I := 0 to FLayout.BlockCount - 1 do
  begin
    Blk := FLayout.Blocks[I];
    Item := Default(TEpubViewItem);
    Item.Block := I;
    X := FPageMargin + Blk.MarginLeft * FFontSize;
    W := AWidth - X - FPageMargin;
    if W < FFontSize * 4 then
    begin
      X := FPageMargin;
      W := AWidth - 2 * FPageMargin;
    end;
    if Blk.Kind = ebkHeading then
      Y := Y + FFontSize * FParagraphSpacing;   // room above a heading
    // a chapter break (an audiobook's chapter): a rule in a gap above
    if (Y > FPageMargin) and BreakBefore(I) then
    begin
      Item.RuleY := Y + FFontSize * FLineHeight;
      Y := Y + 2 * FFontSize * FLineHeight;
    end;
    Item.X := X;
    Item.Top := Y;
    Item.Width := W;
    case Blk.Kind of
      ebkImage:
        begin
          Item.Image := nil;
          try
            if B.Zip.Exists(Blk.ImagePath) then
            begin
              Bytes := B.ReadResource(Blk.ImagePath);
              Item.Image := TSkImage.MakeFromEncoded(Bytes);   // nil for SVG etc.
            end;
          except
            // a damaged or unreadable entry (CRC, ZIP method, too large):
            // no picture, and the rest of the document is still laid out.
            // Raised from here it left Draw with the items half made.
            on E: Exception do
              Item.Image := nil;
          end;
          if Item.Image <> nil then
          begin
            Scale := Min(W / Item.Image.Width, MaxH / Item.Image.Height);
            Scale := Min(Scale, 2);
            Item.Width := Item.Image.Width * Scale;
            Item.Height := Item.Image.Height * Scale;
            Item.X := X + (W - Item.Width) / 2;
          end
          else
            Item.Height := 0;
        end;
      ebkRule:
        Item.Height := FFontSize;
    else
      Item.Paragraph := MakeParagraph(Blk, W, Off);
      Item.Offset := Off;
      Item.Height := Item.Paragraph.Height;
    end;
    if Item.Height > 0 then
    begin
      FItems[N] := Item;
      Inc(N);
      Y := Y + Item.Height;
      if (Blk.TextIndent > 0) and (Blk.Kind = ebkParagraph) then
        Y := Y + FFontSize * FParagraphSpacing / 3
      else
        Y := Y + FFontSize * FParagraphSpacing;
    end;
  end;
  SetLength(FItems, N);
  FContentHeight := Y + FPageMargin;
end;

procedure TEpubView.Resize;
begin
  inherited;
  if not SameValue(FLaidOutWidth, Width) then
    FLaidOutWidth := -1;
end;

procedure TEpubView.Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single);
var
  Paint: ISkPaint;
  I, K, Local, F, L, S, E, CoreFirst: Integer;
  Item: TEpubViewItem;
  Top, Y: Single;
  Blk: TEpubBlock;
  Boxes: TArray<TSkTextBox>;
  B: TEpubBook;
  R, TextRect: TRectF;
begin
  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;
  Paint.Style := TSkPaintStyle.Fill;
  Paint.Color := FBackgroundColor;
  ACanvas.DrawRect(ADest, Paint);
  B := Book;
  if (B = nil) or not LayoutCurrent then
    Exit;   // no book, or a layout of the book before: an empty page
  // the text above the progress strip
  TextRect := ADest;
  TextRect.Bottom := ADest.Bottom - FooterHeight;
  if not SameValue(FLaidOutWidth, ADest.Width) then
  begin
    LayoutItems(ADest.Width);
    FScroll := Max(0, Min(FScroll, FContentHeight - TextRect.Height));
  end;
  if FShowProgress then
    DrawFooter(ACanvas, RectF(ADest.Left, TextRect.Bottom, ADest.Right, ADest.Bottom));
  ACanvas.Save;
  try
    ACanvas.ClipRect(TextRect);
    for I := 0 to High(FItems) do
    begin
      Item := FItems[I];
      Top := ADest.Top + Item.Top - FScroll;
      if Top > TextRect.Bottom then
        Break;
      if Top + Item.Height < ADest.Top then
        Continue;
      Blk := FLayout.Blocks[Item.Block];
      // a chapter break above the block: a short centred rule
      if Item.RuleY > 0 then
      begin
        Paint.Color := (FTextColor and $00FFFFFF) or $70000000;
        Paint.Style := TSkPaintStyle.Stroke;
        Paint.StrokeWidth := 1;
        Y := ADest.Top + Item.RuleY - FScroll;
        R.Left := ADest.Left + ADest.Width / 2 - Min(ADest.Width * 0.15, FFontSize * 6);
        R.Right := ADest.Left + ADest.Width / 2 + Min(ADest.Width * 0.15, FFontSize * 6);
        ACanvas.DrawLine(PointF(R.Left, Y), PointF(R.Right, Y), Paint);
        Paint.Style := TSkPaintStyle.Fill;
      end;
      // a note (footnote, endnote, aside - marked so, or the target of a
      // footnote marker's link: the book's word roles): its own background
      if (TAlphaColorRec(FNoteColor).A > 0) and ((Blk.Role = ewrNote) or ((Length(Blk.Words) > 0) and
        (B.Words[Blk.Words[0].Word + B.Documents[FDocument].FirstWord].Role = ewrNote))) then
      begin
        Paint.Style := TSkPaintStyle.Fill;
        Paint.Color := FNoteColor;
        ACanvas.DrawRect(RectF(ADest.Left + Item.X - FPageMargin / 2, Top - 2,
          ADest.Left + Item.X + Item.Width + FPageMargin / 2, Top + Item.Height + 2), Paint);
      end;
      if Item.Paragraph <> nil then
      begin
        // the highlight, behind the text
        if (FHighFirst >= 0) and (Length(Blk.Words) > 0) then
        begin
          F := -1;
          L := -1;
          for K := 0 to High(Blk.Words) do
          begin
            Local := Blk.Words[K].Word + B.Documents[FDocument].FirstWord;
            if (Local >= FHighFirst) and (Local <= FHighLast) then
            begin
              if F < 0 then
                F := K;
              L := K;
            end;
          end;
          if F >= 0 then
          begin
            // without the punctuation around the words: 'whales' is read,
            // the comma after it is not
            S := Blk.Words[F].Start + 1;
            E := Blk.Words[F].Start + Blk.Words[F].Length;
            EpubWordCore(Blk.Text, S, E);
            S := S - 1 + Item.Offset;
            CoreFirst := Blk.Words[L].Start + 1;
            E := Blk.Words[L].Start + Blk.Words[L].Length;
            EpubWordCore(Blk.Text, CoreFirst, E);
            E := E + Item.Offset;
            Boxes := Item.Paragraph.GetRectsForRange(S, E, TSkRectHeightStyle.Max, TSkRectWidthStyle.Tight);
            Paint.Color := FHighlightColor;
            for K := 0 to High(Boxes) do
            begin
              R := Boxes[K].Rect;
              R.Offset(ADest.Left + Item.X, Top);
              R.Inflate(2, 0);
              ACanvas.DrawRect(R, Paint);
            end;
          end;
        end;
        Item.Paragraph.Paint(ACanvas, ADest.Left + Item.X, Top);
      end
      else if Item.Image <> nil then
        ACanvas.DrawImageRect(Item.Image, RectF(ADest.Left + Item.X, Top, ADest.Left + Item.X + Item.Width,
          Top + Item.Height), TSkSamplingOptions.High)
      else if Blk.Kind = ebkRule then
      begin
        Paint.Color := FTextColor;
        Paint.Style := TSkPaintStyle.Stroke;
        Paint.StrokeWidth := 1;
        Y := Top + Item.Height / 2;
        ACanvas.DrawLine(PointF(ADest.Left + Item.X + Item.Width / 4, Y),
          PointF(ADest.Left + Item.X + Item.Width * 3 / 4, Y), Paint);
        Paint.Style := TSkPaintStyle.Fill;
      end;
    end;
  finally
    ACanvas.Restore;
  end;
end;

procedure TEpubView.SetChapterBreaks(const AValue: TArray<Integer>);
begin
  FChapterBreaks := Copy(AValue);
  Relayout;
end;

function TEpubView.BreakBefore(ABlock: Integer): Boolean;
var
  B: TEpubBook;
  W, I: Integer;
  Blk: TEpubBlock;
begin
  Result := False;
  B := Book;
  if (B = nil) or (Length(FChapterBreaks) = 0) or (FLayout = nil) then
    Exit;
  Blk := FLayout.Blocks[ABlock];
  if Length(Blk.Words) = 0 then
    Exit;
  W := Blk.Words[0].Word + B.Documents[FDocument].FirstWord;
  for I := 0 to High(FChapterBreaks) do
    if FChapterBreaks[I] = W then
      Exit(True);
end;

function TEpubView.FooterHeight: Single;
begin
  if FShowProgress then
    Result := Round(Max(11, FFontSize * 0.65) * 2)
  else
    Result := 0;
end;

function TEpubView.TextHeight: Single;
begin
  Result := Max(1, Height - FooterHeight);
end;

procedure TEpubView.SetShowProgress(const AValue: Boolean);
begin
  if AValue = FShowProgress then
    Exit;
  FShowProgress := AValue;
  FScroll := Max(0, Min(FScroll, FContentHeight - TextHeight));
  Redraw;
end;

function TEpubView.Progress: Single;
var
  B: TEpubBook;
  Doc: TEpubDocument;
  Share: Single;
  Total: Integer;
begin
  Result := -1;
  B := Book;
  if (B = nil) or not LayoutCurrent or (FDocument < 0) or (FDocument > High(B.Documents)) then
    Exit;
  Total := B.WordCount;
  if Total = 0 then
    Exit;
  Doc := B.Documents[FDocument];
  // the share of the document above the top of the view; at its end, all
  if (FContentHeight <= TextHeight) or (FScroll >= FContentHeight - TextHeight - 1) then
    Share := 1
  else
    Share := FScroll / FContentHeight;
  Result := Min(1, (Doc.FirstWord + Share * Doc.WordCount) / Total);
  // the first words of the book: 0, not a fraction of a percent above
  if (Doc.FirstWord = 0) and (FScroll < 1) and (FContentHeight > TextHeight) then
    Result := 0;
end;

procedure TEpubView.DrawFooter(const ACanvas: ISkCanvas; const ARect: TRectF);
var
  P: Single;
  PS: ISkParagraphStyle;
  TS: ISkTextStyle;
  Builder: ISkParagraphBuilder;
  Para: ISkParagraph;
  Paint: ISkPaint;
begin
  P := Progress;
  if P < 0 then
    Exit;
  // a hairline between the text and the strip
  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;
  Paint.Style := TSkPaintStyle.Stroke;
  Paint.StrokeWidth := 1;
  Paint.Color := (FTextColor and $00FFFFFF) or $30000000;
  ACanvas.DrawLine(PointF(ARect.Left + FPageMargin, ARect.Top + 0.5), PointF(ARect.Right - FPageMargin,
    ARect.Top + 0.5), Paint);
  // the percentage, centred, in the text colour made fainter
  PS := TSkParagraphStyle.Create;
  PS.TextAlign := TSkTextAlign.Center;
  Builder := TSkParagraphBuilder.Create(PS);
  TS := TSkTextStyle.Create;
  TS.Color := (FTextColor and $00FFFFFF) or $A0000000;
  TS.FontSize := Max(11, FFontSize * 0.65);
  if FFontFamily <> '' then
    TS.FontFamilies := [FFontFamily];
  Builder.PushStyle(TS);
  Builder.AddText(Format('%d%%', [Trunc(P * 100)]));
  Builder.Pop;
  Para := Builder.Build;
  Para.Layout(ARect.Width);
  Para.Paint(ACanvas, ARect.Left, ARect.Top + (ARect.Height - Para.Height) / 2);
end;

function TEpubView.WordAt(X, Y: Single): Integer;
var
  I, K, P: Integer;
  Item: TEpubViewItem;
  DocY: Single;
  Blk: TEpubBlock;
  B: TEpubBook;
begin
  Result := -1;
  B := Book;
  if (B = nil) or not LayoutCurrent then
    Exit;
  // the progress strip has no words (the text under it is hidden)
  if Y > TextHeight then
    Exit;
  DocY := Y + FScroll;
  for I := 0 to High(FItems) do
  begin
    Item := FItems[I];
    if (DocY < Item.Top) or (DocY > Item.Top + Item.Height) or (Item.Paragraph = nil) then
      Continue;
    P := Item.Paragraph.GetGlyphPositionAtCoordinate(X - Item.X, DocY - Item.Top).Position - Item.Offset;
    Blk := FLayout.Blocks[Item.Block];
    for K := 0 to High(Blk.Words) do
      if (P >= Blk.Words[K].Start) and (P <= Blk.Words[K].Start + Blk.Words[K].Length) then
        Exit(Blk.Words[K].Word + B.Documents[FDocument].FirstWord);
    Exit;
  end;
end;

procedure TEpubView.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  inherited;
  if Handled then
    Exit;
  ScrollPos := FScroll - WheelDelta / WHEEL_DELTA * WHEEL_LINES * FFontSize * FLineHeight;
  Handled := True;
end;

procedure TEpubView.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  case Key of
    vkDown:
      ScrollPos := FScroll + FFontSize * FLineHeight;
    vkUp:
      ScrollPos := FScroll - FFontSize * FLineHeight;
    vkNext:
      Page(True);
    vkPrior:
      Page(False);
    vkHome:
      ScrollPos := 0;
    vkEnd:
      ScrollPos := FContentHeight;
  else
    if KeyChar = ' ' then
      Page(not (ssShift in Shift))
    else
    begin
      inherited;
      Exit;
    end;
  end;
  Key := 0;
  KeyChar := #0;
end;

procedure TEpubView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  W: Integer;
begin
  inherited;
  if (Button <> TMouseButton.mbLeft) or not Assigned(FOnWordClick) then
    Exit;
  W := WordAt(X, Y);
  if W >= 0 then
    FOnWordClick(Self, W);
end;

end.
