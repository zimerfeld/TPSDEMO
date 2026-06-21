extends Node
## PerformanceHUD — overlay GLOBAL de indicadores de performance (barra no topo da tela).
##
## Cria um CanvasLayer (acima de tudo) com a barra performance_bar.gd e mostra/esconde
## conforme o toggle "HUD de Performance" da tela Developer (config "game/performance_hud").
## Substitui o antigo SystemHealth como leitor de métricas; a PROTEÇÃO (pausa/throttle) é do
## autoload StabilityGuard, cujo estado a barra exibe num badge. Registrado como autoload
## "PerformanceHUD"; a tela Developer chama PerformanceHUD.refresh() ao alternar o toggle.

const _BAR_SCRIPT := preload("res://scenes2D/overlays/performance_bar.gd")

var _canvas: CanvasLayer = null
var _bar: Control = null


func _ready() -> void:
	# Keep updating even while the tree is paused (e.g. during a StabilityGuard pause).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = CanvasLayer.new()
	_canvas.name = "PerformanceHUDCanvas"
	_canvas.layer = 99
	_canvas.visible = _is_on()
	add_child(_canvas)

	_bar = _BAR_SCRIPT.new()
	_bar.name = "PerformanceBar"
	_bar.process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas.add_child(_bar)


func _is_on() -> bool:
	return Settings.config_file.get_value("game", "performance_hud", false)


# Show/hide the overlay to match the saved setting (called by the Developer toggle).
func refresh() -> void:
	if is_instance_valid(_canvas):
		_canvas.visible = _is_on()
