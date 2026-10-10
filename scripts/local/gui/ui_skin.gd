class_name UISkin
extends RefCounted

# ============================================================
# UI SKIN — helper terpusat buat skin UI pakai art Kenney
# (fantasy-ui-borders, CC0). Satu tempat ganti skin seluruh game.
#
# Pola (ngikutin Sample Kenney):
#   - Panel hero  : fill gelap (Flat) + overlay border putih 9-slice
#   - Row / kartu : single StyleBoxTexture (frame putih, tengah
#                   transparan nunjukin fill parent)
#   - Tombol      : StyleBoxTexture terang + teks gelap (kayak
#                   tombol "Accept quest" di Sample)
#
# Art: 48x48 white, margin NinePatch 12 (corner hias ~10px).
# ============================================================

const PANEL_ART := "res://assets/tilesets/kenney_fantasy-ui-borders/PNG/Default/Border/panel-border-020.png"
const TEX_MARGIN := 12.0

# Palette (dark serious, ngikutin Sample).
const FILL_MAIN := Color(0.07, 0.08, 0.12, 0.96)
const BTN_TEXT := Color(0.12, 0.09, 0.06)
const BTN_HOVER_MOD := Color(1.0, 0.95, 0.8)
const BTN_PRESS_MOD := Color(0.72, 0.68, 0.62)


static func _art() -> Texture2D:
	if not ResourceLoader.exists(PANEL_ART):
		push_warning("[UISkin] art hilang: " + PANEL_ART)
		return null
	return load(PANEL_ART) as Texture2D


# Fill gelap polos (lapis bawah panel hero).
static func fill(color: Color = FILL_MAIN) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	return s


# StyleBoxTexture 9-slice putih (frame). content_* opsional biar
# layout lama nggak geser.
static func frame_box(content_ltrb: Array = []) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = _art()
	s.texture_margin_left = TEX_MARGIN
	s.texture_margin_right = TEX_MARGIN
	s.texture_margin_top = TEX_MARGIN
	s.texture_margin_bottom = TEX_MARGIN
	if content_ltrb.size() == 4:
		s.content_margin_left = content_ltrb[0]
		s.content_margin_top = content_ltrb[1]
		s.content_margin_right = content_ltrb[2]
		s.content_margin_bottom = content_ltrb[3]
	return s


# Tempel border overlay di atas panel (fill + frame = look Sample).
# Overlay mouse-ignore + full-rect, aman buat Panel biasa maupun
# manual-position. JANGAN dipakai di dalam Container (merusak layout).
static func frame(parent: Control) -> void:
	if parent == null:
		return
	var b := Panel.new()
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("panel", frame_box())
	parent.add_child(b)
	# Pastikan overlay paling atas.
	parent.move_child(b, parent.get_child_count() - 1)


# --- Tombol: flat warna asli + overlay frame putih ---
# (StyleBoxTexture NGGAK punya modulate di Godot 4 — jadi state
# dibedain via warna flat, frame-nya sama. Proven aman.)

static func apply_button(btn: Button, font_size: int, normal_col: Color, hover_col: Color, font_col: Color) -> void:
	if btn == null:
		return
	var n := StyleBoxFlat.new()
	n.bg_color = normal_col
	n.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", n)
	var h := StyleBoxFlat.new()
	h.bg_color = hover_col
	h.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", font_col)
	frame(btn)
