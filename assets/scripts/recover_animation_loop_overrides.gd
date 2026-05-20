@tool
extends EditorScript

const OLD_SCENE_PATH := "res://.godot/imported/animations.glb-699397d56d3e57e26289ce02fae68973.scn"
const OUTPUT_PATH := "res://assets/data/animation_loop_overrides.json"


func _run() -> void:
	var old_scene := load(OLD_SCENE_PATH) as PackedScene
	if old_scene == null:
		push_error("Old imported scene not found: %s" % OLD_SCENE_PATH)
		return

	var instance := old_scene.instantiate()
	var player := _find_animation_player(instance)
	if player == null:
		instance.free()
		push_error("AnimationPlayer not found in old imported scene.")
		return

	var loop_overrides := {}
	for library_name in player.get_animation_library_list():
		var library := player.get_animation_library(library_name)
		if library == null:
			continue

		for animation_name in library.get_animation_list():
			var animation := library.get_animation(animation_name)
			if animation == null:
				continue

			loop_overrides[String(animation_name)] = animation.loop_mode

	instance.free()

	var json_text := JSON.stringify(loop_overrides, "\t")
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open output file: %s" % OUTPUT_PATH)
		return

	file.store_string(json_text)
	file.close()
	print("Recovered %d animation loop override(s) to %s" % [loop_overrides.size(), OUTPUT_PATH])


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer

	for child in root.find_children("*", "AnimationPlayer", true, false):
		var animation_player := child as AnimationPlayer
		if animation_player != null:
			return animation_player

	return null
