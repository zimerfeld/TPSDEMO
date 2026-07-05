---
tipo: convencao
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 📌 Ancoragem de UI (rodapé + título)

Convenção (2026-06-16): elementos colados nas bordas da tela usam ancoragem **`*_WIDE`**
(largura total) com texto/botões centralizados, nunca largura fixa centrada.

- **Barra de botões no rodapé** (`UI/Actions` de menu/settings/models/chooseplayer/
  controls/developer/levels/playonline) → **`BOTTOM_WIDE` (preset 12)**: `anchor_left=0`,
  `anchor_right=1`, `anchor_top=1`, `anchor_bottom=1`, `offset_left/right=0`, com
  `alignment=1` e `grow_horizontal=2`. Largura toda, colada no rodapé, botões no centro.
  - **Também no menu** (sob `UI`) e nos **levels de gameplay** level_1/2/base (sob o `TitleCanvas`):
    mesma `Actions` BOTTOM_WIDE, mas com `mouse_filter=2` (ignore, para não bloquear o que está atrás)
    — criadas para o toggle de Debug 2D injetado pelo `DebugOverlay`. Ver [[🐞 debug-overlay]].
  - **LangBar dentro da Actions (2026-06-26; nós renomeados 2026-06-28):** os botões de idioma
    (`Portuguese`/`English` — antes `PortugueseButton`/`EnglishButton`) NÃO ficam mais numa barra
    própria ancorada à direita — a `LangBar` virou um `HBoxContainer` filho de `UI/Actions` (sub-grupo
    com `separation=12`), como último item do grupo centralizado. Vale para TODAS as telas
    (menu/settings/levels/chooseplayer/controls/playonline/developer/models). Caminhos:
    `UI/Actions/LangBar/Portuguese` (e as conexões `pressed`). As telas que referenciam por
    `%NomeÚnico` seguem funcionando; controls/developer/playonline/models usam o caminho
    `$UI/Actions/LangBar/...`. O botão **Voltar** também passou de `BackButton` para `Back`.
- **Label do título** (`Title` — antes `TitleLabel` — de chooseplayer/controls/developer/levels/menu/
  playonline/models + os `TitleCanvas/Title` dos níveis) → **`TOP_WIDE` (preset 10)**:
  `anchor_left=0`, `anchor_right=1`, `anchor_top/bottom=0`, `offset_left/right=0`, com
  `horizontal_alignment=1`. Largura toda, colado no topo, texto no centro. (O título de
  settings fica num `VBox` ancorado ao topo, então já flui correto — não é absoluto.)

**Por quê:** antes usavam preset central com **largura fixa** (rodapé 660px, título 800px).
Em resoluções estreitas (retrato/celular) a caixa fixa estourava as laterais e o
conteúdo saía da tela. `*_WIDE` acompanha qualquer largura.

**Complemento (resolução > monitor):** ancoragem sozinha não resolve quando a **janela**
fica maior que a tela (4K/8K num monitor 1080p) — aí a janela inteira (topo e rodapé)
é cortada. Por isso a aplicação de resolução **limita a janela à área útil da tela**
(`DisplayServer.screen_get_usable_rect`) e centraliza — ver `_apply_video_resolution`
(settings.gd) e `Settings.apply_window_resolution` (config.gd). Ver [[🎬 fluxo-de-cenas]].

**Stretch = `disabled` (2026-06-23):** `window/stretch/mode` passou de `canvas_items` para `disabled`
— controles com **tamanho fixo** (não escalam com a resolução); o layout reflui via Containers. Toda
tela 2D foi migrada para o esqueleto de containers; ver [[📐 layout-responsivo]].

Relacionado: [[🔽 dropdowns]] · [[📐 layout-responsivo]] · raiz de cena de UI deve
ser `Node`/`Control` (Control filho de Node2D fica size 0).
