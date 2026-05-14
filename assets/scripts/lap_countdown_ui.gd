extends CanvasLayer

class_name LapCountdownUi

signal go_released

const COUNTDOWN_STEPS := [
	{"text": "3", "hold": 0.0},
	{"text": "2", "hold": 0.0},
	{"text": "1", "hold": 0.0},
	{"text": "GO", "hold": 0.1},
]
const BASE_SCALE := Vector2(0.68, 0.68)
const IMPACT_SCALE := Vector2(1.26, 1.26)
const STEP_DURATION := 0.58
const STEP_GAP := 0.05
const GO_EXTRA_VISIBLE_TIME := 0.1
const GO_FADE_DURATION := 0.24

@onready var message_label: Label = $MarginContainer/MessageLabel


func _ready() -> void:
	layer = 120
	visible = false
	if message_label != null:
		message_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
		message_label.scale = BASE_SCALE


func play_countdown() -> void:
	visible = true
	for step_index in range(COUNTDOWN_STEPS.size()):
		var step: Dictionary = COUNTDOWN_STEPS[step_index]
		var is_go_step := step_index == COUNTDOWN_STEPS.size() - 1
		await _play_step(String(step["text"]), float(step["hold"]), is_go_step)

	visible = false


func _play_step(text: String, hold_duration: float, emit_release: bool) -> void:
	if message_label == null:
		return

	message_label.text = text
	message_label.scale = BASE_SCALE
	message_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

	var impact_tween := create_tween()
	impact_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	impact_tween.tween_property(message_label, "scale", IMPACT_SCALE, STEP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await impact_tween.finished

	if emit_release:
		go_released.emit()

	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration + GO_EXTRA_VISIBLE_TIME).timeout

	var fade_tween := create_tween()
	fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	fade_tween.tween_property(message_label, "modulate:a", 0.0, GO_FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await fade_tween.finished

	if STEP_GAP > 0.0:
		await get_tree().create_timer(STEP_GAP).timeout
