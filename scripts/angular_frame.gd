extends Control

## Angular HUD panel frame. Child of a PanelContainer.
##
## On _ready() it duplicates the parent's "panel" stylebox and zeroes out
## border_width / corner_radius / shadow so the vector outline owns the
## frame. The parent's bg_color and content_margin are preserved.
##
## _draw() renders:
##   * angular outline polyline (with one or more diagonally cut corners)
##   * inner double-stroke at lower alpha (depth)
##   * chevron band at the top edge (parallelogram accents)
##   * ruler tick marks along the bottom edge
##   * small outward "corner flags" for the HUD panel look

@export var color: Color = Color(0.0, 0.918, 1.0, 1.0)
@export var outline_width: float = 2.0

@export_group("Corner cuts")
@export var corner_cut: float = 14.0
@export var cut_top_left: bool = false
@export var cut_top_right: bool = true
@export var cut_bottom_left: bool = false
@export var cut_bottom_right: bool = false

@export_group("Inner stroke")
@export var inner_inset: float = 5.0
@export var inner_alpha: float = 0.35
@export var inner_width: float = 1.0

@export_group("Chevron band")
@export var chevron_count: int = 4
@export var chevron_width: float = 16.0
@export var chevron_height: float = 7.0
@export var chevron_gap: float = 5.0
@export var chevron_slant: float = 4.0
@export var chevron_y_offset: float = 2.0

@export_group("Tick marks")
@export var tick_count: int = 10
@export var tick_length: float = 4.0
@export var tick_alpha: float = 0.55
@export var tick_inset: float = 24.0

@export_group("Corner flags")
@export var flag_size: float = 7.0
@export var flag_inset: float = 10.0

var _ml: float = 0.0
var _mt: float = 0.0
var _mr: float = 0.0
var _mb: float = 0.0
var _bg_color: Color = Color(0.04, 0.05, 0.12, 0.85)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_install_override_stylebox()
	_cache_parent_margins()
	# PanelContainer resizes us after layout settles; redraw when our rect
	# changes so the outline always traces the current panel bounds.
	resized.connect(queue_redraw)
	queue_redraw()

func _install_override_stylebox() -> void:
	var parent := get_parent() as Control
	if parent == null:
		return
	var sb := parent.get_theme_stylebox("panel")
	if sb == null:
		return
	var sbf := sb.duplicate() as StyleBoxFlat
	if sbf == null:
		return
	# Take over the bg fill so the diagonal corner cut clips the fill too
	# (the default rectangular bg pokes past our polyline otherwise).
	_bg_color = sbf.bg_color
	sbf.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	sbf.border_width_left = 0
	sbf.border_width_top = 0
	sbf.border_width_right = 0
	sbf.border_width_bottom = 0
	sbf.corner_radius_top_left = 0
	sbf.corner_radius_top_right = 0
	sbf.corner_radius_bottom_left = 0
	sbf.corner_radius_bottom_right = 0
	sbf.shadow_size = 0
	parent.add_theme_stylebox_override("panel", sbf)

func _cache_parent_margins() -> void:
	var parent := get_parent() as Control
	if parent == null:
		return
	var sb := parent.get_theme_stylebox("panel")
	if sb == null:
		return
	_ml = sb.get_margin(SIDE_LEFT)
	_mt = sb.get_margin(SIDE_TOP)
	_mr = sb.get_margin(SIDE_RIGHT)
	_mb = sb.get_margin(SIDE_BOTTOM)

func _draw() -> void:
	# Local origin sits at (content_margin_left, content_margin_top) relative
	# to the panel's outer rect. Shift into outer-rect coordinates.
	var x0 := -_ml
	var y0 := -_mt
	var x1 := size.x + _mr
	var y1 := size.y + _mb
	if x1 - x0 <= 0.0 or y1 - y0 <= 0.0:
		return

	var outer_path := _frame_path(x0, y0, x1, y1, corner_cut)
	# Fill first so everything else paints on top of it.
	_draw_fill(outer_path, _bg_color)
	_draw_outline(outer_path, color, outline_width)
	if inner_inset > 0.0:
		var inner_cut := maxf(corner_cut - inner_inset, 2.0)
		var ic := Color(color.r, color.g, color.b, color.a * inner_alpha)
		var inner_path := _frame_path(
			x0 + inner_inset, y0 + inner_inset,
			x1 - inner_inset, y1 - inner_inset,
			inner_cut
		)
		_draw_outline(inner_path, ic, inner_width)
	_draw_chevrons(x0, y0, x1)
	_draw_ticks(x0, x1, y1)
	_draw_corner_flags(x0, y0, x1, y1)

func _frame_path(
	x0: float, y0: float, x1: float, y1: float, cut: float
) -> PackedVector2Array:
	var points := PackedVector2Array()
	# Walk clockwise from top-left, inserting diagonal cuts at enabled corners.
	if cut_top_left and cut > 0.0:
		points.append(Vector2(x0, y0 + cut))
		points.append(Vector2(x0 + cut, y0))
	else:
		points.append(Vector2(x0, y0))
	if cut_top_right and cut > 0.0:
		points.append(Vector2(x1 - cut, y0))
		points.append(Vector2(x1, y0 + cut))
	else:
		points.append(Vector2(x1, y0))
	if cut_bottom_right and cut > 0.0:
		points.append(Vector2(x1, y1 - cut))
		points.append(Vector2(x1 - cut, y1))
	else:
		points.append(Vector2(x1, y1))
	if cut_bottom_left and cut > 0.0:
		points.append(Vector2(x0 + cut, y1))
		points.append(Vector2(x0, y1 - cut))
	else:
		points.append(Vector2(x0, y1))
	return points

func _draw_fill(path: PackedVector2Array, c: Color) -> void:
	if c.a <= 0.0 or path.size() < 3:
		return
	draw_polygon(path, PackedColorArray([c]))

func _draw_outline(path: PackedVector2Array, c: Color, w: float) -> void:
	var loop := path.duplicate()
	loop.append(loop[0])
	draw_polyline(loop, c, w, true)

func _draw_chevrons(x0: float, y0: float, x1: float) -> void:
	if chevron_count <= 0 or chevron_width <= 0.0:
		return
	var total_width := chevron_count * chevron_width + (chevron_count - 1) * chevron_gap
	var start_x := (x0 + x1) * 0.5 - total_width * 0.5
	var cy := y0 + chevron_y_offset
	for i in chevron_count:
		var cx := start_x + i * (chevron_width + chevron_gap)
		var pts := PackedVector2Array([
			Vector2(cx, cy + chevron_height),
			Vector2(cx + chevron_slant, cy),
			Vector2(cx + chevron_width, cy),
			Vector2(cx + chevron_width - chevron_slant, cy + chevron_height),
		])
		draw_polygon(pts, PackedColorArray([color]))

func _draw_ticks(x0: float, x1: float, y1: float) -> void:
	if tick_count < 2:
		return
	var span := (x1 - x0) - tick_inset * 2.0
	if span <= 0.0:
		return
	var step := span / float(tick_count - 1)
	var dim := Color(color.r, color.g, color.b, color.a * tick_alpha)
	for i in tick_count:
		var x := x0 + tick_inset + i * step
		draw_line(Vector2(x, y1 - tick_length), Vector2(x, y1), dim, 1.0, true)

func _draw_corner_flags(x0: float, y0: float, x1: float, y1: float) -> void:
	if flag_size <= 0.0:
		return
	# Short outward ticks near the bottom-left and top-right-opposite corners
	# echo the "flag" marks on the reference panels.
	draw_line(Vector2(x0, y1 - flag_inset), Vector2(x0 - flag_size, y1 - flag_inset), color, outline_width, true)
	draw_line(Vector2(x1 - flag_inset, y1), Vector2(x1 - flag_inset, y1 + flag_size), color, outline_width, true)
