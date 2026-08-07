extends Node
## Preferências LOCAIS de otimização de rede/render, escolhidas pelo jogador ANTES de hospedar/
## entrar numa sala (tela playonline). Não são replicadas — cada lado ajusta o que controla:
##   • render_delay_ms  → atraso de interpolação dos modelos REMOTOS (Suave ↔ Responsivo).
##                        Aplicado em [[net_interp]] (NetInterp.render_delay_ms, static).
##   • sync_hz          → taxa de replicação (updates/s). Vale DOS DOIS LADOS, cada um na direção que
##                        ENVIA: o SERVIDOR aplica nos MultiplayerSynchronizer das entidades
##                        (replication_interval=1/Hz) em [[room_manager]] (broadcast servidor→clientes);
##                        o CLIENTE dono aplica no próprio InputSynchronizer (apply_authority) — upload
##                        do seu input. Não precisam casar: controlam fluxos diferentes.
##   • host_render_observed → host renderiza a sala observada/jogada (janela) ou roda como servidor
##                        puro sem render (economiza GPU). Lido pelo host_session.
##
## Persistido em Settings.config_file (seção "netopt"). Vive como autoload (/root/NetConfig).
## Trade-off central (regra do projeto: priorizar experiência sem comprometer resposta/FPS):
## menos atraso/mais Hz = mais responsivo porém mais banda/sensível a jitter; o default
## "Equilibrado" (60 ms / 30 Hz) é mais rápido que o antigo 100 ms sem custo perceptível.

const SECTION := "netopt"

# Presets de interpolação (ms de atraso de render). Menor = mais responsivo.
const INTERP_PRESETS := {"smooth": 100.0, "balanced": 60.0, "responsive": 35.0}
const INTERP_LABELS := ["Suave", "Equilibrado", "Responsivo"]   # ordem = smooth/balanced/responsive
const INTERP_KEYS := ["smooth", "balanced", "responsive"]

var render_delay_ms: float = 60.0      # default Equilibrado
var sync_hz: int = 30
var host_render_observed: bool = true


func _ready() -> void:
	load_config()


# Intervalo de replicação (s) correspondente ao sync_hz escolhido (mín. 1 Hz por segurança).
func sync_interval() -> float:
	return 1.0 / float(maxi(sync_hz, 1))


# Intervalo de envio do INPUT do cliente dono (s). Deliberadamente SEPARADO do sync_hz: aquele
# dimensiona o broadcast de ESTADO do servidor (muitas entidades × muitos peers, onde a banda
# importa); este é um único pacote pequeno com as teclas de um jogador, e cada milissegundo aqui é
# sentido como input lag. 0 = envia no ritmo do frame, sem grade própria — o custo é da ordem de
# 2 KB/s de upload a mais, contra até 33 ms de espera em toda ação do cliente.
func input_interval() -> float:
	return 0.0


# Índice do preset de interpolação atual (para popular o OptionButton). Cai em "balanced" se custom.
func interp_index() -> int:
	for i in INTERP_KEYS.size():
		if is_equal_approx(INTERP_PRESETS[INTERP_KEYS[i]], render_delay_ms):
			return i
	return 1


func set_interp_index(idx: int) -> void:
	var key: String = INTERP_KEYS[clampi(idx, 0, INTERP_KEYS.size() - 1)]
	render_delay_ms = float(INTERP_PRESETS[key])
	_apply_runtime()
	save_config()


func set_sync_hz(hz: int) -> void:
	sync_hz = 60 if hz >= 60 else 30
	save_config()


func set_host_render(on: bool) -> void:
	host_render_observed = on
	save_config()


# Aplica os valores que têm efeito imediato em runtime (interpolação). sync_hz é lido pelo
# servidor ao spawnar entidades; host_render_observed é lido pelo host_session ao renderizar.
func _apply_runtime() -> void:
	NetInterp.render_delay_ms = render_delay_ms


func load_config() -> void:
	var cf: ConfigFile = Settings.config_file
	if cf != null:
		render_delay_ms = float(cf.get_value(SECTION, "render_delay_ms", render_delay_ms))
		sync_hz = int(cf.get_value(SECTION, "sync_hz", sync_hz))
		host_render_observed = bool(cf.get_value(SECTION, "host_render_observed", host_render_observed))
	_apply_runtime()


func save_config() -> void:
	var cf: ConfigFile = Settings.config_file
	if cf == null:
		return
	cf.set_value(SECTION, "render_delay_ms", render_delay_ms)
	cf.set_value(SECTION, "sync_hz", sync_hz)
	cf.set_value(SECTION, "host_render_observed", host_render_observed)
	Settings.save_settings()
