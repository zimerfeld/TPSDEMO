# Navegação por Tab / foco — helpers `UINav` (e outros helpers do projeto)

> Autoload **`UINav`** (`autoload/ui_nav.gd`) centraliza a navegação por teclado das telas 2D: foco
> inicial, anel de Tab (Tab/Shift+Tab) e a regra do ESC. Esta nota documenta cada helper, **em que cenas
> é usado**, e por que o **Debug 2D** às vezes mostra `TAB: -` (sem número). Relacionada:
> [[sistemas/debug-overlay]], [[fluxos/fluxo-de-cenas]], [[fluxos/fluxo-de-input]], [[convencoes/ancoragem-ui]].

---

## Por que o Debug 2D mostra `TAB: -` em alguns controles?

A linha branca **"Tab"** do [[sistemas/debug-overlay]] é calculada por `DebugOverlay._compute_tab_indices`:
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
| `host_session` | ✅ | ✅ | — | — | — |
| `client_session` | ✅ | ✅ | — | — | — |
| `floating_window` | ✅ (`last=×`) | — | ✅ (no parent ao fechar) | ✅ (`last=×`) | — |
| `chooseplayer` | ✅ | ✅ | — | — | ✅ |
| `settings` | ✅ (+ `tab_changed`) | ✅ | — | — | ✅ |
| `developer` | ✅ (+ sub-toggles) | ✅ | — | — | ✅ |
| `controls` | ✅ | ✅ | — | — | ✅ |
| `debug_overlay` (autoload) | — | — | — | — | — (usa `first_focusable`) |

> `collect_focusables` não tem chamador direto de cena (é interno de `wire_tab_ring`/`tab_one_control`).
> **Casos especiais de re-ligar (2026-06-29):** `settings` re-liga no `TabContainer.tab_changed` (cada aba
> tem seus próprios focáveis e só os da aba VISÍVEL entram no anel); `developer` re-liga no
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
| **`Locale.tr_key`** | `tr_key(key) → String` (autoload [[sistemas/localizacao]]) | ~84 chamadas (todas as telas com texto dinâmico/OptionButton) |
| **`Locale.set_language` / `get_language` / `language_changed`** | troca/lê idioma + sinal | todas as telas com barra de idioma |
| **`CrashHandler.show_error`** | `show_error(msg, retry_callable)` (autoload) | playonline, level_1, level_2, level_base, models, player |
| **`DebugOverlay.refresh`** | reconstrói os overlays 2D | developer, settings, debug2d_toggle |

---

## Cobertura e pendências

**(2026-06-29)** Todas as **telas cheias** agora ligam o anel: `menu`, `playonline`, `levels`,
`host_session`, `client_session`, `chooseplayer`, `settings`, `developer`, `controls` (+ `floating_window`
para janelas). É **regra do projeto** (ver `CLAUDE.md`): toda cena 2D liga `UINav.wire_tab_ring(self)` e
todo controle interativo deve ser focável (sem `TAB: -` em controles de interação).

Pendência conhecida: **`pause_menu`** (overlay `Control`, 3 botões + 3 sliders) — sem barra `Actions` e
sem `grab_focus`. É overlay de pausa (não troca de cena); aplicar o anel ali é opcional/secundário.
