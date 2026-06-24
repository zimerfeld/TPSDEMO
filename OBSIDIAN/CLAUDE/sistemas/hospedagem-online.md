# Hospedagem Online (jogar com amigos pela internet)

> Como expor a máquina-host para que outro jogador conecte pela internet.
> Relacionado: [[sistemas/multiplayer]]

---

## Contexto técnico

- O jogo usa **ENetMultiplayerPeer** → `create_server()` / `create_client()` em `scenes2D/playonline/playonline.gd`.
- ENet roda sobre **UDP**. A porta padrão é **UDP 4383** (`playonline.tscn`, SpinBox `Port`, `value = 4383`).
- O campo **Address** aceita hostname (o ENet resolve nome), então dá pra usar domínios em vez de IP.
- O campo **Port** aceita **1–65535**. (Antes o `max_value` do SpinBox era 49151, que **truncava** portas dinâmicas como as do playit — ex.: digitar 54417 virava 49151 e a conexão falhava. Corrigido p/ 65535.)
- **Histórico de porta/IP:** ao lado de Port e Address há um `OptionButton` ("Selecione…") com os **últimos 3 valores** usados. Persistido em `Settings.config_file` seção **`online`** (chaves `ports` / `addresses`), recarregado no `_ready` (`_refresh_history`). Selecionar um item preenche o campo e o dropdown volta a "Selecione…".
  - O campo Address guarda o **texto cru** — funciona igual para **IP** (`147.185.221.26`) e **domínio** (`wharf-pos.gl.at.ply.gg`).
  - Gravado: ao clicar **Host**/**Connect** (`_remember`), ao pressionar **Enter** e ao o campo **perder o foco** (`_on_address_focus_exited` / `_on_port_focus_exited` — o Port salva pelo `get_line_edit().focus_exited` do SpinBox). Atualiza o dropdown na hora. ENet (`create_client`) resolve hostname, então domínio conecta direto.
- **Layout da tela** (`playonline.tscn`): cada input tem um **Label à esquerda** localizado — `Port:` (PT "Porta:") e `IP Address/Domain:` (PT "Endereço IP/Domínio:"), via `Resources/playonline.*.json`. A `ButtonsRow` centralizada **abaixo** das linhas de Port/Address tem **três botões**:
  - **HostButton** ("Hospedar e Conectar") → `_on_host_pressed`: hospeda E entra no jogo como player (comportamento clássico do antigo "Host").
  - **HostOnlyButton** ("Hospedar Somente") → `_on_host_only_pressed`: hospeda mas **não** entra como player — abre uma **câmera livre de observação** (`scenes3D/spectator_camera/`) para acompanhar o level ao vivo (ver seção abaixo).
  - **ConnectButton** ("Conectar") → `_on_connect_pressed`: **(2026-06-24)** faz primeiro uma **sondagem
    ("probe")** — conecta brevemente ao host só para **perguntar qual cenário ele hospeda** (RPC
    `NetSpawn.request_scenario` → `answer_scenario`). Só mostra o **`ConfirmationDialog`** ("Deseja se
    re-conectar na partida em andamento ?", Sim/Não) **quando o cenário do host é o MESMO** que o cliente
    escolheu (`_selected_level()`); caso contrário conecta direto, sem perguntar. O probe é **descartado**
    (`_end_probe` fecha o socket e volta ao `OfflineMultiplayerPeer`) antes do **join real** (`_do_connect`),
    preservando a ordem de carga do nível (o spawner do cliente precisa existir antes do join, senão
    perde os spawns já existentes). Falha de conexão → erro; sem resposta em `PROBE_TIMEOUT` (3 s, ex.:
    servidor antigo sem o RPC) → conecta direto. O diálogo não empilha (guarda `_reconnect_dialog`).
    Strings em `Resources/playonline.*.json` (`Reconectar`, `Deseja…`, `Sim`, `Não`).
  - Os três compartilham `_start_host()` (host) — o modo é gravado em `PlayerSelection.spectator_host` (true só no "Hospedar Somente") e lido no `NetSpawn.setup` dos **3 níveis** (level_base/1/2).

> **Reconexão (mesmo cenário):** um cliente pode reentrar numa partida em andamento enquanto houver um
> host (o servidor respawna o player no `peer_connected` via `NetSpawn`). Mas a confirmação só faz sentido
> quando se reentra no **mesmo cenário** — por isso o **Conectar** pergunta o cenário ao servidor antes de
> decidir. Cenário diferente conecta direto, sem o diálogo. Ver [[sistemas/multiplayer]].

> ⚠️ **ngrok NÃO funciona** aqui: ngrok só faz túnel de **TCP/HTTP**, não suporta **UDP**. Sem alterar o jogo para WebSocket/TCP, não há configuração de ngrok que conecte ao host ENet.

---

## Modo "Hospedar Somente" (câmera livre de observação)

Hospeda o servidor **sem** virar player: o host voa pelo level com uma câmera livre, sem colisão e
sem player controlado, para ver em tempo real o que acontece (robôs, players conectados).

- **Fluxo:** `_on_host_only_pressed` (playonline) seta `PlayerSelection.spectator_host = true` e chama
  `_start_host()` (mesmo servidor ENet do "Hospedar e Conectar"). **(2026-06-24)** a câmera é adicionada
  pelo **`NetSpawn.setup`** quando `spawn_host=false` (`_add_spectator_camera`), valendo para os **3
  níveis** — antes só o `level_base` tratava, então no `level_1`/`level_2` o "Hospedar Somente" criava
  player do host por engano. O jogo **offline** reseta `spectator_host=false` em `levels.gd` (solo sempre
  tem player).
- **Câmera** (`scenes3D/spectator_camera/spectator_camera.{gd,tscn}`): um `Camera3D` filho **direto do
  level** (fora do `SpawnedNodes` → **não replica**; existe só na instância do servidor). Não consome
  spawn point — todos ficam para os clientes.
- **Controles:** **WASD** voa no plano (relativo ao yaw da câmera); **mouse** olha em volta (mouse
  capturado); **Espaço+W** sobe e **Espaço+S** desce **na velocidade do pulo** do player
  (`VERTICAL_SPEED = 5.0 = Player.JUMP_SPEED`); a velocidade é suavizada por `lerp` (start/stop sem
  solavanco). <kbd>Escape</kbd> volta ao menu (tratado pelo `level_base._input`).

> Em "Hospedar Somente" **nenhum nó player "1"** é criado em `SpawnedNodes`. Como a câmera não é
> replicada, no servidor ela permanece `current` (os players de clientes só fazem `make_current` no
> peer dono, não no servidor).

---

## Opção 1 — playit.gg (substituto do ngrok, suporta UDP, grátis)

1. Baixar e rodar o agente em https://playit.gg
2. Criar túnel do tipo **UDP** apontando para `127.0.0.1:4383`
3. **Proxy Protocol:** ❌ **desativado** (o ENet do Godot não entende o cabeçalho PROXY — quebraria a conexão)
4. O playit gera um endereço público, ex.: `wharf-pos.gl.at.ply.gg:54417`
5. Host: abrir o jogo → **Host**. Amigo: **Address** = domínio, **Port** = porta do painel → **Connect**

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

| Papel | Address | Port | Botão |
|---|---|---|---|
| **Host** | *(ignorado — pode deixar vazio)* | `4383` (a mesma do túnel) | **Host / Hospedar** |
| **Conectar** | `wharf-pos.gl.at.ply.gg` (só domínio, **sem** `:porta`) | `54417` (porta **pública** do painel) | **Connect / Conectar** |

- **Host** (`_on_host_pressed`): `create_server(port)` usa **só a porta**, nunca o Address. Essa porta deve ser a mesma que o túnel playit redireciona (local address `4383`).
- **Conectar** (`_on_connect_pressed`): `create_client(address, port)` — domínio num campo, porta no outro. O ENet resolve hostname, então **domínio = IP**. Não cole `dominio:porta` no Address: o `:porta` vai no campo **Port** separado.

### Estabilidade dos valores gerados
- **Domínio + porta** (`xxxxx.gl.at.ply.gg:PORTA`): **fixos enquanto o túnel existir**. Mudam se o túnel for **apagado e recriado** (porta aleatória no plano grátis).
- **IP cru** (`147.185.221.26:...`): **compartilhado/anycast, pode mudar** — **não compartilhar**. Sempre passar o **domínio**.
- Endereço permanente/personalizado: só nos planos **pagos**.

### Erros comuns
- **`RequiresVerifiedAccount`**: a conta playit precisa de **e-mail verificado**. Resolver em https://playit.gg/account adicionando e-mail + confirmando, **ou** logar via **Discord/Google** (já vem verificado).
- A **porta pública** pode ser diferente de 4383 — o amigo deve usar a porta que aparece no **painel do playit**.

---

## Opção 2 — Tailscale ou ZeroTier (LAN virtual / VPN — mais confiável)

Cria uma rede local entre as máquinas, sem mexer no roteador nem expor porta na internet.

1. Host e amigo instalam o **Tailscale** (https://tailscale.com) e logam na **mesma rede** (login Google/etc.)
2. Host abre o jogo → **Host** (porta 4383)
3. Amigo conecta usando o **IP Tailscale da máquina-host** (ex.: `100.x.x.x`) + porta **4383**

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
