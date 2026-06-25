shader_type canvas_item;
// Fundo da tela "Configurações": barras de EQUALIZADOR subindo/descendo na base + faixas de
// "slider" ao fundo — evoca ajuste de áudio/vídeo/controles. Barato (math por pixel). Acento
// azul-ciano, base navy igual às outras telas.

uniform vec4 base_color : source_color = vec4(0.043, 0.051, 0.102, 1.0);
uniform vec4 bar_color : source_color = vec4(0.30, 0.78, 1.0, 1.0);
uniform vec4 track_color : source_color = vec4(0.16, 0.40, 0.70, 1.0);
uniform float speed = 1.6;
uniform float bands = 26.0;        // quantas barras de equalizador

void fragment() {
	vec2 uv = UV;
	vec3 col = base_color.rgb;

	// Faixas horizontais de "slider" (trilhos de configuração) ao fundo, com um knob deslizando.
	float rows = 7.0;
	float ry = uv.y * rows;
	float track = smoothstep(0.10, 0.06, abs(fract(ry) - 0.5));       // linha fina no meio da faixa
	col = mix(col, track_color.rgb, track * 0.10);
	float knob_x = 0.5 + 0.42 * sin(TIME * 0.5 + floor(ry) * 1.3);    // knob por faixa
	float knob = smoothstep(0.025, 0.0, abs(uv.x - knob_x)) * smoothstep(0.16, 0.04, abs(fract(ry) - 0.5));
	col += track_color.rgb * knob * 0.6;

	// Barras de equalizador ancoradas na base (a parte "viva" do fundo).
	float bx = uv.x * bands;
	float bi = floor(bx);
	float bf = fract(bx);
	float h = 0.10 + 0.26 * (0.5 + 0.5 * sin(TIME * speed + bi * 0.7) * cos(TIME * 0.6 + bi * 1.7));
	float bar_mask = step(0.16, bf) * step(bf, 0.84);                 // vão entre as barras
	float fill = step(1.0 - h, uv.y) * bar_mask;                     // ancorado embaixo
	float grad = smoothstep(1.0 - h - 0.02, 1.0, uv.y);              // mais forte na base
	col = mix(col, bar_color.rgb, fill * (0.25 + 0.45 * grad));
	// Topo aceso de cada barra.
	float tip = smoothstep(0.02, 0.0, abs(uv.y - (1.0 - h))) * bar_mask;
	col += bar_color.rgb * tip * 0.5;

	COLOR = vec4(col, 1.0);
}
