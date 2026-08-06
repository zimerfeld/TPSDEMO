---
tipo: sistema
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-08-06
---

# 🧩 Templates de Level (Gerenciador de Templates + Gerenciador de Cenários)

> Composição de spawn por level: personagens (Templates) e objetos de cenário (Cenários), com
> facção, quantidade e posicionamento, editados em jogo numa janela flutuante e aplicados quando
> o level inicia (solo ou sala online). Relacionado: [[🎬 fluxo-de-cenas (PT)|🎬 fluxo-de-cenas]] (tela `levels`),
> [[🚪 salas (PT)|🚪 salas]] (host abre a mesma janela), memória *"salas nascem limpas"*.

---

## 📐 Campo "Escala (%)" (2026-08-06)

Abaixo de **Quantidade**, nos **dois** gerenciadores (Templates e Cenários), um `SpinBox` define a
escala do modelo em **porcentagem sobre o tamanho original**:

| Valor | Efeito |
|---|---|
| `0` | tamanho natural (default) |
| `+50` | uma vez e meia |
| `-30` | 30% menor |

- Faixa aceita: **-95% a +900%**.
- Persistido na entrada do template com a chave **`scale_percent`** (JSON em `user://`), portanto é
  carregado e pode ser alterado **em tempo de execução**, sem recompilar.
- Aplicado a cada spawn em `TemplateManagerBase._configure_spawned_node`:
  `factor = 1 + scale_percent/100`, com piso de **0,05** (abaixo disso a malha vira um ponto e os
  colliders degeneram). O fator também fica na meta `template_scale_factor` do nó.

## Duas cenas + dois managers separados (2026-07-03, refatoração)

Responsabilidades **separadas** por categoria (antes: um só diálogo `LevelTemplateDialog`
parametrizado por `configure()` e um só autoload `LevelTemplateManager` — ambos REMOVIDOS):

- **UI — duas cenas `.tscn`** (raiz `ScrollContainer`, rolagem vertical quando os campos não cabem):
  - `scenes2D/template_manager/template_manager.tscn` (+ `.gd`) — personagens, **com** linha Facção;
  - `scenes2D/scenery_manager/scenery_manager.tscn` (+ `.gd`) — cenários, **sem** Facção.
  - Lógica comum na base `scenes2D/managers_common/template_form_base.gd` (`class_name
    TemplateFormBase extends ScrollContainer`); cada subclasse só define `_manager()`, título e
    nome padrão. A presença/ausência da Facção é detectada pelo nó `%Factions` (só existe na cena
    de personagens). Cada cena tem `Resources/<nome>.pt.json` + `.en.json` (i18n via Locale).
  - Abertas por `open_over(host, level_path)`: criam a `FloatingWindow` (CanvasLayer 128),
    inserem o próprio formulário no conteúdo dela e montam os botões do rodapé; ao fechar, o
    CanvasLayer inteiro é liberado (a instância NÃO é reaproveitada — o chamador cria uma nova).
  - **Layout do formulário (2026-07-03):** `Novo` fica à direita do campo `Nome` (não mais na TopRow);
    a `EntryRow` (dropdown `Entries` + `Remover Entrada`) vem ANTES da `EntryNameRow` (campo
    `Nome da entrada` + `Adicionar Entrada` à direita). O campo `Nome da entrada` é **auto-preenchido**
    com o corpo do rótulo do dropdown Entries (`_entry_body_text`: nome custom ou `_entry_auto_label`
    "facção modelo xN"); `_save_entry_fields` só grava como nome CUSTOM se o texto difere do rótulo
    automático (senão mantém `""` = dinâmico). Rodapé: o botão foi renomeado — nó `Footer_SalvarAplicar`,
    texto **"Salvar e Aplicar"** (`add_footer_button` + `save_apply.name = ...`; chave i18n nova).
- **Dados — dois autoloads** (`autoload/template_manager_base.gd` = `TemplateManagerBase` com a
  lógica comum; subclasses `CharacterTemplateManager` e `SceneryTemplateManager`), cada um no SEU
  arquivo: `user://character_templates.json` e `user://scenery_templates.json`. API uniforme sem
  categoria: `templates_for_level(level)`, `active(level)`/`active_id(level)`, `set_active`,
  `upsert_template`, `remove_template`, `browse_dir`, `root_dir`, `apply_active(level, spawned)`.
- **Migração 1x**: na 1ª carga, se o arquivo próprio não existe, cada manager LÊ o legado
  `user://level_templates.json` e traz só a sua categoria (`_matches_legacy`) + o mapa de ativos
  correspondente (`active_by_level` / `active_scenery_by_level`), gravando no arquivo próprio.
- **Aplicação**: `level_1`/`level_2` (solo) e `RoomManager` (salas) chamam
  `CharacterTemplateManager.apply_active` **e** `SceneryTemplateManager.apply_active`. No `level_2`,
  a criatura padrão só nasce se NENHUM dos dois aplicou (semântica preservada do antigo bool).

Cada level tem na tela `levels` DOIS botões à direita (Template + Cenário), com ativos
independentes — um level roda um template de personagens E um cenário ao mesmo tempo (solo e salas).

**Cura de caminhos obsoletos (no load):** `_heal_entry_paths` relocaliza pelo `model_key`, sob a
raiz atual, toda entrada cujo `scene_path` não existe mais (ex.: dados salvos apontando para a
extinta `characters/enemies/…`) e regrava o arquivo. Sem isto, a cascata do diálogo abria em
"Selecione..." em vez de re-selecionar o modelo salvo. **Rótulos i18n dos botões de level:** os
textos dinâmicos "Templates/Cenários: padrão" e "Template/Cenário: `<nome>`" passam por `tr_key`
(prefixos fixos traduzidos; o NOME do template é dado e não é traduzido), no `SKIP_GROUP` e
re-traduzidos em `language_changed` — chaves em `scenes2D/levels/Resources/levels.{pt,en}.json`.

## Layout do formulário e campos condicionais ao Posicionamento (2026-07-04)

Refino de layout das DUAS janelas (mesma base `TemplateFormBase`, aplicado às duas `.tscn`):

- **Campos condicionais AGRUPADOS.** Os campos que só valem para um modo de Posicionamento saíram
  do grid principal e foram para um `PanelContainer` **`%PlacementGroup`** (título "Opções de
  posicionamento", chave i18n nova nos dois idiomas), com `MarginContainer` interno e um
  `GridContainer` de 2 colunas. `_apply_placement_visibility()` mostra só os pares label+campo do modo
  atual (par oculto = ambas as células, para o grid não desalinhar) e o PAINEL inteiro some quando não
  há entrada (`_placement_group.visible = has_entry`). Mapeamento: `coordinates` → Coordenadas;
  `random` → Centro + Tamanho aleatório; `formation` → Formação + Origem + Espaçamento. **Rotação Y**
  é geral (sempre visível, fica no grid principal). Controles ocultos saem do anel de Tab
  automaticamente (`UINav.collect_focusables` ignora invisíveis) — `_win.wire_focus_ring` é religado
  em `_on_placement_selected` e ao trocar de entrada.
- **Larguras compactas (não superdimensionadas).** Os campos deixaram de esticar com a janela
  (`size_flags_horizontal = 0`): dropdowns e campos de vetor-texto **240 px**; inteiros/números
  (`Count`, `Spacing`, `Rotação`) **96 px** (cabem os dígitos sem estourar). Os grids encolhem ao
  conteúdo e alinham à esquerda, sem tocar as bordas (a `FloatingWindow` já dá margem de 16 px).
- **Cascata do Modelo em coluna.** `%CascadeRow` virou `VBoxContainer` (era `HFlowContainer`), então
  cada dropdown `Folders%d` ocupa a largura toda e empilha verticalmente (o VBox estica no cross-axis).
- **`ModelValue` removido.** A label que mostrava "Modelo: X (x.tscn)" saiu (nó + `_model_value_label`
  + `_update_model_label()` + chamadas) — limpeza de código morto.
- **Janela menor.** `min_window_size` 1040×640 → **700×620**; `custom_minimum_size` das cenas
  1000×560 → **620×540**, cortando espaço horizontal ocioso.

> [!warning] `.tscn` NÃO usa `#` para comentário
> Comentários de prosa com `#` DENTRO do `.tscn` corrompem o parse de nós (aviso "parent path …
> vanished", filhos sem pai). O formato de recurso do Godot usa `;`. Preferir: sem comentário no
> `.tscn` (documentar aqui) — validado instanciando as duas cenas headless (todos os `%UniqueName`
> resolvem, sem "vanished").

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

## ManageTemplates da host_session (2026-07-03; ex-ManageTemplatesButton)

O "Templates" da grade do host "não funcionava" quando o seletor de level estava em
"Selecione..." — retorno SILENCIOSO. Agora exibe um alerta (`FloatingDialog.alert`: "Selecione um
level primeiro…"); com level selecionado abre o gerenciador normalmente (validado ao vivo
hospedando em 127.0.0.1:4383 — sala #1 criada, observada, cenário aplicado).

## Arquitetura

- **`TemplateManagerBase`** (`autoload/template_manager_base.gd`): base comum dos dois autoloads.
  API: `upsert_template(t) -> id`, `remove_template(id)`, `set_active(level, id)`,
  `active(level)`/`active_id(level)`, `templates_for_level(level)`, `apply_active(level, spawned)`,
  `browse_dir(dir)`, `root_dir()`. Ganchos por subclasse: `_file_path`, `root_dir`, `_entry_kind`,
  `_matches_legacy`, `_install_defaults`.
  - **`CharacterTemplateManager`** → `user://character_templates.json`, raiz `characters`; sem
    template salvo, instala o exemplo "Level 2 - Caça aérea".
  - **`SceneryTemplateManager`** → `user://scenery_templates.json`, raiz `sceneries`; sem defaults.
- **`TemplateFormBase`** (`scenes2D/managers_common/template_form_base.gd`): controlador do formulário
  (raiz `ScrollContainer`) inserido numa `FloatingWindow` (CanvasLayer 128) — tema 2D + Debug 2D
  funcionam. Subclasses: `template_manager.gd` (personagens) e `scenery_manager.gd` (cenários),
  cada uma raiz da sua `.tscn`. Abertas por `open_over(host, level)` do botão de cada linha da tela
  `levels` e (só o de personagens) pela `host_session`.
- **Entrada** de template: `kind` (character/scenery), `model_key`/`scene_path`, `faction`
  (friendly/enemy/neutral — só personagens), `count`, `placement` (coordinates/random/formation) +
  campos de cada modo, `name` (rótulo custom no dropdown `Entries`), `rotation_y`, `spacing`.
- **Aplicação**: `level_1.gd`/`level_2.gd` chamam `apply_active` dos DOIS managers no `_ready`
  (offline) e o `RoomManager` na criação da sala (online). Facção friendly → player `bot_controlled`
  (bots de cobertura); enemy → IA hostil.
- `browse_dir`/`_dir_model` varrem a raiz da categoria recursivamente; só entra a cena cujo basename
  == nome da pasta (a cena "do modelo"; irmãs como `bomb.tscn` ficam fora). Precisa do
  `_logical_name` (strip `.remap`/`.import`) para funcionar no `.exe` exportado.

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
