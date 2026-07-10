class_name Factions
extends RefCounted

## Facção em RUNTIME, por-instância e mutável — a "de que lado este NÓ está" no combate.
##
## Diferente de [AIConfig] (facção por-MODELO, estática, persistida em JSON), aqui a facção é lida e
## alterada por-nó em tempo de jogo, via metadados do próprio nó. É o que permite:
##   • sem fogo amigo — a mesma facção não se fere (ver [method can_damage]);
##   • targeting por lado — inimigos miram a facção OPOSTA (ver [method are_enemies]);
##   • neutros dinâmicos — um neutro atingido por um lado alinha-se contra o atacante,
##     temporariamente (ver [method note_damage] / [method _provoke]).
##
## Resolução de [method of] (precedência): override temporário (neutro provocado) → colocação por
## template (meta "template_faction") → facção-base semeada de [AIConfig] no _ready (meta "faction")
## → inferência pelos métodos do nó. Tudo server-autoritativo: só o servidor aplica dano e escolhe
## alvo, então basta a facção existir no servidor (clientes apenas renderizam).

const AIConfigLib := preload("res://effects_shared/ai_config.gd")

const HOSTILE := "hostile"
const ALLY := "ally"
const NEUTRAL := "neutral"

const _META_BASE := "faction"                   # facção-base (semeada de AIConfig no _ready)
const _META_OVERRIDE := "faction_override"       # facção temporária (neutro provocado)
const _META_OVERRIDE_UNTIL := "faction_override_until"  # instante (ms) em que o override expira

## Quanto tempo (ms) um neutro fica alinhado após ser atingido, antes de voltar a neutro.
const PROVOKE_DURATION_MS := 8000.0


## Semeia a facção-base do nó a partir do [AIConfig] do modelo (uma leitura no _ready). A colocação
## por template (meta "template_faction") continua tendo precedência em [method base_of].
static func seed_node(node: Node, model_key: String) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_meta(_META_BASE, AIConfigLib.faction(model_key))


## Facção-base do nó (ignora o override temporário): template > semeada > inferida.
static func base_of(node) -> String:
	if node == null or not is_instance_valid(node):
		return NEUTRAL
	if node.has_meta("template_faction"):
		var mapped := _from_template(String(node.get_meta("template_faction")))
		if mapped != "":
			return mapped
	if node.has_meta(_META_BASE):
		return String(node.get_meta(_META_BASE))
	return _infer(node)


## Facção EFETIVA do nó agora — o override de um neutro provocado tem precedência enquanto ativo.
static func of(node) -> String:
	if node == null or not is_instance_valid(node):
		return NEUTRAL
	if node.has_meta(_META_OVERRIDE_UNTIL):
		if float(Time.get_ticks_msec()) < float(node.get_meta(_META_OVERRIDE_UNTIL)):
			return String(node.get_meta(_META_OVERRIDE))
		node.remove_meta(_META_OVERRIDE)
		node.remove_meta(_META_OVERRIDE_UNTIL)
	return base_of(node)


## `a` e `b` são de lados OPOSTOS (um hostil, outro aliado). Neutro não é inimigo de ninguém.
static func are_enemies(a, b) -> bool:
	var fa := of(a)
	var fb := of(b)
	if fa == NEUTRAL or fb == NEUTRAL:
		return false
	return fa != fb


## `a` e `b` são do MESMO lado (ambos hostis ou ambos aliados). Neutro não compartilha lado.
static func same_side(a, b) -> bool:
	var fa := of(a)
	var fb := of(b)
	if fa == NEUTRAL or fb == NEUTRAL:
		return false
	return fa == fb


## Se `attacker` pode causar dano em `target`. Puro (sem efeito colateral): um NEUTRO sempre pode ser
## atingido (e será alinhado por [method note_damage] quando o dano de fato ocorrer); de resto, só há
## dano entre lados opostos → nunca fogo amigo dentro da mesma facção.
static func can_damage(attacker, target) -> bool:
	if target == null or not is_instance_valid(target) or target == attacker:
		return false
	if base_of(target) == NEUTRAL:
		return true
	return are_enemies(attacker, target)


## Registra que o dano de `attacker` de fato atingiu `target`. Se o alvo for um NEUTRO, provoca-o:
## atingido por ALIADO → vira HOSTIL; atingido por HOSTIL → vira ALIADO. Temporário (reverte sozinho).
static func note_damage(attacker, target) -> void:
	if target == null or not is_instance_valid(target):
		return
	if base_of(target) == NEUTRAL:
		_provoke(target, attacker)


static func _provoke(target: Node, attacker) -> void:
	var new_faction := ""
	match of(attacker):
		ALLY:
			new_faction = HOSTILE
		HOSTILE:
			new_faction = ALLY
		_:
			return  # atacante neutro/desconhecido não define um lado a alinhar contra
	target.set_meta(_META_OVERRIDE, new_faction)
	target.set_meta(_META_OVERRIDE_UNTIL, float(Time.get_ticks_msec()) + PROVOKE_DURATION_MS)


static func _from_template(template_faction: String) -> String:
	match template_faction:
		"enemy":
			return HOSTILE
		"friendly":
			return ALLY
		"neutral":
			return NEUTRAL
	return ""


# Fallback quando o nó nunca foi semeado: player-like (leva shake de câmera) = aliado; entidade com
# HUD de vida de inimigo = hostil; o resto, neutro.
static func _infer(node) -> String:
	if node.has_method(&"add_camera_shake_trauma") and node.has_method(&"hit"):
		return ALLY
	if node.has_method(&"show_health_hud") and node.has_method(&"hit"):
		return HOSTILE
	return NEUTRAL
