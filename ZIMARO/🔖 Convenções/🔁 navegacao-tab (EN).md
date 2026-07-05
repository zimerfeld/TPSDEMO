---
tipo: convencao
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🔁 Tab / focus navigation — `UINav` helpers (and other project helpers)

> The **`UINav`** autoload (`autoload/ui_nav.gd`) centralizes the keyboard navigation of the 2D screens:
> initial focus, the Tab ring (Tab/Shift+Tab) and the ESC rule. This note documents each helper, **in which
> scenes it is used**, and why the **Debug 2D** sometimes shows `TAB: -` (no number). Related:
> [[🐞 debug-overlay (EN)\|debug-overlay]], [[🎬 fluxo-de-cenas (EN)\|fluxo-de-cenas]], [[⌨️ fluxo-de-input (EN)\|fluxo-de-input]], [[📌 ancoragem-ui (EN)\|ancoragem-ui]].

---

## EXPLICIT Tab order — `metadata/tab_order` (2026-06-30)

Project rule: **even with Godot's auto-Tab applied, declare the EXPECTED Tab order and
show it in the Debug Overlay**, for cycle predictability. Chosen mechanism: **per-node metadata**.

- Each interactive control carries `metadata/tab_order = N` (1-based) in the `.tscn`, in the **reading
  order** (top→bottom, left→right) — which is the tree/document order itself. E.g. (scene
  `menu`): `Play=1, PlayOnline=2, Settings=3, Developer=4, Quit=5, Portuguese=6, English=7`; the
  **Debug 2D** toggle is injected at runtime and gets `tab_order = the screen's highest declared + 1`
  (`DebugOverlay._max_declared_tab_order`), always staying LAST (menu `8`, chooseplayer `7`…).
  **Row containers (`*Row`)** wrapping a single control may **mirror** the same `tab_order`
  of their control just for DISPLAY (e.g. `menu` `PlayRow=1`…`QuitRow=5`); since they are not focusable, they don't
  enter the ring. **Controls created at runtime** (e.g. the Template buttons in `levels`) get their own `name`
  + `tab_order` via `set_meta` at creation (otherwise they'd appear as `@Button@N` and without a number).
- **`UINav.collect_focusables`** now orders by `tab_order` (ascending) and, among those WITHOUT metadata (or
  tied), by tree order — so `wire_tab_ring` builds the ring exactly in that order. Since the
  metadata replicates the tree order that was already used, **there is no change in behavior** in the screens
  that already wired the ring; it just became explicit.
- **Debug 2D shows the EXPECTED value:** the Tab line uses `UINav.tab_order_of(ctrl)` — if there is a
  `tab_order`, it shows that number; otherwise it falls back to the index CALCULATED from the live chain (`_tab_index_map`).
- Applied in: `menu`, `chooseplayer`, `controls`, `developer`, `levels`, `playonline`, `settings`
  (numbered **crossing the tabs**, see below), `pause_menu` and `models` (3D).

## TabContainer — Tab crosses the tabs (2026-06-30)

Project rule for the `TabContainer` control (today only `settings`):

1. The **1st tab** is the initial focus when entering with Tab.
2. Inside the tab, Tab moves **left→right, top→bottom**.
3. On the **last control of a tab**, Tab **switches to the next tab** and highlights its **1st control**.
4. It only **leaves** the `TabContainer` (goes to Back/Reset/language/Debug2D) when you are on the **last
   control of the LAST tab** and Tab is pressed again.

Implementation: the scene handles Tab/Shift+Tab in `_input` by calling **`UINav.tab_container_focus_step(self,
tabs, forward)`** (consuming the event). The helper builds the **global order** with
**`collect_focus_order_with_tabs`** — focusables before the TabContainer → tab 0 → … → tab N-1 → focusables
after — using **`collect_focusables_ignoring_visibility`** to scan the HIDDEN tabs; when crossing a tab
boundary, it switches `current_tab` and focuses the target (deferred). `settings` stopped building a closed
ring (`wire_tab_ring`) and re-wiring on `tab_changed`/language — the order is recomputed on each step
(it ignores disabled ones, so the active language drops out by itself). With a **floating window open**, the Tab is
of the window (its own ring) — `settings._input` doesn't cross the tabs (`_floating_window_open`).

## Why does Debug 2D show `TAB: -` on some controls?

The white **"Tab"** line of [[🐞 debug-overlay (EN)\|debug-overlay]] is computed by `DebugOverlay._compute_tab_indices`:
it starts from the screen's **1st focusable** (`UINav.first_focusable`) and follows **`Control.find_next_valid_focus()`**
control by control until it **closes the cycle** (returns to an already-numbered one). Each visited control gets
`TAB: 1, 2, 3…`; **whoever isn't visited stays `TAB: -`**. So there are **two reasons** for having no number:

1. **It is not focusable** — this is the correct/expected case: `Label`, `ColorRect`, `Panel`, `MarginContainer`,
   `VBox/HBox`, decorative `TextureRect`, the **scene title**, etc. (they don't have `focus_mode = FOCUS_ALL`).
   Also the **ACTIVE language button** (stays `disabled`, out of the ring) and nodes marked
   `is_queued_for_deletion()`. These **should** show `TAB: -`.
2. **It is focusable, but the automatic chain doesn't reach it** — this is the "surprise" reason: **without**
   `UINav.wire_tab_ring`, `find_next_valid_focus()` follows the **neighbors Godot computes on its own**
   (geometry/`focus_next`). When the focusables are in **separate containers** (several `HBox`/columns),
   those automatic neighbors **may not chain all of them** or **close the cycle early** → the walk ends
   before visiting the rest, which appears as `TAB: -` **even though it is focusable**.
3. **`SpinBox` is NOT `FOCUS_ALL` by default (2026-06-30)** — unlike `Button`/`LineEdit`/`OptionButton`,
   the `SpinBox` is born without `focus_mode = FOCUS_ALL`, so `collect_focusables` IGNORES it and Tab skips it
   (e.g. `playonline` jumped from `PlayerName`=1 straight to `PortHistories`=3, without stopping at `Port`=2).
   **Fix by setting `focus_mode = 2` (FOCUS_ALL)** in the `.tscn`, or `sp.focus_mode = Control.FOCUS_ALL`
   on `SpinBox`es created in code (the templates dialog, the Offset/Rotation/Scale rows of Models).

> **Screens with columns:** the Tab cycle is by COLUMN — it walks all the controls of a column (from top
> to bottom) before moving to the next. Since `collect_focusables` follows the tree order (and the declared
> `tab_order`), it's enough for each column to be its own container in reading order.

**Conclusion:** if a **focusable** control appears without a number, the screen probably **doesn't wire the ring yet**.
Calling **`UINav.wire_tab_ring(self)`** wires `focus_next`/`focus_previous` into a **closed ring
`1 → 2 → … → N → 1`**, so `find_next_valid_focus()` passes through **all** of them and Debug 2D numbers **1..N
incrementing by 1**. (Labels/containers stay, correctly, at `TAB: -`.)

> To see the numbers: **developer** screen → turn on **Debug 2D** + the **Tab** line.

---

## `UINav` helpers (focus/keyboard)

| Helper | Signature | What it does |
|---|---|---|
| **`wire_tab_ring`** | `wire_tab_ring(root, last=null)` | **(new)** Wires Tab/Shift+Tab into a **closed ring** in reading order (tree order: top→bottom, and within an HBox left→right) via `collect_focusables`. `last` (optional) goes to the **END** of the ring (highest index) — e.g. the **×** of floating windows. **Idempotent**: re-call whenever the focusable set changes (injected toggle, language enabling/disabling, dynamic lists). |
| **`focus_tab_one`** | `focus_tab_one(root, last=null) → Control` | Focuses the **head of the ring** (Tab = 1). Used when **opening** the screen so the focus always starts on the 1st of the sequence. |
| **`tab_one_control`** | `tab_one_control(root, last=null) → Control` | Returns (without focusing) the **Tab = 1** control = `collect_focusables(root)` minus `last`, 1st item. |
| **`focus_first`** | `focus_first(root) → Control` | Focuses the **1st focusable** in tree order. Equivalent to `focus_tab_one` when there is no `last` moved — it is the **old** standard of the screens that don't wire the ring yet. |
| **`first_focusable`** | `first_focusable(node) → Control` | The 1st focusable `Control` (FOCUS_ALL, visible, a non-`disabled` `BaseButton`) in tree order. The base of `focus_first` and used by the **DebugOverlay** to find the start of the Tab chain. |
| **`collect_focusables`** | `collect_focusables(root) → Array[Control]` | **All** the focusables under `root` in tree order. The base of `wire_tab_ring`/`tab_one_control`. Ignores `is_queued_for_deletion()`. |
| **`cancel_active_edit`** | `cancel_active_edit(viewport, fallback=null) → bool` | **ESC rule**: if the focus is on a `LineEdit` (includes a `SpinBox`'s internal editor), it ends the edit and returns the focus to `fallback`, returning `true` (the caller consumes the ESC and does **not** go back a screen). Only the **2nd ESC** navigates back. |
| **`tab_order_of`** | `tab_order_of(ctrl) → int` | The declared `metadata/tab_order` value (1-based) or a large sentinel if absent. The base of `collect_focusables`'s ordering and of the Debug 2D Tab line (EXPECTED value). |
| **`collect_focusables_ignoring_visibility`** | `… → Array[Control]` | Scans a HIDDEN `TabContainer` tab: it ignores that the tab-root is hidden, but RESPECTS the control's OWN `.visible` flag (controls hidden on their own — e.g. MetalFX buttons on an unsupported OS — stay OUT, otherwise Tab would try to focus a hidden one and got stuck at the end of the tab). |
| **`collect_focus_order_with_tabs`** | `(scene_root, tab_container) → Array[Control]` | The GLOBAL focus order with each tab expanded in sequence (hidden ones included): before → tab 0 → … → tab N-1 → after. |
| **`tab_container_focus_step`** | `(scene_root, tab_container, forward) → bool` | One Tab/Shift+Tab step crossing the tabs (the TabContainer rule). Switches the visible tab when the target is in another tab. Called from the scene's `_input`. |

### Usage pattern in a screen (ready-to-copy)

```gdscript
func _ready() -> void:
    # ... fill fields, assemble dynamic options BEFORE wiring the ring ...
    UINav.focus_tab_one.call_deferred(self)            # focus on Tab = 1
    _wire_tab_order.call_deferred()                    # wire the ring (deferred)
    ($UI/Actions as HBoxContainer).child_entered_tree.connect(
        func(_n: Node) -> void: _wire_tab_order.call_deferred())  # re-wire when the Debug2D is injected

func _wire_tab_order() -> void:
    UINav.wire_tab_ring(self)

func _update_language_buttons() -> void:
    # ... sets disabled on the active language ...
    if is_node_ready():
        _wire_tab_order.call_deferred()                # the active language leaves the ring → re-wire

func _input(e: InputEvent) -> void:
    if e.is_action_pressed(&"quit"):
        if UINav.cancel_active_edit(get_viewport(), <fallback>):
            get_viewport().set_input_as_handled(); return
        get_viewport().set_input_as_handled()
        # ... go back a screen ...
```

### Matrix: which scene uses which `UINav` helper

| Scene / file | `wire_tab_ring` | `focus_tab_one` | `focus_first` | `tab_one_control` | `cancel_active_edit` |
|---|:---:|:---:|:---:|:---:|:---:|
| `menu` | ✅ | ✅ | — | — | ✅ |
| `playonline` | ✅ | ✅ | — | — | ✅ |
| `levels` | ✅ | ✅ | — | — | ✅ |
| `host_session` | ✅ (static scaffold; `tab_order` by code in `_rewire_tab`) | ✅ | — | — | — |
| `client_session` | ✅ (static scaffold; `tab_order` by code in `_rewire_tab`) | ✅ | — | — | — |
| `floating_window` | ✅ (`last=×`) | — | ✅ (on the parent when closing) | ✅ (`last=×`) | — |
| `chooseplayer` | ✅ | ✅ | — | — | ✅ |
| `settings` | — (uses `tab_container_focus_step`) | — (focuses the 1st of tab 0) | — | — | ✅ |
| `developer` | ✅ (+ sub-toggles) | ✅ | — | — | ✅ |
| `controls` | ✅ | ✅ | — | — | ✅ |
| `debug_overlay` (autoload) | — | — | — | — | — (uses `first_focusable`) |

> `collect_focusables` has no direct scene caller (it is internal to `wire_tab_ring`/`tab_one_control`).
> **Special re-wiring cases (2026-06-29):** `settings` **no longer** uses the ring — it handles Tab in
> `_input` crossing the tabs (see "TabContainer" above, 2026-06-30); `developer` re-wires on
> `_update_subrows_enabled` (the Debug 2D sub-toggles enter/leave the ring as the master turns on/off).

---

## Other shared project helpers

Reusable helpers (static or autoload) used by several scenes — not to be confused with the
**config stores** (`Settings`, `NetConfig`, `RoomManager`…), which hold state and are not "helpers".

| Helper | Signature / origin | Scenes that use it |
|---|---|---|
| **`FloatingDialog.confirm`** | `confirm(parent, title, text, ok="Sim", cancel="Não") → FloatingWindow` | menu, host_session, client_session, settings, models, crash_handler |
| **`FloatingDialog.alert`** | `alert(parent, title, text, ok="OK") → FloatingWindow` | client_session, crash_handler |
| **`FloatingWindow.style_close_button`** | `static` — styles the × button | models |
| **`FloatingWindow.pointer_over_any_window`** | `static → bool` — cursor over some floating window | models |
| **`FloatingWindow.wire_focus_ring`** | instance → delegates to `UINav.wire_tab_ring(self, _close_button)` | every floating window (× last) |
| **`Locale.tr_key`** | `tr_key(key) → String` (autoload [[🗣️ localizacao (EN)\|localizacao]]) | ~84 calls (all screens with dynamic text/OptionButton) |
| **`Locale.set_language` / `get_language` / `language_changed`** | changes/reads the language + signal | all screens with a language bar |
| **`CrashHandler.show_error`** | `show_error(msg, retry_callable)` (autoload) | playonline, level_1, level_2, models, player |
| **`DebugOverlay.refresh`** | rebuilds the 2D overlays | developer, settings, debug2d_toggle |

---

## Coverage and pending items

**(2026-06-29)** All the **full screens** now wire the ring: `menu`, `playonline`, `levels`,
`host_session`, `client_session`, `chooseplayer`, `settings`, `developer`, `controls` (+ `floating_window`
for windows). It is a **project rule** (see `CLAUDE.md`): every 2D scene wires `UINav.wire_tab_ring(self)` and
every interactive control must be focusable (no `TAB: -` on interaction controls).

Known pending item: **`pause_menu`** (a `Control` overlay, 3 buttons + 3 sliders) — with no `Actions` bar and
no `grab_focus`. It is a pause overlay (it doesn't change scenes); applying the ring there is optional/secondary.
