class_name InputBindings
extends RefCounted
## Remapeamento de teclas/botões do jogador (aba **Controles** das configurações).
##
## As ações e seus eventos PADRÃO vivem no `project.godot`; aqui guardamos apenas o que o jogador
## MUDOU, em `Settings.config_file`, seção `bindings` — uma entrada por ação alterada. Seção vazia =
## tudo no padrão de fábrica, então o arquivo de configuração de quem nunca remapeou continua limpo.
##
## O `Settings` (autoload) chama `apply_saved()` no boot, depois de carregar o arquivo: sem isso o
## remapeamento só valeria na sessão em que foi feito.

## Ações expostas na aba, na ordem em que aparecem. `group` separa as seções da tela; `label` é a
## chave de tradução (ver `scenes2D/settings/Resources/settings.*.json`).
const ACTIONS: Array[Dictionary] = [
	{"action": "move_forward", "label": "Andar para frente", "group": "Movimento"},
	{"action": "move_back", "label": "Andar para trás", "group": "Movimento"},
	{"action": "move_left", "label": "Andar para a esquerda", "group": "Movimento"},
	{"action": "move_right", "label": "Andar para a direita", "group": "Movimento"},
	{"action": "jump", "label": "Pular", "group": "Movimento"},
	{"action": "run", "label": "Correr (segurar)", "group": "Movimento"},
	{"action": "crouch", "label": "Abaixar (segurar)", "group": "Movimento"},
	{"action": "aim", "label": "Mirar", "group": "Combate"},
	{"action": "shoot", "label": "Atirar", "group": "Combate"},
	{"action": "toggle_aim_side", "label": "Trocar o lado da mira", "group": "Combate"},
	{"action": "view_up", "label": "Olhar para cima", "group": "Câmera"},
	{"action": "view_down", "label": "Olhar para baixo", "group": "Câmera"},
	{"action": "view_left", "label": "Olhar para a esquerda", "group": "Câmera"},
	{"action": "view_right", "label": "Olhar para a direita", "group": "Câmera"},
	{"action": "quit", "label": "Sair / pausar", "group": "Sistema"},
	{"action": "toggle_fullscreen", "label": "Tela cheia", "group": "Sistema"},
	{"action": "toggle_debug", "label": "Depuração", "group": "Sistema"},
]

const SECTION := "bindings"

# Eventos de fábrica (do project.godot), capturados ANTES de qualquer override — é a eles que o
# botão "Restaurar padrão" volta. Sem esta cópia, resetar exigiria reiniciar o jogo.
static var _defaults: Dictionary = {}


## Aplica os remapeamentos salvos ao InputMap. Idempotente: pode ser chamada de novo a qualquer
## momento (o padrão é sempre restaurado antes de aplicar o override).
static func apply_saved() -> void:
	_capture_defaults()
	for entry in ACTIONS:
		var action := String(entry["action"])
		var saved: Variant = Settings.config_file.get_value(SECTION, action, {})
		var event := data_to_event(saved)
		if event == null:
			_restore_default(action)
		else:
			_assign(action, event)


## Troca a tecla/botão de uma ação e persiste. `event` deve ser tecla ou botão do mouse.
static func set_binding(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action) or not is_supported(event):
		return
	_capture_defaults()
	_assign(action, event)
	Settings.config_file.set_value(SECTION, action, event_to_data(event))
	Settings.save_settings()


## Devolve a ação ao padrão de fábrica e apaga o override do arquivo.
static func reset_binding(action: String) -> void:
	_capture_defaults()
	_restore_default(action)
	if Settings.config_file.has_section_key(SECTION, action):
		Settings.config_file.erase_section_key(SECTION, action)
	Settings.save_settings()


## Devolve TODAS as ações ao padrão (usado pelo Reset geral das configurações).
static func reset_all() -> void:
	_capture_defaults()
	for entry in ACTIONS:
		var action := String(entry["action"])
		_restore_default(action)
		if Settings.config_file.has_section_key(SECTION, action):
			Settings.config_file.erase_section_key(SECTION, action)
	Settings.save_settings()


## Só tecla e botão do mouse são aceitos — é o que a demanda pede, e um eixo de mouse/joystick não
## tem representação estável nesta tela.
static func is_supported(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton


## Evento atualmente ligado à ação (o 1º tecla/botão encontrado), ou null.
static func current_event(action: String) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for e in InputMap.action_get_events(action):
		if is_supported(e):
			return e
	return null


## Ação DIFERENTE que já usa este evento (para avisar o jogador do conflito), ou "".
static func conflicting_action(action: String, event: InputEvent) -> String:
	for entry in ACTIONS:
		var other := String(entry["action"])
		if other == action:
			continue
		var e := current_event(other)
		if e != null and same_event(e, event):
			return other
	return ""


## Texto legível de um evento, para o botão da tela ("W", "Espaço", "Botão esquerdo do mouse").
static func label_for(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		# `physical_keycode` é o que o projeto usa nos binds do project.godot: a tecla pela POSIÇÃO,
		# independente do layout do teclado.
		var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		var name := OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code))
		return name if name != "" else OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return Locale.tr_key("Botão esquerdo do mouse")
			MOUSE_BUTTON_RIGHT: return Locale.tr_key("Botão direito do mouse")
			MOUSE_BUTTON_MIDDLE: return Locale.tr_key("Botão do meio do mouse")
			MOUSE_BUTTON_WHEEL_UP: return Locale.tr_key("Roda do mouse para cima")
			MOUSE_BUTTON_WHEEL_DOWN: return Locale.tr_key("Roda do mouse para baixo")
			_: return "%s %d" % [Locale.tr_key("Botão do mouse"), (event as InputEventMouseButton).button_index]
	return Locale.tr_key("Não definido")


# ───────────────────────────── interno ─────────────────────────────

# Guarda os eventos de fábrica na 1ª chamada. Roda antes de qualquer override ser aplicado, então o
# que está no InputMap nesse momento é exatamente o que veio do project.godot.
static func _capture_defaults() -> void:
	if not _defaults.is_empty():
		return
	for entry in ACTIONS:
		var action := String(entry["action"])
		if InputMap.has_action(action):
			_defaults[action] = InputMap.action_get_events(action).duplicate()


# Substitui os eventos de tecla/botão da ação pelo escolhido, PRESERVANDO os demais (eixos de
# joystick, por exemplo) — remapear o teclado não pode desligar um controle já configurado.
static func _assign(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if is_supported(e):
			InputMap.action_erase_event(action, e)
	InputMap.action_add_event(action, event)


static func _restore_default(action: String) -> void:
	if not (_defaults.has(action) and InputMap.has_action(action)):
		return
	InputMap.action_erase_events(action)
	for e in _defaults[action]:
		InputMap.action_add_event(action, e)


## Formato persistido: dicionário simples e legível no .ini, sem serializar o objeto de evento (que
## mudaria de forma entre versões da engine). Público: o AnimationBindings grava no mesmo formato.
static func event_to_data(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		return {"type": "key", "code": int(key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)}
	return {"type": "mouse", "code": int((event as InputEventMouseButton).button_index)}


static func data_to_event(saved: Variant) -> InputEvent:
	if not (saved is Dictionary) or not (saved as Dictionary).has("code"):
		return null
	var data: Dictionary = saved
	if String(data.get("type", "key")) == "mouse":
		var mb := InputEventMouseButton.new()
		mb.button_index = int(data["code"]) as MouseButton
		mb.pressed = true
		return mb
	var key := InputEventKey.new()
	key.physical_keycode = int(data["code"]) as Key
	key.pressed = true
	return key


static func same_event(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return (a as InputEventKey).physical_keycode == (b as InputEventKey).physical_keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false
