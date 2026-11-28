(* @abstract(What the reader keeps of each book on the device - its index,
  chapters and page layouts - held to a size, and never the device's last
  space.)

  Owner, 2026-11-27 21:25: "32 books with indices took 221Mb ... We need to
  limit how much we use (this is especially true for apple)"; 21:30 "OK to
  storage sizes" (250 MB on a TV, a menu setting, 1 GB on a phone) and "It
  must NEVER be possible to run out of storage space" (zip 397).

  Two rules:
  - @bold(Never the last space): nothing the reader makes for itself is
    written when it would leave less than STORE_RESERVE free on that
    volume (@link(StoreMayWrite)) - an index is then not kept (the book
    opens the slow way), a cover not made (the title shows).
  - @bold(A size for the books' files) (the store: every file index\<md5>
    with any extension): when
    it is over, books make way (@link(StoreVictims)) - books no longer in
    the library first, then books prepared but never opened (oldest
    first), then the opened ones not opened for longest; the open book,
    the one being prepared and the few opened last never. The budget
    shrinks to what the volume has to spare (its free space less
    STORE_RESERVE) when that is less.

  Everything here is made again when needed: a book whose files went is
  read in full at its next opening. Pure functions and file work: no form,
  any thread. *)

unit uBookStore;

interface

uses
  System.SysUtils, System.Classes;

const
  { Space never taken by what the reader writes for itself (1 GiB): the
    device needs room for itself. }
  STORE_RESERVE = Int64(1024) * 1024 * 1024;
  { The sizes the store can be given (MB), in the menu's order. }
  STORE_SIZES_MB: array[0..4] of Integer = (100, 250, 500, 1000, 2000);
  { A TV's store (MB): the owner's 250 MB (the Shield's 32 books took
    221 MB). }
  STORE_TV_MB = 250;
  { A phone's (MB). }
  STORE_PHONE_MB = 1000;
  { A computer's (MB). }
  STORE_DESKTOP_MB = 2000;
  { The books opened last that never make way. }
  STORE_KEEP_OPENED = 3;

type
  { One book's files in the store: index\<Key>.* }
  TStoreBook = record
    { The MD5 of its file name (BookIndexFile's). }
    Key: string;
    { Its files' bytes. }
    Size: Int64;
    { When its newest file was written. }
    Newest: TDateTime;
  end;

  { The store looked through (StoreScan). }
  TStoreScan = record
    { Each book's files. }
    Books: TArray<TStoreBook>;
    { All of them. }
    Total: Int64;
    { Of which indexes (.euix). }
    Indexes: Int64;
    { Chapter lists (.chapters.json). }
    Chapters: Int64;
    { Page layouts (.eul). }
    Layouts: Int64;
    { Temporary files left by a write cut off (deleted when old). }
    Temps: Int64;
    { The covers' folder (not in the budget: the library shows them). }
    Covers: Int64;
    { How many covers. }
    CoverCount: Integer;
  end;

  { What the library knows of a book, for choosing what makes way. }
  TStoreUse = record
    { Its store key. }
    Key: string;
    { Times opened (0: prepared, never read). }
    Opens: Integer;
    { When last opened (0: not known). }
    LastOpen: TDateTime;
    { Its place in the library's recent order (0 = read last). }
    Rank: Integer;
    { Never makes way (the open book, the one being prepared, the few
      opened last). }
    Keep: Boolean;
  end;

{ Free bytes on AFolder's volume (-1: not known). A folder not made yet is
  measured by the nearest one above it that is there (the iPad's first
  start: the store's folder did not exist and the space was "?" - zip 404).
  @param(AFolder  a folder on it)
  @returns(the bytes) }
function StoreFree(const AFolder: string): Int64;

{ ASize bytes may be written in AFolder: STORE_RESERVE stays free after
  (any thread). When the free space is not known: no on a phone, tablet or
  TV (Android, iOS: it must never be possible to fill one - owner,
  2026-11-27), yes elsewhere.
  @param(AFolder  where)
  @param(ASize  how much)
  @param(AWhy  why not, for the log)
  @returns(the answer) }
function StoreMayWrite(const AFolder: string; ASize: Int64; out AWhy: string): Boolean;

{ Looks through the store AIndexFolder (each book's files by their key)
  and the covers' folder ACoverFolder; temporary files over an hour old
  are deleted.
  @param(AIndexFolder  index\)
  @param(ACoverFolder  covers\)
  @returns(what is there) }
function StoreScan(const AIndexFolder, ACoverFolder: string): TStoreScan;

{ The books that make way so that the store is at most ABudget: books not
  in AUses first, then those never opened (oldest written first), then the
  opened ones (last opened longest ago first; the library's order when not
  known); a Keep one never.
  @param(AScan  the store)
  @param(AUses  the library's books)
  @param(ABudget  bytes)
  @param(AAfter  the store's size after)
  @returns(their keys, in the order they go) }
function StoreVictims(const AScan: TStoreScan; const AUses: TArray<TStoreUse>; ABudget: Int64;
  out AAfter: Int64): TArray<string>;

{ Deletes the book AKey's files in the store (index\<AKey> with any extension).
  @param(AIndexFolder  index\)
  @param(AKey  its key)
  @returns(the bytes freed) }
function StoreDropBook(const AIndexFolder, AKey: string): Int64;

{ Bytes as the log and the menu say them ('180 MB', '1.2 GB').
  @param(ABytes  the bytes)
  @returns(the text) }
function StoreText(ABytes: Int64): string;

implementation

uses
  System.IOUtils, System.DateUtils, System.Math, System.StrUtils, System.Generics.Collections,
  System.Generics.Defaults, uLink;

type
  { A book that may make way, and its order (StoreVictims). }
  TStoreCandidate = record
    { Its index in the scan's Books. }
    Book: Integer;
    { 0 not in the library, 1 never opened, 2 opened. }
    Tier: Integer;
    { Within the tier: the smaller goes first. }
    Age: Double;
  end;

const
  { A temporary file older than this (days) was left by a write cut off. }
  TEMP_OLD_DAYS = 1 / 24;

function StoreFree(const AFolder: string): Int64;
var
  Folder, Up: string;
begin
  Result := -1;
  try
    Folder := ExcludeTrailingPathDelimiter(AFolder);
    // up to one that is there (at most the volume's root)
    while (Folder <> '') and not TDirectory.Exists(Folder) do
    begin
      Up := ExcludeTrailingPathDelimiter(ExtractFilePath(Folder));
      if Up = Folder then
        Break;
      Folder := Up;
    end;
    if Folder = '' then
      Folder := AFolder;
    Result := LinkFreeSpace(Folder);
  except
    Result := -1;
  end;
end;

function StoreMayWrite(const AFolder: string; ASize: Int64; out AWhy: string): Boolean;
var
  Free: Int64;
begin
  AWhy := '';
  Free := StoreFree(AFolder);
  {$IF Defined(ANDROID) or Defined(IOS)}
  if Free < 0 then
  begin
    AWhy := 'the free space is not known - nothing written';
    Exit(False);
  end;
  {$ENDIF}
  Result := (Free < 0) or (Free - ASize >= STORE_RESERVE);
  if not Result then
    AWhy := Format('no room: %s to write, %s free and %s always kept free', [StoreText(ASize),
      StoreText(Free), StoreText(STORE_RESERVE)]);
end;

{ A store file's key: its name up to the first dot ('<md5>').
  @param(AName  the file's name)
  @returns(the key) }
function KeyOf(const AName: string): string;
var
  P: Integer;
begin
  P := Pos('.', AName);
  if P > 0 then
    Result := LowerCase(Copy(AName, 1, P - 1))
  else
    Result := LowerCase(AName);
end;

function StoreScan(const AIndexFolder, ACoverFolder: string): TStoreScan;
var
  SR: TSearchRec;
  Map: TDictionary<string, Integer>;
  B: TStoreBook;
  I: Integer;
  Name: string;
  Size: Int64;
begin
  Result := Default(TStoreScan);
  Map := TDictionary<string, Integer>.Create;
  try
    if DirectoryExists(AIndexFolder) and
      (FindFirst(IncludeTrailingPathDelimiter(AIndexFolder) + '*', faAnyFile, SR) = 0) then
      try
        repeat
          if (SR.Attr and faDirectory) <> 0 then
            Continue;
          Name := SR.Name;
          Size := SR.Size;
          // a write cut off long ago: its temporary file goes
          if EndsText('.tmp', Name) then
          begin
            if Now - SR.TimeStamp > TEMP_OLD_DAYS then
              System.SysUtils.DeleteFile(IncludeTrailingPathDelimiter(AIndexFolder) + Name)
            else
              Inc(Result.Temps, Size);
            Continue;
          end;
          if EndsText('.euix', Name) then
            Inc(Result.Indexes, Size)
          else if EndsText('.chapters.json', Name) then
            Inc(Result.Chapters, Size)
          else if EndsText('.eul', Name) then
            Inc(Result.Layouts, Size);
          Inc(Result.Total, Size);
          if not Map.TryGetValue(KeyOf(Name), I) then
          begin
            B := Default(TStoreBook);
            B.Key := KeyOf(Name);
            Result.Books := Result.Books + [B];
            I := High(Result.Books);
            Map.Add(B.Key, I);
          end;
          Inc(Result.Books[I].Size, Size);
          if SR.TimeStamp > Result.Books[I].Newest then
            Result.Books[I].Newest := SR.TimeStamp;
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
  finally
    Map.Free;
  end;
  if DirectoryExists(ACoverFolder) and
    (FindFirst(IncludeTrailingPathDelimiter(ACoverFolder) + '*', faAnyFile, SR) = 0) then
    try
      repeat
        if (SR.Attr and faDirectory) = 0 then
        begin
          Inc(Result.Covers, SR.Size);
          Inc(Result.CoverCount);
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
end;

function StoreVictims(const AScan: TStoreScan; const AUses: TArray<TStoreUse>; ABudget: Int64;
  out AAfter: Int64): TArray<string>;
var
  UseOf: TDictionary<string, Integer>;
  Cands: TList<TStoreCandidate>;
  C: TStoreCandidate;
  I, U: Integer;
  Use: TStoreUse;
begin
  Result := nil;
  AAfter := AScan.Total;
  if AAfter <= ABudget then
    Exit;
  UseOf := TDictionary<string, Integer>.Create;
  Cands := TList<TStoreCandidate>.Create;
  try
    for I := 0 to High(AUses) do
    begin
      // the same book twice (two copies of one name): kept if either says so
      if UseOf.TryGetValue(LowerCase(AUses[I].Key), U) then
      begin
        if AUses[I].Keep or (not AUses[U].Keep and (AUses[I].Opens > AUses[U].Opens)) then
          UseOf[LowerCase(AUses[I].Key)] := I;
      end
      else
        UseOf.Add(LowerCase(AUses[I].Key), I);
    end;
    for I := 0 to High(AScan.Books) do
    begin
      C.Book := I;
      if not UseOf.TryGetValue(AScan.Books[I].Key, U) then
      begin
        C.Tier := 0;
        C.Age := AScan.Books[I].Newest;
      end
      else
      begin
        Use := AUses[U];
        if Use.Keep then
          Continue;
        if Use.Opens <= 0 then
        begin
          C.Tier := 1;
          C.Age := AScan.Books[I].Newest;
        end
        else
        begin
          C.Tier := 2;
          // not known: the library's order (later = read longer ago)
          if Use.LastOpen > 0 then
            C.Age := Use.LastOpen
          else
            C.Age := -1E6 + (-Use.Rank);
        end;
      end;
      Cands.Add(C);
    end;
    Cands.Sort(TComparer<TStoreCandidate>.Construct(
      function(const A, B: TStoreCandidate): Integer
      begin
        Result := CompareValue(A.Tier, B.Tier);
        if Result = 0 then
          Result := CompareValue(A.Age, B.Age);
      end));
    for C in Cands do
    begin
      if AAfter <= ABudget then
        Break;
      Result := Result + [AScan.Books[C.Book].Key];
      Dec(AAfter, AScan.Books[C.Book].Size);
    end;
  finally
    Cands.Free;
    UseOf.Free;
  end;
end;

function StoreDropBook(const AIndexFolder, AKey: string): Int64;
var
  SR: TSearchRec;
  Folder: string;
begin
  Result := 0;
  if AKey = '' then
    Exit;
  Folder := IncludeTrailingPathDelimiter(AIndexFolder);
  if FindFirst(Folder + AKey + '.*', faAnyFile, SR) = 0 then
    try
      repeat
        // a write under way (its temporary file) is left to finish
        if ((SR.Attr and faDirectory) = 0) and not EndsText('.tmp', SR.Name) and
          SameText(KeyOf(SR.Name), AKey) then
          if System.SysUtils.DeleteFile(Folder + SR.Name) then
            Inc(Result, SR.Size);
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
end;

function StoreText(ABytes: Int64): string;
begin
  if ABytes < 0 then
    Result := '?'
  else if ABytes >= Int64(1000) * 1024 * 1024 then
    Result := Format('%.1f GB', [ABytes / (1024.0 * 1024 * 1024)])
  else
    Result := Format('%d MB', [Round(ABytes / (1024.0 * 1024))]);
end;

end.
