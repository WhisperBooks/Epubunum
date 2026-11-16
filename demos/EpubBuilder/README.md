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

## Using it

1. **Choose...** the EPUB. Its title and word count are shown; a
   copy-protected book is refused with a message.
2. **Add files...** or **Add folder...** for the audio, then put the files
   in reading order (**Up** / **Down**; added files are sorted as people
   read them: chapter2 before chapter10). With **Chapters of a file are
   parts** ticked, each chapter of an m4b is transcribed as a part.
3. Choose the model and, if you like, the device (Default lets
   whisper.cpp choose; WhisperConsole `--bench` tells which is fastest).
4. Check the output name (`<book>-synced.epub` by default) and press
   **Create**. The **Now** line shows what is being done - while a part
   is transcribed, the words as they are heard, with their time in the
   recording - and the time taken and (once there is enough to go on)
   the time left, updated every second. The log keeps a line per step and
   per part; **Cancel** stops at the next check. If the output EPUB is
   already there, Create asks before replacing it - unless this run of
   the builder made it from the same book (building again, e.g. from the
   saved transcript, does not ask).

The book's language (its `dc:language`, e.g. `de`) is the language
Whisper transcribes in - never translated - and the prompt that keeps
capitals and punctuation is in that language (English, German, French,
Spanish, Italian, Dutch so far; other languages are transcribed without
one). A multilingual model is needed for other languages
(`ggml-large-v3-turbo.bin` is; the `.en` models are English only).
Choosing another book empties the audio list and sets a new output name.

The results after a build list the longest stretches worth a look.
Front and back matter - text not read before the first or after the last
word that is (title pages, a licence, about the author) - is counted but
not listed: it is normal, and still in the book. The recording's parts
(chapters of an M4B with **Chapters of a file are parts** ticked, else
the files) are written into the book as chapter marks, which EpubReader
steps by when the book's contents list has no chapters that are read.

The model, the device (by name), the two options and the last book and
audio folders are remembered between sessions, in
`%APPDATA%\EpubBuilder\EpubBuilder.ini` on Windows,
`~/Library/Application Support/EpubBuilder/EpubBuilder.ini` on macOS and
`~/.config/EpubBuilder/EpubBuilder.ini` (or under `$XDG_CONFIG_HOME`) on
Linux. Delete the file to start afresh.

The transcript is kept beside the output as
`<output>.transcript.json`. With **Use a saved transcript** ticked, a
second **Create** with the same audio reads it instead of transcribing
again: re-aligning a whole audiobook then takes seconds (after a TWhisper
update, for example). It is the same JSON as WhisperConsole `--json`, so
`WhisperConsole --from-json` reads it too.
