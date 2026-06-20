extends Control
## Barra de indicadores de performance (conteúdo do PerformanceHUD). É montada por
## autoload/performance_hud.gd dentro de um CanvasLayer global; não use direto em cena.
##
## Modo básico : FPS | NET | RAM | CPU% | GPU% | badge do StabilityGuard
## Modo avançado: painéis por categoria (CPU / GPU / Memória) com toggle
##
## Todos os valores vêm do singleton Performance (confiável, multiplataforma). NET depende
## de um NetworkManager opcional com get_total_bps(); como o ZIMARO não tem um, o indicador
## degrada para "N/D" automaticamente. Textos fixos são localizados via Locale (todos no
## grupo SKIP_GROUP — o script é dono deles e os re-traduz em language_changed).

const UPDATE_INTERVAL  := 0.25
const HEIGHT_BASIC     := 32
const HEIGHT_ADVANCED  := 130
const COLOR_OK         := Color(0.2, 1.0, 0.4)
const COLOR_WARN       := Color(1.0, 0.85, 0.1)
const COLOR_CRIT       := Color(1.0, 0.25, 0.25)
const COLOR_LABEL      := Color(0.55, 0.75, 1.0)
const COLOR_HEADER     := Color(0.8, 0.9, 1.0)

var _timer:        float = 0.0
var _advanced:     bool  = false

var _lbl_guard_state:  Label
var _lbl_guard_reason: Label

var _lbl_fps:  Label
var _lbl_net:  Label
var _lbl_ram:  Label
var _lbl_cpu:  Label
var _lbl_gpu:  Label
var _btn_toggle: Button
var _bar_bg: ColorRect
var _panel_advanced: Control

# CPU
var _lbl_proc_ms:    Label
var _lbl_phys_ms:    Label
var _lbl_cpu_pct:    Label
var _lbl_nodes:      Label
var _lbl_objects:    Label
var _lbl_phys_objs:  Label
var _lbl_col_pairs:  Label

# GPU
var _lbl_draw_calls: Label
var _lbl_primitives: Label
var _lbl_vram:       Label
var _lbl_tex_mem:    Label

# RAM
var _lbl_static_mem: Label
var _lbl_resources:  Label


func _ready() -> void:
	# Fill the viewport so the top bar spans the full width; never capture mouse except on
	# the toggle button (it's a full-rect overlay over the game).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_make_click_through()
	_set_advanced_visible(false)
	var sg: Node = get_node_or_null("/root/StabilityGuard")
	if sg != null:
		sg.state_changed.connect(_on_guard_state_changed)
		sg.recovered.connect(_on_guard_recovered)
	Locale.language_changed.connect(_on_language_changed)


# Let mouse events pass through to the game everywhere except the Avançado/Básico button.
func _make_click_through() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for n in find_children("*", "Control", true, false):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn_toggle.mouse_filter = Control.MOUSE_FILTER_STOP


func _build_ui() -> void:
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.04, 0.05, 0.12, 0.92)
	_bar_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar_bg.custom_minimum_size = Vector2(0, HEIGHT_BASIC)
	_bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_bar_bg)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hbox.custom_minimum_size = Vector2(0, HEIGHT_BASIC)
	hbox.add_theme_constant_override("separation", 16)
	add_child(hbox)

	_lbl_fps = _make_label("FPS: --",  hbox, 110)
	_lbl_net = _make_label("NET: --",  hbox, 170)
	_lbl_ram = _make_label("RAM: --",  hbox, 110)
	_lbl_cpu = _make_label("CPU: --",  hbox, 110)
	_lbl_gpu = _make_label("GPU: --",  hbox, 110)

	_lbl_guard_state = _make_label("● NORMAL", hbox, 120)
	_lbl_guard_state.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_btn_toggle = Button.new()
	_btn_toggle.text = Locale.tr_key("▼ Avançado")
	_btn_toggle.flat = true
	_btn_toggle.add_theme_font_size_override("font_size", 12)
	_btn_toggle.add_theme_color_override("font_color",         Color(0.6, 0.8, 1.0))
	_btn_toggle.add_theme_color_override("font_hover_color",   Color(1.0, 1.0, 1.0))
	_btn_toggle.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	_btn_toggle.custom_minimum_size = Vector2(110, HEIGHT_BASIC)
	_btn_toggle.focus_mode = Control.FOCUS_NONE
	_btn_toggle.add_to_group(Locale.SKIP_GROUP)
	_btn_toggle.pressed.connect(_on_toggle_pressed)
	hbox.add_child(_btn_toggle)

	_panel_advanced = Control.new()
	_panel_advanced.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel_advanced.position = Vector2(0, HEIGHT_BASIC)
	_panel_advanced.custom_minimum_size = Vector2(0, HEIGHT_ADVANCED - HEIGHT_BASIC)
	_panel_advanced.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_panel_advanced)

	var sep := ColorRect.new()
	sep.color = Color(0.2, 0.4, 0.8, 0.5)
	sep.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.position = Vector2(0, 0)
	_panel_advanced.add_child(sep)

	var cols := HBoxContainer.new()
	cols.position = Vector2(8, 6)
	cols.add_theme_constant_override("separation", 0)
	_panel_advanced.add_child(cols)

	_panel_advanced.resized.connect(func():
		cols.size = Vector2(_panel_advanced.size.x - 8, _panel_advanced.size.y - 6)
	)

	var col_cpu := _make_column("⚙ CPU", cols)
	_lbl_proc_ms   = _make_stat("Processo",   "--", col_cpu)
	_lbl_phys_ms   = _make_stat("Física",     "--", col_cpu)
	_lbl_cpu_pct   = _make_stat("Carga",      "--", col_cpu)
	_lbl_nodes     = _make_stat("Nós",        "--", col_cpu)
	_lbl_objects   = _make_stat("Objetos",    "--", col_cpu)
	_lbl_phys_objs = _make_stat("Corpos 3D",  "--", col_cpu)
	_lbl_col_pairs = _make_stat("Col. Pairs", "--", col_cpu)

	var col_gpu := _make_column("🖥 GPU", cols)
	_lbl_draw_calls = _make_stat("Draw Calls", "--", col_gpu)
	_lbl_primitives = _make_stat("Triângulos", "--", col_gpu)
	_lbl_vram       = _make_stat("VRAM",       "--", col_gpu)
	_lbl_tex_mem    = _make_stat("Tex. Mem.",  "--", col_gpu)

	var col_mem := _make_column("💾 Memória", cols)
	_lbl_static_mem = _make_stat("RAM Estática", "--", col_mem)
	_lbl_resources  = _make_stat("Resources",    "--", col_mem)

	var sep2 := ColorRect.new()
	sep2.color = Color(0.2, 0.4, 0.8, 0.4)
	sep2.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sep2.custom_minimum_size = Vector2(0, 1)
	sep2.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel_advanced.add_child(sep2)

	_lbl_guard_reason = Label.new()
	_lbl_guard_reason.add_to_group(Locale.SKIP_GROUP)
	_lbl_guard_reason.text = "🛡 StabilityGuard: NORMAL  —  " + Locale.tr_key("Sem alertas")
	_lbl_guard_reason.add_theme_font_size_override("font_size", 11)
	_lbl_guard_reason.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	_lbl_guard_reason.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_lbl_guard_reason.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_lbl_guard_reason.position = Vector2(8, -18)
	_panel_advanced.add_child(_lbl_guard_reason)


func _make_column(title: String, parent: Node) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(vbox)

	if parent.get_child_count() > 1:
		var div := ColorRect.new()
		div.color = Color(0.2, 0.3, 0.6, 0.4)
		div.custom_minimum_size = Vector2(1, 0)
		div.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Add it first (move_child requires it to already be a child), then slot it just
		# before the column we just appended → "… prev_col | DIV | new_col".
		parent.add_child(div)
		parent.move_child(div, parent.get_child_count() - 2)

	var lbl_title := Label.new()
	lbl_title.add_to_group(Locale.SKIP_GROUP)
	lbl_title.set_meta("loc_key", title)
	lbl_title.text = Locale.tr_key(title)
	lbl_title.add_theme_font_size_override("font_size", 11)
	lbl_title.add_theme_color_override("font_color", COLOR_HEADER)
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_title)

	return vbox


func _make_stat(label_text: String, value: String, parent: Node) -> Label:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	parent.add_child(hb)

	var lbl_key := Label.new()
	lbl_key.add_to_group(Locale.SKIP_GROUP)
	lbl_key.set_meta("loc_key", label_text)
	lbl_key.set_meta("loc_suffix", ":")
	lbl_key.text = Locale.tr_key(label_text) + ":"
	lbl_key.add_theme_font_size_override("font_size", 11)
	lbl_key.add_theme_color_override("font_color", COLOR_LABEL)
	lbl_key.custom_minimum_size = Vector2(78, 0)
	hb.add_child(lbl_key)

	var lbl_val := Label.new()
	lbl_val.add_to_group(Locale.SKIP_GROUP)
	lbl_val.text = value
	lbl_val.add_theme_font_size_override("font_size", 11)
	lbl_val.add_theme_color_override("font_color", Color.WHITE)
	lbl_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(lbl_val)

	return lbl_val


func _make_label(txt: String, parent: Node, min_w: int = 130) -> Label:
	var lbl := Label.new()
	lbl.add_to_group(Locale.SKIP_GROUP)
	lbl.text = txt
	lbl.add_theme_color_override("font_color", Color.CYAN)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(min_w, HEIGHT_BASIC)
	parent.add_child(lbl)
	return lbl


func _on_toggle_pressed() -> void:
	_advanced = not _advanced
	_set_advanced_visible(_advanced)


func _set_advanced_visible(show_advanced: bool) -> void:
	_panel_advanced.visible = show_advanced
	var target_h: int = HEIGHT_ADVANCED if show_advanced else HEIGHT_BASIC
	_bar_bg.custom_minimum_size = Vector2(0, target_h)
	_btn_toggle.text = Locale.tr_key("▲ Básico") if show_advanced else Locale.tr_key("▼ Avançado")


func _process(delta: float) -> void:
	# Skip all work while the overlay is hidden (toggled off in the Developer screen).
	if not is_visible_in_tree():
		return
	_timer += delta
	if _timer < UPDATE_INTERVAL:
		return
	_timer = 0.0
	_refresh()


func _refresh() -> void:
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	_lbl_fps.text = "FPS: %d" % int(fps)
	_lbl_fps.add_theme_color_override("font_color",
		COLOR_OK if fps >= 55 else (COLOR_WARN if fps >= 30 else COLOR_CRIT))

	# NET depends on an optional NetworkManager autoload with get_total_bps(); absent here,
	# so it degrades to N/D instead of breaking.
	var nm: Node = get_node_or_null("/root/NetworkManager")
	if nm != null and nm.has_method("get_total_bps"):
		_lbl_net.text = "NET: %s" % _fmt_bits(nm.get_total_bps() * 8.0)
	else:
		_lbl_net.text = "NET: %s" % Locale.tr_key("N/D")

	var ram_bytes: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	_lbl_ram.text = "RAM: %d MB" % int(ram_bytes / 1_048_576.0)

	var proc_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var cpu_pct: float = clampf(proc_ms / 16.67 * 100.0, 0.0, 100.0)
	_lbl_cpu.text = "CPU: %.1f%%" % cpu_pct
	_lbl_cpu.add_theme_color_override("font_color",
		COLOR_OK if cpu_pct < 60 else (COLOR_WARN if cpu_pct < 85 else COLOR_CRIT))

	var dc: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var gpu_pct: float = clampf(dc / 2.0, 0.0, 100.0)
	_lbl_gpu.text = "GPU: %.1f%%" % gpu_pct
	_lbl_gpu.add_theme_color_override("font_color",
		COLOR_OK if gpu_pct < 60 else (COLOR_WARN if gpu_pct < 85 else COLOR_CRIT))

	if not _advanced:
		return

	var phys_ms: float    = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var node_count: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var obj_count: float  = Performance.get_monitor(Performance.OBJECT_COUNT)
	var phys_objs: float  = Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	var col_pairs: float  = Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)

	_lbl_proc_ms.text   = "%.2f ms" % proc_ms
	_lbl_phys_ms.text   = "%.2f ms" % phys_ms
	_lbl_cpu_pct.text   = "%.1f %%" % cpu_pct
	_lbl_nodes.text     = "%d" % int(node_count)
	_lbl_objects.text   = "%d" % int(obj_count)
	_lbl_phys_objs.text = "%d" % int(phys_objs)
	_lbl_col_pairs.text = "%d" % int(col_pairs)

	_color_threshold(_lbl_proc_ms,   proc_ms,   8.0,  14.0)
	_color_threshold(_lbl_phys_ms,   phys_ms,   4.0,   8.0)
	_color_threshold(_lbl_cpu_pct,   cpu_pct,  60.0,  85.0)
	_color_threshold(_lbl_col_pairs, col_pairs, 50.0, 200.0)

	var primitives: float = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var vram: float       = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	var tex_mem: float    = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)

	_lbl_draw_calls.text = "%d" % int(dc)
	_lbl_primitives.text = _fmt_number(int(primitives))
	_lbl_vram.text       = "%d MB" % int(vram / 1_048_576.0)
	_lbl_tex_mem.text    = "%d MB" % int(tex_mem / 1_048_576.0)

	_color_threshold(_lbl_draw_calls, dc,          50.0,  150.0)
	_color_threshold(_lbl_primitives, primitives, 200_000.0, 500_000.0)
	_color_threshold(_lbl_vram,       vram / 1_048_576.0, 256.0, 512.0)

	var resources: float = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	_lbl_static_mem.text = "%d MB" % int(ram_bytes / 1_048_576.0)
	_lbl_resources.text  = "%d" % int(resources)

	_color_threshold(_lbl_static_mem, ram_bytes / 1_048_576.0, 256.0, 512.0)
	_color_threshold(_lbl_resources,  resources, 1000.0, 3000.0)

	_refresh_guard_badge()


func _refresh_guard_badge() -> void:
	var sg: Node = get_node_or_null("/root/StabilityGuard")
	if sg == null:
		return
	var col: Color     = sg.state_color()
	var name_s: String = sg.state_name()
	_lbl_guard_state.text = "● " + name_s
	_lbl_guard_state.add_theme_color_override("font_color", col)
	if _lbl_guard_reason:
		var reason: String = sg.last_reason if sg.last_reason != "" else Locale.tr_key("Sem alertas")
		_lbl_guard_reason.text = "🛡 StabilityGuard: %s  —  %s" % [name_s, reason]
		_lbl_guard_reason.add_theme_color_override("font_color", col)


func _on_guard_state_changed(_new_state: int, _reason: String) -> void:
	_refresh_guard_badge()


func _on_guard_recovered() -> void:
	_refresh_guard_badge()


func _on_language_changed(_lang: String) -> void:
	# Re-translate the static captions (script-owned, in SKIP_GROUP). Dynamic values
	# re-format on the next _refresh tick, so they need no handling here.
	for child in find_children("*", "Label", true, false):
		var lbl := child as Label
		if lbl.has_meta("loc_key"):
			lbl.text = Locale.tr_key(lbl.get_meta("loc_key")) + str(lbl.get_meta("loc_suffix", ""))
	_set_advanced_visible(_advanced)
	_refresh_guard_badge()


func _color_threshold(lbl: Label, value: float, warn: float, crit: float) -> void:
	lbl.add_theme_color_override("font_color",
		COLOR_OK if value < warn else (COLOR_WARN if value < crit else COLOR_CRIT))


func _fmt_bits(bps: float) -> String:
	if bps >= 1_000_000.0:
		return "%.1f Mbit/s" % (bps / 1_000_000.0)
	elif bps >= 1_000.0:
		return "%.1f Kbit/s" % (bps / 1_000.0)
	return "%d bit/s" % int(bps)


func _fmt_number(n: int) -> String:
	if n >= 1_000_000:
		return "%.1fM" % (n / 1_000_000.0)
	elif n >= 1_000:
		return "%.1fK" % (n / 1_000.0)
	return "%d" % n
