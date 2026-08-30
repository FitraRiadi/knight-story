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

const ICON_SIZE: float = 50.0
const BADGE_SIZE: float = 28.0
const BORDER_RADIUS: float = 10.0

const HOVER_LIFT: float = -18.0
const HOVER_SCALE: float = 1.1
const SELECT_LIFT: float = -90.0
const SELECT_SCALE: float = 1.25

const FAN_ANGLE: float = 4.0
const FLOAT_AMPLITUDE: float = 4.0
const FLOAT_SPEED: float = 2.5


# ============================================================
# STATE
# ============================================================

var cards_data: Array[ActionCardData] = []
var card_nodes: Array[Control] = []
var card_labels: Array[Label] = []
var card_icons: Array[TextureRect] = []
var card_badges: Array[Label] = []
var card_glow_panels: Array[Panel] = []
var card_cd_overlays: Array[Control] = []

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
	# CanvasLayer
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 165
	add_child(canvas_layer)

	# Full-screen bg overlay (click to close)
	bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0, 0, 0, 0.5)
	bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	bg_overlay.gui_input.connect(_on_bg_input)
	canvas_layer.add_child(bg_overlay)

	# Hitung total width
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var total_width: float = (cards_data.size() * CARD_WIDTH) + ((cards_data.size() - 1) * CARD_GAP)
	var start_x: float = (viewport_size.x - total_width) / 2.0

	# Buat kartu
	for i in range(cards_data.size()):
		var data: ActionCardData = cards_data[i]
		var is_on_cd: bool = i < card_cooldowns.size() and card_cooldowns[i] > 0
		var has_enough_stamina: bool = current_stamina >= data.stamina_cost

		var card: Control = _create_card(data, i, is_on_cd, has_enough_stamina)
		card.position = Vector2(start_x + i * CARD_SPACING, CARD_Y + 300.0)  # start from bottom
		card.name = "Card_" + str(i)
		canvas_layer.add_child(card)
		card_nodes.append(card)


func _create_card(data: ActionCardData, index: int, on_cooldown: bool, has_stamina: bool) -> Control:
	var card := Control.new()
	card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.pivot_offset = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT / 2.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# Rotasi fan layout
	var fan_count: int = cards_data.size()
	var center_index: float = (fan_count - 1) / 2.0
	var fan_offset: float = index - center_index
	var fan_rotation: float = fan_offset * deg_to_rad(FAN_ANGLE)
	card.rotation = fan_rotation

	# === BACKGROUND ===
	var bg := Panel.new()
	bg.name = "BG"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.15, 0.95)
	style.border_color = data.accent_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(BORDER_RADIUS))
	style.set_shadow_color(Color(0, 0, 0, 0.4))
	style.set_shadow_offset(Vector2(2, 4))
	style.shadow_size = 8
	bg.add_theme_stylebox_override("panel", style)
	card.add_child(bg)

	# === GLOW PANEL (hidden by default) ===
	var glow := Panel.new()
	glow.name = "Glow"
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(data.accent_color.r, data.accent_color.g, data.accent_color.b, 0.15)
	glow_style.border_color = data.accent_color
	glow_style.set_border_width_all(3)
	glow_style.set_corner_radius_all(int(BORDER_RADIUS))
	glow_style.set_shadow_color(Color(data.accent_color.r, data.accent_color.g, data.accent_color.b, 0.5))
	glow_style.shadow_size = 16
	glow.add_theme_stylebox_override("panel", glow_style)
	glow.modulate.a = 0.0
	card.add_child(glow)
	card_glow_panels.append(glow)

	# === ICON ===
	var icon_tex := TextureRect.new()
	icon_tex.name = "Icon"
	icon_tex.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon_tex.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon_tex.position = Vector2((CARD_WIDTH - ICON_SIZE) / 2.0, 16)
	icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if data.icon:
		icon_tex.texture = data.icon
	else:
		# Placeholder: colored square
		var placeholder := ColorRect.new()
		placeholder.color = data.accent_color
		placeholder.size = Vector2(ICON_SIZE - 10, ICON_SIZE - 10)
		placeholder.position = Vector2(5, 5)
		icon_tex.add_child(placeholder)
	card.add_child(icon_tex)
	card_icons.append(icon_tex)

	# === NAME ===
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = data.card_name.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.position = Vector2(4, 72)
	name_label.size = Vector2(CARD_WIDTH - 8, 16)
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(0.88, 0.82, 0.70))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_label)

	# === DIVIDER ===
	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.color = Color(data.accent_color.r, data.accent_color.g, data.accent_color.b, 0.3)
	divider.position = Vector2(12, 90)
	divider.size = Vector2(CARD_WIDTH - 24, 1)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(divider)

	# === DESCRIPTION ===
	var desc_label := Label.new()
	desc_label.name = "Desc"
	desc_label.text = data.description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc_label.position = Vector2(6, 96)
	desc_label.size = Vector2(CARD_WIDTH - 12, 32)
	desc_label.add_theme_font_size_override("font_size", 8)
	desc_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(desc_label)

	# === STAMINA BADGE ===
	var badge_container := Control.new()
	badge_container.name = "Badge"
	badge_container.position = Vector2(CARD_WIDTH - BADGE_SIZE - 4, -4)
	badge_container.size = Vector2(BADGE_SIZE, BADGE_SIZE)
	badge_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(badge_container)

	var badge_bg := Panel.new()
	badge_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var badge_style := StyleBoxFlat.new()
	if has_stamina and not on_cooldown:
		badge_style.bg_color = Color(0.94, 0.75, 0.25)
		badge_style.border_color = Color(0.82, 0.56, 0.13)
	else:
		badge_style.bg_color = Color(0.4, 0.4, 0.4)
		badge_style.border_color = Color(0.3, 0.3, 0.3)
	badge_style.set_border_width_all(2)
	badge_style.set_corner_radius_all(int(BADGE_SIZE / 2.0))
	badge_bg.add_theme_stylebox_override("panel", badge_style)
	badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_container.add_child(badge_bg)

	var badge_label := Label.new()
	badge_label.text = str(int(data.stamina_cost))
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge_label.add_theme_font_size_override("font_size", 9)
	badge_label.add_theme_color_override("font_color", Color(0.12, 0.08, 0.0))
	badge_label.add_theme_font_override("font_label_settings", null)
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_container.add_child(badge_label)
	card_badges.append(badge_label)

	# === COOLDOWN OVERLAY ===
	var cd_overlay := Control.new()
	cd_overlay.name = "CooldownOverlay"
	cd_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_overlay.visible = on_cooldown

	var cd_bg := ColorRect.new()
	cd_bg.color = Color(0, 0, 0, 0.65)
	cd_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cd_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_overlay.add_child(cd_bg)

	var cd_number := Label.new()
	cd_number.name = "CDNumber"
	cd_number.text = str(card_cooldowns[index]) if index < card_cooldowns.size() else "?"
	cd_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_number.position = Vector2(0, 30)
	cd_number.size = Vector2(CARD_WIDTH, 50)
	cd_number.add_theme_font_size_override("font_size", 32)
	cd_number.add_theme_color_override("font_color", Color(0.9, 0.3, 0.2))
	cd_number.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	cd_number.add_theme_constant_override("outline_size", 3)
	cd_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_overlay.add_child(cd_number)

	var cd_label_text := Label.new()
	cd_label_text.text = "TURNS"
	cd_label_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_label_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_label_text.position = Vector2(0, 72)
	cd_label_text.size = Vector2(CARD_WIDTH, 16)
	cd_label_text.add_theme_font_size_override("font_size", 8)
	cd_label_text.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	cd_label_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_overlay.add_child(cd_label_text)

	card.add_child(cd_overlay)
	card_cd_overlays.append(cd_overlay)

	# === GREYED OUT OVERLAY ===
	if not has_stamina and not on_cooldown:
		var greyed := ColorRect.new()
		greyed.name = "GreyedOverlay"
		greyed.color = Color(0, 0, 0, 0.4)
		greyed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		greyed.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(greyed)

	# === CONNECT HOVER & INPUT ===
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

		# Slide up from bottom with spring bounce
		tw.tween_property(card, "position:y", target_y, 0.5)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

		# Scale in
		card.scale = Vector2(0.3, 0.3)
		tw.tween_property(card, "scale", Vector2.ONE, 0.45)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

	# Mulai idle float setelah spawn selesai
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

	var card: Control = card_nodes[index]

	# Stop idle float for this card
	if index < float_tweens.size() and float_tweens[index] and float_tweens[index].is_valid():
		float_tweens[index].kill()

	# Lift + scale
	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "position:y", CARD_Y + HOVER_LIFT, 0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), 0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	# Glow
	if index < card_glow_panels.size():
		tw.tween_property(card_glow_panels[index], "modulate:a", 1.0, 0.2)


func _on_card_unhover(index: int) -> void:
	if is_selecting:
		return
	if index < 0 or index >= card_nodes.size():
		return

	var card: Control = card_nodes[index]

	# Return to idle position
	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "position:y", CARD_Y, 0.25)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	# Glow off
	if index < card_glow_panels.size():
		tw.tween_property(card_glow_panels[index], "modulate:a", 0.0, 0.2)

	# Restart float after unhover
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

	# Cek apakah kartu bisa dipilih
	var data: ActionCardData = cards_data[index]
	var is_on_cd: bool = index < card_cooldowns.size() and card_cooldowns[index] > 0
	var has_stamina: bool = current_stamina >= data.stamina_cost

	if is_on_cd or not has_stamina:
		# Shake animation (rejection)
		_play_shake(index)
		return

	_select_card(index)


func _play_shake(index: int) -> void:
	if index < 0 or index >= card_nodes.size():
		return
	var card: Control = card_nodes[index]
	var orig_x: float = card.position.x

	var tw := create_tween()
	tw.tween_property(card, "position:x", orig_x + 8, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "position:x", orig_x - 8, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "position:x", orig_x + 5, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "position:x", orig_x, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ============================================================
# SELECT ANIMATION (Balatro-style punch)
# ============================================================

func _select_card(index: int) -> void:
	is_selecting = true
	selected_index = index
	_stop_idle_float()

	var card: Control = card_nodes[index]
	var data: ActionCardData = cards_data[index]

	# Hitung posisi tengah viewport
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var center_pos: Vector2 = Vector2(
		(viewport_size.x - CARD_WIDTH * SELECT_SCALE) / 2.0,
		(viewport_size.y - CARD_HEIGHT * SELECT_SCALE) / 2.0
	)

	# Phase 1: Selected card moves to center with punch
	var tw := create_tween()

	# Move to center
	tw.tween_property(card, "position", center_pos, 0.4)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	# Punch scale: 1.0 → 1.3 → 0.95 → SELECT_SCALE
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

	# Reset rotation ke 0 (centered, lurus)
	tw.parallel().tween_property(card, "rotation", 0.0, 0.3)\
		.set_trans(Tween.TRANS_CUBIC)

	# Phase 2: Other cards cascade fade out
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

	# Phase 3: Hold, then close
	tw.tween_interval(0.6)
	tw.tween_callback(func() -> void:
		# Emit signal
		card_selected.emit(selected_index)
		# Fade out selected card
		var close_tw := create_tween()
		close_tw.tween_property(card, "modulate:a", 0.0, 0.2)
		close_tw.parallel().tween_property(card, "scale", Vector2(0.5, 0.5), 0.25)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN)
		close_tw.tween_callback(_cleanup)
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
	card_labels.clear()
	card_icons.clear()
	card_badges.clear()
	card_glow_panels.clear()
	card_cd_overlays.clear()
