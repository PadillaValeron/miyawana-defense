class_name MassiveTackleGateAttack
extends GateAttackData

@export_group("Tackle Trajectory")
@export var charge_distance_from_gate: float = 1050.0
@export var impact_delay: float = 0.35

func execute(monster: Node2D) -> void:
	if not (monster is Monster):
		return
	var m: Monster = monster as Monster
	var gate: GuildGate = m.get_tree().get_first_node_in_group("guild_gate") as GuildGate
	if not is_instance_valid(gate) or gate.is_destroyed:
		return
		
	m.current_state = Monster.State.ACTING
	m.stop_walking_animation()
	
	var gate_wall_x: float = gate.get_front_wall_x()
	var setup_x: float = min(2650.0, gate_wall_x + charge_distance_from_gate)
	
	# =========================================================================
	# PHASE 1: TACTICAL LEAP BACK TO CHARGE POSITION
	# =========================================================================
	var jump_dir: int = 1 if setup_x > m.global_position.x else -1
	m.set_facing_direction(jump_dir)
	var f_scale: float = m.get_facing_scale_x()
	
	var leap_tween_y: Tween = m.create_tween()
	leap_tween_y.tween_property(m.visual_root, "position:y", -180.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	leap_tween_y.tween_property(m.visual_root, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	var leap_tween_x: Tween = m.create_tween()
	leap_tween_x.tween_property(m, "position:x", setup_x, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await leap_tween_x.finished
	
	if not is_instance_valid(m) or m.current_state != Monster.State.ACTING:
		return
		
	m.set_facing_direction(-1)
	f_scale = m.get_facing_scale_x()
	
	# =========================================================================
	# PHASE 2: INTERRUPTIBLE CHARGE-UP WINDOW!
	# =========================================================================
	m.start_gate_charge(self)
	
	var prep_tween: Tween = m.create_tween().set_parallel(true)
	prep_tween.tween_property(m.visual_root, "scale", Vector2(1.32 * f_scale, 0.68), 0.3)
	prep_tween.tween_property(m.visual_root, "rotation_degrees", 10.0, 0.3)
	
	var pulse_loops: int = max(1, int(charge_duration / 0.24))
	var pulse_tween: Tween = m.create_tween().set_loops(pulse_loops)
	pulse_tween.tween_property(m.sprite, "modulate", Color(3.2, 0.5, 0.8), 0.12)
	pulse_tween.tween_property(m.sprite, "modulate", Color(1.5, 0.3, 0.5), 0.12)
	
	var tremble_tween: Tween = m.create_tween().set_loops(pulse_loops * 3)
	tremble_tween.tween_property(m.visual_root, "position:x", 6.0, 0.04)
	tremble_tween.tween_property(m.visual_root, "position:x", -6.0, 0.04)
	
	# Cancellable wait loop: breaks IMMEDIATELY on interruption or death!
	var elapsed: float = 0.0
	while elapsed < charge_duration:
		if not is_instance_valid(m) or m.current_state == Monster.State.DEAD or m.charge_was_interrupted:
			break
		await m.get_tree().process_frame
		if is_instance_valid(m):
			elapsed += m.get_process_delta_time()
			
	# Clean up charge visuals regardless of whether it finished or broke
	EventBus.boss_warning_changed.emit(m, false)
	if prep_tween and prep_tween.is_valid(): prep_tween.kill()
	if pulse_tween and pulse_tween.is_valid(): pulse_tween.kill()
	if tremble_tween and tremble_tween.is_valid(): tremble_tween.kill()
	
	# ABORT HERE if interrupted or slain! (on_interrupted has already stunned the monster)
	if not is_instance_valid(m) or m.current_state == Monster.State.DEAD or m.charge_was_interrupted:
		return
		
	m.finish_gate_charge_success()
	
	# =========================================================================
	# PHASE 3: M.U.G.E.N. SUPER FREEZE & 0.32x CINEMATIC ZOOM OUT
	# =========================================================================
	m.is_invincible = true
	m.visual_root.position.x = 0.0
	
	var arena: CombatArena = m.get_tree().get_first_node_in_group("combat_arena") as CombatArena
	if is_instance_valid(arena):
		await arena.begin_boss_massive_cinematic(m, gate)
	else:
		Engine.time_scale = 0.0
		
	if not is_instance_valid(m):
		return
		
	# =========================================================================
	# PHASE 4: HYPERSONIC BLITZ TACKLE & EERIE DELAYED IMPACT
	# =========================================================================
	var blitz_tween: Tween = m.create_tween().set_parallel(true)
	blitz_tween.set_ignore_time_scale(true)
	
	var gate_impact_x: float = gate_wall_x + 42.0
	blitz_tween.tween_property(m, "position:x", gate_impact_x, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	blitz_tween.tween_property(m.visual_root, "scale", Vector2(1.85 * f_scale, 0.55), 0.09)
	blitz_tween.tween_property(m.visual_root, "rotation_degrees", -18.0, 0.09)
	await blitz_tween.finished
	
	if not is_instance_valid(m):
		return
		
	m.visual_root.scale = Vector2(0.75 * f_scale, 1.35)
	m.visual_root.rotation_degrees = 8.0
	m.sprite.modulate = Color(2.5, 0.8, 0.8)
	
	await m.get_tree().create_timer(impact_delay, true, false, true).timeout
	
	if not is_instance_valid(m):
		return
		
	# =========================================================================
	# PHASE 5: DETONATE!
	# =========================================================================
	if is_instance_valid(arena):
		arena.end_boss_massive_cinematic(m, gate)
	else:
		Engine.time_scale = 1.0
		
	spawn_massive_impact_vfx(m, gate_wall_x)
	EventBus.camera_shake_requested.emit(26.0, 0.45)
	
	if is_instance_valid(gate) and not gate.is_destroyed:
		var massive_dmg: float = m.current_attack * damage_multiplier
		gate.receive_hit(massive_dmg)
		
	for h in m.get_tree().get_nodes_in_group("hunters"):
		if h is Hunter and is_instance_valid(h) and h.current_state != Hunter.State.FAINTED:
			if abs(h.global_position.x - gate_wall_x) <= 220.0:
				h.receive_hit(m.current_attack * 0.8, 200.0, gate_wall_x - 50.0, true, 160.0)
				
	# =========================================================================
	# PHASE 6: RECOVER & REMOVE INVINCIBILITY
	# =========================================================================
	var rec_tween: Tween = m.create_tween().set_parallel(true)
	rec_tween.tween_property(m.sprite, "modulate", Color(1.0, 1.0, 1.0), 0.3)
	rec_tween.tween_property(m.visual_root, "scale", Vector2(1.0 * f_scale, 1.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rec_tween.tween_property(m.visual_root, "rotation_degrees", 0.0, 0.3)
	await rec_tween.finished
	
	if is_instance_valid(m):
		m.is_invincible = false
		if m.current_state == Monster.State.ACTING:
			m.current_state = Monster.State.IDLE_WALK
			m.start_walking_animation()

func spawn_massive_impact_vfx(m: Monster, impact_x: float) -> void:
	var blast := ColorRect.new()
	blast.color = Color(1.0, 0.25, 0.35, 0.9)
	blast.size = Vector2(80.0, 480.0)
	blast.pivot_offset = Vector2(40.0, 480.0)
	blast.z_index = 6
	
	m.get_tree().current_scene.add_child(blast)
	blast.global_position = Vector2(impact_x - 40.0, m.global_position.y - 480.0)
	
	var tween: Tween = blast.create_tween().set_parallel(true)
	tween.tween_property(blast, "scale", Vector2(5.5, 1.3), 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(blast, "modulate:a", 0.0, 0.32)
	await tween.finished
	if is_instance_valid(blast):
		blast.queue_free()
