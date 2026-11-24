#!/usr/bin/env python3
"""Splits the GPU backends out of a Steam Linux depot folder into DLC depot
folders, for SteamPipe GUI (owner, 2026-11-18: "My SteamGUI setup has a
folder called Deployment with Win, Mac and Linux folders - could just add a
HIP one?").

    python tools/steam_stage.py DEPLOYMENT [--linux NAME] [--hip NAME]
                                [--cuda NAME] [--dry-run]

DEPLOYMENT is the folder SteamPipe GUI's depots point into; its Linux
folder (--linux, default "Linux") holds the program as Delphi deployed it
(PAServer's folder, copied there as before). The script:

  * moves every file of the ROCm part out of Linux into HIP (--hip,
    default "HIP") - the base depot then has no ROCm; ggml lists the
    CPU and Vulkan only, until the "AMD ROCm acceleration" DLC is
    installed into the program's folder;
  * completes HIP from redistributable_bin/Linux64: the whole ROCm part,
    with rocBLAS's and hipBLASLt's kernel folders (too many files for
    PAServer's Deploy - Later tests 4 - so never in Linux) and the ROCm
    licence texts in licences/;
  * moves the CUDA part out of Linux into CUDA (--cuda, default "CUDA";
    no depot yet - the CUDA DLC comes later), when there is one.

Which files belong to which part comes from redistributable_bin/Linux64/
parts.txt, written by "tools/redist.sh collect" on Linux (it needs ldd):
"rocm NAME" / "cuda NAME" lines; a library is listed with all its names.
In the DLC folder a library is kept under the names the loaders ask for
(libX.so and libX.so.N; libX.so.N.M.P is dropped when a shorter one is
there - as tools/deploy_redist.py does), as plain files (no links).

Without parts.txt (redist.sh collect not run on Linux since zip 110) the
parts are told by name instead - ROCm's and CUDA's libraries as whisper-
dev bundles them (NAME_RULES), the kernel folders, the licences - with a
warning. Both depots install into the same folder, so a helper library
the rules miss stays in the base depot and everything still works; the
base depot is only that much larger.

Run it after each Linux build, before uploading. --dry-run lists what it
would do.
"""
import argparse
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from deploy_redist import wanted_names   # noqa: E402  (same folder)


# the parts by name, when there is no parts.txt: library stems (every
# libX.so* of them) and folders / licence prefixes
NAME_RULES = {
    "rocm": ("libggml-hip.so", "libamdhip64.so", "libhipblas.so", "libhipblaslt.so", "librocblas.so",
             "librocsolver.so", "libamd_comgr.so", "libhsa-runtime64.so", "librocprofiler-register.so",
             "libhiprtc.so", "librocm_smi64.so", "libroctx64.so", "libroctracer64.so",
             "rocblas", "hipblaslt", "licences/ROCm-"),
    "cuda": ("libggml-cuda.so", "libcudart.so", "libcublas.so", "libcublasLt.so", "libnvrtc.so",
             "libnvrtc-builtins.so", "licences/CUDA-"),
}


def parts_by_name(src):
    """The parts from NAME_RULES and the files of src."""
    names = sorted(os.listdir(src))
    lic = os.path.join(src, "licences")
    if os.path.isdir(lic):
        names += ["licences/" + n for n in sorted(os.listdir(lic))]
    parts = {"rocm": [], "cuda": []}
    for kind, rules in NAME_RULES.items():
        for n in names:
            for r in rules:
                if n == r or (r.endswith(".so") and (n == r or n.startswith(r + "."))) or \
                        (r.endswith("-") and n.startswith(r)):
                    parts[kind].append(n)
                    break
    return parts


def read_parts(src):
    """{'rocm': [names], 'cuda': [names]} from src/parts.txt (or by name)."""
    path = os.path.join(src, "parts.txt")
    if not os.path.isfile(path):
        print("WARNING: no %s (tools/redist.sh collect on Linux writes it) - the parts are told by "
              "name" % path)
        return parts_by_name(src)
    parts = {"rocm": [], "cuda": []}
    with open(path, encoding="utf-8") as f:
        for line in f:
            kind, _, name = line.strip().partition(" ")
            if kind in parts and name:
                parts[kind].append(name.replace("\\", "/"))
    return parts


def size_of(path):
    if os.path.isfile(path):
        return os.path.getsize(path)
    total = 0
    for base, _, files in os.walk(path):
        for f in files:
            total += os.path.getsize(os.path.join(base, f))
    return total


def stage(args):
    dep = os.path.abspath(args.deployment)
    linux = os.path.join(dep, args.linux)
    src = os.path.join(ROOT, "redistributable_bin", "Linux64")
    if not os.path.isdir(linux):
        sys.exit("No %s: copy the deployed Linux program there first" % linux)
    if not os.path.isdir(src):
        sys.exit("No %s: tools/redist.sh collect on Linux, then copy the folder here" % src)
    parts = read_parts(src)
    if not parts["rocm"]:
        sys.exit("parts.txt lists no ROCm files: whisper-dev was built without HIP?")
    if not any(n.startswith("libggml-hip.so") for n in parts["rocm"]):
        sys.exit("parts.txt lists no libggml-hip.so")
    say = print
    act = not args.dry_run
    for kind, folder in (("rocm", os.path.join(dep, args.hip)), ("cuda", os.path.join(dep, args.cuda))):
        names = parts[kind]
        if not names:
            continue
        say("%s -> %s" % (kind.upper(), folder))
        # 1. out of the base depot: every name of the part (folders whole)
        moved = 0
        for n in names:
            p = os.path.join(linux, n)
            if os.path.exists(p):
                moved += 1
                if act:
                    if os.path.isdir(p):
                        shutil.rmtree(p)
                    else:
                        os.remove(p)
        say("  removed from %s: %d entr%s" % (args.linux, moved, "y" if moved == 1 else "ies"))
        # 2. the DLC folder afresh from redistributable_bin
        if act:
            if os.path.isdir(folder):
                shutil.rmtree(folder)
            os.makedirs(folder)
        files = [n for n in names if os.path.isfile(os.path.join(src, n)) and "/" not in n]
        keep = set(wanted_names(files))
        count, total = 0, 0
        for n in names:
            s = os.path.join(src, n)
            d = os.path.join(folder, n)
            if os.path.isdir(s):
                if act:
                    shutil.copytree(s, d, symlinks=False)
                count += sum(len(fs) for _, _, fs in os.walk(s))
                total += size_of(s)
            elif os.path.isfile(s) and (n in keep or "/" in n):
                if act:
                    os.makedirs(os.path.dirname(d), exist_ok=True)
                    shutil.copyfile(s, d)   # a link's target, as a file
                count += 1
                total += os.path.getsize(s)
            elif not os.path.exists(s):
                say("  WARNING: %s is in parts.txt but not in %s" % (n, src))
        say("  %s: %d file(s), %.0f MB" % (os.path.basename(folder), count, total / 1048576.0))
    # what the base depot still needs
    for need in ("EpubBuilder", "EpubBuilder.sh", "libsteam_api.so", "libwhisper.so.1"):
        if not os.path.exists(os.path.join(linux, need)):
            say("  NOTE: %s has no %s" % (args.linux, need))
    # ggml's number: 1 from ggml 1.0 (whisper.cpp 1.9.6), 0 before - and
    # never both (an older build's file left beside the new one)
    ggml = [n for n in ("libggml.so.1", "libggml.so.0") if os.path.exists(os.path.join(linux, n))]
    if not ggml:
        say("  NOTE: %s has no libggml.so.1" % args.linux)
    elif len(ggml) > 1:
        say("  WARNING: %s has %s: files of two whisper.cpp builds - deploy to an empty folder" %
            (args.linux, " and ".join(ggml)))
    # the reference texts (uCalibration's REFERENCE_TEXTS): recordings and
    # their EPUBs in media/, not named here
    media = os.path.join(linux, "media")
    names = os.listdir(media) if os.path.isdir(media) else []
    for ext, what in ((".m4b", "recordings"), (".epub", "EPUBs")):
        if not any(n.lower().endswith(ext) for n in names):
            say("  NOTE: %s has no reference-text %s in media/" % (args.linux, what))
    left = [f for f in os.listdir(linux) if f.startswith(("libggml-hip", "libggml-cuda", "libamdhip", "librocblas",
                                                          "libhipblas", "libcudart", "libcublas"))]
    if act and left:
        say("  WARNING: GPU libraries still in %s: %s" % (args.linux, ", ".join(sorted(left))))
    say("%s: %.0f MB" % (args.linux, size_of(linux) / 1048576.0))
    if args.dry_run:
        say("(dry run: nothing changed)")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("deployment")
    ap.add_argument("--linux", default="Linux")
    ap.add_argument("--hip", default="HIP")
    ap.add_argument("--cuda", default="CUDA")
    ap.add_argument("--dry-run", action="store_true")
    stage(ap.parse_args())


if __name__ == "__main__":
    main()
