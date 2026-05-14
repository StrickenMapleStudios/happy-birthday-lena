extends CanvasLayer

class_name LapCounterUi

@onready var counter_label: Label = $MarginContainer/CounterLabel


func _ready() -> void:
	layer = 110


func set_progress(completed_laps: int, total_laps: int) -> void:
	if counter_label == null:
		return

	counter_label.text = "%d/%d" % [completed_laps, total_laps]
	counter_label.queue_redraw()
