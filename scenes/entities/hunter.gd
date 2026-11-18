class_name Hunter
extends Node2D

enum State { IDLE_WALK, ATTACKING, ACTING, LAUNCHED, FAINTED }
enum FaceState { IDLE, HIT, DEAD }
enum CommandState { OFFENSIVE, RETREAT, FOCUS }

@export var data: HunterData
@export var guard_leash_range: float = 220.0

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/CharacterSprite

# Combat runtime variables
var current_health: float = 100.0
var equipped_weapon: WeaponData = null
var current_state: State = State.IDLE_WALK
var current_command: CommandState = CommandState.OFFENSIVE
var facing_direction: int = 1

# AI & Combat Targeting
var current_target: Node2D = null
var focus_target: Node2D = null
var attack_timer: float = 0.0
var skill_cooldown_timer: float = 0.0
var has_reached_gate: bool = false

const GATE_X_POSITION: float = 120.0
const MIN_ARENA_X: float = 70.0 # Prevents backpedaling archers from clipping past the left Gate wall!

var range_variance: float = 0.0
var gate_x_offset: float = 0.0
var walk_tween: Tween

func _ready() -> void:
	if data:
		current_health = data.max_health
		equipped_weapon = data.default_weapon
		
	range_variance = randf_range(-22.0, 22.0)
	gate_x_offset = randf_range(-30.0, 35.0)
	position.y += randf_range(-20.0, 20.0)
	
	update_facing_visuals()
	set_face(FaceState.IDLE)
	start_walking_animation()

func equip_weapon(new_weapon: WeaponData) -> void:
	equipped_weapon = new_weapon

func _physics_process(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta
	if skill_cooldown_timer > 0.0:
		skill_cooldown_timer -= delta
		
	match current_state:
		State.IDLE_WALK:
			handle_combat_ai(delta)
		State.FAINTED:
			if data:
				current_health += data.revive_regen_rate * delta
				if current_health >= data.max_health:
					revive()

# ==============================================================================
# COMBAT AI & TACTICAL ORDERS
# ==============================================================================

func handle_combat_ai(delta: float) -> void:
	match current_command:
		CommandState.RETREAT:
			handle_retreat_logic(delta)
		CommandState.FOCUS:
			handle_focus_logic(delta)
		CommandState.OFFENSIVE:
			handle_offensive_logic(delta)

func handle_retreat_logic(delta: float) -> void:
	var my_gate_spot_x: float = GATE_X_POSITION + gate_x_offset
	
	if not has_reached_gate:
		if position.x > my_gate_spot_x + 10.0:
			set_facing_direction(-1)
			position.x -= data.move_speed * delta
			resume_walking_animation_if_needed()
			return
		else:
			has_reached_gate = true
			stop_walking_animation()
			set_facing_direction(1)

	var guard_target: Node2D = find_monster_in_guard_zone()
	if is_valid_target(guard_target):
		current_target = guard_target
		if position.x > GATE_X_POSITION + guard_leash_range:
			stop_walking_animation()
			position.x -= data.move_speed * delta
			set_facing_direction(-1)
			resume_walking_animation_if_needed()
		else:
			execute_approach_and_attack(guard_target, delta)
	else:
		current_target = null
		if position.x > my_gate_spot_x + 10.0:
			set_facing_direction(-1)
			position.x -= data.move_speed * delta
			resume_walking_animation_if_needed()
		else:
			stop_walking_animation()
			set_facing_direction(1)

func find_monster_in_guard_zone() -> Node2D:
	var monsters: Array[Node] = get_tree().get_nodes_in_group("monsters")
	var closest: Node2D = null
	var min_dist: float = INF
	var max_allowed_x: float = GATE_X_POSITION + guard_leash_range
	for m in monsters:
		if is_instance_valid(m) and m is Node2D:
			if m.global_position.x <= max_allowed_x:
				var dist: float = abs(m.global_position.x - global_position.x)
				if dist < min_dist:
					min_dist = dist
					closest = m
	return closest

func handle_focus_logic(delta: float) -> void:
	if not is_valid_target(focus_target):
		order_offensive()
		return
	current_target = focus_target
	execute_approach_and_attack(current_target, delta)

func handle_offensive_logic(delta: float) -> void:
	if not is_valid_target(current_target):
		current_target = find_closest_monster()
	if not is_valid_target(current_target):
		stop_walking_animation()
		return
	execute_approach_and_attack(current_target, delta)

func execute_approach_and_attack(target_node: Node2D, delta: float) -> void:
	var target_x: float = target_node.global_position.x
	var distance_to_target: float = abs(target_x - global_position.x)
	var dir_to_target: int = 1 if target_x > global_position.x else -1
	set_facing_direction(dir_to_target)
	
	var effective_max_range: float = max(data.min_attack_range + 15.0, data.max_attack_range + range_variance)
	
	if distance_to_target > effective_max_range:
		# Too far: Walk towards target
		position.x += data.move_speed * dir_to_target * delta
		resume_walking_animation_if_needed()
	elif distance_to_target < data.min_attack_range:
		# Check if archer is cornered against the left Gate wall!
		var backpedal_dir: int = -dir_to_target
		var is_cornered_at_gate: bool = (backpedal_dir < 0 and position.x <= MIN_ARENA_X)
		
		if not is_cornered_at_gate:
			# Safe to backpedal while looking at target
			position.x += data.move_speed * backpedal_dir * delta
			resume_walking_animation_if_needed()
		else:
			# Cornered against wall: stand ground and shoot anyway!
			stop_walking_animation()
			if attack_timer <= 0.0:
				perform_attack()
	else:
		# Inside ideal range: Stop and attack!
		stop_walking_animation()
		if attack_timer <= 0.0:
			perform_attack()

func is_valid_target(target_node: Variant) -> bool:
	return is_instance_valid(target_node) and target_node is Node2D and target_node.is_in_group("monsters")

func find_closest_monster() -> Node2D:
	var monsters: Array[Node] = get_tree().get_nodes_in_group("monsters")
	var closest: Node2D = null
	var min_distance: float = INF
	for m in monsters:
		if is_instance_valid(m) and m is Node2D:
			var dist: float = abs(m.global_position.x - global_position.x)
			if dist < min_distance:
				min_distance = dist
				closest = m
	return closest

# ==============================================================================
# PUBLIC ORDER METHODS & ACTIVE SKILL LIFECYCLE
# ==============================================================================

func order_offensive() -> void:
	if current_command == CommandState.OFFENSIVE:
		return
	current_command = CommandState.OFFENSIVE
	focus_target = null
	current_target = null

func order_retreat() -> void:
	if current_command == CommandState.RETREAT:
		return
	current_command = CommandState.RETREAT
	current_target = null
	focus_target = null
	has_reached_gate = false

func order_focus(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	if current_command == CommandState.FOCUS and focus_target == target:
		return
	current_command = CommandState.FOCUS
	focus_target = target
	current_target = target

func can_use_active_skill() -> bool:
	return current_state == State.IDLE_WALK and skill_cooldown_timer <= 0.0 and data != null and data.active_skill != null

func prepare_active_skill() -> void:
	current_state = State.ACTING
	stop_walking_animation()
	skill_cooldown_timer = data.active_skill.cooldown

func execute_prepared_skill() -> void:
	if data and data.active_skill:
		data.active_skill.execute(self)

func use_active_skill() -> bool:
	if not can_use_active_skill():
		return false
	prepare_active_skill()
	execute_prepared_skill()
	return true

# ==============================================================================
# PROCEDURAL ATTACK ANIMATION (MELEE VS RANGED BOW)
# ==============================================================================

func perform_attack() -> void:
	if not is_valid_target(current_target) or current_state != State.IDLE_WALK:
		return
		
	var dir_to_target: int = 1 if current_target.global_position.x > global_position.x else -1
	set_facing_direction(dir_to_target)
	
	current_state = State.ATTACKING
	attack_timer = data.attack_cooldown
	
	# Check if equipped weapon is Ranged (Bow) or Melee
	if equipped_weapon and equipped_weapon.is_ranged and equipped_weapon.projectile_scene:
		await play_ranged_bow_attack()
	else:
		await play_melee_attack()
		
	if current_state == State.ATTACKING:
		current_state = State.IDLE_WALK

func play_melee_attack() -> void:
	var f_scale: float = get_facing_scale_x()
	var tween: Tween = create_tween()
	
	tween.tween_property(visual_root, "position:x", -12.0 * facing_direction, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(visual_root, "scale", Vector2(1.15 * f_scale, 0.85), 0.12)
	
	tween.chain().tween_property(visual_root, "position:x", 16.0 * facing_direction, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(visual_root, "scale", Vector2(0.9 * f_scale, 1.2), 0.08)
	
	await tween.finished
	
	if is_valid_target(current_target) and current_target.has_method("receive_hit"):
		var dmg_info: Dictionary = DamageCalculator.calculate_hunter_attack(self, current_target, 1.0)
		current_target.receive_hit(dmg_info, 15.0, global_position.x)
		
	var tween_recover: Tween = create_tween().set_parallel(true)
	tween_recover.tween_property(visual_root, "position:x", 0.0, 0.15)
	tween_recover.tween_property(visual_root, "scale", Vector2(1.0 * f_scale, 1.0), 0.15)
	await tween_recover.finished

func play_ranged_bow_attack() -> void:
	var f_scale: float = get_facing_scale_x()
	
	# 1. Draw the bowstring (lean back slightly & stretch)
	var tween_draw: Tween = create_tween().set_parallel(true)
	tween_draw.tween_property(visual_root, "rotation_degrees", -8.0 * facing_direction, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_draw.tween_property(visual_root, "scale", Vector2(1.12 * f_scale, 0.9), 0.18)
	await tween_draw.finished
	
	# 2. Snap release & Spawn Parabolic Arrow!
	if is_valid_target(current_target):
		var dmg_info: Dictionary = DamageCalculator.calculate_hunter_attack(self, current_target, 1.0)
		var arrow: Projectile = equipped_weapon.projectile_scene.instantiate()
		
		# Add arrow to the main scene root so it flies freely in world coordinates
		get_tree().current_scene.add_child(arrow)
		
		var spawn_height: float = -sprite.texture.get_height() * 0.55 if sprite.texture else -180.0
		var hand_pos: Vector2 = global_position + Vector2(25.0 * facing_direction, spawn_height)
		arrow.launch(hand_pos, current_target, dmg_info, 8.0, global_position.x)
		
	# 3. Release recoil bounce
	var tween_release: Tween = create_tween().set_parallel(true)
	tween_release.tween_property(visual_root, "rotation_degrees", 4.0 * facing_direction, 0.08)
	tween_release.tween_property(visual_root, "scale", Vector2(0.92 * f_scale, 1.08), 0.08)
	await tween_release.finished
	
	var tween_recover: Tween = create_tween().set_parallel(true)
	tween_recover.tween_property(visual_root, "rotation_degrees", 0.0, 0.12)
	tween_recover.tween_property(visual_root, "scale", Vector2(1.0 * f_scale, 1.0), 0.12)
	await tween_recover.finished

# ==============================================================================
# VISUALS & ORIENTATION
# ==============================================================================

func get_facing_scale_x() -> float:
	if facing_direction == -1 and data and data.texture_idle_left != null:
		return 1.0
	return float(facing_direction)

func set_facing_direction(dir: int) -> void:
	if dir == 0 or dir == facing_direction:
		return
	facing_direction = sign(dir)
	update_facing_visuals()

func update_facing_visuals() -> void:
	if not data:
		return
	if facing_direction == -1 and data.texture_idle_left != null:
		visual_root.scale.x = 1.0
		sprite.texture = data.texture_idle_left
	else:
		visual_root.scale.x = facing_direction
		set_face(FaceState.IDLE)

func set_face(face_state: FaceState) -> void:
	if not data:
		return
	match face_state:
		FaceState.IDLE:
			if facing_direction == -1 and data.texture_idle_left != null:
				sprite.texture = data.texture_idle_left
			else:
				sprite.texture = data.texture_idle
		FaceState.HIT:
			sprite.texture = data.texture_hit
		FaceState.DEAD:
			sprite.texture = data.texture_dead

func set_custom_face(face_key: String) -> void:
	if data and data.special_faces.has(face_key):
		sprite.texture = data.special_faces[face_key]

func set_highlight(active: bool) -> void:
	z_index = 50 if active else 0

func start_walking_animation() -> void:
	if current_state == State.FAINTED or current_state == State.ATTACKING or current_state == State.ACTING:
		return
	if walk_tween and walk_tween.is_valid():
		walk_tween.kill()
	walk_tween = create_tween().set_loops()
	walk_tween.tween_property(visual_root, "rotation_degrees", 3.0, 0.25).set_trans(Tween.TRANS_SINE)
	walk_tween.tween_property(visual_root, "rotation_degrees", -3.0, 0.25).set_trans(Tween.TRANS_SINE)
	walk_tween.parallel().tween_property(visual_root, "scale:y", 0.96, 0.25)
	walk_tween.parallel().tween_property(visual_root, "scale:y", 1.0, 0.25)

func stop_walking_animation() -> void:
	if walk_tween and walk_tween.is_valid():
		walk_tween.kill()
	visual_root.rotation_degrees = 0.0
	visual_root.scale = Vector2(get_facing_scale_x(), 1.0)

func resume_walking_animation_if_needed() -> void:
	if walk_tween == null or not walk_tween.is_valid():
		start_walking_animation()

# ==============================================================================
# DAMAGE RECEPTIONS
# ==============================================================================

func receive_hit(damage: float, knockback_force: float = 0.0, attacker_global_x: float = 0.0, is_launch: bool = false, launch_height: float = 120.0) -> void:
	if current_state == State.FAINTED or current_state == State.LAUNCHED:
		return
	current_health = max(0.0, current_health - damage)
	if current_health <= 0.0:
		faint()
		return
		
	if current_state == State.ACTING:
		sprite.modulate = Color(3.0, 3.0, 3.0)
		var flash_tween = create_tween()
		flash_tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.12)
		return
		
	var push_direction: float = 1.0 if attacker_global_x < global_position.x else -1.0
	if is_launch:
		play_launch_reaction(knockback_force, launch_height, push_direction)
	elif knockback_force > 0.0:
		play_knockback_reaction(knockback_force, push_direction)
	else:
		play_light_hit_reaction(push_direction)

func play_light_hit_reaction(push_direction: float) -> void:
	if current_state != State.IDLE_WALK:
		return
	current_state = State.ACTING
	set_face(FaceState.HIT)
	
	var tween = create_tween()
	sprite.modulate = Color(3.0, 3.0, 3.0)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.15)
	
	var lean_angle: float = 8.0 * push_direction
	tween.parallel().tween_property(visual_root, "scale:y", 1.15, 0.1)
	tween.parallel().tween_property(visual_root, "rotation_degrees", lean_angle, 0.1)
	tween.tween_property(visual_root, "scale:y", 1.0, 0.1)
	tween.tween_property(visual_root, "rotation_degrees", 0.0, 0.1)
	
	await tween.finished
	if current_state == State.ACTING:
		set_face(FaceState.IDLE)
		current_state = State.IDLE_WALK

func play_knockback_reaction(force: float, push_direction: float) -> void:
	current_state = State.ACTING
	set_face(FaceState.HIT)
	
	var tween = create_tween()
	sprite.modulate = Color(3.5, 3.5, 3.5)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.15)
	
	var lean_angle: float = 15.0 * push_direction
	tween.parallel().tween_property(visual_root, "scale:y", 1.2, 0.1)
	tween.parallel().tween_property(visual_root, "rotation_degrees", lean_angle, 0.1)
	
	var target_x: float = position.x + (push_direction * force)
	tween.parallel().tween_property(self, "position:x", target_x, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual_root, "scale:y", 1.0, 0.15)
	tween.parallel().tween_property(visual_root, "rotation_degrees", 0.0, 0.15)
	
	await tween.finished
	if current_state == State.ACTING:
		set_face(FaceState.IDLE)
		current_state = State.IDLE_WALK

func play_launch_reaction(distance: float, height: float, push_direction: float) -> void:
	current_state = State.LAUNCHED
	set_face(FaceState.HIT)
	stop_walking_animation()
		
	var air_time: float = 0.55
	var center_offset: float = 192.0
	var original_sprite_y: float = sprite.position.y
	var flight_distance: float = distance * 0.75
	var skid_distance: float = distance * 0.25
	
	sprite.position.y = original_sprite_y + center_offset
	visual_root.position.y = -center_offset
	
	var tween_y: Tween = create_tween()
	tween_y.tween_property(visual_root, "position:y", -center_offset - height, air_time * 0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_y.tween_property(visual_root, "position:y", 0.0, air_time * 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	var tween_flight: Tween = create_tween().set_parallel(true)
	var impact_x: float = position.x + (push_direction * flight_distance)
	tween_flight.tween_property(self, "position:x", impact_x, air_time).set_trans(Tween.TRANS_LINEAR)
	var total_tumble: float = 450.0 * push_direction
	tween_flight.tween_property(visual_root, "rotation_degrees", total_tumble, air_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await tween_flight.finished
	
	visual_root.rotation_degrees = 90.0 * push_direction
	set_face(FaceState.DEAD)
	
	var tween_skid: Tween = create_tween().set_parallel(true)
	var final_x: float = position.x + (push_direction * skid_distance)
	tween_skid.tween_property(self, "position:x", final_x, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_skid.tween_property(sprite, "position:y", original_sprite_y, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var tween_bounce: Tween = create_tween()
	tween_bounce.tween_property(visual_root, "position:y", -4.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_bounce.tween_property(visual_root, "position:y", 0.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await tween_skid.finished
	await get_tree().create_timer(0.18).timeout
	
	var tween_recover: Tween = create_tween()
	tween_recover.tween_property(visual_root, "rotation_degrees", 0.0, 0.24).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tween_recover.finished
	set_face(FaceState.IDLE)
	current_state = State.IDLE_WALK
	current_target = null
	start_walking_animation()

func faint() -> void:
	current_state = State.FAINTED
	set_face(FaceState.DEAD)
	current_target = null
	stop_walking_animation()
	var tween = create_tween()
	tween.tween_property(visual_root, "rotation_degrees", -90.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(visual_root, "rotation_degrees", -84.0, 0.08)
	tween.tween_property(visual_root, "rotation_degrees", -90.0, 0.08)

func revive() -> void:
	current_health = data.max_health
	var tween = create_tween()
	tween.tween_property(visual_root, "rotation_degrees", 0.0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tween.finished
	set_face(FaceState.IDLE)
	current_state = State.IDLE_WALK
	current_target = null
	start_walking_animation()

# ==============================================================================
# DEBUG / KEYBOARD TESTING
# ==============================================================================
