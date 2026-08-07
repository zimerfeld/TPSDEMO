extends Node

## Emitted by reset_to_defaults() so live UI (e.g. the System Health overlay) can react —
## the System Health panel uses it to snap back to the top-right corner.
signal settings_reset

enum GIType {
	SDFGI = 0,
	VOXEL_GI = 1,
	LIGHTMAP_GI = 2,
}

enum GIQuality {
	DISABLED = 0,
	LOW = 1,
	HIGH = 2,
}

const CONFIG_FILE_PATH = "user://settings.ini"

# MetalFX is only supported when using the Metal rendering driver.
var metalfx_supported: bool = RenderingServer.get_current_rendering_driver_name() == "metal"

# Built-in baseline tuned for common/average hardware. Used in two places: load_settings
# fills any missing key with it (so a fresh install with no config file boots on these
# values), and reset_to_defaults rewrites everything back to it (the settings "Reset"
# button). Single source of truth for "the defaults".
var DEFAULTS := {
	game = {
		# Debug 2D (tooltips de controles na tela developer). A inspeção 3D foi para a Models.
		debug_2d = false,
		# HUD de versão (build_id) no canto inferior direito — mesma string que o RoomManager usa no
		# handshake de rede (game_version), para o usuário conferir que está na mesma build dos amigos.
		hud_version = false,
		hud_fps = false,
		# 2D tooltip lines (Debug 2D column).
		show_id = false,
		show_type = false,
		show_name = false,
		# Linha "Tab" (branca): índice de Tab/foco de cada controle 2D.
		show_tab = false,
		# Linha "Path" (azul claro): caminho do controle na árvore da cena ativa — diferencia
		# controles com mesmo Type/Name.
		show_path = false,
		# Performance HUD overlay (top bar; Developer screen). The crash/freeze PROTECTION
		# is always-on via the StabilityGuard autoload and has no toggle.
		performance_hud = false,
		# UI language: "pt" (default), "en" or "es". Persisted; read by the Locale autoload.
		language = "pt",
	},
	audio = {
		music = true,
		sfx = true,
		# Volume 1–100 (%) de cada bus, ajustável pelo VolumeBar na aba Audio. 100 = 0 dB.
		music_volume = 100,
		sfx_volume = 100,
	},
	models = {
		auto_rotate = false,
		play_animation = false,
		play_audio = false,
		show_colliders = false,
		show_member_labels = false,
		show_type = false,
		show_name = false,
		show_id = false,
		show_effects = false,
	},
	video = {
		display_mode = Window.MODE_EXCLUSIVE_FULLSCREEN,
		vsync = DisplayServer.VSYNC_ENABLED,
		max_fps = 60,
		# First preset in settings.gd VIDEO_RESOLUTIONS (HD 1280 × 720) is the default.
		resolution = Vector2i(1280, 720),
		# "Equilibrado" (Balanced) na UI = 1.0 / 1.7 (ver settings.gd).
		resolution_scale = 1.0 / 1.7,
		scale_filter = Viewport.SCALING_3D_MODE_BILINEAR,
	},
	rendering = {
		taa = false,
		msaa = Viewport.MSAA_DISABLED,
		fxaa = false,
		shadow_mapping = true,
		gi_type = GIType.VOXEL_GI,
		gi_quality = GIQuality.LOW,
		# Desligado de fábrica: o ambiente dos levels já nasce sem SSAO, e a meta do projeto é 60 FPS
		# em hardware gráfico mínimo. Quem quiser o efeito liga nas configurações.
		ssao_quality = -1,
		ssil_quality = -1,  # Disabled
		bloom = false,
		volumetric_fog = false,
	},
}

var config_file := ConfigFile.new()


func _ready() -> void:
	load_settings()
	apply_audio_settings()


# Mutes/unmutes the "Music" and "SFX" audio buses from the saved settings, so they
# apply globally to every scene. "Music" carries the background music; "SFX" carries
# every non-music sound (the gameplay effects buses Outside/Reactor route into it),
# so each toggle silences its own category independently.
func apply_audio_settings() -> void:
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus != -1:
		AudioServer.set_bus_mute(music_bus, not config_file.get_value("audio", "music", true))
		AudioServer.set_bus_volume_db(music_bus, _volume_to_db(config_file.get_value("audio", "music_volume", 100)))
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		AudioServer.set_bus_mute(sfx_bus, not config_file.get_value("audio", "sfx", true))
		AudioServer.set_bus_volume_db(sfx_bus, _volume_to_db(config_file.get_value("audio", "sfx_volume", 100)))


# Converte volume 1–100 (%) em dB para o bus. 100% = 0 dB; abaixo disso atenua em escala log
# (linear→dB), espelhando como o ouvido percebe volume. Piso de 0.0001 evita -inf dB.
func _volume_to_db(percent: int) -> float:
	return linear_to_db(clampf(float(percent) / 100.0, 0.0001, 1.0))


# Resize the window to the saved video resolution, but only while windowed — a fixed
# pixel size is meaningless in (exclusive) fullscreen, so it is skipped there. Centered
# on the window's current screen. Call AFTER apply_graphics_settings (which sets the
# display mode) so the mode check below sees the saved windowed/fullscreen state.
func apply_window_resolution(window: Window) -> void:
	if window.mode != Window.MODE_WINDOWED and window.mode != Window.MODE_MAXIMIZED:
		return
	var res: Vector2i = config_file.get_value("video", "resolution", Vector2i.ZERO)
	if res.x <= 0 or res.y <= 0:
		return
	# Clamp to the usable screen so the window (and its bottom UI) never extends past
	# the monitor, then center it inside that area.
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	res.x = mini(res.x, usable.size.x)
	res.y = mini(res.y, usable.size.y)
	window.size = res
	@warning_ignore("integer_division")
	window.position = usable.position + (usable.size - res) / 2


# Overwrite every setting with the built-in DEFAULTS (the common-hardware baseline) and
# persist. Backs the settings "Reset" button; the caller is responsible for reloading
# the UI and applying the values to the live window/audio.
func reset_to_defaults() -> void:
	for section in DEFAULTS:
		for key in DEFAULTS[section]:
			config_file.set_value(section, key, DEFAULTS[section][key])
	save_settings()
	settings_reset.emit()


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"toggle_fullscreen"):
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if (!((get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN) or (get_window().mode == Window.MODE_FULLSCREEN))) else Window.MODE_WINDOWED
		get_viewport().set_input_as_handled()


func load_settings() -> void:
	config_file.load(CONFIG_FILE_PATH)
	# Initialize defaults for values not found in the existing configuration file,
	# so we don't have to specify them every time we use `ConfigFile.get_value()`.
	var needs_save := false
	for section in DEFAULTS:
		for key in DEFAULTS[section]:
			if not config_file.has_section_key(section, key):
				config_file.set_value(section, key, DEFAULTS[section][key])
				needs_save = true
	if needs_save:
		save_settings()


func save_settings() -> void:
	var err := config_file.save(CONFIG_FILE_PATH)
	if err != OK:
		push_error("Settings: failed to save '%s': %s" % [CONFIG_FILE_PATH, error_string(err)])


## True quando o modo de escala 3D é um upscaler temporal (FSR 2 / MetalFX Temporal),
## que já faz antialiasing temporal e é incompatível com TAA.
func is_temporal_upscaler(scaling_mode: int) -> bool:
	return scaling_mode == Viewport.SCALING_3D_MODE_FSR2 \
		or scaling_mode == Viewport.SCALING_3D_MODE_METALFX_TEMPORAL


func apply_graphics_settings(window: Window, environment: Environment, scene_root: Node) -> void:
	get_window().mode = Settings.config_file.get_value("video", "display_mode")
	DisplayServer.window_set_vsync_mode(Settings.config_file.get_value("video", "vsync"))
	Engine.max_fps = Settings.config_file.get_value("video", "max_fps")
	window.scaling_3d_scale = Settings.config_file.get_value("video", "resolution_scale")
	window.scaling_3d_mode = Settings.config_file.get_value("video", "scale_filter")

	# FSR 2 e MetalFX Temporal já são upscalers temporais e são incompatíveis com TAA — a engine
	# desligaria o TAA internamente e emitiria warning. Garantimos a exclusividade aqui.
	window.use_taa = Settings.config_file.get_value("rendering", "taa") and not is_temporal_upscaler(window.scaling_3d_mode)
	window.msaa_3d = Settings.config_file.get_value("rendering", "msaa")
	window.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if Settings.config_file.get_value("rendering", "fxaa") else Viewport.SCREEN_SPACE_AA_DISABLED

	if not Settings.config_file.get_value("rendering", "shadow_mapping"):
		# Disable shadows for all lights present during level load,
		# reducing the number of draw calls significantly.
		# FIXME: In the main menu, shadows aren't enabled again after enabling shadows
		# if they were previously disabled. We can't enable shadows on all lights unconditionally,
		# as this would negatively affect the level's performance.
		scene_root.propagate_call("set", ["shadow_enabled", false])

	# O 2º teste era `if` (não `elif`), então "Desligado" (-1) caía no `else` e RELIGAVA o SSAO — e o
	# mapeamento estava trocado (Média pedia HIGH em resolução cheia, o mais caro dos três). Ninguém
	# conseguia desligar o efeito mais caro da lista. Espelha agora a cadeia do SSIL logo abaixo.
	if Settings.config_file.get_value("rendering", "ssao_quality") == -1:
		environment.ssao_enabled = false
	elif Settings.config_file.get_value("rendering", "ssao_quality") == RenderingServer.ENV_SSAO_QUALITY_MEDIUM:
		environment.ssao_enabled = true
		RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50, 300)
	elif Settings.config_file.get_value("rendering", "ssao_quality") == RenderingServer.ENV_SSAO_QUALITY_HIGH:
		environment.ssao_enabled = true
		RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_HIGH, false, 0.5, 2, 50, 300)
	else:
		environment.ssao_enabled = false   # valor desconhecido: fica no barato

	if Settings.config_file.get_value("rendering", "ssil_quality") == -1:
		environment.ssil_enabled = false
	elif Settings.config_file.get_value("rendering", "ssil_quality") == RenderingServer.ENV_SSIL_QUALITY_MEDIUM:
		environment.ssil_enabled = true
		RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_MEDIUM, false, 0.5, 2, 50, 300)
	else:
		environment.ssil_enabled = true
		RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_HIGH, true, 0.5, 2, 50, 300)

	environment.glow_enabled = Settings.config_file.get_value("rendering", "bloom")
	environment.volumetric_fog_enabled = Settings.config_file.get_value("rendering", "volumetric_fog")
