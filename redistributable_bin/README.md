# redistributable_bin

The shared libraries Epubunum's programs need at run time, one folder per
Delphi platform: whisper.cpp's (built by whisper-dev) and FFmpeg's (built
by ffmpeg-dev) together. Epubunum's programs - EpubReader, EpubBuilder -
are the ones that get deployed, so their libraries are collected here.
Nothing in this folder except this file is tracked (`.gitignore`: platform
folders and `.dll` / `.so` / `.dylib` files).

| Folder | Filled on | With |
|---|---|---|
| `Win64` | Windows | `tools\redist.bat collect WHISPER_DEV FFMPEG_DEV` |
| `Linux64` | Linux x86-64 | `tools/redist.sh collect WHISPER_DEV FFMPEG_DEV` |
| `OSXARM64`, `OSX64` | a Mac (that architecture) | `tools/redist.sh collect WHISPER_DEV FFMPEG_DEV` |

WHISPER_DEV and FFMPEG_DEV are the two repositories' folders, after their
`build` scripts have run. **For Linux, build both in whisper-dev's
container** (`container-build/build.sh` and `container-build/build.sh
../ffmpeg-dev`, Docker or Podman - whisper-dev's
`container-build/README.md`): libraries built straight on a new
distribution do not load on older ones; from the container they run on
every Linux with glibc 2.35 or newer. On Windows, TWhisper's `redistributable_bin\Win64`
also does as WHISPER_DEV. Each platform folder also gets `licences/`:
FFmpeg's LGPL texts and its build's configure line, and whisper.cpp's MIT
licence - they go with the libraries.

## Deploying

The libraries go where the programs look first:

| Platform | Where | Command |
|---|---|---|
| Windows | next to the .exe | `tools\redist.bat deploy TARGET_FOLDER` |
| Linux | next to the program (they find each other through `$ORIGIN`); `EpubReader.sh` goes along with EpubReader | `tools/redist.sh deploy Linux64 TARGET_FOLDER` |
| macOS | the bundle's `Contents/Frameworks` (signed ad hoc, or with `CODESIGN_ID`), licences in `Contents/Resources/licences` | `tools/redist.sh deploy OSXARM64 TARGET.app` |

With PAServer, run the deploy on the Linux box or the Mac after a build,
on the folder PAServer built the program in. During development on
Windows the Win64 folder can simply be put on PATH instead.

Models (`ggml-*.bin`) are not kept here: EpubBuilder asks for one.
