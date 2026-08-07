---
tipo: sistema
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-08-07
---

# 🎛️ Controles, remapeamento e gestos

> Aba **Controles** das configurações: cada função do jogador e cada animação do modelo mapeáveis a
> uma tecla ou botão do mouse — e o caminho que faz a animação de fato tocar em partida.
> Irmãs: [[🎛️ controles-e-gestos (EN)|EN]] · [[🎛️ controles-e-gestos (ES)|ES]].
> Ver também [[🧍 humanoide-jogavel (PT)]] e [[🎮 player (PT)]].

## ESC na partida abre as configurações

Antes o ESC abria direto a confirmação "Abandonar a partida ?". Agora abre a **tela de configurações
sobre o jogo**, que fica **pausado** — é o que deixa o personagem ocioso, sem responder aos comandos e
sem continuar levando dano enquanto o jogador mexe nas opções. A tela roda em `PROCESS_MODE_ALWAYS`
para funcionar com a árvore parada (mesmo padrão que a confirmação já usava).

- **Voltar** retoma o jogo exatamente de onde parou (despausa, recaptura o mouse).
- **Abandonar Partida** — botão que só existe nesse modo, montado em código — chama a **mesma**
  confirmação de sempre. "Sim" volta à seleção de níveis; "Não" devolve o jogador às configurações,
  com o jogo ainda pausado.

**Online ficou como estava** (ESC volta ao menu): em sala a árvore não pode ser pausada — congelaria a
replicação — e o ESC das salas já é tratado pelo `host_session`/`client_session`, que nem repassam a
tecla ao nível dentro do SubViewport.

## Remapeamento de ações

`scenes2D/settings/input_bindings.gd`. As ações e seus eventos **padrão** vivem no `project.godot`;
só o que o jogador MUDOU vai para `Settings.config_file`, seção `bindings` — quem nunca remapeou
continua com o arquivo limpo.

- 14 ações em quatro grupos: **Movimento**, **Combate**, **Câmera**, **Sistema**.
- Clicar no atalho entra em captura ("Pressione uma tecla…"); ESC cancela. Aceita **tecla ou botão do
  mouse**.
- Teclas gravadas por **posição física** (`physical_keycode`), como o resto do projeto: AZERTY e ABNT2
  mantêm o mesmo lugar no teclado.
- Os eventos **de fábrica** são guardados em memória no boot, antes de qualquer override — é a eles
  que o botão **Padrão** volta, sem reiniciar.
- Conflito com outra ação é **aceito com aviso**: quem remapeia costuma trocar duas ações de lugar, e
  bloquear obrigaria a limpar uma antes.
- `Settings.load_settings()` aplica os overrides no boot; sem isso valeriam só na sessão em que foram
  feitos.

> **Gotcha:** `ConfigFile.get_value(section, key, null)` conta como "sem default" e enche o console de
> erro. O sentinela de "não salvo" é um **dicionário vazio**.

## Atalhos de animação

`scenes2D/settings/animation_bindings.gd`. A lista **não é escrita à mão**: sai das animações do
próprio modelo humanoide, lidas do `.glb` — acrescentar um clipe no Blender já o faz aparecer na tela.
São as 36 do rig de 16 ossos em português (`ocioso`, `andar`, `rolar_frente`, `defender_esq`…), o
mesmo banco que o FIGArtStudio usa.

- Persistência em `anim_bindings`, só o que o jogador mudou.
- **Herança de padrão:** `andar`/`correr` herdam a tecla de `move_forward`, `saltar` a de `jump`,
  `atirar_*` a de `shoot`. Remapear a ação leva a animação junto — é herança, não cópia.
- `defender_*` ficou **fora** dos padrões de propósito: o botão direito é a **mira** (liga/desliga),
  não a defesa; herdar dela faria o mesmo botão significar duas coisas.

## Gestos: como a animação toca em partida

Três decisões, cada uma evitando um jeito de dar errado:

1. **Gesto é CAMADA, não estado.** Vai num `AnimationNodeOneShot` por cima da locomoção. Como estado,
   o `animate()` — que roda a cada frame de física — o reescreveria no frame seguinte e o gesto
   simplesmente não apareceria. Medido: o personagem percorre 2,34 m **enquanto** o gesto toca.
2. **O evento NÃO é consumido, e locomoção nunca vira gesto.** `ocioso`/`andar`/`correr`/`saltar` são
   da máquina de estados (`AnimationBindings.is_locomotion`); dispará-las por cima brigaria com o
   próprio andar. Somado a não consumir o evento, é o que mantém o **WSAD intacto** mesmo quando uma
   animação de locomoção herda aquela tecla. Só a **borda de subida** conta — segurar não redispara.
3. **O servidor media.** O dono toca na hora (responsividade) e pede confirmação; o servidor **valida
   que quem pediu é o dono daquele corpo** — senão qualquer peer animaria o personagem alheio — e
   retransmite a todos. O eco que volta ao dono é ignorado por uma janela, para não tocar duas vezes.

Personagem sem a camada (o robô, hoje) é **no-op silencioso**: `supports_gestures()` devolve `false`.

## Onde isso vive

| arquivo | papel |
| --- | --- |
| `scenes2D/settings/input_bindings.gd` | ações: captura, persistência, aplicação no `InputMap`, padrões |
| `scenes2D/settings/animation_bindings.gd` | animações: lista lida do `.glb`, herança de padrão, consulta por evento |
| `scenes2D/settings/settings.gd` | a aba (linhas montadas em código), captura compartilhada, modo pausa |
| `library3D/characters/player/player.gd` | `request_gesture` / `play_gesture` (RPC mediado pelo servidor) |
| `library3D/characters/player/player_input.gd` | interceptação da tecla no dono local |
| `scenes3D/level_exit.gd` | ESC → configurações; confirmação de abandono |
