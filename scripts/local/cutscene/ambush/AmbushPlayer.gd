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
#       "root": self,            # Control pemanggil (overlay ditempel di sini)
#       "bg": $bg,              # TextureRect background (di-shake pas impact)
#       "enemy_id": "skeleton", # art diambil dari EnemyDatabase (konsisten battle)
#       "warning_text": "Something moved behind the trees!",
#       "impact_text": "Ambush!",  # teks miring di segitiga slash (opsional)
#   })
#   await ambush.finished
#   ambush.queue_free()
#   TransitionManager.pindah_scene("...", "Ambush")
#
# AmbushPlayer CUMA urus drama (tension -> warning -> reveal ->
# impact). Habis ini ke mana = urusan caller (via signal finished).
# ============================================================

signal finished

# Tunable (viewport 740x340) — eyeball pas test:
const TENSION_SEC := 0.8
const WARNING_SEC := 1.2
const ENEMY_START_X := 1050.0
const ENEMY_END_X := 520.0
const ENEMY_Y := 200.0
const SHAKE_PX := 20.0
# Slash segitiga siku-siku (local coords, pivot = sudut kanan-atas layar):
# P0 (0,0) -> layar (740,0); P1 (0,340) -> (740,340); P2 (-640,340) -> (100,340).
const SLASH_POINTS := [Vector2(0, 0), Vector2(0, 340), Vector2(-640, 340)]
const SLASH_POS := Vector2(740, 0)
const SLASH_COLOR := Color(1, 1, 1, 1)
# Teks impact: miring ngikutin sisi miring segitiga.
const IMPACT_FONT_SIZE := 56
const IMPACT_ROT_DEG := -18.0
const IMPACT_COLOR := Color(0.7, 0.05, 0.05, 1)

const SFX_STING := "res://assets/audio/effects/battle/ui/zoomIntoEnemy.mp3"
const SFX_REVEAL := "res://assets/audio/effects/battle/ui/attackQte-open.mp3"
const SFX_IMPACT := "res://assets/audio/effects/battle/sword/sword-attack.mp3"
const FONT_PATH := "res://assets/ui/fonts/alagard.ttf"

var _running := false

var _vignette: ColorRect
var _warn_label: Label
var _enemy: AnimatedSprite2D
var _slash: Polygon2D
var _impact_label: Label


func play(cfg: Dictionary) -> void:
	if _running:
		return
	_running = true

	var root: Control = cfg.get("root")
	var bg: TextureRect = cfg.get("bg")
	var enemy_id: String = cfg.get("enemy_id", "skeleton")
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
	await _beat_reveal(enemy_id)
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

	_enemy = AnimatedSprite2D.new()
	_enemy.visible = false
	root.add_child(_enemy)

	# Slash segitiga (di atas vignette + enemy) + teks miring (paling atas).
	_slash = Polygon2D.new()
	_slash.polygon = PackedVector2Array(SLASH_POINTS)
	_slash.color = SLASH_COLOR
	_slash.position = SLASH_POS
	_slash.scale = Vector2(0.01, 0.01)
	_slash.visible = false
	root.add_child(_slash)

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


func _cleanup() -> void:
	for n in [_vignette, _warn_label, _enemy, _slash, _impact_label]:
		if is_instance_valid(n):
			n.queue_free()
	_vignette = null
	_warn_label = null
	_enemy = null
	_slash = null
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


# Beat 3 — REVEAL (1.0s): musuh slide in dari kanan pakai art asli.
func _beat_reveal(enemy_id: String) -> void:
	var data: EnemyData = EnemyDatabase.get_enemy_data(enemy_id)
	if data == null or data.sprite_frames == null:
		push_warning("[AmbushPlayer] enemy '%s' tidak ketemu — reveal diskip." % enemy_id)
		return
	_play_sfx(SFX_REVEAL)
	_enemy.sprite_frames = data.sprite_frames
	_enemy.scale = data.sprite_scale
	if _enemy.sprite_frames.has_animation("idle"):
		_enemy.play("idle")
	else:
		_enemy.play()
	_enemy.position = Vector2(ENEMY_START_X, ENEMY_Y)
	_enemy.modulate.a = 0.0
	_enemy.visible = true

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_enemy, "position:x", ENEMY_END_X, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_enemy, "modulate:a", 1.0, 0.5)
	await tw.finished


# Beat 4 — IMPACT (~0.8s): segitiga slash nyabet + teks miring pop
# + shake + impact SFX. Bukan fullscreen — bg masih kelihatan di sisi kiri.
func _beat_impact(bg: TextureRect, impact_text: String) -> void:
	_play_sfx(SFX_IMPACT)

	# Teks "Ambush!" miring ngikutin sisi miring segitiga.
	_impact_label.text = impact_text
	_impact_label.position = Vector2(300.0, 125.0)
	_impact_label.size = Vector2(400.0, 90.0)
	_impact_label.pivot_offset = Vector2(200.0, 45.0)
	_impact_label.rotation_degrees = IMPACT_ROT_DEG
	_impact_label.scale = Vector2(0.5, 0.5)
	_impact_label.modulate.a = 0.0
	_impact_label.visible = true

	_slash.visible = true
	var tw := create_tween().set_parallel(true)
	# Slash nyabet dari sudut kanan-atas (0.18s, snappy).
	tw.tween_property(_slash, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Teks pop nyusul dikit (delay 0.08s).
	tw.tween_property(_impact_label, "modulate:a", 1.0, 0.15).set_delay(0.08)
	tw.tween_property(_impact_label, "scale", Vector2.ONE, 0.25).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Warn label + vignette settle, bg shake.
	tw.tween_property(_warn_label, "modulate:a", 0.0, 0.2)
	tw.tween_property(_vignette, "color:a", 0.4, 0.3)
	if bg != null and is_instance_valid(bg):
		var base_pos: Vector2 = bg.position
		for i in range(6):
			var off := Vector2(randf_range(-SHAKE_PX, SHAKE_PX), randf_range(-SHAKE_PX, SHAKE_PX))
			tw.tween_property(bg, "position", base_pos + off, 0.06)
		tw.tween_property(bg, "position", base_pos, 0.08)
	await tw.finished
	# Tahan 0.4s biar slash + teks kebaca, baru curtain.
	await get_tree().create_timer(0.4).timeout


func _play_sfx(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path) as AudioStream
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
