# CLAUDE.md - working rules for this repository

Read README.md first, then this file. Keep both up to date with every
change. The rules follow TWhisper's and TFFMpegAPI's CLAUDE.md (same
owner, same conventions); where this file is silent, theirs apply.

THE HISTORY IS IN `archive/CLAUDE.001`: every zip's section from 01 to
411 (the owner's words, what was measured, what went wrong), the
handovers of sessions 7 - 18 and the plans parked on the way. It is
about 850 KB: never read it whole. Search it (`grep -n "## Zip 392"
archive/CLAUDE.001`, or a word) and read only the part needed. This file
holds what every session needs: the rules, the map, where things stand,
what is next. Zip sections from 412 on go at the end of THIS file; when
it grows past ~80 KB, move the older ones to `archive/CLAUDE.002` (owner
2026-11-28 11:11: "put important information in CLAUDE.md and rename the
current one to archive/CLAUDE.001").

## Standing rules - the owner's, every one of them has bitten

### Working with the owner
- NEVER commit or push, and never offer to. The owner applies the zips,
  builds, runs and pushes.
- NOTHING IS COMPILED HERE (no Delphi; FPC only for lib/ when set up).
  The owner builds and runs every zip, often within minutes, at any
  hour: small zips, one thing each; say in the delivery what is not
  known until it runs.
- THE LOG FIRST: never guess a cause before the debug log is read; read
  both logs' times before naming a delay. A stale build looks like a
  bug: the log's second line ("Version: 0.0.N") and "Build:" say which
  build ran - ask which build ran and whether the zip is in the folder
  before looking for a fault.
- Answer simple questions directly and briefly first. A message that
  arrives mid-task is answered in the same turn.
- A COMMAND GIVEN TO THE OWNER IS GIVEN IN FULL: every argument, with his
  real folders where known (C:\src\epubunum, C:\src\whisper-dev,
  C:\src\Whisper = TWhisper; Linux ~/src/whisper-dev; the Mac's
  whisper-dev on its SN770 volume). A folder not known is asked for.
- Ask one precise question where a wrong guess would cost a zip.

### Deliveries
- Zips: EpubUnum-NN-topic.zip (other repos: TWhisper-NN-, FFmpegAPI-NN-,
  ffmpeg-dev-NN-, whisper-dev-NN-), only the files changed since the
  previous zip, paths from the repository root, each saying what it goes
  on top of. A number is never reused (a corrected zip gets the next).
- THE SUMMARY'S FIRST LINE says "NO PACKAGE REBUILD" or the banner, and
  names any .dproj in the zip. The banner, exactly - a blank line, then

      =====> PACKAGE REBUILD NEEDED <=====

  then a blank line and which packages in build order (EpubUnum ->
  EpubUnumFMX -> dclEpubUnumFMX; TWhisper: WhisperAPI -> WhisperAPIFMX ->
  dclWhisperAPIFMX), the unit changed, what to rebuild after. Only when a
  PACKAGE unit (lib/, fmx/) changed; a program-only change is "NO
  PACKAGE REBUILD". Android / iOS need the packages built for that
  target too ("Unit not found: Epub.Zip" = not built for it).
- A STEAM REBUILD is flagged the same way (`=====> STEAM REBUILD NEEDED
  <=====` + the programs) when a delivery changes more than the one
  program under test - a unit another Steam program compiles
  (demos/common, uPadMenu, uReaderInput, uCovers ...), the Steam Input
  definitions, staged or redistributed files. Otherwise say nothing
  about Steam builds.
- VERSIONS major.minor.build: EVERY ZIP sets VERSION_BUILD in
  demos/common/uVersion.pas to its own number and "Last number used" at
  the end of this file (tools/project_check.py fails when they differ).
  Major / minor change only when the owner says. Compare versions part
  by part as integers (VersionCompare). NOT YET in the .dproj version
  info (Android versionCode 1 / versionName 1.0.0, Windows 1.0.0.0).
- Before delivering: `python3 tools/pasdoc_check.py` and
  `python3 tools/project_check.py` (both 0 problems); an FPC build of
  lib/ and EpubConsole when lib/ changed and FPC is set up.

### Project files
- PULL BEFORE CHANGING A .dproj, make the change on the repository's
  file; its `<Platform Condition="'$(Platform)'==''">` and
  `<Config Condition=...>` lines are the owner's and go back as they
  came (zip 275: two zips reset his build to Linux64 and he tested the
  wrong program three times). Say in the delivery that a .dproj is in
  the zip.
- Never run gen_projects.py --force on existing projects; group projects
  are edited by hand; deploy_redist.py edits only its own DeployFile
  entries. A new unit: add it to the .dpr AND the .dproj (DCCReference),
  or say the IDE will.
- The IDE writes "GlobalUseSkia := True;" into a .dpr: never keep it.
- Shell scripts need the executable bit in git (`git update-index
  --chmod=+x`); *.bat are CRLF (.gitattributes), .sh LF.
- The build output folders are ignored (iOSDevice64/, *.dSYM, *.ipa
  since zip 408 - a push once carried 157 MB of iOS output).

### Code
- ASCII-only sources; PasDoc on every declaration.
- NEVER '}' inside a { } comment, NEVER '*)' inside a (* *) comment (no
  "x.*)", no "(see {...})"); a multi-line comment ends at the end of its
  line. pasdoc_check.py catches it (zip 400: "Embedded comments - you
  keep doing this...").
- In a class section every FIELD comes before the first method or
  property: new fields after the last field, new methods (accessors
  too) after the last method (E2169, zips 199, 287). The E2250 "no
  overloaded version of Queue / ForceQueue" errors that follow an
  earlier error are its cascade.
- A unit-level const is visible only BELOW its declaration (put a
  method that uses it after the const block). An array constructor
  cannot be indexed (['A', 'B'][I]): use a typed const. A nested
  function must not share a name with a const or field (Pascal ignores
  case: Rows / ROWS).
- A TThread.Queue / ForceQueue closure copies everything it uses into
  ITS OWN locals first: never a field of an object that may be freed
  before it runs, never a captured variable another closure of the same
  method uses (captured variables are shared). A queued event reads
  its handler into a local before calling it.
- A record built field by field starts as Default(T) (zip 269: a new
  field left unset made menu rows invisible in both programs).
- Never Low, High, TypeOf, AS ... as identifiers.
- In uMain, names Winapi.Windows also has (TBitmap, DeleteFile) are
  written qualified (FMX.Graphics.TBitmap, System.SysUtils.DeleteFile).
  A unit using FMX.Objects writes System.IOUtils.TPath (FMX.Objects has
  a TPath shape). Hints on the owner's compile are cleared in the next
  zip.
- Never build a file name on disk from a path inside a book.
- No absolute paths, user names, machine names or e-mail addresses in
  tracked files (the archive has some from the past - do not add more).

### Product and content
- THE READER needs no TWhisper, whisper.cpp, models or GPU (EpubUnum and,
  on desktops, FFmpegAPI). Output is standard EPUB 3 media overlays.
- Copy-protected books are refused with a clear message; never offer
  DRM removal, never hint how.
- Copyrighted test books (Night Watch, Death's End, The Sword of
  Shannara ...) stay local: never committed, uploaded or quoted; the
  owner sends logs only.
- ONLY CHAPTER MATERIAL IS TIMED OR SCORED: 30 s clear of both ends of
  every LibriVox section (and any recording's start / end).
- Anything that keeps or compares a TIME or a SPEED keeps whisper.cpp's
  version with it and compares within one version (zips 293 - 297).
- THE NAME is written "epubunum" wherever the public reads it (sites,
  READMEs' prose, messages); folders, identifiers and program names are
  not renamed.
- Cloud storage (iCloud, Google) is only ever OPTIONAL - privacy and
  subscriptions (owner 2026-11-27). It must NEVER be possible to run a
  device out of storage (uBookStore: 1 GiB always left).

### Steam builds
- EVERY BUTTON AND KEY MAPPING IS DEFINED VIA STEAM INPUT:
  tools/gen_reader_input.py's tables (never the .vdf files or
  uReaderInput.pas by hand); keys and the pointer are tabled beside the
  actions (MENU_KEYS, MENU_POINTER) and a program asks which ACTION a key
  means - no key named in a program's own code. A table change raises
  LAYOUT_REVISION; an interaction added raises LAYOUT_MAJOR. The reader's
  own FormKeyDown still breaks the rule (open, zip 217).
- EVERY BUTTON IS SHOWN AS STEAM'S GLYPH with a pad and as its KEY with
  the keyboard, in ALL menus (uPadMenu TPadHint / SetHints); never a
  button's letter or name in a text (a PlayStation pad has no A or B).
- A Steam product must NEVER need an outside service or account; the
  sites (link.epubunum.com, the leaderboard) are optional extras.
- A non-Steam build must neither show nor call anything of Steam's (go
  through every SteamRunning / SteamBuild use when the non-Steam version
  is done; SDL3 pad fallback parked until then).

### UI
- A NEW PAGE OR BOX in the builder is WIDE (a share of the window), with
  set column widths, the benchmarks' YELLOW FRAME and a CENTRED title -
  the first time ("Bad layout (again)").
- The pad / touch menu: Left / Right never move the row (TPadMenu.Select
  after a re-show, zip 398); dead rows faded (Dim); TouchStyle buttons on
  phones; text fills the width (no value column when empty).
- A TV: Back never leaves the app (the menu's Exit does), held keys are
  one press, OK held = the menu in the library.

### The websites (web/)
- https://www.epubunum.com, https://leaderboard.epubunum.com,
  https://link.epubunum.com - Plesk, PHP + MySQL; the owner uploads and
  runs SQL in phpMyAdmin. Settings files outside the repository.
- PHP written so tools/test_leaderboard.py / tools/test_link.py run it
  against SQLite (no ON DUPLICATE KEY, no window functions); run them
  before a delivery that touches web/.
- A database change is an ALTER the owner runs BEFORE the PHP that needs
  it is uploaded; it goes in that site's README. The leaderboard's
  `benchmarks` table IS the list of boards - never emptied.
- The boards can be read from a session: WebFetch
  https://leaderboard.epubunum.com/api/board.php?benchmark=benchmark_long_fast&whisper=1.9.6&rows=N
  (cached 15 min per address: change rows= to read again).

## The project

EpubUnum (github.com/WhisperBooks/Epubunum; clones without a key): EPUB
reading and writing for Delphi FMX, and the programs built on it.
Started 2026-11-15. Product line (owner): the END-USER READER is the
main application; EpubBuilder (paid DLC on Steam, planned) makes
read-along books from an EPUB + its audiobook with Whisper; BookManager
moves books between machines and streams them.

Related repositories (each with its own CLAUDE.md): WhisperBooks/TWhisper
(whisper.cpp for Delphi), WhisperBooks/whisper-dev (whisper.cpp builds,
1.9.6; branches 1.9.5 / 1.9.6), G3DGames/TFFMpegAPI and ffmpeg-dev
(FFmpeg), G3DGames/TSteamAPI (Steamworks; the owner's copy is
..\Steamworks).

Rendering: NATIVE WITH SKIA (TEpubView draws lib/Epub.Layout's model).
lib/ compiles with Delphi AND FPC (keep compiler differences in small
{$ifdef FPC} branches); Skia only in fmx/.

### Layout
- `lib/` - framework-free (no FMX / VCL / LCL ever): Epub.Zip
  (EpubStreamOpener hook for Android content:// books), Epub.Xml
  (source positions), Epub.Css, Epub.Layout (THE ONE WALKER: words and
  blocks; never split words anywhere else), Epub.Book (TEpubBook:
  package, overlays, words, CreateHeader, the index SaveIndex /
  CreateIndexed version 3, LayoutCache), Epub.Writer (TEpubWriter:
  media overlays, spans inserted into the source, EPUB 2 -> 3, chapter
  marks, SetCover, written to .tmp then renamed), Epub.Mobi (MOBI ->
  EPUB 3), Epub.Components (TCustomEpub, Adopt).
- `fmx/` - Epub.FMX (TEpubUnum), Epub.FMX.View (TEpubView: lazy layout,
  ShowPreview, DragScroll, fling, two highlights, ChapterBreaks,
  progress footer, one font provider per view - the Linux hang fix),
  Epub.FMX.Reg.
- `packages/` - EpubUnum, EpubUnumFMX (requires Skia.Package.RTL / FMX),
  dclEpubUnumFMX. Group order: runtime, FMX runtime, design, programs.
- `demos/EpubReader` - the reader (desktop, Steam Deck / Big Picture,
  Android phone / tablet / TV, iOS): uMain (everything), uPlayer
  (TReaderPlayer) + uPlayerFFmpeg / uPlayerAndroid (MediaPlayer, JNI) /
  uPlayerIOS (AVPlayer by raw ids), uPadMenu (shared with EpubBuilder),
  uReaderInput (GENERATED), uBookImport (Android SAF folders, PhoneName,
  KeepScreenOn, WifiAwake, IsTelevision), uBookPrep (background
  preparation thread), uBookStore (storage budget), uStreamBook
  (bookmanager://ID/path books read by blocks), uLicences.
- `demos/EpubBuilder` - uBuilder (window, queue, Big Picture pad flow,
  benchmarks, link server), uCalibration (calibration on the clearest
  120 s of a reference text, diagnostics), uHistory (build history and
  estimates), uModels (catalogue, downloads, Core ML encoders),
  uCovers / uCoverPick, uBenchProgress, uMacWindow, EpubBuilder.sh.
- `demos/BookManager` - uManager (window, tabs, Send to phone, serves
  its books to readers), uTransfers (worker, poller), uRoute.
- `demos/EpubConsole` - the command-line tool (--words, --overlay ...).
- `demos/common` - uLink (UDP discovery 47820, HTTP 47821-47830,
  pairing, /books /book /slice /upload /bye, TLinkFinder.Watch for typed
  addresses), uLinkSite (link.epubunum.com client), uDebugLog, uVersion,
  uMachine, uEpubUnum (shared folders), uProgressFrame ("Opening book" /
  "Adding books" frames), uSteam / uSteamPad / uSteamBoard, uWebBoard,
  uGpuPower, uInhibit (keep awake, Game Mode sleep), uQuitSignal,
  uRedraw, uCards (memory cards).
- `tools/` - pasdoc_check, project_check, gen_projects, gen_reader_input
  (needs TSteamAPI's gen_input_mapping.py), deploy_redist (--platform,
  --skip-rocm, --skip-cuda, --media-only), redist.sh / redist.bat,
  postbuild.bat, buildstamp.bat, steam_stage.py, make_icons.py,
  test_leaderboard.py, test_link.py. (make_bookmanager_icon.py is
  replaced by make_icons.py: to delete.)
- `notes/Building-distributions.md` (how every library and file of a
  distribution is made - keep in step), `notes/Windows-on-Arm.md`.
- `media/` - the reference texts (A Scandal in Bohemia = calibration and
  the Short benchmark, A Christmas Carol = Long; the .m4b git-ignored).
- `web/` - www, leaderboard, link (see above).

### Folders the programs use
- Shared: Documents/EpubUnum (Books, Audio, Transcribed, Covers, Queues)
  and one settings folder EpubUnum (%APPDATA% / ~/Library/Application
  Support / ~/.config), uEpubUnum. Steam builds: Books beside the program
  (on the Mac beside the .app).
- Android: everything in Android/data/com.epubunum.reader/files/EpubUnum
  (Books, index, covers, EpubReader.json, EpubReader-debug.log + .old).
  Books folders chosen by the user are read in place (SAF tree).
- iOS: books anywhere in the app's Documents (Files / Finder); the log
  in Library/Application Support/EpubUnum.
- Debug logs: <program>-debug.log beside the settings, the run before as
  .old; capped at 8 MB.

### Platform notes
- LINUX / STEAM RUNTIME 3: the .sh launchers (ICU, FreeType 2.11 beside
  the program first - SLR 3's FreeType crashes Skia, DISABLE_GAMESCOPE_WSI
  for the builder, ROCm hidden when there are no kernels for the GPU);
  FmxLinuxGtkGlobal in the .dpr; FMX's TMainMenu shows first letters
  only on GTK, so the reader draws a TMenuBar; gamescope needs the
  window redrawn after display sleep (uRedraw). In Game Mode Steam's
  sleep is let through (logind delay) and the builder pauses for it.
- macOS: App Nap slowed builds with the display off (NSProcessInfo
  activity under Power = Fastest); Big Picture full screen through Cocoa
  (uMacWindow); the owner codesigns.
- ANDROID: package com.epubunum.reader (owner's manifest template in
  demos/EpubReader, LEANBACK_LAUNCHER + banner for TV,
  usesCleartextTraffic for BookManager's http). Release builds are signed
  with another key than the IDE's debug ones: switching means an
  uninstall (wipes the app's books, pairing, settings). Delphi's Android
  target SDK is below 37 today; at 37 ACCESS_LOCAL_NETWORK must be asked
  for or the link stops. The .dproj asks for permissions the reader does
  not use (location, camera, phone): trim before a store release.
- ANDROID TV (NVIDIA Shield P2897, Android 11): the Shield's "menu"
  button is its Settings button (Android keeps it): OK on the page opens
  the menu, Up from the library's top row too, OK held in the library.
  DPAD_CENTER / MENU are mapped through FMX's key mapping service.
- iOS (learnt in zips 403 - 410, keep):
  - APPLE APIs ARE CALLED BY RAW IDS THROUGH objc_msgSend (dlsym in
    /usr/lib/libobjc.A.dylib), NOT through Delphi's Objective-C bridge:
    through the bridge, and with CMTime by value, every AVPlayer seek
    raised an access violation try/except did not catch. A record over
    16 bytes is passed as a POINTER to a copy (AAPCS64 written out);
    times read by valueForKey: + NSValue getValue:size:; objects as
    Pointer, retained / released by message. Same for every other API
    with structs (lock-screen controls next).
  - Broadcast UDP needs Apple's multicast entitlement; unicast does not.
    Until the Local Network question is answered connections fail with
    "No route to host"; the question makes the app INACTIVE, so the link
    stops only at EnteredBackground (zip 410). Auto-lock would end a
    batch: idleTimerDisabled while the link panel is open.
  - A reinstall moves the app's container: the library drops the old
    path and finds the book again (its reading place is lost).
  - DEBUGGING through PAServer is broken: RUN WITHOUT DEBUGGING. "Can't
    connect to the Mac": restart PAServer (a reboot fixed it once).
  - Provisioning: Xcode's "iOS Team Provisioning Profile: *" PICKED in
    Project > Options > Deployment > Provisioning (Auto pointed at a
    deleted file). Bundle com.epubunum.reader, SDK iPhoneOS27.0, Mac mini
    M4 with PAServer.
  - The 12 iOS build warnings are the owner's global library path (BOSS
    entries), not the project.
  - Files to / from the iPad from the Mac (Finder's Files tab does not
    open the app's folders) - the device's id from `xcrun devicectl list
    devices`:
      xcrun devicectl device copy to --device <id> --domain-type appDataContainer --domain-identifier com.epubunum.reader --source <file> --destination Documents/<name>.epub
      xcrun devicectl device copy from --device <id> --domain-type appDataContainer --domain-identifier com.epubunum.reader --source "Library/Application Support/EpubUnum/EpubReader-debug.log" --destination ~/Desktop/EpubReader-debug.log
    (the log before the app is started again - each start begins a new
    one). The archive's session 18 handover has the owner's device id.

### How the link works (phones, TVs, iPad)
- THE READER STARTS IT: "Get books from BookManager" (main menu, the
  empty library's menu, the Folders menu); it runs only while its panel
  is open (TLinkServer on 47821+, TLinkFinder on 47820, screen kept on,
  low-latency Wi-Fi lock on Android). Ends at Cancel, Done, leaving the
  app, or BookManager's goodbye (POST /bye + a "bye" broadcast).
- BookManager: beacon every 2 s, asks to pair by itself when the chosen
  device is heard unpaired (6-digit code shown on the device); /books +
  /space every 20 s; EPUBs one at a time; the queue held while the
  device's link is off. Pairings persist (the reader's linkId /
  linkTokens; BookManager's [Paired]).
- STREAMING (a TV, and the iPad): BookManager serves its fetch folder to
  paired readers (/books, /book by 512 KB blocks, /slice with HTTP
  ranges for the audio; the token may come as ?token=). The reader's
  library lists them as bookmanager://ID/path, faint "Unavailable" when
  BookManager is away; the audio plays from /slice by URL.
- iOS: no broadcast without the entitlement - BookManager is found by a
  TYPED ADDRESS (asked at "Get books from BookManager", kept as
  "managerHost"; TLinkFinder.Watch asks GET /info every 2 s;
  announcements go unicast to it). BookManager shows its address on the
  Send to phone tab. Bonjour next (below).
- Finding each other: usually 1 - 3 s; ~60 s on the first run of a
  freshly built BookManager.exe (Windows Defender / firewall suspected,
  not proved).

## Where it stands (2026-11-28 11:11, session 19)

- THE REPOSITORY: the owner's last push is 3839834 "iOS Reader - altered
  gitignore" = zips to 408. The working copy = 3839834 + zips 409 - 414
  (uncommitted). Pull before touching a .dproj.
- BUILT AND RUN: Android TV (Shield) to zip 402 - streaming, storage
  limits, local copies first, "Unavailable" confirmed. Pixel 10a phone:
  the link and everything before session 18. iPad (iOS 27.0) with zip
  409: the typed address works, pairing by itself, BookManager's 14
  books in the library with covers, preparation over the network, books
  opened from their index, audio streamed by /slice with seeking - "yeah,
  just tried again + worked. Plays audio. skip etc" (10:59).
- NOT YET BUILT: zip 410 (iOS: inactive does not stop the link,
  idleTimerDisabled, one-line watcher messages), zip 411 ("Adding books"
  frame over the library), zip 412 (this file), zip 413 (the screen kept
  on while a book is read aloud, phones / tablets / TVs).
- EpubBuilder has not been built since uLink changed (zips 354 on): its
  next build is the test that its pairing and sending still work.
- Desktop EpubReader: last seen working 2026-11-26 (7f102d1); desktop
  opens books the old way (window's thread, no index, no staged page) -
  the index and thread are touch builds only until the owner says.

## Next, in this order (owner: "Now iOS then tvOS")
0. FIRST, IN A NEW SESSION: SPLIT uMain (owner 2026-11-28 11:25 "y").
   uMain.pas is 350 KB / 10,200 lines (30 % PasDoc - KEPT: the owner
   asked whether to strip it; no). Delphi cannot spread TfrmMain over
   units, so what moves is what is not the form, in stages, ONE ZIP A
   STAGE, each built by the owner for Win64, Android64 and iOS (and a
   Steam build) and seen to behave the same before the next. NO
   BEHAVIOUR CHANGE in any stage.
   1. Plain routines into units: chapters (MakeChapters, TChapterList,
      Load / SaveChaptersFile - ~15 KB), covers (EnsureCover,
      SaveImageCover, SaveTextCover, SaveCoverFrom, CoverFile - ~8 KB),
      RegisterOpenWith, the small helpers (LibraryTitle, EndsPhrase,
      SafeAudioExtension ...).
   2. TRecentBook, EpubReader.json's reading / writing, RecentIndex,
      SetBookMeta.
   3. The link and streaming as a class the form owns (TReaderLink: the
      link panel, the watcher, StreamLook, the BookManager registry) -
      BEFORE Bonjour, so Bonjour goes in it, not in uMain.
   4. The library grid and the new-book scan (TLibraryView) - the
      biggest and riskiest (many form fields).
   Each new unit: in EpubReader.dpr AND EpubReader.dproj (pull first),
   PasDoc on everything, its IFDEF branches kept exactly. Expected
   uMain ~280 KB after 1 - 2, ~180 - 200 KB after all four.
1. BONJOUR, after stage 3 (owner 10:07 "yes + bonjour"): BookManager advertises
   _epubunum._tcp (Windows' own DnsServiceRegister in dnsapi.dll, Windows
   10 1809+; Linux / macOS later); the iOS reader browses with Apple's C
   dns_sd API (DNSServiceBrowse / Resolve / GetAddrInfo from libSystem -
   plain C, no Objective-C, no delegates; NSBonjourServices =
   _epubunum._tcp in the iOS VerInfo_Keys - a .dproj change) and hands
   what it finds to TLinkFinder.Watch beside the typed address. No
   entitlement needed.
2. Lock-screen / Control Centre controls (MPRemoteCommandCenter,
   MPNowPlayingInfoCenter) - by raw ids.
3. "Open in" (CFBundleDocumentTypes for epub) and the document picker.
4. tvOS: a separate Swift app in a NEW repository, streaming from
   BookManager (500 KB persistent storage there; caches purgeable).
- Then the plan's order: a headless BookManager (activation through
  link.epubunum.com) -> Fire TVs -> Kindle Fire 8 last; the reader free
  + EpubBuilder a paid DLC on Steam (archive: "NEXT PLAN OF ACTION:
  EpubReader free, EpubBuilder a paid DLC"); the two builders
  (benchmark-only and full - ask which form the limited one takes).
- Later: BookManager's index sent ahead of a stream; family / local
  users with pictures and their own lists (owner: "for later on"); place
  sync between devices through BookManager; an interop test with a
  Storyteller-aligned book.

### Reminders for the owner
- THE MULTICAST ENTITLEMENT: the form
  developer.apple.com/contact/request/networking-multicast can be sent
  before alpha (give https://www.epubunum.com as the URL and say why).
  Granted, it needs an EXPLICIT App ID com.epubunum.reader with
  Multicast Networking, a profile made for it by hand, the entitlement
  in demos/EpubReader/Entitlement.TemplateiOS.xml and IOS_BROADCAST :=
  True in uMain. A request has been refused with "use Bonjour instead".
- Before App Store review: take Delphi's unused default usage strings
  (location, contacts, camera ...) out of the iOS VerInfo_Keys.
- Before anything goes on a store page under a feature name ("Recito" is
  the favourite, archive: "A NAME FOR THE FEATURE"): the UK IPO search,
  classes 9 and 41.

### Open, the owner's to decide or answer
- ABOUT_COPYRIGHT is a placeholder; the repository has no licence file;
  Skia4Delphi's exact copyright line to check; Android libraries' Apache
  2.0 given as a notice, not the full text.
- The .dproj version info is not 0.0.N yet.
- The reader's page keys under the Steam Input rule (zip 217).
- Offered, not taken up: the ISBN lookup (Open Library); a "remove from
  library" on the phone; a narrower indent in a narrow column; the
  Defender exclusion test; the website's boards inside the program;
  names on the leaderboard (three tiers, archive zip 284); one speed for
  listening and another for read-along.

### Known, not done
- The desktop copies a book's audio out at the first Play (FFmpeg's
  subfile protocol could play it in place); "library: layout" 50 times
  in a row on the desktop.
- Compressed audio inside a book is copied out in the window's thread
  (phones).
- The library is shown twice at every start and twice per book received.
- gen_projects.py writes no Android64 group.
- EpubBuilder still calls EpubUnumMove.
- The calibration log says "no graphics card here could run it" when
  the CPU is simply fastest (Mac).
- uInhibit takes desktop Big Picture (SteamGamepadUI=1) for Game Mode.
- TWhisper's aligner front / back edges (a lone match at the book's
  edges; archive Later tests 6).

## Session 19 (2026-11-28 09:58 -)
- 09:58 "pull + continue"; 10:01 the multicast entitlement looked up;
  10:07 "yes + bonjour".
- Zip 409: BookManager on the iPad by a typed address (uLink Watch,
  TLinkWatcher, Broadcasting, LinkPrimaryAddress; uMain AskManagerHost;
  BookManager shows its address). Works (logs 10:51, 10:59).
- Zip 410: iOS's own questions no longer end the link (WillBecomeInactive
  saves only; idleTimerDisabled by raw objc_msgSend; the watcher's
  message on one line with a Local Network hint; no empty "link: " lines).
- Zip 411: "Adding books" over the library while new books are read in
  (owner 11:04: "only required on Library screen as if updated while
  reading the user won't even be aware") - FScanProgress / ScanFrame in
  uMain; keys and taps wait for it, as for "Opening book".
- Zip 412: this file. The old CLAUDE.md is archive/CLAUDE.001, unchanged
  (owner 11:09 asked why the conversation keeps being compacted: the 850
  KB CLAUDE.md was loaded in full every session).

- 11:16 "After some minutes the iPad screen blanks and you have to wake
  it up again. The audio keeps playing but you can't see the text and
  highlighting": zip 413 (below).

## Zip 413 (on top of zip 412): the screen kept on while a book is read aloud
NOT COMPILED. NO PACKAGE REBUILD; no .dproj. Files:
demos/EpubReader/src/uMain.pas, demos/EpubReader/README.md,
demos/common/uVersion.pas (413), CLAUDE.md.
- uInhibit's ikDisplay (held while FPlaying, desktops) does nothing on
  Android / iOS; only the link panel called uBookImport.KeepScreenOn.
- UpdateScreenOn (uMain): a touch build keeps the screen on while
  FPlaying OR the link panel is open (FLink), else the system's timeout;
  called from UpdateControls (every play / pause goes through it) and
  StartLinkServer / StopLink (which called KeepScreenOn themselves - and
  StopLink's False would have let the screen go off mid-book). FScreenKept
  so KeepScreenOn is called only on a change. Log: "screen: kept on
  (reading aloud)" / "(the link panel)" / "the system's own timeout
  again".
- Android phones and TVs get it too (FLAG_KEEP_SCREEN_ON; on a TV the
  screensaver waited for no one either). Paused: auto-lock as usual.

- 11:23 "is it possible to make uMain smaller ... Basically a refactor"
  - the four stages above; 11:25 "y" (in a new session, after zips 409 -
  414 are pushed; stage 3 before Bonjour). Zip 414: this note only.

Last number used: 414
