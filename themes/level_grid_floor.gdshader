shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Piso-grade neon dos levels: grade emissiva BARATA (só matemática por pixel, sem
// texturas — meta do projeto: 60 FPS em hardware gráfico mínimo). As linhas somem
// com a distância (fade) para não gerar moiré nem ruído no horizonte. A identidade
// de cada level vem dos uniforms (Level 1 = ciano, Level 2 = âmbar); o brilho é
// emissivo puro, então funciona sem Bloom e ganha halo de graça quando o usuário
// liga o Bloom nas configurações.
uniform vec3 base_color : source_color = vec3(0.03, 0.05, 0.09);
uniform vec3 line_color : source_color = vec3(0.15, 0.85, 1.0);
uniform float cell_size = 2.0;
uniform float major_every = 5.0;
uniform float emission_strength = 1.6;
uniform float fade_distance = 55.0;
uniform float roughness_value = 0.85;

// Linha antisserrilhada de 1px na borda de cada célula (técnica padrão com fwidth).
float grid_line(vec2 uv) {
	vec2 g = abs(fract(uv - 0.5) - 0.5) / fwidth(uv);
	return 1.0 - min(min(g.x, g.y), 1.0);
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float fade = clamp(1.0 - length(VERTEX) / fade_distance, 0.0, 1.0);
	float minor = grid_line(world_pos.xz / cell_size);
	float major = grid_line(world_pos.xz / (cell_size * major_every));
	float line = max(minor * 0.45, major);
	ALBEDO = base_color;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	EMISSION = line_color * line * fade * emission_strength;
}
