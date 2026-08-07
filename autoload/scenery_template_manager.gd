extends TemplateManagerBase
## Gerenciador de Cenários (`library3D/sceneries`) — objetos de palco, SEM facção. Persiste em
## `user://scenery_templates.json`. Ver [[sistemas/templates-de-level]].

const FILE := "user://scenery_templates.json"
const ROOT := "res://library3D/sceneries"


func _file_path() -> String:
	return FILE


func root_dir() -> String:
	return ROOT


func _entry_kind() -> String:
	return "scenery"


func _legacy_active_key() -> String:
	return "active_scenery_by_level"


# Do arquivo legado, herda só os templates de categoria "scenery".
func _matches_legacy(raw: Dictionary) -> bool:
	return String(raw.get("category", "spawn")) == "scenery"

# Sem defaults de fábrica: um projeto novo começa sem cenários (só personagens têm exemplo).


# Requisito desta categoria: a peça precisa do contrato completo do SceneryPiece (script + sincronizador
# de spawn com as três properties). Peças são estáticas — se o transform não vier no pacote de spawn,
# nada o corrige depois e a peça fica em (0,0,0) no cliente para sempre.
func _node_contract_issues(root: Node) -> PackedStringArray:
	return SceneryPiece.contract_issues(root)
