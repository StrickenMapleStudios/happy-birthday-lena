extends Control

class_name ScrollingCreditsUI

const TITLE_FONT := preload("res://assets/art/fonts/Titan_One/TitanOne-Regular.ttf")
const DEFAULT_CREDIT_NAME := "Артем Айрапетов"
const LAPTOP_CREDIT_ROLE := "Ноутбук"
const LAPTOP_CREDIT_NAME := "Тигран Айрапетов"
const SPECIAL_CREDIT_NAMES_BY_ROLE := {
	LAPTOP_CREDIT_ROLE: LAPTOP_CREDIT_NAME,
}

const TEMPLATE_PROFESSIONS := [
	"Режиссёр",
	"Сценарист",
	"Художник-постановщик",
	"Композитор",
	"Программист",
	"Художник по персонажам",
	"Аниматор",
	"Звукорежиссёр",
	"Тестировщик",
	"Продюсер",
	"Ноутбук",
]

@export var credit_name := DEFAULT_CREDIT_NAME
@export var professions: PackedStringArray = PackedStringArray(TEMPLATE_PROFESSIONS)
@export_range(10.0, 200.0, 1.0) var scroll_speed := 42.0
@export_range(0.0, 4.0, 0.01) var blur_strength := 1.45
@export_range(0.0, 1.0, 0.01) var dim_strength := 0.08
@export_range(0, 256, 1) var role_font_size := 34
@export_range(0, 256, 1) var name_font_size := 34
@export_range(0.0, 1000.0, 1.0) var column_gap := 72.0
@export_range(0.0, 1200.0, 1.0) var column_width := 480.0
@export_range(0.0, 400.0, 1.0) var row_spacing := 28.0
@export_range(0.0, 3000.0, 1.0) var top_padding := 1080.0
@export_range(0.0, 3000.0, 1.0) var bottom_padding := 720.0

@onready var _dim_overlay: ColorRect = $DimOverlay
@onready var _scroll_root: Control = $ClipContainer/CreditsScroll
@onready var _entries: VBoxContainer = $ClipContainer/CreditsScroll/Entries

var _scrolling := false


func _ready() -> void:
	visible = false
	_build_entries()
	_apply_blur_state_immediately(0.0)


func _process(delta: float) -> void:
	if not _scrolling:
		return

	_scroll_root.position.y -= scroll_speed * delta


func start_scrolling() -> void:
	_build_entries()
	_scroll_root.position.y = top_padding
	_scrolling = true
	visible = true
	_apply_blur_state_immediately(blur_strength)


func stop_scrolling() -> void:
	_scrolling = false
	_apply_blur_state_immediately(0.0)
	visible = false


func get_estimated_scroll_duration() -> float:
	var content_height := top_padding + bottom_padding
	if _entries != null:
		content_height += _entries.get_combined_minimum_size().y

	var viewport_height := size.y
	if viewport_height <= 0.0:
		viewport_height = 1080.0

	var travel_distance := content_height + viewport_height
	if scroll_speed <= 0.0:
		return 0.0

	return travel_distance / scroll_speed


func _build_entries() -> void:
	if _entries == null:
		return

	for child in _entries.get_children():
		child.queue_free()

	for profession in professions:
		_entries.add_child(_create_entry_row(profession))
		var spacer := Control.new()
		spacer.custom_minimum_size.y = row_spacing
		_entries.add_child(spacer)


func _create_entry_row(profession: String) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(column_gap))
	var normalized_profession := profession.strip_edges()

	var role_label := Label.new()
	role_label.text = normalized_profession
	role_label.custom_minimum_size.x = column_width
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	role_label.add_theme_font_override("font", TITLE_FONT)
	role_label.add_theme_font_size_override("font_size", role_font_size)
	role_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.72, 1.0))
	row.add_child(role_label)

	var name_label := Label.new()
	name_label.text = String(SPECIAL_CREDIT_NAMES_BY_ROLE.get(normalized_profession, credit_name))
	name_label.custom_minimum_size.x = column_width
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.add_theme_font_override("font", TITLE_FONT)
	name_label.add_theme_font_size_override("font_size", name_font_size)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78, 1.0))
	row.add_child(name_label)

	return row


func _set_blur_amount(value: float) -> void:
	if _dim_overlay == null:
		return

	var blur_material := _dim_overlay.material as ShaderMaterial
	if blur_material == null:
		return

	blur_material.set_shader_parameter("blur_lod", value)
	blur_material.set_shader_parameter("tint_color", Color(0.18, 0.2, 0.16, dim_strength))


func _apply_blur_state_immediately(value: float) -> void:
	_set_blur_amount(value)
