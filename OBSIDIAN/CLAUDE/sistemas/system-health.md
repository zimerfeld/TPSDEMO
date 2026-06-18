# Sistema — System Health (monitor + auto-pausa de segurança)

Overlay global de monitoramento, autoload **SystemHealth** (`autoload/system_health.gd`). Ligado/
desligado pela linha **System Health** da tela `developer` (config `game/system_health`).

## O que mostra

**Painel flutuante arrastável** (segure o botão esquerdo sobre a barra de título para mover),
amostrado a cada ~0,6 s:

- **FPS** — `Engine.get_frames_per_second()`.
- **CPU** — **uso REAL do processo Godot** (bate com o Gerenciador de Tarefas). O Godot não expõe
  isso, então uma **thread em segundo plano** amostra do SO via PowerShell `Get-Process … .CPU`
  (locale-independente) e converte deltas sucessivos em % sobre os núcleos lógicos. **N/D** até o
  1º delta / fora do Windows. (GPU por processo e temperatura de CPU foram removidos — indisponíveis
  de forma confiável; ver decisão do usuário em 2026-06-18.)
- **Mem. Jogo** — `Performance.MEMORY_STATIC`.
- **Mem. Vídeo** — `Performance.RENDER_VIDEO_MEM_USED`.
- **Mem. Sistema** — RAM física usada via `OS.get_memory_info()` (`physical - available`), em MB/GB e %.

## Limite seguro + auto-pausa

- `THRESHOLD = 90%`. RAM do sistema acima do limite é crítico **na hora**; a CPU só conta para a
  pausa após ficar acima por `SPIKE_GRACE = 4 s` (picos curtos são tolerados). O alerta vermelho
  aparece imediatamente em qualquer pico.
- Crítico: se o interruptor **"Pausar ao atingir o limite"** (config `game/system_health_autopause`,
  padrão ligado) estiver ativo, faz `get_tree().paused = true` para não congelar/travar o SO, e mostra
  o botão **Retomar**.
- O overlay roda mesmo pausado (`PROCESS_MODE_ALWAYS`). Ao retomar, trava a auto-pausa
  (`_suppress_autopause`) até o uso cair abaixo do limite — evita re-pausar na hora.
- A thread de CPU para em `_exit_tree` (`_hw_run=false` + `wait_to_finish`).

## Integração

- Registrado em `project.godot` `[autoload]` como `SystemHealth` (depois de `DebugOverlay`).
- `developer.gd`: `_TOGGLES["SystemHealthRow"] = "system_health"`; `_on_toggle` chama
  `SystemHealth.refresh()` para mostrar/ocultar na hora.
- Defaults em `config.gd`: `game/system_health=false`, `game/system_health_autopause=true`.
- Textos do painel são localizados via `Locale.tr_key` (chaves no dicionário da cena `developer`),
  com os nós no `Locale.SKIP_GROUP`.

Relacionado: [[sistemas/localizacao]], [[sistemas/debug-overlay]], [[arquivos-chave/main-gd]].
