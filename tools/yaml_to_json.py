#!/usr/bin/env python3
"""Convert all game/data/**/*.yaml to game/data/**/*.json for Godot runtime loading.

Run from the repo root:
    python tools/yaml_to_json.py
"""
import yaml
import json
import pathlib
import sys

root = pathlib.Path("game/data")

if not root.exists():
    print(f"✗ Directory '{root}' not found. Run from the repo root.")
    sys.exit(1)

errors = []
converted = 0

for yaml_file in sorted(root.rglob("*.yaml")):
    try:
        data = yaml.safe_load(yaml_file.read_text())
        json_file = yaml_file.with_suffix(".json")
        json_file.write_text(json.dumps(data, indent=2))
        print(f"✓ {yaml_file} → {json_file.name}")
        converted += 1
    except Exception as e:
        errors.append(f"✗ {yaml_file}: {e}")
        print(errors[-1])

print(f"\n{converted} file(s) converted, {len(errors)} error(s).")

if errors:
    sys.exit(1)
