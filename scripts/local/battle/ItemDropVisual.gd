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
var toss_done: bool = false
var toss_dir: float = 1.0
var shimmer: CPUParticles2D = null
var name_label: Label = null
const POP_DURATION := 0.4
const FLOAT_AMPLITUDE := 3.0
const FLOAT_SPEED := 2.0
const DESPAWN_TIME := 8.0
const AUTO_COLLECT_DELAY := 1.2

# ============================================================
# BASE POSITION (untuk float effect)
# ============================================================
var base_position: Vector2 = Vector2.ZERO

# ============================================================
# SETUP
# ============================================================
func setup(item: ItemData, spawn_pos: Vector2, ground_pos: Vector2 = Vector2.ZERO, spawn_delay: float = 0.0) -> void:
	item_data = item
	# Mendarat di tanah (ground_pos), bukan di badan musuh
	if ground_pos == Vector2.ZERO:
		ground_pos = spawn_pos
	toss_dir = signf(ground_pos.x - spawn_pos.x)
	if toss_dir == 0.0:
		toss_dir = 1.0
	base_position = ground_pos
	position = spawn_pos
	visible = true
	# Ukuran + pivot ngikutin template scene (jangan override)
	pivot_offset = size / 2.0
	flat = true
	focus_mode = Control.FOCUS_NONE

	# Icon item: pakai TextureRect bawaan template
	var icon := get_node_or_null("TextureRect") as TextureRect
	if icon:
		icon.texture = item.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Label nama: pakai Label bawaan template (muncul pas mendarat)
	name_label = get_node_or_null("Label") as Label
	if name_label:
		name_label.text = item.item_name
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.modulate.a = 0.0
	# Shimmer loop
	_start_shimmer()
	
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
	
	# Guard: duplicate bisa bawa koneksi lama
	if pressed.is_connected(_on_pressed):
		pressed.disconnect(_on_pressed)
	pressed.connect(_on_pressed)
	
	# Despawn timer
	var timer := Timer.new()
	timer.wait_time = DESPAWN_TIME
	timer.one_shot = true
	timer.timeout.connect(_on_timeout)
	add_child(timer)
	timer.start()

	# Auto-collect timer: ambil sendiri tanpa klik
	var auto := Timer.new()
	auto.wait_time = AUTO_COLLECT_DELAY
	auto.one_shot = true
	auto.timeout.connect(_on_auto_timeout)
	add_child(auto)
	auto.start()
	
	# Mulai dari kecil dan transparan
	scale = Vector2.ZERO
	modulate.a = 0.0

	# Start animasi (stagger per index biar pop-nya gantian)
	_play_spawn_animation(spawn_delay)
	# Toss: melambung dari badan musuh terus jatoh ke tanah + squash pas mendarat
	_play_toss_animation(spawn_delay)

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


func _play_toss_animation(spawn_delay: float = 0.0) -> void:
	# Lempar ke atas dikit terus jatoh BOUNCE ke tanah (tanpa squash)
	var tw := create_tween()
	tw.tween_interval(spawn_delay)
	tw.tween_property(self, "position:x", base_position.x, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "position:y", position.y - 50.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", base_position.y, 0.27).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		toss_done = true
		base_position = position
		_play_land_settle()
		if name_label:
			var fade_tw := create_tween()
			fade_tw.tween_property(name_label, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)


func _play_land_settle() -> void:
	# Stagger smooth: ngesot searah lemparan + geter halus (tanpa menciut)
	var end_x := base_position.x + toss_dir * 22.0
	var st := create_tween()
	st.tween_property(self, "position:x", end_x, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Geter: goyang x mengecil 3x
	st.tween_property(self, "position:x", end_x - toss_dir * 4.0, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	st.tween_property(self, "position:x", end_x + toss_dir * 2.5, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	st.tween_property(self, "position:x", end_x, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	st.tween_callback(func() -> void:
		base_position = position
	)

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


func _make_dot() -> GradientTexture2D:
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = Gradient.new()
	grad_tex.gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(1.0, 0.5)
	grad_tex.width = 12
	grad_tex.height = 12
	return grad_tex


func _start_shimmer() -> void:
	if shimmer:
		return
	shimmer = CPUParticles2D.new()
	shimmer.amount = 5
	shimmer.lifetime = 1.4
	shimmer.preprocess = 1.4
	shimmer.emitting = true
	shimmer.direction = Vector2(0, -1)
	shimmer.spread = 25.0
	shimmer.gravity = Vector2(0, -15)
	shimmer.initial_velocity_min = 12.0
	shimmer.initial_velocity_max = 30.0
	shimmer.scale_amount_min = 1.0
	shimmer.scale_amount_max = 2.0
	shimmer.color = Color(1.0, 0.9, 0.5, 0.5)
	shimmer.texture = _make_dot()
	shimmer.position = size * 0.5
	add_child(shimmer)

# ============================================================
# FLOAT ANIMATION
# ============================================================
func _process(_delta: float) -> void:
	if is_collected or not toss_done:
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
	# NOTE: jangan guard is_collected di sini — auto path nge-claim
	# (is_collected=true) SEBELUM emit, jadi guard itu bikin fade gak jalan.
	if not item_data:
		return

	is_collected = true

	if _glow_tween:
		_glow_tween.kill()

	# Squeeze pop-out: kempis -> lenyap + fade, terus save via collect_finished
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.25, 0.6), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.chain().tween_callback(func() -> void:
		collect_finished.emit(item_data)
		queue_free()
	)


# ============================================================
# BATAL (dipanggil handler kalau inventory penuh)
# ============================================================
func cancel_collect() -> void:
	# Balikin ke idle di tempat: tetep ngambang + bisa diklik sampe despawn.
	is_collected = false
	base_position = position
	scale = Vector2.ONE
	modulate.a = 1.0
	_start_glow_pulse()


# ============================================================
# AUTO-COLLECT (tanpa klik, tanpa terbang)
# ============================================================
func _on_auto_timeout() -> void:
	if is_collected or not item_data:
		return

	# Claim dulu biar despawn timer + klik gak rebutan
	is_collected = true
	if _glow_tween:
		_glow_tween.kill()
	item_clicked.emit(item_data, self)

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
