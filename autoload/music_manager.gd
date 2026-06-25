extends Node
## Trilha de fundo em LOOP INFINITO por cena/level, escolhida pelo NOME da cena. Centraliza a
## música (antes cada cena embutia o próprio nó "Music"): o roteador (main.gd) chama
## play_for_scene() a cada troca de tela e este autoload toca `res://Audios/<nome_da_cena>.<ext>`
## em loop (ext em .ogg/.mp3/.wav, a 1ª que existir vence). Sem arquivo para a cena → silêncio.
## Se a próxima cena resolve para a MESMA trilha, ela continua tocando sem reiniciar (transições
## suaves, ex.: menu → escolher personagem).
##
## Atribuição manual (Gerenciador de Música, na tela Settings): o jogador pode ATRIBUIR uma faixa
## específica a uma cena/level ou REMOVÊ-LA (silêncio). Isso vira um override persistido em
## Settings (seção "music"), que tem prioridade sobre a resolução por nome. Ver music_manager_window.gd.
##
## Para definir/trocar a música por arquivo, basta colocar a faixa em `res://Audios/` com o nome da
## cena (ex.: `Audios/menu.ogg`, `Audios/level_1.ogg`). Ver `Audios/README.md`.
##
## Usa o bus "Music" → respeita o mute global de música das settings (ver [[sistemas/audio]]).

# Onde procurar as trilhas e a ordem de extensão testada (a 1ª que existir vence).
const AUDIOS_DIR := "res://Audios/"
const EXTENSIONS := [".ogg", ".mp3", ".wav"]
# Cenas que COMPARTILHAM a trilha de outra (sem duplicar arquivo). A tela de escolher personagem
# mantém a música do menu tocando continuamente.
const ALIASES := {"chooseplayer": "menu"}
# Seção do Settings onde ficam os overrides do Gerenciador de Música (scene_key -> arquivo, ou "" = silêncio).
const OVERRIDE_SECTION := "music"
# Cenas/levels gerenciáveis pelo Gerenciador de Música (rótulo amigável + chave = nome do arquivo da cena).
const SCENES := [
	{"key": "menu", "label": "Menu principal"},
	{"key": "chooseplayer", "label": "Escolher personagem"},
	{"key": "playonline", "label": "Jogar Online"},
	{"key": "levels", "label": "Seleção de level"},
	{"key": "settings", "label": "Configurações"},
	{"key": "developer", "label": "Modo Developer"},
	{"key": "controls", "label": "Controles (widgets 2D)"},
	{"key": "host_session", "label": "Sessão host (salas)"},
	{"key": "client_session", "label": "Sessão cliente (salas)"},
	{"key": "models", "label": "Biblioteca de modelos"},
	{"key": "level_base", "label": "Level Base"},
	{"key": "level_1", "label": "Level 1"},
	{"key": "level_2", "label": "Level 2"},
]

var _player: AudioStreamPlayer
# Player separado para PRÉ-ESCUTA no Gerenciador de Música (não bagunça a trilha de fundo).
var _preview: AudioStreamPlayer
# Nome do arquivo que está em pré-escuta agora (para o ▶ retomar uma pausa da MESMA faixa em vez
# de reiniciar). "" = nada em pré-escuta.
var _preview_file: String = ""
# Caminho da trilha tocando agora (ou "" = silêncio) e a chave da cena atual. Evitam reiniciar a
# mesma faixa entre cenas e permitem reaplicar ao vivo quando o override muda.
var _current_path: String = ""
var _current_key: String = ""


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Music"
	add_child(_player)
	_preview = AudioStreamPlayer.new()
	_preview.bus = &"Music"
	add_child(_preview)


# Chamado pelo roteador a cada troca de tela. Resolve a trilha pelo nome do arquivo da cena.
func play_for_scene(scene: Node) -> void:
	if scene == null:
		return
	play_key(String(scene.scene_file_path).get_file().get_basename())


# Toca a trilha da chave `key` (nome da cena/level) em loop; se já for a que está tocando, mantém
# (a menos que `force`, usado quando o override da cena muda no Gerenciador).
func play_key(key: String, force: bool = false) -> void:
	_current_key = key
	var path := _resolve(key)
	if path == _current_path and not force:
		return
	_current_path = path
	if path.is_empty():
		_player.stop()
		_player.stream = null
		return
	var stream := load(path) as AudioStream
	if stream == null:
		_player.stop()
		_player.stream = null
		_current_path = ""
		return
	_ensure_loop(stream)
	_player.stream = stream
	_player.play()


# Caminho da trilha de `key`: override do Gerenciador (se houver) > Audios/<key>.<ext> > alias > "".
func _resolve(key: String) -> String:
	if key.is_empty():
		return ""
	# Override manual do Gerenciador de Música tem prioridade.
	if Settings.config_file.has_section_key(OVERRIDE_SECTION, key):
		var ov := String(Settings.config_file.get_value(OVERRIDE_SECTION, key, ""))
		if ov.is_empty():
			return ""  # silêncio explícito
		var po: String = AUDIOS_DIR + ov
		if ResourceLoader.exists(po):
			return po
		# arquivo do override sumiu → cai na resolução por nome abaixo
	for ext in EXTENSIONS:
		var p: String = AUDIOS_DIR + key + ext
		if ResourceLoader.exists(p):
			return p
	if ALIASES.has(key):
		return _resolve(ALIASES[key])
	return ""


# Garante loop infinito qualquer que seja o formato. O import do .ogg já costuma vir com loop=true,
# mas .mp3/.wav podem não — forçamos aqui para a regra "loop infinito em cada cena" valer sempre,
# inclusive para arquivos que o usuário solte em Audios/ sem ajustar o import.
func _ensure_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)


# ───────────────────────────── Gerenciador de Música (API) ─────────────────────────────

# Cenas/levels gerenciáveis (rótulo + chave). Usada pela janela do Gerenciador.
func scene_list() -> Array:
	return SCENES


# Faixas disponíveis (nomes de arquivo) em Audios/. Funciona no editor E no .exe exportado: como o
# .ogg fonte não vai no PCK (só o import), varremos também os `.import` e confirmamos via ResourceLoader.
func list_tracks() -> Array:
	var out: Array = []
	var seen := {}
	var dir := DirAccess.open(AUDIOS_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir():
			var fname := f
			if fname.ends_with(".import"):
				fname = fname.substr(0, fname.length() - 7)  # tira ".import"
			if EXTENSIONS.has("." + fname.get_extension()) and not seen.has(fname):
				if ResourceLoader.exists(AUDIOS_DIR + fname):
					seen[fname] = true
					out.append(fname)
		f = dir.get_next()
	dir.list_dir_end()
	# Ordem alfabética "natural" e SEM diferenciar maiúsculas/minúsculas (ex.: "it's different" e
	# "menu.ogg" entram no lugar certo; números seguem ordem humana: 2 antes de 10).
	out.sort_custom(func(a, b): return String(a).naturalnocasecmp_to(String(b)) < 0)
	return out


# Estado de atribuição de uma cena para o Gerenciador refletir: "default" (sem override, usa o nome
# da cena), "none" (silêncio explícito) ou o nome do arquivo atribuído.
func assignment_of(key: String) -> String:
	if not Settings.config_file.has_section_key(OVERRIDE_SECTION, key):
		return "default"
	var ov := String(Settings.config_file.get_value(OVERRIDE_SECTION, key, ""))
	return "none" if ov.is_empty() else ov


# Atribui a faixa de uma cena. `value`: "default" remove o override (volta a resolver pelo nome);
# "none" = silêncio; senão é o nome do arquivo. Persiste e reaplica AO VIVO se for a cena atual.
func set_assignment(key: String, value: String) -> void:
	if value == "default":
		if Settings.config_file.has_section_key(OVERRIDE_SECTION, key):
			Settings.config_file.erase_section_key(OVERRIDE_SECTION, key)
	elif value == "none":
		Settings.config_file.set_value(OVERRIDE_SECTION, key, "")
	else:
		Settings.config_file.set_value(OVERRIDE_SECTION, key, value)
	Settings.save_settings()
	if key == _current_key:
		play_key(_current_key, true)


# Nome do arquivo da trilha EFETIVA de `key` (resolvendo override/default/alias) ou "" se silêncio.
func effective_track(key: String) -> String:
	var p := _resolve(key)
	return p.get_file() if not p.is_empty() else ""


# Pré-escuta uma faixa (silencia o fundo enquanto toca). Usada pelo Gerenciador de Música.
func preview(filename: String) -> void:
	if filename.is_empty():
		return
	var p: String = AUDIOS_DIR + filename
	if not ResourceLoader.exists(p):
		return
	var s := load(p) as AudioStream
	if s == null:
		return
	_ensure_loop(s)
	_player.stream_paused = true
	_preview.stream = s
	_preview.stream_paused = false
	_preview.play()
	_preview_file = filename


# ▶ do Gerenciador: se a MESMA faixa está pausada, RETOMA de onde parou; senão toca do início.
func preview_or_resume(filename: String) -> void:
	if _preview != null and _preview.stream != null and _preview_file == filename:
		resume_preview()
		return
	preview(filename)


# ⏸ do Gerenciador: pausa a pré-escuta sem reiniciar (mantém o fundo mudo). No-op se nada toca.
func pause_preview() -> void:
	if _preview == null or _preview.stream == null:
		return
	_preview.stream_paused = true


# Retoma a pré-escuta pausada (▶ na mesma faixa). Mantém o fundo mudo enquanto a pré-escuta toca.
func resume_preview() -> void:
	if _preview == null or _preview.stream == null:
		return
	_preview.stream_paused = false
	if not _preview.playing:
		_preview.play()
	if _player != null:
		_player.stream_paused = true


func stop_preview() -> void:
	if _preview == null:
		return
	_preview.stop()
	_preview.stream = null
	_preview.stream_paused = false
	_preview_file = ""
	if _player != null:
		_player.stream_paused = false
