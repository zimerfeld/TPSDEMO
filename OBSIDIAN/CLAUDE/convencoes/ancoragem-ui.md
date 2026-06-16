# Ancoragem de UI (rodapé + título)

Convenção (2026-06-16): elementos colados nas bordas da tela usam ancoragem **`*_WIDE`**
(largura total) com texto/botões centralizados, nunca largura fixa centrada.

- **Barra de botões no rodapé** (`UI/Actions` de menu/settings/models/chooseplayer/
  controls/developer/levels/playonline) → **`BOTTOM_WIDE` (preset 12)**: `anchor_left=0`,
  `anchor_right=1`, `anchor_top=1`, `anchor_bottom=1`, `offset_left/right=0`, com
  `alignment=1` e `grow_horizontal=2`. Largura toda, colada no rodapé, botões no centro.
- **Label do título** (`TitleLabel` de chooseplayer/controls/developer/levels/menu/
  playonline/models + os `TitleCanvas/TitleLabel` dos níveis) → **`TOP_WIDE` (preset 10)**:
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
(settings.gd) e `Settings.apply_window_resolution` (config.gd). Ver [[fluxos/fluxo-de-cenas]].

Relacionado: [[convencoes/dropdowns]] · raiz de cena de UI deve ser `Node`/`Control`
(Control filho de Node2D fica size 0).
