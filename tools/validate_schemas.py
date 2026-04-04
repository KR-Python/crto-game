#!/usr/bin/env python3
"""
validate_schemas.py — CRTO YAML data file validator
Full implementation with cross-reference checks and schema validation.
"""

import sys
import glob
import os
import argparse
from collections import defaultdict

try:
    import yaml
except ImportError:
    print("✗ ERROR: PyYAML not installed. Run: pip install pyyaml")
    sys.exit(1)

# ── Constants ──────────────────────────────────────────────────────────────────

UNIT_REQUIRED = ["unit_id", "display_name", "faction", "category", "tier",
                 "role_tag", "cost", "health", "movement", "vision", "weapons"]
UNIT_CATEGORIES = {"infantry", "vehicle", "air", "naval", "structure"}
UNIT_TIERS = {1, 2, 3}
UNIT_ROLE_TAGS = {"combat", "spec_ops", "hero", "harvester", "engineer", "air"}
ARMOR_TYPES = {"light", "medium", "heavy", "building"}
MOVEMENT_TYPES = {"foot", "wheeled", "tracked", "hover", "flying"}
DAMAGE_TYPES = {"kinetic", "explosive", "energy", "chemical", "fire"}

STRUCT_REQUIRED = ["structure_id", "display_name", "faction", "tier",
                   "role_tag", "cost", "health", "footprint", "placement_rules", "power"]
STRUCT_ROLE_TAGS = {"production", "defense", "tech", "economy", "special"}

AI_REQUIRED = ["personality_id", "faction_affinity", "difficulty", "strategy_weights"]
AI_DIFFICULTIES = {"easy", "medium", "hard"}

TECH_REQUIRED = ["faction", "tiers"]

DAMAGE_TYPE_LIST = ["kinetic", "explosive", "energy", "chemical", "fire"]
ARMOR_TYPE_LIST = ["light", "medium", "heavy", "building"]

# ── Helpers ────────────────────────────────────────────────────────────────────

def err(errors, filename, msg, fix=None):
    entry = {"file": filename, "msg": msg, "fix": fix}
    errors.append(entry)


def get_nested(data, *keys):
    """Safely get nested dict value."""
    for k in keys:
        if not isinstance(data, dict):
            return None
        data = data.get(k)
    return data


def load_yaml(path):
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def collect_structure_ids(data_dir):
    ids = set()
    pattern = os.path.join(data_dir, "structures", "*.yaml")
    for p in glob.glob(pattern):
        try:
            d = load_yaml(p)
            if isinstance(d, dict) and "structure_id" in d:
                ids.add(d["structure_id"])
        except Exception:
            pass
    return ids


def collect_unit_ids(data_dir):
    ids = set()
    pattern = os.path.join(data_dir, "units", "*.yaml")
    for p in glob.glob(pattern):
        try:
            d = load_yaml(p)
            if isinstance(d, dict) and "unit_id" in d:
                ids.add(d["unit_id"])
        except Exception:
            pass
    return ids

# ── Validators ─────────────────────────────────────────────────────────────────

def validate_unit(filename, data, errors, known_structure_ids, fix_hints=False):
    name = os.path.basename(filename)
    local_errors = []

    def e(msg, fix=None):
        local_errors.append({"file": name, "msg": msg, "fix": fix})

    for field in UNIT_REQUIRED:
        if field not in data:
            e(f"missing required field: {field}",
              fix=f"Add '{field}:' to {name}" if fix_hints else None)

    cat = data.get("category")
    if cat and cat not in UNIT_CATEGORIES:
        e(f"invalid category '{cat}'",
          fix=f"category must be one of: {', '.join(sorted(UNIT_CATEGORIES))}" if fix_hints else None)

    tier = data.get("tier")
    if tier is not None and tier not in UNIT_TIERS:
        e(f"invalid tier '{tier}'",
          fix=f"tier must be 1, 2, or 3" if fix_hints else None)

    role = data.get("role_tag")
    if role and role not in UNIT_ROLE_TAGS:
        e(f"invalid role_tag '{role}'",
          fix=f"role_tag must be one of: {', '.join(sorted(UNIT_ROLE_TAGS))}" if fix_hints else None)

    armor = get_nested(data, "health", "armor_type")
    if armor and armor not in ARMOR_TYPES:
        e(f"invalid health.armor_type '{armor}'",
          fix=f"armor_type must be one of: {', '.join(sorted(ARMOR_TYPES))}" if fix_hints else None)

    max_hp = get_nested(data, "health", "max")
    if max_hp is not None and max_hp <= 0:
        e("health.max must be > 0")

    move_type = get_nested(data, "movement", "type")
    if move_type and move_type not in MOVEMENT_TYPES:
        e(f"invalid movement.type '{move_type}'",
          fix=f"movement.type must be one of: {', '.join(sorted(MOVEMENT_TYPES))}" if fix_hints else None)

    cost = data.get("cost", {})
    if isinstance(cost, dict):
        if cost.get("primary", 0) < 0:
            e("cost.primary must be >= 0")
        if cost.get("secondary", 0) < 0:
            e("cost.secondary must be >= 0")

    weapons = data.get("weapons", [])
    if isinstance(weapons, list):
        for i, w in enumerate(weapons):
            if not isinstance(w, dict):
                continue
            dt = w.get("damage_type")
            if dt and dt not in DAMAGE_TYPES:
                e(f"weapon[{i}] invalid damage_type '{dt}'",
                  fix=f"damage_type must be one of: {', '.join(sorted(DAMAGE_TYPES))}" if fix_hints else None)

    produced_at = data.get("produced_at")
    if produced_at and known_structure_ids and produced_at not in known_structure_ids:
        e(f"produced_at '{produced_at}' references unknown structure_id",
          fix=f"Add a structure with structure_id: {produced_at}" if fix_hints else None)

    errors.extend(local_errors)
    return len(local_errors) == 0


def validate_structure(filename, data, errors, fix_hints=False):
    name = os.path.basename(filename)
    local_errors = []

    def e(msg, fix=None):
        local_errors.append({"file": name, "msg": msg, "fix": fix})

    for field in STRUCT_REQUIRED:
        if field not in data:
            e(f"missing required field: {field}",
              fix=f"Add '{field}:' to {name}" if fix_hints else None)

    role = data.get("role_tag")
    if role and role not in STRUCT_ROLE_TAGS:
        e(f"invalid role_tag '{role}'",
          fix=f"role_tag must be one of: {', '.join(sorted(STRUCT_ROLE_TAGS))}" if fix_hints else None)

    armor = get_nested(data, "health", "armor_type")
    if armor and armor != "building":
        e(f"health.armor_type must be 'building' for structures, got '{armor}'")

    power = data.get("power", {})
    if isinstance(power, dict):
        if power.get("consumption", 0) < 0:
            e("power.consumption must be >= 0")
        if power.get("production", 0) < 0:
            e("power.production must be >= 0")

    footprint = data.get("footprint", {})
    if isinstance(footprint, dict):
        if footprint.get("width", 1) <= 0:
            e("footprint.width must be > 0")
        if footprint.get("height", 1) <= 0:
            e("footprint.height must be > 0")

    errors.extend(local_errors)
    return len(local_errors) == 0


def validate_tech_tree(filename, data, errors, known_unit_ids, known_structure_ids, fix_hints=False):
    name = os.path.basename(filename)
    local_errors = []

    def e(msg, fix=None):
        local_errors.append({"file": name, "msg": msg, "fix": fix})

    for field in TECH_REQUIRED:
        if field not in data:
            e(f"missing required field: {field}")

    tiers = data.get("tiers", {})
    if not isinstance(tiers, dict):
        e("'tiers' must be a mapping")
        errors.extend(local_errors)
        return False

    # Collect all ids referenced
    for tier_name, tier_data in tiers.items():
        if not isinstance(tier_data, dict):
            continue
        for uid in tier_data.get("units", []):
            if known_unit_ids and uid not in known_unit_ids:
                e(f"{tier_name}: references unknown unit_id '{uid}'",
                  fix=f"Create game/data/units/*.yaml with unit_id: {uid}" if fix_hints else None)
        for sid in tier_data.get("structures", []):
            if known_structure_ids and sid not in known_structure_ids:
                e(f"{tier_name}: references unknown structure_id '{sid}'",
                  fix=f"Create game/data/structures/*.yaml with structure_id: {sid}" if fix_hints else None)

    # Acyclic check on unlock_requirements
    graph = {}
    for tier_name, tier_data in tiers.items():
        if not isinstance(tier_data, dict):
            continue
        reqs = tier_data.get("unlock_requirements", {})
        deps = set()
        if isinstance(reqs, dict):
            for dep in reqs.get("structures", []):
                deps.add(dep)
            for dep in reqs.get("units", []):
                deps.add(dep)
        graph[tier_name] = deps

    # Simple cycle detection via DFS
    visited = set()
    rec_stack = set()

    def has_cycle(node):
        visited.add(node)
        rec_stack.add(node)
        for dep in graph.get(node, []):
            if dep not in visited:
                if has_cycle(dep):
                    return True
            elif dep in rec_stack:
                return True
        rec_stack.discard(node)
        return False

    for node in list(graph.keys()):
        if node not in visited:
            if has_cycle(node):
                e("circular dependency detected in unlock_requirements")
                break

    errors.extend(local_errors)
    return len(local_errors) == 0


def validate_ai_personality(filename, data, errors, fix_hints=False):
    name = os.path.basename(filename)
    local_errors = []

    def e(msg, fix=None):
        local_errors.append({"file": name, "msg": msg, "fix": fix})

    for field in AI_REQUIRED:
        if field not in data:
            e(f"missing required field: {field}")

    difficulty = data.get("difficulty")
    if difficulty and difficulty not in AI_DIFFICULTIES:
        e(f"invalid difficulty '{difficulty}'",
          fix=f"difficulty must be one of: {', '.join(sorted(AI_DIFFICULTIES))}" if fix_hints else None)

    weights = data.get("strategy_weights", {})
    if isinstance(weights, dict):
        for k, v in weights.items():
            if not isinstance(v, (int, float)) or not (0.0 <= v <= 3.0):
                e(f"strategy_weights.{k} = {v} must be between 0.0 and 3.0")

    errors.extend(local_errors)
    return len(local_errors) == 0


def validate_damage_matrix(filename, data, errors, fix_hints=False):
    name = os.path.basename(filename)
    local_errors = []

    def e(msg, fix=None):
        local_errors.append({"file": name, "msg": msg, "fix": fix})

    matrix = data.get("matrix", {})
    if not isinstance(matrix, dict):
        e("'matrix' key missing or not a mapping")
        errors.extend(local_errors)
        return False

    for dt in DAMAGE_TYPE_LIST:
        if dt not in matrix:
            e(f"missing damage type: {dt}")
        else:
            row = matrix[dt]
            if not isinstance(row, dict):
                e(f"matrix.{dt} must be a mapping")
                continue
            for at in ARMOR_TYPE_LIST:
                if at not in row:
                    e(f"matrix.{dt}.{at} missing")
                elif not isinstance(row[at], (int, float)) or row[at] <= 0:
                    e(f"matrix.{dt}.{at} = {row[at]} must be > 0")

    errors.extend(local_errors)
    return len(local_errors) == 0

# ── Main ────────────────────────────────────────────────────────────────────────

def print_section(title, file_results, show_fix_hints):
    """Print a section with file-level pass/fail."""
    if not file_results:
        return
    print(f"\n{title} ({len(file_results)} file{'s' if len(file_results) != 1 else ''}):")
    for fname, ok, errs in file_results:
        if ok:
            print(f"  ✓ {fname}")
        else:
            for err_entry in errs:
                print(f"  ✗ {fname} — {err_entry['msg']}")
                if show_fix_hints and err_entry.get("fix"):
                    print(f"      → Fix: {err_entry['fix']}")


def main():
    parser = argparse.ArgumentParser(description="CRTO YAML data file validator")
    parser.add_argument("--units", action="store_true", help="Validate only unit definitions")
    parser.add_argument("--structures", action="store_true", help="Validate only structure definitions")
    parser.add_argument("--tech-trees", action="store_true", help="Validate only tech trees")
    parser.add_argument("--ai", action="store_true", help="Validate only AI personalities")
    parser.add_argument("--matrix", action="store_true", help="Validate only damage/armor matrix")
    parser.add_argument("--fix-hints", action="store_true", help="Show suggested fixes for errors")
    args = parser.parse_args()

    # If no filter flags, validate everything
    all_mode = not any([args.units, args.structures, args.tech_trees, args.ai, args.matrix])

    data_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "data")
    data_dir = os.path.normpath(data_dir)

    print("Validating CRTO game data...")

    # Pre-collect known IDs for cross-reference
    known_structure_ids = collect_structure_ids(data_dir)
    known_unit_ids = collect_unit_ids(data_dir)

    total_valid = 0
    total_errors = 0

    # ── Units ──
    unit_results = []
    if all_mode or args.units:
        unit_files = sorted(glob.glob(os.path.join(data_dir, "units", "*.yaml")))
        for path in unit_files:
            fname = os.path.basename(path)
            file_errors = []
            try:
                data = load_yaml(path)
                ok = validate_unit(path, data, file_errors, known_structure_ids, args.fix_hints)
            except yaml.YAMLError as ex:
                ok = False
                file_errors.append({"file": fname, "msg": f"YAML parse error: {ex}", "fix": None})
            except Exception as ex:
                ok = False
                file_errors.append({"file": fname, "msg": str(ex), "fix": None})
            unit_results.append((fname, ok and len(file_errors) == 0, file_errors))
            if ok and len(file_errors) == 0:
                total_valid += 1
            else:
                total_errors += 1
        print_section("Units", unit_results, args.fix_hints)

    # ── Structures ──
    struct_results = []
    if all_mode or args.structures:
        struct_files = sorted(glob.glob(os.path.join(data_dir, "structures", "*.yaml")))
        for path in struct_files:
            fname = os.path.basename(path)
            file_errors = []
            try:
                data = load_yaml(path)
                ok = validate_structure(path, data, file_errors, args.fix_hints)
            except yaml.YAMLError as ex:
                ok = False
                file_errors.append({"file": fname, "msg": f"YAML parse error: {ex}", "fix": None})
            except Exception as ex:
                ok = False
                file_errors.append({"file": fname, "msg": str(ex), "fix": None})
            struct_results.append((fname, ok and len(file_errors) == 0, file_errors))
            if ok and len(file_errors) == 0:
                total_valid += 1
            else:
                total_errors += 1
        print_section("Structures", struct_results, args.fix_hints)

    # ── Tech Trees ──
    tech_results = []
    if all_mode or args.tech_trees:
        tech_files = sorted(glob.glob(os.path.join(data_dir, "tech_trees", "*.yaml")))
        for path in tech_files:
            fname = os.path.basename(path)
            file_errors = []
            try:
                data = load_yaml(path)
                ok = validate_tech_tree(path, data, file_errors, known_unit_ids, known_structure_ids, args.fix_hints)
            except yaml.YAMLError as ex:
                ok = False
                file_errors.append({"file": fname, "msg": f"YAML parse error: {ex}", "fix": None})
            except Exception as ex:
                ok = False
                file_errors.append({"file": fname, "msg": str(ex), "fix": None})
            tech_results.append((fname, ok and len(file_errors) == 0, file_errors))
            if ok and len(file_errors) == 0:
                total_valid += 1
            else:
                total_errors += 1
        print_section("Tech Trees", tech_results, args.fix_hints)

    # ── AI Personalities ──
    ai_results = []
    if all_mode or args.ai:
        ai_files = sorted(glob.glob(os.path.join(data_dir, "ai_personalities", "*.yaml")))
        for path in ai_files:
            fname = os.path.basename(path)
            file_errors = []
            try:
                data = load_yaml(path)
                ok = validate_ai_personality(path, data, file_errors, args.fix_hints)
            except yaml.YAMLError as ex:
                ok = False
                file_errors.append({"file": fname, "msg": f"YAML parse error: {ex}", "fix": None})
            except Exception as ex:
                ok = False
                file_errors.append({"file": fname, "msg": str(ex), "fix": None})
            ai_results.append((fname, ok and len(file_errors) == 0, file_errors))
            if ok and len(file_errors) == 0:
                total_valid += 1
            else:
                total_errors += 1
        if ai_files:
            print_section("AI Personalities", ai_results, args.fix_hints)

    # ── Damage/Armor Matrix ──
    matrix_results = []
    if all_mode or args.matrix:
        matrix_path = os.path.join(data_dir, "balance", "damage_armor_matrix.yaml")
        if os.path.exists(matrix_path):
            fname = os.path.basename(matrix_path)
            file_errors = []
            try:
                data = load_yaml(matrix_path)
                ok = validate_damage_matrix(matrix_path, data, file_errors, args.fix_hints)
            except yaml.YAMLError as ex:
                ok = False
                file_errors.append({"file": fname, "msg": f"YAML parse error: {ex}", "fix": None})
            except Exception as ex:
                ok = False
                file_errors.append({"file": fname, "msg": str(ex), "fix": None})
            matrix_results.append((fname, ok and len(file_errors) == 0, file_errors))
            if ok and len(file_errors) == 0:
                total_valid += 1
            else:
                total_errors += 1
            print_section("Damage/Armor Matrix", matrix_results, args.fix_hints)

    # ── Summary ──
    print(f"\nSummary: {total_valid} valid, {total_errors} error{'s' if total_errors != 1 else ''}")
    if total_errors > 0:
        print(f"Exit code: 1 (errors found)")
        sys.exit(1)
    else:
        print(f"Exit code: 0 (all valid)")
        sys.exit(0)


if __name__ == "__main__":
    main()
