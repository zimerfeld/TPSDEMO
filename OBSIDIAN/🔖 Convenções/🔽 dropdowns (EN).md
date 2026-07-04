---
tipo: convencao
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🔽 Convention — Dropdowns (OptionButton)

> Every dropdown (`OptionButton`) in the game UI must start with a
> placeholder option called **"Select..."** as the **first item** and **default
> selection**.

## Rules

1. **First item = `"Select..."`** in every dropdown, inserted at index `0`
   and selected by default (`select(0)`) when building the screen. The real items
   start at index `1` — remember the offset when mapping back to the data
   (`data[index - 1]`).
2. **Dependent cascade.** When selecting `"Select..."` (index 0) in a
   combo, every combo that depends on its value must be **reloaded also with
   `"Select..."` selected**, and any screen behavior that depends on the
   selection (preview, status, window) must be **reset/cleared**.
3. **The screen starts blank.** Nothing is previewed/applied until the user
   walks the selection chain. Do not auto-select the first real item.
4. **Selection persistence + chain restoration.** Every dropdown choice
   is persisted (by a **stable** value — key/name/sentinel, not
   the index — together with the toggles). When reopening the screen, the chain is replayed from
   top to bottom: `select()` does not emit `item_selected`, so each step also calls
   the handler explicitly to populate the next combo. Stopping rule
   per level: an **empty** value (the user stopped there) → leaves the combo enabled on the
   placeholder, ready to continue (with everything empty = a normal blank start);
   a value that **doesn't exist today** (a saved choice that disappeared from the library, "no more
   data") → **disables that combo and the ones below it**. Never auto-selects an item.

## Node naming (2026-06-30)

Every `OptionButton` must have its **`Name` in the plural** (a project rule) — the dropdown represents a
**collection** of options. Renamed under this convention:

| Scene | Before → After |
|---|---|
| `controls.tscn` | `cboControl` → **`Controls`** (drops the `cbo` prefix) |
| `playonline.tscn` | `PortHistory` → **`PortHistories`** · `AddressHistory` → **`AddressHistories`** |
| `settings.tscn` | `VideoResolutionDropdown` → **`VideoResolutions`** (drops the `Dropdown` type suffix) |
| `models.tscn` | `Category`→`Categories` · ~~`Prefix`→`Prefixes`~~ (dropdown **removed** on 2026-06-30) · `EffectsList`→`EffectsLists` · `MemberGeo`→`MemberGeos` · `SubMemberGeo`→`SubMemberGeos` · `Skeleton`→`Skeletons` · `SkeletonGeo`→`SkeletonGeos` |

Already plural (no change): `Models`, `Meshes`, `Animations`, `Members`, `SubMembers`. The
`%Name` accessors in the `.gd` and the `from=` of the `.tscn` `[connection]` followed the name.

## Special cases

- **"Show all" filters** (e.g.: the old `"All"` of the extinct prefix dropdown in
  `models.gd` — the prefix dropdown itself was **removed** on 2026-06-30):
  replaced by `"Select..."`, which now means
  "no filter" (empty metadata). It still lists every item.
- **Own action options** (e.g.: `"Full model"` in the part dropdown in
  `models.gd`): **kept** as selectable items right below
  `"Select..."`. E.g. the part dropdown order: `Select...`,
  `Full model`, then each mesh.
- **Dropdowns that reflect saved state** (e.g.: video resolution in
  `settings.gd`): `"Select..."` is the default only when **there is no saved value**;
  if the saved one matches a preset, it selects the preset. Selecting `"Select..."`
  does not change the window (a no-op placeholder). The dropdown's **minimum width** is
  adjusted by code (`_fit_dropdown_to_widest_item`) to the **widest item text**
  (measured by the resolved font + stylebox margins + the arrow icon), so no
  item is truncated; `size_flags_horizontal` still expands above that.

## Where it applies today

- `scenes3D/models/models.gd` — the Category → Model → Part chain.
- `scenes2D/settings/settings.gd` — the video resolution dropdown.
- `scenes2D/controls/controls.gd` — the control dropdown.

## Links

- [[🏠 Home (EN)|Home]]
- [[🗿 biblioteca-de-modelos (EN)|Model Library]]
- [[📄 formatacao (EN)|File Formatting]]
