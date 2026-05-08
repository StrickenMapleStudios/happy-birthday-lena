extends Node

signal settings_applied(settings: Dictionary)

const CONFIG_PATH := "user://settings.cfg"
const RESOLUTION_OPTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]
const LANGUAGE_OPTIONS: Array[String] = ["ENGLISH", "RUSSIAN"]

const _DEFAULT_SETTINGS := {
	"audio": {
		"master_volume": 100.0,
		"music_volume": 80.0,
		"sfx_volume": 90.0,
	},
	"display": {
		"resolution_index": 2,
		"fullscreen": true,
		"vsync": true,
	},
	"gameplay": {
		"language": "ENGLISH",
		"tutorial_hints": true,
	},
}

const _LANGUAGE_TO_LOCALE := {
	"ENGLISH": "en",
	"RUSSIAN": "ru",
}

var _settings: Dictionary = {}


func _ready() -> void:
	_load_settings()
	apply_settings(_settings, false)


func get_settings() -> Dictionary:
	return _settings.duplicate(true) as Dictionary


func apply_settings(new_settings: Dictionary, save_to_disk: bool = true) -> void:
	_settings = _normalize_settings(new_settings)
	_apply_audio_settings(_settings["audio"])
	_apply_display_settings(_settings["display"])
	_apply_gameplay_settings(_settings["gameplay"])

	if save_to_disk:
		_save_settings()

	settings_applied.emit(get_settings())


func is_tutorial_hints_enabled() -> bool:
	var gameplay_settings: Dictionary = _settings.get("gameplay", {}) as Dictionary
	return bool(gameplay_settings.get("tutorial_hints", true))


func _load_settings() -> void:
	var loaded_settings: Dictionary = _DEFAULT_SETTINGS.duplicate(true)
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)

	if err == OK:
		loaded_settings["audio"]["master_volume"] = config.get_value("audio", "master_volume", loaded_settings["audio"]["master_volume"])
		loaded_settings["audio"]["music_volume"] = config.get_value("audio", "music_volume", loaded_settings["audio"]["music_volume"])
		loaded_settings["audio"]["sfx_volume"] = config.get_value("audio", "sfx_volume", loaded_settings["audio"]["sfx_volume"])
		loaded_settings["display"]["resolution_index"] = config.get_value("display", "resolution_index", loaded_settings["display"]["resolution_index"])
		loaded_settings["display"]["fullscreen"] = config.get_value("display", "fullscreen", loaded_settings["display"]["fullscreen"])
		loaded_settings["display"]["vsync"] = config.get_value("display", "vsync", loaded_settings["display"]["vsync"])
		loaded_settings["gameplay"]["language"] = config.get_value("gameplay", "language", loaded_settings["gameplay"]["language"])
		loaded_settings["gameplay"]["tutorial_hints"] = config.get_value("gameplay", "tutorial_hints", loaded_settings["gameplay"]["tutorial_hints"])

	_settings = _normalize_settings(loaded_settings)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", _settings["audio"]["master_volume"])
	config.set_value("audio", "music_volume", _settings["audio"]["music_volume"])
	config.set_value("audio", "sfx_volume", _settings["audio"]["sfx_volume"])
	config.set_value("display", "resolution_index", _settings["display"]["resolution_index"])
	config.set_value("display", "fullscreen", _settings["display"]["fullscreen"])
	config.set_value("display", "vsync", _settings["display"]["vsync"])
	config.set_value("gameplay", "language", _settings["gameplay"]["language"])
	config.set_value("gameplay", "tutorial_hints", _settings["gameplay"]["tutorial_hints"])

	var err := config.save(CONFIG_PATH)
	if err != OK:
		push_warning("Failed to save settings to '%s' (error %d)." % [CONFIG_PATH, err])


func _normalize_settings(candidate: Dictionary) -> Dictionary:
	var normalized: Dictionary = _DEFAULT_SETTINGS.duplicate(true)
	var audio: Dictionary = candidate.get("audio", {}) as Dictionary
	var display: Dictionary = candidate.get("display", {}) as Dictionary
	var gameplay: Dictionary = candidate.get("gameplay", {}) as Dictionary

	normalized["audio"]["master_volume"] = clampf(float(audio.get("master_volume", normalized["audio"]["master_volume"])), 0.0, 100.0)
	normalized["audio"]["music_volume"] = clampf(float(audio.get("music_volume", normalized["audio"]["music_volume"])), 0.0, 100.0)
	normalized["audio"]["sfx_volume"] = clampf(float(audio.get("sfx_volume", normalized["audio"]["sfx_volume"])), 0.0, 100.0)
	normalized["display"]["resolution_index"] = clampi(int(display.get("resolution_index", normalized["display"]["resolution_index"])), 0, RESOLUTION_OPTIONS.size() - 1)
	normalized["display"]["fullscreen"] = bool(display.get("fullscreen", normalized["display"]["fullscreen"]))
	normalized["display"]["vsync"] = bool(display.get("vsync", normalized["display"]["vsync"]))

	var language := str(gameplay.get("language", normalized["gameplay"]["language"])).to_upper()
	if not LANGUAGE_OPTIONS.has(language):
		language = normalized["gameplay"]["language"]

	normalized["gameplay"]["language"] = language
	normalized["gameplay"]["tutorial_hints"] = bool(gameplay.get("tutorial_hints", normalized["gameplay"]["tutorial_hints"]))
	return normalized


func _apply_audio_settings(audio_settings: Dictionary) -> void:
	_set_bus_volume("Master", float(audio_settings["master_volume"]))
	_set_bus_volume("Music", float(audio_settings["music_volume"]))
	_set_bus_volume("SFX", float(audio_settings["sfx_volume"]))


func _apply_display_settings(display_settings: Dictionary) -> void:
	var resolution: Vector2i = RESOLUTION_OPTIONS[int(display_settings["resolution_index"])]
	var fullscreen := bool(display_settings["fullscreen"])
	var vsync_mode := DisplayServer.VSYNC_ENABLED if bool(display_settings["vsync"]) else DisplayServer.VSYNC_DISABLED
	var root_window := get_tree().root
	var window_id := root_window.get_window_id()

	root_window.content_scale_size = resolution
	DisplayServer.window_set_vsync_mode(vsync_mode, window_id)

	if fullscreen:
		DisplayServer.window_set_size(resolution, window_id)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN, window_id)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, window_id)
		DisplayServer.window_set_size(resolution, window_id)


func _apply_gameplay_settings(gameplay_settings: Dictionary) -> void:
	var language := str(gameplay_settings["language"])
	var locale: String = str(_LANGUAGE_TO_LOCALE.get(language, "en"))
	TranslationServer.set_locale(locale)


func _set_bus_volume(bus_name: String, volume_percent: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return

	var db := linear_to_db(maxf(volume_percent / 100.0, 0.0001))
	if is_zero_approx(volume_percent):
		db = -80.0

	AudioServer.set_bus_volume_db(bus_index, db)
