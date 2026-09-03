extends Node

var _overlay: ColorRect

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	layer.add_child(_overlay)

func fade_out(sec: float) -> void:
	_overlay.visible = true
	_overlay.color = Color(0, 0, 0, 0)
	var tw := create_tween()
	tw.tween_property(_overlay, "color:a", 1.0, sec)
	await tw.finished

func fade_in(sec: float) -> void:
	_overlay.visible = true
	_overlay.color = Color(0, 0, 0, 1)
	var tw := create_tween()
	tw.tween_property(_overlay, "color:a", 0.0, sec)
	await tw.finished
	_overlay.visible = false
