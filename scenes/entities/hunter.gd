class_name Hunter
extends Node2D

# Tried calling the face Expression but gave errors
# Renamed to FaceState to avoid shadowing Godot's built-in Expression class
enum FaceState { IDLE, HIT, DEAD }

@export var data: HunterData

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/CharacterSprite

var is_dead: bool = false
var is_acting: bool = false

func _ready() -> void:
	# Set initial texture and start walking animation
	set_face(FaceState.IDLE)
	start_walking_animation()

func _physics_process(delta: float) -> void:
	if not is_dead and not is_acting:
		# Move forward to the right
		position.x += data.move_speed * delta

# Helper to swap faces instantly
func set_face(state: FaceState) -> void:
	if not data:
		return
		
	match state:
		FaceState.IDLE:
			sprite.texture = data.texture_idle
		FaceState.HIT:
			sprite.texture = data.texture_hit
		FaceState.DEAD:
			sprite.texture = data.texture_dead

# Walking: Gentle sway from feet (rotation) + slight bounce
func start_walking_animation() -> void:
	var tween: Tween = create_tween().set_loops()
	
	# Rotate slightly left and right (pivoting on feet)
	tween.tween_property(visual_root, "rotation_degrees", 3.0, 0.25).set_trans(Tween.TRANS_SINE)
	tween.tween_property(visual_root, "rotation_degrees", -3.0, 0.25).set_trans(Tween.TRANS_SINE)
	
	# Slight vertical bounce (Squash towards the floor)
	tween.parallel().tween_property(visual_root, "scale", Vector2(1.04, 0.96), 0.25)
	tween.parallel().tween_property(visual_root, "scale", Vector2(1.0, 1.0), 0.25)

# Call this function when the hunter receives damage. we use _ in front of it so godot knows it's not used yet and doesn't give a warning
func take_damage(_amount: float) -> void:
	if is_dead:
		return
		
	# 1. Change face to hurt
	set_face(FaceState.HIT)
	
	# 2. Procedural hit reaction (recoil + stretch)
	var tween: Tween = create_tween()
	# Hit flash effect (turn white briefly)
	sprite.modulate = Color(3.0, 3.0, 3.0) # Overbright white flash
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.15)
	
	# Physical flinch (stretches up and leans back slightly)
	tween.parallel().tween_property(visual_root, "scale", Vector2(0.9, 1.15), 0.1)
	tween.parallel().tween_property(visual_root, "rotation_degrees", -8.0, 0.1)
	
	# Return to normal stance
	tween.tween_property(visual_root, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_property(visual_root, "rotation_degrees", 0.0, 0.1)
	
	await tween.finished
	
	# 3. If still alive, restore normal face
	if not is_dead:
		set_face(FaceState.IDLE)

# Call this function when health reaches 0
func die() -> void:
	is_dead = true
	set_face(FaceState.DEAD)
	
	# Fall backwards onto the ground (rotates -90 degrees from feet)
	var tween: Tween = create_tween()
	tween.tween_property(visual_root, "rotation_degrees", -90.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# Fade out after a delay
	tween.tween_interval(0.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	queue_free()
	
	
#--------------------------------------------------------------------------------------------------------------------------------------------------------------
	# hit with knockback
func take_heavy_hit(knockback_distance: float = 80.0) -> void:
	if is_dead:
		return
		
	is_acting = true
	set_face(FaceState.HIT)
	
	var tween: Tween = create_tween()
	
	# white flash
	sprite.modulate = Color(3.5, 3.5, 3.5)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.15)
	
	# leans back even more (-15 degree) and stretches
	tween.parallel().tween_property(visual_root, "scale", Vector2(0.85, 1.2), 0.1)
	tween.parallel().tween_property(visual_root, "rotation_degrees", -15.0, 0.1)
	
	# knockback: slides back and stops smoothly
	tween.parallel().tween_property(self, "position:x", position.x - knockback_distance, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# goes back to normal posture
	tween.tween_property(visual_root, "scale", Vector2(1.0, 1.0), 0.15)
	tween.parallel().tween_property(visual_root, "rotation_degrees", 0.0, 0.15)
	
	await tween.finished
	
	# goes back to normal and keeps walking
	if not is_dead:
		set_face(FaceState.IDLE)
		is_acting = false
#--------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	# Quick test inputs (press Space to hit, press K to die, press b for strong hit)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_SPACE:
			take_damage(20.0)
		elif event.keycode == KEY_B:
			take_heavy_hit(90.0) # ¡Guarrapazo con retroceso!
		elif event.keycode == KEY_K:
			die()
