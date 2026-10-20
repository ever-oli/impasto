#!/usr/bin/env python3
"""Aether → Notch: fill the keys Notch's colors.toml needs from Aether's
palette, copy the wallpaper in, run the contrast audit (warn, never block),
then `notch-theme set aether` so every app follows."""
import os, shutil, subprocess, tomllib
D = os.path.expanduser("~/.local/share/notch/themes/aether")
with open(f"{D}/aether.toml", "rb") as f:
    a = tomllib.load(f)

def mix(x, y, t):
    p = [int(x[i:i + 2], 16) for i in (1, 3, 5)]; q = [int(y[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(u + (v - u) * t):02X}" for u, v in zip(p, q))

bg, fg = a["background"].upper(), a["foreground"].upper()
dark = a.get("mode") != "light"
c = {k: a[f"color{i}"].upper() for i, k in enumerate(["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"])}
c.update({f"bright_{k}": a[f"color{i + 8}"].upper() for i, k in enumerate(["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"])})
out = {
    "mode": "dark" if dark else "light",
    "accent": a["accent"].upper(),
    "selection": a["selection_background"].upper(),
    "selection_foreground": a["selection_foreground"].upper(),
    "selection_background": a["selection_background"].upper(),
    "muted": mix(fg, bg, 0.40),
    "background": bg,
    "dark_background": mix(bg, fg, 0.06),
    "darker_background": mix(bg, fg, 0.10),
    "lighter_background": mix(bg, "#FFFFFF" if not dark else fg, 0.04),
    "foreground": fg,
    "dark_foreground": mix(fg, bg, 0.25),
    "light_foreground": mix(fg, bg, 0.15),
    "bright_foreground": mix(fg, "#FFFFFF" if dark else "#000000", 0.30),
    "orange": mix(c["red"], c["yellow"], 0.5),
    "brown": mix(mix(c["red"], c["yellow"], 0.5), bg, 0.25),
}
for k in ("red", "yellow", "green", "cyan", "blue", "magenta"):
    out[k] = c[k]; out[f"bright_{k}"] = c[f"bright_{k}"]
for i in range(16):
    out[f"color{i}"] = a[f"color{i}"].upper()
with open(f"{D}/colors.toml", "w") as f:
    f.write("# Generated from Aether by custom/notch/post-apply.sh — edit in Aether, not here.\n\n")
    f.writelines(f'{k} = "{v}"\n' for k, v in out.items())

wall = a.get("wallpaper", "")
if wall and os.path.isfile(wall):
    os.makedirs(f"{D}/backgrounds", exist_ok=True)
    for old in os.listdir(f"{D}/backgrounds"):
        os.remove(f"{D}/backgrounds/{old}")
    shutil.copy(wall, f"{D}/backgrounds/aether{os.path.splitext(wall)[1] or '.jpg'}")

bin = os.path.expanduser("~/.local/bin")
os.environ["PATH"] = f"{bin}:{os.environ['PATH']}"
audit = subprocess.run(["notch-theme", "audit", "aether"], capture_output=True, text=True)
if audit.returncode:
    first = audit.stdout.splitlines()[0] if audit.stdout else "contrast check failed"
    subprocess.run(["notify-send", "-u", "normal", "Aether theme: low contrast", first])
subprocess.run(["notch-theme", "set", "aether"])
