extends Node
## StabilityGuard — autoload de proteção contra crash/freeze (substitui o antigo SystemHealth).
##
## Monitora 5 indicadores de risco real e aplica 3 níveis:
##   NORMAL    → tudo OK
##   THROTTLE  → reduz a física (ticks/s) + emite sinal de aviso
##   EMERGENCY → pausa a árvore + overlay de emergência (tela cheia, dispensável com ESC)
##
## Indicadores monitorados (via singleton Performance — internos da engine, confiáveis):
##   • RAM estática    (MEMORY_STATIC)            esgotamento → OOM killer do SO
##   • VRAM            (RENDER_VIDEO_MEM_USED)    esgotamento → crash de driver GPU
##   • Collision Pairs (PHYSICS_3D_COLLISION_PAIRS) explosão → freeze do thread de física
##   • Node Count      (OBJECT_NODE_COUNT)        vazamento → RAM cresce sem parar
##   • FPS             (TIME_FPS)                 < limite por N frames → loop principal preso
##
## É sempre-ligado (rede de segurança). O PerformanceHUD lê o estado via os sinais abaixo e
## mostra um badge. Textos do overlay são localizados via Locale (dicionários em
## res://scenes2D/overlays/Resources). Registrado como autoload "StabilityGuard".

enum State { NORMAL, THROTTLE, EMERGENCY }

signal state_changed(new_state: int, reason: String)
signal throttle_activated(reason: String)
signal emergency_activated(reason: String)
signal recovered()

@export var ram_warn_mb:        float = 512.0
@export var ram_crit_mb:        float = 800.0
@export var vram_warn_mb:       float = 512.0
@export var vram_crit_mb:       float = 800.0
@export var col_pairs_warn:     float = 300.0
@export var col_pairs_crit:     float = 600.0
@export var node_warn:          float = 3000.0
@export var node_crit:          float = 6000.0
@export var fps_crit:           float = 5.0
@export var fps_crit_frames:    int   = 10
@export var physics_normal_tps:   int = 60
@export var physics_throttle_tps: int = 30
@export var check_interval: float = 0.5

var current_state: State = State.NORMAL
var last_reason:   String = ""

var _timer:          float = 0.0
var _low_fps_frames: int   = 0
var _node_baseline:  float = -1.0
var _overlay:        CanvasLayer

# Static overlay labels kept so they can be re-translated on a language change.
var _lbl_title: Label = null
var _lbl_hint:  Label = null
var _btn_dismiss: Button = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	Locale.language_changed.connect(_on_language_changed)


func _process(delta: float) -> void:
	_timer += delta
	if _timer < check_interval:
		return
	_timer = 0.0
	_evaluate()


func _evaluate() -> void:
	var ram_mb:    float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1_048_576.0
	var vram_mb:   float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1_048_576.0
	var col_pairs: float = Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)
	var nodes:     float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var fps:       float = Performance.get_monitor(Performance.TIME_FPS)

	if _node_baseline < 0.0:
		_node_baseline = nodes

	if fps <= fps_crit:
		_low_fps_frames += 1
	else:
		_low_fps_frames = 0

	var worst: State = State.NORMAL
	var reason: String = ""

	if ram_mb >= ram_crit_mb:
		worst = State.EMERGENCY
		reason = _reason("RAM crítica: %.0f MB (limite: %.0f MB)", [ram_mb, ram_crit_mb])
	elif vram_mb >= vram_crit_mb:
		worst = State.EMERGENCY
		reason = _reason("VRAM crítica: %.0f MB (limite: %.0f MB)", [vram_mb, vram_crit_mb])
	elif col_pairs >= col_pairs_crit:
		worst = State.EMERGENCY
		reason = _reason("Collision Pairs crítico: %.0f (limite: %.0f)", [col_pairs, col_pairs_crit])
	elif nodes >= node_crit:
		worst = State.EMERGENCY
		reason = _reason("Node count crítico: %.0f (limite: %.0f)", [nodes, node_crit])
	elif _low_fps_frames >= fps_crit_frames:
		worst = State.EMERGENCY
		reason = _reason("FPS ≤ %.0f por %d frames consecutivos (loop principal bloqueado)", [fps_crit, fps_crit_frames])

	if worst == State.NORMAL:
		if ram_mb >= ram_warn_mb:
			worst = State.THROTTLE
			reason = _reason("RAM elevada: %.0f MB", [ram_mb])
		elif vram_mb >= vram_warn_mb:
			worst = State.THROTTLE
			reason = _reason("VRAM elevada: %.0f MB", [vram_mb])
		elif col_pairs >= col_pairs_warn:
			worst = State.THROTTLE
			reason = _reason("Collision Pairs elevado: %.0f", [col_pairs])
		elif nodes >= node_warn:
			worst = State.THROTTLE
			reason = _reason("Node count elevado: %.0f", [nodes])

	if worst != current_state:
		_transition_to(worst, reason)


# Format a localized reason: the template KEY is translated by Locale (keeping its %-specs),
# then the values are substituted. Unknown keys pass through unchanged (PT source).
func _reason(template: String, values: Array) -> String:
	return Locale.tr_key(template) % values


func _transition_to(new_state: State, reason: String) -> void:
	var prev: State = current_state
	current_state = new_state
	last_reason   = reason

	match new_state:
		State.NORMAL:    _apply_normal()
		State.THROTTLE:  _apply_throttle(reason)
		State.EMERGENCY: _apply_emergency(reason)

	state_changed.emit(new_state, reason)

	if prev != State.NORMAL and new_state == State.NORMAL:
		recovered.emit()


func _apply_normal() -> void:
	Engine.physics_ticks_per_second = physics_normal_tps
	get_tree().paused = false
	_overlay.visible  = false


func _apply_throttle(reason: String) -> void:
	Engine.physics_ticks_per_second = physics_throttle_tps
	_overlay.visible = false
	throttle_activated.emit(reason)
	push_warning("[StabilityGuard] THROTTLE: " + reason)


func _apply_emergency(reason: String) -> void:
	Engine.physics_ticks_per_second = physics_throttle_tps
	get_tree().paused = true
	_show_overlay(reason)
	emergency_activated.emit(reason)
	push_error("[StabilityGuard] EMERGENCY: " + reason)


func state_name() -> String:
	match current_state:
		State.THROTTLE:  return "THROTTLE"
		State.EMERGENCY: return "EMERGENCY"
		_:               return "NORMAL"


func state_color() -> Color:
	match current_state:
		State.THROTTLE:  return Color(1.0, 0.85, 0.1)
		State.EMERGENCY: return Color(1.0, 0.25, 0.25)
		_:               return Color(0.2, 1.0, 0.4)


func dismiss_emergency() -> void:
	if current_state == State.EMERGENCY:
		get_tree().paused = false
		_overlay.visible  = false


func force_check() -> void:
	_timer = check_interval
	_evaluate()


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 128
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.visible = false
	add_child(_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.0, 0.0, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.process_mode = Node.PROCESS_MODE_ALWAYS
	center.add_child(vbox)

	var lbl_icon := Label.new()
	lbl_icon.text = "⚠"
	lbl_icon.add_theme_font_size_override("font_size", 64)
	lbl_icon.add_theme_color_override("font_color", Color(1.0, 0.3, 0.1))
	lbl_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_icon.process_mode = Node.PROCESS_MODE_ALWAYS
	lbl_icon.add_to_group(Locale.SKIP_GROUP)
	vbox.add_child(lbl_icon)

	_lbl_title = Label.new()
	_lbl_title.text = Locale.tr_key("PROTEÇÃO CONTRA CRASH ATIVADA")
	_lbl_title.add_theme_font_size_override("font_size", 22)
	_lbl_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	_lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_title.process_mode = Node.PROCESS_MODE_ALWAYS
	_lbl_title.add_to_group(Locale.SKIP_GROUP)
	vbox.add_child(_lbl_title)

	var lbl_reason := Label.new()
	lbl_reason.name = "LblReason"
	lbl_reason.text = ""
	lbl_reason.add_theme_font_size_override("font_size", 15)
	lbl_reason.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	lbl_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_reason.custom_minimum_size = Vector2(500, 0)
	lbl_reason.process_mode = Node.PROCESS_MODE_ALWAYS
	lbl_reason.add_to_group(Locale.SKIP_GROUP)
	vbox.add_child(lbl_reason)

	_lbl_hint = Label.new()
	_lbl_hint.text = Locale.tr_key("O jogo foi pausado automaticamente para proteger o sistema.\nAguarde a recuperação de recursos ou pressione ESC para continuar.")
	_lbl_hint.add_theme_font_size_override("font_size", 13)
	_lbl_hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_hint.custom_minimum_size = Vector2(500, 0)
	_lbl_hint.process_mode = Node.PROCESS_MODE_ALWAYS
	_lbl_hint.add_to_group(Locale.SKIP_GROUP)
	vbox.add_child(_lbl_hint)

	_btn_dismiss = Button.new()
	_btn_dismiss.text = Locale.tr_key("Continuar mesmo assim  [ESC]")
	_btn_dismiss.custom_minimum_size = Vector2(300, 44)
	_btn_dismiss.process_mode = Node.PROCESS_MODE_ALWAYS
	_btn_dismiss.add_to_group(Locale.SKIP_GROUP)
	_btn_dismiss.pressed.connect(dismiss_emergency)
	vbox.add_child(_btn_dismiss)


func _show_overlay(reason: String) -> void:
	var lbl: Label = _overlay.find_child("LblReason", true, false) as Label
	if lbl:
		lbl.text = reason
	_overlay.visible = true


func _on_language_changed(_lang: String) -> void:
	if is_instance_valid(_lbl_title):
		_lbl_title.text = Locale.tr_key("PROTEÇÃO CONTRA CRASH ATIVADA")
	if is_instance_valid(_lbl_hint):
		_lbl_hint.text = Locale.tr_key("O jogo foi pausado automaticamente para proteger o sistema.\nAguarde a recuperação de recursos ou pressione ESC para continuar.")
	if is_instance_valid(_btn_dismiss):
		_btn_dismiss.text = Locale.tr_key("Continuar mesmo assim  [ESC]")


func _input(event: InputEvent) -> void:
	if current_state == State.EMERGENCY and event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			dismiss_emergency()
