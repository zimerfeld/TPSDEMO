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

**Última revisão:** 2026-07-01 · **Branch ativa:** `feature/restrutu` (24 commits à frente de `main`)

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
