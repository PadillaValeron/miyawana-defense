class_name WhirlwindSkill
extends ActiveSkillData

@export_group("Whirlwind Properties")
## Total duration of the spinning attack in seconds
@export var spin_duration: float = 2.4
## Time between each weak hit (0.16s = ~15 hits total!)
@export var hit_interval: float = 0.16
## Area of Effect radius around the hunter to slice all nearby enemies
@export var spin_radius: float = 150.0
## Light knockback per tick (keeps monsters pushed slightly)
@export var knockback_per_hit: float = 8.0
## Slight forward drift speed while spinning through the horde
@export var drift_speed: float = 45.0

func execute(hunter: Hunter) -> void:
	hunter.current_state = Hunter.State.ACTING
	hunter.stop_walking_animation()
	
	var dir: int = hunter.facing_direction
	var f_scale: float = hunter.get_facing_scale_x()
	
	# Calculate dynamic center of mass for clean spinning
	var center_offset: float = 192.0
	if hunter.sprite.texture:
		center_offset = hunter.sprite.texture.get_height() * 0.5
		
	var original_sprite_y: float = hunter.sprite.position.y
	
	# =========================================================================
	# PHASE 1: WIND-UP & HOVER INTO SPIN
	# =========================================================================
	hunter.sprite.position.y = original_sprite_y + center_offset
	hunter.visual_root.position.y = -center_offset - 25.0 # Hovers slightly off the floor
	hunter.sprite.modulate = Color(1.3, 1.8, 2.6) # Energetic wind/cyan aura
	
	# Infinite smooth 360° spin loop while active
	var spin_tween: Tween = hunter.create_tween().set_loops()
	spin_tween.tween_property(hunter.visual_root, "rotation_degrees", 360.0 * dir, 0.18).from(0.0).set_trans(Tween.TRANS_LINEAR)
	
	# =========================================================================
	# PHASE 2: MULTI-HIT SHREDDER LOOP
	# =========================================================================
	var elapsed: float = 0.0
	while elapsed < spin_duration:
		# Safety check: if hunter fainted mid-spin, abort cleanly!
		if not is_instance_valid(hunter) or hunter.current_state != Hunter.State.ACTING:
			break
			
		# Deal AoE weak hits to EVERY monster within spin_radius!
		var monsters = hunter.get_tree().get_nodes_in_group("monsters")
		for m in monsters:
			if m is Node2D and hunter.is_valid_target(m):
				if abs(m.global_position.x - hunter.global_position.x) <= spin_radius:
					if m.has_method("receive_hit"):
						var dmg_info: Dictionary = DamageCalculator.calculate_hunter_attack(hunter, m, base_damage_multiplier)
						m.receive_hit(dmg_info, knockback_per_hit, hunter.global_position.x)
		
		# Gently drift forward towards current target (or facing direction)
		if hunter.is_valid_target(hunter.current_target):
			var dir_to_target: int = 1 if hunter.current_target.global_position.x > hunter.global_position.x else -1
			hunter.position.x += dir_to_target * drift_speed * hit_interval
		else:
			hunter.position.x += dir * drift_speed * hit_interval
			
		await hunter.get_tree().create_timer(hit_interval).timeout
		elapsed += hit_interval
		
	# =========================================================================
	# PHASE 3: CLEANUP & LANDING
	# =========================================================================
	if spin_tween and spin_tween.is_valid():
		spin_tween.kill()
		
	if not is_instance_valid(hunter):
		return
		
	# Restore feet pivot & normal color cleanly
	hunter.sprite.position.y = original_sprite_y
	hunter.sprite.modulate = Color(1.0, 1.0, 1.0)
	
	# Normalize angle to [-180, 180] so she recovers upright smoothly without Beyblade snap
	hunter.visual_root.rotation_degrees = wrapf(hunter.visual_root.rotation_degrees, -180.0, 180.0)
	
	# If still alive (didn't faint mid-spin), drop back down onto feet
	if hunter.current_state == Hunter.State.ACTING:
		var land_tween: Tween = hunter.create_tween().set_parallel(true)
		land_tween.tween_property(hunter.visual_root, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		land_tween.tween_property(hunter.visual_root, "rotation_degrees", 0.0, 0.15)
		land_tween.tween_property(hunter.visual_root, "scale", Vector2(1.0 * f_scale, 1.0), 0.15)
		await land_tween.finished
		
		if hunter.current_state == Hunter.State.ACTING:
			hunter.current_state = Hunter.State.IDLE_WALK
			hunter.start_walking_animation()
	else:
		# If she fainted mid-spin, just ensure root Y returns to ground level
		hunter.visual_root.position.y = 0.0
