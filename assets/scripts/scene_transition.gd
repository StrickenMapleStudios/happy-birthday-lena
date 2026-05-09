extends CanvasLayer

signal transition_finished

@export_range(0.0, 5.0, 0.01, "or_greater") var default_fade_out_duration: float = 0.45
@export_range(0.0, 5.0, 0.01, "or_greater") var default_fade_in_duration: float = 0.35

var _overlay: ColorRect
var _is_transitioning := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color.BLACK
	_overlay.modulate.a = 0.0
	add_child(_overlay)


func change_scene_to_file(
	scene_path: String,
	fade_out_duration: float = default_fade_out_duration,
	fade_in_duration: float = default_fade_in_duration
) -> void:
	if _is_transitioning:
		await transition_finished

	_is_transitioning = true
	await _fade_to(1.0, fade_out_duration, Control.MOUSE_FILTER_STOP)

	var packed_scene := await _resolve_scene(scene_path)
	if packed_scene == null:
		await _fade_to(0.0, fade_in_duration, Control.MOUSE_FILTER_IGNORE)
		_finish_transition()
		return

	var change_result := get_tree().change_scene_to_packed(packed_scene)
	if change_result != OK:
		push_error("Failed to change scene to '%s' (error %d)." % [scene_path, change_result])
		await _fade_to(0.0, fade_in_duration, Control.MOUSE_FILTER_IGNORE)
		_finish_transition()
		return

	await get_tree().process_frame
	await _fade_to(0.0, fade_in_duration, Control.MOUSE_FILTER_IGNORE)
	_finish_transition()


func fade_out(duration: float = default_fade_out_duration) -> void:
	if _is_transitioning:
		await transition_finished

	_is_transitioning = true
	await _fade_to(1.0, duration, Control.MOUSE_FILTER_STOP)


func fade_in(duration: float = default_fade_in_duration) -> void:
	await _fade_to(0.0, duration, Control.MOUSE_FILTER_IGNORE)
	_finish_transition()


func preload_scene(scene_path: String, use_sub_threads: bool = true) -> void:
	var load_status := ResourceLoader.load_threaded_get_status(scene_path)
	if load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS or load_status == ResourceLoader.THREAD_LOAD_LOADED:
		return

	var request_result := ResourceLoader.load_threaded_request(scene_path, "PackedScene", use_sub_threads)
	if request_result != OK:
		push_error("Failed to preload scene '%s' (error %d)." % [scene_path, request_result])


func _fade_to(target_alpha: float, duration: float, mouse_filter: Control.MouseFilter) -> void:
	_overlay.visible = true
	_overlay.mouse_filter = mouse_filter

	if is_zero_approx(duration):
		_overlay.modulate.a = target_alpha
		_overlay.visible = target_alpha > 0.0
		return

	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", target_alpha, duration)
	await tween.finished
	_overlay.visible = target_alpha > 0.0


func _resolve_scene(scene_path: String) -> PackedScene:
	var load_status := ResourceLoader.load_threaded_get_status(scene_path)
	if load_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return load(scene_path) as PackedScene

	if load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		while load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
			load_status = ResourceLoader.load_threaded_get_status(scene_path)

	if load_status == ResourceLoader.THREAD_LOAD_LOADED:
		return ResourceLoader.load_threaded_get(scene_path) as PackedScene

	push_error("Failed to resolve preloaded scene '%s' (status %d)." % [scene_path, load_status])
	return null


func _finish_transition() -> void:
	_is_transitioning = false
	transition_finished.emit()
