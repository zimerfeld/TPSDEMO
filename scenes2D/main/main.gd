extends Node

## main.tscn é a raiz/roteador do jogo. Não há mais tela de abertura separada: o
## menu já é a primeira tela (a abertura/branding agora vive dentro de menu.tscn).
## Daqui em diante, change_scene_to_packed troca o menu por qualquer outra tela.

const MENU_PATH: String = "res://scenes2D/menu/menu.tscn"


func _ready() -> void:
	multiplayer.server_relay = false
	if DisplayServer.get_name() == "headless":
		Engine.max_fps = 60
	randomize()
	get_window().mode = Settings.config_file.get_value("video", "display_mode")
	# Em modo Janela, dá à janela um tamanho/posição sãos (senão ela nasceria do tamanho da tela
	# inteira, sem barra de título alcançável). Assim o modo janela é uma janela normal, movível.
	if get_window().mode == Window.MODE_WINDOWED:
		Settings.apply_window_resolution(get_window())
	# Piloto automático (`-- autohost`/`autojoin ... win=x,y,w,h`): posiciona esta instância na metade
	# da tela pedida pelo launcher, sobrepondo o tamanho/centralização do Settings. Inerte sem os args.
	Autopilot.apply_window(get_window())
	# Tela de "Carregando" do startup: carrega um level DE VERDADE por alguns frames para PAGAR
	# ADIANTADO o setup de 1o render 3D (~2,5 s) — senao ele cairia no meio da 1a partida (inimigos
	# congelando na tela do cliente). Medido: a entrada seguinte numa sala cai de ~2,5 s p/ ~0,6 s.
	# Servidor dedicado (headless) nao renderiza → nada a pagar; `-- nopreload` pula (medicao/baseline).
	if not (DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("nopreload")):
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()  # o level precisa de um peer valido
		await LoadingScreen.run_startup_preload()
	# O MENU PRINCIPAL ganha uma faixa NOVA a cada abertura do jogo: sorteia entre as de audios/ e grava
	# como atribuição da cena "menu" (o Gerenciador de Músicas passa a mostrar a sorteada, em vez de
	# exibir uma faixa e tocar outra). Servidor dedicado (headless) não toca nada → não sorteia.
	if DisplayServer.get_name() != "headless":
		MusicManager.randomize_track("menu")
	go_to_main_menu()


func go_to_main_menu() -> void:
	_swap_root_scene(ResourceLoader.load(MENU_PATH))


func _swap_root_scene(resource: PackedScene) -> void:
	if multiplayer != null and multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	change_scene_to_packed(resource)


func replace_main_scene(resource: PackedScene) -> void:
	call_deferred("change_scene_to_packed", resource)


func change_scene_to_packed(resource: PackedScene) -> void:
	var node: Node = resource.instantiate()
	# Rede de seguranca do cursor: o modo do mouse e GLOBAL e so o gameplay 3D o captura (player /
	# spectator_camera). Ao entrar numa tela 2D, o cursor TEM de estar visivel — sem isto, qualquer
	# saida de level que nao passe pelo LevelExit/session deixaria a UI 2D sem cursor.
	if not (node is Node3D):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_child(node)
	# Toca a trilha de fundo da nova tela em loop (pelo nome da cena; silêncio se não houver arquivo).
	MusicManager.play_for_scene(node)
	if node.has_signal(&"quit"):
		node.quit.connect(go_to_main_menu)
	if node.has_signal(&"replace_main_scene"):
		node.replace_main_scene.connect(replace_main_scene)
