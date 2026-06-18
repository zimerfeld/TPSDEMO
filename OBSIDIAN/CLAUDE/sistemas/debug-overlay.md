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

**Tooltips Debug 3D na cena Models (2026-06-18):** o browser desenha a **mesma pilha** do overlay
(TYPE/Name/ID/Membro), em **ciano**, com as **mesmas sub-chaves** (`show_type_3d`/`show_name_3d`/
`show_id_3d`/`show_members`) — só que aqui ele tem os overrides de osso por personagem
(cabeça/tronco/placas) que o classificador global não tem. Assim os tooltips do Debug 3D
aparecem **também na cena Models**, sobre cada collider de membro do preview (incl. as placas das
pernas, `PLACA PERNA E/D`). Antes o browser só desenhava o nome do membro (amarelo).

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
