extends "res://assets/scripts/npc_character.gd"

class_name RaceChallengerNpc

const LAP_SCENE_PATH := "res://assets/scenes/game/lap_track_showcase.tscn"
const START_TITLE := "start"
const POST_RACE_WIN_TITLE := "post_race_win"
const POST_RACE_LOSE_TITLE := "post_race_lose"

@export var interaction_target_path: NodePath = ^"InteractionTarget"
@export var race_dialogue_state_path: NodePath = ^"RaceDialogueState"


func get_interaction_target() -> InteractionTarget:
	return get_node_or_null(interaction_target_path) as InteractionTarget


func prepare_post_race_dialogue(result: StringName) -> InteractionTarget:
	var interaction_target := get_interaction_target()
	if interaction_target == null:
		return null

	match result:
		&"win":
			interaction_target.dialogue_start_title = POST_RACE_WIN_TITLE
		_:
			interaction_target.dialogue_start_title = POST_RACE_LOSE_TITLE

	return interaction_target


func handle_dialogue_finished(_resource: DialogueResource) -> void:
	var race_dialogue_state := get_node_or_null(race_dialogue_state_path) as RaceChallengerDialogueState
	if race_dialogue_state != null and race_dialogue_state.consume_pending_race_start():
		await _start_lap_race()
		return

	var interaction_target := get_interaction_target()
	if interaction_target != null and interaction_target.dialogue_start_title != START_TITLE:
		interaction_target.dialogue_start_title = START_TITLE


func _start_lap_race() -> void:
	var current_scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group(&"player_character") as Node3D
	if current_scene == null or player == null:
		return

	LapRaceFlow.start_race(
		String(current_scene.scene_file_path),
		player.global_transform,
		current_scene.get_path_to(self)
	)
	await SceneTransition.change_scene_to_file(LAP_SCENE_PATH)
