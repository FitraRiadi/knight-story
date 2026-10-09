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
# Slash art bawaan (12 frame, arah diagonal `\` — teks ngikutin arah ini).
const SLASH_PATTERN := "res://assets/art/particles/slash/slash4_%05d.png"
const SLASH_COUNT := 12
const SLASH_SPEED := 20
const SLASH_SCALE := Vector2(2.0, 2.0)
const SLASH_POS := Vector2(520, 170)
# Teks impact: miring +22° (searah garis slash `\`).
const IMPACT_FONT_SIZE := 56
const IMPACT_ROT_DEG := 22.0
const IMPACT_COLOR := Color(0.7, 0.05, 0.05, 1)

const SFX_STING := "res://assets/audio/effects/battle/ui/zoomIntoEnemy.mp3"
const SFX_REVEAL := "res://assets/audio/effects/battle/ui/attackQte-open.mp3"
const SFX_IMPACT := "res://assets/audio/effects/battle/sword/sword-attack.mp3"
const FONT_PATH := "res://assets/ui/fonts/alagard.ttf"

var _running := false

var _vignette: ColorRect
var _warn_label: Label
var _enemy: AnimatedSprite2D
var _slash_fx: AnimatedSprite2D
var _slash_frames: SpriteFrames
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

	# Slash art + teks miring (paling atas, di atas vignette + enemy).
	_slash_frames = _build_slash_frames()
	_slash_fx = AnimatedSprite2D.new()
	_slash_fx.sprite_frames = _slash_frames
	_slash_fx.position = SLASH_POS
	_slash_fx.scale = SLASH_SCALE * 0.9
	_slash_fx.modulate.a = 0.0
	_slash_fx.visible = false
	root.add_child(_slash_fx)

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
	for n in [_vignette, _warn_label, _enemy, _slash_fx, _impact_label]:
		if is_instance_valid(n):
			n.queue_free()
	_vignette = null
	_warn_label = null
	_enemy = null
	_slash_fx = null
	_slash_frames = null
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


# Bangun SpriteFrames slash dari 12 file. File yang hilang di-skip;
# kalau 0 yang keload, beat impact jalan tanpa slash (teks + shake tetap).
func _build_slash_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("slash")
	sf.set_animation_speed("slash", SLASH_SPEED)
	sf.set_animation_loop("slash", false)
	for i in range(1, SLASH_COUNT + 1):
		var path := SLASH_PATTERN % i
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		if tex != null:
			sf.add_frame("slash", tex)
	return sf


# Beat 4 — IMPACT (~1.0s): slash art nyabet + teks miring pop
# + shake + impact SFX.
func _beat_impact(bg: TextureRect, impact_text: String) -> void:
	_play_sfx(SFX_IMPACT)

	# Teks "Ambush!" miring +22° (searah garis slash `\`).
	_impact_label.text = impact_text
	_impact_label.position = Vector2(300.0, 125.0)
	_impact_label.size = Vector2(400.0, 90.0)
	_impact_label.pivot_offset = Vector2(200.0, 45.0)
	_impact_label.rotation_degrees = IMPACT_ROT_DEG
	_impact_label.scale = Vector2(0.5, 0.5)
	_impact_label.modulate.a = 0.0
	_impact_label.visible = true

	var has_slash := false
	if is_instance_valid(_slash_fx) and _slash_fx.sprite_frames != null:
		has_slash = _slash_fx.sprite_frames.has_animation("slash") \
			and _slash_fx.sprite_frames.get_frame_count("slash") > 0

	var tw := create_tween().set_parallel(true)
	# Slash main + scale punch.
	if has_slash:
		_slash_fx.visible = true
		_slash_fx.modulate.a = 1.0
		_slash_fx.play("slash")
		tw.tween_property(_slash_fx, "scale", SLASH_SCALE * 1.1, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Teks pop nyusul dikit (delay 0.1s).
	tw.tween_property(_impact_label, "modulate:a", 1.0, 0.15).set_delay(0.1)
	tw.tween_property(_impact_label, "scale", Vector2.ONE, 0.25).set_delay(0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
	# Slash fade out, tahan bentar biar teks kebaca, baru curtain.
	if has_slash and is_instance_valid(_slash_fx) and _slash_fx.visible:
		var fade := create_tween()
		fade.tween_property(_slash_fx, "modulate:a", 0.0, 0.3)
		await fade.finished
	await get_tree().create_timer(0.2).timeout


func _play_sfx(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path) as AudioStream
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
