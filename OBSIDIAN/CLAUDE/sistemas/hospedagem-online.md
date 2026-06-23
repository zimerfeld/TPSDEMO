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
- **Layout da tela** (`playonline.tscn`): cada input tem um **Label à esquerda** localizado — `Port:` (PT "Porta:") e `IP Address/Domain:` (PT "Endereço IP/Domínio:"), via `Resources/playonline.*.json`. Os botões **HostButton** / **ConnectButton** (nós renomeados; texto "Host"/"Connect" → PT "Hospedar"/"Conectar") ficam juntos numa `ButtonsRow` centralizada **abaixo** das linhas de Port/Address, com espaço entre eles.

> ⚠️ **ngrok NÃO funciona** aqui: ngrok só faz túnel de **TCP/HTTP**, não suporta **UDP**. Sem alterar o jogo para WebSocket/TCP, não há configuração de ngrok que conecte ao host ENet.

---

## Opção 1 — playit.gg (substituto do ngrok, suporta UDP, grátis)

1. Baixar e rodar o agente em https://playit.gg
2. Criar túnel do tipo **UDP** apontando para `127.0.0.1:4383`
3. **Proxy Protocol:** ❌ **desativado** (o ENet do Godot não entende o cabeçalho PROXY — quebraria a conexão)
4. O playit gera um endereço público, ex.: `wharf-pos.gl.at.ply.gg:54417`
5. Host: abrir o jogo → **Host**. Amigo: **Address** = domínio, **Port** = porta do painel → **Connect**

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
