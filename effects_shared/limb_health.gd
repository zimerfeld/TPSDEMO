class_name LimbHealth
extends RefCounted

## HP por MEMBRO / SUB-MEMBRO de um personagem. Substitui a barra única de vida como CONDIÇÃO DE
## ABATE: o personagem só cai quando TODOS os membros contáveis estiverem destruídos.
##
## COMO O HP É REPARTIDO (decisão de projeto, 2026-08-06): cada membro contável começa com a MESMA
## fatia — `max_health / nº de membros`. A porcentagem configurada na tela Models continua sendo o
## MULTIPLICADOR DE DANO que sempre foi: um membro a 200% cai com metade dos tiros. Assim a
## configuração de dano já existente por modelo segue valendo, sem reconfigurar nada.
##
## QUEM CONTA: apenas membros/sub-membros DEFINIDOS — os que têm multiplicador próprio no LimbConfig
## e os sub-membros declarados do modelo. Peças sem configuração nenhuma ficam de fora, para um
## modelo mal configurado não virar um inimigo imortal.
##
## HIERARQUIA: destruir um membro leva junto os sub-membros dele (o BRAÇO cai com antebraço e mão).
##
## Vive no próprio personagem e é alimentado pelos colliders de membro (metas "group", "owner_group",
## "member_label" — ver [[limb-colliders]]). Como o `hit` dos personagens é `@rpc("call_local")`, todos
## os pares aplicam o mesmo dano e chegam ao mesmo estado sem replicar dicionário nenhum.

# HP mínimo de um membro: mesmo um modelo com dezenas de peças mantém cada uma abatível em poucos tiros.
const MIN_LIMB_HP := 1

# Peso da CABEÇA no reparto do HP: ela recebe esta fatia para cada 1 dos demais membros. Como um golpe
# no ROSTO (olhos/boca) derruba a cabeça inteira de uma vez, engrossá-la é o que dá valor real à mira
# precisa: no caminho difícil ela custa o dobro de acertos; pelo ponto fraco, um só. Subir este número
# encarece o headshot bruto e valoriza ainda mais o tiro certeiro.
const HEAD_HP_WEIGHT := 2.0

# group -> HP restante. Só contém os membros CONTÁVEIS (ver _is_countable).
var _hp: Dictionary = {}
# group -> rótulo exibido no overlay ("Cabeça", "Braço esquerdo"…).
var _labels: Dictionary = {}
# sub-membro -> membro dono (para o pai levar os filhos junto ao ser destruído).
var _owner_of: Dictionary = {}
# group -> HP inicial dele (a cabeça leva uma fatia maior — ver HEAD_HP_WEIGHT).
var _max_hp: Dictionary = {}


# Monta o mapa a partir dos colliders de membro já criados no personagem. `total_health` é a vida
# total do personagem, repartida igualmente entre os membros contáveis. Devolve quantos entraram.
func setup(character: Node, model_key: String, total_health: int) -> int:
	_hp.clear()
	_labels.clear()
	_owner_of.clear()
	_max_hp.clear()
	var groups: Array[String] = []
	for body in _limb_bodies(character):
		var group := String(body.get_meta("group", ""))
		if group == "" or groups.has(group):
			continue
		if not _is_countable(model_key, group, body):
			continue
		groups.append(group)
		_labels[group] = String(body.get_meta("member_label", group))
		var owner_group := String(body.get_meta("owner_group", ""))
		if owner_group != "":
			_owner_of[group] = owner_group
	if groups.is_empty():
		return 0
	# Reparto PONDERADO: a cabeça vale HEAD_HP_WEIGHT membros comuns; o total continua sendo a vida
	# do personagem, então engrossar a cabeça afina os demais na mesma medida.
	var weight_sum := 0.0
	for g in groups:
		weight_sum += _weight_of(g)
	for g in groups:
		var share: float = float(total_health) * _weight_of(g) / weight_sum
		_max_hp[g] = maxi(MIN_LIMB_HP, int(round(share)))
		_hp[g] = _max_hp[g]
	return groups.size()


# Peso de um membro no reparto do HP. Só a CABEÇA foge do peso 1 (ver HEAD_HP_WEIGHT).
func _weight_of(group: String) -> float:
	return HEAD_HP_WEIGHT if group == BodyParts.HEAD else 1.0


# Colliders de membro do personagem (StaticBody3D carimbados por LimbColliders). Ignora os de
# PREVIEW (meta "suppressed"), que não existem no gameplay.
func _limb_bodies(character: Node) -> Array[Node]:
	var out: Array[Node] = []
	for n in character.find_children("Collider_*", "StaticBody3D", true, false):
		if n.has_meta("group") and not n.has_meta("suppressed"):
			out.append(n)
	return out


# Conta todo membro/sub-membro que o modelo CONSTRÓI de fato (tem collider de gameplay). Quem não tem
# porcentagem própria no LimbConfig usa o dano padrão 1x — o que importa para o abate é a peça existir.
#
# A alternativa (contar só quem tem porcentagem configurada) foi medida no red_robot e dava 5 membros:
# os dois escudos, o tanque e as duas placas traseiras. Cabeça, tronco, braços e pernas ficavam de fora
# porque o limb_config.json dele só define `PART_FuelTank` — ou seja, acertar a cabeça não ajudaria a
# derrubar o inimigo. Contar pelo collider evita esse buraco sem exigir reconfigurar modelo por modelo.
func _is_countable(_model_key: String, _group: String, _body: Node) -> bool:
	return true


# Aplica `amount` de dano ao membro `group`. Um membro já destruído (ou não contável) ignora o golpe.
# Ao zerar, leva junto os sub-membros que pertencem a ele — e, se for um sub-membro CRÍTICO (do rosto),
# derruba também o membro-dono. Devolve `true` se ESTE golpe o destruiu.
func apply_damage(group: String, amount: int) -> bool:
	if not _hp.has(group) or int(_hp[group]) <= 0:
		return false
	_hp[group] = maxi(int(_hp[group]) - maxi(amount, 0), 0)
	if int(_hp[group]) > 0:
		return false
	_destroy(group)
	return true


# Zera `group` e propaga: os sub-membros dele caem junto (pai → filhos) e, quando `group` é um
# sub-membro CRÍTICO, o dono cai também (filho → pai) — o que por sua vez derruba os irmãos.
func _destroy(group: String) -> void:
	_hp[group] = 0
	for sub in _owner_of:
		if String(_owner_of[sub]) == group and int(_hp.get(sub, 0)) > 0:
			_destroy(sub)
	var owner_group := String(_owner_of.get(group, ""))
	if owner_group != "" and int(_hp.get(owner_group, 0)) > 0 and _is_critical(group, owner_group):
		_destroy(owner_group)


# Sub-membro CRÍTICO: peça do ROSTO (dona = CABEÇA), como olhos e boca. Destruí-la derruba a cabeça
# inteira — é o que devolve valor à mira precisa, já que a regra geral só propaga de pai para filho.
# Critério pelo DONO (e não por uma lista de nomes) para valer em qualquer modelo, em qualquer idioma.
func _is_critical(_group: String, owner_group: String) -> bool:
	return owner_group == BodyParts.HEAD


# Todos os membros contáveis destruídos? Um personagem SEM membros contáveis nunca "cai" por aqui —
# quem chama deve tratar esse caso com a vida global (ver has_limbs).
func is_defeated() -> bool:
	if _hp.is_empty():
		return false
	for g in _hp:
		if int(_hp[g]) > 0:
			return false
	return true


# Há membros contáveis? Falso = modelo sem configuração de dano; o chamador cai na vida global.
func has_limbs() -> bool:
	return not _hp.is_empty()


# Devolve todos os membros ao HP cheio (respawn do player).
func reset() -> void:
	for g in _hp:
		_hp[g] = int(_max_hp.get(g, MIN_LIMB_HP))


func has_limb(group: String) -> bool:
	return _hp.has(group)


func hp_of(group: String) -> int:
	return int(_hp.get(group, 0))


# HP CHEIO daquele membro (a cabeça tem mais que os demais) — o "máximo" da barra do overlay.
func max_hp_of(group: String) -> int:
	return int(_max_hp.get(group, 0))


func label_of(group: String) -> String:
	return String(_labels.get(group, group))


# Soma do HP restante de todos os membros — serve de "vida do corpo" para barras que mostram o total.
func total_hp() -> int:
	var sum := 0
	for g in _hp:
		sum += int(_hp[g])
	return sum


func total_max_hp() -> int:
	var sum := 0
	for g in _max_hp:
		sum += int(_max_hp[g])
	return sum
