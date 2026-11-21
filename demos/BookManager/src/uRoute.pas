(* @abstract(Where files dropped on BookManager go on EpubBuilder: books to
  its books folder, audio to its audio folder, pictures to its Covers
  folder - a folder's files each to their place.)

  Owner, 2026-11-20: "drag a book to it and builder sticks it in books,
  drag audio -> audio, drag folder - send right bits to right locations".

  @unorderedList(
    @item(@bold(A file) dropped goes into its kind's folder itself.)
    @item(@bold(A folder) dropped is walked: each book and audio file keeps
      the folders it was in, from the dropped folder's name down - an
      audiobook's folder of parts stays one folder on the builder (its
      audio list offers a folder of files as one book), a folder of
      several books stays as it was.)
    @item(@bold(Pictures) go into Covers by their own name, without
      folders: EpubBuilder gives a book the picture named as the book. A
      picture beside audio files (folder.jpg, cover.jpg) is not one of
      those - it is left out, and said so; the builder already takes the
      audiobook's own picture.)
    @item(Left out, and said so: other files (text, playlists, ...),
      hidden files and folders (a name starting with a dot) and .part
      files of unfinished copies.)) *)
unit uRoute;

interface

type
  { One file to send. }
  TRouteItem = record
    { The file, with its folder. }
    FileName: string;
    { 'book', 'audio' or 'cover' (uLink's LinkKindOf). }
    Kind: string;
    { The folder under the kind's folder on the builder ('' = the kind's
      folder itself), '/' between names. }
    Dir: string;
    { Its size, bytes. }
    Size: Int64;
  end;

  { Files to send. }
  TRouteItems = TArray<TRouteItem>;

{ The files to send for the files and folders APaths (dropped or chosen):
  books first, then pictures, then audio, each in name order; the same
  file named twice is sent once.
  @param(APaths  files and folders)
  @param(ASkipped  what is left out: 'file - why' a line)
  @returns(the files) }
function RouteFiles(const APaths: array of string; out ASkipped: TArray<string>): TRouteItems;

{ The bytes of the files of AKind in AItems ('' = all).
  @param(AItems  the files)
  @param(AKind  'book', 'audio', 'cover' or '')
  @returns(the sum) }
function RouteSize(const AItems: TRouteItems; const AKind: string): Int64;

{ 'book', 'audio' or 'picture' for a kind, as the window says it.
  @param(AKind  'book', 'audio' or 'cover')
  @returns(the word) }
function RouteKindText(const AKind: string): string;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils, System.StrUtils, System.Generics.Defaults,
  System.Generics.Collections, uLink;

{ A name left out: hidden (starting with a dot) or an unfinished copy. }
function Hidden(const AName: string): Boolean;
begin
  Result := (AName = '') or (AName[1] = '.') or EndsText('.part', AName);
end;

{ AFolder has audio files directly in it. }
function HasAudio(const AFolder: string): Boolean;
var
  F: string;
begin
  Result := False;
  try
    for F in TDirectory.GetFiles(AFolder) do
      if LinkKindOf(F) = 'audio' then
        Exit(True);
  except
    // unreadable: as none
  end;
end;

{ The size of AFileName (-1 when it cannot be read). }
function FileSizeOf(const AFileName: string): Int64;
begin
  try
    Result := TFile.GetSize(AFileName);
  except
    Result := -1;
  end;
end;

{ The order books, pictures, audio. }
function KindRank(const AKind: string): Integer;
begin
  if AKind = 'book' then
    Result := 0
  else if AKind = 'cover' then
    Result := 1
  else
    Result := 2;
end;

function RouteKindText(const AKind: string): string;
begin
  if AKind = 'cover' then
    Result := 'picture'
  else
    Result := AKind;
end;

function RouteFiles(const APaths: array of string; out ASkipped: TArray<string>): TRouteItems;
var
  Seen, Skipped: TStringList;
  Items: TList<TRouteItem>;
  Path, Root, Name, F, Rel, Dir, Part: string;
  Parts: TArray<string>;
  Bad: Boolean;

  { Adds AFileName as its kind, in the folder ADir. }
  procedure Add(const AFileName, ADir: string);
  var
    It: TRouteItem;
    Kind: string;
  begin
    if Seen.IndexOf(AFileName) >= 0 then
      Exit;
    Seen.Add(AFileName);
    Kind := LinkKindOf(AFileName);
    if Kind = '' then
    begin
      Skipped.Add(AFileName + ' - not a book, audio or picture');
      Exit;
    end;
    It := Default(TRouteItem);
    It.FileName := AFileName;
    It.Kind := Kind;
    It.Size := FileSizeOf(AFileName);
    if It.Size < 0 then
    begin
      Skipped.Add(AFileName + ' - cannot be read');
      Exit;
    end;
    // pictures: Covers itself (found by the book's name)
    if Kind = 'cover' then
    begin
      if (ADir <> '') and HasAudio(ExtractFileDir(AFileName)) then
      begin
        Skipped.Add(AFileName + ' - a picture beside audio files (the builder takes the audiobook''s own ' +
          'picture; for another, drop a picture named as the book)');
        Exit;
      end;
      It.Dir := '';
    end
    else
      It.Dir := ADir;
    Items.Add(It);
  end;

begin
  Seen := TStringList.Create;
  Skipped := TStringList.Create;
  Items := TList<TRouteItem>.Create;
  try
    Seen.Sorted := True;
    Seen.CaseSensitive := True;
    for Path in APaths do
    begin
      Root := ExcludeTrailingPathDelimiter(Path);
      if TDirectory.Exists(Root) then
      begin
        Name := ExtractFileName(Root);
        if Hidden(Name) then
        begin
          Skipped.Add(Root + ' - a hidden folder');
          Continue;
        end;
        for F in TDirectory.GetFiles(Root, '*', TSearchOption.soAllDirectories) do
        begin
          // the path under the dropped folder: 'sub/file'
          Rel := Copy(F, Length(IncludeTrailingPathDelimiter(Root)) + 1, MaxInt);
          Parts := Rel.Split([PathDelim]);
          Bad := False;
          for Part in Parts do
            if Hidden(Part) then
              Bad := True;
          if Bad then
          begin
            Skipped.Add(F + ' - hidden or unfinished');
            Continue;
          end;
          // the folders kept: the dropped folder's name and those below it
          Dir := Name;
          if Length(Parts) > 1 then
            Dir := Dir + '/' + string.Join('/', Parts, 0, Length(Parts) - 1);
          Add(F, Dir);
        end;
      end
      else if FileExists(Path) then
      begin
        if Hidden(ExtractFileName(Path)) then
          Skipped.Add(Path + ' - hidden or unfinished')
        else
          Add(Path, '');
      end
      else
        Skipped.Add(Path + ' - not found');
    end;
    Items.Sort(TComparer<TRouteItem>.Construct(
      function(const A, B: TRouteItem): Integer
      begin
        Result := KindRank(A.Kind) - KindRank(B.Kind);
        if Result = 0 then
          Result := CompareText(A.Dir, B.Dir);
        if Result = 0 then
          Result := CompareText(ExtractFileName(A.FileName), ExtractFileName(B.FileName));
      end));
    Result := Items.ToArray;
    ASkipped := Skipped.ToStringArray;
  finally
    Items.Free;
    Skipped.Free;
    Seen.Free;
  end;
end;

function RouteSize(const AItems: TRouteItems; const AKind: string): Int64;
var
  It: TRouteItem;
begin
  Result := 0;
  for It in AItems do
    if (AKind = '') or (It.Kind = AKind) then
      Inc(Result, It.Size);
end;

end.
