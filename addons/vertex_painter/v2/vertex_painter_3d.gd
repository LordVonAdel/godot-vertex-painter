@tool
extends Node3D

const VERTEX_COLOR = preload("res://addons/vertex_painter/shaders/vertex_color.tres")

@onready var mouse_camera_3d: Camera3D = $"../SubViewport/MouseCamera3D"
@onready var sub_viewport = $"../SubViewport"
@onready var debug: MeshInstance3D = $"../Debug"
@onready var debug_vertex: MeshInstance3D = $"../DebugVertex"
@onready var show_debug_check_box = $"../VBoxContainer/ShowDebugCheckBox"

## Brush size in world units
var brush_size: float = 3.0

var brush_color: Color = Color.WHITE

var mesh_i: MeshInstance3D = null
var click_active := false
var active_mdt := MeshDataTool.new()
var pre_mat
var working := false
var cursor_position: Vector3

## Remember if the instance was locked, so we don't change the state when ending our draw
var instance_was_locked: bool

func err(message: String) -> void:
	print("Vertex painter [ERROR]: " + message)

func msg(message: String) -> void:
	print("Vertex painter [INFO]: " + message)

func _process(_delta: float) -> void:
	if !is_enabled():
		return
	
	var _cursor = raycast()
	if _cursor.is_finite():
		cursor_position = _cursor
		debug.global_position = cursor_position
	
	debug.visible = show_debug_check_box.button_pressed
	debug_vertex.visible = show_debug_check_box.button_pressed

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
	
	debug.global_position = point
	return point

func start_paint(event: InputEvent) -> void:	
	click_active = true
	process_move(event)

func stop_paint() -> void:	
	if pre_mat == null:
		pre_mat = VERTEX_COLOR
		mesh_i.set_surface_override_material(0, pre_mat)
	click_active = false

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
		active_mdt.set_vertex_color(idx, brush_color)
		mesh_i.mesh.clear_surfaces()
		active_mdt.commit_to_surface(mesh_i.mesh)

func get_vertices_in_radius(mdt: MeshDataTool, mesh_transform: Transform3D, center: Vector3, radius: float) -> PackedInt32Array:
	var radius_squared := radius * radius
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
		paint()
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
	if is_enabled():
		disable()
	
	mesh_i = target
	instance_was_locked = mesh_i.get_meta("_edit_lock_", false)
	mesh_i.set_meta("_edit_lock_", true)
	mesh_i.update_gizmos()
	
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

func disable() -> void:
	if is_instance_valid(mesh_i):
		if !instance_was_locked:
			mesh_i.remove_meta("_edit_lock_")
		mesh_i.update_gizmos()
			
	mesh_i = null
	mouse_camera_3d.hide()
	debug.hide()
	debug_vertex.hide()

func is_enabled() -> bool:
	return is_instance_valid(mesh_i)
