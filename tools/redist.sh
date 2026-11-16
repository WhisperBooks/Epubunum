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
#     with their licence texts
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
#     other there through $ORIGIN; EpubReader.sh goes along when
#     EpubReader is there) or its .app (macOS: the libraries into
#     Contents/Frameworks, signed - ad hoc, or with the identity in
#     CODESIGN_ID - and the licences into Contents/Resources/licences)
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
  fi
  # licences: FFmpeg (LGPL - its texts and the build's configure line go
  # with the libraries) and whisper.cpp (MIT)
  for f in COPYING.LGPLv2.1 COPYING.LGPLv3 LICENSE.md BUILD-INFO.txt; do
    [ -f "$FDIR/$f" ] && cp "$FDIR/$f" "$OUT/licences/FFmpeg-$f"
  done
  [ -f "$1/whisper.cpp/LICENSE" ] && cp "$1/whisper.cpp/LICENSE" "$OUT/licences/whisper.cpp-LICENSE.txt"
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
      if [ -f "$TARGET/EpubReader" ]; then
        cp "$ROOT/demos/EpubReader/src/EpubReader.sh" "$TARGET/"
        chmod +x "$TARGET/EpubReader.sh"
      fi
      echo "Libraries copied next to the program in $TARGET"
      ;;
    OSX64|OSXARM64)
      case $TARGET in
        *.app|*.app/) ;;
        *) echo "On macOS TARGET is the program's .app"; exit 1 ;;
      esac
      mkdir -p "$TARGET/Contents/Frameworks" "$TARGET/Contents/Resources/licences"
      cp -a "$SRC"/*.dylib "$TARGET/Contents/Frameworks/"
      cp -a "$SRC"/licences/. "$TARGET/Contents/Resources/licences/"
      for f in "$TARGET"/Contents/Frameworks/*.dylib; do
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
    # shares with every backend
    CORE_RE='^lib(ggml-base|ggml|whisper|gomp)\.so'
    [ -f "$SRC/libggml-cuda.so" ] && needs_in "$SRC" libggml-cuda.so | grep -v -E "$CORE_RE" | sort -u > "$TMP/cuda"
    if [ -f "$SRC/libggml-hip.so" ]; then
      needs_in "$SRC" libggml-hip.so | grep -v -E "$CORE_RE" > "$TMP/rocm"
      for k in rocblas hipblaslt; do [ -d "$SRC/$k" ] && echo "$k" >> "$TMP/rocm"; done
      sort -u -o "$TMP/rocm" "$TMP/rocm"
    fi
    PARTS="core cuda rocm"
  else
    PARTS="core"
  fi
  grep -v -x -F -f "$TMP/cuda" "$ALL" | grep -v -x -F -f "$TMP/rocm" > "$TMP/core" || true
  # licences: NVIDIA's and ROCm's with their part, the rest with core
  for f in $(cd "$SRC" && ls licences 2>/dev/null); do
    case $f in
      CUDA-*) echo "licences/$f" >> "$TMP/cuda" ;;
      ROCm-*) echo "licences/$f" >> "$TMP/rocm" ;;
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
