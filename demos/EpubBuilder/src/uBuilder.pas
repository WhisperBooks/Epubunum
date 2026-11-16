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
  FMX.ListBox, FMX.Edit, FMX.Memo, FMX.Memo.Types, FMX.ScrollBox, FMX.Controls.Presentation,
  Epub.Zip, Epub.Book, Epub.Layout, Epub.Writer,
  FFmpeg.API,
  Whisper.Types, Whisper.API, Whisper.Audio, Whisper.Core, Whisper.Words, Whisper.Align, Whisper.AudioSet,
  uDebugLog;

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
    { The device ('' = whisper.cpp's default). }
    Device: string;
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
    { Sends AText to OnLog. }
    procedure Log(const AText: string);
    { Sends APercent to OnProgress. }
    procedure Progress(APercent: Double);
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
    { Receives what is being done now. }
    property OnStatus: TProc<string> read FOnStatus write FOnStatus;
    { The build's figures (complete once it has ended). }
    property Summary: TBuildSummary read FSummary;
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
    { The model file. }
    edModel: TEdit;
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
    { Folder the last book was chosen in ('' = none yet). }
    FBookFolder: string;
    { Folder the last audio was added from. }
    FAudioFolder: string;
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
    { Adds the jobs of AFileName to FJobs; returns how many. }
    function LoadQueue(const AFileName: string): Integer;
    { Closing while a build runs asks first (No by default): the build
      would be stopped and its work so far lost. }
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
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
    { Writes the time taken, the time left and FStatusText into lblStatus. }
    procedure ShowStatus;
    { tmStatus: ShowStatus. }
    procedure tmStatusTimer(Sender: TObject);
  end;

var
  { The window. }
  frmBuilder: TfrmBuilder;

implementation

{$R *.fmx}

const
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
    Log(Format('Model: %s on %s', [Model.Description, IfThen(FDevice = '', 'the default device', FDevice)]));
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
        if (Part.ResultCode <> 0) or Part.Cancelled then
        begin
          if not Part.Cancelled then
            Log(Format('Part %d failed: %s', [I + 1, Part.ErrorMessage]));
          Break;
        end;
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
      FSummary.Device := FDevice;
      FSummary.Language := FLanguage;
      Log(Format('Audio: %d file(s), %d part(s), about %s', [Audio.Files.Count, Length(Audio.Parts),
        WhisperTimeToStr(Round(FTotalSeconds * 100))]));
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
  edModel := TEdit.Create(Self);
  edModel.Parent := Row;
  edModel.Align := TAlignLayout.Client;
  edModel.ReadOnly := True;
  AddButton(Row, 'Choose...', btnModelClick, TAlignLayout.Right);

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

procedure TfrmBuilder.FormCreate(Sender: TObject);
var
  Lib: TWhisperLib;
  I: Integer;
begin
  OnCloseQuery := FormCloseQuery;
  // the debug log: next to the settings, started afresh at every run
  DebugLogOpen(ChangeFileExt(SettingsFile, '-debug.log'));
  FJob := -1;
  FBuildLog := TStringList.Create;
  BuildWindow;
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
  LoadSettings;
  LogLine('Choose the EPUB, add its audio files in reading order, choose the model (ggml-*.bin), Create.');
  LogLine('Debug log: ' + DebugLogFile);
  UpdateControls;
end;

procedure TfrmBuilder.WhisperLog(Sender: TObject; ALevel: TWhisperLogLevel; const AText: string);
begin
  DebugLog('whisper.cpp: ' + AText);
end;

procedure TfrmBuilder.LoadSettings;
var
  Ini: TMemIniFile;
  Device: string;
  I: Integer;
begin
  if not FileExists(SettingsFile) then
    Exit;
  try
    Ini := TMemIniFile.Create(SettingsFile, TEncoding.UTF8);
    try
      edModel.Text := Ini.ReadString('Build', 'Model', '');
      if (edModel.Text <> '') and not FileExists(edModel.Text) then
        edModel.Text := '';
      // the device by its name: the list's order can change
      Device := Ini.ReadString('Build', 'Device', '');
      for I := 0 to High(FDevices) do
        if SameText(FDevices[I].Name, Device) then
          cbDevice.ItemIndex := I + 1;
      chkChapters.IsChecked := Ini.ReadBool('Build', 'Chapters', True);
      FBookFolder := Ini.ReadString('Folders', 'Book', '');
      FAudioFolder := Ini.ReadString('Folders', 'Audio', '');
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
      Ini.WriteString('Build', 'Model', edModel.Text);
      if cbDevice.ItemIndex > 0 then
        Ini.WriteString('Build', 'Device', FDevices[cbDevice.ItemIndex - 1].Name)
      else
        Ini.WriteString('Build', 'Device', '');
      Ini.WriteBool('Build', 'Chapters', chkChapters.IsChecked);
      // no longer kept (off at every start)
      Ini.DeleteKey('Build', 'UseSavedTranscript');
      Ini.WriteString('Folders', 'Book', FBookFolder);
      Ini.WriteString('Folders', 'Audio', FAudioFolder);
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

procedure TfrmBuilder.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  SaveSettings;
  if FBuild <> nil then
  begin
    // still running (BuildDone, which clears FBuild, runs on this thread
    // and has not run): keep the object to wait for it, then free it here
    FBuild.FreeOnTerminate := False;
    FBuild.OnLog := nil;
    FBuild.OnProgress := nil;
    FBuild.OnStatus := nil;
    FBuild.OnTerminate := nil;
    tmStatus.Enabled := False;
    FBuild.Cancel;
    FBuild.WaitFor;
    FreeAndNil(FBuild);
  end;
  FreeAndNil(FBuildLog);
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
  Busy := (FBuild <> nil) or FQueueRunning;
  Ready := (FWhisperNote = '') and (edBook.Text <> '') and (lbAudio.Count > 0) and (edOut.Text <> '') and
    ((edModel.Text <> '') or chkReuse.IsChecked);
  // the window stays usable while building: books are added to the queue
  // while it runs (owner)
  btnCreate.Enabled := not Busy and Ready;
  btnAddJob.Enabled := Ready;
  btnCancel.Enabled := FBuild <> nil;
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
        edOut.Text := ChangeFileExt(AFileName, '') + '-synced.epub';
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
begin
  L := TStringList.Create;
  try
    L.Assign(AFiles);
    // chapter2 before chapter10, Part IV after Part III
    L.CustomSort(NaturalFileOrder);
    for I := 0 to L.Count - 1 do
      if lbAudio.Items.IndexOf(L[I]) < 0 then
        lbAudio.Items.Add(L[I]);
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
    begin
      FBookFolder := ExtractFileDir(D.FileName);
      ShowBook(D.FileName);
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
    D.Filter := 'Audio (*.m4b;*.m4a;*.mp3;*.wav;*.flac;*.ogg;*.opus;*.aac)|*.m4b;*.m4a;*.mp3;*.wav;*.flac;*.ogg;' +
      '*.opus;*.aac|All files (*.*)|*.*';
    D.Options := D.Options + [TOpenOption.ofAllowMultiSelect];
    D.InitialDir := FAudioFolder;
    if D.Execute then
    begin
      FAudioFolder := ExtractFileDir(D.FileName);
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
    if edModel.Text <> '' then
      D.InitialDir := ExtractFileDir(edModel.Text);
    if D.Execute then
    begin
      edModel.Text := D.FileName;
      SaveSettings;
    end;
  finally
    D.Free;
  end;
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
  Device, Msg: string;
  Q: Boolean;
begin
  Q := AQueue;
  if SameFileName(ExpandFileName(edOut.Text), ExpandFileName(edBook.Text)) then
  begin
    LogLine('The output must not be the book itself: choose another output file.');
    Exit;
  end;
  if (edModel.Text = '') and not (chkReuse.IsChecked and FileExists(TranscriptFileOf(edOut.Text))) then
  begin
    LogLine('Choose a model: there is no saved transcript to use.');
    Exit;
  end;
  Device := '';
  if cbDevice.ItemIndex > 0 then
    Device := FDevices[cbDevice.ItemIndex - 1].Name;
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
  Result.Model := edModel.Text;
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
      end;
    end;
  FBuild.OnStatus :=
    procedure(AText: string)
    begin
      FStatusText := AText;
      ShowStatus;
    end;
  FPercent := 0;
  FRatePercent := -1;
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
      'upgraded_epub2,epub_bytes,book,output,note');
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
        '%s,%s,%s', [I + 1, CsvText(J.Title), STATE_TEXT[J.State], IfThen(J.Started > 0,
        FormatDateTime('yyyy-mm-dd hh:nn:ss', J.Started), ''), Num(J.Seconds, 1), Num(S.AudioSeconds, 1),
        IfThen(Speed = '-', '', Num(S.AudioSeconds / Max(J.Seconds, 0.001), 2)),
        IfThen(S.SavedTranscript, 'yes', 'no'), Num(S.TranscribeSeconds, 1), CsvText(S.Model), CsvText(S.Device),
        S.Language, S.Files, S.Parts, S.Stats.BookWords, S.HeardWords, S.Stats.Exact, S.Stats.Similar,
        S.Stats.Moved, S.Stats.Interpolated, S.Stats.NotHeard, S.Stats.NotSpoken, S.EdgeWords,
        Num(S.Matched, 2), S.Verdict, Num(S.Stats.WordsPerSecond, 2), S.Clips, S.LeftOut, S.ChapterMarks,
        IfThen(S.Upgraded, 'yes', 'no'), J.OutputBytes, CsvText(J.Book), CsvText(J.Output),
        CsvText(IfThen(S.Error <> '', S.Error, J.Note))]));
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
      if S.AudioSeconds > 0 then
        Md.Add(Format('- Audio: %s in %d file(s), %d part(s); language %s', [HmsText(S.AudioSeconds), S.Files,
          S.Parts, IfThen(S.Language = '', 'not given', S.Language)]));
      if S.SavedTranscript then
        Md.Add('- Transcript: the saved one' + IfThen(S.Model <> '', ' (made with ' + S.Model + ')', ''))
      else if S.TranscribeSeconds > 0 then
        Md.Add(Format('- Transcribed with %s on %s in %s (%.1fx)', [S.Model, IfThen(S.Device = '',
          'the default device', S.Device), HmsText(S.TranscribeSeconds), S.AudioSeconds /
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
  I, K: Integer;
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
    edModel.Text := Job.Model;
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
  Ok := pbBuild.Value >= 100;
  if Ok then
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
end;

procedure TfrmBuilder.ShowStatus;
var
  Taken, Since, Left: Int64;
  S: string;
begin
  Taken := MilliSecondsBetween(Now, FStarted);
  S := Format('%s taken', [WhisperTimeToStr((Taken div 1000) * 100)]);
  // the time left from the transcription's own rate: only after a minute
  // of it and 1 % of progress (counted from the start of the build, the
  // loading made the first figures hours too high - owner, Night Watch on
  // Linux: 14 - 20 h shown, 20 min taken)
  if (FBuild <> nil) and (FPercent < 100) and (FRatePercent >= 0) then
  begin
    Since := MilliSecondsBetween(Now, FRateFrom);
    if (Since >= 60000) and (FPercent - FRatePercent >= 1) then
    begin
      Left := Round(Since * (100 - FPercent) / (FPercent - FRatePercent));
      S := S + Format(', about %s left', [WhisperTimeToStr((Left div 1000) * 100)]);
    end
    else
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

end.
