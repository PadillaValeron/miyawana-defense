class_name MonsterData
extends Resource

@export_group("Identity")
@export var id: String = "monster_dummy"
@export var monster_name: String = "Evil Dummy"
@export var icon_portrait: Texture2D # Icon for the Top-Right HUD

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

@export_group("Visuals")
@export var texture_idle: Texture2D
@export var texture_hit: Texture2D
@export var texture_stunned: Texture2D
## Check this if your drawn sprite naturally looks to the RIGHT instead of LEFT
@export var sprite_faces_right_by_default: bool = true

@export_group("Apex Modifiers")
@export var apex_scale_multiplier: float = 1.4
@export var apex_health_multiplier: float = 2.5
@export var apex_attack_multiplier: float = 1.5

@export_group("Special Moves")
@export var special_attacks: Array[MonsterAttackData] = []
