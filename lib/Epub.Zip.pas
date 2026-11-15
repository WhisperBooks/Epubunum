(* @abstract(The ZIP container of an EPUB: reading entries (stored or
  deflated) and writing a new archive with the mimetype entry first and
  uncompressed, as the EPUB standard requires.)

  Small and self-contained: the central directory is read once, an entry is
  read when asked for, so a book with hundreds of megabytes of audio inside
  opens at once. ZIP64 archives (over 4 GB) are refused with a message;
  encrypted ZIP entries are refused too (an EPUB never uses ZIP encryption -
  DRM sits in META-INF/encryption.xml, see Epub.Book). Deflate goes through
  the compiler's zlib unit (System.ZLib with Delphi, zstream with FPC).

  Framework-free; compiles with Delphi and FPC. *)
unit Epub.Zip;

{$I Epub.inc}

interface

uses
  SysUtils, Classes;

type
  { Raised for every failure of EpubUnum. }
  EEpubError = class(Exception);

  { One entry of the central directory. }
  TEpubZipEntry = record
    { Path inside the archive, '/'-separated, as stored (UTF-8 decoded). }
    Name: string;
    { 0 = stored, 8 = deflated (others are refused when read). }
    Method: Word;
    { General purpose flags (bit 0 = encrypted). }
    Flags: Word;
    { CRC-32 of the uncompressed data. }
    Crc: Cardinal;
    { Compressed size, bytes. }
    CompressedSize: Int64;
    { Uncompressed size, bytes. }
    Size: Int64;
    { Offset of the local header in the archive. }
    LocalOffset: Int64;
  end;
  { The entries, in central-directory order. }
  TEpubZipEntryArray = array of TEpubZipEntry;

  { Reads a ZIP archive: the entry list, and any entry's data. }
  TEpubZipReader = class
  private
    { The archive. }
    FStream: TStream;
    { FStream is ours to free. }
    FOwnsStream: Boolean;
    { Backing field of @link(Entries). }
    FEntries: TEpubZipEntryArray;
    { Backing field of @link(FileName). }
    FFileName: string;
    { Reads the end of central directory and the central directory. }
    procedure ReadDirectory;
  public
    { Opens AFileName (read only, shared for reading).
      @raises(EEpubError when it is not a ZIP archive or uses ZIP64.) }
    constructor Create(const AFileName: string); overload;
    { Reads from AStream (positioned anywhere); AOwnsStream frees it with
      the reader. }
    constructor Create(AStream: TStream; AOwnsStream: Boolean); overload;
    { Closes the archive. }
    destructor Destroy; override;
    { Index of entry AName (exact first, then ignoring case); -1 when absent. }
    function IndexOf(const AName: string): Integer;
    { True when entry AName exists. }
    function Exists(const AName: string): Boolean;
    { The uncompressed data of entry AIndex, CRC-checked.
      @raises(EEpubError for an unknown method, an encrypted entry or a CRC
        mismatch.) }
    function ReadBytes(AIndex: Integer): TBytes; overload;
    { The data of entry AName.
      @raises(EEpubError when there is no such entry.) }
    function ReadBytes(const AName: string): TBytes; overload;
    { Entry AName as text: UTF-8 (a BOM is dropped), or UTF-16 with a BOM. }
    function ReadText(const AName: string): string;
    { Writes entry AName to the file AFileName. }
    procedure Extract(const AName, AFileName: string);
    { The entries. }
    property Entries: TEpubZipEntryArray read FEntries;
    { The archive's file name ('' when read from a stream). }
    property FileName: string read FFileName;
  end;

  { Writes a new ZIP archive. For an EPUB, add 'mimetype' first with
    AStored = True (@link(AddEpubMimetype) does that). }
  TEpubZipWriter = class
  private
    { The archive being written. }
    FStream: TStream;
    { FStream is ours to free. }
    FOwnsStream: Boolean;
    { Entries written so far (for the central directory). }
    FEntries: TEpubZipEntryArray;
    { Finish was called. }
    FFinished: Boolean;
  public
    { Creates AFileName (overwrites it). }
    constructor Create(const AFileName: string); overload;
    { Writes to AStream; AOwnsStream frees it with the writer. }
    constructor Create(AStream: TStream; AOwnsStream: Boolean); overload;
    { Finishes the archive (if not done) and closes it. }
    destructor Destroy; override;
    { Adds entry AName with AData, deflated unless AStored. }
    procedure Add(const AName: string; const AData: TBytes; AStored: Boolean = False); overload;
    { Adds entry AName with AText as UTF-8. }
    procedure Add(const AName, AText: string; AStored: Boolean = False); overload;
    { Adds the EPUB 'mimetype' entry (stored, no extra field). Must be first. }
    procedure AddEpubMimetype;
    { Writes the central directory. Nothing can be added after it. }
    procedure Finish;
  end;

{ CRC-32 (ZIP / zlib polynomial) of ACount bytes at AData, continuing ACrc
  (start with 0). }
function EpubCrc32(ACrc: Cardinal; AData: PByte; ACount: NativeInt): Cardinal;
{ AText as UTF-8 bytes (no BOM). }
function EpubUtf8Bytes(const AText: string): TBytes;
{ ABytes as text: UTF-8 (BOM dropped), or UTF-16 LE / BE with a BOM. }
function EpubBytesText(const ABytes: TBytes): string;

implementation

uses
  {$ifdef FPC}zstream{$else}ZLib{$endif};

const
  { Local file header signature. }
  SIG_LOCAL = $04034B50;
  { Central directory file header signature. }
  SIG_CENTRAL = $02014B50;
  { End of central directory signature. }
  SIG_END = $06054B50;
  { ZIP64 end of central directory locator signature. }
  SIG_END64_LOCATOR = $07064B50;
  { Bytes of the end of central directory record without its comment. }
  END_SIZE = 22;
  { Longest ZIP comment, bytes. }
  MAX_COMMENT = $FFFF;
  { Flag bit 11: the name is UTF-8. }
  FLAG_UTF8 = $0800;
  { Flag bit 0: the entry is encrypted. }
  FLAG_ENCRYPTED = $0001;
  { Method: stored. }
  METHOD_STORED = 0;
  { Method: deflated. }
  METHOD_DEFLATED = 8;
  { "Version needed to extract" written: 2.0 (deflate). }
  ZIP_VERSION = 20;
  { The EPUB mimetype. }
  EPUB_MIMETYPE = 'application/epub+zip';

var
  { CRC-32 table, built on first use. }
  CrcTable: array[0..255] of Cardinal;
  { CrcTable is filled. }
  CrcReady: Boolean = False;

{ Fills CrcTable. }
procedure MakeCrcTable;
var
  N, K: Integer;
  C: Cardinal;
begin
  for N := 0 to 255 do
  begin
    C := Cardinal(N);
    for K := 0 to 7 do
      if (C and 1) <> 0 then
        C := $EDB88320 xor (C shr 1)
      else
        C := C shr 1;
    CrcTable[N] := C;
  end;
  CrcReady := True;
end;

function EpubCrc32(ACrc: Cardinal; AData: PByte; ACount: NativeInt): Cardinal;
var
  I: NativeInt;
begin
  if not CrcReady then
    MakeCrcTable;
  Result := not ACrc;
  for I := 0 to ACount - 1 do
  begin
    Result := CrcTable[(Result xor AData^) and $FF] xor (Result shr 8);
    Inc(AData);
  end;
  Result := not Result;
end;

function EpubUtf8Bytes(const AText: string): TBytes;
var
  U: UTF8String;
begin
  U := UTF8String(AText);
  SetLength(Result, Length(U));
  if Length(U) > 0 then
    Move(U[1], Result[0], Length(U));
end;

function EpubBytesText(const ABytes: TBytes): string;
var
  U: UTF8String;
  W: UnicodeString;
  I, N: Integer;
begin
  N := Length(ABytes);
  if (N >= 2) and (ABytes[0] = $FF) and (ABytes[1] = $FE) then
  begin
    SetLength(W, (N - 2) div 2);
    if Length(W) > 0 then
      Move(ABytes[2], W[1], Length(W) * 2);
    Exit(string(W));
  end;
  if (N >= 2) and (ABytes[0] = $FE) and (ABytes[1] = $FF) then
  begin
    SetLength(W, (N - 2) div 2);
    for I := 1 to Length(W) do
      W[I] := WideChar((ABytes[2 * I] shl 8) or ABytes[2 * I + 1]);
    Exit(string(W));
  end;
  I := 0;
  if (N >= 3) and (ABytes[0] = $EF) and (ABytes[1] = $BB) and (ABytes[2] = $BF) then
    I := 3;
  SetLength(U, N - I);
  if N - I > 0 then
    Move(ABytes[I], U[1], N - I);
  {$ifdef FPC}
  Result := UTF8Decode(U);
  {$else}
  Result := UTF8ToString(U);
  {$endif}
end;

{ Little-endian 16-bit value at AP. }
function Get16(const AB: TBytes; AP: Integer): Word;
begin
  Result := AB[AP] or (AB[AP + 1] shl 8);
end;

{ Little-endian 32-bit value at AP. }
function Get32(const AB: TBytes; AP: Integer): Cardinal;
begin
  Result := Cardinal(AB[AP]) or (Cardinal(AB[AP + 1]) shl 8) or (Cardinal(AB[AP + 2]) shl 16) or
    (Cardinal(AB[AP + 3]) shl 24);
end;

{ Reads exactly ACount bytes at AOffset of AStream. }
function ReadAt(AStream: TStream; AOffset: Int64; ACount: Integer): TBytes;
begin
  SetLength(Result, ACount);
  AStream.Position := AOffset;
  if ACount > 0 then
    AStream.ReadBuffer(Result[0], ACount);
end;

{ The bytes of a stored name as text (UTF-8 when AUtf8 or when it decodes
  as such; else code page 437 is approximated by Latin-1). }
function NameText(const AB: TBytes; AP, ALen: Integer; AUtf8: Boolean): string;
var
  Raw: TBytes;
  I: Integer;
  Ascii: Boolean;
begin
  SetLength(Raw, ALen);
  if ALen > 0 then
    Move(AB[AP], Raw[0], ALen);
  Ascii := True;
  for I := 0 to ALen - 1 do
    if Raw[I] >= $80 then
      Ascii := False;
  if AUtf8 or not Ascii then
    Result := EpubBytesText(Raw)
  else
  begin
    SetLength(Result, ALen);
    for I := 0 to ALen - 1 do
      Result[I + 1] := Char(Raw[I]);
  end;
end;

{ TEpubZipReader }

constructor TEpubZipReader.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
  try
    FStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  except
    on E: Exception do
      raise EEpubError.CreateFmt('%s cannot be opened: %s', [AFileName, E.Message]);
  end;
  FOwnsStream := True;
  ReadDirectory;
end;

constructor TEpubZipReader.Create(AStream: TStream; AOwnsStream: Boolean);
begin
  inherited Create;
  FStream := AStream;
  FOwnsStream := AOwnsStream;
  ReadDirectory;
end;

destructor TEpubZipReader.Destroy;
begin
  if FOwnsStream then
    FStream.Free;
  inherited;
end;

procedure TEpubZipReader.ReadDirectory;
var
  Size, TailStart: Int64;
  Tail, Dir: TBytes;
  I, EndPos, Count, P, NameLen, ExtraLen, CommentLen: Integer;
  DirSize, DirOffset: Cardinal;
  E: TEpubZipEntry;
  What: string;
begin
  What := FFileName;
  if What = '' then
    What := 'The archive';
  Size := FStream.Size;
  if Size < END_SIZE then
    raise EEpubError.CreateFmt('%s is not a ZIP archive (an EPUB is one)', [What]);
  TailStart := Size - END_SIZE - MAX_COMMENT;
  if TailStart < 0 then
    TailStart := 0;
  Tail := ReadAt(FStream, TailStart, Size - TailStart);
  EndPos := -1;
  for I := Length(Tail) - END_SIZE downto 0 do
    if Get32(Tail, I) = SIG_END then
    begin
      EndPos := I;
      Break;
    end;
  if EndPos < 0 then
    raise EEpubError.CreateFmt('%s is not a ZIP archive (an EPUB is one)', [What]);
  if (EndPos >= 20) and (Get32(Tail, EndPos - 20) = SIG_END64_LOCATOR) then
    raise EEpubError.CreateFmt('%s is a ZIP64 archive (over 4 GB), which is not supported', [What]);
  Count := Get16(Tail, EndPos + 10);
  DirSize := Get32(Tail, EndPos + 12);
  DirOffset := Get32(Tail, EndPos + 16);
  if (DirOffset = $FFFFFFFF) or (Count = $FFFF) then
    raise EEpubError.CreateFmt('%s is a ZIP64 archive (over 4 GB), which is not supported', [What]);
  if Int64(DirOffset) + DirSize > Size then
    raise EEpubError.CreateFmt('%s: the ZIP directory is damaged', [What]);
  Dir := ReadAt(FStream, DirOffset, DirSize);
  SetLength(FEntries, Count);
  P := 0;
  for I := 0 to Count - 1 do
  begin
    if (P + 46 > Length(Dir)) or (Get32(Dir, P) <> SIG_CENTRAL) then
      raise EEpubError.CreateFmt('%s: the ZIP directory is damaged (entry %d)', [What, I]);
    E := Default(TEpubZipEntry);
    E.Flags := Get16(Dir, P + 8);
    E.Method := Get16(Dir, P + 10);
    E.Crc := Get32(Dir, P + 16);
    E.CompressedSize := Get32(Dir, P + 20);
    E.Size := Get32(Dir, P + 24);
    NameLen := Get16(Dir, P + 28);
    ExtraLen := Get16(Dir, P + 30);
    CommentLen := Get16(Dir, P + 32);
    E.LocalOffset := Get32(Dir, P + 42);
    if P + 46 + NameLen > Length(Dir) then
      raise EEpubError.CreateFmt('%s: the ZIP directory is damaged (entry %d)', [What, I]);
    E.Name := NameText(Dir, P + 46, NameLen, (E.Flags and FLAG_UTF8) <> 0);
    FEntries[I] := E;
    P := P + 46 + NameLen + ExtraLen + CommentLen;
  end;
end;

function TEpubZipReader.IndexOf(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FEntries) do
    if FEntries[I].Name = AName then
      Exit(I);
  for I := 0 to High(FEntries) do
    if SameText(FEntries[I].Name, AName) then
      Exit(I);
  Result := -1;
end;

function TEpubZipReader.Exists(const AName: string): Boolean;
begin
  Result := IndexOf(AName) >= 0;
end;

function TEpubZipReader.ReadBytes(AIndex: Integer): TBytes;
var
  E: TEpubZipEntry;
  Head: TBytes;
  DataStart: Int64;
  Packed_: TMemoryStream;
  Z: TStream;
  Got: Integer;
begin
  E := FEntries[AIndex];
  if (E.Flags and FLAG_ENCRYPTED) <> 0 then
    raise EEpubError.CreateFmt('%s: entry %s is encrypted', [FFileName, E.Name]);
  Head := ReadAt(FStream, E.LocalOffset, 30);
  if Get32(Head, 0) <> SIG_LOCAL then
    raise EEpubError.CreateFmt('%s: entry %s is damaged', [FFileName, E.Name]);
  DataStart := E.LocalOffset + 30 + Get16(Head, 26) + Get16(Head, 28);
  if E.Size > MaxInt then
    raise EEpubError.CreateFmt('%s: entry %s is too large to read into memory (use Extract)',
      [FFileName, E.Name]);
  case E.Method of
    METHOD_STORED:
      Result := ReadAt(FStream, DataStart, E.Size);
    METHOD_DEFLATED:
      begin
        Packed_ := TMemoryStream.Create;
        try
          FStream.Position := DataStart;
          if E.CompressedSize > 0 then
            Packed_.CopyFrom(FStream, E.CompressedSize);
          Packed_.Position := 0;
          {$ifdef FPC}
          Z := TDecompressionStream.Create(Packed_, True);   // raw deflate
          {$else}
          Z := TZDecompressionStream.Create(Packed_, -15);   // raw deflate
          {$endif}
          try
            SetLength(Result, E.Size);
            Got := 0;
            if E.Size > 0 then
              Got := Z.Read(Result[0], E.Size);
            if Got <> E.Size then
              raise EEpubError.CreateFmt('%s: entry %s is damaged (short data)', [FFileName, E.Name]);
          finally
            Z.Free;
          end;
        finally
          Packed_.Free;
        end;
      end;
  else
    raise EEpubError.CreateFmt('%s: entry %s uses ZIP method %d (only stored and deflated are read)',
      [FFileName, E.Name, E.Method]);
  end;
  if (Length(Result) > 0) and (EpubCrc32(0, @Result[0], Length(Result)) <> E.Crc) then
    raise EEpubError.CreateFmt('%s: entry %s is damaged (CRC)', [FFileName, E.Name]);
end;

function TEpubZipReader.ReadBytes(const AName: string): TBytes;
var
  I: Integer;
begin
  I := IndexOf(AName);
  if I < 0 then
    raise EEpubError.CreateFmt('%s: there is no %s inside', [FFileName, AName]);
  Result := ReadBytes(I);
end;

function TEpubZipReader.ReadText(const AName: string): string;
begin
  Result := EpubBytesText(ReadBytes(AName));
end;

procedure TEpubZipReader.Extract(const AName, AFileName: string);
var
  B: TBytes;
  S: TFileStream;
begin
  B := ReadBytes(AName);
  S := TFileStream.Create(AFileName, fmCreate);
  try
    if Length(B) > 0 then
      S.WriteBuffer(B[0], Length(B));
  finally
    S.Free;
  end;
end;

{ TEpubZipWriter }

constructor TEpubZipWriter.Create(const AFileName: string);
begin
  inherited Create;
  FStream := TFileStream.Create(AFileName, fmCreate);
  FOwnsStream := True;
end;

constructor TEpubZipWriter.Create(AStream: TStream; AOwnsStream: Boolean);
begin
  inherited Create;
  FStream := AStream;
  FOwnsStream := AOwnsStream;
end;

destructor TEpubZipWriter.Destroy;
begin
  if (FStream <> nil) and not FFinished then
    Finish;
  if FOwnsStream then
    FStream.Free;
  inherited;
end;

{ Appends a little-endian 16-bit value. }
procedure Put16(AOut: TStream; AV: Word);
var
  B: array[0..1] of Byte;
begin
  B[0] := AV and $FF;
  B[1] := AV shr 8;
  AOut.WriteBuffer(B, 2);
end;

{ Appends a little-endian 32-bit value. }
procedure Put32(AOut: TStream; AV: Cardinal);
var
  B: array[0..3] of Byte;
begin
  B[0] := AV and $FF;
  B[1] := (AV shr 8) and $FF;
  B[2] := (AV shr 16) and $FF;
  B[3] := AV shr 24;
  AOut.WriteBuffer(B, 4);
end;

procedure TEpubZipWriter.Add(const AName: string; const AData: TBytes; AStored: Boolean);
var
  E: TEpubZipEntry;
  Name: TBytes;
  Packed_: TMemoryStream;
  Z: TStream;
begin
  if FFinished then
    raise EEpubError.Create('The ZIP archive is finished: nothing more can be added');
  if FStream.Position > $FFFFFFFF - Int64(Length(AData)) then
    raise EEpubError.Create('The ZIP archive would pass 4 GB (ZIP64 is not supported)');
  E := Default(TEpubZipEntry);
  E.Name := AName;
  E.Size := Length(AData);
  if Length(AData) > 0 then
    E.Crc := EpubCrc32(0, @AData[0], Length(AData));
  E.Flags := FLAG_UTF8;
  Packed_ := TMemoryStream.Create;
  try
    if AStored or (Length(AData) = 0) then
    begin
      E.Method := METHOD_STORED;
      if Length(AData) > 0 then
        Packed_.WriteBuffer(AData[0], Length(AData));
    end
    else
    begin
      E.Method := METHOD_DEFLATED;
      {$ifdef FPC}
      Z := TCompressionStream.Create(cldefault, Packed_, True);   // raw deflate
      {$else}
      Z := TZCompressionStream.Create(Packed_, zcDefault, -15);   // raw deflate
      {$endif}
      try
        Z.WriteBuffer(AData[0], Length(AData));
      finally
        Z.Free;   // flushes
      end;
    end;
    E.CompressedSize := Packed_.Size;
    E.LocalOffset := FStream.Position;
    Name := EpubUtf8Bytes(AName);
    Put32(FStream, SIG_LOCAL);
    Put16(FStream, ZIP_VERSION);
    Put16(FStream, E.Flags);
    Put16(FStream, E.Method);
    Put16(FStream, 0);   // time
    Put16(FStream, $21); // date: 1980-01-01
    Put32(FStream, E.Crc);
    Put32(FStream, E.CompressedSize);
    Put32(FStream, E.Size);
    Put16(FStream, Length(Name));
    Put16(FStream, 0);   // no extra field (the EPUB mimetype rule)
    if Length(Name) > 0 then
      FStream.WriteBuffer(Name[0], Length(Name));
    Packed_.Position := 0;
    if Packed_.Size > 0 then
      FStream.CopyFrom(Packed_, Packed_.Size);
  finally
    Packed_.Free;
  end;
  SetLength(FEntries, Length(FEntries) + 1);
  FEntries[High(FEntries)] := E;
end;

procedure TEpubZipWriter.Add(const AName, AText: string; AStored: Boolean);
begin
  Add(AName, EpubUtf8Bytes(AText), AStored);
end;

procedure TEpubZipWriter.AddEpubMimetype;
begin
  if Length(FEntries) > 0 then
    raise EEpubError.Create('The EPUB mimetype must be the first entry of the archive');
  Add('mimetype', EPUB_MIMETYPE, True);
end;

procedure TEpubZipWriter.Finish;
var
  I: Integer;
  DirStart, DirEnd: Int64;
  Name: TBytes;
begin
  if FFinished then
    Exit;
  DirStart := FStream.Position;
  for I := 0 to High(FEntries) do
  begin
    Name := EpubUtf8Bytes(FEntries[I].Name);
    Put32(FStream, SIG_CENTRAL);
    Put16(FStream, ZIP_VERSION);   // made by
    Put16(FStream, ZIP_VERSION);   // needed
    Put16(FStream, FEntries[I].Flags);
    Put16(FStream, FEntries[I].Method);
    Put16(FStream, 0);
    Put16(FStream, $21);
    Put32(FStream, FEntries[I].Crc);
    Put32(FStream, FEntries[I].CompressedSize);
    Put32(FStream, FEntries[I].Size);
    Put16(FStream, Length(Name));
    Put16(FStream, 0);   // extra
    Put16(FStream, 0);   // comment
    Put16(FStream, 0);   // disk
    Put16(FStream, 0);   // internal attributes
    Put32(FStream, 0);   // external attributes
    Put32(FStream, FEntries[I].LocalOffset);
    if Length(Name) > 0 then
      FStream.WriteBuffer(Name[0], Length(Name));
  end;
  DirEnd := FStream.Position;
  Put32(FStream, SIG_END);
  Put16(FStream, 0);
  Put16(FStream, 0);
  Put16(FStream, Length(FEntries));
  Put16(FStream, Length(FEntries));
  Put32(FStream, DirEnd - DirStart);
  Put32(FStream, DirStart);
  Put16(FStream, 0);
  FFinished := True;
end;

end.
