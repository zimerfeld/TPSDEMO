# Layout responsivo (containers)

Convenção (2026-06-23): telas de UI devem organizar os controles com **Containers** (que
posicionam e dimensionam os filhos), **não** com offsets absolutos (`layout_mode = 0`,
`offset_left = 1240`…). Offsets fixos não refluem ao mudar resolução/aspecto e geram bugs de
sobreposição. Complementa [[convencoes/ancoragem-ui|ancoragem de UI]] (que cuida dos poucos
elementos colados nas bordas).

**Stretch do projeto = `disabled` (2026-06-23):** trocado de `canvas_items` para **`disabled`**
(`window/stretch/mode`, base 1920×1080). Com `disabled` os controles têm **tamanho fixo em px** (não
escalam com a resolução) e os Containers reorganizam o layout — resolução maior = mais espaço, não
controles maiores. Decisão do usuário: controles com tamanho único independente da resolução.

**Trade-off do `disabled`:** conteúdo LARGO desenhado para 1920 **transbordaria** abaixo de 1920px
(o `canvas_items` antigo encolhia para caber). Solução: o container **`HFlowContainer`** (filhos
quebram em linha quando não cabem). **Aplicado em `settings` (2026-06-23):** cada linha de opção virou
`HFlowContainer` e os botões perderam o `Expand` (largura = texto, fixa) — em 1366×768 as faixas largas
("Escala de Resolução" com 6 botões) quebram em 2 linhas sem cortar; em ≥1920 ficam numa linha. A barra
de abas (`TabContainer`) já rola sozinha quando não cabe. `models` é denso em sub-1920 mas não tem
faixas largas — não recebeu HFlow (só seria necessário se telas muito estreitas virarem alvo).

## Esqueleto padrão das telas

```
Control (anchors_preset = 15 → tela inteira)
└─ MarginContainer (full rect; margens = respiro nas bordas)
   └─ VBoxContainer
      ├─ Title                 (horizontal_alignment = 1)
      ├─ <seções>              (VBox/HBox/Grid)
      └─ Content (HBox)        filhos com size_flags = Expand → dividem a largura
   (Actions no rodapé e LangBar no canto seguem ancorados — ver ancoragem-ui)
```

## Containers disponíveis (Godot 4)

| Container | Para quê |
|---|---|
| **VBox/HBoxContainer** | Empilha em coluna/linha — base de tudo |
| **GridContainer** | Grade de N colunas (alinhar rótulo \| botão \| botão) |
| **FlowContainer** | Como Box mas **quebra linha** quando não cabe |
| **MarginContainer** | Margens internas (padding) |
| **CenterContainer** | Centraliza o filho sem cálculo |
| **PanelContainer** | Fundo/borda que se ajusta ao conteúdo |
| **AspectRatioContainer** | Mantém a proporção do filho (ex.: viewports 3D) |
| **ScrollContainer** | Rolagem quando excede |
| **SplitContainer** | Duas áreas com divisória |

## As 3 propriedades do esticamento

- **`size_flags_horizontal` / `size_flags_vertical`** → `Fill` (1), **`Expand`** (2, "flex-grow"),
  `Shrink Center` (4) / `Shrink End` (8); `Expand+Fill = 3`, `Shrink Begin = 0`.
- **`custom_minimum_size`** → piso antes de esticar.
- **`stretch_ratio`** → proporção entre filhos que expandem.

## Cena-piloto: developer (2026-06-23)

A `scenes2D/developer/developer.tscn` foi convertida de offsets absolutos para este esqueleto e
serve de **modelo** para as demais:

- Raiz `UI/Margin` (`MarginContainer`, full rect) → `Main` (`VBoxContainer`).
- `Content` é um `HBoxContainer` com `Col2D`, `Col3D` e `PreviewPanel`, todos `size_flags_horizontal
  = Expand` → dividem a largura igualmente e refluem em qualquer resolução. O painel 3D fica com a
  **mesma altura** das colunas automaticamente (sem `offset_top/bottom` fixos). Ver
  [[sistemas/debug-overlay|preview do player]].
- A seção `General` (3 toggles abaixo do título) é um **`GridContainer` de 3 colunas** (rótulo \|
  Desativado \| Ativado): as células de cada coluna assumem a largura da mais larga, então os botões
  **alinham horizontalmente** sozinhos (sem `custom_minimum_size` mágico no rótulo). Como o grid não
  tem nó "row", esses toggles são ligados no script via `_GENERAL_TOGGLES` (par de botões com nomes
  únicos), e não pelo `_row()` usado nas colunas. Usa `size_flags_horizontal = 0` (Shrink Begin) para
  não esticar por toda a largura.
- `Actions` (rodapé) e `LangBar` (canto) seguem **ancorados** (`BOTTOM_WIDE` / `BOTTOM_RIGHT`) como
  overlays — é o caso legítimo de âncora, não de container.
- O `ModelHolder` do `SubViewport` usa `unique_name_in_owner` (`%ModelHolder`) para o script não
  depender do caminho na árvore.

## Rollout (2026-06-23) — TODAS as telas 2D feitas

Aplicado a **todas** as telas 2D de UI, usando a developer como referência. Cada tela recebeu o
esqueleto `Margin → VBox(Main) → conteúdo` com `Actions`/`LangBar`/títulos ancorados; nós acessados
por script viraram `unique_name_in_owner` (`%Nome`) ao serem reparentados (para não quebrar
`@onready`/`[connection]`):

- **developer** — Grid no General, colunas HBox Expand (botões largura fixa), preview em AspectRatio.
- **menu** — menu central num `CenterContainer` + `PanelContainer`.
- **chooseplayer** — título no topo; setas ancoradas nas laterais (centro-V); robô 3D intacto.
- **controls** — seletor + `SubViewportContainer` Expand.
- **levels** — coluna de botões de nível no `Main`.
- **playonline** — formulário centralizado (`CenterContainer` + VBox 700px).
- **settings** — `TabContainer`; cada aba é um `ScrollContainer`; 77 nós → `%nome`.
- **models** — `Selectors`/`Toggles` em `HBox(Body)`; `DamagePanel` MANTIDO absoluto (arrastável por
  script); 41 `@onready` → `%nome`.

Ver [[ui-responsive-rollout]] (memória) para o status e o trade-off sub-1920.
