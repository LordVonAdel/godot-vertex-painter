@tool
class_name VertexPainterUI
extends Control

@export var vertex_painter_3d: VertexPainter3D
@export var input_color: Control
@export var input_brush_size: Slider
@export var input_blend_mode: OptionButton
@export var input_weight: Slider
@export var input_sculpt_mode: OptionButton
@export var btn_exit: Button

@export var label_size: Label
@export var label_weight: Label

@export var input_edit_mode: OptionButton

func _ready() -> void:
	
	if input_color is ColorPickerButton:
		input_color.color_changed.connect(func(_color) -> void: update_from_ui())
	if input_color is ColorPicker:
		input_color.color_changed.connect(func(_color) -> void: update_from_ui())
	input_brush_size.value_changed.connect(func(_value) -> void: update_from_ui())
	input_blend_mode.item_selected.connect(func(_idx)->void: update_from_ui())
	input_weight.value_changed.connect(func(_value)->void: update_from_ui())
	input_edit_mode.item_selected.connect(func(idx) -> void: update_from_ui())
	input_sculpt_mode.item_selected.connect(func(idx) -> void: update_from_ui())

	btn_exit.pressed.connect(func() -> void:
		vertex_painter_3d.disable()	
	)
	
	update_ui()

func update_from_ui() -> void:
	vertex_painter_3d.brush_size = input_brush_size.value
	vertex_painter_3d.brush_color = input_color.color
	vertex_painter_3d.brush_weight = input_weight.value
	vertex_painter_3d.brush_blend_mode = input_blend_mode.selected as VertexPainter3D.BlendMode
	vertex_painter_3d.current_mode = input_edit_mode.selected as VertexPainter3D.EditMode
	vertex_painter_3d.sculpt_mode = input_sculpt_mode.selected as VertexPainter3D.SculptMode
	update_ui()

func update_ui() -> void:
	label_size.text = "Size %s" % vertex_painter_3d.brush_size
	label_weight.text = "Weight %s" % vertex_painter_3d.brush_weight

	input_color.visible = vertex_painter_3d.current_mode == VertexPainter3D.EditMode.PAINT
	input_blend_mode.visible = vertex_painter_3d.current_mode == VertexPainter3D.EditMode.PAINT
	input_sculpt_mode.visible = vertex_painter_3d.current_mode == VertexPainter3D.EditMode.SCULPT
