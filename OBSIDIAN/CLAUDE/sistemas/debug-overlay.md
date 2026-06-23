# Sistema — Debug Overlay & Modo Desenvolvedor

Overlay de debug global (`autoload/debug_overlay.gd`, autoload **DebugOverlay**), ligado
pela tela **developer** (`scenes2D/developer/`) e pela aba "Debug" das settings. Todos os
toggles persistem em `Settings` (seção `game`) e aplicam na hora (`DebugOverlay.refresh()`).

## Tela developer — duas colunas

A tela separa os controles em **duas colunas**, cujos tooltips usam **cores claras
diferentes** para distinguir a origem:

- **Debug 2D** (rótulos amarelo claro) — master `debug_2d` + linhas `show_type` /
  `show_name` / `show_id`. Controla os tooltips 2D (borda colorida + TYPE/Name/ID) em
  cada `Control`. Texto dos tooltips em **amarelo claro**. **Debug 2D ligado sozinho não
  mostra nada**: a borda e os tooltips só aparecem quando ≥1 linha (Type/Name/Id) está
  selecionada — as linhas são sub-toggles dependentes, igual à coluna Debug 3D (sem linha
  padrão implícita).
- **Debug 3D** (rótulos ciano claro) — master `debug_3d` + linhas `show_type_3d` /
  `show_name_3d` / `show_id_3d` + `show_members` + `show_skeleton3d` + `show_mesh3d`.
  Rótulos `Label3D` por membro do esqueleto, em **ciano claro**.

As linhas de cada coluna ficam **acinzentadas** (botões `disabled`) enquanto o master
da coluna está desligado — a dependência fica explícita. Seção geral acima das colunas:
**HUD FPS** (`hud_fps`) e **Malha no Solo** (`show_grid`).

## Preview do modelo do player (2026-06-23)

À **direita da coluna Debug 3D**, um painel (`UI/Margin/Main/Content/PreviewPanel`, um `PanelContainer`)
mostra o **robô do player** girando, para ver ao vivo o efeito dos toggles. O layout é **baseado em
containers** (ver [[convencoes/layout-responsivo|layout responsivo]]): `Content` é um `HBoxContainer`
com três filhos `size_flags = Expand` — `Col2D`, `Col3D` e o `PreviewPanel` — então o painel tem a
**mesma altura** das colunas e a largura se divide responsivamente (sem offsets fixos). O modelo
(`library3D/characters/player/player.glb`, escala `0.803991` como no
[[arquivos-chave/chooseplayer-gd|chooseplayer]]) é instanciado por `developer.gd::_setup_preview()`
dentro de um `SubViewport` com **mundo próprio** (`own_world_3d`, `render_target_update_mode = Always`),
câmera e `DirectionalLight3D` próprios; toca a idle (`Idlecombatrest`) e gira em `_process`. O
`ModelHolder` usa `unique_name_in_owner` (acesso via `%ModelHolder`), desacoplado da hierarquia.

**Por que reflete os toggles:** o preview fica **FORA** do grupo `no_debug_overlay`, então o `_scan`
(que varre a `root` inteira, incluindo dentro do `SubViewport`) acha o `Skeleton3D`/`MeshInstance3D` do
preview e aplica os mesmos overlays 3D (esqueleto/mesh/membros/type/name/id) controlados pela coluna
Debug 3D — os gizmos/`Label3D` são filhos do esqueleto, no mundo do `SubViewport`, então renderizam no
painel. `_setup_preview` chama `DebugOverlay.refresh()` para o estado já refletir ao entrar na tela.

## Rótulos 3D (por membro)

Para cada membro (CABEÇA/TRONCO/BRAÇO…) classificado por `BodyParts`, um
`BoneAttachment3D` segue a pose e empilha linhas `Label3D`: **TYPE** (classe do
`Skeleton3D`), **Name** (nome do nó), **ID** (instance id) e **Membro** (parte do corpo).
Cada linha liga/desliga pela sub-chave correspondente da coluna Debug 3D.

**Isenção de rótulos de membro (2026-06-18):** `DebugOverlay.exempt_member_labels(node)`
marca um subtree (grupo `_NO_MEMBER_LABELS_GROUP`) cujos rótulos são desenhados por **outro**
dono — o [[sistemas/biblioteca-de-modelos|browser de modelos]] desenha sua própria PILHA de
tooltips sobre o preview. `_add_3d_skeleton` pula esses esqueletos (via `_in_group_or_ancestor`),
evitando rótulo **dobrado**; os gizmos de **esqueleto/mesh** do overlay continuam aplicando.

**Debug 2D em TODAS as telas, sem exceção (2026-06-21):** o `_tag` deixou de checar
`_is_overlay_exempt` no ramo **2D** — os tooltips de Debug 2D agora aparecem em **qualquer cena**,
inclusive Models e o editor de Dano (antes isentas). A isenção `no_debug_overlay` passou a valer
**só para os overlays 3D** (rótulos de membro/gizmos de esqueleto/mesh) — ex.: robô decorativo do
menu e preview da Models (que desenha os próprios rótulos). Além disso, o **watermark do nome da
cena** (canto inferior esquerdo, no canvas persistente) ganhou **tooltip de Debug 2D**: como o
`_scan` pula o canvas persistente, `_build_overlays` registra o `_scene_name_label` explicitamente
(`_add_2d`) quando `debug_2d` está ligado; `_ready` monta o watermark ANTES de `_build_overlays`.

**Cena Models e o overlay 3D (2026-06-21):** o nó raiz da
[[sistemas/biblioteca-de-modelos|cena Models]] está no grupo **`_NO_OVERLAY_GROUP`**
(`no_debug_overlay`); hoje `_is_overlay_exempt` só faz o `_tag` pular os overlays **3D** da cena
(o 2D passa). O browser desenha sua PRÓPRIA
pilha de tooltips (TYPE/Name/ID/Membro, em ciano) sobre cada collider de membro, controlada pelos
**toggles dedicados da própria cena** (Membro + checkboxes Tipo/Nome/ID) — nada mais lê
`show_type_3d`/`show_members` etc. daqui. (A `exempt_member_labels` do preview permanece como
defesa redundante.)

## Malha no Solo (grid)

Grade wireframe 100 m × 100 m na origem, para escala/posição em telas 3D
(**Modelos 3D**, levels). Como o `main.gd` troca as telas como **filhas** do nó Main
(`current_scene` permanece o Main, tipo `Node`), o grid não pode olhar o tipo da raiz:
ele detecta a tela carregada ativa e procura qualquer `Node3D` descendente
(`_scene_has_3d`), anexando o grid a essa tela. Some nas telas 2D (menu/settings/developer).

## Sub-switches Debug 3D

- **Members** — rótulos por membro (linha "Membro: X").
- **Skeleton** — linhas brancas osso→pai, refeitas todo frame a partir da pose viva.
- **Mesh** — caixa wireframe ciano do AABB de cada `MeshInstance3D`.

Relacionado: [[sistemas/dano-localizado]] (mesmo classificador `BodyParts`),
[[sistemas/localizacao]], [[convencoes/ancoragem-ui]].
