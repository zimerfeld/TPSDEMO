class_name SceneryPiece
extends Node3D
## Peça de CENÁRIO (objeto de palco estático) que nasce nas MESMAS coordenadas nos dois lados da rede.
##
## O MultiplayerSpawner só transmite QUAL cena instanciar — o `position`/`rotation`/`scale` que o
## servidor aplica depois do `instantiate()` NÃO viaja no pacote. Sem isto, as peças materializadas
## pelo template (ver [[SceneryTemplateManager]]) chegavam ao cliente em (0,0,0), todas empilhadas na
## origem, e ficavam lá para sempre: por serem estáticas, nada replicava o transform depois do spawn
## (os personagens escapavam porque replicam `net_transform`/`spawn_position` continuamente).
##
## A solução é a mesma do player (ver `spawn_position` em player.gd): declarar o transform como
## PROPERTIES DE SPAWN, entregues dentro do próprio pacote de criação do nó. O ServerSynchronizer de
## cada peça as replica com `replication_mode = 0` (só no spawn) — depois disso não há tráfego algum,
## que é o certo para um corpo que nunca se move.
##
## Quem preenche estes valores é o `_spawn_job` do TemplateManagerBase, ANTES do `add_child` (só assim
## eles entram no pacote de spawn).
##
## O `replication_mode` SÓ-SPAWN vale porque a peça é ESTÁTICA: seu estado inicial é tudo que existe.
## Se uma peça passar a ter algo DINÂMICO (mover-se, abrir/fechar, tomar dano, mudar de material), esse
## dado precisa entrar no `replication_config` com replicação contínua — senão os clientes já conectados
## continuariam vendo o estado antigo. Criar/remover peças em runtime já repercute sozinho: quem cuida
## disso é o MultiplayerSpawner (spawn e despawn viajam para todos os peers da sala).
##
## A base é `Node3D` (e não `StaticBody3D`) de propósito: o contrato vale para QUALQUER raiz 3D, então
## o importador (`scripts/scenery_contract.gd`) consegue anexá-lo tanto às peças de colisão prontas
## quanto a modelos novos cuja raiz seja `Node3D`/`RigidBody3D`. Ver [[sistemas/templates-de-level]].

## Escala mínima aceita — espelha TemplateManagerBase.MIN_SCALE_FACTOR: abaixo disso o modelo vira um
## ponto e seus colliders degeneram.
const MIN_SCALE: float = 0.05

## Posição definida pelo servidor. O setter aplica no próprio nó, então o cliente se coloca no lugar
## certo assim que o valor chega (o nó ainda está fora da árvore nesse momento — `position` é local e
## pode ser escrito com segurança).
@export var spawn_position: Vector3 = Vector3.ZERO:
	set(value):
		spawn_position = value
		position = value

## Rotação em torno de Y (radianos), como o template a definiu.
@export var spawn_rotation_y: float = 0.0:
	set(value):
		spawn_rotation_y = value
		rotation.y = value

## Fator de escala uniforme do template ("Escala (%)" do gerenciador de cenários).
@export var spawn_scale: float = 1.0:
	set(value):
		spawn_scale = maxf(value, MIN_SCALE)
		scale = Vector3.ONE * spawn_scale


# ───────────────────────── contrato de replicação (regra única) ─────────────────────────
# A mesma regra vale para a FERRAMENTA que prepara as cenas (scripts/scenery_contract.gd) e para a
# VALIDAÇÃO em runtime (gerenciador de cenários / _spawn_job). Ter os dois lados perguntando à mesma
# função evita o caso clássico: a ferramenta diz "ok" com um critério e o jogo quebra com outro.

## Nome do sincronizador de spawn que cada peça deve ter.
const SYNC_NAME: String = "ServerSynchronizer"
## Properties que precisam viajar no PACOTE DE SPAWN (na ordem em que a ferramenta as escreve).
const SPAWN_PROPERTIES: PackedStringArray = [
	".:spawn_position", ".:spawn_rotation_y", ".:spawn_scale",
]


## O que falta para `root` cumprir o contrato (vazio = cumpre). Uma lista em vez de um bool para a
## tela poder dizer ao usuário O QUE está errado no modelo, não só que está.
static func contract_issues(root: Node) -> PackedStringArray:
	var issues := PackedStringArray()
	if root == null:
		return PackedStringArray(["cena vazia"])
	if not (root is Node3D):
		issues.append("a raiz não é um nó 3D")
		return issues   # sem raiz 3D nada mais se aplica
	if not (root is SceneryPiece):
		issues.append("falta o script SceneryPiece na raiz")
	var sync := _spawn_synchronizer(root)
	if sync == null:
		issues.append("falta o %s (MultiplayerSynchronizer) de spawn" % SYNC_NAME)
		return issues
	var cfg := sync.replication_config
	if cfg == null:
		issues.append("o %s está sem replication_config" % SYNC_NAME)
		return issues
	var present := PackedStringArray()
	for p in cfg.get_properties():
		present.append(String(p))
	for wanted in SPAWN_PROPERTIES:
		if not present.has(wanted):
			issues.append("a property '%s' não é replicada no spawn" % wanted)
	return issues


## True quando a cena instanciada nasce nas coordenadas do servidor também no cliente.
static func meets_contract(root: Node) -> bool:
	return contract_issues(root).is_empty()


## O sincronizador de spawn da peça (por nome ou, na falta dele, o 1º filho MultiplayerSynchronizer).
static func _spawn_synchronizer(root: Node) -> MultiplayerSynchronizer:
	var by_name := root.get_node_or_null(NodePath(SYNC_NAME))
	if by_name is MultiplayerSynchronizer:
		return by_name as MultiplayerSynchronizer
	for c in root.get_children():
		if c is MultiplayerSynchronizer:
			return c as MultiplayerSynchronizer
	return null


## Config de replicação SPAWN-ONLY das três properties (`replication_mode = 0` → nada é enviado depois
## do pacote de criação; peça estática não gera tráfego contínuo).
static func make_spawn_config() -> SceneReplicationConfig:
	var cfg := SceneReplicationConfig.new()
	for path in SPAWN_PROPERTIES:
		var np := NodePath(path)
		cfg.add_property(np)
		cfg.property_set_spawn(np, true)
		cfg.property_set_replication_mode(np, SceneReplicationConfig.REPLICATION_MODE_NEVER)
	return cfg
