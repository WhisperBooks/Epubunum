#!/bin/sh
# Linux launcher for a Delphi program inside Steam's Linux runtime.
#
# Delphi's runtime looks for ICU (libicuuc / libicui18n) at start-up by
# trying the unversioned names first, then versions 99 down to 40 - and it
# takes libicui18n ONLY in the version it found for libicuuc. On SteamOS,
# Steam Linux Runtime 3.0 brings in the host's libicuuc.so.78 (for the
# graphics drivers) but not libicui18n.so.78, so the runtime binds
# ucol_open to nil and the program dies at once (signal 11, exit code 139).
# See docs/fmx-steamos-icu-bug.md.
#
# This script points the UNVERSIONED names at the newest COMPLETE ICU of the
# runtime itself (both libraries present), so Delphi picks a matching pair.
# Where there is no such pair (a normal desktop), it changes nothing.
#
# It also puts the program's folder first on LD_LIBRARY_PATH when a
# libfreetype.so.6 is there (see the end).
#
# Use: ship it next to the program and make it the game's Linux launch
# command, named <program>.sh - it starts <program>. Named <program>
# itself, it starts <program>.bin (for testing without changing Steam's
# launch settings: rename the program to <program>.bin, copy this as
# <program>).

here=$(dirname "$(readlink -f "$0")")
self=$(basename "$0")
prog="$here/${self%.sh}"
[ "$prog" = "$here/$self" ] && prog="$prog.bin"

libdir=/usr/lib/x86_64-linux-gnu
best=""
for f in "$libdir"/libicui18n.so.[0-9]*; do
  [ -e "$f" ] || continue
  v=${f##*/libicui18n.so.}
  v=${v%%.*}
  case $v in ''|*[!0-9]*) continue ;; esac
  [ -e "$libdir/libicuuc.so.$v" ] || continue
  if [ -z "$best" ] || [ "$v" -gt "$best" ]; then best=$v; fi
done

if [ -n "$best" ]; then
  dir="${XDG_RUNTIME_DIR:-/tmp}/delphi-icu-$best"
  if mkdir -p "$dir" &&
     ln -sf "$libdir/libicuuc.so.$best" "$dir/libicuuc.so" &&
     ln -sf "$libdir/libicui18n.so.$best" "$dir/libicui18n.so"; then
    export LD_LIBRARY_PATH="$dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    echo "launcher: ICU $best for Delphi's runtime ($dir)" >&2
  fi
fi

# EpubUnum's addition (not in TSteamAPI's copy yet): the libraries next to
# the program first, when it ships its own FreeType. Skia (libsk4d) uses
# the system's libfreetype.so.6, and Steam Linux Runtime 3's (2.10.4)
# crashes it on the first page it draws; a newer one next to the program
# is only used when it is found first - before GTK loads the runtime's.
if [ -e "$here/libfreetype.so.6" ]; then
  export LD_LIBRARY_PATH="$here${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  echo "launcher: $here first on LD_LIBRARY_PATH (its own FreeType)" >&2
fi

# EpubBuilder's addition: no gamescope WSI layer. In SteamOS Game Mode
# gamescope's implicit Vulkan layer wraps every Vulkan device, and on
# ggml's compute-only one it aborts the program (vkroots.h: Assertion
# `obj' failed - VkDispatchTableMap<VkQueue_T*>::insert; Steam Machine,
# 2026-11-18, Vulkan0 calibration). EpubBuilder shows nothing through
# Vulkan (FMX draws with OpenGL), so the layer is not needed. The variable
# is the layer's own off switch; nothing reads it outside gamescope.
export DISABLE_GAMESCOPE_WSI=1
echo "launcher: gamescope's Vulkan WSI layer off (ggml's Vulkan device)" >&2

# EpubBuilder's addition: ROCm only on a GPU it has kernels for. ROCm's
# runtime is bundled beside the program (libamdhip64) with rocBLAS's
# kernels for its HIP targets (rocblas/). Without kernels for the GPU -
# none shipped at all (the runtime left in the Linux depot without the HIP
# depot's kernels, 2026-11-20), or none for this GPU (a Steam Deck's
# gfx1033) - ggml still lists a ROCm device, makes it the default and
# calibrates it, and loading a model on it never comes back. Each GPU's
# target comes from the kernel driver (kfd topology: gfx_target_version
# 100303 = gfx1033, 110002 = gfx1102). No kernels: HIP is shown no device
# (HIP_VISIBLE_DEVICES=-1) and ggml uses Vulkan; EPUBUNUM_ROCM_OFF tells
# EpubBuilder why. A HIP_VISIBLE_DEVICES set by the user, and a ROCm
# installed on the system (not beside the program), are left alone.
if [ -z "${HIP_VISIBLE_DEVICES+x}" ] && ls "$here"/libamdhip64.so* > /dev/null 2>&1; then
  why=""
  if [ ! -d "$here/rocblas" ]; then
    why="no ROCm kernels beside the program (rocblas/ missing)"
  elif [ -d /sys/class/kfd/kfd/topology/nodes ]; then
    gfxs=""
    usable=""
    for p in /sys/class/kfd/kfd/topology/nodes/*/properties; do
      [ -r "$p" ] || continue
      v=$(sed -n 's/^gfx_target_version \([0-9][0-9]*\)$/\1/p' "$p")
      case $v in ''|0) continue ;; esac
      g=$(printf 'gfx%d%x%x' $((v / 10000)) $((v / 100 % 100)) $((v % 100)))
      gfxs="$gfxs $g"
      if [ -n "$(find "$here/rocblas" -name "*$g*" -print -quit 2>/dev/null)" ]; then
        usable="$usable $g"
      fi
    done
    if [ -n "$gfxs" ] && [ -z "$usable" ]; then
      why="no ROCm kernels here for$gfxs"
    elif [ -n "$usable" ]; then
      echo "launcher: ROCm kernels here for$usable" >&2
    fi
  fi
  if [ -n "$why" ]; then
    export HIP_VISIBLE_DEVICES=-1
    export EPUBUNUM_ROCM_OFF="$why"
    echo "launcher: ROCm off - $why; Vulkan instead" >&2
  fi
fi

exec "$prog" "$@"
