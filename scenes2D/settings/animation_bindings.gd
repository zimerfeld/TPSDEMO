class_name AnimationBindings
extends RefCounted
## Atalhos de ANIMAÇÃO do personagem (seção "Animações" da aba Controles).
##
## A lista NÃO é escrita à mão: vem das animações do próprio modelo humanoide, lidas do `.glb`. Assim,
## trocar o modelo ou acrescentar um clipe no Blender já reflete na tela, sem tocar em código. São as
## 36 animações do rig de 16 ossos em português (`ocioso`, `andar`, `correr`, `saltar`, `rolar_frente`,
## `atirar_dir_1x`, `defender_esq`…) — o mesmo banco que o FIGArtStudio usa como referência.
##
## Persistência em `Settings.config_file`, seção `anim_bindings`: só o que o jogador mudou. As
## animações que correspondem a uma ação de movimento já existente herdam a tecla dela como PADRÃO
## (ver DEFAULT_FROM_ACTION), então andar/correr/saltar/atirar nascem coerentes com os controles.

## Modelo de referência das animações. É o `humanoide` porque é o rig completo do projeto (36 clipes);
## `jogador7` e `monstro_pedregulho3` compartilham o mesmo vocabulário.
const MODEL_PATH := "res://library3D/characters/humanoide/humanoide3.glb"

const SECTION := "anim_bindings"

## Animação → ação cuja tecla ela herda quando o jogador não definiu nada. Cobre a MOVIMENTAÇÃO
## (pedido da demanda) e o disparo; o resto nasce sem atalho, para o jogador escolher.
##
## `defender_*` de propósito FORA da lista: o botão direito é a mira (liga/desliga), não a defesa —
## herdar dela faria o mesmo botão significar duas coisas diferentes.
const DEFAULT_FROM_ACTION := {
	"andar": "move_forward",
	"correr": "move_forward",
	"saltar": "jump",
	"atirar_dir_1x": "shoot",
	"atirar_esq_1x": "shoot",
}

# Lista lida do .glb uma vez por sessão (abrir o modelo custa; a tela pode ser reaberta várias vezes).
static var _names: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


## Todas as animações do modelo de referência, em ordem alfabética. Vazio se o modelo não existir
## (a seção da tela simplesmente não aparece).
static func animation_names() -> PackedStringArray:
	if _loaded:
		return _names
	_loaded = true
	_names = PackedStringArray()
	if not ResourceLoader.exists(MODEL_PATH):
		push_warning("AnimationBindings: modelo de animações não encontrado em %s" % MODEL_PATH)
		return _names
	var packed: PackedScene = load(MODEL_PATH)
	if packed == null:
		return _names
	# `instantiate()` monta a malha inteira só para ler os nomes; é o preço de não manter uma lista
	# duplicada em código. Roda uma vez por sessão e o nó é liberado em seguida.
	var root := packed.instantiate()
	for node in root.find_children("*", "AnimationPlayer", true, false):
		for anim in (node as AnimationPlayer).get_animation_list():
			var name := String(anim)
			if not _names.has(name):
				_names.append(name)
	root.free()
	_names.sort()
	return _names


## Evento ligado a uma animação: o escolhido pelo jogador ou, na falta dele, o da ação-padrão
## correspondente. Null quando a animação não tem atalho.
static func event_for(animation: String) -> InputEvent:
	# Dicionário VAZIO é o sentinela de "não salvo" (o ConfigFile trata `null` como ausência de
	# default e reclama no console) — só um dicionário preenchido conta como escolha do jogador.
	var saved: Variant = Settings.config_file.get_value(SECTION, animation, {})
	if saved is Dictionary and not (saved as Dictionary).is_empty():
		return InputBindings.data_to_event(saved)
	if DEFAULT_FROM_ACTION.has(animation):
		return InputBindings.current_event(String(DEFAULT_FROM_ACTION[animation]))
	return null


## True se a animação usa o padrão herdado (nada salvo pelo jogador).
static func is_default(animation: String) -> bool:
	return not Settings.config_file.has_section_key(SECTION, animation)


## Grava o atalho de uma animação.
static func set_binding(animation: String, event: InputEvent) -> void:
	if not InputBindings.is_supported(event):
		return
	Settings.config_file.set_value(SECTION, animation, InputBindings.event_to_data(event))
	Settings.save_settings()


## Devolve a animação ao padrão (herdado da ação, ou sem atalho).
static func reset_binding(animation: String) -> void:
	if Settings.config_file.has_section_key(SECTION, animation):
		Settings.config_file.erase_section_key(SECTION, animation)
		Settings.save_settings()


## Limpa TODOS os atalhos de animação (usado pelo Reset geral).
static func reset_all() -> void:
	for animation in animation_names():
		if Settings.config_file.has_section_key(SECTION, animation):
			Settings.config_file.erase_section_key(SECTION, animation)
	Settings.save_settings()


## Animações que a MÁQUINA DE ESTADOS do personagem já toca sozinha (ver a árvore de animação da
## cena). Elas aparecem na tela e podem ser remapeadas, mas NÃO viram gesto: dispará-las por cima da
## locomoção brigaria com o próprio andar — o WSAD continua sendo do movimento.
const LOCOMOTION := ["ocioso", "andar", "correr", "saltar"]


## True se a animação é da locomoção (tocada pelo movimento, não por gesto).
static func is_locomotion(animation: String) -> bool:
	return LOCOMOTION.has(animation)


## Animação ligada a este evento, ou "" — é por aqui que o gameplay consulta o que tocar quando uma
## tecla é pressionada.
static func animation_for_event(event: InputEvent) -> String:
	for animation in animation_names():
		var bound := event_for(animation)
		if bound != null and InputBindings.same_event(bound, event):
			return animation
	return ""

