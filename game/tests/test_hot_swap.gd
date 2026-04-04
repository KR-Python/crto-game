## test_hot_swap.gd
## Unit tests for RoleHotSwap and LatencySimulator.
##
## Run with GUT (Godot Unit Testing) or any compatible GDScript test runner.
## Each test is self-contained and creates its own mock objects.
##
## Tests:
##   1. AI takes role when player disconnects
##   2. Human takes AI role: role mapping updated, AI stopped
##   3. Graceful handoff: warning emitted before transfer
##   4. Latency simulator: command delivered after simulated delay
##   5. Packet loss: commands dropped at the expected statistical rate
extends GutTest


# ─────────────────────────────────────────────────────────────────────────────
# Helpers / Mocks
# ─────────────────────────────────────────────────────────────────────────────

## Minimal mock that satisfies the SessionManager API surface used by RoleHotSwap.
class MockSessionManager:
	## role → player_id  (-1 = AI)
	var role_assignments: Dictionary = {
		"commander":     -1,
		"quartermaster": -1,
		"field_marshal": -1,
		"spec_ops":      -1,
	}
	## player_id → role
	var player_roles: Dictionary = {}
	## role → AIPartner (mock)
	var ai_partners: Dictionary = {}
	## connected player ids
	var connected: Dictionary = {}

	var ai_partner_cleared := false
	var last_assigned_role := ""
	var last_assigned_player := -2
	var ai_partner_added := false

	var ecs_world = null

	func is_ai_role(role: String) -> bool:
		return role_assignments.get(role, -1) == -1

	func is_connected_player(player_id: int) -> bool:
		return connected.has(player_id)

	func player_has_role(player_id: int) -> bool:
		return player_roles.has(player_id)

	func clear_ai_partner(role: String) -> void:
		ai_partners.erase(role)
		ai_partner_cleared = true

	func assign_role(player_id: int, role: String) -> void:
		player_roles[player_id] = role
		role_assignments[role] = player_id
		last_assigned_role = role
		last_assigned_player = player_id

	func mark_role_ai(role: String) -> void:
		var prev: int = role_assignments.get(role, -1)
		if prev != -1:
			player_roles.erase(prev)
		role_assignments[role] = -1

	func set_ai_partner(role: String, partner) -> void:
		ai_partners[role] = partner
		ai_partner_added = true

	func get_state_snapshot() -> Dictionary:
		return {
			"player_roles":     player_roles.duplicate(),
			"role_assignments": role_assignments.duplicate(),
		}

	## Mimic add_child so AIPartner.initialize() can be called
	func add_child(node: Node) -> void:
		# In unit tests we don't have a real scene tree; just call initialize if available
		if node.has_method("initialize") and ecs_world != null:
			node.initialize(ecs_world)


## Minimal AIPartner stub — no real logic needed for these tests.
class MockAIPartner extends Node:
	var role: String = ""
	var initialized := false

	func initialize(_ecs_world) -> void:
		initialized = true


# ─────────────────────────────────────────────────────────────────────────────
# Test 1 — AI takes role when player disconnects
# ─────────────────────────────────────────────────────────────────────────────
func test_ai_takes_role_on_player_disconnect() -> void:
	var session := MockSessionManager.new()
	# Human is currently commander
	session.connected[1] = true
	session.player_roles[1] = "commander"
	session.role_assignments["commander"] = 1

	var swap := RoleHotSwap.new()
	add_child(swap)

	var ai_activated_role := ""
	swap.ai_activated.connect(func(r): ai_activated_role = r)

	swap.ai_take_role("commander", session)

	assert_eq(session.role_assignments["commander"], -1,
		"Role should be marked AI-controlled after disconnect")
	assert_eq(ai_activated_role, "commander",
		"ai_activated signal should fire with the correct role")
	assert_true(session.ai_partner_added,
		"An AIPartner should have been registered in session")

	swap.queue_free()


# ─────────────────────────────────────────────────────────────────────────────
# Test 2 — Human takes AI role: mapping updated, AI stopped
# ─────────────────────────────────────────────────────────────────────────────
func test_human_takes_ai_role() -> void:
	var session := MockSessionManager.new()
	# "spec_ops" is AI-controlled
	session.role_assignments["spec_ops"] = -1
	session.ai_partners["spec_ops"] = MockAIPartner.new()
	# Player 7 is connected with no role
	session.connected[7] = true

	var swap := RoleHotSwap.new()
	add_child(swap)

	var transferred_role := ""
	var transferred_to := -1
	swap.role_transferred.connect(func(r, _from, to):
		if r == "spec_ops":
			transferred_role = r
			transferred_to = to
	)

	var ai_deactivated_role := ""
	swap.ai_deactivated.connect(func(r): ai_deactivated_role = r)

	var result := swap.human_take_role(7, "spec_ops", session)

	assert_true(result, "human_take_role should return true on success")
	assert_eq(session.role_assignments["spec_ops"], 7,
		"spec_ops should now be assigned to player 7")
	assert_eq(session.player_roles[7], "spec_ops",
		"Player 7's role entry should be spec_ops")
	assert_true(session.ai_partner_cleared,
		"AI partner for spec_ops should have been cleared")
	assert_eq(ai_deactivated_role, "spec_ops",
		"ai_deactivated signal should fire for spec_ops")

	swap.queue_free()


# ─────────────────────────────────────────────────────────────────────────────
# Test 3 — Graceful handoff: warning emitted before AI transfer
# ─────────────────────────────────────────────────────────────────────────────
func test_graceful_handoff_warns_then_transfers() -> void:
	var session := MockSessionManager.new()
	session.connected[3] = true
	session.player_roles[3] = "quartermaster"
	session.role_assignments["quartermaster"] = 3

	var swap := RoleHotSwap.new()
	add_child(swap)

	var warnings_received: Array = []
	swap.handoff_warning.connect(func(role, secs):
		warnings_received.append({"role": role, "secs": secs})
	)

	var ai_activated_role := ""
	swap.ai_activated.connect(func(r): ai_activated_role = r)

	# Run the coroutine — GUT supports awaiting signals / timers via yield
	await swap.initiate_graceful_handoff(3, session)

	assert_eq(warnings_received.size(), RoleHotSwap.GRACEFUL_HANDOFF_SECONDS,
		"Should emit one warning per second of the countdown")

	# First warning should be the full countdown value
	assert_eq(warnings_received[0]["secs"], RoleHotSwap.GRACEFUL_HANDOFF_SECONDS,
		"First warning should start at GRACEFUL_HANDOFF_SECONDS")

	# Last warning should be 1
	assert_eq(warnings_received[-1]["secs"], 1,
		"Last warning should be 1")

	assert_eq(ai_activated_role, "quartermaster",
		"AI should be activated after countdown completes")
	assert_eq(session.role_assignments["quartermaster"], -1,
		"quartermaster should be AI-controlled after handoff")

	swap.queue_free()


# ─────────────────────────────────────────────────────────────────────────────
# Test 4 — Latency simulator: command delivered after simulated delay
# ─────────────────────────────────────────────────────────────────────────────
func test_latency_simulator_delivers_after_delay() -> void:
	var sim := LatencySimulator.new()
	add_child(sim)

	const LATENCY_MS := 100

	sim.simulate(LATENCY_MS, 0, 0.0)

	var received: Array = []
	sim.command_ready.connect(func(cmd): received.append(cmd))

	var cmd := {"type": "move", "entity": 1}
	var queued_at := Time.get_ticks_msec()
	sim.queue_command(cmd)

	# Command should NOT be delivered synchronously
	assert_eq(received.size(), 0, "Command should not be delivered immediately")

	# Wait for longer than the simulated latency
	await get_tree().create_timer(float(LATENCY_MS + 50) / 1000.0).timeout

	assert_eq(received.size(), 1, "Command should be delivered after latency elapses")
	assert_eq(received[0]["type"], "move", "Delivered command payload should match")

	var elapsed := Time.get_ticks_msec() - queued_at
	assert_true(elapsed >= LATENCY_MS,
		"Elapsed time (%dms) should be >= simulated latency (%dms)" % [elapsed, LATENCY_MS])

	sim.queue_free()


# ─────────────────────────────────────────────────────────────────────────────
# Test 5 — Packet loss: commands dropped at the correct statistical rate
# ─────────────────────────────────────────────────────────────────────────────
func test_packet_loss_drops_at_expected_rate() -> void:
	var sim := LatencySimulator.new()
	add_child(sim)

	const SAMPLES := 100
	const LOSS_PCT := 0.30     # 30%
	const TOLERANCE := 0.15    # ±15% — wide enough to avoid flakiness

	sim.simulate(0, 0, LOSS_PCT)   # zero latency so flush is instant

	var received_count := 0
	sim.command_ready.connect(func(_cmd): received_count += 1)

	for i in range(SAMPLES):
		sim.queue_command({"seq": i})

	# With zero latency, commands are delivered synchronously in queue_command
	# (latency=0 means deliver_at = now, so _process fires them next frame)
	# Use flush() to deliver all pending without waiting for frames.
	sim.flush()

	var drop_rate: float = float(SAMPLES - received_count) / float(SAMPLES)
	var lower := LOSS_PCT - TOLERANCE
	var upper := LOSS_PCT + TOLERANCE

	assert_true(drop_rate >= lower and drop_rate <= upper,
		"Drop rate %.2f should be within [%.2f, %.2f] of target %.2f" % [
			drop_rate, lower, upper, LOSS_PCT])

	sim.queue_free()
