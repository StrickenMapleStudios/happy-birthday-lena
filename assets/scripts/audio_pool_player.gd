class_name AudioPoolPlayer
extends Node

const DEFAULT_BUS := &"SFX"

var _node_pool: NodePool
var _sound_configs: Dictionary = {}


func _ready() -> void:
	_node_pool = NodePool.new()
	_node_pool.name = "NodePool"
	add_child(_node_pool)


func configure_sound(
	sound_id: StringName,
	streams: Array,
	pool_size: int = 3,
	bus: StringName = DEFAULT_BUS,
	volume_db: float = 0.0
) -> void:
	if streams.is_empty():
		stop_sound(sound_id)
		if _node_pool != null:
			_node_pool.clear_pool(sound_id)
		_sound_configs.erase(sound_id)
		return

	var config: Dictionary = _sound_configs.get(sound_id, {})
	if _node_pool != null:
		_node_pool.configure_pool(
			sound_id,
			Callable(self, "_create_audio_player").bind(sound_id, bus, volume_db),
			pool_size,
			Callable(self, "_setup_audio_player").bind(bus, volume_db)
		)

	_sound_configs[sound_id] = {
		"streams": streams.duplicate(),
		"next_stream_index": int(config.get("next_stream_index", 0)),
		"bus": StringName(bus),
		"volume_db": volume_db,
	}


func play_sound(sound_id: StringName, options: Dictionary = {}) -> void:
	var config: Dictionary = _sound_configs.get(sound_id, {})
	if config.is_empty():
		return

	var streams: Array = config.get("streams", [])
	if streams.is_empty() or _node_pool == null:
		return

	var stream_index := int(config.get("next_stream_index", 0)) % streams.size()
	var player := _node_pool.acquire(sound_id, true) as AudioStreamPlayer
	if player == null:
		return

	player.stream = streams[stream_index] as AudioStream
	player.pitch_scale = float(options.get("pitch_scale", 1.0))
	player.volume_db = float(options.get("volume_db", player.volume_db))
	player.bus = StringName(options.get("bus", player.bus))
	player.play(float(options.get("from_position", 0.0)))

	config["next_stream_index"] = _get_next_stream_index(stream_index, streams.size())
	_sound_configs[sound_id] = config


func stop_sound(sound_id: StringName) -> void:
	if _node_pool == null:
		return

	_node_pool.release_all(sound_id, Callable(self, "_stop_audio_player"))


func _get_next_stream_index(current_index: int, stream_count: int) -> int:
	if stream_count <= 1:
		return 0

	return (current_index + 1) % stream_count


func _create_audio_player(sound_id: StringName, bus: StringName, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = "%sPlayer" % String(sound_id)
	player.bus = bus
	player.volume_db = volume_db
	return player


func _setup_audio_player(player: AudioStreamPlayer, bus: StringName, volume_db: float) -> void:
	if player == null:
		return

	player.bus = bus
	player.volume_db = volume_db


func _stop_audio_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return

	player.stop()
