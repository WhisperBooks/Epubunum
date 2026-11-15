# Session handover - 2026-11-15 (evening), session 6

Read this first, then each repository's CLAUDE.md (they hold the detail
and the history; this is the summary and the to-do list).

## Repositories and where they stand

| Repo | Pushed | = zip | Last zip number used |
|---|---|---|---|
| WhisperBooks/TWhisper | 59cc978 | TWhisper-28 | 28 |
| WhisperBooks/Epubunum | 5717238 | EpubUnum-37 | 37 |
| G3DGames/TFFMpegAPI | 105ffe7 | FFmpegAPI-11 | 11 |
| G3DGames/ffmpeg-dev | 2b0ba17 | ffmpeg-dev-06 | 06 |

All four pushes were checked file by file against the deliveries (CR LF
and BOM aside). The only difference: demos/EpubBuilder/EpubBuilder.dproj
in Epubunum was re-saved by the IDE (platform blocks, TargetedPlatforms;
harmless - keep the pushed one). TWhisper's 5e029a8 had EpubUnum-34's
files unpacked into it by mistake (EpubUnum's CLAUDE.md over TWhisper's,
demos/EpubReader/...); fixed in 59cc978 and re-checked. Nothing is
pending: every delivered zip is pushed. The pushes checked are not yet
written into the repos' CLAUDE.md files - do that in the next zip of each.

## Standing rules (owner) - unchanged, repeated because they matter

- Never commit or push, and never offer to.
- Zips: only files changed since the previous zip, paths from the repo
  root, named TWhisper-NN-topic.zip / EpubUnum-NN-topic.zip /
  FFmpegAPI-NN-topic.zip / ffmpeg-dev-NN-topic.zip; numbers never
  reused (a corrected zip gets the next number and says what it
  replaces); every delivery says what it goes on top of.
- Every delivery ends with either "NO PACKAGE REBUILD" or: a blank line,
  `=====> PACKAGE REBUILD NEEDED <=====`, a blank line, then the packages
  in build order, the units changed, what to rebuild after.
  TWhisper: WhisperAPI -> WhisperAPIFMX -> dclWhisperAPIFMX.
  EpubUnum: EpubUnum -> EpubUnumFMX -> dclEpubUnumFMX.
- ASCII sources; PasDoc on every declaration; run tools/pasdoc_check.py
  and tools/project_check.py before delivering (both repos).
- .dproj files: do not change platform lines or the default platform;
  never run gen_projects.py --force on existing projects (without
  --force it only creates missing files - that is how EpubBuilder.dproj
  was made). Group projects are edited by hand.
- README code blocks paste as-is: comments on their own line, no
  <placeholders>.
- Never offer DRM removal; refuse protected files with a clear message.
- Copyrighted test books stay local - never committed, uploaded or
  quoted. Night Watch (Pratchett, English and German) is one: the owner
  sends logs only.
- No absolute paths, user names, machine names or e-mail addresses in
  tracked files.
- Answer simple questions directly and briefly first.
- When the owner's message arrives mid-task, address it in the same turn.

## What exists now

Pipeline (files): EpubConsole --words -> WhisperConsole (transcribe,
--json) / --from-json --align-words --timings -> EpubConsole --overlay.
In one program: **EpubBuilder** (Epubunum demos/EpubBuilder, links
TWhisper + EpubUnum + TFFMpegAPI): EPUB left, audio list right, model /
device / output, Create; keeps `<output>.transcript.json` so a re-align
needs no transcription; explained results with a verdict; settings in
EpubBuilder.ini (model, device by name, options, folders).

**EpubReader**: menu (File: Open, Recently Opened (10), Go to Footnote -
only with "debug": true; Edit: Find / next / previous; View: Dark mode,
Learn to read, text size), settings in EpubReader.json (dark, textSize,
speed, recent with reading positions, debug), opens the last book read
where it was left, centred smooth line following, speed slider 0.5-1.5x
(applied when the slider rests), Learn to read (green, Phrase / Sentence
/ Paragraph; Play repeats the unit; click = the unit the word is in),
punctuation not lit, footnotes shaded (marked notes, or the paragraph a
marker link points to), Open with registration (Windows HKCU, Linux
.desktop), icon.

**TWhisper** this session: edge pairs (front / back matter not timed),
Roman numerals as numbers, short words given room, word edges trimmed of
silence from the audio (the next sentence no longer lit during a pause),
benchmark times a chosen stretch of speech (not within 30 s of either
end), shared helpers for the builder (WhisperWordFileTimes etc.).

## Results to remember

- Moby-Dick (LibriVox, Stewart Wills, 24 h 38 m, 5 m4b): 81x on the 5090
  laptop; 209652 exact of 213817 book words. Against the IDPF human sync
  of ch 1-2: clip starts mean |error| 0.21 s (the human times are
  rounded to 0.25-0.5 s).
- Aladdin through EpubBuilder: 26.5 s for 34:32 (78x) once the builder
  used TWhisper's book settings (no previous-text context, punctuated
  prompt in every window); 99.8 % matched.
- Night Watch (English, professional reader, 14:41, 75 parts): 97.8 %;
  441 moved words = the footnotes, timed where they are read.
- Benchmark on the 5090 (turbo, Aladdin, 30 s): chosen stretch CUDA0
  122.0x, Vulkan0 128.8x; the old first-30-s figures were ~20 % high.

## Open - Windows (owner to test or answer)

1. Test the pause fix in the reader on a book rebuilt after TWhisper-28
   (the next sentence must not light while the narrator pauses).
2. Test German Night Watch through the builder (book language -> German
   prompt, transcribe only). Expected weak spot: chapter numbers (the
   aligner's number words are English).
3. Night Watch's contents list has no chapters: check the chapter
   buttons, which fall back to the book's 24 documents.
4. Unanswered offers: (a) Create asks before replacing an EPUB this
   book's last build did not make; (b) leave front / back matter out of
   the builder's "worth a look" list; (c) Find matches a punctuation-only
   query (`*`) literally.
5. Small: --overlay drops audio no overlay plays (moby-dick-mo.epub's
   9 MB mp4); a drawn menu bar that follows dark mode (the native one
   stays light); the Settings menu (later).

## Next - other operating systems (agreed order: Linux, then macOS)

- **Linux (incl. Steam Machine, Steam Deck):** a Linux build of TWhisper
  and its first test (whisper-dev builds the libraries); then the
  Steam Machine HIP re-run with --bench (chosen stretch, greedy) for a
  like-for-like comparison with the 5090; first runs of the reader
  (FMXLinux; TSteamAPI's platform units and EpubReader.sh already in)
  and of the builder; FFmpeg linux-x64 from ffmpeg-dev. Steam Deck:
  Steam Input through TSteamAPI (needs its source in the session) and a
  1280x800 layout.
- **macOS:** TFFMpegAPI has no macOS audio output yet (AudioQueue) - the
  reader is silent there until it does; TWhisper with Metal (untested);
  Info.plist CFBundleDocumentTypes for "Open with".
- **Android:** later.

## Plans agreed or parked (detail in the CLAUDE.md files)

- Volunteer transcribers (design only): a job server, workers poll,
  LibriVox section files as jobs, transcripts back, the server aligns;
  workers report their own benchmark (HIP / Vulkan / CUDA / Metal),
  6 GB+ GPU memory. TWhisper CLAUDE.md, plans.
- Audio outside the book: timings beside the original EPUB (+3: the
  complete EPUB), timings naming LibriVox's downloads, an edition check.
  Epubunum CLAUDE.md, "Shall we do this".
- Builder: progress per word stretch is fine; later - go to the
  suspicious stretches from the results (needs the reader inside the
  builder or the other way round); long files without chapters could be
  split into 30 min pieces (memory: 64 KB per second of audio).
- German / other-language number words in TWhisper's aligner, if the
  German run shows heading misses.
- Parked: English sentence -> German sentence and audio between two
  synced EPUBs (sentence alignment feasible, phrase level needs a
  translation model).

## Working notes for the next session

- Nothing compiles Delphi / FMX in the session: lib/ and the consoles
  were built with FPC 3.0 to test; the reader, the builder and the FMX
  view were reviewed by reading only - the owner's Delphi build is their
  first compile, so expect the occasional compile fix.
- Tests used here, worth setting up again when needed: epubcheck 5.2.1
  on every overlay EPUB; a check that every clip equals its timing and
  ClipAt finds it; a check that only markup was inserted into the
  documents; --from-json re-alignment of the owner's moby.json (fast
  regression test of the aligner: 209652 exact, 213544 timed words with
  the current word list).
- The owner's machine: Windows, RTX 5090 laptop + Intel iGPU; whisper.cpp
  and FFmpeg 8.1.3 LGPL in TWhisper's redistributable_bin\Win64 (on
  PATH); model ggml-large-v3-turbo.bin.
