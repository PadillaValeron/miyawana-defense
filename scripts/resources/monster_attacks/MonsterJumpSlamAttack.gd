class_name MonsterJumpSlamAttack
extends MonsterAttackData

@export_group("Jump Slam Settings")
@export var jump_height: float = 250.0
@export var aoe_radius: float = 240.0

func execute(monster: Node2D, target: Node2D) -> void:
	if not (monster is Monster):
		return
	var m: Monster = monster as Monster
	m.current_state = Monster.State.ACTING
	m.stop_walking_animation()
	
	var dir: int = 1 if (is_instance_valid(target) and target.global_position.x > m.global_position.x) else -1
	m.set_facing_direction(dir)
	var f_scale: float = m.get_facing_scale_x()
	
	# 1. Deep Crouch Prep (0.28s)
	m.sprite.modulate = Color(2.2, 0.6, 2.5) # Purple warning glow
	var tween_prep: Tween = m.create_tween().set_parallel(true)
	tween_prep.tween_property(m.visual_root, "scale", Vector2(1.3 * f_scale, 0.65), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween_prep.finished
	
	if not is_instance_valid(m) or m.current_state != Monster.State.ACTING:
		return
		
	# Calculate slight forward hop towards target (safe against gate wall)
	var gate: GuildGate = m.get_tree().get_first_node_in_group("guild_gate") as GuildGate
	var min_x: float = gate.get_front_wall_x() + 45.0 if is_instance_valid(gate) else 185.0
	var leap_x: float = m.position.x
	if is_instance_valid(target):
		leap_x = max(min_x, lerp(m.position.x, target.global_position.x, 0.45))
		
	# 2. High Leap into the Air! (0.38s)
	var tween_up: Tween = m.create_tween().set_parallel(true)
	tween_up.tween_property(m.visual_root, "position:y", -jump_height, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_up.tween_property(m.visual_root, "scale", Vector2(0.85 * f_scale, 1.25), 0.38)
	tween_up.tween_property(m, "position:x", leap_x, 0.54).set_trans(Tween.TRANS_LINEAR)
	await tween_up.finished
	
	if not is_instance_valid(m) or m.current_state != Monster.State.ACTING:
		return
		
	# 3. CRUSHING SLAM DOWN! (0.16s)
	var tween_slam: Tween = m.create_tween().set_parallel(true)
	tween_slam.tween_property(m.visual_root, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween_slam.tween_property(m.visual_root, "scale", Vector2(1.4 * f_scale, 0.65), 0.16)
	await tween_slam.finished
	
	if not is_instance_valid(m) or m.current_state != Monster.State.ACTING:
		return
		
	# 4. SHOCKWAVE RING VFX + AOE LAUNCH + CAMERA SHAKE!
	spawn_shockwave_vfx(m)
	EventBus.camera_shake_requested.emit(14.0, 0.24)
	m.sprite.modulate = Color(1.0, 1.0, 1.0)
	
	var dmg: float = m.current_attack * damage_multiplier
	for h in m.get_tree().get_nodes_in_group("hunters"):
		if h is Hunter and is_instance_valid(h) and h.current_state != Hunter.State.FAINTED:
			if abs(h.global_position.x - m.global_position.x) <= aoe_radius:
				h.receive_hit(dmg, knockback_force, m.global_position.x, launches_hunter, launch_height)
				
	if is_instance_valid(gate) and not gate.is_destroyed:
		if abs(gate.get_front_wall_x() - m.global_position.x) <= aoe_radius:
			gate.receive_hit(dmg)
			
	# 5. Heavy Recovery
	var tween_rec: Tween = m.create_tween()
	tween_rec.tween_property(m.visual_root, "scale", Vector2(1.0 * f_scale, 1.0), 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tween_rec.finished
	
	if is_instance_valid(m) and m.current_state == Monster.State.ACTING:
		m.current_state = Monster.State.IDLE_WALK
		m.start_walking_animation()

func spawn_shockwave_vfx(m: Monster) -> void:
	var wave := ColorRect.new()
	wave.color = Color(0.85, 0.25, 0.95, 0.85) # Vivid purple-magenta shockwave
	wave.size = Vector2(40.0, 22.0)
	wave.pivot_offset = Vector2(20.0, 11.0)
	wave.z_index = 4
	
	m.get_tree().current_scene.add_child(wave)
	wave.global_position = m.global_position - Vector2(20.0, 11.0)
	
	var target_scale_x: float = (aoe_radius * 2.0) / 40.0
	var tween: Tween = wave.create_tween().set_parallel(true)
	tween.tween_property(wave, "scale", Vector2(target_scale_x, 1.4), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(wave, "modulate:a", 0.0, 0.28)
	await tween.finished
	if is_instance_valid(wave):
		wave.queue_free()
