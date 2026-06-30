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


# TODOS os Controls focáveis (FOCUS_ALL, visíveis, BaseButton não desabilitado) sob `root`, em
# ORDEM DE ÁRVORE — que é a ordem de leitura da tela (cada controle do topo para baixo e, dentro de
# uma linha/HBox, da esquerda para a direita). Base do anel de Tab montado por wire_tab_ring.
func collect_focusables(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	_collect_focusables_into(root, out)
	return out


func _collect_focusables_into(root: Node, out: Array[Control]) -> void:
	for child in root.get_children():
		if child is Control:
			var c := child as Control
			var ok := c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree() \
					and not c.is_queued_for_deletion()
			if ok and c is BaseButton and (c as BaseButton).disabled:
				ok = false
			if ok:
				out.append(c)
		_collect_focusables_into(child, out)


# Liga o Tab/Shift+Tab num ANEL FECHADO seguindo a ordem de leitura (ordem de árvore) dos controles
# focáveis sob `root`: 1 → 2 → … → N → 1 (e o inverso no Shift+Tab). Garante índices de Tab
# INCREMENTAIS DE 1 (ver a linha "Tab" do DebugOverlay), começando no 1º controle do topo e seguindo
# para a direita e depois para a linha de baixo. Reaplique se o conjunto de focáveis mudar (ex.: um
# toggle injetado depois, ou um botão que troca de habilitado/desabilitado).
# `last` (opcional): se informado e presente, vai para o FIM do anel — recebe o MAIOR índice de Tab e
# é o último alcançado antes de voltar ao 1º (ex.: o botão × das janelas flutuantes, sempre por último).
func wire_tab_ring(root: Node, last: Control = null) -> void:
	var ring := collect_focusables(root)
	if last != null and ring.has(last):
		ring.erase(last)
		ring.append(last)
	var n := ring.size()
	if n < 2:
		return
	for i in n:
		var cur := ring[i]
		cur.focus_next = cur.get_path_to(ring[(i + 1) % n])
		cur.focus_previous = cur.get_path_to(ring[(i + n - 1) % n])


# Controle de Tab = 1 (CABEÇA do anel): 1º focável em ordem de leitura sob `root`, exceto `last` (que
# vai p/ o FIM do anel — ex.: o × das janelas flutuantes). Casa com a ordem montada por wire_tab_ring.
# Null se não houver focável.
func tab_one_control(root: Node, last: Control = null) -> Control:
	var ring := collect_focusables(root)
	if last != null:
		ring.erase(last)
	return ring[0] if not ring.is_empty() else null


# Dá foco ao controle de Tab = 1 (cabeça do anel) sob `root` — usado ao ABRIR uma tela/janela para o
# foco começar SEMPRE no 1º da sequência de Tab. Retorna o controle focado (ou null).
func focus_tab_one(root: Node, last: Control = null) -> Control:
	var head := tab_one_control(root, last)
	if head != null:
		head.grab_focus()
	return head
