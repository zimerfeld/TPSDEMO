# Templates de Level (Gerenciador de Templates)

> Composição de spawn por level: personagens/estruturas, facção, quantidade e posicionamento,
> editados em jogo numa janela flutuante e aplicados quando o level inicia (solo ou sala online).
> Relacionado: [[fluxos/fluxo-de-cenas]] (tela `levels`), [[sistemas/salas]] (host abre a mesma
> janela), memória *"salas nascem limpas"* (inimigos vêm SÓ de template).

## Arquitetura

- **`LevelTemplateManager`** (`autoload/level_template_manager.gd`): persiste em
  `user://level_templates.json` (`{templates: [...], active_by_level: {level_path: id}}`).
  API: `upsert_template(t) -> id`, `remove_template(id)`, `set_active_template(level, id)`,
  `active_template(level)`, `apply_active_template(level, spawned_nodes)`, `model_options(kind)`.
  Sem template salvo, `_install_defaults()` instala o exemplo "Level 2 - Caça aérea".
- **`LevelTemplateDialog`** (`scenes2D/level_templates/level_template_dialog.gd`): controlador do
  formulário DENTRO de uma `FloatingWindow` (CanvasLayer 128) — tema 2D + Debug 2D funcionam.
  Aberto pelo botão de template de cada linha da tela `levels` e pela `host_session`.
- **Entrada** de template: `kind` (character/structure), `model_key`/`scene_path`, `faction`
  (friendly/enemy/neutral), `count`, `placement` (coordinates/random/formation) + campos de cada
  modo, `name` (rótulo custom no EntryPicker), `rotation_y`, `spacing`.
- **Aplicação**: `level_1.gd`/`level_2.gd` chamam `apply_active_template` no `_ready` (offline) e o
  `RoomManager` na criação da sala (online). Facção friendly → player `bot_controlled` (bots de
  cobertura); enemy → IA hostil.
- `model_options` varre `library3D/characters` e `library3D/structures` recursivamente; só entra a
  cena cujo basename == nome da pasta (a cena "do modelo"; irmãs como `bomb.tscn` ficam fora).

## Bugs corrigidos em 2026-07-03 (encontrados em playtest no .exe)

1. **Dropdown Modelo VAZIO no .exe exportado** — `_collect_scene_options` filtrava
   `file.ends_with(".tscn")`, mas no export os arquivos aparecem no `DirAccess` como
   `*.tscn.remap` → nenhum modelo listado e era impossível montar template válido no build.
   **Fix:** helper `_logical_name` (strip de `.remap`/`.import`), mesmo padrão da tela Models
   (`models.gd`). ⚠️ Lição geral: **todo scan de `DirAccess` por extensão precisa do
   `_logical_name`** — o editor NÃO reproduz esse estado, só o build exportado.
2. **"Salvar e Usar Neste Level" não ativava template NOVO** — `_normalize_template` duplica o
   dicionário, então o id gerado no `upsert_template` ficava só na cópia; o `_template` local
   mantinha `id=""` → `set_active_template(level, "")` ERASE do ativo (linha voltava a
   "Templates: padrão") e cada Save re-append (duplicatas). **Fix:** `_save_template` agora faz
   `_template["id"] = LevelTemplateManager.upsert_template(_template)`.
3. **Nome digitado se perdia** — digitar o Nome e clicar "Adicionar/Remover Entrada" fazia
   `_refresh_template_fields` re-ler `_template["name"]` antigo (o campo só era lido no Save).
   **Fix:** `_name_edit.text_changed` grava direto em `_template["name"]` (igual ao campo
   "Nome da entrada").

## Comportamentos observados (por design)

- `remove_template("")` é no-op — "Remover" sobre um template ainda não salvo não afeta a lista.
- Dois templates podem ter o **mesmo nome** (o vínculo é por id) — ex.: dois "Novo template" na
  lista confundem; ideia de polimento: sufixo automático ("Novo template 2").
- `model_options` lista TODA cena nomeada como a pasta — inclusive `bullet`, `impact_effect`
  (efeitos/projéteis aparecem como "modelos" escolhíveis). Ideia de polimento: filtrar pastas de
  suporte ou marcar categorias spawnáveis.

## Validação em campo (2026-07-03, .exe rebuildado)

Fluxo completo no build: Levels → Gerenciador → template **"Arena Fable"** (Red Robot × 3,
enemy, random) → "Salvar e Usar Neste Level" → linha mostra "Template: Arena Fable" → Level 1
solo spawna os 3 red robots, que engajam (dano no player, morte e respawn OK) a 59–61 FPS.
