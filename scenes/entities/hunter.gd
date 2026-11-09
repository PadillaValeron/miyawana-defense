class_name Hunter
extends Node2D

# Visual and physical states
enum State { IDLE_WALK, ACTING, LAUNCHED, FAINTED }
enum FaceState { IDLE, HIT, DEAD }

@export var data: HunterData

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/CharacterSprite

# Combat runtime variables
var current_health: float = 100.0
var current_state: State = State.IDLE_WALK
var facing_direction: int = 1 # 1 = Facing Right, -1 = Facing Left

# Active tweens tracking
var walk_tween: Tween

func _ready() -> void:
	if data:
		current_health = data.max_health
		
	update_facing_visuals()
	set_face(FaceState.IDLE)
	start_walking_animation()

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE_WALK:
			# Advance in the current facing direction
			position.x += data.move_speed * facing_direction * delta
			
		State.FAINTED:
			# Gradually recover health while downed
			if data:
				current_health += data.revive_regen_rate * delta
				if current_health >= data.max_health:
					revive()

# ==============================================================================
# VISUALS & ORIENTATION
# ==============================================================================

## Changes facing direction: 1 for Right, -1 for Left
func set_facing_direction(dir: int) -> void:
	if dir == 0 or dir == facing_direction:
		return
	facing_direction = sign(dir)
	update_facing_visuals()

func update_facing_visuals() -> void:
	if not data:
		return
		
	# Check if this hunter has a dedicated left-profile sprite
	if facing_direction == -1 and data.texture_idle_left != null:
		visual_root.scale.x = 1.0
		sprite.texture = data.texture_idle_left
	else:
		# Standard 2D flip by inverting scale.x
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
	if current_state == State.FAINTED:
		return
		
	if walk_tween and walk_tween.is_valid():
		walk_tween.kill()
		
	walk_tween = create_tween().set_loops()
	
	# Sway rotation from the feet
	walk_tween.tween_property(visual_root, "rotation_degrees", 3.0, 0.25).set_trans(Tween.TRANS_SINE)
	walk_tween.tween_property(visual_root, "rotation_degrees", -3.0, 0.25).set_trans(Tween.TRANS_SINE)
	
	# Vertical bounce (Squash towards the ground)
	walk_tween.parallel().tween_property(visual_root, "scale:y", 0.96, 0.25)
	walk_tween.parallel().tween_property(visual_root, "scale:y", 1.0, 0.25)

# ==============================================================================
# COMBAT & DAMAGE RECEPTIONS (CALLED BY MONSTERS / HITBOXES)
# ==============================================================================

## Master entry point to receive any attack from monsters
# ==============================================================================
# COMBAT & DAMAGE RECEPTIONS
# ==============================================================================

## Master entry point to receive any attack from monsters
func receive_hit(damage: float, knockback_force: float = 0.0, attacker_global_x: float = 0.0, is_launch: bool = false, launch_height: float = 120.0) -> void:
	# INVULNERABILITY: Cannot be hit while fainted OR while launched/downed in the air
	if current_state == State.FAINTED or current_state == State.LAUNCHED:
		return
		
	current_health = max(0.0, current_health - damage)
	
	if current_health <= 0.0:
		faint()
		return
		
	# Calculate push direction away from attacker (+1 = to the right, -1 = to the left)
	var push_direction: float = 1.0 if attacker_global_x < global_position.x else -1.0
	
	if is_launch:
		play_launch_reaction(knockback_force, launch_height, push_direction)
	elif knockback_force > 0.0:
		play_knockback_reaction(knockback_force, push_direction)
	else:
		play_light_hit_reaction(push_direction)

## Type 1: Light hit (Flinch leans away from the blow)
func play_light_hit_reaction(push_direction: float) -> void:
	if current_state != State.IDLE_WALK:
		return
		
	current_state = State.ACTING
	set_face(FaceState.HIT)
	
	var tween = create_tween()
	sprite.modulate = Color(3.0, 3.0, 3.0)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.15)
	
	# Lean angle dynamically matches the blow direction (8.0 * push_direction)
	var lean_angle: float = 8.0 * push_direction
	tween.parallel().tween_property(visual_root, "scale:y", 1.15, 0.1)
	tween.parallel().tween_property(visual_root, "rotation_degrees", lean_angle, 0.1)
	
	tween.tween_property(visual_root, "scale:y", 1.0, 0.1)
	tween.tween_property(visual_root, "rotation_degrees", 0.0, 0.1)
	
	await tween.finished
	if current_state == State.ACTING:
		set_face(FaceState.IDLE)
		current_state = State.IDLE_WALK

## Type 2: Knockback (Leans forward or backward depending on where the hit came from)
func play_knockback_reaction(force: float, push_direction: float) -> void:
	current_state = State.ACTING
	set_face(FaceState.HIT)
	
	var tween = create_tween()
	sprite.modulate = Color(3.5, 3.5, 3.5)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.15)
	
	# Dynamic lean: +15 deg if hit from behind, -15 deg if hit from front
	var lean_angle: float = 15.0 * push_direction
	tween.parallel().tween_property(visual_root, "scale:y", 1.2, 0.1)
	tween.parallel().tween_property(visual_root, "rotation_degrees", lean_angle, 0.1)
	
	# Slide along the floor
	var target_x: float = position.x + (push_direction * force)
	tween.parallel().tween_property(self, "position:x", target_x, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Recovery to upright stance
	tween.tween_property(visual_root, "scale:y", 1.0, 0.15)
	tween.parallel().tween_property(visual_root, "rotation_degrees", 0.0, 0.15)
	
	await tween.finished
	if current_state == State.ACTING:
		set_face(FaceState.IDLE)
		current_state = State.IDLE_WALK


## Type 3: Launch (Smooth center-of-mass tumble, seamless ground impact, blended skid)
func play_launch_reaction(distance: float, height: float, push_direction: float) -> void:
	current_state = State.LAUNCHED
	set_face(FaceState.HIT)
	
	if walk_tween and walk_tween.is_valid():
		walk_tween.kill()
		
	var air_time: float = 0.55
	var center_offset: float = 192.0 # Half height: center of mass
	var original_sprite_y: float = sprite.position.y
	
	var flight_distance: float = distance * 0.75
	var skid_distance: float = distance * 0.25
	
	# =========================================================================
	# PHASE 1 & 2: AIR FLIGHT (Centered Pivot)
	# =========================================================================
	
	# 1. Shift pivot to waist for realistic airborne tumbling
	sprite.position.y = original_sprite_y + center_offset
	visual_root.position.y = -center_offset
	
	# 2. Y Arc: Goes up, and descends ALL THE WAY down to ground level (0.0)
	var tween_y: Tween = create_tween()
	tween_y.tween_property(visual_root, "position:y", -center_offset - height, air_time * 0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_y.tween_property(visual_root, "position:y", 0.0, air_time * 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# 3. Horizontal flight & rotation around center of mass
	var tween_flight: Tween = create_tween().set_parallel(true)
	var impact_x: float = position.x + (push_direction * flight_distance)
	tween_flight.tween_property(self, "position:x", impact_x, air_time).set_trans(Tween.TRANS_LINEAR)
	
	var total_tumble: float = 450.0 * push_direction
	tween_flight.tween_property(visual_root, "rotation_degrees", total_tumble, air_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await tween_flight.finished
	# we fix the rotation so it doesn't spin the 450 degree when standing up
	visual_root.rotation_degrees = 90.0 * push_direction
	
	# =========================================================================
	# PHASE 3 & 4: CRASH & BLENDED SKID (Pivot smoothly returns to feet)
	# =========================================================================
	
	set_face(FaceState.DEAD) # Knocked out face
	
	# During the skid, we blend:
	# 1) The horizontal friction slide (self.position.x)
	# 2) The gradual restoration of the sprite position back to original_sprite_y
	var tween_skid: Tween = create_tween().set_parallel(true)
	var final_x: float = position.x + (push_direction * skid_distance)
	
	# Slide across the dirt
	tween_skid.tween_property(self, "position:x", final_x, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Seamless pivot blend: moves sprite back smoothly while sliding, masking any pop!
	tween_skid.tween_property(sprite, "position:y", original_sprite_y, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Mini ground shock impact
	var tween_bounce: Tween = create_tween()
	tween_bounce.tween_property(visual_root, "position:y", -4.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_bounce.tween_property(visual_root, "position:y", 0.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await tween_skid.finished
	await get_tree().create_timer(0.18).timeout
	
	# =========================================================================
	# PHASE 5: SPRING RECOVERY (Pivoting from feet cleanly)
	# =========================================================================
	var tween_recover: Tween = create_tween()
	tween_recover.tween_property(visual_root, "rotation_degrees", 0.0, 0.24).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	await tween_recover.finished
	
	set_face(FaceState.IDLE)
	current_state = State.IDLE_WALK
	start_walking_animation()

# ==============================================================================
# FAINT & REVIVE SYSTEM
# ==============================================================================

func faint() -> void:
	current_state = State.FAINTED
	set_face(FaceState.DEAD)
	
	if walk_tween and walk_tween.is_valid():
		walk_tween.kill()
		
	var tween = create_tween()
	# Fall backwards onto the ground
	tween.tween_property(visual_root, "rotation_degrees", -90.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Minor bounce upon hitting the ground
	tween.tween_property(visual_root, "rotation_degrees", -84.0, 0.08)
	tween.tween_property(visual_root, "rotation_degrees", -90.0, 0.08)

func revive() -> void:
	current_health = data.max_health
	
	var tween = create_tween()
	# Get back up onto feet
	tween.tween_property(visual_root, "rotation_degrees", 0.0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	set_face(FaceState.IDLE)
	current_state = State.IDLE_WALK
	start_walking_animation()

# ==============================================================================
# DEBUG / KEYBOARD TESTING
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			# 1: Light hit (Assume monster is at X = position.x + 100)
			KEY_1:
				receive_hit(15.0, 0.0, position.x + 100.0)
			# 2: Medium knockback
			KEY_2:
				receive_hit(25.0, 80.0, position.x + 100.0)
			# 3: Heavy knockback
			KEY_3:
				receive_hit(40.0, 500.0, position.x + 100.0)
			# 4: Launch into the air (Parabolic flight!)
			KEY_4:
				receive_hit(50.0, 200.0, position.x + 100, true, 500.0)
			# F: Flip walking direction (Left / Right)
			KEY_F:
				set_facing_direction(-facing_direction)
			# K: Force faint (instant 0 HP)
			KEY_K:
				receive_hit(9999.0, 0.0, position.x + 100.0)
