extends Control
class_name ChargeAttackUI

signal charge_complete(multiplier: float)

@onready var charge_panel: Panel = $chargePanel
@onready var button_charge: Button = $chargePanel/ButtonCharge
@onready var charge_progress: Panel = $chargePanel/chargeProgress
@onready var zone_high: Panel = $chargePanel/high
@onready var zone_normal: Panel = $chargePanel/normal
@onready var zone_low: Panel = $chargePanel/low

var is_charging: bool = false
var charge_value: float = 0.0
var charge_speed: float = 1.8
var charge_direction: float = 1.0
var max_charge_time: float = 2.0
var hold_timer: float = 0.0

var progress_top: float = 0.0
var progress_bottom: float = 0.0

const ZONE_HIGH_MULTIPLIER: float = 2.0
const ZONE_NORMAL_MULTIPLIER: float = 1.5
const ZONE_LOW_MULTIPLIER: float = 1.0

const VIEWPORT_SIZE := Vector2(740, 340)

# Visual bounding box dari chargePanel + semua children
var _viz_left: float = 0.0
var _viz_top: float = 0.0
var _viz_right: float = 0.0
var _viz_bottom: float = 0.0
var _viz_size: Vector2 = Vector2.ZERO
var _viz_center_offset: Vector2 = Vector2.ZERO

# Original offsets dari chargePanel (dari scene)
var _orig_offsets: Vector4 = Vector4.ZERO

func _ready() -> void:
	visible = false
	button_charge.button_down.connect(_on_button_down)
	button_charge.button_up.connect(_on_button_up)

	if charge_progress:
		progress_top = charge_progress.offset_top
		progress_bottom = charge_progress.offset_bottom

	# Simpan original offsets
	_orig_offsets = Vector4(
		charge_panel.offset_left,
		charge_panel.offset_top,
		charge_panel.offset_right,
		charge_panel.offset_bottom
	)

	# Hitung visual bounding box (panel + semua children recursive)
	_calc_visual_bounds()


func _calc_visual_bounds() -> void:
	# Mulai dari batas chargePanel sendiri
	_viz_left = charge_panel.offset_left
	_viz_top = charge_panel.offset_top
	_viz_right = charge_panel.offset_right
	_viz_bottom = charge_panel.offset_bottom

	# Expand dengan semua children recursive
	_calc_node_bounds(charge_panel)

	_viz_size = Vector2(_viz_right - _viz_left, _viz_bottom - _viz_top)

	# Offset dari pusat bounding box ke pusat chargePanel
	var panel_cx: float = (_orig_offsets.x + _orig_offsets.z) * 0.5
	var panel_cy: float = (_orig_offsets.y + _orig_offsets.w) * 0.5
	var bbox_cx: float = (_viz_left + _viz_right) * 0.5
	var bbox_cy: float = (_viz_top + _viz_bottom) * 0.5
	_viz_center_offset = Vector2(panel_cx - bbox_cx, panel_cy - bbox_cy)


func _calc_node_bounds(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			var c: Control = child
			# Hitung offset child RELATIVE ke chargePanel
			var rel_left: float = c.offset_left
			var rel_top: float = c.offset_top
			var rel_right: float = c.offset_right
			var rel_bottom: float = c.offset_bottom

			# Traverse hierarchy: offset parent bertambah
			var p = c.get_parent()
			while p != null and p != charge_panel and p is Control:
				rel_left += p.offset_left
				rel_top += p.offset_top
				rel_right += p.offset_right
				rel_bottom += p.offset_bottom
				p = p.get_parent()

			# Expand bounds
			if rel_left < _viz_left:
				_viz_left = rel_left
			if rel_top < _viz_top:
				_viz_top = rel_top
			if rel_right > _viz_right:
				_viz_right = rel_right
			if rel_bottom > _viz_bottom:
				_viz_bottom = rel_bottom

		# Recursive
		if child.get_child_count() > 0:
			_calc_node_bounds(child)


func _process(delta: float) -> void:
	if not is_charging:
		return

	hold_timer += delta
	if hold_timer >= max_charge_time:
		_stop_charge()
		return

	charge_value += charge_direction * charge_speed * delta
	if charge_value >= 1.0:
		charge_value = 1.0
		charge_direction = -1.0
	elif charge_value <= 0.0:
		charge_value = 0.0
		charge_direction = 1.0

	_update_progress_bar()


func show_charge() -> void:
	# Reset chargePanel ke posisi original dulu
	charge_panel.offset_left = _orig_offsets.x
	charge_panel.offset_top = _orig_offsets.y
	charge_panel.offset_right = _orig_offsets.z
	charge_panel.offset_bottom = _orig_offsets.w

	# Shift chargePanel supaya pusat visual bounding box = pusat viewport
	# Posisi yang dibutuhkan: viewport_center - bbox_center
	# Tapi karena offset relatif ke parent, shift-nya adalah:
	var shift: Vector2 = Vector2(
		(VIEWPORT_SIZE.x - _viz_size.x) * 0.5 - _viz_left,
		(VIEWPORT_SIZE.y - _viz_size.y) * 0.5 - _viz_top
	)

	charge_panel.offset_left += shift.x
	charge_panel.offset_top += shift.y
	charge_panel.offset_right += shift.x
	charge_panel.offset_bottom += shift.y

	visible = true
	move_to_front()

	charge_value = 0.0
	charge_direction = 1.0
	hold_timer = 0.0
	is_charging = false

	if charge_progress:
		charge_progress.offset_top = progress_top
		charge_progress.offset_bottom = progress_bottom
	_update_progress_bar()

	pivot_offset = VIEWPORT_SIZE * 0.5
	modulate.a = 0.0
	scale = Vector2(0.5, 0.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_charge() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_property(self, "scale", Vector2(0.8, 0.8), 0.15)
	tw.tween_callback(func() -> void:
		visible = false
		is_charging = false
		# Reset ke original
		charge_panel.offset_left = _orig_offsets.x
		charge_panel.offset_top = _orig_offsets.y
		charge_panel.offset_right = _orig_offsets.z
		charge_panel.offset_bottom = _orig_offsets.w
	)


func _on_button_down() -> void:
	is_charging = true
	charge_value = 0.0
	charge_direction = 1.0
	hold_timer = 0.0


func _on_button_up() -> void:
	_stop_charge()


func _stop_charge() -> void:
	if not is_charging:
		return

	is_charging = false
	var zone := _detect_zone()
	var multiplier := _get_zone_multiplier(zone)

	_flash_zone(zone)

	await get_tree().create_timer(0.3).timeout
	charge_complete.emit(multiplier)


func _detect_zone() -> String:
	if charge_value >= 0.7:
		return "high"
	elif charge_value >= 0.3:
		return "normal"
	else:
		return "low"


func _get_zone_multiplier(zone: String) -> float:
	match zone:
		"high":
			return ZONE_HIGH_MULTIPLIER
		"normal":
			return ZONE_NORMAL_MULTIPLIER
		"low":
			return ZONE_LOW_MULTIPLIER
		_:
			return ZONE_LOW_MULTIPLIER


func _update_progress_bar() -> void:
	if not charge_progress:
		return

	var full_height: float = progress_bottom - progress_top
	var fill_height: float = full_height * charge_value

	charge_progress.size.y = max(fill_height, 1.0)
	charge_progress.position.y = progress_bottom - fill_height

	if charge_value >= 0.7:
		charge_progress.modulate = Color(1.0, 0.95, 0.3, 1.0)
	elif charge_value >= 0.3:
		charge_progress.modulate = Color(1.0, 0.6, 0.2, 1.0)
	else:
		charge_progress.modulate = Color(0.9, 0.2, 0.2, 1.0)


func _flash_zone(zone: String) -> void:
	var zone_node: Panel
	match zone:
		"high":
			zone_node = zone_high
		"normal":
			zone_node = zone_normal
		"low":
			zone_node = zone_low
		_:
			return

	if not zone_node:
		return

	var original_color: Color = zone_node.modulate
	zone_node.modulate = Color.WHITE * 2.0
	var tw := create_tween()
	tw.tween_property(zone_node, "modulate", original_color, 0.3)
