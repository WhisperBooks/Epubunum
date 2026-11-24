{ @abstract(EpubBuilder's calibration: which device transcribes fastest on
  this machine, model by model, measured once and kept in the settings.)

  whisper.cpp left alone takes the first GPU in ggml's list (CUDA before
  HIP before Vulkan), which is often not the fastest: the owner's RTX 5090
  laptop built Night Watch with large-v3 in 39:20 on CUDA0 (whisper.cpp's
  own choice) and in 29:16 on Vulkan; on a GTX 1650 Vulkan beat CUDA with
  base.en, and large-v3 does not fit its 4 GB at all. So (owner,
  2026-11-17): a calibration - TWhisperBenchmark on every device, one
  timed run of CALIBRATION_STRETCH_SECONDS of speech (the stretch: the
  clearest two minutes of the reference text's recording, in any section,
  30 s away from both of that section's ends - FindReferenceStretch; since
  zip 242 - CALIBRATION_METHOD 2 - the calibration was three runs of 30 s,
  which whisper.cpp encodes twice and in which a model's fallback retries
  never happen: it misranked the .en models and ran 1.2 - 1.6 times slower
  than a book), with the
  settings of a build (DTW word times, the book prompt, each window on its
  own) - and the fastest device made the model's device. Asked for once at
  start-up ("Do not show this again" stops that), again from Settings >
  Calibrate when the graphics card changes.

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
  Whisper.Types, Whisper.API, Whisper.Audio, Whisper.Core, Whisper.Words, Whisper.AudioSet,
  // TWhisperStringArray (ReferenceWords)
  Whisper.Align;

const
  { The settings' section of the calibration as a whole. }
  CAL_SECTION = 'Calibration';
  { Section of the pairs that ended the program (key: device + '@' +
    model file name, value: when). }
  CAL_CRASH_SECTION = 'Calibration crashes';
  { whisper.cpp's version of every calibration and score made before the
    programs kept it (all of them were this). }
  WHISPER_VERSION_FIRST = '1.9.5';
  { Timed runs per pair (the median counts): one run of a long stretch
    (zip 242; was 3 of 30 s). }
  CALIBRATION_RUNS = 1;
  { How the calibration times (kept as [Calibration] Method; a model's
    section keeps its stretch's length as Seconds): 1 = three runs of 30 s
    (none kept: before zip 242), 2 = one run of CALIBRATION_STRETCH_SECONDS
    of continuous speech. A calibration of an older method is offered
    again at start-up. }
  CALIBRATION_METHOD = 2;
  { The stretch of a calibration of method 1 (no Seconds key), s. }
  CALIBRATION_OLD_SECONDS = 30;
  { The folder of the reference texts' files (REFERENCE_TEXTS), looked for
    beside the program and in the folders above it. }
  REFERENCE_FOLDER = 'media';
  { Folders above the program's searched for REFERENCE_FOLDER (the
    repository's root from demos/EpubBuilder/<platform>/<config>). }
  REFERENCE_LEVELS = 5;
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
  { Seconds of the stretch the calibration times (FindReferenceStretch,
    TWhisperBenchmark.MaxSeconds): about four Whisper windows, continuous -
    a book's way (step 2, 2026-11-22; zip 205's plan). }
  CALIBRATION_STRETCH_SECONDS = 120;

type
  { A reference text: a public-domain recording and the EPUB of the text
    it reads, both in REFERENCE_FOLDER. The program times Whisper on the
    recording and scores what it heard against the book. Only chapter
    material counts: every section of a LibriVox recording opens and
    closes with a spoken notice, so the 30 s at both ends of a section are
    never timed or scored. }
  TReferenceText = record
    { The title, for the logs and the menus. }
    Title: string;
    { The recording's file name. }
    Audio: string;
    { The book's file name (an EPUB of the text the recording reads). }
    Book: string;
    { Where both come from, for the logs. }
    Source: string;
  end;

const
  { The reference texts. Their files may change: the program names them
    only here. }
  REFERENCE_TEXTS: array[0..1] of TReferenceText = (
    (Title: 'A Scandal in Bohemia'; Audio: 'ScandalBohemia_librivox.m4b'; Book: 'A_Scandal_in_Bohemia.epub';
     Source: 'Arthur Conan Doyle; LibriVox, read by Phil Chenevert; text: Project Gutenberg 1661, its first story'),
    (Title: 'A Christmas Carol'; Audio: 'AChristmasCarol_librivox.m4b'; Book: 'A_Christmas_Carol.epub';
     Source: 'Charles Dickens; LibriVox, read by Kyle M.; text: Project Gutenberg 46'));
  { The reference text the calibration and the diagnostics use (a short
    one). The benchmark offers every one of REFERENCE_TEXTS. }
  CALIBRATION_REFERENCE = 0;
  { The reference text of Benchmark Lite (short). }
  BENCHMARK_LITE_REFERENCE = 0;
  { The reference text of Benchmark Full (long). }
  BENCHMARK_FULL_REFERENCE = 1;
  { Seconds at both ends of every part (a LibriVox section) that a
    benchmark neither times nor scores. }
  BENCH_EDGE_SECONDS = DIAGNOSTIC_EDGE_SECONDS;
  { The benchmark's Quick model (owner 2026-11-21: base, the fast one). }
  BENCH_QUICK_MODEL = 'ggml-base.bin';
  { The benchmark's Detailed model (turbo, the accurate one). }
  BENCH_DETAILED_MODEL = 'ggml-large-v3-turbo.bin';

type
  { A calibration pair started (ASpeed < 0) or ended (ASpeed: x real
    time; 0 = failed or skipped): AModel and ADevice are indices of the
    calibration's models and devices. }
  TCalibrationPairEvent = reference to procedure(AModel, ADevice: Integer; ASpeed: Double);

  { How far the pair being timed is (owner, 2026-11-22: "If calibrating a
    very slow machine it can look like it's stuck"): AModel and ADevice as
    TCalibrationPairEvent's, APhase what it does ('Loading the model onto',
    'Warming up on', 'Timing on' - the device's name follows), APercent of
    the pair (TWhisperBenchmark.OnProgress's estimate). }
  TCalibrationStepEvent = reference to procedure(AModel, ADevice: Integer; const APhase: string;
    APercent: Integer);

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
    { Receives each pair's start and end (on the main thread). }
    FOnPair: TCalibrationPairEvent;
    { Receives how far the pair being timed is (on the main thread). }
    FOnStep: TCalibrationStepEvent;
    { The pair being timed: its model, its device (indices), how many pairs
      were done before it and how many there are (BenchProgress). }
    FStepModel: Integer;
    { See FStepModel. }
    FStepDevice: Integer;
    { See FStepModel. }
    FStepDone: Integer;
    { See FStepModel. }
    FStepTotal: Integer;
    { Sends AText to OnLog. }
    procedure Log(const AText: string);
    { Sends a pair's start (ASpeed < 0) or end (ASpeed: x real time, 0 =
      failed or skipped) to OnPair: model AModel, device ADevice (indices
      of the models and devices given to Create). }
    procedure Pair(AModel, ADevice: Integer; ASpeed: Double);
    { Sends APercent to OnProgress. }
    procedure Progress(APercent: Double);
    { The benchmark's progress within a pair (TWhisperBenchmark.OnProgress,
      on this thread): to OnStep, and the whole calibration's to
      OnProgress. }
    procedure BenchProgress(Sender: TObject; APhase: TWhisperBenchmarkPhase; APercent: Integer);
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
    { Each model / device pair of the calibration as it starts and ends
      (the calibration's progress view; not called by the diagnostics). }
    property OnPair: TCalibrationPairEvent read FOnPair write FOnPair;
    { How far the pair being timed is: its phase and percentage, as the
      benchmark reports them (between OnPair's start and end; not called
      by the diagnostics). }
    property OnStep: TCalibrationStepEvent read FOnStep write FOnStep;
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

{ whisper.cpp's version as scores and calibrations are told apart by it:
  the three numbers of the library's own text ('1.9.6' of '1.9.6', of
  'v1.9.6' and of '1.9.6-dev').
  @param(AText the library's version)
  @returns(the numbers, '' when AText does not begin with three) }
function WhisperVersionNumbers(const AText: string): string;

{ The calibration belongs to ONE version of whisper.cpp: a new version
  can be faster or slower on the same device, so what an older one timed
  is not used (owner, 2026-11-24: "the leaderboard etc need to be version
  aware"). Called once the library is loaded. When the settings'
  calibration is of another version ([Calibration] Whisper; none written
  = WHISPER_VERSION_FIRST, which every calibration before this was), its
  model sections are put aside as "Whisper <that version> Calibration
  <model>" and [Calibration] Done is cleared - the program then finds no
  calibration and asks for one, as on a new machine. Sections kept
  earlier for AVersion are brought back (the library changed back), and
  Done is set again.
  @param(AIniFile the settings)
  @param(AVersion the library's version (WhisperVersionNumbers); '' does
    nothing)
  @param(ARestored a calibration kept for AVersion was brought back)
  @returns(True when a calibration of another version was put aside) }
function CalibrationForWhisper(const AIniFile, AVersion: string; out ARestored: Boolean): Boolean;

{ A model's calibration belongs to the encoder that ran it: with its Core
  ML encoder beside it (a Mac, a Core ML build) a model runs at another
  speed on the same device than without (owner, 2026-11-24: "coreml is
  different speed from Metal"; asked whether the calibration should be
  split by it too: "yes"). Each model section keeps CoreML = 1 / 0. A
  section whose value is not what AUses says now - an encoder downloaded
  since, or taken away - is put aside as "Core ML on Calibration <model>"
  / "Core ML off Calibration <model>", and the one kept for the state now
  is brought back; the model then counts as not calibrated (a model
  without a calibration is calibrated as it comes) or has its own figures
  again. A section without the value gets the state now (it was made
  before the value was kept; what it ran with is not known).
  @param(AIniFile the settings)
  @param(ACoreMLBuild whisper.cpp is a Core ML build: only then is the
    value written into sections that have none (nothing is written on a
    machine that has no Core ML))
  @param(AUses whether the model of that file name uses its Core ML
    encoder now)
  @returns(the file names of the models whose calibration was put aside) }
function CalibrationForEncoders(const AIniFile: string; ACoreMLBuild: Boolean;
  const AUses: TFunc<string, Boolean>): TArray<string>;

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

{ The length of the stretch AModelFile's calibration timed (its section's
  Seconds; CALIBRATION_OLD_SECONDS for a calibration before zip 242).
  @returns(s; 0 when the model is not calibrated) }
function CalibrationSeconds(const AIniFile, AModelFile: string): Double;

{ The method of the calibration kept ([Calibration] Method; 1 before zip
  242).
  @returns(the method; 0 when there is no calibration) }
function CalibrationMethod(const AIniFile: string): Integer;

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

{ A file of the reference texts: (macOS) the bundle's
  Contents/Resources/REFERENCE_FOLDER/AName, else REFERENCE_FOLDER/AName
  beside the program or in a folder up to REFERENCE_LEVELS above it.
  @returns('' when there is none) }
function FindReferenceFile(const AName: string): string;

{ The recording of reference text AIndex (REFERENCE_TEXTS).
  @returns('' when it is not there) }
function ReferenceAudio(AIndex: Integer): string;

{ The reference text whose recording AAudioFile is (by file name).
  @returns(its index in REFERENCE_TEXTS; -1 for any other recording) }
function ReferenceIndexOf(const AAudioFile: string): Integer;

{ The words of reference text AIndex as the aligner wants them: its
  book's words in reading order (the contents page left out), each split
  at dashes (WhisperSplitBookWords). AError receives why there are none.
  @returns(the words; empty when the book is not there or cannot be read) }
function ReferenceWords(AIndex: Integer; out AError: string): TWhisperStringArray;

{ The chapter material the calibration and the diagnostics time: the
  first section (a chapter of the file) at least AMinSeconds long plus
  the 30 s at both of its ends, else the longest section; a file without
  chapters is one section. Read whole: the caller keeps away from its
  ends. ANote receives which section it is, for the log.
  @returns(the section's samples) }
function ReadReferenceSection(AFFmpeg: TFFmpegLibrary; const AAudioFile: string; AMinSeconds: Double;
  out ANote: string): TWhisperSamples;

{ The calibration's stretch: the ASeconds of AAudioFile with the most
  sound - the fewest quiet 100 ms frames, judged against the loudness of
  the whole recording (as WhisperFindSpeech judges) - in any section (a
  chapter of the file), 30 s (DIAGNOSTIC_EDGE_SECONDS) away from both of
  that section's ends; the earliest of equals. The whole recording is
  decoded once to choose it.
  @param(ASamples  receives the chosen section's samples)
  @param(AStart  receives where the stretch starts in that section, s)
  @param(AShare  receives the stretch's share of sound, 0 .. 1)
  @param(ANote  receives the section and the stretch's place, for the log)
  @returns(False when no section is long enough: ASamples is then the
    longest section and AStart -1 - the benchmark chooses in it) }
function FindReferenceStretch(AFFmpeg: TFFmpegLibrary; const AAudioFile: string; ASeconds: Double;
  out ASamples: TWhisperSamples; out AStart, AShare: Double; out ANote: string): Boolean;

{ The calibration's recording: the reference text's (CALIBRATION_REFERENCE)
  when it is there, else ASaved (one chosen by the user before) when that
  exists.
  @returns('' when there is none) }
function FindCalibrationAudio(const ASaved: string): string;

{ The start-up question: why to calibrate, Start calibration / Cancel and
  "Do not show this again". Modal.
  @param(AOwner  the window it is centred on)
  @param(AText  the explanation)
  @param(ADontAsk  receives the check box)
  @returns(True for Start calibration) }
function AskCalibration(AOwner: TComponent; const AText: string; out ADontAsk: Boolean): Boolean;

{ Settings > Build history: the history (uHistory) as a table, newest first,
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
  // the reference texts' books (the diagnostics' accuracy)
  Epub.Book, Epub.Layout,
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
    '(Settings > Calibrate tries it again)';

{ The settings' section of AModelFile. }
function ModelSection(const AModelFile: string): string;
begin
  Result := CAL_SECTION + ' ' + ExtractFileName(AModelFile);
end;

function WhisperVersionNumbers(const AText: string): string;
var
  S: string;
  I, Dots, Digits: Integer;
begin
  Result := '';
  S := Trim(AText);
  if (S <> '') and CharInSet(S[1], ['v', 'V']) then
    Delete(S, 1, 1);
  Dots := 0;
  Digits := 0;
  I := 1;
  while I <= Length(S) do
  begin
    if CharInSet(S[I], ['0'..'9']) then
      Inc(Digits)
    else if (S[I] = '.') and (Digits > 0) and (Dots < 2) then
    begin
      Inc(Dots);
      Digits := 0;
    end
    else
      Break;
    Inc(I);
  end;
  // three numbers, the last with a digit
  if (Dots = 2) and (Digits > 0) then
    Result := Copy(S, 1, I - 1);
end;

{ AFrom's keys under ATo in AIni (what ATo held is gone); AFrom gone. }
procedure MoveIniSection(AIni: TMemIniFile; const AFrom, ATo: string);
var
  Keys: TStringList;
  K: Integer;
begin
  Keys := TStringList.Create;
  try
    AIni.ReadSection(AFrom, Keys);
    AIni.EraseSection(ATo);
    for K := 0 to Keys.Count - 1 do
      AIni.WriteString(ATo, Keys[K], AIni.ReadString(AFrom, Keys[K], ''));
    AIni.EraseSection(AFrom);
  finally
    Keys.Free;
  end;
end;

function CalibrationForEncoders(const AIniFile: string; ACoreMLBuild: Boolean;
  const AUses: TFunc<string, Boolean>): TArray<string>;
const
  { A section put aside: 'Core ML on Calibration <file>'. }
  KEPT_ON = 'Core ML on ';
  KEPT_OFF = 'Core ML off ';
var
  Ini: TMemIniFile;
  Sections: TStringList;
  Model, S, FileName, Was, Aside, Back: string;
  I: Integer;
  Now1, Changed: Boolean;
begin
  Result := nil;
  if not FileExists(AIniFile) or not Assigned(AUses) then
    Exit;
  Model := CAL_SECTION + ' ';
  Changed := False;
  Ini := TMemIniFile.Create(AIniFile, TEncoding.UTF8);
  Sections := TStringList.Create;
  try
    Ini.ReadSections(Sections);
    for I := 0 to Sections.Count - 1 do
    begin
      S := Sections[I];
      if not StartsText(Model, S) or SameText(S, CAL_CRASH_SECTION) then
        Continue;
      FileName := Copy(S, Length(Model) + 1, MaxInt);
      Now1 := AUses(FileName);
      Was := Ini.ReadString(S, 'CoreML', '');
      if Was = '' then
      begin
        // made before the value was kept: taken for the state now
        if ACoreMLBuild then
        begin
          Ini.WriteString(S, 'CoreML', IfThen(Now1, '1', '0'));
          Changed := True;
        end;
        Continue;
      end;
      if (Was = '1') = Now1 then
        Continue;
      // the encoder came or went: this calibration is the other state's
      Aside := IfThen(Was = '1', KEPT_ON, KEPT_OFF) + S;
      Back := IfThen(Now1, KEPT_ON, KEPT_OFF) + S;
      MoveIniSection(Ini, S, Aside);
      if Ini.SectionExists(Back) then
        MoveIniSection(Ini, Back, S);
      Result := Result + [FileName];
      Changed := True;
    end;
    if Changed then
      Ini.UpdateFile;
  finally
    Sections.Free;
    Ini.Free;
  end;
end;

function CalibrationForWhisper(const AIniFile, AVersion: string; out ARestored: Boolean): Boolean;
var
  Ini: TMemIniFile;
  Sections: TStringList;
  Was, Model, Kept, S: string;
  I: Integer;
begin
  Result := False;
  ARestored := False;
  if (AVersion = '') or not FileExists(AIniFile) then
    Exit;
  // a model's section: 'Calibration <file>'; one put aside: 'Whisper
  // <version> Calibration <file>'
  Model := CAL_SECTION + ' ';
  Kept := 'Whisper ' + AVersion + ' ' + Model;
  Ini := TMemIniFile.Create(AIniFile, TEncoding.UTF8);
  Sections := TStringList.Create;
  try
    Ini.ReadSections(Sections);
    Was := Ini.ReadString(CAL_SECTION, 'Whisper', '');
    if Was = '' then
    begin
      // none written: a calibration that is there was made before the
      // version was kept; none there - nothing to tell apart
      Was := AVersion;
      for I := 0 to Sections.Count - 1 do
        if StartsText(Model, Sections[I]) and not SameText(Sections[I], CAL_CRASH_SECTION) then
          Was := WHISPER_VERSION_FIRST;
    end;
    if Was <> AVersion then
    begin
      Result := True;
      for I := 0 to Sections.Count - 1 do
      begin
        S := Sections[I];
        if StartsText(Model, S) and not SameText(S, CAL_CRASH_SECTION) then
          MoveIniSection(Ini, S, 'Whisper ' + Was + ' ' + S);
      end;
      for I := 0 to Sections.Count - 1 do
      begin
        S := Sections[I];
        if StartsText(Kept, S) then
        begin
          MoveIniSection(Ini, S, Copy(S, Length(Kept) - Length(Model) + 1, MaxInt));
          ARestored := True;
        end;
      end;
      Ini.WriteBool(CAL_SECTION, 'Done', ARestored);
    end;
    if Ini.ReadString(CAL_SECTION, 'Whisper', '') <> AVersion then
    begin
      Ini.WriteString(CAL_SECTION, 'Whisper', AVersion);
      Ini.UpdateFile;
    end;
  finally
    Sections.Free;
    Ini.Free;
  end;
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
        // the stretch's length: like is compared with like (uHistory)
        Ini.WriteInteger(ModelSection(Model), 'Seconds', CALIBRATION_STRETCH_SECONDS);
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
    Ini.WriteInteger(CAL_SECTION, 'Method', CALIBRATION_METHOD);
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

function CalibrationSeconds(const AIniFile, AModelFile: string): Double;
var
  Ini: TMemIniFile;
begin
  Result := 0;
  if (AModelFile = '') or not FileExists(AIniFile) then
    Exit;
  Ini := TMemIniFile.Create(AIniFile, TEncoding.UTF8);
  try
    if Ini.ReadString(ModelSection(AModelFile), 'Made', '') <> '' then
      Result := Ini.ReadInteger(ModelSection(AModelFile), 'Seconds', CALIBRATION_OLD_SECONDS);
  finally
    Ini.Free;
  end;
end;

function CalibrationMethod(const AIniFile: string): Integer;
var
  Ini: TMemIniFile;
begin
  Result := 0;
  if not FileExists(AIniFile) then
    Exit;
  Ini := TMemIniFile.Create(AIniFile, TEncoding.UTF8);
  try
    if Ini.ReadBool(CAL_SECTION, 'Done', False) then
      Result := Ini.ReadInteger(CAL_SECTION, 'Method', 1);
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
    'offered now leaves it out; Settings > Calibrate tries it again.', [Model, Device]);
end;

function FindReferenceFile(const AName: string): string;
var
  Dir: string;
  I: Integer;
begin
  Dir := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  {$IFDEF MACOS}
  // the bundle's Contents/Resources/media (Dir is Contents/MacOS), where
  // Deploy and tools/redist.sh deploy put them
  Result := TPath.Combine(TPath.Combine(TPath.Combine(ExtractFileDir(Dir), 'Resources'), REFERENCE_FOLDER), AName);
  if FileExists(Result) then
    Exit;
  {$ENDIF}
  for I := 0 to REFERENCE_LEVELS do
  begin
    Result := TPath.Combine(TPath.Combine(Dir, REFERENCE_FOLDER), AName);
    if FileExists(Result) then
      Exit;
    if ExtractFileDir(Dir) = Dir then
      Break;
    Dir := ExtractFileDir(Dir);
  end;
  Result := '';
end;

function ReferenceAudio(AIndex: Integer): string;
begin
  Result := FindReferenceFile(REFERENCE_TEXTS[AIndex].Audio);
end;

function ReferenceIndexOf(const AAudioFile: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(REFERENCE_TEXTS) do
    if SameText(ExtractFileName(AAudioFile), REFERENCE_TEXTS[I].Audio) then
      Exit(I);
  Result := -1;
end;

function ReferenceWords(AIndex: Integer; out AError: string): TWhisperStringArray;
var
  FileName: string;
  Book: TEpubBook;
  BookWords: TEpubWordArray;
  Given: TWhisperStringArray;
  Map: TWhisperIndexArray;
  I, N: Integer;
begin
  Result := nil;
  AError := '';
  FileName := FindReferenceFile(REFERENCE_TEXTS[AIndex].Book);
  if FileName = '' then
  begin
    AError := Format('%s/%s was not found beside the program', [REFERENCE_FOLDER, REFERENCE_TEXTS[AIndex].Book]);
    Exit;
  end;
  try
    Book := TEpubBook.Create(FileName);
    try
      // as a build reads a book: every word but the contents page's (the
      // front and back matter - Project Gutenberg's notices - stay, and
      // are never reached: the figures count from the first word matched
      // to the last)
      BookWords := Book.Words;
      SetLength(Given, Length(BookWords));
      N := 0;
      for I := 0 to High(BookWords) do
        if BookWords[I].Role <> ewrNav then
        begin
          Given[N] := BookWords[I].Text;
          Inc(N);
        end;
      SetLength(Given, N);
    finally
      Book.Free;
    end;
    Result := WhisperSplitBookWords(Given, Map);
    if Length(Result) = 0 then
      AError := FileName + ' has no words';
  except
    on E: Exception do
    begin
      Result := nil;
      AError := FileName + ' cannot be read: ' + E.Message;
    end;
  end;
end;

function ReadReferenceSection(AFFmpeg: TFFmpegLibrary; const AAudioFile: string; AMinSeconds: Double;
  out ANote: string): TWhisperSamples;
var
  Files: TStringList;
  Audio: TWhisperAudioSet;
  I, Pick: Integer;
begin
  Files := TStringList.Create;
  Audio := nil;
  try
    Files.Add(AAudioFile);
    // a LibriVox book's sections are the file's chapters
    Audio := TWhisperAudioSet.Create(AFFmpeg, Files, True);
    Pick := -1;
    for I := 0 to High(Audio.Parts) do
      if Audio.Parts[I].Duration >= AMinSeconds + 2 * DIAGNOSTIC_EDGE_SECONDS then
      begin
        Pick := I;
        Break;
      end;
    if Pick < 0 then
    begin
      // none long enough: the longest
      Pick := 0;
      for I := 1 to High(Audio.Parts) do
        if Audio.Parts[I].Duration > Audio.Parts[Pick].Duration then
          Pick := I;
    end;
    Result := Audio.Read(Pick);
    if Length(Audio.Parts) > 1 then
      ANote := Format('section %d of %d, "%s" (%s - %s of the file)', [Pick + 1, Length(Audio.Parts),
        Audio.Parts[Pick].Title, Hms(Audio.Parts[Pick].Start), Hms(Audio.Parts[Pick].Start +
        WhisperSamplesSeconds(Result))])
    else
      ANote := 'one section (the file has no chapters)';
  finally
    Audio.Free;
    Files.Free;
  end;
end;

function FindReferenceStretch(AFFmpeg: TFFmpegLibrary; const AAudioFile: string; ASeconds: Double;
  out ASamples: TWhisperSamples; out AStart, AShare: Double; out ANote: string): Boolean;
const
  { Samples per frame (100 ms), as WhisperFindSpeech. }
  FRAME = WHISPER_SAMPLE_RATE div 10;
  { Histogram bins for the loudness percentile, as WhisperFindSpeech. }
  BINS = 1000;
var
  Files: TStringList;
  Audio: TWhisperAudioSet;
  Levels: array of TArray<Single>;
  Hist: array of Integer;
  S: TWhisperSamples;
  Sum, Top, Threshold: Double;
  P, I, J, NFrames, Total, W, Edge, Quiet, At, BestPart, BestAt, BestQuiet, Longest: Integer;
begin
  Result := False;
  ASamples := nil;
  AStart := -1;
  AShare := 0;
  ANote := '';
  W := Max(1, Round(ASeconds * 10));
  Edge := Round(DIAGNOSTIC_EDGE_SECONDS * 10);
  Files := TStringList.Create;
  Audio := nil;
  try
    Files.Add(AAudioFile);
    // a LibriVox book's sections are the file's chapters
    Audio := TWhisperAudioSet.Create(AFFmpeg, Files, True);
    // 1. the level of every 100 ms frame, section by section (one section's
    // samples in memory at a time)
    SetLength(Levels, Length(Audio.Parts));
    Top := 0;
    Total := 0;
    for P := 0 to High(Audio.Parts) do
    begin
      S := Audio.Read(P);
      NFrames := Length(S) div FRAME;
      SetLength(Levels[P], NFrames);
      for I := 0 to NFrames - 1 do
      begin
        Sum := 0;
        for J := I * FRAME to I * FRAME + FRAME - 1 do
          Sum := Sum + Sqr(S[J]);
        Levels[P][I] := Sqrt(Sum / FRAME);
        if Levels[P][I] > Top then
          Top := Levels[P][I];
      end;
      Inc(Total, NFrames);
      S := nil;
    end;
    // 2. quiet = under a tenth of the loud end (the 90th percentile) of
    // the whole recording, as WhisperFindSpeech decides
    SetLength(Hist, BINS);
    for P := 0 to High(Levels) do
      for I := 0 to High(Levels[P]) do
        Inc(Hist[Min(BINS - 1, Trunc(Levels[P][I] / Max(Top, 1E-9) * BINS))]);
    J := 0;
    I := 0;
    while (I < BINS - 1) and (J + Hist[I] < (Int64(Total) * 9) div 10) do
    begin
      Inc(J, Hist[I]);
      Inc(I);
    end;
    Threshold := Max(0.002, 0.1 * (I + 1) * Top / BINS);
    // 3. in every section long enough, the stretch with the fewest quiet
    // frames, kept 30 s away from the section's ends
    BestPart := -1;
    BestAt := 0;
    BestQuiet := MaxInt;
    for P := 0 to High(Levels) do
    begin
      NFrames := Length(Levels[P]);
      if NFrames < W + 2 * Edge then
        Continue;
      Quiet := 0;
      for I := Edge to Edge + W - 1 do
        if Levels[P][I] < Threshold then
          Inc(Quiet);
      At := Edge;
      while True do
      begin
        if Quiet < BestQuiet then
        begin
          BestQuiet := Quiet;
          BestPart := P;
          BestAt := At;
        end;
        if At >= NFrames - Edge - W then
          Break;
        if Levels[P][At] < Threshold then
          Dec(Quiet);
        if Levels[P][At + W] < Threshold then
          Inc(Quiet);
        Inc(At);
      end;
    end;
    if BestPart < 0 then
    begin
      // no section long enough: the longest, the benchmark chooses in it
      Longest := 0;
      for P := 1 to High(Audio.Parts) do
        if Length(Levels[P]) > Length(Levels[Longest]) then
          Longest := P;
      ASamples := Audio.Read(Longest);
      ANote := Format('section %d of %d, "%s" - no section is long enough to keep 30 s from both of its ends: ' +
        'the stretch is chosen in the longest', [Longest + 1, Length(Audio.Parts), Audio.Parts[Longest].Title]);
      Exit;
    end;
    // 4. the chosen section's samples
    ASamples := Audio.Read(BestPart);
    AStart := BestAt / 10;
    AShare := 1 - BestQuiet / W;
    Result := True;
    if Length(Audio.Parts) > 1 then
      ANote := Format('section %d of %d, "%s": %.0f s from %s into it (%s of the file), %.0f %% sound - the ' +
        'clearest %.0f s of the recording', [BestPart + 1, Length(Audio.Parts), Audio.Parts[BestPart].Title,
        ASeconds, Hms(AStart), Hms(Audio.Parts[BestPart].Start + AStart), AShare * 100, ASeconds])
    else
      ANote := Format('one section (the file has no chapters): %.0f s from %s, %.0f %% sound - the clearest ' +
        '%.0f s of the recording', [ASeconds, Hms(AStart), AShare * 100, ASeconds]);
  finally
    Audio.Free;
    Files.Free;
  end;
end;

function FindCalibrationAudio(const ASaved: string): string;
begin
  // the reference text first: a recording chosen before (when the
  // program had none, or an older one) is used only without it
  Result := ReferenceAudio(CALIBRATION_REFERENCE);
  if (Result = '') and (ASaved <> '') and FileExists(ASaved) then
    Result := ASaved;
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

procedure TCalibrationThread.BenchProgress(Sender: TObject; APhase: TWhisperBenchmarkPhase; APercent: Integer);
const
  { What each phase is called; the device's name follows. }
  PHASE_TEXT: array[TWhisperBenchmarkPhase] of string = ('Loading the model onto', 'Warming up on', 'Timing on');
var
  P: TCalibrationStepEvent;
  M, D: Integer;
  Text: string;
begin
  Progress(100 * (FStepDone + APercent / 100) / Max(1, FStepTotal));
  P := FOnStep;
  if not Assigned(P) then
    Exit;
  M := FStepModel;
  D := FStepDevice;
  Text := PHASE_TEXT[APhase];
  TThread.Queue(nil,
    procedure
    begin
      P(M, D, Text, APercent);
    end);
end;

procedure TCalibrationThread.Pair(AModel, ADevice: Integer; ASpeed: Double);
var
  P: TCalibrationPairEvent;
begin
  P := FOnPair;
  if Assigned(P) then
    TThread.Queue(nil,
      procedure
      begin
        P(AModel, ADevice, ASpeed);
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
  Table: TStringList;
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
  RefIndex: Integer;
  RefError, Section: string;
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
        Log(Format('The calibration timed it there at %.1fx real time (%.0f s of speech).', [Speed,
          CalibrationSeconds(FIniFile, ExtractFileName(AModelFile))]))
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
      Table := TStringList.Create;
      // one section of the recording (a LibriVox book's sections each
      // open and close with a spoken notice)
      Samples := ReadReferenceSection(FF, FAudioFile, DIAGNOSTIC_SECONDS, Section);
      if Length(Samples) = 0 then
        raise EWhisperError.Create('The recording has no sound: ' + FAudioFile);
      // only chapter material: not the section's first or last
      // DIAGNOSTIC_EDGE_SECONDS (a spoken introduction, a closing notice)
      Edge := DIAGNOSTIC_EDGE_SECONDS * WHISPER_SAMPLE_RATE;
      if Length(Samples) >= 2 * Edge + 2 * WHISPER_CHUNK_SIZE * WHISPER_SAMPLE_RATE then
      begin
        Samples := Copy(Samples, Edge, Min(Length(Samples) - 2 * Edge, DIAGNOSTIC_SECONDS * WHISPER_SAMPLE_RATE));
        Seconds := WhisperSamplesSeconds(Samples);
        Log(Format('Recording: %s, %s; %s of it from %s into the section (the first and last %d s of every ' +
          'section are left out: Whisper may skip a spoken introduction or closing notice)', [FAudioFile, Section,
          Hms(Seconds), Hms(DIAGNOSTIC_EDGE_SECONDS), DIAGNOSTIC_EDGE_SECONDS]));
      end
      else
      begin
        Seconds := WhisperSamplesSeconds(Samples);
        Log(Format('Recording: %s, %s; all %s of it (too short to leave out its first and last %d s, which ' +
          'Whisper may skip: the figures are less sure)', [FAudioFile, Section, Hms(Seconds),
          DIAGNOSTIC_EDGE_SECONDS]));
      end;
      Log(Format('%d runs of the same audio per model with a build''s settings (the book prompt, each 30 s window ' +
        'on its own, word times); the first pass only, not the second pass over gaps.', [RUN_COUNT]));
      // the text read is known only for a reference text's recording
      RefIndex := ReferenceIndexOf(FAudioFile);
      if RefIndex < 0 then
        Log('(No accuracy figures: the recording is not one of the reference texts.)')
      else
      begin
        Reference := ReferenceWords(RefIndex, RefError);
        if Length(Reference) > 0 then
          Log(Format('Reference text: %s (%s) - %d words to score against', [REFERENCE_TEXTS[RefIndex].Title,
            REFERENCE_TEXTS[RefIndex].Source, Length(Reference)]))
        else
          Log(Format('(No accuracy figures: the book of %s - %s.)', [REFERENCE_TEXTS[RefIndex].Title, RefError]));
      end;
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
    FF.Free;
  end;
end;

procedure TCalibrationThread.Execute;
var
  FF: TFFmpegLibrary;
  Samples: TWhisperSamples;
  Seconds: Double;
  CP: TWhisperContextParams;
  Params: TWhisperParams;
  Bench: TWhisperBenchmark;
  R: TWhisperBenchmarkResult;
  M, D, N, Total, B, I: Integer;
  Key, Line, Section: string;
  Start, Share: Double;
begin
  if FDiagnostics then
  begin
    ExecuteDiagnostics;
    Exit;
  end;
  FF := nil;
  Params := nil;
  Bench := nil;
  try
    try
      // the clearest 30 s of the recording, in any section, 30 s clear of
      // both of its ends (a LibriVox book's sections each open and close
      // with a spoken notice); the same stretch on every machine
      Status('Calibrating: reading the recording and choosing its clearest 30 s ...');
      FF := OpenBuilderFFmpeg;
      FindReferenceStretch(FF, FAudioFile, CALIBRATION_STRETCH_SECONDS, Samples, Start, Share, Section);
      Seconds := WhisperSamplesSeconds(Samples);
      if Length(Samples) = 0 then
        raise EWhisperError.Create('The recording has no sound: ' + FAudioFile);
      Log(Format('Recording: %s, %s', [FAudioFile, Section]));
      if ReferenceIndexOf(FAudioFile) >= 0 then
        Log(Format('Reference text: %s (%s)', [REFERENCE_TEXTS[ReferenceIndexOf(FAudioFile)].Title,
          REFERENCE_TEXTS[ReferenceIndexOf(FAudioFile)].Source]));
      if (Start < 0) and (Seconds < CALIBRATION_STRETCH_SECONDS + 2 * DIAGNOSTIC_EDGE_SECONDS) then
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
      Bench.MaxSeconds := CALIBRATION_STRETCH_SECONDS;
      // the stretch chosen above (-1: the benchmark chooses)
      Bench.StartSeconds := Start;
      Bench.Params := Params;
      Bench.ContextParams := CP;
      Bench.Runs := CALIBRATION_RUNS;
      // each pair's phase and percentage: the bars move while a slow machine
      // times a pair (owner, 2026-11-22)
      Bench.OnProgress := BenchProgress;
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
          Status(Format('Calibrating: %s on %s (%d of %d; loading, a warm-up and %d s of speech timed) ...',
            [ExtractFileName(FModels[M]), FDevices[D].Name, N + 1, Total, CALIBRATION_STRETCH_SECONDS]));
          Key := ExtractFileName(FModels[M]) + #9 + FDevices[D].Name;
          Pair(M, D, -1);
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
            FStepModel := M;
            FStepDevice := D;
            FStepDone := N;
            FStepTotal := Total;
            R := Bench.RunOne(FModels[M], FDevices[D]);
            System.SysUtils.DeleteFile(FMarkerFile);
            // cancelled mid-run: not a result
            if Terminated and not R.Ok then
              Break;
            if R.Ok then
            begin
              // the share of sound: the Recording line's when the stretch was
              // chosen above (the benchmark's own figure is judged against
              // the stretch alone, not the recording)
              Log(Format('  %s: %.1fx real time (%s of %.0f s from %s into the section%s; ' +
                'loading %.1f s, warm-up %.1f s, %d threads)', [WhisperDeviceText(R.Device), R.Speed,
                IfThen(R.Runs = 1, 'one run', Format('median of %d runs', [R.Runs])), R.AudioSeconds,
                Hms(R.StartSeconds), IfThen(Start < 0, Format(', %.0f %% sound', [R.SpeechShare * 100]), ''),
                R.LoadMs / 1000, R.WarmupMs / 1000, R.Threads]));
              DebugLog('calibration text: ' + R.Text);
            end
            else
              Log(Format('  %s: FAILED - %s', [WhisperDeviceText(R.Device), OneLine(R.ErrorMessage)]));
          end;
          FResults := FResults + [R];
          if R.Ok then
            Pair(M, D, R.Speed)
          else
            Pair(M, D, 0);
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
    FF.Free;
  end;
end;

end.
