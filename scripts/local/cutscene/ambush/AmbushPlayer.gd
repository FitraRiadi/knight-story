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
#       "warning_text": "Something moved behind the trees.",
#   })
#   await ambush.finished
#   ambush.queue_free()
#   TransitionManager.pindah_scene("...", "Ambush")
#
# Visual: SILENT DREAD — tanpa hit, tanpa shape, tanpa SFX keras.
# Dialog selesai -> hening (teks warning muncul pelan) -> layar
# turun ke near-black pelan -> tahan -> curtain -> battle.
# Penyerang TIDAK ditampilin (misterius).
#
# AmbushPlayer CUMA urus drama. Habis ini ke mana = urusan
# caller (via signal finished).
# ============================================================

signal finished

# Tunable — dread butuh waktu, jangan dicepetin:
const SILENCE_SEC := 2.0
const DARKEN_SEC := 2.5
const DARK_TARGET_A := 0.85
const HOLD_SEC := 0.5

const FONT_PATH := "res://assets/ui/fonts/alagard.ttf"

var _running := false

var _darken: ColorRect
var _warn_label: Label


func play(cfg: Dictionary) -> void:
	if _running:
		return
	_running = true

	var root: Control = cfg.get("root")
	var warn_text: String = cfg.get("warning_text", "Something moved behind the trees.")

	if root == null or not is_instance_valid(root):
		push_error("[AmbushPlayer] cfg['root'] invalid!")
		_running = false
		finished.emit()
		return

	_build_overlays(root)
	await _beat_silence(warn_text)
	if not _alive():
		return
	await _beat_darken()
	if not _alive():
		return
	await _beat_hold()
	_cleanup()
	_running = false
	finished.emit()


func _alive() -> bool:
	return _running and is_instance_valid(self)


# ============================================================
# OVERLAY — dibikin runtime, dibersihin pas selesai
# ============================================================

func _build_overlays(root: Control) -> void:
	_darken = ColorRect.new()
	_darken.set_anchors_preset(Control.PRESET_FULL_RECT)
	_darken.color = Color(0, 0, 0, 0)
	_darken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_darken)

	_warn_label = Label.new()
	_warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn_label.add_theme_font_size_override("font_size", 24)
	_warn_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_warn_label.add_theme_constant_override("outline_size", 6)
	_warn_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	if ResourceLoader.exists(FONT_PATH):
		_warn_label.add_theme_font_override("font", load(FONT_PATH) as Font)
	_warn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warn_label.visible = false
	root.add_child(_warn_label)


func _cleanup() -> void:
	for n in [_darken, _warn_label]:
		if is_instance_valid(n):
			n.queue_free()
	_darken = null
	_warn_label = null


# ============================================================
# BEATS
# ============================================================

# Beat 1 — SILENCE: hening total. Teks warning muncul PELAN
# (fade 1s, tanpa pop, tanpa SFX). Nggak ada yang gerak.
func _beat_silence(warn_text: String) -> void:
	_warn_label.text = warn_text
	_warn_label.visible = true
	_warn_label.modulate.a = 0.0
	var vs := get_viewport().get_visible_rect().size
	_warn_label.position = Vector2(vs.x * 0.5 - 250.0, 70.0)
	_warn_label.size = Vector2(500.0, 60.0)

	var tw := create_tween()
	tw.tween_property(_warn_label, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(SILENCE_SEC).timeout


# Beat 2 — DARKEN: layar turun ke near-black pelan. Teks larut
# di tengah jalan. Tetap hening.
func _beat_darken() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_darken, "color:a", DARK_TARGET_A, DARKEN_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_warn_label, "modulate:a", 0.0, 0.8).set_delay(1.0).set_trans(Tween.TRANS_SINE)
	await tw.finished


# Beat 3 — HOLD: gelap + hening, baru curtain.
func _beat_hold() -> void:
	await get_tree().create_timer(HOLD_SEC).timeout
