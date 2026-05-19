extends "res://assets/scripts/npc_character.gd"

class_name RaceChallengerNpc

const LAP_SCENE_PATH := "res://assets/scenes/game/lap_track_showcase.tscn"
const START_TITLE := &"start"
const POST_RACE_REWARD_PENDING_TITLE := &"post_race_win_pending_reward"
const POST_RACE_LOSE_TITLE := &"post_race_lose"
const POST_RACE_CHAIN_COMPLETE_TITLE := &"post_race_win_reward_claimed"
const POST_RACE_INTERMEDIATE_WIN_TITLE := &"post_race_win"
const DEFAULT_POST_RACE_SCENE_PATH := "res://assets/scenes/game/test_movement.tscn"

@export var interaction_target_path: NodePath = ^"InteractionTarget"
@export var race_dialogue_state_path: NodePath = ^"RaceDialogueState"
@export_file("*.tscn") var post_race_scene_path := DEFAULT_POST_RACE_SCENE_PATH
@export var race_ids: Array[StringName] = [&"first_race", &"second_race"]


func _ready() -> void:
	super._ready()
	call_deferred("_sync_idle_dialogue_title")


func get_interaction_target() -> InteractionTarget:
	return get_node_or_null(interaction_target_path) as InteractionTarget


func prepare_post_race_dialogue(result: StringName) -> InteractionTarget:
	var interaction_target := get_interaction_target()
	if interaction_target == null:
		return null

	match result:
		&"win":
			interaction_target.dialogue_start_title = _get_post_race_win_title()
		_:
			interaction_target.dialogue_start_title = POST_RACE_LOSE_TITLE

	return interaction_target


func consume_pending_race_start() -> bool:
	if not can_offer_race():
		return false

	var race_dialogue_state := get_node_or_null(race_dialogue_state_path) as RaceChallengerDialogueState
	return race_dialogue_state != null and race_dialogue_state.consume_pending_race_start()


func handle_dialogue_finished(_resource: DialogueResource) -> void:
	var interaction_target := get_interaction_target()
	if interaction_target != null:
		interaction_target.dialogue_start_title = _get_idle_dialogue_title()


func can_offer_race() -> bool:
	if GameSessionState == null:
		return not race_ids.is_empty()

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


func mark_current_race_reward_completed() -> void:
	var current_race_id := _get_current_race_id()
	if current_race_id.is_empty() or GameSessionState == null:
		return

	GameSessionState.mark_race_completed(current_race_id)
	GameSessionState.mark_race_reward_completed(current_race_id)


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
	return POST_RACE_CHAIN_COMPLETE_TITLE if not can_offer_race() else START_TITLE


func _get_post_race_win_title() -> StringName:
	var current_race_id := _get_current_race_id()
	if current_race_id.is_empty():
		return POST_RACE_CHAIN_COMPLETE_TITLE
	if not _has_uncompleted_race_after(current_race_id):
		return POST_RACE_REWARD_PENDING_TITLE
	return POST_RACE_INTERMEDIATE_WIN_TITLE


func _get_current_race_id() -> StringName:
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
	if interaction_target != null:
		interaction_target.dialogue_start_title = _get_idle_dialogue_title()
