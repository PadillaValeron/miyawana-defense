class_name Hunter
extends Node2D

enum State { IDLE_WALK, ATTACKING, ACTING, LAUNCHED, FAINTED }
enum FaceState { IDLE, HIT, DEAD }
# Tactical squad orders
enum CommandState { OFFENSIVE, RETREAT, FOCUS }

@export var data: HunterData

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/CharacterSprite

# Combat runtime variables
var current_health: float = 100.0
var current_state: State = State.IDLE_WALK
var current_command: CommandState = CommandState.OFFENSIVE
var facing_direction: int = 1 # 1 = Right, -1 = Left

# AI & Combat Targeting
var current_target: Node2D = null
var focus_target: Node2D = null
var attack_timer: float = 0.0
const GATE_X_POSITION: float = 120.0 # Coordinate where the gate stands
## Maximum distance from the gate the hunter is allowed to engage enemies while retreating
@export var guard_leash_range: float = 220.0 
var has_reached_gate: bool = false

# Active tweens tracking
var walk_tween: Tween

func _ready() -> void:
	if data:
		current_health = data.max_health
		
	update_facing_visuals()
	set_face(FaceState.IDLE)
	start_walking_animation()

func _physics_process(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta
		
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

## Stance 1: Retreat to the gate, then guard the perimeter (Leash System)
func handle_retreat_logic(delta: float) -> void:
	# PHASE 1: Running back to touch the gate
	if not has_reached_gate:
		if position.x > GATE_X_POSITION + 10.0:
			set_facing_direction(-1)
			position.x -= data.move_speed * delta
			resume_walking_animation_if_needed()
			return
		else:
			# Arrived at the gate for the first time!
			has_reached_gate = true
			stop_walking_animation()
			set_facing_direction(1)

	# PHASE 2: Guarding the Gate (Leash Area: GATE_X to GATE_X + guard_leash_range)
	var guard_target: Node2D = find_monster_in_guard_zone()
	
	if is_instance_valid(guard_target):
		current_target = guard_target
		
		# If the hunter is getting dragged too far away from the gate, break chase!
		if position.x > GATE_X_POSITION + guard_leash_range:
			stop_walking_animation()
			position.x -= data.move_speed * delta
			set_facing_direction(-1)
			resume_walking_animation_if_needed()
		else:
			# Attack the trespasser within the gate perimeter
			execute_approach_and_attack(guard_target, delta)
	else:
		# No enemies near the gate: Pull back to base if we stepped forward
		current_target = null
		if position.x > GATE_X_POSITION + 10.0:
			set_facing_direction(-1)
			position.x -= data.move_speed * delta
			resume_walking_animation_if_needed()
		else:
			# Standing watch at the entrance
			stop_walking_animation()
			set_facing_direction(1)

## Searches only for monsters trespassing inside the gate perimeter
func find_monster_in_guard_zone() -> Node2D:
	var monsters: Array[Node] = get_tree().get_nodes_in_group("monsters")
	var closest: Node2D = null
	var min_dist: float = INF
	var max_allowed_x: float = GATE_X_POSITION + guard_leash_range
	
	for m in monsters:
		if is_instance_valid(m) and m is Node2D:
			# Only consider monsters that have crossed into the defense zone!
			if m.global_position.x <= max_allowed_x:
				var dist: float = abs(m.global_position.x - global_position.x)
				if dist < min_dist:
					min_dist = dist
					closest = m
					
	return closest

## Stance 2: Focus a specific target chosen by player
func handle_focus_logic(delta: float) -> void:
	if not is_instance_valid(focus_target):
		# Target died or vanished; fall back to normal offensive behavior
		order_offensive()
		return
		
	current_target = focus_target
	execute_approach_and_attack(current_target, delta)

## Stance 3: Seek and destroy closest monster
func handle_offensive_logic(delta: float) -> void:
	if not is_instance_valid(current_target):
		current_target = find_closest_monster()
		
	if not is_instance_valid(current_target):
		stop_walking_animation()
		return
		
	execute_approach_and_attack(current_target, delta)

## Shared navigation logic for attacking any target
func execute_approach_and_attack(target_node: Node2D, delta: float) -> void:
	var target_x: float = target_node.global_position.x
	var distance_to_target: float = abs(target_x - global_position.x)
	var dir_to_target: int = 1 if target_x > global_position.x else -1
	
	set_facing_direction(dir_to_target)
	
	if distance_to_target > data.max_attack_range:
		# Approach
		position.x += data.move_speed * dir_to_target * delta
		resume_walking_animation_if_needed()
	elif distance_to_target < data.min_attack_range:
		# Archer coward backpedal
		position.x += data.move_speed * -dir_to_target * delta
		resume_walking_animation_if_needed()
	else:
		# In range: Stop and strike!
		stop_walking_animation()
		if attack_timer <= 0.0:
			perform_attack()

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
# PUBLIC ORDER METHODS (CAN BE CALLED BY HUD OR SQUAD CONTROLLER)
# ==============================================================================

func order_offensive() -> void:
	if current_command == CommandState.OFFENSIVE:
		return
	
	current_command = CommandState.OFFENSIVE
	focus_target = null
	current_target = null # Forces re-evaluating targets

func order_retreat() -> void:
	if current_command == CommandState.RETREAT:
		return
	
	current_command = CommandState.RETREAT
	current_target = null
	focus_target = null
	has_reached_gate = false # Must reach the gate first!

func order_focus(target: Node2D) -> void:
	if current_command == CommandState.FOCUS and focus_target == target:
		return
	
	if not is_instance_valid(target):
		return
	
	current_command = CommandState.FOCUS
	focus_target = target
	current_target = target

# ==============================================================================
# PROCEDURAL ATTACK ANIMATION
# ==============================================================================

func perform_attack() -> void:
	if not is_instance_valid(current_target) or current_state != State.IDLE_WALK:
		return
		
	var dir_to_target: int = 1 if current_target.global_position.x > global_position.x else -1
	set_facing_direction(dir_to_target)
	
	current_state = State.ATTACKING
	attack_timer = data.attack_cooldown
	
	var f_scale: float = get_facing_scale_x()
	var tween: Tween = create_tween()
	
	# Wind-up
	tween.tween_property(visual_root, "position:x", -12.0 * facing_direction, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(visual_root, "scale", Vector2(1.15 * f_scale, 0.85), 0.12)
	
	# Strike
	tween.chain().tween_property(visual_root, "position:x", 16.0 * facing_direction, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(visual_root, "scale", Vector2(0.9 * f_scale, 1.2), 0.08)
	
	await tween.finished
	
	if is_instance_valid(current_target) and current_target.has_method("receive_hit"):
		current_target.receive_hit(data.base_attack, 15.0, global_position.x)
	
	# Recovery
	var tween_recover: Tween = create_tween().set_parallel(true)
	tween_recover.tween_property(visual_root, "position:x", 0.0, 0.15)
	tween_recover.tween_property(visual_root, "scale", Vector2(1.0 * f_scale, 1.0), 0.15)
	
	await tween_recover.finished
	
	if current_state == State.ATTACKING:
		current_state = State.IDLE_WALK

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

# ==============================================================================
# ANIMATIONS (TWEENS)
# ==============================================================================

func start_walking_animation() -> void:
	if current_state == State.FAINTED or current_state == State.ATTACKING:
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
	
	# Air Flight
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
	
	# Crash & Skid
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
	
	# Recover
	var tween_recover: Tween = create_tween()
	tween_recover.tween_property(visual_root, "rotation_degrees", 0.0, 0.24).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	await tween_recover.finished
	set_face(FaceState.IDLE)
	current_state = State.IDLE_WALK
	
	# RESET AGGRO: Forget previous target upon landing
	current_target = null
	start_walking_animation()

func faint() -> void:
	current_state = State.FAINTED
	set_face(FaceState.DEAD)
	current_target = null # Forget target upon fainting
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
	current_target = null # Re-evaluate battlefield
	start_walking_animation()

# ==============================================================================
# DEBUG / KEYBOARD TESTING
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_1:
				receive_hit(15.0, 0.0, position.x + 100.0)
			KEY_2:
				receive_hit(25.0, 80.0, position.x + 100.0)
			KEY_3:
				receive_hit(40.0, 160.0, position.x + 100.0)
			KEY_4:
				receive_hit(50.0, 180.0, position.x + 100.0, true, 130.0)
			KEY_5:
				receive_hit(40.0, 160.0, position.x - 100.0)
			KEY_K:
				receive_hit(9999.0, 0.0, position.x + 100.0)
				
			# TEST TACTICAL ORDERS:
			KEY_R:
				print("ORDER: RETREAT TO GATE")
				order_retreat()
			KEY_O:
				print("ORDER: OFFENSIVE ASSAULT")
				order_offensive()
			KEY_T:
				print("ORDER: FOCUS TARGET (Furthest Dummy)")
				# Targets the furthest dummy to see her ignore the close one!
				var monsters = get_tree().get_nodes_in_group("monsters")
				if monsters.size() > 1:
					order_focus(monsters[monsters.size() - 1])
