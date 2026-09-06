extends Control
class_name ChargeAttackUI

signal charge_complete(multiplier: float)

# ============================================================
# NODE REFERENCES
# ============================================================

@onready var charge_panel: Panel = $chargePanel
@onready var button_charge: Button = $chargePanel/ButtonCharge
@onready var charge_progress: Panel = $chargePanel/chargeProgress
@onready var zone_high: Panel = $chargePanel/high
@onready var zone_normal: Panel = $chargePanel/normal
@onready var zone_low: Panel = $chargePanel/low

# ============================================================
# STATE
# ============================================================

var is_charging: bool = false
var charge_value: float = 0.0
var charge_speed: float = 1.8
var charge_direction: float = 1.0
var max_charge_time: float = 2.0
var hold_timer: float = 0.0

# Simpan bounds & size sekali dari scene
var progress_top: float = 0.0
var progress_bottom: float = 0.0
var panel_size_cache: Vector2 = Vector2.ZERO

# ============================================================
# ZONE MULTIPLIERS
# ============================================================

const ZONE_HIGH_MULTIPLIER: float = 2.0
const ZONE_NORMAL_MULTIPLIER: float = 1.5
const ZONE_LOW_MULTIPLIER: float = 1.0

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	visible = false
	button_charge.button_down.connect(_on_button_down)
	button_charge.button_up.connect(_on_button_up)

	if charge_progress:
		progress_top = charge_progress.offset_top
		progress_bottom = charge_progress.offset_bottom

	# Cache original panel size
	if charge_panel:
		panel_size_cache = Vector2(
			charge_panel.offset_right - charge_panel.offset_left,
			charge_panel.offset_bottom - charge_panel.offset_top
		)

	# Wrap in CanvasLayer biar gak terpengaruh Camera2D zoom
	var cl := CanvasLayer.new()
	cl.layer = 10
	get_parent().add_child(cl)
	get_parent().remove_child(self)
	cl.add_child(self)

	# CanvasLayer bukan Control, jadi anchors gak work — set manual
	var viewport_size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = viewport_size
	anchors_preset = 0
	anchor_right = 0.0
	anchor_bottom = 0.0


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


# ============================================================
# SHOW / HIDE
# ============================================================

func show_charge() -> void:
	# Center chargePanel di viewport — SAMA PERSIS kayak attackQte
	var viewport_size = get_viewport().get_visible_rect().size
	charge_panel.offset_left = (viewport_size.x - panel_size_cache.x) * 0.5
	charge_panel.offset_top = (viewport_size.y - panel_size_cache.y) * 0.5
	charge_panel.offset_right = charge_panel.offset_left + panel_size_cache.x
	charge_panel.offset_bottom = charge_panel.offset_top + panel_size_cache.y

	visible = true
	move_to_front()

	charge_value = 0.0
	charge_direction = 1.0
	hold_timer = 0.0
	is_charging = false

	# Reset progress bar
	if charge_progress:
		charge_progress.position.y = progress_top
		charge_progress.size.y = progress_bottom - progress_top
	_update_progress_bar()

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
	)


# ============================================================
# CHARGE LOGIC
# ============================================================

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


# ============================================================
# ZONE DETECTION
# ============================================================

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


# ============================================================
# VISUAL
# ============================================================

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
