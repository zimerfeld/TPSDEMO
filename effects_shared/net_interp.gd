class_name NetInterp
extends RefCounted

## Buffer de interpolação de Transform3D com snapshots datados.
##
## Suaviza entidades REMOTAS (não-autoridade) renderizando-as ~RENDER_DELAY_MS "no passado":
## em vez de aplicar o transform cru do MultiplayerSynchronizer (que chega só ~30x/s e causa
## stutter/flicker), guardamos as amostras recebidas com o horário de chegada e, a cada frame,
## devolvemos o transform interpolado no instante (agora − RENDER_DELAY_MS). Assim há sempre
## duas amostras "ao redor" do tempo de render e o movimento fica contínuo, sem extrapolar.
##
## Barato (uma busca linear curta + um interpolate_with por frame) → não pesa no FPS.

# Atraso de render (ms). ~100 ms cobre o jitter de UDP entre dois pacotes de sync (~33 ms)
# com folga, sem custo perceptível de "lag visual" dos outros jogadores.
const RENDER_DELAY_MS: float = 100.0
# Histórico máximo de amostras (a ~30/s, cobre ~0,8 s — muito além do atraso de render).
const MAX_SAMPLES: int = 24

var _times: PackedFloat64Array = PackedFloat64Array()
var _xforms: Array[Transform3D] = []


# Registra uma amostra (chamar a cada frame com o valor sincronizado atual). Só guarda quando
# o valor MUDA — amostras idênticas consecutivas (parado) não geram passos de interpolação.
func push(now_ms: float, xform: Transform3D) -> void:
	var n: int = _xforms.size()
	if n > 0 and _xforms[n - 1].is_equal_approx(xform):
		return
	_times.append(now_ms)
	_xforms.append(xform)
	while _xforms.size() > MAX_SAMPLES:
		_times.remove_at(0)
		_xforms.remove_at(0)


func has_data() -> bool:
	return _xforms.size() > 0


# Transform interpolado no tempo (now_ms − RENDER_DELAY_MS). Clampa nas pontas (sem extrapolar).
func sample(now_ms: float) -> Transform3D:
	var n: int = _xforms.size()
	if n == 1:
		return _xforms[0]
	var rt: float = now_ms - RENDER_DELAY_MS
	if rt <= _times[0]:
		return _xforms[0]
	if rt >= _times[n - 1]:
		return _xforms[n - 1]
	for i in range(n - 1):
		if rt <= _times[i + 1]:
			var span: float = _times[i + 1] - _times[i]
			var f: float = 0.0 if span <= 0.0 else float((rt - _times[i]) / span)
			return _xforms[i].interpolate_with(_xforms[i + 1], f)
	return _xforms[n - 1]
