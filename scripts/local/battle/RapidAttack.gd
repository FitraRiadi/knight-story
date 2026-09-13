extends Control
class_name RapidAttackUI


# ============================================================
# SIGNALS
# ============================================================

signal rapid_complete(results: Array[Dictionary])
signal rapid_started
signal rapid_ended


# ============================================================
# NODES (built programmatically, no .tscn dependency)
# ============================================================

var timer_bg: Panel
var timer_bar: Panel
var timer_label: Label
var combo_label: Label
var title_label: Label
var hit_marker: Label


# ============================================================
# STATE
# ============================================================

var is_active: bool = false
var timer_duration: float = 2.5
var timer_value: float = 0.0
var hit_results: Array[Dictionary] = []
var hit_enemies: Array[int] = []
var targets_hit_count: int = 0
var max_hits: int = 5
var _timer_tween: Tween


# ============================================================
# CONSTANTS
# ============================================================

const PERFECT_WINDOW: float = 0.6
const GOOD_WINDOW: float = 1.5
const HIT_MARKER_DURATION: float = 0.6


# ============================================================
# INIT
# ============================================================

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func _build_ui() -> void:
	# Title
	title_label = Label.new()
	title_label.text = "RAPID STRIKE!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.position = Vector2(170, 8)
	title_label.size = Vector2(400, 30)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	title_label.add_theme_constant_override("shadow_offset_x", 1)
	title_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(title_label)

	# Timer background
	timer_bg = Panel.new()
	timer_bg.position = Vector2(190, 42)
	timer_bg.size = Vector2(360, 18)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	timer_bg.add_theme_stylebox_override("panel", bg_style)
	add_child(timer_bg)

	# Timer bar
	timer_bar = Panel.new()
	timer_bar.position = Vector2(2, 2)
	timer_bar.size = Vector2(356, 14)
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(1.0, 0.85, 0.2)
	bar_style.corner_radius_top_left = 3
	bar_style.corner_radius_top_right = 3
	bar_style.corner_radius_bottom_left = 3
	bar_style.corner_radius_bottom_right = 3
	timer_bar.add_theme_stylebox_override("panel", bar_style)
	timer_bg.add_child(timer_bar)

	# Timer label
	timer_label = Label.new()
	timer_label.text = "2.5s"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.position = Vector2(190, 42)
	timer_label.size = Vector2(360, 18)
	timer_label.add_theme_font_size_override("font_size", 10)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(timer_label)

	# Combo label (bottom)
	combo_label = Label.new()
	combo_label.text = "0 / 5"
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.position = Vector2(170, 64)
	combo_label.size = Vector2(400, 24)
	combo_label.add_theme_font_size_override("font_size", 16)
	combo_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	combo_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	add_child(combo_label)

	# Hit marker (popup, hidden by default)
	hit_marker = Label.new()
	hit_marker.text = ""
	hit_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hit_marker.position = Vector2(170, 90)
	hit_marker.size = Vector2(400, 30)
	hit_marker.add_theme_font_size_override("font_size", 20)
	hit_marker.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2))
	hit_marker.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	hit_marker.visible = false
	add_child(hit_marker)


# ============================================================
# SHOW / HIDE
# ============================================================

func show_rapid(hit_count: int, enemy_count: int) -> void:
	visible = true
	move_to_front()

	max_hits = hit_count
	timer_duration = 2.5
	timer_value = timer_duration
	targets_hit_count = 0
	hit_results.clear()
	hit_enemies.clear()
	is_active = true

	# Update combo text
	combo_label.text = "0 / %d" % max_hits

	# SFX open
	var sfx: AudioStream = load("res://assets/audio/effects/battle/ui/attackQte-open.mp3")
	if sfx:
		var sfx_player := AudioStreamPlayer.new()
		sfx_player.stream = sfx
		sfx_player.volume_db = -3.0
		add_child(sfx_player)
		sfx_player.play()
		sfx_player.finished.connect(sfx_player.queue_free)

	# Pop-in animation
	modulate.a = 0.0
	scale = Vector2(0.5, 0.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Title pulse
	_start_title_pulse()

	# Start timer bar animation
	_start_timer_bar()

	rapid_started.emit()


func hide_rapid() -> void:
	is_active = false
	_stop_title_pulse()
	_kill_timer_tween()

	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_property(self, "scale", Vector2(0.8, 0.8), 0.15)
	tw.chain().tween_callback(func() -> void:
		visible = false
	)


# ============================================================
# TIMER
# ============================================================

func _start_timer_bar() -> void:
	_kill_timer_tween()
	_timer_tween = create_tween()
	_timer_tween.tween_property(self, "timer_value", 0.0, timer_duration).set_trans(Tween.TRANS_LINEAR)
	_timer_tween.tween_callback(_on_timer_expired)


func _kill_timer_tween() -> void:
	if _timer_tween and _timer_tween.is_valid():
		_timer_tween.kill()
		_timer_tween = null


func _process(_delta: float) -> void:
	if not is_active:
		return
	_update_timer_visual()
	_update_timer_color()


func _update_timer_visual() -> void:
	if not timer_bar or not timer_label:
		return
	var ratio: float = clampf(timer_value / timer_duration, 0.0, 1.0)
	var full_width: float = 356.0
	timer_bar.size.x = max(full_width * ratio, 2.0)
	timer_label.text = "%.1fs" % timer_value


func _update_timer_color() -> void:
	if not timer_bar:
		return
	var ratio: float = clampf(timer_value / timer_duration, 0.0, 1.0)
	var style: StyleBoxFlat = timer_bar.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		if ratio > 0.5:
			style.bg_color = Color(1.0, 0.85, 0.2)
		elif ratio > 0.25:
			style.bg_color = Color(1.0, 0.55, 0.15)
		else:
			style.bg_color = Color(0.9, 0.2, 0.2)


func _on_timer_expired() -> void:
	is_active = false
	rapid_ended.emit()
	rapid_complete.emit(hit_results)
	hide_rapid()


# ============================================================
# ENEMY TAP
# ============================================================

func register_hit(enemy_index: int) -> bool:
	if not is_active:
		return false
	if hit_enemies.has(enemy_index):
		return false

	var quality: String = _determine_quality()
	hit_enemies.append(enemy_index)
	targets_hit_count += 1
	hit_results.append({"enemy_index": enemy_index, "quality": quality})

	# Update combo
	combo_label.text = "%d / %d" % targets_hit_count, max_hits

	# Show hit marker
	_show_hit_marker(quality)

	return true


func _determine_quality() -> String:
	if timer_value >= timer_duration - PERFECT_WINDOW:
		return "perfect"
	elif timer_value >= timer_duration - GOOD_WINDOW:
		return "good"
	return "miss"


func _show_hit_marker(quality: String) -> void:
	if not hit_marker:
		return

	match quality:
		"perfect":
			hit_marker.text = "PERFECT!"
			hit_marker.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2))
		"good":
			hit_marker.text = "GOOD!"
			hit_marker.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
		_:
			hit_marker.text = "HIT"
			hit_marker.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	hit_marker.visible = true
	hit_marker.modulate.a = 1.0
	hit_marker.scale = Vector2(1.3, 1.3)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(hit_marker, "modulate:a", 0.0, HIT_MARKER_DURATION).set_delay(0.15)
	tw.tween_property(hit_marker, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void: hit_marker.visible = false)


func is_enemy_hit(enemy_index: int) -> bool:
	return hit_enemies.has(enemy_index)


# ============================================================
# TITLE PULSE
# ============================================================

var _title_pulse_tween: Tween

func _start_title_pulse() -> void:
	if not title_label:
		return
	_title_pulse_tween = create_tween().set_loops()
	_title_pulse_tween.tween_property(title_label, "modulate:a", 0.5, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title_pulse_tween.tween_property(title_label, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_title_pulse() -> void:
	if _title_pulse_tween and _title_pulse_tween.is_valid():
		_title_pulse_tween.kill()
	if title_label:
		title_label.modulate.a = 1.0


func get_results() -> Array[Dictionary]:
	return hit_results
