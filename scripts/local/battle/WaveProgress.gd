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
var bg_line: Panel        # Background line (always full width, grey)
var fill_line: Panel      # Fill line (animates width, white → green)
var total_line_width: float = 0.0


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
		_animate_travel(old_wave, current_wave)
	else:
		_update_visual()


func advance_wave() -> void:
	if current_wave < total_waves:
		var old_wave := current_wave
		current_wave += 1
		_animate_travel(old_wave, current_wave)
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
	bg_line = null
	fill_line = null

	# Wait for queue_free
	await get_tree().process_frame

	# Hitung posisi dot pertama dan terakhir
	var first_dot_x: float = 0.0
	var last_dot_x: float = 0.0
	var x_offset: float = 0.0

	# Hitung total width untuk centering
	var used_width: float = (total_waves * dot_size) + ((total_waves - 1) * (dot_size + dot_spacing * 2))
	var center_offset: float = (size.x - used_width) / 2.0
	center_offset = maxf(center_offset, 0.0)
	x_offset = center_offset

	# Create dots
	for i in range(total_waves):
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

		if i == 0:
			first_dot_x = x_offset
		if i == total_waves - 1:
			last_dot_x = x_offset

		x_offset += dot_size + dot_spacing

	# Single continuous line dari dot pertama ke dot terakhir
	total_line_width = last_dot_x - first_dot_x + dot_size
	
	# Background line (always full width, grey)
	bg_line = Panel.new()
	bg_line.name = "BackgroundLine"
	bg_line.position = Vector2(first_dot_x, (dot_size - line_height) / 2.0)
	bg_line.size = Vector2(total_line_width, line_height)
	bg_line.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg_style := StyleBoxFlat.new()
	bg_style.set_corner_radius_all(1)
	bg_style.bg_color = inactive_color
	bg_line.add_theme_stylebox_override("panel", bg_style)
	add_child(bg_line)
	
	# Fill line (animates width, sits on top of bg_line)
	fill_line = Panel.new()
	fill_line.name = "FillLine"
	fill_line.position = Vector2(first_dot_x, (dot_size - line_height) / 2.0)
	fill_line.size = Vector2(0.0, line_height)  # Start at 0 width
	fill_line.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var fill_style := StyleBoxFlat.new()
	fill_style.set_corner_radius_all(1)
	fill_style.bg_color = inactive_color
	fill_line.add_theme_stylebox_override("panel", fill_style)
	add_child(fill_line)

	_update_visual()


func _update_visual() -> void:
	# Update dots
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

	# Update fill line width berdasarkan active dot
	if fill_line and is_instance_valid(fill_line):
		# Width = jarak dari dot pertama ke active dot
		var active_dot_index: int = current_wave - 1
		var target_width: float = 0.0
		
		if active_dot_index > 0:
			var first_dot_x: float = dot_panels[0].position.x
			var active_dot_x: float = dot_panels[active_dot_index].position.x
			target_width = active_dot_x - first_dot_x
		
		fill_line.size.x = target_width
		
		# Warna fill line
		var fill_style: StyleBoxFlat = fill_line.get_theme_stylebox("panel").duplicate()
		if current_wave >= total_waves:
			fill_style.bg_color = completed_color  # Semua selesai
		elif current_wave > 1:
			fill_style.bg_color = completed_color  # Ada yang selesai
		else:
			fill_style.bg_color = inactive_color  # Belum ada yang selesai
		fill_line.add_theme_stylebox_override("panel", fill_style)


# ============================================================
# ANIMATION
# ============================================================

func _animate_travel(from_wave: int, to_wave: int) -> void:
	if not fill_line or not is_instance_valid(fill_line):
		_update_visual()
		return
	
	# Hitung target width
	var target_dot_index: int = to_wave - 1
	var target_width: float = 0.0
	
	if target_dot_index > 0:
		var first_dot_x: float = dot_panels[0].position.x
		var target_dot_x: float = dot_panels[target_dot_index].position.x
		target_width = target_dot_x - first_dot_x
	
	# Set fill line color = white (traveling) dan width = 0
	var fill_style: StyleBoxFlat = fill_line.get_theme_stylebox("panel").duplicate()
	fill_style.bg_color = traveling_color
	fill_line.add_theme_stylebox_override("panel", fill_style)
	fill_line.size.x = 0.0
	
	# Animate width ke target
	var tw := create_tween()
	tw.tween_property(fill_line, "size:x", target_width, line_travel_duration)\
		.set_trans(line_travel_trans).set_ease(Tween.EASE_OUT)
	
	# Setelah sampai, ganti warna ke completed + grow dot
	tw.tween_callback(func() -> void:
		# Fill line color → completed
		var final_style: StyleBoxFlat = fill_line.get_theme_stylebox("panel").duplicate()
		final_style.bg_color = completed_color
		fill_line.add_theme_stylebox_override("panel", final_style)
		
		# Grow active dot
		_animate_dot_grow(to_wave - 1)
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