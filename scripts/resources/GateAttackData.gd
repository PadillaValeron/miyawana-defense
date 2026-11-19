class_name GateAttackData
extends Resource

@export_group("Identity & Scheduling")
@export var attack_name: String = "Apex Gate Breaker"
@export var trigger_interval: float = 15.0
@export var charge_duration: float = 2.6

@export_group("Damage & Interruption")
@export var damage_multiplier: float = 6.0
## Total damage the squad must deal during charge_duration to cancel this attack
@export var damage_threshold_to_interrupt: float = 250.0
## Guaranteed stun duration applied to the monster when interrupted
@export var interrupt_stun_duration: float = 4.0

## Virtual method implemented by specific Boss Gate Attacks
func execute(_monster: Node2D) -> void:
	pass

## Virtual method called when squad breaks the damage threshold during charge!
## Override this in custom bosses
func on_interrupted(monster: Node2D) -> void:
	if monster is Monster:
		monster.enter_stun(interrupt_stun_duration)
