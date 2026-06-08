extends Control

## Rotating radar sweep: a line arm from center + fading trail arcs,
## plus animated blips drifting across the disc. Bounds-wrapped so
## they always stay inside the radar circle.

@export var color: Color = Color(0.0, 0.918, 1.0, 0.9)
@export var sweep_period: float = 4.0  # seconds per revolution
@export var trail_steps: int = 5
@export var blip_count: int = 5

var _angle: float = 0.0
var _blips: Array[Dictionary] = []
const _BLIP_COLORS: Array[Color] = [
	Color(0.0, 0.918, 1.0, 1.0),   # cyan (friendly)
	Color(0.0, 0.918, 1.0, 1.0),   # cyan
	Color(1.0, 0.3, 0.3, 1.0),     # red (hostile)
	Color(1.0, 0.3, 0.3, 1.0),     # red
	Color(1.0, 0.42, 0.18, 1.0),   # orange (neutral)
]

func _ready() -> void:
	_blips.clear()
	for i in range(blip_count):
		_blips.append({
			"r": randf_range(0.25, 0.85),
			"theta": randf() * TAU,
			"dr": randf_range(-0.08, 0.08),
			"dtheta": randf_range(-0.35, 0.35),
			"color": _BLIP_COLORS[i % _BLIP_COLORS.size()],
			"flash": 0.0,  # 0..1, brightens briefly when sweep passes
		})

func _process(delta: float) -> void:
	var prev_angle := _angle
	_angle += (TAU / sweep_period) * delta
	if _angle > TAU:
		_angle -= TAU
	# Drift blips, bounce off radial bounds so they never leave the disc.
	for blip in _blips:
		blip.theta = wrapf(blip.theta + blip.dtheta * delta, 0.0, TAU)
		blip.r += blip.dr * delta
		if blip.r > 0.9:
			blip.r = 0.9
			blip.dr = -blip.dr
		elif blip.r < 0.15:
			blip.r = 0.15
			blip.dr = -blip.dr
		# Flash when sweep arm crosses the blip angle.
		if _angle_crossed(prev_angle, _angle, blip.theta):
			blip.flash = 1.0
		else:
			blip.flash = maxf(blip.flash - delta * 1.5, 0.0)
	queue_redraw()

func _angle_crossed(a: float, b: float, target: float) -> bool:
	# Handles wrap-around: the sweep jumped from near-TAU back to 0.
	if b < a:
		return target >= a or target <= b
	return target >= a and target <= b

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 4.0
	if radius <= 0.0:
		return
	# Static outer ring (dim)
	var dim := Color(color.r, color.g, color.b, 0.25)
	draw_arc(center, radius, 0.0, TAU, 48, dim, 1.0)
	# Concentric inner ring at 2/3 radius
	draw_arc(center, radius * 0.66, 0.0, TAU, 36, Color(color.r, color.g, color.b, 0.15), 1.0)
	# Crosshair tick marks at cardinals
	for i in range(4):
		var theta := i * PI / 2
		var p1 := center + Vector2(cos(theta), sin(theta)) * (radius - 4.0)
		var p2 := center + Vector2(cos(theta), sin(theta)) * radius
		draw_line(p1, p2, dim, 1.0)
	# Fading trail arcs behind the arm
	for i in range(trail_steps):
		var a := color.a * (1.0 - float(i + 1) / (trail_steps + 1))
		var trail := Color(color.r, color.g, color.b, a)
		var span := 0.15
		var end_a := _angle - i * span
		var start_a := end_a - span
		draw_arc(center, radius - 1.0, start_a, end_a, 12, trail, 2.0)
	# Main sweep arm
	var arm_end := center + Vector2(cos(_angle), sin(_angle)) * radius
	draw_line(center, arm_end, color, 2.0)
	# Blips
	for blip in _blips:
		var r_px: float = blip.r * radius
		var pos := center + Vector2(cos(blip.theta), sin(blip.theta)) * r_px
		var base: Color = blip.color
		var flash: float = blip.flash
		# Core dot, brighter when the sweep just touched it.
		var dot_color := Color(base.r, base.g, base.b, clampf(0.45 + flash * 0.55, 0.0, 1.0))
		draw_circle(pos, 2.5 + flash * 1.5, dot_color)
		# Soft halo while flashing.
		if flash > 0.05:
			var halo_color := Color(base.r, base.g, base.b, flash * 0.35)
			draw_circle(pos, 6.0 + flash * 2.0, halo_color)
	# Center dot
	draw_circle(center, 2.0, color)
