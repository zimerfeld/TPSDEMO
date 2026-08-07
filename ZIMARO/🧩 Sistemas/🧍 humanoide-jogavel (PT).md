---
tipo: sistema
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-08-07
---

# 🧍 Humanoide jogável

> Terceiro personagem selecionável, com rig e vocabulário de animação PRÓPRIOS — e as costuras que
> transformaram a classe `Player` de "o robô" em chassi de personagem.
> Irmãs: [[🧍 humanoide-jogavel (EN)|EN]] · [[🧍 humanoide-jogavel (ES)|ES]].
> Ver também [[🎮 player (PT)]], [[🎛️ controles-e-gestos (PT)]] e [[🧩 templates-de-level (PT)]].

## O bloqueio que definiu o desenho

**A velocidade do player não vem de código: vem da animação.** O `apply_input` lê
`get_root_motion_position()` e divide por delta — o corpo anda exatamente o que a passada andou, e é
por isso que os pés não patinam. Não existe nenhuma constante de velocidade horizontal no `player.gd`.

Medido nos dois `.glb`:

| modelo | osso `root` em `andar`/`correr` |
| --- | --- |
| `player.glb` | anda de verdade (`walking_gun` percorre 2,18 m em 1,25 s) |
| `humanoide3.glb` | deslocamento horizontal **zero** — as animações são **in-place** |

Ligado ao motor do player, o humanoide mexeria as pernas **parado no lugar**. Retarget resolveria (é o
caminho do FIGArtStudio), mas ficou fora de escopo por decisão do dono. A saída foi **locomoção por
velocidade**: `_apply_horizontal_velocity` virou **virtual** na base, o humanoide a sobrescreve, e a
cadência da animação é escalada (`AnimationNodeTimeScale`) para o passo casar com a velocidade real —
mesma técnica que o `red_robot` usa no movimento manual.

> A troca **não** bifurca o netcode: `_reconcile` é posicional e agnóstico à fonte da velocidade, e
> servidor e cliente-dono passam pelo MESMO `apply_input`. Continua um caminho, parametrizado.

## As costuras na classe `Player`

Quatro pontos prendiam a mecânica ao robô. Todos com defaults que deixam `player`/`playera`
idênticos ao que eram:

| antes | agora | por que importa |
| --- | --- | --- |
| `player_model.get_node_or_null("Robot_Skeleton/Skeleton3D")` | `skeleton()`, busca por TIPO | `Robot_Skeleton` é a raiz do glTF **dentro** do `player.glb`, não algo autorado. Em outro modelo devolvia `null` **em silêncio** → personagem sem dano por membro e sem mira procedural |
| `shoot_from` por caminho literal | busca pelo nome `ShootFrom` | cada modelo pendura o ponto de tiro num osso diferente |
| `model_key`/`head_shape`/… fixos no método | `@export` (`limb_model_key`, …) | não dava para sobrescrever numa subclasse sem reescrever o método inteiro |
| velocidade do root motion, direto | `_apply_horizontal_velocity` virtual | ver acima |

## A cena

`library3D/characters/humanoide_jogavel/humanoide_jogavel.tscn`, gerada por
`scripts/build_humanoide_jogavel.gd` (rodar de novo regenera).

**Pasta própria, e não dentro de `humanoide/`:** a whitelist de replicação casa
`basename == nome da pasta`; fora dela o `MultiplayerSpawner` **recusa em silêncio** e o jogador fica
invisível para os outros peers.

**Cópia plana, não cena herdada:** o truque da `playera` (instanciar `player.tscn` + script) não
serve — o Godot não permite repontar o `PackedScene` de um nó herdado, e é exatamente o modelo que
precisamos trocar.

Duas armadilhas que só o teste pegou, ambas silenciosas:

1. **`PlayerModel` É a instância do `player.glb`**, não um nó vazio. Esvaziá-lo não adianta: o `pack`
   restaura os filhos e a cena saía com os dois modelos (145 ossos do robô em vez dos 16). Só resolve
   trocando o nó inteiro por um `Node3D` de mesmo nome.
2. **Filhos adicionados dentro de uma instância** (o `GunBone`/`ShootFrom` no esqueleto) só sobrevivem
   ao `pack` se ela for marcada com `set_editable_instance` — sem isso o personagem nascia sem de onde
   atirar.

## Animações

Escopo desta entrega: **`ocioso`** parado, **`andar`** para qualquer direção (W/S/A/D) e **`saltar`**.
A árvore expõe os **mesmos nomes de parâmetro** que o `Player.animate()` já escrevia
(`parameters/state/transition_request`, `walk`/`strafe` `blend_position`, `aim/add_amount`), então
nem uma linha daquele código mudou.

Duas armadilhas de `AnimationTree` registradas: `walk`/`strafe` **têm** que ser `BlendSpace2D` (o
código escreve `Vector2`; um 1D rejeita o valor todo frame e a saída congela), e pontos **colineares**
degeneram a triangulação — por isso os quatro pontos cardeais.

## Orientação, velocidade e cadência (2026-08-07, pós-teste)

**Giro de 180°.** O glTF do humanoide foi autorado encarando o lado OPOSTO ao do player: com o mesmo
transform de nó, a malha dele andava de costas. A correção é `rotation.y = PI` no nó do MODELO (no
gerador), e não na lógica — assim direção de movimento, mira e ponto de tiro seguem falando a mesma
língua do player e do red_robot.

> Medir o ângulo do NÓ não denuncia esse problema: os transforms de humanoide e player eram iguais. O
> que difere é para onde a MALHA aponta dentro do `.glb`. É um caso em que só o olho pega — foi um
> playtest que o encontrou, não os testes automatizados.

**A animação estava apressada** porque a cadência valia `velocidade / 1,45` com teto **2,6×**: a
5,2 m/s ela batia no teto e tocava um clipe de CAMINHADA a quase três vezes a velocidade. Duas
mudanças resolveram:

1. O estado `walk` virou uma progressão **parado (0) → `andar` (0,45) → `correr` (1,0)**.
2. A cadência divide pela velocidade que o clipe REALMENTE representa, medida pela duração do ciclo:
   `andar` 1,10 s ≈ **1,4 m/s**; `correr` 0,85 s ≈ **4,0 m/s**.

Medido depois: caminhando 1,70 m/s com cadência **1,21×**; correndo 4,50 m/s com **1,12×**. A faixa
permitida ficou estreita (0,75–1,3) de propósito — precisar de 2× é sinal de que o clipe errado está
tocando.

## Correr, abaixar e o lado da mira

| tecla | efeito |
| --- | --- |
| **SHIFT** (segurar) | corre: 4,5 m/s e clipe `correr`. Solto, caminha a 1,7 m/s com `andar` |
| **CTRL** (segurar) | abaixa: `ajoelhar_dir` ou `ajoelhar_esq` **conforme o lado da mira**; soltar aborta o gesto |
| **C** | alterna o ombro da mira e LEMBRA a escolha (`Settings → reticle_side`) |

As três são ações remapeáveis na aba Controles. **`running` e `crouching` são REPLICADOS**: sem isso o
servidor simularia caminhada enquanto o cliente corre, e a reconciliação passaria a corrigir uma
divergência que é só de input — o mesmo mecanismo que produz o "flickering".

O lado da mira é aplicado **depois** da animação da câmera, espelhando o X do `SpringArm3D`: o clipe
de mira continua único, só troca de ombro.

## Números a calibrar no olho

`MAX_SPEED = 5,2 m/s` e a altura da câmera `1,72 m` foram **estimados**. Uma constante cada.

## Registro na seleção

`PlayerSelection.VARIANTS` e `chooseplayer.CHARACTERS` têm de ficar na **mesma ordem** — o que trafega
pela rede é o **índice**. Acrescentar sempre no fim; inserir no meio faz o jogador nascer com o corpo
errado em todos os peers, e o clamp esconde o problema.

O preview da tela deixou de ser cravado no `player.glb`: cada personagem declara `model_glb` e
`idle_anim` (o robô descansa em `Idlecombatrest`; o humanoide, em `ocioso`).

**Bug corrigido de passagem:** o Label do nome entrava na árvore com o texto `"PLAYER"`, que o
`Locale` congela como fonte — trocar de idioma revertia o nome para "PLAYER". Resolvido pondo o nó no
grupo de tradução manual (nome próprio é dado, não vai para dicionário).
