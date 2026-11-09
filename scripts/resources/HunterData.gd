class_name HunterData
extends Resource

@export_group("Identity & Lore")
@export var id: String = "Generic_hunter"
@export var hunter_name: String = "Generic hunter"
@export_multiline var lore_description: String = "A fierce hunter forged in the volcanic peaks, relentless in battle."

@export_group("Base Stats")
@export var max_health: float = 120.0
@export var base_attack: float = 30.0
@export var move_speed: float = 100.0
## Health points recovered per second while fainted on the ground
@export var revive_regen_rate: float = 10.0 

@export_group("Visuals & Faces")
@export var texture_idle: Texture2D
@export var texture_hit: Texture2D
@export var texture_dead: Texture2D
## Optional: Assign only if this character has an asymmetric design (scars, eyepatch...)
@export var texture_idle_left: Texture2D 
## Dictionary for extra expressions (e.g. "enraged": texture_flame_eyes.png)
@export var special_faces: Dictionary = {}

@export_group("Abilities & Traits")
@export var active_skill: Resource # Will hold ActiveSkillData
@export var traits: Array[Resource] = [] # Will hold Array[TraitData]
