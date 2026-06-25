class_name UIDialogs
extends RefCounted

## Estilo PADRÃO das janelas de confirmação/aviso do jogo. Centraliza o visual de TODAS as caixas
## (Sair do jogo, Resolução de vídeo, Restaurar padrões, Desconectar, avisos das sessões online e
## erros do CrashHandler) para que fiquem consistentes e legíveis:
##   • BOTÕES PADRÃO — aplica o tema do projeto (ui_theme) no próprio diálogo, então os botões
##     OK/Cancelar ganham o MESMO visual do resto da UI mesmo quando o diálogo é filho de um Node
##     sem tema (menu/settings/crash adicionavam ao root sem tema → antes saíam botões cinza padrão);
##   • JANELA MAIOR — min_size folgado;
##   • FONTES MAIORES — texto, título e botões ampliados.
##
## Uso:
##   var dlg := ConfirmationDialog.new()
##   dlg.dialog_text = ...; dlg.get_ok_button().text = ...   # textos primeiro
##   UIDialogs.style(dlg)                                     # depois o estilo
##   add_child(dlg); dlg.popup_centered()

const THEME: Theme = preload("res://themes/ui_theme.tres")
const MIN_SIZE := Vector2i(720, 340)
const TEXT_FONT_SIZE: int = 30
const TITLE_FONT_SIZE: int = 26
const BUTTON_FONT_SIZE: int = 30
const BUTTON_MIN_SIZE := Vector2(200, 60)


# Aplica o estilo padrão a um AcceptDialog ou ConfirmationDialog já criado (com os textos
# definidos). Chamar ANTES de popup_centered(); o min_size garante a janela maior mesmo que o
# conteúdo seja curto.
static func style(dlg: AcceptDialog) -> void:
	dlg.theme = THEME
	dlg.min_size = MIN_SIZE
	# Título maior (o título é a barra da janela — item de tema do Window/AcceptDialog).
	dlg.add_theme_font_size_override("title_font_size", TITLE_FONT_SIZE)
	# Texto da mensagem maior e centralizado.
	var label: Label = dlg.get_label()
	if label != null:
		label.add_theme_font_size_override("font_size", TEXT_FONT_SIZE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_constant_override("line_spacing", 8)
	# Botões padrão maiores (OK e, se houver, Cancelar).
	for btn in _buttons(dlg):
		btn.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
		btn.custom_minimum_size = BUTTON_MIN_SIZE


static func _buttons(dlg: AcceptDialog) -> Array:
	var out: Array = [dlg.get_ok_button()]
	if dlg is ConfirmationDialog:
		out.append((dlg as ConfirmationDialog).get_cancel_button())
	return out
