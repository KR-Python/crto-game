#!/usr/bin/env python3
"""
validate_schemas.py — CRTO YAML data file validator
Phase 0 stub: validates all YAML files are parseable.
Full schema validation is TODO per schema type.
"""

import sys
import glob
import os

try:
    import yaml
except ImportError:
    print("✗ ERROR: PyYAML not installed. Run: pip install pyyaml")
    sys.exit(1)

# TODO: Full schema validation per type
SCHEMA_TODOS = {
    "unit": "TODO: Validate unit stats (hp, speed, damage ranges), ability refs, faction membership",
    "structure": "TODO: Validate structure build costs, produced units, footprint sizes",
    "tech": "TODO: Validate tech tree (no cycles), prerequisite IDs exist, unlock targets valid",
    "resource": "TODO: Validate resource node positions on valid terrain, harvester reachability",
    "map": "TODO: Validate spawn points on valid terrain, map dimensions, resource placement",
    "ability": "TODO: Validate ability cooldowns, effect refs, targeting rules",
    "faction": "TODO: Validate faction unit/structure rosters, starting resources",
}

def main():
    data_dir = os.path.join(os.path.dirname(__file__), "..", "game", "data")
    pattern = os.path.join(data_dir, "**", "*.yaml")
    files = glob.glob(pattern, recursive=True)

    if not files:
        print("⚠ No YAML files found in game/data/ — skipping validation")
        print()
        print("=== Schema TODO List ===")
        for schema_type, todo in SCHEMA_TODOS.items():
            print(f"  [{schema_type}] {todo}")
        sys.exit(0)

    errors = []
    valid_count = 0

    for filepath in sorted(files):
        rel_path = os.path.relpath(filepath)
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                data = yaml.safe_load(f)
            valid_count += 1
            # TODO: Route to per-schema validator based on file path / type field
        except yaml.YAMLError as e:
            errors.append((rel_path, str(e)))
            print(f"✗ ERROR: {rel_path} — {e}")
        except Exception as e:
            errors.append((rel_path, str(e)))
            print(f"✗ ERROR: {rel_path} — {e}")

    print()
    print("=== Schema TODO List (full validation not yet implemented) ===")
    for schema_type, todo in SCHEMA_TODOS.items():
        print(f"  [{schema_type}] {todo}")
    print()

    if errors:
        print(f"✗ {len(errors)} file(s) invalid, {valid_count} valid")
        sys.exit(1)
    else:
        print(f"✓ {valid_count} files valid")
        sys.exit(0)

if __name__ == "__main__":
    main()
