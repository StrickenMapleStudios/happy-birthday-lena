extends Button

class_name DialogueResponseOption

@onready var _text_label: Label = $Content/TextLabel
@onready var _marker: TextureRect = $Content/Marker

var _response: DialogueResponse

var response: DialogueResponse:
	set(value):
		_response = value
		_apply_response()
	get:
		return _response


func _ready() -> void:
	_apply_response()


func _apply_response() -> void:
	var response_text := "" if _response == null else _response.text
	text = response_text
	if _text_label != null:
		_text_label.text = response_text
	if _marker != null:
		_marker.visible = _response != null
