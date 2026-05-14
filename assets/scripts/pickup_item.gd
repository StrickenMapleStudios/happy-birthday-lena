extends Node3D

class_name PickupItem

@export var item_data: InventoryItemData
@export_range(1, 99, 1) var quantity := 1
@export var bob_height := 0.18
@export var bob_speed := 1.9

@onready var visual_root: Node3D = $VisualRoot
@onready var body_mesh: MeshInstance3D = $VisualRoot/BodyMesh
@onready var top_mesh: MeshInstance3D = $VisualRoot/TopMesh
@onready var custom_visual_anchor: Node3D = $VisualRoot/CustomVisualAnchor
@onready var highlight_light: OmniLight3D = $VisualRoot/HighlightLight
@onready var interaction_target: InteractionTarget = $InteractionTarget

var _base_visual_position := Vector3.ZERO
var _time := 0.0
var _custom_visual_instance: Node3D
var _reward_reveal_tween: Tween


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


func play_reward_reveal(duration: float = 0.45) -> void:
	if visual_root == null:
		return

	if _reward_reveal_tween != null and _reward_reveal_tween.is_valid():
		_reward_reveal_tween.kill()

	_set_visual_transparency(1.0)
	visual_root.scale = Vector3.ONE * 0.7
	if highlight_light != null and highlight_light.visible:
		highlight_light.light_energy = 0.0

	_reward_reveal_tween = create_tween()
	_reward_reveal_tween.set_trans(Tween.TRANS_CUBIC)
	_reward_reveal_tween.set_ease(Tween.EASE_OUT)
	_reward_reveal_tween.parallel().tween_method(Callable(self, "_set_visual_transparency"), 1.0, 0.0, duration)
	_reward_reveal_tween.parallel().tween_property(visual_root, "scale", Vector3.ONE, duration)
	if highlight_light != null and highlight_light.visible and item_data != null:
		_reward_reveal_tween.parallel().tween_property(
			highlight_light,
			"light_energy",
			item_data.world_light_energy,
			duration
		)


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

	_clear_custom_visual()
	_configure_highlight()

	var has_custom_visual := item_data.world_model_scene != null
	if body_mesh != null:
		body_mesh.visible = not has_custom_visual
	if top_mesh != null:
		top_mesh.visible = not has_custom_visual

	if has_custom_visual:
		_spawn_custom_visual()
		return

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


func _configure_highlight() -> void:
	if highlight_light == null or item_data == null:
		return

	var is_enabled := item_data.world_highlight_enabled
	highlight_light.visible = is_enabled
	if not is_enabled:
		return

	highlight_light.light_color = item_data.world_highlight_color
	highlight_light.light_energy = item_data.world_light_energy
	highlight_light.omni_range = item_data.world_light_range


func _spawn_custom_visual() -> void:
	if custom_visual_anchor == null or item_data == null or item_data.world_model_scene == null:
		return

	var instance := item_data.world_model_scene.instantiate() as Node3D
	if instance == null:
		return

	custom_visual_anchor.add_child(instance)
	instance.position = item_data.world_model_offset
	instance.rotation_degrees = item_data.world_model_rotation_degrees
	instance.scale = item_data.world_model_scale
	_custom_visual_instance = instance
	_attach_glow_shells(instance)


func _attach_glow_shells(root: Node) -> void:
	if root == null or item_data == null or not item_data.world_highlight_enabled:
		return

	for child in root.get_children():
		_attach_glow_shells(child)

	var mesh_instance := root as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	if mesh_instance.get_parent() == null:
		return

	var shell := MeshInstance3D.new()
	shell.name = "%sGlowShell" % mesh_instance.name
	shell.mesh = mesh_instance.mesh
	shell.transform = mesh_instance.transform
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.material_override = _build_shell_material(
		item_data.world_highlight_color,
		item_data.world_highlight_energy,
		item_data.world_highlight_scale
	)
	mesh_instance.get_parent().add_child(shell)
	mesh_instance.get_parent().move_child(shell, mesh_instance.get_index() + 1)


func _build_shell_material(color: Color, energy: float, shell_scale: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_front, unshaded;

uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.3, 0.55);
uniform float shell_expand = 0.018;
uniform float fresnel_power = 2.8;
uniform float emission_energy = 1.2;

void vertex() {
	VERTEX += NORMAL * shell_expand;
}

void fragment() {
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), fresnel_power);
	ALBEDO = glow_color.rgb;
	EMISSION = glow_color.rgb * rim * emission_energy;
	ALPHA = rim * glow_color.a;
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("glow_color", Color(color.r, color.g, color.b, 0.62))
	material.set_shader_parameter("shell_expand", lerpf(0.012, 0.028, clampf(shell_scale - 1.0, 0.0, 1.0)))
	material.set_shader_parameter("fresnel_power", 2.5)
	material.set_shader_parameter("emission_energy", energy)
	return material


func _clear_custom_visual() -> void:
	if _custom_visual_instance == null:
		return

	_custom_visual_instance.queue_free()
	_custom_visual_instance = null


func _set_visual_transparency(value: float) -> void:
	var clamped_value := clampf(value, 0.0, 1.0)
	_apply_transparency_to_node(visual_root, clamped_value)


func _apply_transparency_to_node(root: Node, value: float) -> void:
	if root == null:
		return

	var geometry := root as GeometryInstance3D
	if geometry != null:
		geometry.transparency = value

	for child in root.get_children():
		_apply_transparency_to_node(child, value)
