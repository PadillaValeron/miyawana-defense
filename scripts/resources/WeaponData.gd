class_name WeaponData
extends Resource

enum WeaponCategory { GREATSWORD, DUAL_BLADES, HAMMER, LANCE, BOW }
enum DamageType { SLASH, BLUNT, PIERCE }
enum ElementType { NONE, FIRE, WATER, THUNDER, ICE, DRAGON }
enum Sharpness { RED, ORANGE, YELLOW, GREEN, BLUE, WHITE, PURPLE }

@export_group("Identity & Forge")
@export var id: String = "weapon_iron_gs"
@export var weapon_name: String = "Iron Greatsword"
@export var icon: Texture2D
@export var category: WeaponCategory = WeaponCategory.GREATSWORD
@export var is_ranged: bool = false
## Scene to spawn when attacking if is_ranged is true (e.g. ArrowProjectile.tscn)
@export var projectile_scene: PackedScene

@export_group("Combat Stats")
@export var damage_type: DamageType = DamageType.SLASH
@export var attack_power: float = 80.0
@export var defense_bonus: float = 10.0
@export_range(-100.0, 100.0) var affinity: float = 0.0
@export var sharpness: Sharpness = Sharpness.GREEN

@export_group("Elemental Power")
@export var element_type: ElementType = ElementType.NONE
@export var element_power: float = 0.0

@export_group("Forge Recipe (Future)")
@export var craft_cost_zenny: int = 200
@export var craft_materials: Dictionary = {}

func get_sharpness_multiplier() -> float:
	match sharpness:
		Sharpness.RED:    return 0.50
		Sharpness.ORANGE: return 0.75
		Sharpness.YELLOW: return 1.00
		Sharpness.GREEN:  return 1.10
		Sharpness.BLUE:   return 1.20
		Sharpness.WHITE:  return 1.32
		Sharpness.PURPLE: return 1.39
	return 1.0

func get_element_label() -> String:
	match element_type:
		WeaponData.ElementType.FIRE:    return "FIRE"
		WeaponData.ElementType.WATER:   return "WATER"
		WeaponData.ElementType.THUNDER: return "THUNDER"
		WeaponData.ElementType.ICE:     return "ICE"
		WeaponData.ElementType.DRAGON:  return "DRAGON"
	return ""
