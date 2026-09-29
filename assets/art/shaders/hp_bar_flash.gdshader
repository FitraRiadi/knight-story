shader_type canvas_item;

// Flash putih buat HP bar pas kena damage.
// Full dikontrol dari kode via flash_amount (1 = full putih, 0 = warna normal).

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 col = COLOR;
	col.rgb = mix(col.rgb, flash_color.rgb, flash_amount);
	COLOR = col;
}
