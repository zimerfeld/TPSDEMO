class_name Player
extends CharacterBody3D


enum Animations {
	JUMP_UP,
	JUMP_DOWN,
	STRAFE,
	WALK,
}

## Rapidez (1/s) com que o vetor de andar persegue o input. É o quanto o personagem demora a chegar à
## velocidade plena ao pisar no acelerador e a parar quando se solta — o deslocamento vem do root
## motion da animação, então este número é a "inércia" sentida no controle.
## 20 (era 10): a 10 sobravam ~100 ms de deriva depois de soltar a tecla, lidos como o personagem
## escorregando por conta própria. Aqui a parada fica seca e a arrancada, mais imediata; subir muito
## além disso começa a estalar a transição das animações de caminhada/estrafe.
const MOTION_INTERPOLATE_SPEED: float = 20.0
const ROTATION_INTERPOLATE_SPEED: float = 10.0
const PlayerBotAILib := preload("res://library3D/characters/player/IA/player_bot_ai.gd")

const MIN_AIRBORNE_TIME: float = 0.1
const JUMP_SPEED: float = 6.5
# Amortecimento (1/s) da velocidade vertical quando o espaço é SOLTO no meio da subida do
# pulo: a subida morre suavemente (sem trancos) e a animação transiciona para jump_down.
# Segurar o espaço até o fim mantém o arco completo (altura e distância máximas).
const JUMP_CUT_DAMPING: float = 14.0
# Tempo (s) mirando antes do PRIMEIRO tiro — espera a animação de mira assentar. Sem isto, num
# aim→tiro instantâneo a bala saía antes de o corpo entrar na pose de mira; no cliente (corpo
# renderizado ~100 ms no passado) isso parecia a bala saindo fora da extremidade do cano.
#
# VOLTOU a 0,45 (2026-08-07). A tentativa de 0,25 s — em tese acima do piso de 0,20 do xfade_time do
# AnimationNodeTransition — trouxe de volta o glitch da bala saindo fora do cano ao SACAR a arma de
# novo (relatado em playtest: "depois de guardar a arma volta a dar glitch"). O xfade é o piso do
# BLEND, não do tempo real até o osso GunBone assentar na pose de mira; quem define a origem do tiro é
# `shoot_from` no esqueleto DO SERVIDOR, ainda em transição. A responsividade do primeiro tiro vem da
# predição do efeito local (ver _can_predict_shot_fx), que não depende desta constante.
const AIM_WARMUP_TIME: float = 0.45
# Margem (s) sobre o aquecimento antes de o cliente CONFIAR que o servidor já autorizaria o tiro.
# Cobre a grade de envio do input mais uma volta de rede folgada — sem ela, prever o primeiro tiro de
# cada saque tocaria o efeito antes da autorização.
const SHOT_PREDICT_MARGIN: float = 0.15

var airborne_time: float = 100.0
# True do início do pulo até o ápice (ou o pouso). Restringe o corte de pulo (JUMP_CUT_DAMPING)
# a pulos REAIS — cair de uma borda não pode ser amortecido só porque o espaço não está pressionado.
var _jump_active: bool = false
# Tempo acumulado mirando (zera ao sair da mira); o tiro só é liberado após AIM_WARMUP_TIME.
var _aim_held_time: float = 0.0
# Predição do FEEDBACK do tiro no cliente dono (ver _play_shot_fx / _predict_shot_fx). Guarda o
# instante (ms) em que o efeito foi tocado localmente, para o `shoot()` que chega do servidor logo
# depois não repetir flash/som/tremida. Só cosmético — bala e dano seguem 100% no servidor.
var _local_fx_at: float = -1.0e9
# O servidor já confirmou um tiro NESTA sessão de mira? Só depois disso o cliente prevê o efeito: o
# relógio de aquecimento local corre à frente do servidor (o `aiming` ainda vai subir pela rede), e
# prever o PRIMEIRO tiro faria o efeito sair sistematicamente antes da autorização.
var _server_shot_since_aim: bool = false

var orientation := Transform3D()
var root_motion := Transform3D()
## Vetor de andar/estrafear (x = lateral, y = frente/trás), suavizado. LOCAL: cada peer calcula o seu
## — o dono a partir do próprio teclado, o servidor a partir do input recebido. NÃO é replicado; ver
## `net_motion`.
var motion := Vector2()
## Espelho de `motion` publicado pelo servidor, para os peers que só ASSISTEM este player animarem as
## pernas certo. Existe separado de `motion` porque replicar `motion` direto o devolvia ao PRÓPRIO
## dono ~30x/s: a cada amostra o teclado local era atropelado por um valor de um RTT atrás, e a
## arrancada/parada ficava serrilhada (o "flickering" ao mover). Agora o dono manda no seu `motion` e
## só quem assiste lê daqui.
var net_motion := Vector2()

var _is_local_player: bool = false
var _has_prediction: bool = false
var _predicted_origin: Vector3
var _predicted_velocity: Vector3
## Distância (m) de discordância a partir da qual a predição local é DESCARTADA e o corpo salta para a
## posição do servidor. Piso do limiar — ele cresce com a velocidade e o ping (ver _snap_threshold),
## porque quanto mais rápido se anda e mais alto o ping, maior é a discordância NORMAL entre os dois.
## Baixou de 2,0 para 0,4: com a reconciliação suave drenando o erro, um limiar alto só servia para
## deixar o desvio crescer até o teleporte.
const SERVER_SNAP_THRESHOLD: float = 0.4
## Teto do limiar de snap (m). Sem ele, ping alto viraria "nunca corrige".
const SERVER_SNAP_THRESHOLD_MAX: float = 4.0
## Fração do erro drenada por tick de física quando servidor e predição concordam "o suficiente".
## 0,12 a 60 Hz mata ~99% de um desvio em meio segundo — invisível para o jogador.
const RECONCILE_RATE: float = 0.12
# RTT medido do peer (s), reamostrado a cada RTT_SAMPLE_INTERVAL — get_statistic por tick de física
# seria desperdício para um número que muda devagar.
const RTT_SAMPLE_INTERVAL: float = 1.0
var _rtt_seconds: float = 0.0
var _rtt_sampled_at: float = -1.0e9

# --- Interpolação de rede (suavização das entidades remotas) ---
## Proxies replicados pelo ServerSynchronizer NO LUGAR de transform/PlayerModel:transform.
## O servidor os espelha do estado real a cada frame; o cliente remoto os bufferiza (NetInterp)
## e renderiza ~100 ms no passado, eliminando o stutter de aplicar o transform cru ~30x/s. O
## cliente DONO usa net_transform como "verdade do servidor" para reconciliar a predição.
@export var net_transform: Transform3D = Transform3D.IDENTITY:
	set(value):
		net_transform = value
		_net_received = true
@export var net_model_transform: Transform3D = Transform3D.IDENTITY
var _net_received: bool = false
var _interp_body := NetInterp.new()
var _interp_model := NetInterp.new()
var _interp_seeded: bool = false
# Estado da mira no frame anterior — para detectar o "aim-enter" e alinhar o corpo na hora.
var _was_aiming: bool = false

var initial_position: Vector3 = Vector3.ZERO

@onready var player_input: PlayerInputSynchronizer = $InputSynchronizer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var player_model: Node3D = $PlayerModel
## De onde a bala sai. `Robot_Skeleton` é o nó-raiz do glTF DENTRO de player.glb — não é autorado, e
## outro modelo tem outra raiz. Por isso a busca por NOME é o caminho principal: qualquer personagem
## que tenha um `ShootFrom` em qualquer profundidade funciona, sem depender do formato do rig.
@onready var shoot_from: Marker3D = _find_shoot_from()
@onready var crosshair: TextureRect = $Crosshair
@onready var fire_cooldown: Timer = $FireCooldown

@onready var sound_effects: Node = $SoundEffects
@onready var sound_effect_jump: AudioStreamPlayer3D = sound_effects.get_node(^"Jump")
@onready var sound_effect_land: AudioStreamPlayer3D = sound_effects.get_node(^"Land")
@onready var sound_effect_shoot: AudioStreamPlayer3D = sound_effects.get_node(^"Shoot")

@export var player_id: int = 1:
	set(value):
		player_id = value
		$InputSynchronizer.set_multiplayer_authority(value)
		# O MultiplayerSpawner atribui player_id (logo, a autoridade do input) só
		# DEPOIS que $InputSynchronizer._ready() rodou no cliente que entra. Por isso
		# o setup de câmera/input precisa ser reaplicado aqui — senão o cliente fica
		# com a view presa no centro do mundo e o player não se move.
		if is_inside_tree():
			$InputSynchronizer.apply_authority.call_deferred()
		# Garante o HUD do player local em toda cena de level, inclusive quando
		# player_id chega via replicação depois do _ready (cliente multiplayer).
		_setup_health_bar.call_deferred()
		# A autoridade do input (definida agora) decide se o nome vai no Label3D acima da
		# cabeça (outros) ou no HUD (player local) — reavalia após a autoridade assentar.
		_apply_name_label.call_deferred()
		# Guard: multiplayer is only available when inside the scene tree.
		# _ready() will re-evaluate _is_local_player after add_child().
		if is_inside_tree():
			_is_local_player = _safe_is_server_call(false) == false and value == multiplayer.get_unique_id()

@export var current_animation := Animations.WALK

## Posição de spawn definida pelo servidor; replicada como spawn property (ver
## ServerSynchronizer em player.tscn). O spawn do transform via MultiplayerSpawner NÃO
## chega a tempo no cliente que entra — ele nasceria em (0,0,0) e cairia do mapa. Esta
## property (entregue no pacote de spawn, como player_id) reposiciona o cliente.
@export var spawn_position: Vector3 = Vector3.ZERO:
	set(value):
		spawn_position = value
		_apply_spawn_position()

## Nome do jogador (spawn property, definida pelo servidor a partir do que o peer escolheu na
## playonline). Replicada a TODOS os peers no pacote de spawn → cada um mostra o Label3D acima
## da cabeça. O setter pode rodar antes do _ready (como player_id), por isso é idempotente.
@export var player_name: String = "":
	set(value):
		player_name = value
		_apply_name_label()

## Vida TOTAL, repartida igualmente entre os 10 membros/sub-membros com collider (ver [[limb-health]]) —
## 150 dá 15 de HP por membro. Calibrado (medido em 2026-08-06) contra o laser do red_robot, que vale
## 10: cada membro exige 2 acertos, dando 12 acertos até o abate (os 6 membros principais; olhos, boca
## e ombreiras caem junto com cabeça/braços). Fica perto dos 10 acertos do modelo antigo de vida única.
## Com os 100 anteriores eram só 6 acertos — um tiro por membro —, ou seja, a mudança para HP por
## membro tinha deixado o player MAIS frágil do que antes, não mais resistente.
const MAX_HP: int = 150
## Vida atual. REPLICADA (spawn + on-change, ver player.tscn): sem isto, quem entrava na sala depois
## via todo mundo com vida cheia, porque `hp` só se propagava pelo EVENTO `hit()` — quem não estava
## presente nunca recebeu o evento, e o valor errado nunca se corrigia sozinho. O setter repinta a
## barra; é null-safe porque `_health_bar` é null PARA SEMPRE em peer não-dono e em bot.
var hp: int = MAX_HP:
	set(value):
		hp = value
		if _health_bar != null:
			_health_bar.update_health(hp, MAX_HP)

# HP por membro/sub-membro (ver [[limb-health]]). Enquanto houver membros definidos, é ele que decide
# o abate; `hp` passa a espelhar a soma dos membros (a barra de vida continua mostrando o corpo todo).
var limbs: LimbHealth = null
## Snapshot do mapa de membros, replicado (ver LimbHealth.groups_snapshot / apply_snapshot). O
## `limbs` é um RefCounted e não passa pela rede; sem estes dois, quem entra na sala reconstrói o
## mapa CHEIO e vê membros intactos num corpo já castigado.
var limb_groups: PackedStringArray = PackedStringArray():
	set(value):
		limb_groups = value
		_apply_limb_snapshot()
var limb_hp: PackedInt32Array = PackedInt32Array():
	set(value):
		limb_hp = value
		_apply_limb_snapshot()

## Dano da arma que o player porta (atribuído a cada bullet disparado).
@export var weapon_damage: int = 50

@export_group("Perfil do modelo")
## Chave em LimbConfig (pasta do modelo) de onde saem os multiplicadores de dano e os sub-membros.
## Existe como export para um personagem com OUTRO rig poder reusar toda a mecânica do player sem
## reescrever `_setup_limb_colliders` — os valores abaixo mantêm player/playera idênticos ao que eram.
@export var limb_model_key: String = "player"
## Forma do collider da cabeça: "capsule" (player) ou "sphere".
@export var limb_head_shape: String = "capsule"
## Subdividir antebraço/mão e canela/pé em sub-membros próprios. O player faz opt-out (o hitbox de
## braço/perna inteiro já está ajustado); modelos novos costumam querer ligado.
@export var limb_auto_distal: bool = false
## Camada de colisão dos hitboxes de membro (bit5 = player).
@export var limb_hitbox_layer: int = 16
@export_group("")

var _health_bar = null

# SkeletonModifier3D que faz a mira vertical procedural (gira o torso pelo pitch da câmera).
var _aim_modifier = null
var ai: Node = null

@export var bot_controlled: bool = false:
	set(value):
		bot_controlled = value
		if is_inside_tree():
			_apply_bot_controlled()


func _ready() -> void:
	# Facção runtime deste nó (aliado por padrão; template "enemy" tem precedência). Usada para o
	# targeting da IA e para cortar o fogo amigo (ver [[factions]] / effects_shared/factions.gd).
	Factions.seed_node(self, &"player")
	# Pre-initialize orientation transform.
	orientation = player_model.global_transform
	orientation.origin = Vector3()
	initial_position = transform.origin
	# Posiciona no spawn replicado (cobre o caso de a property já ter chegado antes do _ready).
	_apply_spawn_position()
	# Mostra o nome acima da cabeça (cobre o caso de player_name já ter chegado antes do _ready).
	_apply_name_label()
	# Semeia os proxies de rede com a pose inicial APENAS no servidor (assim o spawn property
	# já carrega o valor certo). No cliente NÃO semeamos: o valor correto chega pela replicação
	# de spawn; semear aqui marcaria _net_received cedo e a entidade interpolaria a partir da
	# origem (flicker). Até chegar, o remoto fica na spawn_position.
	if _safe_is_server_call(false):
		net_transform = transform
		net_model_transform = player_model.transform
	# Re-evaluate here: player_id setter may have run before add_child() (no tree = no multiplayer).
	_is_local_player = not _safe_is_server_call(false) and player_id == multiplayer.get_unique_id()
	if not _safe_is_server_call(false):
		set_process(false)
	# Cria o HUD de vida do player local sempre que um level carrega.
	# Deferido para garantir que player_id/authority já foi replicado em multiplayer.
	_setup_health_bar.call_deferred()
	# Colliders 3D de membro (dano localizado). O projétil colide fisicamente
	# com eles; construídos em todos os peers (só o servidor simula os tiros).
	_setup_limb_colliders.call_deferred()
	# Mira vertical procedural (gira o torso conforme o pitch da câmera). Substitui o
	# blend additive AIM-Up/AIM-Down, que não conseguia abaixar o braço.
	_setup_aim_modifier.call_deferred()
	_apply_bot_controlled.call_deferred()


func _apply_bot_controlled() -> void:
	if player_input == null:
		return
	player_input.ai_controlled = bot_controlled
	if bot_controlled:
		_is_local_player = false
		if ai == null:
			ai = PlayerBotAILib.new()
			ai.name = "IA"
			add_child(ai)
	else:
		if ai != null:
			ai.queue_free()
			ai = null
		if is_inside_tree() and not _safe_is_server_call(false):
			_is_local_player = player_id == multiplayer.get_unique_id()
	# Bot vs. controlado muda quem é "dono local": reavalia o nome 3D / HUD.
	_apply_name_label()


# Coloca o player na posição de spawn enviada pelo servidor e zera a queda/predição local.
# Reentrante: chamado pelo setter de spawn_position (quando a property replicada chega) e
# pelo _ready. Idempotente — só age quando já está na árvore e há um spawn válido.
func _apply_spawn_position() -> void:
	if not is_inside_tree() or spawn_position == Vector3.ZERO:
		return
	global_position = spawn_position
	initial_position = spawn_position
	velocity = Vector3.ZERO
	_has_prediction = false
	# Salto de posição: zera a interpolação física para não "rasgar" (flicker) do ponto
	# antigo (ex.: 0,0,0) até o spawn. Roda em todos os peers (a property é replicada).
	reset_physics_interpolation()


# Atualiza o Label3D do nome acima da cabeça. Idempotente (chamado pelo setter de player_name e
# pelo _ready). O nome 3D acima da cabeça aparece só para os OUTROS jogadores conectados; no
# próprio player local o nome vai para o HUD (health_bar), então o Label3D dele fica escondido.
# Também esconde quando o nome está vazio para não mostrar uma etiqueta em branco.
func _apply_name_label() -> void:
	if not is_inside_tree():
		return
	var lbl := get_node_or_null(^"NameLabel") as Label3D
	if lbl == null:
		return
	lbl.text = player_name
	lbl.visible = player_name.strip_edges() != "" and not _is_owned_locally()
	# Mantém o HUD do dono em sincronia com o nome (quando o HUD já existe).
	if _health_bar != null and _health_bar.has_method(&"set_player_name"):
		_health_bar.set_player_name(player_name)


# True apenas na instância que CONTROLA localmente este player (o "meu" player), pelo mesmo
# critério do HUD de vida: a autoridade do InputSynchronizer é este peer e não é um bot. Cobre o
# host (id 1, que joga na sala) e os clientes. Usa $InputSynchronizer (não o onready) porque pode
# ser chamado antes do _ready, quando o setter de player_id já configurou a autoridade.
func _is_owned_locally() -> bool:
	if not is_inside_tree() or multiplayer == null:
		return false
	if bot_controlled:
		return false
	return $InputSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()


func _setup_health_bar() -> void:
	# Idempotente: pode ser chamado pelo _ready e pelo setter de player_id.
	if _health_bar != null:
		return
	# Mostra o HUD apenas para o player controlado localmente (mesmo critério do nome 3D).
	if not _is_owned_locally():
		return
	_health_bar = preload("res://controls2D/health_bar.gd").new()
	_health_bar.name = "HealthBar"
	add_child(_health_bar)
	_health_bar.update_health(hp, MAX_HP)
	# O nome do player local vai no HUD (acima do HP); o Label3D acima da cabeça fica escondido.
	_health_bar.set_player_name(player_name)
	_apply_name_label()


func _setup_limb_colliders() -> void:
	if has_node(^"LimbColliders"):
		return
	var skel := skeleton()
	if skel == null:
		CrashHandler.show_error(
			"Personagem %s sem Skeleton3D: o dano por membro não pode ser montado." % name)
		return
	var lc = preload("res://effects_shared/limb_colliders.gd").new()
	lc.name = "LimbColliders"
	lc.body_type = "biped"      # plano corporal → classificador de membros
	lc.model_key = limb_model_key
	lc.head_shape = limb_head_shape
	lc.hitbox_layer = limb_hitbox_layer
	lc.auto_distal_sub_members = limb_auto_distal
	add_child(lc)
	lc.build_for(skel)
	# HP por membro/sub-membro: a mesma regra dos inimigos vale para o player e para qualquer modelo
	# friendly/neutro — só é abatido quando TODOS os membros definidos caem. Ver [[limb-health]].
	limbs = LimbHealth.new()
	limbs.setup(self, lc.model_key, MAX_HP)
	# O snapshot do servidor costuma chegar ANTES daqui (o pacote de spawn é processado antes deste
	# setup, que é deferido) — então ele fica guardado nas properties e é aplicado agora que o mapa
	# existe. Sem isto, quem entra na sala nasceria com todos os membros cheios.
	_apply_limb_snapshot()
	# Ajusta a cápsula de LOCOMOÇÃO (bloqueio físico) ao modelo, derivando raio/altura dos boxes
	# de membro recém-construídos — corpo proporcional ao player em vez da cápsula default. Mantém
	# 1 shape/personagem (barato, estável, netcode-friendly). Ver [[sistemas/player]].
	var body_shape := get_node_or_null(^"CapsuleShape3D") as CollisionShape3D
	if body_shape != null:
		lc.fit_locomotion_capsule(body_shape, self)


## O personagem pode disparar? Precisa de um ponto de saída da bala E de dano — sem arma atribuída no
## template o dano é 0, e aí ele não atira: uma bala que não machuca ninguém só confundiria quem joga.
## O `weapon_damage` da própria cena (50 no player) continua valendo para quem nasce fora de template.
func can_shoot() -> bool:
	return shoot_from != null and weapon_damage > 0


## De onde sai a velocidade horizontal. No player ela vem do ROOT MOTION: o deslocamento que a própria
## animação carrega no osso `root` vira velocidade — é o que faz os pés não patinarem, porque o corpo
## anda exatamente o que a passada andou.
##
## É `virtual` porque nem todo modelo traz esse deslocamento. As animações do humanoide, por exemplo,
## são IN-PLACE (o `root` fica parado): plugadas aqui, o personagem animaria as pernas sem sair do
## lugar. Quem estiver nessa situação sobrescreve e calcula a velocidade por código — ver
## HumanoideJogavel. A predição de rede não se importa com a fonte: `_reconcile` é posicional, e
## servidor e cliente-dono passam os dois por aqui.
func _apply_horizontal_velocity(delta: float, _camera_x: Vector3, _camera_z: Vector3) -> void:
	var h_velocity: Vector3 = orientation.origin / delta
	velocity.x = h_velocity.x
	velocity.z = h_velocity.z


## Esqueleto do modelo, achado por TIPO e não por caminho. O caminho literal (`Robot_Skeleton/
## Skeleton3D`) vale só para o player.glb: em outro modelo a raiz do glTF tem outro nome, e o
## `get_node_or_null` devolvia null em silêncio — o personagem nascia sem dano por membro e sem mira
## procedural, sem nenhum aviso. Mesmo idioma que a tela Models já usa para varrer modelos.
func skeleton() -> Skeleton3D:
	if player_model == null:
		return null
	var found := player_model.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null


# Marker3D de onde a bala sai. Busca por nome em qualquer profundidade — modelos diferentes penduram
# o `ShootFrom` em ossos diferentes (o robô tem GunBone; um humanoide, a mão).
func _find_shoot_from() -> Marker3D:
	if player_model == null:
		return null
	return player_model.find_child("ShootFrom", true, false) as Marker3D


# Cria o SkeletonModifier3D da mira vertical procedural sob o Skeleton3D do player.
func _setup_aim_modifier() -> void:
	if _aim_modifier != null:
		return
	var skel := skeleton()
	if skel == null:
		return
	_aim_modifier = preload("res://library3D/characters/player/procedural_aim.gd").new()
	_aim_modifier.name = "ProceduralAim"
	skel.add_child(_aim_modifier)


func _safe_is_server_call(default: bool = false) -> bool:
	if not is_inside_tree():
		return default
	if multiplayer == null:
		CrashHandler.show_error(
			"MultiplayerAPI indisponível no player %d.\nVerifique a conexão de rede." % player_id
		)
		return default
	return multiplayer.is_server()


func _physics_process(delta: float) -> void:
	if _safe_is_server_call(false):
		if bot_controlled and ai != null and ai.has_method(&"update_input"):
			ai.update_input(self, player_input, delta)
		apply_input(delta)
		# Espelha o estado real nos proxies replicados (os clientes interpolam estes valores).
		net_transform = transform
		net_model_transform = player_model.transform
		net_motion = motion
	elif _is_local_player:
		_reconcile()
		apply_input(delta)
		_predicted_origin = global_position
		_predicted_velocity = velocity
		_has_prediction = true
	else:
		# Player remoto: renderiza ~100 ms no passado interpolando os snapshots recebidos.
		motion = net_motion   # só quem ASSISTE adota o vetor do servidor (alimenta o blend das pernas)
		_interpolate_remote()
		animate(current_animation, delta)


# Aplica o transform interpolado (buffer de snapshots datados) no player remoto e no seu modelo.
func _interpolate_remote() -> void:
	if not _net_received:
		return  # nada recebido ainda: fica na posição de spawn
	var now: float = float(Time.get_ticks_msec())
	_interp_body.push(now, net_transform)
	_interp_model.push(now, net_model_transform)
	if _interp_body.has_data():
		transform = _interp_body.sample(now)
	if _interp_model.has_data():
		player_model.transform = _interp_model.sample(now)
	if not _interp_seeded:
		# 1ª aplicação: zera a interpolação física p/ não "rasgar" do spawn até a 1ª amostra.
		_interp_seeded = true
		reset_physics_interpolation()


# Limiar de snap deste instante: quanto mais rápido o jogador anda e maior o ping, MAIOR a
# discordância normal entre a predição local e um estado do servidor de meia-volta atrás. Um limiar
# fixo obrigava a escolher entre teleportar em corrida (baixo) ou deixar o erro crescer (alto).
#
# SEM INPUT o limiar vai direto ao teto. É o que impede o "vai até um ponto à frente" ao parar: o
# jogador para no mesmo tick, mas o servidor ainda executa o input de um RTT atrás e sua posição fica
# adiantada — um desvio NORMAL, que não é erro de predição e não deve ser corrigido. Corrigi-lo é que
# produzia o salto (limiar baixo) ou o deslize (drenagem). Parado, só uma discordância realmente
# grande — teleporte, queda, dessincronia de verdade — justifica mexer na posição.
func _snap_threshold() -> float:
	if player_input == null or player_input.motion.length_squared() <= 0.0001:
		return SERVER_SNAP_THRESHOLD_MAX
	var speed: float = Vector2(velocity.x, velocity.z).length()
	return clampf(SERVER_SNAP_THRESHOLD + speed * _peer_rtt() * 2.0,
			SERVER_SNAP_THRESHOLD, SERVER_SNAP_THRESHOLD_MAX)


# RTT com o servidor (s), amostrado do próprio ENet. 0 quando indisponível (offline/host) — aí o
# limiar cai no piso, que é o comportamento certo sem rede no meio.
func _peer_rtt() -> float:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now - _rtt_sampled_at < RTT_SAMPLE_INTERVAL:
		return _rtt_seconds
	_rtt_sampled_at = now
	_rtt_seconds = 0.0
	var mp := multiplayer.multiplayer_peer
	if mp is ENetMultiplayerPeer:
		var enet_peer: ENetPacketPeer = (mp as ENetMultiplayerPeer).get_peer(1)
		if enet_peer != null:
			_rtt_seconds = float(enet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) / 1000.0
	return _rtt_seconds


func _reconcile() -> void:
	if not _has_prediction:
		return
	if not _net_received:
		# Sem verdade do servidor ainda: confia 100% na predição local.
		global_position = _predicted_origin
		velocity = _predicted_velocity
		return
	var drift: float = net_transform.origin.distance_to(_predicted_origin)
	if drift < _snap_threshold():
		# Servidor concorda o suficiente: segue a predição local (sem solavanco), drenando o erro um
		# pouco a cada tick — é isto que permite o dono não receber mais o eco de `motion`.
		#
		# Mas SÓ ENQUANTO HÁ INPUT. Ao soltar as teclas o jogador para na hora aqui, enquanto o
		# servidor ainda executa o input de um RTT atrás e sua posição está ADIANTE; drenar nesse
		# instante arrastava o personagem para essa posição futura — ele "escorregava" depois de
		# solto. Parado, a predição fica firme: o resto do desvio é pequeno (velocidade × RTT), não se
		# acumula com o jogador imóvel, e é drenado no próximo movimento.
		if player_input.motion.length_squared() > 0.0001:
			_predicted_origin = _predicted_origin.lerp(net_transform.origin, RECONCILE_RATE)
		global_position = _predicted_origin
		velocity = _predicted_velocity
	else:
		# Divergiu demais: ressincroniza com a posição autoritativa do servidor.
		global_position = net_transform.origin
		# physics_interpolation está LIGADA no projeto: sem zerar o histórico, o corpo é desenhado
		# "rasgando" da posição antiga até a nova, transformando a correção num risco visível. Os
		# outros teleportes do arquivo (spawn/respawn/level_exit) já fazem isto.
		reset_physics_interpolation()
		_has_prediction = false


func animate(anim: int, _delta: float) -> void:
	current_animation = anim as Animations

	if anim == Animations.JUMP_UP:
		animation_tree["parameters/state/transition_request"] = "jump_up"

	elif anim == Animations.JUMP_DOWN:
		animation_tree["parameters/state/transition_request"] = "jump_down"

	elif anim == Animations.STRAFE:
		animation_tree["parameters/state/transition_request"] = "strafe"
		# Vertical aim is now PROCEDURAL (see procedural_aim.gd): the additive AIM-Up/AIM-Down
		# blend can't lower the arm, so it stays disabled (add_amount 0) and the torso is
		# rotated by the camera pitch instead.
		animation_tree["parameters/aim/add_amount"] = 0
		if _aim_modifier != null:
			_aim_modifier.aim_pitch = player_input.get_aim_pitch()
		# The animation's forward/backward axis is reversed.
		animation_tree["parameters/strafe/blend_position"] = Vector2(motion.x, -motion.y)

	elif anim == Animations.WALK:
		# Not aiming while walking: zero the additive blend and the procedural pitch.
		animation_tree["parameters/aim/add_amount"] = 0
		if _aim_modifier != null:
			_aim_modifier.aim_pitch = 0.0
		# Change state to walk.
		animation_tree["parameters/state/transition_request"] = "walk"
		# Blend position for walk speed based checked motion.
		animation_tree["parameters/walk/blend_position"] = Vector2(motion.length(), 0)


func apply_input(delta: float) -> void:
	# apply_input roda no SERVIDOR (autoritativo) e também na PREDIÇÃO do cliente local. O
	# movimento é previsto nos dois; mas os EFEITOS AUTORITATIVOS (spawnar a bala replicada,
	# disparar os RPCs call_local de tiro/pulo/aterrissagem) só podem rodar no servidor — senão
	# o cliente cria uma bala-fantasma local que nunca se move nem é destruída (fica presa no cano).
	var authoritative: bool = _safe_is_server_call(false)
	motion = motion.lerp(player_input.motion, MOTION_INTERPOLATE_SPEED * delta)

	var camera_basis: Basis = player_input.get_camera_rotation_basis()
	var camera_z: Vector3 = camera_basis.z
	var camera_x: Vector3 = camera_basis.x

	camera_z.y = 0
	camera_z = camera_z.normalized()
	camera_x.y = 0
	camera_x = camera_x.normalized()

	# Jump/in-air logic.
	airborne_time += delta
	if is_on_floor():
		if airborne_time > 0.5 and authoritative:
			land.rpc()
		airborne_time = 0
		_jump_active = false

	var on_air: bool = airborne_time > MIN_AIRBORNE_TIME

	if not on_air and player_input.jumping:
		velocity.y = JUMP_SPEED  # salto previsto localmente (movimento responsivo)
		on_air = true
		_jump_active = true
		# Increase airborne time so next frame on_air is still true
		airborne_time = MIN_AIRBORNE_TIME
		if authoritative:
			jump.rpc()

	player_input.jumping = false

	if on_air:
		# No ar não há mira. DECAI em vez de zerar: um pulinho (ou um degrau que passe de
		# MIN_AIRBORNE_TIME) devolvia o aquecimento inteiro ao jogador que já estava mirando há
		# tempo — meio segundo de tiro engolido, sem explicação na tela. Decaindo, o pé de volta ao
		# chão retoma o aquecimento de onde parou.
		_aim_held_time = maxf(_aim_held_time - delta, 0.0)
		if velocity.y > 0:
			# Pulo variável: espaço SEGURO até o fim = arco completo (animação e distância
			# máximas). Espaço SOLTO na subida = corta o pulo suavemente, amortecendo a
			# velocidade vertical; a gravidade assume e a animação vira jump_down no ápice.
			if _jump_active and not player_input.jump_held:
				velocity.y *= exp(-JUMP_CUT_DAMPING * delta)
			animate(Animations.JUMP_UP, delta)
		else:
			_jump_active = false  # subida acabou (ápice/queda): nada mais a cortar
			animate(Animations.JUMP_DOWN, delta)
	elif player_input.aiming:
		_aim_held_time += delta  # acumula tempo de mira; o disparo aguarda AIM_WARMUP_TIME
		var q_to: Quaternion = player_input.get_camera_base_quaternion()
		if not _was_aiming:
			# Aim-enter: alinha o corpo À CÂMERA IMEDIATAMENTE (sem slerp). Sem isto, num
			# aim→tiro muito rápido o cano (shoot_from) ainda aponta para a direção antiga e a
			# bala sai torta. Atualiza já o player_model para o shoot_from refletir a mira agora.
			orientation.basis = Basis(q_to)
			player_model.global_transform.basis = orientation.basis
			_server_shot_since_aim = false   # nova sessão de mira: o 1º tiro volta a ser do servidor
		else:
			# Convert orientation to quaternions for interpolating rotation.
			var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
			# Interpolate current rotation with desired one.
			orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))

		# Change state to strafe.
		animate(Animations.STRAFE, delta)

		root_motion = Transform3D(animation_tree.get_root_motion_rotation(), animation_tree.get_root_motion_position())

		# Disparo é SERVER-AUTORITATIVO: só o servidor spawna a bala (replicada a todos via
		# MultiplayerSpawner) e dispara o RPC do efeito de tiro. No cliente isso é pulado — senão
		# nasceria uma bala local sem física nem replicação, presa no cano (efeito que "não some").
		# Aguarda o aquecimento de mira (AIM_WARMUP_TIME): o tiro sai só DEPOIS de a animação
		# de mira assentar e o cano estar alinhado — corrige o glitch do cliente (bala antes
		# da mira / fora do cano). Vale p/ host, cliente e bots (todos passam por aqui).
		if authoritative and player_input.shooting and fire_cooldown.time_left == 0 \
				and _aim_held_time >= AIM_WARMUP_TIME and can_shoot():
			var shoot_origin: Vector3 = shoot_from.global_transform.origin
			var to_target: Vector3 = player_input.shoot_target - shoot_origin
			# Guarda contra alvo degenerado (perto/atrás do cano, ex.: shoot_target ainda em
			# 0,0,0 ou um acerto colado): em vez de uma direção absurda (tiro vertical), usa a
			# direção que o modelo encara. A correção principal está na mira (player_input).
			var shoot_dir: Vector3 = -player_model.global_transform.basis.z
			if to_target.length() > 0.5:
				shoot_dir = to_target.normalized()

			# Reusable cannon shooter spawns + configures the bullet (default blue look)
			# and excludes the shooter's own body/limb colliders.
			CannonShooter.fire(get_parent(), shoot_origin, shoot_dir, weapon_damage, self)
			if bot_controlled and ai != null and ai.has_method(&"note_shot_fired"):
				var target_speed := 0.0
				if ai.has_method(&"current_target_speed"):
					target_speed = float(ai.current_target_speed())
				ai.note_shot_fired(shoot_origin.distance_to(player_input.shoot_target),
					target_speed)
			shoot.rpc()
		elif _is_local_player and player_input.shooting and _can_predict_shot_fx():
			# CLIENTE DONO: toca o feedback do tiro AGORA, sem esperar a volta do servidor. Sem isto o
			# jogador clicava e só via flash/som/tremida depois de um RTT inteiro (pelo túnel, perto de
			# 200 ms) — é a maior parcela de "input lag" que só o cliente paga. Nada de gameplay é
			# antecipado: a bala e o dano continuam nascendo no servidor, e o `shoot()` que chega logo
			# depois reconhece o efeito já tocado e não o repete.
			_play_shot_fx()

	else: # Not in air or aiming, idle.
		_aim_held_time = 0.0  # saiu da mira: zera o aquecimento
		# Convert orientation to quaternions for interpolating rotation.
		var target: Vector3 = camera_x * motion.x + camera_z * motion.y
		if target.length() > 0.001:
			var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
			var q_to: Quaternion = Basis.looking_at(target).get_rotation_quaternion()
			# Interpolate current rotation with desired one.
			orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))

		animate(Animations.WALK, delta)

		root_motion = Transform3D(animation_tree.get_root_motion_rotation(), animation_tree.get_root_motion_position())

	# Apply root motion to orientation.
	orientation *= root_motion

	_apply_horizontal_velocity(delta, camera_x, camera_z)
	velocity += get_gravity() * delta
	set_velocity(velocity)
	set_up_direction(Vector3.UP)
	move_and_slide()

	orientation.origin = Vector3() # Clear accumulated root motion displacement (was applied to speed).
	orientation = orientation.orthonormalized() # Orthonormalize orientation.

	player_model.global_transform.basis = orientation.basis

	# If we're below -40, respawn (teleport to the initial position).
	if transform.origin.y < -40.0:
		transform.origin = initial_position
		reset_physics_interpolation()  # teleporte: evita o rasgo de interpolação até o respawn

	# Estado da mira p/ o próximo frame (detecção do aim-enter, ver branch de mira acima).
	_was_aiming = player_input.aiming


@rpc("call_local")
func jump() -> void:
	animate(Animations.JUMP_UP, 0.0)
	sound_effect_jump.play()


@rpc("call_local")
func land() -> void:
	animate(Animations.JUMP_DOWN, 0.0)
	sound_effect_land.play()


@rpc("call_local")
func shoot() -> void:
	# O cooldown é do SERVIDOR e nunca pode ser pulado pelo dedupe: é ele que governa a cadência real
	# de tiro (o efeito local é só sensorial). Por isso fica FORA do guard abaixo.
	fire_cooldown.start()
	# Chegou um tiro autorizado nesta sessão de mira → a partir daqui o dono pode antecipar o efeito
	# dos PRÓXIMOS (o primeiro fica com o servidor, cujo relógio de aquecimento é o que vale).
	_server_shot_since_aim = true
	# O cliente dono já tocou o efeito ao clicar (ver _play_shot_fx)? então não repete — senão o
	# jogador ouviria o mesmo disparo duas vezes, separado por um RTT.
	if _fx_recently_played():
		return
	_play_shot_fx()


# Parte puramente SENSORIAL do disparo: partícula, clarão do cano, som e tremida de câmera. Separada
# do `shoot()` para o cliente dono poder tocá-la no instante do clique (predição de feedback), e o
# `shoot()` vindo do servidor apenas completar o que faltou.
func _play_shot_fx() -> void:
	_local_fx_at = float(Time.get_ticks_msec())
	# As partículas são FILHAS do próprio ShootFrom (ver player.tscn): derivá-las dele elimina mais um
	# caminho literal preso ao rig do robô e faz o efeito valer para qualquer personagem.
	if shoot_from != null:
		for fx_name in [^"ShootParticle", ^"MuzzleFlash"]:
			# SEM tipar como GPUParticles3D: no player.tscn estes nós são CPUParticles3D, e o cast
			# devolvia `null` — o clarão e a partícula do cano sumiam em silêncio para todo mundo. Os
			# dois tipos compartilham `restart()`/`emitting`, então basta checar o método.
			var fx := shoot_from.get_node_or_null(fx_name) as Node3D
			if fx != null and fx.has_method(&"restart"):
				fx.call(&"restart")
				fx.set(&"emitting", true)
	sound_effect_shoot.play()
	if not bot_controlled:
		add_camera_shake_trauma(0.35)


# Janela MÍNIMA (ms) em que um `shoot()` do servidor é entendido como a confirmação do efeito que o
# cliente já tocou.
const SHOT_FX_DEDUPE_MS: float = 250.0
# Folga (ms) somada ao RTT medido ao dimensionar essa janela.
const SHOT_FX_DEDUPE_SLACK_MS: float = 150.0


# A janela ACOMPANHA O PING. Fixa em 250 ms ela ficava menor que o próprio RTT que a predição existe
# para compensar: acima de ~220 ms — plausível no túnel, e garantido quando um pacote se perde e é
# retransmitido — o `shoot()` do servidor chegava fora da janela e o efeito tocava DE NOVO, dois
# clarões e dois sons por disparo. O teto é o cooldown de tiro, para dois disparos distintos nunca
# se confundirem num só.
func _fx_dedupe_window_ms() -> float:
	var wanted: float = maxf(SHOT_FX_DEDUPE_MS, _peer_rtt() * 1000.0 + SHOT_FX_DEDUPE_SLACK_MS)
	return minf(wanted, fire_cooldown.wait_time * 1000.0 - 50.0)


func _fx_recently_played() -> bool:
	return float(Time.get_ticks_msec()) - _local_fx_at < _fx_dedupe_window_ms()


# O cliente dono pode antecipar o efeito agora? Duas condições, e a primeira é o que faz o PRIMEIRO
# tiro de cada saque também sair na hora:
#   • o aquecimento local já passou do exigido pelo servidor COM MARGEM (ou o servidor já autorizou um
#     tiro nesta sessão de mira, o que é prova direta) — assim o efeito nunca sai antes da autorização;
#   • respeitou a cadência, medida por relógio PRÓPRIO. Não usa o FireCooldown: ele só é iniciado pelo
#     `shoot()` que vem do servidor, e amarrar a predição a ele faria a cadência local depender da
#     volta da rede — exatamente o que estamos eliminando.
# Antes esta função exigia um tiro JÁ confirmado na sessão de mira, e por isso o atraso voltava a cada
# vez que o jogador guardava e sacava a arma (relatado em playtest).
func _can_predict_shot_fx() -> bool:
	# Sem arma o servidor não vai autorizar tiro nenhum — prever o efeito aqui daria clarão e som
	# fantasmas, sem bala.
	if not can_shoot():
		return false
	var warmed: bool = _server_shot_since_aim or _aim_held_time >= AIM_WARMUP_TIME + SHOT_PREDICT_MARGIN
	if not warmed:
		return false
	return float(Time.get_ticks_msec()) - _local_fx_at >= fire_cooldown.wait_time * 1000.0


# Aplica o snapshot de membros recebido, se o mapa local já existir. Chamado pelos setters das duas
# properties (a ordem de chegada não importa: quem chegar por último completa o par) e ao final da
# construção dos membros. No SERVIDOR é inerte — lá o mapa é a fonte da verdade, não o destino.
func _apply_limb_snapshot() -> void:
	if limbs == null or limb_groups.is_empty() or _safe_is_server_call(false):
		return
	limbs.apply_snapshot(limb_groups, limb_hp)


# Publica o estado dos membros para os clientes. Só o servidor escreve; roda ao montar os membros e a
# cada acerto, e o MultiplayerSynchronizer envia por mudança (não a cada frame).
func _publish_limb_snapshot() -> void:
	if limbs == null or not _safe_is_server_call(false):
		return
	limb_groups = limbs.groups_snapshot()
	limb_hp = limbs.hp_snapshot()


@rpc("call_local")
func hit(amount: int = 25, group: String = "") -> void:
	# Com membros definidos o dano é localizado e o abate exige derrubar todos eles; `hp` espelha a
	# soma. Golpe sem membro identificado (área/queda) segue descontando da vida global.
	var by_limb: bool = limbs != null and limbs.has_limbs() and limbs.has_limb(group)
	if by_limb:
		limbs.apply_damage(group, amount)
		hp = limbs.total_hp()
	else:
		hp = maxi(hp - amount, 0)
	_publish_limb_snapshot()   # servidor: leva o estado por membro a quem entrar depois
	if (limbs.is_defeated() if by_limb else hp <= 0) and _safe_is_server_call(false):
		respawn.rpc()
	if not bot_controlled:
		add_camera_shake_trauma(0.75)


# ───────────────────────────── gestos (atalhos de animação) ─────────────────────────────
# Animações avulsas do modelo (rolar, defender, bater…) que o jogador mapeou a uma tecla na aba
# Controles. Entram como CAMADA por cima da locomoção — um estado seria reescrito por `animate()` no
# frame seguinte. Só existem em personagens cuja árvore tem o nó `gesture`; nos demais é no-op.

## Parâmetros do OneShot de gesto na árvore de animação.
const GESTURE_REQUEST := "parameters/gesture/request"
const GESTURE_CLIP := "gesture_clip"
## Janela (ms) em que o eco do servidor é entendido como confirmação do gesto que o dono já tocou.
const GESTURE_DEDUPE_MS: float = 400.0
var _gesture_played_at: float = -1.0e9

## Escala de tempo da camada de gesto. Zerá-la CONGELA a pose no frame em que estiver.
const GESTURE_SCALE := "parameters/gesture_scale/scale"
## Sobra deixada antes do fim do clipe ao congelar. O clipe de postura é CÍCLICO (é o que mantém a
## camada de gesto viva — ela se encerraria num clipe que acaba); parar o tempo um triz antes do fim
## garante que o segundo ciclo nunca comece. Sem a sobra, um frame de atraso rebobinaria a pose para o
## início do movimento — o corpo voltaria a ficar de pé.
const GESTURE_HOLD_MARGIN: float = 0.06
## Gestos de POSTURA: em vez de voltarem à locomoção quando o clipe acaba, congelam no último frame e
## ficam lá até o próximo gesto. É o que faz o agachado ser um ESTADO ("continua abaixado") em vez de
## uma repetição do movimento de abaixar. Cada personagem declara os seus; vazio = ninguém segura.
var hold_gestures: PackedStringArray = []
## Invalida um congelamento agendado quando outro gesto o substitui antes da hora.
var _gesture_hold_generation: int = 0


## True se este personagem sabe tocar gestos (a árvore tem a camada). O robô, por ora, não tem.
func supports_gestures() -> bool:
	return animation_tree != null and animation_tree.tree_root != null \
			and animation_tree.tree_root.has_node(StringName(GESTURE_CLIP))


## Pedido do DONO: toca já (responsividade) e manda o servidor confirmar para os outros peers.
func request_gesture(animation: String) -> void:
	if animation == "" or not supports_gestures():
		return
	_play_gesture_local(animation)
	if not _safe_is_server_call(false):
		_server_gesture.rpc_id(1, animation)
	else:
		play_gesture.rpc(animation)


# Servidor recebe o pedido e o retransmite. Valida o remetente: só o DONO do personagem manda gesto
# nele — senão qualquer peer poderia animar o corpo alheio.
@rpc("any_peer", "reliable")
func _server_gesture(animation: String) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != player_id:
		return
	play_gesture.rpc(animation)


@rpc("authority", "call_local", "reliable")
func play_gesture(animation: String) -> void:
	# O dono já tocou ao apertar a tecla; o eco que volta do servidor não repete.
	if _is_local_player and float(Time.get_ticks_msec()) - _gesture_played_at < GESTURE_DEDUPE_MS:
		return
	_play_gesture_local(animation)


## Encerra o gesto em andamento (ex.: soltar o CTRL sai do agachado). Como o disparo, é o servidor
## que confirma para os demais peers.
func abort_gesture() -> void:
	if not supports_gestures():
		return
	_resume_gesture_time()
	animation_tree[GESTURE_REQUEST] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
	if not _safe_is_server_call(false):
		_server_gesture_abort.rpc_id(1)
	else:
		play_gesture_abort.rpc()


@rpc("any_peer", "reliable")
func _server_gesture_abort() -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != player_id:
		return
	play_gesture_abort.rpc()


@rpc("authority", "call_local", "reliable")
func play_gesture_abort() -> void:
	if supports_gestures():
		_resume_gesture_time()
		animation_tree[GESTURE_REQUEST] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT


func _play_gesture_local(animation: String) -> void:
	if not supports_gestures():
		return
	var clip := animation_tree.tree_root.get_node(StringName(GESTURE_CLIP)) as AnimationNodeAnimation
	if clip == null:
		return
	clip.animation = StringName(animation)
	_gesture_played_at = float(Time.get_ticks_msec())
	_resume_gesture_time()
	animation_tree[GESTURE_REQUEST] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	if hold_gestures.has(animation):
		_freeze_gesture_at_end(animation)


## Nome do clipe de AGACHAR para o lado dado (1 = direita, -1 = esquerda), e o de LEVANTAR que o
## desfaz. Vazio quer dizer "este personagem não sabe agachar" — o CTRL simplesmente não o anima. Só o
## humanoide tem esse vocabulário hoje; o robô não tem os clipes.
func crouch_gesture(_side: int) -> String:
	return ""


func stand_gesture(_side: int) -> String:
	return ""


func _has_gesture_scale() -> bool:
	return animation_tree != null and animation_tree.tree_root != null \
			and animation_tree.tree_root.has_node(&"gesture_scale")


## Volta o tempo do gesto a correr e cancela qualquer congelamento pendente. Chamado a cada disparo e
## no aborto: sem isto, o gesto seguinte a um agachado nasceria com escala 0, ou seja, parado.
func _resume_gesture_time() -> void:
	_gesture_hold_generation += 1
	if _has_gesture_scale():
		animation_tree[GESTURE_SCALE] = 1.0


## Deixa o clipe rodar inteiro UMA vez e então para o tempo, segurando a pose final.
func _freeze_gesture_at_end(animation: String) -> void:
	if not _has_gesture_scale():
		return
	var clip := animation_tree.get_animation(StringName(animation))
	if clip == null:
		return
	_gesture_hold_generation += 1
	var generation := _gesture_hold_generation
	await get_tree().create_timer(maxf(clip.length - GESTURE_HOLD_MARGIN, 0.05)).timeout
	# Outro gesto entrou no meio do caminho (ou o personagem morreu): este congelamento não vale mais.
	if generation != _gesture_hold_generation or not is_inside_tree():
		return
	animation_tree[GESTURE_SCALE] = 0.0


@rpc("call_local")
func respawn() -> void:
	hp = MAX_HP          # o setter repinta a barra de vida
	if limbs != null:
		limbs.reset()   # membros destruídos voltam inteiros junto com a vida
	_publish_limb_snapshot()   # servidor: o mapa cheio vale também para quem entrar depois
	transform.origin = initial_position
	reset_physics_interpolation()  # teleporte de respawn: evita o rasgo de interpolação


@rpc("call_local")
func add_camera_shake_trauma(amount: float) -> void:
	player_input.camera_camera.add_trauma(amount)


func notify_projectile_feedback(hit_target: Node) -> void:
	if not bot_controlled or ai == null or not ai.has_method(&"report_shot_result"):
		return
	ai.report_shot_result(hit_target != null and hit_target.has_method(&"show_health_hud"))
