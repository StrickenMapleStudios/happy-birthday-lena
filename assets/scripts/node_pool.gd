class_name NodePool
extends Node

var _pools: Dictionary = {}


func configure_pool(
	pool_id: StringName,
	factory: Callable,
	size: int = 1,
	setup_callback: Callable = Callable()
) -> void:
	if not factory.is_valid():
		return

	var desired_size := maxi(size, 1)
	var pool: Dictionary = _pools.get(pool_id, {
		"factory": factory,
		"setup_callback": setup_callback,
		"entries": [],
		"next_index": 0,
	})

	pool["factory"] = factory
	pool["setup_callback"] = setup_callback

	var entries: Array = pool.get("entries", [])
	while entries.size() < desired_size:
		var instance = factory.call()
		if instance == null:
			break

		add_child(instance)
		entries.append({
			"node": instance,
			"in_use": false,
		})

	while entries.size() > desired_size:
		var removed_entry: Dictionary = entries.pop_back()
		var removed_node: Node = removed_entry.get("node")
		if is_instance_valid(removed_node):
			removed_node.queue_free()

	if setup_callback.is_valid():
		for entry in entries:
			var node: Node = entry.get("node")
			if is_instance_valid(node):
				setup_callback.call(node)

	pool["entries"] = entries
	pool["next_index"] = mini(int(pool.get("next_index", 0)), maxi(entries.size() - 1, 0))
	_pools[pool_id] = pool


func acquire(pool_id: StringName, allow_reuse_in_use: bool = false) -> Node:
	var pool: Dictionary = _pools.get(pool_id, {})
	if pool.is_empty():
		return null

	var entries: Array = pool.get("entries", [])
	if entries.is_empty():
		return null

	if not allow_reuse_in_use:
		for entry_index in entries.size():
			var entry: Dictionary = entries[entry_index]
			if bool(entry.get("in_use", false)):
				continue

			var free_node: Node = entry.get("node")
			if not is_instance_valid(free_node):
				continue

			entry["in_use"] = true
			entries[entry_index] = entry
			pool["entries"] = entries
			_pools[pool_id] = pool
			return free_node

	var index := int(pool.get("next_index", 0)) % entries.size()
	pool["next_index"] = (index + 1) % entries.size()

	var selected_entry: Dictionary = entries[index]
	var selected_node: Node = selected_entry.get("node")
	if not is_instance_valid(selected_node):
		_pools[pool_id] = pool
		return null

	selected_entry["in_use"] = true
	entries[index] = selected_entry
	pool["entries"] = entries
	_pools[pool_id] = pool
	return selected_node


func release(pool_id: StringName, instance: Node, reset_callback: Callable = Callable()) -> void:
	if instance == null:
		return

	var pool: Dictionary = _pools.get(pool_id, {})
	if pool.is_empty():
		return

	var entries: Array = pool.get("entries", [])
	for entry_index in entries.size():
		var entry: Dictionary = entries[entry_index]
		if entry.get("node") != instance:
			continue

		entry["in_use"] = false
		entries[entry_index] = entry
		pool["entries"] = entries
		_pools[pool_id] = pool
		if reset_callback.is_valid():
			reset_callback.call(instance)
		return


func release_all(pool_id: StringName, reset_callback: Callable = Callable()) -> void:
	var pool: Dictionary = _pools.get(pool_id, {})
	if pool.is_empty():
		return

	var entries: Array = pool.get("entries", [])
	for entry_index in entries.size():
		var entry: Dictionary = entries[entry_index]
		entry["in_use"] = false
		entries[entry_index] = entry
		var node: Node = entry.get("node")
		if reset_callback.is_valid() and is_instance_valid(node):
			reset_callback.call(node)

	pool["entries"] = entries
	_pools[pool_id] = pool


func clear_pool(pool_id: StringName) -> void:
	var pool: Dictionary = _pools.get(pool_id, {})
	if pool.is_empty():
		return

	var entries: Array = pool.get("entries", [])
	for entry in entries:
		var node: Node = entry.get("node")
		if is_instance_valid(node):
			node.queue_free()

	_pools.erase(pool_id)
