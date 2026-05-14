@tool
extends Marker3D

class_name RewardMarker

const PICKUP_ITEM_SCENE := preload("res://assets/scenes/common/pickup_item.tscn")

@export var marker_id := &""
@export var spawn_reward_on_ready := false

@onready var helper_mesh: MeshInstance3D = $HelperMesh

var _spawned_reward: PickupItem


func _ready() -> void:
	add_to_group(&"reward_markers")
	if helper_mesh != null:
		helper_mesh.visible = Engine.is_editor_hint()


func has_reward_instance() -> bool:
	return _spawned_reward != null and is_instance_valid(_spawned_reward)


func spawn_reward(item_data: InventoryItemData, quantity: int = 1, play_reveal: bool = true) -> PickupItem:
	if item_data == null:
		return null
	if has_reward_instance():
		return _spawned_reward

	var pickup := PICKUP_ITEM_SCENE.instantiate() as PickupItem
	if pickup == null:
		return null

	add_child(pickup)
	pickup.owner = owner
	pickup.position = Vector3.ZERO
	pickup.item_data = item_data
	pickup.quantity = max(quantity, 1)
	_spawned_reward = pickup
	pickup.tree_exited.connect(_on_spawned_reward_tree_exited, CONNECT_ONE_SHOT)
	if play_reveal and pickup.has_method("play_reward_reveal"):
		pickup.call_deferred("play_reward_reveal")
	return pickup


func _on_spawned_reward_tree_exited() -> void:
	_spawned_reward = null
