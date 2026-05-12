extends Node3D

const MENU_MUSIC_START_OFFSET := 0.5
const CURSOR_IMAGE_PATH := "res://assets/art/sprites/cursor/cursor.png"
const CURSOR_SIZE := Vector2i(64, 64)
const CURSOR_HOTSPOT := Vector2(20, 14)

@onready var menu_music: AudioStreamPlayer = $MenuMusic


func _ready() -> void:
	get_tree().paused = false
	_apply_custom_cursor()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if menu_music.stream is AudioStreamMP3:
		var music_stream := menu_music.stream as AudioStreamMP3
		music_stream.loop = true
		music_stream.loop_offset = MENU_MUSIC_START_OFFSET

	if not menu_music.playing:
		menu_music.play(MENU_MUSIC_START_OFFSET)


func _apply_custom_cursor() -> void:
	var image := Image.load_from_file(CURSOR_IMAGE_PATH)
	if image == null or image.is_empty():
		return

	image.resize(CURSOR_SIZE.x, CURSOR_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var texture := ImageTexture.create_from_image(image)
	if texture == null:
		return

	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, CURSOR_HOTSPOT)
