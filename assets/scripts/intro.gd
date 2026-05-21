extends Control

const MENU_SCENE_PATH := "res://assets/scenes/menu/menu_main.tscn"
const HIDDEN_COLOR := Color.BLACK
const VISIBLE_COLOR := Color.WHITE

@export_multiline var line_1_text: String = "StrickenMaple Studios"
@export_multiline var line_2_text: String = "Presents"
@export_range(0, 256, 1, "or_greater") var line_1_font_size: int = 72
@export_range(0, 256, 1, "or_greater") var line_2_font_size: int = 68
@export_range(0.0, 10.0, 0.01, "or_greater") var pre_delay: float = 0.5
@export_range(0.0, 10.0, 0.01, "or_greater") var mid_delay: float = 1.1
@export_range(0.0, 10.0, 0.01, "or_greater") var post_delay: float = 1.0
@export_range(0.0, 1.0, 0.01, "or_greater") var char_fade_duration: float = 0.045
@export_range(0.0, 5.0, 0.01, "or_greater") var menu_fade_out_duration: float = 0.75

@onready var line_1: HBoxContainer = $CenterContainer/IntroText/Line1Center/Line1
@onready var line_2: HBoxContainer = $CenterContainer/IntroText/Line2Center/Line2

var _line_1_chars: Array[Label] = []
var _line_2_chars: Array[Label] = []


func _ready() -> void:
	SceneTransition.preload_scene(MENU_SCENE_PATH)
	_line_1_chars = _build_line(line_1, line_1_text, line_1_font_size)
	_line_2_chars = _build_line(line_2, line_2_text, line_2_font_size)
	await _play_intro()
	await SceneTransition.fade_out(menu_fade_out_duration)
	await SceneTransition.change_scene_to_file_from_faded_state(MENU_SCENE_PATH)


func _play_intro() -> void:
	await get_tree().create_timer(pre_delay).timeout
	await _animate_line(_line_1_chars)
	await get_tree().create_timer(mid_delay).timeout
	await _animate_line(_line_2_chars)
	await get_tree().create_timer(post_delay).timeout


func _animate_line(char_labels: Array[Label]) -> void:
	for char_index in range(char_labels.size()):
		var tween := create_tween()
		tween.tween_method(
			_set_char_reveal.bind(char_labels[char_index]),
			0.0,
			1.0,
			char_fade_duration
		)
		await tween.finished


func _build_line(container: HBoxContainer, full_text: String, font_size: int) -> Array[Label]:
	for child in container.get_children():
		child.queue_free()

	var char_labels: Array[Label] = []
	for char_index in range(full_text.length()):
		var label := Label.new()
		label.text = full_text.substr(char_index, 1)
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", HIDDEN_COLOR)
		container.add_child(label)
		char_labels.append(label)

	return char_labels


func _set_char_reveal(reveal_progress: float, label: Label) -> void:
	label.add_theme_color_override(
		"font_color",
		HIDDEN_COLOR.lerp(VISIBLE_COLOR, clampf(reveal_progress, 0.0, 1.0))
	)
