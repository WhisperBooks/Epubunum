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
  System.DateUtils, System.IOUtils, System.IniFiles,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls, FMX.Layouts,
  FMX.ListBox, FMX.Edit, FMX.Memo, FMX.Memo.Types, FMX.ScrollBox, FMX.Controls.Presentation,
  Epub.Zip, Epub.Book, Epub.Layout, Epub.Writer,
  FFmpeg.API,
  Whisper.Types, Whisper.API, Whisper.Audio, Whisper.Core, Whisper.Words, Whisper.Align, Whisper.AudioSet;

type
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
      ARegions from WhisperAlignRegions). }
    procedure LogResults(const AStats: TWhisperAlignStats; AHeard: Integer; const ASplit: TWhisperStringArray;
      const ARegions: TWhisperAlignRegionArray);
    { Takes the silence off the word edges of a transcript saved before
      that was done (TWhisper zip 28), part by part from the audio. }
    procedure TrimSaved(var AResult: TWhisperTranscription; AAudio: TWhisperAudioSet);
    { Saves AResult as FJsonFile, marked as having trimmed word edges. }
    procedure SaveTranscript(const AResult: TWhisperTranscription; const AParts: TWhisperAudioPartArray);
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
  end;

  { The builder's window. }
  TfrmBuilder = class(TForm)
    { Loads whisper.cpp and lists its devices; builds the window. }
    procedure FormCreate(Sender: TObject);
    { Stops a build before the window goes. }
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
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
    { Devices whisper.cpp can use (cbDevice's items after 'Default'). }
    FDevices: TWhisperDeviceArray;
    { Why whisper.cpp is not there ('' when it is). }
    FWhisperNote: string;
    { Folder the last book was chosen in ('' = none yet). }
    FBookFolder: string;
    { Folder the last audio was added from. }
    FAudioFolder: string;
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
    { Start the build. }
    procedure btnCreateClick(Sender: TObject);
    { Stop it. }
    procedure btnCancelClick(Sender: TObject);
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
  try
    Result := TFFmpegLibrary.Create('');
  except
    on E: EFFmpegError do
    begin
      First := E.Message;
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
begin
  Result := False;
  AResult := Default(TWhisperTranscription);
  ASavedParts := nil;
  if not FReuse or not FileExists(FJsonFile) then
    Exit;
  try
    AResult := WhisperTranscriptionFromJson(WhisperLoadTextFile(FJsonFile), ASavedParts);
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
  Log(Format('Using the transcript an earlier run kept: %s (%d words) - untick "Use a saved transcript" to ' +
    'transcribe again', [FJsonFile, Length(AResult.Words)]));
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

procedure TBuildThread.SaveTranscript(const AResult: TWhisperTranscription; const AParts: TWhisperAudioPartArray);
var
  Json: string;
  P: Integer;
begin
  Json := WhisperTranscriptionToJson(AResult, AParts);
  // a key of its own after the opening brace (the reader ignores keys it
  // does not know)
  P := Pos('{', Json);
  Insert(sLineBreak + '  ' + TRIMMED_MARK + ',', Json, P + 1);
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
  Model := TWhisperModel.Create(FModelFile, CP);
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
  const ASplit: TWhisperStringArray; const ARegions: TWhisperAlignRegionArray);
var
  Timed, Matched, I, K, Shown, Edges: Integer;
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
  if Share >= 98 then
    Verdict := 'very good'
  else if Share >= 93 then
    Verdict := 'good'
  else if Share >= 80 then
    Verdict := 'usable - listen to the stretches below'
  else
    Verdict := 'poor - is this the right recording for this book (or the right order of files)?';
  Log(Format('  Verdict: %.1f %% of the timed words were matched to what was heard: %s.', [Share, Verdict]));
  // not spoken at the very start and end is front and back matter (a
  // title page, a licence): normal. Inside the book it is text the
  // recording leaves out - or audio missing from the list.
  Edges := 0;
  for I := 0 to High(ARegions) do
    if (ARegions[I].Match = wamNotSpoken) and ((ARegions[I].First = 0) or (ARegions[I].Last = High(ASplit))) then
      Inc(Edges, ARegions[I].Last - ARegions[I].First + 1);
  if Edges > 0 then
    Log(Format('  Of the not spoken words, %d are before the first or after the last word read: front and back ' +
      'matter, normal.', [Edges]));
  if AStats.NotSpoken - Edges > AStats.BookWords div 10 then
    Log(Format('  %d words inside the book are not in the recording: check that every audio file is in the ' +
      'list, in order.', [AStats.NotSpoken - Edges]));
  // the longest stretches first (a copy: shown ones are marked in it)
  Regions := Copy(ARegions, 0, Length(ARegions));
  if Length(Regions) = 0 then
    Exit;
  Log(Format('  Stretches of %d or more words worth a look (longest first, at most %d):', [REGION_MIN_WORDS,
    REGIONS_SHOWN]));
  Shown := 0;
  while Shown < Min(REGIONS_SHOWN, Length(Regions)) do
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
      Log(Format('Audio: %d file(s), %d part(s), about %s', [Audio.Files.Count, Length(Audio.Parts),
        WhisperTimeToStr(Round(FTotalSeconds * 100))]));
      Progress(5);
      if Terminated then
        Exit;

      // 3. the transcript: a saved one when it fits, else transcribed
      if ReadSaved(Audio.Parts, R, Parts) then
      begin
        if Pos(TRIMMED_MARK, WhisperLoadTextFile(FJsonFile)) = 0 then
        begin
          TrimSaved(R, Audio);
          if Terminated then
            Exit;
          SaveTranscript(R, Parts);
        end;
      end
      else
      begin
        Status('Loading the model ...');
        R := Transcribe(Audio);
        if Terminated then
        begin
          Log('Cancelled');
          Exit;
        end;
        Parts := Audio.Parts;
        SaveTranscript(R, Parts);
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
      LogResults(Stats, Length(R.Words), Split, WhisperAlignRegions(Aligned, REGION_MIN_WORDS));
      Files := WhisperPartFiles(Parts);
      Times := WhisperWordFileTimes(Joined, Parts, Files);
      Progress(93);
      if Terminated then
        Exit;

      // 5. the book with overlays and the audio inside
      Writer := TEpubWriter.Create(Book);
      for I := 0 to Files.Count - 1 do
        Writer.AddAudioFile(Files[I]);
      for I := 0 to High(Times) do
        Writer.AddWord(Numbers[Times[I].Word], Times[I].FileIndex, Times[I].StartTime, Times[I].EndTime);
      Log(Format('Writing %s ...', [FOutFile]));
      Status('Writing the book (the audio is copied in) ...');
      Writer.SaveToFile(FOutFile);
      Report := Writer.Report;
      Log(Format('Done: %d document(s), %d clip(s), %d timed word(s) left out', [Report.Documents,
        Report.Clips, Report.Skipped]));
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
  chkReuse.IsChecked := True;

  Buttons := AddRow(layBottom, '');
  btnCreate := AddButton(Buttons, 'Create', btnCreateClick, TAlignLayout.Left, 120);
  btnCancel := AddButton(Buttons, 'Cancel', btnCancelClick, TAlignLayout.Left, 120);
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

  // the book: left
  layBook := TLayout.Create(Self);
  layBook.Parent := Self;
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
  BuildWindow;
  cbDevice.Items.Add('Default (whisper.cpp chooses)');
  try
    Lib := TWhisperLib.Load;
    FDevices := Lib.SelectableDevices;
    for I := 0 to High(FDevices) do
      cbDevice.Items.Add(WhisperDeviceText(FDevices[I]));
    LogLine(Format('whisper.cpp %s loaded from %s', [Lib.Version, Lib.LibraryFolder]));
  except
    on E: Exception do
    begin
      FWhisperNote := E.Message;
      LogLine('whisper.cpp is not available: ' + E.Message);
      LogLine('Put TWhisper''s redistributable_bin libraries next to the program or on PATH.');
    end;
  end;
  cbDevice.ItemIndex := 0;
  LoadSettings;
  LogLine('Choose the EPUB, add its audio files in reading order, choose the model (ggml-*.bin), Create.');
  UpdateControls;
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
      chkReuse.IsChecked := Ini.ReadBool('Build', 'UseSavedTranscript', True);
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
      Ini.WriteBool('Build', 'UseSavedTranscript', chkReuse.IsChecked);
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
end;

procedure TfrmBuilder.LogLine(const AText: string);
begin
  mmLog.Lines.Add(AText);
  mmLog.GoToTextEnd;
end;

procedure TfrmBuilder.UpdateControls;
var
  Busy: Boolean;
begin
  Busy := FBuild <> nil;
  btnCreate.Enabled := not Busy and (FWhisperNote = '') and (edBook.Text <> '') and (lbAudio.Count > 0) and
    (edOut.Text <> '') and ((edModel.Text <> '') or chkReuse.IsChecked);
  btnCancel.Enabled := Busy;
  layBook.Enabled := not Busy;
  layAudio.Enabled := not Busy;
  edModel.Enabled := not Busy;
  cbDevice.Enabled := not Busy;
  edOut.Enabled := not Busy;
end;

procedure TfrmBuilder.ShowBook(const AFileName: string);
var
  Book: TEpubBook;
  Audio: TStringList;
begin
  mmBook.Lines.Clear;
  try
    Book := TEpubBook.Create(AFileName);
    try
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
var
  Device: string;
begin
  if SameFileName(ExpandFileName(edOut.Text), ExpandFileName(edBook.Text)) then
  begin
    LogLine('The output must not be the book itself: choose another output file.');
    Exit;
  end;
  if (edModel.Text = '') and not FileExists(TranscriptFileOf(edOut.Text)) then
  begin
    LogLine('Choose a model: there is no saved transcript to use.');
    Exit;
  end;
  Device := '';
  if cbDevice.ItemIndex > 0 then
    Device := FDevices[cbDevice.ItemIndex - 1].Name;
  SaveSettings;
  mmLog.Lines.Clear;
  pbBuild.Value := 0;
  FStarted := Now;
  FBuild := TBuildThread.Create(edBook.Text, lbAudio.Items, edModel.Text, Device, edOut.Text,
    chkChapters.IsChecked, chkReuse.IsChecked);
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
    end;
  FBuild.OnStatus :=
    procedure(AText: string)
    begin
      FStatusText := AText;
      ShowStatus;
    end;
  FPercent := 0;
  FStatusText := 'Starting ...';
  tmStatus.Enabled := True;
  FBuild.OnTerminate := BuildDone;
  FBuild.FreeOnTerminate := True;
  UpdateControls;
  FBuild.Start;
end;

procedure TfrmBuilder.btnCancelClick(Sender: TObject);
begin
  if FBuild <> nil then
  begin
    LogLine('Cancelling ...');
    FBuild.Cancel;
  end;
end;

procedure TfrmBuilder.BuildDone(Sender: TObject);
begin
  // OnTerminate runs on the main thread after Execute: the queued log
  // lines have been delivered before it
  LogLine(Format('Finished after %s', [WhisperTimeToStr(MilliSecondsBetween(Now, FStarted) div 10)]));
  if pbBuild.Value >= 100 then
    LogLine('Open ' + edOut.Text + ' in EpubReader.');
  // FreeOnTerminate: the thread frees itself once this handler returns
  FBuild := nil;
  tmStatus.Enabled := False;
  ShowStatus;
  UpdateControls;
end;

procedure TfrmBuilder.ShowStatus;
var
  Taken, Left: Int64;
  S: string;
begin
  Taken := MilliSecondsBetween(Now, FStarted);
  S := Format('%s taken', [WhisperTimeToStr((Taken div 1000) * 100)]);
  // the time left from the progress so far, once there is enough of it
  if (FBuild <> nil) and (FPercent >= 7) and (FPercent < 100) then
  begin
    Left := Round(Taken * (100 - FPercent) / FPercent);
    S := S + Format(', about %s left', [WhisperTimeToStr((Left div 1000) * 100)]);
  end;
  lblStatus.Text := S + ' - ' + FStatusText;
end;

procedure TfrmBuilder.tmStatusTimer(Sender: TObject);
begin
  ShowStatus;
end;

end.
