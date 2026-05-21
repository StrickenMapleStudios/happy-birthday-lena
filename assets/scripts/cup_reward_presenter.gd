extends Node3D

class_name CupRewardPresenter

signal presentation_finished

const CUP_MODEL_SCENE := preload("res://assets/art/models/items/cup.glb")

@export var descent_start_offset := Vector3(0.0, 1.35, 0.0)
@export var descent_end_offset := Vector3(0.0, 0.0, 0.0)
@export_range(0.5, 8.0, 0.05) var descent_duration := 3.2
@export_range(0.1, 4.0, 0.05) var rotation_speed := 0.85
@export var model_scale := Vector3(0.28, 0.28, 0.28)

var _cup_root: Node3D
var _is_presenting := false
var _descent_tween: Tween


func _ready() -> void:
	_spawn_cup_visual()
	_set_cup_visible(false)


func _process(delta: float) -> void:
	if not _is_presenting or _cup_root == null:
		return

	_cup_root.rotation.y += delta * rotation_speed


func is_presenting() -> bool:
	return _is_presenting


func get_focus_position() -> Vector3:
	if _cup_root != null:
		return _cup_root.global_position
	return global_position


func begin_presentation() -> void:
	if _cup_root == null:
		presentation_finished.emit()
		return

	if _descent_tween != null and _descent_tween.is_valid():
		_descent_tween.kill()

	_is_presenting = true
	_set_cup_visible(true)
	_cup_root.position = descent_start_offset
	_cup_root.rotation = Vector3.ZERO

	_descent_tween = create_tween()
	_descent_tween.set_trans(Tween.TRANS_CUBIC)
	_descent_tween.set_ease(Tween.EASE_IN_OUT)
	_descent_tween.tween_property(_cup_root, "position", descent_end_offset, descent_duration)
	_descent_tween.finished.connect(_on_descent_finished, CONNECT_ONE_SHOT)


func _on_descent_finished() -> void:
	_is_presenting = false
	_set_cup_visible(false)
	presentation_finished.emit()


func _spawn_cup_visual() -> void:
	if _cup_root != null:
		return

	var instance := CUP_MODEL_SCENE.instantiate() as Node3D
	if instance == null:
		return

	_cup_root = Node3D.new()
	_cup_root.name = "CupVisual"
	add_child(_cup_root)
	_cup_root.add_child(instance)
	instance.scale = model_scale


func _set_cup_visible(value: bool) -> void:
	if _cup_root != null:
		_cup_root.visible = value
