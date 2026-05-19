@tool
extends Node3D

class_name LapTrack

enum LaneSide {
	INNER,
	OUTER,
}

const FULL_CIRCLE := TAU
const MARKER_HEIGHT := 0.01
const MARKER_RADIUS_PADDING := 0.02
const MARKER_ANGLE_WINDOW := 0.2
const INNER_WALL_NODE_NAME := "InnerWall"
const OUTER_WALL_NODE_NAME := "OuterWall"
const START_POINT_NODE_NAME := "StartPoint"
const TRIGGER_HELPER_MATERIAL_COLOR := Color(0.15, 0.55, 1.0, 0.28)
const CHECKPOINT_HELPER_MATERIAL_COLOR := Color(1.0, 0.25, 0.15, 0.2)

@export var lap_model_path: NodePath = ^"TrackPivot/LapModel"

@export var curve_marker_inner_path: NodePath = ^"CurveMarkerInner"
@export var curve_marker_outer_path: NodePath = ^"CurveMarkerOuter"
@export var inner_lane_path: NodePath = ^"InnerLanePath"
@export var outer_lane_path: NodePath = ^"OuterLanePath"
@export var generated_triggers_root_path: NodePath = ^"TrackPivot/LapModel/GeneratedTriggers"
@export var start_trigger_path: NodePath = ^"TrackPivot/LapModel/GeneratedTriggers/StartTrigger"
@export var checkpoint_root_path: NodePath = ^"TrackPivot/LapModel/GeneratedTriggers/CheckpointTriggers"
@export var auto_refresh_lane_markers_from_geometry := false
@export_range(16, 256, 1) var curve_point_count := 64
@export_range(0.1, 3.0, 0.05) var lane_height_offset := 0.0
@export_range(1, 8, 1) var checkpoint_count := 3
@export_range(0.5, 12.0, 0.05) var checkpoint_length := 5.0
@export_range(0.5, 8.0, 0.05) var checkpoint_height := 3.0
@export_range(0.0, 4.0, 0.05) var checkpoint_vertical_offset := 1.5
@export_range(0.0, 3.0, 0.05) var checkpoint_track_padding := 0.35
@export_range(0.5, 8.0, 0.05) var fallback_start_trigger_length := 5.5
@export_range(0.5, 8.0, 0.05) var start_trigger_height := 3.0
@export_range(0.0, 4.0, 0.05) var start_trigger_vertical_offset := 1.5
@export var auto_place_start_trigger := false
@export var show_trigger_helpers := false


func _ready() -> void:
	if Engine.is_editor_hint() and auto_refresh_lane_markers_from_geometry:
		call_deferred("_refresh_editor_geometry")
	_rebuild_generated_content()


func rebuild() -> void:
	if Engine.is_editor_hint() and auto_refresh_lane_markers_from_geometry:
		_refresh_marker_positions_from_geometry()
	_rebuild_generated_content()


func get_lane_path(side: LaneSide) -> Path3D:
	var path_node: Node = get_node_or_null(_get_lane_path_node_path(side))
	return path_node as Path3D


func get_lane_marker(side: LaneSide) -> Marker3D:
	var marker_path: NodePath = curve_marker_inner_path if side == LaneSide.INNER else curve_marker_outer_path
	return get_node_or_null(marker_path) as Marker3D


func get_start_trigger() -> Area3D:
	return get_node_or_null(start_trigger_path) as Area3D


func get_checkpoint_triggers() -> Array[Area3D]:
	var checkpoint_root: Node = get_node_or_null(checkpoint_root_path)
	if checkpoint_root == null:
		return []

	var result: Array[Area3D] = []
	for child in checkpoint_root.get_children():
		var area := child as Area3D
		if area != null:
			result.append(area)
	return result


func get_lane_radius(side: LaneSide) -> float:
	var marker: Marker3D = get_lane_marker(side)
	if marker == null:
		return 0.0
	return Vector2(marker.position.x, marker.position.z).length()


func get_lane_forward_direction(side: LaneSide, look_ahead_distance: float = 1.5) -> Vector3:
	var lane_path: Path3D = get_lane_path(side)
	if lane_path == null or lane_path.curve == null:
		return Vector3.FORWARD

	var curve: Curve3D = lane_path.curve
	var marker: Marker3D = get_lane_marker(side)
	if marker == null:
		return Vector3.FORWARD

	var lane_local_position: Vector3 = lane_path.to_local(to_global(marker.position))
	var offset: float = curve.get_closest_offset(lane_local_position)
	var baked_length: float = maxf(curve.get_baked_length(), 0.001)
	var next_offset: float = wrapf(offset + look_ahead_distance, 0.0, baked_length)
	var current_world: Vector3 = lane_path.to_global(curve.sample_baked(offset, true))
	var next_world: Vector3 = lane_path.to_global(curve.sample_baked(next_offset, true))
	var direction: Vector3 = next_world - current_world
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD


func _rebuild_generated_content() -> void:
	_build_lane_curve(LaneSide.INNER)
	_build_lane_curve(LaneSide.OUTER)
	_configure_wall_colliders()
	_rebuild_start_trigger()
	_rebuild_checkpoint_triggers()


func _build_lane_curve(side: LaneSide) -> void:
	var lane_path: Path3D = get_lane_path(side)
	var marker: Marker3D = get_lane_marker(side)
	if lane_path == null or marker == null:
		return

	var radius: float = Vector2(marker.position.x, marker.position.z).length()
	if radius <= 0.0:
		return

	var start_angle: float = atan2(marker.position.x, marker.position.z)
	var curve: Curve3D = Curve3D.new()
	curve.closed = true

	for point_index in range(max(curve_point_count, 3)):
		var t: float = float(point_index) / float(curve_point_count)
		var angle: float = start_angle + (FULL_CIRCLE * t)
		var lap_local_point := _point_on_circle(radius, angle, marker.position.y + lane_height_offset)
		var world_point := to_global(lap_local_point)
		var lane_local_point := lane_path.to_local(world_point)
		curve.add_point(lane_local_point)

	lane_path.curve = curve


func _point_on_circle(radius: float, angle: float, y: float) -> Vector3:
	return Vector3(sin(angle) * radius, y, cos(angle) * radius)


func _get_lane_path_node_path(side: LaneSide) -> NodePath:
	return inner_lane_path if side == LaneSide.INNER else outer_lane_path


func _refresh_editor_geometry() -> void:
	_refresh_marker_positions_from_geometry()
	_rebuild_generated_content()


func _refresh_marker_positions_from_geometry() -> void:
	var lap_model: Node3D = get_node_or_null(lap_model_path) as Node3D
	var inner_marker: Marker3D = get_lane_marker(LaneSide.INNER)
	var outer_marker: Marker3D = get_lane_marker(LaneSide.OUTER)
	if lap_model == null or inner_marker == null or outer_marker == null:
		return

	var radii := _estimate_track_radii(lap_model)
	if radii.is_empty():
		return

	var inner_radius: float = radii["inner"]
	var outer_radius: float = radii["outer"]
	if inner_radius <= 0.0 or outer_radius <= inner_radius:
		return

	_place_marker_on_radius(inner_marker, inner_radius)
	_place_marker_on_radius(outer_marker, outer_radius)


func _estimate_track_radii(lap_model: Node3D) -> Dictionary:
	var vertices_by_angle: Array[Dictionary] = []
	var generated_triggers_root := get_node_or_null(generated_triggers_root_path)
	for child in lap_model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		if generated_triggers_root != null and generated_triggers_root.is_ancestor_of(mesh_instance):
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface_index)
			if arrays.is_empty():
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var local_point: Vector3 = to_local(mesh_instance.to_global(vertex))
				var radius: float = Vector2(local_point.x, local_point.z).length()
				if radius > 0.001:
					vertices_by_angle.append({
						"radius": radius,
						"angle": atan2(local_point.x, local_point.z),
					})

	if vertices_by_angle.is_empty():
		return {}

	return {
		"inner": _estimate_radius_for_marker(get_lane_marker(LaneSide.INNER), vertices_by_angle, true),
		"outer": _estimate_radius_for_marker(get_lane_marker(LaneSide.OUTER), vertices_by_angle, false),
	}


func _place_marker_on_radius(marker: Marker3D, radius: float) -> void:
	var angle: float = atan2(marker.position.x, marker.position.z)
	marker.position = Vector3(
		sin(angle) * radius,
		MARKER_HEIGHT,
		cos(angle) * radius
	)


func _estimate_radius_for_marker(
	marker: Marker3D,
	vertices_by_angle: Array[Dictionary],
	is_inner: bool
) -> float:
	if marker == null:
		return 0.0

	var marker_angle: float = atan2(marker.position.x, marker.position.z)
	var matching_radii: Array[float] = []
	for vertex_data_variant in vertices_by_angle:
		var vertex_data: Dictionary = vertex_data_variant
		var vertex_angle: float = vertex_data["angle"]
		var angle_delta := absf(wrapf(vertex_angle - marker_angle + PI, 0.0, TAU) - PI)
		if angle_delta <= MARKER_ANGLE_WINDOW:
			matching_radii.append(vertex_data["radius"])

	if matching_radii.is_empty():
		for vertex_data_variant in vertices_by_angle:
			var vertex_data: Dictionary = vertex_data_variant
			matching_radii.append(vertex_data["radius"])

	matching_radii.sort()
	if is_inner:
		return maxf(matching_radii[0] + MARKER_RADIUS_PADDING, 0.01)
	return maxf(matching_radii[matching_radii.size() - 1] - MARKER_RADIUS_PADDING, 0.01)


func _configure_wall_colliders() -> void:
	var lap_model: Node3D = get_node_or_null(lap_model_path) as Node3D
	if lap_model == null:
		return

	_configure_wall_mesh(lap_model, INNER_WALL_NODE_NAME)
	_configure_wall_mesh(lap_model, OUTER_WALL_NODE_NAME)


func _configure_wall_mesh(lap_model: Node3D, wall_name: String) -> void:
	var wall_mesh := _find_named_mesh_instance(lap_model, wall_name)
	if wall_mesh == null:
		return

	wall_mesh.visible = false
	if _has_wall_collision_child(wall_mesh):
		return

	wall_mesh.create_trimesh_collision()
	var body := _find_static_body_child(wall_mesh)
	if body != null:
		body.name = "%sCollider" % wall_name


func _has_wall_collision_child(node: Node) -> bool:
	for child in node.get_children():
		var body := child as StaticBody3D
		if body == null:
			continue
		if body.get_child_count() == 0:
			continue
		var shape_node := body.get_child(0) as CollisionShape3D
		if (
			shape_node != null
			and (shape_node.shape is ConcavePolygonShape3D or shape_node.shape is ConvexPolygonShape3D)
		):
			return true
	return false


func _find_static_body_child(node: Node) -> StaticBody3D:
	for child in node.get_children():
		var body := child as StaticBody3D
		if body != null:
			return body
	return null


func _rebuild_start_trigger() -> void:
	var start_trigger: Area3D = get_node_or_null(start_trigger_path) as Area3D
	var lap_model: Node3D = get_node_or_null(lap_model_path) as Node3D
	if start_trigger == null or lap_model == null:
		return

	start_trigger.monitoring = true
	start_trigger.monitorable = false
	start_trigger.collision_layer = 0
	start_trigger.collision_mask = 1

	var collision_shape := start_trigger.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		return

	var trigger_box_shape := collision_shape.shape as BoxShape3D
	if trigger_box_shape == null:
		trigger_box_shape = BoxShape3D.new()
		collision_shape.shape = trigger_box_shape

	if auto_place_start_trigger:
		var start_mesh := _find_named_mesh_instance(lap_model, START_POINT_NODE_NAME)
		if start_mesh != null:
			_rebuild_start_trigger_from_position(start_trigger, trigger_box_shape, start_mesh.global_position)
		else:
			_rebuild_fallback_start_trigger(start_trigger, trigger_box_shape)
	else:
		trigger_box_shape.size = Vector3(fallback_start_trigger_length, start_trigger_height, 4.0)

	_ensure_trigger_helper(
		start_trigger,
		trigger_box_shape,
		"TriggerHelper",
		TRIGGER_HELPER_MATERIAL_COLOR
	)


func _rebuild_start_trigger_from_position(
	start_trigger: Area3D,
	box_shape: BoxShape3D,
	start_world_position: Vector3
) -> void:
	var inner_radius := get_lane_radius(LaneSide.INNER)
	var outer_radius := get_lane_radius(LaneSide.OUTER)
	if outer_radius <= inner_radius:
		return

	var local_start_position := to_local(start_world_position)
	var start_radius := Vector2(local_start_position.x, local_start_position.z).length()
	var angle := atan2(local_start_position.x, local_start_position.z)
	var track_width := maxf((outer_radius - inner_radius) + checkpoint_track_padding, 0.5)
	var local_trigger_position := _point_on_circle(start_radius, angle, start_trigger_vertical_offset)

	start_trigger.global_position = to_global(local_trigger_position)
	start_trigger.global_basis = global_basis * Basis.from_euler(Vector3(0.0, angle + (PI * 0.5), 0.0))
	box_shape.size = Vector3(fallback_start_trigger_length, start_trigger_height, track_width)


func _rebuild_fallback_start_trigger(start_trigger: Area3D, box_shape: BoxShape3D) -> void:
	var inner_marker := get_lane_marker(LaneSide.INNER)
	var outer_marker := get_lane_marker(LaneSide.OUTER)
	if inner_marker == null or outer_marker == null:
		return

	var inner_radius := get_lane_radius(LaneSide.INNER)
	var outer_radius := get_lane_radius(LaneSide.OUTER)
	var radius_midpoint: float = lerpf(inner_radius, outer_radius, 0.5)
	var track_width := maxf((outer_radius - inner_radius) + checkpoint_track_padding, 0.5)
	var angle := atan2(inner_marker.position.x, inner_marker.position.z)
	var local_trigger_position := _point_on_circle(radius_midpoint, angle, start_trigger_vertical_offset)
	start_trigger.global_position = to_global(local_trigger_position)
	start_trigger.global_basis = global_basis * Basis.from_euler(Vector3(0.0, angle + (PI * 0.5), 0.0))
	box_shape.size = Vector3(fallback_start_trigger_length, start_trigger_height, track_width)


func _rebuild_checkpoint_triggers() -> void:
	var checkpoint_root: Node3D = get_node_or_null(checkpoint_root_path) as Node3D
	if checkpoint_root == null:
		return

	for child in checkpoint_root.get_children():
		child.queue_free()

	var inner_marker := get_lane_marker(LaneSide.INNER)
	if inner_marker == null:
		return

	var inner_radius := get_lane_radius(LaneSide.INNER)
	var outer_radius := get_lane_radius(LaneSide.OUTER)
	if outer_radius <= inner_radius:
		return

	var radius_midpoint: float = lerpf(inner_radius, outer_radius, 0.5)
	var track_width := maxf((outer_radius - inner_radius) + checkpoint_track_padding, 0.5)
	var start_angle := atan2(inner_marker.position.x, inner_marker.position.z)
	var gate_count: int = maxi(checkpoint_count, 1)

	for checkpoint_index in range(gate_count):
		var area := Area3D.new()
		area.name = "Checkpoint%02d" % (checkpoint_index + 1)
		area.monitoring = true
		area.monitorable = false
		area.collision_layer = 0
		area.collision_mask = 1
		area.set_meta(&"checkpoint_index", checkpoint_index)

		var angle := start_angle + (FULL_CIRCLE * float(checkpoint_index + 1) / float(gate_count + 1))
		var local_checkpoint_position := _point_on_circle(radius_midpoint, angle, checkpoint_vertical_offset)

		var collision_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(checkpoint_length, checkpoint_height, track_width)
		collision_shape.shape = box_shape
		area.add_child(collision_shape)
		_ensure_trigger_helper(area, box_shape, "CheckpointHelper", CHECKPOINT_HELPER_MATERIAL_COLOR)

		checkpoint_root.add_child(area)
		area.global_position = to_global(local_checkpoint_position)
		area.global_basis = global_basis * Basis.from_euler(Vector3(0.0, angle + (PI * 0.5), 0.0))
		if Engine.is_editor_hint():
			area.owner = get_tree().edited_scene_root
			collision_shape.owner = get_tree().edited_scene_root


func _find_named_mesh_instance(root: Node, mesh_name: String) -> MeshInstance3D:
	if root == null:
		return null

	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance != null and mesh_instance.name == mesh_name:
			return mesh_instance
	return null


func _ensure_trigger_helper(
	area: Area3D,
	box_shape: BoxShape3D,
	helper_name: String,
	helper_color: Color
) -> void:
	if area == null or box_shape == null:
		return

	var helper := area.get_node_or_null(helper_name) as MeshInstance3D
	if helper == null:
		helper = MeshInstance3D.new()
		helper.name = helper_name
		area.add_child(helper)
		if Engine.is_editor_hint():
			helper.owner = get_tree().edited_scene_root

	var box_mesh := helper.mesh as BoxMesh
	if box_mesh == null:
		box_mesh = BoxMesh.new()
		helper.mesh = box_mesh

	box_mesh.size = box_shape.size
	helper.visible = show_trigger_helpers

	var material := helper.get_active_material(0) as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		helper.set_surface_override_material(0, material)

	material.albedo_color = helper_color
