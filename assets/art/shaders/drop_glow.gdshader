shader_type canvas_item;

// Glow emas di sekeliling art item + angkat brightness dikit.
// Dipulse dari code via glow_strength. Enteng: 8 texture fetch.

uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform float glow_strength : hint_range(0.0, 1.0) = 0.6;
uniform float glow_size : hint_range(0.0, 8.0) = 2.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * glow_size;

	float n = 0.0;
	n += texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	n += texture(TEXTURE, UV - vec2(px.x, 0.0)).a;
	n += texture(TEXTURE, UV + vec2(0.0, px.y)).a;
	n += texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	n += texture(TEXTURE, UV + px).a;
	n += texture(TEXTURE, UV - px).a;
	n += texture(TEXTURE, UV + vec2(px.x, -px.y)).a;
	n += texture(TEXTURE, UV + vec2(-px.x, px.y)).a;

	float edge = clamp(n, 0.0, 1.0) * (1.0 - tex.a);

	vec3 rgb = tex.rgb + glow_color.rgb * (edge * glow_strength + tex.a * 0.12 * glow_strength);
	float a = max(tex.a, edge * glow_strength * glow_color.a);
	COLOR = vec4(rgb, a);
}
