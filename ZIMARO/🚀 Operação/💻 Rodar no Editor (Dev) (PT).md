---
tipo: procedimento
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 💻 Rodar no Editor (Dev)

> **Objetivo:** rodar e desenvolver o ZIMARO localmente pelo editor Godot — incluindo o
> teste multiplayer em loopback com 2 instâncias no mesmo PC (sem rede real).

## ⚡ TL;DR

Abrir o projeto `C:\GODOT\ZIMARO` no **Godot 4.6.2**
(`C:\GODOT\Godot_v4.6.2-stable_win64.exe\…`) e **rodar o projeto** (F5). A cena principal é a
`main` ([[🧭 main-gd (PT)|🧭 main-gd]], roteador), que abre o **menu** — ver [[🎬 fluxo-de-cenas (PT)|🎬 fluxo-de-cenas]].

## ⚙️ Passo a passo

1. **Encerrar** qualquer instância do jogo em execução **e** o editor Godot antes de mexer no
   código (regra do projeto — ver `CLAUDE.md`; há hooks em `.claude/settings.json` que fecham o
   `ZIMARO.exe` automaticamente a cada prompt).
2. Abrir o projeto no editor Godot 4.6.2 e rodar (F5). Navegação: menu → chooseplayer → levels →
   level_1/level_2 · settings · developer → models ([[🎬 fluxo-de-cenas (PT)|🎬 fluxo-de-cenas]]).
3. **Multiplayer em loopback (2 instâncias no MESMO PC)** — protocolo completo em
   [[🧪 teste-salas-multiplayer (PT)|🧪 teste-salas-multiplayer]] (Teste A, ✅ validado em campo 2026-07-02):
   - Abrir **duas** janelas do jogo (o `.exe` de `build/windows/ZIMARO.exe` ou **duas execuções
     pelo editor**). Janela 1 = HOST, Janela 2 = CLIENTE.
   - **[HOST]** Menu → **Jogar Online** → Porta `4383` → **"Gerenciar Salas"** → escolher Level →
     **"Iniciar Sala"**.
   - **[CLIENTE]** Menu → **Jogar Online** → IP `127.0.0.1`, Porta `4383` → **"Entrar em Salas"** →
     **Jogar**.
   - Se falhar: rodar **pelo editor** para ver o console (`push_error`/RPC).
4. Validação sem janela (usada nas sessões): o Godot **headless** roda o jogo por ~300 frames para
   caçar erros de script/runtime — os avisos `ObjectDB leaked` / `resources still in use` no
   encerramento forçado (`--quit-after`) são benignos.

## 📏 Regras que respeita

- **Nunca commitar/publicar** — deixar para o usuário revisar (GitFlow; branch ativa em [[📌 Backlog (PT)|📌 Backlog]]).
- Ao fim de tarefa com impacto no usuário: atualizar READMEs + cofre e rodar o build de produção
  ([[🚀 Build Windows (Prod) (PT)|🚀 Build Windows (Prod)]]); zerar erros/warnings.

## 🛟 Troubleshooting

- **Arquivo travado / "Failed to rename temporary file":** alguma instância do jogo ficou aberta —
  encerrar o `ZIMARO.exe` (os hooks do projeto fazem isso automaticamente).
- **Tela cinza no cliente ao entrar na sala:** template/scene-cache — ver [[🚪 salas (PT)|🚪 salas]] ("salas
  nascem limpas"); mais sintomas na tabela do [[🧪 teste-salas-multiplayer (PT)|🧪 teste-salas-multiplayer]].

## 🔗 Ligações
- [[🚀 Build Windows (Prod) (PT)|🚀 Build Windows (Prod)]] — gerar o `.exe` de produção
- [[🧪 teste-salas-multiplayer (PT)|🧪 teste-salas-multiplayer]] · [[🚪 salas (PT)|🚪 salas]] · [[🌐 multiplayer (PT)|🌐 multiplayer]] · [[🎬 fluxo-de-cenas (PT)|🎬 fluxo-de-cenas]]
- [[🏠 Home (PT)|🏠 Home]] · [[📌 Backlog (PT)|📌 Backlog]]
