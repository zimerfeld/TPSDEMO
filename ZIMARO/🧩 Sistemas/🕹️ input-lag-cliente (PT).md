---
lang: pt-BR
---

# 🕹️ Input lag do cliente

Investigação e correção da latência de resposta sentida por quem joga como **cliente** (2026-08-07).
Notas irmãs: [[🕹️ input-lag-cliente (EN)|EN]] · [[🕹️ input-lag-cliente (ES)|ES]]. Ver também
[[🚪 salas (PT)]] e [[🧩 templates-de-level (PT)]].

## O enquadramento que mudou o diagnóstico

Levantamos 58 hipóteses de latência e verificamos cada uma contra o código; 29 se confirmaram. O
achado que organiza tudo: **quase todo número grande é simétrico** — host e cliente pagam igual
(aquecimento de mira, vsync, interpolação de física, slerp do corpo, custo de GPU). O que **só o
cliente paga**:

| Termo assimétrico | Custo | Onde |
| --- | --- | --- |
| Feedback do tiro só volta pelo `shoot.rpc()` | RTT + ~35 ms | `player.gd` |
| Quantização do upload de input | 0–33 ms (média 16,7) | `player_input.gd` |
| `render_delay_ms` na idade dos alvos remotos | 60 ms (estava em **100**) | `net_config.gd` |
| RTT do túnel playit | não medido | transporte |

Ou seja: reclamar de "input lag" e mexer em GPU/vsync não resolveria — esses custos o host também
tem, e ele não reclama.

## O que foi corrigido

- **Feedback do tiro previsto no cliente** (`player.gd`). O sensorial (partícula, clarão, som,
  tremida) saiu de `shoot()` para `_play_shot_fx()`; o cliente dono toca no instante do clique e o
  `shoot()` do servidor, chegando depois, reconhece e não repete (`SHOT_FX_DEDUPE_MS`).
  **Bala e dano continuam 100% no servidor** — só o que o jogador vê e ouve foi antecipado.
  Duas armadilhas evitadas: o gate local usa relógio próprio (`_local_fx_at` + `wait_time` do
  cooldown), **não** o `FireCooldown` (que só o servidor inicia); e o **primeiro** tiro de cada
  sessão de mira não é previsto — o aquecimento local corre à frente do servidor, e prever o primeiro
  faria o efeito sair antes da autorização, sistematicamente.
- **Upload do input desacoplado do `sync_hz`** (`player_input.gd` + `NetConfig.input_interval()`).
  A "Taxa de sincronização" dimensiona o **broadcast de estado** (muitas entidades × muitos peers);
  amarrar a ela um pacote de ~40 B com as teclas de um jogador punha até 33 ms na frente de toda ação
  para economizar ~2 KB/s. Agora o cliente envia no ritmo do frame. **Guard obrigatório**
  `if not multiplayer.is_server()`: no host esse mesmo synchronizer é autoritativo, e `apply_authority`
  é deferido — sem o guard ele sobrescreveria o intervalo que o RoomManager aplicou à sala.
- **`AIM_WARMUP_TIME` 0,45 → 0,25 s** e decaimento em vez de zeragem no ar. O piso técnico é 0,20 s
  (o `xfade_time` do `AnimationNodeTransition` que assenta a pose do GunBone); abaixo disso o glitch
  da bala fora do cano volta. E um pulo zerava o aquecimento inteiro de quem já mirava há tempo.
- **`reset_physics_interpolation()` após o snap de `_reconcile`**. Com interpolação de física ligada,
  a correção de posição era desenhada "rasgando" da posição antiga até a nova.
- **Bug do SSAO** (`config.gd`): o segundo teste era `if` e não `elif`, então "Desligado" caía no
  `else` e **religava** o efeito — e o mapeamento estava trocado (Média pedia HIGH em resolução
  cheia, o mais caro dos três). Corrigido e desligado de fábrica.
- **Bala avança suave no cliente** (`bullet.gd`): recebia só o transform a 30 Hz e saltava 0,67 m por
  amostra. Agora integra a posição por frame — visual apenas, sem colisão, dano ou RPC. Não usa
  `NetInterp` de propósito: interpolar renderiza no passado e deixaria a bala atrás do cano.
- **Preferência de interpolação** voltou de "Suave" (100 ms) para "Equilibrado" (60 ms) — 40 ms de
  idade dos alvos, sem uma linha de código.

## O que ficou de fora, e por quê

- **Parar de replicar `.:motion` para o dono** (o servidor sobrescreve a predição ~30×/s) e
  **reconciliação suave com limiar por RTT**: os dois mexem no mesmo ponto e têm dependência dura —
  a reconciliação vem primeiro, senão troca-se "movimento mole" por "teleporte a cada 2 m". E não há
  **nenhuma evidência medida** de que o snap dispare hoje: instrumentar contador de snaps antes.
- **Buffer de input com replay/rollback**: inviável nesta arquitetura, não é questão de risco. O
  movimento é 100% root motion do `AnimationTree`, e a engine não oferece snapshot/restore do estado
  de blend/xfade nem rebobinagem do mundo físico.
- **Rig de câmera fora da interpolação de física**: ganho medido de 8–11 ms num harness headless,
  mas é **simétrico** e exige `top_level` + `get_global_transform_interpolated()` — sem isso a câmera
  anda em degraus de 60 Hz enquanto o modelo continua interpolado.
- **`frame_queue_size=1`**: valor inválido (mínimo da engine é 2).
- **Compressão RANGE_CODER**: custo em microssegundos; mudar de um lado só quebra a conexão antes do
  handshake de versão — falha muda.

## Bug registrado à parte

**`hp` não está em nenhum `SceneReplicationConfig`.** Um `hit()`/`respawn()` perdido causa
dessincronia **permanente** de vida/membros no HUD do cliente. Não é latência: é estado que nunca se
auto-cura. Vale uma correção própria.

## Como medir de verdade

Nada acima foi cronometrado dentro do jogo — as contas vêm do código (grades de 16,7/33,3 ms, RTT).
O caminho honesto: ligar o Performance HUD, registrar `NET` (`PEER_ROUND_TRIP_TIME`), FPS e frame
time nas quatro combinações (host × cliente, loopback × túnel), antes e depois. Para o tiro,
instrumentar `Time.get_ticks_usec()` entre `is_action_just_pressed("shoot")` e a entrada de
`_play_shot_fx()`: o alvo é o delta do cliente cair para a mesma ordem do host.
