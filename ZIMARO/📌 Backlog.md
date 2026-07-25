---
tipo: backlog
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-23
---

# 🗂️ Backlog priorizado — ZIMARO

> **Ponto de retomada entre sessões.** Esta nota é autossuficiente: leia-a no início de uma
> nova conversa para saber **o que está em andamento, o que falta e por qual ordem atacar**.
> Ligada ao [[🏠 Home]]. Cada item aponta para a nota de sistema onde o contexto detalhado vive.
>
> **Convenção de status:** 🟡 em andamento · 🔴 não iniciado · 🟢 pronto (aguardando validação) · ⚪ opcional
>
> **Regras que valem para retomar (ver `CLAUDE.md` / `REGRAS.md`):** nunca commitar/publicar — deixar
> para o usuário revisar; encerrar o jogo e o editor Godot antes de mexer no código; ao fim de tarefa
> com impacto no usuário, atualizar READMEs (`.md`/`.en-US`/`.pt-BR`) **e** este cofre; rodar
> `build_windows.ps1` ao final; eliminar erros/warnings após compilar.

**Última revisão:** 2026-07-23 · **Branch ativa:** `feature/jogador7-import`

---

## 🟢 Sub-membros distais + classificador bilíngue + desempenho do refit — PRONTO p/ review (2026-07-23)

Branch `feature/jogador7-import`. **Não commitado** (aguardando review).

- **Extremidades viram sub-membros automáticos** — antebraço/mão (dono BRAÇO) e canela/pé (dono
  PERNA) ganham collider e dano PRÓPRIOS; sem valor definido **herdam o do membro-dono**. Novo virtual
  `BodyParts.is_distal_sub_member` + `@export auto_distal_sub_members` em `LimbColliders`. **Opt-out**
  de `player`/`red_robot` (mantêm o hitbox de membro inteiro), espelhado no preview por
  `_MODEL_NO_AUTO_DISTAL`. Medido: humanoide/monstro = 6 membros + 8 sub-membros; player = 6 + 0.
  Ver [[🩸 dano-localizado]] · [[🦴 body-parts-gd]] · [[🦿 limb-colliders-gd]].
- **Classificador bilíngue PT+EN** — passa a reconhecer `cabeca/peito/bracoDireito/antebracoDireito/…`
  além do inglês (o `monstro`, em PT, classificava **0 de 16 ossos**). O PT "pe" (pé) casa por **token
  exato** (`BodyParts.words_of`), senão colidiria com `peito`/`perna`/`pescoco`.
- **Desempenho do refit** (era o que derrubava o FPS na tela Models) — 6,45 → **0,318 ms/frame** (~20×):
  cache em memória do `LimbConfig` (os getters reabriam o JSON do disco, ~140 leituras/s), grupos de
  **osso único** pulados (AABB invariante — os termos se cancelam) e **rodízio** de 3 grupos por frame
  no lugar do throttle adaptativo. ✅ FPS validado em tela pelo usuário.
- **Tela Models** — o dropdown Sub-membro agora lista **todos** os sub-membros no modo "Todos os
  membros" (rotulados com o membro-dono); **pan da câmera com o botão DIREITO** (o esquerdo segue
  girando o modelo, a roda segue no zoom).
- **Importação de modelos** — `humanoide` e `monstro_pedregulho3` corrigidos e reimportados (36
  animações cada). Nomes com sufixo `" (2)"` e caminhos de raiz nos `.import`/`.tscn` quebravam a
  importação. Nota nova [[🔌 MCP do Godot]] documenta o addon e os comandos headless.

**Pendências desta frente:** validar o `red_robot` em partida (opt-out analisado, sem teste dedicado);
o plano **quadrúpede** ainda não subdivide extremidades (só o bípede); o `README.md` raiz segue
**bilíngue** (EN+PT, sem bloco ES) — divergente da regra de trilíngue.

---

## 🟢 Locomoção realista + suavização + Sistema de Facções — PRONTO p/ review (2026-07-08)

Branch `feature/locomocao-realista-inimigos` (a partir de `develop`). `.exe` rebuildado; import
headless sem erros/warnings. **Não commitado** (aguardando review).

- **Locomoção terrestre sem deslizar:** passada da `Walk` medida em runtime (~0,8 m/s), cadência via
  novo nó `AnimationNodeTimeScale`, pernas encaram a direção do movimento (deslocamento por root
  motion), velocidades da IA reduzidas. Ver [[🤖 inimigos]].
- **Anti-chacoalho:** rumo suavizado (`move_dir_response`), `body_turn_rate` 7→5, strafe segura 1,6–3 s.
- **Sistema de facções (runtime, por-instância):** novo `effects_shared/factions.gd`. Sem fogo amigo
  (bala atravessa aliado), targeting por facção, neutros dinâmicos (~8 s). Ver [[⚔️ facções]].
- **Aliado orbita o player mais próximo sem colidir** (`player_bot_ai`): âncora no humano mais perto,
  órbita (raio + tangencial), exceção de colisão bot↔âncora. Ver [[🎮 player]].
- ✅ **Separação entre múltiplos bots aliados (2026-07-08):** `player_bot_ai._separation` (steering
  estilo boids) afasta cada aliado dos outros dentro de `separation_radius` → distribuem-se na órbita
  sem empilhar. Ver [[🎮 player]] / [[⚔️ facções]].

---

## 🟢 Colisão dos controles em PT + atualização do `.exe` da release — PUBLICADO (2026-07-07)

Três frentes numa mesma sessão, todas concluídas:

1. **Fix de colisão dos controles ("Referência rápida") em PT.** A landing page
   (`index.html`, **zimaro.zimerfeld.com** via GitHub Pages) forçava o container dos pills
   para `display:block` no PT (`html[data-lang="pt"] .block.lang-pt{display:block}`),
   tornando os `.pill` **inline** — e o padding vertical de inline sobrepunha os fundos
   entre linhas. **Correção de 1 linha de CSS:**
   `html[data-lang="pt"] .pills.lang-pt.block{display:flex}` restaura o flex/wrap só no PT.
   Publicado como hotfix direto na `main` (commit `4d79896`); Pages redeployado ao vivo.
   (O mesmo template do ZIMMY tinha o bug — corrigido lá também.)
2. **`.exe` da release atualizado.** Asset `ZIMARO.exe` da release **`202606251203`**
   substituído (`gh release upload … --clobber`): **587 MB → 166 MB** (build novo), e a
   release **publicada** (`--draft=false`) — antes era rascunho, invisível ao público.
3. **Higiene do git.** Removido do histórico o commit `com exe` (exe de 174 MB, que o
   GitHub rejeita por >100 MB); `build/windows/*.exe` agora no `.gitignore`; recommit limpo
   só com ícones + `.gitignore` (`8fec39b`, enviado ao `develop`).
4. **Nova release com tag de hoje + título limpo.** Criada a release **`202607072141`**
   (`gh release create … --title "202607072141"`), agora **Latest**: título = só a tag
   (sem "ZIMARO v0.1.0"), notas EN/PT reaproveitadas sem o cabeçalho de versão, `ZIMARO.exe`
   (166 MB) anexado. A antiga `202606251203` foi **mantida** por opção.

**Procedimento documentado no cofre:** [[📦 Atualizar Asset da Release (GitHub)]] (PT/EN)
na pasta 🚀 Operação — como trocar/publicar o binário com `gh` sem passar pelo git, e como
criar uma **nova release com nova tag** (título = só a tag).

---

## 🟢 Landing page — quebra de linha de títulos/subtítulos em PT — PUBLICADO (2026-07-07)

A landing page (`index.html`, publicada em **zimaro.zimerfeld.com** via GitHub Pages) compartilha um
template i18n com a regra `html[data-lang="pt"] .lang-pt{display:inline}`, que tornava **todo** elemento
em português `inline` — incluindo `h2`/`h3` — fazendo título/subtítulo colarem no texto seguinte quando o
site abre em PT (em EN funcionava, pois `h2`/`h3` já são `block` por padrão). **Correção de 1 linha de
CSS:** `html[data-lang="pt"] h2.lang-pt,html[data-lang="pt"] h3.lang-pt{display:block}` — restaura a
quebra apenas nos títulos/subtítulos em PT, sem afetar o EN. Publicado via GitFlow (release `develop`→`main`;
o fix já estava no `develop` de uma sessão anterior — só faltava promover a produção) + tag
**`202607071915pt-heading-break`**; `CNAME` preservado; deploy do GitHub Pages confirmado ao vivo.

> [!note] Diferente dos itens de código do jogo abaixo
> Este é um ajuste isolado de **conteúdo da página** e **já foi publicado** (com autorização do usuário) —
> ao contrário dos itens P0.x de código, que seguem a regra "não commitar" e aguardam review.

---

## 🟢 P0.5 — Gerenciador de Templates funcional no .exe — PRONTO p/ review (2026-07-03)

Playtest de ponta a ponta no **.exe exportado** (menu → chooseplayer → levels → Gerenciador de
Templates → template "Arena Fable" (Red Robot ×3 enemy) → partida solo no Level 1 com spawn,
combate, morte e respawn a ~60 FPS). **3 bugs achados e corrigidos** (detalhes em
[[🧩 templates-de-level]]):

1. Dropdown **Modelo vazio no build** — scan `DirAccess` não resolvia `*.tscn.remap` do export
   (`level_template_manager.gd`, helper `_logical_name` igual ao da tela Models).
2. **"Salvar e Usar Neste Level" não ativava template novo** (id gerado não voltava ao diálogo;
   Save repetido duplicava) — `level_template_dialog.gd` agora guarda o id do `upsert_template`.
3. **Nome do template se perdia** ao Adicionar/Remover Entrada — `text_changed` grava direto.

READMEs (3) + cofre atualizados; `build_windows.ps1` rodado (531 MB, sem erros). **Aguarda o
usuário commitar/publicar.** Polimentos sugeridos (não feitos): filtrar cenas de suporte
(bullet/impact_effect) do dropdown Modelo; sufixo automático p/ nomes de template repetidos.

---

## 🟢 P0.6 — Ambiente visual dos levels (céu + fog + grade neon) — PRONTO p/ review (2026-07-03)

Item 1 do plano de performance/atratividade, **aprovado pelo usuário e implementado**: céu
procedural com identidade por level (**Level 1 ciano / Level 2 âmbar**), fog de distância
exponencial e **piso-grade neon emissivo** (shader compartilhado `themes/level_grid_floor.gdshader`,
só matemática — sem texturas/passes). Meta de performance do projeto registrada no `CLAUDE.md`
(mín. 60 FPS em hardware gráfico mínimo) e **validada no `.exe`: 60 FPS nos 2 levels, inclusive em
combate**. Detalhes: [[🌌 ambiente-dos-levels]]. READMEs (3) atualizados. O exe caiu de
531→174 MB porque o usuário moveu arquivos não usados de propósito (confirmado). **Aguarda commit.**

---

## 🟢 P0 — Fechar a reestruturação em curso (`feature/restrutu`) — PRONTO p/ review (2026-07-01)

**Status:** trabalho concluído e validado; **aguarda o usuário commitar/publicar** (regra: não commitar).
Feito nesta sessão: caçadas as referências órfãs a `level_base` (nenhuma no código); removidas as
**chaves de localização órfãs** `"Level Base"` em `scenes2D/levels/Resources/levels.{en,pt}.json`;
confirmada a remoção completa do **filtro de Prefixo** em `models.gd` (sem sobras); validação headless
no Godot 4.6.2 → **editor importa limpo** (autoloads compilam sem erro) e o **jogo roda 300 frames sem
erro de script/runtime** (só os avisos benignos `ObjectDB leaked` / `resources still in use` do
`--quit-after`, normais no encerramento forçado); READMEs (`.md`/`.en-US`/`.pt-BR`) já refletem
`structures` + membro **CORPO** de fallback e a saída do `level_base.ogg`; cofre sincronizado
([[🏠 Home]], [[🎬 fluxo-de-cenas]] ordem de Tab da `levels`, [[🚪 salas]] nota histórica,
[[📄 formatacao]]). **Falta só:** rodar `build_windows.ps1` (feito ao fim da sessão) e a
**publicação pelo usuário**.

<details><summary>Contexto original da reestruturação (referência)</summary>

Branch de reestruturação com muitas mudanças ainda não commitadas. Levada a estado consistente,
testável e revisável.

- **Cofre movido e renomeado** `OBSIDIAN/CLAUDE/` → `OBSIDIAN/` → `ZIMARO/` (renomeado para o nome do projeto; raiz do vault agora é `C:\GODOT\ZIMARO\ZIMARO`,
  índice em `000-INDEX.md`). Os arquivos aparecem como `D` (caminho antigo) + `??` (caminho novo) no git.
- **Sistema de templates de level** em construção: `scenes2D/level_templates/level_template_dialog.gd`,
  `library3D/structures/` (novo, não rastreado), mais `scenes3D/models/`, `levels`, `net_spawn`,
  `player_selection`, `host_session`, `stability_guard`, `music_manager`. Relaciona com as memórias
  *"salas nascem limpas"* (nada pré-spawnado; inimigos só via template) e *"fallback CORPO member"*.
- **Áudio:** `audios/level_base.ogg` removido (+ `.import`); conferir se `MusicManager`/atribuições por
  cena não referenciam mais esse arquivo. Ver [[🔊 audio]].

**Fechamento:** rodar o jogo e confirmar que abre sem erro (menu → level → models → salas); zerar
erros/warnings; atualizar os 3 READMEs + notas do cofre afetadas; `build_windows.ps1`; **deixar para o
usuário commitar/publicar** (não commitar). Sistemas: [[🚪 salas]], [[🗿 biblioteca-de-modelos]].

</details>

---

## 🟢 P0.7 — Cascata de pastas + Gerenciador de Cenários + reparo da reorganização (2026-07-03)

Sessão grande, tudo validado em jogo no `.exe` (166 MB, 60 FPS) — **aguarda commit do usuário**:

- **Reparo da reorganização de pastas do usuário** (characters → enemies/players/NPCs; remoção de
  `structures/` e da pasta-suporte `characters/player/`): restaurados do git APENAS os assets
  usados (player.glb + materiais/texturas, audio/, bullet/, muzzle mesh, limb_config) para DENTRO
  de `characters/players/player/`; reescritos os caminhos antigos em **72 arquivos** (preloads de
  script não usam UID e quebravam); `_spawnable_scenes` dos levels limpos (structures fora,
  sceneries dentro); `user://level_templates.json` migrado.
- **Navegação em cascata** no Gerenciador de Templates (characters) e o novo **Gerenciador de
  Cenários** (sceneries) — ver [[🧩 templates-de-level]]. Tela `levels` com 2 botões por
  level (Tab renumerado 1-9); cenário "Palco Neon" (4 box + 3 sphere + 2 pill) validado no solo
  E numa sala online.
- **Velocidade dos inimigos terrestres calibrada em padrões reais** (pesquisa: caminhada ~1,4 m/s,
  trote ~3, corrida 4,5): red_robot strafe 4,25→**2,4**, pressão 5,2→**3,2**, fuga 6,0→**3,8** +
  **aceleração suave** (`manual_accel` 6/s) no movimento manual — sem deslizar, com peso.
- **ManageTemplates (host_session) corrigido** (botão renomeado de `ManageTemplatesButton` na
  varredura de 2026-07-03): alerta quando nenhum level está selecionado
  (antes retorno silencioso = "botão quebrado"); validado hospedando sala em **127.0.0.1:4383**.
- **Tela `levels` em grade responsiva**: `GridContainer` 3 colunas (Level fixo 300 px | Template |
  Cenário), colunas dos gerenciadores com `SIZE_EXPAND_FILL` **dividindo o resto da tela meio a
  meio**, espaçamento uniforme 16 px nas duas linhas. Ver [[📐 layout-responsivo]].
- **`build_windows.ps1` blindado**: apaga `.godot/exported/` antes de todo export — o cache não
  invalida quando um `.tscn` muda e o exe saía com **cena velha** (custou um ciclo de diagnóstico
  com sondas headless e marcadores no binário). Ver [[🚀 Build Windows (Prod)]].

---

## 🟢 P0.10 — Reparo da reorganização de pastas (refs → caminhos planos) — PRONTO p/ review (2026-07-03)

O projeto estava numa **reorganização de pastas pela metade**: os arquivos dos personagens voltaram
aos caminhos **planos** (`characters/player/`, `red_robot/`, `criatura_alada/`, `playera/`), mas muitas
referências ainda apontavam para os caminhos reorganizados (`characters/players/…`, `characters/enemies/…`).
As com `uid://` resolviam, mas as por **string pura quebravam**: os `_spawnable_scenes` de `level_1`/`level_2`
(personagens não spawnavam) e o `load(player.glb)` do `chooseplayer` (tela de escolha falhava). Detectado
pelos erros de recurso no build (já presentes desde o 1º build da sessão — **pré-existente**, não do
auto-fit). **Corrigido** com 4 reescritas de caminho em **24 arquivos** (~101 ocorrências):
`players/player/→player/`, `players/playera/→playera/`, `enemies/red_robot/→red_robot/`,
`enemies/criatura_alada/→criatura_alada/`. **Preservado de propósito** `enemies/enemy_health_bar.gd`
(único arquivo que genuinamente ficou em `enemies/`, referenciado por red_robot/criatura). Validado
headless (sem erros de recurso) + rebuild. **Aguarda commit.**

---

## 🟢 P0.9 — Auto-fit da cápsula de locomoção por modelo — PRONTO p/ review (2026-07-03)

O **bloqueio físico** entre personagens deixou de usar uma cápsula default (0,5×2,0) igual p/ todos e
passou a ser **proporcional ao modelo**, derivado dos mesmos boxes de membro que o `LimbColliders` já
mede — mantendo **1 shape por personagem** (barato, estável, determinístico p/ o netcode). Novo método
`LimbColliders.fit_locomotion_capsule` (raio = footprint tronco+pernas; altura = extensão vertical;
base ancorada no chão; no-op se não há membros → preserva a cápsula autorada). Ligado em `player.gd` e
`red_robot.gd` após `build_for`. A criatura_alada (voadora, sem `LimbColliders` no gameplay) segue com
a cápsula autorada. **Validado** por sonda headless determinística (raio 0,250 ≠ braços 0,575; altura
1,800; base 0,000 — 3/3 OK). Detalhes: [[🩸 dano-localizado]] · [[🎮 player]]. Respondeu à
pergunta do usuário sobre usar os LimbColliders p/ bloqueio físico (dano localizado já funcionava
assim). **Aguarda commit.**

---

## 🟢 P0.8 — Pulo variável + varredura de nomes de controles — PRONTO p/ review (2026-07-03)

- **Pulo variável (hold/release):** segurar **espaço** = animação do salto completa + distância máxima
  (arco balístico integral, comportamento anterior preservado); **soltar no meio da subida** = corte
  SUAVE do pulo (amortecimento exponencial `JUMP_CUT_DAMPING = 14.0/s` na velocidade vertical — sem
  tranco) e a animação transiciona para `jump_down` no ápice antecipado. Implementação: novo estado
  sincronizado `jump_held` no `PlayerInputSynchronizer` (semeado `true` no RPC `jump()` p/ não cortar
  o 1º frame por atraso de replicação; replicado no `SceneReplicationConfig` do InputSynchronizer),
  corte restrito a pulos reais via flag `_jump_active` (cair de borda NÃO é amortecido). Bots não
  pulam (IA), logo não são afetados. Ver [[🎮 player]].
- **Varredura de nomes dos controles 2D:** concluída (detalhes no item P2 riscado abaixo). Duas novas
  regras de projeto no `CLAUDE.md` (sem repetir Type/siglas no Name; revisar dependências ao alterar
  controle) e regra global de limpeza de código morto reforçada (após toda inclusão/deleção/modificação).
- Validação: jogo headless 300 frames **sem erro**; consistência `%UniqueName`×`.tscn` verificada
  em host_session/client_session/playonline. **Aguarda commit do usuário.**

---

## 🟡 P1 — Validar salas multiplayer em rede real

As Fases 1–3 do servidor multi-level estão **implementadas**. Progresso em 2026-07-01:

- ✅ **Revisão de código do fluxo de salas** (`RoomManager` + `host_session` + `client_session` + `_ready`
  dos níveis + template lazy + filtros de visibilidade): **consistente, sem bugs encontrados**. Verificados
  os fluxos host-joga (`host_spawn_in_room`/`host_leave_room`), cliente-entra (`client_join_room`/`join_room`),
  parar/reiniciar (`notify_room_closed`/`notify_room_restarted`), isolamento por `room_id` e o caminho
  determinístico de replicação `/root/RoomManager/Room<id>/Level`.
- ✅ **Protocolo de teste autossuficiente** criado: [[🧪 teste-salas-multiplayer]] (loopback local
  `127.0.0.1` → LAN → internet via **playit.gg UDP**; porta padrão `4383`).
- ✅ **Teste A (loopback `127.0.0.1`, 2 instâncias) VALIDADO em campo (2026-07-02):** host cria sala,
  cliente entra e nasce (cenário, não cinza), "(1 conexão)", replicação cliente↔host. **Netcode provado.**
  Ajustes de UI na mesma sessão: janela de erro **não-destrutiva** (× / ESC / "Voltar" só fecham; conserta
  de brinde o quit acidental na validação da tela Models) + **guarda de corrida** do "Jogar" no cliente
  (não nascer numa sala parada durante o `chooseplayer`). Ver [[🧪 teste-salas-multiplayer]] · [[🚪 salas]].
- ⬜ **Falta a execução em campo de rede REAL** (precisa de hardware/rede):
  - **Teste B/C (rede real):** 2 PCs (LAN e depois internet via playit.gg) — **depende do usuário**.

Contexto completo: [[🚪 salas]] · [[🌐 multiplayer]] · [[🛰️ hospedagem-online]].

---

## 🟡 P1.5 — IA dos inimigos: comportamento + tela de parametrização

Feedback do usuário (2026-07-02) sobre a IA automática atual. Dividido em **comportamento** (código, em
andamento) e **parametrização** (UI, adiada por decisão do usuário). Contexto: [[🤖 inimigos]],
[[🧠 red-robot-ai-gd]], `red_robot_ai.gd` / `criatura_alada_ai.gd` / `red_robot.gd`.

**Comportamento (código) — ✅ FEITO (2026-07-02, ver [[🤖 inimigos]] "Refinamento de IA"):**
- ✅ **Terrestre não "deslizar":** `_match_locomotion_cadence` escala o `speed_scale` do AnimationPlayer de
  locomoção p/ a cadência casar com a velocidade real (sem patinar); fora do manual volta a 1.0. Só código
  (sem tocar no `.tscn`/blend tree). Tunáveis `walk_natural_speed`/`gait_speed_scale`.
- ✅ **Formação menos rígida:** `formation_cohesion` 0.55→0.32, `formation_band` 5→7 m, rumo do slot oscila
  suave (`formation_wander`) → orgânico.
- ✅ **Alvo = player mais próximo (multiplayer):** `_players_in_range` + `_pick_target()` com histerese
  (`TARGET_SWITCH_MARGIN`); qualquer inimigo atira em qualquer player no raio (red_robot + criatura).
- ✅ **Aéreo altura suave/contextual:** troca de camada interpolada (`_alt_bias`): ameaçada→sobe (escape),
  bombardeio iminente→desce (precisão), senão cruzeiro; taxa vertical limitada.
- ✅ **Marcação de facção (estrutural):** `AIConfig.faction`/`set_faction`/`is_hostile`/`is_neutral` (hostile/
  neutral/ally), defaults hostis p/ os inimigos. **Sem personagem neutro ainda** — campo pronto p/ plugar.
- 🔴 **Lógica de comportamento NEUTRO (pendente — depende de personagem neutro):** neutro só entra em confronto
  se AMEAÇADO (levar tiro) ou por aleatoriedade. A marcação já existe; falta o personagem e a lógica.

**Parametrização (UI — ADIADA, este é o "próximo item" que o usuário citou):**
- 🔴 Na **janela de IA** (Inteligência Artificial) de cada modelo, adicionar um **botão ao lado de cada toggle**;
  ao clicar, **fecha a janela de IA** e abre uma **janela de parametrização** dedicada.
- 🔴 A janela de parametrização expõe os **limites**: altura (min/max de voo), velocidade, **cadência de tiro**, etc.
- 🔴 **Mesmos padrões de estilo** das outras janelas (campos, botão **Voltar** e **× fechar** no canto superior):
  Voltar/× **fecham a janela e reabrem a respectiva janela de IA do modelo que a chamou**.
- Base de UI já existe: `FloatingWindow`/`FloatingDialog` (mesmo padrão modal/estilo). Os parâmetros hoje são
  `@export` nos scripts de IA + `AIConfig` (só toggles booleanos por enquanto) → estender `AIConfig` p/ valores
  numéricos por modelo. Ver [[🚪 salas]] (janelas) e [[🧠 red-robot-ai-gd]].

---

## 🔴 P2 — UI: rollouts pendentes

- **Layout responsivo (containers):** migrar as demais telas 2D do posicionamento por offsets absolutos
  para o esqueleto `Margin → VBox → HBox` com `stretch` desativado. **Piloto concluído: `developer`.**
  Replicar para menu/settings/chooseplayer/levels/playonline/sessions. Ver [[📐 layout-responsivo]].
- ~~**Renomear controles 2D (sweep)**~~ — ✅ **CONCLUÍDO em 2026-07-03** (todas as telas): sem repetir o
  Type no Name, sem siglas de tipo, `OptionButton` no plural; `Actions` preservado (o DebugOverlay o
  busca por nome). Regras registradas no `CLAUDE.md` do projeto. Renames: `BackButton→Back` (host/client
  session), `StartButton→Start`, `ManageTemplatesButton→ManageTemplates`, `LevelPicker→Levels`,
  `TemplatePicker→Templates`, `HostRenderPicker→HostRenderModes`, `SyncRatePicker→SyncRates`,
  `InterpPicker→Interpolations`, `ScopeLabel→Scope`/`OptionLabel→Caption` (playonline ×3 colunas),
  7×`Label→Caption` (selectors da models), linhas de sala (`RoomLabel→RoomInfo`, `PlayButton→Play`,
  `Observe/Restart/Stop` sem sufixo Button), diálogo de templates (`ModelBox→ModelColumn`,
  `ModelValueLabel→ModelValue`, `CountSpin→Count`, `EntryPicker→Entries`, `FactionPickers→Factions`,
  `PlacementPicker→Placements`, `FolderPickers%d→Folders%d`), music manager (`ListenPicker→ListenTracks`,
  `TrackLabel_→Track_`, `TrackPicker_→Tracks_`), janela Dano da models (`Bone→Bones`, `Owner→Owners`).
  Dependências de código todas revisadas (`%`, `$`, `get_node`, sinais); validação headless 300 frames sem erro.

---

## ⚪ P3 — Polimento / pendências menores

- **`pause_menu`** (overlay `Control`, 3 botões + 3 sliders): ligar `UINav.wire_tab_ring(self)` +
  `grab_focus` inicial para não ficar fora do anel de Tab. É overlay de pausa (não troca de cena) → **opcional/secundário**. Ver [[🔁 navegacao-tab]] (§ Cobertura e pendências).

---

## Como retomar (checklist rápido)

1. Ler esta nota + [[🏠 Home]] e as notas linkadas do item que vai atacar.
2. Encerrar Zimaro em execução e o editor Godot **antes** de tocar no código.
3. Atacar por prioridade (P0 → P3); dentro de cada item, o "contexto completo" está na nota de sistema.
4. Ao terminar: zerar erros/warnings → atualizar READMEs + cofre → `build_windows.ps1` → **deixar para review** (não commitar).
