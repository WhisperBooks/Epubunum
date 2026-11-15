# EpubReader

The end-user reader: open an EPUB, read it, and - for a book with media
overlays (EPUB 3 synced audio) - listen with the words highlighted as they
are read. The page is drawn with Skia by `TEpubView`; the contents list is
on the left.

## Before the first build

**TFFMpegAPI** (github.com/G3DGames/TFFMpegAPI) plays the sound: build its
`FFmpegAPI.groupproj` first (the reader uses the runtime package FFmpegAPI's
DCUs). Then build EpubUnum's packages (`EpubUnum.groupproj` builds them before
the demos) and install `dclEpubUnumFMX` to open the form in the designer.
Skia is enabled for this project (Project > Enable Skia), so the IDE
deploys Skia's library (`sk4d.dll`, `libsk4d.so`, ...) next to the program.
**Do not keep the `GlobalUseSkia := True;` line** the IDE adds to the .dpr.

## Using it

| | |
|---|---|
| Folder / Ctrl+O | choose a book |
| Contents list | jump to a chapter |
| bar + double triangle | previous / next chapter (document of the reading order) |
| triangle + bar | previous / next sentence (media overlay clip) |
| Play / Pause, P | play or pause the book's audio (books with media overlays) |
| click a word | play from there |
| A- / A+, Ctrl+Minus / Ctrl+Plus | text size |
| wheel, arrows, Page Up / Page Down, Space, Home / End | scroll |

Copy-protected books are refused with a message.

## Platform notes (from TSteamAPI)

The files in `src/` named `Fmx*.pas` and `EpubReader.sh` are **unchanged
copies** of TSteamAPI's (github.com/G3DGames/TSteamAPI, `docs/`):

- **Linux in Steam's runtime / SteamOS:** use Steam Linux Runtime 3.0;
  `FmxLinuxGtkGlobal` makes GTK globally visible (otherwise "access
  violation at address 0" with a TListBox); ship `EpubReader.sh` (the ICU
  launcher, LF line endings) as the Linux launch command (otherwise exit
  code 139 on SteamOS).
- **Windows build under Wine / Proton:** `FmxWineCanvas` avoids the white
  window (Wine's Direct2D); `TSAPI_FMX_CANVAS=skia %command%` switches FMX
  to Skia's raster canvas (much faster there).
- **No main menu** on purpose: FMX's GTK menu bar on Linux shows only first
  letters (TSteamAPI's `FmxLinuxMenu` fixes it if a menu is ever added), and
  SteamOS runs every main window full screen.

## Sound

The book's audio is played by FFmpegAPI's `TFFmpegAudioPlayer`: FFmpeg
streams the audio file (extracted from the book once) to the platform's
output - WASAPI on Windows, PulseAudio / PipeWire on Linux and SteamOS - and
the player's clock (the sound really being heard) picks the sentence to
highlight. Put FFmpeg 8's shared libraries (`avutil-60.dll`,
`swresample-6.dll`, `avcodec-62.dll`, `avformat-62.dll`) next to the
program or on PATH; a GPL or an LGPL build will do, and its licence is
written to the log. Without FFmpeg the book still reads, without sound;
without a sound device it plays silently and the highlight still follows.
macOS sound comes later.

The tool bar's icons are drawn as Sprite3D's results view draws them: a
`TPath` in a `TButton`, coloured by the style.
