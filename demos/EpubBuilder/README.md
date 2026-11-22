# EpubBuilder

Makes a read-along EPUB: an EPUB on one side, its audio files on the other,
**Create**. The new book has EPUB 3 media overlays (one clip per word) and
the audio inside it; open it in EpubReader to hear it read with the words
highlighted, or in any reading system that plays media overlays.

It does in one program what the file pipeline does in three steps
(`EpubConsole --words`, `WhisperConsole --align-words --timings`,
`EpubConsole --overlay`): TWhisper transcribes the audio with word times
(DTW), aligns those words with the book's own words, and EpubUnum's
writer puts the times into the book.

## Before the first build

Build, in order: TFFMpegAPI's `FFmpegAPI.groupproj`, TWhisper's packages
(`WhisperAPI` first), then EpubUnum's group (`EpubUnum.groupproj` builds
the packages before the demos). EpubBuilder takes all their DCUs from
Delphi's Dcp folder.

## Running it

Next to the program, or on PATH:

- whisper.cpp's libraries (TWhisper's `redistributable_bin` for the
  platform: `whisper.dll`, the `ggml-*.dll` backends);
- FFmpeg 8's shared libraries (`avutil-60.dll`, `swresample-6.dll`,
  `avcodec-62.dll`, `avformat-62.dll`); when they are not found there,
  the builder also looks in whisper.cpp's folder.

The Whisper model is chosen by name in the **Model** list of the
**Settings** page (below).

## The window

At the top the **book** (left) and its **audio** (right); below them,
across the window, the **job queue** (Load, Save, Remove, Up, Down, Run
queue); at the bottom the **output**, a line of the settings with
**Settings...**, Create / Add to queue / Update job / Cancel, and the
progress (or the log, Settings > Show the log). The dividers between book and audio and
between them and the queue can be dragged.

The menu bar has **File** only: **Settings...** and **Exit**. "Settings >"
in this text is **File > Settings...**: the Settings page of the menu
that Big Picture uses, over the window - Model (with Download every
model), Calibrate and Diagnostics (this model, every model), Device,
Language, Power, Chapters of a file, Dark mode, Expert mode, Output, the
Books / Audio / Output folders, Show the log, Calibration results, Build
history, and AMD ROCm acceleration when it applies. Arrow keys or W A S
D, Enter, the mouse and its wheel work it; Esc, a right click or **Back**
closes it. (The View and Tools menus it replaces are gone.) **F2** opens
the whole menu and **F3** the queue's, as in Big Picture.

**Settings...** (the window's button) opens the settings on a page of
their own over the window: Model (and its Folder...), Device, Language,
Power, Window GPU (Windows), "Chapters of a file are parts" and "Use a
saved transcript". **Done** closes it (Enter too) and saves; the line on
the window says what is set - the model, the device, the language, the
power, and what is not as usual (a file's chapters not parts, USING THE
SAVED TRANSCRIPT). In Big Picture the pad's menu has all of these, and
the window shows the log only.

For the calibration and the diagnostics (below), the **reference texts**
in `media/` - beside the program, or in a folder up to five levels above
it (the repository's root, from `demos/EpubBuilder/<platform>/<config>`);
on macOS also the bundle's `Contents/Resources/media`. A reference text is
a public-domain LibriVox recording and the EPUB of the text it reads:

| Reference text | Recording | Book | Used by |
|---|---|---|---|
| A Scandal in Bohemia (Doyle) | `ScandalBohemia_librivox.m4b` (Phil Chenevert, 56 min, 3 sections) | `A_Scandal_in_Bohemia.epub` (Project Gutenberg 1661, its first story) | the calibration, the diagnostics, the benchmark |
| A Christmas Carol (Dickens) | `AChristmasCarol_librivox.m4b` (Kyle M., 3 h 11 min, 5 sections) | `A_Christmas_Carol.epub` (Project Gutenberg 46) | the benchmark |

The program names these files in one place (`REFERENCE_TEXTS` in
`uCalibration.pas`), so they can be changed there. The recordings are
git-ignored (each machine needs its own copy); the EPUBs are committed.
Every file of `media/` goes with the program, none named by the tools:
on Windows the post-build step copies the folder; for Linux and macOS
Delphi's Deploy takes it from the repository's `media/` - after `media/`
changes, run `python tools/deploy_redist.py --media-only` (on the Windows
machine; it rewrites only those deploy entries, for Linux64 and
OSXARM64); `tools/redist.sh deploy` copies it too. Without the calibration's recording the calibration asks for
another recording of English speech, a few minutes long.

Only chapter material is timed or scored: every section of a LibriVox
recording opens and closes with a spoken notice, so the calibration and
the diagnostics work in one section of the recording (a chapter of the
file) and keep 30 s away from both of its ends.

## Models

The **Model** list offers two of whisper.cpp's models:

| Model | For | Words not heard on a first pass |
|---|---|---|
| turbo (whisper.cpp's large-v3-turbo) | the most accurate: the first choice | 1.2 % |
| base | several times faster, nearly as accurate: slower machines, or a quick build | 2.0 % |

These two came out of timing and scoring all ten models on seven machines
(AMD, NVIDIA and Intel graphics on Vulkan, Apple's Metal; Linux, Windows
and macOS; ten minutes of one public-domain recording against its text).
large-v3-turbo was the most accurate on every machine and never had to
decode a passage again; base was faster than it on every machine and
within a point of it. The English-only models (the `.en` ones) decoded
many passages again and so were slower in a build than their twins.

**Settings > Expert mode** - in Big Picture **Expert
mode** - puts all ten in the list: base and turbo first, always; then
the models of every language (tiny, small, medium, large), those
installed before those still to download, each smallest first; the
English-only ones (tiny.en, base.en, small.en, medium.en) at the very
end in the same way. The list says **turbo** for large-v3-turbo and
**large** for large-v3; the files, the queue files and the logs keep
whisper.cpp's names. After them come the other `ggml-*.bin` files of
the models folder and **Other model file ...**, which takes one from
anywhere. Expert mode is kept until turned off. A model already in use stays in the list either way.

One not downloaded yet says how large it is; choosing it
asks, then downloads it from whisper.cpp's model repository on Hugging
Face (the progress bar shows it; **Cancel** stops it). The file is checked
- its size, and its SHA-256 when Hugging Face gives one - before it is
used.

Where the models are kept:

- Steam builds: the `models` folder in the program's folder in Steam's
  library (macOS: beside the `.app`); uninstalling removes them.
- Otherwise the folder chosen with **Folder...** next to the list (kept in
  the settings); at first `models` beside the settings. A folder that
  already holds `ggml-*.bin` files can be chosen as it is.

The settings name a model in the models folder by its name
(`Model=large-v3-turbo`), any other by its file.

**Core ML (macOS).** When whisper.cpp is built with Core ML (whisper-dev's
default on a Mac; the log says `Core ML: built in`), a model's encoder can
run on the Neural Engine. It needs the model's Core ML encoder - a folder
`ggml-<name>-encoder.mlmodelc` beside the `.bin`, from the same model
repository (about as large again as the model for the big ones). A model
downloaded on such a build comes with it; for a model already there the
list says `(no Core ML encoder)` and choosing it offers the encoder. Without
the encoder the model runs on Metal as before. The first use of an encoder
on a Mac is slow (macOS compiles it once), so re-calibrate after
downloading one - the calibration's warm-up takes that time. Builds with
the encoder are kept apart in the build history (device `MTL0+CoreML`),
so the two can be compared.

### Every model at once

**Settings > Model > Download every model...** - in Big Picture the first row of the
model list - asks once, with the total size, and then fetches every model
of the list that is not in the models folder (the two, or all ten in
expert mode), one after another, each checked. Calibrating or running the
diagnostics on "every model" follows the list in the same way. The model in the window stays as it is and no calibration is
offered between them; Cancel, or a download that fails, ends it (what
was fetched stays, and the same command later fetches the rest). Then
**Calibrate every model** and **Diagnostics (every model)** work through
them all.

## Calibration (which device is fastest here)

Which device transcribes fastest - the processor, or the graphics card
through CUDA, Vulkan or ROCm - depends on the card and its memory, its
driver, the model and the processor. Left to itself ("Default")
whisper.cpp takes the first GPU in its list, and that is often not the
fastest: on an RTX 5090 laptop large-v3 built Night Watch in 39 min on
CUDA (whisper.cpp's choice) and in 29 min on Vulkan; a 4 GB GTX 1650 cannot
hold large-v3 at all.

So the builder offers a **calibration** when it starts, until one has
been made (or **Do not show this again** is ticked). It times the model
in the window on every device: the model is loaded, a short warm-up, then
three timed runs of 30 s of speech (the median counts). The 30 s are
chosen in one section of the reference text's recording where there is
speech all through, 30 s away from both of the section's ends. The settings are a build's: word times by DTW, the book
prompt, each window on its own. The fastest device becomes the model's
device. A device that heard far fewer words than the others is not
chosen, because it may not compute correctly. A device the model fails
on (not enough memory) is recorded. Create and Add to queue ask before
building on it (No by default).

- **Settings > Calibrate (this model)**: again, after a new graphics card
  or driver. The start-up question also comes back when the device list
  has changed.
- **Settings > Calibrate every model**: every
  `ggml-*.bin` beside the model, smallest first.
- **Settings > Calibration results**: what is kept, model by model.

Choosing a model that has been calibrated sets the device to its fastest.
Results are kept per model in `EpubBuilder.ini`
(`[Calibration]`, `[Calibration ggml-large-v3.bin]`, ...). The last
calibration's lines are in `EpubBuilder-calibration.log`, beside it. If
the program ends while a model is timed on a device (a GPU runtime that
gives up), the next start records that pair as failed, and the
calibration offered then leaves it out. Re-calibrate tries it again.

Every build's log (and the queue report) starts with the machine
(name, system, processor, memory), whisper.cpp's version and folder, and
the device in full. "Default" is shown as the device whisper.cpp takes,
with whether the calibration found it fastest for the model.

A model that has not been timed on this machine - one just downloaded, or
one chosen from the list - brings the question "Calibrate it now?" by
itself. Yes calibrates that model; No leaves it on "Default" and is
remembered until the program is started again, so choosing the model again
does not ask twice. The question is not asked while a build, the queue, a
download or a calibration runs, nor after "Do not show this again".

## Build history and the time left

Every build that transcribes adds a row to `EpubBuilder-history.csv`
beside the settings: when, the computer, model, device, the audio's
length, how long the transcription and the aligning / writing took, the
speed (x real time), the calibration's speed at the time, the exact
share (of the words between the first and the last word read: front and
back matter left out - rows from before 2026-11-19 count all the book's
words) and the matched share (the verdict's), and the book: its title, the
language transcribed and the output's file name (rows from before these
columns have them empty; the file's header line is brought up to date
on the next build). A spreadsheet opens it, and
**Settings > Build history...** shows it as a table, newest first, under a
line per model and device of this machine (builds, median speed, exact
and matched); **Copy** puts the table on the clipboard as tab-separated
text.

A new build starts from what it can expect, logged as `Expected: about
... from ...`: the median speed of the last builds of that model on that
device here; else the calibration's speed, corrected by how this
machine's builds compared with their calibrations; else the calibration
times 1.35 (a whole book usually runs that much faster than the
calibration's 30 s windows). Builds that matched less than 90 % of the
book (the wrong recording, or a book tagged with the wrong language)
are left out: their speed says nothing of the next book's. The time left then moves from that expectation towards the build's
own rate as more audio is done, plus the aligning and writing earlier
builds here took. Without either (no build, no calibration) it is the
build's own rate after a minute, as before. At the end the log says
`Speed: ...x real time (expected ...x)`.

## Steam: AMD ROCm acceleration as a free DLC (Linux)

On Steam the base program has whisper.cpp with the CPU and Vulkan
backends. AMD's ROCm (HIP) backend - with its runtime and kernels, about
1 GB - is a free DLC, "AMD ROCm acceleration", installed into the
program's folder, where ggml finds it at the next start. In a Linux
Steam build with an AMD GPU and no ROCm device the log says so and
**Settings > AMD ROCm acceleration...** appears: a DLC in the
account is installed by Steam; one that is not opens its store page in
the Steam overlay (add it - it is free - and Steam installs it). Start
EpubBuilder again afterwards, then **Settings > Calibrate**: ROCm0 is
timed against Vulkan0. When the DLC is installed but no ROCm device
appears, the log says so and the debug log's whisper.cpp lines say why.

ROCm runs only on the GPUs its kernels were built for (`rocblas/` beside
the program, from the HIP depot). The Linux launcher (`EpubBuilder.sh`)
hides ROCm (`HIP_VISIBLE_DEVICES=-1`) when ROCm's runtime is beside the
program but no kernels are (the HIP depot not installed), or when none of
the AMD GPUs - their targets read from the driver, `/sys/class/kfd` - has
kernels there (a Steam Deck's gfx1033). The device list, the default
device and the calibration then use Vulkan, and the log says "ROCm: off
- why". The Linux depot itself should not carry ROCm's runtime: deploy
with `deploy_redist.py --skip-rocm`, or stage with `tools/steam_stage.py`
(it moves the ROCm files out of the Linux folder). The DLC is not offered on a Steam
Deck. A `HIP_VISIBLE_DEVICES` set in Steam's launch options is left as
it is. EpubBuilder checks too, whatever the launcher did: on a Steam
Deck, with ROCm's runtime beside the program and no `rocblas/`, or when
the launcher found no kernels, the ROCm devices are left
out of the Device list and the calibration ("ROCm0 left out" in the
log), and **Default** is the first other GPU (Vulkan0) - whisper.cpp
itself would take ROCm0. The debug log's "ROCm check:" line says what
the launcher found.

The depots are made with `tools/steam_stage.py` from SteamPipe GUI's
deployment folder: it moves the ROCm files out of the Linux depot's
folder into a HIP folder and completes that from
`redistributable_bin/Linux64` (kernels and licences included).

## Icon

`EpubBuilder_Icon.ico` (Win64; set in the project), one of the EpubUnum
set drawn by `tools/make_icons.py` (Pillow): an open book, text on one
page and a sound wave on the other, with a gear badge - EpubReader's has a
highlighted word and play, BookManager's books on a shelf and arrows.

## Which build is this?

Every build of EpubReader and EpubBuilder is stamped: a pre-build step
(`tools\buildstamp.bat`) writes the time and the git commit into
`demos/common/BuildStamp.inc` (not tracked), and the debug log's first
lines - and EpubBuilder's window and build logs - show it, e.g.
`Build: 2026-11-17 15:25, 8e306df+` (`+`: with changes not committed
yet). Compare it with the build you uploaded.

## Linux and Steam's runtime

Like EpubReader, EpubBuilder carries TSteamAPI's `FmxLinuxGtkGlobal` (FMX
crashes in Steam's Linux runtime without it) and `FmxWineCanvas` (a
Windows build under Proton), and ships `EpubBuilder.sh`, the ICU launcher
script: on Linux, Steam starts `EpubBuilder.sh`, which starts
`EpubBuilder` next to it. Deploy puts the script there in every
configuration.

## Language

Whisper is told the book's language (its `dc:language`). A wrong tag
costs dearly - an English book tagged `ru` came out at 62.7 % matched
and a third of the speed - so **Language** (beside Device) can override
it: "From the book (...)" shows the tag, or choose the language the
recording is in. The choice goes back to "From the book" for every new
book, and is kept with a queued job (`"language"` in the queue file,
where any code Whisper knows can be written). `und`, `mul` and `zxx`
in a book count as no language (Whisper detects it). The log says
`Language: en, chosen in the builder (the book says ...)`.

## Folders

EpubBuilder works with three folders: books (the EPUBs to read along),
audio (the recordings) and output (the books it makes). At first they
are Documents/EpubUnum/Books, Audio and Transcribed, made at start-up;
Settings > Books folder / Audio folder / Output folder choose
others (kept in the settings). Each also follows its dialog: Book... and
Add audio... (and Add folder...) open where a file was last chosen, and
an output chosen with Output... - or typed into the Output box, once the
book is added to the queue or created - makes its folder the output
folder for the next books (a folder that does not exist is not taken) -
all kept between runs.

The folders are shared with EpubReader: Documents/EpubUnum (Books,
Audio, Transcribed, Covers, Queues) and one settings folder, EpubUnum
(EpubBuilder.ini and EpubReader.json side by side). At the first start
after the change, what was in Documents/EpubBuilder and EpubBuilder's
settings folder is moved in (Documents/EpubBuilder is renamed; settings,
the queue and the history are copied with their paths changed - the old
files stay; the models, converted MOBIs and other folders are moved).
It happens once; the debug log lists it ("folders: ...") and so does
EpubUnum-moved-EpubBuilder.txt in the settings folder.

A chosen book's output is its own file name in the output folder - the
EPUB 3 it becomes, with the audio and the overlays. When that name is
taken (a file there, or a job in the queue writes it) it gets a number:
Night Watch_001.epub, then _002 and so on. The name can still be changed
(Output...).

## Kept awake while it works

The Power row chooses how the computer is kept while a build, the queue,
a calibration or a model download runs (kept in the settings, in force
at once when changed):

- Automatic (the first time): Fastest on mains power, Save power on
  battery - looked at again at each book of a queue;
- Fastest: kept awake, at full speed (the Mac: no App Nap; Windows: no
  EcoQoS efficiency mode);
- Save power: kept awake, but the system may slow the program down (the
  Mac: App Nap allowed - an M4 ran at 17x real time with the display off
  instead of 27x; Windows: EcoQoS; Linux: left to the system);
- Let it sleep: nothing held - a computer that sleeps stops the build
  until it wakes.

The log says what was done ("Power: Fastest (Automatic: on mains power)
- keeping the computer awake: ...; speed: ..."), and each book's log at
  its start.

On Windows, Window GPU (Settings) stores Windows' graphics preference for
EpubBuilder (as Settings > System > Display > Graphics does), used from
the next start: which GPU draws the window on a laptop with two. Whisper
runs on the Device chosen, not on this - but the Vulkan devices may come
in another order after it; the device (and each queued job's) is found
again by its description, so a build keeps its GPU.

While it works, EpubBuilder asks the system not to sleep (the screen may
still go dark), and lets it sleep again when it ends. SteamOS in Game Mode, and laptops,
otherwise sleep after a while with nobody at the controls - half way
through a book. The log says how it was asked ("keeping the computer
awake: ..."):

- Windows: SetThreadExecutionState.
- macOS: an IOKit power assertion; at Fastest also an NSProcessInfo
  activity (user initiated) - without it macOS slows the program down
  once the display is off (App Nap): an M4 ran a queue at 27.6x real time
  with the display on and 17.1x with it off.
- Linux: systemd-logind's sleep:idle inhibitor over D-Bus (libdbus-1).

If the machine still sleeps, set its sleep timeout to Never while a long
book builds (Steam: Settings > Display / Power).

### Steam's Game Mode: the build pauses for sleep

In Steam's Game Mode, refusing sleep breaks Steam: when its sleep timer
fires and the machine may not sleep, the screen goes black, Steam's menu
stops working, and only restarting Steam (or the machine) helps. So
there EpubBuilder does not refuse sleep. While it builds it asks only for
a few seconds' notice ("Game Mode - sleep allowed, the work pauses for
it" in the log):

- When the machine is about to sleep, the build pauses between two 30 s
  windows of the transcription ("Paused: the system is going to sleep"),
  and the machine sleeps.
- When it wakes, the build goes on where it was ("Going on after the
  sleep"). The time asleep is not counted in the build's time, its speed
  or the time left.
- Steam's sleep timer counts from the last button pressed, not from the
  wake: a machine woken and left alone sleeps again after the timer -
  with a 1-minute timer, every minute. Each wake goes on where it was.
- At Run queue, EpubBuilder says how long the queue should take, and that
  Steam's sleep pauses it. To build overnight without anyone waking the
  machine, set Steam's sleep to Never: dimming and the screen saver can
  stay.

Game Mode is told by the environment (gamescope), or by Steam's Big
Picture on Linux; the log's start says which.

Game Mode (gamescope) can show the window black after Steam's screen
saver or once the display comes back on. On Linux EpubBuilder then draws
itself again and, in Game Mode only, changes its size by a pixel and back
(full screen, as in Big Picture: leaves full screen and goes back): when
the window is active again, when a display comes back on, and at the
first pad press after a minute without one. Steam's Big Picture on a
desktop is only drawn again (leaving full screen there would be seen and
lose the focus). The debug log says each time ("redraw: ...").

On every system EpubBuilder draws its whole window again every two
seconds, so a display that went to sleep during a long run does not come
back to an empty window that fills in only at the next line of the log.
The display itself is still allowed to sleep while EpubBuilder works (the
computer is not): that is the system's setting.

## Ended from outside (Steam's Exit Game)

Steam's Exit Game ends EpubBuilder with SIGTERM (Linux, macOS); so does
the system when it shuts down. EpubBuilder then saves its settings, the
queue file and the log so far, and ends at once when a build, calibration
or download was running. A build's finished parts are kept (see below):
building the book again goes on from the next part; a calibration or
download starts again.
The log says "Asked to end (SIGTERM ...)", and the next start's debug log
says when and during what the last run was ended. A calibration ended
this way is not taken for a crash of the device. On Windows nothing is
trapped.

## A build stopped part way goes on from there

After each part (a chapter, or a file) is transcribed, the transcription
so far is kept beside the output as `<output>.transcript-partial.json`.
When the build stops part way - Steam's Exit Game, the system shutting
down, a crash, Cancel, a part that failed - building the same output
again with the same model and audio goes on from the next part ("GOING ON
FROM PART n"), and the history counts the earlier parts' own time. Once
the whole transcript is saved (`.transcript.json`) the partial file is
deleted. Another model or other audio starts from the first part.

## Debug log

Every run writes `EpubBuilder-debug.log` next to the settings
(`%APPDATA%\EpubUnum` on Windows, `~/Library/Application Support/
EpubUnum` on macOS, `~/.config/EpubUnum` on Linux; the window's log
shows the path): the build's steps, the devices, whisper.cpp's and ggml's
own lines, each written to the file at once. When the builder disappears
without a message (a library crashed), the last lines say what it was
doing. The previous run's log is kept as `EpubBuilder-debug.log.old`.

### Diagnostics (what makes a model slow here)

**Settings > Diagnostics (this model)...** - in Big Picture, **Diagnostics
(this model)** on the home list - measures the model in the window on its
device. **Run diagnostics on every model...** (Big Picture: **Diagnostics
(every model)**) does the same for every model in the models folder,
smallest first, each on the device its calibration chose, and ends with a
table - a line per model: its speed as a build and without the fallback,
how many checks failed, how much of the text was heard with and without
the fallback. A model that cannot be loaded (too large for the card) is
noted and the next one run. Nothing has to be set up: it uses the calibration's reference text
(A Scandal in Bohemia), ten minutes of the first section long enough,
from 30 s into it, and transcribes
them four times with a build's settings:

| Run | Temperature fallback | DTW word times |
|---|---|---|
| 1 | on | on (as a build) |
| 2 | off | on |
| 3 | on | off |
| 4 | off | off |

For each run the log gives the time and speed, the words heard, how many
30 s windows failed whisper.cpp's probability or entropy check (with the
fallback on, each of those is decoded again at a higher temperature), the
encoder's, decoder's and sampling's time, and the windows' own times (the
fastest, the middle one, the slowest, how many took more than twice the
middle one).
Each run is also scored against the reference text's book (its EPUB in
`media/`, read as a build reads a book): how far into the text the run
got, and how much of what was read was heard exactly, or exactly or
nearly. A run that "reached" far fewer words than the others dropped
text at the end; a lower share heard means words were lost or wrong in
between. With another recording chosen for the calibration, or without
the EPUB, there are no such figures.
Then it says what the fallback costs (run 1 against run 2), what it is
worth in words heard, and what DTW costs (run 1 against run 3). The lines are added to
`EpubBuilder-diagnostics.log` beside the settings - one file holds every
run, each under its "=== Diagnostics (date) ===" line with its model and
device; delete the file to start afresh. whisper.cpp's own timing lines
of each run are in the debug log. It runs like a calibration (Cancel stops it) and
changes no setting, no calibration and no build history. Only the first
pass is timed, not a build's second pass over gaps.

The time it takes is about forty minutes of audio at the model's speed
here: a few minutes on a graphics card, longer for a large model on a
processor.

### Diagnostic builds (a last resort: a whole book, measured)

Two switches make every build of that run a measurement of a real book.
Give them on the command line (Steam: the program's Properties > Launch
options) or as environment variables with any value:

| Switch | Environment variable | What it turns off |
|---|---|---|
| `--no-fallback` | `EPUBUNUM_NO_FALLBACK` | whisper.cpp decoding a 30 s window again, at a higher temperature, when its text fails the entropy or probability check |
| `--no-dtw` | `EPUBUNUM_NO_DTW` | DTW word times (token time stamps are used; flash attention stays off, as with DTW) |

Windows, in Steam's launch options:

```
--no-fallback --no-dtw
```

Linux and SteamOS, in Steam's launch options:

```
EPUBUNUM_NO_FALLBACK=1 EPUBUNUM_NO_DTW=1 %command%
```

A diagnostic build says so in its log ("DIAGNOSTIC ..."), always
transcribes (no saved or part-way transcript is read), keeps no transcript
and is not added to the build history, so the time estimates and the next
normal build are not changed by it. Its book is written as usual, but its
words may be less accurate or less accurately timed: take the switches out
to build books.

Every build, diagnostic or not, writes whisper.cpp's timings to the debug
log after each part's first pass and again after its second pass
("timings: part N of M, ..." followed by the "whisper_print_timings"
lines): the time and number of runs of the encoder, the decoder and the
sampling since the part began, and the fallbacks ("p" probability, "h"
entropy) since the model was loaded. A part's own fallbacks are the
difference from the part before. DTW has no timer of its own: its cost is
the difference between a build with and without `--no-dtw`.

## Using it

1. **Choose...** the EPUB (or a MOBI - see below). Its title and word
   count are shown; a copy-protected book is refused with a message.
2. **Add files...** or **Add folder...** for the audio, then put the files
   in reading order (**Up** / **Down**; added files are sorted as people
   read them: chapter2 before chapter10). With **Chapters of a file are
   parts** ticked, each chapter of an m4b is transcribed as a part.
   A DRM-free Audible `.aax` is taken like an m4b (in the book it becomes
   `.m4b`, so other readers play it). A copy-protected file - an `.aax`
   straight from Audible, a FairPlay m4b - is not added: the log says why.
   EpubBuilder never removes copy protection.
3. Choose the model; the device is the calibration's fastest for it
   (or choose one: Default lets whisper.cpp take its first GPU).
4. Check the output name (`<book>-synced.epub` by default) and press
   **Create**. The **Now** line shows what is being done - while a part
   is transcribed, the words as they are heard, with their time in the
   recording - and the time taken and (once there is enough to go on)
   the time left, updated every second. The log keeps a line per step and
   per part; **Cancel** stops at the next check. Closing the window while
   a build runs asks first (No by default): the build would stop and its
   work so far be lost. If the output EPUB is
   already there, Create asks before replacing it - unless this run of
   the builder made it from the same book (building again, e.g. from the
   saved transcript, does not ask).

## MOBI books

A DRM-free MOBI (`.mobi`, `.prc`, `.azw`, `.azw3` with the old
Mobipocket text in it) can be chosen like an EPUB, here and in Big
Picture's book list. EpubBuilder writes an EPUB 3 from it first
(library unit `Epub.Mobi`) and builds from that; the read-along book it
makes is an EPUB 3 as always. The converted copy is kept in the
settings' folder, `Converted/<name>.epub`, and made again when the MOBI
is newer. The log says what was read: "MOBI converted to EPUB 3: MOBI 6 -
"title" by author, language en: 28 document(s) ...".

- The book is split into documents at Kindle's page breaks; Kindle's
  tags are dropped, its indents and alignment kept as styles, links
  inside the book and pictures kept, the cover marked.
- Refused with a message: copy-protected (DRM) books - never decrypted,
  as everything bought from Amazon is; books compressed with Huffman
  coding (HUFF/CDIC); KF8-only books (AZW3 without the old text) - not
  read yet.

## Job queue (many books, overnight)

The **job queue** is below the book and the audio. Instead of **Create**,
press **Add to queue**: the book, its audio, the model, device, output and the two
options are added as a job (the same questions as Create are asked then,
not while the queue runs). **Run queue** builds the jobs one after the
other - failed and cancelled ones again - and books can be added while it
runs. A book built is no longer queued: while the queue runs its job shows
as done, and when the queue has finished (after the report is written)
the done jobs leave the queue. **Cancel** stops the job running and the queue (Run
queue goes on with the jobs not done). **Remove**, **Up** and **Down**
change the queue (not the job running). After Add to queue the window is
emptied for the next book - the book, its audio, the output, the language
and the saved-transcript choice (the model, device, power and chapters
stay). A click on a job shows it in the
window as it was added - the book, its audio files, model, device,
output, language and options - so a loaded queue can be checked; change
what is wrong (the output's name, say) and press **Update job**: the
same checks as Add to queue, then the job takes the window's choices in
its place, waiting again. Add to queue still
adds a new job. Update job is off for the job running, and after Remove,
Up or Down until a job is clicked again. **Save...** writes the queue to a JSON file
and **Load...** adds the jobs of one, so a list of books can be prepared
and run later. Loading asks nothing, so it says what it did in the log: a
job saved as done is not queued (the book is built),
a job whose output is its own book, or whose output a job of the queue
writes already, is left out; a job whose output is there already is added
with a note that it will be replaced. Each build's log is kept beside its output as
`<output>.log` (Create's too), and the list shows each job's state, the
time it took or why it failed.

When the queue has run, a **report** is written beside the queue file
with its name (`books.json` gives `books.md` and `books.csv`; a queue
never saved: `EpubBuilder-report-<date-time>` beside the first output):
the Markdown file has a table - time, audio length, speed, matched %,
verdict, EPUB size per book - and a section per book with every figure
(transcription time, model, device, words exact / similar / moved /
interpolated / not heard / not spoken, front and back matter, reading
speed, clips, chapter marks); the CSV has all of them for a spreadsheet.
The queue file is saved again after each job, so it always says which
books are done (loading it again queues only the others). Save... and Load... open in the queues folder,
Documents/EpubUnum/Queues (the last one used is kept). The queue
itself is kept as it changes (EpubBuilder-queue.json beside the
settings) and comes back at the next start - closing the program, or a
crash, loses no jobs; a job that was running then is waiting again, and
one done by then is not queued. In
Big Picture the Queue list has **Save queue** (named by the date and
time, in the queues folder) and **Load a queue ...** (that folder's
queues, newest first; their jobs are added). Each book's `.log` holds its own build only: what is done
in the window meanwhile (another book chosen, a job added, the queue
loaded or saved) goes to the window's log and the debug log, not into
the log of the book being built.

The book's language (its `dc:language`, e.g. `de`) is the language
Whisper transcribes in - never translated - and the prompt that keeps
capitals and punctuation is in that language (English, German, French,
Spanish, Italian, Dutch so far; other languages are transcribed without
one). A multilingual model is needed for other languages
(`ggml-large-v3-turbo.bin` is; the `.en` models are English only).
Choosing another book empties the audio list and sets a new output name.

A book EpubBuilder (or EpubConsole) made is marked so in its package:
choosing it shows "ALREADY A READ-ALONG BOOK", and Create asks before
building from it (No by default) - choose the original EPUB instead. A
book with synced audio of its own (made elsewhere) is asked about too.

The results after a build list the longest stretches worth a look.
Front and back matter - text not read before the first or after the last
word that is (title pages, a licence, about the author) - is counted but
not listed: it is normal, and still in the book. When it is more than a
tenth of the book the results say so - the verdict counts only the timed
words, so it stays "very good" for an EPUB with extras (an introduction,
a preview, another book), another edition, or a recording of only part
of the book: check where the reading starts and ends. The recording's parts
(chapters of an M4B with **Chapters of a file are parts** ticked, else
the files) are written into the book as chapter marks, which EpubReader
steps by when the book's contents list has no chapters that are read.

The model, the device (by name), "Chapters of a file are parts" and the
last book and audio folders are remembered between sessions (**Use a
saved transcript** is not: it is off at every start), in
`%APPDATA%\EpubUnum\EpubBuilder.ini` on Windows,
`~/Library/Application Support/EpubUnum/EpubBuilder.ini` on macOS and
`~/.config/EpubUnum/EpubBuilder.ini` (or under `$XDG_CONFIG_HOME`) on
Linux. Delete the file to start afresh.

The transcript is kept beside the output as
`<output>.transcript.json`, with the model that made it and when. With
**Use a saved transcript** ticked (Settings; off at every start - reusing old words
is a choice for one build), a second **Create** with the same audio reads
it instead of transcribing again: re-aligning a whole audiobook then takes
seconds (after a TWhisper update, for example). It is used only for the
same output name, the same audio files and parts, and the same model -
another model chosen means a new transcription - and the log says, in
capitals, which transcript was used, when it was made and with which
model. It is the same JSON as WhisperConsole `--json`, so
`WhisperConsole --from-json` reads it too.

## Big Picture (a pad, the keyboard, the mouse, a finger)

Started from Steam in Big Picture (or Game Mode on a Steam Deck / Steam
Machine), EpubBuilder opens its pad menu over the window - no file
dialogs or mouse needed (with no model downloaded yet it opens on the
model list):

- **Book**: the EPUB and MOBI files of the books folder (and its folders)
  to choose from - the books still to do first, in name order; those
  transcribed already last, faded and marked "transcribed" (a book of
  that name in the output folder, a queued job's output folder or a
  card's Transcribed folder, or a build of the build history that matched
  well, at least 90 %);
- **Audio**: chosen with the book - the audio folder's files and folders
  whose names best match the book's title come first (a folder of two or
  more files is all of them, in name order), *best match* on top; choose
  one, see **All the audio in the folder ...**, or keep the list;
- **Add to queue**, then **Queue** (Run queue is its first row; each job:
  show it in the window, Up, Down, Remove) - Queue is selected after Add
  to queue;
- **Cover**, **Create**, **Update job**, **Cancel**, **Controls**,
  **Settings...**, **Exit**.

**Settings...** (directly above Exit) is a second page - B, or its Back
row, returns:

- **Model**: a list of every model - installed, or its size to download
  (choosing one not installed asks to download it; turbo is a good
  first choice);
- **Device**, **Language**, **Power**, **Chapters of a file are parts**:
  left / right change them;
- **Calibrate (this model)**, **Calibrate every model**, **Diagnostics
  (this model)**, **Diagnostics (every model)**;
- **Dark mode**, **Expert mode**;
- **Output** (says where the book is written; with no book chosen yet,
  the folder).

| | Pad | Keyboard | Mouse, finger |
|---|---|---|---|
| up / down | D-pad / stick | Up / Down, W / S | the wheel |
| change a value | left / right | Left / Right, A / D | |
| choose | A | Enter | left click, tap |
| back (a question: no) | B | Esc | right click |
| the menu / close it | Start / Menu | F2 | a click beside the menu closes it |
| the queue | View / Select | F3 | |

The keys drive the menu while it shows; in Big Picture F2 or Enter
opens it, on the desktop F2. **Controls** lists these as they are bound now, the button or
key on the left and what it does on the right: Steam's pictures of the
pad's own controls (their names when Steam has none), or the keys and
the mouse when those were used last. Use the other while the list shows
and it changes over at once - as the hints at the menu's foot do. Both
forms of the list have the same width, the wider one's.

Every button and key mapping has one definition: the tables of
`tools/gen_reader_input.py`, which writes the Steam Input action
manifest, the pads' layouts and, beside them, the menu's keys and
pointer (Steam Input itself binds controllers only - a keyboard or a
mouse is not one of its devices). The programs ask which *action* a key
or a click means and act on the action as for a pad; no key is named in
their own code. Layout revision 1.3.

In Big Picture the window behind the menu is the log alone, full screen
in large type (24) - no menu bar, columns or settings: the pad's menu has
all of them. While a build runs the menu's foot shows its progress; close
the menu to read the log. A program asking to connect (BookManager)
still shows its bar above the log. On the desktop the window is never
made wider than the screen (a Steam Deck in Desktop Mode). Questions (an output already there, a model to
download, the calibration) are asked in the same menu. The pad uses
EpubReader's Steam Input actions (one manifest per Steam app); outside
Big Picture Start opens the same menu on the desktop too. Copy books into
the books folder and audio into the audio folder first (on a Steam Deck in
Desktop Mode); Settings changes them on the desktop. Save... and
Load... of a queue need the desktop (file dialogs).

EpubBuilder is dark, in Big Picture and on the desktop alike: the pad's
menu, its questions and the window. **Settings > Dark mode** (left / right, or A) - turns that off and
on; it is one setting for both (`[View] Dark`, on unless turned off). On
the desktop the window's background, its captions and status line, the
audio and queue lists, the book's text and the log go dark; the edit and
combo boxes, the buttons, the settings panel and the menu bar keep the
system's own look.

The home list comes back by itself when something has ended - a download,
a calibration, the diagnostics, a build, the queue - unless a question is
on the screen (answer it first) or something else is still running. After
a download, a calibration, the diagnostics or a declined "Calibrate it
now?" it comes back on **Model**, ready for the next one; after a build
or the queue on its first row. Directly under **Model** on the home list
are what is done with a model: **Calibrate (this model)**, **Calibrate
every model** (every downloaded model in one go - the desktop has the same row) and **Diagnostics (this model)**.

## Progress, and the log

While it works, the window's lower part shows what is being done in large
type: the book, its job in the queue, how far it is, the time taken and
left, and the transcription's speed so far (x real time); when idle, the
jobs waiting and the last build's result. The line above it still shows
the words being transcribed. The log - every line also kept in the book's
.log and the debug log - is behind **Settings > Show the log** (kept between
starts).

## The cover

The book built gets a cover by this rule (log: "Cover: ..."):

1. a picture in the **Covers** folder (Documents/EpubUnum/Covers,
   [Folders] Covers) named as the book's file, its output or its title -
   .jpg, .jpeg, .png, .webp or .gif;
2. else the **audiobook's** cover art (an m4b / m4a / aax's, an mp3's ID3
   picture, a FLAC picture) when the book has no cover, or its cover is
   wider than it is high - a book cover never is (a calibre MOBI came
   with Word 2000's logo, 680 x 510);
3. else the book's own.

**Cover...** (beside the book's Choose..., and Cover on Big Picture's
list) shows the covers there are as thumbnails - Automatic (the rule
above), the book's, the audiobook's and every picture in the Covers
folder (those named as the book first) - click one, or move with the
pad and press A. The choice goes into the job (queue files keep it as
"cover"). The new cover is added to the book as its cover-image (the old
picture stays in the book). Pictures sent from BookManager go to the
Covers folder.

## The link (BookManager and EpubReader)

EpubBuilder listens on the network from the start (log: "link:
BookManager and EpubReader can connect (port 47821 ...)"), so other
programs can send it books and audio, fetch the books it made, and show
its progress and log. Nothing is typed: every two seconds it says where
it is (UDP broadcast, port 47820), and the other programs list the
builders they hear. Its HTTP port is 47821, or the next free one up to
47830. A firewall must let these through (Windows asks the first time).

- **Pairing, once:** a program asks; EpubBuilder shows a 6-digit code in
  a bar at the top of its window (in Big Picture also in the pad's box),
  with the time it still works (5 minutes). Typed in the other program,
  the two are paired for good (kept in the settings, [Link] Paired) and
  the bar closes by itself - as it does when the code runs out or was
  typed wrong five times. **Refuse connection** turns the program away
  (it can ask again). Only paired programs can send or fetch.
- **Files sent in** go to the books folder (EPUB, MOBI) or the audio
  folder (m4b, mp3, ...), into a sub folder when one is given (an
  audiobook's folder of files stays together). Each is written as
  `.part` and named when whole; the log says "Received ...". A file
  that would leave less than 2 GB free on that drive is refused before
  it is sent - building needs the room.
- **Books made**: the EPUBs in the output folder, the queue's output
  folders and the cards' Transcribed folders; a program can fetch them
  (and go on after an interruption).
- **Progress and log**: what the progress panel shows, and the log's
  last 5000 lines.

While the machine sleeps it is not heard; it is back when it wakes.

## Memory cards

On Steam hardware (Linux), a memory card's top-level folders are looked
in too: **Books** (EPUB files) and **Audio** (audiobooks) - in Big
Picture's book list and the audio matching. Choosing a book that is on a
card asks where its EPUB goes: back on the card, in its **Transcribed**
folder, or on this machine (the output folder). Only those folders are
looked in, never the whole card. EpubReader lists a card's Books and
Transcribed folders.
