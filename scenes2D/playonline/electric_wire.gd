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
@export var pulse_count: int = 2          # 2 = um horário + um anti-horário (espelhados no eixo vertical)

@export_group("Trovão")
@export var thunder_enabled: bool = true
@export var thunder_min_interval: float = 0.45   # intervalo aleatório mín. entre raios (s)
@export var thunder_max_interval: float = 1.4    # intervalo aleatório máx. entre raios (s)
@export var thunder_color: Color = Color(0.7, 0.9, 1.0)
@export var thunder_max_bolts: int = 4           # teto de raios simultâneos (otimização)

var _time: float = 0.0
# Arc-length do TOPO-CENTRO: eixo de simetria dos dois pulsos espelhados (ver _draw).
var _mirror_start: float = 0.0
# Raios ativos do "trovão": cada um { pts, life, max_life, width }. Gerados no spawn, só envelhecem.
var _bolts: Array = []
var _next_bolt: float = 0.6
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
	# Só a energia e os raios se movem; o fio em si é estático. Redesenha por frame para animá-los.
	_time += delta
	_update_thunder(delta)
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
	_mirror_start = 0.0

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

	# Eixo de simetria = meio da aresta superior (topo-centro), de onde os dois pulsos partem em
	# sentidos opostos espelhando-se no eixo vertical (ver _draw). _pts[0] está em (x0, margin).
	_mirror_start = clampf(w * 0.5 - x0, 0.0, _total)

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
	# Raios (trovão) crepitando no fio, desenhados ANTES da energia (a energia brilha por cima).
	_draw_bolts()
	# Energia: dois pulsos ESPELHADOS no eixo vertical. Ambos partem do topo-centro (_mirror_start);
	# o k par corre no sentido horário e o ímpar no anti-horário — o anti-horário é o espelho do
	# horário (pedido: espelhar a animação para o lado oposto). Eles se reencontram embaixo.
	for k in pulse_count:
		var dir := 1.0 if (k % 2 == 0) else -1.0
		var s := fposmod(_mirror_start + dir * energy_speed * _time, _total)
		var flick := 0.75 + 0.25 * sin(_time * 6.0 + float(k) * 1.7)
		_draw_pulse(s, flick, dir)


# Desenha um "cometa" de energia: rastro que esmaece para trás (no sentido do movimento) + uma
# cabeça com halo ciano e núcleo branco. `intensity` cintila levemente a energia.
func _draw_pulse(s_head: float, intensity: float, dir: float) -> void:
	var n := _pts.size()
	if n < 2:
		return
	var hi := _index_for_len(s_head)
	var ec := energy_color
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.append(_pts[hi])
	cols.append(Color(ec.r, ec.g, ec.b, ec.a * intensity))
	# O rastro fica ATRÁS da cabeça: recua no índice se o pulso anda para a frente (horário) e
	# avança no índice se anda ao contrário (anti-horário) → os dois cometas espelham certo.
	var step := -1 if dir > 0.0 else 1
	var acc := 0.0
	var idx := hi
	while acc < energy_trail and pts.size() <= n:
		var nxt := (idx + step + n) % n
		acc += _pts[idx].distance_to(_pts[nxt])
		idx = nxt
		var a := clampf(1.0 - acc / energy_trail, 0.0, 1.0)
		pts.append(_pts[nxt])
		cols.append(Color(ec.r, ec.g, ec.b, ec.a * intensity * a))
	if pts.size() >= 2:
		draw_polyline_colors(pts, cols, energy_width, true)
		# Núcleo quente sobre o rastro → leitura mais "plasma" que simples linha.
		draw_polyline(pts, Color(1, 1, 1, 0.35 * intensity), energy_width * 0.42, true)
	var hp := _pts[hi]
	# Tangente na cabeça (sentido do movimento): `step` aponta para TRÁS, então invertemos p/ a
	# frente. As faíscas saem daqui espalhadas para a frente e para os lados.
	var nb := (hi + step + n) % n
	var tang := _pts[hi] - _pts[nb]
	if tang.length() < 0.001:
		tang = Vector2.RIGHT
	tang = tang.normalized()
	# Faíscas/ramos elétricos crepitando da cabeça (tremulam como raio).
	_draw_head_forks(hp, tang, intensity)
	# Halo multi-camada: bloom externo PULSANTE → camadas ciano → núcleo branco-quente. Bem mais
	# dramático que o halo antigo de 3 círculos.
	var bloom := energy_width * (4.6 + 0.9 * sin(_time * 9.0))
	draw_circle(hp, bloom, Color(ec.r, ec.g, ec.b, 0.06 * intensity))
	draw_circle(hp, energy_width * 3.0, Color(ec.r, ec.g, ec.b, 0.16 * intensity))
	draw_circle(hp, energy_width * 1.8, Color(ec.r, ec.g, ec.b, 0.36 * intensity))
	draw_circle(hp, energy_width * 1.0, Color(0.85, 0.97, 1.0, 0.9 * intensity))
	draw_circle(hp, energy_width * 0.5, Color(1, 1, 1, 1.0 * intensity))


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


# ── Trovão (raios elétricos) ───────────────────────────────────────────────────
# Raios curtos que crepitam no fio em intervalos aleatórios, como faíscas de um trovão. Cada raio é
# uma polilinha em zigue-zague PRÉ-CALCULADA no spawn (deslocamento de ponto médio); por frame só
# variamos o brilho e o removemos ao fim da vida → poucas chamadas de draw, nenhuma textura
# (regra de otimização do projeto). Limitados por thunder_max_bolts.

func _update_thunder(delta: float) -> void:
	if not thunder_enabled or _total <= 0.0:
		_bolts.clear()
		return
	# Envelhece e descarta os raios já apagados.
	var i := _bolts.size() - 1
	while i >= 0:
		_bolts[i]["life"] -= delta
		if _bolts[i]["life"] <= 0.0:
			_bolts.remove_at(i)
		i -= 1
	# Dispara um novo raio quando o contador zera (respeitando o teto simultâneo).
	_next_bolt -= delta
	if _next_bolt <= 0.0:
		_next_bolt = randf_range(thunder_min_interval, thunder_max_interval)
		if _bolts.size() < thunder_max_bolts:
			_spawn_bolt()


func _spawn_bolt() -> void:
	var n := _pts.size()
	if n < 4:
		return
	# Começo: às vezes na cabeça de um pulso de energia (o raio "salta" da energia), às vezes solto.
	var s0: float
	if randf() < 0.6:
		var dir := 1.0 if (randi() % 2 == 0) else -1.0
		s0 = fposmod(_mirror_start + dir * energy_speed * _time, _total)
	else:
		s0 = randf() * _total
	# Fim: um trecho curto adiante (ou atrás) no perímetro → o raio crepita acompanhando o fio.
	var span := randf_range(55.0, 170.0)
	var s1 := fposmod(s0 + (span if randf() < 0.5 else -span), _total)
	var p0 := _pts[_index_for_len(s0)]
	var p1 := _pts[_index_for_len(s1)]
	# Arqueia o meio para DENTRO da tela (em direção ao centro) para o raio descolar do fio.
	var mid := (p0 + p1) * 0.5
	var inward := size * 0.5 - mid
	if inward.length() > 0.001:
		mid += inward.normalized() * randf_range(8.0, 26.0)
	var pts := _jagged_bolt(p0, mid, p1, randf_range(10.0, 22.0), 4)
	var life := randf_range(0.12, 0.22)
	_bolts.append({"pts": pts, "life": life, "max_life": life, "width": randf_range(1.6, 3.0)})


# Zigue-zague de p0→mid→p1 por deslocamento recursivo de ponto médio (`disp` decai a cada nível).
func _jagged_bolt(p0: Vector2, mid: Vector2, p1: Vector2, disp: float, depth: int) -> PackedVector2Array:
	var out := _subdivide(p0, mid, disp, depth)
	out.remove_at(out.size() - 1)            # evita duplicar o ponto do meio
	out.append_array(_subdivide(mid, p1, disp, depth))
	return out


func _subdivide(a: Vector2, b: Vector2, disp: float, depth: int) -> PackedVector2Array:
	if depth <= 0:
		return PackedVector2Array([a, b])
	var m := (a + b) * 0.5
	var d := b - a
	var nrm := Vector2(-d.y, d.x)
	if nrm.length() > 0.001:
		m += nrm.normalized() * randf_range(-disp, disp)
	var left := _subdivide(a, m, disp * 0.5, depth - 1)
	left.remove_at(left.size() - 1)
	left.append_array(_subdivide(m, b, disp * 0.5, depth - 1))
	return left


func _draw_bolts() -> void:
	for b in _bolts:
		var pts: PackedVector2Array = b["pts"]
		if pts.size() < 2:
			continue
		# Brilho mais forte no começo da vida (o clarão do raio) e some ao final.
		var t: float = clampf(b["life"] / b["max_life"], 0.0, 1.0)
		var glow := t * t
		var tc := thunder_color
		var w: float = b["width"]
		# Halo largo e fraco + núcleo branco fino → leitura de "raio elétrico".
		draw_polyline(pts, Color(tc.r, tc.g, tc.b, 0.16 * glow), w * 3.0, true)
		draw_polyline(pts, Color(tc.r, tc.g, tc.b, 0.5 * glow), w * 1.7, true)
		draw_polyline(pts, Color(1, 1, 1, 0.95 * glow), w, true)
		# Pequeno clarão na ponta de partida.
		draw_circle(pts[0], w * 2.2, Color(tc.r, tc.g, tc.b, 0.22 * glow))


# Faíscas/ramos elétricos curtos saltando da cabeça da energia. Geradas com aleatoriedade A CADA
# frame para tremular (raio). Poucas e curtas → baratas (regra de otimização do projeto).
func _draw_head_forks(origin: Vector2, tang: Vector2, intensity: float) -> void:
	var ec := energy_color
	for i in 3:
		# Direção: tangente girada por um ângulo aleatório (espalha p/ frente e lados).
		var dirv := tang.rotated(randf_range(-1.3, 1.3))
		var length := randf_range(16.0, 40.0)
		var tip := origin + dirv * length
		var seg := _subdivide(origin, tip, length * 0.3, 3)
		var a := intensity * randf_range(0.45, 1.0)
		draw_polyline(seg, Color(ec.r, ec.g, ec.b, 0.5 * a), 2.6, true)
		draw_polyline(seg, Color(1, 1, 1, 0.85 * a), 1.1, true)
		draw_circle(tip, 2.0, Color(ec.r, ec.g, ec.b, 0.55 * a))
