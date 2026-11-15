(* @abstract(The layout model of a content document: its words (with their
  element ids and roles) and, for a renderer, its blocks of styled text.)

  @link(TEpubDocLayout) walks a document's body once. Without blocks it
  only splits the text into words - what TEpubBook.Words, the aligner and
  media overlays use. With blocks it also produces what a reflowing
  renderer draws: paragraphs, headings, list items, table cells,
  preformatted text, pictures and rules, each with its text, its styled
  runs (italic, bold, small caps, size, links, ...) and the character
  span of every word. The words are the same in both modes - one walker,
  one numbering - so a word index from an overlay or an alignment always
  finds its place on screen.

  Styles come from the element names (an HTML reader's defaults: em / i
  italic, h1 large and bold, ...) and from the book's CSS through
  Epub.Css (classes, style attributes). Character offsets are 0-based and
  in the compiler's string units: UTF-16 code units with Delphi (what
  Skia's paragraph ranges use), bytes of UTF-8 with FPC.

  Framework-free; compiles with Delphi and FPC. *)
unit Epub.Layout;

{$I Epub.inc}

interface

uses
  SysUtils, Classes,
  Epub.Zip, Epub.Xml, Epub.Css;

type
  { What a word is part of (decided by the markup around it, never by the
    words themselves). }
  TEpubWordRole = (
    { Running text. }
    ewrBody,
    { A heading (h1 - h6). }
    ewrHeading,
    { A figure or table caption. }
    ewrCaption,
    { A footnote, endnote or aside. }
    ewrNote,
    { A table cell. }
    ewrTable,
    { Preformatted text (pre). }
    ewrPreformatted,
    { Navigation (a nav element inside a content document). }
    ewrNav);

  { What a block is. }
  TEpubBlockKind = (
    { A paragraph (p, div, ... and loose text). }
    ebkParagraph,
    { A heading; Level 1 - 6. }
    ebkHeading,
    { A list item; Level = nesting depth from 1. }
    ebkListItem,
    { A table cell. }
    ebkTableCell,
    { Preformatted text: white space and line breaks kept. }
    ebkPreformatted,
    { A picture: ImagePath, ImageAlt. }
    ebkImage,
    { A horizontal rule. }
    ebkRule);

  { A style of a run. }
  TEpubRunStyle = (
    { Italic. }
    ersItalic,
    { Bold. }
    ersBold,
    { Small capitals. }
    ersSmallCaps,
    { Underlined. }
    ersUnderline,
    { Struck through. }
    ersStrike,
    { Monospace. }
    ersMono,
    { Superscript. }
    ersSuper,
    { Subscript. }
    ersSub,
    { A link (Href). }
    ersLink);
  { The styles of a run. }
  TEpubRunStyles = set of TEpubRunStyle;

  { A stretch of a block's text in one style. }
  TEpubRun = record
    { First character (0-based) in the block's Text. }
    Start: Integer;
    { Number of characters. }
    Length: Integer;
    { Styles. }
    Styles: TEpubRunStyles;
    { Font size as a factor of the reader's base size. }
    Size: Double;
    { Link target as written (for ersLink). }
    Href: string;
  end;
  { Runs of a block, in order, covering its whole Text. }
  TEpubRunArray = array of TEpubRun;

  { Where a word is in a block's text. }
  TEpubWordSpan = record
    { The word (index into the layout's Words). }
    Word: Integer;
    { First character (0-based) in the block's Text. }
    Start: Integer;
    { Number of characters. }
    Length: Integer;
  end;
  { Word spans of a block, in order. }
  TEpubWordSpanArray = array of TEpubWordSpan;

  { One block of a document. }
  TEpubBlock = record
    { What it is. }
    Kind: TEpubBlockKind;
    { Heading level (1 - 6) or list depth (from 1); 0 otherwise. }
    Level: Integer;
    { The role of its words. }
    Role: TEpubWordRole;
    { Alignment (never etaInherit). }
    Align: TEpubTextAlign;
    { First-line indent, em. }
    TextIndent: Double;
    { Left margin, em (blockquotes, lists). }
    MarginLeft: Double;
    { The text (white space collapsed unless preformatted; #10 = a line
      break). }
    Text: string;
    { Its styled runs. }
    Runs: TEpubRunArray;
    { Its words. }
    Words: TEpubWordSpanArray;
    { Full archive path of the picture (ebkImage). }
    ImagePath: string;
    { The picture's alt text (ebkImage). }
    ImageAlt: string;
    { Id of the block's element, '' when it has none. }
    Id: string;
  end;
  { Blocks in document order. }
  TEpubBlockArray = array of TEpubBlock;

  { One word of a document. }
  TEpubLayoutWord = record
    { The word as written, punctuation included. }
    Text: string;
    { Index of the innermost element with an id around it (into Ids), -1
      when none. }
    IdIndex: Integer;
    { What it is part of. }
    Role: TEpubWordRole;
    { Its block (-1 without blocks). }
    Block: Integer;
  end;
  { Words of a document. }
  TEpubLayoutWordArray = array of TEpubLayoutWord;

  { One element id of a document and the words it holds. }
  TEpubLayoutId = record
    { The id. }
    Id: string;
    { First word inside it, -1 when none. }
    FirstWord: Integer;
    { Last word inside it, -1 when none. }
    LastWord: Integer;
    { The block it starts in (-1 without blocks). }
    Block: Integer;
  end;
  { Ids in document order. }
  TEpubLayoutIdArray = array of TEpubLayoutId;

  { The layout of one content document. }
  TEpubDocLayout = class
  private
    { Backing field of @link(Words). }
    FWords: TEpubLayoutWordArray;
    { Words in use. }
    FWordCount: Integer;
    { Backing field of @link(Ids). }
    FIds: TEpubLayoutIdArray;
    { Backing field of @link(Blocks). }
    FBlocks: TEpubBlockArray;
    { Blocks in use. }
    FBlockCount: Integer;
    { The words, trimmed. }
    function GetWords: TEpubLayoutWordArray;
    { The blocks, trimmed. }
    function GetBlocks: TEpubBlockArray;
  public
    { Lays out the body of document ADocPath.
      @param(ABody  The document's body element (or root).)
      @param(ADocPath  Its archive path (for pictures' paths).)
      @param(AStyles  Its style sheets; nil = element defaults only.)
      @param(AWithBlocks  Also build the blocks (else only the words).) }
    constructor Create(ABody: TEpubXmlNode; const ADocPath: string; AStyles: TEpubStyleSheet;
      AWithBlocks: Boolean);
    { Index of id AId in Ids, -1 when absent. }
    function IndexOfId(const AId: string): Integer;
    { The words. }
    property Words: TEpubLayoutWordArray read GetWords;
    { Number of words. }
    property WordCount: Integer read FWordCount;
    { The element ids. }
    property Ids: TEpubLayoutIdArray read FIds;
    { The blocks (empty without blocks). }
    property Blocks: TEpubBlockArray read GetBlocks;
    { Number of blocks. }
    property BlockCount: Integer read FBlockCount;
  end;

{ Name of a word role ('body', 'heading', ...). }
function EpubWordRoleName(ARole: TEpubWordRole): string;
{ Name of a block kind ('paragraph', 'heading', ...). }
function EpubBlockKindName(AKind: TEpubBlockKind): string;
{ AText with the Unicode spaces (no-break, en / em / thin, U+2000 -
  U+200A, U+202F, U+3000) turned into plain spaces. }
function EpubPlainSpaces(const AText: string): string;
{ Full archive path of AHref as written in document ABase (relative paths
  resolved, '%20' decoded, any fragment dropped). }
function EpubResolvePath(const ABase, AHref: string): string;

implementation

uses
  Math;

const
  { Names of TEpubWordRole. }
  ROLE_NAMES: array[TEpubWordRole] of string = ('body', 'heading', 'caption', 'note', 'table',
    'preformatted', 'nav');
  { Names of TEpubBlockKind. }
  KIND_NAMES: array[TEpubBlockKind] of string = ('paragraph', 'heading', 'list item', 'table cell',
    'preformatted', 'image', 'rule');
  { Elements that are blocks (start and end separate words and blocks). }
  BLOCK_ELEMENTS: array[0..30] of string = ('p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li',
    'ul', 'ol', 'dl', 'dt', 'dd', 'td', 'th', 'tr', 'table', 'pre', 'blockquote', 'section',
    'article', 'aside', 'figure', 'figcaption', 'caption', 'header', 'footer', 'main', 'nav',
    'center');
  { Elements whose content is never shown or read. }
  SKIP_ELEMENTS: array[0..8] of string = ('head', 'script', 'style', 'rt', 'rp', 'svg', 'math',
    'title', 'template');
  { Heading sizes (h1 .. h6), as a browser's defaults. }
  HEADING_SIZE: array[1..6] of Double = (2.0, 1.5, 1.17, 1.0, 0.83, 0.67);

function EpubWordRoleName(ARole: TEpubWordRole): string;
begin
  Result := ROLE_NAMES[ARole];
end;

function EpubBlockKindName(AKind: TEpubBlockKind): string;
begin
  Result := KIND_NAMES[AKind];
end;

{ True when AValue is one of AList. }
function InList(const AValue: string; const AList: array of string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(AList) do
    if AList[I] = AValue then
      Exit(True);
  Result := False;
end;

function EpubPlainSpaces(const AText: string): string;
{$ifdef FPC}
var
  I: Integer;
begin
  // FPC strings are UTF-8: the spaces are byte sequences
  Result := AText;
  I := 1;
  while I < Length(Result) do
  begin
    if (Result[I] = #$C2) and (Result[I + 1] = #$A0) then
    begin
      Result[I] := ' ';
      Delete(Result, I + 1, 1);
    end
    else if (I + 2 <= Length(Result)) and (Result[I] = #$E2) and (Result[I + 1] = #$80) and
      ((Ord(Result[I + 2]) in [$80..$8A]) or (Result[I + 2] = #$AF)) then
    begin
      Result[I] := ' ';
      Delete(Result, I + 1, 2);
    end
    else if (I + 2 <= Length(Result)) and (Result[I] = #$E3) and (Result[I + 1] = #$80) and
      (Result[I + 2] = #$80) then
    begin
      Result[I] := ' ';
      Delete(Result, I + 1, 2);
    end;
    Inc(I);
  end;
end;
{$else}
var
  I: Integer;
begin
  Result := AText;
  for I := 1 to Length(Result) do
    case Ord(Result[I]) of
      $A0, $2000..$200A, $202F, $3000:
        Result[I] := ' ';
    end;
end;
{$endif}

{ AText with %XX escapes decoded (as UTF-8 bytes). }
function PercentDecode(const AText: string): string;
var
  I, V, N: Integer;
  B: TBytes;
  U: TBytes;
begin
  if Pos('%', AText) = 0 then
    Exit(AText);
  U := EpubUtf8Bytes(AText);
  SetLength(B, Length(U));
  N := 0;
  I := 0;
  while I < Length(U) do
  begin
    if (U[I] = Ord('%')) and (I + 2 < Length(U)) and
      TryStrToInt('$' + Char(U[I + 1]) + Char(U[I + 2]), V) then
    begin
      B[N] := V;
      Inc(I, 3);
    end
    else
    begin
      B[N] := U[I];
      Inc(I);
    end;
    Inc(N);
  end;
  SetLength(B, N);
  Result := EpubBytesText(B);
end;

function EpubResolvePath(const ABase, AHref: string): string;
var
  H, Dir: string;
  P, I: Integer;
  Parts: TStringList;
begin
  H := AHref;
  P := Pos('#', H);
  if P > 0 then
    SetLength(H, P - 1);
  H := PercentDecode(H);
  if H = '' then
    Exit(ABase);
  if H[1] = '/' then
    Dir := ''
  else
  begin
    P := LastDelimiter('/', ABase);
    Dir := Copy(ABase, 1, P);
  end;
  Parts := TStringList.Create;
  try
    Parts.Delimiter := '/';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := Dir + H;
    I := 0;
    while I < Parts.Count do
    begin
      if (Parts[I] = '.') or ((Parts[I] = '') and (I < Parts.Count - 1)) then
        Parts.Delete(I)
      else if Parts[I] = '..' then
      begin
        Parts.Delete(I);
        if I > 0 then
        begin
          Parts.Delete(I - 1);
          Dec(I);
        end;
      end
      else
        Inc(I);
    end;
    Result := '';
    for I := 0 to Parts.Count - 1 do
    begin
      if I > 0 then
        Result := Result + '/';
      Result := Result + Parts[I];
    end;
  finally
    Parts.Free;
  end;
end;

type
  { The computed state while walking: what an element passes on. }
  TWalkState = record
    { Index of the innermost element with an id (into FIds), -1 = none. }
    IdIndex: Integer;
    { Role of the words. }
    Role: TEpubWordRole;
    { Inline styles. }
    Styles: TEpubRunStyles;
    { Font size factor. }
    Size: Double;
    { Link target. }
    Href: string;
    { Keep white space. }
    Pre: Boolean;
    { Alignment of blocks inside. }
    Align: TEpubTextAlign;
    { First-line indent of blocks inside, em. }
    TextIndent: Double;
    { Left margin, em (accumulated). }
    MarginLeft: Double;
    { List nesting depth. }
    ListDepth: Integer;
  end;

  { The walker (one per TEpubDocLayout.Create). }
  TWalker = class
    { The layout being built. }
    L: TEpubDocLayout;
    { The document's path. }
    DocPath: string;
    { Its style sheets (may be nil). }
    Sheet: TEpubStyleSheet;
    { Build blocks. }
    WithBlocks: Boolean;
    { The word being collected. }
    Buf: string;
    { Its id index, role and start offset in the block text. }
    BufId: Integer;
    { Its role. }
    BufRole: TEpubWordRole;
    { Its start in the open block's text. }
    BufStart: Integer;
    { A block is open (blocks mode). }
    Open: Boolean;
    { The open block's index. }
    Cur: Integer;
    { Properties for the next block opened. }
    NextKind: TEpubBlockKind;
    { Its level. }
    NextLevel: Integer;
    { Its id. }
    NextId: string;
    { The state of the block that will open next. }
    NextState: TWalkState;
    { Adds a word. }
    procedure FlushWord;
    { Opens a block for text in state AState when none is open. }
    procedure EnsureBlock(const AState: TWalkState);
    { Closes the open block (and the word in progress). }
    procedure CloseBlock;
    { Appends AText to the open block in state AState. }
    procedure AppendText(const AText: string; const AState: TWalkState);
    { Records that ALength characters ending the open block's text were
      added in state AState (a new run, or the last one grown). }
    procedure AddRun(ALength: Integer; const AState: TWalkState);
    { Drops trailing spaces of the open block's text and of its runs. }
    procedure TrimEnd;
    { Ends the line inside the open block (br). }
    procedure LineBreak(const AState: TWalkState);
    { Adds a picture / rule block. }
    procedure AddSpecial(AKind: TEpubBlockKind; const APath, AAlt, AId: string; const AState: TWalkState);
    { Walks AEl's children. }
    procedure Walk(AEl: TEpubXmlNode; const AState: TWalkState);
  end;

{ The role AEl gives its content, from markup only. }
function RoleOf(AEl: TEpubXmlNode; AInherited: TEpubWordRole): TEpubWordRole;
var
  L, T: string;
begin
  Result := AInherited;
  L := AEl.LocalName;
  // semantic markup (epub:type, ARIA role) and class names as a common
  // convention ('image_caption', 'footnote'): markup, never the words
  T := ' ' + LowerCase(AEl.Attr('epub:type') + ' ' + AEl.Attr('role') + ' ' + AEl.Attr('class')) + ' ';
  if (L = 'aside') or (Pos('footnote', T) > 0) or (Pos('endnote', T) > 0) or (Pos(' note ', T) > 0) or
    (Pos('rearnote', T) > 0) then
    Result := ewrNote
  else if Result = ewrNote then
    Exit
  else if (L = 'figcaption') or (L = 'caption') or (Pos('caption', T) > 0) then
    Result := ewrCaption
  else if Result = ewrCaption then
    Exit
  else if L = 'nav' then
    Result := ewrNav
  else if Result = ewrNav then
    Exit
  else if (L = 'td') or (L = 'th') then
    Result := ewrTable
  else if L = 'pre' then
    Result := ewrPreformatted
  else if (Length(L) = 2) and (L[1] = 'h') and CharInSet(L[2], ['1'..'6']) then
    Result := ewrHeading;
end;

procedure TWalker.FlushWord;
var
  N, W: Integer;
begin
  if Buf = '' then
    Exit;
  if L.FWordCount = Length(L.FWords) then
    SetLength(L.FWords, L.FWordCount * 2 + 256);
  W := L.FWordCount;
  L.FWords[W].Text := Buf;
  L.FWords[W].IdIndex := BufId;
  L.FWords[W].Role := BufRole;
  L.FWords[W].Block := -1;
  Inc(L.FWordCount);
  if WithBlocks and Open then
  begin
    L.FWords[W].Block := Cur;
    N := Length(L.FBlocks[Cur].Words);
    SetLength(L.FBlocks[Cur].Words, N + 1);
    L.FBlocks[Cur].Words[N].Word := W;
    L.FBlocks[Cur].Words[N].Start := BufStart;
    L.FBlocks[Cur].Words[N].Length := Length(L.FBlocks[Cur].Text) - BufStart;
  end;
  Buf := '';
end;

procedure TWalker.EnsureBlock(const AState: TWalkState);
var
  B: TEpubBlock;
begin
  if not WithBlocks or Open then
    Exit;
  B := Default(TEpubBlock);
  B.Kind := NextKind;
  B.Level := NextLevel;
  B.Role := NextState.Role;
  B.Align := NextState.Align;
  if B.Align = etaInherit then
    B.Align := etaStart;
  B.TextIndent := NextState.TextIndent;
  B.MarginLeft := NextState.MarginLeft;
  B.Id := NextId;
  NextId := '';
  if L.FBlockCount = Length(L.FBlocks) then
    SetLength(L.FBlocks, L.FBlockCount * 2 + 64);
  L.FBlocks[L.FBlockCount] := B;
  Cur := L.FBlockCount;
  Inc(L.FBlockCount);
  Open := True;
end;

procedure TWalker.CloseBlock;
begin
  FlushWord;
  if not Open then
    Exit;
  Open := False;
  // trailing white space (not of preformatted text)
  if L.FBlocks[Cur].Kind <> ebkPreformatted then
    TrimEnd;
  // a block with no text and no words is dropped (empty divs)
  if (L.FBlocks[Cur].Text = '') and (Length(L.FBlocks[Cur].Words) = 0) then
    Dec(L.FBlockCount);
end;

procedure TWalker.AppendText(const AText: string; const AState: TWalkState);
var
  K: Integer;
  Ch: Char;
  S: string;
  Added: string;
begin
  S := EpubPlainSpaces(AText);
  Added := '';
  for K := 1 to Length(S) do
  begin
    Ch := S[K];
    if CharInSet(Ch, [' ', #9, #10, #13]) then
    begin
      FlushWord;
      if not WithBlocks then
        Continue;
      if AState.Pre then
      begin
        if Ch <> #13 then
        begin
          EnsureBlock(AState);
          Added := Added + Ch;
          L.FBlocks[Cur].Text := L.FBlocks[Cur].Text + Ch;
        end;
      end
      else if Open and (L.FBlocks[Cur].Text <> '') and
        not CharInSet(L.FBlocks[Cur].Text[Length(L.FBlocks[Cur].Text)], [' ', #10]) then
      begin
        Added := Added + ' ';
        L.FBlocks[Cur].Text := L.FBlocks[Cur].Text + ' ';
      end;
      Continue;
    end;
    if WithBlocks then
      EnsureBlock(AState);
    if Buf = '' then
    begin
      BufId := AState.IdIndex;
      BufRole := AState.Role;
      if WithBlocks then
        BufStart := Length(L.FBlocks[Cur].Text);
    end;
    Buf := Buf + Ch;
    if WithBlocks then
    begin
      Added := Added + Ch;
      L.FBlocks[Cur].Text := L.FBlocks[Cur].Text + Ch;
    end;
  end;
  if WithBlocks and Open and (Added <> '') then
    AddRun(Length(Added), AState);
end;

procedure TWalker.AddRun(ALength: Integer; const AState: TWalkState);
var
  N, Last: Integer;
  R: TEpubRun;
begin
  N := Length(L.FBlocks[Cur].Text) - ALength;
  Last := High(L.FBlocks[Cur].Runs);
  if (Last >= 0) and (L.FBlocks[Cur].Runs[Last].Styles = AState.Styles) and
    SameValue(L.FBlocks[Cur].Runs[Last].Size, AState.Size) and (L.FBlocks[Cur].Runs[Last].Href = AState.Href) and
    (L.FBlocks[Cur].Runs[Last].Start + L.FBlocks[Cur].Runs[Last].Length = N) then
    Inc(L.FBlocks[Cur].Runs[Last].Length, ALength)
  else
  begin
    R := Default(TEpubRun);
    R.Start := N;
    R.Length := ALength;
    R.Styles := AState.Styles;
    R.Size := AState.Size;
    R.Href := AState.Href;
    SetLength(L.FBlocks[Cur].Runs, Last + 2);
    L.FBlocks[Cur].Runs[Last + 1] := R;
  end;
end;

procedure TWalker.TrimEnd;
var
  T: string;
  N, R: Integer;
begin
  T := L.FBlocks[Cur].Text;
  N := Length(T);
  while (N > 0) and (T[N] = ' ') do
    Dec(N);
  if N = Length(T) then
    Exit;
  L.FBlocks[Cur].Text := Copy(T, 1, N);
  while Length(L.FBlocks[Cur].Runs) > 0 do
  begin
    R := High(L.FBlocks[Cur].Runs);
    if L.FBlocks[Cur].Runs[R].Start >= N then
    begin
      SetLength(L.FBlocks[Cur].Runs, R);
      Continue;
    end;
    if L.FBlocks[Cur].Runs[R].Start + L.FBlocks[Cur].Runs[R].Length > N then
      L.FBlocks[Cur].Runs[R].Length := N - L.FBlocks[Cur].Runs[R].Start;
    Break;
  end;
end;

procedure TWalker.LineBreak(const AState: TWalkState);
begin
  FlushWord;
  if not WithBlocks or not Open then
    Exit;
  TrimEnd;
  L.FBlocks[Cur].Text := L.FBlocks[Cur].Text + #10;
  AddRun(1, AState);
end;

procedure TWalker.AddSpecial(AKind: TEpubBlockKind; const APath, AAlt, AId: string; const AState: TWalkState);
var
  SaveKind: TEpubBlockKind;
  SaveLevel: Integer;
  SaveId: string;
  SaveState: TWalkState;
begin
  if not WithBlocks then
    Exit;
  CloseBlock;
  SaveKind := NextKind;
  SaveLevel := NextLevel;
  SaveId := NextId;
  SaveState := NextState;
  NextKind := AKind;
  NextLevel := 0;
  NextId := AId;
  NextState := AState;
  if NextState.Align = etaInherit then
    NextState.Align := etaCenter;   // pictures and rules are centred
  EnsureBlock(NextState);
  L.FBlocks[Cur].ImagePath := APath;
  L.FBlocks[Cur].ImageAlt := AAlt;
  Open := False;   // kept although it has no text
  NextKind := SaveKind;
  NextLevel := SaveLevel;
  NextId := SaveId;
  NextState := SaveState;
end;

procedure TWalker.Walk(AEl: TEpubXmlNode; const AState: TWalkState);
var
  I, Id, WStart, WLast, Lvl: Integer;
  C: TEpubXmlNode;
  Loc, IdText: string;
  IsBlock: Boolean;
  St: TWalkState;
  Css: TEpubStyle;
  SaveKind: TEpubBlockKind;
  SaveLevel: Integer;
  SaveState: TWalkState;
begin
  for I := 0 to AEl.ChildCount - 1 do
  begin
    C := AEl.Children[I];
    if C.Kind = xnText then
    begin
      AppendText(C.Text, AState);
      Continue;
    end;
    Loc := C.LocalName;
    if InList(Loc, SKIP_ELEMENTS) or C.HasAttr('hidden') then
      Continue;
    // computed style: element defaults, then the style sheets
    St := AState;
    if Sheet <> nil then
      Css := Sheet.StyleOf(Loc, C.Attr('class'), C.Attr('id'), C.Attr('style'))
    else
      Css := EpubStyleOfAttr(C.Attr('style'));
    if Css.Display = edNone then
      Continue;
    IsBlock := InList(Loc, BLOCK_ELEMENTS) or (Loc = 'br') or (Loc = 'hr') or (Loc = 'img') or (Loc = 'image');
    if Css.Display = edBlock then
      IsBlock := True
    else if (Css.Display = edInline) and (Loc <> 'br') and (Loc <> 'img') and (Loc <> 'image') then
      IsBlock := False;
    if (Loc = 'em') or (Loc = 'i') or (Loc = 'cite') or (Loc = 'var') or (Loc = 'dfn') then
      Include(St.Styles, ersItalic)
    else if (Loc = 'strong') or (Loc = 'b') or (Loc = 'th') then
      Include(St.Styles, ersBold)
    else if (Loc = 'u') or (Loc = 'ins') then
      Include(St.Styles, ersUnderline)
    else if (Loc = 's') or (Loc = 'del') or (Loc = 'strike') then
      Include(St.Styles, ersStrike)
    else if (Loc = 'code') or (Loc = 'tt') or (Loc = 'kbd') or (Loc = 'samp') then
      Include(St.Styles, ersMono)
    else if Loc = 'sup' then
    begin
      Include(St.Styles, ersSuper);
      St.Size := St.Size * 0.83;
    end
    else if Loc = 'sub' then
    begin
      Include(St.Styles, ersSub);
      St.Size := St.Size * 0.83;
    end
    else if Loc = 'small' then
      St.Size := St.Size * 0.85
    else if Loc = 'big' then
      St.Size := St.Size * 1.2
    else if Loc = 'pre' then
    begin
      St.Pre := True;
      Include(St.Styles, ersMono);
    end
    else if Loc = 'center' then
      St.Align := etaCenter
    else if Loc = 'blockquote' then
      St.MarginLeft := St.MarginLeft + 2
    else if (Loc = 'ul') or (Loc = 'ol') then
    begin
      Inc(St.ListDepth);
      St.MarginLeft := St.MarginLeft + 1.5;
    end
    else if (Loc = 'a') and (C.Attr('href') <> '') then
    begin
      Include(St.Styles, ersLink);
      St.Href := C.Attr('href');
    end;
    if (Length(Loc) = 2) and (Loc[1] = 'h') and CharInSet(Loc[2], ['1'..'6']) then
    begin
      Include(St.Styles, ersBold);
      St.Size := St.Size * HEADING_SIZE[Ord(Loc[2]) - Ord('0')];
    end;
    // the book's CSS on top
    case Css.Italic of
      efOn: Include(St.Styles, ersItalic);
      efOff: Exclude(St.Styles, ersItalic);
    end;
    case Css.Bold of
      efOn: Include(St.Styles, ersBold);
      efOff: Exclude(St.Styles, ersBold);
    end;
    case Css.SmallCaps of
      efOn: Include(St.Styles, ersSmallCaps);
      efOff: Exclude(St.Styles, ersSmallCaps);
    end;
    case Css.Underline of
      efOn: Include(St.Styles, ersUnderline);
      efOff: Exclude(St.Styles, ersUnderline);
    end;
    case Css.Strike of
      efOn: Include(St.Styles, ersStrike);
      efOff: Exclude(St.Styles, ersStrike);
    end;
    if Css.Mono = efOn then
      Include(St.Styles, ersMono);
    case Css.Pre of
      efOn: St.Pre := True;
      efOff: St.Pre := False;
    end;
    if Css.Shift > 0 then
      Include(St.Styles, ersSuper)
    else if Css.Shift < 0 then
      Include(St.Styles, ersSub);
    if Css.Align <> etaInherit then
      St.Align := Css.Align;
    if not IsNan(Css.TextIndent) then
      St.TextIndent := Css.TextIndent;
    if not IsNan(Css.MarginLeft) then
      St.MarginLeft := AState.MarginLeft + Css.MarginLeft;
    if not IsNan(Css.SizeFactor) then
      St.Size := AState.Size * Css.SizeFactor;
    St.Role := RoleOf(C, AState.Role);
    // id
    Id := AState.IdIndex;
    IdText := C.Attr('id');
    WStart := L.FWordCount;   // a word pending in Buf gets this index too
    if IdText <> '' then
    begin
      SetLength(L.FIds, Length(L.FIds) + 1);
      Id := High(L.FIds);
      L.FIds[Id].Id := IdText;
      L.FIds[Id].FirstWord := -1;
      L.FIds[Id].LastWord := -1;
      L.FIds[Id].Block := -1;
    end;
    St.IdIndex := Id;
    // pictures, rules, line breaks
    if (Loc = 'img') or (Loc = 'image') then
    begin
      FlushWord;
      if Loc = 'img' then
        AddSpecial(ebkImage, EpubResolvePath(DocPath, C.Attr('src')), C.Attr('alt'), IdText, St)
      else
        AddSpecial(ebkImage, EpubResolvePath(DocPath, C.Attr('href')), '', IdText, St);
      if (IdText <> '') and WithBlocks then
        L.FIds[Id].Block := L.FBlockCount - 1;
      Continue;
    end;
    if Loc = 'hr' then
    begin
      AddSpecial(ebkRule, '', '', IdText, St);
      Continue;
    end;
    if Loc = 'br' then
    begin
      LineBreak(St);
      Continue;
    end;
    // a block element: close what is open, describe the next block
    SaveKind := NextKind;
    SaveLevel := NextLevel;
    SaveState := NextState;
    if IsBlock then
    begin
      CloseBlock;
      NextKind := ebkParagraph;
      NextLevel := 0;
      if (Length(Loc) = 2) and (Loc[1] = 'h') and CharInSet(Loc[2], ['1'..'6']) then
      begin
        NextKind := ebkHeading;
        NextLevel := Ord(Loc[2]) - Ord('0');
      end
      else if Loc = 'li' then
      begin
        NextKind := ebkListItem;
        Lvl := St.ListDepth;
        if Lvl < 1 then
          Lvl := 1;
        NextLevel := Lvl;
      end
      else if (Loc = 'td') or (Loc = 'th') then
        NextKind := ebkTableCell
      else if St.Pre then
        NextKind := ebkPreformatted;
      NextState := St;
      if IdText <> '' then
        NextId := IdText;
    end;
    if (IdText <> '') and WithBlocks then
      L.FIds[Id].Block := L.FBlockCount;   // the next block (or the open one)
    if (IdText <> '') and WithBlocks and Open then
      L.FIds[Id].Block := Cur;
    Walk(C, St);
    if IdText <> '' then
    begin
      // every word that touches the element, nested ids included
      if Buf <> '' then
        WLast := L.FWordCount
      else
        WLast := L.FWordCount - 1;
      if WLast >= WStart then
      begin
        L.FIds[Id].FirstWord := WStart;
        L.FIds[Id].LastWord := WLast;
      end;
    end;
    if IsBlock then
    begin
      CloseBlock;
      NextKind := SaveKind;
      NextLevel := SaveLevel;
      NextState := SaveState;
    end;
  end;
end;

{ TEpubDocLayout }

constructor TEpubDocLayout.Create(ABody: TEpubXmlNode; const ADocPath: string; AStyles: TEpubStyleSheet;
  AWithBlocks: Boolean);
var
  W: TWalker;
  S: TWalkState;
  Css: TEpubStyle;
begin
  inherited Create;
  W := TWalker.Create;
  try
    W.L := Self;
    W.DocPath := ADocPath;
    W.Sheet := AStyles;
    W.WithBlocks := AWithBlocks;
    W.BufId := -1;
    S := Default(TWalkState);
    S.IdIndex := -1;
    S.Role := ewrBody;
    S.Size := 1;
    S.Align := etaInherit;
    // the body's own style (a book may centre or indent everything)
    if AStyles <> nil then
    begin
      Css := AStyles.StyleOf(ABody.LocalName, ABody.Attr('class'), ABody.Attr('id'), ABody.Attr('style'));
      if Css.Align <> etaInherit then
        S.Align := Css.Align;
      if not IsNan(Css.TextIndent) then
        S.TextIndent := Css.TextIndent;
      if Css.Italic = efOn then
        Include(S.Styles, ersItalic);
    end;
    W.NextKind := ebkParagraph;
    W.NextState := S;
    W.Walk(ABody, S);
    W.CloseBlock;
  finally
    W.Free;
  end;
  SetLength(FWords, FWordCount);
  SetLength(FBlocks, FBlockCount);
end;

function TEpubDocLayout.GetWords: TEpubLayoutWordArray;
begin
  Result := FWords;
end;

function TEpubDocLayout.GetBlocks: TEpubBlockArray;
begin
  Result := FBlocks;
end;

function TEpubDocLayout.IndexOfId(const AId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FIds) do
    if FIds[I].Id = AId then
      Exit(I);
  Result := -1;
end;

end.
