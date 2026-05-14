extends Node3D

class_name LabyrinthArea

signal labyrinth_enter_requested(area: LabyrinthArea)
signal labyrinth_exit_requested(area: LabyrinthArea)

const PLAYER_GROUP := &"player_character"

@onready var entry_trigger: Area3D = $EntryTrigger
@onready var exit_trigger: Area3D = $ExitTrigger
@onready var return_point: Node3D = $ReturnPoint


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


func get_return_position(body: Node3D = null) -> Vector3:
	var target_position := return_point.global_position if return_point != null else entry_trigger.global_position
	if body != null:
		target_position.y = body.global_position.y
	return target_position


func _is_player_body(body: Node) -> bool:
	return body != null and body.is_in_group(PLAYER_GROUP)
