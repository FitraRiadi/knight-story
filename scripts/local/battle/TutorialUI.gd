extends Control
class_name TutorialUI

# ============================================================
# TUTORIAL UI
# Panel-nya PAKAI DESAIN SCENE (tutorialPanel di
# battle_gameplay_tutorial.tscn): Panel + title + info + badge
# "STEP k / N". Script ini cuma ngisi teks, mindahin posisi,
# ngatur show/hide, dan mainin intro stagger. Gak bikin panel
# manual lagi.
#
# ZONA — layar 740x340 sempit, jadi panel pindah zona per step:
#   BOTTOM_LEFT → default (musuh/tombol/parry/drop)
#   TOP_RIGHT   → kartu & QTE (area bawah penuh)
#   TOP_CENTER  → inventory (panel fullscreen)
# Panel juga otomatis NGEHINDAR spotlight biar gak nutup target.
# ============================================================

enum Zone { BOTTOM_LEFT, TOP_RIGHT, TOP_CENTER }

const MOVE_TIME := 0.25

## Dipanggil manager waktu player tap layar.
signal tapped
## Dipencet tombol Continue di step terakhir.
signal finished

var spotlight: TutorialSpotlight = null

var _panel: Panel = null
var _title: Label = null
var _info: Label = null
var _step_badge: Label = null
var _panel_size := Vector2(272.0, 99.0)
var _panel_dest := Vector2.ZERO
# Posisi "rumah" (dari scene) buat animasi slide-in stagger.
var _title_home := Vector2.ZERO
var _info_home := Vector2.ZERO
var _badge_home := Vector2.ZERO
var _hp_note: Label = null
var _continue_btn: Button = null
var _move_tween: Tween = null
var _intro_tween: Tween = null

var _dismiss_armed: bool = false
# Target spotlight baru: di-apply SEBELUM panel dipindah biar
# _avoid_spotlight() ngitung pakai rect yang BENAR.
var _pending_spotlight_target: Node = null
var _pending_has_target: bool = false
var _pending_dim: float = 0.78


func setup(layer: CanvasLayer, panel: Panel) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "TutorialUI"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(self)

	spotlight = TutorialSpotlight.new()
	spotlight.name = "Spotlight"
	add_child(spotlight)

	# Panel scene DIPINDAH ke layer tutorial (300): biar SELALU paling
	# atas — di atas deck kartu (165), QTE (155), parry/rapid (150) —
	# dan di atas spotlight (gelap) itu sendiri. Urutan anak di sini:
	# spotlight, panel, hp_note, continue. Koordinat panel tetap
	# viewport-space (layer 300 identity), posisi di-set tiap show.
	if panel == null or not is_instance_valid(panel):
		push_error("[TutorialUI] tutorialPanel scene tidak ketemu — panel tutorial gak akan muncul!")
		return
	var old_parent := panel.get_parent()
	if old_parent:
		old_parent.remove_child(panel)
	add_child(panel)
	_panel = panel
	_title = panel.get_node_or_null("title") as Label
	_info = panel.get_node_or_null("info") as Label
	_step_badge = panel.get_node_or_null("Label") as Label
	if _title == null or _info == null or _step_badge == null:
		push_error("[TutorialUI] child tutorialPanel kurang (title/info/Label)!")
		return
	if _panel.size.x > 0.0 and _panel.size.y > 0.0:
		_panel_size = _panel.size
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # tap tembus
	_panel.pivot_offset = _panel_size * 0.5
	_step_badge.pivot_offset = _step_badge.size * 0.5
	_title_home = _title.position
	_info_home = _info.position
	_badge_home = _step_badge.position
	_panel.visible = false

	# Catatan kecil HP protected (tetap runtime, di atas panel).
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


func show_step(step_no: int, step_total: int, title: String, body: String,
		zone: Zone = Zone.BOTTOM_LEFT, avoid_target: bool = true,
		dismissable: bool = true) -> void:
	if _panel == null:
		return
	# info scene = Label biasa (bukan bbcode): bersihin marker **.
	_title.text = title.strip_edges()
	_info.text = body.strip_edges().replace("**", "")
	_step_badge.text = "STEP %d / %d" % [step_no, step_total]
	_step_badge.visible = true
	visible = true
	_panel.visible = true
	_dismiss_armed = dismissable
	_continue_btn.visible = false
	_apply_pending_spotlight()
	var target: Vector2 = _zone_pos(zone)
	if avoid_target and spotlight and spotlight.visible:
		target = _avoid_spotlight(zone, target)
	_move_panel_to(target)
	_place_hp_note()
	_play_intro_stagger()


func show_final(text: String) -> void:
	if _panel == null:
		return
	var title_text := ""
	var body_text := text
	var nl := text.find("\n")
	if nl >= 0:
		title_text = text.substr(0, nl).strip_edges()
		body_text = text.substr(nl + 1).strip_edges()
	_title.text = title_text
	_info.text = body_text.replace("**", "")
	_step_badge.text = "DONE"
	_step_badge.visible = true
	visible = true
	_panel.visible = true
	_dismiss_armed = false
	if spotlight:
		spotlight.clear_spotlight()
	_move_panel_to(_zone_pos(Zone.TOP_CENTER))
	_place_hp_note()
	_play_intro_stagger()
	_continue_btn.visible = true
	_position_continue_btn()


func hide_panel() -> void:
	visible = false
	_dismiss_armed = false
	_continue_btn.visible = false
	_hp_note.visible = false
	if _panel:
		_panel.visible = false
	if spotlight:
		spotlight.clear_spotlight()


func set_spotlight_target(node: Node, dim: float = 0.78) -> void:
	_pending_spotlight_target = node
	_pending_has_target = true
	_pending_dim = dim
	if spotlight and visible:
		_apply_pending_spotlight()


func _apply_pending_spotlight() -> void:
	if not _pending_has_target:
		return
	_pending_has_target = false
	if not spotlight:
		return
	if _pending_spotlight_target == null or not is_instance_valid(_pending_spotlight_target):
		spotlight.clear_spotlight()
	else:
		spotlight.set_spotlight_target(_pending_spotlight_target, _pending_dim)
	_pending_spotlight_target = null


func clear_spotlight() -> void:
	if spotlight:
		spotlight.clear_spotlight()


func set_hp_note(shown: bool) -> void:
	_hp_note.visible = shown and visible
	if shown:
		_place_hp_note()


func is_dismiss_armed() -> bool:
	return _dismiss_armed


func try_dismiss_on_tap() -> bool:
	if not _dismiss_armed:
		return false
	hide_panel()
	return true


# ============================================================
# TAP INPUT — node ini PROCESS_MODE_ALWAYS, jadi _input() tetap
# jalan walau tree paused.
# ============================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Tombol Continue punya alur sendiri (pressed signal).
	if _continue_btn.visible:
		return
	# Step aksi: target yang di-highlight yang harus diklik, JANGAN
	# semua tap diterjemahkan jadi dismiss.
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
			return Vector2(vs.x - _panel_size.x - 16, 62)
		Zone.TOP_CENTER:
			return Vector2((vs.x - _panel_size.x) * 0.5, 14)
		_:
			return Vector2(16, vs.y - _panel_size.y - 12)


func _avoid_spotlight(zone: Zone, base: Vector2) -> Vector2:
	# Panel desain FIXED SIZE (dari scene) — gak ada shrink. Cari slot
	# muat 272x99 yang gak nabrak spotlight, fallback ke base.
	if not spotlight or not spotlight.visible:
		return base
	var vs := get_viewport_rect().size
	var sr := spotlight.get_target_rect()
	if not Rect2(base, _panel_size).intersects(sr):
		return base
	var candidates: Array[Vector2] = [
		base,
		Vector2(16, 62),
		Vector2(vs.x - _panel_size.x - 16, 62),
		Vector2(16, (vs.y - _panel_size.y) * 0.5),
		Vector2(vs.x - _panel_size.x - 16, (vs.y - _panel_size.y) * 0.5),
		Vector2(16, vs.y - _panel_size.y - 12),
		Vector2(vs.x - _panel_size.x - 16, vs.y - _panel_size.y - 12),
	]
	for c in candidates:
		if not Rect2(c, _panel_size).intersects(sr):
			return c
	var step_x := 10.0
	var step_y := 8.0
	var y := 4.0
	while y <= vs.y - _panel_size.y - 4.0:
		var x := 4.0
		while x <= vs.x - _panel_size.x - 4.0:
			if not Rect2(Vector2(x, y), _panel_size).intersects(sr):
				return Vector2(x, y)
			x += step_x
		y += step_y
	return base


# Intro stagger: panel pop + fade, judul geser-masuk, info fade,
# badge pop belakangan. Tiap show_text diulang dari awal.
func _play_intro_stagger() -> void:
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	_panel.modulate.a = 1.0
	_panel.scale = Vector2(0.92, 0.92)
	_title.modulate.a = 0.0
	_title.position = _title_home + Vector2(-8, 0)
	_info.modulate.a = 0.0
	_step_badge.modulate.a = 0.0
	_step_badge.scale = Vector2(0.5, 0.5)
	_intro_tween = create_tween().set_parallel(true)
	_intro_tween.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(_title, "modulate:a", 1.0, 0.15).set_delay(0.06)
	_intro_tween.tween_property(_title, "position:x", _title_home.x, 0.15).set_delay(0.06)
	_intro_tween.tween_property(_info, "modulate:a", 1.0, 0.15).set_delay(0.12)
	_intro_tween.tween_property(_step_badge, "modulate:a", 1.0, 0.12).set_delay(0.18)
	_intro_tween.tween_property(_step_badge, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.18)


func _move_panel_to(target: Vector2) -> void:
	if _panel == null:
		return
	_panel_dest = target
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(_panel, "position", target, MOVE_TIME)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _place_hp_note() -> void:
	if _hp_note == null:
		return
	_hp_note.position = _panel_dest + Vector2(0, -18)


func _position_continue_btn() -> void:
	var vs := get_viewport_rect().size
	var x := clampf(_panel_dest.x + (_panel_size.x - 120.0) * 0.5, 8.0, vs.x - 128.0)
	var y := _panel_dest.y + _panel_size.y + 8.0
	if y + 40.0 > vs.y - 4.0:
		y = _panel_dest.y - 40.0 - 8.0
	_continue_btn.position = Vector2(x, maxf(y, 4.0))


func _on_continue_pressed() -> void:
	_hide_dismiss_arm()
	hide_panel()
	finished.emit()


func _hide_dismiss_arm() -> void:
	_dismiss_armed = false
