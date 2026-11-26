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
    { First word of the block (paragraph) the element starts in, -1 when
      that block has none (an empty anchor just before a paragraph is in
      that paragraph's block). }
    BlockFirst: Integer;
    { Last word of that block. }
    BlockLast: Integer;
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

  { One chapter mark of the narration - an audiobook's chapter, or one of
    its files - as @link(TEpubWriter.AddAudioChapter) writes them. It
    marks a place in the audio, not in the text: the text is the first
    clip from there on (@link(TEpubBook.AudioChapterWords)). }
  TEpubAudioChapter = record
    { The chapter's title as the recording names it. }
    Title: string;
    { Full path of the audio file inside the archive. }
    AudioPath: string;
    { Start in that file, s. }
    Start: Double;
  end;
  { Chapter marks in narration order. }
  TEpubAudioChapterArray = array of TEpubAudioChapter;

  { Word indexes (into @link(TEpubBook.Words)). }
  TEpubWordIndexArray = array of Integer;

const
  { Manifest id of the audio chapters file (EpubUnum's own XML, not part
    of EPUB: other readers ignore it). }
  EPUB_AUDIO_CHAPTERS_ID = 'eu-audio-chapters';
  { Namespace of the audio chapters file's elements. }
  EPUB_AUDIO_CHAPTERS_NS = 'https://github.com/WhisperBooks/Epubunum/ns/audio-chapters';
  { Name of the package meta (@code(<meta name="epubunum:writer"
    content="EpubBuilder"/>)) that TEpubWriter writes into every book it
    makes: what made it (@link(TEpubBook.WrittenBy)). }
  EPUB_WRITER_META = 'epubunum:writer';

type

  { Where the time of the last @link(TEpubBook.DocumentLayout) went, ms
    (zip 338: EpubReader's log - a long document took 0.4 s on a phone,
    not in the view's laying out). }
  TEpubLayoutTimes = record
    { Document number. }
    Doc: Integer;
    { Its text from the archive (unzipped, decoded). }
    ReadMs: Int64;
    { Parsed (XML). }
    ParseMs: Int64;
    { Its style sheets (read and parsed the first time, kept after). }
    StyleMs: Int64;
    { The walk that makes the blocks and words. }
    WalkMs: Int64;
  end;

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
    { Backing field of @link(Subjects). }
    FSubjects: TStringList;
    { Backing field of @link(CreatorFileAs). }
    FCreatorFileAs: string;
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
    { Backing field of @link(AudioChapters). }
    FAudioChapters: TEpubAudioChapterArray;
    { Backing field of @link(WrittenBy). }
    FWrittenBy: string;
    { The clip ClipAt found last (where the next search starts). }
    FLastClip: Integer;
    { Per document: its ids sorted (Objects = index into its Ids), made by
      ClipWords on first use; owned. }
    FIdIndex: array of TStringList;
    { Every clip has a clipEnd after its clipBegin, and the clips of each
      audio file follow each other without overlapping (ClipAt may start
      from FLastClip). }
    FClipsOrdered: Boolean;
    { Style sheets by document path (TEpubStyleSheet objects, owned). }
    FSheets: TStringList;
    { Backing field of @link(FromIndex). }
    FFromIndex: Boolean;
    { Backing field of @link(LastLayoutTimes). }
    FLastLayoutTimes: TEpubLayoutTimes;
    { A number made from the size and CRC of every file in the archive: an
      index is this book's only when it carries the same one. }
    function IndexStamp: Cardinal;
    { Takes clips, words and ids from an index (SaveIndex's); False, and
      nothing kept, when it is not this book's, of another version or
      damaged. }
    function LoadIndex(AIndex: TStream): Boolean;
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
    { Sets FClipsOrdered (and forgets FLastClip). }
    procedure CheckClipOrder;
    { Reads the audio chapters file (item EPUB_AUDIO_CHAPTERS_ID), when
      there is one; a damaged one gives no marks. }
    procedure ReadAudioChapters;
    { Index of the document with APath, -1 when none. }
    function DocumentOf(const APath: string): Integer;
    { Index of the manifest item with AId, -1 when none. }
    function ItemOf(const AId: string): Integer;
    { The words of the text, trimmed (LoadText first). }
    function GetWords: TEpubWordArray;
    { Number of words (LoadText first). }
    function GetWordCount: Integer;
    { The words of document ADoc; its footnote links (a marker - *, a
      dagger, a raised number - linking to an id) are added to ALinks as
      'path#id' with the word they follow as the object. }
    procedure LoadDocumentText(ADoc: Integer; ALinks: TStringList);
    { Gives the role note to the words of every footnote that ALinks
      point to (LoadDocumentText's list): the block (paragraph) holding
      the target id, when it comes AFTER the link in the book - a link
      back from the note to its marker points the other way. }
    procedure MarkLinkedNotes(ALinks: TStringList);
    { The style sheets of document ADoc (its links and style elements),
      parsed once; owned by the book. }
    function StyleSheetOf(ADoc: Integer; ADocXml: TEpubXmlDoc): TEpubStyleSheet;
    { Parses document ADoc; the caller frees the result. }
    function ParseDocument(ADoc: Integer): TEpubXmlDoc;
    { The work of the constructors: opens the archive, refuses a copy
      protected book, reads the package and, with AWithOverlays, the media
      overlays and the audio chapters - the clips, words and ids from
      AIndex when that is given and is this book's. }
    procedure OpenFile(const AFileName: string; AWithOverlays: Boolean; AIndex: TStream = nil);
  public
    { Opens AFileName and reads its package, contents and media overlays.
      @raises(EEpubError when it is not an EPUB, is damaged or is copy
        protected.) }
    constructor Create(const AFileName: string);
    { Opens AFileName for what a list of books shows - @link(Title),
      @link(Creators), @link(CoverPath) and the files (@link(ReadResource))
      - and reads its package only: NOT the media overlays (@link(Clips)
      stays empty) and not the audio chapters. A book of 150,000 timed
      words opens in a small part of the time Create takes (EpubReader's
      library on a phone, zip 324: 2.3 s a book for its title).
      @raises(EEpubError as Create.) }
    constructor CreateHeader(const AFileName: string);
    { Opens AFileName as Create does, taking the media overlays' clips and
      the whole text (@link(Words), every document's ids) from AIndex -
      what @link(SaveIndex) wrote for this book at an earlier opening -
      and not from the book's XML: a long book opens in a fraction of
      the time (zip 330). When AIndex is not this book's (the book
      changed, another version, damaged) it is ignored and the book is
      read as Create reads it; @link(FromIndex) says which.
      @param(AIndex  the index, read from its position on; a stream in
        memory is much the fastest)
      @raises(EEpubError as Create - never because of the index.) }
    constructor CreateIndexed(const AFileName: string; AIndex: TStream);
    { Writes this book's index to AStream: its clips, words and ids as
      numbers and text, with a stamp of the book it is of. Reads the text
      first (LoadText). For this program on this kind of machine: it is a
      cache, made again when it does not fit, not a file to pass on.
      Packed (varints, differences, UTF-8): 20 to 25 bytes a word. }
    procedure SaveIndex(AStream: TStream);
    { Closes the book. }
    destructor Destroy; override;
    { Reads the text of every document into @link(Words) (done on first use
      of Words; call it to control when the work happens). }
    procedure LoadText;
    { The layout of document ADoc with its blocks, for a renderer: word
      indexes in it are local; add @code(Documents[ADoc].FirstWord) for
      @link(Words). The caller frees it. }
    function DocumentLayout(ADoc: Integer): TEpubDocLayout;
    { The layout of document ADoc with word sources, for a writer: the same
      words as @link(Words) (same walker, same style sheets), each with its
      place in ADocXml, the parsed document (its Source is the document's
      text). The caller frees both, the layout first.
      @param(AText  A changed text of the document to lay out instead of
        the book's ('' = the book's).) }
    function DocumentSources(ADoc: Integer; out ADocXml: TEpubXmlDoc; const AText: string = ''): TEpubDocLayout;
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
    { For each of @link(AudioChapters): the first word of the clip in its
      audio file that starts soonest at the mark or after it (a word
      started just before the mark counts: 0.25 s); -1 when no clip does.
      By time, not by reading order: words read elsewhere (a title page
      read in the end credits) do not catch every mark. }
    function AudioChapterWords: TEpubWordIndexArray;
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
    { The first author's name as it is sorted ('Asimov, Isaac'): its
      file-as (an opf:file-as attribute, or an EPUB 3 meta refining it),
      '' when the book gives none. }
    property CreatorFileAs: string read FCreatorFileAs;
    { The subjects (dc:subject, often a genre: 'Science Fiction',
      'FICTION / Fantasy / Epic'), in order; empty when none. }
    property Subjects: TStringList read FSubjects;
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
    { The narration's chapter marks (empty: none were written - a book
      not made by TEpubWriter, or made without marks). }
    property AudioChapters: TEpubAudioChapterArray read FAudioChapters;
    { What made this book when TEpubWriter did (its EPUB_WRITER_META:
      'EpubBuilder', 'EpubConsole', ...; 'EpubUnum' for a book written
      before the meta existed but carrying the audio chapters file); ''
      for any other book. A book made so already has its synced audio:
      building one from it again is a copy of a copy. }
    property WrittenBy: string read FWrittenBy;
    { The clips and the text came from an index (@link(CreateIndexed)),
      not from the book's XML. }
    property FromIndex: Boolean read FFromIndex;
    { Where the time of the last @link(DocumentLayout) went. }
    property LastLayoutTimes: TEpubLayoutTimes read FLastLayoutTimes;
  end;

{ A SMIL clock value in seconds: '1:02:03.5', '02:03.5', '12.5s', '500ms',
  '1.5min', '0.5h', '12.5' (seconds); -1 when it cannot be read. }
function EpubClockValue(const AText: string): Double;

implementation

var
  { Number format with '.' as the decimal separator, set once (copying
    FormatSettings, a record of some fifty strings, for every clock value
    was most of the time of reading a word-level overlay). }
  DotSettings: TFormatSettings;

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
  S, Part: string;
  V: Double;
  Mult: Double;
  P: Integer;
begin
  Result := -1;
  S := LowerCase(Trim(AText));
  if Copy(S, 1, 4) = 'npt=' then
    S := Copy(S, 5, MaxInt);
  if S = '' then
    Exit;
  if Pos(':', S) > 0 then
  begin
    // h:mm:ss.f or mm:ss.f, split by hand (a word-level overlay has two
    // clock values per word)
    Result := 0;
    repeat
      P := Pos(':', S);
      if P > 0 then
      begin
        Part := Copy(S, 1, P - 1);
        S := Copy(S, P + 1, MaxInt);
      end
      else
        Part := S;
      if not TryStrToFloat(Part, V, DotSettings) then
        Exit(-1);
      Result := Result * 60 + V;
    until P = 0;
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
  if TryStrToFloat(S, V, DotSettings) then
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
  OpenFile(AFileName, True);
end;

constructor TEpubBook.CreateHeader(const AFileName: string);
begin
  inherited Create;
  OpenFile(AFileName, False);
end;

constructor TEpubBook.CreateIndexed(const AFileName: string; AIndex: TStream);
begin
  inherited Create;
  OpenFile(AFileName, True, AIndex);
end;

const
  { An index file starts and ends with these four bytes: 'EUIX'. }
  INDEX_MAGIC: array[0..3] of Byte = ($45, $55, $49, $58);
  { Changed whenever what SaveIndex writes changes: older files are not
    read. 1 (zip 330) was fixed-size numbers and texts as they lie in
    memory, 107 bytes a word; 2 (zip 334) is the packed form below,
    25 bytes a word; 3 (zip 335) writes a clip's text id as the number of
    that id in its document where it is one of them. }
  INDEX_VERSION = 3;
  { No text in an index is longer than this (bytes): a larger length is a
    damaged file. }
  INDEX_MAX_TEXT = 1 shl 20;
  { A clip's times are kept as whole milliseconds when every one of the
    book's is one to this (seconds); else as they are. }
  INDEX_TIME_EXACT = 1E-7;

{ THE INDEX, version 2 (owner, 2026-11-26: "Smaller usually = hard to
  read as a human but fast"). Every number is a varint (7 bits a byte,
  low first, the top bit = more follow); a number that can be negative is
  zigzagged first (0, -1, 1, -2 ... as 0, 1, 2, 3 ...). A text is its
  length in bytes and its UTF-8. And almost nothing is written as itself:
  - an id (a document's ids, a clip's text id) as how many characters it
    shares with the one before, and the rest: 'w000123' then 'w000124' is
    6 and '4';
  - a word's id index, an id's first word, a clip's document and its
    begin, as the difference from the one before (mostly 0 or 1); an id's
    last word and its block, a clip's end, as the difference from its own
    first word or begin;
  - a clip's two paths as numbers into a list of the few there are;
  - a clip's text id, which nearly always IS one of its document's ids,
    as that id's number (a difference again, mostly 1) - and read back it
    is the same string as the document's, not a second copy: a hundred
    thousand strings fewer to make (version 2 was a quarter of the size
    of version 1 and SLOWER to read, 0.6 s against 0.35 s for Night
    Watch on the Pixel: the time is in making strings, not in reading
    bytes);
  - a clip's times as whole milliseconds (when the book's are).
  About 25 bytes a word where version 1 took 107. }

function TEpubBook.IndexStamp: Cardinal;
var
  I: Integer;
begin
  Result := Cardinal(Length(FZip.Entries));
  for I := 0 to High(FZip.Entries) do
    Result := ((Result shl 5) or (Result shr 27)) xor FZip.Entries[I].Crc xor
      Cardinal(FZip.Entries[I].Size and $FFFFFFFF);
end;

procedure TEpubBook.SaveIndex(AStream: TStream);
var
  Buf: TBytes;
  Len: Integer;
  I, K, Prev: Integer;
  Paths: TStringList;
  Last: string;
  Millis: Boolean;
  B, E, PrevEnd, D: Int64;
  Stamp: Cardinal;
  IdDoc, IdAt: Integer;

  { Room for ACount more bytes. }
  procedure Need(ACount: Integer);
  begin
    if Len + ACount > Length(Buf) then
      SetLength(Buf, (Len + ACount) * 2 + 65536);
  end;

  { A number, 0 or more. }
  procedure PutU(AValue: UInt64);
  begin
    Need(10);
    while AValue >= $80 do
    begin
      Buf[Len] := Byte(AValue and $7F) or $80;
      Inc(Len);
      AValue := AValue shr 7;
    end;
    Buf[Len] := Byte(AValue);
    Inc(Len);
  end;

  { A number that can be negative. }
  procedure PutS(AValue: Int64);
  begin
    if AValue >= 0 then
      PutU(UInt64(AValue) shl 1)
    else
      PutU((UInt64(-(AValue + 1)) shl 1) or 1);
  end;

  { Bytes as they are. }
  procedure PutRaw(const AData; ACount: Integer);
  begin
    Need(ACount);
    Move(AData, Buf[Len], ACount);
    Inc(Len, ACount);
  end;

  { A text. }
  procedure PutText(const AText: string);
  var
    U: TBytes;
  begin
    U := EpubUtf8Bytes(AText);
    PutU(Length(U));
    if Length(U) > 0 then
      PutRaw(U[0], Length(U));
  end;

  { An id: what it shares with the one before (Last), and the rest. }
  procedure PutId(const AId: string);
  var
    N: Integer;
  begin
    N := 0;
    while (N < Length(AId)) and (N < Length(Last)) and (AId[N + 1] = Last[N + 1]) do
      Inc(N);
    {$ifdef FPC}
    // the string is UTF-8 there: not cut inside a character
    while (N > 0) and (N < Length(AId)) and ((Ord(AId[N + 1]) and $C0) = $80) do
      Dec(N);
    {$endif}
    PutU(N);
    PutText(Copy(AId, N + 1, MaxInt));
    Last := AId;
  end;

  { The number of APath in Paths (added when new). }
  function PathIndex(const APath: string): Integer;
  begin
    Result := Paths.IndexOf(APath);
    if Result < 0 then
      Result := Paths.Add(APath);
  end;

begin
  LoadText;
  Buf := nil;
  Len := 0;
  PutRaw(INDEX_MAGIC, SizeOf(INDEX_MAGIC));
  PutU(INDEX_VERSION);
  Stamp := IndexStamp;
  PutU(Stamp);
  // the documents: their words and ids
  PutU(Length(FDocuments));
  for I := 0 to High(FDocuments) do
  begin
    PutU(FDocuments[I].FirstWord);
    PutU(FDocuments[I].WordCount);
    PutU(Length(FDocuments[I].Ids));
    Last := '';
    Prev := FDocuments[I].FirstWord;
    for K := 0 to High(FDocuments[I].Ids) do
    begin
      PutId(FDocuments[I].Ids[K].Id);
      PutS(Int64(FDocuments[I].Ids[K].FirstWord) - Prev);
      PutS(Int64(FDocuments[I].Ids[K].LastWord) - FDocuments[I].Ids[K].FirstWord);
      PutS(Int64(FDocuments[I].Ids[K].BlockFirst) - FDocuments[I].Ids[K].FirstWord);
      PutS(Int64(FDocuments[I].Ids[K].BlockLast) - FDocuments[I].Ids[K].BlockFirst);
      if FDocuments[I].Ids[K].FirstWord >= 0 then
        Prev := FDocuments[I].Ids[K].FirstWord;
    end;
  end;
  // the words (each one's document follows from the documents' ranges)
  PutU(FWordCount);
  Prev := -1;
  for I := 0 to FWordCount - 1 do
  begin
    PutText(FWords[I].Text);
    PutS(Int64(FWords[I].IdIndex) - Prev);
    Prev := FWords[I].IdIndex;
    PutU(Ord(FWords[I].Role));
  end;
  // the clips; their paths (a few, each used by thousands) once
  Paths := TStringList.Create;
  try
    Paths.CaseSensitive := True;
    for I := 0 to High(FClips) do
    begin
      PathIndex(FClips[I].TextPath);
      PathIndex(FClips[I].AudioPath);
    end;
    PutU(Paths.Count);
    for I := 0 to Paths.Count - 1 do
      PutText(Paths[I]);
    // whole milliseconds, when the book's times are
    Millis := True;
    for I := 0 to High(FClips) do
      if (Abs(FClips[I].ClipBegin - Round(FClips[I].ClipBegin * 1000) / 1000) > INDEX_TIME_EXACT) or
        (Abs(FClips[I].ClipEnd - Round(FClips[I].ClipEnd * 1000) / 1000) > INDEX_TIME_EXACT) then
      begin
        Millis := False;
        Break;
      end;
    PutU(Length(FClips));
    PutU(Ord(Millis));
    Last := '';
    Prev := 0;
    PrevEnd := 0;
    IdDoc := -2;
    IdAt := -1;
    for I := 0 to High(FClips) do
    begin
      PutS(Int64(FClips[I].Document) - Prev);
      Prev := FClips[I].Document;
      PutU(PathIndex(FClips[I].TextPath));
      // the id's number in its document (looked for from the last one
      // on: clips and ids run in the same order), else the id itself
      if FClips[I].Document <> IdDoc then
      begin
        IdDoc := FClips[I].Document;
        IdAt := -1;
      end;
      K := -1;
      if IdDoc >= 0 then
      begin
        K := IdAt + 1;
        while (K <= High(FDocuments[IdDoc].Ids)) and (FDocuments[IdDoc].Ids[K].Id <> FClips[I].TextId) do
          Inc(K);
        if K > High(FDocuments[IdDoc].Ids) then
        begin
          K := 0;
          while (K <= IdAt) and (K <= High(FDocuments[IdDoc].Ids)) and
            (FDocuments[IdDoc].Ids[K].Id <> FClips[I].TextId) do
            Inc(K);
          if (K > IdAt) or (K > High(FDocuments[IdDoc].Ids)) then
            K := -1;
        end;
      end;
      if K >= 0 then
      begin
        // odd: a number (its difference from the last, zigzagged, in the
        // bits above)
        D := Int64(K) - IdAt;
        if D >= 0 then
          PutU((UInt64(D) shl 2) or 1)
        else
          PutU((UInt64(-(D + 1)) shl 2) or 3);
        IdAt := K;
      end
      else
      begin
        // 0: the id follows
        PutU(0);
        PutId(FClips[I].TextId);
      end;
      PutU(PathIndex(FClips[I].AudioPath));
      if Millis then
      begin
        B := Round(FClips[I].ClipBegin * 1000);
        E := Round(FClips[I].ClipEnd * 1000);
        PutS(B - PrevEnd);
        PutS(E - B);
        PrevEnd := E;
      end
      else
      begin
        PutRaw(FClips[I].ClipBegin, SizeOf(Double));
        PutRaw(FClips[I].ClipEnd, SizeOf(Double));
      end;
    end;
  finally
    Paths.Free;
  end;
  PutRaw(INDEX_MAGIC, SizeOf(INDEX_MAGIC));
  if Len > 0 then
    AStream.WriteBuffer(Buf[0], Len);
end;

function TEpubBook.LoadIndex(AIndex: TStream): Boolean;
var
  Buf: TBytes;
  Pos, Size: Integer;
  I, K, N, P, Prev, Role: Integer;
  Paths: array of string;
  Last: string;
  Millis: Boolean;
  B, E, PrevEnd: Int64;
  U: UInt64;
  IdDoc, IdAt: Integer;

  { ACount more bytes are there.
    @raises(EEpubError when not: the file is cut short) }
  procedure Have(ACount: Integer);
  begin
    if (ACount < 0) or (Pos + ACount > Size) then
      raise EEpubError.Create('index: cut short');
  end;

  { A number, 0 or more. }
  function GetU: UInt64;
  var
    Shift: Integer;
    C: Byte;
  begin
    // one byte, as nearly every number is
    if (Pos < Size) and (Buf[Pos] < $80) then
    begin
      Result := Buf[Pos];
      Inc(Pos);
      Exit;
    end;
    Result := 0;
    Shift := 0;
    repeat
      Have(1);
      C := Buf[Pos];
      Inc(Pos);
      Result := Result or (UInt64(C and $7F) shl Shift);
      Inc(Shift, 7);
    until (C < $80) or (Shift > 63);
  end;

  { A number that can be negative. }
  function GetS: Int64;
  var
    U: UInt64;
  begin
    U := GetU;
    if (U and 1) = 0 then
      Result := Int64(U shr 1)
    else
      Result := -Int64(U shr 1) - 1;
  end;

  { A count or an index: a number from 0 to AMax.
    @raises(EEpubError when it is not) }
  function GetN(AMax: Int64): Integer;
  var
    U: UInt64;
  begin
    U := GetU;
    if (AMax < 0) or (U > UInt64(AMax)) then
      raise EEpubError.Create('index: a number out of its range');
    Result := Integer(U);
  end;

  { A text. Plain ASCII (nearly all of a book in English) is widened here;
    anything else goes through the UTF-8 decoder. }
  function GetText: string;
  var
    L, J: Integer;
    Plain: Boolean;
  begin
    L := GetN(INDEX_MAX_TEXT);
    Have(L);
    Plain := True;
    for J := Pos to Pos + L - 1 do
      if Buf[J] >= $80 then
      begin
        Plain := False;
        Break;
      end;
    if Plain then
    begin
      SetLength(Result, L);
      for J := 1 to L do
        Result[J] := Char(Buf[Pos + J - 1]);
    end
    else
      Result := EpubBytesText(Copy(Buf, Pos, L));
    Inc(Pos, L);
  end;

  { An id: the start of the one before (Last), and the rest. }
  function GetId: string;
  var
    Shared, L, J: Integer;
    Plain: Boolean;
  begin
    Shared := GetN(Length(Last));
    L := GetN(INDEX_MAX_TEXT);
    Have(L);
    Plain := True;
    for J := Pos to Pos + L - 1 do
      if Buf[J] >= $80 then
      begin
        Plain := False;
        Break;
      end;
    if Plain then
    begin
      // one string made, filled in place: the start of the last one and
      // the bytes that follow
      SetLength(Result, Shared + L);
      for J := 1 to Shared do
        Result[J] := Last[J];
      for J := 1 to L do
        Result[Shared + J] := Char(Buf[Pos + J - 1]);
    end
    else
      Result := Copy(Last, 1, Shared) + EpubBytesText(Copy(Buf, Pos, L));
    Inc(Pos, L);
    Last := Result;
  end;

  { The four bytes of INDEX_MAGIC are next. }
  function GetMagic: Boolean;
  begin
    Have(SizeOf(INDEX_MAGIC));
    Result := CompareMem(@Buf[Pos], @INDEX_MAGIC[0], SizeOf(INDEX_MAGIC));
    Inc(Pos, SizeOf(INDEX_MAGIC));
  end;

begin
  Result := False;
  try
    // the whole of it into memory: read byte by byte from there
    Size := AIndex.Size - AIndex.Position;
    SetLength(Buf, Size);
    if Size > 0 then
      AIndex.ReadBuffer(Buf[0], Size);
    Pos := 0;
    if not GetMagic or (GetU <> INDEX_VERSION) or (GetU <> IndexStamp) or
      (GetU <> UInt64(Length(FDocuments))) then
      Exit;
    for I := 0 to High(FDocuments) do
    begin
      FDocuments[I].FirstWord := GetN(MaxInt);
      FDocuments[I].WordCount := GetN(MaxInt);
      N := GetN(Size);
      SetLength(FDocuments[I].Ids, N);
      Last := '';
      Prev := FDocuments[I].FirstWord;
      for K := 0 to N - 1 do
      begin
        FDocuments[I].Ids[K].Id := GetId;
        FDocuments[I].Ids[K].FirstWord := Integer(Prev + GetS);
        FDocuments[I].Ids[K].LastWord := Integer(FDocuments[I].Ids[K].FirstWord + GetS);
        FDocuments[I].Ids[K].BlockFirst := Integer(FDocuments[I].Ids[K].FirstWord + GetS);
        FDocuments[I].Ids[K].BlockLast := Integer(FDocuments[I].Ids[K].BlockFirst + GetS);
        if FDocuments[I].Ids[K].FirstWord >= 0 then
          Prev := FDocuments[I].Ids[K].FirstWord;
      end;
    end;
    N := GetN(Size);
    SetLength(FWords, N);
    FWordCount := N;
    Prev := -1;
    for I := 0 to N - 1 do
    begin
      FWords[I].Text := GetText;
      Prev := Integer(Prev + GetS);
      FWords[I].IdIndex := Prev;
      Role := GetN(Ord(High(TEpubWordRole)));
      FWords[I].Role := TEpubWordRole(Role);
      FWords[I].Document := -1;
    end;
    // each word's document, from the documents' ranges
    for I := 0 to High(FDocuments) do
    begin
      if Int64(FDocuments[I].FirstWord) + FDocuments[I].WordCount > N then
        raise EEpubError.Create('index: a document past the last word');
      for K := FDocuments[I].FirstWord to FDocuments[I].FirstWord + FDocuments[I].WordCount - 1 do
        FWords[K].Document := I;
    end;
    N := GetN(Size);
    SetLength(Paths, N);
    for I := 0 to N - 1 do
      Paths[I] := GetText;
    N := GetN(Size);
    Millis := GetN(1) = 1;
    SetLength(FClips, N);
    Last := '';
    Prev := 0;
    PrevEnd := 0;
    IdDoc := -2;
    IdAt := -1;
    for I := 0 to N - 1 do
    begin
      Prev := Integer(Prev + GetS);
      if (Prev < -1) or (Prev > High(FDocuments)) then
        raise EEpubError.Create('index: a clip of no document');
      FClips[I].Document := Prev;
      P := GetN(High(Paths));
      FClips[I].TextPath := Paths[P];
      if Prev <> IdDoc then
      begin
        IdDoc := Prev;
        IdAt := -1;
      end;
      U := GetU;
      if U = 0 then
        FClips[I].TextId := GetId
      else
      begin
        // the document's own string, not a copy of it
        if (U and 2) = 0 then
          IdAt := Integer(IdAt + Int64(U shr 2))
        else
          IdAt := Integer(IdAt - Int64(U shr 2) - 1);
        if (IdDoc < 0) or (IdAt < 0) or (IdAt > High(FDocuments[IdDoc].Ids)) then
          raise EEpubError.Create('index: a clip of no id');
        FClips[I].TextId := FDocuments[IdDoc].Ids[IdAt].Id;
      end;
      P := GetN(High(Paths));
      FClips[I].AudioPath := Paths[P];
      if Millis then
      begin
        B := PrevEnd + GetS;
        E := B + GetS;
        FClips[I].ClipBegin := B / 1000;
        FClips[I].ClipEnd := E / 1000;
        PrevEnd := E;
      end
      else
      begin
        Have(2 * SizeOf(Double));
        Move(Buf[Pos], FClips[I].ClipBegin, SizeOf(Double));
        Move(Buf[Pos + SizeOf(Double)], FClips[I].ClipEnd, SizeOf(Double));
        Inc(Pos, 2 * SizeOf(Double));
      end;
    end;
    if not GetMagic then
      raise EEpubError.Create('index: no end');
    FTextLoaded := True;
    CheckClipOrder;
    Result := True;
  except
    // damaged or cut short: as if there were none
    Result := False;
  end;
  if not Result then
  begin
    FClips := nil;
    FWords := nil;
    FWordCount := 0;
    FTextLoaded := False;
    for I := 0 to High(FDocuments) do
    begin
      FDocuments[I].FirstWord := 0;
      FDocuments[I].WordCount := 0;
      FDocuments[I].Ids := nil;
    end;
  end;
end;

procedure TEpubBook.OpenFile(const AFileName: string; AWithOverlays: Boolean; AIndex: TStream);
begin
  FFileName := AFileName;
  FCreators := TStringList.Create;
  FSubjects := TStringList.Create;
  FSheets := TStringList.Create;
  FSheets.OwnsObjects := True;
  FActiveClass := DEFAULT_ACTIVE_CLASS;
  FZip := TEpubZipReader.Create(AFileName);
  CheckProtection;
  ReadPackage;
  if AWithOverlays then
  begin
    FFromIndex := (AIndex <> nil) and LoadIndex(AIndex);
    if not FFromIndex then
      ReadOverlays;
    ReadAudioChapters;
  end;
  // written by TEpubWriter before the meta existed (zips 40 - 44)
  if (FWrittenBy = '') and (ItemOf(EPUB_AUDIO_CHAPTERS_ID) >= 0) then
    FWrittenBy := 'EpubUnum';
end;

destructor TEpubBook.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FIdIndex) do
    FIdIndex[I].Free;
  FZip.Free;
  FCreators.Free;
  FSubjects.Free;
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
  NcxId, NavPath, CoverId, Prop, CreatorId: string;
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
      // the first author's sort form: EPUB 2's attribute here, EPUB 3's
      // meta (refines its id) below
      CreatorId := '';
      if Length(List) > 0 then
      begin
        FCreatorFileAs := Trim(List[0].Attr('file-as'));
        CreatorId := List[0].Attr('id');
      end;
      List := Meta.FindAll('subject');
      for I := 0 to High(List) do
        if Trim(List[I].InnerText) <> '' then
          FSubjects.Add(Trim(List[I].InnerText));
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
        else if List[I].Attr('name') = EPUB_WRITER_META then
          FWrittenBy := Trim(List[I].Attr('content'))
        else if (Prop = 'file-as') and (FCreatorFileAs = '') and (CreatorId <> '') and
          (List[I].Attr('refines') = '#' + CreatorId) then
          FCreatorFileAs := Trim(List[I].InnerText)
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
  I, K, N, P, LastDoc: Integer;
  D: TEpubXmlDoc;
  Pars: TEpubXmlNodeArray;
  T, A: TEpubXmlNode;
  Src, SmilPath, Base, LastBase, LastPath, LastAudioSrc, LastAudioPath: string;
  Clip: TEpubClip;
begin
  N := 0;
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
    LastBase := '';
    LastPath := '';
    LastDoc := -1;
    LastAudioSrc := '';
    LastAudioPath := '';
    try
      Pars := D.Root.FindAll('par');
      for K := 0 to High(Pars) do
      begin
        T := Pars[K].Child('text');
        A := Pars[K].Child('audio');
        if (T = nil) or (A = nil) then
          Continue;
        Clip := Default(TEpubClip);
        // the pars of a file name the same document and audio file: their
        // paths are resolved once (a word-level overlay has a par per word)
        Src := T.Attr('src');
        P := Pos('#', Src);
        if P > 0 then
        begin
          Clip.TextId := Copy(Src, P + 1, MaxInt);
          Base := Copy(Src, 1, P - 1);
        end
        else
          Base := Src;
        if (K = 0) or (Base <> LastBase) then
        begin
          LastBase := Base;
          LastPath := ResolvePath(SmilPath, Base);
          LastDoc := DocumentOf(LastPath);
        end;
        Clip.TextPath := LastPath;
        Clip.Document := LastDoc;
        if (K = 0) or (A.Attr('src') <> LastAudioSrc) then
        begin
          LastAudioSrc := A.Attr('src');
          LastAudioPath := ResolvePath(SmilPath, LastAudioSrc);
        end;
        Clip.AudioPath := LastAudioPath;
        Clip.ClipBegin := EpubClockValue(A.Attr('clipBegin'));
        if Clip.ClipBegin < 0 then
          Clip.ClipBegin := 0;
        Clip.ClipEnd := EpubClockValue(A.Attr('clipEnd'));
        if Clip.ClipEnd < 0 then
          Clip.ClipEnd := 0;
        // grown by doubling: a word-level overlay has a clip per word
        if N = Length(FClips) then
          SetLength(FClips, N * 2 + 256);
        FClips[N] := Clip;
        Inc(N);
      end;
    finally
      D.Free;
    end;
  end;
  SetLength(FClips, N);
  CheckClipOrder;
end;

procedure TEpubBook.ReadAudioChapters;
var
  I, N: Integer;
  Path: string;
  D: TEpubXmlDoc;
  List: TEpubXmlNodeArray;
  Start: Double;
begin
  FAudioChapters := nil;
  I := ItemOf(EPUB_AUDIO_CHAPTERS_ID);
  if I < 0 then
    Exit;
  Path := FItems[I].Path;
  if not FZip.Exists(Path) then
    Exit;
  try
    D := TEpubXmlDoc.Create(FZip.ReadText(Path));
    try
      List := D.Root.FindAll('chapter');
      SetLength(FAudioChapters, Length(List));
      N := 0;
      for I := 0 to High(List) do
      begin
        Start := EpubClockValue(List[I].Attr('begin'));
        if (List[I].Attr('audio') = '') or (Start < 0) then
          Continue;
        FAudioChapters[N].Title := Trim(List[I].Attr('title'));
        FAudioChapters[N].AudioPath := ResolvePath(Path, List[I].Attr('audio'));
        FAudioChapters[N].Start := Start;
        Inc(N);
      end;
      SetLength(FAudioChapters, N);
    finally
      D.Free;
    end;
  except
    // the marks are a convenience: a damaged file must not stop the book
    FAudioChapters := nil;
  end;
end;

function TEpubBook.AudioChapterWords: TEpubWordIndexArray;
const
  // a word that starts just before the mark still opens the chapter
  EARLY = 0.25;
var
  M, C, Best, First, Last, A: Integer;
  BestBegin: Double;
  Files: TStringList;
  FileOf: array of Integer;
begin
  Result := nil;
  SetLength(Result, Length(FAudioChapters));
  if Length(FAudioChapters) = 0 then
    Exit;
  // each clip's audio file as a number: one comparison of names per clip
  Files := TStringList.Create;
  try
    Files.CaseSensitive := False;
    SetLength(FileOf, Length(FClips));
    for C := 0 to High(FClips) do
    begin
      A := Files.IndexOf(FClips[C].AudioPath);
      if A < 0 then
        A := Files.Add(FClips[C].AudioPath);
      FileOf[C] := A;
    end;
    for M := 0 to High(FAudioChapters) do
    begin
      Result[M] := -1;
      A := Files.IndexOf(FAudioChapters[M].AudioPath);
      if A < 0 then
        Continue;
      // the soonest clip at the mark or after it, wherever it is in the
      // book: by reading order, the first clip "after" the mark was the
      // title page read in the end credits - for every mark (The Sword of
      // Shannara, 2026-11-20: 37 marks on one word, "End Credits")
      Best := -1;
      BestBegin := 0;
      for C := 0 to High(FClips) do
        if (FileOf[C] = A) and (FClips[C].ClipBegin >= FAudioChapters[M].Start - EARLY) and
          ((Best < 0) or (FClips[C].ClipBegin < BestBegin)) then
        begin
          Best := C;
          BestBegin := FClips[C].ClipBegin;
        end;
      if (Best >= 0) and ClipWords(Best, First, Last) then
        Result[M] := First;
    end;
  finally
    Files.Free;
  end;
end;

procedure TEpubBook.CheckClipOrder;
var
  Files: TStringList;
  Lasts: array of Double;
  I, K: Integer;
begin
  FLastClip := -1;
  FClipsOrdered := True;
  Files := TStringList.Create;
  try
    Files.Sorted := True;
    Files.CaseSensitive := False;
    for I := 0 to High(FClips) do
    begin
      if FClips[I].ClipEnd <= FClips[I].ClipBegin then
      begin
        FClipsOrdered := False;
        Exit;
      end;
      // Objects hold the index of the file's last clip end in Lasts
      if Files.Find(FClips[I].AudioPath, K) then
      begin
        K := NativeInt(Files.Objects[K]);
        if FClips[I].ClipBegin < Lasts[K] then
        begin
          FClipsOrdered := False;
          Exit;
        end;
      end
      else
      begin
        SetLength(Lasts, Length(Lasts) + 1);
        K := High(Lasts);
        Files.AddObject(FClips[I].AudioPath, TObject(NativeInt(K)));
      end;
      Lasts[K] := FClips[I].ClipEnd;
    end;
  finally
    Files.Free;
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

{ True when AText is a footnote marker: asterisks, daggers, section or
  paragraph signs (up to 4), or - raised (ASuper) - a number or letter of
  up to 3 characters. }
function IsNoteMarker(const AText: string; ASuper: Boolean): Boolean;
const
  {$ifdef FPC}
  // UTF-8 (FPC strings are bytes)
  DAGGER = #$E2#$80#$A0;
  DOUBLE_DAGGER = #$E2#$80#$A1;
  SECTION = #$C2#$A7;
  PILCROW = #$C2#$B6;
  {$else}
  DAGGER = #$2020;
  DOUBLE_DAGGER = #$2021;
  SECTION = #$A7;
  PILCROW = #$B6;
  {$endif}
var
  S, R: string;
  I: Integer;
begin
  Result := False;
  S := Trim(AText);
  if (S = '') or (Length(S) > 12) then
    Exit;
  R := StringReplace(S, '*', '', [rfReplaceAll]);
  R := StringReplace(R, DAGGER, '', [rfReplaceAll]);
  R := StringReplace(R, DOUBLE_DAGGER, '', [rfReplaceAll]);
  R := StringReplace(R, SECTION, '', [rfReplaceAll]);
  R := StringReplace(R, PILCROW, '', [rfReplaceAll]);
  if (R = '') and (Length(S) <= 12) then
    Exit(True);
  if not ASuper or (Length(S) > 3) then
    Exit;
  for I := 1 to Length(S) do
    if not CharInSet(S[I], ['0'..'9', 'a'..'z', 'A'..'Z']) then
      Exit;
  Result := True;
end;

procedure TEpubBook.LoadDocumentText(ADoc: Integer; ALinks: TStringList);
var
  D: TEpubXmlDoc;
  Body: TEpubXmlNode;
  Lay: TEpubDocLayout;
  I, N, B, K, R, P, Src: Integer;
  Blk: TEpubBlock;
  Run: TEpubRun;
  Href: string;
begin
  FDocuments[ADoc].FirstWord := FWordCount;
  FDocuments[ADoc].Ids := nil;
  D := ParseDocument(ADoc);
  try
    Body := D.Root.Find('body');
    if Body = nil then
      Body := D.Root;
    // with blocks: the paragraphs and the links in them (footnotes)
    Lay := TEpubDocLayout.Create(Body, FDocuments[ADoc].Path, StyleSheetOf(ADoc, D), True);
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
        FDocuments[ADoc].Ids[I].BlockFirst := -1;
        FDocuments[ADoc].Ids[I].BlockLast := -1;
        if Lay.Ids[I].FirstWord >= 0 then
        begin
          FDocuments[ADoc].Ids[I].FirstWord := FWordCount + Lay.Ids[I].FirstWord;
          FDocuments[ADoc].Ids[I].LastWord := FWordCount + Lay.Ids[I].LastWord;
        end;
        B := Lay.Ids[I].Block;
        if (B >= 0) and (B < Lay.BlockCount) and (Length(Lay.Blocks[B].Words) > 0) then
        begin
          FDocuments[ADoc].Ids[I].BlockFirst := FWordCount + Lay.Blocks[B].Words[0].Word;
          FDocuments[ADoc].Ids[I].BlockLast := FWordCount + Lay.Blocks[B].Words[High(Lay.Blocks[B].Words)].Word;
        end;
      end;
      // footnote links: a marker linking to an id
      if ALinks <> nil then
        for B := 0 to Lay.BlockCount - 1 do
        begin
          Blk := Lay.Blocks[B];
          for R := 0 to High(Blk.Runs) do
          begin
            Run := Blk.Runs[R];
            Href := Run.Href;
            P := Pos('#', Href);
            if not (ersLink in Run.Styles) or (P = 0) or
              not IsNoteMarker(Copy(Blk.Text, Run.Start + 1, Run.Length), ersSuper in Run.Styles) then
              Continue;
            // the word it belongs to: the one it is in or follows
            Src := -1;
            for K := 0 to High(Blk.Words) do
              if Blk.Words[K].Start <= Run.Start then
                Src := Blk.Words[K].Word
              else
                Break;
            if Src < 0 then
              Continue;
            ALinks.AddObject(EpubResolvePath(FDocuments[ADoc].Path, Href) + '#' + Copy(Href, P + 1, MaxInt),
              TObject(NativeInt(FWordCount + Src)));
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

function TEpubBook.DocumentSources(ADoc: Integer; out ADocXml: TEpubXmlDoc; const AText: string): TEpubDocLayout;
var
  Body: TEpubXmlNode;
begin
  if AText <> '' then
    ADocXml := TEpubXmlDoc.Create(AText, True)
  else
    ADocXml := ParseDocument(ADoc);
  try
    Body := ADocXml.Root.Find('body');
    if Body = nil then
      Body := ADocXml.Root;
    Result := TEpubDocLayout.Create(Body, FDocuments[ADoc].Path, StyleSheetOf(ADoc, ADocXml), False, True);
  except
    FreeAndNil(ADocXml);
    raise;
  end;
end;

{ A millisecond clock (the times of DocumentLayout). }
function TicksMs: Int64;
begin
  {$ifdef FPC}
  Result := Int64(GetTickCount64);
  {$else}
  Result := Int64(TThread.GetTickCount64);
  {$endif}
end;

function TEpubBook.DocumentLayout(ADoc: Integer): TEpubDocLayout;
var
  D: TEpubXmlDoc;
  Body: TEpubXmlNode;
  Text: string;
  Sheet: TEpubStyleSheet;
  T0, T1, T2, T3: Int64;
begin
  // ParseDocument's work in two steps, each timed (LastLayoutTimes)
  FLastLayoutTimes := Default(TEpubLayoutTimes);
  FLastLayoutTimes.Doc := ADoc;
  T0 := TicksMs;
  Text := FZip.ReadText(FDocuments[ADoc].Path);
  T1 := TicksMs;
  D := TEpubXmlDoc.Create(Text, True);
  try
    T2 := TicksMs;
    Body := D.Root.Find('body');
    if Body = nil then
      Body := D.Root;
    Sheet := StyleSheetOf(ADoc, D);
    T3 := TicksMs;
    Result := TEpubDocLayout.Create(Body, FDocuments[ADoc].Path, Sheet, True);
    FLastLayoutTimes.ReadMs := T1 - T0;
    FLastLayoutTimes.ParseMs := T2 - T1;
    FLastLayoutTimes.StyleMs := T3 - T2;
    FLastLayoutTimes.WalkMs := TicksMs - T3;
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
  Links: TStringList;
begin
  if FTextLoaded then
    Exit;
  FWordCount := 0;
  Links := TStringList.Create;
  try
    for I := 0 to High(FDocuments) do
      if Pos('html', FItems[FDocuments[I].Item].MediaType) > 0 then
        LoadDocumentText(I, Links)
      else
      begin
        FDocuments[I].FirstWord := FWordCount;
        FDocuments[I].WordCount := 0;
      end;
    SetLength(FWords, FWordCount);
    MarkLinkedNotes(Links);
  finally
    Links.Free;
  end;
  FTextLoaded := True;
end;

procedure TEpubBook.MarkLinkedNotes(ALinks: TStringList);
var
  I, P, D, K, Src, First, Last, W: Integer;
  Path, Id: string;
begin
  for I := 0 to ALinks.Count - 1 do
  begin
    P := LastDelimiter('#', ALinks[I]);
    Path := Copy(ALinks[I], 1, P - 1);
    Id := Copy(ALinks[I], P + 1, MaxInt);
    Src := Integer(NativeInt(ALinks.Objects[I]));
    for D := 0 to High(FDocuments) do
      if SameText(FDocuments[D].Path, Path) then
      begin
        for K := 0 to High(FDocuments[D].Ids) do
          if FDocuments[D].Ids[K].Id = Id then
          begin
            // the paragraph the target is in (and all the element holds)
            First := FDocuments[D].Ids[K].BlockFirst;
            Last := FDocuments[D].Ids[K].BlockLast;
            if FDocuments[D].Ids[K].FirstWord >= 0 then
            begin
              if (First < 0) or (FDocuments[D].Ids[K].FirstWord < First) then
                First := FDocuments[D].Ids[K].FirstWord;
              if FDocuments[D].Ids[K].LastWord > Last then
                Last := FDocuments[D].Ids[K].LastWord;
            end;
            // only after the marker: a link back from the note points up
            if (First > Src) and (Last >= First) then
              for W := First to Last do
                if FWords[W].Role in [ewrBody, ewrCaption, ewrTable] then
                  FWords[W].Role := ewrNote;
            Break;
          end;
        Break;
      end;
  end;
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

  { True when clip AI is of the audio file and plays at ATime. }
  function Plays(AI: Integer): Boolean;
  var
    E: Double;
  begin
    Result := False;
    if (ATime < FClips[AI].ClipBegin) or not SameText(FClips[AI].AudioPath, AAudioPath) then
      Exit;
    E := FClips[AI].ClipEnd;
    Result := (E <= 0) or (ATime < E);
  end;

var
  I, K: Integer;
begin
  // Ordered clips (FClipsOrdered): at most one clip of a file plays at a
  // time, so any match is the first one. Playing goes forward, so the clip
  // found last or one of the next is the usual answer - a word-level
  // overlay has a clip per word, and this runs on every tick.
  if FClipsOrdered and (FLastClip >= 0) then
    for K := FLastClip to FLastClip + 16 do
    begin
      if K > High(FClips) then
        Break;
      if Plays(K) then
      begin
        FLastClip := K;
        Exit(K);
      end;
    end;
  for I := 0 to High(FClips) do
    if Plays(I) then
    begin
      FLastClip := I;
      Exit(I);
    end;
  Result := -1;
end;

function TEpubBook.ClipWords(AClip: Integer; out AFirst, ALast: Integer): Boolean;
var
  C: TEpubClip;
  I, K: Integer;
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
  // a sorted index of the document's ids: a word-level overlay has a clip
  // (and an id) per word, and a reader asks for every clip
  if Length(FIdIndex) <> Length(FDocuments) then
    SetLength(FIdIndex, Length(FDocuments));
  if FIdIndex[C.Document] = nil then
  begin
    FIdIndex[C.Document] := TStringList.Create;
    FIdIndex[C.Document].CaseSensitive := True;
    for I := 0 to High(FDocuments[C.Document].Ids) do
      FIdIndex[C.Document].AddObject(FDocuments[C.Document].Ids[I].Id, TObject(NativeInt(I)));
    // Sorted, not Sort: FPC's Find finds nothing in a list not marked sorted
    FIdIndex[C.Document].Duplicates := dupAccept;
    FIdIndex[C.Document].Sorted := True;
  end;
  if not FIdIndex[C.Document].Find(C.TextId, K) then
    Exit;
  // a repeated id: the first in the document wins (the sort keeps no order)
  I := NativeInt(FIdIndex[C.Document].Objects[K]);
  while (K + 1 < FIdIndex[C.Document].Count) and (FIdIndex[C.Document][K + 1] = C.TextId) do
  begin
    Inc(K);
    if NativeInt(FIdIndex[C.Document].Objects[K]) < I then
      I := NativeInt(FIdIndex[C.Document].Objects[K]);
  end;
  AFirst := FDocuments[C.Document].Ids[I].FirstWord;
  ALast := FDocuments[C.Document].Ids[I].LastWord;
  Result := AFirst >= 0;
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

initialization
  DotSettings := FormatSettings;
  DotSettings.DecimalSeparator := '.';

end.
