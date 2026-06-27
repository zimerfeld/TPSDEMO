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
  `show_tab`. Desenha tooltips 2D (borda colorida + TYPE/Name/ID/TAB) em cada `Control`, com **cor por
  linha** (Tipo = rosa, Nome = verde, Id = amarelo, **Tab = branco** — `_LINE_COLORS`). **Debug 2D
  ligado sozinho não mostra nada**: borda/tooltips só aparecem com ≥1 linha selecionada. As sub-linhas **inteiras** (o rótulo
  `Show*Label` **mais** os botões) ficam **acinzentadas** enquanto o master (Debug 2D) está desligado
  — `_set_subrows_disabled` escurece todo `Control` da linha via `modulate` e só desabilita os
  `BaseButton` (`_DEBUG2D_SUBROWS`; cor base lembrada em `_BASE_MODULATE_META`).
  - **Linha Tab** (`ShowTabRow` → `show_tab`, adicionada abaixo de `ShowIDRow`): mostra o **índice de
    Tab/foco** de cada controle (`TAB: n`, ou `TAB: -` se não focável). O índice é a ordem REAL de
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
