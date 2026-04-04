# Setting Up CRTO in Godot 4.4

## Prerequisites

- **Godot 4.4+** — download from [godotengine.org](https://godotengine.org/download/)
- **Python 3.8+** — for data pipeline tools
- **Git**

---

## Steps

### 1. Clone the Repository

```bash
git clone https://github.com/KR-Python/crto-game.git
cd crto-game
```

### 2. Generate Runtime Data Files

CRTO's game data lives in YAML (human/agent-editable) and must be compiled to JSON before the game can load it.

```bash
python3 tools/yaml_to_json.py
```

This reads from `game/data/` and writes JSON output to `game/data/generated/`. **Run this every time you modify YAML files.**

### 3. Validate Data Integrity (Optional but Recommended)

```bash
python3 tools/validate_schemas.py
```

Checks cross-references (e.g., tech tree prerequisites point to real units, structure costs are valid). CI runs this automatically on push.

### 4. Import the Project in Godot

1. Open Godot 4.4+
2. Click **Import** (or **Import Project**)
3. Navigate to `crto-game/game/` and select `project.godot`
4. Click **Import & Edit**

### 5. Scene Wiring (Required)

`.tscn` files are **not committed** to the repository — they must be created in the Godot editor. The scene tree is documented in `game/src/core/main_scene.gd`.

To wire the main scene:
1. In Godot, create a new scene: **Scene → New Scene**
2. Follow the node tree described in `game/src/core/main_scene.gd` (comments at the top document the expected structure)
3. Save as `game/src/core/main_scene.tscn`
4. In **Project Settings → Application → Run**, set the main scene to `res://src/core/main_scene.tscn`

> **Why?** `.tscn` files contain absolute editor paths and binary-adjacent formatting that creates bad merge conflicts. The approach here is code-first: scene trees are defined in GDScript and wired manually once per workstation.

### 6. Run the Project

Press **F5** (or **Run → Run Project**) to start.

---

## Known Setup Issues

| Issue | Solution |
|-------|----------|
| `DataLoader: file not found: units/...json` | Run `python3 tools/yaml_to_json.py` first |
| Missing scene error on run | Complete Step 5 (scene wiring) above |
| Schema validation errors after editing YAML | Run `python3 tools/validate_schemas.py` to find broken cross-references |
| C++ GDExtension not compiling | The `game/native/` extension is optional — pure GDScript fallback is available; see `game/src/core/config.gd` |

---

## Running Tests

Tests are written in GDScript. Run them via the Godot editor's built-in test runner, or headless:

```bash
# Headless test run (requires Godot in PATH)
godot --headless -s tests/run_all.gd
```

CI runs this automatically on every push via `.github/workflows/`.

---

## Development Workflow Summary

```bash
# After pulling latest changes:
python3 tools/yaml_to_json.py     # rebuild data if YAML changed
python3 tools/validate_schemas.py # sanity check

# After editing YAML game data:
python3 tools/yaml_to_json.py
python3 tools/validate_schemas.py

# Before opening a PR:
python3 tools/validate_schemas.py  # must pass
# CI will run tests automatically
```
