extends Node

# Registro das variantes de player, na MESMA ordem do seletor (chooseplayer.CHARACTERS).
# O índice (variant_id) é o que trafega pela rede no register_loadout — um int, não um caminho
# arbitrário (mais seguro). NetSpawn resolve o índice → cena via variant_scene_path().
const VARIANTS: Array[String] = [
	"res://library3D/characters/player/player.tscn",
	"res://library3D/characters/playera/playera.tscn",
]

var scene_path: String = VARIANTS[0]
# Variante escolhida no chooseplayer (índice em VARIANTS). Enviada ao servidor ao conectar.
var variant_id: int = 0
# Nome do jogador (digitado na playonline, persistido em Settings). Enviado ao servidor junto com
# a variante ao entrar/hospedar e replicado como spawn property → vira o Label3D acima da cabeça.
var player_name: String = ""

# Fluxo "Jogar Online": definido ao escolher Play Online no menu. Quando true, a tela
# de levels não carrega o nível direto — guarda o nível escolhido em level_path e abre
# a tela playonline (Host/Connect), que então carrega esse nível ao hospedar/conectar.
var online_mode: bool = false
var level_path: String = ""

# Modo "Hospedar Somente": host abre o servidor SEM player controlado e observa o level
# com uma câmera livre (sem colisão). Definido na tela playonline; lido nos níveis.
var spectator_host: bool = false


# Caminho da cena para um variant_id (com clamp defensivo p/ índice fora do registro).
func variant_scene_path(variant_id_value: int) -> String:
	return VARIANTS[clampi(variant_id_value, 0, VARIANTS.size() - 1)]
