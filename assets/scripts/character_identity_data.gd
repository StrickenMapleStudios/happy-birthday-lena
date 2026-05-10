@tool
extends Resource

class_name CharacterIdentityData

@export var dialogue_name := "":
	set(value):
		dialogue_name = value
		emit_changed()
