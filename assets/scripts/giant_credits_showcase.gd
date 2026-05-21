extends Node3D

const SHOWCASE_GROUP := &"giant_credits_showcase"

@export var showcase_path: NodePath = ^"GiantCharacterShowcase"
@export var credits_camera_path: NodePath = ^"GiantCharacterShowcase/Camera3D"
@export var credits_ui_path: NodePath = ^"CreditsCanvas/ScrollingCreditsUI"
@export_range(5.0, 300.0, 1.0) var credits_duration_override := 0.0

@onready var _showcase: Node3D = get_node_or_null(showcase_path) as Node3D
@onready var _credits_ui: ScrollingCreditsUI = get_node_or_null(credits_ui_path) as ScrollingCreditsUI


func _ready() -> void:
	add_to_group(SHOWCASE_GROUP)
	_set_credits_ui_active(false)


func get_credits_camera() -> Camera3D:
	return get_node_or_null(credits_camera_path) as Camera3D


func get_credits_duration() -> float:
	if credits_duration_override > 0.0:
		return credits_duration_override

	if _credits_ui != null:
		return _credits_ui.get_estimated_scroll_duration()

	return 45.0


func begin_credits() -> void:
	_start_giants_dancing()
	_set_credits_ui_active(true)


func end_credits() -> void:
	_set_credits_ui_active(false)
	_stop_giants_dancing()


func _start_giants_dancing() -> void:
	if _showcase != null and _showcase.has_method("begin_credits_dance"):
		_showcase.call("begin_credits_dance")


func _stop_giants_dancing() -> void:
	if _showcase != null and _showcase.has_method("end_credits_dance"):
		_showcase.call("end_credits_dance")


func _set_credits_ui_active(is_active: bool) -> void:
	if _credits_ui == null:
		return

	if is_active:
		_credits_ui.start_scrolling()
	else:
		_credits_ui.stop_scrolling()
