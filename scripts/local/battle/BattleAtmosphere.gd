extends Node2D
class_name BattleAtmosphere

# ============================================================
# BATTLE ATMOSPHERE
# Ambient battle: kunang-kunang + kabut + vignette gelap.
# Dibuat code-based (tanpa ubah .tscn) biar aman dari @onready $ paths.
# Semua CPUParticles2D (ramah Android), total < 50 partikel.
# Parent = root battlemode (screen-space 740x340), BUKAN Camera2D
# biar gak ikut zoom 1.10x pas rapid attack.
# ============================================================

const VIEW_SIZE := Vector2(740.0, 340.0)

var fireflies: CPUParticles2D = null
var fog: CPUParticles2D = null
var vignette: TextureRect = null

var _burst_active: bool = false
var _danger: bool = false
var _burst_tween: Tween = null
var _vignette_tween: Tween = null
var _stopped: bool = false

# Warna dasar kunang-kunang (hijau terang) & mode danger (merah redup)
var _firefly_calm := Color(0.6, 1.0, 0.3, 0.85)
var _firefly_danger := Color(1.0, 0.45, 0.3, 0.7)
var _fog_calm := Color(0.6, 0.7, 0.65, 0.10)
var _fog_danger := Color(0.55, 0.6, 0.6, 0.16)


func setup(battle_root: Control) -> void:
	battle_root.add_child(self)
	# Duduk tepat di atas bg (index 0), di bawah semua UI/enemy
	battle_root.move_child(self, 1)
	_setup_vignette()
	_setup_fireflies()
	_setup_fog()
	_play_vignette_breath()


func update_mood(big_hit: bool, hp_low: bool) -> void:
	if _stopped:
		return
	_danger = hp_low
	if big_hit:
		_trigger_burst()
	else:
		_apply_state()


func stop() -> void:
	_stopped = true
	if _burst_tween and _burst_tween.is_valid():
		_burst_tween.kill()
	if _vignette_tween and _vignette_tween.is_valid():
		_vignette_tween.kill()
	if fireflies:
		fireflies.emitting = false
	if fog:
		fog.emitting = false


# ------------------------------------------------------------
# SETUP
# ------------------------------------------------------------

func _make_dot_texture(size: int) -> GradientTexture2D:
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = Gradient.new()
	grad_tex.gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(1.0, 0.5)
	grad_tex.width = size
	grad_tex.height = size
	return grad_tex


func _make_fade_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	return ramp


func _setup_vignette() -> void:
	# Vignette murah: radial gradient transparan tengah -> gelap tepi
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = Gradient.new()
	grad_tex.gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad_tex.gradient.colors = PackedColorArray([
		Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.55)
	])
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(1.0, 0.5)
	grad_tex.width = 256
	grad_tex.height = 256
	vignette = TextureRect.new()
	vignette.texture = grad_tex
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(vignette)


func _setup_fireflies() -> void:
	fireflies = CPUParticles2D.new()
	fireflies.position = VIEW_SIZE / 2.0
	fireflies.amount = 28
	fireflies.lifetime = 5.0
	fireflies.preprocess = 5.0
	fireflies.lifetime_randomness = 0.4
	fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_BOX
	fireflies.emission_box_extents = Vector3(VIEW_SIZE.x / 2.0, VIEW_SIZE.y / 2.0, 1.0)
	fireflies.direction = Vector2(0, -1)
	fireflies.spread = 180.0
	fireflies.gravity = Vector2(0, -8)
	fireflies.initial_velocity_min = 10.0
	fireflies.initial_velocity_max = 25.0
	fireflies.scale_amount_min = 0.8
	fireflies.scale_amount_max = 1.6
	fireflies.color = _firefly_calm
	fireflies.color_ramp = _make_fade_ramp()
	fireflies.texture = _make_dot_texture(12)
	add_child(fireflies)


func _setup_fog() -> void:
	fog = CPUParticles2D.new()
	fog.position = Vector2(VIEW_SIZE.x / 2.0, 290.0)
	fog.amount = 10
	fog.lifetime = 9.0
	fog.preprocess = 9.0
	fog.lifetime_randomness = 0.3
	fog.emission_shape = CPUParticles2D.EMISSION_SHAPE_BOX
	fog.emission_box_extents = Vector3(VIEW_SIZE.x / 2.0, 50.0, 1.0)
	fog.direction = Vector2(1, 0)
	fog.spread = 25.0
	fog.gravity = Vector2.ZERO
	fog.initial_velocity_min = 8.0
	fog.initial_velocity_max = 18.0
	fog.scale_amount_min = 2.0
	fog.scale_amount_max = 4.0
	fog.color = _fog_calm
	fog.color_ramp = _make_fade_ramp()
	fog.texture = _make_dot_texture(64)
	add_child(fog)


func _play_vignette_breath() -> void:
	if not vignette:
		return
	_vignette_tween = create_tween().set_loops()
	_vignette_tween.tween_property(vignette, "modulate:a", 0.85, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_vignette_tween.tween_property(vignette, "modulate:a", 1.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ------------------------------------------------------------
# REAKTIF
# ------------------------------------------------------------

func _trigger_burst() -> void:
	_burst_active = true
	if _burst_tween and _burst_tween.is_valid():
		_burst_tween.kill()
	_apply_state()
	_burst_tween = create_tween()
	_burst_tween.tween_interval(1.2)
	_burst_tween.tween_callback(_end_burst)


func _end_burst() -> void:
	if _stopped:
		return
	_burst_active = false
	_apply_state()


func _apply_state() -> void:
	if not fireflies or not fog:
		return
	if _burst_active:
		# Hantaman besar: kunang-kunang ngamuk sesaat
		fireflies.amount = 44
		fireflies.speed_scale = 1.9
		fireflies.modulate = Color(1, 1, 1, 1)
		fog.modulate = Color(1, 1, 1, 1.4)
	elif _danger:
		# HP sekarat: kunang redup kemerahan, kabut menebal
		fireflies.amount = 28
		fireflies.speed_scale = 0.8
		fireflies.color = _firefly_danger
		fog.amount = 16
		fog.color = _fog_danger
	else:
		fireflies.amount = 28
		fireflies.speed_scale = 1.0
		fireflies.color = _firefly_calm
		fireflies.modulate = Color(1, 1, 1, 1)
		fog.amount = 10
		fog.color = _fog_calm
		fog.modulate = Color(1, 1, 1, 1)
