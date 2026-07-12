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

## 🛟 Notas

- **Tag actual:** `202606251203`. El `.exe` publicado es a lo que enlaza el botón **Download**
  de `zimaro.zimerfeld.com` (GitHub Pages servido desde `main`).
- Si el `.exe` acaba accidentalmente en el historial de git (p. ej. un commit "com exe"), **no lo
  subas** — deshazlo con `git reset --soft HEAD~1`, asegúrate de que `build/windows/*.exe` esté en
  `.gitignore`, y sácalo del stage (`git restore --staged`).

## 🔗 Enlaces
- [[🚀 Build Windows (Prod) (ES)]] — construir `build/windows/ZIMARO.exe` antes de publicar
- [[💻 Rodar no Editor (Dev) (ES)]] · [[🏠 Home (ES)]] · [[📌 Backlog (ES)]]
