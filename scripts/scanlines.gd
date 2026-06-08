extends Control

## Full-screen scanline overlay — thin horizontal lines at regular intervals.
## Drifts downward at `scroll_speed` pixels per second for a CRT-refresh feel.
## Pass-through mouse.

@export var color: Color = Color(1.0, 1.0, 1.0, 0.05)
@export var spacing: int = 3
@export var line_width: float = 1.0
@export var scroll_speed: float = 1.2  # pixels per second

var _offset: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if scroll_speed == 0.0 or spacing < 1:
		return
	_offset = fposmod(_offset + scroll_speed * delta, float(spacing))
	queue_redraw()

func _draw() -> void:
	if spacing < 1 or size.y <= 0.0 or size.x <= 0.0:
		return
	# Start a row above the top so scrolled lines enter smoothly from y<0.
	var y := _offset - float(spacing)
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), color, line_width)
		y += spacing
