extends CharacterBody3D


signal exploded()

enum State {
	APPROACH = 0,
	AIM = 1,
	SHOOTING = 2,
}

const PLAYER_AIM_TOLERANCE_DEGREES = deg_to_rad(15.0)

## Histerese de alvo: só troca para outro player se ele estiver ao menos esta distância (m) mais perto
## que o alvo atual — evita ficar alternando entre players quase equidistantes.
const TARGET_SWITCH_MARGIN: float = 2.5

const SHOOT_WAIT: float = 6.0
const AIM_TIME: float = 1.0

const AIM_PREPARE_TIME: float = 0.5
const BLEND_AIM_SPEED: float = 0.05

# Aparência da bala de canhão do red_robot (CannonShooter): bola VERMELHA grande (calibre)
# com rastro/flash VERMELHO — o mesmo bullet do player, recolorido.
# A bola usa material unshaded: valores > 1 dão o brilho HDR (mesmo truque do azul do player).
const BULLET_TINT := Color(1.0, 0.12, 0.12)            # cor do efeito (luz + rastro)
const BULLET_BALL_COLOR := Color(1.50196, 0.14902, 0.14902, 1)  # bola vermelha (glow)
const BULLET_BALL_SCALE := 2.5                         # tamanho do calibre

@export var test_shoot: bool = false

@export var enemy_name: String = "Red Robot"
## Vida TOTAL, repartida igualmente entre os 11 membros/sub-membros com collider (ver [[limb-health]]) —
## 550 dá 50 de HP por membro. Calibrado (medido em 2026-08-06) contra o tiro do player, que vale 50:
## é o MAIOR total que ainda derruba um membro por tiro, mantendo o abate em 6 tiros (um por membro
## principal; os sub-membros caem com o pai). Acima de ~560 cada membro passaria a exigir 2 tiros e o
## abate saltaria para 12. O valor antigo (200) dava só 18 por membro — granularidade grosseira demais
## para armas fracas, como o canhão de 10 do próprio red_robot.
@export var max_health: int = 550

## Dano-base do laser do enemy por acerto em MEMBRO do player (cabeça aplica
## +50% via multiplicador 1.5 da hitbox). Só há dano se acertar um membro.
@export var weapon_damage: int = 10
## Precisão-base antes da adaptação da IA. O red_robot pode melhorar esse valor ao longo
## do duelo se os comportamentos adaptativos estiverem ligados.
@export_range(0.0, 1.0) var aim_accuracy: float = 0.78
## Só dispara quando o player estiver dentro deste alcance (mira precisa).
@export var effective_range: float = 30.0
## Velocidade (m/s) que a animação de caminhada percorre no chão com escala de tempo = 1.0 (a "passada
## natural" da anim `Walk`). É MEDIDA em runtime no _ready a partir do deslocamento do bone de root
## motion (MASTER) ÷ duração da animação — este valor é só o fallback. No movimento manual
## (strafe/recuo/formação) a cadência da animação é escalada para casar com a velocidade real e o
## deslocamento sai do PRÓPRIO root motion → os pés NÃO patinam.
@export var walk_natural_speed: float = 0.8
## Multiplicador global do quanto o robô anda no modo manual (1.0 = casa a passada; >1 acelera).
@export_range(0.5, 2.0) var gait_speed_scale: float = 1.0
## Velocidade angular (rad/s) com que o CORPO/pernas giram para encarar a direção do movimento no modo
## manual — a torre/canhão continua mirando o player de forma independente (blendspace `aim`). Girar as
## pernas para onde o robô anda é o que elimina o deslize lateral (a anim `Walk` é só para frente).
## Baixo de propósito: um giro gracioso e pesado, sem "chacoalhar" a cada reprocura de rumo.
@export var body_turn_rate: float = 5.0
## Suavização (1/s) do RUMO de deslocamento antes de virar o corpo. A direção que a IA calcula muda
## rápido (troca de strafe, reprocura de alvo, sondas de geometria); passá-la por este filtro faz as
## mudanças de direção entrarem GRADUALMENTE → nada de tremer. Menor = mais suave/pesado.
@export var move_dir_response: float = 4.0

@export var target_position := Vector3()
@export var aim_target_position := Vector3.ZERO
@export var health: int = 550

# HP por membro/sub-membro (ver [[limb-health]]). Criado junto com os colliders de membro; enquanto
# houver membros definidos, é ELE que decide o abate — `health` vira o espelho da soma dos membros.
var limbs: LimbHealth = null
## Snapshot do mapa de membros, replicado (ver LimbHealth.groups_snapshot / apply_snapshot). O mapa
## e um RefCounted e nao passa pela rede; sem isto quem entra na sala reconstroi todos os membros
## CHEIOS e ve a barra por membro intacta num robo ja castigado.
var limb_groups: PackedStringArray = PackedStringArray():
	set(value):
		limb_groups = value
		_apply_limb_snapshot()
var limb_hp: PackedInt32Array = PackedInt32Array():
	set(value):
		limb_hp = value
		_apply_limb_snapshot()
@export var state: State = State.APPROACH
## Abatido. REPLICADO (spawn + on-change): quem entra na sala depois nasce sabendo quem já morreu, e
## a decisão do abate é só do servidor. O setter dispara a explosão quando a morte acontece com este
## peer presente; quem chega depois cai no `_ready` (ver linha ~166), que aplica só o estado estático
## — refazer explosão e som de um evento passado seria pior que não mostrar nada.
@export var dead: bool = false:
	set(value):
		var was_dead := dead
		dead = value
		if dead and not was_dead and is_node_ready():
			_play_death()
# Guarda de idempotência da explosão (o setter de `dead` e o `_ready` podem chamar o mesmo caminho).
var _death_played: bool = false
@export var aim_preparing: float = AIM_PREPARE_TIME

## Proxy replicado NO LUGAR de global_transform: o servidor o espelha; o cliente o bufferiza
## (NetInterp) e renderiza ~100 ms no passado, suavizando o movimento do robô (anti-flicker).
@export var net_transform: Transform3D = Transform3D.IDENTITY:
	set(value):
		net_transform = value
		_net_received = true
var _net_received: bool = false
var _interp := NetInterp.new()
var _interp_seeded: bool = false
# Cliente: última posição interpolada, para estimar a velocidade e casar a cadência das pernas.
var _remote_last_pos: Vector3 = Vector3.ZERO
var _remote_has_last_pos: bool = false

var shoot_countdown: float = SHOOT_WAIT
var aim_countdown: float = AIM_TIME

var player: Node3D = null
# Todos os players atualmente dentro do raio de alerta (Area body_entered/exited). O alvo do quadro é
# o MAIS PRÓXIMO entre eles (_pick_target) → qualquer inimigo pode atirar em qualquer player no raio.
var _players_in_range: Array[Node3D] = []
var orientation := Transform3D()
# AnimationPlayer de locomoção que o AnimationTree pilota — usado para escalar a cadência das pernas
# à velocidade real no movimento manual (anti-patinação). Resolvido no _ready a partir do tree.
var _loco_player: AnimationPlayer = null
# Rumo de deslocamento suavizado (modo manual): filtra a direção crua da IA p/ o corpo não chacoalhar.
var _move_dir_smooth: Vector3 = Vector3.ZERO

# Controlador de IA (comportamentos/decisões), instanciado em _ready a partir de IA/.
var ai: RedRobotAI = null
# Recarga efetiva entre tiros, já acelerada pela IA (SHOOT_WAIT / fire_rate_multiplier).
var shoot_reload: float = SHOOT_WAIT

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var shoot_animation: AnimationPlayer = $ShootAnimation

@onready var model: Node3D = $RedRobotModel
# Muzzle of the cannon (the bullet is fired from here, along its -Z).
@onready var ray_from: BoneAttachment3D = model.get_node(^"Armature/Skeleton3D/RayFrom")
@onready var ray_mesh: MeshInstance3D = ray_from.get_node(^"RayMesh")
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

@onready var explosion_sound: AudioStreamPlayer3D = $SoundEffects/Explosion
@onready var hit_sound: AudioStreamPlayer3D = $SoundEffects/Hit

@onready var death: Node3D = $Death
@onready var death_shield1: RigidBody3D = death.get_node(^"PartShield1")
@onready var death_shield2: RigidBody3D = death.get_node(^"PartShield2")
@onready var death_head: RigidBody3D = death.get_node(^"PartHead")
@onready var death_detach_spark1: CPUParticles3D = death.get_node(^"DetachSpark1")
@onready var death_detach_spark2: CPUParticles3D = death.get_node(^"DetachSpark2")


func _ready() -> void:
	# Facção runtime (hostil por padrão; template tem precedência) → targeting e sem fogo amigo.
	Factions.seed_node(self, &"red_robot")
	orientation = global_transform
	orientation.origin = Vector3()
	# Semeia o proxy de rede com a pose inicial APENAS no servidor (spawn property correto). No
	# cliente o valor chega pela replicação de spawn; semear aqui causaria flicker a partir da origem.
	if multiplayer.is_server():
		net_transform = global_transform
	$AnimationTree.active = true
	# AnimationPlayer que o tree pilota → usado APENAS para medir a passada natural da anim `Walk`
	# (a cadência em si é escalada pelo nó AnimationNodeTimeScale `locomotion_scale` da árvore, porque
	# o speed_scale do AnimationPlayer é ignorado quando quem pilota é a AnimationTree). Pode ser null.
	if animation_tree.anim_player != NodePath():
		_loco_player = animation_tree.get_node_or_null(animation_tree.anim_player) as AnimationPlayer
	_calibrate_walk_natural_speed()

	# IA do red_robot: instancia o controlador de comportamento/decisões (pasta IA/) e
	# aplica a recarga acelerada (1.5x mais rápida no 1º e nos próximos tiros).
	ai = preload("res://library3D/characters/red_robot/IA/red_robot_ai.gd").new()
	ai.name = "IA"
	add_child(ai)
	shoot_reload = ai.reload_time(SHOOT_WAIT)
	shoot_countdown = shoot_reload

	if test_shoot:
		shoot_countdown = 0.0

	# Sem mais laser: o tiro agora é uma bala de canhão. Esconde o feixe do laser e suas
	# faíscas para que nada do antigo raio apareça.
	ray_mesh.visible = false
	var laser_ember := ray_from.get_node_or_null(^"LaserEmber")
	if laser_ember is CPUParticles3D:
		(laser_ember as CPUParticles3D).emitting = false

	if dead:
		# Entrou numa sala onde este robô JÁ estava abatido (o pacote de spawn traz `dead` verdadeiro):
		# aplica o estado estático e marca a explosão como "já ocorrida", sem refazer efeitos de um
		# evento que aconteceu antes de eu chegar. As peças da explosão já sumiram no servidor.
		_death_played = true
		_apply_dead_state()

	animate(0.0)

	# Colliders 3D de membro (dano localizado); o projétil colide fisicamente.
	if not dead:
		_setup_limb_colliders.call_deferred()


func _setup_limb_colliders() -> void:
	if has_node(^"LimbColliders"):
		return
	var skel := model.get_node_or_null(^"Armature/Skeleton3D") as Skeleton3D
	if skel == null:
		return
	var lc = preload("res://effects_shared/limb_colliders.gd").new()
	lc.name = "LimbColliders"
	lc.body_type = "biped"      # plano corporal → classificador de membros
	lc.model_key = "red_robot"  # busca os multiplicadores de dano e os sub-membros em LimbConfig
	lc.hitbox_layer = 32        # bit6 = colliders de membro do enemy
	lc.auto_distal_sub_members = false  # opt-out: mantém BRAÇO/PERNA inteiros (rig/config manual já ajustados)
	# A CABEÇA cobre o painel do rosto ("mouth_eyes") + os olhos ("L-EYE"/"R-EYE"). Sem os
	# olhos (excluídos pela palavra "eye") a cabeça ficaria minúscula (~42 vértices só do
	# painel) — esta hitbox vale para o headshot em jogo e para o gizmo do model browser.
	lc.head_bone_names = (["mouth_eyes", "L-EYE", "R-EYE"] as Array[String])
	# O corpo do red_robot é o osso genérico "Bone.001", que o classificador não
	# reconhece — sem isto ele ficaria sem collider de TRONCO (só a cabeça).
	lc.torso_bone_names = (["Bone.001"] as Array[String])
	lc.torso_shape = "sphere"   # corpo arredondado do red_robot → esfera, não caixa
	lc.head_scale = 1.3         # cabeça com volume maior (headshot mais generoso)
	# Os sub-membros (placas traseiras das pernas "L-/R-RearLegGuard") agora vêm de
	# LimbConfig (na pasta do modelo: res://library3D/characters/red_robot/limb_config.json;
	# override de runtime em user://) — editáveis na tela Models. Ver build_for.
	add_child(lc)
	lc.build_for(skel)
	# HP por membro/sub-membro: a partir daqui o abate exige derrubar TODOS os membros definidos, cada
	# um com sua fatia da vida total. Precisa vir DEPOIS de build_for (é dos colliders que sai a lista).
	limbs = LimbHealth.new()
	limbs.setup(self, lc.model_key, max_health)
	# O snapshot do servidor costuma chegar ANTES daqui (o pacote de spawn e processado antes deste
	# setup, que e deferido): fica guardado nas properties e e aplicado agora que o mapa existe.
	_apply_limb_snapshot()
	# Ajusta a cápsula de LOCOMOÇÃO (bloqueio físico) ao red_robot a partir dos boxes de membro —
	# corpo proporcional ao modelo em vez da cápsula default. Ver [[sistemas/inimigos]].
	if collision_shape != null:
		lc.fit_locomotion_capsule(collision_shape, self)


func resume_approach(reset_reload: bool = true) -> void:
	state = State.APPROACH
	aim_preparing = AIM_PREPARE_TIME
	shoot_countdown = shoot_reload if reset_reload else ai.retry_delay()


# Aplica o snapshot de membros recebido, se o mapa local ja existir (os setters podem chegar antes
# do build). No SERVIDOR e inerte: la o mapa e a fonte da verdade, nao o destino.
func _apply_limb_snapshot() -> void:
	if limbs == null or limb_groups.is_empty() or multiplayer.is_server():
		return
	limbs.apply_snapshot(limb_groups, limb_hp)


# Publica o estado dos membros para os clientes. So o servidor escreve; o MultiplayerSynchronizer
# envia por mudanca (replication_mode 2), nao a cada frame.
func _publish_limb_snapshot() -> void:
	if limbs == null or not multiplayer.is_server():
		return
	limb_groups = limbs.groups_snapshot()
	limb_hp = limbs.hp_snapshot()


@rpc("call_local")
func hit(amount: int = 50, group: String = "") -> void:
	if dead:
		return
	var param = "parameters/hit" + str(randi() % 3 + 1) + "/request"
	animation_tree[param] = 1
	hit_sound.play()
	# Com membros definidos, o dano vai para o MEMBRO atingido e a vida global apenas espelha a soma
	# (para barras que mostram o corpo inteiro). Sem membros — ou golpe sem membro identificado, como
	# uma explosão de área — cai no comportamento antigo de vida única.
	var by_limb: bool = limbs != null and limbs.has_limbs() and limbs.has_limb(group)
	if by_limb:
		limbs.apply_damage(group, amount)
		health = limbs.total_hp()
	else:
		health = maxi(health - amount, 0)
	show_health_hud(-1.0, group)
	_publish_limb_snapshot()   # servidor: leva o estado por membro a quem entrar depois
	# ABATE é decisão do SERVIDOR (mesma regra do player.gd). Antes cada peer decidia a partir do seu
	# estado local: um cliente com vida dessincronizada via o robô morrer cedo — ou seguir vivo,
	# animado e com collider, até sumir do nada. Agora o servidor decide e `dead` replica; o setter de
	# `dead` roda a explosão em cada peer.
	if (limbs.is_defeated() if by_limb else health <= 0) and multiplayer.is_server():
		dead = true
		await get_tree().create_timer(10.0).timeout
		queue_free()


# Explosão/desmonte do robô. Idempotente (`_death_played`) porque chega por dois caminhos: o setter de
# `dead` quando a morte acontece com o peer presente, e o `_ready` de quem entra depois — este último
# só aplica o estado estático (ver _apply_dead_state), sem refazer efeitos de um evento passado.
func _play_death() -> void:
	if _death_played:
		return
	_death_played = true
	_apply_dead_state()
	death.visible = true

	death_detach_spark1.emitting = true
	death_detach_spark2.emitting = true

	death_shield1.explode()
	death_shield2.explode()
	death_head.explode()

	explosion_sound.play()
	if multiplayer.is_server():
		# Sinal de "abateu" é evento de GAMEPLAY: emitir só no servidor, senão o dia em que alguém o
		# escutar (pontuação, missão) contaria o mesmo abate uma vez por peer.
		exploded.emit()
	hide_health_hud()


# Estado ESTÁTICO do robô morto: sem animação, sem malha viva, sem collider. Aplicado tanto na
# explosão quanto por quem entra na sala com ele já abatido.
func _apply_dead_state() -> void:
	animation_tree.active = false
	model.visible = false
	collision_shape.disabled = true


# Atualiza o HUD compartilhado de vida do inimigo (apenas em clientes com tela).
# Público: chamado por hit() e pela mira do player (player_input.gd).
# `distance` (m) é exibida ao lado do nome; -1 oculta a distância.
func show_health_hud(distance: float = -1.0, group: String = "") -> void:
	if dead:
		return
	if DisplayServer.get_name() == "headless":
		return
	# `self` (e não a cena atual): o HUD nasce no viewport DESTA sala — ver enemy_health_bar.gd.
	var hud = preload("res://controls2D/enemy_health_bar.gd").get_shared(self)
	if hud == null:
		return
	# Com um MEMBRO na mira (ou recém-atingido), o overlay mostra o HP DAQUELE membro e o nome dele
	# junto do inimigo — é o membro que precisa cair, então é o número que importa ao jogador.
	if limbs != null and limbs.has_limb(group):
		hud.show_enemy("%s — %s" % [enemy_name, limbs.label_of(group)],
			limbs.hp_of(group), limbs.max_hp_of(group), distance, effective_range)
		return
	# red_robot possui arma de tiro: informa o alcance efetivo (m) para o HUD exibi-lo.
	hud.show_enemy(enemy_name, maxi(health, 0), max_health, distance, effective_range)


# Público: chamado na morte e quando a mira do player sai do inimigo.
func hide_health_hud() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var hud = preload("res://controls2D/enemy_health_bar.gd").get_shared(self)
	if hud != null:
		hud.hide_now()


func _player_velocity() -> Vector3:
	if player is CharacterBody3D:
		return (player as CharacterBody3D).velocity
	return Vector3.ZERO


func _aim_point_from(origin: Vector3) -> Vector3:
	if not is_instance_valid(player):
		return Vector3.ZERO
	return ai.compute_aim_point(origin, player.global_transform.origin, _player_velocity())


func _ray_hits_player(ray_origin: Vector3, ray_to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_to, 0xFFFFFFFF, [self])
	var col: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if col.is_empty():
		return false
	if col.collider == player:
		return true
	return col.collider != null and col.collider.has_meta("character") and col.collider.get_meta("character") == player


# Dispara uma BALA DE CANHÃO (preta, com rastro/flash vermelho) pelo cano, via o
# componente reutilizável CannonShooter (mesmo bullet do player, recolorido). A bala voa
# e aplica DANO LOCALIZADO ao acertar os colliders de membro do player (LimbColliders);
# não há mais raio hitscan. O servidor dispara; clientes recebem a bala replicada.
func shoot() -> void:
	if not multiplayer.is_server():
		return
	var origin: Vector3 = ray_from.global_transform.origin
	var dir: Vector3 = -ray_from.global_transform.basis.z
	if is_instance_valid(player):
		var aim_point := aim_target_position if aim_target_position != Vector3.ZERO else _aim_point_from(origin)
		dir = (aim_point - origin).normalized()
		var target_speed := _player_velocity().length()
		var distance := origin.distance_to(player.global_transform.origin)
		var accuracy := ai.dynamic_accuracy(aim_accuracy, distance, target_speed)
		if accuracy < 1.0:
			var spread := (1.0 - accuracy) * 0.15
			dir = (dir + Vector3(randf_range(-spread, spread), randf_range(-spread, spread),
				randf_range(-spread, spread))).normalized()
		ai.note_shot_fired(distance, target_speed)
	CannonShooter.fire(get_parent(), origin, dir, weapon_damage, self,
		BULLET_TINT, BULLET_BALL_COLOR, BULLET_BALL_SCALE)


func notify_projectile_feedback(hit_target: Node) -> void:
	if ai == null:
		return
	ai.report_shot_result(hit_target == player)


func animate(delta: float) -> void:
	if state == State.APPROACH:
		var to_player_local: Vector3 = target_position * global_transform
		# The front of the robot is +Z, and atan2 is zero at +X, so we need to use the Z for the X parameter (second one).
		var angle_to_player: float = atan2(to_player_local.x, to_player_local.z)
		if angle_to_player > PLAYER_AIM_TOLERANCE_DEGREES:
			animation_tree["parameters/state/transition_request"] = "turn_left"
		elif angle_to_player < -PLAYER_AIM_TOLERANCE_DEGREES:
			animation_tree["parameters/state/transition_request"] = "turn_right"
		elif target_position == Vector3.ZERO:
			animation_tree["parameters/state/transition_request"] = "idle"
		else:
			animation_tree["parameters/state/transition_request"] = "walk"
	else:
		animation_tree["parameters/state/transition_request"] = "idle"

	# Aiming or shooting
	if target_position != Vector3.ZERO:
		animation_tree["parameters/aiming/blend_amount"] = clamp(aim_preparing / AIM_PREPARE_TIME, 0, 1)

		var live_aim_target := aim_target_position if aim_target_position != Vector3.ZERO else (target_position + Vector3.UP)
		var to_cannon_local: Vector3 = live_aim_target * ray_mesh.global_transform
		var h_angle: float = rad_to_deg(atan2( to_cannon_local.x, -to_cannon_local.z))
		var v_angle: float = rad_to_deg(atan2( to_cannon_local.y, -to_cannon_local.z))
		var blend_pos: Vector2 = animation_tree.get("parameters/aim/blend_position")
		var h_motion: float = BLEND_AIM_SPEED * delta * -h_angle
		blend_pos.x += h_motion
		blend_pos.x = clampf(blend_pos.x, -1.0, 1.0)

		var v_motion: float = BLEND_AIM_SPEED * delta * v_angle
		blend_pos.y += v_motion
		blend_pos.y = clampf(blend_pos.y, -1.0, 1.0)

		animation_tree["parameters/aim/blend_position"] = blend_pos


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		# Remoto: interpola o transform recebido (~100 ms no passado) e anima. A escala de cadência
		# não é replicada, então casamos a passada à velocidade INTERPOLADA local → os pés também não
		# patinam no cliente (o corpo já chega encarando a direção do movimento, calculada no servidor).
		if not dead:
			_interpolate_remote()
			_match_remote_cadence(delta)
			animate(delta)
		return

	if dead:
		return

	if test_shoot:
		shoot()
		test_shoot = false

	# Alvo do quadro = player VIVO mais próximo dentro do raio de alerta (multiplayer: pode haver
	# vários). Reavaliado a cada frame com histerese → cada robô reage ao player mais perto DELE.
	player = _pick_target()

	if not player:
		target_position = Vector3()
		aim_target_position = Vector3.ZERO
		_reset_locomotion_cadence()
		animate(delta)
		set_velocity(get_gravity() * delta)
		set_up_direction(Vector3.UP)
		move_and_slide()
		net_transform = global_transform  # espelha p/ replicação (clientes interpolam)
		return

	target_position = player.global_transform.origin
	aim_target_position = _aim_point_from(ray_from.global_transform.origin)
	var dist_to_player: float = global_transform.origin.distance_to(player.global_transform.origin)
	var has_los: bool = _ray_hits_player(ray_from.global_transform.origin, aim_target_position)
	ai.note_line_of_sight(has_los, delta)
	var move_plan: Dictionary = ai.movement_plan(global_transform.origin, player.global_transform.origin,
		effective_range, get_world_3d().direct_space_state, [self, player], delta, has_los)

	if state == State.APPROACH:
		if aim_preparing > 0:
			aim_preparing -= delta
			if aim_preparing < 0:
				aim_preparing = 0

		var to_player_local: Vector3 = target_position * global_transform
		# The front of the robot is +Z, and atan2 is zero at +X, so we need to use the Z for the X parameter (second one).
		var angle_to_player: float = atan2(to_player_local.x, to_player_local.z)
		if angle_to_player > -PLAYER_AIM_TOLERANCE_DEGREES and angle_to_player < PLAYER_AIM_TOLERANCE_DEGREES:
			# Facing player, try to shoot.
			shoot_countdown -= delta
			if shoot_countdown < 0.0:
				# Só dispara quando a mira é precisa (player dentro do alcance efetivo).
				if dist_to_player > effective_range:
					# Muito longe — aguarda aproximar antes de mirar.
					shoot_countdown = 0.0
				elif has_los:
					state = State.AIM
					aim_countdown = AIM_TIME
					aim_preparing = 0.0
				else:
					shoot_countdown = ai.retry_delay()

	elif state == State.AIM or state == State.SHOOTING:
		if aim_preparing < AIM_PREPARE_TIME:
			aim_preparing += delta
			if aim_preparing > AIM_PREPARE_TIME:
				aim_preparing = AIM_PREPARE_TIME

		aim_countdown -= delta
		if aim_countdown < 0.0 and state == State.AIM:
			if has_los:
				state = State.SHOOTING
				shoot_countdown = shoot_reload
				play_shoot.rpc()
			else:
				resume_approach(false)

	animate(delta)
	if bool(move_plan.get("manual", false)):
		animation_tree["parameters/state/transition_request"] = "walk"
		var move_dir: Vector3 = move_plan.get("direction", Vector3.ZERO)
		move_dir.y = 0.0
		var desired_speed: float = float(move_plan.get("speed", 0.0)) * gait_speed_scale
		if move_dir.length() > 0.001 and desired_speed > 0.01:
			# Realismo: as PERNAS viram para a direção do movimento (a torre mira o player à parte) e o
			# deslocamento sai do PRÓPRIO root motion da anim `Walk` — como o corpo encara para onde anda,
			# o passo cai exatamente sobre o chão percorrido → sem deslize, em qualquer direção.
			move_dir = move_dir.normalized()
			# Filtra o rumo cru da IA → mudanças de direção entram graduais (anti-chacoalho). Semeia a
			# partir do rumo atual do corpo para não dar um pinote ao entrar no modo manual.
			if _move_dir_smooth.length() < 0.001:
				_move_dir_smooth = orientation.basis.z
				_move_dir_smooth.y = 0.0
				if _move_dir_smooth.length() < 0.001:
					_move_dir_smooth = move_dir
			_move_dir_smooth = _move_dir_smooth.normalized().slerp(move_dir,
				clampf(move_dir_response * delta, 0.0, 1.0))
			_move_dir_smooth.y = 0.0
			if _move_dir_smooth.length() > 0.001:
				_move_dir_smooth = _move_dir_smooth.normalized()
			_face_move_direction(_move_dir_smooth, delta)
			_match_locomotion_cadence(desired_speed)
			var local_disp: Vector3 = animation_tree.get_root_motion_position()
			var world_disp: Vector3 = orientation.basis * local_disp
			velocity.x = world_disp.x / delta
			velocity.z = world_disp.z / delta
		else:
			_reset_locomotion_cadence()
			_move_dir_smooth = Vector3.ZERO
			velocity.x = 0.0
			velocity.z = 0.0
	else:
		# APPROACH: o deslocamento VEM da animação (root motion) → pés já travados; cadência natural.
		_reset_locomotion_cadence()
		orientation *= Transform3D(animation_tree.get_root_motion_rotation(), animation_tree.get_root_motion_position())
		var h_velocity: Vector3 = orientation.origin / delta
		velocity.x = h_velocity.x
		velocity.z = h_velocity.z

	velocity += get_gravity() * delta
	set_velocity(velocity)
	set_up_direction(Vector3.UP)
	move_and_slide()

	orientation.origin = Vector3() # Clear accumulated root motion displacement (was applied to speed).
	orientation = orientation.orthonormalized() # orthonormalize orientation.

	global_transform.basis = orientation.basis
	net_transform = global_transform  # espelha p/ replicação (clientes interpolam)


# Aplica o transform interpolado (buffer de snapshots datados) no robô remoto.
func _interpolate_remote() -> void:
	if not _net_received:
		return  # nada recebido ainda: fica na posição de spawn
	var now: float = float(Time.get_ticks_msec())
	_interp.push(now, net_transform)
	if _interp.has_data():
		global_transform = _interp.sample(now)
	if not _interp_seeded:
		# 1ª aplicação: zera a interpolação física p/ não "rasgar" do spawn até a 1ª amostra.
		_interp_seeded = true
		reset_physics_interpolation()


# Cliente: casa a cadência das pernas à velocidade horizontal INTERPOLADA (a escala não é replicada).
func _match_remote_cadence(delta: float) -> void:
	if delta <= 0.0:
		return
	var here: Vector3 = global_transform.origin
	if _remote_has_last_pos:
		var flat := Vector2(here.x - _remote_last_pos.x, here.z - _remote_last_pos.z)
		var speed := flat.length() / delta
		if speed > 0.05:
			_match_locomotion_cadence(speed)
		else:
			_reset_locomotion_cadence()
	_remote_last_pos = here
	_remote_has_last_pos = true


# Gira o CORPO (pernas) suavemente para encarar a direção horizontal do movimento, até `body_turn_rate`
# rad/s. Como o front do robô é +Z e o root motion da `Walk` avança em +Z, encarar para onde anda faz o
# passo coincidir com o chão percorrido. A torre/canhão mira o player à parte (blendspace `aim`).
func _face_move_direction(dir: Vector3, delta: float) -> void:
	var cur_fwd: Vector3 = orientation.basis.z
	cur_fwd.y = 0.0
	if cur_fwd.length() < 0.001:
		cur_fwd = dir
	cur_fwd = cur_fwd.normalized()
	var new_fwd: Vector3 = cur_fwd.slerp(dir, clampf(body_turn_rate * delta, 0.0, 1.0))
	new_fwd.y = 0.0
	if new_fwd.length() < 0.001:
		return
	new_fwd = new_fwd.normalized()
	var x_axis: Vector3 = Vector3.UP.cross(new_fwd).normalized()
	if x_axis.length() < 0.001:
		return
	var y_axis: Vector3 = new_fwd.cross(x_axis).normalized()
	orientation.basis = Basis(x_axis, y_axis, new_fwd)


@rpc("call_local")
func play_shoot() -> void:
	shoot_animation.play(&"shoot")


func shoot_check() -> void:
	test_shoot = true


func _is_player_candidate(body: Node3D) -> bool:
	return body != null and (body.name == "Target" \
		or (body.has_method(&"add_camera_shake_trauma") and body.has_method(&"hit")))


# Alvo do quadro: player VIVO mais próximo dentro do raio de alerta. Com histerese (TARGET_SWITCH_MARGIN)
# para não oscilar entre players quase equidistantes. Retorna null se não há ninguém no raio.
func _pick_target() -> Node3D:
	var here: Vector3 = global_transform.origin
	var best: Node3D = null
	var best_d: float = INF
	for p in _players_in_range:
		if not is_instance_valid(p):
			continue
		# Facção: só mira quem é de lado OPOSTO (inimigo). Filtrado aqui (não na entrada da Area) para
		# reagir a mudanças de facção em runtime — ex.: um neutro provocado que vira aliado.
		if not Factions.are_enemies(self, p):
			continue
		var d: float = here.distance_to((p as Node3D).global_transform.origin)
		if d < best_d:
			best_d = d
			best = p
	# Mantém o alvo atual se o novo mais próximo não for margem suficiente mais perto (evita flip-flop).
	if player != null and is_instance_valid(player) and _players_in_range.has(player) \
			and Factions.are_enemies(self, player) and best != null and best != player:
		if here.distance_to(player.global_transform.origin) - best_d < TARGET_SWITCH_MARGIN:
			return player
	return best


# Caminho do parâmetro do nó AnimationNodeTimeScale que escala a cadência da locomoção na árvore.
const LOCO_SCALE_PARAM := "parameters/locomotion_scale/scale"
# Faixa da escala de tempo da locomoção. O piso evita passos lentos demais; o teto limita o quão
# acelerada a `Walk` pode ficar (acima disso a velocidade fica capada, mas os pés SEGUEM travados —
# o deslocamento vem do próprio root motion, então nunca há deslize, só um teto de velocidade).
const LOCO_SCALE_MIN := 0.6
const LOCO_SCALE_MAX := 2.6


# Escala a cadência da locomoção para casar com a velocidade real: leg cycle ∝ ground speed → sem
# patinar. Pilota o nó TimeScale da AnimationTree (o speed_scale do AnimationPlayer não vale aqui).
func _match_locomotion_cadence(speed: float) -> void:
	animation_tree[LOCO_SCALE_PARAM] = clampf(speed / maxf(walk_natural_speed, 0.1),
		LOCO_SCALE_MIN, LOCO_SCALE_MAX)


# Volta a locomoção à cadência natural (usado fora do movimento manual e quando não há alvo).
func _reset_locomotion_cadence() -> void:
	if not is_equal_approx(float(animation_tree[LOCO_SCALE_PARAM]), 1.0):
		animation_tree[LOCO_SCALE_PARAM] = 1.0


# Mede a passada natural da anim `Walk` (m/s a TimeScale = 1.0): deslocamento horizontal do bone de
# root motion (MASTER) entre a 1ª e a última chave ÷ duração. Mantém `walk_natural_speed` correto
# mesmo que o artista reexporte a animação com outra passada. Falha silenciosa → usa o fallback.
func _calibrate_walk_natural_speed() -> void:
	if _loco_player == null:
		return
	var anim := _loco_player.get_animation(&"Walk")
	if anim == null:
		return
	var track := anim.find_track(NodePath("Armature/Skeleton3D:MASTER"), Animation.TYPE_POSITION_3D)
	if track < 0:
		return
	var key_count := anim.track_get_key_count(track)
	if key_count < 2 or anim.length <= 0.01:
		return
	var first: Vector3 = anim.track_get_key_value(track, 0)
	var last: Vector3 = anim.track_get_key_value(track, key_count - 1)
	var disp := last - first
	disp.y = 0.0
	var measured := disp.length() / anim.length
	if measured > 0.05:
		walk_natural_speed = measured


func _on_area_body_entered(body: Node3D) -> void:
	if _is_player_candidate(body) and not _players_in_range.has(body):
		_players_in_range.append(body)


func _on_area_body_exited(body: Node3D) -> void:
	_players_in_range.erase(body)
