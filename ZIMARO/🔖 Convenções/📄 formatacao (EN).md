---
tipo: convencao
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 📄 Convention — File formatting

> Always apply the correct formatting before committing and at the end of each task.

## Rules (enforced by `file_format.sh`)

- Encoding **UTF-8 without BOM**
- **LF** (Unix) line endings
- **No** trailing whitespace at the end of lines
- **Final newline** at the end of the file

## How to apply

At the repository root (`C:\GODOT\ZIMARO`), via **Git Bash** on Windows:

```bash
bash file_format.sh
```

Dependencies: `dos2unix` and `perl` (`recode` is optional — the files are already UTF-8).

## Why it matters

- A **BOM** (`EF BB BF`) at the start of a `.tscn`/`.tres` makes the Godot parser
  fail with `Parse Error: Expected '['`, breaking the scene load.
  That was exactly what prevented `level_base` from loading (a level later **removed**
  on 2026-07-01) — the fix was to remove the BOM from 12 files.

## Related convention — UID cache

When **moving/renaming** scenes or resources:

1. Update all `res://...` references (including those inside `.tscn`/`.tres`/`.import`).
2. Reopen the project in the **Godot editor** once to rebuild the
   `.godot/uid_cache.bin` and reimport the moved assets. This clears the
   `invalid UID … using text path instead` warnings.

Binary files (`.mesh`, `.glb`) may contain embedded paths that are **not**
fixed by text editing — in those cases you need to reimport/re-export
from the `.blend` or reassign the resource in the editor.

## Links

- [[🏠 Home (EN)|Home]]
