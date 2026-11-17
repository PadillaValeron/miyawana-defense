class_name MonsterCard
extends Control

signal card_hovered(monster: Monster)
signal card_unhovered(monster: Monster)
signal card_clicked(monster: Monster)

@onready var card_frame: Panel = $CardFrame
@onready var monster_icon: TextureRect = $CardFrame/MonsterIcon
@onready var role_badge: ColorRect = $CardFrame/RoleBadge
@onready var role_symbol: Label = $CardFrame/RoleBadge/RoleSymbol
@onready var health_bar: ProgressBar = $HealthBar
@onready var target_badges: HBoxContainer = $CardFrame/TargetBadges

var target_monster: Monster = null
var is_hovered: bool = false
var is_preview_selected: bool = false

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if is_instance_valid(target_monster):
			card_clicked.emit(target_monster)

func setup(monster: Monster) -> void:
	target_monster = monster
	
	if monster.data:
		if monster.data.icon_portrait:
			monster_icon.texture = monster.data.icon_portrait
		elif monster.data.texture_idle:
			monster_icon.texture = monster.data.texture_idle
			
	setup_role_badge(monster.role)
	
	health_bar.max_value = monster.max_health
	health_bar.value = monster.current_health
	monster.health_changed.connect(_on_monster_health_changed)
	monster.died.connect(_on_monster_died)

func setup_role_badge(role: Monster.Role) -> void:
	match role:
		Monster.Role.INVADER:
			role_badge.color = Color("#ef4444")
			role_symbol.text = "🦷"
		Monster.Role.RUSHER:
			role_badge.color = Color("#3b82f6")
			role_symbol.text = "🚪"
		Monster.Role.TARGETER:
			role_badge.color = Color("#22c55e")
			role_symbol.text = "🎯"
		Monster.Role.APEX:
			role_badge.color = Color("#a855f7")
			role_symbol.text = "💀"

func set_preview_selected(selected: bool) -> void:
	is_preview_selected = selected
	update_frame_visual()

func update_frame_visual() -> void:
	if is_preview_selected:
		card_frame.self_modulate = Color(1.8, 1.5, 0.4) # Bright gold selection
	elif is_hovered:
		card_frame.self_modulate = Color(1.5, 1.5, 1.5) # Hover highlight
	else:
		card_frame.self_modulate = Color(1.0, 1.0, 1.0)

func update_target_badges(hunters_focusing: Array[Hunter]) -> void:
	if not target_badges:
		return
	for child in target_badges.get_children():
		child.queue_free()
	for hunter in hunters_focusing:
		if hunter.data and hunter.data.texture_idle:
			var mini_icon := TextureRect.new()
			mini_icon.texture = hunter.data.texture_idle
			mini_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mini_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mini_icon.custom_minimum_size = Vector2(20, 20)
			mini_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			target_badges.add_child(mini_icon)

func _on_monster_health_changed(current_hp: float, max_hp: float) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current_hp

func _on_monster_died(_monster: Monster) -> void:
	queue_free()

func _on_mouse_entered() -> void:
	is_hovered = true
	update_frame_visual()
	if is_instance_valid(target_monster):
		card_hovered.emit(target_monster)

func _on_mouse_exited() -> void:
	is_hovered = false
	update_frame_visual()
	if is_instance_valid(target_monster):
		card_unhovered.emit(target_monster)
