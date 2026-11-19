class_name Monster
extends Node2D

enum Role { INVADER, TARGETER, RUSHER, APEX }
enum State { IDLE_WALK, ATTACKING, ACTING, STUNNED, DEAD }

signal health_changed(current_hp: float, max_hp: float)
signal died(monster: Monster)

@export var data: MonsterData
@export var role: Role = Role.INVADER

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/MonsterSprite
@onready var highlight_marker: Label = $HighlightMarker

var max_health: float = 300.0
var current_health: float = 300.0
var current_attack: float = 20.0
var current_state: State = State.IDLE_WALK
var facing_direction: int = -1
var is_invincible: bool = false

var current_target: Node2D = null
var attack_timer: float = 0.0
var target_reevaluate_timer: float = 0.0
var gate_attack_timer: float = 0.0
var stun_timer: float = 0.0
var range_variance: float = 0.0

# Gate Attack Charge & Interruption tracking
var is_charging_gate_attack: bool = false
var charge_was_interrupted: bool = false
var active_gate_attack: GateAttackData = null
var charge_damage_accumulated: float = 0.0

const FALLBACK_GATE_X: float = 140.0
const MAX_ARENA_X: float = 2900.0

var unlocked_specials: Array[MonsterAttackData] = []
var special_cooldowns: Dictionary = {}
var walk_tween: Tween
var stun_tween: Tween

func _ready() -> void:
	if not data:
		return
	range_variance = randf_range(-20.0, 20.0)
	setup_monster_stats()
	setup_visuals()
	start_walking_animation()

func get_left_arena_limit() -> float:
	var gate: GuildGate = get_tree().get_first_node_in_group("guild_gate") as GuildGate
	if is_instance_valid(gate):
		return gate.get_front_wall_x() + 35.0
	return FALLBACK_GATE_X + 35.0

func clamp_x_to_arena(target_x: float) -> float:
	return clampf(target_x, get_left_arena_limit(), MAX_ARENA_X)

func setup_monster_stats() -> void:
	var is_apex: bool = (role == Role.APEX)
	max_health = data.max_health * (data.apex_health_multiplier if is_apex else 1.0)
	current_health = max_health
	current_attack = data.base_attack * (data.apex_attack_multiplier if is_apex else 1.0)
	
	if is_apex and data.apex_gate_attack:
		gate_attack_timer = data.apex_gate_attack.trigger_interval
		
	unlocked_specials.clear()
	for attack in data.special_attacks:
		if attack and (is_apex or not attack.is_apex_only):
			unlocked_specials.append(attack)
			special_cooldowns[attack] = 0.0

func setup_visuals() -> void:
	if sprite.material:
		sprite.material = sprite.material.duplicate()
		
	if data.texture_idle:
		sprite.texture = data.texture_idle
		sprite.centered = true
		sprite.position.y = -data.texture_idle.get_height() * 0.5
		
	if highlight_marker and data.texture_idle:
		highlight_marker.visible = false
		highlight_marker.position = Vector2(-24.0, -data.texture_idle.get_height() - 65.0)
		
	if role == Role.APEX:
		scale = Vector2(data.apex_scale_multiplier, data.apex_scale_multiplier)
		sprite.self_modulate = Color(1.2, 0.75, 0.85)
		
	update_facing_visuals()

func set_highlight(active: bool) -> void:
	if current_state == State.DEAD:
		active = false
	if highlight_marker:
		highlight_marker.visible = active
	z_index = 50 if active else 0
	if sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("outline_width", 6.0 if active else 0.0)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD or not data:
		return
		
	# Handle STUNNED state countdown cleanly
	if current_state == State.STUNNED:
		stun_timer -= delta
		if stun_timer <= 0.0:
			exit_stun()
		position.x = clamp_x_to_arena(position.x)
		return
		
	if attack_timer > 0.0:
		attack_timer -= delta
	if target_reevaluate_timer > 0.0:
		target_reevaluate_timer -= delta
	for special in special_cooldowns.keys():
		if special_cooldowns[special] > 0.0:
			special_cooldowns[special] -= delta
			
	if role == Role.APEX and data.apex_gate_attack and current_state != State.ACTING:
		if gate_attack_timer > 0.0:
			gate_attack_timer -= delta
			
	if current_state == State.IDLE_WALK:
		if role == Role.APEX and data.apex_gate_attack and gate_attack_timer <= 0.0:
			var gate: GuildGate = get_tree().get_first_node_in_group("guild_gate") as GuildGate
			if is_instance_valid(gate) and not gate.is_destroyed:
				gate_attack_timer = data.apex_gate_attack.trigger_interval
				data.apex_gate_attack.execute(self)
				return
				
		handle_role_ai(delta)
		
	position.x = clamp_x_to_arena(position.x)

# ==============================================================================
# GATE ATTACK CHARGE, INTERRUPTION & GUARANTEED STUN
# ==============================================================================

func start_gate_charge(attack: GateAttackData) -> void:
	active_gate_attack = attack
	is_charging_gate_attack = true
	charge_was_interrupted = false
	charge_damage_accumulated = 0.0
	EventBus.boss_warning_changed.emit(self, true)

func finish_gate_charge_success() -> void:
	is_charging_gate_attack = false
	active_gate_attack = null
	EventBus.boss_warning_changed.emit(self, false)

func trigger_gate_attack_interrupt() -> void:
	is_charging_gate_attack = false
	charge_was_interrupted = true
	EventBus.boss_warning_changed.emit(self, false)
	
	# Spawn bright cyan "INTERRUPTED!" banner above the monster
	var sprite_height: float = data.texture_idle.get_height() if data.texture_idle else 250.0
	var spawn_pos: Vector2 = global_position + Vector2(0.0, -sprite_height * scale.y * 0.95)
	EventBus.damage_text_requested.emit(spawn_pos, {
		"custom_text": "INTERRUPTED!",
		"effectiveness": "interrupted"
	})
	EventBus.camera_shake_requested.emit(12.0, 0.2)
	
	var attack_to_break: GateAttackData = active_gate_attack
	active_gate_attack = null
	if attack_to_break:
		attack_to_break.on_interrupted(self)

func enter_stun(duration: float) -> void:
	if current_state == State.DEAD:
		return
		
	current_state = State.STUNNED
	stun_timer = max(stun_timer, duration)
	is_invincible = false
	stop_walking_animation()
	
	if stun_tween and stun_tween.is_valid():
		stun_tween.kill()
		
	# Swap to stunned sprite (or fall back to hurt sprite)
	if data.texture_stunned:
		sprite.texture = data.texture_stunned
	elif data.texture_hit:
		sprite.texture = data.texture_hit
		
	var f_scale: float = get_facing_scale_x()
	visual_root.position.x = 0.0
	visual_root.position.y = 0.0
	sprite.modulate = Color(1.0, 1.0, 1.0)
	
	# Initial heavy stagger backward + slumped dizzy sway loop!
	stun_tween = create_tween()
	stun_tween.tween_property(visual_root, "scale", Vector2(1.2 * f_scale, 0.8), 0.12)
	stun_tween.parallel().tween_property(visual_root, "rotation_degrees", 16.0 * -facing_direction, 0.12)
	stun_tween.tween_property(visual_root, "scale", Vector2(1.08 * f_scale, 0.9), 0.2)
	stun_tween.parallel().tween_property(visual_root, "rotation_degrees", 0.0, 0.2)
	
	await stun_tween.finished
	if current_state == State.STUNNED:
		stun_tween = create_tween().set_loops()
		stun_tween.tween_property(visual_root, "rotation_degrees", 6.0, 0.35).set_trans(Tween.TRANS_SINE)
		stun_tween.tween_property(visual_root, "rotation_degrees", -6.0, 0.35).set_trans(Tween.TRANS_SINE)

func exit_stun() -> void:
	if current_state == State.DEAD:
		return
	if stun_tween and stun_tween.is_valid():
		stun_tween.kill()
		
	var f_scale: float = get_facing_scale_x()
	visual_root.rotation_degrees = 0.0
	visual_root.scale = Vector2(f_scale, 1.0)
	sprite.modulate = Color(1.0, 1.0, 1.0)
	if data.texture_idle:
		sprite.texture = data.texture_idle
		
	current_state = State.IDLE_WALK
	start_walking_animation()

# ==============================================================================
# ROLE-BASED AI LOGIC
# ==============================================================================

func handle_role_ai(delta: float) -> void:
	match role:
		Role.RUSHER:
			approach_and_attack_gate(delta)
		Role.INVADER:
			var hunter: Hunter = find_closest_standing_hunter()
			if is_instance_valid(hunter) and abs(hunter.global_position.x - global_position.x) <= 350.0:
				engage_hunter(hunter, delta)
			else:
				approach_and_attack_gate(delta)
		Role.TARGETER:
			if not is_instance_valid(current_target) or current_target.current_state == Hunter.State.FAINTED or target_reevaluate_timer <= 0.0:
				current_target = find_random_standing_hunter()
				target_reevaluate_timer = 5.0
			if is_instance_valid(current_target):
				engage_hunter(current_target, delta)
			else:
				approach_and_attack_gate(delta)
		Role.APEX:
			var hunter: Hunter = find_closest_standing_hunter()
			if is_instance_valid(hunter):
				engage_hunter(hunter, delta)
			else:
				approach_and_attack_gate(delta)

func engage_hunter(hunter: Hunter, delta: float) -> void:
	current_target = hunter
	var dist: float = abs(hunter.global_position.x - global_position.x)
	var dir: int = 1 if hunter.global_position.x > global_position.x else -1
	set_facing_direction(dir)
	
	var effective_range: float = max(35.0, data.attack_range + range_variance)
	if dist > effective_range:
		if attack_timer <= 0.0:
			if try_special_attack_only(hunter, dist):
				return
			else:
				attack_timer = 1.0
		position.x += data.move_speed * dir * delta
		resume_walking_animation_if_needed()
	else:
		stop_walking_animation()
		try_attack(hunter, dist)

func approach_and_attack_gate(delta: float) -> void:
	current_target = null
	set_facing_direction(-1)
	
	var gate: GuildGate = get_tree().get_first_node_in_group("guild_gate") as GuildGate
	if is_instance_valid(gate) and gate.is_destroyed:
		stop_walking_animation()
		return
		
	var gate_wall_x: float = gate.get_front_wall_x() if is_instance_valid(gate) else FALLBACK_GATE_X
	var effective_range: float = max(35.0, data.attack_range + range_variance)
	var dist_to_gate: float = abs(global_position.x - gate_wall_x)
	
	if global_position.x > gate_wall_x + effective_range:
		if attack_timer <= 0.0 and is_instance_valid(gate):
			if try_special_attack_only(gate, dist_to_gate):
				return
			else:
				attack_timer = 1.0
		position.x -= data.move_speed * delta
		resume_walking_animation_if_needed()
	else:
		stop_walking_animation()
		try_attack(gate, dist_to_gate)

func find_closest_standing_hunter() -> Hunter:
	var hunters = get_tree().get_nodes_in_group("hunters")
	var closest: Hunter = null
	var min_dist: float = INF
	for h in hunters:
		if h is Hunter and is_instance_valid(h) and h.current_state != Hunter.State.FAINTED:
			var dist: float = abs(h.global_position.x - global_position.x)
			if dist < min_dist:
				min_dist = dist
				closest = h
	return closest

func find_random_standing_hunter() -> Hunter:
	var standing: Array[Hunter] = []
	for h in get_tree().get_nodes_in_group("hunters"):
		if h is Hunter and is_instance_valid(h) and h.current_state != Hunter.State.FAINTED:
			standing.append(h)
	if standing.is_empty():
		return null
	return standing.pick_random()

func try_special_attack_only(target_node: Node2D, distance: float) -> bool:
	if unlocked_specials.is_empty():
		return false
	var shuffled_specials: Array[MonsterAttackData] = unlocked_specials.duplicate()
	shuffled_specials.shuffle()
	
	for special in shuffled_specials:
		if special_cooldowns[special] <= 0.0 and distance >= special.min_range and distance <= special.max_range:
			if randf() <= special.trigger_chance:
				special_cooldowns[special] = special.cooldown
				attack_timer = data.attack_cooldown
				special.execute(self, target_node)
				return true
	return false

func try_attack(target_node: Node2D, distance: float) -> void:
	if attack_timer > 0.0:
		return
	if try_special_attack_only(target_node, distance):
		return
	perform_basic_attack(target_node)

func perform_basic_attack(target_node: Node2D) -> void:
	current_state = State.ATTACKING
	attack_timer = data.attack_cooldown
	
	var f_scale: float = get_facing_scale_x()
	var tween: Tween = create_tween()
	tween.tween_property(visual_root, "position:x", -10.0 * facing_direction, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(visual_root, "scale", Vector2(1.15 * f_scale, 0.85), 0.15)
	tween.chain().tween_property(visual_root, "position:x", 18.0 * facing_direction, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(visual_root, "scale", Vector2(0.85 * f_scale, 1.25), 0.1)
	
	await tween.finished
	if current_state == State.DEAD or current_state == State.STUNNED:
		return
		
	if is_instance_valid(target_node):
		if target_node is Hunter:
			var is_launch: bool = (role == Role.APEX and randf() < 0.25)
			var kb: float = 160.0 if is_launch else data.basic_knockback
			target_node.receive_hit(current_attack, kb, global_position.x, is_launch, 130.0)
		elif target_node is GuildGate:
			target_node.receive_hit(current_attack)
			
	var tween_rec: Tween = create_tween().set_parallel(true)
	tween_rec.tween_property(visual_root, "position:x", 0.0, 0.2)
	tween_rec.tween_property(visual_root, "scale", Vector2(1.0 * f_scale, 1.0), 0.2)
	await tween_rec.finished
	
	if current_state == State.ATTACKING:
		current_state = State.IDLE_WALK

# ==============================================================================
# RECEIVING DAMAGE, CHARGE THRESHOLD & DEATH
# ==============================================================================

func receive_hit(damage_info: Dictionary, knockback_force: float = 0.0, attacker_global_x: float = 0.0) -> void:
	if current_state == State.DEAD or is_invincible:
		return
		
	var total_damage: float = damage_info.get("total", 0.0)
	current_health = max(0.0, current_health - total_damage)
	health_changed.emit(current_health, max_health)
	
	var sprite_height: float = data.texture_idle.get_height() if data.texture_idle else 250.0
	var spawn_pos: Vector2 = global_position + Vector2(0.0, -sprite_height * scale.y * 0.75)
	EventBus.damage_text_requested.emit(spawn_pos, damage_info)
	
	if current_health <= 0.0:
		is_charging_gate_attack = false
		die()
		return
		
	# INTERRUPT CHECK: Accumulate damage if charging a Gate Attack!
	if is_charging_gate_attack and active_gate_attack:
		charge_damage_accumulated += total_damage
		if charge_damage_accumulated >= active_gate_attack.damage_threshold_to_interrupt:
			trigger_gate_attack_interrupt()
			return
		
	# SUPER ARMOR / STUNNED STATE: Flash white, ignore knockback interruptions
	if current_state == State.ACTING or current_state == State.STUNNED:
		sprite.modulate = Color(3.0, 3.0, 3.0)
		var flash_tween: Tween = create_tween()
		flash_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.12)
		return
		
	if data.texture_hit:
		sprite.texture = data.texture_hit
		
	var push_dir: float = 1.0 if attacker_global_x < global_position.x else -1.0
	var f_scale: float = get_facing_scale_x()
	
	var tween: Tween = create_tween()
	sprite.modulate = Color(3.0, 3.0, 3.0)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.12)
	tween.parallel().tween_property(visual_root, "scale", Vector2(1.12 * f_scale, 0.9), 0.08)
	tween.parallel().tween_property(visual_root, "rotation_degrees", 6.0 * push_dir, 0.08)
	
	if knockback_force > 0.0:
		var target_x: float = clamp_x_to_arena(position.x + (push_dir * knockback_force))
		tween.parallel().tween_property(self, "position:x", target_x, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	tween.tween_property(visual_root, "scale", Vector2(1.0 * f_scale, 1.0), 0.12)
	tween.parallel().tween_property(visual_root, "rotation_degrees", 0.0, 0.12)
	
	await tween.finished
	if current_state != State.DEAD and current_state != State.STUNNED and data.texture_idle:
		sprite.texture = data.texture_idle

func die() -> void:
	if current_state == State.DEAD:
		return
	current_state = State.DEAD
	is_invincible = false
	is_charging_gate_attack = false
	active_gate_attack = null
	set_highlight(false)
	EventBus.boss_warning_changed.emit(self, false)
	remove_from_group("monsters")
	died.emit(self)
	stop_walking_animation()
	if stun_tween and stun_tween.is_valid():
		stun_tween.kill()
	visual_root.position.y = 0.0
	
	if data.texture_hit:
		sprite.texture = data.texture_hit
		
	var f_scale: float = get_facing_scale_x()
	visual_root.scale = Vector2(f_scale, 1.0)
	visual_root.rotation_degrees = 0.0
	
	var blink_tween: Tween = create_tween().set_loops(7)
	blink_tween.tween_property(sprite, "modulate", Color(3.5, 3.5, 3.5, 1.0), 0.08)
	blink_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.35), 0.08)
	
	var shake_tween: Tween = create_tween().set_loops(14)
	shake_tween.tween_property(visual_root, "position:x", 4.0, 0.04)
	shake_tween.tween_property(visual_root, "position:x", -4.0, 0.04)
	
	await blink_tween.finished
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
		
	var poof_tween: Tween = create_tween().set_parallel(true)
	sprite.modulate = Color(4.0, 4.0, 4.0, 1.0)
	poof_tween.tween_property(visual_root, "scale", Vector2(1.5 * f_scale, 1.5), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	poof_tween.tween_property(sprite, "modulate", Color(4.0, 4.0, 4.0, 0.0), 0.14)
	
	await poof_tween.finished
	queue_free()

func get_facing_scale_x() -> float:
	if not data:
		return 1.0
	if data.sprite_faces_right_by_default:
		return float(facing_direction)
	else:
		return float(-facing_direction)

func set_facing_direction(dir: int) -> void:
	if dir == 0 or dir == facing_direction:
		return
	facing_direction = sign(dir)
	update_facing_visuals()

func update_facing_visuals() -> void:
	visual_root.scale.x = get_facing_scale_x()

func start_walking_animation() -> void:
	if current_state != State.IDLE_WALK:
		return
	if walk_tween and walk_tween.is_valid():
		walk_tween.kill()
	walk_tween = create_tween().set_loops()
	walk_tween.tween_property(visual_root, "rotation_degrees", 2.5, 0.3).set_trans(Tween.TRANS_SINE)
	walk_tween.tween_property(visual_root, "rotation_degrees", -2.5, 0.3).set_trans(Tween.TRANS_SINE)
	walk_tween.parallel().tween_property(visual_root, "scale:y", 0.96, 0.3)
	walk_tween.parallel().tween_property(visual_root, "scale:y", 1.0, 0.3)

func stop_walking_animation() -> void:
	if walk_tween and walk_tween.is_valid():
		walk_tween.kill()
	visual_root.rotation_degrees = 0.0
	visual_root.scale = Vector2(get_facing_scale_x(), 1.0)

func resume_walking_animation_if_needed() -> void:
	if walk_tween == null or not walk_tween.is_valid():
		start_walking_animation()
