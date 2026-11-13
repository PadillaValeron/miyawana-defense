class_name Monster
extends Node2D

# The 4 Tactical Roles defined in the GDD
enum Role { INVADER, TARGETER, RUSHER, APEX }
enum State { IDLE_WALK, ATTACKING, ACTING, STUNNED, DEAD }

# Signals for HUD and CombatArena
signal health_changed(current_hp: float, max_hp: float)
signal died(monster: Monster)

@export var data: MonsterData
@export var role: Role = Role.INVADER

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/MonsterSprite

# Runtime Stats
var max_health: float = 300.0
var current_health: float = 300.0
var current_attack: float = 20.0
var current_state: State = State.IDLE_WALK
var facing_direction: int = -1 # Monsters start walking LEFT towards the gate

# AI & Targeting
var current_target: Node2D = null
var attack_timer: float = 0.0
var target_reevaluate_timer: float = 0.0
const GATE_X_POSITION: float = 140.0

# Special Moves & Cooldowns
var unlocked_specials: Array[MonsterAttackData] = []
var special_cooldowns: Dictionary = {} # { MonsterAttackData: float_remaining_time }

var walk_tween: Tween

func _ready() -> void:
	if not data:
		return
		
	setup_monster_stats()
	setup_visuals()
	start_walking_animation()

func setup_monster_stats() -> void:
	var is_apex: bool = (role == Role.APEX)
	
	# Apply Apex multipliers directly to runtime stats without modifying the .tres file
	max_health = data.max_health * (data.apex_health_multiplier if is_apex else 1.0)
	current_health = max_health
	current_attack = data.base_attack * (data.apex_attack_multiplier if is_apex else 1.0)
	
	# Filter unlocked special attacks (Apex unlocks all, normal filters out apex-only moves)
	unlocked_specials.clear()
	for attack in data.special_attacks:
		if attack and (is_apex or not attack.is_apex_only):
			unlocked_specials.append(attack)
			special_cooldowns[attack] = 0.0

func setup_visuals() -> void:
	if data.texture_idle:
		sprite.texture = data.texture_idle
		# AUTO-PIVOT AT FEET: Half sprite height based on resolution
		sprite.centered = true
		sprite.position.y = -data.texture_idle.get_height() * 0.5
		
	# Apply Apex scale & menacing tint on root so VisualRoot tweens stay clean!
	if role == Role.APEX:
		scale = Vector2(data.apex_scale_multiplier, data.apex_scale_multiplier)
		sprite.self_modulate = Color(1.2, 0.75, 0.85) # Subtle menacing reddish/purple tint
		
	update_facing_visuals()

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD or not data:
		return
		
	# Tick attack & special cooldowns
	if attack_timer > 0.0:
		attack_timer -= delta
	if target_reevaluate_timer > 0.0:
		target_reevaluate_timer -= delta
	for special in special_cooldowns.keys():
		if special_cooldowns[special] > 0.0:
			special_cooldowns[special] -= delta
			
	if current_state == State.IDLE_WALK:
		handle_role_ai(delta)

# ==============================================================================
# ROLE-BASED AI LOGIC
# ==============================================================================

func handle_role_ai(delta: float) -> void:
	match role:
		Role.RUSHER:
			# Ignores all hunters! Rushes directly towards the Guild Gate
			approach_and_attack_gate(delta)
			
		Role.INVADER:
			# Attacks the closest standing hunter in front, otherwise marches to the Gate
			var hunter: Hunter = find_closest_standing_hunter()
			if is_instance_valid(hunter) and abs(hunter.global_position.x - global_position.x) <= 300.0:
				engage_hunter(hunter, delta)
			else:
				approach_and_attack_gate(delta)
				
		Role.TARGETER:
			# Locks onto a specific hunter for 5 seconds before re-evaluating
			if not is_instance_valid(current_target) or current_target.current_state == Hunter.State.FAINTED or target_reevaluate_timer <= 0.0:
				current_target = find_random_standing_hunter()
				target_reevaluate_timer = 5.0
				
			if is_instance_valid(current_target):
				engage_hunter(current_target, delta)
			else:
				approach_and_attack_gate(delta)
				
		Role.APEX:
			# Apex prioritizes closest standing threat, or marches relentlessly to crush the Gate
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
	
	if dist > data.attack_range:
		position.x += data.move_speed * dir * delta
		resume_walking_animation_if_needed()
	else:
		stop_walking_animation()
		try_attack(hunter, dist)

func approach_and_attack_gate(delta: float) -> void:
	current_target = null
	set_facing_direction(-1) # Walk Left towards the gate
	
	var dist_to_gate: float = abs(global_position.x - GATE_X_POSITION)
	if global_position.x > GATE_X_POSITION + data.attack_range:
		position.x -= data.move_speed * delta
		resume_walking_animation_if_needed()
	else:
		stop_walking_animation()
		try_attack(null, dist_to_gate) # Passing null means hitting the Gate!

# ==============================================================================
# TARGETING HELPERS (ONLY STANDING HUNTERS)
# ==============================================================================

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

# ==============================================================================
# RNG ATTACK SELECTION & EXECUTION
# ==============================================================================

func try_attack(target_node: Node2D, distance: float) -> void:
	if attack_timer > 0.0:
		return
		
	# 1. Roll RNG to see if we trigger a Special Move
	for special in unlocked_specials:
		if special_cooldowns[special] <= 0.0 and distance >= special.min_range and distance <= special.max_range:
			if randf() <= special.trigger_chance:
				special_cooldowns[special] = special.cooldown
				attack_timer = data.attack_cooldown
				special.execute(self, target_node)
				return
				
	# 2. Otherwise, perform standard basic attack
	perform_basic_attack(target_node)

func perform_basic_attack(target_node: Node2D) -> void:
	current_state = State.ATTACKING
	attack_timer = data.attack_cooldown
	
	var f_scale: float = get_facing_scale_x()
	var tween: Tween = create_tween()
	
	# Wind-up
	tween.tween_property(visual_root, "position:x", -10.0 * facing_direction, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(visual_root, "scale", Vector2(1.15 * f_scale, 0.85), 0.15)
	
	# Heavy monster strike forward
	tween.chain().tween_property(visual_root, "position:x", 18.0 * facing_direction, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(visual_root, "scale", Vector2(0.85 * f_scale, 1.25), 0.1)
	
	await tween.finished
	
	if current_state == State.DEAD:
		return
	
	# Impact delivery!
	if is_instance_valid(target_node) and target_node is Hunter:
		# If Apex, occasional chance or basic launch test; normal does standard knockback
		var is_launch: bool = (role == Role.APEX and randf() < 0.35)
		var kb: float = 160.0 if is_launch else data.basic_knockback
		target_node.receive_hit(current_attack, kb, global_position.x, is_launch, 130.0)
	elif target_node == null:
		print("[GATE UNDER ATTACK!] ", data.monster_name, " hit the Guild Gate for ", current_attack, " dmg!")
		
	# Recovery
	var tween_rec: Tween = create_tween().set_parallel(true)
	tween_rec.tween_property(visual_root, "position:x", 0.0, 0.2)
	tween_rec.tween_property(visual_root, "scale", Vector2(1.0 * f_scale, 1.0), 0.2)
	await tween_rec.finished
	
	if current_state == State.ATTACKING:
		current_state = State.IDLE_WALK

# ==============================================================================
# RECEIVING DAMAGE & DEATH
# ==============================================================================

func receive_hit(damage: float, knockback_force: float = 0.0, attacker_global_x: float = 0.0) -> void:
	if current_state == State.DEAD:
		return
		
	current_health = max(0.0, current_health - damage)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0.0:
		die()
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
	
	# Monsters resist knockback slightly more (or move smoothly)
	if knockback_force > 0.0:
		var target_x: float = position.x + (push_dir * knockback_force)
		tween.parallel().tween_property(self, "position:x", target_x, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	tween.tween_property(visual_root, "scale", Vector2(1.0 * f_scale, 1.0), 0.12)
	tween.parallel().tween_property(visual_root, "rotation_degrees", 0.0, 0.12)
	
	await tween.finished
	if current_state != State.DEAD and data.texture_idle:
		sprite.texture = data.texture_idle

func die() -> void:
	if current_state == State.DEAD:
		return
		
	# 1. IMMEDIATELY CEASE TO EXIST FOR GAMEPLAY / TARGETING
	current_state = State.DEAD
	remove_from_group("monsters") # Hunters immediately ignore it and switch targets
	died.emit(self) # Notifies HUD to remove its MonsterCard
	stop_walking_animation()
	
	# 2. LOCK INTO HURT POSE
	if data.texture_hit:
		sprite.texture = data.texture_hit
		
	var f_scale: float = get_facing_scale_x()
	visual_root.scale = Vector2(f_scale, 1.0)
	visual_root.rotation_degrees = 0.0
	
	# 3. INTERMITTENT BLINKING & DEATH SHUDDER (approx 1.1 seconds)
	var blink_tween: Tween = create_tween().set_loops(7)
	blink_tween.tween_property(sprite, "modulate", Color(3.5, 3.5, 3.5, 1.0), 0.08)
	blink_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.35), 0.08)
	
	# Subtle vibration shake while blinking
	var shake_tween: Tween = create_tween().set_loops(14)
	shake_tween.tween_property(visual_root, "position:x", 4.0, 0.04)
	shake_tween.tween_property(visual_root, "position:x", -4.0, 0.04)
	
	await blink_tween.finished
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
		
	# 4. THE "POOF" EXPLOSION
	# TODO: Spawn dropped materials in random physics arcs here and send them to HUD bag!
	
	var poof_tween: Tween = create_tween().set_parallel(true)
	sprite.modulate = Color(4.0, 4.0, 4.0, 1.0) # Peak bright burst
	poof_tween.tween_property(visual_root, "scale", Vector2(1.5 * f_scale, 1.5), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	poof_tween.tween_property(sprite, "modulate", Color(4.0, 4.0, 4.0, 0.0), 0.14)
	
	await poof_tween.finished
	queue_free()
# ==============================================================================
# ORIENTATION & WALK TWEENS
# ==============================================================================

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
