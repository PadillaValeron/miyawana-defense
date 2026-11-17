class_name CombatArena
extends Node2D

enum UIState { IDLE, PICK_HUNTER, PICK_MONSTER }
enum PendingOrder { NONE, OFFENSE, RETREAT, TARGET }

@onready var camera: Camera2D = $Camera2D

@export var lane_total_width: float = 3000.0
@export var monster_card_scene: PackedScene
@export var floating_text_scene: PackedScene

# World & HUD Overlay references
@onready var world_dark_overlay: ColorRect = $WorldDarkOverlay
@onready var input_blocker: ColorRect = $HUD/UIRoot/DarkOverlay

@onready var top_left_hud: MarginContainer = $HUD/UIRoot/TopLeft
@onready var top_right_hud: MarginContainer = $HUD/UIRoot/TopRight
@onready var bottom_left_hud: MarginContainer = $HUD/UIRoot/BottomLeft
@onready var bottom_right_hud: MarginContainer = $HUD/UIRoot/BottomRight

@onready var squad_portraits_container: HBoxContainer = $HUD/UIRoot/TopLeft/SquadPortraits
@onready var monster_cards_container: HBoxContainer = $HUD/UIRoot/TopRight/MonsterCardsContainer
@onready var skills_bar_container: HBoxContainer = $HUD/UIRoot/BottomRight/SkillsBar

@onready var btn_offense: Button = $HUD/UIRoot/BottomLeft/CommandBar/BtnOffense
@onready var btn_retreat: Button = $HUD/UIRoot/BottomLeft/CommandBar/BtnRetreat
@onready var btn_target: Button = $HUD/UIRoot/BottomLeft/CommandBar/BtnTarget
@onready var btn_cancel: Button = $HUD/UIRoot/BottomLeft/CommandBar/BtnCancel

# Camera dragging
var is_dragging_camera: bool = false
var drag_start_mouse_pos: Vector2 = Vector2.ZERO
var drag_start_camera_pos: Vector2 = Vector2.ZERO
var camera_focus_tween: Tween

# Combat & Director state
var active_hunters: Array[Hunter] = []
var active_portraits: Array[HunterPortrait] = []
var active_monster_cards: Array[MonsterCard] = []

var ui_state: UIState = UIState.IDLE
var pending_order: PendingOrder = PendingOrder.NONE
var pending_hunter: Hunter = null

var previewed_hunter: Hunter = null
var previewed_monster: Monster = null

const DIMMED_COLOR: Color = Color(0.3, 0.3, 0.3, 1.0)
const BRIGHT_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)

func _ready() -> void:
	# 1. Register Hunters
	for node in get_tree().get_nodes_in_group("hunters"):
		if node is Hunter:
			active_hunters.append(node)
			
	# 2. Register Monsters
	for node in get_tree().get_nodes_in_group("monsters"):
		if node is Monster:
			register_monster(node)
			
	# 3. Connect Hunter Portraits (TopLeft)
	for child in squad_portraits_container.get_children():
		if child is HunterPortrait:
			active_portraits.append(child)
			child.portrait_clicked.connect(_on_hunter_portrait_clicked)
			child.portrait_hovered.connect(_on_hunter_portrait_hovered)
			child.portrait_unhovered.connect(_on_hunter_portrait_unhovered)
			
	# 4. Connect Active Skill Buttons (BottomRight)
	if skills_bar_container:
		for child in skills_bar_container.get_children():
			if child is SkillButton:
				child.skill_button_clicked.connect(_on_skill_button_clicked)
			
	# 5. Connect BottomLeft Command Buttons
	btn_offense.pressed.connect(_on_btn_offense_pressed)
	btn_retreat.pressed.connect(_on_btn_retreat_pressed)
	btn_target.pressed.connect(_on_btn_target_pressed)
	btn_cancel.pressed.connect(cancel_command_mode)
	
	# 6. Initialize clean UI & Camera
	reset_ui_to_idle()
	var half_width: float = get_half_visible_world_width()
	if camera.position.x < half_width:
		camera.position.x = half_width
	EventBus.damage_text_requested.connect(_on_damage_text_requested)

func _physics_process(_delta: float) -> void:
	sort_monster_cards_by_distance()
	refresh_all_target_badges()

# ==============================================================================
# GUIDED BULLET-TIME COMMAND WORKFLOW
# ==============================================================================

func _on_btn_offense_pressed() -> void:
	if ui_state == UIState.IDLE:
		enter_pick_hunter_mode(PendingOrder.OFFENSE)
	elif ui_state == UIState.PICK_HUNTER and pending_order == PendingOrder.OFFENSE:
		execute_order_for_target(null)

func _on_btn_retreat_pressed() -> void:
	if ui_state == UIState.IDLE:
		enter_pick_hunter_mode(PendingOrder.RETREAT)
	elif ui_state == UIState.PICK_HUNTER and pending_order == PendingOrder.RETREAT:
		execute_order_for_target(null)

func _on_btn_target_pressed() -> void:
	if ui_state == UIState.IDLE:
		enter_pick_hunter_mode(PendingOrder.TARGET)
	elif ui_state == UIState.PICK_HUNTER and pending_order == PendingOrder.TARGET:
		pending_hunter = null
		clear_hunter_preview()
		enter_pick_monster_mode()

func _on_hunter_portrait_clicked(hunter: Hunter) -> void:
	if not is_instance_valid(hunter):
		return
	if ui_state == UIState.IDLE:
		focus_camera_on_x(hunter.global_position.x)
		return
	if ui_state == UIState.PICK_HUNTER:
		if hunter.current_state == Hunter.State.FAINTED:
			return
		if previewed_hunter != hunter:
			set_hunter_preview(hunter)
			focus_camera_on_x(hunter.global_position.x)
		else:
			clear_hunter_preview()
			if pending_order == PendingOrder.TARGET:
				pending_hunter = hunter
				enter_pick_monster_mode()
			else:
				execute_order_for_target(hunter)

func _on_monster_card_clicked(monster: Monster) -> void:
	if not is_instance_valid(monster):
		return
	if ui_state == UIState.IDLE:
		focus_camera_on_x(monster.global_position.x)
		return
	if ui_state == UIState.PICK_MONSTER:
		if previewed_monster != monster:
			set_monster_preview(monster)
			focus_camera_on_x(monster.global_position.x)
		else:
			clear_monster_preview()
			execute_order_for_target(pending_hunter, monster)

func _on_skill_button_clicked(hunter: Hunter) -> void:
	if ui_state != UIState.IDLE:
		return # Cannot cast skills while selecting tactical orders
	trigger_hunter_skill(hunter)

func enter_pick_hunter_mode(order: PendingOrder) -> void:
	ui_state = UIState.PICK_HUNTER
	pending_order = order
	pending_hunter = null
	clear_hunter_preview()
	clear_monster_preview()
	
	Engine.time_scale = 0.2
	is_dragging_camera = false
	
	world_dark_overlay.visible = true
	input_blocker.visible = true
	
	top_left_hud.modulate = BRIGHT_COLOR
	top_right_hud.modulate = DIMMED_COLOR
	bottom_right_hud.modulate = DIMMED_COLOR
	
	btn_cancel.visible = true
	btn_cancel.modulate = BRIGHT_COLOR
	
	btn_offense.disabled = (order != PendingOrder.OFFENSE)
	btn_retreat.disabled = (order != PendingOrder.RETREAT)
	btn_target.disabled = (order != PendingOrder.TARGET)
	
	btn_offense.modulate = BRIGHT_COLOR if order == PendingOrder.OFFENSE else DIMMED_COLOR
	btn_retreat.modulate = BRIGHT_COLOR if order == PendingOrder.RETREAT else DIMMED_COLOR
	btn_target.modulate = BRIGHT_COLOR if order == PendingOrder.TARGET else DIMMED_COLOR
	
	match order:
		PendingOrder.OFFENSE: btn_offense.text = "⚔️ EVERYONE"
		PendingOrder.RETREAT: btn_retreat.text = "🛡️ EVERYONE"
		PendingOrder.TARGET:  btn_target.text = "🎯 EVERYONE"

func enter_pick_monster_mode() -> void:
	ui_state = UIState.PICK_MONSTER
	clear_monster_preview()
	
	top_left_hud.modulate = DIMMED_COLOR
	top_right_hud.modulate = BRIGHT_COLOR
	
	btn_target.disabled = true
	btn_target.modulate = DIMMED_COLOR
	btn_target.text = "🎯 TARGET"

func execute_order_for_target(target_hunter: Hunter, target_monster: Monster = null) -> void:
	match pending_order:
		PendingOrder.OFFENSE:
			if target_hunter != null:
				if target_hunter.current_state != Hunter.State.FAINTED:
					target_hunter.order_offensive()
			else:
				for h in active_hunters:
					if h.current_state != Hunter.State.FAINTED:
						h.order_offensive()
		PendingOrder.RETREAT:
			if target_hunter != null:
				if target_hunter.current_state != Hunter.State.FAINTED:
					target_hunter.order_retreat()
			else:
				for h in active_hunters:
					if h.current_state != Hunter.State.FAINTED:
						h.order_retreat()
		PendingOrder.TARGET:
			if is_instance_valid(target_monster):
				if target_hunter != null:
					if target_hunter.current_state != Hunter.State.FAINTED:
						target_hunter.order_focus(target_monster)
				else:
					for h in active_hunters:
						if h.current_state != Hunter.State.FAINTED:
							h.order_focus(target_monster)
	reset_ui_to_idle()

func cancel_command_mode() -> void:
	reset_ui_to_idle()

func reset_ui_to_idle() -> void:
	ui_state = UIState.IDLE
	pending_order = PendingOrder.NONE
	pending_hunter = null
	clear_hunter_preview()
	clear_monster_preview()
	
	Engine.time_scale = 1.0
	world_dark_overlay.visible = false
	input_blocker.visible = false
	
	top_left_hud.modulate = BRIGHT_COLOR
	top_right_hud.modulate = BRIGHT_COLOR
	bottom_right_hud.modulate = BRIGHT_COLOR
	
	btn_cancel.visible = false
	btn_offense.disabled = false
	btn_retreat.disabled = false
	btn_target.disabled = false
	
	btn_offense.modulate = BRIGHT_COLOR
	btn_retreat.modulate = BRIGHT_COLOR
	btn_target.modulate = BRIGHT_COLOR
	
	btn_offense.text = "⚔️ OFFENSE"
	btn_retreat.text = "🛡️ RETREAT"
	btn_target.text = "🎯 TARGET"

# ==============================================================================
# PREVIEW HIGHLIGHTS
# ==============================================================================

func set_hunter_preview(hunter: Hunter) -> void:
	clear_hunter_preview()
	previewed_hunter = hunter
	if is_instance_valid(previewed_hunter):
		previewed_hunter.set_highlight(true)
	for p in active_portraits:
		p.set_preview_selected(p.target_hunter == hunter)

func clear_hunter_preview() -> void:
	if is_instance_valid(previewed_hunter):
		previewed_hunter.set_highlight(false)
	previewed_hunter = null
	for p in active_portraits:
		p.set_preview_selected(false)

func set_monster_preview(monster: Monster) -> void:
	clear_monster_preview()
	previewed_monster = monster
	if is_instance_valid(previewed_monster):
		previewed_monster.set_highlight(true)
	for card in active_monster_cards:
		if is_instance_valid(card):
			card.set_preview_selected(card.target_monster == monster)

func clear_monster_preview() -> void:
	if is_instance_valid(previewed_monster):
		previewed_monster.set_highlight(false)
	previewed_monster = null
	for card in active_monster_cards:
		if is_instance_valid(card):
			card.set_preview_selected(false)

func _on_hunter_portrait_hovered(hunter: Hunter) -> void:
	if ui_state == UIState.PICK_MONSTER:
		return
	if is_instance_valid(hunter):
		hunter.set_highlight(true)

func _on_hunter_portrait_unhovered(hunter: Hunter) -> void:
	if is_instance_valid(hunter) and hunter != previewed_hunter:
		hunter.set_highlight(false)

func _on_monster_card_hovered(monster: Monster) -> void:
	if ui_state == UIState.PICK_HUNTER:
		return
	if is_instance_valid(monster):
		monster.set_highlight(true)

func _on_monster_card_unhovered(monster: Monster) -> void:
	if is_instance_valid(monster) and monster != previewed_monster:
		monster.set_highlight(false)

# ==============================================================================
# CAMERA CONTROLS
# ==============================================================================

func get_half_visible_world_width() -> float:
	var screen_width: float = get_viewport_rect().size.x
	return screen_width / (2.0 * camera.zoom.x)

func is_drag_button(button_index: int) -> bool:
	return button_index == MOUSE_BUTTON_LEFT or button_index == MOUSE_BUTTON_RIGHT or button_index == MOUSE_BUTTON_MIDDLE

func is_any_drag_button_held() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.is_pressed():
		if is_drag_button(event.button_index):
			is_dragging_camera = false
	elif event is InputEventMouseMotion and is_dragging_camera:
		if not is_any_drag_button_held():
			is_dragging_camera = false
			return
		var mouse_delta: Vector2 = event.position - drag_start_mouse_pos
		var target_cam_x: float = drag_start_camera_pos.x - (mouse_delta.x / camera.zoom.x)
		var half_width: float = get_half_visible_world_width()
		camera.position.x = clampf(target_cam_x, half_width, max(half_width, lane_total_width - half_width))
	elif event is InputEventKey and event.is_pressed() and event.keycode == KEY_ESCAPE:
		if ui_state != UIState.IDLE:
			cancel_command_mode()

func _unhandled_input(event: InputEvent) -> void:
	if ui_state != UIState.IDLE:
		return
	if event is InputEventMouseButton and event.is_pressed():
		if is_drag_button(event.button_index):
			is_dragging_camera = true
			drag_start_mouse_pos = event.position
			drag_start_camera_pos = camera.position
			if camera_focus_tween and camera_focus_tween.is_valid():
				camera_focus_tween.kill()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_Q:
			trigger_hunter_skill_by_index(0)

func trigger_hunter_skill(hunter: Hunter) -> bool:
	if ui_state != UIState.IDLE or not is_instance_valid(hunter):
		return false
	return hunter.use_active_skill()

func trigger_hunter_skill_by_index(index: int) -> bool:
	if index >= 0 and index < active_hunters.size():
		return trigger_hunter_skill(active_hunters[index])
	return false

# ==============================================================================
# MONSTER HUD MANAGEMENT, SORTING & BADGES
# ==============================================================================

func register_monster(monster: Monster) -> void:
	if not monster_card_scene or not monster_cards_container:
		return
	var card: MonsterCard = monster_card_scene.instantiate()
	monster_cards_container.add_child(card)
	card.setup(monster)
	
	card.card_hovered.connect(_on_monster_card_hovered)
	card.card_unhovered.connect(_on_monster_card_unhovered)
	card.card_clicked.connect(_on_monster_card_clicked)
	
	active_monster_cards.append(card)
	monster.died.connect(func(_m): active_monster_cards.erase(card))

func sort_monster_cards_by_distance() -> void:
	active_monster_cards = active_monster_cards.filter(func(c): return is_instance_valid(c) and is_instance_valid(c.target_monster))
	if active_monster_cards.size() <= 1:
		return
	active_monster_cards.sort_custom(func(a: MonsterCard, b: MonsterCard) -> bool:
		return a.target_monster.global_position.x < b.target_monster.global_position.x
	)
	for i in range(active_monster_cards.size()):
		var card: MonsterCard = active_monster_cards[i]
		if card.get_index() != i:
			monster_cards_container.move_child(card, i)

func refresh_all_target_badges() -> void:
	for card in active_monster_cards:
		if not is_instance_valid(card) or not is_instance_valid(card.target_monster):
			continue
		var focusing_hunters: Array[Hunter] = []
		for h in active_hunters:
			if is_instance_valid(h) and h.current_command == Hunter.CommandState.FOCUS and h.focus_target == card.target_monster:
				focusing_hunters.append(h)
		card.update_target_badges(focusing_hunters)

func focus_camera_on_x(target_x: float) -> void:
	if is_dragging_camera:
		return
	var half_width: float = get_half_visible_world_width()
	var clamped_x: float = clampf(target_x, half_width, max(half_width, lane_total_width - half_width))
	
	if camera_focus_tween and camera_focus_tween.is_valid():
		camera_focus_tween.kill()
		
	camera_focus_tween = create_tween()
	camera_focus_tween.set_ignore_time_scale(true)
	camera_focus_tween.tween_property(camera, "position:x", clamped_x, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_damage_text_requested(world_pos: Vector2, damage_info: Dictionary) -> void:
	if not floating_text_scene:
		return
	var text_node: FloatingText = floating_text_scene.instantiate()
	add_child(text_node)
	text_node.global_position = world_pos
	text_node.setup_and_play(damage_info)
