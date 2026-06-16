# Biblioteca de Modelos (tela Models)

Tela `scenes3D/models/models.tscn` (`models.gd`): navegador + extrator dos
modelos 3D do projeto. Alcançada por **developer → Modelos 3D**; volta com
"Voltar" (→ developer) e abre a galeria com "Exportados" (→ `Exported.tscn`).

## Biblioteca de assets

Tudo sob `res://library3D/<tipo>/<modelo>/`:

- `characters/` — `player`, `red_robot`, `criatura_alada` e os **14 robôs**
  `robot_01..07_*_{infantil,adulto}` (importados de
  `C:\GODOT\MODELOS\robos_3d_godot_infantil_adulto` em 2026-06-16; prefixo "robot")
- `props/` — `forklift`
- `structures/` — `core`, `core_out_light`, `lights`, `props`, `structure`
- pastas de suporte (NÃO categorias): `geometry/` (materiais `.tres`), `textures/`, `extracted/` (saída)

`_scan_library()` varre só as categorias fixas em `const CATEGORIES`
(characters/props/structures). Por modelo prefere `.glb`/`.gltf` (malha crua, sem
rodar script de gameplay) e cai para `.tscn`. Novo modelo em
`library/<tipo>/<nome>/` com um `.glb` aparece sozinho — nada a editar em código.

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

### Rotação do preview

`_yaw`/`_pitch` separados → `model_holder.rotation = Vector3(_pitch, _yaw, 0)`
(roll sempre 0, só eixos ortogonais). Ao arrastar, **ambos** `_pitch` (cima/baixo) e
`_yaw` (esquerda/direita) ficam travados em **±90°** (2026-06-16). O modelo é
**nivelado** antes do giro: `_preview_whole_model()` zera a rotação embutida da raiz
do `.glb` (desconsidera inclinações angulares). Arrastar com o botão esquerdo sobre a
área 3D move yaw/pitch; o toggle **Rotação** liga/desliga a rotação automática (só
yaw, sem trava — gira como turntable). `UI` raiz tem `mouse_filter = 2` para o
arrasto chegar a `_unhandled_input`.

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

## Relacionado

- [[fluxos/fluxo-de-cenas]]
- [[arquivos-chave/main-gd]]
- [[convencoes/formatacao]]
