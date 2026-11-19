class_name FloatingText
extends Node2D

@onready var damage_label: Label = $DamageLabel

func setup_and_play(damage_info: Dictionary) -> void:
	var custom_text: String = damage_info.get("custom_text", "")
	var phys: int = damage_info.get("physical", 0)
	var elem: int = damage_info.get("elemental", 0)
	var elem_type: String = damage_info.get("element_type", "")
	var effectiveness: String = damage_info.get("effectiveness", "normal")
	var is_crit: bool = damage_info.get("is_crit", false)
	var is_feeble: bool = damage_info.get("is_feeble", false)
	
	if custom_text != "":
		damage_label.text = custom_text
	elif elem > 0:
		var crit_mark: String = "!" if is_crit else ""
		damage_label.text = "%d%s (+%d %s)" % [phys, crit_mark, elem, elem_type]
	else:
		var crit_mark: String = "!" if is_crit else ""
		damage_label.text = "%d%s" % [phys, crit_mark]
		
	match effectiveness:
		"weak":
			damage_label.modulate = Color("#fde047") # Bright Yellow
		"resist":
			damage_label.modulate = Color("#94a3b8") # Muted Grey
		"gate_damage":
			damage_label.modulate = Color("#ef4444") # Bright Red
		"interrupted":
			damage_label.modulate = Color("#38bdf8") # Bright Cyan!
		_:
			damage_label.modulate = Color("#ffffff") # Normal White
			
	if is_feeble:
		damage_label.modulate = Color("#64748b")
		
	var peak_scale: float = 1.45 if (is_crit or custom_text != "") else 1.15
	var end_scale: float = 1.15 if (is_crit or custom_text != "") else 1.0
	
	scale = Vector2(0.4, 0.4)
	var random_offset_x: float = randf_range(-25.0, 25.0)
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(peak_scale, peak_scale), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self, "scale", Vector2(end_scale, end_scale), 0.1)
	tween.tween_property(self, "position:y", position.y - 75.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", position.x + random_offset_x, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_delay(0.4)
	
	await tween.finished
	queue_free()
