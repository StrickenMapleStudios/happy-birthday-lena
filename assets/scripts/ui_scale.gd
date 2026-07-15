extends RefCounted

class_name UiScale


static func compute_reference_scale(
	viewport_size: Vector2,
	reference_viewport_size: Vector2,
	max_scale: float = 1.0,
	min_scale: float = 0.0
) -> float:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return max_scale
	if reference_viewport_size.x <= 0.0 or reference_viewport_size.y <= 0.0:
		return max_scale

	var fit_scale := minf(
		viewport_size.x / reference_viewport_size.x,
		viewport_size.y / reference_viewport_size.y
	)
	return clampf(fit_scale, min_scale, max_scale)


static func get_control_scaled_size(control: Control, base_size: Vector2 = Vector2.ZERO) -> Vector2:
	var resolved_size := base_size
	if resolved_size == Vector2.ZERO:
		resolved_size = control.get_combined_minimum_size()
	return Vector2(
		resolved_size.x * control.scale.x,
		resolved_size.y * control.scale.y
	)
