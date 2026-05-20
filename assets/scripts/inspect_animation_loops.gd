extends SceneTree

const OLD_SCENE_PATH := "res://.godot/imported/animations.glb-699397d56d3e57e26289ce02fae68973.scn"
const CURRENT_LIBRARY_PATH := "res://assets/art/models/characters/animations/animations.glb"


func _init() -> void:
	var old_scene := load(OLD_SCENE_PATH) as PackedScene
	if old_scene == null:
		push_error("Old imported scene not found: %s" % OLD_SCENE_PATH)
		quit(1)
		return

	var instance := old_scene.instantiate()
	var player := _find_animation_player(instance)
	if player == null:
		push_error("AnimationPlayer not found in old imported scene.")
		quit(1)
		return

	print("OLD_SCENE_ANIMATIONS_BEGIN")
	for library_name in player.get_animation_library_list():
		var library := player.get_animation_library(library_name)
		if library == null:
			continue
		for animation_name in library.get_animation_list():
			var animation := library.get_animation(animation_name)
			if animation == null:
				continue
			print("%s|%s|%d" % [String(library_name), String(animation_name), animation.loop_mode])
	print("OLD_SCENE_ANIMATIONS_END")

	var current_resource := load(CURRENT_LIBRARY_PATH)
	if current_resource is AnimationLibrary:
		var current_library := current_resource as AnimationLibrary
		print("CURRENT_LIBRARY_ANIMATIONS_BEGIN")
		for animation_name in current_library.get_animation_list():
			var animation := current_library.get_animation(animation_name)
			if animation == null:
				continue
			print("%s|%d" % [String(animation_name), animation.loop_mode])
		print("CURRENT_LIBRARY_ANIMATIONS_END")
	else:
		print("CURRENT_LIBRARY_IS_NOT_ANIMATION_LIBRARY")

	instance.free()
	quit()


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer

	for child in root.find_children("*", "AnimationPlayer", true, false):
		var animation_player := child as AnimationPlayer
		if animation_player != null:
			return animation_player

	return null
