extends Node3D

class_name LabyrinthArea

signal labyrinth_enter_requested(area: LabyrinthArea)
signal labyrinth_exit_requested(area: LabyrinthArea)

const PLAYER_GROUP := &"player_character"

@onready var entry_trigger: Area3D = $EntryTrigger
@onready var exit_trigger: Area3D = $ExitTrigger


func _ready() -> void:
	_connect_trigger(entry_trigger, Callable(self, "_on_entry_trigger_body_entered"))
	_connect_trigger(exit_trigger, Callable(self, "_on_exit_trigger_body_entered"))
	add_to_group(&"labyrinth_areas")


func _on_entry_trigger_body_entered(body: Node3D) -> void:
	if _is_player_body(body):
		labyrinth_enter_requested.emit(self)


func _on_exit_trigger_body_entered(body: Node3D) -> void:
	if _is_player_body(body):
		labyrinth_exit_requested.emit(self)


func _connect_trigger(trigger: Area3D, callback: Callable) -> void:
	if trigger == null:
		return

	if not trigger.body_entered.is_connected(callback):
		trigger.body_entered.connect(callback)


func _is_player_body(body: Node) -> bool:
	return body != null and body.is_in_group(PLAYER_GROUP)
