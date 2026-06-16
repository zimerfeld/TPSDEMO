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

Os combos **"Animação"** (`AnimationRow`) e **"Efeitos Especiais"** (`EffectsRow`,
abaixo de Animação) só aparecem quando a Parte é **"Modelo completo"** (2026-06-16):
`_populate_animations()`/`_populate_effects()` mostram as linhas e
`_reset_animations()`/`_reset_effects()` as escondem (placeholder e partes isoladas).
Ambos só se aplicam ao modelo montado.

**Cascata de reset (2026-06-16):** mudar qualquer selector reseta **todos** os de
baixo para "Selecione..." e reabilita só o filho imediato. As funções de reset
(`_reset_meshes_and_preview`, `_on_model_selected`) agora chamam também
`_reset_animations()`+`_reset_effects()`, então os dois combos de baixo entram na
cascata (antes ficavam "presos" visíveis ao trocar um selector acima).

### Rotação do preview

`_yaw`/`_pitch` separados → `model_holder.rotation = Vector3(_pitch, _yaw, 0)`
(roll sempre 0, só eixos ortogonais). Ao arrastar, **ambos** os eixos vão até
**±180°** (2026-06-16): `_yaw` (esquerda/direita) gira o modelo até as costas e
`_pitch` (cima/baixo) tomba o modelo de ponta-cabeça. O modelo é **nivelado** antes
do giro: `_preview_whole_model()` zera a rotação embutida da raiz do `.glb`
(desconsidera inclinações angulares). Arrastar com o botão esquerdo sobre a área 3D
move yaw/pitch; o toggle **Rotação** liga/desliga a rotação automática (só yaw, sem
trava — gira como turntable). `UI` raiz tem `mouse_filter = 2` para o arrasto chegar
a `_unhandled_input`.

### Toggles (preferência + persistência)

Toggles atuais (2026-06-16): **Rotação · Animação · Audio · Falas · Colisores ·
Efeitos especiais** (o antigo "Som" virou **Audio**). Cada toggle é o **interruptor
mestre** da sua categoria:

- **Animação** — com o toggle desligado **nada anima**, mesmo com um clip escolhido
  no dropdown "Animação"; `_on_animation_selected` retorna cedo e `_apply_av_playback`
  só toca dentro do `if _play_animation`. Ligado, toca o clip do dropdown (com
  fallback para o autoplay e depois o 1º clip).
- **Audio** — toca **todo emissor que NÃO é fala** (movimentação andar/correr/saltar,
  motor, tiro, explosão…); desligado, silencia.
- **Falas** — toca **só** os emissores de **fala/grito**, classificados pelo nome do
  nó (`_is_speech_audio`: voz/voice/fala/grito/scream/shout/yell/…). Desligado, silencia.
- **Efeitos especiais** — mostra/esconde **tudo o que sobra** ligado ao modelo e que
  nenhum outro toggle cobre: partículas, luzes e malhas presas a osso (muzzle/laser),
  coletadas por `_collect_effect_nodes`. O combo **"Efeitos Especiais"** isola **um**
  efeito (mostra só ele); "Selecione..." mostra **todos** (só com o toggle ligado). A
  visibilidade é aplicada por `_apply_effects_visibility` sem reconstruir o preview.

⚠️ Vários modelos disparam som por **tracks de animação** (`type = "audio"`/`"method"`,
não só autoplay). Por isso `_apply_av_playback` **pré-muta** (volume_db = -80) os
emissores cujo toggle está desligado **antes** de iniciar a animação — assim o áudio
disparado pela própria animação também respeita Audio/Falas. Como o preview é
reconstruído a cada toggle, o volume autorado volta sozinho quando religa.

(Os emissores vão pro bus `SFX` — ver [[sistemas/audio]].) Os 6 estados (rotação,
animação, audio, falas, colisores, efeitos especiais) são **persistidos** na seção
`[models]` de `user://settings.ini` via `Settings.config_file` (`_save_toggle` em cada
handler) e relidos em `_ready` antes de conectar os sinais, então a tela reabre como
foi deixada.

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
