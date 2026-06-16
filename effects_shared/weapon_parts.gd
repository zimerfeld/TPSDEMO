class_name WeaponParts
extends RefCounted
## Classificação de nós de malha de ARMAS em MEMBROS (CANO, CORPO, CABO, CORONHA,
## CARREGADOR, MIRA, GATILHO). Espelha BodyParts (personagens), para o navegador de
## modelos detectar membros, montar colliders e exibir tooltips também nas armas.

const BARREL := "BARREL"
const BODY := "BODY"
const GRIP := "GRIP"
const STOCK := "STOCK"
const MAG := "MAG"
const SIGHT := "SIGHT"
const TRIGGER := "TRIGGER"

const LABELS := {
	"BARREL": "CANO",
	"BODY": "CORPO",
	"GRIP": "CABO",
	"STOCK": "CORONHA",
	"MAG": "CARREGADOR",
	"SIGHT": "MIRA",
	"TRIGGER": "GATILHO",
}

## Palavras de partes puramente decorativas/efêmeras que NÃO viram membro.
const EXCLUDE_KEYWORDS: Array[String] = [
	"flash", "muzzleflash", "glow", "ring", "olho", "eye", "light", "fx",
	"emitter", "particle", "decal", "top", "core",
]


## Retorna o grupo de membro de uma arma para o nó, ou "" se não pertencer.
static func group_of(node_name: String) -> String:
	var n := node_name.to_lower()
	for ex in EXCLUDE_KEYWORDS:
		if n.contains(ex):
			return ""
	# "muzzle" sozinho (boca do cano) conta como CANO; "muzzleflash" já foi excluído.
	if n.contains("cano") or n.contains("barrel") or n.contains("muzzle"):
		return BARREL
	if n.contains("coronha") or n.contains("stock") or n.contains("butt"):
		return STOCK
	if n.contains("carregador") or n.contains("magazine") or n.contains("clip") or n == "mag":
		return MAG
	if n.contains("mira") or n.contains("sight") or n.contains("scope"):
		return SIGHT
	if n.contains("gatilho") or n.contains("trigger"):
		return TRIGGER
	if n.contains("cabo") or n.contains("grip") or n.contains("handle") or n.contains("punho"):
		return GRIP
	if n.contains("corpo") or n.contains("body") or n.contains("receiver") or n.contains("frame"):
		return BODY
	return ""


## Nome legível do membro (CANO, CORPO, …) ou "" se desconhecido.
static func label_of(group: String) -> String:
	return LABELS.get(group, "")
