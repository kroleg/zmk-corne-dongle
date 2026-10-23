"""Rewrite the QWERTY (RU) layer of a keymap-drawer YAML with Cyrillic legends,
and export it with key geometry as JSON for the Raycast extension.

Usage: ru_legends.py <parsed.yaml> <keymap> <layouts.dtsi> <out.yaml> <out.json>

Letters are what the macOS "Russian" (Apple) layout types for each key.
On the RU layer the parser puts the Colemak shortcut letter in the shifted
slot; it's replaced with the Alt variant (rus_* mod-morphs) or dropped.
"""

import json
import re
import sys

import yaml

RU_LAYER = "QWERTY"

# ZMK keycode -> character in macOS "Russian" layout
RU = {
    "Q": "й", "W": "ц", "E": "у", "R": "к", "T": "е", "Y": "н", "U": "г",
    "I": "ш", "O": "щ", "P": "з", "LBKT": "х", "RBKT": "ъ",
    "A": "ф", "S": "ы", "D": "в", "F": "а", "G": "п", "H": "р", "J": "о",
    "K": "л", "L": "д", "SEMI": "ж", "SQT": "э", "BSLH": "ё",
    "Z": "я", "X": "ч", "C": "с", "V": "м", "B": "и", "N": "т", "M": "ь",
    "COMMA": "б", "DOT": "ю", "FSLH": "/", "GRAVE": "]",
}
# keymap-drawer legend -> ZMK keycode, for the non-letter keys
LEGEND = {"[": "LBKT", "]": "RBKT", ";": "SEMI", "'": "SQT", "\\": "BSLH",
          ",": "COMMA", ".": "DOT", "/": "FSLH", "`": "GRAVE"}


def ru(legend):
    if not isinstance(legend, str):
        return legend
    code = LEGEND.get(legend, legend.upper() if len(legend) == 1 else legend)
    return RU.get(code, legend)


def alt_variants(keymap):
    """(RU tap keycode, Colemak keycode) -> Alt keycode, from SC_ALT_KEY + rus_* morphs."""
    morphs = dict(
        (m[0], (m[1], m[2]))
        for m in re.findall(r"(\w+): \w+ \{[^}]*?bindings = <&kp (\w+)>, <&kp (\w+)>;\s*mods = <\(MOD_RALT\|MOD_LALT\)>", keymap)
    )
    out = {}
    for name, inner, en in re.findall(r"SC_ALT_KEY\((\w+), (\w+), (\w+)\)", keymap):
        if inner in morphs:
            tap, alt = morphs[inner]
            out[(tap, en)] = alt
    return out


def convert_key(key, alts):
    if isinstance(key, str):
        return ru(key)
    if not isinstance(key, dict) or "t" not in key:
        return key
    key = dict(key)
    tap = LEGEND.get(key["t"], key["t"])
    shifted = key.pop("s", None)
    if shifted is not None and (tap, shifted) in alts:
        key["s"] = "⌥ " + RU[alts[(tap, shifted)]]
    key["t"] = ru(key["t"])
    return key


def physical_keys(dtsi):
    """key_physical_attrs w h x y rot rx ry (rot in centidegrees) -> dicts."""
    keys = []
    for attrs in re.findall(r"<&key_physical_attrs([^>]*)>", dtsi):
        w, h, x, y, r, rx, ry = (int(v) for v in re.findall(r"-?\d+", attrs.replace("(", "").replace(")", "")))
        keys.append({"x": x, "y": y, "w": w, "h": h, "r": r / 100, "rx": rx, "ry": ry})
    return keys


def main():
    parsed, keymap, layouts, out_yaml, out_json = sys.argv[1:6]
    data = yaml.safe_load(open(parsed))
    alts = alt_variants(open(keymap).read())
    data["layers"][RU_LAYER] = [convert_key(k, alts) for k in data["layers"][RU_LAYER]]
    for combo in data.get("combos", []):
        if combo.get("l") == [RU_LAYER]:
            k = combo["k"]
            combo["k"] = ru(k["t"] if isinstance(k, dict) else k)
    with open(out_yaml, "w") as f:
        yaml.safe_dump(data, f, allow_unicode=True, sort_keys=False)
    with open(out_json, "w") as f:
        json.dump({"keys": physical_keys(open(layouts).read()), **data}, f, ensure_ascii=False, indent=1)


main()
