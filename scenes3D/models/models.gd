extends Node

signal replace_main_scene(resource: PackedScene)

const DEVELOPER_PATH: String = "res://scenes2D/developer/developer.tscn"
const AIConfigLib := preload("res://effects_shared/ai_config.gd")
# Janela flutuante REUTILIZÁVEL (controles2D) usada como editor de Afastamento/Escala do collider.
const _FLOATING_WINDOW := preload("res://scenes2D/controls2D/floating_window/floating_window.tscn")

# Placeholder shown as the first, default-selected option of every dropdown.
# Picking it means "nothing chosen yet": dependent dropdowns reset to this same
# placeholder and the preview is cleared. In the prefix dropdown it doubles as
# "no filter" (it replaced the old "Todos"), so it lists every model.
const SELECT_LABEL: String = "Selecione..."

# Selectable option in the part dropdown (right below "Selecione...") that previews
# the whole assembled model. Picking a real part below it isolates one distinct mesh.
const WHOLE_MODEL_LABEL: String = "Modelo completo"

# Option listed right below "Selecione..." in the Efeitos Especiais dropdown, meaning
# "show every effect". Added only when the model actually exposes at least one effect.
# ALL_VALUE is the stable sentinel persisted for it (its visible label is translated, so
# restore keys off the sentinel, not the text).
const ALL_EFFECTS_LABEL: String = "Todos"
const ALL_VALUE: String = "__all__"

# Stable identifier persisted for the "Modelo completo" part selection. Its visible label
# is translated, so the restore code keys off this sentinel instead of the on-screen text.
const WHOLE_MODEL_VALUE: String = "__whole_model__"

# Option listed right below "Selecione..." in the Membro dropdown: "Todos os membros" — exibe
# TODOS os membros (sem isolamento) e ainda lista TODOS os sub-membros para escolher qualquer um
# individualmente. ALL_MEMBERS_VALUE é o sentinela estável (o rótulo visível é traduzido).
const ALL_MEMBERS_LABEL: String = "Todos os membros"
const ALL_MEMBERS_VALUE: String = "__all_members__"

# Item logo após "Selecione..." no dropdown "Sub-membro" quando "Todos os membros" está escolhido:
# "Todos os Sub-membros" — não isola nada (mostra o modelo inteiro), serve de "voltar a ver tudo".
const ALL_SUB_MEMBERS_LABEL: String = "Todos os Sub-membros"
const ALL_SUB_MEMBERS_VALUE: String = "__all_sub_members__"

# Item no topo do filtro "Esqueleto" (modo "Todos os membros"): realça os respectivos modelos
# 3D de TODOS os ossos avulsos de uma vez. Sentinela estável; rótulo traduzido.
const ALL_AUX_LABEL: String = "Todos os Esqueletos"
const ALL_AUX_VALUE: String = "__all_aux__"

# Prefixo dos nós de REALCE (caixa translúcida sobre a região de um osso avulso) e a cor do realce.
const _AUX_HL_PREFIX := "_AuxHL_"
const _AUX_HL_COLOR := Color(1.0, 0.6, 0.1, 0.35)   # laranja translúcido (distinto do verde dos colliders)

# Prefixo dos BoneAttachment3D que carregam o Label3D com o NOME do osso avulso (toggle "Esqueleto"),
# e a cor do texto (laranja, casando com o realce). Independente do realce: pode haver nome sem caixa.
const _AUX_LBL_PREFIX := "_AuxLbl_"
const _AUX_LBL_COLOR := Color(1.0, 0.6, 0.1)

# Prefixo dos Label3D "Submembro: <nome>" (toggle "Submembros"), presos ao corpo do sub-membro
# selecionado no dropdown. Roxo (igual à cor do texto do toggle "Submembros").
const _SUB_LBL_PREFIX := "_SubLbl_"
const _SUB_LBL_COLOR := Color(0.6, 0.25, 0.9)

# Root of the 3D model library. Models live in res://library3D/<tipo>/<modelo>/
# (e.g. characters/red_robot, props/forklift, structures/core). The selection
# dropdowns below are built by scanning this folder, so dropping a new model
# folder in here makes it show up automatically — no code change needed.
const LIBRARY_ROOT: String = "res://library3D"

# Model categories shown in the dropdown, in display order. Only these
# subfolders of LIBRARY_ROOT are scanned — support folders that also live under
# library/ (e.g. geometry/, textures/) are intentionally ignored here.
const CATEGORIES: Array[Dictionary] = [
	{"key": "characters", "label": "Personagens"},
	{"key": "propulsores", "label": "Propulsores"},
	{"key": "structures", "label": "Estruturas"},
	{"key": "weapons", "label": "Armas"},
]

# Models follow the Godot/Blender convention (front = -Z), but the preview camera
# sits on +Z looking toward -Z, so it would face the model's BACK. Rotate the holder
# 180° by default so the model's FRONT faces the user; the user's ±90° yaw drag then
# swings around the front.
const DEFAULT_FRONT_YAW: float = PI

# How fast the dragged model rotates, in radians per pixel of mouse motion.
const DRAG_SENSITIVITY: float = 0.01

# Auto-rotation speed in radians per second when the toggle is on.
const AUTO_ROTATE_SPEED: float = 0.6

# Mouse-wheel zoom: the camera slides along its view axis toward/away from the
# model. ZOOM_STEP is how much one wheel notch changes the target distance;
# ZOOM_MIN/MAX clamp it; ZOOM_SMOOTH is the per-second approach rate that makes
# the move glide instead of snapping.
const ZOOM_STEP: float = 0.6
const ZOOM_MIN: float = 1.2
const ZOOM_MAX: float = 12.0
const ZOOM_SMOOTH: float = 10.0

# Built at _ready by scanning LIBRARY_ROOT. Each entry:
#   {"key": String, "label": String, "models": Array[{"name", "path"}]}
var _categories: Array = []

# Currently selected model scene and its de-duplicated mesh catalog. A big level
# model bundles hundreds of placed MeshInstance3D, but they share a small palette
# of unique meshes — the catalog lists each distinct mesh once (the reusable
# asset), not every placement. Each entry:
#   {"label", "mesh": Mesh, "name": String, "count": int, "has_collision": bool, "skinned": bool}
# _model_scene is the mesh source used to build the catalog (the raw .glb when
# present). _display_scene is what the "Modelo completo" view instantiates: the
# authored .tscn (materials, effects, the intended visible variant) when one
# exists, otherwise the same scene as _model_scene.
var _model_scene: PackedScene = null
var _display_scene: PackedScene = null
var _mesh_catalog: Array = []
# Resource path of the currently previewed model, used to look up per-character
# data such as the head bone(s) that BodyParts can't infer from the name alone.
var _current_model_path: String = ""

# The models of the current category that pass the active prefix filter, in the
# same order as the Model dropdown — so the dropdown index maps straight back to
# an entry. Rebuilt whenever the category or prefix changes.
var _filtered_models: Array = []
# Active prefix filter ("" = ALL_PREFIXES_LABEL, i.e. no filtering).
var _prefix_filter: String = ""

# Rotation state. The holder either spins on its own (auto) or follows the mouse
# while the left button is held; dragging temporarily overrides auto-rotation.
# Yaw and pitch are tracked separately and rebuilt as an Euler rotation with no
# roll, so mouse motion only ever turns the model about the two orthogonal axes
# (horizontal -> yaw on Y, vertical -> pitch on X).
var _auto_rotate: bool = false
var _dragging: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0
# Yaw frontal BASE do modelo atual (antes do drag do usuário). Padrão DEFAULT_FRONT_YAW
# (180°, convenção front=-Z). Alguns modelos (player, red_robot) têm a FRENTE em +Z e
# apareceriam de costas com o flip de 180°; eles sobrescrevem via _MODEL_FRONT_YAW para
# já iniciar de frente, sem o usuário precisar rotacionar. Setado em _on_model_selected.
var _front_yaw_base: float = DEFAULT_FRONT_YAW

# Whole-model preview toggles. Colliders draws wireframe gizmos for the
# (otherwise invisible) CollisionShape3D volumes; animation plays the model's
# AnimationPlayer; audio plays ALL of its sound emitters (movement, motor, shots,
# explosions, voices...). Effects ("Efeitos especiais") shows everything else linked
# to the model that no other toggle covers — particles, lights and bone-mounted
# laser/muzzle meshes (see _collect_effect_nodes). All start off so a freshly-picked
# model previews static, silent and clean.
var _show_colliders: bool = false
# Toggle "Colisores de Submembros": mostra/oculta SÓ o limbcollider (gizmo) do sub-membro
# selecionado no dropdown "Sub-membro". Independente de "Colisores de Membro". Persistido.
var _show_sub_colliders: bool = false
# Toggle "Submembros": rotula o sub-membro selecionado com "Submembro: <nome>" (Label3D flutuante).
var _show_sub_member_label: bool = false
var _play_animation: bool = false
var _play_audio: bool = false
var _show_effects: bool = false
# Rótulos "Membro: CABEÇA" sobre cada collider — toggle PRÓPRIO do browser, totalmente
# independente da tela de Debug 3D (que agora só afeta os levels do jogo).
var _show_member_labels: bool = false
# Linhas extras do tooltip de membro (TYPE/Name/ID do Skeleton3D), cada uma com seu
# checkbox dedicado na cena Models — não dependem mais do Debug 3D global.
var _show_type: bool = false
var _show_name: bool = false
var _show_id: bool = false
# Toggle "Esqueleto" (ex-"SubMembro"/"Osso"; topo do LabelLinesRow): mostra, como Label3D flutuante,
# "Esqueleto: <nome>" do osso avulso escolhido no dropdown "Esqueleto" (modo "Todos os membros").
# Independente da caixa de realce (toggle "Colisores de Esqueleto"); pode-se ver só o nome, só a
# caixa, ou ambos. Persistido (chave `show_osso`, mantida).
var _show_osso: bool = false
# Toggle "Colisores de Esqueleto" (ex-"Realçar avulso"/"Esqueleto"): quando ligado E o filtro
# "Esqueleto" tem um item escolhido, desenha uma caixa translúcida sobre a região daquele osso (ou de
# todos, em "Todo o esqueleto"), sem esconder o modelo. "Selecione..." / off = modelo inteiro. Persistido.
var _show_aux_highlight: bool = false
# Toggle "Malha" (acima de Tipo): mostra/esconde a malha (MeshInstance3D) do modelo do preview
# — útil para ver esqueleto/colliders sem a malha por cima. Vindo da antiga tela developer.
# Default LIGADO (malha visível). Efeito local a esta cena (só o preview). Persistido.
var _show_malha: bool = true
# Toggle "Linhas do Esqueleto" (abaixo de Id): desenha as linhas brancas osso→pai do esqueleto
# do preview, refeitas a cada frame pela pose viva. Vindo da antiga tela developer (Show
# Skeleton3D). NÃO é o "Esqueleto" (que mostra o NOME do osso). Persistido.
var _show_skeleton_lines: bool = false
# Gizmo (ImmediateMesh) das linhas de osso do preview; recriado/removido por _refresh_skeleton_lines.
var _skeleton_lines_mi: MeshInstance3D = null
# LimbColliders + Skeleton3D do preview (modelos COM esqueleto). Enquanto uma animação toca,
# `_member_lc.refit(_member_skel)` re-encaixa os colliders de membro/sub-membro à pose animada
# (acompanham movimentos/dobra em tempo real). Null para rigs sem esqueleto (já seguem o nó animado).
var _member_lc: LimbColliders = null
var _member_skel: Skeleton3D = null
# Throttle ADAPTATIVO do refit (a passada de skinning é cara em modelos densos): o intervalo é
# ajustado para o refit custar ~3% do tempo (≈ elapsed × 30), com teto 10 Hz (modelos leves) e
# piso 2 Hz (muito densos) — mantém ≥ 60 FPS. (BoneAttachment dá translação/rotação todo frame.)
const _REFIT_MIN_INTERVAL := 0.1
const _REFIT_MAX_INTERVAL := 0.5
var _refit_accum := 0.0
var _refit_interval := _REFIT_MIN_INTERVAL
# Editor de dano por membro (painel com um input de bônus % por membro). Só faz sentido
# para personagens em "Modelo completo"; não é persistido (abre fechado a cada visita).
var _show_damage_panel: bool = false
# Editor de IA por modelo. Por enquanto só o red_robot expõe opções configuráveis.
var _show_ai_panel: bool = false

# Dropdowns Membro/Sub-membro (só "Modelo completo", personagens/armas): isolam o collider
# de um membro e, opcionalmente, de um de seus sub-membros, na visualização. Cada array
# guarda as entradas {group,label} na MESMA ordem dos itens do combo (item index - 1).
var _member_entries: Array = []      # membros grandes (HEAD/TORSO/ARM…), exceto PART_*
var _sub_member_entries: Array = []  # sub-membros (PART_*) do membro atualmente escolhido
var _skeleton_entries: Array = []  # ossos avulsos (candidatos a sub-membro) do dropdown "Esqueleto" ("Todos os membros")

# AnimationPlayers of the current whole-model preview, used by the "Animação"
# dropdown to list and play the model's clips.
var _preview_anim_players: Array = []
# The model's MAIN AnimationPlayer (the one its AnimationTree drives, or the richest one
# when there is no tree). When no specific clip is chosen, ONLY this player auto-plays a
# default/idle clip; the other players (one-shot effect/death clips like kaboom/blast/shoot)
# stay stopped so they don't overlay extra debris meshes on the model.
var _main_anim_player: AnimationPlayer = null
# The live body subtree (the main player's model root). Hidden while a death/explosion clip
# plays — those clips reveal the model's debris (e.g. red_robot's kaboom shows the Death
# parts) WITHOUT hiding the body, so without this the intact body and the debris overlap as
# "two models". Hiding it leaves only the explosion.
var _main_body_root: Node3D = null

# Special-effect nodes of the current whole-model preview, used by the "Efeitos
# Especiais" dropdown to list and isolate them. Each entry: {"label", "node"}.
var _preview_effect_nodes: Array = []

# The live preview instance currently under ModelHolder (whole model or single
# mesh). Toggles act on THIS node in place instead of rebuilding it, so flipping
# any toggle never reloads the model nor disturbs the camera/rotation.
var _preview_instance: Node = null
# Captured at build so the in-place audio applier can restore state: each emitter's
# authored volume_db, so a muted-by-toggle emitter can be un-muted without a rebuild.
var _preview_audio_players: Array = []
var _preview_audio_volumes: Dictionary = {}
# Whether the per-member colliders were already built for the current preview, so
# turning the Colliders toggle on later builds them once instead of every time.
var _member_colliders_built: bool = false
# Índice das pilhas de rótulos de membro vivas no preview, consumido a cada frame por
# _layout_member_labels para o anti-colisão (empurrar pilhas que se sobreponham na tela).
# Cada entrada: {"pivot": Node3D (move a pilha junta), "body": StaticBody3D (âncora animada),
# "base": Vector3 (posição local sem empurrão), "H": float, "halfW": float} — H/halfW são o
# tamanho aproximado do bloco em metros, usados para projetar seu retângulo de tela.
var _member_label_pivots: Array = []

# Registro dos itens da ÁRVORE de dano, um por membro/sub-membro. Cada entrada:
# {"item": TreeItem, "group": String, "owner": String}. Usado por _refresh_tree_inherited para
# reexibir, ao vivo, o valor herdado (range col 2) dos itens sem valor próprio quando o dono muda.
var _damage_field_anchors: Array = []
# Ícone de lixeira (gerado em código) usado no botão de remover de CADA folha de sub-membro na
# árvore de dano (à direita do nome). Construído uma vez em _setup_damage_tree.
var _trash_icon: Texture2D = null
# id do botão de lixeira nas células da árvore (Tree.button_clicked devolve este id).
const _TRASH_BTN_ID := 0

# Arraste da janela flutuante de dano (clique e arraste na barra de título).
var _damage_panel_dragging: bool = false
var _damage_panel_drag_offset: Vector2 = Vector2.ZERO
# Arraste da janela flutuante de IA.
var _ai_panel_dragging: bool = false
var _ai_panel_drag_offset: Vector2 = Vector2.ZERO

# Janela flutuante REUTILIZÁVEL (FloatingWindow) de Afastamento/Escala do collider do item escolhido
# nos dropdowns Membro/Sub-membro/Esqueleto. _dialog_group é o grupo em edição; cada mudança persiste
# e aplica AO VIVO na hora (sem botão Salvar). _dialog_dismissed_group: grupo cuja janela o usuário
# fechou no × — não reabre até o alvo mudar. _closing_dialog_programmatically distingue o fechamento
# por código (alvo sumiu) do manual. _dlg_* são os SpinBox criados no conteúdo da janela.
var _collider_dialog: FloatingWindow = null
var _dialog_group: String = ""
var _dialog_dismissed_group: String = ""
var _closing_dialog_programmatically: bool = false
var _dlg_off_x: SpinBox
var _dlg_off_y: SpinBox
var _dlg_off_z: SpinBox
var _dlg_rot_x: SpinBox
var _dlg_rot_y: SpinBox
var _dlg_rot_z: SpinBox
var _dlg_scale_x: SpinBox
var _dlg_scale_y: SpinBox
var _dlg_scale_z: SpinBox

@onready var model_holder: Node3D = $ModelHolder
@onready var camera: Camera3D = $Camera3D

# Gizmo de eixos 3D: overlay (SubViewport) reposicionado à esquerda dos toggles; _gizmo_node gira
# junto com o modelo. Ver _setup_axis_gizmo / _process.
@onready var _toggles_col: Control = $UI/Margin/Main/Body/Toggles
var _gizmo_overlay: SubViewportContainer = null
var _gizmo_node: Node3D = null

# Mouse-wheel zoom state: the camera's distance from the model along its local Z.
# _zoom_target is nudged by the wheel; _zoom eases toward it every frame.
var _zoom: float = 0.0
var _zoom_target: float = 0.0
@onready var cbo_category: OptionButton = %cboCategory
@onready var cbo_prefix: OptionButton = %cboPrefix
@onready var cbo_models: OptionButton = %cboModels
@onready var cbo_meshes: OptionButton = %cboMeshes
@onready var animation_row: HBoxContainer = %AnimationRow
@onready var cbo_animations: OptionButton = %cboAnimations
@onready var effects_row: HBoxContainer = %EffectsRow
@onready var cbo_effects: OptionButton = %cboEffects
@onready var member_row: HBoxContainer = %MemberRow
@onready var cbo_members: OptionButton = %cboMembers
@onready var sub_member_row: HBoxContainer = %SubMemberRow
@onready var cbo_sub_members: OptionButton = %cboSubMembers
# Dropdown "Esqueleto" (ossos avulsos), exibido SÓ no modo "Todos os membros". Fica ABAIXO do editor
# de collider (Save) — quando um sub-membro está selecionado, o editor aparece e empurra o Esqueleto
# para baixo dele; sem sub-membro selecionado o editor some e o Esqueleto fica logo abaixo de Submembros.
@onready var skeleton_row: HBoxContainer = %SkeletonRow
@onready var cbo_skeleton: OptionButton = %cboSkeleton
# Rótulo da row de sub-membro: gerenciado em código (sempre "Sub-membro:" agora que os ossos avulsos
# têm o dropdown próprio "Esqueleto"); fica no SKIP_GROUP do Locale, retraduzido por código.
@onready var sub_member_label: Label = %SubMemberLabel
# Dropdowns de TIPO DE GEOMETRIA (collider) à direita de Membro/Sub-membro/Esqueleto. Visíveis só com
# um item REAL escolhido na row; "Selecione..." = sem collider (no MEMBRO REMOVE o collider; em
# sub-membro/avulso só deixa de aplicar override). A escolha vai p/ LimbConfig.collider_shape e é
# lida na construção dos colliders (spawn). Ver _refresh_collider_editors / _on_*_geo_selected.
@onready var cbo_member_geo: OptionButton = %cboMemberGeo
@onready var cbo_sub_member_geo: OptionButton = %cboSubMemberGeo
@onready var cbo_skeleton_geo: OptionButton = %cboSkeletonGeo
# Raiz da UI (Control) onde a janela flutuante de Afastamento/Escala é anexada (como os painéis Dano/IA).
@onready var ui_root: Control = $UI
@onready var rotate_toggle: CheckButton = %RotateToggle
@onready var animation_toggle: CheckButton = %AnimationToggle
@onready var audio_toggle: CheckButton = %AudioToggle
@onready var colliders_toggle: CheckButton = %CollidersToggle
@onready var labels_toggle: CheckButton = %LabelsToggle
@onready var type_check: CheckButton = %TypeCheck
@onready var name_check: CheckButton = %NameCheck
@onready var id_check: CheckButton = %IdCheck
@onready var osso_check: CheckButton = %OssoCheck
@onready var damage_button: Button = %DamageButton
@onready var ai_button: Button = %AIButton
@onready var aux_highlight_toggle: CheckButton = %AuxHighlightToggle
@onready var sub_member_label_toggle: CheckButton = %SubMemberLabelToggle
@onready var sub_collider_toggle: CheckButton = %SubColliderToggle
@onready var malha_check: CheckButton = %MalhaCheck
@onready var skeleton_lines_check: CheckButton = %SkeletonLinesCheck
@onready var effects_toggle: CheckButton = %EffectsToggle
@onready var damage_panel: PanelContainer = %DamagePanel
@onready var ai_panel: PanelContainer = %AIPanel
# Editor de dano em ÁRVORE (Tree): galhos = membros, folhas = sub-membros sob seu dono. Colunas:
# Nome | Definir (check) | Bônus % (range) | Dono (dropdown, só sub-membros). Footer abaixo da
# árvore = linha "Adicionar sub-membro" + botão "Remover sub-membro".
@onready var damage_tree: Tree = %DamageTree
@onready var damage_footer: VBoxContainer = %Footer
# Barra de título (área de arraste) e botão fechar (×, estilo Windows) da janela flutuante de dano.
@onready var damage_titlebar: PanelContainer = %TitleBar
@onready var damage_close_button: Button = %CloseButton
@onready var ai_list: VBoxContainer = %AIList
@onready var ai_titlebar: PanelContainer = %AITitleBar
@onready var ai_close_button: Button = %AICloseButton
@onready var portuguese_button: Button = $UI/Actions/LangBar/PortugueseButton
@onready var english_button: Button = $UI/Actions/LangBar/EnglishButton
# Rótulo LOCAL do nome da cena (nó no .tscn). Mantido OCULTO (ver _ready) — o nome da cena é
# mostrado pelo watermark GLOBAL de debug_overlay.gd (topo direito, ao lado do título). Nó
# preservado só para não quebrar a referência %SceneNameLabel.
@onready var scene_name_label: Label = %SceneNameLabel


func _ready() -> void:
	_zoom = camera.position.z
	_zoom_target = _zoom
	_setup_axis_gizmo()
	# Watermark LOCAL do nome da cena: mantido OCULTO (o nome "Models" não deve aparecer na janela
	# de dano). O nome da cena já é mostrado pelo watermark GLOBAL de debug_overlay.gd no canto da
	# tela. Nó preservado só para não quebrar referências.
	scene_name_label.text = name
	scene_name_label.visible = false
	_categories = _scan_library()

	cbo_category.clear()
	cbo_category.add_item(Locale.tr_key(SELECT_LABEL))
	for category in _categories:
		cbo_category.add_item(Locale.tr_key(category["label"]))
	cbo_category.item_selected.connect(_on_category_selected)
	cbo_prefix.item_selected.connect(_on_prefix_selected)
	cbo_models.item_selected.connect(_on_model_selected)
	cbo_meshes.item_selected.connect(_on_mesh_selected)
	cbo_animations.item_selected.connect(_on_animation_selected)
	cbo_effects.item_selected.connect(_on_effect_selected)
	cbo_members.item_selected.connect(_on_member_selected)
	cbo_sub_members.item_selected.connect(_on_sub_member_selected)
	cbo_skeleton.item_selected.connect(_on_skeleton_selected)
	_populate_geo_dropdown(cbo_member_geo)
	_populate_geo_dropdown(cbo_sub_member_geo)
	_populate_geo_dropdown(cbo_skeleton_geo)
	cbo_member_geo.item_selected.connect(_on_member_geo_selected)
	cbo_sub_member_geo.item_selected.connect(_on_sub_member_geo_selected)
	cbo_skeleton_geo.item_selected.connect(_on_skeleton_geo_selected)
	_reset_animations()
	_reset_effects()
	_reset_members()

	# Restore the toggle states saved on a previous visit, so the browser reopens
	# exactly as the user left it (see _save_toggle / _on_*_toggled). Defaults match
	# the field initializers above (everything off) for a first run.
	_auto_rotate = Settings.config_file.get_value("models", "auto_rotate", _auto_rotate)
	_play_animation = Settings.config_file.get_value("models", "play_animation", _play_animation)
	_play_audio = Settings.config_file.get_value("models", "play_audio", _play_audio)
	_show_colliders = Settings.config_file.get_value("models", "show_colliders", _show_colliders)
	_show_sub_colliders = Settings.config_file.get_value("models", "show_sub_colliders", _show_sub_colliders)
	_show_sub_member_label = Settings.config_file.get_value("models", "show_sub_member_label", _show_sub_member_label)
	_show_member_labels = Settings.config_file.get_value("models", "show_member_labels", _show_member_labels)
	_show_type = Settings.config_file.get_value("models", "show_type", _show_type)
	_show_name = Settings.config_file.get_value("models", "show_name", _show_name)
	_show_id = Settings.config_file.get_value("models", "show_id", _show_id)
	_show_osso = Settings.config_file.get_value("models", "show_osso", _show_osso)
	_show_aux_highlight = Settings.config_file.get_value("models", "show_aux_highlight", _show_aux_highlight)
	_show_malha = Settings.config_file.get_value("models", "show_malha", _show_malha)
	_show_skeleton_lines = Settings.config_file.get_value("models", "show_skeleton_lines", _show_skeleton_lines)
	_show_effects = Settings.config_file.get_value("models", "show_effects", _show_effects)

	rotate_toggle.button_pressed = _auto_rotate
	rotate_toggle.toggled.connect(_on_rotate_toggled)
	animation_toggle.button_pressed = _play_animation
	animation_toggle.toggled.connect(_on_animation_toggled)
	audio_toggle.button_pressed = _play_audio
	audio_toggle.toggled.connect(_on_audio_toggled)
	colliders_toggle.button_pressed = _show_colliders
	colliders_toggle.toggled.connect(_on_colliders_toggled)
	labels_toggle.button_pressed = _show_member_labels
	labels_toggle.toggled.connect(_on_labels_toggled)
	type_check.button_pressed = _show_type
	type_check.toggled.connect(_on_type_toggled)
	name_check.button_pressed = _show_name
	name_check.toggled.connect(_on_name_toggled)
	id_check.button_pressed = _show_id
	id_check.toggled.connect(_on_id_toggled)
	osso_check.button_pressed = _show_osso
	osso_check.toggled.connect(_on_osso_toggled)
	# "Dano" virou botão de ação (ao lado do "Voltar"), não mais um toggle da lista: abre a janela.
	damage_button.pressed.connect(_on_damage_button_pressed)
	ai_button.pressed.connect(_on_ai_button_pressed)
	aux_highlight_toggle.button_pressed = _show_aux_highlight
	aux_highlight_toggle.toggled.connect(_on_aux_highlight_toggled)
	sub_member_label_toggle.button_pressed = _show_sub_member_label
	sub_member_label_toggle.toggled.connect(_on_sub_member_label_toggled)
	sub_collider_toggle.button_pressed = _show_sub_colliders
	sub_collider_toggle.toggled.connect(_on_sub_colliders_toggled)
	malha_check.button_pressed = _show_malha
	malha_check.toggled.connect(_on_malha_toggled)
	skeleton_lines_check.button_pressed = _show_skeleton_lines
	skeleton_lines_check.toggled.connect(_on_skeleton_lines_toggled)
	effects_toggle.button_pressed = _show_effects
	effects_toggle.toggled.connect(_on_effects_toggled)
	# O rótulo da row de sub-membro é dirigido por código (alterna com o filtro "Ossos avulsos"),
	# então sai do auto-tradutor do Locale; _populate_sub_members/_on_language_changed o atualizam.
	sub_member_label.add_to_group(Locale.SKIP_GROUP)
	_setup_damage_window()
	_setup_damage_tree()
	_setup_ai_window()

	# Pinta o texto de cada toggle de linha com a mesma cor do rótulo 3D que ele controla.
	_apply_label_line_colors()

	Locale.language_changed.connect(_on_language_changed)
	_update_language_buttons()

	# Reopen exactly where the user left off: replay the persisted selection chain
	# (Categoria -> Prefixo -> Modelo -> Parte -> Animação/Efeitos). With nothing saved
	# every dropdown shows "Selecione..." and nothing is previewed — identical to a first
	# visit, and no real item is ever auto-selected.
	_restore_selection_chain()
	_refresh_ai_actions()


func _on_language_changed(_lang: String) -> void:
	# Relabel the placeholders/category names already in the dropdowns (kept in place so
	# the current selection survives), then re-apply the lang buttons.
	if cbo_category.item_count > 0:
		cbo_category.set_item_text(0, Locale.tr_key(SELECT_LABEL))
	for i in range(_categories.size()):
		if i + 1 < cbo_category.item_count:
			cbo_category.set_item_text(i + 1, Locale.tr_key(_categories[i]["label"]))
	for combo in [cbo_prefix, cbo_models, cbo_meshes, cbo_animations, cbo_effects, cbo_members, cbo_sub_members, cbo_skeleton]:
		if combo.item_count > 0:
			combo.set_item_text(0, Locale.tr_key(SELECT_LABEL))
	# Dropdowns de geometria (itens fixos Selecione/Esfera/Caixa/Cápsula) — re-traduz preservando a seleção.
	for geo in [cbo_member_geo, cbo_sub_member_geo, cbo_skeleton_geo]:
		_relabel_geo_dropdown(geo)
	if cbo_meshes.item_count > 1:
		cbo_meshes.set_item_text(1, Locale.tr_key(WHOLE_MODEL_LABEL))
	# The "Todos" entry (when present) sits at index 1 of the Efeitos dropdown.
	if not _preview_effect_nodes.is_empty() and cbo_effects.item_count > 1:
		cbo_effects.set_item_text(1, Locale.tr_key(ALL_EFFECTS_LABEL))
	# "Todos os membros" fica no índice 1 do dropdown Membro (quando populado).
	if cbo_members.item_count > 1:
		cbo_members.set_item_text(1, Locale.tr_key(ALL_MEMBERS_LABEL))
	# "Todos os Sub-membros": índice 1 do dropdown Sub-membro (só no modo "Todos os membros").
	if cbo_sub_members.item_count > 1 and _sub_member_value(1) == ALL_SUB_MEMBERS_VALUE:
		cbo_sub_members.set_item_text(1, Locale.tr_key(ALL_SUB_MEMBERS_LABEL))
	# "Todo o esqueleto": índice 1 do dropdown Esqueleto (quando há ossos avulsos).
	if cbo_skeleton.item_count > 1 and not _skeleton_entries.is_empty() \
			and str(_skeleton_entries[0]["group"]) == ALL_AUX_VALUE:
		cbo_skeleton.set_item_text(1, Locale.tr_key(ALL_AUX_LABEL))
	# Rótulo da row de sub-membro (SKIP_GROUP, dirigido por código): agora sempre "Sub-membro:"
	# (o filtro de ossos avulsos virou o dropdown próprio "Esqueleto", com label estático).
	sub_member_label.text = Locale.tr_key("Sub-membro:")
	if _show_ai_panel:
		_refresh_ai_panel()
	_refresh_ai_actions()
	# Re-traduz os PREFIXOS dos rótulos 3D (Membro:/Sub-membro:/Esqueleto:/Tipo:/Nome:): os Label3D não
	# passam pelo auto-tradutor do Locale, então reconstruímos as pilhas com o idioma atual.
	_refresh_member_overlays()
	_refresh_aux_labels()
	_update_language_buttons()


func _update_language_buttons() -> void:
	var lang := Locale.get_language()
	portuguese_button.disabled = lang == "pt"
	english_button.disabled = lang == "en"


func _on_portuguese_pressed() -> void:
	Locale.set_language("pt")
	_update_language_buttons()


func _on_english_pressed() -> void:
	Locale.set_language("en")
	_update_language_buttons()


# --- Gizmo de eixos 3D ------------------------------------------------------------------
# Indicador de orientação estilo editor de jogos: três eixos coloridos (X vermelho, Y verde, Z
# azul) com bola na ponta + letra, que GIRAM junto com o modelo (ver _process). É renderizado num
# SubViewport PRÓPRIO (mundo isolado, fundo transparente, MSAA) sobreposto no topo à direita —
# assim NUNCA é coberto pelo modelo e independe do zoom/tamanho dele; o overlay é reposicionado à
# esquerda da coluna de toggles a cada frame, então também não cobre a UI nem o modelo.
const _GIZMO_SIZE: int = 132          # lado do overlay (px)
const _GIZMO_ARM: float = 0.9         # comprimento de cada eixo
const _GIZMO_ARM_RADIUS: float = 0.045
const _GIZMO_BALL: float = 0.17       # bola da ponta + (eixo positivo)
const _GIZMO_NEG_BALL: float = 0.115  # bola da ponta - (apagada)


func _setup_axis_gizmo() -> void:
	var container := SubViewportContainer.new()
	container.name = "AxisGizmoOverlay"
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	container.custom_minimum_size = Vector2(_GIZMO_SIZE, _GIZMO_SIZE)
	container.size = Vector2(_GIZMO_SIZE, _GIZMO_SIZE)
	$UI.add_child(container)
	_gizmo_overlay = container

	var vp := SubViewport.new()
	vp.name = "AxisGizmoViewport"
	vp.size = Vector2i(_GIZMO_SIZE, _GIZMO_SIZE)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(vp)

	# Câmera ortográfica olhando -Z (mesma orientação da câmera principal), para o gizmo
	# renderizar exatamente como o modelo é visto na tela.
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.2
	cam.near = 0.05
	cam.far = 100.0
	cam.position = Vector3(0.0, 0.0, 6.0)
	vp.add_child(cam)

	var gizmo := Node3D.new()
	gizmo.name = "AxisGizmo"
	vp.add_child(gizmo)
	# Hub central neutro que une os braços.
	gizmo.add_child(_gizmo_ball(Vector3.ZERO, 0.13, Color(0.22, 0.23, 0.27)))
	# Um braço + bola + letra por eixo; bola apagada (sem letra) no sentido negativo.
	var axes := [
		{"dir": Vector3.RIGHT, "rot": Vector3(0, 0, -90), "col": Color(0.96, 0.27, 0.31), "letter": "X"},
		{"dir": Vector3.UP,    "rot": Vector3(0, 0, 0),   "col": Color(0.46, 0.86, 0.33), "letter": "Y"},
		{"dir": Vector3.BACK,  "rot": Vector3(90, 0, 0),  "col": Color(0.30, 0.56, 1.00), "letter": "Z"},
	]
	for a in axes:
		var dir: Vector3 = a["dir"]
		var col: Color = a["col"]
		var arm := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = _GIZMO_ARM_RADIUS
		cyl.bottom_radius = _GIZMO_ARM_RADIUS
		cyl.height = _GIZMO_ARM
		cyl.radial_segments = 12
		arm.mesh = cyl
		arm.material_override = _gizmo_mat(col)
		arm.rotation_degrees = a["rot"]
		arm.position = dir * (_GIZMO_ARM * 0.5)
		gizmo.add_child(arm)
		gizmo.add_child(_gizmo_ball(dir * _GIZMO_ARM, _GIZMO_BALL, col))
		var lbl := Label3D.new()
		lbl.text = a["letter"]
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.fixed_size = true
		lbl.pixel_size = 0.0055
		lbl.font_size = 110
		lbl.outline_size = 30
		lbl.modulate = Color.WHITE
		lbl.outline_modulate = Color(0, 0, 0, 0.85)
		lbl.position = dir * (_GIZMO_ARM + _GIZMO_BALL + 0.12)
		gizmo.add_child(lbl)
		gizmo.add_child(_gizmo_ball(-dir * _GIZMO_ARM, _GIZMO_NEG_BALL, col.darkened(0.55)))
	_gizmo_node = gizmo


# Esfera unshaded reutilizável do gizmo.
func _gizmo_ball(pos: Vector3, radius: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0
	sph.radial_segments = 16
	sph.rings = 8
	mi.mesh = sph
	mi.material_override = _gizmo_mat(col)
	mi.position = pos
	return mi


# Material unshaded (cor cheia, legível sem luz — o gizmo tem mundo próprio sem iluminação).
func _gizmo_mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	return mat


# Mantém o overlay do gizmo ancorado à ESQUERDA da coluna de toggles, no topo — assim não cobre
# os toggles (qualquer largura/idioma) nem o modelo (centralizado), em qualquer resolução.
func _position_gizmo_overlay() -> void:
	if _gizmo_overlay == null or _toggles_col == null:
		return
	var x: float = _toggles_col.global_position.x - float(_GIZMO_SIZE) - 16.0
	_gizmo_overlay.position = Vector2(maxf(x, 16.0), 40.0)


func _process(delta: float) -> void:
	# Slowly spin the previewed mesh, like the character on the choose-player
	# screen — but pause while the user is hand-rotating it with the mouse.
	if _auto_rotate and not _dragging:
		_yaw += delta * AUTO_ROTATE_SPEED
	# Rebuild rotation from yaw/pitch with roll fixed at 0 (orthogonal axes only).
	# _front_yaw_base turns the model's front toward the camera (180° por padrão; 0° para
	# modelos cuja frente já é +Z, como player/red_robot — ver _MODEL_FRONT_YAW).
	model_holder.rotation = Vector3(_pitch, _front_yaw_base + _yaw, 0.0)
	# O gizmo de eixos gira em lockstep com o modelo e fica ancorado à esquerda dos toggles.
	if _gizmo_node != null:
		_gizmo_node.rotation = model_holder.rotation
		_position_gizmo_overlay()
	# Glide the camera toward the wheel-set zoom distance instead of snapping.
	if not is_equal_approx(_zoom, _zoom_target):
		_zoom = lerpf(_zoom, _zoom_target, minf(ZOOM_SMOOTH * delta, 1.0))
		camera.position.z = _zoom
	# Reflui as pilhas de rótulos de membro para que conjuntos de membros diferentes não se
	# sobreponham na tela (o modelo gira, então a checagem é por frame). Sem pilhas, é no-op.
	if not _member_label_pivots.is_empty():
		_layout_member_labels()
	# Linhas do esqueleto seguem a pose viva (reconstruídas todo frame), como na antiga developer.
	if _show_skeleton_lines and is_instance_valid(_skeleton_lines_mi):
		_update_skeleton_lines()
	# Enquanto uma animação toca E os colliders estão visíveis, re-encaixa os colliders de
	# membro/sub-membro à pose animada (acompanham a dobra) — com THROTTLE adaptativo para não
	# derrubar o FPS em modelos densos.
	if _play_animation and _show_colliders and cbo_animations.selected > 0 \
			and is_instance_valid(_member_lc) and is_instance_valid(_member_skel):
		_refit_accum += delta
		if _refit_accum >= _refit_interval:
			_refit_accum = 0.0
			var t0 := Time.get_ticks_usec()
			_member_lc.refit(_member_skel)
			var elapsed := float(Time.get_ticks_usec() - t0) / 1_000_000.0
			# Próximo refit espaçado para custar ~3% do tempo: modelo mais denso → menos frequente.
			_refit_interval = clampf(elapsed * 30.0, _REFIT_MIN_INTERVAL, _REFIT_MAX_INTERVAL)
	else:
		# Pronto para re-encaixar de imediato quando a animação/colisores forem (re)ativados.
		_refit_accum = _refit_interval
	# Rede de segurança do arraste da janela: se o botão foi solto fora da barra (ex.: a janela
	# bateu no limite da viewport e o cursor escapou), encerra o arraste e salva a posição.
	if _damage_panel_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_damage_panel_dragging = false
		_save_damage_panel_pos()
	if _ai_panel_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_ai_panel_dragging = false
		_save_ai_panel_pos()


# Sequential gating: each dropdown below Categoria stays DISABLED until the one
# directly above it holds a real (non-"Selecione...") choice. So the user is forced
# down the chain Categoria -> Prefixo -> Modelo -> Parte. Category index 0 is the
# "Selecione..." placeholder (real categories start at index 1). Selecting it blanks
# and disables the whole chain below and clears the preview.
func _on_category_selected(index: int) -> void:
	_save_selection("sel_category", _category_value(index))
	if index <= 0:
		_reset_prefixes()
		_reset_models()
		return
	_populate_prefixes(index - 1)
	# Prefix is now enabled but still on its placeholder, so Modelo/Parte stay locked.
	_reset_models()


# Build the prefix dropdown for a category: "Selecione..." (placeholder) plus each
# distinct model prefix (the first underscore-separated token, e.g. "robot" for
# robot_01 / robot_02). Enables the dropdown; the placeholder carries empty metadata.
func _populate_prefixes(category_index: int) -> void:
	var models: Array = _categories[category_index]["models"]
	var seen: Dictionary = {}
	var prefixes: Array = []
	for entry in models:
		var prefix: String = entry.get("prefix", "")
		if prefix != "" and not seen.has(prefix):
			seen[prefix] = true
			prefixes.append(prefix)
	prefixes.sort()

	cbo_prefix.clear()
	cbo_prefix.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_prefix.set_item_metadata(0, "")
	for prefix in prefixes:
		cbo_prefix.add_item(_prettify(prefix))
		cbo_prefix.set_item_metadata(cbo_prefix.item_count - 1, prefix)
	cbo_prefix.select(0)
	cbo_prefix.disabled = false
	_prefix_filter = ""


# Reset the prefix dropdown to just the "Selecione..." placeholder and DISABLE it
# (no category chosen, so there is nothing to filter yet).
func _reset_prefixes() -> void:
	cbo_prefix.clear()
	cbo_prefix.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_prefix.set_item_metadata(0, "")
	cbo_prefix.select(0)
	cbo_prefix.disabled = true
	_prefix_filter = ""


func _on_prefix_selected(index: int) -> void:
	_prefix_filter = cbo_prefix.get_item_metadata(index)
	_save_selection("sel_prefix", _prefix_filter)
	if _prefix_filter == "":
		# Back to the placeholder: re-lock Modelo and Parte.
		_reset_models()
	else:
		_populate_models()


# Fill the Model dropdown with "Selecione..." plus the current category's models
# that match the chosen prefix, and ENABLE it. The placeholder stays selected, so no
# model is previewed until the user picks one — and the Part dropdown stays locked.
func _populate_models() -> void:
	cbo_models.clear()
	cbo_models.add_item(Locale.tr_key(SELECT_LABEL))
	_filtered_models = []
	var cat_index := cbo_category.selected - 1
	if cat_index < 0:
		_reset_models()
		return

	var models: Array = _categories[cat_index]["models"]
	for entry in models:
		if entry.get("prefix", "") != _prefix_filter:
			continue
		_filtered_models.append(entry)
		cbo_models.add_item(entry["name"])

	cbo_models.select(0)
	cbo_models.disabled = false
	_reset_meshes_and_preview()


# Reset the Model dropdown to just the "Selecione..." placeholder, DISABLE it, and
# clear the parts dropdown and preview below it.
func _reset_models() -> void:
	cbo_models.clear()
	cbo_models.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_models.select(0)
	cbo_models.disabled = true
	_filtered_models = []
	_reset_meshes_and_preview()


# Reset the Part dropdown to just the "Selecione..." placeholder, DISABLE it, and
# clear the previewed mesh/model and its cached scenes. Also resets the dropdowns
# below Part (Animação, Efeitos, Membro, Sub-membro) so changing any upper dropdown
# cascades a "Selecione..." reset all the way down.
func _reset_meshes_and_preview() -> void:
	_front_yaw_base = DEFAULT_FRONT_YAW
	_current_model_path = ""
	_model_scene = null
	_display_scene = null
	_mesh_catalog = []
	cbo_meshes.clear()
	cbo_meshes.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_meshes.select(0)
	cbo_meshes.disabled = true
	_reset_animations()
	_reset_effects()
	_reset_members()
	_clear_preview()
	_refresh_ai_actions()


# Model dropdown index 0 is the "Selecione..." placeholder; real models start at
# index 1 (mapping to _filtered_models[index - 1]). Selecting a real model rebuilds
# the Part dropdown ("Selecione...", then "Modelo completo", then each distinct
# mesh) but leaves the placeholder selected, so nothing previews until a part is
# picked. Selecting the placeholder blanks the part dropdown and the preview.
func _on_model_selected(index: int) -> void:
	if index <= 0:
		_save_selection("sel_model", "")
		_reset_meshes_and_preview()
		return

	var model: Dictionary = _filtered_models[index - 1]
	_save_selection("sel_model", model["name"])
	_current_model_path = model["path"]
	# Orientação inicial deste modelo: a maioria usa o flip de 180°; player/red_robot já
	# nascem de frente (ver _MODEL_FRONT_YAW). Lido aqui pois _current_model_key() já resolve.
	_front_yaw_base = _MODEL_FRONT_YAW.get(_current_model_key(), DEFAULT_FRONT_YAW)
	_model_scene = load(model["path"])
	_display_scene = load(model.get("display_path", model["path"]))
	_mesh_catalog = _build_mesh_catalog(_model_scene)

	cbo_meshes.clear()
	cbo_meshes.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_meshes.add_item(Locale.tr_key(WHOLE_MODEL_LABEL))
	for entry in _mesh_catalog:
		cbo_meshes.add_item(entry["label"])
	cbo_meshes.select(0)
	cbo_meshes.disabled = false
	# Part is back on its placeholder, so the dropdowns below it reset/hide too
	# (Animação, Efeitos, Membro, Sub-membro) — cascade the "Selecione..." reset down.
	_reset_animations()
	_reset_effects()
	_reset_members()
	_clear_preview()
	_refresh_ai_actions()


# Part dropdown index 0 is the "Selecione..." placeholder (nothing previewed),
# index 1 is the assembled "Modelo completo", and indices 2.. map to the distinct
# meshes in _mesh_catalog (shifted by the two leading entries).
func _on_mesh_selected(index: int) -> void:
	_save_selection("sel_part", _part_value(index))
	if index <= 0:
		_clear_preview()
		_reset_animations()
		_reset_effects()
		_reset_members()
	elif index == 1:
		_preview_whole_model()
		# The animation/effects/member dropdowns only apply to "Modelo completo".
		_populate_animations()
		_populate_effects()
		_populate_members()
	else:
		# A single isolated part has no animation/effects/member combos below it.
		_preview_mesh(index - 2)
		_reset_animations()
		_reset_effects()
		_reset_members()


# Fill the "Animação" dropdown with "Selecione..." plus every clip the previewed
# model exposes; enable it only when there is at least one. Selecting a clip plays
# it on the preview (see _on_animation_selected). The whole row is shown ONLY for the
# assembled "Modelo completo" view (see _on_mesh_selected) — single parts and the
# placeholder hide it via _reset_animations.
func _populate_animations() -> void:
	animation_row.visible = true
	# Preserve the current pick across preview rebuilds (toggling colliders/audio
	# re-runs the preview), so a chosen clip keeps playing.
	var prev := "" if cbo_animations.selected <= 0 else cbo_animations.get_item_text(cbo_animations.selected)
	cbo_animations.clear()
	cbo_animations.add_item(Locale.tr_key(SELECT_LABEL))
	var seen: Dictionary = {}
	for ap: AnimationPlayer in _preview_anim_players:
		for clip in ap.get_animation_list():
			if not seen.has(clip):
				seen[clip] = true
				cbo_animations.add_item(clip)
	var restore := 0
	for i in range(1, cbo_animations.item_count):
		if cbo_animations.get_item_text(i) == prev:
			restore = i
			break
	cbo_animations.select(restore)
	cbo_animations.disabled = cbo_animations.item_count <= 1


# Reset the "Animação" dropdown to just the placeholder, disable it and HIDE the whole
# row — the combo is only shown for the assembled "Modelo completo" view.
func _reset_animations() -> void:
	cbo_animations.clear()
	cbo_animations.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_animations.select(0)
	cbo_animations.disabled = true
	animation_row.visible = false


# Item 0 is "Selecione..." (stop / static rest); items 1.. are clip names. Plays the
# chosen clip (looping via the player) on every AnimationPlayer that has it — but only
# while the Animação toggle is on: with it off, picking a clip just updates the pending
# selection and plays nothing (it starts when the toggle is turned on, via _refresh_preview).
func _on_animation_selected(index: int) -> void:
	_save_selection("sel_animation", "" if index <= 0 else cbo_animations.get_item_text(index))
	if not _play_animation:
		return
	# Play the newly chosen clip in place (the appliers read cbo_animations).
	_apply_animation_state()


# Fill the "Efeitos Especiais" dropdown with "Selecione..." plus one entry per special
# effect of the previewed model (particles, lights, bone-mounted laser/muzzle meshes —
# see _collect_effect_nodes). Shown ONLY for the assembled "Modelo completo" view, like
# the animation dropdown. Preserves the current pick across preview rebuilds.
func _populate_effects() -> void:
	effects_row.visible = true
	var prev_value := _effect_value(cbo_effects.selected)
	cbo_effects.clear()
	cbo_effects.add_item(Locale.tr_key(SELECT_LABEL))
	# Only offer "Todos" (and the per-effect entries) when the model actually exposes
	# effects, so an effect-less model just shows the placeholder and stays disabled.
	if not _preview_effect_nodes.is_empty():
		cbo_effects.add_item(Locale.tr_key(ALL_EFFECTS_LABEL))
		for entry in _preview_effect_nodes:
			cbo_effects.add_item(entry["label"])
	cbo_effects.select(maxi(_effect_index_for_value(prev_value), 0))
	cbo_effects.disabled = cbo_effects.item_count <= 1
	_apply_effects_visibility()


# Reset the "Efeitos Especiais" dropdown to just the placeholder, disable it and HIDE
# the whole row — the combo is only shown for the assembled "Modelo completo" view.
func _reset_effects() -> void:
	cbo_effects.clear()
	cbo_effects.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_effects.select(0)
	cbo_effects.disabled = true
	effects_row.visible = false


# Item 0 is "Selecione...", item 1 is "Todos" (show every effect), items 2.. are effect
# names. Picking a name isolates it (only that effect renders); see _apply_effects_visibility.
func _on_effect_selected(index: int) -> void:
	_save_selection("sel_effect", _effect_value(index))
	_apply_effects_visibility()


# Stable persisted value for an Efeitos index: "" (placeholder), the ALL_VALUE sentinel
# ("Todos", index 1) or the effect label (indices 2..).
func _effect_value(index: int) -> String:
	if index <= 0:
		return ""
	if index == 1:
		return ALL_VALUE
	return cbo_effects.get_item_text(index)


# Inverse of _effect_value: the Efeitos index for a saved value (0 when empty or stale).
func _effect_index_for_value(value: String) -> int:
	if value == "":
		return 0
	if value == ALL_VALUE:
		return 1 if cbo_effects.item_count > 1 else 0
	for i in range(2, cbo_effects.item_count):
		if cbo_effects.get_item_text(i) == value:
			return i
	return 0


# Show/hide the preview's special-effect nodes: nothing while the "Efeitos especiais"
# toggle is off; with it on, every effect on "Selecione..."/"Todos", or only the chosen
# one when a specific effect is picked.
func _apply_effects_visibility() -> void:
	var sel := cbo_effects.selected
	var chosen := "" if sel <= 1 else cbo_effects.get_item_text(sel)
	for entry in _preview_effect_nodes:
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			continue
		node.visible = _show_effects and (chosen == "" or entry["label"] == chosen)


# --- Dropdowns Membro / Sub-membro (isolamento de membro no preview) ---------
#
# Só aparecem na visão "Modelo completo" de Personagens/Armas (mesma porta dos tooltips de
# membro). "Membro" lista os membros grandes (HEAD/TORSO/ARM…) lidos dos próprios colliders
# do preview; escolher um ISOLA o seu rótulo (e o gizmo, se o toggle de collider do tipo estiver
# ligado). "Sub-membro" depende do membro
# escolhido e lista os PART_* daquele membro (mapeados pelo OSSO-PAI, subindo na hierarquia
# do esqueleto até o classificador devolver um membro); escolher um estreita o foco para
# membro + aquele sub-membro. O placeholder "Selecione..." em cada um = sem isolamento /
# membro inteiro. Tudo espelha o padrão de _populate_effects / _apply_effects_visibility.

# StaticBody3D de membro do preview (carimbados com a meta "group" por _add_member_colliders).
func _member_bodies() -> Array:
	var out: Array = []
	if _preview_instance == null:
		return out
	for node in _preview_instance.find_children("*", "StaticBody3D", true, false):
		if (node as StaticBody3D).has_meta("group"):
			out.append(node)
	return out


# Entradas {group,label} dos membros, na MESMA fonte usada pelo combo Membro e pelo painel Dano.
# PERSONAGENS: TODOS os membros do PLANO corporal (mesmo sem geometria no preview), na ordem do
# plano e com o rótulo do plano (CABEÇA/TRONCO/BRAÇO E-D/PERNA E-D…) — assim a lista reflete o
# corpo inteiro, não só os que têm collider. ARMAS (sem plano corporal): os grupos dos colliders
# do preview (WeaponParts), exceto os sub-membros PART_*, ordenados por rótulo.
func _plan_member_entries() -> Array:
	var out: Array = []
	if _current_category_key() == "characters":
		var c := _current_classifier()
		for g in c.members():
			out.append({"group": g, "label": c.label_of(g)})
		return out
	for body in _member_bodies():
		var g := str((body as StaticBody3D).get_meta("group"))
		if g.begins_with("PART_"):
			continue
		var lab := str((body as StaticBody3D).get_meta("member_label")) \
			if (body as StaticBody3D).has_meta("member_label") else g
		out.append({"group": g, "label": lab})
	out.sort_custom(func(a, b): return a["label"] < b["label"])
	return out


# Preenche o dropdown "Membro". Personagens: todos os membros do plano (ver _plan_member_entries);
# armas: os membros com collider. Só para Personagens/Armas em "Modelo completo"; senão esconde as
# duas rows. **Restaura o valor PERSISTIDO (sel_member) sempre que exibido; se não houver/for inválido
# → "Selecione..."** (2026-06-25).
func _populate_members() -> void:
	if not (_current_category_key() in ["characters", "weapons"]):
		_reset_members()
		return
	_ensure_member_colliders()
	member_row.visible = true
	var prev := String(Settings.config_file.get_value("models", "sel_member", ""))
	_member_entries = _plan_member_entries()
	cbo_members.clear()
	cbo_members.add_item(Locale.tr_key(SELECT_LABEL))          # índice 0: placeholder
	cbo_members.add_item(Locale.tr_key(ALL_MEMBERS_LABEL))     # índice 1: "Todos os membros"
	for e in _member_entries:
		cbo_members.add_item(str(e["label"]))                 # índices 2+: membros do plano
	cbo_members.select(maxi(_member_index_for_value(prev), 0))
	cbo_members.disabled = _member_entries.is_empty()
	_populate_sub_members()
	_refresh_member_overlays()
	_refresh_aux_highlight()
	_refresh_aux_labels()
	_apply_malha_visibility()
	_refresh_skeleton_lines()


# Reseta o dropdown "Membro" ao placeholder, desabilita e esconde a row (e a de sub-membro).
func _reset_members() -> void:
	cbo_members.clear()
	cbo_members.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_members.select(0)
	cbo_members.disabled = true
	member_row.visible = false
	_member_entries = []
	# A row some → seus dropdowns de geometria também; e a janela de Afastamento/Escala fecha (sem alvo).
	_close_collider_dialog()
	_dialog_dismissed_group = ""
	_reset_sub_members()


# Preenche o dropdown "Sub-membro" (logo abaixo de "Membro"). Com um MEMBRO específico (índices 2+):
# lista os PART_* DAQUELE membro. Com "Todos os membros" (índice 1): lista TODOS os sub-membros do
# modelo, com a opção "Todos os Sub-membros" no topo (= mostrar tudo). Selecionar um sub-membro o
# isola/realça. Os OSSOS AVULSOS saíram daqui para o dropdown próprio "Esqueleto" (_populate_skeleton).
# Esconde a row no placeholder/sem sub-membros.
func _populate_sub_members() -> void:
	# Dropdown "Esqueleto" (ossos avulsos, só no modo "Todos os membros"): populado/escondido à parte.
	_populate_skeleton()
	# Restaura o valor PERSISTIDO (sel_submember) sempre que exibido; sem valor válido → "Selecione...".
	var prev := String(Settings.config_file.get_value("models", "sel_submember", ""))
	_sub_member_entries = []
	cbo_sub_members.clear()
	cbo_sub_members.add_item(Locale.tr_key(SELECT_LABEL))
	sub_member_label.text = Locale.tr_key("Sub-membro:")
	var msel := cbo_members.selected
	if not member_row.visible or msel <= 0:
		cbo_sub_members.select(0)
		cbo_sub_members.disabled = true
		sub_member_row.visible = false
		return
	if msel == 1:
		# "Todos os membros": o dropdown Sub-membro oferece SÓ "Selecione..." e "Todos os Sub-membros"
		# (2026-06-25) — sub-membros INDIVIDUAIS só aparecem ao escolher um MEMBRO específico. "Todos os
		# Sub-membros" não isola (mostra o modelo inteiro) e, com "Colisor de Submembro" ligado, exibe
		# todos os gizmos de sub-membro. Só aparece se o modelo TIVER sub-membros.
		var has_subs := false
		for body in _member_bodies():
			if str((body as StaticBody3D).get_meta("group")).begins_with("PART_"):
				has_subs = true
				break
		if has_subs:
			_sub_member_entries.append({"group": ALL_SUB_MEMBERS_VALUE, "label": Locale.tr_key(ALL_SUB_MEMBERS_LABEL)})
	else:
		# Membro específico: só os sub-membros (PART_*) DAQUELE membro.
		var mgroup := str(_member_entries[msel - 2]["group"])
		var owners := _sub_member_owner_map()
		for body in _member_bodies():
			var g := str((body as StaticBody3D).get_meta("group"))
			if not g.begins_with("PART_"):
				continue
			if str(owners.get(g, "")) != mgroup:
				continue
			var lab := str((body as StaticBody3D).get_meta("member_label")) \
				if (body as StaticBody3D).has_meta("member_label") else g.substr(len("PART_"))
			_sub_member_entries.append({"group": g, "label": lab})
		_sub_member_entries.sort_custom(func(a, b): return a["label"] < b["label"])
	if _sub_member_entries.is_empty():
		cbo_sub_members.select(0)
		cbo_sub_members.disabled = true
		sub_member_row.visible = false
		return
	for e in _sub_member_entries:
		cbo_sub_members.add_item(str(e["label"]))
	sub_member_row.visible = true
	cbo_sub_members.select(maxi(_sub_member_index_for_value(prev), 0))
	cbo_sub_members.disabled = false


func _reset_sub_members() -> void:
	cbo_sub_members.clear()
	cbo_sub_members.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_sub_members.select(0)
	cbo_sub_members.disabled = true
	sub_member_row.visible = false
	_sub_member_entries = []
	_reset_skeleton()


# Esconde/limpa o dropdown "Esqueleto" (modo "Todos os membros").
func _reset_skeleton() -> void:
	cbo_skeleton.clear()
	cbo_skeleton.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_skeleton.select(0)
	cbo_skeleton.disabled = true
	skeleton_row.visible = false
	_skeleton_entries = []


# Dropdown "Esqueleto" (só no modo "Todos os membros", cbo_members índice 1): lista os OSSOS AVULSOS
# — candidatos a sub-membro (group_of == "" e ainda não promovidos), os MESMOS do "Adicionar
# sub-membro" da janela de dano. Só inspeção/realce (não têm collider, não isolam). Com candidatos,
# oferece "Todo o esqueleto" no topo. SEMPRE visível no modo "Todos os membros" — VAZIO aparece
# DESABILITADO (só "Selecione..."). Some em qualquer outro modo de "Membro".
func _populate_skeleton() -> void:
	# Restaura o valor PERSISTIDO (sel_skeleton) sempre que exibido; sem valor válido → "Selecione...".
	var prev := String(Settings.config_file.get_value("models", "sel_skeleton", ""))
	_skeleton_entries = []
	cbo_skeleton.clear()
	cbo_skeleton.add_item(Locale.tr_key(SELECT_LABEL))
	if not member_row.visible or cbo_members.selected != 1:
		cbo_skeleton.select(0)
		cbo_skeleton.disabled = true
		skeleton_row.visible = false
		return
	var aux := _aux_bone_candidates()
	if not aux.is_empty():
		_skeleton_entries.append({"group": ALL_AUX_VALUE, "label": Locale.tr_key(ALL_AUX_LABEL)})
	for bn in aux:
		_skeleton_entries.append({"group": bn, "label": bn})
	for e in _skeleton_entries:
		cbo_skeleton.add_item(str(e["label"]))
	skeleton_row.visible = true   # visível mesmo vazio (fica desabilitado abaixo)
	if _skeleton_entries.is_empty():
		cbo_skeleton.select(0)
		cbo_skeleton.disabled = true
		return
	cbo_skeleton.select(maxi(_skeleton_index_for_value(prev), 0))
	cbo_skeleton.disabled = false


# Valor estável (group: nome do osso avulso ou ALL_AUX_VALUE) de um índice; "" no placeholder/inválido.
func _skeleton_value(index: int) -> String:
	if index <= 0 or index - 1 >= _skeleton_entries.size():
		return ""
	return str(_skeleton_entries[index - 1]["group"])


# Inverso: índice do combo "Esqueleto" para um group salvo (0 quando vazio/inexistente).
func _skeleton_index_for_value(value: String) -> int:
	if value == "":
		return 0
	for i in _skeleton_entries.size():
		if str(_skeleton_entries[i]["group"]) == value:
			return i + 1
	return 0


# Escolher um osso avulso no dropdown "Esqueleto" (modo "Todos os membros"): persiste e reaplica o
# realce/rótulo. NÃO isola collider (esses ossos não têm) — só inspeção visual. A seleção é PERSISTIDA e
# recarregada na restauração; numa seleção FRESCA de "Todos os membros", porém, inicia em "Selecione...".
func _on_skeleton_selected(index: int) -> void:
	_save_selection("sel_skeleton", _skeleton_value(index))
	_refresh_aux_highlight()
	_refresh_aux_labels()
	_refresh_collider_editors()   # dropdown de geometria do osso avulso + janela Afastamento/Escala


# Escolher um membro: persiste, repopula os sub-membros daquele membro e reaplica o isolamento.
func _on_member_selected(index: int) -> void:
	_save_selection("sel_member", _member_value(index))
	# Sub-membro e Esqueleto carregam o valor PERSISTIDO (default "Selecione..." se não houver/for
	# inválido p/ este membro), via _populate_sub_members/_populate_skeleton. Ver req 2026-06-25.
	_populate_sub_members()
	_refresh_member_overlays()
	_refresh_aux_highlight()
	_refresh_aux_labels()
	_apply_malha_visibility()
	_refresh_skeleton_lines()


# Escolher um sub-membro (ou um osso avulso no modo "Todos os membros"): persiste e reaplica o
# isolamento e o realce.
func _on_sub_member_selected(index: int) -> void:
	_save_selection("sel_submember", _sub_member_value(index))
	_refresh_member_overlays()
	_refresh_aux_highlight()
	_refresh_aux_labels()
	_apply_malha_visibility()
	_refresh_skeleton_lines()


# Valor estável persistido de um índice de "Membro": "" (placeholder), ALL_MEMBERS_VALUE (índice 1
# = "Todos os membros") ou o group do membro (índices 2+, deslocados pelo item "Todos").
func _member_value(index: int) -> String:
	if index <= 0:
		return ""
	if index == 1:
		return ALL_MEMBERS_VALUE
	if index - 2 >= _member_entries.size():
		return ""
	return str(_member_entries[index - 2]["group"])


# Inverso de _member_value: o índice do combo para um valor salvo (0 quando vazio/inexistente).
func _member_index_for_value(value: String) -> int:
	if value == "":
		return 0
	if value == ALL_MEMBERS_VALUE:
		return 1
	for i in _member_entries.size():
		if str(_member_entries[i]["group"]) == value:
			return i + 2
	return 0


func _sub_member_value(index: int) -> String:
	if index <= 0 or index - 1 >= _sub_member_entries.size():
		return ""
	return str(_sub_member_entries[index - 1]["group"])


func _sub_member_index_for_value(value: String) -> int:
	if value == "":
		return 0
	for i in _sub_member_entries.size():
		if str(_sub_member_entries[i]["group"]) == value:
			return i + 1
	return 0


# Mapa PART_<osso> → group do membro DONO. Critérios, nesta ordem:
#   0) DONO EXPLÍCITO salvo em LimbConfig (escolhido pelo usuário ao Adicionar ou no dropdown "Dono"
#      da árvore): tem PRECEDÊNCIA — assim o sub-membro aparece sob o membro escolhido na árvore E no
#      dropdown "Sub-membro" (antes a tela ignorava o explícito e reagrupava por nome/hierarquia).
#   1) NOME da peça (classifier.owner_hint): uma placa costuma dizer no nome a que membro
#      pertence ("shoulderpad.L" → BRAÇO E), mesmo pendurada noutro osso. Resolve casos como
#      a ombreira do player, filha do "chest" (a hierarquia a colocaria no TRONCO).
#   2) HIERARQUIA: sobe do osso da peça na cadeia de pais até o classificador devolver um
#      membro — esse é o dono (caso o nome não decida; ex.: placas penduradas no membro certo).
# Vazio para rigs sem esqueleto (não têm PART_*).
func _sub_member_owner_map() -> Dictionary:
	var out: Dictionary = {}
	if _preview_instance == null:
		return out
	var skels: Array = _preview_instance.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return out
	var skel := skels[0] as Skeleton3D
	var classifier := _current_classifier()
	var head := _head_bones_for_current()
	var torso := _torso_bones_for_current()
	var model_key := _current_model_key()
	# Resolvedor compartilhado com o rótulo (LimbColliders._part_label): nome da peça → owner_hint
	# subindo na hierarquia (pega escudos presos a ossos AUX/IK, ex.: L-Shield → L-ARMIK → BRAÇO).
	for body in _member_bodies():
		var g := str((body as StaticBody3D).get_meta("group"))
		if not g.begins_with("PART_"):
			continue
		var bone_name := g.substr(len("PART_"))
		var explicit := LimbConfig.sub_member_owner(model_key, bone_name)
		if explicit != "":
			out[g] = explicit
		else:
			out[g] = LimbColliders.resolve_sub_member_owner(skel, bone_name, classifier, head, torso, [])
	return out


# Conjunto de groups em FOCO conforme os dropdowns, ou null quando não há isolamento
# (row escondida ou "Membro" no placeholder). SEM sub-membro escolhido → foca SÓ o collider do
# MEMBRO (não inclui os sub-membros). COM um sub-membro escolhido → foca SÓ aquele sub-membro
# (não inclui o membro). Assim o isolamento mostra exatamente uma peça por vez.
func _current_focus_groups():
	if not member_row.visible:
		return null
	var msel := cbo_members.selected
	if msel <= 0:
		return null
	# "Todos os membros" (índice 1): o dropdown "Sub-membro" isola UM sub-membro (PART_*) escolhido;
	# "Todos os Sub-membros"/"Selecione..." → não isola (mostra o modelo inteiro). O dropdown
	# "Esqueleto" (ossos avulsos) é só inspeção/realce e NUNCA isola (esses ossos não têm collider).
	if msel == 1:
		var v_all := _sub_member_value(cbo_sub_members.selected)
		if v_all.begins_with("PART_"):
			return {v_all: true}
		return null
	var ssel := cbo_sub_members.selected
	# Membro específico com sub-membro escolhido → isola SÓ aquele sub-membro.
	if sub_member_row.visible and ssel >= 1 and ssel - 1 < _sub_member_entries.size():
		return {str(_sub_member_entries[ssel - 1]["group"]): true}
	if msel - 2 >= _member_entries.size():
		return null
	return {str(_member_entries[msel - 2]["group"]): true}


# Reaplica os overlays de membro (gizmos de collider + pilhas de label) respeitando o foco
# dos dropdowns. SEM foco: estado normal dos toggles (Colisores de Membro/Rótulos). COM foco: isola
# só o membro/sub-membro escolhido. O gizmo do collider segue o toggle MESTRE conforme o tipo:
# MEMBRO → "Colisores de Membro" (_show_colliders); SUB-MEMBRO (PART_*) → "Colisores de Submembros"
# (_show_sub_colliders). O isolamento dos RÓTULOS independe desses toggles (segue os de Rótulos). O
# ramo de foco não remove gizmos (só adiciona/esconde), evitando corrida com o queue_free do
# _apply_colliders_visibility (que limpa os gizmos quando o toggle está off).
func _refresh_member_overlays() -> void:
	if _preview_instance == null:
		return
	_refresh_collider_editors()
	_refresh_sub_member_labels()
	var focus = _current_focus_groups()
	if focus == null:
		_apply_colliders_visibility()
		_apply_member_labels_visibility()
		return
	_ensure_member_colliders()
	_apply_member_labels_visibility()        # (re)cria as pilhas conforme os toggles
	if _show_colliders or _show_sub_colliders:
		_add_collider_gizmos(_preview_instance)  # idempotente: garante gizmo no membro/sub em foco
	for body in _member_bodies():
		var grp := str((body as StaticBody3D).get_meta("group"))
		var in_focus: bool = focus.has(grp)
		# Gizmo visível só em foco E com o toggle MESTRE do tipo ligado (membro vs sub-membro).
		var giz_on: bool = in_focus and (_show_sub_colliders if grp.begins_with("PART_") else _show_colliders)
		for giz in body.find_children(_GIZMO_NAME, "MeshInstance3D", true, false):
			(giz as MeshInstance3D).visible = giz_on
		# Pilha de rótulos: isolamento independe dos toggles de collider (o pivô agrupa as linhas;
		# em foco fica visível e cada linha mantém o próprio toggle).
		for piv in body.find_children(_LABEL_PREFIX + "Pivot", "Node3D", true, false):
			(piv as Node3D).visible = in_focus


# ── Geometria do collider + janela de Afastamento/Escala (Membro/Sub-membro/Esqueleto) ─────────
#
# Ao escolher um item REAL (não "Selecione..."/"Todos") num dos três dropdowns, aparece à direita um
# dropdown de TIPO DE GEOMETRIA (Esfera/Caixa/Cápsula) e abre-se a janela flutuante REUTILIZÁVEL
# (FloatingWindow) com Afastamento e Escala, intitulada com o NOME do item. Tudo persiste em LimbConfig
# e aplica AO VIVO na hora; o gameplay relê na construção dos colliders (quando o personagem entra em cena).

# Popula um dropdown de geometria: 0 "Selecione..." (= sem collider) + Esfera/Caixa/Cápsula. O VALOR
# estável ("", "sphere", "box", "capsule") fica na metadata de cada item.
func _populate_geo_dropdown(combo: OptionButton) -> void:
	combo.clear()
	combo.add_item(Locale.tr_key(SELECT_LABEL)); combo.set_item_metadata(0, "")
	combo.add_item(Locale.tr_key("Esfera")); combo.set_item_metadata(1, "sphere")
	combo.add_item(Locale.tr_key("Caixa")); combo.set_item_metadata(2, "box")
	combo.add_item(Locale.tr_key("Cápsula")); combo.set_item_metadata(3, "capsule")


# Re-traduz os rótulos de um dropdown de geometria (troca de idioma; preserva a seleção/metadata).
func _relabel_geo_dropdown(combo: OptionButton) -> void:
	if combo.item_count < 4:
		return
	combo.set_item_text(0, Locale.tr_key(SELECT_LABEL))
	combo.set_item_text(1, Locale.tr_key("Esfera"))
	combo.set_item_text(2, Locale.tr_key("Caixa"))
	combo.set_item_text(3, Locale.tr_key("Cápsula"))


# Índice do dropdown de geometria para um valor de forma. "none" (membro suprimido) e "" caem em 0.
func _geo_index_for_value(value: String) -> int:
	match value:
		"sphere": return 1
		"box": return 2
		"capsule": return 3
		_: return 0


# Forma do collider VIVO de um grupo no preview (sphere/box/capsule), ou "" se o grupo não tem corpo
# (ex.: osso avulso ainda não promovido). Deixa o dropdown refletir a forma automática atual.
func _live_shape_kind(group: String) -> String:
	for body in _member_bodies():
		if str((body as StaticBody3D).get_meta("group")) == group:
			for cs in body.find_children("*", "CollisionShape3D", true, false):
				var sh: Shape3D = (cs as CollisionShape3D).shape
				if sh is SphereShape3D:
					return "sphere"
				if sh is BoxShape3D:
					return "box"
				if sh is CapsuleShape3D:
					return "capsule"
			return ""
	return ""


# Geometria que melhor envolve uma região pelo seu AABB: um eixo BEM mais longo → CÁPSULA (alongado);
# três dimensões parecidas → ESFERA (arredondado); senão → CAIXA (chapa/placa). Para o autodetect.
func _auto_geo_for_box(box: AABB) -> String:
	var s := box.size
	if s == Vector3.ZERO:
		return ""
	var dims := [s.x, s.y, s.z]
	dims.sort()                 # ascendente: dims[0] menor, dims[2] maior
	if dims[1] > 0.0 and dims[2] >= 1.6 * dims[1]:
		return "capsule"        # um eixo domina os outros dois → alongado
	if dims[0] > 0.0 and dims[2] <= 1.3 * dims[0]:
		return "sphere"         # a ≈ b ≈ c → arredondado
	return "box"


# Geometria auto-detectada pelo FORMATO do osso de um grupo "PART_<osso>" (via AABB dos vértices); ""
# se não der (grupo não-PART_, sem preview/esqueleto/osso). Usada quando não há escolha salva nem corpo.
func _auto_geo_for_group(group: String) -> String:
	if not group.begins_with("PART_") or _preview_instance == null:
		return ""
	var skels: Array = _preview_instance.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return ""
	var skel := skels[0] as Skeleton3D
	var bidx := skel.find_bone(group.substr(len("PART_")))
	if bidx < 0:
		return ""
	return _auto_geo_for_box(LimbColliders.bone_vertex_box(skel, bidx))


# Seleciona no dropdown de geometria a forma do grupo (sem disparar sinal), em 3 estados:
#   • forma salva (sphere/box/capsule) → CARREGA a última escolha;
#   • `SHAPE_NONE` ("none") → "Selecione..." (sem collider, escolha explícita do usuário);
#   • sem escolha ("") → AUTODETECTA: forma VIVA do collider (membro/sub têm corpo) ou pelo FORMATO do osso.
func _select_geo_for_group(combo: OptionButton, group: String) -> void:
	var shape := LimbConfig.collider_shape(_current_model_key(), group)
	if shape == "sphere" or shape == "box" or shape == "capsule":
		combo.select(_geo_index_for_value(shape))
		return
	if shape == LimbConfig.SHAPE_NONE:
		combo.select(0)
		return
	var auto := _live_shape_kind(group)
	if auto == "":
		auto = _auto_geo_for_group(group)
	combo.select(_geo_index_for_value(auto))


# Group do MEMBRO específico em cbo_members (índices 2+), ou "" em "Selecione..."/"Todos os membros".
func _selected_member_group() -> String:
	if not member_row.visible or cbo_members.selected < 2 or cbo_members.selected - 2 >= _member_entries.size():
		return ""
	return str(_member_entries[cbo_members.selected - 2]["group"])


# Atualiza os 3 dropdowns de geometria (visibilidade + forma atual) e sincroniza a janela de
# Afastamento/Escala com o item escolhido. Chamado por _refresh_member_overlays e _on_skeleton_selected.
func _refresh_collider_editors() -> void:
	var sub_val := _sub_member_value(cbo_sub_members.selected) if sub_member_row.visible else ""
	var sub_real := sub_val.begins_with("PART_")
	# Membro: o dropdown de geometria do MEMBRO some quando um SUB-MEMBRO específico está escolhido —
	# aí vale o geo do sub-membro. Visível só com um membro específico E sem sub-membro específico.
	var mg := _selected_member_group()
	cbo_member_geo.visible = mg != "" and not sub_real
	if cbo_member_geo.visible:
		_select_geo_for_group(cbo_member_geo, mg)
	cbo_sub_member_geo.visible = sub_real
	if sub_real:
		_select_geo_for_group(cbo_sub_member_geo, sub_val)
	var skel_val := _skeleton_value(cbo_skeleton.selected) if (skeleton_row.visible and not cbo_skeleton.disabled) else ""
	var skel_real := skel_val != "" and skel_val != ALL_AUX_VALUE
	cbo_skeleton_geo.visible = skel_real
	if skel_real:
		# Osso avulso: carrega a ÚLTIMA escolha salva (forma ou SHAPE_NONE); sem escolha → "Selecione..."
		# (= sem limbcollider). Sem auto-detecção de forma padrão.
		_select_geo_for_group(cbo_skeleton_geo, "PART_" + skel_val)
	_sync_collider_dialog()


# Item ÚNICO em edição (para a janela de Afastamento/Escala), por precedência esqueleto > sub > membro.
# {group, label} ou {} quando nada está escolhido. group é "PART_<osso>" p/ sub/avulso, ou o membro.
func _current_edit_target() -> Dictionary:
	if not member_row.visible:
		return {}
	if skeleton_row.visible and not cbo_skeleton.disabled:
		var sv := _skeleton_value(cbo_skeleton.selected)
		if sv != "" and sv != ALL_AUX_VALUE:
			return {"group": "PART_" + sv, "label": sv}
	if sub_member_row.visible:
		var sub := _sub_member_value(cbo_sub_members.selected)
		if sub.begins_with("PART_"):
			return {"group": sub, "label": _group_label(sub)}
	# Membro: usa o rótulo do PLANO (CABEÇA/BRAÇO E…) — vale mesmo suprimido (sem corpo para _group_label).
	if _selected_member_group() != "":
		var e: Dictionary = _member_entries[cbo_members.selected - 2]
		return {"group": str(e["group"]), "label": str(e["label"])}
	return {}


# Escolher geometria do MEMBRO: "Selecione..." REMOVE o collider (SHAPE_NONE); senão sobrescreve a
# forma. Persiste, reconstrói o preview (mostra na hora) e o gameplay relê no spawn.
func _on_member_geo_selected(index: int) -> void:
	var g := _selected_member_group()
	if g == "":
		return
	var value := str(cbo_member_geo.get_item_metadata(index))
	LimbConfig.set_collider_shape(_current_model_key(), g, LimbConfig.SHAPE_NONE if value == "" else value)
	_rebuild_member_colliders()


# Escolher geometria do SUB-MEMBRO: **"Selecione..." SUPRIME o collider** (SHAPE_NONE) — o sub-membro
# CONTINUA na árvore/dropdown (corpo suprimido sem gizmo, via include_suppressed) p/ reconfigurar;
# remover de vez é pela lixeira da janela de Dano. Senão, sobrescreve a forma. Persiste + mostra na hora.
func _on_sub_member_geo_selected(index: int) -> void:
	var g := _sub_member_value(cbo_sub_members.selected)
	if not g.begins_with("PART_"):
		return
	var value := str(cbo_sub_member_geo.get_item_metadata(index))
	LimbConfig.set_collider_shape(_current_model_key(), g, LimbConfig.SHAPE_NONE if value == "" else value)
	_rebuild_member_colliders()


# Escolher geometria de um OSSO AVULSO ("Esqueleto"): persiste a escolha e atualiza o realce — **NÃO
# promove** o osso a sub-membro (preview-only; esqueletos não têm dano e não entram nos levels). A
# promoção (criar o collider de fato) é pela janela de Dano ("Adicionar sub-membro"). **"Selecione..."
# (value "") REMOVE o limbcollider de preview** gravando SHAPE_NONE (persistido) → o realce some.
func _on_skeleton_geo_selected(index: int) -> void:
	var bone := _skeleton_value(cbo_skeleton.selected)
	if bone == "" or bone == ALL_AUX_VALUE:
		return
	var value := str(cbo_skeleton_geo.get_item_metadata(index))
	LimbConfig.set_collider_shape(_current_model_key(), "PART_" + bone, LimbConfig.SHAPE_NONE if value == "" else value)
	_refresh_aux_highlight()   # o realce "Colisor de Esqueleto" passa a usar a nova forma (ou some)


# Aplica afastamento (posição do StaticBody3D), rotação (graus, no corpo) e escala (na forma, em torno
# do seu centro) de um grupo no preview vivo — gizmo/rótulo acompanham. No-op se o grupo não tem corpo.
func _apply_collider_xform(group: String, offset: Vector3, scale: Vector3, rotation: Vector3) -> void:
	for body in _member_bodies():
		if str((body as StaticBody3D).get_meta("group")) == group:
			(body as StaticBody3D).position = offset
			(body as StaticBody3D).rotation_degrees = rotation
			for cs in body.find_children("*", "CollisionShape3D", true, false):
				(cs as CollisionShape3D).scale = scale
			return


# Rótulo legível do grupo (membro/sub-membro): a meta "member_label" do corpo, ou o próprio group.
func _group_label(group: String) -> String:
	for body in _member_bodies():
		if str((body as StaticBody3D).get_meta("group")) == group and body.has_meta("member_label"):
			return str(body.get_meta("member_label"))
	return group


# ── Janela flutuante reutilizável de Afastamento/Escala ────────────────────────

# Abre/atualiza/fecha a janela conforme o item em edição (_current_edit_target). Respeita um fechamento
# manual (× / ESC) do mesmo alvo: não reabre até o alvo mudar.
func _sync_collider_dialog() -> void:
	var target := _current_edit_target()
	if target.is_empty():
		_close_collider_dialog()
		_dialog_dismissed_group = ""
		return
	var g := str(target["group"])
	if g == _dialog_dismissed_group:
		return
	_dialog_dismissed_group = ""
	_open_or_update_collider_dialog(g, str(target["label"]))


# (Re)abre a janela reutilizável (FloatingWindow) com Afastamento/Escala do grupo; título = nome do item.
func _open_or_update_collider_dialog(group: String, label: String) -> void:
	if _collider_dialog != null and is_instance_valid(_collider_dialog):
		_dialog_group = group
		_collider_dialog.set_title(label)
		_load_dialog_values(group)
		return
	var dlg: FloatingWindow = _FLOATING_WINDOW.instantiate()
	dlg.modal = false                      # não escurece/bloqueia: dá p/ girar o modelo com ela aberta
	dlg.close_on_escape = true
	dlg.min_window_size = Vector2(380, 250)
	dlg.remember_position_key = "models_collider_dialog"
	dlg.title = label
	ui_root.add_child(dlg)
	_collider_dialog = dlg
	_dialog_group = group
	_build_collider_dialog_content(dlg)
	dlg.closed.connect(_on_collider_dialog_closed)
	_load_dialog_values(group)
	dlg.popup_centered()


# Monta Afastamento (X/Y/Z), Rotação (X/Y/Z, graus) e Escala (X/Y/Z) no conteúdo da janela; cada
# mudança persiste + aplica ao vivo.
func _build_collider_dialog_content(dlg: FloatingWindow) -> void:
	var content := dlg.get_content()
	var off := _make_vec3_row(content, "Afastamento:", -10.0, 10.0, 0.01, 0.0)
	_dlg_off_x = off[0]; _dlg_off_y = off[1]; _dlg_off_z = off[2]
	var rot := _make_vec3_row(content, "Rotação:", -360.0, 360.0, 1.0, 0.0)
	_dlg_rot_x = rot[0]; _dlg_rot_y = rot[1]; _dlg_rot_z = rot[2]
	var sc := _make_vec3_row(content, "Escala:", 0.05, 20.0, 0.05, 1.0)
	_dlg_scale_x = sc[0]; _dlg_scale_y = sc[1]; _dlg_scale_z = sc[2]
	for sp in [_dlg_off_x, _dlg_off_y, _dlg_off_z, _dlg_rot_x, _dlg_rot_y, _dlg_rot_z, _dlg_scale_x, _dlg_scale_y, _dlg_scale_z]:
		(sp as SpinBox).value_changed.connect(_on_dialog_field_changed)


# Linha "rótulo: X[ ] Y[ ] Z[ ]" de 3 SpinBox; devolve os 3. Rótulos auto-localizados pelo Locale.
func _make_vec3_row(parent: Control, label_text: String, mn: float, mx: float, step: float, default_v: float) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 110
	row.add_child(lbl)
	var spins: Array = []
	for axis in ["X", "Y", "Z"]:
		var al := Label.new()
		al.text = axis
		row.add_child(al)
		var sp := SpinBox.new()
		sp.custom_minimum_size = Vector2(90, 44)
		sp.min_value = mn
		sp.max_value = mx
		sp.step = step
		sp.value = default_v
		sp.allow_greater = true
		sp.allow_lesser = true
		row.add_child(sp)
		spins.append(sp)
	parent.add_child(row)
	return spins


# Carrega nos SpinBox da janela o afastamento/rotação/escala salvos do grupo (sem disparar sinais).
func _load_dialog_values(group: String) -> void:
	var off := LimbConfig.collider_offset(_current_model_key(), group)
	var rot := LimbConfig.collider_rotation(_current_model_key(), group)
	var sc := LimbConfig.collider_scale(_current_model_key(), group)
	_dlg_off_x.set_value_no_signal(off.x)
	_dlg_off_y.set_value_no_signal(off.y)
	_dlg_off_z.set_value_no_signal(off.z)
	_dlg_rot_x.set_value_no_signal(rot.x)
	_dlg_rot_y.set_value_no_signal(rot.y)
	_dlg_rot_z.set_value_no_signal(rot.z)
	_dlg_scale_x.set_value_no_signal(sc.x)
	_dlg_scale_y.set_value_no_signal(sc.y)
	_dlg_scale_z.set_value_no_signal(sc.z)


# Mudou um SpinBox da janela: persiste na hora (sem botão Salvar) e aplica AO VIVO no corpo do grupo
# (gizmo/rótulo acompanham). O gameplay relê esses valores no spawn.
func _on_dialog_field_changed(_v: float) -> void:
	if _dialog_group == "":
		return
	var model_key := _current_model_key()
	var off := Vector3(_dlg_off_x.value, _dlg_off_y.value, _dlg_off_z.value)
	var rot := Vector3(_dlg_rot_x.value, _dlg_rot_y.value, _dlg_rot_z.value)
	var sc := Vector3(_dlg_scale_x.value, _dlg_scale_y.value, _dlg_scale_z.value)
	LimbConfig.set_collider_offset(model_key, _dialog_group, off)
	LimbConfig.set_collider_rotation(model_key, _dialog_group, rot)
	LimbConfig.set_collider_scale(model_key, _dialog_group, sc)
	_apply_collider_xform(_dialog_group, off, sc, rot)
	# Osso avulso (sem corpo real): _apply_collider_xform é no-op; o realce "Colisor de Esqueleto" é
	# que previsualiza o collider, então o reconstruímos com o novo afastamento/escala. No-op fora disso.
	_refresh_aux_highlight()


# Fecha a janela por CÓDIGO (alvo sumiu) — não marca o grupo como "dispensado" (reabre se o alvo voltar).
func _close_collider_dialog() -> void:
	if _collider_dialog == null or not is_instance_valid(_collider_dialog):
		_collider_dialog = null
		_dialog_group = ""
		return
	_closing_dialog_programmatically = true
	_collider_dialog.close()
	_closing_dialog_programmatically = false


# A janela fechou (× / ESC do usuário, ou close() por código): limpa as refs. Fechamento MANUAL marca o
# grupo para não reabrir até o alvo mudar (ver _sync_collider_dialog).
func _on_collider_dialog_closed() -> void:
	if not _closing_dialog_programmatically:
		_dialog_dismissed_group = _dialog_group
	_collider_dialog = null
	_dialog_group = ""


func _on_rotate_toggled(pressed: bool) -> void:
	_auto_rotate = pressed
	_save_toggle("auto_rotate", pressed)


# Every toggle below acts on the EXISTING preview in place (play/stop, mute, show/
# hide) — never a rebuild — so the model is not reloaded and the camera/rotation
# stay exactly as the user left them.
func _on_animation_toggled(pressed: bool) -> void:
	_play_animation = pressed
	_save_toggle("play_animation", pressed)
	_apply_animation_state()


func _on_audio_toggled(pressed: bool) -> void:
	_play_audio = pressed
	_save_toggle("play_audio", pressed)
	_apply_audio_state()


func _on_colliders_toggled(pressed: bool) -> void:
	_show_colliders = pressed
	_save_toggle("show_colliders", pressed)
	# Via _refresh_member_overlays (não direto _apply_colliders_visibility) para o
	# isolamento Membro/Sub-membro, se ativo, continuar valendo após mexer no toggle.
	_refresh_member_overlays()


# ── Realce de "osso avulso" (toggle "Esqueleto") ──────────────────────────────

func _on_aux_highlight_toggled(pressed: bool) -> void:
	_show_aux_highlight = pressed
	_save_toggle("show_aux_highlight", pressed)
	_refresh_aux_highlight()


# Decide o que realçar a partir do toggle + do filtro "Ossos avulsos" (só vale no modo
# "Todos os membros"). "Selecione..." ou toggle off → sem realce (modelo inteiro). Um osso →
# realça aquele; "Todos os ossos avulsos" → realça todos os candidatos.
func _refresh_aux_highlight() -> void:
	if _preview_instance == null:
		return
	if not _show_aux_highlight or not member_row.visible or cbo_members.selected != 1:
		_clear_aux_highlights()
		return
	var ssel := cbo_skeleton.selected
	if ssel <= 0:
		_clear_aux_highlights()
		return
	var val := _skeleton_value(ssel)
	if val == ALL_AUX_VALUE:
		_highlight_aux_bones(_aux_bone_candidates())
	elif val != "":
		_highlight_aux_bones([val])
	else:
		_clear_aux_highlights()


# Remove as caixas de realce (filhas do esqueleto do preview).
func _clear_aux_highlights() -> void:
	if _preview_instance == null:
		return
	for n in _preview_instance.find_children(_AUX_HL_PREFIX + "*", "BoneAttachment3D", true, false):
		(n as Node).free()


# Desenha uma caixa translúcida (sem profundidade, por cima do modelo) ajustada à região de cada
# osso, presa via BoneAttachment3D para acompanhar a pose. NÃO esconde nada (realce "por cima").
func _highlight_aux_bones(bone_names: Array) -> void:
	_clear_aux_highlights()
	if _preview_instance == null:
		return
	var skels: Array = _preview_instance.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	var skel := skels[0] as Skeleton3D
	var model_key := _current_model_key()
	for bn in bone_names:
		var bidx := skel.find_bone(str(bn))
		if bidx < 0:
			continue
		var box := LimbColliders.bone_vertex_box(skel, bidx)
		if box.size == Vector3.ZERO:
			continue
		var att := BoneAttachment3D.new()
		att.name = _AUX_HL_PREFIX + str(bn)
		skel.add_child(att)
		att.bone_name = str(bn)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.no_depth_test = true
		mat.albedo_color = _AUX_HL_COLOR
		# Forma do realce: **`SHAPE_NONE` ("Selecione...") → SEM realce**; **sem escolha ("") → AUTODETECTA**
		# pelo formato do osso; forma salva → essa. O afastamento/escala salvos do osso também são aplicados
		# → o realce PREVISUALIZA o collider que o osso teria se promovido (o osso NÃO é promovido; preview-only).
		var group := "PART_" + str(bn)
		var kind := LimbConfig.collider_shape(model_key, group)
		if kind == LimbConfig.SHAPE_NONE:
			continue
		if kind == "":
			kind = _auto_geo_for_box(box)
			if kind == "":
				continue
		var cs := LimbColliders.make_shape(kind, box)
		var mi := MeshInstance3D.new()
		mi.mesh = _solid_mesh_for_shape(cs.shape)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transform = cs.transform                                    # centro + orientação da forma
		mi.scale = LimbConfig.collider_scale(model_key, group)         # escala em torno do centro da forma
		# Wrapper afastamento+rotação (espelha o StaticBody3D: offset → position, rotação → rotation_degrees).
		var holder := Node3D.new()
		holder.position = LimbConfig.collider_offset(model_key, group)
		holder.rotation_degrees = LimbConfig.collider_rotation(model_key, group)
		holder.add_child(mi)
		cs.free()
		att.add_child(holder)


# Mesh SÓLIDA (não-wireframe) equivalente a uma Shape3D primitiva, para o realce translúcido do osso
# avulso acompanhar a geometria escolhida (esfera/caixa/cápsula).
func _solid_mesh_for_shape(shape: Shape3D) -> Mesh:
	if shape is SphereShape3D:
		var sm := SphereMesh.new()
		sm.radius = (shape as SphereShape3D).radius
		sm.height = sm.radius * 2.0
		return sm
	if shape is CapsuleShape3D:
		var cm := CapsuleMesh.new()
		cm.radius = (shape as CapsuleShape3D).radius
		cm.height = (shape as CapsuleShape3D).height
		return cm
	var bm := BoxMesh.new()
	bm.size = (shape as BoxShape3D).size
	return bm


# ── Rótulo "Esqueleto: <nome>" do osso avulso (toggle "Esqueleto") ────────────

# Espelha _refresh_aux_highlight, mas para os NOMES: decide o que rotular a partir do toggle "Esqueleto"
# + do dropdown "Esqueleto" (só vale no modo "Todos os membros"). "Selecione..." ou toggle off →
# sem rótulo. Um osso → rotula aquele; "Todos os ossos avulsos" → rotula todos os candidatos.
func _refresh_aux_labels() -> void:
	if _preview_instance == null:
		return
	if not _show_osso or not member_row.visible or cbo_members.selected != 1:
		_clear_aux_labels()
		return
	var ssel := cbo_skeleton.selected
	if ssel <= 0:
		_clear_aux_labels()
		return
	var val := _skeleton_value(ssel)
	if val == ALL_AUX_VALUE:
		_label_aux_bones(_aux_bone_candidates())
	elif val != "":
		_label_aux_bones([val])
	else:
		_clear_aux_labels()


# Remove os rótulos de nome de osso avulso (filhos do esqueleto do preview).
func _clear_aux_labels() -> void:
	if _preview_instance == null:
		return
	for n in _preview_instance.find_children(_AUX_LBL_PREFIX + "*", "BoneAttachment3D", true, false):
		(n as Node).free()


# Desenha um Label3D (billboard, por cima do modelo) com o NOME de cada osso, preso via
# BoneAttachment3D para acompanhar a pose, posicionado um pouco acima da região do osso.
func _label_aux_bones(bone_names: Array) -> void:
	_clear_aux_labels()
	if _preview_instance == null:
		return
	var skels: Array = _preview_instance.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	var skel := skels[0] as Skeleton3D
	for bn in bone_names:
		var bidx := skel.find_bone(str(bn))
		if bidx < 0:
			continue
		var att := BoneAttachment3D.new()
		att.name = _AUX_LBL_PREFIX + str(bn)
		skel.add_child(att)
		att.bone_name = str(bn)
		var lbl := Label3D.new()
		lbl.text = "%s %s" % [Locale.tr_key("Esqueleto:"), str(bn)]
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		# Acima do realce/colliders e dos rótulos de membro, para o nome nunca ser engolido.
		lbl.render_priority = 5
		lbl.outline_render_priority = 4
		lbl.pixel_size = _LBL_PIXEL_SIZE
		lbl.font_size = _LBL_FONT_SIZE
		lbl.modulate = _AUX_LBL_COLOR
		lbl.outline_size = 4
		lbl.outline_modulate = Color(0, 0, 0, 0.8)
		# Posiciona um pouco acima do topo da caixa do osso (centro + meia-altura + folga).
		var box := LimbColliders.bone_vertex_box(skel, bidx)
		if box.size != Vector3.ZERO:
			lbl.position = box.position + box.size * 0.5 + Vector3(0.0, box.size.y * 0.5 + 0.05, 0.0)
		att.add_child(lbl)
		# Linhas TYPE/Name/Id (cores próprias) descrevendo o OSSO, acima do "Esqueleto: …".
		_add_tni_lines(att, att, str(bn), lbl.position, _AUX_LBL_PREFIX + "L_")


# ── Rótulo "Submembro: <nome>" (toggle "Submembros") ──────────────────────────

# Rotula o sub-membro SELECIONADO no dropdown "Sub-membro" com um Label3D "Submembro: <nome>".
# Vale com um membro específico OU "Todos os membros" (ambos listam sub-membros) e um sub-membro
# (PART_*) escolhido. Placeholder/"Todos os Sub-membros"/toggle off → sem rótulo.
func _refresh_sub_member_labels() -> void:
	if _preview_instance == null:
		return
	if not _show_sub_member_label or not member_row.visible:
		_clear_sub_member_labels()
		return
	var msel := cbo_members.selected
	# msel <= 0: placeholder (sem membro). Em "Todos os membros" (1) o dropdown "Sub-membro" também
	# lista sub-membros, então rotula o PART_* escolhido (a checagem de val.begins_with abaixo filtra).
	if msel <= 0:
		_clear_sub_member_labels()
		return
	var ssel := cbo_sub_members.selected
	if ssel <= 0:
		_clear_sub_member_labels()
		return
	var val := _sub_member_value(ssel)
	if not val.begins_with("PART_"):
		_clear_sub_member_labels()
		return
	_label_sub_member(val)


# Remove os rótulos de sub-membro (filhos dos corpos do preview).
func _clear_sub_member_labels() -> void:
	if _preview_instance == null:
		return
	for n in _preview_instance.find_children(_SUB_LBL_PREFIX + "*", "Label3D", true, false):
		(n as Node).free()


# Desenha um Label3D "Submembro: <nome>" preso ao corpo (StaticBody3D) do sub-membro, posicionado
# acima da sua forma de colisão (acompanha a pose, pois o corpo é ancorado ao osso animado).
func _label_sub_member(group: String) -> void:
	_clear_sub_member_labels()
	for body in _member_bodies():
		if str((body as StaticBody3D).get_meta("group")) != group:
			continue
		var shapes: Array = body.find_children("*", "CollisionShape3D", true, false)
		if shapes.is_empty():
			return
		var name_txt := str(body.get_meta("member_label")) if body.has_meta("member_label") else group.substr(len("PART_"))
		var lbl := Label3D.new()
		lbl.name = _SUB_LBL_PREFIX + group
		lbl.text = "%s %s" % [Locale.tr_key("Sub-membro:"), name_txt]
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.render_priority = 5
		lbl.outline_render_priority = 4
		lbl.pixel_size = _LBL_PIXEL_SIZE
		lbl.font_size = _LBL_FONT_SIZE
		lbl.modulate = _SUB_LBL_COLOR
		lbl.outline_size = 4
		lbl.outline_modulate = Color(0, 0, 0, 0.8)
		# Acima da forma do collider (centro + meia-altura + folga).
		var cs := shapes[0] as CollisionShape3D
		var top := cs.position
		if cs.shape != null:
			top += Vector3(0.0, cs.shape.get_debug_mesh().get_aabb().size.y * 0.5 * cs.scale.y + 0.06, 0.0)
		lbl.position = top
		body.add_child(lbl)
		# Linhas TYPE/Name/Id (cores próprias) descrevendo o SUBMEMBRO, acima do "Submembro: …".
		_add_tni_lines(body, body, name_txt, top, _SUB_LBL_PREFIX + "L_")
		return


# Adiciona, sobre `parent`, as linhas TYPE/Name/Id (cores de _LABEL_LINE_COLORS) descrevendo o
# ELEMENTO `node` (classe/nome/id), empilhadas ACIMA de `base_pos`. Cada linha aparece só se o seu
# toggle (_show_type/_show_name/_show_id) estiver ligado. `name_txt` = nome do osso/submembro.
func _add_tni_lines(parent: Node3D, node: Object, name_txt: String, base_pos: Vector3, prefix: String) -> void:
	var lines := [
		{"id": "Type", "on": _show_type, "text": "%s %s" % [Locale.tr_key("Tipo:"), node.get_class()]},
		{"id": "Name", "on": _show_name, "text": "%s %s" % [Locale.tr_key("Nome:"), name_txt]},
		{"id": "Id", "on": _show_id, "text": "%s %d" % [Locale.tr_key("ID:"), node.get_instance_id()]},
	]
	var y := base_pos.y
	for line in lines:
		if not line["on"]:
			continue
		y += 0.06
		var l := Label3D.new()
		l.name = prefix + str(line["id"])
		l.text = str(line["text"])
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.render_priority = 5
		l.outline_render_priority = 4
		l.pixel_size = _LBL_PIXEL_SIZE
		l.font_size = _LBL_FONT_SIZE
		l.modulate = _LABEL_LINE_COLORS[str(line["id"])]
		l.outline_size = 4
		l.outline_modulate = Color(0, 0, 0, 0.8)
		l.position = Vector3(base_pos.x, y, base_pos.z)
		parent.add_child(l)


# Toggle PRÓPRIO dos rótulos de membro do browser: liga/desliga os Label3D "Membro: …"
# sobre os colliders, sem depender da tela de Debug 3D.
func _on_labels_toggled(pressed: bool) -> void:
	_show_member_labels = pressed
	_save_toggle("show_member_labels", pressed)
	_refresh_member_overlays()


# Checkboxes dedicados das linhas extras do tooltip (Skeleton3D): Tipo/Nome/ID. Cada um
# liga/desliga sua linha, independente do Debug 3D global (que só vale nos levels).
func _on_type_toggled(pressed: bool) -> void:
	_show_type = pressed
	_save_toggle("show_type", pressed)
	_refresh_member_overlays()   # membro + submembro
	_refresh_aux_labels()        # esqueleto (osso avulso)


func _on_name_toggled(pressed: bool) -> void:
	_show_name = pressed
	_save_toggle("show_name", pressed)
	_refresh_member_overlays()
	_refresh_aux_labels()


func _on_id_toggled(pressed: bool) -> void:
	_show_id = pressed
	_save_toggle("show_id", pressed)
	_refresh_member_overlays()
	_refresh_aux_labels()


# Toggle "Esqueleto" (ex-"SubMembro"): liga/desliga o rótulo 3D "Esqueleto: <nome>" do osso avulso
# escolhido no dropdown "Esqueleto". Não toca nos colliders/labels de membro (segue a mesma seleção do realce).
func _on_osso_toggled(pressed: bool) -> void:
	_show_osso = pressed
	_save_toggle("show_osso", pressed)
	_refresh_aux_labels()


# Toggle "Colisores de Submembros": liga/desliga o gizmo do limbcollider do sub-membro selecionado
# no dropdown. Via _refresh_member_overlays (respeita o foco do dropdown Membro/Sub-membro).
func _on_sub_colliders_toggled(pressed: bool) -> void:
	_show_sub_colliders = pressed
	_save_toggle("show_sub_colliders", pressed)
	_refresh_member_overlays()


# Toggle "Submembros": liga/desliga o rótulo 3D "Submembro: <nome>" do sub-membro selecionado.
func _on_sub_member_label_toggled(pressed: bool) -> void:
	_show_sub_member_label = pressed
	_save_toggle("show_sub_member_label", pressed)
	_refresh_sub_member_labels()


# Toggle "Malha": mostra/esconde a malha do modelo do preview (efeito só nesta cena).
func _on_malha_toggled(pressed: bool) -> void:
	_show_malha = pressed
	_save_toggle("show_malha", pressed)
	_apply_malha_visibility()


# Toggle "Linhas do Esqueleto": liga/desliga as linhas brancas osso→pai do preview.
func _on_skeleton_lines_toggled(pressed: bool) -> void:
	_show_skeleton_lines = pressed
	_save_toggle("show_skeleton_lines", pressed)
	_refresh_skeleton_lines()


# Mostra/esconde a malha (MeshInstance3D) do modelo do preview. Pula os gizmos de debug
# (nomes com prefixo "_": _ColliderGizmo, _AuxHL_, _SkeletonLines…), que seguem visíveis.
func _apply_malha_visibility() -> void:
	if _preview_instance == null:
		return
	for mi in _preview_instance.find_children("*", "MeshInstance3D", true, false):
		if (mi as Node).name.begins_with("_"):
			continue
		(mi as MeshInstance3D).visible = _show_malha


# Cria/remove o gizmo de linhas do esqueleto sob o Skeleton3D do preview, conforme o toggle.
func _refresh_skeleton_lines() -> void:
	if is_instance_valid(_skeleton_lines_mi):
		_skeleton_lines_mi.queue_free()
		_skeleton_lines_mi = null
	if not _show_skeleton_lines or _preview_instance == null:
		return
	var skels: Array = _preview_instance.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	var skel := skels[0] as Skeleton3D
	var mi := MeshInstance3D.new()
	mi.name = "_SkeletonLines"
	mi.mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.albedo_color = Color(1, 1, 1)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skel.add_child(mi)
	_skeleton_lines_mi = mi
	_update_skeleton_lines()


# Refaz as linhas osso→pai a partir da pose viva (espaço local do Skeleton3D = espaço do gizmo).
func _update_skeleton_lines() -> void:
	if not is_instance_valid(_skeleton_lines_mi):
		return
	var skel := _skeleton_lines_mi.get_parent() as Skeleton3D
	if skel == null:
		return
	var im := _skeleton_lines_mi.mesh as ImmediateMesh
	im.clear_surfaces()
	if skel.get_bone_count() == 0:
		return
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for b in skel.get_bone_count():
		var parent := skel.get_bone_parent(b)
		if parent == -1:
			continue
		im.surface_add_vertex(skel.get_bone_global_pose(b).origin)
		im.surface_add_vertex(skel.get_bone_global_pose(parent).origin)
	im.surface_end()


# True quando QUALQUER linha de rótulo de membro está ligada (Membro/Tipo/Nome/ID) — decide
# construir colliders/labels do preview, já sem ler nada do Debug 3D global.
func _any_member_label() -> bool:
	return _show_member_labels or _show_type or _show_name or _show_id


# Abre/fecha o painel de edição de dano por membro (só popula para personagem em
# "Modelo completo"; _refresh_damage_panel decide a visibilidade real).
# Botão "Dano" (à direita do "Voltar"): abre a JANELA de Dano. O × da janela a fecha
# (_on_damage_close). Antes era um toggle na lista; virou botão de ação dedicado.
func _on_damage_button_pressed() -> void:
	# Toggle: se a janela de Dano JÁ está aberta, o mesmo botão a fecha.
	if damage_panel.visible:
		_show_damage_panel = false
		_refresh_damage_panel()
		return
	# Sem bloqueio: o Dano abre para QUALQUER modelo (em "Modelo completo"). Abrir o Dano fecha a IA
	# (só UMA janela flutuante por vez, mas o botão nunca é bloqueado pela outra).
	_show_ai_panel = false
	_show_damage_panel = true
	_refresh_ai_panel()
	_refresh_damage_panel()
	# Reposiciona para dentro da tela (offsets default/salvos podem cair fora). Deferido: o painel
	# só ganha size real após o layout desta troca de visibilidade.
	if damage_panel.visible:
		_clamp_window_to_viewport.call_deferred(damage_panel)


# Transforma o painel de dano numa JANELA FLUTUANTE estilo Windows: barra de título com fundo
# próprio (área de arraste com cursor de mover) + botão × (fechar). Chamado uma vez em _ready.
func _setup_damage_window() -> void:
	# Fundo da JANELA: preto OPACO (alpha 1) com uma borda discreta.
	var win_style := StyleBoxFlat.new()
	win_style.bg_color = Color(0, 0, 0, 1)
	win_style.border_color = Color(1, 1, 1, 0.18)
	win_style.set_border_width_all(1)
	win_style.set_corner_radius_all(4)
	damage_panel.add_theme_stylebox_override("panel", win_style)
	# Barra de título: cinza-escuro OPACO (contraste com o corpo preto), estilo janela do Windows.
	var tb_style := StyleBoxFlat.new()
	tb_style.bg_color = Color(0.16, 0.16, 0.2, 1)
	tb_style.border_color = Color(1, 1, 1, 0.12)
	tb_style.border_width_bottom = 1
	tb_style.content_margin_left = 10
	tb_style.content_margin_right = 6
	tb_style.content_margin_top = 4
	tb_style.content_margin_bottom = 4
	damage_titlebar.add_theme_stylebox_override("panel", tb_style)
	damage_titlebar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	damage_titlebar.gui_input.connect(_on_damage_titlebar_input)
	damage_close_button.tooltip_text = Locale.tr_key("Fechar")
	FloatingWindow.style_close_button(damage_close_button)
	damage_close_button.pressed.connect(_on_damage_close)
	# Restaura a ÚLTIMA posição salva da janela (default = posição do .tscn). Presa à viewport
	# para nunca abrir fora da tela caso o valor salvo tenha ficado além da borda.
	var saved_pos = Settings.config_file.get_value("models", "damage_panel_pos", damage_panel.position)
	if saved_pos is Vector2:
		var vp := get_viewport().get_visible_rect().size
		var sz: Vector2 = damage_panel.size if damage_panel.size.x > 0 else (damage_panel.get_rect().size)
		saved_pos.x = clampf(saved_pos.x, 0.0, maxf(0.0, vp.x - sz.x))
		saved_pos.y = clampf(saved_pos.y, 0.0, maxf(0.0, vp.y - sz.y))
		damage_panel.position = saved_pos


# Persiste a posição atual da janela de dano (chamado ao terminar o arraste) — restaurada em
# _setup_damage_window na próxima abertura/visita.
func _save_damage_panel_pos() -> void:
	Settings.config_file.set_value("models", "damage_panel_pos", damage_panel.position)
	Settings.save_settings()


# Arraste da janela: clique-segura na barra de título e move o painel inteiro, preso à viewport.
func _on_damage_titlebar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_damage_panel_dragging = event.pressed
		if event.pressed:
			_damage_panel_drag_offset = damage_panel.position - damage_panel.get_global_mouse_position()
		else:
			_save_damage_panel_pos()   # salva a posição ao soltar
	elif event is InputEventMouseMotion and _damage_panel_dragging:
		var target := damage_panel.get_global_mouse_position() + _damage_panel_drag_offset
		var vp := get_viewport().get_visible_rect().size
		target.x = clampf(target.x, 0.0, maxf(0.0, vp.x - damage_panel.size.x))
		target.y = clampf(target.y, 0.0, maxf(0.0, vp.y - damage_panel.size.y))
		damage_panel.position = target


# Botão × (fechar): esconde a janela de Dano e limpa os campos flutuantes (mesmo efeito de
# reabrir depois pelo botão "Dano"). Mantém o estado coerente via _refresh_damage_panel.
func _on_damage_close() -> void:
	_damage_panel_dragging = false
	_show_damage_panel = false
	_refresh_damage_panel()


# Garante que a janela flutuante caiba INTEIRA na viewport ao abrir. As posições default do .tscn
# (offsets ~1300/1220, pensados p/ telas largas) e posições salvas de uma resolução maior caem FORA
# da tela em resoluções menores (ex.: 1280×720) → a janela "abria" (visible=true) mas ficava invisível
# à direita. Chamado DEFERIDO no open: a essa altura o layout já deu size real ao painel.
func _clamp_window_to_viewport(panel: Control) -> void:
	if not is_instance_valid(panel):
		return
	var vp := get_viewport().get_visible_rect().size
	var sz := panel.size
	if sz.x <= 0.0 or sz.y <= 0.0:
		sz = panel.get_combined_minimum_size()
	var pos := panel.position
	pos.x = clampf(pos.x, 0.0, maxf(0.0, vp.x - sz.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, vp.y - sz.y))
	panel.position = pos


func _supports_ai_editor() -> bool:
	return AIConfigLib.has_behavior_definitions(_current_model_key())


func _refresh_ai_actions() -> void:
	var supported := _supports_ai_editor()
	ai_button.visible = true
	ai_button.disabled = not supported
	if not supported:
		_show_ai_panel = false
	if is_instance_valid(ai_panel):
		ai_panel.visible = supported and _show_ai_panel


func _on_ai_button_pressed() -> void:
	# Toggle: se a janela de IA JÁ está aberta, o mesmo botão a fecha.
	if ai_panel.visible:
		_show_ai_panel = false
		_refresh_ai_panel()
		return
	# IA SÓ para personagens (modelos com comportamentos definidos). Sem bloqueio mútuo: abrir a IA
	# fecha o Dano (só UMA janela por vez), mas o botão nunca é bloqueado pela janela de Dano.
	if not _supports_ai_editor():
		return
	_show_damage_panel = false
	_show_ai_panel = true
	_refresh_damage_panel()
	_refresh_ai_panel()
	if ai_panel.visible:
		_clamp_window_to_viewport.call_deferred(ai_panel)


func _setup_ai_window() -> void:
	var win_style := StyleBoxFlat.new()
	win_style.bg_color = Color(0, 0, 0, 1)
	win_style.border_color = Color(1, 1, 1, 0.18)
	win_style.set_border_width_all(1)
	win_style.set_corner_radius_all(4)
	ai_panel.add_theme_stylebox_override("panel", win_style)
	var tb_style := StyleBoxFlat.new()
	tb_style.bg_color = Color(0.16, 0.16, 0.2, 1)
	tb_style.border_color = Color(1, 1, 1, 0.12)
	tb_style.border_width_bottom = 1
	tb_style.content_margin_left = 10
	tb_style.content_margin_right = 6
	tb_style.content_margin_top = 4
	tb_style.content_margin_bottom = 4
	ai_titlebar.add_theme_stylebox_override("panel", tb_style)
	ai_titlebar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	ai_titlebar.gui_input.connect(_on_ai_titlebar_input)
	ai_close_button.tooltip_text = Locale.tr_key("Fechar")
	FloatingWindow.style_close_button(ai_close_button)
	ai_close_button.pressed.connect(_on_ai_close)
	var saved_pos = Settings.config_file.get_value("models", "ai_panel_pos", ai_panel.position)
	if saved_pos is Vector2:
		var vp := get_viewport().get_visible_rect().size
		var sz: Vector2 = ai_panel.size if ai_panel.size.x > 0 else ai_panel.get_rect().size
		saved_pos.x = clampf(saved_pos.x, 0.0, maxf(0.0, vp.x - sz.x))
		saved_pos.y = clampf(saved_pos.y, 0.0, maxf(0.0, vp.y - sz.y))
		ai_panel.position = saved_pos


func _save_ai_panel_pos() -> void:
	Settings.config_file.set_value("models", "ai_panel_pos", ai_panel.position)
	Settings.save_settings()


func _on_ai_titlebar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_ai_panel_dragging = event.pressed
		if event.pressed:
			_ai_panel_drag_offset = ai_panel.position - ai_panel.get_global_mouse_position()
		else:
			_save_ai_panel_pos()
	elif event is InputEventMouseMotion and _ai_panel_dragging:
		var target := ai_panel.get_global_mouse_position() + _ai_panel_drag_offset
		var vp := get_viewport().get_visible_rect().size
		target.x = clampf(target.x, 0.0, maxf(0.0, vp.x - ai_panel.size.x))
		target.y = clampf(target.y, 0.0, maxf(0.0, vp.y - ai_panel.size.y))
		ai_panel.position = target


func _on_ai_close() -> void:
	_ai_panel_dragging = false
	_show_ai_panel = false
	_refresh_ai_panel()


func _refresh_ai_panel() -> void:
	for child in ai_list.get_children():
		child.queue_free()
	if not _show_ai_panel or not _supports_ai_editor():
		ai_panel.visible = false
		return
	var model_key := _current_model_key()
	for def in AIConfigLib.behavior_definitions(model_key):
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(1, 1, 1, 0.03)
		panel_style.border_color = Color(1, 1, 1, 0.08)
		panel_style.set_border_width_all(1)
		panel_style.set_corner_radius_all(4)
		panel_style.content_margin_left = 10
		panel_style.content_margin_top = 8
		panel_style.content_margin_right = 10
		panel_style.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel", panel_style)
		ai_list.add_child(panel)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 6)
		panel.add_child(content)
		var toggle := CheckButton.new()
		toggle.text = str(def.get("label", ""))
		toggle.button_pressed = AIConfigLib.behavior_enabled(model_key, str(def.get("key", "")))
		toggle.tooltip_text = Locale.tr_key(str(def.get("description", "")))
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.toggled.connect(_on_ai_behavior_toggled.bind(model_key, str(def.get("key", ""))))
		content.add_child(toggle)
		var desc := Label.new()
		desc.text = str(def.get("description", ""))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.tooltip_text = Locale.tr_key(str(def.get("description", "")))
		desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
		desc.add_theme_font_size_override("font_size", 14)
		content.add_child(desc)
	ai_panel.visible = true


func _on_ai_behavior_toggled(pressed: bool, model_key: String, behavior_key: String) -> void:
	AIConfigLib.set_behavior(model_key, behavior_key, pressed)


# The special-effect nodes already live in the preview (collected on build), so toggling
# just flips their visibility — no rebuild needed (cheaper, no flicker).
func _on_effects_toggled(pressed: bool) -> void:
	_show_effects = pressed
	_save_toggle("show_effects", pressed)
	_apply_effects_visibility()


# Persist one preview toggle so the model browser reopens with the same options.
func _save_toggle(key: String, value: bool) -> void:
	Settings.config_file.set_value("models", key, value)
	Settings.save_settings()


# --- Selection persistence + restore ----------------------------------------

# Persist one dropdown selection so the browser reopens on the same chain. Stored by a
# STABLE value (category key / prefix token / model name / clip / effect label, or the
# WHOLE_MODEL_VALUE sentinel for "Modelo completo") rather than by index, so it survives
# the library being re-scanned in a different order. "" means the placeholder.
func _save_selection(key: String, value: String) -> void:
	Settings.config_file.set_value("models", key, value)
	Settings.save_settings()


# Stable value for a Categoria index: the category key (index 0 / out of range -> "").
func _category_value(index: int) -> String:
	var i := index - 1
	return String(_categories[i]["key"]) if i >= 0 and i < _categories.size() else ""


# Stable value for a Parte index: "" (placeholder), the WHOLE_MODEL_VALUE sentinel
# ("Modelo completo", index 1) or the mesh label (indices 2..).
func _part_value(index: int) -> String:
	if index <= 0:
		return ""
	if index == 1:
		return WHOLE_MODEL_VALUE
	return cbo_meshes.get_item_text(index)


# Replay the persisted Categoria -> Prefixo -> Modelo -> Parte chain (and, for "Modelo
# completo", the parallel Animação/Efeitos leaves) so the browser reopens exactly where
# the user left it. select() does not emit item_selected, so each step also calls its
# handler explicitly — populating the next dropdown just like a real click would.
#
# Per saved value at each level:
#   * empty -> the user simply stopped here: leave this dropdown enabled on its
#     placeholder, ready to continue. With everything empty this reproduces the blank
#     first-run start (every combo "Selecione...", nothing previewed).
#   * stale -> the saved choice no longer exists in the library, so there is "no more
#     data" for it: DISABLE this dropdown, and since its handler never runs the rest of
#     the chain below stays disabled too.
func _restore_selection_chain() -> void:
	var cfg := Settings.config_file
	var v_cat: String = cfg.get_value("models", "sel_category", "")
	var v_pre: String = cfg.get_value("models", "sel_prefix", "")
	var v_mod: String = cfg.get_value("models", "sel_model", "")
	var v_part: String = cfg.get_value("models", "sel_part", "")
	var v_anim: String = cfg.get_value("models", "sel_animation", "")
	var v_eff: String = cfg.get_value("models", "sel_effect", "")
	# sel_member/sel_submember/sel_skeleton NÃO são lidos aqui: cada _populate_* os carrega ao exibir.

	# Categoria — the root dropdown is always enabled. A missing/stale value falls back to
	# the placeholder, which resets and disables the whole chain below it.
	var ci := _find_category_index(v_cat)
	if ci <= 0:
		cbo_category.select(0)
		_on_category_selected(0)
		return
	cbo_category.select(ci)
	_on_category_selected(ci)

	# Prefixo
	if v_pre == "":
		return
	var pi := _find_prefix_index(v_pre)
	if pi <= 0:
		cbo_prefix.disabled = true
		return
	cbo_prefix.select(pi)
	_on_prefix_selected(pi)

	# Modelo
	if v_mod == "":
		return
	var mi := _find_model_index(v_mod)
	if mi <= 0:
		cbo_models.disabled = true
		return
	cbo_models.select(mi)
	_on_model_selected(mi)

	# Parte
	if v_part == "":
		return
	var qi := _find_part_index(v_part)
	if qi <= 0:
		cbo_meshes.disabled = true
		return
	cbo_meshes.select(qi)
	_on_mesh_selected(qi)
	# A single isolated mesh exposes no Animação/Efeitos combos below it.
	if qi != 1:
		return

	# Animação and Efeitos are parallel leaves of "Modelo completo": restore each on its own.
	# A stale saved value disables that one combo; an empty one leaves it enabled on its
	# placeholder (nothing further down depends on either).
	var ai := _find_combo_text_index(cbo_animations, v_anim)
	if ai > 0:
		cbo_animations.select(ai)
		_on_animation_selected(ai)
	elif v_anim != "":
		cbo_animations.disabled = true
	var ei := _effect_index_for_value(v_eff)
	if ei > 0:
		cbo_effects.select(ei)
		_on_effect_selected(ei)
	elif v_eff != "":
		cbo_effects.disabled = true

	# Membro/Sub-membro/Esqueleto NÃO precisam de restauração explícita aqui: _on_mesh_selected(1) já
	# rodou _populate_members, e cada populate (membro/sub/esqueleto) CARREGA o valor persistido
	# (sel_member/sel_submember/sel_skeleton), default "Selecione...". Ver _populate_members et al.


# Index of the Categoria item with the given category key, or -1 if none/empty.
func _find_category_index(value: String) -> int:
	if value == "":
		return -1
	for i in range(_categories.size()):
		if String(_categories[i]["key"]) == value:
			return i + 1
	return -1


# Index of the Prefixo item whose metadata equals the saved prefix token, or -1.
func _find_prefix_index(value: String) -> int:
	if value == "":
		return -1
	for i in range(1, cbo_prefix.item_count):
		if String(cbo_prefix.get_item_metadata(i)) == value:
			return i
	return -1


# Index of the Modelo item with the given (displayed) model name, or -1.
func _find_model_index(value: String) -> int:
	if value == "":
		return -1
	for i in range(1, cbo_models.item_count):
		if cbo_models.get_item_text(i) == value:
			return i
	return -1


# Index of the Parte item for a saved part value: WHOLE_MODEL_VALUE -> the "Modelo
# completo" entry at index 1; otherwise the mesh whose label matches. -1 if none/empty.
func _find_part_index(value: String) -> int:
	if value == "":
		return -1
	if value == WHOLE_MODEL_VALUE:
		return 1 if cbo_meshes.item_count > 1 else -1
	for i in range(2, cbo_meshes.item_count):
		if cbo_meshes.get_item_text(i) == value:
			return i
	return -1


# Index of the first real (index >= 1) item of `combo` whose text equals `value`, or -1.
func _find_combo_text_index(combo: OptionButton, value: String) -> int:
	if value == "":
		return -1
	for i in range(1, combo.item_count):
		if combo.get_item_text(i) == value:
			return i
	return -1


# --- Library scanning -------------------------------------------------------

# For each category in CATEGORIES, scan LIBRARY_ROOT/<categoria>/<modelo>/ and
# collect one entry per model folder. Categories with no models are dropped.
func _scan_library() -> Array:
	var result: Array = []
	for category in CATEGORIES:
		var type_path := LIBRARY_ROOT.path_join(category["key"])
		var type_access := DirAccess.open(type_path)
		if type_access == null:
			continue

		var models: Array = []
		for model_dir in type_access.get_directories():
			var model_path := type_path.path_join(model_dir)
			var file_path := _find_model_file(model_path)
			if file_path != "":
				models.append({
					"name": _prettify(model_dir),
					"path": file_path,
					"display_path": _find_display_file(model_path),
					"prefix": _prefix_of(model_dir),
				})

		if not models.is_empty():
			models.sort_custom(func(a, b): return a["name"] < b["name"])
			result.append({
				"key": category["key"],
				"label": category["label"],
				"models": models,
			})

	return result


# Em builds EXPORTADOS, os arquivos-fonte não vão crus no PCK: o modelo importado vira
# "<nome>.glb.import" e as cenas viram "<nome>.tscn.remap" (ambos apontam para o recurso importado).
# No EDITOR os arquivos crus existem (com um ".import" ao lado). Normaliza tirando o sufixo
# ".import"/".remap" → devolve o caminho lógico ("red_robot.glb.import" → "red_robot.glb",
# "red_robot.tscn.remap" → "red_robot.tscn"), que load() resolve nos dois contextos. Sem isso o
# scanner não acha modelo nenhum no .exe e o menu Categoria fica vazio.
func _logical_name(file_name: String) -> String:
	var ext := file_name.get_extension().to_lower()
	if ext == "remap" or ext == "import":
		return file_name.get_basename()
	return file_name


# Pick the previewable resource in a model folder: the raw imported model
# (.glb / .gltf) if present — so we show the mesh without running any gameplay
# script — otherwise an assembled scene (.tscn). Only files directly in the
# folder are considered (subfolders like audio/ or bullet/ are ignored).
# A folder may hold more than one scene (e.g. criatura_alada/ also ships
# bomb.tscn, the projectile it drops); the file whose basename matches the
# folder name is the model itself, so it wins over any sibling scene.
func _find_model_file(folder: String) -> String:
	var access := DirAccess.open(folder)
	if access == null:
		return ""
	var model_name := folder.get_file()
	var mesh_path: String = ""
	var mesh_named: String = ""
	var scene_path: String = ""
	var scene_named: String = ""
	for raw_name in access.get_files():
		var file_name := _logical_name(raw_name)
		var is_named := file_name.get_basename() == model_name
		match file_name.get_extension().to_lower():
			"glb", "gltf":
				if mesh_path == "":
					mesh_path = folder.path_join(file_name)
				if is_named and mesh_named == "":
					mesh_named = folder.path_join(file_name)
			"tscn":
				if scene_path == "":
					scene_path = folder.path_join(file_name)
				if is_named and scene_named == "":
					scene_named = folder.path_join(file_name)
	if mesh_named != "":
		return mesh_named
	if mesh_path != "":
		return mesh_path
	if scene_named != "":
		return scene_named
	return scene_path


# Pick the resource for the assembled "Modelo completo" view: the authored scene
# (.tscn) when present — it carries the materials, effects and the intended
# visible setup the raw mesh lacks — falling back to whatever _find_model_file
# resolves (the .glb) when there is no scene.
func _find_display_file(folder: String) -> String:
	var access := DirAccess.open(folder)
	if access == null:
		return ""
	var model_name := folder.get_file()
	var scene_path: String = ""
	for raw_name in access.get_files():
		var file_name := _logical_name(raw_name)
		if file_name.get_extension().to_lower() == "tscn":
			# The scene named after the folder is the model; a sibling scene
			# (e.g. bomb.tscn next to criatura_alada.tscn) must not shadow it.
			if file_name.get_basename() == model_name:
				return folder.path_join(file_name)
			if scene_path == "":
				scene_path = folder.path_join(file_name)
	if scene_path != "":
		return scene_path
	return _find_model_file(folder)


# --- Mesh catalog (de-duplicated reusable assets) ---------------------------

# Walk every MeshInstance3D in the model and group them by their shared Mesh
# resource, so each distinct mesh shows up once. Entries are sorted by how many
# times the mesh is placed (most-used first), which surfaces the "main" pieces.
func _build_mesh_catalog(scene: PackedScene) -> Array:
	var result: Array = []
	if scene == null:
		return result

	var instance := scene.instantiate()
	var nodes: Array = instance.find_children("*", "MeshInstance3D", true, false)
	if instance is MeshInstance3D:
		nodes.append(instance)

	var by_mesh: Dictionary = {}
	var entries: Array = []
	for node in nodes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var id := mesh_instance.mesh.get_instance_id()
		if not by_mesh.has(id):
			var has_collision := not mesh_instance.find_children(
				"*", "CollisionShape3D", true, false
			).is_empty()
			# Capture the instance's materials so a single-part preview keeps its
			# look. Some models (criatura_alada) paint their meshes via
			# material_override / per-surface overrides on the INSTANCE rather than
			# baking them into the Mesh surfaces — without this the isolated part
			# would render untextured.
			var surface_overrides: Array = []
			for s in mesh_instance.mesh.get_surface_count():
				surface_overrides.append(mesh_instance.get_surface_override_material(s))
			by_mesh[id] = entries.size()
			entries.append({
				"mesh": mesh_instance.mesh,
				"name": _group_key(mesh_instance.name),
				"count": 0,
				"has_collision": has_collision,
				"skinned": mesh_instance.skin != null,
				"material_override": mesh_instance.material_override,
				"surface_overrides": surface_overrides,
			})
		entries[by_mesh[id]]["count"] += 1
	instance.free()

	entries.sort_custom(func(a, b):
		if a["count"] != b["count"]:
			return a["count"] > b["count"]
		return a["name"] < b["name"])

	for entry in entries:
		var label: String = _prettify(entry["name"])
		if entry["count"] > 1:
			label += " (×%d)" % entry["count"]
		if entry["skinned"]:
			label += " [skin]"
		elif entry["has_collision"]:
			label += " [+col]"
		entry["label"] = label
		result.append(entry)
	return result


# Grouping prefix of a model folder: the first underscore-separated token.
# "core_out_light" -> "core", "red_robot" -> "red", "forklift" -> "forklift".
func _prefix_of(folder_name: String) -> String:
	var parts := folder_name.split("_", false)
	return parts[0] if not parts.is_empty() else folder_name


# "prop_cargobox5b_022" -> "prop_cargobox5b", "Spot_010" -> "Spot".
# Strips trailing _<number> groups without eating mid-name digits.
func _group_key(node_name: String) -> String:
	var regex := RegEx.new()
	regex.compile("_[0-9]+$")
	var result := node_name
	while true:
		var match_result := regex.search(result)
		if match_result == null:
			break
		var stripped := result.substr(0, match_result.get_start())
		if stripped == "":
			break
		result = stripped
	return result


# --- Preview ----------------------------------------------------------------

func _clear_preview() -> void:
	for child in model_holder.get_children():
		child.queue_free()
	_preview_instance = null
	_preview_anim_players = []
	_main_anim_player = null
	_main_body_root = null
	_preview_audio_players = []
	_preview_audio_volumes = {}
	_member_colliders_built = false
	_preview_effect_nodes = []
	_member_label_pivots = []
	_clear_damage_fields()
	# Sem preview não há corpo focado: fecha a janela de Afastamento/Escala e zera o "dispensado" (o
	# próximo modelo recarrega os valores do zero, sem herdar um grupo de mesmo nome de outro modelo).
	_close_collider_dialog()
	_dialog_dismissed_group = ""
	_yaw = 0.0
	_pitch = 0.0
	model_holder.rotation = Vector3.ZERO
	# Rede de segurança do editor de dano: qualquer teardown de preview (trocar/desmarcar
	# modelo, ir para mesh isolada) oculta o painel; o build do "Modelo completo" o reexibe.
	if _show_damage_panel and is_instance_valid(damage_panel):
		_refresh_damage_panel()


# Show a single instance of the selected distinct mesh, centered and fit to view.
func _preview_mesh(index: int) -> void:
	_clear_preview()
	if index < 0 or index >= _mesh_catalog.size():
		return
	var mesh_instance := MeshInstance3D.new()
	var entry: Dictionary = _mesh_catalog[index]
	mesh_instance.mesh = entry["mesh"]
	# Re-apply the materials captured from the source instance so painted-by-
	# override models (e.g. criatura_alada) keep their texture in the part view.
	mesh_instance.material_override = entry.get("material_override", null)
	var surface_overrides: Array = entry.get("surface_overrides", [])
	for s in surface_overrides.size():
		mesh_instance.set_surface_override_material(s, surface_overrides[s])
	model_holder.add_child(mesh_instance)
	_preview_instance = mesh_instance
	_fit_to_view(mesh_instance)


# Show the whole model with every object in place (the default view when a model
# is picked), centered and fit to view. Uses the assembled scene (_display_scene)
# so materials and effects show, and strips its scripts first so gameplay logic
# never runs — the preview stays static and the scene's saved visibility decides
# what shows (e.g. the forklift's one clean colour variant, not a random pick).
func _preview_whole_model() -> void:
	_clear_preview()
	if _display_scene == null:
		return
	var instance := _display_scene.instantiate()
	# Level the model: disregard any baked angular tilt the .glb root carries so it
	# previews upright. The user's drag then rotates it on orthogonal axes only.
	if instance is Node3D:
		(instance as Node3D).rotation = Vector3.ZERO
	_strip_scripts(instance)
	# Catalog the special-effect nodes (particles, lights, bone-mounted laser/muzzle
	# meshes). Their visibility is decided by the "Efeitos especiais" toggle + dropdown
	# via _apply_effects_visibility (called from _populate_effects after this returns);
	# _fit_to_view ignores them, so framing is unaffected either way.
	_preview_effect_nodes = _collect_effect_nodes(instance)
	# Capture autoplay/volumes and DISABLE any AnimationTree BEFORE the subtree
	# enters the tree, so nothing autostarts and the tree never fights the clip we
	# drive directly (that double-drive is what made red_robot look like two
	# overlapping models). Playback is then started below per the active toggles.
	_capture_av(instance)
	# (O overlay global não faz mais rótulos 3D — a inspeção 3D vive só aqui na Models —
	# então não há mais necessidade de isentar o subtree do esqueleto.)
	model_holder.add_child(instance)
	_preview_instance = instance
	_apply_animation_state()
	_apply_audio_state()
	# Detect members for characters and weapons either way: their colliders feed the
	# always-on member tooltips; for other categories we only build them to draw the
	# collider gizmos when the toggle is on.
	var show_members := _current_category_key() in ["characters", "weapons"]
	_member_colliders_built = false
	if _show_colliders or _any_member_label() or show_members:
		# Build the per-member colliders (best-fit sphere/box/capsule) — the preview
		# strips the gameplay script that normally builds them, so we do it here.
		_add_member_colliders(instance)
		_member_colliders_built = true
	if instance is Node3D:
		# Frame from the POSED body (the member colliders) when we have them: a
		# skinned mesh's get_aabb() is the bind pose, which for red_robot sits ~1.4 m
		# off the idle pose in Z — using it would anchor the pivot behind the body so
		# it swings away when rotated. The collider bounds track the real pose.
		var posed := _posed_member_bounds(instance) if _member_colliders_built else AABB()
		if posed.size != Vector3.ZERO:
			_fit_to_view(instance as Node3D, 2.0, posed)
		else:
			_fit_to_view(instance as Node3D)
	if _show_colliders:
		_add_collider_gizmos(instance)
	# Rótulos de membro (TYPE/Name/ID/Membro): cada linha segue seu PRÓPRIO toggle da cena
	# Models (Rótulos/Tipo/Nome/ID), totalmente desacoplado do Debug 3D global.
	if _member_colliders_built and _any_member_label():
		_add_member_labels(instance)
	# Editor de dano por membro: repopula se o painel estiver aberto (só personagem completo).
	if _show_damage_panel:
		_refresh_damage_panel()


# Capture the preview's animation/audio state into fields and neutralise anything
# that would start on its own, BEFORE the subtree enters the tree (autoplay fires on
# tree entry). Clears every AnimationPlayer's autoplay and records each emitter's
# authored volume so the in-place appliers can later (re)start or mute/un-mute them
# without rebuilding. Also disables every AnimationTree so it never poses the
# skeleton in parallel with the clip we drive directly.
func _capture_av(instance: Node) -> void:
	_preview_anim_players = []
	_main_anim_player = null
	for node in instance.find_children("*", "AnimationPlayer", true, false):
		var ap := node as AnimationPlayer
		# Clear authored autoplay so no clip starts on tree entry — playback is driven
		# explicitly by the Animação toggle + combo via _apply_animation_state.
		ap.autoplay = ""
		_preview_anim_players.append(ap)
	for node in instance.find_children("*", "AnimationTree", true, false):
		var tree := node as AnimationTree
		# The clips carry their root motion on a bone (e.g. Skeleton3D:MASTER) that the
		# tree extracted (and the gameplay script applied to the body). Driving a clip
		# straight from the AnimationPlayer would instead APPLY that bone, translating the
		# whole skeleton — which made red_robot drift ~1.6 m and look like a second model
		# behind the first. Copy the tree's root_motion_track onto the player it drives so
		# the clip plays IN PLACE (the root motion is extracted, and we simply discard it).
		var ap := tree.get_node_or_null(tree.anim_player) as AnimationPlayer
		if ap != null:
			if not tree.root_motion_track.is_empty():
				ap.root_motion_track = tree.root_motion_track
			_main_anim_player = ap
		tree.active = false
	# With no AnimationTree, treat the richest player as the main one (the others are
	# usually one-shot effect/death clips that must not auto-play over the model).
	if _main_anim_player == null:
		for ap: AnimationPlayer in _preview_anim_players:
			if _main_anim_player == null or ap.get_animation_list().size() > _main_anim_player.get_animation_list().size():
				_main_anim_player = ap
	# The body subtree is the main player's model root (e.g. RedRobotModel), a sibling of
	# the debris/death node — so hiding it doesn't hide the explosion.
	_main_body_root = _main_anim_player.get_parent() as Node3D if _main_anim_player != null else null

	_preview_audio_players = []
	_preview_audio_volumes = {}
	for cls in ["AudioStreamPlayer", "AudioStreamPlayer3D", "AudioStreamPlayer2D"]:
		for node in instance.find_children("*", cls, true, false):
			_preview_audio_players.append(node)
			_preview_audio_volumes[node] = node.get("volume_db")
			node.set("autoplay", false)


# Apply the Animação toggle to the live preview: with it off, stop every player;
# with it on, play the "Animação" dropdown's clip (falling back to the model's
# autoplay clip, then its first clip) on each player that has it. Re-applies the
# audio state afterwards so animation-driven sound respects the Audio/Falas toggles.
func _apply_animation_state() -> void:
	var chosen := "" if cbo_animations.selected <= 0 else cbo_animations.get_item_text(cbo_animations.selected)
	# An animation plays ONLY when BOTH the Animação toggle is on AND a clip is explicitly
	# chosen in the combo. With the toggle off, or while the combo still sits on
	# "Selecione...", nothing plays — there is no default/idle auto-play.
	var should_play := _play_animation and chosen != ""
	# A death/explosion clip reveals the model's debris; hide the live body so the preview
	# shows ONLY the explosion (otherwise the intact body and the debris overlap).
	if is_instance_valid(_main_body_root):
		_main_body_root.visible = not (should_play and _is_death_clip(chosen))
	for ap: AnimationPlayer in _preview_anim_players:
		if not is_instance_valid(ap):
			continue
		# Play the chosen clip on whichever player owns it; stop every other player (and all
		# of them when nothing should play).
		if should_play and ap.has_animation(chosen):
			# Loop: ao terminar, _on_preview_anim_finished retoca o clipe (sem mexer no loop_mode
			# do recurso, que é compartilhado com o jogo).
			if not ap.animation_finished.is_connected(_on_preview_anim_finished):
				ap.animation_finished.connect(_on_preview_anim_finished)
			ap.play(chosen)
		else:
			ap.stop()
	# Sem clip tocando (dropdown "Selecione..." ou toggle off): volta o(s) esqueleto(s) à pose
	# de descanso = ESTADO INICIAL do modelo. `stop()` apenas CONGELA a pose corrente do clipe
	# anterior, então reposicionamos cada osso na sua transform de REST (os modelos não têm
	# animação "RESET" para tocar).
	if not should_play and _preview_instance != null:
		for skel_node in _preview_instance.find_children("*", "Skeleton3D", true, false):
			var skel := skel_node as Skeleton3D
			for i in skel.get_bone_count():
				var rest := skel.get_bone_rest(i)
				skel.set_bone_pose_position(i, rest.origin)
				skel.set_bone_pose_rotation(i, rest.basis.get_rotation_quaternion())
				skel.set_bone_pose_scale(i, rest.basis.get_scale())
	_apply_audio_state()


# Loop do preview: ao terminar um clipe não-looping, retoca o MESMO (se ainda for o selecionado e
# a Animação seguir ligada). Por SINAL — não altera o `loop_mode` do recurso (compartilhado com o
# jogo). Clipes de morte/explosão NÃO dão loop (revelam destroços uma vez).
func _on_preview_anim_finished(anim_name: StringName) -> void:
	if not _play_animation:
		return
	var chosen := "" if cbo_animations.selected <= 0 else cbo_animations.get_item_text(cbo_animations.selected)
	if chosen == "" or String(anim_name) != chosen or _is_death_clip(chosen):
		return
	for ap: AnimationPlayer in _preview_anim_players:
		if is_instance_valid(ap) and ap.has_animation(chosen):
			ap.play(chosen)


# A death/explosion clip (by common naming) that reveals the model's debris instead of
# animating the body — the live body is hidden while one of these plays.
func _is_death_clip(clip: String) -> bool:
	var c := clip.to_lower()
	return c.contains("kaboom") or c.contains("explo") or c.contains("death") or c.contains("die") or c.contains("destr")


# Apply the Audio toggle to the live preview's emitters in place: each emitter is muted
# (volume_db -80) when the toggle is off and restored to its authored volume when on;
# standalone emitters are (re)started when on, the rest stopped. Muting the volume is what
# also gates sound triggered from animation tracks. Covers every emitter — movement, motor,
# shots, explosions and voices alike (there is no separate speech toggle anymore).
func _apply_audio_state() -> void:
	for node in _preview_audio_players:
		if not is_instance_valid(node):
			continue
		var wanted := _play_audio
		var authored: float = _preview_audio_volumes.get(node, 0.0)
		node.set("volume_db", authored if wanted else -80.0)
		if node.get("stream") == null:
			continue
		if wanted:
			if not node.get("playing"):
				node.play()
		else:
			node.stop()


# Recursively detach every script in the instanced subtree before it enters the
# tree, so no _ready / gameplay code runs during the static preview.
func _strip_scripts(node: Node) -> void:
	node.set_script(null)
	for child in node.get_children():
		_strip_scripts(child)


# Effect node classes surfaced by the "Efeitos Especiais" dropdown — every kind of
# special effect a model may carry: lights (luminosity/shadows — Light3D covers Omni/
# Spot/Directional), particle systems (smoke, sparks, thrust — GPU/CPU), and the other
# visual-effect volumes (decals, fog, particle attractors/colliders). is_class() matches
# subclasses too, so listing the base class is enough.
const _EFFECT_CLASSES: Array[String] = [
	"GPUParticles3D", "CPUParticles3D", "Light3D",
	"Decal", "FogVolume", "GPUParticlesAttractor3D", "GPUParticlesCollision3D",
]


# Collect the model's gameplay-only flourishes — particles (smoke/thrust), lights
# (luminosity/shadows), decals/fog/other effect volumes, and meshes pinned to a bone
# (muzzle/laser) — the "remaining" elements no other toggle covers. Returned as
# [{"label", "node"}] for the "Efeitos Especiais" dropdown; the caller decides their
# visibility via _apply_effects_visibility.
func _collect_effect_nodes(instance: Node) -> Array:
	var out: Array = []
	for node in instance.find_children("*", "Node3D", true, false):
		var is_effect := false
		for cls in _EFFECT_CLASSES:
			if node.is_class(cls):
				is_effect = true
				break
		if not is_effect and node is MeshInstance3D and _under_bone_attachment(node, instance):
			is_effect = true
		if is_effect:
			out.append({"label": _prettify(String(node.name)), "node": node})
	return out


# Name carried by every collider wireframe gizmo, so the Colliders toggle can add
# them once and strip them back out in place without touching anything else.
const _GIZMO_NAME := "_ColliderGizmo"

# Prefixo dos nós de tooltip de membro (Tipo/Nome/ID/Membro): o pivô da pilha é
# "_MdlLbl_Pivot" e cada linha "_MdlLbl_<Id>", para os toggles da cena Models acharem e
# recriarem tudo in-place sem tocar no resto.
const _LABEL_PREFIX := "_MdlLbl_"

# Cor distinta por LINHA do tooltip de membro. A MESMA cor é aplicada ao texto do toggle que
# controla a linha (Membro→Rótulos, Tipo→Tipo, Nome→Nome, ID→ID), para o usuário associar de
# relance o controle ao seu rótulo 3D. As chaves casam com o "id" das linhas em _add_member_labels.
const _LABEL_LINE_COLORS := {
	"Member": Color(0.45, 0.85, 1.0),   # azul-ciano (membro)
	"Type": Color(1.0, 0.45, 0.85),     # rosa (tipo)
	"Name": Color(0.55, 1.0, 0.55),     # verde (nome)
	"Id": Color(1.0, 0.92, 0.42),       # amarelo (id)
	"Osso": Color(1.0, 0.6, 0.1),       # laranja (osso avulso — igual ao realce)
}

# Tamanho dos Label3D de membro (compartilhado entre a construção e o anti-colisão por tela,
# que projeta o bloco usando estes números). _LBL_LINE_STEP é o passo em Y entre linhas.
const _LBL_PIXEL_SIZE := 0.003
const _LBL_FONT_SIZE := 14
const _LBL_LINE_STEP := 0.06


# True quando o dropdown está em "Todos os membros" + "Todos os Sub-membros" E o toggle "Colisores de
# Submembros" está ligado: nesse caso TODOS os gizmos de sub-membro (PART_*) aparecem de uma vez, sem
# isolar a malha e independentemente do toggle "Colisores de Membro". A opção "Todos os Sub-membros" só
# existe no dropdown "Sub-membro" quando "Membro" está em "Todos os membros" (cbo_members índice 1).
func _should_show_all_sub_colliders() -> bool:
	return _show_sub_colliders \
		and member_row.visible \
		and cbo_members.selected == 1 \
		and _sub_member_value(cbo_sub_members.selected) == ALL_SUB_MEMBERS_VALUE


# Apply the "Colisores de Membro" toggle to the live preview in place: build the member colliders
# on first use, then add or remove the wireframe gizmos — no rebuild, so the camera and rotation are
# untouched. SUB-MEMBROS (PART_*) ficam OCULTOS nesta visão geral, com UMA exceção: o modo "Todos os
# Sub-membros" + "Colisores de Submembros" ligado (_should_show_all_sub_colliders) mostra TODOS os
# gizmos de sub-membro de uma vez, independente do toggle "Colisores de Membro". Fora disso, o
# sub-membro só aparece isolado (ramo de foco em _refresh_member_overlays) quando escolhido no dropdown.
func _apply_colliders_visibility() -> void:
	if _preview_instance == null:
		return
	var show_all_sub: bool = _should_show_all_sub_colliders()
	# Membros (não-PART_) só aparecem TODOS quando "Membro" está em **"Todos os membros"** (índice 1) —
	# não mais só ao ligar o toggle em "Modelo completo"/Selecione (2026-06-25). Em "Selecione..." = nenhum.
	var show_all_members: bool = _show_colliders and member_row.visible and cbo_members.selected == 1
	# Nada para mostrar (nem todos os membros, nem "todos os sub-membros") → limpa os gizmos e sai.
	if not show_all_members and not show_all_sub:
		for gizmo in _preview_instance.find_children(_GIZMO_NAME, "MeshInstance3D", true, false):
			gizmo.queue_free()
		return
	_ensure_member_colliders()
	_add_collider_gizmos(_preview_instance)
	# Reaplica a visibilidade EXPLICITAMENTE (não confia no default), para gizmos escondidos por um foco
	# anterior voltarem ao estado certo ao sair do isolamento: MEMBRO segue show_all_members ("Todos os
	# membros"); SUB-MEMBRO (PART_*) fica oculto, EXCETO no modo "Todos os Sub-membros" (show_all_sub).
	for body in _member_bodies():
		var is_part: bool = str((body as StaticBody3D).get_meta("group")).begins_with("PART_")
		var vis: bool = show_all_sub if is_part else show_all_members
		for giz in body.find_children(_GIZMO_NAME, "MeshInstance3D", true, false):
			(giz as MeshInstance3D).visible = vis


# Build the per-member colliders once for the current preview (idempotent), so the
# Colliders toggle can draw gizmos for categories whose colliders were not built at
# preview time (characters/weapons already build them for the member tooltips).
func _ensure_member_colliders() -> void:
	if _member_colliders_built or _preview_instance == null:
		return
	_add_member_colliders(_preview_instance)
	_member_colliders_built = true


# Aplica os toggles de rótulo (Rótulos/Tipo/Nome/ID) no preview ao vivo, in-place: remove a
# pilha de labels atual e a recria com a visibilidade certa por linha. Sem rebuild do modelo
# → câmera/rotação intactas. Nada é lido do Debug 3D global.
func _apply_member_labels_visibility() -> void:
	if _preview_instance == null:
		return
	# Remove as pilhas atuais (cada pivô leva junto suas linhas) e zera o índice do anti-colisão.
	for pivot in _preview_instance.find_children(_LABEL_PREFIX + "Pivot", "Node3D", true, false):
		(pivot as Node3D).free()
	_member_label_pivots = []
	if not _any_member_label():
		return
	_ensure_member_colliders()
	_add_member_labels(_preview_instance)


# --- Editor de dano por membro ----------------------------------------------

# Chave do modelo atual = nome da pasta que contém o .tscn (ex.: "red_robot", "player").
# É a MESMA chave que o gameplay define em LimbColliders.model_key, então o que o editor
# grava em LimbConfig é exatamente o que player.gd/red_robot.gd leem em partida.
func _current_model_key() -> String:
	if _current_model_path == "":
		return ""
	return _current_model_path.get_base_dir().get_file()


# Plano corporal do modelo atual (espelha o @export body_type do gameplay, que o preview
# não enxerga porque os scripts são removidos). Default bípede.
func _body_type_for_current() -> String:
	return _MODEL_BODY_TYPE.get(_current_model_key(), "biped")


# Instância do classificador do modelo atual (para dano default e labels).
func _current_classifier() -> BodyParts:
	return BodyPlans.for_type(_body_type_for_current())


# True quando o preview é um PERSONAGEM em "Modelo completo" — a única situação em que o
# editor de dano por membro faz sentido (precisa do dono e dos membros completos).
# O editor de Dano vale para QUALQUER modelo em "Modelo completo" (não só personagens): personagens
# usam o plano corporal; armas/rigs usam os colliders de membro (WeaponParts/BodyParts via
# _add_mesh_member_colliders). Em mesh ISOLADA não há "modelo" para editar membros, então gateia só
# em "Modelo completo" + preview existente.
func _supports_damage_editor() -> bool:
	return _preview_instance != null \
		and _part_value(cbo_meshes.selected) == WHOLE_MODEL_VALUE


# (Re)constrói o editor de dano como uma ÁRVORE (Tree): cada MEMBRO é um galho; seus sub-membros
# (PART_*) são folhas SOB ele (ex.: "↳ PLACA BRAÇO E" sob "BRAÇO E") — a "estrutura de árvore com
# galhos e folhas". Colunas: Nome | Definir(check) | Bônus %(range) | Dono(dropdown, só sub). O
# footer abaixo tem "Adicionar sub-membro" + "Remover". Oculta tudo fora de "personagem em Modelo
# completo". Idempotente — limpa árvore/footer antes. A associação dono→filho é salva em LimbConfig
# e recarregada a cada add/remove (via _rebuild_member_colliders → aqui).
func _refresh_damage_panel() -> void:
	_damage_field_anchors = []
	damage_tree.clear()
	for c in damage_footer.get_children():
		c.queue_free()
	if not _show_damage_panel or not _supports_damage_editor():
		damage_panel.visible = false
		return
	_ensure_member_colliders()
	var model_key := _current_model_key()
	damage_tree.set_column_title(0, Locale.tr_key("Membro"))
	damage_tree.set_column_title(1, Locale.tr_key("Def"))
	damage_tree.set_column_title(2, Locale.tr_key("Bônus %"))
	damage_tree.set_column_title(3, Locale.tr_key("Dono"))
	var root := damage_tree.create_item()
	var members := _plan_member_entries()
	var member_groups := {}
	for m in members:
		member_groups[m["group"]] = true
	var subs_by_owner := _sub_members_by_owner()
	for m in members:
		var mi := damage_tree.create_item(root)
		_fill_member_item(mi, model_key, str(m["group"]), str(m["label"]))
		for s in subs_by_owner.get(str(m["group"]), []):
			_fill_sub_member_item(damage_tree.create_item(mi), model_key, str(s["group"]), str(s["bone"]), str(s["label"]))
	# Sub-membros cujo dono não está na lista (owner "" ou grupo ausente): galho "Outros".
	var orphans: Array = []
	for owner_group in subs_by_owner:
		if not member_groups.has(owner_group):
			for s in subs_by_owner[owner_group]:
				orphans.append(s)
	if not orphans.is_empty():
		var oi := damage_tree.create_item(root)
		oi.set_text(0, Locale.tr_key("Outros sub-membros"))
		oi.set_selectable(0, false)
		for s in orphans:
			_fill_sub_member_item(damage_tree.create_item(oi), model_key, str(s["group"]), str(s["bone"]), str(s["label"]))
	_build_damage_footer(model_key)
	damage_panel.visible = true


# Configura o Tree do editor de dano (uma vez, em _ready): colunas, títulos visíveis, raiz oculta,
# e conecta os sinais de edição/seleção das células.
func _setup_damage_tree() -> void:
	damage_tree.columns = 4
	damage_tree.column_titles_visible = true
	damage_tree.hide_root = true
	damage_tree.set_column_expand(0, true)
	damage_tree.set_column_expand(1, false)
	damage_tree.set_column_custom_minimum_width(1, 44)
	damage_tree.set_column_expand(2, false)
	damage_tree.set_column_custom_minimum_width(2, 96)
	damage_tree.set_column_expand(3, false)
	damage_tree.set_column_custom_minimum_width(3, 150)
	damage_tree.item_edited.connect(_on_damage_tree_edited)
	damage_tree.button_clicked.connect(_on_damage_tree_button)
	# Mais espaço por linha: o ícone de lixeira (à direita do nome) era alto demais p/ a altura padrão
	# da linha e encostava na linha vizinha. Padding interno (topo/baixo) e separação vertical maiores
	# dão folga (overrides inexistentes são ignorados sem erro).
	damage_tree.add_theme_constant_override("v_separation", 10)
	damage_tree.add_theme_constant_override("inner_item_margin_top", 4)
	damage_tree.add_theme_constant_override("inner_item_margin_bottom", 4)
	_trash_icon = _make_trash_icon()


# Desenha em código um ícone de LIXEIRA (vermelho = excluir), usado no botão de remover de cada
# folha de sub-membro da árvore. Gerado por código para não depender de asset/import externo.
# Desenho de CONTORNO (paredes/fundo + ranhuras), com FUNDO e INTERIOR transparentes.
func _make_trash_icon() -> ImageTexture:
	var s := 18
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))               # fundo transparente
	var col := Color(0.93, 0.30, 0.24, 1.0)   # vermelho (ação destrutiva)
	img.fill_rect(Rect2i(7, 1, 4, 2), col)    # alça (aba superior)
	img.fill_rect(Rect2i(2, 3, 14, 2), col)   # tampa (barra larga)
	# Corpo só de CONTORNO (paredes + fundo), interior transparente.
	img.fill_rect(Rect2i(4, 6, 2, 9), col)    # parede esquerda
	img.fill_rect(Rect2i(12, 6, 2, 9), col)   # parede direita
	img.fill_rect(Rect2i(4, 14, 10, 2), col)  # fundo
	# Ranhuras verticais (traços), dão a cara de lixeira.
	img.fill_rect(Rect2i(7, 7, 1, 6), col)
	img.fill_rect(Rect2i(10, 7, 1, 6), col)
	return ImageTexture.create_from_image(img)


# Galho de um MEMBRO: nome + células de dano (sem dono — membros não herdam).
func _fill_member_item(item: TreeItem, model_key: String, group: String, label: String) -> void:
	item.set_text(0, label)
	item.set_metadata(0, {"group": group, "bone": "", "owner": ""})
	_fill_damage_cells(item, model_key, group, "")


# Folha de um SUB-MEMBRO: "↳ nome" + células de dano + dropdown de DONO (col 3).
func _fill_sub_member_item(item: TreeItem, model_key: String, group: String, bone: String, label: String) -> void:
	item.set_text(0, "↳ " + label)
	# Botão de lixeira à DIREITA do nome (col 0): remove ESTE sub-membro direto da árvore,
	# sem precisar selecioná-lo + um botão grande no footer (ver _on_damage_tree_button).
	if _trash_icon != null:
		item.add_button(0, _trash_icon, _TRASH_BTN_ID, false, Locale.tr_key("Remover sub-membro"))
	var owner := LimbConfig.sub_member_owner(model_key, bone)
	if owner == "":
		owner = str(_sub_member_owner_map().get(group, ""))
	item.set_metadata(0, {"group": group, "bone": bone, "owner": owner})
	_fill_damage_cells(item, model_key, group, owner)
	# Col 3: DONO como dropdown (range com texto separado por vírgula = menu de opções).
	var choices := _owner_choices()
	var texts := PackedStringArray()
	var sel := 0
	for i in choices.size():
		texts.append(str(choices[i]["label"]))
		if str(choices[i]["group"]) == owner:
			sel = i
	item.set_cell_mode(3, TreeItem.CELL_MODE_RANGE)
	item.set_text(3, ",".join(texts))
	item.set_range_config(3, 0, maxi(choices.size() - 1, 0), 1)
	item.set_range(3, sel)
	item.set_editable(3, true)
	item.set_tooltip_text(3, Locale.tr_key("Membro-dono (agrupa o dano; não mexe na malha)"))


# Células de DANO de um item: col 1 = "Definir" (check), col 2 = bônus % (range -100..500, passo 5,
# editável só com "Definir" ligado; senão mostra o valor EFETIVO herdado). Registra em
# _damage_field_anchors p/ _refresh_tree_inherited atualizar os herdados ao vivo.
func _fill_damage_cells(item: TreeItem, model_key: String, group: String, owner_group: String) -> void:
	var has := LimbConfig.has_multiplier(model_key, group)
	item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
	item.set_checked(1, has)
	item.set_editable(1, true)
	item.set_tooltip_text(1, Locale.tr_key("Definir dano (desmarcado = herda)"))
	item.set_cell_mode(2, TreeItem.CELL_MODE_RANGE)
	item.set_range_config(2, -100.0, 500.0, 5.0)
	item.set_range(2, (LimbConfig.effective_multiplier(model_key, group, _current_classifier(), owner_group) - 1.0) * 100.0)
	item.set_editable(2, has)
	_damage_field_anchors.append({"item": item, "group": group, "owner": owner_group})


# Edição de célula da árvore: Definir (check) liga/desliga o valor próprio; Bônus % (range) grava o
# valor; Dono (range/dropdown) reassocia o sub-membro (com confirmação).
func _on_damage_tree_edited() -> void:
	var item := damage_tree.get_edited()
	if item == null:
		return
	var meta = item.get_metadata(0)
	if not (meta is Dictionary):
		return
	var col := damage_tree.get_edited_column()
	var group := str(meta.get("group", ""))
	var bone := str(meta.get("bone", ""))
	var owner := str(meta.get("owner", ""))
	var model_key := _current_model_key()
	if col == 1:
		var on := item.is_checked(1)
		item.set_editable(2, on)
		if on:
			LimbConfig.set_multiplier(model_key, group, 1.0 + item.get_range(2) / 100.0)
		else:
			LimbConfig.clear_multiplier(model_key, group)
			item.set_range(2, (LimbConfig.effective_multiplier(model_key, group, _current_classifier(), owner) - 1.0) * 100.0)
		_restamp_damage_metas()
		_refresh_tree_inherited()
	elif col == 2:
		if not item.is_checked(1):
			return
		LimbConfig.set_multiplier(model_key, group, 1.0 + item.get_range(2) / 100.0)
		_restamp_damage_metas()
		_refresh_tree_inherited()
	elif col == 3:
		_on_tree_owner_edited(model_key, item, bone, owner)


# Reassocia o DONO de um sub-membro (col 3): pede CONFIRMAÇÃO (só agrupamento lógico, não mexe na
# malha). Confirmado → grava e reconstrói a árvore; cancelado → reverte o dropdown.
func _on_tree_owner_edited(model_key: String, item: TreeItem, bone: String, prev_owner: String) -> void:
	var choices := _owner_choices()
	var idx := int(item.get_range(3))
	if idx < 0 or idx >= choices.size():
		return
	var new_group := str(choices[idx]["group"])
	if new_group == prev_owner:
		return
	var dlg := FloatingDialog.confirm(self, "Reassociar sub-membro", "Mudar o dono de \"%s\" para \"%s\"?\nSó muda o agrupamento/dano (herança) — não altera a malha." % [bone, str(choices[idx]["label"])], "Sim", "Não")
	dlg.confirmed.connect(func():
		LimbConfig.set_sub_member_owner(model_key, bone, new_group)
		_rebuild_member_colliders())
	dlg.canceled.connect(func():
		var prev_idx := 0
		for i in choices.size():
			if str(choices[i]["group"]) == prev_owner:
				prev_idx = i
		item.set_range(3, prev_idx))


# Clique num botão de célula da árvore: o ícone de lixeira (à direita do nome de um sub-membro)
# pede CONFIRMAÇÃO e então remove AQUELE sub-membro. Outros ids/colunas são ignorados.
func _on_damage_tree_button(item: TreeItem, _column: int, id: int, _mouse_button: int) -> void:
	if id != _TRASH_BTN_ID or item == null:
		return
	var meta = item.get_metadata(0)
	if not (meta is Dictionary):
		return
	var bone := str(meta.get("bone", ""))
	if bone == "":
		return
	# Nome exibido do sub-membro (sem o prefixo "↳ " da árvore) para a frase da confirmação.
	var sub_name := item.get_text(0).trim_prefix("↳ ").strip_edges()
	var model_key := _current_model_key()
	var dlg := FloatingDialog.confirm(self, "Remover sub-membro", "Deseja realmente remover associação do sub-membro: %s ?" % sub_name, "Sim", "Não")
	dlg.confirmed.connect(func():
		_on_sub_member_removed(model_key, bone))


# Footer abaixo da árvore: só a linha "Adicionar sub-membro" (osso avulso + dono explícito +
# Adicionar). A REMOÇÃO agora é por linha, via ícone de lixeira ao lado do nome de cada sub-membro
# (ver _fill_sub_member_item / _on_damage_tree_button). Reconstruído a cada _refresh_damage_panel.
func _build_damage_footer(model_key: String) -> void:
	damage_footer.add_child(HSeparator.new())
	var title := Label.new()
	title.text = "Adicionar sub-membro"   # Label: auto-localizado pelo Locale
	damage_footer.add_child(title)
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 8)
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.size_flags_vertical = Control.SIZE_SHRINK_END   # base alinhada ao dropdown do dono (que tem rótulo acima)
	var candidates := _aux_bone_candidates()
	if candidates.is_empty():
		picker.add_item(Locale.tr_key("(sem ossos auxiliares)"))
		picker.disabled = true
	else:
		for b in candidates:
			picker.add_item(b)
	add_row.add_child(picker)
	# Coluna do membro-dono: um rótulo "Para Membro Dono" ACIMA do dropdown (deixa claro o que ele faz).
	var owner_col := VBoxContainer.new()
	owner_col.add_theme_constant_override("separation", 2)
	var owner_label := Label.new()
	owner_label.text = "Para Membro Dono"   # Label: auto-localizado pelo Locale
	owner_col.add_child(owner_label)
	var owner_btn := OptionButton.new()
	owner_btn.tooltip_text = Locale.tr_key("Membro-dono (agrupa o dano; não mexe na malha)")
	for ch in _owner_choices():
		var i := owner_btn.item_count
		owner_btn.add_item(str(ch["label"]))
		owner_btn.set_item_metadata(i, str(ch["group"]))
	owner_btn.disabled = candidates.is_empty()
	owner_col.add_child(owner_btn)
	add_row.add_child(owner_col)
	var add_btn := Button.new()
	add_btn.text = "Adicionar"   # Button: auto-localizado pelo Locale
	add_btn.disabled = candidates.is_empty()
	add_btn.size_flags_vertical = Control.SIZE_SHRINK_END   # base alinhada ao dropdown do dono
	add_btn.pressed.connect(func(): _on_sub_member_added(model_key, picker, owner_btn))
	add_row.add_child(add_btn)
	damage_footer.add_child(add_row)


# Mapa owner_group → [{group, label, bone}] dos sub-membros (PART_*) do preview, agrupados pelo
# mesmo dono dos combos (_sub_member_owner_map). Usado para aninhar no painel Dano.
func _sub_members_by_owner() -> Dictionary:
	var out: Dictionary = {}
	if _preview_instance == null:
		return out
	var owners := _sub_member_owner_map()
	for node in _preview_instance.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if not body.has_meta("group"):
			continue
		var grp := str(body.get_meta("group"))
		if not grp.begins_with("PART_"):
			continue
		var bone := grp.substr(len("PART_"))
		var label := str(body.get_meta("member_label")) if body.has_meta("member_label") else bone
		var owner_group := str(owners.get(grp, ""))
		if not out.has(owner_group):
			out[owner_group] = []
		out[owner_group].append({"group": grp, "label": label, "bone": bone})
	return out


# ── Campos de dano (na janela) ────────────────────────────────────────────────

# Esvazia o registro dos itens da árvore de dano (os TreeItem em si são liberados por
# damage_tree.clear() em _refresh_damage_panel; aqui só zeramos o índice).
func _clear_damage_fields() -> void:
	_damage_field_anchors = []


# Dono efetivo de um grupo p/ herança: membros não têm dono (""); sub-membros (PART_*) usam o
# dono EXPLÍCITO salvo e, na falta, a resolução automática (owners_auto = _sub_member_owner_map).
func _resolve_owner_for(model_key: String, group: String, owners_auto: Dictionary) -> String:
	if not group.begins_with("PART_"):
		return ""
	var owner_group := LimbConfig.sub_member_owner(model_key, group.substr(len("PART_")))
	if owner_group == "":
		owner_group = str(owners_auto.get(group, ""))
	return owner_group


# Atualiza os valores HERDADOS na árvore (itens com "Definir" desligado): quando o valor de um
# dono muda, os sub-membros sem valor próprio reexibem o número efetivo (range col 2), sem rebuild.
func _refresh_tree_inherited() -> void:
	var model_key := _current_model_key()
	var classifier := _current_classifier()
	for e in _damage_field_anchors:
		var item: TreeItem = e["item"]
		if is_instance_valid(item) and not item.is_checked(1):
			item.set_range(2, (LimbConfig.effective_multiplier(model_key, str(e["group"]), classifier, str(e["owner"])) - 1.0) * 100.0)


# Recarimba a meta "damage_multiplier" (lida pelo gameplay/gizmos) de TODOS os colliders do
# preview com o valor EFETIVO (com herança), para o preview vivo bater com o salvo.
func _restamp_damage_metas() -> void:
	if _preview_instance == null:
		return
	var model_key := _current_model_key()
	var classifier := _current_classifier()
	var owners_auto := _sub_member_owner_map()
	for node in _preview_instance.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if not body.has_meta("group"):
			continue
		var group := str(body.get_meta("group"))
		var owner_group := _resolve_owner_for(model_key, group, owners_auto)
		body.set_meta("damage_multiplier", LimbConfig.effective_multiplier(model_key, group, classifier, owner_group))


# ── Painel de agrupamento (dono dos sub-membros) ──────────────────────────────

# Opções de DONO para um sub-membro: os membros do plano + "(Outros / sem dono)" (group "").
func _owner_choices() -> Array:
	var out: Array = []
	var c := _current_classifier()
	for g in c.members():
		out.append({"group": g, "label": c.label_of(g)})
	out.append({"group": "", "label": "(Outros / sem dono)"})
	return out


# Ossos do esqueleto do preview que o classificador descarta (group_of == "") e ainda NÃO
# são sub-membros — candidatos a promoção. Vazio se o preview não tem Skeleton3D.
func _aux_bone_candidates() -> Array[String]:
	var out: Array[String] = []
	if _preview_instance == null:
		return out
	var skels: Array = _preview_instance.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return out
	var skel := skels[0] as Skeleton3D
	var classifier := _current_classifier()
	var existing := LimbConfig.sub_members(_current_model_key())
	for b in skel.get_bone_count():
		var bn := skel.get_bone_name(b)
		if classifier.group_of(bn) == "" and not existing.has(bn):
			out.append(bn)
	return out


# Promove o osso escolhido a sub-membro, com o membro-DONO escolhido no dropdown (item 3:
# o usuário determina explicitamente onde ele entra). Reconstrói os colliders e repopula.
func _on_sub_member_added(model_key: String, picker: OptionButton, owner_btn: OptionButton = null) -> void:
	if picker.disabled or picker.selected < 0:
		return
	# Exclusividade Membro × Submembro: um osso que JÁ é classificado como Membro NÃO pode virar
	# Submembro (e vice-versa). O picker (_aux_bone_candidates) já filtra, mas garantimos aqui.
	var bone := picker.get_item_text(picker.selected)
	var grp := _current_classifier().group_of(bone)
	if grp != "":
		CrashHandler.show_error(
			"\"%s\" já pertence ao membro \"%s\".\nUm elemento não pode ser Membro e Submembro ao mesmo tempo." %
			[bone, _current_classifier().label_of(grp)]
		)
		return
	var owner_group := ""
	if owner_btn != null and owner_btn.selected >= 0:
		owner_group = str(owner_btn.get_item_metadata(owner_btn.selected))
	LimbConfig.add_sub_member(model_key, picker.get_item_text(picker.selected), owner_group)
	_rebuild_member_colliders()


# Remove o sub-membro, reconstrói os colliders do preview e repopula.
func _on_sub_member_removed(model_key: String, bone: String) -> void:
	LimbConfig.remove_sub_member(model_key, bone)
	_rebuild_member_colliders()


# Refaz os colliders de membro do preview (após mudar a lista de sub-membros), repondo
# gizmos/rótulos conforme os toggles, e repopula o painel.
func _rebuild_member_colliders() -> void:
	if _preview_instance == null:
		return
	_clear_member_colliders()
	_ensure_member_colliders()
	if _show_colliders:
		_add_collider_gizmos(_preview_instance)
	if _member_colliders_built and _any_member_label():
		_add_member_labels(_preview_instance)
	_refresh_damage_panel()
	# Repopula o dropdown Sub-membro/"Esqueleto": promover/remover um osso muda tanto a lista de
	# sub-membros de um membro quanto os candidatos avulsos — sem isto o combo só atualizava ao
	# re-selecionar o membro. Preserva a seleção atual (via _sub_member_value).
	_populate_sub_members()
	_refresh_aux_highlight()   # a lista de avulsos muda quando um osso é promovido/removido
	_refresh_aux_labels()
	# Reaplica a visibilidade dos gizmos (esconde sub-membros na visão geral / respeita o foco) e
	# recria o rótulo "Submembro: …" do selecionado — os nós antigos foram liberados com os corpos.
	_refresh_member_overlays()


# Remove os colliders de membro atuais do preview: o nó LimbColliders (caminho com
# esqueleto) e os wrappers que carregam cada corpo — BoneAttachment3D "Hitbox_*" (esqueleto)
# ou o próprio StaticBody3D (caminho sem esqueleto). free() imediato (a lista é um snapshot),
# para o rebuild seguinte não enxergar duplicatas.
func _clear_member_colliders() -> void:
	if _preview_instance == null:
		return
	var to_free: Array[Node] = []
	for lc in _preview_instance.find_children("*", "LimbColliders", true, false):
		to_free.append(lc)
	for body in _preview_instance.find_children("*", "StaticBody3D", true, false):
		if (body as Node).has_meta("member_label"):
			var p := body.get_parent()
			to_free.append(p if p is BoneAttachment3D else body)
	for n in to_free:
		if is_instance_valid(n):
			n.free()
	_member_colliders_built = false


# Draw a wireframe gizmo for every CollisionShape3D so the otherwise-invisible
# collision volumes can be inspected. Each gizmo is parented under its shape so
# it inherits the shape transform and the root's fit-to-view scale. Idempotent: a
# shape that already carries its gizmo is skipped (the toggle may re-run this).
#
# For Personagens/Armas we build per-MEMBER colliders and those are what's interesting to
# inspect; the model's own authored body collider (e.g. red_robot's big body sphere) and
# its detection/death volumes would just be noise wrapping everything, so they are skipped
# — only the per-member colliders get a gizmo. Other categories draw all their shapes.
func _add_collider_gizmos(instance: Node) -> void:
	var members_only := _current_category_key() in ["characters", "weapons"]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.2, 1.0, 0.4, 0.28)
	for node in instance.find_children("*", "CollisionShape3D", true, false):
		var shape_node := node as CollisionShape3D
		if shape_node.shape == null or shape_node.has_node(NodePath(_GIZMO_NAME)):
			continue
		if members_only and not _is_member_collider(shape_node):
			continue
		# Sub-membro SUPRIMIDO (geo "Selecione...") existe só p/ ficar na árvore/dropdown — sem gizmo.
		var owner_body := shape_node.get_parent()
		if owner_body is StaticBody3D and (owner_body as StaticBody3D).has_meta("suppressed"):
			continue
		var gizmo := MeshInstance3D.new()
		gizmo.name = _GIZMO_NAME
		gizmo.mesh = shape_node.shape.get_debug_mesh()
		gizmo.material_override = mat
		shape_node.add_child(gizmo)


# True when a CollisionShape3D belongs to one of the per-member colliders we built (its
# owning StaticBody3D carries the "member_label" meta), as opposed to the model's own
# authored body/detection/death colliders.
func _is_member_collider(shape_node: CollisionShape3D) -> bool:
	var parent := shape_node.get_parent()
	return parent is StaticBody3D and parent.has_meta("member_label")


# Draws the member tooltip STACK (TYPE / Name / ID / Membro) over each member collider, com o
# mesmo conteúdo/cor (ciano) do debug_overlay.gd, mas cada linha gated pelo SEU toggle da cena
# Models (Rótulos/Tipo/Nome/ID) — não há mais leitura do Debug 3D global. O preview é exempt do
# overlay global (exempt_member_labels), então o browser é dono desses tooltips aqui — onde tem
# os overrides por personagem (cabeça/tronco) que o classificador global não tem. Cada label é
# filho do corpo do collider (ancorado ao osso/pivô animado), então acompanha o membro.
func _add_member_labels(instance: Node) -> void:
	# Idempotente: remove pilhas anteriores (cada pivô leva junto suas linhas) e zera o índice
	# do anti-colisão antes de recriar, para chamadas repetidas não acumularem duplicatas.
	for old in instance.find_children(_LABEL_PREFIX + "Pivot", "Node3D", true, false):
		(old as Node3D).free()
	_member_label_pivots = []
	# TYPE/Name/ID describe the owning Skeleton3D (like the global overlay); fall back to the
	# preview root for rigs without a skeleton (criatura).
	var owner_node: Node = instance
	var skels: Array = instance.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		owner_node = skels[0]
	for node in instance.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if not body.has_meta("member_label"):
			continue
		# Sub-membros (PART_*) têm o PRÓPRIO rótulo "Submembro:" (_label_sub_member) — NÃO recebem
		# o stack de "Membro:". Um elemento é Membro OU Submembro, nunca os dois.
		if str(body.get_meta("group")).begins_with("PART_"):
			continue
		var text: String = str(body.get_meta("member_label"))
		if text == "":
			continue
		var shapes: Array = body.find_children("*", "CollisionShape3D", true, false)
		if shapes.is_empty():
			continue
		# Member centre in the body's local space (the shape carries the offset).
		var center: Vector3 = (shapes[0] as CollisionShape3D).position
		# Cada linha: id (p/ recriar in-place + cor), visibilidade pelo toggle local, e offset Y.
		var lines := [
			{"id": "Type", "on": _show_type, "text": "%s %s" % [Locale.tr_key("Tipo:"), owner_node.get_class()], "y": 0.18},
			{"id": "Name", "on": _show_name, "text": "%s %s" % [Locale.tr_key("Nome:"), owner_node.name], "y": 0.12},
			{"id": "Id", "on": _show_id, "text": "%s %d" % [Locale.tr_key("ID:"), owner_node.get_instance_id()], "y": 0.06},
			{"id": "Member", "on": _show_member_labels, "text": "%s %s" % [Locale.tr_key("Membro:"), text], "y": 0.0},
		]
		# Um pivô por membro agrupa as 4 linhas, de modo que o anti-colisão desloque a pilha
		# inteira de uma vez (sem desalinhar as linhas entre si). Posicionado no topo do bloco.
		var base: Vector3 = center + Vector3(0.0, 0.12, 0.0)
		var pivot := Node3D.new()
		pivot.name = _LABEL_PREFIX + "Pivot"
		body.add_child(pivot)
		pivot.position = base
		var visible_count := 0
		var max_y := 0.0
		var max_len := 0
		for line in lines:
			var lbl := Label3D.new()
			lbl.name = _LABEL_PREFIX + str(line["id"])
			lbl.text = str(line["text"])
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.no_depth_test = true
			# Always draw on TOP of the translucent green collider gizmos and of each other,
			# so a member's tag is never swallowed by a neighbouring collider/label.
			lbl.render_priority = 4
			lbl.outline_render_priority = 3
			lbl.pixel_size = _LBL_PIXEL_SIZE
			lbl.font_size = _LBL_FONT_SIZE
			# Cor própria da linha (Membro/Tipo/Nome/ID) — a mesma usada no toggle que a controla.
			lbl.modulate = _LABEL_LINE_COLORS.get(str(line["id"]), Color(0.6, 1.0, 1.0))
			lbl.outline_size = 4
			lbl.outline_modulate = Color(0, 0, 0, 0.8)
			lbl.visible = bool(line["on"])
			pivot.add_child(lbl)
			# Relativo ao pivô: o "Membro" (y=0) fica na base, as demais linhas acima dele.
			lbl.position = Vector3(0.0, float(line["y"]), 0.0)
			if bool(line["on"]):
				visible_count += 1
				max_y = maxf(max_y, float(line["y"]))
				max_len = maxi(max_len, str(line["text"]).length())
		# Sem nenhuma linha visível, nada a posicionar: descarta o pivô e não o indexa.
		if visible_count == 0:
			pivot.free()
			continue
		# Tamanho aproximado do bloco em METROS, para o anti-colisão projetar seu retângulo:
		# altura = topo da pilha + uma linha; meia-largura ≈ metade do texto mais longo (Label3D
		# centraliza no eixo X). Largura por caractere ≈ font*pixel_size*0.5.
		var block_h: float = max_y + _LBL_LINE_STEP
		var half_w: float = max_len * (_LBL_FONT_SIZE * _LBL_PIXEL_SIZE * 0.5) * 0.5
		_member_label_pivots.append({
			"pivot": pivot, "body": body, "base": base, "H": block_h, "halfW": half_w,
		})


# Pinta o texto de cada toggle de linha com a cor do rótulo 3D que ele controla, para o
# usuário ligar de relance o controle ao seu rótulo. Cobre os estados do CheckButton (normal/
# hover/pressed/focus) para a cor não "sumir" ao passar o mouse ou marcar.
func _apply_label_line_colors() -> void:
	var toggles := {
		"Member": labels_toggle, "Type": type_check, "Name": name_check, "Id": id_check,
		"Osso": osso_check,
	}
	for id in toggles:
		var btn: CheckButton = toggles[id]
		var col: Color = _LABEL_LINE_COLORS[id]
		for key in [
			"font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color",
		]:
			btn.add_theme_color_override(key, col)
	# "Submembros": texto roxo (igual ao rótulo 3D _SUB_LBL_COLOR), fundo normal.
	for key in [
		"font_color", "font_hover_color", "font_pressed_color",
		"font_hover_pressed_color", "font_focus_color",
	]:
		sub_member_label_toggle.add_theme_color_override(key, _SUB_LBL_COLOR)


# Anti-colisão das pilhas de rótulos de membro (chamado por frame enquanto houver pilhas). O
# modelo gira, então conjuntos de membros distintos podem se sobrepor na tela a qualquer
# momento; aqui projetamos cada pilha para um retângulo de tela e, processando de cima para
# baixo, empurramos para BAIXO quem colidir com uma pilha já posicionada — mantendo cada
# conjunto inteiro e legível "um abaixo do outro". O empurrão é convertido de pixels de tela
# para metros e aplicado movendo o pivô da pilha no espaço-mundo (para baixo = -câmera_up).
func _layout_member_labels() -> void:
	if camera == null:
		return
	var up_world := camera.global_transform.basis.y
	var right_world := camera.global_transform.basis.x
	# 1) Mede o retângulo de tela de cada pilha SEM empurrão (pivô reposto na base). As medidas
	# saem de posições de MUNDO reais (pivot.to_global), então já embutem o escalonamento do
	# fit-to-view; o fator px/metro vem da câmera na profundidade da âncora (corrige o zoom).
	var rects: Array = []
	for i in _member_label_pivots.size():
		var e: Dictionary = _member_label_pivots[i]
		var pivot: Node3D = e["pivot"]
		var body: Node3D = e["body"]
		if not is_instance_valid(pivot) or not is_instance_valid(body):
			continue
		pivot.position = e["base"]
		# Âncora = base da pilha (linha "Membro"); topo = base + H ao longo do eixo da pilha.
		var anchor: Vector3 = pivot.to_global(Vector3.ZERO)
		if camera.is_position_behind(anchor):
			continue
		var a_px := camera.unproject_position(anchor)
		var top_px := camera.unproject_position(pivot.to_global(Vector3(0.0, float(e["H"]), 0.0)))
		# Pixels por metro de mundo nesta profundidade (1 m na horizontal de tela → px).
		var px_per_m := absf(camera.unproject_position(anchor + right_world).x - a_px.x)
		if px_per_m < 0.001:
			continue
		var scale_x: float = body.global_transform.basis.get_scale().x
		var height_px := absf(a_px.y - top_px.y)
		var halfw_px := maxf(float(e["halfW"]) * scale_x * px_per_m, 16.0)
		# A pilha cresce para CIMA a partir da âncora (linha "Membro" embaixo).
		rects.append({
			"idx": i, "x": a_px.x, "bottom": a_px.y, "top": a_px.y - height_px,
			"halfw": halfw_px, "mpp": 1.0 / px_per_m,
		})
	# 2) De-overlap guloso: de cima para baixo, empurra cada pilha abaixo das já posicionadas.
	rects.sort_custom(func(a, b): return a["top"] < b["top"])
	var placed: Array = []
	for r in rects:
		var push := 0.0
		var changed := true
		while changed:
			changed = false
			for p in placed:
				if absf(r["x"] - p["x"]) >= (r["halfw"] + p["halfw"]):
					continue   # sem sobreposição horizontal
				var r_top: float = r["top"] + push
				var r_bot: float = r["bottom"] + push
				if r_bot <= p["top"] or r_top >= p["bottom"]:
					continue   # sem sobreposição vertical
				# Colide: desce r até passar do fundo da pilha já posicionada (+ folga).
				push += (p["bottom"] - r_top) + 4.0
				changed = true
		placed.append({
			"x": r["x"], "halfw": r["halfw"], "top": r["top"] + push, "bottom": r["bottom"] + push,
		})
		# Aplica o empurrão no pivô: para baixo na tela = mundo -up (convertido p/ o espaço local
		# do corpo, que gira com o modelo). push==0 deixa o pivô exatamente na base.
		var e: Dictionary = _member_label_pivots[r["idx"]]
		var body: Node3D = e["body"]
		if push > 0.0 and r["mpp"] > 0.0 and is_instance_valid(body):
			var down_local: Vector3 = body.global_transform.basis.inverse() * (-up_world * (push * float(r["mpp"])))
			(e["pivot"] as Node3D).position = (e["base"] as Vector3) + down_local


# Per-character: head bone(s) BodyParts can't infer from the name (it excludes
# "eye"/"mouth"), so the model browser names them explicitly for the preview.
const _MODEL_HEAD_BONES := {
	# Face panel ("mouth_eyes") + eyes ("L-EYE"/"R-EYE"). The eyes are excluded by the
	# "eye" keyword, so without forcing them the head would wrap only the ~42-vertex panel
	# and read as a tiny sphere. Mirrors red_robot.gd's gameplay head hitbox.
	"red_robot": ["mouth_eyes", "L-EYE", "R-EYE"],
}

# Per-character TORSO bone(s) the classifier can't infer from a generic name — same
# role as _MODEL_HEAD_BONES but for the trunk (red_robot's body is "Bone.001").
const _MODEL_TORSO_BONES := {
	"red_robot": ["Bone.001"],
}

# Per-character body PLAN (mirrors the @export body_type the gameplay sets, which the
# stripped preview can't read). Drives the member classifier. Default "biped".
const _MODEL_BODY_TYPE := {
	"red_robot": "biped",
	"player": "biped",
}

# Per-character HEAD collider shape (mirrors LimbColliders.head_shape the gameplay sets).
# Default "sphere"; the player uses a "capsule" (same orientation as the head bone).
const _MODEL_HEAD_SHAPE := {
	"player": "capsule",
}

# Forma do collider do TRONCO por modelo (espelha LimbColliders.torso_shape). Default "box".
const _MODEL_TORSO_SHAPE := {
	"red_robot": "sphere",
}

# Escala do collider da CABEÇA por modelo (espelha LimbColliders.head_scale). Default 1.0.
const _MODEL_HEAD_SCALE := {
	"red_robot": 1.3,
}

# Yaw frontal BASE por modelo (rad). Default é DEFAULT_FRONT_YAW (PI = 180°, para a convenção
# front=-Z). O player e o red_robot foram exportados com a FRENTE em +Z (a mesma direção da
# câmera), então o flip de 180° os mostraria de COSTAS — 0.0 os deixa de frente ao abrir.
const _MODEL_FRONT_YAW := {
	"player": 0.0,
	"red_robot": 0.0,
}

# Sub-membros (placas salientes etc.) NÃO ficam mais numa tabela aqui: vêm de LimbConfig
# (arquivo por modelo na PASTA do modelo: res://library3D/<cat>/<model_key>/limb_config.json; override
# de runtime em user://), editáveis na tela — o preview os recebe ao setar lc.model_key. Ver
# _add_member_colliders.


# Build best-fit colliders that wrap each body MEMBER (sphere/capsule head, box torso,
# capsule limbs) so they render green via the gizmos above. The gameplay script
# that normally builds these is stripped from the preview, so we build them here.
# Skeleton characters reuse the shared LimbColliders builder; the criatura (no
# skeleton) is grouped by mesh-node name instead.
func _add_member_colliders(instance: Node) -> void:
	var skels: Array = instance.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		var lc := LimbColliders.new()
		lc.body_type = _body_type_for_current()   # plano corporal → classificador
		lc.model_key = _current_model_key()        # sub-membros + dano de LimbConfig
		lc.include_suppressed = true               # PREVIEW: lista sub-membros suprimidos (gizmo escondido)
		lc.head_shape = _MODEL_HEAD_SHAPE.get(_current_model_key(), "sphere")  # cabeça: esfera/cápsula
		lc.torso_shape = _MODEL_TORSO_SHAPE.get(_current_model_key(), "box")   # tronco: caixa/esfera
		lc.head_scale = _MODEL_HEAD_SCALE.get(_current_model_key(), 1.0)       # volume da cabeça
		lc.hitbox_layer = 64        # own layer — does not touch damage layers (16/32)
		lc.padding = 0.04           # tight gap around the mesh (hugs the body)
		lc.head_bone_names = _head_bones_for_current()
		lc.torso_bone_names = _torso_bones_for_current()
		instance.add_child(lc)
		lc.build_for(skels[0] as Skeleton3D)
		_member_lc = lc
		_member_skel = skels[0] as Skeleton3D
		# Monta o cache de refit JÁ aqui (ao construir os colliders), movendo o custo único
		# (~150 ms, `surface_get_arrays`) para FORA da animação — sem soluço ao animar depois.
		lc._build_refit_cache(_member_skel)
		return
	# Rig sem esqueleto: colliders parentados ao nó animado (já seguem); sem refit por osso.
	_member_lc = null
	_member_skel = null
	_add_mesh_member_colliders(instance)


func _head_bones_for_current() -> Array[String]:
	return _model_bones_for_current(_MODEL_HEAD_BONES)


func _torso_bones_for_current() -> Array[String]:
	return _model_bones_for_current(_MODEL_TORSO_BONES)


func _model_bones_for_current(table: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key in table:
		if _current_model_path.contains(key):
			for b in table[key]:
				out.append(b)
			break
	return out


# Key ("characters"/"weapons"/…) of the category currently selected, or "" if on
# the "Selecione..." placeholder. Drives weapon-vs-character member detection.
func _current_category_key() -> String:
	var idx := cbo_category.selected - 1
	if idx < 0 or idx >= _categories.size():
		return ""
	return _categories[idx]["key"]


# Member colliders for a rig that has no Skeleton3D, grouping the visible mesh nodes
# by member name. Characters use BodyParts (head/torso/arms/legs → criatura_alada,
# mecha07); weapons use WeaponParts (cano/corpo/cabo/… → pistola etc.). Each collider
# is parented to the lowest common ancestor of its member's meshes — that ancestor is
# the node the animation drives (the limb pivot / recoiling receiver), so the collider
# (and its tooltip) MOVES WITH THE ANIMATION instead of staying behind.
func _add_mesh_member_colliders(instance: Node) -> void:
	var is_weapon := _current_category_key() == "weapons"
	# Personagens usam o classificador do plano (instância — BodyParts não é polimórfico
	# via estático); armas seguem o WeaponParts estático.
	var classifier := _current_classifier()
	var members: Dictionary = {}   # group -> {"label": String, "nodes": Array}
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var g := WeaponParts.group_of(mi.name) if is_weapon else classifier.group_of(mi.name)
		if g == "":
			continue
		if not members.has(g):
			var lab: String = WeaponParts.label_of(g) if is_weapon else classifier.label_of(g)
			members[g] = {"label": lab, "nodes": []}
		members[g]["nodes"].append(mi)

	var model_key := _current_model_key()
	for g in members:
		# "Selecione..." no dropdown de geometria (tela Models) suprime o collider do membro (SHAPE_NONE).
		if LimbConfig.collider_shape(model_key, g) == LimbConfig.SHAPE_NONE:
			continue
		var nodes: Array = members[g]["nodes"]
		var anchor := _lca(nodes, instance)
		if anchor == null:
			anchor = instance
		# AABB in the anchor's local space: the meshes are rigid under their animated
		# pivot, so this is pose-independent and stays glued to the moving member.
		var inv := (anchor as Node3D).global_transform.affine_inverse()
		var aabb := AABB()
		var first := true
		for n in nodes:
			var mi := n as MeshInstance3D
			var box := (inv * mi.global_transform) * mi.get_aabb()
			aabb = box if first else aabb.merge(box)
			first = false
		aabb = aabb.grow(0.04)

		var body := StaticBody3D.new()
		body.name = "Collider_%s" % g
		body.collision_layer = 64
		body.collision_mask = 0
		# "group" espelha o que LimbColliders carimba no caminho com esqueleto, para o
		# editor de dano por membro também listar rigs sem Skeleton3D (criatura).
		body.set_meta("group", g)
		body.set_meta("member_label", members[g]["label"])
		# Afastamento salvo (igual ao caminho com esqueleto em LimbColliders): move o corpo inteiro.
		body.position = LimbConfig.collider_offset(model_key, g)
		# Rotação salva (graus) — gira o corpo (igual ao caminho com esqueleto).
		body.rotation_degrees = LimbConfig.collider_rotation(model_key, g)
		# Forma escolhida na tela Models (override) tem prioridade; senão a automática por tipo de rig.
		var shape_override := LimbConfig.collider_shape(model_key, g)
		var shape_node: CollisionShape3D
		if shape_override == "sphere" or shape_override == "box" or shape_override == "capsule":
			shape_node = LimbColliders.make_shape(shape_override, aabb)
		elif is_weapon:
			# Barrel → capsule along its length; receiver/grip/stock/mag → box.
			var kind := "capsule" if g == WeaponParts.BARREL else "box"
			shape_node = LimbColliders.make_shape(kind, aabb)
		else:
			shape_node = LimbColliders.make_member_shape(g, aabb)
		# Escala salva (igual ao caminho com esqueleto): escala a forma em torno do seu centro.
		shape_node.scale = LimbConfig.collider_scale(model_key, g)
		body.add_child(shape_node)
		anchor.add_child(body)


# Lowest common ancestor of `nodes` within `root` (inclusive). For a single node it
# is the node itself; used to anchor a member's collider to the node the animation
# actually moves.
func _lca(nodes: Array, root: Node) -> Node:
	if nodes.is_empty():
		return root
	var common: Array = _ancestor_chain(nodes[0], root)
	for i in range(1, nodes.size()):
		var chain: Array = _ancestor_chain(nodes[i], root)
		var k := 0
		while k < common.size() and k < chain.size() and common[k] == chain[k]:
			k += 1
		common = common.slice(0, k)
	return common[-1] if not common.is_empty() else root


# Chain of nodes from `root` down to `node` (inclusive), root first.
func _ancestor_chain(node: Node, root: Node) -> Array:
	var chain: Array = []
	var n: Node = node
	while n != null:
		chain.push_front(n)
		if n == root:
			break
		n = n.get_parent()
	return chain


# Center and scale a model so it fits nicely in front of the camera, regardless
# of its original size. target_size is the largest dimension after scaling. Only
# mesh geometry is measured — lights and particle systems carry huge bounds (the
# forklift spotlight reaches 50 m) that would otherwise shrink the model to a dot.
# `precomputed` (an AABB in `model`'s local space) overrides the mesh measurement:
# used for skinned characters, whose mesh get_aabb() is the bind pose and can sit
# well off the posed body (see _posed_member_bounds).
func _fit_to_view(model: Node3D, target_size: float = 2.0, precomputed = null) -> void:
	var bounds := AABB()
	if precomputed is AABB:
		bounds = precomputed
	else:
		var visuals: Array = model.find_children("*", "MeshInstance3D", true, false)
		if model is MeshInstance3D:
			visuals.append(model)
		var first := true
		for node in visuals:
			var vi := node as MeshInstance3D
			# Frame only the body: skip hidden meshes (the forklift's unused colour
			# variants, a character's death debris) and meshes bolted to a bone
			# (muzzle/laser effects whose long beams would otherwise shrink the body
			# to a dot).
			if not vi.is_visible_in_tree():
				continue
			if _under_bone_attachment(vi, model):
				continue
			var rel := model.global_transform.affine_inverse() * vi.global_transform
			var box := rel * vi.get_aabb()
			if first:
				bounds = box
				first = false
			else:
				bounds = bounds.merge(box)
		if first:
			return

	var max_dim: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if max_dim <= 0.0:
		return
	var scale_factor := target_size / max_dim
	model.scale = Vector3.ONE * scale_factor
	model.position = -bounds.get_center() * scale_factor


# Bounds of the POSED body, measured from the per-member colliders (which wrap the
# skinned vertices in the live pose), in `model`'s local space. Used to frame and
# CENTER skinned characters correctly — their mesh get_aabb() is the bind pose and
# for red_robot sits ~1.4 m off in Z, which would put the rotation pivot behind the
# body. Returns an empty AABB (size 0) when there are no member colliders.
func _posed_member_bounds(model: Node3D) -> AABB:
	var inv := model.global_transform.affine_inverse()
	var bounds := AABB()
	var first := true
	for node in model.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if not body.has_meta("member_label"):
			continue
		for cs in body.find_children("*", "CollisionShape3D", true, false):
			var shape: Shape3D = (cs as CollisionShape3D).shape
			if shape == null:
				continue
			var box := (inv * (cs as CollisionShape3D).global_transform) * shape.get_debug_mesh().get_aabb()
			if first:
				bounds = box
				first = false
			else:
				bounds = bounds.merge(box)
	return bounds


# True when `node` hangs under a BoneAttachment3D somewhere below `root` — i.e.
# it is a prop pinned to a skeleton bone (weapon, muzzle/laser effect) rather
# than part of the model's body.
func _under_bone_attachment(node: Node, root: Node) -> bool:
	var parent := node.get_parent()
	while parent != null and parent != root:
		if parent is BoneAttachment3D:
			return true
		parent = parent.get_parent()
	return false


# --- Misc -------------------------------------------------------------------

# "red_robot" -> "Red Robot", "core_out_light" -> "Core Out Light".
func _prettify(raw_name: String) -> String:
	var words := raw_name.replace("_", " ").replace("-", " ").split(" ", false)
	var out: Array[String] = []
	for word in words:
		out.append(word.capitalize())
	return " ".join(out)


func _on_back_pressed() -> void:
	emit_signal("replace_main_scene", load(DEVELOPER_PATH))


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


# True quando o ponteiro está sobre a janela flutuante de Dano ou IA (visível). A roda do mouse
# leva esse evento ao _unhandled_input quando o scroll interno da janela está no limite (ou sobre
# uma área sem rolagem); aqui a usamos para NÃO aplicar o zoom do 3D nesse caso.
func _pointer_over_model_window() -> bool:
	if FloatingWindow.pointer_over_any_window():
		return true
	for panel in [damage_panel, ai_panel]:
		if is_instance_valid(panel) and panel.visible \
				and panel.get_global_rect().has_point(panel.get_global_mouse_position()):
			return true
	return false


# Hold the left mouse button over the render area and drag to hand-rotate the
# mesh on the two orthogonal axes (horizontal -> yaw, vertical -> pitch). Clicks
# that land on a dropdown or button are consumed by those controls first, so only
# drags over the empty 3D view reach here.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Não inicia o arraste se o clique caiu sobre uma janela flutuante (Dano/IA ou outra).
		_dragging = event.pressed and not _pointer_over_model_window()
	elif event is InputEventMouseButton and event.pressed and \
			event.button_index == MOUSE_BUTTON_WHEEL_UP:
		# Roda do mouse SOBRE a janela Dano/IA rola só o conteúdo dela, nunca o zoom do 3D.
		if _pointer_over_model_window():
			return
		# Wheel forward -> approach the model (smaller distance).
		_zoom_target = clampf(_zoom_target - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
	elif event is InputEventMouseButton and event.pressed and \
			event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if _pointer_over_model_window():
			return
		# Wheel backward -> pull away from the model (larger distance).
		_zoom_target = clampf(_zoom_target + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
	elif event is InputEventMouseMotion and _dragging:
		# Congela a rotação enquanto o ponteiro está sobre uma janela flutuante: a câmera só volta a
		# responder ao mouse quando o cursor sai da janela (ou ela fecha). Pedido do usuário.
		if _pointer_over_model_window():
			return
		var motion := event as InputEventMouseMotion
		# Both axes swing up to 180 degrees each side: yaw (left/right) turns the model
		# all the way around to its back, and pitch (up/down) tilts it all the way over.
		_yaw = clampf(_yaw + motion.relative.x * DRAG_SENSITIVITY, -PI, PI)
		_pitch = clampf(_pitch + motion.relative.y * DRAG_SENSITIVITY, -PI, PI)
