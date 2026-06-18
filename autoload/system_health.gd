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
var _rows: Dictionary = {}          # key -> Label (the value label of each metric row)
var _alert_label: Label = null
var _autopause_check: CheckButton = null
var _paused_label: Label = null
var _resume_button: Button = null

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
	call_deferred("_build_ui")
	var timer := Timer.new()
	timer.name = "PollTimer"
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.wait_time = POLL_INTERVAL
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_poll)
	Locale.language_changed.connect(_on_language_changed)
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

	# Title bar doubles as the drag handle for the floating window.
	_title_label = _make_label("⠿  " + Locale.tr_key("Saúde do Sistema"), 18, Color(0.51, 0.92, 1.0))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_label.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_title_label.tooltip_text = Locale.tr_key("Arraste para mover")
	_title_label.gui_input.connect(_on_title_gui_input)
	vbox.add_child(_title_label)

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

	# Park the window at the top-right once it has a measured size.
	await get_tree().process_frame
	if is_instance_valid(_panel):
		var vp := get_viewport().get_visible_rect().size
		_panel.position = Vector2(maxf(12.0, vp.x - _panel.size.x - 12.0), 12.0)
	_poll()


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
		var vp := get_viewport().get_visible_rect().size
		var pos := get_viewport().get_mouse_position() + _drag_offset
		pos.x = clampf(pos.x, 0.0, maxf(0.0, vp.x - _panel.size.x))
		pos.y = clampf(pos.y, 0.0, maxf(0.0, vp.y - _panel.size.y))
		_panel.position = pos
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false


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

	# Physical RAM (cross-platform). used% = (physical - available) / physical.
	var mem_info: Dictionary = OS.get_memory_info()
	var physical: float = float(mem_info.get("physical", 0))
	var available: float = float(mem_info.get("available", 0))
	var sys_pct := 0.0
	if physical > 0.0:
		sys_pct = clampf((physical - available) / physical * 100.0, 0.0, 100.0)

	var cpu_over := cpu_pct >= 0.0 and cpu_pct >= THRESHOLD
	_set_row("fps", "%d" % fps, false)
	_set_row("cpu", ("%d%%" % int(round(cpu_pct))) if cpu_pct >= 0.0 else Locale.tr_key("N/D"), cpu_over)
	_set_row("game_mem", _format_bytes(game_mem), false)
	_set_row("video_mem", _format_bytes(video_mem), false)
	if physical > 0.0:
		_set_row("sys_mem", "%s  (%d%%)" % [_format_bytes(physical - available), int(round(sys_pct))], sys_pct >= THRESHOLD)
	else:
		_set_row("sys_mem", Locale.tr_key("N/D"), false)

	_update_alert(sys_pct, cpu_pct, cpu_over)


func _set_row(key: String, value: String, over: bool) -> void:
	var lbl: Label = _rows.get(key)
	if lbl == null:
		return
	lbl.text = value
	lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35) if over else Color(0.85, 1.0, 0.85))


# Decide the alert/pause state. RAM over the limit is critical immediately; CPU must stay
# over the limit for SPIKE_GRACE seconds (short spikes are tolerated) before it counts.
func _update_alert(sys_pct: float, _cpu_pct_now: float, cpu_over: bool) -> void:
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

	if any_over:
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
	_paused_label.text = Locale.tr_key("Processamento pausado para proteger o sistema.")
	_paused_label.visible = true
	_resume_button.visible = true


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


func _on_language_changed(_lang: String) -> void:
	if not is_instance_valid(_panel):
		return
	_title_label.text = "⠿  " + Locale.tr_key("Saúde do Sistema")
	_title_label.tooltip_text = Locale.tr_key("Arraste para mover")
	_autopause_check.text = Locale.tr_key("Pausar ao atingir o limite")
	_resume_button.text = Locale.tr_key("Retomar")
	# Re-caption each metric row's left label from its stored key.
	for child in _panel.find_children("*", "Label", true, false):
		if child.has_meta("loc_key"):
			(child as Label).text = Locale.tr_key(child.get_meta("loc_key"))
	_poll()
