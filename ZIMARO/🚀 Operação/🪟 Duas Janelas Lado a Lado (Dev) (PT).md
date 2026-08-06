---
tipo: procedimento
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-08-06
---

# 🪟 Duas Janelas Lado a Lado (Dev)

> **Objetivo:** testar o multiplayer em loopback com **um comando só** — duas instâncias do ZIMARO
> abertas lado a lado (metade da tela cada), uma hospedando uma sala e a outra entrando nela
> sozinha, sem clicar em nada. Substitui o roteiro manual do
> [[💻 Rodar no Editor (Dev) (PT)|💻 Rodar no Editor (Dev)]] (passo 3).

## ⚡ TL;DR

```powershell
pwsh -File scripts/dual-window.ps1
```

Janela da **esquerda** = servidor (hospeda uma sala no Level 1). Janela da **direita** = cliente
(espera o servidor subir, entra na sala e já nasce jogando). `ESC` na janela do cliente sai da sala
e devolve o mouse.

## ⚙️ Como funciona

Duas peças:

1. **`scripts/dual-window.ps1`** — detecta a **área útil** do monitor (largura/altura descontando a
   barra de tarefas), divide ao meio e lança as duas instâncias com os argumentos de cada papel.
   Antes de lançar, encerra instâncias anteriores do mesmo executável (senão a porta fica ocupada).
   Usa o `.exe` de `build/windows/ZIMARO.exe` quando existe; senão (ou com `-Editor`) roda pelo
   binário do Godot com `--path`.
2. **`autoload/autopilot.gd`** (autoload `Autopilot`) — lê os **argumentos de usuário** da linha de
   comando (tudo depois de `--`) e conduz o fluxo dentro do jogo. Sem esses argumentos o autoload
   fica inerte e o jogo roda exatamente como antes.

### Argumentos aceitos (depois de `--`)

| Argumento | Efeito |
| --- | --- |
| `autohost` | hospeda o servidor de salas e cria a sala inicial |
| `autojoin` | conecta como cliente e entra na primeira sala em execução |
| `port=<n>` | porta do servidor (padrão `4383`) |
| `address=<host>` | IP/domínio do servidor, só no `autojoin` (padrão `127.0.0.1`) |
| `level=<1\|2\|res://…>` | level da sala criada pelo `autohost` (padrão `1`) |
| `template=<id\|nome>` | template de personagens ativado na sala; casa pelo **id exato** ou por um trecho do **nome** (sem acento/maiúsculas — `aerea` acha "Caça aérea"). `none` limpa; vazio mantém o ativo |
| `delay=<seg>` | **cliente:** espera antes da 1ª tentativa de conexão (padrão `6`). **host:** pausa entre preencher os campos e hospedar (padrão `5`), **só em build de depuração** — ver abaixo |
| `retries=<n>` | tentativas extras, de 2 em 2 s (padrão `15`) |
| `player=<nome>` | nome do jogador desta instância (**não** persiste em Settings) |
| `music=<on\|off>` | trilha desta instância. Sem o argumento, o **host nasce mudo** e o cliente toca — duas trilhas ao mesmo tempo nas duas janelas atrapalham o acompanhamento. Mexe só no bus vivo, **nunca** no Settings (as duas janelas gravam no mesmo arquivo de configuração) |
| `win=<x,y,w,h>` | posiciona/dimensiona a janela em pixels de tela |

Exemplo do que o script executa:

```
ZIMARO.exe -- autohost port=4383 level=1 win=0,0,960,1032 player=HOST
ZIMARO.exe -- autojoin port=4383 address=127.0.0.1 delay=6 win=960,0,960,1032 player=CLIENTE
```

### Parâmetros do script

`-Port` · `-Address` · `-Level` · `-Template` · `-Delay` · `-Retries` · `-Monitor <índice>` (base 0) ·
`-Exe <caminho>` · `-Editor` (força rodar pelo binário do Godot) · `-NoKill` (não encerra
instâncias anteriores) · `-Preview <seg>` (pausa de conferência antes de lançar, padrão `6`;
`0` sobe direto).

### Testar o aliado bot (escolta)

```powershell
pwsh -File scripts/dual-window.ps1 -Level 2 -Template aerea
```

O Level 2 tem o template padrão **"Level 2 - Caça aérea"** (2 criaturas hostis + **1 aliado bot**).
Com o `-Template`, o autopilot ativa o template **antes** do `start_room` (é ele quem aplica os
personagens) — dá para observar a [[🎮 player (PT)|postura de segurança]] do aliado direto da grade
do host (**Observar**) ou entrando na sala. Só o **host** recebe `template=`: é ele quem cria a sala.

### Pausa do host (só em depuração)

Antes de hospedar, a tela **Jogar Online** do host fica **5 s** com os parâmetros já preenchidos —
tempo de conferir nome, porta e as opções de otimização antes de ela trocar pela sessão de salas
(`Autopilot.host_preview_delay` → `HOST_PREVIEW_DELAY_SEC`). Passar `delay=` sobrepõe o valor.

Ela **não existe em release**: `OS.is_debug_build()` é falso no `.exe` exportado e a pausa vira `0`,
então o servidor de produção sobe na hora. É apoio a acompanhamento visual, não comportamento do jogo.

O campo **IP/Domínio** do host vai **vazio** de propósito: o `create_server` usa só a porta, e deixar
o último IP ali sugeriria que ele é usado para hospedar (não é — só o cliente o consome).

### Pausa de conferência

Antes de lançar, o script imprime um bloco com **todos os parâmetros em uso** — monitor e área
útil, executável, porta/endereço, level, espera do cliente, a geometria de cada janela e as **duas
linhas de comando completas** — e faz uma contagem regressiva de `-Preview` segundos (`Ctrl+C`
cancela). É o tempo de conferir tudo antes de as janelas tomarem a tela.

## 🔌 Pontos de gancho no jogo

| Arquivo | O que faz sob piloto automático |
| --- | --- |
| `scenes2D/main/main.gd` | aplica a geometria `win=` logo no boot |
| `scenes2D/menu/menu.gd` | reaplica a geometria e pula direto para o **playonline** |
| `scenes2D/playonline/playonline.gd` | preenche porta/endereço/nome e hospeda **ou** conecta (com o `delay=`); falha de conexão **re-tenta em silêncio** enquanto houver tentativas |
| `scenes2D/host_session/host_session.gd` | cria a sala inicial (uma vez, e só se não houver salas) |
| `scenes2D/client_session/client_session.gd` | entra na **primeira** sala assim que ela aparece na lista (uma vez) |
| `scenes2D/chooseplayer/chooseplayer.gd` | confirma o personagem padrão e segue |
| `scenes3D/level_1/level_1.gd` · `level_2.gd` | reafirmam a geometria depois do `apply_graphics_settings` (que reimpõe o `display_mode` salvo) — sem isso a janela do **level** voltava a tela cheia e saía do lado a lado |

## 🛟 Troubleshooting

- **As duas janelas nascem em tela cheia sobrepostas:** o Settings nasce em **tela cheia
  exclusiva** e a saída desse modo **não assenta no mesmo frame** — por isso o `Autopilot` reafirma
  a geometria por ~30 frames (`REASSERT_FRAMES`) depois de cada chamada. Se voltar a acontecer,
  aumentar esse valor.
- **Janelas menores que a metade da tela (telas com escala 125%/150%):** o script chama
  `SetProcessDPIAware()` antes de ler a área útil. Sem isso o Windows devolve coordenadas virtuais.
- **Cliente não entra:** subir o `-Delay` (o servidor paga o preload de startup + a criação da
  sala antes de aceitar conexões). O cliente já re-tenta 15× de 2 em 2 s por padrão.
- **"Porta em uso" no servidor:** sobrou instância de uma execução anterior — rodar sem `-NoKill`
  (padrão) ou encerrar o `ZIMARO.exe` à mão.
- **Handshake de versão recusado:** as duas janelas rodam do mesmo build, então isso só aparece
  apontando `-Address` para outro PC — ver [[🛰️ hospedagem-online (PT)|🛰️ hospedagem-online]].

## 📏 Regras que respeita

- **Nunca commitar/publicar** — deixar para o usuário revisar (GitFlow).
- Ferramenta de **desenvolvimento**: sem os argumentos de linha de comando o jogo é idêntico ao
  de produção (nenhum caminho novo é executado).

## 🔗 Ligações
- [[💻 Rodar no Editor (Dev) (PT)|💻 Rodar no Editor (Dev)]] — o roteiro manual equivalente
- [[🧪 teste-salas-multiplayer (PT)|🧪 teste-salas-multiplayer]] · [[🚪 salas (PT)|🚪 salas]] · [[🌐 multiplayer (PT)|🌐 multiplayer]]
- [[🛰️ hospedagem-online (PT)|🛰️ hospedagem-online]] · [[🚀 Build Windows (Prod) (PT)|🚀 Build Windows (Prod)]]
- [[🏠 Home (PT)|🏠 Home]] · [[📌 Backlog (PT)|📌 Backlog]]
