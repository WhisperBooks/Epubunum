(* @abstract(MOBI to EPUB 3: a DRM-free Mobipocket / Kindle book
  (@code(.mobi), @code(.prc), @code(.azw)) written as an EPUB 3 that
  @link(TEpubBook) reads - so a MOBI can be built into a read-along book.)

  What is read (owner, 2026-11-20: "Can we transcribe mobi -> epub3?"):
  @unorderedList(
    @item(the Palm database and the MOBI header: text encoding (UTF-8 or
      Windows-1252), the text records, the first picture record;)
    @item(the text: PalmDOC compression (or none), each record's trailing
      entries taken off;)
    @item(EXTH metadata: title (503), authors (100), language (524),
      publisher (101), description (103), ISBN (104), date (106), cover
      (201);)
    @item(the old MOBI 6 HTML: split into documents at
      @code(<mbp:pagebreak>), made well-formed XHTML (tags closed, Kindle
      tags dropped, @code(align) / @code(width) / @code(height) made
      styles, entities decoded), @code(filepos) links turned into links
      to anchors, @code(recindex) pictures into image files;)
    @item(a book with both MOBI 6 and KF8 (most since 2012) is read from
      its MOBI 6 part.))

  Refused with a message (EEpubError), never worked around:
  @unorderedList(
    @item(copy protection (DRM: the header's encryption is not 0) - such
      books are never decrypted;)
    @item(Huffman (HUFF/CDIC) compression, and KF8-only books (AZW3) - not
      read yet.))

  Framework-free; compiles with Delphi and FPC. *)
unit Epub.Mobi;

{$I Epub.inc}

interface

uses
  SysUtils, Classes, Epub.Zip;

type
  { What MobiToEpub read and wrote. }
  TMobiInfo = record
    { The book's title. }
    Title: string;
    { Its authors, ' & ' between them ('' when not given). }
    Author: string;
    { Its language (BCP 47 as in the file; 'und' when not given). }
    Language: string;
    { 'MOBI 6', 'MOBI 6 (the file also holds KF8)' or 'PalmDOC text'. }
    Kind: string;
    { Documents written. }
    Documents: Integer;
    { Pictures written. }
    Pictures: Integer;
    { A cover picture was found. }
    HasCover: Boolean;
  end;

{ The file is a Mobipocket / Kindle book (a Palm database of type
  BOOKMOBI, or TEXtREAd), whatever its name.
  @param(AFileName  the file)
  @returns(True for a MOBI; False otherwise or when it cannot be read) }
function MobiIsMobi(const AFileName: string): Boolean;

{ Writes the MOBI AMobiFile as the EPUB 3 AEpubFile (overwritten). Raises
  EEpubError for a book it cannot read (DRM, Huffman compression, KF8
  only, not a MOBI).
  @param(AMobiFile  the MOBI)
  @param(AEpubFile  the EPUB to write)
  @param(AInfo  what was read and written) }
procedure MobiToEpub(const AMobiFile, AEpubFile: string; out AInfo: TMobiInfo);

{ AInfo in one line, for a log.
  @param(AInfo  MobiToEpub's)
  @returns(the line) }
function MobiInfoText(const AInfo: TMobiInfo): string;

implementation

type
  { A growing string: Add appends without copying the whole each time. }
  TMobiBuf = record
    { The text, longer than used. }
    Text: string;
    { The characters used. }
    Len: Integer;
  end;

  { One picture record of the book. }
  TMobiPicture = record
    { Its recindex (1 = the first picture record). }
    Index: Integer;
    { Its bytes. }
    Data: TBytes;
    { 'jpg', 'png', 'gif' or 'bmp'. }
    Ext: string;
    { It is used (a picture in the text, or the cover). }
    Used: Boolean;
  end;

  { The book's pictures. }
  TMobiPictureArray = array of TMobiPicture;

  { One document to write. }
  TMobiDoc = record
    { Its XHTML body. }
    Body: string;
    { Its title (for the contents). }
    Title: string;
  end;

  { The documents. }
  TMobiDocArray = array of TMobiDoc;

const
  { Windows-1252's characters for bytes $80 - $9F (0 = none). }
  CP1252_HIGH: array[$80..$9F] of Word = (
    $20AC, 0, $201A, $0192, $201E, $2026, $2020, $2021, $02C6, $2030, $0160, $2039, $0152, 0, $017D, 0,
    0, $2018, $2019, $201C, $201D, $2022, $2013, $2014, $02DC, $2122, $0161, $203A, $0153, 0, $017E, $0178);

  { Named entities decoded in the text (the rest of HTML's are kept as
    they were, escaped): name and character. }
  ENTITY_NAMES: array[0..65] of string = (
    'amp', 'lt', 'gt', 'quot', 'apos', 'nbsp', 'mdash', 'ndash', 'hellip', 'lsquo', 'rsquo', 'ldquo',
    'rdquo', 'sbquo', 'bdquo', 'copy', 'reg', 'trade', 'deg', 'middot', 'bull', 'laquo', 'raquo', 'iexcl',
    'iquest', 'sect', 'para', 'dagger', 'Dagger', 'shy', 'times', 'divide', 'frac12', 'frac14', 'frac34',
    'eacute', 'egrave', 'ecirc', 'euml', 'aacute', 'agrave', 'acirc', 'auml', 'aring', 'iacute', 'iuml',
    'oacute', 'ocirc', 'ouml', 'uacute', 'ugrave', 'uuml', 'ccedil', 'ntilde', 'szlig', 'Eacute', 'Agrave',
    'Ccedil', 'aelig', 'oslash', 'pound', 'euro', 'yen', 'cent', 'thinsp', 'ensp');
  { The characters of ENTITY_NAMES. }
  ENTITY_CHARS: array[0..65] of Word = (
    38, 60, 62, 34, 39, $A0, $2014, $2013, $2026, $2018, $2019, $201C,
    $201D, $201A, $201E, $A9, $AE, $2122, $B0, $B7, $2022, $AB, $BB, $A1,
    $BF, $A7, $B6, $2020, $2021, $AD, $D7, $F7, $BD, $BC, $BE,
    $E9, $E8, $EA, $EB, $E1, $E0, $E2, $E4, $E5, $ED, $EF,
    $F3, $F4, $F6, $FA, $F9, $FC, $E7, $F1, $DF, $C9, $C0,
    $C7, $E6, $F8, $A3, $20AC, $A5, $A2, $2009, $2002);

  { Elements kept (others are dropped, their text kept). }
  KEEP_TAGS: array[0..32] of string = (
    'p', 'div', 'span', 'br', 'hr', 'b', 'i', 'u', 'em', 'strong', 'sub', 'sup', 'small', 'blockquote',
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'table', 'tbody', 'thead', 'tr', 'td', 'th', 'a',
    'img', 's', 'code');
  { Old elements written as another: from. }
  MAP_FROM: array[0..9] of string = ('center', 'font', 'big', 'tt', 'strike', 'del', 'ins', 'cite', 'pre',
    'q');
  { Old elements written as another: to (MAP_FROM's). }
  MAP_TO: array[0..9] of string = ('div', 'span', 'span', 'code', 's', 's', 'u', 'i', 'div', 'span');
  { Elements opening a block: an open p is closed first (HTML's rule). }
  BLOCK_TAGS: array[0..13] of string = ('p', 'div', 'blockquote', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul',
    'ol', 'table', 'hr', 'center');

  { The longest title of a document in the contents, characters. }
  TITLE_MAX = 60;

{ Adds AText to AB. }
procedure BufAdd(var AB: TMobiBuf; const AText: string);
var
  N: Integer;
begin
  N := Length(AText);
  if N = 0 then
    Exit;
  if AB.Len + N > Length(AB.Text) then
    SetLength(AB.Text, (AB.Len + N) * 2 + 256);
  Move(AText[1], AB.Text[AB.Len + 1], N * SizeOf(Char));
  Inc(AB.Len, N);
end;

{ AB's text. }
function BufText(const AB: TMobiBuf): string;
begin
  Result := Copy(AB.Text, 1, AB.Len);
end;

{ Big-endian 16 bits of AB at AP (0-based); 0 past the end. }
function Be16(const AB: TBytes; AP: Integer): Cardinal;
begin
  if (AP < 0) or (AP + 2 > Length(AB)) then
    Exit(0);
  Result := (Cardinal(AB[AP]) shl 8) or AB[AP + 1];
end;

{ Big-endian 32 bits of AB at AP (0-based); 0 past the end. }
function Be32(const AB: TBytes; AP: Integer): Cardinal;
begin
  if (AP < 0) or (AP + 4 > Length(AB)) then
    Exit(0);
  Result := (Cardinal(AB[AP]) shl 24) or (Cardinal(AB[AP + 1]) shl 16) or (Cardinal(AB[AP + 2]) shl 8) or
    AB[AP + 3];
end;

{ The 4 bytes of AB at AP as text ('' past the end). }
function Tag4(const AB: TBytes; AP: Integer): string;
var
  I: Integer;
begin
  Result := '';
  if (AP < 0) or (AP + 4 > Length(AB)) then
    Exit;
  for I := 0 to 3 do
    Result := Result + Char(AB[AP + I]);
end;

{ The character with code point ACode as a string (two UTF-16 units above
  $FFFF). }
function CodeChar(ACode: Cardinal): string;
begin
  if ACode > $FFFF then
  begin
    Dec(ACode, $10000);
    Result := Char($D800 + (ACode shr 10)) + Char($DC00 + (ACode and $3FF));
  end
  else
    Result := Char(ACode);
end;

{ ACount bytes of AB from AP decoded: UTF-8 when AUtf8, else
  Windows-1252. }
function DecodeBytes(const AB: TBytes; AP, ACount: Integer; AUtf8: Boolean): string;
var
  Part: TBytes;
  I: Integer;
  W: Word;
  Buf: TMobiBuf;
begin
  if ACount <= 0 then
    Exit('');
  if AUtf8 then
  begin
    SetLength(Part, ACount);
    Move(AB[AP], Part[0], ACount);
    Exit(EpubBytesText(Part));
  end;
  Buf.Len := 0;
  SetLength(Buf.Text, ACount);
  for I := AP to AP + ACount - 1 do
  begin
    W := AB[I];
    if (W >= $80) and (W <= $9F) then
    begin
      W := CP1252_HIGH[W];
      if W = 0 then
        Continue;
    end;
    BufAdd(Buf, Char(W));
  end;
  Result := BufText(Buf);
end;

{ A Palm database: its record offsets (one more than records: the file's
  end). }
type
  { Record start offsets, the last one the file's length. }
  TMobiOffsets = array of Cardinal;

{ The records' offsets of the database AB (raises when it is not one). }
function ReadOffsets(const AB: TBytes): TMobiOffsets;
var
  N, I: Integer;
begin
  if Length(AB) < 86 then
    raise EEpubError.Create('Not a MOBI book: the file is too short');
  N := Be16(AB, 76);
  if (N = 0) or (78 + N * 8 > Length(AB)) then
    raise EEpubError.Create('Not a MOBI book: its record list is damaged');
  SetLength(Result, N + 1);
  for I := 0 to N - 1 do
    Result[I] := Be32(AB, 78 + I * 8);
  Result[N] := Length(AB);
  for I := 0 to N - 1 do
    if (Result[I] > Result[I + 1]) or (Result[I] > Cardinal(Length(AB))) then
      raise EEpubError.Create('Not a MOBI book: its records are out of order');
end;

{ Record AIndex of AB (its bytes). }
function RecordBytes(const AB: TBytes; const AOff: TMobiOffsets; AIndex: Integer): TBytes;
var
  N: Integer;
begin
  Result := nil;
  if (AIndex < 0) or (AIndex >= High(AOff)) then
    Exit;
  N := Integer(AOff[AIndex + 1] - AOff[AIndex]);
  SetLength(Result, N);
  if N > 0 then
    Move(AB[AOff[AIndex]], Result[0], N);
end;

{ The record ARec without its trailing entries (MOBI header's extra data
  flags AFlags: bit 0 multibyte characters, the others sized entries). }
function WithoutTrailing(const ARec: TBytes; AFlags: Cardinal): Integer;
var
  Size, Num, S, Bit, Res: Integer;
  F: Cardinal;
  V: Byte;
begin
  Size := Length(ARec);
  Num := 0;
  F := AFlags shr 1;
  while F <> 0 do
  begin
    if (F and 1) <> 0 then
    begin
      // a backward variable-width size at the end
      S := Size - Num;
      Bit := 0;
      Res := 0;
      while S > 0 do
      begin
        V := ARec[S - 1];
        Res := Res or ((V and $7F) shl Bit);
        Inc(Bit, 7);
        Dec(S);
        if ((V and $80) <> 0) or (Bit >= 28) then
          Break;
      end;
      Inc(Num, Res);
    end;
    F := F shr 1;
  end;
  if ((AFlags and 1) <> 0) and (Size - Num - 1 >= 0) then
    Inc(Num, (ARec[Size - Num - 1] and 3) + 1);
  Result := Size - Num;
  if Result < 0 then
    Result := 0;
end;

{ Unpacks ACount bytes of PalmDOC-compressed ARec, adding them to AOut
  (used AOutLen bytes, grown as needed). }
procedure PalmDocUnpack(const ARec: TBytes; ACount: Integer; var AOut: TBytes; var AOutLen: Integer);
var
  I, Dist, N, K: Integer;
  C: Cardinal;

  procedure Room(AMore: Integer);
  begin
    if AOutLen + AMore > Length(AOut) then
      SetLength(AOut, (AOutLen + AMore) * 2 + 4096);
  end;

begin
  I := 0;
  while I < ACount do
  begin
    C := ARec[I];
    Inc(I);
    if (C = 0) or ((C >= 9) and (C <= $7F)) then
    begin
      Room(1);
      AOut[AOutLen] := C;
      Inc(AOutLen);
    end
    else if C <= 8 then
    begin
      // C literal bytes
      Room(Integer(C));
      for K := 1 to Integer(C) do
        if I < ACount then
        begin
          AOut[AOutLen] := ARec[I];
          Inc(AOutLen);
          Inc(I);
        end;
    end
    else if C >= $C0 then
    begin
      // a space and a character
      Room(2);
      AOut[AOutLen] := 32;
      AOut[AOutLen + 1] := C xor $80;
      Inc(AOutLen, 2);
    end
    else
    begin
      // a copy from before: 11 bits back, 3 bits length (3 - 10)
      if I >= ACount then
        Break;
      C := (C shl 8) or ARec[I];
      Inc(I);
      Dist := (C shr 3) and $7FF;
      N := (C and 7) + 3;
      if (Dist = 0) or (Dist > AOutLen) then
        Continue;
      Room(N);
      for K := 1 to N do
      begin
        AOut[AOutLen] := AOut[AOutLen - Dist];
        Inc(AOutLen);
      end;
    end;
  end;
end;

{ The character of the entity AName ('' when not known): '#123',
  '#x7B' or a name of ENTITY_NAMES. }
function EntityChar(const AName: string): string;
var
  I: Integer;
  Code: Int64;
begin
  Result := '';
  if AName = '' then
    Exit;
  if AName[1] = '#' then
  begin
    if (Length(AName) > 1) and ((AName[2] = 'x') or (AName[2] = 'X')) then
      Code := StrToInt64Def('$' + Copy(AName, 3, 8), -1)
    else
      Code := StrToInt64Def(Copy(AName, 2, 9), -1);
    // XML's characters only
    if (Code = 9) or (Code = 10) or (Code = 13) or ((Code >= 32) and (Code <= $D7FF)) or
      ((Code >= $E000) and (Code <= $FFFD)) or ((Code >= $10000) and (Code <= $10FFFF)) then
      Result := CodeChar(Code);
    Exit;
  end;
  for I := 0 to High(ENTITY_NAMES) do
    if ENTITY_NAMES[I] = AName then
      Exit(Char(ENTITY_CHARS[I]));
end;

{ AText with its entities decoded (known ones; others kept as written). }
function DecodeEntities(const AText: string): string;
var
  Buf: TMobiBuf;
  I, J: Integer;
  C: string;
begin
  if Pos('&', AText) = 0 then
    Exit(AText);
  Buf.Len := 0;
  I := 1;
  while I <= Length(AText) do
  begin
    if AText[I] = '&' then
    begin
      J := I + 1;
      while (J <= Length(AText)) and (J - I <= 10) and (AText[J] <> ';') and (AText[J] <> '&') and
        (AText[J] > ' ') do
        Inc(J);
      if (J <= Length(AText)) and (AText[J] = ';') then
      begin
        C := EntityChar(Copy(AText, I + 1, J - I - 1));
        if C <> '' then
        begin
          BufAdd(Buf, C);
          I := J + 1;
          Continue;
        end;
      end;
    end;
    BufAdd(Buf, AText[I]);
    Inc(I);
  end;
  Result := BufText(Buf);
end;

{ AText for XML: & < > (and " when AQuote) escaped, characters XML does
  not allow left out. }
function XmlText(const AText: string; AQuote: Boolean): string;
var
  Buf: TMobiBuf;
  I: Integer;
  C: Char;
begin
  Buf.Len := 0;
  for I := 1 to Length(AText) do
  begin
    C := AText[I];
    case C of
      '&': BufAdd(Buf, '&amp;');
      '<': BufAdd(Buf, '&lt;');
      '>': BufAdd(Buf, '&gt;');
      '"':
        if AQuote then
          BufAdd(Buf, '&quot;')
        else
          BufAdd(Buf, C);
    else
      if (C >= ' ') or (C = #9) or (C = #10) or (C = #13) then
        BufAdd(Buf, C);
    end;
  end;
  Result := BufText(Buf);
end;

{ AName is in AList. }
function InList(const AName: string; const AList: array of string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(AList) do
    if AList[I] = AName then
      Exit(True);
  Result := False;
end;

{ The value of attribute AName in the attribute text AAttrs ('' when not
  there; AFound says whether it was). Values decoded. }
function AttrValue(const AAttrs, AName: string; out AFound: Boolean): string;
var
  I, J, N: Integer;
  K: string;
  Q: Char;
begin
  Result := '';
  AFound := False;
  N := Length(AAttrs);
  I := 1;
  while I <= N do
  begin
    while (I <= N) and not CharInSet(AAttrs[I], ['a'..'z', 'A'..'Z', '_', ':']) do
      Inc(I);
    J := I;
    while (J <= N) and CharInSet(AAttrs[J], ['a'..'z', 'A'..'Z', '0'..'9', '_', ':', '-', '.']) do
      Inc(J);
    if J = I then
      Break;
    K := LowerCase(Copy(AAttrs, I, J - I));
    I := J;
    while (I <= N) and (AAttrs[I] = ' ') do
      Inc(I);
    Result := '';
    if (I <= N) and (AAttrs[I] = '=') then
    begin
      Inc(I);
      while (I <= N) and CharInSet(AAttrs[I], [' ', #9, #10, #13]) do
        Inc(I);
      if (I <= N) and ((AAttrs[I] = '"') or (AAttrs[I] = '''')) then
      begin
        Q := AAttrs[I];
        J := I + 1;
        while (J <= N) and (AAttrs[J] <> Q) do
          Inc(J);
        Result := Copy(AAttrs, I + 1, J - I - 1);
        I := J + 1;
      end
      else
      begin
        J := I;
        while (J <= N) and not CharInSet(AAttrs[J], [' ', #9, #10, #13, '>']) do
          Inc(J);
        Result := Copy(AAttrs, I, J - I);
        I := J;
      end;
    end;
    if K = AName then
    begin
      AFound := True;
      Exit(DecodeEntities(Result));
    end;
  end;
  Result := '';
end;

{ A size from width / height ('0pt', '1em', '20', ...) as CSS ('' for
  none or nothing). }
function CssSize(const AValue: string): string;
var
  V: string;
  I: Integer;
begin
  V := LowerCase(Trim(AValue));
  Result := '';
  if V = '' then
    Exit;
  I := 1;
  while (I <= Length(V)) and CharInSet(V[I], ['0'..'9', '.', '-']) do
    Inc(I);
  if I = 1 then
    Exit;
  // '0', '0pt', '0.0em' say nothing
  if LastDelimiter('123456789', Copy(V, 1, I - 1)) = 0 then
    Exit;
  if I > Length(V) then
    Result := V + 'px'
  else if (Copy(V, I, 3) = 'pt') or (Copy(V, I, 3) = 'em') or (Copy(V, I, 3) = 'px') or (V[I] = '%') then
    Result := V;
end;

{ Makes the MOBI 6 HTML ASrc well-formed XHTML: kept elements closed and
  nested, the rest dropped (their text kept). Pictures by recindex get
  their file name from APictures (marked used); filepos links become
  '#fpN' (made links to documents later). }
function CleanHtml(const ASrc: string; var APictures: TMobiPictureArray): string;
var
  Buf: TMobiBuf;
  Stack: array of string;
  I, J, N, K, P, Rec: Integer;
  S, Name, Orig, Attrs, Style, Attr, V, Al: string;
  Closing, SelfClosing, Found: Boolean;

  procedure Push(const AName: string);
  begin
    SetLength(Stack, Length(Stack) + 1);
    Stack[High(Stack)] := AName;
  end;

  function Opened(const AName: string): Boolean;
  var
    X: Integer;
  begin
    for X := High(Stack) downto 0 do
      if Stack[X] = AName then
        Exit(True);
    Result := False;
  end;

  // closes the open elements down to (and with) AName
  procedure CloseTo(const AName: string);
  var
    T: string;
  begin
    while Length(Stack) > 0 do
    begin
      T := Stack[High(Stack)];
      SetLength(Stack, Length(Stack) - 1);
      BufAdd(Buf, '</' + T + '>');
      if T = AName then
        Break;
    end;
  end;

begin
  Buf.Len := 0;
  Stack := nil;
  N := Length(ASrc);
  I := 1;
  while I <= N do
  begin
    if (ASrc[I] = '<') and (I < N) and CharInSet(ASrc[I + 1], ['a'..'z', 'A'..'Z', '/', '!', '?']) then
    begin
      // a comment
      if Copy(ASrc, I, 4) = '<!--' then
      begin
        J := Pos('-->', Copy(ASrc, I + 4, MaxInt));
        if J = 0 then
          Break;
        I := I + 4 + J + 2;
        Continue;
      end;
      J := I + 1;
      while (J <= N) and (ASrc[J] <> '>') do
        Inc(J);
      S := Copy(ASrc, I + 1, J - I - 1);
      I := J + 1;
      if (S = '') or (S[1] = '!') or (S[1] = '?') then
        Continue;
      Closing := S[1] = '/';
      if Closing then
        Delete(S, 1, 1);
      S := Trim(S);
      SelfClosing := (S <> '') and (S[Length(S)] = '/');
      if SelfClosing then
        S := Trim(Copy(S, 1, Length(S) - 1));
      K := 1;
      while (K <= Length(S)) and CharInSet(S[K], ['a'..'z', 'A'..'Z', '0'..'9', ':', '-']) do
        Inc(K);
      Orig := LowerCase(Copy(S, 1, K - 1));
      Attrs := Copy(S, K, MaxInt);
      Name := Orig;
      for P := 0 to High(MAP_FROM) do
        if MAP_FROM[P] = Orig then
          Name := MAP_TO[P];
      if not InList(Name, KEEP_TAGS) then
        Continue;
      if Closing then
      begin
        if (Name <> 'br') and (Name <> 'hr') and (Name <> 'img') and Opened(Name) then
          CloseTo(Name);
        Continue;
      end;
      // a block closes the paragraph it would be in; a list item the item
      if InList(Name, BLOCK_TAGS) or InList(Orig, BLOCK_TAGS) then
        if Opened('p') then
          CloseTo('p');
      if (Name = 'li') and Opened('li') then
        CloseTo('li');
      Attr := '';
      Style := '';
      V := AttrValue(Attrs, 'id', Found);
      if Found and (V <> '') then
        Attr := Attr + ' id="' + XmlText(V, True) + '"';
      Al := LowerCase(AttrValue(Attrs, 'align', Found));
      if Orig = 'center' then
        Al := 'center';
      if (Name <> 'img') and ((Al = 'left') or (Al = 'right') or (Al = 'center') or (Al = 'justify')) then
        Style := Style + 'text-align:' + Al + ';';
      if Name = 'p' then
      begin
        // Kindle's first-line indent and space above
        V := CssSize(AttrValue(Attrs, 'width', Found));
        if V <> '' then
          Style := Style + 'text-indent:' + V + ';';
        V := CssSize(AttrValue(Attrs, 'height', Found));
        if V <> '' then
          Style := Style + 'margin-top:' + V + ';';
      end;
      if Orig = 'pre' then
        Style := Style + 'white-space:pre-wrap;';
      if Name = 'a' then
      begin
        V := AttrValue(Attrs, 'filepos', Found);
        if Found then
        begin
          Rec := StrToIntDef(Trim(V), -1);
          if Rec >= 0 then
            Attr := Attr + ' href="#fp' + IntToStr(Rec) + '"';
        end
        else
        begin
          V := AttrValue(Attrs, 'href', Found);
          if Found and ((Pos('http:', LowerCase(V)) = 1) or (Pos('https:', LowerCase(V)) = 1) or
            (Pos('mailto:', LowerCase(V)) = 1)) then
            Attr := Attr + ' href="' + XmlText(V, True) + '"';
        end;
      end;
      if Name = 'img' then
      begin
        V := AttrValue(Attrs, 'recindex', Found);
        if not Found then
          V := AttrValue(Attrs, 'hirecindex', Found);
        if not Found then
          V := AttrValue(Attrs, 'lorecindex', Found);
        Rec := StrToIntDef(Trim(V), -1);
        Found := False;
        for P := 0 to High(APictures) do
          if APictures[P].Index = Rec then
          begin
            APictures[P].Used := True;
            Attr := Attr + Format(' src="../images/image%.5d.%s" alt=""', [Rec, APictures[P].Ext]);
            Found := True;
            Break;
          end;
        if not Found then
          Continue;
      end;
      if Style <> '' then
        Attr := Attr + ' style="' + XmlText(Copy(Style, 1, Length(Style) - 1), True) + '"';
      if (Name = 'br') or (Name = 'hr') or (Name = 'img') then
        BufAdd(Buf, '<' + Name + Attr + '/>')
      else if SelfClosing then
        BufAdd(Buf, '<' + Name + Attr + '></' + Name + '>')
      else
      begin
        BufAdd(Buf, '<' + Name + Attr + '>');
        Push(Name);
      end;
    end
    else
    begin
      // text up to the next tag
      J := I + 1;
      while (J <= N) and (ASrc[J] <> '<') do
        Inc(J);
      BufAdd(Buf, XmlText(DecodeEntities(Copy(ASrc, I, J - I)), False));
      I := J;
    end;
  end;
  while Length(Stack) > 0 do
    CloseTo(Stack[High(Stack)]);
  Result := BufText(Buf);
end;

{ The text of the XHTML AXhtml (tags taken out, entities as written,
  white space made single). }
function PlainText(const AXhtml: string): string;
var
  Buf: TMobiBuf;
  I: Integer;
  InTag, Space: Boolean;
  C: Char;
begin
  Buf.Len := 0;
  InTag := False;
  Space := False;
  for I := 1 to Length(AXhtml) do
  begin
    C := AXhtml[I];
    if C = '<' then
    begin
      InTag := True;
      Space := True;
    end
    else if C = '>' then
      InTag := False
    else if not InTag then
    begin
      if CharInSet(C, [' ', #9, #10, #13, #$A0]) then
        Space := True
      else
      begin
        if Space and (Buf.Len > 0) then
          BufAdd(Buf, ' ');
        Space := False;
        BufAdd(Buf, C);
      end;
    end;
  end;
  Result := BufText(Buf);
end;

{ A document's title for the contents: its first words (up to TITLE_MAX
  characters, cut at a word), else 'Part N'. }
function DocTitle(const AXhtml: string; ANumber: Integer): string;
var
  T: string;
  I: Integer;
begin
  T := Trim(StringReplace(StringReplace(StringReplace(PlainText(AXhtml), '&amp;', '&', [rfReplaceAll]),
    '&lt;', '<', [rfReplaceAll]), '&gt;', '>', [rfReplaceAll]));
  if T = '' then
    Exit(Format('Part %d', [ANumber]));
  if Length(T) > TITLE_MAX then
  begin
    I := TITLE_MAX;
    while (I > TITLE_MAX div 2) and (T[I] <> ' ') do
      Dec(I);
    T := TrimRight(Copy(T, 1, I)) + '...';
  end;
  Result := T;
end;

{ The MOBI's text bytes with an anchor ('<a id="fpN"></a>', N the
  offset a filepos link gives) put in at every place a link points to -
  moved to the start of a tag it would fall in. }
function WithAnchors(const AText: TBytes): TBytes;
var
  Places, Names: array of Integer;
  I, J, K, V, T, N, Count, OutLen: Integer;
  L: string;
  A: AnsiString;
  Seen: Boolean;
begin
  Places := nil;
  Names := nil;
  N := Length(AText);
  I := 0;
  while I < N - 8 do
  begin
    if (AText[I] = Ord('f')) or (AText[I] = Ord('F')) then
    begin
      L := '';
      for K := 0 to 7 do
        L := L + Char(AText[I + K]);
      if LowerCase(L) = 'filepos=' then
      begin
        J := I + 8;
        while (J < N) and ((AText[J] = Ord('"')) or (AText[J] = Ord(''''))) do
          Inc(J);
        V := 0;
        Count := 0;
        while (J < N) and (AText[J] >= Ord('0')) and (AText[J] <= Ord('9')) and (Count < 10) do
        begin
          V := V * 10 + AText[J] - Ord('0');
          Inc(J);
          Inc(Count);
        end;
        if (Count > 0) and (V <= N) then
        begin
          Seen := False;
          for K := 0 to High(Names) do
            if Names[K] = V then
            begin
              Seen := True;
              Break;
            end;
          if not Seen then
          begin
            // not in a tag: back to its '<'
            T := V - 1;
            while (T >= 0) and (AText[T] <> Ord('<')) and (AText[T] <> Ord('>')) do
              Dec(T);
            SetLength(Names, Length(Names) + 1);
            SetLength(Places, Length(Places) + 1);
            Names[High(Names)] := V;
            if (T >= 0) and (AText[T] = Ord('<')) then
              Places[High(Places)] := T
            else
              Places[High(Places)] := V;
          end;
        end;
        I := J;
        Continue;
      end;
    end;
    Inc(I);
  end;
  if Length(Places) = 0 then
    Exit(AText);
  // in order of place (an insertion sort: few links)
  for I := 1 to High(Places) do
  begin
    V := Places[I];
    T := Names[I];
    J := I - 1;
    while (J >= 0) and (Places[J] > V) do
    begin
      Places[J + 1] := Places[J];
      Names[J + 1] := Names[J];
      Dec(J);
    end;
    Places[J + 1] := V;
    Names[J + 1] := T;
  end;
  SetLength(Result, N + Length(Places) * 32);
  OutLen := 0;
  J := 0;
  for I := 0 to High(Places) do
  begin
    V := Places[I];
    if V > J then
    begin
      Move(AText[J], Result[OutLen], V - J);
      Inc(OutLen, V - J);
      J := V;
    end;
    A := AnsiString('<a id="fp' + IntToStr(Names[I]) + '"></a>');
    Move(A[1], Result[OutLen], Length(A));
    Inc(OutLen, Length(A));
  end;
  if N > J then
  begin
    Move(AText[J], Result[OutLen], N - J);
    Inc(OutLen, N - J);
  end;
  SetLength(Result, OutLen);
end;

{ The position (1-based) of ASub in AText from AFrom on, letter case
  ignored (0 = not there). ALower is AText in lower case. }
function PosLower(const ASub, ALower: string; AFrom: Integer): Integer;
var
  P: Integer;
begin
  P := Pos(ASub, Copy(ALower, AFrom, MaxInt));
  if P = 0 then
    Result := 0
  else
    Result := AFrom + P - 1;
end;

{ AHtml cut at Kindle's page breaks (<mbp:pagebreak>, with or without its
  end tag), the body's content only. }
function SplitPages(const AHtml: string): TStringList;
var
  Lower: string;
  Start, Stop, P, Q, R: Integer;
begin
  Result := TStringList.Create;
  Lower := LowerCase(AHtml);
  Start := 1;
  P := PosLower('<body', Lower, 1);
  if P > 0 then
  begin
    Q := PosLower('>', Lower, P);
    if Q > 0 then
      Start := Q + 1;
  end;
  Stop := Length(AHtml) + 1;
  P := Start;
  repeat
    Q := PosLower('</body', Lower, P);
    if Q = 0 then
      Break;
    Stop := Q;
    P := Q + 1;
  until False;
  P := Start;
  repeat
    Q := PosLower('<mbp:pagebreak', Lower, P);
    if (Q = 0) or (Q >= Stop) then
    begin
      Result.Add(Copy(AHtml, P, Stop - P));
      Break;
    end;
    Result.Add(Copy(AHtml, P, Q - P));
    R := PosLower('>', Lower, Q);
    if R = 0 then
      Break;
    P := R + 1;
    // its end tag, when written
    while (P < Stop) and CharInSet(AHtml[P], [' ', #9, #10, #13]) do
      Inc(P);
    if Copy(Lower, P, 16) = '</mbp:pagebreak>' then
      Inc(P, 16);
  until False;
end;

{ Plain PalmDOC text (TEXtREAd) as XHTML paragraphs: a paragraph per line
  with text. }
function TextAsHtml(const AText: string): string;
var
  L: TStringList;
  I: Integer;
  Buf: TMobiBuf;
begin
  Buf.Len := 0;
  L := TStringList.Create;
  try
    L.Text := AText;
    for I := 0 to L.Count - 1 do
      if Trim(L[I]) <> '' then
        BufAdd(Buf, '<p>' + XmlText(Trim(L[I]), False) + '</p>' + #10);
  finally
    L.Free;
  end;
  Result := BufText(Buf);
end;

{ The picture type of AData ('' when it is not a picture). }
function PictureExt(const AData: TBytes): string;
begin
  Result := '';
  if Length(AData) < 8 then
    Exit;
  if (AData[0] = $FF) and (AData[1] = $D8) and (AData[2] = $FF) then
    Result := 'jpg'
  else if (AData[0] = $89) and (AData[1] = Ord('P')) and (AData[2] = Ord('N')) and (AData[3] = Ord('G')) then
    Result := 'png'
  else if (AData[0] = Ord('G')) and (AData[1] = Ord('I')) and (AData[2] = Ord('F')) and (AData[3] = Ord('8')) then
    Result := 'gif'
  else if (AData[0] = Ord('B')) and (AData[1] = Ord('M')) then
    Result := 'bmp';
end;

{ The media type of a picture type. }
function PictureMediaType(const AExt: string): string;
begin
  if AExt = 'jpg' then
    Result := 'image/jpeg'
  else if AExt = 'png' then
    Result := 'image/png'
  else if AExt = 'gif' then
    Result := 'image/gif'
  else
    Result := 'image/bmp';
end;

{ A date as EPUB's dc:date wants it (YYYY, YYYY-MM or YYYY-MM-DD), ''
  when ADate does not start with one. }
function W3cDate(const ADate: string): string;
var
  I: Integer;
begin
  Result := '';
  if (Length(ADate) < 4) then
    Exit;
  for I := 1 to 4 do
    if not CharInSet(ADate[I], ['0'..'9']) then
      Exit;
  Result := Copy(ADate, 1, 4);
  // calibre's "no date" is 0101-01-01: no book is from before 1000
  if StrToIntDef(Result, 0) < 1000 then
    Exit('');
  if (Length(ADate) >= 7) and (ADate[5] = '-') and CharInSet(ADate[6], ['0'..'9']) and
    CharInSet(ADate[7], ['0'..'9']) then
  begin
    Result := Copy(ADate, 1, 7);
    if (Length(ADate) >= 10) and (ADate[8] = '-') and CharInSet(ADate[9], ['0'..'9']) and
      CharInSet(ADate[10], ['0'..'9']) then
      Result := Copy(ADate, 1, 10);
  end;
end;

function MobiIsMobi(const AFileName: string): Boolean;
var
  F: TFileStream;
  B: TBytes;
  T: string;
begin
  Result := False;
  try
    F := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      if F.Size < 86 then
        Exit;
      SetLength(B, 68);
      F.ReadBuffer(B[0], 68);
    finally
      F.Free;
    end;
    T := Tag4(B, 60) + Tag4(B, 64);
    Result := (T = 'BOOKMOBI') or (T = 'TEXtREAd');
  except
    Result := False;
  end;
end;

function MobiInfoText(const AInfo: TMobiInfo): string;
var
  By, Cover: string;
begin
  By := '';
  if AInfo.Author <> '' then
    By := ' by ' + AInfo.Author;
  Cover := '';
  if AInfo.HasCover then
    Cover := ', a cover';
  Result := Format('%s - "%s"%s, language %s: %d document(s), %d picture(s)%s', [AInfo.Kind, AInfo.Title, By,
    AInfo.Language, AInfo.Documents, AInfo.Pictures, Cover]);
end;

procedure MobiToEpub(const AMobiFile, AEpubFile: string; out AInfo: TMobiInfo);
var
  F: TFileStream;
  All, R0, Rec, Text: TBytes;
  Off: TMobiOffsets;
  Kind: string;
  Compression, Encryption, TextRecs, TextLen, HeaderLen, Encoding, FirstPic, ExthFlags, Extra: Cardinal;
  Utf8, IsText: Boolean;
  I, J, K, P, TextUsed, Size, CoverIndex, ExthAt, ExthCount, ExthType, ExthLen, KF8At: Integer;
  Html, Title, Authors, Language, Publisher, Description, Isbn, Date, V, Body, Id, Ids, Href: string;
  Pages: TStringList;
  Pictures: TMobiPictureArray;
  Docs: TMobiDocArray;
  Zip: TEpubZipWriter;
  Opf, Nav, Manifest, Spine, Doc: TMobiBuf;
  Anchors: TStringList;

  function ExthString(APos, ALen: Integer): string;
  begin
    Result := Trim(DecodeBytes(R0, APos, ALen, Utf8));
  end;

begin
  AInfo := Default(TMobiInfo);
  F := TFileStream.Create(AMobiFile, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(All, F.Size);
    if F.Size > 0 then
      F.ReadBuffer(All[0], F.Size);
  finally
    F.Free;
  end;
  if Length(All) < 86 then
    raise EEpubError.Create('Not a MOBI book: the file is too short');
  Kind := Tag4(All, 60) + Tag4(All, 64);
  IsText := Kind = 'TEXtREAd';
  if (Kind <> 'BOOKMOBI') and not IsText then
    raise EEpubError.Create('Not a MOBI book (its type is "' + Kind + '")');
  Off := ReadOffsets(All);
  R0 := RecordBytes(All, Off, 0);
  if Length(R0) < 16 then
    raise EEpubError.Create('Not a MOBI book: its first record is too short');
  Compression := Be16(R0, 0);
  TextLen := Be32(R0, 4);
  TextRecs := Be16(R0, 8);
  Encryption := Be16(R0, 12);
  if Encryption <> 0 then
    raise EEpubError.Create('This MOBI is copy-protected (DRM): it cannot be read - only DRM-free books ' +
      'can be converted');
  if Compression = 17480 then
    raise EEpubError.Create('This MOBI is compressed with Huffman coding (HUFF/CDIC), which is not read yet');
  if (Compression <> 1) and (Compression <> 2) then
    raise EEpubError.CreateFmt('This MOBI uses compression %d, which is not known', [Compression]);
  // the MOBI header (not in plain PalmDOC text)
  // (the header's length and EXTH flags are read in the block below only)
  Utf8 := False;
  FirstPic := $FFFFFFFF;
  Extra := 0;
  Title := '';
  Authors := '';
  Language := '';
  Publisher := '';
  Description := '';
  Isbn := '';
  Date := '';
  CoverIndex := -1;
  KF8At := -1;
  AInfo.Kind := 'PalmDOC text';
  if not IsText and (Tag4(R0, 16) = 'MOBI') then
  begin
    HeaderLen := Be32(R0, 20);
    Encoding := Be32(R0, 28);
    Utf8 := Encoding = 65001;
    if Be32(R0, 36) >= 8 then
      raise EEpubError.Create('This is a KF8 (AZW3) book only, which is not read yet - a MOBI with the ' +
        'old Mobipocket text in it is');
    AInfo.Kind := 'MOBI 6';
    // the full name
    P := Be32(R0, 84);
    K := Be32(R0, 88);
    if (P > 0) and (K > 0) and (P + K <= Length(R0)) then
      Title := ExthString(P, K);
    FirstPic := Be32(R0, 108);
    ExthFlags := Be32(R0, 128);
    if (16 + HeaderLen >= $F4) and (Length(R0) >= $F4) then
      Extra := Be16(R0, $F2);
    // EXTH
    ExthAt := 16 + Integer(HeaderLen);
    if ((ExthFlags and $40) <> 0) and (Tag4(R0, ExthAt) = 'EXTH') then
    begin
      ExthCount := Be32(R0, ExthAt + 8);
      P := ExthAt + 12;
      for I := 1 to ExthCount do
      begin
        if P + 8 > Length(R0) then
          Break;
        ExthType := Be32(R0, P);
        ExthLen := Be32(R0, P + 4);
        if (ExthLen < 8) or (P + ExthLen > Length(R0)) then
          Break;
        case ExthType of
          100:
            begin
              V := ExthString(P + 8, ExthLen - 8);
              if V <> '' then
                if Authors = '' then
                  Authors := V
                else
                  Authors := Authors + ' & ' + V;
            end;
          101: Publisher := ExthString(P + 8, ExthLen - 8);
          103: Description := ExthString(P + 8, ExthLen - 8);
          104: Isbn := ExthString(P + 8, ExthLen - 8);
          106: Date := ExthString(P + 8, ExthLen - 8);
          121:
            if ExthLen = 12 then
              KF8At := Integer(Be32(R0, P + 8));
          201:
            if ExthLen = 12 then
              CoverIndex := Integer(Be32(R0, P + 8)) + 1;
          503:
            begin
              V := ExthString(P + 8, ExthLen - 8);
              if V <> '' then
                Title := V;
            end;
          524: Language := ExthString(P + 8, ExthLen - 8);
        end;
        Inc(P, ExthLen);
      end;
    end;
    if (KF8At > 0) and (KF8At <> -1) and (Cardinal(KF8At) <> $FFFFFFFF) then
      AInfo.Kind := 'MOBI 6 (the file also holds KF8)';
  end;
  if Title = '' then
    Title := ChangeFileExt(ExtractFileName(AMobiFile), '');
  if Language = '' then
    Language := 'und';
  // the text
  SetLength(Text, TextLen + 4096);
  TextUsed := 0;
  for I := 1 to Integer(TextRecs) do
  begin
    Rec := RecordBytes(All, Off, I);
    if Rec = nil then
      Break;
    Size := WithoutTrailing(Rec, Extra);
    if Compression = 2 then
      PalmDocUnpack(Rec, Size, Text, TextUsed)
    else
    begin
      if TextUsed + Size > Length(Text) then
        SetLength(Text, (TextUsed + Size) * 2);
      if Size > 0 then
        Move(Rec[0], Text[TextUsed], Size);
      Inc(TextUsed, Size);
    end;
  end;
  if (TextLen > 0) and (Cardinal(TextUsed) > TextLen) then
    TextUsed := TextLen;
  SetLength(Text, TextUsed);
  // the pictures: records from the first picture on, while pictures
  Pictures := nil;
  if (FirstPic <> $FFFFFFFF) and (FirstPic > 0) then
    for I := Integer(FirstPic) to High(Off) - 1 do
    begin
      Rec := RecordBytes(All, Off, I);
      V := PictureExt(Rec);
      if V = '' then
      begin
        // the end of the pictures: FLIS, FCIS, the KF8 boundary, ...
        if (Tag4(Rec, 0) = 'FLIS') or (Tag4(Rec, 0) = 'FCIS') or (Tag4(Rec, 0) = 'BOUN') or
          (Tag4(Rec, 0) = 'SRCS') then
          Break;
        Continue;
      end;
      SetLength(Pictures, Length(Pictures) + 1);
      Pictures[High(Pictures)].Index := I - Integer(FirstPic) + 1;
      Pictures[High(Pictures)].Data := Rec;
      Pictures[High(Pictures)].Ext := V;
      Pictures[High(Pictures)].Used := Pictures[High(Pictures)].Index = CoverIndex;
    end;
  // the documents
  if IsText then
  begin
    Html := TextAsHtml(DecodeBytes(Text, 0, Length(Text), False));
    Pages := TStringList.Create;
    Pages.Add(Html);
  end
  else
  begin
    Text := WithAnchors(Text);
    Html := DecodeBytes(Text, 0, Length(Text), Utf8);
    Pages := SplitPages(Html);
  end;
  Docs := nil;
  Anchors := TStringList.Create;
  try
    for I := 0 to Pages.Count - 1 do
    begin
      Body := CleanHtml(Pages[I], Pictures);
      // a page with neither words nor pictures is left out
      if (Trim(PlainText(Body)) = '') and (Pos('<img', Body) = 0) then
        Continue;
      SetLength(Docs, Length(Docs) + 1);
      Docs[High(Docs)].Body := Body;
      Docs[High(Docs)].Title := DocTitle(Body, Length(Docs));
      // its anchors, for the links
      P := 1;
      repeat
        J := Pos('id="fp', Copy(Body, P, MaxInt));
        if J = 0 then
          Break;
        P := P + J - 1 + 6;
        K := P;
        while (K <= Length(Body)) and CharInSet(Body[K], ['0'..'9']) do
          Inc(K);
        Anchors.Values['fp' + Copy(Body, P, K - P)] := IntToStr(High(Docs));
        P := K;
      until False;
    end;
    if Length(Docs) = 0 then
      raise EEpubError.Create('This MOBI has no text to convert');
    // filepos links: to the document their anchor is in
    for I := 0 to High(Docs) do
    begin
      Body := Docs[I].Body;
      Doc.Len := 0;
      P := 1;
      repeat
        J := Pos('href="#fp', Copy(Body, P, MaxInt));
        if J = 0 then
        begin
          BufAdd(Doc, Copy(Body, P, MaxInt));
          Break;
        end;
        BufAdd(Doc, Copy(Body, P, J - 1));
        P := P + J - 1 + 7;
        K := P + 2;
        while (K <= Length(Body)) and CharInSet(Body[K], ['0'..'9']) do
          Inc(K);
        Id := Copy(Body, P, K - P);
        Ids := Anchors.Values[Id];
        if Ids <> '' then
          BufAdd(Doc, Format('href="doc%.4d.xhtml#%s"', [StrToInt(Ids) + 1, Id]))
        else
          // the place is not in a document written: no link
          BufAdd(Doc, 'data-filepos="' + Id + '"');
        P := K + 1;
      until False;
      Docs[I].Body := BufText(Doc);
    end;
  finally
    Anchors.Free;
    Pages.Free;
  end;
  // the EPUB
  AInfo.Title := Title;
  AInfo.Author := Authors;
  AInfo.Language := Language;
  AInfo.Documents := Length(Docs);
  for I := 0 to High(Pictures) do
    if Pictures[I].Used then
      Inc(AInfo.Pictures);
  AInfo.HasCover := False;
  for I := 0 to High(Pictures) do
    if Pictures[I].Index = CoverIndex then
      AInfo.HasCover := True;
  Zip := TEpubZipWriter.Create(AEpubFile);
  try
    Zip.AddEpubMimetype;
    Zip.Add('META-INF/container.xml', '<?xml version="1.0" encoding="UTF-8"?>' + #10 +
      '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">' + #10 +
      '  <rootfiles>' + #10 +
      '    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>' + #10 +
      '  </rootfiles>' + #10 + '</container>' + #10);
    Zip.Add('OEBPS/style.css', 'body { margin: 0 5%; }' + #10 + 'p { margin: 0; text-indent: 1.2em; }' + #10 +
      'img { max-width: 100%; }' + #10);
    Manifest.Len := 0;
    Spine.Len := 0;
    Nav.Len := 0;
    BufAdd(Nav, '<?xml version="1.0" encoding="UTF-8"?>' + #10 +
      '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="' +
      XmlText(Language, True) + '">' + #10 + '<head><title>' + XmlText(Title, False) + '</title></head>' + #10 +
      '<body>' + #10 + '<nav epub:type="toc" id="toc"><h1>Contents</h1>' + #10 + '<ol>' + #10);
    for I := 0 to High(Docs) do
    begin
      Href := Format('doc%.4d.xhtml', [I + 1]);
      Zip.Add('OEBPS/text/' + Href, '<?xml version="1.0" encoding="UTF-8"?>' + #10 +
        '<!DOCTYPE html>' + #10 +
        '<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="' + XmlText(Language, True) + '">' + #10 +
        '<head>' + #10 + '<title>' + XmlText(Docs[I].Title, False) + '</title>' + #10 +
        '<link rel="stylesheet" type="text/css" href="../style.css"/>' + #10 + '</head>' + #10 +
        '<body>' + #10 + Docs[I].Body + #10 + '</body>' + #10 + '</html>' + #10);
      BufAdd(Manifest, Format('    <item id="doc%.4d" href="text/%s" media-type="application/xhtml+xml"/>',
        [I + 1, Href]) + #10);
      BufAdd(Spine, Format('    <itemref idref="doc%.4d"/>', [I + 1]) + #10);
      BufAdd(Nav, '<li><a href="text/' + Href + '">' + XmlText(Docs[I].Title, False) + '</a></li>' + #10);
    end;
    BufAdd(Nav, '</ol>' + #10 + '</nav>' + #10 + '</body>' + #10 + '</html>' + #10);
    Zip.Add('OEBPS/nav.xhtml', BufText(Nav));
    for I := 0 to High(Pictures) do
      if Pictures[I].Used then
      begin
        V := Format('image%.5d.%s', [Pictures[I].Index, Pictures[I].Ext]);
        Zip.Add('OEBPS/images/' + V, Pictures[I].Data, True);
        if Pictures[I].Index = CoverIndex then
          BufAdd(Manifest, Format('    <item id="cover-image" href="images/%s" media-type="%s" ' +
            'properties="cover-image"/>', [V, PictureMediaType(Pictures[I].Ext)]) + #10)
        else
          BufAdd(Manifest, Format('    <item id="image%.5d" href="images/%s" media-type="%s"/>',
            [Pictures[I].Index, V, PictureMediaType(Pictures[I].Ext)]) + #10);
      end;
    Opf.Len := 0;
    BufAdd(Opf, '<?xml version="1.0" encoding="UTF-8"?>' + #10 +
      '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid" xml:lang="' +
      XmlText(Language, True) + '">' + #10 +
      '  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">' + #10);
    if Isbn <> '' then
      V := 'urn:isbn:' + Isbn
    else
      V := Format('urn:epubunum:mobi:%.8x-%d', [EpubCrc32(0, @All[0], Length(All)), Length(All)]);
    BufAdd(Opf, '    <dc:identifier id="bookid">' + XmlText(V, False) + '</dc:identifier>' + #10);
    BufAdd(Opf, '    <dc:title>' + XmlText(Title, False) + '</dc:title>' + #10);
    if Authors <> '' then
      BufAdd(Opf, '    <dc:creator>' + XmlText(Authors, False) + '</dc:creator>' + #10);
    BufAdd(Opf, '    <dc:language>' + XmlText(Language, False) + '</dc:language>' + #10);
    if Publisher <> '' then
      BufAdd(Opf, '    <dc:publisher>' + XmlText(Publisher, False) + '</dc:publisher>' + #10);
    if Description <> '' then
      BufAdd(Opf, '    <dc:description>' + XmlText(Description, False) + '</dc:description>' + #10);
    if W3cDate(Date) <> '' then
      BufAdd(Opf, '    <dc:date>' + W3cDate(Date) + '</dc:date>' + #10);
    BufAdd(Opf, '    <meta property="dcterms:modified">' + FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss"Z"',
      Now) + '</meta>' + #10);
    if AInfo.HasCover then
      BufAdd(Opf, '    <meta name="cover" content="cover-image"/>' + #10);
    BufAdd(Opf, '    <meta name="epubunum:converted" content="' + XmlText(AInfo.Kind + ': ' +
      ExtractFileName(AMobiFile), True) + '"/>' + #10);
    BufAdd(Opf, '  </metadata>' + #10 + '  <manifest>' + #10 +
      '    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>' + #10 +
      '    <item id="style" href="style.css" media-type="text/css"/>' + #10);
    BufAdd(Opf, BufText(Manifest));
    BufAdd(Opf, '  </manifest>' + #10 + '  <spine>' + #10 + BufText(Spine) + '  </spine>' + #10 +
      '</package>' + #10);
    Zip.Add('OEBPS/content.opf', BufText(Opf));
    Zip.Finish;
  finally
    Zip.Free;
  end;
end;

end.
