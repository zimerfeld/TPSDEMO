extends Node

signal replace_main_scene

const MENU_PATH: String = "res://scenes2D/menu/menu.tscn"

# Placeholder shown as the first, default-selected option of the resolution
# dropdown. Picking it leaves the window untouched; it stays the default until a
# saved resolution matches a preset, in which case that preset is selected instead.
const SELECT_LABEL: String = "Selecione..."

# Resolution presets for the "Resolução Vídeo" dropdown. Selecting one resizes
# the game window to that exact pixel size immediately (see
# _on_video_resolution_selected).
const VIDEO_RESOLUTIONS: Array[Dictionary] = [
	{"nome": "HD — 1280 × 720", "largura": 1280, "altura": 720},
	{"nome": "Full HD — 1920 × 1080", "largura": 1920, "altura": 1080},
	{"nome": "QHD / 2K — 2560 × 1440", "largura": 2560, "altura": 1440},
	{"nome": "4K / UHD — 3840 × 2160", "largura": 3840, "altura": 2160},
	{"nome": "8K — 7680 × 4320", "largura": 7680, "altura": 4320},
	{"nome": "HD retrato — 720 × 1280", "largura": 720, "altura": 1280},
	{"nome": "Full HD retrato — 1080 × 1920", "largura": 1080, "altura": 1920},
	{"nome": "iPhone SE — 375 × 667", "largura": 375, "altura": 667},
	{"nome": "iPhone 14 — 390 × 844", "largura": 390, "altura": 844},
	{"nome": "iPhone 14 Plus — 430 × 932", "largura": 430, "altura": 932},
	{"nome": "Android típico — 412 × 915", "largura": 412, "altura": 915},
	{"nome": "iPad — 768 × 1024", "largura": 768, "altura": 1024},
	{"nome": "iPad Retina — 2048 × 1536", "largura": 2048, "altura": 1536},
	{"nome": "Tablet Android — 800 × 1280", "largura": 800, "altura": 1280},
	{"nome": "Tablet grande — 1600 × 2560", "largura": 1600, "altura": 2560},
]

var metalfx_supported: bool = RenderingServer.get_current_rendering_driver_name() == "metal"

@onready var display_mode_windowed: Button = %DisplayModeWindowed
@onready var display_mode_fullscreen: Button = %DisplayModeFullscreen
@onready var display_mode_exclusive_fullscreen: Button = %DisplayModeExclusiveFullscreen

@onready var vsync_disabled: Button = %VSyncDisabled
@onready var vsync_enabled: Button = %VSyncEnabled
@onready var vsync_adaptive: Button = %VSyncAdaptive
@onready var vsync_mailbox: Button = %VSyncMailbox

@onready var max_fps_30: Button = %MaxFPS30
@onready var max_fps_40: Button = %MaxFPS40
@onready var max_fps_60: Button = %MaxFPS60
@onready var max_fps_72: Button = %MaxFPS72
@onready var max_fps_90: Button = %MaxFPS90
@onready var max_fps_120: Button = %MaxFPS120
@onready var max_fps_144: Button = %MaxFPS144
@onready var max_fps_unlimited: Button = %MaxFPSUnlimited

@onready var resolution_scale_ultra_performance: Button = %ResolutionScaleUltraPerformance
@onready var resolution_scale_performance: Button = %ResolutionScalePerformance
@onready var resolution_scale_balanced: Button = %ResolutionScaleBalanced
@onready var resolution_scale_quality: Button = %ResolutionScaleQuality
@onready var resolution_scale_ultra_quality: Button = %ResolutionScaleUltraQuality
@onready var resolution_scale_native: Button = %ResolutionScaleNative

@onready var scale_filter_bilinear: Button = %ScaleFilterBilinear
@onready var scale_filter_fsr1: Button = %ScaleFilterFSR1
@onready var scale_filter_metalfx_spatial: Button = %ScaleFilterMetalFXSpatial
@onready var scale_filter_fsr2: Button = %ScaleFilterFSR2
@onready var scale_filter_metalfx_temporal: Button = %ScaleFilterMetalFXTemporal

@onready var video_resolution_dropdown: OptionButton = %VideoResolutionDropdown

@onready var taa_disabled: Button = %TAADisabled
@onready var taa_enabled: Button = %TAAEnabled

@onready var msaa_disabled: Button = %MSAADisabled
@onready var msaa_2x: Button = %MSAA2X
@onready var msaa_4x: Button = %MSAA4X
@onready var msaa_8x: Button = %MSAA8X

@onready var fxaa_disabled: Button = %FXAADisabled
@onready var fxaa_enabled: Button = %FXAAEnabled

@onready var shadow_mapping_disabled: Button = %ShadowMappingDisabled
@onready var shadow_mapping_enabled: Button = %ShadowMappingEnabled

@onready var gi_lightmapgi: Button = %GITypeLightmapGI
@onready var gi_voxelgi: Button = %GITypeVoxelGI
@onready var gi_sdfgi: Button = %GITypeSDFGI

@onready var gi_disabled: Button = %GIQualityDisabled
@onready var gi_low: Button = %GIQualityLow
@onready var gi_high: Button = %GIQualityHigh

@onready var ssao_disabled: Button = %SSAODisabled
@onready var ssao_medium: Button = %SSAOMedium
@onready var ssao_high: Button = %SSAOHigh

@onready var ssil_disabled: Button = %SSILDisabled
@onready var ssil_medium: Button = %SSILMedium
@onready var ssil_high: Button = %SSILHigh

@onready var bloom_disabled: Button = %BloomDisabled
@onready var bloom_enabled: Button = %BloomEnabled

@onready var volumetric_fog_disabled: Button = %VolumetricFogDisabled
@onready var volumetric_fog_enabled: Button = %VolumetricFogEnabled

@onready var music_disabled: Button = %MusicDisabled
@onready var music_enabled: Button = %MusicEnabled

@onready var sfx_disabled: Button = %SFXDisabled
@onready var sfx_enabled: Button = %SFXEnabled

@onready var tabs: TabContainer = %Tabs
@onready var portuguese_button: Button = %PortugueseButton
@onready var english_button: Button = %EnglishButton

@onready var _rows: Array = []

# Index of the currently-confirmed video resolution, used to revert the dropdown
# if the user cancels the confirmation popup.
var _current_resolution_index: int = 0


func _ready() -> void:
	_rows = [
		%DisplayModeRow,
		%VSyncRow,
		%MaxFPSRow,
		%ResolutionScaleRow,
		%ScaleFilterRow,
		%TAARow,
		%MSAARow,
		%FXAARow,
		%ShadowMappingRow,
		%GITypeRow,
		%GIQualityRow,
		%SSAORow,
		%SSILRow,
		%BloomRow,
		%VolumetricFogRow,
		%MusicRow,
		%SFXRow,
	]

	if not metalfx_supported:
		scale_filter_metalfx_spatial.hide()
		scale_filter_metalfx_temporal.hide()

	for row in _rows:
		_make_button_group(row)

	_populate_video_resolutions()

	_load_current_settings()

	# There is no "Aplicar" button: every option saves + applies the moment it changes.
	# Connect AFTER _load_current_settings so programmatically setting the initial state
	# above doesn't fire a spurious apply. The video-resolution dropdown is handled
	# apart (it keeps its own confirmation dialog in _on_video_resolution_selected).
	for row in _rows:
		var group := _group_of(row)
		if group != null:
			group.pressed.connect(_on_setting_changed)

	# Tab titles come from the child node names (not Button/Label text), so the automatic
	# localizer can't reach them — translate them here and on every language change.
	_localize_tabs()
	Locale.language_changed.connect(_on_language_changed)
	_update_language_buttons()


# Translate each tab's title from its (English) node name via the active dictionary.
func _localize_tabs() -> void:
	for i in tabs.get_tab_count():
		tabs.set_tab_title(i, Locale.tr_key(tabs.get_tab_control(i).name))


func _on_language_changed(_lang: String) -> void:
	_localize_tabs()
	_update_language_buttons()


func _update_language_buttons() -> void:
	var lang := Locale.get_language()
	portuguese_button.disabled = lang == "pt"
	english_button.disabled = lang == "en"


func _on_portuguese_pressed() -> void:
	Locale.set_language("pt")
	_update_language_buttons()


func _on_english_pressed() -> void:
	Locale.set_language("en")
	_update_language_buttons()


func _populate_video_resolutions() -> void:
	video_resolution_dropdown.clear()
	# Index 0 is the "Selecione..." placeholder; presets start at index 1 (mapping
	# to VIDEO_RESOLUTIONS[index - 1]).
	video_resolution_dropdown.add_item(SELECT_LABEL)
	for res in VIDEO_RESOLUTIONS:
		video_resolution_dropdown.add_item(res["nome"])
	_select_saved_resolution()
	video_resolution_dropdown.item_selected.connect(_on_video_resolution_selected)


# Point the dropdown at the preset matching the saved resolution (or the "Selecione..."
# placeholder if none matches). Setting `selected` programmatically does NOT emit
# item_selected, so this is safe to call without triggering the confirmation dialog —
# used on load and after a Reset.
func _select_saved_resolution() -> void:
	var saved: Vector2i = Settings.config_file.get_value("video", "resolution", Vector2i.ZERO)
	var matched := 0
	for i in range(VIDEO_RESOLUTIONS.size()):
		if VIDEO_RESOLUTIONS[i]["largura"] == saved.x and VIDEO_RESOLUTIONS[i]["altura"] == saved.y:
			matched = i + 1
			break
	video_resolution_dropdown.selected = matched
	_current_resolution_index = matched


func _make_button_group(row: Node) -> void:
	var group := ButtonGroup.new()
	for btn in row.get_children():
		if btn is BaseButton:
			btn.button_group = group


# The shared ButtonGroup of a settings row (every BaseButton in the row carries it), or
# null if the row has no buttons. Used to listen for live changes and to re-fetch groups.
func _group_of(row: Node) -> ButtonGroup:
	for btn in row.get_children():
		if btn is BaseButton:
			return btn.button_group
	return null


# A button in one of the option rows was clicked: persist + apply every setting now
# (there is no "Aplicar" button). The pressed button itself is unused — _apply_settings
# reads the current state of every row.
func _on_setting_changed(_button: BaseButton) -> void:
	_apply_settings()


func _load_current_settings() -> void:
	var display_mode: int = Settings.config_file.get_value("video", "display_mode")
	if display_mode == Window.MODE_WINDOWED or display_mode == Window.MODE_MAXIMIZED:
		display_mode_windowed.button_pressed = true
	elif display_mode == Window.MODE_FULLSCREEN:
		display_mode_fullscreen.button_pressed = true
	else:
		display_mode_exclusive_fullscreen.button_pressed = true

	match Settings.config_file.get_value("video", "vsync"):
		DisplayServer.VSYNC_DISABLED: vsync_disabled.button_pressed = true
		DisplayServer.VSYNC_ENABLED:  vsync_enabled.button_pressed = true
		DisplayServer.VSYNC_ADAPTIVE: vsync_adaptive.button_pressed = true
		_:                            vsync_mailbox.button_pressed = true

	match Settings.config_file.get_value("video", "max_fps"):
		30:  max_fps_30.button_pressed = true
		40:  max_fps_40.button_pressed = true
		60:  max_fps_60.button_pressed = true
		72:  max_fps_72.button_pressed = true
		90:  max_fps_90.button_pressed = true
		120: max_fps_120.button_pressed = true
		144: max_fps_144.button_pressed = true
		_:   max_fps_unlimited.button_pressed = true

	var res_scale: float = Settings.config_file.get_value("video", "resolution_scale")
	if is_equal_approx(res_scale, 1.0 / 3.0):
		resolution_scale_ultra_performance.button_pressed = true
	elif is_equal_approx(res_scale, 1.0 / 2.0):
		resolution_scale_performance.button_pressed = true
	elif is_equal_approx(res_scale, 1.0 / 1.7):
		resolution_scale_balanced.button_pressed = true
	elif is_equal_approx(res_scale, 1.0 / 1.5):
		resolution_scale_quality.button_pressed = true
	elif is_equal_approx(res_scale, 1.0 / 1.3):
		resolution_scale_ultra_quality.button_pressed = true
	else:
		resolution_scale_native.button_pressed = true

	match Settings.config_file.get_value("video", "scale_filter"):
		Viewport.SCALING_3D_MODE_BILINEAR:         scale_filter_bilinear.button_pressed = true
		Viewport.SCALING_3D_MODE_FSR:              scale_filter_fsr1.button_pressed = true
		Viewport.SCALING_3D_MODE_FSR2:             scale_filter_fsr2.button_pressed = true
		Viewport.SCALING_3D_MODE_METALFX_SPATIAL:  scale_filter_metalfx_spatial.button_pressed = true
		Viewport.SCALING_3D_MODE_METALFX_TEMPORAL: scale_filter_metalfx_temporal.button_pressed = true
		_:
			if metalfx_supported:
				scale_filter_metalfx_temporal.button_pressed = true
			else:
				scale_filter_bilinear.button_pressed = true

	match Settings.config_file.get_value("rendering", "gi_type"):
		Settings.GIType.LIGHTMAP_GI: gi_lightmapgi.button_pressed = true
		Settings.GIType.VOXEL_GI:    gi_voxelgi.button_pressed = true
		Settings.GIType.SDFGI:       gi_sdfgi.button_pressed = true

	match Settings.config_file.get_value("rendering", "gi_quality"):
		Settings.GIQuality.DISABLED: gi_disabled.button_pressed = true
		Settings.GIQuality.LOW:      gi_low.button_pressed = true
		Settings.GIQuality.HIGH:     gi_high.button_pressed = true

	taa_disabled.button_pressed = not Settings.config_file.get_value("rendering", "taa")
	taa_enabled.button_pressed = Settings.config_file.get_value("rendering", "taa")

	match Settings.config_file.get_value("rendering", "msaa"):
		Viewport.MSAA_DISABLED: msaa_disabled.button_pressed = true
		Viewport.MSAA_2X:       msaa_2x.button_pressed = true
		Viewport.MSAA_4X:       msaa_4x.button_pressed = true
		Viewport.MSAA_8X:       msaa_8x.button_pressed = true

	fxaa_disabled.button_pressed = not Settings.config_file.get_value("rendering", "fxaa")
	fxaa_enabled.button_pressed = Settings.config_file.get_value("rendering", "fxaa")

	shadow_mapping_disabled.button_pressed = not Settings.config_file.get_value("rendering", "shadow_mapping")
	shadow_mapping_enabled.button_pressed = Settings.config_file.get_value("rendering", "shadow_mapping")

	match Settings.config_file.get_value("rendering", "ssao_quality"):
		-1:                                      ssao_disabled.button_pressed = true
		RenderingServer.ENV_SSAO_QUALITY_MEDIUM: ssao_medium.button_pressed = true
		RenderingServer.ENV_SSAO_QUALITY_HIGH:   ssao_high.button_pressed = true

	match Settings.config_file.get_value("rendering", "ssil_quality"):
		-1:                                      ssil_disabled.button_pressed = true
		RenderingServer.ENV_SSIL_QUALITY_MEDIUM: ssil_medium.button_pressed = true
		RenderingServer.ENV_SSIL_QUALITY_HIGH:   ssil_high.button_pressed = true

	bloom_disabled.button_pressed = not Settings.config_file.get_value("rendering", "bloom")
	bloom_enabled.button_pressed = Settings.config_file.get_value("rendering", "bloom")

	volumetric_fog_disabled.button_pressed = not Settings.config_file.get_value("rendering", "volumetric_fog")
	volumetric_fog_enabled.button_pressed = Settings.config_file.get_value("rendering", "volumetric_fog")

	music_disabled.button_pressed = not Settings.config_file.get_value("audio", "music")
	music_enabled.button_pressed = Settings.config_file.get_value("audio", "music")

	sfx_disabled.button_pressed = not Settings.config_file.get_value("audio", "sfx")
	sfx_enabled.button_pressed = Settings.config_file.get_value("audio", "sfx")


# Persist + apply EVERY option to the live window at once. Called immediately whenever
# any option changes (no "Aplicar" button). Does not navigate away — only "Voltar"
# leaves. Note: the video resolution (pixel size) is intentionally NOT touched here; it
# is applied by _on_video_resolution_selected so its windowed resize isn't overridden.
func _apply_settings() -> void:
	if display_mode_windowed.button_pressed:
		Settings.config_file.set_value("video", "display_mode", Window.MODE_WINDOWED)
	elif display_mode_fullscreen.button_pressed:
		Settings.config_file.set_value("video", "display_mode", Window.MODE_FULLSCREEN)
	elif display_mode_exclusive_fullscreen.button_pressed:
		Settings.config_file.set_value("video", "display_mode", Window.MODE_EXCLUSIVE_FULLSCREEN)

	if vsync_disabled.button_pressed:
		Settings.config_file.set_value("video", "vsync", DisplayServer.VSYNC_DISABLED)
	elif vsync_enabled.button_pressed:
		Settings.config_file.set_value("video", "vsync", DisplayServer.VSYNC_ENABLED)
	elif vsync_adaptive.button_pressed:
		Settings.config_file.set_value("video", "vsync", DisplayServer.VSYNC_ADAPTIVE)
	elif vsync_mailbox.button_pressed:
		Settings.config_file.set_value("video", "vsync", DisplayServer.VSYNC_MAILBOX)

	if max_fps_30.button_pressed:
		Settings.config_file.set_value("video", "max_fps", 30)
	elif max_fps_40.button_pressed:
		Settings.config_file.set_value("video", "max_fps", 40)
	elif max_fps_60.button_pressed:
		Settings.config_file.set_value("video", "max_fps", 60)
	elif max_fps_72.button_pressed:
		Settings.config_file.set_value("video", "max_fps", 72)
	elif max_fps_90.button_pressed:
		Settings.config_file.set_value("video", "max_fps", 90)
	elif max_fps_120.button_pressed:
		Settings.config_file.set_value("video", "max_fps", 120)
	elif max_fps_144.button_pressed:
		Settings.config_file.set_value("video", "max_fps", 144)
	elif max_fps_unlimited.button_pressed:
		Settings.config_file.set_value("video", "max_fps", 0)

	if resolution_scale_ultra_performance.button_pressed:
		Settings.config_file.set_value("video", "resolution_scale", 1.0 / 3.0)
	elif resolution_scale_performance.button_pressed:
		Settings.config_file.set_value("video", "resolution_scale", 1.0 / 2.0)
	elif resolution_scale_balanced.button_pressed:
		Settings.config_file.set_value("video", "resolution_scale", 1.0 / 1.7)
	elif resolution_scale_quality.button_pressed:
		Settings.config_file.set_value("video", "resolution_scale", 1.0 / 1.5)
	elif resolution_scale_ultra_quality.button_pressed:
		Settings.config_file.set_value("video", "resolution_scale", 1.0 / 1.3)
	elif resolution_scale_native.button_pressed:
		Settings.config_file.set_value("video", "resolution_scale", 1.0)

	if scale_filter_bilinear.button_pressed:
		Settings.config_file.set_value("video", "scale_filter", Viewport.SCALING_3D_MODE_BILINEAR)
	elif scale_filter_fsr1.button_pressed:
		Settings.config_file.set_value("video", "scale_filter", Viewport.SCALING_3D_MODE_FSR)
	elif scale_filter_fsr2.button_pressed:
		Settings.config_file.set_value("video", "scale_filter", Viewport.SCALING_3D_MODE_FSR2)
	elif scale_filter_metalfx_spatial.button_pressed:
		Settings.config_file.set_value("video", "scale_filter", Viewport.SCALING_3D_MODE_METALFX_SPATIAL)
	elif scale_filter_metalfx_temporal.button_pressed:
		Settings.config_file.set_value("video", "scale_filter", Viewport.SCALING_3D_MODE_METALFX_TEMPORAL)

	if gi_lightmapgi.button_pressed:
		Settings.config_file.set_value("rendering", "gi_type", Settings.GIType.LIGHTMAP_GI)
	elif gi_voxelgi.button_pressed:
		Settings.config_file.set_value("rendering", "gi_type", Settings.GIType.VOXEL_GI)
	elif gi_sdfgi.button_pressed:
		Settings.config_file.set_value("rendering", "gi_type", Settings.GIType.SDFGI)

	if gi_disabled.button_pressed:
		Settings.config_file.set_value("rendering", "gi_quality", Settings.GIQuality.DISABLED)
	elif gi_low.button_pressed:
		Settings.config_file.set_value("rendering", "gi_quality", Settings.GIQuality.LOW)
	elif gi_high.button_pressed:
		Settings.config_file.set_value("rendering", "gi_quality", Settings.GIQuality.HIGH)

	Settings.config_file.set_value("rendering", "taa", taa_enabled.button_pressed)

	if msaa_disabled.button_pressed:
		Settings.config_file.set_value("rendering", "msaa", Viewport.MSAA_DISABLED)
	elif msaa_2x.button_pressed:
		Settings.config_file.set_value("rendering", "msaa", Viewport.MSAA_2X)
	elif msaa_4x.button_pressed:
		Settings.config_file.set_value("rendering", "msaa", Viewport.MSAA_4X)
	elif msaa_8x.button_pressed:
		Settings.config_file.set_value("rendering", "msaa", Viewport.MSAA_8X)

	Settings.config_file.set_value("rendering", "shadow_mapping", shadow_mapping_enabled.button_pressed)
	Settings.config_file.set_value("rendering", "fxaa", fxaa_enabled.button_pressed)

	if ssao_disabled.button_pressed:
		Settings.config_file.set_value("rendering", "ssao_quality", -1)
	elif ssao_medium.button_pressed:
		Settings.config_file.set_value("rendering", "ssao_quality", RenderingServer.ENV_SSAO_QUALITY_MEDIUM)
	elif ssao_high.button_pressed:
		Settings.config_file.set_value("rendering", "ssao_quality", RenderingServer.ENV_SSAO_QUALITY_HIGH)

	if ssil_disabled.button_pressed:
		Settings.config_file.set_value("rendering", "ssil_quality", -1)
	elif ssil_medium.button_pressed:
		Settings.config_file.set_value("rendering", "ssil_quality", RenderingServer.ENV_SSIL_QUALITY_MEDIUM)
	elif ssil_high.button_pressed:
		Settings.config_file.set_value("rendering", "ssil_quality", RenderingServer.ENV_SSIL_QUALITY_HIGH)

	Settings.config_file.set_value("rendering", "bloom", bloom_enabled.button_pressed)
	Settings.config_file.set_value("rendering", "volumetric_fog", volumetric_fog_enabled.button_pressed)

	Settings.config_file.set_value("audio", "music", music_enabled.button_pressed)
	Settings.config_file.set_value("audio", "sfx", sfx_enabled.button_pressed)

	Settings.save_settings()
	Settings.apply_audio_settings()

	get_window().mode = Settings.config_file.get_value("video", "display_mode")
	DisplayServer.window_set_vsync_mode(Settings.config_file.get_value("video", "vsync"))
	Engine.max_fps = Settings.config_file.get_value("video", "max_fps")
	get_window().scaling_3d_scale = Settings.config_file.get_value("video", "resolution_scale")
	get_window().scaling_3d_mode = Settings.config_file.get_value("video", "scale_filter")
	get_window().use_taa = Settings.config_file.get_value("rendering", "taa")
	get_window().msaa_3d = Settings.config_file.get_value("rendering", "msaa")
	get_window().screen_space_aa = (
		Viewport.SCREEN_SPACE_AA_FXAA if Settings.config_file.get_value("rendering", "fxaa")
		else Viewport.SCREEN_SPACE_AA_DISABLED
	)

	DebugOverlay.refresh()


func _on_video_resolution_selected(index: int) -> void:
	if index == _current_resolution_index:
		return
	if index <= 0:
		# "Selecione..." placeholder: leave the window resolution untouched.
		_current_resolution_index = index
		return
	var res_index := index - 1
	if res_index >= VIDEO_RESOLUTIONS.size():
		return
	# Ask for confirmation in a centered floating window before changing the
	# resolution; the dropdown reverts to the previous choice if the user cancels.
	var dlg := ConfirmationDialog.new()
	dlg.title = Locale.tr_key("Resolução de vídeo")
	dlg.dialog_text = Locale.tr_key("Confirma resolução de video escolhida ?")
	dlg.get_ok_button().text = Locale.tr_key("Sim")
	dlg.get_cancel_button().text = Locale.tr_key("Não")
	dlg.confirmed.connect(func() -> void:
		_apply_video_resolution(res_index)
		_current_resolution_index = index
		var res: Dictionary = VIDEO_RESOLUTIONS[res_index]
		Settings.config_file.set_value("video", "resolution", Vector2i(res["largura"], res["altura"]))
		# A fixed pixel size only holds in windowed mode, so lock the display mode to
		# Window and persist it — otherwise the next live-applied option would snap the
		# window back to a saved fullscreen mode and undo the resolution. Updating the
		# radio keeps the Display tab consistent (no spurious apply: setting button_pressed
		# fires `toggled`, not the group's `pressed` we listen to).
		Settings.config_file.set_value("video", "display_mode", Window.MODE_WINDOWED)
		display_mode_windowed.button_pressed = true
		Settings.save_settings()
		dlg.queue_free()
	)
	# `canceled` covers the "Não" button, the close (X) button and Escape.
	dlg.canceled.connect(func() -> void:
		video_resolution_dropdown.selected = _current_resolution_index
		dlg.queue_free()
	)
	add_child(dlg)
	dlg.popup_centered()


func _apply_video_resolution(index: int) -> void:
	var res: Dictionary = VIDEO_RESOLUTIONS[index]
	var target := Vector2i(res["largura"], res["altura"])
	var window := get_window()
	# A specific pixel size is only meaningful in windowed mode — drop out of
	# (exclusive) fullscreen first so the change is visible immediately.
	if window.mode == Window.MODE_FULLSCREEN \
			or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN \
			or window.mode == Window.MODE_MAXIMIZED:
		window.mode = Window.MODE_WINDOWED
	# Never let the window grow past the visible screen, or its top/bottom (and the
	# bottom button bar) would be pushed off the monitor. Clamp to the usable area
	# (excludes the taskbar) and center the window inside it.
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	target.x = mini(target.x, usable.size.x)
	target.y = mini(target.y, usable.size.y)
	window.size = target
	@warning_ignore("integer_division")
	window.position = usable.position + (usable.size - target) / 2


# "Reset" button: ask for confirmation (same Sim/Não dialog as the video resolution).
# On "Sim", restore the common-hardware defaults, refresh the controls to match and
# apply everything to the live window/audio immediately; on "Não", do nothing.
func _on_reset_pressed() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = Locale.tr_key("Restaurar padrões")
	dlg.dialog_text = Locale.tr_key("Restaurar todas as configurações para o padrão?")
	dlg.get_ok_button().text = Locale.tr_key("Sim")
	dlg.get_cancel_button().text = Locale.tr_key("Não")
	dlg.confirmed.connect(func() -> void:
		Settings.reset_to_defaults()
		_load_current_settings()
		_select_saved_resolution()
		_apply_settings()
		Settings.apply_window_resolution(get_window())
		dlg.queue_free()
	)
	# `canceled` covers the "Não" button, the close (X) button and Escape.
	dlg.canceled.connect(func() -> void:
		dlg.queue_free()
	)
	add_child(dlg)
	dlg.popup_centered()


func _on_back_pressed() -> void:
	emit_signal("replace_main_scene", load(MENU_PATH))


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
