extends Node2D
class_name BattleAtmosphere

# ============================================================
# BATTLE ATMOSPHERE
# Ambient battle: kunang-kunang + kabut + vignette gelap.
# Dibuat code-based (tanpa ubah .tscn) biar aman dari @onready $ paths.
# GPUParticles2D + ParticleProcessMaterial (pola yang sama kayak village.gd),
# total < 50 partikel biar ringan di Android.
# Parent = root battlemode (screen-space 740x340), BUKAN Camera2D
# biar gak ikut zoom 1.10x pas rapid attack.
# ============================================================

const VIEW_SIZE := Vector2(740.0, 340.0)

var fireflies: GPUParticles2D = null
var fog: GPUParticles2D = null
var vignette: TextureRect = null
var _firefly_pm: ParticleProcessMaterial = null
var _fog_pm: ParticleProcessMaterial = null

var _burst_active: bool = false
var _danger: bool = false
var _burst_tween: Tween = null
var _pulse_tween: Tween = null
var _vignette_tween: Tween = null
var _stopped: bool = false

# Kunang permanen = gaya pulse sekarat: merah redup, gerak lemes.
# (Dulu hijau terang ngebut = terlalu mencolok.) Pas HP kritis kunang
# SENGAJA gak diubah lagi, yang kerja cuma kabut + vignette.
var _firefly_calm := Color(1.0, 0.45, 0.3, 0.65)
var _fog_calm := Color(0.6, 0.7, 0.65, 0.10)
var _fog_danger := Color(0.55, 0.6, 0.6, 0.16)

# Tier LOW (HP kentang): jumlah fix kecil, tanpa color_ramp texture,
# vignette datar. HIGH = full seperti biasa.
var _low_mode := false
var _base_fireflies := 28
var _base_fog := 10
var _burst_fireflies := 44
var _danger_fog := 16


func setup(battle_root: Control) -> void:
	battle_root.add_child(self)
	# Duduk tepat di atas bg (index 0), di bawah semua UI/enemy
	battle_root.move_child(self, 1)
	_low_mode = GameSettings.get_effective_tier() == "low"
	if _low_mode:
		_base_fireflies = 16
		_base_fog = 6
		_burst_fireflies = 16
		_danger_fog = 6
	print("[Atmosphere] tier=", GameSettings.get_effective_tier(), " low=", _low_mode)
	_setup_vignette()
	_setup_fireflies()
	_setup_fog()
	_apply_state()
	_play_vignette_breath()


func update_mood(big_hit: bool, hp_low: bool) -> void:
	if _stopped:
		return
	_danger = hp_low
	if big_hit:
		_trigger_burst()
	else:
		_apply_state()


func burst() -> void:
	# Versi publik burst gede (parry jackpot dkk): jumlah + speed + fog 1.2 dtk
	if _stopped:
		return
	_trigger_burst()


func pulse(duration: float = 0.3) -> void:
	# Micro-surge: kunang ngebut + flash sesaat (parry/hit), balik sendiri.
	# Cuma speed + modulate, jumlah gak diubah biar murah. Revert via _apply_state
	# biar nurut sama burst/danger yang lagi aktif.
	if _stopped or not fireflies:
		return
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	fireflies.speed_scale = 8.0
	fireflies.modulate = Color(1.6, 1.6, 1.6, 1.0)
	_pulse_tween = create_tween()
	_pulse_tween.tween_interval(duration)
	_pulse_tween.tween_callback(_end_pulse)


func _end_pulse() -> void:
	if _stopped:
		return
	_apply_state()


func stop() -> void:
	_stopped = true
	if _burst_tween and _burst_tween.is_valid():
		_burst_tween.kill()
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
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

func _make_fade_ramp() -> GradientTexture1D:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	return ramp_tex


func _make_streak_texture(w: int = 8, h: int = 32) -> ImageTexture:
	# Jarum vertikal tipis, lancip atas-bawah (bukan dot bulet).
	# Generate sekali pas setup, murah (8x32 px).
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx: float = (float(w) - 1.0) / 2.0
	for y in h:
		var v: float = float(y) / float(h - 1)
		var taper: float = pow(sin(v * PI), 1.5)  # 0 di ujung -> lancip
		for x in w:
			var dx: float = absf(float(x) - cx) / (cx + 0.001)
			var core: float = pow(clampf(1.0 - dx, 0.0, 1.0), 2.0)  # tipis di tengah
			img.set_pixel(x, y, Color(1, 1, 1, clampf(core * taper, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _setup_vignette() -> void:
	if _low_mode:
		# LOW: vignette dimatikan total (gradient fullscreen = overdraw mahal)
		return
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
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(vignette)


func _setup_fireflies() -> void:
	fireflies = GPUParticles2D.new()
	fireflies.position = VIEW_SIZE / 2.0
	fireflies.amount = _base_fireflies
	fireflies.lifetime = 5.0
	fireflies.preprocess = 5.0
	fireflies.texture = _make_streak_texture()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(VIEW_SIZE.x / 2.0, VIEW_SIZE.y / 2.0, 1.0)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.gravity = Vector3(0, -8, 0)
	pm.initial_velocity_min = 20.0
	pm.initial_velocity_max = 50.0
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	pm.color = _firefly_calm
	if not _low_mode:
		pm.color_ramp = _make_fade_ramp()
	fireflies.process_material = pm
	_firefly_pm = pm
	add_child(fireflies)


func _setup_fog() -> void:
	fog = GPUParticles2D.new()
	fog.position = Vector2(VIEW_SIZE.x / 2.0, 290.0)
	fog.amount = _base_fog
	fog.lifetime = 9.0
	fog.preprocess = 9.0
	fog.texture = _make_dot_texture(64)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(VIEW_SIZE.x / 2.0, 50.0, 1.0)
	pm.direction = Vector3(1, 0, 0)
	pm.spread = 25.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 18.0
	pm.scale_min = 2.0
	pm.scale_max = 4.0
	pm.color = _fog_calm
	if not _low_mode:
		pm.color_ramp = _make_fade_ramp()
	fog.process_material = pm
	_fog_pm = pm
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
	if not fireflies or not fog or not _firefly_pm or not _fog_pm:
		return
	fireflies.modulate = Color(1, 1, 1, 1)
	if _burst_active:
		# Hantaman besar: kunang-kunang ngamuk sesaat (LOW: speed doang, no realloc)
		_set_fireflies_amount(_burst_fireflies)
		fireflies.speed_scale = 1.9
		fireflies.modulate = Color(1, 1, 1, 1)
		fog.modulate = Color(1, 1, 1, 1.4)
	elif _danger:
		# HP sekarat: kunang SENGAJA gak diubah (udah merah redup permanen),
		# yang menebal cuma kabut.
		_set_fireflies_amount(_base_fireflies)
		_set_fog_amount(_danger_fog)
		_fog_pm.color = _fog_danger
	else:
		_set_fireflies_amount(_base_fireflies)
		fireflies.speed_scale = 0.8
		_firefly_pm.color = _firefly_calm
		fireflies.modulate = Color(1, 1, 1, 1)
		_set_fog_amount(_base_fog)
		_fog_pm.color = _fog_calm
		fog.modulate = Color(1, 1, 1, 1)


func _set_fireflies_amount(v: int) -> void:
	# Guard: ganti amount me-realloc pool partikel (kedip), jadi cuma pas beda
	if fireflies.amount != v:
		fireflies.amount = v


func _set_fog_amount(v: int) -> void:
	if fog.amount != v:
		fog.amount = v
