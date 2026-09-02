extends Control
class_name WaveProgress


# ============================================================
# SIGNALS
# ============================================================

signal wave_completed(wave: int)
signal all_waves_completed()


# ============================================================
# PROPERTIES
# ============================================================

@export_group("Wave Settings")

## Total wave dalam battle
@export var total_waves: int = 3:
	set(value):
		total_waves = maxi(2, value)
		_rebuild_ui()

## Wave saat ini (1-indexed)
@export var current_wave: int = 1:
	set(value):
		current_wave = clampi(value, 1, total_waves)
		_update_visual()


# ============================================================
# VISUAL SETTINGS
# ============================================================

@export_group("Visual")

@export var dot_size: float = 12.0
@export var line_width: float = 16.0
@export var line_height: float = 3.0
@export var dot_spacing: float = 4.0

@export var active_color: Color = Color(1.0, 0.85, 0.2, 1.0)
@export var completed_color: Color = Color(0.3, 0.8, 0.2, 1.0)
@export var inactive_color: Color = Color(0.35, 0.35, 0.35, 0.8)
@export var traveling_color: Color = Color(1.0, 1.0, 1.0, 1.0)  # Putih

@export var dot_border_color: Color = Color(0.2, 0.2, 0.2, 0.6)
@export var dot_border_width: int = 2


# ============================================================
# ANIMATION SETTINGS
# ============================================================

@export_group("Animation")

@export var line_travel_duration: float = 0.4
@export var line_travel_trans: Tween.TransitionType = Tween.TRANS_CIRC
@export var dot_grow_scale: float = 1.4
@export var dot_grow_duration: float = 0.3
@export var dot_grow_trans: Tween.TransitionType = Tween.TRANS_ELASTIC


# ============================================================
# STATE
# ============================================================

var dot_panels: Array[Panel] = []
var line_rects: Array[Panel] = []  # Changed to Panel for width animation


# ============================================================
# BUILT-IN
# ============================================================

func _ready() -> void:
	_rebuild_ui()


# ============================================================
# PUBLIC API
# ============================================================

func set_wave(current: int, total: int = -1) -> void:
	if total > 0:
		total_waves = total
	var old_wave := current_wave
	current_wave = current
	
	# Animate if advancing
	if current_wave > old_wave and current_wave <= total_waves:
		_animate_travel(old_wave - 1, current_wave - 1)
	else:
		_update_visual()


func advance_wave() -> void:
	if current_wave < total_waves:
		var old_wave := current_wave
		current_wave += 1
		_animate_travel(old_wave - 1, current_wave - 1)
		wave_completed.emit(current_wave)
		
		if current_wave >= total_waves:
			all_waves_completed.emit()


func reset() -> void:
	current_wave = 1
	_rebuild_ui()


# ============================================================
# UI BUILD
# ============================================================

func _rebuild_ui() -> void:
	# Clear existing
	for child in get_children():
		child.queue_free()
	dot_panels.clear()
	line_rects.clear()

	# Wait for queue_free
	await get_tree().process_frame

	# Hitung total width yang dipakai
	var used_width: float = (total_waves * dot_size) + ((total_waves - 1) * (line_width + dot_spacing * 2))

	# Hitung center offset
	var center_offset: float = (size.x - used_width) / 2.0
	center_offset = maxf(center_offset, 0.0)

	var x_offset: float = center_offset

	for i in range(total_waves):
		# === DOT ===
		var dot := Panel.new()
		dot.name = "Dot_" + str(i)
		dot.custom_minimum_size = Vector2(dot_size, dot_size)
		dot.size = Vector2(dot_size, dot_size)
		dot.position = Vector2(x_offset, 0)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(int(dot_size / 2.0))
		style.set_border_width_all(dot_border_width)
		style.border_color = dot_border_color
		style.bg_color = inactive_color
		dot.add_theme_stylebox_override("panel", style)
		add_child(dot)
		dot_panels.append(dot)

		x_offset += dot_size + dot_spacing

		# === LINE (Panel for width animation) ===
		if i < total_waves - 1:
			var line := Panel.new()
			line.name = "Line_" + str(i)
			line.custom_minimum_size = Vector2(line_width, line_height)
			line.size = Vector2(line_width, line_height)
			line.position = Vector2(x_offset, (dot_size - line_height) / 2.0)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var line_style := StyleBoxFlat.new()
			line_style.set_corner_radius_all(1)
			line_style.bg_color = inactive_color
			line.add_theme_stylebox_override("panel", line_style)
			add_child(line)
			line_rects.append(line)

			x_offset += line_width + dot_spacing

	_update_visual()


func _update_visual() -> void:
	for i in range(dot_panels.size()):
		var dot: Panel = dot_panels[i]
		if not is_instance_valid(dot):
			continue

		var style: StyleBoxFlat = dot.get_theme_stylebox("panel").duplicate()

		if i < current_wave - 1:
			style.bg_color = completed_color
			style.border_color = completed_color.darkened(0.2)
		elif i == current_wave - 1:
			style.bg_color = active_color
			style.border_color = active_color.darkened(0.2)
		else:
			style.bg_color = inactive_color
			style.border_color = dot_border_color

		dot.add_theme_stylebox_override("panel", style)

	# Update lines
	for i in range(line_rects.size()):
		var line: Panel = line_rects[i]
		if not is_instance_valid(line):
			continue

		var line_style: StyleBoxFlat = line.get_theme_stylebox("panel").duplicate()

		if i < current_wave - 1:
			line_style.bg_color = completed_color
		elif i == current_wave - 1:
			line_style.bg_color = active_color
		else:
			line_style.bg_color = inactive_color

		line.add_theme_stylebox_override("panel", line_style)
		line.size.x = line_width  # Reset width


# ============================================================
# ANIMATION - TRAVEL
# ============================================================

func _animate_travel(from_index: int, to_index: int) -> void:
	# to_index = dot yang baru aktif (0-indexed)
	# Line yang dianimate = line_rects[from_index] (garis sebelum dot baru)
	
	if from_index < 0 or from_index >= line_rects.size():
		# No line to animate (first wave)
		_animate_dot_grow(to_index)
		_update_visual()
		return
	
	var line: Panel = line_rects[from_index]
	if not is_instance_valid(line):
		_animate_dot_grow(to_index)
		_update_visual()
		return
	
	# Step 1: Set line width = 0, color = white (traveling)
	var line_style: StyleBoxFlat = line.get_theme_stylebox("panel").duplicate()
	line_style.bg_color = traveling_color
	line.add_theme_stylebox_override("panel", line_style)
	line.size.x = 0.0
	
	# Step 2: Animate line width ke full (traveling)
	var tw := create_tween()
	tw.tween_property(line, "size:x", line_width, line_travel_duration)\
		.set_trans(line_travel_trans).set_ease(Tween.EASE_OUT)
	
	# Step 3: Setelah line sampai, ganti warna ke completed + grow dot
	tw.tween_callback(func() -> void:
		# Line color → completed
		var final_style: StyleBoxFlat = line.get_theme_stylebox("panel").duplicate()
		final_style.bg_color = completed_color
		line.add_theme_stylebox_override("panel", final_style)
		
		# Grow dot
		_animate_dot_grow(to_index)
		_update_visual()
	)


# ============================================================
# ANIMATION - DOT GROW
# ============================================================

func _animate_dot_grow(dot_index: int) -> void:
	if dot_index < 0 or dot_index >= dot_panels.size():
		return
	
	var dot: Panel = dot_panels[dot_index]
	if not is_instance_valid(dot):
		return
	
	# Scale up
	var tw := create_tween()
	tw.tween_property(dot, "scale", Vector2(dot_grow_scale, dot_grow_scale), 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Scale back with elastic bounce
	tw.tween_property(dot, "scale", Vector2.ONE, dot_grow_duration)\
		.set_trans(dot_grow_trans).set_ease(Tween.EASE_OUT)
