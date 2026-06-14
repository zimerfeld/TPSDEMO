extends Node

signal replace_main_scene(resource: PackedScene)

const MENU_PATH: String = "res://scenes2D/menu/menu.tscn"
const STATUS_TEXT: String = "SINCRONIZANDO ARENA DE TREINO"

@export_range(1.0, 10.0, 0.1) var minimum_wait_time: float = 2.0
@export_range(0.1, 5.0, 0.05) var fade_out_time: float = 0.35
@export_range(40.0, 600.0, 10.0) var sweep_speed: float = 210.0

@onready var hold_timer: Timer = $HoldTimer
@onready var ui: Control = $Layer/UI
@onready var title_block: VBoxContainer = $Layer/UI/TitleBlock
@onready var hero_frame: Control = $Layer/UI/HeroFrame
@onready var hero_mask: Control = $Layer/UI/HeroFrame/HeroMask
@onready var reticle_large: Control = $Layer/UI/HeroFrame/HeroMask/ReticleLarge
@onready var reticle_small: Control = $Layer/UI/HeroFrame/HeroMask/ReticleSmall
@onready var sweep_line: ColorRect = $Layer/UI/HeroFrame/HeroMask/SweepLine
@onready var status_label: Label = $Layer/UI/StatusFrame/StatusLabel
@onready var boot_flash: ColorRect = $Layer/UI/BootFlash

var _elapsed: float = 0.0
var _title_origin: Vector2
var _hero_origin: Vector2


func _ready() -> void:
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_origin = title_block.position
	_hero_origin = hero_frame.position
	title_block.position = _title_origin + Vector2(-28.0, 0.0)
	hero_frame.position = _hero_origin + Vector2(42.0, 0.0)
	title_block.modulate.a = 0.0
	hero_frame.modulate.a = 0.0
	status_label.modulate.a = 0.0
	boot_flash.color = Color(0.88, 0.96, 1.0, 0.85)
	hold_timer.wait_time = minimum_wait_time
	hold_timer.start()
	_play_intro()


func _process(delta: float) -> void:
	_elapsed += delta

	var dot_count: int = int(floor(_elapsed * 3.0)) % 4
	status_label.text = STATUS_TEXT + ".".repeat(dot_count)
	sweep_line.position.y = fposmod(_elapsed * sweep_speed, hero_mask.size.y + 120.0) - 60.0

	reticle_large.modulate.a = 0.22 + (sin(_elapsed * 2.1) + 1.0) * 0.11
	reticle_large.scale = Vector2.ONE * (1.12 + sin(_elapsed * 1.5) * 0.04)
	reticle_small.modulate.a = 0.18 + (sin(_elapsed * 2.9) + 1.0) * 0.08
	reticle_small.rotation = sin(_elapsed * 0.9) * 0.08


func _play_intro() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(boot_flash, "color", Color(0.88, 0.96, 1.0, 0.0), 0.45)
	tween.tween_property(title_block, "modulate:a", 1.0, 0.55)
	tween.tween_property(title_block, "position", _title_origin, 0.55)
	tween.tween_property(hero_frame, "modulate:a", 1.0, 0.7)
	tween.tween_property(hero_frame, "position", _hero_origin, 0.7)
	tween.tween_property(status_label, "modulate:a", 1.0, 0.55).set_delay(0.22)


func _on_hold_timer_timeout() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ui, "modulate:a", 0.0, fade_out_time)
	tween.tween_property(hero_frame, "scale", Vector2(0.985, 0.985), fade_out_time)
	tween.tween_property(boot_flash, "color", Color(0.88, 0.96, 1.0, 0.18), fade_out_time * 0.6).set_delay(fade_out_time * 0.25)
	tween.finished.connect(_go_to_menu, CONNECT_ONE_SHOT)


func _go_to_menu() -> void:
	emit_signal("replace_main_scene", load(MENU_PATH))
