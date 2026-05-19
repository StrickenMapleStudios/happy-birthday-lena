extends "res://assets/scripts/npc_character.gd"

class_name RaceChallengerNpc

const LAP_RACE_CONFIG_UTILS := preload("res://assets/scripts/lap_race_config_utils.gd")
const LAP_SCENE_PATH := "res://assets/scenes/game/lap_track_showcase.tscn"
const DEFAULT_POST_RACE_SCENE_PATH := "res://assets/scenes/game/test_movement.tscn"
const DEFAULT_RACE_CONFIG_PATH := LAP_RACE_CONFIG_UTILS.DEFAULT_RACE_CONFIG_PATH
const SPECIAL_FORM_RACE_ID := &"third_race"

@export var interaction_target_path: NodePath = ^"InteractionTarget"
@export var race_dialogue_state_path: NodePath = ^"RaceDialogueState"
@export_file("*.tscn") var post_race_scene_path := DEFAULT_POST_RACE_SCENE_PATH
@export_file("*.json") var race_config_path := DEFAULT_RACE_CONFIG_PATH
@export var special_form_node_path: NodePath = ^"ThirdRaceLightning"

var _race_ids: Array[StringName] = []
var _race_definitions: Dictionary = {}
var _dialogue_resource_cache: Dictionary = {}


func _ready() -> void:
	super._ready()
	_load_race_configuration()
	call_deferred("_sync_idle_dialogue_title")


func get_interaction_target() -> InteractionTarget:
	return get_node_or_null(interaction_target_path) as InteractionTarget


func prepare_post_race_dialogue(result: StringName) -> InteractionTarget:
	var interaction_target := get_interaction_target()
	if interaction_target == null:
		return null

	_apply_dialogue_resource_for_race(interaction_target, _get_current_race_definition())
	match result:
		&"win":
			interaction_target.dialogue_start_title = _get_post_race_win_title()
		_:
			interaction_target.dialogue_start_title = _get_post_race_lose_title()

	return interaction_target


func consume_pending_race_start() -> bool:
	if not can_offer_race():
		return false

	var race_dialogue_state := get_node_or_null(race_dialogue_state_path) as RaceChallengerDialogueState
	return race_dialogue_state != null and race_dialogue_state.consume_pending_race_start()


func handle_dialogue_finished(_resource: DialogueResource) -> void:
	_sync_idle_dialogue_title()


func can_offer_race() -> bool:
	if GameSessionState == null:
		return not _get_configured_race_ids().is_empty()

	return not _get_current_race_id().is_empty()


func should_grant_reward_for_result(result: StringName) -> bool:
	if result != &"win":
		return false

	var current_race_id := _get_current_race_id()
	return not current_race_id.is_empty() and not _has_uncompleted_race_after(current_race_id)


func mark_current_race_completed() -> void:
	var current_race_id := _get_current_race_id()
	if current_race_id.is_empty() or GameSessionState == null:
		return

	GameSessionState.mark_race_completed(current_race_id)
	_sync_idle_dialogue_title()


func mark_current_race_reward_completed() -> void:
	var current_race_id := _get_current_race_id()
	if current_race_id.is_empty() or GameSessionState == null:
		return

	GameSessionState.mark_race_completed(current_race_id)
	GameSessionState.mark_race_reward_completed(current_race_id)
	_sync_idle_dialogue_title()


func start_race_transition() -> void:
	await _start_lap_race()


func _start_lap_race() -> void:
	var current_scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group(&"player_character") as Node3D
	var current_race_id := _get_current_race_id()
	if current_scene == null or player == null or current_race_id.is_empty():
		return

	LapRaceFlow.start_race(
		post_race_scene_path if not post_race_scene_path.is_empty() else String(current_scene.scene_file_path),
		player.global_transform,
		current_scene.get_path_to(self),
		current_race_id
	)
	await SceneTransition.change_scene_to_file_from_faded_state(LAP_SCENE_PATH)


func _get_idle_dialogue_title() -> StringName:
	if not can_offer_race():
		return _get_chain_complete_title()

	var current_race_definition := _get_current_race_definition()
	var start_title := StringName(
		current_race_definition.get("start_title", LAP_RACE_CONFIG_UTILS.DEFAULT_START_TITLE)
	)
	return start_title if not start_title.is_empty() else LAP_RACE_CONFIG_UTILS.DEFAULT_START_TITLE


func _get_post_race_win_title() -> StringName:
	var current_race_definition := _get_current_race_definition()
	if current_race_definition.is_empty():
		return _get_chain_complete_title()

	var win_title := StringName(
		current_race_definition.get("win_title", LAP_RACE_CONFIG_UTILS.DEFAULT_WIN_TITLE)
	)
	return win_title if not win_title.is_empty() else LAP_RACE_CONFIG_UTILS.DEFAULT_WIN_TITLE


func _get_post_race_lose_title() -> StringName:
	var current_race_definition := _get_current_race_definition()
	if current_race_definition.is_empty():
		return LAP_RACE_CONFIG_UTILS.DEFAULT_LOSE_TITLE

	var lose_title := StringName(
		current_race_definition.get("lose_title", LAP_RACE_CONFIG_UTILS.DEFAULT_LOSE_TITLE)
	)
	return lose_title if not lose_title.is_empty() else LAP_RACE_CONFIG_UTILS.DEFAULT_LOSE_TITLE


func _get_current_race_id() -> StringName:
	var race_ids := _get_configured_race_ids()
	if race_ids.is_empty():
		return &""
	if GameSessionState == null:
		return race_ids[0]

	for configured_race_id in race_ids:
		if configured_race_id.is_empty():
			continue
		if not GameSessionState.is_race_completed(configured_race_id):
			return configured_race_id

	return &""


func _has_uncompleted_race_after(current_race_id: StringName) -> bool:
	var race_ids := _get_configured_race_ids()
	if race_ids.is_empty():
		return false
	if GameSessionState == null:
		return race_ids.size() > 1
	if current_race_id.is_empty():
		return false

	var found_current := false
	for configured_race_id in race_ids:
		if configured_race_id == current_race_id:
			found_current = true
			continue
		if not found_current or configured_race_id.is_empty():
			continue
		if not GameSessionState.is_race_completed(configured_race_id):
			return true

	return false


func _sync_idle_dialogue_title() -> void:
	var interaction_target := get_interaction_target()
	if interaction_target == null:
		return

	var current_race_definition := _get_current_race_definition()
	if current_race_definition.is_empty():
		_apply_dialogue_resource_for_race(interaction_target, _get_last_race_definition())
	else:
		_apply_dialogue_resource_for_race(interaction_target, current_race_definition)
	interaction_target.dialogue_start_title = _get_idle_dialogue_title()
	_sync_special_form_visual()


func get_current_race_id() -> StringName:
	return _get_current_race_id()


func _load_race_configuration() -> void:
	_race_ids.clear()
	_race_definitions.clear()
	for race_definition in LAP_RACE_CONFIG_UTILS.load_race_definitions(race_config_path):
		var race_id := StringName(race_definition.get("race_id", &""))
		if race_id.is_empty():
			continue
		_race_ids.append(race_id)
		_race_definitions[String(race_id)] = race_definition


func _get_configured_race_ids() -> Array[StringName]:
	if not _race_ids.is_empty():
		return _race_ids
	return [&"first_race", &"second_race", &"third_race"]


func _get_current_race_definition() -> Dictionary:
	var current_race_id := _get_current_race_id()
	if current_race_id.is_empty():
		return {}
	return _race_definitions.get(String(current_race_id), {})


func _get_last_race_definition() -> Dictionary:
	var race_ids := _get_configured_race_ids()
	if race_ids.is_empty():
		return {}
	return _race_definitions.get(String(race_ids[race_ids.size() - 1]), {})


func _get_chain_complete_title() -> StringName:
	var last_race_definition := _get_last_race_definition()
	var completed_title := StringName(
		last_race_definition.get(
			"completed_title",
			LAP_RACE_CONFIG_UTILS.DEFAULT_COMPLETED_TITLE
		)
	)
	return completed_title if not completed_title.is_empty() else LAP_RACE_CONFIG_UTILS.DEFAULT_COMPLETED_TITLE


func _apply_dialogue_resource_for_race(interaction_target: InteractionTarget, race_definition: Dictionary) -> void:
	if interaction_target == null:
		return

	var dialogue_resource_path := String(
		race_definition.get("dialogue_resource_path", LAP_RACE_CONFIG_UTILS.DEFAULT_DIALOGUE_RESOURCE_PATH)
	).strip_edges()
	if dialogue_resource_path.is_empty():
		dialogue_resource_path = LAP_RACE_CONFIG_UTILS.DEFAULT_DIALOGUE_RESOURCE_PATH

	var dialogue_resource := _load_dialogue_resource(dialogue_resource_path)
	if dialogue_resource != null:
		interaction_target.dialogue_resource = dialogue_resource


func _load_dialogue_resource(resource_path: String) -> DialogueResource:
	if resource_path.is_empty():
		return null
	if _dialogue_resource_cache.has(resource_path):
		return _dialogue_resource_cache[resource_path] as DialogueResource

	var resource := load(resource_path) as DialogueResource
	if resource != null:
		_dialogue_resource_cache[resource_path] = resource
	return resource


func _sync_special_form_visual() -> void:
	var special_form_node := get_node_or_null(special_form_node_path) as Node3D
	if special_form_node == null:
		return

	special_form_node.visible = can_offer_race() and _get_current_race_id() == SPECIAL_FORM_RACE_ID
