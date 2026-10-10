shader_type canvas_item;

// CardFlameLite: varian RINGAN dari FlameShader buat kartu.
// Api + outline animasi di tepi frame kartu, warna ngikut rarity.
// Budget: 3 ring x 8 sample = 24 texture fetch (aslinya 8x12 = 96),
// noise 1 oktaf. Aman buat 3-5 kartu barengan di mobile.
// Pas intensity/transition ~0, loop di-skip -> cost ~0.

uniform vec4 flame_color : source_color = vec4(0.12, 0.38, 0.68, 1.0);
uniform vec4 outline_color : source_color = vec4(0.027, 0.027, 0.031, 1.0);

uniform float intensity : hint_range(0.0, 1.0) = 0.6;
uniform float transition : hint_range(0.0, 1.0) = 1.0;

uniform float flame_size : hint_range(0.0, 0.2) = 0.055;
uniform float speed : hint_range(0.0, 10.0) = 2.8;

uniform float noise_scale : hint_range(1.0, 30.0) = 10.0;
uniform float upward_bias : hint_range(0.0, 1.0) = 0.6;

varying vec4 modulate_color;

void vertex() {
	modulate_color = COLOR;
}

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

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec4 result = base;

	float gate = intensity * transition;
	if (gate > 0.003) {
		vec2 aspect = vec2(1.0, TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x);
		vec2 noise_uv = UV * noise_scale * vec2(1.0, TEXTURE_PIXEL_SIZE.x / TEXTURE_PIXEL_SIZE.y);
		noise_uv.y += TIME * speed;

		// 1 oktaf aja (asli 2).
		float n = noise(noise_uv);

		float radius = flame_size * gate * (0.4 + n * 0.9);
		vec2 bias = vec2(0.0, radius * upward_bias) * aspect;

		// Lite distance-field: 3 ring x 8 arah (asli 8 x 12).
		// Dua jarak sekaligus: ke opaque (api luar) + ke transparan
		// (lapisan dalam = frame-nya sendiri ikut kebakar).
		float d_op = 99.0;
		float d_tr = 99.0;
		for (int r = 1; r <= 3; r++) {
			float rr = float(r) / 3.0;
			for (int i = 0; i < 8; i++) {
				float ang = float(i) * TAU / 8.0;
				vec2 s = UV + vec2(cos(ang), sin(ang)) * aspect * radius * rr + bias * rr;
				float sa = 0.0;
				if (s.x >= 0.0 && s.x <= 1.0 && s.y >= 0.0 && s.y <= 1.0) {
					sa = texture(TEXTURE, s).a;
				}
				if (sa > 0.5) {
					d_op = min(d_op, rr);
				} else {
					d_tr = min(d_tr, rr);
				}
			}
			if (d_op < 99.0 && d_tr < 99.0) break;
		}

		if (base.a < 0.5) {
			// Api LUAR: pixel transparan yang nempel opaque.
			vec4 fx = vec4(0.0);
			if (d_op <= 0.6) {
				fx = flame_color;
			} else if (d_op <= 1.0) {
				fx = outline_color;
			}
			fx.a *= gate * smoothstep(0.0, 0.25, transition);

			float out_a = base.a + fx.a * (1.0 - base.a);
			vec3 out_rgb = (base.rgb * base.a + fx.rgb * fx.a * (1.0 - base.a)) / max(out_a, 0.0001);
			result = vec4(out_rgb, out_a);
		} else {
			// Lapisan DALAM: tepi opaque yang nempel transparan ikut
			// ketint flame — frame-nya sendiri keliatan kebakar.
			float coat = (1.0 - clamp(d_tr, 0.0, 1.0)) * gate;
			vec3 coated = mix(base.rgb, flame_color.rgb, coat * 0.85);
			// Pulse halus biar api hidup (noise yang sama).
			coated += flame_color.rgb * coat * 0.25 * n;
			result = vec4(coated, base.a);
		}
	}

	COLOR = result * modulate_color;
}
