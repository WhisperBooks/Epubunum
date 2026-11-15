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
  - `Epub.Components` - `TCustomEpub`, the base of the component.
- `fmx/` - `TEpubUnum` (the book), `TEpubView` (Skia page view) and their
  design-time registration (palette page "EpubUnum").
- `demos/EpubReader` - the reader (FMX, Skia): contents, pages, play with
  highlighting; its sound is TFFMpegAPI's player (FFmpeg streamed to
  WASAPI / PulseAudio), so the reader also needs TFFMpegAPI installed.
- `demos/EpubConsole` - console demo and smoke test.

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
- **Layout for a renderer**: `DocumentLayout(Doc)` gives the blocks with
  their runs and word spans; `BlockOfWord` finds a word's block. Character
  offsets are 0-based UTF-16 (what Skia's paragraph ranges use).
- **Copy protection**: `META-INF/encryption.xml` naming anything but font
  obfuscation, `META-INF/rights.xml` (Adobe) or `META-INF/sinf.xml` (Apple
  FairPlay) - the book is refused with a message. Nothing is ever decrypted.

## The view (`TEpubView`)

Link it to a `TEpubUnum` (`Epub` property), call `ShowDocument` or
`ShowFragment`; `Highlight(First, Last)` + `ScrollToWord` follow the
narration; `OnWordClick` gives the word under a click. Text size, line
height, paragraph spacing, page margin and colours are properties. It lays out
each block with Skia's paragraph engine (`TSkParagraph`) and draws the
highlight from the paragraph's range rectangles.

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

The demos use the runtime packages' DCUs from Delphi's Dcp folder, as any
user project would, so build the packages first. Install `dclEpubUnumFMX`.

Platforms: Win32 / Win64, macOS (x64, ARM), Linux64, Android64 for the
packages; the demos are desktop. iOS can follow (pure Pascal).

## SteamOS, Linux and Proton

The reader carries TSteamAPI's platform fixes (unchanged copies, see
`demos/EpubReader/README.md`): GTK made global in Steam's Linux runtime,
the ICU launcher script for SteamOS, the Wine canvas switch for a Windows
build under Proton, and no main menu (FMX's GTK menu bar shows only first
letters; SteamOS runs windows full screen).

## Layout

- `lib/Epub.inc` - compiler and platform defines.
- `tools/gen_projects.py` - generates the .dproj files and the groupproj
  (missing files only; `--force` rewrites them). Once the IDE has saved a
  file, the IDE's version is authoritative.

## Checks before delivery

```
python3 tools/pasdoc_check.py      # every declaration documented, ASCII, hygiene
python3 tools/project_check.py     # projects, packages and build order agree
```

## Not covered (yet)

- Writing media overlays into a book (what TWhisper needs: spans with ids
  in the text, SMIL files, the package updated) - next.
- Writing a new EPUB from a transcript (make-your-own books).
- Paged (rather than scrolled) view; fonts embedded in books; SVG pictures.
- Audio playback on Linux (FMX's TMediaPlayer there is untested).
