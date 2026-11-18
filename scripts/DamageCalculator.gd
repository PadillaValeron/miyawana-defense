class_name DamageCalculator
extends RefCounted

## Full Monster Hunter-inspired Damage Formula
static func calculate_hunter_attack(hunter: Hunter, target: Node2D, skill_multiplier: float = 1.0) -> Dictionary:
	var hunter_atk: float = hunter.data.base_attack if (hunter and hunter.data) else 10.0
	var weapon: WeaponData = hunter.equipped_weapon if hunter else null
	
	var weapon_atk: float = 0.0
	var sharpness_mult: float = 1.0
	var phys_res: float = 1.0
	var elem_res: float = 1.0
	var elem_power: float = 0.0
	var elem_label: String = ""
	var affinity: float = 0.0
	
	# 1. Read Weapon Stats if equipped
	if weapon:
		weapon_atk = weapon.attack_power
		sharpness_mult = weapon.get_sharpness_multiplier()
		affinity = weapon.affinity
		elem_power = weapon.element_power
		elem_label = weapon.get_element_label()
		
		# Read Monster Resistances if target is a Monster
		if target is Monster and target.data:
			phys_res = target.data.get_physical_resistance(weapon.damage_type)
			if weapon.element_type != WeaponData.ElementType.NONE:
				elem_res = target.data.get_elemental_resistance(weapon.element_type)
				
	# 2. Affinity Roll (Positive = 1.25x Crit, Negative = 0.75x Feeble Hit)
	var crit_mult: float = 1.0
	var is_crit: bool = false
	var is_feeble: bool = false
	
	if affinity > 0.0 and randf() * 100.0 <= affinity:
		crit_mult = 1.25
		is_crit = true
	elif affinity < 0.0 and randf() * 100.0 <= abs(affinity):
		crit_mult = 0.75
		is_feeble = true
		
	# 3. Calculate Final Physical & Elemental Damage
	var raw_physical: float = (hunter_atk + weapon_atk) * sharpness_mult * phys_res * crit_mult * skill_multiplier
	var raw_elemental: float = elem_power * elem_res * skill_multiplier
	
	var final_physical: int = max(1, roundi(raw_physical))
	var final_elemental: int = roundi(raw_elemental) if elem_power > 0.0 else 0
	
	# 4. Determine Effectiveness Color Tag
	var effectiveness: String = "normal"
	if phys_res >= 1.2:
		effectiveness = "weak"   # Bright Yellow
	elif phys_res <= 0.7:
		effectiveness = "resist" # Muted Grey
		
	return {
		"physical": final_physical,
		"elemental": final_elemental,
		"element_type": elem_label,
		"total": float(final_physical + final_elemental),
		"effectiveness": effectiveness,
		"is_crit": is_crit,
		"is_feeble": is_feeble
	}
