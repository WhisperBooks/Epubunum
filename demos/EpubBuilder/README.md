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

The Whisper model is chosen by name in the window's **Model** list
(below).

For the calibration (below), `media/aladdin.m4a` - a LibriVox recording
- beside the program, or in a folder up to five levels above it (the
repository's root, from `demos/EpubBuilder/<platform>/<config>`); on
macOS also the bundle's `Contents/Resources/media`. On Linux and macOS
`tools/redist.sh collect` takes it into `redistributable_bin/<platform>/media`,
so `tools/deploy_redist.py` and `tools/redist.sh deploy` put it there.
Without it the calibration asks for another recording of English speech,
a few minutes long.

## Models

The **Model** list offers whisper.cpp's models by name, smallest first:
tiny.en, tiny, base.en, base, small.en, small, medium.en, medium,
large-v3-turbo (a good choice: accurate and much faster than large-v3)
and large-v3. One not downloaded yet says how large it is; choosing it
asks, then downloads it from whisper.cpp's model repository on Hugging
Face (the progress bar shows it; **Cancel** stops it). The file is checked
- its size, and its SHA-256 when Hugging Face gives one - before it is
used. Other `ggml-*.bin` files in the models folder are listed too, and
**Other model file ...** takes one from anywhere.

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
chosen in the recording where there is speech all through, away from
both ends. The settings are a build's: word times by DTW, the book
prompt, each window on its own. The fastest device becomes the model's
device. A device that heard far fewer words than the others is not
chosen, because it may not compute correctly. A device the model fails
on (not enough memory) is recorded. Create and Add to queue ask before
building on it (No by default).

- **Tools > Re-calibrate (this model)**: again, after a new graphics card
  or driver. The start-up question also comes back when the device list
  has changed.
- **Tools > Re-calibrate every model in its folder**: every
  `ggml-*.bin` beside the model, smallest first.
- **Tools > Calibration results**: what is kept, model by model.

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
**Tools > Build history...** shows it as a table, newest first, under a
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
**Tools > Get AMD ROCm acceleration (free DLC)...** appears: a DLC in the
account is installed by Steam; one that is not opens its store page in
the Steam overlay (add it - it is free - and Steam installs it). Start
EpubBuilder again afterwards, then **Tools > Re-calibrate**: ROCm0 is
timed against Vulkan0. When the DLC is installed but no ROCm device
appears, the log says so and the debug log's whisper.cpp lines say why.

The depots are made with `tools/steam_stage.py` from SteamPipe GUI's
deployment folder: it moves the ROCm files out of the Linux depot's
folder into a HIP folder and completes that from
`redistributable_bin/Linux64` (kernels and licences included).

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
are Documents/EpubBuilder/Books, Audio and Output, made at start-up;
Tools > Books folder... / Audio folder... / Output folder... choose
others (kept in the settings). Each also follows its dialog: Book... and
Add audio... (and Add folder...) open where a file was last chosen, and
an output chosen with Output... makes its folder the output folder for
the next books - all kept between runs.

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

On Windows, Window GPU stores Windows' graphics preference for
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

## Ended from outside (Steam's Exit Game)

Steam's Exit Game ends EpubBuilder with SIGTERM (Linux, macOS); so does
the system when it shuts down. EpubBuilder then saves its settings, the
queue file and the log so far, and ends at once when a build, calibration
or download was running (the work in progress is lost: Create again).
The log says "Asked to end (SIGTERM ...)", and the next start's debug log
says when and during what the last run was ended. A calibration ended
this way is not taken for a crash of the device. On Windows nothing is
trapped.

## Debug log

Every run writes `EpubBuilder-debug.log` next to the settings
(`%APPDATA%\EpubBuilder` on Windows, `~/Library/Application Support/
EpubBuilder` on macOS, `~/.config/EpubBuilder` on Linux; the window's log
shows the path): the build's steps, the devices, whisper.cpp's and ggml's
own lines, each written to the file at once. When the builder disappears
without a message (a library crashed), the last lines say what it was
doing. The previous run's log is kept as `EpubBuilder-debug.log.old`.

## Using it

1. **Choose...** the EPUB. Its title and word count are shown; a
   copy-protected book is refused with a message.
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

## Job queue (many books, overnight)

The left column is the **job queue**. Instead of **Create**, press **Add
to queue**: the book, its audio, the model, device, output and the two
options are added as a job (the same questions as Create are asked then,
not while the queue runs). **Run queue** builds the jobs one after the
other - failed and cancelled ones again, done ones not - and books can be
added while it runs. **Cancel** stops the job running and the queue (Run
queue goes on with the jobs not done). **Remove**, **Up** and **Down**
change the queue (not the job running). A click on a job shows it in the
window as it was added - the book, its audio files, model, device,
output, language and options - so a loaded queue can be checked; change
what is wrong (the output's name, say) and press **Update job**: the
same checks as Add to queue, then the job takes the window's choices in
its place, waiting again (a done one is built again). Add to queue still
adds a new job. Update job is off for the job running, and after Remove,
Up or Down until a job is clicked again. **Save...** writes the queue to a JSON file
and **Load...** adds the jobs of one, so a list of books can be prepared
and run later. Loading asks nothing, so it says what it did in the log: a
job whose output is its own book, or whose output a job of the queue
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
books are done. Each book's `.log` holds its own build only: what is done
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
`%APPDATA%\EpubBuilder\EpubBuilder.ini` on Windows,
`~/Library/Application Support/EpubBuilder/EpubBuilder.ini` on macOS and
`~/.config/EpubBuilder/EpubBuilder.ini` (or under `$XDG_CONFIG_HOME`) on
Linux. Delete the file to start afresh.

The transcript is kept beside the output as
`<output>.transcript.json`, with the model that made it and when. With
**Use a saved transcript** ticked (off at every start - reusing old words
is a choice for one build), a second **Create** with the same audio reads
it instead of transcribing again: re-aligning a whole audiobook then takes
seconds (after a TWhisper update, for example). It is used only for the
same output name, the same audio files and parts, and the same model -
another model chosen means a new transcription - and the log says, in
capitals, which transcript was used, when it was made and with which
model. It is the same JSON as WhisperConsole `--json`, so
`WhisperConsole --from-json` reads it too.
