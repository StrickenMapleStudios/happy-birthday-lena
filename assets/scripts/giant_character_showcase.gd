extends Node3D

@export var left_giant_path: NodePath = ^"GiantCharacterLeft"
@export var right_giant_path: NodePath = ^"GiantCharacterRight"
@export var dialogue_camera_path: NodePath = ^"Camera3D"
@export var interaction_target_path: NodePath = ^"InteractionTarget"
@export var auto_trigger_path: NodePath = ^"AutoDialogueTrigger"
@export var wall_with_door_path: NodePath = ^"WallWithDoor"
@export var dialogue_speaker_pivot_path: NodePath = ^"DialogueSpeakerPivot"
@export var player_dialogue_anchor_path: NodePath = ^"PlayerDialogueAnchor"
@export var interaction_prompt_anchor_path: NodePath = ^"InteractionPromptAnchor"
@export var dialogue_resource: DialogueResource
@export var dialogue_start_title := "start"
@export var dialogue_speaker_name := "Гиганты"
@export_range(0.5, 20.0, 0.1) var interaction_margin := 1.5
@export_range(0.5, 20.0, 0.1) var player_anchor_margin := 3.5
var _interaction_radius := 0.0


func _ready() -> void:
	_configure_interaction_target()
	_fit_interaction_geometry_to_giants()

func get_dialogue_camera_mount() -> Node3D:
	return get_node_or_null(dialogue_speaker_pivot_path) as Node3D


func get_player_dialogue_anchor() -> Node3D:
	return get_node_or_null(player_dialogue_anchor_path) as Node3D


func get_dialogue_speaker_name() -> String:
	return dialogue_speaker_name.strip_edges()


func get_dialogue_scene_camera() -> Camera3D:
	return get_node_or_null(dialogue_camera_path) as Camera3D


func get_dialogue_focus_position() -> Vector3:
	return to_global(_compute_giants_midpoint_local())


func set_character_visible(value: bool) -> void:
	var left_giant := get_node_or_null(left_giant_path) as Node3D
	var right_giant := get_node_or_null(right_giant_path) as Node3D
	if left_giant != null:
		left_giant.visible = value
	if right_giant != null:
		right_giant.visible = value


func enter_dialogue_animation_mode(_is_talking: bool) -> void:
	var dialogue_camera := get_dialogue_scene_camera()
	for giant in _get_giants():
		if giant.has_method("set_dialogue_camera_target"):
			giant.call("set_dialogue_camera_target", dialogue_camera)
		if giant.has_method("enter_dialogue_animation_mode"):
			giant.call("enter_dialogue_animation_mode", true)


func exit_dialogue_animation_mode() -> void:
	for giant in _get_giants():
		if giant.has_method("set_dialogue_camera_target"):
			giant.call("set_dialogue_camera_target", null)
		if giant.has_method("exit_dialogue_animation_mode"):
			giant.call("exit_dialogue_animation_mode")


func handle_dialogue_finished(_resource: DialogueResource) -> void:
	var wall_with_door := get_node_or_null(wall_with_door_path)
	if wall_with_door != null and wall_with_door.has_method("open_doors"):
		wall_with_door.call("open_doors")


func face_towards_position(_target_position: Vector3) -> void:
	pass


func _configure_interaction_target() -> void:
	var interaction_target := get_node_or_null(interaction_target_path) as InteractionTarget
	if interaction_target == null:
		return

	interaction_target.dialogue_resource = dialogue_resource
	interaction_target.dialogue_start_title = dialogue_start_title
	interaction_target.interaction_enabled = true
	interaction_target.dialogue_variables = {
		"speaker_name": dialogue_speaker_name,
	}


func _fit_interaction_geometry_to_giants() -> void:
	var mesh_bounds := _compute_combined_mesh_bounds()
	if mesh_bounds.size == Vector3.ZERO:
		return

	var height := maxf(mesh_bounds.size.y, 4.0)
	var interaction_radius := maxf((height * 0.08) + interaction_margin, 2.25)
	_interaction_radius = interaction_radius
	var base_y := mesh_bounds.position.y
	var activation_center := Vector3.ZERO

	_configure_area(interaction_target_path, interaction_radius, height, base_y)

	var prompt_anchor := get_node_or_null(interaction_prompt_anchor_path) as Node3D
	if prompt_anchor != null:
		prompt_anchor.position = Vector3(
			activation_center.x,
			mesh_bounds.position.y + mesh_bounds.size.y * 0.72,
			activation_center.z
		)

	var speaker_pivot := get_node_or_null(dialogue_speaker_pivot_path) as Node3D
	var dialogue_camera := get_dialogue_scene_camera()
	if speaker_pivot != null and dialogue_camera != null:
		speaker_pivot.global_transform = dialogue_camera.global_transform

	_position_player_anchor()


func _compute_combined_mesh_bounds() -> AABB:
	var found_bounds := false
	var combined_bounds := AABB()

	for mesh_instance in _collect_mesh_instances():
		var mesh := mesh_instance.mesh
		if mesh == null:
			continue

		var mesh_aabb := mesh.get_aabb()
		var corners := _build_aabb_corners(mesh_aabb)
		for corner in corners:
			var local_point := to_local(mesh_instance.to_global(corner))
			if not found_bounds:
				combined_bounds = AABB(local_point, Vector3.ZERO)
				found_bounds = true
				continue

			combined_bounds = combined_bounds.expand(local_point)

	if not found_bounds:
		return AABB()

	return combined_bounds


func _collect_mesh_instances() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	var nodes := _get_giants()

	for node in nodes:
		if node == null:
			continue
		for child in node.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := child as MeshInstance3D
			if mesh_instance != null:
				result.append(mesh_instance)

	return result


func _build_aabb_corners(bounds: AABB) -> Array[Vector3]:
	var position := bounds.position
	var size := bounds.size
	return [
		position,
		position + Vector3(size.x, 0.0, 0.0),
		position + Vector3(0.0, size.y, 0.0),
		position + Vector3(0.0, 0.0, size.z),
		position + Vector3(size.x, size.y, 0.0),
		position + Vector3(size.x, 0.0, size.z),
		position + Vector3(0.0, size.y, size.z),
		position + size,
	]

func _configure_area(
	area_path: NodePath,
	radius: float,
	height: float,
	base_y: float
) -> void:
	var area := get_node_or_null(area_path) as Area3D
	if area == null:
		return

	var collision_shape := area.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		return

	var shape := collision_shape.shape as CylinderShape3D
	if shape != null:
		shape.radius = radius
		shape.height = height

	var transform := collision_shape.transform
	transform.origin = Vector3(0.0, base_y + (height * 0.5), 0.0)
	collision_shape.transform = transform


func _position_player_anchor() -> void:
	var player_anchor := get_node_or_null(player_dialogue_anchor_path) as Node3D
	if player_anchor == null or _interaction_radius <= 0.0:
		return

	var midpoint_local := _compute_giants_midpoint_local()
	var approach_direction := _get_anchor_approach_direction()
	var anchor_local := midpoint_local + (approach_direction * _interaction_radius)

	player_anchor.position = anchor_local
	player_anchor.look_at(to_global(midpoint_local), Vector3.UP, true)


func _get_anchor_approach_direction() -> Vector3:
	var dialogue_camera := get_dialogue_scene_camera()
	if dialogue_camera != null:
		var camera_forward := -dialogue_camera.global_transform.basis.z
		camera_forward.y = 0.0
		if not camera_forward.is_zero_approx():
			var local_forward := global_transform.basis.inverse() * camera_forward.normalized()
			local_forward.y = 0.0
			if not local_forward.is_zero_approx():
				return -local_forward.normalized()

	return Vector3(0.0, 0.0, 1.0)


func _compute_giants_midpoint_local() -> Vector3:
	var left_giant := get_node_or_null(left_giant_path) as Node3D
	var right_giant := get_node_or_null(right_giant_path) as Node3D
	if left_giant != null and right_giant != null:
		var midpoint := (left_giant.global_position + right_giant.global_position) * 0.5
		return to_local(midpoint)

	return Vector3.ZERO

func _get_giants() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var left_giant := get_node_or_null(left_giant_path) as Node3D
	var right_giant := get_node_or_null(right_giant_path) as Node3D
	if left_giant != null:
		result.append(left_giant)
	if right_giant != null:
		result.append(right_giant)
	return result
