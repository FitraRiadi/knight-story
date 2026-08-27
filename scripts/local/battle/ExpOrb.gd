extends Node2D
class_name ExpOrb

# ============================================================
# DATA
# ============================================================
var exp_amount: int = 0
var target_pos: Vector2 = Vector2.ZERO
var is_flying: bool = false

# ============================================================
# VISUAL
# ============================================================
var circle: ColorRect
var label: Label

# ============================================================
# CONSTANTS
# ============================================================
const ORB_SIZE := Vector2(10, 10)
const ORB_COLOR := Color(0.3, 0.8, 1.0, 0.9)  # Biru terang
const ORB_GLOW_COLOR := Color(0.5, 0.9, 1.0, 0.4)
const FLY_DURATION := 0.6
const SPAWN_DURATION := 0.25
const FLOAT_AMPLITUDE := 2.0
const FLOAT_SPEED := 3.0

# ============================================================
# SETUP
# ============================================================
func setup(amount: int, spawn_pos: Vector2, destination: Vector2) -> void:
	exp_amount = amount
	target_pos = destination
	position = spawn_pos
	
	# Glow circle (bg)
	var glow := ColorRect.new()
	glow.name = "Glow"
	glow.size = ORB_SIZE * 2.0
	glow.position = -ORB_SIZE / 2.0
	glow.color = ORB_GLOW_COLOR
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	
	# Main circle
	circle = ColorRect.new()
	circle.name = "Circle"
	circle.size = ORB_SIZE
	circle.position = -ORB_SIZE / 2.0
	circle.color = ORB_COLOR
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(circle)
	
	# Label EXP
	label = Label.new()
	label.name = "Label"
	label.text = "+" + str(exp_amount)
	label.position = Vector2(-20, -20)
	label.size = Vector2(40, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0, 1.0))
	label.add_theme_font_size_override("font_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	
	# Mulai dari kecil
	scale = Vector2.ZERO
	modulate.a = 0.0

# ============================================================
# ANIMASI SPAWN + FLY
# ============================================================
func play_orb_animation() -> void:
	# Phase 1: Spawn (muncul + scale up)
	var spawn_tween := create_tween()
	spawn_tween.set_parallel(true)
	spawn_tween.tween_property(self, "scale", Vector2(1.3, 1.3), SPAWN_DURATION * 0.6)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	spawn_tween.chain().tween_property(self, "scale", Vector2(1.0, 1.0), SPAWN_DURATION * 0.4)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	spawn_tween.tween_property(self, "modulate:a", 1.0, SPAWN_DURATION * 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Tunggu spawn selesai
	await spawn_tween.finished
	
	# Phase 2: Label fade in
	var label_tween := create_tween()
	label_tween.tween_property(label, "modulate:a", 1.0, 0.15)
	label_tween.tween_property(label, "position:y", label.position.y - 12, 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	await label_tween.finished
	
	# Phase 3: Label fade out
	var label_fade := create_tween()
	label_fade.tween_property(label, "modulate:a", 0.0, 0.15)
	
	# Phase 4: Fly ke target (bezier curve)
	is_flying = true
	var start_pos := global_position
	var mid_pos := Vector2(
		(start_pos.x + target_pos.x) / 2.0,
		minf(start_pos.y, target_pos.y) - 60.0  # Arc ke atas
	)
	
	var fly_tween := create_tween()
	fly_tween.tween_method(_fly_bezier.bind(start_pos, mid_pos, target_pos), 0.0, 1.0, FLY_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Scale down saat mendekati target
	fly_tween.parallel().tween_property(self, "scale", Vector2(0.3, 0.3), FLY_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fly_tween.parallel().tween_property(self, "modulate:a", 0.6, FLY_DURATION * 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	await fly_tween.finished
	
	# Selesai
	queue_free()

# ============================================================
# BEZIER CURVE FLY
# ============================================================
func _fly_bezier(t: float, start: Vector2, mid: Vector2, end: Vector2) -> void:
	var one_minus_t := 1.0 - t
	global_position = (
		one_minus_t * one_minus_t * start +
		2.0 * one_minus_t * t * mid +
		t * t * end
	)
