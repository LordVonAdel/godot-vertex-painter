@tool
class_name VertexPainter3D
extends Node3D

const VERTEX_COLOR = preload("res://addons/vertex_painter/shaders/vertex_color.tres")

@onready var mouse_camera_3d: Camera3D = $"../SubViewport/MouseCamera3D"
@onready var sub_viewport = $"../SubViewport"
@export var preview_sphere: MeshInstance3D

signal enabled_changed

enum BlendMode {
	MIX = 0,
	ADD = 1,
	SUBTRACT = 2,
	MULTIPLY = 3
}

enum EditMode {
	PAINT = 0,
	BLUR = 1,
	SCULPT = 2
}

var current_mode = EditMode.PAINT

## Brush size in world units
var brush_size: float = 0.1 : 
	set(value):
		preview_sphere.scale = Vector3(value, value, value)
		brush_size = value

var brush_color: Color = Color.WHITE

var brush_weight: float = 1.0

var brush_blend_mode: BlendMode = BlendMode.MIX

var mesh_i: MeshInstance3D = null
var click_active := false
var active_mdt := MeshDataTool.new()
var pre_mat
var working := false
var cursor_position: Vector3

## Used to push into undo history
var previous_state: ArrayMesh

func _process(_delta: float) -> void:
	if !is_enabled():
		return
	
	var _cursor = raycast()
	if _cursor.is_finite():
		cursor_position = _cursor
		preview_sphere.global_position = cursor_position

func raycast() -> Vector3:
	var viewport := EditorInterface.get_editor_viewport_3d()
	var mouse_pos := viewport.get_mouse_position()
	var camera := viewport.get_camera_3d()
	
	var src_pos: Vector3 = camera.project_ray_origin(mouse_pos)
	var direction: Vector3 = camera.project_ray_normal(mouse_pos).normalized()

	mouse_camera_3d.global_position = src_pos - direction
	
	var point: Vector3
	if is_zero_approx((direction - Vector3(0, -1, 0)).length_squared()):
		mouse_camera_3d.rotation_degrees = Vector3(-90, 0, 0)
		point = src_pos
	else:
		mouse_camera_3d.look_at(mouse_camera_3d.global_position + direction, Vector3.UP)
		sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		var vp_tex: ViewportTexture = sub_viewport.get_texture()
		var vp_img := vp_tex.get_image()
		
		var screen_depth = vp_img.get_pixel(1, 1).srgb_to_linear()
		
		var screen_rg = Vector2(screen_depth.r, screen_depth.g)
		var normalized_distance: float = screen_rg.dot(Vector2(1, 1.0 / 255.0))

		if (is_zero_approx(normalized_distance)):
			return Vector3(-INF, -INF, -INF)
		
		if (normalized_distance > 0.9999):
			normalized_distance = 1.0
		
		var depth: float = normalized_distance * mouse_camera_3d.far
		point = mouse_camera_3d.global_position + direction * depth
	
	return point

func start_paint(event: InputEvent) -> void:	
	previous_state = mesh_i.mesh.duplicate()
	active_mdt.create_from_surface(mesh_i.mesh, 0)
	
	click_active = true
	process_move(event)

func stop_paint() -> void:
	if pre_mat == null:
		pre_mat = VERTEX_COLOR
		mesh_i.set_surface_override_material(0, pre_mat)
	click_active = false
	
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Vertex Paint")
	undo_redo.add_undo_property(mesh_i, "mesh", previous_state)
	undo_redo.commit_action(true)

func process_click(event: InputEvent) -> void:
	var mb_event: InputEventMouseButton = event

	if mb_event.button_index == 1:
		if mb_event.pressed:
			start_paint(event)
		
		if not mb_event.pressed:
			stop_paint()

func paint() -> void:
	var vertices := get_vertices_in_radius(active_mdt, mesh_i.global_transform, cursor_position, brush_size)
	
	for idx in vertices:
		var old_color = active_mdt.get_vertex_color(idx)
		var new_color = brush_color
		match brush_blend_mode:
			BlendMode.MIX:
				new_color = lerp(old_color, brush_color, brush_weight)
			BlendMode.ADD:
				new_color = old_color + brush_color * brush_weight
			BlendMode.SUBTRACT:
				new_color = old_color - brush_color * brush_weight
			BlendMode.MULTIPLY:
				new_color = lerp(old_color, old_color * brush_color, brush_weight)

		active_mdt.set_vertex_color(idx, new_color)
		mesh_i.mesh.clear_surfaces()
		active_mdt.commit_to_surface(mesh_i.mesh)

func blur() -> void:
	var vertices := get_vertices_in_radius(active_mdt, mesh_i.global_transform, cursor_position, brush_size)
	var new_colors: Dictionary[int, Color] = {}

	for vertex in vertices:
		var old_color := active_mdt.get_vertex_color(vertex)
		var neighbor_color := Vector3(old_color.r, old_color.g, old_color.b)
		var neighbor_count := 1

		for edge in active_mdt.get_vertex_edges(vertex):
			for edge_vertex in [active_mdt.get_edge_vertex(edge, 0), active_mdt.get_edge_vertex(edge, 1)]:
				if edge_vertex != vertex:
					var c := active_mdt.get_vertex_color(edge_vertex)
					neighbor_color += Vector3(c.r, c.g, c.b)
					neighbor_count += 1
		
		neighbor_color /= neighbor_count
		new_colors[vertex] = Color(neighbor_color.x, neighbor_color.y, neighbor_color.z)

	for vertex in new_colors.keys():
		var old_color = active_mdt.get_vertex_color(vertex)
		active_mdt.set_vertex_color(vertex, lerp(old_color, new_colors[vertex], brush_weight))

	mesh_i.mesh.clear_surfaces()
	active_mdt.commit_to_surface(mesh_i.mesh)

func sculpt() -> void:
	pass

func get_vertices_in_radius(mdt: MeshDataTool, mesh_transform: Transform3D, center: Vector3, radius: float) -> PackedInt32Array:
	var radius_squared := (radius * 0.5) * (radius * 0.5)
	var local_point := center * mesh_transform

	var out = PackedInt32Array()
	for index in range(mdt.get_vertex_count()):
		var vertex := mdt.get_vertex(index)
		if vertex.distance_squared_to(local_point) <= radius_squared:
			out.append(index)
	return out

func process_move(_event: InputEvent) -> void:
	if not working:
		working = true
		
		if current_mode == EditMode.PAINT:
			paint()
		elif current_mode == EditMode.BLUR:
			blur()
		elif current_mode == EditMode.SCULPT:
			sculpt()
		
		await get_tree().create_timer(0.05).timeout
		working = false

func _forward_3d_gui_input(_cam: Camera3D, event: InputEvent) -> int:	
	if not (event is InputEventMouseButton) and \
		not (event is InputEventMouseMotion): return EditorPlugin.AFTER_GUI_INPUT_PASS
	
	if event is InputEventMouseButton:
		process_click(event)
		
	if event is InputEventMouseMotion:
		if click_active:
			process_move(event)
	
	return EditorPlugin.AFTER_GUI_INPUT_STOP if click_active else EditorPlugin.AFTER_GUI_INPUT_PASS

func enable(target: MeshInstance3D) -> void:
	mesh_i = target

	if not mesh_i.mesh is ArrayMesh:
		var surface_tool := SurfaceTool.new()
		surface_tool.create_from(mesh_i.mesh, 0)
		mesh_i.mesh = surface_tool.commit()
	
	active_mdt.create_from_surface(mesh_i.mesh, 0)
	mesh_i.mesh = ArrayMesh.new()
	active_mdt.commit_to_surface(mesh_i.mesh)
	pre_mat = mesh_i.get_surface_override_material(0)
	mesh_i.set_surface_override_material(0, VERTEX_COLOR)
	mouse_camera_3d.show()

	preview_sphere.show()
	enabled_changed.emit()

func disable() -> void:
	mesh_i = null
	mouse_camera_3d.hide()
	preview_sphere.hide()
	enabled_changed.emit()

func is_enabled() -> bool:
	return is_instance_valid(mesh_i)
