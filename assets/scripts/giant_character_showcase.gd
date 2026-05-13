extends Node3D

@export var left_giant_path: NodePath = ^"GiantCharacterLeft"
@export var right_giant_path: NodePath = ^"GiantCharacterRight"
@export var dialogue_camera_path: NodePath = ^"Camera3D"
@export var interaction_target_path: NodePath = ^"InteractionTarget"
@export var auto_trigger_path: NodePath = ^"AutoDialogueTrigger"
@export var dialogue_speaker_pivot_path: NodePath = ^"DialogueSpeakerPivot"
@export var player_dialogue_anchor_path: NodePath = ^"PlayerDialogueAnchor"
@export var interaction_prompt_anchor_path: NodePath = ^"InteractionPromptAnchor"
@export var dialogue_resource: DialogueResource
@export var dialogue_start_title := "start"
@export var dialogue_speaker_name := "Гиганты"
@export_range(0.5, 20.0, 0.1) var interaction_margin := 1.5
@export_range(0.5, 30.0, 0.1) var auto_trigger_margin := 2.0
@export_range(0.5, 20.0, 0.1) var player_anchor_margin := 3.5

var _auto_trigger_radius := 0.0
var _auto_trigger_consumed := false


func _ready() -> void:
	_configure_interaction_target()
	_fit_interaction_geometry_to_giants()


func _physics_process(_delta: float) -> void:
	if _auto_trigger_consumed or _auto_trigger_radius <= 0.0:
		return

	var player := _get_player_character()
	if player == null:
		return

	var distance_to_activation := player.global_position.distance_to(global_position)
	if distance_to_activation > _auto_trigger_radius:
		return

	var interaction_target := get_node_or_null(interaction_target_path) as InteractionTarget
	if interaction_target == null:
		return

	var current_scene := get_tree().current_scene
	if current_scene == null or not current_scene.has_method("can_start_dialogue_with_target"):
		return
	if not bool(current_scene.call("can_start_dialogue_with_target", interaction_target, true)):
		return

	_auto_trigger_consumed = true
	current_scene.call_deferred("request_dialogue_with_target", interaction_target, true)


func get_dialogue_camera_mount() -> Node3D:
	return get_node_or_null(dialogue_speaker_pivot_path) as Node3D


func get_player_dialogue_anchor() -> Node3D:
	return get_node_or_null(player_dialogue_anchor_path) as Node3D


func get_dialogue_speaker_name() -> String:
	return dialogue_speaker_name.strip_edges()


func get_dialogue_scene_camera() -> Camera3D:
	return get_node_or_null(dialogue_camera_path) as Camera3D


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
	var trigger_radius := maxf((height * 0.12) + auto_trigger_margin, interaction_radius + 0.75)
	_auto_trigger_radius = trigger_radius
	var base_y := mesh_bounds.position.y
	var activation_center := Vector3.ZERO

	var interaction_shape := _get_area_shape(interaction_target_path) as CylinderShape3D
	if interaction_shape != null:
		interaction_shape.radius = interaction_radius
		interaction_shape.height = height
		_set_area_shape_origin(interaction_target_path, Vector3(
			activation_center.x,
			base_y + (height * 0.5),
			activation_center.z
		))

	var trigger_shape := _get_area_shape(auto_trigger_path) as CylinderShape3D
	if trigger_shape != null:
		trigger_shape.radius = trigger_radius
		trigger_shape.height = height
		_set_area_shape_origin(auto_trigger_path, Vector3(
			activation_center.x,
			base_y + (height * 0.5),
			activation_center.z
		))

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

	var player_anchor := get_node_or_null(player_dialogue_anchor_path) as Node3D
	if player_anchor != null and dialogue_camera != null:
		var camera_forward := -dialogue_camera.global_transform.basis.z
		camera_forward.y = 0.0
		if camera_forward.is_zero_approx():
			camera_forward = Vector3.FORWARD
		else:
			camera_forward = camera_forward.normalized()

		var anchor_distance := interaction_radius + player_anchor_margin
		player_anchor.position = activation_center - (camera_forward * anchor_distance)


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


func _get_area_shape(area_path: NodePath) -> Shape3D:
	var area := get_node_or_null(area_path) as Area3D
	if area == null:
		return null

	var collision_shape := area.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		return null

	return collision_shape.shape


func _set_area_shape_origin(area_path: NodePath, origin: Vector3) -> void:
	var area := get_node_or_null(area_path) as Area3D
	if area == null:
		return

	var collision_shape := area.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		return

	var transform := collision_shape.transform
	transform.origin = origin
	collision_shape.transform = transform


func _get_player_character() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null

	var players := tree.get_nodes_in_group(&"player_character")
	if players.is_empty():
		return null

	return players[0] as Node3D


func _get_giants() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var left_giant := get_node_or_null(left_giant_path) as Node3D
	var right_giant := get_node_or_null(right_giant_path) as Node3D
	if left_giant != null:
		result.append(left_giant)
	if right_giant != null:
		result.append(right_giant)
	return result
