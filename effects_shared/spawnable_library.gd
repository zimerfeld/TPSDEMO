class_name SpawnableLibrary
extends RefCounted
## Configura a lista de cenas replicaveis (`_spawnable_scenes`) de um MultiplayerSpawner de forma
## DINAMICA, varrendo toda a biblioteca 3D (library3D) em vez de uma whitelist fixa no .tscn.
##
## Motivo: a whitelist fixa nos levels so tinha os modelos ANTIGOS. Ao usar um template com um
## modelo novo (baixado em library3D/characters), o servidor instanciava mas o MultiplayerSpawner
## RECUSAVA replicar ao cliente (cena fora da whitelist) -> inimigo invisivel no cliente. Varrendo a
## biblioteca, qualquer modelo do template e replicavel sem editar cena nenhuma.
##
## ORDEM DETERMINISTICA: o MultiplayerSpawner replica por INDICE na lista, entao servidor e cliente
## PRECISAM registrar as cenas na MESMA ordem. A lista e ORDENADA (sort lexicografico) -> como os dois
## peers rodam o mesmo build (garantido pelo handshake de versao), varrem os mesmos arquivos res:// e
## produzem a mesma lista ordenada -> indices batem. Usa _logical_name (no .exe os arquivos aparecem
## como *.tscn.remap) para funcionar igual no editor e no build exportado.

const ROOTS: Array[String] = [
	"res://library3D/characters",
	"res://library3D/sceneries",
	"res://library3D/weapons",
]


# (Re)configura o spawner com TODAS as cenas-modelo da biblioteca, em ordem deterministica.
# Idempotente: limpa a lista existente e a reconstroi.
static func configure(spawner: MultiplayerSpawner) -> void:
	if spawner == null:
		return
	spawner.clear_spawnable_scenes()
	for path in all_model_scenes():
		spawner.add_spawnable_scene(path)


# Todas as cenas-modelo da biblioteca (convencao: cena cujo basename == nome da pasta que a contem),
# varrendo recursivamente as raizes, em ordem lexicografica (deterministica entre peers).
static func all_model_scenes() -> PackedStringArray:
	var paths: Array[String] = []
	for root in ROOTS:
		_scan(root, paths)
	paths.sort()
	return PackedStringArray(paths)


static func _scan(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	var key := dir_path.get_file()
	for raw_name in dir.get_files():
		var file := _logical_name(raw_name)
		if file.ends_with(".tscn") and file.get_basename() == key:
			out.append("%s/%s" % [dir_path, file])
	for child in dir.get_directories():
		if child.begins_with("."):
			continue
		_scan("%s/%s" % [dir_path, child], out)


# No .exe exportado os arquivos aparecem como "*.tscn.remap"; o nome logico remove o sufixo para o
# filtro de extensao funcionar igual no editor e no build (mesmo padrao de models.gd / templates).
static func _logical_name(file_name: String) -> String:
	var ext := file_name.get_extension().to_lower()
	if ext == "remap" or ext == "import":
		return file_name.get_basename()
	return file_name
