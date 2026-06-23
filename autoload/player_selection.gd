extends Node

var scene_path: String = "res://library3D/characters/players/player/player.tscn"

# Fluxo "Jogar Online": definido ao escolher Play Online no menu. Quando true, a tela
# de levels não carrega o nível direto — guarda o nível escolhido em level_path e abre
# a tela playonline (Host/Connect), que então carrega esse nível ao hospedar/conectar.
var online_mode: bool = false
var level_path: String = ""
