# EpubUnum - EPUB books for Delphi (FMX)

Reads EPUB 2 and EPUB 3 books - metadata, reading order, contents, cover,
the text word by word, and **media overlays** (EPUB 3 synced audio) - and
shows them with **`TEpubView`**, a page view drawn with Skia that
highlights the words as they are read. It is the base of the WhisperBooks
reader (the end-user application) and of the tools that make synced books
(TWhisper aligns a narration with a book's text through it).

**Delphi with Skia, Free Pascal without.** `lib/` (everything but
rendering) compiles with both; `fmx/` - the components and the Skia view -
is Delphi. A Free Pascal / Lazarus program reads books, text and media
overlays the same way and would draw the layout model with its own view.

- `lib/` - framework-free units:
  - `Epub.Zip` - the ZIP container: reading, and writing with the
    `mimetype` entry first and stored.
  - `Epub.Xml` - a tolerant XML / XHTML parser (EPUB 2 books carry HTML
    habits: `&nbsp;`, unclosed `<br>`, stray end tags).
  - `Epub.Css` - the part of CSS a reflowing reader needs (italic, bold,
    small caps, alignment, indent, margins, size, display: none, ...).
  - `Epub.Layout` - one walker per document: the **words** (with element
    ids and roles) and, for a renderer, the **blocks** (paragraphs,
    headings, list items, table cells, preformatted text, pictures, rules)
    with styled runs and the character span of every word.
  - `Epub.Book` - `TEpubBook`: package, spine, contents (EPUB 3 nav,
    EPUB 2 NCX), cover, text, media overlays, copy-protection refusal.
  - `Epub.Writer` - `TEpubWriter`: a copy of a book with **media overlays
    written** from timed words (what TWhisper makes synced books with).
  - `Epub.Mobi` - a DRM-free **MOBI** (Mobipocket / Kindle, the old
    MOBI 6 text) written as an EPUB 3 that `TEpubBook` reads; copy-
    protected books are refused, never decrypted.
  - `Epub.Components` - `TCustomEpub`, the base of the component.
- `fmx/` - `TEpubUnum` (the book), `TEpubView` (Skia page view) and their
  design-time registration (palette page "EpubUnum").
- `demos/EpubReader` - the reader (FMX, Skia): contents, pages, play with
  highlighting; its sound is TFFMpegAPI's player (FFmpeg streamed to
  WASAPI / PulseAudio), so the reader also needs TFFMpegAPI installed.
- `demos/EpubConsole` - console demo and smoke test.
- `demos/EpubBuilder` - makes a read-along EPUB from an EPUB and its audio
  files (TWhisper transcribes and aligns; needs TWhisper installed too).

## The book (`TEpubBook`)

```pascal
Book := TEpubBook.Create('book.epub');      // EEpubError when not an EPUB / protected
try
  WriteLn(Book.Title, ' by ', Book.Creators.CommaText);
  for I := 0 to High(Book.Toc) do            // contents
    WriteLn(Book.Toc[I].Title);
  for I := 0 to Book.WordCount - 1 do        // the text, word by word
    if Book.Words[I].Role = ewrBody then ...
  C := Book.ClipAt('OEBPS/audio/ch1.m4a', 12.5);   // what is read at 12.5 s
  if Book.ClipWords(C, First, Last) then ...       // its words
finally
  Book.Free;
end;
```

- **Words** keep their document, the innermost element id around them and
  a **role**: body, heading, caption, note, table, preformatted, nav. Roles
  come from markup only - `epub:type`, ARIA roles (`doc-endnotes`, ...) and
  class names containing `caption`, `footnote`, `endnote` or `note` - never
  from the words. An aligner leaves captions and notes out of what it
  expects to hear (Hobbit: 509 fewer unspoken words, the same exact matches).
- **Media overlays**: `Clips` (text element, audio file, clip begin / end),
  `ClipAt`, `ClipWords`, `AudioFiles`, `ActiveClass`, `MediaDuration`.
- **Audio chapter marks** (books written by `TEpubWriter` with
  `AddAudioChapter`): `AudioChapters` (title, audio file, start) and
  `AudioChapterWords` (the first word read at each mark).
- **Layout for a renderer**: `DocumentLayout(Doc)` gives the blocks with
  their runs and word spans; `BlockOfWord` finds a word's block. Character
  offsets are 0-based UTF-16 (what Skia's paragraph ranges use).
- **Copy protection**: `META-INF/encryption.xml` naming anything but font
  obfuscation, `META-INF/rights.xml` (Adobe) or `META-INF/sinf.xml` (Apple
  FairPlay) - the book is refused with a message. Nothing is ever decrypted.

## Writing media overlays (`TEpubWriter`)

The caller gives, for each word it heard, the word's index in
`Book.Words`, the audio file and the clip's start and end. Matching a
transcript to the book's words is the caller's job (TWhisper's): the
writer takes word indexes only, so they always agree with the reader's.

```pascal
W := TEpubWriter.Create(Book);                // Book stays open while saving
try
  A := W.AddAudioFile('narration.m4a');       // copied into the book (stored)
  // or A := W.AddBookAudio('OEBPS/audio/ch1.mp4');   audio already inside
  for I := 0 to High(Heard) do
    W.AddWord(Heard[I].Word, A, Heard[I].Start, Heard[I].Stop);
  W.Level := eolWord;                         // default; eolBlock = a clip per paragraph
  W.Narrator := 'A. Narrator';
  W.SaveToFile('book-synced.epub');           // never over the book itself
  WriteLn(W.Report.Clips, ' clips, ', W.Report.Skipped, ' words left out');
finally
  W.Free;
end;
```

`SaveToFile` writes to `book-synced.epub.tmp` and gives the book its name
only when it is complete: an error leaves a file that was there before
untouched, and no half written one.

- **Word level** (default): every timed word gets `<span id="eu-wN">`
  (a word already alone in an element with an id keeps that id, so writing
  a book again adds nothing); **block level**: the paragraph, heading or
  list item gets an id and one clip covers its words.
- Only **inserted**: the documents keep every byte of their markup,
  comments and entities. Each tagged document is **checked** before it is
  written: parsed and laid out again it must give the same words, and every
  new id must hold exactly its word.
- One SMIL file per document, in document order; the package gets the
  SMIL and audio items, `media-overlay`, `media:duration` (each overlay and
  the total), `media:active-class`, `media:narrator`, `dcterms:modified`.
  A document's overlay is replaced as a whole; documents without timed
  words, and every other file, are copied unchanged (not even unpacked).
- A book without an active class gets a small style sheet with a
  highlight rule, so other readers show the highlight too.
- **Marked as made here**: `<meta name="epubunum:writer" content="...">`
  in the package (`WrittenBy`, default `EpubUnum`; EpubBuilder and
  EpubConsole write their names). `TEpubBook.WrittenBy` reads it back, so a
  program can tell a book it already made (EpubBuilder warns before
  building from one).
- **Audio chapter marks** (`AddAudioChapter(Title, Audio, Start)`): an
  audiobook's chapters, written to `epubunum-audio-chapters.xml` (manifest
  id `eu-audio-chapters`, EpubUnum's own format - other readers ignore
  it). They mark places in the audio, not the text, so they survive any
  re-alignment.
- **EPUB 2 books become EPUB 3** (overlays are EPUB 3 only): version 3.0,
  a nav document made from the NCX, `opf:role` / `opf:file-as` turned into
  `refines` metadata, extra `dc:date` dropped, the HTML5 doctype with named
  entities as character references.
- Audio: MP3 or AAC in MP4 (what every EPUB 3 reader must play); other
  types are written with a warning in `Report.Warnings`.
- Checked with epubcheck 5.2.1: Moby-Dick (IDPF sample) with every one of
  its 212,881 words timed, 142 overlays - no errors, no warnings.

## The view (`TEpubView`)

Link it to a `TEpubUnum` (`Epub` property), call `ShowDocument` or
`ShowFragment`; `Highlight(First, Last)` + `ScrollToWord` follow the
narration; `OnWordClick` gives the word under a click. Text size, line
height, paragraph spacing, page margin and colours are properties. It lays out
each block with Skia's paragraph engine (`TSkParagraph`) and draws the
highlight from the paragraph's range rectangles. `ShowProgress` adds a
strip under the text with how far through the book the view is
(`Progress`, by words - the text size does not change it).
`ChapterBreaks` (book word indexes) draws a short centred rule, with room
around it, above the paragraphs that start chapters the book itself does
not mark (EpubReader: an audiobook's chapters). When the component opens
another book the view notices (`TEpubUnum.BookSerial`): it draws an empty
page until `ShowDocument` is called for the new book, and never the old
book's text. A picture that cannot be read is left out; the text goes on.

**Skia:** `TEpubView` derives from `TSkCustomControl` and draws with Skia
whatever FMX's own canvas is. Enable Skia (Project > Enable Skia) on
`EpubUnumFMX` and on any program that uses the view: the IDE adds Skia and
deploys its library (`sk4d.dll`, `libsk4d.so`, ...). In a program, **do not
keep the `GlobalUseSkia := True;` line** the IDE writes into the .dpr (see
EpubReader).

The layout model is renderer-neutral: a VCL, LCL or web-view renderer
would draw the same blocks.

## Packages and demos

`EpubUnum.groupproj` builds, in order:

1. `packages/EpubUnum` - runtime, rtl only: all of `lib/`.
2. `packages/EpubUnumFMX` - runtime: `TEpubUnum`, `TEpubView` (Skia).
3. `packages/dclEpubUnumFMX` - design time (Win32 / Win64): registers both.
4. `demos/EpubConsole`
5. `demos/EpubReader`
6. `demos/EpubBuilder`

The demos use the runtime packages' DCUs from Delphi's Dcp folder, as any
user project would, so build the packages first. Install `dclEpubUnumFMX`.
EpubBuilder also uses TWhisper's runtime package `WhisperAPI` (which needs
TFFMpegAPI's `FFmpegAPI`): build TWhisper's packages before it.

Platforms: Win32 / Win64, macOS (x64, ARM), Linux64, Android64 for the
packages; the demos are desktop. iOS can follow (pure Pascal).

## Redistributables (deploying the programs)

EpubReader and EpubBuilder need whisper.cpp's libraries (built by
whisper-dev; the reader does not) and FFmpeg's (built by ffmpeg-dev) at
run time. `tools/redist.sh` (Linux, macOS) and `tools\redist.bat`
(Windows) collect both sets into `redistributable_bin/<platform>/` and
deploy them next to a built program, or into a macOS app's
`Contents/Frameworks` - see `redistributable_bin/README.md`.

```
tools/redist.sh collect ../whisper-dev ../ffmpeg-dev
```

```
tools/redist.sh deploy Linux64 demos/EpubBuilder/Linux64/Release
```

## Steam builds

EpubReader and EpubBuilder can be built for Steam (AppIDs 5639840 and
5639910, `STEAM_APP_ID` in each `.dpr`). To make a Steam build, choose its
configuration in the IDE. The rest of each program is the same:

| Configuration | Parent | Steam |
|---|---|---|
| Debug, Release | - | none: TSteamAPI is not needed at all |
| **SteamDebug** | Debug | started with the AppID from the environment (no `steam_appid.txt`, no relaunch): run from the IDE with Steam running |
| **Steam** | Release | started outside Steam, the program ends and Steam launches it (Steam starts first if needed) |

Both define `STEAMBUILD`. All the Steam code is in `demos/common/uSteam.pas`
and compiles to nothing without that define. When Steam cannot be started,
the program carries on without it and says so in its log; neither program
uses a Steam feature yet. A Steam build needs:

- TSteamAPI's runtime packages `Steamworks` and `SteamworksFMX`, built for
  the platform (their units come from Delphi's Dcp folder, as EpubUnum's
  do). See TSteamAPI's `docs/Install-Delphi.md`.
- The Steam library in `redistributable_bin/steam/` (see
  `redistributable_bin/README.md`). The Win64 build copies it next to the
  .exe; Deploy puts it next to the Linux program or into the Mac bundle.

Every Win64 build also copies the program's other libraries next to it
(`tools\postbuild.bat`): FFmpeg for EpubReader; for EpubBuilder,
whisper.cpp with the CPU and Vulkan backends in the Steam configurations
(CUDA and ROCm are to be free DLC) and every backend in Debug / Release.
On macOS `tools/redist.sh deploy` gives EpubBuilder the CPU and Metal
backends.

## SteamOS, Linux and Proton

Both programs carry TSteamAPI's platform fixes (see
`demos/EpubReader/README.md`): GTK made global in Steam's Linux runtime
(`FmxLinuxGtkGlobal`), the ICU launcher script for SteamOS
(`EpubReader.sh`, `EpubBuilder.sh` - identical but for the name; each
starts the program it is named after), the Wine canvas switch for a
Windows build under Proton (`FmxWineCanvas`), and on Linux a menu bar
drawn by FMX instead of GTK's (which shows only first letters).

The launcher has one addition of ours: Skia crashes with Steam Linux
Runtime 3's FreeType (2.10.4), so the programs ship FreeType 2.11.1 next
to them (`tools/redist.sh collect` fetches it from an Ubuntu 22.04
container) and the script puts their folder first on `LD_LIBRARY_PATH`
when it is there.

On Linux the **launcher script is what Steam starts**: set each app's
Linux launch command on the Steamworks site to `EpubReader.sh` /
`EpubBuilder.sh`, not the program. Delphi's Deploy puts the script next
to the program in every configuration, and `tools/redist.sh deploy`
copies it too (made executable). Keep it LF and executable in git.

## Layout

- `lib/Epub.inc` - compiler and platform defines.
- `redistributable_bin/` - the libraries the programs need, per platform
  (not tracked; `tools/redist.sh` / `redist.bat` fill and deploy them).
- `notes/Building-distributions.md` - step by step from fresh clones:
  building, collecting and deploying every library and file, for every
  platform, and the Steam depots.
- `notes/Windows-on-Arm.md` - Windows on Arm (Delphi's Arm64EC): what is
  known, the risks, and the tests, with `notes/Arm64ECProbe.dpr` (compiler
  symbols, Vulkan, CUDA, which DLLs load).
- `tools/gen_projects.py` - generates the .dproj files and the groupproj
  (missing files only; `--force` rewrites them). Once the IDE has saved a
  file, the IDE's version is authoritative.

## Checks before delivery

```
python3 tools/pasdoc_check.py      # every declaration documented, ASCII, hygiene
python3 tools/project_check.py     # projects, packages and build order agree
```

## Not covered (yet)

- Writing a new EPUB from a transcript (make-your-own books) - next.
- Sentence-level overlays (a sentence can cross inline markup: needs
  splitting into several spans).
- Paged (rather than scrolled) view; fonts embedded in books; SVG pictures.
