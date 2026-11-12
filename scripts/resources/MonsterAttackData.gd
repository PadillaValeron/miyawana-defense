class_name MonsterAttackData
extends Resource

@export_group("Identity & Access")
@export var attack_name: String = "Monster Slam"
## If true, only Apex versions of this monster can use this attack
@export var is_apex_only: bool = false

@export_group("RNG & Timing")
@export var cooldown: float = 6.0
## Probability (0.0 to 1.0) to trigger this special instead of a basic attack when ready
@export_range(0.0, 1.0) var trigger_chance: float = 0.35

@export_group("Range & Physics")
@export var min_range: float = 0.0
@export var max_range: float = 100.0
@export var damage_multiplier: float = 1.5
@export var knockback_force: float = 60.0
@export var launches_hunter: bool = false
@export var launch_height: float = 120.0

## Virtual method: override in specific attack scripts (e.g. Fireball, GroundSlam, MassiveGateCharge)
func execute(_monster: Node2D, _target: Node2D) -> void:
	pass
