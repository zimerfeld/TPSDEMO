# Ambiente visual dos levels (céu + fog + piso-grade neon)

> Identidade visual cyberpunk das arenas 3D, implementada em 2026-07-03 com **técnicas baratas**
> (meta do projeto no `CLAUDE.md`: mínimo 60 FPS em hardware gráfico mínimo). Validado no `.exe`:
> **60 FPS cravados** nos dois levels, inclusive em combate. Relacionado: [[sistemas/salas]],
> [[sistemas/templates-de-level]], regra de otimização ([[optimize-when-adding-scene-elements]]).

## Identidade por level

| Level | Céu/horizonte | Grade do piso | Luz direcional |
|---|---|---|---|
| `level_1` | Navy escuro → horizonte **teal/ciano** | Linhas **ciano** (0.15, 0.85, 1.0) | Branca fria (0.85, 0.95, 1) |
| `level_2` | Roxo escuro → horizonte **âmbar** (pôr-do-sol digital) | Linhas **laranja** (1, 0.62, 0.18) | Branca quente (1, 0.92, 0.82) |

Mesma linguagem de cor das sessões online (HOST = âmbar / CLIENTE = ciano — ver [[sistemas/salas]]).

## Componentes (tudo custo ~zero de GPU)

- **`ProceduralSkyMaterial`** (já existia, estava com defaults cinza): `sky_top/horizon_color`,
  `ground_bottom/horizon_color`, `sky_curve 0.12` / `ground_curve 0.08` (banda de horizonte
  apertada). Gradiente matemático — sem textura, sem custo relevante.
- **Fog de distância** (`Environment.fog_enabled`, exponencial): `fog_density 0.01`,
  `fog_light_color` na cor do horizonte, `fog_sky_affect 0.2`. **NÃO é volumetric fog** — o
  volumetric segue desligado por default e controlado pelo Settings (`volumetric_fog`). O fog
  exponencial é por-pixel simples e dá profundidade/atmosfera de graça.
- **Piso-grade neon** — shader compartilhado **`themes/level_grid_floor.gdshader`** (spatial),
  aplicado como `surface_material_override/0` do `MeshInstance3D` do Ground: grade antisserrilhada
  via `fwidth` (linhas menores fracas ×0.45 + linhas maiores fortes a cada `major_every=5` células),
  **EMISSION** pura com **fade por distância** (`fade_distance 55`) que evita moiré no horizonte e
  funde com o fog. Uniforms `base_color`/`line_color` dão a identidade por level. Sem textura.
- **Luz ambiente** do céu (`ambient_light_source = 2`) com tint na cor da cena, energy 0.6.
- **Emissivo × Bloom:** o brilho das linhas é emissivo puro → aparece mesmo com Bloom OFF
  (default). Quando o usuário liga Bloom nas Settings (`config.gd` seta `glow_enabled`), as linhas
  ganham halo neon de graça.

## Por que assim (custo)

Céu procedural + fog exponencial + 1 shader de piso com ~10 operações por pixel: nada disso
adiciona draw calls, texturas ou passes. Alternativas descartadas por custo: volumetric fog
(caro em GPU fraca), HDRI de céu (VRAM), SSAO/SSR (passes extras). Serve de **padrão para
qualquer level futuro**: reutilizar o shader do piso mudando `line_color`/`base_color`.

## Observação de build (2026-07-03)

No rebuild após criar o `.gdshader`, a **1ª exportação falhou** (import do shader novo no meio do
export headless) e a 2ª completou. O `.exe` caiu de **531 MB → 174 MB** porque o **usuário moveu
propositalmente arquivos não usados** que ocupavam espaço à toa no projeto (confirmado por ele em
2026-07-03) — não foi purge de cache. Jogo íntegro (menu, modelos, os 2 levels validados em jogo).
