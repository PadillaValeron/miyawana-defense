class_name MonsterProjectileAttack
extends MonsterAttackData

@export_group("Projectile Settings")
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 720.0

func execute(monster: Node2D, target: Node2D) -> void:
	if not (monster is Monster) or not projectile_scene:
		return
	var m: Monster = monster as Monster
	m.current_state = Monster.State.ACTING
	m.stop_walking_animation()
	
	var dir: int = 1 if (is_instance_valid(target) and target.global_position.x > m.global_position.x) else -1
	m.set_facing_direction(dir)
	var f_scale: float = m.get_facing_scale_x()
	
	# 1. Telegraph Charge-up (Leans back, glows purple/red)
	var tween_windup: Tween = m.create_tween().set_parallel(true)
	m.sprite.modulate = Color(2.5, 0.8, 2.2)
	tween_windup.tween_property(m.visual_root, "scale", Vector2(1.2 * f_scale, 0.85), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_windup.tween_property(m.visual_root, "rotation_degrees", -10.0 * dir, 0.32)
	await tween_windup.finished
	
	if not is_instance_valid(m) or m.current_state != Monster.State.ACTING:
		return
		
	# 2. Spit / Fire Projectile!
	if is_instance_valid(target):
		var proj: Projectile = projectile_scene.instantiate()
		m.get_tree().current_scene.add_child(proj)
		
		var mouth_h: float = -m.data.texture_idle.get_height() * m.scale.y * 0.65 if m.data.texture_idle else -200.0
		var spawn_pos: Vector2 = m.global_position + Vector2(30.0 * dir, mouth_h)
		var dmg: float = m.current_attack * damage_multiplier
		
		proj.launch_enemy_projectile(spawn_pos, target, dmg, knockback_force, launches_hunter, launch_height, m.global_position.x, projectile_speed)
		
	# 3. Recoil & Recover
	var tween_rec: Tween = m.create_tween().set_parallel(true)
	tween_rec.tween_property(m.sprite, "modulate", Color(1.0, 1.0, 1.0), 0.18)
	tween_rec.tween_property(m.visual_root, "scale", Vector2(1.0 * f_scale, 1.0), 0.18)
	tween_rec.tween_property(m.visual_root, "rotation_degrees", 0.0, 0.18)
	await tween_rec.finished
	
	if is_instance_valid(m) and m.current_state == Monster.State.ACTING:
		m.current_state = Monster.State.IDLE_WALK
		m.start_walking_animation()
