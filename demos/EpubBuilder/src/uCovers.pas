(* @abstract(The cover of a book built: a picture from the Covers folder,
  the audiobook's own cover art, or the book's.)

  Owner, 2026-11-20: The Sword of Shannara (a calibre MOBI) came with a
  picture of Word 2000 as its cover - "ok [use the audiobook's], but also
  let user change cover art e.g. by transferring image to builder in
  EpubBuilder\Covers". @link(ChooseCover) decides, in this order:

  @orderedList(
    @item(a picture in the Covers folder named as the book's file, its
      output or its title (.jpg, .jpeg, .png, .webp, .gif; letter case
      ignored) - the user's choice wins;)
    @item(the audiobook's cover art when the book has no cover, or its
      cover is wider than it is high (a book cover never is) - an m4b /
      m4a / aax 'covr', an mp3's ID3 picture, a FLAC picture;)
    @item(else the book's own cover, unchanged.))

  The user can choose instead (owner: "show a thumbnail and let them
  choose"): @link(CoverOptions) lists the pictures there are, the choice
  goes to ChooseCover as AChoice - 'book', 'audio' or a picture's path
  ('' = the rule above).

  No FFmpeg: the boxes and tags are read directly. *)
unit uCovers;

interface

uses
  System.SysUtils, System.Classes;

type
  { A cover the user can choose (CoverOptions). }
  TCoverOption = record
    { The choice to keep: 'book', 'audio' or the picture's path. }
    Choice: string;
    { What it is, for the tile ('The book''s - 680 x 510'). }
    Caption: string;
    { The picture. }
    Data: TBytes;
  end;

  { The covers there are. }
  TCoverOptionArray = array of TCoverOption;

{ The picture type of AData ('jpg', 'png', 'gif', 'webp'; '' when it is
  none of them). }
function PictureType(const AData: TBytes): string;

{ The size of the picture AData (JPEG, PNG, GIF, WebP).
  @returns(False when it cannot be read) }
function PictureSize(const AData: TBytes; out AWidth, AHeight: Integer): Boolean;

{ The cover art inside the audio file AFileName (MP4 'covr', ID3v2 APIC,
  FLAC PICTURE).
  @returns(False when it has none) }
function AudioCover(const AFileName: string; out AData: TBytes): Boolean;

{ The cover art in the audio AStream (AExt its type: '.m4b', '.mp3',
  '.flac' ...) - e.g. an audio file stored inside a book (TStreamWindow).
  @returns(False when it has none) }
function AudioCoverStream(AStream: TStream; const AExt: string; out AData: TBytes): Boolean;

type
  { A part of another stream, read only: ASize bytes from AOffset - an
    entry stored (not compressed) in a ZIP read where it lies. }
  TStreamWindow = class(TStream)
  private
    { The stream (not owned). }
    FBase: TStream;
    { Where the part starts in it. }
    FOffset: Int64;
    { The part's size. }
    FSize: Int64;
    { The position in the part. }
    FPos: Int64;
  protected
    { The part's size. }
    function GetSize: Int64; override;
  public
    { The part of ABase from AOffset, ASize bytes. }
    constructor Create(ABase: TStream; AOffset, ASize: Int64);
    { Reads from the part. }
    function Read(var Buffer; Count: Longint): Longint; override;
    { Not writable. }
    function Write(const Buffer; Count: Longint): Longint; override;
    { Moves in the part. }
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

{ The cover to give the book built ('' AFile and empty AData: the book's
  own is kept).
  @param(ACoversFolder  the Covers folder)
  @param(ANames  names a picture there may have (without extension))
  @param(ABookCover  the book's cover picture (empty when none))
  @param(AAudioFiles  the audio, in order: the first with cover art is used)
  @param(AData  the picture to use (empty: keep the book's))
  @param(AExt  its type)
  @param(AWhy  what was chosen and why, for the log) }
procedure ChooseCover(const ACoversFolder: string; const ANames: array of string; const ABookCover: TBytes;
  AAudioFiles: TStrings; const AChoice: string; out AData: TBytes; out AExt, AWhy: string);

{ The covers the user can choose from: the book's, the audiobook's, the
  Covers folder's pictures (those named as the book first; at most 30).
  @param(ACoversFolder  the Covers folder)
  @param(ANames  names a picture there may have)
  @param(ABookCover  the book's cover (empty: none))
  @param(AAudioFiles  the audio)
  @returns(the options, in that order) }
function CoverOptions(const ACoversFolder: string; const ANames: array of string; const ABookCover: TBytes;
  AAudioFiles: TStrings): TCoverOptionArray;

{ What a choice is, in words ('automatic', 'the book''s', ...). }
function CoverChoiceText(const AChoice: string): string;

implementation

uses
  System.IOUtils, System.StrUtils;

const
  { Picture files of the Covers folder. }
  COVER_EXTS: array[0..4] of string = ('.jpg', '.jpeg', '.png', '.webp', '.gif');
  { The most a cover may be (a bigger "picture" is not one), bytes. }
  COVER_MAX = 32 * 1024 * 1024;

{ Big-endian 16 bits at AP. }
function Be16(const AB: TBytes; AP: Integer): Integer;
begin
  Result := (AB[AP] shl 8) or AB[AP + 1];
end;

{ Big-endian 32 bits at AP. }
function Be32(const AB: TBytes; AP: Integer): Cardinal;
begin
  Result := (Cardinal(AB[AP]) shl 24) or (Cardinal(AB[AP + 1]) shl 16) or (Cardinal(AB[AP + 2]) shl 8) or
    AB[AP + 3];
end;

{ Little-endian 16 bits at AP. }
function Le16(const AB: TBytes; AP: Integer): Integer;
begin
  Result := AB[AP] or (AB[AP + 1] shl 8);
end;

{ Little-endian 24 bits at AP. }
function Le24(const AB: TBytes; AP: Integer): Integer;
begin
  Result := AB[AP] or (AB[AP + 1] shl 8) or (AB[AP + 2] shl 16);
end;

function PictureType(const AData: TBytes): string;
begin
  Result := '';
  if Length(AData) < 12 then
    Exit;
  if (AData[0] = $FF) and (AData[1] = $D8) then
    Result := 'jpg'
  else if (AData[0] = $89) and (AData[1] = Ord('P')) and (AData[2] = Ord('N')) and (AData[3] = Ord('G')) then
    Result := 'png'
  else if (AData[0] = Ord('G')) and (AData[1] = Ord('I')) and (AData[2] = Ord('F')) then
    Result := 'gif'
  else if (AData[0] = Ord('R')) and (AData[1] = Ord('I')) and (AData[8] = Ord('W')) and (AData[9] = Ord('E')) then
    Result := 'webp';
end;

function PictureSize(const AData: TBytes; out AWidth, AHeight: Integer): Boolean;
var
  T: string;
  P, L, M: Integer;
begin
  Result := False;
  AWidth := 0;
  AHeight := 0;
  T := PictureType(AData);
  try
    if T = 'png' then
    begin
      AWidth := Be32(AData, 16);
      AHeight := Be32(AData, 20);
    end
    else if T = 'gif' then
    begin
      AWidth := Le16(AData, 6);
      AHeight := Le16(AData, 8);
    end
    else if T = 'jpg' then
    begin
      // the frame header (SOF0 - SOF15, not DHT / JPG / DAC)
      P := 2;
      while P + 9 < Length(AData) do
      begin
        if AData[P] <> $FF then
          Exit;
        M := AData[P + 1];
        if M = $FF then
        begin
          Inc(P);
          Continue;
        end;
        L := Be16(AData, P + 2);
        if (M >= $C0) and (M <= $CF) and (M <> $C4) and (M <> $C8) and (M <> $CC) then
        begin
          AHeight := Be16(AData, P + 5);
          AWidth := Be16(AData, P + 7);
          Break;
        end;
        Inc(P, 2 + L);
      end;
    end
    else if T = 'webp' then
    begin
      if (AData[12] = Ord('V')) and (AData[15] = Ord(' ')) then
      begin
        // VP8: lossy
        AWidth := Le16(AData, 26) and $3FFF;
        AHeight := Le16(AData, 28) and $3FFF;
      end
      else if (AData[12] = Ord('V')) and (AData[15] = Ord('L')) then
      begin
        // VP8L: lossless, 14 bits each after the signature
        AWidth := (Le16(AData, 21) and $3FFF) + 1;
        AHeight := ((Le24(AData, 22) shr 6) and $3FFF) + 1;
      end
      else if (AData[12] = Ord('V')) and (AData[15] = Ord('X')) then
      begin
        // VP8X: 24 bits each, minus one
        AWidth := Le24(AData, 24) + 1;
        AHeight := Le24(AData, 27) + 1;
      end;
    end;
  except
    // a cut picture: not known
    AWidth := 0;
    AHeight := 0;
  end;
  Result := (AWidth > 0) and (AHeight > 0);
end;

{ ACount bytes of AStream from APos (fewer at its end). }
function ReadAt(AStream: TStream; APos: Int64; ACount: Integer): TBytes;
begin
  Result := nil;
  if (APos < 0) or (ACount <= 0) or (APos >= AStream.Size) then
    Exit;
  if APos + ACount > AStream.Size then
    ACount := AStream.Size - APos;
  SetLength(Result, ACount);
  AStream.Position := APos;
  AStream.ReadBuffer(Result[0], ACount);
end;

{ The child box AType of the MP4 box between AFrom and ATo: its content's
  start and end (after the 8 or 16 byte header).
  @returns(False when there is none) }
function FindBox(AStream: TStream; AFrom, ATo: Int64; const AType: AnsiString; out AStart, AEnd: Int64): Boolean;
var
  H: TBytes;
  Size: Int64;
  HeaderLen: Integer;
  T: AnsiString;
begin
  Result := False;
  while AFrom + 8 <= ATo do
  begin
    H := ReadAt(AStream, AFrom, 16);
    if Length(H) < 8 then
      Exit;
    Size := Be32(H, 0);
    SetString(T, PAnsiChar(@H[4]), 4);
    HeaderLen := 8;
    if (Size = 1) and (Length(H) >= 16) then
    begin
      Size := (Int64(Be32(H, 8)) shl 32) or Be32(H, 12);
      HeaderLen := 16;
    end
    else if Size = 0 then
      Size := ATo - AFrom;
    if Size < HeaderLen then
      Exit;
    if T = AType then
    begin
      AStart := AFrom + HeaderLen;
      AEnd := AFrom + Size;
      Exit(True);
    end;
    Inc(AFrom, Size);
  end;
end;

{ An MP4's cover: moov/udta/meta/ilst/covr/data. }
function Mp4Cover(AStream: TStream; out AData: TBytes): Boolean;
var
  S, E, S2, E2: Int64;
begin
  Result := False;
  AData := nil;
  if not FindBox(AStream, 0, AStream.Size, 'moov', S, E) then
    Exit;
  if not FindBox(AStream, S, E, 'udta', S, E) then
    Exit;
  if not FindBox(AStream, S, E, 'meta', S, E) then
    Exit;
  // meta is a full box: version and flags first
  if not FindBox(AStream, S + 4, E, 'ilst', S, E) then
    Exit;
  if not FindBox(AStream, S, E, 'covr', S, E) then
    Exit;
  if not FindBox(AStream, S, E, 'data', S2, E2) then
    Exit;
  // type (4) and locale (4), then the picture
  if (E2 - S2 <= 8) or (E2 - S2 > COVER_MAX) then
    Exit;
  AData := ReadAt(AStream, S2 + 8, E2 - S2 - 8);
  Result := PictureType(AData) <> '';
end;

{ An ID3v2 synchsafe size. }
function SyncSafe(const AB: TBytes; AP: Integer): Integer;
begin
  Result := (AB[AP] shl 21) or (AB[AP + 1] shl 14) or (AB[AP + 2] shl 7) or AB[AP + 3];
end;

{ An MP3's cover: ID3v2.3 / 2.4 APIC (the front cover, else the first). }
function Id3Cover(AStream: TStream; out AData: TBytes): Boolean;
var
  H, Tag, Pic: TBytes;
  Ver, TagSize, P, FrameSize, Q, Enc: Integer;
  Id: AnsiString;
  Kind: Byte;
begin
  Result := False;
  AData := nil;
  H := ReadAt(AStream, 0, 10);
  if (Length(H) < 10) or (H[0] <> Ord('I')) or (H[1] <> Ord('D')) or (H[2] <> Ord('3')) then
    Exit;
  Ver := H[3];
  // unsynchronised tags (rare) are not read
  if ((Ver <> 3) and (Ver <> 4)) or ((H[5] and $80) <> 0) then
    Exit;
  TagSize := SyncSafe(H, 6);
  if (TagSize <= 0) or (TagSize > COVER_MAX) then
    Exit;
  Tag := ReadAt(AStream, 10, TagSize);
  P := 0;
  // an extended header
  if (H[5] and $40) <> 0 then
    if Ver = 4 then
      Inc(P, SyncSafe(Tag, 0))
    else
      Inc(P, Integer(Be32(Tag, 0)) + 4);
  while P + 10 <= Length(Tag) do
  begin
    SetString(Id, PAnsiChar(@Tag[P]), 4);
    if Tag[P] = 0 then
      Break;
    if Ver = 4 then
      FrameSize := SyncSafe(Tag, P + 4)
    else
      FrameSize := Be32(Tag, P + 4);
    if (FrameSize <= 0) or (P + 10 + FrameSize > Length(Tag)) then
      Break;
    if Id = 'APIC' then
    begin
      Q := P + 10;
      Enc := Tag[Q];
      Inc(Q);
      // the MIME type, ended by 0
      while (Q < P + 10 + FrameSize) and (Tag[Q] <> 0) do
        Inc(Q);
      Inc(Q);
      Kind := Tag[Q];
      Inc(Q);
      // the description, ended by 0 (00 00 in UTF-16)
      if (Enc = 1) or (Enc = 2) then
      begin
        while (Q + 1 < P + 10 + FrameSize) and not ((Tag[Q] = 0) and (Tag[Q + 1] = 0)) do
          Inc(Q, 2);
        Inc(Q, 2);
      end
      else
      begin
        while (Q < P + 10 + FrameSize) and (Tag[Q] <> 0) do
          Inc(Q);
        Inc(Q);
      end;
      if Q < P + 10 + FrameSize then
      begin
        Pic := Copy(Tag, Q, P + 10 + FrameSize - Q);
        if PictureType(Pic) <> '' then
        begin
          // the front cover (3) wins; else the first picture
          if (Kind = 3) or (AData = nil) then
            AData := Pic;
          if Kind = 3 then
            Break;
        end;
      end;
    end;
    Inc(P, 10 + FrameSize);
  end;
  Result := AData <> nil;
end;

{ A FLAC's cover: METADATA_BLOCK_PICTURE (the front cover, else the
  first). }
function FlacCover(AStream: TStream; out AData: TBytes): Boolean;
var
  H, B, Pic: TBytes;
  P: Int64;
  Last: Boolean;
  BlockType, Len, Q, Kind, N: Integer;
begin
  Result := False;
  AData := nil;
  H := ReadAt(AStream, 0, 4);
  if (Length(H) < 4) or (H[0] <> Ord('f')) or (H[1] <> Ord('L')) or (H[2] <> Ord('a')) or (H[3] <> Ord('C')) then
    Exit;
  P := 4;
  repeat
    H := ReadAt(AStream, P, 4);
    if Length(H) < 4 then
      Break;
    Last := (H[0] and $80) <> 0;
    BlockType := H[0] and $7F;
    Len := (H[1] shl 16) or (H[2] shl 8) or H[3];
    if (BlockType = 6) and (Len > 32) and (Len <= COVER_MAX) then
    begin
      B := ReadAt(AStream, P + 4, Len);
      Kind := Be32(B, 0);
      Q := 4;
      N := Be32(B, Q);           // MIME
      Inc(Q, 4 + N);
      N := Be32(B, Q);           // description
      Inc(Q, 4 + N + 16);        // width, height, depth, colours
      N := Be32(B, Q);           // the picture
      Inc(Q, 4);
      if (N > 0) and (Q + N <= Length(B)) then
      begin
        Pic := Copy(B, Q, N);
        if PictureType(Pic) <> '' then
        begin
          if (Kind = 3) or (AData = nil) then
            AData := Pic;
          if Kind = 3 then
            Break;
        end;
      end;
    end;
    Inc(P, 4 + Len);
  until Last;
  Result := AData <> nil;
end;

function AudioCoverStream(AStream: TStream; const AExt: string; out AData: TBytes): Boolean;
var
  Ext: string;
begin
  Result := False;
  AData := nil;
  try
    Ext := LowerCase(AExt);
    if (Ext = '.m4b') or (Ext = '.m4a') or (Ext = '.aax') or (Ext = '.mp4') or (Ext = '.aac') then
      Result := Mp4Cover(AStream, AData)
    else if Ext = '.mp3' then
      Result := Id3Cover(AStream, AData)
    else if Ext = '.flac' then
      Result := FlacCover(AStream, AData);
  except
    // not readable: no cover from it
    AData := nil;
    Result := False;
  end;
end;

function AudioCover(const AFileName: string; out AData: TBytes): Boolean;
var
  F: TFileStream;
begin
  Result := False;
  AData := nil;
  try
    F := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      Result := AudioCoverStream(F, ExtractFileExt(AFileName), AData);
    finally
      F.Free;
    end;
  except
    AData := nil;
    Result := False;
  end;
end;

{ TStreamWindow }

constructor TStreamWindow.Create(ABase: TStream; AOffset, ASize: Int64);
begin
  inherited Create;
  FBase := ABase;
  FOffset := AOffset;
  FSize := ASize;
end;

function TStreamWindow.GetSize: Int64;
begin
  Result := FSize;
end;

function TStreamWindow.Read(var Buffer; Count: Longint): Longint;
begin
  if FPos + Count > FSize then
    Count := FSize - FPos;
  if Count <= 0 then
    Exit(0);
  FBase.Position := FOffset + FPos;
  Result := FBase.Read(Buffer, Count);
  Inc(FPos, Result);
end;

function TStreamWindow.Write(const Buffer; Count: Longint): Longint;
begin
  Result := 0;
end;

function TStreamWindow.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning: FPos := Offset;
    soCurrent: FPos := FPos + Offset;
    soEnd: FPos := FSize + Offset;
  end;
  Result := FPos;
end;

{ The size of AData as ' - W x H' ('' when not known). }
function SizeText(const AData: TBytes): string;
var
  W, H: Integer;
begin
  if PictureSize(AData, W, H) then
    Result := Format(' - %d x %d', [W, H])
  else
    Result := '';
end;

function CoverChoiceText(const AChoice: string): string;
begin
  if AChoice = '' then
    Result := 'automatic'
  else if AChoice = 'book' then
    Result := 'the book''s'
  else if AChoice = 'audio' then
    Result := 'the audiobook''s'
  else
    Result := ExtractFileName(AChoice);
end;

function CoverOptions(const ACoversFolder: string; const ANames: array of string; const ABookCover: TBytes;
  AAudioFiles: TStrings): TCoverOptionArray;
var
  O: TCoverOption;
  Files, Named, Others: TArray<string>;
  F, N: string;
  I: Integer;
  Match: Boolean;
begin
  Result := nil;
  if Length(ABookCover) > 0 then
  begin
    O.Choice := 'book';
    O.Caption := 'The book''s' + SizeText(ABookCover);
    O.Data := ABookCover;
    Result := Result + [O];
  end;
  for I := 0 to AAudioFiles.Count - 1 do
    if AudioCover(AAudioFiles[I], O.Data) then
    begin
      O.Choice := 'audio';
      O.Caption := 'The audiobook''s' + SizeText(O.Data);
      Result := Result + [O];
      Break;
    end;
  Named := nil;
  Others := nil;
  try
    if (ACoversFolder <> '') and TDirectory.Exists(ACoversFolder) then
    begin
      Files := TDirectory.GetFiles(ACoversFolder);
      for F in Files do
        if IndexText(ExtractFileExt(F), COVER_EXTS) >= 0 then
        begin
          Match := False;
          for N in ANames do
            if (Trim(N) <> '') and SameText(ChangeFileExt(ExtractFileName(F), ''), Trim(N)) then
              Match := True;
          if Match then
            Named := Named + [F]
          else
            Others := Others + [F];
        end;
    end;
  except
    // the folder not readable: the others only
  end;
  for F in Named + Others do
  begin
    if Length(Result) >= 30 then
      Break;
    try
      O.Data := TFile.ReadAllBytes(F);
    except
      Continue;
    end;
    if PictureType(O.Data) = '' then
      Continue;
    O.Choice := F;
    O.Caption := ExtractFileName(F) + SizeText(O.Data);
    Result := Result + [O];
  end;
end;

procedure ChooseCover(const ACoversFolder: string; const ANames: array of string; const ABookCover: TBytes;
  AAudioFiles: TStrings; const AChoice: string; out AData: TBytes; out AExt, AWhy: string);
var
  Files: TArray<string>;
  F, N, Base, Own: string;
  W, H, I: Integer;
begin
  AData := nil;
  AExt := '';
  AWhy := '';
  // the user's choice first
  if AChoice = 'book' then
  begin
    AWhy := 'Cover: the book''s own (chosen)';
    Exit;
  end;
  if AChoice = 'audio' then
  begin
    for I := 0 to AAudioFiles.Count - 1 do
      if AudioCover(AAudioFiles[I], AData) then
      begin
        AExt := PictureType(AData);
        AWhy := 'Cover: the audiobook''s (chosen' + SizeText(AData) + ')';
        Exit;
      end;
    AData := nil;
    AWhy := 'Cover: the audiobook''s was chosen but the audio has none now - ';
  end
  else if AChoice <> '' then
  begin
    try
      AData := TFile.ReadAllBytes(AChoice);
      AExt := PictureType(AData);
    except
      AData := nil;
    end;
    if AExt <> '' then
    begin
      AWhy := 'Cover: ' + AChoice + ' (chosen' + SizeText(AData) + ')';
      Exit;
    end;
    AData := nil;
    AWhy := 'Cover: ' + AChoice + ' was chosen but cannot be read as a picture - ';
  end;
  // 1. the user's: a picture in the Covers folder with the book's name
  try
    if (ACoversFolder <> '') and TDirectory.Exists(ACoversFolder) then
    begin
      Files := TDirectory.GetFiles(ACoversFolder);
      for N in ANames do
        if Trim(N) <> '' then
          for F in Files do
          begin
            Base := ChangeFileExt(ExtractFileName(F), '');
            if SameText(Base, Trim(N)) and (IndexText(ExtractFileExt(F), COVER_EXTS) >= 0) then
            begin
              AData := TFile.ReadAllBytes(F);
              AExt := PictureType(AData);
              if AExt <> '' then
              begin
                AWhy := 'Cover: ' + F + ' (the Covers folder)';
                Exit;
              end;
              AData := nil;
            end;
          end;
    end;
  except
    on E: Exception do
      AWhy := 'Cover: the Covers folder could not be read (' + E.Message + '); ';
  end;
  // 2. the audiobook's, when the book's is missing or not a cover's shape
  if Length(ABookCover) = 0 then
    Own := 'the book has no cover'
  else if PictureSize(ABookCover, W, H) and (W > H) then
    Own := Format('the book''s cover is %d x %d - wider than high, not a book cover', [W, H])
  else
    Own := '';
  if Own <> '' then
  begin
    for I := 0 to AAudioFiles.Count - 1 do
      if AudioCover(AAudioFiles[I], AData) then
      begin
        AExt := PictureType(AData);
        if PictureSize(AData, W, H) then
          AWhy := AWhy + Format('Cover: the audiobook''s (%d x %d, from %s) - %s', [W, H,
            ExtractFileName(AAudioFiles[I]), Own])
        else
          AWhy := AWhy + Format('Cover: the audiobook''s (from %s) - %s', [ExtractFileName(AAudioFiles[I]), Own]);
        Exit;
      end;
    AData := nil;
    AWhy := AWhy + 'Cover: the book''s kept - ' + Own + ', and the audio has no cover art (put one in the ' +
      'Covers folder, named as the book)';
    Exit;
  end;
  AWhy := AWhy + 'Cover: the book''s own';
end;

end.
