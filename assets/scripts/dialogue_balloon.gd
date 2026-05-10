extends CanvasLayer

signal speaker_changed(character_name: String, dialogue_line: DialogueLine)
signal response_selection_state_changed(is_active: bool)
signal pause_requested

@export var dialogue_resource: DialogueResource
@export var start_from_title: String = ""
@export var auto_start: bool = false
@export var will_block_other_input: bool = true
@export var next_action: StringName = &"dialogue_select"
@export var advance_action: StringName = &"dialogue_advance"
@export var pause_action: StringName = &"ui_cancel"
@export var skip_action: StringName = &"dialogue_advance"

@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

var temporary_game_states: Array = []
var is_waiting_for_input := false
var will_hide_balloon := false
var locals: Dictionary = {}
var _response_selection_active := false

var _locale: String = TranslationServer.get_locale()

var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			dialogue_line = null
			_lock_visual_state_for_exit()
	get:
		return dialogue_line

var mutation_cooldown: Timer = Timer.new()

@onready var balloon: Control = $Balloon
@onready var character_label: RichTextLabel = $Balloon/BottomBar/DialogueFrame/DialogueContent/CharacterLabel
@onready var dialogue_label: DialogueLabel = $Balloon/BottomBar/DialogueFrame/DialogueContent/DialogueLabel
@onready var responses_menu: DialogueResponsesMenu = $Balloon/ResponsesPanel/ResponsesMenu
@onready var progress_indicator: CanvasItem = $Balloon/BottomBar/ProgressIndicator


func _ready() -> void:
	if balloon == null or character_label == null or dialogue_label == null or responses_menu == null or progress_indicator == null:
		push_error("Dialogue balloon UI is missing required child nodes.")
		return

	balloon.hide()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)

	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)

	if auto_start:
		if not is_instance_valid(dialogue_resource):
			assert(false, DMConstants.get_error_message(DMConstants.ERR_MISSING_RESOURCE_FOR_AUTOSTART))
		start()


func _process(_delta: float) -> void:
	if is_instance_valid(dialogue_line):
		progress_indicator.visible = not dialogue_label.is_typing and dialogue_line.responses.size() == 0 and not dialogue_line.has_tag("voice")


func _unhandled_input(_event: InputEvent) -> void:
	if _event.is_action_pressed(skip_action) and dialogue_label.is_typing:
		dialogue_label.skip_typing()
		get_viewport().set_input_as_handled()
		return

	if _event.is_action_pressed(pause_action) and not dialogue_label.is_typing:
		pause_requested.emit()
		get_viewport().set_input_as_handled()
		return

	if _response_selection_active and _handle_response_navigation_input(_event):
		get_viewport().set_input_as_handled()
		return

	if will_block_other_input:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _locale != TranslationServer.get_locale() and is_instance_valid(dialogue_label):
		_locale = TranslationServer.get_locale()
		var visible_ratio: float = dialogue_label.visible_ratio
		dialogue_line = await dialogue_resource.get_next_dialogue_line(dialogue_line.id)
		if visible_ratio < 1:
			dialogue_label.skip_typing()


func start(with_dialogue_resource: DialogueResource = null, title: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	_set_response_selection_active(false)
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not title.is_empty():
		start_from_title = title
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_title, temporary_game_states)
	show()


func apply_dialogue_line() -> void:
	mutation_cooldown.stop()

	progress_indicator.hide()
	is_waiting_for_input = false
	_set_response_selection_active(false)
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = tr(dialogue_line.character, "dialogue")

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses

	balloon.show()
	will_hide_balloon = false

	speaker_changed.emit(dialogue_line.character, dialogue_line)

	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	if dialogue_line.has_tag("voice"):
		audio_stream_player.stream = load(dialogue_line.get_tag_value("voice"))
		audio_stream_player.play()
		await audio_stream_player.finished
		next(dialogue_line.next_id)
	elif dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE
		_set_response_selection_active(true)
		responses_menu.show()
	elif dialogue_line.time != "":
		var time: float = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()


func next(next_id: String) -> void:
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


func close_balloon() -> void:
	queue_free()


func _lock_visual_state_for_exit() -> void:
	is_waiting_for_input = false
	_set_response_selection_active(false)
	progress_indicator.hide()
	balloon.focus_mode = Control.FOCUS_NONE
	responses_menu.hide()


func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		balloon.hide()


func _on_mutated(mutation: Dictionary) -> void:
	if not mutation.is_inline:
		is_waiting_for_input = false
		will_hide_balloon = true
		mutation_cooldown.start(0.1)


func _on_balloon_gui_input(event: InputEvent) -> void:
	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		var skip_button_was_pressed: bool = event.is_action_pressed(skip_action)
		if mouse_was_clicked or skip_button_was_pressed:
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			return

	if event.is_action_pressed(pause_action):
		get_viewport().set_input_as_handled()
		pause_requested.emit()
		return

	if not is_waiting_for_input:
		return

	if dialogue_line.responses.size() > 0:
		return

	get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		next(dialogue_line.next_id)
	elif event.is_action_pressed(advance_action) and get_viewport().gui_get_focus_owner() == balloon:
		next(dialogue_line.next_id)


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	_set_response_selection_active(false)
	next(response.next_id)


func _set_response_selection_active(value: bool) -> void:
	if _response_selection_active == value:
		return

	_response_selection_active = value
	response_selection_state_changed.emit(value)


func _handle_response_navigation_input(event: InputEvent) -> bool:
	var items: Array = responses_menu.get_menu_items()
	if items.is_empty():
		return false

	var current_index := _get_focused_response_index(items)
	if current_index < 0:
		current_index = 0

	if event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_left"):
		items[maxi(current_index - 1, 0)].grab_focus()
		return true

	if event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_right"):
		items[mini(current_index + 1, items.size() - 1)].grab_focus()
		return true

	match _get_pressed_digit_index(event):
		0:
			return _focus_response_by_index(items, 0)
		1:
			return _focus_response_by_index(items, 1)
		2:
			return _focus_response_by_index(items, 2)
		3:
			return _focus_response_by_index(items, 3)
		4:
			return _focus_response_by_index(items, 4)
		5:
			return _focus_response_by_index(items, 5)
		6:
			return _focus_response_by_index(items, 6)
		7:
			return _focus_response_by_index(items, 7)
		8:
			return _focus_response_by_index(items, 8)

	return false


func _get_focused_response_index(items: Array) -> int:
	var focus_owner := get_viewport().gui_get_focus_owner()
	for index in items.size():
		if items[index] == focus_owner:
			return index

	return -1


func _focus_response_by_index(items: Array, index: int) -> bool:
	if index < 0 or index >= items.size():
		return false

	var item: Control = items[index]
	item.grab_focus()
	return true


func _get_pressed_digit_index(event: InputEvent) -> int:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return -1

	match event.keycode:
		KEY_1, KEY_KP_1:
			return 0
		KEY_2, KEY_KP_2:
			return 1
		KEY_3, KEY_KP_3:
			return 2
		KEY_4, KEY_KP_4:
			return 3
		KEY_5, KEY_KP_5:
			return 4
		KEY_6, KEY_KP_6:
			return 5
		KEY_7, KEY_KP_7:
			return 6
		KEY_8, KEY_KP_8:
			return 7
		KEY_9, KEY_KP_9:
			return 8

	return -1
