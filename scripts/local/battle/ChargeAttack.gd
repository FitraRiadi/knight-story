extends Control
class_name ChargeAttackUI

signal charge_complete(multiplier: float)
signal charge_started
signal charge_ended

@onready var charge_panel: Panel = $Control/chargePanel
@onready var button_charge: Button = $Control/chargePanel/ButtonCharge
@onready var charge_progress: Panel = $Control/chargePanel/chargeProgress
@onready var zone_high: Panel = $Control/chargePanel/high
@onready var zone_normal: Panel = $Control/chargePanel/normal
@onready var zone_low: Panel = $Control/chargePanel/low
@onready var wrapper: Control = $Control
@onready var title_text2: Label = $Control/chargePanel/title/text2

var _text2_pulse_tween: Tween
var _button_hold_tween: Tween
var _button_velocity_tween: Tween

var is_charging: bool = false
var charge_value: float = 0.0
var charge_speed: float = 1.8
var charge_direction: float = 1.0

var progress_top: float = 0.0
var progress_bottom: float = 0.0

const ZONE_HIGH_MULTIPLIER: float = 2.0
const ZONE_NORMAL_MULTIPLIER: float = 1.5
const ZONE_LOW_MULTIPLIER: float = 1.0

const CENTER_SPAWN := Vector2(380, 180)

# Default wrapper offsets dari scene
var _default_wrapper_offsets: Vector4 = Vector4.ZERO

func _ready() -> void:
	visible = false
	button_charge.gui_input.connect(_on_button_gui_input)

	if charge_progress:
		progress_top = charge_progress.offset_top
		progress_bottom = charge_progress.offset_bottom

	# Cache default wrapper offsets
	if wrapper:
		_default_wrapper_offsets = Vector4(
			wrapper.offset_left,
			wrapper.offset_top,
			wrapper.offset_right,
			wrapper.offset_bottom
		)


func _process(delta: float) -> void:
	if not is_charging:
		return

	charge_value += charge_direction * charge_speed * delta
	if charge_value >= 1.0:
		charge_value = 1.0
		charge_direction = -1.0
	elif charge_value <= 0.0:
		charge_value = 0.0
		charge_direction = 1.0

	_update_progress_bar()


func show_charge(enemy: Node2D = null) -> void:
	visible = true
	move_to_front()

	# Force kill any existing velocity tween from previous charge
	if _button_velocity_tween:
		if _button_velocity_tween.is_running():
			_button_velocity_tween.kill()
		_button_velocity_tween = null

	# Set pivot ke center biar scale dari tengah
	if button_charge:
		var btn_size := Vector2(
			button_charge.offset_right - button_charge.offset_left,
			button_charge.offset_bottom - button_charge.offset_top
		)
		button_charge.pivot_offset = btn_size * 0.5
		button_charge.scale = Vector2.ONE

	# Offset wrapper berdasarkan posisi enemy dari center spawn
	if wrapper and enemy and is_instance_valid(enemy):
		var enemy_offset: Vector2 = enemy.global_position - CENTER_SPAWN
		wrapper.offset_left = _default_wrapper_offsets.x + enemy_offset.x
		wrapper.offset_top = _default_wrapper_offsets.y + enemy_offset.y
		wrapper.offset_right = _default_wrapper_offsets.z + enemy_offset.x
		wrapper.offset_bottom = _default_wrapper_offsets.w + enemy_offset.y

	charge_value = 0.0
	charge_direction = 1.0
	is_charging = false

	if charge_progress:
		charge_progress.offset_top = progress_top
		charge_progress.offset_bottom = progress_bottom
	_update_progress_bar()

	# SFX charge attack muncul
	var sfx: AudioStream = load("res://assets/audio/effects/battle/ui/attackQte-open.mp3")
	if sfx:
		var sfx_player := AudioStreamPlayer.new()
		sfx_player.stream = sfx
		sfx_player.volume_db = -3.0
		add_child(sfx_player)
		sfx_player.play()
		sfx_player.finished.connect(sfx_player.queue_free)

	modulate.a = 0.0
	scale = Vector2(0.5, 0.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Mulai pulse text2
	_start_text2_pulse()


func hide_charge() -> void:
	# Stop text2 pulse
	_stop_text2_pulse()

	# Force kill velocity tween
	if _button_velocity_tween:
		if _button_velocity_tween.is_running():
			_button_velocity_tween.kill()
		_button_velocity_tween = null

	# Reset button scale immediately
	if button_charge:
		button_charge.scale = Vector2.ONE

	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_property(self, "scale", Vector2(0.8, 0.8), 0.15)
	tw.tween_callback(func() -> void:
		visible = false
		is_charging = false
		# Reset wrapper ke posisi default
		if wrapper:
			wrapper.offset_left = _default_wrapper_offsets.x
			wrapper.offset_top = _default_wrapper_offsets.y
			wrapper.offset_right = _default_wrapper_offsets.z
			wrapper.offset_bottom = _default_wrapper_offsets.w
	)


func _start_text2_pulse() -> void:
	if not title_text2:
		return
	if _text2_pulse_tween and _text2_pulse_tween.is_running():
		_text2_pulse_tween.kill()
	_text2_pulse_tween = create_tween().set_loops()
	_text2_pulse_tween.tween_property(title_text2, "modulate:a", 0.3, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_text2_pulse_tween.tween_property(title_text2, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_text2_pulse() -> void:
	if _text2_pulse_tween and _text2_pulse_tween.is_running():
		_text2_pulse_tween.kill()
	if title_text2:
		title_text2.modulate.a = 1.0


func _on_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_charging = true
				charge_value = 0.0
				charge_direction = 1.0
				charge_started.emit()

				# Button scale up smooth saat hold
				if _button_hold_tween and _button_hold_tween.is_running():
					_button_hold_tween.kill()
				_button_hold_tween = create_tween()
				_button_hold_tween.tween_property(button_charge, "scale", Vector2(1.12, 1.12), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

				# Velocity: scale pelan-pelan naik terus
				if _button_velocity_tween and _button_velocity_tween.is_running():
					_button_velocity_tween.kill()
				_button_velocity_tween = create_tween().set_loops()
				_button_velocity_tween.tween_property(button_charge, "scale", Vector2(1.25, 1.25), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				_button_velocity_tween.tween_property(button_charge, "scale", Vector2(1.12, 1.12), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			else:
				# Button scale back smooth saat release
				if _button_hold_tween and _button_hold_tween.is_running():
					_button_hold_tween.kill()
				if _button_velocity_tween and _button_velocity_tween.is_running():
					_button_velocity_tween.kill()
				button_charge.scale = Vector2.ONE
				charge_ended.emit()
				_stop_charge()


func _stop_charge() -> void:
	if not is_charging:
		return

	is_charging = false

	# Force kill velocity tween and reset button
	if _button_velocity_tween:
		if _button_velocity_tween.is_running():
			_button_velocity_tween.kill()
		_button_velocity_tween = null
	if _button_hold_tween and _button_hold_tween.is_running():
		_button_hold_tween.kill()
	if button_charge:
		button_charge.scale = Vector2.ONE

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
