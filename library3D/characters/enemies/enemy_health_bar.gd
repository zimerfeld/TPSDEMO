extends CanvasLayer

# HUD compartilhado (estilo "boss bar") exibido no topo-centro da tela.
# Mostra o nome e a vida do inimigo atingido mais recentemente e some sozinho.

const AUTO_HIDE_TIME: float = 6.0

static var _instance = null

var _panel: PanelContainer
var _bar: ProgressBar
var _name_label: Label
var _dist_label: Label
var _hp_label: Label
var _range_label: Label
var _hide_timer: float = 0.0
var _last_distance: float = -1.0
var _last_range: float = -1.0


# Retorna a instância compartilhada, criando-a sob `parent` se necessário.
static func get_shared(parent: Node):
	if _instance != null and is_instance_valid(_instance):
		return _instance
	_instance = (preload("res://library3D/characters/enemies/enemy_health_bar.gd")).new()
	parent.add_child(_instance)
	return _instance


func _ready() -> void:
	layer = 9
	set_process(true)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 16)
	# Centraliza horizontalmente o painel ancorado ao topo.
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.75)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)

	# Linha do topo: nome à esquerda, distância à direita.
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(top_row)

	_name_label = Label.new()
	_name_label.text = "Enemy"
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.add_theme_font_size_override("font_size", 16)
	top_row.add_child(_name_label)

	_dist_label = Label.new()
	_dist_label.text = ""
	_dist_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	_dist_label.add_theme_font_size_override("font_size", 14)
	top_row.add_child(_dist_label)

	_bar = ProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = 5
	_bar.value = 5
	_bar.custom_minimum_size = Vector2(260, 20)
	_bar.show_percentage = false

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.25, 0.05, 0.05, 1.0)
	bg_style.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.85, 0.1, 0.1, 1.0)
	fill_style.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill_style)

	# Texto "vida restante / vida total" centralizado sobre a barra.
	_hp_label = Label.new()
	_hp_label.text = "5 / 5"
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_label.add_theme_color_override("font_color", Color.WHITE)
	_hp_label.add_theme_font_size_override("font_size", 12)
	_bar.add_child(_hp_label)

	vbox.add_child(_bar)

	# Alcance da arma do inimigo (em metros), exibido só quando o inimigo possui um
	# mecanismo de ataque/tiro (weapon_range >= 0). Fica oculto para inimigos sem arma.
	_range_label = Label.new()
	_range_label.text = ""
	_range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_range_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_range_label.add_theme_font_size_override("font_size", 13)
	_range_label.hide()
	vbox.add_child(_range_label)

	add_child(_panel)
	_panel.hide()


func _process(delta: float) -> void:
	if _hide_timer > 0.0:
		_hide_timer -= delta
		if _hide_timer <= 0.0:
			_panel.hide()


# `distance` (m) aparece ao lado do nome; `weapon_range` (m) é o alcance da arma do
# inimigo, exibido só quando >= 0 (inimigo com mecanismo de ataque/tiro). -1 mantém o
# último valor conhecido (ex.: chamada ao ser atingido, sem reinformar o alcance).
func show_enemy(enemy_name: String, current: int, maximum: int, distance: float = -1.0, weapon_range: float = -1.0) -> void:
	if not _panel:
		return
	# Trocou de inimigo: descarta a distância/alcance do anterior para não vazar valores.
	if enemy_name != _name_label.text:
		_last_distance = -1.0
		_last_range = -1.0
	_panel.show()
	_hide_timer = AUTO_HIDE_TIME
	_name_label.text = enemy_name
	_bar.max_value = maximum
	_bar.value = current
	_hp_label.text = "%d / %d" % [current, maximum]
	# Mantém a última distância conhecida quando chamada sem distância (ex.: ao ser atingido).
	if distance >= 0.0:
		_last_distance = distance
	_dist_label.text = ("%.1f m" % _last_distance) if _last_distance >= 0.0 else ""

	# Alcance da arma: só atualiza/exibe quando informado; some se o inimigo não tem arma.
	if weapon_range >= 0.0:
		_last_range = weapon_range
	if _last_range >= 0.0:
		var word: String = "Alcance" if _locale_is_pt() else "Range"
		_range_label.text = "%s: %.0f m" % [word, _last_range]
		_range_label.show()
	else:
		_range_label.hide()


func _locale_is_pt() -> bool:
	var loc := get_node_or_null(^"/root/Locale")
	if loc != null and loc.has_method("get_language"):
		return loc.get_language() == "pt"
	return true


func hide_now() -> void:
	if _panel:
		_panel.hide()
	_hide_timer = 0.0
