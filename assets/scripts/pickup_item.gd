extends Node3D

class_name PickupItem

@export var item_data: InventoryItemData
@export_range(1, 99, 1) var quantity := 1
@export var bob_height := 0.18
@export var bob_speed := 1.9

@onready var visual_root: Node3D = $VisualRoot
@onready var icon_label: Label3D = $VisualRoot/IconLabel
@onready var body_mesh: MeshInstance3D = $VisualRoot/BodyMesh
@onready var top_mesh: MeshInstance3D = $VisualRoot/TopMesh
@onready var interaction_target: InteractionTarget = $InteractionTarget

var _base_visual_position := Vector3.ZERO
var _time := 0.0


func _ready() -> void:
	add_to_group(&"pickup_items")
	if visual_root != null:
		_base_visual_position = visual_root.position
	_apply_item_visuals()


func _process(delta: float) -> void:
	if visual_root == null:
		return

	_time += delta * bob_speed
	visual_root.position = _base_visual_position + Vector3(0.0, sin(_time) * bob_height, 0.0)
	visual_root.rotation.y += delta * 0.45


func handle_interaction(_player: Node, inventory: InventoryData) -> bool:
	if inventory == null or item_data == null:
		return false

	var added := inventory.add_item(item_data, quantity)
	if not added:
		return false

	queue_free()
	return true


func _apply_item_visuals() -> void:
	if item_data == null:
		return

	if interaction_target != null:
		interaction_target.interaction_key_text = "E"

	if icon_label != null:
		icon_label.text = item_data.icon_text
		icon_label.modulate = item_data.accent_color

	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = item_data.accent_color.darkened(0.25)
	body_material.roughness = 0.72
	if body_mesh != null:
		body_mesh.material_override = body_material

	var top_material := StandardMaterial3D.new()
	top_material.albedo_color = item_data.accent_color.lightened(0.12)
	top_material.emission_enabled = true
	top_material.emission = item_data.accent_color * 0.24
	top_material.roughness = 0.38
	if top_mesh != null:
		top_mesh.material_override = top_material
