# Biblioteca de Modelos (tela Models)

Tela `scenes3D/models/models.tscn` (`models.gd`): navegador + extrator dos
modelos 3D do projeto. Alcançada por **developer → Modelos 3D**; volta com
"Voltar" (→ developer) e abre a galeria com "Exportados" (→ `Exported.tscn`).

## Gizmo de eixos 3D (orientação)

Indicador de orientação estilo editor no **topo à direita**: três eixos coloridos (X vermelho, Y
verde, Z azul) com bola e letra na ponta, que **giram junto com o modelo** (`_gizmo_node.rotation =
model_holder.rotation` no `_process`). Montado por código (`_setup_axis_gizmo`) num **SubViewport
próprio** (`own_world_3d`, `transparent_bg`, MSAA) com câmera ortográfica olhando -Z — assim **nunca
é coberto pelo modelo** e independe do zoom. O overlay é reposicionado a cada frame **à esquerda da
coluna de toggles** (`_position_gizmo_overlay`), então não cobre a UI nem o modelo (centralizado),
em qualquer resolução. Materiais **unshaded** (cor cheia, legível sem luz). Tunáveis: `_GIZMO_SIZE`,
`_GIZMO_ARM`, `_GIZMO_BALL`.

## Biblioteca de assets

Tudo sob `res://library3D/<tipo>/<modelo>/`:

- `characters/` — `player`, `players`, `red_robot`, `criatura_alada`, `demonio_*`,
  `mecha07_infantil`, `enemies/` e os **14 robôs** `robot_01..07_*_{infantil,adulto}`
  (importados de `C:\GODOT\MODELOS\robos_3d_godot_infantil_adulto` em 2026-06-16; prefixo "robot")
- `propulsores/` — `forklift` (era `props/` na versão antiga da nota)
- `structures/` — `core`, `core_out_light`, `door`, `lights`, `props`, `structure`
- `weapons/` — `bomb`, `pistola_infantil`
- pastas de suporte (NÃO categorias): `geometry/` (materiais `.tres`), `textures/`, `extracted/` (saída)

`_scan_library()` varre só as **4 categorias fixas** em `const CATEGORIES`
(characters/propulsores/structures/weapons — pastas de suporte como geometry/textures
são ignoradas de propósito). Novo modelo em `library3D/<tipo>/<nome>/` com um `.glb`
aparece sozinho — nada a editar em código.

> [!warning] Compatibilidade com BUILD EXPORTADO (2026-06-21)
> No `.exe` exportado os fontes não vão crus no PCK: o `.glb` vira **`<nome>.glb.import`** e o
> `.tscn` vira **`<nome>.tscn.remap`** (ambos apontam para o recurso importado). Por isso o scanner
> normaliza cada nome com **`_logical_name()`** (tira o sufixo `.import`/`.remap` → caminho lógico,
> que `load()` resolve no editor E no export). Sem isso o `_find_model_file` não achava nada e o
> **menu Categoria ficava vazio no `.exe`** (no editor funcionava). Validado: editor e export acham
> os mesmos 21/1/6/2 modelos.

### Tipos de arquivo importáveis (escaneados)

O navegador reconhece **apenas 3 extensões** (case-insensitive), só dos arquivos
**diretamente na pasta do modelo** (subpastas como `audio/`, `bullet/` são ignoradas):

| Extensão | Papel |
|---|---|
| `.glb` / `.gltf` | malha crua importada (glTF 2.0) — **preferida** |
| `.tscn` | cena Godot montada — **fallback** |

> [!warning] Formatos como `.obj`, `.fbx`, `.dae` **não aparecem** no navegador.
> Precisam virar `.glb`/`.gltf` (ou uma cena `.tscn`) antes. glTF (`.glb`/`.gltf`) é
> o formato recomendado pelo Godot para modelo completo **com animação** (malha +
> esqueleto + skinning + clips); `.blend`/`.fbx`/`.dae` também animam mas dependem de
> Blender/FBX2glTF; `.obj` só importa malha estática.

Cada modelo resolve **dois** caminhos, por duas funções distintas:

- **`_find_model_file()`** → `path` (a **malha**, base do catálogo de peças). Prefere,
  nesta ordem: `.glb`/`.gltf` cujo basename **bate com a pasta** (ex.: `red_robot.glb`
  em `red_robot/`), depois qualquer `.glb`/`.gltf`, depois `.tscn` homônimo, depois
  qualquer `.tscn`. A malha crua ganha por mostrar a geometria **sem rodar script de
  gameplay**. O critério "nome = pasta" evita que uma cena irmã (ex.: `bomb.tscn` em
  `criatura_alada/`, o projétil) seja confundida com o modelo.
- **`_find_display_file()`** → `display_path` (a cena do **"Modelo completo"**). Prefere
  o **`.tscn`** (carrega materiais, efeitos e a variante visível pretendida que o `.glb`
  cru não tem), caindo para o que `_find_model_file` resolver (o `.glb`) quando não há cena.

Depois de escolher um modelo, `_on_model_selected` faz `load()` dos dois caminhos e
`_build_mesh_catalog` instancia a cena, varre todos os `MeshInstance3D` e os **deduplica
pelo recurso `Mesh` compartilhado** (`get_instance_id`) — cada malha distinta lista uma
vez, ordenada por nº de placements, com marca `[skin]` (skinning/animação) ou `[+col]`.

## Fluxo da tela

**Categoria → Prefixo → Modelo → Parte**, com **seleção sequencial** (2026-06-16):
cada dropdown abaixo de Categoria fica **desabilitado** até o de cima ter uma
escolha real. Todo dropdown começa com o placeholder **"Selecione..."** (item 0,
default — ver [[convencoes/dropdowns]]); selecioná-lo recarrega/destrava os
dependentes também em "Selecione..." e limpa o preview. O dropdown "Parte" lista
`Selecione...`, depois `Modelo completo`, depois as malhas **distintas** (dedup por
recurso `Mesh` via `get_instance_id`), rótulo `Nome (×N) [+col]/[skin]` ordenado por
uso. O preview mostra a peça selecionada, centrada/escalada (`_fit_to_view`). Os
dropdowns são `OptionButton` nativos (sem listas de botões).

Os combos **"Animação"** (`AnimationRow`) e **"Efeitos Especiais"** (`EffectsRow`, abaixo de
Animação) só aparecem quando a Parte é **"Modelo completo"**:
`_populate_animations()`/`_populate_effects()` mostram as linhas e
`_reset_animations()`/`_reset_effects()` as escondem (placeholder e partes isoladas). Ambos só
se aplicam ao modelo montado.

- **Efeitos Especiais (2026-06-18):** lista, após "Selecione...", a opção **"Todos"** (mostra
  todos os efeitos) e exibe **efeitos de todos os tipos** que existirem — luzes/luminosidade
  (e sombras), fumaça/partículas, decals, névoa (`FogVolume`), atratores/colisores de partícula
  e malhas presas a osso (muzzle/laser). Coletados por `_collect_effect_nodes` via a lista
  `_EFFECT_CLASSES` (`node.is_class(...)`, pega subclasses). "Todos" só é incluído **quando há**
  efeitos; sem efeitos, o combo fica só no placeholder e desabilitado.

> [!note] StatusLabel removido (2026-06-18)
> A linha de status (a label vermelha que guiava "Selecione um/uma …" acima dos combos) foi
> **removida** da tela — o nó `StatusLabel` saiu da cena e todo o código de status
> (`_set_status`/`_apply_status`/`_clear_status`/`_update_whole_model_status`/
> `_refresh_whole_model_status`, vars `_status_*` e onready `selectors_box`/`*_row` órfãos) e as
> chaves de mensagem nos JSONs foram apagados. A navegação é guiada só pelo gating sequencial
> dos dropdowns.

**Cascata de reset (2026-06-16):** mudar qualquer selector reseta **todos** os de
baixo para "Selecione..." e reabilita só o filho imediato. As funções de reset
(`_reset_meshes_and_preview`, `_on_model_selected`) agora chamam também
`_reset_animations()`+`_reset_effects()`, então os dois combos de baixo entram na
cascata (antes ficavam "presos" visíveis ao trocar um selector acima).

> [!info] Sem linha de status (2026-06-18)
> A tela **não tem mais** a `StatusLabel` que mostrava prompts "Selecione um/uma …" (categoria/
> prefixo/modelo/parte/animação/efeito) nem a antiga contagem de partes. A orientação fica só
> pelo gating sequencial dos dropdowns (cada combo desabilitado até o de cima ter escolha real).

### Rotação do preview

`_yaw`/`_pitch` separados → `model_holder.rotation = Vector3(_pitch, _front_yaw_base + _yaw, 0)`
(roll sempre 0, só eixos ortogonais). `_front_yaw_base` é a **orientação frontal BASE** do modelo
antes do drag (default `DEFAULT_FRONT_YAW = PI`, o flip de 180° da convenção front=-Z). **Por
modelo (2026-06-21):** `_MODEL_FRONT_YAW` sobrescreve essa base — `player` e `red_robot` foram
exportados com a **frente em +Z** (mesma direção da câmera), então o flip de 180° os mostrava de
**costas**; com `0.0` eles **abrem de frente**, sem o usuário precisar rotacionar. Setado em
`_on_model_selected` (e resetado em `_reset_meshes_and_preview`). Ao arrastar, **ambos** os eixos
vão até **±180°** (2026-06-16): `_yaw` (esquerda/direita) gira o modelo até as costas e
`_pitch` (cima/baixo) tomba o modelo de ponta-cabeça. O modelo é **nivelado** antes
do giro: `_preview_whole_model()` zera a rotação embutida da raiz do `.glb`
(desconsidera inclinações angulares). Arrastar com o botão esquerdo sobre a área 3D
move yaw/pitch; o toggle **Rotação** liga/desliga a rotação automática (só yaw, sem
trava — gira como turntable). `UI` raiz tem `mouse_filter = 2` para o arrasto chegar
a `_unhandled_input`.

### Toggles (preferência + persistência)

> [!note] Nós dos toggles sem o sufixo "Toggle" (2026-06-28)
> Os nós `CheckButton` dos toggles tiveram o sufixo **"Toggle" removido do nome** (pedido p/ limpar os
> tooltips do Debug 2D): `Rotate`, `Animation`, `Effects`, `Audio`, `Colliders`, `Labels`, `SubCollider`,
> `SubMemberLabel`, `AuxHighlight` (antes `…Toggle`). Os `%`-acessores em `models.gd` acompanham; as
> **variáveis** GDScript (`rotate_toggle`, `colliders_toggle`, …) e os métodos `_show_*` **não** mudaram.
> **Sufixo "Check" também removido (2026-06-28):** os `CheckButton` cujo nome terminava em "Check"
> perderam o sufixo: `Malha`, `Osso`, `SkeletonLines`, `Type`, `Name`, `Id` (antes `…Check`). Os
> `%`-acessores em `models.gd` acompanham; as variáveis (`malha_check`, `osso_check`, `type_check`…) e
> os métodos `_show_*` **não** mudaram.

> [!important] Nomes de nó → inglês descritivo (2026-06-29)
> Renomeação dos **controles** da tela Models (só nomes de nó; **textos exibidos e persistência
> inalterados**):
> - **Dropdowns:** prefixo `cbo` removido — `cboCategory→Category`, `cboPrefix→Prefix`,
>   `cboModels→Models`, `cboMeshes→Meshes`, `cboAnimations→Animations`,
>   **`cboEffects→EffectsList`** (não pôde virar `Effects`: já é o nó do `CheckButton` de efeitos),
>   `cboMembers→Members`, `cboMemberGeo→MemberGeo`, `cboSubMembers→SubMembers`,
>   `cboSubMemberGeo→SubMemberGeo`, `cboSkeleton→Skeleton`, `cboSkeletonGeo→SkeletonGeo`.
> - **Toggles (`CheckButton`):** `Malha→Mesh`, `Colliders→MemberLimbCollider`, `Labels→MemberLabel`,
>   `SubCollider→SubMemberLimbCollider`, `AuxHighlight→SkeletonLimbCollider`, `Osso→SkeletonLabel`.
> - **Gizmo de eixos:** `AxisGizmoOverlay→AxisGizmo` (o `SubViewportContainer`).
> - **Botões/painéis de Dano e IA (sem o sufixo de tipo):** `DamageButton→Damage`, `AIButton→AI`,
>   `DamagePanel→Damage` (janela), `CloseButton→Close`, `AICloseButton→AIClose`, `DamageTree→Limbs`.
>   **Colisão de nome:** o botão **e** a janela viram "Damage" (pais diferentes, OK como nó), mas o
>   `%Damage` único fica com a **janela**; o **botão** é resolvido por caminho (`$UI/Actions/Damage`,
>   sem `unique_name`). `AIPanel` ficou como está (não pedido), então `%AI` (botão) não colide.
> - **Footer do painel Dano redesenhado:** a seção "Adicionar sub-membro" virou um **`GridContainer`
>   de 3 colunas** (osso · dono · botão) para os cabeçalhos ficarem na MESMA largura dos dropdowns
>   abaixo. O **tooltip** do dropdown de dono ("Membro-dono…") deixou de ser tooltip e virou um
>   **rótulo visível `OwnerHint`** de largura total acima da seção (chave nova nos `models.{pt,en}.json`).
>   Controles criados em código agora têm nome (antes `@label@…`/`@optionbutton@…`): `Separator`,
>   `OwnerHint`, `AddArea` (grid), `AddTitle`/`OwnerTitle`/`Pad`, `Bone`/`Owner`/`Add`; e os itens da
>   lista de IA: `<chave>`/`Content`/`Enabled`/`Description`.
> - **AIPanel — tooltips removidos:** cada checkbutton de comportamento já mostra a descrição como
>   **rótulo logo abaixo** dele, então o `tooltip_text` (que duplicava a descrição) saiu do toggle **e**
>   do `Description` — a regra "texto só no rótulo abaixo, sem tooltip duplicado".
> - **Label do dropdown de malha:** texto **"Parte:" → "Malha:"** (`Mesh:` em en; chave em
>   `models.{pt,en}.json` migrada de `Parte:` para `Malha:`).
> - **VBox `Selectors`:** perdeu o `size_flags_horizontal = 3` (deixou de esticar a linha toda) e
>   ganhou um irmão **`Spacer`** (expand-fill) antes de `Toggles`, encolhendo a coluna ~à metade e
>   mantendo os toggles fixos à direita.
>
> Os `%`-acessores em `models.gd` acompanham; as **variáveis** GDScript (`cbo_*`, `*_check`,
> `*_toggle`) e os métodos `_show_*` **não** mudaram.

Toggles atuais (ordem/nomes em 2026-06-23): **Malha · Rotação · Animação · Efeitos especiais · Audio ·
Colisor de Membro · Membro · Colisor de Submembro · Submembros · Colisor de Esqueleto ·
[Esqueleto · Linhas do Esqueleto · Tipo · Nome · ID]**. (Renomeados de "Colisores
de X" → **"Colisor de X"**; `SubCollider`/`SubMemberLabel` movidos para o topo, logo
**abaixo de "Membro"**; **"Malha" promovido ao 1º da lista** e **"Dano" deixou de ser toggle** —
virou o **botão `DamageButton`** ao lado direito do "Voltar", ver abaixo.)

> [!note] Labels Tipo/Nome/Id no Esqueleto e Submembro + exclusividade (2026-06-23)
> - **Tipo/Nome/Id** (cores rosa/verde/amarelo de `_LABEL_LINE_COLORS`) agora aparecem também sobre o
>   rótulo do **Esqueleto** (`_label_aux_bones`) e do **Submembro** (`_label_sub_member`), via
>   `_add_tni_lines` — descrevendo o ELEMENTO (classe do nó · nome do osso/submembro · id do nó). Os
>   handlers Tipo/Nome/Id refrescam membro+submembro (`_refresh_member_overlays`) e esqueleto
>   (`_refresh_aux_labels`).
> - **Bug corrigido:** o stack "Membro:" não aparece mais sobre **submembros** — `_add_member_labels`
>   pula corpos `PART_*` (um elemento é Membro OU Submembro, nunca os dois).
> - **Exclusividade:** `_aux_bone_candidates` já só oferece ossos não-membros (`group_of==""`) para
>   promover; `_on_sub_member_added` ainda bloqueia + avisa se um osso de Membro chegar lá.

> [!note] Prefixos dos rótulos 3D LOCALIZADOS (2026-06-25)
> Os prefixos dos `Label3D` — **"Membro:" / "Sub-membro:" / "Esqueleto:" / "Tipo:" / "Nome:"** (e "ID:") —
> passam por `Locale.tr_key(...)` na construção (`_add_member_labels`, `_label_aux_bones`,
> `_label_sub_member`, `_add_tni_lines`), então aparecem traduzidos nos DOIS idiomas (antes "Membro/
> Esqueleto/Submembro" ficavam em PT no EN, e "TYPE/Name" em EN no PT; "Submembro:" virou "Sub-membro:").
> Como `Label3D` NÃO passa pelo auto-tradutor do Locale, `_on_language_changed` agora chama
> `_refresh_member_overlays()` + `_refresh_aux_labels()` para reconstruir as pilhas no idioma novo.
> Chaves novas em `models.{pt,en}.json`: `Tipo:`/`Nome:` (prefixos) + os toggles `Tipo`/`Nome`/`Linhas do Esqueleto`.

> [!note] "Malha" e "Linhas do Esqueleto" (vindos da antiga tela developer, 2026-06-23)
> - **Malha** (`Malha`, **1º toggle da lista** desde 2026-06-23, chave `show_malha`, default LIGADO):
>   mostra/esconde a malha (`MeshInstance3D`) do modelo do preview (pula gizmos com nome `_…`). `_apply_malha_visibility`.
> - **Linhas do Esqueleto** (`SkeletonLines`, abaixo de Id, chave `show_skeleton_lines`): desenha
>   as linhas brancas osso→pai do preview, refeitas todo frame pela pose viva (`_refresh_skeleton_lines`
>   / `_update_skeleton_lines`, gizmo `_SkeletonLines`). É DIFERENTE de "Esqueleto" (que mostra o NOME
>   do osso). Efeito **só nesta cena** (o preview). Ambos persistem na seção `models` do config.

> [!note] Renomeações e novos toggles (2ª leva, 2026-06-22)
> - **Colisores** → **Colisores de Membro** (`Colliders`, `_show_colliders`).
> - **Esqueleto** (o realce laranja, `AuxHighlight`/`_show_aux_highlight`) → **Colisores de Esqueleto**.
> - **SubMembro** (`Osso`/`osso_check`/`_show_osso`, topo do `LabelLinesRow`) → **Esqueleto**; o
>   Label3D agora exibe **"Esqueleto: \<nome\>"** (antes só o nome do osso).
> - **NOVO Colisores de Submembros** (`SubCollider`/`_show_sub_colliders`, chave `show_sub_colliders`;
>   rótulo exibido **"Colisor de Sub-membro"/"Sub-member collider"** desde 2026-06-25):
>   mostra/oculta SÓ o gizmo do limbcollider do sub-membro selecionado no dropdown (ramo de FOCO de
>   `_refresh_member_overlays`; gizmo de PART_* segue ESTE toggle, gizmo de membro segue "Colisores de
>   Membro"). Os sub-membros ficam OCULTOS na visão geral (`_apply_colliders_visibility` esconde PART_*),
>   **com uma exceção (2026-06-25):** com **"Todos os membros" + "Todos os Sub-membros"** nos dropdowns e
>   este toggle LIGADO, `_apply_colliders_visibility` mostra **TODOS** os gizmos de sub-membro de uma vez,
>   independente de "Colisores de Membro" (helper `_should_show_all_sub_colliders`).
>   O editor de afastamento/escala também aparece para sub-membros sob este toggle.
> - **NOVO Submembros** (`SubMemberLabel`/`_show_sub_member_label`, chave `show_sub_member_label`;
>   rótulo exibido **"Sub-membro"/"Sub-member"** desde 2026-06-25):
>   Label3D **"Submembro: \<nome\>"** preso ao corpo do sub-membro selecionado
>   (`_refresh_sub_member_labels`/`_label_sub_member`). Só no modo membro-específico. **Cor ROXA
>   (2026-06-23):** `_SUB_LBL_COLOR = Color(0.6,0.25,0.9)`; o toggle "Submembros" tem o **texto roxo**
>   (`font_color` via `_apply_label_line_colors`, fundo normal — sem `modulate`).

Histórico (1ª leva, 2026-06-22): "Dano por membro" virou **Dano**; "Realçar avulso" virou "Esqueleto";
o toggle "Osso" virou "SubMembro" e foi ao topo do `LabelLinesRow` (o toggle "Rótulos" foi renomeado para
**Membro** em 2026-06-21 — `Labels` no `.tscn`, traduzido "Member" em en; o antigo "Som" virou **Audio**; o
toggle **Falas** foi REMOVIDO — o Audio agora cobre todos os emissores, inclusive vozes). Cada
toggle é o **interruptor mestre** da sua categoria:

> [!note] Cores dos rótulos 3D (`_LABEL_LINE_COLORS`)
> Membro = ciano · **Tipo = ROSA (2026-06-23, antes laranja)** · Nome = verde · Id = amarelo ·
> Osso/Esqueleto = laranja. O toggle **Tipo** (`Type`) tem o **texto rosa** via `font_color`
> (`_apply_label_line_colors`, todos os estados); o **`modulate` foi REMOVIDO (2026-06-25)** para o
> **fundo do toggle bater com os demais** (antes o `modulate` tingia o controle inteiro de rosa) —
> mesmo padrão do toggle "Submembros".
> O `DebugOverlay` da tela developer reusa as mesmas cores (Tipo/Nome/Id/Membro) + Esqueleto branco.

> [!important] Cena Models 100% desacoplada do Debug 3D (2026-06-21)
> O nó raiz da cena está no grupo **`no_debug_overlay`**, então o `DebugOverlay` global pula a
> cena Models inteira (2D **e** 3D) — as definições de Debug só valem nos **levels do jogo**. Os
> rótulos de membro do preview (TYPE/Name/ID/Membro) agora seguem **toggles dedicados da própria
> cena** (Membro + os checkboxes Tipo/Nome/ID), não mais os sub-toggles globais. Foram-se o
> `_debug3d_tooltips_enabled()` e toda leitura de `game/*` em `models.gd`.
>
> **Rótulo do nome da cena (2026-06-20 → OCULTADO 2026-06-21):** o `SceneName` local (nó no
> `.tscn`) hoje fica **sempre oculto** — o nome "Models" **não deve aparecer na janela de dano**. O
> nó é preservado só para não quebrar `@onready`/referências; `_ready` faz `visible = false` e nada
> mais o exibe. O nome da cena já é mostrado pelo **watermark GLOBAL** de `debug_overlay.gd` no
> **topo direito, ao lado do título** (que tem **tooltip de Debug 2D**). Ver [[sistemas/debug-overlay]].

> [!important] Toggles agem **in-place** (2026-06-17)
> Nenhum toggle **reconstrói** o preview: o modelo **não é recarregado** e a
> **câmera/rotação ficam intactas**. Cada handler altera o nó vivo
> (`_preview_instance`) por um aplicador dedicado em vez de chamar um rebuild.

- **Animação** — uma animação só roda quando **ambos**: o toggle está ligado **E** um clip
  está escolhido no dropdown "Animação" (2026-06-18). Com o toggle desligado **nada anima**
  (`_on_animation_selected` retorna cedo); com o toggle ligado mas o combo em "Selecione..."
  também **nada roda** — **não há mais auto-play de clip default/idle**. O playback é aplicado
  **in-place** por `_apply_animation_state()` (`should_play = _play_animation and chosen != ""`;
  toca o clip escolhido em quem o tiver, para todos os outros `_preview_anim_players`).
  **Voltar ao "Selecione..." (2026-06-23):** quando nada deve tocar, além de `stop()` (que só
  CONGELA a pose corrente), o esqueleto é reposto na **pose de REST = estado inicial do modelo**
  (cada osso → `get_bone_rest`, via `set_bone_pose_*`; os modelos não têm clip "RESET").
  **Loop (2026-06-23):** o clipe escolhido fica em **loop** — ao terminar, `_on_preview_anim_finished`
  (sinal `animation_finished`) o re-toca. Por sinal, NÃO mexe no `loop_mode` do recurso (compartilhado
  com o jogo). Clipes de morte/explosão não dão loop.
- **Audio** — toca **todos** os emissores do modelo (movimentação andar/correr/saltar,
  motor, tiro, explosão, vozes…); desligado, silencia. Aplicado por `_apply_audio_state()`.
  (Não há mais toggle "Falas" separado.)
- **Colisores** — `_apply_colliders_visibility()` adiciona/remove os gizmos wireframe
  (`_add_collider_gizmos`, idempotente, nó `_ColliderGizmo`) **sem rebuild**; constrói os
  colliders de membro sob demanda uma vez (`_ensure_member_colliders`). Para **Personagens/
  Armas** desenha gizmo **só dos colliders de MEMBRO** (`_is_member_collider`, meta
  `member_label`); pula o collider de corpo genérico do modelo (ex.: a cápsula de corpo do
  red_robot) e as áreas de detecção/morte, que só eram ruído envolvendo tudo (2026-06-18).
  - **Re-encaixe em tempo real na animação (2026-06-23):** os colliders são presos aos ossos
    (`BoneAttachment3D`), então já seguem **translação/rotação**. Enquanto uma animação toca **e** os
    colisores estão visíveis, `_process` chama `_member_lc.refit(_member_skel)` (`limb_colliders.gd`):
    recomputa a AABB de cada membro/sub-membro na **pose ATUAL** dos ossos e re-encaixa a forma +
    gizmo — então os colliders **acompanham a dobra** dos membros multi-osso. Só no preview (rigs sem
    esqueleto já seguem o nó animado).
    - **Performance (2026-06-23):** o refit era ~150 ms/chamada porque `surface_get_arrays`
      reconstruía os arrays da malha todo frame. Agora há um **cache** (`_build_refit_cache`): por
      vértice guarda grupo + osso dominante + `bind_pose·vértice`; o refit só lê as poses ATUAIS dos
      ossos → **~4 ms** (33× mais rápido). O cache é montado **ao construir os colliders**
      (`_add_member_colliders`), movendo o custo único (~150 ms) para FORA da animação. Além disso,
      **throttle adaptativo** no
      `_process` (intervalo = `elapsed·30`, teto 10 Hz / piso 2 Hz) mantém o custo em ~3% → **≥ 60 FPS**,
      com modelos mais densos re-encaixando menos vezes. (1ª chamada ainda monta o cache ~150 ms uma vez.)
  - **Geometria do collider + janela de Afastamento/Escala por membro/sub-membro/osso avulso (2026-06-25,
    substitui o editor inline):** ao escolher um item **real** (não "Selecione..."/"Todos") em **Membro**,
    **Sub-membro** ou **Esqueleto**, aparece **à direita** daquele dropdown um **dropdown de geometria**
    (`cboMemberGeo`/`cboSubMemberGeo`/`cboSkeletonGeo`; itens "Selecione..." + Esfera/Caixa/Cápsula com
    metadata `""`/`sphere`/`box`/`capsule`) **e** abre-se a **janela flutuante REUTILIZÁVEL**
    ([[convencoes/ancoragem-ui|FloatingWindow]] dos controles2D) — `_open_or_update_collider_dialog`,
    anexada ao `UI`, `modal=false` (dá p/ girar o modelo), posição lembrada em
    `windows/models_collider_dialog` — com **Afastamento**, **Rotação** (graus) e **Escala** X/Y/Z, **intitulada
    com o nome do item**. Cada mudança **persiste na hora** (`LimbConfig.set_collider_offset`/`set_collider_rotation`/
    `set_collider_scale`, **sem botão Salvar**) e aplica **AO VIVO** (`_apply_collider_xform`: afastamento →
    `body.position`; rotação → `body.rotation_degrees`; escala → `scale` da forma). O **dropdown de geometria** grava `LimbConfig.set_collider_shape` e
    **reconstrói** os colliders (`_rebuild_member_colliders`): num **MEMBRO**, "Selecione..." = `SHAPE_NONE`
    → **remove o collider** (membro sem hitbox); num **SUB-MEMBRO**, "Selecione..." = `SHAPE_NONE` **SUPRIME o
    collider** mas **mantém o sub-membro** na árvore/dropdown (corpo de preview suprimido — ver `include_suppressed`
    abaixo) p/ reconfigurar; a remoção total é pela lixeira da árvore de Dano. Para um **OSSO AVULSO** (Esqueleto),
    escolher uma geometria **NÃO promove** (2026-06-25): só persiste a forma de preview (`set_collider_shape`) e o
    realce **"Colisor de Esqueleto"** passa a desenhar nessa geometria (ver abaixo) — a promoção (criar o collider
    de fato) segue na janela de Dano ("Adicionar sub-membro"). Esqueletos **não têm dano e não entram nos levels**
    (preview-only). **Pré-seleção dos 3 dropdowns (3 estados, 2026-06-25, `_select_geo_for_group`):** forma salva
    (sphere/box/capsule) → **CARREGA** a última escolha; `SHAPE_NONE` → **"Selecione..."** (sem collider, explícito);
    **sem escolha ("") → AUTODETECTA** — forma VIVA do collider (`_live_shape_kind`, membro/sub têm corpo) ou pelo
    **formato do osso** (`_auto_geo_for_box`/`_auto_geo_for_group` via AABB: alongado→cápsula, redondo→esfera, senão caixa).
    **Sub-membro suprimido fica VISÍVEL (`include_suppressed`, 2026-06-25):** o preview seta `lc.include_suppressed
    = true`; em `build_for`, um sub-membro `SHAPE_NONE` ainda é construído (forma automática, meta `suppressed`,
    **sem gizmo** — `_add_collider_gizmos` o pula) p/ continuar na árvore/dropdown; no gameplay (flag false) é PULADO.
    Tudo é **relido no spawn** via `LimbColliders` (`make_member_shape` honra o override;
    `build_for`/`_add_mesh_member_colliders` pulam grupos `SHAPE_NONE`). **Visibilidade dos geo (2026-06-25):**
    o geo do **Membro** some quando um **sub-membro específico** (`PART_*`, ≠ "Selecione..."/"Todos os Sub-membros")
    está escolhido — aí vale o geo do sub-membro (mesma precedência da janela de Afastamento/Escala). Lógica em
    `_refresh_collider_editors` / `_on_*_geo_selected` / `_sync_collider_dialog` / `_current_edit_target`.
    O antigo `ColliderEditBox` inline + botão **Salvar** + `_prompt_save_offset_if_dirty` foram **REMOVIDOS**.
    Ver [[sistemas/dano-localizado]].
- **Efeitos especiais** — mostra/esconde **tudo o que sobra** ligado ao modelo e que
  nenhum outro toggle cobre: partículas, luzes, decals/névoa e malhas presas a osso (muzzle/
  laser), coletadas por `_collect_effect_nodes` (lista `_EFFECT_CLASSES`). O combo **"Efeitos
  Especiais"** isola **um** efeito (mostra só ele); **"Selecione..."** e **"Todos"** (item 1,
  2026-06-18) mostram **todos** (só com o toggle ligado). A visibilidade é aplicada por
  `_apply_effects_visibility` (`sel <= 1` = todos; `>1` = isolado) sem reconstruir o preview.
- **Membro · Tipo · Nome · ID** (2026-06-21; o toggle **Membro** chamava-se "Rótulos" até
  2026-06-21 — só o TEXTO mudou, o nó segue `Labels`/`labels_toggle`) — a pilha de tooltips de
  membro (TYPE/Name/ID/Membro) agora é **toda local** à cena Models, sem nada do Debug 3D global.
  **Membro** (CheckButton) liga
  a linha "Membro: …"; **Tipo/Nome/ID** são 3 `CheckButton` (toggles) **empilhados verticalmente** no
  nó `LabelLinesRow` (um `VBoxContainer` desde 2026-06-21 — antes eram `CheckBox` numa linha horizontal
  que **cortava os rótulos** na coluna estreita; o stack vertical garante que os 3 textos apareçam por
  inteiro) que ligam as linhas que descrevem o `Skeleton3D`. Os tooltips de membro são desenhados com
  `render_priority` alto (sempre por cima dos gizmos verdes e uns dos outros).
  `_apply_member_labels_visibility` **recria a pilha in-place**
  (limpa os pivôs `_MdlLbl_Pivot` e re-adiciona com a visibilidade por linha de
  `_add_member_labels`), sem rebuild do modelo. `_any_member_label()` (qualquer das 4 ligada) decide
  construir colliders/labels. Persistidos em `[models]` (`show_member_labels`/`show_type`/`show_name`/
  `show_id`). Pensado para **inspecionar quais membros** o classificador reconhece (e pedir um membro novo).
  - **Cor por linha = cor do toggle (2026-06-20):** cada linha tem **cor própria** (Membro = azul-ciano,
    Tipo = laranja, Nome = verde, ID = amarelo, Osso = laranja — `const _LABEL_LINE_COLORS`) aplicada ao
    `modulate` do `Label3D` **e** ao texto do `CheckButton` que a controla (`_apply_label_line_colors`,
    cobrindo os estados normal/hover/pressed/focus), para o usuário ligar de relance o controle ao seu rótulo 3D.
  - **Toggle "Esqueleto" (rótulo do osso avulso; renomeado de "SubMembro"/"Osso" em 2026-06-22):** 1º `CheckButton` do `LabelLinesRow`
    (`Osso`/`osso_check` — nome de nó/var mantidos; **no TOPO**, logo abaixo do toggle "Membro" e acima de Tipo;
    traduzido "Skeleton" em en — reusa a chave `Esqueleto`). Quando ligado **E** o filtro
    "Esqueleto" (modo "Todos os membros") tem um osso escolhido, desenha um **`Label3D` laranja**
    (billboard, sem depth-test) com **"Esqueleto: \<nome\>"** acima da sua região, preso via `BoneAttachment3D`.
    **Independente** do "Colisores de Esqueleto" (ex-"Realçar avulso"; pode-se ver só o nome, só a caixa, ou ambos) — segue a MESMA
    seleção. `_refresh_aux_labels` (chamado nos handlers de membro/sub-membro, em `_populate_members` e
    `_rebuild_member_colliders`) decide; `_label_aux_bones` desenha (nós `_AuxLbl_*`); `_clear_aux_labels`
    remove. Persistido em `[models]` (`show_osso`). "Todos os Esqueletos" rotula todos de uma vez.
  - **Anti-colisão entre membros (2026-06-20):** as 4 linhas de cada membro ficam sob um **pivô**
    (`_MdlLbl_Pivot`, filho do collider) para deslocarem juntas. A cada frame `_layout_member_labels`
    projeta a pilha de cada membro num retângulo de tela e, processando de cima para baixo, **empurra
    para baixo** quem se sobrepuser a uma pilha já posicionada — assim conjuntos de membros distintos
    nunca se sobrescrevem (cada conjunto continua inteiro, "um abaixo do outro"). O empurrão é convertido
    de pixels para metros (fator px/m da câmera na profundidade da âncora, robusto ao zoom/escala do
    fit-to-view) e aplicado movendo o pivô no espaço-mundo (para baixo = `-câmera.up`). Indexado em
    `_member_label_pivots`; sem pilhas, é no-op.
- **Dano** — aberto pelo **botão `DamageButton`** (à direita do "Voltar", em `UI/Actions`; texto "Dano"/"Damage").
  Antes era o toggle `DamageToggle` na lista; em 2026-06-23 virou **botão de ação dedicado** que invoca a tela de
  Dano (`_on_damage_button_pressed` → `_show_damage_panel = true` → `_refresh_damage_panel`); o `×` da janela fecha
  (`_on_damage_close`). (Janela renomeada de "Dano por membro" em 2026-06-22; o título `Title` exibe "Dano".)
  — **JANELA FLUTUANTE (estado em 2026-06-21):** o `DamagePanel` é uma **janela
  flutuante arrastável**, de **fundo PRETO OPACO**, **600×660**, com **todos os controles DENTRO dela**
  (os campos de valor NÃO flutuam mais sobre o modelo 3D — revertido em 2026-06-21).
  - **Janela (estilo Windows):** estrutura `DamagePanel(PanelContainer, âncora top-left) →
    Main(VBox) → TitleBar(PanelContainer) → TitleRow[Title(IGNORE) + CloseButton ×] · Margin →
    Scroll → VBox → Rows`. `_setup_damage_window` (em `_ready`) dá ao `DamagePanel` um `StyleBoxFlat`
    **preto opaco** (alpha 1) e estiliza a `TitleBar` (cinza-escuro opaco), põe `CURSOR_MOVE` e conecta
    `gui_input`→`_on_damage_titlebar_input` (clique-arrasta move `damage_panel.position`, preso à
    viewport; rede de segurança no `_process` solta o arraste se o botão for liberado fora da barra) e
    o `×`→`_on_damage_close` (fecha a janela: `_show_damage_panel = false` + `_refresh_damage_panel`). A **última posição é persistida**:
    `_save_damage_panel_pos` grava `Settings.config_file("models","damage_panel_pos")` (um `Vector2`)
    ao terminar o arraste, e `_setup_damage_window` a **restaura** na abertura (presa à viewport;
    default = posição do `.tscn`).
  - **ÁRVORE (Tree) NA janela (2026-06-21):** `_refresh_damage_panel` constrói um `Tree`
    (`DamageTree`, montado por `_setup_damage_tree` em `_ready`): cada MEMBRO é um galho; seus
    sub-membros (PART_*) são folhas SOB ele, exibidas com o **nome original do osso** (ex.: "↳ shoulderpad-adjust.L" sob "BRAÇO E"); órfãos vão p/ o
    galho "Outros sub-membros". **Colunas:** 0 Nome · 1 **Def** (`CELL_MODE_CHECK`) · 2 **Bônus %**
    (`CELL_MODE_RANGE` −100..500, passo 5; editável só com Def ligado) · 3 **Dono** (`CELL_MODE_RANGE`
    com texto vírgula-separado = dropdown, só sub-membros). Check off = **SEM valor próprio** (mostra o
    EFETIVO herdado via `effective_multiplier`); on = explícito (`set_multiplier`). **Nenhum valor é
    obrigatório.** `_on_damage_tree_edited` despacha por coluna; `_restamp_damage_metas` recarimba as
    metas e `_refresh_tree_inherited` reexibe os herdados (itens em `_damage_field_anchors` =
    `{item,group,owner}`). Reassociar o **dono** (col 3) pede **confirmação** (`_on_tree_owner_edited`)
    e reconstrói a árvore. **Footer** abaixo: só a linha "Adicionar sub-membro" (osso avulso + dono
    explícito + Adicionar → `_on_sub_member_added`). A **remoção é por linha (2026-06-22):** cada folha
    de sub-membro tem um **botão de LIXEIRA à direita do nome** (col 0; ícone vermelho gerado em código
    por `_make_trash_icon` → `ImageTexture`; `TreeItem.add_button` com id `_TRASH_BTN_ID`), e
    `_on_damage_tree_button` (sinal `Tree.button_clicked`) **pede confirmação** (`FloatingDialog.confirm`:
    "Deseja realmente remover associação do sub-membro: &lt;nome&gt; ?") e então remove aquele sub-membro
    (2026-06-22) — substituiu o antigo
    botão grande "Remover sub-membro" do footer (e o `_on_damage_tree_selected`/`_damage_remove_btn`,
    removidos). A associação dono→filho é salva em `LimbConfig` e **recarregada a cada add/remove** (via
    `_rebuild_member_colliders` → `_refresh_damage_panel`). **Espaçamento das linhas (2026-06-22):**
    `_setup_damage_tree` aplica overrides de tema (`v_separation`/`inner_item_margin_top`/`_bottom`) para
    o ícone de lixeira não encostar na linha vizinha. Ver [[sistemas/dano-localizado]].
  - **Janelas abriam FORA da tela — correção (2026-06-25):** os botões "não abriam" porque
    `DamagePanel`/`AIPanel` tinham offsets fixos no `.tscn` (`offset_left` 1300/1220, p/ telas largas)
    → em resoluções menores (ex.: 1280×720) a janela abria (`visible=true`) **fora da viewport, à
    direita** (invisível); o clamp do `_setup_*_window` rodava só no `_ready` com `size=0`, prendendo a
    posição na borda. **Fix:** `_clamp_window_to_viewport(panel)` chamado **deferido ao abrir** (já com
    size real) reposiciona a janela p/ caber inteira na tela. Painéis **ampliados p/ 760×620** (offsets
    novos) para o conteúdo (árvore de 4 colunas / lista de IA) não ficar apertado.
  - **Botões sem bloqueio mútuo + escopo por modelo (2026-06-25):** `_has_active_model_window()` foi
    **removido** — nenhum dos dois botões é bloqueado pela janela do outro. Abrir um **fecha o outro**
    (só UMA janela flutuante por vez, "switch"). **TOGGLE (2026-06-25):** clicar de novo no MESMO botão
    (Dano/IA) com a janela já aberta a **fecha** (`_on_*_button_pressed` checa `panel.visible` e fecha).
    **Scroll sobre a janela Dano/IA NÃO dá zoom no 3D (2026-06-25):** o `_unhandled_input` ignora a roda
    do mouse quando `_pointer_over_model_window()` (ponteiro sobre o `damage_panel`/`ai_panel` visível) —
    a roda só rola o conteúdo da janela; sobre o 3D, continua dando zoom. **Arraste tb congela sobre
    a janela (2026-06-25):** a rotação por arraste do mouse também respeita `_pointer_over_model_window()`
    — a câmera para de girar assim que o ponteiro entra na janela e volta a operar ao sair dela ou
    fechá-la; o helper passou a incluir `FloatingWindow.pointer_over_any_window()` (qualquer janela
    flutuante, não só Dano/IA). **Dano vale para QUALQUER modelo** em "Modelo completo"
    (`_supports_damage_editor` substituiu `_preview_is_whole_character`: não exige mais categoria
    "characters" — armas/rigs usam os colliders de membro). **IA só para personagens** com
    comportamentos definidos (`_supports_ai_editor` = `AIConfigLib.has_behavior_definitions` — hoje
    `red_robot`, `player`, `criatura_alada`; o `ai_button` fica `disabled` fora disso). O botão tem
    **texto "Inteligência Artificial"/"Artificial Intelligence"** (canônico PT desde 2026-06-25 — antes
    o `.tscn` trazia o nome só em inglês e o `models.pt.json` mapeava para si mesmo, sem traduzir).
    **Fix 2026-06-25:** `_refresh_ai_panel` abortava num override de tema inválido
    (`content.theme_override_constants.separation = 6`, acesso por ponto que não existe em GDScript),
    então a janela de IA NUNCA abria (erro em runtime antes de `ai_panel.visible = true`); trocado por
    `add_theme_constant_override("separation", 6)`. Ver `_on_damage_button_pressed`/`_on_ai_button_pressed`.
  - **Editor de IA virou `FloatingWindow` (2026-06-30):** o painel IA deixou de ser um `PanelContainer`
    do `.tscn` (com barra/×/arraste/posição manuais) e passou a ser uma **`FloatingWindow` runtime
    não-modal**, criada sob demanda em `_ensure_ai_window` (`remember_position_key = "ai_window"`,
    `min_window_size = (420,480)`). O conteúdo (ScrollContainer + `ai_list`) é repovoado por
    `_populate_ai_list`; abrir = `_open_ai_window` (`popup_centered`), fechar = `_close_ai_window`
    (×/ESC disparam `closed` → `_on_ai_window_closed` zera as refs). Assim a IA herda gap, anel de
    foco/ESC, supressão do Debug 2D de fundo e o click-forward do toggle (ver [[sistemas/debug-overlay]]).
    Removidos do `models.gd`: `ai_panel`/`ai_titlebar`/`ai_close_button`, `_setup_ai_window`,
    `_on_ai_titlebar_input`, `_save_ai_panel_pos`, `_on_ai_close` e o drag manual; o subtree `UI/AIPanel`
    saiu do `.tscn`. O **Dano** segue `PanelContainer` próprio (ligado ao dano por membro), com o gap
    aplicado à parte. `_pointer_over_model_window` agora cobre a IA via `pointer_over_any_window()`.
  - **Foco/Tab da janela Dano + foco inicial da tela (2026-06-30):** o `_ready` passou a focar o
    controle de Tab = 1 (`UINav.focus_tab_one` → 1ª por `tab_order` = Categorias). A **janela Dano** ganhou
    anel de foco LOCAL (`UINav.wire_tab_ring(damage_panel, damage_close_button)` em `_refresh_damage_panel`,
    com o **× sempre por último**): `Limbs` 1 → `Bone` 2 → `Owner` 3 → `Add` 4 → **× 5**; foca a árvore
    `Limbs` ao abrir. `Bone`/`Owner`/`Add` (runtime) recebem `tab_order` por `set_meta`; `Limbs` e `Close`
    têm `tab_order` 1 e 5 no `.tscn`.
  Aparece para **QUALQUER modelo em "Modelo completo"**
  (`_supports_damage_editor`); `_refresh_damage_panel` repopula ao trocar de modelo e some em mesh
  isolada. **Não** é persistido (abre fechado). A chave do modelo = nome da pasta
  (`_current_model_key`), igual ao `model_key` do gameplay. Os MEMBROS listados vêm do plano
  corporal do modelo: como o preview remove scripts (e não tem o `@export body_type`), a tela
  espelha o tipo na const `_MODEL_BODY_TYPE := {"red_robot":"biped","player":"biped"}` e resolve o
  classificador por `_body_type_for_current()`/`_current_classifier()` (`BodyPlans.for_type`).
  - **Membros = TODOS os do plano (2026-06-21):** o painel Dano e o combo "Membro" usam
    `_plan_member_entries()` — PERSONAGENS listam **todos** os membros do plano (`classifier.members()`,
    mesmo sem geometria no preview), na ordem e com os rótulos do plano (CABEÇA/TRONCO/BRAÇO E-D/
    PERNA E-D); ARMAS seguem os colliders (WeaponParts).
  - **Sub-membros aninhados no painel (2026-06-21):** cada `PART_*` aparece **indentado (↳, margem
    24px) sob o seu membro-dono**, agrupado pelo MESMO `_sub_member_owner_map` dos combos
    (helper `_sub_members_by_owner`) — painel e dropdown concordam. Sub-membro sem dono na lista vai
    para a seção **"Outros sub-membros"**.
  - **Dono EXPLÍCITO tem precedência no agrupamento (2026-06-22):** `_sub_member_owner_map` agora usa
    PRIMEIRO o dono salvo em `LimbConfig.sub_member_owner` (o que o usuário escolheu ao **Adicionar** ou
    no dropdown "Dono"), só caindo no `owner_hint`/hierarquia quando não há explícito. Antes a tela
    ignorava o explícito e reagrupava por nome/hierarquia — então um sub-membro recém-adicionado a um
    membro podia cair em "Outros" e **não aparecer sob o membro escolhido** (na árvore nem no dropdown
    "Sub-membro" ao selecionar o membro). Agora aparece e o vínculo persiste/recarrega corretamente.
  - **Subseção "Sub-membros" (2026-06-20):** cada sub-membro existente é uma linha (rótulo + `SpinBox`
    de bônus % + botão **× (remover)**, agora aninhada — ver acima). A linha de **adicionar**
    (`_add_sub_member_add_row`) é um
    `OptionButton` (`_aux_bone_candidates`) com os ossos AUXILIARES do esqueleto do preview
    — aqueles cujo `group_of` do classificador dá "" — + botão "Adicionar". `_on_sub_member_added`/
    `_on_sub_member_removed` chamam `LimbConfig.add_sub_member`/`remove_sub_member` e **reconstroem**
    os colliders do preview (`_rebuild_member_colliders` → `_clear_member_colliders` +
    `_ensure_member_colliders`), repondo gizmos/rótulos. Os membros principais continuam editáveis
    como antes; só os `PART_*` ganham esta subseção. Ver [[sistemas/dano-localizado]]. A const
    `_MODEL_STANDALONE_BONES` foi **removida** (os sub-membros vêm de `LimbConfig`/plano agora).
  - **Sub-membro PRESERVA o nome original (2026-06-22):** ao ser **adicionado a um membro-dono**, o
    `PART_*` **mantém o NOME ORIGINAL do osso** (o dono só agrupa o dano; não renomeia). O `_part_label`
    foi simplificado para `return bone_name` — o antigo rótulo **"PLACA &lt;MEMBRO&gt;"** (ex.: "PLACA BRAÇO E")
    foi descartado a pedido. A resolução de dono (`resolve_sub_member_owner`) segue valendo para o
    **agrupamento/herança de dano**, só não muda mais o rótulo exibido.
  - **Sob qual MEMBRO o sub-membro aparece (2026-06-21):** o dropdown "Sub-membro" agrupa cada
    `PART_*` pelo dono resolvido por **`LimbColliders.resolve_sub_member_owner`**: 1º **NOME** da peça
    (`owner_hint`), 2º **sobe na hierarquia** tentando
    `owner_hint`/`group_of` em cada ancestral. Destravou: **ombreiras do player**
    (`shoulderpad-adjust`, filhas do `chest`) → BRAÇO pelo nome; **escudos do braço do red_robot**
    (`L-/R-Shield`, filhos do `L-ARMIK`) → BRAÇO via o pai `L-ARMIK` na hierarquia. Ambos **agrupados sob
    BRAÇO E/D**, mas exibidos com o **nome original** do osso (ver item acima). Ossos que já são MEMBRO (ex.: `L-Shoulder` → BRAÇO) NÃO entram na
    lista "Adicionar sub-membro". Ver [[sistemas/dano-localizado]].
  - **Opção "Todos os membros" (2026-06-21):** o dropdown "Membro" tem,
    logo após "Selecione...", o item **"Todos os membros"** (`ALL_MEMBERS_LABEL`/`ALL_MEMBERS_VALUE`,
    traduzido "All members"; retraduzido na troca de idioma como "Modelo completo"/"Todos"). Ele
    **desloca os membros para os índices 2+** (`_member_value`/`_member_index_for_value` tratam índice
    1 = sentinela). Escolhido, **exibe TODOS os membros** (sem isolamento).
  - **Três dropdowns separados — Membro · Sub-membro · Esqueleto (reestruturado em 2026-06-23):** o
    `cboSubMembers` ("Sub-membro:", logo abaixo de "Membro") agora é SEMPRE a lista de sub-membros —
    nunca mais o filtro de ossos avulsos. Com **membro específico** lista os `PART_*` daquele membro;
    com **"Todos os membros"** oferece **SÓ "Selecione..." e "Todos os Sub-membros"** (2026-06-25 — sub-membros
    INDIVIDUAIS só aparecem ao escolher um membro específico). **"Todos os Sub-membros"**
    (`ALL_SUB_MEMBERS_LABEL`/`ALL_SUB_MEMBERS_VALUE`) não isola, mostra o modelo inteiro — **e, com "Colisores
    de Submembros" LIGADO, exibe os gizmos de TODOS os sub-membros de uma vez** (`_should_show_all_sub_colliders`).
    Os **ossos avulsos** saíram para um dropdown PRÓPRIO **"Esqueleto"**
    (`SkeletonRow` → `cboSkeleton`, label estático "Esqueleto:" auto-traduzido), exibido **só no modo
    "Todos os membros"** e **sempre visível nesse modo** — quando o modelo não tem ossos avulsos
    candidatos, aparece **desabilitado** (só "Selecione..."). Ele lista `_aux_bone_candidates`
    (`group_of == ""`, não promovidos), com **"Todos os Esqueletos"** (`ALL_AUX_VALUE`) no topo; só
    inspeção/realce (não isola). `_populate_sub_members` (sub-membros) e `_populate_skeleton` (ossos
    avulsos, chamado no topo daquele) populam; `_reset_skeleton` limpa. **Posição do "Esqueleto":** a
    `SkeletonRow` fica logo abaixo de "Sub-membro" (o antigo `ColliderEditBox` inline foi REMOVIDO — o
    editor de afastamento/escala agora é a janela flutuante reutilizável; ver acima). À direita do combo
    "Esqueleto" há o dropdown de geometria `cboSkeletonGeo` quando um osso avulso real está escolhido.
    **Carga do PERSISTIDO ao exibir (2026-06-25):** cada `_populate_*` (membro/sub/esqueleto) CARREGA o
    valor persistido (`sel_member`/`sel_submember`/`sel_skeleton`, lidos de Settings) sempre que o dropdown é
    (re)exibido; sem valor salvo ou inválido para o contexto → **"Selecione..."**. Então **"Todos os membros"
    só "reseta" Sub-membro/Esqueleto a "Selecione..." quando não acha persistido válido** (ex.: um `PART_*` de
    membro específico não casa no modo "Todos os membros" → "Selecione..."; mas "Todos os Sub-membros" ou um
    osso avulso salvos voltam). `_restore_selection_chain` **não** restaura membro/sub/esqueleto
    explicitamente — `_on_mesh_selected(1)` roda `_populate_members`, que faz a carga. (A flag `_restoring`
    e o reset em `_on_member_selected` foram REMOVIDOS.)
  - **Toggle "Colisores de Esqueleto" (renomeado de "Realçar avulso"→"Esqueleto"→"Colisores de Esqueleto" em 2026-06-22) + "Todo o esqueleto" (2026-06-21; item antes "Todos os ossos avulsos"):** como os personagens são UMA
    malha skinada (partes não separáveis por nó), o filtro **DESTACA sem esconder**: o toggle
    `AuxHighlight` (`_show_aux_highlight`, persistido) desenha uma **forma laranja translúcida**
    (sem depth-test, presa via `BoneAttachment3D`) sobre a região do osso avulso escolhido — AABB dos
    vértices DOMINANTES do osso via `LimbColliders.bone_vertex_box` (static). O item **"Todos os ossos
    avulsos"** (`ALL_AUX_VALUE`) no topo do filtro realça todos de uma vez; "Selecione..." / toggle off
    = modelo inteiro sem realce. `_refresh_aux_highlight` (chamado nos handlers de membro/sub-membro,
    em `_populate_members` e no `_rebuild_member_colliders`) decide o quê; `_highlight_aux_bones`
    desenha; `_clear_aux_highlights` remove (nós com prefixo `_AuxHL_`).
    **Forma por geometria (2026-06-25):** `_highlight_aux_bones` desenha na **geometria** do osso (salva em
    `LimbConfig.collider_shape("PART_<osso>")`): `SHAPE_NONE` ("Selecione...") → **SEM realce**; **sem escolha ("")
    → AUTODETECTA** pelo formato (`_auto_geo_for_box`); forma salva → essa. Desenha via
    `LimbColliders.make_shape` + `_solid_mesh_for_shape`, aplicando também o **afastamento/escala** salvos do
    osso — então o realce **PREVISUALIZA o collider** que o osso teria se promovido, **sem promovê-lo**. A
    janela de Afastamento/Escala chama `_refresh_aux_highlight` ao mudar, então a prévia acompanha ao vivo.
  - **Isolamento EXCLUSIVo (2026-06-21):** `_current_focus_groups` mostra **uma peça por vez** —
    Membro escolhido **sem** Sub-membro → só o collider do MEMBRO; **com** Sub-membro → só aquele
    sub-membro. "Todos os membros" → o `cboSubMembers` isola o `PART_*` escolhido (ou `null` = mostra
    tudo, em "Selecione..."/"Todos os Sub-membros"); o dropdown "Esqueleto" (`cboSkeleton`) nunca isola.
  - **Colisores gateados por toggle, POR TIPO (2026-06-21; separado em 2026-06-22):** o ramo de foco de
    `_refresh_member_overlays` exibe o gizmo conforme o **toggle MESTRE do tipo** do grupo em foco:
    MEMBRO → **"Colisores de Membro"** (`_show_colliders`); SUB-MEMBRO (PART_*) → **"Colisores de
    Submembros"** (`_show_sub_colliders`) — `giz_on = in_focus and (_show_sub_colliders if PART_ else
    _show_colliders)`. Na visão GERAL (sem foco), `_apply_colliders_visibility` mostra os colliders de membro
    **SÓ quando "Membro" está em "Todos os membros"** (`cbo_members.selected == 1` + toggle "Colisores de
    Membro"; em "Modelo completo"/"Selecione..." = **NENHUM**, 2026-06-25 — antes o toggle sozinho mostrava
    todos) e **esconde os PART_***; o sub-membro só aparece isolado, via seu toggle — **exceto** no modo "Todos os
    Sub-membros" + "Colisores de Submembros" on, que mostra TODOS os sub-membros de uma vez (2026-06-25,
    `_should_show_all_sub_colliders`). O isolamento dos **rótulos**
    continua independente dos toggles de collider. Obs.: ossos que já são MEMBRO (ex.:
    `shoulder.L/.R` → BRAÇO) **não** entram na lista "Adicionar sub-membro" (que só oferece os
    auxiliares, `group_of == ""`); o "ombro" como sub-membro é a placa `shoulderpad-adjust` (exibida com
    esse nome original, agrupada sob BRAÇO), pois `shoulderpad.L/.R` cru tem 0 vértices.

⚠️ Vários modelos disparam som por **tracks de animação** (`type = "audio"`/`"method"`,
não só autoplay). Por isso `_apply_audio_state()` **muta** (volume_db = -80) os emissores
quando o toggle Audio está desligado e restaura o **volume autorado** (capturado por
`_capture_av`) quando religa — assim o áudio disparado pela própria animação também respeita
o toggle Audio, sem precisar reconstruir o preview.

🔁 `_capture_av()` também **desativa todo `AnimationTree`** (`active = false`) ao montar o
preview, para que ele não pose o esqueleto **em paralelo** com o clip tocado direto no
`AnimationPlayer`.

🎭 **Anti-"dois modelos" do red_robot (2026-06-18):** ao ligar a animação o red_robot aparecia
**duplicado/deslocado**. Duas causas, ambas em `_capture_av`/`_apply_animation_state`:
- **Root motion:** os clips carregam o root motion num osso (`Skeleton3D:MASTER`) que o
  `AnimationTree` extraía e o script aplicava ao corpo. Tocando o clip **direto** no
  `AnimationPlayer`, esse osso era APLICADO, transladando o esqueleto (~1,6 m em Z) → segundo
  modelo atrás. Correção: `_capture_av` copia `tree.root_motion_track` p/ o player que a tree
  dirigia → o clip toca **no lugar** (root motion extraído e descartado; drift = 0).
- **Players de efeito/morte:** o red_robot tem 4 `AnimationPlayer` (locomoção + `ShootAnimation` +
  `Explosion`/kaboom + blast). O preview tocava o 1º clip de **cada** player → o kaboom
  revelava os destroços de morte (cópias de partes) sobre o modelo. Correção: sem clip escolhido
  no dropdown **nada toca** (2026-06-18 — antes o player principal tocava um clip default/idle);
  com um clip explícito do dropdown, `_apply_animation_state` o toca **só** em quem o tiver e para
  todos os outros players (ex.: escolher "kaboom" mostra a explosão de propósito, sem o blast/shoot
  junto). O **player principal** (`_main_anim_player` = o que a tree dirige, ou o mais rico sem tree)
  segue sendo identificado em `_capture_av` só para achar o `_main_body_root` (corpo vivo a esconder
  nos clips de morte).
- **Clip de morte/explosão esconde o corpo vivo (2026-06-18):** o clip `kaboom` torna o nó `Death`
  (destroços = cópias de partes) **visível** mas NÃO esconde o corpo vivo (isso era feito pelo script,
  removido no preview) → corpo + destroços = "dois modelos". `_apply_animation_state` esconde o
  `_main_body_root` (raiz do corpo, ex.: `RedRobotModel`) quando o clip escolhido é de morte
  (`_is_death_clip`: kaboom/explo/death/die/destr), deixando só a explosão.

(Os emissores vão pro bus `SFX` — ver [[sistemas/audio]].) Os estados de **rotação,
animação, efeitos especiais, audio, colisores, rótulos e Tipo/Nome/ID/Osso** são **persistidos** na
seção `[models]` de `user://settings.ini` via `Settings.config_file` (`_save_toggle` em cada
handler; `show_member_labels` desde 2026-06-20, `show_type`/`show_name`/`show_id` desde 2026-06-21,
`show_osso` desde 2026-06-22)
e relidos em `_ready` antes de conectar os sinais, então a tela reabre como foi deixada. O toggle
**Dano por membro** é a exceção — **não** é persistido (abre sempre fechado).

### Persistência da seleção + restauração da cadeia (2026-06-18)

Além dos toggles, **toda escolha dos dropdowns** (Categoria · Prefixo · Modelo · Parte ·
Animação · Efeitos) é persistida na mesma seção `[models]` por um **valor estável** — não o
índice — via `_save_selection(key, value)` em cada `_on_*_selected`: `sel_category` = chave da
categoria, `sel_prefix` = token do prefixo, `sel_model` = nome do modelo, `sel_part` = rótulo da
malha **ou** a sentinela `WHOLE_MODEL_VALUE` (`"__whole_model__"`) p/ "Modelo completo",
`sel_animation` = texto do clip, `sel_effect` = sentinela `ALL_VALUE` (`"__all__"`) p/ "Todos"
**ou** o texto do item (`_effect_value`; o inverso `_effect_index_for_value` resolve p/ índice).
Usar a sentinela p/ "Todos" evita quebrar a restauração quando o idioma muda (o rótulo é
traduzido). Por isso a restauração sobrevive a um re-scan da biblioteca em ordem diferente.

`_restore_selection_chain()` (chamada no fim de `_ready` no lugar do antigo
`select(0)`+`_on_category_selected(0)`) **replaya a cadeia de cima p/ baixo**: como `select()`
**não** emite `item_selected`, cada passo chama **também** o handler explicitamente, populando o
próximo combo como um clique real. Os `_find_*_index` resolvem o valor salvo p/ o índice atual de
cada combo. Regra de parada por nível:

- **valor vazio** (o usuário parou ali) → deixa o combo no placeholder **habilitado**, pronto p/
  continuar. Com tudo vazio = **início em branco** normal (nada previsualizado, nenhum item
  auto-selecionado — ver [[convencoes/dropdowns]]).
- **valor inexistente hoje** (escolha salva sumiu da biblioteca, "não há mais dados") →
  **desabilita esse combo**; como o handler dele não roda, todos os de baixo ficam desabilitados
  também. Animação e Efeitos são **folhas paralelas** de "Modelo completo": cada uma é restaurada
  independente (stale → desabilita só ela; vazia → fica no placeholder).

### Membros e centralização (Personagens/Armas)

Para **Personagens** e **Armas**, `_preview_whole_model` constrói os colliders de
membro (via [[arquivos-chave/limb-colliders-gd|LimbColliders]]) e `_add_member_labels`
flutua um `Label3D` com o nome do membro (CABEÇA, TRONCO, BRAÇO…) sobre cada collider.
A fonte do rótulo é **36** (¼ menor que os 48 originais — 2026-06-17), com outline 9.

**Rótulos: 100% locais à cena (2026-06-21):** cada linha do stack TYPE/Name/ID/Membro segue o
**seu** toggle da cena Models (Membro + checkboxes Tipo/Nome/ID), sem **nenhuma** leitura do
Debug 3D global. `_add_member_labels` nomeia cada linha com o prefixo `_MdlLbl_` e
`_apply_member_labels_visibility` **recria o stack in-place** (limpa os `_MdlLbl_*` e re-adiciona
com a visibilidade por linha). Como o nó raiz da cena está no grupo **`no_debug_overlay`**, o
`DebugOverlay` (autoload) já pula a cena inteira — então não há rótulo dobrado nem gizmos globais
no preview. (A chamada `DebugOverlay.exempt_member_labels(instance)` em `_preview_whole_model`
permanece como defesa redundante.) Os rótulos do browser usam os overrides de
cabeça/tronco) são a única fonte.

> [!note] Collider de CABEÇA do red_robot = rosto + olhos (2026-06-18)
> O membro CABEÇA do red_robot é montado a partir de `mouth_eyes` **+ `L-EYE`/`R-EYE`**
> (override em `_MODEL_HEAD_BONES` e em `red_robot.gd`). Os olhos caem na exclusão por "eye",
> então sem forçá-los a cabeça pegava só o painel do rosto (~42 vértices) e virava uma esfera
> minúscula escondida na caixa do TRONCO. Com os olhos, a esfera fica ~`r=0.34` (rosto inteiro).
> Vale tanto para o gizmo do browser quanto para a **hitbox de headshot** em jogo (mesmo
> `LimbColliders`) — o headshot ficou um alvo justo.

> [!note] Collider de CABEÇA do player = CÁPSULA (2026-06-21)
> A cabeça do **player** usa uma **cápsula** (não esfera): `player.gd` seta `lc.head_shape =
> "capsule"` e a tela Models espelha por `_MODEL_HEAD_SHAPE := {"player":"capsule"}`. A cápsula é
> alinhada ao eixo mais longo da cabeça (mesma orientação do osso) e mantém o **raio cheio**
> (`make_member_shape` → `make_shape("capsule", aabb, cap_radius=false)`), sem o `CROSS_SHRINK`
> dos demais membros, para **cobrir toda a malha** da cabeça. Ver [[sistemas/dano-localizado]].

**Centralização posada (2026-06-17):** o AABB de uma malha **skinada** vem da pose de
**bind**, que no red_robot fica ~1,4 m fora da pose idle em Z. Usá-lo ancoraria o pivô
**atrás** do corpo, e o modelo "escaparia" ao girar. Por isso, quando há colliders de
membro, `_posed_member_bounds()` mede o corpo **na pose real** (a partir dos colliders) e
`_fit_to_view(model, 2.0, posed)` centra/escala por esse AABB — o modelo gira **no lugar**.

## Extração ("Salvar como cena 3D")

`_on_save_pressed()` re-instancia o modelo, acha o 1º nó com a malha selecionada
(com a colisão filha, se houver), zera o transform para a origem, re-define owners
e empacota numa `.tscn` standalone em `library/extracted/<categoria>/<nome>.tscn`.

## Galeria "Exportados"

`library/extracted/Exported.tscn` (`exported.gd`): escaneia `library/extracted/`,
instancia todas as cenas `.tscn`/`.glb` (menos ela mesma), normaliza o tamanho e
dispõe lado a lado. Botão "Exportados" navega até ela; "Voltar"/ESC retornam a
`models.tscn`. **Obs.:** o scan é só da raiz de `extracted/`; o "Salvar" grava em
subpastas `extracted/<categoria>/` (cenas extraídas não aparecem na galeria sem
scan recursivo).

## Entrada sintética "Level Base (dinâmicos)"

`level_base.gd` monta dinamicamente **RedRobot** (`spawn_robot`) e **Player**
(`add_player`). Os `.glb` visuais desses foram copiados para `library/extracted/`
(`red_robot.glb`, `player.glb`). Na categoria **Personagens** há a entrada
sintética **"Level Base (dinâmicos)"** (`group_paths`) que, ao ser selecionada,
exibe os dois modelos lado a lado (`_show_group`, ignora o catálogo de malhas).

## Amarrações / reutilização (levantamento)

A única amarração que impede separar é o *skinning* a `Skeleton3D` — só nos
**personagens** (Player, RedRobot): a unidade reutilizável é o personagem inteiro.
O conteúdo estático é uma paleta pequena de malhas distintas instanciadas com
transform embutido + colisão filha (`StaticBody3D`/`CollisionShape3D`): Core 35,
CoreOutLight 4, Lights 4 (+luminárias), Props 86 (+`VehicleWheel3D` das scificars),
Structure 104. Forklift tem hierarquia limpa (3 empilhadeiras). Scificars (em
props.glb) ficam planas (rodas + carroceria como irmãos, sem nó-pai por carro).

## Viewer de controles 2D (análogo)

`scenes2D/controls/controls.tscn` (`controls.gd`) é o equivalente 2D desta tela:
um dropdown lista cada controle em `scenes2D/controls2D/<nome>/<nome>.tscn` e o
selecionado é instanciado num `SubViewport` de preview (isola controles que cobrem
a tela inteira, como `scanlines`/`pause_menu`, e o `cyberpunk_hud`, que é
`CanvasLayer`). Acessível pela tela `developer` (botão "Controles 2D", ao lado de
"Modelos 3D"). Soltar uma nova pasta de controle aparece automaticamente.

`_center_preview` centraliza o controle no SubViewport **horizontal e verticalmente
sempre que possível** (2026-06-16): espera 1 frame pro layout assentar e só recentra
o eixo em que o controle é **menor** que o viewport — controles que já preenchem a
área toda (scanlines/hud/pause_menu) ficam onde estão.

## Relacionado

- [[fluxos/fluxo-de-cenas]]
- [[arquivos-chave/main-gd]]
- [[convencoes/formatacao]]
