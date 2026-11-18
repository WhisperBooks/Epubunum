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
     corrected by how this machine's builds compared with their own
     calibrations (a whole book runs slower than the calibration's 30 s:
     parts, silences, bad stretches tried again);
  3. the calibration's speed alone;
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
  { The table's columns (HistoryCells, HistoryTable). }
  HISTORY_HEADERS: array[0..11] of string = ('When', 'Machine', 'Model', 'Device', 'Audio', 'Transcription',
    'Speed', 'Calibration', 'Book / calibration', 'Align + write', 'Exact %', 'Matched %');
  { Their widths in the window, units. }
  HISTORY_WIDTHS: array[0..11] of Single = (120, 150, 120, 70, 70, 95, 65, 85, 120, 95, 65, 75);

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
    { Words heard exactly as the book has them, % of the book's words. }
    ExactPercent: Double;
    { Timed words matched to what was heard, % (the verdict's figure). }
    MatchedPercent: Double;
  end;

  { The rows of a history file, oldest first. }
  TBuildHistory = array of TBuildHistoryRow;

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
  @param(ASpeed  receives the expected speed, x real time)
  @param(AAfterShare  receives aligning + writing per second of audio, s
    (0 when no build here measured it))
  @param(APriorAudio  receives the seconds of audio after which the
    build's own rate counts as much as the expectation)
  @param(ASource  receives where the expectation comes from, for the log)
  @returns(False when there is nothing to go on) }
function HistoryExpect(const AHistory: TBuildHistory; const AMachine, AModel, ADevice: string;
  ACalibrationSpeed: Double; out ASpeed, AAfterShare, APriorAudio: Double; out ASource: string): Boolean;

implementation

uses
  System.DateUtils, System.Generics.Collections;

const
  { The header line (the columns HistoryAdd writes). }
  HEADER = 'made,machine,model,device,audio_s,transcribe_s,after_s,speed,calibration_speed,exact_pct,matched_pct';
  { Columns of a row. }
  COLUMNS = 11;
  { APriorAudio by source: earlier builds of the pair, the calibration
    corrected by builds, the calibration alone (s of audio). }
  PRIOR_BUILDS = 3600;
  PRIOR_CORRECTED = 1800;
  PRIOR_CALIBRATION = 1200;

var
  { '.' as the decimal separator, whatever the locale. }
  Inv: TFormatSettings;

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
      Num(ARow.CalibrationSpeed, 2) + ',' + Num(ARow.ExactPercent, 2) + ',' + Num(ARow.MatchedPercent, 2);
    IsNew := not FileExists(AFile);
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
  Result[1] := ARow.Machine;
  Result[2] := ShortModel(ARow.Model);
  Result[3] := ARow.Device;
  Result[4] := Hms(ARow.AudioSeconds);
  Result[5] := Hms(ARow.TranscribeSeconds);
  Result[6] := Format('%.1fx', [Speed]);
  Result[7] := '';
  Result[8] := '';
  if ARow.CalibrationSpeed > 0 then
  begin
    Result[7] := Format('%.1fx', [ARow.CalibrationSpeed]);
    Result[8] := Format('%.2f', [Speed / ARow.CalibrationSpeed]);
  end;
  Result[9] := '';
  if ARow.AfterSeconds > 0 then
    Result[9] := Hms(ARow.AfterSeconds);
  Result[10] := Format('%.1f', [ARow.ExactPercent]);
  Result[11] := Format('%.1f', [ARow.MatchedPercent]);
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
  I, K, Others: Integer;
  Speeds, Exact, Matched: TArray<Double>;
  Key: string;
begin
  if Length(AHistory) = 0 then
    Exit('No builds yet: every build that transcribes is added when it ends.');
  Result := '';
  Others := 0;
  Keys := TStringList.Create;
  try
    Keys.CaseSensitive := False;
    Keys.Duplicates := dupIgnore;
    Keys.Sorted := True;
    for I := 0 to High(AHistory) do
      if SameText(AHistory[I].Machine, AMachine) then
        Keys.Add(ShortModel(AHistory[I].Model) + ' on ' + AHistory[I].Device)
      else
        Inc(Others);
    for K := 0 to Keys.Count - 1 do
    begin
      Speeds := nil;
      Exact := nil;
      Matched := nil;
      for I := 0 to High(AHistory) do
      begin
        Key := ShortModel(AHistory[I].Model) + ' on ' + AHistory[I].Device;
        if SameText(AHistory[I].Machine, AMachine) and SameText(Key, Keys[K]) then
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
  Result := TrimRight(Result);
end;

function HistoryExpect(const AHistory: TBuildHistory; const AMachine, AModel, ADevice: string;
  ACalibrationSpeed: Double; out ASpeed, AAfterShare, APriorAudio: Double; out ASource: string): Boolean;
var
  I: Integer;
  Same, Ratios, After: TArray<Double>;
  Here: Boolean;
begin
  ASpeed := 0;
  AAfterShare := 0;
  APriorAudio := 0;
  ASource := '';
  Same := nil;
  Ratios := nil;
  After := nil;
  // newest first: the latest builds count (a new driver, a new
  // whisper.cpp)
  for I := High(AHistory) downto 0 do
  begin
    Here := SameText(AHistory[I].Machine, AMachine);
    if not Here or (HistorySpeed(AHistory[I]) <= 0) then
      Continue;
    if SameText(AHistory[I].Model, AModel) and SameText(AHistory[I].Device, ADevice) and
      (Length(Same) < HISTORY_RECENT) then
      Push(Same, HistorySpeed(AHistory[I]));
    if (AHistory[I].CalibrationSpeed > 0) and (Length(Ratios) < 2 * HISTORY_RECENT) then
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
    ASource := Format('the calibration (%.1fx) times %.2f - how %d earlier build(s) here compared with their ' +
      'calibration', [ACalibrationSpeed, Median(Ratios), Length(Ratios)], Inv);
  end
  else if ACalibrationSpeed > 0 then
  begin
    ASpeed := ACalibrationSpeed;
    APriorAudio := PRIOR_CALIBRATION;
    ASource := Format('the calibration (%.1fx; no finished build here yet to correct it - a whole book usually ' +
      'runs slower)', [ACalibrationSpeed], Inv);
  end;
  Result := ASpeed > 0;
end;

initialization
  Inv := TFormatSettings.Invariant;

end.
