#!/usr/bin/env python3
"""Puts redistributable_bin/<platform> into the Delphi deployment of the
programs that need it, so Deploy (PAServer) copies the libraries where the
program loads them from - after a Clean as well.

    python tools/deploy_redist.py [--platform P] [--skip REGEX]...

--platform: Linux64 (default; next to the program), OSXARM64 or OSX64
(into the .app's Contents/Frameworks, the licence texts into
Contents/Resources/licences - so Delphi signs the bundle with them in it).
Each platform's entries are replaced on their own: running it for one
leaves the others' as they are.

--skip leaves out the files whose path in the folder (with '/') matches
REGEX, e.g. --skip "^(rocblas|hipblaslt)/" or --skip "^libcublasLt"
(for testing what a deploy can take; the entries written before are
replaced either way).

Run it after tools/redist.sh collect (on Linux) or after copying
redistributable_bin/Linux64 to the Windows machine (sftp turns the
symbolic links into copies - that is fine), and again whenever the folder
changes; then reopen the projects in Delphi.

What each program gets:
  EpubBuilder  Linux64: everything - whisper.cpp, ggml and its backends,
               the CUDA / ROCm runtimes, ROCm's kernel folders, FFmpeg,
               the licences. macOS: whisper.cpp with the CPU and Metal
               backends (no Vulkan, CUDA or HIP - to be free DLC; owner
               2026-11-17), FFmpeg, the licences
  EpubReader   FFmpeg and its licence texts (it plays sound, it does not
               transcribe); on Linux also FreeType + brotli (Skia crashes
               with Steam Linux Runtime 3's FreeType 2.10.4)
  EpubConsole  nothing (no libraries)

The entries it writes are the DeployFile entries whose LocalName starts
with ..\\..\\redistributable_bin\\Linux64\\ ; it replaces all of those
and touches nothing else (platforms, other deploy entries, classes).

Library names: a library is deployed under the names the loaders and the
other libraries ask for - libX.so and libX.so.N (macOS: libX.dylib and
libX.N.dylib). A fully versioned name (libX.so.N.M.P, libX.N.M.P.dylib)
is left out when a shorter one is there: it is the file the links point
to, and the links are what is used.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLATFORMS = ("Linux64", "OSXARM64", "OSX64")
# set by main() from --platform
PLATFORM = "Linux64"
LOCAL_PREFIX = ""


def is_mac():
    """The platform is macOS (a bundle, .dylib)."""
    return PLATFORM.startswith("OSX")


def reader_file(rel):
    """EpubReader's share: FFmpeg's libraries and licence texts, and the
    FreeType (with brotli) that Skia needs in Steam's Linux runtime."""
    return (re.match(r"lib(av|sw|postproc)[a-z]*[.0-9]*\.(so|dylib)", rel) is not None
            or rel.startswith("licences/FFmpeg-")
            or re.match(r"lib(freetype|brotli[a-z]*)\.so", rel) is not None
            or rel.startswith("licences/FreeType-") or rel.startswith("licences/brotli-"))


def builder_file(rel):
    """EpubBuilder's share: everything on Linux; on macOS no Vulkan, CUDA or
    HIP backend (CPU and Metal only)."""
    if not is_mac():
        return True
    return re.search(r"(vulkan|cuda|hip)", rel.lower()) is None


# program -> which files (by their path in the folder, '/'-separated)
PROJECTS = {
    "demos/EpubBuilder/EpubBuilder.dproj": builder_file,
    "demos/EpubReader/EpubReader.dproj": reader_file,
}

# libX.so.N.M.P / libX.N.M.P.dylib: the stem and the version
VERSIONED = re.compile(r"^(lib.+?\.so)((?:\.[0-9]+)+)$")
VERSIONED_DYLIB = re.compile(r"^(lib.+?)((?:\.[0-9]+)+)\.dylib$")


def wanted_names(names):
    """The names of one folder to deploy (see the module's text)."""
    present = set(names)
    keep = []
    for n in sorted(names):
        m = VERSIONED.match(n)
        if m:
            parts = m.group(2).split(".")[1:]
            if len(parts) >= 2:
                shorter = [m.group(1)] + [m.group(1) + "." + ".".join(parts[:i])
                                          for i in range(1, len(parts))]
                if any(s in present for s in shorter):
                    continue
        m = VERSIONED_DYLIB.match(n)
        if m:
            parts = m.group(2).split(".")[1:]
            if len(parts) >= 2:
                shorter = [m.group(1) + ".dylib"] + [m.group(1) + "." + ".".join(parts[:i]) + ".dylib"
                                                     for i in range(1, len(parts))]
                if any(s in present for s in shorter):
                    continue
        keep.append(n)
    return keep


def collect(folder):
    """(relative path with '/', size) of every file to deploy."""
    out = []
    for base, dirs, files in os.walk(folder, followlinks=True):
        dirs.sort()
        rel_dir = os.path.relpath(base, folder)
        rel_dir = "" if rel_dir == "." else rel_dir.replace(os.sep, "/") + "/"
        for n in wanted_names([f for f in files if f != "README.md"]):
            p = os.path.join(base, n)
            if os.path.isfile(p):
                out.append((rel_dir + n, os.path.getsize(p)))
    return out


def entry(rel, nl):
    """One DeployFile entry, indented as Delphi writes them."""
    d, _, name = rel.rpartition("/")
    if is_mac():
        # libraries into the bundle's Frameworks (where the loaders look);
        # the licence texts are no code: Resources
        if d.startswith("licences"):
            remote_dir = "Contents\\Resources\\" + d.replace("/", "\\") + "\\"
        else:
            remote_dir = "Contents\\Frameworks\\" + (d.replace("/", "\\") + "\\" if d else "")
    else:
        remote_dir = ".\\" + (d.replace("/", "\\") + "\\" if d else "")
    local = LOCAL_PREFIX + rel.replace("/", "\\")
    lines = [
        '                <DeployFile LocalName="%s" Class="File">' % local,
        '                    <Platform Name="%s">' % PLATFORM,
        '                        <RemoteDir>%s</RemoteDir>' % remote_dir,
        '                        <RemoteName>%s</RemoteName>' % name,
        '                        <Overwrite>true</Overwrite>',
        '                    </Platform>',
        '                </DeployFile>',
    ]
    return nl.join(lines) + nl


def update(dproj, files):
    """Replaces the project's generated entries; returns how many it wrote."""
    path = os.path.join(ROOT, dproj)
    raw = open(path, "rb").read()
    bom = raw.startswith(b"\xef\xbb\xbf")
    text = raw.decode("utf-8-sig")
    nl = "\r\n" if "\r\n" in text else "\n"
    old = re.compile(r'[ \t]*<DeployFile LocalName="' + re.escape(LOCAL_PREFIX)
                     + r'[^"]*"[^>]*>.*?</DeployFile>[ \t]*' + re.escape(nl), re.S)
    text, removed = old.subn("", text)
    anchor = re.search(r'<Deployment Version="[0-9]+">' + re.escape(nl), text)
    if anchor is None:
        # a project the IDE has not written a deployment for yet: an empty
        # section (the IDE adds its own classes and entries when it saves)
        end = re.search(r'([ \t]*)</BorlandProject>', text)
        if end is None:
            sys.exit("%s: no <BorlandProject> section" % dproj)
        ind = end.group(1) + "    "
        text = (text[:end.start()] + ind + '<Deployment Version="5">' + nl + ind + '</Deployment>' + nl
                + text[end.start():])
        anchor = re.search(r'<Deployment Version="[0-9]+">' + re.escape(nl), text)
    block = "".join(entry(rel, nl) for rel in files)
    text = text[:anchor.end()] + block + text[anchor.end():]
    data = text.encode("utf-8")
    open(path, "wb").write((b"\xef\xbb\xbf" if bom else b"") + data)
    return removed


def main():
    global PLATFORM, LOCAL_PREFIX
    skips = []
    args = sys.argv[1:]
    while args:
        if args[0] == "--skip" and len(args) > 1:
            skips.append(re.compile(args[1]))
            args = args[2:]
        elif args[0] == "--platform" and len(args) > 1 and args[1] in PLATFORMS:
            PLATFORM = args[1]
            args = args[2:]
        else:
            sys.exit(__doc__)
    LOCAL_PREFIX = "..\\..\\redistributable_bin\\" + PLATFORM + "\\"
    folder = os.path.join(ROOT, "redistributable_bin", PLATFORM)
    if not os.path.isdir(folder):
        sys.exit("No %s: run tools/redist.sh collect on %s first and copy the folder here"
                 % (folder, "a Mac" if is_mac() else "Linux"))
    files = [(r, s) for r, s in collect(folder) if not any(x.search(r) for x in skips)]
    for dproj, want in PROJECTS.items():
        mine = [(r, s) for r, s in files if want(r)]
        removed = update(dproj, [r for r, _ in mine])
        longest = max((r for r, _ in mine), key=len, default="")
        print("%s: %d file(s), %.0f MB, longest name %d characters (replacing %d earlier entries)"
              % (dproj, len(mine), sum(s for _, s in mine) / 1048576.0, len(longest), removed))


if __name__ == "__main__":
    main()
