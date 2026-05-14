extends CanvasLayer

class_name LapDebugUi

@onready var debug_label: Label = $MarginContainer/DebugLabel


func _ready() -> void:
	layer = 111


func set_lines(lines: PackedStringArray) -> void:
	if debug_label == null:
		return

	debug_label.text = "\n".join(lines)
