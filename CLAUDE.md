# CLAUDE.md - working rules for this repository

Read README.md first, then this file. Keep both up to date with every change.
The rules follow TWhisper's and TFFMpegAPI's CLAUDE.md (same owner, same
conventions); where this file is silent, theirs apply.

## Project
EpubUnum (github.com/WhisperBooks/Epubunum, PRIVATE - WhisperBooks' own,
unlike the public TFFMpegAPI): EPUB reading and, next, writing for Delphi
FMX. Started 2026-11-15 at the owner's request, before the EPUB layer of
TWhisper: "having it's own component makes sense".

Product line (owner, 2026-11-15): the END-USER READER is the main
application most people will get - it shows the EPUB and plays the audio in
sync with the text highlighted. Variants for creators, publishers and
narrators build on it (TWhisper is "the big one"). Make-your-own books
(record stories for your children) is a promising market. So:
- The reader must not need TWhisper, whisper.cpp, models or a GPU: it uses
  EpubUnum (and possibly FFmpegAPI) only.
- Output is standard EPUB 3 media overlays, so books made here also play in
  other readers.
- Copy-protected books are refused with a message, never decrypted.

Rendering (owner, 2026-11-15): NATIVE WITH SKIA - "add Delphi's Skia into
things as it speeds up rendering". TEpubView (fmx/) draws the layout model
(lib/Epub.Layout) with Skia's paragraph engine. A web view is possible
later as a second renderer only; FMX has no web view on Linux and WebView2
under Proton is unproven. The layout model stays renderer-neutral.

DELPHI WITH SKIA, FPC WITHOUT (owner, 2026-11-15: "Epubunum can be Delphi
with Skia and FPC without - best of all worlds that way"; Skia "only matters
when rendering"). lib/ compiles with Delphi AND FPC (FPC is also the test
compiler here). Skia is only in fmx/ (TEpubView, Delphi). An FPC / Lazarus
renderer (LCL canvas or BGRABitmap) would draw the same layout model later.
Keep compiler differences in lib/ to small {$ifdef FPC} branches; names that
exist in only one compiler are bugs (zip 01: DefaultFormatSettings is FPC's
only - use FormatSettings, which both have).

The owner builds in the 32-bit IDE (the 64-bit one has no macOS / Linux
targets): packages build for Win32 too; design packages open on Win32.

## Skia (owner, 2026-11-15)
- EpubUnumFMX requires Skia.Package.RTL and Skia.Package.FMX (Delphi 13's
  names). TEpubView uses System.Skia and FMX.Skia, so the IDE adds both
  packages on the first compile if they are missing ("Skia was actually
  forced on me by the IDE when compiling the package" - push e8c3a23).
  gen_projects.py now writes them, with the SKIA define.
- Programs (EpubReader) still need Project > Enable Skia for sk4d.dll
  deployment; gen_projects.py writes those DeployFile entries.
- The IDE writes "GlobalUseSkia := True;" into a program's .dpr: NEVER
  keep it (TSteamAPI's rule; FmxSkiaCanvas decides under Proton).
- Skia API used by TEpubView was checked against the Skia4Delphi source
  (github.com/skia4delphi/skia4delphi): TSkCustomControl.Draw (strict
  protected virtual), DrawCacheKind, Redraw, ISkParagraphBuilder (PushStyle,
  AddText, Pop, Build), ISkParagraph (Layout, Paint, Height,
  GetRectsForRange -> TArray<TSkTextBox>, GetGlyphPositionAtCoordinate ->
  TSkPositionAffinity), TSkTextStyle, TSkFontStyle.Create(weight, width,
  slant), TSkImage.MakeFromEncoded, ISkCanvas.DrawImageRect / DrawRect /
  DrawLine / ClipRect / Save / Restore.

## Platform notes (from TSteamAPI, owner: "important notes in general")
github.com/G3DGames/TSteamAPI docs/: fmx-steamos-gtk3-bug-fix.md,
fmx-steamos-icu-bug-fix.md, fmx-menu-bug-fix.md, FmxWineCanvas /
FmxSkiaCanvas. EpubReader carries UNCHANGED copies of FmxLinuxGtkGlobal,
FmxWineCanvas, FmxSkiaCanvas and the ICU launcher (as EpubReader.sh; LF -
.gitattributes). Their headers still name TSteamAPI's copies and the
environment variable TSAPI_FMX_CANVAS: kept identical on purpose. No
TMainMenu in the reader (Linux GTK menu bar bug; SteamOS full screen); if a
menu is added, add FmxLinuxMenu. Start-up markers on stderr under POSIX and
the canvas in use logged, as SteamDemoPad. Gorilla3D / CGE notes in
TSteamAPI do not apply (no 3D).

## Reader sound and tool bar (zip 03, owner 2026-11-15)
- No TMediaPlayer: "(b) That's how MoviePlayerFMX does it" (SRDelphiFMX).
  The reader plays with TFFMpegAPI's TFFmpegAudioPlayer (FFmpegAPI-04:
  FFmpeg.AudioOut + FFmpeg.Player - streamed, WASAPI / PulseAudio / silent,
  Position = the sound being heard). EpubUnum's packages do NOT use FFmpeg;
  only the EpubReader demo does (TFFMpegAPI installed, like TWhisper).
  FFmpeg may be GPL or LGPL (owner): no policy forced; the licence is logged.
- Tool bar: no designed buttons; made in FormCreate the way Sprite3D's
  results view does it (github.com/peardox/Sprite3D, Sprite3DResultsView /
  Sprite3DHelpers: a TButton with a centred FMX TPath icon, SVG path data in
  a 24x24 box, Fill coloured from ResultingTextSettings.FontColor in
  OnApplyStyleLookup). Icons: open (folder), previous / next chapter
  (Sprite3D's FIRST / LAST), previous / next sentence (PREVIOUS / NEXT),
  play / pause.

## Layout rules
- `lib/` - framework-free units only. No FMX, VCL or LCL here, ever.
- `fmx/` - Epub.FMX (TEpubUnum), Epub.FMX.View (TEpubView), Epub.FMX.Reg.
  They include `..\lib\Epub.inc` by relative path.
- ONE WALKER: Epub.Layout's TEpubDocLayout produces the words AND the
  blocks; TEpubBook.Words comes from it (blocks off). Never split words
  anywhere else - word indexes from overlays, alignments and the view
  must agree.
- `demos/<Name>/` - `<Name>.dpr` + `<Name>.dproj` + `README.md`, other
  sources in `src/`. Demos list and search ONLY their own sources.
- GROUP ORDER (gen_projects.py GROUP_ORDER): EpubUnum, EpubUnumFMX,
  dclEpubUnumFMX, EpubConsole, EpubReader - plain runtime, FMX runtime,
  design, applications.

## Code rules
- ASCII-only sources; PasDoc on every declaration.
- Never `Low`, `High`, `TypeOf`, `AS` ... as identifiers (AS is reserved).
- No absolute paths, user names or machine names in tracked files.

## Deliveries
- Zips hold only the files changed since the previous zip, paths from the
  repo root, named EpubUnum-NN-topic.zip; the number is never reused; every
  delivery says what it goes on top of. Zip 01 is the whole repository.
- PACKAGE REBUILDS (owner, 2026-11-15: "Add rule"). Every delivery says
  one or the other. When a package must be rebuilt, the message carries,
  exactly, a blank line, the banner, a blank line, then the details:

      =====> PACKAGE REBUILD NEEDED <=====

  Details of the package rebuilds: which packages, in build order, why
  (which unit changed), and what to rebuild after them (programs, other
  repos' packages). Otherwise say "NO PACKAGE REBUILD", in capitals.
- Never commit or push, and don't offer to.
- Sync + check needs access: the repo is private (give this session access
  to WhisperBooks/Epubunum, or send a zip of the checkout).
- Before delivery: `python3 tools/pasdoc_check.py`,
  `python3 tools/project_check.py`, an FPC build of lib/ and EpubConsole
  run on the test books.

Last number used: 08.

## Review fixes (zip 08, on top of 68162a4 "A Claude push")
From a code review by reading (owner, 2026-11-15: "code review", then "y" to
a zip with the five fixes). NOT COMPILED OR RUN in that session (no FPC, no
Delphi, no Skia there; pasdoc_check and project_check: 0 problems): the
owner's Delphi build and an FPC build of lib/ with EpubConsole on the test
books are their test.
1. EpubReader, StartClip: the name of the extracted audio file was the
   overlay's audio path with '/' turned into '_'. A book chooses that path:
   backslashes with '..', or an absolute path (TPath.Combine returns an
   absolute second part as it is), wrote the book's bytes anywhere. Now the
   name is <BookSerial>-<first clip of that audio><extension>, the
   extension only a dot and ASCII letters / digits (SafeAudioExtension), so
   a second book with the same inner path no longer plays the first book's
   file either. The temp folder's name is a GUID (Random without Randomize
   gave the same folder every run; two readers shared and deleted it).
   Never build a file name on disk from a path inside a book.
2. TCustomEpub.BookSerial (Epub.Components): changes with every open and
   close. TEpubView keeps the serial its layout was made at
   (LayoutCurrent): ShowDocument makes the layout again when the book is
   another one even if the document number is the same - it showed the
   FIRST book's text for a second book starting at the same document - and
   Draw / WordAt / ScrollToWord / ShowFragment do nothing with a layout of
   the book before. TO TEST: open a book, then another, without leaving the
   first document.
3. Epub.Css, Parse: a statement without a block ('@charset "UTF-8";',
   '@namespace ...;', '@import ...;') ends at its ';'. It was scanned on to
   the next '{', became that rule's selector, started with '@' and the rule
   was skipped: the first rule of every style sheet starting that way. TO
   TEST: EpubConsole's rule counts / a book whose CSS starts with @charset.
4. TEpubView.LayoutItems: reading a picture is in try / except - a damaged
   entry (CRC, ZIP method, too large) gives no picture. The exception left
   Draw with FItems half made and the width marked as laid out, so the
   chapter stayed cut off.
5. Epub.Xml: Children no longer copies the array on every read (the node's
   own array, trimmed once). Children[I] in a loop over ChildCount
   (Epub.Layout's walk, the NCX reader) was quadratic. Callers must not
   change the array.
Found in the same review and NOT fixed: Epub.Zip trusts the sizes of the
directory (a small file can ask for 2 GB) and Extract reads the whole entry
into memory although the error text says to use it; a descendant selector
('.poem p') is applied to every element matching its last part; style
sheets are parsed once per DOCUMENT, not per CSS file, and StyleOf scans
every rule and parses the declarations again for each element; ClipAt
returns a clip without clipEnd for every later time; the XML tree and the
layout walk recurse without a depth limit; ExtractAll skips every name with
'..' in it ('Wait....xhtml'); with FPC, UTF-16 text is converted with
string(W), not UTF8Encode; Active := True fails silently without
OnOpenFailed; no LICENSE file.

## Pushes checked
- e8c3a23: zips 01-04 match. The IDE added the Skia requires (now in the
  generator, zip 05) and re-saved the .dproj files. The owner added
  test/README.md and test/.gitignore (*.epub - test books stay local).
  The console folder was pushed as demos/EPubConsole; the owner renamed it
  to demos/EpubConsole in cdcebf7 (checked). bed841b = zip 05 (checked).

## Test notes (zip 01, FPC 3.0, Linux x64)
- Seven EPUBs (local only, copyrighted - never committed or quoted):
  Aladdin, The Stars My Destination, The Hobbit (illustrated, EPUB 3),
  Silverthorn, Night Watch, The Moment of the Magician, Magician. All open;
  every ZIP entry reads with its CRC; every document parses (Hobbit: 16
  repairs).
- Layout invariants on all seven: every word's span spells the word, no
  word without a block, runs cover each block's text - 0 failures. Night
  Watch's 834 italic runs come from its CSS classes (Calibre). Magician's
  293,229 words load in about 0.4 s.
- Synthetic EPUBs: EPUB 3 with nav, nested ids, a SMIL overlay (clock
  values h:mm:ss, mm:ss, 1.5s, 3200ms, 0.15min), cover, active class,
  duration; font obfuscation opens; AES encryption.xml and Adobe rights.xml
  are refused.
- Hobbit aligned with EpubConsole --text --body-only against the earlier
  transcript: exact 93,955 (same), not spoken 10,188 -> 9,679, not heard
  5 -> 0 (captions and notes left out).
- Owner's first Delphi build of zip 01 (Win64): E2003 DefaultFormatSettings
  in Epub.Css (FPC-only name; also in Epub.Book) - fixed in zip 02.
- Owner (2026-11-15, Delphi 13, Windows): EpubUnumFMX and EpubReader build
  (the IDE added the Skia requires to EpubUnumFMX on the first compile).
  EpubReader with Moby-Dick (IDPF epub3-samples, CC-BY-SA, media overlays,
  one AAC mp4): "All tests ran perfectly" - the book shows, WASAPI sound,
  the highlight follows the audio, pause / resume, clip buttons, chapter 2.
- A Windows "ding" on the very first run, not seen in the debugger log
  (that log is only the File Open dialog's shell noise). Possibly Ctrl+O:
  FormKeyDown opens the dialog inside the key press, and the pending Ctrl+O
  character may reach the dialog's file-name box. Unconfirmed - change only
  if it comes back (fix: TThread.ForceQueue the open).
- Not yet run: Linux / SteamOS (PulseAudio), macOS, a paged view.
