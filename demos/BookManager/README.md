# BookManager

EpubBuilder's companion, on another computer of the same network (or on
the same one). It finds EpubBuilder by itself, pairs with it once, and
then:

- **sends it books, audio and pictures** - drop them on the window (or
  **Add files...** / **Add folder...**), each goes to its place;
- **fetches the books it made** into a folder here (EpubReader's
  Transcribed folder at first, so the reader lists them);
- shows its **progress** and its **log** as it works.

Not a Steam program. It needs none of epubunum's packages, TWhisper or
FFmpeg: the link (`demos/common/uLink.pas`) is Indy, which comes with
Delphi. Nothing to put beside the program.

## Before the first build

Nothing else to build first. `tools\buildstamp.bat` runs before every
build (the project's pre-build step) and writes
`demos\common\BuildStamp.inc`, which the debug log reads; it is not
tracked.

## Connecting

EpubBuilder says where it is every two seconds (UDP broadcast, port
47820); BookManager lists every EpubBuilder it hears at the top, as
"computer (address)". With one heard, it is chosen; the one chosen last
time is chosen again when it is heard. Nothing is typed.

**Pairing, once per EpubBuilder:** **Pair...** asks it; EpubBuilder shows a
6-digit code (in a box, in Big Picture too) that works for 5 minutes; type
it in the row that opens under the list, **Pair** (or Enter); EpubBuilder's
bar closes by itself. If someone there presses **Refuse connection**,
BookManager says so and the row closes (**Pair...** asks again). The
pairing is kept on both sides. If EpubBuilder forgets it (its settings were
reset), BookManager says so and asks to pair again.

**Without a code (optional):** programs that are in the same account at
https://link.epubunum.com pair with each other without the code.
**Account...** shows a code and that address: sign in there (a link is
mailed to you; there is no password) and type the code - BookManager says
when the account has it. **Open in browser** in that row opens the page
in your own browser with the code filled in already. From then on **Pair...** first asks the site for
a ticket and hands it to EpubBuilder; if that EpubBuilder is not in the
account (or the site is not reached) BookManager says why and the 6-digit
code is asked for as before. Nothing of this is needed: with **Account...**
never pressed, no outside site is ever asked.

A firewall must let the link through: Windows asks the first time
BookManager runs (allow it on private networks). EpubBuilder's HTTP port
is 47821, or the next free one up to 47830.

When EpubBuilder is closed, or its computer sleeps, it is not heard: the
list says "Connection inactive" and BookManager stops asking it for its
progress (a builder that does not answer is asked less and less often
first: 2, 4, 8, 16, then every 30 seconds). Transfers started then fail
with "no answer": drop the same files again when it is back - those that
arrived are not sent twice, and a fetch goes on from where it stopped. It
is asked at once when it is heard again.

In Delphi's debugger these tries show as first-chance Indy exceptions
(Connection refused, Connect timed out) - handled; Tools > Options >
Debugger > Embarcadero Debuggers > Language Exceptions can ignore
EIdSocketError, EIdConnectTimeout, EIdClosedSocket,
EIdConnClosedGracefully and ELinkError.

## Dark mode

**Dark mode**, the check box at the top right, is on at first (as in
EpubBuilder) and kept in the settings (`BookManager.ini`, `[View]
Dark`). Dark: the window, the tabs' pages, the lists and the log are
dark with light text, and the tabs' names are drawn as a row of boxes
under the builder row (the one that shows is filled). Buttons, the list
of builders, the code box and the progress bars keep the system's
colours. Unticked, the window is as the system's style draws it.

## Send to EpubBuilder

Drop on the dashed box (or on the list below it):

- a **book** (EPUB, MOBI, PRC, AZW, AZW3) goes to EpubBuilder's books
  folder;
- **audio** (m4b, m4a, aax, mp3, wav, flac, ogg, opus, aac) to its audio
  folder;
- a **picture** (jpg, png, webp, gif) to its Covers folder - name it as
  the book it is for (EpubBuilder gives a book the picture of its name);
- a **folder**: each file to its place, keeping the folders it was in from
  the dropped folder's name down - an audiobook's folder of parts stays
  one folder (EpubBuilder's audio list offers a folder of files as one
  book), a folder of several books stays as it was.

Left out, and said so in the status line (all of them in the debug log):
other files (text, playlists, ...), hidden files and folders, `.part`
files, and pictures beside audio files (`folder.jpg`, `cover.jpg`: not
named as a book; EpubBuilder already takes an audiobook's own picture).

The files go one at a time, books first, then pictures, then audio. A file
EpubBuilder already has (the same name and size) is not sent again ("It
has it"); another of that name gets a number. Each arrives as `.part` and
is named when whole, so EpubBuilder never takes half a file.

**Space:** EpubBuilder refuses a file that would leave less than 2 GB free
on its drive - building needs the room - before any of it is sent. The
line beside the buttons says how much room it has; when the files dropped
need more, BookManager asks before sending.

**Cancel** stops the transfer chosen in the list (one waiting is dropped),
**Cancel all** every one, **Clear finished** takes the finished ones off
the list.

## Books made

The EPUBs in EpubBuilder's output folders, newest first, each "new" or
"here" (a file of that name and size is in the folder here). The list is
asked for every 20 seconds; **Refresh** asks now.

- **Fetch checked** - the books ticked (none ticked: the one chosen);
- **Fetch all new** - every book not here;
- **Folder...** - where they go (kept between runs). At first
  `Documents/EpubUnum/Transcribed`, the folder EpubReader lists.

A book here of the same name but another size (built again) is
replaced. An interrupted fetch goes on
from where it stopped the next time (its `.part` file is kept, with a
`.part.from` note of the build it is of: when the book was built again
in between, the fetch starts afresh rather than mix the two). Nothing
is fetched that would leave less than 1 GB free here.

## Streaming to a TV (zip 391 - BookManager's half)

While it runs, BookManager serves the books here (the folder Books made
fetches to, its sub-folders too) to the readers paired with it - a TV
streams them instead of storing them. Read only: nothing can be sent to
BookManager this way, and only the programs paired with it (the tokens
they gave it, Send to phone's pairing) are answered. Its UDP
announcement now says the port of that server (EpubBuilder on the same
computer has 47821: BookManager takes the next free one, 47822); when no
port is free it says where it is as before, without serving.

What a reader asks it: `/books` (the list), `/book?path=..&offset=..&length=..`
(a block of a book, at most 16 MB) and `/slice?path=..&offset=..&length=..`
(the audio stored in a book, as a file of its own, with HTTP ranges - the
TV's player streams it; the token may be in the address there,
`&token=..`). The debug log has a "serve:" line for every call but the
blocks.

The reader's half is zip 392: a TV paired with BookManager has all these
books in its library while BookManager runs (EpubReader's README, "BookManager's
books, streamed to a TV").

## Send to phone

On the phone, **Get books from BookManager** (EpubReader's Menu > Books
folders) starts its link: while its panel is open the phone says where
it is on the same network (the same Wi-Fi), and the **Send to phone** tab
lists it (the one chosen last time, else the only one, is chosen).
BookManager says where it is too (a UDP announcement every two seconds),
so the phone answers it directly - the computer learns the phone's
address that way, and its first connection is not lost. A phone not
paired yet is asked at once: it shows a 6-digit code - type it in the row
that opens (**Pair** or Enter); once per phone, kept on both sides.
**Pair...** asks again by hand. Up to 30 seconds is waited for a phone's
answer. A phone whose link is off (Done or Cancel on the phone, the
reader left, the phone asleep) is "not linking now": books are not sent
to it, and BookManager says to start Get books from BookManager on the
phone. When the phone's link goes off while books are being sent (Done
or Cancel on the phone), the book cut off and the phone's books after it
are held - "waiting for the phone to link" in the list - and go on by
themselves, in their order, once the phone links again; the one cut off
starts afresh. Cancel / Cancel all drop held books as any other.
Closing BookManager tells the phone (directly when it is paired and
linking, and with a goodbye on the network): its link panel closes by
itself.

- **Drop** books or folders on the dashed box (or on the list): their
  EPUBs go to the phone; other files are left out (the reader reads
  EPUBs). **Add books...** chooses them in a dialog.
- The list is the books here - the folder Books made fetches to - newest
  first, each "on phone" (a book of that name and size is on the phone)
  or "new" - and while it is being sent, its transfer: "waiting",
  "held" (the phone's link went off), "sending 22 % 11.0 MB/s", "sent
  10.7 MB/s". **Send checked** sends the ticked ones (none ticked: the one
  chosen), **Send all new** every one the phone does not have.
- On the phone they go to EpubReader's own Books folder
  (`Android/data/com.epubunum.reader/files/EpubUnum/Books`) and into its
  library. Uninstalling EpubReader deletes that folder, and the books in
  it.
- The phone keeps 500 MB free: a book that would leave less is refused
  before it is sent (BookManager asks first when the books dropped need
  more than it has). The line beside the buttons says how many books
  the phone has and its room.

**An iPhone or iPad** (zip 409) cannot hear BookManager's announcement
(iOS refuses broadcasts to apps without Apple's multicast entitlement):
the line under the Phone row says this computer's address - "On an iPhone
or iPad, type this computer's address in EpubReader's Get books from
BookManager: 192.168.1.91" (its mouse hint lists every address the
computer has; the one shown is the one its network route uses). Typed
there, the iPad asks it every two seconds, and its own announcement comes
to this computer directly: from then on it is a phone here like any other
(listed, paired with its code, sent books, streamed to). **Refresh** reads
the address again (another Wi-Fi, a cable). Windows' firewall must let
BookManager take connections on the private network (it asks the first
time BookManager runs).

The transfers are in Send to EpubBuilder's list too ("To phone"), one at
a time with the others; the bar under the buttons shows the one running.
Each row shows its speed - while it runs ("45 % 14.8 MB/s", after two
seconds) and when it is done ("Sent 14.6 MB/s"); the debug log has the
size, time and speed of each.
The phone is asked for its books every 20 seconds and after each book
sent; **Refresh** asks now.

## Progress and Log

**Progress** shows what EpubBuilder's progress panel shows: the book, the
job and the queue, the percentage, the time, what it does now and its
speed. **Log** is its log, as it is written (its last 5000 lines when
BookManager connects).

## Remembered between runs

`BookManager.ini` in the shared epubunum settings folder (Windows
`%APPDATA%\EpubUnum`, macOS `~/Library/Application Support/EpubUnum`,
Linux `~/.config/EpubUnum`): the pairings ([Paired], one line per
EpubBuilder or phone), the EpubBuilder chosen last ([Builder]), the phone
chosen last ([Phone]), the fetch folder and the
folder Add files... opens. After **Account...**: [Link] - this
installation's random id and key at the link site, and whether an account
has it. No name of the computer is sent there.

## Icon

`BookManager_Icon.ico` (Windows; set in the project), one of the
epubunum set (EpubReader, EpubBuilder, BookManager: the same navy tile,
cream books and amber badge): books on a shelf, the badge's arrows up
(sent) and down (fetched). Drawn by `tools/make_icons.py` (Pillow), with
the other two - run it again to change them.

## Debug log

`BookManager-debug.log` beside the settings (the run before as `.old`):
the machine, the status lines, every transfer and the files left out.

## Notes

- Linux: dropping files from a file manager depends on FMX's support
  there; **Add files...** and **Add folder...** always work.
- EpubBuilder and BookManager on one computer work too: the books made
  are then already in the Transcribed folder, and "here".
