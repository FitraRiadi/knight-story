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
# Lunge musuh ke kamera (horor): scale-up + maju + animasi attack.
# LUNGE_TIME cuma fallback — durasi real dibaca dari resource (frames/fps).
const LUNGE_SCALE_MULT := 1.6
const LUNGE_POS := Vector2(400, 210)
const LUNGE_TIME := 0.25
const REDBURST_COLOR := Color(0.5, 0.0, 0.0, 1)

const SFX_STING := "res://assets/audio/effects/battle/ui/zoomIntoEnemy.mp3"
const SFX_REVEAL := "res://assets/audio/effects/battle/ui/attackQte-open.mp3"
const SFX_IMPACT := "res://assets/audio/effects/battle/sword/sword-attack.mp3"
const FONT_PATH := "res://assets/ui/fonts/alagard.ttf"

var _running := false

var _vignette: ColorRect
var _warn_label: Label
var _enemy: AnimatedSprite2D
var _redburst: ColorRect


func play(cfg: Dictionary) -> void:
	if _running:
		return
	_running = true

	var root: Control = cfg.get("root")
	var bg: TextureRect = cfg.get("bg")
	var enemy_id: String = cfg.get("enemy_id", "skeleton")
	var warn_text: String = cfg.get("warning_text", "Something moved behind the trees!")

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
	await _beat_impact(bg, enemy_id)
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

	# Red burst (paling atas) — darah, bukan flash putih.
	_redburst = ColorRect.new()
	_redburst.set_anchors_preset(Control.PRESET_FULL_RECT)
	_redburst.color = Color(REDBURST_COLOR.r, REDBURST_COLOR.g, REDBURST_COLOR.b, 0.0)
	_redburst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_redburst)


func _cleanup() -> void:
	for n in [_vignette, _warn_label, _enemy, _redburst]:
		if is_instance_valid(n):
			n.queue_free()
	_vignette = null
	_warn_label = null
	_enemy = null
	_redburst = null


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


# Beat 4 — IMPACT (~1.1s), DUA FASE:
#   4a. ATTACK DULU — musuh main animasi attack SAMPAI FRAME TERAKHIR
#       (lunge scale+move ngikutin durasi real animasi, bukan fixed 0.25s).
#   4b. IMPACT — BARU red burst + shake + SFX (attack udah kebaca jelas).
# Tanpa shape grafis, tanpa teks — musuhnya sendiri yang jadi efeknya.
func _beat_impact(bg: TextureRect, enemy_id: String) -> void:
	# 4a. ATTACK DULU sampai habis.
	var atk_sec := LUNGE_TIME
	if is_instance_valid(_enemy) and _enemy.visible:
		var data: EnemyData = EnemyDatabase.get_enemy_data(enemy_id)
		var base_scale: Vector2 = data.sprite_scale if data != null else Vector2(0.8, 0.8)
		if _enemy.sprite_frames != null and _enemy.sprite_frames.has_animation("attack"):
			var fc := _enemy.sprite_frames.get_frame_count("attack")
			var fps := _enemy.sprite_frames.get_animation_speed("attack")
			if fps > 0.0 and fc > 0:
				atk_sec = float(fc) / fps
			_enemy.play("attack")
		var lunge := create_tween().set_parallel(true)
		lunge.tween_property(_enemy, "scale", base_scale * LUNGE_SCALE_MULT, atk_sec).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		lunge.tween_property(_enemy, "position", LUNGE_POS, atk_sec).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await lunge.finished
		if not _alive():
			return
	# 4b. IMPACT — attack udah kelar, baru efeknya.
	_play_sfx(SFX_IMPACT)
	var fx := create_tween().set_parallel(true)
	fx.tween_property(_redburst, "color:a", 0.7, 0.1)
	fx.tween_property(_warn_label, "modulate:a", 0.0, 0.2)
	fx.tween_property(_vignette, "color:a", 0.4, 0.3)
	if bg != null and is_instance_valid(bg):
		var base_pos: Vector2 = bg.position
		for i in range(6):
			var off := Vector2(randf_range(-SHAKE_PX, SHAKE_PX), randf_range(-SHAKE_PX, SHAKE_PX))
			fx.tween_property(bg, "position", base_pos + off, 0.06)
		fx.tween_property(bg, "position", base_pos, 0.08)
	await fx.finished
	# Tahan 0.3s (musuh di muka + merah), baru curtain.
	await get_tree().create_timer(0.3).timeout


func _play_sfx(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path) as AudioStream
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
