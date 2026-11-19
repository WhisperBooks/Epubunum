# Windows on Arm (Arm64EC) - tests and notes

Whether EpubReader and EpubBuilder can be built for Windows on Arm, and how
to find out. Nothing here is done yet: this is the plan, the known facts
and the risks, with a probe program (`notes/Arm64ECProbe.dpr`) for the
first test.

## Contents

1. [What Delphi offers](#1-what-delphi-offers)
2. [What it means for this project](#2-what-it-means-for-this-project)
3. [Test machines](#3-test-machines)
4. [Test 1 - the probe](#4-test-1---the-probe)
5. [Test 2 - TWhisper's console](#5-test-2---twhispers-console)
6. [Test 3 - FFmpeg](#6-test-3---ffmpeg)
7. [Test 4 - the programs](#7-test-4---the-programs)
8. [Test 5 - native Arm64EC libraries (later)](#8-test-5---native-arm64ec-libraries-later)
9. [Results](#9-results)
10. [Work after the tests](#10-work-after-the-tests)

---

## 1. What Delphi offers

- **Delphi 13.1** added a Windows on Arm target; it produces **Arm64EC**
  programs (Microsoft's "emulation compatible" ABI: native Arm code that
  can call x64 code in the same process). 13.2 fixed much of it (linking,
  debugging, exceptions, floating point, generics, imported functions,
  resources) and added a FastMM4-based memory manager. We use **13.2**.
- The target is in the **64-bit IDE only**.
- The programs need **Windows 11 on Arm** (not Windows 10 on Arm) and do
  **not run on x64 Windows** - an x64 machine can build them, not run them.
- **VCL and FireMonkey** work. Whether **Skia** (`sk4d.dll`, which our
  programs draw with) is there for the target is not documented - test 4
  shows it.
- **No runtime packages (BPLs)** for the target. Design packages still
  work, and units from packages are linked in - which is how our programs
  use EpubUnum, TWhisper, TFFMpegAPI and TSteamAPI anyway.
- **No inline assembler.** Epubunum, TWhisper and TFFMpegAPI have none.
  TSteamAPI's `Steamworks.Plugin.MatchmakingServers.pas` has 32-bit x86
  thunks; the programs do not use that plugin.
- **DLLs:** an Arm64EC process loads **x64** and **Arm64EC** DLLs (and
  ARM64X ones, which hold both). It does **not** load pure **ARM64** DLLs
  (`LoadLibrary` error 193).
- `TOSVersion.Architecture` reports x64 in an Arm64EC program (Microsoft's
  compatibility choice); the probe uses `IsWow64Process2` to see the real
  machine.
- Do not strip the relocation table (`{$SetPEFlags 1}`): it crashes under
  the emulator.

Source: Embarcadero's DocWiki page "Arm64EC" (RAD Studio) and the 13.1 /
13.2 release notes.

---

## 2. What it means for this project

### 2a. The C calling convention - the main risk

Arm64EC code calls C the **x64 way** (parameters, returned records), so
that it can call x64 DLLs directly. Two places in our libraries choose the
convention by the compiler's CPU symbol:

| Where | Today | Under Arm64EC |
|---|---|---|
| TWhisper `lib/Whisper.inc` | `WHISPER_CPUX64` (from `CPUX64`) turns on `WHISPER_SRET_AS_PARAM` (a returned record - `whisper_full_default_params` and others - as a hidden first parameter); `WHISPER_CPUARM64` (from `CPUARM64`) selects the ARM64 rules | must get the **x64** rules |
| TSteamAPI `lib/Steamworks.inc` + `lib/plugins/Steamworks.Plugin.Input.pas` | `STEAMWORKS_CPUARM64` selects the ARM64 return of `GetMotionData` (hidden pointer in register X8) | must get the **x64** way |

If the Arm64EC compiler defines `CPUARM64` (and not `CPUX64`), both pick
ARM64 rules and the calls go wrong: garbage parameters or a crash in
transcription and in the pad code. **Test 1 tells which symbols it
defines**; the fix is then a few lines in each `.inc`, e.g. an
`ARM64EC`-style define that counts as x64 for the ABI. TWhisper's
`tools/verify_layout.py` (clang's lowering for 9 targets) should gain the
`arm64ec-pc-windows-msvc` target, and `WhisperConsole --check` (test 2)
proves it against the real library.

### 2b. The libraries

| Library | Route 1: x64 DLLs (today's Win64 set) | Route 2: Arm64EC builds |
|---|---|---|
| whisper.cpp + ggml | loads; CPU code runs **emulated** (slow); the Vulkan backend works only if the GPU driver offers Vulkan to an emulated x64 library (test 1) | native speed; not built by whisper-dev yet, ggml untested as Arm64EC |
| FFmpeg | loads, emulated - fine for decoding audio | not built by ffmpeg-dev yet |
| `steam_api64.dll` | loads (x64) | Valve's; only x64 / ARM64 exist - x64 it is |
| `sk4d.dll` (Skia) | whatever Delphi deploys for the target | - |

A plain **ARM64** build of any of these would **not** load into the
program - it must be x64, Arm64EC or ARM64X.

### 2c. GPUs on Windows on Arm

- **Qualcomm Snapdragon (Adreno):** Vulkan drivers exist for native Arm
  programs; whether the x64 or Arm64EC side of a process can use them is
  what test 1 shows (`vulkan-1.dll` loaded, devices listed).
- **NVIDIA GPU machines on Arm (CUDA expected):** CUDA needs NVIDIA's
  `nvcuda.dll` to load into our process (x64, Arm64EC or ARM64X - a pure
  ARM64 one would not), and ggml-cuda built for a matching target with a
  CUDA toolkit that supports it. Test 1 shows whether the driver loads
  and lists the GPU.
- **ROCm / HIP:** not on Windows on Arm.
- **A VM** (VMware on a Mac): a virtual GPU - expect no usable Vulkan
  device and no CUDA. CPU only.

### 2d. Steam

`steam_api64.dll` (x64) loads into an Arm64EC process. Whether the Steam
client itself runs on Windows on Arm, and launches the program, is to be
tested (test 4).

---

## 3. Test machines

| Machine | Good for | Not for |
|---|---|---|
| Windows x64 + Delphi 13.2 (64-bit IDE) | building everything | running the Arm64EC builds |
| **Windows 11 on Arm VM** (VMware Fusion on the Mac) | tests 1 - 4: symbols, DLL loading, ABI (`--check`), FMX / Skia start, sound | speed (CPU only, emulated, virtualised); GPUs |
| **Snapdragon laptop** (rented) | Adreno Vulkan, real CPU speed, route 1 vs route 2 timings | CUDA |
| **NVIDIA Arm PC** (when available) | CUDA | - |

Copy files to the VM through a shared folder or the network; build on the
x64 machine.

---

## 4. Test 1 - the probe

`notes/Arm64ECProbe.dpr` is a console program that prints:

1. the compiler's conditional symbols (`CPUX64`, `CPUARM64`, `WIN64`,
   `ARM64EC`-style names, `LLVM`, `ASSEMBLER`, ...);
2. the process and the machine (`IsWow64Process2`), and the probe's own
   PE machine type;
3. **Vulkan:** whether `vulkan-1.dll` loads (and from where, which machine
   type), the devices it lists - name, integrated / discrete / virtual /
   CPU, vendor, Vulkan version;
4. **CUDA:** whether `nvcuda.dll` loads (where, machine type), the driver's
   CUDA version, the devices with their memory;
5. **DLLs:** each DLL named on the command line, and `whisper.dll`,
   `ggml-base.dll`, `ggml.dll`, `avutil-60.dll`, `steam_api64.dll` when
   they are next to the probe - loaded or not (error 193 = wrong machine
   type), with the file's machine type.

### Steps

1. Delphi 13.2, **64-bit IDE**: File > Open `notes\Arm64ECProbe.dpr`. Delphi
   makes a `.dproj` for it (not tracked - leave it out of git, or delete
   it afterwards).
2. Projects window > Target Platforms > Add Platform: the **Windows Arm64EC**
   platform. Build. Also build for **Windows 64-bit**.
3. Make a test folder with:
   - `Arm64ECProbe.exe` (the Arm64EC build);
   - the contents of `redistributable_bin\Win64` (route 1's DLLs) -
     whisper, ggml, FFmpeg - and `redistributable_bin\steam\win64\steam_api64.dll`.
4. Copy the folder to the Arm machine (VM, laptop). In a command prompt
   there:
   ```
   Arm64ECProbe > probe-arm64ec.txt
   ```
5. On the x64 machine, the Win64 build in the same kind of folder:
   ```
   Arm64ECProbe > probe-win64.txt
   ```
6. Keep both files (and one per Arm machine): they go into section 9.

### Reading the output

| Seen | Means | Next |
|---|---|---|
| `CPUX64 True` under Arm64EC | the `.inc` files already take the x64 ABI | test 2 as it is |
| `CPUARM64 True`, `CPUX64 False` | the `.inc` files would take ARM64 rules - wrong | fix `Whisper.inc` / `Steamworks.inc` first (an Arm64EC symbol, if one is listed True, decides it) |
| both True | depends on the order of the `.inc` tests | fix explicitly for Arm64EC |
| `whisper.dll: loaded ... x64` | route 1 possible | test 2 |
| `error 193` for a DLL | that DLL's type cannot load here | route 2 for it, or another build |
| Vulkan: devices listed, not `CPU` / `virtual GPU` type | ggml-vulkan has a real GPU here | time it in test 4 |
| Vulkan: `NOT loaded` or `-9` | no Vulkan for this process | CPU only on this machine |
| CUDA: `CUDA0: <name>` | the driver works from this process | ggml-cuda for this target is worth building |
| CUDA: `NOT loaded ... 193` | NVIDIA's driver DLL is pure ARM64 | CUDA only from a native ARM64 program, not Arm64EC |

---

## 5. Test 2 - TWhisper's console

The real ABI test: TWhisper checks its structs and calls against the
library itself.

1. On the x64 machine, build for **Windows Arm64EC** (after test 1's fixes,
   if any): TFFMpegAPI's `FFmpegAPI`, TWhisper's `WhisperAPI`, then
   TWhisper's `demos\WhisperConsole`.
2. Folder: `WhisperConsole.exe` + `redistributable_bin\Win64` + a model
   (`ggml-base.en.bin`, small) + a short WAV (whisper.cpp's `jfk.wav`, 11 s).
3. On the Arm machine:
   ```
   WhisperConsole --check > check.txt
   WhisperConsole --bench ggml-base.en.bin jfk.wav > bench.txt
   ```
4. `--check`: the layout check must pass and the device list appear.
   `--bench`: a transcription that reads correctly, and a time per device.

A crash or nonsense text here, with test 1's symbols looking right, means
the record-return ABI is still wrong - send `check.txt`.

---

## 6. Test 3 - FFmpeg

1. Build TFFMpegAPI's `demos\FFmpegConsole` for Arm64EC.
2. Folder: the console + FFmpeg's DLLs from `redistributable_bin\Win64` + a
   short `.m4b` / `.m4a` (not a copy-protected one).
3. On the Arm machine: its probe / info command on the file (see
   TFFMpegAPI's README) - FFmpeg's version and the file's streams and
   chapters must show.

---

## 7. Test 4 - the programs

1. Build EpubUnum's packages, then **EpubReader** and **EpubBuilder** for
   Arm64EC (Release; later Steam). The Win64 post-build step does not run
   for the new platform yet (section 10): copy by hand -
   - next to EpubReader: FFmpeg's DLLs (`av*.dll`, `sw*.dll`), `licences\`;
   - next to EpubBuilder: all of `redistributable_bin\Win64`, `media\aladdin.m4a`;
   - Skia: whatever Delphi deploys for the target (check the output
     folder for `sk4d.dll`).
2. On the Arm machine:
   - **EpubReader:** opens, draws a book (Skia), plays it aloud (FFmpeg),
     dark mode, find; its debug log (`%APPDATA%\EpubReader\EpubReader-debug.log`).
   - **EpubBuilder:** the device list (CPU; Vulkan on real hardware),
     **Calibrate** (times every device - the speed under emulation), then
     one short book; its debug log and the book's `.log`.
3. Steam (later): a SteamDebug build with the Steam client running on the
   Arm machine - Steam found, overlay, pad.

---

## 8. Test 5 - native Arm64EC libraries (later)

Only if route 1 works but the CPU speed under emulation is poor:

- **whisper-dev:** an Arm64EC configuration - Visual Studio's ARM64 tools
  build Arm64EC with `/arm64EC` (CMake: the Visual Studio generator with
  `-A ARM64EC`). ggml's CPU backend would need its Arm (NEON) code paths
  for that target; the GPU backend Vulkan as available. New target folder,
  e.g. `dlls\windows-arm64ec`.
- **ffmpeg-dev:** an Arm64EC target for `build.sh` (MSVC `cl` with
  `/arm64EC`), `dlls\windows-arm64ec`.
- Then the same tests 2 - 4 with those DLLs, and timings against route 1
  on the Snapdragon laptop.

---

## 9. Results

Fill in as the tests run (and keep the probe outputs next to this file
while working - not in git if they hold machine names).

| Date | Machine | Test | Result | Notes |
|---|---|---|---|---|
| | Win11 Arm VM (Mac) | 1 probe | | symbols: ... |
| | Win11 Arm VM (Mac) | 2 `--check` | | |
| | Win11 Arm VM (Mac) | 2 `--bench` base.en | | x real time: ... |
| | Win11 Arm VM (Mac) | 3 FFmpeg | | |
| | Win11 Arm VM (Mac) | 4 reader / builder | | Skia: ... |
| | Snapdragon laptop | 1 probe | | Vulkan devices: ... |
| | Snapdragon laptop | 4 calibration | | CPU ...x, Vulkan ...x |
| | NVIDIA Arm PC | 1 probe | | CUDA: ... |

---

## 10. Work after the tests

What the build system needs once the target works (not done yet):

- **The `.inc` files** (TWhisper, TSteamAPI): the ABI for Arm64EC (test 1);
  `verify_layout.py` with the Arm64EC target.
- **Projects:** the Arm64EC platform in the packages and programs
  (`tools/gen_projects.py`, then the IDE), `tools/project_check.py`
  taught it.
- **`redistributable_bin\WinARM64EC`** (route 1: a copy of the Win64 set
  without CUDA / ROCm; route 2: the Arm64EC builds), `tools\redist.bat`
  for it.
- **`tools\postbuild.bat`**: the new platform's output folder and share
  (FFmpeg for the reader; whisper.cpp CPU + Vulkan, FFmpeg, recording for
  the builder; `steam_api64.dll` for Steam).
- **EpubBuilder:** the device list shows what the Arm machine has; the
  Power row works as on Win64 (EcoQoS is the same API).
- **`notes/Building-distributions.md`**: the platform added to its tables
  and steps.
- **Steam:** an Arm depot, if Steam on Windows on Arm installs it (or
  the x64 build runs emulated - test that too: the plain Win64 build on
  the Arm machine is the fallback that needs no work at all).
