class_name AIConfig
extends RefCounted
## Config de comportamentos de IA por modelo, persistida em UM ARQUIVO POR MODELO na pasta do
## próprio asset (res://library3D/<categoria>/<model_key>/ai_config.json; override de runtime em
## user://ai_config/<model_key>.json). O formato atual é simples:
##   { "behaviors": { "<behavior_key>": true|false } }
## O res:// é a fonte canônica no editor; no jogo exportado as edições da tela Models caem no
## override user://, que tem precedência na leitura.

const LIBRARY_ROOT := "res://library3D"
const MODEL_FILE := "ai_config.json"
const USER_DIR := "user://ai_config"

const _MODEL_BEHAVIOR_DEFS := {
	"red_robot": [
		{
			"key": "predictive_aim",
			"label": "Mira preditiva",
			"description": "Antecipar a posição futura do alvo a partir da velocidade do player e do projétil.",
			"default_enabled": true,
		},
		{
			"key": "adaptive_accuracy",
			"label": "Precisão adaptativa",
			"description": "Ganhar precisão com a experiência acumulada contra alvos em distâncias e velocidades parecidas.",
			"default_enabled": true,
		},
		{
			"key": "reactive_strafe",
			"label": "Strafe reativo",
			"description": "Circular o alvo lateralmente durante o combate para dificultar o contra-ataque e abrir ângulos de tiro.",
			"default_enabled": true,
		},
		{
			"key": "adaptive_spacing",
			"label": "Controle de distância",
			"description": "Manter uma faixa de combate preferida, avançando ou recuando conforme o alcance efetivo da arma.",
			"default_enabled": true,
		},
		{
			"key": "geometry_probe",
			"label": "Leitura de geometria",
			"description": "Sondar o espaço livre ao redor para escolher lados mais abertos e sair de linhas bloqueadas.",
			"default_enabled": true,
		},
		{
			"key": "pressure_reposition",
			"label": "Reposicionamento sob pressão",
			"description": "Trocar de ângulo após bloqueios de linha de visão ou sequências de erros para reacquirir o alvo mais rápido.",
			"default_enabled": true,
		},
	],
	"criatura_alada": [
		{
			"key": "aerial_predictive_bombing",
			"label": "Bombardeio preditivo aéreo",
			"description": "Antecipar a posição futura do player durante a queda da bomba, respeitando o desvio máximo.",
			"default_enabled": true,
		},
		{
			"key": "adaptive_altitude",
			"label": "Altitude adaptativa",
			"description": "Manter uma altura relativa ao player, em vez de depender apenas da altitude fixa do mundo.",
			"default_enabled": true,
		},
		{
			"key": "reactive_orbit",
			"label": "Órbita reativa",
			"description": "Alternar raio e sentido da órbita conforme distância, espaço livre e pressão do combate.",
			"default_enabled": true,
		},
		{
			"key": "vertical_evasion",
			"label": "Evasão vertical",
			"description": "Usar subidas e descidas controladas para reposicionar em 3D sem abandonar o ataque aéreo.",
			"default_enabled": true,
		},
		{
			"key": "airspace_probe",
			"label": "Leitura de espaço aéreo",
			"description": "Sondar obstáculos ao redor da rota de voo para escolher lados e alturas mais livres.",
			"default_enabled": true,
		},
		{
			"key": "pressure_bomb_run",
			"label": "Passada de bomba sob pressão",
			"description": "Após erros ou bloqueios, ajustar altitude e ângulo para uma nova passada de bombardeio.",
			"default_enabled": true,
		},
	],
	"player": [
		{
			"key": "ally_follow",
			"label": "Seguir esquadrão",
			"description": "Manter o bot aliado próximo ao player humano quando não houver ameaça imediata.",
			"default_enabled": true,
		},
		{
			"key": "guard_stance",
			"label": "Postura de segurança",
			"description": "Acompanhar o player como um segurança: assume um posto na diagonal traseira, para quando chega nele e nunca avança para cima do inimigo (suprime a órbita e o flanco).",
			"default_enabled": true,
		},
		{
			"key": "enemy_prioritization",
			"label": "Priorizar inimigos",
			"description": "Escolher alvos hostis próximos e vivos antes de apenas seguir o esquadrão.",
			"default_enabled": true,
		},
		{
			"key": "predictive_assist_aim",
			"label": "Mira assistida preditiva",
			"description": "Antecipar a posição futura do inimigo para bots aliados dispararem com mais consistência.",
			"default_enabled": true,
		},
		{
			"key": "combat_spacing",
			"label": "Espaçamento de combate",
			"description": "Manter distância segura do inimigo, avançando ou recuando conforme o alcance da arma.",
			"default_enabled": true,
		},
		{
			"key": "friendly_fire_guard",
			"label": "Bloqueio de fogo amigo",
			"description": "Evitar disparar quando outro aliado estiver cruzando a linha de tiro.",
			"default_enabled": true,
		},
		{
			"key": "pressure_flank",
			"label": "Flanco sob pressão",
			"description": "Reposicionar lateralmente após erros ou bloqueios para abrir um novo ângulo contra o inimigo.",
			"default_enabled": true,
		},
	],
}

# ───────────────────────────── Facção do modelo (marcação estrutural) ─────────────────────────────
# Marca de que LADO o modelo está. A lógica de comportamento pluga aqui depois:
#   hostile = ataca players assim que os detecta no raio de alerta (padrão dos inimigos atuais);
#   neutral = NÃO ataca por detecção — só decide entrar em confronto se AMEAÇADO (levar tiro) ou por
#             aleatoriedade (ainda sem personagem neutro no jogo; campo pronto para receber a lógica);
#   ally    = do lado do player (bots aliados).
# Persistida no mesmo JSON por-modelo (chave "faction"), com precedência user:// como os behaviors.
const FACTIONS := ["hostile", "neutral", "ally"]
const _MODEL_FACTION_DEFAULTS := {
	"red_robot": "hostile",
	"criatura_alada": "hostile",
	"player": "ally",
}

static var _dir_cache: Dictionary = {}


static func _model_dir(model_key: String) -> String:
	if model_key == "":
		return ""
	if _dir_cache.has(model_key):
		return _dir_cache[model_key]
	var found := _find_model_dir_recursive(LIBRARY_ROOT, model_key, 0)
	_dir_cache[model_key] = found
	return found


static func _find_model_dir_recursive(base_path: String, model_key: String, depth: int) -> String:
	if depth > 5:
		return ""
	var dir := DirAccess.open(base_path)
	if dir == null:
		return ""
	var fallback := ""
	for child in dir.get_directories():
		if child.begins_with("."):
			continue
		var path := "%s/%s" % [base_path, child]
		if child == model_key:
			if FileAccess.file_exists("%s/%s" % [path, MODEL_FILE]) \
					or FileAccess.file_exists("%s/%s.tscn" % [path, model_key]):
				return path
			if fallback == "":
				fallback = path
		var nested := _find_model_dir_recursive(path, model_key, depth + 1)
		if nested != "":
			return nested
	return fallback


static func _model_path(model_key: String) -> String:
	var dir := _model_dir(model_key)
	return "" if dir == "" else "%s/%s" % [dir, MODEL_FILE]


static func _user_path(model_key: String) -> String:
	return "%s/%s.json" % [USER_DIR, model_key]


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


static func _load_entry(model_key: String) -> Dictionary:
	if model_key == "":
		return {}
	var user_path := _user_path(model_key)
	if FileAccess.file_exists(user_path):
		return _read_json(user_path)
	var model_path := _model_path(model_key)
	if model_path != "" and FileAccess.file_exists(model_path):
		return _read_json(model_path)
	return {}


static func _save_entry(model_key: String, entry: Dictionary) -> void:
	if model_key == "":
		return
	var json := JSON.stringify(entry, "\t")
	var model_path := _model_path(model_key)
	if model_path != "":
		var file := FileAccess.open(model_path, FileAccess.WRITE)
		if file != null:
			file.store_string(json)
			file.close()
			var user_path := _user_path(model_key)
			if FileAccess.file_exists(user_path):
				DirAccess.remove_absolute(user_path)
			return
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	var user_file := FileAccess.open(_user_path(model_key), FileAccess.WRITE)
	if user_file == null:
		push_error("AIConfig: não foi possível gravar config de '%s'" % model_key)
		return
	user_file.store_string(json)
	user_file.close()


static func behavior_definitions(model_key: String) -> Array[Dictionary]:
	var defs: Array[Dictionary] = []
	for raw in _MODEL_BEHAVIOR_DEFS.get(model_key, []):
		defs.append((raw as Dictionary).duplicate(true))
	return defs


static func has_behavior_definitions(model_key: String) -> bool:
	return not behavior_definitions(model_key).is_empty()


static func default_behavior_state(model_key: String, behavior_key: String) -> bool:
	for entry in _MODEL_BEHAVIOR_DEFS.get(model_key, []):
		if str(entry.get("key", "")) == behavior_key:
			return bool(entry.get("default_enabled", true))
	return false


static func behaviors(model_key: String) -> Dictionary:
	var out: Dictionary = {}
	for entry in _MODEL_BEHAVIOR_DEFS.get(model_key, []):
		out[str(entry.get("key", ""))] = bool(entry.get("default_enabled", true))
	var saved: Dictionary = _load_entry(model_key).get("behaviors", {})
	for key in saved:
		out[str(key)] = bool(saved[key])
	return out


static func behavior_enabled(model_key: String, behavior_key: String) -> bool:
	return bool(behaviors(model_key).get(behavior_key, false))


static func default_faction(model_key: String) -> String:
	return String(_MODEL_FACTION_DEFAULTS.get(model_key, "hostile"))


## Facção efetiva do modelo (override salvo tem precedência; senão o default).
static func faction(model_key: String) -> String:
	var saved := String(_load_entry(model_key).get("faction", ""))
	return saved if saved in FACTIONS else default_faction(model_key)


static func set_faction(model_key: String, value: String) -> void:
	if model_key == "" or not (value in FACTIONS):
		return
	var entry := _load_entry(model_key)
	if value == default_faction(model_key):
		entry.erase("faction")   # volta ao padrão → não polui o arquivo
	else:
		entry["faction"] = value
	_save_entry(model_key, entry)


static func is_hostile(model_key: String) -> bool:
	return faction(model_key) == "hostile"


static func is_neutral(model_key: String) -> bool:
	return faction(model_key) == "neutral"


static func set_behavior(model_key: String, behavior_key: String, enabled: bool) -> void:
	if model_key == "" or not has_behavior_definitions(model_key):
		return
	var exists := false
	for entry in _MODEL_BEHAVIOR_DEFS.get(model_key, []):
		if str(entry.get("key", "")) == behavior_key:
			exists = true
			break
	if not exists:
		return
	var entry := _load_entry(model_key)
	var map: Dictionary = entry.get("behaviors", {})
	if enabled == default_behavior_state(model_key, behavior_key):
		map.erase(behavior_key)
	else:
		map[behavior_key] = enabled
	if map.is_empty():
		entry.erase("behaviors")
	else:
		entry["behaviors"] = map
	_save_entry(model_key, entry)
