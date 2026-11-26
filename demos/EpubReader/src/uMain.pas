{ @abstract(Main form of EpubReader: open an EPUB, read it in a Skia view,
  and - for a book with media overlays - play its audio with the words
  highlighted as they are read.)

  The book component (EpubUnum1), the view (View1) and their events are
  set up in uMain.fmx. The sound is uPlayer's TReaderPlayer; on a desktop
  that is FFmpegAPI's TFFmpegAudioPlayer (uPlayerFFmpeg; TFFMpegAPI,
  installed separately): the book's audio file streamed by
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

// TEpubBook.Create and CreateHeader both take a file name only: Delphi
// warns (W1029) that C++ could not tell them apart, here where the class
// is used - no C++ uses it (zip 341)
{$WARN DUPLICATE_CTOR_DTOR OFF}

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.IOUtils, System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Layouts, FMX.Platform,
  FMX.ListBox, FMX.Controls.Presentation, FMX.Objects, FMX.Menus, FMX.Edit, System.JSON,
  // TJSONArray's inline getters expand only with it (H2443)
  System.Generics.Collections,
  Epub.Zip, Epub.Layout, Epub.Book, Epub.Components, Epub.FMX, Epub.FMX.View, uDebugLog,
  // sound: the platform's player behind one class (the desktop's is
  // uPlayerFFmpeg: DCUs of TFFMpegAPI's runtime package FFmpegAPI)
  uPlayer,
  // the game pad and its menu (fields of the form)
  uSteamPad, uPadMenu,
  // Android: the books folders chosen in the system's picker, read in place
  uBookImport,
  // a phone: BookManager sends it books over the network (zip 355)
  uLink,
  // the version, major.minor.build (About, the log)
  uVersion,
  // About > Licences: the outside components and their licences
  uLicences,
  // Linux: the window brought back after the screen saver (a field)
  uRedraw,
  // the folders shared with EpubBuilder (SettingsFile, the books)
  uEpubUnum,
  // the cover chooser: EpubBuilder's units (thumbnails, the audio's art)
  uCovers, uCoverPick;

type
  { The library's order (zip 340): as last opened, or by a book's details.
    The book read last stays first (the large cover) in every order. }
  TLibrarySort = (lsRecent, lsTitle, lsAuthor, lsYear, lsGenre);

  { What is highlighted while the book is read aloud (zip 352; owner
    15:53 - 15:55, "all options are valid"): the word alone, or the phrase
    or the sentence it is in - all of it or only up to the word
    (trailing), with or without the word over it in its own colour (zip
    353: three menu rows, owner 16:22). }
  THighlightUnit = (huWord, huPhrase, huSentence);

  { A book in the Recently Opened list, with where its reader left off. }
  TRecentBook = record
    { The EPUB file. }
    FileName: string;
    { Its title (the menu shows it). }
    Title: string;
    { Its authors, as the book names them ('Isaac Asimov'). }
    Author: string;
    { The first author as sorted ('Asimov, Isaac'): the book's file-as,
      else made from the name. }
    AuthorSort: string;
    { The year of its date (dc:date - often the edition's, not the first
      printing's), 0 = none. }
    Year: Integer;
    { Its first subject (dc:subject - often a genre), '' = none. }
    Genre: string;
    { Author, AuthorSort, Year and Genre have been read (books of the
      library from before zip 340 have not: read when an order needs
      them). }
    Meta: Boolean;
    { The word the reader was at (index into the book's Words), -1 = the
      start. }
    Word: Integer;
    { The same place without the book's word numbers: the document
      (index into Documents) and the word in it, -1 = not known. A page
      can be shown from these before the whole book is read (zip 332). }
    Doc, DocWord: Integer;
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
    { The part of the window clear of the system's bars and the screen's
      cut-outs changed (a phone, a tablet): the window's contents keep
      inside it. AInsets is what each edge loses. }
    procedure FormSafeAreaChanged(Sender: TObject; const AInsets: TRectF);
    { The touch bar's width changed: its buttons share it evenly. }
    procedure layTouchResized(Sender: TObject);
    { Touch bar: the menu (the pad's: Library, Contents, Text size ...),
      or away with it. }
    procedure btnTouchMenuClick(Sender: TObject);
    { Touch bar: a page back. }
    procedure btnTouchPageBackClick(Sender: TObject);
    { Touch bar: a page on. }
    procedure btnTouchPageOnClick(Sender: TObject);
    { An exception nothing handled: into the debug log with the library it
      happened in (DebugLogException), then shown as before. }
    procedure AppException(Sender: TObject; E: Exception);
    { The first time the window is shown: the display it is on into the
      debug log (SteamScreenText). }
    procedure FormShow(Sender: TObject);
    { The window is active again: brought back (FRedraw). }
    procedure FormActivated(Sender: TObject);
    { The window is not active any more: logged (FRedraw). }
    procedure FormDeactivated(Sender: TObject);
    {$IFDEF ANDROID}
    { Android: the app is in front again (it is not ended when left) - the
      library looks for books copied in meanwhile. }
    function AppEvent(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;
    {$ENDIF}
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
    { View > Graphics: Windows' graphics preference for the reader (its
      Tag), used from the next start. }
    procedure miGpuClick(Sender: TObject);
    { View > Cover of this book: ShowCoverChoice. }
    procedure miCoverClick(Sender: TObject);
    { The covers there are for the open book - its own, its audiobook's
      (the m4b inside it), the Covers folder's pictures - as thumbnails;
      the one chosen becomes the library's picture of the book (the book
      file is not changed: owner, 2026-11-20, "Reader only"). }
    procedure ShowCoverChoice;
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
    { The page was scrolled on past an end of its document: the next or
      the previous document of the reading order is shown (zip 339). }
    procedure View1Edge(Sender: TObject; AForward: Boolean);
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
    { The touch bar at the foot of the window (nil on a desktop): Menu,
      page back, sentence back, Play, sentence on, page on. Zip 321. }
    layTouch: TLayout;
    { The touch bar's buttons, left to right. }
    FTouchButtons: TArray<TButton>;
    { The touch bar's Play / pause, sentence back and sentence on. }
    btnTouchPlay, btnTouchPrevClip, btnTouchNextClip: TButton;
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
    { The library's order (Menu > Library order; saved). }
    FLibrarySort: TLibrarySort;
    { What is highlighted while reading aloud (Menu > Highlight; saved). }
    FHighUnit: THighlightUnit;
    { The phrase / sentence only up to the word being read (Menu >
      Highlight type: Trailing; saved). }
    FHighTrailing: Boolean;
    { The word over the phrase / sentence in its own colour (Menu >
      Highlight word; saved). }
    FHighWord: Boolean;
    { The phrase / sentence last highlighted (book words; FHiUnit = its
      UNIT_*, -1 = none): it is looked for again only when the read word
      leaves it (owner 15:56: "only needs to run when it changes"). }
    FHiFirst, FHiLast, FHiUnit: Integer;
    { Android: the books folders chosen in the system's picker (the
      phone's, a memory card's - owner: "they could also use sd card"),
      their addresses; saved as "booksFolders" (uBookImport). }
    FBooksTrees: TArray<string>;
    { A phone: the link BookManager sends books through - only while the
      user links (Get books from BookManager; zip 357, owner 17:19: "get
      phone to request link services as this will allow turning it off
      after link stuff done"), nil otherwise. A paired BookManager uploads
      EPUBs into FBooksFolder. }
    FLink: TLinkServer;
    { Hears the BookManagers while linking (each is answered directly:
      FLink.SetDirect). }
    FLinkFinder: TLinkFinder;
    { The link panel: what it says now. }
    FLinkStatus: string;
    { The pairing code shown ('' = none) and who asked. }
    FLinkCode, FLinkCodeFor: string;
    { The book being received, in words ('' = none). }
    FLinkProgress: string;
    { Books received since the link started. }
    FLinkReceived: Integer;
    { The last book received (its name). }
    FLinkLast: string;
    { BookManagers heard while linking (their addresses, for the log). }
    FLinkHeard: string;
    { Something happened on the link (paired, a call of a paired
      BookManager, a book): Done may be chosen (owner 17:33: "DONE ...
      should be disabled until something happens"). }
    FLinkActive: Boolean;
    { The menu the link was started from (MODE_START, MODE_FOLDERS or
      MODE_MAIN):
      Cancel goes back to it ("a CANCEL that returns you to main choose
      book source menu"). }
    FLinkFrom: Integer;
    { This reader's id on the link (made once; saved as "linkId"). }
    FLinkId: string;
    { The BookManagers paired, token=name a line (saved as
      "linkTokens"). }
    FLinkTokens: string;
    { The books the books folders held at their last listing (addresses,
      in their order), and the same for asking (ListBooksFolders). }
    FFolderBooks: TArray<string>;
    { ... }
    FFolderBookSet: TDictionary<string, Boolean>;
    { Every folder could be listed then (when one could not, its books are
      not taken for gone). }
    FFolderBooksOK: Boolean;
    { About > Licences: the components (ReaderLicences). }
    FLicences: TArray<TLicenceInfo>;
    { The licence shown (index into FLicences), its pages and the page. }
    FLicence, FLicencePage: Integer;
    { The books folder shown (MODE_FOLDER; index into FBooksTrees). }
    FFolderShown: Integer;
    { ... }
    FLicencePages: TArray<string>;
    { File > Library order's items (the desktop's menu). }
    miSort: array[TLibrarySort] of TMenuItem;
    { View > Highlight's items (the desktop's menu). }
    miHigh: array[THighlightUnit] of TMenuItem;
    { View > Highlight > Trailing. }
    miHighTrailing: TMenuItem;
    { View > Highlight > Word in its own colour. }
    miHighWord: TMenuItem;
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
    { The sound (uPlayer: FFmpeg on a desktop; nil when there is none -
      FFmpeg's libraries not found, or no player for the platform yet). }
    FPlayer: TReaderPlayer;
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
    { A phone or tablet: the covers are in this box, which a finger
      scrolls (nil on a desktop: they are in recLibrary). Zip 323. }
    FLibScroll: TVertScrollBox;
    { A line at the library's foot: "Reading new books: 3 of 7",
      "Opening <title> ..." (hidden when there is nothing to say). }
    lblLibNote: TLabel;
    { New books found by ScanTranscribed and not read yet (a touch build
      reads them one at a time, the library showing meanwhile). }
    FScanQueue: TArray<string>;
    { How many books that scan found in all. }
    FScanTotal: Integer;
    { The books of FScanQueue read so far, in the order they will show:
      they go into FRecent together when the last one has been read, so
      that the library on the screen changes once and not at every book
      (zip 331). }
    FScanDone: TArray<TRecentBook>;
    { Reads the next book of FScanQueue. }
    tmScan: TTimer;
    { Where the finger went down in FLibScroll (a tap is a press and a
      release near each other; a drag scrolls). }
    FTapAt: TPointF;
    { A touch build: a book is being read in a thread (OpenBook) and is
      not open yet. }
    FOpening: Boolean;
    { The staged open (a touch build, zip 332): a second book component
      and view, over the page, that show ONE document of a book whose
      package only has been read, while OpenBook's thread reads the rest. }
    FPreviewEpub: TEpubUnum;
    { The view of the staged open's page (child of View1, hidden when
      there is none). }
    FPreviewView: TEpubView;
    { FClipFirst and FClipLast were filled by OpenBook's thread for the
      book about to be adopted: EpubUnum1Open does not work them out again. }
    FClipsReady: Boolean;
    { Counts OpenBook's calls: a thread's book is taken only when no other
      book was asked for meanwhile. }
    FOpenTicket: Integer;
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
    { View > Graphics (Windows): Windows decides, power saving GPU, high
      performance GPU - TGpuPreference's order (uInhibit); nil elsewhere. }
    miGpu: array[0..2] of TMenuItem;
    { The cover chooser (thumbnails; uCoverPick). }
    FCoverPick: TCoverPicker;
    { The library: the books opened or found, the latest read first (at
      most LIBRARY_MAX), with their reading positions. File > Recently
      Opened lists the first RECENT_MAX of them. }
    FRecent: TArray<TRecentBook>;
    { The books of EpubBuilder's output folder the library has seen (file
      names, lower case - as RecentIndex matches): ScanTranscribed adds a
      book only once, so one taken off the list stays off. Kept in the
      settings ("seen"). }
    FSeen: TArray<string>;
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
    { The keyboard was used last on the menu, not a pad: its foot names
      keys, not the pad's buttons (SetPadKeys). }
    FPadKeys: Boolean;
    { The menu's foot has left / right's "change" (PadMenuFoot). }
    FFootChange: Boolean;
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
    { Linux (Game Mode): the window brought back after the screen saver or
      a display that was off (uRedraw). }
    FRedraw: TWindowRedraw;
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
    { No books yet (a phone, zip 341): a box like the menu offering a
      link to BookManager or books from the phone's own storage. }
    procedure ShowStartMenu;
    { The library on a phone, empty, with nothing showing over it (a menu
      closed, a note's OK): ShowStartMenu - without a book there is
      nothing else to do (owner, zip 345). }
    procedure OfferBooksIfEmpty;
    { A phone: the library's books whose file is gone (deleted with a file
      manager, over USB) are taken off it - the books folder is the
      library there; the open book too, closed (zip 345). }
    procedure DropMissingBooks;
    { A note in the menu's box, with OK. }
    procedure ShowNote(const ATitle, AText: string);
    { A phone: starts the link (BookManager finds this reader and sends it
      books) and shows its panel. }
    procedure StartLink;
    { Ends the link (Done, the app left, closing). }
    procedure StopLink(const AWhy: string);
    { Deletes the .part files a cut-off transfer left in the Books folder
      (Done or Cancel while a book came: the connection closed before the
      link could). }
    procedure DropPartFiles;
    { The panel's Cancel (and Back): the link ends, the menu it was started
      from shows again. }
    procedure LinkCancel;
    { The link panel: where the link is, the code, the book being
      received, Done (and Refuse with a code). }
    procedure ShowLinkPanel;
    { BookManagers heard: answered directly. }
    procedure LinkFinderChange(Sender: TObject);
    { A book's progress. }
    procedure LinkUploadProgress(const AName, ABatch: string; ADone, ATotal: Int64);
    { A BookManager asks to pair: the code in the panel, with Refuse. }
    procedure LinkPairCode(const AClient, ACode: string);
    { A BookManager was paired: its token kept. }
    procedure LinkPaired(const AClient, AToken: string);
    { The code shown no longer works (five wrong codes). }
    procedure LinkPairEnded(const AClient, AWhy: string);
    { A book arrived: in the library. }
    procedure LinkReceived(const AKind, AFileName: string);
    { A call came to the link (the debug log). }
    procedure LinkRequest(const AText: string);
    { BookManager closed (its goodbye, by a call or on the network): the
      link ends, the panel closes (zip 371). }
    procedure LinkBye(const AText: string);
    { About: the version, when and from what it was built, the copyright
      and the libraries' licences, in the menu's box (zip 343). }
    procedure ShowAbout;
    { Help > About (a desktop's menu): ShowAbout. }
    procedure miAboutClick(Sender: TObject);
    { About > Licences: the outside components of this build
      (uLicences), the one shown last selected (AIndex). }
    procedure ShowLicencesMenu(AIndex: Integer);
    { Component AIndex's licence, page APage (Next page / Back). }
    procedure ShowLicence(AIndex, APage: Integer);
    { The system's folder picker (Android): the books folder chosen - its
      books and its folders' read where they are, the library shows them
      (zip 346; zip 341 copied single files). }
    procedure ChooseBooksFolder;
    { The books folders listed (FFolderBooks): before the library takes
      gone books off and takes new ones in. }
    procedure ListBooksFolders;
    { Book AName is there: a path - the file exists; a books folder's
      address - its folder's last listing has it (a query of each
      document, zip 346, took the book just found for gone: the library
      emptied itself as fast as it filled - owner 15:04, "the screen is
      blank"); not known (a listing failed) - yes. }
    function BookThere(const AName: string): Boolean;
    { Menu > Books folders (Android): the folders chosen (one chosen: what
      to do with it), "Add a folder" (the phone's storage or the memory
      card) and Back. }
    procedure ShowFoldersMenu;
    { Books folder AIndex (FBooksTrees): take it off, or keep it. }
    procedure ShowFolder(AIndex: Integer);
    { Books folder AIndex taken off: its books leave the library (they
      stay where they are), Android forgets its permission. }
    procedure RemoveBooksFolder(AIndex: Integer);
    { Row AIndex of the main menu's value as it reads now (text size,
      speed, on / off).
      @param(AIndex  MENU_RESUME .. MENU_ABOUT)
      @returns(the value; '' for none) }
    function PadMenuValue(AIndex: Integer): string;
    { The hints at the foot of the menu: the pad's own names for choose,
      back and change (the keys without a pad).
      @param(AChange  with left / right's "change")
      @returns(the line) }
    function PadMenuFoot(AChange: Boolean): string;
    { The foot's hints for the pad in hand - Steam's pictures of its
      controls (their names without pictures) - or for the keys (AKeys;
      uReaderInput's table): choose, back, and with FFootChange left /
      right's change (owner's standing rule, 2026-11-22: a PlayStation pad
      has no A or B).
      @returns(the hints) }
    function PadFootHints(AKeys: Boolean): TArray<TPadHint>;
    { The foot of the menu shown drawn as hints (after each Show, and when
      the other way of control is used). }
    procedure RefreshPadFoot;
    { The pad (False) or the keyboard (True) was used on the menu: its foot
      goes over to that one's buttons or keys. }
    procedure SetPadKeys(AKeys: Boolean);
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
    { The chapters as BuildChapters left them at the last opening of this
      book, from the file beside its index - only for a book that came
      from its index (it is the same book then) and when the file is not
      older than the index.
      @returns(@false when they have to be built) }
    function LoadChapters: Boolean;
    { Keeps what BuildChapters made, beside the book's index (nothing when
      the book has no index). }
    procedure SaveChapters;
    { Makes the tool bar's buttons. }
    procedure BuildToolBar;
    { Makes the touch bar (a phone, a tablet). }
    procedure BuildTouchBar;
    { A tap on Text size or Speed in the menu, where there is no left /
      right: one step up, and from the top round to the bottom. AIndex is
      MENU_SIZE or MENU_SPEED. }
    procedure TouchMenuStep(AIndex: Integer);
    { An icon button (Sprite3D's way: a TPath in a TButton). }
    function AddIconButton(const AIcon, AHint: string; AOnClick: TNotifyEvent): TButton;
    { A text button. }
    function AddTextButton(const AText, AHint: string; AOnClick: TNotifyEvent): TButton;
    { An icon takes the colour the style gives the button's text. }
    procedure IconButtonApplyStyle(Sender: TObject);
    { Shows AIcon on button AButton. }
    procedure SetIcon(AButton: TButton; const AIcon: string);
    { Makes the sound player (FSoundNote says what is missing). }
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
    { A unit AUnit (UNIT_*) starts at word AWord. }
    function IsUnitStartOf(AWord, AUnit: Integer): Boolean;
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
    { The staged open: OpenBook's thread has read the package of the book
      (AHeader, ours to keep or free) - its page is shown at once.
      ADoc and AWord: the place kept from last time (-1: the first
      document of the reading order, its top). }
    procedure PreviewReady(AHeader: TEpubBook; ADoc, AWord, ATicket: Integer);
    { The staged open's page goes (the real one is there, or there is
      none). }
    procedure HidePreview;
    { A touch build: the thread of OpenBook has read AFileName - ABook
      (with its text), or nil and why not in AError. ATicket is
      FOpenTicket as it was when the thread was started. }
    procedure OpenDone(const AFileName: string; ABook: TEpubBook; const AError: string; ATicket: Integer;
      const AClipFirst, AClipLast: TArray<Integer>);
    { Reads one book of FScanQueue into the library and shows it; after the
      last one the settings are saved. }
    procedure tmScanTimer(Sender: TObject);
    { One new book into the library: its title read from it, put after the
      book read last - or, with AHold, kept in FScanDone until the whole
      batch has been read (a touch build: the library changes once). }
    procedure AddScanned(const AFileName: string; AHold: Boolean = False);
    { Takes a book that is in the library more than once out of it but for
      its first entry (zip 325 put books in two and three times). }
    procedure DropDoubleBooks;
    { Fills R's Author, AuthorSort, Year and Genre from ABook (open, or its
      package only). }
    procedure SetBookMeta(var R: TRecentBook; ABook: TEpubBook);
    { Reads the details of the library's books that do not have them yet
      (their packages only; books from before zip 340), when the order
      needs them. }
    procedure EnsureLibraryMeta;
    { The library's books in the order shown (indexes into FRecent): the
      one read last first, the others by FLibrarySort. }
    function LibraryOrder: TArray<Integer>;
    { Puts the library in order ASort, keeps it, shows it again when it is
      on the screen. }
    procedure SetLibrarySort(ASort: TLibrarySort);
    { File > Library order > an order (Tag = TLibrarySort). }
    procedure miSortClick(Sender: TObject);
    { Highlights while reading aloud as AUnit says (ATrailing: only up to
      the word; AWord: the word over it in its own colour), keeps it,
      shows it on the word being read. }
    procedure SetHighlight(AUnit: THighlightUnit; ATrailing, AWord: Boolean);
    { View > Highlight > Word / Phrase / Sentence (Tag = THighlightUnit). }
    procedure miHighClick(Sender: TObject);
    { View > Highlight > Trailing. }
    procedure miHighTrailingClick(Sender: TObject);
    { View > Highlight > Word in its own colour. }
    procedure miHighWordClick(Sender: TObject);
    { The desktop's View > Highlight items checked (and the two under the
      line enabled) as the settings say. }
    procedure CheckHighlightMenu;
    { The pad menu's Highlight row stepped ADelta (Word, Phrase,
      Sentence, round). }
    procedure StepHighlight(ADelta: Integer);
    { Highlights the words AFirst..ALast being read (a clip) as FHighUnit,
      FHighTrailing and FHighWord say. }
    procedure ShowReadHighlight(AFirst, ALast: Integer);
    { Cover AIndex (of FRecent) was clicked or tapped: back to the open
      book when it is that one, else it is opened. }
    procedure CoverChosen(AIndex: Integer);
    { The finger down in the touch library. }
    procedure LibScrollMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    { The finger up in the touch library: a tap on a cover chooses it. }
    procedure LibScrollMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    { Shows AText at the library's foot ('' = hides the line). }
    procedure LibraryNote(const AText: string);
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
    { EpubBuilder's output folder (Transcribed) looked through: a book not
      seen there before goes into the library (FRecent) after the book read
      last, the newest first (owner, 2026-11-22: a benchmark's books kept,
      then "Reader had no content"). Called by ShowLibrary.
      @returns(how many were added) }
    function ScanTranscribed: Integer;
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
    { The start of the unit AUnit (UNIT_*) that word AWord is in. }
    function UnitStartOf(AWord, AUnit: Integer): Integer;
    { The last word of the unit AUnit that starts at word AWord. }
    function UnitEndOf(AWord, AUnit: Integer): Integer;
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
  System.Hash, System.UIConsts, System.Skia, System.Generics.Defaults, System.IniFiles,
  FmxWineCanvas, FmxSkiaCanvas, uSteam, uInhibit, uQuitSignal, uReaderInput, uCards;

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
  { Get books from BookManager (a phone: the link and its panel; owner
    18:09, "There's no way to re-open bookmanager in Phone menu" - it was
    only in Books folders; zip 362). Faded elsewhere. }
  MENU_LINK = 2;
  { The library. }
  MENU_LIBRARY = 3;
  { The library's order (a tap, or left / right, steps through them). }
  MENU_SORT = 4;
  { The contents. }
  MENU_CONTENTS = 5;
  { Text size (left / right). }
  MENU_SIZE = 6;
  { Speed (left / right). }
  MENU_SPEED = 7;
  { Dark mode. }
  MENU_DARK = 8;
  { What is highlighted while reading aloud: Word, Phrase, Sentence (a
    tap, or left / right, steps through them; zip 352 / 353). }
  MENU_HIGHLIGHT = 9;
  { Highlight type: All / Trailing (only up to the word); faded with
    Word. }
  MENU_HIGH_TYPE = 10;
  { Highlight word: On / Off (the word over the phrase / sentence in its
    own colour); faded with Word. }
  MENU_HIGH_WORD = 11;
  { Learn to read. }
  MENU_LEARN = 12;
  { The pad's controls. }
  MENU_CONTROLS = 13;
  { The open book's cover (thumbnails to choose from). }
  MENU_COVER = 14;
  { Exit. }
  MENU_EXIT = 15;
  { About: the version and the copyright (the last row; owner, zip 343). }
  MENU_ABOUT = 16;
  { Who holds the copyright, for About - A PLACEHOLDER until the owner
    says (the repository names no holder; WhisperBooks is its GitHub
    organisation). }
  ABOUT_COPYRIGHT = 'Copyright (c) 2026 WhisperBooks. All rights reserved.';
  { The library's orders, as the menus name them. }
  LIBRARY_SORT_NAMES: array[TLibrarySort] of string = ('Recent', 'Title', 'Author', 'Year', 'Genre');
  { ... and as the settings file keeps them. }
  LIBRARY_SORT_KEYS: array[TLibrarySort] of string = ('recent', 'title', 'author', 'year', 'genre');
  { What is highlighted, as the menus name it. }
  HIGHLIGHT_NAMES: array[THighlightUnit] of string = ('Word', 'Phrase', 'Sentence');
  { ... and as the settings file keeps it. }
  HIGHLIGHT_KEYS: array[THighlightUnit] of string = ('word', 'phrase', 'sentence');
  { Highlight type, as the menus name it (False = all of it). }
  HIGHLIGHT_TYPE_NAMES: array[Boolean] of string = ('All', 'Trailing');
  { FMenuMode: the main menu. }
  MODE_MAIN = 0;
  { The contents. }
  MODE_CONTENTS = 1;
  { The controls. }
  MODE_CONTROLS = 2;
  { The books of the books folder. }
  MODE_BOOKS = 3;
  { No books yet (a phone): where books come from (zip 341). }
  MODE_START = 4;
  { A note with one answer, OK (back to what was there). }
  MODE_NOTE = 5;
  { About: OK, Licences (zip 344). }
  MODE_ABOUT = 6;
  { The licences' list (the outside components). }
  MODE_LICENCES = 7;
  { One licence, a page at a time. }
  MODE_LICENCE = 8;
  { The books folders (Android): each one, Add a folder, Back (zip 346). }
  MODE_FOLDERS = 9;
  { One books folder: take it off the library, or keep it. }
  MODE_FOLDER = 10;
  { Linking with BookManager: the panel (zip 357). }
  MODE_LINK = 11;
  { About's rows. }
  ABOUT_OK = 0;
  { ... }
  ABOUT_LICENCES = 1;
  { A licence's page, characters (the menu's box does not scroll: a
    phone shows about this much). }
  LICENCE_PAGE_CHARS = 700;
  { MODE_START's rows. }
  START_LINK = 0;
  { ... }
  START_FOLDER = 1;
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
  { The menu: three lines. }
  ICON_MENU = 'M4 6h16v2H4z M4 11h16v2H4z M4 16h16v2H4z';
  { A page back: an arrow head left. }
  ICON_PAGE_BACK = 'M15 5l2 2-5 5 5 5-2 2-7-7z';
  { A page on: an arrow head right. }
  ICON_PAGE_ON = 'M9 5l7 7-7 7-2-2 5-5-5-5z';
  { Icon box, px. }
  ICON_SIZE = 24;
  { The touch library: a cover is about this wide (the columns come from
    the window's width). }
  TOUCH_COVER_WIDTH = 130;
  { A finger that moved less than this between down and up tapped. }
  TAP_SLOP = 12;
  { A cover that takes longer than this, ms, is told of in the log. }
  SLOW_COVER_MS = 100;
  { The line at the library's foot, its height. }
  LIB_NOTE_HEIGHT = 30;
  { A touch build: the window is drawn once more before a book is opened
    (the library says "Opening ..."), ms. }
  TOUCH_OPEN_DELAY = 120;
  { A touch build: between two new books read into the library, ms - the
    window is drawn in it. }
  SCAN_STEP_MS = 60;
  { The touch bar's height (Android's least for something touched is 48). }
  TOUCH_BAR_HEIGHT = 56;
  { Space round each of the touch bar's buttons. }
  TOUCH_BUTTON_GAP = 3;
  { Text size on a phone: a tap on the menu's row goes up to this ... }
  TOUCH_SIZE_MAX = 40;
  { ... and then round to this. }
  TOUCH_SIZE_MIN = 12;
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
  { Dark mode: the phrase / sentence being read, under the word (a dark
    blue the amber word stands out on). }
  DARK_UNIT_HIGHLIGHT = $FF2A3850;
  { The phrase / sentence being read, under the word (pale blue). }
  UNIT_HIGHLIGHT = $FFDCE8F7;
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
  { Books shown in File > Recently Opened: the first of the library's. }
  RECENT_MAX = 10;
  { Books kept in the library (FRecent). It was RECENT_MAX until zip 325:
    the library grew out of the recent list, and ten was all a phone's
    library could hold (owner: "seems very low"). }
  LIBRARY_MAX = 1000;
  { Added to the window title in Learn to read. }
  LEARN_TITLE = ' - LEARN TO READ';
  { Button width, px. }
  BUTTON_WIDTH = 36;
  { Longest extension kept for an extracted audio file, the dot included. }
  MAX_AUDIO_EXTENSION = 8;

{ @true in a build for a phone, a tablet or a TV box (Android, iOS): no
  menu bar, no mouse, a screen that may be narrow and tall. }
function TouchBuild: Boolean;
begin
  {$IF Defined(ANDROID) or Defined(IOS)}
  Result := True;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

{ @true where the window is the page alone and the pad's menu has the
  rest (Library, Contents, Text size ...): Steam's Big Picture, and a
  phone or tablet - no tool bar across the top, no contents panel beside
  the page. Zip 321: on a phone held upright the contents panel left the
  page one word wide. }
function MenuLayout: Boolean;
begin
  Result := SteamBigPicture or TouchBuild;
end;

{ Where entry AName of AZip lies in the book's file, when it is there as
  it is (stored: EpubBuilder's and most books' audio) - a player that can
  play a part of a file needs no copy of it.
  @param(AOffset  the first byte of the entry's data in the file)
  @param(ASize  its length, bytes)
  @returns(@false when the entry is compressed, encrypted or not there,
    the archive is not a file, or its header cannot be read) }
{ The book file AName to read bytes of: through Epub.Zip's
  EpubStreamOpener when it gives one (a books folder's book on Android:
  its address is no path - zip 350, the owner's debugger: "Cannot create
  file "/content:/com.android..."), else the file. The caller frees it. }
function OpenBookFile(const AName: string): TStream;
begin
  Result := nil;
  if Assigned(EpubStreamOpener) then
    Result := EpubStreamOpener(AName);
  if Result = nil then
    Result := TFileStream.Create(AName, fmOpenRead or fmShareDenyNone);
end;

function AudioInBook(AZip: TEpubZipReader; const AName: string; out AOffset, ASize: Int64): Boolean;
const
  LOCAL_HEADER = 30;
  LOCAL_SIGNATURE = $04034B50;
var
  I: Integer;
  E: TEpubZipEntry;
  F: TStream;
  H: array[0..LOCAL_HEADER - 1] of Byte;
begin
  Result := False;
  AOffset := 0;
  ASize := 0;
  if (AZip = nil) or (AZip.FileName = '') then
    Exit;
  I := AZip.IndexOf(AName);
  if I < 0 then
    Exit;
  E := AZip.Entries[I];
  if (E.Method <> 0) or ((E.Flags and 1) <> 0) or (E.CompressedSize <> E.Size) or (E.Size <= 0) then
    Exit;
  try
    F := OpenBookFile(AZip.FileName);
    try
      F.Position := E.LocalOffset;
      if F.Read(H, LOCAL_HEADER) <> LOCAL_HEADER then
        Exit;
      if (H[0] or (H[1] shl 8) or (H[2] shl 16) or (Cardinal(H[3]) shl 24)) <> LOCAL_SIGNATURE then
        Exit;
      // after the header: the name and the extra field, then the data
      AOffset := E.LocalOffset + LOCAL_HEADER + (H[26] or (H[27] shl 8)) + (H[28] or (H[29] shl 8));
      ASize := E.Size;
      Result := AOffset + ASize <= F.Size;
    finally
      F.Free;
    end;
  except
    // not readable: the caller extracts, and says why if that fails too
    Result := False;
  end;
end;

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

procedure TfrmMain.BuildTouchBar;

  { A button of the bar: AddIconButton's, moved from the tool bar. }
  function Add(const AIcon: string; AOnClick: TNotifyEvent): TButton;
  begin
    Result := AddIconButton(AIcon, '', AOnClick);
    Result.Align := TAlignLayout.None;
    Result.Parent := layTouch;
    Result.Position.X := Length(FTouchButtons) * 1000;
    Result.Align := TAlignLayout.Left;
    Result.Margins.Rect := TRectF.Create(TOUCH_BUTTON_GAP, TOUCH_BUTTON_GAP + 1, TOUCH_BUTTON_GAP,
      TOUCH_BUTTON_GAP + 1);
    Result.ShowHint := False;
    FTouchButtons := FTouchButtons + [Result];
  end;

begin
  layTouch := TLayout.Create(Self);
  layTouch.Parent := Self;
  layTouch.Align := TAlignLayout.Bottom;
  layTouch.Height := TOUCH_BAR_HEIGHT;
  Add(ICON_MENU, btnTouchMenuClick);
  Add(ICON_PAGE_BACK, btnTouchPageBackClick);
  btnTouchPrevClip := Add(ICON_PREVIOUS, btnPrevClipClick);
  btnTouchPlay := Add(ICON_PLAY, btnPlayClick);
  btnTouchNextClip := Add(ICON_NEXT, btnNextClipClick);
  Add(ICON_PAGE_ON, btnTouchPageOnClick);
  layTouch.OnResized := layTouchResized;
  layTouchResized(nil);
end;

procedure TfrmMain.layTouchResized(Sender: TObject);
var
  I: Integer;
  W: Single;
begin
  if (layTouch = nil) or (Length(FTouchButtons) = 0) then
    Exit;
  W := layTouch.Width / Length(FTouchButtons) - 2 * TOUCH_BUTTON_GAP;
  if W < BUTTON_WIDTH then
    W := BUTTON_WIDTH;
  for I := 0 to High(FTouchButtons) do
    FTouchButtons[I].Width := W;
end;

procedure TfrmMain.btnTouchMenuClick(Sender: TObject);
begin
  if FPadMenu = nil then
    Exit;
  if FPadMenu.Showing then
    FPadMenu.Hide
  else
    ShowPadMenu;
end;

procedure TfrmMain.btnTouchPageBackClick(Sender: TObject);
begin
  if (EpubUnum1.Book <> nil) and not LibraryShowing then
    View1.Page(False);
end;

procedure TfrmMain.btnTouchPageOnClick(Sender: TObject);
begin
  if (EpubUnum1.Book <> nil) and not LibraryShowing then
    View1.Page(True);
end;

procedure TfrmMain.TouchMenuStep(AIndex: Integer);
begin
  case AIndex of
    MENU_SIZE:
      if View1.FontSize >= TOUCH_SIZE_MAX then
        View1.FontSize := TOUCH_SIZE_MIN
      else
        View1.FontSize := View1.FontSize + SIZE_STEP;
    MENU_SPEED:
      if tbSpeed.Value >= SPEED_MAX - SPEED_STEP / 2 then
        tbSpeed.Value := SPEED_MIN
      else
        tbSpeed.Value := tbSpeed.Value + SPEED_STEP;
  else
    Exit;
  end;
  FPadMenu.SetValue(AIndex, PadMenuValue(AIndex));
end;

procedure TfrmMain.FormSafeAreaChanged(Sender: TObject; const AInsets: TRectF);
begin
  DebugLog(Format('safe area: the edges lose left %.0f, top %.0f, right %.0f, bottom %.0f', [AInsets.Left,
    AInsets.Top, AInsets.Right, AInsets.Bottom]));
  Padding.Rect := AInsets;
end;

procedure TfrmMain.StartSound;
begin
  DebugLog('sound: making the player');
  try
    // the platform's player (uPlayer): on a desktop any FFmpeg 8 build -
    // GPL or LGPL (owner): the licence is in its description
    FPlayer := ReaderPlayerCreate;
    FSoundNote := FPlayer.Note;
    DebugLog('sound: ' + FPlayer.Description);
    {$IF Defined(POSIX) and not Defined(ANDROID) and not Defined(IOS)}
    WriteLn(ErrOutput, FPlayer.Description);
    {$ENDIF}
  except
    on E: Exception do
    begin
      DebugLog('sound: none - ' + E.Message);
      FreeAndNil(FPlayer);
      FSoundNote := 'No sound: ' + E.Message;
    end;
  end;
end;

{ The settings file (JSON: they will grow), in the EpubUnum settings
  folder shared with EpubBuilder (uEpubUnum): Windows
  %APPDATA%\EpubUnum\EpubReader.json, macOS ~/Library/Application
  Support/EpubUnum/EpubReader.json, Linux $XDG_CONFIG_HOME (else
  ~/.config)/EpubUnum/EpubReader.json. }
{ The folder the program is in - on the Mac the one that holds
  EpubReader.app (ParamStr(0) is inside the signed bundle, which must not
  be written to): Steam's install folder, Manage > Browse local files. }
function ProgramFolder: string;
var
  D: string;
begin
  D := ExtractFileDir(ParamStr(0));
  {$IFDEF MACOS}
  // .../EpubReader.app/Contents/MacOS -> ...
  if SameText(ExtractFileName(D), 'MacOS') and SameText(ExtractFileName(ExtractFileDir(D)), 'Contents') and
    SameText(ExtractFileExt(ExtractFileDir(ExtractFileDir(D))), '.app') then
    D := ExtractFileDir(ExtractFileDir(ExtractFileDir(D)));
  {$ENDIF}
  Result := D;
end;

{ The books folder at first. A Steam build: Books beside the program (on
  the Mac beside EpubReader.app) - a Steam Deck has no file dialog to
  reach anything else, and the folder is easy to find from Steam (Manage
  > Browse local files). Other builds: Documents/EpubReader/Books. Owner,
  2026-11-18; the Mac's Steam build beside the .app, owner 2026-11-19. }
function BooksFolderDefault: string;
begin
  {$IF Defined(STEAMBUILD)}
  Result := System.IOUtils.TPath.Combine(ProgramFolder, 'Books');
  {$ELSE}
  // shared with EpubBuilder (owner, 2026-11-20)
  Result := EpubUnumFolder(EU_BOOKS);
  {$ENDIF}
end;

function SettingsFile: string;
begin
  // the folder shared with EpubBuilder (uEpubUnum; owner, 2026-11-20)
  Result := System.IOUtils.TPath.Combine(EpubUnumConfigFolder, 'EpubReader.json');
end;

{ The cached cover of book ABookFile: covers\<MD5 of the file name>.png
  beside the settings file. By the file NAME, as the recent list matches
  books (a moved book keeps its cover); the user may replace the picture. }
function CoverFile(const ABookFile: string): string;
begin
  Result := System.IOUtils.TPath.Combine(System.IOUtils.TPath.Combine(ExtractFilePath(SettingsFile), 'covers'),
    THashMD5.GetHashString(LowerCase(BookFileName(ABookFile))) + '.png');
end;

{ The index of book ABookFile (TEpubBook.SaveIndex: its words and clips
  ready to read, so that it is not parsed again at every opening):
  index\<MD5 of the file name>.euix beside the settings file. By the file
  NAME, as the covers; the index itself knows whether it is still this
  book's. }
function BookIndexFile(const ABookFile: string): string;
begin
  Result := System.IOUtils.TPath.Combine(System.IOUtils.TPath.Combine(ExtractFilePath(SettingsFile), 'index'),
    THashMD5.GetHashString(LowerCase(BookFileName(ABookFile))) + '.euix');
end;

{ Opens ABookFile in full, with its text - from its index when it has one
  that fits, else from the book, writing the index for next time. Touches
  nothing of the window: for a thread. APath: where to read it (the same
  but for a book of the chosen folder: BookOpenPath's, made in the
  window's thread).
  @param(ANote  what was done, for the debug log)
  @returns(the book; the caller frees it)
  @raises(Exception as TEpubBook.Create) }
function OpenBookIndexed(const ABookFile, APath: string; out ANote: string): TEpubBook;
var
  IndexFile: string;
  M: TMemoryStream;
begin
  Result := nil;
  ANote := '';
  IndexFile := BookIndexFile(ABookFile);
  M := TMemoryStream.Create;
  try
    try
      if FileExists(IndexFile) then
      begin
        M.LoadFromFile(IndexFile);
        M.Position := 0;
        Result := TEpubBook.CreateIndexed(APath, M);
        if Result.FromIndex then
          ANote := Format('open: from its index (%d bytes) - the book''s XML was not read', [M.Size])
        else
          ANote := 'open: its index does not fit (the book changed, or another version) - read in full';
      end
      else
        Result := TEpubBook.Create(APath);
      Result.LoadText;
      if not Result.FromIndex then
        try
          M.Clear;
          Result.SaveIndex(M);
          ForceDirectories(ExtractFilePath(IndexFile));
          M.SaveToFile(IndexFile);
          if ANote = '' then
            ANote := 'open: read in full';
          ANote := ANote + Format('; index written for next time (%d bytes)', [M.Size]);
        except
          on E: Exception do
          begin
            // no index: the book opens as slowly next time
            System.SysUtils.DeleteFile(IndexFile);
            ANote := ANote + '; index NOT written - ' + E.Message;
          end;
        end;
    except
      FreeAndNil(Result);
      raise;
    end;
  finally
    M.Free;
  end;
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
  Held: Boolean;
begin
  Held := False;
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
      // (a books folder's book: tried - a failure is a made cover, below;
      // BookThere is the form's, this runs without it)
      if (ABook = nil) and (IsBookAddress(ABookFile) or FileExists(ABookFile)) then
        try
          // the package only: a cover needs no timings (zip 324); a book
          // of the chosen folder through the file Android opens (released
          // below only when it was opened here)
          BookOpenPath(ABookFile);
          Held := True;
          Own := TEpubBook.CreateHeader(ABookFile);
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
        Title := ChangeFileExt(BookFileName(ABookFile), '');
      SaveTextCover(F, Title, Author);
    except
      // no cover: the library shows the title
    end;
  finally
    Own.Free;
    if Held then
      BookRelease(ABookFile);
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
  Exe: string;
  {$IF Defined(MSWINDOWS) or Defined(LINUX)}
  Command: string;
  {$ENDIF}
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
  M, S: TMenuItem;
  Sort: TLibrarySort;
  High_: THighlightUnit;
  Bar: TFmxObject;
  {$IFDEF MSWINDOWS}
  G: TMenuItem;
  I: Integer;
  {$ENDIF}
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
  if not MenuLayout then
    mnuMain.Parent := Self;
  Bar := mnuMain;
  {$ENDIF}
  M := Item(Bar, '&File', nil);
  Item(M, '&Open...'#9'Ctrl+O', btnOpenClick);
  Item(M, 'Li&brary', miLibraryClick);
  S := Item(M, 'Library &order', nil);
  for Sort := Low(TLibrarySort) to High(TLibrarySort) do
  begin
    miSort[Sort] := Item(S, '&' + LIBRARY_SORT_NAMES[Sort], miSortClick);
    miSort[Sort].Tag := Ord(Sort);
    miSort[Sort].IsChecked := Sort = FLibrarySort;
  end;
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
  S := Item(M, '&Highlight', nil);
  for High_ := Low(THighlightUnit) to High(THighlightUnit) do
  begin
    miHigh[High_] := Item(S, '&' + HIGHLIGHT_NAMES[High_], miHighClick);
    miHigh[High_].Tag := Ord(High_);
  end;
  Item(S, '-', nil);
  miHighTrailing := Item(S, '&Trailing (up to the word)', miHighTrailingClick);
  miHighWord := Item(S, 'W&ord in its own colour', miHighWordClick);
  CheckHighlightMenu;
  Item(M, '-', nil);
  Item(M, '&Larger text'#9'Ctrl+Plus', btnLargerClick);
  Item(M, '&Smaller text'#9'Ctrl+Minus', btnSmallerClick);
  Item(M, '-', nil);
  Item(M, '&Cover of this book...', miCoverClick);
  M := Item(Bar, '&Help', nil);
  Item(M, '&About EpubReader...', miAboutClick);
  {$IFDEF MSWINDOWS}
  // which GPU draws the page on a laptop with two: Windows' own setting
  // (Settings > System > Display > Graphics), read when the program starts
  Item(M, '-', nil);
  G := Item(M, '&Graphics (from the next start)', nil);
  miGpu[0] := Item(G, '&Windows decides', miGpuClick);
  miGpu[1] := Item(G, '&Power saving GPU', miGpuClick);
  miGpu[2] := Item(G, '&High performance GPU', miGpuClick);
  for I := 0 to 2 do
  begin
    miGpu[I].Tag := I;
    miGpu[I].IsChecked := Ord(GpuPreference) = I;
  end;
  {$ENDIF}
  BuildRecentMenu;
  // a menu made in code reaches the window (Windows' / macOS' own menu
  // bar) only when it is recreated - without this there was no menu
  RefreshMenu;
end;

procedure TfrmMain.miCoverClick(Sender: TObject);
begin
  ShowCoverChoice;
end;

procedure TfrmMain.ShowCoverChoice;
var
  B: TEpubBook;
  Options, More: TCoverOptionArray;
  O: TCoverOption;
  P, I, NameLen, ExtraLen: Integer;
  F: TStream;
  W: TStreamWindow;
  H: TBytes;
  E: TEpubZipEntry;
  NoAudio: TStringList;
  Audio: TStringList;
  Title: string;
begin
  B := EpubUnum1.Book;
  if (B = nil) or (FBookFile = '') then
  begin
    ShowMessage('Open a book first: its covers are shown then.');
    Exit;
  end;
  Options := nil;
  Title := B.Title;
  // its own
  if B.CoverPath <> '' then
    try
      O.Data := B.ReadResource(B.CoverPath);
      if PictureType(O.Data) <> '' then
      begin
        O.Choice := 'book';
        O.Caption := 'The book''s own';
        Options := Options + [O];
      end;
    except
      on Ex: Exception do
        DebugLog('cover: the book''s picture - ' + Ex.Message);
    end;
  // the audiobook's: an audio file stored in the book, read where it lies
  Audio := B.AudioFiles;
  try
    for I := 0 to Audio.Count - 1 do
    begin
      P := B.Zip.IndexOf(Audio[I]);
      if P < 0 then
        Continue;
      E := B.Zip.Entries[P];
      // stored only (a book's audio is never compressed by EpubBuilder)
      if E.Method <> 0 then
        Continue;
      try
        F := OpenBookFile(B.FileName);
        try
          SetLength(H, 30);
          F.Position := E.LocalOffset;
          F.ReadBuffer(H[0], 30);
          NameLen := H[26] or (H[27] shl 8);
          ExtraLen := H[28] or (H[29] shl 8);
          W := TStreamWindow.Create(F, E.LocalOffset + 30 + NameLen + ExtraLen, E.Size);
          try
            if AudioCoverStream(W, ExtractFileExt(Audio[I]), O.Data) then
            begin
              O.Choice := 'audio';
              O.Caption := 'The audiobook''s';
              Options := Options + [O];
            end;
          finally
            W.Free;
          end;
        finally
          F.Free;
        end;
      except
        on Ex: Exception do
          DebugLog('cover: the audio''s picture - ' + Ex.Message);
      end;
      if (Length(Options) > 0) and (Options[High(Options)].Choice = 'audio') then
        Break;
    end;
  finally
    Audio.Free;
  end;
  // the shared Covers folder's pictures (those named as the book first)
  NoAudio := TStringList.Create;
  try
    More := CoverOptions(EpubUnumFolder(EU_COVERS), [ChangeFileExt(BookFileName(FBookFile), ''), Title], nil,
      NoAudio);
  finally
    NoAudio.Free;
  end;
  Options := Options + More;
  if Length(Options) = 0 then
  begin
    ShowMessage('This book has no pictures to choose from. Put one in ' + EpubUnumFolder(EU_COVERS) +
      ', named as the book, and choose again.');
    Exit;
  end;
  if FCoverPick = nil then
    if SteamBigPicture then
      FCoverPick := TCoverPicker.Create(Self, 1.5)
    else
      FCoverPick := TCoverPicker.Create(Self, 1);
  FCoverPick.Show(Format('Cover of %s (in the library; pictures in %s are offered too)', [Title,
    EpubUnumFolder(EU_COVERS)]), '', Options, '',
    procedure(const AChoice: string)
    var
      X: TCoverOption;
      Cache: string;
    begin
      Cache := CoverFile(FBookFile);
      try
        if AChoice = 'book' then
        begin
          // its own again: the cache made afresh from the book
          if FileExists(Cache) then
            System.SysUtils.DeleteFile(Cache);
          EnsureCover(FBookFile, EpubUnum1.Book, Title);
        end
        else
          for X in Options do
            if X.Choice = AChoice then
            begin
              ForceDirectories(ExtractFilePath(Cache));
              SaveImageCover(X.Data, Cache);
              Break;
            end;
        DebugLog('cover: ' + CoverChoiceText(AChoice) + ' for ' + FBookFile);
      except
        on Ex: Exception do
          ShowMessage('The cover was not changed: ' + Ex.Message);
      end;
    end);
end;

procedure TfrmMain.miGpuClick(Sender: TObject);
var
  I, P: Integer;
begin
  P := TMenuItem(Sender).Tag;
  if SetGpuPreference(TGpuPreference(P)) then
  begin
    for I := 0 to 2 do
      if miGpu[I] <> nil then
        miGpu[I].IsChecked := I = P;
    DebugLog('graphics preference: ' + TMenuItem(Sender).Text + ' (from the next start)');
    ShowMessage('Windows uses this graphics choice from the next start of EpubReader.');
  end
  else
    ShowMessage('The graphics choice could not be stored (the registry could not be written).');
end;

procedure TfrmMain.FormActivated(Sender: TObject);
begin
  FRedraw.Activated;
end;

procedure TfrmMain.FormDeactivated(Sender: TObject);
begin
  FRedraw.Deactivated;
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
  for I := 0 to Min(High(FRecent), RECENT_MAX - 1) do
  begin
    M := TMenuItem.Create(Self);
    M.Parent := miRecent;
    if FRecent[I].Title <> '' then
      M.Text := Format('&%d  %s  (%s)', [(I + 1) mod 10, FRecent[I].Title, BookFileName(FRecent[I].FileName)])
    else
      M.Text := Format('&%d  %s', [(I + 1) mod 10, BookFileName(FRecent[I].FileName)]);
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
  if not BookThere(FRecent[AIndex].FileName) then
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
  {$IFDEF ANDROID}
  // nothing: an empty library offers BookManager or the phone's own
  // storage in a box like the menu (ShowStartMenu; owner, zip 341)
  lblLibrary.Text := '';
  {$ELSE}
  lblLibrary.Text := 'No books yet: File > Open... (Ctrl+O) to read one.';
  {$ENDIF}
  lblLibrary.HitTest := False;
  tmLibrary := TTimer.Create(Self);
  tmLibrary.Enabled := False;
  tmLibrary.Interval := 1;
  tmLibrary.OnTimer := tmLibraryTimer;
  // what is going on, at the foot
  lblLibNote := TLabel.Create(Self);
  lblLibNote.Parent := recLibrary;
  lblLibNote.Align := TAlignLayout.Bottom;
  lblLibNote.Height := LIB_NOTE_HEIGHT;
  lblLibNote.StyledSettings := lblLibNote.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  lblLibNote.TextSettings.Font.Size := 14;
  lblLibNote.TextSettings.HorzAlign := TTextAlign.Center;
  lblLibNote.HitTest := False;
  lblLibNote.Visible := False;
  tmScan := TTimer.Create(Self);
  tmScan.Enabled := False;
  tmScan.Interval := SCAN_STEP_MS;
  tmScan.OnTimer := tmScanTimer;
  if TouchBuild then
  begin
    // the covers fill the width and a finger scrolls them
    FLibScroll := TVertScrollBox.Create(Self);
    FLibScroll.Parent := recLibrary;
    FLibScroll.Align := TAlignLayout.Client;
    FLibScroll.OnMouseDown := LibScrollMouseDown;
    FLibScroll.OnMouseUp := LibScrollMouseUp;
    tmLibrary.Interval := TOUCH_OPEN_DELAY;
  end;
end;

{$IFDEF ANDROID}
function TfrmMain.AppEvent(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;
begin
  Result := False;
  if AAppEvent = TApplicationEvent.BecameActive then
  begin
    DebugLog('app: in front again');
    if LibraryShowing and not tmLibrary.Enabled and not FOpening then
      ShowLibrary;
  end
  else if AAppEvent in [TApplicationEvent.WillBecomeInactive, TApplicationEvent.EnteredBackground] then
  begin
    // The system ends an app that is not in front without closing it
    // (FormClose never runs): the place in the book and the library are
    // kept whenever the app is left. Zip 323 - until now nothing was
    // kept on a phone at all, so every start read every book again and
    // the library was in the folder's order, not the order read.
    RememberBook;
    SaveSettings;
    DebugLog('app: left - place and settings saved');
    // not in front: Android takes the network away (the announcement
    // failed with Socket Error # 1 while the phone slept, 16:53) - the
    // link ends; Get books from BookManager starts it again
    if FLink <> nil then
      StopLink('the app was left');
  end;
end;
{$ENDIF}

function TfrmMain.LibraryShowing: Boolean;
begin
  Result := (recLibrary <> nil) and recLibrary.Visible;
end;

procedure TfrmMain.ShowLibrary;
var
  I, K: Integer;
  Img: TImage;
  F: string;
  Tick: Cardinal;
  Order: TArray<Integer>;
begin
  DebugLog('library: showing');
  // the book stops (paused: Play resumes it once back on the page), and the
  // contents panel, which means nothing here, goes (owner)
  StopPlaying;
  lbToc.Visible := False;
  Splitter1.Visible := False;
  // the open book first, with where it is
  RememberBook;
  DropDoubleBooks;
  if TouchBuild then
  begin
    ListBooksFolders;
    DropMissingBooks;
  end;
  // EpubBuilder's books not seen before: into the library
  ScanTranscribed;
  for I := 0 to High(FCoverImages) do
    FCoverImages[I].Free;
  FCoverImages := nil;
  // in the chosen order (the book read last first); the covers' Tag is
  // still the index in FRecent
  if FLibrarySort <> lsRecent then
    EnsureLibraryMeta;
  Order := LibraryOrder;
  for K := 0 to High(Order) do
  begin
    I := Order[K];
    Tick := TThread.GetTickCount;
    EnsureCover(FRecent[I].FileName, nil, FRecent[I].Title);
    // one cover held the window for four seconds at two starts
    // (2026-11-26, a different book each time): which part, next time
    if TThread.GetTickCount - Tick > SLOW_COVER_MS then
      DebugLog(Format('library: SLOW - making sure of that cover took %d ms', [TThread.GetTickCount - Tick]));
    Img := TImage.Create(Self);
    if FLibScroll <> nil then
      Img.Parent := FLibScroll
    else
      Img.Parent := recLibrary;
    Img.WrapMode := TImageWrapMode.Fit;
    // in the touch library the box under the covers takes the finger: a
    // drag scrolls, a tap is found there (LibScrollMouseUp)
    Img.HitTest := FLibScroll = nil;
    Img.Cursor := crHandPoint;
    Img.Tag := I;
    Img.Hint := FRecent[I].Title;
    if Img.Hint = '' then
      Img.Hint := BookFileName(FRecent[I].FileName);
    // what the orders go by (a desktop shows it over the cover)
    if FRecent[I].Author <> '' then
      Img.Hint := Img.Hint + ' - ' + FRecent[I].Author;
    if FRecent[I].Year > 0 then
      Img.Hint := Img.Hint + Format(' (%d)', [FRecent[I].Year]);
    if FRecent[I].Genre <> '' then
      Img.Hint := Img.Hint + ' - ' + FRecent[I].Genre;
    Img.ShowHint := True;
    Img.OnClick := CoverClick;
    F := CoverFile(FRecent[I].FileName);
    Tick := TThread.GetTickCount;
    if FileExists(F) then
      try
        Img.Bitmap.LoadFromFile(F);
      except
        // a damaged cache file: made again next time
        System.SysUtils.DeleteFile(F);
      end;
    if TThread.GetTickCount - Tick > SLOW_COVER_MS then
      DebugLog(Format('library: SLOW - loading that cover''s picture took %d ms (%s)', [TThread.GetTickCount - Tick,
        F]));
    // a book no longer there: faint (a click takes it off the list)
    if not BookThere(FRecent[I].FileName) then
      Img.Opacity := 0.35;
    FCoverImages := FCoverImages + [Img];
  end;
  lblLibrary.Visible := (Length(FRecent) = 0) and (Length(FScanQueue) = 0);
  recLibrary.Fill.Color := View1.BackgroundColor;
  lblLibrary.TextSettings.FontColor := View1.TextColor;
  lblLibNote.TextSettings.FontColor := View1.TextColor;
  // (the line stays while books are being copied in: it says how far)
  if Length(FScanQueue) = 0 then
    LibraryNote('');
  recLibrary.Visible := True;
  recLibrary.BringToFront;
  // the pad's choice: none until the pad moves it
  FCoverSel := -1;
  LayoutLibrary;
  UpdateControls;
  // a phone with no books: where they come from (not while books are
  // being read or copied in, nor over a menu already showing)
  OfferBooksIfEmpty;
end;

procedure TfrmMain.OfferBooksIfEmpty;
begin
  if TouchBuild and LibraryShowing and (Length(FRecent) = 0) and (Length(FScanQueue) = 0) and
    (FPadMenu <> nil) and not FPadMenu.Showing then
    ShowStartMenu;
end;

procedure TfrmMain.DropMissingBooks;
var
  I, N: Integer;
begin
  N := 0;
  for I := High(FRecent) downto 0 do
    if not BookThere(FRecent[I].FileName) then
    begin
      DebugLog('library: ' + FRecent[I].FileName + ' is gone - taken off');
      // the open book itself: closed (its file is no more)
      if (FBookFile <> '') and SameFileName(FBookFile, FRecent[I].FileName) then
      begin
        StopPlaying;
        EpubUnum1.Active := False;
        View1.Clear;
        FBookFile := '';
      end;
      Delete(FRecent, I, 1);
      Inc(N);
    end;
  if N = 0 then
    Exit;
  BuildRecentMenu;
  SaveSettings;
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
  // Picture or on a phone: the menu has the contents)
  if not MenuLayout then
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
  if lblLibNote.Visible then
    AreaH := AreaH - LIB_NOTE_HEIGHT;
  if FLibScroll <> nil then
  begin
    // A phone or tablet (zip 323; owner: "needs to adapt to screen
    // width"): the columns come from the width, the rows scroll. The
    // large cover is never taller than the window, so on a screen held
    // sideways the covers are smaller and more of them go across.
    Cols := Max(3, Trunc(AreaW / TOUCH_COVER_WIDTH));
    W := (AreaW - (Cols + 1) * COVER_GAP) / Cols;
    BestW := ((AreaH - 3 * COVER_GAP) / 2) / COVER_ASPECT;
    if (BestW > 1) and (W > BestW) then
    begin
      W := BestW;
      Cols := Max(3, Trunc((AreaW - COVER_GAP) / (W + COVER_GAP)));
    end;
    if W <= 1 then
      Exit;
    TileH := W * COVER_ASPECT;
    X0 := (AreaW - (Cols * W + (Cols - 1) * COVER_GAP)) / 2;
    Y0 := COVER_GAP;
  end
  else
  begin
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
  end;
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
  CoverChosen(I);
end;

procedure TfrmMain.CoverChosen(AIndex: Integer);
var
  I: Integer;
  Name: string;
begin
  I := AIndex;
  if (I < 0) or (I > High(FRecent)) or tmLibrary.Enabled or FOpening then
    Exit;
  // a tap meant for the menu box (a second tap on Done, as it closed)
  // opens nothing: the box shows, or closed a moment ago (owner 18:40:
  // "It opened a book - don't know which one")
  if (FPadMenu <> nil) and (FPadMenu.Showing or (TThread.GetTickCount64 - FPadMenu.HiddenAt < 700)) then
  begin
    DebugLog('library: a tap just after the menu closed - no book opened');
    Exit;
  end;
  // the open book: back to it, where it was
  if (EpubUnum1.Book <> nil) and (FBookFile <> '') and
    ((IsBookAddress(FRecent[I].FileName) and SameText(FRecent[I].FileName, FBookFile)) or
    (not IsBookAddress(FRecent[I].FileName) and SameFileName(ExpandFileName(FRecent[I].FileName), FBookFile))) then
  begin
    HideLibrary;
    Exit;
  end;
  // opened from a timer: the click must not free its own image (the book
  // opening ends in HideLibrary)
  FLibraryOpen := I;
  if TouchBuild then
  begin
    // Reading a book takes seconds in which nothing moves (owner,
    // 2026-11-25: "this also needs disguising"): the other covers fade
    // and the foot says what is being done; the timer leaves the window
    // time to be drawn so before the book is read.
    for I := 0 to High(FCoverImages) do
      if FCoverImages[I].Tag <> AIndex then
        FCoverImages[I].Opacity := 0.25;
    Name := FRecent[AIndex].Title;
    if Name = '' then
      Name := ChangeFileExt(BookFileName(FRecent[AIndex].FileName), '');
    LibraryNote('Opening ' + Name + ' ...');
  end;
  tmLibrary.Enabled := True;
end;

procedure TfrmMain.tmLibraryTimer(Sender: TObject);
begin
  tmLibrary.Enabled := False;
  OpenRecent(FLibraryOpen);
  // not opened and not being opened (the library still shows): as it was
  if TouchBuild and LibraryShowing and not FOpening then
    ShowLibrary;
end;

procedure TfrmMain.LibraryNote(const AText: string);
var
  Was: Boolean;
begin
  if lblLibNote = nil then
    Exit;
  Was := lblLibNote.Visible;
  lblLibNote.Text := AText;
  lblLibNote.Visible := AText <> '';
  if lblLibNote.Visible then
    lblLibNote.BringToFront;
  // the covers keep clear of the line
  if (Was <> lblLibNote.Visible) and (FLibScroll = nil) then
    LayoutLibrary;
end;

procedure TfrmMain.LibScrollMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  FTapAt := PointF(X, Y);
end;

procedure TfrmMain.LibScrollMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  I: Integer;
  P: TPointF;
begin
  if (Abs(X - FTapAt.X) > TAP_SLOP) or (Abs(Y - FTapAt.Y) > TAP_SLOP) then
    Exit;
  // the covers' places are the scrolled content's
  P := PointF(X + FLibScroll.ViewportPosition.X, Y + FLibScroll.ViewportPosition.Y);
  for I := 0 to High(FCoverImages) do
    if FCoverImages[I].BoundsRect.Contains(P) then
    begin
      CoverChosen(FCoverImages[I].Tag);
      Exit;
    end;
end;

{ AName as sorted: 'Isaac Asimov' -> 'Asimov, Isaac' (a name with a
  comma is taken as it is; Jr., Sr., II, III stay with the surname). }
function AuthorSortOf(const AName: string): string;
var
  Words: TArray<string>;
  Last, Rest, Tail: string;
  N, I: Integer;
begin
  Result := Trim(AName);
  if (Result = '') or (Pos(',', Result) > 0) then
    Exit;
  Words := Result.Split([' '], TStringSplitOptions.ExcludeEmpty);
  N := Length(Words);
  if N < 2 then
    Exit;
  Last := Words[N - 1];
  Tail := UpperCase(Last.TrimRight(['.', ',']));
  if (N > 2) and ((Tail = 'JR') or (Tail = 'SR') or (Tail = 'II') or (Tail = 'III') or (Tail = 'IV')) then
  begin
    Dec(N);
    Last := Words[N - 1] + ' ' + Last;
  end;
  Rest := '';
  for I := 0 to N - 2 do
    if Rest = '' then
      Rest := Words[I]
    else
      Rest := Rest + ' ' + Words[I];
  Result := Last + ', ' + Rest;
end;

{ The year in a dc:date ('1951', '2012-03-01', 'March 1951'): its first
  four digits in a row, 0 when none. }
function YearOf(const ADate: string): Integer;
var
  I: Integer;
begin
  for I := 1 to Length(ADate) - 3 do
    if CharInSet(ADate[I], ['0'..'9']) and CharInSet(ADate[I + 1], ['0'..'9']) and
      CharInSet(ADate[I + 2], ['0'..'9']) and CharInSet(ADate[I + 3], ['0'..'9']) then
      Exit(StrToIntDef(Copy(ADate, I, 4), 0));
  Result := 0;
end;

{ Two sort keys, an empty one after anything (a book without that detail
  goes last), else without case. }
function CompareSortKeys(const X, Y: string): Integer;
begin
  if (X = '') <> (Y = '') then
    Exit(Ord(X = '') - Ord(Y = ''));
  Result := CompareText(X, Y);
end;

{ A title as sorted: without case, and without a leading The / A / An. }
function TitleSortOf(const ATitle: string): string;
begin
  Result := LowerCase(Trim(ATitle));
  if Result.StartsWith('the ') then
    Result := Copy(Result, 5, MaxInt)
  else if Result.StartsWith('an ') then
    Result := Copy(Result, 4, MaxInt)
  else if Result.StartsWith('a ') then
    Result := Copy(Result, 3, MaxInt);
end;

procedure TfrmMain.SetBookMeta(var R: TRecentBook; ABook: TEpubBook);
var
  I: Integer;
begin
  R.Author := '';
  for I := 0 to ABook.Creators.Count - 1 do
    if R.Author = '' then
      R.Author := ABook.Creators[I]
    else
      R.Author := R.Author + ', ' + ABook.Creators[I];
  if ABook.CreatorFileAs <> '' then
    R.AuthorSort := ABook.CreatorFileAs
  else if ABook.Creators.Count > 0 then
    R.AuthorSort := AuthorSortOf(ABook.Creators[0])
  else
    R.AuthorSort := '';
  R.Year := YearOf(ABook.Date);
  if ABook.Subjects.Count > 0 then
    R.Genre := ABook.Subjects[0]
  else
    R.Genre := '';
  R.Meta := True;
end;

procedure TfrmMain.EnsureLibraryMeta;
var
  I, N: Integer;
  Tick: Cardinal;
  Book: TEpubBook;
  Held: Boolean;
begin
  N := 0;
  Tick := TThread.GetTickCount;
  for I := 0 to High(FRecent) do
    if not FRecent[I].Meta and BookThere(FRecent[I].FileName) then
    begin
      Book := nil;
      Held := False;
      try
        try
          BookOpenPath(FRecent[I].FileName);
          Held := True;
          Book := TEpubBook.CreateHeader(FRecent[I].FileName);
          SetBookMeta(FRecent[I], Book);
          Inc(N);
        except
          on E: Exception do
          begin
            DebugLog('library: ' + FRecent[I].FileName + ' - its details not read: ' + E.Message);
            // not tried again at every showing
            FRecent[I].Meta := True;
          end;
        end;
      finally
        Book.Free;
        if Held then
          BookRelease(FRecent[I].FileName);
      end;
    end;
  if N = 0 then
    Exit;
  DebugLog(Format('library: the details of %d book(s) read for the order (%d ms)', [N,
    TThread.GetTickCount - Tick]));
  SaveSettings;
end;

function TfrmMain.LibraryOrder: TArray<Integer>;
var
  I: Integer;
  Rest: TArray<Integer>;
begin
  SetLength(Result, Length(FRecent));
  for I := 0 to High(Result) do
    Result[I] := I;
  if (FLibrarySort = lsRecent) or (Length(Result) < 3) then
    Exit;
  // the book read last stays first (its large cover): the rest in order
  Rest := Copy(Result, 1, MaxInt);
  TArray.Sort<Integer>(Rest, TComparer<Integer>.Construct(
    function(const A, B: Integer): Integer
    var
      RA, RB: TRecentBook;
      TA, TB: string;
    begin
      RA := FRecent[A];
      RB := FRecent[B];
      TA := RA.Title;
      if TA = '' then
        TA := BookFileName(RA.FileName);
      TB := RB.Title;
      if TB = '' then
        TB := BookFileName(RB.FileName);
      Result := 0;
      case FLibrarySort of
        lsAuthor:
          Result := CompareSortKeys(RA.AuthorSort, RB.AuthorSort);
        lsYear:
          if (RA.Year = 0) <> (RB.Year = 0) then
            Result := Ord(RA.Year = 0) - Ord(RB.Year = 0)
          else
            Result := RA.Year - RB.Year;
        lsGenre:
          Result := CompareSortKeys(RA.Genre, RB.Genre);
      end;
      // then by author (a year's or a genre's books), then by title
      if (Result = 0) and (FLibrarySort in [lsYear, lsGenre]) then
        Result := CompareSortKeys(RA.AuthorSort, RB.AuthorSort);
      if Result = 0 then
        Result := CompareText(TitleSortOf(TA), TitleSortOf(TB));
      // the same: as last opened
      if Result = 0 then
        Result := A - B;
    end));
  for I := 0 to High(Rest) do
    Result[I + 1] := Rest[I];
end;

procedure TfrmMain.SetLibrarySort(ASort: TLibrarySort);
var
  Sort: TLibrarySort;
begin
  FLibrarySort := ASort;
  DebugLog('library: in order of ' + LIBRARY_SORT_KEYS[ASort]);
  for Sort := Low(TLibrarySort) to High(TLibrarySort) do
    if miSort[Sort] <> nil then
      miSort[Sort].IsChecked := Sort = FLibrarySort;
  SaveSettings;
  // shown again in the new order (not while a book is being opened)
  if LibraryShowing and not FOpening then
    ShowLibrary;
end;

procedure TfrmMain.miSortClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    SetLibrarySort(TLibrarySort(TMenuItem(Sender).Tag));
end;

procedure TfrmMain.CheckHighlightMenu;
var
  U: THighlightUnit;
begin
  for U := Low(THighlightUnit) to High(THighlightUnit) do
    if miHigh[U] <> nil then
      miHigh[U].IsChecked := U = FHighUnit;
  // with the word alone, the other two say nothing
  if miHighTrailing <> nil then
  begin
    miHighTrailing.IsChecked := FHighTrailing;
    miHighTrailing.Enabled := FHighUnit <> huWord;
  end;
  if miHighWord <> nil then
  begin
    miHighWord.IsChecked := FHighWord;
    miHighWord.Enabled := FHighUnit <> huWord;
  end;
end;

procedure TfrmMain.SetHighlight(AUnit: THighlightUnit; ATrailing, AWord: Boolean);
const
  YES_NO: array[Boolean] of string = ('no', 'yes');
begin
  FHighUnit := AUnit;
  FHighTrailing := ATrailing;
  FHighWord := AWord;
  FHiUnit := -1;
  DebugLog(Format('highlight: %s, trailing %s, word %s', [HIGHLIGHT_KEYS[AUnit], YES_NO[ATrailing],
    YES_NO[AWord]]));
  CheckHighlightMenu;
  SaveSettings;
  // the word being read (or where Play starts) in the new way
  if (EpubUnum1.Book <> nil) and not FLearn and (FClip >= 0) and (FClip < Length(FClipFirst)) and
    (FClipFirst[FClip] >= 0) then
    ShowReadHighlight(FClipFirst[FClip], FClipLast[FClip]);
end;

procedure TfrmMain.miHighClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    SetHighlight(THighlightUnit(TMenuItem(Sender).Tag), FHighTrailing, FHighWord);
end;

procedure TfrmMain.StepHighlight(ADelta: Integer);
var
  Was: THighlightUnit;
begin
  Was := FHighUnit;
  SetHighlight(THighlightUnit((Ord(FHighUnit) + ADelta + Ord(High(THighlightUnit)) + 1) mod
    (Ord(High(THighlightUnit)) + 1)), FHighTrailing, FHighWord);
  // to or from the word alone: the two rows under it faded or not - the
  // menu made again, on this row
  if (Was = huWord) <> (FHighUnit = huWord) then
  begin
    ShowPadMenu;
    FPadMenu.Move(MENU_HIGHLIGHT);
  end
  else
    FPadMenu.SetValue(MENU_HIGHLIGHT, PadMenuValue(MENU_HIGHLIGHT));
end;

procedure TfrmMain.miHighTrailingClick(Sender: TObject);
begin
  SetHighlight(FHighUnit, not FHighTrailing, FHighWord);
end;

procedure TfrmMain.miHighWordClick(Sender: TObject);
begin
  SetHighlight(FHighUnit, FHighTrailing, not FHighWord);
end;

procedure TfrmMain.ShowReadHighlight(AFirst, ALast: Integer);
const
  { Each choice's unit, -1 = the word alone. }
  UNIT_OF: array[THighlightUnit] of Integer = (-1, UNIT_PHRASE, UNIT_SENTENCE);
var
  U, First, Last: Integer;
begin
  U := UNIT_OF[FHighUnit];
  // the word alone (and Learn to read has its own highlighting)
  if (U < 0) or FLearn or (AFirst < 0) then
  begin
    View1.HighlightUnit(-1, -1);
    View1.Highlight(AFirst, ALast);
    Exit;
  end;
  // the phrase / sentence: looked for only when the word has left the
  // last one
  if (U <> FHiUnit) or (AFirst < FHiFirst) or (AFirst > FHiLast) then
  begin
    FHiFirst := UnitStartOf(AFirst, U);
    FHiLast := UnitEndOf(FHiFirst, U);
    FHiUnit := U;
  end;
  First := FHiFirst;
  if FHighTrailing then
    Last := ALast
  else
    Last := Max(FHiLast, ALast);
  if FHighWord then
  begin
    View1.HighlightUnit(First, Last);
    View1.Highlight(AFirst, ALast);
  end
  else
  begin
    // one colour: the word's
    View1.HighlightUnit(-1, -1);
    View1.Highlight(First, Last);
  end;
end;

procedure TfrmMain.DropDoubleBooks;
var
  I, J, N: Integer;
begin
  N := 0;
  for I := High(FRecent) downto 1 do
    for J := 0 to I - 1 do
      if SameFileName(BookFileName(FRecent[J].FileName), BookFileName(FRecent[I].FileName)) then
      begin
        Delete(FRecent, I, 1);
        Inc(N);
        Break;
      end;
  if N > 0 then
    DebugLog(Format('library: %d double(s) taken out', [N]));
end;

procedure TfrmMain.AddScanned(const AFileName: string; AHold: Boolean);
var
  R: TRecentBook;
  Book: TEpubBook;
  Held: Boolean;
begin
  Held := False;
  // never twice
  if RecentIndex(AFileName) >= 0 then
    Exit;
  R := Default(TRecentBook);
  R.FileName := AFileName;
  R.Title := '';
  R.Word := -1;
  R.Doc := -1;
  R.DocWord := -1;
  // its title (the book opened without its text)
  Book := nil;
  try
    try
      // the package only (CreateHeader, zip 324): Create read the timing
      // of every word as well, 2.3 s for a long book
      BookOpenPath(AFileName);
      Held := True;
      Book := TEpubBook.CreateHeader(AFileName);
      R.Title := Book.Title;
      SetBookMeta(R, Book);
      // its cover while it is open (ShowLibrary would open it once more)
      EnsureCover(AFileName, Book, R.Title);
    except
      on E: Exception do
        DebugLog('library: ' + AFileName + ' not read: ' + E.Message);
    end;
  finally
    Book.Free;
    if Held then
      BookRelease(AFileName);
  end;
  if AHold then
  begin
    FScanDone := FScanDone + [R];
    DebugLog('library: read, to be added with its batch - ' + AFileName);
    Exit;
  end;
  // after the book read last (the library shows it large), else first
  Insert(R, FRecent, Min(1, Length(FRecent)));
  if Length(FRecent) > LIBRARY_MAX then
    SetLength(FRecent, LIBRARY_MAX);
  DebugLog('library: added from EpubBuilder''s output - ' + AFileName);
end;

procedure TfrmMain.tmScanTimer(Sender: TObject);
var
  Name: string;
  I, At: Integer;
begin
  tmScan.Enabled := False;
  if Length(FScanQueue) = 0 then
    Exit;
  Name := FScanQueue[0];
  Delete(FScanQueue, 0, 1);
  // read, but not shown yet: the library on the screen stays as it is
  // until the whole batch is in (owner, 2026-11-25: "the screen changing
  // constantly ... visible order change only happens once")
  AddScanned(Name, True);
  if Length(FScanQueue) > 0 then
  begin
    LibraryNote(Format('Reading new books: %d of %d', [FScanTotal - Length(FScanQueue) + 1, FScanTotal]));
    tmScan.Enabled := True;
    Exit;
  end;
  // the batch, in its order, after the book read last
  At := Min(1, Length(FRecent));
  for I := 0 to High(FScanDone) do
    if RecentIndex(FScanDone[I].FileName) < 0 then
    begin
      Insert(FScanDone[I], FRecent, At);
      Inc(At);
    end;
  DebugLog(Format('library: %d new book(s) read and added', [Length(FScanDone)]));
  FScanDone := nil;
  if Length(FRecent) > LIBRARY_MAX then
    SetLength(FRecent, LIBRARY_MAX);
  BuildRecentMenu;
  LibraryNote('');
  // kept now: an app on a phone is ended without being closed
  SaveSettings;
  // the one change on the screen (not while a book is being opened)
  if LibraryShowing and not tmLibrary.Enabled and not FOpening then
    ShowLibrary;
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
  View1.HighlightUnit(-1, -1);
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
    if SameFileName(BookFileName(FRecent[I].FileName), BookFileName(AFileName)) then
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
  R := Default(TRecentBook);
  R.FileName := FBookFile;
  R.Title := EpubUnum1.Book.Title;
  SetBookMeta(R, EpubUnum1.Book);
  R.Word := ReadingWord;
  R.Doc := -1;
  R.DocWord := -1;
  if (R.Word >= 0) and (R.Word < EpubUnum1.Book.WordCount) then
  begin
    R.Doc := EpubUnum1.Book.Words[R.Word].Document;
    if (R.Doc >= 0) and (R.Doc <= High(EpubUnum1.Book.Documents)) then
      R.DocWord := R.Word - EpubUnum1.Book.Documents[R.Doc].FirstWord
    else
      R.Doc := -1;
  end;
  I := RecentIndex(FBookFile);
  if I >= 0 then
    Delete(FRecent, I, 1);
  Insert(R, FRecent, 0);
  if Length(FRecent) > LIBRARY_MAX then
    SetLength(FRecent, LIBRARY_MAX);
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
    DebugLog(Format('restore word %d: shown (%d blocks, %d laid out)', [AWord, LayoutBlocks, View1.LaidOutBlocks]));
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
  Sort: TLibrarySort;
  High_: THighlightUnit;
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
      FBooksTrees := nil;
      O.TryGetValue<string>('linkId', FLinkId);
      O.TryGetValue<string>('linkTokens', FLinkTokens);
      if O.TryGetValue<TJSONArray>('booksFolders', A) then
        for I := 0 to A.Count - 1 do
          if (A.Items[I] is TJSONString) and (TJSONString(A.Items[I]).Value <> '') then
            FBooksTrees := FBooksTrees + [TJSONString(A.Items[I]).Value];
      if O.TryGetValue<string>('librarySort', Folder) then
        for Sort := Low(TLibrarySort) to High(TLibrarySort) do
          if SameText(Folder, LIBRARY_SORT_KEYS[Sort]) then
            FLibrarySort := Sort;
      // zip 352 kept one word for all three ("sentenceSoFar+word"):
      // read the same way
      if O.TryGetValue<string>('highlight', Folder) then
      begin
        for High_ := Low(THighlightUnit) to High(THighlightUnit) do
          if SameText(Copy(Folder, 1, Length(HIGHLIGHT_KEYS[High_])), HIGHLIGHT_KEYS[High_]) then
            FHighUnit := High_;
        if Pos('SoFar', Folder) > 0 then
          FHighTrailing := True;
        if (Folder <> 'word') and (Pos('+word', Folder) = 0) then
          FHighWord := False;
      end;
      O.TryGetValue<Boolean>('highlightTrailing', FHighTrailing);
      O.TryGetValue<Boolean>('highlightWord', FHighWord);
      // another books folder, put in the settings by hand (not written)
      if O.TryGetValue<string>('booksFolder', Folder) and (Folder <> '') then
        FBooksFolder := Folder;
      if O.TryGetValue<Double>('textSize', Size) and (Size >= 10) and (Size <= 60) then
        View1.FontSize := Size;
      if O.TryGetValue<Double>('speed', Speed) then
        tbSpeed.Value := EnsureRange(Speed, SPEED_MIN, SPEED_MAX);
      FSeen := nil;
      if O.TryGetValue<TJSONArray>('seen', A) then
        for I := 0 to A.Count - 1 do
          if A.Items[I] is TJSONString then
            FSeen := FSeen + [LowerCase(TJSONString(A.Items[I]).Value)];
      FRecent := nil;
      if O.TryGetValue<TJSONArray>('recent', A) then
        for I := 0 to A.Count - 1 do
          if (A.Items[I] is TJSONObject) and (Length(FRecent) < LIBRARY_MAX) then
          begin
            E := TJSONObject(A.Items[I]);
            R := Default(TRecentBook);
            R.FileName := '';
            R.Title := '';
            R.Word := -1;
            R.Doc := -1;
            R.DocWord := -1;
            E.TryGetValue<string>('file', R.FileName);
            E.TryGetValue<string>('title', R.Title);
            E.TryGetValue<Integer>('word', R.Word);
            E.TryGetValue<Integer>('doc', R.Doc);
            E.TryGetValue<Integer>('docWord', R.DocWord);
            E.TryGetValue<Boolean>('meta', R.Meta);
            E.TryGetValue<string>('author', R.Author);
            E.TryGetValue<string>('authorSort', R.AuthorSort);
            E.TryGetValue<Integer>('year', R.Year);
            E.TryGetValue<string>('genre', R.Genre);
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
  for Sort := Low(TLibrarySort) to High(TLibrarySort) do
    if miSort[Sort] <> nil then
      miSort[Sort].IsChecked := Sort = FLibrarySort;
  CheckHighlightMenu;
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
    O.AddPair('librarySort', LIBRARY_SORT_KEYS[FLibrarySort]);
    O.AddPair('highlight', HIGHLIGHT_KEYS[FHighUnit]);
    O.AddPair('highlightTrailing', TJSONBool.Create(FHighTrailing));
    O.AddPair('highlightWord', TJSONBool.Create(FHighWord));
    // the link (a phone): who this reader is, the BookManagers paired
    if FLinkId <> '' then
      O.AddPair('linkId', FLinkId);
    if FLinkTokens <> '' then
      O.AddPair('linkTokens', FLinkTokens);
    A := TJSONArray.Create;
    O.AddPair('booksFolders', A);
    for I := 0 to High(FBooksTrees) do
      A.Add(FBooksTrees[I]);
    O.AddPair('speed', TJSONNumber.Create(FPendingSpeed));
    A := TJSONArray.Create;
    O.AddPair('recent', A);
    for I := 0 to High(FRecent) do
    begin
      E := TJSONObject.Create;
      E.AddPair('file', FRecent[I].FileName);
      E.AddPair('title', FRecent[I].Title);
      E.AddPair('word', TJSONNumber.Create(FRecent[I].Word));
      E.AddPair('doc', TJSONNumber.Create(FRecent[I].Doc));
      E.AddPair('docWord', TJSONNumber.Create(FRecent[I].DocWord));
      E.AddPair('meta', TJSONBool.Create(FRecent[I].Meta));
      E.AddPair('author', FRecent[I].Author);
      E.AddPair('authorSort', FRecent[I].AuthorSort);
      E.AddPair('year', TJSONNumber.Create(FRecent[I].Year));
      E.AddPair('genre', FRecent[I].Genre);
      A.AddElement(E);
    end;
    A := TJSONArray.Create;
    O.AddPair('seen', A);
    for I := 0 to High(FSeen) do
      A.Add(FSeen[I]);
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
{$IF Defined(ANDROID) or Defined(IOS)}
var
  SafeArea: IFMXWindowSafeAreaService;
{$ENDIF}
begin
  if FScreenLogged then
    Exit;
  FScreenLogged := True;
  {$IF Defined(ANDROID) or Defined(IOS)}
  // the safe area as it is now (OnSafeAreaChanged tells of changes only)
  if TPlatformServices.Current.SupportsPlatformService(IFMXWindowSafeAreaService, SafeArea) then
    FormSafeAreaChanged(Self, SafeArea.GetSafeAreaInsets(Self));
  {$ENDIF}
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
  {$IFDEF ANDROID}
  AppEvents: IFMXApplicationEventService;
  Old: string;
  {$ENDIF}
begin
  // (the move of EpubReader's folders of before into the shared ones,
  // and its marker EpubUnum-moved-EpubReader.txt, are gone: obsolete -
  // owner, zip 342)
  // the debug log: next to the settings, started afresh at every run
  DebugLogOpen(ChangeFileExt(SettingsFile, '-debug.log'));
  {$IFDEF ANDROID}
  // the books of the books folders are read from the file Android opened
  // (uBookImport; zip 347 - set here since 349)
  EpubStreamOpener := OpenBookStream;
  {$ENDIF}
  // a crash in a library (Steam Deck, 2026-11-17): logged with where it was
  Application.OnException := AppException;
  OnShow := FormShow;
  {$IF Defined(ANDROID) or Defined(IOS)}
  // clear of the status and navigation bars (Android 15 on draws the
  // window under them)
  OnSafeAreaChanged := FormSafeAreaChanged;
  {$ENDIF}
  OnActivate := FormActivated;
  OnDeactivate := FormDeactivated;
  FRedraw := TWindowRedraw.Create(Self);
  // Steam's overlay is drawn into the window's own frames: one whenever
  // it has something to show (uSteam)
  SteamOverlayFollow(Self);
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
  FHiUnit := -1;
  // the phrase / sentence chosen: the word over it in its own colour
  FHighWord := True;
  lbToc.OnApplyStyleLookup := TocApplyStyle;
  // how far through the book, under the text
  View1.ShowProgress := True;
  // scrolled on past a document's end: the next one (set here, not in the
  // form file: the IDE's form loads with an older package too)
  View1.OnEdge := View1Edge;
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
  {$IFDEF ANDROID}
  // leaving an app does not end it there: back in front, the library is
  // read again (books copied in over USB)
  if TPlatformServices.Current.SupportsPlatformService(IFMXApplicationEventService, AppEvents) then
    AppEvents.SetApplicationEventHandler(AppEvent);
  {$ENDIF}
  DebugLog('FMX canvas in use: ' + FmxCanvasClassName);
  // Linux only: fontconfig's (macOS and Windows find their fonts without it)
  {$IFDEF LINUX}
  LogFontProbe;
  {$ENDIF}
  // a new name every run (Random without Randomize gave the same one, so
  // two readers shared - and deleted - one folder)
  FAudioFolder := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetTempPath,
    'EpubReader-' + System.IOUtils.TPath.GetGUIDFileName);
  {$IFDEF ANDROID}
  // An app there is ended by the system, not closed: FormClose never
  // emptied the folders of earlier runs (a 900 MB copy of a book's audio
  // each, 2026-11-25). One reader runs at a time there, so all of them go.
  try
    for Old in TDirectory.GetDirectories(System.IOUtils.TPath.GetTempPath, 'EpubReader-*') do
    begin
      TDirectory.Delete(Old, True);
      DebugLog('audio: an earlier run''s copies deleted - ' + Old);
    end;
  except
    on E: Exception do
      DebugLog('audio: an earlier run''s copies not deleted - ' + E.Message);
  end;
  {$ENDIF}
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
    FBooksFolder := EpubUnumFolder(EU_BOOKS);
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
  // A phone or tablet (zip 321): the same, with a bar of six buttons at
  // the foot for what is used all the time; its Menu button is the way in.
  if MenuLayout then
  begin
    layTop.Visible := False;
    lbToc.Visible := False;
    Splitter1.Visible := False;
    if TouchBuild then
    begin
      BuildTouchBar;
      DebugLog('touch: no tool bar or contents panel - the bar at the foot, and its menu, have them');
    end
    else
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
  else if TouchBuild then
    // a phone's: buttons, larger (owner, zip 345)
    FPadMenu.FontSize := 22
  else
    FPadMenu.FontSize := 20;
  FPadMenu.TouchStyle := TouchBuild;
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
  // beside the program (on the Mac beside EpubReader.app, never inside
  // the signed bundle) - where the partner site's "Custom Configuration
  // (Bundled with Game)" can name it - else beside the settings (a
  // folder the user cannot write to)
  Manifest := '';
  Folder := System.IOUtils.TPath.Combine(ProgramFolder, 'steaminput');
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
      begin
        // the first press for a minute: the screen may be black
        FRedraw.UserInput;
        // the menu's foot names the pad's buttons again
        SetPadKeys(False);
        PadPress(I);
      end;
    // the right stick scrolls the page (up is positive)
    if (Abs(Y) > PAD_STICK_DEAD) and not FPadMenu.Showing and not LibraryShowing and
      (EpubUnum1.Book <> nil) then
      View1.ScrollBy(-Y * PAD_SCROLL_SPEED * (Now_ - FPadTick) / 1000);
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
  // the cover chooser over everything: the pad moves its frame
  if (FCoverPick <> nil) and FCoverPick.Showing then
  begin
    case AButton of
      PAD_UP, PAD_LEFT: FCoverPick.Move(-1);
      PAD_DOWN, PAD_RIGHT: FCoverPick.Move(1);
      PAD_PLAY: FCoverPick.Choose;
      PAD_BACK, PAD_MENU: FCoverPick.Hide;
    end;
    Exit;
  end;
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
        // a books folder: the folders
        else if FMenuMode = MODE_FOLDER then
          ShowFoldersMenu
        // a licence: its list; the list: About
        else if FMenuMode = MODE_LICENCE then
          ShowLicencesMenu(FLicence)
        else if FMenuMode = MODE_LICENCES then
          ShowAbout
        // "No books yet" stays (Android's Back leaves the app there)
        else if FMenuMode = MODE_START then
          Exit
        // the link panel: Back is Cancel (the link ends, back to where
        // books come from)
        else if FMenuMode = MODE_LINK then
          LinkCancel
        else
        begin
          FPadMenu.Hide;
          OfferBooksIfEmpty;
        end;
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
    PAD_UP: View1.ScrollBy(-3 * View1.FontSize);
    PAD_DOWN: View1.ScrollBy(3 * View1.FontSize);
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
    MENU_SORT: Result := Format('%s  %s  %s', [#$2039, LIBRARY_SORT_NAMES[FLibrarySort], #$203A]);
    MENU_HIGHLIGHT: Result := Format('%s  %s  %s', [#$2039, HIGHLIGHT_NAMES[FHighUnit], #$203A]);
    // with the word alone: faded, the value without the arrows
    MENU_HIGH_TYPE:
      if FHighUnit = huWord then
        Result := HIGHLIGHT_TYPE_NAMES[FHighTrailing]
      else
        Result := Format('%s  %s  %s', [#$2039, HIGHLIGHT_TYPE_NAMES[FHighTrailing], #$203A]);
    MENU_HIGH_WORD: Result := ON_OFF[FHighWord];
  else
    Result := '';
  end;
end;

function TfrmMain.PadMenuFoot(AChange: Boolean): string;
begin
  // the words size the box; RefreshPadFoot draws the hints after Show
  FFootChange := AChange;
  Result := TPadMenu.HintsText(PadFootHints(FPadKeys));
end;

function TfrmMain.PadFootHints(AKeys: Boolean): TArray<TPadHint>;

  { The hint of button AButton (PAD_*), doing AText. }
  function One(AButton: Integer; const AText: string): TPadHint;
  var
    Origin: TSteamPadOrigin;
  begin
    Origin.Glyph := '';
    Origin.Name := '';
    if not AKeys and (FPad <> nil) then
      Origin := FPad.Origin(AButton, FDark);
    // the keys (or no pad Steam knows): the key's name from the table
    if (Origin.Glyph = '') and (Origin.Name = '') then
      Origin.Name := ReaderMenuFirstKey(PAD_ACTIONS[AButton]);
    Result := TPadMenu.Hint(Origin.Glyph, Origin.Name, AText);
  end;

begin
  Result := [One(PAD_PLAY, 'choose'), One(PAD_BACK, 'back')];
  if FFootChange then
    Result := Result + [One(PAD_LEFT, ''), One(PAD_RIGHT, 'change')];
end;

procedure TfrmMain.RefreshPadFoot;
begin
  if (FPadMenu <> nil) and FPadMenu.Showing then
    FPadMenu.SetHints(PadFootHints(FPadKeys));
end;

procedure TfrmMain.SetPadKeys(AKeys: Boolean);
begin
  if AKeys = FPadKeys then
    Exit;
  FPadKeys := AKeys;
  // only a foot of hints changes over (a folder's line stays)
  if (FPadMenu <> nil) and FPadMenu.Showing and FPadMenu.HasHints then
    RefreshPadFoot;
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
  TEXTS: array[MENU_RESUME..MENU_ABOUT] of string = ('Back to the book', 'Open a book',
    'Get books from BookManager', 'Library',
    'Library order', 'Contents', 'Text size',
    'Speed', 'Dark mode', 'Highlight', 'Highlight type', 'Highlight word', 'Learn to read',
    'Controls', 'Cover of this book', 'Exit', 'About');
var
  Items: TArray<TPadMenuItem>;
  I: Integer;
begin
  FMenuMode := MODE_MAIN;
  SetLength(Items, MENU_ABOUT + 1);
  for I := 0 to MENU_ABOUT do
    Items[I] := TPadMenu.Item(TEXTS[I], PadMenuValue(I));
  // with the word alone, the highlight's type and word say nothing
  Items[MENU_HIGH_TYPE].Dim := FHighUnit = huWord;
  Items[MENU_HIGH_WORD].Dim := FHighUnit = huWord;
  // BookManager sends books to a phone
  Items[MENU_LINK].Dim := not BookFolderSupported;
  // a phone: its own storage through the system's picker (the books folder
  // is the library already; owner: "the current Open File is useless on
  // Android")
  if BookFolderSupported then
  begin
    if Length(FBooksTrees) = 1 then
      Items[MENU_OPEN] := TPadMenu.Item('Books folders', BookFolderName(FBooksTrees[0]))
    else if Length(FBooksTrees) > 1 then
      Items[MENU_OPEN] := TPadMenu.Item('Books folders', IntToStr(Length(FBooksTrees)))
    else
      Items[MENU_OPEN] := TPadMenu.Item('Books folders', 'none yet');
  end;
  PadMenuColors;
  FPadMenu.Show('EpubReader', Items, MENU_RESUME, PadMenuFoot(True));
  RefreshPadFoot;
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
  RefreshPadFoot;
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
  RefreshPadFoot;
end;

{ EpubBuilder's output folder: the one in its settings ([Folders] Output),
  else its default, Documents/EpubBuilder/Output - the books it makes are
  listed with the reader's own (owner, 2026-11-20). '' when it cannot be
  told. }
function BuilderOutputFolder: string;
var
  Base, Ini: string;
  F: TMemIniFile;
begin
  Result := '';
  try
    // EpubBuilder's settings file (its uBuilder.SettingsFile)
    {$IF Defined(MSWINDOWS)}
    Base := System.IOUtils.TPath.GetHomePath;
    {$ELSEIF Defined(MACOS)}
    Base := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetHomePath, 'Library/Application Support');
    {$ELSE}
    Base := GetEnvironmentVariable('XDG_CONFIG_HOME');
    if Base = '' then
      Base := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetHomePath, '.config');
    {$ENDIF}
    // its settings: the shared folder (uEpubUnum); before zip 178 its own
    Ini := System.IOUtils.TPath.Combine(EpubUnumConfigFolder, 'EpubBuilder.ini');
    if not FileExists(Ini) then
      Ini := System.IOUtils.TPath.Combine(System.IOUtils.TPath.Combine(Base, 'EpubBuilder'), 'EpubBuilder.ini');
    if FileExists(Ini) then
    begin
      F := TMemIniFile.Create(Ini, TEncoding.UTF8);
      try
        Result := F.ReadString('Folders', 'Output', '');
      finally
        F.Free;
      end;
    end;
    if Result = '' then
      Result := EpubUnumFolder(EU_TRANSCRIBED);
  except
    Result := '';
  end;
end;

function TfrmMain.ScanTranscribed: Integer;
const
  { Names kept in "seen" at most (the oldest go). }
  SEEN_MAX = 1000;
var
  Folders, Files, Found: TArray<string>;
  Times: TArray<TDateTime>;
  I, J: Integer;
  Name, T: string;
  D: TDateTime;

  { Book AFile (a path, or a chosen folder's address) found: into Found
    unless the library or the queue has it already. }
  procedure Consider(const AFile: string; ATime: TDateTime);
  var
    K: Integer;
    Have: Boolean;
    N: string;
  begin
    N := LowerCase(BookFileName(AFile));
    Have := False;
    for K := 0 to High(FSeen) do
      if FSeen[K] = N then
      begin
        Have := True;
        Break;
      end;
    // "Seen" keeps a book the user took off the list from coming back.
    // On a phone the library IS the folder, and nothing takes a book
    // off but the old limit of ten: a book there and not in the
    // library goes in (zip 325).
    if Have and not TouchBuild then
      Exit;
    if not Have then
      FSeen := FSeen + [N];
    // already in the library (opened from elsewhere)
    if RecentIndex(AFile) >= 0 then
      Exit;
    // or waiting to be read into it. MY FAULT IN 325 (zip 328): with
    // "seen" no longer stopping it on a phone, every showing of the
    // library - one after each book read - queued the waiting books
    // again, and each came in two or three times
    for K := 0 to High(FScanQueue) do
      if SameFileName(BookFileName(FScanQueue[K]), BookFileName(AFile)) then
        Exit;
    for K := 0 to High(FScanDone) do
      if SameFileName(BookFileName(FScanDone[K].FileName), BookFileName(AFile)) then
        Exit;
    for K := 0 to High(Found) do
      if SameFileName(BookFileName(Found[K]), BookFileName(AFile)) then
        Exit;
    Found := Found + [AFile];
    Times := Times + [ATime];
  end;

begin
  Result := 0;
  // EpubBuilder's output folder (its settings, else Documents/EpubUnum/
  // Transcribed), and the shared Transcribed folder when that is another
  Folders := nil;
  Name := BuilderOutputFolder;
  if Name <> '' then
    Folders := [Name];
  Name := EpubUnumFolder(EU_TRANSCRIBED);
  if (Length(Folders) = 0) or not SameFileName(ExcludeTrailingPathDelimiter(ExpandFileName(Folders[0])),
    ExcludeTrailingPathDelimiter(ExpandFileName(Name))) then
    Folders := Folders + [Name];
  {$IF Defined(ANDROID) or Defined(IOS)}
  // a phone has no File > Open: every book of the Books folder is in the
  // library as well (copied in over USB, or sent by BookManager)
  Folders := Folders + [FBooksFolder];
  {$ENDIF}
  Found := nil;
  Times := nil;
  for I := 0 to High(Folders) do
  try
    if not TDirectory.Exists(Folders[I]) then
      Continue;
    Files := TDirectory.GetFiles(Folders[I], '*.epub', TSearchOption.soAllDirectories);
    for J := 0 to High(Files) do
      Consider(Files[J], TFile.GetLastWriteTime(Files[J]));
  except
    on E: Exception do
      DebugLog('library: ' + Folders[I] + ': ' + E.Message);
  end;
  // Android: the books folders chosen in the system's picker - every book
  // in them and their folders, read where it is (zip 346), as last listed
  // (ListBooksFolders; a phone's order is by name, below: no time needed)
  for J := 0 to High(FFolderBooks) do
    Consider(FFolderBooks[J], 0);
  if Length(FSeen) > SEEN_MAX then
    Delete(FSeen, 0, Length(FSeen) - SEEN_MAX);
  if Length(Found) = 0 then
    Exit;
  // the oldest first: each goes in at the same place, so the newest ends
  // up nearest the front
  for I := 1 to High(Found) do
    for J := I downto 1 do
      if Times[J - 1] > Times[J] then
      begin
        T := Found[J - 1];
        Found[J - 1] := Found[J];
        Found[J] := T;
        D := Times[J - 1];
        Times[J - 1] := Times[J];
        Times[J] := D;
      end
      else
        Break;
  if TouchBuild then
  begin
    // A phone: one at a time from a timer, the library showing meanwhile
    // (zip 323: seven new books were ten seconds of a window that did
    // nothing - the owner thought it had hung). Result is 0: none is in
    // yet.
    // A batch copied to a phone has no order worth showing in its files'
    // times: by name (zip 331; the owner saw a "random-looking order").
    for I := 1 to High(Found) do
      for J := I downto 1 do
        if CompareText(BookFileName(Found[J - 1]), BookFileName(Found[J])) > 0 then
        begin
          T := Found[J - 1];
          Found[J - 1] := Found[J];
          Found[J] := T;
        end
        else
          Break;
    FScanQueue := FScanQueue + Found;
    FScanTotal := Length(FScanQueue) + Length(FScanDone);
    LibraryNote(Format('Reading new books: %d of %d', [Length(FScanDone) + 1, FScanTotal]));
    tmScan.Enabled := True;
    Exit;
  end;
  for I := 0 to High(Found) do
  begin
    AddScanned(Found[I]);
    Inc(Result);
  end;
  BuildRecentMenu;
end;

procedure TfrmMain.ListBooksFolders;
var
  I, J: Integer;
  Books: TArray<string>;
  Note: string;
  Tick: Cardinal;
begin
  FFolderBooks := nil;
  FFolderBooksOK := True;
  if FFolderBookSet = nil then
    FFolderBookSet := TDictionary<string, Boolean>.Create;
  FFolderBookSet.Clear;
  for I := 0 to High(FBooksTrees) do
  begin
    Tick := TThread.GetTickCount;
    Books := BookFolderBooks(FBooksTrees[I], Note);
    if Note <> '' then
    begin
      FFolderBooksOK := False;
      DebugLog('library: the books folder ' + BookFolderName(FBooksTrees[I]) + ' could not be read - ' + Note);
      Continue;
    end;
    DebugLog(Format('library: %d book(s) in %s (%d ms)', [Length(Books), BookFolderName(FBooksTrees[I]),
      TThread.GetTickCount - Tick]));
    for J := 0 to High(Books) do
      if not FFolderBookSet.ContainsKey(Books[J]) then
      begin
        FFolderBookSet.Add(Books[J], True);
        FFolderBooks := FFolderBooks + [Books[J]];
      end;
  end;
end;

function TfrmMain.BookThere(const AName: string): Boolean;
begin
  if not IsBookAddress(AName) then
    Exit(FileExists(AName));
  // not listed yet, or a folder that could not be read: not taken for gone
  if (FFolderBookSet = nil) or not FFolderBooksOK then
    Exit(True);
  Result := FFolderBookSet.ContainsKey(AName);
end;

procedure TfrmMain.ShowFoldersMenu;
var
  Items: TArray<TPadMenuItem>;
  I: Integer;
begin
  FMenuMode := MODE_FOLDERS;
  Items := nil;
  for I := 0 to High(FBooksTrees) do
    Items := Items + [TPadMenu.Item(BookFolderName(FBooksTrees[I]))];
  Items := Items + [TPadMenu.Item('Add a folder'), TPadMenu.Item('Get books from BookManager'),
    TPadMenu.Item('Back')];
  PadMenuColors;
  // the phone's storage and a memory card are both in Android's picker
  FPadMenu.ShowText('Books folders', 'Every EPUB book in these folders and in their folders is in the library, ' +
    'read where it is. Add the phone''s folder, a memory card''s, or both - or get books from BookManager ' +
    'on your computer.', Items, Length(FBooksTrees), '');
end;

procedure TfrmMain.ShowFolder(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex > High(FBooksTrees)) then
    Exit;
  FMenuMode := MODE_FOLDER;
  FFolderShown := AIndex;
  PadMenuColors;
  FPadMenu.ShowText(BookFolderName(FBooksTrees[AIndex]), 'Taken off, its books leave the library. They stay ' +
    'where they are; adding the folder again brings them back.', [TPadMenu.Item('Take it off'),
    TPadMenu.Item('Keep it')], 1, '');
end;

procedure TfrmMain.RemoveBooksFolder(AIndex: Integer);
var
  I, N: Integer;
  Tree: string;
begin
  if (AIndex < 0) or (AIndex > High(FBooksTrees)) then
    Exit;
  Tree := FBooksTrees[AIndex];
  Delete(FBooksTrees, AIndex, 1);
  // its books off the library (the open one closed)
  N := 0;
  for I := High(FRecent) downto 0 do
    if BookInFolder(FRecent[I].FileName, Tree) then
    begin
      if SameText(FBookFile, FRecent[I].FileName) then
      begin
        StopPlaying;
        EpubUnum1.Active := False;
        View1.Clear;
        FBookFile := '';
      end;
      Delete(FRecent, I, 1);
      Inc(N);
    end;
  BookFolderForget(Tree);
  DebugLog(Format('books folder: %s taken off, %d book(s) with it', [BookFolderName(Tree), N]));
  BuildRecentMenu;
  SaveSettings;
  ShowLibrary;
end;

procedure TfrmMain.ShowStartMenu;
var
  Items: TArray<TPadMenuItem>;
begin
  FMenuMode := MODE_START;
  Items := [TPadMenu.Item('Get books from BookManager'), TPadMenu.Item('Choose a books folder')];
  PadMenuColors;
  FPadMenu.ShowText('No books yet', 'Books come from BookManager on your computer, or from a folder on this ' +
    'phone or on its memory card - every EPUB book in it and in its folders, read where it is.', Items,
    START_FOLDER, '');
  DebugLog('library: empty - BookManager or the phone''s storage offered');
end;

procedure TfrmMain.ShowAbout;
var
  Sound: string;
  P: Integer;
begin
  // the sound player's own words, without where its files are
  if FPlayer <> nil then
  begin
    Sound := FPlayer.Description;
    P := Pos(' from ', Sound);
    if P > 0 then
      Sound := Copy(Sound, 1, P - 1);
  end
  else
    Sound := 'none';
  DebugLog('about: ' + VersionText);
  FMenuMode := MODE_ABOUT;
  PadMenuColors;
  FPadMenu.ShowText('About EpubReader', 'EpubReader ' + VersionText + sLineBreak + 'Built ' + BuildStamp +
    sLineBreak + sLineBreak + 'Reads EPUB books aloud, the words highlighted as they are spoken.' + sLineBreak +
    sLineBreak + ABOUT_COPYRIGHT + sLineBreak + sLineBreak + 'Sound: ' + Sound + '.' + sLineBreak +
    'Licences: the outside components it is made with.', [TPadMenu.Item('OK'), TPadMenu.Item('Licences')],
    ABOUT_OK, '');
end;

procedure TfrmMain.ShowLicencesMenu(AIndex: Integer);
var
  Items: TArray<TPadMenuItem>;
  I: Integer;
begin
  FMenuMode := MODE_LICENCES;
  FLicences := ReaderLicences;
  SetLength(Items, Length(FLicences) + 1);
  for I := 0 to High(FLicences) do
    Items[I] := TPadMenu.Item(FLicences[I].Name, FLicences[I].Licence);
  Items[High(Items)] := TPadMenu.Item('Back');
  PadMenuColors;
  FPadMenu.Show('Licences', Items, EnsureRange(AIndex, 0, High(Items)), '');
end;

procedure TfrmMain.ShowLicence(AIndex, APage: Integer);
var
  Items: TArray<TPadMenuItem>;
  Title: string;
begin
  if (AIndex < 0) or (AIndex > High(FLicences)) then
    Exit;
  FMenuMode := MODE_LICENCE;
  FLicence := AIndex;
  FLicencePages := LicencePages(FLicences[AIndex].Text, LICENCE_PAGE_CHARS);
  FLicencePage := EnsureRange(APage, 0, High(FLicencePages));
  Title := FLicences[AIndex].Name + ' - ' + FLicences[AIndex].Licence;
  if Length(FLicencePages) > 1 then
    Title := Title + Format(' (%d of %d)', [FLicencePage + 1, Length(FLicencePages)]);
  // Next page while there is one (round to the first after the last);
  // Back to the list
  if Length(FLicencePages) > 1 then
    Items := [TPadMenu.Item('Next page'), TPadMenu.Item('Back')]
  else
    Items := [TPadMenu.Item('Back')];
  PadMenuColors;
  FPadMenu.ShowText(Title, FLicencePages[FLicencePage], Items, 0, '');
end;

procedure TfrmMain.miAboutClick(Sender: TObject);
begin
  ShowAbout;
end;

procedure TfrmMain.ShowNote(const ATitle, AText: string);
begin
  FMenuMode := MODE_NOTE;
  PadMenuColors;
  FPadMenu.ShowText(ATitle, AText, [TPadMenu.Item('OK')], 0, '');
end;

procedure TfrmMain.StartLink;
{$IFDEF ANDROID}
var
  Name, Said: string;
{$ENDIF}
begin
  {$IFDEF ANDROID}
  if FLink = nil then
  begin
    if FLinkId = '' then
    begin
      // made once, kept: BookManager knows this reader by it
      FLinkId := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').ToLower;
      SaveSettings;
    end;
    Name := PhoneName;
    if Name = '' then
      Name := 'Android phone';
    FLinkStatus := '';
    FLinkCode := '';
    FLinkProgress := '';
    FLinkReceived := 0;
    FLinkLast := '';
    FLinkHeard := '';
    FLinkActive := False;
    // where Cancel goes back to
    if FMenuMode in [MODE_FOLDERS, MODE_MAIN] then
      FLinkFrom := FMenuMode
    else
      FLinkFrom := MODE_START;
    try
      FLink := TLinkServer.Create(LINK_APP_READER, Name, FLinkId);
      // books only, into the reader's own Books folder; /books lists it
      FLink.SetFolders(FBooksFolder, '', '', [FBooksFolder]);
      FLink.Reserve := LINK_RESERVE_PHONE;
      FLink.SetTokens(FLinkTokens);
      FLink.OnPairCode := LinkPairCode;
      FLink.OnPaired := LinkPaired;
      FLink.OnPairEnded := LinkPairEnded;
      FLink.OnReceived := LinkReceived;
      FLink.OnRequest := LinkRequest;
      FLink.OnUploadProgress := LinkUploadProgress;
      FLink.OnBye := LinkBye;
      Said := FLink.Start;
      DebugLog(Format('link: started - EpubReader as "%s" - %s', [Name, Said]));
      if FLink.Port = 0 then
        FLinkStatus := Said
      else
        FLinkStatus := 'Waiting for BookManager on your computer (on the same Wi-Fi): open its Send to ' +
          'phone tab.';
      // a book cut off last time (Done mid-transfer: its .part stays)
      DropPartFiles;
      // BookManager says it is here: answered directly
      FLinkFinder := TLinkFinder.Create;
      FLinkFinder.OnChange := LinkFinderChange;
      FLinkFinder.OnBye := LinkBye;
      DebugLog('link: the finder is ' + FLinkFinder.State + '; this phone''s addresses: ' + LinkLocalAddresses +
        '; announcing to 255.255.255.255 and ' + string.Join(' ', LinkBroadcastTargets));
    except
      on E: Exception do
      begin
        DebugLog('link: not started - ' + E.ClassName + ': ' + E.Message);
        FreeAndNil(FLinkFinder);
        FreeAndNil(FLink);
        FLinkStatus := 'The link could not start: ' + E.Message;
      end;
    end;
    // a batch of books takes a while: the screen stays on meanwhile, and
    // the Wi-Fi saves no power (its first connections were dropped)
    KeepScreenOn(FLink <> nil);
    if FLink <> nil then
      DebugLog('link: ' + WifiAwake(True));
  end;
  ShowLinkPanel;
  {$ENDIF}
end;

procedure TfrmMain.DropPartFiles;
var
  F: string;
  N: Integer;
begin
  N := 0;
  try
    if TDirectory.Exists(FBooksFolder) then
      for F in TDirectory.GetFiles(FBooksFolder, '*.part', TSearchOption.soAllDirectories) do
      try
        TFile.Delete(F);
        Inc(N);
      except
        // in use: next time
      end;
  except
    on E: Exception do
      DebugLog('link: .part files not looked through - ' + E.Message);
  end;
  if N > 0 then
    DebugLog(Format('link: %d unfinished book(s) of a cut-off transfer deleted', [N]));
end;

procedure TfrmMain.StopLink(const AWhy: string);
begin
  if (FLink = nil) and (FLinkFinder = nil) then
    Exit;
  FreeAndNil(FLinkFinder);
  FreeAndNil(FLink);
  KeepScreenOn(False);
  DebugLog('link: ' + WifiAwake(False));
  DebugLog(Format('link: stopped - %s (%d book(s) received)', [AWhy, FLinkReceived]));
end;

procedure TfrmMain.LinkCancel;
begin
  StopLink('Cancel');
  if FLinkFrom = MODE_FOLDERS then
    ShowFoldersMenu
  else if FLinkFrom = MODE_MAIN then
  begin
    ShowPadMenu;
    FPadMenu.Move(MENU_LINK);
  end
  else if TouchBuild and LibraryShowing and (Length(FRecent) = 0) and (Length(FScanQueue) = 0) then
    ShowStartMenu
  else
  begin
    FPadMenu.Hide;
    OfferBooksIfEmpty;
  end;
end;

procedure TfrmMain.ShowLinkPanel;
var
  Text: string;
  Items: TArray<TPadMenuItem>;
begin
  if FPadMenu = nil then
    Exit;
  Text := FLinkStatus;
  if FLinkCode <> '' then
    // the code in two halves, easier to read across a room
    Text := Format('%s asks to send books to this phone.' + sLineBreak + sLineBreak +
      'Type this code there:  %s %s' + sLineBreak + sLineBreak + 'It works for 5 minutes. Not you? Refuse.',
      [FLinkCodeFor, Copy(FLinkCode, 1, 3), Copy(FLinkCode, 4, MaxInt)]);
  if FLinkProgress <> '' then
    Text := Text + sLineBreak + sLineBreak + FLinkProgress;
  if FLinkReceived > 0 then
    Text := Text + sLineBreak + sLineBreak + Format('Received: %d book(s), the last "%s" - in the library.',
      [FLinkReceived, FLinkLast]);
  // Cancel back to where books come from; Done only once something
  // happened (faded until then); Refuse with a code
  if FLinkCode <> '' then
    Items := [TPadMenu.Item('Refuse'), TPadMenu.Item('Cancel'), TPadMenu.Item('Done')]
  else
    Items := [TPadMenu.Item('Cancel'), TPadMenu.Item('Done')];
  Items[High(Items)].Dim := not FLinkActive;
  FMenuMode := MODE_LINK;
  PadMenuColors;
  if FLinkActive then
    FPadMenu.ShowText('Get books from BookManager', Text, Items, High(Items), '')
  else
    FPadMenu.ShowText('Get books from BookManager', Text, Items, High(Items) - 1, '');
end;

procedure TfrmMain.LinkFinderChange(Sender: TObject);
var
  P: TLinkPeer;
  Hosts: TArray<string>;
  Heard: string;
begin
  if (FLink = nil) or (FLinkFinder = nil) then
    Exit;
  Hosts := nil;
  Heard := '';
  for P in FLinkFinder.Peers do
    if P.App = LINK_APP_MANAGER then
    begin
      Hosts := Hosts + [P.Host];
      Heard := Heard + P.Name + ' (' + P.Host + ') ';
    end;
  FLink.SetDirect(Hosts);
  if Heard <> FLinkHeard then
  begin
    FLinkHeard := Heard;
    if Heard <> '' then
      DebugLog('link: heard ' + Trim(Heard) + ' - answered directly');
  end;
end;

procedure TfrmMain.LinkUploadProgress(const AName, ABatch: string; ADone, ATotal: Int64);
var
  Of_: string;
begin
  if FLink = nil then
    Exit;
  Of_ := '';
  if Pos('/', ABatch) > 1 then
    Of_ := Format(', book %s of %s', [Copy(ABatch, 1, Pos('/', ABatch) - 1),
      Copy(ABatch, Pos('/', ABatch) + 1, MaxInt)]);
  if ATotal > 0 then
    FLinkProgress := Format('Receiving "%s"%s - %d %% (%.0f of %.0f MB)', [ChangeFileExt(AName, ''), Of_,
      Round(ADone * 100 / ATotal), ADone / 1E6, ATotal / 1E6])
  else
    FLinkProgress := Format('Receiving "%s"%s', [ChangeFileExt(AName, ''), Of_]);
  if FMenuMode = MODE_LINK then
    ShowLinkPanel;
end;

procedure TfrmMain.LinkPairCode(const AClient, ACode: string);
begin
  // the link ended meanwhile (Done / Cancel): nothing to show
  if FLink = nil then
    Exit;
  DebugLog('link: ' + AClient + ' asks to pair - the code shown');
  FLinkCode := ACode;
  FLinkCodeFor := AClient;
  ShowLinkPanel;
end;

procedure TfrmMain.LinkPaired(const AClient, AToken: string);
begin
  if FLink = nil then
    Exit;
  FLinkTokens := FLink.TokensText;
  SaveSettings;
  DebugLog('link: paired with ' + AClient);
  FLinkCode := '';
  FLinkActive := True;
  FLinkStatus := 'Paired with ' + AClient + ': drop books on its Send to phone tab, or Send all new. They ' +
    'come into the library as they arrive.';
  ShowLinkPanel;
end;

procedure TfrmMain.LinkPairEnded(const AClient, AWhy: string);
begin
  if FLink = nil then
    Exit;
  DebugLog('link: pairing with ' + AClient + ' ended - ' + AWhy);
  FLinkCode := '';
  FLinkStatus := Format('The code for %s no longer works (%s). Press Pair... in BookManager to try again.',
    [AClient, AWhy]);
  if FMenuMode = MODE_LINK then
    ShowLinkPanel;
end;

procedure TfrmMain.LinkBye(const AText: string);
begin
  // the call and the announcement may both come: once; and only a
  // BookManager ends the link
  if (FLink = nil) or ((AText <> '') and (Pos('"', AText) > 0) and (Pos(LINK_APP_MANAGER, AText) <> 1)) then
    Exit;
  StopLink('BookManager closed (' + AText + ')');
  if (FPadMenu <> nil) and (FMenuMode = MODE_LINK) then
  begin
    FPadMenu.Hide;
    OfferBooksIfEmpty;
  end;
end;

procedure TfrmMain.LinkRequest(const AText: string);
begin
  DebugLog('link: ' + AText);
  // the first call of a paired BookManager: in touch (not after the link
  // ended - a call that came just before Done)
  if (FLink <> nil) and (FLinkCode = '') and (Pos('/pair', AText) = 0) and (Pos('Paired with', FLinkStatus) <> 1) and
    (Pos('In touch', FLinkStatus) <> 1) then
  begin
    FLinkStatus := 'In touch with BookManager (' + Copy(AText, Pos(' from ', AText) + 6, MaxInt) + '): drop ' +
      'books on its Send to phone tab, or Send all new.';
    FLinkActive := True;
    if FMenuMode = MODE_LINK then
      ShowLinkPanel;
  end;
end;

procedure TfrmMain.LinkReceived(const AKind, AFileName: string);
begin
  DebugLog(Format('link: received %s %s (%d bytes)', [AKind, AFileName, TFile.GetSize(AFileName)]));
  Inc(FLinkReceived);
  FLinkActive := True;
  FLinkLast := ChangeFileExt(ExtractFileName(AFileName), '');
  FLinkProgress := '';
  // the library shows it now, behind the panel; with a book open, the
  // next time it shows
  if LibraryShowing and not FOpening then
    ShowLibrary;
  if FLink <> nil then
    ShowLinkPanel;
end;

procedure TfrmMain.ChooseBooksFolder;
begin
  if not BookFolderSupported then
    Exit;
  FPadMenu.Hide;
  DebugLog('books folder: the system''s folder picker');
  BookFolderChoose(
    procedure(const ATree: string)
    var
      I: Integer;
    begin
      if ATree = '' then
      begin
        DebugLog('books folder: none chosen');
        OfferBooksIfEmpty;
        Exit;
      end;
      // a folder chosen again: once
      for I := 0 to High(FBooksTrees) do
        if SameText(FBooksTrees[I], ATree) then
        begin
          ShowLibrary;
          Exit;
        end;
      FBooksTrees := FBooksTrees + [ATree];
      SaveSettings;
      DebugLog('books folder: ' + BookFolderName(ATree) + ' (' + ATree + ')');
      // its books into the library (read one at a time, as any new books)
      ShowLibrary;
    end);
end;

procedure TfrmMain.ShowBooksMenu;
var
  Items: TArray<TPadMenuItem>;
  Files, More, Names, Cards: TArray<string>;
  I, J, Sel: Integer;
  Rel, Built, Foot: string;
  Have: Boolean;
begin
  FMenuMode := MODE_BOOKS;
  FBookFiles := nil;
  Files := nil;
  More := nil;
  try
    if TDirectory.Exists(FBooksFolder) then
      Files := TDirectory.GetFiles(FBooksFolder, '*.epub', TSearchOption.soAllDirectories);
  except
    on E: Exception do
      DebugLog('books folder: ' + E.Message);
  end;
  // EpubBuilder's output folder too, when it is another one
  Built := BuilderOutputFolder;
  if (Built <> '') and not SameFileName(ExcludeTrailingPathDelimiter(ExpandFileName(Built)),
    ExcludeTrailingPathDelimiter(ExpandFileName(FBooksFolder))) then
  try
    if TDirectory.Exists(Built) then
      More := TDirectory.GetFiles(Built, '*.epub', TSearchOption.soAllDirectories);
  except
    on E: Exception do
      DebugLog('EpubBuilder''s output folder: ' + E.Message);
  end
  else
    Built := '';
  // memory cards: their Books and Transcribed folders (uCards)
  Cards := CardFolders(CARD_BOOKS) + CardFolders(CARD_TRANSCRIBED);
  for I := 0 to High(Cards) do
  try
    More := More + TDirectory.GetFiles(Cards[I], '*.epub', TSearchOption.soAllDirectories);
  except
    on E: Exception do
      DebugLog('books folder: ' + Cards[I] + ': ' + E.Message);
  end;
  for I := 0 to High(More) do
  begin
    // a book in both (the books folder inside the output folder, or so)
    Have := False;
    for J := 0 to High(Files) do
      if SameFileName(ExpandFileName(Files[J]), ExpandFileName(More[I])) then
        Have := True;
    if not Have then
      Files := Files + [More[I]];
  end;
  // the name each shows: its path in the books folder; EpubBuilder's books
  // marked as such
  SetLength(Names, Length(Files));
  for I := 0 to High(Files) do
  begin
    Names[I] := '';
    // a card's: "<card>: <its path in the card's folder>"
    for J := 0 to High(Cards) do
      if Files[I].StartsWith(IncludeTrailingPathDelimiter(Cards[J])) then
        Names[I] := CardName(CardOf(Cards[J])) + ': ' +
          ChangeFileExt(ExtractRelativePath(IncludeTrailingPathDelimiter(Cards[J]), Files[I]), '');
    if Names[I] <> '' then
      Continue;
    if (Built <> '') and Files[I].StartsWith(IncludeTrailingPathDelimiter(Built)) then
      Names[I] := ChangeFileExt(ExtractRelativePath(IncludeTrailingPathDelimiter(Built), Files[I]), '')
    else
      Names[I] := ChangeFileExt(ExtractRelativePath(IncludeTrailingPathDelimiter(FBooksFolder), Files[I]), '');
  end;
  // by name, as a person reads them (sub-folders' books by their path)
  for I := 1 to High(Files) do
    for J := I downto 1 do
      if CompareText(Names[J - 1], Names[J]) > 0 then
      begin
        Rel := Names[J - 1];
        Names[J - 1] := Names[J];
        Names[J] := Rel;
        Rel := Files[J - 1];
        Files[J - 1] := Files[J];
        Files[J] := Rel;
      end
      else
        Break;
  FBookFiles := Files;
  Sel := 0;
  SetLength(Items, Length(FBookFiles));
  for I := 0 to High(FBookFiles) do
  begin
    Items[I] := TPadMenu.Item(Names[I]);
    if ((Built <> '') and FBookFiles[I].StartsWith(IncludeTrailingPathDelimiter(Built))) or
      (FBookFiles[I].Contains(PathDelim + CARD_TRANSCRIBED + PathDelim) and (CardOf(FBookFiles[I]) <> '')) then
      Items[I].Value := 'made by EpubBuilder';
    if (FBookFile <> '') and SameFileName(ExpandFileName(FBookFiles[I]), FBookFile) then
    begin
      Items[I].Value := 'open';
      Sel := I;
    end;
  end;
  if Length(Items) = 0 then
    Items := [TPadMenu.Item('No books there yet - copy EPUB files into the folder below')];
  if Built <> '' then
    DebugLog(Format('books folder: %d book(s) in %s and EpubBuilder''s output %s', [Length(FBookFiles),
      FBooksFolder, Built]))
  else
    DebugLog(Format('books folder: %d book(s) in %s', [Length(FBookFiles), FBooksFolder]));
  PadMenuColors;
  // the foot says where the books are: where to copy more
  Foot := FBooksFolder;
  if Built <> '' then
    Foot := Foot + '  +  EpubBuilder''s output';
  FPadMenu.Show('Open a book', Items, Sel, Foot);
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
  if FMenuMode = MODE_LINK then
  begin
    // the rows: [Refuse,] Cancel, Done
    if FLinkCode = '' then
      Inc(AIndex);
    case AIndex of
      0:
        begin
          // Refuse: BookManager is told, the link stays
          if FLink <> nil then
            FLink.RefusePair;
          DebugLog('link: pairing refused here');
          FLinkCode := '';
          FLinkStatus := 'Refused. Waiting for BookManager...';
          ShowLinkPanel;
        end;
      1:
        // Cancel: back to where books come from
        LinkCancel;
    else
      // Done: only once something happened (faded until then)
      if FLinkActive then
      begin
        StopLink('Done');
        FPadMenu.Hide;
        OfferBooksIfEmpty;
      end;
    end;
    Exit;
  end;
  if FMenuMode = MODE_START then
  begin
    case AIndex of
      START_LINK:
        StartLink;
      START_FOLDER:
        ChooseBooksFolder;
    end;
    Exit;
  end;
  if FMenuMode = MODE_FOLDERS then
  begin
    if AIndex <= High(FBooksTrees) then
      ShowFolder(AIndex)
    else if AIndex = Length(FBooksTrees) then
      ChooseBooksFolder
    else if AIndex = Length(FBooksTrees) + 1 then
      StartLink
    else
    begin
      FPadMenu.Hide;
      OfferBooksIfEmpty;
    end;
    Exit;
  end;
  if FMenuMode = MODE_FOLDER then
  begin
    if AIndex = 0 then
    begin
      FPadMenu.Hide;
      RemoveBooksFolder(FFolderShown);
    end
    else
      ShowFoldersMenu;
    Exit;
  end;
  if FMenuMode = MODE_ABOUT then
  begin
    if AIndex = ABOUT_LICENCES then
      ShowLicencesMenu(0)
    else
    begin
      FPadMenu.Hide;
      OfferBooksIfEmpty;
    end;
    Exit;
  end;
  if FMenuMode = MODE_LICENCES then
  begin
    if AIndex <= High(FLicences) then
      ShowLicence(AIndex, 0)
    else
      ShowAbout;
    Exit;
  end;
  if FMenuMode = MODE_LICENCE then
  begin
    if (Length(FLicencePages) > 1) and (AIndex = 0) then
      ShowLicence(FLicence, (FLicencePage + 1) mod Length(FLicencePages))
    else
      ShowLicencesMenu(FLicence);
    Exit;
  end;
  if FMenuMode = MODE_NOTE then
  begin
    // OK: back to the library's offer when it is still empty
    FPadMenu.Hide;
    OfferBooksIfEmpty;
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
        OfferBooksIfEmpty;
      end;
    MENU_OPEN:
      if BookFolderSupported then
        ShowFoldersMenu
      else
        ShowBooksMenu;
    MENU_LINK:
      if BookFolderSupported then
        StartLink
      else
        ShowNote('Get books from BookManager', 'BookManager sends books to EpubReader on a phone or a ' +
          'tablet. Here, books come from the Books folder (Open a book) and EpubBuilder''s Transcribed ' +
          'folder.');
    MENU_LIBRARY:
      begin
        FPadMenu.Hide;
        if not LibraryShowing then
          ShowLibrary;
      end;
    MENU_SORT:
      begin
        // a tap (or Select) is a step - the menu stays, the library behind
        // it is in the new order
        if FLibrarySort = High(TLibrarySort) then
          SetLibrarySort(Low(TLibrarySort))
        else
          SetLibrarySort(Succ(FLibrarySort));
        // the library made again is in front: the menu over it again
        ShowPadMenu;
        FPadMenu.Move(MENU_SORT);
      end;
    MENU_CONTENTS:
      if (EpubUnum1.Book <> nil) and not LibraryShowing then
        ShowContentsMenu;
    MENU_SIZE, MENU_SPEED:
      // a value: left / right change it; choosing it closes the menu.
      // By touch there is no left / right: a tap is a step
      if TouchBuild then
        TouchMenuStep(AIndex)
      else
        FPadMenu.Hide;
    MENU_DARK:
      begin
        btnDarkClick(nil);
        // the box in the new colours
        ShowPadMenu;
        FPadMenu.Move(MENU_DARK);
      end;
    MENU_HIGHLIGHT:
      // a tap (or Select) is a step - the menu stays
      StepHighlight(1);
    MENU_HIGH_TYPE:
      if FHighUnit <> huWord then
      begin
        SetHighlight(FHighUnit, not FHighTrailing, FHighWord);
        FPadMenu.SetValue(MENU_HIGH_TYPE, PadMenuValue(MENU_HIGH_TYPE));
      end;
    MENU_HIGH_WORD:
      if FHighUnit <> huWord then
      begin
        SetHighlight(FHighUnit, FHighTrailing, not FHighWord);
        FPadMenu.SetValue(MENU_HIGH_WORD, PadMenuValue(MENU_HIGH_WORD));
      end;
    MENU_LEARN:
      if EpubUnum1.Book <> nil then
      begin
        btnLearnClick(nil);
        FPadMenu.SetValue(MENU_LEARN, PadMenuValue(MENU_LEARN));
      end;
    MENU_CONTROLS: ShowControlsMenu;
    MENU_COVER:
      begin
        FPadMenu.Hide;
        ShowCoverChoice;
      end;
    MENU_ABOUT: ShowAbout;
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
  // a tap beside the box: "No books yet" stays (without a book there is
  // nothing behind it; owner, zip 345: "you should have to load a book");
  // the link panel too (Done ends the link)
  if FMenuMode in [MODE_START, MODE_LINK] then
    Exit;
  FPadMenu.Hide;
  OfferBooksIfEmpty;
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
    MENU_HIGHLIGHT:
      begin
        StepHighlight(ADelta);
        Exit;
      end;
    MENU_HIGH_TYPE:
      if FHighUnit <> huWord then
        SetHighlight(FHighUnit, not FHighTrailing, FHighWord);
    MENU_SORT:
      begin
        SetLibrarySort(TLibrarySort((Ord(FLibrarySort) + ADelta + Ord(High(TLibrarySort)) + 1) mod
          (Ord(High(TLibrarySort)) + 1)));
        // the library made again is in front: the menu over it again
        ShowPadMenu;
        FPadMenu.Move(MENU_SORT);
        Exit;
      end;
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
  // the link: no more announcing, no more uploads
  StopLink('closing');
  StopPlaying;
  // where the reader left off, and the settings
  RememberBook;
  SaveSettings;
  DebugLog('closing: place and settings saved');
  FreeAndNil(FUnitLayout);
  FreeAndNil(FPlayer);
  DebugLog('closing: sound player freed');
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
  // Android's Back: out of the menu; from the library to the open book;
  // from the book to the library. Not taken in the library with no book
  // open: the system then leaves the app, as Back does everywhere
  if Key = vkHardwareBack then
  begin
    // "No books yet": Back leaves the app, as with an empty library
    if (FPadMenu <> nil) and FPadMenu.Showing and (FMenuMode = MODE_START) then
      Exit;
    if ((FPadMenu <> nil) and FPadMenu.Showing) or (LibraryShowing and (EpubUnum1.Book <> nil)) then
      Key := vkEscape
    else if (EpubUnum1.Book <> nil) and not LibraryShowing then
    begin
      ShowLibrary;
      Key := 0;
      Exit;
    end
    else
      Exit;
  end;
  // the pad's menu with the keyboard too: arrows, Enter, Esc
  if (FPadMenu <> nil) and FPadMenu.Showing then
  begin
    // the menu's foot names the keys now
    SetPadKeys(True);
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
var
  Ticket, PDoc, PWord, K: Integer;
  Name, Path: string;
  Staged: Boolean;
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
  FHiUnit := -1;
  FChapterWord := nil;
  FChapterToc := nil;
  FChapterDoc := nil;
  FChapterTitle := nil;
  FTocIsChapters := False;
  EpubUnum1.Active := False;
  if TouchBuild then
  begin
    // A phone (zip 327): the book is read in a thread - 4.5 s for a long
    // one, in which Android offers to close an app that does not answer -
    // and OpenDone makes it the open book. The window stays alive: the
    // library says "Opening ..." (CoverChosen), or the page is empty.
    Inc(FOpenTicket);
    FOpening := True;
    Ticket := FOpenTicket;
    Name := AFileName;
    View1.Clear;
    HidePreview;
    // THE STAGED OPEN (zip 332): a book with no index yet takes seconds
    // to read - its package is read first (milliseconds) and the page it
    // was left at shown from that alone; the rest follows behind it. With
    // an index the whole book is there in a moment, and no stage is
    // needed.
    Staged := not FileExists(BookIndexFile(AFileName));
    PDoc := -1;
    PWord := -1;
    K := RecentIndex(AFileName);
    if (K >= 0) and (FRecent[K].Doc >= 0) then
    begin
      PDoc := FRecent[K].Doc;
      PWord := FRecent[K].DocWord;
    end;
    UpdateControls;
    // where to read it: a book of the chosen folder is opened by Android
    // here, in the window's thread (Java), and read in the thread below
    try
      Path := BookOpenPath(AFileName);
    except
      on E: Exception do
      begin
        FOpening := False;
        DebugLog('open: ' + AFileName + ' - ' + E.Message);
        EpubUnum1OpenFailed(EpubUnum1, E.Message);
        ShowLibrary;
        Exit;
      end;
    end;
    TThread.CreateAnonymousThread(
      procedure
      var
        Book: TEpubBook;
        Err: string;
        CF, CL: TArray<Integer>;
        C, F, L: Integer;
        Note: string;
        Header: TEpubBook;
      begin
        Book := nil;
        Err := '';
        Note := '';
        if Staged then
          try
            Header := TEpubBook.CreateHeader(Path);
            TThread.Queue(nil,
              procedure
              begin
                PreviewReady(Header, PDoc, PWord, Ticket);
              end);
          except
            // no page first: the whole book says what is wrong with it
            Header := nil;
          end;
        try
          // with its words (the reader needs them at once) - from the
          // book's index when it has one (zip 330)
          Book := OpenBookIndexed(Name, Path, Note);
          // and each clip's words (zip 329: 0.1 s less in the window's
          // thread)
          SetLength(CF, Length(Book.Clips));
          SetLength(CL, Length(Book.Clips));
          for C := 0 to High(CF) do
            if Book.ClipWords(C, F, L) then
            begin
              CF[C] := F;
              CL[C] := L;
            end
            else
            begin
              CF[C] := -1;
              CL[C] := -1;
            end;
        except
          on E: Exception do
          begin
            Err := E.Message;
            FreeAndNil(Book);
          end;
        end;
        TThread.Queue(nil,
          procedure
          begin
            if Note <> '' then
              DebugLog(Note);
            OpenDone(Name, Book, Err, Ticket, CF, CL);
          end);
      end).Start;
    Exit;
  end;
  EpubUnum1.FileName := AFileName;
  EpubUnum1.Active := True;   // OnOpen or OnOpenFailed follows
  UpdateControls;
end;

procedure TfrmMain.PreviewReady(AHeader: TEpubBook; ADoc, AWord, ATicket: Integer);
var
  I: Integer;
begin
  // too late (the whole book is there) or for a book no longer wanted
  if (ATicket <> FOpenTicket) or not FOpening then
  begin
    AHeader.Free;
    Exit;
  end;
  if FPreviewView = nil then
  begin
    FPreviewEpub := TEpubUnum.Create(Self);
    FPreviewView := TEpubView.Create(Self);
    FPreviewView.Parent := View1;
    FPreviewView.Align := TAlignLayout.Client;
    FPreviewView.HitTest := False;
    FPreviewView.Epub := FPreviewEpub;
  end;
  // the page's look
  FPreviewView.FontFamily := View1.FontFamily;
  FPreviewView.FontSize := View1.FontSize;
  FPreviewView.LineHeight := View1.LineHeight;
  FPreviewView.Justify := View1.Justify;
  FPreviewView.ParagraphSpacing := View1.ParagraphSpacing;
  FPreviewView.PageMargin := View1.PageMargin;
  FPreviewView.ShowProgress := View1.ShowProgress;
  FPreviewView.TextColor := View1.TextColor;
  FPreviewView.BackgroundColor := View1.BackgroundColor;
  FPreviewView.LinkColor := View1.LinkColor;
  FPreviewView.NoteColor := View1.NoteColor;
  FPreviewEpub.Adopt(AHeader);   // the component frees it
  // no place kept: the first document of the reading order
  if (ADoc < 0) or (ADoc > High(AHeader.Documents)) then
  begin
    ADoc := 0;
    AWord := -1;
    for I := 0 to High(AHeader.Documents) do
      if AHeader.Documents[I].Linear then
      begin
        ADoc := I;
        Break;
      end;
  end;
  // the library (it says "Opening ...") makes way for the page
  HideLibrary;
  FPreviewView.Visible := True;
  FPreviewView.BringToFront;
  FPreviewView.ShowPreview(ADoc, AWord);
  DebugLog(Format('open: a page shown from the package alone (document %d, word %d of it) - the book is ' +
    'still being read', [ADoc, AWord]));
end;

procedure TfrmMain.HidePreview;
begin
  if FPreviewView = nil then
    Exit;
  FPreviewView.Visible := False;
  FPreviewView.Clear;
  FPreviewEpub.Close;
end;

procedure TfrmMain.OpenDone(const AFileName: string; ABook: TEpubBook; const AError: string; ATicket: Integer;
  const AClipFirst, AClipLast: TArray<Integer>);
begin
  if ATicket <> FOpenTicket then
  begin
    // another book was asked for meanwhile: this one is not wanted
    DebugLog('open: ' + AFileName + ' read, but another book was asked for - dropped');
    ABook.Free;
    Exit;
  end;
  FOpening := False;
  if ABook = nil then
  begin
    HidePreview;
    EpubUnum1OpenFailed(EpubUnum1, AError);
    // back to the library (its covers were faded for "Opening ...", or
    // the staged page had taken its place)
    ShowLibrary;
    Exit;
  end;
  DebugLog('open: read in its thread');
  FClipFirst := AClipFirst;
  FClipLast := AClipLast;
  FClipsReady := True;
  EpubUnum1.Adopt(ABook);   // OnOpen follows
  // the real page is laid out at the same place: the staged one goes
  HidePreview;
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
  K, Big, Back: Integer;
begin
  DebugLog('open: read, building the view');
  // its documents' layouts kept beside its index (index\<md5>.<n>.eul):
  // a chapter shown again is read back, not parsed and walked (zip 351) -
  // set before any document is shown
  EpubUnum1.Book.LayoutCache := ChangeFileExt(BookIndexFile(BookStableName(EpubUnum1.FileName)), '');
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
  // each clip's words - done already when the book was read in a thread
  // (OpenBook, zip 329)
  if not FClipsReady or (Length(FClipFirst) <> Length(B.Clips)) then
  begin
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
  end;
  FClipsReady := False;
  DebugLog('open: the clips'' words known');
  // The chapters: kept from the last opening when the book came from its
  // index (zip 333). Working them out lays out every document a chapter
  // mark falls in - 1.5 s of Night Watch's 2.4 s on the Pixel, in the
  // window's thread, and all of it the XML the index had saved reading.
  if LoadChapters then
    DebugLog(Format('open: %d chapters from last time', [Length(FChapterWord)]))
  else
  begin
    BuildChapters;
    SaveChapters;
    DebugLog('open: chapters built');
  end;
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
  DebugLog('open: notes menu built');
  // the first linear document with words
  First := 0;
  for I := 0 to High(B.Documents) do
    if B.Documents[I].Linear and (B.Documents[I].WordCount > 0) then
    begin
      First := I;
      Break;
    end;
  // A book read before goes back to where it was left - and its first
  // document was laid out here first, only to be dropped (zip 329; part
  // of 0.8 s on the Pixel). Now the first document is laid out only when
  // there is no place to go back to.
  // (the book's name: a book of a chosen folder was opened from the path
  // Android gave - BookStableName gives its address back)
  I := RecentIndex(BookStableName(EpubUnum1.FileName));
  Back := -1;
  if (I >= 0) and (FRecent[I].Word >= 0) and (FRecent[I].Word < B.WordCount) then
    Back := FRecent[I].Word;
  if Back < 0 then
  begin
    View1.ShowDocument(First);
    DebugLog('open: the first document laid out');
  end;
  // this book now: first in Recently Opened, and back where it was left
  FBookFile := BookStableName(EpubUnum1.FileName);
  if not IsBookAddress(FBookFile) then
    FBookFile := ExpandFileName(FBookFile);
  // its cover for the library (made once, cached)
  EnsureCover(FBookFile, B, B.Title);
  // each step logged: the Steam Deck crash comes after the cover (2026-11-17)
  DebugLog('open: cover done, hiding the library');
  HideLibrary;
  if Back >= 0 then
  begin
    DebugLog(Format('open: back to word %d (lays the page out)', [Back]));
    RestoreWord(Back);
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

{ The file the chapters of ABookFile are kept in: beside its index. }
function BookChaptersFile(const ABookFile: string): string;
begin
  Result := ChangeFileExt(BookIndexFile(ABookFile), '.chapters.json');
end;

function TfrmMain.LoadChapters: Boolean;
var
  B: TEpubBook;
  F, Ix: string;
  V: TJSONValue;
  O, E: TJSONObject;
  A: TJSONArray;
  I, N, W, T, D: Integer;
  Title: string;
  Words, Tocs, Docs, Breaks: TArray<Integer>;
  Titles: TArray<string>;
begin
  Result := False;
  B := EpubUnum1.Book;
  if (B = nil) or not B.FromIndex then
    Exit;
  F := BookChaptersFile(BookStableName(EpubUnum1.FileName));
  Ix := BookIndexFile(BookStableName(EpubUnum1.FileName));
  V := nil;
  try
    try
      if not FileExists(F) or not FileExists(Ix) or (TFile.GetLastWriteTime(F) < TFile.GetLastWriteTime(Ix)) then
        Exit;
      V := TJSONObject.ParseJSONValue(TFile.ReadAllText(F, TEncoding.UTF8));
      if not (V is TJSONObject) then
        Exit;
      O := TJSONObject(V);
      // of this book as it is now
      if (O.GetValue<Integer>('version', 0) <> 1) or (O.GetValue<Integer>('words', -1) <> B.WordCount) or
        (O.GetValue<Integer>('clips', -1) <> Length(B.Clips)) or
        (O.GetValue<Integer>('contents', -1) <> Length(B.Toc)) then
        Exit;
      if not O.TryGetValue<TJSONArray>('chapters', A) then
        Exit;
      N := A.Count;
      SetLength(Words, N);
      SetLength(Tocs, N);
      SetLength(Docs, N);
      SetLength(Titles, N);
      for I := 0 to N - 1 do
      begin
        if not (A.Items[I] is TJSONObject) then
          Exit;
        E := TJSONObject(A.Items[I]);
        W := E.GetValue<Integer>('word', -1);
        T := E.GetValue<Integer>('toc', -1);
        D := E.GetValue<Integer>('doc', -1);
        Title := E.GetValue<string>('title', '');
        if (W < 0) or (W >= B.WordCount) or (T < -1) or (T > High(B.Toc)) or (D < 0) or
          (D > High(B.Documents)) then
          Exit;
        Words[I] := W;
        Tocs[I] := T;
        Docs[I] := D;
        Titles[I] := Title;
      end;
      Breaks := nil;
      if O.TryGetValue<TJSONArray>('breaks', A) then
        for I := 0 to A.Count - 1 do
          Breaks := Breaks + [A.Items[I].GetValue<Integer>];
      FChapterWord := Words;
      FChapterToc := Tocs;
      FChapterDoc := Docs;
      FChapterTitle := Titles;
      FTocIsChapters := O.GetValue<Boolean>('tocIsChapters', False);
      FChapterSource := O.GetValue<string>('source', '');
      View1.ChapterBreaks := Breaks;
      Result := True;
    except
      on Ex: Exception do
      begin
        // not readable: built again
        DebugLog('chapters: the kept ones not read - ' + Ex.Message);
        Result := False;
      end;
    end;
  finally
    V.Free;
  end;
end;

procedure TfrmMain.SaveChapters;
var
  B: TEpubBook;
  F: string;
  O, E: TJSONObject;
  A: TJSONArray;
  I: Integer;
  Breaks: TArray<Integer>;
begin
  B := EpubUnum1.Book;
  if (B = nil) or not FileExists(BookIndexFile(BookStableName(EpubUnum1.FileName))) then
    Exit;
  F := BookChaptersFile(BookStableName(EpubUnum1.FileName));
  O := TJSONObject.Create;
  try
    try
      O.AddPair('version', TJSONNumber.Create(1));
      O.AddPair('words', TJSONNumber.Create(B.WordCount));
      O.AddPair('clips', TJSONNumber.Create(Length(B.Clips)));
      O.AddPair('contents', TJSONNumber.Create(Length(B.Toc)));
      O.AddPair('tocIsChapters', TJSONBool.Create(FTocIsChapters));
      O.AddPair('source', FChapterSource);
      A := TJSONArray.Create;
      O.AddPair('chapters', A);
      for I := 0 to High(FChapterWord) do
      begin
        E := TJSONObject.Create;
        E.AddPair('word', TJSONNumber.Create(FChapterWord[I]));
        E.AddPair('toc', TJSONNumber.Create(FChapterToc[I]));
        E.AddPair('doc', TJSONNumber.Create(FChapterDoc[I]));
        E.AddPair('title', FChapterTitle[I]);
        A.AddElement(E);
      end;
      A := TJSONArray.Create;
      O.AddPair('breaks', A);
      Breaks := View1.ChapterBreaks;
      for I := 0 to High(Breaks) do
        A.Add(Breaks[I]);
      TFile.WriteAllText(F, O.ToJSON, TEncoding.UTF8);
    except
      on Ex: Exception do
        DebugLog('chapters: not kept - ' + Ex.Message);
    end;
  finally
    O.Free;
  end;
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
    ShowReadHighlight(FClipFirst[AClip], FClipLast[AClip]);
    // the layout itself happens here (ScrollToWord lays the document out)
    View1.ScrollToWord(FClipFirst[AClip], True);
    SyncToc(FClipFirst[AClip]);
  end;
  DebugLog(Format('go to clip %d: shown (%d blocks, %d laid out)', [AClip, LayoutBlocks, View1.LaidOutBlocks]));
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
begin
  Result := IsUnitStartOf(AWord, StepUnit);
end;

function TfrmMain.IsUnitStartOf(AWord, AUnit: Integer): Boolean;
var
  B: TEpubBook;
begin
  B := EpubUnum1.Book;
  if AWord <= 0 then
    Exit(True);
  if B.Words[AWord - 1].Document <> B.Words[AWord].Document then
    Exit(True);
  if (AUnit <> UNIT_PARAGRAPH) and EpubEndsSentence(B.Words[AWord - 1].Text) then
    Exit(True);
  if (AUnit = UNIT_PHRASE) and EndsPhrase(B.Words[AWord - 1].Text) then
    Exit(True);
  Result := WordBlock(AWord - 1) <> WordBlock(AWord);
end;

function TfrmMain.UnitStart(AWord: Integer): Integer;
begin
  Result := UnitStartOf(AWord, StepUnit);
end;

function TfrmMain.UnitEnd(AWord: Integer): Integer;
begin
  Result := UnitEndOf(AWord, StepUnit);
end;

function TfrmMain.UnitStartOf(AWord, AUnit: Integer): Integer;
begin
  Result := AWord;
  while not IsUnitStartOf(Result, AUnit) do
    Dec(Result);
end;

function TfrmMain.UnitEndOf(AWord, AUnit: Integer): Integer;
var
  B: TEpubBook;
begin
  B := EpubUnum1.Book;
  Result := AWord;
  while (Result + 1 < B.WordCount) and not IsUnitStartOf(Result + 1, AUnit) do
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
  Offset, Size: Int64;
  InBook: Boolean;
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
      // A player that plays a part of a file (Android's) plays the audio
      // where it lies in the book: no copy. Zip 321 - copying a 900 MB
      // m4b took the phone nine seconds in the window's thread, and
      // Android offered to close the app ("isn't responding").
      InBook := False;
      if AudioInBook(B.Zip, C.AudioPath, Offset, Size) then
        try
          InBook := FPlayer.OpenPart(B.Zip.FileName, Offset, Size);
          if InBook then
            DebugLog(Format('clip %d: playing %s inside the book (%d bytes at %d), no copy', [AClip, C.AudioPath,
              Size, Offset]));
        except
          on E: Exception do
          begin
            // the copy is tried instead
            InBook := False;
            DebugLog(Format('clip %d: not played inside the book - %s', [AClip, E.Message]));
          end;
        end;
      if not InBook then
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
      end;
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
  View1.HighlightUnit(-1, -1);
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
    View1.UnitHighlightColor := DARK_UNIT_HIGHLIGHT;
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
    View1.UnitHighlightColor := UNIT_HIGHLIGHT;
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
  else if TouchBuild then
  begin
    // behind the system's bars and the touch bar: the page's colour
    Fill.Kind := TBrushKind.Solid;
    Fill.Color := View1.BackgroundColor;
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
      ShowReadHighlight(FClipFirst[AClip], FClipLast[AClip]);
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

procedure TfrmMain.View1Edge(Sender: TObject; AForward: Boolean);
var
  B: TEpubBook;
  D, Step: Integer;
begin
  B := EpubUnum1.Book;
  if (B = nil) or LibraryShowing or (View1.Document < 0) then
    Exit;
  // the next (or previous) document of the reading order - a foreword,
  // a part's title page, a chapter: all of the book can be read by
  // scrolling, without the sound (owner, 2026-11-26: the page stopped at
  // the end of a foreword until its last words were played)
  if AForward then
    Step := 1
  else
    Step := -1;
  D := View1.Document;
  repeat
    Inc(D, Step);
  until (D < 0) or (D > High(B.Documents)) or B.Documents[D].Linear;
  if (D < 0) or (D > High(B.Documents)) then
    Exit;
  if AForward then
    DebugLog(Format('scrolled on: document %d, from its start', [D]))
  else
    DebugLog(Format('scrolled back: document %d, from its end', [D]));
  // paused: Play starts with what is shown now, not with a jump made
  // before (playing, the sound goes on and the page follows it again)
  if not FPlaying then
    FSeekClip := -1;
  View1.ShowDocument(D, not AForward);
  if B.Documents[D].WordCount > 0 then
    SyncToc(B.Documents[D].FirstWord);
end;

procedure TfrmMain.View1DocumentChange(Sender: TObject);
var
  B: TEpubBook;
  T: TEpubLayoutTimes;
begin
  // where the time of the document's layout went (zip 338): the view's
  // own laying out comes after this line, up to "shown"
  B := EpubUnum1.Book;
  if B <> nil then
  begin
    T := B.LastLayoutTimes;
    if T.Cached then
      DebugLog(Format('document %d: its layout read back from the cache in %d ms (%d blocks)', [T.Doc, T.ReadMs,
        LayoutBlocks]))
    else
      DebugLog(Format('document %d: its layout made in %d ms - unzipped %d, parsed %d, style sheets %d, blocks ' +
        '%d (%d blocks); kept in %d ms', [T.Doc, T.ReadMs + T.ParseMs + T.StyleMs + T.WalkMs, T.ReadMs, T.ParseMs,
        T.StyleMs, T.WalkMs, LayoutBlocks, T.SaveMs]));
  end;
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
      ShowReadHighlight(FClipFirst[C], FClipLast[C]);
      View1.ScrollToWord(FClipFirst[C], True);
      SyncToc(FClipFirst[C]);
    end;
    if FClip = C then
      DebugLog(Format('clip %d: shown (%d blocks, %d laid out)', [C, LayoutBlocks, View1.LaidOutBlocks]));
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
  // the touch bar's three follow the tool bar's
  if btnTouchPlay <> nil then
  begin
    btnTouchPlay.Enabled := btnPlay.Enabled;
    btnTouchPrevClip.Enabled := btnPlay.Enabled;
    btnTouchNextClip.Enabled := btnPlay.Enabled;
    if FPlaying then
      SetIcon(btnTouchPlay, ICON_PAUSE)
    else
      SetIcon(btnTouchPlay, ICON_PLAY);
  end;
  if LibraryShowing and TouchBuild then
    S := 'Library - tap a cover to read'
  else if LibraryShowing then
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
