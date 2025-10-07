#!/usr/bin/env python3
"""
Extract stat weights from WoWSims MoP preset files.
Converts TypeScript stat definitions to Lua format for ReforgeLite.
"""

import json
import os
import re
from pathlib import Path

# WoWSims stat enum to ReforgeLite stat index mapping
STAT_MAP = {
    'StatSpirit': 1,
    'StatDodgeRating': 2,
    'StatParryRating': 3,
    'StatHitRating': 4,
    'StatCritRating': 5,
    'StatHasteRating': 6,
    'StatExpertiseRating': 7,
    'StatMasteryRating': 8,
}

# Class name mapping
CLASS_MAP = {
    'death_knight': 'DEATHKNIGHT',
    'druid': 'DRUID',
    'hunter': 'HUNTER',
    'mage': 'MAGE',
    'monk': 'MONK',
    'paladin': 'PALADIN',
    'priest': 'PRIEST',
    'rogue': 'ROGUE',
    'shaman': 'SHAMAN',
    'warlock': 'WARLOCK',
    'warrior': 'WARRIOR',
}

# Spec name mapping
SPEC_MAP = {
    'blood': 'blood',
    'frost': 'frost',
    'unholy': 'unholy',
    'balance': 'balance',
    'feral': 'feralcombat',
    'guardian': 'guardian',
    'restoration': 'restoration',
    'beast_mastery': 'beastmastery',
    'marksmanship': 'marksmanship',
    'survival': 'survival',
    'arcane': 'arcane',
    'fire': 'fire',
    'brewmaster': 'brewmaster',
    'mistweaver': 'mistweaver',
    'windwalker': 'windwalker',
    'holy': 'holy',
    'protection': 'protection',
    'retribution': 'retribution',
    'discipline': 'discipline',
    'shadow': 'shadow',
    'assassination': 'assassination',
    'combat': 'combat',
    'subtlety': 'subtlety',
    'elemental': 'elemental',
    'enhancement': 'enhancement',
    'affliction': 'affliction',
    'demonology': 'demonology',
    'destruction': 'destruction',
    'arms': 'arms',
    'fury': 'fury',
}

def extract_stat_weights(file_path):
    """Extract stat weights from a WoWSims preset TypeScript file."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find all EP preset definitions
    # Pattern: Stats.fromMap({ ... })
    pattern = r'Stats\.fromMap\s*\(\s*\{([^}]+)\}'

    matches = re.findall(pattern, content, re.DOTALL)

    weights_list = []
    for match in matches:
        weights = [0] * 8  # Spirit, Dodge, Parry, Hit, Crit, Haste, Exp, Mastery

        # Extract individual stat mappings
        stat_pattern = r'\[Stat\.(\w+)\]:\s*([\d.]+)'
        for stat_match in re.finditer(stat_pattern, match):
            stat_name, value = stat_match.groups()
            if stat_name in STAT_MAP:
                idx = STAT_MAP[stat_name] - 1  # Convert to 0-indexed
                weights[idx] = float(value)

        weights_list.append(weights)

    return weights_list

def find_preset_files(wowsims_path):
    """Find all preset.ts files in WoWSims UI directory."""
    ui_path = Path(wowsims_path) / 'ui'

    results = {}

    for class_dir in CLASS_MAP.keys():
        class_path = ui_path / class_dir
        if not class_path.exists():
            continue

        # Find all spec directories
        for spec_dir in class_path.iterdir():
            if not spec_dir.is_dir():
                continue

            preset_file = spec_dir / 'presets.ts'
            if preset_file.exists():
                spec_name = spec_dir.name
                if spec_name in SPEC_MAP:
                    weights = extract_stat_weights(preset_file)
                    if weights:
                        if class_dir not in results:
                            results[class_dir] = {}
                        results[class_dir][spec_name] = weights

    return results

def format_lua_weights(weights):
    """Format weights array as Lua table."""
    # Scale by 100 and round to integers (WoWSims uses 0-1 scale, ReforgeLite uses 0-100+)
    scaled = [round(w * 100) for w in weights]
    return '{' + ', '.join(str(w) for w in scaled) + '}'

def generate_lua_output(results):
    """Generate Lua code for ReforgeLite presets."""
    lines = []
    lines.append("-- Stat weights extracted from WoWSims MoP")
    lines.append("-- Format: {Spirit, Dodge, Parry, Hit, Crit, Haste, Expertise, Mastery}")
    lines.append("")

    for class_name in sorted(results.keys()):
        lua_class = CLASS_MAP[class_name]
        lines.append(f"-- {lua_class}")

        for spec_name in sorted(results[class_name].keys()):
            lua_spec = SPEC_MAP.get(spec_name, spec_name)
            weights_list = results[class_name][spec_name]

            if len(weights_list) == 1:
                lines.append(f"  [{lua_spec}] = {format_lua_weights(weights_list[0])},")
            else:
                lines.append(f"  [{lua_spec}] = {{")
                for i, weights in enumerate(weights_list):
                    lines.append(f"    [preset_{i+1}] = {format_lua_weights(weights)},")
                lines.append("  },")

        lines.append("")

    return '\n'.join(lines)

def main():
    wowsims_path = '/mnt/c/Git/wowsims_mop'

    print("Extracting stat weights from WoWSims...")
    results = find_preset_files(wowsims_path)

    print(f"Found stat weights for {sum(len(specs) for specs in results.values())} specs")
    print("")

    # Generate Lua output
    lua_output = generate_lua_output(results)

    # Save to file
    output_file = '/mnt/c/Git/ReforgeLite/wowsims_weights.lua'
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(lua_output)

    print(f"Saved to {output_file}")
    print("")
    print("Summary by class:")
    for class_name in sorted(results.keys()):
        specs = list(results[class_name].keys())
        print(f"  {CLASS_MAP[class_name]}: {', '.join(specs)}")

if __name__ == '__main__':
    main()
