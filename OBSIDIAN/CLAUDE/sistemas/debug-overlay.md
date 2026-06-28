# Sistema — Debug Overlay & Modo Desenvolvedor

Overlay de debug global (`autoload/debug_overlay.gd`, autoload **DebugOverlay**), ligado pela
tela **developer** (`scenes2D/developer/`). Os toggles persistem em `Settings` (seção `game`) e
aplicam na hora (`DebugOverlay.refresh()`).

> [!important] Debug 3D foi para a tela Models (2026-06-23)
> A inspeção 3D (malha, linhas do esqueleto, rótulos por membro / Tipo / Nome / Id) **saiu do
> developer e das telas de jogo** (levels/chooseplayer) e vive agora na tela **Models**, com toggles
> próprios sobre o preview — ver [[sistemas/biblioteca-de-modelos]]. O overlay GLOBAL aplica **só o
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
    **índice de Tab/foco** de cada controle (`TAB: n`, ou `TAB: -` se não focável). O índice é a ordem REAL de
    navegação: o `_compute_tab_indices` parte do 1º focável (`UINav.first_focusable`) da tela ativa e
    segue `find_next_valid_focus()` numerando 1, 2, 3… Recalculado a cada frame **só** enquanto a
    linha Tab está visível (a ordem de foco muda conforme controles aparecem/somem). Ver [[fluxo-de-cenas]].
- Botões **Modelos 3D** / **Controles 2D** (navegação).

## Debug 2D — detalhes

- O `_tag` aplica o 2D em **TODAS as telas, sem exceção** (não checa `no_debug_overlay`) — inclusive
  Models e o editor de Dano. Ao trocar de tela, o `_process` detecta `_active_screen_root` mudar e
  chama `refresh()` para reconstruir os tooltips na cena nova.
- **Toggle de Debug 2D na barra Actions:** ao trocar de tela, o `_process` também chama
  `_ensure_debug2d_toggle(screen)`, que injeta (idempotente) um `Debug2DToggle`
  (`scenes2D/controls2D/debug2d_toggle.gd`, um `CheckButton`) na `HBoxContainer` **Actions** da tela —
  **menos a developer** (`scene_file_path` termina em `developer.tscn`, que já tem o seu próprio par).
  O **menu** e os **levels de gameplay** (level_1/2/base) também ganharam uma barra Actions na posição
  padrão (no menu sob `UI`; nos levels sob o `TitleCanvas`), então o toggle os alcança quando são a
  tela ativa (solo offline). Telas sem nenhuma Actions são ignoradas. O toggle lê/grava
  `Settings("game","debug_2d")` e chama `DebugOverlay.refresh()`. Roda mesmo com o Debug 2D **desligado**
  (a chamada está ANTES do `if _canvas_layer == null: return`), senão não haveria como ligá-lo.
- **Posição dos tooltips:** por padrão cada tooltip fica **à direita** do controle (vira para a
  esquerda se sair da tela). **Exceção — `TitleLabel`:** o tooltip fica **centralizado abaixo do
  texto** do título (flag `is_title` na entrada do `_overlay_map`).
- **Layout anti-sobreposição (reescrito 2026-06-27):** depois de ancorar cada tooltip ao seu controle,
  `_resolve_tooltip_layout` (substituiu `_resolve_overlaps` + `_clamp_tooltips_to_viewport`) prende
  todos à viewport e faz uma **separação iterativa em 2D**: a cada passada empurra cada par sobreposto
  pelo **menor eixo de penetração** (metade p/ cada lado, mais `_TOOLTIP_GAP`), reprendendo à tela, até
  ninguém mais se mover (teto de 16 passadas). O antigo empurrão **só-horizontal** jogava tooltips p/
  fora da tela e deixava cruzamentos (ver imagens do bug). O `TitleLabel` agora **entra** na separação
  (antes era pulado). A cor da borda de cada tooltip = a do controle, então a associação visual se
  mantém mesmo quando ele é afastado. Esforço-limitado: com mais tooltips que espaço, minimiza em vez
  de garantir zero sobreposição.
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
  amplitude 6→12 px). O aceso sobe de `z_index` (borda + tooltip). Os demais voltam ao normal **uma
  vez** (flag `glow_on` na entrada do `_overlay_map`), então só 1 `StyleBox` é reescrito por frame.
  Vale em **toda cena 2D** (mesma varredura global do Debug 2D).
  - **Realce fraco do host (2026-06-28):** se o controle apontado estiver **dentro de outro**, o
    "host" (ancestral `Control` mais próximo rastreado — `_host_id_of`) também recebe overlay, com a
    **borda** no MESMO efeito porém em intensidade bem menor (`_HOST_GLOW = 0.3`: borda/brilho/largura
    escalados por esse fator em `_set_border_lit(..., intensity)`), só p/ situar o controle no
    contêiner. O host fica em `z_index 0`, abaixo do apontado (`1`).
  - **Tooltip do host também aparece, sem colidir com o filho (2026-06-28):** o overlay do apontado e
    o do host são montados pelo mesmo helper `_show_overlay_for(inst_id, tab_visible)` (borda + tooltip
    + linhas Type/Name/Id/Tab), então o **host exibe seu tooltip** igual ao filho. Como agora há 2
    tooltips visíveis, o `_resolve_tooltip_layout` volta a fazer a **separação 2D** entre eles —
    afastando o tooltip do host do tooltip do filho p/ não se sobreporem.
- **Mapeamento de coordenadas — controles em `SubViewport` (2026-06-27):** `_screen_rect_of(ctrl)`
  converte o `get_global_rect()` (espaço da viewport do controle) para **coordenadas de tela** do
  canvas do overlay. Para controles na viewport principal é o próprio rect; para controles **dentro de
  um `SubViewport`** (ex.: o preview da **tela Controles 2D**, `scenes2D/controls/controls.tscn`, que
  instancia cada widget num `SubViewport` via `SubViewportContainer` com `stretch`), sobe a cadeia
  somando `container.get_global_position()` e a escala `container.size / subviewport.size`. Sem isso, a
  borda/tooltip saía **deslocada** da posição real do controle.
- O **watermark do nome da cena** (`_scene_name_label`) fica no **topo direito, ao lado do
  `TitleLabel`** (antes era o canto inferior esquerdo), no canvas persistente. Também ganha tooltip
  2D: como o `_scan` pula o canvas persistente, `_build_overlays` registra `_scene_name_label`
  explicitamente (`_add_2d`) quando `debug_2d` está ligado.
- **Janela flutuante aberta → some o overlay da UI de fundo (2026-06-27):** enquanto QUALQUER
  janela flutuante estiver **visível**, o Debug 2D desenha tooltips/bordas **só nos controles DENTRO
  dela** — a UI que a chamou (a tela atrás) fica limpa, p/ não poluir com informação demais. As
  janelas se marcam no grupo `DebugOverlay.FLOATING_WINDOW_GROUP` (`&"debug_floating_window"`); a cada
  frame o `_process` lista as do grupo que estão `is_visible_in_tree()` (`_active_floating_windows`) e
  `_suppressed_by_floating(ctrl, …)` esconde o que não é descendente de nenhuma delas. Sem janela
  aberta nada muda. **Vale em QUALQUER cena (2026-06-27):** a classe reutilizável `FloatingWindow`
  (`scenes2D/controls2D/floating_window/`) entra no grupo sozinha no seu `_ready`, então toda janela
  baseada nela — incluindo os diálogos de confirmação do `FloatingDialog` — já dispara a supressão em
  qualquer tela. Em Models, como o `damage_panel` (Dano) e o `ai_panel` (IA) **não** são `FloatingWindow`
  (são `PanelContainer` próprios), eles entram no grupo **explicitamente** (`add_to_group` no
  `_setup_damage_window`/`_setup_ai_window`); a `FloatingWindow` de Afastamento/Escala se registra
  sozinha. Abrir/fechar/alternar janelas atualiza a supressão na hora, pois é decidida pela
  visibilidade ao vivo (ver [[sistemas/dano-localizado]], [[sistemas/biblioteca-de-modelos]]).

## Inspeção 3D → tela Models

Malha, linhas do esqueleto, realce de osso, rótulos de membro / Tipo / Nome / Id e dano por membro
são toggles da **tela Models**, aplicados ao seu preview (a cena está no grupo `no_debug_overlay`,
então o overlay global não a toca em 3D). Ver [[sistemas/biblioteca-de-modelos]].

Relacionado: [[sistemas/dano-localizado]] (mesmo classificador `BodyParts`),
[[sistemas/localizacao]], [[convencoes/ancoragem-ui]], [[sistemas/biblioteca-de-modelos]].
