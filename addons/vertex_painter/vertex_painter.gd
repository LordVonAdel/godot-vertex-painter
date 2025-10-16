@tool
extends EditorPlugin

#var dock
const MAIN_SCREEN = preload("res://addons/vertex_painter/vertex_painter_ui.tscn")

var main_panel_instance

func _enter_tree():
	main_panel_instance = MAIN_SCREEN.instantiate()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UR, main_panel_instance)

func _exit_tree():
	remove_control_from_docks(main_panel_instance)
	main_panel_instance.free()

func _forward_3d_gui_input(cam: Camera3D, event: InputEvent) -> int:
	if main_panel_instance.is_enabled():
		return main_panel_instance.vertex_painter_3d._forward_3d_gui_input(cam, event)
	else:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

func _handles(object: Object) -> bool:
	return object is MeshInstance3D
