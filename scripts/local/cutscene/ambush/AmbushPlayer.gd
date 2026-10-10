class_name AmbushPlayer
extends Node

# ============================================================
# AMBUSH PLAYER — komponen reusable buat adegan penyergapan.
#
# Dipakai siapa aja yang butuh "diserang dadakan":
#   prologue_2, random encounter di Forest, story ambush, dll.
#
# Cara pakai:
#   var ambush := AmbushPlayer.new()
#   add_child(ambush)
#   ambush.play({
#       "root": self,         # Control pemanggil (overlay ditempel di sini)
#       "bg": $bg,           # TextureRect background (di-shake pas impact)
#       "warning_text": "Something moved behind the trees!",
#       "impact_text": "Ambush!",  # teks miring di segitiga (opsional)
#   })
#   await ambush.finished
#   ambush.queue_free()
#   TransitionManager.pindah_scene("...", "Ambush")
#
# Visual: segitiga siku-siku pojok kanan-bawah + api FlameShader
# di sisinya + blink + teks miring + shake. Penyerang TIDAK
# ditampilin (misterius) — pertama kelihatan di battle.
#
# AmbushPlayer CUMA urus drama (tension -> warning -> impact).
# Habis ini ke mana = urusan caller (via signal finished).
# ============================================================

signal finished

# Tunable (viewport 740x340) — eyeball pas test:
const TENSION_SEC := 0.8
const WARNING_SEC := 1.2
const SHAKE_PX := 20.0
# Segitiga: box 320x220, siku di kanan-bawah (740, 340).
const TRI_W := 320
const TRI_H := 220
const TRI_POS := Vector2(420, 120)
# Teks impact: miring -28° (naik ke kanan, ngikutin sisi miring).
const IMPACT_FONT_SIZE := 56
const IMPACT_ROT_DEG := -28.0
const IMPACT_COLOR := Color(0.7, 0.05, 0.05, 1)
const IMPACT_POS := Vector2(453.0, 227.0)
const IMPACT_SIZE := Vector2(360.0, 80.0)
# Api di sisi segitiga.
const FLAME_COLOR := Color(1.0, 0.35, 0.05, 1.0)
const FLAME_OUTLINE := Color(0.1, 0.02, 0.02, 1.0)
const FLAME_SHADER := "res://shaders/FlameShader.gdshader"
# Blink segitiga putih <-> oranye (3x).
const BLINK_COLOR := Color(1.0, 0.55, 0.2, 1.0)
const BLINK_HALF_SEC := 0.075
const BLINK_COUNT := 3

const SFX_STING := "res://assets/audio/effects/battle/ui/zoomIntoEnemy.mp3"
const SFX_SLAM := "res://assets/audio/effects/battle/ui/attackQte-open.mp3"
const SFX_IMPACT := "res://assets/audio/effects/battle/sword/sword-attack.mp3"
const FONT_PATH := "res://assets/ui/fonts/alagard.ttf"

var _running := false

var _vignette: ColorRect
var _warn_label: Label
var _tri: TextureRect
var _flame_mat: ShaderMaterial
var _impact_label: Label


func play(cfg: Dictionary) -> void:
	if _running:
		return
	_running = true

	var root: Control = cfg.get("root")
	var bg: TextureRect = cfg.get("bg")
	var warn_text: String = cfg.get("warning_text", "Something moved behind the trees!")
	var impact_text: String = cfg.get("impact_text", "Ambush!")

	if root == null or not is_instance_valid(root):
		push_error("[AmbushPlayer] cfg['root'] invalid!")
		_running = false
		finished.emit()
		return

	_build_overlays(root)
	await _beat_tension()
	if not _alive():
		return
	await _beat_warning(warn_text)
	if not _alive():
		return
	await _beat_impact(bg, impact_text)
	_cleanup()
	_running = false
	finished.emit()


func _alive() -> bool:
	return _running and is_instance_valid(self)


# ============================================================
# OVERLAY — dibikin runtime, dibersihin pas selesai
# ============================================================

func _build_overlays(root: Control) -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.color = Color(0.4, 0.0, 0.0, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_vignette)

	_warn_label = Label.new()
	_warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn_label.add_theme_font_size_override("font_size", 28)
	_warn_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	_warn_label.add_theme_constant_override("outline_size", 8)
	_warn_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	if ResourceLoader.exists(FONT_PATH):
		_warn_label.add_theme_font_override("font", load(FONT_PATH) as Font)
	_warn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warn_label.visible = false
	root.add_child(_warn_label)

	# Segitiga + teks miring (paling atas).
	_tri = TextureRect.new()
	_tri.texture = _make_triangle_texture()
	_tri.position = TRI_POS
	_tri.size = Vector2(TRI_W, TRI_H)
	_tri.pivot_offset = Vector2(TRI_W, TRI_H)
	_tri.scale = Vector2(0.01, 0.01)
	_tri.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tri.stretch_mode = TextureRect.STRETCH_SCALE
	_tri.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_tri.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tri.visible = false
	if ResourceLoader.exists(FLAME_SHADER):
		_flame_mat = ShaderMaterial.new()
		_flame_mat.shader = load(FLAME_SHADER) as Shader
		_flame_mat.set_shader_parameter("flame_color", FLAME_COLOR)
		_flame_mat.set_shader_parameter("outline_color", FLAME_OUTLINE)
		_flame_mat.set_shader_parameter("transition", 0.0)
		_tri.material = _flame_mat
	root.add_child(_tri)

	_impact_label = Label.new()
	_impact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_impact_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_impact_label.add_theme_font_size_override("font_size", IMPACT_FONT_SIZE)
	_impact_label.add_theme_color_override("font_color", IMPACT_COLOR)
	_impact_label.add_theme_constant_override("outline_size", 10)
	_impact_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	if ResourceLoader.exists(FONT_PATH):
		_impact_label.add_theme_font_override("font", load(FONT_PATH) as Font)
	_impact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_impact_label.visible = false
	root.add_child(_impact_label)


# Segitiga siku-siku (siku di kanan-bawah), digenerate runtime —
# tanpa file aset. Half-plane test per piksel, sekali jalan.
func _make_triangle_texture() -> ImageTexture:
	var img := Image.create(TRI_W, TRI_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(TRI_H):
		var t := float(TRI_H - 1 - y) / float(TRI_H - 1)
		var x_left := int(float(TRI_W - 1) * (1.0 - t))
		for x in range(x_left, TRI_W):
			img.set_pixel(x, y, Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)


func _cleanup() -> void:
	for n in [_vignette, _warn_label, _tri, _impact_label]:
		if is_instance_valid(n):
			n.queue_free()
	_vignette = null
	_warn_label = null
	_tri = null
	_flame_mat = null
	_impact_label = null


# ============================================================
# BEATS
# ============================================================

# Beat 1 — TENSION (0.8s): hening. Prasyarat: caller udah beresin
# animasinya sendiri (bg diam) sebelum play().
func _beat_tension() -> void:
	await get_tree().create_timer(TENSION_SEC).timeout


# Beat 2 — WARNING (1.2s): vignette merah pulse + teks + sting.
func _beat_warning(warn_text: String) -> void:
	_play_sfx(SFX_STING)
	_warn_label.text = warn_text
	_warn_label.visible = true
	_warn_label.modulate.a = 0.0
	_warn_label.scale = Vector2(0.8, 0.8)
	var vs := get_viewport().get_visible_rect().size
	_warn_label.position = Vector2(vs.x * 0.5 - 250.0, 70.0)
	_warn_label.size = Vector2(500.0, 60.0)
	_warn_label.pivot_offset = Vector2(250.0, 30.0)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_vignette, "color:a", 0.5, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_warn_label, "modulate:a", 1.0, 0.3)
	tw.tween_property(_warn_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(WARNING_SEC).timeout


# Beat 3 — IMPACT (~1.2s): segitiga nyabet dari sudut + api meletup
# di sisinya + blink + teks miring pop + shake + SFX.
func _beat_impact(bg: TextureRect, impact_text: String) -> void:
	_play_sfx(SFX_SLAM)

	# Teks miring -28° di tengah wedge.
	_impact_label.text = impact_text
	_impact_label.position = IMPACT_POS
	_impact_label.size = IMPACT_SIZE
	_impact_label.pivot_offset = IMPACT_SIZE * 0.5
	_impact_label.rotation_degrees = IMPACT_ROT_DEG
	_impact_label.scale = Vector2(0.5, 0.5)
	_impact_label.modulate.a = 0.0
	_impact_label.visible = true

	_tri.visible = true
	var tw := create_tween().set_parallel(true)
	# Segitiga nyabet (0.18s, snappy) + api meletup (0.4s).
	tw.tween_property(_tri, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _flame_mat != null:
		tw.tween_property(_flame_mat, "shader_parameter/transition", 1.0, 0.4)
	# Teks pop nyusul dikit (delay 0.1s).
	tw.tween_property(_impact_label, "modulate:a", 1.0, 0.15).set_delay(0.1)
	tw.tween_property(_impact_label, "scale", Vector2.ONE, 0.25).set_delay(0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Warn label + vignette settle, bg shake, SFX impact pas teks pop.
	tw.tween_property(_warn_label, "modulate:a", 0.0, 0.2)
	tw.tween_property(_vignette, "color:a", 0.4, 0.3)
	if bg != null and is_instance_valid(bg):
		var base_pos: Vector2 = bg.position
		for i in range(6):
			var off := Vector2(randf_range(-SHAKE_PX, SHAKE_PX), randf_range(-SHAKE_PX, SHAKE_PX))
			tw.tween_property(bg, "position", base_pos + off, 0.06)
		tw.tween_property(bg, "position", base_pos, 0.08)
	await tw.finished
	if not _alive():
		return
	_play_sfx(SFX_IMPACT)

	# Blink segitiga putih <-> oranye (tween sekuensial terpisah —
	# gabung ke parallel di atas bakal tabrakan di properti sama).
	var blink := create_tween()
	for i in range(BLINK_COUNT):
		blink.tween_property(_tri, "modulate", BLINK_COLOR, BLINK_HALF_SEC)
		blink.tween_property(_tri, "modulate", Color(1, 1, 1, 1), BLINK_HALF_SEC)
	await blink.finished
	if not _alive():
		return
	# Tahan 0.3s (segitiga api + teks), baru curtain.
	await get_tree().create_timer(0.3).timeout


func _play_sfx(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path) as AudioStream
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
