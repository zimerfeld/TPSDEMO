extends Camera3D

## Câmera livre de observação — modo "Hospedar Somente".
##
## Voa pelo level SEM colisão e SEM player controlado: o host hospeda o servidor e
## observa em tempo real o que acontece (robôs, players conectados). Vive APENAS na
## instância do servidor (é filha direta do level, fora do SpawnedNodes), por isso
## NÃO é replicada pela rede.
##
## Controles:
##   - WASD: move no plano horizontal, relativo à direção da câmera (yaw).
##   - Mouse: olha em volta (mouse capturado).
##   - ESPAÇO + W: sobe suavemente (na velocidade do pulo do player).
##   - ESPAÇO + S: desce suavemente (na velocidade do pulo do player).
##     (com ESPAÇO segurado, A/D continuam fazendo o strafe lateral.)

# Velocidade do voo livre no plano (un/s).
const MOVE_SPEED: float = 12.0
# Subida/descida na MESMA velocidade do pulo do player (Player.JUMP_SPEED = 5.0).
const VERTICAL_SPEED: float = 5.0
# Suavização (aceleração/desaceleração) da velocidade — quanto maior, mais responsivo.
const ACCEL: float = 8.0
const MOUSE_SENSITIVITY: float = 0.0025
const PITCH_MIN: float = deg_to_rad(-89.0)
const PITCH_MAX: float = deg_to_rad(89.0)

var _velocity: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _pitch: float = 0.0


func _ready() -> void:
	current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Parte da orientação atual (definida ao posicionar a câmera no level).
	_yaw = rotation.y
	_pitch = rotation.x


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.screen_relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.screen_relative.y * MOUSE_SENSITIVITY, PITCH_MIN, PITCH_MAX)
		rotation = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	var target: Vector3 = Vector3.ZERO

	if Input.is_action_pressed(&"jump"):
		# ESPAÇO segurado: W sobe / S desce (na velocidade do pulo). A/D ainda fazem strafe.
		var vertical: float = Input.get_action_strength(&"move_forward") - Input.get_action_strength(&"move_back")
		var strafe: float = Input.get_action_strength(&"move_right") - Input.get_action_strength(&"move_left")
		target.y = vertical * VERTICAL_SPEED
		var right: Vector3 = global_transform.basis.x
		right.y = 0.0
		target += right.normalized() * strafe * MOVE_SPEED
	else:
		# Voo livre no plano: W/S frente-trás, A/D lateral (relativo ao yaw da câmera).
		var input2d := Vector2(
				Input.get_action_strength(&"move_right") - Input.get_action_strength(&"move_left"),
				Input.get_action_strength(&"move_back") - Input.get_action_strength(&"move_forward"))
		var right: Vector3 = global_transform.basis.x
		var forward: Vector3 = global_transform.basis.z  # basis.z aponta para trás; *input.y resolve o sinal
		right.y = 0.0
		forward.y = 0.0
		target = (right.normalized() * input2d.x + forward.normalized() * input2d.y) * MOVE_SPEED

	# Suaviza a velocidade (start/stop sem solavanco) e integra a posição.
	_velocity = _velocity.lerp(target, clampf(ACCEL * delta, 0.0, 1.0))
	global_position += _velocity * delta
