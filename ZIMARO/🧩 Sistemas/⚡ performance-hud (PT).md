---
tipo: sistema
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# ⚡ Sistema — Indicadores de Performance (PerformanceHUD + StabilityGuard)

> Substituiu o antigo **SystemHealth** em 2026-06-20. São DOIS autoloads complementares:
> **StabilityGuard** (proteção sempre-ligada) e **PerformanceHUD** (barra de leitura, opcional).
> Ambos leem só do singleton `Performance` (métricas internas da engine, confiáveis e
> multiplataforma). Ver [[🧱 recursos-nativos-godot (PT)|🧱 recursos-nativos-godot]].
>
> **Rótulo na tela developer (2026-06-23):** a linha que liga a barra (chave `performance_hud`) é
> rotulada **"Monitor de Saúde"** / EN "Health Monitor" (era "HUD de Performance"). A chave de config
> e os autoloads NÃO mudaram.

## StabilityGuard (`autoload/stability_guard.gd`)

Rede de segurança contra crash/freeze, **sempre ligada** (sem toggle). Amostra a cada
`check_interval` (0,5 s) e classifica em 3 estados, aplicando a ação na **transição**:

| Estado | Ação |
|---|---|
| `NORMAL` | física em `physics_normal_tps` (60), árvore despausada, overlay oculto |
| `THROTTLE` | física cai para `physics_throttle_tps` (30) + sinal `throttle_activated` |
| `EMERGENCY` | `get_tree().paused = true` + overlay de emergência (tela cheia, ESC dispensa) |

**5 indicadores** (limites `@export`, em `warn`/`crit`):

| Indicador | Monitor | Risco real |
|---|---|---|
| RAM livre do sistema | `OS.get_memory_info()` "free" | pouca RAM física livre → swap/OOM/freeze |
| VRAM | `RENDER_VIDEO_MEM_USED` | esgotamento → crash de driver GPU |
| Collision Pairs | `PHYSICS_3D_COLLISION_PAIRS` | explosão → freeze do thread de física |
| Node Count | `OBJECT_NODE_COUNT` | vazamento → RAM cresce sem parar |
| FPS | `TIME_FPS` | `≤ fps_crit` por `fps_crit_frames` → loop principal preso |

- **RAM migrada para o sistema (2026-06-21):** a checagem de RAM usa `OS.get_memory_info()` "free"
  e age quando a RAM física LIVRE fica **ABAIXO** dos limites (`ram_free_warn_mb` 1024 / `ram_free_crit_mb`
  512) — invertido vs. os outros indicadores (que agem ACIMA do limite). `MEMORY_STATIC` (RAM do jogo)
  ficava 0 no `.exe` em release, então a proteção de RAM nunca disparava no executável. Sem dado da
  plataforma (`free < 0`) a checagem de RAM é pulada (nunca dispara por falta de dado).
- Sinais: `state_changed(new_state, reason)`, `throttle_activated`, `emergency_activated`,
  `recovered` — o PerformanceHUD os escuta para o badge.
- `state_name()`/`state_color()`/`last_reason`/`dismiss_emergency()`/`force_check()` são a API
  de leitura/controle. O overlay roda em `PROCESS_MODE_ALWAYS` (vive durante a pausa).
- Textos do overlay e os `reason` são localizados via `Locale.tr_key` (templates com `%`
  preservados, formatados depois) — dicionário em `res://scenes2D/overlays/Resources`.

## PerformanceHUD (`autoload/performance_hud.gd` + `scenes2D/overlays/performance_bar.gd`)

Overlay GLOBAL: o autoload (Node `PerformanceHUD`) cria um `CanvasLayer` (layer 99) com a barra
`performance_bar.gd`, mostrada/oculta pela config `game/performance_hud` (toggle **HUD de
Performance** na tela `developer`). É **click-through** (mouse só na barra do toggle) e o
`_process` é pulado quando oculto (`is_visible_in_tree`).

- **Básico** (32 px): `FPS | NET | RAM | CPU% | GPU% | ● badge do StabilityGuard`.
  - `CPU%` **(2026-06-23)** = `(TIME_PROCESS + TIME_PHYSICS_PROCESS) / tempo_de_frame_real ÷ núcleos`
    (`OS.get_processor_count`) → % do PROCESSO relativo ao **total do sistema** (~ Gerenciador de
    Tarefas), no lugar do antigo `TIME_PROCESS / 16,67` fixo que **saturava em 100%** por núcleo.
    Ainda é proxy (só main-thread process+física; não conta a render-thread) — subconta vs o CPU real
    do processo, mas não satura mais. `GPU%` = proxy por `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`.
  - **NET (2026-06-24)** mede o **RTT/ping do ENet** (`_refresh_net`): no **cliente**, o ping até o
    servidor (`enet.get_peer(1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)`); no **host**, a
    **média** dos pings dos clientes + a contagem (`NET: 42 ms (2)`); sem cliente mostra `NET: host (0)`.
    Colorido por limiar (<80 ms verde / <160 amarelo / senão vermelho). Offline ou sem peer ENet →
    **"N/D"**. Funciona através de túneis UDP (ex.: **playit.gg**): o ENet mede o RTT real do pacote,
    incluindo o relay. (Antes dependia de um `NetworkManager.get_total_bps()` inexistente → travado em "N/D".)
  - **RAM** (2026-06-21) = memória do **SISTEMA** via `OS.get_memory_info()`, formato **"usado/total GB"**
    (usado = `physical - free`, como o "Em uso" do Gerenciador de Tarefas; colorido por % de uso).
    **Por quê:** `Performance.MEMORY_STATIC` só é rastreada em **debug** e fica **0 no .exe exportado em
    release**. `OS.get_memory_info()` funciona em release; usa-se `free` (não `available`, que no Windows
    é memória virtual/commit e daria `physical - available < 0` → 0).
- **Avançado** (toggle ▼/▲, 130 px): colunas **CPU** (Processo/Física/Carga/Nós/Objetos/Corpos
  3D/Col. Pairs), **GPU** (Draw Calls/Triângulos/VRAM/Tex. Mem.) e **Memória** (**RAM Sistema** — o
  mesmo usado/total GB do básico — / Resources), cada valor colorido por limiar (verde/amarelo/
  vermelho), mais a linha do Guard.

## Integração

- `project.godot` `[autoload]` (após `DebugOverlay`): `StabilityGuard` e `PerformanceHUD`.
- `developer.gd`: `_TOGGLES["PerformanceHUDRow"] = "performance_hud"`; `_on_toggle` chama
  `PerformanceHUD.refresh()`. Linha `PerformanceHUDRow` em `developer.tscn`.
- `config.gd`: default `game/performance_hud = false`. A proteção (StabilityGuard) **não** tem
  config — é sempre-ligada.
- Localização: chaves do HUD/Guard em `scenes2D/overlays/Resources/overlays.{pt,en}.json`
  (varridas pelo `Locale`), com todos os nós em `Locale.SKIP_GROUP` (o script é dono dos textos).

## Por que substituiu o SystemHealth

O SystemHealth também pausava a árvore; manter os dois geraria briga pelo `get_tree().paused`.
Decisão (2026-06-20): StabilityGuard vira a ÚNICA proteção e o PerformanceHUD a leitura. **Perdas
aceitas**: o CPU REAL por processo (thread PowerShell `Get-Process`) e o **bip** de pico crítico do
SystemHealth não foram portados — o CPU% do HUD é um proxy por tempo de frame.

Relacionado: [[🧱 recursos-nativos-godot (PT)|🧱 recursos-nativos-godot]], [[🗣️ localizacao (PT)|🗣️ localizacao]], [[🐞 debug-overlay (PT)|🐞 debug-overlay]].
