# Audios — trilhas de fundo por cena/level

🇬🇧 Background-music tracks, one per scene/level, played in an **infinite loop** by the
`MusicManager` autoload (`res://autoload/music_manager.gd`).
>
🇧🇷 Trilhas de fundo, uma por cena/level, tocadas em **loop infinito** pelo autoload
`MusicManager` (`res://autoload/music_manager.gd`).

## Como funciona / How it works

🇬🇧 On every screen change the router (`main.gd`) calls `MusicManager.play_for_scene()`, which
plays `res://Audios/<scene-name>.<ext>` in a loop. The name is the scene's file name without
extension (e.g. `menu.tscn` → `menu`). Supported extensions, in priority order: `.ogg`, `.mp3`,
`.wav` (first one found wins). No file for a scene → silence. If the next screen resolves to the
**same** track, it keeps playing without restarting.
>
🇧🇷 A cada troca de tela o roteador (`main.gd`) chama `MusicManager.play_for_scene()`, que toca
`res://Audios/<nome-da-cena>.<ext>` em loop. O nome é o do arquivo da cena sem extensão (ex.:
`menu.tscn` → `menu`). Extensões aceitas, por prioridade: `.ogg`, `.mp3`, `.wav` (a 1ª encontrada
vence). Sem arquivo para a cena → silêncio. Se a próxima tela cair na **mesma** trilha, ela
continua tocando sem reiniciar.

> **Loop:** o `MusicManager` força loop em tempo de execução, então qualquer arquivo que você
> soltar aqui toca em loop infinito mesmo sem ajustar o import. / The loop is forced at runtime,
> so any file you drop here loops infinitely even without tweaking its import settings.

## Para adicionar uma trilha / To add a track

🇬🇧 Drop an audio file in this folder named exactly after the target scene/level (see list below)
and let Godot import it. That's it — the music plays automatically next time that screen opens.
>
🇧🇷 Solte um arquivo de áudio nesta pasta com o nome exato da cena/level alvo (lista abaixo) e
deixe o Godot importar. Pronto — a música toca sozinha na próxima vez que aquela tela abrir.

## Nomes esperados / Expected file names

| Arquivo / File          | Tela ou level / Screen or level                | Status |
|-------------------------|------------------------------------------------|--------|
| `menu.ogg`              | Menu principal / Main menu                     | ✅ incluso / bundled |
| `chooseplayer.ogg`      | Escolher personagem (senão usa `menu.ogg`)     | herda menu / inherits menu |
| `playonline.ogg`        | Jogar Online                                   | — |
| `levels.ogg`            | Seleção de level (Jogar)                       | — |
| `controls.ogg`          | Controles                                      | — |
| `developer.ogg`         | Modo Developer                                 | — |
| `settings.ogg`          | Configurações / Settings                       | — |
| `host_session.ogg`      | Sessão host (salas online)                     | — |
| `client_session.ogg`    | Sessão cliente (salas online)                  | — |
| `models.ogg`            | Biblioteca de modelos                          | — |
| `level_1.ogg`           | Level 1                                        | — |
| `level_2.ogg`           | Level 2                                        | — |

> **Online:** nas salas, a tela raiz é `host_session`/`client_session`, então a música delas vem
> de `host_session.ogg`/`client_session.ogg`. A troca de trilha por level observado dentro de uma
> sala não é feita aqui (cada sala roda num SubViewport próprio). / In online rooms the root screen
> is the session, so its music comes from `host_session.ogg`/`client_session.ogg`; per-observed-room
> level music is out of scope here.

## Licença / Licensing

🇬🇧 Only add music you have the right to use (your own, CC0/public-domain, or a license that
permits bundling in a game). Do **not** add copyrighted commercial tracks ripped from streaming
sites. `menu.ogg` was already in the project.
>
🇧🇷 Só adicione músicas que você tem direito de usar (suas, CC0/domínio público, ou licença que
permita embutir num jogo). **Não** adicione faixas comerciais com direitos autorais baixadas de
sites de streaming. `menu.ogg` já estava no projeto.
