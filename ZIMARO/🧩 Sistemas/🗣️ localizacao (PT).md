---
tipo: sistema
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 🗣️ Sistema — Localização (EN/PT/ES)

Troca de idioma da UI entre **Português**, **English** e **Español**, via autoload **Locale**
(`autoload/locale.gd`). Os idiomas suportados ficam em `Locale.SUPPORTED_LANGS` (`["pt", "en", "es"]`).

## Dicionários por cena

Cada cena tem seu **próprio trio** de JSON planos numa pasta `Resources/` ao lado do `.tscn`:
`scenes2D/menu/Resources/menu.pt.json` + `menu.en.json` + `menu.es.json`,
`scenes2D/settings/Resources/settings.pt.json` + `...en.json` + `...es.json`,
`scenes3D/models/Resources/models.pt.json` + `...en.json` + `...es.json`, etc. Cada trio mapeia o
texto canônico (autorado) de cada Button/Label para o texto daquele idioma e tem o **mesmo conjunto
de chaves** nos três idiomas.

Na inicialização o Locale **varre recursivamente** `scenes2D/` e `scenes3D/` (`SCAN_ROOTS`), acha
todo `*.pt.json` / `*.en.json` / `*.es.json` e **mescla** tudo numa tabela por idioma. Adicionar os
dicionários `Resources/` de uma tela nova basta — sem editar o autoload. (Não existe mais
`pt.json`/`en.json`/`es.json` na raiz do projeto.)

## Persistência e aplicação

- A escolha é salva em `Settings` → `game/language` (`"pt"` padrão / `"en"` / `"es"`; um valor fora de
  `SUPPORTED_LANGS` cai no padrão).
- No `_ready`, o Locale lê o idioma persistido, monta a tabela e **conecta-se a `node_added`**: todo
  Button/Label que entra na árvore tem o `text` traduzido automaticamente. `OptionButton`/`MenuButton`
  são **ignorados** (texto = seleção viva).
- A primeira vez que vê um nó, guarda o texto original em meta (`_loc_src`); trocas de idioma traduzem
  a partir desse original (não do texto já traduzido).
- `set_language(lang)` persiste, remonta a tabela e **re-localiza a árvore viva** (emite
  `language_changed`).

## Botões de idioma — em TODAS as telas

A `UI/LangBar` (HBox no canto inferior direito com botões "Português" / "English" / "Español", mesmo
padrão do menu) está em **menu, chooseplayer, settings, developer, levels, playonline, controls e
models**. Cada script chama `Locale.set_language(...)` e acinzenta o botão do idioma ativo
(`_update_language_buttons` — cada tela tem `portuguese_button`/`english_button`/`spanish_button`). Como a re-localização é in-place, a tela atualiza na hora.
**Alinhamento (2026-06-25):** a `LangBar` fica na **mesma faixa vertical do botão "Voltar"** (offsets
do rodapé `−100`/`−50`) em todas essas telas.

## Textos vindos de código (SKIP_GROUP)

Textos que o localizador automático não alcança — placeholders/itens de `OptionButton`, títulos
das abas de settings, diálogos de confirmação, e o **PerformanceHUD**/overlay do **StabilityGuard** —
entram no grupo `Locale.SKIP_GROUP` e reaplicam `Locale.tr_key(...)` sozinhos no sinal
`language_changed`. As chaves do HUD/Guard ficam em `scenes2D/overlays/Resources/overlays.{pt,en,es}.json`.
(As telas
`models` e `controls` **não têm mais** `StatusLabel` — removidas em 2026-06-18.)

Os **prefixos dos `Label3D`** da cena Models (`Membro:`/`Sub-membro:`/`Esqueleto:`/`Tipo:`/`Nome:`)
também não são alcançados pelo auto-tradutor: vão por `Locale.tr_key` e são reconstruídos no
`language_changed` (`_refresh_member_overlays`/`_refresh_aux_labels`) — ver [[🗿 biblioteca-de-modelos (PT)|🗿 biblioteca-de-modelos]].

Os **títulos de coluna do `Tree`** da janela de **Dano** (`Membro`/`Def`/`Bônus %`/`Dono`) são outro
caso: `set_column_title` não é `Label`/`Button`, então o auto-tradutor não o alcança. Desde 2026-06-27,
`_apply_damage_tree_titles()` os reaplica via `Locale.tr_key` na construção da árvore E no
`language_changed` (antes ficavam presos no idioma da última construção) — ver [[🩸 dano-localizado (PT)|🩸 dano-localizado]].

## Regra — mudou texto, atualize as chaves

**Sempre que alterar ou adicionar um texto de UI em uma cena, atualize a chave correspondente em
`Resources/<cena>.pt.json`, `Resources/<cena>.en.json` E `Resources/<cena>.es.json` da própria cena,
na mesma tarefa.** Como o Locale indexa pelo texto-fonte, mudar a cena sem atualizar a chave quebra a
tradução. PT recebe a tradução em português; EN, em inglês; ES, em espanhol. Validar os três JSON ao final.

Relacionado: [[🎬 fluxo-de-cenas (PT)|🎬 fluxo-de-cenas]], [[🐞 debug-overlay (PT)|🐞 debug-overlay]], [[⚡ performance-hud (PT)|⚡ performance-hud]],
[[🧭 main-gd (PT)|🧭 main-gd]].
