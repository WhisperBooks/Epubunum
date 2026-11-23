# EpubConsole

Console demo and smoke test of epubunum: `TEpubBook` directly, no component.

Build the packages first (`EpubUnum.groupproj` builds them in order): the
demo takes the library's DCUs from the runtime package EpubUnum.

## Usage

```
EpubConsole <book.epub>                        metadata, contents, word roles, overlays
EpubConsole <book.epub> --text OUT.txt         the text, a paragraph per line
                        [--body-only]          (leave out captions, notes, navigation)
EpubConsole <book.epub> --layout N             the blocks of document N (from 1)
EpubConsole <book.epub> --at AUDIO SECONDS     the clip and words read then
EpubConsole <book.epub> --extract DIR          every file of the book under DIR
EpubConsole <book.epub> --words OUT.txt        every word: number, document, role, text
EpubConsole <book.epub> --overlay TIMINGS OUT.epub (--audio FILE | --book-audio PATH)...
                        [--block] [--narrator NAME]
                                               a copy with media overlays (TEpubWriter)
EpubConsole <book.epub> --clip-timings OUT.txt TIMINGS from the book's own overlays
```

### Writing overlays

TIMINGS is a text file, a timed word per line: `WORD BEGIN END [AUDIO]` -
the word's number as `--words` lists it (from 1), start and end in
seconds (`.` decimal), and the audio file's number in the order the
`--audio` / `--book-audio` options are given (default 1). Lines starting
with `#` are comments. Without `--audio` / `--book-audio`, the files come from the timings
file's own `# audio N: path` lines (WhisperConsole `--timings` writes
them; a relative path is relative to the timings file). `--audio` copies a file into the book;
`--book-audio` uses one already inside it. `--block` writes a clip per
paragraph instead of per word.

Word numbers belong to the Epubunum version that listed them. When an
update changes how words are found (zip 15: a dash between two words now
ends the first, so 'calm' + em dash + 'frozen' is two words), make a new
`--words` list and align again before `--overlay`; a timings file made
from an older list puts times on the wrong words. Re-aligning does not
need a new transcription: WhisperConsole `--from-json` reads the old one.

`--clip-timings` is a test aid: it shares each clip of the book's own
overlays out over the clip's words by length - not an aligner. For
example, Moby-Dick at word level:

```
EpubConsole moby-dick-mo.epub --clip-timings t.txt
EpubConsole moby-dick-mo.epub --overlay t.txt moby-words.epub --book-audio OPS/audio/mobydick_001_002_melville.mp4
```

`--text --body-only` is what an aligner should read: the words a narrator
speaks. Copy-protected books are refused with a message (exit code 1).
