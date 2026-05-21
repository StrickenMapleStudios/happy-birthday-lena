extends RefCounted

class_name CharacterGroundSnap

const RAY_START_ABOVE_FEET := 0.35
const RAY_DISTANCE := 1.25
const MIN_FLOOR_NORMAL_Y := 0.55
const MAX_STEP_UP := 0.2
const MAX_STEP_DOWN := 1.5
const DEFAULT_FEET_HEIGHT_OFFSET := 0.55


static func compute_feet_height_offset(
	character: CharacterBody3D,
	fallback: float = DEFAULT_FEET_HEIGHT_OFFSET
) -> float:
	var collision_shape := character.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return fallback

	var local_bottom_y := collision_shape.position.y
	var shape := collision_shape.shape
	if shape is CapsuleShape3D:
		local_bottom_y -= (shape as CapsuleShape3D).height * 0.5
	elif shape is CylinderShape3D:
		local_bottom_y -= (shape as CylinderShape3D).height * 0.5
	elif shape is BoxShape3D:
		local_bottom_y -= (shape as BoxShape3D).size.y * 0.5

	return local_bottom_y


static func clamp_horizontal_slide(motion: Vector3) -> Vector3:
	motion.y = minf(motion.y, 0.0)
	return motion


static func snap_to_ground_height(character: CharacterBody3D, feet_height_offset: float) -> void:
	var world := character.get_world_3d()
	if world == null:
		return

	var space_state := world.direct_space_state
	if space_state == null:
		return

	var feet_position := character.global_position + Vector3(0.0, feet_height_offset, 0.0)
	var ray_start := feet_position + Vector3.UP * RAY_START_ABOVE_FEET
	var ray_end := feet_position - Vector3.UP * RAY_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = [character.get_rid()]

	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var floor_normal: Vector3 = hit.normal
	if floor_normal.y < MIN_FLOOR_NORMAL_Y:
		return

	var target_y := float(hit.position.y) - feet_height_offset
	var delta_y := target_y - character.global_position.y
	if delta_y > MAX_STEP_UP or delta_y < -MAX_STEP_DOWN:
		return

	character.global_position.y = target_y
