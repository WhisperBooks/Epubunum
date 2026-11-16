# EpubReader

The end-user reader: open an EPUB, read it, and - for a book with media
overlays (EPUB 3 synced audio) - listen with the words highlighted as they
are read. The page is drawn with Skia by `TEpubView`; the contents list is
on the left.

## Before the first build

**TFFMpegAPI** (github.com/G3DGames/TFFMpegAPI) plays the sound: build its
`FFmpegAPI.groupproj` first (the reader uses the runtime package FFmpegAPI's
DCUs). Then build EpubUnum's packages (`EpubUnum.groupproj` builds them before
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

Covers are cached as PNG in a `covers` folder beside `EpubReader.json`,
named by a hash of the book's file name, at most 600 px high: the book's
own cover picture, or - when it has none, or one the reader cannot draw
(SVG) - a made cover with the title and author on a colour of the
title's own. Replace a file there to change a book's cover; delete it to
have it made again.

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
Application > Icons, Win64).

## Platform notes (from TSteamAPI)

The files in `src/` named `Fmx*.pas` and `EpubReader.sh` are **unchanged
copies** of TSteamAPI's (github.com/G3DGames/TSteamAPI, `docs/`):

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

## Sound

The book's audio is played by FFmpegAPI's `TFFmpegAudioPlayer`: FFmpeg
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
