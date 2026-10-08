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

# Posisi lubang YANG KE-RENDER (dilerp tiap frame ke target).
# Inilah yang bikin pindah target ada animasi glide-nya, bukan snap.
var _cur_center := Vector2(0.5, 0.5)
var _cur_size: Vector2 = Vector2(64.0, 48.0)
var _cur_dim := 0.0
var _has_cur := false
# Kecepatan glide: ~99% sampai dalam 0.7 dtk — keliatan sebagai
# animasi pindah, bukan snap, tapi gak lemot ngikutin target gerak.
const GLIDE_SPEED := 6.0


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
	# WAJIB dua-duanya: anchors_preset DOANG gak ngembangin size
	# (kebukti: size tetap (0,0) -> overlay gak pernah ke-render!).
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	_force_full_rect()
	visible = false


# Sabuk pengaman: paksa fullscreen tiap frame (rotasi/resize HP).
func _force_full_rect() -> void:
	var vs := get_viewport_rect().size
	if vs.x <= 0.0 or vs.y <= 0.0:
		return
	position = Vector2.ZERO
	size = vs
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0


func _process(delta: float) -> void:
	_force_full_rect()
	if _mat == null:
		return
	var vs := get_viewport_rect().size
	if vs.x <= 0.0 or vs.y <= 0.0:
		return
	# Target yang DIMAU frame ini (bisa beda jauh pas ganti step).
	var want_center := _cur_center
	var want_size := _cur_size
	var want_dim := 0.0
	if _target_node and is_instance_valid(_target_node):
		var r := get_target_rect()
		want_center = r.get_center() / vs
		want_size = r.size
		want_dim = _dim_amount
		if not _has_cur:
			# Kemunculan pertama: snap (gak glide dari entah mana).
			_cur_center = want_center
			_cur_size = want_size
			_cur_dim = 0.0
			_has_cur = true
	# Glide eksponensial ke target: pindah spot = animasi, bukan snap.
	# Tetap ngikutin target yang gerak (kartu hover, tombol slide).
	# Fade-out (clear) jalannya 2x lebih kencang biar layar cepat jernih.
	var spd := GLIDE_SPEED
	if _target_node == null or not is_instance_valid(_target_node):
		spd = GLIDE_SPEED * 2.0
	var t := 1.0 - exp(-spd * minf(maxf(delta, 0.0), 0.05))
	_cur_center = _cur_center.lerp(want_center, t)
	_cur_size = _cur_size.lerp(want_size, t)
	_cur_dim = lerpf(_cur_dim, want_dim, t)
	_mat.set_shader_parameter("spot_center", _cur_center)
	_mat.set_shader_parameter("spot_size", _cur_size)
	_mat.set_shader_parameter("dim_amount", _cur_dim)
	# Fade-out kelar -> sembunyi (fade-in diatur set_spotlight_target).
	if _target_node == null and _cur_dim <= 0.01:
		visible = false


func get_target_rect() -> Rect2:
	if not _target_node or not is_instance_valid(_target_node):
		return Rect2()
	var r: Rect2
	if _target_node is Control:
		r = (_target_node as Control).get_global_rect()
	elif _target_node is Node2D:
		# Musuh: pakai collision button-nya kalau ada (presisi, ngikutin
		# scale/anim), fallback ke tebakan posisi+sprite.
		var col: Control = null
		if _target_node.get("enemy_collision") is Control:
			col = _target_node.get("enemy_collision") as Control
		if col and is_instance_valid(col):
			r = col.get_global_rect()
		else:
			var n2 := _target_node as Node2D
			var scr_pos: Vector2 = get_viewport().get_canvas_transform() * n2.global_position
			r = Rect2(scr_pos - Vector2(48, 64), Vector2(96, 128))
	else:
		r = Rect2(Vector2.ZERO, _min_size)
	return r.grow_individual(_padding.x, _padding.y, _padding.x, _padding.y)


func set_spotlight_target(node: Node, dim: float = 0.72) -> void:
	_target_node = node
	_dim_amount = dim
	visible = true
	# Gak snap: _process nge-glide _cur_* ke target baru (~0.35 dtk).
	_start_pulse()


func clear_spotlight() -> void:
	_stop_pulse()
	_target_node = null
	# Gak langsung invisible: _process fade-out dim dulu baru hide.


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
