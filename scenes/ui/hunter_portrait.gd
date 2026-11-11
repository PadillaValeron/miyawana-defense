class_name HunterPortrait
extends Control

## The hunter instance this portrait is mirroring in real-time
@export var target_hunter: Hunter

@onready var mini_sprite: Sprite2D = $CircleBase/MiniSprite
@onready var health_bar: ProgressBar = $HealthBar

# Base scale of the miniature sprite inside the circle
var base_mini_scale: Vector2 = Vector2(0.14, 0.14)

func _ready() -> void:
	if target_hunter and target_hunter.data:
		health_bar.max_value = target_hunter.data.max_health
		health_bar.value = target_hunter.current_health
		mini_sprite.texture = target_hunter.data.texture_idle

func _process(_delta: float) -> void:
	if not is_instance_valid(target_hunter):
		return
		
	# 1. MIRROR VISUAL PROPERTIES IN REAL TIME:
	# Copy current facial expression / texture
	mini_sprite.texture = target_hunter.sprite.texture
	
	# Copy hit flashes / color modulates
	mini_sprite.modulate = target_hunter.sprite.modulate
	
	# Copy procedural leaning & hit rotation
	mini_sprite.rotation_degrees = target_hunter.visual_root.rotation_degrees
	
	# Copy squash & stretch scale (multiplied by our mini scale factor)
	# We use abs() on scale.x so the portrait always looks forward cleanly in the HUD
	var squash_factor_x: float = abs(target_hunter.visual_root.scale.x)
	var squash_factor_y: float = target_hunter.visual_root.scale.y
	mini_sprite.scale = Vector2(base_mini_scale.x * squash_factor_x, base_mini_scale.y * squash_factor_y)
	
	# 2. UPDATE HEALTH BAR:
	health_bar.value = target_hunter.current_health
