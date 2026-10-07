extends Control
class_name TutorialUI

# ============================================================
# TUTORIAL UI
# Panel penjelasan + tombol Continue. Selalu hidup walau tree
# paused (PROCESS_MODE_ALWAYS) karena step machine perlu jalan
# pas game di-freeze.
#
# PANEL ADAPTIF — 3 zona. Layar cuma 740x340 dan banyak elemen
# battle occupy area yang sama (kartu y168-328, QTE bar
# y260-333, charge panel x347-401 full-height, rapid HUD y14-50).
# Jadi panel pindah zona per step, bukan satu posisi statis:
#   ZONE_BOTTOM_LEFT  → default, buat enemy/tombol/parry/drop
#   ZONE_TOP_RIGHT    → buat KARTU & QTE (they eat area bawah)
#   ZONE_TOP_CENTER   → buat INVENTORY (full-screen panel)
#
# Panel juga otomatis NGEHINDAR spotlight: kalau target di sisi
# kiri, panel geser ke kanan, dan sebaliknya — jadi panel gak
# pernah nutup target yang lagi diajarin.
# ============================================================

enum Zone { BOTTOM_LEFT, TOP_RIGHT, TOP_CENTER }

const PANEL_SIZE := Vector2(360.0, 66.0)
const MOVE_TIME := 0.25

## Dipanggil manager waktu player tap layar. Manager yang tau ini
## artinya "lanjut step" atau "aksi yang diNTAHARIN".
signal tapped

var spotlight: TutorialSpotlight = null

var _panel: Panel = null
var _label: RichTextLabel = null
var _hp_note: Label = null
var _continue_btn: Button = null
var _move_tween: Tween = null

# Tap handling: tap di spotlight = aksi, tap di panel = juga boleh dismiss
	# (biar player gak frustrasi kalo panel nutup area yg dia mau tap)
var _dismiss_armed: bool = false
# Kalau panel harus diperkecil biar nutup spotlight target
var _pending_resize: Vector2 = Vector2.ZERO
# Target spotlight baru: di-apply di show_text() SEBELUM panel dipindah,
# biar _avoid_spotlight() ngitung pakai rect yang BENAR (bukan sisa step lalu).
var _pending_spotlight_target: Node = null
var _pending_dim: float = 0.72


func setup(layer: CanvasLayer) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "TutorialUI"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # full IGNORE, lockpsi kita yg pegang
	layer.add_child(self)

	spotlight = TutorialSpotlight.new()
	spotlight.name = "Spotlight"
	add_child(spotlight)

	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # tap tembus ke spotlight
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.09, 0.94)
	sb.border_color = Color(1.0, 0.85, 0.35, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	# RichTextLabel (bukan Label) karena step text pakai **tebal**.
	# Label biasa gak punya bbcode.
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = false
	_label.scroll_active = false
	_label.add_theme_font_size_override("normal_font_size", 15)
	_label.add_theme_font_size_override("bold_font_size", 15)
	_label.add_theme_color_override("default_color", Color(1.0, 0.96, 0.86))
	_label.add_theme_constant_override("outline_size", 5)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = Vector2(12, 10)
	_label.size = PANEL_SIZE - Vector2(24, 20)
	_panel.add_child(_label)

	# Catatan kecil HP protected (step 14-15)
	_hp_note = Label.new()
	_hp_note.text = "Tutorial: HP protected (min 25%)"
	_hp_note.add_theme_font_size_override("font_size", 10)
	_hp_note.add_theme_color_override("font_color", Color(0.75, 0.8, 0.95, 0.95))
	_hp_note.add_theme_constant_override("outline_size", 4)
	_hp_note.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hp_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_note.visible = false
	add_child(_hp_note)

	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.visible = false
	_continue_btn.custom_minimum_size = Vector2(120, 40)
	_continue_btn.add_theme_font_size_override("font_size", 16)
	_continue_btn.pressed.connect(_on_continue_pressed)
	add_child(_continue_btn)

	visible = false


# dismissable: true  = step BACA (tree paused, tap panel buat lanjut)
# dismissable: false = step AKSI (tree jalan, tap TARGET yg di-highlight,
#                        panel HARUS ga nyapot tap-nya)
func show_text(text: String, zone: Zone = Zone.BOTTOM_LEFT, avoid_target: bool = true,
		dismissable: bool = true) -> void:
	_label.text = text
	visible = true
	_dismiss_armed = dismissable
	_continue_btn.visible = false
	_pending_resize = Vector2.ZERO
	# PENTING: set spotlight DULU. _avoid_spotlight() butuh
	# spotlight.visible + get_target_rect() yg valid, jadi urutannya
	# spotlight dulu baru panel. Kalau dibalik, _avoid_spotlight()
	# masih pakai rect step LALU -> panel salah tempat.
	if _pending_spotlight_target:
		spotlight.set_spotlight_target(_pending_spotlight_target, _pending_dim)
		_pending_spotlight_target = null
	var target: Vector2 = _zone_pos(zone)
	if avoid_target and spotlight and spotlight.visible:
		target = _avoid_spotlight(zone, target)
	_move_panel_to(target)
	if _pending_resize != Vector2.ZERO:
		_apply_panel_size(_pending_resize)
	# Fade in halus
	if _panel.modulate.a < 1.0:
		_panel.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func show_final(text: String) -> void:
	# Panel + tombol Continue. Gak ada spotlight action di step terakhir.
	_label.text = text
	visible = true
	_dismiss_armed = false
	if spotlight:
		spotlight.clear_spotlight()
	_move_panel_to(_zone_pos(Zone.TOP_CENTER))
	_continue_btn.visible = true
	_position_continue_btn()
	_panel.modulate.a = 1.0


func hide_panel() -> void:
	visible = false
	_dismiss_armed = false
	_continue_btn.visible = false
	_hp_note.visible = false
	if spotlight:
		spotlight.clear_spotlight()


func set_spotlight_target(node: Node, dim: float = 0.72) -> void:
	# Disimpan dulu, baru di-apply bareng show_text() (lihat catatan
	# di _pending_spotlight_target).
	_pending_spotlight_target = node
	_pending_dim = dim
	if spotlight and visible:
		spotlight.set_spotlight_target(node, dim)
		_pending_spotlight_target = null


func clear_spotlight() -> void:
	if spotlight:
		spotlight.clear_spotlight()


func set_hp_note(shown: bool) -> void:
	_hp_note.visible = shown and visible


func is_dismiss_armed() -> bool:
	return _dismiss_armed


# Dipanggil manager: tap jatuh di spotlight (lubang) = aksi player.
# Kalau step ini "tap to dismiss panel", baru panel disembunyiin.
func try_dismiss_on_tap() -> bool:
	if not _dismiss_armed:
		return false
	hide_panel()
	return true


# ============================================================
# TAP INPUT — node ini PROCESS_MODE_ALWAYS, jadi _input() tetap
# jalan walau tree paused. Ini yang bikin step "baca" (tap panel
# buat lanjut) gak deadlock.
# ============================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Tombol Continue punya alur sendiri (pressed signal).
	if _continue_btn.visible:
		return
	# Step aksi: target yang di-highlight yang harus diklik, JANGAN
	# semua tap diterjemahkan jadi dismiss (nanti player gak bisa
	# tap target-nya karena panel keburu ilang).
	if not _dismiss_armed:
		return
	var tap := false
	if event is InputEventScreenTouch:
		tap = event.pressed
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		tap = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if not tap:
		return
	get_viewport().set_input_as_handled()
	tapped.emit()


func _zone_pos(zone: Zone) -> Vector2:
	var vs := get_viewport_rect().size
	match zone:
		Zone.TOP_RIGHT:
			return Vector2(vs.x - PANEL_SIZE.x - 16, 62)
		Zone.TOP_CENTER:
			return Vector2((vs.x - PANEL_SIZE.x) * 0.5, 14)
		_:
			return Vector2(16, vs.y - PANEL_SIZE.y - 12)


func _avoid_spotlight(zone: Zone, base: Vector2) -> Vector2:
	# Kalau panel & spotlight ada di sisi yg sama, geser ke seberang.
	if not spotlight or not spotlight.visible:
		return base
	var vs := get_viewport_rect().size
	var sr := spotlight.get_target_rect()
	var pr := Rect2(base, PANEL_SIZE)
	if not pr.intersects(sr):
		return base
	# Kandidat posisi. Panel di-resize + geser KALAU masih nabrak,
	# karena di layar 740x340 sometimes gak ada slot 360px yg
	# beneran kosong (musuh di tengah, kartu full bawah).
	var candidates: Array[Vector2] = [
		base,
		Vector2(16, 62),                                              # kiri-atas
		Vector2(vs.x - PANEL_SIZE.x - 16, 62),                       # kanan-atas
		Vector2(16, (vs.y - PANEL_SIZE.y) * 0.5),                    # kiri-tengah
		Vector2(vs.x - PANEL_SIZE.x - 16, (vs.y - PANEL_SIZE.y) * 0.5), # kanan-tengah
		Vector2(16, vs.y - PANEL_SIZE.y - 12),                       # kiri-bawah
		Vector2(vs.x - PANEL_SIZE.x - 16, vs.y - PANEL_SIZE.y - 12),  # kanan-bawah
	]
	for c in candidates:
		if not Rect2(c, PANEL_SIZE).intersects(sr):
			_pending_resize = Vector2.ZERO  # muat penuh, ga perlu shrink
			return c
	# Semua candidate nabrak: KECILIN dulu satu tingkat, cek ulang.
	# (grid scan dislike karena shrink tapi posisinya yg dipake stale)
	for shrink in [Vector2(300.0, 58.0), Vector2(240.0, 48.0), Vector2(180.0, 40.0)]:
		for c in candidates:
			if not Rect2(c, shrink).intersects(sr):
				_pending_resize = shrink
				return c

	# Semua slot kena: scan SELURUH layar dgn kartu shrunk sampai muat.
	# Layar 740x340 itu sempit, jadi satu-satunya cara pasti ialah brute
	# force grid scan— bukan cuma 7 titik tetap.
	var vs2 := get_viewport_rect().size
	var widths: Array[float] = [PANEL_SIZE.x, 300.0, 260.0, 220.0, 180.0, 150.0, 120.0]
	var heights: Array[float] = [PANEL_SIZE.y, 58.0, 52.0, 46.0, 40.0, 34.0, 28.0]
	var step_x: float = 10.0
	var step_y: float = 8.0
	# Scan dari ATAS dulu: spotlight di battle ini loves duduk rendah
	# (tombol interaction y~215-270, kartu y~168-328), jadi slot atas
	# hampir selalu free. Scan bawah-dulu dulu ngambil slot yg cuma
	# "nempel harmlessly" tapi masih kena pinggir lubang.
	for w in widths:
		for h in heights:
			var y: float = 4.0
			while y <= vs2.y - h - 4.0:
				var x: float = 4.0
				while x <= vs2.x - w - 4.0:
					if not Rect2(Vector2(x, y), Vector2(w, h)).intersects(sr):
						_pending_resize = Vector2(w, h)
						return Vector2(x, y)
					x += step_x
				y += step_y
	# benar2 gak ada ruang sama sekali: perkecil terus dgn margin 0
	_pending_resize = Vector2(120.0, 28.0)
	return Vector2(4.0, 4.0)


func _apply_panel_size(sz: Vector2) -> void:
	_panel.size = sz
	_label.size = sz - Vector2(24, 20)
	_pending_resize = Vector2.ZERO


func _move_panel_to(target: Vector2) -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(_panel, "position", target, MOVE_TIME)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# JANGAN ikutin ngermin _label: dia child _panel, jadi position-nya
	# RELATIF ke panel. Kalau ikut ke target+offset, text-nya ketarik
	# 2x offset dan keluar dari panel (teks jadi gak keliatan).
	_label.position = Vector2(12, 10)


func _position_continue_btn() -> void:
	var vs := get_viewport_rect().size
	_continue_btn.position = Vector2(
		(vs.x - _continue_btn.custom_minimum_size.x) * 0.5,
		vs.y - _continue_btn.custom_minimum_size.y - 20
	)


func _on_continue_pressed() -> void:
	_hide_dismiss_arm()
	hide_panel()


func _hide_dismiss_arm() -> void:
	_dismiss_armed = false
