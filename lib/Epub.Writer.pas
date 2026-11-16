(* @abstract(@link(TEpubWriter): writes a copy of a book with EPUB 3 media
  overlays - the text synced with audio - from timed words.)

  The caller (TWhisper, after matching its transcript to the book's words)
  gives, for each word it heard, the word's index in
  @link(TEpubBook.Words), the audio file and the clip's start and end.
  Matching the transcript to the text is the caller's job: the writer takes
  word indexes only, so the words always agree with the reader's (one
  walker, Epub.Layout).

  What is written:
  - Every timed word is wrapped in @code(<span id="eu-wN">) in its document
    (word level, the default), or the block around it (p, li, h1, ...)
    gets an id (@link(TEpubWriter.Level) = eolBlock: a clip per paragraph).
    A word already alone in an element with an id keeps that id. Only
    inserted: the documents keep every byte of their markup, comments and
    entities.
  - A SMIL file per document with a clip (@code(<par>)) per word or block,
    in document order.
  - The package: SMIL and audio items in the manifest, media-overlay on
    the documents' items, media:duration (each overlay and the total),
    media:active-class, media:narrator, dcterms:modified.
  - When the book has no media:active-class: a small style sheet with a
    highlight rule for the active class, linked from the tagged documents,
    so other readers show the highlight too.
  - An EPUB 2 book becomes EPUB 3 (overlays are EPUB 3 only): version 3.0,
    a nav document made from the table of contents, opf:role / opf:file-as
    turned into refines metadata, other opf: attributes and extra dc:date
    elements dropped, the HTML5 doctype in the documents.
  - Chapter marks of the narration (@link(TEpubWriter.AddAudioChapter)),
    when given, in the audio chapters file (EpubUnum's own XML, manifest
    id @link(EPUB_AUDIO_CHAPTERS_ID)).
  A document's overlay is replaced as a whole: its clips are the timed
  words given for it. Documents without timed words are copied unchanged.

  Every tagged document is checked before it is written: parsed again and
  laid out, it must give the same words, and each new id must hold exactly
  its word (or block). The book's other files are copied without being
  unpacked.

  Framework-free; compiles with Delphi and FPC. *)
unit Epub.Writer;

{$I Epub.inc}

interface

uses
  SysUtils, Classes,
  Epub.Zip, Epub.Xml, Epub.Layout, Epub.Book;

type
  { What one clip of the overlay reads. }
  TEpubOverlayLevel = (
    { A clip per word (the highlight follows every word). }
    eolWord,
    { A clip per block - paragraph, list item, heading. }
    eolBlock);

  { One word heard in the audio. }
  TEpubTimedWord = record
    { The word: index into @link(TEpubBook.Words). }
    Word: Integer;
    { The audio file (from @link(TEpubWriter.AddAudioFile) or
      @link(TEpubWriter.AddBookAudio)). }
    Audio: Integer;
    { Start in the audio file, s. }
    ClipBegin: Double;
    { End in the audio file, s (after ClipBegin). }
    ClipEnd: Double;
  end;
  { Timed words. }
  TEpubTimedWordArray = array of TEpubTimedWord;

  { A chapter mark of the narration given to the writer. }
  TEpubChapterMark = record
    { Title. }
    Title: string;
    { The audio file (index from AddAudioFile / AddBookAudio). }
    Audio: Integer;
    { Start in that file, s. }
    Start: Double;
  end;
  { Chapter marks in narration order. }
  TEpubChapterMarkArray = array of TEpubChapterMark;

  { What the last @link(TEpubWriter.SaveToFile) did. }
  TEpubWriteReport = record
    { Documents given an overlay. }
    Documents: Integer;
    { Clips written (pars). }
    Clips: Integer;
    { Elements wrapped or given an id. }
    NewIds: Integer;
    { Ids the book had already used (a word alone in an element). }
    ReusedIds: Integer;
    { Timed words left out: no such word, a word outside the documents'
      text, a clip that ends before it starts, or a word given twice. }
    Skipped: Integer;
    { Total length of the clips, s (media:duration of the book). }
    Duration: Double;
    { The book was EPUB 2 and was made EPUB 3. }
    Upgraded: Boolean;
    { Things to know about the result, a line each ('' = none): an audio
      file of a type other readers may not play, ... }
    Warnings: string;
  end;

  { Writes a copy of a book with media overlays. The book stays the
    caller's and must stay open until SaveToFile returns. }
  TEpubWriter = class
  private
    { The book. }
    FBook: TEpubBook;
    { The timed words given (unsorted). }
    FTimed: TEpubTimedWordArray;
    { Timed words in use. }
    FTimedCount: Integer;
    { Audio files: archive path in the new book. }
    FAudioPaths: TStringList;
    { Audio files: file on disk ('' for one already in the book). }
    FAudioFiles: TStringList;
    { Chapter marks given (AddAudioChapter). }
    FChapters: TEpubChapterMarkArray;
    { Backing field of @link(Level). }
    FLevel: TEpubOverlayLevel;
    { Backing field of @link(IdPrefix). }
    FIdPrefix: string;
    { Backing field of @link(ActiveClass). }
    FActiveClass: string;
    { Backing field of @link(HighlightColor). }
    FHighlightColor: string;
    { Backing field of @link(Narrator). }
    FNarrator: string;
    { Backing field of @link(Report). }
    FReport: TEpubWriteReport;
    { Folder of the package document, with a trailing '/' ('' at the root). }
    function PackageFolder: string;
  public
    { A writer for ABook (not owned). }
    constructor Create(ABook: TEpubBook);
    { Frees the lists. }
    destructor Destroy; override;
    { Adds audio file AFileName (on disk) to the book, as
      @code(<package folder>/audio/<AName>) (AName '' = the file's name;
      characters other than ASCII letters, digits, '.', '-' and '_' become
      '_'). Returns its index for @link(AddWord). It is stored, not
      compressed. Use MP3 or AAC in MP4 (core media types of EPUB 3). }
    function AddAudioFile(const AFileName: string; const AName: string = ''): Integer;
    { Uses audio file APath already inside the book. Returns its index.
      @raises(EEpubError when the book has no such file.) }
    function AddBookAudio(const APath: string): Integer;
    { Adds a timed word: word AWord of @link(TEpubBook.Words) is heard in
      audio file AAudio from AClipBegin to AClipEnd seconds. Any order. }
    procedure AddWord(AWord, AAudio: Integer; AClipBegin, AClipEnd: Double);
    { Forgets the timed words (the audio files stay). }
    procedure ClearWords;
    { Adds a chapter mark of the narration: chapter ATitle of the
      recording starts at AStart seconds of audio file AAudio. Give them
      in narration order. Written to the book's audio chapters file
      (@link(EPUB_AUDIO_CHAPTERS_ID), EpubUnum's own: other readers ignore
      it), which @link(TEpubBook.AudioChapters) reads; it replaces the
      book's marks. With none given, the book's marks are kept as they are. }
    procedure AddAudioChapter(const ATitle: string; AAudio: Integer; AStart: Double);
    { Forgets the chapter marks. }
    procedure ClearAudioChapters;
    { Writes the book with its overlays to AFileName (not the book's own
      file). A file left half written by an error is deleted.
      @raises(EEpubError when there is nothing to write, AFileName is the
        book, or a tagged document does not check.) }
    procedure SaveToFile(const AFileName: string);
    { Clip per word (default) or per block. }
    property Level: TEpubOverlayLevel read FLevel write FLevel;
    { Start of the new ids ('eu-' = 'eu-w12', 'eu-p3'); an id the document
      already has is never made twice. }
    property IdPrefix: string read FIdPrefix write FIdPrefix;
    { media:active-class written when the book has none
      ('-epub-media-overlay-active'). A book's own class is kept. }
    property ActiveClass: string read FActiveClass write FActiveClass;
    { Background of the highlight in the style sheet added when the book
      has no active class (CSS colour, '#ffff66'). }
    property HighlightColor: string read FHighlightColor write FHighlightColor;
    { media:narrator ('' = keep the book's). }
    property Narrator: string read FNarrator write FNarrator;
    { What the last SaveToFile did. }
    property Report: TEpubWriteReport read FReport;
  end;

{ ASeconds as a SMIL clock value, 'h:mm:ss.fff'. }
function EpubClockText(ASeconds: Double): string;
{ Path ATo (inside the archive) relative to the file AFrom, as an href
  ('../audio/a.mp4'); characters outside ASCII letters, digits and
  '-._~/' are percent-encoded. }
function EpubRelativeHref(const AFrom, ATo: string): string;

implementation

uses
  DateUtils, StrUtils;

const
  { The XHTML namespace. }
  NS_XHTML = 'http://www.w3.org/1999/xhtml';

type
  { One change to a text: delete Del characters at Pos, insert Text. }
  TTextEdit = record
    { 1-based position in the original text. }
    Pos: Integer;
    { Characters deleted there. }
    Del: Integer;
    { At the same position, lower orders go first ('</span>' before
      '<span'). }
    Order: Integer;
    { Order of adding (keeps equal edits stable). }
    Seq: Integer;
    { Text inserted. }
    Text: string;
  end;

  { A list of edits. }
  TTextEdits = record
    { The edits (Count in use). }
    Items: array of TTextEdit;
    { Number in use. }
    Count: Integer;
  end;

  { One clip of an overlay being written. }
  TPar = record
    { Element id in the document. }
    Id: string;
    { Audio file index. }
    Audio: Integer;
    { Start, s. }
    ClipBegin: Double;
    { End, s. }
    ClipEnd: Double;
  end;
  { Clips of a document. }
  TParArray = array of TPar;

  { A replaced or added file of the new book. }
  TNewFile = record
    { Archive path. }
    Path: string;
    { Its text (UTF-8 when written). }
    Text: string;
  end;

{ Adds an edit to AList. }
procedure AddEdit(var AList: TTextEdits; APos, ADel, AOrder: Integer; const AText: string);
begin
  if AList.Count = Length(AList.Items) then
    SetLength(AList.Items, AList.Count * 2 + 64);
  AList.Items[AList.Count].Pos := APos;
  AList.Items[AList.Count].Del := ADel;
  AList.Items[AList.Count].Order := AOrder;
  AList.Items[AList.Count].Seq := AList.Count;
  AList.Items[AList.Count].Text := AText;
  Inc(AList.Count);
end;

{ True when edit A goes before edit B. }
function EditBefore(const A, B: TTextEdit): Boolean;
begin
  if A.Pos <> B.Pos then
    Result := A.Pos < B.Pos
  else if A.Order <> B.Order then
    Result := A.Order < B.Order
  else
    Result := A.Seq < B.Seq;
end;

{ Sorts AItems[ALo..AHi] (quicksort; the edits mostly come in order). }
procedure SortEdits(var AItems: array of TTextEdit; ALo, AHi: Integer);
var
  I, J: Integer;
  P, T: TTextEdit;
begin
  while ALo < AHi do
  begin
    P := AItems[(ALo + AHi) div 2];
    I := ALo;
    J := AHi;
    repeat
      while EditBefore(AItems[I], P) do
        Inc(I);
      while EditBefore(P, AItems[J]) do
        Dec(J);
      if I <= J then
      begin
        T := AItems[I];
        AItems[I] := AItems[J];
        AItems[J] := T;
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if J - ALo < AHi - I then
    begin
      SortEdits(AItems, ALo, J);
      ALo := I;
    end
    else
    begin
      SortEdits(AItems, I, AHi);
      AHi := J;
    end;
  end;
end;

{ AText with the edits made (they must not overlap). }
function ApplyEdits(const AText: string; var AList: TTextEdits): string;
var
  I, Src, Dst, N, Total: Integer;
begin
  if AList.Count = 0 then
    Exit(AText);
  SortEdits(AList.Items, 0, AList.Count - 1);
  Total := Length(AText);
  for I := 0 to AList.Count - 1 do
    Total := Total + Length(AList.Items[I].Text) - AList.Items[I].Del;
  SetLength(Result, Total);
  Src := 1;
  Dst := 1;
  for I := 0 to AList.Count - 1 do
  begin
    if AList.Items[I].Pos < Src then
      raise EEpubError.Create('Internal error: overlapping edits of a document');
    N := AList.Items[I].Pos - Src;
    if N > 0 then
      Move(AText[Src], Result[Dst], N * SizeOf(Char));
    Inc(Dst, N);
    Src := AList.Items[I].Pos + AList.Items[I].Del;
    N := Length(AList.Items[I].Text);
    if N > 0 then
      Move(AList.Items[I].Text[1], Result[Dst], N * SizeOf(Char));
    Inc(Dst, N);
  end;
  N := Length(AText) - Src + 1;
  if N > 0 then
    Move(AText[Src], Result[Dst], N * SizeOf(Char));
end;

function EpubClockText(ASeconds: Double): string;
var
  Ms: Int64;
begin
  if ASeconds < 0 then
    ASeconds := 0;
  Ms := Round(ASeconds * 1000);
  Result := Format('%d:%.2d:%.2d.%.3d', [Ms div 3600000, (Ms div 60000) mod 60, (Ms div 1000) mod 60,
    Ms mod 1000]);
end;

{ The UTF-8 bytes of AText percent-encoded where an href needs it. }
function HrefEncode(const AText: string): string;
const
  HEX = '0123456789ABCDEF';
var
  B: TBytes;
  I: Integer;
begin
  B := EpubUtf8Bytes(AText);
  Result := '';
  for I := 0 to High(B) do
    if AnsiChar(B[I]) in ['A'..'Z', 'a'..'z', '0'..'9', '-', '.', '_', '~', '/'] then
      Result := Result + Char(B[I])
    else
      Result := Result + '%' + HEX[B[I] shr 4 + 1] + HEX[B[I] and 15 + 1];
end;

function EpubRelativeHref(const AFrom, ATo: string): string;
var
  F, T: TStringList;
  I, Common: Integer;
begin
  F := TStringList.Create;
  T := TStringList.Create;
  try
    F.Delimiter := '/';
    F.StrictDelimiter := True;
    T.Delimiter := '/';
    T.StrictDelimiter := True;
    F.DelimitedText := AFrom;
    T.DelimitedText := ATo;
    F.Delete(F.Count - 1);   // the file's name: only its folders count
    Common := 0;
    while (Common < F.Count) and (Common < T.Count - 1) and (F[Common] = T[Common]) do
      Inc(Common);
    Result := '';
    for I := Common to F.Count - 1 do
      Result := Result + '../';
    for I := Common to T.Count - 1 do
    begin
      Result := Result + T[I];
      if I < T.Count - 1 then
        Result := Result + '/';
    end;
  finally
    F.Free;
    T.Free;
  end;
  Result := HrefEncode(Result);
end;

{ The media type of an audio file, from its extension. }
function AudioMediaType(const APath: string): string;
var
  E: string;
begin
  E := LowerCase(ExtractFileExt(APath));
  if E = '.mp3' then
    Result := 'audio/mpeg'
  else if (E = '.mp4') or (E = '.m4a') or (E = '.m4b') or (E = '.aac') then
    Result := 'audio/mp4'
  else if (E = '.ogg') or (E = '.oga') or (E = '.opus') then
    Result := 'audio/ogg'
  else if E = '.wav' then
    Result := 'audio/wav'
  else if E = '.flac' then
    Result := 'audio/flac'
  else
    Result := 'application/octet-stream';
end;

{ AName with every character but ASCII letters, digits, '.', '-' and '_'
  made '_' (names inside the book stay portable). }
function SafeName(const AName: string): string;
var
  I: Integer;
begin
  Result := AName;
  for I := 1 to Length(Result) do
    if not CharInSet(Result[I], ['A'..'Z', 'a'..'z', '0'..'9', '.', '-', '_']) then
      Result[I] := '_';
  if (Result = '') or (Result[1] = '.') then
    Result := 'audio' + Result;
end;

{ The start tag of element AEl as it would be written, with its attributes
  AAttrs (values escaped). }
function StartTag(AEl: TEpubXmlNode; const AAttrs: TEpubXmlAttrArray; ASelfClose: Boolean): string;
var
  I: Integer;
begin
  Result := '<' + AEl.Name;
  for I := 0 to High(AAttrs) do
    Result := Result + ' ' + AAttrs[I].Name + '="' + EpubXmlEscape(AAttrs[I].Value) + '"';
  if ASelfClose then
    Result := Result + '/>'
  else
    Result := Result + '>';
end;

{ True when element AEl's start tag in ASource ends with '/>'. }
function IsSelfClosed(const ASource: string; AEl: TEpubXmlNode): Boolean;
var
  P: Integer;
begin
  P := AEl.SrcPos + AEl.SrcLen - 2;
  Result := (P >= 1) and (P <= Length(ASource)) and (ASource[P] = '/');
end;

{ AAttrs with attribute AName set to AValue (added at the end when
  missing; compared as written, case ignored). }
procedure SetAttr(var AAttrs: TEpubXmlAttrArray; const AName, AValue: string);
var
  I: Integer;
begin
  for I := 0 to High(AAttrs) do
    if SameText(AAttrs[I].Name, AName) then
    begin
      AAttrs[I].Value := AValue;
      Exit;
    end;
  SetLength(AAttrs, Length(AAttrs) + 1);
  AAttrs[High(AAttrs)].Name := AName;
  AAttrs[High(AAttrs)].Value := AValue;
end;

{ Where the end tag of AEl starts in ASource ('<' of '</...>'); 0 when the
  element has no end tag of its own. }
function EndTagStart(const ASource: string; AEl: TEpubXmlNode): Integer;
begin
  Result := 0;
  if (AEl.SrcEnd <= AEl.SrcPos + AEl.SrcLen) then
    Exit;   // empty, void or repaired
  Result := AEl.SrcEnd - 1;
  while (Result > AEl.SrcPos) and (ASource[Result] <> '<') do
    Dec(Result);
  if (Result <= AEl.SrcPos) or (Copy(ASource, Result, 2) <> '</') then
    Result := 0;
end;

{ Every id attribute in the tree under ANode, into AIds (sorted). }
procedure CollectIds(ANode: TEpubXmlNode; AIds: TStringList);
var
  I: Integer;
  C: TEpubXmlNode;
begin
  for I := 0 to ANode.ChildCount - 1 do
  begin
    C := ANode.Children[I];
    if C.Kind <> xnElement then
      Continue;
    if C.Attr('id') <> '' then
      AIds.Add(C.Attr('id'));
    CollectIds(C, AIds);
  end;
end;

{ AText with the encoding of its XML declaration set to UTF-8 (the new
  file is written as UTF-8 whatever the old one was). }
function DeclareUtf8(const AText: string): string;
var
  E, Q1, Q2: Integer;
  Decl: string;
begin
  Result := AText;
  if Copy(AText, 1, 5) <> '<?xml' then
    Exit;
  E := Pos('?>', AText);
  if E = 0 then
    Exit;
  Decl := Copy(AText, 1, E + 1);
  Q1 := Pos('encoding', Decl);
  if Q1 = 0 then
    Exit;
  while (Q1 <= Length(Decl)) and not CharInSet(Decl[Q1], ['"', '''']) do
    Inc(Q1);
  Q2 := Q1 + 1;
  while (Q2 <= Length(Decl)) and (Decl[Q2] <> Decl[Q1]) do
    Inc(Q2);
  if Q2 > Length(Decl) then
    Exit;
  Result := Copy(AText, 1, Q1) + 'UTF-8' + Copy(AText, Q2, MaxInt);
end;

{ AText with its DOCTYPE made the HTML5 one (EPUB 3 content documents). }
function Html5Doctype(const AText: string): string;
var
  P, E: Integer;
  U: string;
begin
  Result := AText;
  U := UpperCase(Copy(AText, 1, 4096));
  P := Pos('<!DOCTYPE', U);
  if P = 0 then
    Exit;
  E := P;
  while (E <= Length(AText)) and (AText[E] <> '>') do
  begin
    if AText[E] = '[' then
      Exit;   // an internal subset: left alone
    Inc(E);
  end;
  if E > Length(AText) then
    Exit;
  if LowerCase(Trim(Copy(AText, P, E - P + 1))) = '<!doctype html>' then
    Exit;
  Result := Copy(AText, 1, P - 1) + '<!DOCTYPE html>' + Copy(AText, E + 1, MaxInt);
end;

{ AText without the meta elements whose http-equiv HTML5 does not allow
  (EPUB 2 books, Project Gutenberg's among them, carry
  http-equiv="Content-Style-Type"; epubcheck rejects it in EPUB 3).
  Allowed: content-type, default-style, refresh, x-ua-compatible,
  content-security-policy. }
function WithoutOldHttpEquiv(const AText: string): string;
const
  ALLOWED = '|content-type|default-style|refresh|x-ua-compatible|content-security-policy|';
var
  Low, Tag, Value: string;
  From, P, E, A, Q: Integer;
begin
  Result := AText;
  Low := LowerCase(Result);   // the same length as Result: offsets match
  From := 1;
  repeat
    P := PosEx('<meta', Low, From);
    if P = 0 then
      Break;
    E := PosEx('>', Low, P);
    if E = 0 then
      Break;
    Tag := Copy(Low, P, E - P + 1);
    A := Pos('http-equiv', Tag);
    Value := '';
    if A > 0 then
    begin
      Inc(A, Length('http-equiv'));
      while (A <= Length(Tag)) and CharInSet(Tag[A], [' ', #9, #10, #13, '=']) do
        Inc(A);
      if (A <= Length(Tag)) and CharInSet(Tag[A], ['"', '''']) then
      begin
        Q := A + 1;
        while (Q <= Length(Tag)) and (Tag[Q] <> Tag[A]) do
          Inc(Q);
        Value := Trim(Copy(Tag, A + 1, Q - A - 1));
      end;
    end;
    if (A > 0) and (Pos('|' + Value + '|', ALLOWED) = 0) then
    begin
      Delete(Result, P, E - P + 1);
      Delete(Low, P, E - P + 1);
      From := P;
    end
    else
      From := E + 1;
  until False;
end;

{ AText made an EPUB 3 content document: the HTML5 doctype, named
  entities as character references (the HTML5 doctype declares none),
  and no meta http-equiv that HTML5 does not allow. }
function Html5Text(const AText: string): string;
begin
  Result := Html5Doctype(AText);
  if Result <> AText then
    Result := EpubXmlNumericEntities(Result);
  Result := WithoutOldHttpEquiv(Result);
end;

{ The file name part of archive path APath. }
function LastPart(const APath: string): string;
begin
  Result := Copy(APath, LastDelimiter('/', APath) + 1, MaxInt);
end;

{ The time now, UTC, as dcterms:modified wants it ('2026-11-15T10:59:00Z'). }
function ModifiedNow: string;
var
  T: TDateTime;
begin
  {$ifdef FPC}
  T := IncMinute(Now, GetLocalTimeOffset);   // offset: UTC - local, minutes
  {$else}
  T := TTimeZone.Local.ToUniversalTime(Now);
  {$endif}
  Result := FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss"Z"', T);
end;

{ TEpubWriter }

constructor TEpubWriter.Create(ABook: TEpubBook);
begin
  inherited Create;
  FBook := ABook;
  FAudioPaths := TStringList.Create;
  FAudioFiles := TStringList.Create;
  FIdPrefix := 'eu-';
  FActiveClass := '-epub-media-overlay-active';
  FHighlightColor := '#ffff66';
end;

destructor TEpubWriter.Destroy;
begin
  FAudioPaths.Free;
  FAudioFiles.Free;
  inherited;
end;

function TEpubWriter.PackageFolder: string;
var
  P: Integer;
begin
  P := LastDelimiter('/', FBook.PackagePath);
  Result := Copy(FBook.PackagePath, 1, P);
end;

function TEpubWriter.AddAudioFile(const AFileName: string; const AName: string): Integer;
var
  Name, Path, Base, Ext: string;
  N: Integer;
begin
  if not FileExists(AFileName) then
    raise EEpubError.CreateFmt('The audio file %s does not exist', [AFileName]);
  Name := AName;
  if Name = '' then
    Name := ExtractFileName(AFileName);
  Name := SafeName(Name);
  Ext := ExtractFileExt(Name);
  Base := Copy(Name, 1, Length(Name) - Length(Ext));
  Path := PackageFolder + 'audio/' + Name;
  N := 1;
  // never over a file of the book or one added before
  while FBook.Zip.Exists(Path) or (FAudioPaths.IndexOf(Path) >= 0) do
  begin
    Inc(N);
    Path := PackageFolder + 'audio/' + Base + '-' + IntToStr(N) + Ext;
  end;
  FAudioPaths.Add(Path);
  Result := FAudioFiles.Add(AFileName);
end;

function TEpubWriter.AddBookAudio(const APath: string): Integer;
var
  I: Integer;
begin
  I := FBook.Zip.IndexOf(APath);
  if I < 0 then
    raise EEpubError.CreateFmt('%s: there is no %s inside', [FBook.FileName, APath]);
  FAudioPaths.Add(FBook.Zip.Entries[I].Name);
  Result := FAudioFiles.Add('');
end;

procedure TEpubWriter.AddWord(AWord, AAudio: Integer; AClipBegin, AClipEnd: Double);
begin
  if FTimedCount = Length(FTimed) then
    SetLength(FTimed, FTimedCount * 2 + 1024);
  FTimed[FTimedCount].Word := AWord;
  FTimed[FTimedCount].Audio := AAudio;
  FTimed[FTimedCount].ClipBegin := AClipBegin;
  FTimed[FTimedCount].ClipEnd := AClipEnd;
  Inc(FTimedCount);
end;

procedure TEpubWriter.ClearWords;
begin
  FTimed := nil;
  FTimedCount := 0;
end;

procedure TEpubWriter.AddAudioChapter(const ATitle: string; AAudio: Integer; AStart: Double);
begin
  if (AAudio < 0) or (AAudio >= FAudioPaths.Count) then
    raise EEpubError.CreateFmt('Chapter mark "%s": there is no audio file %d', [ATitle, AAudio]);
  SetLength(FChapters, Length(FChapters) + 1);
  FChapters[High(FChapters)].Title := ATitle;
  FChapters[High(FChapters)].Audio := AAudio;
  if AStart < 0 then
    AStart := 0;
  FChapters[High(FChapters)].Start := AStart;
end;

procedure TEpubWriter.ClearAudioChapters;
begin
  FChapters := nil;
end;

{ Sorts timed words by word index (merge sort: stable, so the first of
  two entries for one word wins). }
procedure SortTimed(var A: TEpubTimedWordArray; ACount: Integer);
var
  Tmp: TEpubTimedWordArray;

  procedure Merge(ALo, AHi: Integer);
  var
    Mid, I, J, K: Integer;
  begin
    if AHi - ALo < 1 then
      Exit;
    Mid := (ALo + AHi) div 2;
    Merge(ALo, Mid);
    Merge(Mid + 1, AHi);
    I := ALo;
    J := Mid + 1;
    K := ALo;
    while (I <= Mid) and (J <= AHi) do
    begin
      if A[J].Word < A[I].Word then
      begin
        Tmp[K] := A[J];
        Inc(J);
      end
      else
      begin
        Tmp[K] := A[I];
        Inc(I);
      end;
      Inc(K);
    end;
    while I <= Mid do
    begin
      Tmp[K] := A[I];
      Inc(I);
      Inc(K);
    end;
    while J <= AHi do
    begin
      Tmp[K] := A[J];
      Inc(J);
      Inc(K);
    end;
    for K := ALo to AHi do
      A[K] := Tmp[K];
  end;

begin
  SetLength(Tmp, ACount);
  Merge(0, ACount - 1);
end;

type
  { The work of one SaveToFile (keeps the writer's fields plain). }
  TSaveJob = class
    { The writer. }
    W: TEpubWriter;
    { Its book. }
    Book: TEpubBook;
    { Timed words kept, sorted by word. }
    Timed: TEpubTimedWordArray;
    { Files replaced or added (by archive path). }
    NewFiles: array of TNewFile;
    { Archive paths given out (new files), lower case, sorted. }
    Taken: TStringList;
    { Manifest ids in use (the package's ids), sorted. }
    ItemIds: TStringList;
    { Make EPUB 2 into EPUB 3. }
    Upgrade: Boolean;
    { The book has media:active-class. }
    HasActiveClass: Boolean;
    { The style sheet added for the highlight ('' = none). }
    CssPath: string;
    { The audio chapters file written ('' = none). }
    ChaptersPath: string;
    { It is new: the manifest gets an item for it. }
    ChaptersNew: Boolean;
    { Per document: the overlay's SMIL path ('' = untouched). }
    SmilPaths: array of string;
    { Per document: the SMIL manifest item id. }
    SmilIds: array of string;
    { Per document: the SMIL item is new. }
    SmilNew: array of Boolean;
    { Per document: duration of the new overlay, s. }
    SmilDur: array of Double;
    { The report. }
    Report: TEpubWriteReport;
    { Sets up the lists. }
    constructor Create(AWriter: TEpubWriter);
    { Frees the lists. }
    destructor Destroy; override;
    { Sets file APath of the new book to AText. }
    procedure PutFile(const APath, AText: string);
    { The text of the new book's file APath when it was replaced; else
      the book's. }
    function FileText(const APath: string): string;
    { Index in NewFiles of APath, -1 when none. }
    function NewFileIndex(const APath: string): Integer;
    { A path for a new file like APath that the book does not have. }
    function FreePath(const APath: string): string;
    { A manifest id like ABase that is not in use. }
    function FreeItemId(const ABase: string): string;
    { Drops bad and repeated timed words. }
    procedure FilterTimed;
    { Tags document ADoc for the timed words Timed[AFirst..ALast] and
      writes its overlay. }
    procedure TagDocument(ADoc, AFirst, ALast: Integer);
    { The SMIL text for document ADoc's clips APars. }
    function SmilText(ADoc: Integer; const ASmilPath: string; const APars: TParArray): string;
    { Makes a nav document from the table of contents; returns its path. }
    function MakeNav: string;
    { Writes the chapter marks given (W.FChapters) into the audio chapters
      file: the book's own when it has one, else a new one (ChaptersPath,
      ChaptersNew). }
    procedure WriteChapters;
    { Rewrites the package document. }
    procedure UpdatePackage(const ANavPath: string);
    { Writes the archive. }
    procedure WriteArchive(const AFileName: string);
  end;

constructor TSaveJob.Create(AWriter: TEpubWriter);
var
  I: Integer;
begin
  inherited Create;
  W := AWriter;
  Book := W.FBook;
  Taken := TStringList.Create;
  Taken.Sorted := True;
  ItemIds := TStringList.Create;
  ItemIds.Sorted := True;
  ItemIds.CaseSensitive := True;
  for I := 0 to High(Book.Zip.Entries) do
    Taken.Add(LowerCase(Book.Zip.Entries[I].Name));
  for I := 0 to W.FAudioPaths.Count - 1 do
    if W.FAudioFiles[I] <> '' then
      Taken.Add(LowerCase(W.FAudioPaths[I]));
  SetLength(SmilPaths, Length(Book.Documents));
  SetLength(SmilIds, Length(Book.Documents));
  SetLength(SmilNew, Length(Book.Documents));
  SetLength(SmilDur, Length(Book.Documents));
end;

destructor TSaveJob.Destroy;
begin
  Taken.Free;
  ItemIds.Free;
  inherited;
end;

function TSaveJob.NewFileIndex(const APath: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(NewFiles) do
    if NewFiles[I].Path = APath then
      Exit(I);
  Result := -1;
end;

procedure TSaveJob.PutFile(const APath, AText: string);
var
  I: Integer;
begin
  I := NewFileIndex(APath);
  if I < 0 then
  begin
    SetLength(NewFiles, Length(NewFiles) + 1);
    I := High(NewFiles);
    NewFiles[I].Path := APath;
  end;
  NewFiles[I].Text := AText;
end;

function TSaveJob.FileText(const APath: string): string;
var
  I: Integer;
begin
  I := NewFileIndex(APath);
  if I >= 0 then
    Result := NewFiles[I].Text
  else
    Result := Book.ReadResourceText(APath);
end;

function TSaveJob.FreePath(const APath: string): string;
var
  Ext, Base: string;
  N: Integer;
begin
  Result := APath;
  Ext := ExtractFileExt(APath);
  Base := Copy(APath, 1, Length(APath) - Length(Ext));
  N := 1;
  while Taken.IndexOf(LowerCase(Result)) >= 0 do
  begin
    Inc(N);
    Result := Base + '-' + IntToStr(N) + Ext;
  end;
  Taken.Add(LowerCase(Result));
end;

function TSaveJob.FreeItemId(const ABase: string): string;
var
  N: Integer;
begin
  Result := ABase;
  N := 1;
  while ItemIds.IndexOf(Result) >= 0 do
  begin
    Inc(N);
    Result := ABase + '-' + IntToStr(N);
  end;
  ItemIds.Add(Result);
end;

procedure TSaveJob.FilterTimed;
var
  I, N, Last: Integer;
  T: TEpubTimedWord;
begin
  Timed := Copy(W.FTimed, 0, W.FTimedCount);
  SortTimed(Timed, Length(Timed));
  N := 0;
  Last := -1;
  for I := 0 to High(Timed) do
  begin
    T := Timed[I];
    if (T.Word < 0) or (T.Word >= Book.WordCount) or (T.Word = Last) or (T.Audio < 0) or
      (T.Audio >= W.FAudioPaths.Count) or not (T.ClipEnd > T.ClipBegin) or (T.ClipBegin < 0) then
    begin
      Inc(Report.Skipped);
      Continue;
    end;
    Last := T.Word;
    Timed[N] := T;
    Inc(N);
  end;
  SetLength(Timed, N);
end;

procedure TSaveJob.TagDocument(ADoc, AFirst, ALast: Integer);
var
  Xml, Check: TEpubXmlDoc;
  Lay, Lay2: TEpubDocLayout;
  Src, Text, Raw, Id, CssHref, Base: string;
  Edits: TTextEdits;
  Ids, BlockKeys, NewIds: TStringList;
  BlockIdList: array of string;
  Pars: TParArray;
  NPars, I, K, Local, P1, P2, CoreFirst, CoreLast, First0, IdIdx, N: Integer;
  WS: TEpubWordSource;
  Head, Blk: TEpubXmlNode;

  { The source index of decoded character AIdx of text node ANode. }
  function RawPos(ANode: TEpubXmlNode; AIdx: Integer): Integer;
  begin
    if ANode.CData then
      Result := ANode.SrcPos + AIdx - 1
    else
      Result := ANode.SrcPos - 1 + EpubXmlRawIndex(Copy(Src, ANode.SrcPos, ANode.SrcLen), AIdx);
  end;

  { A new id from AStem that the document does not have. }
  function NewId(const AStem: string): string;
  var
    M: Integer;
  begin
    Result := W.FIdPrefix + AStem;
    M := 1;
    while Ids.IndexOf(Result) >= 0 do
    begin
      Inc(M);
      Result := W.FIdPrefix + AStem + '-' + IntToStr(M);
    end;
    Ids.Add(Result);
  end;

  { Adds a clip for id AId from timed word ATimed. }
  procedure AddPar(const AId: string; const ATimed: TEpubTimedWord);
  begin
    if NPars = Length(Pars) then
      SetLength(Pars, NPars * 2 + 256);
    Pars[NPars].Id := AId;
    Pars[NPars].Audio := ATimed.Audio;
    Pars[NPars].ClipBegin := ATimed.ClipBegin;
    Pars[NPars].ClipEnd := ATimed.ClipEnd;
    Inc(NPars);
  end;

begin
  First0 := Book.Documents[ADoc].FirstWord;
  Edits := Default(TTextEdits);
  NPars := 0;
  Lay := Book.DocumentSources(ADoc, Xml);
  Ids := TStringList.Create;
  BlockKeys := TStringList.Create;
  NewIds := TStringList.Create;
  try
    Src := Xml.Source;
    if Lay.WordCount <> Book.Documents[ADoc].WordCount then
      raise EEpubError.CreateFmt('Internal error: %s gives %d words, the book has %d',
        [Book.Documents[ADoc].Path, Lay.WordCount, Book.Documents[ADoc].WordCount]);
    Ids.Sorted := True;
    Ids.CaseSensitive := True;
    CollectIds(Xml.Root, Ids);
    // block element (its source position as text) -> index in BlockIdList
    BlockKeys.Sorted := True;
    // new id -> the word it must hold (-1 for a block: it must be found)
    NewIds.Sorted := True;
    NewIds.CaseSensitive := True;
    I := AFirst;
    while I <= ALast do
    begin
      Local := Timed[I].Word - First0;
      WS := Lay.Sources[Local];
      if W.FLevel = eolWord then
      begin
        IdIdx := Lay.Words[Local].IdIndex;
        if (IdIdx >= 0) and (Lay.Ids[IdIdx].FirstWord = Local) and (Lay.Ids[IdIdx].LastWord = Local) then
        begin
          // the word is alone in an element with an id: use it
          Id := Lay.Ids[IdIdx].Id;
          Inc(Report.ReusedIds);
        end
        else
        begin
          Id := NewId('w' + IntToStr(Local + 1));
          // the span holds the word without the punctuation around it (a
          // reading system lights the span: 'whales' read, not 'whales,')
          CoreFirst := WS.FirstStart;
          CoreLast := WS.FirstEnd;
          EpubWordCore(WS.FirstNode.Text, CoreFirst, CoreLast);
          if WS.FirstNode <> WS.LastNode then
            CoreLast := WS.FirstEnd;   // the word goes on in the next node
          P1 := RawPos(WS.FirstNode, CoreFirst);
          P2 := RawPos(WS.FirstNode, CoreLast + 1);
          AddEdit(Edits, P1, 0, 1, '<span id="' + EpubXmlEscape(Id) + '">');
          AddEdit(Edits, P2, 0, 0, '</span>');
          NewIds.AddObject(Id, TObject(NativeInt(Local)));
          Inc(Report.NewIds);
        end;
        AddPar(Id, Timed[I]);
        Inc(I);
      end
      else
      begin
        // the block: its own id, or a new one in its start tag
        Blk := WS.Block;
        Id := Blk.Attr('id');
        if Id = '' then
        begin
          K := BlockKeys.IndexOf(IntToStr(Blk.SrcPos));
          if K >= 0 then
            Id := BlockIdList[NativeInt(BlockKeys.Objects[K])]
          else
          begin
            Id := NewId('p' + IntToStr(Length(BlockIdList) + 1));
            SetLength(BlockIdList, Length(BlockIdList) + 1);
            BlockIdList[High(BlockIdList)] := Id;
            BlockKeys.AddObject(IntToStr(Blk.SrcPos), TObject(NativeInt(High(BlockIdList))));
            K := Blk.SrcPos + Blk.SrcLen - 1;   // the '>'
            if IsSelfClosed(Src, Blk) then
              Dec(K);
            AddEdit(Edits, K, 0, 0, ' id="' + EpubXmlEscape(Id) + '"');
            NewIds.AddObject(Id, TObject(NativeInt(-1)));
            Inc(Report.NewIds);
          end;
        end
        else if BlockKeys.IndexOf(IntToStr(Blk.SrcPos)) < 0 then
        begin
          BlockKeys.Add(IntToStr(Blk.SrcPos));
          Inc(Report.ReusedIds);
        end;
        // one clip for the block's run of words in one audio file
        AddPar(Id, Timed[I]);
        Inc(I);
        while (I <= ALast) and (Lay.Sources[Timed[I].Word - First0].Block = Blk) and
          (Timed[I].Audio = Pars[NPars - 1].Audio) and (Timed[I].ClipBegin >= Pars[NPars - 1].ClipBegin) do
        begin
          if Timed[I].ClipEnd > Pars[NPars - 1].ClipEnd then
            Pars[NPars - 1].ClipEnd := Timed[I].ClipEnd;
          Inc(I);
        end;
      end;
    end;
    // the highlight style sheet, linked in the head
    if CssPath <> '' then
    begin
      Head := Xml.Root.Find('head');
      if Head <> nil then
      begin
        K := EndTagStart(Src, Head);
        if K > 0 then
        begin
          CssHref := EpubRelativeHref(Book.Documents[ADoc].Path, CssPath);
          AddEdit(Edits, K, 0, 0, '<link rel="stylesheet" type="text/css" href="' + CssHref + '"/>');
        end;
      end;
    end;
    Text := ApplyEdits(Src, Edits);
    if Upgrade then
      Text := Html5Text(Text);
    Text := DeclareUtf8(Text);
    // the check: same words, and every new id holds its word
    Lay2 := Book.DocumentSources(ADoc, Check, Text);
    try
      if Lay2.WordCount <> Lay.WordCount then
        raise EEpubError.CreateFmt('Internal error: tagging %s changed its words (%d, was %d)',
          [Book.Documents[ADoc].Path, Lay2.WordCount, Lay.WordCount]);
      for K := 0 to Lay.WordCount - 1 do
        if Lay2.Words[K].Text <> Lay.Words[K].Text then
          raise EEpubError.CreateFmt('Internal error: tagging %s changed word %d ("%s", was "%s")',
            [Book.Documents[ADoc].Path, K + 1, Lay2.Words[K].Text, Lay.Words[K].Text]);
      for K := 0 to High(Lay2.Ids) do
      begin
        N := NewIds.IndexOf(Lay2.Ids[K].Id);
        if N < 0 then
          Continue;
        Local := NativeInt(NewIds.Objects[N]);
        if (Local >= 0) and ((Lay2.Ids[K].FirstWord <> Local) or (Lay2.Ids[K].LastWord <> Local)) then
          raise EEpubError.CreateFmt('Internal error: in %s the new id %s holds words %d-%d, not %d',
            [Book.Documents[ADoc].Path, Lay2.Ids[K].Id, Lay2.Ids[K].FirstWord + 1, Lay2.Ids[K].LastWord + 1,
            Local + 1]);
        NewIds.Delete(N);
      end;
      if NewIds.Count > 0 then
        raise EEpubError.CreateFmt('Internal error: in %s the new id %s is not found again',
          [Book.Documents[ADoc].Path, NewIds[0]]);
    finally
      Lay2.Free;
      Check.Free;
    end;
    PutFile(Book.Documents[ADoc].Path, Text);
    // the overlay
    SetLength(Pars, NPars);
    Raw := Book.Items[Book.Documents[ADoc].Item].MediaOverlay;
    K := -1;
    if Raw <> '' then
      for N := 0 to High(Book.Items) do
        if Book.Items[N].Id = Raw then
          K := N;
    if K >= 0 then
    begin
      // the document's overlay is replaced in place (same item, same file)
      SmilPaths[ADoc] := Book.Items[K].Path;
      SmilIds[ADoc] := Book.Items[K].Id;
      SmilNew[ADoc] := False;
    end
    else
    begin
      // next to the document, its name made portable ('chap two' ->
      // 'chap_two.smil')
      Base := LastPart(Book.Documents[ADoc].Path);
      Base := SafeName(Copy(Base, 1, Length(Base) - Length(ExtractFileExt(Base))));
      Raw := Book.Documents[ADoc].Path;
      SmilPaths[ADoc] := FreePath(Copy(Raw, 1, LastDelimiter('/', Raw)) + Base + '.smil');
      SmilIds[ADoc] := FreeItemId('eu-smil-' + IntToStr(ADoc + 1));
      SmilNew[ADoc] := True;
    end;
    SmilDur[ADoc] := 0;
    for N := 0 to High(Pars) do
      SmilDur[ADoc] := SmilDur[ADoc] + Pars[N].ClipEnd - Pars[N].ClipBegin;
    PutFile(SmilPaths[ADoc], SmilText(ADoc, SmilPaths[ADoc], Pars));
    Inc(Report.Documents);
    Inc(Report.Clips, Length(Pars));
    Report.Duration := Report.Duration + SmilDur[ADoc];
  finally
    Lay.Free;
    Xml.Free;
    Ids.Free;
    BlockKeys.Free;
    NewIds.Free;
  end;
end;

function TSaveJob.SmilText(ADoc: Integer; const ASmilPath: string; const APars: TParArray): string;
var
  SB: TStringList;
  I: Integer;
  TextHref: string;
  AudioHrefs: array of string;
begin
  SetLength(AudioHrefs, W.FAudioPaths.Count);
  for I := 0 to W.FAudioPaths.Count - 1 do
    AudioHrefs[I] := EpubRelativeHref(ASmilPath, W.FAudioPaths[I]);
  TextHref := EpubRelativeHref(ASmilPath, Book.Documents[ADoc].Path);
  SB := TStringList.Create;
  try
    SB.Add('<?xml version="1.0" encoding="UTF-8"?>');
    SB.Add('<smil xmlns="http://www.w3.org/ns/SMIL" xmlns:epub="http://www.idpf.org/2007/ops" version="3.0">');
    SB.Add('<body>');
    SB.Add('<seq epub:textref="' + TextHref + '">');
    for I := 0 to High(APars) do
      SB.Add('<par><text src="' + TextHref + '#' + EpubXmlEscape(APars[I].Id) + '"/><audio src="' +
        AudioHrefs[APars[I].Audio] + '" clipBegin="' + EpubClockText(APars[I].ClipBegin) + '" clipEnd="' +
        EpubClockText(APars[I].ClipEnd) + '"/></par>');
    SB.Add('</seq>');
    SB.Add('</body>');
    SB.Add('</smil>');
    SB.LineBreak := #10;
    Result := SB.Text;
  finally
    SB.Free;
  end;
end;

function TSaveJob.MakeNav: string;
var
  SB: TStringList;
  Toc: TEpubTocArray;
  I, Depth, Lvl: Integer;
  Title, Lang, Href: string;
begin
  Result := FreePath(W.PackageFolder + 'nav.xhtml');
  Toc := Book.Toc;
  Lang := Book.Language;
  if Lang = '' then
    Lang := 'en';
  SB := TStringList.Create;
  try
    SB.LineBreak := #10;
    SB.Add('<?xml version="1.0" encoding="UTF-8"?>');
    SB.Add('<!DOCTYPE html>');
    SB.Add('<html xmlns="' + NS_XHTML + '" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="' +
      EpubXmlEscape(Lang) + '" lang="' + EpubXmlEscape(Lang) + '">');
    SB.Add('<head><title>' + EpubXmlEscape(Book.Title) + '</title></head>');
    SB.Add('<body>');
    SB.Add('<nav epub:type="toc" id="toc">');
    SB.Add('<h1>Contents</h1>');
    SB.Add('<ol>');
    if Length(Toc) = 0 then
    begin
      // no table of contents: one entry per document of the reading order
      for I := 0 to High(Book.Documents) do
        if Book.Documents[I].Linear then
          SB.Add('<li><a href="' + EpubRelativeHref(Result, Book.Documents[I].Path) + '">' +
            EpubXmlEscape(LastPart(Book.Documents[I].Path)) + '</a></li>');
    end
    else
    begin
      Depth := 0;
      for I := 0 to High(Toc) do
      begin
        Lvl := Toc[I].Level;
        if Lvl > Depth + 1 then
          Lvl := Depth + 1;   // a level skipped: one deeper only
        if I > 0 then
        begin
          if Lvl > Depth then
            SB.Add('<ol>')
          else
          begin
            SB.Add('</li>');
            while Depth > Lvl do
            begin
              SB.Add('</ol></li>');
              Dec(Depth);
            end;
          end;
        end
        else
          Lvl := 0;
        Depth := Lvl;
        Title := Trim(Toc[I].Title);
        if Title = '' then
          Title := LastPart(Toc[I].Path);
        Href := EpubRelativeHref(Result, Toc[I].Path);
        if Toc[I].Fragment <> '' then
          Href := Href + '#' + Toc[I].Fragment;
        SB.Add('<li><a href="' + EpubXmlEscape(Href) + '">' + EpubXmlEscape(Title) + '</a>');
      end;
      SB.Add('</li>');
      while Depth > 0 do
      begin
        SB.Add('</ol></li>');
        Dec(Depth);
      end;
    end;
    SB.Add('</ol>');
    SB.Add('</nav>');
    SB.Add('</body>');
    SB.Add('</html>');
    PutFile(Result, SB.Text);
  finally
    SB.Free;
  end;
end;

procedure TSaveJob.WriteChapters;
var
  I: Integer;
  SB: TStringList;
begin
  if Length(W.FChapters) = 0 then
    Exit;
  // a book written before keeps its file (same path, same item)
  ChaptersPath := '';
  for I := 0 to High(Book.Items) do
    if Book.Items[I].Id = EPUB_AUDIO_CHAPTERS_ID then
      ChaptersPath := Book.Items[I].Path;
  if ChaptersPath = '' then
  begin
    if ItemIds.IndexOf(EPUB_AUDIO_CHAPTERS_ID) >= 0 then
    begin
      // the id names something else of the book: the marks are left out
      Report.Warnings := Report.Warnings + Format('The book uses the id %s for something else: the %d ' +
        'chapter marks are not written'#10, [EPUB_AUDIO_CHAPTERS_ID, Length(W.FChapters)]);
      Exit;
    end;
    ChaptersPath := FreePath(W.PackageFolder + 'epubunum-audio-chapters.xml');
    ItemIds.Add(EPUB_AUDIO_CHAPTERS_ID);
    ChaptersNew := True;
  end;
  SB := TStringList.Create;
  try
    SB.Add('<?xml version="1.0" encoding="UTF-8"?>');
    SB.Add('<audio-chapters xmlns="' + EPUB_AUDIO_CHAPTERS_NS + '" version="1">');
    for I := 0 to High(W.FChapters) do
      SB.Add('  <chapter audio="' + EpubXmlEscape(EpubRelativeHref(ChaptersPath,
        W.FAudioPaths[W.FChapters[I].Audio])) + '" begin="' + EpubClockText(W.FChapters[I].Start) +
        '" title="' + EpubXmlEscape(W.FChapters[I].Title) + '"/>');
    SB.Add('</audio-chapters>');
    SB.LineBreak := #10;
    PutFile(ChaptersPath, SB.Text);
  finally
    SB.Free;
  end;
end;

procedure TSaveJob.UpdatePackage(const ANavPath: string);
var
  Opf, Text, Prop, Refines, Id, Role, FileAs, Metas, Items: string;
  Doc: TEpubXmlDoc;
  Root, Meta, Manifest, E: TEpubXmlNode;
  Edits: TTextEdits;
  I, K, Dates: Integer;
  Attrs, Kept: TEpubXmlAttrArray;
  Changed: Boolean;
  Rewritten: TStringList;   // SMIL ids of the overlays written now
  Durations: TStringList;   // SMIL id -> seconds of kept overlays (text)
  Total, D: Double;
  FS: TFormatSettings;
  Found: Boolean;

  { Removes element AEl (start tag to end tag) and the white space before
    it on its line. }
  procedure RemoveElement(AEl: TEpubXmlNode);
  var
    S, E: Integer;
  begin
    if AEl.SrcEnd = 0 then
      Exit;
    S := AEl.SrcPos;
    E := AEl.SrcEnd;
    while (S > 1) and CharInSet(Opf[S - 1], [' ', #9]) do
      Dec(S);
    // alone on its line: the line goes
    if (S = 1) or (Opf[S - 1] = #10) then
    begin
      while (E <= Length(Opf)) and CharInSet(Opf[E], [' ', #9]) do
        Inc(E);
      if (E <= Length(Opf)) and (Opf[E] = #13) then
        Inc(E);
      if (E <= Length(Opf)) and (Opf[E] = #10) then
        Inc(E)
      else
      begin
        S := AEl.SrcPos;
        E := AEl.SrcEnd;
      end;
    end;
    AddEdit(Edits, S, E - S, 0, '');
  end;

  { Inserts ALines (each ended by #10) as the last children of AEl, in the
    file's line breaks and the indent of its first child. }
  procedure AppendChildren(AEl: TEpubXmlNode; const ALines: string);
  var
    P, Q, K: Integer;
    Indent, Br, S: string;
  begin
    P := EndTagStart(Opf, AEl);
    Br := #10;
    if Pos(#13#10, Opf) > 0 then
      Br := #13#10;
    // the indent of the first child element
    Indent := '';
    for K := 0 to AEl.ChildCount - 1 do
      if AEl.Children[K].Kind = xnElement then
      begin
        Q := AEl.Children[K].SrcPos;
        while (Q > 1) and CharInSet(Opf[Q - 1], [' ', #9]) do
          Dec(Q);
        if (Q > 1) and (Opf[Q - 1] = #10) then
          Indent := Copy(Opf, Q, AEl.Children[K].SrcPos - Q);
        Break;
      end;
    S := StringReplace(ALines, #10, Br + Indent, [rfReplaceAll]);
    // at the start of the end tag's line when it stands alone there
    Q := P;
    while (Q > 1) and CharInSet(Opf[Q - 1], [' ', #9]) do
      Dec(Q);
    if (Q > 1) and (Opf[Q - 1] = #10) then
      AddEdit(Edits, Q, 0, 1, Indent + Copy(S, 1, Length(S) - Length(Indent)))
    else
      AddEdit(Edits, P, 0, 1, Br + Indent + Copy(S, 1, Length(S) - Length(Indent)));
  end;

begin
  FS := FormatSettings;
  FS.DecimalSeparator := '.';
  Opf := Book.ReadResourceText(Book.PackagePath);
  Doc := TEpubXmlDoc.Create(Opf);
  Rewritten := TStringList.Create;
  Durations := TStringList.Create;
  try
    Edits := Default(TTextEdits);
    Root := Doc.DocumentElement;
    Meta := Root.Child('metadata');
    Manifest := Root.Child('manifest');
    if (Meta = nil) or (Manifest = nil) or (EndTagStart(Opf, Meta) = 0) or (EndTagStart(Opf, Manifest) = 0) then
      raise EEpubError.CreateFmt('%s: the package document cannot be updated (no metadata or manifest end tag)',
        [Book.FileName]);
    for I := 0 to High(SmilIds) do
      if SmilPaths[I] <> '' then
        Rewritten.Add(SmilIds[I]);
    // package: EPUB 3
    if Upgrade then
    begin
      Attrs := Copy(Root.Attrs, 0, Length(Root.Attrs));
      SetAttr(Attrs, 'version', '3.0');
      AddEdit(Edits, Root.SrcPos, Root.SrcLen, 0, StartTag(Root, Attrs, False));
    end;
    // metadata
    Metas := '';
    Dates := 0;
    for I := 0 to Meta.ChildCount - 1 do
    begin
      E := Meta.Children[I];
      if E.Kind <> xnElement then
        Continue;
      if E.LocalName = 'meta' then
      begin
        Prop := E.Attr('property');
        Refines := E.Attr('refines');
        if (Prop = 'dcterms:modified') or ((Prop = 'media:narrator') and (W.FNarrator <> '')) then
          RemoveElement(E)
        else if Prop = 'media:duration' then
        begin
          if (Refines = '') or (Rewritten.IndexOf(Copy(Refines, 2, MaxInt)) >= 0) then
            RemoveElement(E)
          else
          begin
            D := EpubClockValue(E.InnerText);
            if D >= 0 then
              Durations.Values[Copy(Refines, 2, MaxInt)] := FloatToStr(D, FS);
          end;
        end;
        Continue;
      end;
      if not Upgrade then
        Continue;
      if E.LocalName = 'date' then
      begin
        Inc(Dates);
        if Dates > 1 then
        begin
          RemoveElement(E);   // EPUB 3 allows one dc:date
          Continue;
        end;
      end;
      // opf: attributes are EPUB 2 only; so is xsi:type (EPUB 2's
      // <dc:language xsi:type="dcterms:RFC4646">, Project Gutenberg's)
      Changed := False;
      Kept := nil;
      Role := '';
      FileAs := '';
      for K := 0 to High(E.Attrs) do
        if SameText(Copy(E.Attrs[K].Name, 1, 4), 'opf:') or SameText(Copy(E.Attrs[K].Name, 1, 4), 'xsi:') then
        begin
          Changed := True;
          if SameText(E.Attrs[K].Name, 'opf:role') then
            Role := E.Attrs[K].Value
          else if SameText(E.Attrs[K].Name, 'opf:file-as') then
            FileAs := E.Attrs[K].Value;
        end
        else
        begin
          SetLength(Kept, Length(Kept) + 1);
          Kept[High(Kept)] := E.Attrs[K];
        end;
      if not Changed then
        Continue;
      if ((E.LocalName = 'creator') or (E.LocalName = 'contributor')) and ((Role <> '') or (FileAs <> '')) then
      begin
        Id := E.Attr('id');
        if Id = '' then
        begin
          Id := FreeItemId('eu-' + E.LocalName + '-' + IntToStr(I + 1));
          SetAttr(Kept, 'id', Id);
        end;
        if Role <> '' then
          Metas := Metas + '<meta refines="#' + EpubXmlEscape(Id) +
            '" property="role" scheme="marc:relators">' + EpubXmlEscape(Role) + '</meta>'#10;
        if FileAs <> '' then
          Metas := Metas + '<meta refines="#' + EpubXmlEscape(Id) + '" property="file-as">' +
            EpubXmlEscape(FileAs) + '</meta>'#10;
      end;
      AddEdit(Edits, E.SrcPos, E.SrcLen, 0, StartTag(E, Kept, IsSelfClosed(Opf, E)));
    end;
    // durations: the new overlays, the kept ones, the total
    Total := 0;
    for I := 0 to High(SmilPaths) do
      if SmilPaths[I] <> '' then
      begin
        Metas := Metas + '<meta property="media:duration" refines="#' + EpubXmlEscape(SmilIds[I]) + '">' +
          EpubClockText(SmilDur[I]) + '</meta>'#10;
        Total := Total + SmilDur[I];
      end;
    for I := 0 to High(Book.Documents) do
    begin
      Id := Book.Items[Book.Documents[I].Item].MediaOverlay;
      if (Id = '') or (SmilPaths[I] <> '') or (Rewritten.IndexOf(Id) >= 0) then
        Continue;
      Rewritten.Add(Id);   // counted once
      if Durations.IndexOfName(Id) >= 0 then
        Total := Total + StrToFloat(Durations.Values[Id], FS)
      else
      begin
        // a kept overlay without media:duration: its clips' length
        D := 0;
        for K := 0 to High(Book.Clips) do
          if (Book.Clips[K].Document = I) and (Book.Clips[K].ClipEnd > Book.Clips[K].ClipBegin) then
            D := D + Book.Clips[K].ClipEnd - Book.Clips[K].ClipBegin;
        Metas := Metas + '<meta property="media:duration" refines="#' + EpubXmlEscape(Id) + '">' +
          EpubClockText(D) + '</meta>'#10;
        Total := Total + D;
      end;
    end;
    Metas := Metas + '<meta property="media:duration">' + EpubClockText(Total) + '</meta>'#10;
    if W.FNarrator <> '' then
      Metas := Metas + '<meta property="media:narrator">' + EpubXmlEscape(W.FNarrator) + '</meta>'#10;
    if not HasActiveClass then
      Metas := Metas + '<meta property="media:active-class">' + EpubXmlEscape(W.FActiveClass) + '</meta>'#10;
    Metas := Metas + '<meta property="dcterms:modified">' + ModifiedNow + '</meta>'#10;
    AppendChildren(Meta, Metas);
    // manifest: overlays on the documents' items, then the new items
    Items := '';
    for I := 0 to Manifest.ChildCount - 1 do
    begin
      E := Manifest.Children[I];
      if (E.Kind <> xnElement) or (E.LocalName <> 'item') then
        Continue;
      Attrs := Copy(E.Attrs, 0, Length(E.Attrs));
      Changed := False;
      for K := 0 to High(Book.Documents) do
        if SmilNew[K] and (Book.Items[Book.Documents[K].Item].Id = E.Attr('id')) then
        begin
          SetAttr(Attrs, 'media-overlay', SmilIds[K]);
          Changed := True;
        end;
      // a space is not allowed in an href (EPUB 3): encoded, same file
      if Pos(' ', E.Attr('href')) > 0 then
      begin
        SetAttr(Attrs, 'href', StringReplace(E.Attr('href'), ' ', '%20', [rfReplaceAll]));
        Changed := True;
      end;
      if Changed then
        AddEdit(Edits, E.SrcPos, E.SrcLen, 0, StartTag(E, Attrs, IsSelfClosed(Opf, E)));
    end;
    for I := 0 to High(SmilPaths) do
      if SmilNew[I] then
        Items := Items + '<item id="' + EpubXmlEscape(SmilIds[I]) + '" href="' +
          EpubXmlEscape(EpubRelativeHref(Book.PackagePath, SmilPaths[I])) +
          '" media-type="application/smil+xml"/>'#10;
    for I := 0 to W.FAudioPaths.Count - 1 do
    begin
      // an audio file of the book that the manifest lists already is kept
      Found := False;
      for K := 0 to High(Book.Items) do
        if SameText(Book.Items[K].Path, W.FAudioPaths[I]) then
          Found := True;
      if Found then
        Continue;
      Items := Items + '<item id="' + EpubXmlEscape(FreeItemId('eu-audio-' + IntToStr(I + 1))) + '" href="' +
        EpubXmlEscape(EpubRelativeHref(Book.PackagePath, W.FAudioPaths[I])) + '" media-type="' +
        AudioMediaType(W.FAudioPaths[I]) + '"/>'#10;
    end;
    if CssPath <> '' then
      Items := Items + '<item id="' + EpubXmlEscape(FreeItemId('eu-overlay-css')) + '" href="' +
        EpubXmlEscape(EpubRelativeHref(Book.PackagePath, CssPath)) + '" media-type="text/css"/>'#10;
    if ChaptersNew then
      Items := Items + '<item id="' + EPUB_AUDIO_CHAPTERS_ID + '" href="' +
        EpubXmlEscape(EpubRelativeHref(Book.PackagePath, ChaptersPath)) + '" media-type="application/xml"/>'#10;
    if ANavPath <> '' then
      Items := Items + '<item id="' + EpubXmlEscape(FreeItemId('eu-nav')) + '" href="' +
        EpubXmlEscape(EpubRelativeHref(Book.PackagePath, ANavPath)) +
        '" media-type="application/xhtml+xml" properties="nav"/>'#10;
    if Items <> '' then
      AppendChildren(Manifest, Items);
    Text := DeclareUtf8(ApplyEdits(Opf, Edits));
    PutFile(Book.PackagePath, Text);
  finally
    Doc.Free;
    Rewritten.Free;
    Durations.Free;
  end;
end;

procedure TSaveJob.WriteArchive(const AFileName: string);
var
  Z: TEpubZipWriter;
  I, K: Integer;
  Name: string;
  Done: TStringList;
begin
  Done := TStringList.Create;
  Z := TEpubZipWriter.Create(AFileName);
  try
    Done.Sorted := True;
    Z.AddEpubMimetype;
    // the book's files in their order, the changed ones replaced
    for I := 0 to High(Book.Zip.Entries) do
    begin
      Name := Book.Zip.Entries[I].Name;
      if Name = 'mimetype' then
        Continue;
      K := NewFileIndex(Name);
      if K >= 0 then
      begin
        Z.Add(Name, NewFiles[K].Text);
        Done.Add(Name);
      end
      else
        Z.AddRaw(Book.Zip, I);
    end;
    // new files
    for K := 0 to High(NewFiles) do
      if Done.IndexOf(NewFiles[K].Path) < 0 then
        Z.Add(NewFiles[K].Path, NewFiles[K].Text);
    for I := 0 to W.FAudioPaths.Count - 1 do
      if W.FAudioFiles[I] <> '' then
        Z.AddFileStored(W.FAudioPaths[I], W.FAudioFiles[I]);
    Z.Finish;
  finally
    Z.Free;
    Done.Free;
  end;
end;

procedure TEpubWriter.SaveToFile(const AFileName: string);
var
  Job: TSaveJob;
  I, J, Doc: Integer;
  NavPath, Opf: string;
  Words: TEpubWordArray;
  Ver: Double;
  FS: TFormatSettings;
  OpfDoc: TEpubXmlDoc;
  Metas: TEpubXmlNodeArray;
begin
  if SameText(ExpandFileName(AFileName), ExpandFileName(FBook.FileName)) then
    raise EEpubError.CreateFmt('%s is the book being read: write the new book to another file', [AFileName]);
  FReport := Default(TEpubWriteReport);
  Job := TSaveJob.Create(Self);
  try
    try
      Job.FilterTimed;
      if Length(Job.Timed) = 0 then
        raise EEpubError.Create('No timed words to write (none given, or none of them valid)');
      FS := FormatSettings;
      FS.DecimalSeparator := '.';
      Ver := StrToFloatDef(FBook.Version, 2, FS);
      Job.Upgrade := Ver < 3;
      Job.Report.Upgraded := Job.Upgrade;
      // does the book name its own active class?
      Opf := FBook.ReadResourceText(FBook.PackagePath);
      OpfDoc := TEpubXmlDoc.Create(Opf);
      try
        Metas := OpfDoc.Root.FindAll('meta');
        for I := 0 to High(Metas) do
          if Metas[I].Attr('property') = 'media:active-class' then
            Job.HasActiveClass := True;
        Metas := OpfDoc.Root.FindAll('item');
        for I := 0 to High(Metas) do
          Job.ItemIds.Add(Metas[I].Attr('id'));
        CollectIds(OpfDoc.Root, Job.ItemIds);
      finally
        OpfDoc.Free;
      end;
      if not Job.HasActiveClass then
      begin
        Job.CssPath := Job.FreePath(PackageFolder + 'epubunum-overlay.css');
        Job.PutFile(Job.CssPath, '.' + FActiveClass + ' {'#10'  background-color: ' + FHighlightColor + ';'#10 +
          '}'#10);
      end;
      // the documents, a run of timed words each
      Words := FBook.Words;
      I := 0;
      while I <= High(Job.Timed) do
      begin
        Doc := Words[Job.Timed[I].Word].Document;
        J := I;
        while (J < High(Job.Timed)) and (Words[Job.Timed[J + 1].Word].Document = Doc) do
          Inc(J);
        if Pos('html', FBook.Items[FBook.Documents[Doc].Item].MediaType) > 0 then
          Job.TagDocument(Doc, I, J)
        else
          Inc(Job.Report.Skipped, J - I + 1);
        I := J + 1;
      end;
      // EPUB 3: the HTML5 doctype everywhere, a nav document
      NavPath := '';
      if Job.Upgrade then
      begin
        for I := 0 to High(FBook.Items) do
          if (FBook.Items[I].MediaType = 'application/xhtml+xml') and FBook.Zip.Exists(FBook.Items[I].Path) then
          begin
            Opf := Job.FileText(FBook.Items[I].Path);
            if Html5Text(Opf) <> Opf then
              Job.PutFile(FBook.Items[I].Path, DeclareUtf8(Html5Text(Opf)));
          end;
        J := 0;
        for I := 0 to High(FBook.Items) do
          if Pos(' nav ', ' ' + FBook.Items[I].Properties + ' ') > 0 then
            J := 1;
        if J = 0 then
          NavPath := Job.MakeNav;
      end;
      Job.WriteChapters;
      Job.UpdatePackage(NavPath);
      for I := 0 to FAudioPaths.Count - 1 do
        if (AudioMediaType(FAudioPaths[I]) <> 'audio/mpeg') and (AudioMediaType(FAudioPaths[I]) <> 'audio/mp4') then
          Job.Report.Warnings := Job.Report.Warnings + Format('%s is %s: EPUB 3 readers are only required to ' +
            'play MP3 and AAC (MP4), so others may stay silent'#10, [FAudioPaths[I],
            AudioMediaType(FAudioPaths[I])]);
      Job.WriteArchive(AFileName);
      FReport := Job.Report;
    except
      if FileExists(AFileName) then
        DeleteFile(AFileName);
      raise;
    end;
  finally
    Job.Free;
  end;
end;

end.
