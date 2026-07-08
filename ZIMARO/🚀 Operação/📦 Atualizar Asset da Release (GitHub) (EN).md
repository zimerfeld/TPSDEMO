---
tipo: procedure
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-07
tags: [procedure, release, github, distribution]
---

# 📦 Update the Release Asset (GitHub)

> **Goal:** replace/update the `.exe` binary published on the releases page
> (`https://github.com/zimerfeld/ZIMARO/releases`) and make it visible to the public.

## ⚠️ Golden rule — the binary does NOT go through git

Release assets are **not** versioned in git. The ~167 MB `.exe` **must not be
committed/pushed** — GitHub rejects files **> 100 MB**. The binary is managed
**directly on the release** with `gh` (GitHub CLI). See `.gitignore`:
`build/windows/*.exe` is ignored on purpose.

## ⚡ TL;DR — the two commands

```powershell
cd C:/GODOT/ZIMARO
# 1) Replace the .exe (--clobber overwrites the asset with the same name)
gh release upload 202606251203 build/windows/ZIMARO.exe --clobber
# 2) Publish the release (while it's a draft, nobody can see it)
gh release edit 202606251203 --draft=false
```

## ⚙️ Step by step

1. **Replace the `.exe`** — `--clobber` overwrites the asset with the same name:
   ```powershell
   cd C:/GODOT/ZIMARO
   gh release upload 202606251203 build/windows/ZIMARO.exe --clobber
   ```
2. **Publish the release** so it shows on the public page (while it's a `draft`,
   only you, logged in, can see it):
   ```powershell
   gh release edit 202606251203 --draft=false
   ```

## 🧰 Handy related commands

- **Delete an old asset:** `gh release delete-asset 202606251203 ZIMARO.exe`
- **Open the release in the browser:** `gh release view 202606251203 --web`
- **Check state/assets:**
  `gh release view 202606251203 --json tagName,isDraft,assets`
- **List releases:** `gh release list`

## ➕ Create a new release (new tag)

When you want to **publish under a new tag** (instead of updating the same asset),
create a fresh release — the **title becomes the tag itself** (no "ZIMARO v0.1.0"):

```powershell
cd C:/GODOT/ZIMARO
# the tag must exist on the remote (if local, push it first):
git push origin refs/tags/202607072141
# title = the tag itself; --notes-file for the body (changelog)
gh release create 202607072141 build/windows/ZIMARO.exe --title "202607072141" --notes-file notes.md
```

- **Title = tag only:** pass `--title "<TAG>"` — avoids a descriptive/version name at the top.
- **Reuse a previous release's notes** without the version heading:
  ```powershell
  gh release view <OLD_TAG> --json body -q .body | Set-Content notes.md
  # remove the first "# ZIMARO vX.Y.Z" line from notes.md before using it
  ```
- Older releases can be **kept** — the newest becomes **Latest** automatically and is
  what the site's **Download** button (`/releases`) serves.

## 🛟 Notes

- **Current Latest release:** `202607072141` (title = tag only; EN/PT notes without
  "ZIMARO v0.1.0"). The previous `202606251203` was **kept** by choice. The `.exe` on
  the Latest is what the **Download** button on `zimaro.zimerfeld.com` links to (GitHub
  Pages served from `main`, points to `/releases`).
- If the `.exe` accidentally lands in git history (e.g. a "com exe" commit), **do not
  push it** — undo with `git reset --soft HEAD~1`, make sure `build/windows/*.exe` is in
  `.gitignore`, and unstage it (`git restore --staged`).

## 🔗 Links
- [[🚀 Build Windows (Prod) (EN)]] — build `build/windows/ZIMARO.exe` before publishing
- [[💻 Rodar no Editor (Dev) (EN)]] · [[🏠 Home (EN)]] · [[📌 Backlog (EN)]]
