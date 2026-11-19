class_name MonsterTackleAttack
extends MonsterAttackData

@export_group("Tackle Settings")
@export var charge_distance: float = 280.0
@export var tackle_hit_radius: float = 110.0

func execute(monster: Node2D, target: Node2D) -> void:
	if not (monster is Monster):
		return
	var m: Monster = monster as Monster
	m.current_state = Monster.State.ACTING
	m.stop_walking_animation()
	
	var dir: int = 1 if (is_instance_valid(target) and target.global_position.x > m.global_position.x) else -1
	m.set_facing_direction(dir)
	var f_scale: float = m.get_facing_scale_x()
	
	# 1. Heavy Scraping Wind-up (0.45s telegraph)
	m.sprite.modulate = Color(2.8, 0.6, 0.6) # Angry fiery red telegraph
	var tween_prep: Tween = m.create_tween().set_parallel(true)
	tween_prep.tween_property(m.visual_root, "position:x", -26.0 * dir, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_prep.tween_property(m.visual_root, "scale", Vector2(1.3 * f_scale, 0.72), 0.42)
	tween_prep.tween_property(m.visual_root, "rotation_degrees", -12.0 * dir, 0.42)
	await tween_prep.finished
	
	if not is_instance_valid(m) or m.current_state != Monster.State.ACTING:
		return
		
	# Calculate safe end X (don't charge straight through the Guild Gate wall!)
	var gate: GuildGate = m.get_tree().get_first_node_in_group("guild_gate") as GuildGate
	var min_x: float = gate.get_front_wall_x() + 45.0 if is_instance_valid(gate) else 185.0
	var desired_x: float = max(min_x, m.position.x + (dir * charge_distance))
	
	# 2. Bull Charge!
	var tween_charge: Tween = m.create_tween().set_parallel(true)
	m.sprite.modulate = Color(3.5, 3.5, 3.5)
	tween_charge.tween_property(m.sprite, "modulate", Color(1.0, 1.0, 1.0), 0.2)
	tween_charge.tween_property(m, "position:x", desired_x, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween_charge.tween_property(m.visual_root, "position:x", 20.0 * dir, 0.22)
	tween_charge.tween_property(m.visual_root, "scale", Vector2(0.8 * f_scale, 1.25), 0.22)
	tween_charge.tween_property(m.visual_root, "rotation_degrees", 10.0 * dir, 0.22)
	await tween_charge.finished
	
	if not is_instance_valid(m) or m.current_state != Monster.State.ACTING:
		return
		
	# 3. Impact Delivery (Sends nearby hunters flying!)
	var dmg: float = m.current_attack * damage_multiplier
	for h in m.get_tree().get_nodes_in_group("hunters"):
		if h is Hunter and is_instance_valid(h) and h.current_state != Hunter.State.FAINTED:
			if abs(h.global_position.x - m.global_position.x) <= tackle_hit_radius:
				h.receive_hit(dmg, knockback_force, m.global_position.x, launches_hunter, launch_height)
				
	if is_instance_valid(gate) and not gate.is_destroyed:
		if abs(gate.get_front_wall_x() - m.global_position.x) <= tackle_hit_radius:
			gate.receive_hit(dmg)
			
	EventBus.camera_shake_requested.emit(8.0, 0.16)
	
	# 4. Brake & Recover
	var tween_rec: Tween = m.create_tween().set_parallel(true)
	tween_rec.tween_property(m.visual_root, "position:x", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_rec.tween_property(m.visual_root, "scale", Vector2(1.0 * f_scale, 1.0), 0.25)
	tween_rec.tween_property(m.visual_root, "rotation_degrees", 0.0, 0.25)
	await tween_rec.finished
	
	if is_instance_valid(m) and m.current_state == Monster.State.ACTING:
		m.current_state = Monster.State.IDLE_WALK
		m.start_walking_animation()
