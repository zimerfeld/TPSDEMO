extends CanvasLayer
## Tela de "Carregando" REUTILIZAVEL — cobre a tela enquanto um level/sala e ativado.
##
## POR QUE EXISTE (medido em 2026-08-05, cold cache): a 1a vez que um level vira a cena ATIVA custa
## ~2,5 s de stall (setup completo na janela real: apply_graphics_settings + shadow atlas + render
## buffers + occlusion + pipelines do ambiente/chao e das entidades). Sem mascarar, esse stall caia no
## meio da 1a partida — congelando os inimigos na tela do cliente. Ver [[salas-freeze-render-stall]].
##
## DOIS PAPEIS:
##  1. `run_startup_preload()` — no startup (main.gd), carrega um level DE VERDADE por alguns frames e
##     o descarta, PAGANDO ADIANTADO o setup global do renderer. Medido: a entrada seguinte numa sala
##     cai de ~2,5 s para ~0,6 s (-76%). O custo e global (renderer/pipelines), nao por instancia.
##  2. `cover(action)` — cobre a tela ANTES de cada entrada em level (offline) ou sala (online), roda a
##     acao e revela so quando o quadro esta pronto. O jogador ve "Carregando..." em vez de um frame
##     congelado.
##
## ⚠️ So ATIVACAO COMPLETA (o level como cena viva, `_ready` inteiro) paga o custo. Pre-render offscreen
## (SubViewport/viewport raiz) foi medido e da 0 ms de stall — nao reproduz o custo, logo nao antecipa
## nada. NAO trocar por um "warm" offscreen.

## Level usado no pre-pagamento do startup (o custo e do renderer, nao da cena; o level_1 e o padrao
## das salas — DEFAULT_ROOM_LEVEL — entao aquece o caso mais comum).
const PRELOAD_LEVEL: String = "res://scenes3D/level_1/level_1.tscn"
## Frames com o level vivo no pre-pagamento (cobre o spawn deferido do template + frames de render).
const STARTUP_FRAMES: int = 6
## Frames aguardados depois da acao, antes de revelar (deixa o 1o quadro do level/sala ficar pronto).
const SETTLE_FRAMES: int = 5
## Frames para a propria tela PINTAR antes de rodar a acao (senao o stall come o frame da tela e o
## jogador ve a janela congelada, que e exatamente o que queremos mascarar).
const PAINT_FRAMES: int = 2
# Teto (s) da espera pelo `ready_check` do cover(): passado ele, a tela revela assim mesmo. Um
# servidor lento (ou uma sala parada no meio do povoamento) não pode prender o jogador aqui.
const READY_TIMEOUT_SEC: float = 15.0

var _hint: Label = null

## `true` enquanto o pré-pagamento do startup roda. O level vive alguns frames só para aquecer o
## renderer — ninguém joga nele —, então quem CAPTURA o mouse ao entrar em cena (spectator_camera,
## player_input) deve se abster enquanto isto estiver ligado. Capturar e soltar no mesmo punhado de
## frames deixava o cursor sem ser redesenhado no Windows: o modo voltava a VISIBLE, mas o ponteiro
## só reaparecia depois de uma nova troca de modo. Não capturar é a cura, não o remendo.
var preloading: bool = false


func _ready() -> void:
	layer = 200                                   # acima de tudo (inclusive HUDs e janelas flutuantes)
	process_mode = Node.PROCESS_MODE_ALWAYS       # visivel mesmo com a arvore pausada (solo/offline)
	visible = false
	_build_visual()


func _build_visual() -> void:
	var root := Control.new()
	root.name = "Cover"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP   # engole cliques no que esta atras enquanto carrega
	var theme_res := load("res://themes/ui_theme.tres")
	if theme_res is Theme:
		root.theme = theme_res
	add_child(root)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.043, 0.051, 0.094, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)

	# Textos canonicos em pt — o auto-localizer do [[locale]] traduz via
	# scenes2D/loading/Resources/loading.{pt,en,es}.json (o texto NAO muda em runtime, so a visibilidade,
	# para nao invalidar o canonico guardado pelo Locale).
	var title := Label.new()
	title.name = "Title"
	title.text = "Carregando..."
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.text = "Preparando os gráficos"
	_hint.modulate = Color(1.0, 1.0, 1.0, 0.7)
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.visible = false                          # so no pre-pagamento do startup
	column.add_child(_hint)


# Cobre a tela, deixa alguns frames para PINTAR, executa `action` (a ativacao pesada do level/sala),
# aguarda o quadro assentar e revela. Chamar com `await` quando o chamador precisa continuar depois.
func cover(action: Callable, settle_frames: int = SETTLE_FRAMES,
		ready_check: Callable = Callable(), timeout_sec: float = READY_TIMEOUT_SEC) -> void:
	visible = true
	for _i in PAINT_FRAMES:
		await get_tree().process_frame
	if action.is_valid():
		action.call()
	# `ready_check` (opcional): enquanto devolver false, a tela CONTINUA cobrindo. É o que sustenta a
	# regra "a sala carrega inteira antes de liberar o jogador" — a entrada só é revelada quando o
	# player já existe na sala, e como o servidor o spawna DEPOIS de povoá-la, isso implica cenário
	# completo. Timeout de segurança para nunca prender o jogador aqui.
	if ready_check.is_valid():
		var waited := 0.0
		while waited < timeout_sec and not bool(ready_check.call()):
			await get_tree().process_frame
			waited += get_process_delta_time()
	for _i in settle_frames:
		await get_tree().process_frame
	visible = false


# STARTUP (main.gd): carrega um level DE VERDADE por alguns frames e o descarta, pagando adiantado o
# setup global do renderer. Sem input no level → ESC nao dispara o LevelExit durante o carregamento.
# ⚠️ O level roda como observador (spectator_host) e a spectator_camera CAPTURA o mouse no _ready.
# O modo do mouse e GLOBAL: descartar o level nao o desfaz. Por isso restauramos VISIBLE no fim —
# senao o menu (e todas as telas 2D) nasceriam sem cursor.
func run_startup_preload() -> void:
	var scene := ResourceLoader.load(PRELOAD_LEVEL) as PackedScene
	if scene == null:
		return
	_hint.visible = true
	visible = true
	for _i in PAINT_FRAMES:
		await get_tree().process_frame
	preloading = true
	var prev_spectator: bool = PlayerSelection.spectator_host
	PlayerSelection.spectator_host = true
	var level: Node = scene.instantiate()
	level.set_process_input(false)
	get_tree().root.add_child(level)
	for _i in STARTUP_FRAMES:
		await get_tree().process_frame
	if is_instance_valid(level):
		level.queue_free()
	PlayerSelection.spectator_host = prev_spectator
	preloading = false
	# Cinto de segurança: se algum nó do level tiver capturado o mouse mesmo assim, a UI 2D que vem a
	# seguir precisa do cursor de volta.
	if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await get_tree().process_frame
	_hint.visible = false
	visible = false
