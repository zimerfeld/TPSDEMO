shader_type canvas_item;
// Fundo da tela "Modo Developer": grade de blueprint (fina + grossa) com células de dados
// piscando e uma varredura horizontal — vibe de terminal/depurador. Barato (math por pixel).
// Acento verde-ciano (identidade "técnica/dev"), distinto das demais telas.

uniform vec4 base_color : source_color = vec4(0.043, 0.051, 0.102, 1.0);
uniform vec4 grid_color : source_color = vec4(0.20, 0.92, 0.62, 1.0);
uniform float speed = 0.25;        // velocidade da varredura

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = base_color.rgb;

	// Grade fina.
	vec2 gf = abs(fract(uv * vec2(64.0, 36.0)) - 0.5);
	float fine = smoothstep(0.48, 0.5, max(gf.x, gf.y));
	col = mix(col, grid_color.rgb, fine * 0.06);

	// Grade grossa (blueprint).
	vec2 G = uv * vec2(12.0, 7.0);
	vec2 gc = abs(fract(G) - 0.5);
	float coarse = smoothstep(0.46, 0.5, max(gc.x, gc.y));
	col = mix(col, grid_color.rgb, coarse * 0.14);

	// Células de "dados" piscando (algumas células da grade grossa acendem por instantes).
	vec2 cid = floor(G);
	float blink = step(0.93, hash(cid + floor(vec2(TIME * 1.3, TIME * 0.7))));
	col += grid_color.rgb * blink * 0.16;

	// Varredura horizontal (linha de scan subindo).
	float scan = fract(uv.y + TIME * speed);
	float sweep = smoothstep(0.0, 0.02, scan) * smoothstep(0.09, 0.0, scan);
	col += grid_color.rgb * sweep * 0.16;

	COLOR = vec4(col, 1.0);
}
