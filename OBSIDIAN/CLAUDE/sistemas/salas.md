# Salas simultâneas (servidor multi-level)

> Permite ao host rodar **vários levels ao mesmo tempo** e gerenciá-los (iniciar/parar/reiniciar,
> **observar** e **jogar** em cada um) sem que sair de um derrube o servidor. O papel (Host/Client) é
> escolhido no `playonline` (dois botões) e a **sala é escolhida ANTES** do `chooseplayer` — só então o
> player nasce nela. Relacionado: [[sistemas/multiplayer]], [[sistemas/hospedagem-online]],
> [[fluxos/fluxo-de-cenas]].

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
- API: `start_room(level_path) -> id`, `stop_room(id)` (avisa os clientes da sala via
  `notify_room_closed` antes de liberar), `restart_room(id) -> novo_id`, `get_rooms()`, `stop_all()`;
  **host joga:** `host_spawn_in_room(id, variant_id)` / `host_leave_room()`; **cliente sai:**
  `client_leave_room(id)` (+ RPC `leave_room`); sinais `rooms_changed` e `room_closed(id)`. Marcadores
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
    `ConfirmationDialog` ("Desconectar e voltar para a gerência ?") → `host_leave_room` e volta à grade.
  - **Parar:** encerra **só aquela sala**; os clientes que jogavam nela recebem `notify_room_closed`,
    veem **"O Servidor foi desligado"** e voltam ao navegador da `client_session`. Outras salas seguem.
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

`RoomManager._apply_room_visibility` põe `public_visibility = false` + um *visibility filter* em cada
`MultiplayerSynchronizer` de tudo que entra no `SpawnedNodes` da sala (inimigos, balas, players): só
replica para peers cujo `_peer_room[peer] == room_id`. Ao um peer entrar, `_refresh_room_visibility`
chama `update_visibility()` → os spawns já existentes (inimigos) são (re)enviados a ele. Mesmo que a
engine ainda envie algo cruzado, o cliente só espelha a SUA sala (os caminhos das outras não existem
nele) → tráfego cruzado é descartado.

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
- ⏳ **Pendências:** testar o **host jogando** numa sala (câmera/mira/tiro no SubViewport) e validar a
  replicação real entre 2 PCs (join/leave de cliente, kick do Parar, spawn por sala, interest
  management). `enemy_health_bar.get_shared(get_tree().current_scene)` (HUD do inimigo) ainda é global —
  no cliente com 1 sala fullscreen funciona; no host observando/jogando pode aparecer no lugar errado.
  Ver [[sistemas/multiplayer]].
