---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🌌 Visual environment of the levels (sky + fog + neon grid floor)

> Cyberpunk visual identity of the 3D arenas, implemented on 2026-07-03 with **cheap techniques**
> (the project goal in `CLAUDE.md`: at least 60 FPS on minimal graphics hardware). Validated on the `.exe`:
> **a solid 60 FPS** in both levels, including in combat. Related: [[🚪 salas (EN)|Rooms]],
> [[🧩 templates-de-level (EN)|Level Templates]], the optimization rule ([[optimize-when-adding-scene-elements]]).

## Identity per level

| Level | Sky/horizon | Floor grid | Directional light |
|---|---|---|---|
| `level_1` | Dark navy → **teal/cyan** horizon | **Cyan** lines (0.15, 0.85, 1.0) | Cool white (0.85, 0.95, 1) |
| `level_2` | Dark purple → **amber** horizon (digital sunset) | **Orange** lines (1, 0.62, 0.18) | Warm white (1, 0.92, 0.82) |

Same color language as the online sessions (HOST = amber / CLIENT = cyan — see [[🚪 salas (EN)|Rooms]]).

## Components (everything ~zero GPU cost)

- **`ProceduralSkyMaterial`** (already existed, was set to gray defaults): `sky_top/horizon_color`,
  `ground_bottom/horizon_color`, `sky_curve 0.12` / `ground_curve 0.08` (tight horizon
  band). Mathematical gradient — no texture, no relevant cost.
- **Distance fog** (`Environment.fog_enabled`, exponential): `fog_density 0.01`,
  `fog_light_color` in the horizon color, `fog_sky_affect 0.2`. **It is NOT volumetric fog** — the
  volumetric one stays off by default and is controlled by Settings (`volumetric_fog`). The exponential
  fog is a simple per-pixel one and gives depth/atmosphere for free.
- **Neon grid floor** — shared shader **`themes/level_grid_floor.gdshader`** (spatial),
  applied as `surface_material_override/0` of the Ground's `MeshInstance3D`: an antialiased grid
  via `fwidth` (weaker minor lines ×0.45 + stronger major lines every `major_every=5` cells),
  pure **EMISSION** with **distance fade** (`fade_distance 55`) that avoids moiré at the horizon and
  blends with the fog. The `base_color`/`line_color` uniforms give the per-level identity. No texture.
- **Ambient light** from the sky (`ambient_light_source = 2`) tinted with the scene color, energy 0.6.
- **Emissive × Bloom:** the line glow is pure emissive → it shows even with Bloom OFF
  (default). When the user turns Bloom on in Settings (`config.gd` sets `glow_enabled`), the lines
  gain a neon halo for free.

## Why like this (cost)

Procedural sky + exponential fog + 1 floor shader with ~10 operations per pixel: none of it
adds draw calls, textures or passes. Alternatives discarded for cost: volumetric fog
(expensive on a weak GPU), sky HDRI (VRAM), SSAO/SSR (extra passes). It serves as a **pattern for
any future level**: reuse the floor shader changing `line_color`/`base_color`.

## Build note (2026-07-03)

On the rebuild after creating the `.gdshader`, the **1st export failed** (import of the new shader in the
middle of the headless export) and the 2nd completed. The `.exe` dropped from **531 MB → 174 MB** because the
**user deliberately moved out unused files** that were taking up space in the project (confirmed by him on
2026-07-03) — it was not a cache purge. The game is intact (menu, models, the 2 levels validated in-game).
