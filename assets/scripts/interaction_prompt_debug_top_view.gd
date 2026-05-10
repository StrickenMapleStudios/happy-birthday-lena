extends Control

class_name InteractionPromptDebugTopView

@export var target_path: NodePath = ^"../../character"
@export var prompt_controller_path: NodePath = ^"../../InteractionPromptController"
@export_range(2.0, 100.0, 0.5) var follow_height := 18.0
@export_range(-89.0, -5.0, 0.5) var pitch_degrees := -90.0
@export var camera_offset := Vector3(0.0, 0.0, 0.0)

@onready var viewport_container: SubViewportContainer = $Panel/SubViewportContainer
@onready var subviewport: SubViewport = $Panel/SubViewportContainer/SubViewport
@onready var debug_camera: Camera3D = $Panel/SubViewportContainer/SubViewport/DebugCamera
@onready var marker: ColorRect = $Marker

var _target: Node3D
var _prompt_controller: InteractionPromptController


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target = get_node_or_null(target_path) as Node3D
	_prompt_controller = get_node_or_null(prompt_controller_path) as InteractionPromptController
	subviewport.world_3d = get_viewport().world_3d
	debug_camera.current = true


func _process(_delta: float) -> void:
	if _target != null:
		var camera_position := _target.global_position + Vector3.UP * follow_height + camera_offset
		debug_camera.global_position = camera_position
		debug_camera.rotation_degrees = Vector3(pitch_degrees, 0.0, 0.0)

	if _prompt_controller == null or not _prompt_controller.has_active_prompt():
		marker.visible = false
		return

	var prompt_world_position := _prompt_controller.get_debug_prompt_world_position()
	var prompt_screen_position := debug_camera.unproject_position(prompt_world_position)
	marker.position = viewport_container.position + prompt_screen_position - (marker.size * 0.5)
	marker.visible = true
