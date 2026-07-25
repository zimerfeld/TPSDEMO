---
tipo: fluxo
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 🧪 Protocolo de teste — Salas multiplayer (P1)

> Roteiro **autossuficiente e reutilizável** para validar o servidor multi-level (salas) em campo.
> Cobre 3 níveis de rede, do mais fácil ao mais real. Faça na ordem: se o **Teste A (loopback)**
> falha, não adianta ir para os PCs — é bug de código/lógica, não de rede.
> Contexto: [[🚪 salas (PT)|🚪 salas]] · [[🌐 multiplayer (PT)|🌐 multiplayer]] · [[🛰️ hospedagem-online (PT)|🛰️ hospedagem-online]].
>
> **Status da revisão de código (2026-07-01):** o fluxo de salas (`RoomManager` + `host_session` +
> `client_session` + `_ready` dos níveis + template lazy + filtros de visibilidade) foi **revisado e
> está consistente — sem bugs conhecidos**. Falta só a **validação de execução** abaixo.

---

## Fatos do build (do código, para o teste)

- **Porta padrão:** `4383` (SpinBox `Port` da `playonline`; editável/persistida por histórico).
- **Servidor:** botão **"Gerenciar Salas"** → `ENetMultiplayerPeer.create_server(porta)` → abre `host_session`.
- **Cliente:** botão **"Entrar em Salas"** → `create_client(endereço, porta)` → abre `client_session`.
- **Sala padrão (só servidor headless):** `level_1` (`DEFAULT_ROOM_LEVEL`). Na GUI o host escolhe o nível.
- **Protocolo:** ENet sobre **UDP** → túneis/redes precisam repassar **UDP** (ver Teste C).

---

## Teste A — Loopback local (2 instâncias no MESMO PC) · `127.0.0.1`

> ✅ **VALIDADO EM CAMPO (2026-07-02).** `playonline` local, host cria sala, cliente entra e nasce na sala
> (cenário aparece, não cinza), host mostra "(1 conexão)", replicação cliente↔host. **O netcode está
> provado.** Restam só os Testes B/C (transporte de rede real entre 2 PCs). Ajustes de UI feitos na mesma
> sessão: janela de erro não-destrutiva ([[🚪 salas (PT)|🚪 salas]] "Janela de erro NÃO-DESTRUTIVA") e guarda de
> corrida do "Jogar" no cliente (não nascer numa sala parada durante o `chooseplayer`).
>
> Valida TODA a lógica de sala sem depender de rede real. É o teste que EU (Claude) posso dirigir
> localmente; e o que você roda em 1 minuto. **Se A passa, o netcode está certo** — B/C só exercitam
> transporte de rede.

**Setup:** abrir **duas** janelas do jogo (o `.exe` em `build/windows/ZIMARO.exe` ou duas execuções
pelo editor). Janela 1 = HOST, Janela 2 = CLIENTE.

1. **[HOST]** Menu → **Jogar Online** → (chooseplayer → levels → playonline) → em PlayOnline, Porta `4383`
   → **"Gerenciar Salas"**. Cai na `host_session` (grade vazia).
2. **[HOST]** Escolher **Level 1** no dropdown → **"Iniciar Sala"**. Surge **"Sala #1 — level_1 (0 conexões)"**.
3. **[CLIENTE]** Menu → **Jogar Online** → em PlayOnline, IP `127.0.0.1`, Porta `4383` → **"Entrar em Salas"**.
   Cai na `client_session` e **lista "Sala #1 — level_1"** com botão **Jogar**.
4. **[CLIENTE]** **Jogar** → escolhe personagem → nasce **dentro da sala** (renderiza na janela principal).
   - ✅ **Conferir:** cenário aparece (NÃO tela cinza/preta), player com câmera, mira funciona.
   - ✅ **[HOST]** a linha da sala vira **"(1 conexão)"**.
5. **[HOST]** Na sala #1, botão **Observar** → vê o cenário no SubViewport; **o player do cliente aparece
   se mexendo** (replicação servidor→host da posição do cliente). WASD do host voa a câmera livre. **ESC** sai.
6. **[HOST]** Na sala #1, botão **Jogar** → escolhe personagem → nasce na MESMA sala.
   - ✅ **[CLIENTE]** o player do HOST aparece na cena do cliente (replicação servidor→cliente); ambos se
     veem e se movem. Atirar de um deve causar dano no outro (combate replicado).
7. **[HOST]** **ESC** enquanto joga → diálogo "Desconectar e voltar para a gerência?" → **Sim** → volta à
   grade com o mouse visível; o player do host some da cena do cliente.
8. **[HOST]** botão **Reiniciar** na sala → ✅ **[CLIENTE]** recebe **"O nível foi reiniciado pelo host"**,
   volta ao navegador, e a **sala recriada (novo #id)** reaparece na lista para reentrar.
9. **[HOST]** botão **Parar** na sala (com o cliente dentro) → ✅ **[CLIENTE]** recebe **"O nível foi parado
   pelo host"** e volta ao navegador; a sala some da grade do host.
10. **[HOST]** **Iniciar** duas salas (Level 1 e Level 2) ao mesmo tempo → cliente entra numa; ✅ **isolamento:**
    o que acontece numa sala **não** aparece na outra (inimigos/players filtrados por sala).
11. **[CLIENTE]** **ESC** no navegador (fora de sala) → volta ao PlayOnline (fecha o peer).
    **[HOST]** **Voltar** → derruba o servidor, volta ao PlayOnline.

**Se qualquer passo falhar:** anotar o passo + o console (rodar pelo editor para ver `push_error`/RPC).
Suspeitos por sintoma: *tela cinza no cliente* → template/scene-cache (ver [[🚪 salas (PT)|🚪 salas]] "salas nascem
limpas"); *player sem câmera* → filtro de visibilidade (`public_visibility`, ver [[🚪 salas (PT)|🚪 salas]]); *nada replica* →
caminho determinístico `/root/RoomManager/Room<id>/Level`.

---

## Teste B — LAN (2 PCs na MESMA rede/Wi-Fi)

Igual ao Teste A, mas as duas máquinas são físicas.

1. No PC-HOST, descobrir o **IP local**: `ipconfig` → "Endereço IPv4" (ex.: `192.168.0.42`).
2. PC-HOST: hospeda (passos 1-2 do Teste A).
3. PC-CLIENTE: em PlayOnline, IP = **o IP local do host**, Porta `4383` → **Entrar em Salas** → segue do passo 3.
4. Se não conectar: **Firewall do Windows** no PC-HOST pode estar bloqueando UDP `4383` — liberar a porta
   (ou permitir o `ZIMARO.exe` na primeira vez que o Windows perguntar). Confirmar que ambos estão na mesma sub-rede.

---

## Teste C — Internet (2 PCs em redes diferentes) · playit.gg (UDP)

O jogo é **UDP** → precisa de túnel UDP ou port-forwarding. **ngrok NÃO serve (TCP).** Recomendado: **playit.gg**.

1. PC-HOST: instalar o agente **playit.gg**, criar um túnel **UDP** apontando para a porta local `4383`.
   O playit dá um endereço público no formato `<sub>.playit.gg` + **uma porta** (ex.: `147.185.221.x:xxxxx`).
2. PC-HOST: hospedar normalmente na porta `4383` (**Gerenciar Salas**).
3. PC-CLIENTE: em PlayOnline, IP = **endereço do playit**, Porta = **a porta do playit** → **Entrar em Salas**.
   > ⚠️ A porta do cliente é a **porta pública do túnel**, que pode ser **diferente** de `4383`.
4. Seguir a matriz de verificação do Teste A (passos 4-10).
5. Alternativas: **Tailscale/ZeroTier** (VPN mesh — o cliente usa o IP `100.x` do host, porta `4383`) ou
   **port forwarding** no roteador (encaminhar UDP `4383` → IP local do host). Ver [[🛰️ hospedagem-online (PT)|🛰️ hospedagem-online]].

---

## Matriz de capacidades (o que cada passo prova)

| Capacidade | Passo(s) | Prova |
|---|---|---|
| Servidor sobe + cria sala | A2 | `create_server` + `start_room` |
| Cliente conecta + lista salas | A3 | `create_client` + `request_room_list`/`receive_room_list` |
| Cliente entra e nasce na sala | A4 | `client_join_room`/`join_room` + spawn + espelho local |
| Replicação cliente→host | A5 | visibilidade por-sala + `MultiplayerSynchronizer` |
| **Host joga na sala** | A6 | `host_spawn_in_room` (peer 1) + câmera do player no SubViewport |
| Replicação host→cliente + combate | A6 | spawn do peer 1 replicado + `hit()` RPC |
| ESC do host (sair de jogar) | A7 | `host_leave_room` |
| Reiniciar sala | A8 | `restart_room` + `notify_room_restarted` |
| Parar sala | A9 | `stop_room` + `notify_room_closed` |
| Isolamento entre salas | A10 | visibility filter por `room_id` |
| Rede real (LAN/Internet) | B/C | transporte UDP fora do loopback |
