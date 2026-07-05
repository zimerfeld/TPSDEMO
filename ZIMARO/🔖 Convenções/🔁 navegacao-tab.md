---
tipo: convencao
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 🔁 Navegação por Tab / foco — helpers `UINav` (e outros helpers do projeto)

> Autoload **`UINav`** (`autoload/ui_nav.gd`) centraliza a navegação por teclado das telas 2D: foco
> inicial, anel de Tab (Tab/Shift+Tab) e a regra do ESC. Esta nota documenta cada helper, **em que cenas
> é usado**, e por que o **Debug 2D** às vezes mostra `TAB: -` (sem número). Relacionada:
> [[🐞 debug-overlay]], [[🎬 fluxo-de-cenas]], [[⌨️ fluxo-de-input]], [[📌 ancoragem-ui]].

---

## Ordem EXPLÍCITA de Tab — `metadata/tab_order` (2026-06-30)

Regra do projeto: **mesmo com o auto-Tab do Godot aplicado, declarar a ordem ESPERADA de Tab e
exibi-la no Debug Overlay**, para previsibilidade do ciclo. Mecanismo escolhido: **metadata por nó**.

- Cada controle interativo carrega `metadata/tab_order = N` (1-based) no `.tscn`, na **ordem de
  leitura** (topo→baixo, esquerda→direita) — que é a própria ordem de árvore/documento. Ex. (cena
  `menu`): `Play=1, PlayOnline=2, Settings=3, Developer=4, Quit=5, Portuguese=6, English=7`; o toggle
  **Debug 2D** é injetado em runtime e recebe `tab_order = maior declarado da tela + 1`
  (`DebugOverlay._max_declared_tab_order`), ficando sempre por ÚLTIMO (menu `8`, chooseplayer `7`…).
  **Containers de linha (`*Row`)** que envolvem um único controle podem **espelhar** o mesmo `tab_order`
  do seu controle só para EXIBIÇÃO (ex.: `menu` `PlayRow=1`…`QuitRow=5`); como não são focáveis, não
  entram no anel. **Controles criados em runtime** (ex.: botões de Template em `levels`) recebem `name`
  próprio + `tab_order` via `set_meta` na criação (senão apareceriam como `@Button@N` e sem número).
- **`UINav.collect_focusables`** agora ordena por `tab_order` (crescente) e, entre os SEM metadado (ou
  empatados), pela ordem de árvore — então `wire_tab_ring` monta o anel exatamente nessa ordem. Como o
  metadado replica a ordem de árvore que já era usada, **não há mudança de comportamento** nas telas
  que já ligavam o anel; só ficou explícito.
- **Debug 2D mostra o valor ESPERADO:** a linha Tab usa `UINav.tab_order_of(ctrl)` — se há
  `tab_order`, exibe esse número; senão cai no índice CALCULADO pela cadeia viva (`_tab_index_map`).
- Aplicado em: `menu`, `chooseplayer`, `controls`, `developer`, `levels`, `playonline`, `settings`
  (numerado **atravessando as abas**, ver abaixo), `pause_menu` e `models` (3D).

## TabContainer — Tab atravessa as abas (2026-06-30)

Regra do projeto para o controle `TabContainer` (hoje só `settings`):

1. A **1ª aba** é o foco inicial ao entrar com Tab.
2. Dentro da aba, Tab anda **esquerda→direita, cima→baixo**.
3. No **último controle de uma aba**, Tab **troca para a próxima aba** e realça o **1º controle** dela.
4. Só **sai** do `TabContainer` (vai para Voltar/Reset/idioma/Debug2D) quando se está no **último
   controle da ÚLTIMA aba** e Tab é pressionado de novo.

Implementação: a cena trata Tab/Shift+Tab no `_input` chamando **`UINav.tab_container_focus_step(self,
tabs, forward)`** (consumindo o evento). O helper monta a **ordem global** com
**`collect_focus_order_with_tabs`** — focáveis antes do TabContainer → aba 0 → … → aba N-1 → focáveis
depois — usando **`collect_focusables_ignoring_visibility`** para varrer as abas OCULTAS; ao cruzar a
fronteira de uma aba, troca `current_tab` e foca o alvo (deferido). `settings` deixou de montar um anel
fechado (`wire_tab_ring`) e de re-ligar em `tab_changed`/idioma — a ordem é recalculada a cada passo
(ignora desabilitados, então o idioma ativo sai sozinho). Com uma **janela flutuante aberta**, o Tab é
da janela (anel próprio) — `settings._input` não atravessa as abas (`_floating_window_open`).

## Por que o Debug 2D mostra `TAB: -` em alguns controles?

A linha branca **"Tab"** do [[🐞 debug-overlay]] é calculada por `DebugOverlay._compute_tab_indices`:
parte do **1º focável** da tela (`UINav.first_focusable`) e segue **`Control.find_next_valid_focus()`**
controle a controle até **fechar o ciclo** (voltar a um já numerado). Cada controle visitado recebe
`TAB: 1, 2, 3…`; **quem não é visitado fica com `TAB: -`**. Logo, há **dois motivos** para não ter número:

1. **Não é focável** — é o caso correto/esperado: `Label`, `ColorRect`, `Panel`, `MarginContainer`,
   `VBox/HBox`, `TextureRect` decorativo, o **título da cena**, etc. (não têm `focus_mode = FOCUS_ALL`).
   Também o **botão de idioma ATIVO** (fica `disabled`, fora do anel) e nós marcados
   `is_queued_for_deletion()`. Esses **devem** mostrar `TAB: -`.
2. **É focável, mas a cadeia automática não o alcança** — este é o motivo "surpresa": **sem**
   `UINav.wire_tab_ring`, o `find_next_valid_focus()` segue os **vizinhos que o Godot calcula sozinho**
   (geometria/`focus_next`). Quando os focáveis estão em **contêineres separados** (várias `HBox`/colunas),
   esses vizinhos automáticos **podem não encadear todos** ou **fechar o ciclo cedo** → o passeio termina
   antes de visitar o resto, que aparece como `TAB: -` **mesmo sendo focável**.
3. **`SpinBox` NÃO é `FOCUS_ALL` por padrão (2026-06-30)** — diferente de `Button`/`LineEdit`/`OptionButton`,
   o `SpinBox` nasce sem `focus_mode = FOCUS_ALL`, então o `collect_focusables` o IGNORA e o Tab o pula
   (ex.: `playonline` pulava do `PlayerName`=1 direto para `PortHistories`=3, sem parar no `Port`=2).
   **Corrigir definindo `focus_mode = 2` (FOCUS_ALL)** no `.tscn`, ou `sp.focus_mode = Control.FOCUS_ALL`
   nos `SpinBox` criados em código (diálogo de templates, linhas Afastamento/Rotação/Escala de Models).

> **Telas com colunas:** o ciclo de Tab é por COLUNA — percorre todos os controles de uma coluna (de cima
> para baixo) antes de passar para a próxima. Como `collect_focusables` segue a ordem de árvore (e o
> `tab_order` declarado), basta que cada coluna seja um contêiner próprio na ordem de leitura.

**Conclusão:** se um controle **focável** aparece sem número, a tela provavelmente **ainda não liga o anel**.
Chamar **`UINav.wire_tab_ring(self)`** amarra `focus_next`/`focus_previous` num **anel fechado
`1 → 2 → … → N → 1`**, então o `find_next_valid_focus()` passa por **todos** e o Debug 2D numera **1..N
incremental de 1**. (Rótulos/containers continuam, corretamente, em `TAB: -`.)

> Para ver os números: tela **developer** → ligar **Debug 2D** + a linha **Tab**.

---

## Helpers de `UINav` (foco/teclado)

| Helper | Assinatura | O que faz |
|---|---|---|
| **`wire_tab_ring`** | `wire_tab_ring(root, last=null)` | **(novo)** Liga Tab/Shift+Tab num **anel fechado** na ordem de leitura (ordem de árvore: topo→baixo, e numa HBox esquerda→direita) via `collect_focusables`. `last` (opcional) vai para o **FIM** do anel (maior índice) — ex.: o **×** das janelas flutuantes. **Idempotente**: re-chamar sempre que o conjunto de focáveis mudar (toggle injetado, idioma habilitando/desabilitando, listas dinâmicas). |
| **`focus_tab_one`** | `focus_tab_one(root, last=null) → Control` | Dá foco à **cabeça do anel** (Tab = 1). Usado ao **abrir** a tela para o foco começar sempre no 1º da sequência. |
| **`tab_one_control`** | `tab_one_control(root, last=null) → Control` | Devolve (sem focar) o controle de **Tab = 1** = `collect_focusables(root)` menos `last`, 1º item. |
| **`focus_first`** | `focus_first(root) → Control` | Dá foco ao **1º focável** em ordem de árvore. Equivale a `focus_tab_one` quando não há `last` movido — é o padrão **antigo** das telas que ainda não ligam o anel. |
| **`first_focusable`** | `first_focusable(node) → Control` | 1º `Control` focável (FOCUS_ALL, visível, `BaseButton` não-`disabled`) em ordem de árvore. Base de `focus_first` e usado pelo **DebugOverlay** para achar o início da cadeia de Tab. |
| **`collect_focusables`** | `collect_focusables(root) → Array[Control]` | **Todos** os focáveis sob `root` em ordem de árvore. Base de `wire_tab_ring`/`tab_one_control`. Ignora `is_queued_for_deletion()`. |
| **`cancel_active_edit`** | `cancel_active_edit(viewport, fallback=null) → bool` | **Regra do ESC**: se o foco está num `LineEdit` (inclui o editor interno de um `SpinBox`), encerra a edição e devolve o foco ao `fallback`, retornando `true` (o chamador consome o ESC e **não** volta de tela). Só o **2º ESC** navega de volta. |
| **`tab_order_of`** | `tab_order_of(ctrl) → int` | Valor declarado de `metadata/tab_order` (1-based) ou um sentinela grande se ausente. Base da ordenação de `collect_focusables` e da linha Tab do Debug 2D (valor ESPERADO). |
| **`collect_focusables_ignoring_visibility`** | `… → Array[Control]` | Varre uma aba OCULTA do `TabContainer`: ignora que a aba-raiz esteja escondida, mas RESPEITA o flag PRÓPRIO `.visible` (controles escondidos por conta própria — ex.: botões MetalFX num SO sem suporte — ficam de FORA, senão o Tab tentaria focar um oculto e travava no fim da aba). |
| **`collect_focus_order_with_tabs`** | `(scene_root, tab_container) → Array[Control]` | Ordem GLOBAL de foco com cada aba expandida em sequência (ocultas incluídas): antes → aba 0 → … → aba N-1 → depois. |
| **`tab_container_focus_step`** | `(scene_root, tab_container, forward) → bool` | Um passo de Tab/Shift+Tab atravessando as abas (regra do TabContainer). Troca a aba visível quando o alvo está noutra aba. Chamada do `_input` da cena. |

### Padrão de uso numa tela (cópia pronta)

```gdscript
func _ready() -> void:
    # ... preencher campos, montar opções dinâmicas ANTES de ligar o anel ...
    UINav.focus_tab_one.call_deferred(self)            # foco no Tab = 1
    _wire_tab_order.call_deferred()                    # liga o anel (deferido)
    ($UI/Actions as HBoxContainer).child_entered_tree.connect(
        func(_n: Node) -> void: _wire_tab_order.call_deferred())  # re-liga ao injetar o Debug2D

func _wire_tab_order() -> void:
    UINav.wire_tab_ring(self)

func _update_language_buttons() -> void:
    # ... define disabled do idioma ativo ...
    if is_node_ready():
        _wire_tab_order.call_deferred()                # idioma ativo sai do anel → re-liga

func _input(e: InputEvent) -> void:
    if e.is_action_pressed(&"quit"):
        if UINav.cancel_active_edit(get_viewport(), <fallback>):
            get_viewport().set_input_as_handled(); return
        get_viewport().set_input_as_handled()
        # ... voltar de tela ...
```

### Matriz: qual cena usa qual helper de `UINav`

| Cena / arquivo | `wire_tab_ring` | `focus_tab_one` | `focus_first` | `tab_one_control` | `cancel_active_edit` |
|---|:---:|:---:|:---:|:---:|:---:|
| `menu` | ✅ | ✅ | — | — | ✅ |
| `playonline` | ✅ | ✅ | — | — | ✅ |
| `levels` | ✅ | ✅ | — | — | ✅ |
| `host_session` | ✅ (scaffold estático; `tab_order` por código no `_rewire_tab`) | ✅ | — | — | — |
| `client_session` | ✅ (scaffold estático; `tab_order` por código no `_rewire_tab`) | ✅ | — | — | — |
| `floating_window` | ✅ (`last=×`) | — | ✅ (no parent ao fechar) | ✅ (`last=×`) | — |
| `chooseplayer` | ✅ | ✅ | — | — | ✅ |
| `settings` | — (usa `tab_container_focus_step`) | — (foca 1º da aba 0) | — | — | ✅ |
| `developer` | ✅ (+ sub-toggles) | ✅ | — | — | ✅ |
| `controls` | ✅ | ✅ | — | — | ✅ |
| `debug_overlay` (autoload) | — | — | — | — | — (usa `first_focusable`) |

> `collect_focusables` não tem chamador direto de cena (é interno de `wire_tab_ring`/`tab_one_control`).
> **Casos especiais de re-ligar (2026-06-29):** `settings` **não** usa mais o anel — trata Tab no
> `_input` atravessando as abas (ver "TabContainer" acima, 2026-06-30); `developer` re-liga no
> `_update_subrows_enabled` (as sub-toggles do Debug 2D entram/saem do anel conforme o master liga/desliga).

---

## Outros helpers compartilhados do projeto

Helpers reutilizáveis (estáticos ou de autoload) usados por várias cenas — não confundir com os
**stores de configuração** (`Settings`, `NetConfig`, `RoomManager`…), que guardam estado, não são "helpers".

| Helper | Assinatura / origem | Cenas que usam |
|---|---|---|
| **`FloatingDialog.confirm`** | `confirm(parent, title, text, ok="Sim", cancel="Não") → FloatingWindow` | menu, host_session, client_session, settings, models, crash_handler |
| **`FloatingDialog.alert`** | `alert(parent, title, text, ok="OK") → FloatingWindow` | client_session, crash_handler |
| **`FloatingWindow.style_close_button`** | `static` — estiliza o botão × | models |
| **`FloatingWindow.pointer_over_any_window`** | `static → bool` — cursor sobre alguma janela flutuante | models |
| **`FloatingWindow.wire_focus_ring`** | instância → delega a `UINav.wire_tab_ring(self, _close_button)` | toda janela flutuante (× por último) |
| **`Locale.tr_key`** | `tr_key(key) → String` (autoload [[🗣️ localizacao]]) | ~84 chamadas (todas as telas com texto dinâmico/OptionButton) |
| **`Locale.set_language` / `get_language` / `language_changed`** | troca/lê idioma + sinal | todas as telas com barra de idioma |
| **`CrashHandler.show_error`** | `show_error(msg, retry_callable)` (autoload) | playonline, level_1, level_2, models, player |
| **`DebugOverlay.refresh`** | reconstrói os overlays 2D | developer, settings, debug2d_toggle |

---

## Cobertura e pendências

**(2026-06-29)** Todas as **telas cheias** agora ligam o anel: `menu`, `playonline`, `levels`,
`host_session`, `client_session`, `chooseplayer`, `settings`, `developer`, `controls` (+ `floating_window`
para janelas). É **regra do projeto** (ver `CLAUDE.md`): toda cena 2D liga `UINav.wire_tab_ring(self)` e
todo controle interativo deve ser focável (sem `TAB: -` em controles de interação).

Pendência conhecida: **`pause_menu`** (overlay `Control`, 3 botões + 3 sliders) — sem barra `Actions` e
sem `grab_focus`. É overlay de pausa (não troca de cena); aplicar o anel ali é opcional/secundário.
