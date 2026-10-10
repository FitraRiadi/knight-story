shader_type canvas_item;

// CardFlame: FlameShader 1:1 (loop 8x12, noise 2 oktaf, uniform sama)
// dipasang di frame kartu. SATU tambahan: gate jendela art — pixel
// transparan yang posisinya di DALAM badan kartu (jendela art tengah)
// di-skip, biar api cuma di keliling LUAR kayak maunya. Tanpa gate ini
// api nongol ngelilingin art (masalah versi silhouette dulu).

uniform float transition : hint_range(0.0, 1.0) = 1.0;

uniform vec4 flame_color : source_color = vec4(0.537, 0.890, 0.882, 1.0);
uniform vec4 outline_color : source_color = vec4(0.027, 0.027, 0.031, 1.0);

uniform float flame_percent : hint_range(0.0, 100.0) = 50.0;
uniform float outline_percent : hint_range(0.0, 100.0) = 50.0;

uniform float flame_size : hint_range(0.0, 0.2) = 0.05;
uniform float speed : hint_range(0.0, 10.0) = 4.0;

uniform float shrink_factor : hint_range(0.5, 1.0) = 1.0;
uniform float noise_scale : hint_range(1.0, 30.0) = 10.0;
uniform float upward_bias : hint_range(0.0, 1.0) = 0.6;

// Gate jendela: ukuran kartu px + radius sudut px + tebal border px.
uniform vec2 card_px = vec2(110.0, 160.0);
uniform float corner_px : hint_range(0.0, 32.0) = 5.0;
uniform float border_px : hint_range(0.0, 32.0) = 6.0;

varying vec4 modulate_color;

void vertex() {
	modulate_color = COLOR;
}

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * .1031);
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
	vec2 uv = (UV - 0.5) / shrink_factor + 0.5;

	vec4 base = vec4(0.0);
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		base = texture(TEXTURE, uv);
	}

	vec4 result = base;

	// Gate: transparan di dalam badan kartu = jendela art -> steril.
	vec2 gsp = (UV - vec2(0.5)) * card_px;
	float gd = sd_round_box(gsp, card_px * 0.5, corner_px);
	bool window_px = base.a < 0.5 && gd < -border_px;

	if (transition > 0.001 && !window_px) {
		vec2 aspect = vec2(1.0, TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x);

		vec2 noise_uv = uv * noise_scale * vec2(1.0, TEXTURE_PIXEL_SIZE.x / TEXTURE_PIXEL_SIZE.y);

		noise_uv.y += TIME * speed;

		float n = noise(noise_uv) * 0.6 + noise(noise_uv * 2.0) * 0.4;

		float radius = flame_size * transition * (0.4 + n * 0.9);

		vec2 bias = vec2(0.0, radius * upward_bias) * aspect;

		// Inline (TANPA oper TEXTURE ke fungsi — pola sampler2D sbg
		// parameter broken di Godot 4: sampling balikin 0 -> api mati).
		// Logika 1:1 FlameShader: 8 ring x 12 arah.
		float d = 99.0;
		for (int r = 1; r <= 8; r++) {
			float rr = float(r) / 8.0;
			for (int i = 0; i < 12; i++) {
				float ang = float(i) * TAU / 12.0;
				vec2 s = uv + vec2(cos(ang), sin(ang)) * aspect * radius * rr + bias * rr;
				float sa = 0.0;
				if (s.x >= 0.0 && s.x <= 1.0 && s.y >= 0.0 && s.y <= 1.0) {
					sa = texture(TEXTURE, s).a;
				}
				if (sa > 0.5) {
					d = min(d, rr);
				}
			}
			if (d < 99.0) break;
		}

		float total = flame_percent + outline_percent;
		float flame_edge = total > 0.0001 ? flame_percent / total : 0.5;

		vec4 fx = vec4(0.0);
		if (d <= flame_edge) {
			fx = flame_color;
		} else if (d <= 1.0) {
			fx = outline_color;
		}

		fx.a *= smoothstep(0.0, 0.25, transition);

		float out_a = base.a + fx.a * (1.0 - base.a);
		vec3 out_rgb = (base.rgb * base.a + fx.rgb * fx.a * (1.0 - base.a)) / max(out_a, 0.0001);
		result = vec4(out_rgb, out_a);
	}

	COLOR = result * modulate_color;
}
