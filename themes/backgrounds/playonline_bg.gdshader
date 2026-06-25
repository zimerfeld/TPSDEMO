shader_type canvas_item;
// Fundo da tela "Jogar Online": malha de rede SUTIL (nós + linhas finas, identidade "online")
// que aparece só nas BORDAS — o CENTRO fica calmo (navy) para o formulário (Porta/IP/botões) ficar
// bem legível. Limpo e discreto, no estilo das outras telas. Barato (math por pixel, sem texturas).

uniform vec4 base_color : source_color = vec4(0.043, 0.051, 0.102, 1.0);
uniform vec4 net_color : source_color = vec4(0.22, 0.58, 0.90, 1.0);
uniform float speed = 0.45;
uniform float cells = 9.0;     // densidade da malha

void fragment() {
	vec2 uv = UV;
	vec3 col = base_color.rgb;

	vec2 p = uv;
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;   // células quadradas (independe da resolução)
	vec2 g = p * cells;
	vec2 id = floor(g);
	vec2 cell = fract(g) - 0.5;
	vec2 gl = abs(cell);

	float edge = smoothstep(0.49, 0.5, max(gl.x, gl.y));     // linhas finas da malha (bem fracas)
	float d = length(cell);
	float pulse = 0.5 + 0.5 * sin(TIME * speed - (id.x + id.y) * 0.7);
	float node = smoothstep(0.09, 0.0, d) * pulse;          // nós pequenos pulsando devagar

	// Centro CALMO: a rede só "acende" longe do meio → o formulário central fica legível.
	float dist = length(uv - vec2(0.5));
	float mask = smoothstep(0.30, 0.72, dist);

	float net = (edge * 0.45 + node * 0.8) * mask;
	col += net_color.rgb * net * 0.5;

	// Brilho radial muito suave nas bordas (beleza, sem poluir o centro).
	col += net_color.rgb * smoothstep(0.5, 0.95, dist) * 0.05;

	COLOR = vec4(col, 1.0);
}
