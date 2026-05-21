extends "res://assets/scripts/camera_cutscene_target.gd"

const PLAYER_GROUP := &"player_character"
const CAKE_DIALOGUE := preload("res://assets/dialogue/cake_conversation.dialogue")
const BRASS_KEY_ITEM_ID := &"brass_key"
const REQUIRED_KEY_COUNT := 3
const TEST_ALWAYS_PLAY_CUP_CUTSCENE := true

@export var cup_reward_presenter_path: NodePath = ^"MysteryRoom/Stand_Stairs/Stand/CupRewardPresenter"
@export var cup_cutscene_camera_path: NodePath = ^"CupCutsceneCamera"

@export var torch_lights_root_path: NodePath = ^"MysteryRoom/TorchLights"
@export var trigger_root_path: NodePath = ^"TorchSequenceTriggers"
@export_range(1, 8, 1) var torches_per_group := 2
@export_range(1, 8, 1) var initially_enabled_pairs := 1
@export_range(0.01, 2.0, 0.01) var finale_activation_delay := 0.2

var _torch_groups: Array[Array] = []
var _activated_group_count := 0
var _finale_sequence_started := false


func _ready() -> void:
	_collect_torch_groups()
	_set_initial_torch_state()
	_connect_trigger_areas()


func play_cup_reward_cutscene() -> void:
	if not _should_play_cup_cutscene():
		return

	var game := get_tree().current_scene
	if game == null or not game.has_method("run_dialogue_embedded_cutscene"):
		return

	await game.call("run_dialogue_embedded_cutscene", self)
	_mark_cup_cutscene_played()


func _should_play_cup_cutscene() -> bool:
	if TEST_ALWAYS_PLAY_CUP_CUTSCENE:
		return true
	if _has_played_cup_cutscene():
		return false
	return _has_required_keys()


func _has_played_cup_cutscene() -> bool:
	if GameSessionState == null:
		return false
	return GameSessionState.has_played_cake_cup_cutscene()


func _mark_cup_cutscene_played() -> void:
	if GameSessionState == null:
		return
	GameSessionState.mark_cake_cup_cutscene_played()


func _has_required_keys() -> bool:
	var inventory := _get_game_inventory()
	if inventory == null:
		return false
	return inventory.count_item_quantity(BRASS_KEY_ITEM_ID) >= REQUIRED_KEY_COUNT


func _get_game_inventory() -> InventoryData:
	var game := get_tree().current_scene
	if game == null or not game.has_method("get_inventory_data"):
		return null
	return game.call("get_inventory_data") as InventoryData


func get_cup_cutscene_camera() -> Camera3D:
	return get_node_or_null(cup_cutscene_camera_path) as Camera3D


func get_cup_reward_presenter() -> CupRewardPresenter:
	return get_node_or_null(cup_reward_presenter_path) as CupRewardPresenter


func _collect_torch_groups() -> void:
	_torch_groups.clear()

	var lights_root := get_node_or_null(torch_lights_root_path)
	if lights_root == null:
		return

	var torches: Array[OmniLight3D] = []
	for child in lights_root.get_children():
		if child is OmniLight3D:
			torches.append(child as OmniLight3D)

	torches.sort_custom(_sort_nodes_by_name)

	var current_group: Array = []
	for torch in torches:
		current_group.append(torch)
		if current_group.size() < torches_per_group:
			continue
		_torch_groups.append(current_group)
		current_group = []

	if not current_group.is_empty():
		_torch_groups.append(current_group)


func _on_torch_trigger_body_entered(body: Node3D, pair_index: int, trigger: Area3D) -> void:
	if not _is_player_body(body):
		return

	trigger.monitoring = false
	if pair_index < 5:
		_activate_torches_up_to(pair_index - 1)
		return

	if _finale_sequence_started:
		return

	_finale_sequence_started = true
	await _activate_finale_sequence()


func _activate_torches_up_to(group_index: int) -> void:
	var target_count := mini(group_index + 1, _torch_groups.size())
	if target_count <= _activated_group_count:
		return

	for active_index in range(_activated_group_count, target_count):
		_set_group_enabled(active_index, true)

	_activated_group_count = target_count


func _set_all_torches_enabled(value: bool) -> void:
	for group_index in range(_torch_groups.size()):
		_set_group_enabled(group_index, value)
	_activated_group_count = _torch_groups.size() if value else 0


func _set_initial_torch_state() -> void:
	_set_all_torches_enabled(false)
	var initial_count := clampi(initially_enabled_pairs, 0, _torch_groups.size())
	for group_index in range(initial_count):
		_set_group_enabled(group_index, true)
	_activated_group_count = initial_count


func _connect_trigger_areas() -> void:
	var trigger_root := get_node_or_null(trigger_root_path)
	if trigger_root == null:
		return

	for child in trigger_root.get_children():
		var trigger := child as Area3D
		if trigger == null:
			continue

		var pair_index := _extract_pair_index(trigger.name)
		if pair_index < 2:
			continue

		trigger.monitoring = true
		trigger.monitorable = false
		trigger.collision_layer = 0
		trigger.collision_mask = 1

		var callback := Callable(self, "_on_torch_trigger_body_entered").bind(pair_index, trigger)
		if not trigger.body_entered.is_connected(callback):
			trigger.body_entered.connect(callback)


func _extract_pair_index(trigger_name: String) -> int:
	var digits := ""
	for character in trigger_name:
		if character >= "0" and character <= "9":
			digits += character
	if digits.is_empty():
		return -1
	return digits.to_int()


func _activate_finale_sequence() -> void:
	for group_index in range(4, _torch_groups.size()):
		_set_group_enabled(group_index, true)
		_activated_group_count = max(_activated_group_count, group_index + 1)
		if group_index < _torch_groups.size() - 1:
			await get_tree().create_timer(finale_activation_delay).timeout


func _set_group_enabled(group_index: int, value: bool) -> void:
	if group_index < 0 or group_index >= _torch_groups.size():
		return
	for torch in _torch_groups[group_index]:
		if torch is OmniLight3D:
			(torch as OmniLight3D).visible = value


func _is_player_body(body: Node) -> bool:
	return body != null and body.is_in_group(PLAYER_GROUP)


func _sort_nodes_by_name(a: Node, b: Node) -> bool:
	return String(a.name).naturalnocasecmp_to(String(b.name)) < 0


func handle_dialogue_finished(resource: DialogueResource) -> void:
	if resource != CAKE_DIALOGUE:
		return

	var game := get_tree().current_scene
	if game == null or not game.has_method("start_giant_credits_sequence"):
		return

	game.call("start_giant_credits_sequence")
