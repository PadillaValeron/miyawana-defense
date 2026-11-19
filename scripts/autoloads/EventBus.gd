extends Node

@warning_ignore("unused_signal")
signal damage_text_requested(world_position: Vector2, damage_info: Dictionary)
@warning_ignore("unused_signal")
signal camera_shake_requested(intensity: float, duration: float)
@warning_ignore("unused_signal")
signal boss_warning_changed(monster: Node2D, is_warning: bool)
