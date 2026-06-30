class_name MusicManagerWindow
extends Node

## Gerenciador de Música: ouvir qualquer faixa de Audios/ e ATRIBUIR / REMOVER a trilha de cada
## cena ou level. Aberto pela tela Settings ao habilitar "Música". As atribuições viram overrides
## persistidos pelo autoload MusicManager (seção "music" do Settings) e valem na hora.
##
## Controlador: monta o formulário DENTRO da janela flutuante reutilizável (FloatingWindow), num
## CanvasLayer no topo — herda o tema 2D do projeto e o Debug 2D funciona sobre a janela, igual às
## demais janelas flutuantes. Faixas vêm de res://Audios/.

const FLOATING_SCENE := preload("res://scenes2D/controls2D/floating_window/floating_window.tscn")

# 1ª opção de TODO dropdown: "Selecione..." = sem música definida (silêncio), a cena não toca. É o
# default de uma cena não configurada. "Padrão" é uma opção à parte (resolve pelo nome da cena).
const SELECT_LABEL := "Selecione..."
const DEFAULT_LABEL := "Padrão (pelo nome da cena)"
# Estado de UI persistido (a faixa escolhida no "Ouvir faixa"), restaurado na próxima abertura.
const UI_SECTION := "music_ui"
const LISTEN_KEY := "listen"

var _tracks: Array = []
var _win: FloatingWindow = null
var _listen_picker: OptionButton
var _scene_pickers: Dictionary = {}   # scene_key -> OptionButton


# Abre o Gerenciador de Música numa janela flutuante (ou ignora se já está aberta). Chamado pela tela
# Settings ao habilitar "Música".
func popup_centered() -> void:
	if is_instance_valid(_win):
		return
	_open_window()


# Monta a janela flutuante (num CanvasLayer no topo), constrói o formulário no conteúdo e os botões de
# ação no rodapé, e a centraliza. Larga o bastante p/ caber, em cada linha de cena, o rótulo + dropdown
# + os 3 botões ▶/⏸/⏹ sem cortar. O CanvasLayer e a pré-escuta são liberados ao fechar.
func _open_window() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	_win = FLOATING_SCENE.instantiate()
	_win.min_window_size = Vector2(900, 540)
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
	if is_instance_valid(layer):
		layer.queue_free()
	_win = null


func _exit_tree() -> void:
	# Garante que a pré-escuta pare se o controlador for liberado junto com a tela.
	MusicManager.stop_preview()


func _build_ui(content: VBoxContainer) -> void:
	var root := content
	root.add_theme_constant_override("separation", 12)

	# ── Ouvir qualquer faixa ─────────────────────────────────────────────
	root.add_child(_section_title("Ouvir faixa"))
	var listen_row := HBoxContainer.new()
	listen_row.name = "ListenRow"
	listen_row.add_theme_constant_override("separation", 8)
	root.add_child(listen_row)
	_listen_picker = OptionButton.new()
	_listen_picker.name = "ListenPicker"
	_listen_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listen_row.add_child(_listen_picker)
	# Persiste a faixa escolhida para ouvir → restaurada na próxima abertura (persistir estado).
	_listen_picker.item_selected.connect(func(_i: int) -> void:
		if not _tracks.is_empty():
			Settings.config_file.set_value(UI_SECTION, LISTEN_KEY, String(_listen_picker.get_item_metadata(_listen_picker.selected)))
			Settings.save_settings())
	_add_button(listen_row, "▶ Tocar", func() -> void:
		if _listen_picker.selected > 0:   # 0 = "Selecione..." (nada para ouvir)
			MusicManager.preview_or_resume(String(_listen_picker.get_item_metadata(_listen_picker.selected))))
	_add_button(listen_row, "⏸ Pausar", func() -> void: MusicManager.pause_preview())
	_add_button(listen_row, "⏹ Parar", func() -> void: MusicManager.stop_preview())

	var listen_separator := HSeparator.new()
	listen_separator.name = "ListenSeparator"
	root.add_child(listen_separator)

	# ── Atribuição por cena/level ────────────────────────────────────────
	root.add_child(_section_title("Trilha por cena / level"))
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "\"%s\" = sem música (silêncio, padrão). \"%s\" toca Audios/<nome-da-cena>. Ou escolha uma faixa." % [SELECT_LABEL, DEFAULT_LABEL]
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
		lbl.name = "TrackLabel_%s" % key
		lbl.text = String(scene["label"])
		lbl.custom_minimum_size.x = 230
		row.add_child(lbl)
		var picker := OptionButton.new()
		picker.name = "TrackPicker_%s" % key
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_populate_scene_picker(picker)
		picker.item_selected.connect(_on_scene_track_selected.bind(key, picker))
		row.add_child(picker)
		_scene_pickers[key] = picker
		# ▶ / ⏸ / ⏹ por linha: ouve, pausa e para a trilha EFETIVA daquela cena (já considerando a
		# escolha atual). Pausa/parar agem na pré-escuta compartilhada (só uma toca por vez).
		var play_btn := _add_button(row, "▶", func() -> void:
			var fname := MusicManager.effective_track(key)
			if fname != "":
				MusicManager.preview_or_resume(fname))
		play_btn.tooltip_text = "Tocar"
		_add_button(row, "⏸", func() -> void: MusicManager.pause_preview()).tooltip_text = "Pausar"
		_add_button(row, "⏹", func() -> void: MusicManager.stop_preview()).tooltip_text = "Parar"

	# ── Rodapé ───────────────────────────────────────────────────────────
	# "Sortear": sorteia uma faixa aleatória p/ cada cena/level e SALVA (recarregam na próxima
	# abertura). No rodapé da janela flutuante, junto do "Fechar".
	_win.add_footer_button("🎲 Sortear faixas").pressed.connect(_on_shuffle)
	_win.add_footer_button("Fechar").pressed.connect(_win.close)


func _refresh() -> void:
	_listen_picker.clear()
	if _tracks.is_empty():
		_listen_picker.add_item("(nenhuma faixa em Audios/)")
		_listen_picker.disabled = true
	else:
		_listen_picker.disabled = false
		_listen_picker.add_item(SELECT_LABEL)                      # 0: "Selecione..." (nada p/ ouvir)
		_listen_picker.set_item_metadata(0, "")
		for t in _tracks:
			_listen_picker.add_item(_clean_label(String(t)))
			_listen_picker.set_item_metadata(_listen_picker.item_count - 1, String(t))
		_restore_listen_choice()
	for key in _scene_pickers:
		_select_value(_scene_pickers[key], MusicManager.assignment_of(key))


# Sorteia uma faixa aleatória de Audios/ para CADA cena/level, persiste (override do MusicManager) e
# atualiza a tela → as escolhas ficam salvas e recarregam na próxima abertura da janela.
func _on_shuffle() -> void:
	if _tracks.is_empty():
		return
	for scene in MusicManager.scene_list():
		MusicManager.set_assignment(String(scene["key"]), String(_tracks[randi() % _tracks.size()]))
	_refresh()


# Reseleciona no "Ouvir faixa" a faixa salva da última vez (casa por metadata = nome do arquivo).
func _restore_listen_choice() -> void:
	var saved := String(Settings.config_file.get_value(UI_SECTION, LISTEN_KEY, ""))
	if saved == "":
		return
	for i in _listen_picker.item_count:
		if String(_listen_picker.get_item_metadata(i)) == saved:
			_listen_picker.select(i)
			return


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
