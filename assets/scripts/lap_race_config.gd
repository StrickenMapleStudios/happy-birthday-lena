extends Resource

class_name LapRaceConfig

@export var races: Array[LapRaceDefinition] = []


func get_race_definition(race_id: StringName) -> LapRaceDefinition:
	if race_id.is_empty():
		return null

	for race in races:
		if race != null and race.race_id == race_id:
			return race

	return null
