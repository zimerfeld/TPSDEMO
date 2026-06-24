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

`Music` carrega só a música de fundo (players `Music` em `menu`, `chooseplayer`,
`level_base`, todos com `bus = &"Music"`). `SFX` (criado em 2026-06-16) carrega
**todo o resto**: cada `AudioStreamPlayer/3D` de gameplay (passos/tiro/explosão do
player, `Shot` da pistola, `Boom` da bomba, `sound` da porta, `Sound`/`Motor` dos
personagens, `Cannon`/`Explosion`/`Hit`/`Walk` do red_robot, etc.) recebeu
`bus = &"SFX"`, e os buses de reverb `Outside`/`Reactor` foram religados para mandar
em `SFX` em vez de `Master`. Assim mutar `SFX` silencia todo efeito sem tocar na música.

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
e a cada `Aplicar`.

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
