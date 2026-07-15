extends CanvasLayer

signal resume_requested
signal skip_credits_requested

const EXIT_ICON := preload("res://assets/art/sprites/exit-icon.png")
const UINavigation = preload("res://assets/scripts/ui_navigation.gd")
const UiScale := preload("res://assets/scripts/ui_scale.gd")
const REFERENCE_VIEWPORT_SIZE := Vector2(1920.0, 1080.0)
const CONTENT_MIN_SCALE := 0.72
const VERTICAL_OFFSET_FROM_CENTER := 56.0

@onready var menu_root: Control = $MenuRoot
@onready var vertical_center: Control = $MenuRoot.get_node("SafeMargin/VerticalCenter")
@onready var content_root: Control = $MenuRoot.get_node("SafeMargin/VerticalCenter/Content")
@onready var resume_button: Button = content_root.get_node("MenuColumn/ButtonStack/ResumeButton")
@onready var skip_credits_button: Button = content_root.get_node("MenuColumn/ButtonStack/SkipCreditsButton")

@onready var menu_buttons: Array[Button] = [
	resume_button,
	skip_credits_button,
]

var _mirrored_exit_icon: ImageTexture


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_update_vertical_layout)
	menu_root.visible = false
	_mirrored_exit_icon = _make_mirrored_texture(EXIT_ICON)
	skip_credits_button.icon = _mirrored_exit_icon
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	skip_credits_button.pressed.connect(func() -> void: skip_credits_requested.emit())
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
	var scale_factor := UiScale.compute_reference_scale(
		get_viewport_rect().size,
		REFERENCE_VIEWPORT_SIZE,
		1.0,
		CONTENT_MIN_SCALE
	)
	content_root.scale = Vector2(scale_factor, scale_factor)
	var scaled_size := UiScale.get_control_scaled_size(content_root, target_size)
	content_root.size = target_size
	content_root.position = Vector2(
		0.0,
		maxf(((vertical_center.size.y - scaled_size.y) * 0.5) - VERTICAL_OFFSET_FROM_CENTER, 0.0)
	)
