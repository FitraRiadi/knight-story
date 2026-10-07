extends ColorRect
class_name TutorialSpotlight

# ============================================================
# TUTORIAL SPOTLIGHT
# Fullscreen gelap + satu lubang yang nge-FOLLOW target.
#
# Support Control (tombol/kartu) DAN Node2D (musuh), karena
# target step varies. Untuk Node2D posisi世界 -> screen pakai
# canvas_transform, sama kayak _spawn_drop_item() di BM.
#
# ColorRect fullscreen TIDAK mouse_filter STOP, cuma PASS: jadi
# spotlight bisa "ditembus" (area lubang = tap lolos ke target)
# sementara area gelap tetap bisa jadi trigger dismiss juga.
# Detail tap-vs-dismiss dicekel TutorialUI.
# ============================================================

const SPOTLIGHT_SHADER: Shader = preload("res://assets/art/shaders/tutorial_spotlight.gdshader")

var _mat: ShaderMaterial = null
var _target_node: Node = null
var _pulse_tween: Tween = null

# Padding minimum biar lubang gak nutep what'sbehind it
var _padding: Vector2 = Vector2(18.0, 18.0)
var _min_size: Vector2 = Vector2(64.0, 48.0)
var _dim_amount: float = 0.72


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # tembus, no blocking
	color = Color(1, 1, 1, 1)  # shader yang ngewarna, Color = white sbgRGBA
	_mat = ShaderMaterial.new()
	_mat.shader = SPOTLIGHT_SHADER
	_mat.set_shader_parameter("spot_center", Vector2(0.5, 0.5))
	_mat.set_shader_parameter("spot_size", _min_size)
	_mat.set_shader_parameter("dim_amount", _dim_amount)
	_mat.set_shader_parameter("corner_r", 12.0)
	_mat.set_shader_parameter("soft_edge", 0.10)
	_mat.set_shader_parameter("pulse", 0.0)
	material = _mat
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _process(_delta: float) -> void:
	# Ikutin target tiap frame (target bisa gerak: kartu hover, tombol slide)
	if _target_node and is_instance_valid(_target_node):
		var r := get_target_rect()
		_mat.set_shader_parameter("spot_center", r.get_center() / get_viewport_rect().size)
		_mat.set_shader_parameter("spot_size", r.size)


func get_target_rect() -> Rect2:
	if not _target_node or not is_instance_valid(_target_node):
		return Rect2()
	var r: Rect2
	if _target_node is Control:
		r = (_target_node as Control).get_global_rect()
	elif _target_node is Node2D:
		# Node2D enemy: pakai pos + ukuran sprite kasar
		var n2 := _target_node as Node2D
		var scr_pos: Vector2 = get_viewport().get_canvas_transform() * n2.global_position
		r = Rect2(scr_pos - Vector2(48, 64), Vector2(96, 128))
	else:
		r = Rect2(Vector2.ZERO, _min_size)
	return r.grow_individual(_padding.x, _padding.y, _padding.x, _padding.y)


func set_spotlight_target(node: Node, dim: float = 0.72) -> void:
	_target_node = node
	_dim_amount = dim
	if _mat:
		_mat.set_shader_parameter("dim_amount", dim)
	visible = true
	# Snap langsung ke posisi target (bukan nunggu _process) biar ga ada
	# 1 frame spotlight ngantuk pas transisi step
	if _target_node and is_instance_valid(_target_node):
		var r := get_target_rect()
		_mat.set_shader_parameter("spot_center", r.get_center() / get_viewport_rect().size)
		_mat.set_shader_parameter("spot_size", r.size)
	_start_pulse()


func clear_spotlight() -> void:
	_stop_pulse()
	_target_node = null
	visible = false


func _start_pulse() -> void:
	_stop_pulse()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_method(
		func(v: float) -> void:
			if _mat:
				_mat.set_shader_parameter("pulse", v),
		0.0, 1.0, 0.9
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_method(
		func(v: float) -> void:
			if _mat:
				_mat.set_shader_parameter("pulse", v),
		1.0, 0.0, 0.9
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	if _mat:
		_mat.set_shader_parameter("pulse", 0.0)
