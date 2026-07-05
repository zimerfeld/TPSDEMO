shader_type canvas_item;
// Fundo da tela "Níveis": um PORTAL girando que "chama" o jogador para entrar — vórtice em espiral,
// anéis de energia sendo puxados para dentro e um núcleo brilhante que pulsa. Cores vibrantes e
// descontraídas (ciano <-> magenta/roxo) cicladas no tempo. Barato de propósito: só matemática por
// pixel, sem texturas, mantendo os 60 FPS mesmo em hardware gráfico mínimo (meta do projeto).

uniform vec4 base_color : source_color = vec4(0.02, 0.015, 0.05, 1.0);
uniform vec4 color_a : source_color = vec4(0.20, 0.85, 1.00, 1.0);    // ciano
uniform vec4 color_b : source_color = vec4(0.85, 0.25, 1.00, 1.0);    // magenta/roxo
uniform vec4 core_color : source_color = vec4(0.95, 0.98, 1.00, 1.0); // núcleo quase branco
uniform float speed = 1.0;
uniform float arms = 5.0;      // braços da espiral do vórtice
uniform float radius = 0.42;   // raio do portal (em unidades de ALTURA de tela)

// Hash 2D barato para a cintilância (partículas de energia).
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

void fragment() {
	// Centraliza e corrige o aspecto para o portal ser REDONDO (1 unidade = altura da tela).
	vec2 p = UV - 0.5;
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;

	float rad = length(p);
	float ang = atan(p.y, p.x);
	float t = TIME * speed;

	// Vórtice: quanto mais perto do centro, mais o ângulo "torce" (sensação de sucção para dentro).
	float twist = ang + (radius - rad) * 7.0 + t * 1.2;

	// Braços da espiral + anéis puxados para o centro (rad + t faz as cristas migrarem para dentro).
	float spiral = 0.5 + 0.5 * sin(twist * arms);
	float rings  = 0.5 + 0.5 * sin(rad * 46.0 + t * 5.0);
	float energy = spiral * rings;

	// Disco do portal (some suave na borda) e núcleo brilhante que "respira".
	float pulse = 0.85 + 0.15 * sin(t * 2.0);
	float disc  = smoothstep(radius * 1.15, radius * 0.15, rad);
	float core  = smoothstep(radius * 0.42 * pulse, 0.0, rad);

	// Cor ciclada no tempo e ao longo do vórtice — sempre mudando, bem descontraído.
	// O multiplicador do ângulo PRECISA ser inteiro: senão, quando atan() "vira" de +PI para -PI no
	// eixo esquerdo, a cor troca de sinal e aparece uma emenda (a "divisão" visível à esquerda).
	vec3 swirl_col = mix(color_a.rgb, color_b.rgb, 0.5 + 0.5 * sin(twist * 2.0 + t * 0.8));

	vec3 col = base_color.rgb;
	col = mix(col, swirl_col, disc * (0.25 + 0.75 * energy));
	col += core_color.rgb * core * 1.4;

	// Anel de borda brilhante (a "boca" do portal) trocando de cor.
	float rim = smoothstep(0.025, 0.0, abs(rad - radius));
	col += mix(color_a.rgb, color_b.rgb, 0.5 + 0.5 * sin(t * 1.5)) * rim * 0.7;

	// Cintilância: partículas de energia orbitando, puxadas para o centro (setor angular x anel).
	// Ângulo normalizado e "enrolado" em 0..1 (fract) para os setores fecharem o círculo sem emenda
	// no eixo esquerdo — assim a borda +PI/-PI vira só mais uma divisa de setor, não uma linha.
	float na = fract(ang / 6.2831853 + 0.5);
	float sparkle = hash(floor(vec2(na * 40.0, rad * 30.0 - t * 3.0)));
	sparkle = step(0.985, sparkle) * disc;
	col += core_color.rgb * sparkle * 0.8;

	// Vinheta escura nas bordas: o portal "salta" no centro e o texto/os botões da UI ficam legíveis.
	col *= smoothstep(1.05, 0.25, rad);

	COLOR = vec4(col, 1.0);
}
