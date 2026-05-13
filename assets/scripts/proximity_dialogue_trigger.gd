extends Area3D

@export var interaction_target_path: NodePath = ^"../InteractionTarget"
@export var consume_after_activation := true

var _consumed := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _consumed or body == null or not body.is_in_group(&"player_character"):
		return

	var interaction_target := get_node_or_null(interaction_target_path) as InteractionTarget
	if interaction_target == null:
		return

	var current_scene := get_tree().current_scene
	if current_scene == null or not current_scene.has_method("can_start_dialogue_with_target"):
		return
	if not bool(current_scene.call("can_start_dialogue_with_target", interaction_target, true)):
		return

	if consume_after_activation:
		_consumed = true
		monitoring = false

	current_scene.call_deferred("request_dialogue_with_target", interaction_target, true)
