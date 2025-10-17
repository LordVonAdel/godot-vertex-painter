@tool
extends EditorPlugin

#var dock
const MAIN_SCREEN = preload("res://addons/vertex_painter/vertex_painter_top_ui.tscn")

var main_panel_instance: VertexPainterUI
var vertex_painter_3d: VertexPainter3D
var btn_enable: Button

func _enter_tree():
	main_panel_instance = MAIN_SCREEN.instantiate()
	EditorInterface.get_editor_viewport_3d(0).get_parent().get_parent().add_child(main_panel_instance)

	btn_enable = Button.new()
	btn_enable.text = "Vertex Paint"
	btn_enable.flat = true
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, btn_enable)

	btn_enable.pressed.connect(func() -> void:
		var target = find_target()
		if is_instance_valid(target):
			if vertex_painter_3d.is_enabled():
				vertex_painter_3d.disable()
			else:
				vertex_painter_3d.enable(target)
	)

	vertex_painter_3d = main_panel_instance.vertex_painter_3d
	vertex_painter_3d.enabled_changed.connect(_update_ui)

	EditorInterface.get_selection().selection_changed.connect(_update_selection)

func _exit_tree():
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, btn_enable)
	btn_enable.queue_free()

	main_panel_instance.queue_free()
	EditorInterface.get_selection().selection_changed.disconnect(_update_selection)

func _update_selection() -> void:
	vertex_painter_3d.disable()
	var target = find_target()
	btn_enable.visible = is_instance_valid(target)

func _forward_3d_gui_input(cam: Camera3D, event: InputEvent) -> int:
	if vertex_painter_3d.is_enabled():
		return main_panel_instance.vertex_painter_3d._forward_3d_gui_input(cam, event)
	else:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

func _handles(object: Object) -> bool:
	return object is MeshInstance3D

func _update_ui() -> void:
	main_panel_instance.visible = vertex_painter_3d.is_enabled()

func find_target() -> MeshInstance3D:
	var nodes := EditorInterface.get_selection().get_selected_nodes()
	for n in nodes:
		if n is MeshInstance3D:
			return n
	return null
