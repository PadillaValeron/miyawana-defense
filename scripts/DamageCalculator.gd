class_name DamageCalculator
extends RefCounted

## Middleware damage calculator (Template ready for Monster Hunter formulas!)
static func calculate_hunter_attack(hunter: Hunter, _target: Node2D, skill_multiplier: float = 1.0) -> Dictionary:
	var raw_physical: float = 0.0
	if hunter and hunter.data:
		raw_physical = hunter.data.base_attack * skill_multiplier
		
	var final_physical: int = roundi(raw_physical)
	var final_elemental: int = 0
	
	return {
		"physical": final_physical,
		"elemental": final_elemental,
		"element_type": "",
		"total": float(final_physical + final_elemental),
		"effectiveness": "normal", # Future: "weak", "normal", "resist"
		"is_crit": false
	}
