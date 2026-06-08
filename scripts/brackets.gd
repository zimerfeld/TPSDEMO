extends Control

## Adaptive corner brackets: draws four L-shapes at the Control's
## own rect corners. Place as a full_rect child of any PanelContainer
## and the brackets track the panel's actual size automatically.

@export var color: Color = Color(0.0, 0.918, 1.0, 1.0)
@export var arm_length: float = 22.0
@export var thickness: float = 2.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var a := arm_length
	var t := thickness
	# Top-left
	draw_line(Vector2(0, 0), Vector2(a, 0), color, t)
	draw_line(Vector2(0, 0), Vector2(0, a), color, t)
	# Top-right
	draw_line(Vector2(w, 0), Vector2(w - a, 0), color, t)
	draw_line(Vector2(w, 0), Vector2(w, a), color, t)
	# Bottom-left
	draw_line(Vector2(0, h), Vector2(a, h), color, t)
	draw_line(Vector2(0, h), Vector2(0, h - a), color, t)
	# Bottom-right
	draw_line(Vector2(w, h), Vector2(w - a, h), color, t)
	draw_line(Vector2(w, h), Vector2(w, h - a), color, t)
