# EpubReader

The end-user reader: open an EPUB, read it, and - for a book with media
overlays (EPUB 3 synced audio) - listen with the words highlighted as they
are read. The page is drawn with Skia by `TEpubView`; the contents list is
on the left.

## Before the first build

**TFFMpegAPI** (github.com/G3DGames/TFFMpegAPI) plays the sound: build its
`FFmpegAPI.groupproj` first (the reader uses the runtime package FFmpegAPI's
DCUs). Then build epubunum's packages (`EpubUnum.groupproj` builds them before
the demos) and install `dclEpubUnumFMX` to open the form in the designer.
Skia is enabled for this project (Project > Enable Skia), so the IDE
deploys Skia's library (`sk4d.dll`, `libsk4d.so`, ...) next to the program.
**Do not keep the `GlobalUseSkia := True;` line** the IDE adds to the .dpr.

## Using it

| | |
|---|---|
| File > Open, Ctrl+O | choose a book |
| File > Library | the covers of the last 10 books (again: back to the page) |
| File > Recently Opened | the last 10 books, each reopened where you left off |
| File > Exit | close (the place in the book is kept) |
| Edit > Find, Ctrl+F | the find bar: words or the start of a word, anywhere in the book; Enter / F3 next, Shift+Enter / Shift+F3 previous, Esc closes. A match is lit and Play starts there |
| Contents list | jump to a chapter - the audio follows |
| bar + double triangle | previous / next chapter (contents entries; documents when there are none; the audiobook's chapters when the contents list has no chapters that are read - see below); the audio moves to the chapter's first clip - playing on when playing, else Play starts there. Previous goes to the start of the chapter being read, pressed at its start to the one before |
| triangle + bar | previous / next sentence or paragraph (the drop-down beside them), whatever the clips are (a word-level book has one per word). Previous: the start of the sentence being read; within 1.5 s of that start, the one before |
| moon, D | dark mode (page, window, contents; the buttons keep the platform style) |
| Play / Pause, P | play or pause the book's audio (books with media overlays) |
| Abc, L | Learn to read on / off (below) |
| speed slider, [ / ] | playing speed 0.5x - 1.5x in steps of 0.1, the pitch kept (FFmpeg's atempo: needs `swscale-9.dll` and `avfilter-11.dll`); click the `1.0x` label for normal speed; the new speed starts when the slider stops moving |
| click a word | play from there |
| A- / A+, Ctrl+Minus / Ctrl+Plus | text size |
| wheel, arrows, Page Up / Page Down, Space, Home / End | scroll |

### Learn to read

With **Abc** (or L) pressed, the steps drop-down offers Phrase,
Sentence and Paragraph (Phrase chosen: the words between two marks of
punctuation - , ; : . ! ? or a dash - shorter than a sentence for a
learner) and the triangle + bar buttons work differently:
Next / Previous move to the next / previous unit, light it, SAY it and
stop - what is seen is what is heard. Play (or P, or R) says the
highlighted words again - it does not read on; clicking a word picks
the phrase, sentence or paragraph it is in (the drop-down) and says it,
so a hard passage can be clicked and then played as often as needed. Turned on after a pause, Next goes on from where reading stopped.
The mode shows: a green band behind the tool bar, a green highlight
(amber when reading), "LEARN TO READ" in the title and the status line. Words the
recording does not read are lit with no sound. The same mode serves for proof-reading a
book's timings by ear.

Footnotes, endnotes and asides have a background of their own (a shade
darker than the page; dark grey-blue in dark mode), so they can be told
from the text. A note is what the book marks as one (an `aside`, or
`epub:type` / `class` footnote, endnote or note), or the paragraph a
footnote marker links to - an asterisk, a dagger or a raised number
that is a link (a link back from the note to its marker is ignored).

The highlight covers the word, not the punctuation around it: in
"whales," the comma is not lit.

**Highlight** (the menu; on a desktop View > Highlight) says what is lit
while the book is read aloud: the Word, or the Phrase or the Sentence it
is in. With a phrase or sentence, **Highlight type** is All (the whole
of it) or Trailing (only up to the word being read), and **Highlight
word** On lights the phrase / sentence pale and the word over it in the
highlight colour (Off: all of it in the highlight colour). With Word the
two are faded and do nothing. Learn to read keeps its own highlighting.

Copy-protected books are refused with a message.

## Remembered between runs

The reader keeps, in `EpubReader.json` (`%APPDATA%\EpubReader` on
Windows, `~/Library/Application Support/EpubReader` on macOS,
`~/.config/EpubReader` on Linux): dark mode, text size, speed, and the
last 10 books with the place you left each one. `"debug": true` (set by
hand in the file; false otherwise) shows debugging aids such as File >
Go to Footnote - a list of the book's notes. Any book opens where you
left it - the sentence lit, and Play starts there. Books are matched by
file name for now (a book moved to another folder keeps its place).

## Graphics (Windows)

View > Graphics stores Windows' graphics preference for the reader (as
Settings > System > Display > Graphics does): Windows decides, the power
saving GPU (a laptop's integrated one - longer on battery), or the high
performance GPU. Windows uses it from the reader's next start.

## Screen kept on while it reads aloud

While the audio plays, EpubReader asks the system to keep the screen on
and not sleep (Windows: SetThreadExecutionState; macOS: an IOKit power
assertion; Linux: systemd-logind's inhibitor plus
org.freedesktop.ScreenSaver over D-Bus). SteamOS in Game Mode otherwise
dims, then sleeps, with nobody touching the controller. Pause lets it
idle again. The debug log has a "screen:" line saying how it was asked.

Game Mode (gamescope) can show the window black after Steam's screen
saver or once the display comes back on. On Linux EpubReader then draws
itself again and, in Game Mode only, changes its size by a pixel and back
(full screen, as in Big Picture: leaves full screen and goes back): when
the window is active again, when a display comes back on, and at the
first pad press after a minute without one. Steam's Big Picture on a
desktop is only drawn again (leaving full screen there would be seen and
lose the focus). The debug log says each time ("redraw: ...").

## Game pad (Steam builds)

In a Steam build EpubReader reads the pad through Steam Input, with its
own action manifest (`epubreader_controllers.vdf` and a default layout
per controller type), in `steaminput/` beside the program. The build
puts them there (Win64: tools/postbuild.bat, every configuration;
Linux64: the Deploy entries tools/deploy_redist.py writes), so they are
in the Steam depot before the program first runs - Steam may read them
before it starts. The program also carries them and writes them there
at start-up when they are missing or out of date (on the Mac beside
EpubReader.app, never inside the bundle; beside the settings when that
folder cannot be written), then gives
Steam the manifest. They are made by `tools/gen_reader_input.py` from one
table, with TSteamAPI's generator:

```
python3 tools/gen_reader_input.py
```

It finds TSteamAPI beside this repository (a folder named TSteamAPI or
steamworks); elsewhere, name it with `--tsteamapi` or the TSTEAMAPI
environment variable. The generated files are in the repository, so
this is needed only when the controls change.

| Pad | On the page | In the library | In the menu |
|---|---|---|---|
| A (bottom face button) | play / pause | open the chosen book | choose |
| B (right face button) | - | back to the book | back / close |
| X (left face button) | say it again (Learn to read) | - | - |
| Y (top face button) | dark mode | - | - |
| D-pad, left stick | up / down a little, left / right a page | choose a cover | up / down; left / right change a value |
| Right stick | scroll | - | - |
| Shoulders | sentence back / on | - | - |
| Triggers (full pull) | chapter back / on | - | - |
| Start / Menu | the menu | the menu | close |
| Select / View | the library | back to the book | the library |

The menu: Back to the book, Open a book, Get books from BookManager (a
phone; faded elsewhere), Library, Library order, Contents, Text size,
Speed, Dark mode, Highlight, Highlight type, Highlight word, Learn to read, Controls, Exit, About (the version and
the copyright, and Licences: the outside components of that build - Skia,
Skia4Delphi, FFmpeg on a desktop, Android's libraries on a phone,
Steamworks in a Steam build - each licence a page at a time; on a desktop
also Help > About EpubReader). Controls lists what each control
does, with Steam's own pictures of the buttons of the pad in hand (the
names, without Steam). Esc on the page opens the menu with the keyboard
(arrows, Enter, Esc there); a click or tap on a row works too.

In Big Picture the reader shows the page alone - no menu bar, tool bar
or contents panel: the menu has all of them, and Exit.

Steam reads a manifest's layouts once per Steam session: after a new
layout revision, restart Steam (on SteamOS, Steam or the machine). For
players, the partner site's Steam Input setting should be "Custom
Configuration (Bundled with Game)" naming
`steaminput/epubreader_controllers.vdf`.

## Books folder

Open a book (in the menu) lists the EPUB files in the books folder and
its folders - on a Steam Deck the only way to a new book, with no file
dialog to reach - and the books EpubBuilder made: its output folder (the
one in EpubBuilder's settings, else Documents/EpubUnum/Transcribed),
marked "made by EpubBuilder" - and, on Steam hardware, a memory card's
top-level Books and Transcribed folders ("<card>: <book>"). The books folder, made at start-up:

- Steam builds: `Books` beside the program (on the Mac beside
  EpubReader.app) - in Steam, the reader's Manage > Browse local files,
  then Books;
- builds without Steam: Documents/EpubUnum/Books (shared with
  EpubBuilder).

Copy books there (on a Steam Deck in Desktop Mode). Another folder can
be named in the settings file, `"booksFolder": "..."`. Uninstalling the
reader from Steam may delete a Books folder beside the program with it.

## Ended from outside (Steam's Exit Game)

Steam's Exit Game ends EpubReader with SIGTERM (Linux, macOS); so does
the system when it shuts down. EpubReader then closes as from its own
menu: the place in the book and the settings are saved. The debug log
says so, and the next start's debug log says when the last run was
ended. On Windows nothing is trapped.

## Debug log

Every run writes `EpubReader-debug.log` next to `EpubReader.json`: start
up, sound (FFmpeg and the sound output), the library and its covers,
opening a book, chapters, play and stop - each line written to the file
at once, with the time. When the reader stops responding or disappears,
the last line says where. The previous run's log is kept as
`EpubReader-debug.log.old`.

## Library

Started without a book on the command line, the reader shows the
**library** where the page goes: the covers of the last 10 books, the
current one (the last read) large, the grid as big as the window allows
and centred. Click a cover to read that book; with a book open, its own
cover or Esc goes back to it. File > Library shows it at any time. A
book that is no longer there is shown faint (a click takes it off the
list).

Each time the library shows (at start-up too), EpubBuilder's output
folder (Transcribed - or the one set in EpubBuilder) is looked through:
a book the reader has not seen there before is added to the library,
after the book read last, the newest first - so a book just built, or a
benchmark's book kept, is there when the reader opens. Each book is
added once: one taken off the list stays off (the settings keep the
names seen, "seen"); every book there is still in Open a book.

Covers are cached as PNG in a `covers` folder beside `EpubReader.json`,
named by a hash of the book's file name, at most 600 px high: the book's
own cover picture, or - when it has none, or one the reader cannot draw
(SVG) - a made cover with the title and author on a colour of the
title's own. Replace a file there to change a book's cover; delete it to
have it made again.

## A book's cover in the library

**View > Cover of this book...** (the pad: Menu > Cover of this book)
shows the open book's pictures as thumbnails - its own cover, the cover
art of the audiobook inside it (read where it lies in the book, nothing
unpacked), a picture put in Documents/EpubUnum/Covers for this book
(named as the book's file or its title: "Your picture for this book")
and a plain one with its title and author - click one, or move with the
pad and press Play. Other books' pictures and the folder's path are not
shown (zip 398; owner: "should not show path to cover or all other
books"). The one chosen becomes the book's picture in the library; the
book file is not changed (other readers still show its own). "The
book's own" puts it back.

## Chapters from the audiobook

A book made by EpubBuilder carries the recording's chapter marks (an M4B's
chapters, or one mark per audio file). When the book's contents list has
no chapters that are read aloud - Night Watch has no chapters at all,
its audiobook has 75 - the chapter buttons and the contents list use
those marks instead, together with the contents entries that are not
read (title page, about the author) and the documents no chapter starts
in, so front and back matter can still be reached. Such a chapter starts
at the beginning of the paragraph the recording's chapter starts in (the
audio from there too), and a short rule above it shows the break on the
page.

Under the text, a percentage shows how far through the book you are (by
words, so the text size does not change it; page X of Y can follow if
the view gets pages).

While the book is read aloud the line being read stays in the middle of
the window and the text scrolls up smoothly under it, a line at a time
(near the start and end of a chapter the text cannot move that far).

## Open with

At start-up the reader puts itself in the system's "Open with" list for
EPUB books, for the current user (no administrator rights): on Windows
in HKEY_CURRENT_USER\Software\Classes, on Linux as
`~/.local/share/applications/epubreader.desktop`. It only writes when the
entry is missing or points elsewhere (the program moved). To make it the
default on Windows: right-click a book, Open with, Choose another app,
EpubReader, Always - Windows lets only you make that choice.

## Running it on another Windows machine

Copy into one folder: `EpubReader.exe` (no runtime packages - the
library's DCUs are linked in), `sk4d.dll` (Skia; the IDE puts it next to
the program), and the six FFmpeg 8 libraries listed under Sound (an LGPL
build such as ffmpeg-dev's will do). Books made by EpubConsole
`--overlay` carry their audio inside, so the .epub is all the reader needs.
The program's icon is `EpubReader_Icon.ico` (Project > Options >
Application > Icons, Win64), one of the epubunum set drawn by
`tools/make_icons.py` (Pillow): an open book with a highlighted word and
a play badge - EpubBuilder's has a sound wave and a gear, BookManager's
books on a shelf and arrows.

## Platform notes (from TSteamAPI)

The files in `src/` named `Fmx*.pas` are **unchanged copies** of
TSteamAPI's (github.com/G3DGames/TSteamAPI, `docs/`); `EpubReader.sh` is
TSteamAPI's launcher with one addition (below, FreeType):

- **Linux in Steam's runtime / SteamOS:** use Steam Linux Runtime 3.0;
  `FmxLinuxGtkGlobal` makes GTK globally visible (otherwise "access
  violation at address 0" with a TListBox); ship `EpubReader.sh` (the ICU
  launcher, LF line endings) as the Linux launch command (otherwise exit
  code 139 on SteamOS).
- **Windows build under Wine / Proton:** `FmxWineCanvas` avoids the white
  window (Wine's Direct2D); `TSAPI_FMX_CANVAS=skia %command%` switches FMX
  to Skia's raster canvas (much faster there).
- **The menu on Linux** is FMX's own `TMenuBar` (drawn in the window), not
  the native GTK menu bar, which shows only the first letter of each item
  (TSteamAPI's `docs/fmx-menu-bug-fix.md`). The reader makes its menu in
  code, so on Linux it is made on the `TMenuBar` directly (no copying, as
  TSteamAPI's `FmxLinuxMenu` needs for a designed menu); Windows and macOS
  keep the native bar. SteamOS runs every main window full screen: the
  drawn bar stays inside it.
- **FreeType in Steam Linux Runtime 3** (found 2026-11-17, Steam Deck):
  Skia (`libsk4d.so`) uses the system's `libfreetype.so.6`, and the
  runtime's 2.10.4 crashes it on the first page drawn ("Access violation
  ... accessing address 0", in `libfreetype.so.6.17.4`). The reader ships
  FreeType 2.11.1 (Ubuntu 22.04's, with brotli) next to it -
  `tools/redist.sh collect` fetches it, Deploy and the depot take it - and
  `EpubReader.sh` puts the program's folder first on `LD_LIBRARY_PATH`
  when a `libfreetype.so.6` is there, so that FreeType is the one loaded
  (before GTK loads the runtime's). Started without the script, inside the
  runtime, the reader crashes as before.

## Android (phone and tablet)

A build for Android 64-bit (zips 317 to 321; first run on a Pixel 10a,
Android 17). What differs from a desktop:

- **Books** are in **books folders** you choose once (Menu > Books
  folders > Add a folder - Android's own folder picker: a folder on the
  phone, Documents/EpubUnum say, one on the memory card, or both). Every
  EPUB in them and in their folders is in the library, read where it is -
  nothing is copied, and the library looks again whenever it shows (a
  book put there later comes in, a book deleted goes). A folder can be
  taken off (Menu > Books folders > the folder: its books leave the
  library and stay where they are). With no books yet, the library offers
  a folder, or a link to BookManager, in a box like the menu that a book
  is needed to leave.
- **From BookManager** (zips 354 - 362): **Get books from BookManager**
  (the Menu's third row, Menu > Books folders, or "No books yet") starts
  the link and shows its
  panel; nothing of it runs otherwise. While the panel is open the phone
  says where it is on the network, answers BookManager directly, keeps
  the screen on and its Wi-Fi awake (Android's low-latency Wi-Fi lock).
  BookManager's **Send to phone** tab lists it by its name ("Google
  Pixel 10a"); not paired yet, BookManager asks to pair at once and the
  code shows in the panel (**Refuse** says no) - typed there, they are
  paired, once. The panel shows each book as it comes ("Receiving "...", book
  2 of 3 - 45 % (41 of 92 MB)") and the books received; they go to
  the reader's own Books folder
  (`Android/data/com.epubunum.reader/files/EpubUnum/Books`) and into the
  library behind the panel; when BookManager is closed it says so, and
  the panel closes by itself. **Cancel** (or Back) ends the link and goes
  back to the menu it was started from; **Done** - faded until something
  has happened (paired, BookManager in touch, a book received) - ends it
  and shows the library. Leaving the app ends it too. EPUBs only; 500 MB of the phone are always left
  free. Uninstalling the reader deletes that folder and its books. The
  pairings are kept in the settings ("linkId", "linkTokens"); every call
  that reaches the phone is in the debug log ("link: GET /books from
  ...").
  Books copied over USB into
  `Android/data/com.epubunum.reader/files/EpubUnum/Books` are found too. The debug log
  (`EpubReader-debug.log`) is in `EpubUnum` beside `Books`.
- **The window** is the page alone, as in Steam's Big Picture: no tool bar
  across the top and no contents panel beside the page. It keeps clear of
  the status and navigation bars.
- **A bar of six buttons at the foot:** Menu, a page back, a sentence
  back, Play / pause, a sentence on, a page on.
- **Menu** is the pad's menu, used by touch: Library, Books folders, Get
  books from BookManager, Library order, Contents, Text size, Speed, Dark mode, Highlight,
  Highlight type, Highlight word, Learn to read. A tap on Text size or
  Speed is one step up, and from the top it goes round to the bottom; a
  tap on Library order, Highlight or Highlight type is the next one.
  A tap beside the menu closes it.
- **Back** (the system's) leaves the menu; from a book goes to the
  library; from the library goes back to the open book, or with no book
  open leaves the app.
- **The library** fills the window's width and scrolls with a finger;
  held sideways the covers are smaller and more go across. Books copied in
  since last time are read one at a time while the library shows ("Reading
  new books: 3 of 7"), each cover appearing as it is done. A tapped book
  says "Opening ..." while it is read. The book read last is first and
  large; the others are in the order read, or by **Library order** (the
  menu; on a desktop File > Library order): title (without a leading The /
  A / An), author (by surname - the book's own sort form when it has one),
  year (of the book's date, which is often the edition's, not the first
  printing's) or genre (the book's first subject). A book without that
  detail goes last. The place in the book and the library are saved
  whenever the app is left.
- **Tap a word** to read from there. **Drag the page** with a finger to
  scroll it; a quick flick glides on and slows to a stop (the faster, the
  farther; a touch stops it, and it stops at a chapter's end - drag on
  from there for the next; while a book is being read aloud
  the page goes back to the word being spoken).
- **A book's index:** the first time a book is opened its words and
  timings are written to `EpubUnum/index/<name>.euix` (packed: about 25
  bytes a word); later openings read that and not the book's XML. An index that
  no longer fits its book is made again; deleting the `index` folder
  costs only time.
- **A staged open:** a book that has no index yet shows the page you
  left it at straight away, from its package and that one chapter; the
  rest of the book is read behind it and Play comes on when it is there.
  A book never opened shows its first page.
- **A book is opened in a thread:** the window stays alive while a long
  book is read, the library saying "Opening ...".
- **Sound** is Android's own player (no FFmpeg). A book's audio is played
  where it lies inside the book, with no copy made, when it is stored
  there uncompressed - as EpubBuilder's books have it. Compressed audio is
  copied out first, and the app does not answer while that is done.

### "Opening book" (zip 388)

On a phone or a TV, opening a book shows a frame over the dimmed window:
**Opening book**, the book's title, the step under way ("Reading the
book - the first time takes longest", "Reading the book's index",
"Building the view", "Finding the chapters", "Laying out the page"), a
bar and its count from 0 to 100 %. At 100 the book is ready and the
frame goes. While it shows, taps and keys do nothing.

The count is honest about steps, not about time inside one: the book is
read in a thread that says nothing until it is done, so the bar creeps
on by itself towards that step's end (further for a book read for the
first time, which has no index yet) and jumps when the step really ends.
The steps in the window's thread (the page's layout) are run one after
the other from a timer, so the frame is drawn between them. A book read
for the first time has its chapters made in the thread too (zip 389),
the count going up mark by mark (55 - 72 %) - before, that froze the
window: 6.2 s of Night Watch's first open on the Shield.
The frame is `demos/common/uProgressFrame.pas` (built in code - any
program of the group can use it). The desktop opens as before, without
it.

### Books prepared in the background (zip 390)

On a phone or a TV the library's books are prepared one at a time in a
background thread - read, their index written, their chapters made - so
that opening one is the fast, indexed open even the first time. It
starts 15 s after the program starts, after the library has read new
books and after each open, and goes on while a book is being read (and
played). The order: the cover selected in the library; while a book is
open, the books after it in the library (the next of a series), then
the rest.

- **Opening a book the background is preparing right now** waits for
  that job ("Being prepared in the background - finishing that", its
  count) and then opens it the fast way - never slower than reading it
  again.
- **Opening another book** stops the job at its next stage (a book's
  read, once started, runs to its end) and starts no other until the
  open is over; the stopped book is done again later.
- Index and chapter files are written to a temporary name and then
  renamed: a file is there whole or not at all.
- The log: "prep: books to prepare in the background: 29, first ...",
  "prep: preparing ...", "prep: ... read in N ms - ...", "prep: ...
  ready (N s)", "... stopped ... - again later", "... FAILED ...".

The unit is `src/uBookPrep.pas` (the list, the worker, pause / resume,
the join); what preparing a book is lives in `uMain.pas` (PrepareBook).

### Android TV (zip 381, first build for the NVIDIA Shield)

The same APK installs on a TV box (Android TV, Google TV): the manifest
asks for neither a touch screen nor the TV's launcher, and adds the
TV's home-screen entry (`LEANBACK_LAUNCHER`) with a banner. The reader
knows it is on a TV by the system's leanback feature and then:

- **No bar of buttons at the foot** (they make little sense across a
  room); **OK** on the page opens the menu (the way to everything, as
  the Menu button is on a phone), and so does **Up** from the library's
  top row of covers. The Shield remote's top-right button is its
  Settings button: Android keeps it for its own side panel. The page is a little larger (at least 24, as on
  a Steam Deck).
- **A remote or game pad** connected or disconnected does not restart
  the app (the manifest's `configChanges` has `navigation`). Numpad
  Enter is OK too, as Android TV has it.
- **The remote:** the **D-pad** moves in the menu, the library's covers
  and on the page (up / down scroll, left / right a page); **OK** (the
  D-pad's middle) opens the menu on the page and chooses in the menu
  and the library; **Play / Pause** plays and pauses the book and does
  nothing over the menu or the library (zip 382); a remote with a Menu
  key that reaches apps opens the menu with it too; **Back** closes the
  menu and goes from a book to the library, and never back to the book
  (Back never toggles - zip 385). It does NOT leave the app: in the
  library it does nothing, and the menu's **Exit** (the start menu of an
  empty library has one too) is the way out - holding Back went from
  the book to the library and out of the app (owner, zip 395). A held
  Back is one press. FMX gives no key for the remote's OK and
  Menu by itself: the reader maps them (Android's DPAD_CENTER to Enter,
  MENU to FMX's Menu key, zip 382) and logs what it found. The menu is
  Big Picture's list (the remote's names at its foot: OK, Back).
- **The library scrolls with the selection:** moving the frame with
  the D-pad past the covers in view brings that row in (zip 387).
- **The library's menu:** OK on a cover opens the book when it comes up;
  **held** 0.7 s it opens the menu instead (zip 396; Up from the top row
  still does too). The library's title says so at its right ("Hold OK
  for the menu").
- **The library's title** (every phone and TV, zip 396): "Library - 12
  books available (18 unavailable)" - unavailable are the covers marked
  so (zip 401: a dark shade and "Unavailable" in its middle - faded alone
  was not to be seen on the TV): gone, or their BookManager not
  running. The log names them when the list changes.
- **The menu fades what means nothing there** (zip 396): Back to the
  book, Contents, Learn to read and Cover of this book with no book
  open; Library and Contents over the library. Choosing a faded row does
  nothing; the selection starts on the first row that means something.
- **The page takes no keys of its own** on a TV, so the D-pad in the
  menu does not scroll the book behind it (zip 384).
- **The log** has a line for each of the remote's keys the first time
  it is pressed ("tv: remote key 19 (char 0) - Up"; "not used" for the
  ones that do nothing yet), and a line for each storage volume the app
  can keep books on, with its free space ("storage 2 (another volume):
  /storage/XXXX-XXXX/Android/data/com.epubunum.reader/files - 931.20 GB
  free" - a USB drive set up as portable storage).
- **Books folders** need Android's folder picker, which some TV boxes do
  not have: then the log says "books folder: no folder picker here" and
  BookManager's link is the way books come.

### iPhone and iPad (zip 403 on: being built; first run on an iPad, zip 404)

The reader is built for **iOS Device 64-bit** (the target is on in the
.dproj from zip 403; built on the M4 Mac through PAServer, as macOS
ARM). Its sound is AVFoundation's AVPlayer (`src/uPlayerIOS.pas`):

- a book's stored audio is played where it lies in the book: AVPlayer
  plays an address, not a part of a file, so the reader serves that part
  to itself on 127.0.0.1 (ports 47890 - 47909), with byte ranges -
  nothing is copied out;
- a book streamed from BookManager: its `/slice` address, as on Android;
- the speed: the player's rate, the pitch kept (the "TimeDomain"
  algorithm, for speech); the audio session is playback / spoken audio,
  so the book is heard with the switch on silent and the screen locked
  (Info.plist: UIBackgroundModes audio).

Books: the app's Documents folder shows in the **Files** app (On My iPad >
EpubReader - UIFileSharingEnabled, LSSupportsOpeningDocumentsInPlace)
and in Finder on a Mac (the device, Files, EpubReader): every `.epub`
anywhere in it is in the library (from zip 404 - Finder drops books at
its top and does not open the folders inside), looked for again whenever
the app comes back to the front; not those in a hidden folder (`.Trash`).
An empty library says so, with Look again. From a Mac's Terminal a book
can also be copied straight in:

    xcrun devicectl device copy to --device <UDID> --domain-type appDataContainer
      --domain-identifier com.epubunum.reader --source Book.epub
      --destination Documents/Book.epub

AVPlayer is called through objc_msgSend directly, its objects held as raw
ids (zip 406): through Delphi's Objective-C bridge, and then with CMTime
records passed by value, every seek raised an access violation on the
iPad (zips 403 - 405). Now no record crosses a call by value: a seek
passes pointers to copies of its three CMTimes (what arm64's C calling
convention does for records over 16 bytes), and a time is read with
valueForKey: and NSValue's getValue:size:. On iOS
nothing is written when the free space cannot be measured.

BookManager on iOS comes next: iOS lets an app
send or hear network broadcasts only with Apple's multicast entitlement
(asked for once the app is in alpha), so the iPad will be given
BookManager's address once instead (Info.plist has the local network
reason: NSLocalNetworkUsageDescription).

The Apple TV is not this program: Delphi has no tvOS target - a separate
Swift app, in a repository of its own (owner, 2026-11-27).

### One book, two places: the device's own copy first (zip 399)

A book is one entry of the library, by its file name, wherever it is
read from - its place, index, cover and counts go with the name. When
the same book is in a books folder (the TV's USB drive, the phone's
storage) and on BookManager, the library reads it from the copy that is
there now, the device's own first: BookManager's books become the USB
drive's when that folder is added (they were left faint and the
folder's copies skipped as doubles - owner, 21:47: "zero books are
available"), and go back to BookManager's when the drive is taken out
and BookManager runs ("If local becomes unavailable but network makes
it available then the transient copy is available again"). This is
looked at each time the library is shown; opening a book whose copy has
gone since (a drive taken out - "local storage may be swapped at any
time") looks at the folders again first, and says when no copy is
there. The book open at the time is left as it is.

### Book storage: held to a size, never the device's last space (zip 397)

What the reader keeps of each book on the device - its index, chapter
list and page layouts (`index\<md5>.*` beside the settings) - is held to
a size: **250 MB on a TV, 1 GB on a phone, 2 GB on a computer**, changed
in the menu (**Book storage**: 100 MB / 250 MB / 500 MB / 1 GB / 2 GB,
with what is used now). Covers are not counted (the library shows them;
a few hundred KB each). When the store is over its size, books make
way (`src/uBookStore.pas`):

1. books no longer in the library;
2. books prepared in the background but never opened, the oldest first;
3. opened books, the one not opened for longest first.

The open book, the one being prepared and the three opened last never
make way. The background preparation stops when the store is full (it
never pushes out an opened book for one never opened); opening a book
always works - its index is written and the store made to fit after.
Each book counts its openings and when it was last opened (the
settings' "opens" and "lastOpen"; a book with a place from before counts
as opened).

**Never the device's last space** (owner: "It must NEVER be possible to
run out of storage space"): nothing the reader writes for itself - an
index, a chapter list, page layouts, a cover, the settings - is written
when it would leave less than **1 GB** free on that volume: the index is
then not kept (the book opens the slow way), no cover is made (the title
shows), the settings stay as they were. When other apps leave the
volume with less than 1 GB free, books make way until it has. Books
received from BookManager (Send to phone) keep the same 1 GB free. The
settings are written to a temporary file and renamed (a full volume or
a kill half-way can no longer leave half a library), and the debug log
goes to `.old` at 8 MB (at most 16 MB in all).

The start of the log says what the store holds ("store: 180 MB for 32
book(s) - indexes ..., chapters ..., page layouts ...; covers ...; 6.2 GB
free on the volume, 1.0 GB always kept free"), and every book that makes
way is named.

On an Apple TV (a later port) the system may delete these caches at any
time and gives an app 500 KB of persistent storage: everything here is
made again when needed; the settings must stay small. Remote storage
(iCloud, Google) is never required - optional only (owner).

### BookManager's books, streamed to a TV (zip 392)

A TV listens for BookManager all the time (not only while the link panel
is open). Once it is paired with one (Get books from BookManager, then
pairing from BookManager's Send to phone tab, as a phone), all of that
BookManager's books - its Books tab's fetch folder - are in the TV's
library while BookManager runs, read from the computer: nothing is
copied to the TV (BookManager's Send to phone still stores books, by
hand). The BookManager is one more entry of Books folders ("BookManager
on MONSTER"); taken off, its books leave the library and it is not put
back until the two are paired again.

- A streamed book is named `bookmanager://ID/PATH` (ID: BookManager's id
  on the link, PATH its path there) and goes through the reader as a
  books folder's book does: its text is read by blocks of 512 KB
  (`/book?path&offset&length`, the newest 32 kept) through Epub.Zip's
  EpubStreamOpener (`src/uStreamBook.pas`), so the library, the index,
  the chapters and the background preparation work as for any book.
- Its audio is played by Android's player straight from BookManager
  (`/slice`, which answers the player's byte ranges) - the manifest
  allows plain http for that (`usesCleartextTraffic`: Android 9 on
  refuses it otherwise).
- BookManager not on the network (not started, closed, the computer
  asleep): its books stay in the library, faint; choosing one says that
  BookManager is not running, and the background preparation leaves them
  until it is back. The TV looks for BookManagers and asks for their
  lists every 20 s; the log's "stream:" lines say who was heard, paired,
  how many books, who left.
- New books (any, on a phone or a TV) are read into the library in a
  thread since zip 394 - a streamed book's header and cover come over
  the network - so the library and the remote answer meanwhile; the
  cover's picture is made back in the window's thread.
- A held OK, Play / Pause or Menu is one press (its repeats are not
  presses), and the same key coming down again within 0.3 s of coming
  up is not one either: the Shield's Play / Pause did both, one press
  playing, stopping and playing (zip 394; the log says "tv: remote key
  179 ignored - ..."). The D-pad still repeats.

### Its icon

`tools/make_icons.py` writes the Android icons into `android/` beside the
project: `LauncherIcon_36.png` to `_192.png`, and the adaptive icon's
three vector drawables (`AdaptiveIcon_Background.xml`, `_Foreground.xml`,
`_Monochrome.xml`), and the picture shown while the app starts
(`Splash.xml`, `SplashV31.xml` and a `...Dark.xml` of each: the whole icon
on its navy tile), and the TV's banner `TvBanner_320x180.png` (the tile
and the name; deployed to `res/drawable-xhdpi/tv_banner.png`).
`EpubReader.dproj` names them for Android 64-bit.

## Sound

The reader plays through one class, `TReaderPlayer` (`src/uPlayer.pas`),
so that a phone or a TV box can have a player of its own later. On a
desktop that class is `src/uPlayerFFmpeg.pas`:
the book's audio is played by FFmpegAPI's `TFFmpegAudioPlayer`: FFmpeg
streams the audio file (extracted from the book once) to the platform's
output - WASAPI on Windows, PulseAudio / PipeWire on Linux and SteamOS - and
the player's clock (the sound really being heard) picks the sentence to
highlight. Put FFmpeg 8's shared libraries (`avutil-60.dll`,
`swresample-6.dll`, `avcodec-62.dll`, `avformat-62.dll`, and for the speed
slider `swscale-9.dll` and `avfilter-11.dll`) next to the program or on
PATH; a GPL or an LGPL build will do, and its licence is
written to the log. On Linux the same six as `libavutil.so.60`,
`libswresample.so.6`, `libavcodec.so.62`, `libavformat.so.62`,
`libswscale.so.9` and `libavfilter.so.11` - ffmpeg-dev's
`dlls/linux-x64` - next to the program (they find each other there), or
on `LD_LIBRARY_PATH`; the sound goes through `libpulse-simple.so.0`
(PulseAudio, or PipeWire's pulse server - SteamOS has it). Without FFmpeg the book still reads, without sound;
without a sound device it plays silently and the highlight still follows.
macOS sound comes later.

The tool bar's icons are drawn as Sprite3D's results view draws them: a
`TPath` in a `TButton`, coloured by the style.
