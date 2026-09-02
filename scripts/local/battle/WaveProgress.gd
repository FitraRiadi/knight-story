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

@export var dot_border_color: Color = Color(0.2, 0.2, 0.2, 0.6)
@export var dot_border_width: int = 2


# ============================================================
# STATE
# ============================================================

var dot_panels: Array[Panel] = []
var line_rects: Array[ColorRect] = []


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
	current_wave = current
	_update_visual()


func advance_wave() -> void:
	if current_wave < total_waves:
		current_wave += 1
		_update_visual()
		wave_completed.emit(current_wave)
		
		if current_wave >= total_waves:
			all_waves_completed.emit()


func reset() -> void:
	current_wave = 1
	_update_visual()


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

	# Hitung total width
	var total_nodes: int = total_waves + (total_waves - 1)  # dots + lines
	var total_width: float = (total_waves * dot_size) + ((total_waves - 1) * (line_width + dot_spacing * 2))
	custom_minimum_size = Vector2(total_width, dot_size)
	size = Vector2(total_width, dot_size)

	# Pivot ke center
	pivot_offset = Vector2(total_width / 2.0, dot_size / 2.0)

	var x_offset: float = 0.0

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

		# === LINE (kecuali setelah dot terakhir) ===
		if i < total_waves - 1:
			var line := ColorRect.new()
			line.name = "Line_" + str(i)
			line.custom_minimum_size = Vector2(line_width, line_height)
			line.size = Vector2(line_width, line_height)
			line.position = Vector2(x_offset, (dot_size - line_height) / 2.0)
			line.color = inactive_color
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
			# Completed
			style.bg_color = completed_color
			style.border_color = completed_color.darkened(0.2)
		elif i == current_wave - 1:
			# Active
			style.bg_color = active_color
			style.border_color = active_color.darkened(0.2)
		else:
			# Inactive
			style.bg_color = inactive_color
			style.border_color = dot_border_color

		dot.add_theme_stylebox_override("panel", style)

	# Update lines
	for i in range(line_rects.size()):
		var line: ColorRect = line_rects[i]
		if not is_instance_valid(line):
			continue

		if i < current_wave - 1:
			line.color = completed_color
		elif i == current_wave - 1:
			line.color = active_color
		else:
			line.color = inactive_color
