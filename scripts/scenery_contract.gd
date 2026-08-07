extends SceneTree
## Importador de modelos de CENARIO + gerador do contrato de replicacao das pecas.
##
## Cada pasta de `library3D/sceneries/<nome>/` deve ter a cena `<nome>.tscn` (a "cena do modelo", a
## unica que o browse_dir dos gerenciadores enxerga) e essa cena precisa cumprir o CONTRATO:
## script `SceneryPiece` na raiz + `ServerSynchronizer` replicando spawn_position/spawn_rotation_y/
## spawn_scale so no spawn. Sem isso a peca nasce em (0,0,0) no cliente (ver a nota
## "templates-de-level" no cofre) — o servidor posiciona, mas o transform nao viaja no pacote.
##
## Uso (ferramenta de DESENVOLVIMENTO; res:// e somente leitura no .exe exportado):
##   godot --headless --path . --script scripts/scenery_contract.gd             → valida e relata
##   godot --headless --path . --script scripts/scenery_contract.gd -- --apply  → corrige e salva
##
## Com --apply o script tambem IMPORTA modelos novos: pasta que tem um .glb/.gltf mas ainda nao tem
## `<nome>.tscn` ganha uma cena gerada (StaticBody3D + malha + colisao pelo AABB + o contrato).
##
## Saida: codigo 0 quando todas as pecas cumprem o contrato ao final; 1 quando ainda falta algo
## (assim da para usar em verificacao automatica).

const ROOT := "res://library3D/sceneries"
## Biblioteca varrida nesta execucao (ROOT por padrao; --root=<res://...> aponta para outra).
var _root: String = ROOT
## Pasta-modelo unica a processar (--only=<nome>); vazio = todas as da biblioteca.
var _only: String = ""
const PIECE_SCRIPT := "res://library3D/sceneries/scenery_piece.gd"
const MODEL_EXTENSIONS := ["glb", "gltf"]
## Folga aplicada ao AABB do modelo importado ao gerar a colisao (evita colisor rente a malha).
const COLLISION_MARGIN := 0.02


func _initialize() -> void:
	var apply := false
	# --root=<res://...> aponta a ferramenta para OUTRA biblioteca. Serve para modelos que vivem fora de
	# library3D/sceneries mas se comportam como peca estatica (malha sem script/IA): eles precisam do
	# mesmo contrato, senao nascem em (0,0,0) no cliente como qualquer peca de cenario.
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text == "--apply":
			apply = true
		elif text.begins_with("--root="):
			_root = text.substr("--root=".length()).rstrip("/")
		elif text.begins_with("--only="):
			# Limita a UMA pasta-modelo. Sem isto, um --apply numa biblioteca grande tambem GERARIA cena
			# para toda pasta que tenha um .glb sem .tscn — passando a oferecer no gerenciador modelos
			# que ainda nao estavam prontos para uso.
			_only = text.substr("--only=".length())
	print("== Contrato das pecas (%s) em %s ==" % [
		"APLICAR" if apply else "somente validar", _root])
	var pending := 0
	var total := 0
	for dir_name in _model_dirs():
		total += 1
		if not _process_dir(dir_name, apply):
			pending += 1
	if total == 0:
		print("Nenhuma pasta de modelo em %s." % _root)
	print("---")
	print("%d modelo(s); %d fora do contrato." % [total, pending])
	quit(0 if pending == 0 else 1)


# Subpastas de ROOT (uma por modelo). Ignora arquivos soltos como o proprio scenery_piece.gd.
func _model_dirs() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(_root)
	if dir == null:
		push_error("Nao consegui abrir %s" % _root)
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with(".") and (_only == "" or name == _only):
			out.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


# Um modelo: garante a cena e o contrato. Retorna true se ao final a peca cumpre o contrato.
func _process_dir(model: String, apply: bool) -> bool:
	var scene_path := "%s/%s/%s.tscn" % [_root, model, model]
	if not ResourceLoader.exists(scene_path):
		var source := _find_model_file(model)
		if source == "":
			print("[ %-10s ] SEM CENA e sem .glb/.gltf na pasta — nada a fazer." % model)
			return false
		if not apply:
			print("[ %-10s ] SEM CENA — rode com --apply para gerar a partir de %s" % [
				model, source.get_file()])
			return false
		if not _generate_scene(model, source, scene_path):
			return false
		print("[ %-10s ] IMPORTADO de %s" % [model, source.get_file()])

	var packed: PackedScene = load(scene_path)
	if packed == null:
		print("[ %-10s ] ERRO ao carregar %s" % [model, scene_path])
		return false
	var root := packed.instantiate()
	var issues := SceneryPiece.contract_issues(root)
	if issues.is_empty():
		print("[ %-10s ] ok" % model)
		root.free()
		return true
	# Modelo com COMPORTAMENTO proprio (script na raiz) que ja replica o transform — player, red_robot,
	# criatura_alada. Nao e peca estatica: cumpre o requisito por outro caminho (net_transform) e a
	# ferramenta nao tem nada a fazer nele.
	if root.get_script() != null and TemplateManagerBase.replicates_transform(root):
		print("[ %-10s ] ok (replica o transform pelo script proprio)" % model)
		root.free()
		return true
	if not apply:
		print("[ %-10s ] FALTA: %s" % [model, ", ".join(issues)])
		root.free()
		return false
	var fixed := _apply_contract(root)
	if not fixed:
		print("[ %-10s ] NAO CORRIGIDO: %s" % [model, ", ".join(issues)])
		root.free()
		return false
	var ok := _repack(root, scene_path)
	print("[ %-10s ] %s (%s)" % [model, "CORRIGIDO" if ok else "FALHA AO SALVAR", ", ".join(issues)])
	root.free()
	return ok


# Anexa o que falta do contrato na INSTANCIA (script + sincronizador de spawn). False se a raiz nao
# comporta o script (nao e 3D) — nesse caso o modelo precisa de ajuste manual.
func _apply_contract(root: Node) -> bool:
	if not (root is Node3D):
		return false
	# NUNCA sobrescreve um script existente: uma raiz com script proprio tem comportamento (Player,
	# RedRobot, ...) e trocar por SceneryPiece destruiria a cena. Esses casos saem no relatorio para
	# ajuste manual — o caminho certo neles e declarar o transform no proprio replication_config.
	if root.get_script() != null and not (root is SceneryPiece):
		return false
	if not (root is SceneryPiece):
		root.set_script(load(PIECE_SCRIPT))
	var sync := root.get_node_or_null(NodePath(SceneryPiece.SYNC_NAME)) as MultiplayerSynchronizer
	if sync == null:
		sync = MultiplayerSynchronizer.new()
		sync.name = SceneryPiece.SYNC_NAME
		root.add_child(sync)
		sync.owner = root
	sync.replication_config = SceneryPiece.make_spawn_config()
	return SceneryPiece.meets_contract(root)


# Gera a cena do modelo a partir do arquivo importado: raiz StaticBody3D (com o contrato), a malha
# instanciada e um colisor de caixa cobrindo o AABB agregado. E o ponto de partida editavel — quem
# quiser um colisor mais justo ajusta a cena depois; o contrato de rede ja fica pronto.
func _generate_scene(model: String, source: String, scene_path: String) -> bool:
	var model_scene: PackedScene = load(source)
	if model_scene == null:
		push_error("Nao consegui carregar %s" % source)
		return false
	var mesh_root := model_scene.instantiate()
	var root := StaticBody3D.new()
	root.name = model.capitalize().replace(" ", "")
	root.set_script(load(PIECE_SCRIPT))
	root.collision_layer = 1
	root.collision_mask = 0
	root.add_child(mesh_root)
	mesh_root.owner = root
	mesh_root.name = "Mesh"
	var aabb := _aabb_of(mesh_root)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = aabb.size + Vector3.ONE * COLLISION_MARGIN
	col.shape = shape
	col.position = aabb.position + aabb.size * 0.5
	root.add_child(col)
	col.owner = root
	if not _apply_contract(root):
		root.free()
		return false
	var ok := _repack(root, scene_path)
	root.free()
	return ok


# AABB agregado de todas as malhas da subarvore, no espaco do no passado. O transform e ACUMULADO na
# descida (transform local de cada no) em vez de lido de global_transform: a cena ainda nao esta na
# arvore aqui, e fora dela global_transform e invalido (devolve identidade e loga erro).
func _aabb_of(node: Node) -> AABB:
	var boxes: Array[AABB] = []
	_collect_aabb(node, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		return AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)  # sem malha: caixa unitaria de seguranca
	var out: AABB = boxes[0]
	for i in range(1, boxes.size()):
		out = out.merge(boxes[i])
	return out


func _collect_aabb(node: Node, accumulated: Transform3D, out: Array[AABB]) -> void:
	var here := accumulated
	if node is Node3D:
		here = accumulated * (node as Node3D).transform
	if node is MeshInstance3D:
		out.append(here * (node as MeshInstance3D).get_aabb())
	for c in node.get_children():
		_collect_aabb(c, here, out)


# Empacota a instancia (com os owners ja atribuidos) e grava por cima da cena.
func _repack(root: Node, scene_path: String) -> bool:
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("Falha ao empacotar %s" % scene_path)
		return false
	return ResourceSaver.save(packed, scene_path) == OK


# Primeiro .glb/.gltf da pasta do modelo (o arquivo importado que da origem a cena).
func _find_model_file(model: String) -> String:
	var dir_path := "%s/%s" % [_root, model]
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var name := dir.get_next()
	var found := ""
	while name != "":
		if not dir.current_is_dir():
			# No .exe os arquivos aparecem com sufixos de import/remap — por isso a extensao e lida do
			# nome logico, nao do arquivo cru (mesma regra do browse_dir dos gerenciadores).
			var logical := name.trim_suffix(".import").trim_suffix(".remap")
			if MODEL_EXTENSIONS.has(logical.get_extension().to_lower()):
				found = "%s/%s" % [dir_path, logical]
				break
		name = dir.get_next()
	dir.list_dir_end()
	return found
