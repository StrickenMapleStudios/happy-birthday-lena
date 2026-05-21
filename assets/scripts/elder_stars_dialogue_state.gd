extends Node

class_name ElderStarsDialogueState

const DIALOGUE_STATE_GROUP := &"dialogue_state_components"
const FRIEND_FOLLOWERS_GROUP := &"friendly_followers"
const CONSTELLATION_THRESHOLD := 6
const REWARD_SOURCE_ID := &"elder_constellation_reward"

var follower_count := 0
var has_presentable_followers := false
var has_not_lena := false
var has_anti_lena := false
var has_anti_not_lena := false
var has_not_anti_lena := false
var has_hiyori := false


func _ready() -> void:
	add_to_group(DIALOGUE_STATE_GROUP)
	refresh_follower_count()


func refresh_follower_count() -> void:
	follower_count = _count_followers()
	_refresh_followers_presence()


func get_dialogue_start_title() -> StringName:
	if has_claimed_reward():
		return &"reward_claimed"
	if follower_count >= CONSTELLATION_THRESHOLD:
		return &"constellation_ready"
	if follower_count >= 3:
		return &"gathering"
	if follower_count >= 1:
		return &"few_stars"
	return &"start"


func can_grant_constellation_reward() -> bool:
	return follower_count >= CONSTELLATION_THRESHOLD and not has_claimed_reward()


func has_claimed_reward() -> bool:
	if RewardService == null or not RewardService.has_method("has_completed_source"):
		return false

	return bool(RewardService.call("has_completed_source", REWARD_SOURCE_ID))


func queue_constellation_reward() -> void:
	var elder := get_parent()
	if elder != null and elder.has_method("queue_constellation_reward"):
		elder.call("queue_constellation_reward")


func _count_followers() -> int:
	var tree := get_tree()
	if tree == null:
		return 0

	var count := 0
	for actor in tree.get_nodes_in_group(FRIEND_FOLLOWERS_GROUP):
		if actor is Node3D and is_instance_valid(actor):
			count += 1

	return count


func _refresh_followers_presence() -> void:
	has_not_lena = false
	has_anti_lena = false
	has_anti_not_lena = false
	has_not_anti_lena = false
	has_hiyori = false
	has_presentable_followers = false

	var elder := get_parent()
	if elder == null or not elder.has_method("get_ordered_dialogue_followers"):
		return

	var followers: Array = elder.call("get_ordered_dialogue_followers")
	for follower_variant in followers:
		var follower := follower_variant as Node3D
		var follower_name := _get_actor_dialogue_name(follower)
		match follower_name:
			"НеЛена":
				has_not_lena = true
			"АнтиЛена":
				has_anti_lena = true
			"АнтиНеЛена":
				has_anti_not_lena = true
			"НеАнтиЛена":
				has_not_anti_lena = true
			"Хиёри":
				has_hiyori = true

	has_presentable_followers = (
		has_not_lena
		or has_anti_lena
		or has_anti_not_lena
		or has_not_anti_lena
		or has_hiyori
	)


func _get_actor_dialogue_name(actor: Node3D) -> String:
	if actor == null:
		return ""

	if actor.has_method("get_npc_dialogue_name"):
		return String(actor.call("get_npc_dialogue_name")).strip_edges()
	if actor.has_method("get_dialogue_speaker_name"):
		return String(actor.call("get_dialogue_speaker_name")).strip_edges()

	return actor.name.strip_edges()
