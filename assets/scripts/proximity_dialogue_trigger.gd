extends Area3D

@export var target_path: NodePath = ^"../InteractionTarget"
@export var consume_after_activation := true
@export var can_activate_method := StringName("can_start_dialogue_with_target")
@export var request_activate_method := StringName("request_dialogue_with_target")
@export var ignore_interaction_availability := true

var _consumed := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _consumed or body == null or not body.is_in_group(&"player_character"):
		return

	var target := get_node_or_null(target_path)
	if target == null:
		return

	var current_scene := get_tree().current_scene
	if current_scene == null or not current_scene.has_method(can_activate_method):
		return
	if not bool(current_scene.call(can_activate_method, target, ignore_interaction_availability)):
		return

	if consume_after_activation:
		_consumed = true
		monitoring = false

	current_scene.call_deferred(request_activate_method, target, ignore_interaction_availability)


func set_activation_enabled(value: bool) -> void:
	if value:
		monitoring = not _consumed
		return

	monitoring = false
