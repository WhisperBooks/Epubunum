{ @abstract(EpubBuilder's build history: the speed and accuracy of every
  finished build, per machine, model and device, and the time a new build
  can be expected to take.)

  Owner, 2026-11-18: "we should be building up a history of encoding speed
  + accuracy by model. This would then allow a better estimate of time for
  completion" - Night Watch with base.en on the M4 Mac mini first showed
  about an hour left, later 18 min. The estimate from the build's own rate
  alone has nothing to go on at the start and is thrown about by the first
  parts (short credits, the model warming up).

  Kept beside the settings as <settings>-history.csv (EpubBuilder-
  history.csv), one row per build that transcribed (not one that used a
  saved transcript), appended when it ends; a spreadsheet opens it. The
  machine is the computer's name (MachineText up to ' - '), so an update
  of the system keeps its history.

  The expectation for a new build (HistoryExpect), first that fits:
  1. this machine, model and device built before: the median speed of its
     last HISTORY_RECENT builds;
  2. the model was calibrated on the device: the calibration's speed
     corrected by how this machine's builds OF THE SAME MODEL compared
     with their own calibrations (zip 241: other models' ratios - turbo's
     3.41 against a stale calibration - promised base 480x where it ran
     120x) - and only builds whose calibration timed a stretch of the same
     length (zip 242: the calibration of two minutes, one run, is not the
     one of three 30 s runs; calibration_s);
  3. the calibration's speed times HISTORY_BOOK_RATIO (a 30 s calibration)
     or HISTORY_BOOK_RATIO_CONTINUOUS (a longer one).
  A whole book runs FASTER than the calibration's 30 s windows (each has
  its fixed costs; a book's silences go quickly): Night Watch, turbo, 1.48
  on the M4 with Metal, 1.36 with Core ML, 1.36 on the Steam Machine with
  Vulkan (2026-11-18) - the calibration alone promised 32 min for a book
  done in 24.
  else nothing. The window then blends it with the build's own rate (in
  seconds per second of audio), the build's own counting more as more
  audio is done (APriorAudio: the audio after which both count the same). }
unit uHistory;

interface

uses
  System.SysUtils, System.Classes;

const
  { The file's name beside the settings: ChangeFileExt(settings, this). }
  HISTORY_SUFFIX = '-history.csv';
  { Builds of one machine, model and device the expectation looks at (the
    latest). }
  HISTORY_RECENT = 5;
  { A whole book's speed over the calibration's, when no build here says
    better (the lowest measured, so the first estimate errs long). }
  HISTORY_BOOK_RATIO = 1.35;
  { The same for a calibration of a continuous stretch (uCalibration's
    method 2, zip 242): it times windows as a book has them, so a book
    runs at about its speed - to be measured on the machines (the 5090,
    2026-11-22, against the clearest 30 s: base 0.69 - 0.85, turbo 1.11). }
  HISTORY_BOOK_RATIO_CONTINUOUS = 1.0;
  { A calibration's stretch at most this long (s) is of the old kind (three
    runs of 30 s; rows without calibration_s are too). }
  HISTORY_SHORT_CALIBRATION = 45;
  { The table's columns (HistoryCells, HistoryTable). }
  HISTORY_HEADERS: array[0..14] of string = ('When', 'Book', 'Language', 'Machine', 'Model', 'Device', 'Audio',
    'Transcription', 'Speed', 'Calibration', 'Book / calibration', 'Align + write', 'Exact %', 'Matched %',
    'Whisper');
  { Their widths in the window, units. }
  HISTORY_WIDTHS: array[0..14] of Single = (120, 220, 70, 150, 120, 70, 70, 95, 65, 85, 120, 95, 65, 75, 70);
  { whisper.cpp's version of every build kept before the version was
    (all of them were this): a row without one. }
  HISTORY_WHISPER_FIRST = '1.9.5';
  { A build matched worse than this (%) is left out of the estimates: the
    wrong recording, or the wrong language (Ender in Exile tagged ru,
    2026-11-19: 62.7 % at 10.3x, against 99.6 % and 17 - 26x for the
    rest) - its speed says nothing of the next book's. }
  HISTORY_POOR_MATCH = 90;

type
  { One finished build. }
  TBuildHistoryRow = record
    { When it ended. }
    Made: TDateTime;
    { The computer's name (HistoryMachine). }
    Machine: string;
    { The model's file name (ggml-base.en.bin). }
    Model: string;
    { The device's name (MTL0, CUDA0, Vulkan1, CPU). }
    Device: string;
    { Length of the audio, s. }
    AudioSeconds: Double;
    { The transcription, loading the model included, s. }
    TranscribeSeconds: Double;
    { Aligning and writing after the transcription, s (0 = not measured). }
    AfterSeconds: Double;
    { The calibration's speed of this model on this device when it was
      built (x real time; 0 = not calibrated). }
    CalibrationSpeed: Double;
    { The length of the stretch that calibration timed, s (0 = not given:
      a row from before zip 242, a 30 s calibration). }
    CalibrationSeconds: Double;
    { Words heard exactly as the book has them, % of the book's words
      between the first and the last word read (front and back matter left
      out; rows from before 2026-11-19: % of all the book's words). }
    ExactPercent: Double;
    { Timed words matched to what was heard, % (the verdict's figure). }
    MatchedPercent: Double;
    { The book's title ('' in rows from before 2026-11-19). }
    Title: string;
    { The language transcribed ('' = not given, or an older row). }
    Language: string;
    { The output's file name, without its folder. }
    OutputName: string;
    { whisper.cpp's version that transcribed it, as 1.9.6 ('' = a row from
      before 2026-11-24: HISTORY_WHISPER_FIRST - see HistoryRowWhisper). }
    Whisper: string;
    { The model ran with its Core ML encoder: '1', '0', or '' = not known
      (a row from before 2026-11-24, or a machine without Core ML). The
      same model on the same device runs at another speed with it. }
    CoreML: string;
  end;

  { The rows of a history file, oldest first. }
  TBuildHistory = array of TBuildHistoryRow;

var
  { whisper.cpp's version loaded, as 1.9.6 - set once by the program when
    the library is loaded ('' = not known). A new version can be faster or
    slower on the same machine (owner, 2026-11-24: "everything should be
    split as timings may alter"), so HistoryExpect and HistorySummary
    look only at the builds this version made; the table shows all, with
    each row's version. }
  HistoryWhisper: string = '';
  { Whether the model of that file name uses its Core ML encoder now -
    set by the program (nil = not asked: every row counts). HistoryExpect
    leaves out the builds of the model that ran in the other state. }
  HistoryUsesCoreML: TFunc<string, Boolean> = nil;

{ whisper.cpp's version of ARow: its own, or HISTORY_WHISPER_FIRST when it
  has none.
  @returns(the version, as 1.9.5) }
function HistoryRowWhisper(const ARow: TBuildHistoryRow): string;

{ The computer's name in AMachineText (MachineText: 'name - system; ...').
  @returns(the text before ' - ', or all of it) }
function HistoryMachine(const AMachineText: string): string;

{ The transcription's speed of ARow (x real time).
  @returns(0 when it has no times) }
function HistorySpeed(const ARow: TBuildHistoryRow): Double;

{ Appends ARow to AFile, with the header line when the file is new.
  Never raises: a history that cannot be written costs no build.
  @returns('' or why it was not written) }
function HistoryAdd(const AFile: string; const ARow: TBuildHistoryRow): string;

{ The rows of AFile; lines that do not read are skipped.
  @returns(the rows, empty when there is no file) }
function HistoryLoad(const AFile: string): TBuildHistory;

{ ARow as the table's cells (HISTORY_HEADERS): the model without 'ggml-'
  and '.bin', times as h:mm:ss, speeds as 'N.Nx'.
  @returns(one string per column) }
function HistoryCells(const ARow: TBuildHistoryRow): TArray<string>;

{ The whole history as text, newest first: the header and a line per
  build, the cells separated by tabs (pastes into a spreadsheet or a
  message).
  @returns(the text) }
function HistoryTable(const AHistory: TBuildHistory): string;

{ What the history says, a line per model and device on AMachine (builds,
  median speed, exact and matched), then how many builds other machines
  made.
  @returns(the lines; 'No builds yet ...' when there are none) }
function HistorySummary(const AHistory: TBuildHistory; const AMachine: string): string;

{ The speed a build of AModel on ADevice can be expected to run at here
  (see the unit's text for the order).
  @param(AHistory  the history)
  @param(AMachine  the computer's name (HistoryMachine))
  @param(AModel  the model's file name)
  @param(ADevice  the device's name)
  @param(ACalibrationSpeed  the calibration's speed for the pair (0 = none))
  @param(ACalibrationSeconds  the length of that calibration's stretch, s
    (uCalibration.CalibrationSeconds; 0 = the old kind))
  @param(ASpeed  receives the expected speed, x real time)
  @param(AAfterShare  receives aligning + writing per second of audio, s
    (0 when no build here measured it))
  @param(APriorAudio  receives the seconds of audio after which the
    build's own rate counts as much as the expectation)
  @param(ASource  receives where the expectation comes from, for the log)
  @returns(False when there is nothing to go on) }
function HistoryExpect(const AHistory: TBuildHistory; const AMachine, AModel, ADevice: string;
  ACalibrationSpeed, ACalibrationSeconds: Double; out ASpeed, AAfterShare, APriorAudio: Double;
  out ASource: string): Boolean;

implementation

uses
  System.DateUtils, System.StrUtils, System.Generics.Collections, System.IOUtils;

const
  { The header line (the columns HistoryAdd writes). }
  HEADER = 'made,machine,model,device,audio_s,transcribe_s,after_s,speed,calibration_speed,exact_pct,matched_pct,' +
    'title,language,file,calibration_s,whisper,coreml';
  { The header before Core ML (zip 294, 2026-11-24): a file that starts
    with it gets HEADER on the next write. }
  WHISPER_HEADER = 'made,machine,model,device,audio_s,transcribe_s,after_s,speed,calibration_speed,exact_pct,' +
    'matched_pct,title,language,file,calibration_s,whisper';
  { The header before whisper.cpp's version (2026-11-24): a file that
    starts with it gets HEADER on the next write. }
  PREV_HEADER = 'made,machine,model,device,audio_s,transcribe_s,after_s,speed,calibration_speed,exact_pct,' +
    'matched_pct,title,language,file,calibration_s';
  { The header before the calibration's length (zip 242): a file that
    starts with it gets HEADER on the next write. }
  MID_HEADER = 'made,machine,model,device,audio_s,transcribe_s,after_s,speed,calibration_speed,exact_pct,' +
    'matched_pct,title,language,file';
  { The header before the book's columns (owner, 2026-11-19: "This lacks a
    title"): a file that starts with it gets the new one on the next
    write. }
  OLD_HEADER = 'made,machine,model,device,audio_s,transcribe_s,after_s,speed,calibration_speed,exact_pct,matched_pct';
  { Columns of a row at the least (older rows have no book columns). }
  COLUMNS = 11;
  { APriorAudio by source: earlier builds of the pair, the calibration
    corrected by builds, the calibration alone (s of audio). }
  PRIOR_BUILDS = 3600;
  PRIOR_CORRECTED = 1800;
  PRIOR_CALIBRATION = 1200;

var
  { '.' as the decimal separator, whatever the locale. }
  Inv: TFormatSettings;

function HistoryRowWhisper(const ARow: TBuildHistoryRow): string;
begin
  Result := ARow.Whisper;
  if Result = '' then
    Result := HISTORY_WHISPER_FIRST;
end;

{ ARow was made by the whisper.cpp loaded (HistoryWhisper), or no version
  is known and every row counts. }
function OfThisWhisper(const ARow: TBuildHistoryRow): Boolean;
begin
  Result := (HistoryWhisper = '') or (HistoryRowWhisper(ARow) = HistoryWhisper);
end;

function HistoryMachine(const AMachineText: string): string;
var
  P: Integer;
begin
  P := Pos(' - ', AMachineText);
  if P > 0 then
    Result := Trim(Copy(AMachineText, 1, P - 1))
  else
    Result := Trim(AMachineText);
end;

function HistorySpeed(const ARow: TBuildHistoryRow): Double;
begin
  if (ARow.AudioSeconds > 0) and (ARow.TranscribeSeconds > 0) then
    Result := ARow.AudioSeconds / ARow.TranscribeSeconds
  else
    Result := 0;
end;

{ AText as a CSV field: quoted, quotes doubled. }
function Quoted(const AText: string): string;
begin
  Result := '"' + StringReplace(AText, '"', '""', [rfReplaceAll]) + '"';
end;

{ AValue with ADigits decimals and '.'. }
function Num(AValue: Double; ADigits: Integer): string;
begin
  Result := FloatToStrF(AValue, ffFixed, 15, ADigits, Inv);
end;

{ AFile's first line, when it is one of the earlier headers, replaced by
  HEADER (the rows stay: the new columns are empty in them). }
procedure UpgradeHeader(const AFile: string);
var
  Text: string;
begin
  Text := TFile.ReadAllText(AFile, TEncoding.UTF8);
  if Text.StartsWith(WHISPER_HEADER + #13) or Text.StartsWith(WHISPER_HEADER + #10) then
    TFile.WriteAllText(AFile, HEADER + Copy(Text, Length(WHISPER_HEADER) + 1, MaxInt), TEncoding.UTF8)
  else if Text.StartsWith(PREV_HEADER + #13) or Text.StartsWith(PREV_HEADER + #10) then
    TFile.WriteAllText(AFile, HEADER + Copy(Text, Length(PREV_HEADER) + 1, MaxInt), TEncoding.UTF8)
  else if Text.StartsWith(OLD_HEADER + #13) or Text.StartsWith(OLD_HEADER + #10) then
    TFile.WriteAllText(AFile, HEADER + Copy(Text, Length(OLD_HEADER) + 1, MaxInt), TEncoding.UTF8)
  else if Text.StartsWith(MID_HEADER + #13) or Text.StartsWith(MID_HEADER + #10) then
    TFile.WriteAllText(AFile, HEADER + Copy(Text, Length(MID_HEADER) + 1, MaxInt), TEncoding.UTF8);
end;

function HistoryAdd(const AFile: string; const ARow: TBuildHistoryRow): string;
var
  Line: string;
  Bytes: TBytes;
  F: TFileStream;
  IsNew: Boolean;
begin
  Result := '';
  try
    Line := FormatDateTime('yyyy-mm-dd hh:nn:ss', ARow.Made) + ',' + Quoted(ARow.Machine) + ',' +
      Quoted(ARow.Model) + ',' + Quoted(ARow.Device) + ',' + Num(ARow.AudioSeconds, 1) + ',' +
      Num(ARow.TranscribeSeconds, 1) + ',' + Num(ARow.AfterSeconds, 1) + ',' + Num(HistorySpeed(ARow), 2) + ',' +
      Num(ARow.CalibrationSpeed, 2) + ',' + Num(ARow.ExactPercent, 2) + ',' + Num(ARow.MatchedPercent, 2) + ',' +
      Quoted(ARow.Title) + ',' + Quoted(ARow.Language) + ',' + Quoted(ARow.OutputName) + ',' +
      Num(ARow.CalibrationSeconds, 0) + ',' + Quoted(ARow.Whisper) + ',' + ARow.CoreML;
    IsNew := not FileExists(AFile);
    if not IsNew then
      UpgradeHeader(AFile);
    if IsNew then
    begin
      ForceDirectories(ExtractFilePath(AFile));
      Line := HEADER + sLineBreak + Line;
    end;
    Bytes := TEncoding.UTF8.GetBytes(Line + sLineBreak);
    if IsNew then
      F := TFileStream.Create(AFile, fmCreate)
    else
    begin
      F := TFileStream.Create(AFile, fmOpenReadWrite or fmShareDenyWrite);
      F.Seek(0, soEnd);
    end;
    try
      F.WriteBuffer(Bytes[0], Length(Bytes));
    finally
      F.Free;
    end;
  except
    on E: Exception do
      Result := E.Message;
  end;
end;

{ The fields of a CSV line (quoted fields may hold commas and doubled
  quotes). }
function SplitCsv(const ALine: string): TArray<string>;
var
  I, N: Integer;
  Field: string;
  InQuotes: Boolean;
begin
  Result := nil;
  N := 0;
  Field := '';
  InQuotes := False;
  I := 1;
  while I <= Length(ALine) do
  begin
    if InQuotes then
    begin
      if ALine[I] = '"' then
      begin
        if (I < Length(ALine)) and (ALine[I + 1] = '"') then
        begin
          Field := Field + '"';
          Inc(I);
        end
        else
          InQuotes := False;
      end
      else
        Field := Field + ALine[I];
    end
    else if ALine[I] = '"' then
      InQuotes := True
    else if ALine[I] = ',' then
    begin
      SetLength(Result, N + 1);
      Result[N] := Field;
      Inc(N);
      Field := '';
    end
    else
      Field := Field + ALine[I];
    Inc(I);
  end;
  SetLength(Result, N + 1);
  Result[N] := Field;
end;

{ 'yyyy-mm-dd hh:nn:ss' as a date and time.
  @returns(False when it does not read) }
function ReadStamp(const AText: string; out AValue: TDateTime): Boolean;
var
  Y, Mo, D, H, Mi, S: Integer;
begin
  Result := (Length(AText) = 19) and TryStrToInt(Copy(AText, 1, 4), Y) and TryStrToInt(Copy(AText, 6, 2), Mo) and
    TryStrToInt(Copy(AText, 9, 2), D) and TryStrToInt(Copy(AText, 12, 2), H) and
    TryStrToInt(Copy(AText, 15, 2), Mi) and TryStrToInt(Copy(AText, 18, 2), S) and
    TryEncodeDateTime(Y, Mo, D, H, Mi, S, 0, AValue);
end;

function HistoryLoad(const AFile: string): TBuildHistory;
var
  L: TStringList;
  I, N: Integer;
  F: TArray<string>;
  R: TBuildHistoryRow;
begin
  Result := nil;
  if not FileExists(AFile) then
    Exit;
  L := TStringList.Create;
  try
    try
      L.LoadFromFile(AFile, TEncoding.UTF8);
    except
      Exit;
    end;
    N := 0;
    SetLength(Result, L.Count);
    for I := 0 to L.Count - 1 do
    begin
      F := SplitCsv(L[I]);
      if Length(F) < COLUMNS then
        Continue;
      if not ReadStamp(F[0], R.Made) then
        Continue;   // the header, or a line that does not read
      R.Machine := F[1];
      R.Model := F[2];
      R.Device := F[3];
      R.AudioSeconds := StrToFloatDef(F[4], 0, Inv);
      R.TranscribeSeconds := StrToFloatDef(F[5], 0, Inv);
      R.AfterSeconds := StrToFloatDef(F[6], 0, Inv);
      // F[7] is the speed, written for people: worked out again from 4 / 5
      R.CalibrationSpeed := StrToFloatDef(F[8], 0, Inv);
      R.ExactPercent := StrToFloatDef(F[9], 0, Inv);
      R.MatchedPercent := StrToFloatDef(F[10], 0, Inv);
      R.Title := '';
      R.Language := '';
      R.OutputName := '';
      if Length(F) > 13 then
      begin
        R.Title := F[11];
        R.Language := F[12];
        R.OutputName := F[13];
      end;
      R.CalibrationSeconds := 0;
      if Length(F) > 14 then
        R.CalibrationSeconds := StrToFloatDef(F[14], 0, Inv);
      R.Whisper := '';
      if Length(F) > 15 then
        R.Whisper := Trim(F[15]);
      R.CoreML := '';
      if (Length(F) > 16) and ((Trim(F[16]) = '1') or (Trim(F[16]) = '0')) then
        R.CoreML := Trim(F[16]);
      Result[N] := R;
      Inc(N);
    end;
    SetLength(Result, N);
  finally
    L.Free;
  end;
end;

{ The median of AValues (0 when there are none). }
function Median(AValues: TArray<Double>): Double;
var
  N: Integer;
begin
  N := Length(AValues);
  if N = 0 then
    Exit(0);
  TArray.Sort<Double>(AValues);
  if Odd(N) then
    Result := AValues[N div 2]
  else
    Result := (AValues[N div 2 - 1] + AValues[N div 2]) / 2;
end;

{ AValue added to the end of AList. }
procedure Push(var AList: TArray<Double>; AValue: Double);
begin
  SetLength(AList, Length(AList) + 1);
  AList[High(AList)] := AValue;
end;

{ ASeconds as h:mm:ss. }
function Hms(ASeconds: Double): string;
var
  S: Int64;
begin
  S := Round(ASeconds);
  Result := Format('%d:%.2d:%.2d', [S div 3600, (S div 60) mod 60, S mod 60]);
end;

{ The model's file name without 'ggml-' and '.bin'. }
function ShortModel(const AModel: string): string;
begin
  Result := AModel;
  if SameText(Copy(Result, 1, 5), 'ggml-') then
    Delete(Result, 1, 5);
  if SameText(ExtractFileExt(Result), '.bin') then
    Result := ChangeFileExt(Result, '');
end;

function HistoryCells(const ARow: TBuildHistoryRow): TArray<string>;
var
  Speed: Double;
begin
  Speed := HistorySpeed(ARow);
  SetLength(Result, Length(HISTORY_HEADERS));
  Result[0] := FormatDateTime('yyyy-mm-dd hh:nn', ARow.Made);
  // the title, else the output's name; rows from before have neither
  Result[1] := ARow.Title;
  if Result[1] = '' then
    Result[1] := ChangeFileExt(ARow.OutputName, '');
  Result[2] := ARow.Language;
  Result[3] := ARow.Machine;
  Result[4] := ShortModel(ARow.Model);
  Result[5] := ARow.Device;
  if ARow.CoreML = '1' then
    Result[5] := Result[5] + ' + Core ML';
  Result[6] := Hms(ARow.AudioSeconds);
  Result[7] := Hms(ARow.TranscribeSeconds);
  Result[8] := Format('%.1fx', [Speed]);
  Result[9] := '';
  Result[10] := '';
  if ARow.CalibrationSpeed > 0 then
  begin
    Result[9] := Format('%.1fx', [ARow.CalibrationSpeed]);
    Result[10] := Format('%.2f', [Speed / ARow.CalibrationSpeed]);
  end;
  Result[11] := '';
  if ARow.AfterSeconds > 0 then
    Result[11] := Hms(ARow.AfterSeconds);
  Result[12] := Format('%.1f', [ARow.ExactPercent]);
  Result[13] := Format('%.1f', [ARow.MatchedPercent]);
  Result[14] := HistoryRowWhisper(ARow);
end;

function HistoryTable(const AHistory: TBuildHistory): string;
var
  SB: TStringBuilder;
  I: Integer;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append(string.Join(#9, HISTORY_HEADERS)).Append(sLineBreak);
    for I := High(AHistory) downto 0 do
      SB.Append(string.Join(#9, HistoryCells(AHistory[I]))).Append(sLineBreak);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function HistorySummary(const AHistory: TBuildHistory; const AMachine: string): string;
var
  Keys: TStringList;
  I, K, Others, Older: Integer;
  Speeds, Exact, Matched: TArray<Double>;
  Key: string;
begin
  if Length(AHistory) = 0 then
    Exit('No builds yet: every build that transcribes is added when it ends.');
  Result := '';
  Others := 0;
  Older := 0;
  Keys := TStringList.Create;
  try
    Keys.CaseSensitive := False;
    Keys.Duplicates := dupIgnore;
    Keys.Sorted := True;
    for I := 0 to High(AHistory) do
      if not OfThisWhisper(AHistory[I]) then
        Inc(Older)
      else if SameText(AHistory[I].Machine, AMachine) then
        Keys.Add(ShortModel(AHistory[I].Model) + ' on ' + AHistory[I].Device +
          IfThen(AHistory[I].CoreML = '1', ' + Core ML', ''))
      else
        Inc(Others);
    for K := 0 to Keys.Count - 1 do
    begin
      Speeds := nil;
      Exact := nil;
      Matched := nil;
      for I := 0 to High(AHistory) do
      begin
        Key := ShortModel(AHistory[I].Model) + ' on ' + AHistory[I].Device +
          IfThen(AHistory[I].CoreML = '1', ' + Core ML', '');
        if OfThisWhisper(AHistory[I]) and SameText(AHistory[I].Machine, AMachine) and SameText(Key, Keys[K]) then
        begin
          Push(Speeds, HistorySpeed(AHistory[I]));
          Push(Exact, AHistory[I].ExactPercent);
          Push(Matched, AHistory[I].MatchedPercent);
        end;
      end;
      Result := Result + Format('%s: %d build(s), median %.1fx real time, exact %.1f %%, matched %.1f %%',
        [Keys[K], Length(Speeds), Median(Speeds), Median(Exact), Median(Matched)]) + sLineBreak;
    end;
  finally
    Keys.Free;
  end;
  if Result = '' then
    Result := Format('No builds on %s yet.', [AMachine]) + sLineBreak
  else
    Result := Format('On %s:', [AMachine]) + sLineBreak + Result;
  if Others > 0 then
    Result := Result + Format('Other machines: %d build(s) (in the table).', [Others]) + sLineBreak;
  if Older > 0 then
    Result := Result + Format('Other versions of whisper.cpp than %s: %d build(s) (in the table; not counted ' +
      'above, nor in the time estimates).', [HistoryWhisper, Older]) + sLineBreak;
  Result := TrimRight(Result);
end;

function HistoryExpect(const AHistory: TBuildHistory; const AMachine, AModel, ADevice: string;
  ACalibrationSpeed, ACalibrationSeconds: Double; out ASpeed, AAfterShare, APriorAudio: Double;
  out ASource: string): Boolean;
var
  I: Integer;
  Same, Ratios, After: TArray<Double>;
  Here, WithCoreML, Encoder: Boolean;
  Ratio: Double;

  { A calibration of a continuous stretch (method 2), not three of 30 s. }
  function Long(ASeconds: Double): Boolean;
  begin
    Result := ASeconds > HISTORY_SHORT_CALIBRATION;
  end;

begin
  ASpeed := 0;
  AAfterShare := 0;
  APriorAudio := 0;
  ASource := '';
  Same := nil;
  Ratios := nil;
  After := nil;
  // the model's encoder now: its builds in the other state ran at
  // another speed
  WithCoreML := Assigned(HistoryUsesCoreML) and HistoryUsesCoreML(AModel);
  // newest first: the latest builds count (a new driver, a new
  // whisper.cpp)
  for I := High(AHistory) downto 0 do
  begin
    Here := SameText(AHistory[I].Machine, AMachine);
    if not Here or (HistorySpeed(AHistory[I]) <= 0) then
      Continue;
    // another version of whisper.cpp ran at its own speeds
    if not OfThisWhisper(AHistory[I]) then
      Continue;
    // a poor build (wrong recording, wrong language) is no guide
    if (AHistory[I].MatchedPercent > 0) and (AHistory[I].MatchedPercent < HISTORY_POOR_MATCH) then
      Continue;
    // a row that does not say (an older one) counts in either state
    Encoder := not Assigned(HistoryUsesCoreML) or (AHistory[I].CoreML = '') or
      ((AHistory[I].CoreML = '1') = WithCoreML);
    if Encoder and SameText(AHistory[I].Model, AModel) and SameText(AHistory[I].Device, ADevice) and
      (Length(Same) < HISTORY_RECENT) then
      Push(Same, HistorySpeed(AHistory[I]));
    // the ratio of the same model only (owner, 2026-11-22: base's
    // benchmark expected at 480x from turbo's 3.41 - each model's
    // fallback retries and stale calibrations differ)
    if Encoder and SameText(AHistory[I].Model, AModel) and (AHistory[I].CalibrationSpeed > 0) and
      (Long(AHistory[I].CalibrationSeconds) = Long(ACalibrationSeconds)) and
      (Length(Ratios) < 2 * HISTORY_RECENT) then
      Push(Ratios, HistorySpeed(AHistory[I]) / AHistory[I].CalibrationSpeed);
    if (AHistory[I].AfterSeconds > 0) and (Length(After) < 2 * HISTORY_RECENT) then
      Push(After, AHistory[I].AfterSeconds / AHistory[I].AudioSeconds);
  end;
  AAfterShare := Median(After);
  if Length(Same) > 0 then
  begin
    ASpeed := Median(Same);
    APriorAudio := PRIOR_BUILDS;
    ASource := Format('%d earlier build(s) of %s on %s here', [Length(Same), AModel, ADevice]);
  end
  else if (ACalibrationSpeed > 0) and (Length(Ratios) > 0) then
  begin
    ASpeed := ACalibrationSpeed * Median(Ratios);
    APriorAudio := PRIOR_CORRECTED;
    ASource := Format('the calibration (%.1fx) times %.2f - how %d earlier build(s) of %s here compared with ' +
      'their calibration', [ACalibrationSpeed, Median(Ratios), Length(Ratios), AModel], Inv);
  end
  else if ACalibrationSpeed > 0 then
  begin
    if Long(ACalibrationSeconds) then
      Ratio := HISTORY_BOOK_RATIO_CONTINUOUS
    else
      Ratio := HISTORY_BOOK_RATIO;
    ASpeed := ACalibrationSpeed * Ratio;
    APriorAudio := PRIOR_CALIBRATION;
    ASource := Format('the calibration (%.1fx) times %.2f - a whole book usually runs about that fast against ' +
      'it (no finished build here yet to say better)', [ACalibrationSpeed, Ratio], Inv);
  end;
  Result := ASpeed > 0;
end;

initialization
  Inv := TFormatSettings.Invariant;

end.
