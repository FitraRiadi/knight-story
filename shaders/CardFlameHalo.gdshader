shader_type canvas_item;

// CardFlameHalo: api LUAR keliling kartu. Dipasang di ColorRect underlay
// (child kartu paling belakang, rect lebih gede dari kartu biar api gak
// kepotong tepi). Prosedural penuh (rounded-box SDF + noise): NOL texture
// fetch. Pasangan: CardFlameLite (tint border di frame-nya).

uniform vec4 flame_color : source_color = vec4(0.12, 0.38, 0.68, 1.0);
uniform vec4 outline_color : source_color = vec4(0.027, 0.027, 0.031, 1.0);

uniform float intensity : hint_range(0.0, 1.0) = 0.6;
uniform float transition : hint_range(0.0, 1.0) = 1.0;

uniform float speed : hint_range(0.0, 10.0) = 2.8;
uniform float noise_scale : hint_range(1.0, 30.0) = 6.0;
uniform float upward_bias : hint_range(0.0, 1.0) = 0.6;

// Batas kartu dalam UV halo (x0,y0,x1,y1). Diisi dari GDScript.
uniform vec4 inner_rect = vec4(0.1, 0.1, 0.9, 0.9);
// Ukuran kartu px (110x160) + radius sudut px + jangkauan api px.
uniform vec2 card_px = vec2(110.0, 160.0);
uniform float corner_px : hint_range(0.0, 32.0) = 8.0;
uniform float reach_px : hint_range(0.0, 64.0) = 18.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 x) {
	vec2 p = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(p + vec2(0.0, 0.0)), hash(p + vec2(1.0, 0.0)), f.x),
			mix(hash(p + vec2(0.0, 1.0)), hash(p + vec2(1.0, 1.0)), f.x), f.y);
}

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec4 out_col = vec4(0.0);
	float gate = intensity * transition;
	if (gate >= 0.003) {
		// UV halo -> UV kartu (0..1 di area kartu) -> px relatif tengah.
		vec2 cuv = (UV - inner_rect.xy) / max(inner_rect.zw - inner_rect.xy, vec2(0.0001));
		vec2 sp = (cuv - vec2(0.5)) * card_px;
		float d = sd_round_box(sp, card_px * 0.5, corner_px);

		// Api cuma di LUAR kartu (d > 0). Dalam kartu = transparan total
		// (frame-nya yang ngomong via CardFlameLite).
		if (d >= 0.0) {
			// Jilatan: noise 1 oktaf + bias ke atas (api naik).
			float n = noise(cuv * noise_scale + vec2(0.0, -TIME * speed * 0.35));
			float n2 = noise(cuv * noise_scale * 2.3 + vec2(3.7, -TIME * speed * 0.6));
			float wob = (n * 0.65 + n2 * 0.35 - 0.5) * reach_px * 0.9;
			float reach = reach_px * (1.0 + upward_bias * (0.5 - cuv.y) * 1.6);
			// Nempel frame: wobble 0 di akar (d=0 -> api full), makin liar
			// ke luar. Biar gak ada ruang bolong antara frame dan api.
			float hug = smoothstep(0.0, max(reach, 0.001) * 0.6, d);
			float t = 1.0 - smoothstep(0.0, max(reach, 0.001), d + wob * hug);
			if (t > 0.003) {
				// Inti terang -> ekor gelap (outline_color).
				vec3 col = mix(outline_color.rgb, flame_color.rgb, smoothstep(0.0, 0.55, t));
				col = mix(col, vec3(1.0, 0.95, 0.85), pow(t, 3.0) * 0.35 * gate);
				float a = t * gate * smoothstep(0.0, 0.25, transition);
				out_col = vec4(col, a);
			}
		}
	}
	COLOR = out_col;
}
