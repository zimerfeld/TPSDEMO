---
tipo: sistema
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-05
---

# 🌀 Fundos animados das telas 2D (shaders de portal/vórtice)

> Cada tela 2D de UI tem um fundo animado próprio, feito só com **matemática por pixel** (sem
> textura, sem draw call extra) para respeitar a meta de **60 FPS em hardware gráfico mínimo**
> (`CLAUDE.md`). São `ColorRect` em `CanvasLayer` de fundo (`layer = -2`) com `ShaderMaterial`.
> Não confundir com [[🌌 ambiente-dos-levels (PT)|🌌 ambiente-dos-levels]], que é o ambiente **3D** dentro das arenas.

## Shaders (pasta `themes/backgrounds/`)

| Tela | Shader | Identidade |
|---|---|---|
| Níveis (`levels`) | `levels_bg.gdshader` | Portal/vórtice em espiral ciano ↔ magenta, núcleo pulsante |
| Developer | `developer_bg.gdshader` | — |
| Play Online | `playonline_bg.gdshader` | — |
| Settings | `settings_bg.gdshader` | — |

## ⚠️ Regra de ouro: a emenda do `atan()` no eixo esquerdo

Fundos radiais/polares usam `atan(p.y, p.x)` para o ângulo. Essa função **"vira" de +π para −π ao
longo do eixo horizontal esquerdo** (x negativo, y≈0). Qualquer termo que dependa do ângulo e **não
seja periódico em 2π** troca de valor bruscamente ali → aparece uma **linha/emenda visível** só do
lado esquerdo (o direito nunca costura, pois não cruza a virada).

**Como evitar:**
- Multiplicador do ângulo dentro de `sin()`/`cos()` deve ser **inteiro** (ex.: `sin(twist * 2.0)`
  fecha o ciclo na volta; `sin(twist * 1.5)` inverte o sinal e emenda).
- Setores angulares (`floor(ang * N)`, ruído/cintilância) devem usar o ângulo **normalizado e
  enrolado**: `fract(ang / 6.2831853 + 0.5)`. Assim a borda ±π vira só mais uma divisa de setor,
  não uma linha radial contínua.

## Correção aplicada em `levels_bg` (2026-07-05)

O usuário notou uma "divisão" perceptível à esquerda do portal. Duas causas, ambas a emenda acima:
1. **Cor do vórtice** usava `sin(twist * 1.5 + …)` → multiplicador não inteiro. Trocado para
   `* 2.0` (era essa a linha forte). A espiral dos braços já era imune por usar `arms = 5.0` (inteiro).
2. **Cintilância** usava `floor(ang * 20.0, …)` → setores não fechavam o círculo. Passou a usar
   `na = fract(ang / 6.2831853 + 0.5)` e `floor(na * 40.0, …)`.

Resultado: lado esquerdo tão contínuo quanto o direito, **60 FPS** mantidos, validado no `.exe`.
Relacionado: [[🎬 fluxo-de-cenas (PT)|🎬 fluxo-de-cenas]] (a tela Níveis fica em chooseplayer→levels→level_x),
[[optimize-when-adding-scene-elements]].
