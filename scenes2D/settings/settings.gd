extends Node

signal replace_main_scene

const MENU_PATH: String = "res://scenes2D/menu/menu.tscn"

var metalfx_supported: bool = RenderingServer.get_current_rendering_driver_name() == "metal"

@onready var display_mode_windowed: Button = $UI/VBox/Tabs/Display/DisplayMode/Windowed
@onready var display_mode_fullscreen: Button = $UI/VBox/Tabs/Display/DisplayMode/Fullscreen
@onready var display_mode_exclusive_fullscreen: Button = $UI/VBox/Tabs/Display/DisplayMode/ExclusiveFullscreen

@onready var vsync_disabled: Button = $UI/VBox/Tabs/Display/VSync/Disabled
@onready var vsync_enabled: Button = $UI/VBox/Tabs/Display/VSync/Enabled
@onready var vsync_adaptive: Button = $UI/VBox/Tabs/Display/VSync/Adaptive
@onready var vsync_mailbox: Button = $UI/VBox/Tabs/Display/VSync/Mailbox

@onready var max_fps_30: Button = $"UI/VBox/Tabs/Display/MaxFPS/30"
@onready var max_fps_40: Button = $"UI/VBox/Tabs/Display/MaxFPS/40"
@onready var max_fps_60: Button = $"UI/VBox/Tabs/Display/MaxFPS/60"
@onready var max_fps_72: Button = $"UI/VBox/Tabs/Display/MaxFPS/72"
@onready var max_fps_90: Button = $"UI/VBox/Tabs/Display/MaxFPS/90"
@onready var max_fps_120: Button = $"UI/VBox/Tabs/Display/MaxFPS/120"
@onready var max_fps_144: Button = $"UI/VBox/Tabs/Display/MaxFPS/144"
@onready var max_fps_unlimited: Button = $UI/VBox/Tabs/Display/MaxFPS/Unlimited

@onready var resolution_scale_ultra_performance: Button = $UI/VBox/Tabs/Resolution/ResolutionScale/UltraPerformance
@onready var resolution_scale_performance: Button = $UI/VBox/Tabs/Resolution/ResolutionScale/Performance
@onready var resolution_scale_balanced: Button = $UI/VBox/Tabs/Resolution/ResolutionScale/Balanced
@onready var resolution_scale_quality: Button = $UI/VBox/Tabs/Resolution/ResolutionScale/Quality
@onready var resolution_scale_ultra_quality: Button = $UI/VBox/Tabs/Resolution/ResolutionScale/UltraQuality
@onready var resolution_scale_native: Button = $UI/VBox/Tabs/Resolution/ResolutionScale/Native

@onready var scale_filter_bilinear: Button = $UI/VBox/Tabs/Resolution/ScaleFilter/Bilinear
@onready var scale_filter_fsr1: Button = $UI/VBox/Tabs/Resolution/ScaleFilter/FSR1
@onready var scale_filter_metalfx_spatial: Button = $UI/VBox/Tabs/Resolution/ScaleFilter/MetalFXSpatial
@onready var scale_filter_fsr2: Button = $UI/VBox/Tabs/Resolution/ScaleFilter/FSR2
@onready var scale_filter_metalfx_temporal: Button = $UI/VBox/Tabs/Resolution/ScaleFilter/MetalFXTemporal

@onready var taa_disabled: Button = $UI/VBox/Tabs/Antialiasing/TAA/Disabled
@onready var taa_enabled: Button = $UI/VBox/Tabs/Antialiasing/TAA/Enabled

@onready var msaa_disabled: Button = $UI/VBox/Tabs/Antialiasing/MSAA/Disabled
@onready var msaa_2x: Button = $"UI/VBox/Tabs/Antialiasing/MSAA/2X"
@onready var msaa_4x: Button = $"UI/VBox/Tabs/Antialiasing/MSAA/4X"
@onready var msaa_8x: Button = $"UI/VBox/Tabs/Antialiasing/MSAA/8X"

@onready var fxaa_disabled: Button = $UI/VBox/Tabs/Antialiasing/FXAA/Disabled
@onready var fxaa_enabled: Button = $UI/VBox/Tabs/Antialiasing/FXAA/Enabled

@onready var shadow_mapping_disabled: Button = $UI/VBox/Tabs/Lighting/ShadowMapping/Disabled
@onready var shadow_mapping_enabled: Button = $UI/VBox/Tabs/Lighting/ShadowMapping/Enabled

@onready var gi_lightmapgi: Button = $UI/VBox/Tabs/Lighting/GIType/LightmapGI
@onready var gi_voxelgi: Button = $UI/VBox/Tabs/Lighting/GIType/VoxelGI
@onready var gi_sdfgi: Button = $UI/VBox/Tabs/Lighting/GIType/SDFGI

@onready var gi_disabled: Button = $UI/VBox/Tabs/Lighting/GIQuality/Disabled
@onready var gi_low: Button = $UI/VBox/Tabs/Lighting/GIQuality/Low
@onready var gi_high: Button = $UI/VBox/Tabs/Lighting/GIQuality/High

@onready var ssao_disabled: Button = $UI/VBox/Tabs/Lighting/SSAO/Disabled
@onready var ssao_medium: Button = $UI/VBox/Tabs/Lighting/SSAO/Medium
@onready var ssao_high: Button = $UI/VBox/Tabs/Lighting/SSAO/High

@onready var ssil_disabled: Button = $UI/VBox/Tabs/Lighting/SSIL/Disabled
@onready var ssil_medium: Button = $UI/VBox/Tabs/Lighting/SSIL/Medium
@onready var ssil_high: Button = $UI/VBox/Tabs/Lighting/SSIL/High

@onready var bloom_disabled: Button = $UI/VBox/Tabs/Effects/Bloom/Disabled
@onready var bloom_enabled: Button = $UI/VBox/Tabs/Effects/Bloom/Enabled

@onready var volumetric_fog_disabled: Button = $UI/VBox/Tabs/Effects/VolumetricFog/Disabled
@onready var volumetric_fog_enabled: Button = $UI/VBox/Tabs/Effects/VolumetricFog/Enabled

@onready var music_disabled: Button = $UI/VBox/Tabs/Audio/MusicRow/Disabled
@onready var music_enabled: Button = $UI/VBox/Tabs/Audio/MusicRow/Enabled

@onready var _rows: Array = []


func _ready() -> void:
	_rows = [
		$UI/VBox/Tabs/Display/DisplayMode,
		$UI/VBox/Tabs/Display/VSync,
		$UI/VBox/Tabs/Display/MaxFPS,
		$UI/VBox/Tabs/Resolution/ResolutionScale,
		$UI/VBox/Tabs/Resolution/ScaleFilter,
		$UI/VBox/Tabs/Antialiasing/TAA,
		$UI/VBox/Tabs/Antialiasing/MSAA,
		$UI/VBox/Tabs/Antialiasing/FXAA,
		$UI/VBox/Tabs/Lighting/ShadowMapping,
		$UI/VBox/Tabs/Lighting/GIType,
		$UI/VBox/Tabs/Lighting/GIQuality,
		$UI/VBox/Tabs/Lighting/SSAO,
		$UI/VBox/Tabs/Lighting/SSIL,
		$UI/VBox/Tabs/Effects/Bloom,
		$UI/VBox/Tabs/Effects/VolumetricFog,
		$UI/VBox/Tabs/Audio/MusicRow,
	]

	if not metalfx_supported:
		scale_filter_metalfx_spatial.hide()
		scale_filter_metalfx_temporal.hide()

	for row in _rows:
		_make_button_group(row)

	_load_current_settings()


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


func _on_back_pressed() -> void:
	emit_signal("replace_main_scene", load(MENU_PATH))


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
