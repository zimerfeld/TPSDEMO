shader_type canvas_item;
// Fundo da tela "Níveis": grade em perspectiva correndo até o horizonte — vibe de "seleção de
// fase / entrar no nível". Barato (math por pixel, sem texturas) → roda numa tela de menu sem
// custo relevante. Base navy igual às outras telas; acento azul.

uniform vec4 base_color : source_color = vec4(0.043, 0.051, 0.102, 1.0);
uniform vec4 grid_color : source_color = vec4(0.25, 0.60, 1.0, 1.0);
uniform float speed = 0.30;        // velocidade das linhas transversais correndo p/ o jogador
uniform float horizon = 0.45;      // altura do horizonte (0 = topo, 1 = base)

void fragment() {
	vec2 uv = UV;
	vec3 col = base_color.rgb;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;  // corrige células quadradas

	if (uv.y > horizon) {
		// Projeção do "chão": perto do horizonte fica comprimido (longe), embaixo se abre (perto).
		float depth = (uv.y - horizon) / (1.0 - horizon);     // 0 no horizonte → 1 na base
		float dd = max(depth, 0.02);
		float z = 0.15 / dd;                                  // posição ao longo do chão
		float xx = (uv.x - 0.5) / dd * aspect;                // linhas longitudinais convergindo

		float rows = abs(fract(z * 1.5 + TIME * speed) - 0.5);   // transversais correndo
		float cols = abs(fract(xx * 1.5) - 0.5);                 // longitudinais
		float line = max(smoothstep(0.46, 0.5, 1.0 - rows), smoothstep(0.46, 0.5, 1.0 - cols));
		col = mix(col, grid_color.rgb, line * depth * 0.6);      // some perto do horizonte
	}

	// Brilho do horizonte (linha de luz onde o chão encontra o céu).
	float glow = smoothstep(0.07, 0.0, abs(uv.y - horizon));
	col += grid_color.rgb * glow * 0.30;
	// Leve gradiente do céu (mais escuro no topo).
	col += grid_color.rgb * smoothstep(horizon, 0.0, uv.y) * 0.04;

	COLOR = vec4(col, 1.0);
}
