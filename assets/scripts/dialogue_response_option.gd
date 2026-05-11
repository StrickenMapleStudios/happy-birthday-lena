extends Button

class_name DialogueResponseOption

const UINavigation = preload("res://assets/scripts/ui_navigation.gd")

@onready var _text_label: Label = $Content/TextLabel
@onready var _marker: Label = $Content/Marker

var _response: DialogueResponse

var response: DialogueResponse:
	set(value):
		_response = value
		_apply_response()
	get:
		return _response


func _ready() -> void:
	focus_entered.connect(_update_visual_state)
	focus_exited.connect(_update_visual_state)
	mouse_entered.connect(_update_visual_state)
	mouse_exited.connect(_update_visual_state)
	UINavigation.bind_hover_focus_control(self)
	_apply_response()
	_update_visual_state()


func _apply_response() -> void:
	var response_text := "" if _response == null else _response.text
	text = response_text
	if _text_label != null:
		_text_label.text = response_text
	if _marker != null:
		_marker.visible = _response != null


func _update_visual_state() -> void:
	if _marker == null:
		return

	var is_active := has_focus() or is_hovered()
	_marker.add_theme_color_override(
		"font_color",
		Color(0.08, 0.07, 0.03, 1.0) if is_active else Color(0.972549, 0.972549, 0.972549, 1.0)
	)
