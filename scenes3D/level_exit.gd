class_name LevelExit
extends RefCounted

## Saída de um nível pela ação "quit" (ESC). Centraliza a lógica usada por level_1.gd /
## level_2.gd para não duplicá-la. Comportamento por modo:
##   • Offline (partida solo): abre a confirmação "Abandonar a partida ?" (Sim/Não). Enquanto a
##     pergunta está aberta, a PARTIDA FICA PAUSADA. Sim → volta à tela de níveis; Não / × / ESC →
##     retoma a partida exatamente de onde parou.
##   • Online (salas host/cliente): mantém o comportamento antigo — ESC volta direto ao menu.

const LEVELS_PATH := "res://scenes2D/levels/levels.tscn"
# Referência da janela de confirmação, guardada no próprio nível (impede abrir duas ao pressionar
# ESC repetidamente antes de a primeira responder).
const _DIALOG_META := &"abandon_dialog"


# Chamado no _input do nível quando a ação "quit" é pressionada.
static func request_exit(level: Node) -> void:
	# Libera o mouse para o jogador clicar (tanto na pergunta offline quanto ao voltar ao menu online).
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Online: ESC volta ao menu principal (o sinal "quit" já é ligado a main.go_to_main_menu).
	if PlayerSelection.online_mode:
		level.emit_signal(&"quit")
		return

	# Offline: uma pergunta por vez.
	if level.has_meta(_DIALOG_META) and is_instance_valid(level.get_meta(_DIALOG_META)):
		return

	var dialog := FloatingDialog.confirm(
		level, "Abandonar a partida", "Abandonar a partida ?", "Sim", "Não")
	# A partida pausa enquanto a pergunta está aberta; a janela precisa seguir processando (ALWAYS)
	# para os botões/ESC continuarem funcionando com a árvore pausada.
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	level.set_meta(_DIALOG_META, dialog)
	level.get_tree().paused = true

	# Sim → despausa e volta à tela de níveis (o mouse já está visível, como a UI 2D espera).
	dialog.confirmed.connect(func() -> void:
		if is_instance_valid(level) and level.is_inside_tree():
			level.get_tree().paused = false
			level.emit_signal(&"replace_main_scene", load(LEVELS_PATH)))

	# Não / × / ESC → retoma a partida (despausa e recaptura o mouse).
	dialog.canceled.connect(func() -> void:
		if is_instance_valid(level) and level.is_inside_tree():
			level.get_tree().paused = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED))

	# Sempre, ao terminar: solta a referência da janela.
	dialog.closed.connect(func() -> void:
		if is_instance_valid(level):
			level.remove_meta(_DIALOG_META))
