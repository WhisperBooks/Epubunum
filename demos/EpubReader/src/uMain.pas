{ @abstract(Main form of EpubReader: open an EPUB, read it in a Skia view,
  and - for a book with media overlays - play its audio with the words
  highlighted as they are read.)

  The book component (EpubUnum1), the view (View1) and their events are
  set up in uMain.fmx. The sound is FFmpegAPI's TFFmpegAudioPlayer
  (TFFMpegAPI, installed separately): the book's audio file streamed by
  FFmpeg to the platform's output (WASAPI, PulseAudio), and its clock - the
  sound really being heard - picks the clip to highlight. No FFmpeg: the
  book still reads, without sound.

  No main menu (on Linux FMX's GTK menu bar shows only first letters, and
  SteamOS runs every window full screen): a tool bar of icon buttons, as
  Sprite3D's results view draws them (a TPath icon in a TButton, coloured
  by the style), and keys - P play / pause, Ctrl+O open, Ctrl+Plus /
  Ctrl+Minus text size, D dark mode; the view scrolls with the wheel, the
  arrows, Page Up / Page Down and Space. A click on a word starts the
  audio there.

  Chapters are the table of contents' entries (the reading order's
  documents when it has none): previous / next chapter, and a click in the
  contents, show the chapter AND move the audio to its first clip (played
  at once when playing, else from there on Play). Previous / next step by
  sentence or by paragraph (the drop-down), whatever the overlay's clips
  are - a word-level book has a clip per word. Previous goes back to the
  start of the sentence being read; pressed again near that start, to the
  one before. }
unit uMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.IOUtils, System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Layouts,
  FMX.ListBox, FMX.Controls.Presentation, FMX.Objects, FMX.Menus, FMX.Edit, System.JSON,
  // TJSONArray's inline getters expand only with it (H2443)
  System.Generics.Collections,
  Epub.Zip, Epub.Layout, Epub.Book, Epub.Components, Epub.FMX, Epub.FMX.View, uDebugLog,
  // sound: DCUs of TFFMpegAPI's runtime package FFmpegAPI
  FFmpeg.API, FFmpeg.Player,
  // the game pad and its menu (fields of the form)
  uSteamPad, uPadMenu;

type
  { A book in the Recently Opened list, with where its reader left off. }
  TRecentBook = record
    { The EPUB file. }
    FileName: string;
    { Its title (the menu shows it). }
    Title: string;
    { The word the reader was at (index into the book's Words), -1 = the
      start. }
    Word: Integer;
  end;

  { The reader's main form. }
  TfrmMain = class(TForm)
    { The book. }
    EpubUnum1: TEpubUnum;
    { The page view (Skia). }
    View1: TEpubView;
    { Tool bar (its buttons are made in FormCreate). }
    layTop: TLayout;
    { Title, document and playing state. }
    lblStatus: TLabel;
    { Table of contents. }
    lbToc: TListBox;
    { Between contents and page. }
    Splitter1: TSplitter;
    { Follows the audio: highlights the clip being read. }
    tmPlay: TTimer;
    { Chooses the book. }
    dlgOpen: TOpenDialog;
    { Sets up the temporary audio folder; opens a book named on the
      command line. }
    procedure FormCreate(Sender: TObject);
    { An exception nothing handled: into the debug log with the library it
      happened in (DebugLogException), then shown as before. }
    procedure AppException(Sender: TObject; E: Exception);
    { The first time the window is shown: the display it is on into the
      debug log (SteamScreenText). }
    procedure FormShow(Sender: TObject);
    { Stops the audio and removes the temporary files. }
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    { Keys: P, Ctrl+O, Ctrl+Plus / Ctrl+Minus, D, L (Learn to read), R (say
      again), [ / ] (speed). }
    procedure FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    { Chooses and opens a book. }
    procedure btnOpenClick(Sender: TObject);
    { Previous document. }
    procedure btnPrevClick(Sender: TObject);
    { Next document. }
    procedure btnNextClick(Sender: TObject);
    { Previous sentence / paragraph (cbStep). }
    procedure btnPrevClipClick(Sender: TObject);
    { Next sentence / paragraph (cbStep). }
    procedure btnNextClipClick(Sender: TObject);
    { Word, sentence or paragraph steps: the buttons' hints. }
    procedure cbStepChange(Sender: TObject);
    { Learn to read on / off. }
    procedure btnLearnClick(Sender: TObject);
    { Speed slider moved: the player's speed, the label. }
    procedure tbSpeedChange(Sender: TObject);
    { Speed label clicked: back to 1x. }
    procedure lblSpeedClick(Sender: TObject);
    { The speed has stayed put for SPEED_SETTLE_MS: the player gets it. }
    procedure tmSpeedTimer(Sender: TObject);
    { Dark / light page and panels. }
    procedure btnDarkClick(Sender: TObject);
    { Play / pause. }
    procedure btnPlayClick(Sender: TObject);
    { Smaller text. }
    procedure btnSmallerClick(Sender: TObject);
    { Larger text. }
    procedure btnLargerClick(Sender: TObject);
    { The book is open: contents, first document, clip map. }
    procedure EpubUnum1Open(Sender: TObject);
    { The book could not be opened. }
    procedure EpubUnum1OpenFailed(Sender: TObject; const AMessage: string);
    { A contents entry was chosen. }
    procedure lbTocChange(Sender: TObject);
    { A word was clicked: play from its clip. }
    procedure View1WordClick(Sender: TObject; AWord: Integer);
    { Another document is shown. }
    procedure View1DocumentChange(Sender: TObject);
    { Follows the audio. }
    procedure tmPlayTimer(Sender: TObject);
  private
    { Opens a book. }
    { Previous document of the reading order. }
    btnPrev: TButton;
    { Previous clip. }
    btnPrevClip: TButton;
    { Plays / pauses the book's audio (media overlays). }
    btnPlay: TButton;
    { Next clip. }
    btnNextClip: TButton;
    { Next document of the reading order. }
    btnNext: TButton;
    { Smaller text. }
    btnSmaller: TButton;
    { Larger text. }
    btnLarger: TButton;
    { What previous / next step by: sentence (0) or paragraph (1). }
    cbStep: TComboBox;
    { Learn to read on / off (stays pressed while on). }
    btnLearn: TButton;
    { Learn to read: a green band behind the tool bar - the mode must be
      obvious at a glance (owner). }
    recLearn: TRectangle;
    { Learn to read is on: Next / Previous move, then say the unit and
      stop; a click says one word; R says the unit again. Also a way to
      proof-read a book's timings by ear. }
    FLearn: Boolean;
    { Learn to read: first word of the unit shown (and said), -1 = none. }
    FLearnFirst: Integer;
    { Learn to read: its last word. }
    FLearnLast: Integer;
    { Playing speed, SPEED_MIN .. SPEED_MAX (1 = as recorded). }
    tbSpeed: TTrackBar;
    { The speed as text ('1.0x'); a click sets 1x again. }
    lblSpeed: TLabel;
    { Applies the slider's speed once it stops moving: every change of
      speed restarts the player's feed (seek, new filter graph), so a drag
      that applied each step made the window stop responding (owner). }
    tmSpeed: TTimer;
    { The speed waiting for tmSpeed. }
    FPendingSpeed: Double;
    { Dark mode on / off. }
    btnDark: TButton;
    { Dark mode is on. }
    FDark: Boolean;
    { Chapters in reading order: their first word in Book.Words. }
    FChapterWord: TArray<Integer>;
    { Chapters: their entry in Book.Toc (-1 = a document, no contents). }
    FChapterToc: TArray<Integer>;
    { Chapters: their document. }
    FChapterDoc: TArray<Integer>;
    { Chapters: their title ('' = none: a document without contents entry). }
    FChapterTitle: TArray<string>;
    { lbToc lists the chapters (item = chapter) instead of the book's
      contents: the chapters come from the audiobook's chapter marks. }
    FTocIsChapters: Boolean;
    { Where the chapters came from (shown in the status line with "debug"). }
    FChapterSource: string;
    { lbToc's selection is being set from code (no chapter jump). }
    FSyncingToc: Boolean;
    { Clip that Play starts from after a jump while paused, -1 = none (Play
      resumes). }
    FSeekClip: Integer;
    { The layout used to find paragraphs (blocks) of words: document
      FUnitDoc's. }
    FUnitLayout: TEpubDocLayout;
    { Document of FUnitLayout, -1 = none. }
    FUnitDoc: Integer;
    { FFmpeg (nil when its libraries are not found: no sound). }
    FFFmpeg: TFFmpegLibrary;
    { The sound (nil without FFmpeg). }
    FPlayer: TFFmpegAudioPlayer;
    { Why there is no sound / it is silent ('' when all is well). }
    FSoundNote: string;
    { What RegisterOpenWith did at start-up, shown until a book opens. }
    FOpenWithNote: string;
    { The display was logged (FormShow). }
    FScreenLogged: Boolean;
    { The menu bar: File (Open, Recently Opened, Exit), View. }
    mnuMain: TMainMenu;
    {$IF Defined(LINUX) and not Defined(ANDROID)}
    { Linux: the menu bar drawn by FMX instead (mnuMain stays nil): GTK's
      native bar shows only the first letter of each item (TSteamAPI,
      docs/fmx-menu-bug-fix.md). The menu is made in code, so it is made
      on this bar directly - nothing to copy, unlike TSteamAPI's
      FmxLinuxMenu. Declared on Linux only (H2219 elsewhere). }
    mnuBar: TMenuBar;
    {$ENDIF}
    { File > Recently Opened (filled by BuildRecentMenu). }
    miRecent: TMenuItem;
    { The library: the recent books' covers, over the page (File >
      Library; shown at start-up when no book is named). }
    recLibrary: TRectangle;
    { The library's line when it has no books. }
    lblLibrary: TLabel;
    { The library's covers (Tag = index in FRecent; the first, the
      current book, is drawn large). }
    FCoverImages: TArray<TImage>;
    { Opens the clicked cover's book once the click is over. }
    tmLibrary: TTimer;
    { The book tmLibrary opens (index in FRecent). }
    FLibraryOpen: Integer;
    { File > Go to Footnote (filled by BuildNotesMenu; disabled when the
      book has none). }
    miNotes: TMenuItem;
    { First word of each note of the book (miNotes' items' Tags index it). }
    FNoteWords: TArray<Integer>;
    { Debugging aids shown (File > Go to Footnote ...): "debug" in the
      settings file, false unless edited there by hand - it only hides
      what would confuse a reader. }
    FDebug: Boolean;
    { The find bar, under the tool bar (shown by Edit > Find, Ctrl+F). }
    layFind: TLayout;
    { What to find: a word, the start of a word, or several words. }
    edFind: TEdit;
    { Where the finding is: '3 of 17', 'Not found'. }
    lblFind: TLabel;
    { The query FFindHits were found for ('' = none yet). }
    FFindQuery: string;
    { First word of every match of FFindQuery, in book order. }
    FFindHits: TArray<Integer>;
    { Words in a match. }
    FFindLength: Integer;
    { The match shown, -1 = none yet. }
    FFindIndex: Integer;
    { View > Dark mode (checked when on). }
    miDark: TMenuItem;
    { View > Learn to read (checked when on). }
    miLearn: TMenuItem;
    { Recently opened books, the latest first (at most RECENT_MAX), with
      their reading positions. }
    FRecent: TArray<TRecentBook>;
    { The book open now ('' = none): its position is kept for it. }
    FBookFile: string;
    { Folder the audio files are extracted to. }
    FAudioFolder: string;
    { Archive path of the audio file in the player, '' when none. }
    FAudioPath: string;
    { The clip highlighted, -1 when none. }
    FClip: Integer;
    { The audio is playing. }
    FPlaying: Boolean;
    { The screen is kept on (it plays) - see uInhibit. }
    FAwake: Boolean;
    { The game pad through Steam Input (uSteamPad; reads nothing outside a
      Steam build). }
    FPad: TSteamPad;
    { Polls FPad. }
    tmPad: TTimer;
    { The last poll (ms), for the stick's scrolling. }
    FPadTick: UInt64;
    { The pad's menu (uPadMenu). }
    FPadMenu: TPadMenu;
    { What FPadMenu shows: MODE_MAIN, MODE_CONTENTS, MODE_CONTROLS or
      MODE_BOOKS. }
    FMenuMode: Integer;
    { The books folder: the menu's Open a book lists its EPUBs (a Steam
      build: Books beside the program, on the Mac in Documents - see
      BooksFolderDefault; settings key "booksFolder" for another). }
    FBooksFolder: string;
    { The books Open a book lists, in its order. }
    FBookFiles: TArray<string>;
    { The library's cover chosen with the pad (-1 = none yet). }
    FCoverSel: Integer;
    { Its frame. }
    recCoverSel: TRectangle;
    { First word of each clip (-1 when it has none). }
    FClipFirst: TArray<Integer>;
    { Last word of each clip. }
    FClipLast: TArray<Integer>;
    { Steam's Exit Game (SIGTERM) or the system shutting down: the window's
      own close (FormClose: the place, the settings) - quick, nothing to
      wait for.
      @param(ASignal  the signal's number) }
    procedure QuitSignalled(ASignal: Integer);
    { The pad: Steam Input with EpubReader's manifest (written beside the
      settings from uReaderInput), the menu, the poll. }
    procedure StartPad;
    { Reads the pad: presses to PadPress, the stick scrolls the page. }
    procedure tmPadTimer(Sender: TObject);
    { What a pad button does where the reader is (menu, library, page).
      @param(AButton  PAD_UP .. PAD_LIBRARY) }
    procedure PadPress(AButton: Integer);
    { The pad's main menu. }
    procedure ShowPadMenu;
    { The pad's contents list (the panel's entries). }
    procedure ShowContentsMenu;
    { The pad's controls: Steam's picture of each control and what it
      does. }
    procedure ShowControlsMenu;
    { Open a book: the EPUBs in the books folder (and its folders). }
    procedure ShowBooksMenu;
    { Row AIndex of the main menu's value as it reads now (text size,
      speed, on / off).
      @param(AIndex  MENU_RESUME .. MENU_EXIT)
      @returns(the value; '' for none) }
    function PadMenuValue(AIndex: Integer): string;
    { The hints at the foot of the menu: the pad's own names for choose,
      back and change (the keys without a pad).
      @param(AChange  with left / right's "change")
      @returns(the line) }
    function PadMenuFoot(AChange: Boolean): string;
    { The colours of the pad's menu for the theme. }
    procedure PadMenuColors;
    { A menu row chosen (pad or click).
      @param(Sender  the menu)
      @param(AIndex  the row) }
    procedure PadMenuChoose(Sender: TObject; AIndex: Integer);
    { The menu closed by a click beside it. }
    procedure PadMenuClose(Sender: TObject);
    { Left / right on a menu row with a value (text size, speed).
      @param(ADelta  -1 or 1) }
    procedure PadMenuStep(ADelta: Integer);
    { The library's pad choice moved to the nearest cover that way.
      @param(ADX  -1, 0, 1)
      @param(ADY  -1, 0, 1) }
    procedure MoveCover(ADX, ADY: Integer);
    { FCoverSel's frame placed (or hidden). }
    procedure ShowCoverSelection;
    { Opens AFileName. }
    procedure OpenBook(const AFileName: string);
    { Plays from the start of clip AClip. }
    procedure StartClip(AClip: Integer);
    { Stops the audio (the highlight stays). }
    procedure StopPlaying;
    { First clip of document ADoc, -1 when none. }
    function FirstClipOfDocument(ADoc: Integer): Integer;
    { The clip reading word AWord, -1 when none. }
    function ClipOfWord(AWord: Integer): Integer;
    { Enables the buttons and writes the status. }
    procedure UpdateControls;
    { Makes the tool bar's buttons. }
    procedure BuildToolBar;
    { An icon button (Sprite3D's way: a TPath in a TButton). }
    function AddIconButton(const AIcon, AHint: string; AOnClick: TNotifyEvent): TButton;
    { A text button. }
    function AddTextButton(const AText, AHint: string; AOnClick: TNotifyEvent): TButton;
    { An icon takes the colour the style gives the button's text. }
    procedure IconButtonApplyStyle(Sender: TObject);
    { Shows AIcon on button AButton. }
    procedure SetIcon(AButton: TButton; const AIcon: string);
    { Loads FFmpeg and the sound output (FSoundNote says what is missing). }
    procedure StartSound;
    { Makes the chapter list (FChapterWord / Toc / Doc). }
    procedure BuildChapters;
    { The chapter word AWord is in, -1 before the first. }
    function ChapterOfWord(AWord: Integer): Integer;
    { Shows chapter AChapter and moves the audio to its first clip. }
    procedure GoChapter(AChapter: Integer);
    { The word being read or shown: the clip's first word, else the shown
      document's first word; -1 without a book. }
    function CurrentWord: Integer;
    { The first clip with words at or after word AWord, -1 when none. }
    function ClipFromWord(AWord: Integer): Integer;
    { Goes to clip AClip: played from there when playing, else highlighted
      and Play starts there. }
    procedure GoClip(AClip: Integer);
    { The block (paragraph) of word AWord in its document's layout. }
    function WordBlock(AWord: Integer): Integer;
    { What Previous / Next step by (UNIT_PHRASE, UNIT_SENTENCE,
      UNIT_PARAGRAPH): cbStep's choice, whose list starts with Phrase only
      in Learn to read. }
    function StepUnit: Integer;
    { Fills cbStep for the mode (Learn to read: Word, Sentence, Paragraph,
      Word chosen; else Sentence, Paragraph), keeping the unit when it can. }
    procedure FillSteps;
    { A unit (word, sentence or paragraph, by StepUnit) starts at word
      AWord. }
    function IsUnitStart(AWord: Integer): Boolean;
    { The last word of the unit that starts at word AWord. }
    function UnitEnd(AWord: Integer): Integer;
    { Opens the audio file of clip AClip in the player (extracted from the
      book once); False when it cannot (FSoundNote says why). }
    function OpenClipAudio(AClip: Integer): Boolean;
    { Learn to read: shows words AFirst .. ALast and says them, then
      stops (no sound for words without clips). }
    procedure SayWords(AFirst, ALast: Integer);
    { Learn to read: Next (ADirection 1) / Previous (-1). }
    procedure LearnStep(ADirection: Integer);
    { Makes the menu bar. }
    procedure BuildMenu;
    { The OS menu bar shows the items' changes (nothing to do on Linux,
      where FMX draws the bar). }
    procedure RefreshMenu;
    { Fills File > Recently Opened from FRecent. }
    procedure BuildRecentMenu;
    { A Recently Opened item: opens its book (Tag = index in FRecent). }
    procedure miRecentItemClick(Sender: TObject);
    { Fills File > Go to Footnote with the open book's notes. }
    procedure BuildNotesMenu;
    { A Go to Footnote item: shows the note (Tag = index in FNoteWords). }
    procedure miNoteClick(Sender: TObject);
    { File > Recently Opened > Clear the list. }
    procedure miClearRecentClick(Sender: TObject);
    { Opens book AIndex of FRecent; one no longer there is taken off the
      list (with a message). }
    procedure OpenRecent(AIndex: Integer);
    { Makes the library (hidden). }
    procedure BuildLibrary;
    { Shows the library: a cover per recent book (made and cached when
      missing), the current one large. }
    procedure ShowLibrary;
    { Hides it (the page shows again). }
    procedure HideLibrary;
    { The library is showing. }
    function LibraryShowing: Boolean;
    { Places the covers: a grid as large as fits, the first cover over
      2 x 2 tiles, centred both ways. }
    procedure LayoutLibrary;
    { recLibrary was resized: LayoutLibrary. }
    procedure recLibraryResized(Sender: TObject);
    { The page under the library must not scroll. }
    procedure recLibraryMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
      var Handled: Boolean);
    { A cover was clicked: its book (the open one: back to it). }
    procedure CoverClick(Sender: TObject);
    { File > Library. }
    procedure miLibraryClick(Sender: TObject);
    { Opens book FLibraryOpen. }
    procedure tmLibraryTimer(Sender: TObject);
    { File > Exit. }
    procedure miExitClick(Sender: TObject);
    { Makes the find bar (hidden). }
    procedure BuildFindBar;
    { Edit > Find: shows the find bar, the text selected. }
    procedure miFindClick(Sender: TObject);
    { Edit > Find next. }
    procedure miFindNextClick(Sender: TObject);
    { Edit > Find previous. }
    procedure miFindPreviousClick(Sender: TObject);
    { The find bar's close button / Esc. }
    procedure btnFindCloseClick(Sender: TObject);
    { Keys in the find box: Enter next, Shift+Enter previous, Esc close. }
    procedure edFindKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    { Lists every match of AQuery in FFindHits (whole words, the last one
      may be the start of a word; case and punctuation ignored). }
    procedure FindAll(const AQuery: string);
    { Shows the next (ADirection 1) or previous (-1) match, from the place
      being read; round the book at its end. }
    procedure FindStep(ADirection: Integer);
    { The word the reader is at (the unit said in Learn to read, else the
      clip highlighted, else the shown document's first word); -1 = none. }
    function ReadingWord: Integer;
    { Puts the open book first in FRecent with its reading position. }
    procedure RememberBook;
    { Index in FRecent of the book with file name AFileName (the name
      without folder decides, for now: owner), -1 when none. }
    function RecentIndex(const AFileName: string): Integer;
    { Goes to word AWord as when reading paused there: its clip
      highlighted, Play starts there. }
    procedure RestoreWord(AWord: Integer);
    { The shown document's block count, for the debug log.
      @returns(0 when no document is laid out) }
    function LayoutBlocks: Integer;
    { Reads dark mode, text size, speed and the recent books
      (SettingsFile). }
    procedure LoadSettings;
    { Writes them. }
    procedure SaveSettings;
    { The start of the sentence / paragraph that word AWord is in. }
    function UnitStart(AWord: Integer): Integer;
    { Selects in lbToc the chapter of word AWord (no jump). }
    procedure SyncToc(AWord: Integer);
    { Colours of the page and the panels for FDark. }
    procedure ApplyTheme;
    { lbToc's style is (re)applied: its background for FDark. }
    procedure TocApplyStyle(Sender: TObject);
  end;

var
  { The main form. }
  frmMain: TfrmMain;

implementation

{$R *.fmx}

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows, Winapi.ShlObj, System.Win.Registry,
  {$ENDIF}
  {$IFDEF POSIX}
  // System.SysUtils.DeleteFile's inline body expands only with it (H2443)
  Posix.Unistd,
  {$ENDIF}
  System.Hash, System.UIConsts, System.Skia, System.Generics.Defaults,
  FmxWineCanvas, FmxSkiaCanvas, uSteam, uInhibit, uQuitSignal, uReaderInput;

const
  { Text size step, px. }
  SIZE_STEP = 2;
  { The smallest text on a Steam Deck (Steam's advice for its 7" screen:
    24 at the least - owner, 2026-11-18; the default 20 was too small). }
  SIZE_MIN_DECK = 24;
  { The pad's buttons, in the order of PAD_ACTIONS. }
  PAD_UP = 0;
  { Down. }
  PAD_DOWN = 1;
  { Left. }
  PAD_LEFT = 2;
  { Right. }
  PAD_RIGHT = 3;
  { Play / pause, choose (A). }
  PAD_PLAY = 4;
  { Back (B). }
  PAD_BACK = 5;
  { Say it again (X). }
  PAD_AGAIN = 6;
  { Dark mode (Y). }
  PAD_DARK = 7;
  { Previous sentence (left shoulder). }
  PAD_SENTENCE_PREV = 8;
  { Next sentence (right shoulder). }
  PAD_SENTENCE_NEXT = 9;
  { Previous chapter (left trigger). }
  PAD_CHAPTER_PREV = 10;
  { Next chapter (right trigger). }
  PAD_CHAPTER_NEXT = 11;
  { The menu (Start). }
  PAD_MENU = 12;
  { The library (Select / View). }
  PAD_LIBRARY = 13;
  { The action names, as in tools/gen_reader_input.py's manifest. }
  PAD_ACTIONS: array[0..13] of string = ('Up', 'Down', 'Left', 'Right', 'Play', 'Back', 'Again', 'Dark',
    'SentencePrev', 'SentenceNext', 'ChapterPrev', 'ChapterNext', 'Menu', 'Library');
  { The pad's menu rows. }
  MENU_RESUME = 0;
  { Open a book from the books folder. }
  MENU_OPEN = 1;
  { The library. }
  MENU_LIBRARY = 2;
  { The contents. }
  MENU_CONTENTS = 3;
  { Text size (left / right). }
  MENU_SIZE = 4;
  { Speed (left / right). }
  MENU_SPEED = 5;
  { Dark mode. }
  MENU_DARK = 6;
  { Learn to read. }
  MENU_LEARN = 7;
  { The pad's controls. }
  MENU_CONTROLS = 8;
  { Exit. }
  MENU_EXIT = 9;
  { FMenuMode: the main menu. }
  MODE_MAIN = 0;
  { The contents. }
  MODE_CONTENTS = 1;
  { The controls. }
  MODE_CONTROLS = 2;
  { The books of the books folder. }
  MODE_BOOKS = 3;
  { The stick's scrolling at full tilt, units a second. }
  PAD_SCROLL_SPEED = 1500;
  { The stick's dead zone. }
  PAD_STICK_DEAD = 0.15;
  // The tool bar's icons: SVG path data in a 24 by 24 box (Sprite3D's
  // transport icons; the folder is new). FMX.Objects' TPath (the shape)
  // hides System.IOUtils' TPath (file names): both are written qualified.
  { Previous document: bar and two triangles pointing left. }
  ICON_FIRST = 'M5 6h2v12H5z M8 12l6-6v12z M14 12l6-6v12z';
  { Previous clip: triangle left and bar. }
  ICON_PREVIOUS = 'M7 12l7-6v12z M15 6h2v12h-2z';
  { Play: triangle right. }
  ICON_PLAY = 'M8 5v14l11-7z';
  { Pause: two bars. }
  ICON_PAUSE = 'M6 5h4v14H6z M14 5h4v14h-4z';
  { Next clip: bar and triangle right. }
  ICON_NEXT = 'M7 6h2v12H7z M10 6v12l7-6z';
  { Next document: two triangles right and bar. }
  ICON_LAST = 'M4 6v12l6-6z M10 6v12l6-6z M17 6h2v12h-2z';
  { Dark mode: a crescent moon. }
  ICON_DARK = 'M15 3C10 3 6 7 6 12s4 9 9 9c-3-2-5-5-5-9s2-7 5-9z';
  { Icon box, px. }
  ICON_SIZE = 24;
  { Slowest speed: FFmpegAPI's player (one atempo filter) goes down to 0.5. }
  SPEED_MIN = 0.5;
  { Fastest speed (owner: 2x "sounds silly"; the player goes to 2). }
  SPEED_MAX = 1.5;
  { Speed slider and [ / ] keys step. }
  SPEED_STEP = 0.1;
  { The slider must rest this long before the player gets the speed, ms
    (a drag, a held [ / ] key: applied once, at the end). }
  SPEED_SETTLE_MS = 300;
  { Step unit (StepUnit): a phrase - the words between two marks of
    punctuation (, ; : . ! ? ) or a dash), Learn to read only: whole
    sentences are often too much prose for a learner (owner). Word steps
    were tried and dropped (owner: "phrase works well, drop word"); a
    click picks the unit its word is in. }
  UNIT_PHRASE = 0;
  { Step unit: a sentence. }
  UNIT_SENTENCE = 1;
  { Step unit: a paragraph. }
  UNIT_PARAGRAPH = 2;
  { Learn to read: sound added before a unit said on its own, s. 0: with
    40 ms a single word took in the end of the word before (owner). }
  SAY_PAD_BEFORE = 0;
  { Learn to read: sound added after it, s (0, as above: the next word's
    start was heard). }
  SAY_PAD_AFTER = 0;
  { Previous goes to the sentence before when the one being read started
    less than this long ago, s. }
  BACK_GRACE = 1.5;
  { Library: height of a cached cover, px (smaller pictures are kept as
    they are). }
  COVER_HEIGHT = 600;
  { Library: width of a made (text) cover, px. }
  TEXT_COVER_WIDTH = 400;
  { Library: a tile's height / width (a book's shape). }
  COVER_ASPECT = 1.5;
  { Library: space between tiles and round the grid, px. }
  COVER_GAP = 16;
  { Dark mode: page. }
  DARK_PAGE = $FF1E1E1E;
  { Dark mode: text. }
  DARK_TEXT = $FFD8D8D8;
  { Dark mode: highlight (dark amber: light text stays readable on it). }
  DARK_HIGHLIGHT = $FF6B5310;
  { Dark mode: background of notes (footnotes). }
  DARK_NOTE = $FF2C2C34;
  { Dark mode: links. }
  DARK_LINK = $FF7AB8FF;
  { Dark mode: window and contents panel. }
  DARK_PANEL = $FF2B2B2B;
  { Dark mode: panel text. }
  DARK_PANEL_TEXT = $FFE0E0E0;
  { Learn to read: tool bar band. }
  LEARN_BAR = $FFBFE8C6;
  { Learn to read: highlight (green, where reading uses amber). }
  LEARN_HIGHLIGHT = $FF8FDC9E;
  { Learn to read, dark mode: tool bar band. }
  LEARN_BAR_DARK = $FF1E5A2C;
  { Learn to read, dark mode: highlight (light text stays readable). }
  LEARN_HIGHLIGHT_DARK = $FF2F6E3C;
  { Books kept in File > Recently Opened. }
  RECENT_MAX = 10;
  { Added to the window title in Learn to read. }
  LEARN_TITLE = ' - LEARN TO READ';
  { Button width, px. }
  BUTTON_WIDTH = 36;
  { Longest extension kept for an extracted audio file, the dot included. }
  MAX_AUDIO_EXTENSION = 8;

{ The extension of APath (a path inside a book) for the extracted copy:
  '.mp3', '.m4a', ... when it is a dot and a few ASCII letters or digits,
  else '' - nothing of the book's path that could name another folder. }
function SafeAudioExtension(const APath: string): string;
var
  I, P: Integer;
begin
  Result := '';
  P := LastDelimiter('.', APath);
  if (P = 0) or (Length(APath) - P + 1 > MAX_AUDIO_EXTENSION) or (P = Length(APath)) then
    Exit;
  for I := P + 1 to Length(APath) do
    if not CharInSet(APath[I], ['a'..'z', 'A'..'Z', '0'..'9']) then
      Exit;
  Result := Copy(APath, P, MaxInt);
end;

function TfrmMain.AddIconButton(const AIcon, AHint: string; AOnClick: TNotifyEvent): TButton;
var
  Icon: FMX.Objects.TPath;
begin
  Result := TButton.Create(Self);
  Result.Parent := layTop;
  // left-aligned controls are ordered by their X: each goes after the last
  Result.Position.X := layTop.ChildrenCount * 1000;
  Result.Align := TAlignLayout.Left;
  Result.Width := BUTTON_WIDTH;
  Result.Margins.Left := 2;
  Result.Margins.Top := 6;
  Result.Margins.Bottom := 6;
  Result.Text := '';
  Result.Hint := AHint;
  Result.ShowHint := True;
  Result.OnClick := AOnClick;
  Result.OnApplyStyleLookup := IconButtonApplyStyle;
  Icon := FMX.Objects.TPath.Create(Self);
  Icon.Parent := Result;
  Icon.Align := TAlignLayout.Center;
  Icon.Width := ICON_SIZE;
  Icon.Height := ICON_SIZE;
  Icon.WrapMode := TPathWrapMode.Original;
  Icon.Data.Data := AIcon;
  Icon.Stroke.Kind := TBrushKind.None;
  Icon.Fill.Color := TAlphaColors.Black;   // the style's colour once styled
  Icon.HitTest := False;
  Result.TagObject := Icon;
end;

function TfrmMain.AddTextButton(const AText, AHint: string; AOnClick: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := layTop;
  Result.Position.X := layTop.ChildrenCount * 1000;
  Result.Align := TAlignLayout.Left;
  Result.Width := BUTTON_WIDTH;
  Result.Margins.Left := 2;
  Result.Margins.Top := 6;
  Result.Margins.Bottom := 6;
  Result.Text := AText;
  Result.Hint := AHint;
  Result.ShowHint := True;
  Result.OnClick := AOnClick;
end;

procedure TfrmMain.IconButtonApplyStyle(Sender: TObject);
var
  Button: TButton;
begin
  Button := Sender as TButton;
  if Button.TagObject is FMX.Objects.TPath then
    FMX.Objects.TPath(Button.TagObject).Fill.Color := Button.ResultingTextSettings.FontColor;
end;

procedure TfrmMain.SetIcon(AButton: TButton; const AIcon: string);
begin
  if (AButton <> nil) and (AButton.TagObject is FMX.Objects.TPath) then
    FMX.Objects.TPath(AButton.TagObject).Data.Data := AIcon;
end;

procedure TfrmMain.BuildToolBar;
begin
  recLearn := TRectangle.Create(Self);
  recLearn.Parent := layTop;
  recLearn.Align := TAlignLayout.Contents;
  recLearn.HitTest := False;
  recLearn.Stroke.Kind := TBrushKind.None;
  recLearn.Fill.Color := LEARN_BAR;
  recLearn.Visible := False;
  recLearn.SendToBack;
  btnPrev := AddIconButton(ICON_FIRST, 'Previous chapter (the audio follows)', btnPrevClick);
  btnPrevClip := AddIconButton(ICON_PREVIOUS, 'Previous sentence', btnPrevClipClick);
  btnPlay := AddIconButton(ICON_PLAY, 'Play / pause (P)', btnPlayClick);
  btnNextClip := AddIconButton(ICON_NEXT, 'Next sentence', btnNextClipClick);
  btnNext := AddIconButton(ICON_LAST, 'Next chapter (the audio follows)', btnNextClick);
  // what previous / next step by
  cbStep := TComboBox.Create(Self);
  cbStep.Parent := layTop;
  cbStep.Position.X := layTop.ChildrenCount * 1000;
  cbStep.Align := TAlignLayout.Left;
  cbStep.Width := 110;
  cbStep.Margins.Left := 4;
  cbStep.Margins.Top := 9;
  cbStep.Margins.Bottom := 9;
  cbStep.Hint := 'What previous / next step by';
  cbStep.ShowHint := True;
  FillSteps;
  cbStep.OnChange := cbStepChange;
  btnLearn := AddTextButton('Abc', 'Learn to read (L): Next / Previous say one phrase, sentence or ' +
    'paragraph and stop; click a word for its phrase; Play or R says it again', btnLearnClick);
  btnLearn.StaysPressed := True;
  // playing speed: the pitch stays (FFmpeg's atempo)
  lblSpeed := TLabel.Create(Self);
  lblSpeed.Parent := layTop;
  lblSpeed.Position.X := layTop.ChildrenCount * 1000;
  lblSpeed.Align := TAlignLayout.Left;
  lblSpeed.Width := 40;
  lblSpeed.Margins.Left := 8;
  lblSpeed.TextSettings.HorzAlign := TTextAlign.Trailing;
  lblSpeed.Text := '1.0x';
  lblSpeed.HitTest := True;
  lblSpeed.Hint := 'Playing speed - click for 1x';
  lblSpeed.ShowHint := True;
  lblSpeed.OnClick := lblSpeedClick;
  tbSpeed := TTrackBar.Create(Self);
  tbSpeed.Parent := layTop;
  tbSpeed.Position.X := layTop.ChildrenCount * 1000;
  tbSpeed.Align := TAlignLayout.Left;
  tbSpeed.Width := 110;
  tbSpeed.Margins.Left := 4;
  tbSpeed.Margins.Right := 4;
  tbSpeed.Margins.Top := 12;
  tbSpeed.Margins.Bottom := 12;
  tbSpeed.Min := SPEED_MIN;
  tbSpeed.Max := SPEED_MAX;
  tbSpeed.Frequency := SPEED_STEP;
  tbSpeed.Value := 1;
  tbSpeed.Hint := 'Playing speed, 0.5x - 1.5x ([ slower, ] faster)';
  tbSpeed.ShowHint := True;
  tbSpeed.OnChange := tbSpeedChange;
  FPendingSpeed := 1;
  tmSpeed := TTimer.Create(Self);
  tmSpeed.Enabled := False;
  tmSpeed.Interval := SPEED_SETTLE_MS;
  tmSpeed.OnTimer := tmSpeedTimer;
  btnSmaller := AddTextButton('A-', 'Smaller text (Ctrl+Minus)', btnSmallerClick);
  btnLarger := AddTextButton('A+', 'Larger text (Ctrl+Plus)', btnLargerClick);
  btnDark := AddIconButton(ICON_DARK, 'Dark mode (D)', btnDarkClick);
  lblStatus.Position.X := layTop.ChildrenCount * 1000;   // after the buttons
end;

procedure TfrmMain.StartSound;
begin
  DebugLog('sound: loading FFmpeg');
  try
    // any FFmpeg 8 build - GPL or LGPL (owner): the licence is shown
    FFFmpeg := TFFmpegLibrary.Create('');
    DebugLog('sound: ' + FFFmpeg.Description);
    FPlayer := TFFmpegAudioPlayer.Create(FFFmpeg);
    FSoundNote := FPlayer.OutputNote;
    DebugLog('sound output: ' + FPlayer.Output.Description);
    {$IFDEF POSIX}
    WriteLn(ErrOutput, FFFmpeg.Description);
    WriteLn(ErrOutput, 'Sound output: ', FPlayer.Output.Description);
    {$ENDIF}
  except
    on E: Exception do
    begin
      DebugLog('sound: none - ' + E.Message);
      FreeAndNil(FPlayer);
      FreeAndNil(FFFmpeg);
      FSoundNote := 'No sound: ' + E.Message;
    end;
  end;
end;

{ The settings file, the platform's way (JSON: they will grow): Windows
  %APPDATA%\EpubReader\EpubReader.json, macOS ~/Library/Application
  Support/EpubReader/EpubReader.json, Linux $XDG_CONFIG_HOME (else
  ~/.config)/EpubReader/EpubReader.json. }
{ The books folder at first. A Steam build on Windows and Linux: Books
  beside the program - a Steam Deck has no file dialog to reach anything
  else, and the folder is easy to find from Steam (Manage > Browse local
  files). The Mac (the program is a signed bundle) and other builds:
  Documents/EpubReader/Books. Owner, 2026-11-18. }
function BooksFolderDefault: string;
begin
  {$IF Defined(STEAMBUILD) and not Defined(MACOS)}
  Result := System.IOUtils.TPath.Combine(ExtractFileDir(ParamStr(0)), 'Books');
  {$ELSE}
  Result := System.IOUtils.TPath.Combine(System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetDocumentsPath,
    'EpubReader'), 'Books');
  {$ENDIF}
end;

function SettingsFile: string;
var
  Base: string;
begin
  {$IF Defined(MSWINDOWS)}
  Base := System.IOUtils.TPath.GetHomePath;   // %APPDATA% (Roaming)
  {$ELSEIF Defined(MACOS)}
  Base := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetHomePath, 'Library/Application Support');
  {$ELSE}
  Base := GetEnvironmentVariable('XDG_CONFIG_HOME');
  if Base = '' then
    Base := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetHomePath, '.config');
  {$ENDIF}
  Result := System.IOUtils.TPath.Combine(System.IOUtils.TPath.Combine(Base, 'EpubReader'), 'EpubReader.json');
end;

{ The cached cover of book ABookFile: covers\<MD5 of the file name>.png
  beside the settings file. By the file NAME, as the recent list matches
  books (a moved book keeps its cover); the user may replace the picture. }
function CoverFile(const ABookFile: string): string;
begin
  Result := System.IOUtils.TPath.Combine(System.IOUtils.TPath.Combine(ExtractFilePath(SettingsFile), 'covers'),
    THashMD5.GetHashString(LowerCase(ExtractFileName(ABookFile))) + '.png');
end;

{ Writes a made cover to AFile: ATitle and AAuthor on a colour of the
  title's own (the same title always gets the same colour). }
procedure SaveTextCover(const AFile, ATitle, AAuthor: string);
var
  Bmp: FMX.Graphics.TBitmap;
  Hue: Cardinal;
  I, H: Integer;
begin
  H := Round(TEXT_COVER_WIDTH * COVER_ASPECT);
  Hue := 0;
  for I := 1 to Length(ATitle) do
    Hue := (Hue * 31 + Ord(ATitle[I])) mod 360;
  DebugLog(Format('cover: made one, %d x %d', [TEXT_COVER_WIDTH, H]));
  Bmp := FMX.Graphics.TBitmap.Create(TEXT_COVER_WIDTH, H);
  try
    DebugLog('cover: drawing');
    if Bmp.Canvas.BeginScene then
    try
      Bmp.Canvas.Clear(HSLtoRGB(Hue / 360, 0.45, 0.30));
      // a frame
      Bmp.Canvas.Stroke.Kind := TBrushKind.Solid;
      Bmp.Canvas.Stroke.Color := TAlphaColors.White;
      Bmp.Canvas.Stroke.Thickness := 4;
      Bmp.Canvas.DrawRect(RectF(18, 18, TEXT_COVER_WIDTH - 18, H - 18), 0, 0, AllCorners, 0.5);
      // the title, smaller when long; the author under it
      Bmp.Canvas.Fill.Kind := TBrushKind.Solid;
      Bmp.Canvas.Fill.Color := TAlphaColors.White;
      Bmp.Canvas.Font.Style := [TFontStyle.fsBold];
      if Length(ATitle) <= 24 then
        Bmp.Canvas.Font.Size := 40
      else if Length(ATitle) <= 60 then
        Bmp.Canvas.Font.Size := 32
      else
        Bmp.Canvas.Font.Size := 24;
      Bmp.Canvas.FillText(RectF(44, 60, TEXT_COVER_WIDTH - 44, H * 0.64), ATitle, True, 1, [], TTextAlign.Center,
        TTextAlign.Center);
      Bmp.Canvas.Font.Style := [];
      Bmp.Canvas.Font.Size := 24;
      Bmp.Canvas.FillText(RectF(44, H * 0.68, TEXT_COVER_WIDTH - 44, H - 50), AAuthor, True, 1, [],
        TTextAlign.Center, TTextAlign.Leading);
    finally
      Bmp.Canvas.EndScene;
    end;
    DebugLog('cover: drawn, saving ' + AFile);
    Bmp.SaveToFile(AFile);
    DebugLog('cover: saved');
  finally
    Bmp.Free;
  end;
end;

{ Writes the picture ABytes (the book's cover image) to AFile as PNG, at
  most COVER_HEIGHT high. @raises(an exception when it is not a picture
  FMX reads - an SVG cover, say.) }
procedure SaveImageCover(const ABytes: TBytes; const AFile: string);
var
  S: TBytesStream;
  Src, Dst: FMX.Graphics.TBitmap;
  Scale: Single;
  W, H: Integer;
begin
  DebugLog(Format('cover: the book''s picture, %d bytes - decoding', [Length(ABytes)]));
  S := TBytesStream.Create(ABytes);
  Src := FMX.Graphics.TBitmap.Create;
  try
    Src.LoadFromStream(S);
    DebugLog(Format('cover: decoded, %d x %d', [Src.Width, Src.Height]));
    if (Src.Width = 0) or (Src.Height = 0) then
      raise EEpubError.Create('The cover image is empty');
    Scale := Min(1, COVER_HEIGHT / Src.Height);
    W := Max(1, Round(Src.Width * Scale));
    H := Max(1, Round(Src.Height * Scale));
    Dst := FMX.Graphics.TBitmap.Create(W, H);
    try
      DebugLog(Format('cover: scaling to %d x %d', [W, H]));
      if Dst.Canvas.BeginScene then
      try
        Dst.Canvas.DrawBitmap(Src, RectF(0, 0, Src.Width, Src.Height), RectF(0, 0, W, H), 1, False);
      finally
        Dst.Canvas.EndScene;
      end;
      DebugLog('cover: scaled, saving ' + AFile);
      Dst.SaveToFile(AFile);
      DebugLog('cover: saved');
    finally
      Dst.Free;
    end;
  finally
    Src.Free;
    S.Free;
  end;
end;

{ The faces Skia finds for a few family names, and where fontconfig would
  look, into the debug log: inside Steam's Linux runtime the reader crashed
  (access violation reading address 0, in a library) on the first page
  laid out with Skia (owner, Steam Deck, 2026-11-17) - is there a face at
  all? }
{$IFDEF LINUX}
procedure LogFontProbe;
const
  NAMES: array[0..5] of string = ('sans-serif', 'serif', 'monospace', 'DejaVu Sans', 'Noto Sans',
    'Liberation Sans');
  {$IFDEF POSIX}
  FOLDERS: array[0..4] of string = ('/etc/fonts', '/usr/share/fonts', '/run/host/fonts',
    '/run/host/user-fonts', '/run/host/local-fonts');
  {$ENDIF}
var
  I: Integer;
  T: ISkTypeface;
  Name, Line: string;
begin
  Line := '';
  for I := -1 to High(NAMES) do
  begin
    if I < 0 then
      Name := GetEnvironmentVariable('EPUBREADER_FONT')
    else
      Name := NAMES[I];
    if Name = '' then
      Continue;
    try
      T := TSkTypeface.MakeFromName(Name, TSkFontStyle.Create(TSkFontWeight.Normal, TSkFontWidth.Normal,
        TSkFontSlant.Upright));
      if T = nil then
        Line := Line + Format('%s -> NONE; ', [Name])
      else
        Line := Line + Format('%s -> %s; ', [Name, T.FamilyName]);
    except
      on E: Exception do
        Line := Line + Format('%s -> %s: %s; ', [Name, E.ClassName, E.Message]);
    end;
  end;
  DebugLog('fonts: ' + Line);
  {$IFDEF POSIX}
  Line := '';
  for I := 0 to High(FOLDERS) do
    if DirectoryExists(FOLDERS[I]) then
      Line := Line + FOLDERS[I] + ' yes; '
    else
      Line := Line + FOLDERS[I] + ' NO; ';
  DebugLog('fonts: folders ' + Line + 'FONTCONFIG_FILE=' + GetEnvironmentVariable('FONTCONFIG_FILE') +
    ' FONTCONFIG_PATH=' + GetEnvironmentVariable('FONTCONFIG_PATH'));
  {$ENDIF}
end;
{$ENDIF}

{ Makes the cached cover of ABookFile when there is none: the book's own
  picture, else a made one with its title and author. ABook: the book when
  it is open (nil: opened here, without its text, when the file is there).
  ATitle: the title to use when the book cannot be read. Errors leave no
  cover (the library shows the title instead). }
procedure EnsureCover(const ABookFile: string; ABook: TEpubBook; const ATitle: string);
var
  F, Title, Author: string;
  Own: TEpubBook;
  I: Integer;
begin
  DebugLog('cover: ' + ABookFile);
  // EPUBREADER_NO_COVERS=1: no covers made (the library shows titles) -
  // for finding why making one hangs (owner, Linux, 2026-11-16)
  if GetEnvironmentVariable('EPUBREADER_NO_COVERS') = '1' then
  begin
    DebugLog('cover: not made (EPUBREADER_NO_COVERS=1)');
    Exit;
  end;
  F := CoverFile(ABookFile);
  if FileExists(F) then
    Exit;
  Own := nil;
  try
    try
      ForceDirectories(ExtractFilePath(F));
      if (ABook = nil) and FileExists(ABookFile) then
        try
          Own := TEpubBook.Create(ABookFile);
          ABook := Own;
        except
          // not readable now: a made cover from what the list knows
          ABook := nil;
        end;
      Title := ATitle;
      Author := '';
      if ABook <> nil then
      begin
        if ABook.Title <> '' then
          Title := ABook.Title;
        for I := 0 to ABook.Creators.Count - 1 do
          if I = 0 then
            Author := ABook.Creators[I]
          else
            Author := Author + ', ' + ABook.Creators[I];
        if ABook.CoverPath <> '' then
          try
            SaveImageCover(ABook.ReadResource(ABook.CoverPath), F);
            Exit;
          except
            // a picture FMX cannot read: a made cover
            on E: Exception do
              DebugLog('cover: the book''s picture failed - ' + E.Message);
          end;
      end;
      if Title = '' then
        Title := ChangeFileExt(ExtractFileName(ABookFile), '');
      SaveTextCover(F, Title, Author);
    except
      // no cover: the library shows the title
    end;
  finally
    Own.Free;
  end;
end;

{ Puts the reader in the system's "Open with" list for .epub files, for
  this user only (no administrator rights; the default program is left as
  it is - Windows lets only the user choose that, in "Open with > Always").
  Windows: HKCU\Software\Classes - a ProgID EpubUnum.EpubReader with the
  open command, .epub\OpenWithProgids naming it, Applications\
  EpubReader.exe\SupportedTypes; then the shell is told. Linux: a
  .desktop file for application/epub+zip in ~/.local/share/applications
  (through EpubReader.sh when it is next to the program - SteamOS needs
  its ICU set-up). Written only when missing or pointing elsewhere (the
  program moved), so a normal start changes nothing. Returns what was
  done ('' when nothing). }
function RegisterOpenWith: string;
const
  PROG_ID = 'EpubUnum.EpubReader';
var
  Exe, Command: string;
  {$IFDEF MSWINDOWS}
  Reg: TRegistry;
  {$ENDIF}
  {$IFDEF LINUX}
  Folder, FileName, Launcher, Text: string;
  {$ENDIF}
begin
  Result := '';
  Exe := ParamStr(0);
  {$IFDEF MSWINDOWS}
  Command := '"' + Exe + '" "%1"';
  Reg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly('Software\Classes\' + PROG_ID + '\shell\open\command') and
      (Reg.ReadString('') = Command) then
      Exit;
    Reg.CloseKey;
    // OpenKeyReadOnly leaves the object's Access at KEY_READ: every write
    // after it failed ("Failed to set data", seen in the debugger at
    // start-up) - writing needs it back
    Reg.Access := KEY_READ or KEY_WRITE;
    if Reg.OpenKey('Software\Classes\' + PROG_ID, True) then
    begin
      Reg.WriteString('', 'EPUB book');
      Reg.CloseKey;
    end;
    if Reg.OpenKey('Software\Classes\' + PROG_ID + '\DefaultIcon', True) then
    begin
      Reg.WriteString('', '"' + Exe + '",0');
      Reg.CloseKey;
    end;
    if Reg.OpenKey('Software\Classes\' + PROG_ID + '\shell\open\command', True) then
    begin
      Reg.WriteString('', Command);
      Reg.CloseKey;
    end;
    if Reg.OpenKey('Software\Classes\.epub\OpenWithProgids', True) then
    begin
      Reg.WriteString(PROG_ID, '');
      Reg.CloseKey;
    end;
    if Reg.OpenKey('Software\Classes\Applications\' + ExtractFileName(Exe) + '\SupportedTypes', True) then
    begin
      Reg.WriteString('.epub', '');
      Reg.CloseKey;
    end;
    if Reg.OpenKey('Software\Classes\Applications\' + ExtractFileName(Exe) + '\shell\open\command', True) then
    begin
      Reg.WriteString('', Command);
      Reg.CloseKey;
    end;
    SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nil, nil);
    Result := 'Added to "Open with" for .epub files';
  finally
    Reg.Free;
  end;
  {$ENDIF}
  {$IFDEF LINUX}
  Launcher := System.IOUtils.TPath.Combine(ExtractFilePath(Exe), 'EpubReader.sh');
  if FileExists(Launcher) then
    Command := '"' + Launcher + '" %f'
  else
    Command := '"' + Exe + '" %f';
  Folder := GetEnvironmentVariable('XDG_DATA_HOME');
  if Folder = '' then
    Folder := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetHomePath, '.local/share');
  Folder := System.IOUtils.TPath.Combine(Folder, 'applications');
  FileName := System.IOUtils.TPath.Combine(Folder, 'epubreader.desktop');
  Text := '[Desktop Entry]'#10'Type=Application'#10'Name=EpubReader'#10 +
    'Comment=Read EPUB books, read aloud with the words highlighted'#10'Exec=' + Command + #10 +
    'MimeType=application/epub+zip;'#10'Terminal=false'#10'Categories=Office;Viewer;'#10;
  if FileExists(FileName) and (TFile.ReadAllText(FileName) = Text) then
    Exit;
  ForceDirectories(Folder);
  TFile.WriteAllText(FileName, Text);
  Result := 'Added to "Open with" for EPUB books (' + FileName + ')';
  {$ENDIF}
end;

procedure TfrmMain.BuildMenu;

  { A menu item under AParent. }
  function Item(AParent: TFmxObject; const AText: string; AOnClick: TNotifyEvent): TMenuItem;
  begin
    Result := TMenuItem.Create(Self);
    Result.Parent := AParent;
    // the key after a tab: the native menus show it at the right; FMX's own
    // bar (Linux) would draw the tab, so it gets spaces
    {$IF Defined(LINUX) and not Defined(ANDROID)}
    Result.Text := StringReplace(AText, #9, '    ', []);
    {$ELSE}
    Result.Text := AText;
    {$ENDIF}
    Result.OnClick := AOnClick;
  end;

var
  M: TMenuItem;
  Bar: TFmxObject;
begin
  {$IF Defined(LINUX) and not Defined(ANDROID)}
  mnuBar := TMenuBar.Create(Self);
  mnuBar.Parent := Self;
  mnuBar.Position.Y := -1;   // above the tool bar
  mnuBar.Align := TAlignLayout.Top;
  // Big Picture: no menu bar (the items are still made - code uses them)
  mnuBar.Visible := not SteamBigPicture;
  Bar := mnuBar;
  {$ELSE}
  mnuMain := TMainMenu.Create(Self);
  // Big Picture: no menu bar - the menu is not put on the form (its items
  // are still made: code uses them); keys and the tool bar do the rest
  if not SteamBigPicture then
    mnuMain.Parent := Self;
  Bar := mnuMain;
  {$ENDIF}
  M := Item(Bar, '&File', nil);
  Item(M, '&Open...'#9'Ctrl+O', btnOpenClick);
  Item(M, 'Li&brary', miLibraryClick);
  miRecent := Item(M, '&Recently Opened', nil);
  // a debugging aid: only with "debug": true in the settings file
  miNotes := Item(M, 'Go to &Footnote', nil);
  miNotes.Enabled := False;
  miNotes.Visible := False;
  Item(M, '-', nil);
  Item(M, 'E&xit', miExitClick);
  M := Item(Bar, '&Edit', nil);
  Item(M, '&Find...'#9'Ctrl+F', miFindClick);
  Item(M, 'Find &next'#9'F3', miFindNextClick);
  Item(M, 'Find &previous'#9'Shift+F3', miFindPreviousClick);
  M := Item(Bar, '&View', nil);
  miDark := Item(M, '&Dark mode'#9'D', btnDarkClick);
  miLearn := Item(M, '&Learn to read'#9'L', btnLearnClick);
  Item(M, '-', nil);
  Item(M, '&Larger text'#9'Ctrl+Plus', btnLargerClick);
  Item(M, '&Smaller text'#9'Ctrl+Minus', btnSmallerClick);
  BuildRecentMenu;
  // a menu made in code reaches the window (Windows' / macOS' own menu
  // bar) only when it is recreated - without this there was no menu
  RefreshMenu;
end;

procedure TfrmMain.RefreshMenu;
begin
  // a menu made in code reaches the window (Windows' / macOS' own menu
  // bar) only when it is recreated
  if (mnuMain <> nil) and (mnuMain.Parent <> nil) then
    mnuMain.RecreateOSMenu;
end;

procedure TfrmMain.BuildRecentMenu;
var
  I: Integer;
  M: TMenuItem;
begin
  while miRecent.ItemsCount > 0 do
    miRecent.Items[0].Free;
  for I := 0 to High(FRecent) do
  begin
    M := TMenuItem.Create(Self);
    M.Parent := miRecent;
    if FRecent[I].Title <> '' then
      M.Text := Format('&%d  %s  (%s)', [(I + 1) mod 10, FRecent[I].Title, ExtractFileName(FRecent[I].FileName)])
    else
      M.Text := Format('&%d  %s', [(I + 1) mod 10, ExtractFileName(FRecent[I].FileName)]);
    M.Tag := I;
    M.OnClick := miRecentItemClick;
  end;
  if Length(FRecent) > 0 then
  begin
    M := TMenuItem.Create(Self);
    M.Parent := miRecent;
    M.Text := '-';
    M := TMenuItem.Create(Self);
    M.Parent := miRecent;
    M.Text := 'Clear the list';
    M.OnClick := miClearRecentClick;
  end;
  miRecent.Enabled := Length(FRecent) > 0;
  RefreshMenu;
end;

procedure TfrmMain.BuildNotesMenu;
const
  { Most notes listed (a menu, not an index). }
  MAX_NOTES = 300;
  { Words of a note shown in its item. }
  QUOTE_WORDS = 8;
var
  B: TEpubBook;
  W, K, N, C: Integer;
  Text, Where: string;
  M: TMenuItem;
begin
  while miNotes.ItemsCount > 0 do
    miNotes.Items[0].Free;
  FNoteWords := nil;
  B := EpubUnum1.Book;
  if B <> nil then
  begin
    // a note = a run of words whose role is note, in one document
    W := 0;
    while (W < B.WordCount) and (Length(FNoteWords) < MAX_NOTES) do
    begin
      if B.Words[W].Role <> ewrNote then
      begin
        Inc(W);
        Continue;
      end;
      FNoteWords := FNoteWords + [W];
      Text := '';
      K := W;
      N := 0;
      while (K < B.WordCount) and (B.Words[K].Role = ewrNote) and
        (B.Words[K].Document = B.Words[W].Document) do
      begin
        if N < QUOTE_WORDS then
          Text := Text + ' ' + B.Words[K].Text;
        Inc(N);
        Inc(K);
      end;
      if N > QUOTE_WORDS then
        Text := Text + ' ...';
      // where it is: its chapter
      Where := '';
      C := ChapterOfWord(W);
      if (C >= 0) and (FChapterTitle[C] <> '') then
        Where := FChapterTitle[C] + ': ';
      M := TMenuItem.Create(Self);
      M.Parent := miNotes;
      M.Text := Format('%d. %s%s', [Length(FNoteWords), Where, Trim(Text)]);
      M.Tag := High(FNoteWords);
      M.OnClick := miNoteClick;
      W := K;
    end;
  end;
  miNotes.Enabled := Length(FNoteWords) > 0;
  RefreshMenu;
end;

procedure TfrmMain.miNoteClick(Sender: TObject);
var
  I: Integer;
begin
  I := (Sender as TMenuItem).Tag;
  if (I >= 0) and (I <= High(FNoteWords)) then
    RestoreWord(FNoteWords[I]);
end;

procedure TfrmMain.miRecentItemClick(Sender: TObject);
begin
  OpenRecent((Sender as TMenuItem).Tag);
end;

procedure TfrmMain.OpenRecent(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex > High(FRecent)) then
    Exit;
  if not FileExists(FRecent[AIndex].FileName) then
  begin
    ShowMessage('The book is no longer there: ' + FRecent[AIndex].FileName);
    Delete(FRecent, AIndex, 1);
    BuildRecentMenu;
    if LibraryShowing then
      ShowLibrary;
    Exit;
  end;
  OpenBook(FRecent[AIndex].FileName);
end;

procedure TfrmMain.BuildLibrary;
begin
  // over the page, its size: where the text will be
  recLibrary := TRectangle.Create(Self);
  recLibrary.Parent := View1;
  recLibrary.Align := TAlignLayout.Client;
  recLibrary.Stroke.Kind := TBrushKind.None;
  recLibrary.Fill.Kind := TBrushKind.Solid;
  recLibrary.Fill.Color := View1.BackgroundColor;
  recLibrary.HitTest := True;
  recLibrary.Visible := False;
  recLibrary.OnResized := recLibraryResized;
  recLibrary.OnMouseWheel := recLibraryMouseWheel;
  lblLibrary := TLabel.Create(Self);
  lblLibrary.Parent := recLibrary;
  lblLibrary.Align := TAlignLayout.Client;
  lblLibrary.StyledSettings := lblLibrary.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  lblLibrary.TextSettings.Font.Size := 16;
  lblLibrary.TextSettings.FontColor := View1.TextColor;
  lblLibrary.TextSettings.HorzAlign := TTextAlign.Center;
  lblLibrary.TextSettings.VertAlign := TTextAlign.Center;
  lblLibrary.Text := 'No books yet: File > Open... (Ctrl+O) to read one.';
  lblLibrary.HitTest := False;
  tmLibrary := TTimer.Create(Self);
  tmLibrary.Enabled := False;
  tmLibrary.Interval := 1;
  tmLibrary.OnTimer := tmLibraryTimer;
end;

function TfrmMain.LibraryShowing: Boolean;
begin
  Result := (recLibrary <> nil) and recLibrary.Visible;
end;

procedure TfrmMain.ShowLibrary;
var
  I: Integer;
  Img: TImage;
  F: string;
begin
  DebugLog('library: showing');
  // the book stops (paused: Play resumes it once back on the page), and the
  // contents panel, which means nothing here, goes (owner)
  StopPlaying;
  lbToc.Visible := False;
  Splitter1.Visible := False;
  // the open book first, with where it is
  RememberBook;
  for I := 0 to High(FCoverImages) do
    FCoverImages[I].Free;
  FCoverImages := nil;
  for I := 0 to High(FRecent) do
  begin
    EnsureCover(FRecent[I].FileName, nil, FRecent[I].Title);
    Img := TImage.Create(Self);
    Img.Parent := recLibrary;
    Img.WrapMode := TImageWrapMode.Fit;
    Img.HitTest := True;
    Img.Cursor := crHandPoint;
    Img.Tag := I;
    Img.Hint := FRecent[I].Title;
    if Img.Hint = '' then
      Img.Hint := ExtractFileName(FRecent[I].FileName);
    Img.ShowHint := True;
    Img.OnClick := CoverClick;
    F := CoverFile(FRecent[I].FileName);
    if FileExists(F) then
      try
        Img.Bitmap.LoadFromFile(F);
      except
        // a damaged cache file: made again next time
        System.SysUtils.DeleteFile(F);
      end;
    // a book no longer there: faint (a click takes it off the list)
    if not FileExists(FRecent[I].FileName) then
      Img.Opacity := 0.35;
    FCoverImages := FCoverImages + [Img];
  end;
  lblLibrary.Visible := Length(FRecent) = 0;
  recLibrary.Fill.Color := View1.BackgroundColor;
  lblLibrary.TextSettings.FontColor := View1.TextColor;
  recLibrary.Visible := True;
  recLibrary.BringToFront;
  // the pad's choice: none until the pad moves it
  FCoverSel := -1;
  LayoutLibrary;
  UpdateControls;
end;

procedure TfrmMain.HideLibrary;
var
  I: Integer;
begin
  if not LibraryShowing then
    Exit;
  recLibrary.Visible := False;
  for I := 0 to High(FCoverImages) do
    FCoverImages[I].Free;
  FCoverImages := nil;
  FCoverSel := -1;
  if recCoverSel <> nil then
    recCoverSel.Visible := False;
  // the contents panel back, left of the page as before (not in Big
  // Picture: the pad's menu has the contents)
  if not SteamBigPicture then
  begin
    lbToc.Visible := True;
    Splitter1.Visible := True;
    Splitter1.Position.X := lbToc.Position.X + lbToc.Width;
  end;
  UpdateControls;
end;

procedure TfrmMain.LayoutLibrary;
var
  N, Cols, Rows, BestCols, BestRows, C, K, Row, Col, Free2: Integer;
  AreaW, AreaH, W, BestW, X0, Y0, TileH: Single;

  { Rows needed for ACols columns: the first cover over 2 x 2 tiles at
    the top left, the others round it, row by row. }
  function RowsFor(ACols: Integer): Integer;
  var
    Rest: Integer;
  begin
    Rest := Max(0, (N - 1) - 2 * (ACols - 2));
    Result := 2 + (Rest + ACols - 1) div ACols;
  end;

begin
  DebugLog('library: layout');
  N := Length(FCoverImages);
  if (N = 0) or not LibraryShowing then
    Exit;
  AreaW := recLibrary.Width;
  AreaH := recLibrary.Height;
  // the column count that gives the largest tiles
  BestW := 0;
  BestCols := 2;
  BestRows := RowsFor(2);
  for C := 2 to N + 3 do
  begin
    Rows := RowsFor(C);
    W := Min((AreaW - (C + 1) * COVER_GAP) / C, ((AreaH - (Rows + 1) * COVER_GAP) / Rows) / COVER_ASPECT);
    if W > BestW then
    begin
      BestW := W;
      BestCols := C;
      BestRows := Rows;
    end;
  end;
  if BestW <= 1 then
    Exit;
  Cols := BestCols;
  Rows := BestRows;
  W := BestW;
  TileH := W * COVER_ASPECT;
  // the grid centred both ways
  X0 := (AreaW - (Cols * W + (Cols - 1) * COVER_GAP)) / 2;
  Y0 := (AreaH - (Rows * TileH + (Rows - 1) * COVER_GAP)) / 2;
  // the current book: 2 x 2 tiles
  FCoverImages[0].SetBounds(X0, Y0, 2 * W + COVER_GAP, 2 * TileH + COVER_GAP);
  // the others: beside it in the first two rows, then full rows
  Free2 := 2 * (Cols - 2);
  for K := 0 to N - 2 do
  begin
    if K < Free2 then
    begin
      Row := K div (Cols - 2);
      Col := 2 + K mod (Cols - 2);
    end
    else
    begin
      Row := 2 + (K - Free2) div Cols;
      Col := (K - Free2) mod Cols;
    end;
    FCoverImages[K + 1].SetBounds(X0 + Col * (W + COVER_GAP), Y0 + Row * (TileH + COVER_GAP), W, TileH);
  end;
  // the pad's frame follows its cover
  if FCoverSel >= 0 then
    ShowCoverSelection;
end;

procedure TfrmMain.recLibraryResized(Sender: TObject);
begin
  LayoutLibrary;
end;

procedure TfrmMain.recLibraryMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
  var Handled: Boolean);
begin
  Handled := True;
end;

procedure TfrmMain.CoverClick(Sender: TObject);
var
  I: Integer;
begin
  I := (Sender as TImage).Tag;
  if (I < 0) or (I > High(FRecent)) then
    Exit;
  // the open book: back to it, where it was
  if (EpubUnum1.Book <> nil) and (FBookFile <> '') and
    SameFileName(ExpandFileName(FRecent[I].FileName), FBookFile) then
  begin
    HideLibrary;
    Exit;
  end;
  // opened from a timer: the click must not free its own image (the book
  // opening ends in HideLibrary)
  FLibraryOpen := I;
  tmLibrary.Enabled := True;
end;

procedure TfrmMain.tmLibraryTimer(Sender: TObject);
begin
  tmLibrary.Enabled := False;
  OpenRecent(FLibraryOpen);
end;

procedure TfrmMain.miLibraryClick(Sender: TObject);
begin
  if LibraryShowing then
    HideLibrary
  else
    ShowLibrary;
end;

procedure TfrmMain.miClearRecentClick(Sender: TObject);
begin
  // the open book stays (it is put back when the reader closes)
  FRecent := nil;
  BuildRecentMenu;
end;

procedure TfrmMain.miExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmMain.BuildFindBar;
var
  B: TButton;
begin
  layFind := TLayout.Create(Self);
  layFind.Parent := Self;
  layFind.Align := TAlignLayout.Top;
  layFind.Position.Y := layTop.Position.Y + layTop.Height + 1;   // under the tool bar
  layFind.Height := 36;
  layFind.Visible := False;
  edFind := TEdit.Create(Self);
  edFind.Parent := layFind;
  edFind.Align := TAlignLayout.Left;
  edFind.Width := 320;
  edFind.Margins.Rect := RectF(8, 5, 4, 5);
  edFind.TextPrompt := 'Find in the book';
  edFind.OnKeyDown := edFindKeyDown;
  B := AddTextButton('<', 'Previous match (Shift+F3, Shift+Enter)', miFindPreviousClick);
  B.Parent := layFind;
  B.Position.X := 100000;
  B := AddTextButton('>', 'Next match (F3, Enter)', miFindNextClick);
  B.Parent := layFind;
  B.Position.X := 100000;
  lblFind := TLabel.Create(Self);
  lblFind.Parent := layFind;
  lblFind.Align := TAlignLayout.Left;
  lblFind.Position.X := 100000;
  lblFind.Width := 180;
  lblFind.Margins.Left := 8;
  B := AddTextButton('X', 'Close (Esc)', btnFindCloseClick);
  B.Parent := layFind;
  B.Align := TAlignLayout.Right;
end;

procedure TfrmMain.miFindClick(Sender: TObject);
begin
  // finding is in the open book: back to its page first
  if LibraryShowing then
  begin
    if EpubUnum1.Book = nil then
      Exit;
    HideLibrary;
  end;
  layFind.Visible := True;
  edFind.SetFocus;
  edFind.SelectAll;
end;

procedure TfrmMain.miFindNextClick(Sender: TObject);
begin
  if Trim(edFind.Text) = '' then
    miFindClick(nil)
  else
    FindStep(1);
end;

procedure TfrmMain.miFindPreviousClick(Sender: TObject);
begin
  if Trim(edFind.Text) = '' then
    miFindClick(nil)
  else
    FindStep(-1);
end;

procedure TfrmMain.btnFindCloseClick(Sender: TObject);
begin
  layFind.Visible := False;
  View1.SetFocus;
end;

procedure TfrmMain.edFindKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if Key = vkReturn then
  begin
    if ssShift in Shift then
      FindStep(-1)
    else
      FindStep(1);
    Key := 0;
  end
  else if Key = vkEscape then
  begin
    btnFindCloseClick(nil);
    Key := 0;
  end;
end;

{ AText lower case, without the punctuation around it (EpubWordCore). }
function FindKey(const AText: string): string;
var
  F, L: Integer;
begin
  F := 1;
  L := Length(AText);
  EpubWordCore(AText, F, L);
  Result := LowerCase(Copy(AText, F, L - F + 1));
end;

procedure TfrmMain.FindAll(const AQuery: string);
var
  B: TEpubBook;
  Parts: TArray<string>;
  Keys: TArray<string>;
  I, J, N: Integer;
  Ok: Boolean;
  W: string;
begin
  FFindQuery := AQuery;
  FFindHits := nil;
  FFindIndex := -1;
  B := EpubUnum1.Book;
  Parts := Trim(AQuery).Split([' '], TStringSplitOptions.ExcludeEmpty);
  Keys := nil;
  for I := 0 to High(Parts) do
    if FindKey(Parts[I]) <> '' then
      Keys := Keys + [FindKey(Parts[I])];
  FFindLength := Length(Keys);
  if (B = nil) or (FFindLength = 0) then
    Exit;
  N := B.WordCount;
  for I := 0 to N - FFindLength do
  begin
    if B.Words[I].Role = ewrNav then
      Continue;   // the contents page
    Ok := True;
    for J := 0 to FFindLength - 1 do
    begin
      W := FindKey(B.Words[I + J].Text);
      // the last word may be the start of one ('Vim' finds 'Vimes')
      if (J < FFindLength - 1) and (W <> Keys[J]) or
        (J = FFindLength - 1) and not W.StartsWith(Keys[J]) then
      begin
        Ok := False;
        Break;
      end;
    end;
    if Ok then
      FFindHits := FFindHits + [I];
  end;
end;

procedure TfrmMain.FindStep(ADirection: Integer);
var
  B: TEpubBook;
  From, I, W, C: Integer;
begin
  B := EpubUnum1.Book;
  if B = nil then
    Exit;
  layFind.Visible := True;
  if edFind.Text <> FFindQuery then
    FindAll(edFind.Text);
  if Length(FFindHits) = 0 then
  begin
    lblFind.Text := 'Not found';
    Exit;
  end;
  // from the match shown, else from the place being read
  if FFindIndex >= 0 then
    FFindIndex := (FFindIndex + ADirection + Length(FFindHits)) mod Length(FFindHits)
  else
  begin
    From := Max(ReadingWord, 0);
    FFindIndex := -1;
    if ADirection > 0 then
    begin
      for I := 0 to High(FFindHits) do
        if FFindHits[I] > From then
        begin
          FFindIndex := I;
          Break;
        end;
      if FFindIndex < 0 then
        FFindIndex := 0;   // round to the start
    end
    else
    begin
      for I := High(FFindHits) downto 0 do
        if FFindHits[I] < From then
        begin
          FFindIndex := I;
          Break;
        end;
      if FFindIndex < 0 then
        FFindIndex := High(FFindHits);
    end;
  end;
  lblFind.Text := Format('%d of %d', [FFindIndex + 1, Length(FFindHits)]);
  // show it lit; Play starts there
  W := FFindHits[FFindIndex];
  StopPlaying;
  FLearnFirst := -1;
  if B.Words[W].Document <> View1.Document then
    View1.ShowDocument(B.Words[W].Document);
  View1.Highlight(W, W + FFindLength - 1);
  View1.ScrollToWord(W, True);
  SyncToc(W);
  C := ClipOfWord(W);
  if C < 0 then
    C := ClipFromWord(W);
  if C >= 0 then
  begin
    FClip := C;
    FSeekClip := C;
  end;
  UpdateControls;
end;

function TfrmMain.ReadingWord: Integer;
begin
  if FLearn and (FLearnFirst >= 0) then
    Result := FLearnFirst
  else
    Result := CurrentWord;
end;

function TfrmMain.RecentIndex(const AFileName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FRecent) do
    if SameFileName(ExtractFileName(FRecent[I].FileName), ExtractFileName(AFileName)) then
      Exit(I);
  Result := -1;
end;

procedure TfrmMain.RememberBook;
var
  R: TRecentBook;
  I: Integer;
begin
  if (FBookFile = '') or (EpubUnum1.Book = nil) then
    Exit;
  R.FileName := FBookFile;
  R.Title := EpubUnum1.Book.Title;
  R.Word := ReadingWord;
  I := RecentIndex(FBookFile);
  if I >= 0 then
    Delete(FRecent, I, 1);
  Insert(R, FRecent, 0);
  if Length(FRecent) > RECENT_MAX then
    SetLength(FRecent, RECENT_MAX);
  BuildRecentMenu;
end;

function TfrmMain.LayoutBlocks: Integer;
begin
  if View1.Layout <> nil then
    Result := View1.Layout.BlockCount
  else
    Result := 0;
end;

procedure TfrmMain.RestoreWord(AWord: Integer);
var
  B: TEpubBook;
  C: Integer;
begin
  B := EpubUnum1.Book;
  if (B = nil) or (AWord < 0) or (AWord >= B.WordCount) then
    Exit;
  C := ClipOfWord(AWord);
  if C < 0 then
    C := ClipFromWord(AWord);
  if (C >= 0) and (B.Clips[C].Document = B.Words[AWord].Document) then
    GoClip(C)   // highlighted, and Play starts there
  else
  begin
    DebugLog(Format('restore word %d (document %d): laying out', [AWord, B.Words[AWord].Document]));
    View1.ShowDocument(B.Words[AWord].Document);
    View1.ScrollToWord(AWord, True);
    DebugLog(Format('restore word %d: shown (%d blocks)', [AWord, LayoutBlocks]));
    SyncToc(AWord);
    UpdateControls;
  end;
end;

procedure TfrmMain.LoadSettings;
var
  V: TJSONValue;
  O, E: TJSONObject;
  A: TJSONArray;
  I: Integer;
  Size, Speed: Double;
  R: TRecentBook;
  Folder: string;
begin
  FBooksFolder := BooksFolderDefault;
  if not FileExists(SettingsFile) then
    Exit;
  try
    V := TJSONObject.ParseJSONValue(TFile.ReadAllText(SettingsFile, TEncoding.UTF8));
    try
      if not (V is TJSONObject) then
        Exit;
      O := TJSONObject(V);
      O.TryGetValue<Boolean>('dark', FDark);
      O.TryGetValue<Boolean>('debug', FDebug);
      // another books folder, put in the settings by hand (not written)
      if O.TryGetValue<string>('booksFolder', Folder) and (Folder <> '') then
        FBooksFolder := Folder;
      if O.TryGetValue<Double>('textSize', Size) and (Size >= 10) and (Size <= 60) then
        View1.FontSize := Size;
      if O.TryGetValue<Double>('speed', Speed) then
        tbSpeed.Value := EnsureRange(Speed, SPEED_MIN, SPEED_MAX);
      FRecent := nil;
      if O.TryGetValue<TJSONArray>('recent', A) then
        for I := 0 to A.Count - 1 do
          if (A.Items[I] is TJSONObject) and (Length(FRecent) < RECENT_MAX) then
          begin
            E := TJSONObject(A.Items[I]);
            R.FileName := '';
            R.Title := '';
            R.Word := -1;
            E.TryGetValue<string>('file', R.FileName);
            E.TryGetValue<string>('title', R.Title);
            E.TryGetValue<Integer>('word', R.Word);
            if R.FileName <> '' then
              FRecent := FRecent + [R];
          end;
    finally
      V.Free;
    end;
  except
    // unreadable settings: the defaults
  end;
  ApplyTheme;
  miDark.IsChecked := FDark;
  miNotes.Visible := FDebug;
  BuildRecentMenu;   // recreates the OS menu
end;

procedure TfrmMain.SaveSettings;
var
  O, E: TJSONObject;
  A: TJSONArray;
  I: Integer;
begin
  O := TJSONObject.Create;
  try
    O.AddPair('dark', TJSONBool.Create(FDark));
    // written every time, so it can be found and set by hand
    O.AddPair('debug', TJSONBool.Create(FDebug));
    O.AddPair('textSize', TJSONNumber.Create(View1.FontSize));
    O.AddPair('speed', TJSONNumber.Create(FPendingSpeed));
    A := TJSONArray.Create;
    O.AddPair('recent', A);
    for I := 0 to High(FRecent) do
    begin
      E := TJSONObject.Create;
      E.AddPair('file', FRecent[I].FileName);
      E.AddPair('title', FRecent[I].Title);
      E.AddPair('word', TJSONNumber.Create(FRecent[I].Word));
      A.AddElement(E);
    end;
    try
      ForceDirectories(ExtractFilePath(SettingsFile));
      TFile.WriteAllText(SettingsFile, O.Format(2), TEncoding.UTF8);
    except
      // not saved: the next start has the defaults
    end;
  finally
    O.Free;
  end;
end;

procedure TfrmMain.AppException(Sender: TObject; E: Exception);
begin
  DebugLogException(E, ExceptAddr);
  Application.ShowException(E);
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  if FScreenLogged then
    Exit;
  FScreenLogged := True;
  // once the window is on its display (big-screen work, 2026-11-17: the
  // numbers from every machine first)
  TThread.ForceQueue(nil,
    procedure
    begin
      DebugLog(SteamScreenText(Self));
    end);
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  Line: string;
  OK: Boolean;
begin
  // the debug log: next to the settings, started afresh at every run
  DebugLogOpen(ChangeFileExt(SettingsFile, '-debug.log'));
  // a crash in a library (Steam Deck, 2026-11-17): logged with where it was
  Application.OnException := AppException;
  OnShow := FormShow;
  // Steam's Exit Game ends the program with SIGTERM: the place is saved
  // first (owner)
  if QuitSignalInstall(QuitSignalled) then
    DebugLog('SIGTERM / SIGINT / SIGHUP: the place is saved before the program ends');
  Line := QuitSignalLast(ChangeFileExt(SettingsFile, '-ended.txt'));
  if Line <> '' then
    DebugLog(Line);
  // Steam (started in the .dpr, before the log was open)
  DebugLog(SteamText);
  for Line in SteamNotes do
    DebugLog(Line);
  FFindIndex := -1;
  FLearnFirst := -1;
  FLearnLast := -1;
  FClip := -1;
  FSeekClip := -1;
  FUnitDoc := -1;
  lbToc.OnApplyStyleLookup := TocApplyStyle;
  // how far through the book, under the text
  View1.ShowProgress := True;
  // EPUBREADER_FONT=<family>: the text in that font family instead of
  // Skia's default (testing font lookup speed on Linux, 2026-11-16)
  if GetEnvironmentVariable('EPUBREADER_FONT') <> '' then
  begin
    View1.FontFamily := GetEnvironmentVariable('EPUBREADER_FONT');
    DebugLog('font: ' + View1.FontFamily + ' (EPUBREADER_FONT)');
  end;
  BuildToolBar;
  BuildFindBar;
  BuildMenu;
  BuildLibrary;
  StartSound;
  DebugLog('FMX canvas in use: ' + FmxCanvasClassName);
  // Linux only: fontconfig's (macOS and Windows find their fonts without it)
  {$IFDEF LINUX}
  LogFontProbe;
  {$ENDIF}
  // a new name every run (Random without Randomize gave the same one, so
  // two readers shared - and deleted - one folder)
  FAudioFolder := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetTempPath,
    'EpubReader-' + System.IOUtils.TPath.GetGUIDFileName);
  // which canvas FMX really draws the form with (GDI+, Direct2D, Skia ...)
  // and what the Wine / Proton units decided - stderr, as TSteamAPI's demos
  {$IFDEF POSIX}
  WriteLn(ErrOutput, 'FMX canvas in use: ', FmxCanvasClassName);
  {$ENDIF}
  if FmxWineCanvasNote <> '' then
    Caption := Caption + ' [' + FmxWineCanvasName + ']';
  // in the system's "Open with" list (this user; nothing when already so)
  try
    FOpenWithNote := RegisterOpenWith;
  except
    // the reader works without it
    FOpenWithNote := '';
  end;
  // dark mode, text size, speed, the recent books and their positions
  LoadSettings;
  // the books folder there from the start (Open a book lists it); where
  // it cannot be made (a program folder the user cannot write to), the
  // one in Documents
  OK := False;
  try
    OK := ForceDirectories(FBooksFolder);
  except
    on E: Exception do
      DebugLog('books folder: ' + E.Message);
  end;
  if not OK then
  begin
    DebugLog('books folder: ' + FBooksFolder + ' could not be made - the one in Documents instead');
    FBooksFolder := System.IOUtils.TPath.Combine(System.IOUtils.TPath.Combine(
      System.IOUtils.TPath.GetDocumentsPath, 'EpubReader'), 'Books');
    try
      ForceDirectories(FBooksFolder);
    except
      // listed as empty
    end;
  end;
  DebugLog('books folder: ' + FBooksFolder);
  // a Steam Deck: text at least SIZE_MIN_DECK (a smaller size kept from
  // before is raised; the pad's menu can make it larger)
  if SteamOnDeck and (View1.FontSize < SIZE_MIN_DECK) then
  begin
    DebugLog(Format('Steam Deck: text size %d raised to %d (Steam''s least there)', [Round(View1.FontSize),
      SIZE_MIN_DECK]));
    View1.FontSize := SIZE_MIN_DECK;
  end;
  StartPad;
  // Big Picture: the pad and its menu do it all - no tool bar, no
  // contents panel (owner, 2026-11-18; the menu bar is left off already)
  if SteamBigPicture then
  begin
    layTop.Visible := False;
    lbToc.Visible := False;
    Splitter1.Visible := False;
    DebugLog('Big Picture: no tool bar or contents panel - the pad''s menu (Start, or Esc) has them');
  end;
  UpdateControls;
  DebugLog('window ready');
  // a book named on the command line (Open with), else the library: the
  // recent books' covers, the last one read large
  if ParamCount > 0 then
    OpenBook(ParamStr(1))
  else
    ShowLibrary;
end;

procedure TfrmMain.QuitSignalled(ASignal: Integer);
begin
  // the next start says so too (the debug log starts afresh)
  if FPlaying then
    QuitSignalRecord(ChangeFileExt(SettingsFile, '-ended.txt'), ASignal, 'reading aloud')
  else
    QuitSignalRecord(ChangeFileExt(SettingsFile, '-ended.txt'), ASignal, '');
  DebugLog(Format('asked to end (%s - Steam''s Exit Game, or the system shutting down)',
    [QuitSignalName(ASignal)]));
  Close;
end;

procedure TfrmMain.StartPad;
var
  I: Integer;
  Folder, Manifest: string;
begin
  FCoverSel := -1;
  FPadMenu := TPadMenu.Create(Self, Self);
  FPadMenu.OnChoose := PadMenuChoose;
  FPadMenu.OnClose := PadMenuClose;
  if SteamBigPicture then
    FPadMenu.FontSize := 30
  else
    FPadMenu.FontSize := 20;
  FPad := TSteamPad.Create('Reader', PAD_ACTIONS, 'Scroll');
  // directions repeat while held (scrolling, lists)
  for I := PAD_UP to PAD_RIGHT do
    FPad.SetRepeat(I, True);
  if not SteamRunning then
  begin
    DebugLog(FPad.Start(''));
    Exit;
  end;
  // the manifest and its layouts written by the program (afresh when it
  // brings other ones), so nothing has to be deployed: into steaminput/
  // beside the program - where the partner site's "Custom Configuration
  // (Bundled with Game)" can name it - else beside the settings (a
  // folder the user cannot write to; the Mac's signed bundle always)
  Manifest := '';
  {$IFNDEF MACOS}
  Folder := ExtractFilePath(ParamStr(0)) + 'steaminput';
  try
    Manifest := ReaderInputWrite(Folder);
  except
    on E: Exception do
      DebugLog('pad: ' + Folder + ' not writable (' + E.Message + '): the settings'' folder instead');
  end;
  {$ENDIF}
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
    DebugLog(FPad.Start(Manifest) + Format(' (layout revision %d)', [READER_INPUT_REVISION]));
  if not FPad.Started then
    Exit;
  tmPad := TTimer.Create(Self);
  tmPad.Interval := 16;
  tmPad.OnTimer := tmPadTimer;
  FPadTick := TThread.GetTickCount64;
  tmPad.Enabled := True;
end;

procedure TfrmMain.tmPadTimer(Sender: TObject);
var
  Presses: TSteamPadPresses;
  Y: Single;
  I: Integer;
  Now_: UInt64;
  Note: string;
begin
  Now_ := TThread.GetTickCount64;
  try
    FPad.Poll(Presses, Y);
    Note := FPad.TakeNote;
    if Note <> '' then
      DebugLog(Note);
    for I := 0 to High(Presses) do
      if Presses[I] then
        PadPress(I);
    // the right stick scrolls the page (up is positive)
    if (Abs(Y) > PAD_STICK_DEAD) and not FPadMenu.Showing and not LibraryShowing and
      (EpubUnum1.Book <> nil) then
      View1.ScrollPos := View1.ScrollPos - Y * PAD_SCROLL_SPEED * (Now_ - FPadTick) / 1000;
  except
    on E: Exception do
      DebugLog('pad: ' + E.ClassName + ': ' + E.Message);
  end;
  FPadTick := Now_;
end;

procedure TfrmMain.PadPress(AButton: Integer);
begin
  if not (AButton in [PAD_UP, PAD_DOWN, PAD_LEFT, PAD_RIGHT]) then
    DebugLog('pad: ' + PAD_ACTIONS[AButton]);
  // the menu first: it is over everything
  if FPadMenu.Showing then
  begin
    case AButton of
      PAD_UP: FPadMenu.Move(-1);
      PAD_DOWN: FPadMenu.Move(1);
      PAD_LEFT: PadMenuStep(-1);
      PAD_RIGHT: PadMenuStep(1);
      PAD_PLAY: PadMenuChoose(FPadMenu, FPadMenu.Selected);
      PAD_BACK, PAD_MENU:
        // the contents or the controls: back to the menu, on their row;
        // the menu: closed
        if FMenuMode = MODE_CONTENTS then
        begin
          ShowPadMenu;
          FPadMenu.Move(MENU_CONTENTS);
        end
        else if FMenuMode = MODE_CONTROLS then
        begin
          ShowPadMenu;
          FPadMenu.Move(MENU_CONTROLS);
        end
        else if FMenuMode = MODE_BOOKS then
        begin
          ShowPadMenu;
          FPadMenu.Move(MENU_OPEN);
        end
        else
          FPadMenu.Hide;
      PAD_LIBRARY:
        begin
          FPadMenu.Hide;
          miLibraryClick(nil);
        end;
    end;
    Exit;
  end;
  if LibraryShowing then
  begin
    case AButton of
      PAD_UP: MoveCover(0, -1);
      PAD_DOWN: MoveCover(0, 1);
      PAD_LEFT: MoveCover(-1, 0);
      PAD_RIGHT: MoveCover(1, 0);
      PAD_PLAY:
        if (FCoverSel >= 0) and (FCoverSel <= High(FCoverImages)) then
          CoverClick(FCoverImages[FCoverSel])
        else
          MoveCover(0, 0);
      PAD_BACK, PAD_LIBRARY:
        if EpubUnum1.Book <> nil then
          HideLibrary;
      PAD_MENU: ShowPadMenu;
    end;
    Exit;
  end;
  case AButton of
    PAD_UP: View1.ScrollPos := View1.ScrollPos - 3 * View1.FontSize;
    PAD_DOWN: View1.ScrollPos := View1.ScrollPos + 3 * View1.FontSize;
    PAD_LEFT: View1.Page(False);
    PAD_RIGHT: View1.Page(True);
    PAD_PLAY: btnPlayClick(nil);
    PAD_AGAIN:
      if FLearn then
      begin
        // as the R key
        if FLearnFirst >= 0 then
          SayWords(FLearnFirst, FLearnLast)
        else
          LearnStep(1);
      end;
    PAD_DARK: btnDarkClick(nil);
    PAD_SENTENCE_PREV:
      if btnPrevClip.Enabled then
        btnPrevClipClick(nil);
    PAD_SENTENCE_NEXT:
      if btnNextClip.Enabled then
        btnNextClipClick(nil);
    PAD_CHAPTER_PREV:
      if btnPrev.Enabled then
        btnPrevClick(nil);
    PAD_CHAPTER_NEXT:
      if btnNext.Enabled then
        btnNextClick(nil);
    PAD_MENU: ShowPadMenu;
    PAD_LIBRARY: miLibraryClick(nil);
  end;
end;

function TfrmMain.PadMenuValue(AIndex: Integer): string;
const
  ON_OFF: array[Boolean] of string = ('Off', 'On');
begin
  case AIndex of
    MENU_SIZE: Result := Format('%s  %d  %s', [#$2039, Round(View1.FontSize), #$203A]);
    MENU_SPEED: Result := Format('%s  %s  %s', [#$2039, lblSpeed.Text, #$203A]);
    MENU_DARK: Result := ON_OFF[FDark];
    MENU_LEARN: Result := ON_OFF[FLearn];
  else
    Result := '';
  end;
end;

function TfrmMain.PadMenuFoot(AChange: Boolean): string;
var
  Choose, Back: string;
begin
  // the pad's own names (Steam's language), else the keys
  Choose := FPad.Origin(PAD_PLAY, FDark).Name;
  Back := FPad.Origin(PAD_BACK, FDark).Name;
  if (Choose = '') or (Back = '') then
  begin
    Choose := 'Enter';
    Back := 'Esc';
  end;
  Result := Choose + ' choose      ' + Back + ' back';
  if AChange then
    Result := Result + '      Left / Right change';
end;

procedure TfrmMain.PadMenuColors;
begin
  // the page's colours; the selected row a soft blue that suits each
  if FDark then
    FPadMenu.SetColors($FF23262E, View1.TextColor, $FF34405A)
  else
    FPadMenu.SetColors($FFFBFAF7, View1.TextColor, $FFD9E5F6);
end;

procedure TfrmMain.ShowPadMenu;
const
  TEXTS: array[MENU_RESUME..MENU_EXIT] of string = ('Back to the book', 'Open a book', 'Library', 'Contents',
    'Text size',
    'Speed', 'Dark mode', 'Learn to read', 'Controls', 'Exit');
var
  Items: TArray<TPadMenuItem>;
  I: Integer;
begin
  FMenuMode := MODE_MAIN;
  SetLength(Items, MENU_EXIT + 1);
  for I := 0 to MENU_EXIT do
    Items[I] := TPadMenu.Item(TEXTS[I], PadMenuValue(I));
  PadMenuColors;
  FPadMenu.Show('EpubReader', Items, MENU_RESUME, PadMenuFoot(True));
end;

procedure TfrmMain.ShowContentsMenu;
var
  Items: TArray<TPadMenuItem>;
  I: Integer;
begin
  if lbToc.Count = 0 then
    Exit;
  FMenuMode := MODE_CONTENTS;
  SetLength(Items, lbToc.Count);
  for I := 0 to lbToc.Count - 1 do
    Items[I] := TPadMenu.Item(lbToc.Items[I]);
  PadMenuColors;
  FPadMenu.Show('Contents', Items, lbToc.ItemIndex, PadMenuFoot(False));
end;

procedure TfrmMain.ShowControlsMenu;
type
  { A row: what it does, the pad's buttons for it (-1 = the stick), and
    the names shown when Steam has none (no pad, not a Steam build). }
  TControlRow = record
    Text: string;
    A, B: Integer;
    Fallback: string;
  end;
const
  NO_BUTTON = -2;
  THE_STICK = -1;
  ROWS: array[0..10] of TControlRow = (
    (Text: 'Play / pause; choose'; A: PAD_PLAY; B: NO_BUTTON; Fallback: 'A  /  P, Enter'),
    (Text: 'Back; close the menu or the library'; A: PAD_BACK; B: NO_BUTTON; Fallback: 'B  /  Esc'),
    (Text: 'Say it again (Learn to read)'; A: PAD_AGAIN; B: NO_BUTTON; Fallback: 'X  /  R'),
    (Text: 'Dark mode'; A: PAD_DARK; B: NO_BUTTON; Fallback: 'Y  /  D'),
    (Text: 'Scroll a little'; A: PAD_UP; B: PAD_DOWN; Fallback: 'D-pad up / down'),
    (Text: 'Page back / on'; A: PAD_LEFT; B: PAD_RIGHT; Fallback: 'D-pad left / right'),
    (Text: 'Scroll'; A: THE_STICK; B: NO_BUTTON; Fallback: 'Right stick'),
    (Text: 'Sentence back / on'; A: PAD_SENTENCE_PREV; B: PAD_SENTENCE_NEXT; Fallback: 'LB / RB'),
    (Text: 'Chapter back / on'; A: PAD_CHAPTER_PREV; B: PAD_CHAPTER_NEXT; Fallback: 'LT / RT'),
    (Text: 'This menu'; A: PAD_MENU; B: NO_BUTTON; Fallback: 'Start  /  Esc'),
    (Text: 'Library'; A: PAD_LIBRARY; B: NO_BUTTON; Fallback: 'Select'));

  { Action AIndex (or the stick) on the pad in hand. }
  function Origin(AIndex: Integer): TSteamPadOrigin;
  begin
    if AIndex = THE_STICK then
      Result := FPad.Origin(FPad.Count, FDark)
    else
      Result := FPad.Origin(AIndex, FDark);
  end;

var
  Items: TArray<TPadMenuItem>;
  I: Integer;
  O1, O2: TSteamPadOrigin;
  Names, Title: string;
begin
  FMenuMode := MODE_CONTROLS;
  SetLength(Items, Length(ROWS));
  for I := 0 to High(ROWS) do
  begin
    Items[I] := TPadMenu.Item(ROWS[I].Text);
    O1 := Origin(ROWS[I].A);
    O2.Name := '';
    O2.Glyph := '';
    if ROWS[I].B <> NO_BUTTON then
      O2 := Origin(ROWS[I].B);
    // Steam's pictures; the names on the right when there are none
    if O1.Glyph <> '' then
      Items[I].Glyphs := Items[I].Glyphs + [O1.Glyph];
    if O2.Glyph <> '' then
      Items[I].Glyphs := Items[I].Glyphs + [O2.Glyph];
    Names := O1.Name;
    if O2.Name <> '' then
      Names := Names + ' / ' + O2.Name;
    if Length(Items[I].Glyphs) = 0 then
    begin
      if Names <> '' then
        Items[I].Value := Names
      else
        Items[I].Value := ROWS[I].Fallback;
    end;
  end;
  Title := 'Controls';
  if FPad.PadName <> '' then
    Title := 'Controls - ' + FPad.PadName;
  PadMenuColors;
  FPadMenu.Show(Title, Items, 0, PadMenuFoot(False));
end;

procedure TfrmMain.ShowBooksMenu;
var
  Items: TArray<TPadMenuItem>;
  Files: TArray<string>;
  I, Sel: Integer;
  Rel: string;
begin
  FMenuMode := MODE_BOOKS;
  FBookFiles := nil;
  try
    if TDirectory.Exists(FBooksFolder) then
      Files := TDirectory.GetFiles(FBooksFolder, '*.epub', TSearchOption.soAllDirectories);
  except
    on E: Exception do
      DebugLog('books folder: ' + E.Message);
  end;
  // by name, as a person reads them (sub-folders' books by their path)
  TArray.Sort<string>(Files, TComparer<string>.Construct(
    function(const A, B: string): Integer
    begin
      Result := CompareText(A, B);
    end));
  FBookFiles := Files;
  Sel := 0;
  SetLength(Items, Length(FBookFiles));
  for I := 0 to High(FBookFiles) do
  begin
    Rel := ExtractRelativePath(IncludeTrailingPathDelimiter(FBooksFolder), FBookFiles[I]);
    Items[I] := TPadMenu.Item(ChangeFileExt(Rel, ''));
    if (FBookFile <> '') and SameFileName(ExpandFileName(FBookFiles[I]), FBookFile) then
    begin
      Items[I].Value := 'open';
      Sel := I;
    end;
  end;
  if Length(Items) = 0 then
    Items := [TPadMenu.Item('No books there yet - copy EPUB files into the folder below')];
  DebugLog(Format('books folder: %d book(s) in %s', [Length(FBookFiles), FBooksFolder]));
  PadMenuColors;
  // the foot says where the books are: where to copy more
  FPadMenu.Show('Open a book', Items, Sel, FBooksFolder);
end;

procedure TfrmMain.PadMenuChoose(Sender: TObject; AIndex: Integer);
begin
  if AIndex < 0 then
    Exit;
  if FMenuMode = MODE_CONTROLS then
  begin
    // nothing to choose: back to the menu
    ShowPadMenu;
    FPadMenu.Move(MENU_CONTROLS);
    Exit;
  end;
  if FMenuMode = MODE_BOOKS then
  begin
    if AIndex > High(FBookFiles) then
    begin
      // "no books there": back to the menu
      ShowPadMenu;
      FPadMenu.Move(MENU_OPEN);
      Exit;
    end;
    FPadMenu.Hide;
    // later, not inside the pad's timer (opening takes a while)
    TThread.ForceQueue(nil,
      procedure
      begin
        OpenBook(FBookFiles[AIndex]);
      end);
    Exit;
  end;
  if FMenuMode = MODE_CONTENTS then
  begin
    FPadMenu.Hide;
    if AIndex >= lbToc.Count then
      Exit;
    // the panel's own change does the going there
    if lbToc.ItemIndex = AIndex then
      lbTocChange(nil)
    else
      lbToc.ItemIndex := AIndex;
    Exit;
  end;
  case AIndex of
    MENU_RESUME:
      begin
        FPadMenu.Hide;
        if LibraryShowing and (EpubUnum1.Book <> nil) then
          HideLibrary;
      end;
    MENU_OPEN: ShowBooksMenu;
    MENU_LIBRARY:
      begin
        FPadMenu.Hide;
        if not LibraryShowing then
          ShowLibrary;
      end;
    MENU_CONTENTS:
      if (EpubUnum1.Book <> nil) and not LibraryShowing then
        ShowContentsMenu;
    MENU_SIZE, MENU_SPEED:
      // a value: left / right change it; choosing it closes the menu
      FPadMenu.Hide;
    MENU_DARK:
      begin
        btnDarkClick(nil);
        // the box in the new colours
        ShowPadMenu;
        FPadMenu.Move(MENU_DARK);
      end;
    MENU_LEARN:
      if EpubUnum1.Book <> nil then
      begin
        btnLearnClick(nil);
        FPadMenu.SetValue(MENU_LEARN, PadMenuValue(MENU_LEARN));
      end;
    MENU_CONTROLS: ShowControlsMenu;
    MENU_EXIT:
      begin
        FPadMenu.Hide;
        // later, not inside the pad's timer (FormClose frees the pad)
        TThread.ForceQueue(nil,
          procedure
          begin
            Close;
          end);
      end;
  end;
end;

procedure TfrmMain.PadMenuClose(Sender: TObject);
begin
  FPadMenu.Hide;
end;

procedure TfrmMain.PadMenuStep(ADelta: Integer);
begin
  if FMenuMode <> MODE_MAIN then
    Exit;
  case FPadMenu.Selected of
    MENU_SIZE:
      if ADelta < 0 then
        btnSmallerClick(nil)
      else
        btnLargerClick(nil);
    MENU_SPEED:
      tbSpeed.Value := tbSpeed.Value + ADelta * SPEED_STEP;
  else
    Exit;
  end;
  FPadMenu.SetValue(FPadMenu.Selected, PadMenuValue(FPadMenu.Selected));
end;

procedure TfrmMain.MoveCover(ADX, ADY: Integer);
var
  I, Best: Integer;
  C, D: TPointF;
  Along, Across, Score, BestScore: Single;
begin
  if Length(FCoverImages) = 0 then
    Exit;
  // the first press: the open book's cover (the first, large one)
  if (FCoverSel < 0) or (FCoverSel > High(FCoverImages)) or ((ADX = 0) and (ADY = 0)) then
  begin
    if (FCoverSel < 0) or (FCoverSel > High(FCoverImages)) then
      FCoverSel := 0;
    ShowCoverSelection;
    Exit;
  end;
  C := FCoverImages[FCoverSel].BoundsRect.CenterPoint;
  Best := -1;
  BestScore := 0;
  for I := 0 to High(FCoverImages) do
  begin
    if I = FCoverSel then
      Continue;
    D := FCoverImages[I].BoundsRect.CenterPoint - C;
    // how far that way, and how far off it
    Along := D.X * ADX + D.Y * ADY;
    Across := Abs(D.X * ADY) + Abs(D.Y * ADX);
    if Along <= 1 then
      Continue;
    Score := Along + 2 * Across;
    if (Best < 0) or (Score < BestScore) then
    begin
      Best := I;
      BestScore := Score;
    end;
  end;
  if Best >= 0 then
    FCoverSel := Best;
  ShowCoverSelection;
end;

procedure TfrmMain.ShowCoverSelection;
var
  R: TRectF;
begin
  if recCoverSel = nil then
  begin
    recCoverSel := TRectangle.Create(Self);
    recCoverSel.Parent := recLibrary;
    recCoverSel.Fill.Kind := TBrushKind.None;
    recCoverSel.Stroke.Thickness := 6;
    recCoverSel.HitTest := False;
  end;
  if not LibraryShowing or (FCoverSel < 0) or (FCoverSel > High(FCoverImages)) then
  begin
    recCoverSel.Visible := False;
    Exit;
  end;
  R := FCoverImages[FCoverSel].BoundsRect;
  R.Inflate(4, 4);
  recCoverSel.Stroke.Color := View1.TextColor;
  recCoverSel.BoundsRect := R;
  recCoverSel.Visible := True;
  recCoverSel.BringToFront;
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  // each step logged: the Mac reader hung here once (2026-11-18), the
  // log ending after StopPlaying
  DebugLog('closing');
  if tmPad <> nil then
    tmPad.Enabled := False;
  FreeAndNil(FPad);
  StopPlaying;
  // where the reader left off, and the settings
  RememberBook;
  SaveSettings;
  DebugLog('closing: place and settings saved');
  FreeAndNil(FUnitLayout);
  FreeAndNil(FPlayer);
  DebugLog('closing: sound player freed');
  FreeAndNil(FFFmpeg);
  try
    if TDirectory.Exists(FAudioFolder) then
      TDirectory.Delete(FAudioFolder, True);
  except
    // a file still held by the player: left for the system's temp cleanup
  end;
  DebugLog('closing: done (the program ends next)');
end;

procedure TfrmMain.FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  // Ctrl+F, F3 / Shift+F3 work anywhere
  if (ssCtrl in Shift) and ((KeyChar = 'f') or (KeyChar = 'F') or (Key = Ord('F'))) then
  begin
    miFindClick(nil);
    Key := 0;
    KeyChar := #0;
    Exit;
  end;
  if Key = vkF3 then
  begin
    if ssShift in Shift then
      miFindPreviousClick(nil)
    else
      miFindNextClick(nil);
    Key := 0;
    Exit;
  end;
  // typing in the find box is text, not the reader's keys (P, D, L, R ...)
  if (edFind <> nil) and edFind.IsFocused then
    Exit;
  // the pad's menu with the keyboard too: arrows, Enter, Esc
  if (FPadMenu <> nil) and FPadMenu.Showing then
  begin
    case Key of
      vkUp: PadPress(PAD_UP);
      vkDown: PadPress(PAD_DOWN);
      vkLeft: PadPress(PAD_LEFT);
      vkRight: PadPress(PAD_RIGHT);
      vkReturn: PadPress(PAD_PLAY);
      vkEscape: PadPress(PAD_BACK);
    end;
    Key := 0;
    KeyChar := #0;
    Exit;
  end;
  // Esc on the page: the pad's menu (in Big Picture the menu bar is not
  // there - this is the way to Library, Contents and Exit)
  if (Key = vkEscape) and not LibraryShowing and (FPadMenu <> nil) then
  begin
    ShowPadMenu;
    Key := 0;
    Exit;
  end;
  // Esc in the library: back to the open book
  if (Key = vkEscape) and LibraryShowing and (EpubUnum1.Book <> nil) then
  begin
    HideLibrary;
    Key := 0;
    Exit;
  end;
  // the library: the reader's keys (P, D, L, [ ] ...) wait for the page;
  // Ctrl+O still opens a book
  if LibraryShowing and not ((ssCtrl in Shift) and ((KeyChar = 'o') or (KeyChar = 'O') or (Key = Ord('O')))) then
    Exit;
  if (KeyChar = 'p') or (KeyChar = 'P') then
  begin
    btnPlayClick(nil);
    KeyChar := #0;
  end
  else if (ssCtrl in Shift) and ((KeyChar = 'o') or (KeyChar = 'O') or (Key = Ord('O'))) then
  begin
    btnOpenClick(nil);
    Key := 0;
    KeyChar := #0;
  end
  else if (ssCtrl in Shift) and ((KeyChar = '+') or (KeyChar = '=')) then
  begin
    btnLargerClick(nil);
    KeyChar := #0;
  end
  else if (ssCtrl in Shift) and (KeyChar = '-') then
  begin
    btnSmallerClick(nil);
    KeyChar := #0;
  end
  else if ((KeyChar = 'd') or (KeyChar = 'D')) and not (ssCtrl in Shift) then
  begin
    btnDarkClick(nil);
    KeyChar := #0;
  end
  else if ((KeyChar = 'l') or (KeyChar = 'L')) and not (ssCtrl in Shift) then
  begin
    btnLearnClick(nil);
    KeyChar := #0;
  end
  else if ((KeyChar = 'r') or (KeyChar = 'R')) and not (ssCtrl in Shift) and FLearn then
  begin
    // say the unit again
    if FLearnFirst >= 0 then
      SayWords(FLearnFirst, FLearnLast)
    else
      LearnStep(1);
    KeyChar := #0;
  end
  else if KeyChar = '[' then
  begin
    tbSpeed.Value := tbSpeed.Value - SPEED_STEP;
    KeyChar := #0;
  end
  else if KeyChar = ']' then
  begin
    tbSpeed.Value := tbSpeed.Value + SPEED_STEP;
    KeyChar := #0;
  end;
end;

procedure TfrmMain.tbSpeedChange(Sender: TObject);
var
  V: Double;
begin
  // to the slider's steps (a drag gives any value)
  V := EnsureRange(Round(tbSpeed.Value / SPEED_STEP) * SPEED_STEP, SPEED_MIN, SPEED_MAX);
  lblSpeed.Text := FormatFloat('0.0', V) + 'x';
  // the label follows at once; the player when the slider rests
  FPendingSpeed := V;
  tmSpeed.Enabled := False;
  tmSpeed.Enabled := True;
end;

procedure TfrmMain.tmSpeedTimer(Sender: TObject);
begin
  tmSpeed.Enabled := False;
  if FPlayer = nil then
    Exit;
  try
    FPlayer.Speed := FPendingSpeed;
  except
    on E: Exception do
    begin
      // no avfilter (avfilter-11 / swscale-9 missing): 1x only
      FSoundNote := E.Message;
      tbSpeed.OnChange := nil;
      tbSpeed.Value := 1;
      tbSpeed.OnChange := tbSpeedChange;
      FPendingSpeed := 1;
      lblSpeed.Text := '1.0x';
      UpdateControls;
    end;
  end;
end;

procedure TfrmMain.lblSpeedClick(Sender: TObject);
begin
  tbSpeed.Value := 1;
end;

procedure TfrmMain.OpenBook(const AFileName: string);
begin
  DebugLog('open: ' + AFileName);
  StopPlaying;
  // the book being left: its position kept
  RememberBook;
  FFindQuery := '';
  FFindHits := nil;
  FFindIndex := -1;
  if lblFind <> nil then
    lblFind.Text := '';
  FBookFile := '';
  FOpenWithNote := '';
  FAudioPath := '';
  FClip := -1;
  FSeekClip := -1;
  FLearnFirst := -1;
  FLearnLast := -1;
  FreeAndNil(FUnitLayout);
  FUnitDoc := -1;
  FChapterWord := nil;
  FChapterToc := nil;
  FChapterDoc := nil;
  FChapterTitle := nil;
  FTocIsChapters := False;
  EpubUnum1.Active := False;
  EpubUnum1.FileName := AFileName;
  EpubUnum1.Active := True;   // OnOpen or OnOpenFailed follows
  UpdateControls;
end;

procedure TfrmMain.btnOpenClick(Sender: TObject);
begin
  dlgOpen.Filter := 'EPUB books (*.epub)|*.epub|All files (*.*)|*.*';
  if dlgOpen.Execute then
    OpenBook(dlgOpen.FileName);
end;

procedure TfrmMain.EpubUnum1Open(Sender: TObject);
var
  B: TEpubBook;
  I, F, L, First: Integer;
  DocWords: TArray<Integer>;
  Ws: TEpubWordArray;
  K, Big: Integer;
begin
  DebugLog('open: read, building the view');
  DebugLog(Format('book: %d documents, %d words, %d clips', [Length(EpubUnum1.Book.Documents),
    EpubUnum1.Book.WordCount, Length(EpubUnum1.Book.Clips)]));
  // the biggest document (the one whose layout takes longest)
  if EpubUnum1.Book.WordCount > 0 then
  begin
    SetLength(DocWords, Length(EpubUnum1.Book.Documents));
    Ws := EpubUnum1.Book.Words;
    for K := 0 to High(Ws) do
      if (Ws[K].Document >= 0) and (Ws[K].Document <= High(DocWords)) then
        Inc(DocWords[Ws[K].Document]);
    Big := 0;
    for K := 1 to High(DocWords) do
      if DocWords[K] > DocWords[Big] then
        Big := K;
    if Length(DocWords) > 0 then
      DebugLog(Format('book: the biggest document is %d, %d words', [Big, DocWords[Big]]));
  end;
  B := EpubUnum1.Book;
  Caption := 'EpubReader - ' + B.Title;
  if FLearn then
    Caption := Caption + LEARN_TITLE;
  lbToc.BeginUpdate;
  try
    lbToc.Clear;
    for I := 0 to High(B.Toc) do
      lbToc.Items.Add(StringOfChar(' ', B.Toc[I].Level * 3) + B.Toc[I].Title);
  finally
    lbToc.EndUpdate;
  end;
  if FDark then
    ApplyTheme;   // the new items' text colour
  B.LoadText;
  SetLength(FClipFirst, Length(B.Clips));
  SetLength(FClipLast, Length(B.Clips));
  for I := 0 to High(B.Clips) do
    if B.ClipWords(I, F, L) then
    begin
      FClipFirst[I] := F;
      FClipLast[I] := L;
    end
    else
    begin
      FClipFirst[I] := -1;
      FClipLast[I] := -1;
    end;
  BuildChapters;
  if FTocIsChapters then
  begin
    // the contents list holds no chapters that are read: the chapters
    // (audiobook marks, with the book's unread pages) are the list
    lbToc.BeginUpdate;
    try
      lbToc.Clear;
      for I := 0 to High(FChapterTitle) do
        lbToc.Items.Add(FChapterTitle[I]);
    finally
      lbToc.EndUpdate;
    end;
    if FDark then
      ApplyTheme;
  end;
  BuildNotesMenu;
  // the first linear document with words
  First := 0;
  for I := 0 to High(B.Documents) do
    if B.Documents[I].Linear and (B.Documents[I].WordCount > 0) then
    begin
      First := I;
      Break;
    end;
  View1.ShowDocument(First);
  // this book now: first in Recently Opened, and back where it was left
  FBookFile := ExpandFileName(EpubUnum1.FileName);
  // its cover for the library (made once, cached)
  EnsureCover(FBookFile, B, B.Title);
  // each step logged: the Steam Deck crash comes after the cover (2026-11-17)
  DebugLog('open: cover done, hiding the library');
  HideLibrary;
  I := RecentIndex(FBookFile);
  if (I >= 0) and (FRecent[I].Word >= 0) then
  begin
    DebugLog(Format('open: back to word %d (lays the page out)', [FRecent[I].Word]));
    RestoreWord(FRecent[I].Word);
  end;
  DebugLog('open: remembering the book');
  RememberBook;
  View1.SetFocus;
  UpdateControls;
  DebugLog('open: done (the page is drawn next)');
end;

procedure TfrmMain.EpubUnum1OpenFailed(Sender: TObject; const AMessage: string);
begin
  DebugLog('open failed: ' + AMessage);
  lbToc.Clear;
  BuildNotesMenu;
  View1.Clear;
  Caption := 'EpubReader';
  if FLearn then
    Caption := Caption + LEARN_TITLE;
  UpdateControls;
  ShowMessage(AMessage);
end;

procedure TfrmMain.lbTocChange(Sender: TObject);
var
  B: TEpubBook;
  I, K: Integer;
begin
  if FSyncingToc then
    Exit;
  B := EpubUnum1.Book;
  I := lbToc.ItemIndex;
  if FTocIsChapters then
  begin
    if (B <> nil) and (I >= 0) and (I <= High(FChapterWord)) then
      GoChapter(I);
    Exit;
  end;
  if (B = nil) or (I < 0) or (I > High(B.Toc)) or (B.Toc[I].Document < 0) then
    Exit;
  // the chapter of this entry (entries at one place share a chapter)
  for K := 0 to High(FChapterToc) do
    if FChapterToc[K] = I then
    begin
      GoChapter(K);
      Exit;
    end;
  View1.ShowFragment(B.Toc[I].Document, B.Toc[I].Fragment);
  UpdateControls;
end;

procedure TfrmMain.BuildChapters;
const
  { Words of a document's start used as its title. }
  DOC_TITLE_WORDS = 6;
var
  B: TEpubBook;
  I, K, W, N, C, Limit, ReadCount: Integer;
  Doc: TEpubDocument;
  Marks: TEpubWordIndexArray;
  Title: string;
  TocWord, TocIdx: TArray<Integer>;
  Starts: TArray<Boolean>;
  Breaks: TArray<Integer>;

  { Adds a chapter (sorted in by AWord later). }
  procedure Add(AWord, AToc, ADoc: Integer; const ATitle: string);
  begin
    FChapterWord[N] := AWord;
    FChapterToc[N] := AToc;
    FChapterDoc[N] := ADoc;
    FChapterTitle[N] := ATitle;
    Inc(N);
  end;

  { True when the chapter from word AWord to ALimit (excluded) has audio. }
  function HasAudio(AWord, ALimit: Integer): Boolean;
  var
    Clip: Integer;
  begin
    Clip := ClipFromWord(AWord);
    Result := (Clip >= 0) and (FClipFirst[Clip] < ALimit);
  end;

  { True when the reading starts AT the chapter from word AWord: its first
    clip within READ_START_WORDS of it (a read heading). A contents entry
    for front matter (copyright page, dedication) can reach all the way
    to the next entry across the whole narrated book: it has audio, but
    is not a chapter that is read (Night Watch: its contents list is front
    and back matter only - the audiobook's 75 marks were not used). }
  function ReadAtStart(AWord, ALimit: Integer): Boolean;
  const
    READ_START_WORDS = 50;
  var
    Clip: Integer;
  begin
    Clip := ClipFromWord(AWord);
    // on the entry's own page, too: a map page of a few words is followed
    // by the narration on the next page (Night Watch's "Map")
    Result := (Clip >= 0) and (FClipFirst[Clip] < ALimit) and (FClipFirst[Clip] - AWord <= READ_START_WORDS) and
      (B.Words[FClipFirst[Clip]].Document = B.Words[AWord].Document);
  end;

begin
  DebugLog('chapters: building');
  B := EpubUnum1.Book;
  FChapterWord := nil;
  FChapterToc := nil;
  FChapterDoc := nil;
  FChapterTitle := nil;
  FTocIsChapters := False;
  FChapterSource := '';
  Breaks := nil;
  View1.ChapterBreaks := nil;
  if B = nil then
    Exit;
  Marks := B.AudioChapterWords;
  SetLength(FChapterWord, Length(B.Toc) + Length(B.Documents) + Length(Marks));
  SetLength(FChapterToc, Length(FChapterWord));
  SetLength(FChapterDoc, Length(FChapterWord));
  SetLength(FChapterTitle, Length(FChapterWord));
  // the contents' entries in reading order; an entry at the place of the
  // one before (a part and its first chapter) is that chapter
  TocWord := nil;
  TocIdx := nil;
  for I := 0 to High(B.Toc) do
  begin
    if B.Toc[I].Document < 0 then
      Continue;
    Doc := B.Documents[B.Toc[I].Document];
    W := Doc.FirstWord;
    if B.Toc[I].Fragment <> '' then
      for K := 0 to High(Doc.Ids) do
        if (Doc.Ids[K].Id = B.Toc[I].Fragment) and (Doc.Ids[K].FirstWord >= 0) then
        begin
          W := Doc.Ids[K].FirstWord;
          Break;
        end;
    if (Length(TocWord) > 0) and (W <= TocWord[High(TocWord)]) then
      Continue;
    TocWord := TocWord + [W];
    TocIdx := TocIdx + [I];
  end;
  // how many of them are read aloud
  ReadCount := 0;
  for I := 0 to High(TocWord) do
  begin
    if I < High(TocWord) then
      Limit := TocWord[I + 1]
    else
      Limit := MaxInt;
    if ReadAtStart(TocWord[I], Limit) then
      Inc(ReadCount);
  end;
  K := 0;
  for I := 0 to High(Marks) do
    if Marks[I] >= 0 then
      Inc(K);
  N := 0;
  FChapterSource := Format('contents (%d read), %d audiobook mark(s)', [ReadCount, K]);
  // the audiobook's marks when they give more chapters than the contents
  // list has chapters that are read (Night Watch: 75 marks, its contents
  // only front / back matter and "Begin Reading"); a book whose contents
  // list is its read chapters keeps it (Moby-Dick)
  if (K >= 2) and (K > ReadCount) then
  begin
    // the contents list has no chapters that are read (Night Watch: none
    // in the book, 75 in the audiobook): the audiobook's chapter marks,
    // with the contents' entries that are not read (title page, about
    // the author) and the documents no chapter starts in, so the front
    // and back matter can still be reached
    FTocIsChapters := True;
    FChapterSource := Format('audiobook marks (%d), contents read %d', [K, ReadCount]);
    for I := 0 to High(TocWord) do
    begin
      if I < High(TocWord) then
        Limit := TocWord[I + 1]
      else
        Limit := MaxInt;
      // the entries not read at their start: title page, copyright, about
      // the author - kept, so front and back matter can be reached
      if not ReadAtStart(TocWord[I], Limit) then
        Add(TocWord[I], TocIdx[I], B.Toc[TocIdx[I]].Document, Trim(B.Toc[TocIdx[I]].Title));
    end;
    for I := 0 to High(Marks) do
      if Marks[I] >= 0 then
      begin
        Title := Trim(B.AudioChapters[I].Title);
        if Title = '' then
          Title := 'Part ' + IntToStr(I + 1);
        // the recording's split is often inside a paragraph (a pause the
        // publisher cut at): the chapter starts with that paragraph - its
        // audio a few seconds earlier, the same recording
        W := Marks[I];
        C := WordBlock(W);
        if (C >= 0) and (Length(FUnitLayout.Blocks[C].Words) > 0) then
          W := FUnitLayout.Blocks[C].Words[0].Word + B.Documents[B.Words[Marks[I]].Document].FirstWord;
        // -2: a mark (made -1 below); of two marks on one word the later
        // one is kept (Opening Credits has no text of its own: its mark
        // falls on Chapter 1's first word)
        Add(W, -2, B.Words[W].Document, Title);
      end;
    // documents in which no chapter starts and nothing is read
    SetLength(Starts, Length(B.Documents));
    for I := 0 to N - 1 do
      Starts[FChapterDoc[I]] := True;
    for I := 0 to High(B.Documents) do
      if B.Documents[I].Linear and (B.Documents[I].WordCount > 0) and not Starts[I] and
        not HasAudio(B.Documents[I].FirstWord, B.Documents[I].FirstWord + B.Documents[I].WordCount) then
      begin
        Title := '';
        for K := B.Documents[I].FirstWord to Min(B.Documents[I].FirstWord + DOC_TITLE_WORDS,
          B.Documents[I].FirstWord + B.Documents[I].WordCount) - 1 do
          Title := Title + ' ' + B.Words[K].Text;
        if B.Documents[I].WordCount > DOC_TITLE_WORDS then
          Title := Title + ' ...';
        Add(B.Documents[I].FirstWord, -1, I, Trim(Title));
      end;
    // in reading order (stable: of two at one word the first added stays)
    for I := 1 to N - 1 do
    begin
      K := I;
      while (K > 0) and (FChapterWord[K - 1] > FChapterWord[K]) do
      begin
        W := FChapterWord[K]; FChapterWord[K] := FChapterWord[K - 1]; FChapterWord[K - 1] := W;
        C := FChapterToc[K]; FChapterToc[K] := FChapterToc[K - 1]; FChapterToc[K - 1] := C;
        C := FChapterDoc[K]; FChapterDoc[K] := FChapterDoc[K - 1]; FChapterDoc[K - 1] := C;
        Title := FChapterTitle[K]; FChapterTitle[K] := FChapterTitle[K - 1]; FChapterTitle[K - 1] := Title;
        Dec(K);
      end;
    end;
    K := 0;
    for I := 0 to N - 1 do
    begin
      if (K > 0) and (FChapterWord[I] = FChapterWord[K - 1]) then
      begin
        // one word, two entries: the first kept, except a mark after a
        // mark (the later one is the chapter the words belong to)
        if (FChapterToc[I] = -2) and (FChapterToc[K - 1] = -2) then
          FChapterTitle[K - 1] := FChapterTitle[I];
        Continue;
      end;
      FChapterWord[K] := FChapterWord[I];
      FChapterToc[K] := FChapterToc[I];
      FChapterDoc[K] := FChapterDoc[I];
      FChapterTitle[K] := FChapterTitle[I];
      Inc(K);
    end;
    N := K;
    // the chapter breaks the view draws: the marks, not the book's own
    // entries or documents
    for I := 0 to N - 1 do
      if FChapterToc[I] = -2 then
      begin
        Breaks := Breaks + [FChapterWord[I]];
        FChapterToc[I] := -1;
      end;
  end
  else
  begin
    for I := 0 to High(TocWord) do
      Add(TocWord[I], TocIdx[I], B.Toc[TocIdx[I]].Document, Trim(B.Toc[TocIdx[I]].Title));
    if N = 0 then
      // no contents: the linear documents with words
      for I := 0 to High(B.Documents) do
        if B.Documents[I].Linear and (B.Documents[I].WordCount > 0) then
          Add(B.Documents[I].FirstWord, -1, I, '');
  end;
  SetLength(FChapterWord, N);
  SetLength(FChapterToc, N);
  SetLength(FChapterDoc, N);
  SetLength(FChapterTitle, N);
  View1.ChapterBreaks := Breaks;
end;

function TfrmMain.ChapterOfWord(AWord: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FChapterWord) do
    if FChapterWord[I] <= AWord then
      Result := I
    else
      Break;
end;

function TfrmMain.CurrentWord: Integer;
var
  B: TEpubBook;
begin
  Result := -1;
  B := EpubUnum1.Book;
  if B = nil then
    Exit;
  if (FClip >= 0) and (FClip <= High(FClipFirst)) and (FClipFirst[FClip] >= 0) and
    (B.Clips[FClip].Document = View1.Document) then
    Result := FClipFirst[FClip]
  else if (View1.Document >= 0) and (View1.Document <= High(B.Documents)) then
    Result := B.Documents[View1.Document].FirstWord;
end;

function TfrmMain.ClipFromWord(AWord: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FClipFirst) do
    if FClipFirst[I] >= AWord then
      Exit(I);
  Result := -1;
end;

procedure TfrmMain.GoClip(AClip: Integer);
var
  B: TEpubBook;
begin
  B := EpubUnum1.Book;
  if (B = nil) or (AClip < 0) or (AClip > High(B.Clips)) then
    Exit;
  if FPlaying then
  begin
    StartClip(AClip);
    Exit;
  end;
  // paused or stopped: show it; Play starts here
  FClip := AClip;
  FSeekClip := AClip;
  DebugLog(Format('go to clip %d (document %d): laying out', [AClip, B.Clips[AClip].Document]));
  if B.Clips[AClip].Document <> View1.Document then
    View1.ShowDocument(B.Clips[AClip].Document);
  if FClipFirst[AClip] >= 0 then
  begin
    View1.Highlight(FClipFirst[AClip], FClipLast[AClip]);
    // the layout itself happens here (ScrollToWord lays the document out)
    View1.ScrollToWord(FClipFirst[AClip], True);
    SyncToc(FClipFirst[AClip]);
  end;
  DebugLog(Format('go to clip %d: shown (%d blocks)', [AClip, LayoutBlocks]));
  UpdateControls;
end;

procedure TfrmMain.GoChapter(AChapter: Integer);
var
  B: TEpubBook;
  C, Limit: Integer;
begin
  B := EpubUnum1.Book;
  if (B = nil) or (AChapter < 0) or (AChapter > High(FChapterWord)) then
    Exit;
  // Learn to read: the next step starts in the new chapter
  FLearnFirst := -1;
  if FChapterToc[AChapter] >= 0 then
    View1.ShowFragment(FChapterDoc[AChapter], B.Toc[FChapterToc[AChapter]].Fragment)
  else
  begin
    // an audiobook mark can be inside the document shown
    if FChapterDoc[AChapter] <> View1.Document then
      View1.ShowDocument(FChapterDoc[AChapter]);
    View1.ScrollToWord(FChapterWord[AChapter]);
  end;
  SyncToc(FChapterWord[AChapter]);
  // the audio follows: the chapter's first clip - one inside the chapter
  // (a chapter without audio does not jump to a later chapter's)
  C := ClipFromWord(FChapterWord[AChapter]);
  if AChapter < High(FChapterWord) then
    Limit := FChapterWord[AChapter + 1]
  else
    Limit := MaxInt;
  if (C >= 0) and (FClipFirst[C] < Limit) then
    GoClip(C)
  else
  begin
    // nothing to hear here: stop, and Play starts with the shown chapter
    StopPlaying;
    FClip := -1;
    FSeekClip := -1;
    View1.ClearHighlight;
    UpdateControls;
  end;
end;

procedure TfrmMain.SyncToc(AWord: Integer);
var
  K: Integer;
begin
  K := ChapterOfWord(AWord);
  if FTocIsChapters then
  begin
    if (K < 0) or (lbToc.ItemIndex = K) then
      Exit;
  end
  else
  begin
    if (K < 0) or (FChapterToc[K] < 0) or (lbToc.ItemIndex = FChapterToc[K]) then
      Exit;
    K := FChapterToc[K];
  end;
  FSyncingToc := True;
  try
    lbToc.ItemIndex := K;
  finally
    FSyncingToc := False;
  end;
end;

function TfrmMain.WordBlock(AWord: Integer): Integer;
var
  B: TEpubBook;
  D: Integer;
begin
  B := EpubUnum1.Book;
  D := B.Words[AWord].Document;
  if (FUnitLayout = nil) or (FUnitDoc <> D) then
  begin
    FreeAndNil(FUnitLayout);
    FUnitLayout := B.DocumentLayout(D);
    FUnitDoc := D;
  end;
  Result := B.BlockOfWord(FUnitLayout, D, AWord);
end;

{ True when word AWord ends a phrase: its last character, after closing
  quotes and brackets, is , ; : . ! ? or a dash (U+2012 - U+2015, which
  EpubUnum leaves on the word before it), or the word closes a bracket. }
function EndsPhrase(const AWord: string): Boolean;
var
  N: Integer;
begin
  Result := False;
  N := Length(AWord);
  if (N > 0) and CharInSet(AWord[N], [')', ']']) then
    Exit(True);
  while (N > 0) and ((AWord[N] = '"') or (AWord[N] = '''') or (Ord(AWord[N]) = $2019) or
    (Ord(AWord[N]) = $201D) or (Ord(AWord[N]) = $BB)) do
    Dec(N);
  if N = 0 then
    Exit;
  Result := CharInSet(AWord[N], [',', ';', ':', '.', '!', '?']) or
    ((Ord(AWord[N]) >= $2012) and (Ord(AWord[N]) <= $2015));
end;

function TfrmMain.IsUnitStart(AWord: Integer): Boolean;
var
  B: TEpubBook;
begin
  B := EpubUnum1.Book;
  if AWord <= 0 then
    Exit(True);
  if B.Words[AWord - 1].Document <> B.Words[AWord].Document then
    Exit(True);
  if (StepUnit <> UNIT_PARAGRAPH) and EpubEndsSentence(B.Words[AWord - 1].Text) then
    Exit(True);
  if (StepUnit = UNIT_PHRASE) and EndsPhrase(B.Words[AWord - 1].Text) then
    Exit(True);
  Result := WordBlock(AWord - 1) <> WordBlock(AWord);
end;

function TfrmMain.UnitStart(AWord: Integer): Integer;
begin
  Result := AWord;
  while not IsUnitStart(Result) do
    Dec(Result);
end;

function TfrmMain.UnitEnd(AWord: Integer): Integer;
var
  B: TEpubBook;
begin
  B := EpubUnum1.Book;
  Result := AWord;
  while (Result + 1 < B.WordCount) and not IsUnitStart(Result + 1) do
    Inc(Result);
end;

function TfrmMain.StepUnit: Integer;
begin
  if cbStep.ItemIndex < 0 then
    Result := UNIT_SENTENCE
  else if FLearn then
    Result := cbStep.ItemIndex
  else
    Result := cbStep.ItemIndex + UNIT_SENTENCE;
end;

procedure TfrmMain.FillSteps;
var
  Was: Integer;
  Handler: TNotifyEvent;
begin
  if cbStep.Count > 0 then
    Was := StepUnit
  else
    Was := UNIT_SENTENCE;
  Handler := cbStep.OnChange;
  cbStep.OnChange := nil;
  try
    cbStep.Items.Clear;
    if FLearn then
    begin
      cbStep.Items.Add('Phrase');
      Was := UNIT_PHRASE;   // the mode starts with phrases
    end
    else if Was < UNIT_SENTENCE then
      Was := UNIT_SENTENCE;
    cbStep.Items.Add('Sentence');
    cbStep.Items.Add('Paragraph');
    if FLearn then
      cbStep.ItemIndex := Was
    else
      cbStep.ItemIndex := Was - UNIT_SENTENCE;
  finally
    cbStep.OnChange := Handler;
  end;
  cbStepChange(nil);
end;

procedure TfrmMain.cbStepChange(Sender: TObject);
var
  Name: string;
begin
  case StepUnit of
    UNIT_PHRASE: Name := 'phrase';
    UNIT_PARAGRAPH: Name := 'paragraph';
  else
    Name := 'sentence';
  end;
  if FLearn then
  begin
    btnPrevClip.Hint := 'Previous ' + Name + ' - said, then stops';
    btnNextClip.Hint := 'Next ' + Name + ' - said, then stops';
  end
  else
  begin
    btnPrevClip.Hint := 'Previous ' + Name;
    btnNextClip.Hint := 'Next ' + Name;
  end;
  // the unit shown is redone in the new size at the next step
end;

procedure TfrmMain.btnLearnClick(Sender: TObject);
begin
  FLearn := not FLearn;
  btnLearn.IsPressed := FLearn;
  miLearn.IsChecked := FLearn;
  RefreshMenu;
  FLearnFirst := -1;
  FLearnLast := -1;
  if FLearn then
    StopPlaying;
  // obvious at a glance: green band and highlight, title, status, hints
  Caption := StringReplace(Caption, LEARN_TITLE, '', []);
  if FLearn then
  begin
    Caption := Caption + LEARN_TITLE;
    btnPlay.Hint := 'Say the highlighted words again (R)';
  end
  else
    btnPlay.Hint := 'Play / pause (P)';
  ApplyTheme;
  FillSteps;
  UpdateControls;
end;

function TfrmMain.OpenClipAudio(AClip: Integer): Boolean;
var
  B: TEpubBook;
  C: TEpubClip;
  Target: string;
  I, First: Integer;
begin
  DebugLog(Format('clip %d: opening its audio', [AClip]));
  Result := False;
  B := EpubUnum1.Book;
  if (B = nil) or (FPlayer = nil) or (AClip < 0) or (AClip > High(B.Clips)) then
    Exit;
  C := B.Clips[AClip];
  try
    if C.AudioPath <> FAudioPath then
    begin
      // FFmpeg streams a file: the book's audio is extracted once
      // The file name is made HERE, never from the path inside the book:
      // that path is the book's to choose, and one with backslashes and
      // '..', or an absolute one (which System.IOUtils.TPath.Combine returns as it is),
      // wrote the book's bytes anywhere on the disk. It is
      // <book number>-<first clip of this audio file><extension>, so a
      // second book never finds the first one's file under its own name.
      First := AClip;
      for I := 0 to AClip do
        if B.Clips[I].AudioPath = C.AudioPath then
        begin
          First := I;
          Break;
        end;
      Target := System.IOUtils.TPath.Combine(FAudioFolder, Format('%d-%d%s', [EpubUnum1.BookSerial, First,
        SafeAudioExtension(C.AudioPath)]));
      if not TFile.Exists(Target) then
      begin
        ForceDirectories(FAudioFolder);
        DebugLog(Format('clip %d: extracting %s to %s', [AClip, C.AudioPath, Target]));
        B.Zip.Extract(C.AudioPath, Target);
        DebugLog(Format('clip %d: extracted, %d bytes', [AClip, TFile.GetSize(Target)]));
      end;
      DebugLog(Format('clip %d: opening it in the player', [AClip]));
      FPlayer.Open(Target);
      DebugLog(Format('clip %d: open', [AClip]));
      FAudioPath := C.AudioPath;
    end;
    Result := True;
  except
    on E: Exception do
    begin
      DebugLog(Format('clip %d: %s', [AClip, E.Message]));
      FSoundNote := E.Message;
      UpdateControls;
    end;
  end;
end;

procedure TfrmMain.SayWords(AFirst, ALast: Integer);
var
  B: TEpubBook;
  W, CFirst, CLast, C: Integer;
  T0, T1: Double;
begin
  B := EpubUnum1.Book;
  if (B = nil) or (AFirst < 0) or (ALast < AFirst) then
    Exit;
  StopPlaying;
  FLearnFirst := AFirst;
  FLearnLast := ALast;
  if B.Words[AFirst].Document <> View1.Document then
    View1.ShowDocument(B.Words[AFirst].Document);
  View1.Highlight(AFirst, ALast);
  View1.ScrollToWord(AFirst, True);
  SyncToc(AFirst);
  // the clips of the unit's first and last words that have one
  CFirst := -1;
  for W := AFirst to ALast do
  begin
    CFirst := ClipOfWord(W);
    if CFirst >= 0 then
      Break;
  end;
  CLast := -1;
  if CFirst >= 0 then
    for W := ALast downto AFirst do
    begin
      C := ClipOfWord(W);
      // one audio file: a unit across two parts is said up to the first's end
      if (C >= 0) and SameText(B.Clips[C].AudioPath, B.Clips[CFirst].AudioPath) and
        (B.Clips[C].ClipEnd > B.Clips[CFirst].ClipBegin) then
      begin
        CLast := C;
        Break;
      end;
    end;
  if CLast < 0 then
  begin
    // nothing to hear (not read in this recording): shown only, and the
    // unit said before is cut off
    if FPlayer <> nil then
      FPlayer.Pause;
    UpdateControls;
    Exit;
  end;
  // Play after this goes on from the unit
  FClip := CFirst;
  FSeekClip := CFirst;
  if not OpenClipAudio(CFirst) then
    Exit;
  T0 := Max(0, B.Clips[CFirst].ClipBegin - SAY_PAD_BEFORE);
  T1 := B.Clips[CLast].ClipEnd + SAY_PAD_AFTER;
  try
    FPlayer.PlayRange(T0, T1);
  except
    on E: Exception do
      FSoundNote := E.Message;
  end;
  UpdateControls;
end;

procedure TfrmMain.LearnStep(ADirection: Integer);
var
  B: TEpubBook;
  W: Integer;
begin
  B := EpubUnum1.Book;
  if (B = nil) or (B.WordCount = 0) then
    Exit;
  if FLearnFirst < 0 then
  begin
    // no unit said yet: from the word being read (paused) - Next goes
    // on to the unit after it, Previous says its own; nothing read yet:
    // the page's first unit
    W := CurrentWord;
    if W < 0 then
      Exit;
    W := UnitStart(W);
    if (ADirection > 0) and (FClip >= 0) then
    begin
      W := UnitEnd(W) + 1;
      if W >= B.WordCount then
        Exit;
    end;
  end
  else if ADirection > 0 then
  begin
    // the unit after the one shown (redone in the step chosen now)
    W := UnitEnd(UnitStart(FLearnLast)) + 1;
    if W >= B.WordCount then
      Exit;
  end
  else
  begin
    W := UnitStart(FLearnFirst);
    if W = 0 then
      Exit;
    W := UnitStart(W - 1);
  end;
  if (W < 0) or (W >= B.WordCount) then
    Exit;
  SayWords(W, UnitEnd(W));
end;

procedure TfrmMain.btnDarkClick(Sender: TObject);
begin
  FDark := not FDark;
  miDark.IsChecked := FDark;
  RefreshMenu;
  ApplyTheme;
end;

procedure TfrmMain.ApplyTheme;
var
  I: Integer;
begin
  // the page
  if FDark then
  begin
    View1.BackgroundColor := DARK_PAGE;
    View1.TextColor := DARK_TEXT;
    if FLearn then
      View1.HighlightColor := LEARN_HIGHLIGHT_DARK
    else
      View1.HighlightColor := DARK_HIGHLIGHT;
    View1.LinkColor := DARK_LINK;
    View1.NoteColor := DARK_NOTE;
  end
  else
  begin
    // TEpubView's own defaults: warm paper
    View1.BackgroundColor := $FFFBF7EF;
    View1.TextColor := $FF222222;
    if FLearn then
      View1.HighlightColor := LEARN_HIGHLIGHT
    else
      View1.HighlightColor := $FFFFE08A;
    View1.LinkColor := $FF1A5FB4;
    View1.NoteColor := $FFEDE6D6;
  end;
  // the library has the page's colours
  if recLibrary <> nil then
  begin
    recLibrary.Fill.Color := View1.BackgroundColor;
    lblLibrary.TextSettings.FontColor := View1.TextColor;
  end;
  // Learn to read: the green band behind the tool bar
  recLearn.Visible := FLearn;
  if FDark then
    recLearn.Fill.Color := LEARN_BAR_DARK
  else
    recLearn.Fill.Color := LEARN_BAR;
  // the window behind the tool bar
  if FDark then
  begin
    Fill.Kind := TBrushKind.Solid;
    Fill.Color := DARK_PANEL;
  end
  else
    Fill.Kind := TBrushKind.None;
  // the status line
  if FDark then
  begin
    lblStatus.StyledSettings := lblStatus.StyledSettings - [TStyledSetting.FontColor];
    lblStatus.TextSettings.FontColor := DARK_PANEL_TEXT;
  end
  else
    lblStatus.StyledSettings := lblStatus.StyledSettings + [TStyledSetting.FontColor];
  if FDark then
  begin
    lblSpeed.StyledSettings := lblSpeed.StyledSettings - [TStyledSetting.FontColor];
    lblSpeed.TextSettings.FontColor := DARK_PANEL_TEXT;
  end
  else
    lblSpeed.StyledSettings := lblSpeed.StyledSettings + [TStyledSetting.FontColor];
  // the contents: the items' text here, the background in TocApplyStyle
  for I := 0 to lbToc.Count - 1 do
    if FDark then
    begin
      lbToc.ListItems[I].StyledSettings := lbToc.ListItems[I].StyledSettings - [TStyledSetting.FontColor];
      lbToc.ListItems[I].TextSettings.FontColor := DARK_PANEL_TEXT;
    end
    else
      lbToc.ListItems[I].StyledSettings := lbToc.ListItems[I].StyledSettings + [TStyledSetting.FontColor];
  // Dark: FMX's transparent list box style, so the form's dark Fill shows
  // through - the plain style's white background (not reliably reachable
  // by name) left light text on white: unreadable (owner, zip 10).
  if FDark then
    lbToc.StyleLookup := 'transparentlistboxstyle'
  else
    lbToc.StyleLookup := '';
  lbToc.NeedStyleLookup;
  lbToc.ApplyStyleLookup;
  // the tool bar's buttons keep the platform style (their icons follow it)
end;

procedure TfrmMain.TocApplyStyle(Sender: TObject);
var
  O: TFmxObject;
begin
  // a fresh copy of the style: light as the style made it; dark: its
  // background made dark too, should the style still have one (a style
  // without 'transparentlistboxstyle' falls back to the plain one)
  if not FDark then
    Exit;
  O := lbToc.FindStyleResource('background');
  if O is TShape then
  begin
    TShape(O).Fill.Kind := TBrushKind.Solid;
    TShape(O).Fill.Color := DARK_PANEL;
  end
  else if O is TControl then
    TControl(O).Opacity := 0;   // a background of another kind: hidden
end;

procedure TfrmMain.btnPrevClick(Sender: TObject);
var
  K, W: Integer;
begin
  // the start of this chapter; at its start already, the one before
  W := CurrentWord;
  K := ChapterOfWord(W);
  if (K >= 0) and (FClip >= 0) and (W > FChapterWord[K]) and
    (ClipFromWord(FChapterWord[K]) <> FClip) then
    GoChapter(K)
  else if K > 0 then
    GoChapter(K - 1)
  else if K = 0 then
    GoChapter(0);
end;

procedure TfrmMain.btnNextClick(Sender: TObject);
var
  K: Integer;
begin
  K := ChapterOfWord(CurrentWord);
  if K < High(FChapterWord) then
    GoChapter(K + 1);
end;

procedure TfrmMain.btnSmallerClick(Sender: TObject);
begin
  // not below Steam's least on a Steam Deck
  if SteamOnDeck and (View1.FontSize - SIZE_STEP < SIZE_MIN_DECK) then
    Exit;
  if View1.FontSize > 10 then
    View1.FontSize := View1.FontSize - SIZE_STEP;
end;

procedure TfrmMain.btnLargerClick(Sender: TObject);
begin
  if View1.FontSize < 60 then
    View1.FontSize := View1.FontSize + SIZE_STEP;
end;

function TfrmMain.FirstClipOfDocument(ADoc: Integer): Integer;
var
  B: TEpubBook;
  I: Integer;
begin
  Result := -1;
  B := EpubUnum1.Book;
  if B = nil then
    Exit;
  for I := 0 to High(B.Clips) do
    if B.Clips[I].Document = ADoc then
      Exit(I);
end;

function TfrmMain.ClipOfWord(AWord: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FClipFirst) do
    if (AWord >= FClipFirst[I]) and (AWord <= FClipLast[I]) then
      Exit(I);
  Result := -1;
end;

procedure TfrmMain.StartClip(AClip: Integer);
var
  B: TEpubBook;
  C: TEpubClip;
begin
  DebugLog(Format('clip %d: starting', [AClip]));
  B := EpubUnum1.Book;
  if (B = nil) or (AClip < 0) or (AClip > High(B.Clips)) then
    Exit;
  C := B.Clips[AClip];
  FSeekClip := -1;
  if FPlayer = nil then
  begin
    // no sound: show the clip at least
    FClip := AClip;
    if C.Document <> View1.Document then
      View1.ShowDocument(C.Document);
    if FClipFirst[AClip] >= 0 then
    begin
      View1.Highlight(FClipFirst[AClip], FClipLast[AClip]);
      View1.ScrollToWord(FClipFirst[AClip], True);
    end;
    UpdateControls;
    Exit;
  end;
  if not OpenClipAudio(AClip) then
    Exit;
  // Play reads on: Learn to read's unit is left
  FLearnFirst := -1;
  try
    DebugLog(Format('clip %d: play from %.3f s', [AClip, C.ClipBegin]));
    FPlayer.Play(C.ClipBegin);
    DebugLog(Format('clip %d: playing', [AClip]));
  except
    on E: Exception do
    begin
      DebugLog(Format('clip %d: %s', [AClip, E.Message]));
      FSoundNote := E.Message;
      UpdateControls;
      Exit;
    end;
  end;
  FPlaying := True;
  FClip := -2;   // the timer highlights the clip it finds
  tmPlay.Enabled := True;
  UpdateControls;
end;

procedure TfrmMain.StopPlaying;
begin
  DebugLog('stop playing');
  tmPlay.Enabled := False;
  if FPlaying and (FPlayer <> nil) then
    FPlayer.Pause;
  FPlaying := False;
  UpdateControls;
end;

procedure TfrmMain.btnPlayClick(Sender: TObject);
var
  B: TEpubBook;
  C: Integer;
begin
  DebugLog('play / pause clicked');
  B := EpubUnum1.Book;
  if (B = nil) or (Length(B.Clips) = 0) or LibraryShowing then
    Exit;
  if FLearn then
  begin
    // Learn to read: Play says what is highlighted again (a hard word:
    // click it, then Play as often as needed) - it never reads on
    StopPlaying;
    if FLearnFirst >= 0 then
      SayWords(FLearnFirst, FLearnLast)
    else if CurrentWord >= 0 then
      SayWords(UnitStart(CurrentWord), UnitEnd(UnitStart(CurrentWord)));
    Exit;
  end;
  if FPlaying then
  begin
    StopPlaying;
    Exit;
  end;
  if FSeekClip >= 0 then
  begin
    // a jump while paused: play from there
    C := FSeekClip;
    StartClip(C);
    Exit;
  end;
  if (FPlayer <> nil) and (FClip >= 0) and (B.Clips[FClip].Document = View1.Document) and
    (FPlayer.FileName <> '') and not FPlayer.Ended then
  begin
    // resume where it was paused
    FPlayer.Resume;
    FPlaying := True;
    tmPlay.Enabled := True;
    UpdateControls;
    Exit;
  end;
  C := FirstClipOfDocument(View1.Document);
  if C < 0 then
    C := 0;
  StartClip(C);
end;

procedure TfrmMain.btnPrevClipClick(Sender: TObject);
var
  B: TEpubBook;
  W, S, C: Integer;
  AtStart: Boolean;
begin
  if FLearn then
  begin
    LearnStep(-1);
    Exit;
  end;
  B := EpubUnum1.Book;
  W := CurrentWord;
  if (B = nil) or (W < 0) or (Length(B.Clips) = 0) then
    Exit;
  S := UnitStart(W);
  C := ClipFromWord(S);
  // at (or just past) the start of this sentence: the one before
  if FPlaying and (C >= 0) and (FPlayer <> nil) and SameText(B.Clips[C].AudioPath, FAudioPath) then
    AtStart := FPlayer.Position - B.Clips[C].ClipBegin < BACK_GRACE
  else
    AtStart := (C < 0) or (FClip <= C);
  if AtStart and (S > 0) then
  begin
    S := UnitStart(S - 1);
    C := ClipFromWord(S);
  end;
  if C >= 0 then
    GoClip(C);
end;

procedure TfrmMain.btnNextClipClick(Sender: TObject);
var
  B: TEpubBook;
  W, C: Integer;
begin
  if FLearn then
  begin
    LearnStep(1);
    Exit;
  end;
  B := EpubUnum1.Book;
  W := CurrentWord;
  if (B = nil) or (W < 0) or (Length(B.Clips) = 0) then
    Exit;
  repeat
    Inc(W);
  until (W >= B.WordCount) or IsUnitStart(W);
  if W >= B.WordCount then
    Exit;
  C := ClipFromWord(W);
  // always forward, even when a clip holds several sentences
  if (C >= 0) and (C <= FClip) then
    C := FClip + 1;
  if (C >= 0) and (C <= High(B.Clips)) then
    GoClip(C);
end;

procedure TfrmMain.View1WordClick(Sender: TObject; AWord: Integer);
var
  C: Integer;
begin
  if FLearn then
  begin
    // the phrase / sentence / paragraph (cbStep) the word is in - a click
    // that said one word left Play repeating just that word (owner)
    SayWords(UnitStart(AWord), UnitEnd(UnitStart(AWord)));
    Exit;
  end;
  C := ClipOfWord(AWord);
  if C >= 0 then
    StartClip(C);
end;

procedure TfrmMain.View1DocumentChange(Sender: TObject);
begin
  UpdateControls;
end;

procedure TfrmMain.tmPlayTimer(Sender: TObject);
var
  B: TEpubBook;
  T: Double;
  C, I: Integer;
begin
  B := EpubUnum1.Book;
  if (B = nil) or (FPlayer = nil) or not FPlaying then
    Exit;
  // the time of the sound really being heard
  T := FPlayer.Position;
  C := B.ClipAt(FAudioPath, T);
  if (C <> FClip) and (C >= 0) then
  begin
    // the first clips of a play, and every change of document, in the
    // debug log (a document laid out can take long - Linux)
    if (FClip < 0) or (B.Clips[C].Document <> View1.Document) then
      DebugLog(Format('clip %d at %.3f s (document %d)', [C, T, B.Clips[C].Document]));
    FClip := C;
    if B.Clips[C].Document <> View1.Document then
    begin
      DebugLog(Format('document %d: laying out', [B.Clips[C].Document]));
      View1.ShowDocument(B.Clips[C].Document);
    end;
    if FClipFirst[C] >= 0 then
    begin
      View1.Highlight(FClipFirst[C], FClipLast[C]);
      View1.ScrollToWord(FClipFirst[C], True);
      SyncToc(FClipFirst[C]);
    end;
    if FClip = C then
      DebugLog(Format('clip %d: shown (%d blocks)', [C, LayoutBlocks]));
    UpdateControls;
  end;
  if FPlayer.LastError <> '' then
  begin
    FSoundNote := FPlayer.LastError;
    StopPlaying;
    Exit;
  end;
  // this audio file has played out: go on with the next file's first clip
  if FPlayer.Ended then
  begin
    I := Max(FClip, 0);
    while (I <= High(B.Clips)) and (B.Clips[I].AudioPath = FAudioPath) do
      Inc(I);
    if I <= High(B.Clips) then
      StartClip(I)
    else
      StopPlaying;
  end;
end;

procedure TfrmMain.UpdateControls;
var
  B: TEpubBook;
  S: string;
begin
  if FPlaying <> FAwake then
  begin
    // read aloud with nobody at the controls: SteamOS (Game Mode) goes by
    // input only and would dim, then sleep
    FAwake := FPlaying;
    if FPlaying then
      InhibitStart(ikDisplay, 'Reading aloud')
    else
      InhibitStop(ikDisplay);
    DebugLog('screen: ' + InhibitText);
  end;
  B := EpubUnum1.Book;
  btnPrev.Enabled := (B <> nil) and (Length(FChapterWord) > 0) and not LibraryShowing;
  btnNext.Enabled := (B <> nil) and (ChapterOfWord(CurrentWord) < High(FChapterWord)) and not LibraryShowing;
  // nothing plays while the library shows
  btnPlay.Enabled := (B <> nil) and (Length(B.Clips) > 0) and not LibraryShowing;
  btnPrevClip.Enabled := btnPlay.Enabled;
  btnNextClip.Enabled := btnPlay.Enabled;
  if FPlaying then
    SetIcon(btnPlay, ICON_PAUSE)
  else
    SetIcon(btnPlay, ICON_PLAY);
  if LibraryShowing then
    S := 'Library - click a cover to read (Esc: back to the open book)'
  else if B = nil then
    S := 'No book open'
  else
  begin
    S := Format('%s - document %d of %d', [B.Title, View1.Document + 1, Length(B.Documents)]);
    if Length(B.Clips) = 0 then
      S := S + ' - no audio (no media overlays)'
    else if FPlaying then
      S := S + Format(' - playing %s', [ExtractFileName(StringReplace(FAudioPath, '/', PathDelim, [rfReplaceAll]))]);
  end;
  if FSoundNote <> '' then
    S := S + ' - ' + FSoundNote;
  if FOpenWithNote <> '' then
    S := S + ' - ' + FOpenWithNote;
  // "debug": true in the settings - where the chapters came from
  if FDebug and (B <> nil) and (FChapterSource <> '') then
    S := S + ' - chapters: ' + FChapterSource;
  if FLearn then
    S := 'LEARN TO READ - ' + S;
  lblStatus.Text := S;
end;

end.
