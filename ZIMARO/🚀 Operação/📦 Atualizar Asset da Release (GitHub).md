---
tipo: procedimento
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-07
tags: [procedimento, release, github, distribuicao]
---

# 📦 Atualizar Asset da Release (GitHub)

> **Objetivo:** trocar/atualizar o binário `.exe` publicado na página de releases
> (`https://github.com/zimerfeld/ZIMARO/releases`) e deixá-lo visível ao público.

## ⚠️ Regra de ouro — binário NÃO vai pelo git

Assets de release **não** são versionados no git. O `.exe` de ~167 MB **não pode ser
commitado/enviado** — o GitHub rejeita arquivos **> 100 MB**. O binário é gerenciado
**direto na release** com o `gh` (GitHub CLI). Ver `.gitignore`: `build/windows/*.exe`
é ignorado de propósito.

## ⚡ TL;DR — os dois comandos

```powershell
cd C:/GODOT/ZIMARO
# 1) Substituir o .exe (--clobber sobrescreve o asset de mesmo nome)
gh release upload 202606251203 build/windows/ZIMARO.exe --clobber
# 2) Publicar a release (enquanto for draft, ninguém a vê)
gh release edit 202606251203 --draft=false
```

## ⚙️ Passo a passo

1. **Substituir o `.exe`** — `--clobber` sobrescreve o asset de mesmo nome:
   ```powershell
   cd C:/GODOT/ZIMARO
   gh release upload 202606251203 build/windows/ZIMARO.exe --clobber
   ```
2. **Publicar a release** para ela aparecer na página pública (enquanto for `draft`,
   só você, logado, a vê):
   ```powershell
   gh release edit 202606251203 --draft=false
   ```

## 🧰 Comandos úteis relacionados

- **Remover um asset antigo:** `gh release delete-asset 202606251203 ZIMARO.exe`
- **Ver a release no navegador:** `gh release view 202606251203 --web`
- **Conferir estado/assets:**
  `gh release view 202606251203 --json tagName,isDraft,assets`
- **Listar releases:** `gh release list`

## 🛟 Notas

- **Tag atual:** `202606251203`. O `.exe` publicado é lido pelo botão **Download** do
  site `zimaro.zimerfeld.com` (GitHub Pages a partir de `main`).
- Se por engano o `.exe` entrar no histórico do git (ex.: um commit "com exe"), **não
  envie** — desfaça com `git reset --soft HEAD~1`, garanta `build/windows/*.exe` no
  `.gitignore` e retire-o do staging (`git restore --staged`).

## 🔗 Ligações
- [[🚀 Build Windows (Prod)]] — gerar o `build/windows/ZIMARO.exe` antes de publicar
- [[💻 Rodar no Editor (Dev)]] · [[🏠 Home]] · [[📌 Backlog]]
