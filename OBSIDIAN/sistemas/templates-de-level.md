# Templates de Level (Gerenciador de Templates + Gerenciador de Cenários)

> Composição de spawn por level: personagens (Templates) e objetos de cenário (Cenários), com
> facção, quantidade e posicionamento, editados em jogo numa janela flutuante e aplicados quando
> o level inicia (solo ou sala online). Relacionado: [[fluxos/fluxo-de-cenas]] (tela `levels`),
> [[sistemas/salas]] (host abre a mesma janela), memória *"salas nascem limpas"*.

## Duas categorias, um só diálogo (2026-07-03)

O `LevelTemplateDialog` é parametrizado por **categoria** via `configure()`: **"spawn"**
(Gerenciador de Templates — personagens, raiz `library3D/characters`, com linha Facção) e
**"scenery"** (Gerenciador de Cenários — objetos de palco, raiz `library3D/sceneries`, SEM linha
Facção). Cada level tem na tela `levels` DOIS botões à direita (Template + Cenário), e cada
categoria tem **ativo próprio por level** (`active_by_level` × `active_scenery_by_level` no
mesmo JSON) — um level roda um template de personagens E um cenário ao mesmo tempo
(`apply_active_template` aplica os dois, no solo e nas salas online).

## Navegação em CASCATA do modelo (2026-07-03)

O antigo dropdown único "Modelo" (lista achatada com poluição de bullet/impact_effect) virou uma
**cascata de OptionButtons**: um dropdown por nível de pasta a partir da raiz da categoria —
ex.: `[enemies] → [red_robot]` — descendo só por subpastas que CONTÊM um modelo em alguma
profundidade (`browse_dir`/`_dir_model`/`_dir_has_models` no manager). Ao alcançar uma
pasta-modelo (cena com o nome da pasta), os **campos referentes** da entrada são mapeados
(`model_key` + `scene_path`) e o rótulo abaixo mostra "Modelo: X (x.tscn)". Navegar sem concluir
NÃO apaga o modelo salvo da entrada. A cascata é reconstruída do `scene_path` ao trocar de
entrada/template. O campo "Tipo" (character/structure) foi REMOVIDO (o kind vem da categoria);
`model_options`/`_collect_scene_options` viraram código morto e foram excluídos.

## Biblioteca de cenários (`library3D/sceneries/`)

`box/` (cubo magenta 2 m), `sphere/` (esfera esmeralda r=1,2) e `pill/` (cápsula âmbar h=3) —
`StaticBody3D` + geometria volumétrica básica + material EMISSIVO + `OmniLight3D` própria
(range 6, sem sombra — barato) + `CollisionShape3D` abraçando a malha e `limb_config.json` com o
membro único **BODY/CORPO** (conceito LimbColliders — mesma família do `bomb`), então a tela
Models pode configurar o collider. Entram nos `_spawnable_scenes` dos levels (replicáveis nas
salas). As antigas `structures/` saíram do projeto (limpeza do usuário); kind legado
"structure" é migrado p/ "scenery" no load.

## ManageTemplatesButton da host_session (2026-07-03)

O "Templates" da grade do host "não funcionava" quando o seletor de level estava em
"Selecione..." — retorno SILENCIOSO. Agora exibe um alerta (`FloatingDialog.alert`: "Selecione um
level primeiro…"); com level selecionado abre o gerenciador normalmente (validado ao vivo
hospedando em 127.0.0.1:4383 — sala #1 criada, observada, cenário aplicado).

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
