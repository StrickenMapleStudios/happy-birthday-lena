extends RefCounted

const ANIMATION_LIBRARY_SCENE := preload("res://assets/art/models/characters/animations/animations.glb")


static func apply_to(animation_player: AnimationPlayer) -> bool:
	if animation_player == null:
		return false

	var source_root := ANIMATION_LIBRARY_SCENE.instantiate()
	var source_player := _find_animation_player(source_root)
	if source_player == null:
		source_root.free()
		return false

	for library_name in animation_player.get_animation_library_list():
		animation_player.remove_animation_library(library_name)

	for library_name in source_player.get_animation_library_list():
		var source_library := source_player.get_animation_library(library_name)
		if source_library == null:
			continue

		var duplicated_library := source_library.duplicate(true) as AnimationLibrary
		if duplicated_library == null:
			continue

		animation_player.add_animation_library(library_name, duplicated_library)

	source_root.free()
	return true


static func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer

	for child in root.find_children("*", "AnimationPlayer", true, false):
		var animation_player := child as AnimationPlayer
		if animation_player != null:
			return animation_player

	return null
