extends Node3D

const MAIN_MENU_SCENE_PATH := "res://assets/scenes/menu/menu_main.tscn"
const CREDITS_PAUSE_MENU_SCENE := preload("res://assets/scenes/ui/credits_pause_menu.tscn")
const BIRTHDAY_FINALE_OVERLAY_SCENE := preload("res://assets/scenes/ui/birthday_finale_overlay.tscn")
const CURSOR_MODE_CREDITS := Input.MOUSE_MODE_HIDDEN
const CURSOR_MODE_UI := Input.MOUSE_MODE_VISIBLE
const CREDITS_VISIBLE_SECONDS := 21.0
const CREDITS_END_FADE_OUT_DURATION := 3.0
const BIRTHDAY_FINALE_HOLD_SECONDS := 3.0
const BIRTHDAY_FINALE_POST_FADE_DELAY_SECONDS := 1.0

@onready var giant_character_showcase: Node3D = $GiantCharacterShowcase
@onready var credits_ui: ScrollingCreditsUI = $CreditsCanvas/ScrollingCreditsUI

var _credits_pause_menu: Node
var _birthday_finale_overlay: CanvasLayer
var _pause_active := false
var _transition_locked := false
var _credits_finished_requested := false
var _credits_skip_requested := false


func _ready() -> void:
	get_tree().paused = false
	_credits_pause_menu = CREDITS_PAUSE_MENU_SCENE.instantiate()
	var credits_pause_menu_root := _credits_pause_menu.get_node_or_null("MenuRoot") as Control
	if credits_pause_menu_root != null:
		credits_pause_menu_root.visible = false
	add_child(_credits_pause_menu)
	_connect_pause_menu_signals(_credits_pause_menu)
	_birthday_finale_overlay = BIRTHDAY_FINALE_OVERLAY_SCENE.instantiate() as CanvasLayer
	if _birthday_finale_overlay != null:
		add_child(_birthday_finale_overlay)
	_refresh_cursor_mode()
	call_deferred("_run_credits_sequence")


func _unhandled_input(event: InputEvent) -> void:
	if _transition_locked or _is_scene_transition_active():
		get_viewport().set_input_as_handled()
		return

	if _pause_active:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_pause_menu()


func _run_credits_sequence() -> void:
	if giant_character_showcase == null or not is_instance_valid(giant_character_showcase):
		await SceneTransition.change_scene_to_file(MAIN_MENU_SCENE_PATH)
		return

	var credits_camera := giant_character_showcase.get_node_or_null("Camera3D") as Camera3D
	if credits_camera != null:
		credits_camera.current = true

	_close_gate_for_credits()
	_start_credits_presentation()

	_credits_finished_requested = false
	_credits_skip_requested = false
	if CREDITS_VISIBLE_SECONDS <= 0.0:
		_credits_finished_requested = true
	else:
		var credits_timer := get_tree().create_timer(CREDITS_VISIBLE_SECONDS, false)
		credits_timer.timeout.connect(func() -> void: _credits_finished_requested = true, CONNECT_ONE_SHOT)

	while not _credits_skip_requested and not _credits_finished_requested:
		await get_tree().process_frame

	_transition_locked = true
	get_tree().paused = false
	_pause_active = false
	if _credits_pause_menu != null:
		_credits_pause_menu.call("close")
	await SceneTransition.fade_out(CREDITS_END_FADE_OUT_DURATION)

	_stop_credits_presentation()

	if _birthday_finale_overlay != null and _birthday_finale_overlay.has_method("show_message"):
		_birthday_finale_overlay.call("show_message")
	await get_tree().process_frame
	await SceneTransition.fade_in()
	await get_tree().create_timer(BIRTHDAY_FINALE_HOLD_SECONDS, true).timeout
	await SceneTransition.fade_out()
	if _birthday_finale_overlay != null and _birthday_finale_overlay.has_method("hide_message"):
		_birthday_finale_overlay.call("hide_message")
	await SceneTransition.hold_black_screen(BIRTHDAY_FINALE_POST_FADE_DELAY_SECONDS)
	await SceneTransition.change_scene_to_file_from_faded_state(MAIN_MENU_SCENE_PATH)


func _open_pause_menu() -> void:
	if _pause_active or _transition_locked or _credits_pause_menu == null:
		return

	_pause_active = true
	get_tree().paused = true
	_refresh_cursor_mode()
	_credits_pause_menu.call("open")


func _resume_from_pause() -> void:
	if not _pause_active:
		return

	get_tree().paused = false
	_pause_active = false
	if _credits_pause_menu != null:
		_credits_pause_menu.call("close")
	_refresh_cursor_mode()


func _skip_credits_from_pause() -> void:
	if not _pause_active:
		return

	get_tree().paused = false
	_pause_active = false
	if _credits_pause_menu != null:
		_credits_pause_menu.call("close")
	_credits_skip_requested = true
	_refresh_cursor_mode()


func _connect_pause_menu_signals(menu: Node) -> void:
	if menu == null:
		return

	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	if menu.has_signal("resume_requested"):
		menu.connect("resume_requested", Callable(self, "_resume_from_pause"))
	if menu.has_signal("skip_credits_requested"):
		menu.connect("skip_credits_requested", Callable(self, "_skip_credits_from_pause"))


func _refresh_cursor_mode() -> void:
	Input.mouse_mode = CURSOR_MODE_UI if _pause_active else CURSOR_MODE_CREDITS


func _is_scene_transition_active() -> bool:
	return SceneTransition != null and SceneTransition.has_method("is_transitioning") and bool(SceneTransition.call("is_transitioning"))


func _close_gate_for_credits() -> void:
	if giant_character_showcase == null:
		return

	var wall_with_door := giant_character_showcase.get_node_or_null("WallWithDoor")
	if wall_with_door != null and wall_with_door.has_method("close_doors_immediately"):
		wall_with_door.call("close_doors_immediately")


func _start_credits_presentation() -> void:
	if giant_character_showcase != null and giant_character_showcase.has_method("begin_credits_dance"):
		giant_character_showcase.call("begin_credits_dance")
	if credits_ui != null:
		credits_ui.start_scrolling()


func _stop_credits_presentation() -> void:
	if credits_ui != null:
		credits_ui.stop_scrolling()
	if giant_character_showcase != null and giant_character_showcase.has_method("end_credits_dance"):
		giant_character_showcase.call("end_credits_dance")
