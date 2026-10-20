#!/usr/bin/env python3
"""Generate everything themed from palettes.json.

    python themes/build.py              VSCodium themes + .vsix
    python themes/build.py wallpapers   also recolour the wallpapers (needs Pillow + numpy)

Outputs:
    themes/vscodium/                     the extension source (package.json, themes/*.json)
    themes/dist/dotfiles-themes.vsix     install with: codium --install-extension <it> --force
    wallpapers/themes/<theme>/<app>.jpg  each app's picture recoloured for the theme (see build_wallpapers)
"""
import json
import sys
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
DOT = HERE.parent
PALETTES = json.loads((HERE / "palettes.json").read_text(encoding="utf-8"))
# Entries with "builtin" (Default) use an editor's own theme and the original pictures: nothing to build
GENERATED = {tid: p for tid, p in PALETTES.items() if "builtin" not in p}
VERSION = "0.1.0"


def label(p):
    return p["name"]


# ---- VSCodium ----

def workbench(p):
    u, d, g = p["ui"], p["diag"], p["git"]
    s = p["syntax"]
    light = p["type"] == "light"
    ansi_names = ["Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White"]
    c = {
        "foreground": u["fg"],
        "descriptionForeground": u["fgDim"],
        "errorForeground": d["error"],
        "icon.foreground": u["fgDim"],
        "focusBorder": u["accent"] + "80",
        "selection.background": u["sel"],
        "widget.shadow": "#00000014" if light else "#00000055",
        "widget.border": u["border"],
        "sash.hoverBorder": u["accent"],
        "textLink.foreground": u["accent"],
        "textLink.activeForeground": u["accent"],
        "textBlockQuote.background": u["bgDim"],
        "textBlockQuote.border": u["accent"],
        "textCodeBlock.background": u["bgDim"],
        "textPreformat.foreground": s["string"],

        "button.background": u["accent"],
        "button.foreground": u["onAccent"],
        "button.hoverBackground": u["accent"] + "d9",
        "button.secondaryBackground": u["bgAlt"],
        "button.secondaryForeground": u["fg"],
        "button.secondaryHoverBackground": u["sel"],
        "badge.background": u["accent"],
        "badge.foreground": u["onAccent"],
        "activityBarBadge.background": u["accent"],
        "activityBarBadge.foreground": u["onAccent"],
        "progressBar.background": u["accent"],

        "input.background": u["bgDim"],
        "input.foreground": u["fg"],
        "input.border": u["border"],
        "input.placeholderForeground": u["faint"],
        "inputOption.activeBorder": u["accent"],
        "inputOption.activeBackground": u["accent"] + "33",
        "inputValidation.errorBorder": d["error"],
        "inputValidation.errorBackground": u["bgDim"],
        "inputValidation.warningBorder": d["warning"],
        "inputValidation.warningBackground": u["bgDim"],
        "inputValidation.infoBorder": d["info"],
        "inputValidation.infoBackground": u["bgDim"],
        "dropdown.background": u["bgDim"],
        "dropdown.foreground": u["fg"],
        "dropdown.border": u["border"],
        "checkbox.background": u["bgDim"],
        "checkbox.border": u["border"],
        "scrollbarSlider.background": u["faint"] + "33",
        "scrollbarSlider.hoverBackground": u["faint"] + "55",
        "scrollbarSlider.activeBackground": u["faint"] + "77",

        "list.activeSelectionBackground": u["sel"],
        "list.activeSelectionForeground": u["fg"],
        "list.inactiveSelectionBackground": u["lineHl"],
        "list.inactiveSelectionForeground": u["fg"],
        "list.hoverBackground": u["lineHl"],
        "list.focusOutline": u["accent"] + "80",
        "list.highlightForeground": u["accent"],
        "list.errorForeground": d["error"],
        "list.warningForeground": d["warning"],
        "list.dropBackground": u["sel"],
        "tree.indentGuidesStroke": u["border"],

        "activityBar.background": u["bgDim"],
        "activityBar.foreground": u["fg"],
        "activityBar.inactiveForeground": u["faint"],
        "activityBar.border": u["border"],
        "activityBar.activeBorder": u["accent"],
        "sideBar.background": u["bgDim"],
        "sideBar.foreground": u["fgDim"],
        "sideBar.border": u["border"],
        "sideBarTitle.foreground": u["fg"],
        "sideBarSectionHeader.background": u["bgDim"],
        "sideBarSectionHeader.foreground": u["fg"],
        "sideBarSectionHeader.border": u["border"],

        "editorGroup.border": u["border"],
        "editorGroup.dropBackground": u["sel"] + "80",
        "editorGroupHeader.tabsBackground": u["bgDim"],
        "editorGroupHeader.tabsBorder": u["border"],
        "editorGroupHeader.noTabsBackground": u["bg"],
        "tab.activeBackground": u["bg"],
        "tab.activeForeground": u["fg"],
        "tab.inactiveBackground": u["bgDim"],
        "tab.inactiveForeground": u["fgDim"],
        "tab.hoverBackground": u["bg"],
        "tab.border": u["border"],
        "tab.activeBorderTop": u["accent"],
        "tab.unfocusedActiveForeground": u["fgDim"],
        "tab.unfocusedActiveBorderTop": u["faint"],
        "breadcrumb.foreground": u["fgDim"],
        "breadcrumb.focusForeground": u["fg"],
        "breadcrumb.activeSelectionForeground": u["accent"],
        "breadcrumbPicker.background": u["bgDim"],

        "editor.background": u["bg"],
        "editor.foreground": u["fg"],
        "editorLineNumber.foreground": u["faint"],
        "editorLineNumber.activeForeground": u["fgDim"],
        "editorCursor.foreground": u["accent"],
        "editor.selectionBackground": u["sel"],
        "editor.inactiveSelectionBackground": u["sel"] + "80",
        "editor.selectionHighlightBackground": u["sel"] + "80",
        "editor.wordHighlightBackground": u["sel"] + "80",
        "editor.wordHighlightStrongBackground": u["sel"],
        "editor.findMatchBackground": d["warning"] + "55",
        "editor.findMatchHighlightBackground": d["warning"] + "30",
        "editor.findRangeHighlightBackground": u["sel"] + "60",
        "editor.lineHighlightBackground": u["lineHl"],
        "editor.lineHighlightBorder": "#00000000",
        "editor.rangeHighlightBackground": u["sel"] + "50",
        "editorWhitespace.foreground": u["faint"] + "60",
        "editorIndentGuide.background1": u["border"],
        "editorIndentGuide.activeBackground1": u["faint"],
        "editorRuler.foreground": u["border"],
        "editorBracketMatch.background": u["sel"] + "80",
        "editorBracketMatch.border": u["faint"],
        "editorCodeLens.foreground": u["faint"],
        "editorLink.activeForeground": u["accent"],
        "editorError.foreground": d["error"],
        "editorWarning.foreground": d["warning"],
        "editorInfo.foreground": d["info"],
        "editorHint.foreground": d["hint"],
        "editorOverviewRuler.border": u["border"],
        "editorGutter.addedBackground": g["added"],
        "editorGutter.modifiedBackground": g["modified"],
        "editorGutter.deletedBackground": g["deleted"],
        "diffEditor.insertedTextBackground": g["added"] + "26",
        "diffEditor.removedTextBackground": g["deleted"] + "26",
        "diffEditor.insertedLineBackground": g["added"] + "14",
        "diffEditor.removedLineBackground": g["deleted"] + "14",

        "editorWidget.background": u["bgDim"],
        "editorWidget.border": u["border"],
        "editorSuggestWidget.background": u["bgDim"],
        "editorSuggestWidget.border": u["border"],
        "editorSuggestWidget.foreground": u["fg"],
        "editorSuggestWidget.selectedBackground": u["sel"],
        "editorSuggestWidget.highlightForeground": u["accent"],
        "editorHoverWidget.background": u["bgDim"],
        "editorHoverWidget.border": u["border"],
        "peekView.border": u["accent"],
        "peekViewTitle.background": u["bgAlt"],
        "peekViewEditor.background": u["bgDim"],
        "peekViewResult.background": u["bgDim"],
        "peekViewResult.selectionBackground": u["sel"],
        "peekViewEditor.matchHighlightBackground": d["warning"] + "40",
        "peekViewResult.matchHighlightBackground": d["warning"] + "40",
        "minimap.background": u["bg"],
        "minimapSlider.background": u["faint"] + "22",
        "minimapSlider.hoverBackground": u["faint"] + "33",
        "minimapSlider.activeBackground": u["faint"] + "44",

        "panel.background": u["bgDim"],
        "panel.border": u["border"],
        "panelTitle.activeForeground": u["fg"],
        "panelTitle.inactiveForeground": u["faint"],
        "panelTitle.activeBorder": u["accent"],
        "terminal.background": u["bgDim"],
        "terminal.foreground": u["fg"],
        "terminalCursor.foreground": u["accent"],
        "terminal.selectionBackground": u["sel"],

        "statusBar.background": u["bgDim"],
        "statusBar.foreground": u["fgDim"],
        "statusBar.border": u["border"],
        "statusBar.noFolderBackground": u["bgDim"],
        "statusBar.debuggingBackground": d["warning"],
        "statusBar.debuggingForeground": u["bg"],
        "statusBarItem.remoteBackground": u["accent"],
        "statusBarItem.remoteForeground": u["onAccent"],
        "statusBarItem.hoverBackground": u["lineHl"],
        "titleBar.activeBackground": u["bgDim"],
        "titleBar.activeForeground": u["fg"],
        "titleBar.inactiveBackground": u["bgDim"],
        "titleBar.inactiveForeground": u["faint"],
        "titleBar.border": u["border"],
        "menu.background": u["bgDim"],
        "menu.foreground": u["fg"],
        "menu.selectionBackground": u["sel"],
        "menu.selectionForeground": u["fg"],
        "menu.separatorBackground": u["border"],
        "menu.border": u["border"],
        "menubar.selectionBackground": u["lineHl"],
        "quickInput.background": u["bgDim"],
        "quickInput.foreground": u["fg"],
        "quickInputList.focusBackground": u["sel"],
        "pickerGroup.foreground": u["accent"],
        "pickerGroup.border": u["border"],
        "notifications.background": u["bgDim"],
        "notifications.foreground": u["fg"],
        "notifications.border": u["border"],
        "notificationCenterHeader.background": u["bgAlt"],
        "debugToolBar.background": u["bgDim"],
        "settings.headerForeground": u["fg"],
        "settings.modifiedItemIndicator": u["accent"],
        "keybindingLabel.background": u["bgAlt"],
        "keybindingLabel.foreground": u["fg"],
        "keybindingLabel.border": u["border"],
        "keybindingLabel.bottomBorder": u["border"],

        "gitDecoration.addedResourceForeground": g["added"],
        "gitDecoration.untrackedResourceForeground": g["added"],
        "gitDecoration.modifiedResourceForeground": g["modified"],
        "gitDecoration.deletedResourceForeground": g["deleted"],
        "gitDecoration.conflictingResourceForeground": d["warning"],
        "gitDecoration.ignoredResourceForeground": u["faint"],
    }
    for i, col in enumerate([s["keyword"], s["function"], s["string"], s["number"], s["type"], s["constant"]], 1):
        c[f"editorBracketHighlight.foreground{i}"] = col
    for i, col in enumerate(p["ansi"]):
        c[f"terminal.ansi{'Bright' if i >= 8 else ''}{ansi_names[i % 8]}"] = col
    return c


def token_colors(p):
    s, g = p["syntax"], p["git"]
    rules = [
        (["comment", "punctuation.definition.comment",
          "string.quoted.docstring", "string.quoted.double.block.python", "string.quoted.single.block.python"],
         s["comment"], "italic"),
        (["keyword", "storage.type", "storage.modifier", "keyword.control"], s["keyword"], None),
        (["keyword.operator", "keyword.operator.assignment"], s["operator"], None),
        (["keyword.control.import", "keyword.control.from", "keyword.control.export", "keyword.other.import"], s["import"], None),
        (["entity.name.function", "support.function", "meta.function-call.generic", "variable.function"], s["function"], None),
        (["string", "punctuation.definition.string"], s["string"], None),
        (["constant.numeric"], s["number"], None),
        (["constant.language", "constant.other", "support.constant", "variable.other.constant", "variable.other.enummember"], s["constant"], None),
        (["entity.name.type", "entity.name.class", "entity.name.namespace", "support.type", "support.class",
          "entity.other.inherited-class", "storage.type.primitive", "storage.type.built-in"], s["type"], None),
        (["variable", "variable.other"], s["variable"], None),
        (["variable.parameter", "meta.parameter"], s["parameter"], None),
        (["variable.other.property", "variable.other.object.property", "support.variable.property",
          "meta.object-literal.key", "support.type.property-name", "entity.name.tag.yaml"], s["property"], None),
        (["variable.language", "variable.language.this", "variable.parameter.function.language.special.self"], s["language"], "italic"),
        (["entity.name.tag"], s["tag"], None),
        (["entity.other.attribute-name"], s["attribute"], None),
        (["punctuation", "meta.brace", "punctuation.separator", "punctuation.terminator"], s["punctuation"], None),
        (["constant.character.escape", "constant.character.format.placeholder"], s["escape"], None),
        (["string.regexp"], s["regexp"], None),
        (["invalid", "invalid.illegal"], s["invalid"], None),
        (["meta.decorator", "entity.name.function.decorator", "punctuation.decorator"], s["function"], "italic"),
        (["markup.heading", "entity.name.section"], s["function"], "bold"),
        (["markup.bold"], None, "bold"),
        (["markup.italic"], None, "italic"),
        (["markup.underline.link", "string.other.link"], p["ui"]["accent"], None),
        (["markup.inline.raw", "markup.fenced_code.block"], s["string"], None),
        (["markup.quote"], s["comment"], "italic"),
        (["markup.list punctuation.definition.list.begin"], s["keyword"], None),
        (["markup.inserted"], g["added"], None),
        (["markup.deleted"], g["deleted"], None),
        (["markup.changed"], g["modified"], None),
    ]
    out = []
    for scopes, fg, style in rules:
        settings = {}
        if fg:
            settings["foreground"] = fg
        if style:
            settings["fontStyle"] = style
        out.append({"scope": scopes, "settings": settings})
    return out


def semantic(p):
    s = p["syntax"]
    return {
        "variable": s["variable"], "parameter": s["parameter"], "property": s["property"],
        "function": s["function"], "method": s["function"], "macro": s["constant"],
        "type": s["type"], "class": s["type"], "interface": s["type"], "enum": s["type"],
        "struct": s["type"], "typeParameter": s["type"], "namespace": s["type"],
        "enumMember": s["constant"], "variable.readonly": s["constant"], "decorator": s["function"],
        "keyword": s["keyword"], "number": s["number"], "string": s["string"],
        "selfParameter": {"foreground": s["language"], "italic": True},
    }


def build_vscodium():
    ext = HERE / "vscodium"
    (ext / "themes").mkdir(parents=True, exist_ok=True)
    for old in (ext / "themes").glob("*.json"):  # drop themes that were renamed or removed
        if old.stem not in GENERATED:
            old.unlink()
    contributes = []
    for tid, p in GENERATED.items():
        theme = {
            "name": label(p),
            "type": p["type"],
            "semanticHighlighting": True,
            "colors": workbench(p),
            "tokenColors": token_colors(p),
            "semanticTokenColors": semantic(p),
        }
        (ext / "themes" / f"{tid}.json").write_text(json.dumps(theme, indent=2) + "\n", encoding="utf-8")
        contributes.append({"label": label(p), "uiTheme": "vs" if p["type"] == "light" else "vs-dark",
                            "path": f"./themes/{tid}.json"})
    pkg = {
        "name": "dotfiles-themes",
        "displayName": "Dotfiles Themes",
        "description": "Generated from ~/dotfiles/themes/palettes.json by themes/build.py.",
        "publisher": "denys",
        "version": VERSION,
        "engines": {"vscode": "^1.70.0"},
        "categories": ["Themes"],
        "contributes": {"themes": contributes},
    }
    (ext / "package.json").write_text(json.dumps(pkg, indent=2) + "\n", encoding="utf-8")

    # A .vsix is a zip: two manifests plus the extension under extension/
    dist = HERE / "dist"
    dist.mkdir(exist_ok=True)
    vsix = dist / "dotfiles-themes.vsix"
    manifest = f"""<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="dotfiles-themes" Version="{VERSION}" Publisher="denys"/>
    <DisplayName>Dotfiles Themes</DisplayName>
    <Description xml:space="preserve">{pkg['description']}</Description>
    <Categories>Themes</Categories>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="{pkg['engines']['vscode']}"/>
    </Properties>
  </Metadata>
  <Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation>
  <Dependencies/>
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/>
  </Assets>
</PackageManifest>
"""
    types = """<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension=".json" ContentType="application/json"/>
  <Default Extension=".vsixmanifest" ContentType="text/xml"/>
</Types>
"""
    with zipfile.ZipFile(vsix, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", types)
        z.writestr("extension.vsixmanifest", manifest)
        for f in sorted(ext.rglob("*")):
            if f.is_file():
                z.write(f, "extension/" + f.relative_to(ext).as_posix())
    print("built", vsix.relative_to(DOT))


# ---- Wallpapers ----

APPS = ["code-editor", "desktop", "browser", "launcher", "terminal"]


def gradient_map(path, stops):
    """Recolour by brightness: darkest 1% -> first stop, brightest 1% -> last."""
    import numpy as np
    from PIL import Image

    img = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255
    lum = img @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    lo, hi = np.percentile(lum, [1, 99])
    t = np.clip((lum - lo) / max(hi - lo, 1e-6), 0, 1)
    cs = np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)] for h in stops], dtype=np.float32) / 255
    pos = np.linspace(0, 1, len(cs))
    rgb = np.stack([np.interp(t, pos, cs[:, ch]) for ch in range(3)], axis=-1)
    return Image.fromarray((rgb * 255 + 0.5).astype(np.uint8))


def build_wallpapers():
    """wallpapers/themes/<theme>/<app>.jpg for every theme and app.

    Each app keeps its own picture (wallpapers/<app>.jpg). An app with a
    scene spec under the theme's "wallpapers" is repainted by scene.py;
    the rest are gradient-mapped onto the theme's "stops".
    """
    from scene import Night

    night = None
    for tid, p in GENERATED.items():
        out_dir = DOT / "wallpapers" / "themes" / tid
        out_dir.mkdir(parents=True, exist_ok=True)
        w = p["wallpapers"]
        for app in APPS:
            src = DOT / "wallpapers" / f"{app}.jpg"
            if app == "code-editor" and app in w:
                night = night or Night(src)
                im = night.render(w[app])
            else:
                im = gradient_map(src, w["stops"])
            im.save(out_dir / f"{app}.jpg", quality=92)
            print(f"wallpapers/themes/{tid}/{app}.jpg")


if __name__ == "__main__":
    build_vscodium()
    if "wallpapers" in sys.argv[1:]:
        build_wallpapers()
