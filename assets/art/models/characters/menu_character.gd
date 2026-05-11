extends CharacterBody3D

signal goodbye_finished

const ANIMATION_GOODBYE := "Goodbye"
const ANIMATION_IDLE_TO_SITTING := "IdleToSitting"
const ANIMATION_LEG_SWINGING := "LegSwinging"
const ANIMATION_SITTING_TO_STANDING := "SittingToStanding"
const STATE_GOODBYE := "Goodbye"
const STATE_SITTING_TO_STANDING := "SittingToStanding"
const STATE_IDLE := "Idle"
const PARAM_STANDING := "parameters/conditions/standing"
const PARAM_NOT_STANDING := "parameters/conditions/not_standing"
const PARAM_GOODBYE := "parameters/conditions/goodbye"
const GOODBYE_FINISH_PADDING := 0.02
const IDLE_TO_SITTING_SPEED_SCALE := 1.3
const LEG_SWINGING_SPEED_SCALE := 1.7
const SITTING_TO_STANDING_SPEED_SCALE := 1.8
const PREPARED_SPEED_SCALE_META := &"prepared_speed_scale"

@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer
@onready var animation_tree: AnimationTree = $Model/AnimationPlayer/AnimationTree

var _standing: bool = false
var _goodbye_in_progress: bool = false
var _playback: AnimationNodeStateMachinePlayback

var standing: bool:
	get:
		return _standing
	set(value):
		_standing = value


func _ready() -> void:
	animation_tree.active = true
	_playback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	_retime_animation(ANIMATION_IDLE_TO_SITTING, IDLE_TO_SITTING_SPEED_SCALE)
	_retime_animation(ANIMATION_LEG_SWINGING, LEG_SWINGING_SPEED_SCALE)
	_retime_animation(ANIMATION_SITTING_TO_STANDING, SITTING_TO_STANDING_SPEED_SCALE)
	_sync_standing_conditions()
	_set_condition(PARAM_GOODBYE, false)


func set_standing(value: bool) -> void:
	standing = value
	_sync_standing_conditions()


func stand_up_and_wait() -> void:
	set_standing(true)

	if _playback == null:
		return

	var current_state := StringName(_playback.get_current_node())
	if current_state != STATE_SITTING_TO_STANDING and current_state != STATE_IDLE:
		await _wait_for_state(STATE_SITTING_TO_STANDING)

	await _wait_for_state(STATE_IDLE)


func play_goodbye() -> void:
	if _goodbye_in_progress:
		return

	_goodbye_in_progress = true
	_set_condition(PARAM_GOODBYE, true)

	if animation_player.has_animation(ANIMATION_GOODBYE) and _playback != null:
		await _wait_for_state(STATE_GOODBYE)
		var goodbye_animation: Animation = animation_player.get_animation(ANIMATION_GOODBYE)
		if goodbye_animation != null:
			await get_tree().create_timer(goodbye_animation.length + GOODBYE_FINISH_PADDING).timeout
	else:
		push_warning("Menu character is missing the 'Goodbye' animation. Closing without a wave.")

	_set_condition(PARAM_GOODBYE, false)
	goodbye_finished.emit()


func _set_condition(parameter_path: String, value: Variant) -> void:
	if animation_tree == null:
		return

	animation_tree.set(parameter_path, value)


func _sync_standing_conditions() -> void:
	_set_condition(PARAM_STANDING, standing)
	_set_condition(PARAM_NOT_STANDING, not standing)


func _retime_animation(animation_name: StringName, speed_scale: float) -> void:
	var library: AnimationLibrary = animation_player.get_animation_library("")
	if library == null:
		return

	var animation_key := StringName(animation_name)
	var source_animation: Animation = library.get_animation(animation_key)
	if source_animation == null:
		return

	if source_animation.has_meta(PREPARED_SPEED_SCALE_META):
		return

	var animation: Animation = source_animation.duplicate(true) as Animation
	if animation == null:
		return

	for track_index in animation.get_track_count():
		var key_count := animation.track_get_key_count(track_index)
		for key_index in key_count:
			var key_time := animation.track_get_key_time(track_index, key_index)
			animation.track_set_key_time(track_index, key_index, key_time / speed_scale)

	animation.length = source_animation.length / speed_scale
	animation.set_meta(PREPARED_SPEED_SCALE_META, speed_scale)
	library.remove_animation(animation_key)
	library.add_animation(animation_key, animation)


func _wait_for_state(state_name: StringName) -> void:
	while _playback != null and StringName(_playback.get_current_node()) != state_name:
		await get_tree().process_frame
