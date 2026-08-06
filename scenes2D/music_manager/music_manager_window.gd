class_name MusicManagerWindow
extends Node

## Gerenciador de Música: ATRIBUIR / REMOVER a trilha de cada cena ou level e OUVIR a escolhida.
## Aberto pela tela Settings, no botão "Gerenciar Músicas". As atribuições viram overrides
## persistidos pelo autoload MusicManager (seção "music" do Settings) e valem na hora.
##
## Audição: clicar no seletor de uma cena a SELECIONA (linha realçada); o trio ▶/⏸/⏹ do topo, único
## para a janela toda, age sobre a trilha efetiva dessa linha.
##
## Controlador: monta o formulário DENTRO da janela flutuante reutilizável (FloatingWindow), num
## CanvasLayer no topo — herda o tema 2D do projeto e o Debug 2D funciona sobre a janela, igual às
## demais janelas flutuantes. Faixas vêm de res://audios/.

const FLOATING_SCENE := preload("res://controls2D/floating_window/floating_window.tscn")

# 1ª opção de TODO dropdown: "Selecione..." = sem música definida (silêncio), a cena não toca. É o
# default de uma cena não configurada. "Padrão" é uma opção à parte (resolve pelo nome da cena).
const SELECT_LABEL := "Selecione..."
const DEFAULT_LABEL := "Padrão (pelo nome da cena)"
# Realce da linha SELECIONADA (a que os botões ▶/⏸/⏹ do topo controlam) e cor normal das demais.
const ACTIVE_COLOR := Color(1, 1, 0.313726, 1)
const IDLE_COLOR := Color(1, 1, 1, 1)

var _tracks: Array = []
var _win: FloatingWindow = null
var _scene_pickers: Dictionary = {}   # scene_key -> OptionButton
var _scene_labels: Dictionary = {}    # scene_key -> Label (realce da linha selecionada)
# Cena/level SELECIONADO: os controles de audição do topo agem sobre a trilha DELE. "" = nenhum.
var _active_key: String = ""
# Botões ▶/⏸/⏹ do topo, guardados para habilitar/desabilitar o ▶ conforme a linha selecionada.
var _listen_buttons: Array[Button] = []


# Abre o Gerenciador de Música numa janela flutuante (ou ignora se já está aberta). Chamado pela tela
# Settings ao habilitar "Música".
func popup_centered() -> void:
	if is_instance_valid(_win):
		return
	_open_window()


# Monta a janela flutuante (num CanvasLayer no topo), constrói o formulário no conteúdo e os botões de
# ação no rodapé, e a centraliza. Larga o bastante p/ caber, em cada linha de cena, o rótulo + dropdown
# + os 3 botões ▶/⏸/⏹ sem cortar. O CanvasLayer e a pré-escuta são liberados ao fechar.
#
# Os dropdowns usam `clip_text`: sem ele o OptionButton dimensiona pelo item MAIS LARGO (são ~43 faixas,
# com nomes NCS longos) e sozinho empurrava a janela para ~1530 px de largura. Truncado, o botão mostra
# o nome curto e a lista aberta continua exibindo o texto inteiro.
func _open_window() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	_win = FLOATING_SCENE.instantiate()
	# Mínimo modesto: o conteúdo mínimo real é ~552 px de largura (rótulo + dropdown truncado + ▶⏸⏹) e a
	# lista de cenas ROLA. Assim a janela cabe até em telas pequenas (1024×600); nas grandes ela cresce
	# até o teto de viewport da própria FloatingWindow.
	_win.min_window_size = Vector2(760, 420)
	layer.add_child(_win)
	add_child(layer)
	_win.set_title("Gerenciador de Música")
	_win.closed.connect(_on_window_closed.bind(layer))
	_tracks = MusicManager.list_tracks()
	_build_ui(_win.get_content())
	_refresh()
	_win.popup_centered()


func _on_window_closed(layer: CanvasLayer) -> void:
	MusicManager.stop_preview()
	MusicManager.resume_scene_track()
	if is_instance_valid(layer):
		layer.queue_free()
	_win = null


func _exit_tree() -> void:
	# Garante que a pré-escuta pare se o controlador for liberado junto com a tela.
	MusicManager.stop_preview()
	MusicManager.resume_scene_track()


func _build_ui(content: VBoxContainer) -> void:
	var root := content
	root.add_theme_constant_override("separation", 12)

	# ── Ouvir a música da cena SELECIONADA ───────────────────────────────
	# Um único trio ▶/⏸/⏹ centralizado, para a janela inteira: ele age sobre a linha selecionada lá
	# embaixo (clicar no seletor de uma cena a seleciona e a realça). Antes havia um dropdown de faixa
	# aqui em cima e mais um trio de botões por linha — três lugares para tocar a mesma coisa.
	var listen_row := HBoxContainer.new()
	listen_row.name = "ListenRow"
	listen_row.alignment = BoxContainer.ALIGNMENT_CENTER
	listen_row.add_theme_constant_override("separation", 8)
	root.add_child(listen_row)
	_listen_buttons = [
		_add_button(listen_row, "▶ Tocar", _on_listen_play),
		_add_button(listen_row, "⏸ Pausar", func() -> void: MusicManager.pause_playback()),
		_add_button(listen_row, "⏹ Parar", func() -> void: MusicManager.stop_playback()),
	]

	var listen_separator := HSeparator.new()
	listen_separator.name = "ListenSeparator"
	root.add_child(listen_separator)

	# ── Atribuição por cena/level ────────────────────────────────────────
	root.add_child(_section_title("Trilha por cena / level"))
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "\"%s\" = sem música (silêncio, padrão). \"%s\" toca audios/<nome-da-cena>. Ou escolha uma faixa. Clique num seletor para ouvi-lo com os botões acima." % [SELECT_LABEL, DEFAULT_LABEL]
	hint.modulate = Color(1, 1, 1, 0.7)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.name = "TracksScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "TracksList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for scene in MusicManager.scene_list():
		var key := String(scene["key"])
		var row := HBoxContainer.new()
		row.name = "TrackRow_%s" % key
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		var lbl := Label.new()
		lbl.name = "Track_%s" % key
		lbl.text = String(scene["label"])
		lbl.custom_minimum_size.x = 230
		row.add_child(lbl)
		_scene_labels[key] = lbl
		var picker := OptionButton.new()
		picker.name = "Tracks_%s" % key
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.clip_text = true
		_populate_scene_picker(picker)
		picker.item_selected.connect(_on_scene_track_selected.bind(key, picker))
		# Clicar no seletor (ou alcançá-lo por Tab) SELECIONA a linha: ela ganha realce e passa a ser
		# o alvo dos ▶/⏸/⏹ do topo. `focus_entered` cobre os dois caminhos — o clique dá foco ao
		# OptionButton antes de abrir a lista.
		picker.focus_entered.connect(_set_active_scene.bind(key))
		picker.item_selected.connect(func(_i: int) -> void: _set_active_scene(key))
		row.add_child(picker)
		_scene_pickers[key] = picker

	# ── Rodapé ───────────────────────────────────────────────────────────
	# "Sortear": sorteia uma faixa aleatória p/ cada cena/level e SALVA (recarregam na próxima
	# abertura). No rodapé da janela flutuante, junto do "Fechar".
	_win.add_footer_button("🎲 Sortear faixas").pressed.connect(_on_shuffle)
	_win.add_footer_button("Fechar").pressed.connect(_win.close)


func _refresh() -> void:
	for key in _scene_pickers:
		_select_value(_scene_pickers[key], MusicManager.assignment_of(key))
	_update_listen_row()


# Marca a cena/level SELECIONADO: realça sua linha (rótulo + seletor) e aponta para ela os ▶/⏸/⏹.
func _set_active_scene(key: String) -> void:
	if key == _active_key:
		return
	_active_key = key
	for k in _scene_pickers:
		var on: bool = k == _active_key
		(_scene_pickers[k] as Control).modulate = ACTIVE_COLOR if on else IDLE_COLOR
		(_scene_labels[k] as Control).modulate = ACTIVE_COLOR if on else IDLE_COLOR
	_update_listen_row()


# Habilitação dos controles de audição conforme a linha selecionada. Qual cena está no alvo é dito
# pelo REALCE da própria linha (não há rótulo aqui em cima).
# ⏸/⏹ agem na pré-escuta compartilhada e valem sempre; só o ▶ depende de haver trilha para tocar.
func _update_listen_row() -> void:
	if _listen_buttons.is_empty():
		return
	var track: String = MusicManager.effective_track(_active_key) if _active_key != "" else ""
	_listen_buttons[0].disabled = track == ""


func _on_listen_play() -> void:
	var track: String = MusicManager.effective_track(_active_key) if _active_key != "" else ""
	if track != "":
		MusicManager.preview_or_resume(track)


# Sorteia uma faixa aleatória de audios/ para CADA cena/level, persiste (override do MusicManager) e
# atualiza a tela → as escolhas ficam salvas e recarregam na próxima abertura da janela.
func _on_shuffle() -> void:
	if _tracks.is_empty():
		return
	for scene in MusicManager.scene_list():
		MusicManager.randomize_track(String(scene["key"]))
	_refresh()


# Itens do seletor de uma cena: Padrão / Sem música / cada faixa. O VALOR (default/none/arquivo) vai
# na metadata do item, então a ordem/idioma do texto não importa para salvar.
func _populate_scene_picker(picker: OptionButton) -> void:
	picker.clear()
	picker.add_item(SELECT_LABEL)                                  # 0: "Selecione..." = sem música (silêncio)
	picker.set_item_metadata(picker.item_count - 1, "none")
	picker.add_item(DEFAULT_LABEL)                                 # 1: "Padrão" = resolve pelo nome da cena
	picker.set_item_metadata(picker.item_count - 1, MusicManager.BYNAME)
	for t in _tracks:
		picker.add_item(_clean_label(String(t)))
		picker.set_item_metadata(picker.item_count - 1, String(t))


func _on_scene_track_selected(idx: int, key: String, picker: OptionButton) -> void:
	MusicManager.set_assignment(key, String(picker.get_item_metadata(idx)))
	# A trilha efetiva da linha mudou: o rótulo do topo (e o ▶) precisam refletir a escolha nova.
	_update_listen_row()


# Seleciona no picker o item cujo VALOR (metadata) bate com `value`; senão cai em "Padrão" (0).
# select() não emite item_selected → seguro chamar no _refresh sem disparar set_assignment.
func _select_value(picker: OptionButton, value: String) -> void:
	for i in picker.item_count:
		if String(picker.get_item_metadata(i)) == value:
			picker.select(i)
			return
	picker.select(0)


func _section_title(text: String) -> Label:
	var l := Label.new()
	l.name = "SectionTitle_%s" % text
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	return l


func _add_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = "ActionButton_%s" % text
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# Nome amigável para EXIBIR no dropdown (o valor real — nome do arquivo — fica na metadata do item).
# Os arquivos NCS vêm como "Artista - Título  Gênero  NCS - Copyright Free Music.mp3": o duplo espaço
# separa o "Artista - Título" do resto, então cortamos ali. Também remove a extensão e o sufixo NCS.
func _clean_label(filename: String) -> String:
	var cleaned := filename.get_basename()
	var cut := cleaned.find("  ")
	if cut > 0:
		cleaned = cleaned.substr(0, cut)
	cleaned = cleaned.replace(" NCS - Copyright Free Music", "").strip_edges()
	return cleaned if cleaned != "" else filename
