class_name BodyPlans
extends RefCounted
## Factory dos planos corporais: entrega a INSTÂNCIA de [[BodyParts]] certa por
## `body_type`. Isolado das classes para evitar acoplamento base↔subclasse (a base
## não referencia as subclasses → sem ciclo de `extends`). Use isto sempre que
## precisar classificar ossos polimorficamente (limb_colliders.gd, models.gd,
## debug_overlay.gd) — `BodyParts.group_of(...)` estático NÃO é polimórfico.

## Tipos válidos para o @export `body_type` (LimbColliders) e o mapa do browser.
const TYPES: Array[String] = ["biped", "quadruped", "crawler"]


## Instância do plano para um `body_type`; default BÍPEDE para valor vazio/desconhecido.
static func for_type(body_type: String) -> BodyParts:
	match body_type:
		"quadruped": return BodyPartsQuadruped.new()
		"crawler": return BodyPartsCrawler.new()
		_: return BodyPartsBiped.new()


## Plano default (bípede) — para quem não sabe o tipo (ex.: overlay de debug sobre
## esqueletos quaisquer de fase).
static func default() -> BodyParts:
	return BodyPartsBiped.new()
