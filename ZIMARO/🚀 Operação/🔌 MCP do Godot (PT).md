---
tipo: procedimento
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-23
---

# 🔌 MCP do Godot (Claude Code)

> **Objetivo:** ligar o Claude Code ao **editor Godot vivo** via MCP — rodar o jogo, ler o console
> e inspecionar cenas direto do prompt — e registrar os comandos **headless** usados para reimportar
> assets e validar código sem abrir o editor.

## ⚡ TL;DR

O MCP vem do addon de TERCEIROS **`addons/godot_ai/`** ([hi-godot/godot-ai](https://github.com/hi-godot/godot-ai)),
que já está no repositório. Ativar em **Project → Project Settings → Plugins → Godot AI** e, no dock
**Godot AI**, escolher o cliente e clicar **Configure**. O plugin sobe o servidor sozinho (WebSocket).

## ⚙️ Passo a passo (ativar)

1. **Requisitos:** Godot 4.3+ (o projeto usa **4.6.2**), o instalador Python
   [`uv`](https://docs.astral.sh/uv/) e um cliente MCP (Claude Code).
   - Instalar o `uv` no Windows: `powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"`
2. O addon já está em `addons/godot_ai/` — se faltar, copiar para a pasta `addons/` do projeto.
3. Ativar o plugin: **Project → Project Settings → Plugins → Godot AI**.
4. No dock **Godot AI**, selecionar o cliente MCP e apertar **Configure**. Não há configuração manual.
5. Conferir: o Claude passa a expor ferramentas `godot` (rodar projeto, parar, ler console, versão…).

## 🧰 O que dá para fazer pelo MCP

| Ferramenta | Uso |
|---|---|
| `run_project` | roda o jogo (opcionalmente uma cena específica) |
| `stop_project` | encerra a execução |
| `get_debug_output` | lê console e **erros** de runtime |
| `launch_editor` · `get_godot_version` · `get_project_info` | abrir editor / inspecionar projeto |

## 🖥️ Headless (sem editor) — o que mais se usa

Executável numa pasta homônima: `C:\GODOT\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe`

- **Reimportar assets** (depois de trocar um `.glb`) — é o jeito CERTO, ver [[🗿 biblioteca-de-modelos (PT)|🗿 biblioteca-de-modelos]]:
  `--headless --path C:\GODOT\ZIMARO --import`
- **Validar código/medir desempenho** com um script temporário `res://_test_x.gd` (`extends SceneTree`):
  `--headless --path C:\GODOT\ZIMARO --script res://_test_x.gd`
  Apagar o script ao terminar (regra de faxina).

## 📏 Regras que respeita

- **Encerrar o jogo e o editor Godot** antes de mexer no código (regra do projeto; há hooks em
  `.claude/settings.json`). Ver [[💻 Rodar no Editor (Dev) (PT)|💻 Rodar no Editor (Dev)]].
- **Nunca commitar/publicar** — deixar para o usuário revisar.

## 🛟 Troubleshooting

- **`No active Godot process`** ao parar/ler console: nada está rodando — usar `run_project` antes.
- **ESC não sai da tela (Models/outra):** a cena foi aberta **isolada** (`run_project` com `scene:`).
  A troca de tela é feita pelo sinal `replace_main_scene`, que só o **`main.tscn`** escuta
  ([[🧭 main-gd (PT)|🧭 main-gd]]) — rodar o projeto **sem** especificar cena e navegar pelo menu.
- **`.import` inchado / textura sumida** depois de reimportar: foi o **editor** reimportando.
  Usar sempre `--headless --import` e não matar o Godot no meio da importação — ver
  [[🗿 biblioteca-de-modelos (PT)|🗿 biblioteca-de-modelos]].
- **Falso-negativo em teste headless:** `set_bone_pose_rotation` **não** altera
  `get_bone_global_pose` sem um frame real (o `Skeleton3D` não recalcula) — validar pose/animação
  com o jogo rodando, não em headless.

## 🔗 Ligações
- [[💻 Rodar no Editor (Dev) (PT)|💻 Rodar no Editor (Dev)]] — rodar/desenvolver pelo editor
- [[🚀 Build Windows (Prod) (PT)|🚀 Build Windows (Prod)]] — gerar o `.exe` de produção
- [[🏠 Home (PT)|🏠 Home]] · [[📌 Backlog (PT)|📌 Backlog]]
