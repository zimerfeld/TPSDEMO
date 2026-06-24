# Salas simultâneas (servidor multi-level) — Fase 1

> Permite ao host rodar **vários levels ao mesmo tempo** e gerenciá-los (start/stop/restart/observar)
> sem que sair de um derrube o servidor. Relacionado: [[sistemas/multiplayer]], [[sistemas/hospedagem-online]],
> [[fluxos/fluxo-de-cenas]].

---

## Arquitetura

- **`RoomManager`** (`autoload/room_manager.gd`, autoload persistente): cada "sala" é um nível
  rodando dentro de um **`SubViewport` com `World3D` próprio** (`own_world_3d = true`). Isso isola
  **física, navegação e `WorldEnvironment`** — sem World3D separado, dois níveis ocupariam o mesmo
  espaço e os ambientes brigariam (só vale 1 `WorldEnvironment` por World3D).
- Como vive no autoload, as salas **sobrevivem à troca de cena** → o peer ENet **não** é fechado ao
  navegar; só ao "Voltar ao menu" (`host_session._exit_tree` → `RoomManager.stop_all()`).
- **Render sob demanda (otimização):** os SubViewports ficam em `UPDATE_DISABLED`; só a sala
  **observada** vira `UPDATE_ALWAYS`. A **simulação dos inimigos roda em TODAS** as salas, independente
  do render → não se paga GPU por salas que ninguém está vendo.
- API: `start_room(level_path) -> id`, `stop_room(id)`, `restart_room(id) -> novo_id`,
  `get_rooms()`, `stop_all()`, sinal `rooms_changed`.

## Hub de salas (`scenes2D/host_session/`) — dois modos pelo papel na rede

- **SERVIDOR (host)** — botão **"Gerenciar Salas"** da `playonline` (`_on_manage_rooms_pressed`):
  cria o servidor ENet, atribui o peer e troca para `host_session.tscn` (peer mantido). UI: seletor
  de nível + **Iniciar Sala**; lista com **Observar / Reiniciar / Parar**; **Voltar ao menu**.
  - **Observação:** mostra a textura do SubViewport da sala em tela cheia. Mouse **VISÍVEL** na
    grade, **CAPTURADO** ao observar (o movimento do mouse é empurrado p/ a sala via
    `viewport.push_input` → a câmera livre olha em volta). **ESC** sai da observação (1º) e encerra
    o servidor (2º). A câmera livre por sala é adicionada pelo `RoomManager.register_room_level`.
- **CLIENTE** — botão **"Entrar em Salas"** (`_on_join_rooms_pressed`): conecta como cliente e, no
  `connected_to_server`, abre o `host_session` em **modo cliente** (navegador). Pede a lista de
  salas (`request_room_list` RPC), mostra **#id — level (N jogadores) + Entrar**. Ao entrar:
  `client_join_room` espelha a sala como **Node comum** (renderiza na **janela principal** → input/
  câmera de jogo normais, sem SubViewport) e manda `join_room` ao servidor, que spawna o player lá.

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
- ⏳ **Pendências:** validar a replicação real entre 2 PCs (spawn de players/inimigos por sala,
  interest management). `enemy_health_bar.get_shared(get_tree().current_scene)` (HUD do inimigo)
  ainda é global — no cliente com 1 sala fullscreen funciona; no host observando pode aparecer no
  lugar errado. Ver [[sistemas/multiplayer]].
