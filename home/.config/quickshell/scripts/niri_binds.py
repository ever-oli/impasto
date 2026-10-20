#!/usr/bin/env python3
"""Print niri's key binds as JSON for the keys sheet.

niri has no IPC for binds, so this reads the config (following `include`s)
and prints [{key, modmask, description}], with the modmask bits the sheet
already speaks (Super 64, Ctrl 4, Alt 8, Shift 1). A bind's
`hotkey-overlay-title="Group · Action"` names its row; otherwise the action
itself does, under "Niri".
"""
import json, os, re, sys

CONFIG = os.environ.get("NIRI_CONFIG") or os.path.expanduser("~/.config/niri/config.kdl")
BITS = {"super": 64, "mod": 64, "win": 64, "ctrl": 4, "control": 4, "alt": 8, "shift": 1}


def read(path, seen):
    path = os.path.realpath(os.path.expanduser(path))
    if path in seen or not os.path.exists(path):
        return ""
    seen.add(path)
    text = open(path).read()
    def inc(m):
        return read(os.path.join(os.path.dirname(path), m.group(1)), seen)
    return re.sub(r'^\s*include\s+"([^"]+)"', inc, text, flags=re.M)


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"(?m)^\s*//.*$|\s//[^\"\n]*$", "", text)


def binds_blocks(text):
    for m in re.finditer(r"\bbinds\s*\{", text):
        depth, i = 1, m.end()
        while depth and i < len(text):
            depth += {"{": 1, "}": -1}.get(text[i], 0)
            i += 1
        yield text[m.end():i - 1]


NAMES = {
    "toggle launcher": ("Shell", "Palette"), "toggle ask": ("Shell", "Ask the assistant"),
    "palette Style/Theme": ("Shell", "Pick a theme"), "palette Style/Wallpaper": ("Shell", "Pick a wallpaper"), "toggle controls": ("Shell", "Control centre"),
    "toggle t3": ("Shell", "T3 Code"), "toggle keys": ("Shell", "Keys"),
    "toggle clipboard": ("Shell", "Clipboard history"), "toggle emoji": ("Shell", "Emoji"),
    "toggle session": ("Shell", "Session menu"), "focus toggle": ("Shell", "Do not disturb"),
    "capture region": ("Capture", "Region to file"), "capture": ("Capture", "Capture surface"),
    "record": ("Capture", "Record the screen"),
}


def describe(action):
    """(group, label) for a bind's action."""
    action = action.strip().rstrip(";").strip()
    args = re.findall(r'"([^"]*)"', action)
    if action.startswith("spawn") and args:
        if args[0] == "impasto":
            return NAMES.get(" ".join(args[1:]), ("Shell", " ".join(args[1:]).capitalize()))
        if args[0] == "impasto-theme":
            return ("Shell", "Next theme" if args[1:] == ["next"] else "Next wallpaper")
        return ("Applications", args[0].replace("-", " ").title())
    word = action.split()[0]
    group = ("Workspaces" if "workspace" in word or "overview" in word
             else "Niri" if word in ("quit", "screenshot", "show-hotkey-overlay") else "Windows")
    rest = action[len(word):].strip().strip('"')
    return (group, (word.replace("-", " ").capitalize() + (" " + rest if rest else "")))


out = []
for block in binds_blocks(strip_comments(read(CONFIG, set()))):
    for m in re.finditer(r'^\s*([A-Za-z0-9_+]+)((?:\s+[a-z-]+=(?:"[^"]*"|\S+))*)\s*\{([^}]*)\}', block, re.M):
        combo, props, action = m.groups()
        parts = combo.split("+")
        key, mods = parts[-1], parts[:-1]
        mask = sum(BITS.get(p.lower(), 0) for p in mods)
        title = re.search(r'hotkey-overlay-title="([^"]*)"', props or "")
        desc = title.group(1) if title else " · ".join(describe(action))
        out.append({"key": key, "modmask": mask, "description": desc})
json.dump(out, sys.stdout)
