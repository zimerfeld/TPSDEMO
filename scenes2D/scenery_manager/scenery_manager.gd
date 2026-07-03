extends TemplateFormBase
## Gerenciador de Cenários — objetos de palco (`library3D/sceneries`), SEM linha Facção. Raiz da
## cena scenery_manager.tscn (não há nó %Factions aqui; a base detecta a ausência e omite a facção).

func _manager() -> TemplateManagerBase:
	return SceneryTemplateManager


func _window_title() -> String:
	return "Gerenciador de Cenários"


func _default_name() -> String:
	return "Novo cenário"


func _entry_kind() -> String:
	return "scenery"
