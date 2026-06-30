# Regras do projeto ZIMARO

> Regras específicas deste projeto (não valem para outros projetos).

## Regras ativas

- (2026-06-27) Sempre encerrar o programa Zimaro em execução e fechar o editor do Godot antes de começar qualquer operação no código.
- (2026-06-29) Toda tela/cena 2D deve aplicar o padrão de navegação por foco: `UINav.focus_tab_one` (foco inicial no Tab=1) + helper `_wire_tab_order` (que chama `UINav.wire_tab_ring(self)`), religando o anel no sinal `child_entered_tree` da barra `Actions` (quando o toggle Debug 2D é injetado) e dentro de `_update_language_buttons` (quando o botão do idioma ativo é desabilitado e sai do anel).
- (2026-06-29) Garantir que TODAS as cenas 2D liguem `UINav.wire_tab_ring(self)` e que todo controle de interface de interação com o usuário (botão, campo, dropdown, slider, etc.) seja focável (propriedade/ordem de TAB definida), de modo que o Debug 2D numere `TAB: 1..N` sem deixar controles interativos como `TAB: -`. Ver [[convencoes/navegacao-tab]].
