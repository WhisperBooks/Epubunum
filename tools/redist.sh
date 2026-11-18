#!/bin/sh
# Epubunum's redistributables: the whisper.cpp libraries (whisper-dev) and
# FFmpeg's (ffmpeg-dev) together, one folder per Delphi platform in
# redistributable_bin/, and copied to where a built program needs them.
# Epubunum's programs are the ones that are deployed (EpubReader,
# EpubBuilder), so their libraries are collected here.
#
#   tools/redist.sh collect WHISPER_DEV FFMPEG_DEV
#     fills redistributable_bin/<platform>/ for this machine (Linux64;
#     OSXARM64 or OSX64 on a Mac) from WHISPER_DEV/dlls (or WHISPER_DEV
#     itself when it holds the libraries) and FFMPEG_DEV/dlls/<target>,
#     with their licence texts; on Linux also FreeType 2.11.1 from an
#     ubuntu:22.04 container (docker / podman) for Steam's Linux runtime,
#     whose FreeType 2.10.4 crashes Skia
#   tools/redist.sh package PLATFORM [VERSION]
#     packs redistributable_bin/PLATFORM for a release, in
#     redistributable_bin/packages/: Linux64 in three parts that unpack
#     into one folder - core (whisper.cpp, ggml with its CPU and Vulkan
#     backends, FFmpeg, libgomp), cuda (ggml-cuda and NVIDIA's runtime),
#     rocm (ggml-hip, ROCm's runtime and kernels) - each .tar.gz with its
#     licences and a read-me; macOS in one part; SHA256SUMS beside them.
#     VERSION defaults to today's date.
#   tools/redist.sh deploy PLATFORM TARGET
#     copies redistributable_bin/PLATFORM/ to a built program: TARGET is
#     the program's folder (Linux: next to it - the libraries find each
#     other there through $ORIGIN; EpubReader.sh / EpubBuilder.sh go
#     along with their programs) or its .app (macOS: the libraries into
#     Contents/Frameworks, signed - ad hoc, or with the identity in
#     CODESIGN_ID - and the licences into Contents/Resources/licences;
#     by the .app's name: EpubReader FFmpeg only, EpubBuilder the CPU
#     and Metal backends - no Vulkan, CUDA or HIP)
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)

usage() {
  sed -n '/^#   tools\/redist.sh collect/,/^set -e/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'
  exit 1
}

host_platform() {
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) echo Linux64 ;;
    Darwin-arm64) echo OSXARM64 ;;
    Darwin-x86_64) echo OSX64 ;;
    *) echo "No Delphi platform for $(uname -s) $(uname -m)" >&2; exit 1 ;;
  esac
}

ffmpeg_target() {
  case $1 in
    Linux64) echo linux-x64 ;;
    OSXARM64) echo macos-arm64 ;;
    OSX64) echo macos-x64 ;;
  esac
}

# FreeType for Steam Linux Runtime 3 (EpubUnum, 2026-11-17): Skia (libsk4d)
# links the system's libfreetype.so.6, and the runtime's - 2.10.4 - makes
# it crash on the first page it draws (an access violation in
# libfreetype.so.6.17.4); Ubuntu 22.04's 2.11.1, next to the program and
# first on LD_LIBRARY_PATH (EpubReader.sh / EpubBuilder.sh), was tested on
# the Steam Deck and works. Taken from an ubuntu:22.04 container (glibc
# 2.35, as the other Linux libraries), with brotli (FreeType needs it) and
# both licence texts. Needs docker or podman; without either: a warning.
freetype_for_runtime() {
  OUT=$1
  RUN=$(command -v docker || command -v podman || true)
  if [ -z "$RUN" ]; then
    echo "Warning: no docker / podman - no FreeType for Steam's Linux runtime in $OUT"
    echo "  (EpubReader crashes there on the first page without it)"
    return 0
  fi
  "$RUN" run --rm -v "$OUT:/out:z" ubuntu:22.04 sh -c '
    apt-get update -qq && apt-get install -y -qq libfreetype6 > /dev/null &&
    L=/usr/lib/x86_64-linux-gnu &&
    cp -L $L/libfreetype.so.6 $L/libbrotlidec.so.1 $L/libbrotlicommon.so.1 /out/ &&
    cp /usr/share/doc/libfreetype6/copyright /out/licences/FreeType-copyright.txt &&
    cp /usr/share/doc/libbrotli1/copyright /out/licences/brotli-copyright.txt &&
    chmod a+r /out/libfreetype.so.6 /out/libbrotli*.so.1 /out/licences/FreeType-* /out/licences/brotli-*' \
    || { echo "Warning: FreeType for Steam's Linux runtime not fetched"; return 0; }
  echo "FreeType 2.11.1 (Ubuntu 22.04) for Steam's Linux runtime: libfreetype.so.6, libbrotli*.so.1"
}

collect() {
  [ $# -eq 2 ] || usage
  PLATFORM=$(host_platform)
  WDIR=$1/dlls
  [ -d "$WDIR" ] || WDIR=$1
  FDIR=$2/dlls/$(ffmpeg_target "$PLATFORM")
  ls "$WDIR"/libwhisper.* > /dev/null 2>&1 || { echo "No whisper.cpp libraries in $WDIR: run whisper-dev's ./build.sh"; exit 1; }
  ls "$FDIR"/libavutil.* > /dev/null 2>&1 || { echo "No FFmpeg libraries in $FDIR: run ffmpeg-dev's ./build.sh"; exit 1; }
  OUT=$ROOT/redistributable_bin/$PLATFORM
  rm -rf "$OUT"
  mkdir -p "$OUT/licences"
  # the libraries as built (each in its soname / plain-name copies)
  if [ "$PLATFORM" = Linux64 ]; then
    cp -a "$WDIR"/*.so* "$FDIR"/*.so* "$OUT"/
    # ROCm's kernel files beside rocBLAS / hipBLASLt (whisper-dev bundles
    # them for its HIP targets): HIP does not run without them
    for k in rocblas hipblaslt; do
      [ -d "$WDIR/$k" ] && cp -a "$WDIR/$k" "$OUT"/
    done
    # the bundled CUDA / ROCm / libgomp licences (whisper-dev's bundler)
    [ -d "$WDIR/licences" ] && cp -a "$WDIR"/licences/. "$OUT"/licences/
  else
    cp -a "$WDIR"/*.dylib "$FDIR"/*.dylib "$OUT"/
    # ggml's backends (GGML_BACKEND_DL): CMake MODULE libraries, named
    # lib*.so on macOS too - ggml looks for ".so" on every system but
    # Windows (libggml-cpu-*.so, libggml-metal.so, libggml-blas.so)
    for f in "$WDIR"/libggml-*.so; do
      [ -f "$f" ] && cp -a "$f" "$OUT"/
    done
    ls "$OUT"/libggml-cpu*.so > /dev/null 2>&1 || echo "WARNING: no libggml-cpu*.so in $WDIR - EpubBuilder will have no CPU backend"
    ls "$OUT"/libggml-metal*.so > /dev/null 2>&1 || echo "WARNING: no libggml-metal.so in $WDIR - EpubBuilder will have no Metal backend"
  fi
  # licences: FFmpeg (LGPL - its texts and the build's configure line go
  # with the libraries) and whisper.cpp (MIT)
  for f in COPYING.LGPLv2.1 COPYING.LGPLv3 LICENSE.md BUILD-INFO.txt; do
    [ -f "$FDIR/$f" ] && cp "$FDIR/$f" "$OUT/licences/FFmpeg-$f"
  done
  [ -f "$1/whisper.cpp/LICENSE" ] && cp "$1/whisper.cpp/LICENSE" "$OUT/licences/whisper.cpp-LICENSE.txt"
  # EpubBuilder's calibration recording (media/aladdin.m4a, not committed):
  # media/ beside the program (Linux), Contents/Resources/media (macOS)
  if [ -f "$ROOT/media/aladdin.m4a" ]; then
    mkdir -p "$OUT/media"
    cp "$ROOT/media/aladdin.m4a" "$OUT/media/"
  else
    echo "WARNING: no media/aladdin.m4a in $ROOT - EpubBuilder's calibration will ask for a recording"
  fi
  [ "$PLATFORM" = Linux64 ] && freetype_for_runtime "$OUT"
  # Linux: which files are the CUDA and ROCm parts (Steam DLC depots,
  # release packages), for tools on machines without ldd
  # (steam_stage.py)
  if [ "$PLATFORM" = Linux64 ]; then
    PT=$(mktemp -d)
    part_lists "$OUT" "$PT"
    { sed 's/^/rocm /' "$PT/rocm"; sed 's/^/cuda /' "$PT/cuda"; } > "$OUT/parts.txt"
    echo "parts.txt: $(wc -l < "$PT/rocm") ROCm entries, $(wc -l < "$PT/cuda") CUDA entries"
    rm -rf "$PT"
  fi
  echo "$(ls "$OUT" | grep -c -v licences) files in $OUT"
}

deploy() {
  [ $# -eq 2 ] || usage
  SRC=$ROOT/redistributable_bin/$1
  TARGET=$2
  [ -d "$SRC" ] || { echo "No $SRC: run tools/redist.sh collect on that platform first"; exit 1; }
  [ -d "$TARGET" ] || { echo "No folder $TARGET"; exit 1; }
  case $1 in
    Linux64)
      cp -a "$SRC"/. "$TARGET"/
      # each program's launcher (the ICU fix for Steam's Linux runtime)
      for prog in EpubReader EpubBuilder; do
        if [ -f "$TARGET/$prog" ]; then
          cp "$ROOT/demos/$prog/src/$prog.sh" "$TARGET/"
          chmod +x "$TARGET/$prog.sh"
        fi
      done
      echo "Libraries copied next to the program in $TARGET"
      ;;
    OSX64|OSXARM64)
      case $TARGET in
        *.app|*.app/) ;;
        *) echo "On macOS TARGET is the program's .app"; exit 1 ;;
      esac
      mkdir -p "$TARGET/Contents/Frameworks" "$TARGET/Contents/Resources/licences"
      # by program (the .app's name): EpubReader plays sound - FFmpeg only;
      # EpubBuilder - the CPU and Metal backends (Vulkan, CUDA and HIP
      # are left out: GPU backends other than the platform's own are to be
      # free DLC - owner, 2026-11-17)
      APP=$(basename "${TARGET%/}" .app)
      # *.dylib, and ggml's backend modules (lib*.so on macOS too)
      for f in "$SRC"/*.dylib "$SRC"/*.so; do
        [ -e "$f" ] || continue
        n=$(basename "$f")
        case $APP in
          EpubReader*) case $n in libav*|libsw*|libpostproc*) ;; *) continue ;; esac ;;
          *) case $n in *vulkan*|*cuda*|*hip*) continue ;; esac ;;
        esac
        cp -a "$f" "$TARGET/Contents/Frameworks/"
      done
      case $APP in
        EpubReader*) cp -a "$SRC"/licences/FFmpeg-* "$TARGET/Contents/Resources/licences/" 2>/dev/null || true ;;
        *) cp -a "$SRC"/licences/. "$TARGET/Contents/Resources/licences/"
           # the calibration recording (uCalibration looks there first)
           if [ -d "$SRC/media" ]; then
             mkdir -p "$TARGET/Contents/Resources/media"
             cp -a "$SRC"/media/. "$TARGET/Contents/Resources/media/"
           fi ;;
      esac
      for f in "$TARGET"/Contents/Frameworks/*.dylib "$TARGET"/Contents/Frameworks/*.so; do
        [ -e "$f" ] || continue
        [ -L "$f" ] || codesign --force --sign "${CODESIGN_ID:--}" "$f"
      done
      echo "Libraries copied into $TARGET/Contents/Frameworks and signed (${CODESIGN_ID:-ad hoc})"
      ;;
    *) echo "Unknown platform $1 (Linux64, OSX64, OSXARM64; Windows: tools\\redist.bat)"; exit 1 ;;
  esac
}

# the names in folder $1 that library $2 needs (directly or through
# others) and that are in that folder, the library itself included
needs_in() {
  echo "$2"
  LD_LIBRARY_PATH="$1" ldd "$1/$2" 2>/dev/null \
    | sed -n 's/^[[:space:]]*\([^ ]*\) => \([^ ]*\) .*/\1 \2/p' \
    | while read -r name path; do
        [ "$(dirname "$path")" = "$1" ] && echo "$name"
      done
}

# the GPU parts of Linux libraries in folder $1, written to $2/cuda and
# $2/rocm (one name a line): what libggml-cuda.so / libggml-hip.so need
# from the folder (ldd), each library with ALL its names (libX.so,
# libX.so.N, libX.so.N.M.P - not only the one ldd names), minus the core
# every backend shares; ROCm's kernel folders; the CUDA / ROCm licences
part_lists() {
  : > "$2/cuda"
  : > "$2/rocm"
  CORE_RE='^lib(ggml-base|ggml|whisper|gomp)\.so'
  for b in cuda hip; do
    [ -f "$1/libggml-$b.so" ] || continue
    out=$2/cuda
    [ $b = hip ] && out=$2/rocm
    needs_in "$1" "libggml-$b.so" | grep -v -E "$CORE_RE" | while read -r n; do
      stem=${n%%.so*}.so
      # (if, not &&: a name that is not there must not end the script)
      (cd "$1" && for f in "$stem" "$stem".*; do if [ -e "$f" ]; then echo "$f"; fi; done)
    done > "$out.tmp"
    sort -u "$out.tmp" > "$out"
    rm -f "$out.tmp"
  done
  for k in rocblas hipblaslt; do
    [ -d "$1/$k" ] && echo "$k" >> "$2/rocm"
  done
  for f in $(cd "$1" && ls licences 2>/dev/null); do
    case $f in
      CUDA-*) echo "licences/$f" >> "$2/cuda" ;;
      ROCm-*) echo "licences/$f" >> "$2/rocm" ;;
    esac
  done
  return 0
}

# a part's read-me, $1 = part, $2 = version, $3 = platform
part_readme() {
  cat <<EOT
EpubUnum libraries - $3, part "$1", $2

Unpack the parts you need into one folder: next to EpubReader /
EpubBuilder, or a folder on LD_LIBRARY_PATH. The libraries find each
other there (RUNPATH \$ORIGIN).

  core  always: whisper.cpp, ggml (CPU variants, Vulkan), FFmpeg 8,
        libgomp
  cuda  NVIDIA GPUs (GTX 16xx / RTX 20xx and newer): ggml-cuda, cudart,
        cuBLAS. Needs NVIDIA's driver 580 or newer.
  rocm  AMD GPUs (RDNA 2 - 4): ggml-hip, the ROCm runtime and kernels.
        Needs the amdgpu kernel driver.

Licences are in licences/: FFmpeg (LGPL; its configure line in
FFmpeg-BUILD-INFO.txt - source: https://ffmpeg.org/releases/ for that
version), whisper.cpp (MIT; source: https://github.com/ggml-org/whisper.cpp),
GCC's libgomp (GPL with the runtime library exception), NVIDIA's CUDA
EULA (cudart / cuBLAS are redistributable under its attachment A) and
the ROCm packages' copyright files.
EOT
}

package() {
  [ $# -ge 1 ] || usage
  PLAT=$1
  VERSION=${2:-$(date +%Y%m%d)}
  SRC=$ROOT/redistributable_bin/$PLAT
  PKG=$ROOT/redistributable_bin/packages
  [ -d "$SRC" ] || { echo "No $SRC: run tools/redist.sh collect on that platform first"; exit 1; }
  mkdir -p "$PKG"
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  ALL=$TMP/all; : > "$ALL"
  (cd "$SRC" && ls -A) | grep -v -x -e README.md -e licences > "$ALL"
  : > "$TMP/cuda"; : > "$TMP/rocm"
  if [ "$PLAT" = Linux64 ]; then
    # what each GPU backend needs from the folder, but not the core it
    # shares with every backend (part_lists - also behind parts.txt)
    part_lists "$SRC" "$TMP"
    PARTS="core cuda rocm"
  else
    PARTS="core"
  fi
  grep -v -x -F -f "$TMP/cuda" "$ALL" | grep -v -x -F -f "$TMP/rocm" | grep -v -x parts.txt > "$TMP/core" || true
  # licences: NVIDIA's and ROCm's are in their parts; the rest with core
  for f in $(cd "$SRC" && ls licences 2>/dev/null); do
    case $f in
      CUDA-*|ROCm-*) ;;
      *) echo "licences/$f" >> "$TMP/core" ;;
    esac
  done
  : > "$TMP/sums"
  for part in $PARTS; do
    [ -s "$TMP/$part" ] || { echo "$part: nothing in $SRC - left out"; continue; }
    case $part in
      cuda) grep -q '^licences/CUDA-' "$TMP/cuda" || echo "Warning: no CUDA licence file (build whisper-dev in its container)" ;;
      rocm) grep -q '^licences/ROCm-' "$TMP/rocm" || echo "Warning: no ROCm licence files (build whisper-dev in its container)" ;;
    esac
    NAME=EpubUnum-libs-$PLAT-$part-$VERSION.tar.gz
    mkdir -p "$TMP/readme-$part"
    part_readme "$part" "$VERSION" "$PLAT" > "$TMP/readme-$part/EpubUnum-libs-$part.txt"
    # the names as they are: links stay links, folders whole
    tar czf "$PKG/$NAME" -C "$SRC" -T "$TMP/$part" -C "$TMP/readme-$part" "EpubUnum-libs-$part.txt"
    SIZE=$(wc -c < "$PKG/$NAME")
    echo "$NAME: $(wc -l < "$TMP/$part") entries, $((SIZE / 1048576)) MB"
    [ "$SIZE" -gt 2147483648 ] && echo "Warning: $NAME is over GitHub's 2 GiB per file"
    echo "$NAME" >> "$TMP/sums"
  done
  (cd "$PKG" && if command -v sha256sum > /dev/null; then sha256sum $(cat "$TMP/sums"); else shasum -a 256 $(cat "$TMP/sums"); fi) \
    > "$PKG/SHA256SUMS-$PLAT-$VERSION.txt"
  echo "In $PKG, with SHA256SUMS-$PLAT-$VERSION.txt"
}

case $1 in
  collect) shift; collect "$@" ;;
  package) shift; package "$@" ;;
  deploy) shift; deploy "$@" ;;
  *) usage ;;
esac
