# EpubConsole

Console demo and smoke test of EpubUnum: `TEpubBook` directly, no component.

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
```

`--text --body-only` is what an aligner should read: the words a narrator
speaks. Copy-protected books are refused with a message (exit code 1).
