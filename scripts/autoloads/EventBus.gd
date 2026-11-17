extends Node

## Emitted by any entity receiving damage so CombatArena spawns the floating number
@warning_ignore("unused_signal")
signal damage_text_requested(world_position: Vector2, damage_info: Dictionary)
