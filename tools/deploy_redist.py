#!/usr/bin/env python3
"""Puts redistributable_bin/<platform> into the Delphi deployment of the
programs that need it, so Deploy (PAServer) copies the libraries where the
program loads them from - after a Clean as well.

    python tools/deploy_redist.py [--platform P] [--skip-rocm] [--skip-cuda] [--skip REGEX]...
    python tools/deploy_redist.py --media-only [--platform P]

--platform: Linux64 (default; next to the program), OSXARM64 or OSX64
(into the .app's Contents/Frameworks, the licence texts into
Contents/Resources/licences - so Delphi signs the bundle with them in it).
Each platform's entries are replaced on their own: running it for one
leaves the others' as they are.

--skip-rocm / --skip-cuda leave out every file of the ROCm (HIP) / CUDA
part - the list tools/steam_stage.py splits the DLC depot by: Linux64's
parts.txt (tools/redist.sh collect), else the parts by name. For a
Linux deploy without ROCm (the base Steam depot; the HIP DLC comes from
steam_stage.py), e.g. python tools/deploy_redist.py --skip-rocm.

--skip leaves out the files whose path in the folder (with '/') matches
REGEX, e.g. --skip "^(rocblas|hipblaslt)/" or --skip "^libcublasLt"
(for testing what a deploy can take; the entries written before are
replaced either way).

--media-only replaces only EpubBuilder's media entries (the repository's
media/ folder: the reference texts) - for Linux64 and OSXARM64, or the
one --platform names - and leaves every library entry as it is; no
redistributable_bin needed. Run it on Windows whenever media/ changes.

Run it after tools/redist.sh collect (on Linux) or after copying
redistributable_bin/Linux64 to the Windows machine (sftp turns the
symbolic links into copies - that is fine), and again whenever the folder
changes; then reopen the projects in Delphi.

What each program gets:
  EpubBuilder  Linux64: everything - whisper.cpp, ggml and its backends,
               the CUDA / ROCm runtimes, ROCm's kernel folders, FFmpeg,
               the licences. macOS: whisper.cpp with the CPU and Metal
               backends (no Vulkan, CUDA or HIP - to be free DLC; owner
               2026-11-17), FFmpeg, the licences. Both: the repository's
               media/ - the reference texts, recordings and their EPUBs,
               every file but dot files, none named here (Linux media/
               beside the program, macOS Contents/Resources/media)
  EpubReader   FFmpeg and its licence texts (it plays sound, it does not
               transcribe); on Linux also FreeType + brotli (Skia crashes
               with Steam Linux Runtime 3's FreeType 2.10.4), and its
               Steam Input files from demos/EpubReader/steaminput (made
               by tools/gen_reader_input.py) into steaminput/ beside the
               program - in the depot, where the partner site's "Custom
               Configuration (Bundled with Game)" names them (not on
               macOS: the reader writes them beside its settings there)
               EpubBuilder gets the same Steam Input files (its pad uses
               the reader's actions; zip 148)
  EpubConsole  nothing (no libraries)

The entries it writes are the DeployFile entries whose LocalName starts
with ..\\..\\redistributable_bin\\<platform>\\, and this platform's
entries of the program's own folders (steaminput, media); it replaces
all of those and touches nothing else (platforms, other deploy entries,
classes).

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

# program -> its own folders deployed as they are, besides
# redistributable_bin: (folder in the repository, prefix of its entries'
# LocalName - relative to the .dproj -, RemoteDir below the program), on
# Linux only
OWN_FOLDERS = {
    "demos/EpubReader/EpubReader.dproj": [("demos/EpubReader/steaminput", "steaminput\\", "steaminput")],
    # the builder's pad uses the reader's actions (one manifest per Steam
    # app, zip 148): the same files beside it; LocalName relative to the
    # builder's .dproj
    "demos/EpubBuilder/EpubBuilder.dproj": [("demos/EpubReader/steaminput", "..\\EpubReader\\steaminput\\",
                                             "steaminput")],
}

# program -> its media folder (the reference texts), deployed on every
# platform: (folder in the repository, prefix of its entries' LocalName)
MEDIA_FOLDERS = {
    "demos/EpubBuilder/EpubBuilder.dproj": ("media", "..\\..\\media\\"),
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
        for n in wanted_names([f for f in files if f not in ("README.md", "parts.txt")]):
            p = os.path.join(base, n)
            if os.path.isfile(p):
                out.append((rel_dir + n, os.path.getsize(p)))
    return out


def entry(rel, nl, local_prefix=None, remote_base=""):
    """One DeployFile entry, indented as Delphi writes them (an own
    folder's file: local_prefix and remote_base given)."""
    d, _, name = rel.rpartition("/")
    if local_prefix is not None and is_mac():
        # an own folder is no code: the bundle's Resources
        sub = remote_base + ("/" + d if d else "")
        lines = [
            '                <DeployFile LocalName="%s" Class="File">' % (local_prefix + rel.replace("/", "\\")),
            '                    <Platform Name="%s">' % PLATFORM,
            '                        <RemoteDir>Contents\\Resources\\%s\\</RemoteDir>' % sub.replace("/", "\\"),
            '                        <RemoteName>%s</RemoteName>' % name,
            '                        <Overwrite>true</Overwrite>',
            '                    </Platform>',
            '                </DeployFile>',
        ]
        return nl.join(lines) + nl
    if local_prefix is not None:
        sub = remote_base + ("/" + d if d else "")
        lines = [
            '                <DeployFile LocalName="%s" Class="File">' % (local_prefix + rel.replace("/", "\\")),
            '                    <Platform Name="%s">' % PLATFORM,
            '                        <RemoteDir>.\\%s\\</RemoteDir>' % sub.replace("/", "\\"),
            '                        <RemoteName>%s</RemoteName>' % name,
            '                        <Overwrite>true</Overwrite>',
            '                    </Platform>',
            '                </DeployFile>',
        ]
        return nl.join(lines) + nl
    if is_mac():
        # libraries into the bundle's Frameworks (where the loaders look);
        # the licence texts are no code: Resources (and media/, should an
        # older collect have put it there)
        if d.startswith("licences") or d.startswith("media"):
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


def update(dproj, files, own=(), libraries=True):
    """Replaces the project's generated entries (redistributable_bin's and
    those of its own folders, for this platform); returns how many it
    removed. own: (local prefix, remote base, [relative paths]).
    libraries False: redistributable_bin's entries are left as they are
    (files is then empty); only own's prefixes are replaced."""
    path = os.path.join(ROOT, dproj)
    raw = open(path, "rb").read()
    bom = raw.startswith(b"\xef\xbb\xbf")
    text = raw.decode("utf-8-sig")
    nl = "\r\n" if "\r\n" in text else "\n"
    old = re.compile(r'[ \t]*<DeployFile LocalName="' + re.escape(LOCAL_PREFIX)
                     + r'[^"]*"[^>]*>.*?</DeployFile>[ \t]*' + re.escape(nl), re.S)
    removed = 0
    if libraries:
        text, removed = old.subn("", text)
    # the own folders given: their entries are written again below (with
    # --media-only only media's - steaminput's stay)
    for prefix in [p for p, _, _ in own]:
        # this platform's entries only (another platform's stay)
        old_own = re.compile(r'[ \t]*<DeployFile LocalName="' + re.escape(prefix) + r'[^"]*"[^>]*>[ \t]*'
                             + re.escape(nl) + r'[ \t]*<Platform Name="' + re.escape(PLATFORM)
                             + r'">.*?</DeployFile>[ \t]*' + re.escape(nl), re.S)
        text, n = old_own.subn("", text)
        removed += n
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
    for prefix, remote_base, rels in own:
        block += "".join(entry(rel, nl, prefix, remote_base) for rel in rels)
    text = text[:anchor.end()] + block + text[anchor.end():]
    data = text.encode("utf-8")
    open(path, "wb").write((b"\xef\xbb\xbf" if bom else b"") + data)
    return removed


def media_files(dproj):
    """(local prefix, remote base, [relative paths]) of the program's media
    folder - every file in it but dot files - or None when it has none."""
    if dproj not in MEDIA_FOLDERS:
        return None
    folder_rel, prefix = MEDIA_FOLDERS[dproj]
    found = [r for r, _ in collect(os.path.join(ROOT, folder_rel))
             if not os.path.basename(r).startswith(".")]
    if not found:
        print("WARNING: %s has no files - EpubBuilder gets no reference texts" % folder_rel)
    return (prefix, folder_rel.rsplit("/", 1)[-1], found)


def media_only(platforms):
    """--media-only: the media entries of every program that has them, for
    each platform; nothing else changed."""
    global PLATFORM
    for PLATFORM in platforms:
        for dproj in MEDIA_FOLDERS:
            own = [media_files(dproj)]
            removed = update(dproj, [], own, libraries=False)
            print("%s, %s: %d media file(s) (replacing %d earlier entries)"
                  % (dproj, PLATFORM, len(own[0][2]), removed))


def main():
    global PLATFORM, LOCAL_PREFIX
    skips = []
    skip_parts = []
    only_media = False
    chosen = None
    args = sys.argv[1:]
    while args:
        if args[0] == "--skip" and len(args) > 1:
            skips.append(re.compile(args[1]))
            args = args[2:]
        elif args[0] in ("--skip-rocm", "--skip-cuda"):
            skip_parts.append(args[0][len("--skip-"):])
            args = args[1:]
        elif args[0] == "--platform" and len(args) > 1 and args[1] in PLATFORMS:
            PLATFORM = args[1]
            chosen = args[1]
            args = args[2:]
        elif args[0] == "--media-only":
            only_media = True
            args = args[1:]
        else:
            sys.exit(__doc__)
    if only_media:
        media_only([chosen] if chosen else ["Linux64", "OSXARM64"])
        return
    LOCAL_PREFIX = "..\\..\\redistributable_bin\\" + PLATFORM + "\\"
    folder = os.path.join(ROOT, "redistributable_bin", PLATFORM)
    if not os.path.isdir(folder):
        sys.exit("No %s: run tools/redist.sh collect on %s first and copy the folder here"
                 % (folder, "a Mac" if is_mac() else "Linux"))
    # media/ is deployed from the repository (MEDIA_FOLDERS), not from
    # here: an older collect's copy is left out
    files = [(r, s) for r, s in collect(folder)
             if not r.startswith("media/") and not any(x.search(r) for x in skips)]
    if skip_parts:
        # the parts as steam_stage.py tells them (imported here: it imports
        # this module)
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from steam_stage import read_parts
        parts = read_parts(folder)
        names = set()
        for kind in skip_parts:
            if not parts[kind]:
                print("WARNING: no %s files listed - nothing of it to leave out" % kind.upper())
            names.update(n.rstrip("/") for n in parts[kind])
        before = len(files)
        # a listed name, or a file in a listed folder (rocblas/, hipblaslt/)
        files = [(r, s) for r, s in files
                 if r not in names and not any(r.startswith(n + "/") for n in names)]
        print("left out: %d file(s) of the %s part(s)" % (before - len(files),
                                                          " and ".join(k.upper() for k in skip_parts)))
    for dproj, want in PROJECTS.items():
        mine = [(r, s) for r, s in files if want(r)]
        own = []
        if not is_mac():
            for folder_rel, prefix, remote_base in OWN_FOLDERS.get(dproj, []):
                found = collect(os.path.join(ROOT, folder_rel))
                own.append((prefix, remote_base, [r for r, _ in found]))
        media = media_files(dproj)
        if media is not None:
            own.append(media)
        removed = update(dproj, [r for r, _ in mine], own)
        # the count includes the own folders' files
        mine = mine + [(prefix + r, 0) for prefix, _, rels in own for r in rels]
        longest = max((r for r, _ in mine), key=len, default="")
        print("%s: %d file(s), %.0f MB, longest name %d characters (replacing %d earlier entries)"
              % (dproj, len(mine), sum(s for _, s in mine) / 1048576.0, len(longest), removed))


if __name__ == "__main__":
    main()
