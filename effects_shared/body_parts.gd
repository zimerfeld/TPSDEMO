class_name BodyParts
extends RefCounted
## Classificação de ossos em MEMBROS (CABEÇA, TRONCO, BRAÇO E/D, PERNA E/D).
## Compartilhado pelos colliders de membro (limb_colliders.gd) e pelo overlay de
## debug 3D (debug_overlay.gd), para que ambos usem o MESMO mapeamento.

const HEAD := "HEAD"
const TORSO := "TORSO"
const ARM_L := "ARM_L"
const ARM_R := "ARM_R"
const LEG_L := "LEG_L"
const LEG_R := "LEG_R"

const LABELS := {
	"HEAD": "CABEÇA",
	"TORSO": "TRONCO",
	"ARM_L": "BRAÇO E",
	"ARM_R": "BRAÇO D",
	"LEG_L": "PERNA E",
	"LEG_R": "PERNA D",
}

## Ossos auxiliares/mecânicos que NÃO devem virar membro (IK, controladores,
## placas, pistões, etc.).
const EXCLUDE_KEYWORDS: Array[String] = [
	"ik", "scaler", "piston", "pad", "cover", "guard", "cable", "flap",
	"dongle", "sight", "mod", "slider", "rotator", "orient", "control",
	"target", "master", "empty", "eye", "mouth", "track", "extender",
	"recoil", "booster", "fuel", "plate", "heel", "toe", "core", "aim", "dead",
]


## Retorna o grupo de membro de um osso, ou "" se não pertencer a nenhum.
## `head_bones` força certos nomes para CABEÇA e `torso_bones` para TRONCO
## (ambos ignoram as exclusões) — usados por personagens cujo osso principal tem
## nome genérico (ex.: red_robot, cujo corpo é o osso "Bone.001").
static func group_of(bone_name: String, head_bones: Array = [], torso_bones: Array = []) -> String:
	var n := bone_name.to_lower()
	for h in head_bones:
		if n == String(h).to_lower():
			return HEAD
	for t in torso_bones:
		if n == String(t).to_lower():
			return TORSO
	for ex in EXCLUDE_KEYWORDS:
		if n.contains(ex):
			return ""

	if n.contains("head") or n.contains("neck"):
		return HEAD
	if n.contains("hips") or n.contains("pelvis") or n.contains("spine") \
			or n.contains("chest") or n.contains("torso") or n.contains("body"):
		return TORSO

	var side := side_of(bone_name)
	# "wing" conta como BRAÇO: nas criaturas aladas (criatura_alada, robot_*_alado)
	# as asas são os apêndices superiores e devem receber collider de membro.
	if n.contains("shoulder") or n.contains("arm") or n.contains("hand") or n.contains("wing"):
		if side == "":
			return ""
		return ARM_L if side == "L" else ARM_R
	if n.contains("thigh") or n.contains("shin") or n.contains("calf") \
			or n.contains("knee") or n.contains("foot") or n.contains("leg"):
		if side == "":
			return ""
		return LEG_L if side == "L" else LEG_R
	return ""


## Nome legível do membro (CABEÇA, BRAÇO D, …) ou "" se desconhecido.
static func label_of(group: String) -> String:
	return LABELS.get(group, "")


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
	return ""
