---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🗣️ System — Localization (EN/PT)

UI language switch between **Português** and **English**, via the **Locale** autoload
(`autoload/locale.gd`).

## Per-scene dictionaries

Each scene has its **own pair** of flat JSONs in a `Resources/` folder next to the `.tscn`:
`scenes2D/menu/Resources/menu.pt.json` + `menu.en.json`, `scenes2D/settings/Resources/settings.pt.json`
+ `...en.json`, `scenes3D/models/Resources/models.pt.json` + `...en.json`, etc. Each pair maps the
canonical (authored) text of each Button/Label to that language's text and has the **same set of keys**
in both languages.

On startup the Locale **scans recursively** `scenes2D/` and `scenes3D/` (`SCAN_ROOTS`), finds
every `*.pt.json` / `*.en.json` and **merges** them all into a per-language table. To add the
`Resources/` dictionaries of a new screen you just drop them in — no need to edit the autoload. (There is no longer a `pt.json`/`en.json` at the
project root.)

## Persistence and application

- The choice is saved in `Settings` → `game/language` (`"pt"` default / `"en"`).
- In `_ready`, the Locale reads the persisted language, builds the table and **connects to `node_added`**: every
  Button/Label that enters the tree has its `text` translated automatically. `OptionButton`/`MenuButton`
  are **ignored** (text = live selection).
- The first time it sees a node, it stores the original text in meta (`_loc_src`); language switches translate
  from that original (not from the already-translated text).
- `set_language(lang)` persists, rebuilds the table and **re-localizes the live tree** (emits
  `language_changed`).

## Language buttons — on ALL screens

The `UI/LangBar` (HBox in the bottom-right corner with "Português" / "English" buttons, same pattern as the
menu) is present in **menu, chooseplayer, settings, developer, levels, playonline, controls and models**.
Each script calls `Locale.set_language(...)` and grays out the active language button
(`_update_language_buttons`). Because the re-localization is in-place, the screen updates immediately.
**Alignment (2026-06-25):** the `LangBar` sits on the **same vertical band as the "Back" button** (footer
offsets `−100`/`−50`) on all these screens.

## Texts coming from code (SKIP_GROUP)

Texts the automatic localizer can't reach — placeholders/items of `OptionButton`, the titles
of the settings tabs, confirmation dialogs, and the **PerformanceHUD**/**StabilityGuard** overlay —
enter the `Locale.SKIP_GROUP` group and re-apply `Locale.tr_key(...)` themselves on the
`language_changed` signal. The HUD/Guard keys live in `scenes2D/overlays/Resources/overlays.{pt,en}.json`.
(The screens
`models` and `controls` **no longer have** a `StatusLabel` — removed on 2026-06-18.)

The **`Label3D` prefixes** of the Models scene (`Membro:`/`Sub-membro:`/`Esqueleto:`/`Tipo:`/`Nome:`)
are also not reached by the auto-translator: they go through `Locale.tr_key` and are rebuilt on
`language_changed` (`_refresh_member_overlays`/`_refresh_aux_labels`) — see [[🗿 biblioteca-de-modelos (EN)|Model Library]].

The **column titles of the `Tree`** in the **Damage** window (`Membro`/`Def`/`Bônus %`/`Dono`) are another
case: `set_column_title` is not a `Label`/`Button`, so the auto-translator can't reach it. Since 2026-06-27,
`_apply_damage_tree_titles()` re-applies them via `Locale.tr_key` on tree construction AND on
`language_changed` (before, they were stuck in the language of the last construction) — see [[🩸 dano-localizado (EN)|Localized Damage]].

## Rule — changed a text, update the keys

**Whenever you change or add a UI text in a scene, update the matching key in
`Resources/<scene>.pt.json` AND `Resources/<scene>.en.json` of that scene, in the same task.** Because the
Locale indexes by the source text, changing the scene without updating the key breaks the translation. PT gets the
Portuguese translation; EN, the English one. Validate both JSONs at the end.

Related: [[🎬 fluxo-de-cenas (EN)|Scene Flow]], [[🐞 debug-overlay (EN)|Debug Overlay]], [[⚡ performance-hud (EN)|Performance HUD]],
[[🧭 main-gd (EN)|main.gd]].
