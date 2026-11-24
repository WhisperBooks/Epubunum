# CLAUDE.md - working rules for this repository

Read README.md first, then this file. Keep both up to date with every change.
The rules follow TWhisper's and TFFMpegAPI's CLAUDE.md (same owner, same
conventions); where this file is silent, theirs apply.

## Handover - READ THIS FIRST (latest: session 14, 2026-11-23 21:21)

Written at the owner's request (21:21: "write up a session handover in
claude.md"). Session 14 ran from 2026-11-22 18:30 to 2026-11-23 21:21:
zips 258 - 281 here (281 = this handover, CLAUDE.md only). Each zip has
its own section further down ("Zip 280" first, newest first). The
session's running log, entry by entry with the owner's words, is
"Session 14 - the log" inside the session 13 handover below; this is
the map. Sessions 13 and earlier: their handovers follow.

### Where it stands (2026-11-23 21:21)
- THE REPOSITORY: the owner's last push seen is 1310cf6 "External
  leaderboard" (18:05; zips to 274). This working copy = 1310cf6 + zips
  275 - 281. Never commit or push, never offer to.
- STEAM: the build deployed holds zips to 278 (the logs of 20:21 say
  "median" and read AMD's power). Zip 280's program side is NOT built;
  the owner: "No rush to do another steam deployment - it takes a
  while" - BATCH what needs a build (list below), keep site-only
  changes apart.
- THE THREE SITES are up, HTTPS, Plesk, PHP + MySQL:
  https://www.epubunum.com (web/www/index.html, zip 271 / 277),
  https://leaderboard.epubunum.com (web/leaderboard, zips 272 - 280),
  https://link.epubunum.com (web/link, zip 282 - written and tested
  here, NOT UPLOADED: the page there is still Plesk's default).
  The owner uploads the files himself and runs SQL in phpMyAdmin
  (database "epubunum"). The site's settings are in a file outside
  the repository (web/leaderboard/README.md).
- THE BOARDS CAN BE READ FROM A SESSION: WebFetch
  https://leaderboard.epubunum.com/api/board.php?benchmark=
  benchmark_long_fast&rows=N (the four slugs: benchmark_short_fast,
  _short_detailed, _long_fast, _long_detailed). The fetch is cached by
  address for a quarter of an hour: change rows= to read again. The
  owner prefers this to sending screenshots ("you can look at board
  yourself - otherwise its 4x grabs"); of a log he pastes the tail from
  the last "Score -" line.

### What session 14 made (in the order of its use)
1. STEAM'S LEADERBOARDS for the four benchmarks (uSteamBoard; zips
   261, 263 - 270): on by default (Settings > Leaderboard), no question
   asked; Benchmark > Leaderboards (top item) shows a board 95 % of the
   window, four columns, the user's row yellow, left / right = top or
   around you. WORKS on all seven machines, one Steam account each.
2. THE WEBSITE'S LEADERBOARD (zips 272 - 280): a row is a MACHINE's
   best run. Server: register.php (an install's random id -> a key),
   submit.php (rate limits, plausibility, 'pending' above 400x),
   board.php (JSON), index.php (the page). Client: uWebBoard - every
   build, Steam or not, sends each score when Settings > Leaderboard
   is Yes ("yes send to both"); ANONYMOUS, no name and no Steam id
   ("for now anonymous is fine"). WORKS: five machines on the site.
3. THE CARD'S POWER with a score (uGpuPower; zips 274, 276, 278): read
   once a second for the whole benchmark, the MEDIAN ("median then"),
   the highest, and the limit the card is held to; logged ("GPU power
   - ..."), sent (avg_watts holds the median - the name stayed),
   shown ("116 W of 175"). NVIDIA on Windows and Linux (NVML), AMD on
   Linux (the kernel's hwmon files). ALL CONFIRMED UNDER STEAM,
   Steam's Linux container included.
4. The System column (zip 279) and the host's name for it (zip 280).
5. The landing page (zip 271); the name written "epubunum" (zip 277).
6. Before those: Run all N benchmarks and the introduction's timing
   (258), BookManager's Dark mode (259), base by itself when turbo is
   too slow, F5 / F6, the old settings page gone (260), Calibration
   results as a page (262), no pad or keys during a benchmark (269).

### What the power readings showed (owner's machines, 2026-11-23)
- The 5090 laptop's OWN power profile (the maker's - not Windows', not
  the program's Power setting) is the card's limit: low ~92 W, medium
  ~120 W, high 175 W. The detailed model wants ~115 W, the fast one
  ~67 W: medium = high within 2 %, low costs 45 - 65 % (the fast model
  too: the processor is held back as well, unseen). The limit drifts
  within a profile and the highest readings pass it (it is read once,
  at a benchmark's start - offered to read it each second: no answer).
- Long Text, Detailed / Fast, best runs on the site: 5090 2:06.2 at
  116 W of 175 / 1:55.5 at 69 W; Steam Machine 5:23.8 at 62 W of 110 /
  2:59.6 at 35 W; Ally 12:20.2 at 31 W, no limit / 4:32.3 at 21 W;
  GTX 1650 (Linux) 13:18.3 at 51 W of 85 / 4:12.0 at 29 W; Deck
  26:02.8 at 15 W of 15 / 8:58.3 at 5 W of 15.
- The Deck's detailed runs sit AT its 15 W cap (its slider was at the
  maximum). The Deck's 5 W on the fast model is less than "the whole
  chip" should draw: what an APU's file measures is NOT SURE - the
  site's footer and the README say "the whole chip's"; soften when
  known. The Ally has no cap in the driver's files (its power control
  is ASUS's own).
- dGPU-only mode on the 5090 (a reboot): the builder calibrates again
  (the device list changed - right); nothing gained beyond noise.

### Standing rules added in session 14 (also in their zips' sections)
- A NEW PAGE OR BOX in the builder is WIDE (a share of the window),
  with set column widths, the benchmarks' YELLOW frame and a CENTRED
  title - the first time ("Bad layout (again)", zip 265).
- A record built field by field starts as Default(T) (zip 269: a new
  field left unset made menu rows invisible in both programs).
- PULL BEFORE CHANGING A .dproj; its line <Platform Condition=...> is
  the owner's and goes back as it came; say in the delivery that a
  .dproj is in the zip (zip 275: two zips reset his build to Linux64
  and he tested the wrong program three times). The debug log's second
  line "Build:" tells which build ran.
- THE NAME IS "epubunum" where the public reads it (the sites, the
  READMEs) - "Only care about publically visible versions - for
  consistency (may change again later)". Folders, identifiers and the
  programs' names are not renamed.
- THE SITE'S TABLE `benchmarks` IS THE LIST OF BOARDS - never emptied.
  To empty the boards: DELETE FROM bests; DELETE FROM runs; (and for a
  clean slate devices, machines, players, in that order).
- A database change is an ALTER TABLE the owner runs BEFORE the PHP
  that needs it is uploaded; it goes in web/leaderboard/README.md.
- The site's PHP is written so that tools/test_leaderboard.py can run
  it against SQLite (no ON DUPLICATE KEY, no window functions); run it
  before a delivery that touches web/leaderboard.
- When "nothing arrives": first ask which build ran and whether the
  zip is in the folder - before looking for a fault.

### Waiting for the next Steam deployment (needs a build)
- Zip 280: Linux machines say "SteamOS 3.x" / "Ubuntu 24.04", not
  "Steam Runtime 3" (the host's os-release at /run/host - NOT SEEN TO
  WORK). submit.php of zip 280 can be uploaded at any time.
- Zip 275's four hints (compiled? not said) and zip 277's two message
  texts.
- Zips 284 - 286 (session 15): the link site in EpubBuilder - uLink's
  /pair/ticket, --activate, Settings > Account (the code in the window
  and in Big Picture). The owner deploys after 286.
- Zips 290, 291, 293 - 299: Open in browser, the window without the log,
  whisper.cpp's version in scores and calibrations (293 BEFORE or WITH
  the first build that ships 1.9.6's libraries).
- Zips 301 - 303 (machine facts, menu texts), 306 (Windows' P and E cores), 304 (Steam's overlay is
  given frames: BUILDER AND READER; a benchmark with and without
  Steam's frame counter to compare), 305 (Big Picture's menu stays).
- Add here whatever else needs a build, and say so in the delivery.

### Not confirmed by the owner
- Zips 258 - 260 and 262 in full (the Calibration results page was
  seen working at 18:25 in two screenshots; 259's Dark mode not said).
- Zip 269's "no pad or keys during a benchmark": in Big Picture
  nothing but quitting stops a benchmark now - a held button was
  offered, no answer.
- Zip 275 (the hints; three site files and .gitignore the repository
  lacked; tools/leaderboard_schema.sql still to DELETE there).
- Zip 277 on the sites; zip 280.
- The landing page's claims to check: "in testing on Steam", the
  platforms, "99 words in 100".
- The old calibration page seen under the new one on Linux (session
  14's start): cause not found; zip 258 avoids making it.

### Decided, not to be raised again
- Apple's GPU power is NOT read (19:48: "OK, forget Apple").
- No consent question for the leaderboards: on by default.
- The website's validation is version 1 as built (the owner said
  "TBD" and used it); Steam ids are not sent, so nothing to verify.

### Session 15 (2026-11-24 06:38 -) - the log
- 06:38 the owner gave the repository's address (it clones without a
  key now: PUBLIC - "Project" below still says PRIVATE; asked, no
  answer yet), "Read CLAUDE.md", then "link" = item 2 of Next.
  Three questions asked and answered: sign-in by an EMAIL LINK (not
  Steam's); an install without a screen joins by a ONE-TIME KEY FROM
  THE SITE (not a mailed approval); version 1 is ACTIVATION ONLY (the
  site keeps no addresses; finding stays the local network's). Zip 282
  = the site. Next for it: the shared unit beside uLink, then
  BookServer (see "Zip 282").

- 09:10 - 09:12, PARKED (owner): "Is it possible to write a joypad
  fallback system for non-Steam big picture builds?" - yes: a second
  implementation behind uSteamPad's interface (Poll, Origin, PadName),
  the default buttons in the generator's tables beside the keys, its
  own glyphs for each pad family (Steam's come from Steam at run
  time), and a way into Big Picture without Steam (FBigPicture is
  SteamBigPicture today). Offered native backends or SDL3; owner:
  "Yeah, I was thinking SDL3 as well. This is for Builder and Reader
  but not until Steam is done". So: SDL3 (one more library per
  platform to redistribute), EpubBuilder and EpubReader, AFTER the
  Steam work - not to be started or raised before then. Not carried
  over from Steam Input: rebinding, the Deck's back paddles and
  trackpads, gyro.

- 16:47, A NOTE FOR THE NON-STEAM VERSION (owner, after zip 303):
  "This option [Steam leaderboards], of course, should only appear on
  Steam version. Same for using any Steam related function. We're
  doing Steam ATM so this is a note for when we do the non-Steam
  version". AS IT IS NOW (looked at, zip 303's source): the menu
  item, the pad's row and the page are made only when SteamRunning;
  uSteam's functions do nothing outside a STEAMBUILD
  (SteamOpenWebPage answers False); "Website leaderboards" is offered
  everywhere but in a Big Picture without Steam. WHEN THE NON-STEAM
  VERSION IS DONE: go through every SteamRunning / SteamBuild use and
  every text that names Steam (the log's lines, the README), with
  the SDL3 pad fallback (parked above) - a non-Steam build must
  neither show nor call anything of Steam's.

### Next (the owner's word decides the order)
1. AMD's power ON WINDOWS - when Windows is on the Steam Machine
   ("probably next week"; then the Deck and the Ally "if things go
   well"). Needs AMD's ADL / ADLX library; read its header first.
2. link.epubunum.com: ONE activation scheme for every install without
   a screen (BookServer, a headless BookManager, a headless
   EpubBuilder, the Apple TV) - THE SITE IS ZIP 282 (to upload; its
   schema and its mail not tried on the host). Then the programs'
   side: a shared unit beside uLink (System.Net.HttpClient: register,
   claim / code + status, ticket, check, release), uLink's
   /pair/ticket, --activate; then BookServer; then the Apple TV
   reader (native Swift).
3. Offered, no answer: the website's boards inside the program (its
   Leaderboards page shows Steam's only - a non-Steam build has none);
   names on the site; the limit read each second; an in-app "save a
   picture of this window"; the build stamp where it is seen before a
   run; 25 rows on a board.
4. STILL FROM SESSION 13's LIST: step 5, the two builders (benchmark-
   only and the full one behind the DLC) - ASK which form the limited
   one takes; the Mac's "no graphics card" line; uInhibit.

## Handover (session 13, 2026-11-22 18:13)

Written at the owner's request (18:13: "OK, this is getting better.
Write up progress in CLAUDE.md so I can start a new session"). Session 13
ran from 09:30 to 18:13 on 2026-11-22: zips 227 - 256 here and
TWhisper-32. Each zip has its own section further down ("Zip 256" first,
newest first); this is the map. Session 13's task list follows this
handover, with its steps.

### Session 14 - the log (2026-11-22 18:30 - 2026-11-23 21:21; its handover is above)
- PUSHED: 6f7515b "Handover" (all zips to 257 applied, owner 19:57).
- Zip 258 (see its section): Run all N benchmarks, the introduction
  only once the window has its size, the estimate tuned on six
  machines' logs. NOT COMPILED.
- Reported working by the owner: 256, 249, 247, 207, BookManager from
  the Mac. Not reported: 253 (the reader's library).
- Zip 259: BookManager's Dark mode (a check box; written unseen). NOT
  COMPILED.
- Zip 260: base by itself when the chosen model is too slow (Next 3
  below: DONE); Menu F5, Queue F6 (layout revision 2.5, STEAM REBUILD);
  installed models before the others; the window's old settings page
  and zip 223's hidden menus removed. NOT COMPILED.
- Settled by the owner (01:08): touch in the pad menu works; the
  benchmark audio is in the depot; 960 is resolved; Q for the queue.
- Zip 261: the benchmarks' Steam leaderboards (step 4; owner 01:18
  "leaderboards before benchmark mode"; new unit uSteamBoard). Three of
  its four choices were ASSUMED (best score kept, asked once, place +
  top ten) - "asked once" was changed in zip 263. NOT COMPILED.
- Zip 262: Settings > Calibration results opens the results page.
- Zip 263: the leaderboard is not asked about - on by default, Settings
  > Leaderboard turns it off.
- APPLE TV (owner 03:56; the plan is "THEN,
  HIGH PRIORITY: an Apple TV (tvOS) player" below - still native Swift,
  Delphi has no tvOS target): "We want an Apple TV (box) version of
  Reader. This will rely on a Server to take an ebook that streams the
  content to the Apple TV. Apple TVs have very low memory allowances so
  I'm not sure an entire epub minus audio would fit." SAID TO THE OWNER
  (checked 2026-11-23, Apple's tvOS programming guide): the low
  allowance is PERSISTENT STORAGE - 500 KB (NSUserDefaults), everything
  else a cache the system may purge when the app is not running - not
  working memory; a book's text and word timings are small (A Christmas
  Carol: 31,847 words, 28,556 clips - well under 1 MB as compact data)
  and fit in memory, but need not: the server sends a chapter at a
  time (text + timings) and the chapter's audio by HTTP range requests,
  the TV keeps only the pairing and where each book was left.
  DECIDED (owner 04:00): the server is a program on the user's own
  network - "similar to BookManager but also available headless" - not
  a hosted site. So: a new program (suggested: demos/BookServer, not a
  Steam program, as BookManager) on uLink's discovery, pairing and
  tokens, serving a folder of built books: the library, a book's
  chapters, a chapter's text + word timings, a chapter's audio with
  HTTP ranges, the cover; with a window, and the same without one.
  OPEN: how a HEADLESS server pairs (it cannot show the 6-digit code -
  "TENTATIVE: a headless EpubBuilder" below: the owner turned down the
  log / approve-from-a-paired-client options and kept email and an
  activation website as tentative; with a TV the code could be shown
  ON THE TV and typed nowhere - not discussed yet); the decisions in
  the tvOS plan below. NOT BUILT.
  DECIDED (owner 04:05): the name is BookServer; HEADLESS PAIRING BY AN
  ACTIVATION WEBSITE ("Once epubunum.com is online we can use that for
  activation. An activation server will have extremely low usage so
  this is not a concern"), on a subdomain of its own, e.g.
  link.epubunum.com (the owner typed "link.epubumum.com": taken as a
  slip - confirm when it exists). That is IDEA B of "TENTATIVE: a
  headless EpubBuilder" below, no longer tentative for BookServer. The
  constraint there stands: the STEAM programs never need an outside
  site - their on-screen code stays; activation is for the non-Steam
  BookServer (and optional elsewhere). Waits for the domain.
  Owner 04:08: the link subdomain "is now also waiting for DNS (can
  take a day or two). All domains will be https" - written
  "link.epubumum.com" a second time; owner 04:08: "Typo
  link.epubunum.com". THE HOSTS: https://link.epubunum.com (activation)
  and https://leaderboard.epubunum.com (our leaderboard).
  Owner 04:10: "When the link website is up it could also handle
  headless BookManager authentication" - so ONE activation scheme for
  every install that has no screen or wants no code: BookServer, a
  headless BookManager, the headless EpubBuilder of the tentative note
  (non-Steam), the Apple TV. Design it once, in a shared unit (beside
  uLink); the on-screen code remains for the rest. TBD with the site. HTTPS from Delphi: System.Net.HttpClient (the
  system's TLS, no OpenSSL to ship) - not Indy.
- THE SITES ARE UP (owner 2026-11-23 16:13): https://link.epubunum.com, https://leaderboard.epubunum.com,
  https://www.epubunum.com (= epubunum.com) - "all are https enabled and
  currently have a default holding page. The deployed language is PHP
  and MySQL can be provided". Looked at 16:14: each answers with Plesk's
  "Domain Default page". So the hosting is Plesk; PHP + MySQL. The "do
  not build until the site is up" below is lifted, but WHAT to build
  first and the validation are still the owner's to say - asked.
- (SUPERSEDED by zip 272 - kept for its reasoning:) ALL OF THE WEBSITE
  LEADERBOARD IS TBD (owner 03:51: "Mark everything
  as TBD - it'll take a while for the website to come up"): the site,
  the PHP endpoint, the validation, and the draft MySQL schema written
  at 03:47 (asked: "Can we design a MySQL database schema"). The draft
  is tools/leaderboard_schema.sql (zip 269; marked TBD at its top;
  never run): benchmarks, players, machines (a random install id -
  the machine is what is ranked), devices, runs (every submission;
  status / verified for whatever validation is chosen), bests (the
  board). Open with it: how a non-Steam user claims several machines;
  a row per machine or per person; Steam users tied by Steam id. DO
  NOT BUILD any of it until the owner says the site is up.
- PLANNED, NOT BUILT (owner 03:39): OUR
  OWN LEADERBOARD at https://leaderboard.epubunum.com (waiting for DNS)
  beside Steam's - "Submissions can be via POST to a PHP endpoint on
  the website. As this will allow both Steam and non-Steam we'll need
  some validation of some kind (TBD)". Nothing to build until the site
  is live and the validation is decided; said to the owner: what a
  submission could carry (benchmarks.csv's fields, a per-install id, no
  machine or user name), and that a client cannot prove a time - the
  choices are a Steam ticket checked by the server (Steam users), a
  per-install key with rate limits and plausibility checks, and the
  run's log kept for the top rows.
- PLANNED, NOT BUILT (owner 01:32): "For
  multiple machines we can have our own website once leaderboards is
  tested" - Steam's boards stay one row per user (best score); a site
  of ours would list every machine of a user. Not before the Steam
  leaderboards have been tested. benchmarks.csv already has each run
  (no machine or user name).
- Zip 264: Leaderboards is the Benchmark menu's top item.
- THE LEADERBOARDS WORK (owner's screenshot 02:27, the 5090 and the
  Miix on Short Text, Fast Model). Zip 265: their page 95 % wide, three
  columns 40 / 10 / 50, yellow frame, centred name (uPadMenu: STEAM
  REBUILD).
- Zip 266: the user's own row of a leaderboard in the frame's yellow
  (265 compiled and ran: screenshot 03:15).
- Zip 267: the place is a column of its own (four columns), room for
  seven digits; the user's row under the top ten has its device.
- Zip 268: the leaderboard's page is 95 % of the window wide and high
  and shows the rows that fit; left / right: top or around you.
- Zip 269: zip 266 left menu rows unseen (TPadMenuItem.Color not set
  by TPadMenu.Item) - put right; no pad or keys while a benchmark runs.
- Zip 270: the leaderboard's devices no longer cut short on the Deck
  (268 and 269 compiled and ran: the Deck's screenshot, 06:46).
- Zip 271: the landing page of www.epubunum.com (web/www/index.html).
- Zip 272: the leaderboard site's server side (web/leaderboard: PHP +
  MySQL; tested here against SQLite, not on the server). NEXT ON THE
  SITES: the owner puts 271 and 272 up and says how the import went;
  then EpubBuilder's side of the leaderboard; then link.epubunum.com.
- BOTH SITES ARE UP (owner 16:42; the board's API read from here).
- Zip 273: EpubBuilder sends each score to the website too (uWebBoard;
  every build; anonymous). WAITS FOR: a benchmark on any machine and the
  row on the site. Then: link.epubunum.com, or the boards read from the
  site inside the program, or names - the owner's word.
- ZIP 273 WORKS (owner 17:34). Zip 274: an NVIDIA card's power read
  during a benchmark (uGpuPower), logged, sent, shown on the site.
  WAITS FOR: the ALTER TABLE, the upload, a low and a high run on the
  5090 laptop - does "GPU power" appear and does the limit differ?
- Zip 275: EpubBuilder.dproj back on Win64 (zips 273 / 274 had reset
  it to Linux64 - PULL BEFORE TOUCHING A .dproj, its Platform line is
  the owner's) and four compiler hints.
- Zip 276: the power sent is the median of the readings (the field is
  still avg_watts). ZIP 274 WORKS. Still open: does the limit (175 W)
  move with the laptop's low profile?
- Zip 277: THE NAME IS WRITTEN "epubunum" WHEREVER A USER READS IT
  (sites, messages, READMEs' prose); folders and identifiers are not
  renamed.
- Zip 278: AMD cards' power on Linux (the kernel's hwmon files). THE
  5090's PROFILES ARE THE CARD'S LIMIT: ~92 / 120 / 175 W. WAITS FOR:
  the 1650 under Steam on Linux; a "GPU power" line on the Steam
  Machine, the Deck or the Ally.
- ZIP 278 WORKS (1650 on Linux, Ally, Steam Machine). Zip 279: the
  System column on the site. Apple's power: NOT TO BE DONE. AMD on
  Windows: when the owner has Windows on the Steam Machine.
- Zip 280: the system sent is the HOST's (Linux under Steam said
  "Steam Runtime 3"), with every score. WAITS FOR: a Linux run - does
  the site say SteamOS / Ubuntu?
- ZIP 270 COMPILED AND RAN (owner 13:27, four screenshots, the desktop
  window on the 5090): all four boards
  hold the seven machines, one Steam account each; no device cut short;
  the foot reads "Left Right around you / Esc back". The boards (s):
  Short Fast 27.0 / 38.6 / 47.2 / 57.3 / 75.5 / 128.0 / 400.9; Short
  Detailed 35.4 / 88.9 / 116.3 / 209.4 / 215.2 / 428.9 / 3933.3; Long
  Fast 119.4 / 155.1 / 180.0 / 252.0 / 304.9 / 539.6 / 1693.6; Long
  Detailed 125.4 / 323.2 / 428.4 / 774.8 / 797.4 / 1563.3 / 15832.3
  (5090, then by place: M4 / Steam Machine / GTX 1650 / Ally / Deck /
  Miix on Fast; Steam Machine / M4 / Ally / GTX 1650 / Deck / Miix on
  Detailed). The Ally's runs are 5 - 11 % slower than the day before's.
- THE MIIX'S BENCHMARKS (owner 02:51, build 65569dc, UHD 620 Vulkan,
  lowest speed set to 0.4): Short Fast
  7:53.060 (6.8x), Short Detailed 1:10:18.215 (0.76x), Long Fast
  28:28.723 (6.5x), Long Detailed 4:25:07.019 (0.70x); words matched
  98.4 / 99.6 / 98.1 / 99.1 %. Calibration: base 8.8x, turbo 0.71x - a
  whole book ran at 0.73 - 0.77 of the calibration for base and 0.97 -
  1.0 for turbo (HISTORY_BOOK_RATIO_CONTINUOUS is 1.0). All seven
  machines, both texts together, turbo / base: monster 91.0 / 102.5x,
  steam machine 35.2 / 62.7, mac 25.8 / 73.5, ally 15.4 / 42.1, ideapad
  14.2 / 46.4, deck 7.2 / 21.5, Miix 0.71 / 6.6.
- NEXT: the owner's word on 258 - 260, 262, 270 and the Miix's results; then step
  5 (the two builders - ask which form the limited one takes) and what
  is left of "Next" 5 below (the Mac's "no graphics card" line,
  uInhibit).

### Where it stands
- LAST NUMBER USED: 281 (Epubunum; 257 = this handover, CLAUDE.md
  only; 258 - 280 = session 14; 281 = session 14's handover), 32 (TWhisper). Never commit or push,
  and never offer to; the owner applies the zips and pushes.
- PUSH STATE: not told this session. The owner's builds said "Build:
  2026-11-22 17:27, 65569dc" (commit 65569dc + the zips applied on top).
  At the start of the next session ask what is pushed, then compare the
  pushed files with the zips (a scratch clone, CRLF / BOM aside).
- COMPILED AND RUN BY THE OWNER (Windows MONSTER - Core Ultra 9 275HX,
  RTX 5090 Laptop on Vulkan0, Intel(R) Graphics on Vulkan1; the Miix;
  the Ally): everything up to zip 255 (the 17:27 build showed 254 + 255's
  calibration page, so TWhisper-32 and zip 248 compiled too). Seen
  working: the reference texts and the calibration (method 2, 120 s),
  the Benchmark menu and its bars and results, the glyph feet, the
  estimates ("a lot better now" after 241), the start-up calibration
  and its bars, the calibration page with a pad (A / B pictures) and,
  after a key press, at full size.
- DELIVERED, NOT YET REPORTED ON: 256 (the calibration page laid out
  again when the window grows - the start-up page was narrow with its
  answers out of sight; keys on the left with the keyboard); 253 (the
  reader picks up Transcribed's books - the Ally's empty library); 249
  (Settings > Lowest acceptable speed); 251's results table and 252's
  "better estimates" line; 248's moving calibration bars; 247 (macOS Big
  Picture full screen through Cocoa - Mac only).
- PACKAGE REBUILD: TWhisper-32 changed Whisper.Core's interface
  (TWhisperBenchmark.OnProgress): WhisperAPI, WhisperAPIFMX,
  dclWhisperAPIFMX, then EpubBuilder / WhisperConsole. Apparently done
  (the 17:27 build). STEAM REBUILD: 254 - 256 changed uPadMenu (the
  reader's too) - build and deploy both programs.

### The zips of session 13 (one line each; the detail in their sections)
- 227 Aladdin out, the reference texts in (uCalibration.REFERENCE_TEXTS:
  Scandal = calibration and the Short benchmark, Carol = Long). 228
  media/ deployed from the repository (deploy_redist.py --media-only,
  redist.sh, postbuild.bat). 229 the clearest 30 s (superseded by 242).
- 230 - 236 the benchmarks: Benchmark menu of five (Run all 4, Short /
  Long x Fast (base) / Detailed (turbo)), each with its expected time;
  the score = the middle third of each section's transcription time,
  H:MM:SS.mmm; a framed progress block per benchmark (uBenchProgress);
  keeping the book: No by default; benchmarks.csv silent (for the
  leaderboard - not to be mentioned to users).
- 237 Results table, X / H hides it. 238 dark before the first frame.
  239 names "Short Text, Fast Model". 240 every menu's foot as Steam's
  glyphs or the keys (standing rule). 241 the estimates compare like
  with like (same model, same kind of calibration).
- 242 step 2: the calibration times the clearest 120 s in one run
  ([Calibration] Method=2, Seconds per model; history calibration_s).
  243 calibrated at start-up with no dialog; 244 calibration progress
  bars, new models calibrate themselves, "Re-calibrate"; 245 the main
  menu after it; 246 at most four blocks (scrolling, "Model k of N").
- 247 macOS Big Picture full screen via Cocoa (uMacWindow, builder
  only). 248 + TWhisper-32 calibration bars move within a device
  (loading / warming up / timing). 249 Settings > Lowest acceptable speed
  (2.0x default, 0.0 - 2.0 by 0.1; too-slow models / devices refused for
  builds, the queue and the benchmarks). 250 blocks 95 % wide.
- 251 Calibration results after a calibration: base / turbo speeds and
  a dozen LibriVox books' times (lengths from LibriVox's API; War and
  Peace = Books 01 - 17, 64:36:04), bold "A ROUGH GUIDE ONLY" line;
  any button / key / click goes on. 252 the "better estimates once you
  have transcribed a few books" line; the CALIBRATION PAGE before the
  start-up calibration (why, devices found, estimated time, warning when
  long; A "Calibrate now" / B "Come back when I have more time to spare"
  = close the program).
- 253 the READER's library picks up EpubBuilder's Transcribed books not
  seen before ("seen" in EpubReader.json).
- 254 better guesses for the estimate (GuessSpeed: CPU threads / 16 x
  generation, RTX 30+ 40x, Intel UHD 0.7x / Iris 2x / newer 6x ...),
  uPadMenu.NextWidthShare, A / B pictures on the page's answers. 255 the
  page 60 % wide (owner: not 80 %); a question's text measured with
  room to spare. 256 the page laid out again on resize (tmIntro);
  TPadMenuItem.Key - a key's name in the picture column.

### Standing rules added in session 13 (also in their zips' sections)
- Buttons are shown as Steam's glyphs when a pad is in use and as the
  key's name when the keyboard is - in ALL menus, pictures and key names
  on the left; never a button's letter or name written into text (a
  PlayStation pad has no A or B). "Press any button" is fine.
- Only chapter material is timed or scored: 30 s clear of both ends of
  every LibriVox section.
- The leaderboard (step 4): built in zip 261 (session 14); it may be
  mentioned to users now.
- Deliveries: EpubUnum-NN-topic.zip, files changed since the previous zip,
  paths from the repository root, on top of the previous zip; "NO
  PACKAGE REBUILD" or the package banner; the Steam banner only when a
  unit another Steam program compiles changes (demos/common, uPadMenu,
  uReaderInput, uCovers ...), Steam Input or staged files.

### Next
1. Ask what is pushed and whether 256 fixed the start-up page (and 253:
   the Ally's library; 249's setting; the Mac's full screen, 247).
2. Calibration estimate: compare the debug log's "calibration: guessed
   ..." lines and "the introduction's estimate" with "Calibration took"
   on each machine; tune GuessSpeed. HISTORY_BOOK_RATIO_CONTINUOUS (1.0,
   the first estimate's ratio for the new calibration) is still to be
   measured against real builds.
3. OFFERED, NOT ASKED FOR: when the chosen model is below the lowest
   acceptable speed and base is not (the Miix: turbo 0.6x), switch to
   base by itself after the start-up calibration (now Create refuses
   and says why).
4. Step 5 of the task list: the two builders (benchmark-only, and the
   full one behind the DLC). Step 4 (the leaderboard) waits for the
   owner.
5. Still open from before: the calibration log's "no graphics card here
   could run it" when the CPU is fastest (Mac); uInhibit taking desktop
   Big Picture for Game Mode; touch in the pad menu; zip 207's redraw
   after display sleep (Windows).

## Session 13's task list (owner, 2026-11-22 09:30) - statuses in the handover above

Owner: "the next task will be to replace Aladdin with the new book
options so we can build the benchmark functionality which will include
calibration via the new recordings. There will be a limited version of
Builder that only includes Benchmark functionality and benchmarks will
build a leaderboard. The full version will be DLC-enabled and include
all functionality."

(The statuses below are as at 11:34; the handover above is current: steps
1 - 3 are built and ran, step 4 is on hold, step 5 is next.)
WHERE THINGS STAND (11:34): the owner has compiled and run everything up to zip
221; zips 222 - 226 were pushed (cade964 "Menu tidy"), their compile
result not reported. Zip 227 (step 1 below: Aladdin out, the reference
texts in) COMPILED AND RAN (calibration, 5090, 10:49); 228 (media/
deployed from the repository, deploy_redist.py --media-only) and 229
(the calibration times the clearest 30 s of the recording), 230
(benchmarks - step 3), 231 (keep the book: No) and 232 (the Benchmark
menu of five with times expected; the score = transcription time
H:MM:SS.mmm) and 233 (the benchmarks' progress bars) are delivered,
NOT COMPILED. Step 4 (the leaderboard) is
not to be mentioned to users yet (owner 11:34).
Last number used: see "Deliveries". Never commit or push.

BEFORE BUILDING ANYTHING read, in this file: the standing rules under
"Session 7 in brief" above it (chapter material only; Steam Input
mapping; the Steam rebuild banner), "Survey of machines, 2026-11-21"
(seven machines, the error table, the decision base + turbo), "NEXT
PLAN OF ACTION: EpubReader free, EpubBuilder a paid DLC", and the
calibration notes (zips 198 - 208). The owner was charged for a session
in which a recorded rule was ignored: check the notes first, and ask one
precise question where a wrong guess would cost a zip.

THE TASK, in the order it has to be built:
1. DONE IN ZIP 227 (not compiled): ALADDIN OUT, THE REFERENCE TEXTS IN
   (owner 10:28: "Remove all aladdin references ... These may change so
   refer to them as reference texts"). uCalibration.REFERENCE_TEXTS is
   the one place the files are named; the tools copy all of media/.
   DECIDED (owner 2026-11-22): A Scandal in Bohemia (LibriVox, Phil
   Chenevert, 56:23, 3 sections; text = Project Gutenberg 1661 cut down
   to the first story, its PG notices kept) for the CALIBRATION; BOTH it
   and A Christmas Carol (LibriVox, Kyle M., 3:11:08, 5 staves; text =
   PG 46) as SEPARATE BENCHMARK OPTIONS. Files in media/:
   ScandalBohemia_librivox.m4b, AChristmasCarol_librivox.m4b (both
   git-ignored), A_Scandal_in_Bohemia.epub, A_Christmas_Carol.epub
   (committed). Every LibriVox section has a spoken intro and outro: 30 s
   clear of both ends of EVERY section, for timing and for scoring.
2. BUILT IN ZIP 242 (not compiled): CALIBRATION ON A CONTINUOUS STRETCH
   (owner 13:37 "2"). Before it: the survey showed what the
   30 s stretch gets wrong: the .en models' temperature-fallback retries
   do not happen in it, so it misranks them against a real build. The
   deferred "calibration on a continuous stretch" change belongs here.
   The fallback stays on. Every machine is calibrated again afterwards.
3. THE BENCHMARK ("BookMark"): built with turbo and base (the decision),
   speed and accuracy from chapter material only. The owner re-runs
   every machine for it - the 2026-11-21 figures are a survey, not
   results to publish.
4. THE LEADERBOARD the benchmarks build.
5. TWO BUILDERS: a LIMITED one with the benchmark only, and the FULL one
   with everything, "DLC-enabled" - this joins the DLC plan above
   (ownership asked of Steam: SteamDlcState / SteamGetDlc in uSteam; a
   new STEAM_DLC_BUILDER constant).

NOT DECIDED - ask the owner at the start, do not guess:
- Whether the audio ships in the depot (113 MB for both) or is
  downloaded on first use. (Recordings, readers and texts: decided, see
  1.)
- MODELS DEPOT (owner 2026-11-22 10:39): the owner made a new Steam depot
  with ggml-base.bin and ggml-large-v3-turbo.bin, pre-loaded for Windows +
  Linux. The builder's Steam models folder is <install folder>/models
  (uModels.ModelsDefaultFolder: beside the program; on macOS beside the
  .app, i.e. the same install-root models/), so the depot's files must
  land in models/. macOS can take the SAME depot (the .bin files are the
  same everywhere) - plus, for Core ML, ggml-base-encoder.mlmodelc and
  ggml-large-v3-turbo-encoder.mlmodelc folders beside them (a Mac-only
  depot; without them the builder downloads them on first use of a model
  on a Core ML build). Under the DLC plan the depot belongs to the
  builder DLC. Not built in code: nothing to change while the folder is
  models/.
- What a benchmark run is: how much audio, which models (base and turbo
  only, or the expert list too), every device or the calibrated one, and
  how long it may take on the slowest machine (the Miix: turbo 0.8x).
- The leaderboard: Steam leaderboards (TSteamAPI - is ISteamUserStats
  wrapped?) or something of our own; what the score is (speed alone,
  speed and accuracy); one board per model / device class; how a machine
  is named without machine or user names (the privacy rule); what stops
  a made-up score.
- The limited builder: a separate program, a build define, or the same
  program asking Steam whether the DLC is owned; whether it is the free
  part of the reader's app or its own launch option; what a non-Steam
  build is (full?).
- Open from session 12, still unanswered: the reader's page keys under
  the Steam Input rule (zip 217); keep the display on while the builder
  works; 960 in FMX units or pixels; Q for the queue; installed .en
  models before uninstalled multilingual ones; whether the window's
  Settings... button should open File > Settings' page (zip 223).

KNOWN, NOT FIXED: the calibration log says "no graphics card here could
run it" when the CPU is simply the fastest (Mac); nothing chooses base
by itself on a slow machine; uInhibit takes desktop Big Picture for Game
Mode; touch in the pad menu is untested; zip 207's redraw after display
sleep (Windows) and zip 210's Mac full screen are untested; the desktop
dark window of zip 222 was written unseen.

## Handover (session 11, 2026-11-21 05:18)

### Session 11 (2026-11-20 19:35 - 2026-11-21 05:18) - where it stopped
Written at the owner's request (05:18: "write up a session handover in
claude.md. Pay particular attention to releasing Reader as a free app
with Builder as a paid dlc as this will be the next plan of action -
unifying the project"). One section per zip below ("Zip 181" - "Zip
192", newest first); this is the map.

PUSH STATE: last push 42d5f27 "Handover" = zips up to 180. NOTHING of
181 - 193 is pushed (193 = this handover). Never commit or push unless
asked.

COMPILED / RUN BY THE OWNER: 175 - 180 ("everything compiles fine",
19:39); BookManager (181 + 182's TPath fix) compiled and ran (paired,
first-chance Indy exceptions seen); EpubBuilder up to 187 ran on the
Steam Deck (debug log "Build: 2026-11-20 21:18, 42d5f27": ROCm0 left
out, calibration, Foundation built). NOT COMPILED: 188 - 192 (188
launcher / RocmUnusable, 189 / 191 icons + EpubBuilder.dproj line, 190
RememberOutFolder, 192 the builder's window rewrite - the biggest risk).
NO PACKAGE REBUILD needed for anything since 180.

FILES CHANGED since 42d5f27 (for the push): CLAUDE.md, README.md,
EpubUnum.groupproj (BookManager), tools/gen_projects.py,
tools/make_icons.py (NEW; delete tools/make_bookmanager_icon.py if 189
was applied), demos/common/uLink.pas, demos/EpubReader/src/uPadMenu.pas,
demos/EpubReader/EpubReader_Icon.ico (redrawn), demos/EpubReader/README.md,
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/src/EpubBuilder.sh
(keep 100755), demos/EpubBuilder/EpubBuilder.dproj (one Icon_MainIcon
line), demos/EpubBuilder/EpubBuilder_Icon.ico (NEW),
demos/EpubBuilder/README.md, demos/BookManager/ (NEW: BookManager.dpr /
.dproj, BookManager_Icon.ico, README.md, src/uManager.pas + .fmx,
src/uTransfers.pas, src/uRoute.pas).

Done this session, by theme (details in each zip's section):
- BOOKMANAGER (181 - 184): a new FMX desktop program (not Steam): finds
  EpubBuilder by UDP, pairs with a code, sends books / audio / pictures /
  folders each to its place (uRoute), fetches the books made, Progress
  and Log tabs; cancels drop the connection (uLink TLinkClient.Cancel);
  the poll backs off and stops while the builder is not heard. The
  builder's pairing box became a bar that closes itself, with Refuse
  connection (183).
- BUILDER UI: Big Picture books list - transcribed books last, faded,
  "transcribed" (184, uPadMenu TPadMenuItem.Dim); BP home order Book,
  Audio, Add to queue, Queue (184); BP window = the log only, text 24
  (185); a typed output folder is remembered (190); the window rewritten
  - settings on their own page (Settings... / Tools > Settings...), the
  queue below book and audio (192).
- ROCm ON THE DECK (186 - 188): ROCm0 listed on gfx1033 hung model loads.
  The launcher hides HIP when ROCm's runtime is bundled without kernels
  or no GPU has kernels (kfd gfx check); EpubBuilder leaves ROCm devices
  out itself (a Deck, or runtime without rocblas/) and "Default" becomes
  the first other GPU. CAUSE ON STEAM: the HIP depot is no longer shipped
  but the LINUX DEPOT STILL CARRIES ggml-hip + libamdhip64 - stage it
  with steam_stage.py / deploy_redist.py --skip-rocm (owner's side).
- MEASURED: Steam Deck, Foundation 8:57 in 1:07:59 (7.9x Vulkan, 98.8 %
  matched; book / calibration 1.56) - see "Zip 189".
- ICONS (189, 191): one set drawn by tools/make_icons.py (navy tile,
  cream books, amber badge: reader play, builder gear + sound wave,
  manager arrows). Windows .ico only.
- ANSWERED, no code: one Steam account = one device running at a time;
  cloud GPUs (L40S / H100 / RTX PRO 6000) vs the 5090 laptop - modest
  per book, big for several books at once (needs parallel jobs, driver
  580+, "add by address" in BookManager); Steam Families; Bazzite tests
  listed under TO TEST below.

OPEN / OFFERED (not done):
- Calibration: a time limit per device (a hanging GPU skipped, logged).
- The GPU-against-kernels check also in EpubBuilder itself (the Linux
  ROG Ally, gfx1103) - partly done by 188's "runtime without rocblas/".
- BookManager: hold transfers while the builder is not heard (now they
  fail at once; a re-drop skips what arrived); "add by address" (cloud /
  other subnets - UDP broadcast does not cross).
- Builder: larger fonts "where needed (like Deck)" - asked what / when;
  the Big Picture form "may be" more than the log (owner to decide).
- Icons for macOS (.icns) and Linux.
- Several jobs at once on one GPU (cloud cards: 48 - 96 GB).

### NEXT PLAN OF ACTION: EpubReader free, EpubBuilder a paid DLC (one app)
Owner 2026-11-20 21:51: "On Steam is it possible to make Reader a free
main product with builder a paid DLC?" - yes; 22:21 asked whether both
can run at once; 2026-11-21 05:18: "this will be the next plan of action
- unifying the project". Nothing of it is built yet.

WHAT STEAM ALLOWS (checked on the web 2026-11-20, partner.steamgames.com
DLC page and SteamDB):
- A free base app with paid DLC is normal ("Steam supports both free and
  paid downloadable content").
- ALL DLC DEPOTS LIVE IN THE BASE APP's depot list ("There is no way to
  have Depots reside within your DLC App directly"): the builder's files
  are a depot of the READER's app, owned by the DLC, installed into the
  reader's folder only for owners.
- A LAUNCH OPTION CAN REQUIRE OWNING A DLC (SteamDB shows XCOM 2's config:
  a launch option with "Owns DLC ..."): an "EpubBuilder" launch option
  per OS, shown only to owners; Steam asks Reader or EpubBuilder on Play.
- Precedent: Animaze - a freemium app whose one-time-purchase version is
  a DLC with its own launch option.

WHY IT FITS: the two programs already share one Steam Input manifest
("one manifest per Steam app" - the builder uses the reader's), the
Documents/EpubUnum folders and the EpubUnum settings folder; the reader
already lists the builder's Transcribed folder; a free reader also
answers "several devices on one account" (each person their own free
account; zip-less answer 20:03).

WHAT CHANGES (the work, in order):
1. STEAMWORKS (owner): under 5639840 (EpubReader) a new DLC app
   "EpubBuilder" (paid) -> its AppID; on 5639840's Depots page one depot
   per OS for it (Windows, Linux, macOS), each owned by the DLC; the DLC
   in its packages (store package, developer comp). The ROCm DLC (free,
   zips 110 / 111 - never made on the playtest) and later CUDA: DLCs of
   5639840 too (only builder owners need them; offered only by the
   builder). Launch options on 5639840: per OS "EpubReader" (as now) and
   "EpubBuilder" with Owns DLC = the builder DLC (Windows EpubBuilder.exe;
   Linux EpubBuilder.sh - the launcher, NOT the binary; macOS
   EpubBuilder.app). Store: the DLC's page, price, screenshots; read
   Valve's DLC rules for a whole program sold as DLC. Decide what becomes
   of 5639910 (the builder playtest): retire it, or keep it for tests.
2. DEPOTS / STAGING (tools/steam_stage.py + the owner's SteamPipe GUI
   setup, one setup per program today): ONE install folder for both
   programs. Files both use (FFmpeg's libraries, libgomp, licences/,
   steaminput/, FreeType / ICU launcher helpers ...) go ONLY in the
   reader's base depots; the builder DLC depots hold what only the
   builder needs (EpubBuilder + .sh / .app, whisper / ggml CPU + Vulkan,
   media/ (the reference texts), models/ - turbo 1.5 GB: in the DLC depot or
   downloaded on first use, decide). Two depots writing the same file
   name into one folder must not happen (check for overlaps in the
   script; reader and builder must ship the SAME FFmpeg build). ROCm /
   CUDA parts as today (steam_stage.py's HIP / CUDA folders) but as DLC
   depots of 5639840. Mac: EpubReader.app and EpubBuilder.app side by
   side in the depot (the reader's .app today has the steaminput folder
   beside it).
3. CODE:
   a. EpubBuilder.dpr: STEAM_APP_ID 5639910 -> 5639840 (the reader's) +
      a new STEAM_DLC_BUILDER constant. After SteamStartup: not owned
      (SteamDlcState in uSteam - BIsDlcInstalled / BIsSubscribedApp) ->
      a message and SteamGetDlc (the store page in the overlay), no
      window. Its files are only there for owners, but check anyway
      (copied folders).
   b. Steam treats both as ONE app: while one runs, Play becomes Stop -
      the other is started FROM the running one. EpubReader: "Open
      EpubBuilder" (owned) / "Get EpubBuilder..." (not: SteamGetDlc) in
      its menu and its pad menu; EpubBuilder: "Open EpubReader". Start
      the sibling from the program's own folder (Windows CreateProcess;
      Linux through EpubBuilder.sh / the reader's launcher so the
      runtime's env is right; macOS open -a the other .app). The child
      inherits SteamAppId; Steam counts the app as running until both end.
   c. PAD: both programs get Steam Input for the same app at once - each
      must ignore pad actions while its window is not the active one
      (uSteamPad / TSteamPad users: the reader's uReaderInput and the
      builder's pad menu).
   d. GAME MODE (gamescope): two windows of one app - how the user
      switches between them is UNTESTED; test on the Deck / Steam Machine
      before relying on it (may need one at a time in Game Mode).
   e. STEAM_DLC_ROCM (uBuilder, CheckRocmDlc) -> the ROCm DLC's new AppID
      under 5639840.
   f. Paths: the install folder becomes the reader's
      (steamapps/common/<reader's install dir>) - everything is relative
      to the program, but check the launchers, steaminput/, media/,
      models/ and the debug logs' "Program:" line.
   g. Playtime / status show as EpubReader for both (fine; say so).
4. BOOKMANAGER: not a Steam program today. Options: a third launch
   option in the builder DLC (it serves builder owners only), or its own
   download. Decide.
5. TEST MATRIX: DLC not owned (reader works; builder option hidden;
   "Get EpubBuilder" opens the store); owned (both launch options; Open
   the sibling from each; the pad only acts in the front window); Windows
   desktop + Big Picture, Steam Deck Game Mode, Steam Machine, macOS;
   the ROCm DLC on the Steam Machine (kernels) vs the Deck (hidden, 188);
   uninstalling the DLC removes only the builder's files.

DECISIONS FOR THE OWNER before code: the builder's price; what stays free
in the reader (all of it, as now?); models in the DLC depot or downloaded;
BookManager's place; 5639910's fate; app name / store naming (one product
"EpubUnum" with the reader as its base?).

### THEN, HIGH PRIORITY: an Apple TV (tvOS) player - native, not Delphi
Owner 2026-11-21 05:29: "make (2) a high-prority option after combining
Reader + Builder - add this to Claude.md". (2) = a small native tvOS
app. Delphi has NO tvOS target (Embarcadero's platform lists: Windows,
macOS, iOS, Android, Linux - checked 2026-11-21); an iOS build does not
install on an Apple TV. So: Swift / SwiftUI with Apple's tvOS SDK, built
in Xcode on the M4 Mac - a SEPARATE codebase from the Delphi programs.
Order: AFTER the reader + builder DLC work above.

What makes it small: the hard part - the book format - is settled. The
books EpubBuilder makes are standard EPUB 3 with Media Overlays (SMIL
clips: text fragment id + audio file + clipBegin / clipEnd, the audio
inside the EPUB). The tvOS app needs:
- reading the EPUB (zip): container.xml -> the OPF -> spine, nav (the
  chapters), the SMIL of each content document, the audio files;
- showing the page text (WKWebView is NOT on tvOS - render the XHTML's
  text natively, e.g. AttributedString / a Text view per paragraph) with
  the word or phrase being read highlighted, as EpubReader does (its
  uEpubView / clip logic is the reference: ClipAt, the highlight, the
  word-level clips);
- playing the audio with AVPlayer (seek to clipBegin, a periodic time
  observer to move the highlight; speed 0.5 - 3x as the reader's slider);
- the Siri Remote: play / pause, skip a sentence / chapter (swipes),
  the chapter list, speed; large text (10-foot UI, as Big Picture's 24+);
- a library: the books, their covers (the EPUB's cover image), where
  each was left (the reader's bookmark / position) - in iCloud key-value
  storage or CloudKit so iPhone / Mac / TV agree.

GETTING BOOKS ONTO THE TV - CHECK FIRST: tvOS gives apps little or no
guaranteed persistent local storage (Apple's tvOS guidance: a small
key-value store; caches the system may purge; iCloud / CloudKit /
on-demand resources for more) - and a built book is large (Foundation's
EPUB: 489 MB, the audio inside). Options, to be decided after checking
Apple's current rules:
- STREAM from the computer that has the books: EpubBuilder's link
  (uLink: UDP discovery on 47820, HTTP /books and /book with offset) or a
  small "serve my library" mode in EpubReader - the TV pairs once (the
  6-digit code, as BookManager) and streams the EPUB's parts (HTTP range
  requests into the zip: the SMIL, the XHTML, the audio file of the
  chapter) - nothing large kept on the TV;
- iCloud Drive / CloudKit: the user's books in their iCloud, cached on
  the TV while read;
- the cache only (re-fetched when purged).
Streaming over the existing link fits the project best (BookManager and
the reader already speak it) - the link would need range reads INSIDE
an EPUB (a /part?path=..&entry=.. call) or the TV fetches the whole
file into its cache.

DISTRIBUTION: the App Store (Apple Developer Program, review), separate
from Steam; free (like the reader) is the natural fit - it reads books
made by the paid builder.

DECISIONS FOR THE OWNER: where the code lives (a tvos/ folder here or a
new repository); how books reach the TV (above); iPhone / iPad from the
same Swift code later (SwiftUI targets both - an alternative to Delphi's
iOS build for the reader); the name on the App Store.

### TENTATIVE: a headless EpubBuilder - pairing without a screen
Owner 2026-11-21 05:31: "Builder needs a headless option at some point.
This will mean it can't show the 6 digit code. We need other options -
discuss." Offered: the code in the log / stdout, a --pair window, approve
from a paired client, a pre-shared key, trusted networks, Tailscale
identity - owner 05:35: "No - I don't like those options. Can we have
one that involves email?"; 05:40: "Yes, as a tentative one. Another
option would be an activation website I suppose. This would require
registering app instances (UUID?) with central site - this needs some
thought...". NOTHING decided or built; the two ideas below.

CONSTRAINT (owner 05:41: "we dont want to go against steam rules"):
Steam allows a product to need an outside account, but the store page
then shows "Requires 3rd-Party Account: ..." (declared by the publisher;
players dislike it - Sonic Superstars' Epic login); since 2024 store
descriptions may not link to other websites. (Valve's own wording on
third-party accounts not found in the public docs - check the store
page's settings in Steamworks.) So: the Steam products must NEVER need
an outside service or account - pairing on the local network with the
on-screen code stays the way; anything central (email relay,
activation site) is an OPTIONAL extra, off by default. Simplest:
headless = a separate non-Steam build (servers / cloud cannot run the
Steam client anyway), as BookManager is not a Steam program.

IDEA A - THE PAIRING CODE BY EMAIL (tentative plan):
- Setup, once: the owner's address ([Link] Email= in EpubBuilder.ini, or
  --email); a test message with a confirmation code proves mail arrives.
- Pairing as now (/pair, /pair/confirm, 6 digits, 5 minutes, 5 tries),
  but the code is EMAILED: "BookManager on MONSTER wants to connect to
  EpubBuilder on SERVER. Code: ... (5 minutes). If this wasn't you,
  ignore this email." Ignoring = refusing; a Block link (that client
  never asks again) possible. Clients unchanged.
- HOW IT SENDS (the open question):
  1. a small relay run by the project (HTTPS POST from the builder via
     System.Net.HttpClient - the system's own TLS, no OpenSSL) -> a mail
     service (Postmark / Resend / Amazon SES ...). Easiest for users. The
     relay sends ONLY the fixed pairing template, only to addresses
     confirmed once, rate-limited (else it is a way to flood anyone's
     mailbox). Costs: running it, a privacy policy (addresses stored).
  2. the user's own SMTP (server, user, app password) - fiddly for users;
     secure SMTP from Delphi needs Indy + OpenSSL, and the OpenSSL 3 of
     current Linux needs a newer Indy TLS add-on than Delphi's bundled
     Indy (CHECK before promising it).
  3. the user's own mail-service API key over HTTPS - for technical users.
  Suggested: 1 as the default, 2 / 3 for those who will not use the relay.
- To decide: run a relay (where); email only for headless or everywhere
  (the bar AND the email on a builder with a screen); one owner address
  or several (a family).

IDEA B - AN ACTIVATION WEBSITE (needs thought - owner):
- Each install registers with a central site: an instance id (a UUID -
  the link already has a builder id it announces; persist one per
  install) + a secret the site gives back. The user has an ACCOUNT on the
  site (email sign-in, or "Sign in through Steam" - Steam's OpenID: the
  site learns the Steam account, no address needed).
- Claiming an install = the TV-style DEVICE FLOW (OAuth 2.0 device
  authorization grant, RFC 8628): the install gets a short user code from
  the site and shows it ... where? A headless builder has no screen - the
  code goes by EMAIL (idea A) or in the log; a reader / BookManager shows
  it. The user enters it on the website, signed in -> the install is
  theirs.
- Then pairing needs no codes at all: installs claimed by the same
  account trust each other - the builder asks the site whether a client
  id belongs to its owner (or the site hands both a pairing token).
- What it would also solve: FINDING a builder outside the home network
  (cloud, a friend's house) - the site knows each install's last address
  (a rendezvous); UDP broadcast does not cross the internet. Even relaying
  traffic when neither side is reachable (costly - only if needed).
- What it costs: a service to run and secure (accounts, secrets, tokens),
  personal data (GDPR: what is kept, deletion), uptime (if the site is
  down, nothing new pairs - the LAN pairing with the code must keep
  working without it), the Steam store's rules on third-party accounts
  (a Steam product requiring an outside account must say so on the
  store page - CHECK Valve's rules).
- It overlaps with the DLC plan (ownership is Steam's job there) and with
  the tvOS app (the TV would claim itself the same way and find the
  library through the site).

TO TEST (from this session): Bazzite on the ROG Ally (see the list
under Session 10's preferences); EpubBuilder on a Windows Ally (CPU +
Vulkan, its pad menu); 192's window (settings page, queue below,
dividers) on Windows, Linux and the Deck's Desktop Mode.

### Session 10 (2026-11-19 - 2026-11-20 13:00) - where it stopped
Written at the owner's request (13:01: "this session's getting long.
Write session handover in claude.md"). One section per zip below ("Zip
139" - "Zip 179", newest first); this is the map.

PUSH STATE: last push 8a9a67d (zips up to 138). NOTHING of 139 - 179 is
pushed. Never commit or push unless asked. The owner applies the zips
on Windows (Delphi 13.2), builds Win64 / Linux64 (PAServer) / OSXARM64,
and tests on the Steam Machine (SteamOS 3.9.5, Game Mode, Big Picture),
Steam Deck, M4 Mac and the RTX 5090 laptop.

COMPILED BY THE OWNER: up to zip 174 (packages too, with 171's MOBI);
zip 175 failed (uLink E2250, fixed in 177) - so 175 - 179 are NOT
COMPILED yet. Expect a round of compile errors in uLink (Indy calls and
Posix.SysStatvfs's names written from memory), uCoverPick / uCovers
(FMX), uEpubUnum, the reader's ShowCoverChoice. PACKAGE REBUILD NEEDED
from 176 (Epub.Book) and 177 (Epub.Writer, Epub.Mobi) - EpubUnum ->
EpubUnumFMX -> dclEpubUnumFMX, then the programs.

Zip 180 (on top of 179) = this handover + demos/EpubReader/README.md (a
muddled paragraph about zip 176 taken out of "A book's cover in the
library" after 179 was sent). The last zip of session 10.

Done this session, by theme (details in each zip's section):
- MAC / SPEED: App Nap made the M4 build slow with the display off ->
  NSProcessInfo activity (140); Power setting (Automatic / Fastest /
  Save power / Let it sleep), Windows EcoQoS, Window GPU preference
  (142); notes/Building-distributions.md (143), notes/Windows-on-Arm.md
  + Arm64ECProbe (144); deploy_redist --skip-rocm / --skip-cuda.
- BUILDER IN BIG PICTURE (148 - 166): the pad drives it (uSteamPad +
  the reader's uPadMenu, the reader's Steam Input manifest), models
  list, Run queue on the home list, Ask / Tell boxes full width,
  progress panel with the log on demand, memory cards (uCards: Books /
  Audio / Transcribed on SD cards; "local or back on card"), kept queue
  (restored at start), queues folder + Save / Load in Big Picture.
- GAME MODE BLACK SCREEN / SLEEP (164 - 170): uRedraw (redraw, resize
  nudge, leave/re-enter full screen; the display check reads nothing
  inside Steam's container). Steam's SLEEP is the culprit: refusing it
  (logind block) leaves Steam stuck (black, menu dead, restart Steam).
  169: in Game Mode (XDG_CURRENT_DESKTOP=gamescope, else Big Picture on
  Linux) only a logind DELAY lock; PrepareForSleep -> the build pauses
  between 30 s windows (GSleepGate), sleep goes ahead, the build goes on
  at the wake - TESTED, works (7 sleeps, Vulkan fine after resume).
  Finished parts kept (.transcript-partial.json) -> a stopped build goes
  on from the next part. Run-queue note of the expected time. 170: time
  left / taken leave the sleep out. OPEN: the machine sometimes wakes
  itself 3 - 5 s after suspending ("bad sleep") - not the program
  (frozen then); suspects the pad (Bluetooth) or HDMI-CEC; asked the
  owner for tests without EpubBuilder / without the pad and for
  pm_debug_messages + /sys/power/pm_wakeup_irq. Steam's sleep timer
  counts from the last button, not the wake.
- QUEUE: done jobs leave the queue when it finishes (after the report);
  "done" jobs in a saved / kept queue are not queued again (172).
- MOBI -> EPUB 3 (171 - 174): lib/Epub.Mobi.pas (in the EpubUnum
  package): PalmDOC, trailing entries, EXTH, MOBI 6 HTML cleaned to
  XHTML, split at <mbp:pagebreak>, filepos links, recindex pictures,
  cover; DRM / HUFF / KF8-only refused. Builder: BookAsEpub (cache
  <settings>/Converted), MOBI in the Choose dialog and Big Picture lists
  (any letter case, 173). TESTED: The Sword of Shannara (copyrighted
  sample - never commit, upload or quote) built 37.4x, 99.8 % matched.
  NEXT maybe: KF8 / AZW3, HUFF/CDIC.
- READER CHAPTERS (176, lib): AudioChapterWords by time (the soonest
  clip after the mark), not reading order - the Shannara title page read
  in the end credits had put all 37 marks on one word. Not yet tested.
- COVERS (177, 179): lib TEpubWriter.SetCover; builder uCovers (Covers
  folder by name > the audiobook's art (MP4 covr / ID3 APIC / FLAC) when
  the book has none or a landscape one > the book's own), uCoverPick
  thumbnail chooser (Cover... button, Big Picture's Cover row; choice
  kept per job as "cover"). Reader (179, "Reader only"): View / pad menu
  "Cover of this book" - the book's own, the m4b inside the book (read
  in place: TStreamWindow), EpubUnum/Covers - written to the library's
  cover cache only.
- THE LINK (175, builder side only): demos/common/uLink.pas - App
  Tethering is not on Linux, so our own: UDP announcements (47820),
  HTTP (Indy, 47821+), pairing by a 6-digit code shown on the builder,
  uploads (Books / Audio / Covers, .part then renamed, refused when less
  than 2 GB would be left), downloads of the books made (resumable),
  /status, /log. NEXT: BookManager (a new FMX desktop app - a drop
  target routing books / audio / pictures / folders, progress and log
  tabs, fetches the books made), then the reader's "Get books from
  EpubBuilder" (TLinkFinder + TLinkClient are written, unused yet).
- SHARED FOLDERS (178): uEpubUnum - Documents/EpubUnum (Books, Audio,
  Transcribed, Covers, Queues) and one EpubUnum settings folder;
  EpubUnumMove moves the old EpubBuilder / EpubReader folders in once
  (marker EpubUnum-moved-<App>.txt), settings copied with paths changed.

TO TEST (owner 2026-11-20 22:30, "will need to test Bazzite too"):
BAZZITE (Fedora Atomic, gamescope session like SteamOS) on the ROG Ally
(Z1 = gfx1103, no ROCm kernels): the launcher's ICU / FreeType / WSI
lines and the "ROCm: off" line (zip 188), Game Mode detection
(XDG_CURRENT_DESKTOP=gamescope) and the sleep handling (logind delay,
PrepareForSleep), memory cards (/run/media/$USER), Big Picture (log
window, pad menu, text 24), the link (UDP broadcast through Bazzite's
firewalld), the Vulkan calibration against the Deck's 5.1x. Also the
Ally on Windows (CPU + Vulkan; builder's pad menu not yet tried there).

Owner's preferences seen this session: batches tests to avoid Steam
redeploys (each Steam build is slow); wants things found without typing
(no IP addresses); likes clear logs; Steam Machine is the main test box.


### Session 9 (2026-11-17 night - 2026-11-19 early) - where it stopped
Written at the owner's request (05:15: "write session handover as well
in claude.md as this one's rather long"). One section per zip below
("Zip 95" - "Zip 138"); this is the map. Brought up to date at 06:14
("session handover again please") - zip 138.

PUSHED SINCE (2026-11-19 08:18): 8a9a67d "Reader Steam Tests" (after
a170de0, 298b504) - the zips up to 138 (not compared file by file: the
zips are not here; the logs of the morning's queue match its code). NOT
PUSHED: 139 (the morning queue's results), 140 (App Nap on the Mac), 141 (the Mac
Steam reader's Books and steaminput beside the .app), 142 (Power, Window
GPU, devices by description), 143 (notes/Building-distributions.md), 144
(notes/Windows-on-Arm.md + Arm64ECProbe.dpr); see their sections.

Pushes, checked file by file (CR LF aside):
- Epubunum 667070c "Reader Steam Tests" = zips up to 127 (with 43e5cb9
  "Remove local timings file", 21fd6cc). NOT PUSHED: 128 (zip 123's
  tools/gen_reader_input.py - the README already says the plain command
  -, .gitignore's last line end), 129 (Open a book / books folder), 130
  (its test note), 131 (text >= 24 on a Steam Deck), 132 (disk-space
  note), 133 (book columns in the build history), 134 (this handover),
  135 (four more for the OPEN list), 136 (forced language), 137 (the
  folders follow the dialogs again), 138 (this update).
- whisper-dev: zip 22 (WHISPER_DEV_COREML) - pushed 2071815 earlier in
  the session. TSteamAPI: nothing changed this session (EpubReader's
  generator imports its tools/gen_input_mapping.py; the owner's copy is
  ..\Steamworks - the old name).

Done this session, by theme:
- MAC BUILDER: ggml backends (.so) and aladdin.m4a deployed (95, 96);
  models by short name, downloaded by the program (101); Core ML
  encoders (102, whisper-dev 22). DRM-free .aax (98). Justified text in
  the reader (105, package). Build history CSV + time left + Tools >
  Build history (99, 100), estimates x 1.35 from the calibration alone
  (117), poor builds (< 90 % matched) left out and the book's title /
  language / file in the rows (133).
- STEAM: ROCm as a second depot of the builder's playtest (110, 111;
  tools/steam_stage.py); aladdin.m4a in Win64 builds (112); keep-awake
  while working (114, uInhibit); gamescope's WSI layer off in
  EpubBuilder.sh - it aborted ggml's Vulkan device in Game Mode (116);
  Steam's Exit Game (SIGTERM) saves first and is logged (119, uQuitSignal;
  126 its finalization removed).
- BUILDER FOLDERS: books / audio / output folders, output named after
  the book with _001 ... (122); since 137 each follows its dialog (Book...,
  Add audio... / Add folder..., Output...) and is saved at once.
- BUILDER LANGUAGE: Language box beside Device - "From the book (tag)"
  or one of 18; kept per queued job; und / mul / zxx count as no
  language (136). After Ender in Exile tagged ru (62.7 %, a third of the
  speed) and a book tagged und.
- READER PAD (Big Picture, part 1 of 3): Steam Input manifest generated
  by tools/gen_reader_input.py -> demos/EpubReader/steaminput/ +
  src/uReaderInput.pas (121, 123); uSteamPad (common), uPadMenu (reader;
  prettier + Steam's glyphs in 125); steaminput/ in the builds (124:
  postbuild.bat Win64, deploy_redist.py Linux64; not Mac); Big Picture
  shows the page only (125); Open a book from the books folder (129 -
  STOP-GAP); Steam Deck text >= 24 (131).

TESTED BY THE OWNER this session:
- Steam Machine (gfx1102 8 GB, SteamOS, sniper): ROCm0 and Vulkan0 the
  same (Night Watch turbo 23:44 / 23:56, 37x; calibration 27.3 / 28.8x);
  Vulkan needs DISABLE_GAMESCOPE_WSI=1 (as a launch option; 116 puts it
  in the launcher - the launcher itself NOT yet tested). Idle: the owner
  set sleep Never; zip 114 untested there.
- Night Watch turbo: M4 Metal 52:18, M4 Core ML 30:47, 5090 26:08 (with
  stalls), Steam Machine 23:44. Ender in Exile: 5090 9:59, 83x, 99.6 %
  matched, no stalls; the M4's run of the same book was tagged ru -> 62.7
  % (zip 133's section).
- Reader pad: Windows desktop + Big Picture, PS5 pad (its glyphs), ROG
  Ally - "tested perfect"; Mac: works, but HUNG ON EXIT (zips 126 / 127,
  owner tries "tomorrow"); Open a book on the Deck - "stop-gap but it
  worked".

OPEN - IN THE OWNER'S ORDER OR WAITING ON HIM:
1. The Mac reader's hang on Exit: build 126 + 127, Exit from the pad
   menu, send the debug log (its "closing: ..." / "Steam: ..." lines end
   at the step that hangs).
2. Steam Deck / Steam Machine run of the reader: the Linux-only code -
   uQuitSignal (Exit Game), the D-Bus keep-awake ("screen:" line), the
   steaminput Deploy entries; the text size (zip 131: >= 24 on a Deck -
   owner deciding).
3. BIG PICTURE part 2: the big-screen layout (UiScale from
   Steamworks.FMX.Screen: the Mac's 34" ultrawide gave 2.24; a handheld
   case for the Deck); then part 3: following Steam switching into /
   out of Big Picture while running (session 8's plan, below).
4. EpubBuilder with a pad: offered as "pad as mouse and keyboard" (a
   Steam Input layout with mouse / key bindings, X = Steam's keyboard) -
   the owner's yes NOT given.
5. The language check before transcribing (common words vs dc:language;
   Whisper's own detection as a backstop) - offered; a MANUAL override
   is in (zip 136). Also: for a book with no tag, choose the prompt after
   Whisper has detected the language (now: the English one up front).
6. Books folder beyond the stop-gap (zip 130's list); EpubBuilder's
   Steam build writing into the reader's Books folder.
7. Disk space on Steam hardware (zip 132's note) - the reader's temp
   audio (840 MB for Night Watch) already.
8. The partner site: Steam Input "Custom Configuration (Bundled with
   Game)" -> steaminput/epubreader_controllers.vdf; for the Mac the
   files beside EpubReader.app in the depot (offered as a staging step).
9. The M4 slowing through the overnight queue (28.8 -> 17 - 19x) - heat?
Added by the owner (2026-11-19 05:22, "a few more for the list"):
10. EpubBuilder: a LOADED QUEUE does not show the output information
    (the jobs' outputs - check what Load fills in the list / the window
    against Add To Queue).
11. TOUCH as Steam input: on a Steam Deck a tap on a library cover
    should open the book (and the rest of the reader by touch). Check
    how FMX on Linux (and gamescope in Game Mode) delivers touch -
    clicks, gestures, or nothing - and what Steam's touch-screen setting
    for the game does.
12. EpubReader: AUTOPLAY when the book opened is already part-read (it
    goes back to its word - start playing there; not for a new book).
    Mind Learn to read and a book without audio.
13. CHECK EVERY WAY OF CONTROL, properly ("touch may not be the only
    one"): keyboard, mouse, touch, pad (Steam Input), trackpads / the
    Deck's as mouse, Steam's on-screen keyboard - every command of both
    programs reachable by each where it makes sense; a table in the
    READMEs of what does what.

Working notes added this session:
- Mac logs: ~/Library/Application Support/EpubReader (and EpubBuilder);
  crash reports ~/Library/Logs/DiagnosticReports (a hang leaves none).
  Steam Machine logs: ~/.config/EpubBuilder/; stderr via the launch
  option  %command% > ~/eb-out.log 2>&1 .
- Fields go before methods in a Delphi class section (zip 120: E2169).
- Steam: the owner's SteamPipe GUI has one setup per program (builder,
  reader), each with Deployment/<platform> folders; app 5639910
  (builder, a Playtest: no DLC - depots) and 5639840 (reader).

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
| WhisperBooks/Epubunum | 42d5f27 | EpubUnum-180 | 196 (196 Steam-rules constraint on the headless plan; 195 tentative headless pairing (email, activation site); 194 the tvOS player plan; 193 session 11 handover + the DLC plan; 192 builder window: settings page, queue below; 191 icon set; 190 typed output folder remembered; 189 BookManager icon; 188 ROCm runtime without kernels = off; 187 ROCm left out by the program (Deck); 186 no ROCm without kernels (Deck); 185 builder's BP window = the log; 184 transcribed books last, BP home order, BookManager poll backs off; 183 builder's pairing bar, 182 BookManager's TPath, 181 BookManager - NOT pushed; 166 (166 queues folder, kept queue, Big Picture save / load, hints; 165 the window emptied after Add to queue; 164 Linux: whole-window redraws; 163 Transcribed, memory cards; 162 pad menu: texts fill the width; 161 zip 160's compile errors; 160 the builder's progress panel, log behind View; 159 the reader lists EpubBuilder's output; 158 Run queue on Big Picture's home list; 157 Big Picture says why a build / job was refused; 156 Big Picture opens on the models without one; 155 Big Picture's model list; 154 no calibration question without a model; 153 Big Picture questions readable; 152 Linux deploys without ROCm and CUDA; 151 deploy_redist --skip-rocm / --skip-cuda; 150 steaminput in every build; 149 zip 148's compile errors; 148 EpubBuilder in Big Picture; 147 a queue's jobs shown on a click, Update job; 146 the Mac save panel's name; 145 zip 140 confirmed; 144 Windows on Arm notes + probe; 143 notes/Building-distributions.md; 139 the morning queue's results, 140 App Nap on the Mac, 141 Mac Books / steaminput beside the .app, 142 Power / Window GPU - NOT pushed; session 9: 95 - 138, see its handover above. Earlier: 94 handover; 93 Big Picture full screen; 77 - 92 calibration, Steam builds, libraries, Deck crash, build stamp, screen log, DPI, Big Picture maximise))) |
| G3DGames/TFFMpegAPI | 0795d19 | FFmpegAPI-14 | 14 (macOS sound) |
| G3DGames/ffmpeg-dev | 4d7b7be | ffmpeg-dev-09 | 09 |
| WhisperBooks/whisper-dev | 2071815 | whisper-dev-22 | 22 (Core ML; its own CLAUDE.md) |
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
- A STEAM REBUILD IS FLAGGED LIKE A PACKAGE REBUILD (owner 2026-11-22
  07:38: "similar to package rebuilds when a Steam rebuild is needed
  highlight it with arrows (otherwise don't mention)"). A delivery that
  changes more than the one program under test - a unit another Steam
  program compiles too (demos/common, uPadMenu, uReaderInput, uCovers
  ...), the Steam Input definitions, staged or redistributed files -
  ends with
      =====> STEAM REBUILD NEEDED <=====
  and the programs to build and deploy. A delivery that needs none says
  NOTHING about Steam builds. First used for zip 217 (EpubReader and
  EpubBuilder: one manifest, written by both at start-up - an old reader
  would write revision 1 back over the builder's 1.2).
- STEAM BUILDS: EVERY BUTTON AND KEY MAPPING IS DEFINED VIA STEAM INPUT
  (owner 2026-11-22 07:15: "Make it a standing rule that for Steam
  builds all button and key mapping must be defined via steam input";
  "Remove any code that overrides using steam input from Steam builds
  while keeping the functionality already described"). The definitions
  are tools/gen_reader_input.py's tables (never the .vdf files or
  uReaderInput.pas by hand); a change raises LAYOUT_REVISION. No
  program reads a pad except through Steam Input (true since the pad
  went in). CHECKED 2026-11-22 (Valve's Steam Input pages, TSteamAPI's
  gen_input_mapping.py at 80804ab): Steam Input binds CONTROLLERS to
  actions; a physical keyboard or mouse is not a Steam Input device and
  an action manifest has no place for a key - so key bindings cannot
  live in Steam's layout files themselves. HOW keys follow the rule
  (asked; the owner chose it): the keys and the pointer are TABLED IN
  THE GENERATOR beside the actions (MENU_KEYS, MENU_POINTER) and
  generated into uReaderInput.pas; a program asks which ACTION a key or
  a click means (ReaderMenuKeyAction, ReaderMenuPointerAction) and acts
  on the action as for a pad - NO KEY IS NAMED IN A PROGRAM'S OWN CODE.
  A table change raises LAYOUT_REVISION; an interaction added or taken
  away raises LAYOUT_MAJOR too. Done for the builder's menu (zip 217).
  STILL BREAKS IT: EpubReader.FormKeyDown (arrows, Enter, Esc in its
  menu; P, D, L, R, [ ] on the page) - see zip 217's notes.
- STEAM BUILDS: EVERY BUTTON IS SHOWN AS STEAM'S GLYPH WHEN A PAD IS IN
  USE, AND AS ITS KEY WHEN THE KEYBOARD IS (owner 2026-11-22 12:43 / 12:44:
  "All buttons must be shown as their Glyphs when a stick is in use and
  the Key shown when keyboard is in use. This is important as PS4/5
  controllers don't have A/B/X/Y etc" - "This applies to ALL menus").
  NEVER write a button's letter or name ("A answer", "B back", "Start",
  "View") into a text. Menu feet are hints built from ACTIONS (uPadMenu
  TPadHint / SetHints / HintsText): EpubBuilder PadFootOf(buttons, texts)
  + RefreshFoot after the Show; EpubReader PadMenuFoot + RefreshPadFoot.
  A pad: TSteamPad.Origin(button, dark) - its Glyph, else its Name; the
  keyboard / mouse: ReaderMenuFirstKey of the action (uReaderInput's
  table). The foot changes over when the other way is used (SetPadKeys in
  both programs). Done for every menu foot that names controls in zip 240.
- ONLY CHAPTER MATERIAL IS TRUSTED FOR TIMING (decided 2026-11-15,
  TWhisper zip 26; owner restated 2026-11-21 18:59). Whisper deliberately
  leaves a LibriVox recording's spoken intro and outro untranscribed, and
  other publishers' credits may go the same way, so audio within 30 s of
  a recording's start or end is never used to measure speed or accuracy:
  a calibration takes its stretch from WhisperFindSpeech (speech all
  through, 30 s clear of both ends). Anything new that times or scores
  Whisper follows this rule.
  FIXED IN ZIP 208 (was: BREAKS IT TODAY): the Diagnostics of zips 198 -
  206 read the recording's first DIAGNOSTIC_SECONDS from 0, intro
  included. Logs made before 208 (5090, Ally, Deck, Miix on 2026-11-21)
  are of that kind and say "its first 0:10:00"; 208's say "from 0:00:30".
  What follows is how those earlier logs are to be read. The accuracy lines are
  safe (counted between the first and last word matched); the speed has
  the intro in one window of twenty (about 1 % flattering, from the zip
  26 whole-file figure). The survey of machines on 2026-11-21 (5090,
  Ally, Deck, Miix) was made that way; it goes out fixed in the deploy
  after it.
  THE BENCHMARK ("BookMark" build): both recordings chosen are LibriVox
  (A Scandal in Bohemia, A Christmas Carol), so every section has the
  spoken intro and outro - time and score the chapter material only.
  Owner 2026-11-21 19:06: every machine is re-run for the real benchmark,
  so today's diagnostics figures are a survey, not results to publish.

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
| base.en, M4 Mac mini, MTL0 | (running 2026-11-18) | | | |

Calibration, M4 Mac mini 16 GB (2026-11-18; 30 s of Aladdin, median of 3,
DTW + book prompt): base.en CPU 34.0x, MTL0 69.1x; large-v3-turbo CPU
2.5x, MTL0 11.4x. The M4's CPU alone beats the GTX 1650's whole-book
base.en rate (25x CUDA) - fits Later tests 1 (fixed cost per window).
Calibration figures of the 5090 and the 1650: not recorded here yet.
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
   BACK EDGE too (zip 139, Night Watch turbo 2026-11-19): a few words of
   the closing credits matched the back matter, so ~570 words of it were
   timed over the credits. Both edges: count the first / last word read
   only inside a run of several matches, not a lone one.
7. CORE ML ON THE MAC - BUILT (owner 2026-11-18 10:30: "can we have
   coreml for deployment when I build?"; whisper-dev zip 22 + zip 102
   below); what is left is the comparison. Originally (agreed after the
   Metal calibration): whisper.cpp's figure: Core ML encoder on the Neural
   Engine > 3x the CPU alone; against Metal unknown - only the encoder
   (once per 30 s window) moves, the decoder and DTW stay on Metal / CPU.
   Steps: a second whisper-dev build with -DWHISPER_COREML=ON
   -DWHISPER_COREML_ALLOW_FALLBACK=ON (without the fallback a model with
   no .mlmodelc fails); ggml-<model>-encoder.mlmodelc for base.en and
   large-v3-turbo (whisper.cpp models/generate-coreml-model.sh; Python
   coremltools, ane_transformers, openai-whisper); time both against
   Metal on the same 30 s of Aladdin (calibration / WhisperConsole
   --bench). First load per model is slow (macOS compiles for the ANE;
   minutes for large) - keep it out of the timing. Ship it only if it
   clearly wins on turbo: one more folder per model to carry; redist /
   deploy would need the .mlmodelc beside the model, not in the bundle.

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
- PARKED (owner, 2026-11-18 12:24: "We'll leave this as an idea for
  later"): BOOKS FROM SOURCES - tools/pasdoc_epub.py (NOT IN THE
  REPOSITORY: the owner did not apply it - it exists only in zips 106 and
  107, 107 being the later version; apply 107's tools/pasdoc_epub.py when
  this is picked up. The TSteamAPI book builds clean, 8403 declarations) and the "maker" plan
  (lib/ Epub.Create + document model + PasDoc / Markdown / Delphi XML-doc
  importers, EpubConsole --create, an EpubMaker program; the Embarcadero
  DevRel contact for the concept). Owner on the layout in EpubReader:
  "better but not good". Next when picked up: a screenshot of an API page
  in EpubReader first; book side - one paragraph per member (signature,
  line break, description) to halve the gaps, shorter signatures; reader
  side (helps every book) - follow links with Back, margin-top / -bottom,
  a background or border for code, real tables.

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

Last number used: 306 (257 = session 13's handover at the top, CLAUDE.md only; 224 = the
next-session notes, CLAUDE.md only).

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
- MOBILE: EPUBREADER ONLY, iOS (iPhone + iPad) AND ANDROID (owner,
  2026-11-18 11:02: "yes, reader only on ios"; 11:03: "this would work on
  iphone as well, we may as well do android reader to complete the
  platform set"). EpubBuilder stays desktop / Steam: its libraries load
  at run time (iOS apps cannot ship loose ones - App Store: signed
  embedded frameworks only, static linking the usual way), long
  transcriptions are suspended in the background on both, and its window
  is a desktop one. After the Mac / Steam work. Plan:
  1. ONE PLAYER INTERFACE in the reader (a small unit: play / pause,
     Position, Duration, Speed, seek, end of file) with three behind it:
     desktop = TFFmpegAudioPlayer as now; iOS = AVFoundation (AVAudioPlayer
     with enableRate / rate, or AVAudioEngine + time pitch); Android =
     android.media.MediaPlayer through JNI (PlaybackParams.setSpeed, API
     23+; getCurrentPosition for the highlight). Both phones decode AAC
     (m4b / m4a, a DRM-free .aax) and MP3 themselves, so no FFmpeg on
     mobile. On iOS FFmpeg would have to be linked statically, and LGPL's
     relinking sits badly with the App Store (a legal question for the
     owner, not settled here); Android could load FFmpeg's .so files
     (dynamic linking is the LGPL-friendly case) but has no need to.
  2. Playing on with the screen off: iOS - AVAudioSession for spoken
     audio and the "audio" background mode in Info.plist; Android - a
     foreground service of type mediaPlayback with a media notification
     (play / pause on the lock screen; Android 14 requires the type).
  3. Audio straight from the book where the platform can read it in
     place, else extracted to the app's cache folder as now (Extract
     streams).
  4. Delphi targets (the .dproj has iOSDevice64 / Android64, False):
     Skia4Delphi supports both; fonts without fontconfig (TEpubView.Fonts:
     Skia's own font managers on iOS / Android); the library and covers in
     the app's own storage; books in through the system picker (iOS Files
     / "Open in" with CFBundleDocumentTypes for .epub; Android Storage
     Access Framework and an intent filter for application/epub+zip,
     content URIs copied in); the copy-protection refusal unchanged.
  5. Touch and size: tap a word = read from there, swipe pages / scroll,
     finger-sized tool bar; PHONE layout = one column, contents and
     library as full-screen views, tool bar at the bottom; tablet as the
     desktop with bigger controls. Shares the big-screen work (UiScale,
     the Steam Deck layout).
  6. Builds: iOS on the owner's Mac (Xcode + PAServer, set up for
     OSXARM64), TestFlight before the App Store; Android on Windows
     (Delphi's Android SDK / NDK), an .aab for Google Play, internal
     testing track first.
  Order (proposed): the player interface on the desktop first (no
  behaviour change, TFFmpegAudioPlayer behind it), then Android (no Mac
  needed, quickest to a device), then iOS.
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

## Zip 98 (on top of zip 97): DRM-free .aax in EpubBuilder
Owner, 2026-11-18 09:52: "Assign aax as a format Builder can load (with no
DRM)". Standing rule: never remove DRM, refuse protected files.
- uBuilder: both audio dialogs list *.aax. AddAudio (Add files, Add folder
  - TWhisper's folder list already had .aax, queue loading aside) calls
  TFFMpegAPI's FFmpegMp4Protection (FFmpeg.Media; header only, no FFmpeg
  needed, returns at once for non-MP4) and refuses a protected file with a
  log line (adrm / drms / sinf / enca): "... copy protected (...) and was
  not added. EpubBuilder does not remove copy protection: a DRM-free copy
  of the audio is needed." No decryption, no hint how.
- lib/Epub.Writer (PACKAGE EpubUnum): AddAudioFile stores a .aax as
  <name>.m4b in the book (AAC in MP4; audio/mp4); AudioMediaType knows
  .aax as audio/mp4 too.
- EpubBuilder README: step 2.
NOT COMPILED (no FPC or Delphi in this session; pasdoc_check,
project_check 0). TO TEST: Add files with a DRM-free .aax -> listed;
build -> the book has audio/<name>.m4b, plays in EpubReader; epubcheck;
an .aax straight from Audible -> the log line, not listed.
Not done: a saved queue naming a protected file is not checked on load
(the build refuses it - TWhisper / FFmpeg.Media raise the same message);
the brand 'aax ' stays in the file's ftyp (readers go by the media type).

## Zip 99 (on top of zip 98): build history and the time left
Owner, 2026-11-18 09:59: "we should be building up a history of encoding
speed + accuracy by model. This would then allow a better estimate of
time for completion as it still is extremely far off - base started
claiming it was going to need about an hour for Night Watch but now says
18m" (M4 Mac mini, MTL0); "even more extreme for turbo".
- NEW demos/EpubBuilder/src/uHistory.pas (framework-free; in the .dpr and
  one DCCReference in the .dproj - the .dproj NOT in the zip: the
  owner's has deploy_redist.py's OSXARM64 / Linux64 media entries newer
  than git; the IDE adds the reference from the .dpr, or Project > Add):
  <settings>-history.csv (EpubBuilder-history.csv), header + one row per
  build that TRANSCRIBED (saved transcripts left out): made, machine (the
  computer's name - MachineText before ' - ', so a system update keeps
  it), model file, device name, audio_s, transcribe_s (model loading
  included), after_s (aligning + writing, from progress 90 % to the end),
  speed, calibration_speed (the pair's at the time), exact_pct (Exact /
  book words), matched_pct (the verdict's figure). Quoted strings, '.'
  decimals. HistoryExpect: (1) median of the last 5 builds of machine +
  model + device, prior 3600 s of audio; (2) calibration speed x median of
  (build speed / its calibration speed) over this machine's last 10, prior
  1800 s; (3) the calibration alone, prior 1200 s; after-share = median of
  after_s / audio_s here.
- uCalibration: CalibrationSpeed(ini, model, device) - one pair's speed.
- uBuilder: TBuildThread.OnAudioLength (queued once the audio's length is
  known; FormClose clears it). StartJob -> PrepareEstimate (device
  resolved as the history names it); the log: "Expected: about H:MM for
  H:MM of audio - N.Nx real time, from <source>." or "no figure yet".
  ShowStatus: transcribing = remaining audio x blended s-per-s-of-audio
  (W = done / (done + prior); own rate from the first progress past 5 %,
  after 30 s) + after-share x audio; at 90 %+ the after-share left;
  nothing to go on = the old rule (own rate after 60 s and 1 %).
  BuildDone (Ok, before the .log is saved) -> RecordHistory: "Speed: N.Nx
  real time (expected N.Nx); exact .. %, matched .. %." and the row.
- EpubBuilder README: "Build history and the time left".
NOT COMPILED (no Delphi / FPC here); pasdoc_check, project_check 0.
Names to look at if the compile complains: TArray.Sort<Double>
(System.Generics.Collections), TryEncodeDateTime (System.DateUtils),
Format with TFormatSettings, Max(Int64, Int64), EnsureRange(Double).
WHY THE OLD ESTIMATE WAS OFF: not known yet - the from-start rate stays
pulled by the first parts (Night Watch's 75 parts: short ones first?
Metal's first shader compile?). The debug log of the base.en run shows
the parts' times; worth a look before tuning the priors.
Offered, not done: import earlier builds from the queue reports' CSVs
(Windows / Linux runs) to seed the history; a Tools > Build history view.

## Zip 100 (on top of zip 99): Tools > Build history
Owner, 2026-11-18 10:06: "It would be nice to display the build history
in tabular form via the tools menu". Also asked: "Is aladdin.m4a
deployed to Linux?" - only if redistributable_bin\Linux64\media holds it
and deploy_redist.py ran for Linux64 after that (this morning's run was
--platform OSXARM64, which leaves the Linux64 entries alone).
- uHistory: HISTORY_HEADERS / HISTORY_WIDTHS (12 columns: When, Machine,
  Model - without ggml- / .bin, Device, Audio, Transcription, Speed,
  Calibration, Book / calibration, Align + write, Exact %, Matched %),
  HistoryCells, HistoryTable (tab-separated, newest first, header),
  HistorySummary (a line per model + device of this machine: builds,
  median speed / exact / matched; other machines' count).
- uCalibration: ShowBuildHistory (TForm.CreateNew as AskCalibration):
  summary label, TStringGrid (FMX.Grid + FMX.Grid.Style; not editable,
  row select), the file's name, Copy (IFMXClipboardService, THistoryCopy
  for the event), Close. Modal, 1180 x 560.
- uBuilder: Tools > Build history... (miHistoryClick).
- EpubBuilder README: the window.
NOT COMPILED. Names to look at: TStringColumn / TGridOption.RowSelect /
TStringGrid.Cells (FMX.Grid), string.Join with a static array,
TValue.From<string>.

## Zip 101 (on top of zip 100): models by name, downloaded when chosen
Owner, 2026-11-18 10:13: "for steam we also want to deploy turbo", then
10:18 (instead): "rather than deploy we let the app download models and
store them in some known location. For Steam this would be in the steam
app directory while on desktop you can elect a folder for model storage.
This then means we can refer to the models by their short names allowing
selection from a drop-down." (Deploying turbo would also have put a Linux
deploy over PAServer's 2 GiB - Later tests 4.)
- NEW demos/EpubBuilder/src/uModels.pas (framework-free; System.Net):
  MODEL_CATALOGUE (tiny.en .. large-v3, 10 names, sizes as whisper.cpp's
  README; turbo 1549 MB measured), ModelFileName / ModelShortName /
  ModelUrl (https://huggingface.co/ggerganov/whisper.cpp/resolve/main/
  ggml-<name>.bin, as whisper.cpp's download-ggml-model.sh),
  ModelsDefaultFolder (Steam: <program folder>/models, macOS beside the
  .app - never inside: its signature; else <settings folder>/models),
  FolderWritable, TModelDownload (THTTPClient: HEAD without redirects for
  X-Linked-Size / X-Linked-ETag = SHA-256, then GET into <file>.part with
  OnReceiveData progress / cancel, size checked, SHA-256 checked when
  given, renamed; .part deleted on failure or cancel).
- uBuilder: edModel (TEdit + Choose...) -> cbModel (TComboBox) +
  Folder... (hidden in Steam builds); every edModel.Text -> FModelPath.
  FillModels: catalogue (downloaded: "name - note"; else "(N GB to
  download)"), other ggml-*.bin in the folder, a model elsewhere, "Other
  model file ..." (= the old file dialog). Choosing one not downloaded
  asks (Yes by default) -> StartDownload (progress bar + status line,
  Cancel, one at a time; the list disabled meanwhile) -> DownloadDone
  chooses it, ApplyCalibration, "not calibrated yet" hint. Settings:
  [Models] Folder (not in Steam builds); [Build] Model = the name when in
  the models folder, else the file (old settings with a path still read).
  Steam: the program's folder not writable -> the settings' models folder.
  Calibration without a model: a log line (no file dialog any more).
  FormClose waits for a download (deleted part).
- .dpr: uModels. The .dproj is NOT in the zip (as zip 99: the IDE adds
  uHistory and uModels from the .dpr).
- EpubBuilder README: "Models".
NOT COMPILED. Names to look at: THTTPClient.Head / Get(URL, Stream),
IHTTPResponse.HeaderValue / StatusCode / StatusText, TReceiveDataEvent's
signature, THashSHA2.GetHashStringFromFile, record constants with
strings (MODEL_CATALOGUE), TProc<Int64, Int64>.
TO TEST: each platform downloads base.en (small) once; Cancel halfway
(no .part left); turbo; the X-Linked headers really come (log says
"checksum right" or "no checksum given"). LINUX: THTTPClient uses
libcurl (libcurl.so.4) - Ubuntu desktops without the libcurl4 package
and Steam's runtime: check; macOS: NSURLSession (HTTPS, fine).
Steam: Steam's "verify files" leaves extra files alone; the depot must
not ship a models folder.

## Zip 102 (on top of zip 101): Core ML encoders (with whisper-dev zip 22)
Owner, 2026-11-18 10:30: "can we have coreml for deployment when I
build?" - whisper-dev zip 22 builds whisper with WHISPER_COREML +
WHISPER_COREML_ALLOW_FALLBACK on macOS and collects
libwhisper.coreml.dylib (redist.sh collect / deploy_redist.py take it as
any dylib - no change there). whisper.cpp's own download-coreml-model.sh
says it is "not functional" (an old dataset); the main model repository
has ggml-<name>-encoder.mlmodelc.zip for tiny .. large-v3 and
large-v3-turbo (turbo's added by a later commit; ~1.17 GB; base 38 MB,
small 163 MB, medium 568 MB, large-v3 1.18 GB; tiny's size not listed).
- uModels: EncoderMB in the catalogue; ModelEncoderPath (as whisper.cpp's
  whisper_get_coreml_path_encoder: '.bin' and a -qX_Y suffix dropped,
  '-encoder.mlmodelc'); ModelEncoderUrl; TModelDownload(name, folder,
  AWithModel, AWithEncoder) - Fetch (the old body: HEAD for size / SHA-256,
  .part, checks, rename) for the model and / or the zip, then
  TZipFile.ExtractZipFile beside the model (the zip holds the folder),
  zip deleted, the folder checked. ModelSizeText(0) = 'a few MB'.
- uBuilder: FCoreML = whisper_print_system_info has 'COREML = 1' (logged
  at start). The list: "(Core ML)" / "(no Core ML encoder)". Choosing a
  model not there: the download asks with both sizes, gets both. A model
  there without its encoder: chosen at once, the encoder offered (No by
  default). DownloadDone: "calibrated without its Core ML encoder:
  re-calibrate". LogMachine: the encoder used, or none. History /
  estimate device key MTL0+CoreML when the encoder is used (calibration
  still by device name).
- EpubBuilder README: Core ML paragraph; redistributable_bin README: the
  dylib in EpubBuilder's macOS set.
NOT COMPILED. Names to look at: System.Zip TZipFile.ExtractZipFile,
TDirectory.Delete(path, True).
TO DO on the Mac: whisper-dev ./build.sh (zip 22) -> "Core ML encoder ON";
redist.sh collect -> libwhisper.coreml.dylib there; to Windows,
deploy_redist.py --platform OSXARM64, Deploy; EpubBuilder log "Core ML:
built in"; choose large-v3-turbo -> encoder offered; Re-calibrate (slow
first warm-up); Night Watch turbo with it vs without (rename the
.mlmodelc folder to compare) - Later tests 7.

## Zip 105 (on top of zip 104): justified text (PACKAGE EpubUnumFMX)
Owner, 2026-11-18 11:41: "As we do the layout ourselves can we do it fully
justified please. It'll look nicer on-screen".
- fmx/Epub.FMX.View.pas: TEpubView.Justify (published, default True;
  SetJustify re-lays out). In the paragraph builder, a block the book
  leaves at etaInherit / etaStart is TSkTextAlign.Justify when Justify is
  on and the block is ebkParagraph or ebkListItem; etaCenter / etaEnd /
  etaJustify as the book says; headings, preformatted, table cells left
  alone. SkParagraph does not stretch the last line of a paragraph (or,
  as far as known, a line ended by a hard break).
NOT COMPILED. TO TEST: Moby-Dick / Night Watch in EpubReader - straight
right edge, last lines short, centred titles and poems as before; the
highlight still sits on the word (GetRectsForRange with stretched
spaces); a narrow window / large text: wide gaps (no hyphenation).
Not done, for later: hyphenation (Skia's paragraph engine does not
hyphenate; soft hyphens from a pattern dictionary would have to be
inserted in the layout without changing the word indexes); a reader
setting to turn Justify off (the property is there).

## Zip 106 (on top of zip 105): pasdoc_epub.py - books from Pascal sources (PROTOTYPE)
(The script was NOT applied - owner, 12:32. It is in zips 106 / 107 only;
see "Plans agreed or parked".)
Owner, 2026-11-18 11:45 - 12:00: "take pasdoc output and make a book the
reader could display (with no audio)"; reading the SOURCES (PasDoc's HTML
is table-laid and not XHTML); a different variant of builder (a "maker":
lib/ Epub.Create + a document model + importers - PasDoc, Markdown,
later Delphi's XML doc comments; EpubConsole --create; an EpubMaker
program - not built yet, see the conversation's plan); the owner's DevRel
contact at Embarcadero for the concept (a book of Delphi's own sources
only for them / for personal use - their copyright; the TOOL is ours).
"Run it thru TSteamAPI that's more complex - we can decide on the link
follow depending on how the TSteamAPI test goes".
- NEW tools/pasdoc_epub.py (Python 3, markdown + lxml + PIL for the
  cover): Pascal lexer (comments, strings, directives), {$IFDEF} / {$IF
  Defined()} / {$ELSE} / {$I} (include search: the unit's folder, then
  every folder holding a unit of the book), the interface section ->
  Items (classes / records / interfaces with members by visibility,
  enumerations with values, procedural types, aliases, consts, vars,
  routines; class var / class function / class operator; attributes;
  generics; overloads; variant records with the comment before each case
  label); doc comment = the comment right before (not a trailing remark of
  the line before), or {< } / //<, @exclude. PasDoc tags -> XHTML
  (@abstract, @link, @code, @longCode, @bold, @italic, @nil/@true/@false,
  @param, @returns, @raises, @see, lists, @br, @name, @classname,
  @deprecated; unknown tags as text). @link resolution: this unit's class,
  the class and its ancestors, the unit, any unit; a member the book
  leaves out (protected / private) is named, not linked. Markdown chapters
  (tables, fenced code, GitHub heading anchors; links to other chapters
  rewritten, links into the repository made text, pictures copied).
  Book: title page, --intro, --part NAME FILE.md..., "API reference:
  <package>" per .dpk / .lpk (contains order); nav to class level (units
  with > 120 classes: none); cover (--cover). Checked before writing:
  every XHTML is XML, every book link reaches a file and an id.
- TSteamAPI test (80804ab): 77 chapters, 40 units, 8403 declarations,
  0.7 MB, 0 broken links; @link not found: Exception, TComponent (RTL).
  Audit: every declaration pasdoc_check requires to be documented has its
  comment (6 without = SteamIPAddress_t's variant fields, none in the
  source); spot checks right (TSteamID, TSteamworksState, TSteamAPI FMX).
  Command (from TSteamAPI's root):
    python3 <epubunum>/tools/pasdoc_epub.py --root . --out tsteamapi.epub
      --title "Steamworks for Pascal" --subtitle "Guide and API reference"
      --author G3DGames --cover --intro README.md
      --part Guide docs/UserManual.md docs/Install-Delphi.md
        docs/Install-Lazarus-FPC.md docs/GameEngineIntegration.md
        docs/SteamInputMapping.md docs/Launcher.md docs/Proton.md
      --part Components docs/components/README.md docs/components/T*.md
      --packages packages/Steamworks.dpk packages/SteamworksFMX.dpk
        packages/SteamworksVCL.dpk packages/SteamworksLCL.lpk
- LAYOUT (owner 12:18: "the layout is horrible"; his EpubReader shot:
  README's platform table one cell per line). EpubReader's CSS is bold /
  italic / mono / size / align / indent / margin-left only (no borders,
  backgrounds, vertical margins), so the API pages were a wall of
  headings. Now: a heading per class / record / interface (h2) and per
  group (h3 Properties / Events / Methods / Fields / Types and constants);
  each member ONE line (p.member: monospace, the name bold) with its
  description indented under it (class desc, margin-left 2em); properties
  without accessors ("property AppID: Cardinal - read / write, default
  0"; a re-published "property X;" shows its ancestor's declaration and
  documentation); "In this unit" list of the main types with their first
  sentence; other types, constants, variables, routines as member lines.
  Markdown tables -> one paragraph per row (first cell bold, the others
  "Column: value"; '-' cells left out); --keep-tables for readers that
  draw tables.
- FOUND for the reader: links are drawn but not followed (the API book
  has thousands); tables are cells one under another (the guide's
  Markdown has 72 tables). epubcheck not run here (not installed).
- Core ML result recorded here too (owner 12:06, new app, MTL0 + encoder):
  Night Watch turbo 30:47 = 28.8x (steady 29.6x, 1.0 s per window,
  0.67 s per part), exact 95.2 %, matched 97.8 % (= Metal); expected
  21.1x from the calibration -> whole book / calibration 1.36.

## Zip 110 (on top of the push after d72d7b2): AMD ROCm acceleration as a free Steam DLC
Owner, 2026-11-18 12:34: "For steam we were going to supply HIP as a DLC
- can we do that then we can test Builder on Steam Machine". TWhisper's
HIP.md: the Steam Machine is gfx1102 (rocminfo), /dev/kfd exists on
SteamOS, HIP beat Vulkan there (turbo encode 1.5x; whisper-cli in a
Distrobox with ROCm installed). NOT tried yet: EpubBuilder as a Steam
build in Steam's runtime (sniper) with ROCm BUNDLED beside it (whisper-
dev's container build) - /dev/kfd inside the runtime's container, rocBLAS
/ hipBLASLt finding their kernel folders. Uploads: SteamPipe GUI (owner),
its folder "Deployment" with Win / Mac / Linux -> owner: "could just add a
HIP one?".
- tools/redist.sh: part_lists (shared by collect and package): the GPU
  parts by ldd, each library with ALL its names (stem.so*); FIXED: package
  put libX.so / libX.so.N.M.P of the ROCm / CUDA libraries into CORE (only
  ldd's soname copy went to the part). collect (Linux64) writes
  redistributable_bin/Linux64/parts.txt ("rocm NAME" / "cuda NAME").
  Tested with gcc-made stand-ins (libggml-hip -> amdhip64 / hipblas ->
  rocblas, hipblaslt; three names each; kernel folders; licences): parts
  and packages right.
- tools/deploy_redist.py: parts.txt is not deployed.
- NEW tools/steam_stage.py DEPLOYMENT [--linux Linux] [--hip HIP] [--cuda
  CUDA] [--dry-run]: ROCm files out of Deployment/Linux, Deployment/HIP made
  afresh from redistributable_bin/Linux64 (soname copies as deploy_redist,
  plain files, kernel folders, ROCm licences); CUDA likewise into CUDA (no
  depot yet). Tested on a fake Deployment (Linux keeps the program,
  launcher, libsteam_api, libfmux, core, aladdin; Win / Mac untouched).
- demos/common/uSteam.pas: TSteamDlcState, SteamDlcState (BIsDlcInstalled /
  BIsSubscribedApp), SteamGetDlc (owned -> InstallDLC; not owned -> the
  store page in the overlay, ActivateGameOverlayToStore); links
  Steamworks.Plugin.Apps and .Friends in Steam builds (EpubReader too).
- uBuilder: STEAM_DLC_ROCM (0 = nothing offered); CheckRocmDlc at start
  (Linux Steam builds): an AMD / Radeon device and no ROCm device -> the
  log line and Tools > Get AMD ROCm acceleration (free DLC)...; installed
  but no ROCm device -> says so (debug log: ggml-hip). Debug log line with
  the state.
- EpubBuilder README: the Steam DLC section; redistributable_bin README:
  parts.txt.
NOT COMPILED (no Delphi). Names to look at: Steam.FindPlugin,
TSteamAppsPlugin.BIsDlcInstalled / BIsSubscribedApp / InstallDLC,
TSteamFriendsPlugin.ActivateGameOverlayToStore, k_EOverlayToStoreFlag_None.
OWNER'S STEPS:
1. Linux laptop: tools/redist.sh collect (this zip) -> parts.txt; copy
   redistributable_bin/Linux64 to Windows (kernel folders included).
2. Steamworks, EpubBuilder (5639910): add a DLC "AMD ROCm acceleration"
   (free) -> its AppID; on 5639910's Depots page a new depot for it, OS
   Linux, owned by the DLC (DLC column); the depot in the DLC's packages
   (its store package and the developer comp package, so the owner's
   account has it); publish.
3. uBuilder STEAM_DLC_ROCM := the DLC's AppID; build Steam Linux64;
   Deploy to the Linux laptop as before; copy into Deployment/Linux.
4. python tools\steam_stage.py <Deployment> -> Deployment/HIP.
5. SteamPipe GUI: the new depot -> Deployment\HIP; upload with the build;
   set it live on a beta branch.
6. Steam Machine (the beta branch): EpubBuilder's log - "ROCm0" in the
   device list (calibration) or the DLC line; Tools > Re-calibrate turbo:
   ROCm0 vs Vulkan0. If no ROCm0: the debug log's ggml-hip lines (no
   /dev/kfd in the runtime? kernels not found? HSA_OVERRIDE_GFX_VERSION
   should not be needed for gfx1102).

## Zip 111 (on top of zip 110): no DLC on a Playtest; staging by name
Owner 12:48, Steamworks screenshot of 5639910's Associated Packages: no
DLC section - its packages are "EPubUnum Playtest", "... for store
signup", "... Developer Comp": EpubBuilder ("EPubUnum Creator") is a
STEAM PLAYTEST app (no store page, no monetising; no DLC). So, for the
Steam Machine test: HIP as a SECOND DEPOT of the playtest app itself (OS
Linux, in the playtest's packages incl. the Developer Comp) pointing at
Deployment\HIP - every Linux install gets ROCm (~1 GB); STEAM_DLC_ROCM
stays 0 (nothing offered). The DLC (zip 110's offer) waits until the
builder is a normal app / a real DLC on the base app it ships as.
Owner's SteamPipe GUI folder: first given as the reader's setup (it was
the wrong one - zip 112: the builder has its own).
- tools/steam_stage.py: without parts.txt (redist.sh collect not yet run
  on Linux with zip 110) the parts by NAME_RULES (ROCm / CUDA library
  stems as whisper-dev bundles them, kernel folders, licence prefixes),
  with a warning; a missed helper library stays in the base depot (both
  depots go into the same folder). Tested: same split as with parts.txt.

## Zip 112 (on top of zip 111): the calibration recording in Win64 builds
Owner 13:31: "builder has no aladdin on Win Steam deployment - where
should it go? Automate for next time". Its place: media\aladdin.m4a
beside EpubBuilder.exe (FindCalibrationAudio's first look; Debug /
Release found the repository's copy by searching up from the output
folder, a Steam install cannot). The owner's SteamPipe GUI has a
setup for the builder and one for the reader (folders on his machine).
- tools/postbuild.bat (CRLF kept): EpubBuilder, every Win64
  configuration: :media - robocopy media\aladdin.m4a to
  <output>\media\; missing -> a warning, not a failure (the calibration
  asks for a recording). NOT RUN (no Windows here; read through).

## Zip 113 (on top of 58ebe9b): Python caches ignored
Push 58ebe9b ("Steam Deployed", 2026-11-18) checked = zips 110 - 112 (CR
LF aside); EpubBuilder.dproj: Linux64 121 entries (no ROCm kernels,
aladdin), OSXARM64 29, uHistory / uModels; all .dproj / .deployproj XML
valid; project_check, pasdoc_check 0. It also committed
tools/__pycache__/deploy_redist.cpython-314.pyc (Python's cache, made
when steam_stage.py imports deploy_redist.py).
- .gitignore: __pycache__/ and *.pyc. The owner removes the committed
  one: git rm -r --cached tools/__pycache__

## Zip 114 (on top of zip 113 / 58ebe9b): kept awake while working
Owner, 2026-11-18, Steam Machine: "The steam machine thinks Builder is
"Inactivity" it seems cos it starts it's screen saver after a while".
SteamOS Game Mode judges activity by input only (Kodi / Jellyfin reports
the same); it dims, then SUSPENDS - an hour's build would stop.
- demos/common/uInhibit.pas (new): InhibitStart(ikSleep | ikDisplay,
  reason) / InhibitStop (counted), InhibitText for the logs. Windows
  SetThreadExecutionState; macOS IOPMAssertionCreateWithName
  (PreventUserIdleSystemSleep / ...DisplaySleep); Linux libdbus-1.so.3
  loaded at run time, private connections (exit_on_disconnect off):
  login1 Manager.Inhibit("sleep:idle", app, why, "block") on the system
  bus, kept while the returned fd is open; ikDisplay also
  org.freedesktop.ScreenSaver.Inhibit / UnInhibit on the session bus.
  Never raises.
- EpubBuilder: UpdateControls holds ikSleep while Busy (build, queue,
  calibration, download); a log line each change.
- EpubReader: UpdateControls holds ikDisplay while FPlaying; debug log
  "screen: ...".
- Both .dpr list uInhibit (always, not Steam-only); .dproj NOT shipped -
  the IDE adds the DCCReference from the .dpr.
- NOT KNOWN: whether Steam's Game Mode (gamescope) honours logind /
  ScreenSaver inhibitors. Test on the Steam Machine: start a build, leave
  the controller; the log's "keeping the computer awake:" line says
  which calls worked. If it still dims / sleeps: Steam settings' timeouts
  meanwhile, and look for Steam's own way (e.g. a Steamworks call).

## Steam Machine results (2026-11-18)
- ROCm in Steam's runtime with the bundled libraries works: ROCm0 7.9 of
  8 GB free; medium.en calibration ROCm0 15.3x, CPU 1.5x.
- Vulkan0 calibration crashed EpubBuilder (native crash while loading
  the model; the debug log stops; the crash marker recorded it failed).
  Diagnosis offered: rename libggml-hip.so and calibrate Vulkan alone;
  launch option  %command% > ~/eb-out.log 2>&1  for stderr.
- Night Watch turbo on ROCm0 (MEASURED, 2026-11-18, not calibrated,
  build 2af83eb, whisper.cpp 1.9.5-dev): 23:44 in all, transcription
  1419 s for 52889 s of audio = 37.3x; exact 95.3 %, matched 97.8 % (as
  every turbo run). No stalls: every part ran at about the same rate
  (the first, 9.5 s for 114 s, is the warm-up). The FASTEST whole-book
  turbo so far: 5090 laptop Vulkan 26:08 (steady 87x but ~15 min of
  stalls), M4 Core ML 30:47, M4 Metal 52:18. ROCm 5.8 of 8 GB free with
  turbo loaded.
- Logs: ~/.config/EpubBuilder/ (SteamOS's user is deck).
- The Vulkan0 crash FOUND (stderr via launch option
  %command% > ~/eb-out.log 2>&1, small.en, with and without HIP): not
  ggml, not the driver - gamescope's WSI layer (an implicit Vulkan layer
  in Game Mode) aborts in vkroots.h: Assertion `obj' failed
  (VkDispatchTableMap<VkQueue_T*>::insert), just after "[Gamescope WSI]
  Forcing on VK_EXT_swapchain_maintenance1" - SIGABRT, so our debug log
  just stops. It came and went (one run got through).
  Zip 116: EpubBuilder.sh exports DISABLE_GAMESCOPE_WSI=1 (the layer's
  own disable_environment). Not in EpubReader's launcher: it may present
  through Skia's Vulkan canvas, which gamescope's layer is for.
- The screen is a 4K TV but Valve recommend the Steam Machine runs at
  1080p, so the apps see 1920x1080 (the TV's EDID gives only an aspect).

## Zip 117 (on top of zip 116): the first estimate x 1.35; Vulkan = ROCm here
Steam Machine, Night Watch turbo, MEASURED 2026-11-18:
- Vulkan0 (DISABLE_GAMESCOPE_WSI=1 as launch option, HIP renamed):
  calibration 27.3x; book 23:56, 37.0x; exact 95.2 %, matched 97.8 %.
- ROCm0: book 23:44, 37.3x (above). The same within noise: the ROCm
  depot buys nothing on this machine once gamescope's layer is off -
  Vulkan the default; ROCm kept as an option for AMD cards where Vulkan
  is slow or unstable (drop the 975 MB depot if none turns up).
- Book / calibration: 1.36 (Vulkan, Steam Machine), 1.36 (Core ML, M4),
  1.48 (Metal, M4). The estimate from the calibration alone said 32:18.
- uHistory: HISTORY_BOOK_RATIO = 1.35 applied in HistoryExpect's third
  case (calibration only); its log text said "a whole book usually runs
  slower" - wrong, now "times 1.35 ... faster". Cases 1 and 2 unchanged.
- Owner then calibrated with all three devices (15:59, turbo): CPU 1.1x,
  ROCm0 27.3x, Vulkan0 28.8x (27.3x at 15:18 - about 5 % run to run);
  Vulkan0 chosen. Both GPU libraries loaded together without a crash.
  ROCm0 book / calibration 37.3 / 27.3 = 1.37 - the 1.35 holds.

## Zip 119 (on top of zip 118): Steam's Exit Game saves first
Owner, 2026-11-18: "Steam has a "Exit Game" option from it's own control
panel. This forcibly quits the running app. It would be nice to trap
that and write anything pending" ... "If closed this way record it in
the log". Steam's reaper ends a game with SIGTERM, then SIGKILL (the
grace time was not looked up - keep the handler quick).
- demos/common/uQuitSignal.pas (new, POSIX): QuitSignalInstall(proc) -
  signal() for SIGTERM / SIGINT / SIGHUP writes the number to a pipe; an
  anonymous thread reads it and TThread.Queue's the proc once.
  QuitSignalName, QuitNow (_exit: no finalization, no waiting for GPU
  threads), QuitSignalRecord / QuitSignalLast (<settings>-ended.txt:
  "The last run was ended from outside at ... while ...", read and
  deleted at the next start into the debug log). Windows: nothing
  (Steam may TerminateProcess - not trappable; untested).
- EpubBuilder.QuitSignalled: note file; LogLine "Asked to end (SIGTERM
  ...) while building X (NN %)"; SaveSettings; calibration marker
  deleted (not a crash); queue file saved; the build's log beside the
  output / the calibration log saved; then QuitNow when busy, else
  Close.
- EpubReader.QuitSignalled: note file ("while reading aloud"), debug log,
  Close (FormClose saves the place and settings).
- Both .dpr list uQuitSignal; .dproj not shipped.
- NOT TESTED: built in Delphi on Linux and macOS; Steam's Exit Game on
  the Steam Machine with a build running, then the next start's debug
  log. Delphi's Posix.Signal signal() / Posix.Unistd pipe, _exit assumed.
- Possible next: a build stopped part way keeps its finished parts'
  transcripts and resumes (now it starts again).

## Zip 120 (on top of zip 119): EpubReader compiles again
Zip 119 put TfrmMain.QuitSignalled at the top of the private section,
before its fields: E2169 (no field after a method in one section) and,
following from it, E2250 on TThread.ForceQueue in FormShow. Moved down
with the other private methods (before OpenBook). In uBuilder the
private section with fields is a second one for this reason.

## Zip 121 (on top of zip 120): EpubReader's pad controls (Big Picture, part 1)
Owner, 2026-11-18: "OK, big picture mode"; asked which part first, chose
pad controls (then the big-screen layout, then following Big Picture
switches). No TSteamAPI change.
- tools/gen_reader_input.py (new): EpubReader's tables (set Reader;
  stick Scroll; buttons Up Down Left Right Play Back Again Dark
  SentencePrev SentenceNext ChapterPrev ChapterNext Menu Library),
  written with TSteamAPI's tools/gen_input_mapping.py imported from
  --tsteamapi (its Profile, manifest(), layout(), CONTROLLERS; no
  __pycache__ left there). Output demos/EpubReader/steaminput/ (manifest
  + controllers/reader_controller_<type>.vdf) and
  demos/EpubReader/src/uReaderInput.pas (GENERATED: the files as constant
  line arrays; ReaderInputWrite(folder)). LAYOUT_REVISION 1. Triggers
  bound as "click" (full pull) of the trigger group - NOT YET SEEN on a
  pad.
- demos/common/uSteamPad.pas (new): TSteamPad(set, buttons, stick) -
  Start(manifest) (ISteamInput Start(True), SetInputActionManifestFile-
  Path), Poll (RunFrame, every connected pad, presses with repeats
  400 / 120 ms for chosen buttons, the stick's y), TakeNote (handles
  found, pad count, failure). STEAMBUILD only; elsewhere nothing.
- demos/EpubReader/src/uPadMenu.pas (new): TPadMenu, a list over the
  form (shade, box, rows in a scroll box), Move / SetText / Selected,
  click or tap -> OnChoose (queued), click beside -> OnClose.
- EpubReader uMain: StartPad (after LoadSettings) writes the files to
  <exe>/steaminput (not on the Mac), else <settings>/steaminput, starts
  the pad, tmPad 16 ms; PadPress per place (menu > library > page);
  menu rows Back to the book / Library / Contents (lbToc's entries) /
  Text size < > / Speed < > / Dark / Learn / Exit; library covers chosen
  by direction (nearest centre that way), framed (recCoverSel); Esc on
  the page opens the menu with the keyboard. Debug log: "pad: ..."
  lines (start, actions found, controllers, each non-direction press).
- README (reader): the controls table, the generator line, restart Steam
  after layout changes, partner-site "Custom Configuration (Bundled with
  Game)" -> steaminput/epubreader_controllers.vdf.
- NOT COMPILED, NOT TESTED. Next (owner's order): the big-screen layout
  (UiScale), then Big Picture switches while running.

## Zip 122 (on top of zip 121): three folders, output named after the book
Owner, 2026-11-18: "Can we assume that users will have three folders.
one for input epub, one for import audio and a final one for output.
These will be the default folders when setting up paths. The output
folder should end up with a copy of the epub3 version of the input file
using the same name unless that file already exists in which case add
sequential numbering ... filename_001.epub. While the user may modify
the filename this should be the default".
- uBuilder: FBookFolder / FAudioFolder (were "last used") are now set
  folders, with FOutFolder; defaults <Documents>/EpubBuilder/Books,
  Audio, Output (settings [Folders] Book / Audio / Output; an empty key
  = the default), made at start-up and logged. A pick in a dialog no
  longer changes them. Tools > Books folder... / Audio folder... /
  Output folder... (miFolderClick, item Tag 0 / 1 / 2).
- DefaultOutput(book): <output>/<book name>.epub, else _001, _002 ...
  (taken = a file there or a waiting / running queue job). ShowBook uses
  it (was <book>-synced.epub beside the book); FAutoOut remembers it so a
  new output folder renames only an unchanged name. Output... opens in
  the output's folder. StartJob makes the output's folder.
- README (builder): Folders. NOT COMPILED.

## Zip 123 (on top of 7959de0): gen_reader_input.py finds TSteamAPI
Owner: "--tsteamapi ../TSteamAPI" -> not found (his copy is
..\Steamworks, the old name).
--tsteamapi is optional now: else $TSTEAMAPI, else a sibling folder
TSteamAPI / steamworks / tsteamapi with tools/gen_input_mapping.py; the
error lists what was tried. README: the plain command.
Push 7959de0 ("Steam Controls") checked = zips 113 - 122 (CR LF aside),
but: EpubReader.dproj lacks uSteamPad / uPadMenu / uReaderInput (the IDE
adds them on a save; project_check 3 warnings), and timings.txt was
committed - ~110 "worth a look" lines (copyrighted book text) and ~60
absolute paths: the owner removes it (git rm --cached) and ignores it.

## Zip 124 (on top of zip 123): steaminput/ in the build output
Owner: "where's my manifest + vdfs? SteamAPI's VirtualGamepad put them in
the output exe folder" ... "Doesn't steam need them before we do?" - with
the partner site's "Custom Configuration (Bundled with Game)" Steam reads
the depot's file at launch, before the program's first write; and a
fresh install has none until the first run.
- tools/postbuild.bat: :steaminput (from :reader, every configuration)
  robocopies demos\EpubReader\steaminput to <output>\steaminput (a
  warning when missing). CRLF.
- tools/deploy_redist.py: OWN_FOLDERS - EpubReader.dproj gets Linux64
  DeployFile entries LocalName steaminput\..., RemoteDir .\steaminput\
  (and \controllers\), replaced per platform on each run (not on macOS:
  the reader writes them beside its settings there). Tested on a copy:
  twice in a row = 12 entries, an OSXARM64 run leaves them.
- The runtime write (uReaderInput) stays: same files, so no rewrite.
- Owner: run deploy_redist.py --platform Linux64 again (with the usual
  --skip "^(rocblas|hipblaslt)/") for the Linux entries.

## Zip 125 (on top of zip 124): Controls with Steam's glyphs; Big Picture page only
Owner 18:14 (zip 121 tested on Windows): "Works great on reader. There is
no longer a need for the top menu controls or the sidebar contents when
in big picture mode. One improvement would be a menu option for
Controls. Ideally this shows an image of the controller with buttons
labelled ... For now a list will do ... Make them look a little prettier
too." then "Steam also supply all the controller glyphs".
- uSteamPad: TSteamPadOrigin (Name, Glyph); Origin(index | Count = the
  stick, dark): the bound origin with the shortest name, its PNG
  (GetGlyphPNGForActionOrigin, Medium; Dark / Light style with
  SolidABXY, then plain, then Knockout, then the legacy picture);
  PadName (GetInputTypeForHandle); the pad that pressed last is "in
  hand" (FActivePad, else the first).
- uPadMenu rewritten: TPadMenuItem (Text, Value on the right, Glyphs on
  the left in a column of one width), title (bold, larger) + rule, a foot
  line of hints, rounded box with a faint border, rounded selected row,
  fade-in (TAnimator, 0.15 s), pictures cached per file; SetValue
  replaces SetText.
- uMain: menu rows Back to the book / Library / Contents / Text size /
  Speed / Dark mode / Learn to read / Controls / Exit, values on the right
  (< 18 > with U+2039 / U+203A); FMenuMode (main / contents / controls),
  Back returns to the menu on that row; ShowControlsMenu - 11 rows (Play,
  Back, Again, Dark, scroll a little, page, stick, sentence, chapter,
  menu, library), Steam's glyphs, else Steam's names, else fixed names
  (no pad / no Steam); title "Controls - <pad>"; PadMenuColors (dark
  $FF23262E / accent $FF34405A, light $FFFBFAF7 / $FFD9E5F6); the foot
  names the pad's own choose / back buttons.
- Big Picture: layTop (tool bar), lbToc and Splitter1 hidden at start;
  HideLibrary does not show the panel again there.
- NOT COMPILED. The glyph styles' look on each theme NOT YET SEEN.

## Zip 126 (on top of zip 125): the Mac reader's crash on Exit
TESTED (owner, zip 121 / 125 on Windows): the pad works on the reader;
Controls shows Steam's glyphs of the pad in hand - a PS5 controller gets
its symbols. Desktop mode keeps the tool bar and panel.
Owner 19:04, Mac (Steam, Big Picture, 3440 x 1440 34" - UI scale 2.24
suggested): pad Play / Menu / Back fine, manifest written beside the
settings, 15 actions found, IOKit assertion taken and released; then
Exit from the pad menu: "Crashed at end" - the log stops after "screen:
IOKit assertion ... released" (in FormClose). Crash report asked for;
fixed meanwhile by reading (not proven):
- uQuitSignal: no finalization (closing the pipe there woke the reader
  thread while the RTL was being finalised; its TThread clean-up could
  run on finalised units). Most likely cause: only POSIX has the thread.
- uPadMenu.Destroy no longer frees the rows (the form may have freed
  them already as its children).
- uMain: Exit from the pad menu queues Close (it ran inside tmPadTimer,
  and FormClose frees the pad).

## Zip 127 (on top of zip 126): where the Mac reader hangs on Exit
Owner: "It just hung - steam may have killed it" - no crash report (only
Steam's own .ips). FormClose logs each step (place and settings saved,
sound player freed, done) and uSteam's finalization "Steam: shutting
down" / "shut down", so the next log ends at the step that hangs.
Suspects: FPlayer's AudioQueue dispose, ISteamInput's Shutdown in
TSteamAPI's free, the uQuitSignal thread (zip 126 removed its wake-up).

## Zip 128 (on top of 667070c): zip 123's script again; checks
Push 667070c ("Reader Steam Tests", after 43e5cb9 "Remove local timings
file" and 21fd6cc) checked: zips 124 - 127 as delivered (CR LF aside);
timings.txt gone and in .gitignore; EpubReader.dproj has the three pad
units and 12 Linux64 steaminput entries (deploy_redist run), XML valid;
project_check, pasdoc_check 0. NOT pushed: zip 123's
tools/gen_reader_input.py (the README already says the plain command) -
here again. .gitignore given its last line end.
TESTED (owner, 19:17): Windows desktop and Big Picture, PS5 pad, and a
ROG Ally - "tested perfect". Open: the Mac's hang on Exit (zips 126 /
127, owner tries tomorrow); Steam Deck and Steam Machine (the Linux-only
code: uQuitSignal, D-Bus keep-awake, the steaminput deploy entries); the
default text size in Big Picture (the big-screen layout, next).

## Zip 129 (on top of zip 128): Open a book from the books folder
Owner, 2026-11-18 20:46: "There's no way to open a new book on a Steam
Deck. As it's Steam make the default folder Books next to the
application on Linux and present a list of *.epub in there for hte user
to open via the menu. Apple we'll need an alternate location but Windows
and Linux can use this."
- uMain: BooksFolderDefault - STEAMBUILD and not MACOS: <program
  folder>/Books; else Documents/EpubReader/Books. FBooksFolder (settings
  key "booksFolder" read, never written), made at start-up (falls back
  to the Documents one when it cannot be made), logged.
- Pad menu row Open a book (MENU_OPEN = 1; the rows after it moved down
  one, MENU_EXIT = 9): ShowBooksMenu (MODE_BOOKS) lists *.epub there and
  below, sorted by path, shown as the relative path without .epub, the
  open book marked "open" and selected; none -> one row saying so; the
  foot shows the folder. Choosing queues OpenBook. Back -> the menu on
  Open a book.
- README (reader): Books folder.
- TESTED (owner, 21:18): "ok, stop-gap but it worked". A STOP-GAP: the
  books folder and Open a book are what a Steam Deck has for now; to
  come when it is taken further:
  * the folder chosen in the program (no setting UI yet - only the
    settings file's "booksFolder");
  * Open a book's books shown in the library (covers) rather than a
    list;
  * EpubBuilder's Steam build writing into the reader's Books folder
    (sibling installs under steamapps/common);
  * the Mac: Documents/EpubReader/Books (not beside the .app);
  * Books beside the program may go with an uninstall (README says so).
- Possible next: EpubBuilder's Steam build making its books straight
  into the reader's Books folder (two installs: EPubUnum Playtest /
  EPubUnum - siblings under steamapps/common).

## Zip 131 (on top of zip 130): text at least 24 on a Steam Deck
Owner 21:23: "Deck says text is 20 - if that's pt then it is too small.
Steam suggest 24 min". (FMX font sizes are device-independent pixels,
1/96 in at scale 1; the Deck runs at scale 1, 1280 x 800, 7".)
- uSteam: SteamOnDeck (ISteamUtils IsRunningOnSteamHardware =
  k_ESteamHardwareTypeSteamDeck; False without Steam or SDK < 1.65).
- uMain: SIZE_MIN_DECK = 24 - at start-up a smaller size (the saved 20)
  is raised and logged; Smaller stops there on a Deck. Other machines
  unchanged (default 20, least 10). The TV case comes with the
  big-screen layout (UI scale from Steamworks.FMX.Screen).
- NOT COMPILED. Owner decides on the Deck "in the AM".

## NOTE (owner, 2026-11-18): disk space on Steam hardware
"Steam hardware has relatively small SSDs as standard. We should keep an
eye in disk space when we come to transferring from external sources
(later)". Steam Deck 64 GB / 256 GB / 512 GB models; Steam Machine
512 GB / 2 TB; shared with every game. When books come in from outside
(downloads, copies from another machine, a library service):
- check the free space before copying, say how much a book needs and
  how much is free, and refuse (or ask) rather than fill the disk;
- prefer the SD card / the larger drive where Steam has one.
ALREADY RELEVANT, not just "later":
- EpubReader extracts a book's audio to the temp folder to play it -
  Night Watch's m4b is 840 MB (Mac log, 2026-11-18), deleted on close;
  a crash or a kill leaves it (EpubReader-<hash> under the temp folder).
  Worth: a check of free space before extracting, and clearing old
  EpubReader-* temp folders at start-up.
- EpubBuilder: models (turbo 1.5 GB, large 3 GB) in the program's
  models folder; the transcript, the output EPUB (the audio inside it,
  ~ the m4b's size) and the input copies.

## Zip 133 (on top of zip 132): the book in the build history; Ender in Exile
RESULTS (owner, 2026-11-19), Ender in Exile, turbo, 13:43:48 of audio:
- M4 Core ML in the overnight queue, book TAGGED ru (dc:language) but
  English: 1:22:06, 10.3x (expected 26.2x), exact 61.7 %, matched 62.7 %,
  "poor"; long interpolated stretches (200 - 330 words) where Whisper
  wrote Russian; heard 122457 of 128278 words. Whisper does not obey the
  language strictly: each 30 s window decides afresh, clear English
  pulls many back (they matched), the temperature fallback too.
- The owner fixed dc:language to en (unzip, OPF, re-zip mimetype first
  stored) and built on the RTX 5090 laptop, Vulkan0, Steam build:
  9:59, 83.0x (expected 35.2x from calibration 26.1 x 1.35 - the 5090's
  book / calibration is 3.2, not 1.35: its calibration windows are mostly
  fixed costs), exact 98.3 %, matched 99.6 % (best so far), longest
  stretch 13 words, NO STALLS (every part 80 - 90x; the Night Watch
  stalls were not the GPU or the model). Keep-awake logged on Windows:
  SetThreadExecutionState($80000001).
- The M4 queue's history: 28.8, 26.2, 22.8 then 17 - 19x for the later
  books (one 10.3x, the ru one) - slower through the night; cause not
  known (heat? the books?). Worth a look.
- OFFERED, not yet done: a language check before transcribing (common
  words of the text against dc:language; use the text's and warn), and
  Whisper's own detection on a window of the first part as a backstop.
Zip 133 - owner: "This lacks a title - I would expect the name of the
book or the file at a minimum":
- uHistory: rows get title, language, file (the output's name, no
  folder) - CSV columns 12 - 14; older rows read with them empty; a file
  whose first line is the old header gets the new one on the next write
  (UpgradeHeader). Table columns: When, Book (title, else the file's
  name), Language, then as before (14).
- HistoryExpect leaves out builds matched < HISTORY_POOR_MATCH (90 %).
- uBuilder: TBuildSummary.Title; RecordHistory fills the three.
- README (builder) updated. NOT COMPILED.

## Zip 306 (on top of zip 305): Windows says its performance and efficiency cores
Session 15, owner 2026-11-24 16:55, a screenshot of the 5090's row in
`machines` (model "Legion 9 18IAX10", cores 24, threads 24, perf_cores,
eff_cores and gpu_cores NULL): "Still no cores or GPU memory". NOT
COMPILED. Files: demos/common/uMachine.pas; CLAUDE.md. No .dproj.
- ZIP 302's LENOVO NAME WORKS (seen in that row), and cores / threads
  are stored: 24 / 24 is right for that chip (no hyper-threading).
- perf_cores / eff_cores were Mac and Linux only. Now Windows too:
  uMachine.WinCoreKinds reads GetLogicalProcessorInformationEx (own
  external, WinProcessorInfoEx; the entries read as bytes - the
  efficiency class is byte 9 of each) - the highest class = the
  performance cores, the rest efficiency; one class only = both 0.
  The core count comes from it too (the plain call stops at 64
  processors). EXPECTED on the 5090: 8 + 16.
- gpu_cores IS APPLE'S ONLY (a PC's card has no such count): NULL is
  right there.
- GPU MEMORY IS NOT IN `machines`: it is runs.device_memory_mb, of the
  run's device. The owner was given the query to look
  (SELECT id, created, device_id, device_memory_mb FROM runs ORDER BY
  id DESC LIMIT 10) - ANSWER AWAITED; a NULL in a run made with zip
  300 or later means the device text is not as uBuilder.WebScore
  reads it (then: a line of the debug log's "device: ..." is needed).

## Zip 305 (on top of zip 304): Big Picture's menu is never closed while idle
Session 15, owner 2026-11-24 16:51: "[B] on that menu also dumps you to
a menu-less screen - that shouldn't happen either". NOT COMPILED. Files:
demos/EpubBuilder/src/uBuilder.pas; CLAUDE.md. No .dproj. BUILDER ONLY.
- PadStays: Big Picture and nothing running (no build, calibration,
  download or queue). Then back on the first list does nothing, and
  the menu button goes to the first list from any other (nothing on
  it). WHILE SOMETHING RUNS the menu still closes, to see the progress
  behind it - as before.
- The foot (PadFootParts, for PadFoot and PadFootFor) then names no
  button to close, and none to go back on the first list.
- Outside Big Picture nothing changes. A NEW WAY TO HIDE THE MENU MUST
  ASK PadStays first.
- 16:49, the owner's screenshot "I thought we got rid of the memo?":
  it is the progress panel (title "Idle", "Last: ..."), put behind the
  menu in zip 291 by the owner's choice; told so, offered to hide it
  while idle - NOT ANSWERED.

## Zip 304 (on top of zip 303): Steam's overlay is given frames to draw in
Session 15, owner 2026-11-24 16:48: "Are we loading Steam Overlays? It
appears that getting to Steam menus can be a bit hit + miss". NOT
COMPILED. Files: demos/common/uSteam.pas;
demos/EpubBuilder/src/uBuilder.pas; demos/EpubReader/src/uMain.pas;
CLAUDE.md (with 16:47's note for the non-Steam version, in the
session's log). No .dproj. BOTH STEAM PROGRAMS.
- THE OVERLAY IS LOADED (Steam puts it into the program; the frame
  counter in the owner's 16:18 screenshot is its) - but on Windows it
  is drawn INTO the program's own frames, and these programs draw on
  events: the builder, idle, every two seconds (uRedraw); 13 a second
  during a benchmark. So the overlay opened late and moved in jumps.
  NOT SEEN, taken from how the overlay works and that screenshot.
- uSteam.SteamOverlayFollow(form, busy): a timer of the form (16 ms)
  asks ISteamUtils' BOverlayNeedsPresent (TSteamUtilsPlugin, read in
  G3DGames/TSteamAPI: the call for programs that draw on events) and
  Invalidates the form while it says yes. busy (the builder: FBuild
  or FCalib) -> every sixth tick only, ten frames a second: with
  Steam's frame counter on the overlay may ask for a frame all the
  time, and the drawing shares the card with the transcription - A
  BENCHMARK MUST NOT BE SLOWED BY IT (to check: a benchmark with and
  without the frame counter). An exception (an older redistributable
  without the call): logged once, no more asked.
- Called in both programs' FormCreate beside TWindowRedraw.Create.
  The debug log: "Steam overlay: followed ..." at the start, and a
  line each time the overlay begins to need frames.
- LINUX Game Mode: gamescope draws Steam's overlay itself - nothing
  is expected to change there (the call then says no).

## Zip 303 (on top of zip 302): "Steam leaderboards" and "Website leaderboards"
Session 15, owner 2026-11-24 16:44: "The menu lists Leaderboards and
Website Leaderboards shouldn't the first be Steam Leaderboards" - yes.
NOT COMPILED. Files: demos/EpubBuilder/src/uBuilder.pas, README.md;
CLAUDE.md. Texts only: the desktop's Benchmark menu ("Steam
leaderboards...", "Website leaderboards..."), the pad's Benchmark list
and the list's title. The website's row was "Website leaderboard"
(singular) - plural now, as the owner said it and as it opens all
four. The README's heading "Leaderboards (Steam)" and the log's
"Website leaderboard - <benchmark>: ..." lines are as they were.

## Zip 302 (on top of zip 301): the machine's model has fallbacks
Session 15, owner 2026-11-24 16:40: "Are we using fallbacks if the
more accurate ones aren't populated?" - PARTLY, said field by field;
the model had none but Lenovo's. NOT COMPILED. Files:
demos/common/uMachine.pas; CLAUDE.md.
- The owner's laptop (16:38 - 16:39): a Legion 9i; the registry has
  SystemManufacturer LENOVO, SystemProductName 83EY, SystemVersion and
  SystemFamily both "Legion 9 18IAX10" - zip 301's choice is right.
- THE MODEL, in order - Windows: Lenovo's SystemVersion;
  SystemProductName; SystemFamily; BaseBoardProduct (a PC built from
  parts: its board). Linux: Lenovo's product_version; product_name;
  product_family; board_name. A Mac: the report's "Model Name"; then
  sysctl hw.model ("Mac16,10"). A maker's placeholder counts as
  nothing at every step. Then the site's "Unknown".
- THE OTHERS, as they were: cores -> "N cores (P + E)" when the two
  kinds are known, else "N cores", else the site says "N threads";
  the processor's name from the system, '' when not told; the memory
  as the system counts it; a card's memory from whisper.cpp's device
  text only (the site then looks at the machine's other runs on that
  device - zip 301).
- NO FALLBACK, and none known: an Apple chip's graphics cores (only
  the report has them); the performance / efficiency split outside a
  Mac (Intel's hybrid processors: not read on Windows or Linux).

## Zip 301 (on top of zip 300): a card's memory on the row of an older best; Lenovo's model
Session 15, owner 2026-11-24 16:36: "No GPU info still"; "I looked
at table (no entry for GPU RAM either)". READ on the live page after
the 5090's two runs with build 79bd491: its second line is now "83EY
. Intel(R) Core(TM) Ultra 9 275HX . 24 cores . 64 GB" (zip 298 works:
the machine's facts arrive) - and no memory after "Vulkan". PASCAL
NOT COMPILED; the site tested. Files: web/leaderboard/lib.php;
tools/test_leaderboard.py; demos/common/uMachine.pas; CLAUDE.md.
- WHY THE PAGE SHOWS NONE: the memory is the RUN's (runs.
  device_memory_mb - NOT a column of machines, where the owner may
  have looked: SAID), and a board shows the machine's BEST run - the
  5090's best is older than the field. lb_page now takes, when the
  best run has none, what any run of that machine ON THE SAME DEVICE
  said (COALESCE + a sub-select; the same statement in SQLite).
- NOT KNOWN: whether today's four runs carry it (the owner's "no
  entry" - which table?). If runs.device_memory_mb is NULL in the
  newest rows, build 79bd491 did not send it: then say so - WebScore's
  reading of '(GPU, Vulkan, 22.7 of 23.6 GB free)' was gone through
  again and gives 24166.
- "83EY": Lenovo's SystemProductName is the type's code; the name is
  SystemVersion (Windows) / product_version (Linux) - used for Lenovo
  when it is not a placeholder. NOT SEEN: what that value is on the
  owner's laptop.
- The owner's SteamPipe deployment folder: he expected it to be known
  ("Your history knows it"); it is NOT in this file (no absolute
  paths in tracked files) - ask when it is needed.
- The second run of the four benchmarks (16:31): 0:27.955, 0:35.404,
  1:58.928, 2:07.527 - the fast model moved, the detailed did not:
  spread, as read from the log.

## Zip 300 (on top of zip 299): FFmpeg's programs are no longer shipped
Session 15, owner 2026-11-24 16:25: "we ship ffmpeg.exe + ffplay.exe
etc - are those really required?" - NO: looked through every source
and script - nothing starts ffmpeg.exe, ffplay.exe or ffprobe.exe;
FFmpeg (and whisper.cpp) are used through their DLLs only. They came
along because the Windows scripts copy a folder whole. Files:
tools/postbuild.bat, tools/redist.bat; CLAUDE.md. No source changed.
- redist.bat collect: robocopy of whisper-dev's folder now leaves out
  *.exe (ffmpeg-dev's share was *.dll only already); deploy too.
- postbuild.bat: EpubBuilder's two copies (every backend; CPU and
  Vulkan for Steam) leave out *.exe. EpubReader's copy was av*.dll /
  sw*.dll / postproc*.dll only - it never had them.
- Linux and macOS (redist.sh, deploy_redist.py) copy *.so* / *.dylib
  only: no programs there.
- WHAT IS ALREADY THERE STAYS until deleted by hand: the .exe files in
  redistributable_bin\Win64, in the builder's output folders and in
  the Steam content folder the depot is built from (robocopy without
  /purge does not remove). After deleting them there, the next
  SteamPipe upload drops them from the depot.
- ALSO 16:17 - 16:23, the owner's test build 79bd491 on the 5090 (the
  first compile and run of zips 290 - 299; whisper.cpp 1.9.5-dev):
  "have you altered the benchmarks - they're slower and stall at
  start". The debug log READ (5398 lines): the right device, the
  23 November calibration in use, every score sent and answered. THE
  STALL is each model's FIRST use after the program starts - the first
  30 s of benchmark 1 took 20 s (encode 1866 ms a run against 6.9
  after), benchmark 2's (the other model) 6.6 s, benchmarks 3 and 4
  0.3 / 0.6 s - in the UNTIMED lead-in. THE TIMES: the detailed model
  within 1 % of its best; the fast model 5 - 8 % behind, with 4 and
  48 fallbacks (12 s of batched decoding in the long one) - taken for
  run-to-run spread, NOT PROVEN (benchmarks.csv would show it). The
  owner ran again: "looks better". Nothing of today's is in the timed
  part. OPEN: whether the CALIBRATION times a model's first use
  (not looked at).

## Zip 299 (on top of zip 298): the memory of the device a run was on
Session 15, owner 2026-11-24 16:02: "There doesn't appear to be GPU
memory size (unless its cos I've not run with new code yet)" - it was
NOT in zip 298 (the machine's memory was; a card's own was not).
PASCAL NOT COMPILED; the site tested. No .dproj. Files:
demos/common/uWebBoard.pas; demos/EpubBuilder/src/uBuilder.pas,
README.md; web/leaderboard/lib.php, index.php, schema.sql, README.md,
api/submit.php, api/board.php; tools/test_leaderboard.py; CLAUDE.md.
- It is the RUN's, not the machine's (a machine has several devices;
  the same card is sold with different memory): runs.device_memory_mb
  - ONE MORE ALTER (README; with zip 298's, before the upload).
- The builder takes it from the device's text, where the backend is
  taken from: '... (GPU, Vulkan, 22.7 of 23.6 GB free)' - the figure
  after "of", x 1024 (WebScore; TWebBoardScore.DeviceMemoryMb; sent as
  device_memory_mb when > 0). A run on the processor sends none.
- The page: after the backend, "Vulkan, 24 GB" (whole GB of the 23.6
  a card reports; under 1 GB in MB). board.php: device_memory_mb.
- What whisper.cpp reports for graphics that share the system's
  memory (a Deck, a Mac's Metal) is shown as it is - NOT SEEN.

## Zip 298 (on top of zip 297): which machine - model, cores, graphics cores, memory
Session 15, owner 2026-11-24 15:50: "My Mac M4 now shows as macOS
27.0" (zip 296's lib.php is up; the record read "macOS (Version
27.0.1)"; "Major, minor is fine"). "It would be good to differentiate
Macs more. Memory and CPU/GPU cores are the big things that tend to
make a difference. Is there a way to get the model - e.g. Mac Mini,
Macbook Pro, Mac Studio?" - yes; offered for every machine; 15:52:
"Seems sensible to do it for everything with fallback to Unknown".
PASCAL NOT COMPILED (and no Mac here); the site tested. No .dproj.
Files: demos/common/uMachine.pas, uWebBoard.pas;
demos/EpubBuilder/src/uBuilder.pas, README.md; web/leaderboard/
lib.php, index.php, schema.sql, README.md, api/submit.php,
api/register.php, api/board.php; tools/test_leaderboard.py; CLAUDE.md.
- uMachine.MachineFacts (read once, kept, safe from any thread; the
  builder asks first from a thread at start): Model, Cpu, Cores,
  PerfCores, EffCores, Threads, GpuCores, MemoryGb - '' / 0 = not
  told. NEVER the computer's or the user's name.
  * A MAC: sysctlbyname (machdep.cpu.brand_string "Apple M4 Pro",
    hw.memsize, hw.physicalcpu, hw.perflevel0 / 1 .physicalcpu) and
    the system's report for what only it has in words:
    /usr/sbin/system_profiler SPHardwareDataType SPDisplaysDataType -
    "Model Name: Mac mini", and under "Graphics/Displays:" "Total
    Number of Cores: 10". The four C calls are declared in the unit
    (libc, _PU), not taken from the RTL's units. MachineCpu and
    MachineMemory answer on a Mac now too (they were '' and 0 - the
    record's cpu and memory_gb were NULL).
  * WINDOWS: the registry's HARDWARE\DESCRIPTION\System\BIOS
    SystemProductName (a maker's placeholder - "System Product Name",
    "To Be Filled By O.E.M." ... - is nothing); the cores from
    GetLogicalProcessorInformation.
  * LINUX: /sys/class/dmi/id/product_name (Valve's "Jupiter" /
    "Galileo" are "Steam Deck" / "Steam Deck OLED"; anything else as
    the maker wrote it); the cores from /proc/cpuinfo's physical id
    and core id pairs.
- THE FIELD IS machine_model, NOT model: a score's `model` is whisper's
  model file (the tests caught it - "Mac mini" was refused as "not
  the benchmark's model").
- THE SITE - THE DATABASE FIRST (README, "Changes to a database
  already made": one ALTER, six columns on machines), then the five
  PHP files together. submit.php and register.php keep each fact
  given (lb_machine_facts: a fact left out is NOT emptied);
  lb_machine_text makes the line - the model, the processor when the
  device is not it already, "10 cores (4P + 6E)" / "8 cores" / "16
  threads", "10-core GPU", "16 GB" - or "Unknown" when nothing is
  known. The page: a small second line in the "Ran on" cell.
  board.php: `machine`.
- EVERY ROW SAYS "Unknown" until that machine sends a score with this
  build: nothing is filled in from the old records' cpu.
- Steam's board: the device text ends ", <model>" (after "+ Core ML").
- NOT SEEN: what any machine reads. To check on each after the build:
  the row's second line. Doubts: system_profiler's wording on other
  macOS versions ("Model Name", "Total Number of Cores" under
  "Graphics/Displays:"); what the Steam Machine and the handhelds
  have in product_name; a Windows machine with a board maker's
  placeholder.

## Zip 297 (on top of zip 296): the calibration and the history's estimates by Core ML
Session 15, owner 2026-11-24 15:41 "yes" to zip 296's question (the
calibration and the build history's estimates split by Core ML too).
NOT COMPILED. Files: demos/EpubBuilder/src/uCalibration.pas,
uHistory.pas, uBuilder.pas, README.md; CLAUDE.md. No .dproj.
- CALIBRATION: each model section keeps CoreML = 1 / 0.
  CalibrationForEncoders(settings, Core ML build?, uses(file)) walks
  the model sections: none written -> the state now is written (only
  on a Core ML build: nothing is added to the settings of a machine
  without it); written and not the state now -> the section is put
  aside as [Core ML on Calibration <model>] / [Core ML off ...] and
  the one kept for the state now is brought back. The builder's
  CalibrationEncoders calls it at the end of FillModels (an encoder
  downloaded: the list is filled again) and after CalibrationSave;
  NOT before whisper.cpp is loaded (FWhisperText = ''): FCoreML is
  not known then and every model would look as if it had lost its
  encoder. A model put aside counts as not calibrated - the
  program's own way with a model that has no calibration applies.
  MoveIniSection is shared with CalibrationForWhisper.
- HISTORY: a 17th column `coreml` ('1', '0', '' = not known / no Core
  ML on the machine); the header with `whisper` alone (zip 294's,
  WHISPER_HEADER) is upgraded like the older ones.
  uHistory.HistoryUsesCoreML (a function reference the builder sets
  when the library is loaded, nil when the window closes):
  HistoryExpect leaves out the builds OF THE SAME MODEL made in the
  other state; a row that does not say counts in either. The table's
  Device cell and the summary's lines say "+ Core ML".
- WHAT IS SPLIT NOW, in one place: whisper.cpp's version (the
  website's boards, Steam's boards, benchmarks.csv, the calibration,
  the history's estimates and summary) and Core ML (a score's backend
  and Steam's device text, the calibration per model, the history's
  estimates). NOT: the website ranks a machine's Core ML and Metal
  runs as one row (its best); the calibration's crash list.
- NOT SEEN: any of it on the Mac. To try there: the log's lines at
  the start; Build history's Device column after a build; download a
  model's encoder and see "Calibration: the Core ML encoder of ...".

## Zip 296 (on top of zip 295): a Mac's version on the board; Core ML named
Session 15, owner 2026-11-24 15:35: "If you look at the leaderboard Mac
only says MacOS, no version. Also that run was CoreML, also not
specifically identified (as coreml is different speed from Metal)".
READ on the live page: place 2, "Apple M4 Metal", system "macOS".
PASCAL NOT COMPILED; the site tested here. No .dproj. Files:
web/leaderboard/lib.php; tools/test_leaderboard.py;
demos/common/uMachine.pas; demos/EpubBuilder/src/uBuilder.pas,
README.md; CLAUDE.md.
- THE SYSTEM: a board shows what stands before the first bracket of
  what the program sent; a Mac sent TOSVersion.ToString, whose
  version is only IN the bracket. (1) The site (lb_os): a name that
  begins "mac" and has no digit takes "Version N.N" out of the
  bracket - "macOS 26.1"; the row there now is right as soon as
  lib.php is uploaded, without a new run. The exact text the Mac sent
  was NOT SEEN ("macOS (Version ...)" is assumed from Delphi's
  TOSVersion): if the row still says "macOS", send the machines.os
  value. (2) uMachine.MachineOs on a Mac: "macOS 26.1 (build N)".
- CORE ML: WebScore's backend ends " + Core ML" ("Metal + Core ML",
  "CPU + Core ML") when UsesCoreML(the benchmark's model) - a Core ML
  build and the model's encoder beside it; Steam's device text and
  benchmarks.csv's the same. The website ranks a machine's best per
  benchmark and version, whatever backend: a Mac's Core ML and Metal
  runs are one row, the faster one, with its label.
- THE ROW THERE NOW (said by the owner to be Core ML) - by hand, once,
  in phpMyAdmin; it renames the device of every "Apple M4 / Metal"
  run so far (all the owner's):
    UPDATE devices SET backend = 'Metal + Core ML'
    WHERE description = 'Apple M4' AND backend = 'Metal';
- NOT SPLIT BY CORE ML, ASKED: the calibration and the build
  history's estimates (a model's encoder downloaded later changes its
  speed on the same device; the device there is "MTL0" either way).
- uMachine is compiled by EpubBuilder and BookManager: MachineOs is
  only called for the two websites.

## Zip 295 (on top of zip 294): the website's board from the program, at its own version and row
Session 15, owner 2026-11-24 15:27: "I would also like to add the
ability to open the website using a URL via a button like happens with
link. This will need to pass the version of whisper it is running as
some users may not update. Also opening via a link button would allow
the user to be positioned on their own score in the leaderboard website
if some data is passed back from the submission regarding their run id
for example". PASCAL NOT COMPILED; the site tested here. No .dproj.
Files: web/leaderboard/index.php, api/submit.php, README.md;
tools/test_leaderboard.py; demos/common/uLinkSite.pas, uWebBoard.pas,
uSteam.pas; demos/EpubBuilder/src/uBuilder.pas, README.md; CLAUDE.md.
- THE PUSH b4201ce "pre whisper version bump" (15:06) = zip 293 (all
  its files as here); zip 294 was not in it. Zip 293's site is LIVE
  (read at 15:17: "(whisper.cpp 1.9.5)" on the page, no error) - so
  the two ALTERs ran in MySQL.
- ALSO 15:27: the Miix and the Ally are running 1.9.5's benchmarks
  now (the Miix takes hours). "Do I need to run each test machine
  with latest before 1.9.6 arrives? I imagine ... missing version
  will mean 1.9.5" - SAID: no; everywhere a missing version IS 1.9.5
  (the site, Steam's old board names, a calibration, a history row).
  The page opening on the newest version as soon as one 1.9.6 score
  is there: "the action described is fine".
- THE ADDRESS: WebBoardPage(board, version, machine) (uWebBoard) =
  https://leaderboard.epubunum.com/?b=<slug>&w=<1.9.6>&m=<N>#you.
  w = the version THIS program runs. m = the MACHINE's number at the
  site, not a run's: a run that was not the machine's best has no row,
  the machine always has one. submit.php now answers `machine` and
  `run`; the builder keeps the first as [Leaderboard] Machine
  (FWebMachine) - so a machine is marked only after it has sent a
  score with THIS build or later (0 = the address has no m).
- THE PAGE: ?m=N marks that row (id and class "you", the marker's
  yellow), says "Your computer is in place N, marked below" (or that
  it has no score on this board), shows the hundred rows around it
  when it is further down than the first hundred, and keeps m in the
  benchmark and version links. Not a number: nothing marked.
- IN THE PROGRAM: Benchmark > "Website leaderboard..." on the
  desktop's menu (with or without Steam); the pad's Benchmark list:
  "Website leaderboard" (PADROW_WEB = -13; not in a Big Picture
  without Steam); each of Steam's board pages: "This board on the
  website" above Back (FBoardRows is one fewer for it). BoardOpenWeb:
  Big Picture -> SteamOpenWebPage (uSteam: ISteamFriends'
  ActivateGameOverlayToWebPage - the wrapper's signature was read in
  G3DGames/TSteamAPI: (const pchURL: string; eMode)); the desktop ->
  OpenSitePage (uLinkSite: LinkSiteOpen made general - any of the
  project's sites, the site given; '#' allowed), and Steam's overlay
  when that fails. Rows chosen with the actions there are: nothing
  for Steam Input.
- NOT SEEN: any of it in a program; whether Steam's overlay browser
  opens from the pad's menu in Game Mode (it needs the overlay on).
  The page's window around a row past the first hundred is not in
  the tests (it needs more than a hundred machines).

## Zip 294 (on top of zip 293): the build history and its estimates by whisper.cpp's version
Session 15, owner 2026-11-24 15:03, to zip 293's "the build history's
expected times are not split": "everything should be split as timings
may alter". NOT COMPILED. Files: demos/EpubBuilder/src/uHistory.pas,
uBuilder.pas, README.md; CLAUDE.md. No .dproj.
- <settings>-history.csv: a 16th column `whisper` (HEADER; the header
  before it is PREV_HEADER and is upgraded on the next write, as the
  two older ones are). A row without one is 1.9.5
  (HISTORY_WHISPER_FIRST, HistoryRowWhisper). The builder writes
  FWhisperVersion.
- uHistory.HistoryWhisper (a unit variable, set in FormCreate when the
  library is loaded; '' = every row counts): HistoryExpect and
  HistorySummary look ONLY at the rows of that version - so the time
  a build or a benchmark is expected to take (and the align + write
  share) never mixes versions. After a new version: no builds of it
  yet -> the expectation is the calibration's (itself made again,
  zip 293) until the first book is built. The summary ends with how
  many builds other versions made.
- The history's table (Build history, and its copied text): a 15th
  column "Whisper"; every row is shown.
- A queue's report (.md): its first line ends " - whisper.cpp 1.9.6".
  Its .csv has NO version column (one long Format with 36 arguments -
  left alone uncompiled; a report is one session's, so one version's).
- WHAT IS SPLIT NOW (293 + 294): the website's boards, Steam's boards,
  the Leaderboards page, benchmarks.csv, the calibration, the build
  history's estimates and summary. NOT: BookManager and EpubReader
  (they time nothing); the calibration's crash list ([Calibration
  crashes] - a pair that crashed under one version is still skipped
  under another until Re-calibrate tries it; say if that should be
  split too).
- RULE from now on: anything that keeps or compares a TIME or a SPEED
  keeps whisper.cpp's version with it and compares within one version.

## Zip 293 (on top of bf53bf2 = zip 292 pushed): scores and calibrations know whisper.cpp's version
Session 15, owner 2026-11-24 14:46 "whisper 1.9.6 just came out", 14:55
"Before new version the leaderboard etc need to be version aware. We
were aware of this but I don't know if anything has been put in place
already. For both whisper-dev and twhisper I've version branched them.
main is now 1.96 then". LOOKED: NOTHING was in place (the version was
in the log only). Asked and answered: the website "A board per
version", Steam "New boards per version". PASCAL NOT COMPILED; the
site tested here (SQLite). Files: web/leaderboard/lib.php, index.php,
schema.sql, README.md, api/submit.php, api/board.php;
tools/test_leaderboard.py; demos/common/uWebBoard.pas;
demos/EpubBuilder/src/uBuilder.pas, uCalibration.pas, README.md;
CLAUDE.md. No .dproj.
- THE VERSION is three numbers, '1.9.6' (WhisperVersionNumbers of
  TWhisper's Lib.Version: 'v1.9.6-dev' is 1.9.6; the site's
  lb_whisper does the same). FWhisperVersion in the builder.
  WHISPER_VERSION_FIRST / LB_WHISPER_FIRST = '1.9.5': every score and
  calibration made before today, and any program that says none.
- THE SITE - THE DATABASE CHANGES FIRST (web/leaderboard/README.md,
  "Changes to a database already made": two ALTERs - runs.whisper;
  bests.whisper INTO ITS PRIMARY KEY and its board index; both default
  '1.9.5'. NOT RUN AGAINST MySQL), then lib.php, index.php,
  api/submit.php, api/board.php UPLOADED TOGETHER. A board = a
  benchmark under one version: bests is (machine, benchmark, whisper);
  submit.php takes `whisper` and answers that board's place and
  count; board.php takes `whisper` (none = 1.9.5) and names the
  versions that have a board (`whispers`); the page opens on the
  newest version with a score, links to the others (&w=1.9.5; no
  links while there is one version) and its board links keep the
  version chosen. tools/test_leaderboard.py: the versions' checks
  added; all pass.
- THE DEPLOYED BUILDS send no `whisper`: they stay on 1.9.5's boards,
  rightly, as long as they ship 1.9.5's libraries.
- STEAM: SteamBoardName(option) - BOARD_NAMES' name for 1.9.5 (the
  boards as they are), name + '_whisper_1_9_6' for any other version;
  used to send, to read, and to match the answers (WebSent and the
  website's slug keep BOARD_NAMES). uSteamBoard makes a board with
  the first score sent to it - THEIR NAMES FOR PEOPLE ARE SET ON THE
  PARTNER SITE BY THE OWNER (four new boards per version). A score's
  details [3] (was unused) = the version as a number, 1.9.6 = 10906.
  The Leaderboards page's title ends " - whisper.cpp 1.9.6".
- THE ORDER THAT MATTERS: this zip must be in the build that first
  ships 1.9.6's libraries - an older build with 1.9.6's libraries
  would put 1.9.6's times on 1.9.5's boards (Steam's and the site's).
- CALIBRATION: CalibrationForWhisper(settings, version), called in
  FormCreate when the library is loaded: [Calibration] Whisper (none
  written, a calibration there = 1.9.5) differs -> the model sections
  are moved to [Whisper <old> Calibration <model>], Done is cleared
  (the program finds no calibration and asks, as on a new machine),
  sections kept for the new version are brought back (the owner has
  both versions as branches). The log says which happened. The
  history's and the benchmarks' own figures are NOT told apart by
  version (uHistory's expected times mix them) - not done, say if
  wanted.
- benchmarks.csv: a Whisper column at the end (a file begun before
  has the old heading line and one field more per new row).
- NOT DONE: EpubReader and BookManager do not show or keep the
  version; the website does not show a run's version on a row (the
  board's line says it); 1.9.6 itself was not built or run here - its
  whisper.h is THE SAME as 1.9.5's (both tags fetched and compared),
  ggml's headers are not (TWhisper's direct ggml calls, if any, to be
  checked in its repository), whisper.cpp fixes an assertion in DTW's
  filter and clamps segment ends to the audio's length.

## Zip 292 (on top of zip 291): the leaderboard's page shows words a minute
Session 15, owner 2026-11-24 13:08: "make leaderboard display words
per minute". SITE ONLY: web/leaderboard/index.php;
tools/test_leaderboard.py; CLAUDE.md. No change to the database (a
run's `words` was always kept and the page's rows already had it).
- A column "Words/min" between Time and Speed: the run's words over
  its time (words * 60000 / score_ms), whole, with thousands' commas
  (A Christmas Carol's 28,320 words in 0:01:59.437 = 14,227). Empty
  when a row has no words. Speed (x real time) STAYS beside it - the
  owner said "display", not "in place of"; say if it is to go.
- A narrow screen: the row's lines are who / time, ran on / words a
  minute (with " words/min" after the number), system / speed, power.
- The footer says what it is.
- TAKEN TO MEAN the website's page. NOT changed: api/board.php (its
  rows already carry `words` and `score_ms` - a program can work it
  out), EpubBuilder's own Leaderboards page (Steam's boards: a time
  only) and its calibration texts. Ask if those were meant too.
- test_leaderboard.py checks the figure; all pass. NOT SEEN in a
  browser; not uploaded.
- STILL OPEN from 09:40: the pass over EpubBuilder's 183 LogLine
  calls (zip 291) - no answer yet. Zips 290 and 291 were not in the
  repository at 13:08 (16d27a7 still the last push).

## Zip 291 (on top of zip 290): the log leaves EpubBuilder's window; a message line
Session 15, owner 2026-11-24 09:40: "At the moment we log everything
both to file and to the form. The form's copy is not required any more
as we have access to the log by several other methods now". Asked how
far and where the messages go: "Remove the memo entirely" and "A
status line". NOT COMPILED. Files: demos/EpubBuilder/src/uBuilder.pas,
README.md; CLAUDE.md. No .dproj. EpubBuilder ONLY (BookManager's Log
tab and EpubReader are as they were - not asked).
- GONE: mmLog (the memo), SetLogVisible, miLogClick, the Settings row
  "Show the log" (BPC_LOG = 25 stays as a number, unused, so that no
  other command is renumbered), [View] Log is no longer read or
  written, the five mmLog.Lines.Clear.
- LogLine and ThreadLine: the debug log / the link (BookManager's Log
  tab) / the running build's log - NOTHING IN THE WINDOW.
- WindowLine: the same AND lblMessage - one label under the progress
  panel (two lines on the desktop, large in Big Picture), the window's
  LAST message. Tell goes through WindowLine, so on the desktop its
  text is there; in Big Picture also the OK box, as before.
- BIG PICTURE's window behind the menu: the progress panel (title 34,
  the rest 24) and the message line (24) - no longer the log.
- layBottom is 50 higher on the desktop (the message line's room).
- THE GAP TO KNOW: 183 calls are LogLine. Some answer a click and were
  read in the window ("Nothing in the queue to run...", "link: not
  joined to an account - ...", a folder not made): they are now in the
  file only. NOT gone through one by one in this zip - OFFERED: a pass
  that makes the ones the user must see WindowLine or Tell. Until
  then: what a person must see goes through WindowLine or Tell, never
  LogLine (a rule from now on).
- The README's "the log says ..." now means the files and BookManager's
  tab; its "Progress, and the log" section says so.
- NOT SEEN: the window. Likeliest faults: the bottom area's heights
  (the panel's four lines plus the message line), a long message cut
  after two lines on the desktop.

## Zip 290 (on top of 16d27a7 = zip 289 pushed): Open in browser beside the code
Session 15, owner 2026-11-24 09:33: "Non-Steam devices at least should
have a browser. It would be nicer if there was a button that
automatically opened your default web browser at the desired page.
This way a user may open it manually or just click a button".
NOT COMPILED. No .dproj, no .dpr (the function is in uLinkSite, which
both programs have). Files: demos/common/uLinkSite.pas;
demos/BookManager/src/uManager.pas, README.md;
demos/EpubBuilder/src/uBuilder.pas, README.md; CLAUDE.md.
- THE PUSH 16d27a7 "link" (09:24) was checked: all 143 files as the
  working copy here (three .bat by CR LF only, as before); zip 289 is
  in, schema.sql too (owner: "I purposely left the sql out - sorry,
  that was a bad idea").
- LinkSiteOpen(url) (uLinkSite): Windows ShellExecute "open", macOS
  `open`, Linux `xdg-open` in the background. ONLY an address that
  begins with LINK_SITE_URL and is made of plain characters is opened
  (it comes from the site's answer and goes to a shell); at most 200
  characters.
- The address is the code's own (TLinkSiteCode.Url, .../?code=ABCD-
  EFGH): the page has the code in its box, and keeps it through the
  sign-in when the browser is not signed in. The owner still presses
  Add it there (a page that added on arrival could be made to add by
  a link from elsewhere).
- BookManager: "Open in browser" in the link site's row, left of
  Cancel. EpubBuilder: the same in the account bar, NOT SHOWN IN BIG
  PICTURE (btnSiteOpen.Visible := not FBigPicture - no browser comes
  to the front in Game Mode; the pad's box is unchanged, so nothing
  for Steam Input). A Steam build on the desktop shows it too.
- Linux inside Steam's runtime: whether xdg-open reaches the host's
  browser from the container is NOT KNOWN; the log line says when the
  system refused, not when nothing showed.

## Zip 289 (on top of 5b7de61 "link"): zip 283's three files, which the push lacks
Session 15, owner 2026-11-24 09:18: "check the repo + sync". The push
5b7de61 "link" (09:18) was compared with the deliveries file by file:
it IS zips 282 and 284 - 288 (25 of 26 files the same to the byte;
the .sh files still executable) - but ZIP 283 IS NOT IN IT:
web/link/lib.php, web/link/README.md and tools/test_link.py are zip
282's. web/link/index.php is zip 284's, which CALLS ln_setup_hint -
a function only zip 283's lib.php has. On the page that works (the
call is in the failure's branch) but a settings or database failure
would now end in PHP's fatal error, not in "The link site is being
set up". THE LIVE SITE is likely the same pair (at 08:12 the page had
no hint line: 283 was never uploaded) - upload lib.php with this zip.
Files (unchanged since zip 283, sent again so that 283's older
index.php is not taken by mistake): web/link/lib.php, README.md;
tools/test_link.py; web/link/schema.sql (see below); CLAUDE.md (this section, and the pad fallback
parked at 09:12 in the session's log). test_link.py: 56 checks pass.
- ALSO NOT IN THE PUSH: web/link/schema.sql (zip 282; .gitignore
  does not leave it out - it was not added, or not copied in). The
  database was made from it, so the owner has it somewhere; it is in
  this zip again, unchanged.
- The working copy here = 5b7de61 + this zip.
- The owner's test of Settings > Account in Big Picture was starting
  (09:13 "About to test...", 09:15 "How do I link big picture?" - the
  steps said back); no result yet.

## Zip 288 (on top of zip 287): uLinkSite's four hints
Session 15, owner 2026-11-24 09:05: EpubBuilder BUILDS ("Success",
both configurations pasted) with zips 284 - 287 - so zip 287's six
E2250 were what followed from the E2169. Four hints, uLinkSite only:
H2077 twice (Post: Value and HttpStatus set before the try and never
read - taken out) and H2443 twice (TJSONArray's inline getter:
System.Generics.Collections added to the implementation's uses, as
uManager and uBuilder have it). Files: demos/common/uLinkSite.pas;
CLAUDE.md. No hint named uLink, uBuilder or uManager. NOT SEEN: it
running; BookManager's build.

## Zip 287 (on top of zip 286): uLink compiles - a field after methods
Session 15, owner 2026-11-24 09:02, the first build of 284 - 286:
uLink.pas(163) E2169 "Field definition not allowed after methods or
properties", then six E2250 at the TThread.Queue calls (lines of the
old code too) and F2063. Files: demos/common/uLink.pas; CLAUDE.md.
- Zip 286 put TakesTickets' getter and setter between TLinkServer's
  FIELDS (after FTakesTickets, before FTicketWrong). Moved to the
  private methods (before CommandGet).
- The six E2250 are TAKEN FOR what followed from it (they name Queue
  calls that were there before and compiled) - NOT SURE until it is
  built: if they stay, send the lines.
- RULE: in a class, a new accessor goes with the METHODS, never beside
  its backing field; the other classes touched in this session were
  looked through for the same (none).

## Zip 286 (on top of zip 285): EpubBuilder's Account row - the code in the window and in Big Picture
Session 15, owner 2026-11-24 08:57: "Do the big picture Steam version
then I can do a steam deployment". NOT COMPILED. No .dproj, no .dpr.
Files: demos/EpubBuilder/src/uBuilder.pas, README.md;
demos/common/uLink.pas; CLAUDE.md.
- SETTINGS > "Account at link.epubunum.com" (BPC_ACCOUNT = 38, on the
  Settings page of the desktop's menu and of Big Picture's; its value
  "joined" / "not joined"; there whenever the link runs - Steam or
  not). Chosen: the menu hides, SiteAccount asks the site in a thread
  (made known first, under the link's id; no name sent). No account
  has it: ShowSiteClaim - a BAR at the top as the pairing's (pnlSite:
  the text, the code at size 34, the time left, Cancel) and, in Big
  Picture, the pad's BOX (ShowText "Account", NextTitleCentered,
  NextWidthShare 0.6, the boards' yellow frame; one row, Cancel; the
  foot PadFootOf([BP_CHOOSE, BP_BACK], ['', 'cancel']) - glyphs or
  keys as the pairing's box). tmSite: every second the time left,
  every `interval` (5 s) the site asked; typed -> bar and box close,
  Tell says it is in the account (Big Picture: an OK box); run out
  (10 minutes) -> closed and said. An account has it already: Tell.
- STEAM INPUT: nothing new is bound - the row is chosen and the box
  answered with the actions there are; no key is named in the
  program's code, no button in a text. tools/gen_reader_input.py and
  LAYOUT_REVISION are untouched.
- FSitePad is to the account's box what FPairPad is to the pairing's:
  set False wherever a question replaces the box (the three places
  FPairPad is). A pairing asked for while the account's box shows
  gets its bar only.
- uLink: TLinkServer.TakesTickets (under the server's lock; False at
  first) - /info's "ticket" and /pair/ticket follow it. TicketCheck is
  now set ONCE before Start by EpubBuilder, always; TakesTickets turns
  on when an account has it (SiteKeep) - zip 285 set TicketCheck only
  with a key, which could not change after Start without a race.
- SiteKeep (one place): FSiteKey / FSiteClaimed, GSiteKey for the
  link's threads, [Link] SiteKey / SiteClaimed, FLink.TakesTickets.
  SiteActivated (--activate) uses it too.
- The new methods that use BOARD_FRAME_DARK stand AFTER its const
  block (before miSettingsClick): a const must be declared above its
  use - the first try had them beside StartLink.
- TO TRY (owner): Settings > Account on the desktop and in Big Picture
  (the box: wide, yellow, centred title, Cancel with the pad's glyph);
  type the code on the site from a phone; the row says "joined";
  BookManager (Account... done too) > Pair... says "Paired without a
  code". Cancel and the ten minutes. A pairing by code while the
  account's bar shows.
- NOT SEEN: any of it running. Likeliest faults: a compile error; the
  bar's layout on a small screen (the code label is 250 wide); the
  Settings page one row longer in Big Picture.

## Zip 285 (on top of zip 284): BookManager and EpubBuilder use the link site
Session 15, owner 2026-11-24 08:50 "OK" (to: the Steam builds may carry
the optional claim; the order wiring -> names -> premium). NOT
COMPILED. TWO .dproj IN THE ZIP (BookManager.dproj, EpubBuilder.dproj:
one DCCReference line each for uLinkSite.pas, on top of ab4923a's -
the Platform line untouched). Files: demos/BookManager/src/uManager.pas,
BookManager.dpr, BookManager.dproj, README.md; demos/EpubBuilder/src/
uBuilder.pas, EpubBuilder.dpr, EpubBuilder.dproj, README.md;
tools/gen_projects.py (BookManager's unit list); CLAUDE.md.
- BOOKMANAGER: a button Account... beside Pair... - makes itself known
  to the site (no name sent), asks whether an account has it, else
  shows a row "Sign in at link.epubunum.com and type this code
  there: ABCD-EFGH" and asks every 5 s (tmSite) until it is typed, the
  code runs out or Cancel. [Link] Id / Key / Claimed in BookManager.ini.
  Pair...: when claimed, PairWithTicket first (a thread: the builder's
  /info "ticket", TLinkSite.Ticket, TLinkClient.PairTicket); when that
  does not work, WHY is said and the 6-digit code is asked for as
  before (PairWithCode). The site's calls run in anonymous threads,
  one at a time (FSiteBusy); GManagerGone drops an answer that comes
  after the window closed.
- EPUBBUILDER (this zip: the server's side, and joining an account
  WITHOUT a screen's page): --activate KEY (or --activate=KEY) -
  Register when not known, Claim, the log says so; [Link] SiteKey /
  SiteClaimed in its settings; with SiteClaimed the switch is left
  alone (a used key sent again would count as a wrong one at the
  site). TicketCheck := SiteTicketCheck only when it has a key or
  --activate is there - else /info says "ticket": false and no
  outside site is ever asked. The site's install id IS the link's id
  ([Link] Id): it is never changed (the paired programs know the
  builder by it); a site that forgot it (401) has it made known again
  under the same id. GSiteGate guards the id and key (the link's
  server threads read them).
- NOT IN THIS ZIP: EpubBuilder's own claim PAGE (a code shown in the
  window and in Big Picture - wide, yellow frame, centred title; its
  menu entry through Steam Input's tables; glyphs) - it comes with
  the leaderboard names, which need it on the owner's seven machines.
  Until then a Steam machine joins with --activate in Launch Options.
- An installation has NO LABEL yet (nothing but the program's name and
  the system is sent): several BookManagers of an account look alike
  on the site's page. To do: a name typed ON THE SITE (Rename), not
  taken from the computer.
- TO TRY (owner): build both (not Steam builds needed: any build);
  BookManager > Account... > the code on the site; the site > Make a
  key > EpubBuilder --activate KEY; then Pair... on a BookManager that
  has no pairing with that builder ("Pair again..." asks too): it
  should say "Paired without a code". Then the other way: an
  EpubBuilder NOT in the account must still pair with the code, with
  the reason said first.
- WAITING FOR THE NEXT STEAM DEPLOYMENT: this zip's EpubBuilder (and
  zip 284's uLink) - no hurry, nothing in a Steam build changes until
  --activate is used.

## Zip 284 (on top of zip 283): the programs' side of the link site - the units
Session 15, owner 2026-11-24 08:32 "OK" to: a shared unit beside
uLink, /pair/ticket in uLink, BookManager and EpubBuilder as the first
pair. THIS ZIP IS THE TWO UNITS ONLY - no program calls them yet, no
.dpr / .dproj changed. NOT COMPILED (no Delphi here; pasdoc_check and
project_check pass). Files: demos/common/uLinkSite.pas (new),
demos/common/uLink.pas; web/link/index.php; CLAUDE.md.
- THE SITE WORKS ON THE HOST (owner 08:16 - 08:19): the settings file
  had been "in wrong place" (which folder: asked, not said); the
  sign-in mail came to the INBOX and its button signed in (a
  screenshot of "Your installations"). schema.sql loaded into MySQL
  (database "activate" - a database of its own, not the
  leaderboard's). The owner pasted the settings into the chat: told to
  change the password and the salt; neither is written anywhere here.
- uLinkSite (System.Net.HttpClient, as uWebBoard): TLinkSite.Create(
  app, install id, key) then Register / Claim / AskCode / Status /
  Ticket / Check / Release - each BLOCKS (15 s twice at most) and
  raises ELinkSite (Status = the HTTP status, 0 = not reached). The
  install id is uLink's own (the builder's id); the site writes it
  lower case - LinkSiteId. NOT in any project yet: add it to the .dpr
  and .dproj of the program that first uses it (pull first; say so).
- uLink: TLinkServer.TicketCheck (a function reference, set before
  Start; called in the server's threads); POST /pair/ticket?client=&
  ticket= gives the token as /pair/confirm does (OnPaired fires the
  same) - 404 when TicketCheck is not set, 403 with the site's words,
  429 after LINK_TICKET_TRIES (5) refusals in a minute. /info says
  "ticket": true / false. TLinkClient.PairTicket. uLink itself does
  NOT use uLinkSite or HTTPS: the program joins the two (TicketCheck
  := a function that calls TLinkSite.Check). Until a program sets
  TicketCheck nothing changes for it - so NO Steam rebuild is needed
  for this zip, but uLink.pas is compiled by EpubBuilder and
  BookManager at their next build: a compile error would show there.
- web/link/index.php: the space under the dark header was missing
  (main.wrap's padding lost to .wrap's - seen in the owner's
  screenshots); a sign-in link opened by a browser already signed in
  goes to the plain address (the used token left the address bar).
  Not uploaded unless the owner wants it now - with the next upload.
- NEXT (the wiring; ASK FIRST what is below): the install's key and
  "claimed" in each program's settings; BookManager: Register +
  AskCode shown in its window + Status asked; when a builder's /info
  says ticket and both are claimed, PairTicket in place of the code
  box. EpubBuilder: TicketCheck, and its own way of being claimed (a
  code on a page - wide, yellow frame, centred title - and/or
  --activate KEY for a headless start).
- 08:42 - 08:50, THE NAMES AND A PREMIUM TIER (owner; NOT BUILT):
  "one thing here that is a concern is some idiot choosing an
  offensive public name". Offered: names the site makes up, or typed
  names that wait for his approval. Owner: "both plus a third. A
  premium account (which is very much like 2) that some users or
  companies can purchase that allows far more detailed information to
  be stored about their devices including images, detailed device
  specs etc. These would be useful for research, the motivated user
  or reviewers to record extra information." So THREE TIERS: (1) a
  GENERATED name, public at once (pick / re-roll, no free text);
  (2) a TYPED name, hidden until the owner accepts it (shown as the
  generated one meanwhile); (3) PREMIUM, bought: a page per device
  (photos, full specs, notes), notes on a run - all of it waiting for
  approval too. Guards said and not objected to: letters, digits and
  spaces only, 3 - 20; no name twice; a change at most now and then;
  taken off by hand. accounts gets a `tier` from the start. Said of
  premium, TO CHECK BY THE OWNER: a payment provider that is the
  seller (VAT) or Stripe; a paying account's mail address must be
  STORED (with consent - today only its hash is); image limits and
  re-encoding; Steam's rules on purchases outside Steam - keep
  premium a matter of the website, never named in a Steam program.
  ORDER AGREED ("OK"): the wiring (zip 285), then the names on the
  leaderboard with an approval page for the owner, then premium
  (device pages first, the owner the only premium account; payment
  last).
- THE OWNER'S IDEA (08:32), NOT BUILT: "we could optionally link
  devices to an owner so I could claim ownership of all my 7 devices
  (more when we get iOS, Android + tvOS) I could then have an
  identifier in the leaderboard rather than anonymous". SAID BACK: it
  fits - an account that owns installs is what the link site is. What
  it needs: (1) the account gets a PUBLIC NAME, chosen on the link
  page (optional; empty = Anonymous as now); (2) EpubBuilder is
  claimed like any install - so the claim (a code shown, typed on the
  site) must be IN THE STEAM BUILDS too, optional and off until used
  (his seven machines run Steam builds; the constraint is that a Steam
  program never NEEDS the site - asked whether optional is right
  there); (3) the leaderboard learns which account a machine is of:
  the two sites have two databases ("epubunum", "activate") and the
  program has two identities (uWebBoard's install id + key, uLink's
  id + the link key) - the safe way is that the program proves both:
  it asks the link site for a short-lived pass and sends it with its
  score; submit.php asks the link site whether the pass is good and
  whose it is, and puts the machine under a player of source 'link'
  (players / machines.player_id are there for it: "machines of one
  Steam account are one person's" already works so). A name is public:
  the page must say so, and a name can be taken off by hand (players.
  banned is there). DECISIONS FOR THE OWNER before it is built: the
  Steam builds (above); one name for all an account's machines, with
  the machine's own label beside it (machines.label is there).

## Zip 283 (on top of zip 282): the link page says which setting-up step failed
Session 15, owner 2026-11-24 08:03 "link site setup issues" + a
screenshot: zip 282 uploaded, the page says "The link site is being
set up" (read from here too; the address alone first gave Plesk's
default page - its index.html was still there - then the page). Which
of the causes it was could not be seen from here (the log is the
owner's). Files: web/link/lib.php, index.php, README.md;
tools/test_link.py; CLAUDE.md. Site only.
- Under the message, a line "For whoever is setting it up: ..."
  (ln_setup_hint): no settings file found / the file lacks dsn, salt
  or site / the database refused, error N (the driver's number only) /
  the tables are missing. NEVER a name, a path or a password (tested:
  the page has neither the settings' password nor the folder).
- A signed-out page now reads one row's worth of `accounts`, so a
  database without its tables shows at "Look" and not at the first
  sign-in.
- THE LIKELIEST CAUSE SAID TO THE OWNER: `site` - the leaderboard's
  settings file has none, and a copy of it is "incomplete" here.
- The leaderboard's page was left as it is (its reason stays in the
  log); offer the same there if wanted.
- tools/test_link.py: 56 checks, passed.

## Zip 282 (on top of ab4923a = zip 281 pushed): link.epubunum.com, the site
Session 15, owner 2026-11-24 06:40: "link". SITE ONLY - no Pascal, no
.dproj, nothing for a build. Files: web/link/ (new: index.php, lib.php,
schema.sql, config.sample.php, .htaccess, README.md, api/register.php,
claim.php, code.php, status.php, ticket.php, check.php, release.php);
tools/test_link.py (new); .gitignore (web/link/config.php,
link-config.php); CLAUDE.md. Built as the leaderboard's site is (the
same settings-file places, JSON answers, SQLite-testable statements);
functions ln_*, the environment's LN_CONFIG for tests.
- DECIDED (owner, the three answers): an account signs in by a MAILED
  LINK, no password; an install WITHOUT A SCREEN joins with a ONE-TIME
  KEY made on the site and given to the program at one start
  ("BookServer --activate ABCD-EFGH-JKMN" - the page's example: the
  switch's name is this zip's suggestion, no program has it yet);
  ACTIVATION ONLY - no addresses kept, no finding outside the local
  network.
- THE SCHEME: (1) an install REGISTERS (install_id = the id uLink
  announces, app, label, os) and gets a key, as the leaderboard's.
  (2) an account CLAIMS it: claim.php with the one-time key, or - with
  a screen - code.php gives 8 letters to show (and a url for a QR
  code), the owner types them on the site, the install asks status.php
  every 5 s. (3) PAIRING WITHOUT THE 6 DIGITS: the client asks
  ticket.php for the server's install id, hands the ticket to the
  server on the local network, the server asks check.php and learns
  which install the client is - then gives its own X-Link-Token as
  after a code. The site is not needed again. (4) release.php: an
  install leaves; the page removes one, signs out, deletes the account.
- THE MAIL ADDRESS IS NOT STORED (this zip's choice, not asked): the
  account is the salted hash of the address; the link goes to what was
  typed. So the site cannot write to anyone - a mailed approval
  (turned down today anyway) would need the address kept.
- A sign-in link opens a page with a BUTTON; only the button signs in
  (mail scanners open links).
- Times and limits: lib.php's constants; web/link/README.md lists them.
- THE SALT IS NEVER CHANGED: every hash is made with it (the
  leaderboard's only counts senders; this one's is the accounts).
- NOT DONE HERE: schema.sql not run against MySQL; mail() not tried on
  the host (it needs the mail_from address made in Plesk); the page
  not looked at in a browser (its markup and styles follow the
  leaderboard's page); nothing uploaded.
- STEAM: nothing in a Steam program needs this site (the constraint of
  "TENTATIVE: a headless EpubBuilder" stands); the page's footer says
  so.
- Run before a delivery that touches web/link: python3
  tools/test_link.py (52 checks; passed for this zip).

## Zip 281 (on top of zip 280): session 14's handover
Owner 2026-11-23 21:21: "write up a session handover in claude.md".
CLAUDE.md only: "Handover - READ THIS FIRST (latest: session 14)" at
the top - where it stands, what was made, what the power readings
showed, the rules added, what waits for a build, what is not
confirmed, what is decided, what is next. Session 13's handover keeps
its place under it, its "Session 14" entries now headed "Session 14 -
the log".

## Zip 280 (on top of zip 279): the host's system, not "Steam Runtime 3"
Session 14, owner 2026-11-23 21:00, zip 279 uploaded: "Doesn't actually
say SteamOS" - the three Linux machines all read "Steam Runtime 3"
(the site read from here): Steam runs a Linux program in a container
whose /etc/os-release is the runtime's. NOT COMPILED. Files:
demos/common/uMachine.pas (MachineOs), uWebBoard.pas;
web/leaderboard/api/submit.php, README.md; tools/test_leaderboard.py;
CLAUDE.md. No .dproj, no ALTER TABLE.
- MachineOs (Linux): NAME + VERSION_ID (else PRETTY_NAME) of the first
  of /run/host/etc/os-release, /run/host/usr/lib/os-release,
  /etc/os-release, /usr/lib/os-release; elsewhere TOSVersion.ToString.
  THAT /run/host HOLDS THE HOST'S FILE in Steam's container is what
  the container's makers describe - NOT SEEN HERE; if a machine still
  says Steam Runtime, `cat /run/host/etc/os-release` in the program's
  environment is the question.
- Sent with EVERY score now; submit.php puts it in machines.os - so the
  machines already registered are put right by their next run, and an
  upgrade shows.
- MachineText (the logs' line) is as it was.
- uMachine is BookManager's too: it need not be rebuilt for this.

## Zip 279 (on top of zip 278): the operating system on the website's boards
Session 14, owner 2026-11-23 20:55: "we should add os to leaderboard".
THE SITE ONLY - nothing to compile, no ALTER TABLE (machines.os has
been filled at registration since zip 273). Files: web/leaderboard/
lib.php (lb_os; lb_page reads m.os), index.php (a System column),
api/board.php (os), README.md; tools/test_leaderboard.py; CLAUDE.md.
- lb_os: what stands before the first bracket of what the program sent
  (TOSVersion.ToString): 'Windows 11', 'SteamOS', 'Ubuntu 24.04.3 LTS'.
  WHAT THE PROGRAM REALLY SENDS ON LINUX AND macOS IS NOT KNOWN HERE -
  the owner's page will show it; lb_os is where to shorten further.
- It is the system at REGISTRATION: an upgrade does not change it (the
  program could send it with each score - not done, not asked).
- ZIP 278 WORKS (owner 20:23, 20:52; the site read): AMD on Linux
  inside Steam's container - the Ally 31 W, highest 43 W, NO cap (its
  power control is not the driver's); the Steam Machine 62 / 35 W
  (detailed / fast), cap 110 W. NVIDIA on Linux under Steam works too
  (the IdeaPad's 1650: 51 / 29 W of 70 - 85 W). Four machines on the
  site; the Deck is still to run (set its TDP slider to the maximum -
  owner).
- DECIDED: Apple's power is NOT read (owner 19:48: "OK, forget Apple" -
  no public way; the private one could crash and change). AMD ON
  WINDOWS WAITS for Windows on the Steam Machine ("probably next
  week"), then the Deck and the Ally.

## Zip 278 (on top of zip 277): AMD cards' power on Linux
Session 14, owner 2026-11-23 19:30: "AMD have 18.72% market - possibly
worth trying?" (his figure). NOT COMPILED - and the AMD part cannot be
tried here at all. Files: demos/common/uGpuPower.pas (rewritten),
uWebBoard.pas (comments), demos/EpubBuilder/src/uBuilder.pas,
README.md; web/leaderboard/index.php (the footer), api/submit.php,
schema.sql, README.md (words); CLAUDE.md. No .dproj, no ALTER TABLE.
- WHY LINUX ONLY: there it is a file - /sys/class/drm/cardN/device
  (vendor 0x1002) /hwmon/hwmonM/power1_average (a card of its own) or
  power1_input (a processor's graphics: THE WHOLE CHIP), microwatts;
  power1_cap the limit where there is one. On Windows it needs AMD's
  ADL / ADLX library, and the owner's three AMD machines (Steam
  Machine, Deck, Ally) all run SteamOS - nothing could try it.
- uGpuPower: one reader, two kinds of card (TGpuPower.Vendor 'nvidia' |
  'amd'); FindNvidia / FindAmd each fail alone. GpuPowerFind: NVIDIA by
  name; AMD when the description says AMD / Radeon / RADV and the
  machine has exactly ONE AMD card (the files carry no name). The
  builder does not ask for a run on the processor (an AMD processor's
  name would pass). The log's line names the benchmark's device.
- THE LOW / MEDIUM / HIGH FINDING (5090 laptop, the site read from
  here): the maker's profile IS the card's limit - about 92 / 120 /
  175 W. The detailed model wants ~115 W, the fast one ~67 W: medium =
  high within 2 %; low costs 45 - 65 % (the fast model too - the
  processor is held back as well, unseen). The limit drifts (116 - 127
  on medium) and the highest readings pass it (the limit is read once,
  at the start).
- The IdeaPad's GTX 1650 on Linux: nvidia-smi shows 1 W of 70 W,
  libnvidia-ml.so.1 is there - a run under Steam was started at 19:10
  (does Steam's container pass the library? NOT KNOWN YET).
- NOT KNOWN: which of power1_average / power1_input the Deck, the Ally
  and the Steam Machine have, and that /sys is readable inside Steam's
  container.

## Zip 277 (on top of zip 276): the name is written "epubunum"
Session 14, owner 2026-11-23 18:43: "Can we make the name epubunum
everywhere it's displayed to the user - no caps". NOT COMPILED. Files:
web/www/index.html, web/leaderboard/index.php (every occurrence: the
titles, the mastheads, the sentences, the footers),
demos/common/uEpubUnum.pas (two messages), README.md and the four
demos' README.md (prose only), CLAUDE.md.
- THE RULE (STANDING): where a user reads the name it is "epubunum",
  also at a sentence's start. The programs keep their names
  (EpubBuilder, EpubReader, BookManager - not asked).
- NOT CHANGED, ON PURPOSE - SAID TO THE OWNER: the folders
  (EPUBUNUM_NAME = 'EpubUnum': Documents/EpubUnum, %APPDATA%\EpubUnum,
  ~/.config/EpubUnum - a rename would lose every user's settings and
  books on Linux, where case counts, unless they are moved), file,
  unit, package and class names, PROG_ID, the environment variables,
  the zips' names, and Steam's own name of the app (Steamworks: his).
  CLAUDE.md's own text keeps the old spelling (not a user's reading).

## Zip 276 (on top of zip 275): the power's median, not its mean
Session 14, owner 2026-11-23 18:30 - 18:31: "how frequently do we
sample power?" (once a second); "Shouldn't we use mean?" (it was the
mean; said that loading and writing pull it down, offered the
transcription's mean or the median) - "median then". NOT COMPILED.
Files: demos/common/uGpuPower.pas, uWebBoard.pas,
demos/EpubBuilder/src/uBuilder.pas, README.md; web/leaderboard/
index.php (the footer's sentence), schema.sql and README.md (words
only); CLAUDE.md. No .dproj. No ALTER TABLE.
- uGpuPower keeps every reading (grown 900 at a time), sorts at the
  end: TGpuPower.MedianW (was AverageW). The log: "GPU power - ...:
  median 109 W, highest 130 W, held to 175 W (137 readings)."
- THE SITE'S NAMES STAYED: the JSON field and the column are still
  avg_watts and now hold the median (said in uWebBoard, schema.sql and
  the site's README) - a rename would have cost the owner another
  ALTER and an upload in step. Rows from zips 274 / 275 hold means
  until a faster run replaces them.
- ZIP 274 WORKS (owner 18:13, log + site): four "GPU power" lines'
  worth on the 5090 laptop - 103 / 63 / 109 W on short detailed / long
  fast / long detailed, held to 175 W. A board's row is the BEST run:
  its power is that run's (short fast stayed without one - an earlier
  run was 0.1 s faster).
- dGPU-only mode (a reboot): the builder calibrated again (the device
  list changed - right) - turbo 99.0x against 97.7x hybrid, base 122.7x
  against 136.8x (noise); benchmarks "marginally faster".

## Zip 275 (on top of zip 274): the builder's project back on Win64; four hints
Session 14, owner 2026-11-23 18:03 (four compiler hints, "For next
zip") and 18:07: "Pull - this is why I messed up last time - you reset
my builds to Linux64 - latest has Win64". NOT COMPILED. Files:
demos/EpubBuilder/EpubBuilder.dproj, src/uBuilder.pas,
demos/common/uWebBoard.pas, demos/EpubReader/src/uPadMenu.pas,
CLAUDE.md; and AGAIN, because the repository (1310cf6) does not have
them: .gitignore, web/leaderboard/.htaccess, config.sample.php,
api/register.php (zip 272's). STILL TO DELETE in the repository:
tools/leaderboard_schema.sql.
- WHAT HAPPENED: this working copy was cloned at 6f7515b, whose .dproj
  files say Platform Linux64. The owner had since set Win64 (22bc9b7).
  Zips 273 and 274 carried EpubBuilder.dproj (a unit added each time)
  made from the OLD file - unpacking them put the builder back on
  Linux64, twice, and he built and tested the wrong program. 1310cf6
  still has that Linux64 file for the builder (the other five projects
  are Win64 there).
- THE RULE (STANDING): before a .dproj is changed, PULL and make the
  change on the repository's file; the line
  <Platform Condition="'$(Platform)'==''"> is the OWNER'S and goes back
  exactly as it came. Say in the delivery that a .dproj is in the zip.
- Done here: EpubBuilder.dproj = 22bc9b7's (Win64, its ProjectName
  line) + the two units; the other five .dproj taken from 1310cf6.
- The hints: System.NetConsts in uWebBoard's uses (H2443); uPadMenu's
  unused BodyH := 0 gone (H2077; the unit is the reader's too);
  Posix.Unistd in uBuilder's implementation uses under POSIX (H2443);
  miExpertClick gone, declaration and body (H2219 - its menu item went
  with zip 260; ToggleExpert is what the Settings page calls).

## Zip 274 (on top of zip 273): an NVIDIA card's power with a score
Session 14, owner 2026-11-23 17:12 - 17:55: the laptop's OWN power
profile (maker's, not Windows', not the program's Power setting - asked,
"(3)") made the benchmarks ~50 % slower on low; medium = high within
1 - 4 %. "It would be nice if there was an easy, consistant way to read
GPU power" (none across makers - said); "Most consumer PCs use nvidia
... Steam Hardware survey puts it at 72.92%" (his figure, not checked);
log only or the website too? "website too". NOT COMPILED. THE OWNER
RUNS THE ALTER TABLE (web/leaderboard/README.md) BEFORE uploading the
PHP. Files: demos/common/uGpuPower.pas (NEW), uWebBoard.pas,
demos/EpubBuilder/src/uBuilder.pas, EpubBuilder.dpr / .dproj,
README.md; web/leaderboard/schema.sql, lib.php, index.php, README.md,
api/submit.php, api/board.php; tools/test_leaderboard.py; CLAUDE.md.
- ZIP 273 COMPILED (Windows 64 and Linux 64) AND WORKS (owner 17:34,
  log + the site read from here): registration and four scores answered
  in 0.2 s, "1st of 1"; the medium run replaced the four rows. Two
  earlier "nothing arrives" were builds without it (the zip not
  unpacked; then Linux64 built instead of Win64 - the third time this
  session: the debug log's "Build:" line tells).
- uGpuPower: NVML loaded at run time (nvml.dll / libnvidia-ml.so.1;
  Windows and Linux; a stub elsewhere), a thread reading every card's
  nvmlDeviceGetPowerUsage each second from GpuPowerStart (before
  StartJob of a benchmark) to GpuPowerStop (first thing in
  BenchmarkDone); the limit from nvmlDeviceGetEnforcedPowerLimit.
  GpuPowerFind matches the benchmark's device by name. The average is
  over the WHOLE run (loading and writing too). Log: "GPU power - ...".
- The site: runs.avg_watts / peak_watts / limit_watts (NULL when not
  sent; a value outside 1 - 2000 dropped, the run kept); board.php
  gives them; index.php has a Power column ("142 W of 175"). The test
  has 36 checks now.
- The Steam board's log lines begin "Steam leaderboard - " (the owner
  took them for the website's).
- NOT KNOWN: that the owner's laptop reports its power ("fairly sure it
  does"); that NVML is reachable inside Steam's Linux runtime; whether
  the limit moves with the maker's profile (the reason it is recorded).
- The owner emptied `benchmarks` by mistake at 17:29 (put back with the
  INSERT given): it is the list of boards - README says so now.

## Zip 273 (on top of zip 272): EpubBuilder sends its scores to the website
Session 14, owner 2026-11-23 16:42 (asked three things with zip 272):
"All up, yes send to both, for now anonymous is fine". The site was
read from here at 16:45: /api/board.php answers ok with 0 rows - the
schema loaded into the owner's MySQL. NOT COMPILED. Files:
demos/common/uWebBoard.pas (NEW), demos/EpubBuilder/src/uBuilder.pas,
EpubBuilder.dpr, EpubBuilder.dproj (the new unit), README.md; CLAUDE.md.
- uWebBoard: WebBoardSubmit(install id, key, scores, event) - a thread
  (one at a time, GBusy) with THTTPClient (15 s timeouts): registers
  when there is no key (a random UUID; os, cpu, memory_gb - NO name, NO
  steam_id: "anonymous"), POSTs each score, and on a 401 registers as a
  new installation and sends once more. One answer for each score on
  the main thread, carrying the id and key to keep. WebBoardForget at
  FormClose.
- uBuilder: FWebInstall / FWebKey ([Leaderboard] Install, Key; saved the
  moment they change), FWebScores / FWebState / FWebPlace / FWebCount /
  FWebBest [1..4]; WebScore (from the summary: model's file name,
  device's description - BoardDevice, now shared with BoardDetails -,
  kind 'cpu' | 'gpu', backend from the device's text, MTL -> Metal,
  channel 'steam' when SteamBuild else 'direct', ran_at UTC); BoardSend
  sends to Steam when it runs AND to the site always (Settings >
  Leaderboard still the one switch); WebSent logs "Website leaderboard
  - ..."; BoardNote shows the site's place only when Steam's has none.
- NOT DONE, SAID: the program's Leaderboards page still shows Steam's
  boards only (non-Steam builds read the site in a browser); the site's
  'integrated' kind is never sent (the device's text does not tell);
  names and Steam ids wait for the owner (and a Steam ticket check).
- CANNOT BE KNOWN HERE: that THTTPClient reaches the site from each of
  the builds (it does reach Hugging Face for the models).

## Zip 272 (on top of zip 271): the leaderboard site (server side)
Session 14, owner 2026-11-23 16:21, asked what follows the landing page:
"2) leaderboard". NOTHING TO COMPILE (no Delphi file). Files (all NEW
but the last three): web/leaderboard/index.php, lib.php, schema.sql,
config.sample.php, .htaccess, README.md, api/register.php,
api/submit.php, api/board.php; tools/test_leaderboard.py; .gitignore
(the filled-in settings are never committed); CLAUDE.md. DELETE
tools/leaderboard_schema.sql (zip 269's draft: schema.sql replaces it).
- TESTED HERE: PHP 8.3 lints every file; tools/test_leaderboard.py
  runs the site on PHP's own server against SQLite - 35 checks pass
  (registration, the 409 / 400 / 401 / 405 / 422 / 429 refusals, the
  pending run, places, around-a-machine pages, the page's HTML, a name
  shown as text, a hidden machine, every run kept). The page was looked
  at in Chrome at 1280 and 390 wide. NOT TESTED: schema.sql in MySQL,
  the site on Plesk, HTTPS, .htaccess (Apache).
- THE CHOICES MADE (the owner said only "leaderboard"; said to him):
  the machine is what is ranked; version 1's validation is the minimum
  offered at 16:14 (a per-install key, rate limits, plausibility, a
  'pending' state above 400x; README lists it; lib.php's constants);
  PHP 7.4-compatible; SQL that MySQL and SQLite both take (no ON
  DUPLICATE KEY, no window functions, ids and hashes as text) so that
  it could be tested; a person = a Steam id when one is sent (NOT
  checked yet - runs.verified waits for a Steam ticket check), else a
  person per machine; the name shown is the one sent, "Anonymous" when
  none; the same look as the landing page.
- NOT IN THIS ZIP - THE NEXT ONE: EpubBuilder's side (register once,
  keep the key in the settings, POST each score after a benchmark over
  HTTPS with System.Net.HttpClient, Steam and non-Steam builds; what a
  non-Steam user is called; a Settings row). The endpoints' fields are
  in web/leaderboard/README.md. Ask the owner first: after the site is
  up and the import worked; whether the Steam builds send to BOTH
  boards; the non-Steam name.
- OPEN from the schema's draft: how a non-Steam user claims several
  machines as one person (link.epubunum.com's accounts will answer it).

## Zip 271 (on top of zip 270): the website's landing page
Session 14, owner 2026-11-23 16:13 (the three sites exist, https, PHP,
MySQL on request - Plesk's default page on each) and 16:15, asked which
site first: "1st - landing page". NOTHING TO COMPILE. Files:
web/www/index.html (NEW - the first file of a new web/ folder: one
folder a site, web/www for https://www.epubunum.com), CLAUDE.md.
- One self-contained file: no script or font from elsewhere, no cookie,
  no tracking; system fonts (a book serif for the name, the headline
  and the passage; the system's sans for the rest). Deep blue field,
  cool paper, the programs' yellow as the only accent.
- The top shows the thing itself: the opening of A Christmas Carol
  (public domain) on a book page, its words marked one after another as
  EpubReader marks them - no sound; Play / Pause; still (one word
  marked) for visitors who ask their system for less motion. Then: the
  three steps, the three programs, "How long a book takes" (the long
  Detailed benchmark of five of the owner's machines, from the Steam
  boards of 2026-11-23), "Your books stay yours", the two links
  (leaderboard.epubunum.com, the GitHub repository).
- Looked at here in Chrome at 1280 and 390 wide (playwright).
- CLAIMS THE OWNER SHOULD CHECK before it goes up: "EpubUnum is in
  testing on Steam" (no date, no store link - none is known here);
  Windows, macOS, Linux and the Steam Deck; "99 words in 100 were
  matched"; the GitHub link (the repository is public). No price, no
  download, no contact address, no privacy page - none was given.
- TO PUT IT UP (Plesk): the file goes into the www domain's document
  root (usually httpdocs) as index.html, in place of the default page.

## Zip 270 (on top of zip 269): the leaderboard's score column no wider than it needs
Session 14, owner 2026-11-23 06:46, a screenshot from the Steam Deck
(zips 268 and 269 COMPILED AND RAN: "Long Text, Detailed Model - top (6
on the board)", six rows with place, name, score and device, the Deck's
own row in yellow, Back, the foot's left / right "around you" and B
"back"): the devices were cut short ("NVIDIA GeForce RTX 5090 La...")
with room to spare left of the scores. NOT COMPILED (pasdoc_check,
project_check: 0 problems). NO PACKAGE REBUILD. STEAM REBUILD NEEDED
(uPadMenu). Files: demos/EpubReader/src/uPadMenu.pas (shared),
CLAUDE.md.
- Cause: the table took Needed's value width, which is eight font sizes
  at least (a menu's rule) - about a quarter of the Deck's page for an
  11-character score. Now the table measures its own values: the score
  column is its share (10 %) or its widest score; the device column has
  the rest and, when its widest entry still does not fit, a smaller text
  (not under two thirds of the menu's size) rather than "...".
- Not asked for in words: the owner sent the screenshot as a report
  ("one from Steam Machine to follow"); the cut-off devices were put
  right as a fault of zip 265's layout.

## Zip 269 (on top of zip 268): menu rows unseen (zip 266's fault); no pad or keys during a benchmark
Session 14, owner 2026-11-23 05:18, a screenshot (Windows, Big Picture,
keyboard and mouse; Mac the same): the Benchmark list showed only
"Leaderboards" and "Back" - the five benchmark rows were there (the
selection on an empty one) but unseen; "The benchmark results also came
up blank"; and "When running the benchmark pressing [A] brings up the
menu - this shouldn't happen. The pad/keys should not have any effect
mid-benchmark." NOT COMPILED (pasdoc_check, project_check: 0 problems).
NO PACKAGE REBUILD. STEAM REBUILD NEEDED (uPadMenu: the READER'S MENUS
HAD THE SAME FAULT since zip 266). Files:
demos/EpubReader/src/uPadMenu.pas (shared),
demos/EpubBuilder/src/uBuilder.pas, tools/leaderboard_schema.sql (NEW:
the TBD draft), CLAUDE.md.
- THE FAULT WAS MINE: zip 266 added TPadMenuItem.Color and
  TPadMenu.Item did not set it - a record's numeric fields are not
  cleared, so a row got whatever colour the stack held (alpha 0, or
  black). Item now starts from Default(TPadMenuItem). RULE: a field
  added to a record that a function builds field by field - make the
  function start from Default(), or set the new field there.
- uBuilder: BenchRunning (FBenchOption >= 1 or FBenchQueue not empty);
  PadPress returns at once while it is True unless a question shows
  (BPM_ASK). Keys go through PadPress too (KeyDown). The results box
  after the run is not "running" (X / H, the answer).
- SAID TO THE OWNER: in Big Picture nothing now stops a running
  benchmark but leaving the program (the bars have no Cancel button
  there; Menu > Cancel was the way and is closed) - the Miix's Detailed
  runs take hours. Offered: a held button, or a Cancel that asks first.
- Seen in the same screenshot, working: the four "Leaderboard - ...:
  1st of 1." lines after Run all on the 5090 (Long Text, Detailed Model
  0:02:05.388).
- In this zip's CLAUDE.md from the hours before (no code): the Miix's
  benchmarks and the seven machines' speeds; the website leaderboard,
  all TBD (its draft schema: tools/leaderboard_schema.sql); the Apple
  TV reader through BookServer (a new local program, also headless);
  activation at https://link.epubunum.com for headless installs.

## Zip 268 (on top of zip 267): the leaderboard's page fills the window; top / around you
Session 14, owner 2026-11-23 03:23 "could we show, say the top 25?" and
03:31: "If we made the leaderboard 95% wide and high we'd be able to fit
a lot more lines in. If you are on the leaderboard then you appear on
the list. If you're ranked way down the last leaderboard entry is you
and 1 less result is shown. We know in advance how many rows we can fit
on the screen so we can always display a full page (if there are enough
leaderboard entries). There is also a "Range Around User" so we could
show two versions of the same board and switch between them with the
left/right arrow keys". NOT COMPILED (pasdoc_check, project_check: 0
problems). NO PACKAGE REBUILD. STEAM REBUILD NEEDED (uPadMenu is the
reader's too). Files: demos/EpubReader/src/uPadMenu.pas (shared),
demos/common/uSteamBoard.pas, demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/README.md, CLAUDE.md.
- uPadMenu: NextHeightShare (the box that share of the window tall, for
  one Show), RowsThatFit(share, foot) - the inverse of Show's height
  sum - and the private ParentHeight.
- uSteamBoard: SteamBoardRead(board, rows, around, event). The job reads
  the user's row first (place, the board's size), then ONE page with
  k_ELeaderboardDataRequestGlobal: from 1, or - around - from
  EnsureRange(place - rows div 2, 1, size - rows + 1), so the page is
  full at either end of the board. Steam's GlobalAroundUser is NOT used
  for the page (near the top it gives fewer rows); only, as before, 0..0
  for the user's own row. TSteamBoardResult: First, AskedAround, Around.
  BOARD_TOP is gone.
- uBuilder: PadBoard (the waiting page, the same size) -> BoardAsk
  (FBoardRows = RowsThatFit(0.95, foot) - 1 for Back, 3 at least) ->
  BoardRead. Top page, the user not on it: Shown = FBoardRows - 1 and
  the user's row ("N. You", yellow, its device) is the last line. The
  title: "<benchmark> - top (N on the board)" / "- around you (...)";
  the count and blank lines are no longer rows. PadStep in BPM_BOARD ->
  BoardSwitch (FBoardAround; only when FBoardHasRank); the foot shows
  left / right "around you" or "top" and Back (PadFootOf / RefreshFoot).
  The page on the screen stays while the other is fetched; an answer
  for a page no longer asked for is dropped (AskedAround).
- NOT DONE: no scrolling of a board (page up / down through all of it) -
  the two pages are what there is.

## Zip 267 (on top of zip 266): the leaderboard's place in a column of its own
Session 14, owner 2026-11-23 03:17 - 03:20: "How many rows will
leaderboard show?" (ten, BOARD_TOP, and the user's own under them); "If
I'm 104628th ... will my position appear?" (yes); "In that case the
first column (rank) needs to be wider and the 2nd (nickname)
correspondingly shorter so the two columns can fit (there are now 4
columns)". NOT COMPILED (pasdoc_check, project_check: 0 problems). NO
PACKAGE REBUILD. STEAM REBUILD NEEDED (uPadMenu is the reader's too).
Files: demos/EpubReader/src/uPadMenu.pas (shared),
demos/common/uSteamBoard.pas, demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/README.md, CLAUDE.md.
- uPadMenu, a table (NextColumns): a row's Key is its first column -
  the text's size and colour (Color, Dim), right-aligned, room for
  TABLE_KEY_ROOM ('0000000.') at least; the text column is the first
  share less that column (place + name = 40 %). A line with no key and
  no values keeps the whole width (Back, the count). Outside a table
  Key is what it was (a key's name).
- uBuilder.BoardRead: Info(APlace, AText, AValue, ADevice, ...) - the
  place is Row.Key ("1."), the name the text.
- uSteamBoard: TSteamBoardResult.BestDetails (the numbers of the user's
  own row, from the GlobalAroundUser read) - the "N. You" row under the
  top ten shows its device too (offered at 03:18; not asked for in so
  many words).

## Zip 266 (on top of zip 265): the leaderboard's own row in yellow
Session 14, owner 2026-11-23 03:15, a screenshot of zip 265's page (IT
COMPILED AND RAN, build 02:34: 95 % wide, the three columns, the yellow
frame, the centred name): "The leaderboard will look better if your own
score is in the same Yellow as the border". NOT COMPILED (pasdoc_check,
project_check: 0 problems). NO PACKAGE REBUILD. STEAM REBUILD NEEDED
(uPadMenu is the reader's too). Files:
demos/EpubReader/src/uPadMenu.pas (shared),
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- uPadMenu: TPadMenuItem.Color (0 = the menu's own) - the row's text,
  value and third column in it.
- uBuilder.BoardRead: the user's row (in the top ten, or the "N. You"
  row under it) gets BOARD_FRAME_DARK / LIGHT.
- Also in this zip's CLAUDE.md: the Miix's benchmarks and the seven
  machines' speeds ("Session 14" at the top). Owner 02:53: seven Steam
  accounts, one per machine, to fill the boards - waiting for keys.

## Zip 265 (on top of zip 264): the leaderboard's page - 95 % wide, three columns, yellow frame, centred name
Session 14, owner 2026-11-23 02:27, a screenshot of the 5090's first
leaderboard page (IT WORKS: zips 261 - 264 compiled and ran, build 01:55;
"1. <name> (you) 0:00:26.981 NVIDIA GeForce RTX 5090 Laptop GPU", a
second row from the Miix, "2 on this leaderboard"): "Bad layout (again).
Make it 95% wide with 3 columns 40/10/50%"; "Yellow border again as
well"; 02:28 "Center the board name". NOT COMPILED (pasdoc_check,
project_check: 0 problems). NO PACKAGE REBUILD. STEAM REBUILD NEEDED
(uPadMenu is the reader's too; the reader's menus do not use the new
properties). Files: demos/EpubReader/src/uPadMenu.pas (shared),
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- uPadMenu: TPadMenuItem.Value2; NextColumns (three shares: Text,
  Value, Value2 - a table; the box as wide as NextWidthShare allows; the
  value column never narrower than its widest value; a row without
  values keeps its text over the whole width); NextFrameColor (the
  box's frame in that colour, 4 thick). Both for one Show, as
  NextTitleCentered. The columns are placed once the box's width is
  known (Inner = W - PAD x 3 - the left column).
- uBuilder.BoardRead: NextWidthShare 0.95 (BOARD_WIDTH_SHARE),
  NextColumns [0.4, 0.1, 0.5], NextFrameColor BOARD_FRAME_DARK / LIGHT
  (uBenchProgress's yellows), NextTitleCentered; the device is Value2,
  no longer appended to the score. PadBoard's "Asking Steam ..." page
  the same width (MinWidth for that Show), frame and centred title, so
  the box does not jump.
- STANDING, from the owner's "(again)" twice: a new page or box of the
  builder is WIDE (a share of the window, not as narrow as its text),
  its columns given widths, the benchmarks' YELLOW FRAME, its title
  CENTRED - do that the first time.
- Names to look at: Texts / Seconds (the labels kept for the table),
  Align Left with Position.X for the first two columns, TAlphaColor($...)
  typed constants.

## Zip 264 (on top of zip 263): Leaderboards at the top of the Benchmark menu
Session 14, owner 2026-11-23 02:08: "Make Leaderboards the top option in
that menu". NOT COMPILED (pasdoc_check, project_check: 0 problems). NO
PACKAGE REBUILD. Builder only. Files:
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- PadBenchmarks: the Leaderboards row is the first (Steam running), so
  the list opens with it selected - Run all is one down. BuildMenu:
  Leaderboards..., a separator, then the five. The rows' commands are
  FPadCmds' (not their places), the bar's items go by Tag: nothing else
  changed.

## Zip 263 (on top of zip 262): leaderboard - no question, on by default
Session 14, owner 2026-11-23 02:05: "Don't ask to submit to the
leaderboard - just do it if leaderboard is checked in settings. Default
value for leaderboard in settings is yes"; "Where do I view the
leaderboard?" (answered: Benchmark > Leaderboards in the app; on Steam
the app's community stats page once the boards have Community Names).
NOT COMPILED (pasdoc_check, project_check: 0 problems). NO PACKAGE
REBUILD. Builder only. Files: demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/README.md, CLAUDE.md.
- FBoardUpload is a Boolean, True at first ([Benchmark] Leaderboard,
  ReadBool / WriteBool - a 0 or 1 written by zip 261 reads the same);
  zip 261's question, its "< Ask >" and BenchResults are gone (its body
  is BenchmarkFinished's end again). Settings > Leaderboard: Yes / No.
- Owner 01:55: the 5090's "no sign of leaderboards" was a build of 01:17
  (before zip 261; Linux had been built, not Windows). A build with 261
  logs "Steam: Plug-in ISteamUserStats initialised".

## Zip 262 (on top of zip 261): Settings > Calibration results shows the results page
Session 14, owner 2026-11-23 01:46: "Settings menu option -> Calibration
Results should show the new Calibration Results page not just the log".
NOT COMPILED (pasdoc_check, project_check: 0 problems). NO PACKAGE
REBUILD. Builder only. Files: demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/README.md, CLAUDE.md.
- BPC_RESULTS -> ShowCalibrationPage (new): miCalibrationClick's lines
  into the log as before (the log is no longer switched to), then a
  TBenchProgress with no bars (FCalView, titles nil) and
  ShowCalibrationResults - zip 251's table. FCalFromSettings: closed
  (any key, click or button - CalResultsButton), CalResultsClosed shows
  the Settings page again on Calibration results. Not calibrated: Tell
  says so (Big Picture: its OK returns to Settings). A calibration
  running: nothing (the view is its bars').
- Also in this zip's CLAUDE.md: the owner's plan of 01:32 - a website of
  ours for several machines of one user, once the Steam leaderboards
  are tested (see "Session 14" at the top).

## Zip 261 (on top of zip 260): the benchmarks' Steam leaderboards
Session 14, owner 2026-11-23 01:18: "OK, leaderboards before benchmark
mode". Asked four things; the owner answered the first (Steam's
leaderboards, not a server of ours) and left the other three: ASSUMED,
and said so - one row per user per benchmark with the BEST score kept;
ASKED ONCE whether scores go up, then automatic; the app shows the
user's PLACE after a run and a TOP TEN list. NOT COMPILED (pasdoc_check,
project_check: 0 problems). NO PACKAGE REBUILD. Builder only (the reader
does not use the new unit): no Steam banner. Files:
demos/common/uSteamBoard.pas (NEW), demos/EpubBuilder/EpubBuilder.dpr,
demos/EpubBuilder/EpubBuilder.dproj (the new unit),
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- uSteamBoard (STEAMBUILD inside, as uSteamPad; uses uSteam's
  SteamRunning and Steamworks' Steam.FindPlugin): SteamBoardSubmit(board,
  score ms, details, top, event), SteamBoardRead(board, top, event),
  SteamBoardsForget (FormClose), SteamBoardPackText / UnpackText. A
  TSteamBoardJob per request chains TSteamUserStatsPlugin's ...Async
  calls: FindOrCreateLeaderboard (ascending, time in ms; FindLeaderboard
  when only reading) -> UploadLeaderboardScore (KeepBest) ->
  DownloadLeaderboardEntries GlobalAroundUser 0..0 (the user's rank and
  best) -> Global 1..top -> ISteamFriends RequestUserInformation, 1.5 s
  for names Steam must fetch, GetFriendPersonaName. The event comes on
  the main thread (TSteamAPI's callback timer). The job frees itself
  through TThread.ForceQueue, never inside Steam's handler.
- BOARDS: benchmark_short_fast, benchmark_short_detailed,
  benchmark_long_fast, benchmark_long_detailed (BOARD_NAMES) - made by
  the first score sent. THE OWNER, on the Steamworks partner site: give
  them display names; writes must stay allowed from the client (not
  "trusted"); publish. The score: transcription time, ms. Details
  (BoardDetails): [0] 1 = the layout, [1] words matched in hundredths of
  a per cent, [2] 0 processor / 1 graphics, [3] 0, [4..15] the device's
  description, four ASCII characters a number (48 at most).
- PRIVACY RULE: no machine name anywhere. Steam names appear on the
  leaderboard's page of the menu only (that is what a Steam leaderboard
  is, and the question says so); the log has place and count only.
- uBuilder: BenchmarkFinished asks once (Ask - the pad's box in Big
  Picture, a dialog on the desktop) when Steam runs and FBoardUpload is
  -1; [Benchmark] Leaderboard 0 / 1 in the settings; Settings >
  Leaderboard (BPC_BOARD 37, Steam running; < Ask > until answered).
  BenchResults (new: what BenchmarkFinished ended with) calls BoardSend,
  then the table. BoardSent: the log's "Leaderboard - <benchmark>: 3rd
  of 41." and the Results table shown again with the row chosen kept
  (FBenchSel) - the score's cell gets BoardNote ("sending ...", "3rd of
  41", "your best 0:00:25.100 is 3rd of 41", "not added").
- THE LIST: Benchmark > Leaderboards... on the bar (Steam running) and a
  Leaderboards row in the pad's Benchmark list -> PadBoards (BPM_BOARDS
  10: the four) -> PadBoard (BPM_BOARD 11: "Asking Steam ...", then
  BoardRead's rows: place, name, score and device; the user's own row
  under them when not in the top ten; the count). "No scores yet" when
  the board is not there.
- NOT KNOWN UNTIL RUN: whether the app's Steamworks settings let the
  client create leaderboards (else FindOrCreate answers "not found":
  the log says "the leaderboard is not there yet" - make the four by
  hand, ascending, time in milliseconds); what GlobalAroundUser returns
  for a user with no row (taken: nothing, or rows that are not theirs -
  both handled); nothing stops a made-up score (a client-written board
  cannot; said to the owner).
- Names to look at: the anonymous method in TSteamBoardJob.Finish
  (Free), PLeaderboardFindResult_t / PLeaderboardScoreUploaded_t /
  PLeaderboardScoresDownloaded_t casts of AData.Data, TSteamID's "="
  operator, FPadMenu.Show with an array constructor ([Row,
  TPadMenu.Item('Back')]), Dev.LastIndexOf.

## Zip 260 (on top of zip 259): base by itself when turbo is too slow; F5 / F6; installed models first; the old settings page and the hidden menus gone
Session 14, owner 2026-11-23 01:08: "Yes, switch to base automatically
after the start-up calibration if turbo too slow"; "Q for Queue is OK but
now it's F2/F3 - we should change F2 -> F5 and F3 -> F6 to avoid
potential Reader issues"; "Installed models should always be listed
before uninstalled ones, en or otherwise"; "The window's Settings...
button should open File > Settings - the existing menu should be
removed"; "All redundant code should be removed". NOT COMPILED
(pasdoc_check, project_check: 0 problems). NO PACKAGE REBUILD. STEAM
REBUILD NEEDED (uReaderInput and the layouts are the reader's too:
revision 2.5). Files: tools/gen_reader_input.py,
demos/EpubReader/src/uReaderInput.pas and the eleven
demos/EpubReader/steaminput/controllers/*.vdf (GENERATED with TSteamAPI
at 80804ab; LF as the repository has them; the manifest unchanged, not
in the zip), demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/src/uModels.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- BASE BY ITSELF: UseBaseWhenTooSlow, called by CalibrationDone when
  FCalAtStart, after CalibrationSave and before ApplyCalibration (so
  base gets its fastest device): the window's model at its best
  (CalibrationBest) is below FLowestSpeed / 10, base (BENCH_QUICK_MODEL)
  is in the models folder and its best is not below it -> FModelPath :=
  base, FillModels, a log line with both speeds. Any model, not turbo
  only. Not after Settings > Re-calibrate (the user chose the model).
- KEYS: MENU_KEYS Menu = vk 116 "F5", Library (the queue) = vk 117 "F6";
  LAYOUT_REVISION 5 (LAYOUT_MAJOR stays 2). The layouts differ from 2.4
  in title, description and minor_revision only (diffed). The reader's
  own F3 (find next) no longer shares a key with the menu table.
- MODEL ORDER: uModels.ModelListOrder's Rank - base, turbo; installed
  (every language, then .en); to download (every language, then .en);
  each smallest first. base and turbo stay first even when not
  installed (the rule of zip 216, "in all situations"; said to the
  owner).
- THE OLD SETTINGS PAGE IS GONE: pnlSettings, btnSettings,
  btnSettingsClick, btnSettingsDoneClick, the Done button, its rows and
  captions. The window's Settings... button calls miSettingsClick (File >
  Settings: the menu's Settings page). The controls the code reads
  (cbModel, cbDevice, cbLanguage, cbPower, cbGpu, chkChapters, chkReuse)
  are STATE, not redundant: they sit on laySettings, a TLayout never
  shown (as they did, unseen, in Big Picture). What only the old page
  had is now a Settings row, desktop only: BPC_REUSE 34 "Use a saved
  transcript (this build only)", BPC_GPU 35 "Window GPU" (Windows),
  BPC_FOLDER_MODELS 36 "Models folder" (not Steam, no download running;
  ChooseModelsFolder, was btnModelFolderClick). BPC_SETTINGS_TOP = 36.
- THE HIDDEN VIEW AND TOOLS MENUS ARE GONE (zip 223 kept them on no bar
  for their state): miLog, miDarkMode, miExpert (ticks nobody saw),
  miCalibrate / miCalibrateAll / miDiagnostics / miDiagnosticsAll /
  miDownloadAll (one state: FToolsReady, set by UpdateControls), miRocm
  (FRocmOffer, set by CheckRocmDlc), miDarkModeClick, miFolderClick,
  miDownloadAllClick. Download every model was and is the Model list's
  first row. The bar: File (Settings..., Exit) and Benchmark.
- NOT REMOVED: nothing else was looked for - "all redundant code" was
  taken as what these changes made redundant and what zip 223 had left
  behind. A wider sweep of uBuilder for dead code is a job of its own.
- OWNER'S ANSWERS (01:08), no code: touch in the pad menu works; the
  benchmark audio is in the depot; 960 "was pixels but has been resolved
  by % width of screen"; Q for the queue is settled by the F keys; the
  Miix's results are still to come.
- Names to look at: laySettings (combo boxes on a layout never shown -
  as before in Big Picture), the {$IFDEF MSWINDOWS} inside PadStep's
  case and PadHome, FToolsReady before the first UpdateControls (False:
  no calibrate rows until then), ChooseModelsFolder.

## Zip 259 (on top of zip 258): BookManager's Dark mode
Session 14, owner 2026-11-22 19:57 "BookManager should have a DarkMode
option (new job)", 2026-11-23 00:27 "BookManager Dark mode". NOT
COMPILED (pasdoc_check, project_check: 0 problems). NO PACKAGE REBUILD.
BookManager only (not a Steam program). Files:
demos/BookManager/src/uManager.pas, demos/BookManager/README.md,
CLAUDE.md.
- chkDark ("Dark mode", the builder row's far right); FDark, [View] Dark
  in BookManager.ini, True at first as EpubBuilder's; chkDarkChange
  saves. BookManager has no menu bar, hence a check box.
- ApplyDark (EpubBuilder's ApplyDarkWindow, zip 222, copied - its
  DarkMemo / DarkLabel / DarkList, plus DarkCheck): the form's Fill
  DARK_WINDOW; every TLabel, TCheckBox, TListBox, TMemo of
  Self.Components (all are made with the form as owner; the tabs'
  controls are not the tab items' Children). DarkBeforeShow at the end
  of FormCreate's set-up; tmDark (500 ms) while dark; also called after
  the lists are filled (FillBooks, the three lbTransfers.EndUpdate).
- THE TABS: the style's tab strip is light and differs by platform, so
  dark hides it (tcMain.TabPosition None; PlatformDefault when light)
  and shows layTabs: four TRectangles with a TLabel (FTabBoxes,
  FTabLabels; the one that shows filled DARK_ROW), TabBoxClick,
  tcMain.OnChange = TabChanged, UpdateTabStrip (names follow the tab
  items' Text: "Books made (12, 3 new)", "Progress (45 %)"). FTabBacks: a
  dark TRectangle (Align Contents, made first) behind each tab's
  controls, whatever the style draws there. btnPairClick puts layPair
  under layTop (Position.Y) so the code row opens above layTabs.
- Light mode is untouched: the style's tabs, no sheets, no layTabs.
- A GUESS, NOT SEEN (as 222). Likely rough edges: light buttons, combo,
  code box and bars on the dark window; the check boxes of Books made;
  the selected row's colour; a frame the tab control may still draw; the
  order of the rows under the builder row after pairing.

## Zip 258 (on top of zip 256 / 6f7515b): Run all N benchmarks; the introduction only at the window's size; the estimate tuned
Session 14, owner 2026-11-22 19:57, with the logs of six machines
(bench.zip: ally, ideapad, mac, monster, steamdeck, steammachine; the
Miix still running): "It's Run all N benchmarks should let it run the 2
available benchmarks. The label say 4 benchmarks - this is probably a
literal"; "The old bad calibration intro screen is visible via RustDeck
in Linux ... still showing but just covered up by the good calibration
screen. The old bad one should not appear under any circumstances."
NOT COMPILED (pasdoc_check, project_check: 0 problems). NO PACKAGE
REBUILD. One program only (the builder): no Steam banner. Files:
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- RUN ALL N: FBenchCan[1..4] (BenchAvailability: the model is there and
  not TooSlow), BenchCount (0, 2 or 4), BenchName(0) = "Run all N
  benchmarks" (N > 0; the menu bar and the pad list). Run all is enabled
  when one can run, queues those that can, logs "Not run here: ..." for
  the others, "Benchmark k of N"; its time is the sum of those. None:
  the models' message, or "No benchmark can run here ..." + TooSlow's
  why. FBenchKey has BenchCount (the name follows the Lowest acceptable
  speed). BenchmarkFinished: without a Detailed book the Fast ones are
  the candidates to keep. BenchmarkModel(0) = a model that is here.
- THE INTRODUCTION: CheckCalibrationAtStart calls IntroWhenSettled, not
  ShowCalibrationIntro: FIntroWait, tmIntro (100 ms) shows the page when
  the client size has stood still for INTRO_SETTLE_MS (600) and, macOS
  in Big Picture, the Cocoa full screen is there or given up (FFullTries
  = PAD_FULL_TRIES; the two PAD_FULL constants are unit-level now). So
  the page of the small window is never made. A later resize while it
  shows: as zip 256, then Invalidate. Debug log: "calibration: the
  introduction shown, the window W x H". CAUSE NOT FOUND in the code
  (TPadMenu has one box; the ideapad's log shows the page asked for 3 ms
  after the full screen was, before any resize): if the old page still
  shows on Linux after this, it is not a second page but the first
  frame left on the screen - say so and look at FMX Linux's redraw.
- THE ESTIMATE (handover's Next 2), guess -> timed, turbo: Mac CPU 1.9x
  -> 23.9x; ideapad CPU 0.5x -> 1.3x, Iris Xe 2.0x -> 4.0x; estimate /
  took: ideapad 456 / 188 s, mac 122 / 37, ally 131 / 87, steam machine
  180 / 101. GuessSpeed: Apple's CPU 15x with the square root; Core i
  10th / 11th generation Gen 2 (only four digits = Gen 1); Iris 3x.
  CalibrationGuess: START_SECONDS 5 (was 20), LOAD_MB_S 1000 (was 400).
  By hand with the new figures / took: ideapad 244 / 188, mac 30 / 37,
  ally 111 / 87, steam machine 127 / 101, deck 190 / 252, monster 81 /
  73, Miix 595 / 593.
- THE SIX MACHINES' SCORES (benchmarks.csv; Short Fast / Short Detailed /
  Long Fast / Long Detailed, s; a survey - builds 7c08bf5 and 65569dc):
  monster (RTX 5090 Laptop, Vulkan) 26.5 / 34.2 / 113.7 / 123.7; mac (M4,
  Metal) 38.6 / 116.5 / 156.9 / 439.8; steam machine (NAVI33) 47.6 /
  88.1 / 181.6 / 320.7; ideapad (GTX 1650) 58.3 / 215.3 / 251.7 / 798.3;
  ally (Z1 Extreme) 67.7 / 195.4 / 273.7 / 739.0; deck 127.9 / 430.1 /
  541.7 / 1567.9. Words matched: base about 98 %, turbo over 99 %.
- OWNER'S REPORT (19:57): all zips applied; 256 fixed the introduction;
  the Miix no longer black after the screen blanks (207); the Miix
  refuses too-slow benchmarks and builds (249), below 0.6 all four run
  (about 6 h); the Mac gets full screen "after a short spell in windowed
  mode - it'll do" (247); the Mac connects to BookManager and books were
  fetched from it; the Ubuntu run was fine but for the old page.
- NEW JOB (owner): BookManager should have a Dark mode option - zip
  259.

## Zip 256 (on top of zip 255): calibration page - laid out again when the window grows; keys on the left
Owner 2026-11-22 17:32, three screenshots (build 17:27 = zips 254 + 255,
MONSTER): "on start...." - the box narrow, its text running into the
foot, no answers in sight; "I have to use keyboard to get it like
this..." - 60 % wide, both answers, "Enter" / "Esc" on the right: "Note
Calibrate Now is on the wrong side"; "Use pad and it's correct" - the A
and B pictures on the left. The estimate showed "roughly 2 min" (it
takes 1:15). NOT COMPILED. NO PACKAGE REBUILD. STEAM REBUILD NEEDED
(uPadMenu). Files: demos/EpubReader/src/uPadMenu.pas,
demos/EpubBuilder/src/uBuilder.pas, CLAUDE.md.
- Cause of the start: AfterShow shows the page before the window has its
  full size (Big Picture's full screen comes after); TPadMenu sizes its
  box once, at Show. A key press showed it again (SetPadKeys), at the
  full size.
- uBuilder: OnResize := FormResized (StartPad; the form had none) -
  while the introduction shows, tmIntro (250 ms, restarted by every
  resize) shows it again at the new size. CalibrationGuess(ACard, ALog):
  the guesses and the estimate go into the debug log the first time only
  (FCalIntroLogged).
- uPadMenu: TPadMenuItem.Key - a key's name in the left column where a
  picture would be (LeftWidth: the widest pictures or key name, + PAD /
  2; Needed and Show use it). IntroRow puts the key there (was the
  value, on the right).

## Zip 255 (on top of zip 254): calibration page 60 % wide, the text's height
Owner 2026-11-22 17:24, a screenshot (MONSTER: Core Ultra 9 275HX, 24
threads; Vulkan0 RTX 5090 Laptop, Vulkan1 Intel(R) Graphics - no
CUDA device listed), "This screen is still wrong / 80% wide", 17:25 "No
- make that 60%". The screenshot's build was 17:07 - before zip 254
(17:21): the old width (960 cap), the old estimate (7 min), no button
pictures; only "Calibrate now" visible under the text, the second
answer scrolled out of sight. NOT COMPILED. NO PACKAGE REBUILD. STEAM
REBUILD NEEDED (uPadMenu). Files: demos/EpubReader/src/uPadMenu.pas,
demos/EpubBuilder/src/uBuilder.pas, CLAUDE.md.
- ShowCalibrationIntro: NextWidthShare 0.6 (was 0.8).
- TPadMenu.Show, a text's height: measured 4 x PAD narrower than the box
  (was 3: the label wrapped "(graphics card)" onto a line the measure
  did not count) and a spare line (FFontSize x 1.5, was 0.5) - every
  question with a text gets the room; its answers stay in view.
- Zip 254's estimate for this machine (worked by hand from the
  screenshot's devices): CPU 24 / 16 x 3 = 4.5x turbo; Vulkan0 RTX 40x;
  Vulkan1 Intel(R) Graphics 6x -> about 2 min (it took 1:15).

## Zip 254 (on top of zip 253): calibration page - estimate, width, button pictures
Owner 2026-11-22 17:19: "The calibration intro page is good enough but
it way overestimated how long my machine would take saying 7 mins when
it actually took 1:15. There is not enough space under the text to see
both continue and quit options, you need to scroll. Make the panel
wider (80%). Button Glyphs must be used!" NOT COMPILED. NO PACKAGE
REBUILD. STEAM REBUILD NEEDED (uPadMenu is the reader's too). Files:
demos/EpubReader/src/uPadMenu.pas, demos/EpubBuilder/src/uBuilder.pas,
CLAUDE.md.
- Which machine: not said (no log). Worked by hand for the 5090 laptop
  (assumed Core Ultra, 24 threads, an RTX 5090 on CUDA and Vulkan,
  perhaps Intel's iGPU as Vulkan1): the old guess gave about 7 min -
  Intel's newer graphics taken as a UHD 620 (0.7x) and a recent CPU as
  the Miix's. Now about 2 min; the Miix still about 10 min.
- GuessSpeed: CPU = threads / 16 x Gen - Gen 3 for Core Ultra, Apple,
  Core i 12th generation on (5 digits, first two >= 12), Ryzen x7xxx
  on; 1 for older Core i and Ryzen x1xxx - x3xxx; else 2 (the Ally's
  Z1, the Deck's custom APU). GPU: RTX with a 4-digit number from 3xxx
  40x, other cards 15x; Intel UHD / HD 0.7x, Iris 2x, other Intel 6x;
  Metal 20x; other integrated 8x. DigitsAfter (Core i 'i5-' / 'ryzen ' /
  'rtx ': the number after). Debug log per guess: "calibration: guessed
  N.Nx for <model> on <device>" - with "the introduction's estimate"
  and the log's "Calibration took", the guess can be checked.
- uPadMenu: NextWidthShare (one Show: that share of the window, no
  BOX_MAX_WIDTH cap; then 0). The introduction uses 0.8.
- The introduction's answers carry their buttons (IntroRow): Steam's
  picture on the left with a pad (PadHintsFor), the key's name as the
  value with the keyboard; FCalIntro / FCalIntroWhy - SetPadKeys shows
  the page again when the pad and the keys change places.

## Zip 253 (on top of zip 252): the reader's library picks up EpubBuilder's books
Owner 2026-11-22 17:04, Ally: "I just did a benchmark on Ally. I saved
the transcripts at the end then opened Reader. Reader had no content.
Reader should do an initial scan of the Transcribed folder and pick up
any titles there it hasn't seen before and if any are present add them
to it's library. It can then open with a populated library." The
library is FRecent (books opened, at most RECENT_MAX 10); the builder's
output was only in Open a book (ShowBooksMenu). NOT COMPILED. NO PACKAGE
REBUILD. Files: demos/EpubReader/src/uMain.pas,
demos/EpubReader/README.md, CLAUDE.md. One program only (the reader):
no Steam rebuild banner.
- FSeen (lower-case file names, "seen" in EpubReader.json, at most 1000);
  a settings file without "seen" (everyone now) = nothing seen: every
  book there is added on the first start.
- ScanTranscribed (from ShowLibrary, after RememberBook - so at start-up
  and whenever the library shows): BuilderOutputFolder, plus
  EpubUnumFolder(EU_TRANSCRIBED) when another; *.epub, sub-folders too; a
  name not in FSeen is marked seen and, unless RecentIndex has it,
  added: oldest first, each Insert at Min(1, Length(FRecent)) (after
  the book read last; the newest ends nearest the front); the title from
  TEpubBook.Create (no text); FRecent cut to RECENT_MAX (more than nine
  new books: the oldest of them are seen but not in the library - Open
  a book lists them); BuildRecentMenu. Debug log "library: added from
  EpubBuilder's output - <file>".
- Not saved at once (SaveSettings at the end, as before: FPendingSpeed
  may not be set yet during FormCreate); a re-scan after a crash adds
  nothing twice (RecentIndex).

## Zip 252 (on top of zip 251): calibration introduction; results' footnote
Owner 2026-11-22 16:58: "Perhaps mention that better estimates will be
available after the user has transcribed a few books. We also need an
introductory screen before Calibration starts. If we peek at the
devices available we may even be able to give a guide as to how long
Calibration will take. The page should state that we need to Calibrate
epubunum to their particular machine and the CPU/GPU it has as these
greatly affect the speed. If we can discover if the machine is likely to
be very slow we can therefore warn them ... If they have decent hardware
we can state that a few minutes. They then have the option to [A]
proceed to Calibration or [B] Come back when I have more time to spare.
A starts calibration, B exits the program". NOT COMPILED. NO PACKAGE
REBUILD. Files: demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/src/uBenchProgress.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- Results: the footnote's first line "Better estimates come once you
  have transcribed a few books: they learn from this machine's own
  builds."; the star / dash notes on a second line. ArrangeTable sizes
  the footnote by its line count (More); the log gets each line.
- CheckCalibrationAtStart: instead of StartCalibration straight away,
  ShowCalibrationIntro(Why) (Why = a re-calibration's reason, or '').
  Only at start-up: models downloaded later still calibrate with no
  question (OfferCalibration, CalibrateNewModels).
- ShowCalibrationIntro: a pad-menu page on the desktop and in Big Picture
  (ShowText, title "Calibration", centred): why, "Found here:" a line per
  device (name - description (processor, N threads / integrated graphics
  / graphics card)), then "a few minutes (roughly X)" up to FEW_MINUTES
  (10 min), else "Owing to this hardware (no separate graphics card)
  calibration may take some time: roughly X. It can be left to run."
  Rows "Calibrate now" (mrYes, selected) / "Come back when I have more
  time to spare" (mrNo = FAskCancel, so B / Escape is it); foot
  PadFootOf([BP_CHOOSE, BP_BACK], ['choose', 'come back later']);
  FAskThenClose (the answer decides). Yes: StartCalibration(True,
  False), FCalAtStart, PadBackToMenu(False) if it did not start. No: a
  log line, Close.
- CalibrationGuess: the models StartCalibration(True) times (ModelFilesOf
  + KeepStandardModels) x every device: MB / 400 + (25 + 120) / speed,
  + 20 s; speed = an earlier calibration's (CalibrationSpeed), else
  GuessSpeed - turbo: CPU threads / 16 (>= 0.2), Metal 20, wdtGPU 15,
  Intel Iris / Arc 2, other Intel 0.7, other integrated 8; smaller
  models by sqrt(1549 / MB) on graphics, 1549 / MB on the CPU. Checked by
  hand: the Miix -> about 10 min (it took 9:53). Debug log: "calibration:
  the introduction's estimate N s".
- LongTime moved above (used by the introduction too).

## Zip 251 (on top of zip 250): calibration results - what they mean for a book
Owner 2026-11-22 16:46: "After Calibration finishes for a newly
installed device the screen immediately switches to the menu. You can
miss the calibration speed for turbo very easily. It would be nice to
show your calibration results and what that meant in the real world.
Find some popular books on Librivox and get their recording length ...
| Title | Time for base | Time for turbo | ... a dozen books ... all of
war + peace (total the parts)". 16:50: "Stress on the Calibration
results page that these timings are extremely approximate and act as a
guide to the performance you can expect". NOT COMPILED. NO PACKAGE
REBUILD. Files: demos/EpubBuilder/src/uBenchProgress.pas,
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- Lengths: LibriVox's API (librivox.org/api/feed/audiobooks/?title=^...
  &format=json, totaltimesecs), the first recording of each title:
  Alice 10731, Time Machine 14969, Treasure Island 27008, Frankenstein
  29808, Adventures of Sherlock Holmes 37079, Pride and Prejudice 47204,
  Tale of Two Cities 53975, Dracula 59469, Jane Eyre 74196, Moby Dick
  88670, Count of Monte Cristo 178995, War and Peace Books 01 - 17
  (ids 722 ... 4104) 232564 (64:36:04). (Maude's 4 volumes, ids 18545 -
  18549: 224833.) Left out: Great Expectations 73563.
- uBenchProgress.ShowTable(title, note, cells, footnote, foot): the
  blocks hidden, a framed table (95 % wide, lines up to 8 % of the
  height, fonts 11 - 32), the note bold in the frame's yellow, the
  heading row bold, the first column left, the others right (17 % each);
  the timer stops; a click on the layer (or the desktop's corner button,
  now OK) is OnButton. Arrange hands over to ArrangeTable.
- uBuilder: CalibrationDone - completed with a view: ShowCalibrationResults
  and stop; otherwise CalResultsClosed (the old end: FreeAndNil(FCalView),
  PadBackToMenu). ShowCalibrationResults: columns Book (LibriVox
  recording) | Recording | base (8.6x) | turbo (0.6x); BookSeconds =
  the benchmarks' estimate (BenchmarkDevice, Core ML key, HistoryExpect:
  calibration speed and the history's ratios); LongTime ('45 min', '3 h
  05 min', '4 days 11 h'); '~' before each time; '*' + footnote below the
  lowest acceptable speed; '-' not installed / calibrated. Note:
  GUIDE_NOTE "A ROUGH GUIDE ONLY - these times are extremely
  approximate: a guide to the performance you can expect". Foot: "Press
  any button to continue" (Big Picture; no button named) / "Press a key
  or click to continue". The table into the log too.
- Going on: FCalResults - PadPress (any pad button), KeyDown (Enter,
  Escape, any character, the menu's keys), the layer's click / OK ->
  CalResultsButton -> TThread.ForceQueue(CalResultsClosed) (not freed
  inside its own event).

## Zip 250 (on top of zip 249): progress blocks 95 % wide
Owner 2026-11-22 16:40: "We chose 80% width for progress bars - they
still get cut off. Lets give them 95%, here's plenty of free space".
uBenchProgress BLOCK_WIDTH 0.8 -> 0.95 (benchmarks and calibration
alike; heights, gaps and fonts unchanged). NOT COMPILED. NO PACKAGE
REBUILD. Files: demos/EpubBuilder/src/uBenchProgress.pas, CLAUDE.md.

## Zip 249 (on top of zip 248): Settings > Lowest acceptable speed
Owner 2026-11-22 16:12, with the Miix's calibration log (i5-8250U, UHD
620; base 6.7x CPU / 8.6x Vulkan0, large-v3-turbo 0.5x CPU / 0.6x
Vulkan0, calibration 9:53): "any driver that scores that badly should be
excluded from transcription / benchmark ... Anything that falls below
say 2.0 is deemed unusable ... a setting that allows the modification
... drop the allowable device cut-off to 0.1 in steps from 2.0 down to
0.0 ... 'Lowest acceptable speed'". NOT COMPILED. NO PACKAGE REBUILD.
Files: demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- FLowestSpeed: tenths, 0 .. LOWEST_SPEED_TOP (20); [Build] LowestSpeed
  ('2.0', invariant); 2.0 before LoadSettings (a first start has no
  file). StepLowestSpeed (wraps, as the combos do; logs the new value;
  RefreshBenchmarks), LowestSpeedText ('< 2.0x >', '< 0.0x - any speed
  >').
- TooSlow(model, device ('' = default), out Why): 0 = never; the model's
  CalibrationBest speed > 0 and below -> too slow on this machine (hours
  per hour of audio, choose base or lower the setting); else the device's
  CalibrationSpeed > 0 and below -> too slow on that device (names the
  best device). Not calibrated / failed (0): not held back.
- Gates: CheckThen (Create, Add to queue, Update job) - Tell('Not
  started: ' + Why) unless a saved transcript is used; RunNextJob - a
  waiting job too slow becomes jsFailed, Note 'too slow here', a log
  line, the next one tried; RefreshBenchmarks - SlowFast / SlowDetailed
  (BenchTooSlow(1) / (2), once per call) grey the items (Run all 4:
  either); StartBenchmark - BenchTooSlow(AOption) says why (a faded Big
  Picture row comes here).
- Settings page: BPC_LOWEST (33) after Power, in BP_SETTINGS_ROWS;
  BPC_SETTINGS_TOP replaces the two "<= 31" guards before "in"; PadStep
  left / right +-1 tenth; chosen = PadStep(-1) ("from 2.0 down").
- PadModels: an installed model below it at its best is faded, value
  "too slow here: 0.6x" (still choosable - to re-calibrate it).
- NOT done (ask): after the start-up calibration the model chosen
  (turbo first) may be too slow (the Miix) - Create then says so;
  switching to base by itself was not asked.

## Zip 248 (on top of zip 247; NEEDS TWhisper-32): calibration bars move within a device
Owner 2026-11-22 15:49: "When calibrating three runs are typically done.
This means the progress bar goes 0, 33, 66, 100. If calibrating a very
slow machine it can look like it's stuck. Can we get some callbacks while
calibrating so the calibration is more granular?" The three steps are
the devices (one pair each, CALIBRATION_RUNS 1): the bar moved only at
OnPair's end. NOT COMPILED. PACKAGE REBUILD (TWhisper's Whisper.Core
interface changed). Files: demos/EpubBuilder/src/uCalibration.pas,
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- TWhisper-32 (TWhisper's CLAUDE.md "Benchmark progress"):
  TWhisperBenchmark.OnProgress(Sender, APhase: wbpLoading / wbpWarmup /
  wbpTiming, APercent of the pair): loading 0 - 10, warm-up 10 - 20,
  timed runs 20 - 100 by whisper.cpp's progress (each 30 s window: a
  120 s stretch = about four steps), 100 when Ok.
- uCalibration: TCalibrationStepEvent(AModel, ADevice, APhase text,
  APercent); TCalibrationThread.OnStep; BenchProgress (Bench.OnProgress,
  on the thread) queues it with FStepModel / FStepDevice (set before
  RunOne) and sends the whole calibration's progress, 100 * (FStepDone +
  APercent / 100) / FStepTotal, to OnProgress (the desktop's bar too).
  Phase texts: 'Loading the model onto', 'Warming up on', 'Timing on'
  (the device's name follows).
- uBuilder: TCalibrationRow.Phase / Step (cleared at OnPair's start and
  end); FCalib.OnStep fills them (a step whose device is no longer the
  row's is left out); CalTick: Pct = (Done + Step / 100) * 100 / devices,
  the middle text Phase + ' ' + Device ("Timing on" + Device before the
  first step).

## Zip 247 (on top of zip 246): macOS - Big Picture full screen through Cocoa
Owner 2026-11-22 15:06: "Mac Big Picture - Still not Full Screen (maybe
it needs Game Mode?)" - zip 210's FMX FullScreen asked for again did not
help. Answered: Game Mode is not it - macOS turns Game Mode on for a game
that is already full screen (and only for the games category; ours is
productivity); it never makes a window full screen. NOT COMPILED. NO
PACKAGE REBUILD. Files: demos/EpubBuilder/src/uMacWindow.pas (new),
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/EpubBuilder.dpr,
demos/EpubBuilder/EpubBuilder.dproj, CLAUDE.md.
- Suspects (no log yet): FMX's FullScreen read True in an ordinary window
  (so zip 210 never asked again), or the NSWindow lacked
  NSWindowCollectionBehaviorFullScreenPrimary (toggleFullScreen is then
  ignored without a word).
- uMacWindow (new, builder only): MacIsFullScreen - the NSWindow's real
  state (styleMask NSWindowStyleMaskFullScreen) or covered by
  MacCoverScreen; MacMakeFullScreen - collection behaviour Primary on,
  Auxiliary / None off, activateIgnoringOtherApps, makeKeyAndOrderFront,
  toggleFullScreen (only while not full screen); MacCoverScreen - the
  fallback: presentation options HideDock + HideMenuBar, BorderStyle None
  (the NSWindow looked up after: FMX may make it again), setFrame to the
  screen's frame. Other systems: FullScreen / nothing.
- tmPadTimer: first look 1.5 s after StartPad (FFullTick set there), then
  every 1.5 s; PAD_FULL_TRIES 4 - tries 1-3 the Mac's full screen, try 4
  covers the screen. Debug lines: "Big Picture: the window is not full
  screen (n of 4) - FMX full screen <b>, visible <b>, collection
  behaviour $x -> $y, full screen asked for", "... macOS did not make the
  window full screen (4 of 4) - the window covers the display (W x H
  points) ...", "... is full screen (after n of 4)". FMX full screen
  True in the first line = suspect 1.
- Names to look at if it does not compile: NSWindow.toggleFullScreen /
  collectionBehavior / setCollectionBehavior / styleMask / screen /
  setFrame(NSRect, Boolean), NSApplication.setPresentationOptions,
  TFmxFormBorderStyle (FMX.Forms or FMX.Types - both used).
- EpubReader on the Mac in Big Picture: not reported; uMacWindow can be
  moved to demos/common for it if it shows the same.

## Zip 246 (on top of zip 245): at most four blocks at a time
Owner 2026-11-22 14:27: "What happens if the user loads all models then
chooses Calibrate All? Each bar is 20% so the height required will
exceed 100%". Answered: Arrange shrank every block to fit 90 % - ten
models gave blocks of ~7 % (59 px on a Deck, fonts at their minimum 11).
Offered (1) four at a time, scrolling, or (2) a compact form; owner
14:28 "(1)". NOT COMPILED. NO PACKAGE REBUILD. Files:
demos/EpubBuilder/src/uBenchProgress.pas, demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/README.md, CLAUDE.md.
- uBenchProgress: MAX_VISIBLE 4; FHeader (a centred line above the
  blocks, HEADER_HEIGHT 0.35 of a block, shown only with more than four);
  FTop - the first block shown; Arrange lays out at most four (the rest
  Visible False), sized as before for four plus the header (Deck 800 px:
  141 px blocks, 1080p: 191 px). SetCurrent(index): FTop = index, kept
  within [0, N - 4] (the last four stay at the end); SetHeader(text).
- CalTick: Current = the first model not ended -> SetCurrent and "Model
  k of N"; all ended -> the last four, "All N models calibrated". The
  benchmarks (at most four) are unchanged.

## Zip 245 (on top of zip 244): the main menu after the start-up calibration
Owner 2026-11-22 14:24: "After automatic calibration on first start it
should end up on the main menu not the settings menu as it currently
does". CalibrationDone's PadBackToMenu(True) = PadHome(BPC_MODEL), a row
of the Settings page (zip 205's "back on Model, for the next one").
FCalAtStart (new): set when CheckCalibrationAtStart started a
calibration (also the first model's, FCalibPending); CalibrationDone
then PadBackToMenu(False) = PadHome(BPC_BOOK), the first page, and
clears it. Calibrations from Settings, of a model added later, or
after Download every model still come back on Model. NOT COMPILED. NO
PACKAGE REBUILD. Files: demos/EpubBuilder/src/uBuilder.pas, CLAUDE.md.

## Zip 244 (on top of zip 243): the calibration's progress bars; new models calibrate by themselves; Re-calibrate
Owner 2026-11-22 14:15: "We need a Calibration progress bar, similar to
the Benchmark version adapted to role. When the user starts the first
thing they should see is the Calibration taking place. When this has
finished they get to see the menu"; 14:16: "If models are added later on
they should also auto-calibrate - The Calibrate menu options will become
Re-Calibrate options". NOT COMPILED (pasdoc_check, project_check: 0
problems). NO PACKAGE REBUILD. Files: demos/EpubBuilder/src/uCalibration.pas,
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- uCalibration: TCalibrationPairEvent (model index, device index,
  speed); TCalibrationThread.OnPair - Pair(M, D, -1) before each pair
  (skipped ones too), Pair(M, D, speed or 0) after it (not on a Cancel
  mid-pair); queued to the main thread. Not called by the diagnostics.
- uBuilder: TCalibrationRow (Model, Started, Ended, Done, Device, Best,
  BestSpeed); FCalRows filled in StartCalibration from the models list;
  FCalib.OnPair keeps them; FCalView (a TBenchProgress, the benchmarks'
  view: frames, dark / light, Cancel in the corner on the desktop) made
  just before FCalib.Start, a block per model "Calibrating <label> :
  <device names>"; CalTick: the clock from the model's first pair to its
  last (BenchClock), "Waiting" / "Timing on Vulkan0" / "Done - fastest:
  Vulkan0 (92.1x)" (the fastest that succeeded - the choice itself may
  leave a suspect device out: CalibrationBestIndex) / "Done - no device
  could run it", the share = devices done. The pad's menu is hidden when
  it starts; CalibrationDone frees the view, then PadBackToMenu(True).
  Big Picture start: StartPad no longer shows the home list when
  CalibrationDueAtStart (new: whisper.cpp and devices there, not DontAsk,
  and no calibration / other devices / an older method) - the
  calibration (AfterShow) is the first thing seen, the menu after it.
- New models: OfferCalibration no longer asks - it calibrates the
  model in the window when it is not calibrated (after a download, on a
  choice; DontAsk still respected); FCalibDeclined gone. Download every
  model: at its end CalibrateNewModels (FCalOnlyNew: StartCalibration
  with AAllModels keeps only the models without a calibration; nothing
  when all have one).
- Wording: Big Picture's rows "Re-calibrate (this model)" / "Re-calibrate
  every model" (the desktop's items were Re-calibrate already); "Settings
  > Calibrate" -> "Settings > Re-calibrate" in every log line; README.
NAMES TO LOOK AT if the compiler complains: TCalibrationPairEvent
(reference to procedure) and the anonymous OnPair in StartCalibration
(FCalRows / FDevices of Self); Row / Titles / Names locals in
StartCalibration; the empty "then" in StartPad (if ... then else if);
CalTick's body after BenchClock; Models.Free + Exit in the FCalOnlyNew
branch (Models made just above, before the try that frees it).
TO TEST (owner): first start with the depots (no settings): the bars
straight away (desktop and Big Picture), base and turbo, the menu after;
choose / download another model in expert mode - it calibrates at once
with the bars; Download every model - the new ones calibrate at the end.

## Zip 243 (on top of zip 242): calibrated at start-up straight away
Owner 2026-11-22 13:59: the models now ship in Steam depots ("setting up
the depots was easy, only needed the files. All done"): one depot for
every OS with models/ggml-base.bin and models/ggml-large-v3-turbo.bin, a
macOS one with models/ggml-base-encoder.mlmodelc/ and
models/ggml-large-v3-turbo-encoder.mlmodelc/ (unzipped from
huggingface.co/ggerganov/whisper.cpp's *-encoder.mlmodelc.zip). 14:09:
"As models are pre-installed Big Picture should directly calibrate the
models - this doesn't happen. On Desktop mode I get a big warning pop-up
- this should be the same as Big Picture". NOT COMPILED. NO PACKAGE
REBUILD. Files: demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/README.md, CLAUDE.md.
- Why Big Picture did nothing: no model was chosen on a first start, so
  CheckCalibrationAtStart took its "no model to calibrate" branch
  (FCalibPending) - the depot's models were never picked.
- CheckCalibrationAtStart: with FModelPath '' it chooses turbo, else base,
  from FModelsFolder (FillModels, SaveSettings; log "Model: turbo
  (installed with EpubBuilder)"); then - not calibrated, other devices,
  or the old method - NO question and NO dialog on either: a log line
  with the reason and StartCalibration(True, False) = every model (base
  + turbo; the expert list in expert mode). [Calibration] DontAsk (set by
  the old dialog's "Do not show this again") is still respected (a log
  line only). uCalibration.AskCalibration is no longer called (kept, in
  case a question is wanted back). FCalibPending (no model at all): the
  first model downloaded or chosen calibrates every model the same way.
  OfferCalibration (a model downloaded / chosen later, not calibrated:
  "Calibrate it now?") is unchanged.
TO TEST (owner): a machine with the depots and no EpubBuilder.ini (or
Method < 2): desktop and Big Picture start calibrating base and turbo at
once, the log says why, the bars / progress show it, Cancel stops it.

## Zip 242 (on top of zip 241): step 2 - the calibration on a continuous stretch
Owner 2026-11-22 13:34 "OK, Benchmark estimates are a lot better now"
(zip 241 run); 13:37, asked which step next: "2". The plan of zip 205's
notes, built. NOT COMPILED (pasdoc_check, project_check: 0 problems). NO
PACKAGE REBUILD. Files: demos/EpubBuilder/src/uCalibration.pas,
demos/EpubBuilder/src/uHistory.pas, demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/README.md, CLAUDE.md.
- uCalibration: CALIBRATION_STRETCH_SECONDS 30 -> 120, CALIBRATION_RUNS
  3 -> 1: ONE run of the clearest 120 s of chapter material
  (FindReferenceStretch, 30 s from both ends of its section; sections
  shorter than 180 s cannot hold it: the longest is then used, as
  before). The fallback stays on. CALIBRATION_METHOD = 2 written as
  [Calibration] Method by CalibrationSave; each model's section gets
  Seconds = 120. CalibrationMethod (1 when Done without Method, 0 with no
  calibration), CalibrationSeconds (the section's Seconds;
  CALIBRATION_OLD_SECONDS 30 for a section without it; 0 not
  calibrated). Status / log texts: "120 s of speech timed", "one run of
  120 s"; the diagnostics' "The calibration timed it there at ... (N s of
  speech)".
- uHistory: TBuildHistoryRow.CalibrationSeconds, column calibration_s
  (last; HEADER + ',calibration_s'; MID_HEADER = the header of zips
  before, upgraded like OLD_HEADER; rows without it read 0 = the old
  30 s kind). HistoryExpect(.., ACalibrationSpeed, ACalibrationSeconds,
  ..): rule 2's ratios only from rows of the same model AND the same
  kind of calibration (Long: > HISTORY_SHORT_CALIBRATION 45 s); rule 3:
  HISTORY_BOOK_RATIO_CONTINUOUS 1.0 for a long calibration (to be
  measured on the machines), HISTORY_BOOK_RATIO 1.35 for an old one.
- uBuilder: PrepareEstimate and RefreshBenchmarks pass
  CalibrationSeconds; RecordHistory keeps it in the row (0 when the pair
  was not calibrated). CheckCalibrationAtStart: Old = Done and Method <
  CALIBRATION_METHOD - treated as out of date: "The calibration has
  changed since yours of <date>: it now times two minutes of speech in
  one run ... Every model here is calibrated again." and Yes runs
  StartCalibration(Old, ..) = every model (base + turbo, the expert list
  with expert mode). The calibration's header and start-up texts say two
  minutes, one run.
- What to expect: the calibration's speeds DROP towards a book's (turbo
  no longer encodes a short clip twice; base / .en models' retries now
  happen in it) - turbo on the 5090 near its ~92x as a book (was 82.9x
  calibrated against 30 s, faster than the book only through the clip),
  base near its 97 - 120x (was 140.9x). The ranking of devices should
  not change for turbo; for small models it may (retry-heavy devices
  lose). Time: about the same as 3 x 30 s + a warm-up per pair.
- Every machine must be calibrated again (the start-up offer does it);
  after that the benchmarks' and builds' estimates use the new kind only.
NAMES TO LOOK AT if the compiler complains: HistoryExpect's new
parameter in both callers; the nested Long function before HistoryExpect's
begin; Ini.ReadInteger / WriteInteger on the sections; Old captured by the
pad question's anonymous method (CheckCalibrationAtStart).
TO TEST (owner): start EpubBuilder - the "calibration has changed" offer;
Yes: base and turbo calibrated, the log's per-device lines "one run of
120 s from h:mm:ss into the section"; EpubBuilder.ini: [Calibration]
Method=2, Seconds=120 per model; a benchmark afterwards - its Expected
line, then EpubBuilder-history.csv's last column 120.

## Zip 241 (on top of zip 240): the benchmarks' estimates
Owner 2026-11-22 12:58, screenshots (the 5090, Vulkan0): the menu said
Short / Fast about 0:00:07 and Long / Fast about 0:00:25, the scores
were 0:00:26.4 and 0:01:54.8 (Detailed: 0:00:38 / 0:02:10 against
34.6 / 2:04.5 - fine). "The estimates are sometimes way off compared to
results. They should be fairly close at least". The log: "Expected:
about 00:00:07.300 for 00:56:22.850 of audio - 479.8x real time, from
the calibration (140.9x) times 3.41 - how 10 earlier build(s) here
compared with their calibration". CAUSE: HistoryExpect's rule 2 took the
ratio from the last 10 builds of ANY model here - turbo's, against stale
calibrations (zip 201: a 26.1x turbo calibration while it built at
~100x) - and base had no build of its own (benchmarks were not recorded).
NOT COMPILED. NO PACKAGE REBUILD. Files: demos/EpubBuilder/src/uHistory.pas,
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- uHistory.HistoryExpect: Ratios only from rows of the same model; the
  source text names the model. (The deferred step 2 - calibration
  length per row, like with like - is still to do.)
- BuildDone: a benchmark that succeeded is RECORDED in the build history
  (RecordHistory; was skipped since zip 230) - a whole book's build, so
  rule 1 (this model on this device) gives the next estimate, for
  benchmarks and books alike. The "Open ... in EpubReader" line and
  FMadeBook stay for books only. Its TranscribeSeconds is the whole
  transcription (with the sections' edges): the estimate is of the whole
  run, the score of the chapter material - the score stays a little
  under it.
OPEN, owner 12:58: "I THINK Christmas Carol may be stalling" - asked for
the run's log (Benchmarks\A Christmas Carol (Long Text, Fast
Model).epub.log: "Part n of 5 ... s" per stave) and
EpubBuilder-debug.log (whisper.cpp's timings per part: fallbacks).
Seen: base ran the Carol at 97x (186 min in 1:54.8) against the
Scandal's 120x; turbo the same on both (~92x). Suspects: base's
temperature-fallback retries on that reading (slow windows in bursts),
and each stave's audio decoded before it is transcribed (the clock
stands still meanwhile; 54 min of AAC per stave).

## Zip 240 (on top of zip 239): every menu's foot - Steam's glyphs or the keys
Owner 2026-11-22 12:43, a screenshot of the Results ("A answer B no X / H
hide"): the standing rule above; 12:44 "This applies to ALL menus". NOT
COMPILED (pasdoc_check, project_check: 0 problems). NO PACKAGE REBUILD.
Files: demos/EpubReader/src/uPadMenu.pas, demos/EpubReader/src/uMain.pas,
demos/EpubBuilder/src/uBuilder.pas, CLAUDE.md.
- uPadMenu (SHARED): TPadHint (Glyph, Name, Text); TPadMenu.Hint,
  HintsText (the words - "Enter choose   Esc back" - given to Show as its
  foot: they size the box), SetHints (the foot drawn as a row in its
  middle: each control's picture at 90 % of the foot's height, else its
  name, then its words; a hint without words joins the next - "<left>
  <right> change"; the same hints again draw nothing - FHintKey),
  HasHints; Show and SetFoot take the hints away (ClearHints).
- EpubBuilder: BP_FOOT / BP_FOOT_KEYS gone; BP_FOOT_BUTTONS /
  BP_FOOT_TEXTS (choose, back, left+right change, close, the queue);
  PadHintsFor(buttons, texts, keys) - FPad.Origin's Glyph / Name, else
  ReaderMenuFirstKey; PadFootOf keeps FFootButtons / FFootTexts and
  returns the words; RefreshFoot draws them. Now hints: the home list and
  its Settings page, the queue, Controls, every Ask (answer, no /
  cancel), the pairing box (A / B refuse -> <choose> <back> refuse), the
  Results (answer, no, hide). SetPadKeys: any foot with hints changes
  over (was the home and queue lists only); the timer's idle foot is
  hints again after a build's status line. The other lists' feet are
  sentences (a folder, the model advice) and stay text.
- EpubReader: FPadKeys (set by a menu key in FormKeyDown, cleared by a
  pad press in tmPadTimer) and SetPadKeys; PadMenuFoot keeps FFootChange
  and returns the words; PadFootHints / RefreshPadFoot after the menu's,
  Contents' and Controls' Show. Before: the pad's NAMES as text, Enter /
  Esc without a pad.
NAMES TO LOOK AT if the compiler complains: dynamic-array literals passed
to TArray<Integer> / TArray<string> parameters (PadFootOf([BP_CHOOSE,
BP_BACK], ['answer', IfThen(...)])) and of records (PadFootHints' Result
:= [One(..), One(..)]); TPadHint in both programs (uPadMenu); the nested
Word procedure in SetHints using the outer W, L, X, H, Size, Color;
TImageWrapMode (FMX.Objects); BP_FOOT_BUTTONS above PadFoot.
TO TEST (owner): an Xbox pad and a PS4 / PS5 pad (Steam's pictures, no
letters), then the keyboard (Enter, Esc, Left / Right, F2, F3, H) - the
foot changes over at the next key or press without the menu closing;
the Results, a question, the home list, Controls, the reader's menu.

## Zip 239 (on top of zip 238): the benchmarks' names - "Short Text, Fast Model"
Owner 2026-11-22 12:36: "From e.g. Short + Fast -> Short Text, Fast
Model i.e. just append Text + Model". BENCH_NAMES: Short Text, Fast
Model / Short Text, Detailed Model / Long Text, Fast Model / Long Text,
Detailed Model (Run all 4 benchmarks unchanged). They name the menu
items, the bars, the results rows, a kept book's file ("<title> (Short
Text, Detailed Model).epub") and benchmarks.csv's Benchmark column (rows
before 239 say "Short + Detailed"). NOT COMPILED. NO PACKAGE REBUILD.
Files: demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.

## Zip 238 (on top of zip 237): dark before the builder's window is drawn
Owner 2026-11-22 12:32: "The screen briefly flashes white on form load
before the theme takes over. Can we switch theme before anything is
shown?" The dark window was applied only by StartPad (from FormShow, in
Big Picture through BigPictureWindow) and tmDark (500 ms): the first
frames had the style's light background. NOT COMPILED. NO PACKAGE
REBUILD. Files: demos/EpubBuilder/src/uBuilder.pas, CLAUDE.md.
- DarkBeforeShow (new): when dark, ApplyStyleLookup on the memos and
  lists of the window's layouts (what ApplyDarkWindow walks), then
  ApplyDarkWindow - the form's fill dark, the memos' style backgrounds
  off, the labels and lists light-on-dark at once. Called at the end of
  FormCreate and first in FormShow (before StartPad); tmDark goes on as
  before (a style applied again).
- FOUND: a first start (no settings file) came up LIGHT - LoadSettings
  reads [View] Dark (default True, zip 203) only from an existing file
  and FPadDark started False. FPadDark := True before LoadSettings.
- A frame drawn by the system before FMX's first paint (the native
  window's own background) is outside FMX's reach: if a flash remains,
  say on which system.

## Zip 237 (on top of zip 236): Results - a table, centred title; X / H hides them; frames 4 px
Owner 2026-11-22 12:23, a screenshot of Run all 4 with zip 235's frames
("Nicer but make the border 2x as thick"): "When it finishes it returns
to a panel that is headed "Note"... Heading Results (centered). Remove
Scored (transcription time). List results as a table - Benchmark on
left, score on right (right aligned). Add a "X" button / H key binding
that Hides/Shows the results". NOT COMPILED (pasdoc_check, project_check:
0 problems). NO PACKAGE REBUILD. Files: demos/EpubReader/src/uPadMenu.pas,
tools/gen_reader_input.py, demos/EpubReader/src/uReaderInput.pas and
demos/EpubReader/steaminput/controllers/*.vdf (11, REGENERATED - only
their revision lines; the manifest unchanged; LF as committed - the
generator writes CRLF here, converted back),
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/src/uBenchProgress.pas,
demos/EpubBuilder/README.md, CLAUDE.md.
- uPadMenu (SHARED): TPadMenuItem.Info - a line of information: Move
  passes over it (in the direction moved), Show never selects it, a click
  on it does nothing (FInfo per row, cleared with the rows); Item sets it
  False. NextTitleCentered - the next Show centres its title, then left
  again.
- Steam Input rule: pad X is the action "Again" (the reader's "say it
  again") already; gen_reader_input.py MENU_KEYS + ("Again", "char", "H",
  "H"); LAYOUT_REVISION 3 -> 4, LAYOUT_MAJOR 1 -> 2 (an interaction
  added). The builder: BP_TOGGLE = 8, BP_ACTIONS + 'Again' (its TSteamPad
  now reads 9 actions); Controls lists "Show / hide results" (X, H). The
  reader does not look keys up in the menu table (its own FormKeyDown),
  so H changes nothing there.
- Results (BenchmarkFinished -> BenchShowResults), in the pad's menu on
  the desktop too: title "Results" centred; a row per benchmark (name,
  score as the value on the right), Info rows; a blank Info row; "Keep
  the book(s) to read in EpubReader?" (Info); with a Fast book offered
  "Detailed makes the better book." (Info, faded); Yes / No (No
  selected) - or OK without books. "Score (transcription time)" gone.
  Answers as Ask's (FAskResults, FAskProc; B / a click beside = No);
  FAskThenClose: on the desktop PadAnswer closes the menu instead of
  showing the home list. FBenchKeep / FBenchCandidates /
  FBenchFastOffered hold what the answer needs (shown again by X / H).
- BenchToggleResults (X / H; the corner button, now "Hide results" /
  "Show results" - TBenchProgress.SetButtonText, OnCancel renamed
  OnButton): hidden = FPadMenu.Hide with the question kept open
  (FPadMode BPM_ASK); while hidden any button or menu key shows them
  again (PadPress, FormKeyDown).
- uBenchProgress: frames 4 px (were 2); the corner button 140 wide.
ASKED, ANSWERED (no code), 12:26: "Where are the output texts stored? I
see nothing in [Documents]\Epubunum\Transcribed" - a benchmark's book is
written to <settings folder>\Benchmarks (Windows: %APPDATA%\EpubUnum\
Benchmarks) and DELETED unless the question is answered Yes (No is the
default); Yes copies it to the output folder (Transcribed unless the
output folder was changed). The run's .log files and benchmarks.csv stay
in Benchmarks.
NAMES TO LOOK AT if the compiler complains: Items[High(Items)].Info and
Row.Info; FPadMenu.NextTitleCentered; the empty "then" before "else if"
in FormKeyDown (a comment only); FAskProc's anonymous method using the
FBench* fields; BP_ACTIONS[0..8] wherever its length was assumed 8.

## Zip 236 (on top of zip 235): the bar's clock is the score
Owner 2026-11-22 12:11: "the timing for the benchmark for the progress
bars should be the same. Before transcription starts the clock shows
00:00:00.000 and the status (middle) says "Preparing Benchmark", we then
get to transcription and the clock starts. After transcription ends the
clock stops and the status says "Finalizing"". NOT COMPILED. NO PACKAGE
REBUILD. Files: demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/README.md, CLAUDE.md.
- TBuildThread.BenchElapsed (public, any thread): Summary.BenchSeconds
  so far + (while a timed piece runs: FBenchFrom set in Transcribe) the
  piece's time without the time asleep - the very sum the score is, so
  the clock ends on the score. FBenchFrom cleared when the piece ends
  (before its time is added) and on Cancel.
- BenchTick: phases Preparing Benchmark (until the transcription's
  first progress or "Part ..." status) / Transcribing / Finalizing
  (owner's spelling; >= 90 %); clock = FBuild.BenchElapsed; Done shows
  FBenchScores (the score), Stopped the last clock (FBenchClock), Waiting
  00:00:00.000. FBenchStart / FBenchEnd gone (FBenchEnded, FBenchClock);
  BenchClock takes seconds.
- The clock stands still while each section's first and last 30 s are
  transcribed (not timed): a fraction of a second each on a fast GPU.

## Zip 235 (on top of zip 234): a frame round each benchmark's block
Owner 2026-11-22 12:04, screenshots of Run all 4 and of a Short + Fast
end on the 5090 ("That's more like it"): "The progress bar needs a
border around it (Yellow with rounded corners?) ... 4 benchmarks at once
- it is unclear which is which". uBenchProgress: TBenchRow.Box is a
TRectangle - no fill, a 2 px stroke FRAME_DARK $FFE8C547 / FRAME_LIGHT
$FFC99A06, corners of FRAME_PAD (10 % of the block's height), the same
pad inside on all sides; the title, bar and line laid out in the inside
(fonts 18 % of the inside's height, 11 - 28). FMX.Layouts out of its
uses. NOT COMPILED. NO PACKAGE REBUILD. Files:
demos/EpubBuilder/src/uBenchProgress.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
ASKED, ANSWERED (no code): "Why does the elapsed time say 31.497 when
the score says 26.552?" - the time under the bar is the whole run
(reading the book and the audio, loading the model, all three sections
transcribed WITH their first / last 30 s - 3 min of the 56 - aligning
and writing the EPUB); the score is only the middle pieces'
transcription (chapter material). The first shot: Short + Fast (base,
Vulkan0) scored 0:00:26.552, 31.497 s in all.

## Zip 234 (on top of zip 233): the bar's device as the log has it
Owner 2026-11-22 11:55: "The log shows stuff like... Device: Vulkan0 -
NVIDIA GeForce RTX 5090 Laptop GPU (GPU, Vulkan, 22.7 of 23.6 GB free).
The bit after Vulkan0 - is fine for the description". BenchTitle:
WhisperDeviceText(D) without its leading "<name> - " (was Backend + ' on '
+ Description). NOT COMPILED. NO PACKAGE REBUILD. Files:
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.

## Zip 233 (on top of zip 232): the benchmarks' progress bars
Owner 2026-11-22 11:51: a progress bar per benchmark - "At the top ... a
label with the benchmark name along with some very basic details - Text
being transcribed by what device e.g. Scandal in Bohemia : Vulkan on
NVIDIA RTX5090. Under that is the progress bar. Under the progress bar
left aligned is current runtime HH:MM:SS.nnn and right aligned is
percentage of transcription done. In the middle ... Warming Up / Reading
Book / Transcribing / Finalising. This bar can take up to 80% of the
screen width and 20% of the height. You may select up to 4 benchmarks
... up to 4 bars are shown with a gap vertically - ... the space on each
side above/below and left/right are balanced". READ AS: Run all 4 = four
bars, one benchmark = one (the menu has no multiple choice - ask if a
pick of 2 or 3 was meant). NOT COMPILED (pasdoc_check, project_check: 0
problems). NO PACKAGE REBUILD. Files: demos/EpubBuilder/src/uBenchProgress.pas
(NEW), demos/EpubBuilder/EpubBuilder.dpr, demos/EpubBuilder/EpubBuilder.dproj
(one DCCReference line, by hand), demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/README.md, CLAUDE.md.
- uBenchProgress (a unit of its own: FMX.Objects' TRectangle; its TPath
  would hide System.IOUtils.TPath in uBuilder - zip 182): TBenchProgress
  (TComponent owned by the form): an opaque TRectangle Align Contents
  over the window (dark / light from [View] Dark), a block per title -
  title label, a track and fill (TRectangles, not TProgressBar: the same
  look in dark and light, every platform), then Time (left), Phase
  (centre), Percent (right) on one line. Arrange (on the layer's
  OnResized): blocks 80 % of the width, 20 % of the height each, a gap
  of a quarter block, all together at most 90 % of the height (smaller
  blocks then), centred both ways; fonts 16 % of a block, 11 - 28. A
  Cancel button bottom-right on the desktop (OnCancel); a 100 ms TTimer
  -> OnTick. SetRow(index, time, phase, percent).
- uBuilder: StartBenchmark makes the view (FBenchView; titles from
  BenchTitle: "<name> - <title> : <Backend> on <Description>" of the
  device BenchmarkDevice gives); FBenchList (the run's options in order),
  FBenchStart / FBenchEnd / FBenchPct per option; BenchTick: the running
  one from FPercent / FStatusText - transcription % = (FPercent - 5) / 85;
  phase: >= 90 Finalising (100 %), > 5 or a "Part ..." status
  Transcribing, a "Loading ..." status Warming Up, else Reading Book;
  ended ones Done (100 %) or Stopped; the rest Waiting. Time =
  Now - start (HH:MM:SS.mmm, BenchClock) - the run's wall time, not the
  score. BenchCancel = btnCancelClick. The view stays (final bars)
  until the keep-the-book question is answered, then FreeAndNil.
NAMES TO LOOK AT if the compiler complains: TRectangle.OnResized,
TStyledSetting / TTextTrimming / TTextAlign (FMX.Types), TBrushKind
(FMX.Graphics), the constructor's reintroduce, TCommonCustomForm as the
owner and parent; in uBuilder BenchClock (a plain function below
PadBenchmarks, above BenchTick), MSecsPerDay, IfThen not used on
numbers here.
TO TEST (owner): Run all 4 - four bars centred, Waiting until each
starts, the phases in order, the time ticking in ms, the % to 100, Done;
resize the window (desktop) - the blocks follow; Cancel (button, and
the pad's menu in Big Picture) - Stopped, no score; dark and light.

## Zip 232 (on top of zip 231): a Benchmark menu of five, times expected, the score a time
Owner 2026-11-22 11:34: "As we have calibration for each model we can
display the estimated time it will take for the benchmark to run. Let's
make Benchmark it's own menu with 5 options: Run All 4 Benchmarks - ETA,
Short + Fast - ETA, Short + Detailed - ETA, Long + Fast - ETA, Long +
Detailed - ETA. Don't tell them where things are saved and take out the
leaderboard thing (I know) they're not bothered about the model, text or
device either. All we want is a score which is Transcription time in
H:M:S.nnn". REPLACES zip 230's File > Benchmark Lite / Full, its Quick /
Detailed question (AskChoice - gone) and its score box. NOT COMPILED
(pasdoc_check, project_check: 0 problems). NO PACKAGE REBUILD. Files:
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- Short = BENCHMARK_LITE_REFERENCE (the Scandal), Long =
  BENCHMARK_FULL_REFERENCE (the Carol); Fast = base, Detailed = turbo
  (BENCH_NAMES / BENCH_REFS / BENCH_DETAILED, option 0 = Run all 4).
- Desktop: a top-level &Benchmark menu after File: miBench[0] (Run all 4
  benchmarks), a separator, miBench[1..4]. Text "<name> - about
  H:MM:SS" (HmsText); no estimate, no suffix. Enabled: nothing running,
  whisper.cpp there, the option's model there (Run all 4: both).
- RefreshBenchmarks (from UpdateControls): the estimates worked out
  again only when a key changes (both models there, both
  CalibrationSummary lines, the window's device, the history file's
  time) and nothing runs: the recordings' lengths once (FFmpeg,
  FBenchAudio), then per option HistoryExpect as PrepareEstimate does
  (machine, model, device with +CoreML, calibration speed) WITHOUT
  touching FExp* (a running build's time left); ETA = audio / speed +
  after share x audio, of the WHOLE recording; Run all 4 = the sum when
  all four are known. New texts -> mnuMain.RecreateOSMenu.
- Big Picture: one home row "Benchmark" (BPC_BENCH 32, faded when no
  option can run - chosen then, it says why) -> PadBenchmarks
  (BPM_BENCH 9): the five rows, value "about H:MM:SS", faded when not
  available, and Back; B goes back to the home list's Benchmark row.
- Run: StartBenchmark(option) -> FBenchQueue ([1..4] or [option]),
  RunNextBenchmark -> RunBenchmark (zip 230's build, output "<title>
  (<name>).epub" beside the settings); BenchmarkDone keeps the score
  (Summary.BenchSeconds: the chapter material's transcription time),
  appends the CSV line SILENTLY (Benchmarks/benchmarks.csv: Date,
  Benchmark, Score, Transcription s, Chapter material s, Words, Words
  matched, Model, Device, Device text, Build - for later), then the next
  through TThread.ForceQueue(nil, RunNextBenchmark), or
  BenchmarkFinished. A failure or Cancel stops Run all 4. BuildDone does
  not show the pad's home list between two benchmarks.
- BenchmarkFinished: "Score (transcription time)" / "Scores ..." and a
  line per benchmark "<name>: H:MM:SS.mmm"; then "Keep the book(s) to
  read in EpubReader?" - No by default; Run all 4 offers the two
  Detailed books; with a Fast book offered, "Detailed makes the better
  book ...". No paths, no model / text / device, no leaderboard in what
  the user is shown (the window's log still has the build's own lines).
NAMES TO LOOK AT if the compiler complains: miBench (array[0..4] of
TMenuItem field) and High(miBench); FBenchScores / FBenchBooks /
FBenchAudio / FBenchEta static array fields; BENCH_NAMES / BENCH_REFS /
BENCH_DETAILED typed constants (below the BPC_ block, above their
users); TBuildHistory / HistoryLoad / HistoryExpect / HistoryMachine
(uHistory); TThread.ForceQueue(nil, RunNextBenchmark) (a method, as
AfterShow); Delete(FBenchQueue, 0, 1); IndexStr with a TArray<string>;
the anonymous method's own var K in BenchmarkFinished; I in BuildMenu.
TO TEST (owner): the menu's five items with times (a calibrated machine)
and greyed ones without a model; Short + Fast end to end - one score
line, the question (No selected); Run all 4 - four builds, four scores,
the Detailed books kept on Yes; Big Picture's Benchmark list and Back.

## Zip 231 (on top of zip 230): keeping a benchmark's book - No by default
Owner 2026-11-22 11:25: "The default for Saving the resultant book should
be no". BenchmarkDone's Ask: ADefault mbNo (was mbYes); README.
NOT COMPILED. NO PACKAGE REBUILD. Files:
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.

## Zip 230 (on top of zip 229): Benchmark Lite and Benchmark Full
Owner 2026-11-22 11:09: "2 new menu options Benchmark Lite + Benchmark
Full. If the user has both base + turbo they can choose between them
labelled as Quick + Detailed then benchmark. If they only have one of
those models go straight to benchmarking. If they have neither model
Benchmarks are unavailable (Greyed out). The audio to use with
benchmarks: Lite = Scandal, Full = Carol. The benchmark then does a
transcribe using the selected model + text. At the end they are shown
the score - which will be added to Leaderboard when that's set up. They
may also save the resulting epub for reading later with Reader (they
should be advised that Detailed will provide the superior result)".
NOT COMPILED (pasdoc_check, project_check: 0 problems). NO PACKAGE
REBUILD. Files: demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/src/uCalibration.pas, demos/EpubBuilder/README.md
("Benchmarks"), CLAUDE.md.
- uCalibration: BENCHMARK_LITE_REFERENCE 0, BENCHMARK_FULL_REFERENCE 1,
  BENCH_EDGE_SECONDS (= 30), BENCH_QUICK_MODEL 'ggml-base.bin',
  BENCH_DETAILED_MODEL 'ggml-large-v3-turbo.bin'.
- A BENCHMARK IS A REAL BUILD (StartJob(Job, -1, True) -> TBuildThread.
  Benchmark): book = the reference EPUB, audio = its recording, chapters
  as parts, Reuse off, language en, device = the model's calibrated best
  (else the window's), output <settings folder>/Benchmarks/<title>
  (Benchmark Quick|Detailed).epub (+ its .log). No ReadSaved / ReadPartial
  / SavePartial / SaveTranscript; RecordHistory not called.
- CHAPTER MATERIAL ONLY (standing rule): Transcribe cuts each part of at
  least 3 x 30 s into three pieces - [0, 30 s), the middle, the last
  30 s - each its own Execute / Clean / FillGaps / Trim / Append (offset
  = part offset + piece start); only the middle is timed
  (Summary.BenchAudioSeconds / BenchSeconds, the time asleep left out).
  A build's part is one piece, the same calls as before (Piece :=
  Samples, no copy). ScoreBenchmark (after LogResults): the aligner's
  book words with a time inside the middles (exact, similar,
  interpolated, not heard, moved - the verdict's "timed") ->
  BenchWords, of them exact or similar -> BenchMatched; the log's
  "BENCHMARK - ..." line. The book written is whole (every piece timed
  in it). Cutting at 30 s may cost a word at each cut (a window edge,
  as any) - the same cuts on every machine.
- THE SCORE SHOWN: Speed (x real time) and Accuracy (%), both of the
  chapter material. NOT DECIDED (owner, with the leaderboard): one
  number or two, and how they combine. Every run is appended to
  <settings>/Benchmarks/benchmarks.csv (Date, Benchmark, Reference text,
  Model (Quick/Detailed), Model file, Device, Device text, Speed x,
  Accuracy %, Words, Words matched, Chapter material s, Transcription s,
  Build) - no machine or user name (privacy rule).
- The window: File > Benchmark Lite... / Benchmark Full... (above
  Settings), Enabled = not busy, whisper.cpp there, base or turbo in the
  models folder (BenchmarkModels; UpdateControls). Big Picture home
  list: BPC_BENCH_LITE 32 / BPC_BENCH_FULL 33 above Controls, value =
  the reference text's title, faded (TPadMenuItem.Dim) when not
  available; choosing a faded one says why (StartBenchmark's Tell).
  StartBenchmark: both models -> AskChoice('Quick (base)', 'Detailed
  (large-v3-turbo)', default Detailed); one -> RunBenchmark at once.
  AskChoice (new): Big Picture = the pad's question rows (CHOICE_BASE
  1000 + index in FAskResults, Cancel), desktop = a small modal window
  (as uCalibration.AskCalibration). BenchmarkDone (from BuildDone, after
  the log is saved): the score in the log, the CSV line, then Ask "Keep
  the book to read in EpubReader?" (default No - zip 231; Quick adds that
  Detailed makes the better book) - Yes copies it to the output folder
  (FOutFolder, which the reader lists), either way the Benchmarks copy
  is deleted. A failed or cancelled benchmark: no score, its book
  deleted.
NAMES TO LOOK AT if the compiler complains: StartJob's new default
parameter (declaration and body); TArray<Integer> literals (Pieces :=
[0, Edge, ...]); Ranges + [..] on TArray<Double>; the anonymous methods
in StartBenchmark (capturing Ref, Quick, Detailed), BenchmarkDone
(OutFile, Kept) and AskChoice (Done); TStreamWriter.Create(file, True,
TEncoding.UTF8); string.Join with an open array; FormatFloat with
TFormatSettings.Invariant; TBorderIcon / TFormPosition / RectF in
AskChoice; Items[High(Items)].Dim in PadHome; the new fields after
miRocm (still the fields' section).
TO TEST (owner): File menu greyed with neither model; one model -> it
starts; both -> Quick / Detailed (desktop window, Big Picture rows);
Lite on the 5090 with turbo: the log's "Part n ... words" per section,
the "BENCHMARK - ..." line, the score box, Yes -> the book in the
output folder and EpubReader lists and plays it (every section timed,
its first 30 s included); benchmarks.csv; Cancel part way -> no score.

## Zip 229 (on top of zip 228): the calibration times the clearest 30 s
Owner 2026-11-22 10:49, the first calibration on the Scandal (5090,
Windows, Big Picture): base Vulkan0 140.8x, turbo Vulkan0 82.9x (Aladdin
gave 82.6x / 83.6x there), 1:15 - but the stretch was section 1 from
0:00:30 with 76 % sound. 10:55: "Before you messed it up we'd scan the
file for a section 30s in length that had decent sound"; 10:57 "yes, we
want a good calibration after all". (The scan had not gone:
WhisperFindSpeech takes the FIRST 30 s from the edge with at most 25 %
quiet frames - 0:30 had 24 %, and the whole file would have given the
same. What was wanted is the BEST.) NOT COMPILED (pasdoc_check,
project_check: 0 problems). NO PACKAGE REBUILD. Files:
demos/EpubBuilder/src/uCalibration.pas, demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/README.md, CLAUDE.md.
- uCalibration.FindReferenceStretch: the whole recording decoded once,
  section by section (one section's samples in memory at a time); every
  100 ms frame's RMS level; quiet = under a tenth of the 90th percentile
  of the WHOLE recording (WhisperFindSpeech's rule, its constants
  copied); in every section at least 30 + 2 x 30 s long, the 30 s with
  the fewest quiet frames, 30 s from both of the SECTION's ends; the
  earliest of equals. Returns that section's samples and the start in
  it; no section long enough -> the longest section and start -1 (the
  benchmark's own WhisperFindSpeech then, as before).
- Execute: Bench.MaxSeconds := CALIBRATION_STRETCH_SECONDS (30),
  Bench.StartSeconds := the start found. Log: "Recording: <file>,
  section k of n, "<title>": 30 s from h:mm:ss into it (h:mm:ss of the
  file), x % sound - the clearest 30 s of the recording" (the doubled
  length of 227's line gone); the device lines say "from h:mm:ss into the
  section" and give the benchmark's own share of sound only when it chose
  (it judges the stretch against itself, not the recording).
  CALIBRATION_SECTION_SECONDS gone. uBuilder's calibration header line:
  "the stretch is the clearest 30 s of the recording, 30 s away from both
  ends of every section".
- Deterministic: the same file gives the same stretch on every machine
  (decoding is FFmpeg's, the same build everywhere).
- The diagnostics are unchanged (their fixed 10 min from 30 s into the
  first long-enough section: a fixed place, comparable between machines).
NAMES TO LOOK AT if the compiler complains: Levels (array of
TArray<Single>, Levels[P][I]); Int64(Total) in the percentile loop;
IfThen on strings in the device line (System.StrUtils after System.Math
in the uses); Bench.MaxSeconds / StartSeconds (TWhisperBenchmark).
TO TEST (owner): Calibrate on the 5090 again - the Recording line's
section, place and share of sound (expect well over 76 %); the speeds
near 10:49's (a clearer stretch has more words per second, so a little
slower is possible); a second machine gives the same stretch.

## Zip 228 (on top of zip 227): media/ deployed from the repository
Owner 2026-11-22 10:39: "redist.sh collect ... is usually only done for
Dlls. I imagine something like it needs running on Windows though so the
Deployment gets updated - whatever set the deployment for
media/aladdin.m4a now needs to do the same for the new media". NO
PACKAGE REBUILD. Files: tools/deploy_redist.py, tools/redist.sh,
demos/EpubBuilder/EpubBuilder.dproj, demos/EpubBuilder/README.md,
notes/Building-distributions.md, CLAUDE.md. REPLACES zip 227's
media handling in redist.sh and its hand-made .dproj entries.
- What set it before: redist.sh collect copied media/aladdin.m4a into
  redistributable_bin/<platform>/media, and deploy_redist.py deployed
  that folder like the libraries. Now media/ is an OWN FOLDER of
  EpubBuilder in deploy_redist.py (MEDIA_FOLDERS, as steaminput in
  OWN_FOLDERS), deployed straight from the repository on Linux64 (.\media\)
  AND macOS (Contents\Resources\media\ - entry() writes own folders the
  Mac way now): LocalName ..\..\media\<file>, every file but dot files.
- python tools/deploy_redist.py --media-only [--platform P]: only the
  media entries, for Linux64 and OSXARM64 (or P); library and steaminput
  entries untouched; no redistributable_bin needed. Run on Windows
  whenever media/ changes. A full run writes them too, and leaves out a
  media/ that an older collect left in redistributable_bin (no double
  entries). update(): the own-folder entries replaced are only those of
  the folders given (fixed in the session: --media-only first removed
  steaminput's too).
- redist.sh: collect no longer copies media/; deploy copies the
  repository's media/ (Linux beside EpubBuilder, macOS into the builder's
  .app Contents/Resources/media).
- EpubBuilder.dproj: the two aladdin entries out, eight media entries in -
  written by --media-only itself here (placeholder files), so the IDE's
  copy matches what the script writes. Tested on a scratch copy: a full
  Linux64 run gives 1 library + 12 steaminput + the media entries, a
  stale redistributable_bin media/aladdin.m4a left out; runs repeat.
TO TEST (owner): Deploy EpubBuilder for Linux64 and OSXARM64 - media/
with the four files; after adding or renaming a file in media/, run
--media-only and reopen the project.

## Zip 227 (on top of cade964 = zip 226): Aladdin out, the reference texts in
Owner 2026-11-22 10:28: "Scandal for Calibration. both available for
Benchmark as seperate options. Remove all aladdin references now we're
using different texts. These may change so refer to them as reference
texts". The owner's media/ (10:23): ScandalBohemia_librivox.m4b,
AChristmasCarol_librivox.m4b, A_Scandal_in_Bohemia.epub (made in the
session from the owner's PG 1661 EPUB: the other eleven stories and
their contents / nav / ncx entries removed, the PG header and licence
kept; dc:title "A Scandal in Bohemia", identifier
http://www.gutenberg.org/1661#a-scandal-in-bohemia), A_Christmas_Carol.epub;
aladdin.m4a gone. NOT COMPILED (pasdoc_check, project_check: 0
problems). NO PACKAGE REBUILD. Files: demos/EpubBuilder/src/uCalibration.pas,
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/EpubBuilder.dproj
(the two aladdin DeployFile entries -> the four media files, by hand,
as deploy_redist.py writes them), demos/EpubBuilder/README.md,
tools/postbuild.bat, tools/redist.sh, tools/steam_stage.py,
tools/deploy_redist.py (docstring), notes/Building-distributions.md,
notes/Windows-on-Arm.md, CLAUDE.md. NEW, TO ADD TO GIT:
media/A_Scandal_in_Bohemia.epub, media/A_Christmas_Carol.epub (the
owner's copies; *.epub is not ignored).
- uCalibration: TReferenceText (Title, Audio, Book, Source) and
  REFERENCE_TEXTS[0..1] - the ONLY place the files are named;
  CALIBRATION_REFERENCE = 0 (Scandal). REFERENCE_FOLDER 'media',
  REFERENCE_LEVELS 5 (were CALIBRATION_AUDIO / _LEVELS). New:
  FindReferenceFile, ReferenceAudio, ReferenceIndexOf, ReferenceWords
  (the EPUB read as a build reads it - every word but ewrNav, then
  WhisperSplitBookWords; Epub.Book + Epub.Layout in the implementation
  uses, Whisper.Align moved to the interface for TWhisperStringArray),
  ReadReferenceSection (the file opened WITH its chapters = LibriVox
  sections; the first section long enough, else the longest; the log
  says which). DIAG_REFERENCE (Aladdin's 2000 words) and
  DiagReferenceWords are gone.
- CHAPTER MATERIAL, PER SECTION (standing rule): the calibration hands
  TWhisperBenchmark ONE section (at least CALIBRATION_SECTION_SECONDS 60
  + 2 x 30 s), so WhisperFindSpeech's 30 s edge is the section's; the
  diagnostics take their 10 min from 30 s into the first section of at
  least 10 min + 2 x 30 s, never its last 30 s. Before, both read the
  file whole (one recording, one intro - Aladdin's).
- FindCalibrationAudio: the reference recording FIRST, the saved
  [Calibration] Audio only without it (it was the other way round: an
  old aladdin.m4a path in the settings would have kept being used).
  Diagnostics: the reference recording only (the saved one is no longer
  read - the comment always said so); uBuilder.StartDiagnostics lost its
  Saved / Ini variables.
- Accuracy: against the whole book (Scandal: the story plus PG's
  notices) - the figures count from the first word matched to the last,
  as before; "word N of it was reached" now counts from the book's first
  word (PG's header), not from the story's.
- Tools name no file: redist.sh collect copies every file of media/
  (warns without a .m4b / .epub); postbuild.bat :media robocopies
  media\ /mir /xf .gitignore (an old media\aladdin.m4a in a build
  folder is removed by the mirror); steam_stage.py notes a staging
  without a .m4b / .epub in media/.
NOT COMPARABLE with any calibration or diagnostics before 227 (other
audio). The stored calibrations stay until each machine calibrates again
(step 2 does that anyway).
NAMES TO LOOK AT if the compiler complains: the typed const array of
records REFERENCE_TEXTS in the interface; ewrNav (Epub.Layout) and
TEpubWordArray / Book.Words (Epub.Book); TWhisperIndexArray (Whisper.Align)
for the unused Map; names Epub.Book / Epub.Layout bring into
uCalibration's implementation; TWhisperAudioPart.Title / Start /
Duration; Hms used in ReadReferenceSection (declared above it).
TO TEST (owner): Calibrate - the log's "Recording: ..., section 1 of 3,
..." and "Reference text: A Scandal in Bohemia"; Diagnostics - the
section line and "Reference text: ... N words to score against", then
accuracy lines as before (about 98 % for turbo if the EPUB matches the
reading); a build folder's media\ holds the four files and no
aladdin.m4a; redist.sh collect on Linux / Mac.

## Zip 226 (on top of zip 225): Menu on F2, Queue on F3 (layout revision 1.3)
Owner 2026-11-22 09:39: "Space + Q Still do not bring up the bound menus
in desktop mode - Let's change them to F2 + F3 for now". NOT COMPILED.
NO PACKAGE REBUILD. STEAM REBUILD NEEDED (uReaderInput and the layouts
are the reader's too). Files: tools/gen_reader_input.py,
demos/EpubReader/src/uReaderInput.pas and the eleven
demos/EpubReader/steaminput/controllers/*.vdf (GENERATED: revision 1.3;
the manifest is unchanged - the generator writes it with CRLF, the
repository's copy has LF: put back, as in zip 217),
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- MENU_KEYS: Menu = vk 113 "F2", Library (the queue) = vk 114 "F3";
  Space and Q are no longer keys of anything. LAYOUT_REVISION 3 (a
  table change; no interaction added: LAYOUT_MAJOR stays 1). "For now":
  the owner may go back.
- WHY SPACE AND Q FAILED IS NOT KNOWN (no debug log seen). Zip 225 left
  a character to an editable box that has the keyboard - the Output box
  may well have it from the start, which would explain it. 226: a key
  with no character (F2, F3) is never left to a control, the settings
  panel no longer blocks it, and the debug log says "keys: Menu on the
  desktop" when KeyDown takes one - if F2 fails too, that line (absent:
  KeyDown is not reached, or FPad / FPadMenu is nil) is what to ask for.
- The reader has its own F3 (find next) in its own keyboard code; it
  does not use the menu's key table yet (zip 217's open question), so
  nothing clashes today - it will when the reader is converted.

## Zip 225 (on top of zip 224): Space and Q open the menus on the desktop
Owner 2026-11-22 09:35: "Space + Q do not bring up the bound menus in
desktop mode". NOT COMPILED. NO PACKAGE REBUILD; builder only. Files:
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- KeyDown, menu closed, desktop: the Menu and Queue actions' keys (from
  uReaderInput's table - none named here) open PadHome / PadQueue; NOT
  Play (Enter stays the window's). Left to the control (nested
  ControlsKey): a TCustomEdit / TCustomMemo that is not ReadOnly (so Q
  and Space can be typed into Output); for Space also a focused button,
  check box or combo box; and everything while pnlSettings is open.
- So Space does nothing when a button has the focus (it presses it) -
  if the owner reports "Space sometimes does not open the menu", that is
  why; the choice then is Space always the menu's.
- Names to look at: Focused.GetObject, TCustomEdit.ReadOnly,
  TCustomMemo.ReadOnly, TCustomButton, TCustomComboBox.

## Zip 223 (on top of zip 222): the desktop's View and Tools menus gone; File > Settings is the menu's Settings page
Owner 2026-11-22 09:11: "The entire desktop view menu can be replaced by
the Steam Settings menu now - Bind to File -> Settings. Remove View and
Tools menus". NOT COMPILED (pasdoc_check, project_check: 0 problems). NO
PACKAGE REBUILD; builder only (no Steam rebuild beyond zip 222's). Files:
demos/EpubBuilder/src/uBuilder.pas, uCalibration.pas (wording),
demos/EpubBuilder/README.md, CLAUDE.md.
- BuildMenu: the bar has File (Settings..., -, Exit) only. The old View
  and Tools items are STILL MADE, under two items with Parent nil (owned
  by the form, on no bar): UpdateControls enables / ticks them and the
  Settings page asks miCalibrate.Enabled etc. Do not delete them without
  moving that logic.
- miSettingsClick: PadHome(BPC_MODEL) then FPadSettingsOnly := True
  (PadHome clears it for a first-page command) - PadBack and the Back
  row then HIDE the menu instead of going to the first page. The desktop
  can therefore have the pad menu open with no Steam (FPadMenu and FPad
  are made before StartPad's Steam check; KeyDown feeds it).
- New Settings rows (BPC_LOG 25 .. BPC_ROCM 31; all in BP_SETTINGS_ROWS,
  which is a set of 0..31 - 31 IS THE LAST FREE NUMBER, a further row
  needs another way): desktop only - Books / Audio / Output folder
  (ChooseFolder(0..2), split out of miFolderClick), Show the log
  (miLogClick), Build history; everywhere - Calibration results (log
  shown, menu hidden); AMD ROCm acceleration when miRocm.Visible.
- Wording: every "Tools > ..." / "View > ..." in log lines, comments and
  the README is now "Settings > ..." ("Re-calibrate" -> "Calibrate", the
  row's name). The window's Settings... button and its panel
  (pnlSettings) are as they were - two "Settings" on the desktop; the
  owner may want the button to open the same page.
- Names to look at: Item(nil, ...), miSettingsClick, ChooseFolder,
  FPadSettingsOnly, the BPC_* 25..31, EnsureRange (System.Math),
  miCalibrationClick(nil) / miHistoryClick(nil) / miRocmClick(nil) /
  miLogClick(nil) (none reads Sender).

## Zip 222 (on top of zip 221): Controls the same width in both forms; the desktop window dark too
Owner 2026-11-22 09:07: the two forms of Controls differ a little in
width - "They should both be the same width (the larger possibility)";
"Do any of the changes since 215 affect Reader?"; 09:08: "The desktop
form should use the same dark mode option as the Steam version". NOT
COMPILED (pasdoc_check, project_check: 0 problems). NO PACKAGE REBUILD.
STEAM REBUILD NEEDED (uPadMenu is the reader's too). Files:
demos/EpubReader/src/uPadMenu.pas (shared),
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- uPadMenu: Show's measuring is now the private Needed (and TextW a
  method, no longer nested in Show); public WidthFor(title, rows, foot)
  and MinWidth (the next Show is not narrower; the window's share and
  960 still limit). The reader's menus: unchanged in what they do.
- uBuilder.PadControls: its rows come from a nested ListFor(AKeys) (NOT
  "Rows": the constant is ROWS and Pascal does not tell them apart),
  TitleFor(AKeys), PadFootFor(AKeys); before Show MinWidth := WidthFor
  of the OTHER form, 0 again after.
- DARK ON THE DESKTOP: the same FPadDark / [View] Dark (so the desktop
  window is DARK BY DEFAULT now - the setting's default was chosen for
  Big Picture). View > Dark mode (miDarkMode, ticked) and the menu's row
  both call ToggleDark. ApplyDarkWindow no longer stops outside Big
  Picture: the form's fill; then, through the form's TLayouts only
  (Walk) - labels that had the style's colour (marked TagString "dark",
  so only those are put back), list boxes (StyleLookup
  "transparentlistboxstyle", as the reader's contents; rows' text
  light, marked), memos (the log's trick of zip 203, now for the book's
  text too). NOT darkened: TEdit, TComboBox, TButton, the settings
  TPanel and what is in it (the check boxes), the pairing bar, the menu
  bar (Linux's drawn one too), splitters. tmDark (500 ms, made in
  StartPad before the Steam check, so also without Steam) calls it
  again while dark - a style applied again, a list's new rows; the dark
  check in tmPadTimer and FDarkTick are gone.
- A GUESS, NOT SEEN: how the desktop looks. Likely rough edges: light
  boxes on a dark window; a list's new rows dark-on-dark for up to half
  a second; rows the program coloured itself; the selected row's colour
  in the transparent list. The owner's screenshots decide what follows.
- THE READER SINCE 215 (asked): 215 - its menus take the mouse wheel;
  217 - the shared Steam Input definitions, revision 1.2 (rebuild or
  the two programs overwrite each other's layouts), OnGesture in
  uPadMenu; 216, 218 - 221 - builder only; 222 - uPadMenu again, nothing
  to see in the reader. Its own keyboard code is as it was (the open
  question of zip 217).
- Names to look at: Needed / WidthFor / MinWidth / the method TextW in
  uPadMenu; ListFor, TitleFor, PadFootFor, tmDark, tmDarkTimer,
  ToggleDark, miDarkMode in uBuilder; in ApplyDarkWindow the nested
  DarkMemo, DarkLabel, DarkList, Walk, TListBoxItem.StyledSettings,
  TagString, IfThen with strings.

## Zip 221 (on top of zip 220): Controls says "Menu" and "Queue"
Owner 2026-11-22 08:11: "Open or close the menu -> Menu; The queue ->
Queue". NOT COMPILED (pasdoc_check, project_check: 0 problems). NO
PACKAGE REBUILD. Files: demos/EpubBuilder/src/uBuilder.pas, CLAUDE.md.
- PadControls' last two rows read "Menu" and "Queue". The list now:
  Choose, Back, Up, Down, Decrease value, Increase value, Menu, Queue.
  The owner wants SHORT action names here - one or two words.

## Zip 220 (on top of zip 219): Controls says "Decrease value" and "Increase value"
Owner 2026-11-22 08:09: "Left = Decrease Value, Right = Increase Value".
NOT COMPILED (pasdoc_check, project_check: 0 problems). NO PACKAGE
REBUILD. Files: demos/EpubBuilder/src/uBuilder.pas, CLAUDE.md.
- PadControls' rows for Left and Right read "Decrease value" and
  "Increase value" (zip 219: "Left: a value back", "Right: a value on").

## Zip 219 (on top of zip 218): Controls - a row for each of Up, Down, Left, Right
Owner 2026-11-22 08:09: "Make options Up. Down, Left _ Right seperate
lines on controls display". NOT COMPILED (pasdoc_check, project_check: 0
problems). NO PACKAGE REBUILD. Files:
demos/EpubBuilder/src/uBuilder.pas, CLAUDE.md.
- uBuilder.PadControls: eight rows, one action each (Choose, Back, Up,
  Down, "Left: a value back", "Right: a value on", Open or close the
  menu, The queue) + Back; TControlRow has one Button (the A / B pair
  and the "/" joining are gone); one TSteamPadOrigin per row.
- Names to look at: the local Origin (a TSteamPadOrigin), the field
  Button of TControlRow.

## Zip 218 (on top of zip 217): the menu's Settings page; Controls in one layout, changing over at once
Owner 2026-11-22 08:06, two screenshots of Controls on the 5090 (zip 217
compiled and ran, build 04e9903: keys from the table, Xbox glyphs): a
submenu "Settings..." directly above Exit with Model, the two
Calibrates, the two Diagnostics, Device, Language, Power, Chapters, Dark
mode, Expert mode and Output; Controls "same layout on both versions:
Key/Button on left, Action on Right"; using the other way of control
while a menu shows changes the display over. NOT COMPILED (pasdoc_check,
project_check: 0 problems). NO PACKAGE REBUILD. Files:
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- The home list has two PAGES, both FPadMode = BPM_HOME (so PadStep,
  PadChoose and the foot's progress work on either): FPadSettings says
  which. BP_SETTINGS_ROWS names the Settings page's rows; PadHome(row)
  shows the page that row is on, its nested Add leaves out the other
  page's rows. First page: Book, Audio, Add to queue, Queue, Cover,
  Create, Update job, Cancel, Controls, Settings... (BPC_SETTINGS = 23),
  Exit. Settings: the twelve + Back (BPC_SETTINGS_BACK = 24). B on the
  Settings page: the first page on its Settings row. Everything that
  came back "on Model" (a download, a calibration, the diagnostics)
  comes back on the Settings page's Model row by itself.
- FPadToOutput: the Output note's OK brings Settings back on Output.
- PadControls: both forms put the button or key in the row's text
  (left) and what it does in its value (right); a pad's glyphs with an
  empty text. Its selected row is kept when it is shown again.
- SetPadKeys(AKeys): FPadKeys changed -> Controls shown again in the
  other form, the home / queue foot named again. Called from the pad's
  poll (False), KeyDown (True), and - QUEUED (ForceQueue), because they
  come from a row's own event and showing a list frees the rows - from
  PadPointer and PadMenuGesture.
- TO CHECK: Enter into Controls (keys), a d-pad press (pad form, the
  row moves on), a key again; the wheel and a click on Controls from the
  pad form; Left / Right on a Settings row; B from Settings; a download
  ending on Settings > Model.
- Names to look at: the set constant BP_SETTINGS_ROWS and "in" with an
  Integer, the anonymous procedure with its own var in PadMenuGesture,
  TThread.ForceQueue, the begin .. end under BPC_OUTPUT in PadChoose.

## Zip 217 (on top of zip 216): keys defined with the Steam Input actions; revision 1.2
Owner 2026-11-22 07:15: the standing rule STEAM BUILDS: EVERY BUTTON AND
KEY MAPPING IS DEFINED VIA STEAM INPUT ("so we need a regen now
anyway"); "Remove any code that overrides using steam input from Steam
builds while keeping the functionality already described". Steam Input
cannot hold a key (checked - the rule's text); asked where the keys go:
the owner chose the generator's tables. NOT COMPILED (pasdoc_check,
project_check: 0 problems). NO PACKAGE REBUILD. Files:
tools/gen_reader_input.py, demos/EpubReader/src/uReaderInput.pas
(GENERATED), the eleven demos/EpubReader/steaminput/controllers/*.vdf
(GENERATED, CR LF as the generator writes them),
demos/EpubReader/src/uPadMenu.pas, demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/README.md, CLAUDE.md.
- THE GENERATOR WAS RUN HERE with TSteamAPI at 80804ab (a clone of
  G3DGames/tsteamapi, read only): the layouts differ from revision 1 in
  their title, description, minor_revision 1 -> 2 and major_revision
  0 -> 1 only (diffed); the manifest is byte for byte as before and not
  in the zip. TSteamAPI's writer has "major_revision" "0": the reader's
  generator replaces it with LAYOUT_MAJOR (TSteamAPI not touched).
- gen_reader_input.py: LAYOUT_REVISION 2, LAYOUT_MAJOR 1, MENU_KEYS
  (Up: Up, W; Down: Down, S; Left: Left, A; Right: Right, D; Play:
  Enter; Back: Esc; Menu: Space; Library: Q), MENU_POINTER (Play: left
  click, tap; Back: right click; Up / Down: wheel up / down); asserts
  that each names an action of SETS and none is there twice.
- uReaderInput (generated): TReaderInputKey, TReaderInputPointer,
  READER_INPUT_MAJOR, READER_MENU_KEYS, READER_MENU_POINTER,
  ReaderMenuKeyAction, ReaderMenuPointerAction, ReaderMenuKeyNames,
  ReaderMenuFirstKey.
- uPadMenu: OnBack (zip 215) is now OnGesture(AGesture) with
  PADMENU_RIGHT_CLICK / PADMENU_WHEEL_UP / PADMENU_WHEEL_DOWN - the menu
  reports, the program's table decides. No OnGesture (the reader): the
  wheel moves the selection, the right button does nothing.
- uBuilder: KeyDown asks ReaderMenuKeyAction and presses the action's
  button (PadButtonOf: the action's place in BP_ACTIONS) - zip 215's
  vk... and letters are gone; PadMenuGesture the same for the mouse;
  PadFoot's key hints and PadControls' keys column come from the table;
  the debug log says "layout revision 1.2". The menu closed: in Big
  Picture only the actions Menu, Play and Library are taken (they open
  it, as on a pad), on the desktop none.
- A row's left click / tap is the row's own (it chooses the row under
  the pointer); it is in MENU_POINTER so that Controls lists it.
- THE READER IS NOT CONVERTED (its FormKeyDown, uMain 3075 on). Not
  mechanical: the table's menu keys would clash with its page keys (D =
  Dark mode against D = Right; L = Learn to read; P; R; [ ] the speed,
  which has no action) and Esc opens its menu where the pad's Back does
  not. Needs the owner: which page keys become actions (new actions =
  LAYOUT_MAJOR 2), which stay menu-bar shortcuts (Ctrl+F, Ctrl+O, Ctrl
  + / -, F3). The partner site's bundled configuration, if the layouts
  were published there, wants the new .vdf files.
- Names to look at: TReaderInputKey's typed constant (KeyChar: #0 and
  'W' as WideChar), UpCase on a WideChar in uReaderInput,
  TPadMenuGestureEvent, the const block between two type blocks at the
  top of uPadMenu, PadButtonOf, Format with BP_FOOT_KEYS.

## Zip 216 (on top of zip 215): the model list's order; "turbo" and "large"
Owner 2026-11-22 07:10: "model order. Top = Installed, then downloadable
but not installed by model size. Split so Multi-Lingual are nearer top
and .en are at the very end. base + turbo should be first on list in
all situations. The labels for large-v3 -> large and large-v3-turbo ->
turbo". NOT COMPILED (pasdoc_check, project_check: 0 problems). NO
PACKAGE REBUILD. Files: demos/EpubBuilder/src/uModels.pas,
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- uModels: ModelLabel ('turbo', 'large', else the name - the LISTS and
  the questions only; files, downloads, queue files, settings and logs
  keep whisper.cpp's names). ModelListOrder(folder): base, turbo; every
  language installed, by size; every language to download, by size;
  .en installed, by size; .en to download, by size.
- HOW I READ IT: ".en at the very end" taken literally - an installed
  .en model comes after a multilingual one still to download. The other
  reading (installed first whatever the language) is two numbers in
  Rank (groups 2 / 3 / 4 / 5 -> 2 / 4 / 3 / 5); said to the owner.
- uBuilder.FillModels walks ModelListOrder and shows ModelLabel; the
  download and Core ML questions say the label; the pad's model foot,
  the expert-mode log lines and the two first-run hints say "turbo".
  Download every model still fetches smallest first.
- Names to look at: the nested function Rank in ModelListOrder,
  string.EndsWith('.en', True), the locals K, Shown, Order in
  FillModels.

## Zip 215 (on top of zip 214): the builder's menu by keyboard, mouse and finger; Controls
Owner 2026-11-22 07:05, two screenshots of the home list on the 5090
(zips 213 / 214 compiled and ran: the wide menu, build 853c7d1). Asked:
"all that are downloaded" -> "All installed"; "Expert mode (every
model)" -> "Expert mode"; Output "does nothing (just prints Output: on
screen"; the menu "Keyboard aware" (arrows / WASD, Enter = A, Esc = B,
Space = Start); the wheel = Up / Down, right click = B; touch; "raise
the major revision" of the Steam Input definitions if they change; a
"Controls" row showing the bindings in use (stick glyphs for a pad,
keys for keyboard / mouse). NOT COMPILED (pasdoc_check, project_check:
0 problems). NO PACKAGE REBUILD. Files: demos/EpubReader/src/uPadMenu.pas
(shared), demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/README.md, CLAUDE.md.
- uPadMenu: OnBack (right button anywhere on the shade, box or a row,
  queued), OnPointer (a click / tap, the right button or the wheel was
  used), AnyMouseDown, AnyMouseWheel (the selection moves a row, at
  most one per 60 ms; Handled, so the scroll box does not scroll by
  itself). The READER gets the wheel too (its OnBack is not set).
- uBuilder: KeyDown overridden (public): while the menu or the cover
  chooser shows - arrows / W A S D, Enter, Esc, Space (Start), Q (View;
  my addition); menu closed in Big Picture - Space / Enter open it, Q
  the queue; closed on the desktop - nothing taken. FPadKeys (last input
  was keys / mouse / finger; a pad press clears it), PadFoot (BP_FOOT or
  BP_FOOT_KEYS), PadMenuBack, PadPointer, PadControls (BPM_CONTROLS = 8,
  home row BPC_CONTROLS = 22 after Expert mode): six rows + Back; a pad:
  FPad.Origin's glyphs, else its names, else "A", "D-pad up / down" ...;
  keys: the keys and the mouse. The Output row: Tell says the output
  file, or with no book the output folder (its value shows the folder's
  name then). The two wordings changed.
- STEAM INPUT NOT CHANGED, revision still 1: the keyboard and the mouse
  are read by the program itself and Controls is a menu row, so no
  action was added; a new revision would only make Steam load the
  layouts afresh. If an action is ever added: tools/gen_reader_input.py
  (never the .vdf or uReaderInput by hand) and the revision raised, as
  the owner said.
- TOUCH: nothing new beyond the above - a tap is a click (rows, beside
  the menu), a drag is left to the scroll box's own handling. NOT TRIED
  on a touch screen: Deck, Ally, Miix to say.
- After the Output note's OK the home list comes back on Create (as
  after any note), not on Output.
- Names to look at: the KeyDown override's signature (TCommonCustomForm:
  var Key: Word; var KeyChar: WideChar; Shift: TShiftState), vkSpace,
  ssCommand, UpCase on a WideChar, the local type TControlRow and its
  typed constant ROWS in PadControls, TMouseButton.mbRight,
  OnMouseWheel on TVertScrollBox, TThread.ForceQueue.

## Zip 214 (on top of zip 213): the pad's model list says "installed"
Owner 2026-11-22 06:44: "Change the wording on this menu from "here" to
"installed"". NOT COMPILED (pasdoc_check, project_check: 0 problems).
NO PACKAGE REBUILD. Files: demos/EpubBuilder/src/uBuilder.pas, CLAUDE.md.
- uBuilder.PadModels: a downloaded model's value "installed" (was
  "here"); the first row "Download every model - all not installed"
  (was "all that are not here"); its question "... model(s) that are
  not installed yet?". The window's list and the other texts
  ("... to download", "in the models folder") are as they were.

## Zip 213 (on top of zip 212): the pad menu as wide as its text needs, at most 960
Owner 2026-11-22 06:43, a screenshot of the builder's model list in Big
Picture on the 5090 (zips up to 212 compiled and ran; expert mode's
short list shown): "Menu needs to be wider but max = 960, this will
avoid ellipses. Size should really be dynamic so larger font = wider
menu (limit 960)". NOT COMPILED (pasdoc_check, project_check: 0
problems). NO PACKAGE REBUILD. Files: demos/EpubReader/src/uPadMenu.pas
(shared: reader and builder), demos/EpubBuilder/src/uModels.pas,
CLAUDE.md.
- TPadMenu.Show: a nested TextW (TTextLayout, the title's font family)
  measures every row's text and value, the title and the foot at the
  menu's font size. The value column is as wide as its widest value
  (not under FFontSize x 8, as before); the box is as wide as the
  widest row + padding, not under FFontSize x 24 (as before), not over
  BOX_SHARE of the window and BOX_MAX_WIDTH = 960 (FMX units, not
  pixels: 1440 px on a 150 % display). ShowText's box, which took all
  the window allowed, is held to 960 too.
- A value set later with SetValue keeps the column's width of Show (the
  builder shows its list again after every change; the reader: to
  watch).
- uModels: tiny.en's note ended "(decodes again often)" and PadModels
  took the bracket for the row's value ("decodes again..." where "here"
  belonged): now "... slow in a build: decodes again often". A note
  must not end in a bracket.
- TO CHECK: no "..." in the model list and its foot at the 5090's font
  size; the reader's menus (shared unit) look right; a long question
  (ShowText) still reads well at 960.
- Names to look at: the nested function TextW in Show (before its
  begin), TTextLayout.TextWidth, Lay.Font.Family, BOX_MAX_WIDTH.

## Zip 212 (on top of zip 211): the nine compiler hints of a Windows build gone
Owner 2026-11-22 06:12, a dcc64 build (so zips 207 - 211 COMPILE on
Windows; hints only): "why are all these around?" - nine hints, none
from this weekend's zips: code that works only on Linux / POSIX leaves
its variables unused in a Windows build. NOT COMPILED (pasdoc_check,
project_check: 0 problems). NO PACKAGE REBUILD. Files:
demos/common/uQuitSignal.pas, demos/EpubBuilder/src/uModels.pas,
demos/EpubBuilder/src/uCovers.pas, demos/EpubBuilder/src/uBuilder.pas,
CLAUDE.md.
- uQuitSignal (H2164 GProc, GDone): both now inside the unit's
  {$IFDEF POSIX} var block (only POSIX code uses them).
- uModels (H2443 RenameFile wants Winapi.Windows): TFile.Move in its
  place, the error as before with the reason added. NOT Winapi.Windows
  in the uses list: its DeleteFile(PChar) would hide
  System.SysUtils.DeleteFile.
- uCovers.AudioCover (H2077): the first "Result := False" is gone (the
  try and the except both set it).
- uBuilder.CheckRocmDlc (H2164 x 5): its var block is under the same
  {$IF Defined(LINUX) and not Defined(ANDROID)} as its body.
- TO CHECK: the Windows build has no hint left; Linux and macOS build
  as before (uQuitSignal and uCovers are in EpubReader too). If
  AudioCover now gives W1035 (return value might be undefined), put the
  line back and tell me.
- A habit from now: when the owner's compile shows hints, clear them in
  the same zip.

## Zip 211 (on top of zip 210): base and large-v3-turbo; expert mode for the rest
Owner 2026-11-21 22:29 "OK, base + turbo it is"; asked what becomes of
the other eight: only the two in the list, "with "Unlock expert mode"
which allows free choice of all models". NOT COMPILED (pasdoc_check,
project_check: 0 problems). NO PACKAGE REBUILD. Files:
demos/EpubBuilder/src/uModels.pas, demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/README.md, CLAUDE.md.
- uModels: MODEL_STANDARD ('base', 'large-v3-turbo'), ModelIsStandard;
  the catalogue's notes say what was measured (.en: slower in a build;
  large-v3 no longer "most accurate").
- uBuilder: FExpert ([Models] Expert, False at first). FillModels
  without it: the two, plus the model in use (a job or an earlier
  choice keeps working); no other files of the folder, no "Other model
  file ...". Tools > Unlock expert mode (every model) (miExpert,
  checked while on; UpdateControls keeps the tick); Big Picture home
  row "Expert mode (every model)" (BPC_EXPERT = 21, after Dark mode).
  ToggleExpert: saved, list filled again, a log line.
  DownloadEveryModel fetches the list's models (two / ten);
  KeepStandardModels takes the others out of Calibrate / Diagnostics
  "every model" without expert mode. The pad's model list foot names
  both models.
- README (builder): Models rewritten (the two, the evidence, expert
  mode).
- NOT DONE: nothing chooses base by itself for a slow machine (the
  model at first is as before); the benchmark build (turbo, base as its
  light tier) is not begun. The survey tables of all seven machines are
  under "Survey of machines" below.
- Names to look at: TMenuItem.IsChecked, IfThen in PadHome, the
  standalone KeepStandardModels (after ModelFilesOf, before
  StartDiagnostics), SameFileName.

## Zip 210 (on top of zip 209): macOS - Big Picture full screen asked for again
Owner 2026-11-21 21:17, Mac mini: pad and dark mode work; "Big Picture
fails - when app starts it starts in normal mode not full screen ... I
got the correct view just in a Window". Debug log: "Steam: Big Picture:
the main form exists now - TfrmBuilder full screen on a 3440 x 1440
display" - TSteamAPI (bpwFullScreen) set it while the form was being
made and macOS did not take it. NOT COMPILED (pasdoc_check,
project_check: 0 problems). NO PACKAGE REBUILD. Files:
demos/EpubBuilder/src/uBuilder.pas, CLAUDE.md.
- uBuilder.tmPadTimer: PAD_FULL_AGAIN (macOS only), FFullTick,
  FFullTries: in Big Picture, while FullScreen reads False, FullScreen
  := True again, a second apart, at most PAD_FULL_TRIES (3) times; a
  debug line each time ("Big Picture: the window is not full screen -
  asked for again (n of 3)").
- A GUESS, NOT TRIED: that FMX's FullScreen reads the window's real
  state on macOS and that asking after the window is shown takes. If
  not: the debug lines say how often it was asked.
- THE RIGHT PLACE is TSteamAPI's bpwFullScreen on macOS (ask once the
  form is visible) - not in this repository's reach from here; then
  this can go. EpubReader on the Mac in Big Picture: not reported, not
  changed - the owner to say whether it shows the same.
- CLAUDE.md: the Mac's row in the survey of machines.

## Zip 209 (on top of zip 208): no full-screen toggle outside gamescope
Owner 2026-11-21 20:42, Ideapad (Ubuntu desktop, Steam Big Picture,
SteamGamepadUI=1): at the end of a full calibration / diagnostics "the
screen tries to resize and looses focus". Debug log: "redraw: a pad
press after 830 s without one ... full screen True" then 60 ms later
"the window is not active" for 38 s; the same after 2134 s (80 ms, 14
s). uRedraw.Kick left full screen and went back at the first pad press
after the run - meant for gamescope's black screen. NOT COMPILED
(pasdoc_check, project_check: 0 problems). NO PACKAGE REBUILD. Files:
demos/common/uRedraw.pas, demos/EpubBuilder/README.md,
demos/EpubReader/README.md, CLAUDE.md.
- uRedraw: FGamescope (XDG_CURRENT_DESKTOP has gamescope, or
  GAMESCOPE_WAYLAND_DISPLAY set - NOT SteamGamepadUI=1, which
  uInhibit.GameModeSession also takes). Kick outside gamescope: the log
  line and Invalidate only. The log line ends "gamescope: size changed
  and put back" / "not gamescope: drawn again only". Reader and builder
  both (shared unit).
- NOT TOUCHED: uInhibit still treats SteamGamepadUI=1 as Game Mode (the
  Ideapad's log: "sleep allowed, the work pauses for it") - a separate
  question for a desktop; owner to say.
- TO TEST: Ideapad, Big Picture, a pad press after a minute: no resize,
  focus kept. Deck / Ally / Steam Machine (gamescope): as before.
- This zip's CLAUDE.md also has the survey of machines below.

## Survey of machines, 2026-11-21 (diagnostics before zip 208; with zip 209)
Every model, ten minutes of Aladdin from 0 (old kind). As a build /
failed checks / heard with the fallback:
- Ally Z1 Extreme (RADV): tiny 79.4x / 0 / 95.6; tiny.en 11.0x / 57 /
  96.8; base 42.1x / 1 / 97.9; base.en 28.0x / 9 / 94.7; small 27.5x /
  0 / 97.4; small.en 8.3x / 23 / 89.1; medium 10.9x / 0 / 88.8;
  medium.en 6.3x / 17 / 97.9; turbo 16.7x / 0 / 98.8; large-v3 6.6x / 0
  / 93.8. Calibrate all 7:30, diagnostics 25:24.
- Steam Deck (RADV VANGOGH): tiny 39.3x / 0 / 96.1; tiny.en 10.5x / 30 /
  97.6; base 23.4x / 2 / 98.0; base.en 14.4x / 10 / 96.7; small 11.7x /
  2 / 98.2; small.en 9.1x / 6 / 90.5; medium 5.3x / 2 / 84.7; medium.en
  4.3x / 12 / 98.2; turbo 7.9x / 0 / 98.8; large-v3 3.8x / 0 / 93.8.
  Calibrate all 18:56, diagnostics 43:03.
- Ideapad (GTX 1650, NVIDIA Vulkan; large-v3 did not fit its 4 GB and
  ran on the Iris Xe): tiny 61.4x / 2 / 96.6; tiny.en 20.6x / 30 / 96.7;
  base 58.4x / 0 / 98.0; base.en 36.2x / 8 / 95.7; small 27.2x / 0 /
  98.3; small.en 12.4x / 12 / 85.9; medium 12.3x / 0 / 87.5; medium.en
  7.0x / 18 / 98.3 (81.4 without the fallback); turbo 15.4x / 0 / 98.8
  (= the Naked Sun book's 15.4x; calibration 9.9x, ratio 1.56);
  large-v3 2.3x / 0 / 93.8. Calibrate all 13:44, diagnostics 34:01.
  tiny RETRIED here (2, 20 % of its time): over four machines only turbo
  and large-v3 have never retried. The calibration ranks the .en models
  ABOVE their twins (tiny.en 90.1x against tiny 72.1x) - its 30 s
  stretch has no retry - the opposite of a build.
- OPEN, owner 20:42, Ideapad (Ubuntu, Big Picture): when a full
  calibration or diagnostics ends "the screen tries to resize and looses
  focus". Suspect uRedraw.Kick (leaves full screen and goes back: at the
  first pad press after a minute, or the window active again) - right
  for gamescope, wrong for Big Picture on a desktop. CONFIRMED by the
  debug log and fixed in zip 209.
- Mac mini M4 (Metal; tiny and tiny.en on the CPU, which calibrated
  faster): tiny 110.8x / 2 / 97.0; tiny.en 27.9x / 48 / 97.6; base 80.9x
  / 2 / 98.0; base.en 55.5x / 11 / 90.8; small 33.6x / 2 / 98.2;
  small.en 19.8x / 14 / 80.7 (93.6 WITHOUT the fallback - the one case
  where the fallback made it worse); medium 16.8x / 0 / 89.6; medium.en
  11.3x / 12 / 98.3 (77.5 without); turbo 26.9x / 0 / 98.8 (1546 words;
  calibration 21.2x, ratio 1.27 - the Mac's encoder is a smaller share);
  large-v3 8.5x / 0 / 93.8. Calibrate all 2:21, diagnostics 16:07.
  Five machines: only turbo and large-v3 have never retried; base 97.9 -
  98.0 and small 97.4 - 98.3 heard on every one.
  WRONG TEXT in the calibration log: a model fastest on the CPU gets "no
  graphics card here could run it ... a book will take many hours" - on
  the Mac tiny ran 118.6x on the CPU against 116.3x on Metal. To fix.
- Miix 520 (Windows, Intel UHD 620 Vulkan, 7 models; with the next zip
  after 210): tiny 15.0x / 0 / 95.8; tiny.en 2.5x / 38 / 98.1 (13.3x
  without the fallback); base 6.3x / 1 / 98.0; base.en 3.2x / 15 / 96.7;
  small 2.6x / 0 / 96.9; small.en 2.0x / 10 / 92.2; turbo 0.8x / 0 /
  98.8 (1546 words). Diagnostics 1:51:17. This explains the morning's
  Foundation and Empire build on tiny.en: 3.0x against a calibration of
  11.9x (3:12:20) - the retries, not the machine; tiny would have run
  about 15x. FIVE FULL RUNS so far (Ally, Deck, Ideapad, Mac, Miix; the
  5090 only turbo and tiny.en, before the accuracy lines): every .en
  model retries; turbo never has (98.8 % on the five); large-v3 never
  on the four that ran it; tiny, base, small, medium 0 - 2 times.
- Steam Machine (RADV NAVI33, 8 GB; with the next zip after 210): tiny
  117.4x / 0 / 95.6; tiny.en 15.8x / 57 / 96.8; base 66.3x / 1 / 97.9;
  base.en 32.3x / 12 / 88.6 (91.3 without the fallback); small 41.5x /
  0 / 97.4; small.en 13.5x / 15 / 91.1; medium 18.1x / 0 / 87.5;
  medium.en 7.5x / 22 / 98.4 (72.6 without); turbo 37.8x / 0 / 98.8
  (1547 words; calibration 27.4x, ratio 1.38); large-v3 12.8x / 0 /
  93.8. Calibrate all 8:01, diagnostics 15:59. The multilingual models
  give the SAME retries and heard figures as the Ally (tiny 0 / 95.6,
  base 1 / 97.9, small 0 / 97.4; tiny.en 57 / 96.8 too) - the same GPU
  generation gives the same transcript; the Deck's differs. SIX FULL
  RUNS (Ally, Deck, Ideapad, Mac, Miix, Steam Machine - owner 22:18
  corrected a count of seven; the 5090's full run was started then):
  every .en model retries; turbo never (98.8 % on all six; on the 5090
  0 retries, 1547 words, no accuracy line yet); large-v3 never on the
  five that ran it. The gamescope redraw fired
  once here ("a pad press after 486 s") with no loss of focus.
- RTX 5090 laptop (Windows, NVIDIA Vulkan; full run 22:14, owner "No
  issues"): tiny 186.5x / 0 / 97.6; tiny.en 25.9x / 33 / 97.9; base
  115.1x / 2 / 98.0; base.en 77.5x / 8 / 94.7; small 66.9x / 2 / 98.2;
  small.en 36.7x / 14 / 92.1; medium 51.2x / 0 / 85.1; medium.en 23.6x
  / 15 / 96.5 (77.5 without the fallback); turbo 101.8x / 0 / 98.8
  (1547 words; calibration 82.6x, ratio 1.23); large-v3 25.3x / 0 /
  93.8. Calibrate all 6:44, diagnostics 7:00. Three runs had ONE window
  of 5 - 8 s with no retry behind it (tiny.en run 1: 8.44 s, so 25.9x
  where the afternoon's three runs gave 37.5x; base.en run 2: 5.20 s;
  large-v3 run 1: 5.55 s) - a stall of the machine, not Whisper; to
  watch (the owner's old turbo stalls).
  SEVEN FULL RUNS NOW: every .en model retries on every machine; turbo
  0 retries and 98.8 % on all seven; large-v3 0 retries on the six that
  ran it; base 97.9 - 98.0 % on all seven; small 96.9 - 98.3; tiny 95.6
  - 97.6. As a build, turbo / small / base / tiny: 5090 101.8 / 66.9 /
  115.1 / 186.5; Steam Machine 37.8 / 41.5 / 66.3 / 117.4; Mac 26.9 /
  33.6 / 80.9 / 110.8; Ally 16.7 / 27.5 / 42.1 / 79.4; Ideapad 15.4 /
  27.2 / 58.4 / 61.4; Deck 7.9 / 11.7 / 23.4 / 39.3; Miix 0.8 / 2.6 /
  6.3 / 15.0. The survey is complete; the decisions are the owner's.
- DECIDED, owner 2026-11-21 22:29, after the seven runs and the error
  table (first pass, not heard exactly or nearly: turbo 1.2 %, base 2.0,
  medium.en 2.1, small 2.2, tiny.en 2.6, tiny 3.7, base.en 6.0, large-v3
  6.2, small.en 11.2, medium 12.8): "base + turbo it is". Turbo = the
  accurate model, base (multilingual) = the fast one. What happens to
  the other eight in the model list: asked - "(1) with "Unlock expert
  mode" which allows free choice of all models" - zip 211.
- Both: .en models retry far more than their multilingual twins; turbo,
  tiny and large-v3 never retry; turbo gives the same 1547 words on Deck,
  Ally and 5090 (98.8 % on the first two; the 5090's run had no
  accuracy line). Retry COUNTS differ by machine for the
  same audio (tiny.en 57 / 30 / 33 on Ally / Deck / 5090; small.en 23 /
  6, so the Deck beats the Ally on small.en): a model that retries is
  no good for a benchmark. Build speed over calibration, Deck: tiny
  1.19, turbo 1.55, large-v3 1.36 (Ally 1.19, 1.48, 1.27).
- Owner 18:12: no decision until more machines are in. Next: Ideapad
  (GTX 1650), Miix running.
- Owner 19:34, Ideapad (Linux, Big Picture): dark mode and the pad
  work. RustDesk (remote desktop) does not refresh the window properly
  there - RustDesk's fault, not the program's; not to be chased.

## Zip 208 (on top of zip 207): the diagnostics on chapter material only
Owner 2026-11-21 19:19 "Do the fix, I won't do another deploy until after
all tests are done anyway" (the standing rule ONLY CHAPTER MATERIAL IS
TRUSTED FOR TIMING, which zips 198 - 206 broke). NOT COMPILED
(pasdoc_check, project_check: 0 problems). NO PACKAGE REBUILD. Files:
demos/EpubBuilder/src/uCalibration.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- uCalibration: DIAGNOSTIC_EDGE_SECONDS = 30. ExecuteDiagnostics takes
  DIAGNOSTIC_SECONDS from 30 s in, never the last 30 s (Copy(Samples,
  Edge, Min(length - 2 x Edge, 600 s))); a recording under 2 min (two
  edges + two windows) is read whole and the log says the figures are
  less sure. A FIXED start, not WhisperFindSpeech: the same stretch on
  every machine, and the reference text (the first 2000 words) still
  covers it (about 1630 words in). Log: "Recording: ..., 0:10:00 of it
  from 0:00:30 (its first and last 30 s are left out ...)"; the accuracy
  line now reads "word N of it was reached".
- The accuracy needed no change (counted between the first and last word
  matched); the speeds lose the intro's window (was about 1 % kind).
- NOT COMPARABLE with the logs before 208: other audio (30 s later).
  The owner re-runs every machine for the real benchmark anyway.
- Names to look at: Copy on TWhisperSamples, Min (System.Math),
  WHISPER_CHUNK_SIZE (Whisper.Types), the new local Edge.

## Zip 207 (on top of zip 206): the builder's window drawn again after the display slept
Owner 2026-11-21 19:15, Miix 520 (Windows), a long run: "the screen keeps
sleeping. When it awakes again there is an almost black screen (as
nothing is being output). After a while text will re-appear. This is not
desirable". NOT COMPILED (pasdoc_check, project_check: 0 problems). NO
PACKAGE REBUILD. Files: demos/common/uRedraw.pas,
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md, CLAUDE.md.
- uRedraw did nothing outside Linux. TWindowRedraw.Create(AForm,
  AEverywhere = False): with True the 2 s timer runs on every system and
  Tick only calls FForm.Invalidate there (Kick, the displays: Linux as
  before). EpubBuilder passes True; EpubReader unchanged (default False).
- A GUESS, NOT TRIED: that Invalidate is enough on Windows for the log
  to be drawn after the display wakes. If the window is still empty: the
  debug log, and whether the pad menu or the log was showing.
- NOT CHANGED, OWNER TO DECIDE: the builder holds ikSleep only while
  busy (zip 114), so the display may sleep. Holding ikDisplay too on
  Windows / macOS would keep the screen on through a run; Linux Game
  Mode is a separate, open question (zip 168 notes: blocking Steam's
  timers).
- Also in this zip, CLAUDE.md only: the standing rule ONLY CHAPTER
  MATERIAL IS TRUSTED FOR TIMING (owner 18:59 - the diagnostics break
  it, to be fixed after the survey of machines; the benchmark must
  follow it). Owner 18:12: no decision on the models, the fast model or
  the Lite tier until more machines are in (Deck next, Miix running).
  Confirmed today: dark mode on Linux (Ally) and Windows (Miix), the pad
  on the Miix, zips 205 / 206 ran (Ally ten-model table, in the session).

## Zip 206 (on top of zip 205): diagnostics on every model, Download every model
Owner 2026-11-21 17:17 "Diagnose all would make this easy too", 17:19 "a
download all models at the top of models would be handy". NOT COMPILED
(pasdoc_check, project_check: 0 problems). NO PACKAGE REBUILD. Files:
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/src/uCalibration.pas,
demos/EpubBuilder/README.md, CLAUDE.md.
- uCalibration.ExecuteDiagnostics: every model given to Create, model M
  on FDevices[M]. The four runs moved into the nested procedure OneModel
  (its own I, J, K: a for-loop variable must be local to the routine; the
  model's index is a parameter for the same reason), which frees its
  model and returns the model's line; a model that raises (does not fit
  the device) is logged, listed as FAILED and the next one run; with
  more than one model a closing table "Every model, over the same ...".
  Progress over all runs (FDiagRuns = 4 x models). TCalibrationThread.
  IniFile: the thread says what the calibration timed each model at
  (the builder no longer does).
- uBuilder: StartDiagnostics(AAllModels) - ModelFilesOf, each model's
  device = CalibrationBest's when it is calibrated, else the window's;
  its body now lies after ModelFilesOf. miDiagnosticsAll (Tools > Run
  diagnostics on every &model...), BPC_DIAGNOSE_ALL = 20 under Model.
- uBuilder: DownloadEveryModel (Tools > Do&wnload every model...,
  PADROW_DOWNLOAD_ALL = the first row of PadModels): the catalogue's
  models not in FModelsFolder, one question with the total size (with
  the Core ML encoders where FCoreML), FDownloadQueue / FDownloadAll,
  StartNextDownload; DownloadDone in that mode keeps FModelPath, offers
  no calibration, goes on, and ends (done, failed or Cancel) with a line
  and PadBackToMenu(True). No check of free disk space before it.
NAMES TO LOOK AT if the compiler complains: the nested OneModel using the
outer routine's variables and constants (RUN_NAMES, Took, Score, Model);
Delete(FDownloadQueue, 0, 1) on a TArray<string>; Names + [..] and the
anonymous method capturing Names in DownloadEveryModel; MODEL_CATALOGUE's
SizeMB / EncoderMB; CalibrationBest's out parameters in StartDiagnostics.
TO TEST (owner): Download every model (question, a line per model, the
window's model unchanged, Cancel stops it); Calibrate every model;
Diagnostics (every model) - the closing table; a model too large for a
card is listed FAILED and the rest still run.

## Zip 205 (on top of zip 204): accuracy in the diagnostics, Calibrate every model, back on Model
Owner 2026-11-21 16:58 "ok" (to the accuracy figure and the calibration
change), "Add a calibrate all to big picture as well", 17:00 "After
calibrate the menu should be back on model so you can get the next one".
NOT COMPILED (pasdoc_check, project_check: 0 problems). NO PACKAGE
REBUILD. Files: demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/src/uCalibration.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- ACCURACY (uCalibration): DIAG_REFERENCE, the first 2000 words of
  "Aladdin and the Wonderful Lamp" (Andrew Lang, The Blue Fairy Book,
  1889 - public domain; Project Gutenberg 503), 114 strings in the
  source, ASCII. ExecuteDiagnostics aligns it with each run's words
  (Whisper.Align: WhisperSplitText, WhisperAlignText) and logs "against
  the text: its first N words were reached; of the M read, x % heard
  exactly, y % exactly or nearly, K not" - counted from the first to the
  last word matched (the recording has a spoken introduction and stops
  part way through the text); and after the costs "The fallback's worth:
  y % with it (run 1), y % without (run 2)". Only when the recording's
  file name is CALIBRATION_AUDIO. ASSUMED, to check on the first run:
  the recording reads that text from its first sentence (the calibration
  text at 0:01:23 is from it).
- uBuilder: BPC_CALIBRATE_ALL = 19, "Calibrate every model" on the home
  list -> miCalibrateAllClick. PadBackToMenu(AModel): True after a
  download, a calibration, the diagnostics (PadHome(BPC_MODEL)), False
  after a build or the queue. FPadToModel: set by OfferCalibration's "No",
  read and cleared by PadAnswer (the home list on Model instead of
  Create). Owner 17:02 "Move calibrate and diagnostics under model": the
  three rows - Calibrate (this model), Calibrate every model, Diagnostics
  (this model) - now follow the Model row in PadHome (they were above
  Exit).
NAMES TO LOOK AT if the compiler complains: the typed const array
DIAG_REFERENCE (114 strings; doubled apostrophes); Whisper.Align in
uCalibration's implementation uses (TWhisperStringArray,
TWhisperAlignedWordArray, TWhisperAlignStats, wamExact / wamSimilar /
wamNone); "if ... then try ... except ... end" in ExecuteDiagnostics;
PadBackToMenu's five calls with their argument.
NOT DONE, ON PURPOSE - THE CALIBRATION ON A CONTINUOUS STRETCH. Found
2026-11-21 (Ally, all six models; 5090): the calibration times ONE 30 s
clip per run, and whisper.cpp encodes such a clip TWICE - a window ends
at its last time stamp (seek += seek_delta; whisper.cpp 1.9.5,
whisper_full_with_state), the second or two left is a window of its own
with a full encoder pass - while a book costs about 1.15 passes per 30 s.
Turbo on the Ally: 2 x 1.01 s encoder + 0.5 s = 2.6 s = 11.4x calibrated;
1.53 s per window = 16.8x continuous (ratio 1.47; 5090 1.22; the Deck's
book 1.56). That IS HISTORY_BOOK_RATIO. The fix (TWhisperBenchmark's
MaxSeconds 120, one run: about the same time as 3 x 30 s) is small in
uCalibration but NOT SAFE ALONE: uHistory's second rule multiplies a
calibration by the ratio earlier builds had to THEIR calibrations, so a
new-style calibration times an old-style ratio (1.45) promises 40 % too
fast. It needs: the calibration's length kept per model in the settings
and per build in the history (a new column), the ratio rules using only
like with like, HISTORY_BOOK_RATIO about 1.0 - 1.05 for the new style
(to be measured), and every machine calibrated again. A zip of its own,
after the multilingual models' figures.
ALLY Z1 EXTREME, Vulkan0, 10 min (as a build / no fallback / failed
checks / words with / without): base.en 27.9x / 53.4x / 9 / 1500 / 1595;
turbo 16.8x / 16.7x / 0 / 1547 / 1547; tiny.en 11.0x / 79.6x / 57 /
1577 / 1587; small.en 8.4x / 26.5x / 23 / 1495 / 1502; large-v3 6.7x /
6.6x / 0 / 1470; medium.en 6.4x / 13.1x / 17 / 1553 / 1132 (27 % of the
words lost without the fallback). Turbo and tiny.en-without-fallback give
the same words on the 5090 and the Ally (1547, 1587); tiny.en with the
fallback does not (1602 / 33 retries against 1577 / 57). TO TEST (owner's
idea, 16:56): the multilingual tiny / base / small / medium - only the
.en models retried.

## Zip 204 (on top of zip 203): the builder frees its pad
Owner 2026-11-21 16:38, a screenshot of Delphi's "Unexpected Memory Leak"
at the builder's end: TSteamPad x 1, UnicodeString x 9, Unknown x 5 -
one TSteamPad with its set name, 8 action names and 5 arrays. The builder
made FPad in StartPad and never freed it (the reader does, in FormClose);
older than today's zips, which do not touch FPad. Now: where the window
frees FBuildLog and FModelItems, tmPad is stopped and FPad freed. Files:
demos/EpubBuilder/src/uBuilder.pas, CLAUDE.md. NOT COMPILED. NO PACKAGE
REBUILD. If the report still lists something after this, it is another
object: send the box.

## Zip 203 (on top of zip 202): Big Picture all dark, by default
Owner 2026-11-21 16:32, to "say if Big Picture should start dark" and "the
window behind keeps its light colours": "yes, all dark". NOT COMPILED
(pasdoc_check, project_check: 0 problems). NO PACKAGE REBUILD. Files:
demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md.
- The setting is [View] Dark now (zip 202's PadDark is not read), default
  True; the home list's row is "Dark mode". It covers the pad's menu
  (PadColors, zip 202) and the window.
- TfrmBuilder.ApplyDarkWindow (Big Picture only - there the window is the
  log): the form's Fill solid PAD_DARK_WINDOW ($FF1A1C22); the log's
  style resource 'background' (a TCustomStyleObject: a picture cut from
  the style) gets SourceLookup '' and Source nil, so it draws nothing and
  the form shows through; then the log's text PAD_DARK_TEXT (FontColor
  out of StyledSettings). Light again: Fill none, FontColor styled,
  NeedStyleLookup + ApplyStyleLookup (the style's background back).
  Called at the end of BigPictureWindow, on the row's change, and once a
  second from tmPadTimer (FDarkTick): the style may not be applied when
  the window is made, and a style applied again brings the background
  back - SourceLookup <> '' tells.
- SAFETY: the text is made light only after the background was found and
  switched off. A style whose 'background' is not a TCustomStyleObject
  (or has none) keeps the light log with dark text, and the debug log
  says "dark: the log keeps the style's colours - its background is a
  <class>" once (FDarkNoted).
- Implementation uses: FMX.Graphics (TBrushKind), FMX.Styles.Objects
  (TCustomStyleObject). NOT FMX.Objects (its TPath hides
  System.IOUtils.TPath - zip 182's lesson), so a TRectangle background
  is not handled.
THE UNCERTAIN PART (written from knowledge of FMX's styles, not tried):
that mmLog.FindStyleResource('background') reaches the styled
presentation's object on every platform (Windows, macOS, FMXLinux); that
an empty SourceLookup with Source nil stops the drawing; that the
scroll bar's light look is acceptable. TO TEST (owner, Big Picture, each
system): the log dark with light text; the debug log's "dark: ..." line;
Dark mode < No > puts the light log back at once; after a sleep / wake
and a full-screen toggle the log is still dark within a second.
NAMES TO LOOK AT if the compiler complains: TCustomStyleObject's
SourceLookup and Source (FMX.Styles.Objects); Fill.Kind / TBrushKind on
the form; mmLog.NeedStyleLookup / ApplyStyleLookup; names FMX.Graphics
brings into uBuilder's implementation (TBitmap, TCanvas, TFont) that an
existing line may now resolve differently.

## Zip 202 (on top of zip 201): a dark pad menu in the builder
Owner 2026-11-21 16:29: "Add a dark mode to Builder's Steam Menu". NOT
COMPILED (pasdoc_check, project_check: 0 problems). NO PACKAGE REBUILD.
Files: demos/EpubBuilder/src/uBuilder.pas, demos/EpubBuilder/README.md,
CLAUDE.md. uPadMenu is not changed: TPadMenu.SetColors was there (the
reader's dark menu uses it) and the colours take effect at the next Show.
- FPadDark ([View] PadDark, default False = the light menu as before;
  read in LoadSettings, written in SaveSettings); PadColors (after
  FPadMenu is made in StartPad, and on a change): dark = PAD_DARK_BACK
  $FF23262E, PAD_DARK_TEXT $FFE0E0E0, PAD_DARK_ROW $FF34405A (the
  reader's dark menu, uMain.PadMenuColors); light = white, black,
  PAD_LIGHT_ROW $FFD6E4F5 (TPadMenu's own).
- The home list's row "Dark menu < Yes > / < No >" (BPC_DARK = 18, under
  "Chapters of a file are parts"): left / right or A turns it (PadStep),
  saves, and the list is shown again in its new colours. Questions
  (Ask / ShowText) take the same colours.
NOT DONE: the window behind the menu (the log, text 24, the progress
panel) keeps the style's light colours - a dark window is a style
change, not asked for here. The default stays light: say if Big Picture
should start dark.

## Zip 201 (on top of zip 200): the calibration offered by itself, the menu comes back
Owner 2026-11-21 16:14 (installing every .en model for the diagnostics, in
Big Picture): "After loading a new model it always tells you it's not
calibrated yet. It should automatically ask if it should calibrate. If no
then back to menu, if yes then calibrate and back to menu (everything
should normally result in the menu after it's finished)". Zip 200 COMPILED
AND RAN (owner). This zip: NOT COMPILED (pasdoc_check, project_check: 0
problems). NO PACKAGE REBUILD. Files: demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/README.md, CLAUDE.md.
- TfrmBuilder.OfferCalibration: the model in the window has no calibration
  (CalibrationSummary = '') -> Ask "Calibrate it now?" (the pad's menu in
  Big Picture, a dialog on the desktop); Yes = StartCalibration(False,
  False); No is kept in FCalibDeclined (file names between tabs) for the
  run. Not asked while FBuild / FCalib / FDownload / FQueueRunning, nor
  with [Calibration] DontAsk. Called from DownloadDone (a model
  downloaded) and cbModelChange (a model here chosen), each after the
  older first-model path (FCalibPending -> CheckCalibrationAtStart), so
  only one question is asked.
- TfrmBuilder.PadBackToMenu (no parameter: DownloadDone, RunNextJob and
  BuildDone lie above the BPC_* constants - zip 149's lesson): Big
  Picture only, PadHome(BPC_BOOK) unless a question is shown (BPM_ASK) or
  something runs. Called at the end of DownloadDone, CalibrationDone
  (calibration and diagnostics), BuildDone and RunNextJob's "queue
  finished". After an answer PadAnswer already shows the home list.
NAMES TO LOOK AT if the compiler complains: the anonymous method in
OfferCalibration capturing Mark and Model; PadBackToMenu's place (its body
must stay below BPM_ASK / BPC_BOOK).
TO TEST (owner, Big Picture): download a model -> the question; No -> the
home list; choose it again -> no question; Yes -> calibration -> the home
list; diagnostics -> the home list; a build alone and a queue -> the home
list once, at the end. Desktop: the question is a dialog; nothing else
changes.
RESULTS SO FAR (5090 laptop, Vulkan0, 10 min of Aladdin, zip 200's build;
runs repeat within 1 %): turbo as a build 101.9x, no fallback 102.1x, no
DTW 110.3x - 0 failed checks, 1547 words and the same decoder runs in
every run, windows 0.17 - 0.29 s: the fallback is free for turbo and
stays on. tiny.en as a build 37.5x, no fallback 180.2x - 33 probability
fallbacks in 22 windows, windows 0.11 s (passed) to 1.74 s. Fresh
calibrations: turbo 83.6x, tiny.en 188.7x - so turbo's continuous first
pass is 1.22 times its calibration with no retries involved: the gap is in
how the calibration times (single 30 s calls), to be compared on the other
machines from the diagnostics' header line and run 1. The stored turbo
calibration on that laptop was of 2026-11-17 (26.1x, CUDA0 still listed).
KNOWN, NOT FIXED: "decoder ... in N runs" adds whisper.cpp's prompt runs,
which DTW's extra pass raises (2395 with DTW, 437 without); the build
stamp showed no '+' on a tree with these zips applied.

## Zip 200 (on top of zip 199): the diagnostics log keeps every run
Owner 2026-11-21 15:46, after a turbo run then a tiny.en run on the 5090
laptop: "I take it you overwrite the diagnostics as I did a turbo run
first". It did. Zips 198 + 199 COMPILED AND RAN (owner's Windows build).
- uBuilder.CalibrationDone (diagnostics): the run's lines are ADDED to
  <settings>-diagnostics.log (loaded, AddStrings, saved); the file is
  never emptied by the program. QuitSignalled's save of a run stopped
  from outside still replaces the file (not changed).
- uCalibration.ExecuteDiagnostics: the windows line gives the fastest
  window too (with the fallback on, a window that passes is far below
  the middle one, and "more than twice the middle" does not show it).
Every line of a run is also in the debug log (TCalibrationThread.Log ->
DebugLog), and the run before the last start in EpubBuilder-debug.log.old.
FIRST RESULT (5090 laptop, tiny.en, Vulkan0, 10 min of Aladdin; the
calibration's one stretch: 192.3x): as a build 37.1x, 1602 words, 33
probability fallbacks and 0 entropy in 22 windows, decoder 22009 runs,
sampling 6.2 s; no fallback 180.3x, 1587 words, decoder 4252 runs; no DTW
38.8x; neither 227.1x. So for tiny.en the FALLBACK is 79 % of the time and
every one was the probability check (avg_logprobs < logprob_thold -1.0),
none the entropy check (the loop detector); DTW is about 0.7 s per 10 min
of audio. This is the "fixed cost per window" of the small models (Later
tests 1) and the Miix's 11.9x calibration against a 3.0x book: the
calibration's stretch passes the check. DO NOT turn the fallback off for
builds (owner: turbo "used to stall badly ... don't want that to come
back" - BOOK_PROMPT's note): the entropy fallback is the net under loops.
TO DECIDE after the turbo figures: for small models only, no retry on
probability alone (logprob_thold - but whisper.cpp also uses it, with
no_speech_thold, to call a window silent) or cheaper retries (best_of,
temperature_inc), tried as a fifth diagnostics run first.
Files: demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/src/uCalibration.pas, demos/EpubBuilder/README.md,
CLAUDE.md. NOT COMPILED. NO PACKAGE REBUILD.

## Zip 199 (on top of zip 198): zip 198's compile error
Owner's Windows build, 2026-11-21 15:36: uCalibration.pas(125) E2169
"Field definition not allowed after methods or properties".
TCalibrationThread's three new methods (DiagLogLine, DiagProgress,
ExecuteDiagnostics) were declared among the fields, before FOnLog /
FOnProgress / FOnStatus: moved below Status, the last method of the
private section. Both units' classes were then scanned for a field after
a method in the same visibility section: none. LESSON: in a class
section, every field comes before the first method or property - add new
fields after the last field, new methods after the last method. Files:
demos/EpubBuilder/src/uCalibration.pas, CLAUDE.md. NOT COMPILED. NO
PACKAGE REBUILD. (The H2164 hints in uQuitSignal - GProc, GDone - are
older and not from these zips.)

## Zip 198 (on top of 51dbf1f; holds all of zip 197): Tools > Run diagnostics
Owner 2026-11-21 15:05: "can you add a diagnostics option to the menu that
will perform the tests - setting options is extremely awkward, a last
resort". NOT COMPILED (pasdoc_check and project_check: 0 problems). NO
PACKAGE REBUILD. Files: demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/src/uCalibration.pas, demos/EpubBuilder/README.md
("Diagnostics", "Diagnostic builds"), CLAUDE.md. Zip 197 need not be
applied first: its three files are all in this one. No project file
changed (no new unit: the diagnostics are in uCalibration).
- uCalibration: TCalibrationThread.Diagnostics (set before Start) ->
  Execute calls ExecuteDiagnostics: the first DIAGNOSTIC_SECONDS (600) of
  the recording, the first model on the first device, four runs with the
  build's Params - 1 as a build, 2 TemperatureInc 0, 3 no DTW
  (flash_attn off), 4 neither; the model is loaded for runs 1 and 3.
  Each run: whisper_reset_timings, TWhisperRun.Execute (first pass only,
  IncludeWords), whisper_print_timings. The printed lines are read from
  whisper.cpp's log (Lib.AddLogListener(DiagLogLine), NumberAfter):
  fallbacks p / h (since the model's loading: the run's own are the
  difference from the run before on the same model), sample / encode /
  decode + batchd + prompt times and the decoder's runs. Window times:
  DiagProgress - whisper.cpp 1.9.5 calls the progress callback at the top
  of every window's loop (no progress_step in this version), so the time
  between two reports is a window's. Logged per run: s, x real time,
  words, failed checks, encoder / decoder / sampling / the rest, windows
  (middle, slowest, how many over twice the middle); then the fallback's
  cost (run 1 - run 2), DTW's (run 1 - run 3), run 4's speed. Cancel
  cancels FDiagRun. Completed = four runs made; Results stays empty.
- uBuilder: miDiagnostics (Tools > Run &diagnostics (this model)...),
  BPC_DIAGNOSE on Big Picture's home list, StartDiagnostics (the window's
  device, "Default" as GDefaultDevice; the calibration's recording, not
  asked for; FCalib is the thread, so Cancel, the progress panel, Busy,
  closing and QuitSignalled work as for a calibration, with their texts
  saying diagnostics), CalibrationDone's branch for it (nothing saved to
  the settings; lines to <settings>-diagnostics.log,
  DIAGNOSTICS_LOG_SUFFIX).
NAMES TO LOOK AT if the compiler complains: TFormatSettings.Invariant and
TryStrToFloat's three-argument form (NumberAfter); TArray<Double> in the
class (FDiagWindows) and Copy of it; Lib.AddLogListener /
RemoveLogListener with a method of the thread (TWhisperLogEvent);
Run.OnProgress := DiagProgress (TWhisperProgressEvent); the typed const
array RUN_NAMES inside the method; IfThen on strings (System.StrUtils is
in both units); FCalib.Diagnostics in the texts.
TO TEST (owner), each machine, small model and turbo: Tools > Run
diagnostics; send EpubBuilder-diagnostics.log (and the debug log). Check
first: run 1's speed is near a build's first pass; the windows count is
about 20 - 25; Cancel during a run ends it within a window.

## Zip 197 (on top of 51dbf1f "Pre branch"): diagnostic builds, whisper.cpp's timings
Session 12, 2026-11-21. NOT COMPILED (pasdoc_check and project_check: 0
problems). NO PACKAGE REBUILD. Files: demos/EpubBuilder/src/uBuilder.pas,
demos/EpubBuilder/README.md ("Diagnostic builds"), CLAUDE.md.
WHY: on the Miix 520 (UHD 620, Windows) tiny.en calibrated at 11.9x and
built Foundation and Empire at 3.0x - book / calibration 0.25, where
turbo on every other machine gives 1.36 - 1.56 (Deck 1.56, Ideapad GTX
1650 1.55, Ally Z1 Extreme 1.45, Steam Machine 1.36). From the debug
log's status lines: slow from the first 30 s window, and two speeds -
most windows about 15 s, some 1.5 s (16 - 21x). Not heat. Suspects:
whisper.cpp's temperature fallback (a small model fails the entropy /
probability check often; each retry samples best_of 5), or DTW (the
"fixed cost per window" of the small models, Later tests 1). The
calibration times ONE window three times, so one clean window set the
estimate (35:45 against 3:12:20).
- DiagSwitch / BuildDiagnostics (uBuilder, implementation): --no-fallback
  or EPUBUNUM_NO_FALLBACK -> Params.TemperatureInc := 0; --no-dtw or
  EPUBUNUM_NO_DTW -> WhisperEnableDtw not called, CP.flash_attn := False
  (only DTW differs). Both are read from the command line (Steam's launch
  options; EpubBuilder.sh passes "$@") and the environment.
- A diagnostic build (TBuildThread.FDiagnostic, TBuildSummary.Diagnostic):
  FReuse off, ReadPartial / SavePartial / SaveTranscript skipped, and
  RecordHistory logs the "Speed:" line but does not call HistoryAdd.
  Start-up and build logs say "DIAGNOSTIC ...". The calibration is not
  changed by the switches.
- TBuildThread.LogTimings, every build: whisper_reset_timings before each
  part's Execute, whisper_print_timings after it and after FillGaps (to
  the debug log through the whisper.cpp log listener). whisper.cpp 1.9.5
  facts (read in the submodule, 5922450): the timings are the context's
  default state's - TWhisperRun.Execute passes no state, so they are the
  run's; reset_timings does NOT reset n_fail_p / n_fail_h (fallbacks
  count from the model's loading); DTW is not inside any timer.
NAMES TO LOOK AT if the compiler complains: Lib.Flat.whisper_reset_timings
/ whisper_print_timings (Whisper.API TWhisperFlat, optional entries, used
as WhisperConsole does), CP.flash_attn, Params.TemperatureInc,
Model.Handle; "end" + comment + "else if" in Transcribe; IfThen on
strings in BuildDiagnostics (System.StrUtils).
TO TEST (owner): Aladdin (34:32, public domain - its logs can be shared)
built four ways with a small model and again with turbo, same machine:
no switch; --no-fallback; --no-dtw; both. Compare the "Speed:" lines and
the timings. Then decide: the Lite benchmark model (tiny.en / base.en /
small.en), a calibration over several windows, HISTORY_BOOK_RATIO.
ALSO FOUND TODAY, NOT FIXED (owner to decide): the calibration line says
Vulkan1 10.0x and the "Device:" line 9.9x (Ideapad); the report table
gives the whole job's speed (16.4x) and the log line the transcription's
(16.5x) (Ally); "Exact" is of all book words in RESULTS and without front
/ back matter in "Speed:"; "not heard" words get no clip though the text
says "timed like interpolated words" (clips = timed words - not heard);
link lines ("Paired", "Received ...") land in the calibration log;
"redraw: displays (none read)" on the Ally and on Ubuntu. Steam Input
must be turned on for the app on the partner site, or desktop Steam
gives the program no controllers (SteamOS forces it on) - done by the
owner 2026-11-21.

## Zip 192 (on top of zip 191): the builder's window - settings page, queue below
Owner 2026-11-21 05:11: "Builder - Model, Device, Language, Power, GPU,
Chapters are parts... and Use Saved Transcript can all go on their own
settings form/menu reducing clutter. The job queue can now move below
Book and Audio providing more space and allowing for larger fonts where
needed (like Deck)"; 05:12 "GPU = Low Power / Use GPU on Windows"
(cbGpu, Window GPU).
- uBuilder.BuildWindow rewritten (the same controls and handlers, other
  parents): layBottom (Bottom, 4 rows + 190): Output EPUB, Settings
  (lblSettings + btnSettings), the buttons + pbBuild, Now, then
  mmLog / layProgress as before. layTop (Top, Y 50000, 55 % of what is
  left, min 200): layBook (Left, 45 % of the width, min 380), splSides,
  layAudio (Client). splQueue now a Top splitter (Y 60000) between
  layTop and layQueue (Client: caption, Load / Save / Remove / Up / Down
  + btnRunQueue in that row - no longer a Bottom button, lbJobs).
  pnlSettings: TPanel, Align Contents, hidden: caption, rows Model
  (+ Folder...), Device (Client), Language (320), Power (Client), Window
  GPU (Windows, 320), chkChapters, chkReuse (text + "- this build only"),
  Done (Default). Window: ClientHeight at least 820, then the screen
  clamp.
- btnSettingsClick (Settings... and Tools > Settings..., first in
  Tools), btnSettingsDoneClick (hide, SaveSettings, UpdateSettingsLine,
  UpdateControls), UpdateSettingsLine (model without 'ggml-', device -
  the chosen, GDefaultDevice or 'the default device' - language, power's
  first words, 'a file's chapters not parts', ' - USING THE SAVED
  TRANSCRIPT'); called from UpdateControls too.
- BigPictureWindow hides layTop and pnlSettings as well.
- README (builder): ## The window; the queue / transcript / Window GPU
  passages.
NOT DONE: larger fonts (the owner's "where needed (like Deck)") - the
room is there now; ASK what size / when (Desktop Mode on the Deck?).
NOT COMPILED. NO PACKAGE REBUILD.

## Zip 191 (on top of zip 190): the icon set (reader, builder, manager)
Owner 2026-11-21 05:03: "Now do icons for builder and a new one for
reader. They should all share a theme as they belong in a set".
- tools/make_icons.py (Pillow; replaces zip 189's
  make_bookmanager_icon.py - DELETE that file) writes all three .ico
  (16, 24, 32, 48, 64, 128, 256): the same navy tile (28,52,84, radius
  0.18), cream books (251,247,239 / 236,230,218), grey lines, an amber
  badge (255,190,40) at (0.72, 0.70) with a navy ring and a dark-navy sign
  (12,42,87). EpubReader: open book (pages 0.16 - 0.70, high so the right
  page shows beside the badge), 3 lines on the right with an amber word,
  play. EpubBuilder: the same book, a waveform on the right page (one bar
  amber), a gear (8 teeth; 6 at 16 px). BookManager: unchanged from 189.
  24 px and below: no page lines / spine bands; 16 px: bolder signs.
  `python3 tools/make_icons.py preview.png` also writes a preview sheet.
- demos/EpubReader/EpubReader_Icon.ico REPLACED (the .dproj already
  names it); demos/EpubBuilder/EpubBuilder_Icon.ico NEW +
  EpubBuilder.dproj ONE line (Icon_MainIcon in the Base_Win64 group,
  before DCC_Namespace; BOM and LF kept); BookManager_Icon.ico rewritten
  (same picture).
- gen_projects.py: icon= on EpubReader and EpubBuilder too (never run on
  their IDE-saved .dproj; for a regeneration).
- READMEs: reader (icon note), builder (## Icon), manager (## Icon).
- macOS .icns / Linux icons: still not made.
NO PACKAGE REBUILD.

## Zip 190 (on top of zip 189): a typed output folder is remembered
Owner 2026-11-21 04:56: "Changing the output directory when adding books
to builder then adding to queue results in the next book having the old
default directory rather than the new one". Choose... (btnOutClick) and
Tools > Output folder already set FOutFolder; a path TYPED in edOut did
not (no handler) - read as that.
- uBuilder: RememberOutFolder - edOut's folder (trimmed, no trailing
  delimiter), when not FOutFolder and it exists, becomes FOutFolder;
  LogLine "Output folder: ... (the next book's output goes there too)";
  SaveSettings. Called first thing in JobFromWindow (its callers: Add to
  queue - both paths - and Create/StartBuild). A folder that does not
  exist is not taken (a typing slip).
- README (builder): the folders paragraph.
If it was another path (the Big Picture menu has no way to change the
output - its Output row only shows it), ASK.
NOT COMPILED. NO PACKAGE REBUILD.

## Zip 189 (on top of zip 188): BookManager's icon; the Deck measured
Owner 2026-11-21 04:33: "Create a icon for BookManager".
- demos/BookManager/BookManager_Icon.ico (16, 24, 32, 48, 64, 128, 256):
  EpubReader's family - navy rounded tile (28,52,84), cream books on a
  shelf (the middle one's spine bands amber, as the reader's highlighted
  word), an amber badge cut out by a navy ring with an up arrow (sent)
  and a down arrow (fetched). 16 px: one arrow with a head at each end
  (two did not read). Drawn by tools/make_bookmanager_icon.py (Pillow, 4x
  supersampled) - rerun it to change the icon.
- BookManager.dproj: ONE line, Icon_MainIcon in the Base_Win64 group (as
  EpubReader's). gen_projects.py: new key icon= (Win platforms' groups);
  BookManager's entry has it - BUT regenerating makes a new ProjectGuid
  (seen): the .dproj in the zip is the old one + the line. If the IDE has
  saved BookManager.dproj since zip 181, set the icon in Project >
  Options > Application > Icons instead of taking the .dproj.
- macOS (.icns) / Linux icons: not made (as EpubReader).

STEAM DECK MEASURED 2026-11-20 (zip 187 build, Game Mode, mains, no
sleep): Foundation (8:56:46, 55 parts, 1 m4b), turbo on Vulkan0 (RADV
VANGOGH): 1:07:59, 7.9x; calibration 5.08x -> book / calibration 1.56
(highest yet: Steam Machine 1.36, M4 Core ML 1.36, M4 Metal 1.48).
Steady: parts over 10 min 7.2 - 8.3x start to end (no heat slowdown);
about 2.5 s fixed per part. Exact 96.1 %, matched 98.8 % "very good",
not heard 9, 55 chapter marks; EPUB 489.3 MB. CPU calibrated 0.4x.
Turbo: Deck 7.9x, Steam Machine 37x, 5090 laptop 83x (Ender in Exile).

## Zip 188 (on top of zip 187): ROCm's runtime without kernels = no ROCm
Owner 2026-11-20 21:26: zip 187 WORKS on the Deck - "ROCm0 left out ...
a Steam Deck", calibration CPU 0.4x, Vulkan0 5.1x (turbo; 4:24),
whisper.cpp "using Vulkan0 backend" with ROCm0 still first in ggml's list.
The "ROCm check:" line: HIP_VISIBLE_DEVICES and EPUBUNUM_ROCM_OFF empty,
rocblas beside the program False, /sys/class/kfd True. Asked where the
kernels are -> 21:28: "Nothing (I've stopped shipping the HIP depot)". So
the LINUX DEPOT still carries ggml-hip + libamdhip64 (ROCm0 listed) WITHOUT
kernels - on every Linux machine (Steam Machine too: would hang the same).
Told: stage without ROCm (deploy_redist.py --skip-rocm, or
steam_stage.py moves the ROCm files out of Deployment/Linux).
- EpubBuilder.sh: the check now runs when libamdhip64.so* is beside the
  program (the bundled runtime; a system ROCm is not judged) and
  HIP_VISIBLE_DEVICES is not set: no $here/rocblas -> off ("no ROCm
  kernels beside the program (rocblas/ missing)"); else the kfd gfx check
  as in 186 ("no ROCm kernels here for gfx1033"). EPUBUNUM_ROCM_OFF holds
  the whole reason now. Tested (fake trees): full+deck off, full+machine
  kept, no kernels + machine / deck off, system ROCm untouched.
- uBuilder: RocmUnusable also true for libamdhip64.so* beside the program
  without rocblas/; the env's text used as it is ("ROCm: off - <why>;
  Vulkan is used."); CheckRocmDlc skips the offer only on a Deck or for
  "no ROCm kernels here for ..." (no kernels at all is what the DLC
  brings).
- README (builder): the ROCm paragraphs.
NOT COMPILED. NO PACKAGE REBUILD.

## Zip 187 (on top of zip 186): ROCm left out by the program too
Owner 2026-11-20 21:01 / 21:11: the zip-185 build hung >10 min after
"ROCm0 total size = 1623.92 MB" (calibration, turbo on ROCm0); with zip
186 deployed (screenshot: the log-only window) the calibration question
still listed "CPU, ROCm0, Vulkan0" - the launcher did not hide HIP (not
known why: old .sh, no rocblas/ there, /sys/class/kfd not seen, or
HIP_VISIBLE_DEVICES=-1 not honoured in the runtime).
- uBuilder: RocmUnusable(out Why) = EPUBUNUM_ROCM_OFF set, or
  SteamOnDeck; IsRocmDevice (Backend ROCm / HIP, or a name starting
  ROCm). FormCreate after SelectableDevices: debug line "ROCm check:
  HIP_VISIBLE_DEVICES=..., EPUBUNUM_ROCM_OFF=..., rocblas beside the
  program: ..., /sys/class/kfd: ..."; when unusable the ROCm devices are
  taken out of FDevices (LogLine "<name> left out: ROCm cannot run here
  (why)") - so cbDevice, CalibrationDevicesKey and the calibration
  thread never see them - and GDefaultDevice := the first GPU left (else
  the CPU). GDefaultDevice: Default's meaning - DefaultDeviceItem says
  it; the window's build / job passes it for Default; TBuildThread.Create
  turns '' into it (old queued jobs).
- README (builder): the ROCm paragraph.
ASKED: the debug log's "ROCm check:" line (why the launcher did not act).
NOT COMPILED. NO PACKAGE REBUILD.

## Zip 186 (on top of zip 185): no ROCm on a GPU without kernels (Steam Deck)
Owner 2026-11-20 20:55: "it's trying to calibrate rocm on a Steam Deck"
(zip 185's screenshot: Default = "ROCm0 - the first GPU"). The ROCm
depot is in the builder's playtest for everyone (no DLC on a Playtest,
zip 111); ggml-hip lists the Deck's gfx1033 (not a ROCm target - no
kernels in rocblas/), makes it Default (HIP before Vulkan) and the
calibration times it.
- EpubBuilder.sh: when HIP_VISIBLE_DEVICES is not set, $here/rocblas
  exists and /sys/class/kfd/kfd/topology/nodes exists: each node's
  gfx_target_version (0 = CPU) -> 'gfx%d%x%x' (major, minor, step; 100303
  -> gfx1033, 110002 -> gfx1102, 90010 -> gfx90a); usable when find
  rocblas -name '*gfx*' finds a file. None usable -> export
  HIP_VISIBLE_DEVICES=-1 (ggml_cuda_init: no device -> no ROCm0) and
  EPUBUNUM_ROCM_OFF="<gfxs>", stderr line. Mixed (one usable): nothing
  hidden. Tested here with fake kfd trees (deck / machine / mixed / user
  set / no rocblas). sh -n clean; still executable (100755).
- uBuilder: FormCreate logs "ROCm: not for this GPU (...)" when
  EPUBUNUM_ROCM_OFF is set; CheckRocmDlc offers nothing then, nor on a
  Steam Deck (SteamOnDeck - no rocblas without the DLC to judge by).
- The calibration's device key changes on the Deck (no ROCm0): it asks
  to calibrate again - expected.
- README (builder): the ROCm DLC section.
NOT TESTED ON THE DECK (HIP_VISIBLE_DEVICES=-1 -> hipGetDeviceCount
error / 0 is ggml's "failed to initialize ROCm" path). NOT COMPILED.
NO PACKAGE REBUILD.

## Zip 185 (on top of zip 184): the builder's Big Picture window = the log
Owner 2026-11-20 20:49 (a Steam Deck screenshot, Game Mode: the desktop
window behind the pad's menu, 1300 wide on 1280 - Down cut off; tiny
text): "The font is too small on a Steam Deck / The form appears too
large". Asked (scale + tabs / fit + larger text / progress only); owner:
"We're going to redo the form when displayed in big picture mode. The
only thing to remain may be the message log (full screen)".
- uBuilder: BigPictureWindow (from StartPad when FBigPicture): layQueue,
  splQueue, layBook, splSides, layAudio hidden; layBottom Align Client,
  every child hidden, SetLogVisible(True), mmLog text 24 (StyledSettings
  - Size), wide margins; logged. BuildMenu: TMainMenu not parented in Big
  Picture (as the reader), RecreateOSMenu only when parented (also in
  CheckRocmDlc). Linux's mnuBar was hidden already. The pairing bar
  (zip 183) still shows above the log.
- Desktop: ClientWidth = max(form, min(1300, work area - 16)); height
  kept within the work area (min 500); a work area of 0 changes nothing.
  (Screen.WorkAreaWidth / Height - check on FMXLinux.)
- README (builder): Big Picture.
NEXT (owner): the Big Picture form redone - "may be" more than the log.
NOT COMPILED. NO PACKAGE REBUILD.

## Zip 184 (on top of zip 183): transcribed books last; BP home order; BookManager's poll backs off
Owner 2026-11-20 20:34, three things:
1. "the already transcribed titles still appear higher on the list in
   some cases than the new ones. Books that have been successfully
   transcribed should be at the end of the list marked as transcribed
   and/or in a different colour" - read as Big Picture's Books list
   (PadBooks; the desktop's Choose is a file dialog). uBuilder: BookKey
   (file name, no extension, '_NNN' of DefaultOutput off, lower case),
   TranscribedBooks (EPUBs in FOutFolder, the jobs' output folders, the
   cards' Transcribed; + history rows with MatchedPercent >=
   HISTORY_POOR_MATCH by OutputName). PadBooks sorts not-done first, then
   done; done rows Dim + value 'transcribed' ('<sub>, transcribed').
   uPadMenu (reader's src, used by both): TPadMenuItem.Dim (text
   Faded(FFore, $80)); Item sets it False.
2. "Add to queue should be 3rd and Queue 4th - the Run Queue button it
   irrelevant (it appears as the first option on Queue)": PadHome order
   Book, Audio, Add to queue, Queue, Model, ...; BPC_RUN row gone from
   home (the command stays for the Queue list); after Add to queue the
   home list selects Queue (was Run queue).
3. BookManager, the builder closed: first-chance EIdSocketError 10061 /
   EIdConnectTimeout every second. TLinkPoller: FFailures - pause 1 s,
   then 2 / 4 / 8 / 16 / 30 s; FHeard - not polled at all while the
   finder does not hear the builder (SetHeard from FinderChange; back:
   at once); Poke. uManager: FHeard, "Not heard (closed or asleep)",
   status lines on leaving / coming back. The few tries before it is
   "not heard" (10 s) still raise first-chance exceptions (handled;
   README: the debugger's ignore list). Transfers still fail at once
   when it is gone (re-drop: those there are skipped) - OFFERED: hold
   them until it is heard again.
READMEs: builder Big Picture list; BookManager Connecting.
NOT COMPILED. NO PACKAGE REBUILD.

## Zip 183 (on top of zip 182): the builder's pairing bar
Owner 2026-11-20 20:22: "When I pair with Builder the dialog on builder
should automatically close. The OK button makes no sense - Only Cancel -
which should be 'Refuse Connection'". The old box was Ask -> on desktop
TDialogService.MessageDialog (native, modal: cannot be closed from code).
- uBuilder: pnlPair (TPanel, Top, made on first use - NOT TRectangle:
  FMX.Objects' TPath would hide IOUtils' in uBuilder): who asks, the code
  large ('123 456'), the time left (tmPair, 1 s), Refuse connection.
  ShowPairing / HidePairing / RefusePairing / tmPairTimer /
  LinkPairEnded. Closes on LinkPaired, the code's time out
  (LINK_PAIR_MINUTES), five wrong codes (OnPairEnded), Refuse. Big
  Picture: also the pad's box (ShowText, one row 'Refuse connection', A
  and B refuse) unless another question shows; FPairPad - Ask() clears
  it (a later question replaces the box), HidePairing closes the box only
  while it is still the pairing's (FPadMode = BPM_ASK).
- uLink (server): LINK_PAIR_MINUTES public (was PAIR_MINUTES in the
  implementation); RefusePair (code dropped, FPairRefused: confirm answers
  403 'the connection was refused on EpubBuilder' until the next /pair);
  OnPairEnded after the fifth wrong code (answer 'wrong code five times:
  ask again').
- BookManager: a refusal or an 'ask again' answer closes the code row.
- READMEs: builder's "The link", BookManager's "Connecting".
NOT COMPILED. NO PACKAGE REBUILD.

## Zip 182 (on top of zip 181): BookManager's TPath
Owner 2026-11-20 20:09: uManager(364, 373, 1437) E2003 'Combine' /
'GetDocumentsPath' - FMX.Objects' TPath (the shape control, used for the
drop TRectangle's unit) hides System.IOUtils.TPath. Written
System.IOUtils.TPath; a note at the uses. Remember for any unit using
FMX.Objects.
NOT COMPILED. NO PACKAGE REBUILD.

## Zip 181 (on top of 42d5f27 = zip 180): BookManager (desktop, not Steam)
Owner 2026-11-20 19:39: "lets do bookmanager (Non Steam)" - zip 175's
plan: a drop target routing books / audio / pictures / folders, progress
and log tabs, fetches the books made, space-aware, nothing typed.
- NEW demos/BookManager: BookManager.dpr / .dproj (gen_projects.py, new
  key prebuild=True: buildstamp.bat as EpubBuilder's PreBuildEvent -
  uDebugLog includes BuildStamp.inc), README.md, src/uManager.pas + .fmx
  (window in code, as the builder's), src/uTransfers.pas, src/uRoute.pas.
  Units: uDebugLog, uMachine, uEpubUnum, uLink. NO EpubUnum package used
  (Indy only). EpubUnum.groupproj: BookManager last (edited by hand).
- uRoute.RouteFiles: file -> its kind's folder ('' dir); folder -> each
  file with Dir = dropped folder's name + sub folders ('/'); pictures
  always Covers root, and LEFT OUT beside audio files (folder.jpg - the
  builder matches covers by the book's name; DECIDE with the owner);
  hidden, .part, other kinds left out (listed: status + debug log).
  Order: books, pictures, audio.
- uTransfers: TLinkTargets (id -> host, port, token; thread safe);
  TTransferWorker (one at a time, a new TLinkClient per job from the
  targets - follows a builder that moved; Cancel(id) drops a waiting one
  or cancels the running one; progress queued at most 5/s);
  TLinkPoller (1 s: /status + /log?from; /space every 10 s; /books every
  20 s or on WantBooks; Follow(id) = new generation, log from 0, the
  round running cancelled). Results by TThread.Queue from per-call
  helper methods (each closure its own captured copy); freeing a thread
  cancels its call and drops its queued events.
- uManager: builder combo (heard peers; the chosen one kept as "not heard
  now"; auto-choose last id, else the only one), Pair... -> /pair, a code
  ROW in the window (no InputQuery - its FMX Linux support unknown),
  token in BookManager.ini [Paired] id=token; a 401 "not paired - ..."
  from the poll forgets the token. Tabs: Send (TRectangle drop target +
  the list, Add files / Add folder, Cancel / Cancel all / Clear
  finished, the builder's room from /space, asks when the drop needs
  more than free - reserve), Books made (ticks, new / here = same name
  and size in the fetch folder, Fetch checked / all new, Folder...;
  default EpubUnum/Transcribed; refuses below 1 GiB free here; a .part
  is resumed only when its '.part.from' note - size and modified of the
  build - matches, else deleted: a rebuilt book's bytes never mix), Progress
  (the builder's /status fields), Log (5000 lines). Close asks when
  transfers are unfinished.
- uLink (client side only; builder and reader unchanged in use):
  TLinkClient.Cancel (thread safe: FCancel + Disconnect of the call's
  TIdHTTP under a lock - ends a call stuck on a sleeping builder),
  ELinkCancelled; download size known at WorkBegin (was 0 until the end);
  progress counts only the transfer's direction; non-HTTP errors become
  ELinkError 'EpubBuilder at host:port: ...'; Upload(..., AReplace, ...)
  + Skipped (the check's "there": same name and size -> not sent).
- READMEs: root (demo 7), BookManager's own.
CHECK AT FIRST COMPILE: TListBox's OnDrag* events assigned in code; FMX
file drops on Linux (fallback: Add files / Add folder); TIdHTTP.Disconnect
from another thread. NOT COMPILED.
NO PACKAGE REBUILD.

## Zip 179 (on top of zip 178): the reader's cover chooser
Owner 2026-11-20 12:54: "Reader should also be able to change covers -
options = current, image from m4b, image from Covers folder"; asked:
"Reader only" (the library's picture; the book file untouched).
- uCovers: AudioCoverStream(stream, ext) (AudioCover uses it);
  TStreamWindow (a read-only part of a stream: a ZIP entry STORED, read
  where it lies - Mp4Cover seeks through it).
- uCoverPick.Show(title, AAutoCaption, ...): no Automatic tile when
  AAutoCaption is '' (the builder passes its text).
- uMain (reader): uses EpubBuilder's uCovers + uCoverPick (dpr / dproj:
  ..\EpubBuilder\src\...). ShowCoverChoice: options = the book's own
  (ReadResource(CoverPath); choice 'book'), the audiobook's (B.AudioFiles
  -> Zip entry, Method 0: local header at LocalOffset, data at +30 +
  name + extra -> TStreamWindow -> AudioCoverStream; choice 'audio'),
  CoverOptions(EpubUnum/Covers, [file name, title]); chosen: 'book' ->
  the cache deleted and EnsureCover; else SaveImageCover(data,
  CoverFile(FBookFile)). View > "Cover of this book..." (miCoverClick);
  pad: MENU_COVER = 9 (MENU_EXIT now 10), PadPress routes to the picker
  while it shows (Up/Left, Down/Right, Play, Back/Menu).
- README (reader): "A book's cover in the library". (Its second
  paragraph, a muddled note on zip 176, was taken out after delivery -
  goes with the next zip.)
NOT COMPILED.

## Zip 178 (on top of zip 177): shared EpubUnum folders (uEpubUnum)
Owner 2026-11-20 12:54: "the user data folder should be named epubunum
rather than an app's name so things can be shared easier between the
two"; asked: existing folders -> "Move them in"; the reader's cover
change -> "Reader only" (next zip, 179).
- NEW demos/common/uEpubUnum.pas: ConfigBase (%APPDATA% / Application
  Support / XDG), EpubUnumConfigFolder (<base>/EpubUnum, made),
  EpubUnumDocsFolder (Documents/EpubUnum), EpubUnumFolder(EU_BOOKS /
  EU_AUDIO / EU_TRANSCRIBED / EU_COVERS / EU_QUEUES), EpubUnumMove(App) -
  ONCE per program (marker EpubUnum-moved-<App>.txt in the settings
  folder, holding what was done): Documents/EpubBuilder renamed to
  Documents/EpubUnum (both there: children moved, a name taken left);
  Documents/EpubReader/Books' entries moved into EpubUnum/Books; the
  old settings folder <base>/<App>: files COPIED (.ini / .json / .csv
  with the old paths - Documents/EpubBuilder, Documents/EpubReader/Books,
  <base>/<App> - replaced, also JSON's \\ and '/' forms), folders
  MOVED (models, Converted, covers, steaminput). Returns the lines.
- uBuilder: SettingsFile = EpubUnumConfigFolder/EpubBuilder.ini;
  FormCreate calls EpubUnumMove('EpubBuilder') before DebugLogOpen, logs
  "folders: ..."; Docs = EpubUnumDocsFolder.
- uMain (reader): SettingsFile = .../EpubUnum/EpubReader.json;
  EpubUnumMove('EpubReader') before DebugLogOpen; BooksFolderDefault
  (non-Steam) and its fallback = EpubUnum/Books; BuilderOutputFolder
  reads EpubUnum/EpubBuilder.ini (else the old one), default
  EpubUnum/Transcribed. Steam builds' Books beside the program unchanged.
- dpr / dproj (both): uEpubUnum. READMEs (both): the folders.
NOT COMPILED.

## Zip 177 (on top of zip 176): covers - chosen, the audiobook's, Covers folder; zip 175 compile fix
Owner 2026-11-20 12:02 - 12:13: the MOBI's cover was Word 2000's logo
(EXTH 201 = 0 -> its first picture, 680 x 510, a calibre 2.30 file; the
date 0101-01-01 is calibre's "none"). "ok [the audiobook's], but also let
user change cover art e.g. by transferring image to builder in
EpubBuilder\Covers"; "The user could pick from the options - show a
thumbnail and let them choose". Zip 175 compile: uLink(1249) E2250
TIdHTTP.Get(url, encoding) (no such overload here) -> Get into a
TStringStream (UTF-8); uInhibit(294) W1002 'delayed' -> {$WARN
SYMBOL_PLATFORM OFF/ON} around SetProcessInformation.
- lib/Epub.Writer: TEpubWriter.SetCover(bytes, ext jpg/jpeg/png/gif/webp);
  TSaveJob.CoverPath ('<pkg>/epubunum-cover.<ext>', FreePath) + CoverId
  (FreeItemId 'eu-cover'): meta name=cover removed and written anew, the
  old item's 'cover-image' property taken off, a new item
  properties="cover-image" (CoverMediaType), the bytes stored.
- lib/Epub.Mobi: W3cDate - years < 1000 are no date.
- NEW demos/EpubBuilder/src/uCovers.pas: PictureType, PictureSize (JPEG
  SOF, PNG IHDR, GIF, WebP VP8/VP8L/VP8X), AudioCover (MP4 moov/udta/
  meta(+4)/ilst/covr/data(+8); ID3v2.3/2.4 APIC, front cover first, not
  unsynchronised; FLAC block 6), ChooseCover(folder, names, book cover,
  audio, AChoice, ...) - choice 'book' / 'audio' / a path, else: Covers
  folder by name, else audiobook's when no cover or wider than high,
  else the book's; CoverOptions (book's, audiobook's, Covers pictures -
  named first, max 30), CoverChoiceText.
- NEW uCoverPick.pas: TCoverPicker - overlay (TRectangle dimmed, panel,
  TFlowLayout tiles: TImage Fit + caption; Automatic tile first), frame
  on the chosen (pad Move / Choose / Hide), click a tile = choose.
- uBuilder: FCoverFolder (Documents/EpubBuilder/Covers, [Folders]
  Covers, made at start), GCoverFolder (set before a build),
  TBuildJob.Cover (queue JSON "cover"), FCoverChoice (job from / to the
  window; ClearBook ''), TBuildThread.CoverChoice; Execute: book's cover
  bytes (Book.Zip.ReadBytes(CoverPath)) -> ChooseCover -> Log ->
  Writer.SetCover. Cover... button (book row), ShowCoverPicker (book via
  BookAsEpub; audio from lbAudio); Big Picture: BPC_COVER = 16 on the
  home list when a book is chosen; PadPress routes to the picker while
  it shows. Link: kind 'cover' (COVER_EXTS) -> FCovers (SetFolders
  gained ACovers); received cover logged.
- README (builder): "The cover".
NOT COMPILED.

## Zip 176 (on top of zip 175): audiobook marks found by time (Epub.Book)
Owner 2026-11-20 11:59: The Sword of Shannara (from the MOBI, zip 171)
built at 37.4x, exact 99.1 %, matched 99.8 % - but EpubReader showed no
chapters, only "End Credits", which played and stopped. Cause: the title
page's words were read in the end credits ("9 words moved, at
26:21:16.790"), so the book's FIRST clips start at 26:21; AudioChapterWords
searched the clips in reading order for the first ClipBegin >= the
mark's start - clip 0 for all 37 marks -> one word, BuildChapters' "of
two marks on one word the later is kept" -> "End Credits" only.
- TEpubBook.AudioChapterWords: per mark, the clip of its audio file with
  the SMALLEST ClipBegin >= start - 0.25 s, anywhere in the book (audio
  files numbered once: FileOf). O(marks x clips) - 37 x 228k, fine.
- Expected now: 37 marks -> the audiobook's chapters; "End Credits" at
  the title page (its words were read there), first in the list.
NOT COMPILED.

## Zip 175 (on top of zip 174): the link - builder side (uLink)
Owner 2026-11-20 11:06 - 11:22: Delphi App Tethering is not on Linux
(System.Tether.Manager missing - FMXLinux issue 261; Embarcadero lists
Windows / OS X / iOS / Android) - so our own. Wanted: Reader gets local
copies of the books made; a BookManager desktop app - a DROP TARGET
(book -> Books, audio -> Audio, folder -> each file to its place),
receives the books made, real-time progress and logs (a tab); SPACE-
AWARE (never fill the build drive); TSteamAPI's remote logger was "hard
to connect to" - so nothing typed. Defaults taken (owner did not say):
pairing with a code; order link + builder, BookManager, reader.
- NEW demos/common/uLink.pas (Indy): LINK_DISCOVERY_PORT 47820 (UDP
  broadcast every 2 s, a JSON line: link, app, name, id, port),
  LINK_HTTP_PORT 47821 (+9), LINK_RESERVE 2 GiB. TLinkServer (TIdHTTPServer;
  TLinkAnnouncer thread): /info (no token), /pair + /pair/confirm (6-digit
  code, 5 min, 5 tries; token = GUID hex; token=name lines), then token
  (X-Link-Token) for /space, /books (EPUBs in the outputs), /book?path&
  offset (MayGet: an .epub inside an output folder), /upload/check and
  /upload (headers X-Link-Kind / Name / Dir / Size, X-Link-Upload: 1 on
  the real one: OnCreatePostStream -> TLinkPartStream (.part, renamed
  when whole) or TLinkRefusedStream (reason; body dropped); SafeName /
  SafeDir; same name other size -> 'name (2).ext'), /status, /log?from.
  QueryValue (Params, else QueryParams). Events queued to the main
  thread. TLinkFinder (TIdUDPServer, ReuseSocket rsTrue; peers seen in
  10 s). TLinkClient (TIdHTTP; Download resumes a .part; Upload checks
  first). LinkFreeSpace (GetDiskFreeSpaceEx / Posix.SysStatvfs statvfs -
  _statvfs, f_bavail * f_frsize), LinkKindOf.
- uBuilder: FLink; StartLink after RestoreQueue (settings [Link] Id -
  made once - and Paired = tokens '|'-joined); UpdateLinkFolders (books,
  audio; outputs: FOutFolder, the jobs' output folders, the cards'
  Transcribed) also from SaveSettings; UpdateLinkStatus (busy, queue,
  job, title, percent, time, now, speed) from ShowStatus and
  UpdateControls; LogLine / ThreadLine / WindowLine -> FLink.AddLog;
  LinkPairCode (WindowLine + Ask box), LinkPaired (settings), LinkReceived
  (log). FormClose frees it. The close question no longer says the work
  is lost (parts kept since zip 169). dpr / dproj: uLink.
- README (builder): "The link".
NEXT: BookManager (drop target, transfers, progress + log tabs), then
the reader's "Get books from EpubBuilder". NOT COMPILED (Indy APIs and
Posix.SysStatvfs's names from memory - check).

## Zip 174 (on top of zip 173): Epub.Mobi hints
Owner 2026-11-20 10:47: packages EpubUnum / EpubUnumFMX / dclEpubUnumFMX
BUILT (Linux64, Win64) with zip 171 - only H2077 for HeaderLen and
ExthFlags (Epub.Mobi.pas 1155 / 1157: set to 0, then only read inside
the MOBI-header block that sets them). The two first assignments taken
out. The MOBI still not in the books list: build of the program /
Steam deploy to be checked (debug log asked).

## Zip 173 (on top of zip 172): books found in any letter case
Owner 2026-11-20 10:40: "mobi isn't listed in the books list" (which
list and which build not known yet - asked; zip 171 needs the EpubUnum
package rebuilt). Made sturdier anyway: BookFilesIn takes every file
and keeps .epub / MOBI_EXTS by SameText / IndexText (TDirectory's
patterns are case-sensitive on Linux); the Choose dialog's filter has
upper-case patterns too; Big Picture's empty list says "No EPUB or MOBI
files". NOT COMPILED.

## Zip 172 (on top of zip 171): a book built leaves the queue
Owner 2026-11-20 10:25: 4 books in the queue, all transcribed - "If a
book has been transcribed it's no longer queued, it's done."
- RunNextJob, at the queue's end, after WriteQueueReport: jsDone jobs
  deleted from FJobs (FEditJob -1), logged "N book(s) built: out of the
  queue (the queue report lists them)", ShowJobs (-> KeepQueue).
- LoadQueue (Load... and the kept queue at start): a job saved "done" is
  not queued - WindowLine "Built already, so not queued: ...". So his 4
  go at the next start. The saved queue file itself keeps its "done"
  states (written after each job) - loading it queues the others only.
- README (builder): Run queue, Update job, Load..., the kept queue.
NOT COMPILED.

## Zip 171 (on top of zip 170): MOBI -> EPUB 3 (lib Epub.Mobi)
Owner 2026-11-20 10:12: "Can we transcribe mobi -> epub3?", then a
copyrighted sample (The Sword of Shannara .mobi - NEVER committed,
uploaded or quoted). The sample: BOOKMOBI, PalmDOC compression (2),
encryption 0, MOBI header version 6, UTF-8 (65001), 364 text records,
1489959 bytes of HTML, no KF8 boundary, 2 JPEG records + FLIS/FCIS/EOF,
HTML only p / br / font / tt / mbp:pagebreak (28 pages; the last holds
several chapters - the file has no more page breaks), p with height /
width / align, no filepos, no img. A Python port of the Pascal text path
(no FPC here) decoded exactly 1489959 bytes and gave 28 documents, all
well-formed XML, ~229k words.
- NEW lib/Epub.Mobi.pas (framework-free; in EpubUnum.dpk / .dproj and
  tools/gen_projects.py LIB): MobiIsMobi (BOOKMOBI / TEXtREAd at 60),
  MobiToEpub(mobi, epub, out TMobiInfo), MobiInfoText. Palm database
  offsets; record 0: compression (1 / 2; 17480 HUFF refused), encryption
  (<> 0 refused: DRM), text length / records; MOBI header: encoding,
  version (>= 8 = KF8 only: refused), full name, first picture (108),
  EXTH flags (128), extra data flags (0xF2) - trailing entries
  (WithoutTrailing, calibre's rule); EXTH 100 / 101 / 103 / 104 / 106 /
  121 / 201 / 503 / 524. PalmDocUnpack. WithAnchors: filepos targets get
  <a id="fpN"> in the raw bytes (moved to a tag's '<'; named by the link's
  N). SplitPages at <mbp:pagebreak> (body only). CleanHtml: KEEP_TAGS,
  MAP_FROM / MAP_TO (font -> span, tt -> code, center -> div ...), a
  stack (blocks close an open p, li closes li), align / width / height ->
  style (CssSize), filepos -> href '#fpN' then 'docNNNN.xhtml#fpN',
  recindex -> images/imageNNNNN.ext. Empty pages left out. DocTitle =
  first words (60). EPUB 3: OEBPS/content.opf (identifier urn:isbn or
  urn:epubunum:mobi:<crc32>-<size>, dcterms:modified, cover-image,
  meta epubunum:converted), nav.xhtml, style.css, text/docNNNN.xhtml,
  images/. TEXtREAd: a paragraph per line.
- uBuilder: MOBI_EXTS; BookAsEpub (Converted/<name>.epub beside the
  settings, made again when the MOBI is newer; .new then moved) used by
  ShowBook (note in mmBook) and TBuildThread.Execute (logged);
  BookFilesIn (EPUB + MOBI) for Big Picture's books and cards; the
  Choose dialog's filter.
- READMEs: root (Epub.Mobi), builder ("MOBI books").
NEXT (not done): KF8 / AZW3 (skeleton / fragment / FDST rebuild), HUFF/
CDIC; the reader could open MOBI the same way. NOT COMPILED.

## Zip 170 (on top of zip 169): the time left leaves out sleep
Owner 2026-11-20 09:22 - 09:26, Steam Machine, build 08:51 (zip 169),
Project Hail Mary, Steam sleep 1 min. ZIP 169 WORKS: Game Mode found
(XDG_CURRENT_DESKTOP=gamescope); "logind sleep delay (fd 32); listening
for PrepareForSleep"; 7 sleeps, each "Paused" within 0.5 s, delay given
back, real s2idle suspends (journal), "Going on" at the wake; Vulkan fine
after every resume (parts 2 - 9 at their usual speed); "Paused for the
system's sleep: 00:12:58 in all"; Cancel kept parts 1 - 9 (partial json
uploaded, 4.6 MB). The loop the owner saw: Steam asks logind to suspend
(dbus-send) ~1 min after each wake - its timer counts from the last
input, not the wake; several wakes 3 - 5 s after suspend entry came from
outside the program (the pad dropping and coming back each time: "pad: 0
controller(s)" right after) - not the program's doing. The time left
climbed: ShowStatus measures from FRateFrom by the wall clock.
- tmSleepTimer: FSleepWall at going to sleep; at the wake FStarted,
  FRateFrom (when FRatePercent >= 0) and FAfterFrom move on by the gap.
- README: the time left; the timer counting from the last button.
NOT COMPILED.

## Zip 169 (on top of zip 168): Game Mode - sleep paused for; parts kept
Owner 2026-11-20 03:41 - 03:57, Steam Machine, build 03:32 (zip 168):
SLEEP black again, "hands off"; log: "redraw: displays (none read)" (the
Steam runtime container shows no /sys/class/drm connectors - the display
check is useless in Steam builds), nothing else heard. The 03:40
SteamShutdown_t was the owner restarting Steam. Owner: refusing sleep is
the issue - black screen or a Steam menu that does not work, only
restarting Steam / rebooting helps; a frame of the build flashed when
sleep began. His idea, approved ("go ahead"): let it sleep, carry on
after; warn when the queue will not finish before the sleep.
- uInhibit: GameModeSession(out Why) (XDG_CURRENT_DESKTOP gamescope,
  GAMESCOPE_WAYLAND_DISPLAY, SteamGamepadUI=1); InhibitSetPauseForSleep
  / InhibitPauseForSleep; in that mode ikSleep (ikDisplay 0) takes logind
  Inhibit("sleep", ..., "delay") instead of "sleep:idle" block, and
  dbus_bus_add_match PrepareForSleep (AddSleepMatch; GMatched).
  InhibitPoll (main thread): dbus_connection_read_write(0) +
  pop_message + is_signal -> ssGoingToSleep (GAsleep) / ssWoke (Apply('')
  takes the delay again; GReason kept). InhibitLetSleep closes the fd.
  New libdbus imports: dbus_bus_add_match, dbus_connection_read_write,
  dbus_connection_pop_message, dbus_message_is_signal.
- uBuilder: GSleepGate (TEvent, manual, set; initialization /
  finalization) + GBuildPaused. TBuildThread.PausePoint (never on the
  main thread): waits at the gate, logs "Paused ..." / "Going on after
  the sleep (paused ...)", adds FPausedSeconds. Called in RunProgress,
  RunSegment and before each part. DecideSleepMode (AfterShow):
  GameModeSession, else SteamBigPicture on Linux. tmSleep (250 ms) ->
  tmSleepTimer: going to sleep -> gate reset, wait for GBuildPaused (or
  3.5 s, or no build) -> InhibitLetSleep; woke -> gate set, FRedraw.Kick;
  no wake news 120 s of the program's own clock after letting it sleep
  -> gate set anyway.
- Parts kept: PARTIAL_SUFFIX '.transcript-partial.json' (PartialFileOf),
  keys builder_model / builder_parts_done / builder_language /
  builder_seconds; SavePartial after each part (written .new then
  moved); ReadPartial at Transcribe's start (same model, same parts) ->
  goes on from part Done+1, Params.Language from it when auto. Deleted
  after SaveTranscript. TranscribeSeconds = FPriorSeconds + this run -
  FPausedSeconds (history speed right); part lines minus pauses. SIGTERM
  text: "the parts already transcribed are kept".
- QueueSleepNote (Run queue, pause mode only): each waiting job's audio
  length (TWhisperAudioSet on the main thread) x PrepareEstimate ->
  "This queue takes about ..."; Tell in Big Picture, else LogLine.
  Steam's sleep time itself is not read (not known where, nor whether
  the container can see it).
- README (builder): "Steam's Game Mode: the build pauses for sleep", "A
  build stopped part way goes on from there", the SIGTERM paragraph.
TEST (owner): Game Mode, a queue, Steam sleep short: the log at start
says Game Mode (which variable); Run queue note; sleep -> "Paused";
wake (button) -> "Going on", the window shown; the build ends with a
good speed. Exit Game mid-book, start again, Run queue -> "GOING ON FROM
PART n". NOT COMPILED.

## Zip 168 (on top of zip 167): uRedraw - displays read, full screen
Owner 2026-11-20 03:15 - 03:29, Steam Machine, build 03:07 (zip 167),
Big Picture, a queue running, one Steam timer at a time:
- screen saver: came back (idle and during a build); dim: never dims
  during a build (the logind sleep:idle inhibitor); SLEEP: black - the
  culprit. Debug log of the sleep test: NO "redraw:" line between the
  start and Exit Game (SIGTERM 03:26:55) - no deactivate / activate, no
  pad press reached the program, no displays line at all; the status line
  changed every ~0.6 s throughout (the program drew all the time). The
  screen saver test's log: "a pad press after 280 s" Kick at 03:23:16,
  "window 1920 x 1080 ... full screen True" - so no size change was made.
- ReadDisplays: TDirectory.GetFileSystemEntries (the /sys/class/drm
  entries are symlinks: GetDirectories gave none); none read ->
  '(none read)', logged once (FDisplays '' only before the first tick).
- Kick: FullScreen -> FullScreen := False, 500 ms later True (FUnFull);
  normal -> the 1-pixel size change as before; maximized -> nothing.
  FRestoreTimer 500 ms. FLastKick = creation time (the first activation
  at start-up does not toggle full screen).
- READMEs (both): the full-screen sentence.
OPEN: Steam's sleep timer, blocked by the inhibitor, leaves Game Mode
black and the program hears nothing - possibly Steam's own suspend
sequence. Candidate: org.freedesktop.ScreenSaver.Inhibit during builds
(the reader's ikDisplay) so Steam's timers do not run - owner to decide
(keeps the screen on). NOT COMPILED.

## Zip 167 (on top of zip 166): Linux - the window brought back (uRedraw)
Owner 2026-11-20 02:58 / 03:02, the Steam Machine, a build from 02:46
(so WITH zip 164): screen saver, then BLACK on return again - drawing the
whole window every 2 s (Invalidate) is not enough for gamescope.
- NEW demos/common/uRedraw.pas (both programs' dpr / dproj):
  TWindowRedraw (owned by the form; does nothing off Linux - REDRAW_ON).
  Every 2 s: Invalidate; reads /sys/class/drm/card*-*/{status,dpms} of
  the connected displays - a change logged ("redraw: displays
  card0-HDMI-A-1=On"), Off -> On = Kick; a tick > 10 s late = Kick.
  Kick (not more than once in 2 s): logged with the window's size,
  Active, WindowState, FullScreen; Invalidate; SetBounds height - 1, then
  300 ms later back (a new frame of a new size). No size change when
  maximized / full screen (the log line says which).
  Activated (OnActivate) = Kick; Deactivated (OnDeactivate) = a log line;
  UserInput (each pad press, both programs) = Kick when the last press
  was > 60 s ago.
- uBuilder / uMain (reader): tmRepaint / tmRepaintTimer gone -> FRedraw;
  FormDeactivated new. READMEs (both) a paragraph.
TEST (owner): screen saver / display off during a build, come back; the
debug log's "redraw:" lines say what was heard (display off/on, active /
not active, a pad press) and the window's state. If still black: send the
debug log. NOT COMPILED.

## Zip 166 (on top of zip 165): queues - a folder, kept, Big Picture
Owner 2026-11-20 02:39 "Where do queues go? How do I load one?" -> 02:40
"Yes do that" (my proposal):
- FQueueFolder: default Documents/EpubBuilder/Queues, made at start,
  [Folders] Queues in the settings; Save... / Load... open there (made
  first) and keep the folder used.
- KEPT QUEUE: ShowJobs (every change of the queue shows there) calls
  KeepQueue -> SaveQueue(KeptQueueFile = <settings>-queue.json, i.e.
  EpubBuilder-queue.json beside EpubBuilder.ini; deleted when empty).
  FormCreate (after the folders) RestoreQueue: LoadQueue of it (FRestoring
  - no keeping meanwhile), ShowJobs, "The queue from last time: N job(s),
  M waiting". A job saved "running" (a crash) loads waiting (LoadQueue's
  else).
- Big Picture's Queue list: "Save queue" (PadSaveQueue: queue-yyyy-mm-dd-
  hhnn.json in the queues folder; FQueueFile; Tell) when there are jobs;
  "Load a queue ..." (PadQueues, BPM_QUEUES: the folder's *.json newest
  first, value the time; FPadBooks holds the files; choosing LoadQueue -
  ADDS - ShowJobs, Tell "N job(s) added").
COMPILE (owner 02:40): E2003 ShowText - the build had an OLDER
demos/EpubReader/src/uPadMenu.pas (zip 162's has ShowText): included
again here. Hints: uMachine.MachineMemory H2077 (Linux) - Result := 0
only on the platforms that need it; uModels H2443 x6 - Posix.Unistd,
Posix.Stdio in its implementation uses ({$IFDEF POSIX}); H2219 cbGpu off
Windows - the field in {$IFDEF MSWINDOWS}. README (builder): Job queue.
NOT COMPILED.

## Zip 165 (on top of zip 164): the window emptied after Add to queue
Owner 2026-11-20 02:32: "When a job is added to the queue the book +
audio fields should reset to blanks ready for adding another book". New
ClearBook (mmBook, FBookTitle / WrittenBy / Clips, edBook, lbAudio, edOut,
FAutoOut, chkReuse off, SelectLanguage(''), FEditJob -1 - Update job off
until a job is clicked), called by AddJob after a NEW job (not Update
job's replacement, which keeps the window). Model, device, power,
chapters kept. Big Picture's home list then shows Book / Audio "choose
..." with Run queue selected. README (builder): Job queue. NOT COMPILED.

## Zip 164 (on top of zip 163): Linux - the window drawn whole
Owner 2026-11-20 02:22 - 02:25, the Steam Machine, Steam timers at 5 min
for dim / screen saver / sleep, a build running: the screen went blank
but the machine STAYED AWAKE - zip 114's question answered: SteamOS Game
Mode HONOURS logind's Inhibit("sleep:idle", block) (the transcription
went on). But on waking the display the app stayed BLACK, and Steam
button > Resume Game black again: gamescope shows a woken display's
window black until it draws all of itself; FMX draws only what changed
(the status line - too small to notice). Both programs (Linux only):
tmRepaint (2 s) -> Invalidate (the whole window), and OnActivate ->
FormActivated -> Invalidate. tmRepaint / tmRepaintTimer declared in
{$IF Defined(LINUX) and not Defined(ANDROID)} (no H2219 elsewhere).
TEST (owner): screen blanks during a build; wake it - the window within
two seconds; Steam button > Resume Game - at once. The reader the same
when idle. NOT COMPILED.

## Zip 163 (on top of zip 162): "Transcribed"; memory cards
Owner 2026-11-20 02:12: the builder's output folder named "Transcribed"
("OK for shared use with Reader"); "Steam hardware also makes use of SD
Cards so we should allow for books on SD Card" - asked: TOP-LEVEL card
folders (<card>/Books, /Audio, /Transcribed); a card's book: ASK - back
on the card or local.
- NEW demos/common/uCards.pas (both programs' dpr / dproj): CardVolumes
  (Linux: /run/media/$USER/* - SteamOS 3.5+ - and /run/media/* holding
  one of the folders - older; others none), CardFolders(name) (those that
  exist), CardOf(file), CardName. Only those folders, never the whole
  card.
- Builder: default output Documents/EpubBuilder/TRANSCRIBED (saved
  settings keep theirs). PadBooks adds each card's Books (value "card
  <name>"); PadAudioCandidates searches the audio folder and each card's
  Audio (names "<card>: <path>"). AskOutputPlace(book, then): a card's
  book asks "Put the transcribed book back on the card (<card>/
  Transcribed)? No keeps it on this machine" (Yes default; edOut and
  FAutoOut set) - from the BP book list (then the audio list) and the
  desktop's Choose... (after ShowBook).
- Reader: BuilderOutputFolder's default .../Transcribed; ShowBooksMenu
  adds the cards' Books and Transcribed ("<card>: <book>", Transcribed
  ones "made by EpubBuilder").
READMEs: builder Folders (Transcribed) + Memory cards; reader Books
folder. NOT COMPILED.

## Zip 162 (on top of zip 161): the pad menu's texts fill the width
Owner 2026-11-20 02:06 (the Deck, a download question): "Bad design still
- text should fill width" - even at 34 characters the lines were cut:
every row kept its value column (FFontSize * 8 wide, 240 px at 30 pt)
when empty, so a row's text had ~420 of the box's 720 px.
uPadMenu (reader's, shared): a row without a value hides its value
label (its text gets the whole row - every list); new ShowText(ATitle,
AText, AItems, ASelected, AFoot): FBody, a word-wrapped label under the
rule, the box as wide as the window allows (BOX_SHARE), its height
measured with a TTextLayout at that width (FMX.TextLayout); the items -
the answers - below. uBuilder.Ask: ShowText with the question's text
and only the answers (PadWrap and BP_ASK_WIDTH gone; FAskResults /
FPadCmds hold the answers only).
RESULTS (01:27, the Steam Machine, Vulkan0, large-v3-turbo, build
bc9b291, TV switched away most of the time): Death's End 29:11:36 of
audio in 43:08 (+ 5.8 s), 40.6x (calibration 28.87x: ratio 1.41);
exact 98.69 %, matched 99.59 %. The Steam Machine's best; ranking
(large-v3-turbo, whole books): 5090 Vulkan ~86x, Steam Machine Vulkan
~40x, M4 Core ML ~27x, M4 Metal ~17x. NOT COMPILED.

## Zip 161 (on top of zip 160): zip 160's compile errors
Owner 2026-11-20 01:10: E2004 'L' redeclared in BuildWindow (zip 160 added
a var L - there was one): the second removed. E2250 ForceQueue in
FormShow AGAIN (zip 149 took StartPad out of the anonymous method and it
came back): FormShow now queues a METHOD - TThread.ForceQueue(nil,
AfterShow), the TThreadMethod overload - with AfterShow (new) doing the
debug log's screen line and CheckCalibrationAtStart. Cause of the
anonymous method's rejection not known (possibly a cascade: both times
another error came first). H2219 cbGpuChange unused off Windows: its
declaration and body in {$IFDEF MSWINDOWS}. NOT COMPILED.

## Zip 160 (on top of zip 159): a progress panel in the log's place
Owner 2026-11-20 01:04: "little point in having a debug output window for
transcription" - asked: PROGRESS PANEL, LOG ON DEMAND; the live-text line
("Part 4 of 10 at ...: words") KEPT. uBuilder: layProgress (TLayout,
Client, in layBottom with mmLog - one of them visible): lblPTitle (26 pt
bold: the book / Calibrating / Downloading / Idle), lblPJob ("Job N of M
in the queue" / "The book in the window" / "N job(s) waiting - Run
queue"), lblPTime ("NN %  -  <taken, about ... left>" - ShowStatus keeps
FTimeText; the calibration's / download's status), lblPSpeed ("NN.Nx
real time so far" - FSpeedNow = 1 / ShowStatus's Own rate). Idle: the
last result (RecordHistory sets FLastResult: title, speed, matched).
UpdatePanel from ShowStatus (every second while building) and
UpdateControls. View menu (new, before Tools): Show the log (miLog,
checked) - SetLogVisible, [View] Log in the settings (default off).
README (builder): Progress, and the log. NOT COMPILED.
ALSO (00:57, the Steam Machine, TV switched to another input, Vulkan
large-v3-turbo): parts 30 - 34 at 38.0 - 40.6x - Game Mode does not slow
it with the screen off (no App Nap equivalent); htop: nice 0, load 0.8.

## Zip 159 (on top of zip 158): the reader lists EpubBuilder's output
Owner 2026-11-20 00:49: "The output folder of builder should be one of
the default locations Reader looks in". uMain (reader): new
BuilderOutputFolder - EpubBuilder's settings file (the same place as its
uBuilder.SettingsFile: %APPDATA% / ~/Library/Application Support /
$XDG_CONFIG_HOME or ~/.config, + EpubBuilder/EpubBuilder.ini), [Folders]
Output, else Documents/EpubBuilder/Output. ShowBooksMenu (Open a book)
lists its *.epub too (all folders; a file in both once; not when it is
the books folder itself), sorted with the rest by the name shown (its
path in its own folder), value "made by EpubBuilder"; the foot says
"<books folder>  +  EpubBuilder's output"; the debug log names both.
Keep BuilderOutputFolder in step with uBuilder.SettingsFile / the
builder's default output. README (reader): Books folder. Owner also
called Big Picture's builder interface "a disaster" (00:43) - a redesign
proposed (Add a book wizard / Start the queue / Queue / Settings / Exit,
status at the top); waiting for what hurt most. NOT COMPILED.

## Zip 158 (on top of zip 157): Run queue on Big Picture's home list
Owner 2026-11-20 00:41 / 00:43: "How do I start the queue?" ... "Ahh -
not obvious" (it was View, or Queue > Run queue). Now BPC_RUN on the home
list whenever btnRunQueue is enabled (its text), before Queue; after Add
to queue / Update job the home list comes back with Run queue selected.
README (builder): Big Picture's list.
ZIP 157'S CAUSE FOUND (00:40 screenshot): the "only one book" was the
SAME book added again - "Job 1 of the queue writes .../Output/Death's End
- Cixin Liu.epub already" three times in the log, as designed; invisible
in Big Picture until zip 157's Tell.
RESULTS - the STEAM MACHINE (host name "steamdeck"; "AMD Steam Machine
(RADV NAVI33)"), calibration 2026-11-20 00:30, large-v3-turbo, Steam
build bc9b291: CPU 1.1x, ROCm0 27.3x, Vulkan0 28.9x - Vulkan chosen
(Vulkan a little ahead of ROCm here, as the 23:56 / 23:44 books were
close; ROCm out of the Linux depot costs nothing on this machine).
Default folders /home/deck/Documents/EpubBuilder/{Books,Audio,Output}.
The keep-awake on Linux: "letting the computer sleep: logind inhibitor
released; speed: the speed is left to the system here" (zip 142's Linux
line). NOT COMPILED.

## Zip 157 (on top of zip 156): Big Picture says why it refused
Owner 2026-11-20 00:37 (the Deck, build bc9b291): "Default Folder is
/home/deck/Documents/EpubBuilder/Books etc" (confirmed, zip 153) and "Only
possible to add one book to queue" - cause NOT KNOWN yet (asked for the
window's log after the refused add). Whatever it is, the check chain's
refusals (CheckThen .. CheckOutputThen: the output is the book, no model,
a calibration failure declined, not the original EPUB, a job writes this
output already, an existing output kept) went to the window's log only -
behind the pad menu, so Big Picture showed nothing. New Tell(AText):
WindowLine, and in Big Picture also Ask(AText, OK) in the pad menu; the
six WindowLine calls of the chain use it. NOT COMPILED.

## Zip 156 (on top of zip 155): no model - Big Picture opens on the models
Owner 2026-11-20 00:23: "if there are no models first thing to show is
model list". StartPad (Big Picture): when no FModelItems file exists,
PadModels instead of PadHome (B / choosing goes on to the home list as
before). With zip 154 the calibration question follows the first
download. NOT COMPILED.

## Zip 155 (on top of zip 154): Big Picture's model list
Owner 2026-11-20 00:17 / 00:18 (the Deck): "It only offers me tiny as a
model download", "then base.en" - left / right turned cbModel one step,
and its OnChange asked to download every model passed (tiny, then
base.en ...): large-v3-turbo could not be reached. Now the Model row's A
opens BPM_MODELS (PadModels): every cbModel item but "Other model file
..." (a file dialog), the name and what its brackets say ("1.6 GB to
download", "Core ML", ...; "here" / "in the models folder"), the current
one selected, foot "large-v3-turbo: accurate and fast - a good first
choice"; choosing sets cbModel.ItemIndex once (its OnChange: taken, or
the download question in the menu). Left / right no longer turn the
model. The home row shows "choose ..." with none. README (builder): Big
Picture's Model. NOT COMPILED.

## Zip 154 (on top of zip 153): no calibration question without a model
Owner 2026-11-20 00:16 (the Deck): "It hasn't actually got any models to
calibrate yet" - the start-up question came with an empty Model list
("the model you choose next"); Yes would only have logged "choose a
model first". Now CheckCalibrationAtStart, with FModelPath = '': logs
that a model is needed (large-v3-turbo first; downloaded when chosen),
sets FCalibPending, asks nothing. The question comes when the first
model is here: DownloadDone (succeeded) or cbModelChange (a model file
already there, unless the Core ML encoder question was asked then), if
no calibration / build runs - CheckCalibrationAtStart again, now with
the model (DontAsk still honoured; desktop dialog / Big Picture menu as
before). NOT COMPILED.

## Zip 153 (on top of zip 152): Big Picture questions readable
Owner 2026-11-20 00:14, Steam Deck screenshot (build 2026-11-19 23:41,
bc9b291): the start-up calibration question in the pad menu - every line
cut short with "..." (BP_ASK_WIDTH 60; the box at font 30 holds ~35
characters), the desktop's long explanation a screenful. Now
BP_ASK_WIDTH = 34, and CheckCalibrationAtStart's Big Picture text is
short: not calibrated yet; Calibrate now? (the model, the devices, a
minute or two each, then the fastest); later: Calibrate (this model).
ALSO SEEN: Linux's TPath.GetDocumentsPath is ~/Documents - the Deck's
log: "Folders: books /home/deck/Documents/EpubBuilder/Books, audio
.../Audio, output .../Output" (defaults: no [Folders] in that machine's
EpubBuilder.ini; the Steam Machine has /home/deck/Books/epub and m4b
saved). The README's Documents/EpubBuilder is right on Linux too.
Big Picture start-up works: "Big Picture: the pad drives EpubBuilder"
logged, the question shown with the pad's foot "A answer   B no".

## Zip 152 (on top of zip 151): Linux deploys without ROCm and CUDA
Owner 2026-11-19 23:28 "For Linux we're skipping rocm + cuda": the
Linux64 deploy is `python tools/deploy_redist.py --skip-rocm --skip-cuda`
(CPU + Vulkan in the base depot; ROCm as the HIP DLC from steam_stage.py;
no CUDA on Linux for now). notes/Building-distributions.md part 1's table
and part 7's command say so. No code change.

## Zip 151 (on top of zip 150): deploy_redist.py --skip-rocm / --skip-cuda
Owner 2026-11-19 23:25 "deploy_redist needs a skip param" - asked: "skip
hip + roc for Linux". --skip REGEX existed; new --skip-rocm and
--skip-cuda leave out every file of that part, from steam_stage.py's
read_parts (Linux64/parts.txt, else NAME_RULES by name; imported inside
main - steam_stage imports deploy_redist; the tools folder put on
sys.path first): a listed name, or anything under a listed folder
(rocblas/, hipblaslt/). Prints how many were left out. The own folders
(steaminput) are not affected. Tested here on a made-up tree: the hip
library, amdhip64, rocblas/ and the ROCm licence left out, the rest and
both programs' steaminput entries written.
notes/Building-distributions.md part 7: the --skip-rocm deploy.

## Zip 150 (on top of zip 149): steaminput in every build
Owner 2026-11-19 23:20 "why have no builds got steaminput". Found:
postbuild.bat copied demos\EpubReader\steaminput only for EpubReader,
and only after the FFmpeg check (no redistributable_bin\Win64 -> jumped
to nolibs first); EpubBuilder never; deploy_redist.py's OWN_FOLDERS had
the reader only (Linux); macOS never (Deploy writes inside the bundle;
the programs write it beside the .app at run time under Steam only).
Steam reads a bundled configuration from the depot, possibly before
either program runs. Now: postbuild.bat calls :steaminput for both
programs, every configuration, BEFORE the libraries' check (the reader's
branch no longer calls it). deploy_redist.py: OWN_FOLDERS for
EpubBuilder.dproj too ("..\EpubReader\steaminput\" -> steaminput) -
RERUN `python tools/deploy_redist.py` (Linux64) with the projects closed.
notes/Building-distributions.md: the builder's steaminput in part 1's
table, the Steam Input row says where each build gets it, part 10: the
Mac depot gets demos/EpubReader/steaminput beside the .app by hand.
NOT RUN here (no Windows / redistributable_bin).

## Zip 149 (on top of zip 148): zip 142 / 147 / 148's compile errors
Owner 2026-11-19 23:11 (dcc64): E2001 / E2016 at the Power ini write -
an array constructor cannot be indexed (['A', 'B'][I]): new unit const
POWER_KEYS (read with IndexText). E2008 / E2149 in ShowJobInWindow -
LANGUAGES is declared further down the unit (a const section after it):
new SelectLanguage(ACode), after ChosenLanguage. E2250 ForceQueue in
FormShow - the anonymous method no longer calls StartPad: FormShow calls
it first (the calibration question, asked through the pad in Big
Picture, still comes after it). LESSON: a unit-level const is visible
only below its declaration; index a typed const, not a constructor.

## Zip 148 (on top of zip 147): EpubBuilder in Big Picture (the pad)
Owner 2026-11-19 18:31 "Can we add Big Picture mode to Builder"; asked:
FULL PAD FLOW, audio MATCHED THEN CONFIRMED.
- uBuilder.StartPad (FormShow, before CheckCalibrationAtStart): FPadMenu
  (the reader's TPadMenu, font 30 in Big Picture / 20), TSteamPad on the
  READER'S action set "Reader" (Steam Input: one manifest per app -
  ReaderInputWrite into steaminput/ beside the program, as the reader;
  else beside the settings) with Up Down Left Right Play(A) Back(B)
  Menu(Start) Library(View); no stick. Linux's mnuBar hidden in Big
  Picture (Windows' / Mac's system menus left). In Big Picture the home
  list opens at once.
- Lists (FPadMode BPM_*): HOME (Book, Audio, Model / Device / Language /
  Power / Chapters with left / right turning the combo boxes - their own
  OnChange does the rest, Output, Create, Add to queue, Update job,
  Queue, Cancel, Calibrate, Exit - only what UpdateControls enables);
  BOOKS (TDirectory *.epub of FBookFolder, all folders, by name; ShowBook,
  then AUDIO); AUDIO (PadAudioCandidates: every audio file of
  FAudioFolder (BP_AUDIO_EXTS = Add files' filter) and every folder of
  2+ files (NaturalFileOrder), scored by PadScore = share of the title's
  words (PadWords: lower case, small words out; title else file name) +
  0.01 x share of the name's; best 8 with a score > 0, "best match" on
  the first; All the audio ... (by name); Keep the list; Back); QUEUE (Run
  queue, JobText rows); JOB (Show it in the window, Up, Down, Remove).
  B one list back, Start closes, View the queue. The foot shows
  lblStatus while working (SetFoot, new in uPadMenu).
- Ask(...): the five TDialogService.MessageDialog calls (Core ML
  encoder, download, calibration failure, the book / output checks, an
  output already there) now go through it - a dialog, or in Big Picture
  the pad menu (the text in lines of 60, then Yes / No / OK / Cancel; B
  = no / cancel). CheckCalibrationAtStart asks through it in Big Picture
  (no AskCalibration dialog there). Exit while building asks with the pad;
  FForceClose skips FormCloseQuery's sync dialog.
- uPadMenu (reader): SetFoot. EpubBuilder.dpr / .dproj: uSteamPad,
  uPadMenu and uReaderInput (the reader's src) added.
- README (builder): Big Picture (a pad), at the end. NOT COMPILED.
OPEN: the reader's manifest titles say "Play", "Library" (Steam's
controller screen); a builder action set would need gen_reader_input.py
and a layout revision - not needed for the bindings. Save / Load of a
queue: desktop only. Windows' / the Mac's system menu bar stays in Big
Picture.
TEST (owner): Steam Machine / Deck in Game Mode - the menu at start;
Book -> the list; a book -> its audio matched (the Belgariad layout:
"<Book> by <Author>/<Book>.m4b" should top the list); Create; the foot's
progress; an output already there asks with the pad; Queue / Run queue;
Exit while building. Desktop: Start opens the same menu; dialogs as
before.

## Zip 147 (on top of zip 146): a click shows a job; Update job
Owner 2026-11-19 18:14: "when you load a queue clicking in an item shows
no files involved - this would be better if the fields were populated to
look the same as when the queue was saved ... allow the user to make
modifications to the output name and verify the inputs". uBuilder:
lbJobs.OnClick -> ShowJobInWindow(I, False) (the double click's code,
now shared; the double click still announces): the audio list emptied
before ShowBook (no "Another book" note per click), book, audio, model,
device, output (FAutoOut := '' - the job's own), chapters, saved
transcript, and now the LANGUAGE too (cbLanguage from LANGUAGES).
FEditJob = the job the window shows (-1 after Remove / Up / Down / Load:
numbers move). New button Update job (between Add to queue and Cancel):
enabled when Ready, FEditJob is the selected job and not running; it
sets FUpdateJob and runs the Add to queue checks (CheckThen(True));
CheckOutputThen's "a job writes this output already" skips FUpdateJob;
AddJob replaces FJobs[FUpdateJob] in place (waiting again - a done job
is built again), logs "Job N updated: ...". Add to queue resets
FUpdateJob (a new job as before). README (builder): Job queue. NOT
COMPILED. TEST (owner): load a queue, click jobs (fields as saved, the
language too), change an output name, Update job; the queue's list and
a Save show the new name; Up / Down disables Update job until a click.

## Zip 146 (on top of zip 145): the Mac save panel got a path as a name
btnOutClick set D.FileName := edOut.Text (the whole path; InitialDir its
folder). Windows' dialog takes a path there; the Mac's NSSavePanel puts
it into the NAME box, '/' becoming ':' - the owner had to rename
':Users:simon:Downloads:Pawn of Prophecy.epub' by hand (zip 145). Now
D.FileName := ExtractFileName(edOut.Text). The queue's Save dialog
already gave the name only. NOT COMPILED.
TEST (owner, Mac): Output > Choose... - the name box shows only
"<book>.epub", the folder the output's.

## Zip 145 (on top of zip 144): zip 140 (no App Nap) CONFIRMED on the M4
RESULTS (owner, M4 Mac mini, Steam build 8a9a67d + zips 139 / 140 built
14:37, Core ML turbo, the Belgariad queue 2026-11-19 14:55 - 16:58, 5
books, 54:18:09 of audio in 2:02:36 = 26.6x): pmset - display on 14:38:11,
OFF 15:06:03 - 17:59:56. Books 2 - 5 ran wholly with the display off:
26.9x, 27.2x, 26.7x, 26.3x (Pawn of Prophecy 26.5x, half on); align +
write 5 - 8 s per book (0.5 - 0.7 s per hour of audio - the fast rate;
3.2 - 3.6 with App Nap). Last night with the display off: 17.1x. The
log's keep-awake line: "IOKit assertion PreventUserIdleSystemSleep
(41971); NSProcessInfo activity (user initiated, latency critical: no
App Nap)", released at the end. Zip 140's debug-log fix: each part's
line once. Zip 139's exact_pct (front / back matter left out) in the
history: Pawn of Prophecy 97.26 (all words: 96.80). Matched 99.3 - 99.6
%, every book very good. These m4b files have no chapters: 1 part each,
0 chapter marks (as designed). Calibration re-done with the Core ML
encoder: CPU 18.3x (loading 19.3 s: the encoder compiled), MTL0 21.3x.
SOLVED in zip 146: the window's log said "Added to the queue as job 1: Pawn
of Prophecy -> :Users:simon:Downloads:Pawn of Prophecy.epub" (colons),
while the queue file and the report have the right POSIX path - the
Output field at that moment held a name with ':' (a full path typed or
pasted into the Mac save panel's name box becomes a file NAME with ':'
for '/'), then corrected? The owner (18:10): "i renamed the : bits
manually" - the builder's doing, see zip 146.
Zip 142 moves the activity to Power = Fastest (Automatic on mains) - the
same as tested here on a plugged-in Mac.

## Zip 144 (on top of zip 143): Windows on Arm - notes and probe
Owner 2026-11-19 16:24 "can the system be built on Windows ARM64ec?";
16:29: Delphi 13.2, a Win11 Arm VM in VMware on the Mac (slow), maybe a
rented Snapdragon laptop; "the new Spark machines will also feature
cuda"; 16:34: "write up the tests as a .md ... probed for Vulkan as
well". NEW notes/Windows-on-Arm.md: Delphi's Arm64EC facts (DocWiki
"Arm64EC", 13.1 / 13.2 notes: 64-bit IDE only, Win11 on Arm only, FMX
yes, Skia not documented, no BPLs, no asm, x64 + Arm64EC DLLs load, pure
ARM64 not), THE RISK: Whisper.inc's WHISPER_SRET_AS_PARAM on CPUX64 and
TSteamAPI's STEAMWORKS_CPUARM64 GetMotionData (X8) - Arm64EC needs the
x64 ABI, wrong if the compiler defines CPUARM64; routes (x64 DLLs
emulated / Arm64EC builds); GPUs (Adreno Vulkan, NVIDIA CUDA needs a
loadable nvcuda.dll, no ROCm, VM = CPU); tests 1 - 5 with steps and how
to read them; a results table; the work after (inc files, projects,
redistributable_bin\WinARM64EC, postbuild, notes). NEW
notes/Arm64ECProbe.dpr (console, not in the groupproj): compiler symbols,
IsWow64Process2, vulkan-1.dll (loaded from, PE machine, devices via
vkCreateInstance / vkEnumeratePhysicalDevices / properties read from a
buffer: name at 20, type at 16), nvcuda.dll (cuInit, driver version,
devices, memory), DLLs beside it or named (error 193 = wrong type). NOT
COMPILED.

## Zip 143 (on top of zip 142): notes/Building-distributions.md
Owner 2026-11-19 15:50: "a detailed step-by-step about creating and
collecting all the dynamic libraries and other files for creating
distributions for all platforms ... in a folder called notes ... easy to
follow on a machine having just cloned the system (so paths must not
refer to my build machine)". NEW notes/Building-distributions.md: what
ships with what (per program, platform, configuration); the machines and
their once-only setup; the clones side by side in <repos>; building
ffmpeg-dev / whisper-dev per platform (Linux in the container, its glibc
and RUNPATH checks); redist collect; the Steam SDK 1.65 files and
media/aladdin.m4a (not built, git-ignored); copying Linux64 / OSXARM64
to Windows + deploy_redist.py; the Delphi packages in order; Build +
Deploy per platform (postbuild, PAServer, redist.sh deploy without
Delphi); Steam depots (steam_stage.py, launch options, Steam Input);
release packages; checks; a problems table (F1027 dccosx64 among them).
Written from the scripts and the READMEs of this repository, whisper-dev,
ffmpeg-dev, TWhisper, TFFMpegAPI and TSteamAPI - no machine paths. Keep
it in step when a script or a deployed file changes. README Layout
points to it.

## Zip 142 (on top of zip 141): Power, Window GPU, devices by description
Owner 2026-11-19 15:31: "some people may desire power control (all
platforms) ... saving power or time"; 15:33: Windows' per-program GPU
registry key as in his other apps (at the next start).
ZIP 140 TEST so far: Pawn of Prophecy 26.5x (started 14:55:53, display
off 15:06:03 - half off: last night's rates would give ~22x; the off
half ~25x). Queen of Sorcery and the rest of the Belgariad queue (all
display off) to come - CHECK and record.
1. uInhibit: InhibitSpeed(isSystem / isFast / isSaving) apart from sleep.
   macOS: isFast = zip 140's NSProcessInfo activity (MOVED out of
   Apply: InhibitStart no longer begins it - the reader's read-aloud
   keeps the display on, so it does not need it); else none (App Nap
   allowed). Windows: SetProcessInformation(ProcessPowerThrottling,
   EXECUTION_SPEED) - control+off = full speed, control+on = EcoQoS,
   no control = Windows decides (delayed external: Windows 8+). Linux:
   nothing (renice could not be undone unprivileged). OnBattery: Windows
   GetSystemPowerStatus ACLineStatus = 0; macOS IOPSCopyPowerSourcesInfo
   / IOPSGetProvidingPowerSourceType = 'Battery Power'; Linux a
   /sys/class/power_supply Battery 'Discharging'. GpuPreference /
   SetGpuPreference: HKCU\Software\Microsoft\DirectX\UserGpuPreferences,
   value = ParamStr(0), 'GpuPreference=1;' saving / '2;' high
   performance, removed for Windows decides; other 'Name=Value;' pairs
   in the value kept.
2. Builder: row Power (Automatic / Fastest / Save power / Let it sleep;
   ini [Build] Power = Automatic | Fastest | SavePower | Sleep; default
   Automatic = Fastest on mains, Save power on battery). ApplyPower
   replaces UpdateControls' InhibitStart/Stop: logs "Power: ... - keeping
   the computer awake: ...; speed: ..." when work starts, again at each
   job's start when Automatic's answer changed (unplugged mid-queue),
   at once when the row changes while working; at the end
   InhibitStop + InhibitSpeed(isSystem). Windows: Window GPU on the same
   row (cbGpu, from GpuPreference; a change stored at once, "next
   start").
3. Devices by description: Windows' GPU preference (and drivers) can
   reorder Vulkan's list, so "Vulkan0" may become the iGPU. ini
   [Build] DeviceDescription and the queue's "deviceDescription" saved;
   DeviceMatch(name, description): the name when its description still
   matches, else the device of the same kind (letters before the number)
   and description. The calibration's per-device speeds stay by name -
   a changed device list changes its Devices key, which asks for a new
   calibration already.
4. Reader: View > Graphics (from the next start) on Windows - the three
   choices checked from the registry; ShowMessage says next start.
READMEs: builder Kept awake (Power, Window GPU), reader Graphics.
NOT COMPILED - SetProcessInformation's delayed external, the IOPS calls
and TRegistry are untested here.
TESTS (owner): Windows laptop - Window GPU Power saving, restart: the
Device still the RTX (by description), the log's Power line; Automatic
unplugged -> Save power at the next book. Mac: Fastest / Save power on
one book each with the display off (~27x / ~17x).

## Zip 141 (on top of zip 140): the Mac Steam reader's folders beside the .app
Owner 2026-11-19 15:04: the Mac Steam build's books beside
EpubReader.app, as steaminput (he puts it there by hand). uMain: new
ProgramFolder - ParamStr(0)'s folder, on the Mac the folder holding the
.app when it is .../X.app/Contents/MacOS (the signed bundle is never
written to; the folder holding it is Steam's install folder, Manage >
Browse local files). BooksFolderDefault: every STEAMBUILD (the Mac too)
ProgramFolder/Books; other builds Documents/EpubReader/Books (as
before). StartPad: steaminput/ beside the program on the Mac too
(the {$IFNDEF MACOS} gone), the settings' folder still the fallback;
unwritable Books still falls back to Documents (FormCreate). Uninstall
in Steam may delete Books with the folder, as on Windows / Linux.
README (reader): Game pad, Books folder. NOT COMPILED.
TEST (owner, Mac Steam build): the debug log's "books folder:" and
"pad:" lines name the folder holding EpubReader.app.

## Zip 140 (on top of zip 139): the Mac slows down with its display off
RESULTS (owner, M4 Mac mini, Core ML turbo, build 9554a1f, a queue of 20
books 2026-11-18 22:07 - 2026-11-19 12:21: 281:43:46 of audio in
14:13:21, 19.8x; queue report + history + debug log + pmset log): each
of the 1654 parts' times against pmset's "Display is turned on / off":
display ON 222 h of audio at 27.6x (parts 25 - 30x), display OFF 334 h at
17.1x (15 - 20x). 8 display changes (22:39 off, 04:17 on, 04:42 off,
05:36 on, 06:47 off, 08:28 on, 10:10 off, 12:06 on): every one switched
the speed within two minutes (15 min before / 2 - 17 min after: 28.7 ->
20.4, 17.6 -> 26.4, 26.7 -> 19.8, 19.5 -> 29.4, 26.2 -> 18.4, 18.4 ->
28.2, 29.8 -> 18.2, 17.6 -> 26.8). The owner's test: RustDesk open 08:40
- 10:00 (keeps the display on), closed 10:00 (display off 10:10), logged
on 12:05. The aligning and writing (CPU) was five times slower too (0.6
against 3.2 - 3.6 s per hour of audio) - background treatment (App
Nap), not heat. Cost: about 4 h of the 14. Ender in Exile (forced ru,
23:23 - 00:45) was 10x on top of that: its own trouble (zip 133).
The keep-awake (zip 114) held IOPMAssertion PreventUserIdleSystemSleep:
no sleep, but no protection from App Nap.
1. uInhibit (macOS): with the assertion, NSProcessInfo
   beginActivityWithOptions:reason: (NSActivityUserInitiated |
   NSActivityLatencyCritical) while any kind is held - one activity,
   retained, endActivity: + release at the last stop. Through the
   Objective-C runtime (objc_getClass, sel_registerName, objc_msgSend
   declared once per signature - arm64 needs the exact one); the reason
   is a CFString (toll-free an NSString). InhibitText (the log's
   "keeping the computer awake:" line) adds "; NSProcessInfo activity
   (user initiated, latency critical: no App Nap)".
   TEST (owner): a book or two with the display allowed to sleep - the
   parts should stay at ~27x. If not: Activity Monitor's App Nap column;
   then maybe the window's occlusion (FMX stops drawing) is not it but
   the GPU's clocks - pmset / powermetrics next.
2. The debug log had every build and calibration line twice - the
   thread's DebugLog and LogLine's (24 MB for the queue). New ThreadLine
   (window + the book's log, no DebugLog) for FBuild / FCalib's OnLog;
   the model download's Log does not DebugLog, so it keeps LogLine.
README (builder): Kept awake - the macOS activity and why. NOT COMPILED
(the Objective-C calls untested here).

## Zip 139 (on top of 8a9a67d = zip 138): the morning queue's results
RESULTS (owner, 2026-11-19 06:27 - 07:59, RTX 5090 laptop, Vulkan0,
large-v3-turbo, Steam playtest build a170de0 + local = 8a9a67d): a queue
of nine - the seven Death Gate books, Hitchhiker's Guide, Night Watch.
128.5 h of audio transcribed in 90.8 min, 85x overall (81 - 87x per
book); the history's estimate within 5 % every time (zip 99 works once
a model has builds here). Matched 97.8 - 99.5 %, every book "very good"
but Night Watch ("good", 97.8 % as on every turbo run).
- NIGHT WATCH 10:14, 86.9x, no part out of line - against 26:08 with
  ~15 min of stalls before: the stalls are gone on the book itself too
  (zip 133 saw it with Ender in Exile). The fastest whole-book turbo:
  5090 10:14, Steam Machine 23:44, M4 Core ML 30:47, M4 Metal 52:18.
- Book / calibration on the 5090: 85 / 26.1 = 3.3 (zip 133: 3.2).
  HISTORY_BOOK_RATIO stays 1.35 - right for the Steam Machine and the
  M4, 2.4x too slow for the 5090's first build of a model. Not changed;
  if it matters: a longer calibration clip, or the ratio from this
  machine's own rows of any model.
- Death Gate: 104 - 1276 words "moved" per book - footnotes read where
  they are called (every longest stretch is one): as designed. Tagged
  und, built as en with zip 136's override.
- Worth a listen (owner): Into the Labyrinth 02:53:56 (55 not heard -
  about 20 s where Whisper gave nothing); The Hand of Chaos 18:14:40
  (34 not heard: a diagram's labels in the appendix, not marked as a
  caption).
Changes:
1. HITCHHIKER'S GUIDE: 28253 of 75395 words outside the reading (the
   EPUB's extras; the audio, 5:51, is the whole book) - "very good",
   exact 60.6 % in the history. uBuilder.LogResults: a warning when the
   front and back matter is more than a tenth of the book's words (the
   verdict counts only timed words, so it cannot show this).
   RecordHistory: exact_pct is now Exact / (book words - front and back
   matter); older rows keep all words (uHistory's field doc says so).
   That book's row would read 96.9 %.
2. UI LINES IN A BOOK'S LOG: LogLine adds to FBuildLog while a build
   runs, so "Added to the queue as job 8" landed in Dragon Wing's .log
   and "Another book: the audio list was emptied." in The Hand of
   Chaos's. New WindowLine (debug log + window, never FBuildLog) for
   what the window does: ShowBook, AddAudio, Add folder, CheckThen /
   CheckCalibrationThen / CheckBookThen / CheckOutputThen, AddJob, job
   remove, LoadQueue, Load / Save queue, the job put into the window.
   The keep-awake line stays a LogLine (it belongs to the queue's
   start).
3. FOR TWHISPER (not changed here - Later tests 6's other half, the BACK
   EDGE): Night Watch's last chapter (86 s, 88 words) and the closing
   credits matched a few words of the back matter (the names, likely),
   so the last word read sits in the about-the-author / reviews text:
   ~570 words of it timed over a minute of credits (123 + 43
   interpolated) and a 404-word "not spoken" stretch at the top of the
   worth-a-look list. Fix with the front edge: the first / last word read
   is one inside a run of several matches (say 5 in a row), not a lone
   one.
README (builder): the history's exact share; the front / back matter
warning; a book's .log holds its own build only. NOT COMPILED.

## Zip 138 (on top of zip 137): session 9 handover brought up to date
Zips 135 - 137 in the map, the unpushed list and the repositories table.

## Zip 137 (on top of zip 136): the folders follow the dialogs again
Owner 06:13: "Builder's open epub and audio buttons should remember the
directory last used to load a file - one for each option with the same
for the output folder ... these values should persist between sessions".
Partly undoes zip 122 ("a pick in a dialog no longer changes them"):
Book... sets FBookFolder, Add audio... / Add folder... FAudioFolder,
Output... FOutFolder (the next book's DefaultOutput goes there; FAutoOut
cleared - the name is the user's), each saved at once (SaveSettings).
Tools > ... folder still sets them directly; the defaults stay
Documents/EpubBuilder/... README (builder) Folders updated.

## Zip 136 (on top of zip 135): forced language
Owner 06:03 "what will happen if language = UND" (answer: LanguageId
fails -> Whisper auto-detects, the first part's language kept for the
rest, but NO prompt for the whole book - BookPrompt('und') = ''), then
06:07 "I know 100% it's English - Can we have a forced language
override".
- uBuilder: cbLanguage on the Device row - "From the book (<tag>)" then
  18 languages (LANGUAGES: en de fr es it nl pt ru pl cs sv da no fi el
  tr ja zh); FillLanguages(tag) at every ShowBook (back to the book's);
  ChosenLanguage. TBuildJob.Language (queue file "language", '' = the
  book's; any code there). TBuildThread.Create(..., AForceLanguage):
  after the Book line, und / mul / zxx -> '' (as not given: English
  prompt + detection), then the forced one with a log line "Language:
  en, chosen in the builder (the book says und)". The prompt, Whisper's
  language and the history follow FLanguage.
- README (builder): Language. NOT COMPILED.
- Still open (handover item 5): the automatic check of the text against
  the tag; the prompt chosen after detection for a book with no tag.

## Zip 135 (on top of zip 134): four more for the list
Items 10 - 13 of the session 9 handover's OPEN list (the owner's).

## Zip 134 (on top of zip 133): session 9 handover
The handover at the top ("Session 9") and the repositories table.
Also: three absolute paths of the owner's machine taken out of the zip
110 / 112 / 123 sections (the rule: none in tracked files).

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
