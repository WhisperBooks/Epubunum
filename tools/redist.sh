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

case $1 in
  collect) shift; collect "$@" ;;
  deploy) shift; deploy "$@" ;;
  *) usage ;;
esac
