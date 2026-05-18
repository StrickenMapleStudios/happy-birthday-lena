extends CanvasLayer

class_name FoundItemPopup

signal continue_requested

const TITLE_FONT := preload("res://assets/art/fonts/Titan_One/TitanOne-Regular.ttf")
const BODY_FONT := preload("res://assets/art/fonts/Paytone_One/PaytoneOne-Regular.ttf")
const PLACEHOLDER_ITEM_ICON := preload("res://addons/assetplus/defaultgodot.png")
const PREVIEW_RENDER_LAYER := 1 << 10

@onready var root: Control = $Root
@onready var dim_overlay: ColorRect = $Root/DimOverlay
@onready var card: Panel = $Root/Card
@onready var ribbon: Panel = $Root/Card/Ribbon
@onready var ribbon_label: Label = $Root/Card/Ribbon/RibbonLabel
@onready var preview_panel: Panel = $Root/Card/Content/PreviewPanel
@onready var preview_container: SubViewportContainer = $Root/Card/Content/PreviewPanel/PreviewViewportContainer
@onready var preview_viewport: SubViewport = $Root/Card/Content/PreviewPanel/PreviewViewportContainer/PreviewViewport
@onready var preview_camera: Camera3D = $Root/Card/Content/PreviewPanel/PreviewViewportContainer/PreviewViewport/PreviewRoot/PreviewCamera
@onready var preview_anchor: Node3D = $Root/Card/Content/PreviewPanel/PreviewViewportContainer/PreviewViewport/PreviewRoot/PreviewAnchor
@onready var preview_light: DirectionalLight3D = $Root/Card/Content/PreviewPanel/PreviewViewportContainer/PreviewViewport/PreviewRoot/PreviewLight
@onready var preview_fill_light: OmniLight3D = $Root/Card/Content/PreviewPanel/PreviewViewportContainer/PreviewViewport/PreviewRoot/PreviewFillLight
@onready var fallback_icon: TextureRect = $Root/Card/Content/PreviewPanel/FallbackIcon
@onready var item_name_label: Label = $Root/Card/Content/ItemNameLabel
@onready var description_label: Label = $Root/Card/Content/DescriptionLabel
@onready var continue_button: Button = $Root/Card/ContinueButton
@onready var divider: ColorRect = $Root/Card/Content/Divider

var _preview_instance: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 190
	root.visible = false
	_apply_theme()
	continue_button.pressed.connect(_on_continue_pressed)
	root.resized.connect(_update_layout)
	preview_panel.resized.connect(_update_preview_viewport_size)
	call_deferred("_update_layout")


func _process(delta: float) -> void:
	if not root.visible or _preview_instance == null:
		return

	_preview_instance.rotate_y(delta * 0.75)


func _input(event: InputEvent) -> void:
	if not root.visible:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory_toggle"):
		get_viewport().set_input_as_handled()
		continue_requested.emit()


func open_for_item(item: InventoryItemData, quantity: int = 1) -> void:
	_configure_content(item, quantity)
	root.visible = true
	_update_layout()
	call_deferred("_focus_continue_button")


func close() -> void:
	root.visible = false
	_clear_preview_instance()


func is_open() -> bool:
	return root.visible


func _on_continue_pressed() -> void:
	continue_requested.emit()


func _configure_content(item: InventoryItemData, quantity: int) -> void:
	var item_name := "ПРЕДМЕТ"
	var description := "Что-то интересное."
	if item != null:
		item_name = item.display_name.to_upper()
		description = item.description.strip_edges()
		if description.is_empty():
			description = _build_default_description(item, quantity)

	item_name_label.text = item_name
	description_label.text = description
	_setup_preview(item)


func _build_default_description(item: InventoryItemData, quantity: int) -> String:
	if item == null:
		return "Что-то интересное."
	if quantity > 1:
		return "Теперь у тебя их %d." % quantity

	match item.category:
		InventoryItemData.ItemCategory.KEY:
			return "Интересно, от чего же он?"
		InventoryItemData.ItemCategory.QUEST:
			return "Похоже, это пригодится дальше."
		_:
			return "Похоже, это может быть полезно."


func _setup_preview(item: InventoryItemData) -> void:
	_clear_preview_instance()
	fallback_icon.visible = false
	preview_container.visible = false

	if item == null:
		fallback_icon.texture = PLACEHOLDER_ITEM_ICON
		fallback_icon.visible = true
		return

	if item.world_model_scene != null:
		var instance := item.world_model_scene.instantiate() as Node3D
		if instance != null:
			preview_anchor.add_child(instance)
			instance.position = item.world_model_offset
			instance.rotation_degrees = item.world_model_rotation_degrees
			instance.scale = item.world_model_scale
			_assign_preview_layer(instance)
			_preview_instance = instance
			preview_camera.cull_mask = PREVIEW_RENDER_LAYER
			preview_container.visible = true
			_frame_preview_instance(instance)
			return

	fallback_icon.texture = item.icon_texture if item.icon_texture != null else PLACEHOLDER_ITEM_ICON
	fallback_icon.visible = true


func _frame_preview_instance(instance: Node3D) -> void:
	var bounds := _compute_aabb(instance)
	var center := bounds.get_center()
	var size := bounds.size
	var radius := maxf(size.length() * 0.35, 0.45)

	instance.position += -center
	preview_camera.position = Vector3(radius * 0.9, radius * 0.48, radius * 2.45)
	preview_camera.look_at(Vector3(0.0, radius * 0.08, 0.0), Vector3.UP)
	preview_camera.near = 0.05
	preview_camera.far = maxf(radius * 12.0, 12.0)
	preview_fill_light.position = Vector3(-radius * 0.6, radius * 0.65, radius * 1.3)
	preview_fill_light.omni_range = maxf(radius * 8.0, 6.0)


func _compute_aabb(root_node: Node3D) -> AABB:
	var has_bounds := false
	var merged := AABB()
	var stack: Array[Node] = [root_node]

	while not stack.is_empty():
		var current : Node = stack.pop_back()
		for child in current.get_children():
			stack.append(child)

		var mesh_instance := current as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue

		var transformed_points := _get_transformed_aabb_points(mesh_instance.global_transform, mesh_instance.mesh.get_aabb())
		for point in transformed_points:
			if not has_bounds:
				merged = AABB(point, Vector3.ZERO)
				has_bounds = true
			else:
				merged = merged.expand(point)

	if has_bounds:
		return merged

	return AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)


func _get_transformed_aabb_points(transform: Transform3D, bounds: AABB) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for x in [bounds.position.x, bounds.end.x]:
		for y in [bounds.position.y, bounds.end.y]:
			for z in [bounds.position.z, bounds.end.z]:
				points.append(transform * Vector3(x, y, z))
	return points


func _assign_preview_layer(root_node: Node) -> void:
	var visual := root_node as VisualInstance3D
	if visual != null:
		visual.layers = PREVIEW_RENDER_LAYER

	for child in root_node.get_children():
		_assign_preview_layer(child)


func _clear_preview_instance() -> void:
	if _preview_instance == null:
		return

	_preview_instance.queue_free()
	_preview_instance = null


func _focus_continue_button() -> void:
	if root.visible:
		continue_button.grab_focus()


func _update_layout() -> void:
	if card == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var card_size := Vector2(
		clampf(viewport_size.x * 0.39, 420.0, 680.0),
		clampf(viewport_size.y * 0.76, 500.0, 820.0)
	)
	card.size = card_size
	card.position = (viewport_size - card_size) * 0.5

	var ribbon_size := Vector2(card_size.x * 0.88, clampf(card_size.y * 0.15, 72.0, 104.0))
	ribbon.size = ribbon_size
	ribbon.position = Vector2((card_size.x - ribbon_size.x) * 0.5, -ribbon_size.y * 0.32)
	_update_preview_viewport_size()


func _update_preview_viewport_size() -> void:
	if preview_viewport == null or preview_panel == null:
		return

	var size := preview_panel.size
	preview_viewport.size = Vector2i(maxi(int(size.x), 1), maxi(int(size.y), 1))


func _apply_theme() -> void:
	dim_overlay.color = Color(0.03, 0.06, 0.07, 0.62)
	_apply_panel_style(card, Color(0.995, 0.957, 0.82, 0.98), Color(0.84, 0.62, 0.21, 1.0), 8, 36)
	_apply_panel_style(ribbon, Color(0.94, 0.74, 0.15, 1.0), Color(0.75, 0.54, 0.08, 1.0), 0, 28)
	_apply_panel_style(preview_panel, Color(1.0, 0.99, 0.95, 0.98), Color(0.95, 0.92, 0.82, 1.0), 0, 32)

	ribbon_label.add_theme_font_override("font", TITLE_FONT)
	ribbon_label.add_theme_font_size_override("font_size", 42)
	ribbon_label.add_theme_constant_override("outline_size", 7)
	ribbon_label.add_theme_color_override("font_color", Color(1.0, 0.99, 0.97, 1.0))
	ribbon_label.add_theme_color_override("font_outline_color", Color(0.74, 0.54, 0.08, 1.0))
	ribbon_label.text = "НАЙДЕН ПРЕДМЕТ"

	item_name_label.add_theme_font_override("font", TITLE_FONT)
	item_name_label.add_theme_font_size_override("font_size", 38)
	item_name_label.add_theme_constant_override("outline_size", 4)
	item_name_label.add_theme_color_override("font_color", Color(0.42, 0.25, 0.02, 1.0))
	item_name_label.add_theme_color_override("font_outline_color", Color(1.0, 0.93, 0.75, 0.7))

	description_label.add_theme_font_override("font", BODY_FONT)
	description_label.add_theme_font_size_override("font_size", 24)
	description_label.add_theme_color_override("font_color", Color(0.48, 0.38, 0.29, 1.0))

	continue_button.add_theme_font_override("font", TITLE_FONT)
	continue_button.add_theme_font_size_override("font_size", 28)
	continue_button.add_theme_constant_override("outline_size", 5)
	continue_button.add_theme_color_override("font_color", Color(1.0, 0.99, 0.97, 1.0))
	continue_button.add_theme_color_override("font_outline_color", Color(0.65, 0.41, 0.04, 1.0))

	var button_normal := StyleBoxFlat.new()
	button_normal.bg_color = Color(0.84, 0.58, 0.16, 1.0)
	button_normal.border_color = Color(0.95, 0.81, 0.3, 1.0)
	button_normal.set_corner_radius_all(26)
	button_normal.set_border_width_all(4)
	button_normal.content_margin_left = 24.0
	button_normal.content_margin_top = 16.0
	button_normal.content_margin_right = 24.0
	button_normal.content_margin_bottom = 16.0

	var button_hover := button_normal.duplicate() as StyleBoxFlat
	button_hover.bg_color = Color(0.9, 0.66, 0.2, 1.0)

	continue_button.add_theme_stylebox_override("normal", button_normal)
	continue_button.add_theme_stylebox_override("hover", button_hover)
	continue_button.add_theme_stylebox_override("focus", button_hover)
	continue_button.add_theme_stylebox_override("pressed", button_hover)
	divider.color = Color(0.92, 0.78, 0.34, 0.55)


func _apply_panel_style(panel: Panel, bg: Color, border: Color, border_width: int, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.45, 0.27, 0.05, 0.2)
	style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", style)
