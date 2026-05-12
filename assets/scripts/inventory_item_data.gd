extends Resource

class_name InventoryItemData

enum ItemCategory {
	REGULAR,
	KEY,
	QUEST,
}

@export var item_id := &""
@export var display_name := ""
@export_multiline var description := ""
@export var category: ItemCategory = ItemCategory.REGULAR
@export var icon_text := "?"
@export var accent_color := Color(1.0, 0.8, 0.2, 1.0)
@export var world_model_scene: PackedScene
@export var world_model_offset := Vector3.ZERO
@export var world_model_rotation_degrees := Vector3.ZERO
@export var world_model_scale := Vector3.ONE
@export var stackable := false
@export_range(1, 99, 1) var max_stack := 1


func get_category_key() -> StringName:
	match category:
		ItemCategory.KEY:
			return &"keys"
		ItemCategory.QUEST:
			return &"quest"
		_:
			return &"regular"
