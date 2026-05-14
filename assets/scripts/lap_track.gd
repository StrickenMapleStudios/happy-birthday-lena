extends Node3D

class_name LapTrack

enum LaneSide {
	INNER,
	OUTER,
}

const FULL_CIRCLE := TAU

@export var curve_marker_inner_path: NodePath = ^"CurveMarkerInner"
@export var curve_marker_outer_path: NodePath = ^"CurveMarkerOuter"
@export var inner_lane_path: NodePath = ^"InnerLanePath"
@export var outer_lane_path: NodePath = ^"OuterLanePath"
@export var navigation_region_path: NodePath = ^"NavigationRegion3D"
@export var boundary_root_path: NodePath = ^"BoundaryColliders"
@export_range(16, 256, 1) var curve_point_count := 64
@export_range(16, 256, 1) var navigation_segment_count := 48
@export_range(16, 256, 1) var boundary_segment_count := 40
@export_range(0.1, 5.0, 0.05) var navigation_inner_margin := 0.45
@export_range(0.1, 5.0, 0.05) var navigation_outer_margin := 0.45
@export_range(0.1, 5.0, 0.05) var boundary_thickness := 0.8
@export_range(0.1, 8.0, 0.05) var boundary_height := 2.4
@export_range(0.0, 5.0, 0.05) var boundary_vertical_offset := 1.2
@export_range(0.1, 3.0, 0.05) var lane_height_offset := 0.0


func _ready() -> void:
	_rebuild_generated_content()


func rebuild() -> void:
	_rebuild_generated_content()


func get_lane_path(side: LaneSide) -> Path3D:
	var path_node: Node = get_node_or_null(_get_lane_path_node_path(side))
	return path_node as Path3D


func get_lane_marker(side: LaneSide) -> Marker3D:
	var marker_path: NodePath = curve_marker_inner_path if side == LaneSide.INNER else curve_marker_outer_path
	return get_node_or_null(marker_path) as Marker3D


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
	_build_navigation_mesh()
	_build_boundary_colliders()


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
		curve.add_point(_point_on_circle(radius, angle, marker.position.y + lane_height_offset))

	lane_path.curve = curve


func _build_navigation_mesh() -> void:
	var navigation_region: NavigationRegion3D = get_node_or_null(navigation_region_path) as NavigationRegion3D
	if navigation_region == null:
		return

	var inner_radius: float = get_lane_radius(LaneSide.INNER) - navigation_inner_margin
	var outer_radius: float = get_lane_radius(LaneSide.OUTER) + navigation_outer_margin
	if inner_radius <= 0.0 or outer_radius <= inner_radius:
		return

	var vertices: PackedVector3Array = PackedVector3Array()
	var polygons: Array[PackedInt32Array] = []
	var segment_count: int = max(navigation_segment_count, 3)

	for segment_index in range(segment_count):
		var angle: float = (FULL_CIRCLE * float(segment_index)) / float(segment_count)
		vertices.append(_point_on_circle(inner_radius, angle, 0.0))
		vertices.append(_point_on_circle(outer_radius, angle, 0.0))

	for segment_index in range(segment_count):
		var current_inner: int = segment_index * 2
		var current_outer: int = current_inner + 1
		var next_inner: int = int(wrapi(segment_index + 1, 0, segment_count)) * 2
		var next_outer: int = next_inner + 1
		polygons.append(PackedInt32Array([current_inner, current_outer, next_outer]))
		polygons.append(PackedInt32Array([current_inner, next_outer, next_inner]))

	var navigation_mesh: NavigationMesh = NavigationMesh.new()
	navigation_mesh.vertices = vertices
	navigation_mesh.polygons = polygons
	navigation_region.navigation_mesh = navigation_mesh


func _build_boundary_colliders() -> void:
	var boundary_root: Node3D = get_node_or_null(boundary_root_path) as Node3D
	if boundary_root == null:
		return

	for child in boundary_root.get_children():
		child.queue_free()

	var inner_boundary_radius: float = get_lane_radius(LaneSide.INNER) - navigation_inner_margin - (boundary_thickness * 0.5)
	var outer_boundary_radius: float = get_lane_radius(LaneSide.OUTER) + navigation_outer_margin + (boundary_thickness * 0.5)
	if inner_boundary_radius <= 0.0 or outer_boundary_radius <= inner_boundary_radius:
		return

	_add_boundary_ring(boundary_root, "InnerBoundary", inner_boundary_radius)
	_add_boundary_ring(boundary_root, "OuterBoundary", outer_boundary_radius)


func _add_boundary_ring(boundary_root: Node3D, ring_name: String, radius: float) -> void:
	var ring_root: Node3D = Node3D.new()
	ring_root.name = ring_name
	boundary_root.add_child(ring_root)
	if Engine.is_editor_hint():
		ring_root.owner = get_tree().edited_scene_root

	var segment_count: int = max(boundary_segment_count, 3)
	var half_arc_length: float = radius * sin(PI / float(segment_count))

	for segment_index in range(segment_count):
		var angle: float = (FULL_CIRCLE * float(segment_index)) / float(segment_count)
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "%sSegment%d" % [ring_name, segment_index]
		ring_root.add_child(body)
		if Engine.is_editor_hint():
			body.owner = ring_root.owner

		var collision_shape: CollisionShape3D = CollisionShape3D.new()
		var box_shape: BoxShape3D = BoxShape3D.new()
		box_shape.size = Vector3(boundary_thickness, boundary_height, half_arc_length * 2.2)
		collision_shape.shape = box_shape
		body.add_child(collision_shape)
		if Engine.is_editor_hint():
			collision_shape.owner = ring_root.owner

		var center: Vector3 = _point_on_circle(radius, angle, boundary_vertical_offset)
		var tangent: Vector3 = Vector3(cos(angle), 0.0, -sin(angle)).normalized()
		var radial: Vector3 = Vector3(sin(angle), 0.0, cos(angle)).normalized()
		var basis: Basis = Basis(radial, Vector3.UP, tangent)
		body.transform = Transform3D(basis.orthonormalized(), center)


func _point_on_circle(radius: float, angle: float, y: float) -> Vector3:
	return Vector3(sin(angle) * radius, y, cos(angle) * radius)


func _get_lane_path_node_path(side: LaneSide) -> NodePath:
	return inner_lane_path if side == LaneSide.INNER else outer_lane_path
