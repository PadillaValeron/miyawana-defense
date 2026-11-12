class_name ActiveSkillData
extends Resource

@export_group("Identity")
@export var skill_name: String = "Special Move"
@export_multiline var description: String = "Description of the skill."
@export var icon: Texture2D # For the bottom-right HUD button

@export_group("Stats & Timing")
@export var cooldown: float = 8.0 # Cooldown in seconds
@export var base_damage_multiplier: float = 2.5 # Deals 250% base damage

## Virtual method: must be implemented by specific skill scripts
func execute(_hunter: Hunter) -> void:
	pass
