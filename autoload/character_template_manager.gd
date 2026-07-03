extends TemplateManagerBase
## Gerenciador de Templates de personagens (`library3D/characters`) — com facção. Persiste em
## `user://character_templates.json`. Ver [[sistemas/templates-de-level]].

const FILE := "user://character_templates.json"
const ROOT := "res://library3D/characters"


func _file_path() -> String:
	return FILE


func root_dir() -> String:
	return ROOT


func _entry_kind() -> String:
	return "character"


func _legacy_active_key() -> String:
	return "active_by_level"


# Do arquivo legado, herda tudo que NÃO era cenário (categoria "spawn" ou ausente).
func _matches_legacy(raw: Dictionary) -> bool:
	return String(raw.get("category", "spawn")) != "scenery"


func _install_defaults() -> void:
	templates = [
		{
			"id": "default_level_2_air_support",
			"name": "Level 2 - Caça aérea",
			"level_path": "res://scenes3D/level_2/level_2.tscn",
			"entries": [
				{"kind": "character", "faction": "enemy", "model_key": "criatura_alada", "scene_path": "res://library3D/characters/criatura_alada/criatura_alada.tscn", "placement": "random", "random_center": [18, 1, 0], "random_size": [18, 0, 18], "count": 2},
				{"kind": "character", "faction": "friendly", "model_key": "player", "scene_path": "res://library3D/characters/player/player.tscn", "placement": "formation", "formation": "line", "formation_origin": [-10, 1, -4], "count": 1, "spacing": 4.0}
			]
		}
	]
	save()
