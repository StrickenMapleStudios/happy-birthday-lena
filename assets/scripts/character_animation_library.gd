extends RefCounted

const ANIMATION_LIBRARY_PATH := "res://assets/art/models/characters/animations/animations.glb"
const LOOP_OVERRIDES_PATH := "res://assets/data/animation_loop_overrides.json"


static func apply_to(animation_player: AnimationPlayer) -> bool:
	if animation_player == null:
		return false

	var libraries := _load_animation_libraries()
	if libraries.is_empty():
		return false

	for library_name in animation_player.get_animation_library_list():
		animation_player.remove_animation_library(library_name)

	for library_name in libraries:
		var source_library := libraries[library_name] as AnimationLibrary
		var duplicated_library := source_library.duplicate(true) as AnimationLibrary
		if duplicated_library == null:
			continue

		_apply_loop_overrides(duplicated_library)
		animation_player.add_animation_library(library_name, duplicated_library)

	return true


static func _load_animation_libraries() -> Dictionary:
	var libraries := {}
	var source := load(ANIMATION_LIBRARY_PATH)
	if source == null:
		return libraries

	if source is AnimationLibrary:
		libraries[StringName()] = source
		return libraries

	if source is PackedScene:
		var source_root := (source as PackedScene).instantiate()
		var source_player := _find_animation_player(source_root)
		if source_player == null:
			source_root.free()
			return libraries

		for library_name in source_player.get_animation_library_list():
			var source_library := source_player.get_animation_library(library_name)
			if source_library != null:
				libraries[library_name] = source_library

		source_root.free()

	return libraries


static func _apply_loop_overrides(library: AnimationLibrary) -> void:
	if library == null:
		return

	var loop_overrides := _load_loop_overrides()
	if loop_overrides.is_empty():
		return

	for animation_name in library.get_animation_list():
		var override_value = loop_overrides.get(String(animation_name), null)
		if override_value == null:
			continue

		var animation := library.get_animation(animation_name)
		if animation == null:
			continue

		animation.loop_mode = int(override_value)


static func _load_loop_overrides() -> Dictionary:
	if not FileAccess.file_exists(LOOP_OVERRIDES_PATH):
		return {}

	var file: FileAccess = FileAccess.open(LOOP_OVERRIDES_PATH, FileAccess.READ)
	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


static func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer

	for child in root.find_children("*", "AnimationPlayer", true, false):
		var animation_player := child as AnimationPlayer
		if animation_player != null:
			return animation_player

	return null
