class_name SoundEvent
extends Resource

enum RandomizationMode {
	ROUND_ROBIN,
	RANDOM,
	RANDOM_NO_REPEAT,
}

@export var sound_id: StringName
@export var streams: Array[AudioStream] = []
@export var bus: StringName = &"SFX"
@export_range(-40.0, 12.0, 0.1) var base_volume_db := 0.0
@export_range(1, 32, 1) var polyphony := 1
@export_range(0.0, 2.0, 0.01) var pitch_min := 1.0
@export_range(0.0, 2.0, 0.01) var pitch_max := 1.0
@export var randomization_mode: RandomizationMode = RandomizationMode.RANDOM_NO_REPEAT
@export_range(0.0, 2.0, 0.01) var cooldown_seconds := 0.0
