class_name FloatingText
extends Node2D

@onready var damage_label: Label = $DamageLabel

func setup_and_play(damage_info: Dictionary) -> void:
	var phys: int = damage_info.get("physical", 0)
	var elem: int = damage_info.get("elemental", 0)
	var elem_type: String = damage_info.get("element_type", "")
	var effectiveness: String = damage_info.get("effectiveness", "normal")
	
	# Format text (simple "30" now, or "125 (+45🔥)" later when elements exist!)
	if elem > 0:
		damage_label.text = "%d (+%d %s)" % [phys, elem, elem_type]
	else:
		damage_label.text = str(phys)
		
	# Color code by effectiveness (susceptible to change)
	match effectiveness:
		"weak":
			damage_label.modulate = Color("#fde047") # Bright Yellow (Weakness!)
		"resist":
			damage_label.modulate = Color("#94a3b8") # Muted Grey (Resisted)
		_:
			damage_label.modulate = Color("#ffffff") # Clean White (Normal)
			
	# Pop & Float animation
	scale = Vector2(0.4, 0.4)
	var random_offset_x: float = randf_range(-25.0, 25.0)
	
	var tween: Tween = create_tween().set_parallel(true)
	# Elastic pop-in
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Float upwards + slight horizontal drift
	tween.tween_property(self, "position:y", position.y - 75.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", position.x + random_offset_x, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Fade out near the end and self-destruct
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_delay(0.4)
	
	await tween.finished
	queue_free()
