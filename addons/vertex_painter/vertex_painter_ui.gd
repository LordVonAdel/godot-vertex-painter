@tool
class_name VertexPainterUI
extends Control

@export var vertex_painter_3d: VertexPainter3D
@export var input_color: Control
@export var input_brush_size: Slider
@export var input_blend_mode: OptionButton
@export var input_weight: Slider
@export var btn_exit: Button

func _ready() -> void:
	
	if input_color is ColorPickerButton:
		input_color.color_changed.connect(func(_color) -> void: update_from_ui())
	if input_color is ColorPicker:
		input_color.color_changed.connect(func(_color) -> void: update_from_ui())
	input_brush_size.value_changed.connect(func(_value) -> void: update_from_ui())
	input_blend_mode.item_selected.connect(func(_idx)->void: update_from_ui())
	input_weight.value_changed.connect(func(_value)->void: update_from_ui())

	btn_exit.pressed.connect(func() -> void:
		vertex_painter_3d.disable()	
	)

func update_from_ui() -> void:
	vertex_painter_3d.brush_size = input_brush_size.value
	vertex_painter_3d.brush_color = input_color.color
	vertex_painter_3d.brush_weight = input_weight.value
	vertex_painter_3d.brush_blend_mode = input_blend_mode.selected as VertexPainter3D.BlendMode
