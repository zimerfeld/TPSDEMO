extends TemplateFormBase
## Gerenciador de Templates — personagens (`library3D/characters`), COM linha Facção. Raiz da cena
## template_manager.tscn (a linha "Facção"/nó %Factions existe nesta cena, não na de cenários).

func _manager() -> TemplateManagerBase:
	return CharacterTemplateManager


func _window_title() -> String:
	return "Gerenciador de Templates"


func _default_name() -> String:
	return "Novo template"


func _entry_kind() -> String:
	return "character"
