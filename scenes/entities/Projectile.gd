class_name Projectile
extends Node2D

var start_pos: Vector2 = Vector2.ZERO
var target_node: Node2D = null
var last_known_target_pos: Vector2 = Vector2.ZERO
var target_chest_offset_y: float = -120.0

# Hunter -> Monster payload
var damage_info: Dictionary = {}
# Monster -> Hunter/Gate payload
var is_enemy_projectile: bool = false
var raw_enemy_damage: float = 0.0
var is_launch_hit: bool = false
var launch_height: float = 120.0

var knockback_force: float = 8.0
var attacker_origin_x: float = 0.0

var flight_duration: float = 0.4
var arc_height: float = 110.0
var elapsed: float = 0.0
var is_launched: bool = false

## Used by Hunters (passes Dictionary damage_info)
func launch(from_pos: Vector2, target: Node2D, dmg_payload: Dictionary, kb_force: float, shooter_x: float, speed: float = 950.0) -> void:
	is_enemy_projectile = false
	damage_info = dmg_payload
	init_flight(from_pos, target, kb_force, shooter_x, speed)

## Used by Monsters (passes raw damage & optional launch physics)
func launch_enemy_projectile(from_pos: Vector2, target: Node2D, raw_dmg: float, kb_force: float, launches: bool, launch_h: float, shooter_x: float, speed: float = 750.0) -> void:
	is_enemy_projectile = true
	raw_enemy_damage = raw_dmg
	is_launch_hit = launches
	launch_height = launch_h
	init_flight(from_pos, target, kb_force, shooter_x, speed)

func init_flight(from_pos: Vector2, target: Node2D, kb_force: float, shooter_x: float, speed: float) -> void:
	start_pos = from_pos
	global_position = from_pos
	target_node = target
	knockback_force = kb_force
	attacker_origin_x = shooter_x
	
	# Aim dynamically at chest height depending on target type
	if target is Monster and target.data and target.data.texture_idle:
		target_chest_offset_y = -target.data.texture_idle.get_height() * target.scale.y * 0.5
	elif target is Hunter and target.sprite and target.sprite.texture:
		target_chest_offset_y = -target.sprite.texture.get_height() * 0.5
	elif target is GuildGate:
		target_chest_offset_y = -220.0
		
	if is_instance_valid(target):
		last_known_target_pos = target.global_position + Vector2(0.0, target_chest_offset_y)
	else:
		last_known_target_pos = from_pos + Vector2(300.0, 0.0)
		
	var dist: float = start_pos.distance_to(last_known_target_pos)
	flight_duration = clampf(dist / speed, 0.20, 0.85)
	arc_height = clampf(dist * 0.24, 35.0, 200.0)
	is_launched = true

func is_target_still_valid() -> bool:
	if not is_instance_valid(target_node):
		return false
	if is_enemy_projectile:
		if target_node is Hunter:
			return target_node.current_state != Hunter.State.FAINTED
		elif target_node is GuildGate:
			return not target_node.is_destroyed
		return false
	else:
		return target_node.is_in_group("monsters")

func _physics_process(delta: float) -> void:
	if not is_launched:
		return
		
	elapsed += delta
	var t: float = clampf(elapsed / flight_duration, 0.0, 1.0)
	
	if is_target_still_valid():
		last_known_target_pos = target_node.global_position + Vector2(0.0, target_chest_offset_y)
		
	var prev_pos: Vector2 = global_position
	var linear_pos: Vector2 = start_pos.lerp(last_known_target_pos, t)
	var arc_offset: float = sin(t * PI) * arc_height
	var next_pos: Vector2 = Vector2(linear_pos.x, linear_pos.y - arc_offset)
	
	global_position = next_pos
	
	var velocity_vec: Vector2 = next_pos - prev_pos
	if velocity_vec.length_squared() > 0.001:
		rotation = velocity_vec.angle()
		
	if t >= 1.0:
		deliver_impact()

func deliver_impact() -> void:
	if is_target_still_valid() and target_node.has_method("receive_hit"):
		if is_enemy_projectile:
			if target_node is Hunter:
				target_node.receive_hit(raw_enemy_damage, knockback_force, attacker_origin_x, is_launch_hit, launch_height)
			elif target_node is GuildGate:
				target_node.receive_hit(raw_enemy_damage)
		else:
			target_node.receive_hit(damage_info, knockback_force, attacker_origin_x)
	queue_free()
