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

### Linux through Delphi's Deploy (PAServer)

A Clean empties the program's folder on the Linux box, libraries and all.
To have Delphi's Deploy put them back every time, the libraries go into
the projects' deployment:

1. Collect on Linux (`tools/redist.sh collect ...`, above), then copy
   `redistributable_bin/Linux64` - with its subfolders (`rocblas/`,
   `hipblaslt/`, `licences/`) - into the same place in the repository on
   the Windows machine. sftp / scp turn the symbolic links into copies;
   that is fine.
2. On Windows, in the repository: `python tools/deploy_redist.py`. It
   writes a deploy entry for each file into `EpubBuilder.dproj` (all of
   them) and `EpubReader.dproj` (FFmpeg and its licences only), replacing
   the entries it wrote before and nothing else.
3. Reopen the projects in Delphi (close them first: the IDE keeps its own
   copy of an open project and would save over the new entries).

Run 2 and 3 again whenever the libraries change. The full set for
EpubBuilder is large - CUDA's cuBLAS and ROCm's LLVM and kernels make it
1 - 2 GB - and after a Clean, Deploy sends all of it to the Linux box
again. The entries name files that are not in git: on a machine without
the folder, Deploy reports them as missing.

## Release packages (GitHub)

    tools/redist.sh package Linux64 [VERSION]
    tools\redist.bat package [VERSION]

pack a collected platform folder into `redistributable_bin/packages/`
(not tracked), in parts that unpack into one folder, so nobody downloads
a GPU runtime their machine cannot use:

| Part | Holds |
|---|---|
| `core` | whisper.cpp, ggml with its CPU variants and Vulkan, FFmpeg, libgomp (Windows: the MSVC OpenMP runtime) |
| `cuda` | ggml-cuda and NVIDIA's cudart / cuBLAS / cuBLASLt |
| `rocm` | ggml-hip, the ROCm (Windows: HIP SDK) runtime, rocBLAS / hipBLASLt and their kernel folders |

Linux parts are `.tar.gz` (the library links stay links), Windows parts
`.zip`; macOS is one `core` part. Each part carries its licences and a
read-me (`EpubUnum-libs-<part>.txt`: what to unpack where, which driver),
and `SHA256SUMS-<platform>-<version>.txt` lists the parts' checksums.
VERSION defaults to the date. On Linux the GPU parts are what
`libggml-cuda.so` / `libggml-hip.so` need from the folder (found with
`ldd`), the rest is core. A part over GitHub's 2 GiB per file is
reported.

Licences: FFmpeg's and whisper.cpp's are collected from their
repositories; on Linux whisper-dev's container build also puts the
CUDA EULA and the Debian copyright files of every bundled CUDA / ROCm
library and of libgomp into its `dlls/licences/` (whisper-dev-18), and
`collect` brings them here. On Windows `collect` copies `%CUDA_PATH%\EULA.txt`
and the HIP SDK's licence files. `package` warns when a GPU part has none.

Models (`ggml-*.bin`) are not kept here: EpubBuilder asks for one.
