class_name HunterPortrait
extends Control

signal portrait_hovered(hunter: Hunter)
signal portrait_unhovered(hunter: Hunter)
signal portrait_clicked(hunter: Hunter)

@export var target_hunter: Hunter

@onready var circle_base: Panel = $CircleBase
@onready var mini_sprite: Sprite2D = $CircleBase/MiniSprite
@onready var health_bar: ProgressBar = $HealthBar
@onready var focus_badge: Label = $CircleBase/FocusBadge

var base_mini_scale: Vector2 = Vector2(0.18, 0.18)
var is_hovered: bool = false
var is_preview_selected: bool = false

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	if target_hunter and target_hunter.data:
		health_bar.max_value = target_hunter.data.max_health
		health_bar.value = target_hunter.current_health
		mini_sprite.texture = target_hunter.data.texture_idle

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if is_instance_valid(target_hunter):
			portrait_clicked.emit(target_hunter)

func set_preview_selected(selected: bool) -> void:
	is_preview_selected = selected

func _process(_delta: float) -> void:
	if not is_instance_valid(target_hunter):
		return
		
	# Mirror visuals
	mini_sprite.texture = target_hunter.sprite.texture
	mini_sprite.modulate = target_hunter.sprite.modulate
	mini_sprite.rotation_degrees = target_hunter.visual_root.rotation_degrees
	
	var squash_x: float = abs(target_hunter.visual_root.scale.x)
	var squash_y: float = target_hunter.visual_root.scale.y
	mini_sprite.scale = Vector2(base_mini_scale.x * squash_x, base_mini_scale.y * squash_y)
	
	# Health & Focus indicator
	health_bar.value = target_hunter.current_health
	if focus_badge:
		focus_badge.visible = (target_hunter.current_command == Hunter.CommandState.FOCUS)
		
	# Visual feedback for Fainted vs Preview-Selected vs Hover
	if target_hunter.current_state == Hunter.State.FAINTED:
		circle_base.self_modulate = Color(0.4, 0.4, 0.4)
		modulate.a = 0.65
	elif is_preview_selected:
		circle_base.self_modulate = Color(1.5, 1.3, 0.35) # Bright Gold on 1st click
		modulate.a = 1.0
	elif is_hovered:
		circle_base.self_modulate = Color(1.25, 1.25, 0.85)
		modulate.a = 1.0
	else:
		circle_base.self_modulate = Color(1.0, 1.0, 1.0)
		modulate.a = 1.0

func _on_mouse_entered() -> void:
	is_hovered = true
	if is_instance_valid(target_hunter):
		portrait_hovered.emit(target_hunter)

func _on_mouse_exited() -> void:
	is_hovered = false
	if is_instance_valid(target_hunter):
		portrait_unhovered.emit(target_hunter)
