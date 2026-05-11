extends CanvasLayer

class_name InventoryUi

signal close_requested

const TITLE_FONT := preload("res://assets/art/fonts/Titan_One/TitanOne-Regular.ttf")
const BODY_FONT := preload("res://assets/art/fonts/Paytone_One/PaytoneOne-Regular.ttf")
const UINavigation := preload("res://assets/scripts/ui_navigation.gd")
const CATEGORY_TO_TAB := {
	InventoryData.CATEGORY_KEYS: 0,
	InventoryData.CATEGORY_REGULAR: 1,
	InventoryData.CATEGORY_QUEST: 2,
}
const TAB_TITLES := {
	InventoryData.CATEGORY_KEYS: "KEYS",
	InventoryData.CATEGORY_REGULAR: "ITEMS",
	InventoryData.CATEGORY_QUEST: "QUEST",
}
const BUTTON_FONT_COLOR := Color(0.968627, 0.968627, 0.968627, 1.0)
const BUTTON_HOVER_FONT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const BUTTON_DARK_BG := Color(0.235294, 0.235294, 0.235294, 0.65)
const BUTTON_DARK_BORDER := Color(0.631373, 0.631373, 0.631373, 1.0)
const BUTTON_GOLD_BG := Color(0.623529, 0.423529, 0.0, 0.65)
const BUTTON_GOLD_BORDER := Color(1.0, 0.960784, 0.0, 1.0)
const TITLE_GOLD := Color(1.0, 0.741176, 0.0, 1.0)
const TITLE_OUTLINE := Color(0.368627, 0.270588, 0.0, 1.0)
const TAB_HOVER_YELLOW := Color(1.0, 0.960784, 0.0, 1.0)
const TAB_BUTTON_SIZE := Vector2(84.0, 66.0)
const SLOT_BUTTON_SIZE := Vector2(74.0, 74.0)

@onready var menu_root: Control = $MenuRoot
@onready var frame: InventoryFrame = $MenuRoot/Center/Frame
@onready var center_root: Control = $MenuRoot/Center
@onready var content_root: Control = $MenuRoot/Center/Content
@onready var title_label: Label = $MenuRoot/TitleBlock/TitleLabel
@onready var title_block: VBoxContainer = $MenuRoot/TitleBlock
@onready var keys_tab_button: Button = $MenuRoot/Center/Content/TabButtons/KeysTabButton
@onready var regular_tab_button: Button = $MenuRoot/Center/Content/TabButtons/RegularTabButton
@onready var quest_tab_button: Button = $MenuRoot/Center/Content/TabButtons/QuestTabButton
@onready var tab_buttons_root: Control = $MenuRoot/Center/Content/TabButtons
@onready var slot_grid: GridContainer = $MenuRoot/Center/Content/SlotGrid

var _inventory: InventoryData
var _slot_buttons: Array[Button] = []
var _tab_buttons: Dictionary = {}
var _slot_button_group := ButtonGroup.new()
var _tab_button_group := ButtonGroup.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 180
	menu_root.visible = false

	_tab_buttons = {
		InventoryData.CATEGORY_KEYS: keys_tab_button,
		InventoryData.CATEGORY_REGULAR: regular_tab_button,
		InventoryData.CATEGORY_QUEST: quest_tab_button,
	}

	keys_tab_button.pressed.connect(func() -> void: _select_category(InventoryData.CATEGORY_KEYS))
	regular_tab_button.pressed.connect(func() -> void: _select_category(InventoryData.CATEGORY_REGULAR))
	quest_tab_button.pressed.connect(func() -> void: _select_category(InventoryData.CATEGORY_QUEST))

	_build_slot_buttons()
	_configure_tab_buttons()
	_apply_tab_button_text()
	frame.resized.connect(_update_layout)
	center_root.resized.connect(_update_layout)
	_update_visual_state()
	call_deferred("_update_layout")


func _input(event: InputEvent) -> void:
	if not menu_root.visible:
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		close_requested.emit()
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory_toggle"):
		get_viewport().set_input_as_handled()
		close_requested.emit()
		return

	if event.is_action_pressed("inventory_prev_tab"):
		get_viewport().set_input_as_handled()
		_cycle_tab(-1)
		return

	if event.is_action_pressed("inventory_next_tab"):
		get_viewport().set_input_as_handled()
		_cycle_tab(1)
		return


func _unhandled_input(event: InputEvent) -> void:
	if not menu_root.visible:
		return

	var slot_rows := _get_slot_rows()
	if UINavigation.handle_grid_navigation_input(event, slot_rows):
		_sync_selection_to_focus()
		get_viewport().set_input_as_handled()


func set_inventory(inventory: InventoryData) -> void:
	if _inventory == inventory:
		return

	if _inventory != null:
		var inventory_changed_callable: Callable = Callable(self, "_refresh_from_inventory")
		var category_changed_callable: Callable = Callable(self, "_on_category_changed")
		var selection_changed_callable: Callable = Callable(self, "_on_selection_changed")
		if _inventory.inventory_changed.is_connected(inventory_changed_callable):
			_inventory.inventory_changed.disconnect(inventory_changed_callable)
		if _inventory.category_changed.is_connected(category_changed_callable):
			_inventory.category_changed.disconnect(category_changed_callable)
		if _inventory.selection_changed.is_connected(selection_changed_callable):
			_inventory.selection_changed.disconnect(selection_changed_callable)

	_inventory = inventory
	if _inventory == null:
		return

	_inventory.inventory_changed.connect(Callable(self, "_refresh_from_inventory"))
	_inventory.category_changed.connect(Callable(self, "_on_category_changed"))
	_inventory.selection_changed.connect(Callable(self, "_on_selection_changed"))
	_refresh_from_inventory()


func open() -> void:
	menu_root.visible = true
	if _inventory != null:
		_inventory.emit_current_selection()
	_update_visual_state()
	_update_layout()
	call_deferred("_focus_active_slot")


func close() -> void:
	menu_root.visible = false


func _build_slot_buttons() -> void:
	for slot_index in range(InventoryData.SLOTS_PER_CATEGORY):
		var button: Button = Button.new()
		button.custom_minimum_size = SLOT_BUTTON_SIZE
		button.focus_mode = Control.FOCUS_ALL
		button.toggle_mode = true
		button.button_group = _slot_button_group
		button.clip_contents = true
		button.set_meta("slot_index", slot_index)
		button.set_meta("icon_label", _create_slot_icon_label())
		button.set_meta("count_label", _create_slot_count_label())
		button.pressed.connect(_on_slot_button_pressed.bind(slot_index))
		button.focus_entered.connect(_on_slot_button_focus_entered.bind(slot_index))
		button.mouse_entered.connect(_on_slot_button_mouse_entered.bind(slot_index))
		button.add_child(button.get_meta("icon_label") as Label)
		button.add_child(button.get_meta("count_label") as Label)
		slot_grid.add_child(button)
		_slot_buttons.append(button)


func _configure_tab_buttons() -> void:
	for button in [keys_tab_button, regular_tab_button, quest_tab_button]:
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.button_group = _tab_button_group
		button.custom_minimum_size = TAB_BUTTON_SIZE

	UINavigation.bind_hover_focus_controls(_slot_buttons)


func _apply_tab_button_text() -> void:
	keys_tab_button.text = "K"
	regular_tab_button.text = "B"
	quest_tab_button.text = "Q"


func _create_slot_icon_label() -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", BUTTON_HOVER_FONT_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _create_slot_count_label() -> Label:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.offset_left = -24.0
	label.offset_top = -22.0
	label.offset_right = -8.0
	label.offset_bottom = -6.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", BUTTON_HOVER_FONT_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	label.add_theme_constant_override("outline_size", 5)
	label.visible = false
	return label


func _refresh_from_inventory() -> void:
	_update_slot_buttons()
	_update_visual_state()


func _on_category_changed(_category: StringName) -> void:
	_refresh_from_inventory()
	_focus_active_slot()


func _on_selection_changed(_category: StringName, _slot_index: int) -> void:
	_update_visual_state()
	_focus_active_slot()


func _select_category(category: StringName) -> void:
	if _inventory == null:
		return
	_inventory.set_selected_category(category)


func _on_slot_button_pressed(slot_index: int) -> void:
	if _inventory == null:
		return
	if _inventory.get_selected_slot_index() == slot_index:
		_update_visual_state()
		return
	_inventory.select_slot(slot_index)


func _on_slot_button_focus_entered(slot_index: int) -> void:
	if not menu_root.visible or _inventory == null:
		return
	if _inventory.get_selected_slot_index() == slot_index:
		return
	_inventory.select_slot(slot_index)


func _on_slot_button_mouse_entered(slot_index: int) -> void:
	if not menu_root.visible or _inventory == null:
		return
	if _inventory.get_selected_slot_index() == slot_index:
		return
	_inventory.select_slot(slot_index)


func _focus_active_slot() -> void:
	if not menu_root.visible or _inventory == null:
		return

	var slot_index: int = _inventory.get_selected_slot_index()
	if slot_index >= 0 and slot_index < _slot_buttons.size():
		_slot_buttons[slot_index].grab_focus()


func _update_layout() -> void:
	if frame == null or content_root == null:
		return

	var circle_center: Vector2 = frame.get_ring_center()
	var title_size: Vector2 = title_block.get_combined_minimum_size()
	var grid_size: Vector2 = slot_grid.get_combined_minimum_size()

	title_block.position = Vector2((menu_root.size.x - title_size.x) * 0.5, 26.0)
	tab_buttons_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tab_buttons_root.position = Vector2.ZERO
	tab_buttons_root.size = content_root.size

	var tab_buttons := [keys_tab_button, regular_tab_button, quest_tab_button]
	for tab_index in range(tab_buttons.size()):
		var button: Button = tab_buttons[tab_index]
		button.size = TAB_BUTTON_SIZE
		button.position = frame.get_tab_button_center(tab_index) - (TAB_BUTTON_SIZE * 0.5)

	slot_grid.size = grid_size
	slot_grid.position = circle_center - (grid_size * 0.5)


func _get_slot_rows() -> Array:
	var rows: Array = []
	for row_index in range(4):
		var row: Array = []
		for column_index in range(4):
			row.append(_slot_buttons[(row_index * 4) + column_index])
		rows.append(row)
	return rows


func _sync_selection_to_focus() -> void:
	if _inventory == null:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		return
	var focused_button := focus_owner as Button
	if focused_button == null:
		return
	if not focused_button.has_meta("slot_index"):
		return
	var slot_index: int = int(focused_button.get_meta("slot_index"))
	if _inventory.get_selected_slot_index() == slot_index:
		return
	_inventory.select_slot(slot_index)


func _cycle_tab(direction: int) -> void:
	if _inventory == null:
		return
	var current_category: StringName = _inventory.get_selected_category()
	var current_index := InventoryData.CATEGORY_ORDER.find(current_category)
	if current_index < 0:
		current_index = 0
	var next_index := posmod(current_index + direction, InventoryData.CATEGORY_ORDER.size())
	_inventory.set_selected_category(InventoryData.CATEGORY_ORDER[next_index])


func _update_slot_buttons() -> void:
	var category: StringName = InventoryData.CATEGORY_REGULAR
	if _inventory != null:
		category = _inventory.get_selected_category()

	var slots: Array = []
	if _inventory != null:
		slots = _inventory.get_slots(category)
	for slot_index in range(_slot_buttons.size()):
		var button: Button = _slot_buttons[slot_index]
		var slot: Dictionary = {}
		if slot_index < slots.size():
			slot = slots[slot_index]
		_apply_slot_button_state(
			button,
			slot,
			category == InventoryData.CATEGORY_KEYS
		)


func _apply_slot_button_state(button: Button, slot: Dictionary, is_key_category: bool) -> void:
	var icon_label := button.get_meta("icon_label") as Label
	var count_label := button.get_meta("count_label") as Label
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = BUTTON_DARK_BG
	normal_style.border_color = BUTTON_DARK_BORDER
	normal_style.border_width_left = 3
	normal_style.border_width_top = 3
	normal_style.border_width_right = 3
	normal_style.border_width_bottom = 3
	normal_style.corner_radius_top_left = 18
	normal_style.corner_radius_top_right = 18
	normal_style.corner_radius_bottom_right = 18
	normal_style.corner_radius_bottom_left = 18
	normal_style.content_margin_left = 8.0
	normal_style.content_margin_top = 8.0
	normal_style.content_margin_right = 8.0
	normal_style.content_margin_bottom = 8.0

	var focus_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	focus_style.bg_color = BUTTON_GOLD_BG
	focus_style.border_color = BUTTON_GOLD_BORDER

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", focus_style)
	button.add_theme_stylebox_override("focus", focus_style)
	button.add_theme_stylebox_override("pressed", focus_style)
	button.add_theme_stylebox_override("hover_pressed", focus_style)
	button.text = ""
	button.set_pressed_no_signal(false)
	if icon_label != null:
		icon_label.add_theme_font_size_override("font_size", 34 if is_key_category else 36)

	var item: InventoryItemData = slot.get("item") as InventoryItemData
	if item == null:
		button.tooltip_text = ""
		button.disabled = false
		if icon_label != null:
			icon_label.text = ""
		if count_label != null:
			count_label.text = ""
			count_label.visible = false
		return

	var quantity: int = int(slot.get("quantity", 1))
	button.tooltip_text = item.display_name
	button.disabled = false
	if icon_label != null:
		icon_label.text = item.icon_text
	if count_label != null:
		count_label.text = str(quantity)
		count_label.visible = quantity > 1


func _update_visual_state() -> void:
	var category: StringName = InventoryData.CATEGORY_REGULAR
	if _inventory != null:
		category = _inventory.get_selected_category()

	title_label.text = "INVENTORY"
	frame.selected_tab_index = int(CATEGORY_TO_TAB.get(category, 1))
	_update_tab_styles(category)


func _update_tab_styles(active_category: StringName) -> void:
	for category_variant in _tab_buttons.keys():
		var category: StringName = category_variant as StringName
		var button: Button = _tab_buttons[category] as Button
		var is_active: bool = category == active_category
		var normal_style: StyleBoxFlat = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		var hover_style: StyleBoxFlat = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		button.add_theme_stylebox_override("normal", normal_style)
		button.add_theme_stylebox_override("hover", normal_style if is_active else hover_style)
		button.add_theme_stylebox_override("focus", normal_style if is_active else hover_style)
		button.add_theme_stylebox_override("pressed", normal_style)
		button.add_theme_font_override("font", TITLE_FONT)
		button.add_theme_font_size_override("font_size", 36)
		button.add_theme_constant_override("outline_size", 6)
		button.add_theme_color_override(
			"font_color",
			TAB_HOVER_YELLOW if is_active else BUTTON_FONT_COLOR
		)
		button.add_theme_color_override("font_hover_color", TAB_HOVER_YELLOW)
		button.add_theme_color_override("font_focus_color", TAB_HOVER_YELLOW)
		button.add_theme_color_override("font_pressed_color", TAB_HOVER_YELLOW)
		button.add_theme_color_override("font_hover_pressed_color", TAB_HOVER_YELLOW)
		button.add_theme_color_override("font_outline_color", TITLE_OUTLINE)
		button.set_pressed_no_signal(is_active)
		button.tooltip_text = TAB_TITLES[category]
