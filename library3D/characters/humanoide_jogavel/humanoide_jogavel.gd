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


func _ready() -> void:
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
