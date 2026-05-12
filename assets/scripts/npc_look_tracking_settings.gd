extends Resource

class_name NpcLookTrackingSettings

@export var enabled := true
@export var target_group: StringName = &"player_character"
@export_range(0.5, 50.0, 0.1) var tracking_distance := 9.0
@export_range(0.5, 10.0, 0.1) var tracking_height := 3.2
@export_range(1.0, 180.0, 1.0) var horizontal_fov_degrees := 140.0
@export_range(0.1, 20.0, 0.1) var turn_speed := 4.5
@export_range(0.0, 3.0, 0.05) var target_height_offset := 1.45
@export var rig_head_bone_name: StringName = &"headPole"
