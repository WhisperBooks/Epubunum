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
  { Seconds of the recording that each run of the diagnostics transcribes
    (TCalibrationThread.Diagnostics), from DIAGNOSTIC_EDGE_SECONDS in:
    about twenty 30 s windows - enough to tell a cost from chance, short
    enough for four runs on a slow machine. }
  DIAGNOSTIC_SECONDS = 600;
  { Seconds at a recording's start and at its end that the diagnostics
    leave out, as a calibration does (WhisperFindSpeech's edge): Whisper
    leaves a spoken introduction or closing notice untranscribed (a
    LibriVox recording's, about 26 s), so only chapter material is timed
    and scored. }
  DIAGNOSTIC_EDGE_SECONDS = 30;

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
    { Backing field of @link(Diagnostics). }
    FDiagnostics: Boolean;
    { Backing field of @link(IniFile). }
    FIniFile: string;
    { The run in progress during the diagnostics (for Cancel; guarded by
      TMonitor on Self). }
    FDiagRun: TWhisperRun;
    { Diagnostics: when the 30 s window being transcribed began. }
    FDiagTick: TDateTime;
    { Diagnostics: seconds each 30 s window of the run took, in order. }
    FDiagWindows: TArray<Double>;
    { Diagnostics: progress of all runs when the run in progress began, %. }
    FDiagBase: Double;
    { Diagnostics: runs that share the progress bar. }
    FDiagRuns: Integer;
    { Diagnostics, from whisper.cpp's timing lines (DiagLogLine): windows
      that failed the probability check since the model was loaded. }
    FDiagFailP: Integer;
    { Diagnostics: windows that failed the entropy check since the model
      was loaded. }
    FDiagFailH: Integer;
    { Diagnostics: the sampling's time in the run, ms. }
    FDiagSample: Double;
    { Diagnostics: the encoder's time in the run, ms. }
    FDiagEncode: Double;
    { Diagnostics: the decoder's time in the run, ms (whisper.cpp's decode,
      batched decode and prompt times together). }
    FDiagDecode: Double;
    { Diagnostics: the decoder's runs in the run (one per token decoded,
      a batch counted once). }
    FDiagDecodeRuns: Integer;
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
    { whisper.cpp's log during the diagnostics: the lines of
      whisper_print_timings are read into the fields above. }
    procedure DiagLogLine(Sender: TObject; ALevel: TWhisperLogLevel; const AText: string);
    { The diagnostic run's progress - whisper.cpp reports it at the start
      of every 30 s window: the time since the report before is the time
      the window between them took. }
    procedure DiagProgress(Sender: TObject; AProgress: Integer);
    { The diagnostics (@link(Diagnostics)): DIAGNOSTIC_SECONDS of the
      recording, DIAGNOSTIC_EDGE_SECONDS clear of its start and end,
      transcribed four times by each model on its
      device with a build's settings - as a build, without
      whisper.cpp's temperature fallback, without DTW, without either -
      and each run's time, words, fallbacks, encoder / decoder times and
      window times logged, then what the fallback and DTW cost; with
      several models a closing table, a line per model. A model that
      cannot be loaded is logged and the next one run. }
    procedure ExecuteDiagnostics;
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
    { True when every pair was timed (not cancelled, no error); with
      @link(Diagnostics), when the four runs were made. }
    property Completed: Boolean read FCompleted;
    { Set before Start: the thread runs the diagnostics (ExecuteDiagnostics)
      instead of the calibration - every model given to Create, the first
      on the first device, the second on the second and so on (the first
      device for a model without one of its own). Nothing is timed for the
      settings: Results stays empty and the crash marker is not written. }
    property Diagnostics: Boolean read FDiagnostics write FDiagnostics;
    { The settings file ('' = none): the diagnostics say what the
      calibration kept there timed each model at on its device. }
    property IniFile: string read FIniFile write FIniFile;
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

{ The calibration's speed of AModelFile (by file name) on ADevice.
  @returns(x real time; 0 when not timed there or it failed) }
function CalibrationSpeed(const AIniFile, AModelFile, ADevice: string): Double;

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

{ Tools > Build history: the history (uHistory) as a table, newest first,
  under a line per model and device of this machine; Copy puts it on the
  clipboard as tab-separated text. Modal.
  @param(AOwner  the window it is centred on)
  @param(AFile  the history file)
  @param(AMachine  this computer's name (HistoryMachine)) }
procedure ShowBuildHistory(AOwner: TComponent; const AFile, AMachine: string);

implementation

uses
  {$IFDEF POSIX}
  // System.SysUtils.DeleteFile's inline body expands only with it (H2443)
  Posix.Unistd,
  {$ENDIF}
  System.Types, System.Math, System.StrUtils, System.IOUtils, System.DateUtils,
  System.Rtti,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Layouts, FMX.Grid, FMX.Grid.Style, FMX.Platform,
  // the diagnostics' accuracy: the recording's text aligned with what was heard
  Whisper.Align,
  uDebugLog, uHistory;

type
  { The history window's Copy button (an event needs a method). }
  THistoryCopy = class(TComponent)
  public
    { The text Copy puts on the clipboard. }
    Text: string;
    { Copy: Text to the clipboard. }
    procedure Click(Sender: TObject);
  end;

procedure THistoryCopy.Click(Sender: TObject);
var
  Svc: IFMXClipboardService;
begin
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Svc) then
    Svc.SetClipboard(TValue.From<string>(Text));
end;

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

function CalibrationSpeed(const AIniFile, AModelFile, ADevice: string): Double;
var
  Ini: TMemIniFile;
begin
  Result := 0;
  if (AModelFile = '') or (ADevice = '') or not FileExists(AIniFile) then
    Exit;
  Ini := TMemIniFile.Create(AIniFile, TEncoding.UTF8);
  try
    // the speed, or 'failed: ...' (which does not read: 0)
    Result := StrToFloatDef(Ini.ReadString(ModelSection(AModelFile), ADevice, ''), 0, TFormatSettings.Invariant);
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

procedure ShowBuildHistory(AOwner: TComponent; const AFile, AMachine: string);
var
  F: TForm;
  L: TLabel;
  Bar: TLayout;
  B: TButton;
  G: TStringGrid;
  Col: TStringColumn;
  H: TBuildHistory;
  Cells: TArray<string>;
  Copier: THistoryCopy;
  Summary: string;
  C, R: Integer;
begin
  H := HistoryLoad(AFile);
  F := TForm.CreateNew(AOwner);
  try
    F.Caption := Format('Build history - %d build(s)', [Length(H)]);
    F.ClientWidth := 1180;
    F.ClientHeight := 560;
    F.Position := TFormPosition.OwnerFormCenter;
    Copier := THistoryCopy.Create(F);
    Copier.Text := HistoryTable(H);
    // bottom up: the buttons, the file's name on their left
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
    B.Text := 'Close';
    B.ModalResult := mrOk;
    B.Cancel := True;
    B.Default := True;
    B := TButton.Create(F);
    B.Parent := Bar;
    B.Align := TAlignLayout.Right;
    B.Position.X := 0;
    B.Width := 100;
    B.Text := 'Copy';
    B.OnClick := Copier.Click;
    B.Enabled := Length(H) > 0;
    L := TLabel.Create(F);
    L.Parent := Bar;
    L.Align := TAlignLayout.Client;
    L.Text := AFile;
    // the summary over the table
    Summary := HistorySummary(H, AMachine);
    L := TLabel.Create(F);
    L.Parent := F;
    L.Align := TAlignLayout.Top;
    L.Margins.Rect := RectF(12, 10, 12, 6);
    L.AutoSize := False;
    L.StyledSettings := L.StyledSettings - [TStyledSetting.Other];
    L.WordWrap := True;
    L.TextSettings.VertAlign := TTextAlign.Leading;
    L.Height := 20 * (Length(Summary) - Length(StringReplace(Summary, #10, '', [rfReplaceAll])) + 1) + 4;
    L.Text := Summary;
    G := TStringGrid.Create(F);
    G.Parent := F;
    G.Align := TAlignLayout.Client;
    G.Margins.Rect := RectF(12, 0, 12, 8);
    G.Options := G.Options - [TGridOption.Editing] + [TGridOption.RowSelect];
    for C := 0 to High(HISTORY_HEADERS) do
    begin
      Col := TStringColumn.Create(G);
      Col.Header := HISTORY_HEADERS[C];
      Col.Width := HISTORY_WIDTHS[C];
      G.AddObject(Col);
    end;
    G.RowCount := Length(H);
    for R := 0 to High(H) do
    begin
      // newest first
      Cells := HistoryCells(H[High(H) - R]);
      for C := 0 to High(Cells) do
        G.Cells[C, R] := Cells[C];
    end;
    F.ShowModal;
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
    if FDiagRun <> nil then
      FDiagRun.Cancel;
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

const
  { The start of the calibration recording's text, for the diagnostics'
    accuracy figures: "Aladdin and the Wonderful Lamp" as Andrew Lang's Blue
    Fairy Book has it (1889, in the public domain; Project Gutenberg's
    text 503), its first 2000 words - more than the DIAGNOSTIC_SECONDS
    read. One string per line of the source, joined with spaces. }
  DIAG_REFERENCE: array[0..113] of string = (
    'There once lived a poor tailor, who had a son called Aladdin, a careless, idle boy who would do',
    'nothing but play ball all day long in the streets with little idle boys like himself. This so',
    'grieved the father that he died; yet, in spite of his mother''s tears and prayers, Aladdin did',
    'not mend his ways. One day, when he was playing in the streets as usual, a stranger asked him',
    'his age, and if he was not the son of Mustapha the tailor. "I am, sir," replied Aladdin; "but he',
    'died a long while ago." On this the stranger, who was a famous African magician, fell on his',
    'neck and kissed him, saying, "I am your uncle, and knew you from your likeness to my brother. Go',
    'to your mother and tell her I am coming." Aladdin ran home and told his mother of his newly',
    'found uncle. "Indeed, child," she said, "your father had a brother, but I always thought he was',
    'dead." However, she prepared supper, and bade Aladdin seek his uncle, who came laden with wine',
    'and fruit. He presently fell down and kissed the place where Mustapha used to sit, bidding',
    'Aladdin''s mother not to be surprised at not having seen him before, as he had been forty years',
    'out of the country. He then turned to Aladdin, and asked him his trade, at which the boy hung',
    'his head, while his mother burst into tears. On learning that Aladdin was idle and would learn',
    'no trade, he offered to take a shop for him and stock it with merchandise. Next day he bought',
    'Aladdin a fine suit of clothes and took him all over the city, showing him the sights, and',
    'brought him home at nightfall to his mother, who was overjoyed to see her son so fine. The next',
    'day the magician led Aladdin into some beautiful gardens a long way outside the city gates. They',
    'sat down by a fountain and the magician pulled a cake from his girdle, which he divided between',
    'them. They then journeyed onward till they almost reached the mountains. Aladdin was so tired',
    'that he begged to go back, but the magician beguiled him with pleasant stories, and led him on',
    'in spite of himself. At last they came to two mountains divided by a narrow valley. "We will go',
    'no farther," said the false uncle. "I will show you something wonderful; only do you gather up',
    'sticks while I kindle a fire." When it was lit the magician threw on it a powder he had about',
    'him, at the same time saying some magical words. The earth trembled a little and opened in front',
    'of them, disclosing a square flat stone with a brass ring in the middle to raise it by. Aladdin',
    'tried to run away, but the magician caught him and gave him a blow that knocked him down. "What',
    'have I done, uncle?" he said piteously; whereupon the magician said more kindly: "Fear nothing,',
    'but obey me. Beneath this stone lies a treasure which is to be yours, and no one else may touch',
    'it, so you must do exactly as I tell you." At the word treasure Aladdin forgot his fears, and',
    'grasped the ring as he was told, saying the names of his father and grandfather. The stone came',
    'up quite easily, and some steps appeared. "Go down," said the magician; "at the foot of those',
    'steps you will find an open door leading into three large halls. Tuck up your gown and go',
    'through them without touching anything, or you will die instantly. These halls lead into a',
    'garden of fine fruit trees. Walk on until you come to a niche in a terrace where stands a',
    'lighted lamp. Pour out the oil it contains, and bring it to me." He drew a ring from his finger',
    'and gave it to Aladdin, bidding him prosper. Aladdin found everything as the magician had said,',
    'gathered some fruit off the trees, and, having got the lamp, arrived at the mouth of the cave.',
    'The magician cried out in a great hurry: "Make haste and give me the lamp." This Aladdin refused',
    'to do until he was out of the cave. The magician flew into a terrible passion, and throwing some',
    'more powder on to the fire, he said something, and the stone rolled back into its place. The',
    'magician left Persia for ever, which plainly showed that he was no uncle of Aladdin''s, but a',
    'cunning magician, who had read in his magic books of a wonderful lamp, which would make him the',
    'most powerful man in the world. Though he alone knew where to find it, he could only receive it',
    'from the hand of another. He had picked out the foolish Aladdin for this purpose, intending to',
    'get the lamp and kill him afterward. For two days Aladdin remained in the dark, crying and',
    'lamenting. At last he clasped his hands in prayer, and in so doing rubbed the ring, which the',
    'magician had forgotten to take from him. Immediately an enormous and frightful genie rose out of',
    'the earth, saying: "What wouldst thou with me? I am the Slave of the Ring, and will obey thee in',
    'all things." Aladdin fearlessly replied: "Deliver me from this place!" whereupon the earth',
    'opened, and he found himself outside. As soon as his eyes could bear the light he went home, but',
    'fainted on the threshold. When he came to himself he told his mother what had passed, and showed',
    'her the lamp and the fruits he had gathered in the garden, which were, in reality, precious',
    'stones. He then asked for some food. "Alas! child," she said, "I have nothing in the house, but',
    'I have spun a little cotton and will go and sell it." Aladdin bade her keep her cotton, for he',
    'would sell the lamp instead. As it was very dirty she began to rub it, that it might fetch a',
    'higher price. Instantly a hideous genie appeared, and asked what she would have. She fainted',
    'away, but Aladdin, snatching the lamp, said boldly: "Fetch me something to eat!" The genie',
    'returned with a silver bowl, twelve silver plates containing rich meats, two silver cups, and',
    'two bottles of wine. Aladdin''s mother, when she came to herself, said: "Whence comes this',
    'splendid feast?" "Ask not, but eat," replied Aladdin. So they sat at breakfast till it was',
    'dinner-time, and Aladdin told his mother about the lamp. She begged him to sell it, and have',
    'nothing to do with devils. "No," said Aladdin, "since chance hath made us aware of its virtues,',
    'we will use it, and the ring likewise, which I shall always wear on my finger." When they had',
    'eaten all the genie had brought, Aladdin sold one of the silver plates, and so on until none',
    'were left. He then had recourse to the genie, who gave him another set of plates, and thus they',
    'lived for many years. One day Aladdin heard an order from the Sultan proclaimed that everyone',
    'was to stay at home and close his shutters while the Princess, his daughter, went to and from',
    'the bath. Aladdin was seized by a desire to see her face, which was very difficult, as she',
    'always went veiled. He hid himself behind the door of the bath, and peeped through a chink. The',
    'Princess lifted her veil as she went in, and looked so beautiful that Aladdin fell in love with',
    'her at first sight. He went home so changed that his mother was frightened. He told her he loved',
    'the Princess so deeply that he could not live without her, and meant to ask her in marriage of',
    'her father. His mother, on hearing this, burst out laughing, but Aladdin at last prevailed upon',
    'her to go before the Sultan and carry his request. She fetched a napkin and laid in it the magic',
    'fruits from the enchanted garden, which sparkled and shone like the most beautiful jewels. She',
    'took these with her to please the Sultan, and set out, trusting in the lamp. The Grand Vizier',
    'and the lords of council had just gone in as she entered the hall and placed herself in front of',
    'the Sultan. He, however, took no notice of her. She went every day for a week, and stood in the',
    'same place. When the council broke up on the sixth day the Sultan said to his Vizier: "I see a',
    'certain woman in the audience-chamber every day carrying something in a napkin. Call her next',
    'time, that I may find out what she wants." Next day, at a sign from the Vizier, she went up to',
    'the foot of the throne and remained kneeling till the Sultan said to her: "Rise, good woman, and',
    'tell me what you want." She hesitated, so the Sultan sent away all but the Vizier, and bade her',
    'speak frankly, promising to forgive her beforehand for anything she might say. She then told him',
    'of her son''s violent love for the Princess. "I prayed him to forget her," she said, "but in',
    'vain; he threatened to do some desperate deed if I refused to go and ask your Majesty for the',
    'hand of the Princess. Now I pray you to forgive not me alone, but my son Aladdin." The Sultan',
    'asked her kindly what she had in the napkin, whereupon she unfolded the jewels and presented',
    'them. He was thunderstruck, and turning to the Vizier said: "What sayest thou? Ought I not to',
    'bestow the Princess on one who values her at such a price?" The Vizier, who wanted her for his',
    'own son, begged the Sultan to withhold her for three months, in the course of which he hoped his',
    'son would contrive to make him a richer present. The Sultan granted this, and told Aladdin''s',
    'mother that, though he consented to the marriage, she must not appear before him again for three',
    'months. Aladdin waited patiently for nearly three months, but after two had elapsed his mother,',
    'going into the city to buy oil, found every one rejoicing, and asked what was going on. "Do you',
    'not know," was the answer, "that the son of the Grand Vizier is to marry the Sultan''s daughter',
    'to-night?" Breathless, she ran and told Aladdin, who was overwhelmed at first, but presently',
    'bethought him of the lamp. He rubbed it, and the genie appeared, saying, "What is thy will?"',
    'Aladdin replied: "The Sultan, as thou knowest, has broken his promise to me, and the Vizier''s',
    'son is to have the Princess. My command is that to-night you bring hither the bride and',
    'bridegroom." "Master, I obey," said the genie. Aladdin then went to his chamber, where, sure',
    'enough, at midnight the genie transported the bed containing the Vizier''s son and the Princess.',
    '"Take this new-married man," he said, "and put him outside in the cold, and return at daybreak."',
    'Whereupon the genie took the Vizier''s son out of bed, leaving Aladdin with the Princess. "Fear',
    'nothing," Aladdin said to her; "you are my wife, promised to me by your unjust father, and no',
    'harm shall come to you." The Princess was too frightened to speak, and passed the most miserable',
    'night of her life, while Aladdin lay down beside her and slept soundly. At the appointed hour',
    'the genie fetched in the shivering bridegroom, laid him in his place, and transported the bed',
    'back to the palace. Presently the Sultan came to wish his daughter good-morning. The unhappy',
    'Vizier''s son jumped up and hid himself, while the Princess would not say a word, and was very',
    'sorrowful. The Sultan sent her mother to her, who said: "How comes it, child, that you will not',
    'speak to your father? What has happened?" The Princess sighed deeply, and at last told her',
    'mother how, during the night, the bed had been carried into');

{ The words of DIAG_REFERENCE as the aligner wants them.
  @returns(the words, in reading order) }
function DiagReferenceWords: TWhisperStringArray;
var
  I: Integer;
  Text: string;
begin
  Text := '';
  for I := 0 to Length(DIAG_REFERENCE) - 1 do
    Text := Text + DIAG_REFERENCE[I] + ' ';
  Result := WhisperSplitText(Text);
end;

{ The number that follows AKey in ALine, read with a decimal point
  (whisper.cpp's timing lines: 'encode time =  1234.56 ms /    70 runs').
  @param(ALine   the line)
  @param(AKey    the text before the number)
  @param(AValue  receives the number)
  @returns(False when ALine has no AKey, or no number after it) }
function NumberAfter(const ALine, AKey: string; out AValue: Double): Boolean;
var
  P, Q: Integer;
  S: string;
begin
  Result := False;
  AValue := 0;
  P := Pos(AKey, ALine);
  if P = 0 then
    Exit;
  P := P + Length(AKey);
  while (P <= Length(ALine)) and (ALine[P] = ' ') do
    Inc(P);
  Q := P;
  while (Q <= Length(ALine)) and CharInSet(ALine[Q], ['0'..'9', '.', '-']) do
    Inc(Q);
  S := Copy(ALine, P, Q - P);
  Result := (S <> '') and TryStrToFloat(S, AValue, TFormatSettings.Invariant);
end;

procedure TCalibrationThread.DiagLogLine(Sender: TObject; ALevel: TWhisperLogLevel; const AText: string);
var
  V, Runs: Double;
  P: Integer;
begin
  if NumberAfter(AText, 'fallbacks =', V) then
  begin
    // 'fallbacks =   3 p /   0 h'
    FDiagFailP := Round(V);
    P := Pos(' p /', AText);
    if (P > 0) and NumberAfter(Copy(AText, P, MaxInt), ' p /', V) then
      FDiagFailH := Round(V);
  end
  else if NumberAfter(AText, 'sample time =', V) then
    FDiagSample := V
  else if NumberAfter(AText, 'encode time =', V) then
    FDiagEncode := V
  else if NumberAfter(AText, 'decode time =', V) or NumberAfter(AText, 'batchd time =', V) or
    NumberAfter(AText, 'prompt time =', V) then
  begin
    // the decoder's three timers: one token, a batch of them, the prompt.
    // An unused timer prints 0 ms and "1 runs" (whisper.cpp divides by at
    // least 1): not counted
    FDiagDecode := FDiagDecode + V;
    if (V > 0) and NumberAfter(AText, 'ms /', Runs) then
      Inc(FDiagDecodeRuns, Round(Runs));
  end;
end;

procedure TCalibrationThread.DiagProgress(Sender: TObject; AProgress: Integer);
const
  { A report this soon after the one before is not a window's end: the
    first report of a run, or the closing 100 % after the last window. }
  MIN_WINDOW_SECONDS = 0.02;
var
  T: TDateTime;
  Taken: Double;
begin
  T := Now;
  Taken := MilliSecondsBetween(T, FDiagTick) / 1000;
  if (AProgress > 0) and (Taken >= MIN_WINDOW_SECONDS) then
  begin
    SetLength(FDiagWindows, Length(FDiagWindows) + 1);
    FDiagWindows[Length(FDiagWindows) - 1] := Taken;
  end;
  FDiagTick := T;
  if FDiagRuns > 0 then
    Progress(FDiagBase + AProgress / FDiagRuns);
end;

procedure TCalibrationThread.ExecuteDiagnostics;
const
  { Runs: with and without the fallback, with and without DTW. The model
    is loaded for the first and the third (DTW is chosen when it loads). }
  RUN_COUNT = 4;
  { What each run is, for the log. }
  RUN_NAMES: array[0..RUN_COUNT - 1] of string = ('as a build (fallback on, DTW on)',
    'no fallback (DTW on)', 'no DTW (fallback on)', 'no fallback, no DTW');
var
  FF: TFFmpegLibrary;
  Audio: TWhisperAudioSet;
  Files, Table: TStringList;
  Samples: TWhisperSamples;
  Seconds, Taken, Median, Slowest, Fastest: Double;
  Lib: TWhisperLib;
  CP: TWhisperContextParams;
  Model: TWhisperModel;
  Params: TWhisperParams;
  Run: TWhisperRun;
  R: TWhisperTranscription;
  M, FailP0, FailH0, Slow, Fails, Edge: Integer;
  Sorted: TArray<Double>;
  Held: Double;
  Took: array[0..RUN_COUNT - 1] of Double;
  NoDtw, NoFallback, AllDone: Boolean;
  // accuracy against the recording's text
  Reference: TWhisperStringArray;
  Aligned: TWhisperAlignedWordArray;
  Stats: TWhisperAlignStats;
  FirstRead, LastRead, NGood, NSame, NRead: Integer;
  Score: array[0..RUN_COUNT - 1] of Double;
  Dev: TWhisperDevice;
  Line: string;

  { The four runs of model AModelFile (number AIndex, from 0, of the
    models) on ADev, logged with what the fallback and DTW cost it. ALine
    receives the model's line for the closing table ('' when its first run
    was not made). What loading the model raises is passed on. }
  procedure OneModel(AIndex: Integer; const AModelFile: string; const ADev: TWhisperDevice; out ALine: string);
  var
    I, J, K: Integer;
    Speed: Double;
  begin
    ALine := '';
    FailP0 := 0;
    FailH0 := 0;
    Fails := 0;
    for I := 0 to RUN_COUNT - 1 do
    begin
      Took[I] := 0;
      Score[I] := -1;
    end;
    Log('');
    Log(Format('%s on %s', [ExtractFileName(AModelFile), WhisperDeviceText(ADev)]));
    if FIniFile <> '' then
    begin
      Speed := CalibrationSpeed(FIniFile, ExtractFileName(AModelFile), ADev.Name);
      if Speed > 0 then
        Log(Format('The calibration timed it there at %.1fx real time (one 30 s stretch).', [Speed]))
      else
        Log('It is not calibrated on that device.');
    end;
    try
      for I := 0 to RUN_COUNT - 1 do
      begin
        if Terminated then
          Break;
        NoFallback := Odd(I);
        NoDtw := I >= RUN_COUNT div 2;
        if not Odd(I) then
        begin
          // DTW belongs to the loaded model: one model for each pair of runs
          FreeAndNil(Model);
          Status(Format('Diagnostics: %s, run %d of %d - loading the model ...', [ExtractFileName(AModelFile), I + 1,
            RUN_COUNT]));
          CP := Lib.DefaultContextParams;
          if not Lib.ContextParamsFor(ADev.Name, CP) then
            raise EWhisperError.CreateFmt('Device %s cannot be used', [ADev.Name]);
          if NoDtw then
            // as with DTW (which turns it off): only DTW differs
            CP.flash_attn := False
          else if not WhisperEnableDtw(AModelFile, CP) then
            Log('The model header cannot be read for DTW: runs 1 and 2 are without it too');
          Model := TWhisperModel.Create(AModelFile, CP);
          // whisper.cpp counts fallbacks from the model's loading
          FailP0 := 0;
          FailH0 := 0;
        end;
        Params := TWhisperParams.Create;
        try
          Params.Translate := False;
          if FLanguage <> '' then
            Params.Language := FLanguage;
          Params.NoContext := True;
          Params.MaxTextContext := 0;
          Params.InitialPrompt := FPrompt;
          Params.CarryInitialPrompt := FPrompt <> '';
          if NoFallback then
            // whisper.cpp: no increment = the first temperature only
            Params.TemperatureInc := 0;
          Run := TWhisperRun.Create(Model, Params);
          try
            Run.IncludeWords := True;
            Run.OnProgress := DiagProgress;
            TMonitor.Enter(Self);
            try
              FDiagRun := Run;
            finally
              TMonitor.Exit(Self);
            end;
            Status(Format('Diagnostics: %s, run %d of %d - %s ...', [ExtractFileName(AModelFile), I + 1, RUN_COUNT,
              RUN_NAMES[I]]));
            FDiagBase := 100 * (AIndex * RUN_COUNT + I) / FDiagRuns;
            FDiagWindows := nil;
            FDiagSample := 0;
            FDiagEncode := 0;
            FDiagDecode := 0;
            FDiagDecodeRuns := 0;
            if Assigned(Lib.Flat.whisper_reset_timings) then
              Lib.Flat.whisper_reset_timings(Model.Handle);
            FDiagTick := Now;
            R := Run.Execute(Samples);
            if Assigned(Lib.Flat.whisper_print_timings) then
            begin
              DebugLog(Format('timings: diagnostics run %d of %d, %s', [I + 1, RUN_COUNT, RUN_NAMES[I]]));
              Lib.Flat.whisper_print_timings(Model.Handle);
            end;
          finally
            TMonitor.Enter(Self);
            try
              FDiagRun := nil;
            finally
              TMonitor.Exit(Self);
            end;
            Run.Free;
          end;
        finally
          FreeAndNil(Params);
        end;
        if R.Cancelled or Terminated then
          Break;
        if R.ResultCode <> 0 then
        begin
          Log(Format('  %d of %d - %s: FAILED - %s', [I + 1, RUN_COUNT, RUN_NAMES[I], OneLine(R.ErrorMessage)]));
          Continue;
        end;
        Taken := R.ElapsedMs / 1000;
        if Taken <= 0 then
          Taken := 0.001;
        Took[I] := Taken;
        // the windows' times in order of size: the middle one, the slowest,
        // and how many stand out
        Sorted := Copy(FDiagWindows);
        for J := 1 to Length(Sorted) - 1 do
        begin
          Held := Sorted[J];
          K := J - 1;
          while (K >= 0) and (Sorted[K] > Held) do
          begin
            Sorted[K + 1] := Sorted[K];
            Dec(K);
          end;
          Sorted[K + 1] := Held;
        end;
        Median := 0;
        Slowest := 0;
        Fastest := 0;
        Slow := 0;
        if Length(Sorted) > 0 then
        begin
          Fastest := Sorted[0];
          Median := Sorted[Length(Sorted) div 2];
          Slowest := Sorted[Length(Sorted) - 1];
          for J := 0 to Length(Sorted) - 1 do
            if Sorted[J] > 2 * Median then
              Inc(Slow);
        end;
        Log(Format('  %d of %d - %s: %.1f s = %.1fx real time, %d words', [I + 1, RUN_COUNT, RUN_NAMES[I], Taken,
          Seconds / Taken, Length(R.Words)]));
        Log(Format('      windows that failed a check: %d probability, %d entropy%s', [FDiagFailP - FailP0,
          FDiagFailH - FailH0, IfThen(NoFallback, ' (counted, not decoded again)', ' (each decoded again)')]));
        if I = 0 then
          Fails := (FDiagFailP - FailP0) + (FDiagFailH - FailH0);
        Log(Format('      encoder %.1f s, decoder %.1f s in %d runs, sampling %.1f s, the rest (DTW, word ' +
          'times, copying) %.1f s', [FDiagEncode / 1000, FDiagDecode / 1000, FDiagDecodeRuns, FDiagSample / 1000,
          Taken - (FDiagEncode + FDiagDecode + FDiagSample) / 1000]));
        Log(Format('      %d windows: the fastest took %.2f s, the middle one %.2f s, the slowest %.2f s, %d ' +
          'took more than twice the middle one', [Length(Sorted), Fastest, Median, Slowest, Slow]));
        // how much of the text was heard right: the text's words from the
        // first to the last one matched (the recording stops part way
        // through the text, and starts with words that are not in it)
        if (Length(Reference) > 0) and (Length(R.Words) > 0) then
          try
            Aligned := WhisperAlignText(Reference, R.Words, Stats);
            FirstRead := -1;
            LastRead := -1;
            for J := 0 to Length(Aligned) - 1 do
              if Aligned[J].Match in [wamExact, wamSimilar] then
              begin
                if FirstRead < 0 then
                  FirstRead := J;
                LastRead := J;
              end;
            NGood := 0;
            NSame := 0;
            NRead := 0;
            if FirstRead >= 0 then
              for J := FirstRead to LastRead do
                if Aligned[J].Match <> wamNone then
                begin
                  Inc(NRead);
                  if Aligned[J].Match = wamExact then
                    Inc(NSame);
                  if Aligned[J].Match in [wamExact, wamSimilar] then
                    Inc(NGood);
                end;
            if NRead > 0 then
            begin
              Score[I] := NGood * 100 / NRead;
              Log(Format('      against the text: word %d of it was reached; of the %d read, %.1f %% heard ' +
                'exactly, %.1f %% exactly or nearly, %d not', [LastRead + 1, NRead, NSame * 100 / NRead, Score[I],
                NRead - NGood]));
            end
            else
              Log('      against the text: none of its words were heard');
          except
            on E: Exception do
              Log('      against the text: not measured - ' + E.Message);
          end;
        FailP0 := FDiagFailP;
        FailH0 := FDiagFailH;
      end;
      if Terminated then
        Exit;
      if (Took[0] > 0) and (Took[1] > 0) then
        Log(Format('The fallback costs %.1f s of the build''s %.1f s (%.0f %%): run 1 against run 2.',
          [Took[0] - Took[1], Took[0], 100 * (Took[0] - Took[1]) / Took[0]]));
      if (Took[0] > 0) and (Took[2] > 0) then
        Log(Format('DTW costs %.1f s of the build''s %.1f s (%.0f %%): run 1 against run 3.',
          [Took[0] - Took[2], Took[0], 100 * (Took[0] - Took[2]) / Took[0]]));
      if (Took[0] > 0) and (Took[3] > 0) then
        Log(Format('Without either: %.1fx real time (run 4), against %.1fx as a build (run 1).',
          [Seconds / Took[3], Seconds / Took[0]]));
      Log('Two runs of the same thing differ by a few per cent: a smaller cost than that is none.');
      if (Score[0] >= 0) and (Score[1] >= 0) then
        Log(Format('The fallback''s worth: %.1f %% of the text heard exactly or nearly with it (run 1), %.1f %% ' +
          'without (run 2). "Reached" far short of the other runs'' means text was dropped at the end.',
          [Score[0], Score[1]]));
      if Took[0] > 0 then
      begin
        ALine := Format('  %s: as a build %.1fx', [ExtractFileName(AModelFile), Seconds / Took[0]]);
        if Took[1] > 0 then
          ALine := ALine + Format(', no fallback %.1fx', [Seconds / Took[1]]);
        ALine := ALine + Format('; %d failed checks', [Fails]);
        if (Score[0] >= 0) and (Score[1] >= 0) then
          ALine := ALine + Format('; heard %.1f %% with the fallback, %.1f %% without', [Score[0], Score[1]]);
      end;
    finally
      FreeAndNil(Model);
    end;
  end;

begin
  FF := nil;
  Audio := nil;
  Files := nil;
  Table := nil;
  Model := nil;
  Params := nil;
  Reference := nil;
  AllDone := True;
  FDiagRuns := RUN_COUNT * FModels.Count;
  Lib := TWhisperLib.Instance;
  // whisper_print_timings writes to whisper.cpp's log: read from there
  Lib.AddLogListener(DiagLogLine);
  try
    try
      Status('Diagnostics: reading the recording ...');
      FF := OpenBuilderFFmpeg;
      Files := TStringList.Create;
      Files.Add(FAudioFile);
      Table := TStringList.Create;
      Audio := TWhisperAudioSet.Create(FF, Files, False);
      Samples := Audio.Read(0);
      if Length(Samples) = 0 then
        raise EWhisperError.Create('The recording has no sound: ' + FAudioFile);
      // only chapter material: not the recording's first or last
      // DIAGNOSTIC_EDGE_SECONDS (a spoken introduction, a closing notice)
      Edge := DIAGNOSTIC_EDGE_SECONDS * WHISPER_SAMPLE_RATE;
      if Length(Samples) >= 2 * Edge + 2 * WHISPER_CHUNK_SIZE * WHISPER_SAMPLE_RATE then
      begin
        Samples := Copy(Samples, Edge, Min(Length(Samples) - 2 * Edge, DIAGNOSTIC_SECONDS * WHISPER_SAMPLE_RATE));
        Seconds := WhisperSamplesSeconds(Samples);
        Log(Format('Recording: %s, %s of it from %s (its first and last %d s are left out: Whisper may skip a ' +
          'spoken introduction or closing notice)', [FAudioFile, Hms(Seconds), Hms(DIAGNOSTIC_EDGE_SECONDS),
          DIAGNOSTIC_EDGE_SECONDS]));
      end
      else
      begin
        Seconds := WhisperSamplesSeconds(Samples);
        Log(Format('Recording: %s, all %s of it (too short to leave out its first and last %d s, which Whisper ' +
          'may skip: the figures are less sure)', [FAudioFile, Hms(Seconds), DIAGNOSTIC_EDGE_SECONDS]));
      end;
      Log(Format('%d runs of the same audio per model with a build''s settings (the book prompt, each 30 s window ' +
        'on its own, word times); the first pass only, not the second pass over gaps.', [RUN_COUNT]));
      // the text read is known only for the program's own recording
      if SameText(ExtractFileName(FAudioFile), CALIBRATION_AUDIO) then
        Reference := DiagReferenceWords
      else
        Log(Format('(No accuracy figures: the recording is not %s, whose text the program has.)',
          [CALIBRATION_AUDIO]));
      for M := 0 to FModels.Count - 1 do
      begin
        if Terminated then
          Break;
        // each model on its own device (the builder gives one per model)
        if M < Length(FDevices) then
          Dev := FDevices[M]
        else
          Dev := FDevices[0];
        try
          OneModel(M, FModels[M], Dev, Line);
          if Line <> '' then
            Table.Add(Line)
          else
            AllDone := False;
        except
          // a model that does not fit the device: the others are still run
          on E: Exception do
          begin
            AllDone := False;
            Line := Format('  %s: FAILED - %s', [ExtractFileName(FModels[M]), OneLine(E.Message)]);
            Log(Line);
            Table.Add(Line);
          end;
        end;
      end;
      if Terminated then
      begin
        Log('Diagnostics cancelled');
        Exit;
      end;
      Progress(100);
      if FModels.Count > 1 then
      begin
        Log('');
        Log(Format('Every model, over the same %s of audio:', [Hms(Seconds)]));
        for M := 0 to Table.Count - 1 do
          Log(Table[M]);
      end;
      FCompleted := AllDone;
      Status('Diagnostics done');
    except
      on E: Exception do
      begin
        Log('Diagnostics FAILED: ' + E.Message);
        Status('Diagnostics failed: ' + E.Message);
      end;
    end;
  finally
    Lib.RemoveLogListener(DiagLogLine);
    Model.Free;
    Table.Free;
    Audio.Free;
    Files.Free;
    FF.Free;
  end;
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
  if FDiagnostics then
  begin
    ExecuteDiagnostics;
    Exit;
  end;
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
