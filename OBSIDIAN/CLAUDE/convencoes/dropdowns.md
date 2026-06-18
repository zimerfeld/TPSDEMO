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
4. **Persistência da seleção + restauração da cadeia.** Toda escolha dos
   dropdowns é persistida (por um valor **estável** — chave/nome/sentinela, não
   o índice — junto com os toggles). Ao reabrir a tela, a cadeia é replayada de
   cima para baixo: `select()` não emite `item_selected`, então cada passo chama
   também o handler explicitamente para popular o próximo combo. Regra de parada
   por nível: valor **vazio** (o usuário parou ali) → deixa o combo habilitado no
   placeholder, pronto para continuar (com tudo vazio = início em branco normal);
   valor **inexistente hoje** (escolha salva sumiu da biblioteca, "não há mais
   dados") → **desabilita esse combo e os de baixo**. Nunca auto-seleciona item.

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
