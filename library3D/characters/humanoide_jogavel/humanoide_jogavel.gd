class_name HumanoideJogavel
extends Player
## Personagem jogável com o modelo **humanoide** — o rig de 16 ossos com 36 animações em português.
##
## Reaproveita a classe `Player` inteira (input, câmera, rede, dano por membro, HUD). Duas coisas
## precisam ser diferentes:
##
## 1. **A velocidade não pode vir do root motion.** No player, o corpo anda exatamente o que a passada
##    da animação andou — por isso os pés não patinam. As animações do humanoide, porém, são
##    IN-PLACE: medido no `.glb`, `ocioso`/`andar`/`correr` não deslocam o osso `root` em X/Z.
##    Plugadas naquele motor, o personagem mexeria as pernas parado no lugar. Aqui a velocidade é
##    calculada por código e a animação vira visual, com a cadência escalada para o passo casar com a
##    velocidade real (mesma técnica que o red_robot usa no movimento manual).
## 2. **O vocabulário de animação é outro** — `ocioso`/`andar`/`saltar` em vez de `Idle`/`walking_gun`/
##    `jump_*`. Isso vive na árvore de animação da cena, que expõe os MESMOS nomes de parâmetro que o
##    `Player.animate()` escreve, então nem uma linha daquele código precisou mudar.
##
## Retarget (usar os clipes do player neste rig, ou o contrário) fica fora daqui de propósito — é
## trabalho de asset, do FIGArtStudio.

## Velocidade de CAMINHADA (m/s) — o padrão, sem SHIFT.
const WALK_SPEED: float = 1.7
## Velocidade de CORRIDA (m/s), com SHIFT segurado. 4,5 é uma corrida humana plausível; antes o
## personagem andava sempre a 5,2 e a animação precisava ser acelerada até virar borrão.
const MAX_SPEED: float = 4.5
## Velocidade que cada clipe REPRESENTA (m/s), medida pela cadência do ciclo: `andar` tem 1,10 s por
## ciclo (~0,55 s por passo, caminhada normal) e `correr` 0,85 s (~0,43 s por passo, corrida). São os
## divisores da cadência — a animação só é acelerada/desacelerada para cobrir a diferença entre a
## velocidade real e a que o clipe naturalmente teria.
const WALK_NATURAL_SPEED: float = 1.4
const RUN_NATURAL_SPEED: float = 4.0
## Limites da escala de cadência. Faixa ESTREITA de propósito: com o clipe certo tocando para cada
## velocidade (ver o blend em build_humanoide_jogavel.gd), a correção necessária é pequena — se
## precisasse de 2× é sinal de que a animação errada está tocando.
const CADENCE_MIN: float = 0.75
const CADENCE_MAX: float = 1.3
const CADENCE_PARAM := "parameters/locomotion_scale/scale"
## Posição do clipe `andar` no espaço de locomoção (ver build_humanoide_jogavel.gd).
const WALK_BLEND: float = 0.45
const WALK_BLEND_PARAM := "parameters/walk/blend_position"


## Clipes que precisam REPETIR enquanto a tecla estiver pressionada. O importador do Godot só liga o
## loop sozinho em animações com sufixo `-cycle` (convenção do `player.glb`); as do humanoide chegam
## todas como LOOP_NONE, então `andar` tocava 1,10 s e PARAVA com a tecla ainda pressionada.
## `ocioso`/`andar`/`correr` são cíclicos por natureza: uma passada emenda na seguinte.
## `ajoelhar_*` entra por um motivo TÉCNICO, não estético: a camada de gesto (OneShot) se encerra
## quando o clipe acaba, e um gesto que acaba não segura pose nenhuma. Com o clipe em loop a camada
## fica viva, e quem impede a repetição é o congelamento do tempo — ver CROUCH_HOLD. O jogador nunca
## vê o segundo ciclo.
const LOOPING_CLIPS: PackedStringArray = [
	"ocioso", "andar", "correr", "ajoelhar_dir", "ajoelhar_esq",
]

## Agachar é POSTURA: o corpo desce uma vez e FICA lá até soltar o CTRL (ver Player.hold_gestures).
## Levantar fica de fora — esse tem que terminar e devolver o corpo à locomoção.
const CROUCH_HOLD: PackedStringArray = ["ajoelhar_dir", "ajoelhar_esq"]

## Abaixo disto o corpo conta como PARADO ao saltar (salto no lugar, nao a versao em movimento).
const MOVING_THRESHOLD: float = 0.15


func _ready() -> void:
	_ensure_locomotion_loops()
	hold_gestures = CROUCH_HOLD
	# Perfil de rig: reaproveita o `limb_config` da pasta `humanoide/` (a mesma que a tela Models já
	# edita), em vez de exigir uma configuração nova só porque a cena jogável mora noutra pasta.
	limb_model_key = "humanoide"
	limb_head_shape = "sphere"
	limb_auto_distal = true
	# Ele NÃO tem arma própria — a cena veio do player, que traz 50 de dano autorado. Zerar aqui é o
	# que faz valer a regra "sem arma não dá dano": ele só atira depois que um template lhe atribuir
	# uma arma. Os personagens que já nascem armados (player, red_robot) seguem com o dano deles.
	weapon_damage = 0
	super._ready()


## Velocidade horizontal por CÓDIGO (ver o cabeçalho): a direção vem da câmera + input, a rapidez de
## MAX_SPEED, e a cadência da animação é escalada para o passo acompanhar.
func _apply_horizontal_velocity(_delta: float, camera_x: Vector3, camera_z: Vector3) -> void:
	var wish: Vector3 = camera_x * motion.x + camera_z * motion.y
	wish.y = 0.0
	var intensity: float = clampf(motion.length(), 0.0, 1.0)
	# CORRER é escolha do jogador (SHIFT), não intensidade do analógico: solto, caminha.
	var running: bool = player_input != null and player_input.running
	var top_speed: float = MAX_SPEED if running else WALK_SPEED
	var speed: float = top_speed * intensity
	if wish.length() > 0.001:
		wish = wish.normalized()
	else:
		wish = Vector3.ZERO
	velocity.x = wish.x * speed
	velocity.z = wish.z * speed
	if animation_tree != null:
		# O blend do estado WALK vai de parado (0) a `andar` (0,45) a `correr` (1,0). Escrevemos aqui,
		# DEPOIS do `animate()` da base — que usa a intensidade do movimento —, porque quem decide
		# andar ou correr é o SHIFT: sem isso, andar devagar com SHIFT tocaria a caminhada.
		var target: float = (1.0 if running else WALK_BLEND) * intensity
		animation_tree[WALK_BLEND_PARAM] = Vector2(target, 0.0)
		# A velocidade "natural" é a do clipe que está tocando: a animação só é acelerada ou
		# desacelerada para cobrir a diferença entre ela e a velocidade real.
		var natural: float = RUN_NATURAL_SPEED if running else WALK_NATURAL_SPEED
		animation_tree[CADENCE_PARAM] = clampf(
				speed / maxf(natural, 0.1), CADENCE_MIN, CADENCE_MAX)


# Marca como cíclicos os clipes de locomoção. Feito em CÓDIGO e não no `.import` porque assim vale
# para qualquer máquina, sem depender de alguém lembrar de reimportar o `.glb` — e fica visível a
# quem lê o personagem, junto da lista do que é estado e do que é evento.
func _ensure_locomotion_loops() -> void:
	var players := find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var anim_player := players[0] as AnimationPlayer
	for clip_name in LOOPING_CLIPS:
		if not anim_player.has_animation(clip_name):
			continue
		var clip := anim_player.get_animation(clip_name)
		if clip != null and clip.loop_mode == Animation.LOOP_NONE:
			clip.loop_mode = Animation.LOOP_LINEAR


## Vocabulário de postura deste modelo — a perna que se ajoelha (e a que levanta) segue o lado da
## mira. Ver Player.crouch_gesture.
func crouch_gesture(side: int) -> String:
	return "ajoelhar_dir" if side > 0 else "ajoelhar_esq"


func stand_gesture(side: int) -> String:
	return "levantar_dir" if side > 0 else "levantar_esq"


## O salto do humanoide tem TRÊS versões, conforme o que o corpo estava fazendo quando saiu do chão:
## parado (`saltar`), em caminhada (`andar_saltar_*`) e em corrida (`correr_saltar_*`). A escolha é
## feita no instante em que a subida começa e vale para o salto inteiro — trocar de clipe no ar
## partiria a animação ao meio.
func animate(anim: int, delta: float) -> void:
	if anim == Animations.JUMP_UP and current_animation != Animations.JUMP_UP:
		_pick_jump_clip()
	super.animate(anim, delta)


func _pick_jump_clip() -> void:
	if animation_tree == null or animation_tree.tree_root == null:
		return
	var clip_name := "saltar"
	if motion.length() > MOVING_THRESHOLD:
		var running: bool = player_input != null and player_input.running
		# Lado FIXO, não o da mira: `aim_side` é local ao dono e não é replicado, então cada peer
		# escolheria um lado diferente e o mesmo salto sairia com a perna trocada em cada tela. O
		# agachado pode usar a mira porque lá quem viaja pela rede é o NOME do clipe.
		clip_name = "correr_saltar_dir" if running else "andar_saltar_dir"
	for node_name in [&"jump_up", &"jump_down"]:
		var clip := animation_tree.tree_root.get_node(node_name) as AnimationNodeAnimation
		if clip != null:
			clip.animation = StringName(clip_name)
