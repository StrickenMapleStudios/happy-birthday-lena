extends Resource

class_name LapRaceDefinition

@export var race_id := &""
@export_range(1, 12, 1) var laps_to_win := 1
@export_range(0.5, 4.0, 0.05) var npc_speed_multiplier := 1.35
