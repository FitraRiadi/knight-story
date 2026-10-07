shader_type canvas_item;

// ============================================================
// TUTORIAL SPOTLIGHT
// Fullscreen overlay:everything di-gelap, kecuali satu lubang
// rounded-rect yang nge-FOLLOW target (tombol/kartu/musuh).
//
// Ngalahin logika spotlight project lo: renderer "mobile" gak
// dukung Light2D sama sekali, jadi spotlight dipalsuin pake
// 1 fullscreen pass. Murah di HP kentang.
//
// Uniform di-set dari TutorialSpotlight.gd tiap frame:
//   spot_center = titik tengah lubang (0..1, UV space)
//   spot_size   = ukuran lubang (px, sudah + padding)
//   dim_amount  = 0..1 seberapa gelap area luar lubang
//   soft_edge   = 0..1 얼마나 lembut transisi tepi
//   pulse       = 0..1 bonus terang di pinggir lubang (denyut)
// ============================================================

uniform vec2 spot_center = vec2(0.5, 0.5);
uniform vec2 spot_size = vec2(100.0, 100.0);
uniform float dim_amount : hint_range(0.0, 1.0) = 0.72;
uniform float corner_r : hint_range(0.0, 64.0) = 12.0;
uniform float soft_edge : hint_range(0.0, 1.0) = 0.10;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// UV delta (0..1) -> pecahan ukuran lubang. SCREEN_PIXEL_SIZE itu
	// 1/resolusi, jadi untuk balik ke pixel DIKALI balik (dibagi):
	//   px = delta_uv * resolusi_px / ukuran_lubang_px.
	// (Sebelumnya kebalik: dikali SCREEN_PIXEL_SIZE/spot_size sehingga
	// px ~= 0 di mana-mana -> outside = 0 -> gelapnya GAK PERNAH muncul.)
	vec2 px = (UV - spot_center) / (SCREEN_PIXEL_SIZE * max(spot_size, vec2(1.0)));
	float r = corner_r / max(min(spot_size.x, spot_size.y), 1.0);

	// Jarak ke rounded-rect (0 = di dalam, 1 = di luar tepi)
	vec2 d = abs(px) - vec2(1.0 - r, 1.0 - r);
	float sd = length(max(d, 0.0)) - r;

	// -1 (dalem) .. 0 (tepi) .. 1 (luar)
	float t = clamp(sd, 0.0, 1.0);
	// smoothstep bikin transisi lembut dari pinggir ke luar
	float outside = smoothstep(0.0, soft_edge, t);

	// Alpha: 0 di dalam lubang -> dim_amount di luar
	float alpha = outside * dim_amount;

	// Cincin tipis terang di pinggir lubang biar mata nempel
	float ring = 1.0 - smoothstep(0.0, soft_edge * 0.9, t);
	float ring_alpha = ring * (0.10 + 0.16 * pulse);

	vec3 col = mix(vec3(0.0, 0.0, 0.0), vec3(1.0, 0.92, 0.65), ring * pulse * 0.35);

	COLOR = vec4(col, clamp(alpha + ring_alpha, 0.0, 1.0));
}
