{ @abstract(EpubBuilder's window: the EPUB on the left, its audio files on
  the right, the model, device and output file below, Create.)

  The work runs on a TBuildThread: read the book's words, transcribe the
  audio part by part (or read a transcript saved by an earlier run),
  align, write the book with media overlays. The window is built in code
  (as EpubReader's tool bar): uBuilder.fmx only holds the form. }
unit uBuilder;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math, System.StrUtils,
  System.DateUtils, System.IOUtils, System.IniFiles, System.JSON,
  // TJSONArray's inline getters expand only with it (H2443)
  System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.DialogService, FMX.DialogService.Sync, FMX.StdCtrls, FMX.Layouts,
  FMX.ListBox, FMX.Edit, FMX.Memo, FMX.Memo.Types, FMX.ScrollBox, FMX.Controls.Presentation, FMX.Menus,
  Epub.Zip, Epub.Book, Epub.Layout, Epub.Writer, Epub.Mobi,
  FFmpeg.API, FFmpeg.Media,
  Whisper.Types, Whisper.API, Whisper.Audio, Whisper.Core, Whisper.Words, Whisper.Align, Whisper.AudioSet,
  uDebugLog, uMachine, uCalibration, uHistory, uModels, uSteam, uSteamBoard, uInhibit, uQuitSignal, uSteamPad,
  uPadMenu, uCards,
  uRedraw, uLink, uCovers, uCoverPick, uEpubUnum, uBenchProgress, uMacWindow;

type
  { Audio for a book, offered in Big Picture: one file, or a folder's
    files in name order, and how well its name matches the book's. }
  TPadAudio = record
    { What the list shows: the file's or the folder's path in the audio
      folder. }
    Name: string;
    { The files, in reading order. }
    Files: TArray<string>;
    { 0 (nothing in common) .. 1 (every word of the book's title). }
    Score: Double;
  end;

  { The figures of one build, for the queue's report (filled by the
    thread as it goes; read in BuildDone). }
  TBuildSummary = record
    { Length of the audio, s. }
    AudioSeconds: Double;
    { Audio files. }
    Files: Integer;
    { Parts (chapters of the files, or the files). }
    Parts: Integer;
    { A saved transcript was used (no transcription). }
    SavedTranscript: Boolean;
    { Time the transcription took, s (0 with a saved transcript). }
    TranscribeSeconds: Double;
    { The model (file name; a saved transcript's own when it names one). }
    Model: string;
    { The device used, by name: whisper.cpp's default is resolved to the
      device it takes (owner: CUDA chosen by "Default" was not visible in
      the logs). }
    Device: string;
    { The device in words (WhisperDeviceText: name, card, backend, memory). }
    DeviceText: string;
    { The machine (MachineText: name, system, processor, memory). }
    Machine: string;
    { The language transcribed ('' = not given). }
    Language: string;
    { The book's title. }
    Title: string;
    { Words Whisper heard. }
    HeardWords: Integer;
    { The aligner's figures. }
    Stats: TWhisperAlignStats;
    { Not spoken words that are front and back matter. }
    EdgeWords: Integer;
    { Share of the timed words matched to what was heard, %. }
    Matched: Double;
    { 'very good', 'good', 'usable', 'poor' ('' = not aligned). }
    Verdict: string;
    { Clips written. }
    Clips: Integer;
    { Timed words the writer left out. }
    LeftOut: Integer;
    { Chapter marks written. }
    ChapterMarks: Integer;
    { The book was EPUB 2 and is EPUB 3 now. }
    Upgraded: Boolean;
    { Why it failed ('' = it did not). }
    Error: string;
    { The diagnostic switches the build ran with, in words ('' = none: a
      normal build - BuildDiagnostics). A diagnostic build is not kept in
      the build history: its speed is not a build's. }
    Diagnostic: string;
    { A benchmark's build (TBuildThread.Benchmark): the figures below are
      of chapter material only - every part (a LibriVox section) without
      its first and last BENCH_EDGE_SECONDS. }
    Benchmark: Boolean;
    { Benchmark: seconds of chapter material transcribed and timed. }
    BenchAudioSeconds: Double;
    { Benchmark: the time its transcription took (the first pass and the
      second over gaps; the time asleep not counted), s. }
    BenchSeconds: Double;
    { Benchmark: book words timed inside the chapter material (as the
      aligner counts words: split at dashes). }
    BenchWords: Integer;
    { Benchmark: of BenchWords, those heard exactly or nearly as the book
      has them. }
    BenchMatched: Integer;
  end;

  { Builds one read-along EPUB on its own thread. Messages and progress
    reach the window through TThread.Queue. }
  TBuildThread = class(TThread)
  private
    { The EPUB to read. }
    FBookFile: string;
    { The audio files, in reading order. }
    FAudioFiles: TStringList;
    { The Whisper model (ggml-*.bin). }
    FModelFile: string;
    { Device name ('' = whisper.cpp's default). }
    FDevice: string;
    { The EPUB to write. }
    FOutFile: string;
    { The transcript kept beside the output (JSON, with the parts). }
    FJsonFile: string;
    { Chapters of an audio file are parts of their own. }
    FChapters: Boolean;
    { Read FJsonFile instead of transcribing when it fits the audio. }
    FReuse: Boolean;
    { The language to transcribe in, whatever the book says ('' = the
      book's own). }
    FForceLanguage: string;
    { The saved transcript's model (file name; '' = not recorded: made
      before the builder recorded it), read by ReadSaved. }
    FSavedModel: string;
    { When the saved transcript was made ('' = not recorded). }
    FSavedMade: string;
    { The book's language ('de'; '' = not given): the language Whisper is
      told, and the prompt's. }
    FLanguage: string;
    { The run in progress (for Cancel from the window). }
    FRun: TWhisperRun;
    { Seconds of audio before the part being transcribed. }
    FDoneSeconds: Double;
    { Length of the part being transcribed, s. }
    FPartSeconds: Double;
    { Length of all the audio, s. }
    FTotalSeconds: Double;
    { Receives the messages (on the main thread). }
    FOnLog: TProc<string>;
    { Receives the progress, 0 .. 100 (on the main thread). }
    FOnProgress: TProc<Double>;
    { Receives the length of the audio once it is read, s (on the main
      thread). }
    FOnAudioLength: TProc<Double>;
    { Receives what is being done now (on the main thread). }
    FOnStatus: TProc<string>;
    { Number of the part being transcribed (from 1). }
    FPartNo: Integer;
    { How many parts there are. }
    FPartCount: Integer;
    { Where the part being transcribed starts on the joined time line, s. }
    FPartOffset: Double;
    { Backing field of @link(Summary). }
    FSummary: TBuildSummary;
    { Backing field of @link(Succeeded). }
    FSucceeded: Boolean;
    { The transcription so far, part by part, beside the output
      (PartialFileOf): a build stopped part way goes on from there. }
    FPartialFile: string;
    { Time paused for the system's sleep in this run, s (not counted as
      transcribing). }
    FPausedSeconds: Double;
    { Time the parts taken from FPartialFile took to transcribe, s (earlier
      runs). }
    FPriorSeconds: Double;
    { Backing field of @link(CoverChoice). }
    FCoverChoice: string;
    { The diagnostic switches this build runs with (BuildDiagnostics; '' =
      none). With any, no saved or part-way transcript is read or kept:
      every diagnostic build transcribes all of the audio and leaves the
      next normal build nothing made with other settings. }
    FDiagnostic: string;
    { Backing field of @link(Benchmark). }
    FBenchmark: Boolean;
    { A benchmark: when the timed piece being transcribed began (0 = none
      is: BenchElapsed stands still). }
    FBenchFrom: TDateTime;
    { A benchmark: FPausedSeconds when that piece began (the time asleep
      is not the piece's). }
    FBenchPaused: Double;
    { Writes whisper.cpp's timings since the part began to the debug log
      (whisper_print_timings: fallbacks, and the time and runs of the
      encoder, the decoder and the sampling). ANote says which pass they
      are for. The fallback counts are the model's since it was loaded -
      whisper.cpp never resets them - so a part's own are the difference
      from the part before. }
    procedure LogTimings(AModel: TWhisperModel; const ANote: string);
    { Waits while the system sleeps (Steam's Game Mode: GSleepGate reset by
      the window), then counts the time in FPausedSeconds. Called between
      30 s windows and between parts. }
    procedure PausePoint;
    { Saves the parts transcribed so far (AResult, ADone of AParts) as
      FPartialFile, with the model, the language heard (ALanguage) and the
      time they took (ASeconds). }
    procedure SavePartial(const AResult: TWhisperTranscription; const AParts: TWhisperAudioPartArray;
      ADone: Integer; const ALanguage: string; ASeconds: Double);
    { The parts transcribed before (FPartialFile) when it was made from
      these parts (AParts) with this model.
      @returns(False when there is none to go on from) }
    function ReadPartial(const AParts: TWhisperAudioPartArray; out AResult: TWhisperTranscription;
      out ADone: Integer; out ALanguage: string; out ASeconds: Double): Boolean;
    { Sends AText to OnLog. }
    procedure Log(const AText: string);
    { Sends APercent to OnProgress. }
    procedure Progress(APercent: Double);
    { Sends ASeconds to OnAudioLength. }
    procedure AudioLength(ASeconds: Double);
    { Sends AText to OnStatus. }
    procedure Status(const AText: string);
    { A segment was transcribed: shown as the status, so the window shows
      the words as they come. }
    procedure RunSegment(Sender: TObject; const ASegment: TWhisperSegment);
    { whisper.cpp's progress through the part being transcribed. }
    procedure RunProgress(Sender: TObject; AProgress: Integer);
    { FFmpeg: from PATH / the program's folder, else from whisper.cpp's
      library folder (TWhisper's redistributable_bin). }
    function OpenFFmpeg: TFFmpegLibrary;
    { The transcript in FJsonFile when it was made from these files. }
    function ReadSaved(const AParts: TWhisperAudioPartArray; out AResult: TWhisperTranscription;
      out ASavedParts: TWhisperAudioPartArray): Boolean;
    { Logs the alignment's figures with what each means, a verdict, and
      the longest stretches worth a listen (ASplit: the aligner's words,
      AAligned their times, ARegions from WhisperAlignRegions). Front and
      back matter - not spoken before the first or after the last word
      read - is counted but not listed. }
    procedure LogResults(const AStats: TWhisperAlignStats; AHeard: Integer; const ASplit: TWhisperStringArray;
      const AAligned: TWhisperAlignedWordArray; const ARegions: TWhisperAlignRegionArray);
    { Takes the silence off the word edges of a transcript saved before
      that was done (TWhisper zip 28), part by part from the audio. }
    procedure TrimSaved(var AResult: TWhisperTranscription; AAudio: TWhisperAudioSet);
    { Saves AResult as FJsonFile, marked as having trimmed word edges, with
      the model that made it (file name) and when (AMade, 'yyyy-mm-dd
      hh:nn'): a later run reuses it only with the same model. }
    procedure SaveTranscript(const AResult: TWhisperTranscription; const AParts: TWhisperAudioPartArray;
      const AModel, AMade: string);
    { Transcribes every part of AAudio into one transcription (the joined
      time line), as WhisperConsole does: clean, second pass over gaps. }
    function Transcribe(AAudio: TWhisperAudioSet): TWhisperTranscription;
    { A benchmark's score (Summary's Bench* fields): the book words
      (AAligned, the aligner's) timed inside the chapter material of
      AParts - each part without its first and last BENCH_EDGE_SECONDS -
      and how many of them were heard exactly or nearly. }
    procedure ScoreBenchmark(const AAligned: TWhisperAlignedWordArray; const AParts: TWhisperAudioPartArray);
  protected
    { The build. }
    procedure Execute; override;
  public
    { A build of ABookFile with AAudioFiles into AOutFile (not started:
      call Start); AForceLanguage ('' = the book's) overrides the book's
      language tag. }
    constructor Create(const ABookFile: string; AAudioFiles: TStrings; const AModelFile, ADevice,
      AOutFile: string; AChapters, AReuse: Boolean; const AForceLanguage: string);
    { Frees the file list. }
    destructor Destroy; override;
    { Stops the build: the transcription at its next check, the rest
      between steps. }
    procedure Cancel;
    { Receives the messages. }
    property OnLog: TProc<string> read FOnLog write FOnLog;
    { Receives the progress. }
    property OnProgress: TProc<Double> read FOnProgress write FOnProgress;
    { Receives the length of the audio (the transcription's 5 - 90 % of
      progress cover it evenly). }
    property OnAudioLength: TProc<Double> read FOnAudioLength write FOnAudioLength;
    { Receives what is being done now. }
    property OnStatus: TProc<string> read FOnStatus write FOnStatus;
    { The build's figures (complete once it has ended). }
    property Summary: TBuildSummary read FSummary;
    { True when the book was written: every step ran to its end (False
      while it runs, and after a failure or Cancel). }
    property Succeeded: Boolean read FSucceeded;
    { The cover chosen ('' automatic, 'book', 'audio', a picture's path):
      set before Start. }
    property CoverChoice: string read FCoverChoice write FCoverChoice;
    { Set before Start: a benchmark's build (Benchmark Lite / Full). No
      saved or part-way transcript is read or kept (every benchmark
      transcribes all of its audio), and each part long enough is
      transcribed in three pieces - its first BENCH_EDGE_SECONDS, the
      chapter material, its last BENCH_EDGE_SECONDS - of which only the
      middle one is timed and scored (the standing rule: a LibriVox
      section's spoken notices are never measured). The book written is
      a whole one, every piece timed in it. }
    property Benchmark: Boolean read FBenchmark write FBenchmark;
    { A benchmark's clock as it runs (any thread): the timed pieces'
      transcription so far, s - the score's own measure, which it equals
      once the transcription has ended (Summary.BenchSeconds). }
    function BenchElapsed: Double;
  end;

  { Where a job of the queue is. }
  TJobState = (
    { Not run yet (or to run again). }
    jsWaiting,
    { Being built now. }
    jsRunning,
    { Built. }
    jsDone,
    { Stopped by an error. }
    jsFailed,
    { Stopped by Cancel. }
    jsCancelled);

  { One book to build: everything Create would use, taken from the window
    when the job was added. }
  TBuildJob = record
    { The EPUB. }
    Book: string;
    { Its title (for the list). }
    Title: string;
    { The audio files, in reading order. }
    Audio: TArray<string>;
    { The model file. }
    Model: string;
    { The device by name ('' = whisper.cpp's default). }
    Device: string;
    { The EPUB to write. }
    Output: string;
    { Chapters of a file are parts. }
    Chapters: Boolean;
    { Use a saved transcript when it fits. }
    Reuse: Boolean;
    { The language to transcribe in ('' = the book's). }
    Language: string;
    { The cover chosen: '' automatic, 'book', 'audio' or a picture's path
      (uCovers). }
    Cover: string;
    { Where it is. }
    State: TJobState;
    { What happened ('' = nothing yet): the time taken, or why it failed. }
    Note: string;
    { When it started (0 = not run in this session). }
    Started: TDateTime;
    { Time it took, s. }
    Seconds: Double;
    { Size of the EPUB written, bytes (0 = none). }
    OutputBytes: Int64;
    { The build's figures (from this session's run). }
    Summary: TBuildSummary;
  end;

  { One model of a calibration, as its progress view shows it. }
  TCalibrationRow = record
    { The model file. }
    Model: string;
    { When its first device began (0 = not yet). }
    Started: TDateTime;
    { When its last device ended (0 = not yet). }
    Ended: TDateTime;
    { Its devices ended. }
    Done: Integer;
    { The device being timed now ('' = none). }
    Device: string;
    { What is being done on it ('' = not said yet; TCalibrationStepEvent's
      APhase). }
    Phase: string;
    { How far the device being timed is, % (TCalibrationStepEvent). }
    Step: Integer;
    { The fastest so far, by name ('' = none yet). }
    Best: string;
    { Its speed, x real time. }
    BestSpeed: Double;
  end;

  { The builder's window. }
  TfrmBuilder = class(TForm)
    { Loads whisper.cpp and lists its devices; builds the window. }
    procedure FormCreate(Sender: TObject);
    { An exception nothing handled: into the debug log with the library it
      happened in (DebugLogException), then shown as before. }
    procedure AppException(Sender: TObject; E: Exception);
    { Stops a build before the window goes. }
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { whisper.cpp's and ggml's log lines into the debug log (any thread).
      @param(Sender  the library)
      @param(ALevel  the line's level)
      @param(AText  the line) }
    procedure WhisperLog(Sender: TObject; ALevel: TWhisperLogLevel; const AText: string);
  private
    // (a new section: Delphi allows no field after a method in one)
    { The book's side. }
    layBook: TLayout;
    { The audio's side. }
    layAudio: TLayout;
    { Between the two sides. }
    splSides: TSplitter;
    { The output, the settings line, Create and the log, at the bottom. }
    layBottom: TLayout;
    { The book and the audio side by side, at the top (the queue below). }
    layTop: TLayout;
    { Holds the settings' controls (cbModel, cbDevice, cbLanguage,
      cbPower, cbGpu, chkChapters, chkReuse): the code reads and sets
      them, the menu's Settings page shows and changes them. Never shown
      (owner, 2026-11-23: the window's own settings page is gone). }
    laySettings: TLayout;
    { The settings in one line, on the window. }
    lblSettings: TLabel;
    { The EPUB chosen. }
    edBook: TEdit;
    { What the book holds. }
    mmBook: TMemo;
    { The audio files, in reading order. }
    lbAudio: TListBox;
    { The model by name (uModels' catalogue: downloaded the first time it
      is chosen), other models in the models folder, the model chosen
      elsewhere, and "Other model file ...". }
    cbModel: TComboBox;
    { The model file chosen ('' = none). }
    FModelPath: string;
    { The models folder (uModels.ModelsDefaultFolder, or the user's). }
    FModelsFolder: string;
    { cbModel's items: the model file of each ('' = "Other model file ..."). }
    FModelItems: TStringList;
    { True while FillModels fills cbModel (its OnChange does nothing). }
    FFillingModels: Boolean;
    { The model being downloaded, nil when none. }
    FDownload: TModelDownload;
    { "Download every model": the models still to fetch, by name, in the
      catalogue's order. }
    FDownloadQueue: TArray<string>;
    { A download of "Download every model" is running (DownloadDone then
      goes on with FDownloadQueue and leaves the model in the window). }
    FDownloadAll: Boolean;
    { Expert mode ([Models] Expert, off at first): the model list offers
      every model of the catalogue, the other files of the models folder
      and "Other model file ..."; without it only MODEL_STANDARD (base and
      large-v3-turbo) and the model in use. }
    FExpert: Boolean;
    { Settings > Lowest acceptable speed, in tenths of real time (0 ..
      LOWEST_SPEED_TOP; 0 = any speed): a model, or a device, that the
      calibration timed below it is not used for builds or benchmarks
      (owner, 2026-11-22: the Miix's 0.6x). }
    FLowestSpeed: Integer;
    { The calibration's results show (ShowCalibrationResults): any button,
      key or click goes on (CalResultsButton). }
    FCalResults: Boolean;
    { The results page was opened from Settings > Calibration results:
      closed, the Settings page comes back. }
    FCalFromSettings: Boolean;
    { The calibration's introduction shows (ShowCalibrationIntro): shown
      again when the pad and the keys change places (its buttons). }
    FCalIntro: Boolean;
    { Its AWhy. }
    FCalIntroWhy: string;
    { Its estimate has been written to the debug log (once). }
    FCalIntroLogged: Boolean;
    { Shows the introduction once the window has stopped changing size:
      the first time (FIntroWait) and again after a later change
      (FormResized). }
    tmIntro: TTimer;
    { The introduction is still to be shown for the first time
      (IntroWhenSettled): never before the window has its size. }
    FIntroWait: Boolean;
    { The window's client size when tmIntro last looked. }
    FIntroW, FIntroH: Integer;
    { When that size was first seen (GetTickCount64). }
    FIntroTick: UInt64;
    { The computer is kept awake (a build, queue, calibration or download
      runs) - see uInhibit. }
    FAwake: Boolean;
    { InhibitStart(ikSleep) is held (Power: not Let it sleep). }
    FInhibited: Boolean;
    { The power choice in force (see EffectivePower), 0 = none. }
    FPowerNow: Integer;
    { How the computer is kept while building (owner, 2026-11-19: "saving
      power or time"): Automatic, Fastest, Save power, Let it sleep. }
    cbPower: TComboBox;
    {$IFDEF MSWINDOWS}
    { Windows' graphics preference for this program (Windows only; at the
      next start). }
    cbGpu: TComboBox;
    {$ENDIF}
    { The device to transcribe on. }
    cbDevice: TComboBox;
    { The language: the book's (the first item) or one chosen (owner,
      2026-11-19: "Can we have a forced language override"). }
    cbLanguage: TComboBox;
    { The EPUB to write. }
    edOut: TEdit;
    { Chapters of a file (m4b) are parts. }
    chkChapters: TCheckBox;
    { Use the transcript an earlier run kept, when it fits. }
    chkReuse: TCheckBox;
    { Starts a build. }
    btnCreate: TButton;
    { Stops it. }
    btnCancel: TButton;
    { How far the build is. }
    pbBuild: TProgressBar;
    { What the build did. }
    mmLog: TMemo;
    { What is being done now, with the time taken and the time left. }
    lblStatus: TLabel;
    { Refreshes lblStatus every second while building (the clock moves
      even while one long part is transcribed). }
    tmStatus: TTimer;
    { The build's last status text. }
    FStatusText: string;
    { The build's last progress, 0 .. 100. }
    FPercent: Double;
    { The build running, nil when none. }
    FBuild: TBuildThread;
    { When the build started. }
    FStarted: TDateTime;
    { When the transcription's progress started to count (the first
      progress past the 5 % of reading the book and the audio). }
    FRateFrom: TDateTime;
    { The progress at FRateFrom; -1 = not there yet. }
    FRatePercent: Double;
    { The audio of the build running, s (0 until the thread has read it). }
    FAudioTotal: Double;
    { The audio transcribed at FRateFrom, s. }
    FRateAudio: Double;
    { When the transcription ended (progress 90 %); 0 = not yet. }
    FAfterFrom: TDateTime;
    { The speed the build running is expected to run at, x real time, from
      the history or the calibration (0 = nothing to go on). }
    FExpSpeed: Double;
    { Aligning and writing per second of audio, s (0 = not known). }
    FExpAfter: Double;
    { The audio after which the build's own rate counts as much as
      FExpSpeed, s. }
    FExpPrior: Double;
    { Where FExpSpeed comes from (for the log). }
    FExpSource: string;
    { The book of the build running (copied to FMadeBook when it ends well). }
    FRunBook: string;
    { The output of the build running (copied to FMadeOut when it ends well). }
    FRunOut: string;
    { The book of the last build that finished in this run of the program. }
    FMadeBook: string;
    { The EPUB that build wrote: Create replaces it without asking. }
    FMadeOut: string;
    { The chosen book's TEpubBook.WrittenBy ('' = not made by EpubUnum). }
    FBookWrittenBy: string;
    { The chosen book's media overlay clips (0 = no synced audio yet). }
    FBookClips: Integer;
    { Devices whisper.cpp can use (cbDevice's items after 'Default'). }
    FDevices: TWhisperDeviceArray;
    { Why whisper.cpp is not there ('' when it is). }
    FWhisperNote: string;
    { The books folder: where Book... opens (Settings; default
      Documents/EpubBuilder/Books). }
    FBookFolder: string;
    { The audio folder: where Add audio... opens (default
      Documents/EpubBuilder/Audio). }
    FAudioFolder: string;
    { The output folder: where a chosen book's EPUB 3 goes by default
      (default Documents/EpubBuilder/Output). }
    FOutFolder: string;
    { The output name given by DefaultOutput for the book in the window
      (Settings > Output folder renames it only while it is unchanged). }
    FAutoOut: string;
    { The chosen book's title. }
    FBookTitle: string;
    { The job queue: below the book and the audio, across the window. }
    layQueue: TLayout;
    { Between the book and audio above and the queue below. }
    splQueue: TSplitter;
    { The jobs. }
    lbJobs: TListBox;
    { Runs the waiting jobs one after the other. }
    btnRunQueue: TButton;
    { Adds the window's book, audio and settings to the queue. }
    btnAddJob: TButton;
    { Writes the window's book, audio, model, device, output and options
      back into the job shown in it (the selected one; owner, 2026-11-19:
      a loaded queue's jobs checked and their output names changed). }
    btnUpdateJob: TButton;
    { The job the window shows (clicked in the queue), -1 = none. }
    FEditJob: Integer;
    { The job Update job replaces once the checks pass, -1 = Add to queue
      adds a new one. }
    FUpdateJob: Integer;
    { Big Picture (owner, 2026-11-19 "Can we add Big Picture mode to
      Builder" - the full pad flow, audio matched then confirmed): Steam
      runs in Big Picture; the window is driven by FPadMenu with the pad. }
    FBigPicture: Boolean;
    { The pad (Steam Input; the reader's action set "Reader" - one manifest
      per Steam app), nil without Steam. }
    FPad: TSteamPad;
    { Polls FPad. }
    tmPad: TTimer;
    { Looks twice a second whether the dark window is still dark
      (ApplyDarkWindow): a style applied again brings light backgrounds
      back, and a list's new rows come with the style's dark text. Runs
      with or without Steam. }
    tmDark: TTimer;
    { The pad's menu over the window. }
    FPadMenu: TPadMenu;
    { Dark colours - the pad's menu and the window, in Big Picture and on
      the desktop alike ([View] Dark, on unless turned off; Settings > Dark
      mode, the menu's "Dark mode" row - owner, 2026-11-21: "yes, all
      dark"; 2026-11-22: "The desktop form should use the same dark mode
      option as the Steam version"). }
    FPadDark: Boolean;
    { The window is dark now (ApplyDarkWindow): its fill and the log's
      text colour were changed and are put back when dark is turned off. }
    FWindowDark: Boolean;
    { ApplyDarkWindow has said in the debug log why the log stays light. }
    FDarkNoted: Boolean;
    { macOS, Big Picture: when tmPadTimer last looked whether the window is
      full screen. }
    FFullTick: UInt64;
    { macOS, Big Picture: how often full screen has been asked for
      (PAD_FULL_TRIES when it is, or has been asked for often enough; the
      last time the window covers the screen instead - uMacWindow). }
    FFullTries: Integer;
    { Which list FPadMenu shows (BPM_*). }
    FPadMode: Integer;
    { What each row of it does (BPC_* on the home list, PADROW_* or an
      index elsewhere). }
    FPadCmds: TArray<Integer>;
    { The EPUB files listed (Books). }
    FPadBooks: TArray<string>;
    { The audio offered (Audio). }
    FPadAudio: TArray<TPadAudio>;
    { The job the job list is about. }
    FPadJob: Integer;
    { The question's answer goes to it (Ask in Big Picture). }
    FAskProc: TInputCloseDialogProc;
    { The answers of the question's rows (mrNone for its text). }
    FAskResults: TArray<TModalResult>;
    { The answer when the question is left with B / Start. }
    FAskCancel: TModalResult;
    { When the foot's progress was last written (ms). }
    FPadFootTick: UInt64;
    { The menu was last driven by the keyboard, the mouse or a finger, not
      a pad: its foot and Controls name keys (PadFoot, PadControls). }
    FPadKeys: Boolean;
    { The home list shows its Settings page (PadHome): B and its Back row
      go to the first page's Settings row. }
    FPadSettings: Boolean;
    { The Settings page was opened by File > Settings (the desktop): back
      closes the menu, it does not go to the menu's first page. }
    FPadSettingsOnly: Boolean;
    { Big Picture: after the note's OK the list comes back on Output (the
      Output row's note), not on Create. }
    FPadToOutput: Boolean;
    { Exit was confirmed with the pad: no second question on closing. }
    FForceClose: Boolean;
    { Not calibrated, and no model to calibrate at start-up: the question
      is asked once a model is here (downloaded or chosen). }
    FCalibPending: Boolean;
    { The next StartCalibration with AAllModels times only the models not
      calibrated yet (CalibrateNewModels: after Download every model). }
    FCalOnlyNew: Boolean;
    { The calibration running was started by itself at start-up
      (CheckCalibrationAtStart): Big Picture's main menu after it, not the
      Settings page's Model row. }
    FCalAtStart: Boolean;
    { The home list that follows the answer to a pad question shows the
      Model row selected (set by the question's answer, cleared by
      PadAnswer): after "Calibrate it now? - No" the next model is one
      press away. }
    FPadToModel: Boolean;
    { In the log's place (owner, 2026-11-20: "little point in having a debug
      output window for transcription"): what is being done, in large
      type; the log behind Settings > Show the log. }
    layProgress: TLayout;
    { Linux (Game Mode): the window brought back after the screen saver or
      a display that was off (uRedraw). }
    FRedraw: TWindowRedraw;
    { BookManager and EpubReader connect here (uLink): books and audio
      sent in, the books made sent out, the progress and the log. }
    FLink: TLinkServer;
    { The pairing bar at the top (made when first needed): a program asks
      to connect - the code to type there, the time left, Refuse
      connection. Not a dialog: it closes by itself when the program is
      paired, the code runs out or was typed wrong five times (owner,
      2026-11-20: "the dialog on builder should automatically close"). }
    pnlPair: TPanel;
    { The pairing bar: who asks. }
    lblPairText: TLabel;
    { The pairing bar: the code, large. }
    lblPairCode: TLabel;
    { The pairing bar: how long the code works. }
    lblPairTime: TLabel;
    { Counts the pairing code's time down (every second while it shows). }
    tmPair: TTimer;
    { The program asking to pair. }
    FPairWho: string;
    { Until when its code works. }
    FPairUntil: TDateTime;
    { The pad's box (Big Picture) shows the pairing: closed with the bar. }
    FPairPad: Boolean;
    { Steam's Game Mode: reads the system's sleep news (InhibitPoll) four
      times a second - tmSleepTimer. }
    tmSleep: TTimer;
    { The system is going to sleep and the build is being paused: since
      when (ms, TThread.GetTickCount64); 0 = not now. }
    FSleepAsked: UInt64;
    { The sleep delay was given back (InhibitLetSleep): the machine sleeps
      or is about to - the wake opens GSleepGate again. }
    FSleepLet: Boolean;
    { When the machine went to sleep (Now); at the wake the build's clocks
      (FStarted, FRateFrom, FAfterFrom) move on by the time asleep, so the
      time taken and left leave it out (zip 169: the time left climbed
      with every sleep). }
    FSleepWall: TDateTime;
    { The book (or Calibrating, Downloading, Idle). }
    lblPTitle: TLabel;
    { Job N of M. }
    lblPJob: TLabel;
    { Done, taken, left. }
    lblPTime: TLabel;
    { The speed so far. }
    lblPSpeed: TLabel;
    { The title of the book being built. }
    FBuildTitle: string;
    { Taken / left, as ShowStatus last worked it out. }
    FTimeText: string;
    { The transcription's own speed so far, x real time (0 = not yet). }
    FSpeedNow: Double;
    { The last build's result, shown when idle. }
    FLastResult: string;
    { Starts the next job once the last one's thread has gone. }
    tmQueue: TTimer;
    { The queue. }
    FJobs: TArray<TBuildJob>;
    { The job being built (index in FJobs), -1 = none (Create's build). }
    FJob: Integer;
    { Run Queue is on: when a job ends the next waiting one starts. }
    FQueueRunning: Boolean;
    { Cancel was pressed for the build running. }
    FCancelled: Boolean;
    { The log lines of the build running, saved beside its output
      (<output>.log) when it ends - an overnight queue leaves a log per
      book. }
    FBuildLog: TStringList;
    { LogLine also writes to FBuildLog (a build is running). }
    FLogging: Boolean;
    { Folder of the last queue file loaded or saved. }
    FQueueFolder: string;
    { Pictures that become a book's cover, named as the book (uCovers;
      [Folders] Covers). }
    FCoverFolder: string;
    { The cover chosen in the window ('' automatic, 'book', 'audio', a
      picture's path); goes into the job. }
    FCoverChoice: string;
    { The cover chooser (thumbnails). }
    FCoverPick: TCoverPicker;
    { RestoreQueue is loading the kept queue (not kept again meanwhile). }
    FRestoring: Boolean;
    { The queue's file (the last loaded or saved; '' = none yet): the
      report takes its name, and it is saved again after each job. }
    FQueueFile: string;
    { The calibration running, nil when none. }
    FCalib: TCalibrationThread;
    { whisper.cpp's version and folder, for the logs ('' = not loaded). }
    FWhisperText: string;
    { whisper.cpp was built with Core ML (macOS, whisper-dev zip 22: its
      system info says COREML = 1): models get their Core ML encoder. }
    FCoreML: Boolean;
    { The device of the build running as the history names it (with
      '+CoreML' when the model's encoder is used). }
    FExpDevice: string;
    { The window has been shown (the calibration question comes once). }
    FShown: Boolean;
    { The menu bar (Windows, macOS: the system's). }
    mnuMain: TMainMenu;
    {$IF Defined(LINUX) and not Defined(ANDROID)}
    { Linux: the menu bar drawn by FMX instead (mnuMain stays nil): GTK's
      native bar shows only the first letter of each item (as EpubReader).
      Declared on Linux only (H2219 elsewhere). }
    mnuBar: TMenuBar;
    {$ENDIF}
    { Settings' calibration and diagnostics rows can be used: nothing
      runs and whisper.cpp is there (UpdateControls). }
    FToolsReady: Boolean;
    { Settings > AMD ROCm acceleration is offered: Linux Steam builds, an
      AMD GPU without a ROCm device (CheckRocmDlc). }
    FRocmOffer: Boolean;
    { The Benchmark menu: [0] Run all N benchmarks (BenchName: N = those
      that can run here), [1 .. 4] one each (BENCH_NAMES), with the time
      each takes; greyed when its model is not there or too slow. }
    miBench: array[0..4] of TMenuItem;
    { Each benchmark can run here: its model is in the models folder and
      not below Settings > Lowest acceptable speed (BenchAvailability). }
    FBenchCan: array[1..4] of Boolean;
    { The benchmark being built (1 .. 4, BENCH_NAMES; -1 = none: the build
      running is a book's). }
    FBenchOption: Integer;
    { The benchmarks still to run after it (Run all). }
    FBenchQueue: TArray<Integer>;
    { The run is Run all (every benchmark that can run here). }
    FBenchAll: Boolean;
    { Each benchmark's score in this run, s (0 = not run). }
    FBenchScores: array[1..4] of Double;
    { The book each benchmark of the run made ('' = none; kept or deleted
      when the run ends). }
    FBenchBooks: array[1..4] of string;
    { Each recording's length, s (0 = not read yet). }
    FBenchAudio: array[0..1] of Double;
    { What the time estimates were worked out from (RefreshBenchmarks
      works them out again when it changes). }
    FBenchKey: string;
    { Each option's time estimate, s (0 = none). }
    FBenchEta: array[0..4] of Double;
    { The benchmarks of the run, in order (the progress view's rows). }
    FBenchList: TArray<Integer>;
    { Each benchmark of the run has ended. }
    FBenchEnded: array[1..4] of Boolean;
    { Each benchmark's clock as last shown, s (a stopped one keeps it). }
    FBenchClock: array[1..4] of Double;
    { Each benchmark's share of the transcription done, % (its bar). }
    FBenchPct: array[1..4] of Double;
    { The progress view while a run is on (nil otherwise). }
    FBenchView: TBenchProgress;
    { The calibration's progress view (nil when none runs; owner,
      2026-11-22: "a Calibration progress bar, similar to the Benchmark
      version adapted to role"). }
    FCalView: TBenchProgress;
    { The calibration's models, a block each in FCalView. }
    FCalRows: TArray<TCalibrationRow>;
    { The results are up (their question not answered yet). }
    FBenchResults: Boolean;
    { The results are hidden (X / H): the bars show. }
    FBenchHidden: Boolean;
    { The results shown again keep this row selected (-1: the last). }
    FBenchSel: Integer;
    { The scores go to Steam's leaderboards ([Benchmark] Leaderboard in
      the settings, Settings > Leaderboard; yes at first and not asked -
      owner, 2026-11-23: "just do it if leaderboard is checked in
      settings", "Default value ... is yes"). }
    FBoardUpload: Boolean;
    { This run's scores for the leaderboards, ms (0 = none). }
    FBoardMs: array[1..4] of Integer;
    { The numbers sent beside each (BoardDetails). }
    FBoardDetails: array[1..4] of TArray<Integer>;
    { Each score's way to its leaderboard: 0 not sent, 1 being sent, 2
      there (FBoardRank, FBoardCount, FBoardBest), 3 not taken. }
    FBoardState: array[1..4] of Integer;
    { The user's place on each leaderboard. }
    FBoardRank: array[1..4] of Integer;
    { Each leaderboard's rows. }
    FBoardCount: array[1..4] of Integer;
    { The user's score on each leaderboard, ms (their best). }
    FBoardBest: array[1..4] of Integer;
    { The leaderboard the menu shows or waits for (PadBoard). }
    FBoardShown: Integer;
    { Its page is the one around the user, not the top (left / right). }
    FBoardAround: Boolean;
    { The user has a row on it (known once it has been read): the page
      around them can be asked for. }
    FBoardHasRank: Boolean;
    { The board's rows its page has room for (the window's height). }
    FBoardRows: Integer;
    { Benchmark > Leaderboards... (Steam running). }
    miBoards: TMenuItem;
    { The run's books (deleted when the results are answered). }
    FBenchKeep: TArray<string>;
    { Of them, the ones offered to keep. }
    FBenchCandidates: TArray<string>;
    { A Fast book is offered (Detailed makes the better one: said). }
    FBenchFastOffered: Boolean;
    { The question answered by PadAnswer closes the menu instead of going
      to the home list (the desktop's results). }
    FAskThenClose: Boolean;
    { The buttons the foot of the menu shown names (PadFootOf). }
    FFootButtons: TArray<Integer>;
    { What each of them does there. }
    FFootTexts: TArray<string>;
    { A label above AParent's next control. }
    function AddCaption(AParent: TFmxObject; const AText: string): TLabel;
    { A row in AParent: a caption, then a control filling it. }
    function AddRow(AParent: TFmxObject; const ACaption: string): TLayout;
    { A button at the right of / in ARow. }
    function AddButton(AParent: TFmxObject; const AText: string; AOnClick: TNotifyEvent; AAlign: TAlignLayout;
      AWidth: Single = 90): TButton;
    { Makes the controls. }
    procedure BuildWindow;
    { Shows the book's figures in mmBook (or why it cannot be used). }
    procedure ShowBook(const AFileName: string);
    { Adds files to lbAudio in natural order. }
    procedure AddAudio(AFiles: TStrings);
    { Enables what can be used now. }
    procedure UpdateControls;
    { Applies the Power choice: kept awake or not, the speed (uInhibit);
      at the end of the work the system's own again. Logs what was done.
      @param(ABusy  work starts (or goes on: Automatic looks at the
        battery again))
      @param(AOnlyOnChange  log and apply only when the choice in force
        changes) }
    procedure ApplyPower(ABusy, AOnlyOnChange: Boolean);
    { The Power choice in force: 1 Fastest, 2 Save power, 3 Let it sleep
      (Automatic: Fastest on mains, Save power on battery).
      @returns(the choice) }
    function EffectivePower: Integer;
    { cbPower changed: kept, and in force at once while working. }
    procedure cbPowerChange(Sender: TObject);
    {$IFDEF MSWINDOWS}
    { cbGpu changed: stored for Windows (used at the next start). }
    procedure cbGpuChange(Sender: TObject);
    {$ENDIF}
    { The device's name to use for AName saved with description
      ADescription: the device of that description when the numbers moved
      (a driver update, Windows' graphics preference reorder Vulkan's
      list). @returns(the name) }
    function DeviceMatch(const AName, ADescription: string): string;
    { The description of device AName ('' when none). @returns(it) }
    function DeviceDescription(const AName: string): string;
    { Appends a line to the log (and to the running build's log). }
    procedure LogLine(const AText: string);
    { Appends a line about the window - a book or audio chosen, the queue
      changed - to the log, but not to the running build's log: what is
      done in the window during a queue is not part of that book's build. }
    procedure WindowLine(const AText: string);
    { Appends a line of the build or the calibration to the log (and to
      the running build's log) - not to the debug log, which the thread
      wrote it to already, with the time it was written (each part's line
      was there twice). }
    procedure ThreadLine(const AText: string);
    { Choose the EPUB. }
    procedure btnBookClick(Sender: TObject);
    { Add audio files. }
    procedure btnAddAudioClick(Sender: TObject);
    { Add every audio file of a folder. }
    procedure btnAddFolderClick(Sender: TObject);
    { Remove the selected audio file. }
    procedure btnRemoveClick(Sender: TObject);
    { Move the selected audio file up. }
    procedure btnUpClick(Sender: TObject);
    { Move it down. }
    procedure btnDownClick(Sender: TObject);
    { Choose the model file. }
    procedure btnModelClick(Sender: TObject);
    { cbModel: a downloaded model is chosen; one not downloaded yet is
      downloaded first (asked); "Other model file ..." = btnModelClick. }
    procedure cbModelChange(Sender: TObject);
    { Settings > Models folder: another models folder (kept in the
      settings; not in Steam builds - there the models are in the
      program's folder). }
    procedure ChooseModelsFolder;
    { Fills cbModel from the catalogue and the models folder, FModelPath
      selected. }
    procedure FillModels;
    { Downloads model AName (AWithModel) and / or its Core ML encoder
      (AWithEncoder) into the models folder (TModelDownload); the model
      is chosen when it is complete. }
    procedure StartDownload(const AName: string; AWithModel, AWithEncoder: Boolean);
    { The download's OnTerminate. }
    procedure DownloadDone(Sender: TObject);
    { True when model file AModel's Core ML encoder is used: a Core ML
      build and the encoder beside the model. }
    function UsesCoreML(const AModel: string): Boolean;
    { Choose where the EPUB goes. }
    procedure btnOutClick(Sender: TObject);
    { Checks the choices; asks before replacing an EPUB this program did
      not just make from this book; then StartBuild. }
    procedure btnCreateClick(Sender: TObject);
    { Starts the build of the window's choices (ADevice: '' =
      whisper.cpp's default). }
    procedure StartBuild(const ADevice: string);
    { Starts building AJob on a TBuildThread (AIndex: its place in FJobs,
      -1 for Create's build; ABenchmark: RunBenchmark's build -
      TBuildThread.Benchmark). }
    procedure StartJob(const AJob: TBuildJob; AIndex: Integer; ABenchmark: Boolean = False);
    { The window's choices as a job (ADevice: the device's name). }
    function JobFromWindow(const ADevice: string): TBuildJob;
    { Checks the window's choices (as Create does: the output, a model,
      the questions about a built book and an existing output), then
      builds now (AQueue False) or adds a job (True). }
    procedure CheckThen(AQueue: Boolean);
    { Adds AJob to the queue (an output already waiting in it: refused). }
    procedure AddJob(const AJob: TBuildJob);
    { Fills lbJobs from FJobs (keeps the selection). }
    procedure ShowJobs;
    { A job's line in lbJobs. }
    function JobText(AIndex: Integer): string;
    { Starts the next waiting job; ends the run when there is none. }
    procedure RunNextJob;
    { Writes the queue's report: <queue file>.md (a table and a section
      per job) and .csv (every figure, for a spreadsheet); a queue never
      saved: EpubBuilder-report-<date-time> beside the first job's output. }
    procedure WriteQueueReport;
    { tmQueue: RunNextJob. }
    procedure tmQueueTimer(Sender: TObject);
    { Add to queue. }
    procedure btnAddJobClick(Sender: TObject);
    { Update job: the window's job checked (as Add to queue), then in place
      of the selected one - waiting again. }
    procedure btnUpdateJobClick(Sender: TObject);
    { A click in the queue: the job into the window, as it was added. }
    procedure lbJobsClick(Sender: TObject);
    { Job AIndex into the window - book, audio, model, device, output,
      language and options; AAnnounce says so in the log. }
    procedure ShowJobInWindow(AIndex: Integer; AAnnounce: Boolean);
    { Fills the progress panel from what is running (or idle). }
    procedure UpdatePanel;
    { The queue kept between runs: beside the settings.
      @returns(its file) }
    function KeptQueueFile: string;
    { Keeps the queue as it is now (KeptQueueFile; deleted when empty). }
    procedure KeepQueue;
    { Loads the kept queue at start-up. }
    procedure RestoreQueue;
    { Big Picture's queue list: Save queue - named by the date and time,
      in the queues folder. }
    procedure PadSaveQueue;
    { Big Picture: the queues folder's queues, newest first. }
    procedure PadQueues;
    { Empties the book, its audio, the output, the language and the
      saved-transcript choice: ready for the next book (after Add to
      queue). }
    procedure ClearBook;
    { Shows the log (AOn) or the progress panel in its place; kept. }
    procedure SetLogVisible(AOn: Boolean);
    { Settings > Show the log. }
    procedure miLogClick(Sender: TObject);
    { cbLanguage set to ACode ('' = from the book). }
    procedure SelectLanguage(const ACode: string);
    { Asks AText with AButtons: a dialog, or in Big Picture the pad's
      menu; AResult gets the answer.
      @param(AText  the question)
      @param(AType  its kind)
      @param(AButtons  the answers)
      @param(ADefault  the answer selected first)
      @param(AResult  called with the answer) }
    procedure Ask(const AText: string; AType: TMsgDlgType; const AButtons: TMsgDlgButtons; ADefault: TMsgDlgBtn;
      const AResult: TInputCloseDialogProc);
    { Says why a build or a job was not started: the window's log, and in
      Big Picture also the pad's menu (the log is behind it - a second
      Add to queue refused without a word, Steam Deck 2026-11-20). }
    procedure Tell(const AText: string);
    { Starts the pad (Steam Input) and, in Big Picture, the pad's menu. }
    procedure StartPad;
    { Big Picture: the window behind the pad's menu is the log alone, full
      screen, in large type (owner, 2026-11-20: on a Steam Deck the
      window's text was too small and the window too large - "redo the
      form when displayed in big picture mode. The only thing to remain
      may be the message log"); the pad's menu does the rest. The
      pairing bar still shows above it. }
    procedure BigPictureWindow;
    { Once the window shows: the display in the debug log, the calibration's
      question. }
    procedure AfterShow;
    { Steam's Game Mode (GameModeSession, or Steam's Big Picture on Linux):
      sleep is paused for, not refused - refused, Steam was left stuck
      (owner, 2026-11-20). Logged. }
    procedure DecideSleepMode;
    { Starts FLink: the builder's id and the paired programs from the
      settings ([Link]), the folders. Logged. }
    procedure StartLink;
    { Cover...: the covers there are for the book in the window, as
      thumbnails to choose from (also Big Picture's Cover). }
    procedure ShowCoverPicker;
    { Cover... button. }
    procedure btnCoverClick(Sender: TObject);
    { FLink's folders: books, audio, and where books are made (the output
      folder, the queue's outputs, the cards' Transcribed). }
    procedure UpdateLinkFolders;
    { FLink's /status: what the progress panel shows, as JSON. }
    procedure UpdateLinkStatus;
    { FLink: a program asks to pair - the code shown (told in Big
      Picture). }
    procedure LinkPairCode(const AClient, ACode: string);
    { FLink: a program was paired - the tokens kept in the settings. }
    procedure LinkPaired(const AClient, AToken: string);
    { FLink: a file arrived - logged. }
    procedure LinkReceived(const AKind, AFileName: string);
    { The books transcribed already, by BookKey (sorted; the caller frees
      it): an EPUB of the book's name (or '<name>_001' ...) in the output
      folder, a queued job's output folder or a card's Transcribed, or a
      build of the history that matched at least HISTORY_POOR_MATCH %. }
    function TranscribedBooks: TStringList;
    { FLink: the code offered stopped working without a pairing (five
      wrong codes) - the bar closes. }
    procedure LinkPairEnded(const AClient, AWhy: string);
    { Shows the pairing bar (and, in Big Picture, the pad's box when no
      other question shows) for AClient with ACode. }
    procedure ShowPairing(const AClient, ACode: string);
    { Closes the pairing bar and the pad's box; AWhy, when not '', goes to
      the log. }
    procedure HidePairing(const AWhy: string);
    { Refuse connection: the code taken back, the program told. }
    procedure RefusePairing;
    { The bar's Refuse connection button. }
    procedure btnRefusePairClick(Sender: TObject);
    { tmPair: the time left; the bar closes when the code ran out. }
    procedure tmPairTimer(Sender: TObject);
    { Steam's Game Mode: the system's sleep news - going to sleep: the
      build pauses (GSleepGate), then the sleep delay is given back; woke:
      the build goes on. }
    procedure tmSleepTimer(Sender: TObject);
    { Steam's Game Mode, at Run queue: the queue's expected time and what
      Steam's sleep timer does to it (logged; told in Big Picture). }
    procedure QueueSleepNote;
    { The window is active again: brought back (FRedraw). }
    procedure FormActivated(Sender: TObject);
    { The window is not active any more: logged (FRedraw). }
    procedure FormDeactivated(Sender: TObject);
    { Polls the pad; keeps the menu's progress line current. }
    procedure tmPadTimer(Sender: TObject);
    { A press of pad button AButton (BP_*). }
    procedure PadPress(AButton: Integer);
    { The hints at the menu's foot: a pad's buttons, or the keys when the
      keyboard or the mouse was used last (FPadKeys) - the keys' names
      from uReaderInput's table.
      @returns(the text) }
    function PadFoot: string;
    { PadFoot for the keys (AKeys) or for a pad.
      @returns(the text) }
    function PadFootFor(AKeys: Boolean): string;
    { The hints of buttons AButtons (BP_*), doing ATexts: Steam's pictures
      of the pad's controls (their names without pictures), or with AKeys
      the keys' names from uReaderInput's table (owner's standing rule,
      2026-11-22: a PlayStation pad has no A or B).
      @returns(the hints) }
    function PadHintsFor(const AButtons: TArray<Integer>; const ATexts: TArray<string>;
      AKeys: Boolean): TArray<TPadHint>;
    { The foot of the menu about to be shown: AButtons doing ATexts, kept
      for RefreshFoot; the hints as words (the foot Show sizes the box by).
      @returns(the text) }
    function PadFootOf(const AButtons: TArray<Integer>; const ATexts: TArray<string>): string;
    { The foot kept by PadFootOf drawn as hints, for the pad or the keys
      (FPadKeys) - after every Show of a list with button hints, and when
      the other way of control is used. }
    procedure RefreshFoot;
    { What drives the menu changed - a pad, or the keyboard / mouse /
      finger (FPadKeys): a list that shows goes over to it at once - the
      Controls list is shown again in the other form (its row kept), the
      home and queue lists' foot names the other buttons.
      @param(AKeys  the keyboard, the mouse or a finger was used) }
    procedure SetPadKeys(AKeys: Boolean);
    { The pad button (BP_*) of action AAction of the manifest.
      @returns(-1 when the builder has no such button) }
    function PadButtonOf(const AAction: string): Integer;
    { The Controls list, the same in both forms: the button or key on the
      left, what it does on the right - Steam's pictures of the pad's
      controls (their names without pictures), or the keys and the mouse
      when those were used last. Shown again by SetPadKeys when the other
      is used while it shows. }
    procedure PadControls;
    { The menu's OnGesture: the right mouse button, the wheel - the action
      uReaderInput's table gives it, pressed as a pad's button. }
    procedure PadMenuGesture(Sender: TObject; const AGesture: string);
    { The menu's OnPointer: the mouse or a finger was used (FPadKeys). }
    procedure PadPointer(Sender: TObject);
    { The home list: the book, its audio, the choices, the actions;
      ACommand (a BPC_*) selected. }
    procedure PadHome(ACommand: Integer);
    { Big Picture: the home list again once something has ended - a
      download, a calibration, the diagnostics, a build, the queue (owner,
      2026-11-21: "everything should normally result in the menu after
      it's finished"). AModel: with the Model row selected (after a
      download, a calibration, the diagnostics - "so you can get the next
      one"), else the first row. Nothing while a question is shown or
      anything still runs; nothing outside Big Picture. }
    procedure PadBackToMenu(AModel: Boolean);
    { Gives FPadMenu its colours, dark or light (FPadDark): they show from
      the next list or question on. }
    procedure PadColors;
    { Big Picture's window (the log) dark or in the style's own colours
      (FPadDark). Dark: the form is filled dark, the log's style background
      is no longer drawn (the form shows through) and its text is light.
      The text is only made light once the background is known to be gone:
      a style this cannot change keeps a readable light log, and the debug
      log says why. Called on a change and twice a second (tmDark: the
      style can be applied again and bring its background back).
      On the desktop too: the window's fill, the labels of its layouts,
      its two lists (FMX's transparent list style, light rows) and its
      memos go dark; the edit and combo boxes, the buttons, the settings
      panel and the menu bar keep the system's style. }
    procedure ApplyDarkWindow;
    { The window dark before it is drawn (FormCreate, FormShow): the memos'
      and the lists' styles applied first, so ApplyDarkWindow finds their
      backgrounds at once instead of at tmDark's next tick. Nothing when
      the window is light. }
    procedure DarkBeforeShow;
    { tmDark: the dark window looked at again. }
    procedure tmDarkTimer(Sender: TObject);
    { Dark mode on or off: the menu's and the window's colours, saved. }
    procedure ToggleDark;
    { File > Settings... and the window's Settings... button: the menu's
      Settings page over the window (Esc, a right click or its Back row
      closes it). }
    procedure miSettingsClick(Sender: TObject);
    { The folder dialog for the books (0), the audio (1) or the output (2)
      folder; kept in the settings. }
    procedure ChooseFolder(AKind: Integer);
    { The EPUB files of the books folder. }
    procedure PadBooks;
    { The audio for the book: the best matches first (AAll: every
      candidate, by name). }
    procedure PadAudioList(AAll: Boolean);
    { The queue; job ASelected selected (-1: the first row). }
    procedure PadQueue(ASelected: Integer);
    { What can be done with job AIndex. }
    procedure PadJob(AIndex: Integer);
    { The models to choose from (here, or to download). }
    procedure PadModels;
    { A book on a memory card: asks whether its EPUB goes back on the card
      (<card>/Transcribed) or stays on this machine (the output folder);
      AThen after the answer (at once for a book not on a card). }
    procedure AskOutputPlace(const ABook: string; const AThen: TProc);
    { A row chosen (A, or a click / tap). }
    procedure PadChoose(Sender: TObject; AIndex: Integer);
    { The menu closed by a click beside it. }
    procedure PadClosed(Sender: TObject);
    { Left / right on the home list: the selected choice's value. }
    procedure PadStep(ADelta: Integer);
    { B: one list back (a question: its "no"). }
    procedure PadBack;
    { The question's row AIndex answered. }
    procedure PadAnswer(AIndex: Integer);
    { The audio of the audio folder, scored against the book's title.
      @returns(the candidates, best first) }
    function PadAudioCandidates: TArray<TPadAudio>;
    { Run queue: every job not done (failed and cancelled ones again). }
    procedure btnRunQueueClick(Sender: TObject);
    { Removes the selected job (not the one running). }
    procedure btnJobRemoveClick(Sender: TObject);
    { Moves the selected job up. }
    procedure btnJobUpClick(Sender: TObject);
    { Moves it down. }
    procedure btnJobDownClick(Sender: TObject);
    { Adds the jobs of a queue file. }
    procedure btnJobLoadClick(Sender: TObject);
    { Saves the queue to a file. }
    procedure btnJobSaveClick(Sender: TObject);
    { A double click on a job puts its choices into the window (to change
      and add again, or to Create). }
    procedure lbJobsDblClick(Sender: TObject);
    { Saves FJobs to AFileName (JSON). }
    procedure SaveQueue(const AFileName: string);
    { Adds the jobs of AFileName to FJobs; returns how many. Left out,
      with a line in the log: a job whose output is its own book, and a
      job whose output a job of the queue writes already (both still to
      build, or both done - the same file loaded twice). A job still to
      build whose output exists is added with a line saying it will be
      replaced (nothing is asked while the queue runs). }
    function LoadQueue(const AFileName: string): Integer;
    { Closing while a build runs asks first (No by default): the build
      would be stopped and its work so far lost. }
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    { Steam's Exit Game (SIGTERM) or the system shutting down: saves the
      settings, the queue file, the build's log so far and leaves no
      calibration crash mark (it was not a crash), then ends - at once
      when a build, calibration or download runs (waiting for the GPU
      would outlast Steam's patience), else by closing the window.
      @param(ASignal  the signal's number) }
    procedure QuitSignalled(ASignal: Integer);
    { Asks before replacing an EPUB this program did not just make from
      this book (or one a waiting job will write), then StartBuild /
      AddJob (AQueue). }
    procedure CheckOutputThen(const ADevice: string; AQueue: Boolean);
    { Stop it. }
    procedure btnCancelClick(Sender: TObject);
    { "Use a saved transcript" changed: Create may need a model now. }
    procedure chkReuseChange(Sender: TObject);
    { The build thread ended (any way). }
    procedure BuildDone(Sender: TObject);
    { The model, device, options and folders of the last session. }
    procedure LoadSettings;
    { Keeps them for the next session (SettingsFile). }
    procedure SaveSettings;
    { Writes the time taken, the time left and FStatusText into lblStatus.
      The time left: the transcription's remaining audio at a rate that
      blends the expected speed (FExpSpeed) with the build's own (seconds
      per second of audio, the build's counting more as more audio is
      done), plus the aligning and writing; without an expectation the
      build's own rate after a minute of it, as before. }
    procedure ShowStatus;
    { The history file beside the settings (uHistory). }
    function HistoryFile: string;
    { Sets FExpSpeed, FExpAfter, FExpPrior and FExpSource for a build of
      AModel on ADevice ('' = whisper.cpp's choice). }
    procedure PrepareEstimate(const AModel, ADevice: string);
    { The audio transcribed at progress APercent (5 .. 90 %), s. }
    function AudioDoneAt(APercent: Double): Double;
    { Adds the build that ended to the history (when it transcribed) and
      logs its speed against the expectation. }
    procedure RecordHistory(const ASummary: TBuildSummary);
    { tmStatus: ShowStatus. }
    procedure tmStatusTimer(Sender: TObject);
    { Makes the menu bar: File (Exit), Tools (the calibration). }
    procedure BuildMenu;
    { The first show: the calibration question, once the window is up. }
    procedure FormShow(Sender: TObject);
    { At start-up: notes a calibration the program ended in; asks to
      calibrate when it was never done (or the devices have changed since)
      and the user has not said not to ask. }
    procedure CheckCalibrationAtStart;
    { The model in the window is not calibrated on this machine (just
      downloaded, or chosen): it is calibrated now - no question (owner,
      2026-11-22: "If models are added later on they should also
      auto-calibrate"). Not while anything runs, nor when the user said
      not to be reminded ([Calibration] DontAsk). }
    procedure OfferCalibration;
    { The models of the models folder not calibrated yet, calibrated now
      (after Download every model); nothing when all are. }
    procedure CalibrateNewModels;
    { Starts a calibration of the model in the window (AAllModels: every
      ggml-*.bin in its folder, smallest first); ARetry: pairs that ended
      the program before are timed again. Asks for a model or a recording
      when there is none. }
    procedure StartCalibration(AAllModels, ARetry: Boolean);
    { The calibration thread ended (any way): results kept, the model's
      device chosen, its lines saved beside the settings. }
    procedure CalibrationDone(Sender: TObject);
    { Puts the device the calibration found fastest for the model in the
      window into cbDevice (ALog: says so, or that the model is not
      calibrated). }
    procedure ApplyCalibration(ALog: Boolean);
    { Starts the diagnostics (uCalibration, TCalibrationThread.Diagnostics)
      of the model in the window on its device: ten minutes of the
      calibration's recording transcribed four times - as a build, without
      whisper.cpp's fallback, without DTW, without either - to find what
      makes a model slow here. AAllModels: every ggml-*.bin in the model's
      folder instead. It runs as a calibration does (FCalib: the same
      Cancel, progress and busy state) and changes no setting. }
    procedure StartDiagnostics(AAllModels: Boolean);
    { Settings > Diagnostics (this model). }
    procedure miDiagnosticsClick(Sender: TObject);
    { Settings > Diagnostics (every model): StartDiagnostics for every
      ggml-*.bin in the model's folder, smallest first, each on the
      device its calibration chose - with a closing table, a line per
      model. }
    procedure miDiagnosticsAllClick(Sender: TObject);
    { Benchmark option AOption's model file (1 .. 4: base for Fast,
      large-v3-turbo for Detailed) when it is in the models folder; for 0
      (Run all) the model of the first benchmark that has one.
      @returns('' when it is not there) }
    function BenchmarkModel(AOption: Integer): string;
    { Fills FBenchCan: which benchmarks can run here now. }
    procedure BenchAvailability;
    { How many benchmarks can run here (FBenchCan): 0, 2 or 4 - a model's
      two texts go together.
      @returns(the number) }
    function BenchCount: Integer;
    { A benchmark is running, or the next of Run all is about to: the pad
      and the keys do nothing then (PadPress).
      @returns(True while one runs) }
    function BenchRunning: Boolean;
    { Option AOption's name: BENCH_NAMES, but 0 with the number that can
      run here - "Run all 2 benchmarks" where one model is missing or too
      slow (owner, 2026-11-22, the Miix: "The label say 4").
      @returns(the name) }
    function BenchName(AOption: Integer): string;
    { The device a benchmark of AModel uses: its calibration's choice,
      else the window's ("Default" as the device it stands for).
      @returns(the device's name) }
    function BenchmarkDevice(const AModel: string): string;
    { The Benchmark menu (and the pad's list) brought up to date: each
      option enabled when its model is there and nothing runs, with its
      time estimate - worked out again only when the models, the
      calibration, the build history or the window's device changed. }
    procedure RefreshBenchmarks;
    { Option AOption with its time estimate, as the menus show it.
      @returns(the text) }
    function BenchmarkText(AOption: Integer): string;
    { The Benchmark menu's items (Tag: the option). }
    procedure miBenchmarkClick(Sender: TObject);
    { Starts benchmark option AOption (owner, 2026-11-22): 0 runs every
      benchmark that can run here one after another (those whose model is
      missing or too slow are left out, and the log says which), 1 .. 4
      one (BENCH_NAMES). }
    procedure StartBenchmark(AOption: Integer);
    { Runs the next benchmark of FBenchQueue (from ForceQueue: the build
      before it has finished). }
    procedure RunNextBenchmark;
    { Builds option AOption's reference text with its model: a build of
      its own (StartJob, TBuildThread.Benchmark), beside the settings, on
      BenchmarkDevice. }
    procedure RunBenchmark(AOption: Integer);
    { A benchmark's build has ended (from BuildDone): its score kept, the
      next one of Run all started, or the scores shown.
      @param(ASummary  the build's figures)
      @param(AOk  the build succeeded) }
    procedure BenchmarkDone(const ASummary: TBuildSummary; AOk: Boolean);
    { The run has ended: the scores (transcription times) shown, then
      the question whether to keep the book (Run all: the Detailed
      books) to read in EpubReader - No by default. }
    procedure BenchmarkFinished;
    { Big Picture: the Benchmark list - its five options with their time
      estimates, faded when not available, and Back. }
    procedure PadBenchmarks;
    { The progress view's tick: each block's time, what is being done and
      the share of the transcription done, from the running build. }
    procedure BenchTick(Sender: TObject);
    { Option AOption's line above its bar: its name, its text, and the
      device it runs on as the log describes it, without the device's name
      ('NVIDIA GeForce RTX 5090 Laptop GPU (GPU, Vulkan, 22.7 of 23.6 GB
      free)').
      @returns(the line) }
    function BenchTitle(AOption: Integer): string;
    { The progress view's corner button (the desktop): Cancel while the
      run is on, then the results shown or hidden. }
    procedure BenchCancel(Sender: TObject);
    { The calibration's progress view's tick: each model's clock, what is
      being done (the device being timed, or the fastest), and the share of
      its devices done. }
    procedure CalTick(Sender: TObject);
    { CheckCalibrationAtStart will calibrate: whisper.cpp and devices are
      there, it was not asked not to, and there is no calibration, or one
      of other devices or of an older method.
      @returns(the answer) }
    function CalibrationDueAtStart: Boolean;
    { The results in the pad's menu, on the desktop too (owner,
      2026-11-22): the title "Results" centred, a row per benchmark - its
      name, its score on the right (lines of information) - then whether
      to keep the book(s), Yes / No (No selected). }
    procedure BenchShowResults;
    { X / H, or the corner's button: the results hidden (the bars show)
      or shown again. }
    procedure BenchToggleResults;
    { The numbers sent beside a score: [0] their layout (BOARD_FORMAT),
      [1] the words matched, hundredths of a per cent, [2] 0 processor /
      1 graphics, [3] unused, [4 ..] the device's description, four
      characters a number (no machine or user name: the privacy rule).
      @returns(the numbers) }
    function BoardDetails(const ASummary: TBuildSummary): TArray<Integer>;
    { This run's scores to their leaderboards (Steam running, Settings >
      Leaderboard on): each answers through BoardSent. }
    procedure BoardSend;
    { A score reached its leaderboard, or did not: the log's line (place
      and rows - no names) and the results table again. }
    procedure BoardSent(const AResult: TSteamBoardResult);
    { What the results table says after a score: its place, "sending",
      or nothing.
      @returns(the text, with its separator) }
    function BoardNote(AOption: Integer): string;
    { The Leaderboards list: the four benchmarks (owner, 2026-11-23). }
    procedure PadBoards;
    { Leaderboard AOption, from its top: a page 95 % of the window wide
      and high that says "Asking Steam ...", then BoardAsk. }
    procedure PadBoard(AOption: Integer);
    { Asks Steam for the page of FBoardShown that FBoardAround names, as
      many rows as the page has room for (BoardRead shows them; the page
      on the screen stays until then). }
    procedure BoardAsk;
    { Left / right on a leaderboard: its top, or the rows around the
      user (owner, 2026-11-23: "two versions of the same board and
      switch between them with the left/right arrow keys") - when the
      user has a row. }
    procedure BoardSwitch;
    { The leaderboard's rows came: place, name, score, device - a full
      page when the board has that many rows. The user's own row is in
      yellow; on the top page, when it is further down, it takes the
      last line and one row fewer of the top is shown. }
    procedure BoardRead(const AResult: TSteamBoardResult);
    { Benchmark > Leaderboards... }
    procedure miBoardsClick(Sender: TObject);
    { Settings > Model > Download every model (the top row of Big Picture's model
      list): asks, then fetches every model of the catalogue that is not
      in the models folder, one after another (FDownloadQueue). The model
      in the window is not changed, no calibration is offered between
      them; a download that fails, or Cancel, ends it. }
    procedure DownloadEveryModel;
    { Starts the first model of FDownloadQueue and takes it off the queue. }
    procedure StartNextDownload;
    { Turns expert mode on or off (FExpert): kept in the settings, the
      model list filled again, a line in the log. }
    procedure ToggleExpert;
    { Settings > Lowest acceptable speed: ADelta tenths up or down (past
      either end it goes round, as the other settings' values do); kept. }
    procedure StepLowestSpeed(ADelta: Integer);
    { Settings > Lowest acceptable speed as the Settings page shows it.
      @returns(the text) }
    function LowestSpeedText: string;
    { Whether AModel on ADevice ('' = the default device) is below the
      lowest acceptable speed: the model at its best in the calibration,
      or on that device. Not calibrated: not known, so not.
      @param(AWhy  why, and what to do, for the user)
      @returns(the answer) }
    function TooSlow(const AModel, ADevice: string; out AWhy: string): Boolean;
    { TooSlow for benchmark AOption (0, Run all: any model that is here).
      @param(AWhy  why, for the user)
      @returns(the answer) }
    function BenchTooSlow(AOption: Integer; out AWhy: string): Boolean;
    { How long a build of ALength seconds of audio with AModel is expected
      to take here (the benchmarks' estimate: its calibration's device,
      the build history).
      @returns(seconds; 0 = not known) }
    function BookSeconds(const AHistory: TBuildHistory; const AModel: string; ALength: Double): Double;
    { After a calibration (owner, 2026-11-22: "You can miss the calibration
      speed for turbo very easily"): the calibration view shows base's and
      turbo's speeds and how long some well-known LibriVox books would
      take with each - a rough guide - until a button, a key or a click
      (CalResultsButton). Also into the log. }
    procedure ShowCalibrationResults;
    { The calibration's results seen: they go, after this event
      (CalResultsClosed). }
    procedure CalResultsButton(Sender: TObject);
    { The calibration view freed, the menu next (what CalibrationDone did
      before the results; after Settings > Calibration results, the
      Settings page on that row). }
    procedure CalResultsClosed;
    { Settings > Calibration results (owner, 2026-11-23: "should show the
      new Calibration Results page not just the log"): the log's lines as
      before, and the page the calibration ends with
      (ShowCalibrationResults) over the window. Not calibrated yet: says
      so. }
    procedure ShowCalibrationPage;
    { How long calibrating every model here (StartCalibration(True, ...))
      may take: an earlier calibration's speeds, else GuessSpeed's.
      @param(ACard  True when a graphics card (or Apple's Metal) is here)
      @param(ALog  each guess into the debug log)
      @returns(seconds; 0 without a model) }
    function CalibrationGuess(out ACard: Boolean; ALog: Boolean): Double;
    { Before the calibration at start-up (owner, 2026-11-22): why it is
      needed, the devices found and how long it may take (a warning when
      long), then "Calibrate now" or "Come back when I have more time to
      spare" (closes EpubBuilder); B is the second. AWhy: a re-calibration's
      reason ('' = the first). }
    procedure ShowCalibrationIntro(const AWhy: string);
    { ShowCalibrationIntro(AWhy) once the window has its size (start-up:
      the page is asked for before Big Picture's full screen has come;
      owner, 2026-11-22: the page of the small window "should not appear
      under any circumstances" - on Linux it stayed in sight under the
      right one). tmIntro shows it when the client size has not changed
      for INTRO_SETTLE_MS and, on macOS in Big Picture, the full screen
      asked for through Cocoa is there or given up. }
    procedure IntroWhenSettled(const AWhy: string);
    { Makes tmIntro when it is not there, and starts it. }
    procedure StartIntroTimer;
    { The window changed size: the calibration's introduction waits for
      it to stop (FIntroWait) or, when it shows, is laid out again
      (tmIntro). }
    procedure FormResized(Sender: TObject);
    { tmIntro: the introduction shown, the first time or again, once the
      window's size has stood still. }
    procedure tmIntroTimer(Sender: TObject);
    { Settings > Expert mode. }
    procedure miExpertClick(Sender: TObject);
    { Settings > Re-calibrate (this model). }
    procedure miCalibrateClick(Sender: TObject);
    { Settings > Re-calibrate every model. }
    procedure miCalibrateAllClick(Sender: TObject);
    { Settings > Calibration results: what is kept, model by model. }
    procedure miCalibrationClick(Sender: TObject);
    { Settings > Build history: every build's speed and accuracy, a table. }
    procedure miHistoryClick(Sender: TObject);
    { Settings > AMD ROCm acceleration: SteamGetDlc. }
    procedure miRocmClick(Sender: TObject);
    { cbLanguage's items: the book's language (ATag, '' = none) first,
      then the languages to choose; the book's selected.
      @param(ATag  the book's dc:language) }
    procedure FillLanguages(const ATag: string);
    { The language chosen in cbLanguage ('' = the book's).
      @returns(the code) }
    function ChosenLanguage: string;
    { After the start-up calibration: the window's model is below the
      lowest acceptable speed on every device and base is not - base
      becomes the window's model, and the log says so (owner, 2026-11-23:
      "switch to base automatically ... if turbo too slow"; the Miix:
      turbo 0.6x). }
    procedure UseBaseWhenTooSlow;
    { lblSettings from the settings: the model, the device, the language,
      the power, and what is not as usual (chapters, a saved transcript). }
    procedure UpdateSettingsLine;
    { The output's folder, when the user put the book's output elsewhere
      (typed in the Output box, or a card's folder), becomes the output
      folder: the next book's output goes there too (owner, 2026-11-21:
      the next book got the old default folder). Saved and logged. }
    procedure RememberOutFolder;
    { The output for book ABook: its file name in the output folder, or
      with _001, _002 ... when that is taken (a file there, or a job of
      the queue writes it).
      @param(ABook  the book chosen)
      @returns(the full path) }
    function DefaultOutput(const ABook: string): string;
    { At start-up (Linux Steam builds, STEAM_DLC_ROCM set): an AMD GPU
      with no ROCm device -> the DLC offered (or, when it is installed,
      why it may not have loaded). }
    procedure CheckRocmDlc;
    { File > Exit. }
    procedure miExitClick(Sender: TObject);
    { The machine, whisper.cpp and the device a build of AModel on ADevice
      uses, into the log (and so the build's .log): logs from several
      machines told apart (owner, 2026-11-17). }
    procedure LogMachine(const AModel, ADevice: string);
    { cbDevice's first item: 'Default (whisper.cpp chooses: CUDA0)'. }
    function DefaultDeviceItem: string;
    { The calibration says the model failed on ADevice (a model too big
      for the card): asked first, No by default; then CheckBookThen. }
    procedure CheckCalibrationThen(const ADevice: string; AQueue: Boolean);
    { Asks before building from a book that is already a read-along one;
      then CheckOutputThen. }
    procedure CheckBookThen(const ADevice: string; AQueue: Boolean);
  public
    { The keyboard drives the pad's menu while it shows (and opens it in
      Big Picture), before any control has the key. Which key means which
      action is uReaderInput's table (tools/gen_reader_input.py: every
      button and key mapping is defined with the Steam Input actions) -
      no key is named here. A key that means no action, and every key
      while the menu is closed on the desktop, goes on as usual. }
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
  end;

var
  { The window. }
  frmBuilder: TfrmBuilder;

implementation

uses
  System.Character, System.Generics.Defaults, System.SyncObjs,
  // the dark window: TBrushKind, and the style object behind the log
  FMX.Graphics, FMX.Styles.Objects,
  uReaderInput;

{$R *.fmx}

var
  { Open while builds may run; reset by the window while the system goes
    to sleep (Steam's Game Mode - TfrmBuilder.tmSleepTimer). }
  GSleepGate: TEvent;
  { 1 while a build waits at GSleepGate. }
  GBuildPaused: Integer;
  { The Covers folder (TfrmBuilder.FCoverFolder, set before each build):
    the build looks for the book's cover there. }
  GCoverFolder: string;
  { The device "Default" means ('' = whisper.cpp's own choice): set when
    ROCm devices are left out (RocmUnusable) - whisper.cpp would still
    take ROCm0, the first GPU of ggml's list. A build given '' uses it. }
  GDefaultDevice: string;

const
  { Diagnostic switch (command line; Steam: the launch options): builds
    run without whisper.cpp's temperature fallback - a 30 s window whose
    text fails the entropy or probability check is NOT decoded again at a
    higher temperature. To measure what the fallback costs. }
  DIAG_NO_FALLBACK = '--no-fallback';
  { Environment variable with the meaning of DIAG_NO_FALLBACK (any value). }
  DIAG_NO_FALLBACK_ENV = 'EPUBUNUM_NO_FALLBACK';
  { Diagnostic switch: builds load the model without DTW, so word times
    come from whisper.cpp's token time stamps. To measure what DTW costs. }
  DIAG_NO_DTW = '--no-dtw';
  { Environment variable with the meaning of DIAG_NO_DTW (any value). }
  DIAG_NO_DTW_ENV = 'EPUBUNUM_NO_DTW';

{ A diagnostic switch is on: ASwitch is on the command line, or the
  environment variable AEnv has a value.
  @param(ASwitch  the command-line switch, with its dashes)
  @param(AEnv     the environment variable)
  @returns(the answer) }
function DiagSwitch(const ASwitch, AEnv: string): Boolean;
var
  I: Integer;
begin
  Result := Trim(GetEnvironmentVariable(AEnv)) <> '';
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), ASwitch) then
      Result := True;
end;

{ The diagnostic switches that are on, in words for the logs
  ('--no-fallback, --no-dtw'; '' = none: builds are normal builds).
  @returns(the switches) }
function BuildDiagnostics: string;
begin
  Result := '';
  if DiagSwitch(DIAG_NO_FALLBACK, DIAG_NO_FALLBACK_ENV) then
    Result := DIAG_NO_FALLBACK;
  if DiagSwitch(DIAG_NO_DTW, DIAG_NO_DTW_ENV) then
    Result := Result + IfThen(Result = '', '', ', ') + DIAG_NO_DTW;
end;

{ ROCm cannot run here: the launcher found no ROCm kernels for the GPU
  (EPUBUNUM_ROCM_OFF holds why); ROCm's runtime is bundled beside the
  program without rocBLAS's kernels (rocblas/ - the Linux depot kept the
  runtime when the HIP depot was no longer shipped, 2026-11-20); or a
  Steam Deck (gfx1033 is not a ROCm target: a model loaded on its ROCm0
  never came back, 2026-11-20). A ROCm installed on the system is not
  judged.
  @param(AWhy  why, for the log)
  @returns(the answer) }
function RocmUnusable(out AWhy: string): Boolean;
var
  Here: string;
begin
  AWhy := Trim(GetEnvironmentVariable('EPUBUNUM_ROCM_OFF'));
  if AWhy = '' then
  begin
    Here := ExtractFileDir(ParamStr(0));
    try
      if (Length(TDirectory.GetFiles(Here, 'libamdhip64.so*')) > 0) and
        not TDirectory.Exists(TPath.Combine(Here, 'rocblas')) then
        AWhy := 'no ROCm kernels beside the program (rocblas/ missing)';
    except
      // the folder not readable: not judged
    end;
  end;
  if (AWhy = '') and SteamOnDeck then
    AWhy := 'a Steam Deck (gfx1033 is not a ROCm target)';
  Result := AWhy <> '';
end;

{ A ROCm (HIP) device. }
function IsRocmDevice(const ADevice: TWhisperDevice): Boolean;
begin
  Result := SameText(ADevice.Backend, 'ROCm') or SameText(ADevice.Backend, 'HIP') or
    StartsText('ROCm', ADevice.Name);
end;

const
  { The Power row's choices in the settings (cbPower's order). }
  POWER_KEYS: array[0..3] of string = ('Automatic', 'Fastest', 'SavePower', 'Sleep');
  { Settings > Lowest acceptable speed, tenths of real time: the highest
    and the first value (owner, 2026-11-22: "Anything that falls below say
    2.0 is deemed unusable ... drop the allowable device cut-off ... in
    steps from 2.0 down to 0.0"). }
  LOWEST_SPEED_TOP = 20;
  { The "AMD ROCm acceleration" DLC's AppID (Steamworks: a free DLC of
    EpubBuilder whose Linux depot holds ROCm - tools/steam_stage.py's HIP
    folder). 0 = not created yet: nothing is offered. }
  STEAM_DLC_ROCM: Cardinal = 0;
  { Written before each calibration pair, deleted after it: found at
    start-up, the program ended during that pair. Beside the settings. }
  CALIBRATION_MARKER_SUFFIX = '-calibrating.txt';
  { The note of an end from outside (uQuitSignal), beside the settings. }
  QUIT_NOTE_SUFFIX = '-ended.txt';
  { The calibration's lines, beside the settings. }
  CALIBRATION_LOG_SUFFIX = '-calibration.log';
  { The diagnostics' lines (Settings > Diagnostics), beside the settings. }
  DIAGNOSTICS_LOG_SUFFIX = '-diagnostics.log';
  { The prompt given to every 30 s window: punctuated and capitalised, so
    the transcript is too. TWhisper's recommended settings for books
    (its CLAUDE.md; WhisperConsole --no-context --carry-prompt --prompt):
    with DTW word times flash attention is off, and large-v3-turbo with
    flash attention off and the previous text as context falls into
    loops and lower-case run-on text - slowly (the builder's first runs:
    5.8x and 16x instead of ~80x, no capitals, no punctuation). }
  BOOK_PROMPT = 'Once upon a time, there was a story. It was read aloud.';
  { The same prompt in the languages it is written for (BookPrompt): an
    English prompt in every window of a German reading would pull the
    transcript towards English. ASCII source: accented letters as
    character codes. }
  BOOK_PROMPTS: array[0..5, 0..1] of string = (
    ('en', BOOK_PROMPT),
    ('de', 'Es war einmal eine Geschichte. Sie wurde vorgelesen.'),
    ('fr', 'Il '#$E9'tait une fois une histoire. Elle '#$E9'tait lue '#$E0' voix haute.'),
    ('es', 'Hab'#$ED'a una vez una historia. Se le'#$ED'a en voz alta.'),
    ('it', 'C''era una volta una storia. Veniva letta ad alta voce.'),
    ('nl', 'Er was eens een verhaal. Het werd voorgelezen.'));
  { Marks a saved transcript whose word edges were trimmed of silence
    (WhisperTrimWordSilence); one without it is trimmed once when used. }
  TRIMMED_MARK = '"word_edges": "trimmed"';
  { Key of a saved transcript naming the model that made it (file name). }
  MODEL_KEY = 'builder_model';
  { Key of a saved transcript saying when it was made. }
  MADE_KEY = 'builder_made';
  { Shortest stretch of not-matched words listed in the results. }
  REGION_MIN_WORDS = 3;
  { Most stretches listed. }
  REGIONS_SHOWN = 10;
  { Words quoted from a stretch. }
  QUOTE_WORDS = 10;
  { Kept beside the output: '<output name>.transcript.json'. }
  TRANSCRIPT_SUFFIX = '.transcript.json';
  { The transcription so far of a build stopped part way, beside the
    output; gone once the whole transcript is saved. }
  PARTIAL_SUFFIX = '.transcript-partial.json';
  { Key of the partial transcript: the parts in it. }
  PARTS_DONE_KEY = 'builder_parts_done';
  { Key of the partial transcript: the language heard. }
  LANGUAGE_KEY = 'builder_language';
  { Key of the partial transcript: the time its parts took, s. }
  SECONDS_KEY = 'builder_seconds';
  { Rows and buttons, px. }
  ROW_HEIGHT = 30;
  { Gap between controls, px. }
  GAP = 6;

{ TStringList.CustomSort order of file names as people read them
  (WhisperNaturalCompare of the names without folders). }
function NaturalFileOrder(AList: TStringList; A, B: Integer): Integer;
begin
  Result := WhisperNaturalCompare(ExtractFileName(AList[A]), ExtractFileName(AList[B]));
end;

{ Where the settings live: the EpubUnum settings folder shared with
  EpubReader (uEpubUnum) - Windows %APPDATA%\EpubUnum\EpubBuilder.ini,
  macOS ~/Library/Application Support/EpubUnum/EpubBuilder.ini, Linux
  $XDG_CONFIG_HOME (else ~/.config)/EpubUnum/EpubBuilder.ini. }
function SettingsFile: string;
begin
  // the folder shared with EpubReader (uEpubUnum; owner, 2026-11-20)
  Result := TPath.Combine(EpubUnumConfigFolder, 'EpubBuilder.ini');
end;

const
  { Book files besides EPUB: Mobipocket / Kindle (converted by Epub.Mobi). }
  MOBI_EXTS: array[0..3] of string = ('.mobi', '.prc', '.azw', '.azw3');

{ The EPUB to build from for the book ABookFile: the file itself for an
  EPUB; for a MOBI (owner, 2026-11-20) an EPUB 3 converted from it, kept
  in the settings' Converted folder and made again when the MOBI is newer.
  Raises for a MOBI that cannot be read (DRM, ...).
  @param(ABookFile  the book chosen)
  @param(ANote  what was done, for the log ('' for an EPUB))
  @returns(the EPUB's path) }
function BookAsEpub(const ABookFile: string; out ANote: string): string;
var
  Folder, Temp: string;
  Info: TMobiInfo;
  Src, Made: TDateTime;
begin
  ANote := '';
  Result := ABookFile;
  if SameText(ExtractFileExt(ABookFile), '.epub') or not MobiIsMobi(ABookFile) then
    Exit;
  Folder := TPath.Combine(ExtractFilePath(SettingsFile), 'Converted');
  ForceDirectories(Folder);
  Result := TPath.Combine(Folder, ChangeFileExt(ExtractFileName(ABookFile), '') + '.epub');
  if FileAge(ABookFile, Src) and FileAge(Result, Made) and (Made >= Src) then
  begin
    ANote := 'MOBI: converted to EPUB 3 before - ' + Result;
    Exit;
  end;
  // written whole, then put in place
  Temp := Result + '.new';
  MobiToEpub(ABookFile, Temp, Info);
  if FileExists(Result) then
    TFile.Delete(Result);
  TFile.Move(Temp, Result);
  ANote := 'MOBI converted to EPUB 3: ' + MobiInfoText(Info) + ' - ' + Result;
end;

{ The books in AFolder and below: EPUB and MOBI files, the extension in
  any case (Linux's file patterns tell .MOBI from .mobi). }
function BookFilesIn(const AFolder: string): TArray<string>;
begin
  Result := TDirectory.GetFiles(AFolder, '*', TSearchOption.soAllDirectories,
    function(const APath: string; const ASearchRec: TSearchRec): Boolean
    var
      Ext: string;
    begin
      Ext := ExtractFileExt(ASearchRec.Name);
      Result := SameText(Ext, '.epub') or (IndexText(Ext, MOBI_EXTS) >= 0);
    end);
end;

{ The language of a book's dc:language ('en-US' -> 'en'), lower case;
  '' when it has none. }
function PrimaryLanguage(const ATag: string): string;
var
  P: Integer;
begin
  Result := LowerCase(Trim(ATag));
  P := Pos('-', Result);
  if P = 0 then
    P := Pos('_', Result);
  if P > 0 then
    Result := Copy(Result, 1, P - 1);
end;

{ The prompt for a book in language ALanguage ('de'); '' when there is
  none for it (then no prompt: each window still on its own, so no loops,
  but the text may lose capitals and punctuation - the aligner ignores
  both). An unknown language ('') gets the English one. }
function BookPrompt(const ALanguage: string): string;
var
  I: Integer;
begin
  if ALanguage = '' then
    Exit(BOOK_PROMPT);
  for I := 0 to High(BOOK_PROMPTS) do
    if BOOK_PROMPTS[I, 0] = ALanguage then
      Exit(BOOK_PROMPTS[I, 1]);
  Result := '';
end;

{ The transcript file kept for AOutFile. }
{ AText as the inside of a JSON string ('\' and '"' escaped). }
function JsonText(const AText: string): string;
begin
  Result := StringReplace(AText, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
end;

{ The string value of key AKey near the start of a saved transcript
  (the builder's own keys come first; '' when not there). }
function SavedKey(const AJson, AKey: string): string;
var
  Head: string;
  P, E: Integer;
begin
  Result := '';
  Head := Copy(AJson, 1, 2000);
  P := Pos('"' + AKey + '": "', Head);
  if P = 0 then
    Exit;
  P := P + Length(AKey) + 5;
  E := P;
  while (E <= Length(Head)) and (Head[E] <> '"') do
  begin
    if Head[E] = '\' then
      Inc(E);
    Inc(E);
  end;
  Result := StringReplace(StringReplace(Copy(Head, P, E - P), '\"', '"', [rfReplaceAll]), '\\', '\',
    [rfReplaceAll]);
end;

function TranscriptFileOf(const AOutFile: string): string;
begin
  Result := ChangeFileExt(AOutFile, '') + TRANSCRIPT_SUFFIX;
end;

{ The partial transcript kept for AOutFile while it is built. }
function PartialFileOf(const AOutFile: string): string;
begin
  Result := ChangeFileExt(AOutFile, '') + PARTIAL_SUFFIX;
end;

{ TBuildThread }

constructor TBuildThread.Create(const ABookFile: string; AAudioFiles: TStrings; const AModelFile, ADevice,
  AOutFile: string; AChapters, AReuse: Boolean; const AForceLanguage: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FBookFile := ABookFile;
  FAudioFiles := TStringList.Create;
  FAudioFiles.Assign(AAudioFiles);
  FModelFile := AModelFile;
  FDevice := ADevice;
  // "Default" when ROCm is left out: the first other GPU, not whisper.cpp's
  // ROCm0 (queued jobs of before included)
  if FDevice = '' then
    FDevice := GDefaultDevice;
  FOutFile := AOutFile;
  FJsonFile := TranscriptFileOf(AOutFile);
  FPartialFile := PartialFileOf(AOutFile);
  FChapters := AChapters;
  FReuse := AReuse;
  FForceLanguage := AForceLanguage;
  // a diagnostic build always transcribes: a saved transcript has no speed
  FDiagnostic := BuildDiagnostics;
  if FDiagnostic <> '' then
    FReuse := False;
end;

destructor TBuildThread.Destroy;
begin
  FAudioFiles.Free;
  inherited;
end;

procedure TBuildThread.Cancel;
var
  R: TWhisperRun;
begin
  Terminate;
  R := FRun;
  if R <> nil then
    R.Cancel;
end;

procedure TBuildThread.PausePoint;
var
  T: TDateTime;
  S: Double;
begin
  // the window opens the gate: never wait on its thread
  if (GSleepGate.WaitFor(0) = wrSignaled) or (TThread.CurrentThread.ThreadID = MainThreadID) then
    Exit;
  T := Now;
  TInterlocked.Exchange(GBuildPaused, 1);
  try
    Log('Paused: the system is going to sleep (the build goes on when it wakes)');
    while not Terminated and (GSleepGate.WaitFor(250) <> wrSignaled) do
      ;
  finally
    TInterlocked.Exchange(GBuildPaused, 0);
  end;
  S := MilliSecondsBetween(Now, T) / 1000;
  FPausedSeconds := FPausedSeconds + S;
  Log(Format('Going on after the sleep (paused %s)', [WhisperTimeToStr(Round(S * 100))]));
end;

procedure TBuildThread.SavePartial(const AResult: TWhisperTranscription; const AParts: TWhisperAudioPartArray;
  ADone: Integer; const ALanguage: string; ASeconds: Double);
var
  Json, Keys: string;
  P: Integer;
begin
  try
    Json := WhisperTranscriptionToJson(AResult, AParts);
    Keys := sLineBreak + '  "' + MODEL_KEY + '": "' + JsonText(ExtractFileName(FModelFile)) + '",' +
      sLineBreak + '  "' + PARTS_DONE_KEY + '": "' + IntToStr(ADone) + '",' +
      sLineBreak + '  "' + LANGUAGE_KEY + '": "' + JsonText(ALanguage) + '",' +
      sLineBreak + '  "' + SECONDS_KEY + '": "' + FloatToStr(ASeconds, TFormatSettings.Invariant) + '",';
    P := Pos('{', Json);
    Insert(Keys, Json, P + 1);
    // written whole, then put in place: a stop while writing keeps the last
    WhisperSaveTextFile(FPartialFile + '.new', Json);
    if FileExists(FPartialFile) then
      TFile.Delete(FPartialFile);
    TFile.Move(FPartialFile + '.new', FPartialFile);
  except
    on E: Exception do
      Log('The transcription so far could not be kept (' + E.Message + ')');
  end;
end;

function TBuildThread.ReadPartial(const AParts: TWhisperAudioPartArray; out AResult: TWhisperTranscription;
  out ADone: Integer; out ALanguage: string; out ASeconds: Double): Boolean;
var
  Json, Model: string;
  Saved: TWhisperAudioPartArray;
  I: Integer;
begin
  Result := False;
  AResult := Default(TWhisperTranscription);
  ADone := 0;
  ALanguage := '';
  ASeconds := 0;
  if not FileExists(FPartialFile) then
    Exit;
  try
    Json := WhisperLoadTextFile(FPartialFile);
    Model := SavedKey(Json, MODEL_KEY);
    if not SameText(Model, ExtractFileName(FModelFile)) then
    begin
      Log(Format('A build stopped part way was made with %s, and %s is chosen: starting from the first part',
        [Model, ExtractFileName(FModelFile)]));
      Exit;
    end;
    ADone := StrToIntDef(SavedKey(Json, PARTS_DONE_KEY), 0);
    ALanguage := SavedKey(Json, LANGUAGE_KEY);
    ASeconds := StrToFloatDef(SavedKey(Json, SECONDS_KEY), 0, TFormatSettings.Invariant);
    AResult := WhisperTranscriptionFromJson(Json, Saved);
  except
    on E: Exception do
    begin
      Log(Format('A build stopped part way cannot be read (%s): starting from the first part', [E.Message]));
      Exit;
    end;
  end;
  if (ADone <= 0) or (ADone > Length(AParts)) or (Length(Saved) <> Length(AParts)) then
  begin
    Log('A build stopped part way was made from other audio: starting from the first part');
    Exit;
  end;
  for I := 0 to High(AParts) do
    if not SameFileName(Saved[I].FileName, AParts[I].FileName) or not SameValue(Saved[I].Start, AParts[I].Start,
      0.01) then
    begin
      Log('A build stopped part way was made from other audio: starting from the first part');
      Exit;
    end;
  Result := True;
end;

procedure TBuildThread.Log(const AText: string);
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

procedure TBuildThread.Progress(APercent: Double);
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

procedure TBuildThread.AudioLength(ASeconds: Double);
var
  P: TProc<Double>;
begin
  P := FOnAudioLength;
  if Assigned(P) then
    TThread.Queue(nil,
      procedure
      begin
        P(ASeconds);
      end);
end;

procedure TBuildThread.Status(const AText: string);
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

procedure TBuildThread.RunSegment(Sender: TObject; const ASegment: TWhisperSegment);
begin
  // between two 30 s windows: the graphics card is idle here
  PausePoint;
  Status(Format('Part %d of %d at %s: %s', [FPartNo, FPartCount,
    WhisperTimeToStr(ASegment.T0 + Round(FPartOffset * WHISPER_TICKS_PER_SECOND)), Trim(ASegment.Text)]));
end;

procedure TBuildThread.RunProgress(Sender: TObject; AProgress: Integer);
begin
  PausePoint;
  // the transcription is most of the work: 5 .. 90 %
  if FTotalSeconds > 0 then
    Progress(5 + 85 * (FDoneSeconds + FPartSeconds * AProgress / 100) / FTotalSeconds);
end;

function TBuildThread.OpenFFmpeg: TFFmpegLibrary;
begin
  // shared with the calibration (uCalibration)
  Result := OpenBuilderFFmpeg;
end;

function TBuildThread.ReadSaved(const AParts: TWhisperAudioPartArray; out AResult: TWhisperTranscription;
  out ASavedParts: TWhisperAudioPartArray): Boolean;
var
  I: Integer;
  Json: string;
begin
  Result := False;
  AResult := Default(TWhisperTranscription);
  ASavedParts := nil;
  FSavedModel := '';
  FSavedMade := '';
  if not FReuse then
    Exit;
  if not FileExists(FJsonFile) then
  begin
    Log('No saved transcript for this output (' + ExtractFileName(FJsonFile) + '): transcribing');
    Exit;
  end;
  try
    Json := WhisperLoadTextFile(FJsonFile);
    FSavedModel := SavedKey(Json, MODEL_KEY);
    FSavedMade := SavedKey(Json, MADE_KEY);
    // another model: a reason to transcribe again, so the old words are
    // not trusted (owner)
    if (FModelFile <> '') and (FSavedModel <> '') and
      not SameText(ExtractFileName(FSavedModel), ExtractFileName(FModelFile)) then
    begin
      Log(Format('The saved transcript was made with %s, and %s is chosen: transcribing again',
        [FSavedModel, ExtractFileName(FModelFile)]));
      Exit;
    end;
    AResult := WhisperTranscriptionFromJson(Json, ASavedParts);
  except
    on E: Exception do
    begin
      Log(Format('The saved transcript %s cannot be read (%s): transcribing again', [FJsonFile, E.Message]));
      Exit;
    end;
  end;
  // the same files cut into the same parts, or it belongs to other audio
  if Length(ASavedParts) <> Length(AParts) then
  begin
    Log('The saved transcript was made from other audio: transcribing again');
    Exit;
  end;
  for I := 0 to High(AParts) do
    if not SameFileName(ASavedParts[I].FileName, AParts[I].FileName) or
      not SameValue(ASavedParts[I].Start, AParts[I].Start, 0.01) then
    begin
      Log('The saved transcript was made from other audio: transcribing again');
      Exit;
    end;
  if Length(AResult.Words) = 0 then
    Exit;
  if FSavedModel = '' then
    Log(Format('USING THE SAVED TRANSCRIPT %s (%d words; made before the builder recorded the model and ' +
      'the date) - untick "Use a saved transcript" to transcribe again', [FJsonFile, Length(AResult.Words)]))
  else
    Log(Format('USING THE SAVED TRANSCRIPT %s (%d words), made %s with %s - untick "Use a saved ' +
      'transcript" to transcribe again', [FJsonFile, Length(AResult.Words), IfThen(FSavedMade = '',
      '(date not recorded)', FSavedMade), FSavedModel]));
  Result := True;
end;

procedure TBuildThread.TrimSaved(var AResult: TWhisperTranscription; AAudio: TWhisperAudioSet);
var
  I, K, First, N: Integer;
  Ofs, Next: Int64;
  Part: TWhisperTranscription;
  Samples: TWhisperSamples;
begin
  Log('The saved transcript is from before word edges were trimmed of silence: trimming them now from the ' +
    'audio (once - it is saved again)');
  K := 0;
  for I := 0 to High(AAudio.Parts) do
  begin
    if Terminated then
      Exit;
    Status(Format('Trimming word edges: part %d of %d ...', [I + 1, Length(AAudio.Parts)]));
    Progress(5 + 85 * (I + 1) / Length(AAudio.Parts));
    Samples := AAudio.Read(I);
    Ofs := Round(AAudio.Parts[I].Offset * WHISPER_TICKS_PER_SECOND);
    if I < High(AAudio.Parts) then
      Next := Round(AAudio.Parts[I + 1].Offset * WHISPER_TICKS_PER_SECOND)
    else
      Next := High(Int64);
    // the words of this part (in time order), moved onto its own time line
    First := K;
    while (K <= High(AResult.Words)) and (AResult.Words[K].T0 < Next) do
      Inc(K);
    N := K - First;
    if N = 0 then
      Continue;
    Part := Default(TWhisperTranscription);
    Part.Words := Copy(AResult.Words, First, N);
    for N := 0 to High(Part.Words) do
    begin
      Dec(Part.Words[N].T0, Ofs);
      Dec(Part.Words[N].T1, Ofs);
    end;
    WhisperTrimWordSilence(Part, Samples);
    for N := 0 to High(Part.Words) do
    begin
      AResult.Words[First + N].T0 := Part.Words[N].T0 + Ofs;
      AResult.Words[First + N].T1 := Part.Words[N].T1 + Ofs;
    end;
  end;
end;

procedure TBuildThread.SaveTranscript(const AResult: TWhisperTranscription; const AParts: TWhisperAudioPartArray;
  const AModel, AMade: string);
var
  Json, Keys: string;
  P: Integer;
begin
  Json := WhisperTranscriptionToJson(AResult, AParts);
  // keys of its own after the opening brace (the reader ignores keys it
  // does not know)
  Keys := sLineBreak + '  ' + TRIMMED_MARK + ',';
  if AModel <> '' then
    Keys := Keys + sLineBreak + '  "' + MODEL_KEY + '": "' + JsonText(AModel) + '",';
  if AMade <> '' then
    Keys := Keys + sLineBreak + '  "' + MADE_KEY + '": "' + JsonText(AMade) + '",';
  P := Pos('{', Json);
  Insert(Keys, Json, P + 1);
  WhisperSaveTextFile(FJsonFile, Json);
end;

procedure TBuildThread.LogTimings(AModel: TWhisperModel; const ANote: string);
var
  Lib: TWhisperLib;
begin
  Lib := TWhisperLib.Instance;
  if not Assigned(Lib.Flat.whisper_print_timings) then
    Exit;
  DebugLog(Format('timings: part %d of %d, %s (times and runs since the part began; fallbacks p / h since ' +
    'the model was loaded)', [FPartNo, FPartCount, ANote]));
  // through whisper.cpp's log: the "whisper.cpp: whisper_print_timings"
  // lines that follow in the debug log
  Lib.Flat.whisper_print_timings(AModel.Handle);
end;

function TBuildThread.Transcribe(AAudio: TWhisperAudioSet): TWhisperTranscription;
var
  Lib: TWhisperLib;
  CP: TWhisperContextParams;
  Model: TWhisperModel;
  Params: TWhisperParams;
  Samples: TWhisperSamples;
  Part: TWhisperTranscription;
  I, Done, Kept, J, Edge, PartWords: Integer;
  Started, RunStarted, PieceStarted: TDateTime;
  Prompt, Heard: string;
  Paused, PiecePaused, PartSeconds: Double;
  // a part's pieces: sample indices, a piece from each to the next
  Pieces: TArray<Integer>;
  Piece: TWhisperSamples;
  Timed, Stop: Boolean;
begin
  Result := Default(TWhisperTranscription);
  RunStarted := Now;
  Lib := TWhisperLib.Instance;
  CP := Lib.DefaultContextParams;
  if not Lib.ContextParamsFor(FDevice, CP) then
    raise EWhisperError.CreateFmt('Device %s cannot be used', [FDevice]);
  if DiagSwitch(DIAG_NO_DTW, DIAG_NO_DTW_ENV) then
  begin
    // flash attention stays off as in a normal build (DTW turns it off):
    // only DTW differs, not the arithmetic of the attention
    CP.flash_attn := False;
    Log('DIAGNOSTIC ' + DIAG_NO_DTW + ': the model is loaded without DTW - word times come from token time ' +
      'stamps (less accurate), flash attention off as with DTW');
  end
  // word times by DTW: the alignment heads of this model
  else if not WhisperEnableDtw(FModelFile, CP) then
    Log('The model header cannot be read for DTW: word times come from token time stamps');
  Log(Format('Loading %s ...', [ExtractFileName(FModelFile)]));
  DebugLog(Format('model %s, device "%s", GPU %s', [FModelFile, FDevice, BoolToStr(CP.use_gpu, True)]));
  Model := TWhisperModel.Create(FModelFile, CP);
  DebugLog('model loaded');
  Params := TWhisperParams.Create;
  try
    Log(Format('Model: %s on %s', [Model.Description, BuilderDeviceText(FDevice)]));
    // transcribe, never translate: the words must be the book's own
    Params.Translate := False;
    // the book's language when Whisper knows it (else Whisper detects it)
    if (FLanguage <> '') and (Lib.LanguageId(FLanguage) >= 0) then
      Params.Language := FLanguage;
    // each window on its own, with a punctuated prompt in that language
    Prompt := BookPrompt(FLanguage);
    Params.NoContext := True;
    Params.MaxTextContext := 0;
    Params.InitialPrompt := Prompt;
    Params.CarryInitialPrompt := Prompt <> '';
    if DiagSwitch(DIAG_NO_FALLBACK, DIAG_NO_FALLBACK_ENV) then
    begin
      // whisper.cpp: no increment = the first temperature only
      Params.TemperatureInc := 0;
      Log('DIAGNOSTIC ' + DIAG_NO_FALLBACK + ': no temperature fallback - a window whose text fails ' +
        'whisper.cpp''s checks is kept as first decoded, not decoded again');
    end;
    if Prompt <> '' then
      Log(Format('Transcribing in %s, each 30 s window on its own, with a punctuated prompt (TWhisper''s ' +
        'settings for books)', [Params.Language]))
    else
      Log(Format('Transcribing in %s, each 30 s window on its own; no prompt for this language yet, so the ' +
        'text may lack capitals and punctuation (the alignment does not need them)', [Params.Language]));
    DebugLog('starting the transcription');
    FRun := TWhisperRun.Create(Model, Params);
    try
      FRun.IncludeWords := True;
      FRun.OnProgress := RunProgress;
      FRun.OnSegment := RunSegment;
      FDoneSeconds := 0;
      FPartCount := Length(AAudio.Parts);
      // a build of this book stopped part way: on from the next part
      Done := 0;
      if (FDiagnostic = '') and not FBenchmark and ReadPartial(AAudio.Parts, Result, Done, Heard,
        FPriorSeconds) then
      begin
        if (Heard <> '') and SameText(Params.Language, WHISPER_LANGUAGE_AUTO) then
          Params.Language := Heard;
        for I := 0 to Done - 1 do
          FDoneSeconds := FDoneSeconds + AAudio.Parts[I].Duration;
        Log(Format('GOING ON FROM PART %d of %d: parts 1 - %d (%d words) were transcribed by a build that was ' +
          'stopped part way (kept in %s)', [Done + 1, FPartCount, Done, Length(Result.Words),
          ExtractFileName(FPartialFile)]));
      end;
      Kept := Done;
      for I := Done to High(AAudio.Parts) do
      begin
        PausePoint;
        if Terminated then
          Break;
        Started := Now;
        Paused := FPausedSeconds;
        FPartNo := I + 1;
        FPartOffset := AAudio.Parts[I].Offset;
        Status(Format('Part %d of %d "%s": decoding the audio ...', [I + 1, FPartCount, AAudio.Parts[I].Title]));
        Samples := AAudio.Read(I);
        FPartSeconds := WhisperSamplesSeconds(Samples);
        if Length(Samples) = 0 then
          Continue;
        Status(Format('Part %d of %d "%s": transcribing (the words appear as they are heard) ...', [I + 1,
          FPartCount, AAudio.Parts[I].Title]));
        // a benchmark: the part in three pieces, the middle one (chapter
        // material) timed; a build: the part whole, as one piece
        Edge := Round(BENCH_EDGE_SECONDS * WHISPER_SAMPLE_RATE);
        if FBenchmark and (Length(Samples) >= 3 * Edge) then
          Pieces := [0, Edge, Length(Samples) - Edge, Length(Samples)]
        else
          Pieces := [0, Length(Samples)];
        PartSeconds := FPartSeconds;
        PartWords := 0;
        Stop := False;
        for J := 0 to High(Pieces) - 1 do
        begin
          if Length(Pieces) = 2 then
            Piece := Samples
          else
            Piece := Copy(Samples, Pieces[J], Pieces[J + 1] - Pieces[J]);
          FPartSeconds := WhisperSamplesSeconds(Piece);
          // the status's times: on the joined time line
          FPartOffset := AAudio.Parts[I].Offset + Pieces[J] / WHISPER_SAMPLE_RATE;
          Timed := FBenchmark and (Length(Pieces) = 4) and (J = 1);
          PieceStarted := Now;
          PiecePaused := FPausedSeconds;
          if Timed then
          begin
            // the progress view's clock runs from here (BenchElapsed)
            FBenchPaused := PiecePaused;
            FBenchFrom := PieceStarted;
          end;
          // the timings below are this part's (the fallback counts are not:
          // LogTimings)
          if Assigned(Lib.Flat.whisper_reset_timings) then
            Lib.Flat.whisper_reset_timings(Model.Handle);
          Part := FRun.Execute(Piece);
          if Part.Cancelled then
          begin
            FBenchFrom := 0;
            Stop := True;
            Break;
          end;
          LogTimings(Model, 'the first pass');
          // a part that failed ends the build: going on gave a book with
          // part of its audio timed, reported as done, and kept the cut
          // transcript "for next time" (review, zip 73)
          if Part.ResultCode <> 0 then
          begin
            if (Kept > 0) and not FBenchmark then
              Log(Format('Parts 1 - %d are kept (%s): building it again goes on from part %d', [Kept,
                ExtractFileName(FPartialFile), Kept + 1]));
            raise EWhisperError.CreateFmt('Part %d of %d "%s" was not transcribed: %s', [I + 1, FPartCount,
              AAudio.Parts[I].Title, Part.ErrorMessage]);
          end;
          // as WhisperConsole: take out loops and echoes, then a second pass
          // over the stretches left without words
          WhisperCleanTranscription(Part, Prompt);
          Status(Format('Part %d of %d: second pass over stretches left without words ...', [I + 1, FPartCount]));
          FRun.FillGaps(Piece, Part);
          LogTimings(Model, 'with the second pass');
          if Timed then
          begin
            // the clock stops: the piece's time goes into the sum
            FBenchFrom := 0;
            // the chapter material's time; the time asleep is not its
            FSummary.BenchAudioSeconds := FSummary.BenchAudioSeconds + FPartSeconds;
            FSummary.BenchSeconds := FSummary.BenchSeconds + MilliSecondsBetween(Now, PieceStarted) / 1000 -
              (FPausedSeconds - PiecePaused);
          end;
          // the pause before a word is not the word: DTW starts the first
          // word after a pause in it (the next sentence lit too early)
          WhisperTrimWordSilence(Part, Piece);
          WhisperAppendTranscription(Result, Part, AAudio.Parts[I].Offset + Pieces[J] / WHISPER_SAMPLE_RATE);
          Inc(PartWords, Length(Part.Words));
          // keep the language the first part was heard in
          if SameText(Params.Language, WHISPER_LANGUAGE_AUTO) and (Part.LanguageCode <> '') then
            Params.Language := Part.LanguageCode;
          FDoneSeconds := FDoneSeconds + FPartSeconds;
        end;
        Piece := nil;
        FPartSeconds := PartSeconds;
        if Stop then
          Break;
        // the time paused for sleep is not the part's
        Log(Format('Part %d of %d "%s": %.0f s of audio, %d words, %.1f s', [I + 1, Length(AAudio.Parts),
          AAudio.Parts[I].Title, FPartSeconds, PartWords, MilliSecondsBetween(Now, Started) / 1000 -
          (FPausedSeconds - Paused)]));
        // kept part by part: a stop (Steam's Exit Game, a crash, Cancel)
        // loses at most the part being transcribed
        Kept := I + 1;
        if (FDiagnostic = '') and not FBenchmark then
          SavePartial(Result, AAudio.Parts, Kept, Params.Language, FPriorSeconds +
            MilliSecondsBetween(Now, RunStarted) / 1000 - FPausedSeconds);
      end;
      if Terminated and not FBenchmark and (Kept > 0) and (Kept < Length(AAudio.Parts)) then
        Log(Format('Stopped after part %d of %d: parts 1 - %d are kept (%s) - building it again goes on from ' +
          'part %d', [Kept, FPartCount, Kept, ExtractFileName(FPartialFile), Kept + 1]));
    finally
      FreeAndNil(FRun);
    end;
  finally
    Params.Free;
    Model.Free;
  end;
end;

function TBuildThread.BenchElapsed: Double;
var
  From: TDateTime;
begin
  Result := FSummary.BenchSeconds;
  From := FBenchFrom;
  if From <> 0 then
    Result := Result + Max(0.0, MilliSecondsBetween(Now, From) / 1000 - (FPausedSeconds - FBenchPaused));
end;

procedure TBuildThread.ScoreBenchmark(const AAligned: TWhisperAlignedWordArray;
  const AParts: TWhisperAudioPartArray);
var
  Ranges: TArray<Double>;
  I, K: Integer;
  T: Double;
begin
  FSummary.Benchmark := True;
  FSummary.BenchWords := 0;
  FSummary.BenchMatched := 0;
  // the chapter material on the joined time line: the parts transcribed
  // in three pieces (Transcribe), each without its two edges
  Ranges := nil;
  for I := 0 to High(AParts) do
    if AParts[I].Duration * WHISPER_SAMPLE_RATE >= 3 * Round(BENCH_EDGE_SECONDS * WHISPER_SAMPLE_RATE) then
      Ranges := Ranges + [AParts[I].Offset + BENCH_EDGE_SECONDS,
        AParts[I].Offset + AParts[I].Duration - BENCH_EDGE_SECONDS];
  // the words timed in it, as the verdict counts them (not spoken words
  // have no time)
  for I := 0 to High(AAligned) do
  begin
    if (AAligned[I].T0 < 0) or not (AAligned[I].Match in [wamExact, wamSimilar, wamInterpolated, wamNotHeard,
      wamMoved]) then
      Continue;
    T := AAligned[I].T0 / WHISPER_TICKS_PER_SECOND;
    K := 0;
    while K < High(Ranges) do
    begin
      if (T >= Ranges[K]) and (T < Ranges[K + 1]) then
      begin
        Inc(FSummary.BenchWords);
        if AAligned[I].Match in [wamExact, wamSimilar] then
          Inc(FSummary.BenchMatched);
        Break;
      end;
      Inc(K, 2);
    end;
  end;
  Log('');
  if (FSummary.BenchSeconds > 0) and (FSummary.BenchWords > 0) then
    Log(Format('BENCHMARK - chapter material only (every section without its first and last %d s): %s of ' +
      'audio transcribed in %s = %.1fx real time; %d of its %d words (%.1f %%) heard as the book has them, ' +
      'exactly or nearly', [BENCH_EDGE_SECONDS, WhisperTimeToStr(Round(FSummary.BenchAudioSeconds * 100)),
      WhisperTimeToStr(Round(FSummary.BenchSeconds * 100)), FSummary.BenchAudioSeconds / FSummary.BenchSeconds,
      FSummary.BenchMatched, FSummary.BenchWords, FSummary.BenchMatched * 100 / FSummary.BenchWords]))
  else
    Log('BENCHMARK - no chapter material was timed (no section long enough)');
end;

procedure TBuildThread.LogResults(const AStats: TWhisperAlignStats; AHeard: Integer;
  const ASplit: TWhisperStringArray; const AAligned: TWhisperAlignedWordArray;
  const ARegions: TWhisperAlignRegionArray);
var
  Timed, Matched, I, K, Shown, Edges, FirstRead, LastRead, Listed: Integer;
  Share: Double;
  Quote, Where, Verdict: string;
  Regions: TWhisperAlignRegionArray;

  { ACount as 'N (P %)' of the book words. }
  function Part(ACount: Integer): string;
  begin
    if AStats.BookWords > 0 then
      Result := Format('%d (%.1f %%)', [ACount, ACount * 100 / AStats.BookWords])
    else
      Result := IntToStr(ACount);
  end;

begin
  Timed := AStats.Exact + AStats.Similar + AStats.Interpolated + AStats.NotHeard + AStats.Moved;
  Matched := AStats.Exact + AStats.Similar;
  Log('');
  Log(Format('RESULTS - %d words in the book (to the aligner), %d heard by Whisper', [AStats.BookWords, AHeard]));
  Log('  Exact:        ' + Part(AStats.Exact) + ' - heard as the book has it; timed by what was heard.');
  Log('  Similar:      ' + Part(AStats.Similar) + ' - heard a little differently (a name, a spelling, an ' +
    'old word); timed by what was heard.');
  Log('  Moved:        ' + Part(AStats.Moved) + ' - read in another place than the book has them (a ' +
    'footnote read where it is called); timed where they were read.');
  Log('  Interpolated: ' + Part(AStats.Interpolated) + ' - not heard clearly between heard words; timed by ' +
    'sharing out the time between them (worth a listen when there are many in a row).');
  Log('  Not heard:    ' + Part(AStats.NotHeard) + ' - a silence in the transcript where the book goes on; ' +
    'timed like interpolated words.');
  Log('  Not spoken:   ' + Part(AStats.NotSpoken) + ' - in the book but not in the recording (title pages, ' +
    'notes, a licence); left without highlight.');
  if Timed > 0 then
    Share := Matched * 100 / Timed
  else
    Share := 0;
  FSummary.HeardWords := AHeard;
  FSummary.Stats := AStats;
  FSummary.Matched := Share;
  if Share >= 98 then
    FSummary.Verdict := 'very good'
  else if Share >= 93 then
    FSummary.Verdict := 'good'
  else if Share >= 80 then
    FSummary.Verdict := 'usable'
  else
    FSummary.Verdict := 'poor';
  if Share >= 98 then
    Verdict := 'very good'
  else if Share >= 93 then
    Verdict := 'good'
  else if Share >= 80 then
    Verdict := 'usable - listen to the stretches below'
  else
    Verdict := 'poor - is this the right recording for this book (or the right order of files)?';
  Log(Format('  Verdict: %.1f %% of the timed words were matched to what was heard: %s.', [Share, Verdict]));
  // not spoken before the first or after the last word read is front and
  // back matter (a title page, a licence, about the author): normal.
  // Inside the book it is text the recording leaves out - or audio missing
  // from the list. Words read count by their place in the book: exact or
  // similar (moved words - footnotes read where they are called - may sit
  // after the back matter and do not count).
  FirstRead := -1;
  LastRead := -1;
  for I := 0 to High(AAligned) do
    if AAligned[I].Match in [wamExact, wamSimilar] then
    begin
      if FirstRead < 0 then
        FirstRead := I;
      LastRead := I;
    end;
  if FirstRead < 0 then
  begin
    // nothing read: no front or back matter to tell apart
    FirstRead := 0;
    LastRead := High(AAligned);
  end;
  Edges := 0;
  for I := 0 to High(ARegions) do
    if (ARegions[I].Match = wamNotSpoken) and ((ARegions[I].Last < FirstRead) or (ARegions[I].First > LastRead)) then
      Inc(Edges, ARegions[I].Last - ARegions[I].First + 1);
  FSummary.EdgeWords := Edges;
  if Edges > 0 then
    Log(Format('  Of the not spoken words, %d are before the first or after the last word read: front and back ' +
      'matter, normal (not listed below; the text is still in the book).', [Edges]));
  // a tenth of the book or more around what was read is more than title
  // pages and a licence: extras in the EPUB (an introduction, a preview,
  // another book) or a recording of only part of the book - the verdict
  // counts only the timed words and does not show it
  if Edges > AStats.BookWords div 10 then
    Log(Format('  %d words (%.1f %%) are before the first or after the last word read - more front and back ' +
      'matter than a book usually has: extras in the EPUB, another edition, or a recording of only part of ' +
      'the book. Check where the reading starts and ends.', [Edges, Edges * 100 / AStats.BookWords]));
  if AStats.NotSpoken - Edges > AStats.BookWords div 10 then
    Log(Format('  %d words inside the book are not in the recording: check that every audio file is in the ' +
      'list, in order.', [AStats.NotSpoken - Edges]));
  // the longest stretches first (a copy: shown ones are marked in it);
  // front and back matter left out - still in the book, only not listed
  Regions := Copy(ARegions, 0, Length(ARegions));
  for I := 0 to High(Regions) do
    if (Regions[I].Match = wamNotSpoken) and ((Regions[I].Last < FirstRead) or (Regions[I].First > LastRead)) then
      Regions[I].Last := Regions[I].First - 1;
  Listed := 0;
  for I := 0 to High(Regions) do
    if Regions[I].Last >= Regions[I].First then
      Inc(Listed);
  if Listed = 0 then
    Exit;
  Log(Format('  Stretches of %d or more words worth a look (longest first, at most %d):', [REGION_MIN_WORDS,
    REGIONS_SHOWN]));
  Shown := 0;
  while Shown < Min(REGIONS_SHOWN, Listed) do
  begin
    K := -1;
    for I := 0 to High(Regions) do
      if (Regions[I].Last >= Regions[I].First) and
        ((K < 0) or (Regions[I].Last - Regions[I].First > Regions[K].Last - Regions[K].First)) then
        K := I;
    if K < 0 then
      Break;
    Quote := '';
    for I := Regions[K].First to Min(Regions[K].Last, Regions[K].First + QUOTE_WORDS - 1) do
      Quote := Quote + ' ' + ASplit[I];
    if Regions[K].Last - Regions[K].First >= QUOTE_WORDS then
      Quote := Quote + ' ...';
    if Regions[K].Time < 0 then
      Where := 'before the recording starts'
    else
      Where := 'at ' + WhisperTimeToStr(Regions[K].Time);
    Log(Format('    %d words %s, %s:%s', [Regions[K].Last - Regions[K].First + 1,
      WhisperAlignMatchName(Regions[K].Match), Where, Quote]));
    Regions[K].Last := Regions[K].First - 1;   // shown
    Inc(Shown);
  end;
end;

procedure TBuildThread.Execute;
var
  Book: TEpubBook;
  FF: TFFmpegLibrary;
  Audio: TWhisperAudioSet;
  Given, Split: TWhisperStringArray;
  Numbers, Map: TWhisperIndexArray;
  R: TWhisperTranscription;
  Parts: TWhisperAudioPartArray;
  Aligned, Joined: TWhisperAlignedWordArray;
  Stats: TWhisperAlignStats;
  Times: TWhisperFileTimeArray;
  Files: TStringList;
  Writer: TEpubWriter;
  Report: TEpubWriteReport;
  I, N: Integer;
  Started: TDateTime;
  Dev: TWhisperDevice;
  EpubFile, Note, CoverExt: string;
  BookCover, CoverData: TBytes;
begin
  Book := nil;
  FF := nil;
  Audio := nil;
  Files := nil;
  Writer := nil;
  try
    try
      // 1. the book's words (the contents page left out: never read aloud)
      Progress(0);
      Status('Reading the book ...');
      // a MOBI is built from an EPUB 3 made from it
      EpubFile := BookAsEpub(FBookFile, Note);
      if Note <> '' then
        Log(Note);
      Book := TEpubBook.Create(EpubFile);
      SetLength(Given, Book.WordCount);
      SetLength(Numbers, Book.WordCount);
      N := 0;
      for I := 0 to Book.WordCount - 1 do
        if Book.Words[I].Role <> ewrNav then
        begin
          Given[N] := Book.Words[I].Text;
          Numbers[N] := I;
          Inc(N);
        end;
      SetLength(Given, N);
      SetLength(Numbers, N);
      if N = 0 then
        raise EEpubError.Create('The book has no words to read aloud');
      FLanguage := PrimaryLanguage(Book.Language);
      Log(Format('Book: %s - %d words, language %s', [Book.Title, N, IfThen(FLanguage = '', 'not given',
        FLanguage)]));
      // ISO 639's "undetermined", "multiple", "no linguistic content": as
      // good as not given (Whisper detects it; the English prompt)
      if (FLanguage = 'und') or (FLanguage = 'mul') or (FLanguage = 'zxx') then
        FLanguage := '';
      // the user's language over the book's tag (owner, 2026-11-19: a tag
      // can be wrong - Ender in Exile said ru - or und)
      if FForceLanguage <> '' then
      begin
        Log(Format('Language: %s, chosen in the builder (the book says %s)', [FForceLanguage,
          IfThen(Book.Language = '', 'nothing', Book.Language)]));
        FLanguage := FForceLanguage;
      end;

      // 2. the audio, in parts
      Status('Opening the audio ...');
      FF := OpenFFmpeg;
      Log(FF.Description);
      Audio := TWhisperAudioSet.Create(FF, FAudioFiles, FChapters);
      FTotalSeconds := 0;
      for I := 0 to High(Audio.Parts) do
        FTotalSeconds := FTotalSeconds + Audio.Parts[I].Duration;
      FSummary.AudioSeconds := FTotalSeconds;
      FSummary.Files := Audio.Files.Count;
      FSummary.Parts := Length(Audio.Parts);
      // the device by what it is: '' (whisper.cpp's choice) as the device
      // it takes
      if BuilderFindDevice(FDevice, Dev) then
      begin
        FSummary.Device := Dev.Name;
        FSummary.DeviceText := WhisperDeviceText(Dev);
      end
      else
        FSummary.Device := FDevice;
      FSummary.Machine := MachineText;
      FSummary.Diagnostic := FDiagnostic;
      FSummary.Language := FLanguage;
      FSummary.Title := Book.Title;
      Log(Format('Audio: %d file(s), %d part(s), about %s', [Audio.Files.Count, Length(Audio.Parts),
        WhisperTimeToStr(Round(FTotalSeconds * 100))]));
      AudioLength(FTotalSeconds);
      Progress(5);
      if Terminated then
        Exit;

      // 3. the transcript: a saved one when it fits, else transcribed
      if ReadSaved(Audio.Parts, R, Parts) then
      begin
        FSummary.SavedTranscript := True;
        FSummary.Model := FSavedModel;
        if Pos(TRIMMED_MARK, WhisperLoadTextFile(FJsonFile)) = 0 then
        begin
          TrimSaved(R, Audio);
          if Terminated then
            Exit;
          // still the words of its own model and date
          SaveTranscript(R, Parts, FSavedModel, FSavedMade);
        end;
      end
      else
      begin
        Status('Loading the model ...');
        Started := Now;
        R := Transcribe(Audio);
        // the parts of an earlier run counted with their own time; the
        // time asleep not at all
        FSummary.TranscribeSeconds := FPriorSeconds + MilliSecondsBetween(Now, Started) / 1000 - FPausedSeconds;
        FSummary.Model := ExtractFileName(FModelFile);
        if FPausedSeconds > 0 then
          Log(Format('Paused for the system''s sleep: %s in all (not counted as transcribing)',
            [WhisperTimeToStr(Round(FPausedSeconds * 100))]));
        if Terminated then
        begin
          Log('Cancelled');
          Exit;
        end;
        Parts := Audio.Parts;
        if FDiagnostic <> '' then
          // its words are not a normal build's: a later build must not
          // take them for its own (a saved or part-way transcript of a
          // normal build is left as it is)
          Log(Format('DIAGNOSTIC build (%s): the transcript is not kept for next time', [FDiagnostic]))
        else if FBenchmark then
          // every benchmark transcribes all of its audio
          Log('Benchmark: the transcript is not kept for next time')
        else
        begin
          SaveTranscript(R, Parts, ExtractFileName(FModelFile), FormatDateTime('yyyy-mm-dd hh:nn', Now));
          Log(Format('Transcript kept for next time: %s (%d words)', [FJsonFile, Length(R.Words)]));
          // the whole transcript is kept: the parts so far are not needed
          try
            if FileExists(FPartialFile) then
              TFile.Delete(FPartialFile);
          except
            // left behind: the next build of this output starts afresh anyway
            // (ReadPartial's checks), or is read whole from FJsonFile
          end;
        end;
      end;
      Progress(90);
      if Terminated then
        Exit;

      // 4. align (a word of the EPUB may hold dashes: the aligner gets its
      // parts) and move the times into each audio file
      Status('Aligning the transcript with the book ...');
      Split := WhisperSplitBookWords(Given, Map);
      Aligned := WhisperAlignText(Split, R.Words, Stats);
      Joined := WhisperJoinAligned(Aligned, Map, Length(Given));
      LogResults(Stats, Length(R.Words), Split, Aligned, WhisperAlignRegions(Aligned, REGION_MIN_WORDS));
      if FBenchmark then
        ScoreBenchmark(Aligned, Parts);
      Files := WhisperPartFiles(Parts);
      Times := WhisperWordFileTimes(Joined, Parts, Files);
      Progress(93);
      if Terminated then
        Exit;

      // 5. the book with overlays and the audio inside
      Writer := TEpubWriter.Create(Book);
      // marked as ours: choosing this book again is warned about
      Writer.WrittenBy := 'EpubBuilder';
      // the cover: the user's from the Covers folder, else the audiobook's
      // when the book has none or a picture no cover is shaped like (The
      // Sword of Shannara's MOBI: Word 2000's logo, 680 x 510)
      BookCover := nil;
      if Book.CoverPath <> '' then
        try
          BookCover := Book.Zip.ReadBytes(Book.CoverPath);
        except
          BookCover := nil;
        end;
      ChooseCover(GCoverFolder, [ChangeFileExt(ExtractFileName(FBookFile), ''),
        ChangeFileExt(ExtractFileName(FOutFile), ''), Book.Title], BookCover, Files, FCoverChoice, CoverData,
        CoverExt, Note);
      Log(Note);
      if Length(CoverData) > 0 then
        Writer.SetCover(CoverData, CoverExt);
      for I := 0 to Files.Count - 1 do
        Writer.AddAudioFile(Files[I]);
      // the recording's chapters (or its files) as chapter marks: the
      // reader steps by them when the book's contents list does not give
      // chapters that are read (Night Watch: none in the book, 75 in the
      // audiobook). One part alone marks nothing.
      if Length(Parts) >= 2 then
        for I := 0 to High(Parts) do
          if Files.IndexOf(Parts[I].FileName) >= 0 then
            Writer.AddAudioChapter(Parts[I].Title, Files.IndexOf(Parts[I].FileName), Parts[I].Start);
      for I := 0 to High(Times) do
        Writer.AddWord(Numbers[Times[I].Word], Times[I].FileIndex, Times[I].StartTime, Times[I].EndTime);
      Log(Format('Writing %s ...', [FOutFile]));
      Status('Writing the book (the audio is copied in) ...');
      Writer.SaveToFile(FOutFile);
      Report := Writer.Report;
      FSummary.Clips := Report.Clips;
      FSummary.LeftOut := Report.Skipped;
      FSummary.Upgraded := Report.Upgraded;
      if Length(Parts) >= 2 then
        FSummary.ChapterMarks := Length(Parts);
      Log(Format('Done: %d document(s), %d clip(s), %d timed word(s) left out', [Report.Documents,
        Report.Clips, Report.Skipped]));
      if Length(Parts) >= 2 then
        Log(Format('Chapter marks: %d (the recording''s parts; EpubReader steps by them when the book''s ' +
          'contents list has no chapters that are read)', [Length(Parts)]));
      if Report.Upgraded then
        Log('The book was EPUB 2: it is EPUB 3 now (overlays need it)');
      if Report.Warnings <> '' then
        Log('Warning: ' + Trim(Report.Warnings));
      FSucceeded := True;
      Progress(100);
      Status('Done');
    except
      on E: Exception do
      begin
        Log('FAILED: ' + E.Message);
        Status('Failed: ' + E.Message);
        FSummary.Error := E.Message;
      end;
    end;
  finally
    Writer.Free;
    Files.Free;
    Audio.Free;
    FF.Free;
    Book.Free;
  end;
end;

{ TfrmBuilder }

function TfrmBuilder.AddCaption(AParent: TFmxObject; const AText: string): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := AParent;
  Result.Align := TAlignLayout.Top;
  Result.Height := 22;
  Result.Margins.Rect := RectF(GAP, GAP, GAP, 0);
  Result.Text := AText;
  Result.TextSettings.Font.Style := [TFontStyle.fsBold];
  Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Style];
end;

function TfrmBuilder.AddRow(AParent: TFmxObject; const ACaption: string): TLayout;
var
  L: TLabel;
begin
  Result := TLayout.Create(Self);
  Result.Parent := AParent;
  Result.Align := TAlignLayout.Top;
  Result.Height := ROW_HEIGHT;
  Result.Margins.Rect := RectF(GAP, GAP div 2, GAP, 0);
  // rows stack in the order made
  Result.Position.Y := 100000;
  L := TLabel.Create(Self);
  L.Parent := Result;
  L.Align := TAlignLayout.Left;
  L.Width := 90;
  L.Text := ACaption;
end;

function TfrmBuilder.AddButton(AParent: TFmxObject; const AText: string; AOnClick: TNotifyEvent;
  AAlign: TAlignLayout; AWidth: Single): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := AParent;
  Result.Align := AAlign;
  Result.Width := AWidth;
  Result.Margins.Rect := RectF(GAP div 2, 0, 0, 0);
  if AAlign in [TAlignLayout.Left, TAlignLayout.Right] then
    Result.Position.X := 100000;   // after the controls already there
  Result.Text := AText;
  Result.OnClick := AOnClick;
end;

procedure TfrmBuilder.BuildWindow;
var
  Row, Buttons: TLayout;
  L: TLabel;
begin
  // as wide as the window wants, but never wider than the screen (a
  // Steam Deck's 1280 x 800 cut the audio's buttons off, 2026-11-20)
  // (a work area of 0: not known - the sizes as they are)
  if Screen.WorkAreaWidth > 0 then
    ClientWidth := Max(ClientWidth, Min(1300, Integer(Trunc(Screen.WorkAreaWidth)) - 16))
  else
    ClientWidth := Max(ClientWidth, 1300);
  // tall enough for book and audio above the queue (zip 192), within the
  // screen
  ClientHeight := Max(ClientHeight, 820);
  if (Screen.WorkAreaHeight > 0) and (ClientHeight > Screen.WorkAreaHeight - 60) then
    ClientHeight := Max(500, Integer(Trunc(Screen.WorkAreaHeight)) - 60);

  // The window (owner, 2026-11-21: "Model, Device, Language, Power, GPU,
  // Chapters are parts... and Use Saved Transcript can all go on their own
  // settings form/menu reducing clutter. The job queue can now move below
  // Book and Audio providing more space"): book and audio at the top, the
  // queue below them across the window, then the output, a line of the
  // settings with Settings..., Create / Cancel, progress and log. The
  // settings themselves are the menu's Settings page (miSettingsClick).

  // below: output, settings line, Create / Cancel, progress, log
  layBottom := TLayout.Create(Self);
  layBottom.Parent := Self;
  layBottom.Align := TAlignLayout.Bottom;
  layBottom.Height := 4 * (ROW_HEIGHT + GAP div 2) + 190;

  Row := AddRow(layBottom, 'Output EPUB');
  edOut := TEdit.Create(Self);
  edOut.Parent := Row;
  edOut.Align := TAlignLayout.Client;
  AddButton(Row, 'Choose...', btnOutClick, TAlignLayout.Right);

  Row := AddRow(layBottom, 'Settings');
  AddButton(Row, 'Settings...', miSettingsClick, TAlignLayout.Right);
  lblSettings := TLabel.Create(Self);
  lblSettings.Parent := Row;
  lblSettings.Align := TAlignLayout.Client;
  lblSettings.WordWrap := False;
  lblSettings.Trimming := TTextTrimming.Character;

  Buttons := AddRow(layBottom, '');
  btnCreate := AddButton(Buttons, 'Create', btnCreateClick, TAlignLayout.Left, 120);
  btnAddJob := AddButton(Buttons, 'Add to queue', btnAddJobClick, TAlignLayout.Left, 120);
  btnAddJob.Position.X := 100000;
  btnUpdateJob := AddButton(Buttons, 'Update job', btnUpdateJobClick, TAlignLayout.Left, 120);
  btnUpdateJob.Position.X := 150000;
  btnCancel := AddButton(Buttons, 'Cancel', btnCancelClick, TAlignLayout.Left, 120);
  btnCancel.Position.X := 200000;
  pbBuild := TProgressBar.Create(Self);
  pbBuild.Parent := Buttons;
  pbBuild.Align := TAlignLayout.Client;
  pbBuild.Margins.Rect := RectF(GAP * 2, 8, 0, 8);
  pbBuild.Max := 100;

  Row := AddRow(layBottom, 'Now');
  lblStatus := TLabel.Create(Self);
  lblStatus.Parent := Row;
  lblStatus.Align := TAlignLayout.Client;
  lblStatus.Text := 'Idle';
  lblStatus.WordWrap := False;
  lblStatus.Trimming := TTextTrimming.Character;
  tmStatus := TTimer.Create(Self);
  tmStatus.Interval := 1000;
  tmStatus.Enabled := False;
  tmStatus.OnTimer := tmStatusTimer;

  mmLog := TMemo.Create(Self);
  mmLog.Parent := layBottom;
  mmLog.Align := TAlignLayout.Client;
  mmLog.Margins.Rect := RectF(GAP, GAP, GAP, GAP);
  mmLog.ReadOnly := True;
  mmLog.WordWrap := True;
  // the progress panel in the log's place (the log behind View)
  layProgress := TLayout.Create(Self);
  layProgress.Parent := layBottom;
  layProgress.Align := TAlignLayout.Client;
  layProgress.Margins.Rect := RectF(GAP * 2, GAP, GAP * 2, GAP);
  lblPSpeed := TLabel.Create(Self);
  lblPTime := TLabel.Create(Self);
  lblPJob := TLabel.Create(Self);
  lblPTitle := TLabel.Create(Self);
  for L in [lblPSpeed, lblPTime, lblPJob, lblPTitle] do
  begin
    L.Parent := layProgress;
    L.Align := TAlignLayout.Top;
    L.StyledSettings := L.StyledSettings - [TStyledSetting.Size, TStyledSetting.Style];
    L.TextSettings.Font.Size := 18;
    L.Height := 30;
    L.WordWrap := False;
    L.Trimming := TTextTrimming.Character;
  end;
  lblPTitle.TextSettings.Font.Size := 26;
  lblPTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
  lblPTitle.Height := 44;
  // top to bottom: title, job, time, speed (Top-aligned controls are
  // stacked by their position)
  lblPTitle.Position.Y := 0;
  lblPJob.Position.Y := 100;
  lblPTime.Position.Y := 200;
  lblPSpeed.Position.Y := 300;
  lblPTitle.Text := 'Idle';
  mmLog.Visible := False;

  // the top: the book (left) and its audio (right)
  layTop := TLayout.Create(Self);
  layTop.Parent := Self;
  layTop.Align := TAlignLayout.Top;
  layTop.Position.Y := 50000;
  layTop.Height := Max(200, Round((ClientHeight - layBottom.Height) * 0.55));

  layBook := TLayout.Create(Self);
  layBook.Parent := layTop;
  layBook.Position.X := 0;
  layBook.Align := TAlignLayout.Left;
  layBook.Width := Max(380, Round(ClientWidth * 0.45));
  AddCaption(layBook, 'Book (EPUB)');
  Row := AddRow(layBook, '');
  Row.Position.Y := 30;
  edBook := TEdit.Create(Self);
  edBook.Parent := Row;
  edBook.Align := TAlignLayout.Client;
  edBook.ReadOnly := True;
  AddButton(Row, 'Choose...', btnBookClick, TAlignLayout.Right);
  AddButton(Row, 'Cover...', btnCoverClick, TAlignLayout.Right);
  mmBook := TMemo.Create(Self);
  mmBook.Parent := layBook;
  mmBook.Align := TAlignLayout.Client;
  mmBook.Margins.Rect := RectF(GAP, GAP, GAP, GAP);
  mmBook.ReadOnly := True;
  mmBook.WordWrap := True;

  splSides := TSplitter.Create(Self);
  splSides.Parent := layTop;
  splSides.Align := TAlignLayout.Left;
  splSides.Position.X := 100000;
  splSides.Width := 5;

  layAudio := TLayout.Create(Self);
  layAudio.Parent := layTop;
  layAudio.Align := TAlignLayout.Client;
  AddCaption(layAudio, 'Audio (in reading order)');
  Row := AddRow(layAudio, '');
  Row.Position.Y := 30;
  AddButton(Row, 'Add files...', btnAddAudioClick, TAlignLayout.Left, 100);
  AddButton(Row, 'Add folder...', btnAddFolderClick, TAlignLayout.Left, 100);
  AddButton(Row, 'Remove', btnRemoveClick, TAlignLayout.Left, 80);
  AddButton(Row, 'Up', btnUpClick, TAlignLayout.Left, 60);
  AddButton(Row, 'Down', btnDownClick, TAlignLayout.Left, 60);
  lbAudio := TListBox.Create(Self);
  lbAudio.Parent := layAudio;
  lbAudio.Align := TAlignLayout.Client;
  lbAudio.Margins.Rect := RectF(GAP, GAP, GAP, GAP);

  // between the top and the queue (dragged: more room for either)
  splQueue := TSplitter.Create(Self);
  splQueue.Parent := Self;
  splQueue.Align := TAlignLayout.Top;
  splQueue.Position.Y := 60000;
  splQueue.Height := 5;

  // the job queue: below the book and the audio, across the window, the
  // rest of the height; Run queue with its buttons
  layQueue := TLayout.Create(Self);
  layQueue.Parent := Self;
  layQueue.Align := TAlignLayout.Client;
  AddCaption(layQueue, 'Job queue');
  Row := AddRow(layQueue, '');
  Row.Position.Y := 30;
  AddButton(Row, 'Load...', btnJobLoadClick, TAlignLayout.Left, 80);
  AddButton(Row, 'Save...', btnJobSaveClick, TAlignLayout.Left, 80);
  AddButton(Row, 'Remove', btnJobRemoveClick, TAlignLayout.Left, 80);
  AddButton(Row, 'Up', btnJobUpClick, TAlignLayout.Left, 60);
  AddButton(Row, 'Down', btnJobDownClick, TAlignLayout.Left, 60);
  btnRunQueue := AddButton(Row, 'Run queue', btnRunQueueClick, TAlignLayout.Left, 160);
  btnRunQueue.Margins.Left := GAP * 3;
  lbJobs := TListBox.Create(Self);
  lbJobs.Parent := layQueue;
  lbJobs.Align := TAlignLayout.Client;
  lbJobs.Margins.Rect := RectF(GAP, GAP, GAP, GAP);
  lbJobs.OnDblClick := lbJobsDblClick;
  lbJobs.OnClick := lbJobsClick;
  tmQueue := TTimer.Create(Self);
  tmQueue.Enabled := False;
  tmQueue.Interval := 50;
  tmQueue.OnTimer := tmQueueTimer;

  // the settings' controls: the ones the rest of the code reads and sets
  // (cbModel, cbDevice, ...). They are on no page of the window - the
  // menu's Settings page shows and changes them - so their holder is
  // never shown.
  laySettings := TLayout.Create(Self);
  laySettings.Parent := Self;
  laySettings.Visible := False;
  cbModel := TComboBox.Create(Self);
  cbModel.Parent := laySettings;
  cbModel.OnChange := cbModelChange;
  cbDevice := TComboBox.Create(Self);
  cbDevice.Parent := laySettings;
  cbLanguage := TComboBox.Create(Self);
  cbLanguage.Parent := laySettings;
  FillLanguages('');
  cbPower := TComboBox.Create(Self);
  cbPower.Parent := laySettings;
  cbPower.Items.Add('Automatic - fastest on mains power, saving power on battery');
  cbPower.Items.Add('Fastest - kept awake, at full speed');
  cbPower.Items.Add('Save power - kept awake, the system may slow it down');
  cbPower.Items.Add('Let it sleep - the computer may sleep while building');
  cbPower.ItemIndex := 0;
  cbPower.OnChange := cbPowerChange;
  {$IFDEF MSWINDOWS}
  cbGpu := TComboBox.Create(Self);
  cbGpu.Parent := laySettings;
  cbGpu.Items.Add('Windows decides');
  cbGpu.Items.Add('Power saving GPU (next start)');
  cbGpu.Items.Add('High performance GPU (next start)');
  cbGpu.ItemIndex := Ord(GpuPreference);
  cbGpu.OnChange := cbGpuChange;
  {$ENDIF}
  chkChapters := TCheckBox.Create(Self);
  chkChapters.Parent := laySettings;
  chkChapters.IsChecked := True;
  chkReuse := TCheckBox.Create(Self);
  chkReuse.Parent := laySettings;
  // off at every start: reusing old words is a choice made for one build
  // (owner: "if re-transcribing there is obviously a reason"); not kept in
  // the settings
  chkReuse.IsChecked := False;
  chkReuse.OnChange := chkReuseChange;
end;

procedure TfrmBuilder.UpdateSettingsLine;
var
  S, T: string;
begin
  if lblSettings = nil then
    Exit;
  if FModelPath <> '' then
  begin
    S := ChangeFileExt(ExtractFileName(FModelPath), '');
    if StartsText('ggml-', S) then
      S := Copy(S, 6, MaxInt);
  end
  else
    S := 'no model chosen';
  if (cbDevice.ItemIndex > 0) and (cbDevice.ItemIndex - 1 <= High(FDevices)) then
    S := S + ' on ' + FDevices[cbDevice.ItemIndex - 1].Name
  else if GDefaultDevice <> '' then
    S := S + ' on ' + GDefaultDevice
  else
    S := S + ' on the default device';
  if cbLanguage.ItemIndex >= 0 then
    S := S + ', ' + cbLanguage.Items[cbLanguage.ItemIndex];
  if cbPower.ItemIndex >= 0 then
  begin
    T := cbPower.Items[cbPower.ItemIndex];
    if Pos(' - ', T) > 0 then
      T := Copy(T, 1, Pos(' - ', T) - 1);
    S := S + ', power: ' + T;
  end;
  if not chkChapters.IsChecked then
    S := S + ', a file''s chapters not parts';
  if chkReuse.IsChecked then
    S := S + ' - USING THE SAVED TRANSCRIPT';
  lblSettings.Text := S;
end;

procedure TfrmBuilder.AppException(Sender: TObject; E: Exception);
begin
  DebugLogException(E, ExceptAddr);
  Application.ShowException(E);
end;

procedure TfrmBuilder.FormCreate(Sender: TObject);
var
  Lib: TWhisperLib;
  I: Integer;
  Line, Moved, Why: string;
  Kept: TWhisperDeviceArray;
begin
  OnCloseQuery := FormCloseQuery;
  OnShow := FormShow;
  OnActivate := FormActivated;
  OnDeactivate := FormDeactivated;
  FRedraw := TWindowRedraw.Create(Self, True);
  tmSleep := TTimer.Create(Self);
  tmSleep.Interval := 250;
  tmSleep.OnTimer := tmSleepTimer;
  tmSleep.Enabled := True;
  FEditJob := -1;
  FUpdateJob := -1;
  FPadMode := -1;
  FPadJob := -1;
  // the folders shared with EpubReader: what was in EpubBuilder's own moved
  // in, once - before the log and the settings are opened there
  Moved := EpubUnumMove('EpubBuilder');
  // the debug log: next to the settings, started afresh at every run
  DebugLogOpen(ChangeFileExt(SettingsFile, '-debug.log'));
  if Moved <> '' then
    for Line in Moved.Split([sLineBreak], TStringSplitOptions.ExcludeEmpty) do
      DebugLog('folders: ' + Line);
  // Steam's Exit Game ends the program with SIGTERM: save first (owner)
  if QuitSignalInstall(QuitSignalled) then
    DebugLog('SIGTERM / SIGINT / SIGHUP: saved before the program ends');
  Line := QuitSignalLast(ChangeFileExt(SettingsFile, QUIT_NOTE_SUFFIX));
  if Line <> '' then
    DebugLog(Line);
  // a crash in a library (Steam Deck, 2026-11-17): logged with where it was
  Application.OnException := AppException;
  FJob := -1;
  FBenchOption := -1;
  FBuildLog := TStringList.Create;
  FModelItems := TStringList.Create;
  BuildWindow;
  BuildMenu;
  cbDevice.Items.Add('Default (whisper.cpp chooses)');
  // EpubBuilder.sh hid HIP (no ROCm kernels for this GPU, or none at all) -
  // ggml uses Vulkan
  if GetEnvironmentVariable('EPUBUNUM_ROCM_OFF') <> '' then
    LogLine('ROCm: off - ' + Trim(GetEnvironmentVariable('EPUBUNUM_ROCM_OFF')) + '; Vulkan is used.');
  if BuildDiagnostics <> '' then
    LogLine('DIAGNOSTIC SWITCHES: ' + BuildDiagnostics + ' - builds of this run are for measuring: slower or ' +
      'less accurate words, no transcript kept, not in the build history. Start without them to build books.');
  try
    DebugLog('whisper.cpp: loading');
    Lib := TWhisperLib.Load;
    // whisper.cpp's and ggml's own lines (every level), as they are written
    Lib.AddLogListener(WhisperLog);
    FDevices := Lib.SelectableDevices;
    for I := 0 to High(FDevices) do
      DebugLog('device: ' + WhisperDeviceText(FDevices[I]));
    // what the launcher found (why ROCm was or was not hidden)
    DebugLog(Format('ROCm check: HIP_VISIBLE_DEVICES=%s, EPUBUNUM_ROCM_OFF=%s, rocblas beside the program: %s, ' +
      '/sys/class/kfd: %s', [GetEnvironmentVariable('HIP_VISIBLE_DEVICES'),
      GetEnvironmentVariable('EPUBUNUM_ROCM_OFF'),
      BoolToStr(TDirectory.Exists(TPath.Combine(ExtractFileDir(ParamStr(0)), 'rocblas')), True),
      BoolToStr(TDirectory.Exists('/sys/class/kfd/kfd/topology/nodes'), True)]));
    // ROCm on a GPU it cannot run on: its devices left out of the list,
    // the calibration and "Default" (the launcher may not have hidden them)
    if RocmUnusable(Why) then
    begin
      Kept := nil;
      for I := 0 to High(FDevices) do
        if IsRocmDevice(FDevices[I]) then
          LogLine(Format('%s left out: ROCm cannot run here (%s).', [FDevices[I].Name, Why]))
        else
          Kept := Kept + [FDevices[I]];
      FDevices := Kept;
      // "Default": the first GPU left, else the processor
      GDefaultDevice := '';
      for I := High(FDevices) downto 0 do
        if FDevices[I].DeviceType <> wdtCPU then
          GDefaultDevice := FDevices[I].Name;
      if GDefaultDevice = '' then
        for I := 0 to High(FDevices) do
          if FDevices[I].DeviceType = wdtCPU then
            GDefaultDevice := FDevices[I].Name;
    end;
    for I := 0 to High(FDevices) do
      cbDevice.Items.Add(WhisperDeviceText(FDevices[I]));
    // which device "Default" is (owner: whisper.cpp's CUDA choice was not
    // visible anywhere)
    cbDevice.Items[0] := DefaultDeviceItem;
    FWhisperText := Format('whisper.cpp %s from %s', [Lib.Version, Lib.LibraryFolder]);
    FCoreML := Pos('COREML = 1', Lib.SystemInfo) > 0;
    LogLine(Format('whisper.cpp %s loaded from %s', [Lib.Version, Lib.LibraryFolder]));
  except
    on E: Exception do
    begin
      FWhisperNote := E.Message;
      LogLine('whisper.cpp is not available: ' + E.Message);
      {$IFDEF MSWINDOWS}
      LogLine('Put TWhisper''s redistributable_bin libraries next to the program or on PATH.');
      {$ELSE}
      LogLine('Put whisper-dev''s dlls (libwhisper.so, libggml*.so, libgomp.so.1) and ffmpeg-dev''s ' +
        'dlls/linux-x64 libraries next to the program, or on LD_LIBRARY_PATH.');
      {$ENDIF}
    end;
  end;
  cbDevice.ItemIndex := 0;
  // the models folder before the settings (which may name another)
  FModelsFolder := ModelsDefaultFolder(SteamBuild, ExtractFilePath(SettingsFile));
  if SteamBuild and not FolderWritable(FModelsFolder) then
    FModelsFolder := ModelsDefaultFolder(False, ExtractFilePath(SettingsFile));
  // dark by default (zip 203): a first start has no settings file, and
  // LoadSettings reads [View] Dark only from one
  FPadDark := True;
  // the same for the lowest acceptable speed: 2.0x at first
  FLowestSpeed := LOWEST_SPEED_TOP;
  FBoardUpload := True;
  FBenchSel := -1;
  LoadSettings;
  // the three folders there from the start (the dialogs open in them)
  try
    ForceDirectories(FBookFolder);
    ForceDirectories(FAudioFolder);
    ForceDirectories(FOutFolder);
    ForceDirectories(FQueueFolder);
    ForceDirectories(FCoverFolder);
  except
    on E: Exception do
      LogLine('A folder was not made: ' + E.Message);
  end;
  // the queue as it was when the program last ended (kept as it changes)
  RestoreQueue;
  // BookManager and EpubReader can connect from here on
  StartLink;
  FillModels;
  LogLine('Models folder: ' + FModelsFolder);
  LogLine(Format('Folders: books %s, audio %s, output %s (Settings to change)', [FBookFolder, FAudioFolder,
    FOutFolder]));
  if FCoreML then
    LogLine('Core ML: built in - a model''s Core ML encoder is downloaded with it (the encoder then runs on the ' +
      'Neural Engine).');
  LogLine('Machine: ' + MachineText);
  LogLine('Build: ' + BuildStamp);
  // Steam (started in the .dpr, before the log was open)
  LogLine(SteamText);
  for Line in SteamNotes do
    DebugLog(Line);
  LogLine('Choose the EPUB, add its audio files in reading order, choose the model (one not downloaded yet is ' +
    'downloaded when chosen), Create.');
  LogLine('Debug log: ' + DebugLogFile);
  CheckRocmDlc;
  UpdateControls;
  // owner, 2026-11-22: "The screen briefly flashes white on form load
  // before the theme takes over" - dark before the window is first drawn
  // (the timer and StartPad came after it: up to half a second light)
  DarkBeforeShow;
end;

procedure TfrmBuilder.WhisperLog(Sender: TObject; ALevel: TWhisperLogLevel; const AText: string);
begin
  DebugLog('whisper.cpp: ' + AText);
end;

procedure TfrmBuilder.LoadSettings;
var
  Ini: TMemIniFile;
  Device, Docs: string;
  I: Integer;

  { The folder kept under AKey, else ADefault. }
  function FolderSetting(const AKey, ADefault: string): string;
  begin
    Result := Ini.ReadString('Folders', AKey, '');
    if Result = '' then
      Result := ADefault;
  end;

begin
  // the three folders: books in, audio in, books out (owner, 2026-11-18) -
  // Documents/EpubBuilder/... until Settings > ... folder chooses others
  // Documents/EpubUnum, shared with EpubReader (owner, 2026-11-20)
  Docs := EpubUnumDocsFolder;
  FBookFolder := TPath.Combine(Docs, 'Books');
  FAudioFolder := TPath.Combine(Docs, 'Audio');
  // "Transcribed": a name that also reads well as EpubReader's (owner,
  // 2026-11-20; it lists the folder)
  FOutFolder := TPath.Combine(Docs, 'Transcribed');
  // saved queues (owner, 2026-11-20: "Where do queues go?")
  FQueueFolder := TPath.Combine(Docs, 'Queues');
  // a book's cover of the user's choice (owner, 2026-11-20)
  FCoverFolder := TPath.Combine(Docs, 'Covers');
  if not FileExists(SettingsFile) then
    Exit;
  try
    Ini := TMemIniFile.Create(SettingsFile, TEncoding.UTF8);
    try
      // the models folder: the user's (not in Steam builds)
      if not SteamBuild and (Ini.ReadString('Models', 'Folder', '') <> '') then
        FModelsFolder := Ini.ReadString('Models', 'Folder', '');
      // the model: a name (in the models folder) or a file
      FModelPath := Ini.ReadString('Build', 'Model', '');
      if (FModelPath <> '') and (ExtractFilePath(FModelPath) = '') then
        FModelPath := TPath.Combine(FModelsFolder, ModelFileName(FModelPath));
      if (FModelPath <> '') and not FileExists(FModelPath) then
        FModelPath := '';
      // the device by its name: the list's order can change
      Device := DeviceMatch(Ini.ReadString('Build', 'Device', ''), Ini.ReadString('Build', 'DeviceDescription', ''));
      for I := 0 to High(FDevices) do
        if SameText(FDevices[I].Name, Device) then
          cbDevice.ItemIndex := I + 1;
      chkChapters.IsChecked := Ini.ReadBool('Build', 'Chapters', True);
      // the log, or the progress panel in its place (the panel at first)
      SetLogVisible(Ini.ReadBool('View', 'Log', False));
      // Big Picture dark unless turned off (applied when the pad's menu
      // and the window are made)
      FPadDark := Ini.ReadBool('View', 'Dark', True);
      FExpert := Ini.ReadBool('Models', 'Expert', False);
      FBoardUpload := Ini.ReadBool('Benchmark', 'Leaderboard', True);
      FLowestSpeed := EnsureRange(Round(StrToFloatDef(Ini.ReadString('Build', 'LowestSpeed', ''),
        LOWEST_SPEED_TOP / 10, TFormatSettings.Invariant) * 10), 0, LOWEST_SPEED_TOP);
      // not a change of the user's (which saves the settings half read)
      cbPower.OnChange := nil;
      try
        cbPower.ItemIndex := EnsureRange(IndexText(Ini.ReadString('Build', 'Power', 'Automatic'), POWER_KEYS), 0, 3);
      finally
        cbPower.OnChange := cbPowerChange;
      end;
      FBookFolder := FolderSetting('Book', FBookFolder);
      FAudioFolder := FolderSetting('Audio', FAudioFolder);
      FOutFolder := FolderSetting('Output', FOutFolder);
      FQueueFolder := FolderSetting('Queues', FQueueFolder);
      FCoverFolder := FolderSetting('Covers', FCoverFolder);
    finally
      Ini.Free;
    end;
  except
    on E: Exception do
      LogLine('Settings not read (' + E.Message + ')');
  end;
end;

procedure TfrmBuilder.SaveSettings;
var
  Ini: TMemIniFile;
begin
  // the folders may have changed: the link sends and keeps the new ones
  if FLink <> nil then
    UpdateLinkFolders;
  try
    ForceDirectories(ExtractFilePath(SettingsFile));
    Ini := TMemIniFile.Create(SettingsFile, TEncoding.UTF8);
    try
      // a model in the models folder by its name, another by its file
      if (FModelPath <> '') and SameFileName(ExcludeTrailingPathDelimiter(ExtractFilePath(FModelPath)),
        ExcludeTrailingPathDelimiter(FModelsFolder)) and SameText(Copy(ExtractFileName(FModelPath), 1, 5),
        'ggml-') then
        Ini.WriteString('Build', 'Model', ModelShortName(FModelPath))
      else
        Ini.WriteString('Build', 'Model', FModelPath);
      if not SteamBuild then
        Ini.WriteString('Models', 'Folder', FModelsFolder);
      if cbDevice.ItemIndex > 0 then
      begin
        Ini.WriteString('Build', 'Device', FDevices[cbDevice.ItemIndex - 1].Name);
        // found again by it when the list's numbers move
        Ini.WriteString('Build', 'DeviceDescription', FDevices[cbDevice.ItemIndex - 1].Description);
      end
      else
      begin
        Ini.WriteString('Build', 'Device', '');
        Ini.DeleteKey('Build', 'DeviceDescription');
      end;
      Ini.WriteString('Build', 'Power', POWER_KEYS[EnsureRange(cbPower.ItemIndex, 0, 3)]);
      Ini.WriteBool('Build', 'Chapters', chkChapters.IsChecked);
      Ini.WriteBool('View', 'Dark', FPadDark);
      Ini.WriteBool('Models', 'Expert', FExpert);
      Ini.WriteBool('Benchmark', 'Leaderboard', FBoardUpload);
      Ini.WriteString('Build', 'LowestSpeed', FormatFloat('0.0', FLowestSpeed / 10, TFormatSettings.Invariant));
      // no longer kept (off at every start)
      Ini.DeleteKey('Build', 'UseSavedTranscript');
      Ini.WriteString('Folders', 'Book', FBookFolder);
      Ini.WriteString('Folders', 'Audio', FAudioFolder);
      Ini.WriteString('Folders', 'Output', FOutFolder);
      Ini.WriteString('Folders', 'Queues', FQueueFolder);
      Ini.WriteString('Folders', 'Covers', FCoverFolder);
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
  except
    on E: Exception do
      LogLine('Settings not saved (' + E.Message + ')');
  end;
end;

procedure TfrmBuilder.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  Queue: string;
  I, N: Integer;
begin
  if (FBuild = nil) or FForceClose then
    Exit;
  // the answer is needed now: the synchronous dialog (desktop platforms)
  Queue := '';
  if FQueueRunning then
  begin
    N := 0;
    for I := 0 to High(FJobs) do
      if FJobs[I].State = jsWaiting then
        Inc(N);
    Queue := Format(' The queue stops too: %d more job(s) waiting (Save... keeps them).', [N]);
  end;
  CanClose := TDialogServiceSync.MessageDialog(Format('A build is running (%.0f %%: %s).' + sLineBreak +
    sLineBreak + 'Closing stops it; the parts transcribed so far are kept, and building the book again ' +
    'goes on from the next part.%s' + sLineBreak + sLineBreak + 'Stop the build and close?', [FPercent, FStatusText, Queue]),
    TMsgDlgType.mtWarning, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0) = mrYes;
  if not CanClose then
    LogLine('Still building.');
end;

procedure TfrmBuilder.QuitSignalled(ASignal: Integer);
var
  Busy: Boolean;
  What: string;
begin
  Busy := (FBuild <> nil) or (FCalib <> nil) or (FDownload <> nil);
  What := '';
  if FBuild <> nil then
    What := Format('building %s (%.0f %%)', [ExtractFileName(FRunOut), FPercent])
  else if FCalib <> nil then
    What := Format('%s (%.0f %%)', [IfThen(FCalib.Diagnostics, 'running the diagnostics', 'calibrating'),
      FPercent])
  else if FDownload <> nil then
    What := 'downloading a model';
  // the next start says so too (the debug log starts afresh)
  QuitSignalRecord(ChangeFileExt(SettingsFile, QUIT_NOTE_SUFFIX), ASignal, What);
  try
    LogLine(Format('Asked to end (%s - Steam''s Exit Game, or the system shutting down)%s: saving.',
      [QuitSignalName(ASignal), IfThen(What <> '', ' while ' + What, '')]));
    SaveSettings;
    if FCalib <> nil then
      // ended from outside, not by a device: no crash to remember
      TFile.Delete(ChangeFileExt(SettingsFile, CALIBRATION_MARKER_SUFFIX));
    if FQueueRunning and (FQueueFile <> '') then
    begin
      SaveQueue(FQueueFile);
      LogLine('Queue file saved: ' + FQueueFile);
    end;
    if (FBuild <> nil) and (FRunOut <> '') and (FBuildLog <> nil) then
    begin
      LogLine('The build was stopped part way: the parts already transcribed are kept - building it again ' +
        'goes on from the next part.');
      FBuildLog.SaveToFile(FRunOut + '.log', TEncoding.UTF8);
    end
    else if (FCalib <> nil) and (FBuildLog <> nil) then
    begin
      if FCalib.Diagnostics then
      begin
        LogLine('The diagnostics were stopped part way.');
        FBuildLog.SaveToFile(ChangeFileExt(SettingsFile, DIAGNOSTICS_LOG_SUFFIX), TEncoding.UTF8);
      end
      else
      begin
        LogLine('The calibration was stopped part way: nothing of it was kept.');
        FBuildLog.SaveToFile(ChangeFileExt(SettingsFile, CALIBRATION_LOG_SUFFIX), TEncoding.UTF8);
      end;
    end;
  except
    on E: Exception do
      DebugLog('saving before the end: ' + E.Message);
  end;
  if Busy then
  begin
    DebugLog('ending now (a build, calibration or download was running)');
    QuitNow(0);
  end;
  // nothing running: the window's own close (FormClose)
  DebugLog('closing');
  Close;
end;

procedure TfrmBuilder.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  SaveSettings;
  // a leaderboard still asked for answers nobody
  SteamBoardsForget;
  FreeAndNil(FLink);
  if FCalib <> nil then
  begin
    // as a build below: nothing of a calibration is kept unless it ends
    FCalib.FreeOnTerminate := False;
    FCalib.OnLog := nil;
    FCalib.OnProgress := nil;
    FCalib.OnStatus := nil;
    FCalib.OnTerminate := nil;
    tmStatus.Enabled := False;
    FCalib.Cancel;
    FCalib.WaitFor;
    FreeAndNil(FCalib);
  end;
  if FBuild <> nil then
  begin
    // still running (BuildDone, which clears FBuild, runs on this thread
    // and has not run): keep the object to wait for it, then free it here
    FBuild.FreeOnTerminate := False;
    FBuild.OnLog := nil;
    FBuild.OnProgress := nil;
    FBuild.OnAudioLength := nil;
    FBuild.OnStatus := nil;
    FBuild.OnTerminate := nil;
    tmStatus.Enabled := False;
    FBuild.Cancel;
    FBuild.WaitFor;
    FreeAndNil(FBuild);
  end;
  if FDownload <> nil then
  begin
    // as a build: wait for it here (the part downloaded is deleted)
    FDownload.FreeOnTerminate := False;
    FDownload.OnLog := nil;
    FDownload.OnProgress := nil;
    FDownload.OnTerminate := nil;
    FDownload.Cancel;
    FDownload.WaitFor;
    FreeAndNil(FDownload);
  end;
  // the pad: its timer first (tmPadTimer polls it). It was never freed -
  // the leak report at the end named TSteamPad, its names and its arrays
  // (owner, 2026-11-21)
  if tmPad <> nil then
    tmPad.Enabled := False;
  if tmDark <> nil then
    tmDark.Enabled := False;
  FreeAndNil(FPad);
  FreeAndNil(FBuildLog);
  FreeAndNil(FModelItems);
end;

procedure TfrmBuilder.LogLine(const AText: string);
begin
  if FLink <> nil then
    FLink.AddLog(AText);
  DebugLog(AText);
  mmLog.Lines.Add(AText);
  mmLog.GoToTextEnd;
  if FLogging and (FBuildLog <> nil) then
    FBuildLog.Add(AText);
end;

procedure TfrmBuilder.ThreadLine(const AText: string);
begin
  if FLink <> nil then
    FLink.AddLog(AText);
  mmLog.Lines.Add(AText);
  mmLog.GoToTextEnd;
  if FLogging and (FBuildLog <> nil) then
    FBuildLog.Add(AText);
end;

procedure TfrmBuilder.WindowLine(const AText: string);
begin
  if FLink <> nil then
    FLink.AddLog(AText);
  DebugLog(AText);
  mmLog.Lines.Add(AText);
  mmLog.GoToTextEnd;
end;

function TfrmBuilder.EffectivePower: Integer;
begin
  Result := EnsureRange(cbPower.ItemIndex, 0, 3);
  if Result = 0 then
  begin
    if OnBattery then
      Result := 2
    else
      Result := 1;
  end;
end;

procedure TfrmBuilder.ApplyPower(ABusy, AOnlyOnChange: Boolean);
const
  NAMES: array[1..3] of string = ('Fastest', 'Save power', 'Let it sleep');
var
  P: Integer;
  Text, How: string;
begin
  if not ABusy then
  begin
    Text := '';
    if FInhibited then
    begin
      InhibitStop(ikSleep);
      FInhibited := False;
      Text := 'letting the computer sleep: ' + InhibitText + '; ';
    end;
    if FPowerNow > 0 then
      LogLine(Text + 'speed: ' + InhibitSpeed(isSystem));
    FPowerNow := 0;
    Exit;
  end;
  P := EffectivePower;
  if AOnlyOnChange and (P = FPowerNow) then
    Exit;
  FPowerNow := P;
  How := '';
  if cbPower.ItemIndex = 0 then
    How := IfThen(P = 2, ' (Automatic: on battery)', ' (Automatic: on mains power)');
  Text := '';
  if (P <> 3) and not FInhibited then
  begin
    // SteamOS (Game Mode) and laptops sleep with nobody at the controls,
    // half way through an hour's transcription (owner, Steam Machine)
    InhibitStart(ikSleep, 'Building an audiobook');
    FInhibited := True;
    Text := 'keeping the computer awake: ' + InhibitText;
  end
  else if (P = 3) and FInhibited then
  begin
    InhibitStop(ikSleep);
    FInhibited := False;
    Text := 'letting the computer sleep: ' + InhibitText;
  end
  else if P = 3 then
    Text := 'the computer may sleep'
  else
    Text := 'kept awake';
  case P of
    1: Text := Text + '; speed: ' + InhibitSpeed(isFast);
    2: Text := Text + '; speed: ' + InhibitSpeed(isSaving);
  else
    Text := Text + '; speed: ' + InhibitSpeed(isSystem);
  end;
  LogLine('Power: ' + NAMES[P] + How + ' - ' + Text);
end;

procedure TfrmBuilder.cbPowerChange(Sender: TObject);
begin
  SaveSettings;
  if FAwake then
    ApplyPower(True, True);
end;

{$IFDEF MSWINDOWS}
procedure TfrmBuilder.cbGpuChange(Sender: TObject);
begin
  if cbGpu.ItemIndex < 0 then
    Exit;
  if SetGpuPreference(TGpuPreference(cbGpu.ItemIndex)) then
    WindowLine('Window GPU: ' + cbGpu.Items[cbGpu.ItemIndex] + ' - Windows uses it from the next start of ' +
      'EpubBuilder (the device list may then be in another order: devices are found again by name)')
  else
    WindowLine('Window GPU: not stored (the registry could not be written)');
end;
{$ENDIF}

function TfrmBuilder.DeviceDescription(const AName: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FDevices) do
    if SameText(FDevices[I].Name, AName) then
      Exit(FDevices[I].Description);
end;

function TfrmBuilder.DeviceMatch(const AName, ADescription: string): string;

  { The name without its number: 'Vulkan', 'CUDA', 'MTL'. }
  function Kind(const AText: string): string;
  begin
    Result := AText;
    while (Result <> '') and CharInSet(Result[Length(Result)], ['0'..'9']) do
      SetLength(Result, Length(Result) - 1);
  end;

var
  I: Integer;
begin
  Result := AName;
  if (ADescription = '') or SameText(DeviceDescription(AName), ADescription) then
    Exit;
  for I := 0 to High(FDevices) do
    if SameText(FDevices[I].Description, ADescription) and SameText(Kind(FDevices[I].Name), Kind(AName)) then
      Exit(FDevices[I].Name);
end;

procedure TfrmBuilder.UpdateControls;
var
  Busy, Ready, Waiting: Boolean;
  I: Integer;
begin
  Busy := (FBuild <> nil) or FQueueRunning or (FCalib <> nil) or (FDownload <> nil);
  UpdatePanel;
  if Busy <> FAwake then
  begin
    // SteamOS (Game Mode) and laptops sleep with nobody at the controls,
    // half way through an hour's transcription (owner, Steam Machine)
    FAwake := Busy;
    ApplyPower(Busy, False);
  end;
  Ready := (FWhisperNote = '') and (edBook.Text <> '') and (lbAudio.Count > 0) and (edOut.Text <> '') and
    ((FModelPath <> '') or chkReuse.IsChecked);
  // the window stays usable while building: books are added to the queue
  // while it runs (owner)
  btnCreate.Enabled := not Busy and Ready;
  btnAddJob.Enabled := Ready;
  // the job shown is still the one selected, and not the one building
  btnUpdateJob.Enabled := Ready and (FEditJob >= 0) and (FEditJob <= High(FJobs)) and
    (lbJobs.ItemIndex = FEditJob) and (FJobs[FEditJob].State <> jsRunning);
  btnCancel.Enabled := (FBuild <> nil) or (FCalib <> nil) or (FDownload <> nil);
  // one download at a time; the model stays while it runs
  cbModel.Enabled := FDownload = nil;
  // the Settings page's calibration and diagnostics rows
  // (StartCalibration checks again anyway)
  FToolsReady := not Busy and (FWhisperNote = '');
  // the benchmarks: greyed without their model, with the time each takes
  RefreshBenchmarks;
  Waiting := False;
  for I := 0 to High(FJobs) do
    if FJobs[I].State <> jsDone then
      Waiting := True;
  btnRunQueue.Enabled := not Busy and Waiting;
  UpdateSettingsLine;
  if FQueueRunning then
    btnRunQueue.Text := 'Queue running ...'
  else
    btnRunQueue.Text := 'Run queue';
  // BookManager sees the same: busy or not, the queue
  UpdateLinkStatus;
end;

procedure TfrmBuilder.ShowBook(const AFileName: string);
var
  Book: TEpubBook;
  Audio: TStringList;
  EpubFile, Note: string;
begin
  mmBook.Lines.Clear;
  FBookTitle := '';
  FBookWrittenBy := '';
  FBookClips := 0;
  try
    EpubFile := BookAsEpub(AFileName, Note);
    if Note <> '' then
    begin
      mmBook.Lines.Add(Note);
      DebugLog(Note);
    end;
    Book := TEpubBook.Create(EpubFile);
    try
      FBookWrittenBy := Book.WrittenBy;
      FBookTitle := Book.Title;
      FBookClips := Length(Book.Clips);
      if FBookWrittenBy <> '' then
        mmBook.Lines.Add(Format('ALREADY A READ-ALONG BOOK (made by %s): choose the original EPUB to build ' +
          'from', [FBookWrittenBy]));
      mmBook.Lines.Add('Title: ' + Book.Title);
      if Book.Language <> '' then
        mmBook.Lines.Add('Language: ' + Book.Language);
      FillLanguages(Book.Language);
      mmBook.Lines.Add(Format('%d documents, %d words', [Length(Book.Documents), Book.WordCount]));
      Audio := Book.AudioFiles;
      try
        if Length(Book.Clips) > 0 then
          mmBook.Lines.Add(Format('Has media overlays already: %d clips over %d audio file(s) - the new book ' +
            'gets its own (the old audio stays in it)', [Length(Book.Clips), Audio.Count]));
      finally
        Audio.Free;
      end;
      // another book: its own audio and output (the last book's audio
      // left in the list almost went into the new one - owner)
      if not SameFileName(edBook.Text, AFileName) then
      begin
        if lbAudio.Count > 0 then
          WindowLine('Another book: the audio list was emptied.');
        lbAudio.Clear;
        // the EPUB 3 in the output folder, under the book's own name
        // (numbered when taken) - the user may change it (owner)
        edOut.Text := DefaultOutput(AFileName);
        FAutoOut := edOut.Text;
      end;
      edBook.Text := AFileName;
    finally
      Book.Free;
    end;
  except
    on E: Exception do
    begin
      // a copy-protected book is refused here, with the library's message
      edBook.Text := '';
      mmBook.Lines.Add('This book cannot be used: ' + E.Message);
    end;
  end;
  UpdateControls;
end;

procedure TfrmBuilder.AddAudio(AFiles: TStrings);
var
  L: TStringList;
  I: Integer;
  Protection: string;
begin
  L := TStringList.Create;
  try
    L.Assign(AFiles);
    // chapter2 before chapter10, Part IV after Part III
    L.CustomSort(NaturalFileOrder);
    for I := 0 to L.Count - 1 do
      if lbAudio.Items.IndexOf(L[I]) < 0 then
      begin
        // copy protection (an .aax straight from Audible, FairPlay) is
        // refused here, never removed; a DRM-free .aax is added like an m4b
        try
          Protection := FFmpegMp4Protection(L[I]);
        except
          on E: Exception do
            Protection := '';   // unreadable: the build reports it
        end;
        if Protection <> '' then
          WindowLine(Format('%s is copy protected (%s) and was not added. EpubBuilder does not remove copy ' +
            'protection: a DRM-free copy of the audio is needed.', [ExtractFileName(L[I]), Protection]))
        else
          lbAudio.Items.Add(L[I]);
      end;
  finally
    L.Free;
  end;
  UpdateControls;
end;

procedure TfrmBuilder.btnBookClick(Sender: TObject);
var
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    // upper case too: Linux's file dialogs tell .MOBI from .mobi
    D.Filter := 'Books (*.epub;*.mobi;*.prc;*.azw;*.azw3)|*.epub;*.mobi;*.prc;*.azw;*.azw3;*.EPUB;*.MOBI;*.PRC;' +
      '*.AZW;*.AZW3|EPUB books (*.epub)|*.epub;*.EPUB|MOBI books (*.mobi;*.prc;*.azw;*.azw3)|*.mobi;*.prc;*.azw;' +
      '*.azw3;*.MOBI;*.PRC;*.AZW;*.AZW3';
    D.InitialDir := FBookFolder;
    if D.Execute then
    begin
      // the next Book... opens here (owner, 2026-11-19; kept between runs)
      FBookFolder := ExtractFileDir(D.FileName);
      SaveSettings;
      ShowBook(D.FileName);
      AskOutputPlace(D.FileName, nil);
    end;
  finally
    D.Free;
  end;
end;

procedure TfrmBuilder.btnAddAudioClick(Sender: TObject);
var
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Audio (*.m4b;*.m4a;*.aax;*.mp3;*.wav;*.flac;*.ogg;*.opus;*.aac)|*.m4b;*.m4a;*.aax;*.mp3;*.wav;' +
      '*.flac;*.ogg;*.opus;*.aac|All files (*.*)|*.*';
    D.Options := D.Options + [TOpenOption.ofAllowMultiSelect];
    D.InitialDir := FAudioFolder;
    if D.Execute then
    begin
      // the next Add audio... opens here
      FAudioFolder := ExtractFileDir(D.FileName);
      SaveSettings;
      AddAudio(D.Files);
    end;
  finally
    D.Free;
  end;
end;

procedure TfrmBuilder.btnAddFolderClick(Sender: TObject);
var
  Folder: string;
  L: TStringList;
begin
  Folder := FAudioFolder;
  if not SelectDirectory('Folder of audio files', '', Folder) then
    Exit;
  FAudioFolder := ExcludeTrailingPathDelimiter(Folder);
  SaveSettings;
  try
    L := WhisperListAudioFiles(Folder);
    try
      AddAudio(L);
    finally
      L.Free;
    end;
  except
    on E: Exception do
      WindowLine(E.Message);
  end;
end;

procedure TfrmBuilder.btnRemoveClick(Sender: TObject);
begin
  if lbAudio.ItemIndex >= 0 then
    lbAudio.Items.Delete(lbAudio.ItemIndex);
  UpdateControls;
end;

procedure TfrmBuilder.btnUpClick(Sender: TObject);
var
  I: Integer;
begin
  I := lbAudio.ItemIndex;
  if I > 0 then
  begin
    lbAudio.Items.Exchange(I, I - 1);
    lbAudio.ItemIndex := I - 1;
  end;
end;

procedure TfrmBuilder.btnDownClick(Sender: TObject);
var
  I: Integer;
begin
  I := lbAudio.ItemIndex;
  if (I >= 0) and (I < lbAudio.Count - 1) then
  begin
    lbAudio.Items.Exchange(I, I + 1);
    lbAudio.ItemIndex := I + 1;
  end;
end;

procedure TfrmBuilder.btnModelClick(Sender: TObject);
var
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Whisper models (ggml-*.bin)|ggml-*.bin|All files (*.*)|*.*';
    if FModelPath <> '' then
      D.InitialDir := ExtractFileDir(FModelPath);
    if D.Execute then
    begin
      FModelPath := D.FileName;
      // the device the calibration found fastest for this model
      ApplyCalibration(True);
      SaveSettings;
    end;
  finally
    D.Free;
  end;
  FillModels;
  UpdateControls;
end;

procedure TfrmBuilder.cbModelChange(Sender: TObject);
var
  Path, Name, Amount: string;
  I: Integer;
begin
  if FFillingModels or (cbModel.ItemIndex < 0) or (cbModel.ItemIndex >= FModelItems.Count) then
    Exit;
  Path := FModelItems[cbModel.ItemIndex];
  if Path = '' then
  begin
    btnModelClick(nil);
    Exit;
  end;
  Name := ModelShortName(Path);
  I := ModelCatalogueIndex(Name);
  if FileExists(Path) then
  begin
    FModelPath := Path;
    // the device the calibration found fastest for this model
    ApplyCalibration(True);
    SaveSettings;
    UpdateControls;
    // Core ML: a model there without its encoder works (on Metal); the
    // encoder is offered
    if FCoreML and (I >= 0) and not UsesCoreML(Path) then
      Ask(Format('%s has no Core ML encoder here: its encoder runs on Metal.' +
        sLineBreak + sLineBreak + 'Download the Core ML encoder (about %s) so it runs on the Neural Engine? ' +
        'Its first use is slow: macOS compiles it for this Mac.', [ModelLabel(Name),
        ModelSizeText(MODEL_CATALOGUE[I].EncoderMB)]), TMsgDlgType.mtConfirmation,
        [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo,
        procedure(const AResult: TModalResult)
        begin
          if AResult = mrYes then
            StartDownload(Name, False, True);
        end)
    else if FCalibPending and (FCalib = nil) and (FBuild = nil) then
    begin
      // the first model here: the calibration's question now
      FCalibPending := False;
      CheckCalibrationAtStart;
    end
    else
      // a model not timed here yet: offered, not only said
      OfferCalibration;
    Exit;
  end;
  if I < 0 then
  begin
    FillModels;
    Exit;
  end;
  if FCoreML then
    Amount := Format('about %s, and %s for its Core ML encoder', [ModelSizeText(MODEL_CATALOGUE[I].SizeMB),
      ModelSizeText(MODEL_CATALOGUE[I].EncoderMB)])
  else
    Amount := 'about ' + ModelSizeText(MODEL_CATALOGUE[I].SizeMB);
  Ask(Format('%s is not downloaded yet.' + sLineBreak + sLineBreak + 'Download it now? ' +
    '%s, from whisper.cpp''s model repository on Hugging Face, into' + sLineBreak + '%s',
    [ModelLabel(Name), Amount, FModelsFolder]), TMsgDlgType.mtConfirmation,
    [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbYes,
    procedure(const AResult: TModalResult)
    begin
      if AResult = mrYes then
        StartDownload(Name, True, FCoreML)
      else
        FillModels;   // back to the model chosen before
    end);
end;

procedure TfrmBuilder.ChooseModelsFolder;
var
  Folder, Same: string;
begin
  Folder := FModelsFolder;
  if not SelectDirectory('Folder for the Whisper models', '', Folder) then
    Exit;
  Folder := ExcludeTrailingPathDelimiter(Folder);
  if not FolderWritable(Folder) then
    LogLine('Note: ' + Folder + ' cannot be written - models cannot be downloaded into it.');
  FModelsFolder := Folder;
  // the model chosen: the same one in the new folder when it is there
  if FModelPath <> '' then
  begin
    Same := TPath.Combine(FModelsFolder, ExtractFileName(FModelPath));
    if FileExists(Same) then
      FModelPath := Same;
  end;
  LogLine('Models folder: ' + FModelsFolder);
  SaveSettings;
  FillModels;
  UpdateControls;
end;

procedure TfrmBuilder.FillModels;
var
  I, K, Sel: Integer;
  Path, Item, Shown: string;
  Order: TArray<Integer>;
begin
  FFillingModels := True;
  try
    cbModel.Items.BeginUpdate;
    try
      cbModel.Items.Clear;
      FModelItems.Clear;
      Sel := -1;
      // the catalogue: without expert mode only base and large-v3-turbo,
      // and the model in use
      // base and turbo first, always; then every language (here, to
      // download), the English-only ones last - ModelListOrder
      Order := ModelListOrder(FModelsFolder);
      for K := 0 to Length(Order) - 1 do
      begin
        I := Order[K];
        Shown := ModelLabel(MODEL_CATALOGUE[I].Name);
        Path := TPath.Combine(FModelsFolder, ModelFileName(MODEL_CATALOGUE[I].Name));
        if not FExpert and not ModelIsStandard(MODEL_CATALOGUE[I].Name) and not SameFileName(Path, FModelPath) then
          Continue;
        if not FileExists(Path) then
          Item := Format('%s - %s (%s to download)', [Shown, MODEL_CATALOGUE[I].Note,
            ModelSizeText(MODEL_CATALOGUE[I].SizeMB)])
        else if FCoreML and UsesCoreML(Path) then
          Item := Format('%s - %s (Core ML)', [Shown, MODEL_CATALOGUE[I].Note])
        else if FCoreML then
          Item := Format('%s - %s (no Core ML encoder)', [Shown, MODEL_CATALOGUE[I].Note])
        else
          Item := Format('%s - %s', [Shown, MODEL_CATALOGUE[I].Note]);
        cbModel.Items.Add(Item);
        FModelItems.Add(Path);
        if SameFileName(Path, FModelPath) then
          Sel := FModelItems.Count - 1;
      end;
      // other models in the folder (quantised, fine-tuned, older ones):
      // expert mode
      if FExpert and TDirectory.Exists(FModelsFolder) then
        for Path in TDirectory.GetFiles(FModelsFolder, 'ggml-*.bin') do
          if ModelCatalogueIndex(ModelShortName(Path)) < 0 then
          begin
            cbModel.Items.Add(ModelShortName(Path) + ' - in the models folder');
            FModelItems.Add(Path);
            if SameFileName(Path, FModelPath) then
              Sel := FModelItems.Count - 1;
          end;
      // a model chosen in another folder
      if (FModelPath <> '') and (Sel < 0) then
      begin
        cbModel.Items.Add(ModelShortName(FModelPath) + ' - ' + FModelPath);
        FModelItems.Add(FModelPath);
        Sel := FModelItems.Count - 1;
      end;
      if FExpert then
      begin
        cbModel.Items.Add('Other model file ...');
        FModelItems.Add('');
      end;
    finally
      cbModel.Items.EndUpdate;
    end;
    cbModel.ItemIndex := Sel;
  finally
    FFillingModels := False;
  end;
end;

procedure TfrmBuilder.StartDownload(const AName: string; AWithModel, AWithEncoder: Boolean);
begin
  if FDownload <> nil then
    Exit;
  if not FolderWritable(FModelsFolder) then
  begin
    LogLine(Format('%s cannot be written: choose another models folder (Folder...).', [FModelsFolder]));
    FillModels;
    Exit;
  end;
  FDownload := TModelDownload.Create(AName, FModelsFolder, AWithModel, AWithEncoder);
  FDownload.OnLog :=
    procedure(AText: string)
    begin
      LogLine(AText);
    end;
  FDownload.OnProgress :=
    procedure(AReceived, ATotal: Int64)
    begin
      if ATotal > 0 then
      begin
        pbBuild.Value := AReceived * 100 / ATotal;
        lblStatus.Text := Format('Downloading %s: %d of %d MB', [AName, AReceived div 1000000,
          ATotal div 1000000]);
      end
      else
        lblStatus.Text := Format('Downloading %s: %d MB', [AName, AReceived div 1000000]);
    end;
  FDownload.OnTerminate := DownloadDone;
  FDownload.FreeOnTerminate := True;
  pbBuild.Value := 0;
  lblStatus.Text := Format('Downloading %s ...', [AName]);
  UpdateControls;
  FDownload.Start;
end;

procedure TfrmBuilder.StepLowestSpeed(ADelta: Integer);
begin
  FLowestSpeed := (FLowestSpeed + ADelta + LOWEST_SPEED_TOP + 1) mod (LOWEST_SPEED_TOP + 1);
  SaveSettings;
  if FLowestSpeed = 0 then
    LogLine('Lowest acceptable speed: any - every calibrated model and device can be used, however slow.')
  else
    LogLine(Format('Lowest acceptable speed: %.1fx real time - a model or device the calibration timed below it ' +
      'is not used for builds or benchmarks.', [FLowestSpeed / 10]));
  // the benchmarks' items: faded or not
  RefreshBenchmarks;
end;

function TfrmBuilder.LowestSpeedText: string;
begin
  if FLowestSpeed = 0 then
    Result := '< 0.0x - any speed >'
  else
    Result := Format('< %.1fx >', [FLowestSpeed / 10]);
end;

function TfrmBuilder.TooSlow(const AModel, ADevice: string; out AWhy: string): Boolean;
var
  D: TWhisperDevice;
  Dev, Best, Name: string;
  Speed, BestSpeed, Limit: Double;
begin
  Result := False;
  AWhy := '';
  if (FLowestSpeed <= 0) or (AModel = '') then
    Exit;
  Limit := FLowestSpeed / 10;
  Name := ChangeFileExt(ExtractFileName(AModel), '');
  Dev := ADevice;
  if BuilderFindDevice(ADevice, D) then
    Dev := D.Name;
  Speed := CalibrationSpeed(SettingsFile, AModel, Dev);
  if not CalibrationBest(SettingsFile, AModel, Best, BestSpeed) then
    BestSpeed := 0;
  // the model at its best here
  if (BestSpeed > 0) and (BestSpeed < Limit) then
  begin
    AWhy := Format('%s is too slow on this machine: the calibration timed it at %.1fx real time at best (on %s) - ' +
      'about %.1f hours for each hour of audio. The lowest acceptable speed is %.1fx.' + sLineBreak + sLineBreak +
      'Choose a faster model (base), or lower Settings > Lowest acceptable speed to use it anyway.',
      [Name, BestSpeed, Best, 1 / BestSpeed, Limit]);
    Exit(True);
  end;
  // this device: another one is fast enough
  if (Speed > 0) and (Speed < Limit) then
  begin
    AWhy := Format('%s is too slow on %s: %.1fx real time in the calibration (the lowest acceptable speed is ' +
      '%.1fx).', [Name, Dev, Speed, Limit]);
    if BestSpeed > 0 then
      AWhy := AWhy + sLineBreak + sLineBreak + Format('It runs at %.1fx on %s: choose that device (Settings > ' +
        'Device), or lower Settings > Lowest acceptable speed.', [BestSpeed, Best])
    else
      AWhy := AWhy + sLineBreak + sLineBreak + 'Choose another device, or lower Settings > Lowest acceptable speed.';
    Exit(True);
  end;
end;

procedure TfrmBuilder.ToggleExpert;
begin
  FExpert := not FExpert;
  SaveSettings;
  FillModels;
  UpdateControls;
  if FExpert then
    LogLine('Expert mode: the model list offers every model. On the machines tested the English-only (.en) ' +
      'models were slower in a build than their twins, and none was more accurate than turbo.')
  else
    LogLine('Expert mode off: the model list offers base (fast) and turbo (the most accurate), and ' +
      'the model in use.');
end;

procedure TfrmBuilder.miExpertClick(Sender: TObject);
begin
  ToggleExpert;
end;

procedure TfrmBuilder.DownloadEveryModel;
var
  Names: TArray<string>;
  I, MB: Integer;
begin
  if (FDownload <> nil) or (FBuild <> nil) or (FCalib <> nil) or FQueueRunning then
  begin
    Tell('A build, a calibration or a download is running: download the models when it has ended.');
    Exit;
  end;
  Names := nil;
  MB := 0;
  // the models the list offers: two without expert mode
  for I := 0 to Length(MODEL_CATALOGUE) - 1 do
    if (FExpert or ModelIsStandard(MODEL_CATALOGUE[I].Name)) and
      not FileExists(TPath.Combine(FModelsFolder, ModelFileName(MODEL_CATALOGUE[I].Name))) then
    begin
      Names := Names + [MODEL_CATALOGUE[I].Name];
      Inc(MB, MODEL_CATALOGUE[I].SizeMB);
      if FCoreML then
        Inc(MB, MODEL_CATALOGUE[I].EncoderMB);
    end;
  if Length(Names) = 0 then
  begin
    Tell('Every model of the list is in the models folder already.');
    Exit;
  end;
  Ask(Format('Download the %d model(s) that are not installed yet?' + sLineBreak + sLineBreak +
    'About %s in all, from whisper.cpp''s model repository on Hugging Face, into %s - one after another, each ' +
    'checked. Cancel stops it; what is here stays.', [Length(Names), ModelSizeText(MB), FModelsFolder]),
    TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbYes,
    procedure(const AResult: TModalResult)
    begin
      if AResult <> mrYes then
      begin
        FPadToModel := True;
        Exit;
      end;
      FDownloadQueue := Names;
      FDownloadAll := True;
      StartNextDownload;
      // not started (the folder cannot be written): nothing is queued
      if FDownload = nil then
      begin
        FDownloadQueue := nil;
        FDownloadAll := False;
        FPadToModel := True;
      end;
    end);
end;

procedure TfrmBuilder.StartNextDownload;
var
  Next: string;
begin
  if Length(FDownloadQueue) = 0 then
    Exit;
  Next := FDownloadQueue[0];
  Delete(FDownloadQueue, 0, 1);
  LogLine(Format('Download every model: %s (%d more after it)', [Next, Length(FDownloadQueue)]));
  // with its Core ML encoder where those are used (as a model chosen)
  StartDownload(Next, True, FCoreML);
end;

procedure TfrmBuilder.DownloadDone(Sender: TObject);
var
  D: TModelDownload;
begin
  // the thread frees itself after this (FreeOnTerminate)
  D := Sender as TModelDownload;
  FDownload := nil;
  pbBuild.Value := 0;
  if FDownloadAll then
  begin
    // one of "Download every model": the model in the window stays, and
    // no calibration is offered between them
    if D.Succeeded then
      lblStatus.Text := 'Downloaded ' + D.ModelName
    else
      lblStatus.Text := 'Download not finished: ' + D.ModelName;
    FillModels;
    UpdateControls;
    if D.Succeeded and (Length(FDownloadQueue) > 0) then
    begin
      StartNextDownload;
      Exit;
    end;
    if D.Succeeded then
      LogLine('Every model is downloaded; the new ones are calibrated now (Diagnostics (every model) measures ' +
        'them).')
    else
      LogLine(Format('The downloads stopped at %s: %d more model(s) were not fetched (Download every model ' +
        'fetches what is missing).', [D.ModelName, Length(FDownloadQueue)]));
    FDownloadQueue := nil;
    FDownloadAll := False;
    // owner, 2026-11-22: models added later calibrate by themselves - the
    // ones that came (also after a stop part way)
    CalibrateNewModels;
    if FCalib = nil then
      PadBackToMenu(True);
    Exit;
  end;
  if D.Succeeded then
  begin
    FModelPath := D.Target;
    lblStatus.Text := 'Downloaded ' + D.ModelName;
    ApplyCalibration(True);
    if CalibrationSummary(SettingsFile, FModelPath) = '' then
      LogLine(D.ModelName + ' is not calibrated yet: it is calibrated now (later: Settings > ' +
        'Re-calibrate (this model)).')
    else if D.WithEncoder then
      LogLine(D.ModelName + ' was calibrated without its Core ML encoder: Settings > Re-calibrate (this model) ' +
        'times it with it (the first run compiles the encoder - slow once).');
    SaveSettings;
  end
  else
    lblStatus.Text := 'Download not finished: ' + D.ModelName;
  FillModels;
  UpdateControls;
  // the first model here: the calibration's question (start-up had none to
  // time)
  if D.Succeeded and FCalibPending and (FCalib = nil) and (FBuild = nil) then
  begin
    FCalibPending := False;
    CheckCalibrationAtStart;
  end
  else if D.Succeeded then
    // owner, 2026-11-22: calibrated by itself (was asked, 2026-11-21)
    OfferCalibration;
  // no question shown: the menu again, on Model (the next one to get)
  PadBackToMenu(True);
end;

procedure TfrmBuilder.RememberOutFolder;
var
  Folder: string;
begin
  Folder := ExcludeTrailingPathDelimiter(ExtractFileDir(Trim(edOut.Text)));
  if (Folder = '') or SameFileName(Folder, ExcludeTrailingPathDelimiter(FOutFolder)) then
    Exit;
  // a folder that is not there (a typing slip) does not become the default
  if not TDirectory.Exists(Folder) then
    Exit;
  FOutFolder := Folder;
  LogLine('Output folder: ' + Folder + ' (the next book''s output goes there too).');
  SaveSettings;
end;

procedure TfrmBuilder.btnOutClick(Sender: TObject);
var
  D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'EPUB books (*.epub)|*.epub';
    D.DefaultExt := 'epub';
    if edOut.Text <> '' then
      D.InitialDir := ExtractFileDir(edOut.Text)
    else
      D.InitialDir := FOutFolder;
    // the name only: the folder is InitialDir - the Mac's save panel takes
    // a whole path as a NAME, '/' shown as ':' (owner, 2026-11-19: a
    // file ':Users:simon:Downloads:....epub' to rename by hand)
    D.FileName := ExtractFileName(edOut.Text);
    if D.Execute then
    begin
      edOut.Text := D.FileName;
      FAutoOut := '';
      // the next book's output goes to this folder by default
      FOutFolder := ExtractFileDir(D.FileName);
      SaveSettings;
    end;
  finally
    D.Free;
  end;
  UpdateControls;
end;

procedure TfrmBuilder.btnCreateClick(Sender: TObject);
begin
  CheckThen(False);
end;

procedure TfrmBuilder.btnAddJobClick(Sender: TObject);
begin
  FUpdateJob := -1;
  CheckThen(True);
end;

procedure TfrmBuilder.btnUpdateJobClick(Sender: TObject);
begin
  if (FEditJob < 0) or (FEditJob > High(FJobs)) or (FJobs[FEditJob].State = jsRunning) then
    Exit;
  FUpdateJob := FEditJob;
  CheckThen(True);
end;

procedure TfrmBuilder.CheckThen(AQueue: Boolean);
var
  Device, Why: string;
begin
  if SameFileName(ExpandFileName(edOut.Text), ExpandFileName(edBook.Text)) then
  begin
    Tell('The output must not be the book itself: choose another output file.');
    Exit;
  end;
  if (FModelPath = '') and not (chkReuse.IsChecked and FileExists(TranscriptFileOf(edOut.Text))) then
  begin
    Tell('Choose a model: there is no saved transcript to use.');
    Exit;
  end;
  // "Default": whisper.cpp's choice, or the device chosen for it when ROCm
  // is left out
  Device := GDefaultDevice;
  if cbDevice.ItemIndex > 0 then
    Device := FDevices[cbDevice.ItemIndex - 1].Name;
  // below Settings > Lowest acceptable speed (owner, 2026-11-22): not
  // started, not queued - unless a saved transcript is used (nothing is
  // transcribed)
  if not (chkReuse.IsChecked and FileExists(TranscriptFileOf(edOut.Text))) and TooSlow(FModelPath, Device, Why) then
  begin
    Tell('Not started: ' + Why);
    Exit;
  end;
  CheckCalibrationThen(Device, AQueue);
end;

procedure TfrmBuilder.CheckCalibrationThen(const ADevice: string; AQueue: Boolean);
var
  Device, Why: string;
  Q: Boolean;
  D: TWhisperDevice;
begin
  // local copies for the dialog's anonymous method to capture
  Device := ADevice;
  Q := AQueue;
  // the calibration saw this model fail on this device (owner: large-v3 on
  // the 4 GB GTX 1650 failed): asked first, No by default
  Why := '';
  if (FModelPath <> '') and BuilderFindDevice(Device, D) then
    Why := CalibrationFailure(SettingsFile, FModelPath, D.Name);
  if Why <> '' then
  begin
    Ask(Format('In the calibration, %s FAILED on %s:' + sLineBreak + sLineBreak + '%s' +
      sLineBreak + sLineBreak + 'A build would most likely fail the same way (a model too big for the card''s ' +
      'memory fails like this). Choose another device, or a smaller model.' + sLineBreak + sLineBreak +
      'Build on it anyway?', [ExtractFileName(FModelPath), WhisperDeviceText(D), Why]), TMsgDlgType.mtWarning,
      [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo,
      procedure(const AResult: TModalResult)
      begin
        if AResult = mrYes then
          CheckBookThen(Device, Q)
        else
          Tell(Format('Not started: %s failed on %s in the calibration (Settings > Calibration results).',
            [ExtractFileName(FModelPath), D.Name]));
      end);
    Exit;
  end;
  CheckBookThen(Device, Q);
end;

procedure TfrmBuilder.CheckBookThen(const ADevice: string; AQueue: Boolean);
var
  Device, Msg: string;
  Q: Boolean;
begin
  Device := ADevice;
  Q := AQueue;
  // a book that is already a read-along one (made by this program, or with
  // synced audio of its own): asked first, No by default (owner: "I
  // accidentally tried re-encoding an already built epub")
  if (FBookWrittenBy <> '') or (FBookClips > 0) then
  begin
    if FBookWrittenBy <> '' then
      Msg := Format('%s was made by %s: it is already a read-along book.' + sLineBreak + sLineBreak +
        'Building from it again gives a copy of a copy - choose the original EPUB instead.' + sLineBreak +
        sLineBreak + 'Build from it anyway?', [ExtractFileName(edBook.Text), FBookWrittenBy])
    else
      Msg := Format('%s already has synced audio (%d clips).' + sLineBreak + sLineBreak +
        'The new book gets its own; the old audio stays in it.' + sLineBreak + sLineBreak +
        'Build from it anyway?', [ExtractFileName(edBook.Text), FBookClips]);
    Ask(Msg, TMsgDlgType.mtWarning, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo],
      TMsgDlgBtn.mbNo,
      procedure(const AResult: TModalResult)
      begin
        if AResult = mrYes then
          CheckOutputThen(Device, Q)
        else
          Tell('Not started: choose the original EPUB (Choose... above the book).');
      end);
    Exit;
  end;
  CheckOutputThen(Device, Q);
end;

procedure TfrmBuilder.CheckOutputThen(const ADevice: string; AQueue: Boolean);
var
  Device: string;
  Q: Boolean;
  I: Integer;
begin
  // local copies for the dialog's anonymous method to capture
  Device := ADevice;
  Q := AQueue;
  // a job waiting in the queue writes this output already
  for I := 0 to High(FJobs) do
    if (I <> FUpdateJob) and (FJobs[I].State in [jsWaiting, jsRunning]) and
      SameFileName(ExpandFileName(FJobs[I].Output), ExpandFileName(edOut.Text)) then
    begin
      Tell(Format('Job %d of the queue writes %s already: choose another output file (or remove that ' +
        'job).', [I + 1, edOut.Text]));
      Exit;
    end;
  // an EPUB already there: replaced without asking only when this program
  // made it from this book (a re-align); anything else asks first
  if FileExists(edOut.Text) and not (SameFileName(ExpandFileName(edOut.Text), FMadeOut) and
    SameFileName(ExpandFileName(edBook.Text), FMadeBook)) then
  begin
    Ask(Format('%s already exists.' + sLineBreak + sLineBreak +
      'Replace it with the book this build makes?', [edOut.Text]), TMsgDlgType.mtConfirmation,
      [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo,
      procedure(const AResult: TModalResult)
      begin
        if AResult = mrYes then
        begin
          if Q then
            AddJob(JobFromWindow(Device))
          else
            StartBuild(Device);
        end
        else
          Tell('Not done: ' + edOut.Text + ' is kept. Choose another output file to keep both.');
      end);
    Exit;
  end;
  if Q then
    AddJob(JobFromWindow(Device))
  else
    StartBuild(Device);
end;

procedure TfrmBuilder.StartBuild(const ADevice: string);
begin
  // the dialog may have let a build start meanwhile
  if FBuild <> nil then
    Exit;
  SaveSettings;
  mmLog.Lines.Clear;
  StartJob(JobFromWindow(ADevice), -1);
end;

function TfrmBuilder.JobFromWindow(const ADevice: string): TBuildJob;
var
  I: Integer;
begin
  // Add to queue and Create: where this book goes, the next one goes too
  RememberOutFolder;
  Result := Default(TBuildJob);
  Result.Book := edBook.Text;
  Result.Title := FBookTitle;
  if Result.Title = '' then
    Result.Title := ChangeFileExt(ExtractFileName(edBook.Text), '');
  SetLength(Result.Audio, lbAudio.Count);
  for I := 0 to lbAudio.Count - 1 do
    Result.Audio[I] := lbAudio.Items[I];
  Result.Model := FModelPath;
  Result.Device := ADevice;
  Result.Output := edOut.Text;
  Result.Chapters := chkChapters.IsChecked;
  Result.Reuse := chkReuse.IsChecked;
  Result.Language := ChosenLanguage;
  Result.Cover := FCoverChoice;
  Result.State := jsWaiting;
end;

procedure TfrmBuilder.StartJob(const AJob: TBuildJob; AIndex: Integer; ABenchmark: Boolean);
var
  Audio: TStringList;
  I: Integer;
begin
  if FBuild <> nil then
    Exit;
  pbBuild.Value := 0;
  FStarted := Now;
  FBuildTitle := AJob.Title;
  FSpeedNow := 0;
  FTimeText := '';
  FRunBook := ExpandFileName(AJob.Book);
  FRunOut := ExpandFileName(AJob.Output);
  // the output folder (Documents/EpubBuilder/Output at first) made when
  // the first book goes there
  try
    ForceDirectories(ExtractFileDir(FRunOut));
  except
    on E: Exception do
      LogLine('The output folder was not made: ' + E.Message);
  end;
  FJob := AIndex;
  FCancelled := False;
  // this build's lines, saved beside its output when it ends
  FBuildLog.Clear;
  FLogging := True;
  if AIndex >= 0 then
  begin
    FJobs[AIndex].State := jsRunning;
    FJobs[AIndex].Note := '';
    ShowJobs;
    LogLine('');
    LogLine(Format('=== Job %d of %d: %s -> %s (%s) ===', [AIndex + 1, Length(FJobs), AJob.Title,
      ExtractFileName(AJob.Output), FormatDateTime('yyyy-mm-dd hh:nn', Now)]));
  end;
  LogMachine(AJob.Model, AJob.Device);
  // Automatic: unplugged (or plugged in) during a queue
  if FAwake then
    ApplyPower(True, True);
  PrepareEstimate(AJob.Model, AJob.Device);
  Audio := TStringList.Create;
  try
    for I := 0 to High(AJob.Audio) do
      Audio.Add(AJob.Audio[I]);
    // where the build looks for the book's cover (uCovers)
    GCoverFolder := FCoverFolder;
    FBuild := TBuildThread.Create(AJob.Book, Audio, AJob.Model, AJob.Device, AJob.Output, AJob.Chapters,
      AJob.Reuse, AJob.Language);
    FBuild.CoverChoice := AJob.Cover;
    FBuild.Benchmark := ABenchmark;
  finally
    Audio.Free;
  end;
  FBuild.OnLog :=
    procedure(AText: string)
    begin
      ThreadLine(AText);
    end;
  FBuild.OnProgress :=
    procedure(APercent: Double)
    begin
      pbBuild.Value := APercent;
      FPercent := APercent;
      // the time left is measured from here: what came before (the book,
      // the audio, loading the model) does not repeat
      if (FRatePercent < 0) and (APercent > 5) then
      begin
        FRateFrom := Now;
        FRatePercent := APercent;
        FRateAudio := AudioDoneAt(APercent);
      end;
      // the transcription's end: aligning and writing from here
      if (APercent >= 90) and (FAfterFrom = 0) then
        FAfterFrom := Now;
    end;
  FBuild.OnAudioLength :=
    procedure(ASeconds: Double)
    begin
      FAudioTotal := ASeconds;
      if FExpSpeed > 0 then
        LogLine(Format('Expected: about %s for %s of audio - %.1fx real time, from %s.',
          [WhisperTimeToStr(Round((ASeconds / FExpSpeed + FExpAfter * ASeconds) * 100)),
          WhisperTimeToStr(Round(ASeconds * 100)), FExpSpeed, FExpSource]))
      else
        LogLine('Expected: no figure yet (no earlier build of this model on this device here, not calibrated) - ' +
          'the time left comes from this build''s own rate.');
    end;
  FBuild.OnStatus :=
    procedure(AText: string)
    begin
      FStatusText := AText;
      ShowStatus;
    end;
  FPercent := 0;
  FRatePercent := -1;
  FAudioTotal := 0;
  FRateAudio := 0;
  FAfterFrom := 0;
  FStatusText := 'Starting ...';
  tmStatus.Enabled := True;
  FBuild.OnTerminate := BuildDone;
  FBuild.FreeOnTerminate := True;
  UpdateControls;
  FBuild.Start;
end;

procedure TfrmBuilder.AddJob(const AJob: TBuildJob);
var
  I: Integer;
begin
  SaveSettings;
  I := FUpdateJob;
  FUpdateJob := -1;
  if (I >= 0) and (I <= High(FJobs)) and (FJobs[I].State <> jsRunning) then
  begin
    // in place: the same position, waiting again (a done one is built again)
    FJobs[I] := AJob;
    ShowJobs;
    lbJobs.ItemIndex := I;
    FEditJob := I;
    WindowLine(Format('Job %d updated: %s -> %s', [I + 1, AJob.Title, ExtractFileName(AJob.Output)]));
    UpdateControls;
    Exit;
  end;
  FJobs := FJobs + [AJob];
  ShowJobs;
  lbJobs.ItemIndex := High(FJobs);
  FEditJob := High(FJobs);
  WindowLine(Format('Added to the queue as job %d: %s -> %s', [Length(FJobs), AJob.Title,
    ExtractFileName(AJob.Output)]));
  // the window ready for the next book (owner, 2026-11-20): the book, its
  // audio, output, language and saved-transcript choice emptied; the
  // model, device, power and chapters kept
  ClearBook;
  UpdateControls;
end;

procedure TfrmBuilder.ClearBook;
begin
  mmBook.Lines.Clear;
  FBookTitle := '';
  FBookWrittenBy := '';
  FBookClips := 0;
  edBook.Text := '';
  lbAudio.Clear;
  edOut.Text := '';
  FAutoOut := '';
  chkReuse.IsChecked := False;
  SelectLanguage('');
  FCoverChoice := '';
  // the window no longer shows a job: Update job off until one is clicked
  FEditJob := -1;
end;

function TfrmBuilder.JobText(AIndex: Integer): string;
const
  STATE_TEXT: array[TJobState] of string = ('waiting', 'RUNNING', 'done', 'FAILED', 'cancelled');
begin
  Result := Format('%d. %s - %s', [AIndex + 1, FJobs[AIndex].Title, STATE_TEXT[FJobs[AIndex].State]]);
  if FJobs[AIndex].Note <> '' then
    Result := Result + ' (' + FJobs[AIndex].Note + ')';
end;

procedure TfrmBuilder.ShowJobs;
var
  I, Sel: Integer;
begin
  Sel := lbJobs.ItemIndex;
  lbJobs.BeginUpdate;
  try
    lbJobs.Clear;
    for I := 0 to High(FJobs) do
      lbJobs.Items.Add(JobText(I));
  finally
    lbJobs.EndUpdate;
  end;
  if Sel < lbJobs.Count then
    lbJobs.ItemIndex := Sel;
  // every change of the queue shows here: kept for the next start
  KeepQueue;
end;

function TfrmBuilder.KeptQueueFile: string;
begin
  Result := ChangeFileExt(SettingsFile, '-queue.json');
end;

procedure TfrmBuilder.KeepQueue;
begin
  if FRestoring then
    Exit;
  try
    if Length(FJobs) = 0 then
    begin
      if FileExists(KeptQueueFile) then
        System.SysUtils.DeleteFile(KeptQueueFile);
    end
    else
      SaveQueue(KeptQueueFile);
  except
    on E: Exception do
      DebugLog('the queue was not kept: ' + E.Message);
  end;
end;

procedure TfrmBuilder.RestoreQueue;
var
  N, I, Waiting: Integer;
begin
  if not FileExists(KeptQueueFile) then
    Exit;
  FRestoring := True;
  try
    try
      N := LoadQueue(KeptQueueFile);
    except
      on E: Exception do
      begin
        LogLine('The queue from last time could not be read: ' + E.Message);
        Exit;
      end;
    end;
  finally
    FRestoring := False;
  end;
  ShowJobs;
  Waiting := 0;
  for I := 0 to High(FJobs) do
    if FJobs[I].State = jsWaiting then
      Inc(Waiting);
  if N > 0 then
    LogLine(Format('The queue from last time: %d job(s), %d waiting (Run queue builds them).', [N, Waiting]));
end;

procedure TfrmBuilder.RunNextJob;
var
  I, Done, Failed: Integer;
  Why: string;
begin
  if (FBuild <> nil) or not FQueueRunning then
    Exit;
  for I := 0 to High(FJobs) do
    if FJobs[I].State = jsWaiting then
    begin
      // queued before Settings > Lowest acceptable speed was raised (or
      // before the calibration): left out, said why
      if not (FJobs[I].Reuse and FileExists(TranscriptFileOf(FJobs[I].Output))) and
        TooSlow(FJobs[I].Model, FJobs[I].Device, Why) then
      begin
        FJobs[I].State := jsFailed;
        FJobs[I].Note := 'too slow here';
        LogLine(Format('Job %d (%s) left out: %s', [I + 1, FJobs[I].Title, StringReplace(Why, sLineBreak +
          sLineBreak, ' ', [rfReplaceAll])]));
        ShowJobs;
        Continue;
      end;
      StartJob(FJobs[I], I);
      Exit;
    end;
  // nothing left
  FQueueRunning := False;
  Done := 0;
  Failed := 0;
  for I := 0 to High(FJobs) do
    if FJobs[I].State = jsDone then
      Inc(Done)
    else if FJobs[I].State in [jsFailed, jsCancelled] then
      Inc(Failed);
  LogLine('');
  LogLine(Format('=== Queue finished (%s): %d done, %d failed or cancelled ===', [FormatDateTime('yyyy-mm-dd ' +
    'hh:nn', Now), Done, Failed]));
  WriteQueueReport;
  // the books built leave the queue (owner, 2026-11-20: "If a book has
  // been transcribed it's no longer queued, it's done"); the report above
  // keeps them
  if Done > 0 then
  begin
    for I := High(FJobs) downto 0 do
      if FJobs[I].State = jsDone then
        Delete(FJobs, I, 1);
    FEditJob := -1;
    LogLine(Format('%d book(s) built: out of the queue (the queue report lists them).', [Done]));
    ShowJobs;
  end;
  UpdateControls;
  PadBackToMenu(False);
end;

{ ASeconds as h:mm:ss. }
function HmsText(ASeconds: Double): string;
var
  S: Int64;
begin
  S := Round(ASeconds);
  Result := Format('%d:%.2d:%.2d', [S div 3600, (S div 60) mod 60, S mod 60]);
end;

{ AText for a CSV field: in quotes, quotes doubled. }
function CsvText(const AText: string): string;
begin
  Result := '"' + StringReplace(AText, '"', '""', [rfReplaceAll]) + '"';
end;

procedure TfrmBuilder.WriteQueueReport;
const
  STATE_TEXT: array[TJobState] of string = ('waiting', 'running', 'done', 'FAILED', 'cancelled');
var
  Md, Csv: TStringList;
  I: Integer;
  J: TBuildJob;
  S: TBuildSummary;
  Folder, Base, Speed, Mb: string;
  FS: TFormatSettings;
  TotalAudio, TotalTime: Double;
  TotalBytes: Int64;

  { ACount as 'N (P %)' of the book words. }
  function Part(ACount, ABook: Integer): string;
  begin
    if ABook > 0 then
      Result := Format('%d (%.1f %%)', [ACount, ACount * 100 / ABook], FS)
    else
      Result := IntToStr(ACount);
  end;

  { A figure for the CSV ('.' decimals). }
  function Num(AValue: Double; ADecimals: Integer): string;
  begin
    Result := FloatToStrF(AValue, ffFixed, 15, ADecimals, FS);
  end;

begin
  if Length(FJobs) = 0 then
    Exit;
  FS := TFormatSettings.Invariant;
  // the queue file's name (books.json -> books.md, books.csv - owner);
  // a queue never saved: beside the first job's output, dated
  if FQueueFile <> '' then
    Base := ChangeFileExt(FQueueFile, '')
  else
  begin
    Folder := ExtractFilePath(ExpandFileName(FJobs[0].Output));
    Base := TPath.Combine(Folder, 'EpubBuilder-report-' + FormatDateTime('yyyy-mm-dd-hhnn', Now));
  end;
  Md := TStringList.Create;
  Csv := TStringList.Create;
  try
    TotalAudio := 0;
    TotalTime := 0;
    TotalBytes := 0;
    Md.Add('# EpubBuilder queue report');
    Md.Add('');
    Md.Add(Format('%s - %d job(s)', [FormatDateTime('yyyy-mm-dd hh:nn', Now), Length(FJobs)]));
    Md.Add('');
    Md.Add('| # | Book | State | Time | Audio | Speed | Matched | Verdict | EPUB |');
    Md.Add('|---|---|---|---|---|---|---|---|---|');
    Csv.Add('job,title,state,started,seconds,audio_seconds,speed_x,saved_transcript,transcribe_seconds,model,' +
      'device,language,files,parts,book_words,heard_words,exact,similar,moved,interpolated,not_heard,' +
      'not_spoken,front_back_matter,matched_percent,verdict,words_per_second,clips,left_out,chapter_marks,' +
      'upgraded_epub2,epub_bytes,book,output,note,device_text,machine');
    for I := 0 to High(FJobs) do
    begin
      J := FJobs[I];
      S := J.Summary;
      if (J.Seconds > 0) and (S.AudioSeconds > 0) then
        Speed := Format('%.1fx', [S.AudioSeconds / J.Seconds], FS)
      else
        Speed := '-';
      if J.OutputBytes > 0 then
        Mb := Format('%.1f MB', [J.OutputBytes / 1048576], FS)
      else
        Mb := '-';
      if J.State = jsDone then
      begin
        TotalAudio := TotalAudio + S.AudioSeconds;
        TotalTime := TotalTime + J.Seconds;
        TotalBytes := TotalBytes + J.OutputBytes;
      end;
      // the table row
      Md.Add(Format('| %d | %s | %s | %s | %s | %s | %s | %s | %s |', [I + 1,
        StringReplace(J.Title, '|', '/', [rfReplaceAll]), STATE_TEXT[J.State],
        IfThen(J.Seconds > 0, HmsText(J.Seconds), '-'), IfThen(S.AudioSeconds > 0, HmsText(S.AudioSeconds), '-'),
        Speed, IfThen(S.Verdict <> '', Format('%.1f %%', [S.Matched], FS), '-'), IfThen(S.Verdict <> '',
        S.Verdict, '-'), Mb]));
      // the CSV row: everything
      Csv.Add(Format('%d,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s,%d,%d,%d,%s,%d,' +
        '%s,%s,%s,%s,%s', [I + 1, CsvText(J.Title), STATE_TEXT[J.State], IfThen(J.Started > 0,
        FormatDateTime('yyyy-mm-dd hh:nn:ss', J.Started), ''), Num(J.Seconds, 1), Num(S.AudioSeconds, 1),
        IfThen(Speed = '-', '', Num(S.AudioSeconds / Max(J.Seconds, 0.001), 2)),
        IfThen(S.SavedTranscript, 'yes', 'no'), Num(S.TranscribeSeconds, 1), CsvText(S.Model), CsvText(S.Device),
        S.Language, S.Files, S.Parts, S.Stats.BookWords, S.HeardWords, S.Stats.Exact, S.Stats.Similar,
        S.Stats.Moved, S.Stats.Interpolated, S.Stats.NotHeard, S.Stats.NotSpoken, S.EdgeWords,
        Num(S.Matched, 2), S.Verdict, Num(S.Stats.WordsPerSecond, 2), S.Clips, S.LeftOut, S.ChapterMarks,
        IfThen(S.Upgraded, 'yes', 'no'), J.OutputBytes, CsvText(J.Book), CsvText(J.Output),
        CsvText(IfThen(S.Error <> '', S.Error, J.Note)), CsvText(S.DeviceText), CsvText(S.Machine)]));
    end;
    Md.Add('');
    if TotalTime > 0 then
      Md.Add(Format('Built: %s of audio in %s (%.1fx), %.1f MB of EPUBs.', [HmsText(TotalAudio),
        HmsText(TotalTime), TotalAudio / TotalTime, TotalBytes / 1048576], FS));
    // a section per job: every figure, with what it means
    for I := 0 to High(FJobs) do
    begin
      J := FJobs[I];
      S := J.Summary;
      Md.Add('');
      Md.Add(Format('## %d. %s - %s', [I + 1, J.Title, STATE_TEXT[J.State]]));
      Md.Add('');
      Md.Add('- Book: `' + J.Book + '`');
      Md.Add('- Output: `' + J.Output + '`' + IfThen(J.OutputBytes > 0, Format(' (%.1f MB)', [J.OutputBytes /
        1048576], FS), ''));
      if J.Started = 0 then
      begin
        Md.Add('- Not run in this session' + IfThen(J.Note <> '', ' (' + J.Note + ')', ''));
        Continue;
      end;
      Md.Add(Format('- Started %s, took %s', [FormatDateTime('yyyy-mm-dd hh:nn', J.Started), HmsText(J.Seconds)]));
      if S.Error <> '' then
        Md.Add('- **Failed:** ' + S.Error);
      if S.Machine <> '' then
        Md.Add('- Machine: ' + S.Machine);
      if S.AudioSeconds > 0 then
        Md.Add(Format('- Audio: %s in %d file(s), %d part(s); language %s', [HmsText(S.AudioSeconds), S.Files,
          S.Parts, IfThen(S.Language = '', 'not given', S.Language)]));
      if S.SavedTranscript then
        Md.Add('- Transcript: the saved one' + IfThen(S.Model <> '', ' (made with ' + S.Model + ')', ''))
      else if S.TranscribeSeconds > 0 then
        Md.Add(Format('- Transcribed with %s on %s in %s (%.1fx)', [S.Model, IfThen(S.DeviceText = '',
          IfThen(S.Device = '', 'the default device', S.Device), S.DeviceText), HmsText(S.TranscribeSeconds),
          S.AudioSeconds /
          Max(S.TranscribeSeconds, 0.001)], FS));
      if S.Verdict <> '' then
      begin
        Md.Add(Format('- Words: %d in the book, %d heard by Whisper', [S.Stats.BookWords, S.HeardWords]));
        Md.Add('  - Exact: ' + Part(S.Stats.Exact, S.Stats.BookWords));
        Md.Add('  - Similar: ' + Part(S.Stats.Similar, S.Stats.BookWords));
        Md.Add('  - Moved (read elsewhere - footnotes): ' + Part(S.Stats.Moved, S.Stats.BookWords));
        Md.Add('  - Interpolated: ' + Part(S.Stats.Interpolated, S.Stats.BookWords));
        Md.Add('  - Not heard: ' + Part(S.Stats.NotHeard, S.Stats.BookWords));
        Md.Add('  - Not spoken: ' + Part(S.Stats.NotSpoken, S.Stats.BookWords) + Format(', of them %d front / ' +
          'back matter', [S.EdgeWords]));
        Md.Add(Format('- **Matched: %.1f %% of the timed words - %s**; reading speed %.2f words/s', [S.Matched,
          S.Verdict, S.Stats.WordsPerSecond], FS));
      end;
      if S.Clips > 0 then
        Md.Add(Format('- Written: %d clips, %d timed word(s) left out, %d chapter mark(s)%s', [S.Clips,
          S.LeftOut, S.ChapterMarks, IfThen(S.Upgraded, '; EPUB 2 made EPUB 3', '')]));
      Md.Add('- Log: `' + J.Output + '.log`');
    end;
    try
      Md.SaveToFile(Base + '.md', TEncoding.UTF8);
      Csv.SaveToFile(Base + '.csv', TEncoding.UTF8);
      LogLine('Report: ' + Base + '.md (and .csv with every figure)');
    except
      on E: Exception do
        LogLine('The report was not written: ' + E.Message);
    end;
  finally
    Md.Free;
    Csv.Free;
  end;
end;

procedure TfrmBuilder.tmQueueTimer(Sender: TObject);
begin
  tmQueue.Enabled := False;
  RunNextJob;
end;

procedure TfrmBuilder.btnRunQueueClick(Sender: TObject);
var
  I, N: Integer;
begin
  if (FBuild <> nil) or FQueueRunning then
    Exit;
  // failed and cancelled jobs run again; done ones are skipped
  N := 0;
  for I := 0 to High(FJobs) do
  begin
    if FJobs[I].State in [jsFailed, jsCancelled, jsRunning] then
      FJobs[I].State := jsWaiting;
    if FJobs[I].State = jsWaiting then
      Inc(N);
  end;
  ShowJobs;
  if N = 0 then
  begin
    LogLine('Nothing in the queue to run: add books with "Add to queue", or load a queue.');
    Exit;
  end;
  mmLog.Lines.Clear;
  LogLine(Format('=== Queue: %d job(s) to build (%s) ===', [N, FormatDateTime('yyyy-mm-dd hh:nn', Now)]));
  QueueSleepNote;
  FQueueRunning := True;
  RunNextJob;
end;

procedure TfrmBuilder.btnJobRemoveClick(Sender: TObject);
var
  I: Integer;
begin
  // the jobs' numbers change: the window no longer stands for one
  FEditJob := -1;
  I := lbJobs.ItemIndex;
  if (I < 0) or (I > High(FJobs)) then
    Exit;
  if I = FJob then
  begin
    WindowLine('The job running cannot be removed: Cancel stops it.');
    Exit;
  end;
  Delete(FJobs, I, 1);
  if FJob > I then
    Dec(FJob);
  ShowJobs;
  lbJobs.ItemIndex := Min(I, High(FJobs));
  UpdateControls;
end;

procedure TfrmBuilder.btnJobUpClick(Sender: TObject);
var
  I: Integer;
  T: TBuildJob;
begin
  // the jobs' numbers change: the window no longer stands for one
  FEditJob := -1;
  I := lbJobs.ItemIndex;
  if (I < 1) or (I > High(FJobs)) then
    Exit;
  T := FJobs[I - 1];
  FJobs[I - 1] := FJobs[I];
  FJobs[I] := T;
  // the job running keeps its index
  if FJob = I then
    FJob := I - 1
  else if FJob = I - 1 then
    FJob := I;
  ShowJobs;
  lbJobs.ItemIndex := I - 1;
end;

procedure TfrmBuilder.btnJobDownClick(Sender: TObject);
var
  I: Integer;
  T: TBuildJob;
begin
  // the jobs' numbers change: the window no longer stands for one
  FEditJob := -1;
  I := lbJobs.ItemIndex;
  if (I < 0) or (I >= High(FJobs)) then
    Exit;
  T := FJobs[I + 1];
  FJobs[I + 1] := FJobs[I];
  FJobs[I] := T;
  if FJob = I then
    FJob := I + 1
  else if FJob = I + 1 then
    FJob := I;
  ShowJobs;
  lbJobs.ItemIndex := I + 1;
end;

procedure TfrmBuilder.SaveQueue(const AFileName: string);
const
  STATE_NAME: array[TJobState] of string = ('waiting', 'waiting', 'done', 'failed', 'cancelled');
var
  Root, J: TJSONObject;
  Jobs, A: TJSONArray;
  I, K: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('epubBuilderQueue', TJSONNumber.Create(1));
    Jobs := TJSONArray.Create;
    Root.AddPair('jobs', Jobs);
    for I := 0 to High(FJobs) do
    begin
      J := TJSONObject.Create;
      J.AddPair('book', FJobs[I].Book);
      J.AddPair('title', FJobs[I].Title);
      A := TJSONArray.Create;
      for K := 0 to High(FJobs[I].Audio) do
        A.Add(FJobs[I].Audio[K]);
      J.AddPair('audio', A);
      J.AddPair('model', FJobs[I].Model);
      J.AddPair('device', FJobs[I].Device);
      // found again by it when the list's numbers move
      J.AddPair('deviceDescription', DeviceDescription(FJobs[I].Device));
      J.AddPair('output', FJobs[I].Output);
      J.AddPair('chapters', TJSONBool.Create(FJobs[I].Chapters));
      J.AddPair('useSavedTranscript', TJSONBool.Create(FJobs[I].Reuse));
      J.AddPair('cover', FJobs[I].Cover);
      // '' = the book's own
      J.AddPair('language', FJobs[I].Language);
      // the job running is saved as waiting (it has not ended)
      J.AddPair('state', STATE_NAME[FJobs[I].State]);
      J.AddPair('note', FJobs[I].Note);
      Jobs.AddElement(J);
    end;
    TFile.WriteAllText(AFileName, Root.Format(2), TEncoding.UTF8);
  finally
    Root.Free;
  end;
end;

function TfrmBuilder.LoadQueue(const AFileName: string): Integer;
var
  V: TJSONValue;
  Root, J: TJSONObject;
  Jobs, A: TJSONArray;
  I, K, Dup: Integer;
  Job: TBuildJob;
  St, Desc: string;
begin
  Result := 0;
  FEditJob := -1;
  V := TJSONObject.ParseJSONValue(TFile.ReadAllText(AFileName, TEncoding.UTF8));
  try
    if not (V is TJSONObject) then
      raise Exception.Create('not a queue file (no JSON object)');
    Root := TJSONObject(V);
    if not Root.TryGetValue<TJSONArray>('jobs', Jobs) then
      raise Exception.Create('not a queue file (no "jobs")');
    for I := 0 to Jobs.Count - 1 do
    begin
      if not (Jobs.Items[I] is TJSONObject) then
        Continue;
      J := TJSONObject(Jobs.Items[I]);
      Job := Default(TBuildJob);
      J.TryGetValue<string>('book', Job.Book);
      J.TryGetValue<string>('title', Job.Title);
      J.TryGetValue<string>('model', Job.Model);
      J.TryGetValue<string>('device', Job.Device);
      if J.TryGetValue<string>('deviceDescription', Desc) then
        Job.Device := DeviceMatch(Job.Device, Desc);
      J.TryGetValue<string>('output', Job.Output);
      J.TryGetValue<Boolean>('chapters', Job.Chapters);
      J.TryGetValue<Boolean>('useSavedTranscript', Job.Reuse);
      J.TryGetValue<string>('cover', Job.Cover);
      J.TryGetValue<string>('language', Job.Language);
      J.TryGetValue<string>('note', Job.Note);
      if J.TryGetValue<TJSONArray>('audio', A) then
        for K := 0 to A.Count - 1 do
          Job.Audio := Job.Audio + [A.Items[K].Value];
      if (Job.Book = '') or (Job.Output = '') or (Length(Job.Audio) = 0) then
        Continue;
      if Job.Title = '' then
        Job.Title := ChangeFileExt(ExtractFileName(Job.Book), '');
      St := '';
      J.TryGetValue<string>('state', St);
      // a book built is no longer queued (owner, 2026-11-20): its job is
      // left out - its output is there
      if St = 'done' then
      begin
        WindowLine(Format('Built already, so not queued: %s (%s)', [Job.Title, Job.Output]));
        Continue;
      end
      else if St = 'failed' then
        Job.State := jsFailed
      else if St = 'cancelled' then
        Job.State := jsCancelled
      else
        Job.State := jsWaiting;
      // the checks Add to queue makes: a file is not asked, so it says
      if SameFileName(ExpandFileName(Job.Output), ExpandFileName(Job.Book)) then
      begin
        WindowLine(Format('Left out: %s - its output is the book itself.', [Job.Title]));
        Continue;
      end;
      Dup := -1;
      for K := 0 to High(FJobs) do
        if SameFileName(ExpandFileName(FJobs[K].Output), ExpandFileName(Job.Output)) and
          ((FJobs[K].State = jsDone) = (Job.State = jsDone)) then
        begin
          Dup := K;
          Break;
        end;
      if Dup >= 0 then
      begin
        WindowLine(Format('Left out: %s - job %d of the queue writes %s already.', [Job.Title, Dup + 1,
          Job.Output]));
        Continue;
      end;
      if (Job.State <> jsDone) and FileExists(Job.Output) then
        WindowLine(Format('Note: %s is there already and will be replaced by job %d (%s) - remove the job to ' +
          'keep it.', [Job.Output, Length(FJobs) + 1, Job.Title]));
      FJobs := FJobs + [Job];
      Inc(Result);
    end;
  finally
    V.Free;
  end;
end;

procedure TfrmBuilder.btnJobLoadClick(Sender: TObject);
var
  D: TOpenDialog;
  N: Integer;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Build queues (*.json)|*.json|All files (*.*)|*.*';
    ForceDirectories(FQueueFolder);
    D.InitialDir := FQueueFolder;
    if not D.Execute then
      Exit;
    FQueueFolder := ExcludeTrailingPathDelimiter(ExtractFilePath(D.FileName));
    SaveSettings;
    FQueueFile := D.FileName;
    try
      N := LoadQueue(D.FileName);
      WindowLine(Format('%d job(s) added from %s', [N, D.FileName]));
    except
      on E: Exception do
        WindowLine('The queue file cannot be read: ' + E.Message);
    end;
  finally
    D.Free;
  end;
  ShowJobs;
  UpdateControls;
end;

procedure TfrmBuilder.btnJobSaveClick(Sender: TObject);
var
  D: TSaveDialog;
begin
  if Length(FJobs) = 0 then
  begin
    WindowLine('The queue is empty: nothing to save.');
    Exit;
  end;
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'Build queues (*.json)|*.json';
    D.DefaultExt := 'json';
    ForceDirectories(FQueueFolder);
    D.InitialDir := FQueueFolder;
    if FQueueFile <> '' then
      D.FileName := ExtractFileName(FQueueFile)
    else
      D.FileName := 'queue.json';
    if not D.Execute then
      Exit;
    FQueueFolder := ExcludeTrailingPathDelimiter(ExtractFilePath(D.FileName));
    SaveSettings;
    FQueueFile := D.FileName;
    try
      SaveQueue(D.FileName);
      WindowLine(Format('The queue (%d job(s)) was saved to %s', [Length(FJobs), D.FileName]));
    except
      on E: Exception do
        WindowLine('The queue was not saved: ' + E.Message);
    end;
  finally
    D.Free;
  end;
end;

procedure TfrmBuilder.lbJobsDblClick(Sender: TObject);
begin
  ShowJobInWindow(lbJobs.ItemIndex, True);
end;

procedure TfrmBuilder.lbJobsClick(Sender: TObject);
begin
  ShowJobInWindow(lbJobs.ItemIndex, False);
end;

procedure TfrmBuilder.ShowJobInWindow(AIndex: Integer; AAnnounce: Boolean);
var
  I, K: Integer;
  Job: TBuildJob;
begin
  I := AIndex;
  if (I < 0) or (I > High(FJobs)) then
    Exit;
  // the same job again (a double click after the click): nothing to do
  if (I = FEditJob) and not AAnnounce then
    Exit;
  Job := FJobs[I];
  // emptied first: ShowBook's "another book" note is for a book chosen
  lbAudio.Clear;
  ShowBook(Job.Book);
  lbAudio.Clear;
  for K := 0 to High(Job.Audio) do
    lbAudio.Items.Add(Job.Audio[K]);
  edOut.Text := Job.Output;
  // the job's own output, not one made from the book's name
  FAutoOut := '';
  if Job.Model <> '' then
  begin
    FModelPath := Job.Model;
    FillModels;
  end;
  cbDevice.ItemIndex := 0;
  for K := 0 to High(FDevices) do
    if SameText(FDevices[K].Name, Job.Device) then
      cbDevice.ItemIndex := K + 1;
  chkChapters.IsChecked := Job.Chapters;
  chkReuse.IsChecked := Job.Reuse;
  SelectLanguage(Job.Language);
  FCoverChoice := Job.Cover;
  FEditJob := I;
  WindowLine(Format('Job %d in the window: change it and Update job (or Add to queue for a new one), or ' +
      'Create.', [I + 1]));
  UpdateControls;
end;


procedure TfrmBuilder.chkReuseChange(Sender: TObject);
begin
  UpdateControls;
end;

procedure TfrmBuilder.btnCancelClick(Sender: TObject);
begin
  if FDownload <> nil then
  begin
    LogLine('Cancelling the download ...');
    FDownload.Cancel;
  end;
  if FCalib <> nil then
  begin
    LogLine(IfThen(FCalib.Diagnostics, 'Cancelling the diagnostics ...', 'Cancelling the calibration ...'));
    FCalib.Cancel;
  end;
  if FBuild <> nil then
  begin
    LogLine('Cancelling ...');
    FCancelled := True;
    FBuild.Cancel;
  end;
end;

procedure TfrmBuilder.BuildDone(Sender: TObject);
var
  Ok, Bench: Boolean;
  Taken: string;
  I: Integer;
begin
  // OnTerminate runs on the main thread after Execute: the queued log
  // lines have been delivered before it
  Taken := WhisperTimeToStr(MilliSecondsBetween(Now, FStarted) div 10);
  LogLine(Format('Finished after %s', [Taken]));
  // what the thread says, not what the progress bar shows
  Ok := (Sender as TBuildThread).Succeeded;
  Bench := (Sender as TBuildThread).Benchmark;
  // a benchmark is a whole book's build too: in the history, so the next
  // estimate of that model on that device is its own speed (owner,
  // 2026-11-22: "The estimates are sometimes way off")
  if Ok then
    RecordHistory((Sender as TBuildThread).Summary);
  if Ok and not Bench then
  begin
    LogLine('Open ' + FRunOut + ' in EpubReader.');
    FMadeBook := FRunBook;
    FMadeOut := FRunOut;
  end;
  // the job's place in the queue, and its figures for the report
  if (FJob >= 0) and (FJob <= High(FJobs)) then
  begin
    FJobs[FJob].Started := FStarted;
    FJobs[FJob].Seconds := MilliSecondsBetween(Now, FStarted) / 1000;
    FJobs[FJob].Summary := (Sender as TBuildThread).Summary;
    FJobs[FJob].OutputBytes := 0;
    if Ok and FileExists(FRunOut) then
      FJobs[FJob].OutputBytes := TFile.GetSize(FRunOut);
    if Ok then
    begin
      FJobs[FJob].State := jsDone;
      FJobs[FJob].Note := Taken;
    end
    else if FCancelled then
      FJobs[FJob].State := jsCancelled
    else
    begin
      FJobs[FJob].State := jsFailed;
      // why, in the list (the thread's last "FAILED: ..." line)
      FJobs[FJob].Note := 'see ' + ExtractFileName(FRunOut) + '.log';
      for I := FBuildLog.Count - 1 downto 0 do
        if StartsText('FAILED: ', FBuildLog[I]) then
        begin
          FJobs[FJob].Note := Copy(FBuildLog[I], 9, 100);
          Break;
        end;
    end;
  end;
  // this build's lines beside its output: an overnight queue leaves a
  // log per book
  FLogging := False;
  try
    FBuildLog.SaveToFile(FRunOut + '.log', TEncoding.UTF8);
    LogLine('Log kept: ' + FRunOut + '.log');
  except
    on E: Exception do
      LogLine('The log was not saved beside the output: ' + E.Message);
  end;
  FJob := -1;
  // the queue file follows the run: closed or crashed overnight, it still
  // says which books are done
  if FQueueRunning and (FQueueFile <> '') then
    try
      SaveQueue(FQueueFile);
    except
      on E: Exception do
        LogLine('The queue file was not updated: ' + E.Message);
    end;
  // FreeOnTerminate: the thread frees itself once this handler returns
  FBuild := nil;
  tmStatus.Enabled := False;
  ShowStatus;
  ShowJobs;
  // the queue goes on (from a timer: this thread object is still being
  // finished); Cancel stops the whole run
  if FQueueRunning then
  begin
    if FCancelled then
    begin
      FQueueRunning := False;
      LogLine('Queue stopped (Cancel). Run queue builds the jobs not done.');
    end
    else
      tmQueue.Enabled := True;
  end;
  UpdateControls;
  // a benchmark: its score and the question about its book
  if Bench then
    BenchmarkDone((Sender as TBuildThread).Summary, Ok);
  // a build on its own, or a queue stopped: the menu again (a queue that
  // goes on shows it when it has finished - RunNextJob); not over a
  // question (PadBackToMenu), nor between two benchmarks of Run all
  if Length(FBenchQueue) = 0 then
    PadBackToMenu(False);
end;

procedure TfrmBuilder.ShowStatus;
var
  Taken, Since, Left: Int64;
  S: string;
  Done, Remaining, Own, PerSecond, W: Double;
begin
  Taken := MilliSecondsBetween(Now, FStarted);
  S := Format('%s taken', [WhisperTimeToStr((Taken div 1000) * 100)]);
  Left := -1;
  if (FBuild <> nil) and (FPercent < 100) then
  begin
    if FPercent >= 90 then
    begin
      // aligning and writing: what earlier builds here took for that
      // much audio
      if (FExpAfter > 0) and (FAudioTotal > 0) and (FAfterFrom <> 0) then
        Left := Max(Int64(0), Round(FExpAfter * FAudioTotal * 1000) - MilliSecondsBetween(Now, FAfterFrom));
    end
    else if FAudioTotal > 0 then
    begin
      // the transcription's own rate, s per s of audio, counted from its
      // first progress (the book, the audio and the model's loading do
      // not repeat - counted from the start the first figures were hours
      // too high: owner, Night Watch on Linux)
      Own := 0;
      Done := 0;
      Since := 0;
      if FRatePercent >= 0 then
      begin
        Since := MilliSecondsBetween(Now, FRateFrom);
        Done := AudioDoneAt(FPercent) - FRateAudio;
        if (Since >= 30000) and (Done > 0) then
          Own := Since / 1000 / Done;
      end;
      PerSecond := 0;
      if FExpSpeed > 0 then
      begin
        // the expectation, giving way to the build's own rate as audio is
        // done (owner, M4 / base.en: first "about an hour", then 18 min)
        W := 0;
        if Own > 0 then
          W := Done / (Done + FExpPrior);
        PerSecond := W * Own + (1 - W) / FExpSpeed;
      end
      else if (Own > 0) and (Since >= 60000) and (FPercent - FRatePercent >= 1) then
        PerSecond := Own;
      if Own > 0 then
        FSpeedNow := 1 / Own;
      if PerSecond > 0 then
      begin
        Remaining := FAudioTotal - AudioDoneAt(Max(FPercent, 5.0));
        Left := Round((Remaining * PerSecond + FExpAfter * FAudioTotal) * 1000);
      end;
    end;
    if Left >= 0 then
      S := S + Format(', about %s left', [WhisperTimeToStr((Left div 1000) * 100)])
    else if FPercent < 90 then
      S := S + ', estimating the time left ...';
  end;
  FTimeText := S;
  if (FBuild <> nil) and (FJob >= 0) then
    S := Format('Job %d of %d: ', [FJob + 1, Length(FJobs)]) + S;
  lblStatus.Text := S + ' - ' + FStatusText;
  UpdatePanel;
  UpdateLinkStatus;
end;

procedure TfrmBuilder.UpdatePanel;
var
  Waiting, I: Integer;
begin
  if layProgress = nil then
    Exit;
  if FBuild <> nil then
  begin
    lblPTitle.Text := FBuildTitle;
    if FJob >= 0 then
      lblPJob.Text := Format('Job %d of %d in the queue', [FJob + 1, Length(FJobs)])
    else
      lblPJob.Text := 'The book in the window';
    lblPTime.Text := Format('%d %%  -  %s', [Round(FPercent), FTimeText]);
    if FSpeedNow > 0 then
      lblPSpeed.Text := Format('%.1fx real time so far', [FSpeedNow])
    else
      lblPSpeed.Text := '';
  end
  else if FCalib <> nil then
  begin
    lblPTitle.Text := IfThen(FCalib.Diagnostics, 'Diagnostics', 'Calibrating');
    lblPJob.Text := '';
    lblPTime.Text := FStatusText;
    lblPSpeed.Text := '';
  end
  else if FDownload <> nil then
  begin
    lblPTitle.Text := 'Downloading';
    lblPJob.Text := '';
    lblPTime.Text := lblStatus.Text;
    lblPSpeed.Text := '';
  end
  else
  begin
    lblPTitle.Text := 'Idle';
    Waiting := 0;
    for I := 0 to High(FJobs) do
      if FJobs[I].State = jsWaiting then
        Inc(Waiting);
    if Waiting > 0 then
      lblPJob.Text := Format('%d job(s) waiting - Run queue', [Waiting])
    else
      lblPJob.Text := '';
    lblPTime.Text := FLastResult;
    lblPSpeed.Text := '';
  end;
end;

procedure TfrmBuilder.SetLogVisible(AOn: Boolean);
begin
  mmLog.Visible := AOn;
  layProgress.Visible := not AOn;
  if AOn then
    mmLog.GoToTextEnd;
end;

procedure TfrmBuilder.miLogClick(Sender: TObject);
var
  Ini: TMemIniFile;
begin
  SetLogVisible(not mmLog.Visible);
  try
    ForceDirectories(ExtractFilePath(SettingsFile));
    Ini := TMemIniFile.Create(SettingsFile, TEncoding.UTF8);
    try
      Ini.WriteBool('View', 'Log', mmLog.Visible);
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
  except
    on E: Exception do
      DebugLog('settings: ' + E.Message);
  end;
end;

procedure TfrmBuilder.tmStatusTimer(Sender: TObject);
begin
  ShowStatus;
end;

procedure TfrmBuilder.FormActivated(Sender: TObject);
begin
  FRedraw.Activated;
end;

procedure TfrmBuilder.FormDeactivated(Sender: TObject);
begin
  FRedraw.Deactivated;
end;

procedure TfrmBuilder.BuildMenu;

  { A menu item under AParent. }
  function Item(AParent: TFmxObject; const AText: string; AOnClick: TNotifyEvent): TMenuItem;
  begin
    Result := TMenuItem.Create(Self);
    Result.Parent := AParent;
    Result.Text := AText;
    Result.OnClick := AOnClick;
  end;

var
  M: TMenuItem;
  Bar: TFmxObject;
  I: Integer;
begin
  {$IF Defined(LINUX) and not Defined(ANDROID)}
  mnuBar := TMenuBar.Create(Self);
  mnuBar.Parent := Self;
  mnuBar.Position.Y := -1;   // above everything
  mnuBar.Align := TAlignLayout.Top;
  Bar := mnuBar;
  {$ELSE}
  mnuMain := TMainMenu.Create(Self);
  // Big Picture: no menu bar - the menu is not put on the form (the
  // Benchmark items are still made: RefreshBenchmarks keeps their state);
  // the pad's menu has the commands (as EpubReader)
  if not SteamBigPicture then
    mnuMain.Parent := Self;
  Bar := mnuMain;
  {$ENDIF}
  M := Item(Bar, '&File', nil);
  // owner, 2026-11-22: the View and Tools menus are gone - File > Settings
  // opens the menu's Settings page, which has what they had
  Item(M, '&Settings...', miSettingsClick);
  Item(M, '-', nil);
  Item(M, 'E&xit', miExitClick);
  // owner, 2026-11-22: a menu of its own, five items with the time each
  // takes (RefreshBenchmarks writes their text)
  M := Item(Bar, '&Benchmark', nil);
  // Steam's leaderboards of the four, at the top (owner, 2026-11-23)
  if SteamRunning then
  begin
    miBoards := Item(M, '&Leaderboards...', miBoardsClick);
    Item(M, '-', nil);
  end;
  for I := 0 to High(miBench) do
  begin
    miBench[I] := Item(M, BenchmarkText(I), miBenchmarkClick);
    miBench[I].Tag := I;
    if I = 0 then
      Item(M, '-', nil);
  end;
  // a menu made in code reaches the window (Windows' / macOS' own menu
  // bar) only when it is recreated (EpubReader: without it, no menu)
  if (mnuMain <> nil) and (mnuMain.Parent <> nil) then
    mnuMain.RecreateOSMenu;
end;

procedure TfrmBuilder.miExitClick(Sender: TObject);
begin
  Close;
end;

function TfrmBuilder.DefaultDeviceItem: string;
var
  D: TWhisperDevice;
begin
  if GDefaultDevice <> '' then
    Result := Format('Default (%s - ROCm left out: not for this GPU)', [GDefaultDevice])
  else if BuilderFindDevice('', D) then
    Result := Format('Default (whisper.cpp chooses: %s - the first GPU, not always the fastest)', [D.Name])
  else
    Result := 'Default (whisper.cpp chooses)';
end;

const
  { The pad's buttons, in the order of BP_ACTIONS - the reader's action set
    "Reader" (uReaderInput: one manifest per Steam app, both programs). }
  BP_UP = 0;
  { Down. }
  BP_DOWN = 1;
  { Left: a choice's value back. }
  BP_LEFT = 2;
  { Right: a choice's value on. }
  BP_RIGHT = 3;
  { A ("Play" in the reader): choose. }
  BP_CHOOSE = 4;
  { B: back. }
  BP_BACK = 5;
  { Start: the menu, or close it. }
  BP_MENU = 6;
  { View / Select ("Library" in the reader): the queue. }
  BP_QUEUE = 7;
  { X ("Again" in the reader), the key H: the benchmark results shown or
    hidden (owner, 2026-11-22). }
  BP_TOGGLE = 8;
  { The actions' names in the manifest. }
  BP_ACTIONS: array[0..8] of string = ('Up', 'Down', 'Left', 'Right', 'Play', 'Back', 'Menu', 'Library', 'Again');
  { The lists of the pad's menu. }
  BPM_HOME = 0;
  { The books folder's EPUB files. }
  BPM_BOOKS = 1;
  { Audio for the book. }
  BPM_AUDIO = 2;
  { The queue. }
  BPM_QUEUE = 3;
  { One job. }
  BPM_JOB = 4;
  { A question (Ask). }
  BPM_ASK = 5;
  { The models (the Model list's: choosing one not here asks to download
    it - turning the list with left / right asked at every step, so only
    the first model could be reached; Steam Deck, 2026-11-20). }
  BPM_MODELS = 6;
  { The queues folder's queues. }
  BPM_QUEUES = 7;
  { The controls and their bindings (PadControls). }
  BPM_CONTROLS = 8;
  { The Benchmark list (PadBenchmarks). }
  BPM_BENCH = 9;
  { The Leaderboards list (PadBoards). }
  BPM_BOARDS = 10;
  { One leaderboard (PadBoard). }
  BPM_BOARD = 11;
  { The home list's rows. }
  BPC_BOOK = 0;
  { The audio. }
  BPC_AUDIO = 1;
  { The model (left / right). }
  BPC_MODEL = 2;
  { The device (left / right). }
  BPC_DEVICE = 3;
  { The language (left / right). }
  BPC_LANGUAGE = 4;
  { Power (left / right). }
  BPC_POWER = 5;
  { Chapters of a file are parts (left / right). }
  BPC_CHAPTERS = 6;
  { The output (shown). }
  BPC_OUTPUT = 7;
  { Create. }
  BPC_CREATE = 8;
  { Add to queue. }
  BPC_ADD = 9;
  { Update job. }
  BPC_UPDATE = 10;
  { The queue's list. }
  BPC_QUEUE = 11;
  { Cancel. }
  BPC_CANCEL = 12;
  { Calibrate (this model). }
  BPC_CALIBRATE = 13;
  { Exit. }
  BPC_EXIT = 14;
  { Run queue (on the home list too: two lists down was not obvious -
    owner, 2026-11-20). }
  BPC_RUN = 15;
  { The cover (thumbnails to choose from). }
  BPC_COVER = 16;
  { Diagnostics (this model). }
  BPC_DIAGNOSE = 17;
  { The menu's colours: dark or light. }
  BPC_DARK = 18;
  { Calibrate every model in the models' folder. }
  BPC_CALIBRATE_ALL = 19;
  { Diagnostics on every model in the models' folder. }
  BPC_DIAGNOSE_ALL = 20;
  { Expert mode: every model in the model list. }
  BPC_EXPERT = 21;
  { The controls and their bindings. }
  BPC_CONTROLS = 22;
  { The home list's first page: its Settings page. }
  BPC_SETTINGS = 23;
  { The Settings page: back to the first page. }
  BPC_SETTINGS_BACK = 24;
  { Settings, the desktop: the log or the progress panel. }
  BPC_LOG = 25;
  { Settings, the desktop: the books folder. }
  BPC_FOLDER_BOOKS = 26;
  { Settings, the desktop: the audio folder. }
  BPC_FOLDER_AUDIO = 27;
  { Settings, the desktop: the output folder. }
  BPC_FOLDER_OUTPUT = 28;
  { Settings: what the calibration keeps, into the log. }
  BPC_RESULTS = 29;
  { Settings, the desktop: the build history's table. }
  BPC_HISTORY = 30;
  { Settings: the AMD ROCm DLC, when it applies (CheckRocmDlc). }
  BPC_ROCM = 31;
  { Benchmark: its list (faded without base and turbo). }
  BPC_BENCH = 32;
  { Settings: the lowest acceptable speed (left / right). }
  BPC_LOWEST = 33;
  { Settings, the desktop: use a saved transcript, this build only. }
  BPC_REUSE = 34;
  { Settings, the desktop, Windows: the window's graphics preference. }
  BPC_GPU = 35;
  { Settings, the desktop, not Steam: the models folder. }
  BPC_FOLDER_MODELS = 36;
  { Settings, Steam running: benchmark scores go to the leaderboards. }
  BPC_BOARD = 37;
  { The rows of the home list's Settings page (owner, 2026-11-22); the
    others are its first page. PadHome shows the page of the row asked
    for. }
  BP_SETTINGS_ROWS = [BPC_MODEL, BPC_CALIBRATE, BPC_CALIBRATE_ALL, BPC_DIAGNOSE, BPC_DIAGNOSE_ALL, BPC_DEVICE,
    BPC_LANGUAGE, BPC_POWER, BPC_CHAPTERS, BPC_DARK, BPC_EXPERT, BPC_OUTPUT, BPC_SETTINGS_BACK, BPC_LOG,
    BPC_FOLDER_BOOKS, BPC_FOLDER_AUDIO, BPC_FOLDER_OUTPUT, BPC_RESULTS, BPC_HISTORY, BPC_ROCM, BPC_LOWEST,
    BPC_REUSE, BPC_GPU, BPC_FOLDER_MODELS, BPC_BOARD];
  { The highest BPC_* in BP_SETTINGS_ROWS (a set holds 0 .. 255: the
    command is checked against this before "in"). }
  BPC_SETTINGS_TOP = BPC_BOARD;
  { The pad's menu in dark colours: its box, its text, the selected row
    (EpubReader's dark menu, uMain.PadMenuColors, with its panel text). }
  PAD_DARK_BACK = $FF23262E;
  { Text of the dark menu. }
  PAD_DARK_TEXT = $FFE0E0E0;
  { Selected row of the dark menu. }
  PAD_DARK_ROW = $FF34405A;
  { The window behind the dark menu: a shade darker than its box. }
  PAD_DARK_WINDOW = $FF1A1C22;
  { Selected row of the light menu (TPadMenu's own; its box is white, its
    text black). }
  PAD_LIGHT_ROW = $FFD6E4F5;
  { Rows of the other lists that are not an entry. }
  PADROW_BACK = -1;
  { Every audio candidate. }
  PADROW_BROWSE = -2;
  { The audio list as it is. }
  PADROW_KEEP = -3;
  { Run queue. }
  PADROW_RUN = -4;
  { Text only. }
  PADROW_NONE = -5;
  { The job into the window. }
  PADROW_SHOW = -6;
  { The job up. }
  PADROW_UP = -7;
  { The job down. }
  PADROW_DOWN = -8;
  { The job removed. }
  PADROW_REMOVE = -9;
  { Save queue. }
  PADROW_SAVEQ = -10;
  { Load a queue. }
  PADROW_LOADQ = -11;
  { The Benchmark list: Leaderboards. }
  PADROW_BOARDS = -12;
  { The model list's first row: Download every model. }
  PADROW_DOWNLOAD_ALL = -12;
  { Audio files the folder lists (as Add files...). }
  BP_AUDIO_EXTS: array[0..8] of string = ('.m4b', '.m4a', '.aax', '.mp3', '.wav', '.flac', '.ogg', '.opus', '.aac');
  { Words a title match leaves out. }
  BP_SMALL_WORDS: array[0..7] of string = ('the', 'a', 'an', 'of', 'and', 'by', 'in', 'to');
  { How many matches the audio list offers first. }
  BP_AUDIO_FIRST = 8;

{ AText's words, lower case, without the small ones. }
function PadWords(const AText: string): TArray<string>;
var
  W: string;
  C: Char;
  Words: TArray<string>;

  procedure Flush;
  begin
    if (W <> '') and (IndexText(W, BP_SMALL_WORDS) < 0) and (IndexText(W, Words) < 0) then
      Words := Words + [W];
    W := '';
  end;

begin
  Words := nil;
  W := '';
  for C in AnsiLowerCase(AText) do
    if C.IsLetterOrDigit then
      W := W + C
    else
      Flush;
  Flush;
  Result := Words;
end;

{ How much of AKey's words AName has: the share of them (0 .. 1), a little
  more for a name with fewer other words. }
function PadScore(const AKey, AName: TArray<string>): Double;
var
  W: string;
  N: Integer;
begin
  Result := 0;
  if (Length(AKey) = 0) or (Length(AName) = 0) then
    Exit;
  N := 0;
  for W in AKey do
    if IndexText(W, AName) >= 0 then
      Inc(N);
  Result := N / Length(AKey) + 0.01 * N / Length(AName);
end;

{ The text up to ' - ' or ' (' - a combo box item's short form. }
function PadShort(const AText: string): string;
var
  P: Integer;
begin
  Result := AText;
  P := Pos(' - ', Result);
  if P > 0 then
    SetLength(Result, P - 1);
  P := Pos(' (', Result);
  if P > 1 then
    SetLength(Result, P - 1);
end;

procedure TfrmBuilder.Ask(const AText: string; AType: TMsgDlgType; const AButtons: TMsgDlgButtons;
  ADefault: TMsgDlgBtn; const AResult: TInputCloseDialogProc);
const
  TITLES: array[TMsgDlgType] of string = ('Warning', 'Error', 'Note', 'Question', 'EpubBuilder');
var
  Items: TArray<TPadMenuItem>;
  Sel: Integer;

  procedure Answer(AButton: TMsgDlgBtn; const ALabel: string; AResultValue: TModalResult);
  begin
    if not (AButton in AButtons) then
      Exit;
    if AButton = ADefault then
      Sel := Length(Items);
    Items := Items + [TPadMenu.Item(ALabel)];
    FPadCmds := FPadCmds + [PADROW_NONE];
    FAskResults := FAskResults + [AResultValue];
  end;

begin
  if not FBigPicture or (FPadMenu = nil) then
  begin
    TDialogService.MessageDialog(AText, AType, AButtons, ADefault, 0, AResult);
    Exit;
  end;
  DebugLog('pad question: ' + AText.Replace(sLineBreak, ' '));
  // the pairing's box, if it showed, is replaced (its bar stays)
  FPairPad := False;
  Items := nil;
  FPadCmds := nil;
  FAskResults := nil;
  Sel := -1;
  // the text over the box's whole width, the answers below it (one row
  // per line cut every line short)
  Answer(TMsgDlgBtn.mbYes, 'Yes', mrYes);
  Answer(TMsgDlgBtn.mbNo, 'No', mrNo);
  Answer(TMsgDlgBtn.mbOK, 'OK', mrOk);
  Answer(TMsgDlgBtn.mbCancel, 'Cancel', mrCancel);
  if Sel < 0 then
    Sel := Length(Items) - 1;
  if TMsgDlgBtn.mbNo in AButtons then
    FAskCancel := mrNo
  else if TMsgDlgBtn.mbCancel in AButtons then
    FAskCancel := mrCancel
  else
    FAskCancel := mrOk;
  FAskProc := AResult;
  FPadMode := BPM_ASK;
  // the buttons as the pad in hand shows them, or the keys (owner's rule)
  FPadMenu.ShowText(TITLES[AType], AText, Items, Sel, PadFootOf([BP_CHOOSE, BP_BACK], ['answer',
    IfThen(FAskCancel = mrNo, 'no', 'cancel')]));
  RefreshFoot;
end;

procedure TfrmBuilder.Tell(const AText: string);
begin
  WindowLine(AText);
  if FBigPicture and (FPadMenu <> nil) then
    Ask(AText, TMsgDlgType.mtInformation, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, nil);
end;

procedure TfrmBuilder.PadAnswer(AIndex: Integer);
var
  P: TInputCloseDialogProc;
  R: TModalResult;
begin
  if AIndex < 0 then
    R := FAskCancel
  else if (AIndex <= High(FAskResults)) and (FAskResults[AIndex] <> mrNone) then
    R := FAskResults[AIndex]
  else
    Exit;   // a line of the question
  P := FAskProc;
  FAskProc := nil;
  FAskResults := nil;
  FPadMode := BPM_HOME;
  FPadMenu.Hide;
  if Assigned(P) then
    P(R);
  // the desktop's results: the menu closes with them
  if FAskThenClose then
  begin
    FAskThenClose := False;
    if FPadMode <> BPM_ASK then
      Exit;
  end;
  // the answer may ask again (or start a build: the window shows it)
  if (FPadMode <> BPM_ASK) and (FBuild = nil) and (FCalib = nil) and (FDownload = nil) then
  begin
    if FPadToOutput then
      PadHome(BPC_OUTPUT)
    else if FPadToModel then
      PadHome(BPC_MODEL)
    else
      PadHome(BPC_CREATE);
  end;
  FPadToModel := False;
  FPadToOutput := False;
end;

procedure TfrmBuilder.ShowPairing(const AClient, ACode: string);
var
  Lay: TLayout;
  B: TButton;
  Text: string;
begin
  if pnlPair = nil then
  begin
    pnlPair := TPanel.Create(Self);
    pnlPair.Parent := Self;
    pnlPair.Align := TAlignLayout.Top;
    pnlPair.Position.Y := 0;
    pnlPair.Height := 76;
    pnlPair.Padding.Rect := RectF(GAP, GAP div 2, GAP, GAP div 2);
    B := TButton.Create(Self);
    B.Parent := pnlPair;
    B.Align := TAlignLayout.Right;
    B.Width := 170;
    B.Margins.Rect := RectF(GAP, 14, 0, 14);
    B.Text := 'Refuse connection';
    B.OnClick := btnRefusePairClick;
    lblPairCode := TLabel.Create(Self);
    lblPairCode.Parent := pnlPair;
    lblPairCode.Align := TAlignLayout.Right;
    lblPairCode.Width := 190;
    lblPairCode.StyledSettings := lblPairCode.StyledSettings - [TStyledSetting.Size, TStyledSetting.Style];
    lblPairCode.TextSettings.Font.Size := 34;
    lblPairCode.TextSettings.Font.Style := [TFontStyle.fsBold];
    lblPairCode.WordWrap := False;
    Lay := TLayout.Create(Self);
    Lay.Parent := pnlPair;
    Lay.Align := TAlignLayout.Client;
    lblPairText := TLabel.Create(Self);
    lblPairText.Parent := Lay;
    lblPairText.Align := TAlignLayout.Top;
    lblPairText.Height := 40;
    lblPairText.StyledSettings := lblPairText.StyledSettings - [TStyledSetting.Style];
    lblPairText.TextSettings.Font.Style := [TFontStyle.fsBold];
    lblPairText.WordWrap := True;
    lblPairTime := TLabel.Create(Self);
    lblPairTime.Parent := Lay;
    lblPairTime.Align := TAlignLayout.Top;
    lblPairTime.Position.Y := 100;
    lblPairTime.Height := 24;
    tmPair := TTimer.Create(Self);
    tmPair.Interval := 1000;
    tmPair.Enabled := False;
    tmPair.OnTimer := tmPairTimer;
  end;
  FPairWho := AClient;
  FPairUntil := IncMinute(Now, LINK_PAIR_MINUTES);
  Text := Format('%s wants to connect to this EpubBuilder. Type this code there:', [AClient]);
  lblPairText.Text := Text;
  lblPairCode.Text := Copy(ACode, 1, 3) + ' ' + Copy(ACode, 4, MaxInt);
  pnlPair.Visible := True;
  tmPair.Enabled := True;
  tmPairTimer(nil);
  // Big Picture: the pad's box too, unless another question shows there
  if FBigPicture and (FPadMenu <> nil) and ((FPadMode <> BPM_ASK) or FPairPad) then
  begin
    FPadCmds := [PADROW_NONE];
    FAskResults := [mrCancel];
    FAskCancel := mrCancel;
    FAskProc :=
      procedure(const AResult: TModalResult)
      begin
        RefusePairing;
      end;
    FPadMode := BPM_ASK;
    FPairPad := True;
    FPadMenu.ShowText('Connect', Text + sLineBreak + sLineBreak + lblPairCode.Text + sLineBreak + sLineBreak +
      Format('(It works for %d minutes; this box closes by itself once it is typed.)', [LINK_PAIR_MINUTES]),
      [TPadMenu.Item('Refuse connection')], 0, PadFootOf([BP_CHOOSE, BP_BACK], ['', 'refuse']));
    RefreshFoot;
  end;
end;

procedure TfrmBuilder.HidePairing(const AWhy: string);
begin
  if tmPair <> nil then
    tmPair.Enabled := False;
  if pnlPair <> nil then
    pnlPair.Visible := False;
  if FPairPad then
  begin
    FPairPad := False;
    // still the pairing's box (not answered, not replaced): closed
    if (FPadMode = BPM_ASK) and (FPadMenu <> nil) then
    begin
      FAskProc := nil;
      FAskResults := nil;
      FPadMode := BPM_HOME;
      FPadMenu.Hide;
      if (FBuild = nil) and (FCalib = nil) and (FDownload = nil) then
        PadHome(BPC_CREATE);
    end;
  end;
  if AWhy <> '' then
    WindowLine(AWhy);
end;

procedure TfrmBuilder.RefusePairing;
begin
  if FLink <> nil then
    FLink.RefusePair;
  HidePairing(Format('Refused: %s may not connect (it can ask again).', [FPairWho]));
end;

procedure TfrmBuilder.btnRefusePairClick(Sender: TObject);
begin
  RefusePairing;
end;

procedure TfrmBuilder.tmPairTimer(Sender: TObject);
var
  Left: Int64;
begin
  if Now >= FPairUntil then
  begin
    // the link stops taking the code by itself
    HidePairing(Format('The pairing code for %s ran out.', [FPairWho]));
    Exit;
  end;
  Left := SecondsBetween(FPairUntil, Now);
  lblPairTime.Text := Format('It works for %d:%.2d more.', [Left div 60, Left mod 60]);
end;

procedure TfrmBuilder.BigPictureWindow;
const
  { The log's text in Big Picture (Steam asks for at least 24 on a Deck;
    a TV is read from the sofa). }
  LOG_SIZE_BIG = 24;
var
  I: Integer;
begin
  layTop.Visible := False;
  layQueue.Visible := False;
  splQueue.Visible := False;
  layBook.Visible := False;
  splSides.Visible := False;
  layAudio.Visible := False;
  // the bottom part fills the window; of it only the log
  layBottom.Align := TAlignLayout.Client;
  for I := 0 to layBottom.ControlsCount - 1 do
    layBottom.Controls[I].Visible := False;
  SetLogVisible(True);
  mmLog.StyledSettings := mmLog.StyledSettings - [TStyledSetting.Size];
  mmLog.TextSettings.Font.Size := LOG_SIZE_BIG;
  mmLog.Margins.Rect := RectF(GAP * 3, GAP * 3, GAP * 3, GAP * 3);
  mmLog.GoToTextEnd;
  DebugLog(Format('Big Picture: the window shows the log only (text %d)', [LOG_SIZE_BIG]));
  // dark unless turned off (the style may not be applied yet: tmDark
  // looks again)
  ApplyDarkWindow;
end;

procedure TfrmBuilder.StartPad;
var
  I: Integer;
  Folder, Manifest: string;
  Any: Boolean;
begin
  FBigPicture := SteamBigPicture;
  // the calibration's introduction laid out again when the window grows
  OnResize := FormResized;
  FPadMenu := TPadMenu.Create(Self, Self);
  FPadMenu.OnChoose := PadChoose;
  FPadMenu.OnClose := PadClosed;
  FPadMenu.OnGesture := PadMenuGesture;
  FPadMenu.OnPointer := PadPointer;
  PadColors;
  // the dark window, with or without Steam, in Big Picture or not
  tmDark := TTimer.Create(Self);
  tmDark.Interval := 500;
  tmDark.OnTimer := tmDarkTimer;
  tmDark.Enabled := True;
  if FBigPicture then
    FPadMenu.FontSize := 30
  else
    FPadMenu.FontSize := 20;
  // Big Picture: the pad's menu has the menu bar's commands (Linux's drawn
  // bar hidden; Windows' and the Mac's are the system's - left)
  {$IF Defined(LINUX) and not Defined(ANDROID)}
  if FBigPicture and (mnuBar <> nil) then
    mnuBar.Visible := False;
  {$ENDIF}
  if FBigPicture then
    BigPictureWindow;
  FPad := TSteamPad.Create('Reader', BP_ACTIONS, '');
  for I := BP_UP to BP_RIGHT do
    FPad.SetRepeat(I, True);
  if not SteamRunning then
  begin
    DebugLog(FPad.Start(''));
    Exit;
  end;
  // the reader's manifest (the same Steam app): written beside the program
  // as the reader does (on the Mac beside the .app), else beside the
  // settings
  Manifest := '';
  Folder := TPath.Combine(ExtractFileDir(ModelsDefaultFolder(True, '')), 'steaminput');
  try
    Manifest := ReaderInputWrite(Folder);
  except
    on E: Exception do
      DebugLog('pad: ' + Folder + ' not writable (' + E.Message + '): the settings'' folder instead');
  end;
  if Manifest = '' then
  begin
    Folder := ExtractFilePath(SettingsFile) + 'steaminput';
    try
      Manifest := ReaderInputWrite(Folder);
    except
      on E: Exception do
        DebugLog('pad: the action manifest was not written to ' + Folder + ': ' + E.Message);
    end;
  end;
  if Manifest <> '' then
    DebugLog(FPad.Start(Manifest) + Format(' (the reader''s manifest, layout revision %d.%d)',
      [READER_INPUT_MAJOR, READER_INPUT_REVISION]));
  if not FPad.Started then
    Exit;
  // macOS, Big Picture: full screen first looked at 1.5 s from now
  FFullTick := TThread.GetTickCount64;
  tmPad := TTimer.Create(Self);
  tmPad.Interval := 16;
  tmPad.OnTimer := tmPadTimer;
  tmPad.Enabled := True;
  if FBigPicture then
  begin
    LogLine('Big Picture: the pad drives EpubBuilder - Start (Menu) opens its menu, View (Select) the queue.');
    // no model here yet (a new machine): the models first - nothing can be
    // built or calibrated without one (owner, Steam Deck 2026-11-20)
    Any := False;
    for I := 0 to FModelItems.Count - 1 do
      if (FModelItems[I] <> '') and FileExists(FModelItems[I]) then
        Any := True;
    // a calibration about to start (CheckCalibrationAtStart, AfterShow):
    // it is the first thing seen, the menu comes after it
    if Any and CalibrationDueAtStart then
    else if Any then
      PadHome(BPC_BOOK)
    else
      PadModels;
  end;
end;

const
  { macOS: full screen asked for while the window is being made does not
    take (the Mac, 2026-11-21: Big Picture's view in an ordinary window;
    2026-11-22: still so after FMX's FullScreen asked for again), so it is
    asked for through Cocoa once the window is there (uMacWindow). }
  PAD_FULL_AGAIN = {$IFDEF MACOS} True {$ELSE} False {$ENDIF};
  { Looked at this often, a second and a half apart: the Mac's full screen
    the first times, the window over the whole screen the last time; then
    left alone (the user may have left full screen on purpose). }
  PAD_FULL_TRIES = 4;
  { The calibration's introduction shows when the window's size has not
    changed for this long, ms (IntroWhenSettled). }
  INTRO_SETTLE_MS = 600;

procedure TfrmBuilder.tmPadTimer(Sender: TObject);
var
  Presses: TSteamPadPresses;
  Y: Single;
  I: Integer;
  Note: string;
  T: UInt64;
begin
  try
    FPad.Poll(Presses, Y);
    Note := FPad.TakeNote;
    if Note <> '' then
      DebugLog(Note);
    for I := 0 to High(Presses) do
      if Presses[I] then
      begin
        // the first press for a minute: the screen may be black
        FRedraw.UserInput;
        SetPadKeys(False);
        PadPress(I);
      end;
    // the build's progress at the menu's foot, twice a second
    T := TThread.GetTickCount64;
    if FPadMenu.Showing and (FPadMode in [BPM_HOME, BPM_QUEUE]) and (T - FPadFootTick > 500) then
    begin
      FPadFootTick := T;
      if (FBuild <> nil) or (FCalib <> nil) or (FDownload <> nil) then
        FPadMenu.SetFoot(lblStatus.Text)
      else
      begin
        PadFoot;
        RefreshFoot;
      end;
    end;
    // macOS: the window made full screen once it is there - its real
    // state read from Cocoa (FMX's FullScreen can read True in a window)
    if PAD_FULL_AGAIN and FBigPicture and (FFullTries < PAD_FULL_TRIES) and (T - FFullTick > 1500) then
    begin
      FFullTick := T;
      if MacIsFullScreen(Self) then
      begin
        if FFullTries > 0 then
          DebugLog(Format('Big Picture: the window is full screen (after %d of %d)', [FFullTries,
            PAD_FULL_TRIES]));
        FFullTries := PAD_FULL_TRIES;
      end
      else
      begin
        Inc(FFullTries);
        if FFullTries < PAD_FULL_TRIES then
          DebugLog(Format('Big Picture: the window is not full screen (%d of %d) - %s', [FFullTries,
            PAD_FULL_TRIES, MacMakeFullScreen(Self)]))
        else
          DebugLog(Format('Big Picture: macOS did not make the window full screen (%d of %d) - %s',
            [FFullTries, PAD_FULL_TRIES, MacCoverScreen(Self)]));
      end;
    end;
  except
    on E: Exception do
      DebugLog('pad: ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TfrmBuilder.PadPress(AButton: Integer);
begin
  if not (AButton in [BP_UP, BP_DOWN, BP_LEFT, BP_RIGHT]) then
    DebugLog('pad: ' + BP_ACTIONS[AButton]);
  // the calibration's results: any button goes on
  if FCalResults then
  begin
    CalResultsButton(nil);
    Exit;
  end;
  // the benchmark results: X / H hides or shows them; hidden, any other
  // button shows them again
  if FBenchResults and ((AButton = BP_TOGGLE) or FBenchHidden) then
  begin
    BenchToggleResults;
    Exit;
  end;
  if AButton = BP_TOGGLE then
    Exit;
  // a benchmark running: the pad and the keys do nothing (owner,
  // 2026-11-23: "pressing [A] brings up the menu - this shouldn't
  // happen. The pad/keys should not have any effect mid-benchmark") -
  // except to answer a question it asks
  if BenchRunning and not (FPadMenu.Showing and (FPadMode = BPM_ASK)) then
    Exit;
  // the cover chooser over everything: the pad moves its frame
  if (FCoverPick <> nil) and FCoverPick.Showing then
  begin
    case AButton of
      BP_UP, BP_LEFT: FCoverPick.Move(-1);
      BP_DOWN, BP_RIGHT: FCoverPick.Move(1);
      BP_CHOOSE: FCoverPick.Choose;
      BP_BACK, BP_MENU:
        begin
          FCoverPick.Hide;
          PadHome(BPC_COVER);
        end;
    end;
    Exit;
  end;
  if not FPadMenu.Showing then
  begin
    case AButton of
      BP_MENU, BP_CHOOSE: PadHome(BPC_BOOK);
      BP_QUEUE: PadQueue(-1);
    end;
    Exit;
  end;
  case AButton of
    BP_UP: FPadMenu.Move(-1);
    BP_DOWN: FPadMenu.Move(1);
    BP_LEFT: PadStep(-1);
    BP_RIGHT: PadStep(1);
    BP_CHOOSE: PadChoose(FPadMenu, FPadMenu.Selected);
    BP_BACK: PadBack;
    BP_MENU:
      if FPadMode = BPM_ASK then
        PadAnswer(-1)
      else
        FPadMenu.Hide;
    BP_QUEUE:
      if FPadMode <> BPM_ASK then
        PadQueue(-1);
  end;
end;

const
  { The lists' foot when nothing runs: the buttons and what they do (a
    button without words joins the next: "<left> <right> change"). }
  BP_FOOT_BUTTONS: array[0..5] of Integer = (BP_CHOOSE, BP_BACK, BP_LEFT, BP_RIGHT, BP_MENU, BP_QUEUE);
  { What each of BP_FOOT_BUTTONS does. }
  BP_FOOT_TEXTS: array[0..5] of string = ('choose', 'back', '', 'change', 'close', 'the queue');

function TfrmBuilder.PadFoot: string;
var
  B: TArray<Integer>;
  T: TArray<string>;
  I: Integer;
begin
  SetLength(B, Length(BP_FOOT_BUTTONS));
  SetLength(T, Length(BP_FOOT_TEXTS));
  for I := 0 to High(B) do
  begin
    B[I] := BP_FOOT_BUTTONS[I];
    T[I] := BP_FOOT_TEXTS[I];
  end;
  Result := PadFootOf(B, T);
end;

function TfrmBuilder.PadFootFor(AKeys: Boolean): string;
var
  B: TArray<Integer>;
  T: TArray<string>;
  I: Integer;
begin
  SetLength(B, Length(BP_FOOT_BUTTONS));
  SetLength(T, Length(BP_FOOT_TEXTS));
  for I := 0 to High(B) do
  begin
    B[I] := BP_FOOT_BUTTONS[I];
    T[I] := BP_FOOT_TEXTS[I];
  end;
  Result := TPadMenu.HintsText(PadHintsFor(B, T, AKeys));
end;

function TfrmBuilder.PadHintsFor(const AButtons: TArray<Integer>; const ATexts: TArray<string>;
  AKeys: Boolean): TArray<TPadHint>;
var
  I: Integer;
  Origin: TSteamPadOrigin;
  Name, Glyph: string;
begin
  Result := nil;
  for I := 0 to High(AButtons) do
  begin
    Glyph := '';
    Name := '';
    if not AKeys and (FPad <> nil) then
    begin
      // Steam's picture of the control on the pad in hand, else its name
      Origin := FPad.Origin(AButtons[I], FPadDark);
      Glyph := Origin.Glyph;
      Name := Origin.Name;
    end;
    // the keys (or no pad Steam knows): the key's name from the table
    if (Glyph = '') and (Name = '') then
      Name := ReaderMenuFirstKey(BP_ACTIONS[AButtons[I]]);
    if I <= High(ATexts) then
      Result := Result + [TPadMenu.Hint(Glyph, Name, ATexts[I])]
    else
      Result := Result + [TPadMenu.Hint(Glyph, Name, '')];
  end;
end;

function TfrmBuilder.PadFootOf(const AButtons: TArray<Integer>; const ATexts: TArray<string>): string;
begin
  FFootButtons := AButtons;
  FFootTexts := ATexts;
  Result := TPadMenu.HintsText(PadHintsFor(AButtons, ATexts, FPadKeys));
end;

procedure TfrmBuilder.RefreshFoot;
begin
  if (FPadMenu <> nil) and FPadMenu.Showing and (Length(FFootButtons) > 0) then
    FPadMenu.SetHints(PadHintsFor(FFootButtons, FFootTexts, FPadKeys));
end;

function TfrmBuilder.PadButtonOf(const AAction: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  if AAction = '' then
    Exit;
  for I := 0 to Length(BP_ACTIONS) - 1 do
    if SameText(BP_ACTIONS[I], AAction) then
      Exit(I);
end;

procedure TfrmBuilder.SetPadKeys(AKeys: Boolean);
begin
  if AKeys = FPadKeys then
    Exit;
  FPadKeys := AKeys;
  if (FPadMenu = nil) or not FPadMenu.Showing then
    Exit;
  if FPadMode = BPM_CONTROLS then
    PadControls
  else if FCalIntro and (FPadMode = BPM_ASK) then
    // its answers carry their buttons
    ShowCalibrationIntro(FCalIntroWhy)
  else if FPadMenu.HasHints then
    // any list whose foot names buttons: the other way's pictures or keys
    RefreshFoot;
end;

procedure TfrmBuilder.PadPointer(Sender: TObject);
begin
  // later: this comes from a row's own click, and going over to the keys'
  // form frees the rows
  TThread.ForceQueue(nil,
    procedure
    begin
      SetPadKeys(True);
    end);
end;

procedure TfrmBuilder.PadMenuGesture(Sender: TObject; const AGesture: string);
var
  Gesture: string;
begin
  Gesture := AGesture;
  // later: the wheel comes from a row's own event (see PadPointer)
  TThread.ForceQueue(nil,
    procedure
    var
      Button: Integer;
    begin
      SetPadKeys(True);
      Button := PadButtonOf(ReaderMenuPointerAction(Gesture));
      if Button >= 0 then
        PadPress(Button);
    end);
end;

procedure TfrmBuilder.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);

  { The key belongs to the control that has the keyboard: a letter or a
    space typed into a box, the space that presses a button, ticks a box
    or opens a list. }
  function ControlsKey(ASpace: Boolean): Boolean;
  var
    Obj: TFmxObject;
  begin
    Result := False;
    if Focused = nil then
      Exit;
    Obj := Focused.GetObject;
    if Obj is TCustomEdit then
      Result := not TCustomEdit(Obj).ReadOnly
    else if Obj is TCustomMemo then
      Result := not TCustomMemo(Obj).ReadOnly
    else if ASpace then
      Result := (Obj is TCustomButton) or (Obj is TCheckBox) or (Obj is TCustomComboBox);
  end;

var
  Button: Integer;
begin
  // the calibration's results: Enter, Escape, the space or a character
  // goes on too (the menu's keys do through PadPress)
  if FCalResults and ((Key = vkReturn) or (Key = vkEscape) or (KeyChar <> #0)) then
  begin
    Key := 0;
    KeyChar := #0;
    CalResultsButton(nil);
    Exit;
  end;
  Button := -1;
  if (FPadMenu <> nil) and (FPad <> nil) and (Shift * [ssCtrl, ssAlt, ssCommand] = []) then
  begin
    // the key's action, from the table generated with the Steam Input
    // actions; its button here
    Button := PadButtonOf(ReaderMenuKeyAction(Key, KeyChar));
    if not (FPadMenu.Showing or ((FCoverPick <> nil) and FCoverPick.Showing)) then
    begin
      // closed: in Big Picture what opens the menu or the queue (as on a
      // pad); the other actions' keys are left to the log. On the desktop
      // (owner, 2026-11-22: the Menu and Queue keys must open them; F5
      // and F6 since zip 260) those two only - Enter is the window's - and
      // not a character that is a control's own
      if FCalResults then
        // the calibration's results: any of the menu's keys goes on
        // (PadPress)
      else if FBenchResults and FBenchHidden then
        // the benchmark results hidden: any of the menu's keys shows them
        // (PadPress)
      else if FBigPicture then
      begin
        if (Button <> BP_MENU) and (Button <> BP_CHOOSE) and (Button <> BP_QUEUE) then
          Button := -1;
      end
      else if ((Button <> BP_MENU) and (Button <> BP_QUEUE)) or ((KeyChar <> #0) and ControlsKey(KeyChar = ' ')) then
        Button := -1
      else
        DebugLog('keys: ' + BP_ACTIONS[Button] + ' on the desktop');
    end;
  end;
  if Button < 0 then
  begin
    inherited;
    Exit;
  end;
  Key := 0;
  KeyChar := #0;
  SetPadKeys(True);
  if FRedraw <> nil then
    FRedraw.UserInput;
  PadPress(Button);
end;

procedure TfrmBuilder.PadControls;
type
  { One row: what it does, the pad's button (BP_*), its usual name when
    Steam gives none. The keys are uReaderInput's. }
  TControlRow = record
    Text: string;
    Button: Integer;
    Pad: string;
  end;
const
  { One row per action (owner, 2026-11-22: "Up, Down, Left, Right separate
    lines"; short names). }
  ROWS: array[0..8] of TControlRow = (
    (Text: 'Choose'; Button: BP_CHOOSE; Pad: 'A'),
    (Text: 'Back'; Button: BP_BACK; Pad: 'B'),
    (Text: 'Up'; Button: BP_UP; Pad: 'D-pad up'),
    (Text: 'Down'; Button: BP_DOWN; Pad: 'D-pad down'),
    (Text: 'Decrease value'; Button: BP_LEFT; Pad: 'D-pad left'),
    (Text: 'Increase value'; Button: BP_RIGHT; Pad: 'D-pad right'),
    (Text: 'Menu'; Button: BP_MENU; Pad: 'Start'),
    (Text: 'Queue'; Button: BP_QUEUE; Pad: 'View'),
    (Text: 'Show / hide results'; Button: BP_TOGGLE; Pad: 'X'));

  { The list for the keys (AKeys) or for the pad, the same layout in both
    (owner, 2026-11-22): the key or the button on the left, what it does
    on the right; Back last. }
  function ListFor(AKeys: Boolean): TArray<TPadMenuItem>;
  var
    I: Integer;
    Row: TPadMenuItem;
    Origin: TSteamPadOrigin;
  begin
    Result := nil;
    for I := 0 to Length(ROWS) - 1 do
    begin
      Row := TPadMenu.Item('', ROWS[I].Text);
      if AKeys then
        // the keys, the mouse and the finger of the action, from the table
        Row.Text := ReaderMenuKeyNames(BP_ACTIONS[ROWS[I].Button], True)
      else
      begin
        // Steam's picture; its name, or the usual one, without
        Origin := FPad.Origin(ROWS[I].Button, FPadDark);
        if Origin.Glyph <> '' then
          Row.Glyphs := Row.Glyphs + [Origin.Glyph]
        else if Origin.Name <> '' then
          Row.Text := Origin.Name
        else
          Row.Text := ROWS[I].Pad;
      end;
      Result := Result + [Row];
    end;
    Result := Result + [TPadMenu.Item('Back')];
  end;

  { The list's title for the keys or for the pad. }
  function TitleFor(AKeys: Boolean): string;
  begin
    if AKeys then
      Result := 'Controls - keyboard, mouse and touch'
    else if FPad.PadName <> '' then
      Result := 'Controls - ' + FPad.PadName
    else
      Result := 'Controls - controller';
  end;

var
  Items: TArray<TPadMenuItem>;
  I, Sel: Integer;
begin
  if FPadMenu = nil then
    Exit;
  // shown again for the other way of control: the row stays
  Sel := -1;
  if FPadMenu.Showing and (FPadMode = BPM_CONTROLS) then
    Sel := FPadMenu.Selected;
  Items := ListFor(FPadKeys);
  FPadCmds := nil;
  for I := 0 to Length(Items) - 2 do
    FPadCmds := FPadCmds + [PADROW_NONE];
  FPadCmds := FPadCmds + [PADROW_BACK];
  FPadMode := BPM_CONTROLS;
  if (Sel < 0) or (Sel > Length(Items) - 1) then
    Sel := Length(Items) - 1;
  // both forms the same width, the wider one's (owner, 2026-11-22): the
  // box does not change size when the list changes over
  FPadMenu.MinWidth := FPadMenu.WidthFor(TitleFor(not FPadKeys), ListFor(not FPadKeys),
    PadFootFor(not FPadKeys));
  try
    FPadMenu.Show(TitleFor(FPadKeys), Items, Sel, PadFoot);
  finally
    FPadMenu.MinWidth := 0;
  end;
  RefreshFoot;
end;

procedure TfrmBuilder.PadClosed(Sender: TObject);
begin
  // a click beside a question answers it as B does
  if FPadMode = BPM_ASK then
    PadAnswer(-1);
end;

procedure TfrmBuilder.PadBack;
begin
  // the Settings page: back to the first page, on its Settings row
  if (FPadMode = BPM_HOME) and FPadSettings then
  begin
    if FPadSettingsOnly then
    begin
      // File > Settings: closed
      FPadSettingsOnly := False;
      FPadMenu.Hide;
    end
    else
      PadHome(BPC_SETTINGS);
    Exit;
  end;
  case FPadMode of
    BPM_ASK: PadAnswer(-1);
    BPM_BOOKS, BPM_AUDIO, BPM_QUEUE: PadHome(BPC_BOOK);
    BPM_MODELS: PadHome(BPC_MODEL);
    BPM_CONTROLS: PadHome(BPC_CONTROLS);
    BPM_BENCH: PadHome(BPC_BENCH);
    BPM_BOARDS: PadBenchmarks;
    BPM_BOARD: PadBoards;
    BPM_QUEUES: PadQueue(-1);
    BPM_JOB: PadQueue(FPadJob);
  else
    FPadMenu.Hide;
  end;
end;

procedure TfrmBuilder.PadHome(ACommand: Integer);
var
  Items: TArray<TPadMenuItem>;
  Sel: Integer;

  procedure Add(ACmd: Integer; const AText, AValue: string);
  begin
    // the rows of the page shown only
    if ((ACmd >= 0) and (ACmd <= BPC_SETTINGS_TOP) and (ACmd in BP_SETTINGS_ROWS)) <> FPadSettings then
      Exit;
    if ACmd = ACommand then
      Sel := Length(Items);
    Items := Items + [TPadMenu.Item(AText, AValue)];
    FPadCmds := FPadCmds + [ACmd];
  end;

  function Combo(ACombo: TComboBox): string;
  begin
    Result := '';
    if (ACombo <> nil) and (ACombo.ItemIndex >= 0) then
      Result := '< ' + PadShort(ACombo.Items[ACombo.ItemIndex]) + ' >';
  end;

var
  Book, Audio: string;
begin
  if FPadMenu = nil then
    Exit;
  UpdateControls;
  Items := nil;
  FPadCmds := nil;
  Sel := 0;
  // the page ACommand's row is on
  FPadSettings := (ACommand >= 0) and (ACommand <= BPC_SETTINGS_TOP) and (ACommand in BP_SETTINGS_ROWS);
  if not FPadSettings then
    FPadSettingsOnly := False;
  if FBookTitle <> '' then
    Book := FBookTitle
  else if edBook.Text <> '' then
    Book := ChangeFileExt(ExtractFileName(edBook.Text), '')
  else
    Book := 'choose ...';
  case lbAudio.Count of
    0: Audio := 'choose ...';
    1: Audio := ExtractFileName(lbAudio.Items[0]);
  else
    Audio := Format('%d files', [lbAudio.Count]);
  end;
  // owner, 2026-11-20: Add to queue third, Queue fourth; no Run queue here
  // (it is the Queue list's first row)
  Add(BPC_BOOK, 'Book', Book);
  Add(BPC_AUDIO, 'Audio', Audio);
  if btnAddJob.Enabled then
    Add(BPC_ADD, 'Add to queue', '');
  Add(BPC_QUEUE, 'Queue', Format('%d job(s)%s', [Length(FJobs), IfThen(FQueueRunning, ', running', '')]));
  if (cbModel.ItemIndex >= 0) and (cbModel.ItemIndex < cbModel.Count) then
    Add(BPC_MODEL, 'Model', PadShort(cbModel.Items[cbModel.ItemIndex]))
  else
    Add(BPC_MODEL, 'Model', 'choose ...');
  // what is done with a model, right under it (owner, 2026-11-21: "Move
  // calibrate and diagnostics under model")
  if FToolsReady then
    Add(BPC_CALIBRATE, 'Re-calibrate (this model)', '');
  if FToolsReady and (FModelPath <> '') then
  begin
    Add(BPC_CALIBRATE_ALL, 'Re-calibrate every model', 'All installed');
    Add(BPC_DIAGNOSE, 'Diagnostics (this model)', 'four test runs');
    Add(BPC_DIAGNOSE_ALL, 'Diagnostics (every model)', 'All installed');
  end;
  // the desktop's own, not in Steam builds (there the models are in the
  // program's folder)
  if not FBigPicture and not SteamBuild and (FDownload = nil) then
    Add(BPC_FOLDER_MODELS, 'Models folder', ExtractFileName(ExcludeTrailingPathDelimiter(FModelsFolder)));
  Add(BPC_DEVICE, 'Device', Combo(cbDevice));
  if cbLanguage <> nil then
    Add(BPC_LANGUAGE, 'Language', Combo(cbLanguage));
  Add(BPC_POWER, 'Power', Combo(cbPower));
  // owner, 2026-11-22: a model or device slower than this is not used
  Add(BPC_LOWEST, 'Lowest acceptable speed', LowestSpeedText);
  Add(BPC_CHAPTERS, 'Chapters of a file are parts', IfThen(chkChapters.IsChecked, '< Yes >', '< No >'));
  if not FBigPicture then
  begin
    // re-align in seconds, no new transcription; off again at the next
    // start
    Add(BPC_REUSE, 'Use a saved transcript (this build only)', IfThen(chkReuse.IsChecked, '< Yes >', '< No >'));
    {$IFDEF MSWINDOWS}
    Add(BPC_GPU, 'Window GPU', Combo(cbGpu));
    {$ENDIF}
  end;
  Add(BPC_DARK, 'Dark mode', IfThen(FPadDark, '< Yes >', '< No >'));
  // benchmark scores to Steam's leaderboards
  if SteamRunning then
    Add(BPC_BOARD, 'Leaderboard', IfThen(FBoardUpload, '< Yes >', '< No >'));
  Add(BPC_EXPERT, 'Expert mode', IfThen(FExpert, '< Yes >', '< No >'));
  // no book yet: the folder its copy will go to
  if edOut.Text <> '' then
    Add(BPC_OUTPUT, 'Output', ExtractFileName(edOut.Text))
  else
    Add(BPC_OUTPUT, 'Output', ExtractFileName(ExcludeTrailingPathDelimiter(FOutFolder)));
  // the folder dialogs, the log's switch and the history's window are
  // the desktop's
  if not FBigPicture then
  begin
    Add(BPC_FOLDER_BOOKS, 'Books folder', ExtractFileName(ExcludeTrailingPathDelimiter(FBookFolder)));
    Add(BPC_FOLDER_AUDIO, 'Audio folder', ExtractFileName(ExcludeTrailingPathDelimiter(FAudioFolder)));
    Add(BPC_FOLDER_OUTPUT, 'Output folder', ExtractFileName(ExcludeTrailingPathDelimiter(FOutFolder)));
    Add(BPC_LOG, 'Show the log', IfThen(mmLog.Visible, '< Yes >', '< No >'));
  end;
  Add(BPC_RESULTS, 'Calibration results', '');
  if not FBigPicture then
    Add(BPC_HISTORY, 'Build history', '');
  if FRocmOffer then
    Add(BPC_ROCM, 'AMD ROCm acceleration', 'free DLC');
  if edBook.Text <> '' then
    Add(BPC_COVER, 'Cover', CoverChoiceText(FCoverChoice));
  if btnCreate.Enabled then
    Add(BPC_CREATE, 'Create', '');
  if btnUpdateJob.Enabled then
    Add(BPC_UPDATE, Format('Update job %d', [FEditJob + 1]), '');
  if btnCancel.Enabled then
    Add(BPC_CANCEL, 'Cancel', PadShort(FStatusText));
  // owner, 2026-11-22: the benchmarks, a list of their own - faded (and
  // saying why when chosen) when none can run
  if miBench[0] <> nil then
  begin
    Add(BPC_BENCH, 'Benchmark', '');
    if (Length(Items) > 0) and (FPadCmds[High(FPadCmds)] = BPC_BENCH) then
      Items[High(Items)].Dim := not (miBench[1].Enabled or miBench[2].Enabled or miBench[3].Enabled or
        miBench[4].Enabled);
  end;
  Add(BPC_CONTROLS, 'Controls', '');
  // owner, 2026-11-22: Settings directly above Exit
  Add(BPC_SETTINGS, 'Settings...', '');
  Add(BPC_EXIT, 'Exit', '');
  Add(BPC_SETTINGS_BACK, 'Back', '');
  FPadMode := BPM_HOME;
  FPadFootTick := 0;
  if FPadSettings then
    FPadMenu.Show('Settings', Items, Sel, PadFoot)
  else
    FPadMenu.Show('EpubBuilder', Items, Sel, PadFoot);
  RefreshFoot;
end;

procedure TfrmBuilder.PadColors;
begin
  if FPadMenu = nil then
    Exit;
  if FPadDark then
    FPadMenu.SetColors(PAD_DARK_BACK, PAD_DARK_TEXT, PAD_DARK_ROW)
  else
    FPadMenu.SetColors(TAlphaColors.White, TAlphaColors.Black, PAD_LIGHT_ROW);
end;

procedure TfrmBuilder.ApplyDarkWindow;
const
  { FMX's own list style with no background: the window's dark fill shows
    through (the reader's contents list, its zip 10). }
  DARK_LIST_STYLE = 'transparentlistboxstyle';
  { Marks a label whose colour this changed: only those are put back. }
  DARK_MARK = 'dark';

  { A memo: its style's background picture no longer drawn, then its text
    light; the style's own again when dark is off. }
  procedure DarkMemo(AMemo: TMemo);
  var
    Obj: TFmxObject;
  begin
    if not FPadDark then
    begin
      if not (TStyledSetting.FontColor in AMemo.StyledSettings) then
      begin
        AMemo.StyledSettings := AMemo.StyledSettings + [TStyledSetting.FontColor];
        // the style's own background again
        AMemo.NeedStyleLookup;
        AMemo.ApplyStyleLookup;
        AMemo.Repaint;
      end;
      Exit;
    end;
    // the background is a picture taken from the style: with no picture
    // to look up it draws nothing, and its children (the text) still do
    Obj := AMemo.FindStyleResource('background');
    if not (Obj is TCustomStyleObject) then
    begin
      if not FDarkNoted then
      begin
        FDarkNoted := True;
        if Obj = nil then
          DebugLog('dark: the log''s style has no "background" yet - looked for again')
        else
          DebugLog('dark: the log keeps the style''s colours - its background is a ' + Obj.ClassName +
            ', not a style picture');
      end;
      Exit;
    end;
    if TCustomStyleObject(Obj).SourceLookup <> '' then
    begin
      TCustomStyleObject(Obj).SourceLookup := '';
      TCustomStyleObject(Obj).Source := nil;
      DebugLog('dark: the background of ' + IfThen(AMemo = mmLog, 'the log', 'the book''s text') + ' (' +
        Obj.ClassName + ') is no longer drawn');
      AMemo.Repaint;
    end;
    // light text only once the background is known to be gone
    if TStyledSetting.FontColor in AMemo.StyledSettings then
    begin
      AMemo.StyledSettings := AMemo.StyledSettings - [TStyledSetting.FontColor];
      AMemo.TextSettings.FontColor := PAD_DARK_TEXT;
      AMemo.Repaint;
    end;
  end;

  { A label that had the style's colour: light, and marked; a marked one
    gets the style's colour back. }
  procedure DarkLabel(ALabel: TLabel);
  begin
    if FPadDark then
    begin
      if TStyledSetting.FontColor in ALabel.StyledSettings then
      begin
        ALabel.StyledSettings := ALabel.StyledSettings - [TStyledSetting.FontColor];
        ALabel.TextSettings.FontColor := PAD_DARK_TEXT;
        ALabel.TagString := DARK_MARK;
      end;
    end
    else if ALabel.TagString = DARK_MARK then
    begin
      ALabel.TagString := '';
      ALabel.StyledSettings := ALabel.StyledSettings + [TStyledSetting.FontColor];
    end;
  end;

  { A list: no background of its own, its rows' text light (new rows come
    with the style's colour: looked at again by tmDark). }
  procedure DarkList(AList: TListBox);
  var
    I: Integer;
    Row: TListBoxItem;
  begin
    if FPadDark then
    begin
      if AList.StyleLookup <> DARK_LIST_STYLE then
      begin
        AList.StyleLookup := DARK_LIST_STYLE;
        AList.NeedStyleLookup;
        AList.ApplyStyleLookup;
      end;
    end
    else if AList.StyleLookup = DARK_LIST_STYLE then
    begin
      AList.StyleLookup := '';
      AList.NeedStyleLookup;
      AList.ApplyStyleLookup;
    end;
    for I := 0 to AList.Count - 1 do
    begin
      Row := AList.ListItems[I];
      if FPadDark then
      begin
        if TStyledSetting.FontColor in Row.StyledSettings then
        begin
          Row.StyledSettings := Row.StyledSettings - [TStyledSetting.FontColor];
          Row.TextSettings.FontColor := PAD_DARK_TEXT;
          Row.TagString := DARK_MARK;
        end;
      end
      else if Row.TagString = DARK_MARK then
      begin
        Row.TagString := '';
        Row.StyledSettings := Row.StyledSettings + [TStyledSetting.FontColor];
      end;
    end;
  end;

  { The labels, lists and memos of AParent and of the layouts in it. Only
    layouts are gone into: a panel (a program asking to connect), the
    pad's menu and the cover chooser keep their own colours; laySettings
    holds no label, list or memo. }
  procedure Walk(AParent: TFmxObject);
  var
    I: Integer;
    C: TFmxObject;
  begin
    for I := 0 to AParent.ChildrenCount - 1 do
    begin
      C := AParent.Children[I];
      if C is TLabel then
        DarkLabel(TLabel(C))
      else if C is TListBox then
        DarkList(TListBox(C))
      else if C is TMemo then
        DarkMemo(TMemo(C))
      else if C is TLayout then
        Walk(C);
    end;
  end;

begin
  if mmLog = nil then
    Exit;
  if FPadDark <> FWindowDark then
  begin
    FWindowDark := FPadDark;
    if FPadDark then
    begin
      Fill.Kind := TBrushKind.Solid;
      Fill.Color := PAD_DARK_WINDOW;
    end
    else
      Fill.Kind := TBrushKind.None;
  end;
  Walk(Self);
end;

procedure TfrmBuilder.DarkBeforeShow;

  { The styles of the memos and lists of AParent and of the layouts in it
    (what ApplyDarkWindow walks). }
  procedure Styles(AParent: TFmxObject);
  var
    I: Integer;
    C: TFmxObject;
  begin
    for I := 0 to AParent.ChildrenCount - 1 do
    begin
      C := AParent.Children[I];
      if (C is TMemo) or (C is TListBox) then
        TStyledControl(C).ApplyStyleLookup
      else if C is TLayout then
        Styles(C);
    end;
  end;

begin
  if not FPadDark then
    Exit;
  try
    Styles(Self);
    ApplyDarkWindow;
  except
    on E: Exception do
      DebugLog('dark before show: ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TfrmBuilder.tmDarkTimer(Sender: TObject);
begin
  try
    // dark: looked at again (a style applied again, a list's new rows);
    // light: nothing to keep
    if FPadDark or FWindowDark then
      ApplyDarkWindow;
  except
    on E: Exception do
      DebugLog('dark: ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TfrmBuilder.ToggleDark;
begin
  FPadDark := not FPadDark;
  PadColors;
  ApplyDarkWindow;
  SaveSettings;
  UpdateControls;
end;

procedure TfrmBuilder.PadBackToMenu(AModel: Boolean);
begin
  if not FBigPicture or (FPadMenu = nil) or (FPadMode = BPM_ASK) then
    Exit;
  if (FBuild <> nil) or (FCalib <> nil) or (FDownload <> nil) or FQueueRunning then
    Exit;
  if AModel then
    PadHome(BPC_MODEL)
  else
    PadHome(BPC_BOOK);
end;

procedure TfrmBuilder.PadStep(ADelta: Integer);
var
  Cmd: Integer;

  procedure Turn(ACombo: TComboBox);
  begin
    if (ACombo = nil) or (ACombo.Count = 0) then
      Exit;
    // the combo box's own change handler does the rest (a model not here
    // yet asks to download it)
    ACombo.ItemIndex := (Max(ACombo.ItemIndex, 0) + ADelta + ACombo.Count) mod ACombo.Count;
  end;

begin
  // a leaderboard: its other page
  if FPadMode = BPM_BOARD then
  begin
    BoardSwitch;
    Exit;
  end;
  if (FPadMode <> BPM_HOME) or (FPadMenu.Selected < 0) or (FPadMenu.Selected > High(FPadCmds)) then
    Exit;
  Cmd := FPadCmds[FPadMenu.Selected];
  case Cmd of
    BPC_DEVICE: Turn(cbDevice);
    BPC_LANGUAGE: Turn(cbLanguage);
    BPC_POWER: Turn(cbPower);
    BPC_CHAPTERS: chkChapters.IsChecked := not chkChapters.IsChecked;
    BPC_REUSE: chkReuse.IsChecked := not chkReuse.IsChecked;
    BPC_BOARD:
      begin
        FBoardUpload := not FBoardUpload;
        SaveSettings;
      end;
    {$IFDEF MSWINDOWS}
    BPC_GPU: Turn(cbGpu);
    {$ENDIF}
    // the list is shown again below: in its new colours
    BPC_DARK: ToggleDark;
    BPC_EXPERT: ToggleExpert;
    BPC_LOG: miLogClick(nil);
    BPC_LOWEST: StepLowestSpeed(ADelta);
  else
    Exit;
  end;
  // a question asked by the change (a model to download) stays
  if FPadMode = BPM_HOME then
    PadHome(Cmd);
end;

procedure TfrmBuilder.PadChoose(Sender: TObject; AIndex: Integer);
var
  Cmd, I: Integer;
  L: TStringList;
begin
  if FPadMode = BPM_ASK then
  begin
    PadAnswer(AIndex);
    Exit;
  end;
  if (AIndex < 0) or (AIndex > High(FPadCmds)) then
    Exit;
  Cmd := FPadCmds[AIndex];
  case FPadMode of
    BPM_HOME:
      case Cmd of
        BPC_BOOK: PadBooks;
        BPC_AUDIO: PadAudioList(False);
        BPC_MODEL: PadModels;
        BPC_DEVICE, BPC_LANGUAGE, BPC_POWER, BPC_CHAPTERS, BPC_DARK, BPC_EXPERT, BPC_LOG, BPC_REUSE, BPC_GPU,
        BPC_BOARD:
          PadStep(1);
        // chosen: a step down (owner, 2026-11-22: "from 2.0 down to 0.0")
        BPC_LOWEST: PadStep(-1);
        BPC_OUTPUT:
          // owner, 2026-11-22: the row "does nothing (just prints Output:
          // on screen)" - said in the menu now, with the folder when no
          // book is chosen yet
          begin
            // the note's OK brings the Settings page back on this row
            FPadToOutput := FBigPicture;
            if edOut.Text <> '' then
              Tell('The read-along book is written to:' + sLineBreak + edOut.Text)
            else
              Tell('No book is chosen yet. Its read-along copy will be written into:' + sLineBreak + FOutFolder +
              sLineBreak + sLineBreak + 'Settings > Output folder (on the desktop) changes the folder.');
          end;
        BPC_CONTROLS: PadControls;
        BPC_SETTINGS: PadHome(BPC_MODEL);
        BPC_SETTINGS_BACK: PadBack;
        BPC_FOLDER_BOOKS, BPC_FOLDER_AUDIO, BPC_FOLDER_OUTPUT:
          begin
            // the folder dialog, then the page again with the new name
            ChooseFolder(Cmd - BPC_FOLDER_BOOKS);
            PadHome(Cmd);
          end;
        BPC_FOLDER_MODELS:
          begin
            ChooseModelsFolder;
            PadHome(Cmd);
          end;
        BPC_RESULTS:
          begin
            // the results' page over the window: the menu out of its way
            FPadMenu.Hide;
            ShowCalibrationPage;
          end;
        BPC_HISTORY:
          begin
            FPadMenu.Hide;
            miHistoryClick(nil);
          end;
        BPC_ROCM:
          begin
            FPadMenu.Hide;
            miRocmClick(nil);
          end;
        BPC_COVER: ShowCoverPicker;
        BPC_CREATE, BPC_ADD, BPC_UPDATE:
          begin
            FPadMenu.Hide;
            FPadMode := BPM_HOME;
            case Cmd of
              BPC_CREATE: btnCreateClick(nil);
              BPC_ADD: btnAddJobClick(nil);
              BPC_UPDATE: btnUpdateJobClick(nil);
            end;
            // no question asked: the home list again, Queue selected (its
            // first row runs it; a build shows in the window - Start brings
            // the menu back)
            if (FPadMode <> BPM_ASK) and (Cmd <> BPC_CREATE) then
              PadHome(BPC_QUEUE);
          end;
        BPC_QUEUE: PadQueue(-1);
        BPC_RUN:
          begin
            FPadMenu.Hide;
            btnRunQueueClick(nil);
          end;
        BPC_CANCEL:
          begin
            btnCancelClick(nil);
            PadHome(BPC_QUEUE);
          end;
        BPC_CALIBRATE:
          begin
            FPadMenu.Hide;
            miCalibrateClick(nil);
          end;
        BPC_CALIBRATE_ALL:
          begin
            FPadMenu.Hide;
            miCalibrateAllClick(nil);
          end;
        BPC_DIAGNOSE:
          begin
            FPadMenu.Hide;
            miDiagnosticsClick(nil);
          end;
        BPC_DIAGNOSE_ALL:
          begin
            FPadMenu.Hide;
            miDiagnosticsAllClick(nil);
          end;
        BPC_BENCH:
          if not (miBench[1].Enabled or miBench[2].Enabled or miBench[3].Enabled or miBench[4].Enabled) then
            // a faded row says why (StartBenchmark's checks)
            StartBenchmark(1)
          else
            PadBenchmarks;
        BPC_EXIT:
          if FBuild <> nil then
            Ask('A build is running (' + PadShort(FStatusText) + '). Closing stops it, and its work so far ' +
              'is lost.' + sLineBreak + sLineBreak + 'Stop the build and close?', TMsgDlgType.mtWarning,
              [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo,
              procedure(const AResult: TModalResult)
              begin
                if AResult = mrYes then
                begin
                  FForceClose := True;
                  Close;
                end;
              end)
          else
            Close;
      end;
    BPM_BOOKS:
      if (Cmd >= 0) and (Cmd <= High(FPadBooks)) then
      begin
        ShowBook(FPadBooks[Cmd]);
        UpdateControls;
        // a card's book: where its EPUB goes, then its audio (the best
        // matches, to confirm)
        AskOutputPlace(FPadBooks[Cmd],
          procedure
          begin
            PadAudioList(False);
          end);
      end
      else if Cmd = PADROW_BACK then
        PadHome(BPC_BOOK);
    BPM_AUDIO:
      if (Cmd >= 0) and (Cmd <= High(FPadAudio)) then
      begin
        L := TStringList.Create;
        try
          for I := 0 to High(FPadAudio[Cmd].Files) do
            L.Add(FPadAudio[Cmd].Files[I]);
          lbAudio.Clear;
          AddAudio(L);
        finally
          L.Free;
        end;
        WindowLine(Format('Audio: %s (%d file(s))', [FPadAudio[Cmd].Name, lbAudio.Count]));
        PadHome(BPC_CREATE);
      end
      else
        case Cmd of
          PADROW_BROWSE: PadAudioList(True);
          PADROW_KEEP, PADROW_BACK: PadHome(BPC_AUDIO);
        end;
    BPM_CONTROLS:
      if Cmd = PADROW_BACK then
        PadHome(BPC_CONTROLS);
    BPM_BENCH:
      if (Cmd >= 0) and (Cmd <= High(miBench)) then
      begin
        FPadMenu.Hide;
        FPadMode := BPM_HOME;
        // a faded row says why (StartBenchmark's checks)
        StartBenchmark(Cmd);
        // nothing started and nothing asked: the list again
        if (FPadMode <> BPM_ASK) and (FBuild = nil) then
          PadBenchmarks;
      end
      else if Cmd = PADROW_BOARDS then
        PadBoards
      else if Cmd = PADROW_BACK then
        PadHome(BPC_BENCH);
    BPM_BOARDS:
      if (Cmd >= 1) and (Cmd <= 4) then
        PadBoard(Cmd)
      else if Cmd = PADROW_BACK then
        PadBenchmarks;
    BPM_BOARD:
      if Cmd = PADROW_BACK then
        PadBoards;
    BPM_QUEUES:
      if (Cmd >= 0) and (Cmd <= High(FPadBooks)) then
      begin
        // FPadBooks holds the queue files here
        FQueueFile := FPadBooks[Cmd];
        try
          I := LoadQueue(FQueueFile);
          ShowJobs;
          UpdateControls;
          Tell(Format('%d job(s) added from %s.', [I, ChangeFileExt(ExtractFileName(FQueueFile), '')]));
        except
          on E: Exception do
            Tell('The queue file cannot be read: ' + E.Message);
        end;
        if FPadMode <> BPM_ASK then
          PadQueue(-1);
      end
      else if Cmd = PADROW_BACK then
        PadQueue(-1);
    BPM_MODELS:
      if (Cmd >= 0) and (Cmd < cbModel.Count) then
      begin
        FPadMode := BPM_HOME;
        if cbModel.ItemIndex = Cmd then
          PadHome(BPC_MODEL)
        else
        begin
          // the list's own change: a model here is taken, one to download
          // is asked about (in this menu)
          cbModel.ItemIndex := Cmd;
          if FPadMode <> BPM_ASK then
            PadHome(BPC_MODEL);
        end;
      end
      else if Cmd = PADROW_DOWNLOAD_ALL then
      begin
        FPadMode := BPM_HOME;
        DownloadEveryModel;
        // nothing to fetch, or refused before the question: the home list
        if (FPadMode <> BPM_ASK) and (FDownload = nil) then
          PadHome(BPC_MODEL);
      end
      else if Cmd = PADROW_BACK then
        PadHome(BPC_MODEL);
    BPM_QUEUE:
      if (Cmd >= 0) and (Cmd <= High(FJobs)) then
        PadJob(Cmd)
      else
        case Cmd of
          PADROW_RUN:
            begin
              FPadMenu.Hide;
              btnRunQueueClick(nil);
            end;
          PADROW_SAVEQ: PadSaveQueue;
          PADROW_LOADQ: PadQueues;
          PADROW_BACK: PadHome(BPC_QUEUE);
        end;
    BPM_JOB:
      if (FPadJob >= 0) and (FPadJob <= High(FJobs)) then
      begin
        lbJobs.ItemIndex := FPadJob;
        case Cmd of
          PADROW_SHOW:
            begin
              ShowJobInWindow(FPadJob, True);
              PadHome(BPC_UPDATE);
            end;
          PADROW_UP:
            begin
              btnJobUpClick(nil);
              PadQueue(lbJobs.ItemIndex);
            end;
          PADROW_DOWN:
            begin
              btnJobDownClick(nil);
              PadQueue(lbJobs.ItemIndex);
            end;
          PADROW_REMOVE:
            begin
              btnJobRemoveClick(nil);
              PadQueue(-1);
            end;
          PADROW_BACK: PadQueue(FPadJob);
        end;
      end
      else
        PadQueue(-1);
  end;
end;

{ A book's key for TranscribedBooks: its file name without the extension
  (an output's '_001' ... left off too), lower case. }
function BookKey(const AFileName: string): string;
var
  Name: string;
  N: Integer;
begin
  Name := ChangeFileExt(ExtractFileName(AFileName), '');
  N := Length(Name);
  // DefaultOutput's '<name>_001.epub' when '<name>.epub' was taken
  if (N > 4) and (Name[N - 3] = '_') and CharInSet(Name[N - 2], ['0'..'9']) and CharInSet(Name[N - 1], ['0'..'9'])
    and CharInSet(Name[N], ['0'..'9']) then
    Name := Copy(Name, 1, N - 4);
  Result := LowerCase(Name);
end;

function TfrmBuilder.TranscribedBooks: TStringList;
var
  Folders: TArray<string>;
  D, F: string;
  I: Integer;
  R: TBuildHistoryRow;
begin
  Result := TStringList.Create;
  Result.Sorted := True;
  Result.Duplicates := dupIgnore;
  Result.CaseSensitive := True;
  // the books made: the output folder, the queue's, the cards' Transcribed
  Folders := [FOutFolder];
  for I := 0 to High(FJobs) do
    Folders := Folders + [ExtractFileDir(FJobs[I].Output)];
  Folders := Folders + CardFolders(CARD_TRANSCRIBED);
  for D in Folders do
    try
      if (D <> '') and TDirectory.Exists(D) then
        for F in TDirectory.GetFiles(D) do
          if SameText(ExtractFileExt(F), '.epub') then
            Result.Add(BookKey(F));
    except
      on E: Exception do
        DebugLog('pad: ' + D + ': ' + E.Message);
    end;
  // and the builds in the history (their books may have moved on, to
  // EpubReader or BookManager): those matched well
  try
    for R in HistoryLoad(HistoryFile) do
      if (R.OutputName <> '') and (R.MatchedPercent >= HISTORY_POOR_MATCH) then
        Result.Add(BookKey(R.OutputName));
  except
    on E: Exception do
      DebugLog('pad: the history: ' + E.Message);
  end;
end;

procedure TfrmBuilder.PadBooks;
var
  Items: TArray<TPadMenuItem>;
  Files: TArray<string>;
  I: Integer;
  Sub: string;
  Done: TStringList;
  It: TPadMenuItem;
begin
  Items := nil;
  FPadCmds := nil;
  FPadBooks := nil;
  Files := nil;
  try
    if TDirectory.Exists(FBookFolder) then
      Files := BookFilesIn(FBookFolder);
  except
    on E: Exception do
      DebugLog('pad: the books folder: ' + E.Message);
  end;
  // memory cards' Books folders too (uCards)
  for Sub in CardFolders(CARD_BOOKS) do
    if not SameFileName(ExcludeTrailingPathDelimiter(Sub), ExcludeTrailingPathDelimiter(FBookFolder)) then
    try
      Files := Files + BookFilesIn(Sub);
    except
      on E: Exception do
        DebugLog('pad: ' + Sub + ': ' + E.Message);
    end;
  // the books to do first, those transcribed already last - faded and
  // marked (owner, 2026-11-20)
  Done := TranscribedBooks;
  try
    TArray.Sort<string>(Files, TComparer<string>.Construct(
      function(const A, B: string): Integer
      begin
        Result := Ord(Done.IndexOf(BookKey(A)) >= 0) - Ord(Done.IndexOf(BookKey(B)) >= 0);
        if Result = 0 then
          Result := CompareText(ExtractFileName(A), ExtractFileName(B));
      end));
    for I := 0 to High(Files) do
    begin
      // where it is: its folder in the books folder, or the card's name
      if CardOf(Files[I]) <> '' then
        Sub := 'card ' + CardName(CardOf(Files[I]))
      else
        Sub := ExcludeTrailingPathDelimiter(ExtractRelativePath(IncludeTrailingPathDelimiter(FBookFolder),
          ExtractFilePath(Files[I])));
      It := TPadMenu.Item(ChangeFileExt(ExtractFileName(Files[I]), ''), Sub);
      if Done.IndexOf(BookKey(Files[I])) >= 0 then
      begin
        It.Dim := True;
        if Sub = '' then
          It.Value := 'transcribed'
        else
          It.Value := Sub + ', transcribed';
      end;
      Items := Items + [It];
      FPadCmds := FPadCmds + [I];
    end;
  finally
    Done.Free;
  end;
  FPadBooks := Files;
  if Length(Files) = 0 then
  begin
    Items := Items + [TPadMenu.Item('No EPUB or MOBI files in ' + FBookFolder)];
    FPadCmds := FPadCmds + [PADROW_NONE];
  end;
  Items := Items + [TPadMenu.Item('Back')];
  FPadCmds := FPadCmds + [PADROW_BACK];
  FPadMode := BPM_BOOKS;
  FPadMenu.Show('Books', Items, 0, 'The books folder: ' + FBookFolder);
end;

function TfrmBuilder.PadAudioCandidates: TArray<TPadAudio>;
var
  Files, Bases: TArray<string>;
  Dirs: TDictionary<string, TList<string>>;
  F, D, B: string;
  Key: TArray<string>;
  C: TPadAudio;
  L: TStringList;
  Pair: TPair<string, TList<string>>;

  { The base folder AFile is in, with a path separator. }
  function BaseOf(const AFile: string): string;
  var
    X: string;
  begin
    Result := IncludeTrailingPathDelimiter(FAudioFolder);
    for X in Bases do
      if AFile.StartsWith(IncludeTrailingPathDelimiter(X)) then
        Exit(IncludeTrailingPathDelimiter(X));
  end;

  { How the list names AFile (a file or a folder): its path in its base;
    a card's with the card's name first. }
  function Shown(const APath: string): string;
  var
    X: string;
  begin
    X := BaseOf(APath);
    Result := ExcludeTrailingPathDelimiter(ExtractRelativePath(X, APath));
    if Result = '' then
      Result := ExtractFileName(ExcludeTrailingPathDelimiter(X));
    if CardOf(APath) <> '' then
      Result := CardName(CardOf(APath)) + ': ' + Result;
  end;

begin
  Result := nil;
  Files := nil;
  // the audio folder, and memory cards' Audio folders (uCards)
  Bases := [FAudioFolder];
  for B in CardFolders(CARD_AUDIO) do
    if not SameFileName(ExcludeTrailingPathDelimiter(B), ExcludeTrailingPathDelimiter(FAudioFolder)) then
      Bases := Bases + [B];
  for B in Bases do
  try
    if TDirectory.Exists(B) then
      Files := Files + TDirectory.GetFiles(B, '*', TSearchOption.soAllDirectories);
  except
    on E: Exception do
      DebugLog('pad: ' + B + ': ' + E.Message);
  end;
  // the book's title, else its file's name
  Key := PadWords(FBookTitle);
  if Length(Key) = 0 then
    Key := PadWords(ChangeFileExt(ExtractFileName(edBook.Text), ''));
  Dirs := TObjectDictionary<string, TList<string>>.Create([doOwnsValues]);
  try
    for F in Files do
    begin
      if IndexText(ExtractFileExt(F), BP_AUDIO_EXTS) < 0 then
        Continue;
      // each file
      C.Name := Shown(F);
      C.Files := [F];
      C.Score := PadScore(Key, PadWords(ChangeFileExt(ExtractFileName(F), '')));
      Result := Result + [C];
      D := ExtractFileDir(F);
      if not Dirs.ContainsKey(D) then
        Dirs.Add(D, TList<string>.Create);
      Dirs[D].Add(F);
    end;
    // each folder of two or more: all its files, in name order (a book in
    // parts); scored by the folder's name
    for Pair in Dirs do
      if Pair.Value.Count >= 2 then
      begin
        L := TStringList.Create;
        try
          for F in Pair.Value do
            L.Add(F);
          L.CustomSort(NaturalFileOrder);
          C.Name := Shown(IncludeTrailingPathDelimiter(Pair.Key));
          C.Files := L.ToStringArray;
          C.Score := PadScore(Key, PadWords(ExtractFileName(Pair.Key)));
          Result := Result + [C];
        finally
          L.Free;
        end;
      end;
  finally
    Dirs.Free;
  end;
  TArray.Sort<TPadAudio>(Result, TComparer<TPadAudio>.Construct(
    function(const A, B: TPadAudio): Integer
    begin
      Result := CompareValue(B.Score, A.Score);
      if Result = 0 then
        Result := CompareText(A.Name, B.Name);
    end));
end;

procedure TfrmBuilder.PadAudioList(AAll: Boolean);
var
  Items: TArray<TPadMenuItem>;
  All: TArray<TPadAudio>;
  I, N: Integer;
  Title, Value: string;
begin
  All := PadAudioCandidates;
  if AAll then
    TArray.Sort<TPadAudio>(All, TComparer<TPadAudio>.Construct(
      function(const A, B: TPadAudio): Integer
      begin
        Result := CompareText(A.Name, B.Name);
      end))
  else
  begin
    // the matches first: those with anything in common, at most
    // BP_AUDIO_FIRST
    N := 0;
    while (N < Length(All)) and (N < BP_AUDIO_FIRST) and (All[N].Score > 0) do
      Inc(N);
    SetLength(All, N);
  end;
  FPadAudio := All;
  Items := nil;
  FPadCmds := nil;
  for I := 0 to High(All) do
  begin
    if Length(All[I].Files) > 1 then
      Value := Format('%d files', [Length(All[I].Files)])
    else
      Value := '';
    if (I = 0) and not AAll then
      Value := IfThen(Value = '', 'best match', Value + ', best match');
    Items := Items + [TPadMenu.Item(All[I].Name, Value)];
    FPadCmds := FPadCmds + [I];
  end;
  if Length(All) = 0 then
  begin
    if AAll then
      Items := Items + [TPadMenu.Item('No audio files in ' + FAudioFolder)]
    else
      Items := Items + [TPadMenu.Item('No audio whose name matches the book')];
    FPadCmds := FPadCmds + [PADROW_NONE];
  end;
  if not AAll then
  begin
    Items := Items + [TPadMenu.Item('All the audio in the folder ...')];
    FPadCmds := FPadCmds + [PADROW_BROWSE];
  end;
  if lbAudio.Count > 0 then
  begin
    Items := Items + [TPadMenu.Item('Keep the list as it is', Format('%d file(s)', [lbAudio.Count]))];
    FPadCmds := FPadCmds + [PADROW_KEEP];
  end;
  Items := Items + [TPadMenu.Item('Back')];
  FPadCmds := FPadCmds + [PADROW_BACK];
  Title := 'Audio';
  if FBookTitle <> '' then
    Title := 'Audio for ' + FBookTitle;
  FPadMode := BPM_AUDIO;
  FPadMenu.Show(Title, Items, 0, 'The audio folder: ' + FAudioFolder);
end;

procedure TfrmBuilder.PadQueue(ASelected: Integer);
var
  Items: TArray<TPadMenuItem>;
  I, Sel: Integer;
begin
  Items := nil;
  FPadCmds := nil;
  Sel := 0;
  if btnRunQueue.Enabled then
  begin
    Items := Items + [TPadMenu.Item(btnRunQueue.Text)];
    FPadCmds := FPadCmds + [PADROW_RUN];
  end;
  for I := 0 to High(FJobs) do
  begin
    if I = ASelected then
      Sel := Length(Items);
    Items := Items + [TPadMenu.Item(JobText(I))];
    FPadCmds := FPadCmds + [I];
  end;
  if Length(FJobs) = 0 then
  begin
    Items := Items + [TPadMenu.Item('No jobs: Add to queue adds the book in the window')];
    FPadCmds := FPadCmds + [PADROW_NONE];
  end
  else
  begin
    Items := Items + [TPadMenu.Item('Save queue', 'in the queues folder')];
    FPadCmds := FPadCmds + [PADROW_SAVEQ];
  end;
  Items := Items + [TPadMenu.Item('Load a queue ...')];
  FPadCmds := FPadCmds + [PADROW_LOADQ];
  Items := Items + [TPadMenu.Item('Back')];
  FPadCmds := FPadCmds + [PADROW_BACK];
  FPadMode := BPM_QUEUE;
  FPadFootTick := 0;
  FPadMenu.Show('Queue', Items, Sel, PadFoot);
  RefreshFoot;
end;

procedure TfrmBuilder.PadSaveQueue;
var
  F: string;
begin
  F := TPath.Combine(FQueueFolder, 'queue-' + FormatDateTime('yyyy-mm-dd-hhnn', Now) + '.json');
  try
    ForceDirectories(FQueueFolder);
    SaveQueue(F);
    FQueueFile := F;
    Tell(Format('The queue (%d job(s)) was saved as %s.', [Length(FJobs), ChangeFileExt(ExtractFileName(F), '')]));
  except
    on E: Exception do
      Tell('The queue was not saved: ' + E.Message);
  end;
end;

procedure TfrmBuilder.PadQueues;
var
  Items: TArray<TPadMenuItem>;
  Files: TArray<string>;
  I: Integer;
begin
  Items := nil;
  FPadCmds := nil;
  Files := nil;
  try
    if TDirectory.Exists(FQueueFolder) then
      Files := TDirectory.GetFiles(FQueueFolder, '*.json');
  except
    on E: Exception do
      DebugLog('pad: the queues folder: ' + E.Message);
  end;
  // newest first
  TArray.Sort<string>(Files, TComparer<string>.Construct(
    function(const A, B: string): Integer
    begin
      Result := CompareDateTime(TFile.GetLastWriteTime(B), TFile.GetLastWriteTime(A));
    end));
  FPadBooks := Files;
  for I := 0 to High(Files) do
  begin
    Items := Items + [TPadMenu.Item(ChangeFileExt(ExtractFileName(Files[I]), ''),
      FormatDateTime('yyyy-mm-dd hh:nn', TFile.GetLastWriteTime(Files[I])))];
    FPadCmds := FPadCmds + [I];
  end;
  if Length(Files) = 0 then
  begin
    Items := Items + [TPadMenu.Item('No saved queues yet')];
    FPadCmds := FPadCmds + [PADROW_NONE];
  end;
  Items := Items + [TPadMenu.Item('Back')];
  FPadCmds := FPadCmds + [PADROW_BACK];
  FPadMode := BPM_QUEUES;
  FPadMenu.Show('Load a queue', Items, 0, 'Its jobs are added to the queue - ' + FQueueFolder);
end;

procedure TfrmBuilder.AskOutputPlace(const ABook: string; const AThen: TProc);
var
  Card, Here, There: string;
  Next: TProc;
begin
  Next := AThen;
  Card := CardOf(ABook);
  if (Card = '') or (edOut.Text = '') then
  begin
    if Assigned(Next) then
      Next;
    Exit;
  end;
  Here := edOut.Text;
  There := TPath.Combine(TPath.Combine(Card, CARD_TRANSCRIBED), ExtractFileName(Here));
  // owner, 2026-11-20: "ask - local or back on card"
  Ask(Format('%s is on the memory card %s.' + sLineBreak + sLineBreak +
    'Put the transcribed book back on the card (%s)?' + sLineBreak + sLineBreak +
    'No keeps it on this machine (%s).', [ExtractFileName(ABook), CardName(Card), ExtractFileDir(There),
    ExtractFileDir(Here)]), TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbYes,
    procedure(const AResult: TModalResult)
    begin
      if AResult = mrYes then
      begin
        edOut.Text := There;
        FAutoOut := There;
        WindowLine('Output: on the card - ' + There);
      end;
      UpdateControls;
      if Assigned(Next) then
        Next;
    end);
end;

procedure TfrmBuilder.PadModels;
var
  Items: TArray<TPadMenuItem>;
  I, P, Sel: Integer;
  T, V, Best: string;
  Speed: Double;
  Slow: Boolean;
begin
  Items := nil;
  FPadCmds := nil;
  Sel := 0;
  // owner, 2026-11-21: "a download all models at the top of models"
  if (FDownload = nil) and (FBuild = nil) and (FCalib = nil) and not FQueueRunning then
  begin
    Items := Items + [TPadMenu.Item('Download every model', 'all not installed')];
    FPadCmds := FPadCmds + [PADROW_DOWNLOAD_ALL];
    Sel := 1;
  end;
  for I := 0 to cbModel.Count - 1 do
  begin
    // "Other model file ..." needs a file dialog: not here
    if (I < FModelItems.Count) and (FModelItems[I] = '') then
      Continue;
    T := cbModel.Items[I];
    // "name - note (1.6 GB to download)": the name, and what is in brackets
    V := '';
    P := LastDelimiter('(', T);
    if (P > 0) and T.EndsWith(')') then
      V := Copy(T, P + 1, Length(T) - P - 1)
    else if T.Contains(' - in the models folder') then
      V := 'in the models folder';
    // owner, 2026-11-22: "installed", not "here"
    if V = '' then
      V := 'installed';
    // below Settings > Lowest acceptable speed at its best: faded, with its
    // speed (still chosen here - to re-calibrate it; a build says why not)
    Slow := False;
    if (FLowestSpeed > 0) and (I < FModelItems.Count) and FileExists(FModelItems[I]) and
      CalibrationBest(SettingsFile, FModelItems[I], Best, Speed) and (Speed > 0) and (Speed < FLowestSpeed / 10) then
    begin
      Slow := True;
      V := Format('too slow here: %.1fx', [Speed]);
    end;
    if I = cbModel.ItemIndex then
      Sel := Length(Items);
    Items := Items + [TPadMenu.Item(PadShort(T), V)];
    Items[High(Items)].Dim := Slow;
    FPadCmds := FPadCmds + [I];
  end;
  Items := Items + [TPadMenu.Item('Back')];
  FPadCmds := FPadCmds + [PADROW_BACK];
  FPadMode := BPM_MODELS;
  FPadMenu.Show('Model', Items, Sel, 'turbo: the most accurate - base: several times faster, nearly as good');
end;

procedure TfrmBuilder.PadJob(AIndex: Integer);
var
  Items: TArray<TPadMenuItem>;
  Running: Boolean;
begin
  FPadJob := AIndex;
  Running := FJobs[AIndex].State = jsRunning;
  Items := nil;
  FPadCmds := nil;
  Items := Items + [TPadMenu.Item('Show it in the window', 'to check or change')];
  FPadCmds := FPadCmds + [PADROW_SHOW];
  if not Running then
  begin
    if AIndex > 0 then
    begin
      Items := Items + [TPadMenu.Item('Up')];
      FPadCmds := FPadCmds + [PADROW_UP];
    end;
    if AIndex < High(FJobs) then
    begin
      Items := Items + [TPadMenu.Item('Down')];
      FPadCmds := FPadCmds + [PADROW_DOWN];
    end;
    Items := Items + [TPadMenu.Item('Remove')];
    FPadCmds := FPadCmds + [PADROW_REMOVE];
  end;
  Items := Items + [TPadMenu.Item('Back')];
  FPadCmds := FPadCmds + [PADROW_BACK];
  FPadMode := BPM_JOB;
  FPadMenu.Show(JobText(AIndex), Items, 0, ExtractFileName(FJobs[AIndex].Output));
end;

procedure TfrmBuilder.FormShow(Sender: TObject);
begin
  if FShown then
    Exit;
  FShown := True;
  // dark again now the window's controls exist on the screen's side, still
  // before its first frame
  DarkBeforeShow;
  // the pad (and in Big Picture its menu) before the calibration's question,
  // which is asked through it there
  StartPad;
  // once the window is on the screen: the question is centred on it (a
  // method, not an anonymous one: ForceQueue's overloads would not take
  // the anonymous one here - E2250 since zip 148)
  TThread.ForceQueue(nil, AfterShow);
end;

procedure TfrmBuilder.AfterShow;
begin
  // the display it is on (big-screen work, 2026-11-17: numbers first)
  DebugLog(SteamScreenText(Self));
  DecideSleepMode;
  CheckCalibrationAtStart;
end;

procedure TfrmBuilder.DecideSleepMode;
var
  Why: string;
  Pause: Boolean;
begin
  Pause := GameModeSession(Why);
  {$IF Defined(LINUX) and not Defined(ANDROID)}
  if not Pause and SteamBigPicture then
  begin
    Pause := True;
    Why := 'Steam''s Big Picture (' + Why + ')';
  end;
  {$ENDIF}
  InhibitSetPauseForSleep(Pause);
  if InhibitPauseForSleep then
    LogLine('Steam''s Game Mode (' + Why + '): while building, the machine may sleep - the build pauses for ' +
      'it and goes on when the machine wakes (set Steam''s sleep to Never to build unattended).')
  else
    DebugLog('sleep: refused while building (' + Why + ')');
end;

procedure TfrmBuilder.btnCoverClick(Sender: TObject);
begin
  ShowCoverPicker;
end;

procedure TfrmBuilder.ShowCoverPicker;
var
  Book: TEpubBook;
  EpubFile, Note, Title: string;
  BookCover: TBytes;
  Audio: TStringList;
  Options: TCoverOptionArray;
  I: Integer;
begin
  if edBook.Text = '' then
  begin
    Tell('Choose the book first: its covers are shown then.');
    Exit;
  end;
  BookCover := nil;
  Title := FBookTitle;
  try
    EpubFile := BookAsEpub(edBook.Text, Note);
    Book := TEpubBook.Create(EpubFile);
    try
      if Book.CoverPath <> '' then
        BookCover := Book.Zip.ReadBytes(Book.CoverPath);
      if Title = '' then
        Title := Book.Title;
    finally
      Book.Free;
    end;
  except
    on E: Exception do
      WindowLine('The book''s cover could not be read: ' + E.Message);
  end;
  Audio := TStringList.Create;
  try
    for I := 0 to lbAudio.Count - 1 do
      Audio.Add(lbAudio.Items[I]);
    ForceDirectories(FCoverFolder);
    Options := CoverOptions(FCoverFolder, [ChangeFileExt(ExtractFileName(edBook.Text), ''),
      ChangeFileExt(ExtractFileName(edOut.Text), ''), Title], BookCover, Audio);
  finally
    Audio.Free;
  end;
  if FCoverPick = nil then
    if FBigPicture then
      FCoverPick := TCoverPicker.Create(Self, 1.5)
    else
      FCoverPick := TCoverPicker.Create(Self, 1);
  if FPadMenu <> nil then
    FPadMenu.Hide;
  FCoverPick.Show(Format('Cover for %s (pictures in %s are offered too)', [Title, FCoverFolder]),
    'Automatic' + sLineBreak + '(the Covers folder; else the audiobook''s when the book''s is missing or wide)',
    Options, FCoverChoice,
    procedure(const AChoice: string)
    begin
      FCoverChoice := AChoice;
      WindowLine('Cover: ' + CoverChoiceText(AChoice));
      mmBook.Lines.Add('Cover: ' + CoverChoiceText(AChoice));
      if FBigPicture then
        PadHome(BPC_COVER);
    end);
end;

procedure TfrmBuilder.StartLink;
var
  Ini: TMemIniFile;
  Id, Tokens: string;
begin
  Id := '';
  Tokens := '';
  try
    Ini := TMemIniFile.Create(SettingsFile, TEncoding.UTF8);
    try
      // the builder's own id: BookManager knows it again at a new address
      Id := Ini.ReadString('Link', 'Id', '');
      if Id = '' then
      begin
        Id := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '');
        Ini.WriteString('Link', 'Id', Id);
        Ini.UpdateFile;
      end;
      Tokens := Ini.ReadString('Link', 'Paired', '').Replace('|', sLineBreak);
    finally
      Ini.Free;
    end;
  except
    on E: Exception do
      DebugLog('link: the settings: ' + E.Message);
  end;
  try
    FLink := TLinkServer.Create('EpubBuilder', MachineName, Id);
    FLink.SetTokens(Tokens);
    FLink.OnPairCode := LinkPairCode;
    FLink.OnPaired := LinkPaired;
    FLink.OnReceived := LinkReceived;
    FLink.OnPairEnded := LinkPairEnded;
    UpdateLinkFolders;
    LogLine(FLink.Start);
  except
    on E: Exception do
    begin
      FreeAndNil(FLink);
      LogLine('link: not started - ' + E.Message);
    end;
  end;
end;

procedure TfrmBuilder.UpdateLinkFolders;
var
  Outs: TArray<string>;
  I: Integer;
  D: string;

  procedure AddOut(const AFolder: string);
  var
    X: string;
  begin
    if AFolder = '' then
      Exit;
    for X in Outs do
      if SameFileName(ExcludeTrailingPathDelimiter(X), ExcludeTrailingPathDelimiter(AFolder)) then
        Exit;
    Outs := Outs + [AFolder];
  end;

begin
  if FLink = nil then
    Exit;
  Outs := nil;
  AddOut(FOutFolder);
  for I := 0 to High(FJobs) do
  begin
    D := ExtractFileDir(FJobs[I].Output);
    AddOut(D);
  end;
  for D in CardFolders(CARD_TRANSCRIBED) do
    AddOut(D);
  FLink.SetFolders(FBookFolder, FAudioFolder, FCoverFolder, Outs);
end;

procedure TfrmBuilder.UpdateLinkStatus;
var
  O: TJSONObject;
  Title: string;
  Waiting, I: Integer;
begin
  if FLink = nil then
    Exit;
  O := TJSONObject.Create;
  try
    Waiting := 0;
    for I := 0 to High(FJobs) do
      if FJobs[I].State = jsWaiting then
        Inc(Waiting);
    O.AddPair('busy', TJSONBool.Create(FBuild <> nil));
    O.AddPair('queueRunning', TJSONBool.Create(FQueueRunning));
    O.AddPair('waiting', TJSONNumber.Create(Waiting));
    if FBuild <> nil then
    begin
      Title := ChangeFileExt(ExtractFileName(FRunBook), '');
      if (FJob >= 0) and (FJob <= High(FJobs)) then
      begin
        Title := FJobs[FJob].Title;
        O.AddPair('job', TJSONNumber.Create(FJob + 1));
        O.AddPair('jobs', TJSONNumber.Create(Length(FJobs)));
      end;
      O.AddPair('title', Title);
      O.AddPair('percent', TJSONNumber.Create(Round(FPercent * 10) / 10));
      O.AddPair('time', FTimeText);
      O.AddPair('now', FStatusText);
      O.AddPair('speed', TJSONNumber.Create(Round(FSpeedNow * 10) / 10));
    end;
    FLink.SetStatus(O.ToJSON);
  finally
    O.Free;
  end;
end;

procedure TfrmBuilder.LinkPairCode(const AClient, ACode: string);
begin
  WindowLine(Format('%s wants to connect to EpubBuilder. Type this code there: %s (it works for %d minutes).',
    [AClient, ACode, LINK_PAIR_MINUTES]));
  // a bar, not a dialog: it closes by itself (ShowPairing)
  ShowPairing(AClient, ACode);
end;

procedure TfrmBuilder.LinkPairEnded(const AClient, AWhy: string);
begin
  HidePairing(Format('Pairing with %s ended: %s.', [AClient, AWhy]));
end;

procedure TfrmBuilder.LinkPaired(const AClient, AToken: string);
var
  Ini: TMemIniFile;
begin
  HidePairing('');
  LogLine(Format('Paired: %s can now send books and audio and get the books made.', [AClient]));
  try
    Ini := TMemIniFile.Create(SettingsFile, TEncoding.UTF8);
    try
      Ini.WriteString('Link', 'Paired', Trim(FLink.TokensText).Replace(sLineBreak, '|'));
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
  except
    on E: Exception do
      LogLine('The pairing was not kept in the settings: ' + E.Message);
  end;
end;

procedure TfrmBuilder.LinkReceived(const AKind, AFileName: string);
begin
  if AKind = 'book' then
    LogLine('Received a book: ' + AFileName)
  else if AKind = 'cover' then
    LogLine('Received a cover: ' + AFileName + ' (the book of that name gets it when it is built)')
  else
    LogLine('Received audio: ' + AFileName);
end;

procedure TfrmBuilder.tmSleepTimer(Sender: TObject);
const
  { Longest wait for the build to pause before the sleep is let go, ms
    (logind waits 5 s by default). }
  PAUSE_WAIT_MS = 3500;
  { No wake news this long after going to sleep while still running (ms
    of the program's own clock, which stops while asleep): going on. }
  NO_WAKE_MS = 120000;
var
  Busy: string;
  Asleep: TDateTime;
begin
  if not InhibitPauseForSleep then
    Exit;
  try
    if FBuild <> nil then
      Busy := ': pausing the build'
    else if (FCalib <> nil) or (FDownload <> nil) then
      Busy := ' (the calibration or download waits for the wake)'
    else
      Busy := '';
    case InhibitPoll of
      ssGoingToSleep:
        begin
          LogLine('The machine is going to sleep (Steam''s sleep timer, or the power button)' + Busy);
          GSleepGate.ResetEvent;
          FSleepAsked := TThread.GetTickCount64;
          FSleepLet := False;
          FSleepWall := Now;
        end;
      ssWoke:
        begin
          GSleepGate.SetEvent;
          FSleepAsked := 0;
          FSleepLet := False;
          // the time asleep is not the build's
          if (FSleepWall <> 0) and (Now > FSleepWall) then
          begin
            Asleep := Now - FSleepWall;
            if FStarted <> 0 then
              FStarted := FStarted + Asleep;
            if FRatePercent >= 0 then
              FRateFrom := FRateFrom + Asleep;
            if FAfterFrom <> 0 then
              FAfterFrom := FAfterFrom + Asleep;
          end;
          FSleepWall := 0;
          LogLine('The machine woke up' + IfThen(FBuild <> nil, ': the build goes on', '') + ' (' + InhibitText +
            ')');
          FRedraw.Kick('the machine woke up');
        end;
    end;
    if FSleepAsked = 0 then
      Exit;
    // paused, or no build to wait for, or waited long enough: sleep
    if not FSleepLet and ((FBuild = nil) or (TInterlocked.CompareExchange(GBuildPaused, 0, 0) = 1) or
      (TThread.GetTickCount64 - FSleepAsked > PAUSE_WAIT_MS)) then
    begin
      if (FBuild <> nil) and (TInterlocked.CompareExchange(GBuildPaused, 0, 0) = 0) then
        LogLine('The build did not reach a pause in time: the machine sleeps anyway (it goes on after)');
      FSleepLet := True;
      InhibitLetSleep;
      DebugLog('sleep: ' + InhibitText);
    end
    // the wake's news never came (the sleep called off without it?): on
    else if FSleepLet and (TThread.GetTickCount64 - FSleepAsked > NO_WAKE_MS) then
    begin
      LogLine('No news of the machine waking: going on');
      GSleepGate.SetEvent;
      FSleepAsked := 0;
      FSleepLet := False;
    end;
  except
    on E: Exception do
      DebugLog('sleep: ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TfrmBuilder.QueueSleepNote;
var
  FF: TFFmpegLibrary;
  Audio: TWhisperAudioSet;
  Files: TStringList;
  I, K, Unknown: Integer;
  Secs, Len: Double;
  Text: string;
begin
  if not InhibitPauseForSleep then
    Exit;
  Secs := 0;
  Unknown := 0;
  FF := nil;
  Files := TStringList.Create;
  try
    try
      FF := OpenBuilderFFmpeg;
      for I := 0 to High(FJobs) do
        if FJobs[I].State = jsWaiting then
        begin
          Files.Clear;
          for K := 0 to High(FJobs[I].Audio) do
            Files.Add(FJobs[I].Audio[K]);
          Len := 0;
          Audio := TWhisperAudioSet.Create(FF, Files, FJobs[I].Chapters);
          try
            for K := 0 to High(Audio.Parts) do
              Len := Len + Audio.Parts[K].Duration;
          finally
            Audio.Free;
          end;
          PrepareEstimate(FJobs[I].Model, FJobs[I].Device);
          if FExpSpeed > 0 then
            Secs := Secs + Len / FExpSpeed + FExpAfter * Len
          else
            Inc(Unknown);
        end;
    except
      on E: Exception do
      begin
        DebugLog('queue time: ' + E.Message);
        Secs := 0;
      end;
    end;
  finally
    FF.Free;
    Files.Free;
  end;
  if Secs > 0 then
    Text := Format('This queue takes about %s%s.', [HmsText(Secs), IfThen(Unknown > 0,
      Format(' (and %d job(s) with no time to go on)', [Unknown]), '')])
  else
    Text := 'How long this queue takes is not known yet.';
  Text := Text + ' If Steam''s sleep comes on before then, the build pauses while the machine sleeps and goes ' +
    'on when it wakes. To build unattended, set Steam''s sleep to Never (dimming and the screen saver can stay).';
  // Tell: the window's log too, and the pad menu's box in Big Picture
  if FBigPicture then
    Tell(Text)
  else
    LogLine(Text);
end;

procedure TfrmBuilder.OfferCalibration;
var
  Done, DontAsk: Boolean;
  Key, Made: string;
begin
  if (FModelPath = '') or (FWhisperNote <> '') or (Length(FDevices) = 0) then
    Exit;
  if (FBuild <> nil) or (FCalib <> nil) or (FDownload <> nil) or FQueueRunning then
    Exit;
  if CalibrationSummary(SettingsFile, FModelPath) <> '' then
    Exit;
  CalibrationState(SettingsFile, Done, DontAsk, Key, Made);
  if DontAsk then
    Exit;
  // owner, 2026-11-22: a model added later is calibrated as it comes (was
  // a question, zip 201)
  LogLine(ExtractFileName(FModelPath) + ' is not calibrated on this machine yet: calibrating it now (Cancel stops ' +
    'it; Re-calibrate (this model) does it again later).');
  StartCalibration(False, False);
end;

procedure TfrmBuilder.CalibrateNewModels;
begin
  FCalOnlyNew := True;
  try
    StartCalibration(True, False);
  finally
    FCalOnlyNew := False;
  end;
end;

function TfrmBuilder.CalibrationDueAtStart: Boolean;
var
  Done, DontAsk: Boolean;
  Key, Made: string;
begin
  Result := False;
  if (FWhisperNote <> '') or (Length(FDevices) = 0) then
    Exit;
  CalibrationState(SettingsFile, Done, DontAsk, Key, Made);
  if DontAsk then
    Exit;
  Result := not Done or (CalibrationMethod(SettingsFile) < CALIBRATION_METHOD) or
    not SameText(Key, CalibrationDevicesKey(FDevices));
end;

procedure TfrmBuilder.CheckCalibrationAtStart;
var
  Done, DontAsk, Old: Boolean;
  Key, Made, Note, Why, Pick: string;
begin
  if (FWhisperNote <> '') or (Length(FDevices) = 0) then
    Exit;
  // the last run ended while a pair was timed (a GPU runtime that aborts)
  Note := CalibrationCheckMarker(ChangeFileExt(SettingsFile, CALIBRATION_MARKER_SUFFIX), SettingsFile);
  if Note <> '' then
    LogLine(Note);
  CalibrationState(SettingsFile, Done, DontAsk, Key, Made);
  // a calibration of an older method (three runs of 30 s, before zip 242)
  // is out of date: made again, for every model
  Old := Done and (CalibrationMethod(SettingsFile) < CALIBRATION_METHOD);
  if Done and not Old and SameText(Key, CalibrationDevicesKey(FDevices)) then
  begin
    LogLine(Format('Calibrated %s (Settings > Calibration results; Settings > Re-calibrate after a new graphics card ' +
      'or driver).', [Made]));
    if (FModelPath <> '') and (CalibrationSummary(SettingsFile, FModelPath) <> '') then
      LogLine(ExtractFileName(FModelPath) + ': ' + CalibrationSummary(SettingsFile, FModelPath))
    else if FModelPath <> '' then
      LogLine(ExtractFileName(FModelPath) + ' is not calibrated yet: Settings > Re-calibrate times it.');
    Exit;
  end;
  Why := '';
  if Old then
    Why := Format('The calibration has changed since yours of %s: it now times two minutes of speech in one ' +
      'run, which comes much closer to a whole book. Every model here is calibrated again.', [Made]) + sLineBreak +
      sLineBreak
  else if Done then
    Why := Format('The devices have changed since the calibration of %s.', [Made]) + sLineBreak + sLineBreak;
  if DontAsk then
  begin
    LogLine(Why + 'Not calibrated for this machine (you asked not to be reminded): "Default" lets whisper.cpp ' +
      'choose, and it takes the first GPU in its list, not the fastest. Settings > Re-calibrate.');
    Exit;
  end;
  if FModelPath = '' then
  begin
    // the models a Steam depot installed (base and turbo, owner
    // 2026-11-22): turbo, else base, becomes the window's model
    Pick := TPath.Combine(FModelsFolder, BENCH_DETAILED_MODEL);
    if not FileExists(Pick) then
      Pick := TPath.Combine(FModelsFolder, BENCH_QUICK_MODEL);
    if FileExists(Pick) then
    begin
      FModelPath := Pick;
      FillModels;
      SaveSettings;
      UpdateControls;
      LogLine('Model: ' + ModelLabel(ModelShortName(Pick)) + ' (installed with EpubBuilder)');
    end;
  end;
  if FModelPath = '' then
  begin
    // nothing to time yet (a new machine: no model downloaded) - started
    // when one is here (owner, Steam Deck 2026-11-20: the question came
    // with an empty Model list)
    FCalibPending := True;
    LogLine('Not calibrated for this machine yet, and there is no model to calibrate: choose one in Model ' +
      '(turbo is a good first choice; it is downloaded when chosen) - the calibration starts then.');
    Exit;
  end;
  // owner, 2026-11-22: "Big Picture should directly calibrate the models"
  // and the desktop "should be the same as Big Picture" - no question, no
  // dialog: every model here is calibrated now (a line in the log says
  // why; Cancel stops it)
  LogLine(IfThen(Why = '', 'Not calibrated for this machine yet.', Why.Replace(sLineBreak, ' ').Trim));
  // owner, 2026-11-22: an introduction first - why, what was found here,
  // how long it may take; then calibrate now, or close and come back -
  // shown once the window has its size, never before
  IntroWhenSettled(Why);
end;

procedure TfrmBuilder.miCalibrateClick(Sender: TObject);
begin
  // asked for: pairs that ended the program before are tried again
  StartCalibration(False, True);
end;

procedure TfrmBuilder.miCalibrateAllClick(Sender: TObject);
begin
  StartCalibration(True, True);
end;

{ ggml-*.bin of AFolder, smallest first (the quick ones give answers
  early; a large model on the processor comes last). }
function ModelFilesOf(const AFolder: string): TStringList;
var
  Files: TStringDynArray;
  I, J: Integer;
  T: string;
begin
  Result := TStringList.Create;
  Files := TDirectory.GetFiles(AFolder, 'ggml-*.bin');
  for I := 1 to High(Files) do
  begin
    T := Files[I];
    J := I - 1;
    while (J >= 0) and (TFile.GetSize(Files[J]) > TFile.GetSize(T)) do
    begin
      Files[J + 1] := Files[J];
      Dec(J);
    end;
    Files[J + 1] := T;
  end;
  for I := 0 to High(Files) do
    Result.Add(Files[I]);
end;

{ Without expert mode "every model" is the two of MODEL_STANDARD and the
  model in use: takes the others out of AModels.
  @param(AModels  model files (ModelFilesOf))
  @param(AInUse  the model in the window, which stays) }
procedure KeepStandardModels(AModels: TStringList; const AInUse: string);
var
  I: Integer;
begin
  for I := AModels.Count - 1 downto 0 do
    if not ModelIsStandard(ModelShortName(AModels[I])) and not SameFileName(AModels[I], AInUse) then
      AModels.Delete(I);
end;

{ ASeconds in words for the results' table: '45 min', '3 h 05 min', and
  from two days on (ADays) '4 days 11 h'. }
function LongTime(ASeconds: Double; ADays: Boolean): string;
var
  M, H, D: Int64;
begin
  M := Max(Int64(1), Round(ASeconds / 60));
  if M < 60 then
    Exit(Format('%d min', [M]));
  H := M div 60;
  if ADays and (H >= 48) then
  begin
    D := Round(ASeconds / 3600);
    Exit(Format('%d days %d h', [D div 24, D mod 24]));
  end;
  Result := Format('%d h %.2d min', [H, M mod 60]);
end;

{ The number after AKey in AText ('' when none): the digits that follow
  it at once ('i5-' in 'Core i5-8250U' gives '8250'), or with AKey ending
  in a space, the first run of digits after it. }
function DigitsAfter(const AText, AKey: string): string;
var
  P: Integer;
begin
  Result := '';
  P := Pos(AKey, AText);
  if P = 0 then
    Exit;
  P := P + Length(AKey);
  // 'ryzen ': past the tier ('7 ') to the model's digits
  if AKey.EndsWith(' ') then
    while (P <= Length(AText)) and not ((AText[P] >= '0') and (AText[P] <= '9') and (P + 1 <= Length(AText)) and
      (AText[P + 1] >= '0') and (AText[P + 1] <= '9')) do
      Inc(P);
  while (P <= Length(AText)) and (AText[P] >= '0') and (AText[P] <= '9') do
  begin
    Result := Result + AText[P];
    Inc(P);
  end;
end;

{ A rough guess at a model's speed (x real time) on ADevice before any
  calibration, for the introduction's estimate, from the surveys of
  machines (CLAUDE.md, 2026-11-21/22). large-v3-turbo: on the processor a
  sixteenth of its threads (the Miix's 8 of a 2017 i5-8250U: 0.5x), three
  times that for a recent one (Core Ultra, Core i 12th generation on,
  Ryzen 7000 on), twice for the others (owner, 2026-11-22: the first
  version said 7 min for a 1:15 calibration); Apple's Metal 20x; an RTX
  30 / 40 / 50 card 40x (the 5090: 83x), another card 15x (a GTX 1650:
  15x); Intel's UHD / HD 0.7x (the Miix: 0.6x), Iris 2x, its newer
  graphics (Arc, "Intel(R) Graphics") 6x; AMD's integrated graphics 8x (a
  Steam Deck 7.9x, the Ally 16.7x). A smaller model is faster: by the
  square root of the size ratio on graphics, by the whole ratio on the
  processor (base: 8.6x / 6.7x on the Miix).
  Tuned on the six machines' logs of 2026-11-22 (guess -> timed, turbo):
  Apple's processor is as fast as its graphics (M4: 1.9x -> 23.9x; base
  81.6x), so 15x and the square root for smaller models; a Core i of the
  10th or 11th generation is no 2017 one (i5-11320H, 8 threads: 0.5x ->
  1.3x), so twice a sixteenth of its threads; Iris 3x (Iris Xe: 2x ->
  4.0x). Left as they were, the calibration being short on them anyway:
  an RTX card (the 5090: 98.9x), another card (Steam Machine 36.8x, GTX
  1650 14.0x), AMD's integrated graphics (Ally 16.2x, Deck 7.3x). }
function GuessSpeed(const ADevice: TWhisperDevice; ASizeMB: Double): Double;
const
  { large-v3-turbo's file, MB: the sizes are compared with it. }
  TURBO_MB = 1549;
var
  D, N: string;
  Turbo, Gen: Double;
begin
  ASizeMB := Max(ASizeMB, 1);
  D := ' ' + LowerCase(ADevice.Description + ' ' + ADevice.Name) + ' ';
  if ADevice.DeviceType = wdtCPU then
  begin
    // Apple silicon: its processor keeps up with its graphics
    if Pos('apple', D) > 0 then
      Exit(15 * Sqrt(TURBO_MB / ASizeMB));
    Gen := 2;
    if Pos('ultra', D) > 0 then
      Gen := 3
    else
    begin
      N := DigitsAfter(D, 'i3-') + DigitsAfter(D, 'i5-') + DigitsAfter(D, 'i7-') + DigitsAfter(D, 'i9-');
      // Core i: the generation is the first digit, or two of five (10th
      // and 11th: 2, as the processors not known)
      if (Length(N) >= 5) and (StrToIntDef(Copy(N, 1, 2), 0) >= 12) then
        Gen := 3
      else if Length(N) = 4 then
        Gen := 1;
      N := DigitsAfter(D, 'ryzen ');
      if Length(N) = 4 then
      begin
        if N[1] >= '7' then
          Gen := 3
        else if N[1] <= '3' then
          Gen := 1;
      end;
    end;
    Exit(Max(0.2, TThread.ProcessorCount / 16 * Gen) * TURBO_MB / ASizeMB);
  end;
  if SameText(ADevice.Backend, 'Metal') or StartsText('MTL', ADevice.Name) then
    Turbo := 20
  else if ADevice.DeviceType = wdtGPU then
  begin
    N := DigitsAfter(D, 'rtx ');
    if (Length(N) = 4) and (N[1] >= '3') then
      Turbo := 40
    else
      Turbo := 15;
  end
  else if Pos('intel', D) > 0 then
  begin
    if (Pos('uhd', D) > 0) or (Pos(' hd graphics', D) > 0) then
      Turbo := 0.7
    else if Pos('iris', D) > 0 then
      Turbo := 3
    else
      Turbo := 6;
  end
  else
    Turbo := 8;
  Result := Turbo * Sqrt(TURBO_MB / ASizeMB);
end;

function TfrmBuilder.CalibrationGuess(out ACard: Boolean; ALog: Boolean): Double;
const
  { Reading the recording and choosing its stretch, seconds (the logs of
    2026-11-22: 2 s or less on every machine; was 20). }
  START_SECONDS = 5;
  { The warm-up, as seconds of speech (a whole 30 s window is encoded
    even for its 5 s: the Miix's turbo warm-up took 47 s at 0.5x). }
  WARMUP_SECONDS = 25;
  { Loading a model, MB a second (the logs of 2026-11-22: turbo's 1549 MB
    in 0.2 - 1.2 s; was 400). }
  LOAD_MB_S = 1000;
var
  Models: TStringList;
  I, K: Integer;
  Speed, MB: Double;
begin
  Result := 0;
  ACard := False;
  for K := 0 to High(FDevices) do
    if (FDevices[K].DeviceType = wdtGPU) or SameText(FDevices[K].Backend, 'Metal') then
      ACard := True;
  if FModelPath = '' then
    Exit;
  // the models StartCalibration(True, ...) times, on every device
  Models := ModelFilesOf(ExtractFileDir(FModelPath));
  try
    if not FExpert then
      KeepStandardModels(Models, FModelPath);
    Result := START_SECONDS;
    for I := 0 to Models.Count - 1 do
    begin
      MB := TFile.GetSize(Models[I]) / 1048576;
      for K := 0 to High(FDevices) do
      begin
        // an earlier calibration's figure (a re-calibration), else a guess
        Speed := CalibrationSpeed(SettingsFile, Models[I], FDevices[K].Name);
        if Speed <= 0 then
        begin
          Speed := GuessSpeed(FDevices[K], MB);
          if ALog then
            DebugLog(Format('calibration: guessed %.1fx for %s on %s', [Speed, ExtractFileName(Models[I]),
              WhisperDeviceText(FDevices[K])]));
        end;
        Result := Result + MB / LOAD_MB_S + (WARMUP_SECONDS + CALIBRATION_STRETCH_SECONDS) / Max(Speed, 0.05);
      end;
    end;
  finally
    Models.Free;
  end;
end;

procedure TfrmBuilder.StartIntroTimer;
begin
  if tmIntro = nil then
  begin
    tmIntro := TTimer.Create(Self);
    tmIntro.Interval := 100;
    tmIntro.OnTimer := tmIntroTimer;
  end;
  tmIntro.Enabled := True;
end;

procedure TfrmBuilder.IntroWhenSettled(const AWhy: string);
begin
  if FPadMenu = nil then
  begin
    // no menu to ask with: ShowCalibrationIntro calibrates straight away
    ShowCalibrationIntro(AWhy);
    Exit;
  end;
  FCalIntroWhy := AWhy;
  FIntroWait := True;
  FIntroW := ClientWidth;
  FIntroH := ClientHeight;
  FIntroTick := TThread.GetTickCount64;
  StartIntroTimer;
end;

procedure TfrmBuilder.FormResized(Sender: TObject);
begin
  if not FIntroWait and not (FCalIntro and (FPadMode = BPM_ASK)) then
    Exit;
  // counted from now: shown once it has stopped changing
  FIntroW := ClientWidth;
  FIntroH := ClientHeight;
  FIntroTick := TThread.GetTickCount64;
  StartIntroTimer;
end;

procedure TfrmBuilder.tmIntroTimer(Sender: TObject);
var
  First: Boolean;
begin
  if not FIntroWait and not (FCalIntro and (FPadMode = BPM_ASK)) then
  begin
    tmIntro.Enabled := False;
    Exit;
  end;
  // a size no resize event told of: waited for as well
  if (ClientWidth <> FIntroW) or (ClientHeight <> FIntroH) then
  begin
    FIntroW := ClientWidth;
    FIntroH := ClientHeight;
    FIntroTick := TThread.GetTickCount64;
    Exit;
  end;
  if TThread.GetTickCount64 - FIntroTick < INTRO_SETTLE_MS then
    Exit;
  // macOS, Big Picture: the full screen comes through Cocoa a few seconds
  // after the start (tmPadTimer) - not before that is there or given up
  if FIntroWait and PAD_FULL_AGAIN and FBigPicture and (FFullTries < PAD_FULL_TRIES) then
    Exit;
  tmIntro.Enabled := False;
  First := FIntroWait;
  FIntroWait := False;
  if First then
    DebugLog(Format('calibration: the introduction shown, the window %d x %d', [ClientWidth, ClientHeight]));
  ShowCalibrationIntro(FCalIntroWhy);
  // the whole window drawn (Linux: what a changed page left behind)
  Invalidate;
end;

procedure TfrmBuilder.ShowCalibrationIntro(const AWhy: string);
const
  { Up to this, "a few minutes"; above it, a warning (seconds). }
  FEW_MINUTES = 10 * 60;

  { An answer with its button on the left: Steam's picture of it on the
    pad in hand, else (the keyboard, or no picture) its name on the
    right. }
  function IntroRow(const AText: string; AButton: Integer): TPadMenuItem;
  var
    Hints: TArray<TPadHint>;
  begin
    Result := TPadMenu.Item(AText);
    Hints := PadHintsFor([AButton], [''], FPadKeys);
    if Length(Hints) = 0 then
      Exit;
    // on the left either way (owner, 2026-11-22: the key on the right was
    // "on the wrong side")
    if Hints[0].Glyph <> '' then
      Result.Glyphs := [Hints[0].Glyph]
    else
      Result.Key := Hints[0].Name;
  end;

var
  Items: TArray<TPadMenuItem>;
  Text, Kind: string;
  T: Double;
  K: Integer;
  Card: Boolean;
begin
  if FPadMenu = nil then
  begin
    // no menu to ask with: as before - calibrated now
    StartCalibration(True, False);
    FCalAtStart := FCalib <> nil;
    Exit;
  end;
  T := CalibrationGuess(Card, not FCalIntroLogged);
  if not FCalIntroLogged then
    DebugLog(Format('calibration: the introduction''s estimate %.0f s (%s)', [T, IfThen(Card, 'a graphics card',
      'no graphics card')]));
  FCalIntroLogged := True;
  Text := AWhy + 'EpubBuilder first needs to calibrate itself to this machine: how fast it turns speech into ' +
    'text depends greatly on the processor (CPU) and the graphics (GPU), so each model is timed once on each of ' +
    'them, to find the fastest.' + sLineBreak + sLineBreak + 'Found here:';
  for K := 0 to High(FDevices) do
  begin
    case FDevices[K].DeviceType of
      wdtCPU: Kind := Format('processor, %d threads', [TThread.ProcessorCount]);
      wdtIGPU: Kind := 'integrated graphics';
      wdtGPU: Kind := 'graphics card';
    else
      Kind := FDevices[K].Backend;
    end;
    Text := Text + sLineBreak + Format('- %s - %s (%s)', [FDevices[K].Name, FDevices[K].Description, Kind]);
  end;
  Text := Text + sLineBreak + sLineBreak;
  if T <= FEW_MINUTES then
    Text := Text + Format('On this hardware it should take a few minutes (roughly %s).', [LongTime(T, True)])
  else if not Card then
    Text := Text + Format('Owing to this hardware (no separate graphics card) calibration may take some time: ' +
      'roughly %s. It can be left to run.', [LongTime(T, True)])
  else
    Text := Text + Format('Owing to this hardware calibration may take some time: roughly %s. It can be left to ' +
      'run.', [LongTime(T, True)]);
  // owner, 2026-11-22: "[A] proceed to Calibration or [B] Come back when
  // I have more time to spare - A starts calibration, B exits the
  // program" (the buttons are shown as the pad in hand draws them)
  // each with its button: Steam's picture with a pad, the key's name with
  // the keyboard (owner, 2026-11-22: "Button Glyphs must be used!")
  Items := [IntroRow('Calibrate now', BP_CHOOSE), IntroRow('Come back when I have more time to spare', BP_BACK)];
  FPadCmds := [PADROW_NONE, PADROW_NONE];
  FCalIntro := True;
  FCalIntroWhy := AWhy;
  FAskResults := [mrYes, mrNo];
  FAskCancel := mrNo;
  FPairPad := False;
  // the menu does not come back by itself after the answer (the answer
  // says where to go)
  FAskThenClose := True;
  FAskProc :=
    procedure(const AResult: TModalResult)
    begin
      FCalIntro := False;
      if AResult = mrYes then
      begin
        LogLine('Calibrating every model here now: which device is fastest for each (Cancel stops it, ' +
          'Settings > Re-calibrate does it again later).');
        StartCalibration(True, False);
        // owner, 2026-11-22: after it, the main menu (CalibrationDone)
        FCalAtStart := FCalib <> nil;
        if FCalib = nil then
          PadBackToMenu(False);
      end
      else
      begin
        LogLine('Calibration put off: EpubBuilder closes (it asks again at the next start).');
        Close;
      end;
    end;
  FPadMode := BPM_ASK;
  FPadMenu.NextTitleCentered := True;
  // owner, 2026-11-22: wider - both answers under the text without
  // scrolling ("80%", then 17:25 "No - make that 60%")
  FPadMenu.NextWidthShare := 0.6;
  FPadMenu.ShowText('Calibration', Text, Items, 0, PadFootOf([BP_CHOOSE, BP_BACK], ['choose',
    'come back later']));
  RefreshFoot;
end;

procedure TfrmBuilder.miDiagnosticsClick(Sender: TObject);
begin
  StartDiagnostics(False);
end;

procedure TfrmBuilder.miDiagnosticsAllClick(Sender: TObject);
begin
  StartDiagnostics(True);
end;

const
  { The folder beside the settings that a benchmark's book and log go to
    (the book until the user keeps it), with BENCH_RESULTS_FILE. }
  BENCH_FOLDER = 'Benchmarks';
  { Every benchmark's score, a line per run (for the leaderboard to come;
    not mentioned to the user). }
  BENCH_RESULTS_FILE = 'benchmarks.csv';
  { The Benchmark menu's options (owner, 2026-11-22; "Short Text, Fast
    Model" since zip 239, was "Short + Fast"). }
  BENCH_NAMES: array[0..4] of string = ('Run all 4 benchmarks', 'Short Text, Fast Model',
    'Short Text, Detailed Model', 'Long Text, Fast Model', 'Long Text, Detailed Model');
  { Each option's reference text: Short = BENCHMARK_LITE_REFERENCE, Long
    = BENCHMARK_FULL_REFERENCE. }
  BENCH_REFS: array[1..4] of Integer = (BENCHMARK_LITE_REFERENCE, BENCHMARK_LITE_REFERENCE,
    BENCHMARK_FULL_REFERENCE, BENCHMARK_FULL_REFERENCE);
  { Each option's model: Detailed = BENCH_DETAILED_MODEL (turbo), Fast =
    BENCH_QUICK_MODEL (base). }
  BENCH_DETAILED: array[1..4] of Boolean = (False, True, False, True);

  { The benchmarks' leaderboards in Steamworks (uSteamBoard makes each
    with the first score sent to it; their names for people are set on
    the partner site). }
  BOARD_NAMES: array[1..4] of string = ('benchmark_short_fast', 'benchmark_short_detailed',
    'benchmark_long_fast', 'benchmark_long_detailed');
  { A leaderboard's page: this share of the window's width and of its
    height (owner, 2026-11-23); it shows as many rows as fit. }
  BOARD_WIDTH_SHARE = 0.95;
  { Its frame, dark and light: the benchmarks' yellow (uBenchProgress's
    FRAME_DARK and FRAME_LIGHT). }
  BOARD_FRAME_DARK = TAlphaColor($FFE8C547);
  { The same on the light menu (a darker yellow). }
  BOARD_FRAME_LIGHT = TAlphaColor($FFC99A06);
  { The layout of the numbers sent beside a score (BoardDetails). }
  BOARD_FORMAT = 1;
  { Where the device's description starts in them. }
  BOARD_DEVICE_AT = 4;
  { The numbers the description may take (four characters each). }
  BOARD_DEVICE_NUMBERS = 12;

{ APlace as "1st", "2nd", "3rd", "4th", "11th", "22nd". }
function PlaceText(APlace: Integer): string;
begin
  if (APlace mod 100 >= 11) and (APlace mod 100 <= 13) then
    Result := 'th'
  else
    case APlace mod 10 of
      1: Result := 'st';
      2: Result := 'nd';
      3: Result := 'rd';
    else
      Result := 'th';
    end;
  Result := IntToStr(APlace) + Result;
end;

{ A benchmark's score: ASeconds as H:MM:SS.mmm. }
function BenchScore(ASeconds: Double): string;
var
  Ms: Int64;
begin
  Ms := Round(ASeconds * 1000);
  Result := Format('%d:%.2d:%.2d.%.3d', [Ms div 3600000, (Ms div 60000) mod 60, (Ms div 1000) mod 60,
    Ms mod 1000]);
end;

function TfrmBuilder.BenchmarkModel(AOption: Integer): string;
begin
  if AOption = 0 then
  begin
    // Run all: a model that is here (base first)
    Result := BenchmarkModel(1);
    if Result = '' then
      Result := BenchmarkModel(2);
    Exit;
  end;
  if BENCH_DETAILED[AOption] then
    Result := TPath.Combine(FModelsFolder, BENCH_DETAILED_MODEL)
  else
    Result := TPath.Combine(FModelsFolder, BENCH_QUICK_MODEL);
  if (FModelsFolder = '') or not FileExists(Result) then
    Result := '';
end;

function TfrmBuilder.BenchmarkDevice(const AModel: string): string;
var
  Best: string;
  Own: TWhisperDevice;
  Speed: Double;
begin
  Result := '';
  if (cbDevice.ItemIndex > 0) and (cbDevice.ItemIndex - 1 <= High(FDevices)) then
    Result := FDevices[cbDevice.ItemIndex - 1].Name;
  if Result = '' then
    Result := GDefaultDevice;
  if CalibrationBest(SettingsFile, AModel, Best, Speed) and BuilderFindDevice(Best, Own) then
    Result := Own.Name;
end;

function TfrmBuilder.BenchTooSlow(AOption: Integer; out AWhy: string): Boolean;
var
  I: Integer;
  Model: string;
begin
  Result := False;
  AWhy := '';
  for I := 1 to 4 do
    if (AOption = 0) or (AOption = I) then
    begin
      Model := BenchmarkModel(I);
      if (Model <> '') and TooSlow(Model, BenchmarkDevice(Model), AWhy) then
      begin
        if AOption = 0 then
          AWhy := 'No benchmark can run here: no model in the models folder is fast enough on this machine.' +
            sLineBreak + sLineBreak + AWhy
        else
          AWhy := BENCH_NAMES[I] + ' cannot run here.' + sLineBreak + sLineBreak + AWhy;
        Exit(True);
      end;
    end;
end;

procedure TfrmBuilder.BenchAvailability;
var
  I: Integer;
  Why: string;
  Fast, Detailed: Boolean;
begin
  // the two models' calibrations, once each (the ini file is read for
  // each)
  Fast := (BenchmarkModel(1) <> '') and not BenchTooSlow(1, Why);
  Detailed := (BenchmarkModel(2) <> '') and not BenchTooSlow(2, Why);
  for I := 1 to 4 do
    if BENCH_DETAILED[I] then
      FBenchCan[I] := Detailed
    else
      FBenchCan[I] := Fast;
end;

function TfrmBuilder.BenchRunning: Boolean;
begin
  Result := (FBenchOption >= 1) or (Length(FBenchQueue) > 0);
end;

function TfrmBuilder.BenchCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to 4 do
    if FBenchCan[I] then
      Inc(Result);
end;

function TfrmBuilder.BenchName(AOption: Integer): string;
begin
  Result := BENCH_NAMES[AOption];
  // none can run: the full name, faded
  if (AOption = 0) and (BenchCount > 0) then
    Result := Format('Run all %d benchmarks', [BenchCount]);
end;

procedure TfrmBuilder.RefreshBenchmarks;
var
  Busy, Changed: Boolean;
  Key, Model, Dev, DevKey, Source, Audio: string;
  I, R: Integer;
  Hist: TBuildHistory;
  D: TWhisperDevice;
  Speed, After, Prior, Len: Double;
  FF: TFFmpegLibrary;
  Files: TStringList;
  AudioSet: TWhisperAudioSet;
begin
  if miBench[0] = nil then
    Exit;
  Busy := (FBuild <> nil) or FQueueRunning or (FCalib <> nil) or (FDownload <> nil);
  Changed := False;
  // which can run here: model there, not below the lowest acceptable speed
  BenchAvailability;
  // what the estimates and the names come from: the models, their
  // calibrations, the build history, the window's device, how many can run
  Key := BenchmarkModel(1) + '|' + BenchmarkModel(2) + '|' + CalibrationSummary(SettingsFile, BENCH_QUICK_MODEL) +
    '|' + CalibrationSummary(SettingsFile, BENCH_DETAILED_MODEL) + '|' + IntToStr(cbDevice.ItemIndex) + '|' +
    IntToStr(BenchCount);
  if FileExists(HistoryFile) then
    Key := Key + '|' + FloatToStr(TFile.GetLastWriteTime(HistoryFile));
  // not while something runs (the recordings are read, the history too)
  if (Key <> FBenchKey) and not Busy and (FWhisperNote = '') then
  begin
    FBenchKey := Key;
    Changed := True;
    try
      // the recordings' lengths, once
      if (FBenchAudio[0] = 0) or (FBenchAudio[1] = 0) then
      begin
        FF := nil;
        Files := TStringList.Create;
        try
          FF := OpenBuilderFFmpeg;
          for R := 0 to High(FBenchAudio) do
            if FBenchAudio[R] = 0 then
            begin
              Audio := FindReferenceFile(REFERENCE_TEXTS[R].Audio);
              if Audio = '' then
                Continue;
              Files.Clear;
              Files.Add(Audio);
              AudioSet := TWhisperAudioSet.Create(FF, Files, False);
              try
                if Length(AudioSet.Parts) > 0 then
                  FBenchAudio[R] := AudioSet.Parts[0].Duration;
              finally
                AudioSet.Free;
              end;
            end;
        finally
          FF.Free;
          Files.Free;
        end;
      end;
      // each option as a build of the model is expected to take
      // (PrepareEstimate's sources, without touching the running build's)
      Hist := HistoryLoad(HistoryFile);
      for I := 1 to 4 do
      begin
        FBenchEta[I] := 0;
        Model := BenchmarkModel(I);
        Len := FBenchAudio[BENCH_REFS[I]];
        if (Model = '') or (Len <= 0) then
          Continue;
        Dev := BenchmarkDevice(Model);
        if BuilderFindDevice(Dev, D) then
          Dev := D.Name;
        DevKey := Dev;
        if UsesCoreML(Model) then
          DevKey := Dev + '+CoreML';
        if HistoryExpect(Hist, HistoryMachine(MachineText), ExtractFileName(Model), DevKey,
          CalibrationSpeed(SettingsFile, Model, Dev), CalibrationSeconds(SettingsFile, Model), Speed, After, Prior,
          Source) and (Speed > 0) then
          FBenchEta[I] := Len / Speed + After * Len;
      end;
      // Run all: those that can run here, when each has a time
      FBenchEta[0] := 0;
      for I := 1 to 4 do
        if FBenchCan[I] then
        begin
          if FBenchEta[I] <= 0 then
          begin
            FBenchEta[0] := 0;
            Break;
          end;
          FBenchEta[0] := FBenchEta[0] + FBenchEta[I];
        end;
    except
      on E: Exception do
        DebugLog('benchmark estimates: ' + E.Message);
    end;
  end;
  for I := 0 to High(miBench) do
  begin
    // no model, or below Settings > Lowest acceptable speed: faded, says
    // why when chosen; Run all: as long as one can run
    if I = 0 then
      miBench[I].Enabled := not Busy and (FWhisperNote = '') and (BenchCount > 0)
    else
      miBench[I].Enabled := not Busy and (FWhisperNote = '') and FBenchCan[I];
    if Changed then
      miBench[I].Text := BenchmarkText(I);
  end;
  // new text reaches Windows' / macOS' own menu bar when it is made again
  if Changed and (mnuMain <> nil) and (mnuMain.Parent <> nil) then
    mnuMain.RecreateOSMenu;
end;

function TfrmBuilder.BenchmarkText(AOption: Integer): string;
begin
  Result := BenchName(AOption);
  if FBenchEta[AOption] > 0 then
    Result := Result + ' - about ' + HmsText(FBenchEta[AOption]);
end;

procedure TfrmBuilder.miBenchmarkClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    StartBenchmark(TMenuItem(Sender).Tag);
end;

procedure TfrmBuilder.StartBenchmark(AOption: Integer);
var
  I: Integer;
  Titles: TArray<string>;
  Why: string;
begin
  if (AOption < 0) or (AOption > High(BENCH_NAMES)) then
    Exit;
  if (FBuild <> nil) or (FCalib <> nil) or (FDownload <> nil) or FQueueRunning then
  begin
    Tell('A build, a calibration or a download is running: run the benchmark when it has ended.');
    Exit;
  end;
  if (FWhisperNote <> '') or (Length(FDevices) = 0) then
  begin
    Tell('whisper.cpp is not available: there is nothing to benchmark.');
    Exit;
  end;
  if BenchmarkModel(AOption) = '' then
  begin
    if AOption = 0 then
      Tell('The benchmarks need the models base and large-v3-turbo: choose each in the Model list to download ' +
        'it.')
    else
      Tell(Format('%s needs the model %s: choose it in the Model list to download it.', [BENCH_NAMES[AOption],
        IfThen(BENCH_DETAILED[AOption], 'large-v3-turbo', 'base')]));
    Exit;
  end;
  // Run all: those that can run here; none - why not
  BenchAvailability;
  if ((AOption = 0) and (BenchCount = 0) and BenchTooSlow(0, Why)) or ((AOption > 0) and BenchTooSlow(AOption,
    Why)) then
  begin
    Tell(Why);
    Exit;
  end;
  FBenchAll := AOption = 0;
  FBenchQueue := nil;
  if FBenchAll then
  begin
    for I := 1 to 4 do
      if FBenchCan[I] then
        FBenchQueue := FBenchQueue + [I];
  end
  else
    FBenchQueue := [AOption];
  if Length(FBenchQueue) = 0 then
    Exit;
  for I := 1 to 4 do
  begin
    FBenchScores[I] := 0;
    FBenchBooks[I] := '';
    FBenchEnded[I] := False;
    FBoardMs[I] := 0;
    FBoardDetails[I] := nil;
    FBoardState[I] := 0;
    FBenchClock[I] := 0;
    FBenchPct[I] := 0;
  end;
  FBenchList := Copy(FBenchQueue);
  // owner, 2026-11-22: a bar per benchmark over the window - its name,
  // its text and the device it runs on above it
  Titles := nil;
  for I := 0 to High(FBenchList) do
    Titles := Titles + [BenchTitle(FBenchList[I])];
  FreeAndNil(FBenchView);
  FBenchView := TBenchProgress.Create(Self, Titles, FPadDark, not FBigPicture);
  FBenchView.OnTick := BenchTick;
  FBenchView.OnButton := BenchCancel;
  BenchTick(nil);
  mmLog.Lines.Clear;
  // Run all with fewer than four: which are left out, and why
  if FBenchAll then
    for I := 1 to 4 do
      if not FBenchCan[I] then
        if BenchmarkModel(I) = '' then
          LogLine(Format('Not run here: %s - the model %s is not in the models folder.', [BENCH_NAMES[I],
            IfThen(BENCH_DETAILED[I], 'large-v3-turbo', 'base')]))
        else
          LogLine(Format('Not run here: %s - its model is below Settings > Lowest acceptable speed (%.1fx).',
            [BENCH_NAMES[I], FLowestSpeed / 10]));
  RunNextBenchmark;
end;

procedure TfrmBuilder.RunNextBenchmark;
var
  Option: Integer;
begin
  if Length(FBenchQueue) = 0 then
    Exit;
  Option := FBenchQueue[0];
  Delete(FBenchQueue, 0, 1);
  RunBenchmark(Option);
  if FBuild = nil then
  begin
    // not started (said why): the rest not either
    FBenchQueue := nil;
    BenchmarkFinished;
  end;
end;

procedure TfrmBuilder.RunBenchmark(AOption: Integer);
var
  Job: TBuildJob;
  Ref: Integer;
  Audio, Book, Model: string;
begin
  if (FBuild <> nil) or (FCalib <> nil) or (FDownload <> nil) or FQueueRunning then
    Exit;
  Ref := BENCH_REFS[AOption];
  Model := BenchmarkModel(AOption);
  Audio := FindReferenceFile(REFERENCE_TEXTS[Ref].Audio);
  Book := FindReferenceFile(REFERENCE_TEXTS[Ref].Book);
  if (Model = '') or (Audio = '') or (Book = '') then
  begin
    Tell(Format('%s cannot start: its files are missing (%s/%s, %s/%s).', [BENCH_NAMES[AOption],
      REFERENCE_FOLDER, REFERENCE_TEXTS[Ref].Audio, REFERENCE_FOLDER, REFERENCE_TEXTS[Ref].Book]));
    Exit;
  end;
  Job := Default(TBuildJob);
  Job.Book := Book;
  Job.Title := REFERENCE_TEXTS[Ref].Title;
  Job.Audio := [Audio];
  Job.Model := Model;
  Job.Device := BenchmarkDevice(Model);
  // beside the settings until the user keeps it
  Job.Output := TPath.Combine(TPath.Combine(ExtractFileDir(SettingsFile), BENCH_FOLDER),
    Format('%s (%s).epub', [REFERENCE_TEXTS[Ref].Title, BENCH_NAMES[AOption]]));
  // a LibriVox book's sections are its file's chapters: parts
  Job.Chapters := True;
  Job.Reuse := False;
  Job.Language := 'en';
  Job.State := jsWaiting;
  FBenchOption := AOption;
  LogLine('');
  if FBenchAll then
    LogLine(Format('=== Benchmark %d of %d: %s (%s) ===', [Length(FBenchList) - Length(FBenchQueue),
      Length(FBenchList), BENCH_NAMES[AOption],
      FormatDateTime('yyyy-mm-dd hh:nn', Now)]))
  else
    LogLine(Format('=== Benchmark: %s (%s) ===', [BENCH_NAMES[AOption], FormatDateTime('yyyy-mm-dd hh:nn',
      Now)]));
  StartJob(Job, -1, True);
  if FBuild = nil then
    FBenchOption := -1;
end;

procedure TfrmBuilder.BenchmarkDone(const ASummary: TBuildSummary; AOk: Boolean);
var
  Option: Integer;
  OutFile: string;
  W: TStreamWriter;
  NewCsv: Boolean;
begin
  Option := FBenchOption;
  FBenchOption := -1;
  OutFile := FRunOut;
  if (Option < 1) or (Option > 4) then
    Exit;
  FBenchEnded[Option] := True;
  if AOk and (ASummary.BenchSeconds > 0) then
  begin
    FBenchScores[Option] := ASummary.BenchSeconds;
    FBenchBooks[Option] := OutFile;
    LogLine(Format('Score - %s: %s', [BENCH_NAMES[Option], BenchScore(ASummary.BenchSeconds)]));
    // for its leaderboard (BoardSend, once the run has ended)
    FBoardMs[Option] := Round(ASummary.BenchSeconds * 1000);
    FBoardDetails[Option] := BoardDetails(ASummary);
    // every run, kept here too
    try
      NewCsv := not FileExists(TPath.Combine(ExtractFileDir(OutFile), BENCH_RESULTS_FILE));
      // appended to: the encoding's preamble only in a new file
      W := TStreamWriter.Create(TPath.Combine(ExtractFileDir(OutFile), BENCH_RESULTS_FILE), True, TEncoding.UTF8);
      try
        if NewCsv then
          W.WriteLine('Date,Benchmark,Score,Transcription s,Chapter material s,Words,Words matched,Model,Device,' +
            'Device text,Build');
        W.WriteLine(string.Join(',', [CsvText(FormatDateTime('yyyy-mm-dd hh:nn', Now)),
          CsvText(BENCH_NAMES[Option]), CsvText(BenchScore(ASummary.BenchSeconds)),
          FormatFloat('0.000', ASummary.BenchSeconds, TFormatSettings.Invariant),
          FormatFloat('0.0', ASummary.BenchAudioSeconds, TFormatSettings.Invariant),
          IntToStr(ASummary.BenchWords), IntToStr(ASummary.BenchMatched), CsvText(ASummary.Model),
          CsvText(ASummary.Device), CsvText(ASummary.DeviceText), CsvText(BuildStamp)]));
      finally
        W.Free;
      end;
    except
      on E: Exception do
        DebugLog('benchmark score not kept: ' + E.Message);
    end;
  end
  else
  begin
    // the rest of Run all is not run
    FBenchQueue := nil;
    if FCancelled then
      LogLine('Benchmark cancelled.')
    else
      LogLine('The benchmark did not finish, so it has no score (the log above says why).');
    try
      if FileExists(OutFile) then
        TFile.Delete(OutFile);
    except
      // left beside the settings; the next run of it replaces it
    end;
  end;
  // the next of Run all once this build has finished, else the scores
  if Length(FBenchQueue) > 0 then
    TThread.ForceQueue(nil, RunNextBenchmark)
  else
    BenchmarkFinished;
end;

procedure TfrmBuilder.BenchmarkFinished;
var
  I, N: Integer;
  AnyDetailed: Boolean;
begin
  N := 0;
  FBenchKeep := nil;
  FBenchCandidates := nil;
  FBenchFastOffered := False;
  // Run all without the Detailed model (missing, too slow): the Fast books
  // are the ones to keep
  AnyDetailed := False;
  for I := 1 to 4 do
    if BENCH_DETAILED[I] and (FBenchScores[I] > 0) and (FBenchBooks[I] <> '') then
      AnyDetailed := True;
  for I := 1 to 4 do
    if FBenchScores[I] > 0 then
    begin
      Inc(N);
      if FBenchBooks[I] <> '' then
      begin
        FBenchKeep := FBenchKeep + [FBenchBooks[I]];
        // Run all: the Detailed books, the better ones of each text
        if not FBenchAll or BENCH_DETAILED[I] or not AnyDetailed then
        begin
          FBenchCandidates := FBenchCandidates + [FBenchBooks[I]];
          FBenchFastOffered := FBenchFastOffered or not BENCH_DETAILED[I];
        end;
      end;
    end;
  FBenchAll := False;
  // the bars as they ended, behind the results
  BenchTick(nil);
  if N = 0 then
  begin
    FreeAndNil(FBenchView);
    if not FCancelled then
      Tell('The benchmark did not finish, so there is no score.');
    Exit;
  end;
  FBenchResults := True;
  FBenchHidden := False;
  FBenchSel := -1;
  if FBenchView <> nil then
    FBenchView.SetButtonText('Hide results');
  // the scores to their leaderboards (Settings > Leaderboard), then the
  // table
  BoardSend;
  BenchShowResults;
end;

function TfrmBuilder.BoardDetails(const ASummary: TBuildSummary): TArray<Integer>;
var
  Dev: string;
  P: Integer;
  Packed4: TArray<Integer>;
begin
  // 'Vulkan0 - NVIDIA GeForce RTX 5090 Laptop GPU (GPU, Vulkan, 22.7 of
  // 23.6 GB free)': the description alone
  Dev := ASummary.DeviceText;
  P := Pos(' - ', Dev);
  if P > 0 then
    Dev := Copy(Dev, P + 3, MaxInt);
  P := Dev.LastIndexOf(' (');
  if P > 0 then
    Dev := Copy(Dev, 1, P);
  Dev := Trim(Dev);
  SetLength(Result, BOARD_DEVICE_AT);
  Result[0] := BOARD_FORMAT;
  Result[1] := 0;
  if ASummary.BenchWords > 0 then
    Result[1] := Round(ASummary.BenchMatched * 10000.0 / ASummary.BenchWords);
  Result[2] := Ord(not SameText(ASummary.Device, 'CPU'));
  Result[3] := 0;
  Packed4 := SteamBoardPackText(Dev, BOARD_DEVICE_NUMBERS);
  Result := Result + Packed4;
end;

procedure TfrmBuilder.BoardSend;
var
  I: Integer;
begin
  if not FBoardUpload or not SteamRunning then
    Exit;
  for I := 1 to 4 do
    if (FBenchScores[I] > 0) and (FBoardMs[I] > 0) and (FBoardState[I] = 0) then
    begin
      FBoardState[I] := 1;
      // the place and the rows are all that is wanted here
      SteamBoardSubmit(BOARD_NAMES[I], FBoardMs[I], FBoardDetails[I], 0, BoardSent);
    end;
end;

procedure TfrmBuilder.BoardSent(const AResult: TSteamBoardResult);
var
  I, Option: Integer;
begin
  Option := 0;
  for I := 1 to 4 do
    if SameText(BOARD_NAMES[I], AResult.Board) then
      Option := I;
  if (Option = 0) or (FBoardState[Option] <> 1) then
    Exit;
  if AResult.Ok and (AResult.Rank > 0) then
  begin
    FBoardState[Option] := 2;
    FBoardRank[Option] := AResult.Rank;
    FBoardCount[Option] := AResult.Count;
    FBoardBest[Option] := AResult.Best;
    if AResult.Improved then
      LogLine(Format('Leaderboard - %s: %s of %d.', [BENCH_NAMES[Option], PlaceText(AResult.Rank),
        AResult.Count]))
    else
      LogLine(Format('Leaderboard - %s: your best there is %s, %s of %d.', [BENCH_NAMES[Option],
        BenchScore(AResult.Best / 1000), PlaceText(AResult.Rank), AResult.Count]));
  end
  else
  begin
    FBoardState[Option] := 3;
    LogLine(Format('Leaderboard - %s: the score was not added (%s).', [BENCH_NAMES[Option],
      IfThen(AResult.Error <> '', AResult.Error, 'Steam gave no place')]));
  end;
  // the table says it too, the row chosen kept
  if FBenchResults and not FBenchHidden and (FPadMenu <> nil) and (FPadMode = BPM_ASK) and FPadMenu.Showing then
  begin
    FBenchSel := FPadMenu.Selected;
    BenchShowResults;
    FBenchSel := -1;
  end;
end;

function TfrmBuilder.BoardNote(AOption: Integer): string;
begin
  case FBoardState[AOption] of
    1: Result := '   sending to the leaderboard ...';
    2:
      if FBoardBest[AOption] < FBoardMs[AOption] then
        Result := Format('   your best %s is %s of %d', [BenchScore(FBoardBest[AOption] / 1000),
          PlaceText(FBoardRank[AOption]), FBoardCount[AOption]])
      else
        Result := Format('   %s of %d', [PlaceText(FBoardRank[AOption]), FBoardCount[AOption]]);
    3: Result := '   not added to the leaderboard';
  else
    Result := '';
  end;
end;

procedure TfrmBuilder.miBoardsClick(Sender: TObject);
begin
  PadBoards;
end;

procedure TfrmBuilder.PadBoards;
var
  Items: TArray<TPadMenuItem>;
  I: Integer;
begin
  if FPadMenu = nil then
    Exit;
  Items := nil;
  FPadCmds := nil;
  for I := 1 to 4 do
  begin
    Items := Items + [TPadMenu.Item(BENCH_NAMES[I])];
    FPadCmds := FPadCmds + [I];
  end;
  Items := Items + [TPadMenu.Item('Back')];
  FPadCmds := FPadCmds + [PADROW_BACK];
  FPadMode := BPM_BOARDS;
  FPadMenu.Show('Leaderboards', Items, EnsureRange(FBoardShown - 1, 0, 3),
    'The fastest transcriptions on Steam: each player''s best.');
end;

procedure TfrmBuilder.PadBoard(AOption: Integer);
var
  Row: TPadMenuItem;
begin
  if (FPadMenu = nil) or (AOption < 1) or (AOption > 4) then
    Exit;
  FBoardShown := AOption;
  FBoardAround := False;
  FBoardHasRank := False;
  Row := TPadMenu.Item('Asking Steam ...');
  Row.Info := True;
  FPadCmds := [PADROW_NONE, PADROW_BACK];
  FPadMode := BPM_BOARD;
  // the size, the frame and the title of the page that follows
  // (BoardRead)
  FPadMenu.NextWidthShare := BOARD_WIDTH_SHARE;
  FPadMenu.NextHeightShare := BOARD_WIDTH_SHARE;
  if FPadDark then
    FPadMenu.NextFrameColor := BOARD_FRAME_DARK
  else
    FPadMenu.NextFrameColor := BOARD_FRAME_LIGHT;
  FPadMenu.NextTitleCentered := True;
  FPadMenu.MinWidth := 100000;
  FPadMenu.Show(BENCH_NAMES[AOption], [Row, TPadMenu.Item('Back')], 1, PadFootOf([BP_BACK], ['back']));
  FPadMenu.MinWidth := 0;
  RefreshFoot;
  BoardAsk;
end;

procedure TfrmBuilder.BoardAsk;
begin
  if (FPadMenu = nil) or (FBoardShown < 1) or (FBoardShown > 4) then
    Exit;
  // the rows the page holds, less its Back row
  FBoardRows := Max(3, FPadMenu.RowsThatFit(BOARD_WIDTH_SHARE, True) - 1);
  SteamBoardRead(BOARD_NAMES[FBoardShown], FBoardRows, FBoardAround, BoardRead);
end;

procedure TfrmBuilder.BoardSwitch;
begin
  // nothing to switch to while the user has no row there
  if not FBoardHasRank then
    Exit;
  FBoardAround := not FBoardAround;
  BoardAsk;
end;

procedure TfrmBuilder.BoardRead(const AResult: TSteamBoardResult);
var
  Items: TArray<TPadMenuItem>;
  Row: TPadMenuItem;
  I, Shown: Integer;
  Name, Title: string;
  Listed, Last: Boolean;
  Mine: TAlphaColor;

  { A line of the page: APlace in the first column ('' = a line that is
    not a row of the board), then the name, the score, the device; AMine:
    the user's own row, in the frame's yellow (owner, 2026-11-23). }
  procedure Info(const APlace, AText, AValue, ADevice: string; ADim: Boolean; AMine: Boolean = False);
  begin
    Row := TPadMenu.Item(AText, AValue);
    Row.Key := APlace;
    Row.Value2 := ADevice;
    Row.Info := True;
    Row.Dim := ADim;
    if AMine then
      Row.Color := Mine;
    Items := Items + [Row];
    FPadCmds := FPadCmds + [PADROW_NONE];
  end;

  { The device a row's numbers name, when the row is one of this
    program's. }
  function DeviceOf(const ADetails: TArray<Integer>): string;
  begin
    Result := '';
    if (Length(ADetails) > BOARD_DEVICE_AT) and (ADetails[0] = BOARD_FORMAT) then
      Result := SteamBoardUnpackText(ADetails, BOARD_DEVICE_AT);
  end;

begin
  // only while its page shows, and for the page asked for last (left and
  // right pressed in a hurry: an earlier answer is not shown)
  if (FPadMenu = nil) or (FPadMode <> BPM_BOARD) or not FPadMenu.Showing or (FBoardShown < 1) or
    (FBoardShown > 4) or not SameText(AResult.Board, BOARD_NAMES[FBoardShown]) or
    (AResult.AskedAround <> FBoardAround) then
    Exit;
  Items := nil;
  FPadCmds := nil;
  if FPadDark then
    Mine := BOARD_FRAME_DARK
  else
    Mine := BOARD_FRAME_LIGHT;
  FBoardHasRank := AResult.Ok and (AResult.Rank > 0);
  // asked for the rows around a user who has none: the top came
  FBoardAround := AResult.Ok and AResult.Around;
  Title := BENCH_NAMES[FBoardShown];
  if not AResult.Ok then
  begin
    if AResult.Error = 'the leaderboard is not there yet' then
      Info('', 'No scores yet: run this benchmark to be the first.', '', '', False)
    else
      Info('', 'The leaderboard could not be read: ' + AResult.Error + '.', '', '', False);
  end
  else
  begin
    Listed := False;
    for I := 0 to High(AResult.Rows) do
      Listed := Listed or AResult.Rows[I].Me;
    // the top page and the user further down: their row is the last
    // line, one row fewer of the top (owner, 2026-11-23)
    Last := (AResult.Rank > 0) and not Listed;
    Shown := Min(Length(AResult.Rows), FBoardRows);
    if Last and (Shown >= FBoardRows) then
      Shown := FBoardRows - 1;
    for I := 0 to Shown - 1 do
    begin
      Name := AResult.Rows[I].Name;
      if Name = '' then
        Name := 'A Steam player';
      if AResult.Rows[I].Me then
        Name := Name + ' (you)';
      Info(Format('%d.', [AResult.Rows[I].Rank]), Name, BenchScore(AResult.Rows[I].Score / 1000),
        DeviceOf(AResult.Rows[I].Details), not AResult.Rows[I].Me, AResult.Rows[I].Me);
    end;
    if Length(AResult.Rows) = 0 then
      Info('', 'No scores yet: run this benchmark to be the first.', '', '', False);
    if Last then
      Info(Format('%d.', [AResult.Rank]), 'You', BenchScore(AResult.Best / 1000), DeviceOf(AResult.BestDetails),
        False, True);
    // which page, and how many are on the board
    if AResult.Count > 0 then
      Title := Format('%s - %s (%d on the board)', [Title, IfThen(FBoardAround, 'around you', 'top'),
        AResult.Count]);
  end;
  Items := Items + [TPadMenu.Item('Back')];
  FPadCmds := FPadCmds + [PADROW_BACK];
  // owner, 2026-11-23: 95 % of the window wide and high; place and name
  // 40 % (the place a column of its own in it, room for seven digits),
  // score 10 %, device 50 %; the benchmarks' yellow frame; the title
  // centred
  FPadMenu.NextWidthShare := BOARD_WIDTH_SHARE;
  FPadMenu.NextHeightShare := BOARD_WIDTH_SHARE;
  FPadMenu.NextColumns := [0.4, 0.1, 0.5];
  if FPadDark then
    FPadMenu.NextFrameColor := BOARD_FRAME_DARK
  else
    FPadMenu.NextFrameColor := BOARD_FRAME_LIGHT;
  FPadMenu.NextTitleCentered := True;
  // left / right: the other page, when the user has a row
  if FBoardHasRank then
    FPadMenu.Show(Title, Items, High(Items), PadFootOf([BP_LEFT, BP_RIGHT, BP_BACK], ['', IfThen(FBoardAround,
      'top', 'around you'), 'back']))
  else
    FPadMenu.Show(Title, Items, High(Items), PadFootOf([BP_BACK], ['back']));
  RefreshFoot;
end;

procedure TfrmBuilder.BenchShowResults;
var
  Items: TArray<TPadMenuItem>;
  Row: TPadMenuItem;
  I: Integer;
begin
  if FPadMenu = nil then
    Exit;
  Items := nil;
  FPadCmds := nil;
  FAskResults := nil;
  // the table: a benchmark on the left, its score on the right
  for I := 1 to 4 do
    if FBenchScores[I] > 0 then
    begin
      Row := TPadMenu.Item(BENCH_NAMES[I], BenchScore(FBenchScores[I]) + BoardNote(I));
      Row.Info := True;
      Items := Items + [Row];
      FPadCmds := FPadCmds + [PADROW_NONE];
      FAskResults := FAskResults + [mrNone];
    end;
  if Length(FBenchCandidates) > 0 then
  begin
    Items := Items + [TPadMenu.Item('')];
    FPadCmds := FPadCmds + [PADROW_NONE];
    FAskResults := FAskResults + [mrNone];
    Items[High(Items)].Info := True;
    if Length(FBenchCandidates) = 1 then
      Row := TPadMenu.Item('Keep the book to read in EpubReader?')
    else
      Row := TPadMenu.Item('Keep the books to read in EpubReader?');
    Row.Info := True;
    Items := Items + [Row];
    FPadCmds := FPadCmds + [PADROW_NONE];
    FAskResults := FAskResults + [mrNone];
    // owner, 2026-11-22: Detailed gives the better book
    if FBenchFastOffered then
    begin
      Row := TPadMenu.Item('Detailed makes the better book.');
      Row.Info := True;
      Row.Dim := True;
      Items := Items + [Row];
      FPadCmds := FPadCmds + [PADROW_NONE];
      FAskResults := FAskResults + [mrNone];
    end;
    Items := Items + [TPadMenu.Item('Yes'), TPadMenu.Item('No')];
    FPadCmds := FPadCmds + [PADROW_NONE, PADROW_NONE];
    FAskResults := FAskResults + [mrYes, mrNo];
  end
  else
  begin
    Items := Items + [TPadMenu.Item('OK')];
    FPadCmds := FPadCmds + [PADROW_NONE];
    FAskResults := FAskResults + [mrOk];
  end;
  FAskCancel := mrNo;
  FPairPad := False;
  FAskThenClose := not FBigPicture;
  FAskProc :=
    procedure(const AResult: TModalResult)
    var
      K: Integer;
    begin
      for K := 0 to High(FBenchKeep) do
        try
          if (AResult = mrYes) and (IndexStr(FBenchKeep[K], FBenchCandidates) >= 0) then
          begin
            ForceDirectories(FOutFolder);
            TFile.Copy(FBenchKeep[K], TPath.Combine(FOutFolder, ExtractFileName(FBenchKeep[K])), True);
            LogLine('Kept for EpubReader: ' + ChangeFileExt(ExtractFileName(FBenchKeep[K]), ''));
          end;
          if FileExists(FBenchKeep[K]) then
            TFile.Delete(FBenchKeep[K]);
        except
          on E: Exception do
            LogLine('A benchmark''s book was not kept: ' + E.Message);
        end;
      FBenchKeep := nil;
      FBenchCandidates := nil;
      FBenchResults := False;
      FBenchHidden := False;
      // the bars go once the results are answered
      FreeAndNil(FBenchView);
    end;
  FPadMode := BPM_ASK;
  FPadMenu.NextTitleCentered := True;
  // owner, 2026-11-22: No by default (the last row); shown again for a
  // leaderboard's answer, the row chosen stays
  I := High(Items);
  if (FBenchSel >= 0) and (FBenchSel <= High(Items)) and (FAskResults[FBenchSel] <> mrNone) then
    I := FBenchSel;
  FPadMenu.Show('Results', Items, I, PadFootOf([BP_CHOOSE, BP_BACK, BP_TOGGLE], ['answer', 'no',
    'hide']));
  RefreshFoot;
end;

procedure TfrmBuilder.BenchToggleResults;
begin
  if not FBenchResults or (FPadMenu = nil) then
    Exit;
  if FBenchHidden then
  begin
    FBenchHidden := False;
    BenchShowResults;
    if FBenchView <> nil then
      FBenchView.SetButtonText('Hide results');
  end
  else
  begin
    // the question stays open (FAskProc, FPadMode): only the box goes
    FBenchHidden := True;
    FPadMenu.Hide;
    if FBenchView <> nil then
      FBenchView.SetButtonText('Show results');
  end;
end;

procedure TfrmBuilder.PadBenchmarks;
var
  Items: TArray<TPadMenuItem>;
  Row: TPadMenuItem;
  I: Integer;
begin
  if FPadMenu = nil then
    Exit;
  RefreshBenchmarks;
  Items := nil;
  FPadCmds := nil;
  // Steam's leaderboards of the four, the top row (owner, 2026-11-23)
  if SteamRunning then
  begin
    Items := Items + [TPadMenu.Item('Leaderboards')];
    FPadCmds := FPadCmds + [PADROW_BOARDS];
  end;
  for I := 0 to High(miBench) do
  begin
    if FBenchEta[I] > 0 then
      Row := TPadMenu.Item(BenchName(I), 'about ' + HmsText(FBenchEta[I]))
    else
      Row := TPadMenu.Item(BenchName(I));
    // faded: its model is not there or too slow (chosen, it says so)
    Row.Dim := not miBench[I].Enabled;
    Items := Items + [Row];
    FPadCmds := FPadCmds + [I];
  end;
  Items := Items + [TPadMenu.Item('Back')];
  FPadCmds := FPadCmds + [PADROW_BACK];
  FPadMode := BPM_BENCH;
  FPadMenu.Show('Benchmark', Items, 0, 'The score is the time the transcription takes.');
end;

function TfrmBuilder.BenchTitle(AOption: Integer): string;
var
  D: TWhisperDevice;
  Dev: string;
begin
  Result := BENCH_NAMES[AOption] + ' - ' + REFERENCE_TEXTS[BENCH_REFS[AOption]].Title;
  // the device as the log's "Device:" line has it, without its name
  // (owner, 2026-11-22): 'NVIDIA GeForce RTX 5090 Laptop GPU (GPU, Vulkan,
  // 22.7 of 23.6 GB free)'
  if BuilderFindDevice(BenchmarkDevice(BenchmarkModel(AOption)), D) then
  begin
    Dev := WhisperDeviceText(D);
    if StartsText(D.Name + ' - ', Dev) then
      Dev := Copy(Dev, Length(D.Name) + 4, MaxInt);
    Result := Result + ' : ' + Dev;
  end;
end;

{ A benchmark's clock, ASeconds, as HH:MM:SS.mmm. }
function BenchClock(ASeconds: Double): string;
var
  Ms: Int64;
begin
  Ms := Max(Int64(0), Round(ASeconds * 1000));
  Result := Format('%.2d:%.2d:%.2d.%.3d', [Ms div 3600000, (Ms div 60000) mod 60, (Ms div 1000) mod 60,
    Ms mod 1000]);
end;

procedure TfrmBuilder.BenchTick(Sender: TObject);
var
  R, Option: Integer;
  Pct: Double;
  Phase: string;
begin
  if FBenchView = nil then
    Exit;
  for R := 0 to High(FBenchList) do
  begin
    Option := FBenchList[R];
    if (Option = FBenchOption) and (FBuild <> nil) then
    begin
      // owner, 2026-11-22: the clock is the score's - it stands at zero
      // while the benchmark is prepared, runs with the transcription (of
      // the chapter material) and stops when it ends. The build's
      // progress: 0 - 5 % the book, the audio, the model; 5 - 90 % the
      // transcription; then aligning and writing.
      Pct := EnsureRange((FPercent - 5) / 85 * 100, 0.0, 100.0);
      if FPercent >= 90 then
      begin
        Phase := 'Finalizing';
        Pct := 100;
      end
      else if (FPercent > 5) or StartsText('Part ', FStatusText) then
        Phase := 'Transcribing'
      else
        Phase := 'Preparing Benchmark';
      FBenchPct[Option] := Pct;
      FBenchClock[Option] := FBuild.BenchElapsed;
      FBenchView.SetRow(R, BenchClock(FBenchClock[Option]), Phase, Pct);
    end
    else if FBenchEnded[Option] then
    begin
      // the score itself when there is one
      if FBenchScores[Option] > 0 then
        FBenchView.SetRow(R, BenchClock(FBenchScores[Option]), 'Done', 100)
      else
        FBenchView.SetRow(R, BenchClock(FBenchClock[Option]), 'Stopped', FBenchPct[Option]);
    end
    else
      FBenchView.SetRow(R, BenchClock(0), 'Waiting', 0);
  end;
end;

procedure TfrmBuilder.BenchCancel(Sender: TObject);
begin
  // the run over: the button shows or hides the results
  if FBenchResults then
    BenchToggleResults
  else
    btnCancelClick(nil);
end;

procedure TfrmBuilder.CalTick(Sender: TObject);
var
  R, Total, Current: Integer;
  Pct: Double;
begin
  if FCalView = nil then
    Exit;
  Total := Max(1, Length(FDevices));
  // the model being timed: the first not done (more than four models: the
  // view scrolls to it - owner, 2026-11-22, "Calibrate All" of every model)
  Current := -1;
  for R := 0 to High(FCalRows) do
    if FCalRows[R].Ended = 0 then
    begin
      Current := R;
      Break;
    end;
  if Current >= 0 then
  begin
    FCalView.SetCurrent(Current);
    FCalView.SetHeader(Format('Model %d of %d', [Current + 1, Length(FCalRows)]));
  end
  else
  begin
    FCalView.SetCurrent(High(FCalRows));
    FCalView.SetHeader(Format('All %d models calibrated', [Length(FCalRows)]));
  end;
  for R := 0 to High(FCalRows) do
  begin
    // the devices done and how far the one being timed is (owner,
    // 2026-11-22: 0, 33, 66, 100 looked stuck on a slow machine)
    Pct := (FCalRows[R].Done + FCalRows[R].Step / 100) * 100 / Total;
    if FCalRows[R].Ended <> 0 then
    begin
      if FCalRows[R].Best <> '' then
        FCalView.SetRow(R, BenchClock((FCalRows[R].Ended - FCalRows[R].Started) * SecsPerDay),
          Format('Done - fastest: %s (%.1fx)', [FCalRows[R].Best, FCalRows[R].BestSpeed]), 100)
      else
        FCalView.SetRow(R, BenchClock((FCalRows[R].Ended - FCalRows[R].Started) * SecsPerDay),
          'Done - no device could run it', 100);
    end
    else if FCalRows[R].Started <> 0 then
    begin
      if (FCalRows[R].Device <> '') and (FCalRows[R].Phase <> '') then
        FCalView.SetRow(R, BenchClock((Now - FCalRows[R].Started) * SecsPerDay), FCalRows[R].Phase + ' ' +
          FCalRows[R].Device, Pct)
      else if FCalRows[R].Device <> '' then
        FCalView.SetRow(R, BenchClock((Now - FCalRows[R].Started) * SecsPerDay), 'Timing on ' +
          FCalRows[R].Device, Pct)
      else
        FCalView.SetRow(R, BenchClock((Now - FCalRows[R].Started) * SecsPerDay), 'Calibrating', Pct);
    end
    else
      FCalView.SetRow(R, BenchClock(0), 'Waiting', 0);
  end;
end;

procedure TfrmBuilder.StartDiagnostics(AAllModels: Boolean);
var
  Models: TStringList;
  Audio, DevName, Best: string;
  Dev, Own: TWhisperDevice;
  Devs: TWhisperDeviceArray;
  Speed: Double;
  I: Integer;
begin
  if (FBuild <> nil) or (FCalib <> nil) or (FDownload <> nil) or FQueueRunning then
  begin
    LogLine('A build, a calibration or a download is running: run the diagnostics when it has ended.');
    Exit;
  end;
  if (FWhisperNote <> '') or (Length(FDevices) = 0) then
  begin
    LogLine('whisper.cpp is not available: there is nothing to diagnose.');
    Exit;
  end;
  if FModelPath = '' then
  begin
    LogLine('Diagnostics not started: choose a model in the Model list first.');
    Exit;
  end;
  // the device a build would use: the one in the window, "Default" as the
  // device it stands for
  DevName := '';
  if (cbDevice.ItemIndex > 0) and (cbDevice.ItemIndex - 1 <= High(FDevices)) then
    DevName := FDevices[cbDevice.ItemIndex - 1].Name;
  if DevName = '' then
    DevName := GDefaultDevice;
  if not BuilderFindDevice(DevName, Dev) then
  begin
    LogLine('Diagnostics not started: the device ' + IfThen(DevName = '', '"Default"', DevName) + ' was not found.');
    Exit;
  end;
  // the calibration's reference text (never another recording: the
  // figures are compared between machines, so it must be the same one)
  Audio := ReferenceAudio(CALIBRATION_REFERENCE);
  if Audio = '' then
  begin
    LogLine(Format('Diagnostics not started: %s/%s (the reference text %s) was not found beside the program.',
      [REFERENCE_FOLDER, REFERENCE_TEXTS[CALIBRATION_REFERENCE].Audio,
      REFERENCE_TEXTS[CALIBRATION_REFERENCE].Title]));
    Exit;
  end;
  if AAllModels then
  begin
    Models := ModelFilesOf(ExtractFileDir(FModelPath));
    if not FExpert then
      KeepStandardModels(Models, FModelPath);
  end
  else
  begin
    Models := TStringList.Create;
    Models.Add(FModelPath);
  end;
  try
    if Models.Count = 0 then
    begin
      LogLine('No ggml-*.bin in ' + ExtractFileDir(FModelPath) + ': nothing to diagnose.');
      Exit;
    end;
    // each model on the device a build of it would use: the one its
    // calibration found fastest, else the window's
    SetLength(Devs, Models.Count);
    for I := 0 to Models.Count - 1 do
    begin
      Devs[I] := Dev;
      if AAllModels and CalibrationBest(SettingsFile, Models[I], Best, Speed) and BuilderFindDevice(Best, Own) then
        Devs[I] := Own;
    end;
    // the diagnostics' lines: in the window and in <settings>-diagnostics.log
    mmLog.Lines.Clear;
    FBuildLog.Clear;
    FLogging := True;
    LogLine(Format('=== Diagnostics (%s) ===', [FormatDateTime('yyyy-mm-dd hh:nn', Now)]));
    LogLine('Machine: ' + MachineText);
    LogLine(FWhisperText);
    if Models.Count > 1 then
      LogLine(Format('%d models, smallest first, each on the device its calibration chose (the window''s device ' +
        'for a model not calibrated).', [Models.Count]));
    // English, the book prompt: as the calibration (its recording)
    FCalib := TCalibrationThread.Create(Models, Audio, 'en', BOOK_PROMPT, ChangeFileExt(SettingsFile,
      CALIBRATION_MARKER_SUFFIX), Devs, nil);
  finally
    Models.Free;
  end;
  FCalib.Diagnostics := True;
  // it says what the calibration timed each model at
  FCalib.IniFile := SettingsFile;
  FCalib.OnLog :=
    procedure(AText: string)
    begin
      ThreadLine(AText);
    end;
  FCalib.OnProgress :=
    procedure(APercent: Double)
    begin
      pbBuild.Value := APercent;
      FPercent := APercent;
    end;
  FCalib.OnStatus :=
    procedure(AText: string)
    begin
      FStatusText := AText;
      ShowStatus;
    end;
  pbBuild.Value := 0;
  FStarted := Now;
  FPercent := 0;
  FRatePercent := -1;
  FStatusText := 'Diagnostics ...';
  tmStatus.Enabled := True;
  FCalib.OnTerminate := CalibrationDone;
  FCalib.FreeOnTerminate := True;
  UpdateControls;
  FCalib.Start;
end;

procedure TfrmBuilder.StartCalibration(AAllModels, ARetry: Boolean);
var
  Models, Skip: TStringList;
  Audio, Saved, Names: string;
  Ini: TMemIniFile;
  D: TOpenDialog;
  I: Integer;
  Row: TCalibrationRow;
  Titles: TArray<string>;
begin
  if (FBuild <> nil) or (FCalib <> nil) or FQueueRunning then
  begin
    LogLine('A build or a calibration is running: calibrate when it has ended.');
    Exit;
  end;
  if (FWhisperNote <> '') or (Length(FDevices) = 0) then
  begin
    LogLine('whisper.cpp is not available: there is nothing to calibrate.');
    Exit;
  end;
  if FModelPath = '' then
  begin
    LogLine('Calibration not started: choose a model in the Model list first (one not downloaded yet is ' +
      'downloaded when chosen; turbo is a good first choice).');
    Exit;
  end;
  // the recording: the reference text's beside the program (or above
  // it), else one chosen before, else asked for
  Saved := '';
  if FileExists(SettingsFile) then
  begin
    Ini := TMemIniFile.Create(SettingsFile, TEncoding.UTF8);
    try
      Saved := Ini.ReadString(CAL_SECTION, 'Audio', '');
    finally
      Ini.Free;
    end;
  end;
  Audio := FindCalibrationAudio(Saved);
  if Audio = '' then
  begin
    LogLine(Format('%s/%s (the reference text %s) was not found beside the program: choose a recording of ' +
      'English speech, a few minutes long, for the calibration.', [REFERENCE_FOLDER,
      REFERENCE_TEXTS[CALIBRATION_REFERENCE].Audio, REFERENCE_TEXTS[CALIBRATION_REFERENCE].Title]));
    D := TOpenDialog.Create(Self);
    try
      D.Title := 'A recording for the calibration (English speech, a few minutes)';
      D.Filter := 'Audio (*.m4b;*.m4a;*.aax;*.mp3;*.wav;*.flac;*.ogg;*.opus;*.aac)|*.m4b;*.m4a;*.aax;*.mp3;' +
        '*.wav;*.flac;*.ogg;*.opus;*.aac|All files (*.*)|*.*';
      D.InitialDir := FAudioFolder;
      if D.Execute then
        Audio := D.FileName;
    finally
      D.Free;
    end;
    if Audio = '' then
    begin
      LogLine('Calibration not started: no recording.');
      Exit;
    end;
  end;
  if AAllModels then
  begin
    Models := ModelFilesOf(ExtractFileDir(FModelPath));
    if not FExpert then
      KeepStandardModels(Models, FModelPath);
    // CalibrateNewModels: the ones not calibrated yet only
    if FCalOnlyNew then
    begin
      for I := Models.Count - 1 downto 0 do
        if CalibrationSummary(SettingsFile, Models[I]) <> '' then
          Models.Delete(I);
      if Models.Count = 0 then
      begin
        Models.Free;
        Exit;
      end;
    end;
  end
  else
  begin
    Models := TStringList.Create;
    Models.Add(FModelPath);
  end;
  if ARetry then
  begin
    CalibrationClearCrashes(SettingsFile);
    Skip := TStringList.Create;
  end
  else
    Skip := CalibrationCrashes(SettingsFile);
  try
    if Models.Count = 0 then
    begin
      LogLine('No ggml-*.bin in ' + ExtractFileDir(FModelPath) + ': nothing to calibrate.');
      Exit;
    end;
    // the calibration's lines: in the window and in <settings>-calibration.log
    mmLog.Lines.Clear;
    FBuildLog.Clear;
    FLogging := True;
    LogLine(Format('=== Calibration (%s) ===', [FormatDateTime('yyyy-mm-dd hh:nn', Now)]));
    LogLine('Machine: ' + MachineText);
    LogLine(FWhisperText);
    LogLine('Devices:');
    for I := 0 to High(FDevices) do
      LogLine('  ' + WhisperDeviceText(FDevices[I]));
    LogLine(Format('Each model on each device: loaded, a short warm-up, then %d s of speech timed in one run ' +
      '(the clearest %d s of the recording, 30 s away from both ends of every section), with the settings of a ' +
      'build: word times by DTW, the book prompt, the temperature fallback, each window on its own.',
      [CALIBRATION_STRETCH_SECONDS, CALIBRATION_STRETCH_SECONDS]));
    if Models.Count > 1 then
    begin
      LogLine(Format('%d models, smallest first:', [Models.Count]));
      for I := 0 to Models.Count - 1 do
        LogLine('  ' + ExtractFileName(Models[I]));
    end;
    // the progress view's blocks: a model each, in the calibration's order
    FCalRows := nil;
    for I := 0 to Models.Count - 1 do
    begin
      Row := Default(TCalibrationRow);
      Row.Model := Models[I];
      FCalRows := FCalRows + [Row];
    end;
    // English: the calibration recording is English speech (the language
    // makes no difference to the speed)
    FCalib := TCalibrationThread.Create(Models, Audio, 'en', BOOK_PROMPT, ChangeFileExt(SettingsFile,
      CALIBRATION_MARKER_SUFFIX), FDevices, Skip);
  finally
    Models.Free;
    Skip.Free;
  end;
  FCalib.OnLog :=
    procedure(AText: string)
    begin
      ThreadLine(AText);
    end;
  FCalib.OnProgress :=
    procedure(APercent: Double)
    begin
      pbBuild.Value := APercent;
      FPercent := APercent;
    end;
  FCalib.OnStatus :=
    procedure(AText: string)
    begin
      FStatusText := AText;
      ShowStatus;
    end;
  pbBuild.Value := 0;
  FStarted := Now;
  FPercent := 0;
  FRatePercent := -1;
  FCalib.OnPair :=
    procedure(AModel, ADevice: Integer; ASpeed: Double)
    begin
      if (AModel < 0) or (AModel > High(FCalRows)) or (ADevice < 0) or (ADevice > High(FDevices)) then
        Exit;
      if ASpeed < 0 then
      begin
        if FCalRows[AModel].Started = 0 then
          FCalRows[AModel].Started := Now;
        FCalRows[AModel].Device := FDevices[ADevice].Name;
        FCalRows[AModel].Phase := '';
        FCalRows[AModel].Step := 0;
      end
      else
      begin
        Inc(FCalRows[AModel].Done);
        FCalRows[AModel].Device := '';
        FCalRows[AModel].Phase := '';
        FCalRows[AModel].Step := 0;
        if ASpeed > FCalRows[AModel].BestSpeed then
        begin
          FCalRows[AModel].Best := FDevices[ADevice].Name;
          FCalRows[AModel].BestSpeed := ASpeed;
        end;
        if FCalRows[AModel].Done >= Length(FDevices) then
          FCalRows[AModel].Ended := Now;
      end;
    end;
  // within a pair: its phase and how far it is
  FCalib.OnStep :=
    procedure(AModel, ADevice: Integer; const APhase: string; APercent: Integer)
    begin
      if (AModel < 0) or (AModel > High(FCalRows)) or (ADevice < 0) or (ADevice > High(FDevices)) then
        Exit;
      // a step queued after its pair ended: left out
      if FCalRows[AModel].Device <> FDevices[ADevice].Name then
        Exit;
      FCalRows[AModel].Phase := APhase;
      FCalRows[AModel].Step := APercent;
    end;
  FStatusText := 'Calibrating ...';
  tmStatus.Enabled := True;
  // owner, 2026-11-22: the calibration is the first thing seen - a bar per
  // model over the window (the pad's menu out of the way), the menu after
  // it (CalibrationDone)
  if (FPadMenu <> nil) and FPadMenu.Showing then
  begin
    FPadMenu.Hide;
    FPadMode := BPM_HOME;
  end;
  Titles := nil;
  Names := '';
  for I := 0 to High(FDevices) do
    Names := Names + IfThen(Names <> '', ', ', '') + FDevices[I].Name;
  for I := 0 to High(FCalRows) do
    Titles := Titles + [Format('Calibrating %s : %s', [ModelLabel(ModelShortName(FCalRows[I].Model)), Names])];
  FreeAndNil(FCalView);
  FCalView := TBenchProgress.Create(Self, Titles, FPadDark, not FBigPicture);
  FCalView.OnTick := CalTick;
  FCalView.OnButton := BenchCancel;
  CalTick(nil);
  FCalib.OnTerminate := CalibrationDone;
  FCalib.FreeOnTerminate := True;
  UpdateControls;
  FCalib.Start;
end;

procedure TfrmBuilder.UseBaseWhenTooSlow;
var
  Base, Dev, BaseDev, Name: string;
  Speed, BaseSpeed, Limit: Double;
begin
  if (FLowestSpeed <= 0) or (FModelPath = '') then
    Exit;
  Limit := FLowestSpeed / 10;
  // the window's model at its best here: fast enough, or not timed
  if not CalibrationBest(SettingsFile, FModelPath, Dev, Speed) or (Speed <= 0) or (Speed >= Limit) then
    Exit;
  Base := TPath.Combine(FModelsFolder, BENCH_QUICK_MODEL);
  if SameText(Base, FModelPath) or not FileExists(Base) then
    Exit;
  // base must be known to be fast enough
  if not CalibrationBest(SettingsFile, Base, BaseDev, BaseSpeed) or (BaseSpeed < Limit) then
    Exit;
  Name := ModelLabel(ModelShortName(FModelPath));
  LogLine(Format('%s is too slow on this machine: %.1fx real time at best (on %s), and the lowest acceptable ' +
    'speed is %.1fx. base is used instead (%.1fx on %s). Settings > Model chooses another; lowering Settings > ' +
    'Lowest acceptable speed lets %s be used.', [Name, Speed, Dev, Limit, BaseSpeed, BaseDev, Name]));
  FModelPath := Base;
  FillModels;
end;

procedure TfrmBuilder.CalibrationDone(Sender: TObject);
var
  T: TCalibrationThread;
  LogFile: string;
  Kept: TStringList;
begin
  // OnTerminate runs on the main thread after Execute: the queued log
  // lines have been delivered before it
  T := Sender as TCalibrationThread;
  if T.Diagnostics then
  begin
    // nothing to keep in the settings: its lines are the result
    if not T.Completed then
      LogLine('The diagnostics did not finish.');
    LogLine(Format('Diagnostics took %s', [WhisperTimeToStr(MilliSecondsBetween(Now, FStarted) div 10)]));
    FLogging := False;
    LogFile := ChangeFileExt(SettingsFile, DIAGNOSTICS_LOG_SUFFIX);
    try
      // added to the runs before it (owner, 2026-11-21: a tiny.en run had
      // replaced the turbo run made first): one file holds every model's
      Kept := TStringList.Create;
      try
        if FileExists(LogFile) then
          Kept.LoadFromFile(LogFile, TEncoding.UTF8);
        Kept.AddStrings(FBuildLog);
        Kept.SaveToFile(LogFile, TEncoding.UTF8);
      finally
        Kept.Free;
      end;
      LogLine('Diagnostics log (this run added to it): ' + LogFile);
    except
      on E: Exception do
        LogLine('The diagnostics log was not saved: ' + E.Message);
    end;
    // FreeOnTerminate: the thread frees itself once this handler returns
    FCalib := nil;
    tmStatus.Enabled := False;
    ShowStatus;
    UpdateControls;
    PadBackToMenu(True);
    Exit;
  end;
  if T.Completed then
  begin
    try
      CalibrationSave(SettingsFile, T.Results, CalibrationDevicesKey(FDevices), T.AudioFile);
      LogLine('Kept in ' + SettingsFile);
      // at start-up: a model too slow here gives way to base
      if FCalAtStart then
        UseBaseWhenTooSlow;
      // the model in the window gets its fastest device, and keeps it
      ApplyCalibration(True);
      SaveSettings;
    except
      on E: Exception do
        LogLine('The calibration was not saved: ' + E.Message);
    end;
  end
  else
    LogLine('The calibration did not finish: nothing was changed (Settings > Re-calibrate runs it again).');
  LogLine(Format('Calibration took %s', [WhisperTimeToStr(MilliSecondsBetween(Now, FStarted) div 10)]));
  FLogging := False;
  LogFile := ChangeFileExt(SettingsFile, CALIBRATION_LOG_SUFFIX);
  try
    FBuildLog.SaveToFile(LogFile, TEncoding.UTF8);
    LogLine('Calibration log: ' + LogFile);
  except
    on E: Exception do
      LogLine('The calibration log was not saved: ' + E.Message);
  end;
  // FreeOnTerminate: the thread frees itself once this handler returns
  FCalib := nil;
  tmStatus.Enabled := False;
  ShowStatus;
  UpdateControls;
  // owner, 2026-11-22: the results first, and what they mean for a book
  // (the menu once they are seen)
  if T.Completed and (FCalView <> nil) then
  begin
    ShowCalibrationResults;
    Exit;
  end;
  CalResultsClosed;
end;

procedure TfrmBuilder.CalResultsClosed;
begin
  FCalResults := False;
  // the calibration's bars go: the menu next - the main menu after the
  // one at start-up (owner, 2026-11-22), else on Model for the next one
  FreeAndNil(FCalView);
  if FCalFromSettings then
  begin
    // Settings > Calibration results: the Settings page again, on its row
    FCalFromSettings := False;
    PadHome(BPC_RESULTS);
    Exit;
  end;
  PadBackToMenu(not FCalAtStart);
  FCalAtStart := False;
end;

procedure TfrmBuilder.ShowCalibrationPage;
var
  Done, DontAsk: Boolean;
  Key, Made: string;
begin
  // what the calibration keeps, into the log (as before)
  miCalibrationClick(nil);
  CalibrationState(SettingsFile, Done, DontAsk, Key, Made);
  if not Done then
  begin
    // Big Picture: the note's OK brings the Settings page back
    FPadToModel := FBigPicture;
    Tell('Not calibrated on this machine yet: Settings > Re-calibrate.');
    Exit;
  end;
  // a calibration running has the view (its bars)
  if FCalib <> nil then
    Exit;
  FreeAndNil(FCalView);
  FCalView := TBenchProgress.Create(Self, nil, FPadDark, not FBigPicture);
  FCalFromSettings := True;
  ShowCalibrationResults;
end;

procedure TfrmBuilder.CalResultsButton(Sender: TObject);
begin
  if not FCalResults then
    Exit;
  FCalResults := False;
  // not freed inside its own event
  TThread.ForceQueue(nil, CalResultsClosed);
end;

type
  { A LibriVox recording for the calibration's results. }
  TLibriVoxBook = record
    { The book. }
    Title: string;
    { The recording's length, seconds (librivox.org's catalogue). }
    Seconds: Integer;
  end;

const
  { Well-known LibriVox recordings, shortest first (owner, 2026-11-22:
    "Find some popular books on Librivox and get their recording length
    ... Maybe put a dozen books in that list. An interesting one would be
    all of war + peace (total the parts)"). Lengths from LibriVox's
    catalogue (api/feed/audiobooks totaltimesecs, 2026-11-22), the first
    recording of each; War and Peace = its Books 01 - 17 added up. }
  LIBRIVOX_BOOKS: array[0..11] of TLibriVoxBook = (
    (Title: 'Alice''s Adventures in Wonderland'; Seconds: 10731),
    (Title: 'The Time Machine'; Seconds: 14969),
    (Title: 'Treasure Island'; Seconds: 27008),
    (Title: 'Frankenstein'; Seconds: 29808),
    (Title: 'The Adventures of Sherlock Holmes'; Seconds: 37079),
    (Title: 'Pride and Prejudice'; Seconds: 47204),
    (Title: 'A Tale of Two Cities'; Seconds: 53975),
    (Title: 'Dracula'; Seconds: 59469),
    (Title: 'Jane Eyre'; Seconds: 74196),
    (Title: 'Moby Dick'; Seconds: 88670),
    (Title: 'The Count of Monte Cristo'; Seconds: 178995),
    (Title: 'War and Peace (all 17 books)'; Seconds: 232564));

function TfrmBuilder.BookSeconds(const AHistory: TBuildHistory; const AModel: string; ALength: Double): Double;
var
  Dev, DevKey, Source: string;
  D: TWhisperDevice;
  Speed, After, Prior: Double;
begin
  Result := 0;
  if (AModel = '') or (ALength <= 0) then
    Exit;
  // as RefreshBenchmarks: the device a build of it uses, Core ML apart
  Dev := BenchmarkDevice(AModel);
  if BuilderFindDevice(Dev, D) then
    Dev := D.Name;
  DevKey := Dev;
  if UsesCoreML(AModel) then
    DevKey := Dev + '+CoreML';
  if HistoryExpect(AHistory, HistoryMachine(MachineText), ExtractFileName(AModel), DevKey,
    CalibrationSpeed(SettingsFile, AModel, Dev), CalibrationSeconds(SettingsFile, AModel), Speed, After, Prior,
    Source) and (Speed > 0) then
    Result := ALength / Speed + After * ALength;
end;

procedure TfrmBuilder.ShowCalibrationResults;
const
  { The two models of the table: base, large-v3-turbo. }
  NAMES: array[0..1] of string = ('base', 'turbo');
  { Said under the title, in bold (owner, 2026-11-22: "Stress on the
    Calibration results page that these timings are extremely
    approximate and act as a guide to the performance you can expect"). }
  GUIDE_NOTE = 'A ROUGH GUIDE ONLY - these times are extremely approximate: a guide to the performance you can expect';
var
  Hist: TBuildHistory;
  Models: array[0..1] of string;
  Speeds: array[0..1] of Double;
  Slow: array[0..1] of Boolean;
  Cells: TArray<TArray<string>>;
  Row: TArray<string>;
  Best, Footnote, Foot, Line: string;
  I, M: Integer;
  T: Double;
  AnySlow: Boolean;
begin
  Models[0] := BenchmarkModel(1);
  Models[1] := BenchmarkModel(2);
  AnySlow := False;
  for M := 0 to 1 do
  begin
    Speeds[M] := 0;
    if (Models[M] <> '') and not CalibrationBest(SettingsFile, Models[M], Best, Speeds[M]) then
      Speeds[M] := 0;
    Slow[M] := (FLowestSpeed > 0) and (Speeds[M] > 0) and (Speeds[M] < FLowestSpeed / 10);
    AnySlow := AnySlow or Slow[M];
  end;
  Hist := nil;
  try
    Hist := HistoryLoad(HistoryFile);
  except
    on E: Exception do
      DebugLog('calibration results: the history was not read: ' + E.Message);
  end;
  // the heading: each model with its speed here
  Row := ['Book (LibriVox recording)', 'Recording'];
  for M := 0 to 1 do
    if Speeds[M] > 0 then
      Row := Row + [Format('%s (%.1fx)', [NAMES[M], Speeds[M]])]
    else
      Row := Row + [NAMES[M]];
  Cells := [Row];
  for I := 0 to High(LIBRIVOX_BOOKS) do
  begin
    Row := [LIBRIVOX_BOOKS[I].Title, LongTime(LIBRIVOX_BOOKS[I].Seconds, False)];
    for M := 0 to 1 do
    begin
      T := 0;
      if Speeds[M] > 0 then
        T := BookSeconds(Hist, Models[M], LIBRIVOX_BOOKS[I].Seconds);
      if T <= 0 then
        Row := Row + ['-']
      else if Slow[M] then
        Row := Row + ['~' + LongTime(T, True) + ' *']
      else
        Row := Row + ['~' + LongTime(T, True)];
    end;
    Cells := Cells + [Row];
  end;
  // owner, 2026-11-22: "mention that better estimates will be available
  // after the user has transcribed a few books"
  Footnote := 'Better estimates come once you have transcribed a few books: they learn from this machine''s own ' +
    'builds.';
  Line := '';
  if AnySlow then
    Line := Format('* below the lowest acceptable speed (%.1fx): not used - Settings > Lowest acceptable speed',
      [FLowestSpeed / 10]);
  if (Speeds[0] <= 0) or (Speeds[1] <= 0) then
  begin
    if Line <> '' then
      Line := Line + '.  ';
    Line := Line + '- not installed or not calibrated';
  end;
  if Line <> '' then
    Footnote := Footnote + sLineBreak + Line;
  // no button named (a PlayStation pad has no A): any of them goes on
  if FBigPicture then
    Foot := 'Press any button to continue'
  else
    Foot := 'Press a key or click to continue';
  FCalView.OnButton := CalResultsButton;
  FCalView.ShowTable('Calibration results', GUIDE_NOTE, Cells, Footnote, Foot);
  FCalResults := True;
  // the same into the log
  LogLine('');
  LogLine('What that means for a book (' + GUIDE_NOTE + '):');
  for I := 0 to High(Cells) do
  begin
    Line := Format('  %-36s %12s', [Cells[I][0], Cells[I][1]]);
    for M := 2 to High(Cells[I]) do
      Line := Line + Format(' %16s', [Cells[I][M]]);
    LogLine(Line);
  end;
  for Line in Footnote.Split([sLineBreak]) do
    LogLine('  ' + Line);
end;

procedure TfrmBuilder.ApplyCalibration(ALog: Boolean);
var
  Dev: string;
  Speed: Double;
  I: Integer;
begin
  if (FModelPath = '') or (FWhisperNote <> '') then
    Exit;
  if CalibrationBest(SettingsFile, FModelPath, Dev, Speed) then
  begin
    for I := 0 to High(FDevices) do
      if SameText(FDevices[I].Name, Dev) then
      begin
        cbDevice.ItemIndex := I + 1;
        if ALog then
          LogLine(Format('Device: %s - the fastest for %s in the calibration (%s)', [Dev,
            ExtractFileName(FModelPath), CalibrationSummary(SettingsFile, FModelPath)]));
        Exit;
      end;
    if ALog then
      LogLine(Format('The calibration chose %s for %s, and whisper.cpp lists no %s now: Settings > Re-calibrate.',
        [Dev, ExtractFileName(FModelPath), Dev]));
  end
  else if ALog then
    LogLine(Format('%s is not calibrated on this machine: the device stays "%s". Settings > Re-calibrate times it ' +
      'on every device.', [ExtractFileName(FModelPath), cbDevice.Items[Max(0, cbDevice.ItemIndex)]]));
end;

procedure TfrmBuilder.CheckRocmDlc;
{$IF Defined(LINUX) and not Defined(ANDROID)}
var
  I: Integer;
  Amd, Rocm: Boolean;
  State: TSteamDlcState;
  D: string;
{$ENDIF}
begin
  {$IF Defined(LINUX) and not Defined(ANDROID)}
  if not SteamBuild or (STEAM_DLC_ROCM = 0) then
    Exit;
  // a Steam Deck (its gfx1033 is not a ROCm target), or the launcher found
  // no ROCm kernels for this GPU: the DLC would not help - nothing offered.
  // (No kernels at all - the DLC not installed - is what the DLC brings.)
  if SteamOnDeck or StartsText('no ROCm kernels here for', GetEnvironmentVariable('EPUBUNUM_ROCM_OFF')) then
  begin
    DebugLog('ROCm DLC: not offered - not for this GPU (' + IfThen(SteamOnDeck, 'a Steam Deck',
      Trim(GetEnvironmentVariable('EPUBUNUM_ROCM_OFF'))) + ')');
    Exit;
  end;
  Amd := False;
  Rocm := False;
  for I := 0 to High(FDevices) do
  begin
    D := FDevices[I].Description + ' ' + FDevices[I].Name;
    if ContainsText(D, 'AMD') or ContainsText(D, 'Radeon') then
      Amd := True;
    if SameText(FDevices[I].Backend, 'ROCm') or SameText(FDevices[I].Backend, 'HIP') or
      StartsText('ROCm', FDevices[I].Name) then
      Rocm := True;
  end;
  State := SteamDlcState(STEAM_DLC_ROCM);
  DebugLog(Format('ROCm DLC %d: state %d, AMD GPU %s, ROCm device %s', [STEAM_DLC_ROCM, Ord(State),
    BoolToStr(Amd, True), BoolToStr(Rocm, True)]));
  if not Amd or Rocm then
    Exit;
  if State = sdsInstalled then
    LogLine('The AMD ROCm acceleration DLC is installed, but whisper.cpp lists no ROCm device: the debug log''s ' +
      'whisper.cpp lines say why (ggml-hip; /dev/kfd, the GPU''s kernels). Vulkan is used meanwhile.')
  else if State <> sdsNoSteam then
  begin
    LogLine('This AMD GPU may transcribe faster with AMD ROCm acceleration, a free DLC: Settings > AMD ROCm ' +
      'acceleration.');
    FRocmOffer := True;
  end;
  {$ENDIF}
end;

procedure TfrmBuilder.miRocmClick(Sender: TObject);
begin
  LogLine('AMD ROCm acceleration: ' + SteamGetDlc(STEAM_DLC_ROCM));
end;

procedure TfrmBuilder.miHistoryClick(Sender: TObject);
begin
  ShowBuildHistory(Self, HistoryFile, HistoryMachine(MachineText));
end;

const
  { The languages offered (code, name); any other Whisper knows can be
    named in a queue file ("language"). }
  LANGUAGES: array[0..17, 0..1] of string = (('en', 'English'), ('de', 'German'), ('fr', 'French'),
    ('es', 'Spanish'), ('it', 'Italian'), ('nl', 'Dutch'), ('pt', 'Portuguese'), ('ru', 'Russian'),
    ('pl', 'Polish'), ('cs', 'Czech'), ('sv', 'Swedish'), ('da', 'Danish'), ('no', 'Norwegian'),
    ('fi', 'Finnish'), ('el', 'Greek'), ('tr', 'Turkish'), ('ja', 'Japanese'), ('zh', 'Chinese'));

procedure TfrmBuilder.FillLanguages(const ATag: string);
var
  I: Integer;
begin
  cbLanguage.Items.BeginUpdate;
  try
    cbLanguage.Items.Clear;
    if ATag = '' then
      cbLanguage.Items.Add('From the book (none given)')
    else
      cbLanguage.Items.Add('From the book (' + ATag + ')');
    for I := 0 to High(LANGUAGES) do
      cbLanguage.Items.Add(Format('%s (%s)', [LANGUAGES[I, 1], LANGUAGES[I, 0]]));
  finally
    cbLanguage.Items.EndUpdate;
  end;
  // a new book: its own language, until the user says otherwise
  cbLanguage.ItemIndex := 0;
end;

procedure TfrmBuilder.SelectLanguage(const ACode: string);
var
  K: Integer;
begin
  if cbLanguage = nil then
    Exit;
  cbLanguage.ItemIndex := 0;
  if ACode = '' then
    Exit;
  for K := 0 to High(LANGUAGES) do
    if SameText(LANGUAGES[K, 0], ACode) then
      cbLanguage.ItemIndex := K + 1;
end;

function TfrmBuilder.ChosenLanguage: string;
begin
  Result := '';
  if (cbLanguage <> nil) and (cbLanguage.ItemIndex >= 1) and (cbLanguage.ItemIndex - 1 <= High(LANGUAGES)) then
    Result := LANGUAGES[cbLanguage.ItemIndex - 1, 0];
end;

procedure TfrmBuilder.miSettingsClick(Sender: TObject);
begin
  if FPadMenu = nil then
    Exit;
  PadHome(BPC_MODEL);
  FPadSettingsOnly := True;
end;

procedure TfrmBuilder.ChooseFolder(AKind: Integer);
const
  NAMES: array[0..2] of string = ('Books folder (the EPUBs to read along)', 'Audio folder (the recordings)',
    'Output folder (the books made)');
var
  K: Integer;
  Folder: string;
begin
  K := EnsureRange(AKind, 0, 2);
  case K of
    0: Folder := FBookFolder;
    1: Folder := FAudioFolder;
  else
    Folder := FOutFolder;
  end;
  if not SelectDirectory(NAMES[K], '', Folder) then
    Exit;
  Folder := ExcludeTrailingPathDelimiter(Folder);
  case K of
    0: FBookFolder := Folder;
    1: FAudioFolder := Folder;
  else
    begin
      FOutFolder := Folder;
      // the book's output follows, unless the user named it
      if (edBook.Text <> '') and SameFileName(edOut.Text, FAutoOut) then
      begin
        edOut.Text := DefaultOutput(edBook.Text);
        FAutoOut := edOut.Text;
      end;
    end;
  end;
  LogLine(NAMES[K] + ': ' + Folder);
  SaveSettings;
  UpdateControls;
end;

function TfrmBuilder.DefaultOutput(const ABook: string): string;

  { A job of the queue writes AFile. }
  function Queued(const AFile: string): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    for I := 0 to High(FJobs) do
      if (FJobs[I].State in [jsWaiting, jsRunning]) and SameFileName(ExpandFileName(FJobs[I].Output), AFile) then
        Exit(True);
  end;

var
  Name: string;
  N: Integer;
begin
  Name := ChangeFileExt(ExtractFileName(ABook), '');
  Result := TPath.Combine(FOutFolder, Name + '.epub');
  N := 0;
  // the book itself (chosen from the output folder) counts as taken too
  while FileExists(Result) or Queued(ExpandFileName(Result)) do
  begin
    Inc(N);
    Result := TPath.Combine(FOutFolder, Format('%s_%.3d.epub', [Name, N]));
  end;
end;

procedure TfrmBuilder.miCalibrationClick(Sender: TObject);
var
  Ini: TMemIniFile;
  Sections, Crashes: TStringList;
  Done, DontAsk: Boolean;
  Key, Made, Model: string;
  I, P: Integer;
begin
  CalibrationState(SettingsFile, Done, DontAsk, Key, Made);
  LogLine('');
  if not Done then
  begin
    LogLine('Not calibrated on this machine yet: Settings > Re-calibrate.');
    Exit;
  end;
  LogLine(Format('Calibration of %s:', [Made]));
  if not SameText(Key, CalibrationDevicesKey(FDevices)) then
    LogLine('  THE DEVICES HAVE CHANGED SINCE: Settings > Re-calibrate.');
  Ini := TMemIniFile.Create(SettingsFile, TEncoding.UTF8);
  Sections := TStringList.Create;
  try
    Ini.ReadSections(Sections);
    for I := 0 to Sections.Count - 1 do
      if StartsText(CAL_SECTION + ' ', Sections[I]) and not SameText(Sections[I], CAL_CRASH_SECTION) then
      begin
        Model := Copy(Sections[I], Length(CAL_SECTION) + 2, MaxInt);
        LogLine(Format('  %s: %s - %s', [Model, IfThen(Ini.ReadString(Sections[I], 'Best', '') = '',
          'NO DEVICE COULD RUN IT', 'best ' + Ini.ReadString(Sections[I], 'Best', '')),
          CalibrationSummary(SettingsFile, Model)]));
      end;
  finally
    Sections.Free;
    Ini.Free;
  end;
  Crashes := CalibrationCrashes(SettingsFile);
  try
    for I := 0 to Crashes.Count - 1 do
    begin
      P := Pos(#9, Crashes[I]);
      LogLine(Format('  %s on %s ended the program: left out until Settings > Re-calibrate', [Copy(Crashes[I], 1,
        P - 1), Copy(Crashes[I], P + 1, MaxInt)]));
    end;
  finally
    Crashes.Free;
  end;
  LogLine('Log of the last calibration: ' + ChangeFileExt(SettingsFile, CALIBRATION_LOG_SUFFIX));
end;

function TfrmBuilder.UsesCoreML(const AModel: string): Boolean;
begin
  Result := FCoreML and (AModel <> '') and TDirectory.Exists(ModelEncoderPath(AModel));
end;

function TfrmBuilder.HistoryFile: string;
begin
  Result := ChangeFileExt(SettingsFile, HISTORY_SUFFIX);
end;

procedure TfrmBuilder.PrepareEstimate(const AModel, ADevice: string);
var
  D: TWhisperDevice;
  Dev: string;
begin
  FExpSpeed := 0;
  FExpAfter := 0;
  FExpPrior := 0;
  FExpSource := '';
  FExpDevice := '';
  if AModel = '' then
    Exit;
  // the device by name, as the history has it (whisper.cpp's choice
  // resolved)
  Dev := ADevice;
  if BuilderFindDevice(ADevice, D) then
    Dev := D.Name;
  // Core ML is history of its own: the same device, another speed
  FExpDevice := Dev;
  if UsesCoreML(AModel) then
    FExpDevice := Dev + '+CoreML';
  HistoryExpect(HistoryLoad(HistoryFile), HistoryMachine(MachineText), ExtractFileName(AModel), FExpDevice,
    CalibrationSpeed(SettingsFile, AModel, Dev), CalibrationSeconds(SettingsFile, AModel), FExpSpeed, FExpAfter,
    FExpPrior, FExpSource);
end;

function TfrmBuilder.AudioDoneAt(APercent: Double): Double;
begin
  Result := FAudioTotal * EnsureRange((APercent - 5) / 85, 0.0, 1.0);
end;

procedure TfrmBuilder.RecordHistory(const ASummary: TBuildSummary);
var
  R: TBuildHistoryRow;
  Why: string;
begin
  // a saved transcript was not transcribed: nothing to learn
  if ASummary.SavedTranscript or (ASummary.TranscribeSeconds <= 0) or (ASummary.AudioSeconds <= 0) then
    Exit;
  R.Made := Now;
  R.Machine := HistoryMachine(ASummary.Machine);
  R.Model := ASummary.Model;
  R.Device := ASummary.Device;
  // with '+CoreML' when the model's encoder was used (PrepareEstimate)
  if SameText(Copy(FExpDevice, 1, Length(ASummary.Device)), ASummary.Device) and (FExpDevice <> '') then
    R.Device := FExpDevice;
  R.AudioSeconds := ASummary.AudioSeconds;
  R.TranscribeSeconds := ASummary.TranscribeSeconds;
  R.AfterSeconds := 0;
  if FAfterFrom <> 0 then
    R.AfterSeconds := MilliSecondsBetween(Now, FAfterFrom) / 1000;
  R.CalibrationSpeed := CalibrationSpeed(SettingsFile, ASummary.Model, ASummary.Device);
  // which kind of calibration that speed is of (zip 242: like with like)
  R.CalibrationSeconds := 0;
  if R.CalibrationSpeed > 0 then
    R.CalibrationSeconds := CalibrationSeconds(SettingsFile, ASummary.Model);
  // exact of the words between the first and the last word read: front
  // and back matter left out, so an EPUB with extras (Hitchhiker's Guide:
  // 28253 words around the reading) does not look like a poor build
  R.ExactPercent := 0;
  if ASummary.Stats.BookWords - ASummary.EdgeWords > 0 then
    R.ExactPercent := ASummary.Stats.Exact * 100 / (ASummary.Stats.BookWords - ASummary.EdgeWords);
  R.MatchedPercent := ASummary.Matched;
  // which book (owner, 2026-11-19: the history "lacks a title")
  R.Title := ASummary.Title;
  R.Language := ASummary.Language;
  R.OutputName := ExtractFileName(FRunOut);
  FLastResult := Format('Last: %s - %.1fx real time, matched %.1f %%', [R.Title, HistorySpeed(R),
    R.MatchedPercent]);
  if FExpSpeed > 0 then
    LogLine(Format('Speed: %.1fx real time (expected %.1fx); exact %.1f %%, matched %.1f %%.',
      [HistorySpeed(R), FExpSpeed, R.ExactPercent, R.MatchedPercent]))
  else
    LogLine(Format('Speed: %.1fx real time; exact %.1f %%, matched %.1f %%.', [HistorySpeed(R), R.ExactPercent,
      R.MatchedPercent]));
  // a diagnostic build's speed is not a build's: the time estimates must
  // not learn from it
  if ASummary.Diagnostic <> '' then
  begin
    LogLine(Format('DIAGNOSTIC build (%s): not kept in the build history.', [ASummary.Diagnostic]));
    Exit;
  end;
  Why := HistoryAdd(HistoryFile, R);
  if Why = '' then
    LogLine('Kept in the build history: ' + HistoryFile)
  else
    LogLine('The build history was not written: ' + Why);
end;

procedure TfrmBuilder.LogMachine(const AModel, ADevice: string);
var
  D: TWhisperDevice;
  Best: string;
  Speed: Double;
begin
  LogLine('Machine: ' + MachineText);
  LogLine('EpubBuilder build: ' + BuildStamp);
  if SteamBuild then
    LogLine(SteamText);
  if FWhisperText <> '' then
    LogLine(FWhisperText);
  if AModel = '' then
    Exit;
  LogLine('Device: ' + BuilderDeviceText(ADevice));
  if UsesCoreML(AModel) then
    LogLine('  Core ML encoder: ' + ModelEncoderPath(AModel))
  else if FCoreML then
    LogLine('  no Core ML encoder for this model: its encoder runs on the device above');
  if not BuilderFindDevice(ADevice, D) then
    Exit;
  if CalibrationBest(SettingsFile, AModel, Best, Speed) then
  begin
    if SameText(Best, D.Name) then
      LogLine(Format('  the fastest for %s in the calibration (%s)', [ExtractFileName(AModel),
        CalibrationSummary(SettingsFile, AModel)]))
    else
      LogLine(Format('  NOT the fastest for %s: the calibration found %s (%s)', [ExtractFileName(AModel), Best,
        CalibrationSummary(SettingsFile, AModel)]));
  end
  else
    LogLine(Format('  %s is not calibrated on this machine (Settings > Re-calibrate)', [ExtractFileName(AModel)]));
end;

initialization
  GSleepGate := TEvent.Create(nil, True, True, '');

finalization
  FreeAndNil(GSleepGate);

end.
