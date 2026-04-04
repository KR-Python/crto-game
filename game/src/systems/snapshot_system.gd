class_name SnapshotSystem
## Tick pipeline step 13.
## Phase 2 stub — packages state delta for network broadcast.
## Currently emits debug signal with entity count every 2 ticks.

signal snapshot_ready(tick_count: int, entity_count: int)

func tick(ecs: ECS, tick_count: int) -> void:
	# TODO Phase 2: package state delta for network broadcast
	# For now: emit signal with current entity count (for debugging)
	if tick_count % 2 == 0:  # every 2 ticks per architecture spec
		pass  # placeholder
