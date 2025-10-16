@tool
extends CenterContainer

@onready var vertex_painter_3d = $VertexPainter3D

@export var input_color: ColorPicker
@export var input_brush_size: SpinBox
@export var input_enabled: CheckBox

func _enter_tree() -> void:
	EditorInterface.get_selection().selection_changed.connect(_selection_changed)

func _exit_tree() -> void:
	EditorInterface.get_selection().selection_changed.disconnect(_selection_changed)

func _ready() -> void:
	input_color.color_changed.connect(func(_color) -> void: update_from_ui())
	input_brush_size.value_changed.connect(func(_value) -> void: update_from_ui())
	input_enabled.pressed.connect(func() -> void: _update_enabled())

func update_from_ui() -> void:
	vertex_painter_3d.brush_size = input_brush_size.value
	vertex_painter_3d.brush_color = input_color.color

func _selection_changed() -> void:
	vertex_painter_3d.disable()
	input_enabled.button_pressed = false

func _update_enabled():
	var target = find_target()
	
	if input_enabled.button_pressed:
		if !is_instance_valid(target):
			input_enabled.button_pressed = false
			vertex_painter_3d.err("You must select a MeshInstance3D to vertex paint.")
			return
		EditorInterface.set_main_screen_editor("3D")
		update_from_ui()
		vertex_painter_3d.enable(target)
	else:
		vertex_painter_3d.disable()

func find_target() -> MeshInstance3D:
	var nodes := EditorInterface.get_selection().get_selected_nodes()
	for n in nodes:
		if n is MeshInstance3D:
			return n
	return null

func is_enabled() -> bool:
	return input_enabled.button_pressed
