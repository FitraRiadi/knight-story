shader_type canvas_item;

// CardFlameLite: tint api di BORDER kartu (pita tepi luar), warna rarity.
// Prosedural penuh (rounded-box SDF): NOL texture fetch, jauh lebih murah
// dari versi silhouette. Jendela art di tengah STERIL — cuma border yang
// kena. Pasangan: CardFlameHalo (underlay api luar, biar gak kepotong).

uniform vec4 flame_color : source_color = vec4(0.12, 0.38, 0.68, 1.0);

uniform float intensity : hint_range(0.0, 1.0) = 0.6;
uniform float transition : hint_range(0.0, 1.0) = 1.0;

// Lebar pita tint = flame_size * 0.35 (rarity-scaled dari GDScript).
uniform float flame_size : hint_range(0.0, 0.2) = 0.11;
uniform float speed : hint_range(0.0, 10.0) = 2.8;

varying vec4 modulate_color;

void vertex() {
	modulate_color = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec4 result = base;

	float gate = intensity * transition;
	if (gate > 0.003 && base.a > 0.5) {
		// Jarak ke tepi rect (UV). Sudut membulat art gak masalah:
		// yang transparan diskip via base.a, yang opaque di pita kena.
		float edge_d = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
		float coat = flame_size * 0.6;
		float band = 1.0 - smoothstep(0.0, coat, edge_d);
		if (band > 0.003) {
			// Pulse hidup: gelombang jalan keliling border.
			float wave = 0.75 + 0.25 * sin(TIME * speed + (UV.x + UV.y) * 12.56);
			float k = band * gate * wave;
			vec3 coated = mix(base.rgb, flame_color.rgb, k * 0.85);
			coated += flame_color.rgb * k * 0.20;
			result = vec4(coated, base.a);
		}
	}

	COLOR = result * modulate_color;
}
