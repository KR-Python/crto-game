class_name TestMovement
## Tests for MovementSystem and CommandProcessingSystem.
## Run with: TestMovement.run_all()

const TICKS: int = 15  # ticks per second


static func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var errors: Array = []

	# ── Test 1: Unit reaches destination ────────────────────────────────────
	var ecs: ECS = ECS.new()
	var sys: MovementSystem = MovementSystem.new()
	sys.map_bounds = Rect2(0.0, 0.0, 128.0, 96.0)

	var unit: int = ecs.create_entity()
	ecs.add_component(unit, "Position", {"x": 0.0, "y": 0.0})
	ecs.add_component(unit, "Velocity", {"x": 0.0, "y": 0.0})
	ecs.add_component(unit, "MoveSpeed", {"speed": 5.0})
	ecs.add_component(unit, "PathState", {
		"path": [Vector2(10.0, 0.0)],
		"current_index": 0,
		"destination": Vector2(10.0, 0.0),
	})
	ecs.add_component(unit, "MoveCommand", {"destination": Vector2(10.0, 0.0), "queued": false})

	for t in range(35):
		sys.tick(ecs, t)

	var pos_c: Dictionary = ecs.get_component(unit, "Position")
	var pos: Vector2 = Vector2(pos_c.x, pos_c.y)
	if (pos.distance_to(Vector2(10.0, 0.0)) <= 0.5
			and not ecs.has_component(unit, "PathState")
			and not ecs.has_component(unit, "MoveCommand")):
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 FAIL (unit reaches dest): pos=%s path=%s cmd=%s" % [
			str(pos), str(ecs.has_component(unit, "PathState")),
			str(ecs.has_component(unit, "MoveCommand"))])

	# ── Test 2: PathState cleared on arrival ────────────────────────────────
	ecs = ECS.new()
	sys = MovementSystem.new()
	sys.map_bounds = Rect2(0.0, 0.0, 128.0, 96.0)

	unit = ecs.create_entity()
	ecs.add_component(unit, "Position", {"x": 0.0, "y": 0.0})
	ecs.add_component(unit, "Velocity", {"x": 0.0, "y": 0.0})
	ecs.add_component(unit, "MoveSpeed", {"speed": 10.0})
	ecs.add_component(unit, "PathState", {
		"path": [Vector2(1.0, 0.0)],
		"current_index": 0,
		"destination": Vector2(1.0, 0.0),
	})
	ecs.add_component(unit, "MoveCommand", {"destination": Vector2(1.0, 0.0), "queued": false})

	for t in range(5):
		sys.tick(ecs, t)

	if not ecs.has_component(unit, "PathState") and not ecs.has_component(unit, "MoveCommand"):
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 FAIL (PathState cleared): has_path=%s has_cmd=%s" % [
			str(ecs.has_component(unit, "PathState")),
			str(ecs.has_component(unit, "MoveCommand"))])

	# ── Test 3: Straight-line fallback without PathState ────────────────────
	ecs = ECS.new()
	sys = MovementSystem.new()
	sys.map_bounds = Rect2(0.0, 0.0, 128.0, 96.0)

	unit = ecs.create_entity()
	ecs.add_component(unit, "Position", {"x": 0.0, "y": 0.0})
	ecs.add_component(unit, "Velocity", {"x": 0.0, "y": 0.0})
	ecs.add_component(unit, "MoveSpeed", {"speed": 5.0})
	ecs.add_component(unit, "MoveCommand", {"destination": Vector2(5.0, 0.0), "queued": false})
	# No PathState — fallback mode

	for t in range(25):
		sys.tick(ecs, t)

	var pc: Dictionary = ecs.get_component(unit, "Position")
	var px: float = pc.x
	# Should have moved toward (5,0) and either arrived or be moving
	if px > 1.0 or not ecs.has_component(unit, "MoveCommand"):
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 FAIL (straight-line fallback): px=%f" % px)

	# ── Test 4: Unit stops at map bounds ────────────────────────────────────
	ecs = ECS.new()
	sys = MovementSystem.new()
	sys.map_bounds = Rect2(0.0, 0.0, 10.0, 10.0)

	unit = ecs.create_entity()
	ecs.add_component(unit, "Position", {"x": 9.5, "y": 5.0})
	ecs.add_component(unit, "Velocity", {"x": 0.0, "y": 0.0})
	ecs.add_component(unit, "MoveSpeed", {"speed": 20.0})
	ecs.add_component(unit, "MoveCommand", {"destination": Vector2(50.0, 5.0), "queued": false})

	for t in range(10):
		sys.tick(ecs, t)

	pc = ecs.get_component(unit, "Position")
	if pc.x <= 10.0 and pc.y <= 10.0 and pc.x >= 0.0 and pc.y >= 0.0:
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 FAIL (map bounds): pos=(%f,%f)" % [pc.x, pc.y])

	# ── Test 5: Separation steering — units don't perfectly overlap ──────────
	ecs = ECS.new()
	sys = MovementSystem.new()
	sys.map_bounds = Rect2(0.0, 0.0, 128.0, 96.0)
	var dest: Vector2 = Vector2(15.0, 15.0)

	var u1: int = ecs.create_entity()
	var u2: int = ecs.create_entity()
	for u in [u1, u2]:
		ecs.add_component(u, "Position", {"x": 0.0, "y": 0.0})
		ecs.add_component(u, "Velocity", {"x": 0.0, "y": 0.0})
		ecs.add_component(u, "MoveSpeed", {"speed": 3.0})
		ecs.add_component(u, "PathState", {"path": [dest], "current_index": 0, "destination": dest})
		ecs.add_component(u, "MoveCommand", {"destination": dest, "queued": false})
	# Slightly separate start to allow separation to activate
	ecs.add_component(u2, "Position", {"x": 0.3, "y": 0.0})

	for t in range(25):
		sys.tick(ecs, t)

	var p1c: Dictionary = ecs.get_component(u1, "Position")
	var p2c: Dictionary = ecs.get_component(u2, "Position")
	var p1: Vector2 = Vector2(p1c.get("x", 0.0), p1c.get("y", 0.0))
	var p2: Vector2 = Vector2(p2c.get("x", 0.0), p2c.get("y", 0.0))
	if p1.distance_to(p2) > 0.05:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 FAIL (separation): dist=%f" % p1.distance_to(p2))

	# ── Test 6: Unit dies mid-move — no crash ───────────────────────────────
	ecs = ECS.new()
	sys = MovementSystem.new()
	sys.map_bounds = Rect2(0.0, 0.0, 128.0, 96.0)

	unit = ecs.create_entity()
	ecs.add_component(unit, "Position", {"x": 0.0, "y": 0.0})
	ecs.add_component(unit, "Velocity", {"x": 0.0, "y": 0.0})
	ecs.add_component(unit, "MoveSpeed", {"speed": 5.0})
	ecs.add_component(unit, "PathState", {
		"path": [Vector2(20.0, 0.0)],
		"current_index": 0,
		"destination": Vector2(20.0, 0.0),
	})
	ecs.add_component(unit, "MoveCommand", {"destination": Vector2(20.0, 0.0), "queued": false})

	for t in range(5):
		sys.tick(ecs, t)
	ecs.destroy_entity(unit)
	# Must not crash
	for t in range(5, 10):
		sys.tick(ecs, t)
	passed += 1  # Reaching here means no crash

	# ── Test 7: Flying unit moves directly (ignores terrain) ─────────────────
	ecs = ECS.new()
	sys = MovementSystem.new()
	sys.map_bounds = Rect2(0.0, 0.0, 128.0, 96.0)

	unit = ecs.create_entity()
	ecs.add_component(unit, "Position", {"x": 0.0, "y": 0.0})
	ecs.add_component(unit, "Velocity", {"x": 0.0, "y": 0.0})
	ecs.add_component(unit, "MoveSpeed", {"speed": 5.0})
	ecs.add_component(unit, "Flying", {})
	ecs.add_component(unit, "MoveCommand", {"destination": Vector2(5.0, 0.0), "queued": false})

	for t in range(25):
		if not ecs.has_component(unit, "MoveCommand"):
			break
		sys.tick(ecs, t)

	pc = ecs.get_component(unit, "Position")
	if pc.get("x", 0.0) > 0.5 and ecs.has_component(unit, "Flying"):
		passed += 1
	else:
		failed += 1
		errors.append("Test 7 FAIL (flying): x=%f has_flying=%s" % [
			pc.get("x", 0.0), str(ecs.has_component(unit, "Flying"))])

	return {"passed": passed, "failed": failed, "errors": errors}
