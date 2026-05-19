extends Node3D

const MAIN_MENU_SCENE_PATH := "res://assets/scenes/menu/menu_main.tscn"

@export var pause_menu_path: NodePath = ^"PauseMenu"

var _pause_menu: Node
var _pause_active := false


func _ready() -> void:
	_pause_menu = get_node_or_null(pause_menu_path)
	_configure_pause_menu()


func _unhandled_input(event: InputEvent) -> void:
	if _is_scene_transition_active():
		return

	if _pause_active:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_pause_menu()


func _configure_pause_menu() -> void:
	if _pause_menu == null:
		return

	var pause_menu_root := _pause_menu.get_node_or_null("MenuRoot") as Control
	if pause_menu_root != null:
		pause_menu_root.visible = false
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	if _pause_menu.has_signal("resume_requested"):
		_pause_menu.connect("resume_requested", Callable(self, "_resume_from_pause"))
	if _pause_menu.has_signal("main_menu_requested"):
		_pause_menu.connect("main_menu_requested", Callable(self, "_return_to_main_menu"))
	if _pause_menu.has_signal("quit_requested"):
		_pause_menu.connect("quit_requested", Callable(self, "_quit_from_pause"))


func _open_pause_menu() -> void:
	if _pause_active or _pause_menu == null or _is_scene_transition_active():
		return

	_pause_active = true
	get_tree().paused = true
	_pause_menu.call("open")


func _is_scene_transition_active() -> bool:
	return SceneTransition != null and SceneTransition.has_method("is_transitioning") and bool(SceneTransition.call("is_transitioning"))


func _resume_from_pause() -> void:
	if not _pause_active:
		return

	get_tree().paused = false
	_pause_active = false
	if _pause_menu != null:
		_pause_menu.call("close")


func _return_to_main_menu() -> void:
	get_tree().paused = false
	_pause_active = false
	if _pause_menu != null:
		_pause_menu.call("close")
	await SceneTransition.change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _quit_from_pause() -> void:
	get_tree().paused = false
	_pause_active = false
	if _pause_menu != null:
		_pause_menu.call("close")
	get_tree().quit.call_deferred()
