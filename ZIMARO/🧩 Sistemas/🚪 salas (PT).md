---
tipo: sistema
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-08-05
---

# 🚪 Salas simultâneas (servidor multi-level)

> Permite ao host rodar **vários levels ao mesmo tempo** e gerenciá-los (iniciar/parar/reiniciar,
> **observar** e **jogar** em cada um) sem que sair de um derrube o servidor. O papel (Host/Client) é
> escolhido no `playonline` (dois botões) e a **sala é escolhida ANTES** do `chooseplayer` — só então o
> player nasce nela. Relacionado: [[🌐 multiplayer (PT)|🌐 multiplayer]], [[🛰️ hospedagem-online (PT)|🛰️ hospedagem-online]],
> [[🎬 fluxo-de-cenas (PT)|🎬 fluxo-de-cenas]].
>
> 🧪 **Para validar em campo:** ver [[🧪 teste-salas-multiplayer (PT)|🧪 teste-salas-multiplayer]] (roteiro loopback → LAN → internet).
> ✅ **VALIDADO em 2 PCs reais (2026-08-05)** via **playit.gg** (túnel UDP `zimaro.playit.game:44000` → host `192.168.0.211:44000`), após corrigir o **congelamento do inimigo no cliente** — ver a seção *Congelamento do inimigo no cliente* abaixo (release `202608051826`).

---

## Arquitetura

- **`RoomManager`** (`autoload/room_manager.gd`, autoload persistente): cada "sala" é um nível
  rodando dentro de um **`SubViewport` com `World3D` próprio** (`own_world_3d = true`). Isso isola
  **física, navegação e `WorldEnvironment`** — sem World3D separado, dois níveis ocupariam o mesmo
  espaço e os ambientes brigariam (só vale 1 `WorldEnvironment` por World3D).
- Como vive no autoload, as salas **sobrevivem à troca de cena** (inclusive ao ir ao `chooseplayer` e
  voltar) → o peer ENet **não** é fechado ao navegar; só no **"Voltar"** das sessões, que chama
  `RoomManager.stop_all()` + fecha o peer e retorna ao `playonline` (não há mais `_exit_tree → stop_all`).
- **Render sob demanda (otimização):** os SubViewports ficam em `UPDATE_DISABLED`; só a sala
  **observada/jogada** vira `UPDATE_ALWAYS`. A **simulação dos inimigos roda em TODAS** as salas,
  independente do render → não se paga GPU por salas que ninguém está vendo.
- API: `start_room(level_path) -> id`, `stop_room(id)`, `restart_room(id) -> novo_id`, `get_rooms()`,
  `stop_all()`. **`stop_room` e `restart_room` chamam o mesmo `_close_room(id, reason)`** (enum
  `CloseReason.{STOPPED, RESTARTED, SILENT}`), que avisa os clientes da sala ANTES de liberar com o
  RPC adequado ao motivo: **STOPPED → `notify_room_closed`** ("O nível foi parado pelo host"),
  **RESTARTED → `notify_room_restarted`** ("O nível foi reiniciado pelo host"). **host joga:**
  `host_spawn_in_room(id, variant_id)` / `host_leave_room()`; **cliente sai:** `client_leave_room(id)`
  (+ RPC `leave_room`); sinais `rooms_changed`, `room_closed(id)` e **`room_restarted(id)`**. Marcadores
  do fluxo "Jogar" (invertido): `pending_play_room` / `pending_play_level` / `pending_play_return`.

## Fluxo e telas — papel escolhido no `playonline`

No `playonline`, abaixo de Port/Address, há dois botões: **"Gerenciar Salas"** (Host → abre
`host_session`) e **"Entrar em Salas"** (Client → abre `client_session`). O **"Jogar"** (host ou cliente) sempre passa pelo `chooseplayer`
ANTES de nascer: marca `pending_play_room`/`return`, vai ao seletor de personagem e, ao voltar, o
`_ready` da sessão consome o marcador e entra em modo de jogo (spawna + esconde o painel + captura o
mouse). Durante o jogo a **sessão continua sendo a cena raiz** (só esconde o painel).

- **SERVIDOR (`scenes2D/host_session/`, server-only)** — `_on_manage_rooms_pressed` cria o servidor
  ENet e troca para `host_session.tscn` (peer mantido, **nenhuma sala no carregamento**). UI: dropdown
  de nível (**1º item "Selecione…"**) + **Iniciar Sala**; por sala **Jogar / Observar / Reiniciar /
  Parar**; **Voltar** (derruba o servidor e volta ao `playonline`).
  - **Observar:** textura do SubViewport em tela cheia, mouse **CAPTURADO**, mouse empurrado à sala
    (`viewport.push_input`) → a câmera livre (`register_room_level`) olha em volta; **ESC** sai da
    observação.
  - **Jogar:** `chooseplayer` → `host_spawn_in_room` spawna um player do **host (peer 1)** na sala e
    **desliga a câmera livre** dela (senão as duas leriam o `Input` global); a câmera do player vira
    `current` no SubViewport (renderizado em tela cheia, só o mouse é empurrado). **ESC** abre um
    janela `FloatingDialog.confirm` ("Desconectar e voltar para a gerência ?") → `host_leave_room` e volta à grade.
  - **Parar:** encerra **só aquela sala**; os clientes que jogavam nela recebem `notify_room_closed`,
    veem **"O nível foi parado pelo host"** e voltam ao navegador da `client_session`. Outras salas seguem.
  - **Reiniciar:** recria o nível do zero (`restart_room` = `_close_room(RESTARTED)` + `start_room`); os
    clientes da sala recebem `notify_room_restarted`, veem **"O nível foi reiniciado pelo host"** e voltam
    ao navegador (a sala recriada reaparece na lista p/ reentrar). O **host volta à grade com o mouse
    VISÍVEL** (estado idêntico ao de "Iniciar Sala") — `_on_restart_room` reentra na sala recriada só se
    estava observando/jogando ESTA sala. Antes o restart podia deixar a tela num estado sem mouse/respawn.
- **CLIENTE (`scenes2D/client_session/`, client-only — NOVO)** — `_on_join_rooms_pressed` conecta e,
  no `connected_to_server`, abre `client_session.tscn`. Pede `request_room_list` e lista
  **#id — level (N jogadores) + Jogar** (o botão **só aparece se houver sala**). **Jogar:**
  `chooseplayer` → `client_join_room` espelha a sala como **Node comum** (renderiza na **janela
  principal**, sem SubViewport) e manda `join_room`; o servidor spawna o player. **ESC** → confirma →
  `client_leave_room` (despawna no servidor + remove o espelho, **sem fechar o peer**) e volta ao
  navegador. **Voltar** fecha o peer e volta ao `playonline`.

## Caminho determinístico (replicação)

Server e cliente põem a sala em `/root/RoomManager/Room<id>/Level/...` (nó do nível renomeado p/
`"Level"`) → o `MultiplayerSpawner` do nível replica igual. **Assimetria proposital:** no servidor
`Room<id>` é `SubViewport` (World3D próprio, várias salas isoladas + observação); no cliente é `Node`
comum (uma sala só, renderiza na janela principal). O caminho-string é o mesmo → a replicação casa.

## Isolamento por sala (interest management)

`RoomManager._apply_room_visibility` adiciona **só um *visibility filter*** (veta quem não está na
sala) em cada `MultiplayerSynchronizer` de tudo que entra no `SpawnedNodes` da sala (inimigos, balas,
players): só replica para peers cujo `_peer_room[peer] == room_id`. Ao um peer entrar,
`_refresh_room_visibility` chama `update_visibility()` → os spawns já existentes (inimigos) são
(re)enviados a ele.

> ⚠️ **NÃO setar `public_visibility = false`.** Na engine,
> `MultiplayerSynchronizer.is_visible_to(peer)` é: `todos os filtros passam?` **E**
> `peer_visibility.has(0) ou peer_visibility.has(peer)` — onde `has(0)` é o `public_visibility`.
> Filtros **só VETAM** (retornar `true` não concede visibilidade sozinho). Com
> `public_visibility = false` o synchronizer fica **invisível a TODOS** → **nada replica para o
> cliente** (player dele sem câmera/level, outros players e inimigo não aparecem). Mantendo o default
> (`true`) o filtro funciona: na sala = visível, fora = vetado. **Bug corrigido em 2026-06-24**
> (`feature/spawnplayer2`): era a causa de "o level não aparece no `client_session`" e de players/
> inimigo não sincronizarem. Os *parts* de morte do `red_robot` nascem `public_visibility=false` de
> propósito (só sincronizam ao explodir, via `part.gd`) — preservado: ganham só o filtro.

## Congelamento do inimigo no cliente = stall de render (corrigido, VALIDADO 2 PCs 2026-08-05)

Sintoma: o cliente entra na sala do host e os inimigos aparecem **parados**; o tiro acerta mas **não
detecta colisão**. Reproduzido num **harness headless de 2 processos** com o `RoomManager` REAL: o
**núcleo do netcode de sala está correto** — replicação, filtro de visibilidade, interpolação
(`net_transform`) e até a **colisão server-side dentro do SubViewport** funcionam (a bala matou os
inimigos no teste). A falha só aparece com o **cliente RENDERIZANDO**: ao materializar as ~16 entidades
do template **de uma vez**, o loop principal **trava vários segundos** (compilação de shader/pipeline na
GPU + construção dos `LimbColliders` dos `red_robot` na CPU, no mesmo frame). Em **hardware gráfico
fraco** esse stall (a) faz o inimigo "congelar" na tela e (b) **estoura o timeout PADRÃO do ENet
(min 5 s) → a conexão CAI**; e como **nenhum handler tratava `server_disconnected`** (só existia
`connection_failed` na conexão inicial), o cliente ficava **preso na sala congelada** e, desconectado,
o tiro não chegava ao servidor → "não detecta colisão". O `StabilityGuard` **não pega** isso: roda no
`_process` (nem é chamado durante o frame travado) e o gatilho de FPS exige 10 amostras seguidas, não 1
pico gigante.

**Correções (release `202608051826`, validada em 2 PCs via playit.gg em 2026-08-05):**
- **Spawn GRADUAL** das entidades do template (1/frame de física) em vez de tudo de uma vez —
  `TemplateManagerBase.apply_active_gradual()` (refatorado `_apply_template` em `_plan_template`
  [pula caminho morto via `ResourceLoader.exists`] + `_spawn_job`), usada por
  `RoomManager._ensure_template_spawned`.
- **Timeout do ENet TOLERANTE** (limit 32, min 20 s, max 40 s) aplicado a cada peer que conecta —
  `RoomManager._apply_peer_timeout` em `_on_peer_connected` — um stall de render não derruba mais a
  conexão. *(Validado no harness: stall de 3,7 s NÃO caiu e o sync se recuperou.)*
- **`client_session` trata `server_disconnected`** (`_on_server_lost`): avisa "A conexão com o host foi
  perdida" e volta ao `playonline`, em vez de sala congelada.
- **Whitelist DINÂMICA do `MultiplayerSpawner`** — novo `SpawnableLibrary.configure(spawner)`
  (`effects_shared/spawnable_library.gd`), chamado no `_ready` de `level_1`/`level_2`: varre `library3D`
  em **ordem lexicográfica determinística** (índices batem entre peers) → qualquer modelo de template,
  **inclusive os novos** (`humanoide/jogador/monstro/mulher`), replica ao cliente. Antes a whitelist era
  fixa no `.tscn` e só tinha os modelos antigos.
- **`StabilityGuard` afrouxado** (2026-08-05): `col_pairs` **16000/40000**, `node` **20000/45000**,
  `vram_warn` **3072** (crit 5120), `fps_crit_frames` **20** (10 s), `physics_throttle_tps` **45** —
  folga p/ o host multi-sala e tolera o hitch de carga sem estrangular a física. Ver a seção abaixo.

⏳ **Resta** um *hitch de carregamento na 1ª entrada da sala* (~1,6–2,6 s), **não-fatal**: o timeout
tolerante do ENet sobrevive a ele e o handler de `server_disconnected` recupera limpo.

> ⚠️ **PRÉ-AQUECIMENTO NÃO RESOLVE — medido em 2026-08-05, NÃO reexplorar.** Cinco abordagens testadas
> com medição cold-cache: warm de entidades em SubViewport (~25%, ruído); warm de entidades na viewport
> RAIZ (sem ganho); warm do **LEVEL** em SubViewport (**0%**); warm do **LEVEL** na viewport raiz
> (**0%**); e uma fila espalhando os builds de `LimbColliders` (~40 ms, desprezível). **Todas revertidas,
> nada shippado.** Decomposição do custo (level_1, cold cache): render inicial do **ambiente/chão do
> level ≈ 2336 ms (86%)**, entidades ≈ 400 ms, colliders ≈ 40 ms. **Por que falha:** o custo está
> atrelado ao level virar a **cena ATIVA com setup completo** (`apply_graphics_settings` + shadow atlas
> + render buffers + occlusion **na janela real**) — todo pré-render offscreen deu **0 ms de stall**,
> ou seja não reproduz o custo, logo não o antecipa. **Não é one-time:** com shader cache de disco
> quente cai de ~2,6 s para ~1,6 s, mas **não zera** (setup de 1º render 3D da janela, por lançamento).
> ✅ **RESOLVIDO com a TELA DE "CARREGANDO"** (autoload `LoadingScreen`, 2026-08-05) — ver a seção
> *Tela de Carregando* abaixo. Em resumo: o startup carrega um level **DE VERDADE** (ativação completa)
> e descarta, pagando adiantado o setup **global** do renderer (**2473 ms → 602 ms na entrada seguinte,
> −76%**); e cada entrada em level/sala passa a ser **coberta** pela tela. **A chave:** o warm falhava
> porque o `_ready` com meta `warmup` retornava ANTES de `Settings.apply_graphics_settings(...)` — só
> ativação COMPLETA reproduz (e portanto antecipa) o custo. A branch `feature/salas-prewarm-shaders`
> ficou sem propósito.

Ver [[salas-freeze-render-stall]] na memória.

## Tela de "Carregando" (`LoadingScreen`) — 2026-08-05

Autoload **`LoadingScreen`** (`autoload/loading_screen.gd`), um `CanvasLayer` (layer 200,
`PROCESS_MODE_ALWAYS`) com fundo opaco + "Carregando..." — textos canônicos em pt, traduzidos pelo
[[locale]] via `scenes2D/loading/Resources/loading.{pt,en,es}.json`. **Dois papéis:**

1. **`run_startup_preload()`** — chamado no `main.gd._ready` antes do menu. Instancia um level **DE
   VERDADE** (`level_1`), deixa-o vivo ~6 frames e o descarta. É a **ativação completa** que paga
   adiantado o setup **global** do renderer. Medido (cold cache): **2473 ms aqui → a entrada seguinte
   numa sala cai para 602 ms (−76%)**. `spectator_host = true` (sem player controlado → sem captura de
   mouse) e `set_process_input(false)` no level (ESC não dispara o `LevelExit`). **Headless** (servidor
   dedicado, sem GPU) e `-- nopreload` pulam.
2. **`cover(action)`** — cobre a tela ANTES de **cada** entrada e revela só com o quadro pronto:
   mostra a tela, deixa **2 frames PINTAR** (senão o stall comeria o frame da própria tela e o jogador
   veria a janela congelada), executa a `action` (a ativação pesada) e aguarda `SETTLE_FRAMES`.
   Ligado em: **`levels.gd`** (entrada em level offline), **`client_session`** (entrar na sala) e
   **`host_session._set_observing` / `_set_playing`** (observar/jogar uma sala). Medido: entrada
   coberta = **896 ms mascarados** (validado com screenshot durante a cobertura).

> ⚠️ Só **ativação completa** paga o custo — `cover`/preload NÃO podem virar um "warm" offscreen
> (SubViewport ou viewport raiz dão **0 ms de stall**: não reproduzem o custo, logo não antecipam nada).
> Ver a medição na seção *Congelamento do inimigo no cliente*.

## Tela preta no cliente (level_base/level_2) — StabilityGuard (2026-06-24, `feature/spawnplayer2`)

> ⤴ **Valores atualizados em 2026-08-05** (ver seção *Congelamento do inimigo no cliente*): `col_pairs`
> 16000/40000, `node` 20000/45000, `vram_warn` 3072, `fps_crit_frames` 20, `physics_throttle_tps` 45.
> Os limites abaixo (8000/25000 etc.) são o **histórico** da calibração original de 2026-06-24.

> 🗑️ **Nota histórica (2026-07-01):** o nível `level_base` foi **REMOVIDO** do projeto na reestruturação
> `feature/restrutu` (cena, `.ogg` e todas as referências em `levels`/`host_session`/`playonline`/
> `music_manager`). O registro abaixo é mantido como **contexto** da calibração do `StabilityGuard`: os
> ~3066 collision pairs / ~1,2 GB de VRAM que motivaram os limites atuais valem para **qualquer nível 3D
> real** (hoje `level_1`/`level_2`) — a lição não mudou, só o exemplo. A sala padrão do servidor headless
> passou a ser o `level_1` (`DEFAULT_ROOM_LEVEL`).

Sintoma: ao entrar como CLIENTE numa sala de **Level Base** (e, com uma sala dessas rodando no servidor,
também **Level 2**), a tela ficava **preta** — nem o cenário aparecia. **Causa:** o `StabilityGuard`
(autoload sempre-ligado) entrava em **EMERGENCY** porque o level_base tem **~3066 collision pairs** de
geometria estática e o limite crítico era **600**; `_apply_emergency` fazia `get_tree().paused = true`,
que num servidor/cliente **congela o MultiplayerSpawner/Synchronizer e os RPCs** → o player do cliente
não nasce (sem câmera = tela preta) e nada sincroniza. No SERVIDOR, pausar congela TODAS as salas → por
isso o Level 2 (simples) também quebrava quando havia um Level Base rodando junto. O Level 1 (chão plano,
poucos pairs) nunca disparava → só ele funcionava.

**Correções:**
- `stability_guard.gd`: limites recalibrados para valores reais de jogo 3D (o level_base usa ~3066
  collision pairs E ~1198 MB de VRAM — ambos NORMAIS e que disparavam o guard): `col_pairs` 8000/25000,
  `node` 12000/30000, **`vram` 2560/5120 MB**. E `_apply_emergency` **nunca pausa em sessão ONLINE**
  (só estrangula a física + loga) — pausar quebra o netcode de todos os peers. O pause + overlay seguem
  valendo no solo/offline (onde não há rede a quebrar). ⚠️ Mesmo SEM pausar, o EMERGENCY/THROTTLE baixa
  a física p/ 30 tps no servidor (jogo lento p/ todos), então os limites PRECISAM não disparar em jogo
  normal — daí a recalibração. Validado: host iniciando/observando uma sala de level_base fica **NORMAL**.
- `level_base.tscn`: `_spawnable_scenes` convertido de UIDs → **caminhos explícitos** (igual ao level_1),
  eliminando o risco de um UID não resolver no MultiplayerSpawner (que silenciaria o spawn).

**Polimento de UI (2026-06-24):** `host_session`/`client_session` agora aplicam o **tema do projeto**
(`res://themes/ui_theme.tres`, mesmo da playonline/menu) na raiz → botões/labels/dropdowns com o visual
cyberpunk. ⚠️ O `ui_theme.tres` só estiliza **Button/Label** (não dá fundo), então o `_make_panel` foi
reescrito (`_panel` virou `Control`, não mais `PanelContainer`): **fundo com a textura cyberpunk do menu**
(`menu_surreal_training_bg.png`) + véu escuro, mas com IDENTIDADE própria por cena (fator decisivo host ×
cliente): **HOST = graduação QUENTE (âmbar)** + anéis de "radar" EXPANDINDO p/ fora (o servidor transmite /
é a fonte); **CLIENTE = graduação FRIA (ciano)** + anéis CONTRAINDO p/ dentro (conecta-se ao servidor). Os
anéis vêm do shader `res://themes/session_signal_bg.gdshader` (uniforms `ring_color` + `dir` ±1 + `aspect`),
montado pelo helper `_make_signal_layer(cor, dir)`. Um flat navy ficava "sem cor" — daí a textura rica. Também: **tela cheia** (margens + título centralizado);
**conteúdo/listas numa VBox centralizada de largura máx. 900** (HBox `ALIGNMENT_CENTER`); **botão Voltar
200×50 centralizado embaixo** (não mais full-width). Tudo dentro de `_panel`, escondido enquanto observa/
joga (aí o SubViewport/nível ocupa a tela). `_make_back_button` removido (o Voltar é montado no `_make_panel`).

**Persistência da playonline:** TODAS as opções persistem e recarregam — Porta e IP/Domínio
(`_prefill_last_used`: lê `online/last_port|last_address`, gravados em QUALQUER mudança via
`_on_port_changed`/`_on_address_changed`, sem poluir o histórico; fallback p/ o topo do histórico,
depois o default); interpolação/taxa/render do host (`NetConfig`, seção `netopt`); idioma (`Locale`,
`game/language`).

**Dropdowns de histórico (Porta/IP) — correção 2026-06-25:** os `OptionButton` `PortHistory`/
`AddressHistory` **refletem o valor atual do campo** e **mantêm a seleção** — antes `_fill_history`
forçava `selected = 0` ("Selecione...") e os handlers de seleção também resetavam para 0, então o
dropdown nunca mostrava nem guardava o valor armazenado. Agora: `_ready` chama `_prefill_last_used()`
**antes** de `_refresh_history()`; `_fill_history(option, key, current)` chama `_select_in_history` p/
deixar selecionado o item igual ao valor atual (ou "Selecione..." se não estiver no histórico); os
`_on_*_history_item_selected` **não resetam mais** p/ 0; e `_on_port_changed`/`_on_address_changed`
re-sincronizam o dropdown ao digitar. (Setar `.selected` por código não dispara `item_selected` → sem
recursão.) O valor em si já persistia em `online/last_port|last_address` — o que faltava era o dropdown
**espelhar** esse valor.

**HUD de debug do level_base (REMOVIDO):** o `Label` "Debug" (script `debug.gd`, mostrava FPS/VSync/
Memória/Online/Multiplayer ID) era legado do `level_base.tscn` (não existia no level_1/2), aparecia por
padrão e era redundante com o **Performance HUD**. Foi **deletado** do `level_base.tscn` (nó +
ext_resource) e os arquivos `debug.gd`/`debug.gd.uid` apagados. Não foi gerado por mim — era código
abandonado.

## Janelas de confirmação padronizadas + fundos animados das telas (2026-06-24)

**Diálogos (reescrito 2026-06-25):** TODAS as janelas de confirmação/aviso (Sair, Resolução, Restaurar,
Desconectar host/cliente, avisos das sessões, salvar/reassociar/remover na tela Models e erros do
`CrashHandler`) são montadas sobre o **controle2D reutilizável `FloatingWindow`**
(`controls2D/floating_window/`, `class_name FloatingWindow`) pelo helper **`FloatingDialog`**
(`themes/floating_dialog.gd`, `confirm()/alert()`). É um `Control` (não o `Window`/`ConfirmationDialog`
nativo): **título centralizado** (espaçador esquerdo espelha o ×), **botões de largura uniforme**, **× de
fechar padrão** (mesmo visual preto opaco dos painéis Dano/IA), **fundo modal** que escurece e bloqueia o
resto da UI, **ESC = cancela**, **Enter = confirma** (botão OK em foco), **foco devolvido** ao controle
anterior ao fechar e **arraste pela barra de título**. Vai num `CanvasLayer` (layer 128) no topo — cobre
2D e 3D — e se autolibera ao fechar. Textos passados CRUS (chaves canônicas): a janela traduz via Locale
(SKIP_GROUP + meta `loc_key`) e **atualiza ao trocar idioma**. ESC é consumido pela janela (descendente
adicionada por último) antes do `_input` da tela, então o fundo não navega junto. O antigo `UIDialogs`
(`themes/ui_dialogs.gd`, que só estilizava os diálogos nativos) foi **REMOVIDO**. A mesma base serve para
qualquer janela flutuante futura (export `remember_position_key` salva/restaura a posição em Settings).

**Janela de erro NÃO-DESTRUTIVA (`CrashHandler`, 2026-07-02):** a janela de erro global deixou de ser
fatal. × / ESC / botão **"Voltar"** apenas FECHAM e devolvem o foco à cena que chamou (o `FloatingWindow`
já restaura `_prev_focus` no `close()`); com `retry_callback` há também **"Tentar Novamente"** (re-executa).
Antes o botão era "Fechar Jogo" e o `CrashHandler` ligava `canceled/confirmed → get_tree().quit()` — um
erro de porta/conexão da `playonline` (ou até uma **validação da tela Models**) encerrava o jogo inteiro.
Motivo: erro de porta/conexão/validação é recuperável — o jogador ajusta e tenta de novo, sem perder a sessão.

**Cores dos botões (padrão do tema, 2026-06-25):** os styleboxes compartilhados (`scenes2D/menu/button_*.tres`,
usados via `ui_theme.tres` em todas as telas) foram padronizados — botão **sem foco = fundo CINZA**
(`button_normal`), **com foco = fundo PRETO** (`button_focus`, overlay opaco), texto **branco opaco** em todos
os estados (hover = cinza claro, pressionado = quase preto). **Hover e foco** recuperam o efeito **neon**:
**borda branca** + **sombra esfumaçada branca** (`shadow_size`), dando o brilho de luz neon ao redor do
controle. Os **botões × de fechar janela** seguem regra própria, `FloatingWindow.style_close_button(btn)`
(aplicada ao × da FloatingWindow E aos painéis Dano/IA): **sem foco = CINZA, com foco/hover = VERMELHO MEIO
ESCURO**, texto branco.

**Fundos animados:** cada tela 2D ganhou um shader `canvas_item` próprio (em `themes/backgrounds/`,
aplicado como `ShaderMaterial` no nó `Background/Bg` da cena, sobre a base navy) que **remete à função
da tela** — `levels_bg` (grade de fase em perspectiva), `playonline_bg` (rede de nós SUTIL, só nas bordas — o
centro fica calmo/navy p/ os textos do formulário ficarem LEGÍVEIS; reescrito 2026-06-25 porque a 1ª
versão acendia o centro e dificultava a leitura), `settings_bg` (equalizador + sliders),
`developer_bg` (blueprint + varredura horizontal). Barato (math
por pixel, sem texturas) → sem custo relevante numa tela de menu. As sessões host/cliente seguem com o
`session_signal_bg` (anéis de radar) — ver *Polimento de UI*.

## Otimização escolhível antes da sala — `NetConfig` (2026-06-24)

Autoload **`NetConfig`** (`autoload/net_config.gd`, persiste em `Settings`/seção `netopt`) + seletor na
tela **playonline** (3 dropdowns ESTÁTICOS no `.tscn` — colunas `HostColumn`/`BothColumn`/`ClientColumn`
com `HostRenderModes`/`SyncRates`/`Interpolations` (renomeados dos antigos `*Picker` na varredura de
nomes de 2026-07-03 — OptionButton no plural, sem sigla), `tab_order` 6/7/8 antes dos botões Host/Client;
o código só popula itens/seleção e conecta — `_build_optimization_options`/`_setup_opt_picker`, 2026-06-30,
antes eram montados em runtime). São prefs LOCAIS (não replicadas) — cada lado ajusta o que controla:
- **Suavização ↔ Resposta** — atraso de interpolação dos modelos remotos: Suave 100 ms / **Equilibrado
  60 ms (default)** / Responsivo 35 ms. Aplicado em `NetInterp.render_delay_ms` (agora `static var`).
- **Taxa de sincronização** — 30 / 60 Hz. Vale dos DOIS lados, cada um na direção que envia: o
  SERVIDOR seta `replication_interval = 1/Hz` nos synchronizers das entidades (`_apply_room_visibility`,
  broadcast servidor→clientes); o CLIENTE dono seta no próprio `InputSynchronizer` (`apply_authority`,
  upload do seu input). Não precisam casar — controlam fluxos diferentes.
- **Render do host** — Janela (observa salas) / **Servidor puro** (nenhuma sala renderiza → libera GPU;
  Observar/Jogar do host ficam desabilitados). Lido por `host_session._render_only`.
Regra do projeto ([[optimize-when-adding-scene-elements]]): trade-offs explícitos (resposta × suavidade/
banda/FPS) sem comprometer a experiência; o default Equilibrado já é mais rápido que o antigo 100 ms fixo.

**Escopo explícito na tela (2026-06-24):** o seletor é montado em **3 colunas** alinhadas com os botões
abaixo, com badge colorido de escopo: **SÓ NO HOST** (Render do host, esq./laranja, sobre "Gerenciar
Salas"), **HOST + CLIENTE** (Taxa de sync, meio/verde) e **SÓ NO CLIENTE** (Suavização↔Resposta,
dir./ciano, sobre "Entrar em Salas") + uma dica do trade-off interpolação×Hz. Localizado PT/EN: os
**Labels** usam texto canônico (pt) e o auto-localizer do [[locale]] traduz/re-traduz; os **itens dos
OptionButton** (que o Locale pula) são re-traduzidos por `_relocalize_options` no `language_changed`.
⚠️ Não passar `tr_key()` ao setar texto de Label que o auto-localizer cobre — grava o canônico errado
se a cena nascer em EN (o idioma é persistido) e o label não volta para pt.

## Modos de render do host (questão do usuário)

- **Headless** (`--headless`): GPU ociosa — ideal para muitas salas; só CPU/RAM. (A placa AMD de
  8GB não pesa aqui; importa CPU single-thread + RAM + rede.)
- **Com janela**: renderiza só a sala observada (as outras só simulam) → custo de GPU não multiplica.

## Estado / pendências

- ✅ **Fase 1 (validada em instância única):** servidor persistente, salas isoladas simulando em
  paralelo, grade de gerência, observação por sala.
- ✅ **Fase 2 (lado servidor validado em instância única; rede REAL pende 2 PCs):** spawn de players
  **por-sala** (`RoomManager`, isolado do `NetSpawn` single-level), **join de cliente** numa sala
  (`request_room_list`/`join_room`), espelho da sala no cliente, **visibilidade por-peer**. Corrigido
  `criatura_alada._find_player` (busca no próprio `SpawnedNodes`, não no `current_scene`).
- ✅ **Fase 3 — reorganização do fluxo (parse/carga validados; jogo interativo pende):** papel
  Host/Client por dois botões no `playonline`; `host_session` virou **server-only** e nasceu o
  `client_session` (client-only); **sala escolhida antes do `chooseplayer`** (marcadores
  `pending_play_*`); **host joga dentro da sala** (`host_spawn_in_room`, câmera livre desligada);
  **ESC** com confirmação para desconectar; **Parar** avisa os clientes da sala (`notify_room_closed`)
  e os manda à `client_session`; **Voltar** das sessões derruba o peer e volta ao `playonline`.
- ✅ **Interest management corrigido (2026-06-24, `feature/spawnplayer2`):** o `_apply_room_visibility`
  setava `public_visibility = false`, o que tornava TUDO invisível a todos os peers (filtros só vetam) —
  por isso o `client_session` não via o level/câmera e players/inimigo não sincronizavam. Agora só
  adiciona o filtro (mantém `public_visibility` no default `true`). Ver a seção *Isolamento por sala*.
- ✅ **Teste A (loopback `127.0.0.1`, 2 instâncias) VALIDADO em campo (2026-07-02):** `playonline` local
  OK; cliente entra e nasce na sala (cenário, não cinza), host mostra "(1 conexão)", replicação
  cliente↔host. **O netcode está provado** — só falta o transporte de rede real (Teste B/C). Ver
  [[🧪 teste-salas-multiplayer (PT)|🧪 teste-salas-multiplayer]].
- ✅ **Guarda de corrida do "Jogar" no cliente (2026-07-02):** ao voltar do `chooseplayer`, o
  `client_session` revalida via `server_room_list()` que a sala ainda existe (o `RoomManager` autoload
  segue recebendo `receive_room_list` durante a escolha do personagem). Se o host PAROU/reiniciou a sala
  nesse meio-tempo, NÃO nasce numa sala morta: volta ao navegador com o aviso "A sala não está mais
  disponível" (helper `_server_has_room`). Evita a cena vazia de entrar numa sala que não roda mais.
- ✅ **Rede REAL entre 2 PCs VALIDADA (2026-08-05):** testado via **playit.gg** (túnel UDP), após
  corrigir o **congelamento do inimigo no cliente** (stall de render + timeout do ENet + falta de
  handler `server_disconnected`) — ver a seção *Congelamento do inimigo no cliente* (release
  `202608051826`).
- ✅ **Hitch de 1ª entrada: RESOLVIDO** (2026-08-05) pela **tela de "Carregando"** (`LoadingScreen`):
  o startup paga adiantado o setup global do renderer (−76% na entrada seguinte) e cada entrada em
  level/sala é coberta pela tela. **Pré-aquecimento offscreen foi medido e descartado** (5 abordagens,
  todas 0–25%); **não reexplorar** sem ler aquela medição.
- ⏳ **Pendências:**
  `enemy_health_bar.get_shared(get_tree().current_scene)` (HUD do inimigo) ainda é global —
  no cliente com 1 sala fullscreen funciona; no host observando/jogando pode aparecer no lugar errado.
  Ver [[🌐 multiplayer (PT)|🌐 multiplayer]].
