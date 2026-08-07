class_name LevelExit
extends RefCounted

## Saída de um nível pela ação "quit" (ESC). Centraliza a lógica usada por level_1.gd /
## level_2.gd para não duplicá-la. Comportamento por modo:
##   • Offline (partida solo): ESC abre as CONFIGURAÇÕES sobre a partida, que fica PAUSADA — o
##     personagem para de responder aos comandos e nada acontece com ele enquanto o jogador mexe nas
##     opções. "Voltar" retoma o jogo exatamente de onde parou; "Abandonar Partida" (botão que só
##     existe nesse modo) abre a confirmação de sempre e, no "Sim", volta à tela de níveis.
##   • Online (salas host/cliente): mantém o comportamento antigo — ESC volta direto ao menu. Ali a
##     árvore NÃO pode ser pausada (congelaria a replicação da sala), e o ESC das salas já é tratado
##     pelas telas host_session/client_session.

const LEVELS_PATH := "res://scenes2D/levels/levels.tscn"
const SettingsScreen := preload("res://scenes2D/settings/settings.gd")
# Referência da tela de configurações aberta sobre a partida, guardada no próprio nível (impede abrir
# duas ao pressionar ESC repetidamente).
const _SETTINGS_META := &"pause_settings"
# Referência da confirmação de abandono, pelo mesmo motivo.
const _DIALOG_META := &"abandon_dialog"


# Chamado no _input do nível quando a ação "quit" é pressionada.
static func request_exit(level: Node) -> void:
	# Libera o mouse para o jogador clicar (tanto nas configurações offline quanto ao voltar ao menu).
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Online: ESC volta ao menu principal (o sinal "quit" já é ligado a main.go_to_main_menu).
	if PlayerSelection.online_mode:
		level.emit_signal(&"quit")
		return

	# Offline: uma tela por vez.
	if level.has_meta(_SETTINGS_META) and is_instance_valid(level.get_meta(_SETTINGS_META)):
		return
	var screen := SettingsScreen.open_over_level(level)
	level.set_meta(_SETTINGS_META, screen)
	screen.tree_exited.connect(func() -> void:
		if is_instance_valid(level):
			level.remove_meta(_SETTINGS_META))


## Confirmação "Abandonar a partida ?". Chamada pelo botão das configurações abertas sobre o jogo
## (`settings_screen`), que é fechado junto no "Sim". "Não" devolve o jogador às configurações, com a
## partida ainda pausada — quem retoma o jogo é o "Voltar" de lá.
static func confirm_abandon(level: Node, settings_screen: Node = null) -> void:
	if level.has_meta(_DIALOG_META) and is_instance_valid(level.get_meta(_DIALOG_META)):
		return
	# A janela é filha da TELA DE CONFIGURAÇÕES quando ela existe: assim aparece por cima dela (e não
	# atrás), e some junto se a tela for fechada por outro caminho.
	var host: Node = settings_screen if settings_screen != null else level
	var dialog := FloatingDialog.confirm(
		host, "Abandonar a partida", "Abandonar a partida ?", "Sim", "Não")
	# A partida já está pausada; a janela precisa seguir processando (ALWAYS) para os botões e o ESC
	# continuarem funcionando com a árvore parada.
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	level.set_meta(_DIALOG_META, dialog)
	level.get_tree().paused = true

	# Sim → despausa, fecha as configurações e volta à tela de níveis (o mouse já está visível, como a
	# UI 2D espera).
	dialog.confirmed.connect(func() -> void:
		if not (is_instance_valid(level) and level.is_inside_tree()):
			return
		level.get_tree().paused = false
		if is_instance_valid(settings_screen):
			settings_screen.queue_free()
		level.emit_signal(&"replace_main_scene", load(LEVELS_PATH)))

	# Não / × / ESC → volta às configurações (segue pausado e com o mouse visível). Sem tela de
	# configurações (chamada direta), retoma a partida como antes.
	dialog.canceled.connect(func() -> void:
		if not (is_instance_valid(level) and level.is_inside_tree()):
			return
		if is_instance_valid(settings_screen):
			return
		level.get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED))

	# Sempre, ao terminar: solta a referência da janela.
	dialog.closed.connect(func() -> void:
		if is_instance_valid(level):
			level.remove_meta(_DIALOG_META))
