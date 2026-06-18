# Sistema — Localização (EN/PT)

Troca de idioma da UI entre **Português** e **English**, via autoload **Locale**
(`autoload/locale.gd`).

## Dicionários

Cada idioma é um JSON plano na **raiz do projeto**: `pt.json` e `en.json`, mapeando o
texto canônico (do build em português) de cada Button/Label para o texto daquele idioma.
Ambos contêm o mesmo conjunto de chaves. `pt.json` é essencialmente identidade
(preserva a aparência atual); `en.json` traz as traduções.

## Persistência e aplicação

- A escolha é salva em `Settings` → `game/language` (`"pt"` padrão / `"en"`).
- No `_ready`, o Locale lê o idioma persistido, carrega o dicionário e **conecta-se a
  `node_added`**: todo Button/Label que entra na árvore tem o `text` traduzido
  automaticamente — telas novas são cobertas **sem código por cena**.
- A primeira vez que vê um nó, guarda o texto original em meta (`_loc_src`); trocas de
  idioma traduzem a partir desse original (não do texto já traduzido).
- `set_language(lang)` persiste, recarrega o dicionário e **re-localiza a árvore viva**
  (emite `language_changed`).

## Botões de idioma

Ancorados no **rodapé da tela menu** (`UI/LangBar`: "Português" / "English"). O
`menu.gd` chama `Locale.set_language(...)` e acinzenta o botão do idioma ativo
(`_update_language_buttons`). Como a re-localização é in-place, o menu atualiza na hora.

## Estender cobertura

Adicionar novas strings = acrescentar a chave (texto-fonte → tradução) em **ambos** os
arquivos JSON. Nenhuma mudança de código necessária.

## Regra — mudou texto, atualize as chaves

**Sempre que alterar ou adicionar um texto de Button/Label em uma cena, atualize a chave
correspondente em `pt.json` E `en.json` na mesma tarefa, junto com a cena.** Como o Locale
indexa pelo texto-fonte, mudar a cena sem atualizar a chave quebra a tradução (chave órfã
no idioma inativo, string sem tradução no outro). PT recebe a tradução em português; EN, em
inglês. Validar os dois JSON ao final.

Relacionado: [[fluxos/fluxo-de-cenas]], [[sistemas/debug-overlay]],
[[arquivos-chave/main-gd]].
