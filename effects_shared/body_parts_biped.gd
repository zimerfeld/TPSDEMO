class_name BodyPartsBiped
extends BodyParts
## Plano corporal BÍPEDE: além de CABEÇA/TRONCO (da base), tem 2 BRAÇOS e 2 PERNAS,
## com lado E/D pelo nome do osso. É o plano dos personagens atuais (player, red_robot)
## e o DEFAULT. "wing" conta como BRAÇO (criaturas aladas).

const ARM_L := "ARM_L"
const ARM_R := "ARM_R"
const LEG_L := "LEG_L"
const LEG_R := "LEG_R"

const LABELS := {
	"ARM_L": "BRAÇO E",
	"ARM_R": "BRAÇO D",
	"LEG_L": "PERNA E",
	"LEG_R": "PERNA D",
}


func members() -> Array[String]:
	return [HEAD, TORSO, ARM_L, ARM_R, LEG_L, LEG_R]


func _labels() -> Dictionary:
	return BASE_LABELS.merged(LABELS)


func group_of(bone_name: String, head_bones: Array = [], torso_bones: Array = [], leg_bones: Array = []) -> String:
	var n := bone_name.to_lower()
	# Pernas forçadas (ignoram exclusões): peças que o classificador descartaria, com o
	# lado vindo do nome (L-/R-). Antes do super, senão a exclusão as derrubaria.
	for l in leg_bones:
		if n == String(l).to_lower():
			match BodyParts.side_of(bone_name):
				"L": return LEG_L
				"R": return LEG_R
				_: return ""
	# Base: head/torso forçados, exclusões, e palavras-chave head/torso.
	var base_g := super.group_of(bone_name, head_bones, torso_bones, leg_bones)
	if base_g != "":
		return base_g
	# Não classifique um osso EXCLUÍDO como braço/perna.
	if _is_excluded(n):
		return ""
	var side := BodyParts.side_of(bone_name)
	if n.contains("shoulder") or n.contains("arm") or n.contains("hand") or n.contains("wing"):
		return "" if side == "" else (ARM_L if side == "L" else ARM_R)
	if n.contains("thigh") or n.contains("shin") or n.contains("calf") \
			or n.contains("knee") or n.contains("foot") or n.contains("leg"):
		return "" if side == "" else (LEG_L if side == "L" else LEG_R)
	return ""
