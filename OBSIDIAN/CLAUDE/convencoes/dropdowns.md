# Convenção — Dropdowns (OptionButton)

> Todo dropdown (`OptionButton`) da UI do jogo deve começar com uma opção
> placeholder chamada **"Selecione..."** como **primeiro item** e **seleção
> padrão**.

## Regras

1. **Primeiro item = `"Selecione..."`** em todo dropdown, inserido no índice `0`
   e selecionado por padrão (`select(0)`) ao montar a tela. Os itens reais
   começam no índice `1` — lembre do offset ao mapear de volta para os dados
   (`dados[index - 1]`).
2. **Cascata de dependentes.** Ao selecionar `"Selecione..."` (índice 0) num
   combo, todo combo que dependa do seu valor deve ser **recarregado também com
   `"Selecione..."` selecionado**, e qualquer comportamento de tela que dependa
   da seleção (preview, status, janela) deve ser **resetado/limpo**.
3. **Tela inicia em branco.** Nada é previsualizado/aplicado até o usuário
   percorrer a cadeia de seleção. Não auto-selecionar o primeiro item real.

## Casos especiais

- **Filtros "mostrar tudo"** (ex.: o antigo `"Todos"` do dropdown de prefixo em
  `models.gd`): substituídos por `"Selecione..."`, que passa a significar
  "sem filtro" (metadata vazia). Continua listando todos os itens.
- **Opções de ação próprias** (ex.: `"Modelo completo"` no dropdown de parte em
  `models.gd`): **mantidas** como itens selecionáveis logo abaixo de
  `"Selecione..."`. Ex. ordem do dropdown de parte: `Selecione...`,
  `Modelo completo`, depois cada malha.
- **Dropdowns que refletem estado salvo** (ex.: resolução de vídeo em
  `settings.gd`): `"Selecione..."` é o default só quando **não há valor salvo**;
  se o salvo casa com um preset, seleciona o preset. Selecionar `"Selecione..."`
  não altera a janela (placeholder no-op).

## Onde se aplica hoje

- `scenes3D/models/models.gd` — cadeia Categoria → Prefixo → Modelo → Parte.
- `scenes2D/settings/settings.gd` — dropdown de resolução de vídeo.
- `scenes2D/controls/controls.gd` — dropdown de controle.

## Links

- [[000-INDEX]]
- [[biblioteca-de-modelos]]
- [[formatacao]]
