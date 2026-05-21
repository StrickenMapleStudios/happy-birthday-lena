extends Node

class_name ElderStarsDialogueState

const DIALOGUE_STATE_GROUP := &"dialogue_state_components"
const FRIEND_FOLLOWERS_GROUP := &"friendly_followers"
const CONSTELLATION_THRESHOLD := 6
const REWARD_SOURCE_ID := &"elder_constellation_reward"

var follower_count := 0


func _ready() -> void:
	add_to_group(DIALOGUE_STATE_GROUP)
	refresh_follower_count()


func refresh_follower_count() -> void:
	follower_count = _count_followers()


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
