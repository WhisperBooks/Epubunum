(* @abstract(A small, tolerant XML / XHTML parser for EPUB files: the
  container, the package (OPF), navigation (nav, NCX), media overlays (SMIL)
  and the content documents.)

  EPUB 3 content must be well-formed XML, but books in the wild - EPUB 2
  above all - carry HTML habits: named entities (&nbsp; &mdash; ...), void
  elements left open (<br>, <img>), stray or missing end tags. The parser
  never fails on those: it recovers the way a browser would and keeps going.
  Namespaces are kept as written (Name = 'epub:type'); look elements and
  attributes up by local name (@link(TEpubXmlNode.Attr),
  @link(TEpubXmlNode.FindAll)).

  Framework-free; compiles with Delphi and FPC. *)
unit Epub.Xml;

{$I Epub.inc}

interface

uses
  SysUtils, Classes;

type
  { What a node is. }
  TEpubXmlNodeKind = (xnElement, xnText);

  TEpubXmlNode = class;
  { Child nodes, in document order. }
  TEpubXmlNodeArray = array of TEpubXmlNode;

  { One attribute: name as written, value with entities resolved. }
  TEpubXmlAttr = record
    { Name as written ('id', 'epub:type', 'xml:lang'). }
    Name: string;
    { Value, entities resolved. }
    Value: string;
  end;
  { Attributes in document order. }
  TEpubXmlAttrArray = array of TEpubXmlAttr;

  { An element or a run of text. Owned by its parent (the root by the
    document). }
  TEpubXmlNode = class
  private
    { Backing field of @link(Kind). }
    FKind: TEpubXmlNodeKind;
    { Backing field of @link(Name). }
    FName: string;
    { LocalName, made on first use (the walker and FindAll ask for it for
      every element, often more than once). }
    FLocal: string;
    { Backing field of @link(Text). }
    FText: string;
    { Backing field of @link(Attrs). }
    FAttrs: TEpubXmlAttrArray;
    { Backing field of @link(Children). }
    FChildren: TEpubXmlNodeArray;
    { Number of children in use. }
    FCount: Integer;
    { Backing field of @link(Parent). }
    FParent: TEpubXmlNode;
    { Backing field of @link(SrcPos). }
    FSrcPos: Integer;
    { Backing field of @link(SrcLen). }
    FSrcLen: Integer;
    { Backing field of @link(SrcEnd). }
    FSrcEnd: Integer;
    { Backing field of @link(CData). }
    FCData: Boolean;
    { The children: the node's own array, trimmed to FCount on the first
      read (no copy per read). }
    function GetChildren: TEpubXmlNodeArray;
    { Adds AChild (taking ownership). }
    procedure AddChild(AChild: TEpubXmlNode);
    { Collects the descendant elements named ALocal into AList. }
    procedure Collect(const ALocal: string; var AList: TEpubXmlNodeArray; var ACount: Integer);
  public
    { A node of AKind; AName for an element, text for a text node. }
    constructor Create(AKind: TEpubXmlNodeKind; const ANameOrText: string);
    { Frees the children. }
    destructor Destroy; override;
    { Name without its prefix ('type' for 'epub:type'), lower case for
      HTML-tolerant comparison. }
    function LocalName: string;
    { Value of the attribute whose local name is ALocal (case ignored); ''
      when absent. 'type' finds 'epub:type'; a full name ('epub:type') is
      matched as written first. }
    function Attr(const ALocal: string): string;
    { True when the attribute is present (see @link(Attr)). }
    function HasAttr(const ALocal: string): Boolean;
    { The first child element named ALocal (local name, case ignored), or nil. }
    function Child(const ALocal: string): TEpubXmlNode;
    { Every descendant element named ALocal, in document order. }
    function FindAll(const ALocal: string): TEpubXmlNodeArray;
    { The first descendant element named ALocal, or nil. }
    function Find(const ALocal: string): TEpubXmlNode;
    { All text inside, concatenated (whitespace as written). }
    function InnerText: string;
    { Element or text. }
    property Kind: TEpubXmlNodeKind read FKind;
    { Element name as written (with any prefix). }
    property Name: string read FName;
    { Text of a text node (entities resolved). }
    property Text: string read FText;
    { Attributes of an element. }
    property Attrs: TEpubXmlAttrArray read FAttrs;
    { Child nodes (the node's own array: read it, do not change it). }
    property Children: TEpubXmlNodeArray read GetChildren;
    { Number of child nodes. }
    property ChildCount: Integer read FCount;
    { The parent (nil for the root). }
    property Parent: TEpubXmlNode read FParent;
    { Where the node is in @link(TEpubXmlDoc.Source) (1-based): for an
      element the '<' of its start tag, for text the first character as
      written (entities not resolved; for CDATA the first character inside
      it). 0 for the synthetic root. }
    property SrcPos: Integer read FSrcPos;
    { Length in the source: of the start tag ('<' to '>') for an element,
      of the text as written for a text node. }
    property SrcLen: Integer read FSrcLen;
    { For an element: the position just after its end tag (after the start
      tag when it is empty or void); 0 when the parser closed it as a
      repair. }
    property SrcEnd: Integer read FSrcEnd;
    { A text node from a CDATA section (its source is not entity-encoded). }
    property CData: Boolean read FCData;
  end;

  { A parsed document. }
  TEpubXmlDoc = class
  private
    { Backing field of @link(Root). }
    FRoot: TEpubXmlNode;
    { Backing field of @link(Repaired). }
    FRepaired: Integer;
    { Backing field of @link(Source). }
    FSource: string;
  public
    { Parses AText (tolerant; never raises for malformed markup).
      @param(AHtml  Treat it as XHTML: HTML void elements need no end tag,
        and an end tag closes the nearest open element of that name.) }
    constructor Create(const AText: string; AHtml: Boolean = False);
    { Frees the tree. }
    destructor Destroy; override;
    { The document element (nil when there is none). }
    function DocumentElement: TEpubXmlNode;
    { A synthetic root holding everything parsed (the document element and
      any stray top-level text). }
    property Root: TEpubXmlNode read FRoot;
    { How many repairs were made (unclosed or stray tags): 0 for
      well-formed input. }
    property Repaired: Integer read FRepaired;
    { The text that was parsed (node positions point into it). }
    property Source: string read FSource;
  end;

{ AText with XML / HTML entities resolved (&amp; &#233; &#xE9; &nbsp; ...;
  an unknown entity is kept as written). }
function EpubXmlDecode(const AText: string): string;
{ AText escaped for XML text or an attribute value (& < > "). }
function EpubXmlEscape(const AText: string): string;
{ AText with the named HTML entities (&nbsp; &mdash; ...) written as
  character references (&#160;): XHTML with the HTML5 doctype (EPUB 3)
  knows only the XML five, which stay. Unknown names stay as written. }
function EpubXmlNumericEntities(const AText: string): string;
{ Where character ADecoded (1-based) of EpubXmlDecode(ARaw) starts in ARaw;
  Length(ARaw) + 1 for ADecoded past the end. Maps a place in a text
  node's @link(TEpubXmlNode.Text) back to the source. }
function EpubXmlRawIndex(const ARaw: string; ADecoded: Integer): Integer;
{ The local part of a qualified name ('type' for 'epub:type'), lower case. }
function EpubLocalName(const AName: string): string;

implementation

type
  { A named HTML entity. }
  TEntity = record
    { Name without & and ;. }
    Name: string;
    { Unicode code point. }
    Code: Integer;
  end;

const
  { The HTML entities seen in EPUB 2 books (the XML five included). }
  ENTITIES: array[0..47] of TEntity = (
    (Name: 'amp'; Code: 38), (Name: 'lt'; Code: 60), (Name: 'gt'; Code: 62),
    (Name: 'quot'; Code: 34), (Name: 'apos'; Code: 39), (Name: 'nbsp'; Code: 160),
    (Name: 'mdash'; Code: 8212), (Name: 'ndash'; Code: 8211), (Name: 'hellip'; Code: 8230),
    (Name: 'lsquo'; Code: 8216), (Name: 'rsquo'; Code: 8217), (Name: 'ldquo'; Code: 8220),
    (Name: 'rdquo'; Code: 8221), (Name: 'sbquo'; Code: 8218), (Name: 'bdquo'; Code: 8222),
    (Name: 'copy'; Code: 169), (Name: 'reg'; Code: 174), (Name: 'trade'; Code: 8482),
    (Name: 'shy'; Code: 173), (Name: 'thinsp'; Code: 8201), (Name: 'ensp'; Code: 8194),
    (Name: 'emsp'; Code: 8195), (Name: 'zwnj'; Code: 8204), (Name: 'zwj'; Code: 8205),
    (Name: 'eacute'; Code: 233), (Name: 'egrave'; Code: 232), (Name: 'ecirc'; Code: 234),
    (Name: 'euml'; Code: 235), (Name: 'aacute'; Code: 225), (Name: 'agrave'; Code: 224),
    (Name: 'acirc'; Code: 226), (Name: 'auml'; Code: 228), (Name: 'iacute'; Code: 237),
    (Name: 'iuml'; Code: 239), (Name: 'oacute'; Code: 243), (Name: 'ocirc'; Code: 244),
    (Name: 'ouml'; Code: 246), (Name: 'uacute'; Code: 250), (Name: 'uuml'; Code: 252),
    (Name: 'ccedil'; Code: 231), (Name: 'ntilde'; Code: 241), (Name: 'szlig'; Code: 223),
    (Name: 'aelig'; Code: 230), (Name: 'oelig'; Code: 339), (Name: 'pound'; Code: 163),
    (Name: 'euro'; Code: 8364), (Name: 'middot'; Code: 183), (Name: 'bull'; Code: 8226));

  { HTML elements that never have content (no end tag needed in XHTML-ish
    input). }
  VOID_ELEMENTS: array[0..13] of string = ('area', 'base', 'br', 'col', 'embed', 'hr', 'img',
    'input', 'link', 'meta', 'param', 'source', 'track', 'wbr');

{ Code point ACode as a string (a surrogate pair above $FFFF where strings
  are UTF-16; UTF-8 bytes where they are 8-bit, as with FPC). }
function CodeText(ACode: Integer): string;
var
  W: UnicodeString;
  {$ifdef FPC}
  U: RawByteString;
  {$endif}
begin
  if (ACode < 0) or (ACode > $10FFFF) then
    ACode := $FFFD;
  if ACode > $FFFF then
  begin
    Dec(ACode, $10000);
    W := WideChar($D800 + (ACode shr 10)) + WideChar($DC00 + (ACode and $3FF));
  end
  else
    W := WideChar(ACode);
  {$ifdef FPC}
  // copied as bytes: an assignment would convert through the system code
  // page (lossy when it is not UTF-8)
  U := UTF8Encode(W);
  SetLength(Result, Length(U));
  if Length(U) > 0 then
    Move(U[1], Result[1], Length(U));
  {$else}
  Result := W;
  {$endif}
end;

function EpubLocalName(const AName: string): string;
var
  P: Integer;
begin
  P := LastDelimiter(':', AName);
  Result := LowerCase(Copy(AName, P + 1, MaxInt));
end;

{ Reads the entity at AText[AI] ('&'). Returns 2 when it is a known
  entity ending at AEnd (the ';') with code point ACode, 1 when it ends at
  AEnd but is unknown (kept as written), 0 for a bare '&'. }
function ScanEntity(const AText: string; AI, AN: Integer; out AEnd, ACode: Integer): Integer;
var
  J, K: Integer;
  Ent: string;
  Found: Boolean;
begin
  ACode := 0;
  J := AI + 1;
  while (J <= AN) and (J - AI <= 12) and (AText[J] <> ';') and (AText[J] <> '&') and (AText[J] > ' ') do
    Inc(J);
  AEnd := J;
  if (J > AN) or (AText[J] <> ';') then
    Exit(0);   // a bare '&': keep it
  Ent := Copy(AText, AI + 1, J - AI - 1);
  Found := False;
  if (Length(Ent) > 1) and (Ent[1] = '#') then
  begin
    if (Ent[2] = 'x') or (Ent[2] = 'X') then
      Found := TryStrToInt('$' + Copy(Ent, 3, MaxInt), ACode)
    else
      Found := TryStrToInt(Copy(Ent, 2, MaxInt), ACode);
  end
  else
    for K := 0 to High(ENTITIES) do
      if ENTITIES[K].Name = Ent then
      begin
        ACode := ENTITIES[K].Code;
        Found := True;
        Break;
      end;
  if Found then
    Result := 2
  else
    Result := 1;
end;

function EpubXmlDecode(const AText: string): string;
var
  I, J, N, Code, Run: Integer;
begin
  if Pos('&', AText) = 0 then
    Exit(AText);
  Result := '';
  N := Length(AText);
  I := 1;
  Run := 1;
  while I <= N do
  begin
    if AText[I] <> '&' then
    begin
      Inc(I);
      Continue;
    end;
    case ScanEntity(AText, I, N, J, Code) of
      0:
        Inc(I);
      1:
        I := J + 1;
    else
      Result := Result + Copy(AText, Run, I - Run) + CodeText(Code);
      Run := J + 1;
      I := J + 1;
    end;
  end;
  Result := Result + Copy(AText, Run, MaxInt);
end;

function EpubXmlNumericEntities(const AText: string): string;
var
  I, J, N, K, Run: Integer;
  Ent: string;
begin
  if Pos('&', AText) = 0 then
    Exit(AText);
  Result := '';
  N := Length(AText);
  I := 1;
  Run := 1;
  while I <= N do
  begin
    if AText[I] <> '&' then
    begin
      Inc(I);
      Continue;
    end;
    J := I + 1;
    while (J <= N) and (J - I <= 12) and CharInSet(AText[J], ['a'..'z', 'A'..'Z', '0'..'9']) do
      Inc(J);
    if (J <= N) and (AText[J] = ';') and (J > I + 1) then
    begin
      Ent := Copy(AText, I + 1, J - I - 1);
      // ENTITIES[0..4] are the XML five
      for K := 5 to High(ENTITIES) do
        if ENTITIES[K].Name = Ent then
        begin
          Result := Result + Copy(AText, Run, I - Run) + '&#' + IntToStr(ENTITIES[K].Code) + ';';
          Run := J + 1;
          Break;
        end;
    end;
    I := J;
  end;
  Result := Result + Copy(AText, Run, MaxInt);
end;

function EpubXmlRawIndex(const ARaw: string; ADecoded: Integer): Integer;
var
  I, J, N, Code, C, L: Integer;
begin
  if Pos('&', ARaw) = 0 then
  begin
    if ADecoded > Length(ARaw) then
      Exit(Length(ARaw) + 1);
    Exit(ADecoded);
  end;
  N := Length(ARaw);
  I := 1;
  C := 0;   // decoded characters before ARaw[I]
  while I <= N do
  begin
    // the same steps as EpubXmlDecode: a known entity is one unit
    if (ARaw[I] = '&') and (ScanEntity(ARaw, I, N, J, Code) = 2) then
    begin
      L := Length(CodeText(Code));
      if ADecoded <= C + L then
        Exit(I);
      Inc(C, L);
      I := J + 1;
      Continue;
    end;
    if ADecoded = C + 1 then
      Exit(I);
    Inc(C);
    Inc(I);
  end;
  Result := N + 1;
end;

function EpubXmlEscape(const AText: string): string;
begin
  Result := StringReplace(AText, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

{ TEpubXmlNode }

constructor TEpubXmlNode.Create(AKind: TEpubXmlNodeKind; const ANameOrText: string);
begin
  inherited Create;
  FKind := AKind;
  if AKind = xnElement then
    FName := ANameOrText
  else
    FText := ANameOrText;
end;

destructor TEpubXmlNode.Destroy;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    FChildren[I].Free;
  inherited;
end;

function TEpubXmlNode.GetChildren: TEpubXmlNodeArray;
begin
  // Not a copy: Children[I] in a loop over ChildCount copied every child
  // pointer once per child (a body of 50 000 nodes: 20 GB moved per walk).
  // The spare room AddChild left is cut off once; AddChild grows it again
  // if the parser is still adding.
  if Length(FChildren) <> FCount then
    SetLength(FChildren, FCount);
  Result := FChildren;
end;

procedure TEpubXmlNode.AddChild(AChild: TEpubXmlNode);
begin
  if FCount = Length(FChildren) then
    SetLength(FChildren, FCount * 2 + 4);
  FChildren[FCount] := AChild;
  Inc(FCount);
  AChild.FParent := Self;
end;

function TEpubXmlNode.LocalName: string;
begin
  if (FLocal = '') and (FName <> '') then
    FLocal := EpubLocalName(FName);
  Result := FLocal;
end;

function TEpubXmlNode.Attr(const ALocal: string): string;
var
  I: Integer;
  L: string;
begin
  for I := 0 to High(FAttrs) do
    if SameText(FAttrs[I].Name, ALocal) then
      Exit(FAttrs[I].Value);
  if Pos(':', ALocal) = 0 then
  begin
    L := LowerCase(ALocal);
    for I := 0 to High(FAttrs) do
      if EpubLocalName(FAttrs[I].Name) = L then
        Exit(FAttrs[I].Value);
  end;
  Result := '';
end;

function TEpubXmlNode.HasAttr(const ALocal: string): Boolean;
var
  I: Integer;
  L: string;
begin
  L := LowerCase(ALocal);
  for I := 0 to High(FAttrs) do
    if SameText(FAttrs[I].Name, ALocal) or (EpubLocalName(FAttrs[I].Name) = L) then
      Exit(True);
  Result := False;
end;

function TEpubXmlNode.Child(const ALocal: string): TEpubXmlNode;
var
  I: Integer;
  L: string;
begin
  L := LowerCase(ALocal);
  for I := 0 to FCount - 1 do
    if (FChildren[I].FKind = xnElement) and (FChildren[I].LocalName = L) then
      Exit(FChildren[I]);
  Result := nil;
end;

procedure TEpubXmlNode.Collect(const ALocal: string; var AList: TEpubXmlNodeArray; var ACount: Integer);
var
  I: Integer;
  C: TEpubXmlNode;
begin
  for I := 0 to FCount - 1 do
  begin
    C := FChildren[I];
    if C.FKind <> xnElement then
      Continue;
    if (ALocal = '') or (C.LocalName = ALocal) then
    begin
      if ACount = Length(AList) then
        SetLength(AList, ACount * 2 + 8);
      AList[ACount] := C;
      Inc(ACount);
    end;
    C.Collect(ALocal, AList, ACount);
  end;
end;

function TEpubXmlNode.FindAll(const ALocal: string): TEpubXmlNodeArray;
var
  N: Integer;
begin
  Result := nil;
  N := 0;
  Collect(LowerCase(ALocal), Result, N);
  SetLength(Result, N);
end;

function TEpubXmlNode.Find(const ALocal: string): TEpubXmlNode;
var
  A: TEpubXmlNodeArray;
begin
  A := FindAll(ALocal);
  if Length(A) > 0 then
    Result := A[0]
  else
    Result := nil;
end;

function TEpubXmlNode.InnerText: string;
var
  I: Integer;
begin
  if FKind = xnText then
    Exit(FText);
  Result := '';
  for I := 0 to FCount - 1 do
    Result := Result + FChildren[I].InnerText;
end;

{ TEpubXmlDoc }

{ True when ALocal is an HTML void element. }
function IsVoid(const ALocal: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(VOID_ELEMENTS) do
    if VOID_ELEMENTS[I] = ALocal then
      Exit(True);
  Result := False;
end;

constructor TEpubXmlDoc.Create(const AText: string; AHtml: Boolean);
var
  N, I, J, K, Q, TagStart: Integer;
  Cur, E, P: TEpubXmlNode;
  Tag, NameS, AName, AValue: string;
  SelfClose: Boolean;
  Quote: Char;

  procedure AddText(APos, ALen: Integer);
  var
    T: TEpubXmlNode;
  begin
    if ALen <= 0 then
      Exit;
    T := TEpubXmlNode.Create(xnText, EpubXmlDecode(Copy(AText, APos, ALen)));
    T.FSrcPos := APos;
    T.FSrcLen := ALen;
    Cur.AddChild(T);
  end;

  function IsNameChar(C: Char): Boolean;
  begin
    Result := not CharInSet(C, [' ', #9, #10, #13, '/', '>', '=']);
  end;

begin
  inherited Create;
  FSource := AText;
  FRoot := TEpubXmlNode.Create(xnElement, '#document');
  Cur := FRoot;
  N := Length(AText);
  I := 1;
  while I <= N do
  begin
    if AText[I] <> '<' then
    begin
      J := I;
      while (J <= N) and (AText[J] <> '<') do
        Inc(J);
      if Cur <> FRoot then
        AddText(I, J - I);
      I := J;
      Continue;
    end;
    // comment, CDATA, doctype, processing instruction
    if Copy(AText, I, 4) = '<!--' then
    begin
      J := Pos('-->', Copy(AText, I + 4, MaxInt));
      if J = 0 then
        Break;
      I := I + 4 + J + 2;
      Continue;
    end;
    if Copy(AText, I, 9) = '<![CDATA[' then
    begin
      J := Pos(']]>', Copy(AText, I + 9, MaxInt));
      if J = 0 then
        J := N - I - 8 + 1;
      E := TEpubXmlNode.Create(xnText, Copy(AText, I + 9, J - 1));
      E.FSrcPos := I + 9;
      E.FSrcLen := J - 1;
      E.FCData := True;
      Cur.AddChild(E);
      I := I + 9 + J + 2;
      Continue;
    end;
    if (Copy(AText, I, 2) = '<!') or (Copy(AText, I, 2) = '<?') then
    begin
      J := I;
      while (J <= N) and (AText[J] <> '>') do
        Inc(J);
      I := J + 1;
      Continue;
    end;
    // a tag: find its end, respecting quoted attribute values
    J := I + 1;
    Quote := #0;
    while J <= N do
    begin
      if Quote <> #0 then
      begin
        if AText[J] = Quote then
          Quote := #0;
      end
      else if (AText[J] = '"') or (AText[J] = '''') then
        Quote := AText[J]
      else if AText[J] = '>' then
        Break;
      Inc(J);
    end;
    Tag := Copy(AText, I + 1, J - I - 1);
    TagStart := I;
    I := J + 1;
    if Tag = '' then
      Continue;
    if Tag[1] = '/' then
    begin
      // end tag: close the nearest open element of that name
      NameS := LowerCase(Trim(Copy(Tag, 2, MaxInt)));
      P := Cur;
      while (P <> FRoot) and (LowerCase(P.FName) <> NameS) do
        P := P.FParent;
      if P = FRoot then
        Inc(FRepaired)   // stray end tag: ignored
      else
      begin
        if P <> Cur then
          Inc(FRepaired);  // elements left open inside it are closed too
        P.FSrcEnd := I;
        Cur := P.FParent;
      end;
      Continue;
    end;
    // start tag
    SelfClose := (Length(Tag) > 0) and (Tag[Length(Tag)] = '/');
    if SelfClose then
      SetLength(Tag, Length(Tag) - 1);
    K := 1;
    while (K <= Length(Tag)) and IsNameChar(Tag[K]) do
      Inc(K);
    NameS := Copy(Tag, 1, K - 1);
    E := TEpubXmlNode.Create(xnElement, NameS);
    E.FSrcPos := TagStart;
    E.FSrcLen := I - TagStart;
    // attributes
    while K <= Length(Tag) do
    begin
      while (K <= Length(Tag)) and CharInSet(Tag[K], [' ', #9, #10, #13]) do
        Inc(K);
      Q := K;
      while (K <= Length(Tag)) and IsNameChar(Tag[K]) do
        Inc(K);
      AName := Copy(Tag, Q, K - Q);
      if AName = '' then
      begin
        Inc(K);
        Continue;
      end;
      while (K <= Length(Tag)) and CharInSet(Tag[K], [' ', #9, #10, #13]) do
        Inc(K);
      AValue := '';
      if (K <= Length(Tag)) and (Tag[K] = '=') then
      begin
        Inc(K);
        while (K <= Length(Tag)) and CharInSet(Tag[K], [' ', #9, #10, #13]) do
          Inc(K);
        if (K <= Length(Tag)) and ((Tag[K] = '"') or (Tag[K] = '''')) then
        begin
          Quote := Tag[K];
          Inc(K);
          Q := K;
          while (K <= Length(Tag)) and (Tag[K] <> Quote) do
            Inc(K);
          AValue := Copy(Tag, Q, K - Q);
          Inc(K);
        end
        else
        begin
          Q := K;
          while (K <= Length(Tag)) and not CharInSet(Tag[K], [' ', #9, #10, #13]) do
            Inc(K);
          AValue := Copy(Tag, Q, K - Q);
        end;
      end;
      SetLength(E.FAttrs, Length(E.FAttrs) + 1);
      E.FAttrs[High(E.FAttrs)].Name := AName;
      E.FAttrs[High(E.FAttrs)].Value := EpubXmlDecode(AValue);
    end;
    Cur.AddChild(E);
    if not SelfClose and not (AHtml and IsVoid(E.LocalName)) then
      Cur := E
    else
      E.FSrcEnd := I;
  end;
  if Cur <> FRoot then
    Inc(FRepaired);   // unclosed at the end
end;

destructor TEpubXmlDoc.Destroy;
begin
  FRoot.Free;
  inherited;
end;

function TEpubXmlDoc.DocumentElement: TEpubXmlNode;
begin
  Result := FRoot.Child('');
  if Result = nil then
  begin
    // Child('') matches no name; take the first element instead
    Result := nil;
    if FRoot.FCount > 0 then
    begin
      Result := FRoot.FChildren[0];
      if Result.FKind <> xnElement then
        Result := nil;
    end;
  end;
end;

end.
