#!/usr/bin/env python3
"""Puts redistributable_bin/Linux64 into the Delphi deployment of the
programs that need it, so Deploy (PAServer) copies the libraries next to
the program - after a Clean as well.

    python tools/deploy_redist.py [--skip REGEX]...

--skip leaves out the files whose path in the folder (with '/') matches
REGEX, e.g. --skip "^(rocblas|hipblaslt)/" or --skip "^libcublasLt"
(for testing what a deploy can take; the entries written before are
replaced either way).

Run it after tools/redist.sh collect (on Linux) or after copying
redistributable_bin/Linux64 to the Windows machine (sftp turns the
symbolic links into copies - that is fine), and again whenever the folder
changes; then reopen the projects in Delphi.

What each program gets:
  EpubBuilder  everything: whisper.cpp, ggml and its backends, the CUDA /
               ROCm runtimes, ROCm's kernel folders, FFmpeg, the licences
  EpubReader   FFmpeg and its licence texts (it plays sound, it does not
               transcribe)
  EpubConsole  nothing (no libraries)

The entries it writes are the DeployFile entries whose LocalName starts
with ..\\..\\redistributable_bin\\Linux64\\ ; it replaces all of those
and touches nothing else (platforms, other deploy entries, classes).

Library names: a library is deployed under the names the loaders and the
other libraries ask for - libX.so and libX.so.N. A fully versioned
name (libX.so.N.M.P) is left out when a shorter one is there: on Linux
it is the file the links point to, and the links are what is used.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLATFORM = "Linux64"
LOCAL_PREFIX = "..\\..\\redistributable_bin\\" + PLATFORM + "\\"

# program -> which files (by their path in the folder, '/'-separated)
PROJECTS = {
    "demos/EpubBuilder/EpubBuilder.dproj": lambda rel: True,
    "demos/EpubReader/EpubReader.dproj": lambda rel: (
        re.match(r"lib(av|sw)[a-z]+\.so", rel) is not None
        or rel.startswith("licences/FFmpeg-")),
}

VERSIONED = re.compile(r"^(lib.+?\.so)((?:\.[0-9]+)+)$")


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
    skips = []
    args = sys.argv[1:]
    while args:
        if args[0] == "--skip" and len(args) > 1:
            skips.append(re.compile(args[1]))
            args = args[2:]
        else:
            sys.exit(__doc__)
    folder = os.path.join(ROOT, "redistributable_bin", PLATFORM)
    if not os.path.isdir(folder):
        sys.exit("No %s: run tools/redist.sh collect on Linux first (or copy the folder here)" % folder)
    files = [(r, s) for r, s in collect(folder) if not any(x.search(r) for x in skips)]
    for dproj, want in PROJECTS.items():
        mine = [(r, s) for r, s in files if want(r)]
        removed = update(dproj, [r for r, _ in mine])
        longest = max((r for r, _ in mine), key=len, default="")
        print("%s: %d file(s), %.0f MB, longest name %d characters (replacing %d earlier entries)"
              % (dproj, len(mine), sum(s for _, s in mine) / 1048576.0, len(longest), removed))


if __name__ == "__main__":
    main()
