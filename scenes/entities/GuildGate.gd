class_name GuildGate
extends Node2D

signal health_changed(current_hp: float, max_hp: float)
signal gate_destroyed

@export var max_health: float = 1000.0
var current_health: float = 1000.0
var is_destroyed: bool = false

@onready var visual_root: Node2D = $VisualRoot
@onready var gate_body: ColorRect = $VisualRoot/GateBody

var hit_tween: Tween

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

## Returns the X coordinate of the front gate wall where monsters collide and hit
func get_front_wall_x() -> float:
	return global_position.x + 60.0

func receive_hit(damage: float) -> void:
	if is_destroyed:
		return
		
	current_health = max(0.0, current_health - damage)
	health_changed.emit(current_health, max_health)
	
	# Spawn red floating damage number on the gate
	var dmg_info := {
		"physical": roundi(damage),
		"elemental": 0,
		"element_type": "",
		"total": damage,
		"effectiveness": "gate_damage",
		"is_crit": false,
		"is_feeble": false
	}
	EventBus.damage_text_requested.emit(global_position + Vector2(30.0, -240.0), dmg_info)
	
	play_hit_shake()
	
	if current_health <= 0.0:
		destroy_gate()

func play_hit_shake() -> void:
	if hit_tween and hit_tween.is_valid():
		hit_tween.kill()
		
	hit_tween = create_tween().set_parallel(true)
	gate_body.modulate = Color(2.5, 2.5, 2.5) # Bright hit flash
	hit_tween.tween_property(gate_body, "modulate", Color(1.0, 1.0, 1.0), 0.14)
	
	# Heavy structural shudder
	visual_root.position.x = -8.0
	hit_tween.tween_property(visual_root, "position:x", 6.0, 0.05)
	hit_tween.chain().tween_property(visual_root, "position:x", -4.0, 0.05)
	hit_tween.chain().tween_property(visual_root, "position:x", 0.0, 0.05)

func destroy_gate() -> void:
	is_destroyed = true
	gate_body.modulate = Color(0.35, 0.25, 0.25) # Charred/broken tint
	gate_destroyed.emit()
