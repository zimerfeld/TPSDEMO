class_name BodyPartsBiped
extends BodyParts
## Plano corporal BÍPEDE: além de CABEÇA/TRONCO (da base), tem 2 BRAÇOS e 2 PERNAS,
## com lado E/D pelo nome do osso. É o plano dos personagens atuais (player, red_robot)
## e o DEFAULT. "wing"/"asa" conta como BRAÇO (criaturas aladas).
##
## Reconhece nomes de osso em INGLÊS e PORTUGUÊS (os modelos chegam nos dois idiomas). As partes
## DISTAIS (antebraço/mão, canela/pé) podem virar SUB-MEMBROS automáticos (ver is_distal_sub_member);
## quando NÃO viram (opt-out do modelo, ex.: player/red_robot), caem no membro BRAÇO/PERNA como
## qualquer outro osso — preservando o hitbox inteiro já ajustado desses personagens.

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

# Palavras-chave EN+PT por segmento. ROOT = parte proximal que forma o MEMBRO grande (braço superior/
# coxa); DISTAL = extremidade que pode virar sub-membro (antebraço/mão, canela). O PÉ é tratado à parte
# (_is_foot_word), por TOKEN exato "pe"/pé — como substring "pe" apareceria em peito/perna/pescoco.
const _ARM_ROOT_KW := ["shoulder", "arm", "ombro", "braco", "braço", "wing", "asa"]
const _ARM_DISTAL_KW := ["forearm", "lowerarm", "lower_arm", "antebraco", "antebraço", "hand", "mao", "mão"]
const _LEG_ROOT_KW := ["thigh", "coxa", "knee", "joelho", "leg", "perna"]
const _LEG_DISTAL_KW := ["shin", "calf", "lowerleg", "lower_leg", "canela", "panturrilha"]


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
	# Base: head/torso forçados, exclusões, e palavras-chave head/torso (EN+PT).
	var base_g := super.group_of(bone_name, head_bones, torso_bones, leg_bones)
	if base_g != "":
		return base_g
	# Não classifique um osso EXCLUÍDO como braço/perna.
	if _is_excluded(n):
		return ""
	var side := BodyParts.side_of(bone_name)
	if side == "":
		return ""
	# BRAÇO: proximal (braço/ombro) OU distal (antebraço/mão) — ambos caem no membro BRAÇO. A
	# separação da extremidade em SUB-MEMBRO é decidida à parte (is_distal_sub_member), só quando
	# o modelo tem auto_distal ligado; aqui o distal ainda casa para o caso opt-out (membro inteiro).
	if _has_any(n, _ARM_ROOT_KW) or _has_any(n, _ARM_DISTAL_KW):
		return ARM_L if side == "L" else ARM_R
	# PERNA: proximal (coxa/perna/joelho), distal (canela) ou pé.
	if _has_any(n, _LEG_ROOT_KW) or _has_any(n, _LEG_DISTAL_KW) or _is_foot_word(bone_name):
		return LEG_L if side == "L" else LEG_R
	return ""


# Dono de uma peça pelo nome+lado, ignorando exclusões (ver BodyParts.owner_hint). MESMAS palavras
# de braço/perna do group_of (EN+PT), sem o filtro de exclusão — assim "shoulderpad.L"/"footcover.L"
# (placas que o group_of derrubaria por "pad"/"cover") já dizem o membro. É TAMBÉM como um sub-membro
# distal (antebraço/mão/canela/pé) resolve seu membro-DONO para a herança de dano. Sem lado, "".
func owner_hint(bone_name: String) -> String:
	var n := bone_name.to_lower()
	var side := BodyParts.side_of(bone_name)
	if side == "":
		return ""
	if _has_any(n, _ARM_ROOT_KW) or _has_any(n, _ARM_DISTAL_KW):
		return ARM_L if side == "L" else ARM_R
	if _has_any(n, _LEG_ROOT_KW) or _has_any(n, _LEG_DISTAL_KW) or _is_foot_word(bone_name):
		return LEG_L if side == "L" else LEG_R
	return ""


# Antebraço/mão (dono BRAÇO) e canela/pé (dono PERNA) viram sub-membro automático. Precisam de LADO
# (senão não há dono). Exclusões (pad/cover/ik…) não viram sub-membro. Ver BodyParts.is_distal_sub_member.
func is_distal_sub_member(bone_name: String) -> bool:
	var n := bone_name.to_lower()
	if _is_excluded(n):
		return false
	if BodyParts.side_of(bone_name) == "":
		return false
	if _has_any(n, _ARM_DISTAL_KW) or _has_any(n, _LEG_DISTAL_KW):
		return true
	return _is_foot_word(bone_name)


# Pé, EN+PT. "foot"/"feet" por substring; o PT "pe"/"pé" por TOKEN exato (via words_of), senão
# casaria dentro de "peito"/"perna"/"pescoco"/"pelve".
static func _is_foot_word(raw: String) -> bool:
	var n := raw.to_lower()
	if n.contains("foot") or n.contains("feet"):
		return true
	for w in BodyParts.words_of(raw):
		if w == "pe" or w == "pé":
			return true
	return false
