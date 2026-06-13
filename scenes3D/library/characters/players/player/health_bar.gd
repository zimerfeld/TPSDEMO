extends CanvasLayer

var _bar: ProgressBar
var _label: Label


func _ready() -> void:
	layer = 10

	var panel := PanelContainer.new()
	# Ancora no canto inferior esquerdo, mas elevado da borda para não cortar na tela.
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 24.0
	panel.offset_right = 24.0
	panel.offset_top = -72.0
	panel.offset_bottom = -72.0
	panel.grow_horizontal = Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.75)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	_label = Label.new()
	_label.text = "HP: 100 / 100"
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_label)

	_bar = ProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.value = 100
	_bar.custom_minimum_size = Vector2(200, 18)
	_bar.show_percentage = false

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.25, 0.05, 0.05, 1.0)
	bg_style.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.85, 0.1, 0.1, 1.0)
	fill_style.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill_style)

	vbox.add_child(_bar)
	add_child(panel)


func update_health(current: int, maximum: int) -> void:
	if not _bar:
		return
	_bar.max_value = maximum
	_bar.value = current
	_label.text = "HP: %d / %d" % [current, maximum]

	# Muda cor conforme HP: verde > amarelo > vermelho
	var ratio: float = float(current) / float(maximum)
	var fill_style := StyleBoxFlat.new()
	fill_style.set_corner_radius_all(4)
	if ratio > 0.5:
		fill_style.bg_color = Color(0.1, 0.75, 0.1, 1.0)
	elif ratio > 0.25:
		fill_style.bg_color = Color(0.9, 0.7, 0.0, 1.0)
	else:
		fill_style.bg_color = Color(0.85, 0.1, 0.1, 1.0)
	_bar.add_theme_stylebox_override("fill", fill_style)
