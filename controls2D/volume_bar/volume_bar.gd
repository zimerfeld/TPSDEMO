class_name VolumeBar
extends Control

## Controle de volume reutilizável em forma de EQUALIZADOR horizontal: uma barra dividida em
## `segments` segmentos (10% cada por padrão) coloridos num gradiente verde → amarelo → vermelho.
## O preenchimento reflete `value` (1–100) e o usuário CLICA/ARRASTA (ou usa ←/→) para ajustar.
## Emite `value_changed(value)`. Desligado (`enabled = false`) fica esmaecido e ignora o mouse.
##
## Uso:
##   var vb := VolumeBar.new()
##   vb.value = 80
##   vb.value_changed.connect(func(v: int) -> void: ...)
## Desenhado 100% em _draw() (sem texturas) — barato, no padrão dos outros controles2D.

signal value_changed(value: int)

@export var min_value: int = 1
@export var max_value: int = 100
@export_range(0, 100) var value: int = 70: set = set_value
@export var segments: int = 10
@export var enabled: bool = true: set = set_enabled
## Mostra o número 1–100 à direita da barra.
@export var show_value: bool = true
@export var seg_gap: float = 4.0

# Gradiente do equalizador (volume baixo → alto).
@export var color_low: Color = Color(0.2, 1.0, 0.35)    # verde
@export var color_mid: Color = Color(1.0, 0.92, 0.2)    # amarelo
@export var color_high: Color = Color(1.0, 0.27, 0.2)   # vermelho

# Espaço reservado à direita para o número (px), quando show_value.
const VALUE_AREA: float = 52.0


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(260, 46)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_update_cursor()


func set_value(v: int) -> void:
	var nv := clampi(v, min_value, max_value)
	if nv == value and is_node_ready():
		return
	value = nv
	queue_redraw()
	value_changed.emit(value)


func set_enabled(e: bool) -> void:
	enabled = e
	_update_cursor()
	queue_redraw()


func _update_cursor() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW


func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_from_x((event as InputEventMouseButton).position.x)
		grab_focus()
		accept_event()
	elif event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_set_from_x((event as InputEventMouseMotion).position.x)
		accept_event()


# Largura útil da barra (descontando o espaço do número à direita).
func _bar_width() -> float:
	return maxf(1.0, size.x - (VALUE_AREA if show_value else 0.0))


func _set_from_x(x: float) -> void:
	var t := clampf(x / _bar_width(), 0.0, 1.0)
	set_value(int(round(t * float(max_value))))


func _draw() -> void:
	var bar_w := _bar_width()
	var h := size.y
	var n := maxi(segments, 1)
	var seg_w := (bar_w - seg_gap * float(n - 1)) / float(n)
	if seg_w <= 0.0:
		return
	var ratio := float(value) / float(max_value)   # 0..1
	var filled := ratio * float(n)                  # segmentos preenchidos (fracionário)
	var dim := 1.0 if enabled else 0.4
	for i in n:
		var x := float(i) * (seg_w + seg_gap)
		var col := _seg_color(i)
		# Trilho vazio (escuro) do segmento.
		draw_rect(Rect2(x, 0.0, seg_w, h), Color(col.r * 0.16, col.g * 0.16, col.b * 0.16, 0.6 * dim))
		# Parte acesa do segmento (o último parcial preenche proporcionalmente → ajuste fino 1–100).
		var f := clampf(filled - float(i), 0.0, 1.0)
		if f > 0.0:
			draw_rect(Rect2(x, 0.0, seg_w * f, h), Color(col, dim))
	if show_value:
		var font := ThemeDB.fallback_font
		var fs := clampi(int(h * 0.5), 13, 22)
		var txt := str(value)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(size.x - 6.0 - tw, h * 0.5 + float(fs) * 0.35), txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, dim))


# Cor do segmento i no gradiente verde → amarelo → vermelho.
func _seg_color(i: int) -> Color:
	var t := float(i) / float(maxi(segments - 1, 1))
	if t < 0.5:
		return color_low.lerp(color_mid, t / 0.5)
	return color_mid.lerp(color_high, (t - 0.5) / 0.5)
