extends RefCounted

class_name LapRaceConfigUtils

const DEFAULT_RACE_CONFIG_PATH := "res://assets/data/lap_races/default_lap_race_config.json"
const DEFAULT_DIALOGUE_RESOURCE_PATH := "res://assets/dialogue/race_challenger.dialogue"
const DEFAULT_START_TITLE := &"start"
const DEFAULT_WIN_TITLE := &"post_race_win"
const DEFAULT_LOSE_TITLE := &"post_race_lose"
const DEFAULT_COMPLETED_TITLE := &"post_race_win_reward_claimed"


static func load_race_definitions(config_path: String = DEFAULT_RACE_CONFIG_PATH) -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	if config_path.is_empty():
		return definitions

	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_warning("LapRaceConfigUtils could not open race config: %s" % config_path)
		return definitions

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("LapRaceConfigUtils race config is not a dictionary: %s" % config_path)
		return definitions

	var parsed_dict := parsed as Dictionary
	var races: Variant = parsed_dict.get("races", [])
	if typeof(races) != TYPE_ARRAY:
		push_warning("LapRaceConfigUtils race config has no valid 'races' array: %s" % config_path)
		return definitions

	for race_variant: Variant in races:
		if typeof(race_variant) != TYPE_DICTIONARY:
			continue

		var race_data := race_variant as Dictionary
		var race_id := String(race_data.get("race_id", "")).strip_edges()
		if race_id.is_empty():
			continue

		definitions.append({
			"race_id": StringName(race_id),
			"laps_to_win": maxi(int(race_data.get("laps_to_win", 1)), 1),
			"npc_speed_multiplier": float(race_data.get("npc_speed_multiplier", 1.35)),
			"force_player_win": bool(race_data.get("force_player_win", false)),
			"dialogue_resource_path": String(
				race_data.get("dialogue_resource_path", DEFAULT_DIALOGUE_RESOURCE_PATH)
			).strip_edges(),
			"start_title": StringName(
				String(race_data.get("start_title", String(DEFAULT_START_TITLE))).strip_edges()
			),
			"win_title": StringName(
				String(race_data.get("win_title", String(DEFAULT_WIN_TITLE))).strip_edges()
			),
			"lose_title": StringName(
				String(race_data.get("lose_title", String(DEFAULT_LOSE_TITLE))).strip_edges()
			),
			"completed_title": StringName(
				String(race_data.get("completed_title", String(DEFAULT_COMPLETED_TITLE))).strip_edges()
			),
		})

	return definitions


static func load_race_map(config_path: String = DEFAULT_RACE_CONFIG_PATH) -> Dictionary:
	var race_map: Dictionary = {}
	for race_definition in load_race_definitions(config_path):
		var race_id := StringName(race_definition.get("race_id", &""))
		if race_id.is_empty():
			continue
		race_map[String(race_id)] = race_definition
	return race_map


static func load_race_ids(config_path: String = DEFAULT_RACE_CONFIG_PATH) -> Array[StringName]:
	var race_ids: Array[StringName] = []
	for race_definition in load_race_definitions(config_path):
		var race_id := StringName(race_definition.get("race_id", &""))
		if not race_id.is_empty():
			race_ids.append(race_id)
	return race_ids
