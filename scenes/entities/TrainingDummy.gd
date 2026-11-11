class_name TrainingDummy
extends Node2D

@export var max_health: float = 9999.0
@export var texture_idle: Texture2D # Smiling face
@export var texture_hit: Texture2D  # Squinting hurt face

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/DummySprite

var current_health: float = 9999.0
var is_recovering: bool = false

func _ready() -> void:
	current_health = max_health
	
	if texture_idle:
		sprite.texture = texture_idle
		
	# AUTO-PIVOT A LOS PIES:
	# Ajusta la altura dinámicamente según el tamaño de la imagen
	if sprite.texture:
		sprite.position.y -= sprite.texture.get_height() * 0.5

## Master function called when hit by hunters
func receive_hit(damage: float, knockback_force: float = 0.0, attacker_global_x: float = 0.0) -> void:
	current_health -= damage
	
	# Swap to hurt face
	if texture_hit:
		sprite.texture = texture_hit
		
	# Directional wobble (shakes away from attacker)
	var push_direction: float = 1.0 if attacker_global_x < global_position.x else -1.0
	
	var tween = create_tween()
	# White hit flash
	sprite.modulate = Color(3.0, 3.0, 3.0)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.12)
	
	# Squash on pole & lean back
	tween.parallel().tween_property(visual_root, "scale", Vector2(1.15, 0.9), 0.08)
	tween.parallel().tween_property(visual_root, "rotation_degrees", 8.0 * push_direction, 0.08)
	
	# Slight knockback slide along the floor
	if knockback_force > 0.0:
		var target_x: float = position.x + (push_direction * knockback_force)
		tween.parallel().tween_property(self, "position:x", target_x, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Elastic return to normal stance
	tween.tween_property(visual_root, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(visual_root, "rotation_degrees", 0.0, 0.15)
	
	await tween.finished
	
	# Restore smiling face
	if texture_idle:
		sprite.texture = texture_idle
