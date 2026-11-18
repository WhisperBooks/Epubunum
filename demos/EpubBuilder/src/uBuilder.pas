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
  Epub.Zip, Epub.Book, Epub.Layout, Epub.Writer,
  FFmpeg.API, FFmpeg.Media,
  Whisper.Types, Whisper.API, Whisper.Audio, Whisper.Core, Whisper.Words, Whisper.Align, Whisper.AudioSet,
  uDebugLog, uMachine, uCalibration, uHistory, uModels, uSteam, uInhibit, uQuitSignal;

type
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
  protected
    { The build. }
    procedure Execute; override;
  public
    { A build of ABookFile with AAudioFiles into AOutFile (not started:
      call Start). }
    constructor Create(const ABookFile: string; AAudioFiles: TStrings; const AModelFile, ADevice,
      AOutFile: string; AChapters, AReuse: Boolean);
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
    { Settings, Create and the log, below the sides. }
    layBottom: TLayout;
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
    { Model > Folder...: where the models are kept (not in Steam builds:
      there they are in the program's folder). }
    btnModelFolder: TButton;
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
    { The computer is kept awake (a build, queue, calibration or download
      runs) - see uInhibit. }
    FAwake: Boolean;
    { The device to transcribe on. }
    cbDevice: TComboBox;
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
    { The books folder: where Book... opens (Tools > Folders; default
      Documents/EpubBuilder/Books). }
    FBookFolder: string;
    { The audio folder: where Add audio... opens (default
      Documents/EpubBuilder/Audio). }
    FAudioFolder: string;
    { The output folder: where a chosen book's EPUB 3 goes by default
      (default Documents/EpubBuilder/Output). }
    FOutFolder: string;
    { The output name given by DefaultOutput for the book in the window
      (Tools > Output folder renames it only while it is unchanged). }
    FAutoOut: string;
    { The chosen book's title. }
    FBookTitle: string;
    { The job queue: left of the book. }
    layQueue: TLayout;
    { Between the queue and the book. }
    splQueue: TSplitter;
    { The jobs. }
    lbJobs: TListBox;
    { Runs the waiting jobs one after the other. }
    btnRunQueue: TButton;
    { Adds the window's book, audio and settings to the queue. }
    btnAddJob: TButton;
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
    { Tools > Re-calibrate (this model). }
    miCalibrate: TMenuItem;
    { Tools > Re-calibrate every model in the model's folder. }
    miCalibrateAll: TMenuItem;
    { Tools > Get AMD ROCm acceleration (free DLC): Linux Steam builds, an
      AMD GPU without a ROCm device (CheckRocmDlc). }
    miRocm: TMenuItem;
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
    { Appends a line to the log. }
    procedure LogLine(const AText: string);
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
    { Model > Folder...: another models folder (kept in the settings). }
    procedure btnModelFolderClick(Sender: TObject);
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
      -1 for Create's build). }
    procedure StartJob(const AJob: TBuildJob; AIndex: Integer);
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
    { Tools > Re-calibrate (this model). }
    procedure miCalibrateClick(Sender: TObject);
    { Tools > Re-calibrate every model in its folder. }
    procedure miCalibrateAllClick(Sender: TObject);
    { Tools > Calibration results: what is kept, model by model. }
    procedure miCalibrationClick(Sender: TObject);
    { Tools > Build history: every build's speed and accuracy, a table. }
    procedure miHistoryClick(Sender: TObject);
    { Tools > Get AMD ROCm acceleration: SteamGetDlc. }
    procedure miRocmClick(Sender: TObject);
    { Tools > Books folder... / Audio folder... / Output folder...: the
      three folders (Tag 0, 1, 2 of the item). }
    procedure miFolderClick(Sender: TObject);
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
  end;

var
  { The window. }
  frmBuilder: TfrmBuilder;

implementation

{$R *.fmx}

const
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

{ Where the settings live, the platform's way: Windows
  %APPDATA%\EpubBuilder\EpubBuilder.ini, macOS ~/Library/Application
  Support/EpubBuilder/EpubBuilder.ini, Linux $XDG_CONFIG_HOME (else
  ~/.config)/EpubBuilder/EpubBuilder.ini. }
function SettingsFile: string;
var
  Base: string;
begin
  {$IF Defined(MSWINDOWS)}
  Base := TPath.GetHomePath;   // %APPDATA% (Roaming)
  {$ELSEIF Defined(MACOS)}
  Base := TPath.Combine(TPath.GetHomePath, 'Library/Application Support');
  {$ELSE}
  Base := GetEnvironmentVariable('XDG_CONFIG_HOME');
  if Base = '' then
    Base := TPath.Combine(TPath.GetHomePath, '.config');
  {$ENDIF}
  Result := TPath.Combine(TPath.Combine(Base, 'EpubBuilder'), 'EpubBuilder.ini');
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

{ TBuildThread }

constructor TBuildThread.Create(const ABookFile: string; AAudioFiles: TStrings; const AModelFile, ADevice,
  AOutFile: string; AChapters, AReuse: Boolean);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FBookFile := ABookFile;
  FAudioFiles := TStringList.Create;
  FAudioFiles.Assign(AAudioFiles);
  FModelFile := AModelFile;
  FDevice := ADevice;
  FOutFile := AOutFile;
  FJsonFile := TranscriptFileOf(AOutFile);
  FChapters := AChapters;
  FReuse := AReuse;
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
  Status(Format('Part %d of %d at %s: %s', [FPartNo, FPartCount,
    WhisperTimeToStr(ASegment.T0 + Round(FPartOffset * WHISPER_TICKS_PER_SECOND)), Trim(ASegment.Text)]));
end;

procedure TBuildThread.RunProgress(Sender: TObject; AProgress: Integer);
begin
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

function TBuildThread.Transcribe(AAudio: TWhisperAudioSet): TWhisperTranscription;
var
  Lib: TWhisperLib;
  CP: TWhisperContextParams;
  Model: TWhisperModel;
  Params: TWhisperParams;
  Samples: TWhisperSamples;
  Part: TWhisperTranscription;
  I: Integer;
  Started: TDateTime;
  Prompt: string;
begin
  Result := Default(TWhisperTranscription);
  Lib := TWhisperLib.Instance;
  CP := Lib.DefaultContextParams;
  if not Lib.ContextParamsFor(FDevice, CP) then
    raise EWhisperError.CreateFmt('Device %s cannot be used', [FDevice]);
  // word times by DTW: the alignment heads of this model
  if not WhisperEnableDtw(FModelFile, CP) then
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
      for I := 0 to High(AAudio.Parts) do
      begin
        if Terminated then
          Break;
        Started := Now;
        FPartNo := I + 1;
        FPartOffset := AAudio.Parts[I].Offset;
        Status(Format('Part %d of %d "%s": decoding the audio ...', [I + 1, FPartCount, AAudio.Parts[I].Title]));
        Samples := AAudio.Read(I);
        FPartSeconds := WhisperSamplesSeconds(Samples);
        if Length(Samples) = 0 then
          Continue;
        Status(Format('Part %d of %d "%s": transcribing (the words appear as they are heard) ...', [I + 1,
          FPartCount, AAudio.Parts[I].Title]));
        Part := FRun.Execute(Samples);
        if Part.Cancelled then
          Break;
        // a part that failed ends the build: going on gave a book with
        // part of its audio timed, reported as done, and kept the cut
        // transcript "for next time" (review, zip 73)
        if Part.ResultCode <> 0 then
          raise EWhisperError.CreateFmt('Part %d of %d "%s" was not transcribed: %s', [I + 1, FPartCount,
            AAudio.Parts[I].Title, Part.ErrorMessage]);
        // as WhisperConsole: take out loops and echoes, then a second pass
        // over the stretches left without words
        WhisperCleanTranscription(Part, Prompt);
        Status(Format('Part %d of %d: second pass over stretches left without words ...', [I + 1, FPartCount]));
        FRun.FillGaps(Samples, Part);
        // the pause before a word is not the word: DTW starts the first
        // word after a pause in it (the next sentence lit too early)
        WhisperTrimWordSilence(Part, Samples);
        WhisperAppendTranscription(Result, Part, AAudio.Parts[I].Offset);
        // keep the language the first part was heard in
        if SameText(Params.Language, WHISPER_LANGUAGE_AUTO) and (Part.LanguageCode <> '') then
          Params.Language := Part.LanguageCode;
        FDoneSeconds := FDoneSeconds + FPartSeconds;
        Log(Format('Part %d of %d "%s": %.0f s of audio, %d words, %.1f s', [I + 1, Length(AAudio.Parts),
          AAudio.Parts[I].Title, FPartSeconds, Length(Part.Words), MilliSecondsBetween(Now, Started) / 1000]));
      end;
    finally
      FreeAndNil(FRun);
    end;
  finally
    Params.Free;
    Model.Free;
  end;
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
      Book := TEpubBook.Create(FBookFile);
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
      FSummary.Language := FLanguage;
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
        FSummary.TranscribeSeconds := MilliSecondsBetween(Now, Started) / 1000;
        FSummary.Model := ExtractFileName(FModelFile);
        if Terminated then
        begin
          Log('Cancelled');
          Exit;
        end;
        Parts := Audio.Parts;
        SaveTranscript(R, Parts, ExtractFileName(FModelFile), FormatDateTime('yyyy-mm-dd hh:nn', Now));
        Log(Format('Transcript kept for next time: %s (%d words)', [FJsonFile, Length(R.Words)]));
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
      Files := WhisperPartFiles(Parts);
      Times := WhisperWordFileTimes(Joined, Parts, Files);
      Progress(93);
      if Terminated then
        Exit;

      // 5. the book with overlays and the audio inside
      Writer := TEpubWriter.Create(Book);
      // marked as ours: choosing this book again is warned about
      Writer.WrittenBy := 'EpubBuilder';
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
begin
  // below: settings, Create / Cancel, progress, log
  layBottom := TLayout.Create(Self);
  layBottom.Parent := Self;
  layBottom.Align := TAlignLayout.Bottom;
  layBottom.Height := 360;

  Row := AddRow(layBottom, 'Model');
  cbModel := TComboBox.Create(Self);
  cbModel.Parent := Row;
  cbModel.Align := TAlignLayout.Client;
  cbModel.OnChange := cbModelChange;
  btnModelFolder := AddButton(Row, 'Folder...', btnModelFolderClick, TAlignLayout.Right);
  // Steam: the models are in the program's folder
  btnModelFolder.Visible := not SteamBuild;

  Row := AddRow(layBottom, 'Device');
  cbDevice := TComboBox.Create(Self);
  cbDevice.Parent := Row;
  cbDevice.Align := TAlignLayout.Left;
  cbDevice.Width := 420;

  Row := AddRow(layBottom, 'Output EPUB');
  edOut := TEdit.Create(Self);
  edOut.Parent := Row;
  edOut.Align := TAlignLayout.Client;
  AddButton(Row, 'Choose...', btnOutClick, TAlignLayout.Right);

  Row := AddRow(layBottom, '');
  chkChapters := TCheckBox.Create(Self);
  chkChapters.Parent := Row;
  chkChapters.Align := TAlignLayout.Left;
  chkChapters.Width := 260;
  chkChapters.Text := 'Chapters of a file are parts (m4b)';
  chkChapters.IsChecked := True;
  chkReuse := TCheckBox.Create(Self);
  chkReuse.Parent := Row;
  chkReuse.Align := TAlignLayout.Left;
  chkReuse.Position.X := 100000;
  chkReuse.Width := 420;
  chkReuse.Text := 'Use a saved transcript (re-align in seconds, no new transcription)';
  // off at every start: reusing old words is a choice made for one build
  // (owner: "if re-transcribing there is obviously a reason"); not kept in
  // the settings
  chkReuse.IsChecked := False;
  chkReuse.OnChange := chkReuseChange;

  Buttons := AddRow(layBottom, '');
  btnCreate := AddButton(Buttons, 'Create', btnCreateClick, TAlignLayout.Left, 120);
  btnAddJob := AddButton(Buttons, 'Add to queue', btnAddJobClick, TAlignLayout.Left, 120);
  btnAddJob.Position.X := 100000;
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

  // the job queue: leftmost (owner: "a 3rd column ... on the left ... with
  // a Run Queue at the bottom of it")
  ClientWidth := Max(ClientWidth, 1300);
  layQueue := TLayout.Create(Self);
  layQueue.Parent := Self;
  layQueue.Position.X := 0;
  layQueue.Align := TAlignLayout.Left;
  layQueue.Width := 300;
  AddCaption(layQueue, 'Job queue');
  Row := AddRow(layQueue, '');
  Row.Position.Y := 30;
  AddButton(Row, 'Load...', btnJobLoadClick, TAlignLayout.Left, 64);
  AddButton(Row, 'Save...', btnJobSaveClick, TAlignLayout.Left, 64);
  AddButton(Row, 'Remove', btnJobRemoveClick, TAlignLayout.Left, 64);
  AddButton(Row, 'Up', btnJobUpClick, TAlignLayout.Left, 40);
  AddButton(Row, 'Down', btnJobDownClick, TAlignLayout.Left, 48);
  btnRunQueue := TButton.Create(Self);
  btnRunQueue.Parent := layQueue;
  btnRunQueue.Align := TAlignLayout.Bottom;
  btnRunQueue.Height := 36;
  btnRunQueue.Margins.Rect := RectF(GAP, GAP, GAP, GAP);
  btnRunQueue.Text := 'Run queue';
  btnRunQueue.OnClick := btnRunQueueClick;
  lbJobs := TListBox.Create(Self);
  lbJobs.Parent := layQueue;
  lbJobs.Align := TAlignLayout.Client;
  lbJobs.Margins.Rect := RectF(GAP, GAP, GAP, 0);
  lbJobs.OnDblClick := lbJobsDblClick;
  splQueue := TSplitter.Create(Self);
  splQueue.Parent := Self;
  splQueue.Position.X := 1;
  splQueue.Align := TAlignLayout.Left;
  splQueue.Width := 5;
  tmQueue := TTimer.Create(Self);
  tmQueue.Enabled := False;
  tmQueue.Interval := 50;
  tmQueue.OnTimer := tmQueueTimer;

  // the book: left of the audio
  layBook := TLayout.Create(Self);
  layBook.Parent := Self;
  layBook.Position.X := 2;
  layBook.Align := TAlignLayout.Left;
  layBook.Width := 470;
  AddCaption(layBook, 'Book (EPUB)');
  Row := AddRow(layBook, '');
  Row.Position.Y := 30;
  edBook := TEdit.Create(Self);
  edBook.Parent := Row;
  edBook.Align := TAlignLayout.Client;
  edBook.ReadOnly := True;
  AddButton(Row, 'Choose...', btnBookClick, TAlignLayout.Right);
  mmBook := TMemo.Create(Self);
  mmBook.Parent := layBook;
  mmBook.Align := TAlignLayout.Client;
  mmBook.Margins.Rect := RectF(GAP, GAP, GAP, GAP);
  mmBook.ReadOnly := True;
  mmBook.WordWrap := True;

  splSides := TSplitter.Create(Self);
  splSides.Parent := Self;
  splSides.Align := TAlignLayout.Left;
  splSides.Position.X := 100000;
  splSides.Width := 5;

  // the audio: right
  layAudio := TLayout.Create(Self);
  layAudio.Parent := Self;
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
  Line: string;
begin
  OnCloseQuery := FormCloseQuery;
  OnShow := FormShow;
  // the debug log: next to the settings, started afresh at every run
  DebugLogOpen(ChangeFileExt(SettingsFile, '-debug.log'));
  // Steam's Exit Game ends the program with SIGTERM: save first (owner)
  if QuitSignalInstall(QuitSignalled) then
    DebugLog('SIGTERM / SIGINT / SIGHUP: saved before the program ends');
  Line := QuitSignalLast(ChangeFileExt(SettingsFile, QUIT_NOTE_SUFFIX));
  if Line <> '' then
    DebugLog(Line);
  // a crash in a library (Steam Deck, 2026-11-17): logged with where it was
  Application.OnException := AppException;
  FJob := -1;
  FBuildLog := TStringList.Create;
  FModelItems := TStringList.Create;
  BuildWindow;
  BuildMenu;
  cbDevice.Items.Add('Default (whisper.cpp chooses)');
  try
    DebugLog('whisper.cpp: loading');
    Lib := TWhisperLib.Load;
    // whisper.cpp's and ggml's own lines (every level), as they are written
    Lib.AddLogListener(WhisperLog);
    FDevices := Lib.SelectableDevices;
    for I := 0 to High(FDevices) do
      DebugLog('device: ' + WhisperDeviceText(FDevices[I]));
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
  LoadSettings;
  // the three folders there from the start (the dialogs open in them)
  try
    ForceDirectories(FBookFolder);
    ForceDirectories(FAudioFolder);
    ForceDirectories(FOutFolder);
  except
    on E: Exception do
      LogLine('A folder was not made: ' + E.Message);
  end;
  FillModels;
  LogLine('Models folder: ' + FModelsFolder);
  LogLine(Format('Folders: books %s, audio %s, output %s (Tools to change)', [FBookFolder, FAudioFolder,
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
  // Documents/EpubBuilder/... until Tools > ... folder chooses others
  Docs := TPath.Combine(TPath.GetDocumentsPath, 'EpubBuilder');
  FBookFolder := TPath.Combine(Docs, 'Books');
  FAudioFolder := TPath.Combine(Docs, 'Audio');
  FOutFolder := TPath.Combine(Docs, 'Output');
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
      Device := Ini.ReadString('Build', 'Device', '');
      for I := 0 to High(FDevices) do
        if SameText(FDevices[I].Name, Device) then
          cbDevice.ItemIndex := I + 1;
      chkChapters.IsChecked := Ini.ReadBool('Build', 'Chapters', True);
      FBookFolder := FolderSetting('Book', FBookFolder);
      FAudioFolder := FolderSetting('Audio', FAudioFolder);
      FOutFolder := FolderSetting('Output', FOutFolder);
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
        Ini.WriteString('Build', 'Device', FDevices[cbDevice.ItemIndex - 1].Name)
      else
        Ini.WriteString('Build', 'Device', '');
      Ini.WriteBool('Build', 'Chapters', chkChapters.IsChecked);
      // no longer kept (off at every start)
      Ini.DeleteKey('Build', 'UseSavedTranscript');
      Ini.WriteString('Folders', 'Book', FBookFolder);
      Ini.WriteString('Folders', 'Audio', FAudioFolder);
      Ini.WriteString('Folders', 'Output', FOutFolder);
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
  if FBuild = nil then
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
    sLineBreak + 'Closing stops it, and its work so far is lost - a transcription is kept only when all its ' +
    'parts are done.%s' + sLineBreak + sLineBreak + 'Stop the build and close?', [FPercent, FStatusText, Queue]),
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
    What := Format('calibrating (%.0f %%)', [FPercent])
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
      LogLine('The build was stopped part way: its transcription so far is lost (Create again).');
      FBuildLog.SaveToFile(FRunOut + '.log', TEncoding.UTF8);
    end
    else if (FCalib <> nil) and (FBuildLog <> nil) then
    begin
      LogLine('The calibration was stopped part way: nothing of it was kept.');
      FBuildLog.SaveToFile(ChangeFileExt(SettingsFile, CALIBRATION_LOG_SUFFIX), TEncoding.UTF8);
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
  FreeAndNil(FBuildLog);
  FreeAndNil(FModelItems);
end;

procedure TfrmBuilder.LogLine(const AText: string);
begin
  DebugLog(AText);
  mmLog.Lines.Add(AText);
  mmLog.GoToTextEnd;
  if FLogging and (FBuildLog <> nil) then
    FBuildLog.Add(AText);
end;

procedure TfrmBuilder.UpdateControls;
var
  Busy, Ready, Waiting: Boolean;
  I: Integer;
begin
  Busy := (FBuild <> nil) or FQueueRunning or (FCalib <> nil) or (FDownload <> nil);
  if Busy <> FAwake then
  begin
    // SteamOS (Game Mode) and laptops sleep with nobody at the controls,
    // half way through an hour's transcription (owner, Steam Machine)
    FAwake := Busy;
    if Busy then
      InhibitStart(ikSleep, 'Building an audiobook')
    else
      InhibitStop(ikSleep);
    LogLine(IfThen(Busy, 'keeping the computer awake: ', 'letting the computer sleep: ') + InhibitText);
  end;
  Ready := (FWhisperNote = '') and (edBook.Text <> '') and (lbAudio.Count > 0) and (edOut.Text <> '') and
    ((FModelPath <> '') or chkReuse.IsChecked);
  // the window stays usable while building: books are added to the queue
  // while it runs (owner)
  btnCreate.Enabled := not Busy and Ready;
  btnAddJob.Enabled := Ready;
  btnCancel.Enabled := (FBuild <> nil) or (FCalib <> nil) or (FDownload <> nil);
  // one download at a time; the model stays while it runs
  cbModel.Enabled := FDownload = nil;
  btnModelFolder.Enabled := FDownload = nil;
  if miCalibrate <> nil then
  begin
    miCalibrate.Enabled := not Busy and (FWhisperNote = '');
    // an item's Enabled reaches the system's menu by itself (only new
    // items need RecreateOSMenu); StartCalibration checks again anyway
    miCalibrateAll.Enabled := miCalibrate.Enabled;
  end;
  Waiting := False;
  for I := 0 to High(FJobs) do
    if FJobs[I].State <> jsDone then
      Waiting := True;
  btnRunQueue.Enabled := not Busy and Waiting;
  if FQueueRunning then
    btnRunQueue.Text := 'Queue running ...'
  else
    btnRunQueue.Text := 'Run queue';
end;

procedure TfrmBuilder.ShowBook(const AFileName: string);
var
  Book: TEpubBook;
  Audio: TStringList;
begin
  mmBook.Lines.Clear;
  FBookTitle := '';
  FBookWrittenBy := '';
  FBookClips := 0;
  try
    Book := TEpubBook.Create(AFileName);
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
          LogLine('Another book: the audio list was emptied.');
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
          LogLine(Format('%s is copy protected (%s) and was not added. EpubBuilder does not remove copy ' +
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
    D.Filter := 'EPUB books (*.epub)|*.epub';
    D.InitialDir := FBookFolder;
    if D.Execute then
      ShowBook(D.FileName);
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
      AddAudio(D.Files);
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
  try
    L := WhisperListAudioFiles(Folder);
    try
      AddAudio(L);
    finally
      L.Free;
    end;
  except
    on E: Exception do
      LogLine(E.Message);
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
      TDialogService.MessageDialog(Format('%s has no Core ML encoder here: its encoder runs on Metal.' +
        sLineBreak + sLineBreak + 'Download the Core ML encoder (about %s) so it runs on the Neural Engine? ' +
        'Its first use is slow: macOS compiles it for this Mac.', [Name,
        ModelSizeText(MODEL_CATALOGUE[I].EncoderMB)]), TMsgDlgType.mtConfirmation,
        [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0,
        procedure(const AResult: TModalResult)
        begin
          if AResult = mrYes then
            StartDownload(Name, False, True);
        end);
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
  TDialogService.MessageDialog(Format('%s is not downloaded yet.' + sLineBreak + sLineBreak + 'Download it now? ' +
    '%s, from whisper.cpp''s model repository on Hugging Face, into' + sLineBreak + '%s',
    [Name, Amount, FModelsFolder]), TMsgDlgType.mtConfirmation,
    [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbYes, 0,
    procedure(const AResult: TModalResult)
    begin
      if AResult = mrYes then
        StartDownload(Name, True, FCoreML)
      else
        FillModels;   // back to the model chosen before
    end);
end;

procedure TfrmBuilder.btnModelFolderClick(Sender: TObject);
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
  I, Sel: Integer;
  Path, Item: string;
begin
  FFillingModels := True;
  try
    cbModel.Items.BeginUpdate;
    try
      cbModel.Items.Clear;
      FModelItems.Clear;
      Sel := -1;
      // the catalogue, smallest first
      for I := Low(MODEL_CATALOGUE) to High(MODEL_CATALOGUE) do
      begin
        Path := TPath.Combine(FModelsFolder, ModelFileName(MODEL_CATALOGUE[I].Name));
        if not FileExists(Path) then
          Item := Format('%s - %s (%s to download)', [MODEL_CATALOGUE[I].Name, MODEL_CATALOGUE[I].Note,
            ModelSizeText(MODEL_CATALOGUE[I].SizeMB)])
        else if FCoreML and UsesCoreML(Path) then
          Item := Format('%s - %s (Core ML)', [MODEL_CATALOGUE[I].Name, MODEL_CATALOGUE[I].Note])
        else if FCoreML then
          Item := Format('%s - %s (no Core ML encoder)', [MODEL_CATALOGUE[I].Name, MODEL_CATALOGUE[I].Note])
        else
          Item := Format('%s - %s', [MODEL_CATALOGUE[I].Name, MODEL_CATALOGUE[I].Note]);
        cbModel.Items.Add(Item);
        FModelItems.Add(Path);
        if SameFileName(Path, FModelPath) then
          Sel := FModelItems.Count - 1;
      end;
      // other models in the folder (quantised, fine-tuned, older ones)
      if TDirectory.Exists(FModelsFolder) then
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
      cbModel.Items.Add('Other model file ...');
      FModelItems.Add('');
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

procedure TfrmBuilder.DownloadDone(Sender: TObject);
var
  D: TModelDownload;
begin
  // the thread frees itself after this (FreeOnTerminate)
  D := Sender as TModelDownload;
  FDownload := nil;
  pbBuild.Value := 0;
  if D.Succeeded then
  begin
    FModelPath := D.Target;
    lblStatus.Text := 'Downloaded ' + D.ModelName;
    ApplyCalibration(True);
    if CalibrationSummary(SettingsFile, FModelPath) = '' then
      LogLine(D.ModelName + ' is not calibrated yet: Tools > Re-calibrate (this model) finds its fastest device.')
    else if D.WithEncoder then
      LogLine(D.ModelName + ' was calibrated without its Core ML encoder: Tools > Re-calibrate (this model) ' +
        'times it with it (the first run compiles the encoder - slow once).');
    SaveSettings;
  end
  else
    lblStatus.Text := 'Download not finished: ' + D.ModelName;
  FillModels;
  UpdateControls;
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
    D.FileName := edOut.Text;
    if D.Execute then
      edOut.Text := D.FileName;
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
  CheckThen(True);
end;

procedure TfrmBuilder.CheckThen(AQueue: Boolean);
var
  Device: string;
begin
  if SameFileName(ExpandFileName(edOut.Text), ExpandFileName(edBook.Text)) then
  begin
    LogLine('The output must not be the book itself: choose another output file.');
    Exit;
  end;
  if (FModelPath = '') and not (chkReuse.IsChecked and FileExists(TranscriptFileOf(edOut.Text))) then
  begin
    LogLine('Choose a model: there is no saved transcript to use.');
    Exit;
  end;
  Device := '';
  if cbDevice.ItemIndex > 0 then
    Device := FDevices[cbDevice.ItemIndex - 1].Name;
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
    TDialogService.MessageDialog(Format('In the calibration, %s FAILED on %s:' + sLineBreak + sLineBreak + '%s' +
      sLineBreak + sLineBreak + 'A build would most likely fail the same way (a model too big for the card''s ' +
      'memory fails like this). Choose another device, or a smaller model.' + sLineBreak + sLineBreak +
      'Build on it anyway?', [ExtractFileName(FModelPath), WhisperDeviceText(D), Why]), TMsgDlgType.mtWarning,
      [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0,
      procedure(const AResult: TModalResult)
      begin
        if AResult = mrYes then
          CheckBookThen(Device, Q)
        else
          LogLine(Format('Not started: %s failed on %s in the calibration (Tools > Calibration results).',
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
    TDialogService.MessageDialog(Msg, TMsgDlgType.mtWarning, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo],
      TMsgDlgBtn.mbNo, 0,
      procedure(const AResult: TModalResult)
      begin
        if AResult = mrYes then
          CheckOutputThen(Device, Q)
        else
          LogLine('Not started: choose the original EPUB (Choose... above the book).');
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
    if (FJobs[I].State in [jsWaiting, jsRunning]) and SameFileName(ExpandFileName(FJobs[I].Output),
      ExpandFileName(edOut.Text)) then
    begin
      LogLine(Format('Job %d of the queue writes %s already: choose another output file (or remove that ' +
        'job).', [I + 1, edOut.Text]));
      Exit;
    end;
  // an EPUB already there: replaced without asking only when this program
  // made it from this book (a re-align); anything else asks first
  if FileExists(edOut.Text) and not (SameFileName(ExpandFileName(edOut.Text), FMadeOut) and
    SameFileName(ExpandFileName(edBook.Text), FMadeBook)) then
  begin
    TDialogService.MessageDialog(Format('%s already exists.' + sLineBreak + sLineBreak +
      'Replace it with the book this build makes?', [edOut.Text]), TMsgDlgType.mtConfirmation,
      [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0,
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
          LogLine('Not done: ' + edOut.Text + ' is kept. Choose another output file to keep both.');
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
  Result.State := jsWaiting;
end;

procedure TfrmBuilder.StartJob(const AJob: TBuildJob; AIndex: Integer);
var
  Audio: TStringList;
  I: Integer;
begin
  if FBuild <> nil then
    Exit;
  pbBuild.Value := 0;
  FStarted := Now;
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
  PrepareEstimate(AJob.Model, AJob.Device);
  Audio := TStringList.Create;
  try
    for I := 0 to High(AJob.Audio) do
      Audio.Add(AJob.Audio[I]);
    FBuild := TBuildThread.Create(AJob.Book, Audio, AJob.Model, AJob.Device, AJob.Output, AJob.Chapters,
      AJob.Reuse);
  finally
    Audio.Free;
  end;
  FBuild.OnLog :=
    procedure(AText: string)
    begin
      LogLine(AText);
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
begin
  SaveSettings;
  FJobs := FJobs + [AJob];
  ShowJobs;
  lbJobs.ItemIndex := High(FJobs);
  LogLine(Format('Added to the queue as job %d: %s -> %s', [Length(FJobs), AJob.Title,
    ExtractFileName(AJob.Output)]));
  UpdateControls;
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
end;

procedure TfrmBuilder.RunNextJob;
var
  I, Done, Failed: Integer;
begin
  if (FBuild <> nil) or not FQueueRunning then
    Exit;
  for I := 0 to High(FJobs) do
    if FJobs[I].State = jsWaiting then
    begin
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
  UpdateControls;
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
  FQueueRunning := True;
  RunNextJob;
end;

procedure TfrmBuilder.btnJobRemoveClick(Sender: TObject);
var
  I: Integer;
begin
  I := lbJobs.ItemIndex;
  if (I < 0) or (I > High(FJobs)) then
    Exit;
  if I = FJob then
  begin
    LogLine('The job running cannot be removed: Cancel stops it.');
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
      J.AddPair('output', FJobs[I].Output);
      J.AddPair('chapters', TJSONBool.Create(FJobs[I].Chapters));
      J.AddPair('useSavedTranscript', TJSONBool.Create(FJobs[I].Reuse));
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
  St: string;
begin
  Result := 0;
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
      J.TryGetValue<string>('output', Job.Output);
      J.TryGetValue<Boolean>('chapters', Job.Chapters);
      J.TryGetValue<Boolean>('useSavedTranscript', Job.Reuse);
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
      if St = 'done' then
        Job.State := jsDone
      else if St = 'failed' then
        Job.State := jsFailed
      else if St = 'cancelled' then
        Job.State := jsCancelled
      else
        Job.State := jsWaiting;
      // the checks Add to queue makes: a file is not asked, so it says
      if SameFileName(ExpandFileName(Job.Output), ExpandFileName(Job.Book)) then
      begin
        LogLine(Format('Left out: %s - its output is the book itself.', [Job.Title]));
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
        LogLine(Format('Left out: %s - job %d of the queue writes %s already.', [Job.Title, Dup + 1,
          Job.Output]));
        Continue;
      end;
      if (Job.State <> jsDone) and FileExists(Job.Output) then
        LogLine(Format('Note: %s is there already and will be replaced by job %d (%s) - remove the job to ' +
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
    D.InitialDir := FQueueFolder;
    if not D.Execute then
      Exit;
    FQueueFolder := ExtractFilePath(D.FileName);
    FQueueFile := D.FileName;
    try
      N := LoadQueue(D.FileName);
      LogLine(Format('%d job(s) added from %s', [N, D.FileName]));
    except
      on E: Exception do
        LogLine('The queue file cannot be read: ' + E.Message);
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
    LogLine('The queue is empty: nothing to save.');
    Exit;
  end;
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'Build queues (*.json)|*.json';
    D.DefaultExt := 'json';
    D.InitialDir := FQueueFolder;
    if FQueueFile <> '' then
      D.FileName := ExtractFileName(FQueueFile)
    else
      D.FileName := 'queue.json';
    if not D.Execute then
      Exit;
    FQueueFolder := ExtractFilePath(D.FileName);
    FQueueFile := D.FileName;
    try
      SaveQueue(D.FileName);
      LogLine(Format('The queue (%d job(s)) was saved to %s', [Length(FJobs), D.FileName]));
    except
      on E: Exception do
        LogLine('The queue was not saved: ' + E.Message);
    end;
  finally
    D.Free;
  end;
end;

procedure TfrmBuilder.lbJobsDblClick(Sender: TObject);
var
  I, K: Integer;
  Job: TBuildJob;
begin
  I := lbJobs.ItemIndex;
  if (I < 0) or (I > High(FJobs)) then
    Exit;
  Job := FJobs[I];
  ShowBook(Job.Book);
  lbAudio.Clear;
  for K := 0 to High(Job.Audio) do
    lbAudio.Items.Add(Job.Audio[K]);
  edOut.Text := Job.Output;
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
  LogLine(Format('Job %d put into the window: change it and Add to queue (then remove the old one), or ' +
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
    LogLine('Cancelling the calibration ...');
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
  Ok: Boolean;
  Taken: string;
  I: Integer;
begin
  // OnTerminate runs on the main thread after Execute: the queued log
  // lines have been delivered before it
  Taken := WhisperTimeToStr(MilliSecondsBetween(Now, FStarted) div 10);
  LogLine(Format('Finished after %s', [Taken]));
  // what the thread says, not what the progress bar shows
  Ok := (Sender as TBuildThread).Succeeded;
  if Ok then
  begin
    // before the log is saved: the line goes into the build's .log too
    RecordHistory((Sender as TBuildThread).Summary);
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
  if (FBuild <> nil) and (FJob >= 0) then
    S := Format('Job %d of %d: ', [FJob + 1, Length(FJobs)]) + S;
  lblStatus.Text := S + ' - ' + FStatusText;
end;

procedure TfrmBuilder.tmStatusTimer(Sender: TObject);
begin
  ShowStatus;
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
begin
  {$IF Defined(LINUX) and not Defined(ANDROID)}
  mnuBar := TMenuBar.Create(Self);
  mnuBar.Parent := Self;
  mnuBar.Position.Y := -1;   // above everything
  mnuBar.Align := TAlignLayout.Top;
  Bar := mnuBar;
  {$ELSE}
  mnuMain := TMainMenu.Create(Self);
  mnuMain.Parent := Self;
  Bar := mnuMain;
  {$ENDIF}
  M := Item(Bar, '&File', nil);
  Item(M, 'E&xit', miExitClick);
  M := Item(Bar, '&Tools', nil);
  miCalibrate := Item(M, '&Re-calibrate (this model)...', miCalibrateClick);
  miCalibrateAll := Item(M, 'Re-calibrate &every model in its folder...', miCalibrateAllClick);
  Item(M, '-', nil);
  Item(M, '&Calibration results', miCalibrationClick);
  Item(M, 'Build &history...', miHistoryClick);
  Item(M, '-', nil);
  Item(M, '&Books folder...', miFolderClick).Tag := 0;
  Item(M, '&Audio folder...', miFolderClick).Tag := 1;
  Item(M, '&Output folder...', miFolderClick).Tag := 2;
  // shown by CheckRocmDlc when it applies
  miRocm := Item(M, 'Get AMD &ROCm acceleration (free DLC)...', miRocmClick);
  miRocm.Visible := False;
  // a menu made in code reaches the window (Windows' / macOS' own menu
  // bar) only when it is recreated (EpubReader: without it, no menu)
  if mnuMain <> nil then
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
  if BuilderFindDevice('', D) then
    Result := Format('Default (whisper.cpp chooses: %s - the first GPU, not always the fastest)', [D.Name])
  else
    Result := 'Default (whisper.cpp chooses)';
end;

procedure TfrmBuilder.FormShow(Sender: TObject);
begin
  if FShown then
    Exit;
  FShown := True;
  // once the window is on the screen: the question is centred on it
  TThread.ForceQueue(nil,
    procedure
    begin
      // the display it is on (big-screen work, 2026-11-17: numbers first)
      DebugLog(SteamScreenText(Self));
      CheckCalibrationAtStart;
    end);
end;

procedure TfrmBuilder.CheckCalibrationAtStart;
var
  Done, DontAsk, DontShow: Boolean;
  Key, Made, Note, Why, Model, Names, Text: string;
  I: Integer;
begin
  if (FWhisperNote <> '') or (Length(FDevices) = 0) then
    Exit;
  // the last run ended while a pair was timed (a GPU runtime that aborts)
  Note := CalibrationCheckMarker(ChangeFileExt(SettingsFile, CALIBRATION_MARKER_SUFFIX), SettingsFile);
  if Note <> '' then
    LogLine(Note);
  CalibrationState(SettingsFile, Done, DontAsk, Key, Made);
  if Done and SameText(Key, CalibrationDevicesKey(FDevices)) then
  begin
    LogLine(Format('Calibrated %s (Tools > Calibration results; Tools > Re-calibrate after a new graphics card ' +
      'or driver).', [Made]));
    if (FModelPath <> '') and (CalibrationSummary(SettingsFile, FModelPath) <> '') then
      LogLine(ExtractFileName(FModelPath) + ': ' + CalibrationSummary(SettingsFile, FModelPath))
    else if FModelPath <> '' then
      LogLine(ExtractFileName(FModelPath) + ' is not calibrated yet: Tools > Re-calibrate times it.');
    Exit;
  end;
  Why := '';
  if Done then
    Why := Format('The devices have changed since the calibration of %s.', [Made]) + sLineBreak + sLineBreak;
  if DontAsk then
  begin
    LogLine(Why + 'Not calibrated for this machine (you asked not to be reminded): "Default" lets whisper.cpp ' +
      'choose, and it takes the first GPU in its list, not the fastest. Tools > Re-calibrate.');
    Exit;
  end;
  if FModelPath <> '' then
    Model := ExtractFileName(FModelPath)
  else
    Model := 'the model you choose next';
  Names := '';
  for I := 0 to High(FDevices) do
    Names := Names + IfThen(Names <> '', ', ', '') + FDevices[I].Name;
  Text := Why + 'EpubBuilder should be calibrated to this machine.' + sLineBreak + sLineBreak +
    'Which device transcribes fastest - the processor, or the graphics card through CUDA, Vulkan or ROCm - ' +
    'depends on a large number of factors: the card and its memory, its driver, the model, the processor. ' +
    'Left to itself whisper.cpp takes the first GPU in its list, and that is often not the fastest (on one ' +
    'machine CUDA took 39 minutes for a book Vulkan did in 29), and a large model may not fit a small card at ' +
    'all.' + sLineBreak + sLineBreak +
    Format('The calibration times %s on every device here (%s): 30 seconds of speech, three times each, with ' +
    'the settings of a build, and makes the fastest the device for that model. It takes a minute or two per ' +
    'device - longer on the processor with a large model.', [Model, Names]) + sLineBreak + sLineBreak +
    'Tools > Re-calibrate does it again later (a new graphics card or driver, another model).';
  if AskCalibration(Self, Text, DontShow) then
  begin
    if DontShow then
      CalibrationSetDontAsk(SettingsFile, True);
    StartCalibration(False, False);
  end
  else
  begin
    if DontShow then
      CalibrationSetDontAsk(SettingsFile, True);
    LogLine('Not calibrated: "Default" lets whisper.cpp choose (the first GPU in its list, not always the ' +
      'fastest). Tools > Re-calibrate does it later.');
  end;
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

procedure TfrmBuilder.StartCalibration(AAllModels, ARetry: Boolean);
var
  Models, Skip: TStringList;
  Audio, Saved: string;
  Ini: TMemIniFile;
  D: TOpenDialog;
  I: Integer;
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
      'downloaded when chosen; large-v3-turbo is a good first choice).');
    Exit;
  end;
  // the recording: the one used before, else media/aladdin.m4a beside the
  // program (or above it), else asked for
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
    LogLine(Format('media/%s was not found beside the program: choose a recording of English speech, a few ' +
      'minutes long, for the calibration.', [CALIBRATION_AUDIO]));
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
    Models := ModelFilesOf(ExtractFileDir(FModelPath))
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
    LogLine(Format('Each model on each device: loaded, a short warm-up, then %d timed runs of 30 s of speech ' +
      '(the median counts; the stretch is chosen away from both ends of the recording), with the settings of ' +
      'a build: word times by DTW, the book prompt, each window on its own.', [CALIBRATION_RUNS]));
    if Models.Count > 1 then
    begin
      LogLine(Format('%d models, smallest first:', [Models.Count]));
      for I := 0 to Models.Count - 1 do
        LogLine('  ' + ExtractFileName(Models[I]));
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
      LogLine(AText);
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
  FStatusText := 'Calibrating ...';
  tmStatus.Enabled := True;
  FCalib.OnTerminate := CalibrationDone;
  FCalib.FreeOnTerminate := True;
  UpdateControls;
  FCalib.Start;
end;

procedure TfrmBuilder.CalibrationDone(Sender: TObject);
var
  T: TCalibrationThread;
  LogFile: string;
begin
  // OnTerminate runs on the main thread after Execute: the queued log
  // lines have been delivered before it
  T := Sender as TCalibrationThread;
  if T.Completed then
  begin
    try
      CalibrationSave(SettingsFile, T.Results, CalibrationDevicesKey(FDevices), T.AudioFile);
      LogLine('Kept in ' + SettingsFile);
      // the model in the window gets its fastest device, and keeps it
      ApplyCalibration(True);
      SaveSettings;
    except
      on E: Exception do
        LogLine('The calibration was not saved: ' + E.Message);
    end;
  end
  else
    LogLine('The calibration did not finish: nothing was changed (Tools > Re-calibrate runs it again).');
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
      LogLine(Format('The calibration chose %s for %s, and whisper.cpp lists no %s now: Tools > Re-calibrate.',
        [Dev, ExtractFileName(FModelPath), Dev]));
  end
  else if ALog then
    LogLine(Format('%s is not calibrated on this machine: the device stays "%s". Tools > Re-calibrate times it ' +
      'on every device.', [ExtractFileName(FModelPath), cbDevice.Items[Max(0, cbDevice.ItemIndex)]]));
end;

procedure TfrmBuilder.CheckRocmDlc;
var
  I: Integer;
  Amd, Rocm: Boolean;
  State: TSteamDlcState;
  D: string;
begin
  {$IF Defined(LINUX) and not Defined(ANDROID)}
  if not SteamBuild or (STEAM_DLC_ROCM = 0) then
    Exit;
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
    LogLine('This AMD GPU may transcribe faster with AMD ROCm acceleration, a free DLC: Tools > Get AMD ROCm ' +
      'acceleration.');
    miRocm.Visible := True;
    if mnuMain <> nil then
      mnuMain.RecreateOSMenu;
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

procedure TfrmBuilder.miFolderClick(Sender: TObject);
const
  NAMES: array[0..2] of string = ('Books folder (the EPUBs to read along)', 'Audio folder (the recordings)',
    'Output folder (the books made)');
var
  K: Integer;
  Folder: string;
begin
  K := (Sender as TMenuItem).Tag;
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
    LogLine('Not calibrated on this machine yet: Tools > Re-calibrate.');
    Exit;
  end;
  LogLine(Format('Calibration of %s:', [Made]));
  if not SameText(Key, CalibrationDevicesKey(FDevices)) then
    LogLine('  THE DEVICES HAVE CHANGED SINCE: Tools > Re-calibrate.');
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
      LogLine(Format('  %s on %s ended the program: left out until Tools > Re-calibrate', [Copy(Crashes[I], 1,
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
    CalibrationSpeed(SettingsFile, AModel, Dev), FExpSpeed, FExpAfter, FExpPrior, FExpSource);
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
  R.ExactPercent := 0;
  if ASummary.Stats.BookWords > 0 then
    R.ExactPercent := ASummary.Stats.Exact * 100 / ASummary.Stats.BookWords;
  R.MatchedPercent := ASummary.Matched;
  if FExpSpeed > 0 then
    LogLine(Format('Speed: %.1fx real time (expected %.1fx); exact %.1f %%, matched %.1f %%.',
      [HistorySpeed(R), FExpSpeed, R.ExactPercent, R.MatchedPercent]))
  else
    LogLine(Format('Speed: %.1fx real time; exact %.1f %%, matched %.1f %%.', [HistorySpeed(R), R.ExactPercent,
      R.MatchedPercent]));
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
    LogLine(Format('  %s is not calibrated on this machine (Tools > Re-calibrate)', [ExtractFileName(AModel)]));
end;

end.
