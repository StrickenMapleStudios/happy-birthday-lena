@tool
extends EditorScenePostImport

# Этот метод запускается автоматически при импорте
func _post_import(scene):
	_process_node(scene)
	return scene

func _process_node(node):
	if node is Light3D:
		# Делим энергию на 100. Подберите число под себя.
		node.light_energy /= 10000.0
	
	# Рекурсивно проходим по всем дочерним объектам (лампочкам гирлянды)
	for child in node.get_children():
		_process_node(child)
