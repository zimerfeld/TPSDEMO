shader_type canvas_item;
// Anéis concêntricos de "radar/sinal" emanando do centro — diferenciador das telas online.
//   dir = +1  → anéis EXPANDEM para fora  (HOST: o servidor TRANSMITE / é a fonte)
//   dir = -1  → anéis CONTRAEM para dentro (CLIENTE: CONECTA-SE ao servidor)
// A cor (ring_color) dá a identidade: host = quente (âmbar), cliente = fria (ciano).
// Barato (math por pixel) — roda numa tela de menu sem custo relevante.

uniform vec4 ring_color : source_color = vec4(1.0, 0.6, 0.15, 1.0);
uniform float dir = 1.0;        // +1 host (expande) / -1 cliente (contrai)
uniform float aspect = 1.7777;  // largura/altura → anéis circulares (setado em código)
uniform float speed = 0.16;
uniform float density = 7.0;    // quantos anéis pela tela
uniform float intensity = 0.32;

void fragment() {
	vec2 p = UV - vec2(0.5);
	p.x *= aspect;                                   // corrige proporção → círculos, não elipses
	float d = length(p);
	float phase = d * density - TIME * speed * dir;
	float ring = abs(fract(phase) * 2.0 - 1.0);      // onda triangular 0..1 (picos = anéis)
	float line = smoothstep(0.88, 1.0, ring);        // linhas finas (acento, não dominante)
	float fade = smoothstep(1.05, 0.12, d);          // forte no centro, some nas bordas
	COLOR = vec4(ring_color.rgb, line * fade * intensity * ring_color.a);
}
