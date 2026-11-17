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

A Whisper model file (`ggml-large-v3-turbo.bin` is a good choice) is
chosen in the window.

For the calibration (below), `media/aladdin.m4a` - a LibriVox recording
- beside the program, or in a folder up to five levels above it (the
repository's root, from `demos/EpubBuilder/<platform>/<config>`). Without
it the calibration asks for another recording of English speech, a few
minutes long.

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
change the queue (not the job running); a double click puts a job's
choices back into the window. **Save...** writes the queue to a JSON file
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
books are done.

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
not listed: it is normal, and still in the book. The recording's parts
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
