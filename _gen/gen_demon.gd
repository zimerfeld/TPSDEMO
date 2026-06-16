extends Node3D
## Gerador REFINADO do DEMÔNIO-CAVEIRA INFANTIL (showcase de fidelidade, nível
## criatura_alada): ~50 nós de malha, TEXTURA procedural de placas/rebites/arranhões
## (ImageTexture embarcada, triplanar), emissão verde de plasma, chifres, rosto de
## caveira, braço-canhão de plasma, mão com garras, pés com garras. AnimationPlayer
## walk/run/jump + AudioStreamWAV de rugido. Salva .tscn autocontido em
## res://library3D/characters/demonio_infantil/.

const OUT_DIR := "res://library3D/characters/demonio_infantil"
const OUT_PATH := OUT_DIR + "/demonio_infantil.tscn"

var _detail: ImageTexture
var _red: StandardMaterial3D
var _black: StandardMaterial3D
var _steel: StandardMaterial3D
var _bone: StandardMaterial3D
var _green: StandardMaterial3D
var _green_dim: StandardMaterial3D


func _ready() -> void:
	_detail = _detail_tex()
	_red = _tmat(Color(0.55, 0.06, 0.06), 0.55, 0.45, 1.6)
	_black = _tmat(Color(0.09, 0.09, 0.11), 0.6, 0.5, 1.8)
	_steel = _tmat(Color(0.62, 0.64, 0.68), 0.9, 0.3, 2.2)
	_bone = _tmat(Color(0.78, 0.20, 0.16), 0.3, 0.55, 2.0)
	_green = _emat(Color(0.45, 1.0, 0.20), 5.0)
	_green_dim = _emat(Color(0.35, 0.85, 0.15), 2.0)
	var root := _build()
	var err := _save(root)
	print("GEN demonio_infantil -> %s (err=%d, meshes=%d)" % [OUT_PATH, err, root.find_children("*", "MeshInstance3D", true, false).size()])
	print("GEN_DONE")
	get_tree().quit()


func _build() -> Node3D:
	var root := Node3D.new()
	root.name = "DemonioInfantil"
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)

	body.add_child(_torso())
	body.add_child(_head())
	body.add_child(_arm_claw("L", -1.0))
	body.add_child(_arm_cannon("R", 1.0))
	body.add_child(_leg("L", -1.0))
	body.add_child(_leg("R", 1.0))

	var audio := AudioStreamPlayer3D.new()
	audio.name = "Sound"
	audio.stream = _growl_wav()
	audio.unit_size = 8.0
	root.add_child(audio)

	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	lib.add_animation("walk", _anim_walk(1.05, 0.4, 0.05, false))
	lib.add_animation("run", _anim_walk(0.66, 0.72, 0.09, true))
	lib.add_animation("jump", _anim_jump())
	ap.add_animation_library("", lib)
	ap.autoplay = "walk"
	root.add_child(ap)

	_set_owner(root, root)
	return root


func _torso() -> MeshInstance3D:
	# Corpo predominante PRETO, vermelho só como trim.
	var torso := _box("Torso", Vector3(0.52, 0.44, 0.32), _black, Vector3(0.0, 0.60, 0.0))
	# Trim vermelho: bordas laterais + gola.
	torso.add_child(_box("TorsoTrimL", Vector3(0.05, 0.44, 0.34), _red, Vector3(-0.255, 0.0, 0.0)))
	torso.add_child(_box("TorsoTrimR", Vector3(0.05, 0.44, 0.34), _red, Vector3(0.255, 0.0, 0.0)))
	torso.add_child(_box("TorsoCollar", Vector3(0.40, 0.07, 0.34), _red, Vector3(0.0, 0.22, 0.0)))
	# Placas peitorais sobrepostas (pretas) + filete vermelho central.
	torso.add_child(_box("TorsoPlateL", Vector3(0.20, 0.26, 0.34), _black, Vector3(-0.16, 0.04, 0.0)))
	torso.add_child(_box("TorsoPlateR", Vector3(0.20, 0.26, 0.34), _black, Vector3(0.16, 0.04, 0.0)))
	torso.add_child(_box("TorsoSpine", Vector3(0.04, 0.30, 0.35), _red, Vector3(0.0, 0.02, 0.0)))
	# Abdômen segmentado.
	torso.add_child(_box("TorsoAb1", Vector3(0.30, 0.10, 0.30), _black, Vector3(0.0, -0.22, 0.01)))
	torso.add_child(_box("TorsoAb2", Vector3(0.24, 0.09, 0.28), _black, Vector3(0.0, -0.32, 0.02)))
	# Gema/coração de plasma verde (losango).
	var gem := MeshInstance3D.new()
	gem.name = "ChestGem"
	var p := PrismMesh.new()
	p.size = Vector3(0.18, 0.20, 0.06)
	gem.mesh = p
	gem.material_override = _green
	gem.position = Vector3(0.0, 0.04, -0.17)
	torso.add_child(gem)
	torso.add_child(_box("ChestGlow", Vector3(0.06, 0.30, 0.02), _green_dim, Vector3(0.0, 0.0, -0.165)))
	# Gargantilha/pescoço.
	torso.add_child(_cyl("TorsoNeck", 0.09, 0.11, 0.10, _steel, Vector3(0.0, 0.26, 0.0)))
	return torso


func _head() -> MeshInstance3D:
	# Cabeça GRANDE (proporção chibi) e predominante PRETA.
	var head := _box("Head", Vector3(0.50, 0.46, 0.42), _black, Vector3(0.0, 1.06, 0.0))
	# Trim vermelho (só detalhe): faixa superior + têmporas.
	head.add_child(_box("HeadTrimTop", Vector3(0.52, 0.06, 0.44), _red, Vector3(0.0, 0.22, 0.0)))
	head.add_child(_box("HeadTempleL", Vector3(0.05, 0.30, 0.42), _red, Vector3(-0.255, -0.04, 0.0)))
	head.add_child(_box("HeadTempleR", Vector3(0.05, 0.30, 0.42), _red, Vector3(0.255, -0.04, 0.0)))
	# Placa facial preta recuada — fundo da CAVEIRA.
	head.add_child(_box("HeadFace", Vector3(0.42, 0.42, 0.03), _black, Vector3(0.0, -0.01, -0.215)))
	# Olhos rasgados grandes (verde brilhante, raivosos para dentro).
	var el := _box("EyesL", Vector3(0.15, 0.10, 0.04), _green, Vector3(-0.11, 0.07, -0.23))
	el.rotation = Vector3(0.0, 0.0, deg_to_rad(-24.0))
	head.add_child(el)
	var er := _box("EyesR", Vector3(0.15, 0.10, 0.04), _green, Vector3(0.11, 0.07, -0.23))
	er.rotation = Vector3(0.0, 0.0, deg_to_rad(24.0))
	head.add_child(er)
	# Nariz triangular invertido (verde) entre os olhos.
	var nose := MeshInstance3D.new()
	nose.name = "Nose"
	var npm := PrismMesh.new()
	npm.size = Vector3(0.08, 0.09, 0.04)
	nose.mesh = npm
	nose.material_override = _green
	nose.position = Vector3(0.0, -0.05, -0.23)
	nose.rotation = Vector3(deg_to_rad(180.0), 0.0, 0.0)
	head.add_child(nose)
	# Grin (sorriso de caveira) — fileira larga de dentes-prisma verdes alternados.
	for i in 7:
		var tx := -0.15 + i * 0.05
		var tooth := MeshInstance3D.new()
		tooth.name = "Mouth%d" % i
		var pm := PrismMesh.new()
		pm.size = Vector3(0.04, 0.07, 0.03)
		tooth.mesh = pm
		tooth.material_override = _green
		tooth.position = Vector3(tx, -0.17, -0.225)
		tooth.rotation = Vector3(deg_to_rad(180.0) if i % 2 == 0 else 0.0, 0.0, 0.0)
		head.add_child(tooth)
	# Chifres grandes curvos + espinhos laterais de aço.
	head.add_child(_horn("HeadHornL", -1.0))
	head.add_child(_horn("HeadHornR", 1.0))
	for s in [-1.0, 1.0]:
		var spike := _cyl("HeadSpike%s" % ("L" if s < 0 else "R"), 0.0, 0.035, 0.14, _steel, Vector3(0.25 * s, 0.02, 0.0))
		spike.rotation = Vector3(0.0, 0.0, deg_to_rad(-45.0 * s))
		head.add_child(spike)
	return head


func _horn(n: String, sx: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = n
	pivot.position = Vector3(0.12 * sx, 0.16, 0.02)
	var s0 := _cyl(n + "0", 0.05, 0.07, 0.16, _black, Vector3(0.0, 0.08, 0.0))
	s0.rotation = Vector3(0.0, 0.0, deg_to_rad(18.0 * sx))
	pivot.add_child(s0)
	var s1 := _cyl(n + "1", 0.03, 0.05, 0.14, _red, Vector3(0.08 * sx, 0.20, 0.0))
	s1.rotation = Vector3(0.0, 0.0, deg_to_rad(45.0 * sx))
	pivot.add_child(s1)
	var s2 := _cyl(n + "2", 0.0, 0.03, 0.12, _steel, Vector3(0.18 * sx, 0.28, 0.0))
	s2.rotation = Vector3(0.0, 0.0, deg_to_rad(70.0 * sx))
	pivot.add_child(s2)
	return pivot


func _arm_claw(side: String, sx: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Arm" + side
	pivot.position = Vector3(0.42 * sx, 0.76, 0.0)
	_pauldron(pivot, side, sx)
	pivot.add_child(_box("ArmUpper" + side, Vector3(0.16, 0.26, 0.17), _black, Vector3(0.02 * sx, -0.22, 0.0)))
	pivot.add_child(_box("ArmLower" + side, Vector3(0.17, 0.22, 0.18), _black, Vector3(0.02 * sx, -0.44, 0.0)))
	pivot.add_child(_box("ArmTrim" + side, Vector3(0.18, 0.05, 0.19), _red, Vector3(0.02 * sx, -0.35, 0.0)))
	# Punho + 3 garras verdes curvas.
	pivot.add_child(_box("ArmFist" + side, Vector3(0.16, 0.12, 0.18), _steel, Vector3(0.02 * sx, -0.58, 0.02)))
	for i in 3:
		var cx := -0.05 + i * 0.05
		var claw := _cyl("ArmClaw%s%d" % [side, i], 0.0, 0.025, 0.16, _green, Vector3(0.02 * sx + cx, -0.66, 0.08))
		claw.rotation = Vector3(deg_to_rad(35.0), 0.0, 0.0)
		pivot.add_child(claw)
	return pivot


func _arm_cannon(side: String, sx: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Arm" + side
	pivot.position = Vector3(0.42 * sx, 0.76, 0.0)
	_pauldron(pivot, side, sx)
	pivot.add_child(_box("ArmUpper" + side, Vector3(0.17, 0.24, 0.18), _black, Vector3(0.02 * sx, -0.22, 0.0)))
	# Canhão de plasma (cilindro grande) + boca verde brilhante + núcleo.
	var barrel := _cyl("ArmCannon" + side, 0.13, 0.15, 0.40, _black, Vector3(0.03 * sx, -0.46, -0.04))
	pivot.add_child(barrel)
	var ring := _cyl("ArmCannonRing" + side, 0.16, 0.16, 0.05, _green, Vector3(0.03 * sx, -0.46, -0.24))
	pivot.add_child(ring)
	pivot.add_child(_cyl("ArmCannonCore" + side, 0.10, 0.10, 0.06, _green, Vector3(0.03 * sx, -0.46, -0.245)))
	# Detalhes/cabos no canhão.
	pivot.add_child(_box("ArmCannonPipe" + side, Vector3(0.05, 0.05, 0.30), _steel, Vector3(0.14 * sx, -0.40, -0.04)))
	return pivot


func _pauldron(pivot: Node3D, side: String, sx: float) -> void:
	pivot.add_child(_box("Shoulder" + side, Vector3(0.24, 0.22, 0.28), _black, Vector3(0.07 * sx, 0.04, 0.0)))
	pivot.add_child(_box("ShoulderTrim" + side, Vector3(0.26, 0.06, 0.30), _red, Vector3(0.07 * sx, 0.14, 0.0)))
	# 3 espinhos de aço no pauldron.
	for i in 3:
		var sp := _cyl("ShoulderSpike%s%d" % [side, i], 0.0, 0.035, 0.16, _steel, Vector3((0.02 + i * 0.07) * sx, 0.16, -0.08 + i * 0.08))
		sp.rotation = Vector3(deg_to_rad(-30.0), 0.0, deg_to_rad(-25.0 * sx))
		pivot.add_child(sp)


func _leg(side: String, sx: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Leg" + side
	pivot.position = Vector3(0.17 * sx, 0.44, 0.0)
	pivot.add_child(_box("Thigh" + side, Vector3(0.20, 0.26, 0.20), _black, Vector3(0.0, -0.14, 0.0)))
	pivot.add_child(_box("ThighPlate" + side, Vector3(0.22, 0.10, 0.22), _red, Vector3(0.0, -0.05, 0.01)))
	pivot.add_child(_box("Shin" + side, Vector3(0.17, 0.24, 0.17), _black, Vector3(0.0, -0.36, 0.0)))
	pivot.add_child(_box("Foot" + side, Vector3(0.20, 0.10, 0.30), _black, Vector3(0.0, -0.48, 0.05)))
	pivot.add_child(_box("FootTrim" + side, Vector3(0.21, 0.04, 0.10), _red, Vector3(0.0, -0.44, -0.06)))
	# Garras dos pés (aço).
	for i in 3:
		var cx := -0.06 + i * 0.06
		var claw := _cyl("FootClaw%s%d" % [side, i], 0.0, 0.025, 0.12, _steel, Vector3(cx, -0.50, 0.20))
		claw.rotation = Vector3(deg_to_rad(75.0), 0.0, 0.0)
		pivot.add_child(claw)
	return pivot


# ── Textura procedural (placas/rebites/arranhões) ─────────────────────────────

func _detail_tex() -> ImageTexture:
	var size := 192
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var v := 0.84 + (_hash(x * 7 + y * 131) - 0.5) * 0.14
			var gx := x % 48
			var gy := y % 48
			if gx < 2 or gy < 2:
				v *= 0.5                      # costura entre placas
			var rx: int = mini(gx, 48 - gx)
			var ry: int = mini(gy, 48 - gy)
			var rd := rx * rx + ry * ry
			if rd < 9:
				v = 1.0                       # rebite (brilho)
			elif rd < 18:
				v *= 0.65                     # sombra do rebite
			if _hash(y * 977 + int(x / 22)) > 0.94:
				v = minf(1.0, v + 0.22)       # arranhão horizontal
			v = clampf(v, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(img)


func _hash(i: int) -> float:
	var h := (i * 2654435761) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 10007) / 10007.0


# ── Áudio: rugido grave demoníaco ─────────────────────────────────────────────

func _growl_wav() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.5
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var phase2 := 0.0
	var seed_v := 99173
	for i in n:
		var p := float(i) / float(n)
		var freq: float = lerp(90.0, 55.0, p) + sin(p * TAU * 6.0) * 8.0   # vibrato grave
		phase += TAU * freq / float(rate)
		phase2 += TAU * (freq * 1.5) / float(rate)
		seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
		var noise := (float(seed_v) / 1073741823.0 - 1.0)
		var env: float = sin(PI * p) * exp(-p * 1.2)                       # ataque+decay
		var s: float = (sin(phase) * 0.6 + sin(phase2) * 0.25 + noise * 0.15) * env
		var v := int(clampf(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


# ── Animações (andar/correr/saltar) ───────────────────────────────────────────

func _anim_walk(length: float, swing: float, bob: float, lean: bool) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR
	var h := length * 0.5
	_swing(a, "Body/LegL:rotation", 0.0, swing, length)
	_swing(a, "Body/LegR:rotation", h, swing, length)
	_swing(a, "Body/ArmR:rotation", 0.0, swing * 0.7, length)
	_swing(a, "Body/ArmL:rotation", h, swing * 0.7, length)
	var tb := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tb, "Body:position")
	a.track_insert_key(tb, 0.0, Vector3.ZERO)
	a.track_insert_key(tb, length * 0.25, Vector3(0.0, bob, 0.0))
	a.track_insert_key(tb, length * 0.5, Vector3.ZERO)
	a.track_insert_key(tb, length * 0.75, Vector3(0.0, bob, 0.0))
	a.track_insert_key(tb, length, Vector3.ZERO)
	var tr := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tr, "Body:rotation")
	a.track_insert_key(tr, 0.0, Vector3(deg_to_rad(16.0) if lean else 0.0, 0.0, 0.0))
	var tm := a.add_track(Animation.TYPE_METHOD)
	a.track_set_path(tm, "Sound")
	a.track_insert_key(tm, length * 0.02, {"method": "play", "args": [0.0]})
	return a


func _swing(a: Animation, path: String, phase: float, amp: float, length: float) -> void:
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, path)
	for i in 5:
		var time: float = fmod(phase + length * 0.25 * i, length)
		a.track_insert_key(t, time, Vector3(amp * sin(TAU * 0.25 * i), 0.0, 0.0))
	a.track_insert_key(t, 0.0, Vector3(amp * sin(TAU * (-phase / length)), 0.0, 0.0))
	a.track_insert_key(t, length, Vector3(amp * sin(TAU * (1.0 - phase / length)), 0.0, 0.0))


func _anim_jump() -> Animation:
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	var tp := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tp, "Body:position")
	a.track_insert_key(tp, 0.0, Vector3.ZERO)
	a.track_insert_key(tp, 0.18, Vector3(0.0, -0.12, 0.0))
	a.track_insert_key(tp, 0.45, Vector3(0.0, 0.6, 0.0))
	a.track_insert_key(tp, 0.72, Vector3.ZERO)
	a.track_insert_key(tp, 0.85, Vector3(0.0, -0.1, 0.0))
	a.track_insert_key(tp, 1.0, Vector3.ZERO)
	for leg in ["Body/LegL:rotation", "Body/LegR:rotation"]:
		var t := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t, leg)
		a.track_insert_key(t, 0.0, Vector3.ZERO)
		a.track_insert_key(t, 0.18, Vector3(deg_to_rad(40.0), 0.0, 0.0))
		a.track_insert_key(t, 0.45, Vector3(deg_to_rad(60.0), 0.0, 0.0))
		a.track_insert_key(t, 0.72, Vector3.ZERO)
		a.track_insert_key(t, 1.0, Vector3.ZERO)
	for arm in ["Body/ArmL:rotation", "Body/ArmR:rotation"]:
		var t := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t, arm)
		a.track_insert_key(t, 0.0, Vector3.ZERO)
		a.track_insert_key(t, 0.45, Vector3(deg_to_rad(-110.0), 0.0, 0.0))
		a.track_insert_key(t, 0.72, Vector3.ZERO)
		a.track_insert_key(t, 1.0, Vector3.ZERO)
	var tm := a.add_track(Animation.TYPE_METHOD)
	a.track_set_path(tm, "Sound")
	a.track_insert_key(tm, 0.2, {"method": "play", "args": [0.0]})
	return a


# ── Helpers ───────────────────────────────────────────────────────────────────

func _tmat(c: Color, metallic: float, rough: float, scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = _detail
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
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
