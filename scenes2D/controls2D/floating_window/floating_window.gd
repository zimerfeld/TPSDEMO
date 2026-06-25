class_name FloatingWindow
extends Control

## Janela flutuante reutilizável — base das janelas de confirmação/aviso (via FloatingDialog) e de
## outras janelas flutuantes do jogo. Control de tela cheia com um Backdrop opcional (escurece o
## fundo e BLOQUEIA o mouse quando modal) e uma janela central ARRASTÁVEL pela barra de título:
##   • barra de título com o título CENTRALIZADO + botão × padrão;
##   • área de conteúdo exposta por get_content();
##   • rodapé (Footer) de botões com LARGURA UNIFORME, criados por add_footer_button().
## Visual idêntico aos painéis Dano/IA (fundo preto opaco) para a UI ficar consistente. Os textos
## (título/botões/mensagem) seguem o Locale via SKIP_GROUP e re-traduzem ao trocar de idioma.
##
## Uso direto (janela genérica):
##   var w := preload("res://scenes2D/controls2D/floating_window/floating_window.tscn").instantiate()
##   add_child(w)
##   w.set_title("Título"); w.get_content().add_child(meu_conteudo)
##   w.add_footer_button("OK").pressed.connect(_ok)
##   w.popup_centered()
## Para confirmação/aviso, prefira o helper FloatingDialog (confirm/alert).

signal closed            ## Fechou (qualquer caminho), já com o foco anterior restaurado.
signal close_requested   ## Antes de fechar — deixa o dono reagir (× e ESC passam por aqui).
signal confirmed         ## Enter/botão OK (usado pelo FloatingDialog).
signal canceled          ## ESC/×/botão Cancelar (usado pelo FloatingDialog).

@export var title: String = "":
	set(value):
		title = value
		if is_node_ready():
			set_title(value)
@export var modal: bool = true
@export var close_on_escape: bool = true
@export var min_window_size: Vector2 = Vector2(420, 150)
## Quando != "", restaura/salva a posição da janela em Settings ("windows", <chave>). Vazio
## (default) = não mexe em Settings — seguro no previewer e em janelas descartáveis.
@export var remember_position_key: String = ""

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _prev_focus: Control = null
var _closing: bool = false

@onready var _backdrop: ColorRect = %Backdrop
@onready var _window: PanelContainer = %Window
@onready var _titlebar: PanelContainer = %TitleBar
@onready var _left_pad: Control = %LeftPad
@onready var _title_label: Label = %TitleLabel
@onready var _close_button: Button = %CloseButton
@onready var _content: VBoxContainer = %Content
@onready var _footer: HBoxContainer = %Footer


func _ready() -> void:
	_apply_window_style()
	_titlebar.gui_input.connect(_on_titlebar_input)
	_close_button.pressed.connect(_on_close_pressed)
	_close_button.tooltip_text = Locale.tr_key("Fechar")
	_window.custom_minimum_size = min_window_size
	_backdrop.color = Color(0, 0, 0, 0.55)
	_backdrop.visible = false
	Locale.language_changed.connect(_on_language_changed)
	set_title(title)
	# Standalone (previewer) ou direto: posiciona/centraliza após o layout assentar. Se popup_centered()
	# for chamado em seguida, ele re-posiciona depois (vence por rodar por último).
	_layout.call_deferred()


# Estilo da janela (preto opaco + borda) e da barra de título — igual aos painéis Dano/IA.
func _apply_window_style() -> void:
	var win_style := StyleBoxFlat.new()
	win_style.bg_color = Color(0, 0, 0, 1)
	win_style.border_color = Color(1, 1, 1, 0.18)
	win_style.set_border_width_all(1)
	win_style.set_corner_radius_all(4)
	_window.add_theme_stylebox_override("panel", win_style)
	var tb_style := StyleBoxFlat.new()
	tb_style.bg_color = Color(0.16, 0.16, 0.2, 1)
	tb_style.border_color = Color(1, 1, 1, 0.12)
	tb_style.border_width_bottom = 1
	tb_style.content_margin_left = 10
	tb_style.content_margin_right = 6
	tb_style.content_margin_top = 4
	tb_style.content_margin_bottom = 4
	_titlebar.add_theme_stylebox_override("panel", tb_style)
	_titlebar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	style_close_button(_close_button)


# Estilo PADRÃO do botão × de QUALQUER janela (esta cena E os painéis Dano/IA do models.gd): fundo
# CINZA sem foco e VERMELHO MEIO ESCURO com foco/hover/pressionado, sempre com texto BRANCO opaco. Sem
# o skew dos botões do tema (× compacto). Centraliza o visual dos botões de fechamento de janela.
static func style_close_button(btn: Button) -> void:
	var gray := StyleBoxFlat.new()
	gray.bg_color = Color(0.33, 0.33, 0.35, 1)
	gray.set_corner_radius_all(3)
	var red := StyleBoxFlat.new()
	red.bg_color = Color(0.5, 0.12, 0.12, 1)
	red.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", gray)
	btn.add_theme_stylebox_override("hover", red)
	btn.add_theme_stylebox_override("pressed", red)
	btn.add_theme_stylebox_override("focus", red)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))


# ── API pública ──────────────────────────────────────────────────────────────

# Define o título (centralizado). O texto entra no SKIP_GROUP do Locale e re-traduz por idioma.
func set_title(text: String) -> void:
	if _title_label == null:
		return
	_title_label.add_to_group(Locale.SKIP_GROUP)
	_title_label.set_meta("loc_key", text)
	_title_label.text = Locale.tr_key(text)


# Container onde o chamador insere o conteúdo da janela.
func get_content() -> VBoxContainer:
	return _content


# Cria um botão temado no rodapé (texto traduzido via SKIP_GROUP) e o devolve p/ o chamador conectar
# `pressed`. A largura uniforme é (re)aplicada por set_uniform_footer_widths() ao abrir/trocar idioma.
func add_footer_button(src_text: String) -> Button:
	var btn := Button.new()
	btn.add_to_group(Locale.SKIP_GROUP)
	btn.set_meta("loc_key", src_text)
	btn.text = Locale.tr_key(src_text)
	btn.focus_mode = Control.FOCUS_ALL
	_footer.add_child(btn)
	_footer.visible = true
	return btn


# Iguala a largura de TODOS os botões do rodapé ao maior (com um piso), para um visual uniforme.
func set_uniform_footer_widths(floor_px: float = 200.0) -> void:
	var w := floor_px
	for child in _footer.get_children():
		if child is Button:
			w = maxf(w, (child as Button).get_combined_minimum_size().x)
	for child in _footer.get_children():
		if child is Button:
			(child as Button).custom_minimum_size.x = w


# Abre a janela centralizada. Se `modal`, escurece e bloqueia o fundo. Guarda o foco atual para
# restaurá-lo ao fechar e foca o primeiro botão do rodapé (Enter aciona o OK).
func popup_centered() -> void:
	visible = true
	_backdrop.visible = modal
	if is_inside_tree():
		_prev_focus = get_viewport().gui_get_focus_owner()
	_layout.call_deferred()
	_grab_initial_focus.call_deferred()


# Fecha a janela: salva posição (se aplicável), restaura o foco anterior e se autolibera.
func close() -> void:
	if _closing:
		return
	_closing = true
	close_requested.emit()
	if remember_position_key != "":
		_save_position()
	if _prev_focus != null and is_instance_valid(_prev_focus) and _prev_focus.is_visible_in_tree():
		_prev_focus.grab_focus()
	elif get_parent() != null:
		UINav.focus_first(get_parent())
	closed.emit()
	queue_free()


# ── Layout / posição ─────────────────────────────────────────────────────────

func _layout() -> void:
	if not is_inside_tree() or _closing:
		return
	_sync_left_pad()
	set_uniform_footer_widths()
	if not _restore_saved_position():
		_center_window()
	_clamp_to_viewport()


# Iguala a largura do espaçador esquerdo à do botão × → o título fica CENTRALIZADO de fato.
func _sync_left_pad() -> void:
	_left_pad.custom_minimum_size.x = _close_button.size.x


func _center_window() -> void:
	var vp := get_viewport_rect().size
	_window.position = ((vp - _window.size) * 0.5).round()


# Mantém a janela INTEIRA dentro da viewport (espelha o clamp de Dano/IA).
func _clamp_to_viewport() -> void:
	var vp := get_viewport_rect().size
	var sz := _window.size
	var pos := _window.position
	pos.x = clampf(pos.x, 0.0, maxf(0.0, vp.x - sz.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, vp.y - sz.y))
	_window.position = pos


func _restore_saved_position() -> bool:
	if remember_position_key == "":
		return false
	var saved: Variant = Settings.config_file.get_value("windows", remember_position_key, null)
	if saved is Vector2:
		_window.position = saved
		return true
	return false


func _save_position() -> void:
	Settings.config_file.set_value("windows", remember_position_key, _window.position)
	Settings.save_settings()


# ── Arraste pela barra de título ─────────────────────────────────────────────

func _on_titlebar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (event as InputEventMouseButton).pressed
		if _dragging:
			_drag_offset = _window.position - _window.get_global_mouse_position()
		elif remember_position_key != "":
			_save_position()
	elif event is InputEventMouseMotion and _dragging:
		_window.position = _window.get_global_mouse_position() + _drag_offset
		_clamp_to_viewport()


func _process(_delta: float) -> void:
	# Encerra um arraste preso se o botão foi solto fora da barra de título.
	if _dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dragging = false
		if remember_position_key != "":
			_save_position()


# ── Foco / teclado ───────────────────────────────────────────────────────────

func _grab_initial_focus() -> void:
	if not is_inside_tree() or not visible:
		return
	var first := UINav.first_focusable(_footer)
	if first == null:
		first = UINav.first_focusable(_content)
	if first == null:
		first = _close_button
	if first != null:
		first.grab_focus()


# ESC fecha (cancelando). É consumido aqui para a tela de fundo não navegar junto — a janela é
# descendente da tela e adicionada por último, então recebe o input ANTES do _input da tela.
func _input(event: InputEvent) -> void:
	if not visible or not is_inside_tree() or _closing:
		return
	if close_on_escape and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("quit")):
		canceled.emit()
		close()
		get_viewport().set_input_as_handled()


func _on_close_pressed() -> void:
	canceled.emit()
	close()


# ── Tradução por idioma ──────────────────────────────────────────────────────

func _on_language_changed(_lang: String) -> void:
	_close_button.tooltip_text = Locale.tr_key("Fechar")
	_retranslate_tree(_window)
	set_uniform_footer_widths()


# Re-traduz todo Label/Button do SKIP_GROUP sob a janela a partir da chave salva em meta "loc_key".
func _retranslate_tree(node: Node) -> void:
	if node.has_meta("loc_key") and (node is Label or node is Button):
		node.set("text", Locale.tr_key(node.get_meta("loc_key")))
	for child in node.get_children():
		_retranslate_tree(child)
