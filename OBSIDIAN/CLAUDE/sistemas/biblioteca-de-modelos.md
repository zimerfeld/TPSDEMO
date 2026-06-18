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

**StatusLabel (2026-06-18):** a linha de status (vermelha, +2pt) é reposicionada
dinamicamente logo **acima** do combo a que a mensagem se refere (`_set_status(template,
row, args)` + `_apply_status` movem o label com `move_child`). Textos via `Locale.tr_key`,
label no `Locale.SKIP_GROUP` (ver [[sistemas/localizacao]]).

**Após selecionar a Parte (2026-06-18):** o status **NÃO** mostra mais mensagem de
quantidade ("Modelo completo — N parte(s)") nem rótulo de parte ("Parte: X"). Em vez disso,
no **"Modelo completo"** o status só aparece **quando** os combos Animação e/ou Efeitos
Especiais têm opções, posicionado **acima** do primeiro deles (`_update_whole_model_status`):
"Selecione uma animação." (acima de `AnimationRow`), "Selecione um efeito." (acima de
`EffectsRow`), ou "Selecione uma animação e/ou um efeito." quando ambos. Numa **parte
isolada** (sem combos abaixo) o status fica **vazio** (`_clear_status`).

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

Toggles atuais (ordem em 2026-06-18): **Rotação · Animação · Efeitos especiais · Audio ·
Colisores** (o antigo "Som" virou **Audio**; o toggle **Falas** foi REMOVIDO — o Audio agora
cobre todos os emissores, inclusive vozes). Cada toggle é o **interruptor mestre** da sua
categoria:

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
- **Audio** — toca **todos** os emissores do modelo (movimentação andar/correr/saltar,
  motor, tiro, explosão, vozes…); desligado, silencia. Aplicado por `_apply_audio_state()`.
  (Não há mais toggle "Falas" separado.)
- **Colisores** — `_apply_colliders_visibility()` adiciona/remove os gizmos wireframe
  (`_add_collider_gizmos`, idempotente, nó `_ColliderGizmo`) **sem rebuild**; constrói os
  colliders de membro sob demanda uma vez (`_ensure_member_colliders`). Para **Personagens/
  Armas** desenha gizmo **só dos colliders de MEMBRO** (`_is_member_collider`, meta
  `member_label`); pula o collider de corpo genérico do modelo (ex.: a cápsula de corpo do
  red_robot) e as áreas de detecção/morte, que só eram ruído envolvendo tudo (2026-06-18).
- **Efeitos especiais** — mostra/esconde **tudo o que sobra** ligado ao modelo e que
  nenhum outro toggle cobre: partículas, luzes e malhas presas a osso (muzzle/laser),
  coletadas por `_collect_effect_nodes`. O combo **"Efeitos Especiais"** isola **um**
  efeito (mostra só ele); "Selecione..." mostra **todos** (só com o toggle ligado). A
  visibilidade é aplicada por `_apply_effects_visibility` sem reconstruir o preview.

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

(Os emissores vão pro bus `SFX` — ver [[sistemas/audio]].) Os 5 estados (rotação,
animação, efeitos especiais, audio, colisores) são **persistidos** na seção
`[models]` de `user://settings.ini` via `Settings.config_file` (`_save_toggle` em cada
handler) e relidos em `_ready` antes de conectar os sinais, então a tela reabre como
foi deixada.

### Membros e centralização (Personagens/Armas)

Para **Personagens** e **Armas**, `_preview_whole_model` constrói os colliders de
membro (via [[arquivos-chave/limb-colliders-gd|LimbColliders]]) e `_add_member_labels`
flutua um `Label3D` com o nome do membro (CABEÇA, TRONCO, BRAÇO…) sobre cada collider.
A fonte do rótulo é **36** (¼ menor que os 48 originais — 2026-06-17), com outline 9.

**Rótulos seguem os toggles Debug 3D + Membros (2026-06-18):** os labels de membro do
browser só aparecem quando **ambos** os toggles do [[sistemas/debug-overlay]] (tela
developer) estão ligados — `_member_labels_enabled()` lê `game/debug_3d` **e**
`game/show_members` do `Settings.config_file`. Com Debug 3D ligado mas Membros **desligado**
(ou Debug 3D desligado), **nenhum** label é desenhado. Os **colliders** de membro continuam
sendo construídos sempre (enquadramento posado + gizmo do toggle Colisores) — só os rótulos
são condicionados. Como o `DebugOverlay` (autoload) **também** rotularia o esqueleto do
preview, `_preview_whole_model` chama `DebugOverlay.exempt_member_labels(instance)` para o
overlay **pular só os labels de membro** desse subtree (gizmos de esqueleto/mesh do overlay
seguem valendo) — assim não há rótulo dobrado, e os do browser (com overrides de
cabeça/tronco) são a única fonte.

> [!note] Collider de CABEÇA do red_robot = rosto + olhos (2026-06-18)
> O membro CABEÇA do red_robot é montado a partir de `mouth_eyes` **+ `L-EYE`/`R-EYE`**
> (override em `_MODEL_HEAD_BONES` e em `red_robot.gd`). Os olhos caem na exclusão por "eye",
> então sem forçá-los a cabeça pegava só o painel do rosto (~42 vértices) e virava uma esfera
> minúscula escondida na caixa do TRONCO. Com os olhos, a esfera fica ~`r=0.34` (rosto inteiro).
> Vale tanto para o gizmo do browser quanto para a **hitbox de headshot** em jogo (mesmo
> `LimbColliders`) — o headshot ficou um alvo justo.

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
