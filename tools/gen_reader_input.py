#!/usr/bin/env python3
"""EpubReader's Steam Input files: the action manifest, one default layout
per controller type, and demos/EpubReader/src/uReaderInput.pas, which
carries them all inside the program.

    python3 tools/gen_reader_input.py [--tsteamapi PATH_TO_TSTEAMAPI]

Without --tsteamapi: the TSTEAMAPI environment variable, else a folder
beside this repository named TSteamAPI or steamworks (the repository's
name before 2026-11) - the first that has tools/gen_input_mapping.py.

The VDF writing is TSteamAPI's (tools/gen_input_mapping.py, imported from
the TSteamAPI checkout given): the same writer, the same controller list
and the same rules as its demos. Only the tables below are EpubReader's.

Output:
* demos/EpubReader/steaminput/epubreader_controllers.vdf and
  demos/EpubReader/steaminput/controllers/reader_controller_<type>.vdf -
  to read, and for the Steamworks partner site if the layouts are ever
  published there;
* demos/EpubReader/src/uReaderInput.pas - the same files as Pascal
  constants. EpubReader writes them beside its settings at start-up and
  gives Steam that manifest (SetInputActionManifestFilePath), so nothing
  has to be deployed.

Never edit the generated files by hand: change the tables here and run
the script again. Raise LAYOUT_REVISION whenever a layout changes (Steam
reports it back; the debug log shows which copy Steam loaded).
"""
import argparse
import importlib.util
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "demos", "EpubReader", "steaminput")
UNIT = os.path.join(ROOT, "demos", "EpubReader", "src", "uReaderInput.pas")

MANIFEST_NAME = "epubreader_controllers.vdf"
TITLE = "EpubReader default layout"
DESCRIPTION = "Default bindings of EpubReader: reading, listening and its menu."
SUMMARY = "EpubReader: reading, listening and its menu."
# RAISE BY ONE WHENEVER A LAYOUT'S CONTENT CHANGES
#   1 - 2026-11-18: first version
LAYOUT_REVISION = 1

# ONE set: the page, the library and the menu read the same actions; the
# program decides what each means where it is
SETS = [
    ("Reader", "#Set_Reader", [
        ("stick", "Scroll", "#Action_Scroll", "joystick_move"),
        ("button", "Up", "#Action_Up", None),
        ("button", "Down", "#Action_Down", None),
        ("button", "Left", "#Action_Left", None),
        ("button", "Right", "#Action_Right", None),
        ("button", "Play", "#Action_Play", None),
        ("button", "Back", "#Action_Back", None),
        ("button", "Again", "#Action_Again", None),
        ("button", "Dark", "#Action_Dark", None),
        ("button", "SentencePrev", "#Action_SentencePrev", None),
        ("button", "SentenceNext", "#Action_SentenceNext", None),
        ("button", "ChapterPrev", "#Action_ChapterPrev", None),
        ("button", "ChapterNext", "#Action_ChapterNext", None),
        ("button", "Menu", "#Action_Menu", None),
        ("button", "Library", "#Action_Library", None),
    ]),
]
LOCALIZATION = {"english": [
    ("Set_Reader", "Reading"),
    ("Action_Scroll", "Scroll the page"),
    ("Action_Up", "Up (menu, library) / scroll up"),
    ("Action_Down", "Down (menu, library) / scroll down"),
    ("Action_Left", "Left / previous page"),
    ("Action_Right", "Right / next page"),
    ("Action_Play", "Play / pause; choose (menu, library)"),
    ("Action_Back", "Back (close the menu or the library)"),
    ("Action_Again", "Say it again (Learn to read)"),
    ("Action_Dark", "Dark mode"),
    ("Action_SentencePrev", "Previous sentence"),
    ("Action_SentenceNext", "Next sentence"),
    ("Action_ChapterPrev", "Previous chapter"),
    ("Action_ChapterNext", "Next chapter"),
    ("Action_Menu", "Menu"),
    ("Action_Library", "Library"),
]}
BINDINGS = {
    "Reader": [
        ("right_joystick", None, "Scroll"),
        ("dpad", "dpad_north", "Up"),
        ("dpad", "dpad_south", "Down"),
        ("dpad", "dpad_west", "Left"),
        ("dpad", "dpad_east", "Right"),
        # the left stick as a second d-pad (group mode "dpad", MODES)
        ("joystick", "dpad_north", "Up"),
        ("joystick", "dpad_south", "Down"),
        ("joystick", "dpad_west", "Left"),
        ("joystick", "dpad_east", "Right"),
        ("button_diamond", "button_a", "Play"),
        ("button_diamond", "button_b", "Back"),
        ("button_diamond", "button_x", "Again"),
        ("button_diamond", "button_y", "Dark"),
        ("switch", "left_bumper", "SentencePrev"),
        ("switch", "right_bumper", "SentenceNext"),
        # a full pull ("click") of a trigger as a button
        ("left_trigger", "click", "ChapterPrev"),
        ("right_trigger", "click", "ChapterNext"),
        ("switch", "button_escape", "Menu"),
        ("switch", "button_menu", "Library"),
    ],
}
# the left stick moves in steps, like the d-pad
MODES = {"joystick": "dpad"}


# folders beside this repository that may hold TSteamAPI
GUESSES = ["TSteamAPI", "steamworks", "tsteamapi"]


def find_tsteamapi(given):
    """The TSteamAPI checkout: given, else $TSTEAMAPI, else a guess."""
    if given:
        tries = [given]
    elif os.environ.get("TSTEAMAPI"):
        tries = [os.environ["TSTEAMAPI"]]
    else:
        tries = [os.path.join(os.path.dirname(ROOT), g) for g in GUESSES]
    for t in tries:
        if os.path.isfile(os.path.join(t, "tools", "gen_input_mapping.py")):
            return os.path.abspath(t)
    sys.exit("TSteamAPI's tools/gen_input_mapping.py not found in: " + ", ".join(os.path.abspath(t) for t in tries)
             + "\nGive the folder with --tsteamapi or the TSTEAMAPI environment variable.")


def load_generator(path):
    gen = os.path.join(path, "tools", "gen_input_mapping.py")
    # no __pycache__ left in the TSteamAPI checkout
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("gen_input_mapping", gen)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def pascal_lines(text):
    """The lines of a VDF file as Pascal string literals (tabs as #9)."""
    out = []
    for line in text.split("\r\n")[:-1]:
        parts = line.split("\t")
        lit = ""
        for i, p in enumerate(parts):
            if i:
                lit += "#9"
            if p:
                lit += "'" + p.replace("'", "''") + "'"
        out.append(lit if lit else "''")
    return out


def unit_text(files):
    """uReaderInput.pas: every file as a constant array of lines."""
    L = []
    L.append("{ @abstract(EpubReader's Steam Input action manifest and its default")
    L.append("  layouts, inside the program.)")
    L.append("")
    L.append("  GENERATED by tools/gen_reader_input.py (with TSteamAPI's")
    L.append("  tools/gen_input_mapping.py) - never edit by hand: change the tables")
    L.append(f"  there and run it again. Layout revision {LAYOUT_REVISION}.")
    L.append("")
    L.append("  ReaderInputWrite writes them into a folder (the manifest at the top,")
    L.append("  the layouts in controllers/), whose manifest is then given to Steam. }")
    L.append("unit uReaderInput;")
    L.append("")
    L.append("interface")
    L.append("")
    L.append("const")
    L.append("  { The manifest's file name. }")
    L.append(f"  READER_INPUT_MANIFEST = '{MANIFEST_NAME}';")
    L.append("  { The layouts' revision (Steam reports it back when it loads one). }")
    L.append(f"  READER_INPUT_REVISION = {LAYOUT_REVISION};")
    L.append("")
    L.append("{ Writes the manifest and the layouts into AFolder (made if needed);")
    L.append("  a file already as it should be is left alone.")
    L.append("  @param(AFolder  the folder)")
    L.append("  @returns(the manifest's full path) }")
    L.append("function ReaderInputWrite(const AFolder: string): string;")
    L.append("")
    L.append("implementation")
    L.append("")
    L.append("uses")
    L.append("  System.SysUtils, System.IOUtils;")
    L.append("")
    L.append("const")
    for n, (name, text) in enumerate(files):
        lines = pascal_lines(text)
        L.append(f"  {{ {name} }}")
        L.append(f"  FILE{n}: array[0..{len(lines) - 1}] of string = (")
        for i, lit in enumerate(lines):
            L.append("    " + lit + ("," if i < len(lines) - 1 else ");"))
    L.append("")
    L.append("{ AText into AFile (CR LF lines), unless it holds that already. }")
    L.append("procedure Put(const AFile: string; const ALines: array of string);")
    L.append("var")
    L.append("  S: string;")
    L.append("  I: Integer;")
    L.append("begin")
    L.append("  S := '';")
    L.append("  for I := 0 to High(ALines) do")
    L.append("    S := S + ALines[I] + #13#10;")
    L.append("  if TFile.Exists(AFile) and (TFile.ReadAllText(AFile, TEncoding.ASCII) = S) then")
    L.append("    Exit;")
    L.append("  TDirectory.CreateDirectory(ExtractFileDir(AFile));")
    L.append("  TFile.WriteAllText(AFile, S, TEncoding.ASCII);")
    L.append("end;")
    L.append("")
    L.append("function ReaderInputWrite(const AFolder: string): string;")
    L.append("begin")
    for n, (name, _) in enumerate(files):
        parts = name.split("/")
        path = " + PathDelim + ".join("'" + p + "'" for p in parts)
        L.append(f"  Put(IncludeTrailingPathDelimiter(AFolder) + {path}, FILE{n});")
    L.append(f"  Result := IncludeTrailingPathDelimiter(AFolder) + READER_INPUT_MANIFEST;")
    L.append("end;")
    L.append("")
    L.append("end.")
    return "\r\n".join(L) + "\r\n"


def put(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    old = open(path, "rb").read() if os.path.exists(path) else None
    if old != data:
        open(path, "wb").write(data)
        print("wrote", os.path.relpath(path, ROOT))
    else:
        print("unchanged", os.path.relpath(path, ROOT))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--tsteamapi", help="the TSteamAPI checkout (has tools/gen_input_mapping.py)")
    args = ap.parse_args()
    path = find_tsteamapi(args.tsteamapi)
    print("TSteamAPI:", path)
    g = load_generator(path)
    pr = g.Profile([OUT_DIR], MANIFEST_NAME, "reader_controller_", TITLE, DESCRIPTION, "EpubReader",
                   SETS, LOCALIZATION, BINDINGS, {}, MODES, LAYOUT_REVISION, True, SUMMARY,
                   bound_sources_only=True)
    files = [(MANIFEST_NAME, g.manifest(pr))]
    for ctype in g.CONTROLLERS:
        files.append((g.LAYOUT_DIR + "/" + g.layout_file(pr, ctype), g.layout(pr, ctype)))
    for name, text in files:
        put(os.path.join(OUT_DIR, *name.split("/")), text.encode("ascii"))
    # the unit with LF line ends like the other sources here
    put(UNIT, unit_text(files).replace("\r\n", "\n").encode("ascii"))


if __name__ == "__main__":
    main()
