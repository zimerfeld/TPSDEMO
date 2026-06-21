class_name BodyParts
extends RefCounted
## BASE dos PLANOS CORPORAIS. Classifica ossos em MEMBROS; cada plano (bípede,
## quadrúpede, rastejante) é uma SUBCLASSE que acrescenta os membros que o diferenciam.
## A base define o que é universal — CABEÇA e TRONCO — e o pipeline comum (exclusões,
## bones forçados, defaults de dano). As subclasses sobrescrevem os métodos virtuais
## (`group_of`, `members`, `label_of`, `default_sub_members`) e caem na base via `super`.
##
## Use SEMPRE uma INSTÂNCIA (via [[BodyPlans]].for_type / .default) — os métodos são
## virtuais e `BodyParts.group_of(...)` estático NÃO é polimórfico. Compartilhado pelos
## colliders de membro (limb_colliders.gd) e pelo overlay de debug 3D (debug_overlay.gd).

const HEAD := "HEAD"
const TORSO := "TORSO"

## Rótulos dos membros universais. Cada subclasse tem seu próprio `_labels()` que é
## mesclado com este (ver `label_of`).
const BASE_LABELS := {
	"HEAD": "CABEÇA",
	"TORSO": "TRONCO",
}

## Ossos auxiliares/mecânicos que NÃO viram membro principal (IK, controladores,
## placas, pistões, etc.). Podem, porém, ser PROMOVIDOS a sub-membro por modelo
## (ver standalone_part_bones em limb_colliders.gd e a tela Models).
const EXCLUDE_KEYWORDS: Array[String] = [
	"ik", "scaler", "piston", "pad", "cover", "guard", "cable", "flap",
	"dongle", "sight", "mod", "slider", "rotator", "orient", "control",
	"target", "master", "empty", "eye", "mouth", "track", "extender",
	"recoil", "booster", "fuel", "plate", "heel", "toe", "core", "aim", "dead",
]


# ── Estáticos universais (independem do plano) ────────────────────────────────

## Detecta o lado (L/R) pelo padrão do nome do osso/malha; "" se indefinido.
## Aceita prefixo "L-/R-", sufixos ".l/_l/ l" e o sufixo em MAIÚSCULA "…L/…R"
## (ex.: "ThighL", "ShinR" da criatura) — maiúscula evita falsos como "barrel".
static func side_of(raw_name: String) -> String:
	var n := raw_name.to_lower()
	if n.begins_with("l-") or n.ends_with(".l") or n.contains(".l.") \
			or n.ends_with("_l") or n.ends_with(" l") or raw_name.ends_with("L"):
		return "L"
	if n.begins_with("r-") or n.ends_with(".r") or n.contains(".r.") \
			or n.ends_with("_r") or n.ends_with(" r") or raw_name.ends_with("R"):
		return "R"
	# Palavra "left/right" (e PT esquerd/direit) em qualquer posição — para nomes como
	# "front_left_thigh"/"RearRightShin" dos quadrúpedes. Fallback após os sufixos acima.
	if n.contains("left") or n.contains("esquerd"):
		return "L"
	if n.contains("right") or n.contains("direit"):
		return "R"
	return ""


## Detecta dianteira/traseira (F/R) num nome de osso de quadrúpede; "" se indefinido.
## Usado por BodyPartsQuadruped para separar as 4 pernas. Aceita PT e EN.
static func front_rear_of(raw_name: String) -> String:
	var n := raw_name.to_lower()
	if n.contains("front") or n.contains("fore") or n.contains("dianteir") or n.contains("frente"):
		return "F"
	if n.contains("rear") or n.contains("hind") or n.contains("back") or n.contains("traseir") \
			or n.contains("tras"):
		return "R"
	return ""


# ── Virtuais (a base trata só CABEÇA/TRONCO; subclasses estendem) ─────────────

## Grupos principais que este plano define (para a tela listar/rotular). Base: cabeça+tronco.
func members() -> Array[String]:
	return [HEAD, TORSO]


## Rótulos deste plano (subclasse + base). Sobrescreva `_labels()` na subclasse.
func _labels() -> Dictionary:
	return BASE_LABELS


## Sub-membros padrão do plano (ossos salientes com collider próprio). Base: nenhum.
func default_sub_members() -> Array[String]:
	return []


## Membro-DONO provável de uma peça/sub-membro (placa, ombreira, cover…) a partir do
## NOME + lado, IGNORANDO as exclusões. Existe porque uma placa costuma ficar pendurada
## noutro osso (ex.: a ombreira "shoulderpad.L" do player é filha do "chest", não do braço),
## então subir na hierarquia a colocaria no TRONCO. O nome dela, porém, já diz a que membro
## pertence ("shoulder" → BRAÇO). A tela Models usa isto como 1ª tentativa de dono e cai na
## hierarquia só quando o nome não decide. Base: cabeça/tronco não têm peças laterais → "".
func owner_hint(_bone_name: String) -> String:
	return ""


## Multiplicador de dano padrão de um grupo: cabeça +50%, resto 1.0. Pode ser
## sobrescrito por plano (ex.: um corpo sem cabeça).
func default_multiplier(group: String) -> float:
	return 1.5 if group == HEAD else 1.0


## Nome legível do membro (CABEÇA, TRONCO, …) ou "" se desconhecido neste plano.
func label_of(group: String) -> String:
	return _labels().get(group, "")


## Retorna o grupo de membro de um osso, ou "" se não pertencer a nenhum.
## `head_bones` força certos nomes para CABEÇA e `torso_bones` para TRONCO (ambos
## ignoram as exclusões) — para personagens cujo osso principal tem nome genérico
## (ex.: red_robot, cujo corpo é o osso "Bone.001"). `leg_bones` é usado pelas
## subclasses com pernas (ignorado aqui na base).
func group_of(bone_name: String, head_bones: Array = [], torso_bones: Array = [], _leg_bones: Array = []) -> String:
	var n := bone_name.to_lower()
	for h in head_bones:
		if n == String(h).to_lower():
			return HEAD
	for t in torso_bones:
		if n == String(t).to_lower():
			return TORSO
	if _is_excluded(n):
		return ""
	if n.contains("head") or n.contains("neck"):
		return HEAD
	if n.contains("hips") or n.contains("pelvis") or n.contains("spine") \
			or n.contains("chest") or n.contains("torso") or n.contains("body"):
		return TORSO
	return ""


# ── Auxiliares para as subclasses ─────────────────────────────────────────────

## True se o nome (já em minúsculas) contém uma palavra de exclusão.
func _is_excluded(lower_name: String) -> bool:
	for ex in EXCLUDE_KEYWORDS:
		if lower_name.contains(ex):
			return true
	return false
