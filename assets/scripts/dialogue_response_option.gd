extends Button

class_name DialogueResponseOption

@onready var _text_label: Label = $Content/TextLabel
@onready var _marker: TextureRect = $Content/Marker

var response: DialogueResponse:
	set(value):
		response = value
		_apply_response()
	get:
		return response


func _ready() -> void:
	_apply_response()


func _apply_response() -> void:
	if _text_label == null:
		return

	_text_label.text = "" if response == null else response.text
	if _marker != null:
		_marker.visible = response != null
