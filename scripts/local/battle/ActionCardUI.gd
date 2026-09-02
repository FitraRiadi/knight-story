extends Control
class_name ActionCardUI


# ============================================================
# SIGNALS
# ============================================================

signal card_selected(index: int)
signal card_closed()


# ============================================================
# CONSTANTS
# ============================================================

const CARD_WIDTH: float = 110.0
const CARD_HEIGHT: float = 160.0
const CARD_GAP: float = 18.0
const CARD_SPACING: float = CARD_WIDTH + CARD_GAP
const CARD_Y: float = 80.0

const HOVER_LIFT: float = -18.0
const HOVER_SCALE: float = 1.1
const SELECT_SCALE: float = 1.25

const FAN_ANGLE: float = 4.0
const FLOAT_AMPLITUDE: float = 4.0
const FLOAT_SPEED: float = 2.5


# ============================================================
# PRELOADS
# ============================================================

const CARD_SCENE: PackedScene = preload("res://scenes/battle/action_card.tscn")


# ============================================================
# STATE
# ============================================================

var cards_data: Array[ActionCardData] = []
var card_nodes: Array[Control] = []
var card_glow_panels: Array[Panel] = []

var card_cooldowns: Array[int] = []
var current_stamina: float = 0.0

var is_open: bool = false
var is_selecting: bool = false
var selected_index: int = -1

var canvas_layer: CanvasLayer
var bg_overlay: ColorRect
var float_tweens: Array[Tween] = []


# ============================================================
# SETUP
# ============================================================

func setup(cards: Array[ActionCardData], cooldowns: Array[int], stamina: float) -> void:
	cards_data = cards
	card_cooldowns = cooldowns
	current_stamina = stamina


# ============================================================
# OPEN
# ============================================================

func open() -> void:
	if is_open:
		return
	is_open = true
	_build_ui()
	_animate_spawn()


func _build_ui() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 165
	add_child(canvas_layer)

	bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0, 0, 0, 0.5)
	bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	bg_overlay.gui_input.connect(_on_bg_input)
	canvas_layer.add_child(bg_overlay)

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var total_width: float = (cards_data.size() * CARD_WIDTH) + ((cards_data.size() - 1) * CARD_GAP)
	var start_x: float = (viewport_size.x - total_width) / 2.0

	for i in range(cards_data.size()):
		var data: ActionCardData = cards_data[i]
		var cd: int = card_cooldowns[i] if i < card_cooldowns.size() else 0
		var has_stamina: bool = current_stamina >= data.stamina_cost
		var is_on_cooldown: bool = cd > 0

		var card: Control = _create_card(data, i, has_stamina, is_on_cooldown, cd)
		card.position = Vector2(start_x + i * CARD_SPACING, CARD_Y + 300.0)
		card.name = "Card_" + str(i)
		canvas_layer.add_child(card)
		card_nodes.append(card)


func _create_card(data: ActionCardData, index: int, has_stamina: bool, is_on_cooldown: bool, cooldown_remaining: int) -> Control:
	var card: Control = CARD_SCENE.instantiate()

	# Fan rotation
	var fan_count: int = cards_data.size()
	var center_index: float = (fan_count - 1) / 2.0
	var fan_offset: float = index - center_index
	card.rotation = fan_offset * deg_to_rad(FAN_ANGLE)

	# BG Panel
	var bg: Panel = card.get_node("BG")
	var bg_style: StyleBoxFlat = bg.get_theme_stylebox("panel").duplicate()
	bg_style.border_color = data.accent_color
	bg.add_theme_stylebox_override("panel", bg_style)

	# BG Texture hidden
	var bg_texture: TextureRect = card.get_node("BG/BGTexture")
	bg_texture.visible = false

	# Glow Panel
	var glow: Panel = card.get_node("Glow")
	var glow_style: StyleBoxFlat = glow.get_theme_stylebox("panel").duplicate()
	glow_style.bg_color = Color(data.accent_color.r, data.accent_color.g, data.accent_color.b, 0.15)
	glow_style.border_color = data.accent_color
	glow_style.set_shadow_color(Color(data.accent_color.r, data.accent_color.g, data.accent_color.b, 0.5))
	glow.add_theme_stylebox_override("panel", glow_style)
	glow.modulate.a = 0.0
	card_glow_panels.append(glow)

	# Icon
	var icon_tex: TextureRect = card.get_node("IconContainer/Icon")
	icon_tex.texture = data.icon
	if data.icon:
		var placeholder: ColorRect = icon_tex.get_node_or_null("Placeholder")
		if placeholder:
			placeholder.visible = false

	# Name
	var name_label: Label = card.get_node("NameLabel")
	name_label.text = data.card_name.to_upper()

	# Divider color
	var divider: ColorRect = card.get_node("Divider")
	divider.color = Color(data.accent_color.r, data.accent_color.g, data.accent_color.b, 0.3)

	# Description
	var desc_label: Label = card.get_node("DescLabel")
	desc_label.text = data.description

	# Badge
	var badge_label: Label = card.get_node("BadgeContainer/BadgeLabel")
	badge_label.text = str(int(data.stamina_cost))
	var badge_bg: Panel = card.get_node("BadgeContainer/BadgeBG")
	if has_stamina and not is_on_cooldown:
		var badge_style: StyleBoxFlat = badge_bg.get_theme_stylebox("panel").duplicate()
		badge_style.bg_color = Color(0.94, 0.75, 0.25)
		badge_style.border_color = Color(0.82, 0.56, 0.13)
		badge_bg.add_theme_stylebox_override("panel", badge_style)
	else:
		var badge_style: StyleBoxFlat = badge_bg.get_theme_stylebox("panel").duplicate()
		badge_style.bg_color = Color(0.4, 0.4, 0.4)
		badge_style.border_color = Color(0.3, 0.3, 0.3)
		badge_bg.add_theme_stylebox_override("panel", badge_style)

	# Cooldown overlay
	var cd_overlay: Control = card.get_node("CooldownOverlay")
	cd_overlay.visible = is_on_cooldown
	if is_on_cooldown:
		var cd_number: Label = cd_overlay.get_node("CDNumber")
		cd_number.text = str(cooldown_remaining)

	# Greyed overlay (stamina kurang atau cooldown)
	var greyed: ColorRect = card.get_node("GreyedOverlay")
	greyed.visible = not has_stamina or is_on_cooldown

	# Connect input
	card.gui_input.connect(_on_card_input.bind(index))
	card.mouse_entered.connect(_on_card_hover.bind(index))
	card.mouse_exited.connect(_on_card_unhover.bind(index))

	return card


# ============================================================
# ANIMATIONS
# ============================================================

func _animate_spawn() -> void:
	var tw := create_tween().set_parallel(true)

	for i in range(card_nodes.size()):
		var card: Control = card_nodes[i]
		var target_y: float = CARD_Y
		var delay: float = i * 0.1

		tw.tween_property(card, "position:y", target_y, 0.5)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

		card.scale = Vector2(0.3, 0.3)
		tw.tween_property(card, "scale", Vector2.ONE, 0.45)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

	tw.chain().tween_callback(_start_idle_float)


func _start_idle_float() -> void:
	for i in range(card_nodes.size()):
		var card: Control = card_nodes[i]
		var delay: float = i * 0.3

		var float_tw := create_tween().set_loops()
		float_tw.tween_property(card, "position:y", CARD_Y - FLOAT_AMPLITUDE, FLOAT_SPEED / 2.0)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		float_tw.tween_property(card, "position:y", CARD_Y, FLOAT_SPEED / 2.0)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		float_tweens.append(float_tw)


func _stop_idle_float() -> void:
	for ft in float_tweens:
		if ft and ft.is_valid():
			ft.kill()
	float_tweens.clear()


func _on_card_hover(index: int) -> void:
	if is_selecting:
		return
	if index < 0 or index >= card_nodes.size():
		return

	# Skip hover kalau card cooldown atau stamina kurang
	var data: ActionCardData = cards_data[index]
	var cd: int = card_cooldowns[index] if index < card_cooldowns.size() else 0
	if cd > 0 or current_stamina < data.stamina_cost:
		return

	var card: Control = card_nodes[index]

	if index < float_tweens.size() and float_tweens[index] and float_tweens[index].is_valid():
		float_tweens[index].kill()

	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "position:y", CARD_Y + HOVER_LIFT, 0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), 0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	if index < card_glow_panels.size():
		tw.tween_property(card_glow_panels[index], "modulate:a", 1.0, 0.2)


func _on_card_unhover(index: int) -> void:
	if is_selecting:
		return
	if index < 0 or index >= card_nodes.size():
		return

	# Skip unhover kalau card cooldown atau stamina kurang
	var data: ActionCardData = cards_data[index]
	var cd: int = card_cooldowns[index] if index < card_cooldowns.size() else 0
	if cd > 0 or current_stamina < data.stamina_cost:
		return

	var card: Control = card_nodes[index]

	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "position:y", CARD_Y, 0.25)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	if index < card_glow_panels.size():
		tw.tween_property(card_glow_panels[index], "modulate:a", 0.0, 0.2)

	_restart_float(index)


func _restart_float(index: int) -> void:
	if index < 0 or index >= card_nodes.size():
		return
	var card: Control = card_nodes[index]
	var delay: float = index * 0.3

	var float_tw := create_tween().set_loops()
	float_tw.tween_property(card, "position:y", CARD_Y - FLOAT_AMPLITUDE, FLOAT_SPEED / 2.0)\
		.set_delay(delay)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	float_tw.tween_property(card, "position:y", CARD_Y, FLOAT_SPEED / 2.0)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	if index < float_tweens.size():
		float_tweens[index] = float_tw
	else:
		float_tweens.append(float_tw)


# ============================================================
# CARD INPUT
# ============================================================

func _on_card_input(event: InputEvent, index: int) -> void:
	if is_selecting:
		return
	if not event is InputEventMouseButton:
		return
	if not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	# Cek cooldown dan stamina
	var data: ActionCardData = cards_data[index]
	var cd: int = card_cooldowns[index] if index < card_cooldowns.size() else 0
	if cd > 0:
		return
	if current_stamina < data.stamina_cost:
		return

	_select_card(index)


func _select_card(index: int) -> void:
	is_selecting = true
	selected_index = index
	_stop_idle_float()

	var card: Control = card_nodes[index]

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var center_pos: Vector2 = Vector2(
		(viewport_size.x - CARD_WIDTH * SELECT_SCALE) / 2.0,
		(viewport_size.y - CARD_HEIGHT * SELECT_SCALE) / 2.0
	)

	var tw := create_tween()

	# Move to center
	tw.tween_property(card, "position", center_pos, 0.4)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	# Punch scale
	tw.parallel().tween_property(card, "scale", Vector2(1.3, 1.3), 0.1)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2(0.95, 0.95), 0.08)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	tw.tween_property(card, "scale", Vector2(SELECT_SCALE, SELECT_SCALE), 0.2)\
		.set_trans(Tween.TRANS_ELASTIC)\
		.set_ease(Tween.EASE_OUT)

	# Full glow
	if index < card_glow_panels.size():
		tw.parallel().tween_property(card_glow_panels[index], "modulate:a", 1.0, 0.15)

	# Reset rotation
	tw.parallel().tween_property(card, "rotation", 0.0, 0.3)\
		.set_trans(Tween.TRANS_CUBIC)

	# Other cards cascade fade out
	for i in range(card_nodes.size()):
		if i == index:
			continue
		var other: Control = card_nodes[i]
		var delay: float = (i * 0.08)
		var other_tw := create_tween()
		other_tw.tween_property(other, "modulate:a", 0.0, 0.15).set_delay(delay)
		other_tw.parallel().tween_property(other, "position:y", other.position.y + 50, 0.2)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN)
		other_tw.parallel().tween_property(other, "scale", Vector2(0.7, 0.7), 0.2).set_delay(delay)

	# Hold, then close
	tw.tween_interval(0.6)
	tw.tween_callback(func() -> void:
		card_selected.emit(selected_index)
		var close_tw := create_tween()
		close_tw.tween_property(card, "modulate:a", 0.0, 0.2)
		close_tw.parallel().tween_property(card, "scale", Vector2(0.5, 0.5), 0.25)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN)
		close_tw.tween_callback(func() -> void:
			_cleanup()
			card_closed.emit()
		)
	)


# ============================================================
# CLOSE
# ============================================================

func _on_bg_input(event: InputEvent) -> void:
	if is_selecting:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func close() -> void:
	if is_selecting:
		return
	_cleanup()
	card_closed.emit()


func _cleanup() -> void:
	is_open = false
	is_selecting = false
	selected_index = -1
	_stop_idle_float()

	if canvas_layer and is_instance_valid(canvas_layer):
		canvas_layer.queue_free()
		canvas_layer = null

	card_nodes.clear()
	card_glow_panels.clear()
