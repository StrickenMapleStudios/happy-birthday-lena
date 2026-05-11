extends Control

class_name InventoryFrame

const OUTER_RING_COLOR := Color(0.16, 0.2, 0.22, 0.84)
const INNER_FILL_COLOR := Color(0.08, 0.11, 0.1, 0.42)
const GOLD_LINE_COLOR := Color(0.94, 0.77, 0.18, 0.7)
const GOLD_ACCENT_COLOR := Color(1.0, 0.83, 0.18, 1.0)
const TAB_FILL_COLOR := Color(0.76, 0.65, 0.16, 0.78)
const TAB_CENTER_ANGLES_DEGREES := [-130.0, -90.0, -50.0]

@export_range(0.1, 0.49, 0.01) var ring_thickness_ratio: float = 0.16
@export_range(0.1, 0.49, 0.01) var inner_gap_ratio: float = 0.08
@export_range(8.0, 45.0, 1.0) var tab_half_span_degrees: float = 18.0

var selected_tab_index: int = 1:
	set(value):
		selected_tab_index = clampi(value, 0, 2)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center: Vector2 = get_ring_center()
	var radius: float = get_outer_radius()
	var inner_radius: float = get_inner_radius()
	var content_radius: float = get_content_radius()

	draw_circle(center, radius, OUTER_RING_COLOR)
	draw_arc(center, radius, 0.0, TAU, 160, GOLD_LINE_COLOR, 2.0, true)
	draw_arc(center, inner_radius, 0.0, TAU, 160, GOLD_LINE_COLOR, 1.5, true)
	draw_circle(center, content_radius, INNER_FILL_COLOR)

	_draw_tab_segment(center, radius, inner_radius, selected_tab_index)
	_draw_side_diamond(center + Vector2.LEFT * get_diamond_radius(), GOLD_ACCENT_COLOR)
	_draw_side_diamond(center + Vector2.RIGHT * get_diamond_radius(), GOLD_ACCENT_COLOR)
	_draw_bottom_breaks(center, radius)


func _draw_tab_segment(center: Vector2, outer_radius: float, inner_radius: float, tab_index: int) -> void:
	var center_angle: float = deg_to_rad(TAB_CENTER_ANGLES_DEGREES[tab_index])
	var segment_span: float = deg_to_rad(tab_half_span_degrees)
	var start_angle: float = center_angle - segment_span
	var end_angle: float = center_angle + segment_span
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = 24

	for step in range(steps + 1):
		var t: float = float(step) / float(steps)
		var angle: float = lerpf(start_angle, end_angle, t)
		points.append(center + Vector2.from_angle(angle) * outer_radius)

	for step in range(steps, -1, -1):
		var t: float = float(step) / float(steps)
		var angle: float = lerpf(start_angle, end_angle, t)
		points.append(center + Vector2.from_angle(angle) * inner_radius)

	draw_colored_polygon(points, TAB_FILL_COLOR)
	draw_arc(center, outer_radius, start_angle, end_angle, 48, GOLD_LINE_COLOR, 2.0, true)
	draw_arc(center, inner_radius, start_angle, end_angle, 48, GOLD_LINE_COLOR, 1.5, true)


func _draw_side_diamond(center: Vector2, color: Color) -> void:
	var size_offset: float = 10.0
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -size_offset),
		center + Vector2(size_offset, 0.0),
		center + Vector2(0.0, size_offset),
		center + Vector2(-size_offset, 0.0),
	])
	draw_colored_polygon(points, color)


func _draw_bottom_breaks(center: Vector2, radius: float) -> void:
	var left_start: float = deg_to_rad(104.0)
	var left_end: float = deg_to_rad(128.0)
	var right_start: float = deg_to_rad(52.0)
	var right_end: float = deg_to_rad(76.0)
	draw_arc(center, radius, left_start, left_end, 20, INNER_FILL_COLOR, 6.0, true)
	draw_arc(center, radius, right_start, right_end, 20, INNER_FILL_COLOR, 6.0, true)


func get_ring_center() -> Vector2:
	return size * 0.5


func get_outer_radius() -> float:
	return minf(size.x, size.y) * 0.5 - 14.0


func get_ring_thickness() -> float:
	return get_outer_radius() * ring_thickness_ratio


func get_inner_radius() -> float:
	return get_outer_radius() - get_ring_thickness()


func get_content_radius() -> float:
	return get_inner_radius() - (get_outer_radius() * inner_gap_ratio)


func get_tab_button_center(tab_index: int) -> Vector2:
	var angle: float = deg_to_rad(TAB_CENTER_ANGLES_DEGREES[clampi(tab_index, 0, TAB_CENTER_ANGLES_DEGREES.size() - 1)])
	var ring_mid_radius: float = get_outer_radius() - (get_ring_thickness() * 0.48)
	return get_ring_center() + Vector2.from_angle(angle) * ring_mid_radius


func get_diamond_radius() -> float:
	return get_outer_radius() - (get_ring_thickness() * 0.5)
