---
tipo: procedimento
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 🚀 Build Windows (Prod)

> **Objetivo:** gerar o build de "produção" do ZIMARO — um `.exe` Windows autocontido
> (**PCK embutido**) + atalho no Desktop, via o script `build_windows.ps1` na raiz do projeto.
> Rodar ao fim de cada tarefa que muda código/assets.

## ⚡ TL;DR — o comando único

```powershell
pwsh -File build_windows.ps1
```

> `-Force` builda sempre (ignora o skip "sem mudanças"): `pwsh -File build_windows.ps1 -Force`.

## ⚙️ O que o script faz (em ordem)

1. **Exporta** `build/windows/ZIMARO.exe` (release, **PCK embutido** → arquivo único de ~589 MB)
   pela CLI headless do Godot 4.6.2 (`godot --headless --export-release "Windows Desktop"`), usando
   o preset em `export_presets.cfg` (preset `Windows Desktop`, `binary_format/embed_pck=true`,
   arquitetura `x86_64`).
2. **Ícone** `build/icon.ico` — gerado só na 1ª vez: rasteriza `res://icon.svg` via um script tool
   Godot headless temporário (`Texture2D.get_image().save_png`) e converte para `.ico` multi-tamanho
   com Python 3 + Pillow. Depois é reusado (apague o arquivo para regerar).
3. **Atalho** `ZIMARO.lnk` no Desktop (via `WScript.Shell`), apontando para o `.exe`, com
   `IconLocation = build/icon.ico`.

## 🛟 Notas, regras e troubleshooting

- **Pré-requisitos:** Godot 4.6.2 em `C:\GODOT\Godot_v4.6.2-stable_win64.exe\…` + export templates
  4.6.2 instalados. O `.ico` (1ª geração) precisa de Python 3 com Pillow.
- ⚠️ **Cache de export com cena VELHA (2026-07-03):** o export reaproveita cenas convertidas do
  cache `.godot/exported/`, que **não invalida quando um `.tscn` muda** — o exe saía com a cena
  DESATUALIZADA mesmo com `-Force` (tela `levels` rebuildada mostrando o layout antigo).
  **Correção definitiva no próprio script:** o `build_windows.ps1` agora apaga
  `.godot/exported/` **antes de todo export** (custo: re-converter as cenas, segundos). Sintoma
  residual em investigações: validar SEMPRE a mudança visual no build. Atenção também a
  **corridas de regravação** (hook de formatação/editor externo com o arquivo aberto) — se o exe
  sair "um edit atrás", conferir os `LastWriteTime` dos fontes × exe antes de suspeitar do código.
- O **ícone NÃO é embutido no .exe** (faltaria o `rcedit`, um binário externo não instalado) — fica
  só no atalho. Instalar/configurar `rcedit` no editor permitiria embutir no próprio executável.
- **Auto-encerra instância aberta antes de exportar (2026-06-21):** `Stop-RunningZimaro` mata
  qualquer processo cujo **caminho** == `build/windows/ZIMARO.exe` (não só pelo nome) e apaga um
  `.tmp` órfão, logo antes do export — senão a janela aberta trava o arquivo e o Godot falha com
  *"Failed to rename temporary file … ZIMARO.tmp"*. Roda **só quando vai realmente buildar** (depois
  do skip "sem mudanças"), então não fecha o jogo em turnos sem alteração de fonte.
- **Boot splash sem logo do Godot (2026-06-21):** `project.godot` → `[application]`
  `boot_splash/show_image=false` (tira a imagem/logo), `boot_splash/bg_color=Color(0,0,0,1)` (fundo
  preto) e `boot_splash/minimum_display_time=0`. A janela abre escura até o menu — sem marca-d'água
  da engine. (No export Windows o splash NÃO some por completo; isto é o mais "mascarado" possível
  sem build custom.)
- `build/` e `export_presets.cfg` são **ignorados pelo git** (ver `.gitignore`); ficam locais.
- **Skip se nada mudou:** sem `-Force`, o script compara a data do `.exe` com a do arquivo-fonte
  mais novo (ignora `.godot/`, `build/`, `.git/`, `ZIMARO/`, `.md`, `.ps1`) e **sai na hora** se o
  `.exe` já está em dia. `pwsh -File build_windows.ps1 -Force` builda sempre.
- **Automatizado por hook (2026-06-21):** há um hook **`Stop`** em `.claude/settings.json` (hooks só
  deste projeto; `pwsh … build_windows.ps1`, `async`, `timeout 180`) — roda ao fim de **todo turno**
  do Claude Code, mas graças ao skip-se-nada-mudou só exporta de fato quando algum fonte mudou.
  Visualizar/editar: o próprio arquivo `.claude/settings.json`, ou `/hooks` num terminal `claude`
  interativo. Ver memória `build-exe-at-end-of-tasks`.
- **Hook `UserPromptSubmit` que fecha o ZIMARO (2026-06-21):** também em `.claude/settings.json`, roda
  a **cada prompt do chat** (antes do Claude processar o pedido) o comando PowerShell
  `Get-Process ZIMARO -ErrorAction SilentlyContinue | Stop-Process -Force …; exit 0` — encerra qualquer
  instância aberta do jogo para liberar locks de arquivo antes do trabalho/build. O `exit 0` evita que
  o hook reporte erro quando nada está rodando. Redundante (de propósito) com o `Stop-RunningZimaro` do
  build, que cobre o instante do export.

## 🔗 Ligações
- [[💻 Rodar no Editor (Dev)]] — rodar/desenvolver localmente antes do build
- [[📦 Atualizar Asset da Release (GitHub)]] — publicar o `.exe` gerado na página de releases
- [[🧱 recursos-nativos-godot]] · [[🎬 fluxo-de-cenas]]
- [[🏠 Home]] · [[📌 Backlog]]
