extends CanvasLayer

@onready var root: Control = $Root


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide_message()


func show_message() -> void:
	root.visible = true


func hide_message() -> void:
	root.visible = false
