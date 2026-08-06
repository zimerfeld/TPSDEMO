---
tipo: sistema
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-08-06
---

# 🦴 HP por Membro (condição de abate)

> Implementado em 2026-08-06. Substitui a **barra única de vida** como condição de morte:
> o personagem só cai quando **todos os membros e sub-membros** forem destruídos.
> Arquivo novo: `effects_shared/limb_health.gd` (`class_name LimbHealth`).

---

## Ideia

Cada membro/sub-membro com collider de gameplay tem o **seu próprio HP**. O dano vai para o membro
atingido, não para uma barra global. A vida total do personagem continua existindo — ela é **repartida**
entre os membros e passa a ser apenas o espelho da soma (`health = limbs.total_hp()`), para as barras
que mostram o corpo inteiro continuarem funcionando.

A **porcentagem configurada na tela Models continua sendo multiplicador de DANO**, como sempre foi
(ver [[🩸 dano-localizado (PT)|🩸 dano-localizado]]). Um membro a 200% cai com metade dos tiros. Nada
precisou ser reconfigurado por modelo.

---

## Reparto do HP

| Membro | Peso |
|---|---|
| CABEÇA | `HEAD_HP_WEIGHT` = **2,0** |
| Todos os demais | 1,0 |

`HP do membro = vida_total × peso / soma_dos_pesos`

Engrossar a cabeça **afina os demais na mesma medida** — o total continua sendo a vida do personagem,
ninguém ganha vida de graça.

---

## Quem conta para o abate

**Todo membro/sub-membro que o modelo constrói de fato** (tem collider de gameplay). Quem não tem
porcentagem própria no `LimbConfig` usa o dano padrão 1×.

> ⚠️ A alternativa — contar só quem tem porcentagem configurada — foi **medida** e descartada: no
> red_robot dava 5 membros (os dois escudos, o tanque e as duas placas traseiras), porque o
> `limb_config.json` dele só define `PART_FuelTank`. Cabeça, tronco, braços e pernas ficavam de fora,
> ou seja, **acertar a cabeça não ajudava a derrubar o inimigo**. Contar pelo collider evita esse
> buraco sem exigir reconfigurar modelo por modelo.

---

## Propagação (quem cai junto)

```
membro-pai destruído  →  todos os sub-membros dele caem
sub-membro do ROSTO   →  derruba a CABEÇA (e, por tabela, os irmãos dela)
sub-membro comum      →  NÃO derruba o membro-pai
```

O critério de "rosto" é o **membro-dono ser a CABEÇA** (`BodyParts.HEAD`), não uma lista de nomes de
osso — assim vale para qualquer modelo e em qualquer idioma. É o que devolve valor à mira precisa:
pelo caminho bruto a cabeça custa vários acertos; pelo olho/boca, **um só**.

---

## Calibragem (medida em 2026-08-06)

| Personagem | Vida total | Cabeça | Membro comum | Abate |
|---|---|---|---|---|
| **Red Robot** | `max_health` = **550** | 92 | 46 | **7 tiros** de 50 |
| **Player** | `MAX_HP` = **150** | 27 | 14 | **13 acertos** de 10 · **11** mirando o rosto |

Por que esses números:

- **Red Robot** — com os 200 antigos cada membro ficava com 18 HP, e o tiro do player (50) derrubava
  qualquer peça de uma vez; o canhão de 10 do próprio robô tirava mais da metade de um membro por
  acerto. 550 mantém a granularidade sã. Entre 200 e 550 o **número de tiros não muda** (o custo é o
  número de membros, não a vida); acima de ~560 cada membro passaria a exigir 2 tiros e o abate
  saltaria para 12.
- **Player** — com os 100 antigos cada membro tinha exatamente 10 HP e caía com **um** acerto: o
  player morria em 6 acertos, ou seja, a mudança o havia deixado **mais frágil** do que antes. 150 dá
  15 por membro (2 acertos cada) e devolve o equilíbrio dos ~10 acertos do modelo de vida única.

---

## Overlay

Ao mirar num membro, a *boss bar* mostra **o nome do membro e o HP dele** — `Red Robot — CABEÇA`, com
`92` de máximo —, não a vida do corpo. É o membro que precisa cair, então é o número que importa.
Ver [[🤖 inimigos (PT)|🤖 inimigos]].

---

## Rede

`hit()` é `@rpc("call_local")`: **todos os pares aplicam o mesmo dano** e chegam ao mesmo estado.
Nenhum dicionário é replicado. Quem dispara passa o membro atingido junto do dano:

```gdscript
character.hit.rpc(int(round(weapon_damage * mult)), String(collider.get_meta("group", "")))
```

---

## Facções

Vale para **inimigos, friendly e neutros** — o `player` usa o mesmo sistema (com `limbs.reset()` no
respawn). A `criatura_alada` **não** constrói colliders de membro, então segue com vida única e apenas
aceita o argumento novo. Ver [[⚔️ facções (PT)|⚔️ facções]].

---

## 💥 Efeito visual do desmonte (2026-08-06)

`LimbHealth` emite **`limb_destroyed(group)`** a cada membro que cai — inclusive os arrastados pela
propagação. O personagem liga esse sinal a **`LimbColliders.collapse_limb(group)`**, que:

1. **desliga o collider** daquele membro (peça caída não recebe mais tiros);
2. **colapsa o osso** via [[limb-debris]] → a peça **some da malha**, e o que vem depois dela na cadeia
   some junto (o braço leva antebraço, mão e o escudo preso nele);
3. solta uma **nuvem de faíscas** (`CPUParticles3D` one-shot, material *unshaded*, auto-liberada) no
   ponto do osso — barata, dentro do teto de 60 FPS do projeto.

O **TRONCO não colapsa**: é a raiz do rig, e sumir com ele levaria o personagem inteiro, membros de pé
inclusive. Ele recebe só as faíscas. No **respawn** do player, `restore_limbs()` devolve as peças e
religa os colliders.

> ⚠️ **ARMADILHA da virtual (medida em 2026-08-06).** `LimbDebris` é um `SkeletonModifier3D`, porque a
> AnimationTree reescreve a pose de todos os ossos a cada quadro — zerar a escala em qualquer outro
> ponto seria desfeito no quadro seguinte. **No Godot 4.6 a engine chama
> `_process_modification_with_delta(delta)`**; a `_process_modification()` sem argumentos ainda aparece
> na `ClassDB` mas ficou **legada**. Implementar só a versão sem delta faz o modificador **nunca rodar,
> sem erro nenhum** — colliders desligam, faíscas saem, e a peça continua lá (medido: 0 chamadas contra
> 22). Implementamos as duas.
>
> 🔍 **Como VERIFICAR:** ler `get_bone_pose_scale()` **de fora** devolve `1.0` mesmo com o membro
> sumido — a leitura pega a pose de ENTRADA que a animação acabou de reescrever. A escala só é
> observável **dentro** do pipeline de poses: use um **segundo `SkeletonModifier3D` como sonda**,
> adicionado DEPOIS do `LimbDebris`, e leia `get_bone_global_pose()` lá. Medido assim: membro destruído
> `(0.001, 0.001, 0.001)`, membro intacto `(1.0, 1.0, 1.0)`.

---

## Limitações conhecidas
- Dano **sem membro identificado** (explosão de área, queda) continua descontando da vida global,
  senão esses golpes ficariam inertes.

---

## Arquivos

| Arquivo | Papel |
|---|---|
| `effects_shared/limb_health.gd` | **NOVO** — `LimbHealth`: reparto, dano, propagação, abate |
| `effects_shared/limb_debris.gd` | **NOVO** — `LimbDebris`: colapsa o osso (a peça some) + faíscas |
| `effects_shared/limb_colliders.gd` | Carimba a meta `owner_group` (membro-dono do sub-membro) |
| `library3D/characters/red_robot/red_robot.gd` | `limbs`, `hit(amount, group)`, overlay por membro |
| `library3D/characters/player/player.gd` | `limbs`, `hit(amount, group)`, `reset()` no respawn |
| `library3D/characters/player/bullet/bullet.gd` | Passa o membro atingido |
| `effects_shared/laser_shooter.gd` | Passa o membro atingido |
| `library3D/characters/player/player_input.gd` | Membro sob a mira → overlay |

Relacionadas: [[❤️ sistema-de-vida (PT)|❤️ sistema-de-vida]] · [[🩸 dano-localizado (PT)|🩸 dano-localizado]] · [[🗿 biblioteca-de-modelos (PT)|🗿 biblioteca-de-modelos]]
