@tool
extends Camera3D

class_name RewardDemonstrationCamera

@export var marker_id := &""
@export var enabled := true
@export_range(0.1, 10.0, 0.05) var demonstration_duration := 2.0


func _ready() -> void:
	add_to_group(&"reward_demonstration_cameras")


func matches_marker(value: StringName) -> bool:
	return enabled and not marker_id.is_empty() and marker_id == value


func get_demonstration_duration() -> float:
	return demonstration_duration
