## test_entity_factory.gd
## Tests for EntityFactory YAML-driven creation.
## Verifies that DataLoader definitions produce entities with correct components.
##
## Run with: gdunit or from Godot's test runner (res://tests/).

extends GDScriptTestCase  # swap for your project's base test class if different


# ── Helpers ───────────────────────────────────────────────────────────────────

var _ecs: ECS
var _loader: DataLoader
var _factory: EntityFactory


func _before_each() -> void:
	_ecs = ECS.new()
	_loader = DataLoader.new()
	# Load real JSON data (yaml_to_json.py must have been run first in CI).
	# In editor, run: python tools/yaml_to_json.py from the repo root.
	_loader.load_all()
	_factory = EntityFactory.new(_ecs, _loader)


func _after_each() -> void:
	_ecs = null
	_loader = null
	_factory = null


# ── Test 1: aegis_rifleman — correct health, speed, faction ──────────────────

func test_create_aegis_rifleman() -> void:
	var entity_id: int = _factory.create_from_definition("aegis_rifleman", Vector2(3.0, 4.0))

	assert_ne(entity_id, -1, "aegis_rifleman must create a valid entity")

	# Faction
	var faction: Dictionary = _ecs.get_component(entity_id, "FactionComponent")
	assert_eq(faction.get("faction_id"), 0, "aegis_rifleman must have faction_id 0 (Aegis)")

	# Health — YAML: health.max = 120, armor_type = light
	var health: Dictionary = _ecs.get_component(entity_id, "Health")
	assert_eq(health.get("max"), 120.0, "aegis_rifleman max health must be 120")
	assert_eq(health.get("armor_type"), "light", "aegis_rifleman armor_type must be light")

	# Speed — YAML: movement.speed = 3.0
	var move: Dictionary = _ecs.get_component(entity_id, "MoveSpeed")
	assert_eq(move.get("speed"), 3.0, "aegis_rifleman speed must be 3.0")

	# Must have a weapon
	var weapon: Dictionary = _ecs.get_component(entity_id, "Weapon")
	assert_false(weapon.is_empty(), "aegis_rifleman must have a Weapon component")
	assert_eq(weapon.get("damage_type"), "kinetic", "aegis_rifleman weapon must be kinetic")


# ── Test 2: aegis_harvester — harvester component, no weapon ─────────────────

func test_create_aegis_harvester() -> void:
	var entity_id: int = _factory.create_from_definition("aegis_harvester", Vector2(5.0, 5.0))
	assert_ne(entity_id, -1, "aegis_harvester must create a valid entity")

	# Health — YAML: health.max = 400, armor_type = heavy
	var health: Dictionary = _ecs.get_component(entity_id, "Health")
	assert_eq(health.get("max"), 400.0, "aegis_harvester max health must be 400")
	assert_eq(health.get("armor_type"), "heavy")

	# Must NOT have a weapon (weapons: [] in YAML)
	var weapon: Dictionary = _ecs.get_component(entity_id, "Weapon")
	assert_true(weapon.is_empty(), "aegis_harvester must NOT have a Weapon component")

	# Harvester ability capacity (30 from YAML)
	# The factory stores harvest_capacity in the Tags component or a dedicated dict;
	# we verify the Tags component includes "harvester" as role_tag.
	var tags: Dictionary = _ecs.get_component(entity_id, "Tags")
	assert_true(
		"harvester" in tags.get("tags", []),
		"aegis_harvester Tags must contain 'harvester'"
	)


# ── Test 3: forge_attack_bike — correct faction, explosive weapon ─────────────

func test_create_forge_attack_bike() -> void:
	var entity_id: int = _factory.create_from_definition("forge_attack_bike", Vector2(8.0, 2.0))
	assert_ne(entity_id, -1, "forge_attack_bike must create a valid entity")

	# Faction — YAML: faction = forge → faction_id 1
	var faction: Dictionary = _ecs.get_component(entity_id, "FactionComponent")
	assert_eq(faction.get("faction_id"), 1, "forge_attack_bike must have faction_id 1 (Forge)")

	# Health — YAML: health.max = 100, armor_type = light
	var health: Dictionary = _ecs.get_component(entity_id, "Health")
	assert_eq(health.get("max"), 100.0)
	assert_eq(health.get("armor_type"), "light")

	# Weapon — YAML: damage_type = explosive
	var weapon: Dictionary = _ecs.get_component(entity_id, "Weapon")
	assert_false(weapon.is_empty(), "forge_attack_bike must have a Weapon component")
	assert_eq(weapon.get("damage_type"), "explosive", "forge_attack_bike weapon must be explosive")
	assert_eq(weapon.get("damage"), 25.0, "forge_attack_bike weapon damage must be 25")


# ── Test 4: unknown unit_type — returns -1, logs error ───────────────────────

func test_unknown_unit_type_returns_minus_one() -> void:
	# push_error is expected — suppress in test output if your runner supports it.
	var entity_id: int = _factory.create_from_definition("definitely_not_a_real_unit", Vector2.ZERO)
	assert_eq(entity_id, -1, "Unknown unit type must return -1")


# ── Test 5: create_structure aegis_barracks — footprint + power ───────────────

func test_create_aegis_barracks_structure() -> void:
	var entity_id: int = _factory.create_structure("aegis_barracks", Vector2(10.0, 10.0), 0)
	assert_ne(entity_id, -1, "aegis_barracks must create a valid entity")

	# Footprint — YAML: footprint.width = 3, footprint.height = 2
	var footprint: Dictionary = _ecs.get_component(entity_id, "Footprint")
	assert_eq(footprint.get("width"), 3, "aegis_barracks footprint width must be 3")
	assert_eq(footprint.get("height"), 2, "aegis_barracks footprint height must be 2")

	# Health — YAML: health.max = 800, armor_type = building
	var health: Dictionary = _ecs.get_component(entity_id, "Health")
	assert_eq(health.get("max"), 800.0, "aegis_barracks max health must be 800")
	assert_eq(health.get("armor_type"), "building")

	# Structure component present
	var structure: Dictionary = _ecs.get_component(entity_id, "Structure")
	assert_false(structure.is_empty(), "aegis_barracks must have a Structure component")
	assert_eq(structure.get("structure_type"), "aegis_barracks")

	# Faction
	var faction: Dictionary = _ecs.get_component(entity_id, "FactionComponent")
	assert_eq(faction.get("faction_id"), 0)

	# Power consumption deferred until build completes (build_time = 12.0 > 1.0).
	# PowerConsumer should NOT be present immediately after creation.
	var power: Dictionary = _ecs.get_component(entity_id, "PowerConsumer")
	assert_true(
		power.is_empty(),
		"aegis_barracks PowerConsumer must not be applied until construction completes"
	)
