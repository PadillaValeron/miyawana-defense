class_name HeavyCleaveSkill
extends ActiveSkillData

@export_group("Cleave Properties")
## Maximum reach of the rocket lunge
@export var max_lunge_range: float = 450.0 
## Distance traveled if lunging into empty space
@export var default_dash_distance: float = 280.0 
@export var knockback_delivered: float = 140.0

func execute(hunter: Hunter) -> void:
	hunter.current_state = Hunter.State.ACTING
	hunter.stop_walking_animation()
	
	# Determine direction and distance to target
	var dir: int = hunter.facing_direction
	var can_reach_target: bool = false
	var dash_distance: float = default_dash_distance
	
	if is_instance_valid(hunter.current_target):
		var target_x: float = hunter.current_target.global_position.x
		var distance_to_target: float = abs(target_x - hunter.global_position.x)
		var dir_to_target: int = 1 if target_x > hunter.global_position.x else -1
		
		# Turn to face target before charging
		hunter.set_facing_direction(dir_to_target)
		dir = hunter.facing_direction
		
		# If target is within dash reach, rocket all the way to its face!
		if distance_to_target <= max_lunge_range:
			can_reach_target = true
			# Dash to 60px in front of the target
			dash_distance = max(0.0, distance_to_target - 60.0)

	var f_scale: float = hunter.get_facing_scale_x()
	
	# =========================================================================
	# PHASE 1: CHARGING WIND-UP (Fiery deep crouch)
	# =========================================================================
	var tween_charge: Tween = hunter.create_tween().set_parallel(true)
	
	# Deep backward crouch
	tween_charge.tween_property(hunter.visual_root, "position:x", -30.0 * dir, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_charge.tween_property(hunter.visual_root, "scale", Vector2(1.35 * f_scale, 0.65), 0.35)
	tween_charge.tween_property(hunter.visual_root, "rotation_degrees", -15.0 * dir, 0.35)
	
	# Glowing aura (golden-red ignite)
	hunter.sprite.modulate = Color(3.0, 1.2, 0.4)
	
	await tween_charge.finished
	
	# =========================================================================
	# PHASE 2: EXPLOSIVE ROCKET LUNGE (Actual physical movement!)
	# =========================================================================
	var tween_lunge: Tween = hunter.create_tween().set_parallel(true)
	
	# Blinding release flash
	hunter.sprite.modulate = Color(4.0, 4.0, 4.0)
	tween_lunge.tween_property(hunter.sprite, "modulate", Color(1, 1, 1), 0.15)
	
	# ROCKET DASH: Moves the character physically across the battlefield!
	var final_x: float = hunter.position.x + (dir * dash_distance)
	tween_lunge.tween_property(hunter, "position:x", final_x, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Aerodynamic forward stretch
	tween_lunge.tween_property(hunter.visual_root, "scale", Vector2(0.7 * f_scale, 1.4), 0.16)
	tween_lunge.tween_property(hunter.visual_root, "rotation_degrees", 10.0 * dir, 0.16)
	tween_lunge.tween_property(hunter.visual_root, "position:x", 25.0 * dir, 0.16)
	
	await tween_lunge.finished
	
	# =========================================================================
	# PHASE 3: IMPACT & HIT CONFIRM (Only if physically reached!)
	# =========================================================================
	if can_reach_target and is_instance_valid(hunter.current_target) and hunter.current_target.has_method("receive_hit"):
		var total_damage: float = hunter.data.base_attack * base_damage_multiplier
		# Delivers massive damage + heavy 140px knockback
		hunter.current_target.receive_hit(total_damage, knockback_delivered, hunter.global_position.x)
	
	# =========================================================================
	# PHASE 4: RECOVERY & STANCE BRAKE
	# =========================================================================
	var tween_recover: Tween = hunter.create_tween().set_parallel(true)
	tween_recover.tween_property(hunter.visual_root, "position:x", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_recover.tween_property(hunter.visual_root, "scale", Vector2(1.0 * f_scale, 1.0), 0.22)
	tween_recover.tween_property(hunter.visual_root, "rotation_degrees", 0.0, 0.22)
	
	await tween_recover.finished
	
	# Restore standard AI behavior
	hunter.current_state = Hunter.State.IDLE_WALK
	hunter.start_walking_animation()
