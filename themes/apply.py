#!/usr/bin/env python3
"""Switch VSCodium to one of the dotfiles themes, or put things back.

    python themes/apply.py <theme>         default, soft-paper, cold-stone, midnight, blue-skies, dark-forest
    python themes/apply.py restore         colour theme + background back to themes/baseline/vscodium-settings.json
    python themes/apply.py restore --full  the whole settings.json back to the baseline copy
    python themes/apply.py list

Only "workbench.colorTheme" and the background picture in vscodium/settings.json
are touched, so other edits made since survive a plain restore. "default" is
VSCodium's own Dark Modern with the original picture; the other themes come
from the extension built by build.py:
    codium --install-extension themes/dist/dotfiles-themes.vsix --force
"""
import json
import re
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DOT = HERE.parent
SETTINGS = DOT / "vscodium" / "settings.json"
BASELINE = HERE / "baseline" / "vscodium-settings.json"
PALETTES = json.loads((HERE / "palettes.json").read_text(encoding="utf-8"))

THEME_RE = re.compile(r'("workbench\.colorTheme":\s*)"[^"]*"')
IMAGE_RE = re.compile(r'("background\.fullscreen":\s*\{\s*"images":\s*\[)"[^"]*"')


def current(text):
    return THEME_RE.search(text).group(0).split('"')[3], IMAGE_RE.search(text).group(0).rsplit('"', 2)[1]


def write(theme, image):
    text = SETTINGS.read_text(encoding="utf-8")
    text = THEME_RE.sub(lambda m: f'{m.group(1)}"{theme}"', text, count=1)
    text = IMAGE_RE.sub(lambda m: f'{m.group(1)}"{image}"', text, count=1)
    # Write through the symlink so %APPDATA%\VSCodium\User\settings.json stays linked
    SETTINGS.write_text(text, encoding="utf-8", newline="")
    print(f"colorTheme: {theme}\nbackground: {image}")


def main(args):
    if not args or args[0] == "list":
        theme, image = current(SETTINGS.read_text(encoding="utf-8"))
        print("now:", theme, "|", image)
        print("themes:", ", ".join(PALETTES))
        return
    if args[0] == "restore":
        if "--full" in args:
            shutil.copyfile(BASELINE, SETTINGS)
            print("settings.json replaced with", BASELINE.relative_to(DOT))
        else:
            write(*current(BASELINE.read_text(encoding="utf-8")))
        return
    tid = args[0]
    if tid not in PALETTES:
        sys.exit(f"unknown theme {tid!r}; one of: {', '.join(PALETTES)}")
    p = PALETTES[tid]
    if "builtin" in p:
        write(p["builtin"], (DOT / "wallpapers" / "code-editor.jpg").as_uri())
    else:
        write(p["name"], (DOT / "wallpapers" / "themes" / tid / "code-editor.jpg").as_uri())


if __name__ == "__main__":
    main(sys.argv[1:])
