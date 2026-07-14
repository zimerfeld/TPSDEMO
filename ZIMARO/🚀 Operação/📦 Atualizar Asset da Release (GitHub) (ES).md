---
tipo: procedure
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-07
tags: [procedure, release, github, distribution]
---

# 📦 Actualizar el Asset de la Release (GitHub)

> **Objetivo:** reemplazar/actualizar el binario `.exe` publicado en la página de releases
> (`https://github.com/zimerfeld/ZIMARO/releases`) y hacerlo visible al público.

## ⚠️ Regla de oro — el binario NO pasa por git

Los assets de la release **no** se versionan en git. El `.exe` de ~167 MB **no debe
subirse con commit/push** — GitHub rechaza archivos **> 100 MB**. El binario se gestiona
**directamente en la release** con `gh` (GitHub CLI). Ver `.gitignore`:
`build/windows/*.exe` se ignora a propósito.

## ⚡ TL;DR — los dos comandos

```powershell
cd C:/GODOT/ZIMARO
# 1) Reemplaza el .exe (--clobber sobrescribe el asset con el mismo nombre)
gh release upload 202606251203 build/windows/ZIMARO.exe --clobber
# 2) Publica la release (mientras es un borrador, nadie puede verla)
gh release edit 202606251203 --draft=false
```

## ⚙️ Paso a paso

1. **Reemplaza el `.exe`** — `--clobber` sobrescribe el asset con el mismo nombre:
   ```powershell
   cd C:/GODOT/ZIMARO
   gh release upload 202606251203 build/windows/ZIMARO.exe --clobber
   ```
2. **Publica la release** para que aparezca en la página pública (mientras es un `draft`,
   solo tú, con sesión iniciada, puedes verla):
   ```powershell
   gh release edit 202606251203 --draft=false
   ```

## 🧰 Comandos relacionados útiles

- **Eliminar un asset antiguo:** `gh release delete-asset 202606251203 ZIMARO.exe`
- **Abrir la release en el navegador:** `gh release view 202606251203 --web`
- **Comprobar estado/assets:**
  `gh release view 202606251203 --json tagName,isDraft,assets`
- **Listar releases:** `gh release list`

## ➕ Crear una nueva release (nuevo tag)

Cuando quieras **publicar bajo un nuevo tag** (en lugar de actualizar el mismo asset),
crea una release nueva — el **título pasa a ser el propio tag** (sin "ZIMARO v0.1.0"):

```powershell
cd C:/GODOT/ZIMARO
# el tag debe existir en el remoto (si es local, súbelo antes):
git push origin refs/tags/202607072141
# título = el propio tag; --notes-file para el cuerpo (changelog)
gh release create 202607072141 build/windows/ZIMARO.exe --title "202607072141" --notes-file notas.md
```

- **Título solo con el tag:** pasa `--title "<TAG>"` — evita un nombre descriptivo/versión arriba.
- **Reutilizar las notas de una release anterior** sin el encabezado de versión:
  ```powershell
  gh release view <TAG_ANTIGUO> --json body -q .body | Set-Content notas.md
  # elimina la primera línea "# ZIMARO vX.Y.Z" de notas.md antes de usarla
  ```
- Las releases antiguas se pueden **mantener** — la más nueva pasa a ser **Latest** automáticamente y
  es la que sirve el botón **Download** del sitio (`/releases`).

## 🛟 Notas

- **Release Latest actual:** `202607072141` (título = solo el tag; notas EN/PT/ES sin
  "ZIMARO v0.1.0"). La anterior `202606251203` se **mantuvo** por decisión. El `.exe` de la
  Latest es a lo que enlaza el botón **Download** en `zimaro.zimerfeld.com` (GitHub Pages
  servido desde `main`, apunta a `/releases`).
- Si el `.exe` acaba accidentalmente en el historial de git (p. ej. un commit "com exe"), **no lo
  subas** — deshazlo con `git reset --soft HEAD~1`, asegúrate de que `build/windows/*.exe` esté en
  `.gitignore`, y sácalo del stage (`git restore --staged`).

## 🔗 Enlaces
- [[🚀 Build Windows (Prod) (ES)]] — construir `build/windows/ZIMARO.exe` antes de publicar
- [[💻 Rodar no Editor (Dev) (ES)]] · [[🏠 Home (ES)]] · [[📌 Backlog (ES)]]
