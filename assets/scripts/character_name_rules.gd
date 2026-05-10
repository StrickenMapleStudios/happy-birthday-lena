extends RefCounted

class_name CharacterNameRules

const RULES_PATH := "res://assets/data/character_name_rules.json"
const DIALOGUE_NAME_REGEX_KEY := "dialogue_name_regex"
const DEFAULT_DIALOGUE_NAME_REGEX := "^(?:(Анти|Не)(?!\\1))*Лена$"


static func get_dialogue_name_regex() -> String:
	var file := FileAccess.open(RULES_PATH, FileAccess.READ)
	if file == null:
		push_warning("Character name rules file is missing at '%s'. Falling back to default regex." % RULES_PATH)
		return DEFAULT_DIALOGUE_NAME_REGEX

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Character name rules file '%s' is invalid. Falling back to default regex." % RULES_PATH)
		return DEFAULT_DIALOGUE_NAME_REGEX

	var pattern := String((parsed as Dictionary).get(DIALOGUE_NAME_REGEX_KEY, DEFAULT_DIALOGUE_NAME_REGEX)).strip_edges()
	if pattern.is_empty():
		return DEFAULT_DIALOGUE_NAME_REGEX

	return pattern


static func is_dialogue_name_valid(name: String) -> bool:
	var regex := RegEx.new()
	if regex.compile(get_dialogue_name_regex()) != OK:
		push_warning("Dialogue name regex could not be compiled. Validation is skipped.")
		return true

	return regex.search(name) != null
