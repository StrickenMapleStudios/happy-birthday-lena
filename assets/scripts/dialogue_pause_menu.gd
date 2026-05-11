extends CanvasLayer

signal resume_requested
signal exit_dialogue_requested

const EXIT_ICON := preload("res://assets/art/sprites/exit-icon.png")
const UINavigation = preload("res://assets/scripts/ui_navigation.gd")
const VERTICAL_OFFSET_FROM_CENTER := 56.0

@onready var menu_root: Control = $MenuRoot
@onready var vertical_center: Control = $MenuRoot.get_node("SafeMargin/VerticalCenter")
@onready var content_root: Control = $MenuRoot.get_node("SafeMargin/VerticalCenter/Content")
@onready var resume_button: Button = content_root.get_node("MenuColumn/ButtonStack/ResumeButton")
@onready var exit_conversation_button: Button = content_root.get_node("MenuColumn/ButtonStack/ExitConversationButton")

@onready var menu_buttons: Array[Button] = [
	resume_button,
	exit_conversation_button,
]

var _mirrored_exit_icon: ImageTexture


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_root.visible = false
	_mirrored_exit_icon = _make_mirrored_texture(EXIT_ICON)
	exit_conversation_button.icon = _mirrored_exit_icon
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	exit_conversation_button.pressed.connect(func() -> void: exit_dialogue_requested.emit())
	UINavigation.bind_hover_focus_controls(menu_buttons)


func _unhandled_input(event: InputEvent) -> void:
	if not menu_root.visible:
		return

	if UINavigation.handle_linear_navigation_input(event, menu_buttons):
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()


func open() -> void:
	menu_root.visible = true
	_set_button_focus_enabled(menu_buttons, true)
	resume_button.grab_focus()
	call_deferred("_update_vertical_layout")


func close() -> void:
	menu_root.visible = false
	_set_button_focus_enabled(menu_buttons, false)


func _set_button_focus_enabled(buttons: Array[Button], enabled: bool) -> void:
	for button in buttons:
		if not is_instance_valid(button):
			continue
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _make_mirrored_texture(source: Texture2D) -> ImageTexture:
	var image := source.get_image()
	image.flip_x()
	return ImageTexture.create_from_image(image)


func _update_vertical_layout() -> void:
	var target_size := content_root.get_combined_minimum_size()
	content_root.size = target_size
	content_root.position = Vector2(
		0.0,
		maxf(((vertical_center.size.y - target_size.y) * 0.5) - VERTICAL_OFFSET_FROM_CENTER, 0.0)
	)
