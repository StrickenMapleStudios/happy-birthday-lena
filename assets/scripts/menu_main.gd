extends Node3D

const MENU_MUSIC_START_OFFSET := 0.5

@onready var menu_music: AudioStreamPlayer = $MenuMusic


func _ready() -> void:
	if menu_music.stream is AudioStreamMP3:
		var music_stream := menu_music.stream as AudioStreamMP3
		music_stream.loop = true
		music_stream.loop_offset = MENU_MUSIC_START_OFFSET

	if not menu_music.playing:
		menu_music.play(MENU_MUSIC_START_OFFSET)
