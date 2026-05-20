extends "res://assets/scripts/camera_cutscene_target.gd"

const PLAYER_GROUP := &"player_character"

@export var torch_lights_root_path: NodePath = ^"MysteryRoom/TorchLights"
@export var trigger_root_name := ^"TorchSequenceTriggers"
@export_range(1, 8, 1) var torches_per_group := 2
@export_range(0.01, 4.0, 0.01) var pair_z_tolerance := 0.25
@export_range(1.0, 64.0, 0.1) var trigger_width := 38.0
@export_range(1.0, 16.0, 0.1) var trigger_height := 6.0
@export_range(-4.0, 8.0, 0.1) var trigger_center_y := 2.5
@export_range(0.0, 12.0, 0.1) var trigger_depth_padding := 2.0
@export var start_with_all_torches_disabled := true

var _torch_groups: Array[Array] = []
var _activated_group_count := 0


func _ready() -> void:
	_collect_torch_groups()
	if start_with_all_torches_disabled:
		_set_all_torches_enabled(false)
	_build_torch_triggers()


func _collect_torch_groups() -> void:
	_torch_groups.clear()

	var lights_root := get_node_or_null(torch_lights_root_path)
	if lights_root == null:
		return

	var torches: Array[OmniLight3D] = []
	for child in lights_root.get_children():
		if child is OmniLight3D:
			torches.append(child as OmniLight3D)

	torches.sort_custom(_sort_torches_for_pairing)

	var current_group: Array = []
	var current_group_z := 0.0
	for torch in torches:
		if current_group.is_empty():
			current_group = [torch]
			current_group_z = torch.position.z
			continue

		var is_same_pair := absf(torch.position.z - current_group_z) <= pair_z_tolerance
		if is_same_pair and current_group.size() < torches_per_group:
			current_group.append(torch)
			continue

		_torch_groups.append(current_group)
		current_group = [torch]
		current_group_z = torch.position.z

	if not current_group.is_empty():
		_torch_groups.append(current_group)


func _build_torch_triggers() -> void:
	var trigger_root := get_node_or_null(trigger_root_name) as Node3D
	if trigger_root == null:
		trigger_root = Node3D.new()
		trigger_root.name = String(trigger_root_name)
		add_child(trigger_root)

	for child in trigger_root.get_children():
		child.queue_free()

	if _torch_groups.is_empty():
		return

	var centers := _get_group_centers()
	for group_index in range(_torch_groups.size()):
		var boundaries := _get_trigger_boundaries(centers, group_index)
		var trigger := Area3D.new()
		trigger.name = "TorchTrigger%02d" % (group_index + 1)
		trigger.monitoring = true
		trigger.monitorable = false
		trigger.collision_layer = 0
		trigger.collision_mask = 1
		trigger.position = Vector3(0.0, trigger_center_y, boundaries["center_z"])

		var collision_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(trigger_width, trigger_height, boundaries["depth"])
		collision_shape.shape = box_shape
		trigger.add_child(collision_shape)

		trigger_root.add_child(trigger)
		trigger.body_entered.connect(_on_torch_trigger_body_entered.bind(group_index))


func _get_group_centers() -> Array[Vector3]:
	var centers: Array[Vector3] = []
	for torch_group in _torch_groups:
		var accumulated := Vector3.ZERO
		var count := 0
		for torch in torch_group:
			if torch is OmniLight3D:
				accumulated += (torch as OmniLight3D).position
				count += 1
		if count == 0:
			centers.append(Vector3.ZERO)
			continue
		centers.append(accumulated / float(count))
	return centers


func _get_trigger_boundaries(centers: Array[Vector3], group_index: int) -> Dictionary:
	var current_center := centers[group_index]
	var start_boundary_z := 0.0
	if group_index > 0:
		start_boundary_z = (centers[group_index - 1].z + current_center.z) * 0.5
	else:
		start_boundary_z = current_center.z + (_get_edge_spacing(centers, group_index) * 0.5)

	var end_boundary_z := 0.0
	if group_index + 1 < centers.size():
		end_boundary_z = (current_center.z + centers[group_index + 1].z) * 0.5
	else:
		end_boundary_z = current_center.z - (_get_edge_spacing(centers, group_index) * 0.5)

	var min_z := minf(start_boundary_z, end_boundary_z)
	var max_z := maxf(start_boundary_z, end_boundary_z)
	var center_z := (min_z + max_z) * 0.5
	var depth := maxf(absf(max_z - min_z) + trigger_depth_padding, 1.0)
	return {
		"center_z": center_z,
		"depth": depth,
	}


func _get_edge_spacing(centers: Array[Vector3], group_index: int) -> float:
	if centers.size() <= 1:
		return 10.0
	if group_index == 0:
		return absf(centers[0].z - centers[1].z)
	if group_index == centers.size() - 1:
		return absf(centers[group_index].z - centers[group_index - 1].z)
	return absf(centers[group_index - 1].z - centers[group_index].z)


func _on_torch_trigger_body_entered(body: Node3D, group_index: int) -> void:
	if not _is_player_body(body):
		return
	_activate_torches_up_to(group_index)


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


func _set_group_enabled(group_index: int, value: bool) -> void:
	if group_index < 0 or group_index >= _torch_groups.size():
		return
	for torch in _torch_groups[group_index]:
		if torch is OmniLight3D:
			(torch as OmniLight3D).visible = value


func _is_player_body(body: Node) -> bool:
	return body != null and body.is_in_group(PLAYER_GROUP)


func _sort_torches_for_pairing(a: OmniLight3D, b: OmniLight3D) -> bool:
	if not is_equal_approx(a.position.z, b.position.z):
		return a.position.z > b.position.z
	return a.position.x < b.position.x
