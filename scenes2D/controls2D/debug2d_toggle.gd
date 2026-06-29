class_name Debug2DToggle
extends CheckButton
## Toggle reutilizável para Ativar/Desativar o Debug 2D a partir da barra "Actions" de qualquer
## cena. Lê/grava Settings("game","debug_2d") e atualiza o DebugOverlay na hora — espelha o que a
## tela developer já faz, mas como um único controle pronto para ser injetado em qualquer Actions.
##
## O DebugOverlay injeta uma instância deste toggle na barra Actions de cada tela ativa — ver
## DebugOverlay._ensure_debug2d_toggle. A tela developer também o usa, mas o injeta ela mesma
## (developer._ensure_actions_debug2d), para mantê-lo em sincronia com o seu par Desativado/Ativado
## da coluna Debug 2D — por isso o DebugOverlay a pula.

const _CONFIG_KEY := "debug_2d"


func _ready() -> void:
	if text.strip_edges() == "":
		text = "Debug 2D"
	# Reflete o estado salvo SEM disparar o handler (conecta depois de set_pressed).
	set_pressed_no_signal(Settings.config_file.get_value("game", _CONFIG_KEY, false))
	toggled.connect(_on_toggled)


func _on_toggled(toggled_on: bool) -> void:
	# Idempotente: nada a fazer se o valor já bate (evita save/refresh redundantes).
	if Settings.config_file.get_value("game", _CONFIG_KEY, false) == toggled_on:
		return
	Settings.config_file.set_value("game", _CONFIG_KEY, toggled_on)
	Settings.save_settings()
	DebugOverlay.refresh()
