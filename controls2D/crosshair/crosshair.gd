extends Control

## Reticle crosshair: four inner ticks, four outer edge ticks, center dot.
## Self-contained (no addon dependency). Drawn in a 100x100 design space
## that scales to the control's current rect, so it adapts to any size.

@export var color: Color = Color(0.0, 0.918, 1.0, 0.8)
@export var edge_color: Color = Color(0.0, 0.918, 1.0, 0.6)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var sx := size.x / 100.0
	var sy := size.y / 100.0
	var p := func(x: float, y: float) -> Vector2: return Vector2(x * sx, y * sy)
	# Inner ticks (top, bottom, left, right)
	draw_line(p.call(50, 8), p.call(50, 26), color, 2.0)
	draw_line(p.call(50, 74), p.call(50, 92), color, 2.0)
	draw_line(p.call(8, 50), p.call(26, 50), color, 2.0)
	draw_line(p.call(74, 50), p.call(92, 50), color, 2.0)
	# Outer edge ticks
	draw_line(p.call(46, 0), p.call(54, 0), edge_color, 1.0)
	draw_line(p.call(46, 100), p.call(54, 100), edge_color, 1.0)
	draw_line(p.call(0, 46), p.call(0, 54), edge_color, 1.0)
	draw_line(p.call(100, 46), p.call(100, 54), edge_color, 1.0)
	# Center dot
	draw_circle(p.call(50, 50), 2.0, color)
