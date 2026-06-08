extends Node

signal replace_main_scene

const MENU_PATH: String = "res://scenes2D/menu/menu.tscn"

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

@onready var display_mode_windowed: Button = $UI/VBox/Tabs/Display/DisplayModeRow/DisplayModeWindowed
@onready var display_mode_fullscreen: Button = $UI/VBox/Tabs/Display/DisplayModeRow/DisplayModeFullscreen
@onready var display_mode_exclusive_fullscreen: Button = $UI/VBox/Tabs/Display/DisplayModeRow/DisplayModeExclusiveFullscreen

@onready var vsync_disabled: Button = $UI/VBox/Tabs/Display/VSyncRow/VSyncDisabled
@onready var vsync_enabled: Button = $UI/VBox/Tabs/Display/VSyncRow/VSyncEnabled
@onready var vsync_adaptive: Button = $UI/VBox/Tabs/Display/VSyncRow/VSyncAdaptive
@onready var vsync_mailbox: Button = $UI/VBox/Tabs/Display/VSyncRow/VSyncMailbox

@onready var max_fps_30: Button = $UI/VBox/Tabs/Display/MaxFPSRow/MaxFPS30
@onready var max_fps_40: Button = $UI/VBox/Tabs/Display/MaxFPSRow/MaxFPS40
@onready var max_fps_60: Button = $UI/VBox/Tabs/Display/MaxFPSRow/MaxFPS60
@onready var max_fps_72: Button = $UI/VBox/Tabs/Display/MaxFPSRow/MaxFPS72
@onready var max_fps_90: Button = $UI/VBox/Tabs/Display/MaxFPSRow/MaxFPS90
@onready var max_fps_120: Button = $UI/VBox/Tabs/Display/MaxFPSRow/MaxFPS120
@onready var max_fps_144: Button = $UI/VBox/Tabs/Display/MaxFPSRow/MaxFPS144
@onready var max_fps_unlimited: Button = $UI/VBox/Tabs/Display/MaxFPSRow/MaxFPSUnlimited

@onready var resolution_scale_ultra_performance: Button = $UI/VBox/Tabs/Resolution/ResolutionScaleRow/ResolutionScaleUltraPerformance
@onready var resolution_scale_performance: Button = $UI/VBox/Tabs/Resolution/ResolutionScaleRow/ResolutionScalePerformance
@onready var resolution_scale_balanced: Button = $UI/VBox/Tabs/Resolution/ResolutionScaleRow/ResolutionScaleBalanced
@onready var resolution_scale_quality: Button = $UI/VBox/Tabs/Resolution/ResolutionScaleRow/ResolutionScaleQuality
@onready var resolution_scale_ultra_quality: Button = $UI/VBox/Tabs/Resolution/ResolutionScaleRow/ResolutionScaleUltraQuality
@onready var resolution_scale_native: Button = $UI/VBox/Tabs/Resolution/ResolutionScaleRow/ResolutionScaleNative

@onready var scale_filter_bilinear: Button = $UI/VBox/Tabs/Resolution/ScaleFilterRow/ScaleFilterBilinear
@onready var scale_filter_fsr1: Button = $UI/VBox/Tabs/Resolution/ScaleFilterRow/ScaleFilterFSR1
@onready var scale_filter_metalfx_spatial: Button = $UI/VBox/Tabs/Resolution/ScaleFilterRow/ScaleFilterMetalFXSpatial
@onready var scale_filter_fsr2: Button = $UI/VBox/Tabs/Resolution/ScaleFilterRow/ScaleFilterFSR2
@onready var scale_filter_metalfx_temporal: Button = $UI/VBox/Tabs/Resolution/ScaleFilterRow/ScaleFilterMetalFXTemporal

@onready var video_resolution_dropdown: OptionButton = $UI/VBox/Tabs/Resolution/VideoResolutionRow/VideoResolutionDropdown

@onready var taa_disabled: Button = $UI/VBox/Tabs/Antialiasing/TAARow/TAADisabled
@onready var taa_enabled: Button = $UI/VBox/Tabs/Antialiasing/TAARow/TAAEnabled

@onready var msaa_disabled: Button = $UI/VBox/Tabs/Antialiasing/MSAARow/MSAADisabled
@onready var msaa_2x: Button = $UI/VBox/Tabs/Antialiasing/MSAARow/MSAA2X
@onready var msaa_4x: Button = $UI/VBox/Tabs/Antialiasing/MSAARow/MSAA4X
@onready var msaa_8x: Button = $UI/VBox/Tabs/Antialiasing/MSAARow/MSAA8X

@onready var fxaa_disabled: Button = $UI/VBox/Tabs/Antialiasing/FXAARow/FXAADisabled
@onready var fxaa_enabled: Button = $UI/VBox/Tabs/Antialiasing/FXAARow/FXAAEnabled

@onready var shadow_mapping_disabled: Button = $UI/VBox/Tabs/Lighting/ShadowMappingRow/ShadowMappingDisabled
@onready var shadow_mapping_enabled: Button = $UI/VBox/Tabs/Lighting/ShadowMappingRow/ShadowMappingEnabled

@onready var gi_lightmapgi: Button = $UI/VBox/Tabs/Lighting/GITypeRow/GITypeLightmapGI
@onready var gi_voxelgi: Button = $UI/VBox/Tabs/Lighting/GITypeRow/GITypeVoxelGI
@onready var gi_sdfgi: Button = $UI/VBox/Tabs/Lighting/GITypeRow/GITypeSDFGI

@onready var gi_disabled: Button = $UI/VBox/Tabs/Lighting/GIQualityRow/GIQualityDisabled
@onready var gi_low: Button = $UI/VBox/Tabs/Lighting/GIQualityRow/GIQualityLow
@onready var gi_high: Button = $UI/VBox/Tabs/Lighting/GIQualityRow/GIQualityHigh

@onready var ssao_disabled: Button = $UI/VBox/Tabs/Lighting/SSAORow/SSAODisabled
@onready var ssao_medium: Button = $UI/VBox/Tabs/Lighting/SSAORow/SSAOMedium
@onready var ssao_high: Button = $UI/VBox/Tabs/Lighting/SSAORow/SSAOHigh

@onready var ssil_disabled: Button = $UI/VBox/Tabs/Lighting/SSILRow/SSILDisabled
@onready var ssil_medium: Button = $UI/VBox/Tabs/Lighting/SSILRow/SSILMedium
@onready var ssil_high: Button = $UI/VBox/Tabs/Lighting/SSILRow/SSILHigh

@onready var bloom_disabled: Button = $UI/VBox/Tabs/Effects/BloomRow/BloomDisabled
@onready var bloom_enabled: Button = $UI/VBox/Tabs/Effects/BloomRow/BloomEnabled

@onready var volumetric_fog_disabled: Button = $UI/VBox/Tabs/Effects/VolumetricFogRow/VolumetricFogDisabled
@onready var volumetric_fog_enabled: Button = $UI/VBox/Tabs/Effects/VolumetricFogRow/VolumetricFogEnabled

@onready var music_disabled: Button = $UI/VBox/Tabs/Audio/MusicRow/MusicDisabled
@onready var music_enabled: Button = $UI/VBox/Tabs/Audio/MusicRow/MusicEnabled

@onready var _rows: Array = []


func _ready() -> void:
	_rows = [
		$UI/VBox/Tabs/Display/DisplayModeRow,
		$UI/VBox/Tabs/Display/VSyncRow,
		$UI/VBox/Tabs/Display/MaxFPSRow,
		$UI/VBox/Tabs/Resolution/ResolutionScaleRow,
		$UI/VBox/Tabs/Resolution/ScaleFilterRow,
		$UI/VBox/Tabs/Antialiasing/TAARow,
		$UI/VBox/Tabs/Antialiasing/MSAARow,
		$UI/VBox/Tabs/Antialiasing/FXAARow,
		$UI/VBox/Tabs/Lighting/ShadowMappingRow,
		$UI/VBox/Tabs/Lighting/GITypeRow,
		$UI/VBox/Tabs/Lighting/GIQualityRow,
		$UI/VBox/Tabs/Lighting/SSAORow,
		$UI/VBox/Tabs/Lighting/SSILRow,
		$UI/VBox/Tabs/Effects/BloomRow,
		$UI/VBox/Tabs/Effects/VolumetricFogRow,
		$UI/VBox/Tabs/Audio/MusicRow,
	]

	if not metalfx_supported:
		scale_filter_metalfx_spatial.hide()
		scale_filter_metalfx_temporal.hide()

	for row in _rows:
		_make_button_group(row)

	_populate_video_resolutions()

	_load_current_settings()


func _populate_video_resolutions() -> void:
	video_resolution_dropdown.clear()
	for res in VIDEO_RESOLUTIONS:
		video_resolution_dropdown.add_item(res["nome"])
	# Reflect the current window size if it matches a preset; otherwise show no
	# selection rather than implying a resolution that isn't active.
	var current := DisplayServer.window_get_size()
	var matched := -1
	for i in range(VIDEO_RESOLUTIONS.size()):
		if VIDEO_RESOLUTIONS[i]["largura"] == current.x and VIDEO_RESOLUTIONS[i]["altura"] == current.y:
			matched = i
			break
	video_resolution_dropdown.selected = matched
	video_resolution_dropdown.item_selected.connect(_on_video_resolution_selected)


func _make_button_group(row: Node) -> void:
	var group := ButtonGroup.new()
	for btn in row.get_children():
		if btn is BaseButton:
			btn.button_group = group


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


func _on_apply_pressed() -> void:
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

	emit_signal("replace_main_scene", load(MENU_PATH))


func _on_video_resolution_selected(index: int) -> void:
	if index < 0 or index >= VIDEO_RESOLUTIONS.size():
		return
	var res: Dictionary = VIDEO_RESOLUTIONS[index]
	var target := Vector2i(res["largura"], res["altura"])
	var window := get_window()
	# A specific pixel size is only meaningful in windowed mode — drop out of
	# (exclusive) fullscreen first so the change is visible immediately.
	if window.mode == Window.MODE_FULLSCREEN \
			or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN \
			or window.mode == Window.MODE_MAXIMIZED:
		window.mode = Window.MODE_WINDOWED
	window.size = target
	# Re-center on the window's current screen.
	var screen := window.current_screen
	var screen_pos := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	window.position = screen_pos + (screen_size - target) / 2


func _on_back_pressed() -> void:
	emit_signal("replace_main_scene", load(MENU_PATH))


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
