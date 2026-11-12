class_name CombatArena
extends Node2D

@onready var camera: Camera2D = $Camera2D

# Arena configuration
## Total horizontal length of your battlefield lane (ColorRect)
@export var lane_total_width: float = 3000.0

# Camera dragging variables
var is_dragging_camera: bool = false
var drag_start_mouse_pos: Vector2 = Vector2.ZERO
var drag_start_camera_pos: Vector2 = Vector2.ZERO

# Director state variables
var active_hunters: Array[Hunter] = []
var selected_hunter: Hunter = null
var is_aiming_target: bool = false

# Global order cooldown (prevents spamming)
var order_cooldown_timer: float = 0.0
const ORDER_COOLDOWN_TIME: float = 0.3

# Buttons variables
@onready var offense: Button = $HUD/UIRoot/BottomLeft/HBoxContainer/Offense
@onready var retreat: Button = $HUD/UIRoot/BottomLeft/HBoxContainer/Retreat


func _ready() -> void:
	# 1. Find all hunters using the group system (clean & hierarchy-independent)
	for node in get_tree().get_nodes_in_group("hunters"):
		if node is Hunter:
			active_hunters.append(node)
			
	# 2. Connect HUD buttons safely
	active_hunters.assign(get_tree().get_nodes_in_group("hunters"))
	offense.pressed.connect(issue_squad_offensive)
	retreat.pressed.connect(issue_squad_retreat)
		
	# 3. Initialize camera starting position so it never starts showing the left void
	var half_width: float = get_half_visible_world_width()
	if camera.position.x < half_width:
		camera.position.x = half_width

func _physics_process(delta: float) -> void:
	if order_cooldown_timer > 0.0:
		order_cooldown_timer -= delta

# ==============================================================================
# DYNAMIC CAMERA CONTROLS (PANNING, DRAGGING & ZOOM LIMITS)
# ==============================================================================

## Dynamically calculates half the visible world width according to current camera zoom
func get_half_visible_world_width() -> float:
	var screen_width: float = get_viewport_rect().size.x
	return screen_width / (2.0 * camera.zoom.x)

func _unhandled_input(event: InputEvent) -> void:
	# Drag camera using RIGHT CLICK or MIDDLE CLICK (leaves left click for commands/UI)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.is_pressed():
				is_dragging_camera = true
				drag_start_mouse_pos = event.position
				drag_start_camera_pos = camera.position
			else:
				is_dragging_camera = false
				
	# Move the camera based on mouse drag motion
	elif event is InputEventMouseMotion and is_dragging_camera:
		var mouse_delta: Vector2 = event.position - drag_start_mouse_pos
		
		# Dividing by camera.zoom.x makes dragging feel 1:1 with hand movement at any zoom level!
		var target_cam_x: float = drag_start_camera_pos.x - (mouse_delta.x / camera.zoom.x)
		
		# DYNAMIC LIMITS:
		# Min limit: Left edge of screen touches X = 0 exactly
		var half_width: float = get_half_visible_world_width()
		var min_cam_x: float = half_width
		# Max limit: Right edge touches the end of the lane
		var max_cam_x: float = max(min_cam_x, lane_total_width - half_width)
		
		# CLAMP: Locks camera position strictly within bounds! Zero ghost drag.
		camera.position.x = clampf(target_cam_x, min_cam_x, max_cam_x)
		
	# Test special move for Squad Member 0 (Rathalos Hunter)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_Q:
			trigger_hunter_skill_by_index(0)

# ==============================================================================
# SQUAD ORDERS (THE CONDUCTOR)
# ==============================================================================

func issue_squad_offensive() -> void:
	if order_cooldown_timer > 0.0:
		return
	order_cooldown_timer = ORDER_COOLDOWN_TIME
	
	for hunter in active_hunters:
		# Sticky target rule: don't override hunters locked on a specific target!
		if hunter.current_command != Hunter.CommandState.FOCUS:
			hunter.order_offensive()

func issue_squad_retreat() -> void:
	if order_cooldown_timer > 0.0:
		return
	order_cooldown_timer = ORDER_COOLDOWN_TIME
	
	for hunter in active_hunters:
		# Sticky target rule: hunters locked on a target ignore retreat unless canceled!
		if hunter.current_command != Hunter.CommandState.FOCUS:
			hunter.order_retreat()

func start_target_mode() -> void:
	if order_cooldown_timer > 0.0:
		return
	
	is_aiming_target = true
	# BULLET TIME: Slow down time to 25% so player can pick target comfortably!
	Engine.time_scale = 0.25

func cancel_target_mode() -> void:
	is_aiming_target = false
	Engine.time_scale = 1.0 # Back to normal speed

func confirm_target(monster_node: Node2D) -> void:
	cancel_target_mode() # Restores normal speed
	
	if selected_hunter != null:
		# Order only the selected hunter
		selected_hunter.order_focus(monster_node)
	else:
		# Order entire squad to focus fire this monster!
		for hunter in active_hunters:
			hunter.order_focus(monster_node)
			
			
# ==============================================================================
# SPECIAL SKILLS DISPATCHER (THE CONDUCTOR)
# ==============================================================================

## Triggers the active skill of a specific hunter instance
func trigger_hunter_skill(hunter: Hunter) -> bool:
	if not is_instance_valid(hunter):
		return false
	return hunter.use_active_skill()

## Triggers the active skill by squad slot index (0 = 1st Hunter, 1 = 2nd Hunter...)
func trigger_hunter_skill_by_index(index: int) -> bool:
	if index >= 0 and index < active_hunters.size():
		return trigger_hunter_skill(active_hunters[index])
	return false
