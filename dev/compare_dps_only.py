#!/usr/bin/env python3
"""
Compare WoWSims extracted weights with current ReforgeLite presets - DPS ONLY.
Dynamically parses wowsims_weights.lua and Presets.lua to avoid hardcoded values.
"""

import re
from pathlib import Path

STAT_NAMES = ["Spirit", "Dodge", "Parry", "Hit", "Crit", "Haste", "Expertise", "Mastery"]

# DPS specs to compare (excluding tank/healer specs)
DPS_SPECS = {
    "DEATHKNIGHT": ["frost", "unholy"],
    "DRUID": ["balance", "feralcombat"],
    "HUNTER": ["beastmastery", "marksmanship", "survival"],
    "MAGE": ["arcane", "fire", "frost"],
    "MONK": ["windwalker"],
    "PALADIN": ["retribution"],
    "PRIEST": ["shadow"],
    "ROGUE": ["assassination", "combat", "subtlety"],
    "SHAMAN": ["elemental", "enhancement"],
    "WARLOCK": ["affliction", "demonology", "destruction"],
    "WARRIOR": ["arms", "fury"],
}


def parse_lua_weights_array(text):
    """Parse a Lua array like {0, 0, 0, 82, 44, 45, 82, 35} into a tuple."""
    numbers = re.findall(r'\d+', text)
    return tuple(int(n) for n in numbers)


def parse_wowsims_weights(file_path):
    """Parse wowsims_weights.lua to extract stat weights."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    weights = {}
    current_class = None
    current_spec = None

    lines = content.split('\n')
    i = 0
    while i < len(lines):
        line = lines[i].strip()

        # Class comment: -- DEATHKNIGHT
        if line.startswith('-- ') and line[3:].strip() in DPS_SPECS:
            current_class = line[3:].strip()
            if current_class not in weights:
                weights[current_class] = {}

        # Spec with single preset: [frost] = {0, 0, 0, 82, 44, 45, 82, 35},
        elif match := re.match(r'\[(\w+)\]\s*=\s*(\{[^}]+\})', line):
            spec_name = match.group(1)
            if current_class and current_class in DPS_SPECS and spec_name in DPS_SPECS.get(current_class, []):
                weights_array = parse_lua_weights_array(match.group(2))
                weights[current_class][spec_name] = [weights_array]

        # Spec with multiple presets: [frost] = {
        elif match := re.match(r'\[(\w+)\]\s*=\s*\{', line):
            spec_name = match.group(1)
            if current_class and current_class in DPS_SPECS and spec_name in DPS_SPECS.get(current_class, []):
                current_spec = spec_name
                weights[current_class][spec_name] = []
                i += 1
                # Read preset lines until closing }
                while i < len(lines):
                    preset_line = lines[i].strip()
                    if preset_line == '},':
                        break
                    if preset_match := re.match(r'\[preset_\d+\]\s*=\s*(\{[^}]+\})', preset_line):
                        weights_array = parse_lua_weights_array(preset_match.group(1))
                        weights[current_class][current_spec].append(weights_array)
                    i += 1

        i += 1

    return weights


def parse_presets_lua(file_path):
    """Parse Presets.lua to extract stat weights for DPS specs."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    weights = {}

    # Find the presets table definition
    presets_match = re.search(r'local presets = \{(.+?)\n  \}', content, re.DOTALL)
    if not presets_match:
        return weights

    presets_content = presets_match.group(1)

    # Split by class sections: ["WARRIOR"] = {
    class_sections = re.findall(r'\["(\w+)"\]\s*=\s*\{([^}]+(?:\{[^}]*\}[^}]*)*)\}', presets_content)

    for class_name, class_content in class_sections:
        if class_name not in DPS_SPECS:
            continue

        weights[class_name] = {}

        # Look for spec entries
        for spec_name in DPS_SPECS[class_name]:
            # Pattern 1: MeleePreset(hit, crit, haste, exp, mastery)
            pattern1 = rf'\[specs\.{class_name}\.{spec_name}\]\s*=\s*MeleePreset\((\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\)'
            if match := re.search(pattern1, class_content):
                hit, crit, haste, exp, mastery = map(int, match.groups())
                weights[class_name][spec_name] = [(0, 0, 0, hit, crit, haste, exp, mastery)]

            # Pattern 2: CasterPreset(hit, crit, haste, mastery)
            pattern2 = rf'\[specs\.{class_name}\.{spec_name}\]\s*=\s*CasterPreset\((\d+),\s*(\d+),\s*(\d+),\s*(\d+)\)'
            if match := re.search(pattern2, class_content):
                hit, crit, haste, mastery = map(int, match.groups())
                weights[class_name][spec_name] = [(0, 0, 0, hit, crit, haste, 0, mastery)]

            # Pattern 3: weights = {0, 0, 0, 88, 54, 55, 0, 46}
            pattern3 = rf'\[specs\.{class_name}\.{spec_name}\]\s*=\s*\{{[^}}]*weights\s*=\s*(\{{[^}}]+\}})'
            if match := re.search(pattern3, class_content):
                weights_array = parse_lua_weights_array(match.group(1))
                weights[class_name][spec_name] = [weights_array]

            # Pattern 4: Multiple presets in a table
            pattern4 = rf'\[specs\.{class_name}\.{spec_name}\]\s*=\s*\{{([^}}]+Preset[^}}]+)\}}'
            if match := re.search(pattern4, class_content):
                preset_content = match.group(1)
                spec_weights = []

                # Find all Preset() calls
                for preset_match in re.finditer(r'Preset\((\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)', preset_content):
                    preset_tuple = tuple(int(x) for x in preset_match.groups())
                    spec_weights.append(preset_tuple)

                if spec_weights:
                    weights[class_name][spec_name] = spec_weights

    return weights


def format_weights(weights):
    """Format weights as string."""
    return "{" + ", ".join(str(w) for w in weights) + "}"


def compare_weights(ws_weights, rfl_weights):
    """Compare two weight tuples, return list of differences."""
    diffs = []
    for i, (ws, rfl) in enumerate(zip(ws_weights, rfl_weights)):
        if ws != rfl:
            diffs.append((STAT_NAMES[i], rfl, ws, ws - rfl))
    return diffs


def main():
    base_path = Path('/mnt/c/Git/ReforgeLite')
    wowsims_file = base_path / 'wowsims_weights.lua'
    presets_file = base_path / 'Presets.lua'

    print("Parsing WoWSims weights...")
    wowsims = parse_wowsims_weights(wowsims_file)

    print("Parsing ReforgeLite presets...")
    reforgelite = parse_presets_lua(presets_file)

    print()
    print("=" * 90)
    print("DPS SPEC STAT WEIGHT COMPARISON: ReforgeLite → WoWSims")
    print("=" * 90)
    print()

    exact_matches = []
    has_changes = []

    for class_name in sorted(wowsims.keys()):
        for spec_name in sorted(wowsims[class_name].keys()):
            ws_presets = wowsims[class_name][spec_name]
            rfl_presets = reforgelite.get(class_name, {}).get(spec_name, [])

            if not rfl_presets:
                continue

            # Find best match
            best_match = None
            best_diff_count = 999

            for ws_preset in ws_presets:
                for rfl_preset in rfl_presets:
                    diffs = compare_weights(ws_preset, rfl_preset)
                    if len(diffs) < best_diff_count:
                        best_diff_count = len(diffs)
                        best_match = (ws_preset, rfl_preset, diffs)

            if best_match:
                ws_preset, rfl_preset, diffs = best_match

                if not diffs:
                    exact_matches.append((class_name, spec_name))
                else:
                    has_changes.append((class_name, spec_name, ws_preset, rfl_preset, diffs))

    print(f"✓ NO CHANGES NEEDED ({len(exact_matches)} specs):")
    print(f"  {', '.join(f'{c} {s}' for c, s in exact_matches)}")
    print()
    print("=" * 90)
    print()

    if has_changes:
        print(f"SPECS WITH DIFFERENCES ({len(has_changes)} specs):")
        print()

        for class_name, spec_name, ws_preset, rfl_preset, diffs in has_changes:
            print(f"┌─ {class_name} - {spec_name.upper()}")
            print(f"│")
            print(f"│  Current:  {format_weights(rfl_preset)}")
            print(f"│  WoWSims:  {format_weights(ws_preset)}")
            print(f"│")
            print(f"│  Changes:")

            for stat, rfl, ws, change in diffs:
                sign = "+" if change > 0 else ""
                arrow = "↑" if change > 0 else "↓"
                print(f"│    • {stat:10} {rfl:3} → {ws:3}  ({sign}{change:4}) {arrow}")
            print(f"└─")
            print()

    print("=" * 90)
    print(f"SUMMARY: {len(exact_matches)} exact matches, {len(has_changes)} with differences")
    print("=" * 90)


if __name__ == '__main__':
    main()
