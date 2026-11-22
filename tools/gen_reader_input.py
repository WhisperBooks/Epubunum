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

The KEYS: Steam Input binds controllers to actions; a keyboard, a mouse
and a touch screen are not Steam Input devices, and an action manifest has
no place for a key. So that every button AND key mapping still has ONE
definition (owner's standing rule, 2026-11-22), the keys and the pointer
are tabled here beside the actions (MENU_KEYS, MENU_POINTER) and generated
into the same unit: the programs ask it which ACTION a key means and act
on the action as for a pad - no key is named in their own code.

Never edit the generated files by hand: change the tables here and run
the script again. Raise LAYOUT_REVISION whenever a layout or a key table
changes, and LAYOUT_MAJOR with it when an interaction is added or taken
away (Steam reports both back; the debug log shows which copy Steam
loaded).
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
# RAISE BY ONE WHENEVER A LAYOUT'S CONTENT OR A KEY TABLE CHANGES
#   1 - 2026-11-18: first version
#   2 - 2026-11-22: the menu's keys and pointer tabled (MENU_KEYS,
#       MENU_POINTER); the layouts' bindings as in 1
#   3 - 2026-11-22: Menu on F2 and Queue ("Library") on F3, no longer
#       Space and Q (owner: they did not open the builder's menus on the
#       desktop - "Let's change them to F2 + F3 for now")
LAYOUT_REVISION = 3
# RAISE WHEN AN INTERACTION IS ADDED OR TAKEN AWAY (owner, 2026-11-22: "raise
# the major revision code as well as defining new interactions"); written
# into every layout in place of TSteamAPI's "major_revision" "0"
#   1 - 2026-11-22: the keyboard, the mouse and touch drive the menu
LAYOUT_MAJOR = 1

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

# THE MENU'S KEYS (the pad's menu of either program): action, kind, value,
# what Controls calls it. kind "vk": a virtual key code (System.UITypes'
# vk...: vkReturn 13, vkEscape 27, vkLeft 37, vkUp 38, vkRight 39, vkDown
# 40); kind "char": a character, upper case (the space bar is " ").
# The first key of an action is the one the menu's foot names.
MENU_KEYS = [
    ("Up", "vk", 38, "Up"),
    ("Up", "char", "W", "W"),
    ("Down", "vk", 40, "Down"),
    ("Down", "char", "S", "S"),
    ("Left", "vk", 37, "Left"),
    ("Left", "char", "A", "A"),
    ("Right", "vk", 39, "Right"),
    ("Right", "char", "D", "D"),
    ("Play", "vk", 13, "Enter"),
    ("Back", "vk", 27, "Esc"),
    ("Menu", "vk", 113, "F2"),
    ("Library", "vk", 114, "F3"),
]
# THE MENU'S POINTER (mouse and finger): action, what was done - the names
# uPadMenu reports (PADMENU_...) and Controls shows.
MENU_POINTER = [
    ("Play", "left click"),
    ("Play", "tap"),
    ("Back", "right click"),
    ("Up", "wheel up"),
    ("Down", "wheel down"),
]


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
    L.append(f"  there and run it again. Layout revision {LAYOUT_MAJOR}.{LAYOUT_REVISION}.")
    L.append("")
    L.append("  ReaderInputWrite writes them into a folder (the manifest at the top,")
    L.append("  the layouts in controllers/), whose manifest is then given to Steam.")
    L.append("")
    L.append("  The menu's keys and pointer are tabled here too (READER_MENU_KEYS,")
    L.append("  READER_MENU_POINTER): Steam Input has no keyboard or mouse device, so")
    L.append("  the one definition of every button and key is the generator's tables.")
    L.append("  A program asks ReaderMenuKeyAction / ReaderMenuPointerAction which")
    L.append("  ACTION of the manifest a key or a click means, and acts on the action")
    L.append("  as it does for a pad. }")
    L.append("unit uReaderInput;")
    L.append("")
    L.append("interface")
    L.append("")
    L.append("type")
    L.append("  { One key of the menu and the action it means. }")
    L.append("  TReaderInputKey = record")
    L.append("    { The action's name in the manifest ('Up'). }")
    L.append("    Action: string;")
    L.append("    { The virtual key (vkUp = 38 ...); 0 when it is a character. }")
    L.append("    Key: Word;")
    L.append("    { The character, upper case; #0 when it is a virtual key. }")
    L.append("    KeyChar: WideChar;")
    L.append("    { What a list of the controls calls it ('Up', 'W', 'Space'). }")
    L.append("    Title: string;")
    L.append("  end;")
    L.append("")
    L.append("  { One use of the mouse or a finger on the menu and the action it means. }")
    L.append("  TReaderInputPointer = record")
    L.append("    { The action's name in the manifest ('Back'). }")
    L.append("    Action: string;")
    L.append("    { What was done, as uPadMenu reports it ('right click'). }")
    L.append("    Gesture: string;")
    L.append("  end;")
    L.append("")
    L.append("const")
    L.append("  { The manifest's file name. }")
    L.append(f"  READER_INPUT_MANIFEST = '{MANIFEST_NAME}';")
    L.append("  { The layouts' revision (Steam reports it back when it loads one). }")
    L.append(f"  READER_INPUT_REVISION = {LAYOUT_REVISION};")
    L.append("  { The layouts' major revision: raised when an interaction is added or")
    L.append("    taken away. }")
    L.append(f"  READER_INPUT_MAJOR = {LAYOUT_MAJOR};")
    L.append("  { The menu's keys; an action's first key is the one a hint names. }")
    L.append(f"  READER_MENU_KEYS: array[0..{len(MENU_KEYS) - 1}] of TReaderInputKey = (")
    for i, (action, kind, value, title) in enumerate(MENU_KEYS):
        if kind == "vk":
            key, ch = str(value), "#0"
        else:
            key, ch = "0", "'" + value + "'"
        L.append(f"    (Action: '{action}'; Key: {key}; KeyChar: {ch}; Title: '{title}')"
                 + ("," if i < len(MENU_KEYS) - 1 else ");"))
    L.append("  { The menu's pointer: the mouse and a finger. }")
    L.append(f"  READER_MENU_POINTER: array[0..{len(MENU_POINTER) - 1}] of TReaderInputPointer = (")
    for i, (action, gesture) in enumerate(MENU_POINTER):
        L.append(f"    (Action: '{action}'; Gesture: '{gesture}')" + ("," if i < len(MENU_POINTER) - 1 else ");"))
    L.append("")
    L.append("{ The action a key of the menu means.")
    L.append("  @param(AKey  the virtual key of a key event (0 = none))")
    L.append("  @param(AKeyChar  its character (#0 = none))")
    L.append("  @returns(the action's name in the manifest, '' when the key means none) }")
    L.append("function ReaderMenuKeyAction(AKey: Word; AKeyChar: WideChar): string;")
    L.append("")
    L.append("{ The action a use of the mouse or a finger on the menu means.")
    L.append("  @param(AGesture  what was done ('right click', 'wheel up' ...))")
    L.append("  @returns(the action's name in the manifest, '' when it means none) }")
    L.append("function ReaderMenuPointerAction(const AGesture: string): string;")
    L.append("")
    L.append("{ The keys of action AAction, for a list of the controls: 'Up, W'.")
    L.append("  @param(AAction  the action's name in the manifest)")
    L.append("  @param(AWithPointer  the mouse and the finger after them: ', wheel up')")
    L.append("  @returns(the names, '' when the action has no key) }")
    L.append("function ReaderMenuKeyNames(const AAction: string; AWithPointer: Boolean): string;")
    L.append("")
    L.append("{ The first key of action AAction, for a hint: 'Enter'.")
    L.append("  @param(AAction  the action's name in the manifest)")
    L.append("  @returns(its name, '' when the action has no key) }")
    L.append("function ReaderMenuFirstKey(const AAction: string): string;")
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
    L.append("function ReaderMenuKeyAction(AKey: Word; AKeyChar: WideChar): string;")
    L.append("var")
    L.append("  I: Integer;")
    L.append("  C: WideChar;")
    L.append("begin")
    L.append("  Result := '';")
    L.append("  C := UpCase(AKeyChar);")
    L.append("  // a letter or the space bar comes as a character on most systems, as")
    L.append("  // the virtual key alone on some")
    L.append("  if (C = #0) and (((AKey >= Ord('A')) and (AKey <= Ord('Z'))) or (AKey = 32)) then")
    L.append("    C := WideChar(AKey);")
    L.append("  for I := 0 to Length(READER_MENU_KEYS) - 1 do")
    L.append("    if ((READER_MENU_KEYS[I].Key <> 0) and (READER_MENU_KEYS[I].Key = AKey)) or")
    L.append("      ((READER_MENU_KEYS[I].KeyChar <> #0) and (READER_MENU_KEYS[I].KeyChar = C)) then")
    L.append("      Exit(READER_MENU_KEYS[I].Action);")
    L.append("end;")
    L.append("")
    L.append("function ReaderMenuPointerAction(const AGesture: string): string;")
    L.append("var")
    L.append("  I: Integer;")
    L.append("begin")
    L.append("  Result := '';")
    L.append("  for I := 0 to Length(READER_MENU_POINTER) - 1 do")
    L.append("    if SameText(READER_MENU_POINTER[I].Gesture, AGesture) then")
    L.append("      Exit(READER_MENU_POINTER[I].Action);")
    L.append("end;")
    L.append("")
    L.append("function ReaderMenuKeyNames(const AAction: string; AWithPointer: Boolean): string;")
    L.append("var")
    L.append("  I: Integer;")
    L.append("begin")
    L.append("  Result := '';")
    L.append("  for I := 0 to Length(READER_MENU_KEYS) - 1 do")
    L.append("    if SameText(READER_MENU_KEYS[I].Action, AAction) then")
    L.append("    begin")
    L.append("      if Result <> '' then")
    L.append("        Result := Result + ', ';")
    L.append("      Result := Result + READER_MENU_KEYS[I].Title;")
    L.append("    end;")
    L.append("  if not AWithPointer then")
    L.append("    Exit;")
    L.append("  for I := 0 to Length(READER_MENU_POINTER) - 1 do")
    L.append("    if SameText(READER_MENU_POINTER[I].Action, AAction) then")
    L.append("    begin")
    L.append("      if Result <> '' then")
    L.append("        Result := Result + ', ';")
    L.append("      Result := Result + READER_MENU_POINTER[I].Gesture;")
    L.append("    end;")
    L.append("end;")
    L.append("")
    L.append("function ReaderMenuFirstKey(const AAction: string): string;")
    L.append("var")
    L.append("  I: Integer;")
    L.append("begin")
    L.append("  Result := '';")
    L.append("  for I := 0 to Length(READER_MENU_KEYS) - 1 do")
    L.append("    if SameText(READER_MENU_KEYS[I].Action, AAction) then")
    L.append("      Exit(READER_MENU_KEYS[I].Title);")
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
    # every key and every use of the pointer means an action of the manifest
    actions = {a[1] for _, _, acts in SETS for a in acts}
    for row in MENU_KEYS + MENU_POINTER:
        assert row[0] in actions, f"{row}: no action {row[0]} in SETS"
    assert len({(k, v) for _, k, v, _ in MENU_KEYS}) == len(MENU_KEYS), "MENU_KEYS: one key twice"
    assert len({g_ for _, g_ in MENU_POINTER}) == len(MENU_POINTER), "MENU_POINTER: one gesture twice"
    files = [(MANIFEST_NAME, g.manifest(pr))]
    for ctype in g.CONTROLLERS:
        text = g.layout(pr, ctype)
        # TSteamAPI's writer has "major_revision" "0": ours is LAYOUT_MAJOR
        old = '"major_revision"\t\t"0"'
        assert text.count(old) == 1, f"{ctype}: major_revision not found once"
        text = text.replace(old, f'"major_revision"\t\t"{LAYOUT_MAJOR}"')
        files.append((g.LAYOUT_DIR + "/" + g.layout_file(pr, ctype), text))
    for name, text in files:
        put(os.path.join(OUT_DIR, *name.split("/")), text.encode("ascii"))
    # the unit with LF line ends like the other sources here
    put(UNIT, unit_text(files).replace("\r\n", "\n").encode("ascii"))


if __name__ == "__main__":
    main()
