{ @abstract(EpubBuilder's calibration: which device transcribes fastest on
  this machine, model by model, measured once and kept in the settings.)

  whisper.cpp left alone takes the first GPU in ggml's list (CUDA before
  HIP before Vulkan), which is often not the fastest: the owner's RTX 5090
  laptop built Night Watch with large-v3 in 39:20 on CUDA0 (whisper.cpp's
  own choice) and in 29:16 on Vulkan; on a GTX 1650 Vulkan beat CUDA with
  base.en, and large-v3 does not fit its 4 GB at all. So (owner,
  2026-11-17): a calibration - TWhisperBenchmark on every device, three
  timed runs of 30 s of speech each (the stretch chosen by
  WhisperFindSpeech, away from both ends of the recording), with the
  settings of a build (DTW word times, the book prompt, each window on its
  own) - and the fastest device made the model's device. Asked for once at
  start-up ("Do not show this again" stops that), again from Tools >
  Re-calibrate when the graphics card changes.

  Kept in EpubBuilder.ini: [Calibration] (Done, DontAsk, Made, Devices -
  the device list it was made with, Audio) and a section per model,
  [Calibration <model file name>] (Made, Best, BestSpeed, and one key per
  device: the speed, or 'failed: ...'). A pair that ends the program (a
  GPU runtime that aborts) is caught by a marker file written before each
  pair: at the next start it is recorded as failed and skipped by the
  calibration offered then (Re-calibrate tries it again). }
unit uCalibration;

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.IniFiles,
  FFmpeg.API,
  Whisper.Types, Whisper.API, Whisper.Audio, Whisper.Core, Whisper.Words, Whisper.AudioSet;

const
  { The settings' section of the calibration as a whole. }
  CAL_SECTION = 'Calibration';
  { Section of the pairs that ended the program (key: device + '@' +
    model file name, value: when). }
  CAL_CRASH_SECTION = 'Calibration crashes';
  { Timed runs per pair (the median counts). }
  CALIBRATION_RUNS = 3;
  { The calibration's recording, looked for in a media folder beside the
    program and the folders above it (a LibriVox recording: speech with
    its own pauses and noise, as a book's). }
  CALIBRATION_AUDIO = 'aladdin.m4a';
  { Folders above the program's searched for media/CALIBRATION_AUDIO (the
    repository's root from demos/EpubBuilder/<platform>/<config>). }
  CALIBRATION_AUDIO_LEVELS = 5;

type
  { Times every model on every device on its own thread (one
    TWhisperBenchmark, the stretch chosen once for all pairs). Messages
    reach the window through TThread.Queue, as the build's. }
  TCalibrationThread = class(TThread)
  private
    { The models (ggml-*.bin), in the order timed. }
    FModels: TStringList;
    { The recording. }
    FAudioFile: string;
    { The language Whisper is told ('' = detected). }
    FLanguage: string;
    { The prompt of every window (the build's). }
    FPrompt: string;
    { The devices. }
    FDevices: TWhisperDeviceArray;
    { Pairs not timed (model file name + #9 + device name): they ended the
      program in an earlier calibration. }
    FSkip: TStringList;
    { Written before each pair, deleted after it. }
    FMarkerFile: string;
    { The benchmark while it runs (for Cancel; guarded by TMonitor on Self). }
    FBench: TWhisperBenchmark;
    { Backing field of @link(Results). }
    FResults: TWhisperBenchmarkArray;
    { Backing field of @link(Completed). }
    FCompleted: Boolean;
    { Receives the messages (on the main thread). }
    FOnLog: TProc<string>;
    { Receives the progress, 0 .. 100 (on the main thread). }
    FOnProgress: TProc<Double>;
    { Receives what is being done now (on the main thread). }
    FOnStatus: TProc<string>;
    { Sends AText to OnLog. }
    procedure Log(const AText: string);
    { Sends APercent to OnProgress. }
    procedure Progress(APercent: Double);
    { Sends AText to OnStatus. }
    procedure Status(const AText: string);
  protected
    { The calibration. }
    procedure Execute; override;
  public
    { A calibration of AModels on ADevices with AAudioFile (not started:
      call Start). ASkip: pairs to leave out (model file name + #9 +
      device name); AMarkerFile: the crash marker. }
    constructor Create(AModels: TStrings; const AAudioFile, ALanguage, APrompt, AMarkerFile: string;
      const ADevices: TWhisperDeviceArray; ASkip: TStrings);
    { Frees the lists. }
    destructor Destroy; override;
    { Stops after the run in progress. }
    procedure Cancel;
    { Receives the messages. }
    property OnLog: TProc<string> read FOnLog write FOnLog;
    { Receives the progress. }
    property OnProgress: TProc<Double> read FOnProgress write FOnProgress;
    { Receives what is being done now. }
    property OnStatus: TProc<string> read FOnStatus write FOnStatus;
    { One result per pair timed or skipped (complete once it has ended). }
    property Results: TWhisperBenchmarkArray read FResults;
    { True when every pair was timed (not cancelled, no error). }
    property Completed: Boolean read FCompleted;
    { The recording timed. }
    property AudioFile: string read FAudioFile;
  end;

{ FFmpeg: from PATH / the program's folder, else from whisper.cpp's
  library folder (TWhisper's redistributable_bin).
  @returns(the library; the caller frees it)
  @raises(EFFmpegError when neither place has it) }
function OpenBuilderFFmpeg: TFFmpegLibrary;

{ The device a build with device name AName uses: the named one, or for
  '' whisper.cpp's own choice (the first GPU in ggml's list, the CPU when
  there is none).
  @returns(False when whisper.cpp is not loaded or there is no such device) }
function BuilderFindDevice(const AName: string; out ADevice: TWhisperDevice): Boolean;

{ The device of AName in words, for the logs: 'Vulkan0 - NVIDIA ...
  (GPU, Vulkan, 22.0 of 24.0 GB free)', with '' said as 'the default
  device = CUDA0 - ... (whisper.cpp takes the first GPU in its list)'.
  @returns(the text) }
function BuilderDeviceText(const AName: string): string;

{ The device list as the calibration remembers it: names and
  descriptions (not the free memory, which changes).
  @returns(the key) }
function CalibrationDevicesKey(const ADevices: TWhisperDeviceArray): string;

{ Index of the result to choose for AModelFile: the fastest that
  succeeded and heard at least SUSPECT_SHARE of the words the best-heard
  run did (a device that computes wrongly can be fast and hear nothing).
  @returns(-1 when none qualifies) }
function CalibrationBestIndex(const AResults: TWhisperBenchmarkArray; const AModelFile: string): Integer;

{ True when AResult heard much less than the best-heard result of its
  model (CalibrationBestIndex leaves it out).
  @returns(the answer) }
function CalibrationSuspect(const AResults: TWhisperBenchmarkArray; AIndex: Integer): Boolean;

{ Writes AResults into AIniFile: a section per model (its earlier one
  replaced), and [Calibration] Done, Made, Devices (ADevicesKey), Audio.
  Pairs of AResults that succeeded leave the crash list. }
procedure CalibrationSave(const AIniFile: string; const AResults: TWhisperBenchmarkArray;
  const ADevicesKey, AAudioFile: string);

{ The device AModelFile was fastest on (by file name), and its speed.
  @returns(False when the model was not calibrated) }
function CalibrationBest(const AIniFile, AModelFile: string; out ADevice: string; out ASpeed: Double): Boolean;

{ Why AModelFile failed on ADevice in the calibration ('' when it did not
  or was not timed there).
  @returns(the reason) }
function CalibrationFailure(const AIniFile, AModelFile, ADevice: string): string;

{ AModelFile's calibration in one line: 'Vulkan0 128.8x, CUDA0 122.0x,
  CPU 3.1x, ... (2026-11-17 10:12)' ('' when not calibrated).
  @returns(the line) }
function CalibrationSummary(const AIniFile, AModelFile: string): string;

{ Reads [Calibration]: Done, DontAsk, the device key and when. }
procedure CalibrationState(const AIniFile: string; out ADone, ADontAsk: Boolean; out ADevicesKey, AMade: string);

{ Sets [Calibration] DontAsk. }
procedure CalibrationSetDontAsk(const AIniFile: string; AValue: Boolean);

{ The pairs that ended the program (model file name + #9 + device name).
  @returns(a list the caller frees) }
function CalibrationCrashes(const AIniFile: string): TStringList;

{ Forgets the pairs that ended the program (Re-calibrate tries them). }
procedure CalibrationClearCrashes(const AIniFile: string);

{ After a run that ended during a calibration: the marker's pair is
  recorded as failed and as a crash, the marker deleted.
  @returns(a line for the log; '' when there was no marker) }
function CalibrationCheckMarker(const AMarkerFile, AIniFile: string): string;

{ The calibration's recording: ASaved when it exists, else (macOS) the
  bundle's Contents/Resources/media/CALIBRATION_AUDIO, else
  media/CALIBRATION_AUDIO beside the program or in a folder above it.
  @returns('' when there is none) }
function FindCalibrationAudio(const ASaved: string): string;

{ The start-up question: why to calibrate, Start calibration / Cancel and
  "Do not show this again". Modal.
  @param(AOwner  the window it is centred on)
  @param(AText  the explanation)
  @param(ADontAsk  receives the check box)
  @returns(True for Start calibration) }
function AskCalibration(AOwner: TComponent; const AText: string; out ADontAsk: Boolean): Boolean;

implementation

uses
  {$IFDEF POSIX}
  // System.SysUtils.DeleteFile's inline body expands only with it (H2443)
  Posix.Unistd,
  {$ENDIF}
  System.Types, System.Math, System.StrUtils, System.IOUtils,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Layouts,
  uDebugLog;

const
  { A result that heard fewer words than this share of the best-heard one
    of its model is not chosen. }
  SUSPECT_SHARE = 0.6;
  { Prefix of a failed pair's value in the settings. }
  FAILED_PREFIX = 'failed: ';
  { Why a pair was not timed. }
  SKIPPED_TEXT = 'not timed: EpubBuilder ended while it was being timed in an earlier calibration ' +
    '(Tools > Re-calibrate tries it again)';

{ The settings' section of AModelFile. }
function ModelSection(const AModelFile: string): string;
begin
  Result := CAL_SECTION + ' ' + ExtractFileName(AModelFile);
end;

{ The words of AText (runs between spaces). }
function WordCount(const AText: string): Integer;
var
  I: Integer;
  InWord: Boolean;
begin
  Result := 0;
  InWord := False;
  for I := 1 to Length(AText) do
    if AText[I] <= ' ' then
      InWord := False
    else if not InWord then
    begin
      InWord := True;
      Inc(Result);
    end;
end;

{ ASeconds as h:mm:ss. }
function Hms(ASeconds: Double): string;
var
  S: Int64;
begin
  S := Round(ASeconds);
  Result := Format('%d:%.2d:%.2d', [S div 3600, (S div 60) mod 60, S mod 60]);
end;

{ AText on one line (line breaks as ' / '). }
function OneLine(const AText: string): string;
begin
  Result := StringReplace(StringReplace(Trim(AText), #13#10, ' / ', [rfReplaceAll]), #10, ' / ', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' / ', [rfReplaceAll]);
end;

function OpenBuilderFFmpeg: TFFmpegLibrary;
var
  First: string;
begin
  DebugLog('FFmpeg: loading (the program''s folder / the system)');
  try
    Result := TFFmpegLibrary.Create('');
  except
    on E: EFFmpegError do
    begin
      First := E.Message;
      DebugLog('FFmpeg: ' + First + ' - trying the whisper.cpp folder');
      if not TWhisperLib.IsLoaded then
        raise;
      try
        Result := TFFmpegLibrary.Create(TWhisperLib.Instance.LibraryFolder);
      except
        on E2: EFFmpegError do
          raise EFFmpegError.Create(First + sLineBreak + E2.Message);
      end;
    end;
  end;
end;

function BuilderFindDevice(const AName: string; out ADevice: TWhisperDevice): Boolean;
var
  Lib: TWhisperLib;
  CP: TWhisperContextParams;
  Devs: TWhisperDeviceArray;
  I: Integer;
begin
  Result := False;
  ADevice := Default(TWhisperDevice);
  if not TWhisperLib.IsLoaded then
    Exit;
  Lib := TWhisperLib.Instance;
  if AName <> '' then
    Exit(Lib.FindDevice(AName, ADevice));
  // whisper.cpp's choice: with use_gpu, the GPU / IGPU at gpu_device (0:
  // the first in ggml's registry - CUDA before HIP before Vulkan)
  CP := Lib.DefaultContextParams;
  Devs := Lib.SelectableDevices;
  if CP.use_gpu then
    for I := 0 to High(Devs) do
      if Devs[I].GpuIndex = CP.gpu_device then
      begin
        ADevice := Devs[I];
        Exit(True);
      end;
  for I := 0 to High(Devs) do
    if Devs[I].DeviceType = wdtCPU then
    begin
      ADevice := Devs[I];
      Exit(True);
    end;
end;

function BuilderDeviceText(const AName: string): string;
var
  D: TWhisperDevice;
begin
  if not BuilderFindDevice(AName, D) then
    Result := IfThen(AName = '', 'the default device', AName) + ' (not in whisper.cpp''s device list)'
  else if AName = '' then
    Result := 'the default device = ' + WhisperDeviceText(D) + ' (whisper.cpp takes the first GPU in its list)'
  else
    Result := WhisperDeviceText(D);
end;

function CalibrationDevicesKey(const ADevices: TWhisperDeviceArray): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(ADevices) do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + ADevices[I].Name + ' = ' + ADevices[I].Description;
  end;
end;

{ The most words any successful result of AModelFile heard. }
function MostWords(const AResults: TWhisperBenchmarkArray; const AModelFile: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(AResults) do
    if AResults[I].Ok and SameFileName(AResults[I].ModelFile, AModelFile) then
      Result := Max(Result, WordCount(AResults[I].Text));
end;

function CalibrationSuspect(const AResults: TWhisperBenchmarkArray; AIndex: Integer): Boolean;
begin
  Result := AResults[AIndex].Ok and (WordCount(AResults[AIndex].Text) <
    SUSPECT_SHARE * MostWords(AResults, AResults[AIndex].ModelFile));
end;

function CalibrationBestIndex(const AResults: TWhisperBenchmarkArray; const AModelFile: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(AResults) do
    if AResults[I].Ok and SameFileName(AResults[I].ModelFile, AModelFile) and
      not CalibrationSuspect(AResults, I) and ((Result < 0) or (AResults[I].Speed > AResults[Result].Speed)) then
      Result := I;
end;

procedure CalibrationSave(const AIniFile: string; const AResults: TWhisperBenchmarkArray;
  const ADevicesKey, AAudioFile: string);
var
  Ini: TMemIniFile;
  Done: TStringList;
  I, B: Integer;
  Model, Made: string;
  FS: TFormatSettings;
begin
  FS := TFormatSettings.Invariant;
  Made := FormatDateTime('yyyy-mm-dd hh:nn', Now);
  ForceDirectories(ExtractFilePath(AIniFile));
  Ini := TMemIniFile.Create(AIniFile, TEncoding.UTF8);
  Done := TStringList.Create;
  try
    for I := 0 to High(AResults) do
    begin
      Model := AResults[I].ModelFile;
      // a model's section is made again as a whole
      if Done.IndexOf(ExtractFileName(Model)) < 0 then
      begin
        Done.Add(ExtractFileName(Model));
        Ini.EraseSection(ModelSection(Model));
        Ini.WriteString(ModelSection(Model), 'Made', Made);
        B := CalibrationBestIndex(AResults, Model);
        if B >= 0 then
        begin
          Ini.WriteString(ModelSection(Model), 'Best', AResults[B].Device.Name);
          Ini.WriteString(ModelSection(Model), 'BestSpeed', FloatToStrF(AResults[B].Speed, ffFixed, 15, 2, FS));
        end;
      end;
      if AResults[I].Ok then
      begin
        Ini.WriteString(ModelSection(Model), AResults[I].Device.Name, FloatToStrF(AResults[I].Speed, ffFixed, 15,
          2, FS));
        Ini.DeleteKey(CAL_CRASH_SECTION, AResults[I].Device.Name + '@' + ExtractFileName(Model));
      end
      else
        Ini.WriteString(ModelSection(Model), AResults[I].Device.Name, FAILED_PREFIX +
          OneLine(AResults[I].ErrorMessage));
    end;
    Ini.WriteBool(CAL_SECTION, 'Done', True);
    Ini.WriteString(CAL_SECTION, 'Made', Made);
    Ini.WriteString(CAL_SECTION, 'Devices', ADevicesKey);
    Ini.WriteString(CAL_SECTION, 'Audio', AAudioFile);
    Ini.UpdateFile;
  finally
    Done.Free;
    Ini.Free;
  end;
end;

function CalibrationBest(const AIniFile, AModelFile: string; out ADevice: string; out ASpeed: Double): Boolean;
var
  Ini: TMemIniFile;
begin
  ADevice := '';
  ASpeed := 0;
  Result := False;
  if (AModelFile = '') or not FileExists(AIniFile) then
    Exit;
  Ini := TMemIniFile.Create(AIniFile, TEncoding.UTF8);
  try
    ADevice := Ini.ReadString(ModelSection(AModelFile), 'Best', '');
    ASpeed := StrToFloatDef(Ini.ReadString(ModelSection(AModelFile), 'BestSpeed', '0'), 0,
      TFormatSettings.Invariant);
    Result := ADevice <> '';
  finally
    Ini.Free;
  end;
end;

function CalibrationFailure(const AIniFile, AModelFile, ADevice: string): string;
var
  Ini: TMemIniFile;
  V: string;
begin
  Result := '';
  if (AModelFile = '') or (ADevice = '') or not FileExists(AIniFile) then
    Exit;
  Ini := TMemIniFile.Create(AIniFile, TEncoding.UTF8);
  try
    V := Ini.ReadString(ModelSection(AModelFile), ADevice, '');
    if StartsText(FAILED_PREFIX, V) then
      Result := Copy(V, Length(FAILED_PREFIX) + 1, MaxInt);
  finally
    Ini.Free;
  end;
end;

function CalibrationSummary(const AIniFile, AModelFile: string): string;
var
  Ini: TMemIniFile;
  Keys: TStringList;
  I: Integer;
  V, S: string;
  Speed: Double;
begin
  Result := '';
  if (AModelFile = '') or not FileExists(AIniFile) then
    Exit;
  Ini := TMemIniFile.Create(AIniFile, TEncoding.UTF8);
  Keys := TStringList.Create;
  try
    Ini.ReadSection(ModelSection(AModelFile), Keys);
    for I := 0 to Keys.Count - 1 do
    begin
      if SameText(Keys[I], 'Made') or SameText(Keys[I], 'Best') or SameText(Keys[I], 'BestSpeed') then
        Continue;
      V := Ini.ReadString(ModelSection(AModelFile), Keys[I], '');
      if StartsText(FAILED_PREFIX, V) then
        S := Keys[I] + ' failed'
      else
      begin
        Speed := StrToFloatDef(V, 0, TFormatSettings.Invariant);
        S := Keys[I] + Format(' %.1fx', [Speed]);
      end;
      if Result <> '' then
        Result := Result + ', ';
      Result := Result + S;
    end;
    if Result <> '' then
      Result := Result + ' (' + Ini.ReadString(ModelSection(AModelFile), 'Made', '?') + ')';
  finally
    Keys.Free;
    Ini.Free;
  end;
end;

procedure CalibrationState(const AIniFile: string; out ADone, ADontAsk: Boolean; out ADevicesKey, AMade: string);
var
  Ini: TMemIniFile;
begin
  ADone := False;
  ADontAsk := False;
  ADevicesKey := '';
  AMade := '';
  if not FileExists(AIniFile) then
    Exit;
  Ini := TMemIniFile.Create(AIniFile, TEncoding.UTF8);
  try
    ADone := Ini.ReadBool(CAL_SECTION, 'Done', False);
    ADontAsk := Ini.ReadBool(CAL_SECTION, 'DontAsk', False);
    ADevicesKey := Ini.ReadString(CAL_SECTION, 'Devices', '');
    AMade := Ini.ReadString(CAL_SECTION, 'Made', '');
  finally
    Ini.Free;
  end;
end;

procedure CalibrationSetDontAsk(const AIniFile: string; AValue: Boolean);
var
  Ini: TMemIniFile;
begin
  ForceDirectories(ExtractFilePath(AIniFile));
  Ini := TMemIniFile.Create(AIniFile, TEncoding.UTF8);
  try
    Ini.WriteBool(CAL_SECTION, 'DontAsk', AValue);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

function CalibrationCrashes(const AIniFile: string): TStringList;
var
  Ini: TMemIniFile;
  Keys: TStringList;
  I, P: Integer;
begin
  Result := TStringList.Create;
  if not FileExists(AIniFile) then
    Exit;
  Ini := TMemIniFile.Create(AIniFile, TEncoding.UTF8);
  Keys := TStringList.Create;
  try
    Ini.ReadSection(CAL_CRASH_SECTION, Keys);
    // key: device@model -> model + #9 + device
    for I := 0 to Keys.Count - 1 do
    begin
      P := Pos('@', Keys[I]);
      if P > 0 then
        Result.Add(Copy(Keys[I], P + 1, MaxInt) + #9 + Copy(Keys[I], 1, P - 1));
    end;
  finally
    Keys.Free;
    Ini.Free;
  end;
end;

procedure CalibrationClearCrashes(const AIniFile: string);
var
  Ini: TMemIniFile;
begin
  if not FileExists(AIniFile) then
    Exit;
  Ini := TMemIniFile.Create(AIniFile, TEncoding.UTF8);
  try
    Ini.EraseSection(CAL_CRASH_SECTION);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

function CalibrationCheckMarker(const AMarkerFile, AIniFile: string): string;
var
  Text, Model, Device: string;
  P: Integer;
  Ini: TMemIniFile;
begin
  Result := '';
  if not FileExists(AMarkerFile) then
    Exit;
  try
    Text := Trim(TFile.ReadAllText(AMarkerFile, TEncoding.UTF8));
    System.SysUtils.DeleteFile(AMarkerFile);
  except
    on E: Exception do
      Exit('The calibration''s marker file cannot be read: ' + E.Message);
  end;
  P := Pos(#9, Text);
  if P = 0 then
    Exit;
  Model := Copy(Text, 1, P - 1);
  Device := Copy(Text, P + 1, MaxInt);
  ForceDirectories(ExtractFilePath(AIniFile));
  Ini := TMemIniFile.Create(AIniFile, TEncoding.UTF8);
  try
    Ini.WriteString(CAL_CRASH_SECTION, Device + '@' + Model, FormatDateTime('yyyy-mm-dd hh:nn', Now));
    Ini.WriteString(ModelSection(Model), Device, FAILED_PREFIX + 'EpubBuilder ended while it was being timed');
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
  Result := Format('EpubBuilder ended during the last calibration, while %s was timed on %s (a GPU runtime ' +
    'that gave up - not enough memory for the model?). That pair is recorded as failed and the calibration ' +
    'offered now leaves it out; Tools > Re-calibrate tries it again.', [Model, Device]);
end;

function FindCalibrationAudio(const ASaved: string): string;
var
  Dir: string;
  I: Integer;
begin
  if (ASaved <> '') and FileExists(ASaved) then
    Exit(ASaved);
  Dir := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  {$IFDEF MACOS}
  // the bundle's Contents/Resources/media (Dir is Contents/MacOS), where
  // Deploy and tools/redist.sh deploy put it
  Result := TPath.Combine(TPath.Combine(TPath.Combine(ExtractFileDir(Dir), 'Resources'), 'media'),
    CALIBRATION_AUDIO);
  if FileExists(Result) then
    Exit;
  {$ENDIF}
  for I := 0 to CALIBRATION_AUDIO_LEVELS do
  begin
    Result := TPath.Combine(TPath.Combine(Dir, 'media'), CALIBRATION_AUDIO);
    if FileExists(Result) then
      Exit;
    if ExtractFileDir(Dir) = Dir then
      Break;
    Dir := ExtractFileDir(Dir);
  end;
  Result := '';
end;

function AskCalibration(AOwner: TComponent; const AText: string; out ADontAsk: Boolean): Boolean;
var
  F: TForm;
  L: TLabel;
  C: TCheckBox;
  Bar: TLayout;
  B: TButton;
begin
  F := TForm.CreateNew(AOwner);
  try
    F.Caption := 'Calibrate EpubBuilder for this machine';
    F.ClientWidth := 600;
    F.ClientHeight := 360;
    F.Position := TFormPosition.OwnerFormCenter;
    F.BorderIcons := [TBorderIcon.biSystemMenu];
    // bottom up: the buttons, then the check box above them
    Bar := TLayout.Create(F);
    Bar.Parent := F;
    Bar.Align := TAlignLayout.Bottom;
    Bar.Position.Y := 10000;
    Bar.Height := 44;
    Bar.Margins.Rect := RectF(12, 0, 12, 10);
    B := TButton.Create(F);
    B.Parent := Bar;
    B.Align := TAlignLayout.Right;
    B.Position.X := 10000;
    B.Width := 100;
    B.Margins.Rect := RectF(8, 0, 0, 0);
    B.Text := 'Cancel';
    B.ModalResult := mrCancel;
    B.Cancel := True;
    B := TButton.Create(F);
    B.Parent := Bar;
    B.Align := TAlignLayout.Right;
    B.Position.X := 0;
    B.Width := 150;
    B.Text := 'Start calibration';
    B.ModalResult := mrOk;
    B.Default := True;
    C := TCheckBox.Create(F);
    C.Parent := F;
    C.Align := TAlignLayout.Bottom;
    C.Position.Y := 0;
    C.Height := 26;
    C.Margins.Rect := RectF(12, 0, 12, 4);
    C.Text := 'Do not show this again';
    L := TLabel.Create(F);
    L.Parent := F;
    L.Align := TAlignLayout.Client;
    L.Margins.Rect := RectF(12, 12, 12, 8);
    L.AutoSize := False;
    // the style would set the alignment and the wrapping back
    L.StyledSettings := L.StyledSettings - [TStyledSetting.Other];
    L.WordWrap := True;
    L.TextSettings.VertAlign := TTextAlign.Leading;
    L.Text := AText;
    Result := F.ShowModal = mrOk;
    ADontAsk := C.IsChecked;
  finally
    F.Free;
  end;
end;

{ TCalibrationThread }

constructor TCalibrationThread.Create(AModels: TStrings; const AAudioFile, ALanguage, APrompt,
  AMarkerFile: string; const ADevices: TWhisperDeviceArray; ASkip: TStrings);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FModels := TStringList.Create;
  FModels.Assign(AModels);
  FAudioFile := AAudioFile;
  FLanguage := ALanguage;
  FPrompt := APrompt;
  FMarkerFile := AMarkerFile;
  FDevices := Copy(ADevices);
  FSkip := TStringList.Create;
  FSkip.CaseSensitive := False;
  if ASkip <> nil then
    FSkip.Assign(ASkip);
end;

destructor TCalibrationThread.Destroy;
begin
  FSkip.Free;
  FModels.Free;
  inherited;
end;

procedure TCalibrationThread.Cancel;
begin
  Terminate;
  // FBench is freed at the end of Execute: never used outside the lock
  TMonitor.Enter(Self);
  try
    if FBench <> nil then
      FBench.Cancel;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TCalibrationThread.Log(const AText: string);
var
  P: TProc<string>;
begin
  DebugLog(AText);
  P := FOnLog;
  if Assigned(P) then
    TThread.Queue(nil,
      procedure
      begin
        P(AText);
      end);
end;

procedure TCalibrationThread.Progress(APercent: Double);
var
  P: TProc<Double>;
begin
  P := FOnProgress;
  if Assigned(P) then
    TThread.Queue(nil,
      procedure
      begin
        P(APercent);
      end);
end;

procedure TCalibrationThread.Status(const AText: string);
var
  P: TProc<string>;
begin
  DebugLog('status: ' + AText);
  P := FOnStatus;
  if Assigned(P) then
    TThread.Queue(nil,
      procedure
      begin
        P(AText);
      end);
end;

procedure TCalibrationThread.Execute;
var
  FF: TFFmpegLibrary;
  Audio: TWhisperAudioSet;
  Files: TStringList;
  Samples: TWhisperSamples;
  Seconds: Double;
  CP: TWhisperContextParams;
  Params: TWhisperParams;
  Bench: TWhisperBenchmark;
  R: TWhisperBenchmarkResult;
  M, D, N, Total, B, I: Integer;
  Key, Line: string;
begin
  FF := nil;
  Audio := nil;
  Files := nil;
  Params := nil;
  Bench := nil;
  try
    try
      // the recording, whole (its chapters are not parts here)
      Status('Calibrating: reading the recording ...');
      FF := OpenBuilderFFmpeg;
      Files := TStringList.Create;
      Files.Add(FAudioFile);
      Audio := TWhisperAudioSet.Create(FF, Files, False);
      Samples := Audio.Read(0);
      Seconds := WhisperSamplesSeconds(Samples);
      if Length(Samples) = 0 then
        raise EWhisperError.Create('The recording has no sound: ' + FAudioFile);
      Log(Format('Recording: %s (%s)', [FAudioFile, Hms(Seconds)]));
      if Seconds < 120 then
        Log('A short recording: the 30 s timed cannot keep 30 s away from both ends (the middle is timed)');
      if Terminated then
        Exit;

      // a build's settings: DTW word times (the heads are chosen per model
      // by the benchmark), each window on its own, the book prompt
      CP := TWhisperLib.Instance.DefaultContextParams;
      if not WhisperEnableDtw(FModels[0], CP) then
        Log('The model header cannot be read for DTW: timed without word times');
      Params := TWhisperParams.Create;
      Params.Translate := False;
      if FLanguage <> '' then
        Params.Language := FLanguage;
      Params.NoContext := True;
      Params.MaxTextContext := 0;
      Params.InitialPrompt := FPrompt;
      Params.CarryInitialPrompt := FPrompt <> '';
      Bench := TWhisperBenchmark.Create(FModels[0], Samples);
      Bench.Params := Params;
      Bench.ContextParams := CP;
      Bench.Runs := CALIBRATION_RUNS;
      TMonitor.Enter(Self);
      try
        FBench := Bench;
      finally
        TMonitor.Exit(Self);
      end;

      Total := FModels.Count * Length(FDevices);
      N := 0;
      for M := 0 to FModels.Count - 1 do
      begin
        if Terminated then
          Break;
        Log('');
        Log(Format('%s (%.0f MB):', [ExtractFileName(FModels[M]), TFile.GetSize(FModels[M]) / 1048576]));
        for D := 0 to High(FDevices) do
        begin
          if Terminated then
            Break;
          Progress(100 * N / Max(1, Total));
          Status(Format('Calibrating: %s on %s (%d of %d; loading, a warm-up and %d timed runs) ...',
            [ExtractFileName(FModels[M]), FDevices[D].Name, N + 1, Total, CALIBRATION_RUNS]));
          Key := ExtractFileName(FModels[M]) + #9 + FDevices[D].Name;
          if FSkip.IndexOf(Key) >= 0 then
          begin
            R := Default(TWhisperBenchmarkResult);
            R.ModelFile := FModels[M];
            R.Device := FDevices[D];
            R.ErrorMessage := SKIPPED_TEXT;
            Log('  ' + WhisperDeviceText(FDevices[D]) + ': ' + SKIPPED_TEXT);
          end
          else
          begin
            // a GPU runtime that aborts takes the program with it: the
            // next start finds the marker and records this pair as failed
            try
              TFile.WriteAllText(FMarkerFile, Key, TEncoding.UTF8);
            except
              on E: Exception do
                DebugLog('calibration marker not written: ' + E.Message);
            end;
            R := Bench.RunOne(FModels[M], FDevices[D]);
            System.SysUtils.DeleteFile(FMarkerFile);
            // cancelled mid-run: not a result
            if Terminated and not R.Ok then
              Break;
            if R.Ok then
            begin
              Log(Format('  %s: %.1fx real time (median of %d runs of %.0f s from %s, %.0f %% sound; ' +
                'loading %.1f s, warm-up %.1f s, %d threads)', [WhisperDeviceText(R.Device), R.Speed, R.Runs,
                R.AudioSeconds, Hms(R.StartSeconds), R.SpeechShare * 100, R.LoadMs / 1000, R.WarmupMs / 1000,
                R.Threads]));
              DebugLog('calibration text: ' + R.Text);
            end
            else
              Log(Format('  %s: FAILED - %s', [WhisperDeviceText(R.Device), OneLine(R.ErrorMessage)]));
          end;
          FResults := FResults + [R];
          Inc(N);
        end;
      end;
      if Terminated then
      begin
        Log('Calibration cancelled');
        Exit;
      end;
      Progress(100);

      // per model: the choice, and what was left out of it
      Log('');
      for M := 0 to FModels.Count - 1 do
      begin
        for I := 0 to High(FResults) do
          if SameFileName(FResults[I].ModelFile, FModels[M]) and CalibrationSuspect(FResults, I) then
            Log(Format('%s on %s heard far fewer words than the other devices (%s): not chosen - it may not ' +
              'compute correctly', [ExtractFileName(FModels[M]), FResults[I].Device.Name,
              Copy(FResults[I].Text, 1, 80)]));
        B := CalibrationBestIndex(FResults, FModels[M]);
        if B < 0 then
          Log(Format('%s: NO DEVICE COULD RUN IT on this machine', [ExtractFileName(FModels[M])]))
        else
        begin
          Line := Format('%s: fastest on %s (%.1fx real time)', [ExtractFileName(FModels[M]),
            FResults[B].Device.Name, FResults[B].Speed]);
          if FResults[B].Device.DeviceType = wdtCPU then
            Line := Line + ' - the CPU: no graphics card here could run it (its memory?), and a book will take ' +
              'many hours; a smaller model (large-v3-turbo, medium) may fit the card';
          Log(Line);
        end;
      end;
      FCompleted := True;
      Status('Calibration done');
    except
      on E: Exception do
      begin
        Log('Calibration FAILED: ' + E.Message);
        Status('Calibration failed: ' + E.Message);
      end;
    end;
  finally
    TMonitor.Enter(Self);
    try
      FBench := nil;
    finally
      TMonitor.Exit(Self);
    end;
    Bench.Free;
    Params.Free;
    Audio.Free;
    Files.Free;
    FF.Free;
  end;
end;

end.
