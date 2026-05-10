extends Node

const DEFAULT_SOUND_EVENTS := [
	preload("res://assets/audio/events/footstep_grass.tres"),
]
const BUS_DEFINITIONS := [
	{"name": &"Music", "send": &"Master", "volume_db": 0.0},
	{"name": &"SFX", "send": &"Master", "volume_db": 0.0},
	{"name": &"UI", "send": &"SFX", "volume_db": -2.0},
	{"name": &"Dialogue", "send": &"SFX", "volume_db": -1.0},
	{"name": &"Ambience", "send": &"Master", "volume_db": -3.0},
	{"name": &"Footsteps", "send": &"SFX", "volume_db": -8.0},
]
const MIX_PRESETS := {
	&"gameplay": {
		&"Music": 0.0,
		&"SFX": 0.0,
		&"UI": -2.0,
		&"Dialogue": -1.0,
		&"Ambience": -3.0,
		&"Footsteps": -8.0,
	},
	&"pause": {
		&"Music": -3.0,
		&"SFX": -4.0,
		&"UI": 0.0,
		&"Dialogue": -1.0,
		&"Ambience": -6.0,
		&"Footsteps": -12.0,
	},
	&"dialogue": {
		&"Music": -8.0,
		&"SFX": -5.0,
		&"UI": -1.0,
		&"Dialogue": 0.0,
		&"Ambience": -8.0,
		&"Footsteps": -14.0,
	},
}

var _node_pool: NodePool
var _sound_events: Dictionary = {}
var _sound_state: Dictionary = {}
var _mix_tween: Tween


func _ready() -> void:
	_node_pool = NodePool.new()
	_node_pool.name = "NodePool"
	add_child(_node_pool)

	_ensure_audio_buses()
	for sound_event in DEFAULT_SOUND_EVENTS:
		register_sound_event(sound_event)
	apply_mix_preset(&"gameplay")


func register_sound_event(sound_event: SoundEvent) -> void:
	if sound_event == null or sound_event.sound_id.is_empty() or sound_event.streams.is_empty():
		return

	_sound_events[sound_event.sound_id] = sound_event
	_sound_state[sound_event.sound_id] = {
		"last_stream_index": -1,
		"next_stream_index": 0,
		"last_play_time": -1000.0,
	}

	_node_pool.configure_pool(
		sound_event.sound_id,
		Callable(self, "_create_audio_player").bind(sound_event),
		sound_event.polyphony,
		Callable(self, "_setup_audio_player").bind(sound_event)
	)


func play_sound(sound_id: StringName, options: Dictionary = {}) -> AudioStreamPlayer:
	var sound_event: SoundEvent = _sound_events.get(sound_id)
	if sound_event == null or sound_event.streams.is_empty():
		return null

	var state: Dictionary = _sound_state.get(sound_id, {})
	var now := Time.get_ticks_msec() / 1000.0
	var cooldown := float(options.get("cooldown_seconds", sound_event.cooldown_seconds))
	if now - float(state.get("last_play_time", -1000.0)) < cooldown:
		return null

	var stream_index := _pick_stream_index(sound_event, state)
	var player := _node_pool.acquire(sound_id, true) as AudioStreamPlayer
	if player == null:
		return null

	player.bus = StringName(options.get("bus", sound_event.bus))
	player.volume_db = float(options.get("volume_db", sound_event.base_volume_db))
	player.pitch_scale = float(options.get("pitch_scale", _pick_pitch(sound_event)))
	player.stream = sound_event.streams[stream_index]
	player.play(float(options.get("from_position", 0.0)))

	state["last_stream_index"] = stream_index
	state["last_play_time"] = now
	state["next_stream_index"] = (stream_index + 1) % sound_event.streams.size()
	_sound_state[sound_id] = state
	return player


func stop_sound(sound_id: StringName) -> void:
	if _node_pool == null:
		return

	_node_pool.release_all(sound_id, Callable(self, "_reset_audio_player"))


func apply_mix_preset(preset_id: StringName, duration: float = 0.0) -> void:
	var preset: Dictionary = MIX_PRESETS.get(preset_id, {})
	if preset.is_empty():
		return

	if _mix_tween != null and _mix_tween.is_valid():
		_mix_tween.kill()
		_mix_tween = null

	if duration <= 0.0:
		for bus_name in preset.keys():
			_set_bus_volume_db(bus_name, float(preset[bus_name]))
		return

	_mix_tween = create_tween()
	_mix_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for bus_name in preset.keys():
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index == -1:
			continue

		var target_db := float(preset[bus_name])
		_mix_tween.parallel().tween_method(
			func(value: float) -> void:
				AudioServer.set_bus_volume_db(bus_index, value),
			AudioServer.get_bus_volume_db(bus_index),
			target_db,
			duration
		)


func _ensure_audio_buses() -> void:
	for bus_definition in BUS_DEFINITIONS:
		_ensure_bus(
			bus_definition["name"],
			bus_definition["send"],
			float(bus_definition["volume_db"])
		)


func _ensure_bus(bus_name: StringName, send_name: StringName, volume_db: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		bus_index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_index, bus_name)

	AudioServer.set_bus_send(bus_index, send_name)
	AudioServer.set_bus_volume_db(bus_index, volume_db)


func _set_bus_volume_db(bus_name: StringName, volume_db: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return

	AudioServer.set_bus_volume_db(bus_index, volume_db)


func _pick_stream_index(sound_event: SoundEvent, state: Dictionary) -> int:
	match sound_event.randomization_mode:
		SoundEvent.RandomizationMode.ROUND_ROBIN:
			return int(state.get("next_stream_index", 0)) % sound_event.streams.size()
		SoundEvent.RandomizationMode.RANDOM:
			return randi_range(0, sound_event.streams.size() - 1)
		_:
			if sound_event.streams.size() <= 1:
				return 0

			var candidate := randi_range(0, sound_event.streams.size() - 1)
			var last_stream_index := int(state.get("last_stream_index", -1))
			if candidate == last_stream_index:
				candidate = (candidate + 1) % sound_event.streams.size()
			return candidate


func _pick_pitch(sound_event: SoundEvent) -> float:
	if is_equal_approx(sound_event.pitch_min, sound_event.pitch_max):
		return sound_event.pitch_min

	return randf_range(
		minf(sound_event.pitch_min, sound_event.pitch_max),
		maxf(sound_event.pitch_min, sound_event.pitch_max)
	)


func _create_audio_player(sound_event: SoundEvent) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = "%sPlayer" % String(sound_event.sound_id)
	player.bus = sound_event.bus
	player.volume_db = sound_event.base_volume_db
	return player


func _setup_audio_player(player: AudioStreamPlayer, sound_event: SoundEvent) -> void:
	if player == null:
		return

	player.bus = sound_event.bus
	player.volume_db = sound_event.base_volume_db


func _reset_audio_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return

	player.stop()
