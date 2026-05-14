extends CanvasLayer

class_name LapCountdownUi

const COUNTDOWN_STEPS := [
	{"text": "3", "hold": 0.0},
	{"text": "2", "hold": 0.0},
	{"text": "1", "hold": 0.0},
	{"text": "GO", "hold": 0.8},
]
const BASE_SCALE := Vector2(0.68, 0.68)
const IMPACT_SCALE := Vector2(1.26, 1.26)
const STEP_DURATION := 0.58
const STEP_GAP := 0.05
const GO_FADE_DURATION := 0.34

@onready var message_label: Label = $MarginContainer/MessageLabel


func _ready() -> void:
	layer = 120
	visible = false
	if message_label != null:
		message_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
		message_label.scale = BASE_SCALE


func play_countdown() -> void:
	visible = true
	for step in COUNTDOWN_STEPS:
		await _play_step(String(step["text"]), float(step["hold"]))

	visible = false


func _play_step(text: String, hold_duration: float) -> void:
	if message_label == null:
		return

	message_label.text = text
	message_label.scale = BASE_SCALE
	message_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.set_parallel(true)
	tween.tween_property(message_label, "scale", IMPACT_SCALE, STEP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold_duration > 0.0:
		tween.tween_property(message_label, "modulate:a", 0.0, GO_FADE_DURATION).set_delay(STEP_DURATION + hold_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(message_label, "modulate:a", 0.0, STEP_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished

	if STEP_GAP > 0.0:
		await get_tree().create_timer(STEP_GAP).timeout
