extends Node

## Autoload UINav — helpers de navegação por teclado das telas 2D. Chamado como
## UINav.focus_first(...) / UINav.cancel_active_edit(...). Centraliza duas regras que toda
## tela compartilha:
##   1. Foco inicial — para as setas do teclado navegarem entre os botões, ALGUM controle
##      precisa estar focado ao abrir a tela (o Godot já calcula os vizinhos de foco e
##      mapeia ui_up/down/left/right para as setas; só falta dar o foco de partida).
##   2. ESC interrompe primeiro o preenchimento de um campo/seleção, antes de voltar de
##      tela: se um LineEdit (inclusive o editor interno de um SpinBox) está em edição,
##      ESC encerra essa edição e o chamador NÃO navega de volta (precisa de um 2º ESC).


# Encerra a edição de um campo de texto em foco (LineEdit, ou o LineEdit interno de um
# SpinBox), devolvendo o foco a `fallback` para as setas continuarem funcionando. Retorna
# true se havia uma edição em andamento — nesse caso o chamador deve consumir o ESC e NÃO
# voltar de tela. Retorna false quando não há campo em edição (ESC segue para "voltar").
func cancel_active_edit(viewport: Viewport, fallback: Control = null) -> bool:
	if viewport == null:
		return false
	var focused := viewport.gui_get_focus_owner()
	if focused is LineEdit:
		(focused as LineEdit).release_focus()
		if fallback != null and is_instance_valid(fallback) and fallback.is_visible_in_tree():
			fallback.grab_focus()
		return true
	return false


# Dá foco ao primeiro controle focável (visível e não desabilitado) sob `root`, em ordem de
# árvore. Retorna o controle focado (ou null se não houver nenhum). Chamado no _ready de cada
# tela para habilitar a navegação por setas a partir de um ponto previsível.
func focus_first(root: Node) -> Control:
	var ctrl := first_focusable(root)
	if ctrl != null:
		ctrl.grab_focus()
	return ctrl


# Primeiro Control focável (FOCUS_ALL, visível, BaseButton não desabilitado) em ordem de
# árvore sob `node`, ou null. Também usado pelo DebugOverlay para achar o início da cadeia
# de foco ao numerar o índice de Tab dos controles.
func first_focusable(node: Node) -> Control:
	if node is Control:
		var c := node as Control
		var ok := c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree()
		if ok and c is BaseButton and (c as BaseButton).disabled:
			ok = false
		if ok:
			return c
	for child in node.get_children():
		var found := first_focusable(child)
		if found != null:
			return found
	return null
