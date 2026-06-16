extends Node3D
## Gerador procedural da PISTOLA INFANTIL (fatia vertical). Constrói o modelo a
## partir de primitivas, uma AnimationPlayer com a animação "shoot" (recuo +
## clarão + som) e um AudioStreamWAV de laser embarcado, e salva o .tscn
## autocontido em res://library3D/weapons/pistola_infantil/. Rodar via
## project_run(custom) e ler os logs.

const OUT_DIR := "res://library3D/weapons/pistola_infantil"
const OUT_PATH := OUT_DIR + "/pistola_infantil.tscn"


func _ready() -> void:
	var root := _build()
	var err := _save(root)
	print("GEN pistola_infantil -> %s (err=%d)" % [OUT_PATH, err])
	print("GEN_DONE")
	get_tree().quit()


# ── Construção do modelo ──────────────────────────────────────────────────────

func _build() -> Node3D:
	var root := Node3D.new()
	root.name = "PistolaInfantil"

	var blue := _mat(Color(0.16, 0.45, 0.85), 0.55, 0.35)
	var white := _mat(Color(0.90, 0.93, 0.97), 0.15, 0.55)
	var dark := _mat(Color(0.10, 0.11, 0.14), 0.30, 0.5)
	var glow := _emat(Color(0.25, 0.85, 1.0), 4.0)

	# Corpo (receiver) — caixa branca, é o "membro" central.
	var corpo := _box("Corpo", Vector3(0.36, 0.20, 0.12), white, Vector3(0.0, 0.0, 0.0))
	root.add_child(corpo)
	# Faixa azul no topo do corpo.
	corpo.add_child(_box("CorpoTop", Vector3(0.36, 0.05, 0.13), blue, Vector3(0.0, 0.12, 0.0)))
	# "Olho" ciano (rosto smiley) na lateral do corpo.
	corpo.add_child(_box("Olho", Vector3(0.12, 0.12, 0.01), glow, Vector3(0.0, 0.0, 0.066)))

	# Cano (barrel) — cilindro azul apontando para -Z (frente da arma).
	var cano := _cyl("Cano", 0.055, 0.055, 0.34, blue, Vector3(0.0, 0.02, -0.30))
	cano.rotation = Vector3(PI * 0.5, 0.0, 0.0)   # eixo Y do cilindro -> Z
	root.add_child(cano)
	# Anel ciano brilhante na boca do cano.
	var ring := _cyl("CanoRing", 0.07, 0.07, 0.04, glow, Vector3(0.0, 0.02, -0.47))
	ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(ring)

	# Cabo (grip) — caixa escura inclinada para baixo/trás.
	var cabo := _box("Cabo", Vector3(0.09, 0.22, 0.11), dark, Vector3(0.02, -0.20, 0.10))
	cabo.rotation = Vector3(0.0, 0.0, deg_to_rad(12.0))
	root.add_child(cabo)
	cabo.add_child(_box("CaboGlow", Vector3(0.10, 0.04, 0.12), glow, Vector3(0.0, -0.08, 0.0)))

	# Boca do cano (origem do disparo) + clarão.
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.02, -0.50)
	root.add_child(muzzle)
	var flash := _cyl("MuzzleFlash", 0.0, 0.16, 0.22, glow, Vector3(0.0, 0.02, -0.58))
	flash.rotation = Vector3(-PI * 0.5, 0.0, 0.0)   # cone abrindo para -Z
	flash.visible = false
	root.add_child(flash)

	# Áudio do disparo (laser "pew" descendente).
	var audio := AudioStreamPlayer3D.new()
	audio.name = "Shot"
	audio.stream = _laser_wav(1500.0, 380.0, 0.22, 0.30)
	audio.unit_size = 6.0
	root.add_child(audio)

	# AnimationPlayer + "shoot".
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	lib.add_animation("shoot", _make_shoot_anim())
	ap.add_animation_library("", lib)
	ap.autoplay = "shoot"
	root.add_child(ap)

	_set_owner(root, root)
	return root


func _make_shoot_anim() -> Animation:
	var a := Animation.new()
	a.length = 0.6
	a.loop_mode = Animation.LOOP_LINEAR

	# Recuo do corpo (kick em +Z e volta).
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, "Corpo:position")
	a.value_track_set_update_mode(t, Animation.UPDATE_CONTINUOUS)
	a.track_insert_key(t, 0.0, Vector3.ZERO)
	a.track_insert_key(t, 0.05, Vector3(0.0, 0.0, 0.06))
	a.track_insert_key(t, 0.25, Vector3.ZERO)

	# Clarão visível só no instante do disparo.
	var tv := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tv, "MuzzleFlash:visible")
	a.value_track_set_update_mode(tv, Animation.UPDATE_DISCRETE)
	a.track_insert_key(tv, 0.0, true)
	a.track_insert_key(tv, 0.09, false)

	# Escala do clarão (pulso).
	var ts := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ts, "MuzzleFlash:scale")
	a.track_insert_key(ts, 0.0, Vector3(0.4, 0.4, 0.4))
	a.track_insert_key(ts, 0.05, Vector3(1.3, 1.3, 1.3))
	a.track_insert_key(ts, 0.09, Vector3(0.2, 0.2, 0.2))

	# Toca o som no disparo (method track).
	var tm := a.add_track(Animation.TYPE_METHOD)
	a.track_set_path(tm, "Shot")
	a.track_insert_key(tm, 0.0, {"method": "play", "args": [0.0]})
	return a


# ── Áudio procedural ──────────────────────────────────────────────────────────

func _laser_wav(freq_start: float, freq_end: float, dur: float, decay: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var p := float(i) / float(n)
		var freq: float = lerp(freq_start, freq_end, p)
		phase += TAU * freq / float(rate)
		var env: float = exp(-p / maxf(decay, 0.001))
		# Mistura senoide + um pouco de "quadrada" para o znumbido eletrônico.
		var s: float = sin(phase) * 0.7 + signf(sin(phase)) * 0.3
		var v := int(clampf(s * env, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


# ── Helpers de geometria ──────────────────────────────────────────────────────

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
		if node != owner:
			pass
		c.owner = owner
		_set_owner(c, owner)


func _save(root: Node3D) -> int:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(OUT_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var packed := PackedScene.new()
	packed.pack(root)
	return ResourceSaver.save(packed, OUT_PATH)
