(* @abstract(@link(TEpubBook): an EPUB 2 or 3 book - metadata, manifest,
  reading order (spine), table of contents, cover, the text as words with
  their place and role, and the media overlays that sync it with audio.)

  What a reader needs: open the book, list its contents, show a document
  (@link(TEpubBook.ExtractAll) puts the files where a web view can load
  them), and, for a book with media overlays, find which text belongs to
  the current audio time (@link(TEpubBook.ClipAt)) to highlight it.

  Copy-protected books are refused with a message, never decrypted:
  META-INF/encryption.xml naming anything but font obfuscation,
  META-INF/rights.xml (Adobe ADEPT) or META-INF/sinf.xml (Apple FairPlay).

  The text (@link(TEpubBook.Words)) keeps every word's document, the id of
  the element it sits in, and its role: body text, heading, caption, note,
  table, preformatted or navigation - so an aligner can leave captions and
  notes out of what it expects to hear, and media overlays can point at
  the right element. Roles come from markup only: epub:type, ARIA roles
  (doc-footnote, doc-endnotes, ...) and class names containing 'caption',
  'footnote', 'endnote' or 'note' - never from the words themselves.

  Framework-free; compiles with Delphi and FPC. *)
unit Epub.Book;

{$I Epub.inc}

interface

uses
  SysUtils, Classes,
  Epub.Zip, Epub.Xml, Epub.Css, Epub.Layout;

type
  { One manifest item. }
  TEpubItem = record
    { The item's id. }
    Id: string;
    { href as written in the package. }
    Href: string;
    { Full path inside the archive (resolved against the package folder,
      percent-decoded). }
    Path: string;
    { Media type ('application/xhtml+xml', 'audio/mp4', ...). }
    MediaType: string;
    { properties ('nav', 'cover-image', 'scripted', ...; EPUB 3). }
    Properties: string;
    { Id of this item's media overlay (SMIL) item, '' when none. }
    MediaOverlay: string;
  end;
  { Manifest items in package order. }
  TEpubItemArray = array of TEpubItem;

  { One element id inside a document and the words it holds. }
  TEpubIdRange = record
    { The id. }
    Id: string;
    { First word (index into @link(TEpubBook.Words)), -1 when it holds none. }
    FirstWord: Integer;
    { Last word, -1 when it holds none. }
    LastWord: Integer;
  end;
  { Ids of a document, in document order. }
  TEpubIdRangeArray = array of TEpubIdRange;

  { One document of the reading order (the spine). }
  TEpubDocument = record
    { Index of its manifest item. }
    Item: Integer;
    { Full path inside the archive. }
    Path: string;
    { linear="no" in the spine makes it False (notes, pop-ups). }
    Linear: Boolean;
    { Its first word in @link(TEpubBook.Words) (valid after LoadText). }
    FirstWord: Integer;
    { Number of its words (after LoadText). }
    WordCount: Integer;
    { Its element ids and their words (after LoadText). }
    Ids: TEpubIdRangeArray;
  end;
  { The reading order. }
  TEpubDocumentArray = array of TEpubDocument;

  { One table of contents entry. }
  TEpubTocEntry = record
    { The entry's text. }
    Title: string;
    { Document path inside the archive. }
    Path: string;
    { Fragment (element id) after '#', '' when none. }
    Fragment: string;
    { Nesting depth, 0 for the top level. }
    Level: Integer;
    { Index of the document in @link(TEpubBook.Documents), -1 when it is
      not in the reading order. }
    Document: Integer;
  end;
  { The table of contents in reading order. }
  TEpubTocArray = array of TEpubTocEntry;

  { One word of the book's text. }
  TEpubWord = record
    { The word as written, punctuation included. }
    Text: string;
    { Index of its document in @link(TEpubBook.Documents). }
    Document: Integer;
    { Index of the innermost element with an id around it, in that
      document's Ids; -1 when none. (The role type and its names are in
      Epub.Layout.) }
    IdIndex: Integer;
    { What it is part of. }
    Role: TEpubWordRole;
  end;
  { The words of the reading order. }
  TEpubWordArray = array of TEpubWord;

  { One clip of a media overlay: a stretch of audio and the element it
    reads. }
  TEpubClip = record
    { Document (index into @link(TEpubBook.Documents)), -1 when the text
      is outside the reading order. }
    Document: Integer;
    { Full path of the text document inside the archive. }
    TextPath: string;
    { Element id in that document. }
    TextId: string;
    { Full path of the audio file inside the archive. }
    AudioPath: string;
    { Start in the audio file, s. }
    ClipBegin: Double;
    { End in the audio file, s (0 when not given: to the next clip or the end). }
    ClipEnd: Double;
  end;
  { Clips in reading order. }
  TEpubClipArray = array of TEpubClip;

  { An EPUB book. }
  TEpubBook = class
  private
    { The archive. }
    FZip: TEpubZipReader;
    { Backing field of @link(FileName). }
    FFileName: string;
    { Backing field of @link(PackagePath). }
    FPackagePath: string;
    { Backing field of @link(Version). }
    FVersion: string;
    { Backing field of @link(Title). }
    FTitle: string;
    { Backing field of @link(Creators). }
    FCreators: TStringList;
    { Backing field of @link(Language). }
    FLanguage: string;
    { Backing field of @link(Identifier). }
    FIdentifier: string;
    { Backing field of @link(Publisher). }
    FPublisher: string;
    { Backing field of @link(Date). }
    FDate: string;
    { Backing field of @link(Items). }
    FItems: TEpubItemArray;
    { Backing field of @link(Documents). }
    FDocuments: TEpubDocumentArray;
    { Backing field of @link(Toc). }
    FToc: TEpubTocArray;
    { Backing field of @link(CoverPath). }
    FCoverPath: string;
    { Backing field of @link(Words). }
    FWords: TEpubWordArray;
    { Words in use in FWords. }
    FWordCount: Integer;
    { LoadText ran. }
    FTextLoaded: Boolean;
    { Backing field of @link(Clips). }
    FClips: TEpubClipArray;
    { Backing field of @link(ActiveClass). }
    FActiveClass: string;
    { Backing field of @link(MediaDuration). }
    FMediaDuration: Double;
    { Style sheets by document path (TEpubStyleSheet objects, owned). }
    FSheets: TStringList;
    { Refuses a copy-protected book. }
    procedure CheckProtection;
    { Reads META-INF/container.xml and the package document. }
    procedure ReadPackage;
    { Reads the EPUB 3 nav document. }
    procedure ReadNav(const APath: string);
    { Reads the EPUB 2 NCX. }
    procedure ReadNcx(const APath: string);
    { Reads every media overlay. }
    procedure ReadOverlays;
    { Index of the document with APath, -1 when none. }
    function DocumentOf(const APath: string): Integer;
    { Index of the manifest item with AId, -1 when none. }
    function ItemOf(const AId: string): Integer;
    { The words of the text, trimmed (LoadText first). }
    function GetWords: TEpubWordArray;
    { Number of words (LoadText first). }
    function GetWordCount: Integer;
    { The words of document ADoc. }
    procedure LoadDocumentText(ADoc: Integer);
    { The style sheets of document ADoc (its links and style elements),
      parsed once; owned by the book. }
    function StyleSheetOf(ADoc: Integer; ADocXml: TEpubXmlDoc): TEpubStyleSheet;
    { Parses document ADoc; the caller frees the result. }
    function ParseDocument(ADoc: Integer): TEpubXmlDoc;
  public
    { Opens AFileName and reads its package, contents and media overlays.
      @raises(EEpubError when it is not an EPUB, is damaged or is copy
        protected.) }
    constructor Create(const AFileName: string);
    { Closes the book. }
    destructor Destroy; override;
    { Reads the text of every document into @link(Words) (done on first use
      of Words; call it to control when the work happens). }
    procedure LoadText;
    { The layout of document ADoc with its blocks, for a renderer: word
      indexes in it are local; add @code(Documents[ADoc].FirstWord) for
      @link(Words). The caller frees it. }
    function DocumentLayout(ADoc: Integer): TEpubDocLayout;
    { The document and block showing word AWord (an index into
      @link(Words)) in ALayout (DocumentLayout of that document); -1 when
      ALayout is not that document's or the word has no block. }
    function BlockOfWord(ALayout: TEpubDocLayout; ADoc, AWord: Integer): Integer;
    { The raw bytes of file APath inside the book (an image, audio, a
      style sheet).
      @raises(EEpubError when there is no such file.) }
    function ReadResource(const APath: string): TBytes;
    { File APath inside the book as text. }
    function ReadResourceText(const APath: string): string;
    { Writes every file of the book under AFolder, keeping the paths, so a
      web view can show the documents with their images and styles. Audio
      is written too unless ASkipAudio. Returns the folder with a trailing
      delimiter. }
    function ExtractAll(const AFolder: string; ASkipAudio: Boolean = False): string;
    { The clip playing at ATime seconds of audio file AAudioPath, -1 when
      none (a gap, or before the first clip). }
    function ClipAt(const AAudioPath: string; ATime: Double): Integer;
    { The words of clip AClip: AFirst..ALast in @link(Words); False when the
      clip points at nothing with words. }
    function ClipWords(AClip: Integer; out AFirst, ALast: Integer): Boolean;
    { The audio files of the overlays, in reading order (no repeats). }
    function AudioFiles: TStringList;
    { Full archive path of AHref as written in document ABase (relative
      paths resolved, '%20' decoded, fragment dropped). }
    class function ResolvePath(const ABase, AHref: string): string; static;
    { The archive (for anything not covered here). }
    property Zip: TEpubZipReader read FZip;
    { The file. }
    property FileName: string read FFileName;
    { Path of the package document (OPF) inside the archive. }
    property PackagePath: string read FPackagePath;
    { '2.0', '3.0', ... from the package element. }
    property Version: string read FVersion;
    { The title. }
    property Title: string read FTitle;
    { Authors (creators), in order. }
    property Creators: TStringList read FCreators;
    { Language code ('en', 'en-GB'). }
    property Language: string read FLanguage;
    { The unique identifier (ISBN, UUID, ...). }
    property Identifier: string read FIdentifier;
    { The publisher. }
    property Publisher: string read FPublisher;
    { Publication date as written. }
    property Date: string read FDate;
    { The manifest. }
    property Items: TEpubItemArray read FItems;
    { The reading order. }
    property Documents: TEpubDocumentArray read FDocuments;
    { The table of contents (nav for EPUB 3, NCX for EPUB 2). }
    property Toc: TEpubTocArray read FToc;
    { Path of the cover image inside the archive, '' when none. }
    property CoverPath: string read FCoverPath;
    { The text of the reading order, word by word (loads it on first use). }
    property Words: TEpubWordArray read GetWords;
    { Number of words (loads the text on first use). }
    property WordCount: Integer read GetWordCount;
    { Media overlay clips in reading order (empty: no synced audio). }
    property Clips: TEpubClipArray read FClips;
    { CSS class a reader sets on the element being read
      (media:active-class; '-epub-media-overlay-active' when not given). }
    property ActiveClass: string read FActiveClass;
    { Total audio length from media:duration, s (0 when not given). }
    property MediaDuration: Double read FMediaDuration;
  end;

{ A SMIL clock value in seconds: '1:02:03.5', '02:03.5', '12.5s', '500ms',
  '1.5min', '0.5h', '12.5' (seconds); -1 when it cannot be read. }
function EpubClockValue(const AText: string): Double;

implementation

const
  { Algorithms in encryption.xml that are font obfuscation, not DRM. }
  FONT_OBFUSCATION: array[0..1] of string = ('http://www.idpf.org/2008/embedding',
    'http://ns.adobe.com/pdf/enc#RC');
  { The class EPUB names when media:active-class is not given. }
  DEFAULT_ACTIVE_CLASS = '-epub-media-overlay-active';
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

function EpubClockValue(const AText: string): Double;
var
  S: string;
  Parts: TStringList;
  FS: TFormatSettings;
  V: Double;
  Mult: Double;
  I: Integer;
begin
  Result := -1;
  S := LowerCase(Trim(AText));
  if Copy(S, 1, 4) = 'npt=' then
    S := Copy(S, 5, MaxInt);
  if S = '' then
    Exit;
  FS := FormatSettings;   // a copy; only the decimal separator is changed
  FS.DecimalSeparator := '.';
  if Pos(':', S) > 0 then
  begin
    Parts := TStringList.Create;
    try
      Parts.Delimiter := ':';
      Parts.StrictDelimiter := True;
      Parts.DelimitedText := S;
      Result := 0;
      for I := 0 to Parts.Count - 1 do
      begin
        if not TryStrToFloat(Parts[I], V, FS) then
          Exit(-1);
        Result := Result * 60 + V;
      end;
    finally
      Parts.Free;
    end;
    Exit;
  end;
  Mult := 1;
  if Copy(S, Length(S) - 1, 2) = 'ms' then
  begin
    Mult := 0.001;
    SetLength(S, Length(S) - 2);
  end
  else if Copy(S, Length(S) - 2, 3) = 'min' then
  begin
    Mult := 60;
    SetLength(S, Length(S) - 3);
  end
  else if (S <> '') and (S[Length(S)] = 'h') then
  begin
    Mult := 3600;
    SetLength(S, Length(S) - 1);
  end
  else if (S <> '') and (S[Length(S)] = 's') then
    SetLength(S, Length(S) - 1);
  if TryStrToFloat(S, V, FS) then
    Result := V * Mult;
end;

{ TEpubBook }

class function TEpubBook.ResolvePath(const ABase, AHref: string): string;
begin
  Result := EpubResolvePath(ABase, AHref);
end;

constructor TEpubBook.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
  FCreators := TStringList.Create;
  FSheets := TStringList.Create;
  FSheets.OwnsObjects := True;
  FActiveClass := DEFAULT_ACTIVE_CLASS;
  FZip := TEpubZipReader.Create(AFileName);
  CheckProtection;
  ReadPackage;
  ReadOverlays;
end;

destructor TEpubBook.Destroy;
begin
  FZip.Free;
  FCreators.Free;
  FSheets.Free;
  inherited;
end;

procedure TEpubBook.CheckProtection;
var
  D: TEpubXmlDoc;
  Methods: TEpubXmlNodeArray;
  I: Integer;
  Alg: string;
begin
  if FZip.Exists('META-INF/rights.xml') then
    raise EEpubError.CreateFmt('%s is copy protected (Adobe DRM, META-INF/rights.xml): it cannot be ' +
      'read. A DRM-free copy is needed.', [FFileName]);
  if FZip.Exists('META-INF/sinf.xml') then
    raise EEpubError.CreateFmt('%s is copy protected (Apple FairPlay, META-INF/sinf.xml): it cannot ' +
      'be read. A DRM-free copy is needed.', [FFileName]);
  if not FZip.Exists('META-INF/encryption.xml') then
    Exit;
  D := TEpubXmlDoc.Create(FZip.ReadText('META-INF/encryption.xml'));
  try
    Methods := D.Root.FindAll('EncryptionMethod');
    for I := 0 to High(Methods) do
    begin
      Alg := Methods[I].Attr('Algorithm');
      if not InList(Alg, FONT_OBFUSCATION) then
        raise EEpubError.CreateFmt('%s is copy protected (encrypted content, %s): it cannot be read. ' +
          'A DRM-free copy is needed.', [FFileName, Alg]);
    end;
  finally
    D.Free;
  end;
end;

function TEpubBook.ItemOf(const AId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FItems) do
    if FItems[I].Id = AId then
      Exit(I);
  Result := -1;
end;

function TEpubBook.DocumentOf(const APath: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FDocuments) do
    if SameText(FDocuments[I].Path, APath) then
      Exit(I);
  Result := -1;
end;

procedure TEpubBook.ReadPackage;
var
  C, D: TEpubXmlDoc;
  Root, Meta, Manifest, Spine, N: TEpubXmlNode;
  List: TEpubXmlNodeArray;
  I, K: Integer;
  Item: TEpubItem;
  NcxId, NavPath, CoverId, Prop: string;
begin
  if not FZip.Exists('META-INF/container.xml') then
    raise EEpubError.CreateFmt('%s is not an EPUB (no META-INF/container.xml)', [FFileName]);
  C := TEpubXmlDoc.Create(FZip.ReadText('META-INF/container.xml'));
  try
    N := C.Root.Find('rootfile');
    if N = nil then
      raise EEpubError.CreateFmt('%s: META-INF/container.xml names no package', [FFileName]);
    FPackagePath := ResolvePath('', N.Attr('full-path'));
  finally
    C.Free;
  end;
  if not FZip.Exists(FPackagePath) then
    raise EEpubError.CreateFmt('%s: the package %s is missing', [FFileName, FPackagePath]);
  D := TEpubXmlDoc.Create(FZip.ReadText(FPackagePath));
  try
    Root := D.DocumentElement;
    if (Root = nil) or (Root.LocalName <> 'package') then
      raise EEpubError.CreateFmt('%s: %s is not a package document', [FFileName, FPackagePath]);
    FVersion := Root.Attr('version');
    // metadata
    Meta := Root.Child('metadata');
    CoverId := '';
    if Meta <> nil then
    begin
      N := Meta.Child('title');
      if N <> nil then
        FTitle := Trim(N.InnerText);
      List := Meta.FindAll('creator');
      for I := 0 to High(List) do
        FCreators.Add(Trim(List[I].InnerText));
      N := Meta.Child('language');
      if N <> nil then
        FLanguage := Trim(N.InnerText);
      N := Meta.Child('identifier');
      if N <> nil then
        FIdentifier := Trim(N.InnerText);
      N := Meta.Child('publisher');
      if N <> nil then
        FPublisher := Trim(N.InnerText);
      N := Meta.Child('date');
      if N <> nil then
        FDate := Trim(N.InnerText);
      List := Meta.FindAll('meta');
      for I := 0 to High(List) do
      begin
        Prop := List[I].Attr('property');
        if SameText(List[I].Attr('name'), 'cover') then
          CoverId := List[I].Attr('content')
        else if (Prop = 'media:active-class') then
          FActiveClass := Trim(List[I].InnerText)
        else if (Prop = 'media:duration') and (List[I].Attr('refines') = '') then
          FMediaDuration := EpubClockValue(List[I].InnerText);
      end;
      if FMediaDuration < 0 then
        FMediaDuration := 0;
    end;
    // manifest
    Manifest := Root.Child('manifest');
    if Manifest = nil then
      raise EEpubError.CreateFmt('%s: the package has no manifest', [FFileName]);
    List := Manifest.FindAll('item');
    SetLength(FItems, Length(List));
    NavPath := '';
    for I := 0 to High(List) do
    begin
      Item := Default(TEpubItem);
      Item.Id := List[I].Attr('id');
      Item.Href := List[I].Attr('href');
      Item.Path := ResolvePath(FPackagePath, Item.Href);
      Item.MediaType := LowerCase(List[I].Attr('media-type'));
      Item.Properties := List[I].Attr('properties');
      Item.MediaOverlay := List[I].Attr('media-overlay');
      FItems[I] := Item;
      if Pos(' nav ', ' ' + Item.Properties + ' ') > 0 then
        NavPath := Item.Path;
      if Pos(' cover-image ', ' ' + Item.Properties + ' ') > 0 then
        FCoverPath := Item.Path;
    end;
    if (FCoverPath = '') and (CoverId <> '') then
    begin
      I := ItemOf(CoverId);
      if I >= 0 then
        FCoverPath := FItems[I].Path;
    end;
    // spine
    Spine := Root.Child('spine');
    if Spine = nil then
      raise EEpubError.CreateFmt('%s: the package has no spine (reading order)', [FFileName]);
    NcxId := Spine.Attr('toc');
    List := Spine.FindAll('itemref');
    SetLength(FDocuments, 0);
    for I := 0 to High(List) do
    begin
      K := ItemOf(List[I].Attr('idref'));
      if K < 0 then
        Continue;
      SetLength(FDocuments, Length(FDocuments) + 1);
      FDocuments[High(FDocuments)] := Default(TEpubDocument);
      FDocuments[High(FDocuments)].Item := K;
      FDocuments[High(FDocuments)].Path := FItems[K].Path;
      FDocuments[High(FDocuments)].Linear := not SameText(List[I].Attr('linear'), 'no');
    end;
  finally
    D.Free;
  end;
  // table of contents: EPUB 3 nav first, else the EPUB 2 NCX
  if (NavPath <> '') and FZip.Exists(NavPath) then
    ReadNav(NavPath);
  if Length(FToc) = 0 then
  begin
    I := ItemOf(NcxId);
    if I < 0 then
      for K := 0 to High(FItems) do
        if FItems[K].MediaType = 'application/x-dtbncx+xml' then
          I := K;
    if (I >= 0) and FZip.Exists(FItems[I].Path) then
      ReadNcx(FItems[I].Path);
  end;
end;

procedure TEpubBook.ReadNav(const APath: string);
var
  D: TEpubXmlDoc;
  Navs, Links: TEpubXmlNodeArray;
  Nav, A, P: TEpubXmlNode;
  I, Level: Integer;
  Href: string;
  E: TEpubTocEntry;
begin
  D := TEpubXmlDoc.Create(FZip.ReadText(APath), True);
  try
    Navs := D.Root.FindAll('nav');
    Nav := nil;
    for I := 0 to High(Navs) do
      if Pos('toc', Navs[I].Attr('epub:type')) > 0 then
      begin
        Nav := Navs[I];
        Break;
      end;
    if (Nav = nil) and (Length(Navs) > 0) then
      Nav := Navs[0];
    if Nav = nil then
      Exit;
    Links := Nav.FindAll('a');
    for I := 0 to High(Links) do
    begin
      A := Links[I];
      Href := A.Attr('href');
      if Href = '' then
        Continue;
      Level := -1;
      P := A.Parent;
      while (P <> nil) and (P <> Nav) do
      begin
        if P.LocalName = 'ol' then
          Inc(Level);
        P := P.Parent;
      end;
      if Level < 0 then
        Level := 0;
      E := Default(TEpubTocEntry);
      E.Title := Trim(StringReplace(StringReplace(A.InnerText, #10, ' ', [rfReplaceAll]), #13, '',
        [rfReplaceAll]));
      E.Path := ResolvePath(APath, Href);
      if Pos('#', Href) > 0 then
        E.Fragment := Copy(Href, Pos('#', Href) + 1, MaxInt);
      E.Level := Level;
      E.Document := DocumentOf(E.Path);
      SetLength(FToc, Length(FToc) + 1);
      FToc[High(FToc)] := E;
    end;
  finally
    D.Free;
  end;
end;

procedure TEpubBook.ReadNcx(const APath: string);
var
  D: TEpubXmlDoc;

  procedure Walk(AParent: TEpubXmlNode; ALevel: Integer);
  var
    I: Integer;
    C, Lab, Content: TEpubXmlNode;
    Src: string;
    E: TEpubTocEntry;
  begin
    for I := 0 to AParent.ChildCount - 1 do
    begin
      C := AParent.Children[I];
      if (C.Kind <> xnElement) or (C.LocalName <> 'navpoint') then
        Continue;
      Lab := C.Child('navLabel');
      Content := C.Child('content');
      if Content <> nil then
      begin
        Src := Content.Attr('src');
        E := Default(TEpubTocEntry);
        if Lab <> nil then
          E.Title := Trim(Lab.InnerText);
        E.Path := ResolvePath(APath, Src);
        if Pos('#', Src) > 0 then
          E.Fragment := Copy(Src, Pos('#', Src) + 1, MaxInt);
        E.Level := ALevel;
        E.Document := DocumentOf(E.Path);
        SetLength(FToc, Length(FToc) + 1);
        FToc[High(FToc)] := E;
      end;
      Walk(C, ALevel + 1);
    end;
  end;

var
  Map: TEpubXmlNode;
begin
  D := TEpubXmlDoc.Create(FZip.ReadText(APath));
  try
    Map := D.Root.Find('navMap');
    if Map <> nil then
      Walk(Map, 0);
  finally
    D.Free;
  end;
end;

procedure TEpubBook.ReadOverlays;
var
  I, K: Integer;
  D: TEpubXmlDoc;
  Pars: TEpubXmlNodeArray;
  T, A: TEpubXmlNode;
  Src, SmilPath: string;
  Clip: TEpubClip;
begin
  for I := 0 to High(FDocuments) do
  begin
    if FItems[FDocuments[I].Item].MediaOverlay = '' then
      Continue;
    K := ItemOf(FItems[FDocuments[I].Item].MediaOverlay);
    if K < 0 then
      Continue;
    SmilPath := FItems[K].Path;
    if not FZip.Exists(SmilPath) then
      Continue;
    D := TEpubXmlDoc.Create(FZip.ReadText(SmilPath));
    try
      Pars := D.Root.FindAll('par');
      for K := 0 to High(Pars) do
      begin
        T := Pars[K].Child('text');
        A := Pars[K].Child('audio');
        if (T = nil) or (A = nil) then
          Continue;
        Clip := Default(TEpubClip);
        Src := T.Attr('src');
        Clip.TextPath := ResolvePath(SmilPath, Src);
        if Pos('#', Src) > 0 then
          Clip.TextId := Copy(Src, Pos('#', Src) + 1, MaxInt);
        Clip.Document := DocumentOf(Clip.TextPath);
        Clip.AudioPath := ResolvePath(SmilPath, A.Attr('src'));
        Clip.ClipBegin := EpubClockValue(A.Attr('clipBegin'));
        if Clip.ClipBegin < 0 then
          Clip.ClipBegin := 0;
        Clip.ClipEnd := EpubClockValue(A.Attr('clipEnd'));
        if Clip.ClipEnd < 0 then
          Clip.ClipEnd := 0;
        SetLength(FClips, Length(FClips) + 1);
        FClips[High(FClips)] := Clip;
      end;
    finally
      D.Free;
    end;
  end;
end;

function TEpubBook.ReadResource(const APath: string): TBytes;
begin
  Result := FZip.ReadBytes(APath);
end;

function TEpubBook.ReadResourceText(const APath: string): string;
begin
  Result := FZip.ReadText(APath);
end;

function TEpubBook.ExtractAll(const AFolder: string; ASkipAudio: Boolean): string;
var
  I: Integer;
  Name, Target: string;
  IsAudio: Boolean;
  K: Integer;
begin
  Result := IncludeTrailingPathDelimiter(AFolder);
  for I := 0 to High(FZip.Entries) do
  begin
    Name := FZip.Entries[I].Name;
    if (Name = '') or (Name[Length(Name)] = '/') then
      Continue;
    if (Pos('..', Name) > 0) or (Name[1] = '/') or (Pos(':', Name) > 0) then
      Continue;   // never write outside AFolder
    if ASkipAudio then
    begin
      IsAudio := False;
      for K := 0 to High(FItems) do
        if SameText(FItems[K].Path, Name) and (Copy(FItems[K].MediaType, 1, 6) = 'audio/') then
          IsAudio := True;
      if IsAudio then
        Continue;
    end;
    Target := Result + StringReplace(Name, '/', PathDelim, [rfReplaceAll]);
    ForceDirectories(ExtractFilePath(Target));
    FZip.Extract(Name, Target);
  end;
end;

function TEpubBook.ParseDocument(ADoc: Integer): TEpubXmlDoc;
begin
  Result := TEpubXmlDoc.Create(FZip.ReadText(FDocuments[ADoc].Path), True);
end;

function TEpubBook.StyleSheetOf(ADoc: Integer; ADocXml: TEpubXmlDoc): TEpubStyleSheet;
var
  I, K: Integer;
  Links, Styles: TEpubXmlNodeArray;
  Path, Key: string;
begin
  Key := FDocuments[ADoc].Path;
  I := FSheets.IndexOf(Key);
  if I >= 0 then
    Exit(TEpubStyleSheet(FSheets.Objects[I]));
  Result := TEpubStyleSheet.Create;
  FSheets.AddObject(Key, Result);
  Links := ADocXml.Root.FindAll('link');
  for K := 0 to High(Links) do
    if Pos('stylesheet', LowerCase(Links[K].Attr('rel'))) > 0 then
    begin
      Path := EpubResolvePath(Key, Links[K].Attr('href'));
      if FZip.Exists(Path) then
        Result.Add(FZip.ReadText(Path));
    end;
  Styles := ADocXml.Root.FindAll('style');
  for K := 0 to High(Styles) do
    Result.Add(Styles[K].InnerText);
end;

procedure TEpubBook.LoadDocumentText(ADoc: Integer);
var
  D: TEpubXmlDoc;
  Body: TEpubXmlNode;
  Lay: TEpubDocLayout;
  I, N: Integer;
begin
  FDocuments[ADoc].FirstWord := FWordCount;
  FDocuments[ADoc].Ids := nil;
  D := ParseDocument(ADoc);
  try
    Body := D.Root.Find('body');
    if Body = nil then
      Body := D.Root;
    Lay := TEpubDocLayout.Create(Body, FDocuments[ADoc].Path, StyleSheetOf(ADoc, D), False);
    try
      N := Lay.WordCount;
      if FWordCount + N > Length(FWords) then
        SetLength(FWords, FWordCount + N + 4096);
      for I := 0 to N - 1 do
      begin
        FWords[FWordCount + I].Text := Lay.Words[I].Text;
        FWords[FWordCount + I].Document := ADoc;
        FWords[FWordCount + I].IdIndex := Lay.Words[I].IdIndex;
        FWords[FWordCount + I].Role := Lay.Words[I].Role;
      end;
      SetLength(FDocuments[ADoc].Ids, Length(Lay.Ids));
      for I := 0 to High(Lay.Ids) do
      begin
        FDocuments[ADoc].Ids[I].Id := Lay.Ids[I].Id;
        FDocuments[ADoc].Ids[I].FirstWord := -1;
        FDocuments[ADoc].Ids[I].LastWord := -1;
        if Lay.Ids[I].FirstWord >= 0 then
        begin
          FDocuments[ADoc].Ids[I].FirstWord := FWordCount + Lay.Ids[I].FirstWord;
          FDocuments[ADoc].Ids[I].LastWord := FWordCount + Lay.Ids[I].LastWord;
        end;
      end;
      Inc(FWordCount, N);
    finally
      Lay.Free;
    end;
  finally
    D.Free;
  end;
  FDocuments[ADoc].WordCount := FWordCount - FDocuments[ADoc].FirstWord;
end;

function TEpubBook.DocumentLayout(ADoc: Integer): TEpubDocLayout;
var
  D: TEpubXmlDoc;
  Body: TEpubXmlNode;
begin
  D := ParseDocument(ADoc);
  try
    Body := D.Root.Find('body');
    if Body = nil then
      Body := D.Root;
    Result := TEpubDocLayout.Create(Body, FDocuments[ADoc].Path, StyleSheetOf(ADoc, D), True);
  finally
    D.Free;
  end;
end;

function TEpubBook.BlockOfWord(ALayout: TEpubDocLayout; ADoc, AWord: Integer): Integer;
var
  Local: Integer;
begin
  Result := -1;
  LoadText;
  if (ALayout = nil) or (ADoc < 0) or (ADoc > High(FDocuments)) then
    Exit;
  Local := AWord - FDocuments[ADoc].FirstWord;
  if (Local < 0) or (Local >= ALayout.WordCount) then
    Exit;
  Result := ALayout.Words[Local].Block;
end;

procedure TEpubBook.LoadText;
var
  I: Integer;
begin
  if FTextLoaded then
    Exit;
  FWordCount := 0;
  for I := 0 to High(FDocuments) do
    if Pos('html', FItems[FDocuments[I].Item].MediaType) > 0 then
      LoadDocumentText(I)
    else
    begin
      FDocuments[I].FirstWord := FWordCount;
      FDocuments[I].WordCount := 0;
    end;
  SetLength(FWords, FWordCount);
  FTextLoaded := True;
end;

function TEpubBook.GetWords: TEpubWordArray;
begin
  LoadText;
  Result := FWords;
end;

function TEpubBook.GetWordCount: Integer;
begin
  LoadText;
  Result := FWordCount;
end;

function TEpubBook.ClipAt(const AAudioPath: string; ATime: Double): Integer;
var
  I: Integer;
  E: Double;
begin
  Result := -1;
  for I := 0 to High(FClips) do
  begin
    if not SameText(FClips[I].AudioPath, AAudioPath) then
      Continue;
    if ATime < FClips[I].ClipBegin then
      Continue;
    E := FClips[I].ClipEnd;
    if (E <= 0) or (ATime < E) then
      Exit(I);
  end;
end;

function TEpubBook.ClipWords(AClip: Integer; out AFirst, ALast: Integer): Boolean;
var
  C: TEpubClip;
  I: Integer;
begin
  AFirst := -1;
  ALast := -1;
  Result := False;
  if (AClip < 0) or (AClip > High(FClips)) then
    Exit;
  LoadText;
  C := FClips[AClip];
  if C.Document < 0 then
    Exit;
  if C.TextId = '' then
  begin
    AFirst := FDocuments[C.Document].FirstWord;
    ALast := AFirst + FDocuments[C.Document].WordCount - 1;
    Exit(ALast >= AFirst);
  end;
  for I := 0 to High(FDocuments[C.Document].Ids) do
    if FDocuments[C.Document].Ids[I].Id = C.TextId then
    begin
      AFirst := FDocuments[C.Document].Ids[I].FirstWord;
      ALast := FDocuments[C.Document].Ids[I].LastWord;
      Exit(AFirst >= 0);
    end;
end;

function TEpubBook.AudioFiles: TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  for I := 0 to High(FClips) do
    if Result.IndexOf(FClips[I].AudioPath) < 0 then
      Result.Add(FClips[I].AudioPath);
end;

end.
