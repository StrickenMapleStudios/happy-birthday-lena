extends Node

class_name InventoryData

signal inventory_changed
signal category_changed(category: StringName)
signal selection_changed(category: StringName, slot_index: int)
signal item_added(item: InventoryItemData, quantity: int)

const CATEGORY_REGULAR := &"regular"
const CATEGORY_KEYS := &"keys"
const CATEGORY_QUEST := &"quest"
const CATEGORY_ORDER: Array[StringName] = [
	CATEGORY_KEYS,
	CATEGORY_REGULAR,
	CATEGORY_QUEST,
]
const SLOTS_PER_CATEGORY: int = 16

var _slots_by_category: Dictionary = {}
var _selected_category: StringName = CATEGORY_REGULAR
var _selected_slot_by_category: Dictionary = {
	CATEGORY_REGULAR: 0,
	CATEGORY_KEYS: 0,
	CATEGORY_QUEST: 0,
}


func _init() -> void:
	for category in CATEGORY_ORDER:
		_slots_by_category[category] = _build_empty_slots()


func add_item(item: InventoryItemData, quantity: int = 1) -> bool:
	if item == null or quantity <= 0:
		return false

	var category: StringName = item.get_category_key()
	var slots: Array = _slots_by_category.get(category, [])
	if slots.is_empty():
		return false

	var remaining: int = quantity
	if item.stackable:
		for slot_index in range(slots.size()):
			var slot: Dictionary = slots[slot_index]
			if slot.get("item") != item:
				continue
			if int(slot.get("quantity", 0)) >= item.max_stack:
				continue

			var space_left: int = item.max_stack - int(slot.get("quantity", 0))
			var to_add: int = mini(space_left, remaining)
			slot["quantity"] = int(slot.get("quantity", 0)) + to_add
			_mark_slot_as_new(category, slot_index)
			remaining -= to_add
			if remaining <= 0:
				break

	for slot_index in range(slots.size()):
		var slot: Dictionary = slots[slot_index]
		if remaining <= 0:
			break
		if slot.get("item") != null:
			continue

		var stack_size: int = 1
		if item.stackable:
			stack_size = mini(item.max_stack, remaining)

		slot["item"] = item
		slot["quantity"] = stack_size
		_mark_slot_as_new(category, slot_index)
		remaining -= stack_size

	if remaining == quantity:
		return false

	_ensure_valid_selection_for_category(category)
	inventory_changed.emit()
	item_added.emit(item, quantity - remaining)
	return true


func get_slots(category: StringName) -> Array:
	return _slots_by_category.get(category, [])


func get_selected_category() -> StringName:
	return _selected_category


func set_selected_category(category: StringName) -> void:
	if not _slots_by_category.has(category):
		return
	if _selected_category == category:
		emit_current_selection()
		return

	_selected_category = category
	_reset_selection_for_category(category)
	mark_selected_slot_viewed()
	category_changed.emit(category)
	selection_changed.emit(category, get_selected_slot_index(category))


func get_selected_slot_index(category: StringName = &"") -> int:
	if category == &"":
		category = _selected_category
	return int(_selected_slot_by_category.get(category, 0))


func select_slot(slot_index: int, category: StringName = &"") -> void:
	if category == &"":
		category = _selected_category
	var slots: Array = _slots_by_category.get(category, [])
	if slots.is_empty():
		return

	var clamped_index := clampi(slot_index, 0, slots.size() - 1)
	_selected_slot_by_category[category] = clamped_index
	if _selected_category != category:
		_selected_category = category
		category_changed.emit(category)
	mark_slot_viewed(clamped_index, category)
	selection_changed.emit(category, clamped_index)


func get_selected_slot(category: StringName = &"") -> Dictionary:
	if category == &"":
		category = _selected_category
	var slots: Array = get_slots(category)
	if slots.is_empty():
		return {}

	var slot_index: int = clampi(get_selected_slot_index(category), 0, slots.size() - 1)
	return slots[slot_index]


func find_first_occupied_slot_index(category: StringName) -> int:
	var slots: Array = get_slots(category)
	for slot_index in range(slots.size()):
		if slots[slot_index].get("item") != null:
			return slot_index

	return 0


func is_slot_new(slot_index: int, category: StringName = &"") -> bool:
	if category == &"":
		category = _selected_category
	var slots: Array = get_slots(category)
	if slot_index < 0 or slot_index >= slots.size():
		return false

	return bool(slots[slot_index].get("is_new", false))


func has_new_items(category: StringName) -> bool:
	var slots: Array = get_slots(category)
	for slot in slots:
		if bool(slot.get("is_new", false)):
			return true

	return false


func mark_selected_slot_viewed() -> void:
	mark_slot_viewed(get_selected_slot_index(), _selected_category)


func mark_slot_viewed(slot_index: int, category: StringName = &"") -> void:
	if category == &"":
		category = _selected_category
	var slots: Array = get_slots(category)
	if slot_index < 0 or slot_index >= slots.size():
		return
	if slots[slot_index].get("item") == null:
		return
	if not bool(slots[slot_index].get("is_new", false)):
		return

	slots[slot_index]["is_new"] = false
	inventory_changed.emit()


func emit_current_selection() -> void:
	mark_selected_slot_viewed()
	selection_changed.emit(_selected_category, get_selected_slot_index())


func _ensure_valid_selection_for_category(category: StringName) -> void:
	var slots: Array = get_slots(category)
	if slots.is_empty():
		_selected_slot_by_category[category] = 0
		return

	var current_index: int = clampi(get_selected_slot_index(category), 0, slots.size() - 1)
	if slots[current_index].get("item") != null:
		_selected_slot_by_category[category] = current_index
		return

	_selected_slot_by_category[category] = find_first_occupied_slot_index(category)


func _reset_selection_for_category(category: StringName) -> void:
	var slots: Array = get_slots(category)
	if slots.is_empty():
		_selected_slot_by_category[category] = 0
		return

	_selected_slot_by_category[category] = find_first_occupied_slot_index(category)


func _build_empty_slots() -> Array:
	var slots: Array = []
	for slot_index in range(SLOTS_PER_CATEGORY):
		slots.append({
			"index": slot_index,
			"item": null,
			"quantity": 0,
			"is_new": false,
		})
	return slots


func _mark_slot_as_new(category: StringName, slot_index: int) -> void:
	var slots: Array = get_slots(category)
	if slot_index < 0 or slot_index >= slots.size():
		return

	slots[slot_index]["is_new"] = true


func serialize_state() -> Dictionary:
	var serialized_slots_by_category := {}
	for category in CATEGORY_ORDER:
		var serialized_slots: Array[Dictionary] = []
		var slots: Array = get_slots(category)
		for slot in slots:
			var item := slot.get("item") as InventoryItemData
			serialized_slots.append({
				"item_path": item.resource_path if item != null else "",
				"quantity": int(slot.get("quantity", 0)),
				"is_new": bool(slot.get("is_new", false)),
			})
		serialized_slots_by_category[String(category)] = serialized_slots

	return {
		"selected_category": String(_selected_category),
		"selected_slot_by_category": {
			String(CATEGORY_REGULAR): int(_selected_slot_by_category.get(CATEGORY_REGULAR, 0)),
			String(CATEGORY_KEYS): int(_selected_slot_by_category.get(CATEGORY_KEYS, 0)),
			String(CATEGORY_QUEST): int(_selected_slot_by_category.get(CATEGORY_QUEST, 0)),
		},
		"slots_by_category": serialized_slots_by_category,
	}


func restore_state(state: Dictionary) -> void:
	_slots_by_category.clear()
	for category in CATEGORY_ORDER:
		_slots_by_category[category] = _build_empty_slots()

	var slots_by_category: Dictionary = state.get("slots_by_category", {})
	for category in CATEGORY_ORDER:
		var serialized_slots: Array = slots_by_category.get(String(category), [])
		var restored_slots: Array = _build_empty_slots()
		for slot_index in range(mini(serialized_slots.size(), restored_slots.size())):
			var serialized_slot: Dictionary = serialized_slots[slot_index]
			var item_path := String(serialized_slot.get("item_path", ""))
			var item: InventoryItemData = load(item_path) as InventoryItemData if not item_path.is_empty() else null
			restored_slots[slot_index] = {
				"index": slot_index,
				"item": item,
				"quantity": int(serialized_slot.get("quantity", 0)),
				"is_new": bool(serialized_slot.get("is_new", false)),
			}
		_slots_by_category[category] = restored_slots
		_ensure_valid_selection_for_category(category)

	var selected_slot_state: Dictionary = state.get("selected_slot_by_category", {})
	for category in CATEGORY_ORDER:
		_selected_slot_by_category[category] = clampi(
			int(selected_slot_state.get(String(category), 0)),
			0,
			SLOTS_PER_CATEGORY - 1
		)

	var selected_category_text := String(state.get("selected_category", String(CATEGORY_REGULAR)))
	var selected_category := StringName(selected_category_text)
	_selected_category = selected_category if _slots_by_category.has(selected_category) else CATEGORY_REGULAR
	inventory_changed.emit()
	category_changed.emit(_selected_category)
	selection_changed.emit(_selected_category, get_selected_slot_index(_selected_category))
