extends Control

class_name InteractionPrompt3D

const KEY_FONT := preload("res://assets/art/fonts/Paytone_One/PaytoneOne-Regular.ttf")

@export var key_text := "E":
	set(value):
		key_text = value
		_update_content()

@export var screen_offset := Vector2(0.0, -12.0)
@export var icon_size := Vector2(36.0, 36.0)

var _panel: PanelContainer
var _label: Label
var _visual_scale := 1.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_prompt()
	hide_prompt()


func show_prompt() -> void:
	visible = true


func hide_prompt() -> void:
	visible = false


func set_screen_position(screen_position: Vector2) -> void:
	if _panel == null:
		return

	position = screen_position + screen_offset - (icon_size * 0.5 * _visual_scale)


func set_visual_scale(value: float) -> void:
	_visual_scale = maxf(value, 0.01)
	scale = Vector2.ONE * _visual_scale


func _build_prompt() -> void:
	if _panel != null:
		return

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = icon_size
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.45, 0.45, 0.45, 0.94)
	panel_style.border_color = Color(0.82, 0.82, 0.82, 0.9)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	panel_style.shadow_size = 8
	panel_style.shadow_offset = Vector2(0, 4)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = icon_size
	_label.add_theme_font_override("font", KEY_FONT)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_constant_override("outline_size", 5)
	_label.add_theme_color_override("font_outline_color", Color(0.2, 0.2, 0.2, 0.45))
	_panel.add_child(_label)

	_update_content()


func _update_content() -> void:
	if _label != null:
		_label.text = key_text
