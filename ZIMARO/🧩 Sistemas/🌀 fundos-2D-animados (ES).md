---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-05
---

# 🌀 Fondos animados de las pantallas 2D (shaders de portal/vórtice)

> 🇧🇷 Ler em português → [[🌀 fundos-2D-animados]]

> Cada pantalla de UI 2D tiene su propio fondo animado hecho puramente con **matemática por píxel** (sin
> textura, sin draw call extra) para honrar el objetivo de **60 FPS en hardware gráfico mínimo**
> (`CLAUDE.md`). Son `ColorRect` sobre un `CanvasLayer` de fondo (`layer = -2`) con un
> `ShaderMaterial`. No confundir con [[🌌 ambiente-dos-levels]], que es el entorno **3D**
> dentro de las arenas.

## Shaders (carpeta `themes/backgrounds/`)

| Pantalla | Shader | Identidad |
|---|---|---|
| Levels (`levels`) | `levels_bg.gdshader` | Portal/vórtice en espiral, cian ↔ magenta, núcleo palpitante |
| Developer | `developer_bg.gdshader` | — |
| Play Online | `playonline_bg.gdshader` | — |
| Settings | `settings_bg.gdshader` | — |

## ⚠️ Regla de oro: la costura de `atan()` en el eje izquierdo

Los fondos radiales/polares usan `atan(p.y, p.x)` para el ángulo. Esa función **da la vuelta de +π a −π
a lo largo del eje horizontal izquierdo** (x negativa, y≈0). Cualquier término dependiente del ángulo que **no sea periódico
en 2π** cambia de valor bruscamente ahí → una **línea/costura visible** solo en la izquierda (la derecha nunca genera costura
porque no cruza la vuelta).

**Cómo evitarlo:**
- El multiplicador de ángulo dentro de `sin()`/`cos()` debe ser un **entero** (p. ej. `sin(twist * 2.0)` cierra
  el ciclo a través de la vuelta; `sin(twist * 1.5)` invierte el signo y genera costura).
- Los sectores angulares (`floor(ang * N)`, ruido/destello) deben usar el ángulo **normalizado y envuelto**:
  `fract(ang / 6.2831853 + 0.5)`. Entonces el borde ±π pasa a ser solo otro límite de sector, no una
  línea radial continua.

## Corrección aplicada a `levels_bg` (2026-07-05)

El usuario notó una "división" perceptible a la izquierda del portal. Dos causas, ambas la costura de arriba:
1. **Color del vórtice** usaba `sin(twist * 1.5 + …)` → multiplicador no entero. Cambiado a `* 2.0` (esta
   era la línea fuerte). Los brazos de la espiral ya eran inmunes vía `arms = 5.0` (entero).
2. **Destello** usaba `floor(ang * 20.0, …)` → los sectores no cerraban el círculo. Cambiado a
   `na = fract(ang / 6.2831853 + 0.5)` y `floor(na * 40.0, …)`.

Resultado: lado izquierdo tan continuo como el derecho, **60 FPS** mantenidos, validado en el `.exe`.
Relacionado: [[🎬 fluxo-de-cenas]] (la pantalla Levels está en chooseplayer→levels→level_x),
[[optimize-when-adding-scene-elements]].
