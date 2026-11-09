class_name HunterData
extends Resource

@export var hunter_name: String = "Rathalos Hunter"
@export var max_health: float = 120.0
@export var base_attack: float = 30.0
@export var move_speed: float = 100.0

@export_group("Visuals & Expressions")
@export var texture_idle: Texture2D    # Normal face
@export var texture_hit: Texture2D     # Hurt / Eyes closed
@export var texture_dead: Texture2D    # Cross eyes (X X)
