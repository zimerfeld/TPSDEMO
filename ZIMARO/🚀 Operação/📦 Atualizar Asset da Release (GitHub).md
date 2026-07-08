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

## ➕ Criar uma nova release (nova tag)

Quando quiser **publicar sob uma nova tag** (em vez de atualizar o asset da mesma),
crie uma release nova — o **título fica sendo a própria tag** (sem "ZIMARO v0.1.0"):

```powershell
cd C:/GODOT/ZIMARO
# a tag precisa existir no remoto (se for local, enviar antes):
git push origin refs/tags/202607072141
# título = a própria tag; --notes-file para o corpo (changelog)
gh release create 202607072141 build/windows/ZIMARO.exe --title "202607072141" --notes-file notas.md
```

- **Título só com a tag:** passe `--title "<TAG>"` — evita o nome descritivo/versão no topo.
- **Reaproveitar as notas de uma release anterior** sem o cabeçalho de versão:
  ```powershell
  gh release view <TAG_ANTIGA> --json body -q .body | Set-Content notas.md
  # remova a 1ª linha "# ZIMARO vX.Y.Z" do notas.md antes de usar
  ```
- Releases antigas podem ser **mantidas** — a mais nova vira **Latest** automaticamente e
  é a que o botão **Download** do site (`/releases`) passa a servir.

## 🛟 Notas

- **Release Latest atual:** `202607072141` (título = só a tag; notas EN/PT sem
  "ZIMARO v0.1.0"). A anterior `202606251203` foi **mantida** por opção. O `.exe`
  publicado na Latest é lido pelo botão **Download** do site `zimaro.zimerfeld.com`
  (GitHub Pages a partir de `main`, aponta para `/releases`).
- Se por engano o `.exe` entrar no histórico do git (ex.: um commit "com exe"), **não
  envie** — desfaça com `git reset --soft HEAD~1`, garanta `build/windows/*.exe` no
  `.gitignore` e retire-o do staging (`git restore --staged`).

## 🔗 Ligações
- [[🚀 Build Windows (Prod)]] — gerar o `build/windows/ZIMARO.exe` antes de publicar
- [[💻 Rodar no Editor (Dev)]] · [[🏠 Home]] · [[📌 Backlog]]
