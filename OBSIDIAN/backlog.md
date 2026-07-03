# 🗂️ Backlog priorizado — ZIMARO

> **Ponto de retomada entre sessões.** Esta nota é autossuficiente: leia-a no início de uma
> nova conversa para saber **o que está em andamento, o que falta e por qual ordem atacar**.
> Ligada ao [[000-INDEX]]. Cada item aponta para a nota de sistema onde o contexto detalhado vive.
>
> **Convenção de status:** 🟡 em andamento · 🔴 não iniciado · 🟢 pronto (aguardando validação) · ⚪ opcional
>
> **Regras que valem para retomar (ver `CLAUDE.md` / `REGRAS.md`):** nunca commitar/publicar — deixar
> para o usuário revisar; encerrar o jogo e o editor Godot antes de mexer no código; ao fim de tarefa
> com impacto no usuário, atualizar READMEs (`.md`/`.en-US`/`.pt-BR`) **e** este cofre; rodar
> `build_windows.ps1` ao final; eliminar erros/warnings após compilar.

**Última revisão:** 2026-07-03 · **Branch ativa:** `feature/fable`

---

## 🟢 P0.5 — Gerenciador de Templates funcional no .exe — PRONTO p/ review (2026-07-03)

Playtest de ponta a ponta no **.exe exportado** (menu → chooseplayer → levels → Gerenciador de
Templates → template "Arena Fable" (Red Robot ×3 enemy) → partida solo no Level 1 com spawn,
combate, morte e respawn a ~60 FPS). **3 bugs achados e corrigidos** (detalhes em
[[sistemas/templates-de-level]]):

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
combate**. Detalhes: [[sistemas/ambiente-dos-levels]]. READMEs (3) atualizados. O exe caiu de
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
([[000-INDEX]], [[fluxos/fluxo-de-cenas]] ordem de Tab da `levels`, [[sistemas/salas]] nota histórica,
[[convencoes/formatacao]]). **Falta só:** rodar `build_windows.ps1` (feito ao fim da sessão) e a
**publicação pelo usuário**.

<details><summary>Contexto original da reestruturação (referência)</summary>

Branch de reestruturação com muitas mudanças ainda não commitadas. Levada a estado consistente,
testável e revisável.

- **Cofre movido** `OBSIDIAN/CLAUDE/` → `OBSIDIAN/` (raiz do vault agora é `C:\GODOT\ZIMARO\OBSIDIAN`,
  índice em `000-INDEX.md`). Os arquivos aparecem como `D` (caminho antigo) + `??` (caminho novo) no git.
- **Sistema de templates de level** em construção: `scenes2D/level_templates/level_template_dialog.gd`,
  `library3D/structures/` (novo, não rastreado), mais `scenes3D/models/`, `levels`, `net_spawn`,
  `player_selection`, `host_session`, `stability_guard`, `music_manager`. Relaciona com as memórias
  *"salas nascem limpas"* (nada pré-spawnado; inimigos só via template) e *"fallback CORPO member"*.
- **Áudio:** `audios/level_base.ogg` removido (+ `.import`); conferir se `MusicManager`/atribuições por
  cena não referenciam mais esse arquivo. Ver [[sistemas/audio]].

**Fechamento:** rodar o jogo e confirmar que abre sem erro (menu → level → models → salas); zerar
erros/warnings; atualizar os 3 READMEs + notas do cofre afetadas; `build_windows.ps1`; **deixar para o
usuário commitar/publicar** (não commitar). Sistemas: [[sistemas/salas]], [[sistemas/biblioteca-de-modelos]].

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
  Cenários** (sceneries) — ver [[sistemas/templates-de-level]]. Tela `levels` com 2 botões por
  level (Tab renumerado 1-9); cenário "Palco Neon" (4 box + 3 sphere + 2 pill) validado no solo
  E numa sala online.
- **Velocidade dos inimigos terrestres calibrada em padrões reais** (pesquisa: caminhada ~1,4 m/s,
  trote ~3, corrida 4,5): red_robot strafe 4,25→**2,4**, pressão 5,2→**3,2**, fuga 6,0→**3,8** +
  **aceleração suave** (`manual_accel` 6/s) no movimento manual — sem deslizar, com peso.
- **ManageTemplatesButton (host_session) corrigido**: alerta quando nenhum level está selecionado
  (antes retorno silencioso = "botão quebrado"); validado hospedando sala em **127.0.0.1:4383**.
- **Tela `levels` em grade responsiva**: `GridContainer` 3 colunas (Level fixo 300 px | Template |
  Cenário), colunas dos gerenciadores com `SIZE_EXPAND_FILL` **dividindo o resto da tela meio a
  meio**, espaçamento uniforme 16 px nas duas linhas. Ver [[convencoes/layout-responsivo]].
- **`build_windows.ps1` blindado**: apaga `.godot/exported/` antes de todo export — o cache não
  invalida quando um `.tscn` muda e o exe saía com **cena velha** (custou um ciclo de diagnóstico
  com sondas headless e marcadores no binário). Ver [[sistemas/build-windows]].

---

## 🟡 P1 — Validar salas multiplayer em rede real

As Fases 1–3 do servidor multi-level estão **implementadas**. Progresso em 2026-07-01:

- ✅ **Revisão de código do fluxo de salas** (`RoomManager` + `host_session` + `client_session` + `_ready`
  dos níveis + template lazy + filtros de visibilidade): **consistente, sem bugs encontrados**. Verificados
  os fluxos host-joga (`host_spawn_in_room`/`host_leave_room`), cliente-entra (`client_join_room`/`join_room`),
  parar/reiniciar (`notify_room_closed`/`notify_room_restarted`), isolamento por `room_id` e o caminho
  determinístico de replicação `/root/RoomManager/Room<id>/Level`.
- ✅ **Protocolo de teste autossuficiente** criado: [[fluxos/teste-salas-multiplayer]] (loopback local
  `127.0.0.1` → LAN → internet via **playit.gg UDP**; porta padrão `4383`).
- ✅ **Teste A (loopback `127.0.0.1`, 2 instâncias) VALIDADO em campo (2026-07-02):** host cria sala,
  cliente entra e nasce (cenário, não cinza), "(1 conexão)", replicação cliente↔host. **Netcode provado.**
  Ajustes de UI na mesma sessão: janela de erro **não-destrutiva** (× / ESC / "Voltar" só fecham; conserta
  de brinde o quit acidental na validação da tela Models) + **guarda de corrida** do "Jogar" no cliente
  (não nascer numa sala parada durante o `chooseplayer`). Ver [[fluxos/teste-salas-multiplayer]] · [[sistemas/salas]].
- ⬜ **Falta a execução em campo de rede REAL** (precisa de hardware/rede):
  - **Teste B/C (rede real):** 2 PCs (LAN e depois internet via playit.gg) — **depende do usuário**.

Contexto completo: [[sistemas/salas]] · [[sistemas/multiplayer]] · [[sistemas/hospedagem-online]].

---

## 🟡 P1.5 — IA dos inimigos: comportamento + tela de parametrização

Feedback do usuário (2026-07-02) sobre a IA automática atual. Dividido em **comportamento** (código, em
andamento) e **parametrização** (UI, adiada por decisão do usuário). Contexto: [[sistemas/inimigos]],
[[arquivos-chave/red-robot-ai-gd]], `red_robot_ai.gd` / `criatura_alada_ai.gd` / `red_robot.gd`.

**Comportamento (código) — ✅ FEITO (2026-07-02, ver [[sistemas/inimigos]] "Refinamento de IA"):**
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
  numéricos por modelo. Ver [[sistemas/salas]] (janelas) e [[arquivos-chave/red-robot-ai-gd]].

---

## 🔴 P2 — UI: rollouts pendentes

- **Layout responsivo (containers):** migrar as demais telas 2D do posicionamento por offsets absolutos
  para o esqueleto `Margin → VBox → HBox` com `stretch` desativado. **Piloto concluído: `developer`.**
  Replicar para menu/settings/chooseplayer/levels/playonline/sessions. Ver [[convencoes/layout-responsivo]].
- **Renomear controles 2D (sweep):** dar nomes em inglês/papel, sem repetir o Tipo, a todos os controles.
  **Feito: `menu`.** Resto das telas via workflow. Preservar `TitleLabel`/`Actions`. Ver
  [[convencoes/navegacao-tab]] e a memória *"rename 2D controls sweep"*.

---

## ⚪ P3 — Polimento / pendências menores

- **`pause_menu`** (overlay `Control`, 3 botões + 3 sliders): ligar `UINav.wire_tab_ring(self)` +
  `grab_focus` inicial para não ficar fora do anel de Tab. É overlay de pausa (não troca de cena) → **opcional/secundário**. Ver [[convencoes/navegacao-tab]] (§ Cobertura e pendências).

---

## Como retomar (checklist rápido)

1. Ler esta nota + [[000-INDEX]] e as notas linkadas do item que vai atacar.
2. Encerrar Zimaro em execução e o editor Godot **antes** de tocar no código.
3. Atacar por prioridade (P0 → P3); dentro de cada item, o "contexto completo" está na nota de sistema.
4. Ao terminar: zerar erros/warnings → atualizar READMEs + cofre → `build_windows.ps1` → **deixar para review** (não commitar).
