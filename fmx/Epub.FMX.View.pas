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
  { The page was scrolled on past an end of its document (zip 339): past
    the end when AForward, past the start otherwise. The handler shows
    the next or the previous document, or nothing. }
  TEpubEdgeEvent = procedure(Sender: TObject; AForward: Boolean) of object;

  { One block of the shown document, laid out or (until it comes near the
    view) estimated. }
  TEpubViewItem = record
    { The block (index into the layout's Blocks; the same as the item's
      own index). }
    Block: Integer;
    { Its paragraph (nil for a picture or a rule, and until it is laid
      out). }
    Paragraph: ISkParagraph;
    { Its picture (nil when none or unreadable, and until it is laid
      out). }
    Image: ISkImage;
    { Characters put in front of the block's text (the first-line indent). }
    Offset: Integer;
    { Left edge, px from the view's left. }
    X: Single;
    { Top, px from the document's top. }
    Top: Single;
    { Width, px. }
    Width: Single;
    { Height, px: the real one when @link(Measured), an estimate before
      (0 = not shown: an unreadable picture). }
    Height: Single;
    { A chapter break is drawn above it: the rule's middle, px from the
      document's top (0 = none). }
    RuleY: Single;
    { Laid out: Paragraph or Image made and Height real (zip 337 - before,
      every block of a document was laid out before its first page). }
    Measured: Boolean;
    { Its estimated height, px, before the view's correction (see
      TEpubView.GuessScale); unused once Measured. }
    Guess: Single;
    { Room above it, px (a heading's). }
    SpaceAbove: Single;
    { Room below it, px (left out when its height is 0). }
    SpaceBelow: Single;
    { An audiobook's chapter starts at it (ChapterBreaks): a rule above it,
      except at the very top. }
    BreakAbove: Boolean;
  end;
  { The blocks of the shown document, one item per block. }
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
    { The document's blocks, laid out near the view, estimated elsewhere. }
    FItems: TEpubViewItemArray;
    { Width the items were laid out for (-1 = lay out again). }
    FLaidOutWidth: Single;
    { Items laid out since the last LayoutItems. }
    FMeasuredCount: Integer;
    { The estimates and the real heights of the paragraphs laid out so far
      (they correct the estimates of the rest: GuessScale). }
    FMeasuredGuess, FMeasuredReal: Double;
    { The tallest a picture is drawn, px (fixed when the items are made). }
    FImageMax: Single;
    { Height of the whole document, px. }
    FContentHeight: Single;
    { Backing field of @link(ScrollPos). }
    FScroll: Single;
    { Where a smooth scroll is going (@link(ScrollToWord) with ACenter). }
    FScrollTarget: Single;
    { Backing field of @link(DragScroll). }
    FDragScroll: Boolean;
    { The document on show came from @link(ShowPreview): the book's words
      are not numbered (and must not be asked for - that reads the whole
      book). }
    FPreview: Boolean;
    { The button (or a finger) is down on the view. }
    FPressed: Boolean;
    { It has moved far enough since to be a drag: the page follows it, and
      letting go is no click on a word. }
    FDragging: Boolean;
    { Where it went down (Y). }
    FPressY: Single;
    { Where the drag was at its last move (Y): each move scrolls by the
      difference (ScrollBy - so a drag can go on past an end). }
    FDragY: Single;
    { The drag's speed, px a second (+ down the document), smoothed over its
      last moves (zip 352). }
    FDragSpeed: Single;
    { When the drag last moved (TThread.GetTickCount64). }
    FDragTick: UInt64;
    { The glide after a quick drag (nil until the first): FFlingSpeed px a
      second, slowing (owner 15:53: "swipe up fast and more text will go
      by than swiping slower"). }
    FFlingTimer: TTimer;
    { The glide's speed, px a second (0 = none). }
    FFlingSpeed: Single;
    { The glide's last tick (TThread.GetTickCount64). }
    FFlingTick: UInt64;
    { The press that stopped a glide: its letting go is no click on a
      word. }
    FPressStoppedFling: Boolean;
    { Backing field of @link(Fling). }
    FFling: Boolean;
    { How far the user has scrolled on past an end, px (+ the end, - the
      start; 0 = not at one): at EDGE_PULL_LINES lines, OnEdge. }
    FOverscroll: Single;
    { Moves FScroll towards FScrollTarget a step per tick (nil until the
      first smooth scroll). }
    FScrollTimer: TTimer;
    { Backing field of @link(FontSize). }
    FFontSize: Single;
    { Backing field of @link(FontFamily). }
    FFontFamily: string;
    { Backing field of @link(MonoFamily). }
    FMonoFamily: string;
    { The text and mono typefaces, found once and registered under the
      view's own family names (see @link(Fonts)). }
    FFonts: ISkTypefaceFontProvider;
    { FontFamily + #1 + MonoFamily that FFonts was made for. }
    FFontsFor: string;
    { Backing field of @link(LineHeight). }
    FLineHeight: Single;
    { Backing field of @link(Justify). }
    FJustify: Boolean;
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
    { The second highlight, under the first (a phrase or a sentence, the
      word over it; zip 352): its first and last word, -1 = none. }
    FUnitFirst, FUnitLast: Integer;
    { Backing field of @link(UnitHighlightColor). }
    FUnitColor: TAlphaColor;
    { Backing field of @link(OnWordClick). }
    FOnWordClick: TEpubWordEvent;
    { Backing field of @link(OnDocumentChange). }
    FOnDocumentChange: TNotifyEvent;
    { Backing field of @link(OnEdge). }
    FOnEdge: TEpubEdgeEvent;
    { Links to a book component. }
    procedure SetEpub(const AValue: TCustomEpub);
    { Font size; lays out again. }
    procedure SetFontSize(const AValue: Single);
    { Font family; lays out again. }
    procedure SetFontFamily(const AValue: string);
    { Line height; lays out again. }
    procedure SetLineHeight(const AValue: Single);
    { Justified paragraphs on / off; lays out again. }
    procedure SetJustify(const AValue: Boolean);
    { Scroll position (clamped). }
    procedure SetScrollPos(const AValue: Single);
    { Stops a smooth scroll where it is. }
    procedure StopScrolling;
    { Ends a glide (FlingTimer). }
    procedure StopFling;
    { A glide's tick: on by its speed, slower each time; it stops at the
      document's ends (going on into the next document stays a pull of
      the finger: ScrollBy). }
    procedure FlingTimer(Sender: TObject);
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
    { Makes the items for AWidth px - every block ESTIMATED, none laid out
      (that happens near the view: MeasureView, PlaceBlock). A document
      laid out before at another width or font keeps the block at the top
      of the view there. }
    procedure LayoutItems(AWidth: Single);
    { The estimated height of a text block, px, before GuessScale: its
      characters at half an em each, in lines of its size. }
    function GuessHeight(const ABlock: TEpubBlock; AWidth: Single): Single;
    { The real height of the paragraphs laid out over their estimates
      (1 until one is; kept between 0.25 and 4). }
    function GuessScale: Single;
    { Every item's top from the heights (real or estimated), and
      FContentHeight. }
    procedure PlaceItems;
    { Lays item AIndex out: its paragraph or picture, its real height. }
    procedure MeasureItem(AIndex: Integer);
    { Lays out every item not laid out yet between ATop and ABottom (px
      from the document's top), then places the items again so that what
      is at the top of the view stays there (the scroll position, a smooth
      scroll's target moves with it (a drag goes by its moves); a view at the
      document's end stays at the end).
      @returns(True when one was laid out - the tops changed, so call
      again until False) }
    function MeasureSpan(ATop, ABottom: Single): Boolean;
    { Lays out what is in the view, half a view above it and half below. }
    procedure MeasureView;
    { Lays out block ABlock and a view and a half above and below it (so a
      smooth scroll to it from the view ends where it should).
      @returns(its item, -1 when there is none or it has no height) }
    function PlaceBlock(ABlock: Integer): Integer;
    { The first item that ends at AY or below it (px from the document's
      top; the last item when none does), -1 when there are none. }
    function ItemAtY(AY: Single): Integer;
    { The typefaces the paragraphs use: FontFamily (regular, bold, italic,
      bold italic) and MonoFamily, each looked up ONCE and registered with
      a font provider under the view's own family names. Without it every
      paragraph asked the system's font manager again: on Linux each
      fontconfig family match sorts every installed font's names, and a
      chapter of a few thousand paragraphs took minutes - the reader
      stopped responding (owner, Night Watch, 2026-11-16). Made again when
      FontFamily or MonoFamily changes.
      @returns(the provider) }
    function Fonts: ISkTypefaceFontProvider;
    { A paragraph style whose default text style uses the view's own
      families (so nothing in a paragraph asks the system by name).
      @param(AAlign  the text alignment)
      @returns(the style) }
    function NewParagraphStyle(AAlign: TSkTextAlign): ISkParagraphStyle;
    { The Skia paragraph of block ABlock, AWidth px wide. }
    function MakeParagraph(const ABlock: TEpubBlock; AWidth: Single; out AOffset: Integer): ISkParagraph;
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
    { Remembers where a drag would start (@link(DragScroll)). }
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    { A drag: the page follows the finger or the mouse. }
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    { The pointer left with the button down: no drag goes on. }
    procedure DoMouseLeave; override;
    { A click on a word raises OnWordClick - not when letting go ends a
      drag. }
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    { Forgets a freed book component. }
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    { A view with reading defaults. }
    constructor Create(AOwner: TComponent); override;
    { Frees the layout. }
    destructor Destroy; override;
    { Shows document ADoc (index into the book's Documents) from the top,
      or with AAtEnd from its end (scrolling back into it from the next:
      zip 339). }
    procedure ShowDocument(ADoc: Integer; AAtEnd: Boolean = False);
    { Shows document ADoc of a book whose text has NOT been read
      (TEpubBook.CreateHeader) - that one document is parsed and laid out,
      nothing else of the book: a page on the screen at once while the
      whole book is read elsewhere (zip 332). ALocalWord: a word of the
      document (0 = its first) to have in the middle of the view; -1 = the
      top. A picture to look at: no highlight, no clicks on words, no
      progress strip, and notes only where the document itself marks
      them. @link(ShowDocument) or @link(Clear) ends it. }
    procedure ShowPreview(ADoc, ALocalWord: Integer);
    { Shows document ADoc at the element with id AId ('' = the top). }
    procedure ShowFragment(ADoc: Integer; const AId: string);
    { Highlights words AFirst..ALast (indexes into the book's Words); -1 =
      none. Does not scroll (see @link(ScrollToWord)). }
    procedure Highlight(AFirst, ALast: Integer);
    { A second highlight, words AFirst..ALast (book indexes; -1 = none), in
      @link(UnitHighlightColor), drawn under @link(Highlight)'s: the
      phrase or sentence being read, the word over it (zip 352). }
    procedure HighlightUnit(AFirst, ALast: Integer);
    { Removes both highlights. }
    procedure ClearHighlight;
    { Shows word AWord (switching document when needed). ACenter = @false:
      scrolls only when it is not already well inside the view. ACenter =
      @true (reading along): scrolls smoothly so the word's LINE is in the
      middle of the view - each new line moves the text up by a line -
      except where the document's start or end does not allow it. }
    procedure ScrollToWord(AWord: Integer; ACenter: Boolean = False);
    { The word at a point of the view (book index), -1 when none. }
    function WordAt(X, Y: Single): Integer;
    { Scrolls one screen down (True) or up - on past an end of the
      document as ScrollBy does. }
    procedure Page(ADown: Boolean);
    { Scrolls by ADelta px (+ down) as the user does - the wheel, keys,
      Page, a drag, a pad: at an end of the document, going on past it by
      EDGE_PULL_LINES lines in all calls OnEdge (the next or the previous
      document). ScrollPos stops at the ends. }
    procedure ScrollBy(ADelta: Single);
    { Clears the view (no document). }
    procedure Clear;
    { The shown document, -1 when none. }
    property Document: Integer read FDocument;
    { The shown document's layout (nil when none). }
    property Layout: TEpubDocLayout read FLayout;
    { Scroll position, px from the top. }
    property ScrollPos: Single read FScroll write SetScrollPos;
    { Dragging the page up or down scrolls it - a finger on a phone, the
      left button elsewhere (default True; zip 327). A press and release
      in one place is still a click on a word. The page stops with the
      finger: there is no gliding on. Pulled on past an end of the
      document, it goes into the next or the previous one (OnEdge). }
    property DragScroll: Boolean read FDragScroll write FDragScroll;
    { A quick drag glides on when the finger lets go, slowing to a stop -
      the faster the drag, the farther (default True; zip 352). It stops
      at the document's ends, at a press, and when the page is moved by
      the program (reading along). }
    property Fling: Boolean read FFling write FFling;
    { Height of the whole document, px - ESTIMATED for the parts not laid
      out yet (zip 337), so it changes as the document is read. }
    property ContentHeight: Single read FContentHeight;
    { Blocks of the shown document laid out so far (the rest are
      estimates), for the log. }
    property LaidOutBlocks: Integer read FMeasuredCount;
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
    { Paragraphs and list items the book leaves at the start (left, or not
      set) are justified - both edges straight, the last line of each as
      it is (owner, 2026-11-18: "It'll look nicer on-screen"). What the
      book centres, sets right or justifies itself stays as it is;
      headings, preformatted text and table cells are not touched. }
    property Justify: Boolean read FJustify write SetJustify default True;
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
    { The second highlight's colour (@link(HighlightUnit)): paler than
      @link(HighlightColor), so the word over it stands out. }
    property UnitHighlightColor: TAlphaColor index 5 read GetColor write SetColor;
    { A strip at the bottom of the view with how far through the book it
      is (@link(Progress), as a percentage); the text scrolls above it. }
    property ShowProgress: Boolean read FShowProgress write SetShowProgress default False;
    { A word was clicked. }
    property OnWordClick: TEpubWordEvent read FOnWordClick write FOnWordClick;
    { Another document is shown. }
    property OnDocumentChange: TNotifyEvent read FOnDocumentChange write FOnDocumentChange;
    { The user scrolled on past an end of the document (ScrollBy): show
      the next or the previous one. Without a handler the page stops at
      the ends (before zip 339 it always did - the next document came only
      with the sound). }
    property OnEdge: TEpubEdgeEvent read FOnEdge write FOnEdge;
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
  { The family name the view registers its text typefaces under. }
  TEXT_FAMILY = 'EpubView Text';
  { The family name the view registers its monospaced typefaces under. }
  MONO_FAMILY = 'EpubView Mono';
  { Pictures are never taller than this part of the view. }
  IMAGE_MAX_VIEW = 0.85;
  { A picture's estimated height before it is read, as a share of the
    column's width. }
  IMAGE_GUESS = 0.6;
  { The average character's width, em (the estimates; corrected by the
    paragraphs laid out). }
  CHAR_EM = 0.5;
  { At most this many rounds of laying out for one place (each can move
    the tops; two are usual). }
  MEASURE_PASSES = 8;
  { Wheel notches to lines. }
  WHEEL_LINES = 3;
  { Lines scrolled on past an end of a document before OnEdge (a pull a
    page or wheel step makes at once, a line key in two presses, a drag in
    a line and a half). }
  EDGE_PULL_LINES = 1.5;
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
  FUnitFirst := -1;
  FUnitLast := -1;
  // a pale blue: the yellow word stands out on it
  FUnitColor := $FFDCE8F7;
  FLaidOutWidth := -1;
  FFontSize := DEFAULT_FONT_SIZE;
  FFontFamily := '';                 // '' = Skia's default sans serif
  FMonoFamily := 'monospace';
  FLineHeight := 1.4;
  FJustify := True;
  FParagraphSpacing := 0.8;
  FPageMargin := 24;
  FTextColor := $FF222222;
  FBackgroundColor := $FFFBF7EF;     // warm paper
  FHighlightColor := $FFFFE08A;
  FLinkColor := $FF1A5FB4;
  FNoteColor := $FFEDE6D6;           // a shade darker than the paper
  FDragScroll := True;
  FFling := True;
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
    5: Result := FUnitColor;
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
    5: FUnitColor := AValue;
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

procedure TEpubView.SetJustify(const AValue: Boolean);
begin
  if AValue = FJustify then
    Exit;
  FJustify := AValue;
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
  // the program moves the page: a glide gives way
  StopFling;
end;

procedure TEpubView.StopFling;
begin
  FFlingSpeed := 0;
  if FFlingTimer <> nil then
    FFlingTimer.Enabled := False;
end;

procedure TEpubView.FlingTimer(Sender: TObject);
const
  { The speed lost: e^(-FRICTION x seconds) of it is left (3 = a third of
    a second to fall to a third; a 3000 px/s flick goes about a page). }
  FRICTION = 3.0;
  { Slower than this, px a second: stopped. }
  STOP_SPEED = 40;
var
  Now_: UInt64;
  Dt, Limit, Was: Single;
begin
  Now_ := TThread.GetTickCount64;
  Dt := (Now_ - FFlingTick) / 1000;
  FFlingTick := Now_;
  if Dt <= 0 then
    Exit;
  if Dt > 0.1 then
    Dt := 0.1;
  Limit := Max(0, FContentHeight - TextHeight);
  Was := FScroll;
  FScroll := Max(0, Min(FScroll + FFlingSpeed * Dt, Limit));
  FFlingSpeed := FFlingSpeed * Exp(-FRICTION * Dt);
  // an end reached, or slow enough: done
  if SameValue(FScroll, Was) or (Abs(FFlingSpeed) < STOP_SPEED) then
    StopFling;
  Redraw;
end;

procedure TEpubView.SmoothScrollTo(ATarget: Single);
const
  { Ticks of the smooth scroll, ms. }
  TICK_MS = 15;
begin
  // the program moves the page (reading along): a glide gives way
  StopFling;
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
  K := PlaceBlock(Blk);
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

procedure TEpubView.ShowPreview(ADoc, ALocalWord: Integer);
var
  B: TEpubBook;
  Blk, I, K, S: Integer;
  Block: TEpubBlock;
  Boxes: TArray<TSkTextBox>;
  Middle: Single;
begin
  B := Book;
  if (B = nil) or (ADoc < 0) or (ADoc > High(B.Documents)) then
  begin
    Clear;
    Exit;
  end;
  StopScrolling;
  ClearHighlight;
  FreeAndNil(FLayout);
  FItems := nil;
  FPreview := True;
  FLayout := B.DocumentLayout(ADoc);
  FLayoutSerial := FEpub.BookSerial;
  FDocument := ADoc;
  FLaidOutWidth := -1;
  FScroll := 0;
  if ALocalWord >= 0 then
  begin
    LayoutItems(Width);
    for Blk := 0 to FLayout.BlockCount - 1 do
    begin
      Block := FLayout.Blocks[Blk];
      for I := 0 to High(Block.Words) do
        if Block.Words[I].Word = ALocalWord then
        begin
          K := PlaceBlock(Blk);
          if K >= 0 then
          begin
            // the word's line in the middle, as ScrollToWord centres it
            Middle := FItems[K].Top + FItems[K].Height / 2;
            if FItems[K].Paragraph <> nil then
            begin
              S := Block.Words[I].Start + FItems[K].Offset;
              Boxes := FItems[K].Paragraph.GetRectsForRange(S, S + Max(1, Block.Words[I].Length),
                TSkRectHeightStyle.Max, TSkRectWidthStyle.Tight);
              if Length(Boxes) > 0 then
                Middle := FItems[K].Top + Boxes[0].Rect.Top + Boxes[0].Rect.Height / 2;
            end;
            FScroll := Max(0, Min(Middle - TextHeight / 2, FContentHeight - TextHeight));
          end;
          Redraw;
          Exit;
        end;
    end;
  end;
  Redraw;
end;

procedure TEpubView.Clear;
begin
  FPreview := False;
  StopScrolling;
  FreeAndNil(FLayout);
  FItems := nil;
  FDocument := -1;
  FContentHeight := 0;
  FScroll := 0;
  FLaidOutWidth := -1;
  ClearHighlight;
end;

procedure TEpubView.ShowDocument(ADoc: Integer; AAtEnd: Boolean);
var
  B: TEpubBook;
begin
  B := Book;
  if (B = nil) or (ADoc < 0) or (ADoc > High(B.Documents)) then
  begin
    Clear;
    Exit;
  end;
  FPreview := False;
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
  FOverscroll := 0;
  if AAtEnd and (Width > 2 * FPageMargin) then
  begin
    // its end: the items made now (estimated - the end is laid out when
    // it is drawn, and a view at the end stays there: MeasureSpan)
    if not SameValue(FLaidOutWidth, Width) then
      LayoutItems(Width);
    FScroll := Max(0, FContentHeight - TextHeight);
  end;
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
  K := PlaceBlock(FLayout.Ids[I].Block);
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

procedure TEpubView.HighlightUnit(AFirst, ALast: Integer);
begin
  if (AFirst = FUnitFirst) and (ALast = FUnitLast) then
    Exit;
  FUnitFirst := AFirst;
  FUnitLast := ALast;
  Redraw;
end;

procedure TEpubView.ClearHighlight;
begin
  HighlightUnit(-1, -1);
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
  // laid out with the view and a half round it: the word's top is real,
  // and so is the way to it from the view for a smooth scroll
  K := PlaceBlock(Blk);
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
    ScrollBy(Step)
  else
    ScrollBy(-Step);
end;

procedure TEpubView.ScrollBy(ADelta: Single);
var
  Target, Limit, Excess: Single;
begin
  // not laid out yet (a document just shown, before its first paint):
  // its height is not known, so no end to go past
  if FLaidOutWidth < 0 then
  begin
    ScrollPos := FScroll + ADelta;
    Exit;
  end;
  Limit := Max(0, FContentHeight - TextHeight);
  Target := FScroll + ADelta;
  Excess := 0;
  if Target > Limit then
    Excess := Target - Limit
  else if Target < 0 then
    Excess := Target;
  ScrollPos := Target;
  if Excess = 0 then
  begin
    FOverscroll := 0;
    Exit;
  end;
  // on past an end: added up (a pull the other way starts again)
  if (FOverscroll <> 0) and ((Excess > 0) <> (FOverscroll > 0)) then
    FOverscroll := 0;
  FOverscroll := FOverscroll + Excess;
  if Abs(FOverscroll) < FFontSize * FLineHeight * EDGE_PULL_LINES then
    Exit;
  FOverscroll := 0;
  if not FPreview and (FLayout <> nil) and Assigned(FOnEdge) then
    FOnEdge(Self, Excess > 0);
end;

function TEpubView.ItemAtY(AY: Single): Integer;
var
  Lo, Hi, Mid: Integer;
begin
  // the items' bottoms never go down: a binary search
  Lo := 0;
  Hi := High(FItems);
  if Hi < 0 then
    Exit(-1);
  while Lo < Hi do
  begin
    Mid := (Lo + Hi) div 2;
    if FItems[Mid].Top + FItems[Mid].Height < AY then
      Lo := Mid + 1
    else
      Hi := Mid;
  end;
  Result := Lo;
end;

function TEpubView.GuessHeight(const ABlock: TEpubBlock; AWidth: Single): Single;
var
  R, Chars, Breaks, Lines: Integer;
  SizeSum, Size: Double;
  C: Char;
begin
  // the runs' size, averaged over their characters
  SizeSum := 0;
  Chars := 0;
  for R := 0 to High(ABlock.Runs) do
  begin
    SizeSum := SizeSum + ABlock.Runs[R].Size * ABlock.Runs[R].Length;
    Inc(Chars, ABlock.Runs[R].Length);
  end;
  if Chars > 0 then
    Size := SizeSum / Chars
  else
    Size := 1;
  if Size <= 0 then
    Size := 1;
  Breaks := 0;
  for C in ABlock.Text do
    if C = #10 then
      Inc(Breaks);
  // an em space of indent is two average characters
  Chars := Length(ABlock.Text) + 2 * Max(0, Round(ABlock.TextIndent));
  Lines := Breaks + Max(1, Ceil(Chars * FFontSize * Size * CHAR_EM / Max(1, AWidth)));
  Result := Lines * FFontSize * Size * FLineHeight;
end;

function TEpubView.GuessScale: Single;
begin
  if FMeasuredGuess > 0 then
    Result := EnsureRange(FMeasuredReal / FMeasuredGuess, 0.25, 4)
  else
    Result := 1;
end;

procedure TEpubView.PlaceItems;
var
  I: Integer;
  Y, Scale: Single;
begin
  Scale := GuessScale;
  Y := FPageMargin;
  for I := 0 to High(FItems) do
  begin
    Y := Y + FItems[I].SpaceAbove;
    // a chapter break (an audiobook's chapter): a rule in a gap above
    FItems[I].RuleY := 0;
    if FItems[I].BreakAbove and (Y > FPageMargin) then
    begin
      FItems[I].RuleY := Y + FFontSize * FLineHeight;
      Y := Y + 2 * FFontSize * FLineHeight;
    end;
    if not FItems[I].Measured then
      FItems[I].Height := FItems[I].Guess * Scale;
    FItems[I].Top := Y;
    if FItems[I].Height > 0 then
      Y := Y + FItems[I].Height + FItems[I].SpaceBelow;
  end;
  FContentHeight := Y + FPageMargin;
end;

procedure TEpubView.MeasureItem(AIndex: Integer);
var
  B: TEpubBook;
  Blk: TEpubBlock;
  Off: Integer;
  Scale, W: Single;
  Bytes: TBytes;
begin
  if FItems[AIndex].Measured then
    Exit;
  FItems[AIndex].Measured := True;
  Inc(FMeasuredCount);
  B := Book;
  Blk := FLayout.Blocks[FItems[AIndex].Block];
  case Blk.Kind of
    ebkImage:
      begin
        FItems[AIndex].Image := nil;
        if B <> nil then
          try
            if B.Zip.Exists(Blk.ImagePath) then
            begin
              Bytes := B.ReadResource(Blk.ImagePath);
              FItems[AIndex].Image := TSkImage.MakeFromEncoded(Bytes);   // nil for SVG etc.
            end;
          except
            // a damaged or unreadable entry (CRC, ZIP method, too large):
            // no picture, and the rest of the document is still laid out.
            // Raised from here it left Draw with the items half made.
            on E: Exception do
              FItems[AIndex].Image := nil;
          end;
        if FItems[AIndex].Image <> nil then
        begin
          // centred in the column the item was given
          W := FItems[AIndex].Width;
          Scale := Min(W / FItems[AIndex].Image.Width, FImageMax / FItems[AIndex].Image.Height);
          Scale := Min(Scale, 2);
          FItems[AIndex].Width := FItems[AIndex].Image.Width * Scale;
          FItems[AIndex].Height := FItems[AIndex].Image.Height * Scale;
          FItems[AIndex].X := FItems[AIndex].X + (W - FItems[AIndex].Width) / 2;
        end
        else
          FItems[AIndex].Height := 0;
      end;
    ebkRule:
      FItems[AIndex].Height := FFontSize;
  else
    FItems[AIndex].Paragraph := MakeParagraph(Blk, FItems[AIndex].Width, Off);
    FItems[AIndex].Offset := Off;
    FItems[AIndex].Height := FItems[AIndex].Paragraph.Height;
    FMeasuredGuess := FMeasuredGuess + FItems[AIndex].Guess;
    FMeasuredReal := FMeasuredReal + FItems[AIndex].Height;
  end;
end;

function TEpubView.MeasureSpan(ATop, ABottom: Single): Boolean;
var
  I, Anchor: Integer;
  AnchorOffset, Old: Single;
  AtEnd: Boolean;
begin
  Result := False;
  Anchor := -1;
  AnchorOffset := 0;
  AtEnd := False;
  I := ItemAtY(ATop);
  if I < 0 then
    Exit;
  while (I <= High(FItems)) and (FItems[I].Top <= ABottom) do
  begin
    if not FItems[I].Measured then
    begin
      if not Result then
      begin
        // before anything changes: what is at the top of the view, and
        // whether the view is at the document's end
        Anchor := ItemAtY(FScroll);
        AnchorOffset := FScroll - FItems[Anchor].Top;
        AtEnd := (FScroll > 0) and (FScroll >= FContentHeight - TextHeight - 1);
        Result := True;
      end;
      MeasureItem(I);
    end;
    Inc(I);
  end;
  if not Result then
    Exit;
  PlaceItems;
  // the text on the screen does not move: the scroll position follows it,
  // and with it a smooth scroll's target (a drag goes by its moves)
  Old := FScroll;
  if AtEnd then
    FScroll := FContentHeight - TextHeight
  else
    FScroll := FItems[Anchor].Top + AnchorOffset;
  FScroll := Max(0, Min(FScroll, FContentHeight - TextHeight));
  FScrollTarget := FScrollTarget + (FScroll - Old);
end;

procedure TEpubView.MeasureView;
var
  N: Integer;
begin
  N := 0;
  while (N < MEASURE_PASSES) and MeasureSpan(FScroll - TextHeight / 2, FScroll + TextHeight * 1.5) do
    Inc(N);
end;

function TEpubView.PlaceBlock(ABlock: Integer): Integer;
var
  N: Integer;
begin
  Result := -1;
  if (ABlock < 0) or (ABlock > High(FItems)) then
    Exit;
  N := 0;
  while (N < MEASURE_PASSES) and MeasureSpan(FItems[ABlock].Top - TextHeight * 1.5,
    FItems[ABlock].Top + FItems[ABlock].Height + TextHeight * 1.5) do
    Inc(N);
  // itself at least, whatever the rounds left
  if not FItems[ABlock].Measured then
    MeasureSpan(FItems[ABlock].Top, FItems[ABlock].Top);
  if FItems[ABlock].Height > 0 then
    Result := ABlock;
end;

function TEpubView.Fonts: ISkTypefaceFontProvider;

  procedure Add(const AProvider: ISkTypefaceFontProvider; const AFamily, AAs: string);
  const
    WEIGHTS: array[0..1] of TSkFontWeight = (TSkFontWeight.Normal, TSkFontWeight.Bold);
    SLANTS: array[0..1] of TSkFontSlant = (TSkFontSlant.Upright, TSkFontSlant.Italic);
  var
    W, S: Integer;
    T: ISkTypeface;
  begin
    for W := 0 to 1 do
      for S := 0 to 1 do
      begin
        T := TSkTypeface.MakeFromName(AFamily, TSkFontStyle.Create(WEIGHTS[W], TSkFontWidth.Normal, SLANTS[S]));
        if T <> nil then
          AProvider.RegisterTypeface(T, AAs);
      end;
  end;

var
  Key: string;
  P: ISkTypefaceFontProvider;
begin
  Key := FFontFamily + #1 + FMonoFamily;
  if (FFonts = nil) or (Key <> FFontsFor) then
  begin
    P := TSkTypefaceFontProvider.Create;
    // '' = what the paragraphs used before: Skia's default "sans-serif"
    // (an unknown name gives the system's default face, as then)
    if FFontFamily = '' then
      Add(P, 'sans-serif', TEXT_FAMILY)
    else
      Add(P, FFontFamily, TEXT_FAMILY);
    Add(P, FMonoFamily, MONO_FAMILY);
    FFonts := P;
    FFontsFor := Key;
  end;
  Result := FFonts;
end;

function TEpubView.NewParagraphStyle(AAlign: TSkTextAlign): ISkParagraphStyle;
var
  TS: ISkTextStyle;
begin
  Result := TSkParagraphStyle.Create;
  Result.TextAlign := AAlign;
  TS := TSkTextStyle.Create;
  TS.FontFamilies := [TEXT_FAMILY];
  TS.FontSize := FFontSize;
  TS.Color := FTextColor;
  Result.TextStyle := TS;
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
    // the view's own family (Fonts): no lookup by name per paragraph
    Result.FontFamilies := [TEXT_FAMILY];
  end;

begin
  case ABlock.Align of
    etaCenter: PS := NewParagraphStyle(TSkTextAlign.Center);
    etaEnd: PS := NewParagraphStyle(TSkTextAlign.Right);
    etaJustify: PS := NewParagraphStyle(TSkTextAlign.Justify);
  else
    // left as the book has it (start / not set): justified when Justify
    // is on, for running text only
    if FJustify and (ABlock.Kind in [ebkParagraph, ebkListItem]) then
      PS := NewParagraphStyle(TSkTextAlign.Justify)
    else
      PS := NewParagraphStyle(TSkTextAlign.Left);
  end;
  // the fonts found once; fallback (characters the font lacks) stays on
  Builder := TSkParagraphBuilder.Create(PS, Fonts, True);
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
      TS.FontFamilies := [MONO_FAMILY];
    Builder.PushStyle(TS);
    Builder.AddText(Copy(ABlock.Text, Run.Start + 1, Run.Length));
    Builder.Pop;
  end;
  Result := Builder.Build;
  Result.Layout(AWidth);
end;

procedure TEpubView.LayoutItems(AWidth: Single);
var
  I, AnchorBlock: Integer;
  AnchorShare: Single;
  Blk: TEpubBlock;
  X, W: Single;
  Item: TEpubViewItem;
begin
  // the same document laid out before (another width or font): the block
  // at the top of the view, and how far into it, are kept
  AnchorBlock := -1;
  AnchorShare := 0;
  if (FLayout <> nil) and (Length(FItems) = FLayout.BlockCount) then
  begin
    AnchorBlock := ItemAtY(FScroll);
    if (AnchorBlock >= 0) and (FItems[AnchorBlock].Height > 0) then
      AnchorShare := EnsureRange((FScroll - FItems[AnchorBlock].Top) / FItems[AnchorBlock].Height, 0, 1);
  end;
  FItems := nil;
  FLaidOutWidth := AWidth;
  FContentHeight := 0;
  FMeasuredCount := 0;
  FMeasuredGuess := 0;
  FMeasuredReal := 0;
  if (Book = nil) or (FLayout = nil) or (AWidth <= 2 * FPageMargin) then
    Exit;
  FImageMax := Max(Height * IMAGE_MAX_VIEW, FFontSize * 4);
  // every block estimated - none laid out: Skia's paragraphs are made
  // where the view is (MeasureView, PlaceBlock). Laying out a whole
  // document first was 0.48 s of every opening of Night Watch's 1236
  // blocks on the phone (session 16).
  SetLength(FItems, FLayout.BlockCount);
  for I := 0 to High(FItems) do
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
    Item.X := X;
    Item.Width := W;
    if Blk.Kind = ebkHeading then
      Item.SpaceAbove := FFontSize * FParagraphSpacing;   // room above a heading
    Item.BreakAbove := BreakBefore(I);
    if (Blk.TextIndent > 0) and (Blk.Kind = ebkParagraph) then
      Item.SpaceBelow := FFontSize * FParagraphSpacing / 3
    else
      Item.SpaceBelow := FFontSize * FParagraphSpacing;
    case Blk.Kind of
      ebkRule:
        begin
          // nothing to make: laid out as it is
          Item.Height := FFontSize;
          Item.Measured := True;
          Inc(FMeasuredCount);
        end;
      ebkImage:
        Item.Guess := Min(W * IMAGE_GUESS, FImageMax);
    else
      Item.Guess := GuessHeight(Blk, W);
    end;
    FItems[I] := Item;
  end;
  PlaceItems;
  if AnchorBlock > High(FItems) then
    AnchorBlock := -1;
  if AnchorBlock >= 0 then
    FScroll := Max(0, Min(FItems[AnchorBlock].Top + AnchorShare * FItems[AnchorBlock].Height,
      FContentHeight - TextHeight));
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
  I, K, Local, F, L, S, E, CoreFirst, Pass, RangeFirst, RangeLast: Integer;
  RangeColor: TAlphaColor;
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
  // what is about to be seen is laid out (it may move FScroll: the text on
  // the screen stays where it was)
  MeasureView;
  if FShowProgress then
    DrawFooter(ACanvas, RectF(ADest.Left, TextRect.Bottom, ADest.Right, ADest.Bottom));
  ACanvas.Save;
  try
    ACanvas.ClipRect(TextRect);
    for I := Max(0, ItemAtY(FScroll)) to High(FItems) do
    begin
      Item := FItems[I];
      Top := ADest.Top + Item.Top - FScroll;
      if Top > TextRect.Bottom then
        Break;
      // not laid out (only past the rounds MeasureView allows) or no height
      if not Item.Measured or (Item.Height <= 0) then
        Continue;
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
      // (a preview has only the document's own marks: the book's words
      // are not read)
      if (TAlphaColorRec(FNoteColor).A > 0) and ((Blk.Role = ewrNote) or (not FPreview and
        (Length(Blk.Words) > 0) and
        (B.Words[Blk.Words[0].Word + B.Documents[FDocument].FirstWord].Role = ewrNote))) then
      begin
        Paint.Style := TSkPaintStyle.Fill;
        Paint.Color := FNoteColor;
        ACanvas.DrawRect(RectF(ADest.Left + Item.X - FPageMargin / 2, Top - 2,
          ADest.Left + Item.X + Item.Width + FPageMargin / 2, Top + Item.Height + 2), Paint);
      end;
      if Item.Paragraph <> nil then
      begin
        // the highlights, behind the text: the phrase / sentence's first
        // (pale), the word's over it
        for Pass := 0 to 1 do
        begin
          if Pass = 0 then
          begin
            RangeFirst := FUnitFirst;
            RangeLast := FUnitLast;
            RangeColor := FUnitColor;
          end
          else
          begin
            RangeFirst := FHighFirst;
            RangeLast := FHighLast;
            RangeColor := FHighlightColor;
          end;
          if (RangeFirst >= 0) and (Length(Blk.Words) > 0) then
          begin
            F := -1;
            L := -1;
            for K := 0 to High(Blk.Words) do
            begin
              Local := Blk.Words[K].Word + B.Documents[FDocument].FirstWord;
              if (Local >= RangeFirst) and (Local <= RangeLast) then
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
              Paint.Color := RangeColor;
              for K := 0 to High(Boxes) do
              begin
                R := Boxes[K].Rect;
                R.Offset(ADest.Left + Item.X, Top);
                R.Inflate(2, 0);
                ACanvas.DrawRect(R, Paint);
              end;
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
  // a preview: how far through the book is not known yet
  if FPreview then
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
  PS := NewParagraphStyle(TSkTextAlign.Center);
  Builder := TSkParagraphBuilder.Create(PS, Fonts, True);
  TS := TSkTextStyle.Create;
  TS.Color := (FTextColor and $00FFFFFF) or $A0000000;
  TS.FontSize := Max(11, FFontSize * 0.65);
  TS.FontFamilies := [TEXT_FAMILY];
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
  for I := Max(0, ItemAtY(DocY)) to High(FItems) do
  begin
    Item := FItems[I];
    if Item.Top > DocY then
      Break;
    // a paragraph not laid out is not on the screen either
    if (DocY > Item.Top + Item.Height) or (Item.Height <= 0) or (Item.Paragraph = nil) then
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
  ScrollBy(-WheelDelta / WHEEL_DELTA * WHEEL_LINES * FFontSize * FLineHeight);
  Handled := True;
end;

procedure TEpubView.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  case Key of
    vkDown:
      ScrollBy(FFontSize * FLineHeight);
    vkUp:
      ScrollBy(-FFontSize * FLineHeight);
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

procedure TEpubView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if Button <> TMouseButton.mbLeft then
    Exit;
  FPressed := True;
  FDragging := False;
  FPressY := Y;
  // a press stops a glide - and is then no click
  FPressStoppedFling := FFlingSpeed <> 0;
  StopFling;
  FDragSpeed := 0;
  FDragTick := TThread.GetTickCount64;
end;

procedure TEpubView.MouseMove(Shift: TShiftState; X, Y: Single);
const
  { Moved this far, px, a press is a drag (less is an unsteady click). }
  DRAG_SLOP = 8;
var
  Now_: UInt64;
begin
  inherited;
  if not (FPressed and FDragScroll) then
    Exit;
  if not FDragging and (Abs(Y - FPressY) > DRAG_SLOP) then
  begin
    FDragging := True;
    FDragY := FPressY;
  end;
  if FDragging then
  begin
    // the drag's speed, for the glide after it (the recent moves count
    // most)
    Now_ := TThread.GetTickCount64;
    if Now_ > FDragTick then
      FDragSpeed := 0.6 * ((FDragY - Y) * 1000 / (Now_ - FDragTick)) + 0.4 * FDragSpeed;
    FDragTick := Now_;
    // by the move since the last one: past an end of the document the
    // finger pulls on into the next (OnEdge), and the drag goes on there
    ScrollBy(FDragY - Y);
    FDragY := Y;
  end;
end;

procedure TEpubView.DoMouseLeave;
begin
  inherited;
  FPressed := False;
  FDragging := False;
end;

procedure TEpubView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
const
  { A drag at least this fast, px a second, glides on. }
  FLING_MIN_SPEED = 400;
  { ... when the finger was still moving this recently, ms (a drag that
    stopped before letting go does not glide). }
  FLING_MAX_PAUSE = 80;
  { The glide's tick, ms. }
  FLING_TICK_MS = 15;
var
  W: Integer;
  Dragged: Boolean;
begin
  inherited;
  Dragged := FDragging;
  if Button = TMouseButton.mbLeft then
  begin
    FPressed := False;
    FDragging := False;
  end;
  // a quick drag let go: the page glides on
  if Dragged and FFling and (Abs(FDragSpeed) >= FLING_MIN_SPEED) and
    (TThread.GetTickCount64 - FDragTick <= FLING_MAX_PAUSE) then
  begin
    if FFlingTimer = nil then
    begin
      FFlingTimer := TTimer.Create(Self);
      FFlingTimer.Interval := FLING_TICK_MS;
      FFlingTimer.OnTimer := FlingTimer;
    end;
    FFlingSpeed := FDragSpeed;
    FFlingTick := TThread.GetTickCount64;
    FFlingTimer.Enabled := True;
  end;
  // letting go after a drag is not a click on the word under it, nor
  // after a press that stopped a glide
  if Dragged or FPressStoppedFling then
  begin
    FPressStoppedFling := False;
    Exit;
  end;
  if (Button <> TMouseButton.mbLeft) or not Assigned(FOnWordClick) then
    Exit;
  W := WordAt(X, Y);
  if W >= 0 then
    FOnWordClick(Self, W);
end;

end.
