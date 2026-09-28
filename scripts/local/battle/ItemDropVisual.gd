extends Button
class_name ItemDropVisual

# Signal ketika item di-click / magnet sampai (bawa visual biar bisa confirm/cancel)
signal item_clicked(item: ItemData, visual: ItemDropVisual)
# Signal abis fade collect kelar (buat save final)
signal collect_finished(item: ItemData)

# ============================================================
# DATA
# ============================================================
var item_data: ItemData = null
var is_collected: bool = false
var magnet_flying: bool = false
var magnet_target: Vector2 = Vector2.ZERO
var magnet_speed: float = 650.0
var magnet_fly_time: float = 0.0
const MAGNET_MAX_FLY := 2.0

# ============================================================
# CONSTANTS
# ============================================================
const ICON_SIZE := Vector2(48, 48)
const POP_DURATION := 0.4
const FLOAT_AMPLITUDE := 3.0
const FLOAT_SPEED := 2.0
const DESPAWN_TIME := 8.0
const MAGNET_DELAY := 1.0

# ============================================================
# BASE POSITION (untuk float effect)
# ============================================================
var base_position: Vector2 = Vector2.ZERO

# ============================================================
# SETUP
# ============================================================
func setup(item: ItemData, spawn_pos: Vector2, magnet_pos: Vector2 = Vector2.ZERO, spawn_delay: float = 0.0) -> void:
	item_data = item
	base_position = spawn_pos
	position = spawn_pos
	magnet_target = magnet_pos
	custom_minimum_size = Vector2(56, 56)
	size = Vector2(56, 56)
	pivot_offset = size / 2.0
	flat = true
	focus_mode = Control.FOCUS_NONE
	
	# Icon item
	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = ICON_SIZE
	icon.anchors_preset = Control.PRESET_CENTER
	icon.offset_left = -ICON_SIZE.x / 2.0
	icon.offset_top = -ICON_SIZE.y / 2.0
	icon.offset_right = ICON_SIZE.x / 2.0
	icon.offset_bottom = ICON_SIZE.y / 2.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	
	# Style button transparan dengan border gold
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.05, 0.05, 0.08, 0.8)
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.85, 0.7, 0.2, 0.9)
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("normal", normal_style)
	
	# Hover style
	var hover_style := normal_style.duplicate()
	hover_style.border_color = Color(1.0, 0.9, 0.3, 1.0)
	hover_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	add_theme_stylebox_override("hover", hover_style)
	
	# Pressed style
	var pressed_style := normal_style.duplicate()
	pressed_style.border_color = Color(1.0, 0.85, 0.2, 1.0)
	pressed_style.bg_color = Color(0.15, 0.12, 0.05, 0.95)
	add_theme_stylebox_override("pressed", pressed_style)
	
	pressed.connect(_on_pressed)
	
	# Despawn timer
	var timer := Timer.new()
	timer.wait_time = DESPAWN_TIME
	timer.one_shot = true
	timer.timeout.connect(_on_timeout)
	add_child(timer)
	timer.start()

	# Magnet timer: terbang sendiri ke tas kalau gak diklik
	var magnet := Timer.new()
	magnet.wait_time = MAGNET_DELAY
	magnet.one_shot = true
	magnet.timeout.connect(_on_magnet_timeout)
	add_child(magnet)
	magnet.start()
	
	# Mulai dari kecil dan transparan
	scale = Vector2.ZERO
	modulate.a = 0.0

	# Start animasi (stagger per index biar pop-nya gantian)
	_play_spawn_animation(spawn_delay)

# ============================================================
# ANIMASI SPAWN (POP OUT)
# ============================================================
func _play_spawn_animation(spawn_delay: float = 0.0) -> void:
	var tween := create_tween().set_parallel(true)

	# Scale pop: 0 -> 1.2 -> 1.0 (overshoot effect)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), POP_DURATION * 0.6)\
		.set_delay(spawn_delay)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self, "scale", Vector2(1.0, 1.0), POP_DURATION * 0.4)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Fade in
	tween.tween_property(self, "modulate:a", 1.0, POP_DURATION * 0.3)\
		.set_delay(spawn_delay)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Glow pulse mulai setelah spawn selesai
	tween.chain().tween_callback(_start_glow_pulse)

# ============================================================
# GLOW PULSE (looping border color)
# ============================================================
var _glow_tween: Tween

func _start_glow_pulse() -> void:
	if is_collected:
		return
	
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_method(_set_border_color, Color(0.85, 0.7, 0.2, 0.9), Color(1.0, 0.95, 0.4, 1.0), 1.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glow_tween.tween_method(_set_border_color, Color(1.0, 0.95, 0.4, 1.0), Color(0.85, 0.7, 0.2, 0.9), 1.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_border_color(color: Color) -> void:
	if not is_instance_valid(self):
		return
	var style := get_theme_stylebox("normal") as StyleBoxFlat
	if style:
		style.border_color = color

# ============================================================
# FLOAT ANIMATION
# ============================================================
func _process(delta: float) -> void:
	# Magnet: jalan deterministik via move_toward + failsafe waktu.
	# Kalau 2 detik belum sampe (kasus aneh), snap paksa ke target.
	if magnet_flying:
		magnet_fly_time += delta
		position = position.move_toward(magnet_target, magnet_speed * delta)
		if magnet_fly_time >= MAGNET_MAX_FLY:
			position = magnet_target
		if magnet_fly_time >= MAGNET_MAX_FLY or position.distance_to(magnet_target) < 4.0:
			magnet_flying = false
			item_clicked.emit(item_data, self)
		return
	if is_collected:
		return
	position.y = base_position.y + sin(Time.get_ticks_msec() * 0.001 * FLOAT_SPEED) * FLOAT_AMPLITUDE

# ============================================================
# CLICK HANDLER (cuma minta, eksekusi di confirm/cancel)
# ============================================================
func _on_pressed() -> void:
	if is_collected or not item_data:
		return
	item_clicked.emit(item_data, self)

# ============================================================
# KUMPULKAN ITEM (dipanggil handler kalau slot ada)
# ============================================================
func confirm_collect() -> void:
	if is_collected or not item_data:
		return

	is_collected = true

	if _glow_tween:
		_glow_tween.kill()

	# Animasi collect: scale up + fade out
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.chain().tween_callback(func() -> void:
		collect_finished.emit(item_data)
		queue_free()
	)


# ============================================================
# BATAL (dipanggil handler kalau inventory penuh)
# ============================================================
func cancel_collect() -> void:
	# Balikin ke kondisi idle: tetep bisa diklik / ke-magnet lagi.
	# Kalau posisi lagi off-screen (cancel abis magnet), tarik balik ke layar.
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if position.x < 0.0 or position.y > vp.y or position.x > vp.x or position.y < 0.0:
		position = Vector2(vp.x * 0.5 - 28.0, vp.y - 70.0)
	is_collected = false
	magnet_flying = false
	magnet_fly_time = 0.0
	base_position = position
	scale = Vector2.ONE
	modulate.a = 1.0
	_start_glow_pulse()


# ============================================================
# MAGNET OTOMATIS
# ============================================================
func _on_magnet_timeout() -> void:
	if is_collected or not item_data:
		return

	# Claim dulu biar despawn timer + klik gak rebutan.
	# Geraknya di _process (move_toward) biar gak bisa macet.
	is_collected = true
	magnet_flying = true
	magnet_fly_time = 0.0
	if _glow_tween:
		_glow_tween.kill()

# ============================================================
# DESPAWN OTOMATIS
# ============================================================
func _on_timeout() -> void:
	if is_collected:
		return
	
	is_collected = true
	
	if _glow_tween:
		_glow_tween.kill()
	
	# Animasi fade out perlahan
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	tween.chain().tween_callback(queue_free)
