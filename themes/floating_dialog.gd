class_name FloatingDialog
extends RefCounted

## Fábrica das janelas de confirmação/aviso do jogo, construídas sobre a cena reutilizável
## FloatingWindow (controle2D em scenes2D/controls2D/floating_window). Substitui o antigo
## UIDialogs + ConfirmationDialog/AcceptDialog nativos, padronizando o visual:
##   • mensagem CENTRALIZADA; botões de LARGURA UNIFORME; botão × igual ao das outras janelas;
##   • fundo modal (escurece + bloqueia o resto da UI); ESC = cancela; Enter = confirma (botão OK
##     em foco); foco devolvido ao controle anterior ao fechar.
## A janela vai num CanvasLayer no topo, então cobre qualquer cena (2D ou 3D) e se autolibera.
## Os textos são passados CRUS (chaves canônicas) — a janela os traduz e atualiza ao trocar idioma.
##
## Uso:
##   var dlg := FloatingDialog.confirm(self, "Sair do jogo", "Deseja sair do Zimaro ?", "Sim", "Não")
##   dlg.confirmed.connect(_on_sim)      # OK
##   dlg.canceled.connect(_on_nao)       # Cancelar / × / ESC          (opcional)
##   dlg.closed.connect(_on_fechou)      # sempre, ao terminar         (opcional)

const SCENE := preload("res://scenes2D/controls2D/floating_window/floating_window.tscn")
const MESSAGE_FONT_SIZE: int = 28
const MESSAGE_WIDTH: float = 560.0


# Confirmação (dois botões). Devolve o FloatingWindow já aberto sobre `parent`.
static func confirm(parent: Node, title: String, text: String, ok_text: String = "Sim", cancel_text: String = "Não") -> FloatingWindow:
	var win := _build(parent, title, text)
	var ok := win.add_footer_button(ok_text)
	var cancel := win.add_footer_button(cancel_text)
	ok.pressed.connect(func() -> void: win.confirmed.emit(); win.close())
	cancel.pressed.connect(func() -> void: win.canceled.emit(); win.close())
	win.popup_centered()
	return win


# Aviso (um botão OK). ESC/× também fecham (emitindo `canceled`).
static func alert(parent: Node, title: String, text: String, ok_text: String = "OK") -> FloatingWindow:
	var win := _build(parent, title, text)
	var ok := win.add_footer_button(ok_text)
	ok.pressed.connect(func() -> void: win.confirmed.emit(); win.close())
	win.popup_centered()
	return win


# Monta a janela num CanvasLayer no topo (cobre 2D e 3D), com título e mensagem central. O conteúdo
# (título/mensagem/botões) é definido DEPOIS de entrar na árvore — os @onready da cena já existem.
# O CanvasLayer é liberado junto quando a janela fecha.
static func _build(parent: Node, title: String, text: String) -> FloatingWindow:
	var layer := CanvasLayer.new()
	layer.layer = 128
	var win: FloatingWindow = SCENE.instantiate()
	layer.add_child(win)
	parent.add_child(layer)
	win.set_title(title)
	if text != "":
		_add_message(win, text)
	win.closed.connect(layer.queue_free)
	return win


static func _add_message(win: FloatingWindow, text: String) -> void:
	var lbl := Label.new()
	lbl.add_to_group(Locale.SKIP_GROUP)
	lbl.set_meta("loc_key", text)
	lbl.text = Locale.tr_key(text)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(MESSAGE_WIDTH, 0)
	lbl.add_theme_font_size_override("font_size", MESSAGE_FONT_SIZE)
	win.get_content().add_child(lbl)
