class_name BodyParts
extends RefCounted
## Classificação de ossos em MEMBROS (CABEÇA, TRONCO, BRAÇO E/D, PERNA E/D).
## Compartilhado pelas hitboxes de vidro (glass_hitboxes.gd) e pelo overlay de
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
## `head_bones` força certos nomes para CABEÇA (ignora exclusões).
static func group_of(bone_name: String, head_bones: Array = []) -> String:
	var n := bone_name.to_lower()
	for h in head_bones:
		if n == String(h).to_lower():
			return HEAD
	for ex in EXCLUDE_KEYWORDS:
		if n.contains(ex):
			return ""

	if n.contains("head") or n.contains("neck"):
		return HEAD
	if n.contains("hips") or n.contains("pelvis") or n.contains("spine") \
			or n.contains("chest") or n.contains("torso") or n.contains("body"):
		return TORSO

	var side := side_of(n)
	if n.contains("shoulder") or n.contains("arm") or n.contains("hand"):
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


## Detecta o lado (L/R) pelo padrão do nome do osso; "" se indefinido.
static func side_of(n: String) -> String:
	if n.begins_with("l-") or n.ends_with(".l") or n.contains(".l.") or n.ends_with("_l"):
		return "L"
	if n.begins_with("r-") or n.ends_with(".r") or n.contains(".r.") or n.ends_with("_r"):
		return "R"
	return ""
