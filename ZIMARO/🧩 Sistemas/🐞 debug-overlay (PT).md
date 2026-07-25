---
tipo: sistema
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 🐞 Sistema — Debug Overlay & Modo Desenvolvedor

Overlay de debug global (`autoload/debug_overlay.gd`, autoload **DebugOverlay**), ligado pela
tela **developer** (`scenes2D/developer/`). Os toggles persistem em `Settings` (seção `game`) e
aplicam na hora (`DebugOverlay.refresh()`).

> [!important] Debug 3D foi para a tela Models (2026-06-23)
> A inspeção 3D (malha, linhas do esqueleto, rótulos por membro / Tipo / Nome / Id) **saiu do
> developer e das telas de jogo** (levels/chooseplayer) e vive agora na tela **Models**, com toggles
> próprios sobre o preview — ver [[🗿 biblioteca-de-modelos (PT)|🗿 biblioteca-de-modelos]]. O overlay GLOBAL aplica **só o
> Debug 2D** (tooltips de controles), em qualquer tela. O `_tag` não rotula mais
> `Skeleton3D`/`MeshInstance3D`. **Limpeza (2026-06-23):** todo o código 3D/grid morto do
> `debug_overlay.gd` foi **removido** (≈200 linhas: `_add_3d_skeleton`, linhas de osso, caixa AABB,
> grid, getters `*_3d`/`show_members`/`show_grid`, metas/grupos `no_debug_overlay`/`no_debug_member`,
> `exempt_member_labels`), junto das chaves mortas no `DEFAULTS.game` do config. A **coluna Debug 3D**
> e o **painel de preview** do developer foram **removidos**.

## Tela developer

- **Geral** (`GridContainer`): **HUD FPS** (`hud_fps`) e **Monitor de Saúde** (`performance_hud`).
- **Debug 2D** (coluna única): master `debug_2d` + linhas `show_type` / `show_name` / `show_id` /
  `show_path` / `show_tab` (**Tab é a última opção**). Desenha tooltips 2D (borda colorida +
  TYPE/Name/ID/PATH/TAB, **uma linha por valor, na MESMA ordem dos toggles** da tela developer — a
  ordem dos `vbox.add_child` em `_add_2d` espelha `_DEBUG2D_SUBROWS`/`developer.tscn`) em cada
  `Control`, com **cor por linha** (Tipo = rosa, Nome = verde, Id = amarelo, **Path = azul claro**,
  **Tab = branco** — `_LINE_COLORS`). **Debug 2D ligado sozinho não mostra nada**: borda/tooltips
  só aparecem com ≥1 linha selecionada. As sub-linhas **inteiras** (o rótulo
  `Show*Label` **mais** os botões) ficam **acinzentadas** enquanto o master (Debug 2D) está desligado
  — `_set_subrows_disabled` escurece todo `Control` da linha via `modulate` e só desabilita os
  `BaseButton` (`_DEBUG2D_SUBROWS`; cor base lembrada em `_BASE_MODULATE_META`).
  - **Linha Path** (`ShowPathRow` → `show_path`, abaixo de `ShowIDRow`; rótulo "Path"/"Caminho"):
    mostra o **caminho do controle na árvore da cena ativa** (`_scene_path_of` → `root.get_path_to`,
    encurtado p/ os 3 últimos segmentos com `…/` quando longo). Serve para **diferenciar controles com
    o mesmo Type/Name** na mesma cena. Preenchida a cada frame em `_show_overlay_for` (só p/ o controle
    apontado e seu host).
  - **Linha Tab** (`ShowTabRow` → `show_tab`, **última** sub-linha, abaixo de `ShowPathRow`): mostra o
    **índice de Tab/foco** de cada controle (`TAB: n`, ou `TAB: -` se não focável). **Valor ESPERADO em
    primeiro lugar (2026-06-30):** se o controle declara `metadata/tab_order` (ver
    [[🔁 navegacao-tab (PT)|🔁 navegacao-tab]]), a linha exibe esse número (`UINav.tab_order_of`), para a ordem ser
    previsível e independer da cadeia viva. **Sem** o metadado, cai no índice CALCULADO: o
    `_compute_tab_indices` parte do início da cadeia (`_tab_chain_start`) e segue
    `find_next_valid_focus()` numerando 1, 2, 3… **Com janela flutuante aberta** (fundo suprimido) numera
    a cadeia DA JANELA começando **depois do ×**, então o **× recebe o MAIOR `TAB: n`** (fica por último
    no anel — ver [[🎬 fluxo-de-cenas (PT)|🎬 fluxo-de-cenas]]); sem janela, parte do 1º focável (`UINav.first_focusable`) da tela
    ativa. Recalculado a cada frame **só** enquanto a linha Tab está visível (a ordem de foco muda
    conforme controles aparecem/somem).
    - **Por que alguns controles ficam `TAB: -`?** Dois motivos: (1) **não são focáveis** — `Label`,
      `ColorRect`, `Panel`, containers, título da cena, o **idioma ativo** (`disabled`): correto/esperado;
      (2) **são focáveis, mas a cadeia não os alcança** — em telas **sem** `UINav.wire_tab_ring`, o
      `find_next_valid_focus()` segue os vizinhos automáticos do Godot, que podem não encadear todos os
      contêineres e fechar o ciclo cedo, deixando focáveis sem número. **Ligar o anel**
      (`UINav.wire_tab_ring(self)`) faz todos receberem `TAB: 1..N`. Detalhe em [[🔁 navegacao-tab (PT)|🔁 navegacao-tab]].
- Botões **Modelos 3D** / **Controles 2D** (navegação).

## Debug 2D — detalhes

- O `_tag` aplica o 2D em **TODAS as telas, sem exceção** (não checa `no_debug_overlay`) — inclusive
  Models e o editor de Dano. Ao trocar de tela, o `_process` detecta `_active_screen_root` mudar e
  chama `refresh()` para reconstruir os tooltips na cena nova.
- **Toggle de Debug 2D na barra Actions:** ao trocar de tela, o `_process` também chama
  `_ensure_debug2d_toggle(screen)`, que injeta (idempotente) um `Debug2DToggle`
  (`controls2D/debug2d_toggle.gd`, um `CheckButton`; o **nó** se chama `Debug2D` — sem o sufixo
  "Toggle", padrão 2026-06-28) na `HBoxContainer` **Actions** da tela —
  **menos a developer**, que o `_ensure_debug2d_toggle` pula de propósito. **A developer também passou a
  ter o toggle na Actions (2026-06-29):** ela mesma o injeta (`developer._ensure_actions_debug2d`), na
  **mesma posição padrão** (último item da Actions), e o mantém **em sincronia** com o seu par
  Desativado/Ativado da coluna Debug 2D — toggler um reflete no outro e reavalia as sub-linhas
  (`_on_actions_debug2d_toggled` ⇄ `_on_toggle("debug_2d")`). Por gerenciar o seu, o DebugOverlay a pula.
  O **menu** também ganhou uma barra Actions na posição padrão (sob `UI`), então o toggle o alcança
  quando é a tela ativa. **NUNCA em cena de LEVEL de gameplay (2026-07-02):** embora os levels
  (`level_1`/`level_2`) tenham uma `Actions` no `TitleCanvas`, o `_ensure_debug2d_toggle` agora **retorna
  cedo se `screen is Node3D`** (os levels raízam num `Node3D`) — o toggle Debug 2D é de TELAS 2D de UI,
  não do jogo em si. A tela **Models** (`scenes3D/models`) raíza num `Node` comum, então **não** cai no
  guard e segue recebendo o toggle. Telas sem nenhuma Actions são ignoradas. O toggle lê/grava
  `Settings("game","debug_2d")` e chama `DebugOverlay.refresh()`. Roda mesmo com o Debug 2D **desligado**
  (a chamada está ANTES do `if _canvas_layer == null: return`), senão não haveria como ligá-lo.
- **Canvas SEMPRE à frente (2026-06-29):** os dois `CanvasLayer` do overlay subiram para
  `_OVERLAY_LAYER = 129` (tooltips/bordas) e `130` (watermark do nome da cena), **acima das janelas
  flutuantes** — o `FloatingDialog` monta o diálogo num `CanvasLayer` em **128** (ex.: "Deseja sair do
  Zimaro ?"), que antes **cobria** o overlay (que estava em 100/101). Agora o Debug 2D é desenhado por
  cima do diálogo (e, como é `MOUSE_FILTER_IGNORE`, não rouba clique). Fica abaixo apenas de nada — só o
  crash overlay do `stability_guard` (128) também é alto, mas o debug, por pedido, vem à frente.
- **Posição dos tooltips — regra dos 4 cantos (reescrito 2026-06-28):** `_layout_tooltips(hov, host)`
  posiciona **primeiro** o tooltip do controle **apontado** e **depois** o do **host**, cada um pela
  função `_pick_corner`, que tenta 4 cantos do controle **nesta ordem de prioridade**, escolhendo o
  primeiro que cabe **inteiro na tela**: (1) à **direita do canto superior-direito** → (2) à
  **esquerda do canto superior-esquerdo** → (3) à **direita do canto inferior-direito** → (4) à
  **esquerda do canto inferior-esquerdo**. **Se nenhum canto externo couber sem colidir, PROJETA o
  tooltip PARA DENTRO da área do controle (2026-06-29):** `_project_into_rect` procura um dos **4 cantos
  internos** do rect (sup-esq → sup-dir → inf-esq → inf-dir) que caiba na tela E não sobreponha os rects
  já fixados — como o rect do host costuma ser grande (contêiner), sobra espaço interno longe do tooltip
  do filho, garantindo a regra de **nunca** sobrepor pai × filho. Só se nem o interior couber é que relaxa
  para o 1º que ao menos cabe; último recurso, prende o canto preferido (1) à viewport (`_clamp_pos`).
  **O tooltip do host, além de caber, evita SOBREPOR o do apontado** (que já foi fixado primeiro) —
  corrige o bug "o overlay do pai está colidindo" ao apontar um contêiner (ex.: `VBoxContainer` "main"). Substituiu a antiga separação
  iterativa 2D (`_resolve_tooltip_layout`), desnecessária agora que só há 2 tooltips visíveis (apontado
  + host) no inspetor por hover. **O título da cena (`Title`) também segue a regra dos 4 cantos**
  (2026-06-28) — deixou de ter layout próprio (o antigo caso especial `is_title`, que o centralizava
  abaixo do texto, foi **removido**). A cor da borda de cada tooltip = a do controle, mantendo a
  associação visual mesmo quando ele vai p/ outro canto.
- **Inspetor por hover — overlay só no controle apontado (2026-06-28):** o Debug 2D deixou de
  desenhar borda/tooltip de **todos** os controles ao mesmo tempo. Agora o `_process` roda em **dois
  passos**: (1) esconde **todo** o overlay e acha o controle sob o cursor — o de **menor área** entre
  os que contêm o mouse (o mais específico/interno) e **elegível** (visível na árvore + ≥1 linha do
  Debug 2D ligada + não suprimido por janela flutuante); (2) reexibe **só** esse controle (posiciona
  borda + tooltip e liga as linhas Type/Name/Id/Tab escolhidas). Sem nada sob o cursor, **nada**
  aparece. Como só 1 tooltip fica visível, o `_resolve_tooltip_layout` vira só um clamp à viewport.
- **Realce por iluminação no controle apontado (2026-06-28):** `_apply_border_glow` acende a borda do
  controle exibido: cor mais clara (`color.lightened(0.5)`), borda mais grossa (`_BORDER_WIDTH + 2`)
  e um **brilho** (shadow colorido sem deslocamento) **pulsando** suavemente (`sin(_glow_phase)`,
  amplitude 6→12 px). **Empilhamento (`_Z_*`, 2026-06-29):** os **tooltips** (texto) ficam **SEMPRE
  acima das bordas** — mesmo da borda grossa/brilhante do apontado — para o texto do pai e do filho
  seguir **legível** inclusive quando o tooltip é projetado para dentro da área do controle. Ordem:
  borda host (0) < borda apontado (1) < tooltip host (2) < tooltip apontado (3). Os demais voltam ao normal **uma
  vez** (flag `glow_on` na entrada do `_overlay_map`), então só 1 `StyleBox` é reescrito por frame.
  Vale em **toda cena 2D** (mesma varredura global do Debug 2D).
  - **Realce fraco do host (2026-06-28):** se o controle apontado estiver **dentro de outro**, o
    "host" (ancestral `Control` mais próximo rastreado — `_host_id_of`) também recebe overlay, com a
    **borda** no MESMO efeito porém em intensidade bem menor (`_HOST_GLOW = 0.18`: borda/brilho/largura
    escalados por esse fator em `_set_border_lit(..., intensity)`), só p/ situar o controle no
    contêiner. As **bordas** ficam abaixo dos **tooltips** (ver "Empilhamento" acima): borda do host (0)
    abaixo da do apontado (1), e ambos os tooltips (host 2, apontado 3) acima das duas bordas.
  - **Tooltip do host também aparece, sem colidir com o filho (2026-06-28):** o overlay do apontado e
    o do host são montados pelo mesmo helper `_show_overlay_for(inst_id, tab_visible)` (borda + tooltip
    + linhas Type/Name/Id/Tab), então o **host exibe seu tooltip** igual ao filho. Como há 2 tooltips
    visíveis, o `_layout_tooltips` posiciona **primeiro o do filho** (apontado) e **depois o do host**
    pela regra dos 4 cantos (`_pick_corner`), com o host **evitando o rect já fixado do filho** — não se
    sobrepõem (ver "Posição dos tooltips" acima).
- **Mapeamento de coordenadas — controles em `SubViewport` (2026-06-27):** `_screen_rect_of(ctrl)`
  converte o `get_global_rect()` (espaço da viewport do controle) para **coordenadas de tela** do
  canvas do overlay. Para controles na viewport principal é o próprio rect; para controles **dentro de
  um `SubViewport`** (ex.: o preview da **tela Controles 2D**, `scenes2D/controls/controls.tscn`, que
  instancia cada widget num `SubViewport` via `SubViewportContainer` com `stretch`), sobe a cadeia
  somando `container.get_global_position()` e a escala `container.size / subviewport.size`. Sem isso, a
  borda/tooltip saía **deslocada** da posição real do controle.
- O **watermark do nome da cena** (`_scene_name_label`) fica no **topo direito, ao lado do
  título (`Title`)** (antes era o canto inferior esquerdo), no canvas persistente. Também ganha tooltip
  2D: como o `_scan` pula o canvas persistente, `_build_overlays` registra `_scene_name_label`
  explicitamente (`_add_2d`) quando `debug_2d` está ligado.
- **Nós `Label` sem o sufixo "Label" (2026-06-28):** para limpar a linha **Name** dos tooltips do Debug
  2D, os nós **`type="Label"`** cujo nome terminava em "Label" tiveram o sufixo removido: `TitleLabel →
  Title` (em todas as telas + janelas Dano/IA/`FloatingWindow`), `SceneNameLabel → SceneName` (o nó
  local de Models **e** o watermark global criado em `debug_overlay._setup_scene_name_label`) e
  `SubMemberLabel → SubMember` (o **Label** "Sub-membro:" de Models). Os acessores `%` em
  `models.gd`/`floating_window.gd` acompanham; as variáveis
  GDScript (`_title_label`, `scene_name_label`, `sub_member_label`) **não** mudaram. **Atenção:** o
  **`CheckButton`** `SubMemberLabel` (toggle das labels de sub-membro, renomeado de `SubMemberLabelToggle`
  em 2026-06-28) **não** é `Label` e mantém o nome — os dois `SubMemberLabel` coexistiam por engano (mesmo
  `unique_name`); renomear o Label p/ `SubMember` desfez a colisão.
- **Janela flutuante aberta → some o overlay da UI de fundo (2026-06-27):** enquanto QUALQUER
  janela flutuante estiver **visível**, o Debug 2D desenha tooltips/bordas **só nos controles DENTRO
  dela** — a UI que a chamou (a tela atrás) fica limpa, p/ não poluir com informação demais. As
  janelas se marcam no grupo `DebugOverlay.FLOATING_WINDOW_GROUP` (`&"debug_floating_window"`); a cada
  frame o `_process` lista as do grupo que estão `is_visible_in_tree()` (`_active_floating_windows`) e
  `_suppressed_by_floating(ctrl, …)` esconde o que não é descendente de nenhuma delas. Sem janela
  aberta nada muda. **Vale em QUALQUER cena (2026-06-27):** a classe reutilizável `FloatingWindow`
  (`controls2D/floating_window/`) entra no grupo sozinha no seu `_ready`, então toda janela
  baseada nela — incluindo os diálogos de confirmação do `FloatingDialog` — já dispara a supressão em
  qualquer tela. Em Models, o **editor de IA** virou uma `FloatingWindow` runtime (2026-06-30, ver
  abaixo) e se registra sozinha; já o `damage_panel` (Dano) segue `PanelContainer` próprio (ligado ao
  sistema de dano por membro), então entra no grupo **explicitamente** (`add_to_group` no
  `_setup_damage_window`); a `FloatingWindow` de Afastamento/Escala se registra
  sozinha. Abrir/fechar/alternar janelas atualiza a supressão na hora, pois é decidida pela
  visibilidade ao vivo (ver [[🩸 dano-localizado (PT)|🩸 dano-localizado]], [[🗿 biblioteca-de-modelos (PT)|🗿 biblioteca-de-modelos]]).
- **Gap p/ identificar a janela + Debug2D acionável sob o backdrop (2026-06-30):** regra do projeto —
  toda `FloatingWindow` agora deixa um **anel/margem mínima** (`_WINDOW_CONTENT_GAP = 4 px`,
  `content_margin` no stylebox do `Window`) entre a borda e o conteúdo/titlebar, para o mouse passar
  por esse espaço e o Debug 2D **apontar a própria janela**. E, mesmo com a janela **modal** (backdrop
  bloqueando o fundo), um clique sobre certos controles da cena de fundo continua **acionável**:
  `FloatingWindow._input` (`_clickthrough_button_at`) detecta o clique antes do backdrop e aciona o
  controle — o **toggle Debug 2D** (grupo `Debug2DToggle.GROUP` = `&"debug2d_toggle"`, liga/desliga os
  overlays) **e os botões da `LangBar`** (idiomas; regra 2026-06-30). `disabled` é ignorado (ex.: idioma
  ativo). CheckButton dispara `toggled`; Button de idioma dispara `pressed`.
  Em Models: o **editor de IA** virou uma `FloatingWindow` runtime **não-modal** (`_ensure_ai_window`,
  `remember_position_key = "ai_window"`), então herda **tudo** — gap, anel de foco, ESC, supressão e o
  click-forward. O **Dano** segue `PanelContainer` próprio (ligado ao dano por membro): recebeu o
  **mesmo gap** (`content_margin = 4` no `win_style` de `_setup_damage_window`); o **click-forward** não
  se aplica a ele — é **não-modal** (sem backdrop), então o `Debug2DToggle` da barra Actions de Models já
  fica clicável com ele aberto.

## Inspeção 3D → tela Models

Malha, linhas do esqueleto, realce de osso, rótulos de membro / Tipo / Nome / Id e dano por membro
são toggles da **tela Models**, aplicados ao seu preview (a cena está no grupo `no_debug_overlay`,
então o overlay global não a toca em 3D). Ver [[🗿 biblioteca-de-modelos (PT)|🗿 biblioteca-de-modelos]].

Relacionado: [[🩸 dano-localizado (PT)|🩸 dano-localizado]] (mesmo classificador `BodyParts`),
[[🗣️ localizacao (PT)|🗣️ localizacao]], [[📌 ancoragem-ui (PT)|📌 ancoragem-ui]], [[🗿 biblioteca-de-modelos (PT)|🗿 biblioteca-de-modelos]].
