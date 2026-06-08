extends CanvasLayer

## Assembled cyberpunk HUD, built entirely from the reusable controls in
## res://controls2D/*. Each sub-widget auto-binds to a /root/GameState
## autoload if one is present; otherwise drive them via the accessors below
## (e.g. vitals.set_health(...), credits.set_credits(...), log_feed.push_message(...)).
##
## A short fade-in on _ready mirrors the original demo HUD.

@onready var vitals: PanelContainer = $ThemeRoot/VitalsPanel
@onready var minimap: PanelContainer = $ThemeRoot/MinimapPanel
@onready var abilities: HBoxContainer = $ThemeRoot/AbilityBar
@onready var credits: PanelContainer = $ThemeRoot/CreditsPanel
@onready var log_feed: VBoxContainer = $ThemeRoot/LogFeed
@onready var crosshair: Control = $ThemeRoot/Crosshair
@onready var pause_menu: Control = $ThemeRoot/PauseMenu

func _ready() -> void:
	var root := $ThemeRoot as Control
	root.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(root, "modulate", Color.WHITE, 0.6)
