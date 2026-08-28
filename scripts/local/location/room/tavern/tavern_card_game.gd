extends Control
class_name TavernCardGame


# ============================================================
# TAVERN CARD GAME
# Mini-game: 5 kartu, 1 benar ditunjukin lalu di-shuffle.
# Match feature panel layout: (35, 21, 438, 280)
# ============================================================

signal closed

const CARD_COUNT: int = 5
const CARD_WIDTH: float = 70.0
const CARD_HEIGHT: float = 90.0
const CARD_GAP: float = 15.0
const REVEAL_TIME: float = 1.8
const SHUFFLE_COUNT_MIN: int = 6
const SHUFFLE_COUNT_MAX: int = 9
const SHUFFLE_SPEED_START: float = 0.35
const SHUFFLE_SPEED_MIN: float = 0.12
const GOLD_REWARD_MIN: int = 50
const GOLD_REWARD_MAX: int = 150

var panel: Panel
var status_label: Label
var gold_reward_label: Label
var card_container: Control
var cards: Array[Panel] = []
var card_labels: Array[Label] = []
var card_icons: Array[ColorRect] = []

var correct_index: int = 0
var is_shuffling: bool = false
var is_guessing: bool = false
var gold_reward: int = 0
var overlay: ColorRect

# Style constants (match existing tavern)
const PANEL_BG := Color(0, 0, 0, 0.56)
const TITLE_COLOR := Color(1, 1, 0.2)
const TEXT_COLOR := Color(1, 0.95, 0.8)
const STATUS_COLOR := Color(0.7, 0.65, 0.55)
const GOLD_COLOR := Color(1, 0.85, 0.2)
const CARD_NORMAL_BG := Color(0.11, 0.067, 0.016, 0.7)
const CARD_NORMAL_BORDER := Color(0.317, 0.097, 0.125, 0.6)
const CARD_REVEAL_BG := Color(0.05, 0.2, 0.05, 0.9)
const CARD_REVEAL_BORDER := Color(0.3, 0.9, 0.3, 1.0)
const CARD_CORRECT_BG := Color(0.1, 0.35, 0.1, 1.0)
const CARD_WRONG_BG := Color(0.35, 0.08, 0.08, 1.0)


func _ready() -> void:
	_build_ui()
	await _play_intro()
	_start_game()


func _build_ui() -> void:
	# Overlay
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.4)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.modulate.a = 0.0
	add_child(overlay)

	# Panel - same position & size as feature panel
	panel = Panel.new()
	panel.position = Vector2(35, 21)
	panel.size = Vector2(438, 280)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	# Title bar
	var title_bar = Panel.new()
	title_bar.position = Vector2(0, 0)
	title_bar.size = Vector2(438, 30)
	var title_bar_style = StyleBoxFlat.new()
	title_bar_style.bg_color = Color(0.245, 0.169, 0.321, 0.5)
	title_bar.add_theme_stylebox_override("panel", title_bar_style)
	panel.add_child(title_bar)

	var title = Label.new()
	title.text = "Find The Card"
	title.position = Vector2(0, 3)
	title.size = Vector2(438, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title_bar.add_child(title)

	# Status label
	status_label = Label.new()
	status_label.position = Vector2(10, 35)
	status_label.size = Vector2(418, 22)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", STATUS_COLOR)
	panel.add_child(status_label)

	# Card container (centered in panel)
	card_container = Control.new()
	var total_cards_width = CARD_COUNT * CARD_WIDTH + (CARD_COUNT - 1) * CARD_GAP
	var card_x = (438.0 - total_cards_width) / 2.0
	card_container.position = Vector2(card_x, 70)
	card_container.size = Vector2(total_cards_width, CARD_HEIGHT)
	panel.add_child(card_container)

	# Gold reward label (bottom)
	gold_reward_label = Label.new()
	gold_reward_label.position = Vector2(10, 240)
	gold_reward_label.size = Vector2(418, 22)
	gold_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_reward_label.add_theme_font_size_override("font_size", 14)
	gold_reward_label.add_theme_color_override("font_color", GOLD_COLOR)
	gold_reward_label.visible = false
	panel.add_child(gold_reward_label)


func _play_intro() -> void:
	# Overlay fade in
	var tween_overlay = create_tween()
	tween_overlay.tween_property(overlay, "modulate:a", 1.0, 0.25)

	# Panel slide up from below
	var target_y = panel.position.y
	panel.position.y = target_y + 300
	panel.modulate.a = 0.0

	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CIRC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position:y", target_y, 0.35)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	await tween.finished


func _start_game() -> void:
	cards.clear()
	card_labels.clear()
	card_icons.clear()
	is_shuffling = false
	is_guessing = false

	for child in card_container.get_children():
		child.queue_free()

	for i in range(CARD_COUNT):
		var card = _create_card(i)
		var x = i * (CARD_WIDTH + CARD_GAP)
		card.position = Vector2(x, 0)
		card_container.add_child(card)
		cards.append(card)

	correct_index = randi() % CARD_COUNT
	gold_reward = randi_range(GOLD_REWARD_MIN, GOLD_REWARD_MAX)

	await _reveal_correct_card()


func _create_card(index: int) -> Panel:
	var card = Panel.new()
	card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)

	# Card back style
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = CARD_NORMAL_BG
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_color = CARD_NORMAL_BORDER
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6
	card_style.corner_radius_bottom_right = 6
	card.add_theme_stylebox_override("panel", card_style)

	# "?" pattern
	var pattern_label = Label.new()
	pattern_label.text = "?"
	pattern_label.position = Vector2(0, 10)
	pattern_label.size = Vector2(CARD_WIDTH, CARD_HEIGHT - 20)
	pattern_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pattern_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pattern_label.add_theme_font_size_override("font_size", 28)
	pattern_label.add_theme_color_override("font_color", Color(0.317, 0.097, 0.125, 0.5))
	card.add_child(pattern_label)
	card_labels.append(pattern_label)

	# Gem icon (hidden by default)
	var gem = ColorRect.new()
	gem.color = Color(0.3, 0.9, 0.3)
	gem.position = Vector2(18, 22)
	gem.size = Vector2(CARD_WIDTH - 36, CARD_HEIGHT - 44)
	gem.visible = false
	card.add_child(gem)
	card_icons.append(gem)

	# Click detection
	card.gui_input.connect(_on_card_input.bind(index))

	return card


func _reveal_correct_card() -> void:
	status_label.text = "Memorize this card!"
	status_label.add_theme_color_override("font_color", TEXT_COLOR)

	var correct_card = cards[correct_index]

	# Reveal style
	var reveal_style = StyleBoxFlat.new()
	reveal_style.bg_color = CARD_REVEAL_BG
	reveal_style.border_width_top = 3
	reveal_style.border_width_bottom = 3
	reveal_style.border_width_left = 3
	reveal_style.border_width_right = 3
	reveal_style.border_color = CARD_REVEAL_BORDER
	reveal_style.corner_radius_top_left = 6
	reveal_style.corner_radius_top_right = 6
	reveal_style.corner_radius_bottom_left = 6
	reveal_style.corner_radius_bottom_right = 6
	correct_card.add_theme_stylebox_override("panel", reveal_style)

	# Show gem
	if correct_index < card_icons.size():
		card_icons[correct_index].visible = true

	# Pop animation
	correct_card.pivot_offset = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT / 2.0)
	var tween = create_tween()
	tween.tween_property(correct_card, "scale", Vector2(1.12, 1.12), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(correct_card, "scale", Vector2.ONE, 0.15)

	await get_tree().create_timer(REVEAL_TIME).timeout

	# Flip back
	_reset_card_style(correct_index)
	card_icons[correct_index].visible = false

	await _shuffle_cards()


func _reset_card_style(index: int) -> void:
	if index < 0 or index >= cards.size():
		return
	var s = StyleBoxFlat.new()
	s.bg_color = CARD_NORMAL_BG
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_color = CARD_NORMAL_BORDER
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	cards[index].add_theme_stylebox_override("panel", s)


func _shuffle_cards() -> void:
	is_shuffling = true
	status_label.text = "Watch carefully..."
	status_label.add_theme_color_override("font_color", STATUS_COLOR)

	var shuffle_count = randi_range(SHUFFLE_COUNT_MIN, SHUFFLE_COUNT_MAX)
	var current_speed = SHUFFLE_SPEED_START

	for i in range(shuffle_count):
		var a = randi() % CARD_COUNT
		var b = randi() % CARD_COUNT
		while b == a:
			b = randi() % CARD_COUNT

		await _swap_cards(a, b, current_speed)

		if a == correct_index:
			correct_index = b
		elif b == correct_index:
			correct_index = a

		current_speed = maxf(current_speed - 0.025, SHUFFLE_SPEED_MIN)

	status_label.text = "Pick the card!"
	status_label.add_theme_color_override("font_color", TEXT_COLOR)
	is_shuffling = false
	is_guessing = true


func _swap_cards(a: int, b: int, duration: float) -> void:
	if a < 0 or a >= cards.size() or b < 0 or b >= cards.size():
		return

	var card_a = cards[a]
	var card_b = cards[b]

	var pos_a = card_a.position
	var pos_b = card_b.position

	# Cross-path: one goes up, one goes down
	var offset_y = 25.0 if a < b else -25.0

	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)

	# A → B position
	tween.tween_property(card_a, "position:x", pos_b.x, duration)
	tween.tween_property(card_a, "position:y", pos_b.y + offset_y, duration * 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_a, "position:y", pos_b.y, duration).set_delay(duration * 0.5).set_ease(Tween.EASE_IN)

	# B → A position
	tween.tween_property(card_b, "position:x", pos_a.x, duration)
	tween.tween_property(card_b, "position:y", pos_a.y - offset_y, duration * 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_b, "position:y", pos_a.y, duration).set_delay(duration * 0.5).set_ease(Tween.EASE_IN)

	await tween.finished

	# Swap arrays
	var temp = cards[a]
	cards[a] = cards[b]
	cards[b] = temp

	var tl = card_labels[a]
	card_labels[a] = card_labels[b]
	card_labels[b] = tl

	var ti = card_icons[a]
	card_icons[a] = card_icons[b]
	card_icons[b] = ti


func _on_card_input(event: InputEvent, index: int) -> void:
	if not is_guessing:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	is_guessing = false
	await _reveal_choice(index)


func _reveal_choice(chosen_index: int) -> void:
	var is_correct = (chosen_index == correct_index)

	# Style chosen card
	var chosen_card = cards[chosen_index]
	var s = StyleBoxFlat.new()
	s.border_width_top = 3
	s.border_width_bottom = 3
	s.border_width_left = 3
	s.border_width_right = 3
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6

	if is_correct:
		s.bg_color = CARD_CORRECT_BG
		s.border_color = CARD_REVEAL_BORDER
	else:
		s.bg_color = CARD_WRONG_BG
		s.border_color = Color(1, 0.3, 0.2, 1.0)
	chosen_card.add_theme_stylebox_override("panel", s)

	# Reveal correct card if wrong
	if not is_correct:
		var cs = StyleBoxFlat.new()
		cs.bg_color = CARD_CORRECT_BG
		cs.border_width_top = 3
		cs.border_width_bottom = 3
		cs.border_width_left = 3
		cs.border_width_right = 3
		cs.border_color = CARD_REVEAL_BORDER
		cs.corner_radius_top_left = 6
		cs.corner_radius_top_right = 6
		cs.corner_radius_bottom_left = 6
		cs.corner_radius_bottom_right = 6
		cards[correct_index].add_theme_stylebox_override("panel", cs)

	# Pop animation
	chosen_card.pivot_offset = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT / 2.0)
	var tween = create_tween()
	tween.tween_property(chosen_card, "scale", Vector2(1.15, 1.15), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(chosen_card, "scale", Vector2.ONE, 0.1)

	# Result
	if is_correct:
		status_label.text = "Correct!"
		status_label.add_theme_color_override("font_color", Color(0.3, 1, 0.4))
		gold_reward_label.text = "+" + str(gold_reward) + " Gold"
		gold_reward_label.visible = true
		PlayerDataManager.add_gold(gold_reward)
	else:
		status_label.text = "Wrong!"
		status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
		gold_reward_label.text = "The card was here"
		gold_reward_label.visible = true

	await get_tree().create_timer(2.0).timeout
	_play_outro()


func _play_outro() -> void:
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CIRC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "position:y", panel.position.y + 300, 0.3)
	tween.tween_property(panel, "modulate:a", 0.0, 0.25)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.25)
	tween.tween_callback(_emit_closed)


func _emit_closed() -> void:
	closed.emit()
	queue_free()
