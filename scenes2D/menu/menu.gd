extends Node


signal replace_main_scene

const CHOOSEPLAYER_PATH: String = "res://scenes2D/chooseplayer/chooseplayer.tscn"
const DEVELOPER_PATH: String = "res://scenes2D/developer/developer.tscn"
const PLAYONLINE_PATH: String = "res://scenes2D/playonline/playonline.tscn"
const SETTINGS_PATH: String = "res://scenes2D/settings/settings.tscn"

var loading_path: String = ""

var peer: MultiplayerPeer = OfflineMultiplayerPeer.new()

# Diálogo "Deseja sair do Zimaro ?" enquanto aberto, para não empilhar dois ao apertar
# Sair/ESC repetidamente.
var _quit_dialog: FloatingWindow = null

@onready var world_environment: WorldEnvironment = $WorldEnvironment

@onready var ui: Control = $UI
@onready var main: Control = %MenuColumn
@onready var play_button: Button = main.get_node(^"PlayRow/Play")
@onready var play_online_button: Button = main.get_node(^"PlayOnlineRow/PlayOnline")
@onready var settings_button: Button = main.get_node(^"SettingsRow/Settings")
@onready var quit_button: Button = main.get_node(^"QuitRow/Quit")

@onready var loading: HBoxContainer = %Loading
@onready var loading_progress: ProgressBar = loading.get_node(^"Progress")
@onready var loading_done_timer: Timer = loading.get_node(^"DoneTimer")

@onready var portuguese_button: Button = %Portuguese
@onready var english_button: Button = %English
@onready var spanish_button: Button = %Spanish


func _ready() -> void:
	# Read every stored setting from disk and apply it before the menu is shown, so the
	# window, rendering, resolution and audio all reflect the saved configuration on
	# entry (not just whatever was applied when the game first launched).
	Settings.load_settings()
	Settings.apply_graphics_settings(get_window(), world_environment.environment, self)
	Settings.apply_window_resolution(get_window())
	Settings.apply_audio_settings()
	# O menu reaplica a resolução e o ÁUDIO salvos (centralizando a janela, religando a trilha) —
	# reafirma as escolhas do piloto automático por cima, senão as duas janelas voltariam a se
	# sobrepor e a do servidor voltaria a tocar música ao chegar aqui.
	Autopilot.apply_window(get_window())
	Autopilot.apply_audio()

	if DisplayServer.get_name() == "headless" or Autopilot.is_active():
		# Servidor dedicado OU piloto automático (`-- autohost`/`autojoin`): pula chooseplayer/levels
		# e abre direto a tela online, que hospeda ou conecta sozinha.
		_start_online_headless.call_deferred()

	_update_language_buttons()

	# Foco inicial SEMPRE no controle de Tab = 1 (cabeça do anel), p/ as setas/Tab começarem do 1º (Play).
	UINav.focus_tab_one.call_deferred(self)
	# Tab incremental de 1 na ordem de leitura: Play → Play Online → Settings → Developer → Sair →
	# Português → English → Español → Debug 2D. Re-liga quando o DebugOverlay injeta o toggle "Debug 2D" na barra
	# Actions (ele entra DEPOIS do _ready do menu), para o toggle fechar a sequência.
	_wire_tab_order.call_deferred()
	($UI/Actions as HBoxContainer).child_entered_tree.connect(
		func(_n: Node) -> void: _wire_tab_order.call_deferred())


# Headless auto-host / piloto automático: vai direto para playonline (que hospeda ou conecta sozinha).
# Deferido porque main.gd só conecta replace_main_scene DEPOIS do _ready do menu.
func _start_online_headless() -> void:
	PlayerSelection.online_mode = true
	emit_signal("replace_main_scene", load(PLAYONLINE_PATH))


# (Re)liga o anel de Tab da tela na ordem de leitura. Idempotente — pode ser chamado quantas vezes
# o conjunto de focáveis mudar (toggle injetado, botão de idioma habilitando/desabilitando).
func _wire_tab_order() -> void:
	UINav.wire_tab_ring(self)


# Grey out the button for the language already active so the current choice is clear.
func _update_language_buttons() -> void:
	var lang := Locale.get_language()
	portuguese_button.disabled = lang == "pt"
	english_button.disabled = lang == "en"
	spanish_button.disabled = lang == "es"
	# O botão do idioma ativo fica desabilitado (fora do Tab) — re-liga o anel p/ a sequência fechar
	# sem ele. call_deferred: o estado disabled já assentou quando o anel é remontado.
	if is_node_ready():
		_wire_tab_order.call_deferred()


func _process(_delta: float) -> void:
	if loading.visible and loading_path != "":
		var progress: Array = []
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(loading_path, progress)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			loading_progress.value = progress[0] * 100.0
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			loading_progress.value = 100.0
			set_process(false)
			loading_done_timer.start()
		else:
			print("Error while loading level: " + str(status))
			main.show()
			loading.hide()


func _on_loading_done_timer_timeout() -> void:
	multiplayer.multiplayer_peer = peer
	emit_signal("replace_main_scene", ResourceLoader.load_threaded_get(loading_path))


func _on_play_pressed() -> void:
	# Offline: chooseplayer → levels → carrega o nível localmente.
	PlayerSelection.online_mode = false
	loading_path = CHOOSEPLAYER_PATH
	main.hide()
	loading.show()
	ResourceLoader.load_threaded_request(loading_path, "", true)


func _on_settings_pressed() -> void:
	emit_signal("replace_main_scene", load(SETTINGS_PATH))


# Sair do jogo pede confirmação numa janela central ("Deseja sair do Zimaro ?", Sim/Não) —
# tanto pelo botão Sair quanto pelo ESC. Só fecha o jogo no "Sim".
func _on_quit_pressed() -> void:
	if is_instance_valid(_quit_dialog):
		return
	# `closed` cobre o botão "Não", o × e o ESC (a janela se autolibera e devolve o foco).
	var dlg := FloatingDialog.confirm(self, "Sair do jogo", "Deseja sair do Zimaro ?", "Sim", "Não")
	dlg.confirmed.connect(get_tree().quit)
	dlg.closed.connect(func() -> void:
		_quit_dialog = null
		play_button.grab_focus())
	_quit_dialog = dlg


func _on_play_online_pressed() -> void:
	# Online: vai DIRETO para a tela de salas (PlayOnline), onde se decide Host/Client. O
	# personagem (ChoosePlayer) e a sala são escolhidos depois, já dentro do fluxo de salas.
	PlayerSelection.online_mode = true
	emit_signal("replace_main_scene", load(PLAYONLINE_PATH))


func _on_developer_pressed() -> void:
	emit_signal("replace_main_scene", load(DEVELOPER_PATH))


# Language buttons (anchored at the bottom of the menu): switch + persist the UI
# language. Locale re-localizes the live tree, so the menu updates in place.
func _on_portuguese_pressed() -> void:
	Locale.set_language("pt")
	_update_language_buttons()


func _on_english_pressed() -> void:
	Locale.set_language("en")
	_update_language_buttons()


func _on_spanish_pressed() -> void:
	Locale.set_language("es")
	_update_language_buttons()


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		# ESC encerra primeiro um campo em edição; só então abre o diálogo de saída.
		if UINav.cancel_active_edit(get_viewport(), play_button):
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		_on_quit_pressed()
