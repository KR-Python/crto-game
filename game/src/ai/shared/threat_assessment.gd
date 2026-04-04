class_name ThreatAssessment
## Shared threat assessment utilities for opponent and partner AIs.

static func estimate_army_strength(units: Array) -> float:
	var total: float = 0.0
	for unit in units:
		var health: float = unit.get("health", 100.0)
		var dps: float = unit.get("dps", 10.0)
		var type_mult: float = _type_multiplier(unit.get("type", "infantry"))
		total += health * dps * type_mult * 0.01
	return total


static func _type_multiplier(unit_type: String) -> float:
	match unit_type:
		"infantry": return 1.0
		"vehicle": return 1.5
		"air": return 1.8
		"hero": return 3.0
		_: return 1.0


static func analyze_composition(units: Array) -> Dictionary:
	var result := {
		"anti_infantry": 0.0, "anti_vehicle": 0.0,
		"anti_air": 0.0, "anti_structure": 0.0,
	}
	for unit in units:
		match unit.get("type", "infantry"):
			"infantry": result["anti_infantry"] += 1.0
			"vehicle":
				result["anti_vehicle"] += 1.0
				result["anti_structure"] += 0.5
			"air":
				result["anti_infantry"] += 0.5
				result["anti_structure"] += 1.0
			_: result["anti_infantry"] += 0.5
	return result
