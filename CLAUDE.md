# CLAUDE.md - working rules for this repository

Read README.md first, then this file. Keep both up to date with every change.
The rules follow TWhisper's and TFFMpegAPI's CLAUDE.md (same owner, same
conventions); where this file is silent, theirs apply.

## Handover - READ THIS FIRST (latest: session 8, 2026-11-17 evening)

### Session 8 (2026-11-17) - where it stopped
Written at the owner's request (21:39: "write up a claude.md session
handover for that and we'll try next time").

Pushes, checked file by file (CR LF / BOM aside):
- Epubunum 827bed1 = zips 91 + 92 (+ IDE re-saves). NOT PUSHED: zip 93
  (Big Picture full screen - CONFIRMED by the owner on Windows 21:27:
  "Full Screen no menu / taskbar") and zip 94 (this handover). 93's
  files: demos/common/uSteam.pas, demos/EpubReader/src/uMain.pas,
  CLAUDE.md.
- TFFMpegAPI 0795d19 = FFmpegAPI-14 (macOS AudioQueue sound - CONFIRMED:
  play / pause, jumps, speed slider, end of an audio file).
- TSteamAPI 7953ab9 = BigPicture1. NOT PUSHED: FullScreen2 (= FullScreen1
  + its handover). TSteamAPI's own CLAUDE.md has its half of the plan
  below.

Done this session (sections "Zip 77" - "Zip 93" below): calibration,
Steam builds (Reader 5639840, Builder 5639910), libraries next to the
programs, the Deck crash (FreeType) fixed, build stamp, Mac sound, and
the first stage of the big-screen work: the screen: line in both
programs' logs (TSteamAPI's SteamScreenInfo), Per Monitor v2 DPI
awareness (Windows), Big Picture maximise applied once the form exists,
then real full screen without EpubReader's menu.

NEXT TIME - BIG PICTURE SWITCHED WHILE RUNNING (owner's observation:
switching Steam into / out of Big Picture leaves the program as it was;
SDK 1.65 has no callback for it):
1. TSteamAPI polls IsSteamInBigPictureMode about once a second and logs
   every change. Owner runs EpubReader (Steam build), switches modes,
   sends the debug log (uSteam already puts Steam's later lines in it).
2. Only if Steam reports the switch: TSteamAPI's OnBigPictureChanged and
   the window following both ways (TSteamAPI's CLAUDE.md). Here: uSteam
   passes the event on (SteamBigPicture must then read the live value);
   EpubReader re-parents mnuMain (Parent := Self / nil, RecreateOSMenu)
   or shows / hides mnuBar on Linux; EpubBuilder keeps its menu.

THEN (owner's plan, 2026-11-17; decided: EpubReader now, EpubBuilder
later; screen detection and the pad menu as TSteamAPI units; automatic
switch with an override setting):
- Screen logs still wanted: Deck Game Mode and Desktop Mode, the Mac
  (first compile of Steamworks.FMX.Screen's macOS / Linux code).
- EpubReader's big-screen interface: tool bar, contents, library sized by
  UiScale; a setting (Auto / on / off, and a size override).
- The pad overlay menu (VirtualGamepad's, made a TSteamAPI unit) and
  EpubReader's pad controls: hold Start for the menu (Library, Contents,
  Text size, Dark mode, Speed, Exit); D-pad / stick scroll and pages, A
  play / pause, shoulders sentence back / on, triggers chapter; library
  as a grid of covers. Needs a Steam Input action manifest for EpubReader
  (TSteamAPI's gen_input_mapping.py) and the partner site's Steam Input
  setting. In Big Picture Exit is only Steam / Alt+F4 until then.
- Offered earlier, not asked for yet: offer to calibrate when an
  uncalibrated model is chosen; deploy_redist.py --core for the Linux
  Steam depot; the FreeType launcher lines in TSteamAPI's own .sh files.

### Session 7 (2026-11-16 evening)
Written at the owner's request ("write a session handover ... so I can
get a code review done"). The sections further down hold the detail and
the history, one per zip.

### Repositories and where they stand

| Repo | Pushed | = zip | Last zip number used |
|---|---|---|---|
| WhisperBooks/TWhisper | d669a06 | TWhisper-30 | 31 (review fixes) |
| WhisperBooks/Epubunum | 51bb81e | EpubUnum-94 | 96 (95 Mac ggml backends in redist.sh, 96 aladdin.m4a deployed - NOT pushed; 93 Big Picture full screen and 94 this handover NOT pushed; 90 screen log, 91 DPI awareness, 92 Big Picture late maximise; 77 calibration, 78 Steam builds, 79 libraries copied by the builds, 80 - 83 fixes from the first Steam build, 84 EpubBuilder's Linux launcher, 85 Mac libraries through Deploy, 86 Deck crash diagnostics, 87 build stamp, 88 crash place in the log, 89 FreeType for Steam's Linux runtime) |
| G3DGames/TFFMpegAPI | 0795d19 | FFmpegAPI-14 | 14 (macOS sound) |
| G3DGames/ffmpeg-dev | 4d7b7be | ffmpeg-dev-09 | 09 |
| WhisperBooks/whisper-dev | 9fa21dc | whisper-dev-20 | 21 (review fixes; its own CLAUDE.md) |
| G3DGames/TSteamAPI | 7953ab9 | BigPicture1 | FullScreen2 NOT pushed (zips named by topic + number: Screen1-3, BigPicture1, FullScreen1-2; Screen4 declined) |

Checked 2026-11-16 21:18 against the deliveries, file by file (CR LF /
BOM aside): everything matches. The IDE re-saved the four EpubUnum .dproj
files (default platform now Linux64 - the owner's IDE; ProjectName lines
dropped from the packages; *.deployproj files added). EpubBuilder.dproj
and EpubReader.dproj now carry deploy entries from tools/deploy_redist.py
(115 / 16, the run WITHOUT the ROCm kernel folders) - on a machine without
redistributable_bin/Linux64 Deploy reports those files missing.

### Standing rules (owner)

- Never commit or push, and never offer to.
- Zips: only files changed since the previous zip, paths from the repo
  root, named TWhisper-NN-topic.zip / EpubUnum-NN-topic.zip /
  FFmpegAPI-NN-topic.zip / ffmpeg-dev-NN-topic.zip /
  whisper-dev-NN-topic.zip; numbers never reused (a corrected zip gets
  the next number and says what it replaces); every delivery says what it
  goes on top of.
- Every delivery ends with either "NO PACKAGE REBUILD" or: a blank line,
  `=====> PACKAGE REBUILD NEEDED <=====`, a blank line, then the packages
  in build order, the units changed, what to rebuild after.
  TWhisper: WhisperAPI -> WhisperAPIFMX -> dclWhisperAPIFMX.
  EpubUnum: EpubUnum -> EpubUnumFMX -> dclEpubUnumFMX.
  ONLY when a package unit changed (owner, 2026-11-16: program-only
  changes are "NO PACKAGE REBUILD"; rebuilding the program goes without
  saying).
- ASCII sources; PasDoc on every declaration; run tools/pasdoc_check.py
  and tools/project_check.py before delivering (both repos).
- .dproj files: do not change platform lines or the default platform;
  never run gen_projects.py --force on existing projects. Group projects
  are edited by hand. (deploy_redist.py edits only its own DeployFile
  entries.)
- README code blocks paste as-is: comments on their own line, no
  <placeholders>.
- Never offer DRM removal; refuse protected files with a clear message.
- Copyrighted test books stay local - never committed, uploaded or
  quoted. Night Watch (Pratchett, English and German) is one: the owner
  sends logs only (their "worth a look" lines quote a few words - do not
  repeat them).
- No absolute paths, user names, machine names or e-mail addresses in
  tracked files.
- Answer simple questions directly and briefly first.
- When the owner's message arrives mid-task, address it in the same turn.
- In uMain, names Winapi.Windows also has (TBitmap, DeleteFile) are
  written qualified (FMX.Graphics.TBitmap).
- Shell scripts need the executable bit in git (`git update-index
  --chmod=+x`); check after a push.

### Session 7 in brief - what changed (for the review)

EpubUnum (zips 39 - 71):
- lib/Epub.Book.pas, lib/Epub.Writer.pas: audiobook chapter marks in the
  book (epubunum-audio-chapters.xml, item eu-audio-chapters; epubcheck
  0/0); the writer's marker meta epubunum:writer (WrittenBy) so a built
  book is recognised.
- fmx/Epub.FMX.View.pas (PACKAGE): progress footer (ShowProgress);
  ChapterBreaks (a rule between audiobook chapters); zip 71 Fonts - one
  TSkTypefaceFontProvider per view, every paragraph builder uses it
  (fixes the Linux hang; compiled and working on Linux, Windows look
  not re-checked).
- demos/EpubReader/src/uMain.pas: Library (cover grid, cover cache
  beside the settings, text covers, current book large), File >
  Library; Linux menu bar; chapter choice from the toc or the audio's
  marks (BuildChapters - ReadAtStart, K > ReadCount, paragraph snapping,
  zips 54 - 56); debug log calls; Posix.Unistd on POSIX; test switches
  EPUBREADER_NO_COVERS=1 and EPUBREADER_FONT=<family> (decide: keep or
  remove).
- demos/EpubBuilder/src/uBuilder.pas: overwrite question; built-book
  warning; front / back matter out of "worth a look"; chapter marks from
  the m4b's parts; saved transcript off by default and refused for
  another model; close guard; JOB QUEUE (Add To Queue, Run Queue,
  Load / Save, per-build .log, queue report <queue>.md + .csv, 34
  columns); debug log (thread lines written at once, whisper.cpp / ggml
  lines through a log listener); time left from the transcription's own
  rate.
- demos/common/uDebugLog.pas (new): <program>-debug.log beside the
  settings, .old kept, each line opened / appended / closed.
- tools/: redist.sh (collect / deploy / package - core, cuda, rocm
  .tar.gz with licences and SHA256SUMS, GPU parts found with ldd),
  redist.bat + redist-package.ps1 (Win64; the .ps1 is UNTESTED - no
  PowerShell here), deploy_redist.py (DeployFile entries; --skip).
whisper-dev (01 - 20): RUNPATH $ORIGIN, -ffile-prefix-map, libgomp
copied; cmake/bundle_linux.cmake - CUDA / ROCm runtimes bundled by real
path, patchelf $ORIGIN on them and the backends, rocBLAS / hipBLASLt
kernels for the HIP targets (files or per-GPU folders), licences (Debian
copyright files, CUDA EULA, ROCm component texts); CUDA_ALL without sm_50
for CUDA 13; HIP on when ROCm is installed; ROCm 7.x root
(core-NN) found; build.sh deletes CMakeCache.txt each configure;
container-build/ (Ubuntu 22.04 = glibc 2.35, Kitware CMake, patchelf,
CUDA 13.5, LunarG Vulkan SDK, ROCm 7.16 via amdgpu-install 31.60 jammy +
the amdrocm-*-dev packages; build.sh: same-path mount, Podman keep-id,
SDK check before compiling, CUDA_ALL=ON by default; README for people
without Docker).
ffmpeg-dev (07 - 09): /usr/local prefix with DESTDIR staging, BUILD_ROOT,
container pointer. TWhisper (30): --from-json without parts fix; Linux
notes.

### Suggested review focus

1. Epub.FMX.View.Fonts: the Skia4Delphi calls, behaviour on Windows
   (same faces as before?), FontFamily / MonoFamily changes, fallback.
   Then: lay out only the blocks near the view (Night Watch's document 6
   has 31851 words; every layout is still the whole document).
2. uBuilder's job queue and thread hand-over (TThread.Queue callbacks
   after the form or the job list changed; the queue file saved after each
   job; the report's columns).
3. uMain.BuildChapters (three rounds of fixes in one evening).
4. uDebugLog: the lock is freed in finalization while a worker thread
   could still log at shutdown; per-line open / close cost with chatty
   ggml output.
5. bundle_linux.cmake and container-build/build.sh (shell quoting,
   Docker vs Podman, what happens without patchelf / dpkg).
6. redist.sh package (ldd on our own libraries, tar of a name list),
   deploy_redist.py (regex edit of the .dproj XML).
7. Leftovers to decide: the two EPUBREADER_* switches; the deploy
   entries in git; Linux64 as the projects' default platform.

### Results this session

| Night Watch (14 h 41 min, 75 parts) | Time | x real time | Exact | Verdict |
|---|---|---|---|---|
| base.en, GTX 1650 4 GB, Linux, CUDA0 | 34:54 | 25 | 91.2 % | 95.6 % |
| base.en, GTX 1650, Linux, Vulkan1 | 27:57 | 32 | 91.1 % | 95.7 % |
| base.en, RTX 5090 laptop, Windows | 15:57 | 55 | 91.1 % | 95.4 % |
| turbo, GTX 1650, Linux, Vulkan1 | running at handover, about an hour | | | |
Linux loses nothing in quality. On the 1650 Vulkan beats CUDA for base.
German Night Watch: a German colleague: "Feels like a real speaker.
Nothing to complain."

### Open / next

- Steam: a beta branch (steps given 2026-11-16); the reader under Steam
  Linux Runtime 3.0 (sniper) as a non-Steam game - COPY
  ~/.fmxlinux/libfmux-1.0dev.so beside the program (the programs load
  it from the home folder now; a Steam Machine has none); then the
  builder; the GPU backends as free DLC ("Shall we do this").
- Deploy test 2 and the 2 GiB paclient limit (Later tests 4).
- The aligner front edge (Later tests 6, TWhisper).
- Lazy layout in TEpubView (review focus 1).
- macOS: AudioQueue output in TFFMpegAPI, Metal; Info.plist types.

### Later tests (owner, 2026-11-16: "stick that in 'later tests' - bit
busy testing base functionality")

1. WHERE THE TIME GOES PER WINDOW. On the owner's GTX 1650 (Linux,
   Night Watch, 14 h 41 min) base.en took 34 min 54 s on CUDA0 and
   27 min 57 s on Vulkan1; the RTX 5090 (Windows) 15 min 57 s - only 2.2x
   the 1650, so for SMALL models a fixed cost per 30 s window dominates.
   (large-v3-turbo is NOT close to base on the 1650: about an hour against
   28 min - the first "quite close" came from the old time-left estimate.) First suspect DTW (word times, after every window, largely CPU -
   EpubBuilder held ~75 % of a core, GPU ~60 % with base); then token
   choice / bookkeeping, then host <-> GPU copies. Recipe (EpubBuilder
   cannot do part of a book):
   a. a 10 min cut: ffmpeg -ss 00:13:00 -t 600 -i NightWatch.m4b
      -ar 16000 -ac 1 nw10.wav
   b. speed without DTW, both models, both devices: WhisperConsole
      --bench ggml-base.en.bin nw10.wav en --seconds all --devices
      CUDA0,Vulkan1 --also ggml-large-v3-turbo.bin
   c. the same with DTW as the builder runs it: time WhisperConsole
      <model> nw10.wav en --device Vulkan1 --words --no-context
   b against c = DTW's share. If large: DTW's alignment heads on the GPU,
   or DTW only where the aligner needs it (a TWhisper item; matters most
   on small GPUs - the Steam Machine's too). Needs a Linux WhisperConsole
   (Delphi) next to the same libraries.
2. Offered, not built: EpubBuilder "transcribe only the first N minutes"
   (try a model on a new book before an overnight run; would also do 1).
3. HIP against Vulkan on the Steam Machine (the DLC plan's step 4).
4. Deploy: the full EpubBuilder set (1811 files, 2287 MB) failed in
   paclient's Clean with "E0009 Range check error"; without the kernel
   folders (115 files, 1760 MB, longest name 50) it deploys. Test 2:
   deploy_redist.py --skip "^lib(cublas|cudart|ggml-cuda)" (kernels in,
   under 2 GiB): deploys = the 2 GiB total, fails = the kernels' names.
5. DONE (zip 71): EpubReader "not responding" on Linux was Skia asking
   fontconfig for the family once per paragraph; fonts are now looked up
   once per view. Owner: "Otherwise its fine now".
6. Aligner front edge (owner deferred, 2026-11-16): with base.en the
   first 3 words of Chapter 1 were not highlighted (turbo's book was
   right): unmatched words before the first match count as front matter.
   Fix in TWhisper's aligner: words before the first match INSIDE a part
   that has audio are spoken - time them between the part's start and the
   first match (interpolated); only words before the first part's audio
   stay unhighlighted.

### Plans agreed or parked (detail in the CLAUDE.md files)

- GPU backends as free Steam DLC; video in books (game manuals) - both
  in "Shall we do this" below.
- Volunteer transcribers (design only): a job server, workers poll,
  LibriVox section files as jobs. TWhisper CLAUDE.md, plans.
- Audio outside the book: timings beside the original EPUB, LibriVox
  downloads by URL, an edition check. "Shall we do this".
- Builder: go to the suspicious stretches from the results; "transcribe
  only the first N minutes" (offered).
- German / other-language number words in TWhisper's aligner.
- Parked: sentence alignment between an English and a German book.

### Working notes for the next session

- Nothing compiles Delphi / FMX here: lib/ and the consoles build with
  FPC 3.0 (set up in the session from fpc-lambda, with a
  TStringBuilder stand-in for TWhisper); the owner's Delphi build is the first compile of anything
  FMX - expect the odd fix (zip 61 was one).
- The owner's machines: Windows, RTX 5090 laptop (CUDA 13.5, Delphi 13,
  PAServer client); a Linux test laptop: Ubuntu 26.04 (glibc 2.43,
  uutils coreutils - `tail -n 6`, not `tail -6`), GTX 1650 4 GB, driver
  580 (CUDA 13.0: only compiled SASS works, no PTX from 13.5), Docker,
  PAServer scratch-dir/<profile>/<program>. A Clean through PAServer
  empties the program's folder (libraries too) - hence deploy_redist.py.
- Linux libraries: build in whisper-dev's container (whisper-dev, then
  `container-build/build.sh ../ffmpeg-dev`), then `sh tools/redist.sh
  collect ../whisper-dev ../ffmpeg-dev` in Epubunum; to Windows with
  `scp -r` (links become copies; fine), then deploy_redist.py.
- Debug logs: ~/.config/EpubReader/EpubReader-debug.log,
  ~/.config/EpubBuilder/EpubBuilder-debug.log (.old = the run before).
  A hung program: `sudo DEBUGINFOD_URLS= gdb -nx -batch -ex "set
  debuginfod enabled off" -p <pid> -ex "thread apply 1 bt 30"`
  (without the debuginfod switches gdb sits downloading symbols).
- Tests worth setting up again: epubcheck 5.2.1 on every overlay EPUB;
  every clip = its timing and ClipAt finds it; --from-json re-alignment
  of moby.json (209652 exact) as the aligner's regression test.

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

Last number used: 96.

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
directory (a small file can ask for 2 GB) [zip 11: data ranges checked,
Extract streams]; a descendant selector
('.poem p') is applied to every element matching its last part; style
sheets are parsed once per DOCUMENT, not per CSS file, and StyleOf scans
every rule and parses the declarations again for each element; ClipAt
returns a clip without clipEnd for every later time; the XML tree and the
layout walk recurse without a depth limit; ExtractAll skips every name with
'..' in it ('Wait....xhtml'); [fixed in zip 09: with FPC, UTF-16 text
is converted with string(W), not UTF8Encode]; Active := True fails silently without
OnOpenFailed; no LICENSE file.

## EPUB writing (zip 09, on top of ef2daff "Claude review push")
Owner, 2026-11-15: next work item 1, "EPUB writing: media overlays (SMIL),
word spans, package update - so TWhisper can write synced books".
Decisions (owner): "Matching is a TWhisper job. User can decide but default
to word level". So:
- lib/Epub.Writer, TEpubWriter: takes TIMED WORDS ONLY - (index into
  TEpubBook.Words, audio file, clipBegin, clipEnd). No text matching here.
  Level: eolWord (default; a span per timed word) or eolBlock (the
  paragraph / heading / list item gets an id, one clip per block run).
- Spans are INSERTED into the source text (never re-serialised): the
  parser now records source positions (TEpubXmlNode.SrcPos / SrcLen /
  SrcEnd / CData, TEpubXmlDoc.Source; EpubXmlRawIndex maps a decoded index
  back), and the ONE walker records where each word is
  (TEpubDocLayout.Create(..., AWithSources), Sources; TEpubBook.
  DocumentSources). A word split by markup ('<i>Moby</i>-Dick') gets its
  span on the first piece - the walker counts every word touching an
  element, so the id still holds exactly that word.
- Every tagged document is CHECKED before writing: laid out again it must
  give the same words, and each new id must hold exactly its word.
- A word alone in an element with an id keeps that id (Moby-Dick's
  c01w00001; writing a written book again adds 0 spans).
- Package: SMIL / audio / css / nav items, media-overlay, media:duration per
  overlay + total (kept overlays' values counted), media:active-class (when
  the book has none, plus epubunum-overlay.css linked from the tagged
  documents so other readers highlight), media:narrator, dcterms:modified.
  Edits are insertions / tag rewrites on the source, indented like the
  file. A manifest href with a space is written with %20.
- EPUB 2 -> EPUB 3 (overlays need it): version, nav from the NCX,
  opf:role / opf:file-as -> refines metas, other opf: attributes and
  extra dc:date dropped, HTML5 doctype + named entities as &#N; (the HTML5
  doctype declares none: &nbsp; was FATAL in epubcheck).
- Other files are copied RAW (TEpubZipWriter.AddRaw / TEpubZipReader.
  ReadRaw, size checked against the file); audio from disk is stored in
  pieces (AddFileStored), never loaded whole.
- EpubConsole: --words, --overlay TIMINGS OUT [--audio F | --book-audio P]
  [--block] [--narrator N], --clip-timings (test aid).
Also in zip 09 (found while testing):
- FPC UTF-8: EpubBytesText / EpubUtf8Bytes / CodeText converted through
  the system code page (UTF8Decode -> string): with no UTF-8 locale every
  non-ASCII character became '?' - in the words, and in written files.
  Now byte copies under FPC (strings are UTF-8 by design). The old build
  gave '?' for "Transcriber's" (curly quote) on Moby-Dick even with
  LANG=C.UTF-8. Delphi unchanged.
- Speed for word-level books (Moby-Dick with 212,881 clips): ReadOverlays
  grew FClips by one per clip and resolved two paths per par (now doubled
  capacity, paths cached per file); the walker grew FIds by one (now
  doubled); ClipWords scanned the ids (now a sorted index per document,
  first of a repeated id wins); ClipAt starts at the last clip found when
  the clips are ordered (FClipsOrdered); EpubClockValue used a TStringList
  and copied FormatSettings (~50 strings) per value (now split by hand,
  DotSettings set once - also in Epub.Css); StyleOf caches its answers
  (key: element, class, style, and the id only when a rule names it);
  TEpubXmlNode.LocalName is cached. Open + LoadText of that book: 3.1 s ->
  2.2 s (FPC -O2, Linux; most of it is parsing 46 MB of SMIL). The
  original Moby-Dick: 0.24 s -> 0.18 s.
TESTED here (FPC 3.0 from fpc-lambda, Linux x64, static link - no -k-ldl;
epubcheck 5.2.1 from its GitHub release; Moby-Dick from IDPF epub3-samples
20230704): word level for Moby-Dick's own two chapters (timings from its
clips), + chapter 3 new with a second audio file, block level, every word
of the book, a written book written again, a synthetic EPUB 2 (NCX,
opf:role, two dc:date, XHTML 1.1 doctype, &nbsp; / &mdash;, a word split
by <i>, a word across <a><sup>, ruby, pre, display:none, aside footnote,
a file name with a space). epubcheck: 0 errors / 0 warnings (the EPUB 2
sample only keeps its own fake cover PNG error). A test reader re-opened
every result: same words (text, role, document), each clip's words =
exactly its timed word, timings to the ms, ClipAt forwards and backwards.
Every tagged document = the original with only our markup inserted
(byte check). Old vs new library on Moby-Dick and the sample: same text,
layout and info apart from the '?' fix.
NOT RUN: Delphi build (owner), EpubReader on a written book. TO TEST:
build the packages (EpubUnum has a new unit), EpubConsole --overlay as in
its README on Moby-Dick, then open moby-words.epub in EpubReader: the
highlight must move word by word; the prev / next clip buttons now step
one WORD (a reader feature to decide: sentence stepping).
Known, not done: sentence level (a sentence can cross inline markup);
block level picks the innermost block, so a div's loose text after a p
gets a clip on the div (its highlight covers the p too); a word-level
book's SMIL parse dominates opening (a dedicated SMIL scanner would cut
it); non-core audio (wav, ogg, flac) is written with a warning only.

## Reader navigation and dark mode (zip 10, on top of zip 09)
Owner, 2026-11-15, after zip 09: "Chapter forwards / backwards that syncs
to the start of a chapter"; "next/prev ... non-sensical at word level.
This should be sentence / paragraph (selectable - a drop-down for now is
fine)"; "Dark mode would be good as well".
- Chapters = Toc entries in reading order (an entry at the place of the
  one before - a part and its first chapter - is merged; no Toc: the linear
  documents). Previous / next chapter and a contents click show the
  chapter AND move the audio to its first clip inside the chapter (a
  chapter without audio stops playing, nothing jumps to a later
  chapter's). Paused: FSeekClip - Play starts there instead of resuming.
  lbToc follows the clip being read (FSyncingToc: no jump).
- Steps by sentence / paragraph (cbStep, a TComboBox in the tool bar), on
  WORDS, not clips: a paragraph = a block of the walker's layout; a
  sentence ends at a block end or a word for which EpubEndsSentence
  (Epub.Layout, new; closing quotes stripped; Mr. / Dr. / St. ... and
  initials are not ends) is True. Then the first clip at or after that
  word. Checked with FPC on Moby-Dick: every one of its own sentence clips
  starts at a sentence start (its three word clips are the only others).
  Previous: start of the sentence being read; within BACK_GRACE (1.5 s of
  audio) of it - or paused at it - the one before.
- Dark mode (moon button, D): TEpubView's four colours, the form's Fill,
  lblStatus, the contents' item text and its style's 'background' shape
  (TocApplyStyle on OnApplyStyleLookup; light = the style re-applied).
  Zip 12 (owner: "Dark mode makes the sidebar unreadable" - light text on
  the style's white): dark sets lbToc.StyleLookup :=
  'transparentlistboxstyle' (FMX's own), so the form's dark Fill shows
  through; TocApplyStyle stays as a fallback (a 'background' shape made
  dark, another kind hidden). Light: StyleLookup ''.
  The tool bar's buttons and the combo box keep the platform style. Not
  remembered between runs (the reader keeps no settings yet).
NOT COMPILED (no Delphi here): uMain.pas changes are the owner's build.
TO TEST: chapter buttons while playing and paused; a contents click while
playing; sentence / paragraph steps on moby-dick-word-level.epub and the
original Moby-Dick; D on and off (the contents panel's background - if
the style names its background differently, it stays light).

## Streamed extraction (zip 11, on top of zip 10)
Owner, 2026-11-15: "Yes fix streaming" - the LibriVox Moby Dick m4b files
(Stuart Wills: 5 x 140 MB; Peter Dann: 3 x 225 MB) are copied out by
EpubReader before playing, and Extract read the whole entry into memory.
- TEpubZipReader.ReadTo(AIndex, AOut): stored or deflated, 1 MB pieces,
  CRC over the pieces, short data and the data range checked against the
  file. Extract uses it and deletes the file on any error. Tested (FPC): a
  300 MB entry, stored and deflated, byte-identical, peak 13 MB; the 9 MB
  deflated Moby-Dick mp4 = unzip's; a flipped byte -> "damaged (CRC)",
  no file left; ExtractAll of a written book = unzip's.
- ReadBytes checks the data range against the file too.
Still so: ReadBytes allocates the size the directory declares (a small
file can still ask for up to 2 GB when read whole; Extract does not).
NOTE: the IDPF Moby-Dick sample's audio is LibriVox's Stuart Wills
recording (chapters 1-2, the LibriVox intro before 24.5 s): TWhisper on
the Wills m4b files can be compared with that human-made sync (sentence
clips; offsets differ - find the median first).

## Shall we do this - and if so, how to do the UI
Ideas kept for later (owner, 2026-11-15): "keep them in a 'Shall we do
this and if so how to do UI' section". ORDER (owner): "once we've got the
reader at a satisfactory pausing point we can improve the other
contributing components / systems" - reader first, then TFFMpegAPI etc.
- LEARN TO READ: BUILT in zip 18 (see "Learn to read (zip 18)" below).
  Original notes kept:
- LEARN TO READ mode (owner's idea: "if the playing was paused and the
  user pressed fwd it could say the word ... people learning to read or
  learning to read a new language"; "a 'Learn To Read' switch ... owing to
  the differing use of the control(s)"). Proposal, not agreed in detail:
  a toolbar toggle (+ a key, e.g. L). In the mode: the step drop-down gets
  Word / Sentence / Paragraph (Word default); paused Next / Previous MOVE,
  THEN SAY the unit and stop (what is seen is what is heard); a "say
  again" key (Space or R) repeats the highlighted unit; a click on a word
  says just that word; Play still reads on. Next with nothing highlighted
  says the page's first word. Owner said "probably you want to read the
  currently highlighted word then move" - the say-again key covers that;
  confirm the order when it is built.
- NEEDS (other components, after the reader): TFFMpegAPI play range -
  TFFmpegAudioPlayer.PlayRange(Begin, End), the output stops feeding
  samples at End (the reader's 100 ms timer would let a ~300 ms word run
  into the next). Pad words 30-50 ms each side (consonants). Good word
  timings: TWhisper's DTW words, not clips shared out by length (the
  zip 09 test book's words are approximate - owner: "completely
  understandable").
- Speed change: DONE in zip 15 (slider 0.5x - 2x). 0.25x (owner: "down to
  0.25 or 0.5") needs TFFMpegAPI to chain two atempo filters (one goes
  down to 0.5): its MIN_SPEED, then SPEED_MIN here.
- AUDIO OUTSIDE THE BOOK (owner, 2026-11-15: "a strong case for (1+3)").
  (1) Timings file beside the ORIGINAL, untouched EPUB (small download,
  reads without audio); the reader finds the timings + audio and builds
  the overlays in memory. Only our reader plays it. (3) The complete
  EPUB with the audio inside (what --overlay makes now; works in every
  reader). (2) Remote audio URLs in the overlays - EPUB 3 allows it, few
  readers do. To decide: how the reader finds timings / audio (same
  folder + name, or picked), and an EDITION CHECK (word count / hash of
  the text) so timings made from another edition are refused.
  LIBRIVOX: their recordings and the Gutenberg texts are public domain;
  a timings file can name LibriVox's own download (archive.org URL +
  size / checksum) instead of a local path, so only book + timings are
  published and the reader fetches the audio. LibriVox readers mostly read
  a known Gutenberg edition: one timings file per recording + edition.
  Owner: "an interesting option to talk to them about". Volunteer GPU
  transcribers for this: TWhisper CLAUDE.md, plans.
- DROP UNUSED AUDIO: --overlay keeps the source book's audio even when no
  overlay plays it any more (moby-dick-mo.epub's
  mobydick_001_002_melville.mp4, 9 MB). Owner: "no big loss" for now.
- STEAM DECK (owner, 2026-11-15): the reader has TSteamAPI's platform fixes
  already (native Linux64 + EpubReader.sh, or Windows under Proton).
  Needs: Steam Input via TSteamAPI - proposed A play / pause, d-pad
  sentence, bumpers chapter, triggers speed, Y dark, B contents, stick /
  trackpad scroll, touch = click a word; a 1280x800 layout (bigger
  buttons, contents hidden); remembered settings; a test in Game mode.
  Needs TSteamAPI's current source in the session.
- TESTED (owner, 2026-11-15): the reader on a Lenovo Miix 520 tablet
  ("a hugely underpowered pile of junk") - "Worked perfectly and very low
  system usage". Deploy: EpubReader.exe, sk4d.dll, FFmpeg's avutil-60,
  swresample-6, avcodec-62, avformat-62 (+ swscale-9, avfilter-11 for
  the speed slider), the .epub (audio inside).
- VIDEO IN BOOKS - GAME MANUALS (owner, 2026-11-16: "developers having
  epub3 manuals for games ... the addition of video would allow for things
  like playing the intro cut-scene or maybe used to illustrate some game
  mechanics"; "a definite shall we do this"; after the Linux / macOS work
  unless the owner moves it). EPUB 3 allows HTML5 <video> in content
  documents; no core video type (MP4 H.264 + AAC is the safe choice, WebM
  the other), video is exempt from fallbacks; media overlays stay audio
  only (a video cannot drive the highlight). Apple Books / Thorium play
  it, Kobo / Kindle conversions mostly do not. Today: TEpubWriter copies
  videos unchanged; TEpubView shows only text and pictures. Steps:
  1. Layout: <video> a block like <img> (Epub.Layout: kind, src, poster,
     width / height or the video's own size).
  2. View: the poster (or the first frame, decoded by FFmpeg) with a play
     mark; a click plays.
  3. Playing in place: TFFMpegAPI's video decoding (swscale side,
     FHasVideo) into an ISkImage the view redraws; its sound through
     TFFmpegAudioPlayer with the narration paused; controls (play /
     pause, seek bar, full screen - cut-scenes, the Steam Deck). The real
     work of the item.
  4. Straight from the book: videos are stored (not deflated) in the
     EPUB, so FFmpeg can read the entry in place (custom AVIOContext over
     the zip's data range, TEpubZipReader.ReadRaw / the entry's offset)
     instead of extracting to the temp folder as narration audio is now.
     A TFFMpegAPI change.
  5. Authoring note for developers: MP4 (H.264 + AAC), a poster image,
     fallback text, sizes; nothing to change in the writer. Our FFmpeg is
     LGPL: decoding H.264 is fine; encoding it is the developers' tool's
     job (GPL x264 builds).
  Fits the Steam side: a manual readable on the Deck, opened from the
  game or Steam (TSteamAPI).
- GPU BACKENDS AS FREE STEAM DLC (owner, 2026-11-16: "On Steam the DLLs
  could be DLC. Everyone gets Vulkan, download DLC for CUDA or HIP. This
  also makes the footprint smaller on the end users machine";
  "definitely"). Matches tools/redist.sh package's parts (zip 63):
  | Steam | part | for |
  | base game depot | core (whisper, ggml CPU + Vulkan, FFmpeg, libgomp) | everyone |
  | free DLC "NVIDIA CUDA acceleration" | cuda (~1 GB) | NVIDIA owners |
  | free DLC "AMD ROCm acceleration" | rocm (~1 GB) | AMD owners |
  A DLC's depot installs into the game's own folder - next to the
  program, where the libraries must be ($ORIGIN): no code change, ggml
  just finds no CUDA / HIP backend without the DLC (Vulkan and CPU
  listed). Each DLC carries its licences (CUDA EULA / ROCm texts, the
  licences/ split the packages already make). Valve: each DLC an app ID
  and a small store page, reviewed once; free DLC allowed.
  Steps: 1. Steamworks: two DLC app IDs, a Linux depot each (+ Windows
  depots with redist.bat package's parts), the base depot without the
  GPU parts. 2. The build scripts (app_build / depot .vdf): one content
  root per part, from redistributable_bin/packages unpacked (or
  redistributable_bin/<platform> filtered like package does). 3. HINT IN
  EPUBBUILDER (and the reader if it ever transcribes): GPU vendor seen
  (Vulkan device names: NVIDIA / AMD) without its backend -> "CUDA (or
  ROCm) acceleration is a free download" with a button: TSteamAPI's
  BIsDlcInstalled / InstallDLC (ISteamApps); outside Steam the release
  package to download instead. 4. Measure before recommending: on the
  owner's GTX 1650 CUDA and Vulkan are close for base: CUDA 34 min 54 s
  for Night Watch (14 h 41 min of audio, 25x real time), Vulkan "c 31
  mins" (the 20 min first seen was the old time-left estimate); HIP
  against Vulkan on the Steam Machine is not known yet - the hint should
  say "may be faster", or be shown only where measured faster.
- Say a sentence, then step through its words.
- The current word shown large in a strip under the page.
- Remember reader settings between runs (dark mode, step unit, text
  size): the reader keeps none yet.

## Timings with their audio (zip 14, on top of 6ab27c4)
EpubConsole --overlay without --audio / --book-audio takes the files from
the timings' own "# audio N: path" lines (WhisperConsole --timings, TWhisper
zip 21, writes them; a relative path is relative to the timings file; a
missing file is an error). The sync pipeline (TWhisper and Epubunum stay
separate): EpubConsole --words -> WhisperConsole --align-words --timings ->
EpubConsole --overlay. Tested here: a synthetic transcript of Moby-Dick
ch 1-2 over two m4b files (the IDPF mp4 cut at 860 s) -> 3672 clips,
epubcheck 0 / 0, every clip = its timing.

## Words split at dashes (zip 15, on top of 26118e5 = zip 14 pushed)
Owner, Moby-Dick ch 135 in the reader: "calm-frozen" and "it!-it's" (em
dashes) lit as one word. The walker (TWalker.AppendText, DashAt) now ends
a word after a dash U+2012 - U+2015 that follows text: 'calm' + dash,
then 'frozen'. A dash starting a word stays on it (dash + 'GENESIS.');
a dash right after one that ended a word is a word of its own (doubled
dashes). The same dashes as TWhisper's WhisperSplitText, so the aligner's
split and EpubUnum's words now agree. WORD NUMBERS CHANGE: Moby-Dick
212881 -> 214492 words (1611 more); old timings files must be made again
(--words, then WhisperConsole --from-json --align-words --timings).
Tested here: the owner's moby.json realigned against the new list - same
aligner figures (TWhisper zip 23), 213544 timed words; --overlay (stand-in
audio) 213544 clips, 0 left out; epubcheck 5.2.1 0 / 0; checkover (every
word's clip = its timing) and onlyinserts (only markup inserted) clean.
Sentence steps in the reader: 'it!' + dash no longer ends a sentence
(EpubEndsSentence sees the dash) - right, it is mid-sentence.

Also in zip 15:
- PUNCTUATION NOT LIT (owner: "If a word has some punctuation after it
  the punctuation is highlighted as well"). EpubWordCore (Epub.Layout)
  narrows a word to its letters and digits (ASCII punctuation, U+2010 -
  U+205E, guillemets, inverted marks trimmed at both ends; inner ones
  kept: it's, sperm-whale). Used by TEpubView's highlight (first word's
  start, last word's end) and by TEpubWriter's spans: '<span>whales</span>,'
  and opening quotes outside the span. Reading the book back still ties
  every clip to its word (the walker's word ids are unchanged: checkover
  0 word differences, every clip = its timing), onlyinserts clean,
  epubcheck 0 / 0. The FMX view is NOT compiled here (no Delphi / Skia).
- SPEED SLIDER in the reader (owner: "slider will do ... Default 1"):
  TTrackBar 0.5 - 1.5 step 0.1 (zip 16: owner "0.5 to 1.5 (2.0 sounds
  silly)"; was 0.5 - 2). Zip 17: dragging made the window stop responding
  (owner) - every step set Speed, and each set restarts the player's feed
  (seek + new filter graph). Now the label follows at once and the player
  gets the speed when the slider has rested SPEED_SETTLE_MS (300 ms,
  tmSpeed): once per drag, once per run of [ / ] presses. + a '1.0x' label (click = 1x), keys [ and ];
  sets TFFmpegAudioPlayer.Speed (the feed restarts at the same place).
  Without avfilter / swscale the error goes to the status line and the
  slider returns to 1. NOT COMPILED here.
- ICON: demos/EpubReader/EpubReader_Icon.ico (16 - 256 px: an open book
  with an amber highlighted word and a play badge, drawn here with PIL).
  EpubReader.dproj: ONE line added, Icon_MainIcon in the Base_Win64
  group; nothing else in the .dproj touched. gen_projects.py does not
  write icons (it is never run on the existing .dproj). macOS (.icns) and
  Linux icons: not yet.
- FOUND, for TWhisper (not fixed): 375 words in the Moby timings have a
  10 ms time starting where the next word starts (DTW gave Whisper's
  'the' no length) - in 18 places the reader's ClipAt in the middle of
  such a clip finds the word before. Harmless to hear; TWhisper should
  give such a word part of the gap before it.

## Learn to read (zip 18, on top of 17)
Owner, 2026-11-15: "Learn To Read is also a good thing to have - may also
be useful for proof-reading books (re-labelled but same functionality)".
EpubReader (uMain only): btnLearn ('Abc', StaysPressed) + key L; cbStep
holds Word / Sentence / Paragraph in the mode (Word chosen on entry),
Sentence / Paragraph outside it (StepUnit maps the index: UNIT_WORD /
UNIT_SENTENCE / UNIT_PARAGRAPH; FillSteps refills keeping the unit).
In the mode Next / Previous (LearnStep): StopPlaying, the next / previous
unit (UnitStart / new UnitEnd; IsUnitStart is True for every word in
Word steps), SayWords: highlight + scroll + SyncToc, then
FPlayer.PlayRange(first clip's begin - 40 ms, last clip's end + 60 ms)
(SAY_PAD_BEFORE / AFTER) and stop. No clip (not read): lit, silent, the
previous sound cut. A unit across two audio files is said to the end of
the first file's part. Word steps pass over words with no clip and no
letter or digit. R: say again. Click a word: that word. Play reads on
from the unit (FSeekClip); with nothing said yet after a pause, Next
goes on from the paused sentence, Previous says it. Book open / chapter
jump reset the unit. OpenClipAudio split out of StartClip (the audio
extraction, unchanged). NOT COMPILED here (no Delphi / FMX / Skia).
Proof-reading: same mode, a second label later (owner).
Zip 19 (owner, first test): "The word level accuracy is noticeably bad
here. A single word frequently includes the end of previous word and the
start of the next - possibly reduce the padding to near zero. Sentence on
the other hand is frequently too much prose ... sections of the sentence
between punctuation". SAY_PAD_BEFORE / AFTER 40 / 60 ms -> 0. New unit
PHRASE (UNIT_WORD 0, UNIT_PHRASE 1, UNIT_SENTENCE 2, UNIT_PARAGRAPH 3;
outside the mode the list is Sentence / Paragraph = index + 2): a phrase
ends after a word whose last character (closing quotes stripped) is
, ; : . ! ? or a dash U+2012 - U+2015, or that closes a bracket
(EndsPhrase). Phrase is the mode's default. WORD TIMING: with no padding
any bleed left is the timings' own - DTW word boundaries; on the human
sync, sentence starts were within 0.21 s on average. If single words
still bleed, the fix is in TWhisper (word edges), not here.
Zip 20: owner "phrase works well, drop word as an option" (single words
still bled with no padding, on TWhisper-26 timings). Word steps removed
(UNIT_PHRASE 0, UNIT_SENTENCE 1, UNIT_PARAGRAPH 2; outside the mode the
list is Sentence / Paragraph = index + 1); a click still says one word.
Zip 21 (owner): "In Learn Mode the Play button should play the
highlighted text rather than the next text ... useful if someone had
problems with a specific word. Also Learn Mode should be much more
distinctive". btnPlayClick in the mode: SayWords(FLearnFirst, FLearnLast)
again (nothing said yet: the unit of CurrentWord) - never reads on; its
hint changes. Distinctive: recLearn (TRectangle, Align Contents, behind
layTop's buttons) green band LEARN_BAR / LEARN_BAR_DARK; highlight
LEARN_HIGHLIGHT / _DARK instead of amber (ApplyTheme); LEARN_TITLE
appended to the window title (kept across book opens); status line
prefixed "LEARN TO READ - ".
Zip 22 (owner: "Chapter 1 - clicked Call - that was it": the click said
one word and Play then repeated only that word). A click in the mode now
picks the unit the word is in (UnitStart .. UnitEnd, by cbStep) and says
it; single words are no longer said anywhere in the mode.
TWhisper idea for the bleed: move each word boundary to the quietest
point within ~80 ms of DTW's (loudness per frame, as the benchmark
stretch), at --from-json time - offered, not agreed.

## GUI book builder (zip 23: BUILT, NOT COMPILED - see "EpubBuilder (zip 23)")
"Epub on one side, Audio list on the other and a Create button to take
the parts, run the make steps and build the final ePub you can then open
with reader. Probably integrate Reader at some stage later but for now a
simple GUI." The steps it runs are today's files: EpubConsole --words ->
WhisperConsole (transcribe, --json) + --align-words --timings ->
EpubConsole --overlay. Linking both libraries in one app was always the
plan ("A GUI app linking both can come later", TWhisper zip 21 notes).
To decide: which repo it lives in (it needs TWhisper + EpubUnum +
TFFMpegAPI), progress / cancel for a 20 min transcription, keeping the
transcript JSON so a re-align needs no new transcription, the device /
model choice (TWhisperBenchmark).

## EpubBuilder (zip 23, on top of 22; needs TWhisper zip 27)
Owner: builder in EpubUnum's demos (chosen over TWhisper's demos / a new
repo), linking the libraries in-process (chosen over running the console
exes). demos/EpubBuilder: EpubBuilder.dpr, src/uBuilder.pas + .fmx (form
only; controls built in code), README.md, EpubBuilder.dproj made by
tools/gen_projects.py (new file only - no existing .dproj touched; the
generator gained the project and GROUP_ORDER the name). EpubUnum.groupproj
edited BY HAND: EpubBuilder after EpubReader in Projects, its three
targets, and in Build / Clean / Make (project_check: 0 problems).
Window: book (left: Choose..., title / words / existing overlays; a
protected book refused with the library's message), audio (right: Add
files... / Add folder... sorted by WhisperNaturalCompare, Remove, Up,
Down), below: model, device (TWhisperLib.SelectableDevices; Default),
output (default <book>-synced.epub; never the book itself), "Chapters of
a file are parts" (on), "Use a saved transcript" (on), Create / Cancel,
progress, log. TBuildThread: TEpubBook words without role nav ->
FFmpeg (PATH, else whisper.cpp's folder) -> TWhisperAudioSet -> the
transcript: <output>.transcript.json when its parts are the same files
and starts, else TWhisperRun part by part as WhisperConsole (DTW words,
WhisperCleanTranscription, FillGaps, WhisperAppendTranscription, the
first part's language kept) and saved -> WhisperSplitBookWords /
WhisperAlignText / WhisperJoinAligned -> WhisperWordFileTimes (TWhisper
zip 27) -> TEpubWriter.AddAudioFile + AddWord -> SaveToFile. Progress:
5 % book + audio, 85 % transcription by whisper.cpp's progress per part
weighted by length, then align / write. Cancel: Terminate + Run.Cancel.
NOT COMPILED here (no Delphi / FMX): the owner's build is its first.
Zip 24 (owner's first compile, dcc64): EEpubError is in Epub.Zip (added
to uses); WhisperTimeToStr(Round(SecondsBetween(..) * 100)) "incompatible
types" -> MilliSecondsBetween(..) div 10; TThread.ForceQueue(nil, anon)
"no overloaded version" -> the thread is FreeOnTerminate, BuildDone only
clears FBuild; FormClose of a running build sets FreeOnTerminate False,
cancels, WaitFor (OnTerminate has not run: it runs on the main thread),
frees.
Zip 25 (owner, first run on Aladdin: "More user feedback would be nice -
not sure if it's got stuck"; it was at 60 % in one 34 min part with no
log line since the model loaded): a "Now" status line - the step
(reading, opening audio, loading model, decoding part N, transcribing,
second pass, aligning, writing), during transcription each segment's
text and its time on the joined line (TWhisperRun.OnSegment), plus time
taken and time left (from the progress, once >= 7 %), refreshed every
second by tmStatus so the clock moves during a long part.
Zip 26. FIRST REAL BUILD (owner, Aladdin, 34:32 m4a, Gutenberg EPUB 2):
5212 exact, 29 similar, 15 interpolated, 3056 not spoken (Gutenberg
header + licence: the story from "There once lived" to "kings." is all
timed), 5256 clips, 0 left out; second Create from the saved transcript
in 0.4 s. OPEN: (1) 357.6 s to transcribe (5.8x) where WhisperConsole
did Aladdin at 116x - device "Default"? to test with Vulkan0 and the
saved transcript UNticked; (2) the builder's transcript is ALL lower case
with NO punctuation (150 segments) and starts at 0.00 with "there once
lived" - WhisperConsole's text has both; same params on paper. Both may
be one cause (a slow fallback path / another device). Fixed here:
- epubcheck on the result: 3 errors from the EPUB 2 -> 3 upgrade.
  dc:language xsi:type="dcterms:RFC4646" (xsi: attributes now dropped
  with opf: ones) and meta http-equiv="Content-Style-Type" in the
  documents (WithoutOldHttpEquiv in Html5Text: http-equiv values HTML5
  does not allow are removed). Tested: Aladdin's EPUB set back to 2.0 +
  --overlay -> epubcheck 0 / 0.
- RESULTS in the log after a build (owner: "Stats after completion would
  be nice with explanation"): each figure with what it means, a verdict
  (matched / timed: >= 98 very good, >= 93 good, >= 80 usable, else
  poor - wrong recording or file order?), front / back matter told apart
  from not-spoken text inside the book (a warning past 10 %), and the
  10 longest stretches of 3+ words with time and quote.
Zip 27 - CAUSE of the slow, lower-case transcripts (owner's Vulkan0 run:
still 16x and the same text): the builder used whisper.cpp's defaults -
previous text as context, no prompt. With DTW, flash attention is off,
and TWhisper's own notes (its CLAUDE.md, session 5) say turbo with flash
attention off and the previous text as context falls into loops and
lower-case run-on text; RECOMMENDED for books: --no-context
--carry-prompt + a punctuated prompt - what the owner's Moby-Dick run
used ("previous text as context False, initial prompt in every window",
81x). The builder now sets NoContext, MaxTextContext 0, InitialPrompt
BOOK_PROMPT ("Once upon a time, there was a story. It was read
aloud.") carried into every window, and cleans prompt echoes with it.
A saved transcript made before zip 27 should be made again (untick
"Use a saved transcript" once).
Zip 28 (owner: "persist model and device at least ... somewhere
OS-friendly"): EpubBuilder.ini (TMemIniFile, UTF-8) in %APPDATA%\EpubBuilder
(TPath.GetHomePath), ~/Library/Application Support/EpubBuilder (macOS),
$XDG_CONFIG_HOME or ~/.config /EpubBuilder (Linux): [Build] Model (dropped
when the file is gone), Device BY NAME (the list order can change),
Chapters, UseSavedTranscript; [Folders] Book, Audio (the dialogs open
there). Saved on choosing a model, on Create and on close.
Zip 29 (owner): choosing another book empties the audio list ("started
new book, still had old audio") and sets the output name afresh.
FOREIGN LANGUAGES (owner has Night Watch in German too; "I only want
transcribe, not translate"): Params.Translate := False explicitly;
Params.Language := the book's dc:language primary subtag when whisper.cpp
knows it (else auto); the carried prompt in that language (BOOK_PROMPTS:
en, de, fr, es, it, nl; accented letters as #$xx codes - ASCII source);
other languages: no prompt (NoContext + MaxTextContext 0 still - no
loops; maybe no capitals / punctuation, which the aligner ignores).
KNOWN LIMITS for other languages, in TWhisper's aligner: number words are
English (WhisperNumberWords: "4" -> "four", Roman "IV" -> "four"), so a
German "Kapitel IV" heard as "Kapitel vier" does not match (it is then
interpolated - a few words per chapter heading); letters / similarity
work on UTF-8 bytes (umlauts count as two). Worth a German number-word
table in TWhisper if the German run shows many heading misses.
Zip 30. NIGHT WATCH (owner, English, professional reader, 1 m4b, 75
chapter parts, 14:41:28; copyrighted - local only): 19:32 in all;
108371 exact (95.2 %), 1899 similar, 441 MOVED (the footnotes, read
where called - working: 101, 70, 56, 51 ... word stretches at their
call points), 2029 interpolated, 812 not spoken (mostly back matter:
about the author, copyright - not at the very end, so not counted as
edges), verdict 97.8 % good. Slow parts: opening credits 114 s audio in
85 s, chapters 10, 53, 73 (63-89 s) - music / credits or fallbacks.
- Word edges: TWhisper zip 28 WhisperTrimWordSilence called after
  FillGaps; a saved transcript without TRIMMED_MARK ("word_edges":
  "trimmed", written after the JSON's opening brace by SaveTranscript)
  is trimmed once from the audio (TrimSaved, part by part) and saved
  again - so Aladdin / Night Watch need no new transcription.
EpubReader: RegisterOpenWith at start-up (owner: "add Reader to Open
With association. Maybe later Always open with"): Windows HKCU\Software\
Classes - ProgID EpubUnum.EpubReader (open command, icon), .epub\
OpenWithProgids, Applications\EpubReader.exe\SupportedTypes, then
SHChangeNotify; Linux ~/.local/share/applications/epubreader.desktop
(MimeType application/epub+zip, Exec through EpubReader.sh when it is
there). Only written when missing or pointing elsewhere; the status line
says so until a book opens. "Always": Windows 10/11 let only the user
choose the default (the UserChoice key is hash-protected) - Open with >
Choose another app > EpubReader > Always. macOS: CFBundleDocumentTypes
in the Info.plist - later.
NOT COMPILED here (no Delphi). Open question to the owner: ask before
Create replaces an existing EPUB the last build of this book did not make?
IDEA, PARKED (owner: "didn't think it was practical anyway"): an English
sentence -> its German sentence and audio, from two synced EPUBs by
sentence alignment (lengths, names, numbers; Whisper's X -> English
translation as a bridge); phrase level needs a translation model.
Zip 31 - READER (owner, 2026-11-15 21:02): menu bar (TMainMenu, made in
code: File > Open... / Recently Opened / Exit; View > Dark mode / Learn
to read (checked) / Larger / Smaller text); the toolbar's Open button
gone. Settings in JSON (owner: "they will get more complex"):
EpubReader.json in %APPDATA%\EpubReader / ~/Library/Application
Support/EpubReader / $XDG_CONFIG_HOME or ~/.config/EpubReader -
"dark", "textSize", "speed", "recent": [{file, title, word}] (RECENT_MAX
10, latest first). Position = ReadingWord (Learn unit, else the clip
highlighted, else the document's first word), kept on close and when
another book is opened (RememberBook), restored in EpubUnum1Open
(RestoreWord: GoClip - lit, Play starts there). Matched BY FILE NAME
(owner: "tied to the epub name for now"). No book on the command line:
the last one read opens. A missing recent file: a message, taken off.
SMOOTH FOLLOWING (owner: "display is rather jerky ... the row the reader
is on is central"): TEpubView.ScrollToWord(AWord, ACenter) - with
ACenter the word's LINE (WordLine: Skia's rect of the word) goes to the
middle, by SmoothScrollTo (15 ms timer, 20 % of the way per tick; a jump
farther than 1.5 screens is instant; any other scroll stops it); every
ScrollToWord of the reader centres. NOT COMPILED here (no Delphi).
Settings menu: later (owner: "We will also eventually need").
Zip 32 - FOOTNOTES (owner: "I couldn't spot any. They should probably be
highlighted ... File -> Goto Footnote -> [list] ... disable" when none):
TEpubView.NoteColor (index 4; default $FFEDE6D6, a shade darker than the
paper; claNull = off) drawn behind blocks whose Role = ewrNote (the
walker's: aside, epub:type / role / class footnote, endnote, note,
rearnote); reader DARK_NOTE $FF2C2C34. File > Go to Footnote: runs of
note words per document (at most 300), item "N. <chapter>: <first 8
words> ...", click = RestoreWord (lit; Play from there - a footnote
read at its call point plays there). OPEN: if Night Watch's EPUB does
not mark its footnotes as notes (plain paragraphs, or only a noteref
link), the menu stays disabled - then the markup decides what to
detect (the owner can describe one footnote's tags; the book stays
local).
Zip 33 (owner: "Reader doesn't have a menu"): a TMainMenu made in code
reaches the window's (Windows' / macOS') own menu bar only after
RecreateOSMenu - now called at the end of BuildMenu, BuildRecentMenu,
BuildNotesMenu and after a tick changes. If it still does not show:
a TMenuBar (FMX-drawn, Align Top) is the fallback.
Zip 34 - FIND (owner: "We could just add a Search function :)" ... "we
want one anyway"): Edit > Find (Ctrl+F) / Find next (F3) / Find previous
(Shift+F3); a find bar under the tool bar (layFind: edFind, < >, "3 of
17", X; Enter / Shift+Enter / Esc). FindAll: the query split at spaces,
each word compared with the book's words without case and surrounding
punctuation (FindKey = EpubWordCore + LowerCase); whole words, the LAST
one may be a word's start ("Vim" finds "Vimes"); contents page (role
nav) skipped. FindStep: from the match shown, else from ReadingWord;
round the book. A match: shown lit (all its words), centred, its chapter
in the contents, FClip / FSeekClip so Play starts there. While the find
box has the focus FormKeyDown leaves typed keys alone (P, D, L, R, [ ]
would otherwise act). A new book clears the matches. Night Watch's
footnotes: still need their markup to be found as notes.
Zip 35 (owner's debugger: an exception at start-up in RegisterOpenWith,
TRegistry.WriteString - caught, so silent outside the debugger, but the
registration never happened): TRegistry.OpenKeyReadOnly sets the
object's Access to KEY_READ for good, so every OpenKey / WriteString
after the "already registered?" check failed. Access is put back to
KEY_READ or KEY_WRITE before writing.
Zip 36 - FOOTNOTES FROM LINKS (owner, Night Watch, a Calibre conversion:
every call is <a href="Night_Watch_split_013.html#filepos902870"><span
class="calibre11">*</span></a>; "I definitely don't trust that [class]
to always be true"). Detection by the LINK, not by class names:
TEpubBook.LoadText now walks each document WITH blocks; a run that is a
link with a fragment and whose text is a footnote marker (IsNoteMarker:
asterisks, daggers, section / pilcrow signs; or a raised number / letter
of up to 3 characters - ersSuper) records 'path#id' + the word it
follows; MarkLinkedNotes then gives role note to the target's block
(the paragraph holding the id; TEpubIdRange.BlockFirst / BlockLast, new)
plus what the element holds - only when the target comes AFTER the
marker (a link back from the note to its marker points up, so the main
text is never marked); body / caption / table words only. TEpubView
shades a block whose first word has role note (the book's roles) as
well as walker notes; the reader's Go to Footnote lists them. TESTED
(synthetic Calibre-style EPUB): "*" to another file, raised "2" to the
same file, back links (no effect), an unraised "1" index link (no
effect) - all as meant; Moby-Dick: word list and roles unchanged
(its footnote has no link); words load 0.55 s (blocks now built).
OWNER'S CHECK (Night Watch): Go to Footnote lists them ("* The Igor
employed by the Watch as ...", "* Who was an orangutan ..."): detection
works. Their labels said "About the Publisher:" - the book's contents
list has only front / back matter, and the notes live after it.
Zip 37 (owner: "this was more for debugging anyway. Stick a debug entry
in settings - normally false ... only way to turn it on is to manually
edit settings"): "debug" in EpubReader.json (written every save, false
by default); File > Go to Footnote is created hidden and shown only when
it is true.
LATER (owner): go to the suspicious parts from the results - needs the
reader inside the builder (or the builder inside the reader).
To come: remember settings (model, device, folders), a summary of the
not-spoken stretches, open the result in EpubReader, integrate in the
reader later (owner).

## Session 7 (2026-11-16) - zip 39, on top of 4d7dfbe (= zip 38)
Owner's answers to the session 6 handover:
- Pause fix (TWhisper-28 word edges): "works well". Maybe later: a small
  repeat before a pause (to decide what exactly).
- German Night Watch: built, being checked; Leviathan Wakes as a second
  book.
- Night Watch's contents list has no chapters (the book has none) and
  the reader shows no useful chapter steps: BuildChapters uses the Toc
  whenever it has an entry with a document, so the fallback to the
  documents never runs (the Toc holds front / back matter only). OPEN:
  what a chapter step should be in such a book (see the session notes).
- Create asks before replacing (offer (a), agreed): zip 39.
- Find on '*': debugging only, nothing to do (offer (c) dropped).
- Offer (b) explained again (front / back matter in the results' "worth
  a look" list): awaiting an answer.
Zip 39: EpubBuilder, btnCreateClick - when the output EPUB exists, a
TDialogService.MessageDialog (Yes / No, No default) asks before
replacing it, unless this run of the builder made that file from the
same book (FMadeBook / FMadeOut, set from FRunBook / FRunOut when a build
reaches 100 %), so building again from the saved transcript does not
ask. The build start moved to StartBuild (it does nothing if a build is
already running). NOT COMPILED here (no Delphi).

## Zip 40 (on top of 39): audiobook chapters, library, front / back matter
Owner, 2026-11-16: "Use the audiobook's 75 chapter marks"; "ignore Front
and Back but make sure you can get to them by scrolling etc."; covers:
"turn the Recently Read menu into a pre-book-load display of the covers
... cache the images in a directory under settings.json ... current book
taking up several grid tiles ... Center horizontally+vertically using
max grid area. In the event of no cover just create one as a text image -
the user can be allowed to change them later"; then "Add a File ->
Library menu item that takes you to the Library selection screen (temp
fix)".
- AUDIO CHAPTER MARKS. lib: TEpubWriter.AddAudioChapter(Title, Audio,
  Start) / ClearAudioChapters -> TSaveJob.WriteChapters writes
  <package folder>/epubunum-audio-chapters.xml (manifest id
  EPUB_AUDIO_CHAPTERS_ID = 'eu-audio-chapters', media-type
  application/xml, not in the spine; root audio-chapters in namespace
  EPUB_AUDIO_CHAPTERS_NS, a chapter element per mark: audio = href
  relative to the file, begin = clock value, title). A book written
  before keeps its file and item (replaced in place); no marks given:
  the book's file is copied as it is; the id used by something else:
  marks left out with a warning. TEpubBook.AudioChapters (read at open;
  a damaged file gives none) and AudioChapterWords (first word of the
  first clip of that audio at the mark - 0.25 s early allowed - one
  pass). Marks are audio places, not text: they survive re-alignment.
  NOT RUN: epubcheck on a book with the new item (application/xml,
  unreferenced - expected at most a usage note; TO CHECK).
- EpubBuilder: the parts (Audio.Parts or the saved transcript's) as
  marks when there are 2 or more (an M4B's chapters with "Chapters of a
  file are parts", else one per file); logged.
- EpubReader BuildChapters: the contents' chapters as before; when fewer
  than 2 of them have audio and the book has 2 or more marks with words,
  FTocIsChapters: chapters = marks + contents entries without audio +
  linear documents with words, no audio and no chapter start (title: the
  first 6 words), sorted, one per word; lbToc then lists these
  (FChapterTitle; item = chapter), lbTocChange / SyncToc follow. GoChapter
  for a mark: ShowDocument only when another document, then ScrollToWord.
  Go to Footnote's labels use FChapterTitle.
- FRONT / BACK MATTER (builder results): not-spoken stretches before the
  first or after the last exact / similar word (moved words - footnotes
  after the back matter - do not count) are counted as edges and left
  out of "worth a look". Was: only stretches touching word 0 or the last
  word (missed Night Watch's back matter).
- LIBRARY (reader): recLibrary (TRectangle, child of View1, Align Client,
  page colours, eats the mouse wheel) with a TImage per FRecent entry;
  shown at start-up when no book is on the command line (the last book is
  no longer opened by itself), by File > Library (toggles), hidden when a
  book opens or by Esc / the open book's own cover. Grid: the column
  count giving the largest tiles (aspect 1.5, gap 16), the first entry
  (current / last read) over 2 x 2 tiles at the top left, the others
  beside it then in full rows, centred. A click opens through tmLibrary
  (1 ms; the click must not free its own image). Covers: CoverFile =
  covers\<MD5 of the lower-case file name>.png beside EpubReader.json
  (by file name, as RecentIndex); EnsureCover makes a missing one at
  open (and for list entries, opening the book without text): the
  cover image scaled to <= 600 px high, else (none / SVG / unreadable)
  SaveTextCover (title + authors on an HSL colour from the title's hash,
  400 x 600). Replace / delete files there to change / remake. File >
  Recently Opened is still there (owner may want it gone).
NOT COMPILED here (no Delphi; this session also had no FPC - lib changes
are unbuilt): the owner's build is the first. TO TEST: German / English
Night Watch rebuilt (saved transcript) -> 75 chapters in the contents
list and the chapter buttons, title / about-the-author pages reachable;
Moby-Dick and Aladdin unchanged (contents chapters); the library at
start-up, resize, dark mode, click / Esc; a book without a cover.

## Zip 41 (on top of 40): progress under the text
Owner, 2026-11-16: "a progress indicator at the bottom of a book's
displayed text ... just a percentage for now but if we get pagination
later then page X of Y would be nicer ... depends on the text render
size". TEpubView.ShowProgress (published, default False; the reader sets
True): a strip FooterHeight high (2 x max(11, FontSize x 0.65) px) at the
bottom with a hairline and the percentage centred (text colour, fainter);
the text is clipped above it, and every scroll calculation uses
TextHeight (Height less the strip): SetScrollPos / SmoothScrollTo
clamps, ScrollToWord, Page, Draw's clamp; WordAt ignores the strip.
TEpubView.Progress (public, 0..1, -1 when nothing shown): words of the
documents before + this document's words x (scroll / content height),
1 at a document's end, 0 at the very start - BY WORDS, so the text size
does not move it (page X of Y would). Truncated, so 100% only at the end
of the last document. NOT COMPILED here (no Delphi / Skia). TO TEST:
scroll, text size, a chapter jump, the last page of the book, dark mode.

## Zip 42 (on top of d8ce181 = zips 39-41 + the .sh files made executable)
- FIX (owner's dcc64, zip 40): E2003 'Create' / 'Canvas' ... in
  SaveTextCover / SaveImageCover - TBitmap was Winapi.Windows' record
  (the implementation uses clause names Winapi.Windows after FMX.Graphics,
  so it wins). Now FMX.Graphics.TBitmap. RULE: in uMain, any name that
  Winapi.Windows also has (TBitmap, DeleteFile, ...) must be qualified.
- LINUX MENU (Linux port, session 7): FMX's TMainMenu becomes GTK's native
  bar on Linux, which shows only first letters (TSteamAPI
  docs/fmx-menu-bug-fix.md). The reader's menu is made in code, so on
  Linux (not Android) BuildMenu makes it on an FMX TMenuBar (mnuBar, Align
  Top, above layTop) and mnuMain stays nil; RefreshMenu replaces every
  mnuMain.RecreateOSMenu (does nothing without mnuMain). Item text: the
  tab before a key becomes spaces on Linux (FMX would draw the tab).
  READMEs: the "no main menu" notes replaced; Linux FFmpeg names.
- Push d8ce181 checked: = zips 39-41 file by file (CR LF aside), the
  session 6 handover file removed, EpubReader.sh 100755 (ffmpeg-dev
  789b8e9: build.sh 100755).

## Zip 43 (on top of 42): the library stops the book, hides the sidebar
Owner: "If I'm reading a book and select File -> Library the book keeps
playing - not good. Also the Library shows the sidebar which is
meaningless in that view". ShowLibrary: StopPlaying (paused - Play
resumes once back), lbToc and Splitter1 hidden; HideLibrary shows them
again (Splitter1 placed right of lbToc). While the library shows: Play,
chapter and step buttons disabled, btnPlayClick does nothing, the
reader's keys wait (Esc and Ctrl+O still work), Edit > Find goes back to
the open book's page first (nothing without a book).

## Linux port (session 7) - zip 44 (on top of 43)
Libraries, consoles and the pipeline were built and run on Linux here
(detail: TWhisper CLAUDE.md, "Linux port (session 7)"): whisper-dev and
ffmpeg-dev build on Linux (whisper-dev fixed: RUNPATH $ORIGIN, libgomp
bundled - its zip whisper-dev-01), EpubUnum lib/ + EpubConsole built with
FPC 3.0 (zips 40-41's lib changes included), audio chapter marks written
and read back on Moby-Dick (epubcheck 0 / 0), WhisperConsole --from-json
-> --timings -> EpubConsole --overlay on Linux (epubcheck 0 / 0),
FFmpegConsole --play: libpulse-simple.so.0 loads; no server here, so the
silent output with its clock (speed 1.3 too). Delphi side (not compiled
here): the reader's Linux menu (zip 42), and EpubBuilder's "not
available" hint names the Linux libraries and LD_LIBRARY_PATH (zip 44).
.dproj files: Linux64 is already a target of every package (not the
design packages) and program; the reader deploys libsk4d.so for Linux64.
NOT deployed by the .dproj (copy by hand / PAServer deployment): FFmpeg's
.so files, whisper-dev's dlls, EpubReader.sh.
OWNER'S LINUX STEPS (first Linux box, then the Steam Machine / Deck):
1. ffmpeg-dev: ./build.sh -> dlls/linux-x64. whisper-dev: install Vulkan
   (Ubuntu: libvulkan-dev glslc spirv-headers; HIP: ROCm + ROCM_PATH),
   ./build.sh -> dlls/ (check: readelf -d dlls/libwhisper.so | grep
   RUNPATH shows $ORIGIN).
2. Delphi: Linux64 SDK through PAServer; build the packages for Linux64
   (EpubUnum, EpubUnumFMX; WhisperAPI; FFmpegAPI), then WhisperConsole
   --check and --bench with both library folders next to it.
3. EpubReader Linux64: the .so files of both folders + EpubReader.sh
   (executable) next to it; run it from a terminal (stderr markers):
   menu bar with full names, library covers, sound through PipeWire /
   PulseAudio, Open with (~/.local/share/applications/epubreader.desktop).
4. EpubBuilder Linux64: same folders; Aladdin end to end (Vulkan0).
5. SteamOS: EpubReader.sh as the launch command in Steam Linux Runtime
   3.0 (sniper); Game mode full screen; the drawn menu bar.

## Zip 45 (on top of 44): built books are marked; the builder asks
Owner: "add some tag to the processed epubs marking them as already
processed by builder allowing the user to not proceed. I accidentally
tried re-encoding an already built epub". lib: EPUB_WRITER_META =
'epubunum:writer'; TEpubWriter.WrittenBy (default 'EpubUnum') written as
<meta name="epubunum:writer" content="..."/> in the package metadata
(EPUB 2-style name / content meta: epubcheck 5.2.1 0 / 0; any earlier one
removed, so one per book); TEpubBook.WrittenBy reads it, and is
'EpubUnum' for a book with the audio chapters item but no meta (zips
40 - 44). EpubBuilder writes 'EpubBuilder', EpubConsole --overlay
'EpubConsole'. EpubBuilder: ShowBook keeps FBookWrittenBy / FBookClips and
says "ALREADY A READ-ALONG BOOK (made by ...)"; Create: a book made here
(or with clips of its own) -> a warning dialog, No by default, before the
output check (CheckOutputThenBuild, split out of btnCreateClick). TESTED
(FPC, Linux): IDPF Moby-Dick '' (40 clips), EpubConsole's result
'EpubConsole', a zip-40 book 'EpubUnum', written twice -> one meta.
Seen in that test, not new: a book written by --overlay and written
again gets 15 new ids (3643 reused) - zip 09 said 0; the 15 are probably
words whose span was moved inside punctuation in zip 15. Harmless.

## Zip 46 (on top of 45): saved transcripts - opt-in, model checked
Owner: a proper build "with a saved transcript ... needed to transcribe
again. Maybe remove the option ... trusting the old results seems
potentially dangerous"; agreed instead (owner: "Missed the different
model point - very valid"): (1) chkReuse off at every start and no longer
in EpubBuilder.ini (the key is deleted on save; chkReuse.OnChange ->
UpdateControls); (2) the log says in capitals which transcript was used,
when it was made, with which model; a missing one is logged too ("No
saved transcript for this output (...)" - the cause of the owner's
re-transcription is likely another output name); (3) SaveTranscript
writes "builder_model" (the model's file name) and "builder_made"
('yyyy-mm-dd hh:nn') after the opening brace (TrimSaved's re-save keeps
the saved values); ReadSaved refuses a transcript whose model differs
from the one chosen (file names compared); one without the key (made
before zip 46) is used, with a note. Create without a model needs the box
ticked AND the transcript there. NOT COMPILED here (no Delphi).

## Zip 47 (on top of 46): closing during a build asks
Owner: "an OnClose trap to make sure you don't accidentally close the app
half-way thru a build". FormCloseQuery (assigned in FormCreate - the .fmx
is unchanged): with FBuild running, TDialogServiceSync.MessageDialog
(FMX.DialogService.Sync; desktop platforms) shows the progress and the
step, says the work is lost (the transcript is saved only when every
part is done), Yes / No with No the default; No logs "Still building.".
Yes -> FormClose as before (cancel, wait, free). NOT COMPILED here.

## Zip 48 (on top of 47): EpubBuilder job queue
Owner: "a jobs list ... queue many books for transcription and leave it
running overnight ... add to the queue while it was running ... Load/Save
a Queue ... an Add To Queue button ... a 3rd column ... on the left ...
the Job Queue with a Run Queue at the bottom of it". uBuilder only:
- TBuildJob (book, title, audio, model, device by name, output,
  chapters, reuse, State jsWaiting / jsRunning / jsDone / jsFailed /
  jsCancelled, Note) in FJobs; layQueue (Align Left, Position.X 0, 300 px,
  window at least 1300 wide) + splQueue: caption, Load... / Save... /
  Remove / Up / Down, lbJobs, btnRunQueue (Align Bottom). btnAddJob
  ("Add to queue") beside Create.
- Create and Add to queue share CheckThen(AQueue) -> CheckOutputThen
  (ADevice, AQueue): the built-book and existing-output questions are
  asked when adding, never while the queue runs; an output a waiting /
  running job writes already is refused. JobFromWindow takes the window's
  choices. StartBuild = SaveSettings + log cleared + StartJob(job, -1);
  StartJob(AJob, AIndex) starts any build (FJob = the queue index, -1 =
  Create's).
- Run queue: failed / cancelled -> waiting, FQueueRunning, RunNextJob
  (first waiting job; none -> "Queue finished: N done, M failed or
  cancelled"). BuildDone sets the job's state and note (time taken, or
  the thread's last "FAILED: " line), saves the build's lines (FBuildLog,
  LogLine writes to it while FLogging) to <output>.log - Create's builds
  too - and starts the next job through tmQueue (50 ms: the ending
  thread is still being finished); Cancel (FCancelled) stops the run.
- The window stays enabled while building (UpdateControls no longer
  disables the sides / settings): Create only when nothing runs, Add to
  queue whenever the choices are complete, Run queue when not busy and a
  job is not done ("Queue running ..." while it runs).
- Remove / Up / Down keep FJob on the job running (it cannot be removed).
  Double click: the job's choices back into the window (ShowBook, audio,
  output, model, device, options).
- Queue file (JSON, System.JSON): {"epubBuilderQueue": 1, "jobs": [{book,
  title, audio[], model, device, output, chapters, useSavedTranscript,
  state ("waiting" for the running one), note}]}. Load ADDS the file's
  jobs (done ones stay done); entries without book / output / audio are
  skipped.
- Closing while the queue runs: the question also says how many jobs
  wait (Save... keeps them).
NOT COMPILED here (no Delphi / FMX). TO TEST: two short books queued,
Run queue, a third added while it runs; Cancel in the middle and Run
queue again; Save, close, Load, Run; a failing job (a missing audio
file) - the queue goes on, its note says why.

## Zip 49 (on top of 48): hints of the owner's first build of 42 - 48
Owner's Win64 build of EpubBuilder and EpubReader with zips 42 - 48: NO
ERRORS (the queue, library, Linux menu, built-book marker, close guard
all compiled first time). Hints fixed: H2443 TJSONArray.GetValue not
inlined - System.Generics.Collections added to both units' uses; H2219
mnuBar never used on Windows - declared only under LINUX (not ANDROID),
where it is used.

## Zip 50 (on top of ab2c7d6): redistributables collected in Epubunum
Owner: "The only applications that need running ATM are in epubunum -
that's the only one that NEEDS a deploy so placing all redistributables
there makes sense" (macOS / Linux deploys in view). redistributable_bin/
(README tracked; the platform folders and libraries are ignored by the
existing .gitignore) + tools/redist.sh (POSIX sh, LF - NEW SCRIPT: the
owner sets the executable bit: git update-index --chmod=+x
tools/redist.sh) and tools/redist.bat (CRLF):
- collect WHISPER_DEV FFMPEG_DEV: this machine's platform (Linux64;
  OSXARM64 / OSX64 by uname -m; Windows: Win64) from whisper-dev's dlls
  (or a folder holding the libraries - TWhisper's redistributable_bin\Win64)
  and ffmpeg-dev's dlls/<target>, plus licences/ (FFmpeg's LGPL texts,
  LICENSE.md, BUILD-INFO.txt; whisper.cpp's LICENSE). Windows: robocopy /e
  without debug\, so HIP's rocblas\library comes along.
- deploy PLATFORM TARGET: Linux - next to the program, EpubReader.sh too
  when EpubReader is there (chmod +x); macOS - TARGET.app's
  Contents/Frameworks, each dylib codesigned (CODESIGN_ID or ad hoc),
  licences in Contents/Resources/licences; Windows (redist.bat deploy
  TARGET) - next to the .exe.
TESTED here (Linux): collect from whisper-dev d8a2183 + ffmpeg-dev
7566f9c builds -> 42 files + licences; deploy into a folder with the
FPC-built WhisperConsole / FFmpegConsole: both load every library from
there (layout check passed), EpubReader.sh copied, executable. macOS
and Windows paths NOT run here.
Push ab2c7d6 checked: = zips 42 - 49 (CR LF aside); EpubReader.dproj
re-saved by the IDE (Cfg_2 blocks for OSX64 / OSXARM64 / Win64 -
harmless, keep). TWhisper d669a06 = TWhisper-30, whisper-dev d8a2183 =
whisper-dev-01, ffmpeg-dev 7566f9c = ffmpeg-dev-07, TFFMpegAPI 3edcfa3
unchanged this session.

## Zip 51 (on top of 6207694 = zip 50): Linux libraries from the container
redistributable_bin/README.md: Linux libraries are built in whisper-dev's
container-build (Ubuntu 22.04, glibc 2.35 - whisper-dev-04/05; Docker or
Podman, documented in whisper-dev's container-build/README.md), so the
deployed set runs on every Linux with glibc 2.35+; a host build on
Ubuntu 26.04 needed glibc 2.43.
Push 6207694 checked: = zip 50 file by file; tools/redist.sh pushed as
100644 - needs git update-index --chmod=+x tools/redist.sh (until then:
sh tools/redist.sh ...).

## Zip 52 (on top of 7a6a902): the queue's report
Owner: "at the end it should output a report summarizing the job run.
For each transcription all the numbers basically inc time taken size of
final epub, quality score etc"; "JobQueues will have a filename so just
call the report same name .md". TBuildSummary (audio length, files,
parts, saved transcript, transcription time, model, device, language,
heard words, TWhisperAlignStats, front / back matter words, matched %,
short verdict, clips, left out, chapter marks, upgraded, error), filled
by TBuildThread (Execute, LogResults) and read in BuildDone through
TBuildThread.Summary into the job (+ Started, Seconds, OutputBytes from
TFile.GetSize). RunNextJob's end -> WriteQueueReport: <queue file>.md
(table: time, audio, speed, matched, verdict, EPUB MB; totals; a section
per job with every figure) and <queue file>.csv (34 columns, '.'
decimals, quoted texts); FQueueFile = the last loaded / saved queue file
(none: EpubBuilder-report-<yyyy-mm-dd-hhnn> beside the first job's
output). The queue file is saved after each job while the queue runs.
Jobs loaded from a file and not run in this session: "Not run in this
session". NOT COMPILED here (no Delphi).

## Zip 54 (on top of 53): audiobook chapters chosen by a stricter test
Owner, Night Watch rebuilt from its transcript (75 parts: Opening
Credits, Chapter 1 - 73, Closing Credits - checked in the transcript JSON
he sent; structure only): still no chapters in the reader. Cause (by
reading): BuildChapters counted a contents entry as "read" when any clip
fell between it and the next entry - Night Watch's front-matter entries
reach across the whole narrated text to "About the Author", so two of
them counted and the marks were not used. Now ReadAtStart: the entry's
first clip within READ_START_WORDS (50) of its first word (a read
heading). Merged mode keeps the entries not read at their start (title,
copyright, about the author). Moby-Dick: its chapters start with their
read headings - unchanged. NOT COMPILED here. TO TEST: Night Watch (the
rebuilt EPUB - its build log must say "Chapter marks: 75"; inside the
EPUB: OPS/.../epubunum-audio-chapters.xml): the contents list shows the
75 marks among the front / back matter entries; Moby-Dick unchanged.

## Zip 55 (on top of 54): the chapter choice, second fix
Owner's screenshot (zip 54): Night Watch's contents list is Map, Begin
Reading, About the Author, Praise, Other Books, Copyright, About the
Publisher - still the contents list. "Begin Reading" is read at its start
(1), and the Map page (a few words) was followed by the narration on the
NEXT page within 50 words (2) -> ReadCount 2. Now: ReadAtStart also
needs the first clip on the entry's own document; and the marks are used
when K >= 2 and K > ReadCount (more audiobook chapters than read contents
chapters - Night Watch 75 > 1; Moby-Dick's contents list is its read
chapters, so it keeps it). FChapterSource shown in the status line when
"debug": true ("chapters: audiobook marks (75), contents read 1" or
"contents (N read), M audiobook mark(s)") - tells at once whether the
marks are in the book. NOT COMPILED here.

## Zip 56 (on top of 55): audiobook chapters - Chapter 1, paragraphs, rules
Owner's screenshot (zip 55 works: "chapters: audiobook marks (75),
contents read 3"): (1) the list went Opening Credits, Chapter 2 - the
credits have no text, so their mark fell on Chapter 1's first word and
the first entry was kept; (2) "A Chapter starts in the middle of text?"
- the publisher split the recording at a pause inside a paragraph;
(3) "It would be nice to have a HR ... between chapters". Now:
- BuildChapters: a mark's word moves to the first word of its paragraph
  (WordBlock / FUnitLayout; the audio plays from that word's clip, the
  same recording); marks are added with FChapterToc -2 and, of two marks
  on one word, the later one's title is kept (Chapter 1), then made -1;
  their words go to View1.ChapterBreaks (cleared at the start).
- TEpubView.ChapterBreaks (public, TArray<Integer> of book words; setter
  lays out again): LayoutItems leaves 2 lines of room above a block whose
  first word is one (BreakBefore; not at a document's top) and records
  TEpubViewItem.RuleY; Draw draws a centred rule there (30 % of the width
  at most 12 em, the text colour at ~45 % alpha).
NOT COMPILED here. TO TEST: Night Watch - Chapter 1 in the list, each
chapter starting at a paragraph, a rule above it; chapter buttons; Moby-
Dick unchanged (no marks used, no rules).

## Zip 57 (on top of 56): redist.sh collects ROCm's kernel folders
tools/redist.sh collect copied only *.so* from whisper-dev's dlls/, so
the rocblas/library and hipblaslt/library folders whisper-dev-02 bundles
for HIP were left out (HIP fails without them). Now copied (Linux64);
deploy already copies the whole platform folder. redist.bat used robocopy
/e already.

## Zip 58 (on top of 57): EpubReader's Linux hint
uMain's implementation uses Posix.Unistd on POSIX: the cover cache's
System.SysUtils.DeleteFile is inline there and gave H2443 on Linux64.
(The same Linux64 build's E2003 on ChapterBreaks was a stale EpubUnumFMX
Linux64 DCU, from before zip 56: rebuild the packages for Linux64.)

## Zip 59 (on top of 58): debug log files
demos/common/uDebugLog.pas (new; in EpubBuilder's and EpubReader's .dpr
and .dproj): DebugLogOpen / DebugLog / DebugLogFile - one file per run
next to the settings (<program>-debug.log, the previous run's as .old),
time + thread id per line, opened, appended and closed for every line so a
native crash (ggml abort, GPU runtime) loses nothing. Builder: every
thread Log / Status line (straight away - the queued ones die with the
process), whisper.cpp / ggml lines through TWhisperLib.AddLogListener
(any thread), the devices, FFmpeg loading, model load / start of the
transcription; the window's log shows the path. Reader: start up, sound,
library and each cover, open, chapters, play / stop / clips, closing.
Owner's Linux test that led to it: EpubBuilder (small.en, CUDA on a 4 GB
card) aborted in ggml-cuda - "the provided PTX was compiled with an
unsupported toolchain": the container build had only PTX for sm_75
(ggml's default 75-virtual) and the driver is older than CUDA 13.5;
whisper-dev-17 builds the release with CUDA_ALL (SASS for 75/86/89/120).
EpubReader "not responding" on Linux: not found yet - the log is for it.

## Zip 60 (on top of 59): time left from the transcription's rate; Play logged
EpubBuilder's "about ... left" came from the time since the build started
(book, audio, model loading included) and showed 14 - 20 h on the owner's
GTX 1650 for a 20 min base run. Now measured from the first progress past
5 % (FRateFrom / FRatePercent), shown after a minute and 1 % of progress;
"estimating the time left ..." until then. EpubReader: Play's steps in
the debug log (extracting the clip's audio from the book, with its size;
opening it in the player; play) - the owner's Linux "not responding" came
on pressing Play, after the book had loaded.

## Zip 62 (on top of 61): Linux libraries in Delphi's deployment
tools/deploy_redist.py (new): writes a DeployFile entry (Class File,
Platform Linux64, RemoteDir .\ or the subfolder) for every file of
redistributable_bin/Linux64 into EpubBuilder.dproj (all) and
EpubReader.dproj (libav* / libsw* and licences/FFmpeg-*); EpubConsole
needs none. Replaces only the entries whose LocalName starts with
..\..\redistributable_bin\Linux64\ (a second run changes nothing); adds an
empty <Deployment> when the project has none (EpubBuilder had none).
Names: libX.so and libX.so.N; libX.so.N.M.P left out when a shorter name
is there (works on a copied folder where links became files). Owner:
"I want a proper deploy" - a Clean through PAServer empties scratch-dir.
The generated entries are not in the delivered .dproj files: they depend
on the owner's folder; he runs the script on Windows. Tested on a copy
(twice: 42 / 16 entries, then the same 42 / 16 replaced; XML parses;
project_check 0).

## Zip 63 (on top of 62): release packages of the libraries
tools/redist.sh package PLATFORM [VERSION] and tools\redist.bat package
[VERSION] (-> tools/redist-package.ps1, new): core / cuda / rocm parts in
redistributable_bin/packages/ (now in .gitignore), each with its licences
and EpubUnum-libs-<part>.txt, plus SHA256SUMS-<platform>-<version>.txt.
Linux: GPU parts by ldd of libggml-cuda.so / libggml-hip.so with
LD_LIBRARY_PATH = the folder, minus the shared core (ggml-base, ggml,
whisper, gomp); rocblas/ hipblaslt/ with rocm; licences/CUDA-* and ROCm-*
with their part. Windows: by file name patterns. collect now also copies
whisper-dev's dlls/licences/ (Linux; whisper-dev-18 collects the bundled
libraries' Debian copyright files and the CUDA EULA) and, on Windows,
%CUDA_PATH%\EULA.txt and %HIP_PATH%'s LICENSE / NOTICE files.
Tested: redist.sh package on a fake folder built with gcc (real NEEDED
chains): parts and links right. The PowerShell script is untested here
(no PowerShell).

## Zip 64 (on top of 63): deploy_redist.py --skip, sizes
The owner's first Deploy with the generated entries (EpubBuilder: 1811
files, 2287 MB) failed at once in paclient's Clean: "E0009 Range check
error". Suspects: the total over 2 GiB (a 32-bit size) or the kernel
files' long names. --skip REGEX (repeatable) leaves files out, and the
summary gives the longest name, to find which.

## Zip 68 (on top of 67): the cover step logged; EPUBREADER_NO_COVERS
Owner's Linux debug log before "Force Quit": open, read, chapters
built, then "cover: <book>" and nothing more - the hang is in EnsureCover
(the first cover ever made on that machine: the library had no recent
books), not in Play (the earlier report: Play pressed while it hung).
Every step of SaveImageCover / SaveTextCover is logged now (decoding with
the byte count, the picture's size, scaling, saving, saved; a failed
picture's message). EPUBREADER_NO_COVERS=1 skips making covers (the
library shows titles) so the reader can be tested meanwhile. Later-tests
item 5 updated by this.

## Zip 69 (on top of 68): the play timer logged
Owner's next Linux run: Play heard (clip 0 extracted - 840 MB m4b in
2.7 s - opened, playing from 116 s) but the page never moved, then "Force
Quit": the main thread stuck in tmPlayTimer's first highlight. Player
calls there are cheap (Position / Clock: a lock, no I/O), so the suspect
is View1.ShowDocument laying out a big document on Linux. Logged now: the
first clip of a play and every change of document ("clip N at T s
(document D)", "document D: laying out" / "shown"), and on open the
book's documents / words / clips and its biggest document's word count.
Ask the owner to press Wait, not Force Quit: a slow layout ends, a hang
does not.

## Zip 70 (on top of 69): the hang is laying out a big document
Owner, EPUBREADER_NO_COVERS=1: the same stop right after the cover step,
and covers DO work (one was in the library after a restart) - so the
cover was never it. What follows the cover step on open is RestoreWord
(the place left) -> GoClip / ShowDocument + ScrollToWord: the layout of
the document there. Night Watch: 24 documents, the biggest (6) 31851
words. Every earlier hang fits: open (restore) and Play (the timer
moving into document 6). TEpubView lays out on ScrollToWord / paint
(LayoutItems: MakeParagraph per block - a new TSkParagraphBuilder each,
no shared font collection), so the suspect is Skia's font lookup through
fontconfig on Linux, repeated per paragraph. Logged now: GoClip /
RestoreWord / the play timer "laying out" -> "shown (N blocks)" around
the layout. EPUBREADER_FONT=<family> sets View1.FontFamily (test: a font
the machine has, e.g. "DejaVu Sans", against the default). If confirmed:
one shared font collection / typeface cache in TEpubView (package
change), and laying out only the blocks near the view.

## Zip 71 (on top of 70): fonts looked up once per view (the Linux hang)
Owner's gdb stack of the hung reader (twice, same place): tmPlayTimer ->
TEpubView.ScrollToWord -> LayoutItems -> MakeParagraph ->
ParagraphImpl::layout -> OneLineShaper -> FontCollection::matchTypeface
-> SkFontMgr_fontconfig::onMatchFamily -> AnyStringMatching (an
SkTIntroSort of every installed font's names, FcStrCmpIgnoreCase). Each
paragraph had its own TSkParagraphBuilder (so its own FontCollection:
no typeface cache between paragraphs), and each asked fontconfig for its
family again - minutes for one chapter on a machine with many fonts;
Windows' DirectWrite answers at once. EPUBREADER_FONT made no difference
(the lookup is per paragraph whatever the name).
Fix (Epub.FMX.View.pas, PACKAGE EpubUnumFMX): Fonts - a
TSkTypefaceFontProvider made once (again when FontFamily / MonoFamily
change) with the text family's regular / bold / italic / bold italic
(TSkTypeface.MakeFromName; '' = "sans-serif" as before) registered as
'EpubView Text' and MonoFamily's as 'EpubView Mono'; every
TSkParagraphBuilder.Create(PS, Fonts, True) (the provider is the
collection's asset manager, asked before the system's; fallback stays on
for characters the font lacks); every text style names those families;
NewParagraphStyle gives the paragraph style's default text style the same
family. NOT COMPILED here (no Delphi / Skia): the Skia4Delphi names used
- TSkTypefaceFontProvider, RegisterTypeface(Typeface, FamilyName),
TSkTypeface.MakeFromName(Name, Style), ISkParagraphStyle.TextStyle, the
three-argument TSkParagraphBuilder.Create - are from memory of its API.
Later: lay out only the blocks near the view (Night Watch's document 6:
31851 words).

## Zip 73 (on top of e00fb17 = zip 72): review fixes
A code review by reading of e00fb17 along the handover's focus list
(owner, 2026-11-16: "Pr (code review)", then "y" to a zip with the first
five). NOT COMPILED (no Delphi, no FPC in that session); pasdoc_check and
project_check 0 problems.
1. uBuilder, Transcribe: a part whose transcription fails (ResultCode
   <> 0, not cancelled) now RAISES. It logged and left the loop, and
   Execute went on: the cut transcript was saved "for next time", the
   book written with part of its audio timed, the job reported done.
2. lib/Epub.Writer (PACKAGE EpubUnum), SaveToFile: written to AFileName +
   '.tmp', then the old file deleted and the new one renamed. The except
   deleted AFileName on ANY failure - also one before a byte was written
   ("No timed words to write") - so a failed rebuild cost the book made
   before. A file that cannot be replaced (open in the reader on Windows)
   raises and the old one stays.
3. uBuilder, LoadQueue: the checks Add to queue makes - a job whose
   output is its book, and one whose output a job of the queue writes
   already (both still to build, or both done: a file loaded twice), are
   left out with a log line; an output that exists gets a "will be
   replaced" line (nothing can be asked while the queue runs).
4. TBuildThread.Succeeded (set when the book is written); BuildDone uses
   it instead of pbBuild.Value >= 100.
5. uDebugLog: the lock is never freed (no finalization;
   RegisterExpectedMemoryLeak for ReportMemoryLeaksOnShutdown). A worker
   between "Lock = nil" and Acquire at shutdown used a freed lock.
TO TEST: build EpubUnum (Epub.Writer), then the programs; EpubConsole
--overlay over an existing output, and with timings that match nothing
(the old output must still be there, no .tmp left); a queue file loaded
twice; a job with a missing model / a part that fails (job FAILED, no
transcript kept); close EpubBuilder during a build (no error on exit, no
leak report).
FOUND AND NOT FIXED (owner to decide):
- Repo: CLAUDE.md says PRIVATE, an anonymous clone works - public, and
  no LICENSE file.
- TEpubView.Fonts: MakeFromName returning nil for every style registers
  nothing under 'EpubView Text' -> every paragraph asks the system again
  (the hang): fall back to TSkTypeface.MakeDefault. Characters the face
  lacks still go to the system per paragraph (test Greek / CJK / symbols
  on Linux). The em-space indent needs U+2003 in the font: a placeholder
  of the indent's width instead. 'monospace' is no Windows family
  (Consolas / Menlo per platform). MonoFamily, ParagraphSpacing,
  PageMargin setters do not lay out again. Pictures are read and decoded
  again on every layout.
- uBuilder: Cancel reads FRun while the thread may free it; FormClose
  sets OnLog / OnProgress / OnStatus to nil while the thread copies them
  (leave them: WaitFor delivers the queued lines while the form lives);
  the log listener is never removed; StartBuild checks FBuild but not
  FQueueRunning (a dialog answered in the 50 ms between jobs); SaveQueue
  writes in place (temp + rename); the report's verdict column is not
  quoted, an error with a line break splits the Markdown bullet and the
  job's note, no report after Cancel, ChapterMarks counts every part.
- uMain: BuildChapters' K > ReadCount (30 read contents chapters and 31
  audio files -> the marks, the book's titles lost: give a mark the
  contents title when it is within a few words of a read entry);
  ClipFromWord and ClipAt are linear (ClipAt scans every clip on each
  tick in a gap between words); tmPlayTimer's Max(FClip, 0) can start
  clip 0 when a file ends before a clip matched; extracted audio stays
  until the reader closes (stored audio could be played in place with
  FFmpeg's subfile: protocol).
- tools: redist.sh package - libraries a runtime loads with dlopen are
  not in ldd's list and land in core (the dangling-link worry of the
  review was WRONG: whisper-dev bundles the runtimes as plain files
  under their soname and copies its own libraries - zip 74);
  deploy_redist.py deploys libX.so and libX.so.N as two full
  copies after scp (drop equal files by hash - may bring the set under
  2 GiB).
- Leftovers: remove EPUBREADER_NO_COVERS; EPUBREADER_FONT -> a "font"
  setting or remove; deploy entries out of git (a --remove switch, a
  project_check rule); a Windows default platform.

## Zip 74 (on top of 73): whisper-dev reviewed; this file only
whisper-dev 9fa21dc reviewed the same way (owner: "Do the same for
whisper-dev", "y + claude.md"); its fixes are whisper-dev-21, and
whisper-dev has a CLAUDE.md of its own from that zip (rules, what can be
tested without the SDKs, the zip's notes and the findings not fixed) -
whisper-dev's history from 21 on is kept there, 01 - 20 stay here.
What whisper-dev-21 changes for work in THIS repository:
- dlls/ is emptied of the previous build by every build, and holds
  BUILD-INFO.txt (system, glibc, whisper.cpp commit, backends, CUDA
  toolkit, HIP targets). tools/redist.sh collect does not copy that file
  yet (it takes *.so*, the kernel folders, licences/): worth adding, as
  ffmpeg-dev's BUILD-INFO.txt is (offered, not done).
- patchelf is required for a bundling build (the container has it).
- The CUDA / HIP backends should no longer carry the builder's folder
  (to check on the first container build: whisper-dev CLAUDE.md, zip 21
  item 5).
Corrected in the zip 73 notes above: redist.sh package cannot make a
dangling link (the runtimes are plain files under their soname).

## Zip 75 (on top of 74): TWhisper reviewed; this file only
TWhisper d669a06 reviewed the same way (owner: "Same for TWhisper",
"y + claude"); its fixes are TWhisper-31 and the notes are in TWhisper's
CLAUDE.md ("Review fixes (TWhisper-31 ...)", with what was not read and
what was found and not fixed). What it changes for THIS repository
(EpubBuilder links TWhisper - rebuild it after TWhisper's packages):
- Every TWhisperModel now refuses a whisper.cpp library that fails the
  layout check (TWhisperLib.RequireLayout): EpubBuilder never ran that
  check. A mismatched library shows as the build's "FAILED: Layout check
  FAILED ..." line instead of a crash in whisper_full.
- FillGaps keeps short gap segments ("It was", "Sie") that were dropped
  as prompt echoes: expect a few more heard words and fewer "not heard"
  on a book transcribed again (saved transcripts are unchanged - they
  hold what was kept then).
- Still open there and here: TBuildThread.Cancel reads FRun while the
  thread may free it (the same shape as TWhisperBenchmark.Cancel).

## Zip 76 (on top of 75): TFFMpegAPI reviewed; this file only
TFFMpegAPI 3edcfa3 reviewed the same way (owner: "Same for TFFMpegAPI",
"y + claude.md"); its fixes are FFmpegAPI-13 and the notes are in its
CLAUDE.md ("Review fixes (zip 13 ...)"). What it changes for THIS
repository (EpubReader and EpubBuilder link it - rebuild both after its
packages):
- Linux: the end of an audio file should now always be seen (PulseAudio's
  Drained no longer needs a latency of exactly 0) - tmPlayTimer's
  FPlayer.Ended is what moves the reader to the next file. Test with a
  book of two or more audio files.
- A sound device that goes away while playing: FPlayer.LastError is set,
  tmPlayTimer stops playing with FSoundNote; the next Play opens the
  default device afresh (FPlayer.Output is a new object then - uMain
  only reads it at start-up, for the log).
- Still open there: a sound server that hangs at start-up hangs the
  reader (the output's constructor / destructor); every clip jump opens
  the audio file again.

## Zip 77 (on top of 20fc7ce = zip 76): EpubBuilder calibration
Owner, 2026-11-17, after Windows tests: "Default" (whisper.cpp chooses)
picks wrong - the 5090 laptop built Night Watch with large-v3 in 39:20 on
CUDA (whisper.cpp's first GPU) and in 29:16 on Vulkan, same figures to
the word; large-v3 failed outright on the Ideapad's 4 GB GTX 1650. Asked
for: a calibration step, kept in the settings; a start-up question
(Start calibration / Cancel, "Do not show this again"); the improved 30 s
benchmark "where there is noise" on Aladdin (media/aladdin.m4a) over all
devices, the best made the default; the device persisted; Re-calibrate
in a menu; and the machine and backend in the logs ("The output logs
give no idea of the machine or backend being used").
- NEW demos/EpubBuilder/src/uCalibration.pas: TCalibrationThread - ONE
  TWhisperBenchmark, RunOne per model x device (not Run: a marker file
  is written before each pair), CALIBRATION_RUNS = 3 (median), 30 s,
  StartSeconds -1 (WhisperFindSpeech: speech all through, 30 s from both
  ends - TWhisper zip 26), the build's settings (DTW heads per model,
  BOOK_PROMPT, NoContext, language 'en'). Cancel under TMonitor (the
  benchmark is freed in Execute's finally). The storage functions
  (EpubBuilder.ini: [Calibration] Done / DontAsk / Made / Devices /
  Audio, [Calibration <model file>] Made / Best / BestSpeed / one key per
  device = speed or 'failed: ...', [Calibration crashes]
  device@model = date). BuilderFindDevice / BuilderDeviceText resolve ''
  to whisper.cpp's own choice (use_gpu: the GPU / IGPU with GpuIndex =
  gpu_device, else the CPU). OpenBuilderFFmpeg (moved out of
  TBuildThread.OpenFFmpeg, which calls it). AskCalibration: the
  start-up form, made in code (TForm.CreateNew, ShowModal).
- A device whose timed text has under 60 % of the words of the
  best-heard device of that model is NOT chosen (a backend computing
  garbage fast would win otherwise) - logged.
- CRASH MARKER: <settings>-calibrating.txt holds model + TAB + device
  while a pair runs. Found at start-up: that pair is recorded failed and
  in [Calibration crashes]; the start-up calibration skips it,
  Re-calibrate (menu) clears the list and tries it.
- NEW demos/common/uMachine.pas: MachineText = name - TOSVersion;
  CPU (N logical processors); N GB of memory. Windows: COMPUTERNAME,
  registry ProcessorNameString, GlobalMemoryStatusEx. Linux: gethostname,
  /proc/cpuinfo, /proc/meminfo (read until nothing more comes - /proc
  files have size 0). macOS: name only (CPU / memory left out).
  Framework-free (no FMX: Winapi.Windows clashes stay out of uBuilder).
- uBuilder: menu bar (File > Exit; Tools > Re-calibrate (this model),
  Re-calibrate every model in its folder (smallest first), Calibration
  results) - TMainMenu, on Linux an FMX TMenuBar as EpubReader.
  FormShow -> ForceQueue -> CheckCalibrationAtStart: the marker; done and
  the same device list -> a log line; the device list changed -> asked
  again ("The devices have changed ..."); DontAsk -> a log line only.
  Choosing a model applies its calibrated device (ApplyCalibration).
  The calibration runs in the main window like a build (Cancel, the Now
  line, the progress bar; Create / Run queue / the Tools items disabled);
  its lines also go to <settings>-calibration.log. CheckThen split:
  CheckCalibrationThen (the model FAILED on this device in the
  calibration -> asked, No by default) -> CheckBookThen (the old
  read-along question) -> CheckOutputThen.
  cbDevice's first item names whisper.cpp's choice ("Default
  (whisper.cpp chooses: CUDA0 - the first GPU, not always the fastest)").
- LOGS: every build (Create and each queue job) starts with Machine:,
  whisper.cpp version + folder, Device: in full (default resolved) and
  whether the calibration found it fastest for the model ("NOT the
  fastest ... found Vulkan0"). The thread's "Model: ... on" line resolves
  the default too. TBuildSummary.Device is the resolved name; new
  DeviceText and Machine; queue report: "- Machine:" per job, the device
  in full; CSV + device_text, machine at the end (36 columns).
- The settings stay EpubBuilder.ini (the owner said settings.json - the
  builder's file has always been the INI; the reader's is JSON).
- Device persistence: already there (Build/Device by name); the
  calibration sets it and SaveSettings keeps it.
NOT COMPILED (no Delphi here; pasdoc_check, project_check 0 problems).
Names used from memory, worth a look if the compile complains:
TForm.CreateNew, TFormPosition.OwnerFormCenter, TStyledSetting.Other,
TButton.Cancel / Default / ModalResult, Posix.Unistd.gethostname,
System.Win.Registry TRegistry.OpenKeyReadOnly.
TO TEST (Windows, then the Ideapad):
1. Delete [Calibration*] from EpubBuilder.ini (or the file); start: the
   question; Start with large-v3: CPU, CUDA0, Vulkan0 timed; Vulkan0
   expected fastest; cbDevice set; EpubBuilder-calibration.log written.
2. Restart: no question, "Calibrated ..." line.
3. A build: the log's Machine / Device lines; the queue report's columns.
4. Ideapad, large-v3: CUDA0 / Vulkan should FAIL (memory) -> the CPU
   chosen with the "a smaller model may fit" line; Create on CUDA0 asks.
   If the program dies instead: restart -> the crash line, the pair
   skipped.
5. Tools > Re-calibrate every model in its folder (base .. large-v3).
6. Cancel during a calibration; close during one (no error, no leak).
Offered, not done: time-left for the calibration; the reader does not
transcribe, so it needs none; media/aladdin.m4a is not deployed by
deploy_redist.py (copy it, or a DeployFile entry - owner's call: LibriVox
recordings are public domain).

## Zip 78 (on top of 77): Steam builds; macOS ARM as a test-bed
Owner, 2026-11-17: a Steam AppID bought - deploy through Steam; Windows,
Linux and macOS ARM builds "even if incomplete, make a good test-bed";
TSteamAPI added, "easy to select or deselect from the build process";
Reader and Builder both. AppIDs (owner): EpubReader 5639840, EpubBuilder
5639910. Switch (owner's choice of three): BUILD CONFIGURATIONS, not a
source define. Owner, mid-turn: "There is a RestartIfRequired in
TSteamAPI that starts steam etc, there is also a way to run debug code" -
RestartIfNecessary in Steam (Release child), SetAppIdEnvironment in
SteamDebug (Debug child), as TSteamAPI's demos (its docs/Launcher.md).
- NEW demos/common/uSteam.pas: everything Steam, behind STEAMBUILD.
  Without it the unit uses no Steamworks unit (non-Steam builds need
  TSteamAPI neither built nor installed). SteamStartup(AppID) in the .dpr
  after Application.Initialize, before any form: TSteamAPI (FMX, owner
  nil, freed in the unit's finalization - before the Steamworks units'
  own); OnRestartRequired sets ATerminate False and the .dpr Exits (no
  form made, so nothing half-started). OnInitFailed assigned: no message
  box; the program CARRIES ON without Steam and logs why (ASSUMPTION - the
  owner did not answer "relaunch, else carry on / else refuse"; neither
  program uses a Steam feature yet). SteamText / SteamNotes: the forms
  log them (reader: debug log; builder: window + every build's log).
- .dpr: STEAM_APP_ID const, uSteam in the uses.
- .dproj (EpubReader, EpubBuilder; by hand, platforms untouched):
  configurations Steam (Cfg_3, parent Cfg_2) and SteamDebug (Cfg_4,
  parent Cfg_1), each declared right after its parent's declaration
  group (MSBuild reads in order: the parent's flag must be set before its
  platform groups are read), with a Win64 group; value groups before the
  first ItemGroup: DCC_Define STEAMBUILD, and on Win64 a PostBuildEvent
  copying redistributable_bin/steam/win64/steam_api64.dll to $(OUTPUTDIR)
  (fails the build when missing). DeployFile entries, Configuration
  Steam / SteamDebug only: steam/linux64/libsteam_api.so (Linux64, .\),
  steam/osx/libsteam_api.dylib (OSX64, OSXARM64, Contents\MacOS\ - as
  TSteamAPI's SteamDemo). deploy_redist.py's entries (Linux64\) are
  untouched by it and it does not touch these.
- redistributable_bin/steam/{win64,linux64,osx}: copied from TSteamAPI's
  redistributable_bin (Valve's SDK); git-ignored like the rest.
NOT COMPILED. TO TEST: Release and Debug still build WITHOUT TSteamAPI's
packages; SteamDebug Win64 from the IDE with Steam running (log: "Steam
build, AppID ...: Steam running"; Steam shows the program as running);
Steam config started by double click (Steam launches it); Steam not
running / not logged in (the line, the program works); Linux64 /
OSXARM64 deploy carries libsteam_api.
If the IDE re-saves a .dproj and moves the new groups: fine, its layout
wins; check that STEAMBUILD is still in Steam / SteamDebug.
MACOS ARM (no code needed here for a first build - all three loaders
look in the bundle's Contents/Frameworks, redist.sh deploy OSXARM64
fills it): on the Mac whisper-dev (Metal - not built yet) and ffmpeg-dev,
redist.sh collect, then after each PAServer build redist.sh deploy
OSXARM64 <scratch dir>/<Program>.app (a Clean empties the bundle;
deploy_redist.py is Linux64 only). Expected gaps: EpubReader SILENT
(TFFMpegAPI has no AudioQueue output yet); EpubBuilder's devices are the
CPU and Metal (the calibration will tell); signing / notarising for Steam
not looked at.
NEXT (offered): Steam depots and app build scripts (steamcmd
app_build / depot_build .vdf, one depot per OS per program - the depot
IDs from the Steamworks site), and the GPU-backends-as-DLC plan above.

## Zip 79 (on top of 78): the builds copy their libraries
Owner, 2026-11-17: "For the windows build you are now copying the Steam
DLL to the output folder. Can you also do that for required DLLs for
Reader and Builder but with Builder only supply CPU + Vulkan (Mac CPU +
Metal). The others we'll do as DLC".
- NEW tools/postbuild.bat PROGRAM CONFIG OUTPUT_FOLDER (CRLF), the
  Base_Win64 PostBuildEvent of both .dproj (every Win64 configuration;
  the zip 78 Cfg_3_Win64 / Cfg_4_Win64 copy groups removed - their
  declaration groups stay): EpubReader av* / sw* / postproc* + FFmpeg
  licences; EpubBuilder Steam / SteamDebug = everything but the cuda and
  rocm parts (names as tools/redist-package.ps1: ggml-cuda, cudart64_*,
  cublas*, nvrtc*, ggml-hip, amdhip64*, amd_comgr*, hiprtc*, hipblas*,
  rocblas*, rocsolver*, libhipblas*, the rocblas / hipblaslt folders,
  CUDA-* / ROCm-* licences), Debug / Release = everything (DECISION
  here: the owner tests CUDA from the IDE; say if Release should be
  core only too); Steam configs + steam_api64.dll. robocopy (unchanged
  files not copied again). No redistributable_bin\Win64: Steam fails,
  Debug / Release warn. NOTE: a Debug / Release output folder now holds
  the libraries itself (CUDA ~1 GB on the first build), and whisper.cpp
  is loaded from there before PATH.
- .gitattributes: *.bat text eol=crlf (cmd misreads labels in LF-only
  batch files; redist.bat was LF in the repository).
- tools/redist.sh deploy OSX64 / OSXARM64: by the .app's name - EpubReader
  FFmpeg only (and its licences); otherwise no *vulkan* / *cuda* / *hip*
  library (CPU + Metal). Linux64 unchanged (deploy_redist.py still puts
  everything into EpubBuilder: CUDA on the GTX 1650 is tested that way;
  a --core switch for Steam Linux depots is the obvious next step).
NOT RUN (no Windows here): postbuild.bat read through only; the macOS
filter was run on a dummy folder (EpubBuilder: whisper, ggml-base, -cpu,
-metal, -blas, FFmpeg; EpubReader: FFmpeg).
TO TEST: Win64 builds of both in Debug and Steam (the messages in the
build output; the Steam folder has no ggml-cuda / ggml-hip, its device
list is CPU + Vulkan); EpubReader plays from its own folder.
Also noted 2026-11-17:
- The owner codesigns the Mac builds himself. redist.sh deploy signs
  Contents/Frameworks (CODESIGN_ID for his identity);
  libsteam_api.dylib, deployed by Delphi into Contents/MacOS, is not
  signed by it - sign it with the app.
- FOR LATER (owner: "a good plan - for later"): CHINESE / JAPANESE.
  EpubUnum's walker splits words at spaces and dashes only, so a CJK
  sentence would be one word. Plan: (1) Epub.Layout - every Han
  character (and kana) a word, punctuation attached as now; (2) TWhisper
  - Whisper's CJK pieces (already "every whole character piece is a
  word") split to single characters, and WhisperSplitBookWords the same
  - the two lists must still agree; (3) reader phrase / sentence steps
  at 。，！？ etc. (EndsPhrase is ASCII). Test pair: the Analects -
  LibriVox Chinese (classical text, 2:27:53) and English (Legge),
  Gutenberg texts of both. Starter book for other languages: Andersen's
  Princess and the Pea, Emperor's New Clothes, Steadfast Tin Soldier -
  each recorded on LibriVox in 7 languages (EN, NL, DE, FR, EL, FI + DA
  or EO); each recording needs the EPUB of the translation its reader
  used.
- Steam: Whisper models are MIT (OpenAI; ggml conversions MIT) -
  licences with them; one model in the base depot (turbo), others as
  free DLC like the GPU backends; Steam's AI disclosure (live-generated,
  with a guardrails statement) for EpubBuilder, none for EpubReader.

## Zip 80 (on top of 79): first Steam build (owner, 2026-11-17)
The owner's dcc64 output for EpubReader, configuration Steam, Win64:
COMPILED (STEAMBUILD;RELEASE;SKIA defined - the configuration and
TSteamAPI's units work), then "[Exec Error] The command "call ...
postbuild.bat" EpubReader Steam ".\Win64\Steam\"" exited with code 1".
- $(OUTPUTDIR) is RELATIVE (.\Win64\Steam\). postbuild.bat now takes
  $(PROJECTDIR) as a 4th argument (both .dproj pass it) and makes a
  relative output folder the project's; the folder is then normalised
  (%%~f: no ".\", no trailing backslash).
- The other likely cause: no redistributable_bin\Win64 in Epubunum (the
  owner's libraries are TWhisper's redistributable_bin\Win64 on PATH -
  the build log's whisper.cpp / FFmpeg folder) - a Steam build fails
  then, by design; the message is in the IDE's Output pane. redist.bat
  collect: FFMPEG_DEV is optional when WHISPER_DEV holds FFmpeg's DLLs
  too (TWhisper's folder does): tools\redist.bat collect
  <TWhisper>\redistributable_bin\Win64.
- uDebugLog: Winapi.Windows in the uses on Windows (H2443 RenameFile),
  {$WARN SYMBOL_PLATFORM OFF} around RegisterExpectedMemoryLeak (W1002).

## Zip 81 (on top of 80): postbuild.bat says which copy failed
Owner, run by hand (PowerShell): "postbuild: copying to
...\Win64\Steam failed" - past the library and folder checks, so a
robocopy gave 8+ (no step named). Likely: no redistributable_bin\Win64\
licences (folder filled by hand, not by redist.bat collect) - robocopy
16. Now: licence texts are optional (:licences - a warning when the
folder or the copy is missing), and every failure names its step, the
source, the target and the code (8 = files not copied - in use?; 16 = a
folder missing). Owner to run it again and send the line.

## Zip 82 (on top of 81): whisper.cpp's licence; paths tidied
Owner: zip 81's postbuild works (EpubReader Steam: FFmpeg +
steam_api64.dll copied); "redist.bat collect <TWhisper>\redistributable_bin
\Win64 <ffmpeg-dev>" gave licences CUDA-EULA + FFmpeg-* but NO
whisper.cpp-LICENSE (only looked for WHISPER_DEV\whisper.cpp\LICENSE).
redist.bat collect now also takes it from a licences folder or a
whisper.cpp-LICENSE.txt beside the DLLs / in WHISPER_DEV, and WARNS when
none is found (MIT: it must ship with the DLLs - the Steam depot).
ROOT in redist.bat and postbuild.bat is the full path (messages showed
tools\..).

## Zip 83 (on top of 82): POSIX build of uDebugLog (PACKAGE: EpubUnum)
Owner's Linux / macOS build of EpubReader: E2003 RegisterExpectedMemoryLeak
in uDebugLog (zip 73's fix: the call exists on Windows only - never
compiled for POSIX since), H2443 RenameFile wants Posix.Stdio.
- uDebugLog: RegisterExpectedMemoryLeak under {$IFDEF MSWINDOWS};
  Posix.Stdio beside Posix.Unistd.
- The same H2443 in the package units (Delphi on POSIX only): Epub.Zip
  (DeleteFile -> Posix.Unistd), Epub.Writer (DeleteFile, RenameFile ->
  Posix.Unistd, Posix.Stdio), under {$if defined(POSIX) and not
  defined(FPC)} - FPC builds of lib/ unchanged. NOT COMPILED here (no
  FPC / Delphi in this session).

## Zip 84 (on top of 4b560d1 = zip 83): EpubBuilder's Linux launcher
Owner: "Linux has no shell file - check TSteamAPI demos". TSteamAPI: every
program Steam may start on Linux ships <program>.sh (the ICU launcher,
identical but for its name - it starts the program named after it),
deployed by its .dproj on Linux64 (DeployFile src\<program>.sh), and
FmxLinuxGtkGlobal in the .dpr (FMX crashes in Steam Linux Runtime 3.0
without it).
- NEW demos/EpubBuilder/src/EpubBuilder.sh (= EpubReader.sh, LF, mode
  755 - OWNER: git update-index --chmod=+x after adding it, the rule),
  src/FmxLinuxGtkGlobal.pas + src/FmxWineCanvas.pas (unchanged copies of
  TSteamAPI's, = EpubReader's: md5 checked) in EpubBuilder.dpr / .dproj.
  No FmxSkiaCanvas (the builder draws nothing with Skia) and no
  FmxLinuxMenu (its menu is already an FMX TMenuBar on Linux).
- Both .dproj (edited on the IDE-saved 4b560d1 versions): DeployFile
  src\<program>.sh for Linux64 in Debug, Release, Steam, SteamDebug
  (EpubReader's script was only copied by redist.sh deploy before).
- tools/redist.sh deploy Linux64 copies EpubBuilder.sh too (chmod +x).
- STEAMWORKS (owner): each app's Linux launch command = <program>.sh.
  Whether PAServer's deploy keeps the executable bit is not known here:
  if the script arrives without it, chmod +x (redist.sh deploy does).

## Zip 85 (on top of 84): the Mac libraries through Delphi's Deploy
Owner, 2026-11-17: Mac set up (repositories on an external drive - the
home folder's disk is small; PAServer's scratch dir can go there with
paserver -scratchdir=...); "mac has no dlls" - Deploy put no libraries in
the .app (only redist.sh deploy, on the Mac, did). Signing (owner): his
Developer ID taken out of the Steam configuration for now - Steam needs
no notarization; ad hoc everywhere (a Developer ID app with the hardened
runtime would refuse ad-hoc / Valve-signed libraries: library validation).
- tools/deploy_redist.py --platform Linux64 (default) | OSXARM64 | OSX64:
  macOS entries go to Contents\Frameworks\ (libraries) and
  Contents\Resources\licences\ (licence texts); EpubBuilder there = no
  *vulkan* / *cuda* / *hip* file (CPU + Metal), EpubReader = FFmpeg
  (lib(av|sw|postproc)*.so|dylib + licences/FFmpeg-*) on every platform.
  Versioned dylib names (libX.N.M.P.dylib) dropped when libX.N.dylib /
  libX.dylib are there. Each platform's entries replaced on their own.
  TESTED here on a dummy OSXARM64 folder: 13 / 5 entries, Linux64's 115
  untouched, a second run replaces, BOM kept, XML valid.
- Owner's flow: Mac collect -> copy redistributable_bin/OSXARM64 to the
  Windows checkout -> deploy_redist.py --platform OSXARM64 -> reopen,
  Deploy. Delphi then signs (ad hoc) a bundle that already holds them.

## Zip 86 (on top of 85): Steam Deck crash - diagnostics
First Steam builds (owner, 2026-11-17): WINDOWS known; MAC runs and
loads, no sound (TFFMpegAPI has no AudioQueue - known); STEAM DECK
(EpubReader, Steam Runtime 3 sniper, SteamOS 3.9.5): the Steam handover
works (RestartIfNecessary: "Steam is already running ... forwarded"),
GTK fix and launcher ran, Steam API up, PulseAudio output up, the book
read (24 documents, 113836 words, 112772 clips), chapters built, cover
cached - then "Access violation ... accessing address 0000000000000000"
in a library, twice, both runs' logs ending at "cover: <book>" (the
cover existed: EnsureCover returned at once). Next in EpubUnum1Opened:
HideLibrary, RestoreWord (ScrollToWord: the first Skia layout of
document 6 - 31851 words), RememberBook, then the first paint. Prime
suspect: Skia's font lookup inside the container (fontconfig there
finding no face -> a nil typeface in libsk4d), the review's open item
(no MakeDefault fallback in TEpubView.Fonts).
- uMain: LogFontProbe at start-up - MakeFromName for EPUBREADER_FONT,
  sans-serif, serif, monospace, DejaVu Sans, Noto Sans, Liberation Sans
  (family found or NONE), and on POSIX whether /etc/fonts,
  /usr/share/fonts, /run/host/fonts, /run/host/user-fonts,
  /run/host/local-fonts exist, FONTCONFIG_FILE / _PATH. The open sequence
  after the cover logs each step ("open: cover done ...", "back to word
  N", "remembering", "done (the page is drawn next)").
- NEXT, by the log: no face -> bundle a font (OFL / Bitstream Vera
  licence: Noto Sans or DejaVu Sans) and TSkTypeface.MakeFromFile in
  TEpubView.Fonts as the last resort; a face found -> the crash is
  elsewhere (layout of the 31851-word document? the first paint?).

## Zip 87 (on top of 8e306df = zip 86): build stamp
Owner sent the Deck's debug log of 15:11: the OLD build (no "fonts:"
line, no "open: cover done" - zip 86 not in that upload); "Can we have a
build version or something - can't tell if this is new update or not".
- NEW tools\buildstamp.bat (CRLF): PreBuildEvent of both .dproj ('$(Base)'
  group: every platform and configuration - Delphi compiles on Windows
  for Linux / macOS too; IgnoreExitCode true), writes
  demos\common\BuildStamp.inc (.gitignore): const BUILD_STAMP =
  'yyyy-mm-dd hh:nn, <git short hash>[+]' ('+' = git status --porcelain
  --untracked-files=no not empty; "no git" when git is not on PATH; time
  from PowerShell Get-Date, else %DATE% %TIME%). Always exits 0.
- uDebugLog: {$I BuildStamp.inc}, BuildStamp function; the log's
  header has "Build: ..." under the first line. EpubBuilder: "Build:"
  in the window at start, "EpubBuilder build:" in every build's log
  (LogMachine) - so the queue's .log files say it too.
- NOTE: a project that uses uDebugLog needs the pre-build step (or the
  .inc) - only EpubReader and EpubBuilder do. A command-line build runs
  PreBuildEvent too.
NOT COMPILED here. The sample .inc as the batch writes it passes
pasdoc_check.

## Zip 88 (on top of 87): where a crash happened, in the log
Deck log of 15:17 (zip 86 build, before zip 87's stamp): FONTS FINE -
sans-serif -> DejaVu Sans, serif -> DejaVu Serif, monospace -> DejaVu
Sans Mono, Noto Sans found, Liberation Sans none; /etc/fonts,
/usr/share/fonts, /run/host/fonts there (host fonts passed in), no
FONTCONFIG_* set. The open sequence COMPLETES ("open: done (the page is
drawn next)"; no saved word, so no RestoreWord) - the access violation
(address 0, in a library) is in the FIRST PAINT: TEpubView's layout /
paint with Skia (paragraphs, pictures via MakeFromEncoded, the progress
strip), or FMX's Linux canvas inside the runtime.
- uDebugLog: DebugLogWhere(Address) - on Linux the file and offset from
  /proc/self/maps ('libsk4d.so +0x1a2b3c (/path)'); DebugLogException(E,
  ExceptAddr) - class, message, raised-at address and its place, plus the
  place of the address an access violation's message names (the faulting
  instruction). System.SysUtils moved to the interface's uses (Exception
  in a declaration): DeleteFile / RenameFile there now QUALIFIED
  (Winapi.Windows, later in the uses, has its own).
- EpubReader and EpubBuilder: Application.OnException := AppException
  (DebugLogException, then Application.ShowException as before).
NEXT: the Deck's "UNHANDLED EAccessViolation ... in <library> +0x..."
line names the library: libsk4d.so -> Skia (the view's layout / paint:
try a small book, EPUBREADER_FONT=Noto Sans; then a TEpubView log hook);
libgtk / libcairo / libgdk -> FMX's canvas in the runtime (try
TSAPI_FMX_CANVAS - FmxSkiaCanvas); anything else - see.

## Zip 89 (on top of 88): FreeType for Steam Linux Runtime 3 - THE DECK FIX
Deck log with zip 88 (build "2026-11-17 15:26, 662ddc7"): UNHANDLED
EAccessViolation at ...F2B7 reading 0 in libfreetype.so.6.17.4 +0x522B7
(/usr/lib/x86_64-linux-gnu/ - the RUNTIME's FreeType 2.10.4), on the first
page drawn. ldd: libsk4d.so links libfreetype.so.6 (system's). Test 2
(FONTCONFIG_FILE with only the runtime's /usr/share/fonts): still
crashes - not a host font. Test 3: Ubuntu 22.04's FreeType 2.11.1 (+
libbrotlidec / libbrotlicommon) next to EpubReader and the program's
folder first on LD_LIBRARY_PATH in EpubReader.sh: "Works fine" (owner).
- tools/redist.sh collect, Linux64: freetype_for_runtime - docker / podman
  run ubuntu:22.04, apt-get install libfreetype6, copies
  libfreetype.so.6, libbrotlidec.so.1, libbrotlicommon.so.1 and the
  Debian copyright files as licences/FreeType-copyright.txt,
  licences/brotli-copyright.txt (FTL or GPL; brotli MIT). No docker /
  podman: a warning, collect goes on.
- tools/deploy_redist.py: EpubReader's share (reader_file) = FFmpeg +
  libfreetype / libbrotli* + their licences (EpubBuilder: everything, as
  before - it gets them too).
- EpubReader.sh / EpubBuilder.sh (identical to each other, NO LONGER to
  TSteamAPI's): before exec, when $here/libfreetype.so.6 exists, $here
  first on LD_LIBRARY_PATH (+ a stderr line). Tested here: without the
  file nothing changes; with it the folder comes first.
- TSteamAPI: every FMX + Skia program in SLR 3 has this crash - the same
  launcher addition belongs there (owner's repository; offered).
TO DO on the owner's side: redist.sh collect on Linux (with docker), copy
redistributable_bin/Linux64 to Windows, deploy_redist.py (Linux64), then
the depot; the Deck test with the depot's files (not the hand-edited
script).

## Zip 90 (on top of a6ea67b = zip 89): the display, in the logs
Owner, 2026-11-17: Big Picture / handhelds need a big-screen interface -
VirtualGamepad's pad overlay menu (hold a button; up / down / accept /
cancel), touch, keyboard and mouse still working - and sizes from the
screen's real size (handhelds, big monitors, TVs). Decided (owner):
EpubReader now, EpubBuilder later; screen detection and the pad menu as
NEW TSteamAPI units; automatic switch (Big Picture, Deck, small screen)
with a setting to override. Stage 1 (this zip + TSteamAPI zip Screen1):
measure and log only, so the numbers from every machine come before any
layout uses them.
- demos/common/uSteam.pas: SteamScreenText(Form) - TSteamAPI's
  SteamScreenInfo(Form).Text in a Steam build (size in units / pixels /
  mm and where the mm came from, Big Picture, Steam hardware, big-screen
  yes / no, UI scale, viewing distance); 'not measured (not a Steam
  build)' otherwise. FMX.Forms in its interface uses.
- EpubReader uMain: FormShow (OnShow set in FormCreate) logs it once, when
  the window is on its display (ForceQueue). LogFontProbe Linux only (on
  the Mac it printed NONE for every name - fontconfig's names - while the
  text drew fine).
- EpubBuilder uBuilder: FormShow logs it before the calibration question.
Mac sound (FFmpegAPI-14, AudioQueue) CONFIRMED by the owner 18:25 - 18:34:
play / pause, jumps, speed slider, the end of an audio file.
NEEDS TSteamAPI zip Screen1 (Steamworks.FMX.Screen) in SteamworksFMX for
the Steam configurations; Debug / Release do not use it.

## Zip 91 (on top of 3cefa7f = zip 90): Per Monitor v2 DPI awareness
First Windows screen: line (27" 4K monitor at 150 %): "2560 x 1440 units,
scale 1.00 (2560 x 1440 px)" - the programs had NO DPI awareness in their
manifest (no AppDPIAwarenessMode: Windows stretched a 96 dpi window, FMX
saw 2560 x 1440 at scale 1). Owner: "you never set dpi awareness in the
manifest - v2 fixes that" (and declined a TSteamAPI work-around reading
the display mode). EpubReader.dproj / EpubBuilder.dproj, Base_Win64:
AppDPIAwarenessMode PerMonitorV2, AppEnableRuntimeThemes true,
Manifest_File $(BDS)\bin\default_app.manifest (the IDE's "Auto generate"
manifest). Expected: a sharp window, and "scale 1.50 (3840 x 2160 px)".
TSteamAPI pushes checked: d11be14 = Screen1, a58bd1d = Screen3 (Screen2 +
TDisplay from FMX.Types; compiled on Windows).

## Zip 92 (on top of 91): Big Picture maximises the window
Owner 20:20, zip 91 build: sharp; screen: "scale 1.50 (3840 x 2160 px)"
on the 27" 4K monitor (confirmed). Big Picture (Windows) run: "-> big-
screen interface, UI scale 1.75 (viewing distance 1103 mm)" - but "Big
Picture: yes - BigPictureWindow bpwMaximized: no form to change": uSteam
starts TSteamAPI in the .dpr, before any form. Fixed in TSteamAPI (zip
BigPicture1: the timer applies it once the main form exists, and logs a
line). uSteam: Steam's lines go straight into the debug log once it is
open (before: kept as SteamNotes only, so that later line was lost).

## Zip 93 (on top of 827bed1 = zips 91 + 92): Big Picture full screen
Owner 20:53, zip 92 + TSteamAPI BigPicture1: the late maximise works
("the main form exists now - TfrmMain maximised"), but "Windows still had
taskbar, caption, menu etc"; his SRDelphiFMX (LenticularDemoFMX /
StereoModel) does real full screen on Windows. TSteamAPI zip FullScreen1:
bpwFullScreen on Windows = that method. Here:
- uSteam: BigPictureWindow := bpwFullScreen; SteamBigPicture (known from
  SteamStartup on, before any form).
- EpubReader BuildMenu: in Big Picture the TMainMenu is made but NOT put
  on the form (its items still exist - code uses miRecent, miDark, ...);
  Linux: mnuBar hidden. RefreshMenu only for a menu on the form. Without
  the menu: Library / Recently Opened / Find / Learn / Exit have keys or
  the library; Exit only through Steam (or Alt+F4) until the pad menu.
- EpubBuilder keeps its menu (re-calibration is only there; its big-screen
  interface comes later) - full screen with a menu bar.
Pushes checked: 827bed1 = zips 91 + 92 (+ IDE re-saves of EpubConsole and
the two package .dproj: OSX Cfg_2 groups added by the IDE - fine).

## Zip 95 (on top of 51bb81e = zips 93 + 94): the Mac's ggml backends
Session 9 (2026-11-18), owner: "is builder ready for macarm?". No: the
OSXARM64 deploy entries in EpubBuilder.dproj held libwhisper, libggml,
libggml-base and FFmpeg but NO backend - no CPU, no Metal. whisper-dev
builds with GGML_BACKEND_DL=ON: each backend is a CMake MODULE library,
and CMake names those lib*.so on macOS too; ggml itself looks for ".so"
on every system but Windows (ggml-backend-reg.cpp,
backend_filename_extension). tools/redist.sh copied, deployed and signed
*.dylib only on the Mac, so the backends never reached
redistributable_bin/OSXARM64 (zip 79's test used a dummy folder that had
them). TWhisper loads the backends from its library folder
(ggml_backend_load_all_from_path, Contents/Frameworks) - no change there.
- tools/redist.sh: collect copies WHISPER_DEV's libggml-*.so on macOS too
  and warns when no libggml-cpu*.so / libggml-metal.so is there; deploy
  copies and signs *.so beside *.dylib (EpubBuilder: no vulkan / cuda /
  hip as before; EpubReader: FFmpeg only as before). Linux64 unchanged.
- deploy_redist.py needs no change (it passes .so names through).
TESTED here on a fake Mac (uname / codesign shims): collect -> 14 files
with libggml-cpu-*.so, -metal, -blas; deploy EpubBuilder.app -> those
without -vulkan, all signed; EpubReader.app -> FFmpeg only;
deploy_redist.py --platform OSXARM64 -> the backend entries; with no
backends -> both warnings. NOT RUN on a real Mac.
TO DO on the Mac: check whisper-dev's dlls/ has libggml-cpu*.so and
libggml-metal.so (zip 78 said Metal was not built yet), redist.sh collect,
copy redistributable_bin/OSXARM64 to Windows, deploy_redist.py --platform
OSXARM64, Deploy; EpubBuilder's calibration should list CPU and Metal.
Owner, Mac, 09:04: whisper-dev's dlls/ has libggml-cpu-apple_m1 / _m2_m3
/ _m4.so and libggml-metal.so; collect with zip 95 took them (no
libggml-blas - BLAS off, fine).

## Zip 96 (on top of zip 95): the calibration recording deployed
Owner, 09:14: "Mac Deployment (and Linux) are missing aladdin.m4a for
calibration"; "Mac will need some models". FindCalibrationAudio looked
beside the program and up to 5 folders above - fine from the Windows
build tree, not from PAServer's scratch dir or inside a .app.
- uCalibration.FindCalibrationAudio: on macOS first the bundle's
  Contents/Resources/media/aladdin.m4a (ParamStr(0) is Contents/MacOS).
- tools/redist.sh collect: media/aladdin.m4a (repo root, git-ignored)
  into redistributable_bin/<platform>/media/, a WARNING when missing;
  deploy macOS: EpubBuilder.app gets it in Contents/Resources/media
  (EpubReader not); Linux64 deploy copies the folder whole as before.
  package: media/ goes into the core part (public domain, LibriVox).
- tools/deploy_redist.py: media/ on macOS -> Contents\Resources\media\
  (Linux64 .\media\); EpubBuilder only (reader_file excludes it).
- EpubBuilder README: where the recording is looked for.
TESTED here: fake Mac collect / deploy (builder has it, reader not),
deploy_redist.py OSXARM64 and Linux64 entries, XML valid, the warning.
uCalibration NOT COMPILED (FMX; no Delphi here).
Linux64 without collecting again: copy media/aladdin.m4a to
redistributable_bin/Linux64/media/ on Windows, then deploy_redist.py.
MODELS: not deployed (1.6 GB for turbo; a Clean would delete them):
whisper.cpp's models/download-ggml-model.sh NAME FOLDER into a folder on
the Mac, chosen in the window; Tools > Re-calibrate every model in its
folder.

## Pushes checked
- a6ea67b ("SteamOS good") = zips 87 - 89: identical (CR LF aside) but
  the IDE-saved EpubReader / EpubBuilder .dproj - buildstamp PreBuild
  (repeated per configuration by the IDE), postbuild, the .sh deploy
  entries, libsteam_api, STEAMBUILD: all kept.
- 8e306df ("Latest", after 46d2adc = zip 84) = zips 84 - 86 + demos/
  restored (the owner deleted demos/ on Windows; sent whole):
  identical (CR LF / BOM aside) but the IDE-saved .dproj / .deployproj -
  STEAMBUILD, postbuild x4, <program>.sh x4 (moved by the IDE),
  libsteam_api, uSteam: all there; XML valid. EpubBuilder's Steam
  configuration got BT_BuildType Debug on OSX64 / OSXARM64 / Win64 (the
  owner took his Developer ID out). No OSXARM64 library entries yet
  (deploy_redist.py --platform OSXARM64 not run on the real folder).
  .sh 100755. project_check, pasdoc_check 0.
- 4b560d1 ("Latest", 2026-11-17 13:29) = zips 77 - 83 (46e03e3 before
  it): every delivered file identical (CR LF / BOM aside) except the two
  .dproj files, re-saved by the IDE - STEAMBUILD in Steam and
  SteamDebug, the postbuild call (with $(PROJECTDIR)) in all four Win64
  configurations, the libsteam_api deploy entries: all kept; the empty
  Cfg_3_Win64 / Cfg_4_Win64 groups dropped, declarations moved (fine).
  Default configuration now Steam (IDE: the last active one - a
  command-line build without a configuration is a Steam build). Owner
  added media/.gitignore (*.m4a, *.m4b). .bat files: stored LF,
  checked out CRLF (.gitattributes). project_check, pasdoc_check 0.
- 20fc7ce ("Claude push", 2026-11-17 09:27) = zips 74 - 76 (CLAUDE.md
  only); 2b69310 (2026-11-16 21:36) = zip 73 (the review fixes: all five
  in the source). pasdoc_check, project_check 0 problems. Shallow clone,
  not compared file by file.
- e00fb17 ("Claude push", 2026-11-16 21:25) = zip 72 (the handover);
  cloned shallow for the review, not compared file by file.
- d242ae1 (2026-11-16 21:18) = zips 64 - 71: every delivered file
  identical; the .dproj files carry deploy_redist.py's entries (115 / 16).
  whisper-dev 9fa21dc = its 19 - 20.
- 01a4b4e ("Claude push", 2026-11-16 18:14) = zips 52 - 63: every
  delivered file identical (CR LF / BOM aside) except the four .dproj
  files the IDE re-saved: default platform now Linux64 (owner's IDE),
  ProjectName lines dropped from the packages, uDebugLog references kept;
  new *.deployproj files (IDE). project_check 0. whisper-dev 3459870 =
  its zips 08 - 18; ffmpeg-dev 4d7b7be = 09; TWhisper d669a06 = 30.
- 4d7dfbe ("Claude push", 2026-11-15 22:58): the repo's head at the
  start of session 7, after 5717238 = zip 37; taken as zip 38 (the
  handover). Clone is shallow: not compared file by file.
- 5717238 = zip 37 (session 6 check, see the handover).
- 7723030 ("Claude push", 2026-11-15 21:12) = zips 15 - 32: every file
  identical to the deliveries (CR LF / BOM aside) except
  demos/EpubBuilder/EpubBuilder.dproj, re-saved by the IDE (its platform
  blocks and TargetedPlatforms; MainSource and the uBuilder reference
  unchanged) - the pushed one is the one to keep. pasdoc_check,
  project_check: 0 problems. TWhisper at f47da6b (= its zip 28).
- 26118e5 = zip 14 (owner: applied and pushed; his Delphi EpubConsole
  --overlay of the full Moby-Dick from TWhisper timings: 211964 clips, 0
  left out).
- 6ab27c4 ("EPub view etc") = zips 09-13: every delivered file identical
  to a fresh clone (2026-11-15); pasdoc_check, project_check 0 problems;
  FPC build of lib + EpubConsole runs. Owner: "11-13 applied and tested"
  (dark sidebar fixed by the transparent list style).
- ef2daff = zip 08 (review fixes, on 68162a4 = zips 06 + 07): checked
  2026-11-15 by clone; pasdoc_check and project_check 0 problems.
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
