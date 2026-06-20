class_name BodyPartsQuadruped
extends BodyParts
## Plano corporal QUADRÚPEDE: além de CABEÇA/TRONCO (da base), tem 4 PERNAS —
## dianteira/traseira × esquerda/direita. Sem braços. O lado vem de `side_of` e o
## par dianteiro/traseiro de `front_rear_of` (front/fore/dianteira vs rear/hind/traseira).

const LEG_FL := "LEG_FL"  # front left
const LEG_FR := "LEG_FR"  # front right
const LEG_RL := "LEG_RL"  # rear left
const LEG_RR := "LEG_RR"  # rear right

const LABELS := {
	"LEG_FL": "PERNA DIANT E",
	"LEG_FR": "PERNA DIANT D",
	"LEG_RL": "PERNA TRAS E",
	"LEG_RR": "PERNA TRAS D",
}


func members() -> Array[String]:
	return [HEAD, TORSO, LEG_FL, LEG_FR, LEG_RL, LEG_RR]


func _labels() -> Dictionary:
	return BASE_LABELS.merged(LABELS)


func group_of(bone_name: String, head_bones: Array = [], torso_bones: Array = [], leg_bones: Array = []) -> String:
	var n := bone_name.to_lower()
	# Pernas forçadas (ignoram exclusões): par dianteiro/traseiro + lado pelo nome.
	for l in leg_bones:
		if n == String(l).to_lower():
			return _leg_group(bone_name)
	var base_g := super.group_of(bone_name, head_bones, torso_bones, leg_bones)
	if base_g != "":
		return base_g
	if _is_excluded(n):
		return ""
	if n.contains("thigh") or n.contains("shin") or n.contains("calf") \
			or n.contains("knee") or n.contains("foot") or n.contains("paw") or n.contains("leg"):
		return _leg_group(bone_name)
	return ""


# Mapeia um osso de perna para LEG_F?/R? combinando dianteira/traseira + lado.
# "" se faltar algum dos dois (sem como decidir a perna).
func _leg_group(bone_name: String) -> String:
	var fr := BodyParts.front_rear_of(bone_name)
	var side := BodyParts.side_of(bone_name)
	if fr == "" or side == "":
		return ""
	if fr == "F":
		return LEG_FL if side == "L" else LEG_FR
	return LEG_RL if side == "L" else LEG_RR
