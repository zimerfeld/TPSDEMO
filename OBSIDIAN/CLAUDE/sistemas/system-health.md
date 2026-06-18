# Sistema — System Health (monitor + auto-pausa de segurança)

Overlay global de monitoramento, autoload **SystemHealth** (`autoload/system_health.gd`). Ligado/
desligado pela linha **System Health** da tela `developer` (config `game/system_health`).

## O que mostra

**Painel flutuante arrastável**, amostrado a cada ~0,6 s. O topo é um **cabeçalho (PanelContainer)
com UMA linha (HBox)** (2026-06-18): o **texto do título** à esquerda (`SIZE_EXPAND_FILL`) e um **botão
de fechar vermelho estilo Windows ("✕")** à direita. **Só o título move a janela** — apenas o
`_title_label.gui_input` dispara o arraste; o botão de fechar é um `Button` próprio, então **sua área
nunca inicia arraste** (`_make_close_button`). **Fechar** (`_on_close_pressed`) apenas **esconde** o
`_canvas` (`visible=false`) — o monitoramento **continua rodando** (a config `system_health` segue
ligada), de propósito: a rede de segurança (pausa + auto-show crítico) precisa seguir ativa, e um pico
crítico reabre o painel. Reabrir "de vez" = alternar a linha System Health no developer.

- **FPS** — `Engine.get_frames_per_second()`.
- **CPU** — **uso REAL do processo Godot** (bate com o Gerenciador de Tarefas). O Godot não expõe
  isso, então uma **thread em segundo plano** amostra do SO via PowerShell `Get-Process … .CPU`
  (locale-independente) e converte deltas sucessivos em % sobre os núcleos lógicos. **N/D** até o
  1º delta / fora do Windows. (GPU por processo e temperatura de CPU foram removidos — indisponíveis
  de forma confiável; ver decisão do usuário em 2026-06-18.)
- **Mem. Jogo** — `Performance.MEMORY_STATIC`, no padrão **"usado / total (%)"** (mesmo de Mem.
  Sistema), tendo a **RAM física** como total comum (`_format_mem_ratio`).
- **Mem. Vídeo** — `Performance.RENDER_VIDEO_MEM_USED`, também **"usado / total (%)"** com a RAM
  física como total comum, para comparar o peso de cada memória sob a mesma referência.
- **Mem. Sistema** — RAM física usada = `physical - FREE` de `OS.get_memory_info()`, em MB/GB e %
  (ex.: 12,6 GB / 16,2 GB = 78%). ⚠️ **Não usar `available`**: no Windows é o espaço VIRTUAL/commit
  do processo (dezenas de GB, maior que a RAM física) → dava valor negativo (o bug "-25600 0%").
- As três linhas de memória usam a RAM física como total; `_format_mem_ratio` cai para só o valor
  (sem `/ total (%)`) quando a RAM física está indisponível.

## Janela flutuante (posição)

- **Sempre dentro da tela:** ao iniciar e ao arrastar, a posição é limitada por `_clamp_to_screen`
  (e re-limitada a cada poll, p/ sobreviver a mudança de resolução).
- **Persistência:** a posição é salva em `game/system_health_pos` ao soltar o arraste e restaurada
  no boot (`_apply_saved_position`). `(-1,-1)` = não definida → canto **superior direito**.
- **Reset das configurações:** `Settings.reset_to_defaults()` emite o sinal `settings_reset` e zera
  `system_health_pos` p/ `(-1,-1)`; o painel volta ao canto superior direito (`_on_settings_reset`).

## Limite seguro + auto-pausa (90%, suave)

- `THRESHOLD = 90%`. RAM do sistema acima do limite é crítico **na hora**; a CPU só conta para a
  pausa após ficar acima por `SPIKE_GRACE = 4 s` (picos curtos são tolerados). O alerta vermelho
  aparece imediatamente em qualquer pico.
- Suave: se o interruptor **"Pausar ao atingir o limite"** (config `game/system_health_autopause`,
  padrão ligado) estiver ativo, faz `get_tree().paused = true` para não congelar/travar o SO, e mostra
  o botão **Retomar**.
- O overlay roda mesmo pausado (`PROCESS_MODE_ALWAYS`). Ao retomar, trava a auto-pausa
  (`_suppress_autopause`) até o uso cair abaixo do limite — evita re-pausar na hora.
- A thread de CPU para em `_exit_tree` (`_hw_run=false` + `wait_to_finish`).

## Regra crítica (>95%): picos + bip + auto-show + pausa forçada (2026-06-18)

Camada **acima** do limite suave, calculada em `_update_alert` a partir do **maior** indicador
(`max_pct` = máx de CPU + as 3 memórias, computado em `_poll`):

- `SPIKE_THRESHOLD = 95%`, `SPIKE_DURATION = 1 s`, `SPIKES_TO_SHOW = 3`.
- Enquanto **qualquer** indicador fica acima de 95%, conta-se **1 pico por segundo sustentado**
  (`_spike_start`/`_spikes_counted`, via `floor(elapsed/1s)+1` → 1º bip já no cruzamento). Cair abaixo
  de 95% **zera** a contagem.
- **Cada pico emite um bip** (`_play_beep`): um tom senoidal curto **sintetizado no boot**
  (`_make_beep_player` → `AudioStreamWAV` 16-bit, sem asset), no **bus SFX** e `PROCESS_MODE_ALWAYS`
  (soa mesmo pausado).
- Após **mais de 3 picos consecutivos** (`_spikes_counted > SPIKES_TO_SHOW`), `_engage_critical_safety`:
  **reexibe** o painel (mesmo se o usuário o tinha fechado, desde que `system_health` ligada) e **pausa
  à força** — **ignorando** o checkbox de auto-pausa **e** o `_suppress_autopause`. É a garantia do
  brief: **em hipótese alguma** deixar travar/congelar a máquina; antes disso, pausa.
- Pausar derruba a carga do jogo → picos de CPU cedem e dá p/ retomar; recurso ainda crítico (ex.: RAM
  cheia) permanece pausado (desfecho seguro). `_engage_pause` também revela o painel, p/ a pausa nunca
  ficar invisível.

## Integração

- Registrado em `project.godot` `[autoload]` como `SystemHealth` (depois de `DebugOverlay`).
- `developer.gd`: `_TOGGLES["SystemHealthRow"] = "system_health"`; `_on_toggle` chama
  `SystemHealth.refresh()` para mostrar/ocultar na hora.
- Defaults em `config.gd`: `game/system_health=false`, `game/system_health_autopause=true`.
- Textos do painel são localizados via `Locale.tr_key` (chaves no dicionário da cena `developer`),
  com os nós no `Locale.SKIP_GROUP`. Chaves novas (2026-06-18): `"Fechar"` (tooltip do ✕) e
  `"ALERTA CRÍTICO: uso acima de 95%!"`.

Relacionado: [[sistemas/localizacao]], [[sistemas/debug-overlay]], [[arquivos-chave/main-gd]].
