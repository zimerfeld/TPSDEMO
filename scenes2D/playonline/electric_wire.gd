extends Control

## Moldura de "fio de metal trançado" grosso na borda da tela Jogar Online, com energia
## elétrica que o percorre LENTA e ALTERNADAMENTE (dois pulsos em sentidos opostos), como
## pedido. O fio contorna a tela com uma MARGEM para dentro da borda.
##
## Otimizado (regra do projeto): o caminho (retângulo arredondado) e as duas fitas senoidais
## do trançado são PRÉ-CALCULADOS em _rebuild_path() — só refeitos ao redimensionar. Por frame
## só redesenhamos a ENERGIA (cometas de brilho ciano), então são poucas chamadas de draw e
## nenhuma textura. Fica atrás do formulário/botões (primeiro filho de UI) e é MOUSE_FILTER_IGNORE,
## logo nunca rouba clique.

@export_group("Moldura")
@export var margin: float = 12.0          # margem para DENTRO da borda da tela
@export var corner_radius: float = 26.0   # raio dos cantos arredondados
@export var wire_width: float = 12.0      # espessura do cabo (fio "grosso")
@export var segment_len: float = 9.0      # comprimento alvo de cada segmento amostrado do caminho

@export_group("Trançado")
@export var braid_pitch: float = 22.0     # passo da trança, em px (uma volta a cada N px)
@export var braid_amp: float = 3.2        # deslocamento lateral de cada fita em relação ao centro
@export var strand_width: float = 3.4
@export var metal_dark: Color = Color(0.16, 0.17, 0.20)
@export var metal_mid: Color = Color(0.42, 0.45, 0.52)
@export var metal_light: Color = Color(0.82, 0.86, 0.95)

@export_group("Energia")
@export var energy_color: Color = Color(0.45, 0.85, 1.0)
@export var energy_speed: float = 260.0   # px/s — vagaroso
@export var energy_trail: float = 220.0   # comprimento do rastro do cometa, em px
@export var energy_width: float = 5.0
@export var pulse_count: int = 2          # 2 = um horário + um anti-horário (alternados)

var _time: float = 0.0
# Geometria do caminho (linha de centro do cabo), recalculada só no resize.
var _pts := PackedVector2Array()
var _nrm := PackedVector2Array()
var _len := PackedFloat32Array()
var _total: float = 0.0
# Cabo + fitas trançadas pré-montados (estáticos entre resizes).
var _cable := PackedVector2Array()
var _strand_a := PackedVector2Array()
var _strand_a_col := PackedColorArray()
var _strand_b := PackedVector2Array()
var _strand_b_col := PackedColorArray()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_rebuild_path)
	_rebuild_path()


func _process(delta: float) -> void:
	# Só a energia se move; o fio em si é estático. Redesenha por frame para animá-la.
	_time += delta
	queue_redraw()


# ── Construção do caminho (retângulo arredondado, sentido horário) ────────────

# Acrescenta os pontos de uma aresta reta (de `a` até pouco antes de `b`) com a normal externa `n`.
# Não inclui `b`: o próximo trecho (arco) começa exatamente nele, evitando duplicar/abrir o caminho.
func _add_edge(a: Vector2, b: Vector2, n: Vector2) -> void:
	var segs := maxi(1, int(round(a.distance_to(b) / segment_len)))
	for i in segs:
		_pts.append(a.lerp(b, float(i) / float(segs)))
		_nrm.append(n)


# Acrescenta os pontos de um arco (de `a0` até pouco antes de `a1`) centrado em `c`, raio `r`.
# A normal externa de cada ponto é a própria direção radial.
func _add_arc(c: Vector2, r: float, a0: float, a1: float) -> void:
	var segs := maxi(2, int(round(r * absf(a1 - a0) / segment_len)))
	for i in segs:
		var ang := lerpf(a0, a1, float(i) / float(segs))
		var d := Vector2(cos(ang), sin(ang))
		_pts.append(c + d * r)
		_nrm.append(d)


func _rebuild_path() -> void:
	_pts = PackedVector2Array()
	_nrm = PackedVector2Array()
	_cable = PackedVector2Array()
	_strand_a = PackedVector2Array(); _strand_a_col = PackedColorArray()
	_strand_b = PackedVector2Array(); _strand_b_col = PackedColorArray()
	_total = 0.0

	var w := size.x
	var h := size.y
	var r := clampf(corner_radius, 0.0, minf(w, h) * 0.5 - margin - 1.0)
	# Tela pequena demais para a moldura: nada a desenhar.
	if r < 1.0 or w <= 2.0 * (margin + r) or h <= 2.0 * (margin + r):
		return

	var x0 := margin + r
	var y0 := margin + r
	var x1 := w - margin - r
	var y1 := h - margin - r
	# Percorre no sentido horário a partir do topo-esquerdo.
	_add_edge(Vector2(x0, margin), Vector2(x1, margin), Vector2(0, -1))          # topo
	_add_arc(Vector2(x1, y0), r, -PI * 0.5, 0.0)                                 # canto sup-dir
	_add_edge(Vector2(w - margin, y0), Vector2(w - margin, y1), Vector2(1, 0))   # direita
	_add_arc(Vector2(x1, y1), r, 0.0, PI * 0.5)                                  # canto inf-dir
	_add_edge(Vector2(x1, h - margin), Vector2(x0, h - margin), Vector2(0, 1))   # base
	_add_arc(Vector2(x0, y1), r, PI * 0.5, PI)                                   # canto inf-esq
	_add_edge(Vector2(margin, y1), Vector2(margin, y0), Vector2(-1, 0))          # esquerda
	_add_arc(Vector2(x0, y0), r, PI, PI * 1.5)                                   # canto sup-esq

	var n := _pts.size()
	if n < 2:
		return
	# Comprimento de arco acumulado (fechado): _total inclui o segmento de volta ao ponto 0.
	_len = PackedFloat32Array()
	_len.resize(n)
	_len[0] = 0.0
	for i in range(1, n):
		_len[i] = _len[i - 1] + _pts[i - 1].distance_to(_pts[i])
	_total = _len[n - 1] + _pts[n - 1].distance_to(_pts[0])

	# Cabo fechado + as duas fitas senoidais defasadas (o "trançado"). Cada fita brilha na crista
	# (quando passa para a frente) e escurece no vale → ilusão de cabo torcido. Estático.
	_cable = _pts.duplicate()
	_cable.append(_pts[0])
	for i in n:
		var ph := TAU * _len[i] / braid_pitch
		var off := sin(ph) * braid_amp
		_strand_a.append(_pts[i] + _nrm[i] * off)
		_strand_b.append(_pts[i] - _nrm[i] * off)
		_strand_a_col.append(metal_dark.lerp(metal_light, 0.5 + 0.5 * sin(ph)))
		_strand_b_col.append(metal_dark.lerp(metal_light, 0.5 + 0.5 * sin(ph + PI)))
	_strand_a.append(_strand_a[0]); _strand_a_col.append(_strand_a_col[0])
	_strand_b.append(_strand_b[0]); _strand_b_col.append(_strand_b_col[0])


# ── Desenho ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if _total <= 0.0 or _cable.size() < 2:
		return
	# Sombra suave + corpo do cabo (escuro), depois as fitas claras por cima.
	draw_polyline(_cable, Color(0, 0, 0, 0.55), wire_width + 4.0, true)
	draw_polyline(_cable, metal_mid, wire_width, true)
	draw_polyline_colors(_strand_a, _strand_a_col, strand_width, true)
	draw_polyline_colors(_strand_b, _strand_b_col, strand_width, true)
	# Energia: pulsos percorrendo o perímetro em sentidos ALTERNADOS, bem devagar.
	var slots := maxi(pulse_count, 1)
	for k in pulse_count:
		var dir := 1.0 if (k % 2 == 0) else -1.0
		var base := _total * float(k) / float(slots)
		var s := fposmod(base + dir * energy_speed * _time, _total)
		var flick := 0.75 + 0.25 * sin(_time * 6.0 + float(k) * 1.7)
		_draw_pulse(s, flick)


# Desenha um "cometa" de energia: rastro que esmaece para trás (no sentido do movimento) + uma
# cabeça com halo ciano e núcleo branco. `intensity` cintila levemente a energia.
func _draw_pulse(s_head: float, intensity: float) -> void:
	var n := _pts.size()
	if n < 2:
		return
	var hi := _index_for_len(s_head)
	var ec := energy_color
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.append(_pts[hi])
	cols.append(Color(ec.r, ec.g, ec.b, ec.a * intensity))
	var acc := 0.0
	var idx := hi
	while acc < energy_trail and pts.size() <= n:
		var nxt := (idx - 1 + n) % n
		acc += _pts[idx].distance_to(_pts[nxt])
		idx = nxt
		var a := clampf(1.0 - acc / energy_trail, 0.0, 1.0)
		pts.append(_pts[nxt])
		cols.append(Color(ec.r, ec.g, ec.b, ec.a * intensity * a))
	if pts.size() >= 2:
		draw_polyline_colors(pts, cols, energy_width, true)
	var hp := _pts[hi]
	# Halo em 3 camadas (amplo e fraco → núcleo branco) p/ a energia "elétrica" saltar do metal claro.
	draw_circle(hp, energy_width * 3.0, Color(ec.r, ec.g, ec.b, 0.12 * intensity))
	draw_circle(hp, energy_width * 1.7, Color(ec.r, ec.g, ec.b, 0.32 * intensity))
	draw_circle(hp, energy_width * 0.85, Color(1, 1, 1, 0.95 * intensity))


# Maior índice i com _len[i] <= s (busca binária; _len é monotônico). Mapeia comprimento→ponto.
func _index_for_len(s: float) -> int:
	var hi := _len.size() - 1
	if hi < 0:
		return 0
	s = clampf(s, 0.0, _total)
	var lo := 0
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if _len[mid] <= s:
			lo = mid
		else:
			hi = mid - 1
	return lo
