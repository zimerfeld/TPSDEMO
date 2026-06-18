extends Node

## "Saúde do Sistema" (System Health) monitor — a developer overlay that watches the
## game's and the machine's resource usage and, as a safety net, can PAUSE processing
## before a monitored resource saturates (which on a low-spec machine can freeze or crash
## the OS). Toggled from the Developer screen (game/system_health).
##
## Metrics:
##  - FPS / Mem. Jogo (static) / Mem. Vídeo / Mem. Sistema (physical RAM) come straight
##    from Godot (Performance / OS.get_memory_info).
##  - CPU is the REAL per-process CPU usage of the Godot process, sampled from the OS on a
##    background thread (PowerShell `Get-Process` on Windows), so it tracks what the OS
##    Task Manager shows for this process. It reads "N/D" until the first delta is ready,
##    or on non-Windows platforms.
##
## The panel is a draggable floating window (grab the title bar with the left mouse button)
## and keeps running while the tree is paused (PROCESS_MODE_ALWAYS) so the user can resume.

# Percentage at which a monitored resource is considered unsafe (the brief: never let any
# resource reach 90%). Alerting and the optional auto-pause trigger at this level.
const THRESHOLD: float = 90.0
# Critical level: above this, any single indicator is treated as a "spike". A run of more
# than SPIKES_TO_SHOW consecutive one-second spikes force-reveals the panel and HARD-pauses
# the game (so the machine can never run on to a freeze — the brief's overriding rule).
const SPIKE_THRESHOLD: float = 95.0
# Each sustained second over SPIKE_THRESHOLD counts as one spike and emits one alert beep.
const SPIKE_DURATION: float = 1.0
# Reveal + hard-pause once there have been MORE THAN this many consecutive one-second spikes.
const SPIKES_TO_SHOW: int = 3
# How often the panel refreshes its readout, in seconds.
const POLL_INTERVAL: float = 0.6
# CPU may legitimately spike above the threshold for a moment; only count it toward the
# safety pause once it has stayed over the limit continuously for this long (seconds).
# System RAM is not subject to this grace (it doesn't spike-and-recover like CPU).
const SPIKE_GRACE: float = 4.0
# How often the background thread samples the OS for the process CPU usage (seconds).
const CPU_SAMPLE_INTERVAL: float = 1.0

var _canvas: CanvasLayer = null
var _panel: PanelContainer = null
var _title_label: Label = null
var _close_button: Button = null
var _rows: Dictionary = {}          # key -> Label (the value label of each metric row)
var _alert_label: Label = null
var _autopause_check: CheckButton = null
var _paused_label: Label = null
var _resume_button: Button = null

# Alert beep, played once per one-second critical spike. A short sine tone generated at
# startup (no asset to ship); routed through the SFX bus and PROCESS_MODE_ALWAYS so it is
# audible even while the safety pause holds the tree.
var _beep_player: AudioStreamPlayer = null

# Critical-spike state: when the current continuous over-95% run began (< 0 = under), and how
# many one-second spikes have been counted (and beeped) within it.
var _spike_start: float = -1.0
var _spikes_counted: int = 0

# Auto-pause latch: once we auto-pause (or the user resumes), don't re-pause until usage
# has dropped back under the threshold, so resuming isn't undone on the very next frame.
var _suppress_autopause: bool = false
var _auto_paused: bool = false
# Timestamp (sec) since CPU has been continuously over the threshold; < 0 when under.
var _cpu_over_since: float = -1.0

# Floating-window drag state (grab the title bar).
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

# --- Background OS sampler (real process CPU%) ------------------------------
var _hw_thread: Thread = null
var _hw_run: bool = false
var _hw_mutex: Mutex = Mutex.new()
var _cpu_pct: float = -1.0           # shared, written by the worker; < 0 = N/D


func _ready() -> void:
	# Keep monitoring (and let the user resume) even while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_beep_player()
	call_deferred("_build_ui")
	var timer := Timer.new()
	timer.name = "PollTimer"
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.wait_time = POLL_INTERVAL
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_poll)
	Locale.language_changed.connect(_on_language_changed)
	# On a settings "Reset", snap the panel back to the top-right corner.
	if Settings.has_signal("settings_reset"):
		Settings.settings_reset.connect(_on_settings_reset)
	# Real per-process CPU% needs an OS query; sample it off the main thread.
	if OS.get_name() == "Windows":
		_hw_run = true
		_hw_thread = Thread.new()
		_hw_thread.start(_cpu_worker)


func _exit_tree() -> void:
	_hw_run = false
	if _hw_thread != null and _hw_thread.is_started():
		_hw_thread.wait_to_finish()
		_hw_thread = null


func _is_on() -> bool:
	return Settings.config_file.get_value("game", "system_health", false)


func _autopause_enabled() -> bool:
	return Settings.config_file.get_value("game", "system_health_autopause", true)


# Show/hide the overlay to match the saved setting (called by the Developer toggle).
func refresh() -> void:
	if not is_instance_valid(_canvas):
		return
	_canvas.visible = _is_on()
	if not _is_on():
		# Turning the monitor off must never leave the game stuck paused.
		_clear_pause()
	else:
		_poll()


# --- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "SystemHealthCanvas"
	_canvas.layer = 99
	_canvas.visible = _is_on()
	add_child(_canvas)

	_panel = PanelContainer.new()
	# Free-floating: top-left anchored so we can move it by setting `position`.
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(12, 12)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.07, 0.9)
	style.border_color = Color(0.27, 0.86, 1.0, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10.0)
	_panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	# Header bar: a panel holding ONE row — the title text (left) and a Windows-style red close
	# button (right). ONLY the title text moves the window (its gui_input drives the drag); the
	# close button is a separate control, so its area can never start a drag.
	var header := PanelContainer.new()
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.07, 0.10, 0.16, 0.9)
	header_style.set_corner_radius_all(4)
	header_style.set_content_margin_all(4.0)
	header.add_theme_stylebox_override("panel", header_style)
	vbox.add_child(header)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	header.add_child(header_row)

	# Title text — the ONLY drag handle for the floating window.
	_title_label = _make_label("⠿  " + Locale.tr_key("Saúde do Sistema"), 18, Color(0.51, 0.92, 1.0))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_label.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_title_label.tooltip_text = Locale.tr_key("Arraste para mover")
	_title_label.gui_input.connect(_on_title_gui_input)
	header_row.add_child(_title_label)

	# Red close button (top-right). Its area is NOT a drag handle.
	_close_button = _make_close_button()
	header_row.add_child(_close_button)

	# One row per metric: a fixed-name label on the left, the live value on the right.
	for entry in _METRIC_KEYS:
		vbox.add_child(_make_row(entry))

	_alert_label = _make_label("", 15, Color(1.0, 0.35, 0.35))
	_alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_alert_label.custom_minimum_size = Vector2(316, 0)
	vbox.add_child(_alert_label)

	_autopause_check = CheckButton.new()
	_autopause_check.text = Locale.tr_key("Pausar ao atingir o limite")
	_autopause_check.add_theme_font_size_override("font_size", 14)
	_autopause_check.button_pressed = _autopause_enabled()
	_autopause_check.add_to_group(Locale.SKIP_GROUP)
	_autopause_check.toggled.connect(_on_autopause_toggled)
	vbox.add_child(_autopause_check)

	_paused_label = _make_label("", 14, Color(1.0, 0.78, 0.2))
	_paused_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_paused_label.custom_minimum_size = Vector2(316, 0)
	_paused_label.visible = false
	vbox.add_child(_paused_label)

	_resume_button = Button.new()
	_resume_button.text = Locale.tr_key("Retomar")
	_resume_button.add_to_group(Locale.SKIP_GROUP)
	_resume_button.visible = false
	_resume_button.pressed.connect(_on_resume_pressed)
	vbox.add_child(_resume_button)

	# Restore the saved position once the panel has a measured size (clamped to the
	# screen); falls back to the top-right corner when there is none.
	await get_tree().process_frame
	if is_instance_valid(_panel):
		_apply_saved_position()
	_poll()


# Screen margin and config key for the floating panel's persisted position.
const _MARGIN: float = 12.0
const _POS_KEY: String = "system_health_pos"


# Clamp a desired position so the whole panel stays within the viewport.
func _clamp_to_screen(pos: Vector2) -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, 0.0, maxf(0.0, vp.x - _panel.size.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, vp.y - _panel.size.y))
	return pos


func _move_to_top_right() -> void:
	var vp := get_viewport().get_visible_rect().size
	_panel.position = Vector2(maxf(_MARGIN, vp.x - _panel.size.x - _MARGIN), _MARGIN)


# Place the panel at its saved position (clamped on-screen), or top-right if unset.
func _apply_saved_position() -> void:
	var saved: Vector2 = Settings.config_file.get_value("game", _POS_KEY, Vector2(-1, -1))
	if saved.x < 0.0 or saved.y < 0.0:
		_move_to_top_right()
	else:
		_panel.position = _clamp_to_screen(saved)


func _save_position() -> void:
	Settings.config_file.set_value("game", _POS_KEY, _panel.position)
	Settings.save_settings()


func _on_settings_reset() -> void:
	# reset_to_defaults already cleared the saved position; snap back to the corner.
	if is_instance_valid(_panel):
		_move_to_top_right()


# Metric rows, top to bottom. label_key is the (translatable) caption shown on the left.
const _METRIC_KEYS: Array[Dictionary] = [
	{"key": "fps", "label": "FPS"},
	{"key": "cpu", "label": "CPU"},
	{"key": "game_mem", "label": "Mem. Jogo"},
	{"key": "video_mem", "label": "Mem. Vídeo"},
	{"key": "sys_mem", "label": "Mem. Sistema"},
]


func _make_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := _make_label(Locale.tr_key(entry["label"]), 14, Color(0.78, 0.86, 0.94))
	name_label.custom_minimum_size = Vector2(150, 0)
	name_label.set_meta("loc_key", entry["label"])
	row.add_child(name_label)
	var value_label := _make_label("—", 14, Color(0.85, 1.0, 0.85))
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	_rows[entry["key"]] = value_label
	return row


func _make_label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The panel owns these labels' text; keep the auto-localizer off them.
	lbl.add_to_group(Locale.SKIP_GROUP)
	return lbl


# Windows-style red close button shown at the top-right of the title bar.
func _make_close_button() -> Button:
	var btn := Button.new()
	btn.text = "✕"
	btn.add_theme_font_size_override("font_size", 14)
	btn.custom_minimum_size = Vector2(28, 24)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = Locale.tr_key("Fechar")
	# Its text ("✕") is fixed, so keep the auto-localizer off it.
	btn.add_to_group(Locale.SKIP_GROUP)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.78, 0.12, 0.12)
	normal.set_corner_radius_all(3)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.95, 0.20, 0.20)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.58, 0.07, 0.07)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	btn.pressed.connect(_on_close_pressed)
	return btn


# Close (hide) the floating window — like a Windows window's red X. Monitoring KEEPS running
# (the developer setting stays on), so the safety pause and the critical auto-show still guard
# the machine: a critical spike re-reveals the panel. Toggling the Developer switch reopens it.
func _on_close_pressed() -> void:
	if is_instance_valid(_canvas):
		_canvas.visible = false


# Build the alert beep once: a short, click-free sine tone synthesized into a 16-bit WAV (no
# audio asset needed). Routed to the SFX bus, and PROCESS_MODE_ALWAYS so it sounds even while
# the safety pause holds the tree.
func _make_beep_player() -> void:
	_beep_player = AudioStreamPlayer.new()
	_beep_player.name = "AlertBeep"
	_beep_player.bus = "SFX"
	_beep_player.process_mode = Node.PROCESS_MODE_ALWAYS
	var rate := 22050
	var dur := 0.18
	var freq := 920.0
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		# Short attack/decay envelope so the tone starts and ends without a click.
		var env := clampf(minf(t / 0.01, (dur - t) / 0.03), 0.0, 1.0)
		var s := sin(TAU * freq * t) * env * 0.6
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	_beep_player.stream = wav
	add_child(_beep_player)


func _play_beep() -> void:
	if is_instance_valid(_beep_player):
		_beep_player.play()


# --- Floating-window dragging (grab the title bar) --------------------------

func _on_title_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_drag_offset = _panel.position - get_viewport().get_mouse_position()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		_panel.position = _clamp_to_screen(get_viewport().get_mouse_position() + _drag_offset)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
		# Persist the dropped position so the panel reopens where the user left it.
		_save_position()


# --- Polling ----------------------------------------------------------------

func _poll() -> void:
	if not is_instance_valid(_panel) or not _is_on():
		return

	var fps := Engine.get_frames_per_second()

	_hw_mutex.lock()
	var cpu_pct: float = _cpu_pct
	_hw_mutex.unlock()

	var game_mem: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var video_mem: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)

	# Physical RAM in use, like Task Manager: used = total - FREE physical. (Note: the
	# dict's "available" is the process' available VIRTUAL/commit space — tens of GB, larger
	# than physical RAM — so it must NOT be used here; that bug showed a negative value.)
	var mem_info: Dictionary = OS.get_memory_info()
	var physical: float = float(mem_info.get("physical", 0))
	var free: float = float(mem_info.get("free", -1))
	var sys_ok := physical > 0.0 and free >= 0.0
	var used := physical - free
	var sys_pct := 0.0
	if sys_ok:
		sys_pct = clampf(used / physical * 100.0, 0.0, 100.0)

	var cpu_over := cpu_pct >= 0.0 and cpu_pct >= THRESHOLD
	_set_row("fps", "%d" % fps, false)
	_set_row("cpu", ("%d%%" % int(round(cpu_pct))) if cpu_pct >= 0.0 else Locale.tr_key("N/D"), cpu_over)
	# Mem. Jogo / Mem. Vídeo seguem o mesmo padrão de Mem. Sistema: "usado / total (%)", com a
	# RAM física como total comum (mesma referência usada por sys_mem), para comparar os pesos.
	_set_row("game_mem", _format_mem_ratio(game_mem, physical, sys_ok), _mem_over(game_mem, physical, sys_ok))
	_set_row("video_mem", _format_mem_ratio(video_mem, physical, sys_ok), _mem_over(video_mem, physical, sys_ok))
	if sys_ok:
		_set_row("sys_mem", "%s / %s  (%d%%)" % [_format_bytes(used), _format_bytes(physical), int(round(sys_pct))], sys_pct >= THRESHOLD)
	else:
		_set_row("sys_mem", Locale.tr_key("N/D"), false)

	# Keep the panel on-screen even if the window/resolution changed since the last drag.
	_panel.position = _clamp_to_screen(_panel.position)

	# Highest usage across ALL percentage indicators (CPU + the three memories), for the
	# critical-spike rule ("any indicator over 95%").
	var max_pct := cpu_pct
	max_pct = maxf(max_pct, _pct(game_mem, physical, sys_ok))
	max_pct = maxf(max_pct, _pct(video_mem, physical, sys_ok))
	if sys_ok:
		max_pct = maxf(max_pct, sys_pct)

	_update_alert(sys_pct, cpu_pct, cpu_over, max_pct)


func _set_row(key: String, value: String, over: bool) -> void:
	var lbl: Label = _rows.get(key)
	if lbl == null:
		return
	lbl.text = value
	lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35) if over else Color(0.85, 1.0, 0.85))


# Decide the alert/pause state. RAM over the limit is critical immediately; CPU must stay
# over the limit for SPIKE_GRACE seconds (short spikes are tolerated) before it counts. On top
# of that, the CRITICAL (>95%) spike rule beeps once per sustained second and, after more than
# SPIKES_TO_SHOW spikes, force-reveals the panel and hard-pauses the game.
func _update_alert(sys_pct: float, _cpu_pct_now: float, cpu_over: bool, max_pct: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if cpu_over:
		if _cpu_over_since < 0.0:
			_cpu_over_since = now
	else:
		_cpu_over_since = -1.0
	var cpu_sustained := _cpu_over_since >= 0.0 and (now - _cpu_over_since) >= SPIKE_GRACE

	var ram_over := sys_pct >= THRESHOLD
	var any_over := ram_over or cpu_over          # for the (immediate) red alert line
	var pause_needed := ram_over or cpu_sustained # CPU only counts once sustained

	# Critical spikes: while ANY indicator stays over SPIKE_THRESHOLD, count one spike per full
	# second and beep on each. The first beep fires the instant it crosses 95% (spike 1), then
	# one per second; dropping back under 95% resets the run.
	var critical := max_pct >= SPIKE_THRESHOLD
	if critical:
		if _spike_start < 0.0:
			_spike_start = now
			_spikes_counted = 0
		var due := int(floor((now - _spike_start) / SPIKE_DURATION)) + 1
		while _spikes_counted < due:
			_spikes_counted += 1
			_play_beep()
			# More than SPIKES_TO_SHOW consecutive spikes: surface the window and pause.
			if _spikes_counted > SPIKES_TO_SHOW:
				_engage_critical_safety()
	else:
		_spike_start = -1.0
		_spikes_counted = 0

	if critical:
		_alert_label.text = Locale.tr_key("ALERTA CRÍTICO: uso acima de 95%!")
		_alert_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	elif any_over:
		_alert_label.text = Locale.tr_key("ALERTA: uso de recurso acima do limite seguro!")
		_alert_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	else:
		_alert_label.text = Locale.tr_key("Recursos dentro do limite seguro.")
		_alert_label.add_theme_color_override("font_color", Color(0.5, 0.85, 0.55))
		# Usage is safe again: drop the resume latch so auto-pause can re-arm.
		_suppress_autopause = false

	if pause_needed and _autopause_enabled() and not _suppress_autopause and not _auto_paused:
		_engage_pause()


# --- Safety pause -----------------------------------------------------------

func _engage_pause() -> void:
	_auto_paused = true
	get_tree().paused = true
	# Make sure the user actually sees the pause even if they had closed the window.
	if _is_on() and is_instance_valid(_canvas):
		_canvas.visible = true
	_paused_label.text = Locale.tr_key("Processamento pausado para proteger o sistema.")
	_paused_label.visible = true
	_resume_button.visible = true


# Hard safety for the critical (>95%, >3 one-second spikes) case: the machine must NEVER be
# allowed to run on to a freeze. Reveal the panel (even if the user closed it) and pause the
# game NO MATTER WHAT — ignoring both the "Pausar ao atingir o limite" checkbox and the resume
# latch. Pausing drops the game's own load, so CPU spikes clear and the user can then resume;
# a still-critical resource (e.g. RAM near full) simply stays paused, which is the safe outcome.
func _engage_critical_safety() -> void:
	if _is_on() and is_instance_valid(_canvas):
		_canvas.visible = true
	if not _auto_paused:
		_engage_pause()


func _on_resume_pressed() -> void:
	# Resume and latch auto-pause off until usage falls back under the threshold, so we
	# don't immediately re-pause on the next sample.
	_suppress_autopause = true
	_clear_pause()


func _clear_pause() -> void:
	if _auto_paused:
		get_tree().paused = false
	_auto_paused = false
	if is_instance_valid(_paused_label):
		_paused_label.visible = false
	if is_instance_valid(_resume_button):
		_resume_button.visible = false


func _on_autopause_toggled(pressed: bool) -> void:
	Settings.config_file.set_value("game", "system_health_autopause", pressed)
	Settings.save_settings()
	if not pressed:
		_clear_pause()


# --- Background CPU sampler (Windows) ---------------------------------------

# Worker thread: repeatedly read the Godot process' cumulative CPU time from the OS and
# turn successive readings into a real per-process CPU% (matching Task Manager). Runs only
# while the monitor is on; idles cheaply otherwise. Windows-only (PowerShell Get-Process).
func _cpu_worker() -> void:
	var pid := OS.get_process_id()
	var prev_cpu_s := -1.0
	var prev_t := 0.0
	while _hw_run:
		if not _is_on():
			prev_cpu_s = -1.0
			_sleep_chunked(0.5)
			continue
		var sample := _query_process_cpu(pid)   # {cpu_s, cores} or empty
		var now := Time.get_ticks_msec() / 1000.0
		var cpu_s: float = float(sample.get("cpu_s", -1.0))
		var cores: float = maxf(float(sample.get("cores", 1.0)), 1.0)
		if not sample.is_empty() and cpu_s >= 0.0:
			if prev_cpu_s >= 0.0 and now > prev_t:
				var dt := now - prev_t
				var pct := (cpu_s - prev_cpu_s) / (dt * cores) * 100.0
				_hw_mutex.lock()
				_cpu_pct = clampf(pct, 0.0, 100.0)
				_hw_mutex.unlock()
			prev_cpu_s = cpu_s
			prev_t = now
		_sleep_chunked(CPU_SAMPLE_INTERVAL)


# Sleep in small chunks so a shutdown (_hw_run = false) is honored promptly.
func _sleep_chunked(seconds: float) -> void:
	var remaining := int(seconds * 1000.0)
	while remaining > 0 and _hw_run:
		var step := mini(remaining, 100)
		OS.delay_msec(step)
		remaining -= step


# Query the OS for the process' cumulative CPU seconds and the logical-core count via
# PowerShell (locale-independent: Get-Process.CPU and ProcessorCount carry no localized
# strings). Returns {} on failure.
func _query_process_cpu(pid: int) -> Dictionary:
	var script := (
		"$ErrorActionPreference='SilentlyContinue';" +
		"$p=Get-Process -Id %d;" % pid +
		"$c=if($p){$p.CPU}else{-1};" +
		"Write-Output ('{0};{1}' -f $c,[Environment]::ProcessorCount)"
	)
	var out: Array = []
	var code := OS.execute("powershell", ["-NoProfile", "-NonInteractive", "-Command", script], out, false, false)
	if code != 0 or out.is_empty():
		return {}
	var parts := String(out[0]).strip_edges().split(";")
	if parts.size() < 2:
		return {}
	var cpu_s := parts[0].to_float()
	var cores := parts[1].to_float()
	return {"cpu_s": cpu_s, "cores": cores}


# --- Localization -----------------------------------------------------------

func _format_bytes(bytes: float) -> String:
	var mb := bytes / (1024.0 * 1024.0)
	if mb >= 1024.0:
		return "%.2f GB" % (mb / 1024.0)
	return "%.0f MB" % mb


# Formata "usado / total (%)" no padrão de Mem. Sistema; cai para só o valor se o total for
# desconhecido (RAM física indisponível).
func _format_mem_ratio(used_bytes: float, total_bytes: float, total_ok: bool) -> String:
	if not total_ok or total_bytes <= 0.0:
		return _format_bytes(used_bytes)
	var pct := clampf(used_bytes / total_bytes * 100.0, 0.0, 100.0)
	return "%s / %s  (%d%%)" % [_format_bytes(used_bytes), _format_bytes(total_bytes), int(round(pct))]


# True quando o uso atinge o limite seguro (apenas para colorir a linha; não dispara pausa).
func _mem_over(used_bytes: float, total_bytes: float, total_ok: bool) -> bool:
	if not total_ok or total_bytes <= 0.0:
		return false
	return used_bytes / total_bytes * 100.0 >= THRESHOLD


# Percentual de uso (0..100) de um indicador de memória, ou -1 quando o total é desconhecido —
# usado para achar o maior indicador na regra de pico crítico (>95%).
func _pct(used_bytes: float, total_bytes: float, total_ok: bool) -> float:
	if not total_ok or total_bytes <= 0.0:
		return -1.0
	return clampf(used_bytes / total_bytes * 100.0, 0.0, 100.0)


func _on_language_changed(_lang: String) -> void:
	if not is_instance_valid(_panel):
		return
	_title_label.text = "⠿  " + Locale.tr_key("Saúde do Sistema")
	_title_label.tooltip_text = Locale.tr_key("Arraste para mover")
	if is_instance_valid(_close_button):
		_close_button.tooltip_text = Locale.tr_key("Fechar")
	_autopause_check.text = Locale.tr_key("Pausar ao atingir o limite")
	_resume_button.text = Locale.tr_key("Retomar")
	# Re-caption each metric row's left label from its stored key.
	for child in _panel.find_children("*", "Label", true, false):
		if child.has_meta("loc_key"):
			(child as Label).text = Locale.tr_key(child.get_meta("loc_key"))
	_poll()
