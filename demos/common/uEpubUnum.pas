(* @abstract(The folders EpubBuilder and EpubReader share: one EpubUnum
  folder in Documents and one EpubUnum settings folder - and the move from
  the programs' own folders of before.)

  Owner, 2026-11-20: "the user data folder should be named epubunum rather
  than an app's name so things can be shared easier between the two";
  existing folders "Move them in".

  @unorderedList(
    @item(@bold(Documents/EpubUnum): Books, Audio, Transcribed, Covers,
      Queues - EpubBuilder's books in and out, EpubReader's books.)
    @item(@bold(The settings folder) (Windows %APPDATA%\EpubUnum, macOS
      ~/Library/Application Support/EpubUnum, Linux $XDG_CONFIG_HOME
      (else ~/.config)/EpubUnum): EpubBuilder.ini, EpubReader.json, the
      logs, the build history, the models (not in Steam builds), the
      converted MOBIs, the reader's cover cache.))

  @link(EpubUnumMove), called by each program first thing (before its log
  or settings are opened), moves what is there from before - once:
  @unorderedList(
    @item(Documents/EpubBuilder becomes Documents/EpubUnum (renamed; when
      both are there, what EpubUnum has not got is moved in);)
    @item(Documents/EpubReader/Books' files go into Documents/EpubUnum/
      Books (a name taken already: left where it is);)
    @item(the program's old settings folder: its files are COPIED (the old
      ones stay), its folders (models, Converted, covers) MOVED; in the
      copied settings, queue and history, the old folders' paths are
      changed to the new ones;)
    @item(what was done is written to EpubUnum-moved.txt in the settings
      folder, and returned for the log.)) *)
unit uEpubUnum;

interface

const
  { The shared folders' name. }
  EPUBUNUM_NAME = 'EpubUnum';
  { Books to build (EPUB, MOBI). }
  EU_BOOKS = 'Books';
  { Audio to build from. }
  EU_AUDIO = 'Audio';
  { Books built. }
  EU_TRANSCRIBED = 'Transcribed';
  { Pictures to use as covers. }
  EU_COVERS = 'Covers';
  { Saved build queues. }
  EU_QUEUES = 'Queues';

{ The platform's folder for settings (without EpubUnum). }
function ConfigBase: string;

{ The shared settings folder (made when missing). }
function EpubUnumConfigFolder: string;

{ Documents/EpubUnum. }
function EpubUnumDocsFolder: string;

{ Documents/EpubUnum/AName (EU_BOOKS, ...). }
function EpubUnumFolder(const AName: string): string;

{ Moves what the program AApp ('EpubBuilder', 'EpubReader') had in its own
  folders into the shared ones - once (see the unit).
  @returns(what was done, a line each; '' when nothing) }
function EpubUnumMove(const AApp: string): string;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Types;

function ConfigBase: string;
begin
  {$IF Defined(MSWINDOWS)}
  Result := TPath.GetHomePath;   // %APPDATA% (Roaming)
  {$ELSEIF Defined(MACOS)}
  Result := TPath.Combine(TPath.GetHomePath, 'Library/Application Support');
  {$ELSE}
  Result := GetEnvironmentVariable('XDG_CONFIG_HOME');
  if Result = '' then
    Result := TPath.Combine(TPath.GetHomePath, '.config');
  {$ENDIF}
end;

function EpubUnumConfigFolder: string;
begin
  Result := TPath.Combine(ConfigBase, EPUBUNUM_NAME);
  try
    ForceDirectories(Result);
  except
    // said by whoever writes there
  end;
end;

function EpubUnumDocsFolder: string;
begin
  Result := TPath.Combine(TPath.GetDocumentsPath, EPUBUNUM_NAME);
end;

function EpubUnumFolder(const AName: string): string;
begin
  Result := TPath.Combine(EpubUnumDocsFolder, AName);
end;

{ Moves AFrom's children into ATo (a name ATo has already stays in AFrom);
  AFrom is removed when empty. }
procedure MoveChildren(const AFrom, ATo: string; ALog: TStrings);
var
  E, Dest: string;
begin
  ForceDirectories(ATo);
  for E in TDirectory.GetFileSystemEntries(AFrom) do
  begin
    Dest := TPath.Combine(ATo, ExtractFileName(E));
    if FileExists(Dest) or TDirectory.Exists(Dest) then
    begin
      ALog.Add('Left where it is (the new folder has one of that name): ' + E);
      Continue;
    end;
    try
      if TDirectory.Exists(E) then
        TDirectory.Move(E, Dest)
      else
        TFile.Move(E, Dest);
      ALog.Add('Moved: ' + E + ' -> ' + Dest);
    except
      on Ex: Exception do
        ALog.Add('Not moved: ' + E + ' (' + Ex.Message + ')');
    end;
  end;
  try
    if Length(TDirectory.GetFileSystemEntries(AFrom)) = 0 then
      TDirectory.Delete(AFrom);
  except
    // left: harmless
  end;
end;

{ AText with every old folder path changed to its new one (both slash
  ways, and JSON's doubled backslashes). }
function NewPaths(const AText: string; const AOld, ANew: array of string): string;
var
  I: Integer;
  O, N: string;
begin
  Result := AText;
  for I := 0 to High(AOld) do
  begin
    O := ExcludeTrailingPathDelimiter(AOld[I]);
    N := ExcludeTrailingPathDelimiter(ANew[I]);
    Result := StringReplace(Result, O, N, [rfReplaceAll, rfIgnoreCase]);
    Result := StringReplace(Result, O.Replace('\', '\\'), N.Replace('\', '\\'), [rfReplaceAll, rfIgnoreCase]);
    Result := StringReplace(Result, O.Replace('\', '/'), N.Replace('\', '/'), [rfReplaceAll, rfIgnoreCase]);
  end;
end;

function EpubUnumMove(const AApp: string): string;
var
  Log: TStringList;
  Docs, OldDocs, OldReaderBooks, Config, OldConfig, Marker, Dest, Text: string;
  E: string;
  Olds, News: TArray<string>;
begin
  Result := '';
  Log := TStringList.Create;
  try
    try
      Docs := EpubUnumDocsFolder;
      Config := EpubUnumConfigFolder;
      Marker := TPath.Combine(Config, 'EpubUnum-moved-' + AApp + '.txt');
      // once per program
      if FileExists(Marker) then
        Exit;
      // Documents: EpubBuilder's folder becomes EpubUnum
      OldDocs := TPath.Combine(TPath.GetDocumentsPath, 'EpubBuilder');
      if TDirectory.Exists(OldDocs) then
        if not TDirectory.Exists(Docs) then
        begin
          TDirectory.Move(OldDocs, Docs);
          Log.Add('Moved: ' + OldDocs + ' -> ' + Docs);
        end
        else
          MoveChildren(OldDocs, Docs, Log);
      // EpubReader's books
      OldReaderBooks := TPath.Combine(TPath.Combine(TPath.GetDocumentsPath, 'EpubReader'), EU_BOOKS);
      if TDirectory.Exists(OldReaderBooks) then
      begin
        MoveChildren(OldReaderBooks, TPath.Combine(Docs, EU_BOOKS), Log);
        try
          if Length(TDirectory.GetFileSystemEntries(ExtractFileDir(OldReaderBooks))) = 0 then
            TDirectory.Delete(ExtractFileDir(OldReaderBooks));
        except
          // left: harmless
        end;
      end;
      // the program's settings folder: files copied, folders moved
      OldConfig := TPath.Combine(ConfigBase, AApp);
      Olds := [OldDocs, OldReaderBooks, OldConfig];
      News := [Docs, TPath.Combine(Docs, EU_BOOKS), Config];
      if TDirectory.Exists(OldConfig) then
      begin
        for E in TDirectory.GetFiles(OldConfig) do
        begin
          Dest := TPath.Combine(Config, ExtractFileName(E));
          if FileExists(Dest) then
            Continue;
          try
            // settings, queue, history: their paths changed; logs as they are
            if SameText(ExtractFileExt(E), '.ini') or SameText(ExtractFileExt(E), '.json') or
              SameText(ExtractFileExt(E), '.csv') then
            begin
              Text := TFile.ReadAllText(E, TEncoding.UTF8);
              TFile.WriteAllText(Dest, NewPaths(Text, Olds, News), TEncoding.UTF8);
              Log.Add('Copied (paths updated): ' + E + ' -> ' + Dest);
            end
            else
            begin
              TFile.Copy(E, Dest);
              Log.Add('Copied: ' + E + ' -> ' + Dest);
            end;
          except
            on Ex: Exception do
              Log.Add('Not copied: ' + E + ' (' + Ex.Message + ')');
          end;
        end;
        for E in TDirectory.GetDirectories(OldConfig) do
        begin
          Dest := TPath.Combine(Config, ExtractFileName(E));
          if TDirectory.Exists(Dest) then
            MoveChildren(E, Dest, Log)
          else
            try
              TDirectory.Move(E, Dest);
              Log.Add('Moved: ' + E + ' -> ' + Dest);
            except
              on Ex: Exception do
                Log.Add('Not moved: ' + E + ' (' + Ex.Message + ')');
            end;
        end;
      end;
      Log.Insert(0, Format('%s, %s: the shared epubunum folders (Documents: %s; settings: %s)', [AApp,
        FormatDateTime('yyyy-mm-dd hh:nn', Now), Docs, Config]));
      if Log.Count = 1 then
        Log.Add('Nothing to move.');
      Log.SaveToFile(Marker, TEncoding.UTF8);
      if Log.Count > 2 then
        Result := Log.Text
      else if (Log.Count = 2) and (Log[1] <> 'Nothing to move.') then
        Result := Log.Text;
    except
      on Ex: Exception do
        Result := 'The move to the shared epubunum folders stopped: ' + Ex.Message + sLineBreak + Log.Text;
    end;
  finally
    Log.Free;
  end;
end;

end.
