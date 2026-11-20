(* @abstract(Memory cards (and other removable drives) with books on them -
  Steam hardware takes SD cards; owner, 2026-11-20.)

  A card holds its books in folders at its top level:

  @unorderedList(
    @item(@code(Books) - EPUB files (EpubBuilder's input, EpubReader's
      library);)
    @item(@code(Audio) - audiobooks (EpubBuilder's input);)
    @item(@code(Transcribed) - the books EpubBuilder made (EpubReader's
      library too).))

  Only these folders are looked in, never the whole card (a card full of
  games would take long to search).

  Linux (SteamOS) mounts cards under /run/media/<user>/<card> (older
  SteamOS: /run/media/<device>); other systems: none yet. *)
unit uCards;

interface

const
  { A card's folder of EPUB files. }
  CARD_BOOKS = 'Books';
  { A card's folder of audiobooks. }
  CARD_AUDIO = 'Audio';
  { A card's folder of books EpubBuilder made. }
  CARD_TRANSCRIBED = 'Transcribed';

{ The mounted cards / removable drives (their top folders).
  @returns(the folders, none when there are none or the system is not
    looked at) }
function CardVolumes: TArray<string>;

{ The cards' folders named AName that exist (CARD_BOOKS, CARD_AUDIO,
  CARD_TRANSCRIBED).
  @param(AName  the folder's name at a card's top)
  @returns(the folders) }
function CardFolders(const AName: string): TArray<string>;

{ The card AFile is on.
  @param(AFile  a file's path)
  @returns(the card's top folder, '' when it is not on one) }
function CardOf(const AFile: string): string;

{ A card's name for lists: its folder's name.
  @param(AVolume  the card's top folder)
  @returns(the name) }
function CardName(const AVolume: string): string;

implementation

uses
  System.SysUtils, System.IOUtils;

function CardVolumes: TArray<string>;
{$IF Defined(LINUX) and not Defined(ANDROID)}
var
  User, D, Mine: string;
begin
  Result := nil;
  try
    User := GetEnvironmentVariable('USER');
    if User = '' then
      User := ExtractFileName(ExcludeTrailingPathDelimiter(TPath.GetHomePath));
    Mine := '/run/media/' + User;
    // SteamOS 3.5+: /run/media/<user>/<card>
    if (User <> '') and TDirectory.Exists(Mine) then
      for D in TDirectory.GetDirectories(Mine) do
        Result := Result + [D];
    // older: /run/media/<device> (not another user's folder)
    if TDirectory.Exists('/run/media') then
      for D in TDirectory.GetDirectories('/run/media') do
        if not SameText(D, Mine) and (TDirectory.Exists(TPath.Combine(D, CARD_BOOKS)) or
          TDirectory.Exists(TPath.Combine(D, CARD_AUDIO)) or TDirectory.Exists(TPath.Combine(D, CARD_TRANSCRIBED)))
        then
          Result := Result + [D];
  except
    // a card being taken out, a folder not readable: what was found
  end;
end;
{$ELSE}
begin
  Result := nil;
end;
{$ENDIF}

function CardFolders(const AName: string): TArray<string>;
var
  V, F: string;
begin
  Result := nil;
  for V in CardVolumes do
  begin
    F := TPath.Combine(V, AName);
    try
      if TDirectory.Exists(F) then
        Result := Result + [F];
    except
      // not readable: left out
    end;
  end;
end;

function CardOf(const AFile: string): string;
var
  V, P: string;
begin
  Result := '';
  P := ExpandFileName(AFile);
  for V in CardVolumes do
    if P.StartsWith(IncludeTrailingPathDelimiter(V)) then
      Exit(V);
end;

function CardName(const AVolume: string): string;
begin
  Result := ExtractFileName(ExcludeTrailingPathDelimiter(AVolume));
end;

end.
