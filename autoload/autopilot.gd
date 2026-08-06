extends Node
## Piloto automático de sessão (uso de DESENVOLVIMENTO/TESTE). Lê os argumentos de usuário da linha
## de comando (tudo que vem depois de `--`) e conduz sozinho o fluxo de salas: uma instância sobe
## como SERVIDOR e hospeda uma sala; a outra espera o servidor subir e ENTRA na sala em execução.
##
## É o que permite abrir duas janelas lado a lado (ver scripts/dual-window.ps1) sem clicar em nada:
##
##   ZIMARO.exe -- autohost port=4383 level=1 win=0,0,960,1040 player=HOST
##   ZIMARO.exe -- autojoin port=4383 address=127.0.0.1 delay=6 win=960,0,960,1040 player=CLIENTE
##
## Argumentos aceitos (todos opcionais, exceto o modo):
##   autohost              → hospeda o servidor de salas e inicia uma sala
##   autojoin              → conecta como cliente e entra na primeira sala em execução
##   port=<n>              → porta do servidor (padrão 4383)
##   address=<host>        → IP/domínio do servidor, só no autojoin (padrão 127.0.0.1)
##   level=<1|2|res://...> → level da sala criada pelo autohost (padrão 1)
##   template=<id|nome>    → template de personagens ativado na sala (ex.: aliado bot); "none" limpa
##   delay=<seg>           → espera antes da 1ª tentativa de conexão (padrão 6)
##   retries=<n>           → tentativas extras de conexão, de 2 em 2 s (padrão 15)
##   player=<nome>         → nome do jogador desta instância (não persiste em Settings)
##   music=<on|off>        → trilha desta instância; sem o argumento, o HOST nasce sem música
##   win=<x,y,w,h>         → posiciona/dimensiona a janela (em pixels de tela)
##
## Sem nenhum desses argumentos o autoload fica inerte — o jogo roda exatamente como antes.
## Ver [[🧩 Sistemas/🪟 duas-janelas-autopilot]].

const DEFAULT_PORT: int = 4383
const DEFAULT_ADDRESS: String = "127.0.0.1"
const DEFAULT_DELAY_SEC: float = 6.0
# Pausa (s) do HOST entre preencher os campos e hospedar de fato, para dar tempo de LER os parâmetros
# na tela antes de ela trocar pela sessão de salas. Só vale em build de DEPURAÇÃO (editor / export
# debug): é apoio a acompanhamento visual, não pode atrasar o servidor no .exe de release.
const HOST_PREVIEW_DELAY_SEC: float = 5.0
const DEFAULT_RETRIES: int = 15
const RETRY_INTERVAL_SEC: float = 2.0
# Por quantos frames reafirmar a geometria da janela depois de sair da tela cheia (ver apply_window).
const REASSERT_FRAMES: int = 30
const LEVEL_PATHS: Dictionary = {
	"1": "res://scenes3D/level_1/level_1.tscn",
	"2": "res://scenes3D/level_2/level_2.tscn",
}

enum Mode { OFF, HOST, JOIN }
# Trilha desta instância. DEFAULT = decide pelo papel: o HOST nasce mudo (é a janela de gerência —
# duas trilhas tocando ao mesmo tempo nas duas janelas atrapalha o acompanhamento), o cliente toca.
enum Music { DEFAULT, ON, OFF }

var mode: Mode = Mode.OFF
var port: int = DEFAULT_PORT
var address: String = DEFAULT_ADDRESS
var level_path: String = LEVEL_PATHS["1"]
# Template de personagens a ativar no level da sala (id exato ou parte do nome). "" = não mexe no
# que já estiver ativo; "none" = limpa (sala só com os jogadores).
var template: String = ""
var delay_sec: float = DEFAULT_DELAY_SEC
# True se `delay=` veio na linha de comando (o host respeita o valor pedido em vez do padrão).
var _delay_explicit: bool = false
var retries_left: int = DEFAULT_RETRIES
var player_name: String = ""
var music: Music = Music.DEFAULT

# Geometria pedida pelo launcher (win=x,y,w,h). Vazio = não mexe na janela.
var _window_rect: Rect2i = Rect2i()
var _has_window_rect: bool = false
# O auto-join numa sala roda UMA vez: depois disso o jogador manda na sessão (sair de uma sala não
# pode reentrar sozinho). Idem para a sala criada pelo host.
var _room_entered: bool = false
var _room_started: bool = false


func _ready() -> void:
	_parse_args(OS.get_cmdline_user_args())
	# O Settings (autoload anterior na ordem) já aplicou o áudio salvo no seu _ready — silenciamos por
	# cima. Ver apply_audio.
	apply_audio()


# Silencia (ou não) a trilha DESTA instância. Mexe só no bus vivo, NUNCA no Settings: as duas janelas
# gravam no MESMO arquivo de configuração do usuário, e persistir aqui apagaria a preferência dele.
# Reaplicado pelo menu, que recarrega o áudio salvo ao entrar. Inerte sem os argumentos do piloto.
func apply_audio() -> void:
	if not is_active():
		return
	var mute: bool = is_host() if music == Music.DEFAULT else (music == Music.OFF)
	var bus: int = AudioServer.get_bus_index("Music")
	if bus != -1:
		AudioServer.set_bus_mute(bus, mute)


func _parse_args(args: PackedStringArray) -> void:
	for raw in args:
		var arg := String(raw).strip_edges()
		if arg == "autohost":
			mode = Mode.HOST
			continue
		if arg == "autojoin":
			mode = Mode.JOIN
			continue
		var eq := arg.find("=")
		if eq <= 0:
			continue
		var key := arg.substr(0, eq)
		var value := arg.substr(eq + 1)
		match key:
			"port":
				port = maxi(int(value), 1)
			"address":
				address = value
			"level":
				level_path = LEVEL_PATHS.get(value, value if value.begins_with("res://") else level_path)
			"template":
				template = value
			"delay":
				delay_sec = maxf(float(value), 0.0)
				_delay_explicit = true
			"retries":
				retries_left = maxi(int(value), 0)
			"player":
				player_name = value
			"music":
				music = Music.ON if value in ["on", "1", "true"] else Music.OFF
			"win":
				_parse_window_rect(value)


func _parse_window_rect(value: String) -> void:
	var parts := value.split(",", false)
	if parts.size() != 4:
		push_warning("Autopilot: win= espera x,y,w,h (recebido: %s)" % value)
		return
	_window_rect = Rect2i(int(parts[0]), int(parts[1]), maxi(int(parts[2]), 320), maxi(int(parts[3]), 240))
	_has_window_rect = true


func is_active() -> bool:
	return mode != Mode.OFF


func is_host() -> bool:
	return mode == Mode.HOST


func is_join() -> bool:
	return mode == Mode.JOIN


# Pausa do host antes de hospedar. Em RELEASE é sempre 0 (o servidor sobe na hora); em depuração,
# o `delay=` pedido na linha de comando ou HOST_PREVIEW_DELAY_SEC. Ver [[dual-window]].
func host_preview_delay() -> float:
	if not OS.is_debug_build():
		return 0.0
	return delay_sec if _delay_explicit else HOST_PREVIEW_DELAY_SEC


# Posiciona/dimensiona a janela conforme win=x,y,w,h. Força o modo JANELA (o Settings nasce em tela
# cheia exclusiva) e desconta as decorações (barra de título/bordas) para a metade pedida caber de
# fato na tela — sem isso as duas janelas ficariam maiores que a metade e se sobreporiam.
#
# A saída da tela cheia EXCLUSIVA não assenta no mesmo frame (o SO ainda está trocando o modo e
# devolve a janela ao tamanho cheio depois), então reafirmamos a geometria por alguns frames — foi o
# que fazia as duas janelas nascerem ambas em 1920x1080 na primeira versão. Idempotente: chamadas
# repetidas (main.gd e menu.gd) só reiniciam a reafirmação.
func apply_window(window: Window) -> void:
	if not _has_window_rect or window == null:
		return
	_place_window(window)
	_reassert_window(window)


func _reassert_window(window: Window) -> void:
	for _i in range(REASSERT_FRAMES):
		await get_tree().process_frame
		if not is_instance_valid(window):
			return
		_place_window(window)


func _place_window(window: Window) -> void:
	if window.mode != Window.MODE_WINDOWED:
		window.mode = Window.MODE_WINDOWED
	var wid: int = window.get_window_id()
	var deco: Vector2i = (DisplayServer.window_get_size_with_decorations(wid)
			- DisplayServer.window_get_size(wid))
	deco.x = maxi(deco.x, 0)
	deco.y = maxi(deco.y, 0)
	window.size = Vector2i(
		maxi(_window_rect.size.x - deco.x, 320),
		maxi(_window_rect.size.y - deco.y, 240))
	# A barra de título fica ACIMA da área de conteúdo: empurra o conteúdo para baixo o equivalente,
	# senão a barra da janela nasceria fora do topo da área útil da tela.
	window.position = Vector2i(_window_rect.position.x, _window_rect.position.y + deco.y)


# Aplica o nome do jogador desta instância (só em memória — não suja o Settings compartilhado pelas
# duas janelas, que gravam no MESMO arquivo de configuração do usuário).
func apply_player_name() -> void:
	if player_name != "":
		PlayerSelection.player_name = player_name


# Ativa o template de personagens pedido em `template=` para `level`, ANTES de a sala ser criada (é
# no start_room que o template é aplicado). Casa pelo id exato; se não achar, pelo NOME (sem
# diferenciar maiúsculas, casando por trecho) — assim `template=aereo` acha "Level 2 - Caça aérea"
# sem precisar passar acento/espaço na linha de comando. "none" limpa o template do level.
func apply_template(level: String) -> void:
	if template == "":
		return
	if template == "none":
		CharacterTemplateManager.set_active(level, "")
		return
	var wanted := _plain(template)
	var fallback := ""
	var fallback_name := ""
	for t in CharacterTemplateManager.templates_for_level(level):
		var id := String(t.get("id", ""))
		if id == template:
			CharacterTemplateManager.set_active(level, id)
			print("[autopilot] template ativo: %s" % id)
			return
		if fallback == "" and _plain(String(t.get("name", ""))).contains(wanted):
			fallback = id
			fallback_name = String(t.get("name", ""))
	if fallback != "":
		CharacterTemplateManager.set_active(level, fallback)
		print("[autopilot] template ativo: %s (%s)" % [fallback, fallback_name])
		return
	push_warning("Autopilot: template '%s' nao encontrado para %s — a sala nasce sem ele." % [template, level])


# minúsculas SEM acento — o casamento por nome funciona digitando "aerea" para "Caça aérea", que é o
# que se consegue passar sem dor numa linha de comando.
func _plain(text: String) -> String:
	var out := text.to_lower()
	const FROM := "áàâãäéèêëíìîïóòôõöúùûüçñ"
	const TO := "aaaaaeeeeiiiiooooouuuucn"
	for i in FROM.length():
		out = out.replace(FROM[i], TO[i])
	return out


# O host ainda precisa criar a sala inicial? (uma vez por execução)
func should_start_room() -> bool:
	if not is_host() or _room_started:
		return false
	_room_started = true
	return true


# O cliente ainda precisa entrar sozinho numa sala? (uma vez por execução)
func should_enter_room() -> bool:
	return is_join() and not _room_entered


func mark_room_entered() -> void:
	_room_entered = true


# Consome uma tentativa de conexão do cliente. True = ainda dá para tentar de novo (o playonline
# re-tenta em silêncio em vez de abrir o diálogo de erro; o servidor pode estar subindo ainda).
func consume_retry() -> bool:
	if not is_join() or retries_left <= 0:
		return false
	retries_left -= 1
	return true
