# Building distributions - libraries and files for every platform

How to build, collect and place every shared library and support file that
EpubReader and EpubBuilder need, for every platform they ship on, starting
from fresh clones. Follow the parts in order; each part says which machine
it runs on.

Paths in this guide are relative. `<repos>` stands for the folder you clone
everything into (any folder you like, e.g. `C:\dev` or `~/dev`); all the
repositories sit side by side in it. Nothing here depends on a particular
user name or drive.

## Contents

1. [What ships with what](#1-what-ships-with-what)
2. [Machines and what they need (once)](#2-machines-and-what-they-need-once)
3. [Clone the repositories](#3-clone-the-repositories)
4. [Build the native libraries](#4-build-the-native-libraries)
5. [Collect them into Epubunum](#5-collect-them-into-epubunum)
6. [Files that are not built](#6-files-that-are-not-built)
7. [Bring the Linux and Mac folders to the Windows machine](#7-bring-the-linux-and-mac-folders-to-the-windows-machine)
8. [Build the Delphi packages](#8-build-the-delphi-packages)
9. [Build and deploy each program](#9-build-and-deploy-each-program)
10. [Steam depots](#10-steam-depots)
11. [GitHub release packages of the libraries](#11-github-release-packages-of-the-libraries)
12. [Checks](#12-checks)
13. [When something goes wrong](#13-when-something-goes-wrong)

---

## 1. What ships with what

| | Windows (Win64) | Linux (Linux64) | macOS (OSXARM64 / OSX64) |
|---|---|---|---|
| **EpubReader** | FFmpeg DLLs, licences, `steaminput\` (Steam builds: `steam_api64.dll`) | FFmpeg `.so` files, FreeType 2.11.1 + brotli, licences, `steaminput/`, `EpubReader.sh` (Steam builds: `libsteam_api.so`) | FFmpeg `.dylib` files in `Contents/Frameworks`, licences in `Contents/Resources/licences` (Steam builds: `libsteam_api.dylib` in `Contents/MacOS`; the reader writes `steaminput/` beside the `.app` itself) |
| **EpubBuilder, Steam** | whisper.cpp + ggml with the **CPU and Vulkan** backends, FFmpeg, licences, `media\` (the reference texts), `steaminput\` (the reader's), `steam_api64.dll` | whisper.cpp + ggml with every backend built, FFmpeg, licences, `media/` (the reference texts), `steaminput/` (the reader's), `EpubBuilder.sh`, `libsteam_api.so` - deployed **without ROCm and CUDA** (CPU + Vulkan); ROCm in the HIP DLC depot ([part 10](#10-steam-depots)) | whisper.cpp + ggml with the **CPU and Metal** backends, `libwhisper.coreml.dylib`, FFmpeg, licences, `media/` (the reference texts), `libsteam_api.dylib` |
| **EpubBuilder, Debug / Release** | every backend built (CPU, Vulkan, CUDA, ROCm), FFmpeg, licences, `media\` (the reference texts) | as Steam, without `libsteam_api.so` | as Steam, without `libsteam_api.dylib` |
| **EpubConsole** | nothing | nothing | nothing |

Not shipped: Whisper models (`ggml-*.bin`) and Core ML encoders
(`*-encoder.mlmodelc`) - EpubBuilder downloads them when asked.

Where the files come from:

| Files | Built / supplied by | Lands in (Epubunum) |
|---|---|---|
| whisper.cpp, ggml, its backends, CUDA / ROCm runtimes | **whisper-dev** | `redistributable_bin/<platform>/` |
| FFmpeg 8 (LGPL) | **ffmpeg-dev** | `redistributable_bin/<platform>/` |
| FreeType 2.11.1 + brotli (Linux) | fetched by `tools/redist.sh collect` from an Ubuntu 22.04 container | `redistributable_bin/Linux64/` |
| Steam library | Valve's **Steamworks SDK 1.65** (partner site) | `redistributable_bin/steam/` |
| Reference texts (recordings) | you ([part 6](#6-files-that-are-not-built)) | `media/*.m4b` (the EPUBs beside them are committed) |
| Steam Input files (one set per Steam app: both programs) | tracked in git (`demos/EpubReader/steaminput/`) | beside each program: Win64 by `postbuild.bat`, Linux64 by Deploy (`deploy_redist.py`), macOS by hand in the depot (part 10) |
| Launchers `EpubReader.sh`, `EpubBuilder.sh` | tracked in git (`demos/<program>/src/`) | - |

None of the libraries, the Steam SDK files or the recording is ever
committed (`.gitignore` covers them).

---

## 2. Machines and what they need (once)

Delphi runs on Windows and compiles for Linux and macOS through **PAServer**
on those machines. Native libraries are built on the platform they are for.

| Machine | Used for |
|---|---|
| **Windows x64** | Delphi; Win64 libraries; building every program; Steam upload |
| **Linux x86-64** (a desktop - not a Steam Deck) | Linux libraries (in a container); PAServer for Linux64 builds |
| **Mac, Apple silicon** | OSXARM64 libraries; PAServer for OSXARM64 builds |
| **Mac, Intel** (only for OSX64) | OSX64 libraries (the collect step uses the machine's own architecture) |

### Windows

1. **Delphi 13** (RAD Studio) with the Windows, Linux and macOS platforms.
2. **Visual Studio 2022 or 2026** with the *Desktop development with C++*
   workload (includes *C++ CMake tools* and Ninja).
3. **CMake 3.21+** (the one with Visual Studio will do).
4. **CUDA Toolkit** (sets `CUDA_PATH`) - required by whisper-dev on Windows.
5. **Vulkan SDK** from LunarG (sets `VULKAN_SDK`) - required.
6. **AMD HIP SDK** (sets `HIP_PATH`) - optional; without it there is no ROCm
   backend.
7. **MSYS2** in `C:\msys64` (or set `MSYS2_ROOT`), then in the *MSYS2 MSYS*
   shell:
   ```
   pacman -Syu
   ```
   (it may close the shell: open it again and repeat), then:
   ```
   pacman -S --needed make diffutils nasm pkgconf
   ```
8. **Git for Windows** and **Python 3** on PATH.

### Linux

1. **Docker** or **Podman** (whisper-dev's `container-build/README.md`
   has the install steps for both).
2. About 40 GB free disk space for the build image (CUDA, ROCm, Vulkan SDK).
3. Git and Python 3.
4. **PAServer** from your Delphi installation (`PAServer` for Linux, from
   RAD Studio's `PAServer` folder), and the Linux64 SDK added to Delphi
   through it (Tools > Options > Deployment > SDK Manager).

Nothing else: the container brings the compilers and GPU SDKs.

### Mac

1. **Xcode command line tools**: `xcode-select --install`.
2. **CMake 3.21+** (e.g. from cmake.org or Homebrew).
3. Git and Python 3.
4. **PAServer** for macOS from your Delphi installation, and the macOS SDK
   added to Delphi through it.

---

## 3. Clone the repositories

On **every** machine that builds something, clone the repositories it needs
next to each other in `<repos>`:

| Repository | Windows | Linux | Mac |
|---|---|---|---|
| `WhisperBooks/Epubunum` | yes | yes | yes |
| `WhisperBooks/whisper-dev` (with submodules) | yes | yes | yes |
| `G3DGames/ffmpeg-dev` (with submodules) | yes | yes | yes |
| `G3DGames/TFFMpegAPI` | yes (Delphi) | - | - |
| `WhisperBooks/TWhisper` | yes (Delphi) | - | - |
| `G3DGames/TSteamAPI` | yes (Delphi, Steam builds) | - | - |

```
cd <repos>
git clone https://github.com/WhisperBooks/Epubunum
git clone --recurse-submodules https://github.com/WhisperBooks/whisper-dev
git clone --recurse-submodules https://github.com/G3DGames/ffmpeg-dev
```

On Windows also:

```
git clone https://github.com/G3DGames/TFFMpegAPI
git clone https://github.com/WhisperBooks/TWhisper
git clone https://github.com/G3DGames/TSteamAPI
```

`--recurse-submodules` fetches whisper.cpp's and FFmpeg's sources (FFmpeg's
is about 500 MB; a few minutes). A clone made without it:
`git submodule update --init --recursive` inside whisper-dev / ffmpeg-dev.

The result:

```
<repos>/
  Epubunum/
  whisper-dev/
  ffmpeg-dev/
  TFFMpegAPI/     (Windows)
  TWhisper/       (Windows)
  TSteamAPI/      (Windows)
```

All commands below assume this layout and are run from the folder named
in each step.

---

## 4. Build the native libraries

### 4a. Windows (Win64)

From a normal command prompt (the scripts set up Visual Studio themselves):

```
cd <repos>\ffmpeg-dev
build.bat
```

10 - 20 minutes; the result is `ffmpeg-dev\dlls\windows-x64\`.

```
cd <repos>\whisper-dev
build.bat
```

The result is `whisper-dev\dlls\`: `whisper.dll`, `ggml*.dll`, the CPU
variants, `ggml-vulkan.dll`, `ggml-cuda.dll` with NVIDIA's runtime,
`ggml-hip.dll` with ROCm's (when the HIP SDK is installed), the MSVC
runtime, and `BUILD-INFO.txt`. `set JOBS=4` before `build.bat` limits the
parallel compiles if memory runs short (CUDA compiles are large).

### 4b. Linux (Linux64) - in the container

**Always build the Linux libraries in whisper-dev's container**: libraries
built directly on a new distribution do not load on older ones (glibc).
From the container they run on any Linux with glibc 2.35 or newer,
including SteamOS and Steam's Linux runtime.

```
cd <repos>/whisper-dev
container-build/build.sh ../ffmpeg-dev
```

```
container-build/build.sh
```

The first run builds the container image (several GB of downloads, up to
an hour); later runs reuse it. Results:

- `ffmpeg-dev/dlls/linux-x64/`
- `whisper-dev/dlls/` - libwhisper, libggml, the CPU variants, Vulkan,
  CUDA and HIP backends with their runtimes, `rocblas/` and `hipblaslt/`
  kernel folders, `libgomp.so.1`, `licences/`, `BUILD-INFO.txt`

With Podman: `DOCKER=podman container-build/build.sh ...`.

Check the result (each must hold - see whisper-dev's
`container-build/README.md` for more):

```
objdump -T dlls/libggml-base.so | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -n 1
```

prints `GLIBC_2.35` or lower;

```
readelf -d dlls/libwhisper.so | grep RUNPATH
```

prints `[$ORIGIN]`.

### 4c. macOS (OSXARM64, and OSX64 on an Intel Mac)

```
cd <repos>/ffmpeg-dev
./build.sh
```

builds the Mac's own architecture (`dlls/macos-arm64/` on Apple silicon,
`dlls/macos-x64/` on Intel). `./build.sh macos` builds both.

```
cd <repos>/whisper-dev
./build.sh
```

The result is `whisper-dev/dlls/`: `libwhisper.dylib`, `libggml*.dylib`,
`libwhisper.coreml.dylib`, and the backend modules `libggml-cpu-*.so`
and `libggml-metal.so` (named `.so` on macOS too - that is what ggml loads).
Core ML is on by default; the configure step's output says
"Core ML encoder ON".

---

## 5. Collect them into Epubunum

`tools/redist.*` gathers both repositories' libraries, with their licence
texts, into `Epubunum/redistributable_bin/<platform>/`.

**Before collecting**, put the calibration recording in place
([part 6](#6-files-that-are-not-built)) - collect copies it along on Linux
and macOS.

### Windows

```
cd <repos>\Epubunum
tools\redist.bat collect ..\whisper-dev ..\ffmpeg-dev
```

→ `redistributable_bin\Win64\` with `licences\`. If it warns that it found
no whisper.cpp licence, copy `..\whisper-dev\whisper.cpp\LICENSE` to
`redistributable_bin\Win64\licences\whisper.cpp-LICENSE.txt`.

### Linux

```
cd <repos>/Epubunum
sh tools/redist.sh collect ../whisper-dev ../ffmpeg-dev
```

→ `redistributable_bin/Linux64/`, including FreeType 2.11.1 + brotli
(fetched from an `ubuntu:22.04` container - Docker or Podman must work
here too; without them a warning, and EpubReader will crash in Steam's
Linux runtime), `licences/` and `parts.txt` (which files are the
CUDA and ROCm parts - used by `tools/steam_stage.py`).

### macOS

```
cd <repos>/Epubunum
sh tools/redist.sh collect ../whisper-dev ../ffmpeg-dev
```

→ `redistributable_bin/OSXARM64/` (or `OSX64/` on an Intel Mac). It warns
if the CPU or Metal backend is missing.

---

## 6. Files that are not built

### The Steam library (Steam builds only)

1. Download the **Steamworks SDK 1.65** (`steamworks_sdk_165.zip`) from the
   Steamworks partner site.
2. Copy the **contents** of the SDK's `sdk/redistributable_bin/` into
   `<repos>/TSteamAPI/redistributable_bin/` (see the README there; then
   `python3 tools/check_redist.py` in TSteamAPI checks it).
3. Copy three of those folders into Epubunum:

   | From `TSteamAPI/redistributable_bin/` | To `Epubunum/redistributable_bin/steam/` |
   |---|---|
   | `win64/steam_api64.dll` | `win64/steam_api64.dll` |
   | `linux64/libsteam_api.so` | `linux64/libsteam_api.so` |
   | `osx/libsteam_api.dylib` | `osx/libsteam_api.dylib` |

   On Windows:
   ```
   cd <repos>\Epubunum
   mkdir redistributable_bin\steam\win64 redistributable_bin\steam\linux64 redistributable_bin\steam\osx
   copy ..\TSteamAPI\redistributable_bin\win64\steam_api64.dll redistributable_bin\steam\win64\
   copy ..\TSteamAPI\redistributable_bin\linux64\libsteam_api.so redistributable_bin\steam\linux64\
   copy ..\TSteamAPI\redistributable_bin\osx\libsteam_api.dylib redistributable_bin\steam\osx\
   ```

Only the Windows machine needs these (Delphi's Deploy sends the Linux and
Mac ones out).

### The reference texts

EpubBuilder's calibration and diagnostics time Whisper on public-domain
LibriVox recordings and score it against the EPUBs of their texts - the
reference texts, named in one place (`REFERENCE_TEXTS` in
`demos/EpubBuilder/src/uCalibration.pas`). The EPUBs are committed in
`media/`; the recordings are git-ignored, so put them in:

```
Epubunum/media/
```

on **every** machine that collects (part 5) or builds Win64 (part 9):
`ScandalBohemia_librivox.m4b` (A Scandal in Bohemia, read by Phil
Chenevert: archive.org item `ascandalinbohemia_2207_librivox`) and
`AChristmasCarol_librivox.m4b` (A Christmas Carol, read by Kyle M.:
archive.org item `christmascarol_km_librivox`, its file renamed). The
tools take all of `media/` and name no file: the Win64 post-build step
copies it; Linux64 / OSXARM64 deploy it from the repository's `media/`
(not collected into `redistributable_bin`) - after `media/` changes run

```
python tools/deploy_redist.py --media-only
```

on the Windows machine (it rewrites EpubBuilder's media deploy entries
for Linux64 and OSXARM64 and nothing else). Without the recordings every
step only warns, and the program asks the user for a recording when
calibrating.

### Steam Input files

`demos/EpubReader/steaminput/` is tracked and complete. Only when the
reader's controller layouts change: `python tools/gen_reader_input.py`
(it finds `../TSteamAPI` by itself), then commit the result.

---

## 7. Bring the Linux and Mac folders to the Windows machine

Delphi's Deploy (through PAServer) sends files from the Windows machine. A
**Clean** through PAServer empties the program's folder on the Linux box /
inside the `.app`, so the libraries must be part of each project's
deployment - written into the `.dproj` files by `tools/deploy_redist.py`.

1. Copy each collected folder into the same place in the Windows clone:

   | From | To (Windows) |
   |---|---|
   | Linux: `<repos>/Epubunum/redistributable_bin/Linux64/` | `<repos>\Epubunum\redistributable_bin\Linux64\` |
   | Mac: `<repos>/Epubunum/redistributable_bin/OSXARM64/` | `<repos>\Epubunum\redistributable_bin\OSXARM64\` |

   With all subfolders (`licences/`, `rocblas/`, `hipblaslt/`).
   Any way works - `scp -r`, sftp, a USB stick. Symbolic links becoming
   plain copies is fine. For example, from the Windows machine:
   ```
   cd <repos>\Epubunum\redistributable_bin
   scp -r USER@LINUXBOX:<repos-on-linux>/Epubunum/redistributable_bin/Linux64 .
   scp -r USER@MAC:<repos-on-mac>/Epubunum/redistributable_bin/OSXARM64 .
   ```
2. **Close** EpubReader and EpubBuilder in Delphi (the IDE would otherwise
   save its own copy of the project over the new entries).
3. Write the deploy entries:
   ```
   cd <repos>\Epubunum
   python tools/deploy_redist.py --skip-rocm --skip-cuda
   python tools/deploy_redist.py --platform OSXARM64
   ```
   Linux is deployed **without ROCm and CUDA** (owner, 2026-11-19): the
   base depot holds the CPU and Vulkan backends; ROCm comes as the HIP
   DLC (`steam_stage.py`, part 10).
   (`--platform OSX64` as well if you build for Intel Macs.) Each run
   replaces only that platform's entries.

   `--skip-rocm` / `--skip-cuda` use `redistributable_bin/Linux64/parts.txt`
   (written by collect), else the files' names. Without them (a test of
   everything on one Linux box) every backend is deployed.
4. Reopen the projects.

Repeat 1 - 4 whenever the Linux or Mac libraries are rebuilt.

---

## 8. Build the Delphi packages

On Windows, in Delphi. For **each platform you target** (Win64, Linux64,
OSXARM64, OSX64 - select it under the package in the Projects window), and
in this order:

| # | Group (`.groupproj`) | Build | Install (IDE) |
|---|---|---|---|
| 1 | `<repos>\TFFMpegAPI\FFmpegAPI.groupproj` | `FFmpegAPI`, `FFmpegAPIFMX` | `dclFFmpegAPIFMX` |
| 2 | `<repos>\TWhisper\WhisperAPI.groupproj` | `WhisperAPI`, `WhisperAPIFMX` | `dclWhisperAPIFMX` |
| 3 | `<repos>\TSteamAPI\Steamworks.groupproj` (Steam builds) | `Steamworks`, `SteamworksFMX` | optional |
| 4 | `<repos>\Epubunum\EpubUnum.groupproj` | `EpubUnum`, `EpubUnumFMX` | `dclEpubUnumFMX` |

The runtime packages write their units to Delphi's `Dcp` folder
(`$(BDSCOMMONDIR)\Dcp\<platform>`), where the programs find them - no
search paths needed, but **only for platforms you built them for**. With
the 32-bit IDE, build the runtime packages for Win32 too before installing
the design packages.

---

## 9. Build and deploy each program

Configurations: **Debug** / **Release** (no Steam), **SteamDebug** /
**Steam** (Steam builds, `STEAMBUILD` defined). Every build first runs
`tools\buildstamp.bat` (the build's date and commit, shown in the debug
log).

### Win64

Choose the configuration and **Build**. The post-build step
(`tools\postbuild.bat`) copies everything the program needs next to the
`.exe` - see the table in part 1. The output folder is then complete:

```
<repos>\Epubunum\demos\EpubReader\Win64\<Config>\
<repos>\Epubunum\demos\EpubBuilder\Win64\<Config>\
```

A Steam configuration **fails** if `redistributable_bin\Win64` or
`redistributable_bin\steam\win64\steam_api64.dll` is missing; Debug /
Release only warn.

### Linux64

1. Start PAServer on the Linux box; in Delphi select the Linux64 platform
   and its connection profile.
2. Choose the configuration, **Build**, then **Deploy** (Project > Deploy).
3. The program and everything from part 7 land in PAServer's folder on the
   Linux box: `~/PAServer/scratch-dir/<user>-<profile>/<program>/`
   (the exact path is in PAServer's output).

`EpubReader.sh` / `EpubBuilder.sh` are deployed with their programs. They
must be **executable** and are what Steam starts on Linux. If PAServer
dropped the executable bit:

```
chmod +x EpubReader.sh EpubBuilder.sh
```

Without Delphi's Deploy (a program built some other way), put the
libraries next to it on the Linux box:

```
cd <repos>/Epubunum
sh tools/redist.sh deploy Linux64 <program-folder>
```

### macOS (OSXARM64 / OSX64)

1. Start PAServer on the Mac; in Delphi select **macOS ARM 64-bit** (the
   compiler is then `dccosxarm64`; `dccosx64` means Intel - see part 13)
   and its connection profile.
2. Choose the configuration, **Build**, then **Deploy**.
3. The `.app` is in PAServer's folder on the Mac
   (`~/PAServer/scratch-dir/<user>-<profile>/`). Deploy has put the
   libraries into `Contents/Frameworks`, the licences into
   `Contents/Resources/licences`, the reference texts into
   `Contents/Resources/media`, and (Steam configurations) the Steam
   library into `Contents/MacOS`, before the bundle is signed.

Without Delphi's Deploy, on the Mac:

```
cd <repos>/Epubunum
sh tools/redist.sh deploy OSXARM64 <path>/EpubBuilder.app
sh tools/redist.sh deploy OSXARM64 <path>/EpubReader.app
```

It signs the copied libraries ad hoc, or with your identity:
`CODESIGN_ID="Developer ID Application: ..." sh tools/redist.sh deploy ...`.
(For a Steam build made this way, also copy
`redistributable_bin/steam/osx/libsteam_api.dylib` into
`<app>/Contents/MacOS/`.)

---

## 10. Steam depots

| Depot | Contents |
|---|---|
| Windows | the Win64 **Steam** output folder of each program, as it is |
| Mac | the `.app` from PAServer's folder (Steam configuration) |
| Linux | the Linux64 **Steam** program folder from PAServer, after `steam_stage.py` (below) |
| HIP (DLC, Linux) | made by `steam_stage.py` |

On Linux the GPU runtimes are large and only some users need them, so the
ROCm part (and the CUDA part, when there is one) goes into its own DLC
depot. Arrange a deployment folder for SteamPipe with one subfolder per
depot (`Linux`, `HIP`, ...), copy the Linux program folder into `Linux`,
then on the Windows machine:

```
cd <repos>\Epubunum
python tools/steam_stage.py <deployment-folder> --dry-run
python tools/steam_stage.py <deployment-folder>
```

It moves the ROCm files from `Linux` into `HIP` and completes `HIP` from
`redistributable_bin/Linux64` (kernel folders, ROCm licences), using
`redistributable_bin/Linux64/parts.txt`. Run it after each Linux build,
before uploading.

**Mac depot:** Delphi's Deploy can only put files inside the `.app`, so
copy `demos/EpubReader/steaminput/` into the Mac depot folder **beside**
the `.app`(s) - Steam reads it from there before either program runs
(each program also writes it there when it starts under Steam, but only
then).

On the Steamworks site, set each Linux launch option to the script, not
the program: `EpubReader.sh` / `EpubBuilder.sh`. EpubReader's Steam Input
setting: *Custom Configuration (Bundled with Game)*, naming
`steaminput/epubreader_controllers.vdf`.

---

## 11. GitHub release packages of the libraries

To publish the collected libraries (for people building the programs
themselves):

```
sh tools/redist.sh package Linux64 [VERSION]          (on Linux)
sh tools/redist.sh package OSXARM64 [VERSION]         (on the Mac)
tools\redist.bat package [VERSION]                    (on Windows)
```

→ `redistributable_bin/packages/`: `core`, `cuda` and `rocm` parts (macOS:
`core` only), each with its licences and a read-me, plus
`SHA256SUMS-<platform>-<version>.txt`. VERSION defaults to today's date. A
part over GitHub's 2 GiB per-file limit is reported.

---

## 12. Checks

### The collected folders

| Folder | Must contain at least |
|---|---|
| `redistributable_bin/Win64/` | `whisper.dll`, `ggml.dll`, `ggml-base.dll`, `ggml-cpu-*.dll`, `ggml-vulkan.dll`, `avutil-60.dll`, `avcodec-62.dll`, `avformat-62.dll`, `swresample-6.dll`, `licences/` |
| `redistributable_bin/Linux64/` | `libwhisper.so*`, `libggml*.so*`, `libggml-cpu-*.so`, `libggml-vulkan.so`, `libavutil.so.60`, `libfreetype.so.6`, `libgomp.so.1`, `licences/`, `parts.txt` |
| `redistributable_bin/OSXARM64/` | `libwhisper*.dylib`, `libwhisper.coreml.dylib`, `libggml*.dylib`, `libggml-cpu-*.so`, `libggml-metal.so`, `libavutil.60.dylib`, `licences/` |
| `redistributable_bin/steam/` | `win64/steam_api64.dll`, `linux64/libsteam_api.so`, `osx/libsteam_api.dylib` |

### The programs

Start each program once and look at its debug log (Windows:
`%APPDATA%\<program>\`, Linux: `~/.config/<program>/`, macOS:
`~/Library/Application Support/<program>/`, file `<program>-debug.log`):

- the build stamp (date and commit) is the build you made;
- EpubBuilder: the whisper.cpp line names the program's own folder (macOS:
  `Contents/Frameworks`), and the device list has the backends expected
  (Windows Steam: CPU + Vulkan; macOS: CPU + MTL0, "COREML = 1");
- EpubReader plays sound (FFmpeg found);
- Steam builds: Steam is found, and the reader's pad works.

EpubBuilder: run **Calibrate** once on each platform - it proves every
backend loads and times them.

---

## 13. When something goes wrong

| Message | Cause | Fix |
|---|---|---|
| `F1027 Unit not found: 'Steamworks.Types'` / `F2613` | TSteamAPI's packages are not built for this platform - or the wrong platform is selected (`dccosx64` = Intel Mac, `dccosxarm64` = Apple silicon) | select the right platform; build `Steamworks` + `SteamworksFMX` for it (part 8) |
| `Cannot find FFmpegAPI.dcp` / a missing `Whisper.*` unit | TFFMpegAPI / TWhisper packages not built for this platform | part 8, in order |
| `postbuild: no libraries in ...redistributable_bin\Win64` | collect not run on Windows | part 5 |
| `postbuild: no redistributable_bin\steam\win64\steam_api64.dll` | Steam library not copied | part 6 |
| `postbuild: copying ... failed (code 8)` | the program is still running (files in use) | close it, build again |
| Deploy reports files missing (Linux / Mac) | `deploy_redist.py` names files not on this machine | part 7, step 1 |
| A Clean emptied the Linux folder / the `.app` | normal | Deploy again - the entries from part 7 put everything back |
| `GLIBC_2.xx not found` on another Linux | libraries built outside the container | part 4b |
| EpubReader crashes on its first page in Steam (Linux) | no FreeType 2.11.1 next to it, or not started through `EpubReader.sh` | part 5 (Docker / Podman for collect); launch option = the script |
| EpubBuilder on the Mac lists no Metal device | `libggml-metal.so` missing | part 4c, then 5 and 7 |
| A Steam build on Linux has no AMD GPU | the HIP DLC depot is not installed | part 10 |
| The calibration asks for a recording | no reference-text recordings in `media/` when building / deploying, or (Linux, Mac) `deploy_redist.py --media-only` not run since `media/` changed | part 6 |
