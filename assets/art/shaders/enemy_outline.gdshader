shader_type canvas_item;

// Outline tegas di sekeliling sprite + flash putih.
// Enteng: 8 texture fetch tetangga, aman buat mobile.

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 0.6);
uniform float outline_size : hint_range(0.0, 4.0) = 1.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * outline_size;

	float n = 0.0;
	n += texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	n += texture(TEXTURE, UV - vec2(px.x, 0.0)).a;
	n += texture(TEXTURE, UV + vec2(0.0, px.y)).a;
	n += texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	n += texture(TEXTURE, UV + px).a;
	n += texture(TEXTURE, UV - px).a;
	n += texture(TEXTURE, UV + vec2(px.x, -px.y)).a;
	n += texture(TEXTURE, UV + vec2(-px.x, px.y)).a;

	// Edge = pixel transparan yang nempel pixel opaque
	float edge = clamp(n, 0.0, 1.0) * (1.0 - tex.a);

	vec3 rgb = mix(tex.rgb, outline_color.rgb, edge * outline_color.a);
	// Flash cuma di pixel opaque
	rgb = mix(rgb, flash_color.rgb, flash_amount * tex.a);

	float a = max(tex.a, edge * outline_color.a);
	COLOR = vec4(rgb, a);
}
