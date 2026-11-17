class_name SkillButton
extends Control

signal skill_button_clicked(hunter: Hunter)

@export var target_hunter: Hunter

@onready var head_sprite: Sprite2D = $MaskCircle/HeadSprite
@onready var border_ring: Panel = $BorderRing

var is_hovered: bool = false

const COLOR_READY: Color = Color("#fbbf24")    # Bright Gold border
const COLOR_HOVER: Color = Color("#38bdf8")    # Bright Cyan highlight on hover
const COLOR_COOLDOWN: Color = Color("#475569") # Dark Slate grey while recharging
const COLOR_FAINTED: Color = Color("#ef4444")  # Red disabled state if fainted

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Make shader unique per skill button
	if head_sprite.material:
		head_sprite.material = head_sprite.material.duplicate()
		
	setup_head_visual()

func setup_head_visual() -> void:
	if not is_instance_valid(target_hunter) or not target_hunter.data:
		return
		
	var data: HunterData = target_hunter.data
	if data.icon_portrait:
		# Dedicated square headshot
		head_sprite.texture = data.icon_portrait
		var fit_scale: float = 76.0 / max(1.0, float(data.icon_portrait.get_width()))
		head_sprite.scale = Vector2(fit_scale, fit_scale)
		head_sprite.position = Vector2(38.0, 38.0)
		if head_sprite.material is ShaderMaterial:
			head_sprite.material.set_shader_parameter("uv_top", 0.0)
			head_sprite.material.set_shader_parameter("uv_bottom", 1.0)
	elif data.texture_idle:
		# Fallback: Zooms cleanly into the head of the full-body sprite!
		head_sprite.texture = data.texture_idle
		head_sprite.scale = Vector2(0.32, 0.32)
		head_sprite.position = Vector2(38.0, 68.0)
		if head_sprite.material is ShaderMaterial:
			head_sprite.material.set_shader_parameter("uv_top", 0.02)
			head_sprite.material.set_shader_parameter("uv_bottom", 0.45)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if is_instance_valid(target_hunter):
			skill_button_clicked.emit(target_hunter)

func _process(_delta: float) -> void:
	if not is_instance_valid(target_hunter) or not target_hunter.data or not target_hunter.data.active_skill:
		return
		
	# 1. Calculate cooldown fill percentage (0.0 = empty/just cast, 1.0 = full/ready)
	var total_cd: float = target_hunter.data.active_skill.cooldown
	var remaining_cd: float = target_hunter.skill_cooldown_timer
	var fill_progress: float = 1.0
	if total_cd > 0.0:
		fill_progress = clampf(1.0 - (remaining_cd / total_cd), 0.0, 1.0)
		
	if head_sprite.material is ShaderMaterial:
		head_sprite.material.set_shader_parameter("progress", fill_progress)
		
	# 2. Update border color & button juice
	var is_fainted: bool = (target_hunter.current_state == Hunter.State.FAINTED)
	var is_ready: bool = (fill_progress >= 1.0 and not is_fainted)
	
	if is_fainted:
		border_ring.self_modulate = COLOR_FAINTED
		modulate.a = 0.6
		scale = Vector2(1.0, 1.0)
	elif is_ready:
		modulate.a = 1.0
		border_ring.self_modulate = COLOR_HOVER if is_hovered else COLOR_READY
		scale = Vector2(1.08, 1.08) if is_hovered else Vector2(1.0, 1.0)
	else:
		modulate.a = 0.9
		border_ring.self_modulate = COLOR_COOLDOWN
		scale = Vector2(1.0, 1.0)

func _on_mouse_entered() -> void:
	is_hovered = true

func _on_mouse_exited() -> void:
	is_hovered = false
