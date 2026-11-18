class_name Projectile
extends Node2D

var start_pos: Vector2 = Vector2.ZERO
var target_node: Node2D = null
var last_known_target_pos: Vector2 = Vector2.ZERO
var target_chest_offset_y: float = -120.0

var damage_info: Dictionary = {}
var knockback_force: float = 8.0
var attacker_origin_x: float = 0.0

var flight_duration: float = 0.4
var arc_height: float = 110.0
var elapsed: float = 0.0
var is_launched: bool = false

func launch(from_pos: Vector2, target: Node2D, dmg_payload: Dictionary, kb_force: float, shooter_x: float, speed: float = 950.0) -> void:
	start_pos = from_pos
	global_position = from_pos
	target_node = target
	damage_info = dmg_payload
	knockback_force = kb_force
	attacker_origin_x = shooter_x
	
	# Aim dynamically at the center/chest height of the monster
	if target is Monster and target.data and target.data.texture_idle:
		target_chest_offset_y = -target.data.texture_idle.get_height() * target.scale.y * 0.5
		
	if is_instance_valid(target):
		last_known_target_pos = target.global_position + Vector2(0.0, target_chest_offset_y)
	else:
		last_known_target_pos = from_pos + Vector2(300.0, 0.0)
		
	# Calculate realistic flight time & arc height proportional to distance
	var dist: float = start_pos.distance_to(last_known_target_pos)
	flight_duration = clampf(dist / speed, 0.20, 0.75)
	arc_height = clampf(dist * 0.25, 35.0, 190.0)
	
	is_launched = true

func _physics_process(delta: float) -> void:
	if not is_launched:
		return
		
	elapsed += delta
	var t: float = clampf(elapsed / flight_duration, 0.0, 1.0)
	
	# Keep tracking target chest cleanly if target is still alive
	if is_instance_valid(target_node) and target_node.is_in_group("monsters"):
		last_known_target_pos = target_node.global_position + Vector2(0.0, target_chest_offset_y)
		
	var prev_pos: Vector2 = global_position
	
	# PARABOLIC INTERPOLATION: Straight line lerp + smooth vertical Sine curve!
	var linear_pos: Vector2 = start_pos.lerp(last_known_target_pos, t)
	var arc_offset: float = sin(t * PI) * arc_height
	var next_pos: Vector2 = Vector2(linear_pos.x, linear_pos.y - arc_offset)
	
	global_position = next_pos
	
	# Rotate arrow naturally along its flight trajectory tangent
	var velocity_vec: Vector2 = next_pos - prev_pos
	if velocity_vec.length_squared() > 0.001:
		rotation = velocity_vec.angle()
		
	# IMPACT REACHED!
	if t >= 1.0:
		deliver_impact()

func deliver_impact() -> void:
	if is_instance_valid(target_node) and target_node.is_in_group("monsters") and target_node.has_method("receive_hit"):
		target_node.receive_hit(damage_info, knockback_force, attacker_origin_x)
	queue_free()
