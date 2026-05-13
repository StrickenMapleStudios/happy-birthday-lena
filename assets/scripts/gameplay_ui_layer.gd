extends CanvasLayer

class_name GameplayUiLayer

const GAMEPLAY_UI_LAYER := 50
const WORLD_UI_ROOT_NAME := "WorldUIRoot"
const CINEMATIC_BARS_NAME := "CinematicBars"

var world_ui_root: Control
var cinematic_bars: Control


func _ready() -> void:
	layer = GAMEPLAY_UI_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_world_ui_root()


func add_world_ui(node: Control) -> void:
	if node == null:
		return

	var root := _ensure_world_ui_root()
	if root == null:
		return

	var current_parent := node.get_parent()
	if current_parent != null:
		current_parent.remove_child(node)

	root.add_child(node)


func set_world_ui_visible(is_visible: bool) -> void:
	var root := _ensure_world_ui_root()
	if root != null:
		root.visible = is_visible


func set_cinematic_bars_visible(is_visible: bool) -> void:
	var bars := _ensure_cinematic_bars()
	if bars != null:
		bars.visible = is_visible


func _ensure_world_ui_root() -> Control:
	if world_ui_root != null:
		return world_ui_root

	world_ui_root = get_node_or_null(^"WorldUIRoot") as Control
	if world_ui_root != null:
		return world_ui_root

	world_ui_root = Control.new()
	world_ui_root.name = WORLD_UI_ROOT_NAME
	world_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	world_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world_ui_root)
	return world_ui_root


func _ensure_cinematic_bars() -> Control:
	if cinematic_bars != null:
		return cinematic_bars

	cinematic_bars = get_node_or_null(^"CinematicBars") as Control
	return cinematic_bars
