---
tipo: sistema
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 🛰️ Hospedagem Online (jogar com amigos pela internet)

> Como expor a máquina-host para que outro jogador conecte pela internet.
> Relacionado: [[🌐 multiplayer (PT)|🌐 multiplayer]]

---

## Contexto técnico

- O jogo usa **ENetMultiplayerPeer** → `create_server()` / `create_client()` em `scenes2D/playonline/playonline.gd`.
- ENet roda sobre **UDP**. A porta padrão é **UDP 44000** (`playonline.tscn`, SpinBox `Port`, `value = 44000`) — a mesma porta do túnel playit do projeto. Era `4383` até 2026-08-06.
- O campo **Address** aceita hostname, então dá pra usar domínios em vez de IP. Um **rótulo de formato** abaixo do campo (`AddressFormatHint`) diz isso ao jogador: "Aceita domínio (ex.: `zimaro.playit.game`) ou IP — a porta vai no campo Porta."
- **Resolução de DNS assíncrona (2026-08-06).** O `create_client` do ENet resolve hostname sozinho, mas de forma **bloqueante** — numa rede lenta o frame trava até o DNS responder e o jogo parece congelado. Agora `_on_join_rooms_pressed` só chama `create_client` com um **IP já resolvido**:
  - IP literal (`is_valid_ip_address()`) → conecta direto, sem resolver.
  - Hostname → `IP.resolve_hostname_queue_item(host, IP.TYPE_ANY)` (fila do resolver, roda em thread) e o `_process` consulta o status por `_poll_resolve()` sem bloquear; ao concluir chama `_start_client(ip, host)`.
  - **Preferência por IPv4** (`_pick_address`): o playit publica A **e** AAAA e o resolver costuma devolver o IPv6 primeiro (`zimaro.playit.game` → `2602:fbaf:824:1::1d` e `147.185.221.29`). Conectar pelo IPv6 excluiria quem não tem rota IPv6, então escolhemos o primeiro endereço **sem** dois-pontos; só caímos no IPv6 se não houver IPv4.
  - **Rótulo de status** (`ConnectStatus`, grupo `loc_manual`): "Resolvendo endereço…" → "Conectando…", limpo ao abortar. Falha de DNS mostra aviso próprio (`MSG_RESOLVE_FAILED`) com o nome digitado; campo vazio avisa antes de tentar (`MSG_EMPTY_ADDRESS`).
  - **Status e "Carregando" nunca se sobrepõem (2026-08-06).** O painel de *Carregando* (com a barra de progresso) não aparece mais junto com o "Conectando…": o `_start_client` só arma o peer e os sinais; o `loading.show()` (e o `_clear_status()`) passaram para o `_on_client_connected_await_version`, que roda quando o ENet **fecha** a conexão. A ordem visível vira *Resolvendo → Conectando →* (conectou) *→ Carregando*, este último cobrindo o handshake de versão até a abertura do navegador de salas.
  - O item da fila é liberado (`erase_resolve_item`) ao concluir e no `_exit_tree`, para não vazar entre entradas na tela.
- O campo **Port** aceita **1–65535**. (Antes o `max_value` do SpinBox era 49151, que **truncava** portas dinâmicas como as do playit — ex.: digitar 54417 virava 49151 e a conexão falhava. Corrigido p/ 65535.)
- **Histórico de porta/IP:** ao lado de Port e Address há um `OptionButton` ("Selecione…") com os **últimos 3 valores** usados. Persistido em `Settings.config_file` seção **`online`** (chaves `ports` / `addresses`), recarregado no `_ready` (`_refresh_history`). Selecionar um item preenche o campo e o dropdown volta a "Selecione…".
  - O campo Address guarda o **texto cru** — funciona igual para **IP** (`147.185.221.26`) e **domínio** (`wharf-pos.gl.at.ply.gg`).
  - Gravado: ao clicar **Host**/**Connect** (`_remember`), ao pressionar **Enter** e ao o campo **perder o foco** (`_on_address_focus_exited` / `_on_port_focus_exited` — o Port salva pelo `get_line_edit().focus_exited` do SpinBox). Atualiza o dropdown na hora. O domínio conecta direto — resolvido antes na fila assíncrona do `IP` (ver "Resolução de DNS assíncrona" acima).
  - **Domínios completos salvos (2026-06-25):** todo **domínio completo** (FQDN — tem letra e ponto, ex.: `wharf-pos.gl.at.ply.gg`) também entra numa lista PERSISTENTE própria (seção `online`, chave `domains`, cap `DOMAIN_MAX = 12`) que **não rola** junto com os IPs recentes. O dropdown de Address junta os endereços recentes **+ esses domínios salvos**, deduplicados (`_fill_address_history`, `_remember_address`, `_is_full_domain`) — assim um domínio digitado uma vez fica disponível para seleção mesmo depois de usar vários IPs.
- **Layout da tela** (`playonline.tscn`): cada input tem um **Label à esquerda** localizado — `Port:` (PT "Porta:") e `IP Address/Domain:` (PT "Endereço IP/Domínio:"), via `Resources/playonline.*.json`. **Abaixo** de Port/Address há dois botões (sem radios; clicáveis direto):
  - **ManageRooms** ("Gerenciar Salas", `_on_manage_rooms_pressed`) = papel **Host**: cria um servidor ENet **persistente** e abre o `host_session` (gerenciador de salas). Ver [[🚪 salas (PT)|🚪 salas]].
  - **JoinRooms** ("Entrar em Salas", `_on_join_rooms_pressed`) = papel **Client**: conecta como cliente e, no `connected_to_server`, abre o `client_session` (navegador de salas).
  - Os antigos botões single-level (**Hospedar e Conectar / Hospedar Somente / Conectar**) e a sondagem de reconexão ("probe") **foram removidos** — o fluxo agora é só por salas. O **"Voltar"** do `playonline` volta ao menu; o das sessões volta ao `playonline` (derrubando o peer).
  - **Headless (servidor dedicado):** o `playonline` chama `_on_manage_rooms_pressed` e auto‑inicia uma sala com o `level_1` (`DEFAULT_ROOM_LEVEL`).

> **Entrar em partida em andamento:** no fluxo de salas o cliente simplesmente escolhe uma **sala em
> execução** no navegador (`client_session`) e entra — o servidor spawna o player nela. Não há mais a
> sondagem de cenário nem o `ConfirmationDialog` de reconexão (eram do antigo "Conectar" single-level).
> Ver [[🚪 salas (PT)|🚪 salas]], [[🌐 multiplayer (PT)|🌐 multiplayer]].

> ⚠️ **ngrok NÃO funciona** aqui: ngrok só faz túnel de **TCP/HTTP**, não suporta **UDP**. Sem alterar o jogo para WebSocket/TCP, não há configuração de ngrok que conecte ao host ENet.

---

## Câmera livre de observação ("Observar" uma sala)

No `host_session`, **Observar** uma sala mostra o level ao vivo (robôs, players conectados) por uma
câmera livre, **sem colisão e sem player controlado**.

- **Fluxo:** a câmera é adicionada por `RoomManager.register_room_level` em cada sala do servidor. Ao
  clicar **Observar**, a sala vira `UPDATE_ALWAYS` e sua textura é mostrada em tela cheia; o mouse é
  **capturado** e empurrado ao SubViewport (`push_input`) → a câmera olha em volta. **ESC** sai da
  observação. (No **"Jogar"** do host, essa câmera é **desligada** e dá lugar à câmera do player.)
- **Câmera** (`scenes3D/spectator_camera/spectator_camera.{gd,tscn}`): um `Camera3D` filho **direto do
  level** (fora do `SpawnedNodes` → **não replica**; existe só na instância do servidor). Não consome
  spawn point — todos ficam para os clientes.
- **Controles:** **WASD** voa no plano (relativo ao yaw da câmera); **mouse** olha em volta (mouse
  capturado); **Espaço+W** sobe e **Espaço+S** desce **na velocidade do pulo** do player
  (`VERTICAL_SPEED = 5.0 = Player.JUMP_SPEED`); a velocidade é suavizada por `lerp` (start/stop sem
  solavanco).

---

## Opção 1 — playit.gg (substituto do ngrok, suporta UDP, grátis)

1. Baixar e rodar o agente em https://playit.gg
2. Criar túnel do tipo **UDP** apontando para `127.0.0.1:4383`
3. **Proxy Protocol:** ❌ **desativado** (o ENet do Godot não entende o cabeçalho PROXY — quebraria a conexão)
4. O playit gera um endereço público, ex.: `wharf-pos.gl.at.ply.gg:54417`
5. Host: abrir o jogo → **Gerenciar Salas** e **Iniciar Sala**. Amigo: **Address** = domínio, **Port** = porta do painel → **Entrar em Salas** → **Jogar** na sala

### Por que conectar no domínio do playit e não no IP local (`192.168.x.x`)

São **duas pontas do mesmo túnel**, e só uma é alcançável pela internet:

```
Amigo (internet)            playit.gg (nuvem)          Sua máquina (LAN)
────────────────            ─────────────────          ──────────────────
wharf-pos…:54417  ─UDP►   servidor relay playit  ─►   agente playit  ─►  192.168.0.33:4383
 (endereço PÚBLICO)         (IP roteável na net)       (no seu PC)         (jogo / ENet)
```

- `192.168.0.33:4383` é **IP privado de LAN** — só existe dentro da sua rede; ninguém na internet o alcança. É o destino *interno* para onde o agente entrega o tráfego.
- `wharf-pos.gl.at.ply.gg:54417` é o **endereço público** criado nos relays do playit — esse sim é alcançável de qualquer lugar.
- O agente no seu PC mantém o túnel aberto: pacotes p/ `…:54417` → relay → agente → `192.168.0.33:4383` (jogo). Por isso **nunca compartilhe o `192.168…`** (não significa nada fora da sua rede) e a **porta pública** (54417) é diferente da local (4383).

### Valores na UI PlayOnline (`playonline.gd`)

| Papel | Address | Port | Como |
|---|---|---|---|
| **Host** | *(ignorado — pode deixar vazio)* | `4383` (a mesma do túnel) | **Gerenciar Salas** |
| **Client** | `wharf-pos.gl.at.ply.gg` (só domínio, **sem** `:porta`) | `54417` (porta **pública** do painel) | **Entrar em Salas** |

- **Host** (`_on_manage_rooms_pressed`): `create_server(port)` usa **só a porta**, nunca o Address. Essa porta deve ser a mesma que o túnel playit redireciona (local address `4383`).
- **Client** (`_on_join_rooms_pressed`): `create_client(address, port)` — domínio num campo, porta no outro. O ENet resolve hostname, então **domínio = IP**. Não cole `dominio:porta` no Address: o `:porta` vai no campo **Port** separado.

### Estabilidade dos valores gerados
- **Domínio + porta** (`xxxxx.gl.at.ply.gg:PORTA`): **fixos enquanto o túnel existir**. Mudam se o túnel for **apagado e recriado** (porta aleatória no plano grátis).
- **IP cru** (`147.185.221.26:...`): **compartilhado/anycast, pode mudar** — **não compartilhar**. Sempre passar o **domínio**.
- Endereço permanente/personalizado: só nos planos **pagos**.

### Handshake de versão (host e cliente na mesma build)
Desde 2026-08-05, ao conectar, host e cliente trocam um **ID de build**: o `RoomManager` envia a versão
no `peer_connected` e o cliente compara em `receive_host_version`. Se as versões **diferem**, o cliente
**recusa** com o aviso *"Versões incompatíveis — Host: X, Você: Y"* (PT/EN/ES) em vez de falhar no escuro;
se o host for uma build antiga que nem responde, um **timeout de 5 s** mostra *"Não foi possível verificar
a versão do host"*. O ID é carimbado no export pelo `build_windows.ps1` de forma **determinística** via
`git describe --tags --dirty --always` (`build_id.json` = a tag exata quando o commit está numa tag, ex.:
`202608051426`; senão `<tag>-<n>-g<sha>`; sufixo `-dirty` se houver mudança não commitada; lido por
`RoomManager.game_version`, embutido no `.exe`). No **editor** todos batem (`editor-dev`). Regra prática:
**rodar o mesmo `.exe`** — e, como o ID agora é determinístico, **buildar o mesmo commit** também gera o
mesmo ID e casa no handshake. Ver [[🌐 multiplayer]].

### Erros comuns
- **`RequiresVerifiedAccount`**: a conta playit precisa de **e-mail verificado**. Resolver em https://playit.gg/account adicionando e-mail + confirmando, **ou** logar via **Discord/Google** (já vem verificado).
- A **porta pública** pode ser diferente de 4383 — o amigo deve usar a porta que aparece no **painel do playit**.

---

## Opção 2 — Tailscale ou ZeroTier (LAN virtual / VPN — mais confiável)

Cria uma rede local entre as máquinas, sem mexer no roteador nem expor porta na internet.

1. Host e amigo instalam o **Tailscale** (https://tailscale.com) e logam na **mesma rede** (login Google/etc.)
2. Host abre o jogo → **Gerenciar Salas** (porta 4383) e inicia uma sala
3. Amigo: **Entrar em Salas** usando o **IP Tailscale da máquina-host** (ex.: `100.x.x.x`) + porta **4383**

- **Vantagens:** latência boa, estável, nada exposto publicamente, **sem verificação de conta**.
- **ZeroTier** é equivalente (rede virtual com ID de rede compartilhado).

---

## Opção 3 — Port forwarding no roteador (sem programa extra)

1. Redirecionar **UDP 4383** para o IP local da máquina-host
2. Liberar a porta no **Firewall do Windows** (UDP 4383, entrada)
3. Amigo conecta no **IP público** do host (https://meuip.com.br) + porta 4383

- **Desvantagem:** expõe a porta publicamente e depende do NAT da operadora (**CGNAT** pode bloquear).

---

## Recomendação

- Jogar rápido com amigos → **Tailscale** (Opção 2).
- Endereço "público" estilo ngrok → **playit.gg** (Opção 1).
