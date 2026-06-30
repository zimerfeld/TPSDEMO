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


# Metadata (int 1-based) que declara a ORDEM EXPLÍCITA de Tab de um controle — definida no .tscn como
# `metadata/tab_order = N`. Quando presente, manda na ordenação do anel (e o Debug 2D mostra esse valor
# ESPERADO). Controles sem o metadado caem DEPOIS dos numerados, mantendo a ordem de árvore entre si
# (ex.: o toggle Debug 2D injetado em runtime na barra Actions). Ver [[convencoes/navegacao-tab]].
const TAB_ORDER_META := &"tab_order"
const _TAB_ORDER_UNSET := 1 << 30


# TODOS os Controls focáveis (FOCUS_ALL, visíveis, BaseButton não desabilitado) sob `root`, na ORDEM DE
# TAB: primeiro pelo metadado `tab_order` (crescente) e, entre os SEM metadado (ou empatados), pela
# ordem de árvore — que é a ordem de leitura da tela (topo→baixo, e numa HBox esquerda→direita). Base do
# anel de Tab montado por wire_tab_ring.
func collect_focusables(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	_collect_focusables_into(root, out, true)
	_sort_by_tab_order(out)
	return out


# Como collect_focusables, mas IGNORA a visibilidade — usado para varrer os focáveis de uma aba OCULTA
# do TabContainer (a sequência de Tab precisa abranger TODAS as abas, não só a visível). Ver
# collect_focus_order_with_tabs.
func collect_focusables_ignoring_visibility(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	_collect_focusables_into(root, out, false)
	_sort_by_tab_order(out)
	return out


func _collect_focusables_into(root: Node, out: Array[Control], respect_visibility: bool) -> void:
	for child in root.get_children():
		if child is Control:
			var c := child as Control
			var ok := c.focus_mode == Control.FOCUS_ALL and not c.is_queued_for_deletion()
			if ok and respect_visibility and not c.is_visible_in_tree():
				ok = false
			if ok and c is BaseButton and (c as BaseButton).disabled:
				ok = false
			if ok:
				out.append(c)
		_collect_focusables_into(child, out, respect_visibility)


# Ordena ESTAVELMENTE pelo metadado `tab_order`: os controles que o declaram vêm primeiro (crescente);
# os demais ficam no fim, na ordem de árvore original. O índice de árvore desempata (sort determinístico).
func _sort_by_tab_order(arr: Array[Control]) -> void:
	var n := arr.size()
	if n < 2:
		return
	var tree_idx := {}
	for i in n:
		tree_idx[arr[i]] = i
	arr.sort_custom(func(a: Control, b: Control) -> bool:
		var oa := tab_order_of(a)
		var ob := tab_order_of(b)
		if oa == ob:
			return int(tree_idx[a]) < int(tree_idx[b])
		return oa < ob)


# Valor declarado de `tab_order` do controle (1-based), ou um sentinela grande quando não declarado.
func tab_order_of(c: Control) -> int:
	if c != null and c.has_meta(TAB_ORDER_META):
		var v: int = int(c.get_meta(TAB_ORDER_META))
		if v > 0:
			return v
	return _TAB_ORDER_UNSET


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


# ── TabContainer: navegação por Tab atravessando as abas (regra do projeto 2026-06-30) ──────────────
# Sequência de Tab para uma cena/janela que contém um TabContainer:
#   focáveis ANTES do TabContainer (ordem de leitura)
#     → aba 0 (todos os focáveis) → aba 1 → … → aba N-1
#       → focáveis DEPOIS do TabContainer → (volta ao 1º, fechando o anel)
# Atravessa abas OCULTAS (a sequência abrange TODAS as abas). Ao cruzar a fronteira de uma aba, troca a
# aba VISÍVEL e realça o 1º controle da aba seguinte; só "sai" do TabContainer (vai para os focáveis
# DEPOIS dele) quando se está no último controle da ÚLTIMA aba e Tab é pressionado de novo.

# Ordem GLOBAL de foco da cena, com cada aba do TabContainer expandida em sequência (abas ocultas
# incluídas). Os controles fora do TabContainer entram na ordem de leitura/`tab_order` habitual.
func collect_focus_order_with_tabs(scene_root: Node, tab_container: TabContainer) -> Array[Control]:
	var out: Array[Control] = []
	_walk_focus_order(scene_root, tab_container, out)
	return out


func _walk_focus_order(node: Node, tab_container: TabContainer, out: Array[Control]) -> void:
	for child in node.get_children():
		if child == tab_container:
			# Expande as abas em ORDEM DE ABA — inclusive as ocultas (ignora visibilidade aqui dentro).
			for i in (tab_container as TabContainer).get_tab_count():
				var tab := (tab_container as TabContainer).get_tab_control(i)
				if tab != null:
					out.append_array(collect_focusables_ignoring_visibility(tab))
			continue
		if child is Control:
			var c := child as Control
			var ok := c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree() \
					and not c.is_queued_for_deletion()
			if ok and c is BaseButton and (c as BaseButton).disabled:
				ok = false
			if ok:
				out.append(c)
		_walk_focus_order(child, tab_container, out)


# Índice da aba (em `tab_container`) que contém `ctrl`, ou -1 se ctrl está fora do TabContainer.
func _tab_index_of(tab_container: TabContainer, ctrl: Control) -> int:
	for i in tab_container.get_tab_count():
		var tab := tab_container.get_tab_control(i)
		if tab != null and (tab == ctrl or tab.is_ancestor_of(ctrl)):
			return i
	return -1


# Processa um passo de Tab (forward=true) / Shift+Tab (forward=false) numa cena com TabContainer,
# atravessando as abas conforme a regra acima. Chame do _input da cena ao detectar ui_focus_next /
# ui_focus_prev e CONSUMA o evento se retornar true. Troca a aba visível quando o próximo/anterior
# controle pertence a outra aba e foca-o (deferido, após a aba aparecer). Retorna false (não consumir)
# só se não houver focáveis.
func tab_container_focus_step(scene_root: Node, tab_container: TabContainer, forward: bool) -> bool:
	if not is_instance_valid(tab_container):
		return false
	var order := collect_focus_order_with_tabs(scene_root, tab_container)
	if order.is_empty():
		return false
	var viewport := tab_container.get_viewport()
	var focused: Control = viewport.gui_get_focus_owner() if viewport != null else null
	var idx := order.find(focused) if focused != null else -1
	var n := order.size()
	var target_idx: int
	if idx == -1:
		target_idx = 0 if forward else n - 1
	else:
		target_idx = (idx + (1 if forward else -1) + n) % n
	var target := order[target_idx]
	if not is_instance_valid(target):
		return false
	var tab_i := _tab_index_of(tab_container, target)
	if tab_i != -1 and tab_container.current_tab != tab_i:
		# O alvo está numa aba OCULTA: torna-a visível e só então foca (a aba precisa montar o layout).
		tab_container.current_tab = tab_i
		target.grab_focus.call_deferred()
	else:
		target.grab_focus()
	return true
