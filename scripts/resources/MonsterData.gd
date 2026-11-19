class_name MonsterData
extends Resource

@export_group("Identity")
@export var id: String = "monster_dummy"
@export var monster_name: String = "Evil Dummy"
@export var icon_portrait: Texture2D

@export_group("Base Stats")
@export var max_health: float = 300.0
@export var base_attack: float = 20.0
@export var move_speed: float = 60.0
@export var attack_range: float = 85.0
@export var attack_cooldown: float = 1.8
@export var basic_knockback: float = 25.0

@export_group("Physical Resistances (Multipliers)")
@export var res_slash: float = 1.0
@export var res_blunt: float = 1.0
@export var res_pierce: float = 1.0

@export_group("Elemental Resistances (Multipliers)")
@export var res_fire: float = 1.0
@export var res_water: float = 1.0
@export var res_thunder: float = 1.0
@export var res_ice: float = 1.0
@export var res_dragon: float = 1.0

@export_group("Visuals")
@export var texture_idle: Texture2D
@export var texture_hit: Texture2D
@export var texture_stunned: Texture2D
@export var sprite_faces_right_by_default: bool = true

@export_group("Apex Modifiers & Gate Event")
@export var apex_scale_multiplier: float = 1.4
@export var apex_health_multiplier: float = 2.5
@export var apex_attack_multiplier: float = 1.5
## Scheduled Gate Attack event unlocked exclusively by Apex monsters
@export var apex_gate_attack: GateAttackData

@export_group("Combat Special Moves (RNG)")
@export var special_attacks: Array[MonsterAttackData] = []

func get_physical_resistance(dmg_type: WeaponData.DamageType) -> float:
	match dmg_type:
		WeaponData.DamageType.SLASH:  return res_slash
		WeaponData.DamageType.BLUNT:  return res_blunt
		WeaponData.DamageType.PIERCE: return res_pierce
	return 1.0

func get_elemental_resistance(elem_type: WeaponData.ElementType) -> float:
	match elem_type:
		WeaponData.ElementType.FIRE:    return res_fire
		WeaponData.ElementType.WATER:   return res_water
		WeaponData.ElementType.THUNDER: return res_thunder
		WeaponData.ElementType.ICE:     return res_ice
		WeaponData.ElementType.DRAGON:  return res_dragon
	return 1.0
