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
@export_range(0.0, 10.0, 0.01) var blur_delay_seconds := 0.875
@export_range(0.0, 5.0, 0.01) var blur_fade_duration := 0.3
@export_range(0, 256, 1) var role_font_size := 34
@export_range(0, 256, 1) var name_font_size := 34
@export_range(0.0, 400.0, 1.0) var row_spacing := 28.0
@export_range(0.0, 3000.0, 1.0) var top_padding := 1080.0
@export_range(0.0, 3000.0, 1.0) var bottom_padding := 720.0

@onready var _dim_overlay: ColorRect = $DimOverlay
@onready var _scroll_root: Control = $ClipContainer/CreditsScroll
@onready var _entries: VBoxContainer = $ClipContainer/CreditsScroll/Entries

var _scrolling := false
var _blur_tween: Tween


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
	_schedule_delayed_blur()


func stop_scrolling() -> void:
	_scrolling = false
	_kill_blur_tween()
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
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 48)
	var normalized_profession := profession.strip_edges()

	var role_label := Label.new()
	role_label.text = normalized_profession
	role_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	role_label.add_theme_font_override("font", TITLE_FONT)
	role_label.add_theme_font_size_override("font_size", role_font_size)
	role_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.72, 1.0))
	row.add_child(role_label)

	var name_label := Label.new()
	name_label.text = String(SPECIAL_CREDIT_NAMES_BY_ROLE.get(normalized_profession, credit_name))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_label.add_theme_font_override("font", TITLE_FONT)
	name_label.add_theme_font_size_override("font_size", name_font_size)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78, 1.0))
	row.add_child(name_label)

	return row


func _schedule_delayed_blur() -> void:
	_kill_blur_tween()
	_apply_blur_state_immediately(0.0)
	if _dim_overlay == null:
		return

	_blur_tween = create_tween()
	_blur_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if blur_delay_seconds > 0.0:
		_blur_tween.tween_interval(blur_delay_seconds)
	var blur_material := _dim_overlay.material as ShaderMaterial
	if blur_material == null:
		return
	_blur_tween.tween_method(_set_blur_amount, 0.0, blur_strength, blur_fade_duration)


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


func _kill_blur_tween() -> void:
	if _blur_tween != null and _blur_tween.is_valid():
		_blur_tween.kill()
	_blur_tween = null
