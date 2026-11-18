class_name HunterData
extends Resource

@export_group("Identity & Lore")
@export var id: String = "hunter_rathalos"
@export var hunter_name: String = "Rathalos Hunter"
@export_multiline var lore_description: String = "A fierce hunter forged in the volcanic peaks, relentless in battle."

@export_group("Base Stats")
@export var max_health: float = 120.0
@export var base_attack: float = 20.0
@export var base_defense: float = 10.0
@export var move_speed: float = 100.0
@export var revive_regen_rate: float = 25.0

@export_group("Combat Ranges & Timing")
@export var min_attack_range: float = 0.0
@export var max_attack_range: float = 75.0
@export var attack_cooldown: float = 1.0

@export_group("Equipment")
@export var default_weapon: WeaponData # Equipped weapon (.tres)

@export_group("Visuals & Faces")
@export var icon_portrait: Texture2D
@export var texture_idle: Texture2D
@export var texture_hit: Texture2D
@export var texture_dead: Texture2D
@export var texture_idle_left: Texture2D
@export var special_faces: Dictionary = {}

@export_group("Abilities & Traits")
@export var active_skill: ActiveSkillData
@export var traits: Array[Resource] = []
