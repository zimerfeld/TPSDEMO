extends Node3D
## Gerador procedural do MECHA 07 INFANTIL (fatia vertical de personagem). Mecha
## humanoide chibi vermelho/laranja a partir de primitivas, com membros nomeados
## (Head/Torso/Arm*/Thigh*/Shin*/Foot*) e AnimationPlayer com walk/run/jump +
## AudioStreamWAV de passo/servo embarcado. Salva .tscn autocontido em
## res://library3D/characters/mecha07_infantil/.

const OUT_DIR := "res://library3D/characters/mecha07_infantil"
const OUT_PATH := OUT_DIR + "/mecha07_infantil.tscn"

var _red: StandardMaterial3D
var _orange: StandardMaterial3D
var _dark: StandardMaterial3D
var _glow: StandardMaterial3D


func _ready() -> void:
	_red = _mat(Color(0.78, 0.10, 0.10), 0.5, 0.4)
	_orange = _mat(Color(0.95, 0.45, 0.05), 0.5, 0.4)
	_dark = _mat(Color(0.10, 0.10, 0.12), 0.4, 0.5)
	_glow = _emat(Color(1.0, 0.55, 0.05), 4.0)
	var root := _build()
	var err := _save(root)
	print("GEN mecha07_infantil -> %s (err=%d)" % [OUT_PATH, err])
	print("GEN_DONE")
	get_tree().quit()


func _build() -> Node3D:
	var root := Node3D.new()
	root.name = "Mecha07Infantil"
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)

	# Torso (TRONCO) — centro de massa.
	var torso := _box("Torso", Vector3(0.46, 0.42, 0.30), _red, Vector3(0.0, 0.58, 0.0))
	body.add_child(torso)
	torso.add_child(_box("TorsoCore", Vector3(0.46, 0.12, 0.31), _dark, Vector3(0.0, -0.10, 0.0)))
	# Emblema triângulo brilhante na frente (-Z).
	var emblem := MeshInstance3D.new()
	emblem.name = "Emblem"
	var prism := PrismMesh.new()
	prism.size = Vector3(0.20, 0.18, 0.03)
	emblem.mesh = prism
	emblem.material_override = _glow
	emblem.position = Vector3(0.0, 0.02, -0.16)
	torso.add_child(emblem)

	# Cabeça (CABEÇA) — visor escuro com olhos brilhantes + antenas.
	var head := _box("Head", Vector3(0.34, 0.30, 0.30), _dark, Vector3(0.0, 0.96, 0.0))
	body.add_child(head)
	head.add_child(_box("HeadCrownL", Vector3(0.12, 0.10, 0.30), _orange, Vector3(-0.10, 0.18, 0.0)))
	head.add_child(_box("HeadCrownR", Vector3(0.12, 0.10, 0.30), _orange, Vector3(0.10, 0.18, 0.0)))
	head.add_child(_box("Eyes", Vector3(0.26, 0.07, 0.02), _glow, Vector3(0.0, 0.0, -0.16)))
	# Antenas (chifres vermelhos).
	var antl := _cyl("AntennaL", 0.0, 0.03, 0.22, _red, Vector3(-0.10, 0.30, 0.02))
	antl.rotation = Vector3(deg_to_rad(-12.0), 0.0, deg_to_rad(10.0))
	head.add_child(antl)
	var antr := _cyl("AntennaR", 0.0, 0.03, 0.22, _red, Vector3(0.10, 0.30, 0.02))
	antr.rotation = Vector3(deg_to_rad(-12.0), 0.0, deg_to_rad(-10.0))
	head.add_child(antr)

	# Braços (BRAÇO D/E) — pivôs no ombro, com pauldron + braço + antebraço.
	body.add_child(_arm("L", -1.0))
	body.add_child(_arm("R", 1.0))

	# Pernas (PERNA D/E) — pivôs no quadril, com coxa + canela + pé.
	body.add_child(_leg("L", -1.0))
	body.add_child(_leg("R", 1.0))

	# Som característico (passo/servo grave metálico).
	var audio := AudioStreamPlayer3D.new()
	audio.name = "Sound"
	audio.stream = _step_wav()
	audio.unit_size = 8.0
	root.add_child(audio)

	# Animações.
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	lib.add_animation("walk", _anim_walk(1.0, 0.45, 0.06, false))
	lib.add_animation("run", _anim_walk(0.62, 0.8, 0.10, true))
	lib.add_animation("jump", _anim_jump())
	ap.add_animation_library("", lib)
	ap.autoplay = "walk"
	root.add_child(ap)

	_set_owner(root, root)
	return root


func _arm(side: String, sx: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Arm" + side
	pivot.position = Vector3(0.40 * sx, 0.74, 0.0)
	# Pauldron grande (ombro).
	pivot.add_child(_box("Shoulder" + side, Vector3(0.22, 0.20, 0.26), _orange, Vector3(0.06 * sx, 0.02, 0.0)))
	# Braço superior + antebraço (nome contém "Arm" -> classifica como BRAÇO).
	pivot.add_child(_box("ArmUpper" + side, Vector3(0.15, 0.26, 0.16), _dark, Vector3(0.02 * sx, -0.22, 0.0)))
	pivot.add_child(_box("ArmLower" + side, Vector3(0.16, 0.22, 0.17), _orange, Vector3(0.02 * sx, -0.44, 0.02)))
	return pivot


func _leg(side: String, sx: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Leg" + side
	pivot.position = Vector3(0.15 * sx, 0.42, 0.0)
	pivot.add_child(_box("Thigh" + side, Vector3(0.18, 0.24, 0.18), _orange, Vector3(0.0, -0.13, 0.0)))
	pivot.add_child(_box("Shin" + side, Vector3(0.16, 0.22, 0.16), _dark, Vector3(0.0, -0.33, 0.0)))
	pivot.add_child(_box("Foot" + side, Vector3(0.18, 0.10, 0.26), _red, Vector3(0.0, -0.45, 0.04)))
	return pivot


# ── Animações ─────────────────────────────────────────────────────────────────

func _anim_walk(length: float, swing: float, bob: float, lean: bool) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR
	var h := length * 0.5

	# Pernas em contrafase.
	_swing(a, "Body/LegL:rotation", 0.0, swing, length)
	_swing(a, "Body/LegR:rotation", h, swing, length)
	# Braços contrários às pernas.
	_swing(a, "Body/ArmR:rotation", 0.0, swing * 0.8, length)
	_swing(a, "Body/ArmL:rotation", h, swing * 0.8, length)
	# Bob vertical (2x a frequência do passo).
	var tb := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tb, "Body:position")
	a.track_insert_key(tb, 0.0, Vector3(0.0, 0.0, 0.0))
	a.track_insert_key(tb, length * 0.25, Vector3(0.0, bob, 0.0))
	a.track_insert_key(tb, length * 0.5, Vector3(0.0, 0.0, 0.0))
	a.track_insert_key(tb, length * 0.75, Vector3(0.0, bob, 0.0))
	a.track_insert_key(tb, length, Vector3(0.0, 0.0, 0.0))
	# Inclinação à frente ao correr.
	var tr := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tr, "Body:rotation")
	var lean_x := deg_to_rad(14.0) if lean else 0.0
	a.track_insert_key(tr, 0.0, Vector3(lean_x, 0.0, 0.0))
	# Passos (som) nos dois apoios.
	var tm := a.add_track(Animation.TYPE_METHOD)
	a.track_set_path(tm, "Sound")
	a.track_insert_key(tm, length * 0.02, {"method": "play", "args": [0.0]})
	a.track_insert_key(tm, length * 0.52, {"method": "play", "args": [0.0]})
	return a


func _swing(a: Animation, path: String, phase: float, amp: float, length: float) -> void:
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, path)
	for i in 5:
		var time: float = fmod(phase + length * 0.25 * i, length)
		var ang: float = amp * sin(TAU * 0.25 * i)
		a.track_insert_key(t, time, Vector3(ang, 0.0, 0.0))
	# Garante chaves nas bordas para loop limpo.
	a.track_insert_key(t, 0.0, Vector3(amp * sin(TAU * (0.0 - phase / length)), 0.0, 0.0))
	a.track_insert_key(t, length, Vector3(amp * sin(TAU * (1.0 - phase / length)), 0.0, 0.0))


func _anim_jump() -> Animation:
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR

	# Salto vertical do corpo: agacha, sobe, cai, aterrissa.
	var tp := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tp, "Body:position")
	a.track_insert_key(tp, 0.0, Vector3(0.0, 0.0, 0.0))
	a.track_insert_key(tp, 0.18, Vector3(0.0, -0.12, 0.0))
	a.track_insert_key(tp, 0.45, Vector3(0.0, 0.55, 0.0))
	a.track_insert_key(tp, 0.72, Vector3(0.0, 0.0, 0.0))
	a.track_insert_key(tp, 0.85, Vector3(0.0, -0.10, 0.0))
	a.track_insert_key(tp, 1.0, Vector3(0.0, 0.0, 0.0))

	# Pernas dobram (tuck) no ápice.
	for leg in ["Body/LegL:rotation", "Body/LegR:rotation"]:
		var t := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t, leg)
		a.track_insert_key(t, 0.0, Vector3(0.0, 0.0, 0.0))
		a.track_insert_key(t, 0.18, Vector3(deg_to_rad(35.0), 0.0, 0.0))
		a.track_insert_key(t, 0.45, Vector3(deg_to_rad(55.0), 0.0, 0.0))
		a.track_insert_key(t, 0.72, Vector3(0.0, 0.0, 0.0))
		a.track_insert_key(t, 1.0, Vector3(0.0, 0.0, 0.0))
	# Braços sobem na decolagem.
	for arm in ["Body/ArmL:rotation", "Body/ArmR:rotation"]:
		var t := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t, arm)
		a.track_insert_key(t, 0.0, Vector3(0.0, 0.0, 0.0))
		a.track_insert_key(t, 0.18, Vector3(deg_to_rad(20.0), 0.0, 0.0))
		a.track_insert_key(t, 0.45, Vector3(deg_to_rad(-120.0), 0.0, 0.0))
		a.track_insert_key(t, 0.72, Vector3(0.0, 0.0, 0.0))
		a.track_insert_key(t, 1.0, Vector3(0.0, 0.0, 0.0))
	# Som na decolagem e na aterrissagem.
	var tm := a.add_track(Animation.TYPE_METHOD)
	a.track_set_path(tm, "Sound")
	a.track_insert_key(tm, 0.2, {"method": "play", "args": [0.0]})
	a.track_insert_key(tm, 0.74, {"method": "play", "args": [0.0]})
	return a


# ── Áudio: passo/servo grave metálico ─────────────────────────────────────────

func _step_wav() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.28
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var seed_v := 12345
	for i in n:
		var p := float(i) / float(n)
		# Thud grave descendente + ruído metálico decaindo rápido.
		var freq: float = lerp(120.0, 45.0, p)
		phase += TAU * freq / float(rate)
		seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
		var noise := (float(seed_v) / 1073741823.0 - 1.0)
		var env: float = exp(-p / 0.10)
		var s: float = sin(phase) * 0.8 + noise * 0.2 * exp(-p / 0.03)
		var v := int(clampf(s * env, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


# ── Helpers ───────────────────────────────────────────────────────────────────

func _mat(c: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	return m


func _emat(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _box(n: String, size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	return mi


func _cyl(n: String, top_r: float, bot_r: float, h: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bot_r
	mesh.height = h
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	return mi


func _set_owner(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_set_owner(c, owner)


func _save(root: Node3D) -> int:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(OUT_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var packed := PackedScene.new()
	packed.pack(root)
	return ResourceSaver.save(packed, OUT_PATH)
