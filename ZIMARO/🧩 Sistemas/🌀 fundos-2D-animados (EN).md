---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-05
---

# 🌀 Animated 2D screen backgrounds (portal/vortex shaders)

> Every 2D UI screen has its own animated background made purely from **per-pixel math** (no
> texture, no extra draw call) to honor the **60 FPS on minimum graphics hardware** target
> (`CLAUDE.md`). They are `ColorRect`s on a background `CanvasLayer` (`layer = -2`) with a
> `ShaderMaterial`. Not to be confused with [[🌌 ambiente-dos-levels]], which is the **3D**
> environment inside the arenas.

## Shaders (folder `themes/backgrounds/`)

| Screen | Shader | Identity |
|---|---|---|
| Levels (`levels`) | `levels_bg.gdshader` | Spiral portal/vortex, cyan ↔ magenta, pulsing core |
| Developer | `developer_bg.gdshader` | — |
| Play Online | `playonline_bg.gdshader` | — |
| Settings | `settings_bg.gdshader` | — |

## ⚠️ Golden rule: the `atan()` seam on the left axis

Radial/polar backgrounds use `atan(p.y, p.x)` for the angle. That function **wraps from +π to −π
along the horizontal left axis** (negative x, y≈0). Any angle-dependent term that is **not periodic
in 2π** flips value abruptly there → a **visible line/seam** only on the left (the right never seams
because it doesn't cross the wrap).

**How to avoid it:**
- The angle multiplier inside `sin()`/`cos()` must be an **integer** (e.g. `sin(twist * 2.0)` closes
  the cycle across the wrap; `sin(twist * 1.5)` flips sign and seams).
- Angular sectors (`floor(ang * N)`, noise/sparkle) must use the **normalized, wrapped** angle:
  `fract(ang / 6.2831853 + 0.5)`. Then the ±π edge becomes just another sector boundary, not a
  continuous radial line.

## Fix applied to `levels_bg` (2026-07-05)

The user noticed a perceptible "division" on the left of the portal. Two causes, both the seam above:
1. **Vortex color** used `sin(twist * 1.5 + …)` → non-integer multiplier. Changed to `* 2.0` (this
   was the strong line). The spiral arms were already immune via `arms = 5.0` (integer).
2. **Sparkle** used `floor(ang * 20.0, …)` → sectors didn't close the circle. Switched to
   `na = fract(ang / 6.2831853 + 0.5)` and `floor(na * 40.0, …)`.

Result: left side as seamless as the right, **60 FPS** kept, validated in the `.exe`.
Related: [[🎬 fluxo-de-cenas]] (Levels screen sits in chooseplayer→levels→level_x),
[[optimize-when-adding-scene-elements]].
