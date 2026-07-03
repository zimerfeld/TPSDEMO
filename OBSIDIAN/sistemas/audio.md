# Áudio (buses + settings)

Sistema de áudio do projeto: layout de buses em `default_bus_layout.tres`
(`uid://vtdn63d3ksc2`, referenciado por `project.godot` em `[audio]
buses/default_bus_layout`) e os controles na aba **Audio** das settings.

## Layout de buses

| # | Bus | Send | Uso |
|---|---|---|---|
| 0 | `Master` | — | mix final |
| 1 | `Outside` | `SFX` | zona de reverb (Area3D `SoundOutside`) |
| 2 | `Reactor` | `SFX` | zona de reverb (Area3D `SoundReactorRoom`) |
| 3 | `Music` | `Master` | música de fundo |
| 4 | `SFX` | `Master` | todo som que **não** é música |

`Music` carrega só a música de fundo, agora centralizada no autoload **MusicManager** (ver
seção abaixo) num único player com `bus = &"Music"` — os antigos nós `Music` embutidos em
`menu`/`chooseplayer` foram removidos. `SFX` (criado em 2026-06-16) carrega
**todo o resto**: cada `AudioStreamPlayer/3D` de gameplay (passos/tiro/explosão do
player, `Shot` da pistola, `Boom` da bomba, `sound` da porta, `Sound`/`Motor` dos
personagens, `Cannon`/`Explosion`/`Hit`/`Walk` do red_robot, etc.) recebeu
`bus = &"SFX"`, e os buses de reverb `Outside`/`Reactor` foram religados para mandar
em `SFX` em vez de `Master`. Assim mutar `SFX` silencia todo efeito sem tocar na música.

## Música por cena/level — `MusicManager` (2026-06-25)

Trilha de fundo por **nome de cena**, em **loop infinito**. O autoload `MusicManager`
(`res://autoload/music_manager.gd`) mantém um único `AudioStreamPlayer` no bus `Music`; a cada
troca de tela o roteador `main.gd` chama `MusicManager.play_for_scene(node)`:

- **Default = SILÊNCIO (2026-06-25):** uma cena SEM atribuição salva fica em **"Selecione..." = sem
  música** (não toca). Antes, o default resolvia automaticamente por `Audios/<nome-da-cena>.<ext>` — isso
  agora é a **opção "Padrão"** (override `BYNAME`), escolhida por cena no Gerenciador.
- **Resolução por nome (opção "Padrão"):** `res://Audios/<nome-da-cena>.<ext>` (1ª de `.ogg`/`.mp3`/`.wav`
  que existir), em `_resolve_by_name`. Ex.: `menu` → `Audios/menu.ogg`. `ALIASES` faz `chooseplayer`
  herdar a trilha do `menu`. Mesma faixa da cena anterior → continua sem reiniciar (transição suave).
- **Loop forçado em runtime** (`_ensure_loop`): vale para qualquer arquivo solto em `Audios/`,
  mesmo que o import venha com `loop=false`.
- **Online:** nas salas a cena raiz é `host_session`/`client_session`, então a música delas vem de
  `Audios/host_session.ogg`/`client_session.ogg`. Trocar a trilha pelo level observado dentro de uma
  sala (SubViewport próprio) está fora do escopo deste autoload.

Para definir a música de uma cena/level, basta colocar o arquivo em `res://Audios/` com o nome da
cena. Faixas inclusas: `Audios/menu.ogg`. Ver `Audios/README.md` e
[[fluxos/fluxo-de-cenas]].

### Gerenciador de Música (Settings → Música → Enabled)

Clicar em **Música: Enabled** na aba Audio abre o **Gerenciador de Música**
(`scenes2D/music_manager/music_manager_window.gd`). Desde 2026-06-29 é um **controlador** que monta o
formulário DENTRO da **janela flutuante reutilizável** (`FloatingWindow`), num `CanvasLayer` no topo —
mesmo padrão da janela **Gerenciador de Templates** (level templates). Assim herda o tema 2D do
projeto e o **Debug 2D funciona sobre ela** (a `FloatingWindow` entra no grupo do `DebugOverlay`),
igual às demais janelas flutuantes. Permite:

- **Ouvir** qualquer faixa de `Audios/` (player de pré-escuta separado; pausa o fundo enquanto toca).
  Cada botão **▶ Tocar** tem ao lado um **⏸ Pausar** e um **⏹ Parar** (2026-06-25) — tanto na linha
  "Ouvir faixa" quanto na lista por cena. ▶ retoma uma pausa da MESMA faixa (`preview_or_resume`).
- **Atribuir** a trilha de cada cena/level. **Todo dropdown tem "Selecione..." como 1ª opção = sem
  música (silêncio), o DEFAULT** de uma cena não configurada. Outras opções: **"Padrão"** (resolve pelo
  nome, override `BYNAME`) ou um **arquivo** específico.

As atribuições viram **overrides** persistidos em `Settings` (seção `[music]`: `scene_key = arquivo`,
`BYNAME` = pelo nome, `""` = silêncio explícito; **SEM chave = "Selecione..." = silêncio**, o default).
`_resolve()` lê isso. Mudar a
atribuição reaplica **na hora** se for a cena tocando. `MusicManager` expõe `list_tracks()`,
`scene_list()`, `assignment_of()`, `set_assignment()`, `effective_track()`, `preview()`,
`preview_or_resume()`/`pause_preview()`/`resume_preview()` (2026-06-25), `stop_preview()`. Abre via
`button_down` do botão Enabled (abre mesmo com a música já ligada). Os botões de ação ficam no
**rodapé** da `FloatingWindow` (**🎲 Sortear faixas** e **Fechar**); fechar (× / ESC / Fechar) para a
pré-escuta. O controlador persiste na tela Settings entre aberturas; a janela em si se autolibera ao
fechar.

**Sortear + persistência de estado (2026-06-25):** o rodapé tem um botão **"🎲 Sortear faixas"**
(no lugar do 2º "Parar" — já há um em "Ouvir faixa") que atribui uma faixa **aleatória** de
`Audios/` a CADA cena/level (`set_assignment`, que persiste) e atualiza a tela → as escolhas
recarregam na próxima abertura. Todo controle da janela **persiste ao mudar**: as atribuições por
cena já gravam via `set_assignment`; a faixa escolhida no "Ouvir faixa" agora grava em
`[music_ui] listen` e é restaurada no `_refresh` (`_restore_listen_choice`).

## Sons do player posicionais (3D) — 2026-06-24

Os efeitos do player (`SoundEffects/Step`, `Jump`, `Land`, `Shoot`) eram
`AudioStreamPlayer` (não-posicional) → no multiplayer você ouvia o tiro de outro
player sem saber de onde vinha. Agora são **`AudioStreamPlayer3D`** e o nó pai
`SoundEffects` virou **`Node3D`** (senão os filhos 3D tocariam na origem do mundo, não
na posição do player). Como esses sons já disparam via RPC **`@rpc("call_local")`**
(`jump`/`land`/`shoot`), eles tocam em todos os peers a partir da **posição replicada**
do player → espacialização correta, **sem tráfego de rede extra nem latência**. Para o
player **local** (câmera = listener, bem perto) o som fica nítido e consistente.

- **Alcance/atenuação** (calibrado p/ não desperdiçar vozes de áudio com players
  distantes): `Step` `unit_size 8`/`max_distance 30`;
  `Jump`/`Land` `8`/`35`; `Shoot` `12`/`60` (tiro carrega mais longe; alcances espelham
  o `Motor` da criatura ~35 e a `Explosion` do red_robot ~60). Acima do `max_distance` o
  Godot descarta a voz → custo de CPU só para sons audíveis.
- A `playera` herda tudo (instancia `player.tscn`), então o mesmo vale para a variante.

## Controles nas settings

Aba **Audio** de `scenes2D/settings/settings.tscn` tem duas linhas independentes,
cada uma um par de botões `Disabled`/`Enabled` em `ButtonGroup` (ver `_make_button_group`):

- **Música** (`MusicRow`) → chave `[audio] music`
- **Efeitos de Som** (`SFXRow`) → chave `[audio] sfx`

`settings.gd` lê/grava as duas em `_load_current_settings` / `_on_apply_pressed`.
`Settings` (autoload `scenes2D/settings/config.gd`) aplica em
`apply_audio_settings()`: muta/desmuta os buses `Music` e `SFX` via
`AudioServer.set_bus_mute(get_bus_index(...), not valor)`. Defaults em `DEFAULTS.audio`
(`music = true`, `sfx = true`); `apply_audio_settings()` roda no `_ready` do autoload
e a cada mudança de opção.

### Volume por bus — VolumeBar (2026-06-25)

À direita de cada linha (Música/SFX) há um **`VolumeBar`** (`controls2D/volume_bar/`,
`class_name VolumeBar`), controle de volume **reutilizável** desenhado como **equalizador** (10
segmentos, gradiente verde→amarelo→vermelho) que o usuário **clica/arrasta** para ajustar de
**1 a 100** (emite `value_changed`). `settings.gd` cria os dois em código (`_add_volume_bar`),
liga/desliga conforme o toggle (`enabled`, volume só ajustável com o áudio ligado) e grava em
`[audio] music_volume` / `sfx_volume`. `apply_audio_settings()` converte o % em dB
(`_volume_to_db` → `linear_to_db`; 100% = 0 dB) e aplica via `AudioServer.set_bus_volume_db`.
Defaults `music_volume = 100` / `sfx_volume = 100`. O controle também aparece sozinho na tela
**Controles** (o scanner de `controls2D/` acha `volume_bar/volume_bar.tscn`).

> **Botões ativos "acesos" (2026-06-25):** `scenes2D/menu/button_pressed.tres` (estado pressed/ativo
> do tema, usado pelos radios das settings) passou de fundo escuro (recuado) para **fundo claro +
> borda branca + brilho** → o botão selecionado se destaca como "aceso".

## Preview de modelos

Como os emissores dos personagens passaram pro bus `SFX`, o áudio do preview na
[[sistemas/biblioteca-de-modelos]] também respeita o mute global de `SFX` — os
toggles locais **Audio** (todo som que não é fala) e **Falas** (só voz/gritos,
classificados por nome via `_is_speech_audio`) ligam/desligam a reprodução, e o bus
global pode silenciá-la por cima.

## Relacionado

- [[sistemas/biblioteca-de-modelos]]
- [[fluxos/fluxo-de-cenas]]
- [[convencoes/formatacao]]
