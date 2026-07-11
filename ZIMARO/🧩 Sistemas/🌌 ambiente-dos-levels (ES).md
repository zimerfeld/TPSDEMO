---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🌌 Entorno visual de los niveles (cielo + niebla + suelo de rejilla neón)

> Identidad visual cyberpunk de las arenas 3D, implementada el 2026-07-03 con **técnicas baratas**
> (el objetivo del proyecto en `CLAUDE.md`: al menos 60 FPS en hardware gráfico mínimo). Validado en el `.exe`:
> **60 FPS estables** en ambos niveles, incluso en combate. Relacionado: [[🚪 salas (ES)|Salas]],
> [[🧩 templates-de-level (ES)|Plantillas de nivel]], la regla de optimización ([[optimize-when-adding-scene-elements]]).

## Identidad por nivel

| Nivel | Cielo/horizonte | Rejilla del suelo | Luz direccional |
|---|---|---|---|
| `level_1` | Azul marino oscuro → horizonte **turquesa/cian** | Líneas **cian** (0.15, 0.85, 1.0) | Blanco frío (0.85, 0.95, 1) |
| `level_2` | Púrpura oscuro → horizonte **ámbar** (atardecer digital) | Líneas **naranjas** (1, 0.62, 0.18) | Blanco cálido (1, 0.92, 0.82) |

Mismo lenguaje de color que las sesiones en línea (HOST = ámbar / CLIENT = cian — ver [[🚪 salas (ES)|Salas]]).

## Componentes (todo con coste de GPU ~cero)

- **`ProceduralSkyMaterial`** (ya existía, estaba con los grises por defecto): `sky_top/horizon_color`,
  `ground_bottom/horizon_color`, `sky_curve 0.12` / `ground_curve 0.08` (banda de horizonte
  estrecha). Gradiente matemático — sin textura, sin coste relevante.
- **Niebla de distancia** (`Environment.fog_enabled`, exponencial): `fog_density 0.01`,
  `fog_light_color` en el color del horizonte, `fog_sky_affect 0.2`. **NO es niebla volumétrica** — la
  volumétrica queda desactivada por defecto y se controla desde Ajustes (`volumetric_fog`). La niebla
  exponencial es una simple por píxel y da profundidad/atmósfera gratis.
- **Suelo de rejilla neón** — shader compartido **`themes/level_grid_floor.gdshader`** (spatial),
  aplicado como `surface_material_override/0` del `MeshInstance3D` del Ground: una rejilla con antialiasing
  vía `fwidth` (líneas menores más débiles ×0.45 + líneas mayores más fuertes cada `major_every=5` celdas),
  pura **EMISSION** con **fade de distancia** (`fade_distance 55`) que evita el muaré en el horizonte y
  se funde con la niebla. Los uniforms `base_color`/`line_color` dan la identidad por nivel. Sin textura.
- **Luz ambiental** desde el cielo (`ambient_light_source = 2`) tintada con el color de la escena, energy 0.6.
- **Emisivo × Bloom:** el brillo de las líneas es emisivo puro → se muestra incluso con Bloom OFF
  (por defecto). Cuando el usuario activa Bloom en Ajustes (`config.gd` establece `glow_enabled`), las líneas
  ganan un halo neón gratis.

## Por qué así (coste)

Cielo procedural + niebla exponencial + 1 shader de suelo con ~10 operaciones por píxel: nada de eso
añade draw calls, texturas ni pasadas. Alternativas descartadas por coste: niebla volumétrica
(cara en una GPU débil), HDRI de cielo (VRAM), SSAO/SSR (pasadas extra). Sirve como **patrón para
cualquier nivel futuro**: reutilizar el shader del suelo cambiando `line_color`/`base_color`.

## Nota de build (2026-07-03)

En el rebuild tras crear el `.gdshader`, la **1.ª exportación falló** (import del nuevo shader en medio
de la exportación headless) y la 2.ª se completó. El `.exe` bajó de **531 MB → 174 MB** porque el
**usuario movió deliberadamente fuera archivos sin usar** que ocupaban espacio en el proyecto (confirmado por él el
2026-07-03) — no fue una purga de caché. El juego está intacto (menú, models, los 2 niveles validados en el juego).
