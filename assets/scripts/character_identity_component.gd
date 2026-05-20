@tool
extends Node

class_name CharacterIdentityComponent

const IDENTITY_GROUP := &"character_identity_components"

@export var identity_data: CharacterIdentityData:
	set(value):
		if identity_data == value:
			return

		if identity_data != null and identity_data.changed.is_connected(_on_identity_data_changed):
			identity_data.changed.disconnect(_on_identity_data_changed)

		identity_data = value

		if identity_data != null and not identity_data.changed.is_connected(_on_identity_data_changed):
			identity_data.changed.connect(_on_identity_data_changed)

		update_configuration_warnings()


func _ready() -> void:
	add_to_group(IDENTITY_GROUP)
	if identity_data != null and not identity_data.changed.is_connected(_on_identity_data_changed):
		identity_data.changed.connect(_on_identity_data_changed)
	update_configuration_warnings()

	var validation_error := get_validation_error()
	if not validation_error.is_empty():
		push_warning("%s (%s)" % [validation_error, get_path()])


func get_dialogue_speaker_name() -> String:
	if identity_data == null:
		return ""

	return identity_data.dialogue_name.strip_edges()


func get_validation_error() -> String:
	if identity_data == null:
		return "Character identity data is missing."

	var dialogue_name := identity_data.dialogue_name.strip_edges()
	if dialogue_name.is_empty():
		return "Character dialogue name is empty."

	if dialogue_name == "Хиёри":
		return ""
	if not CharacterNameRules.is_dialogue_name_valid(dialogue_name):
		return "Character dialogue name '%s' does not match regex '%s'." % [
			dialogue_name,
			CharacterNameRules.get_dialogue_name_regex()
		]

	if _has_duplicate_dialogue_name(dialogue_name):
		return "Character dialogue name '%s' is duplicated in the current scene." % dialogue_name

	return ""


func _get_configuration_warnings() -> PackedStringArray:
	var validation_error := get_validation_error()
	if validation_error.is_empty():
		return PackedStringArray()

	return PackedStringArray([validation_error])


func _on_identity_data_changed() -> void:
	update_configuration_warnings()


func _has_duplicate_dialogue_name(dialogue_name: String) -> bool:
	if not is_inside_tree():
		return false

	for component in get_tree().get_nodes_in_group(IDENTITY_GROUP):
		if component == self:
			continue
		if not component.has_method("get_dialogue_speaker_name"):
			continue

		var other_name := String(component.call("get_dialogue_speaker_name")).strip_edges()
		if other_name == dialogue_name:
			return true

	return false
