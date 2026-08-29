extends Control
class_name TavernDrinkMix


# ============================================================
# TAVERN DRINK MIX GAME
# Mini-game: Robert kasih resep minuman, tebak urutan bahan.
# Match feature panel layout: (35, 21, 438, 280)
# ============================================================

signal closed
signal back_to_menu
signal game_won

const REVEAL_TIME: float = 3.0
const GOLD_REWARD: int = 5
const BUTTON_COUNT: int = 5

var panel: Panel
var title_bar: Panel
var recipe_label: Label
var status_label: Label
var selected_label: Label
var gold_reward_label: Label
var ingredient_buttons: Array[Button] = []

var current_recipe: Dictionary = {}
var correct_ingredients: Array = []
var player_picks: Array = []
var is_picking: bool = false
var overlay: ColorRect

# Style constants
const PANEL_BG := Color(0, 0, 0, 0.56)
const TITLE_COLOR := Color(1, 1, 0.2)
const TEXT_COLOR := Color(1, 0.95, 0.8)
const STATUS_COLOR := Color(0.7, 0.65, 0.55)
const GOLD_COLOR := Color(1, 0.85, 0.2)
const RECIPE_COLOR := Color(0.4, 0.9, 0.6)
const SELECTED_COLOR := Color(0.6, 0.8, 1.0)
const BTN_NORMAL := Color(0.11, 0.067, 0.016, 0.6)
const BTN_HOVER := Color(0.18, 0.12, 0.03, 0.8)
const BTN_PICKED := Color(0.15, 0.25, 0.15, 0.5)
const BTN_CORRECT := Color(0.1, 0.35, 0.1, 1.0)
const BTN_WRONG := Color(0.35, 0.08, 0.08, 1.0)

# All available ingredients
const ALL_INGREDIENTS: Array = [
	"Beer", "Mead", "Wine", "Ale", "Rum",
	"Brandy", "Cider", "Grog", "Whiskey"
]

# Recipe pool (always 5 ingredients)
const DRINK_POOL: Array = [
	{"recipe": ["Beer", "Mead", "Wine", "Ale", "Rum"]},
	{"recipe": ["Wine", "Grog", "Cider", "Beer", "Mead"]},
	{"recipe": ["Ale", "Rum", "Brandy", "Whiskey", "Cider"]},
	{"recipe": ["Grog", "Whiskey", "Beer", "Mead", "Wine"]},
	{"recipe": ["Rum", "Cider", "Grog", "Brandy", "Ale"]},
	{"recipe": ["Brandy", "Whiskey", "Beer", "Cider", "Mead"]},
	{"recipe": ["Wine", "Ale", "Rum", "Grog", "Whiskey"]},
	{"recipe": ["Mead", "Cider", "Brandy", "Beer", "Wine"]},
	{"recipe": ["Whiskey", "Grog", "Ale", "Rum", "Cider"]},
	{"recipe": ["Cider", "Beer", "Mead", "Brandy", "Grog"]},
]


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

	# Panel
	panel = Panel.new()
	panel.position = Vector2(35, 21)
	panel.size = Vector2(438, 280)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	# Title bar
	title_bar = Panel.new()
	title_bar.position = Vector2(0, 0)
	title_bar.size = Vector2(438, 30)
	var title_bar_style = StyleBoxFlat.new()
	title_bar_style.bg_color = Color(0.35, 0.22, 0.45, 0.85)
	title_bar.add_theme_stylebox_override("panel", title_bar_style)
	title_bar.modulate.a = 0.0
	panel.add_child(title_bar)

	var title = Label.new()
	title.text = "Brew Challenge"
	title.position = Vector2(0, 3)
	title.size = Vector2(438, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title_bar.add_child(title)

	# Recipe display
	recipe_label = Label.new()
	recipe_label.position = Vector2(10, 38)
	recipe_label.size = Vector2(418, 24)
	recipe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recipe_label.add_theme_font_size_override("font_size", 16)
	recipe_label.add_theme_color_override("font_color", RECIPE_COLOR)
	recipe_label.text = ""
	panel.add_child(recipe_label)

	# Status label
	status_label = Label.new()
	status_label.position = Vector2(10, 62)
	status_label.size = Vector2(418, 20)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", STATUS_COLOR)
	panel.add_child(status_label)

	# Selected display
	selected_label = Label.new()
	selected_label.position = Vector2(10, 86)
	selected_label.size = Vector2(418, 22)
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_label.add_theme_font_size_override("font_size", 14)
	selected_label.add_theme_color_override("font_color", SELECTED_COLOR)
	selected_label.text = ""
	panel.add_child(selected_label)

	# Ingredient buttons (5 buttons, 2 rows)
	_create_ingredient_buttons()

	# Gold reward label
	gold_reward_label = Label.new()
	gold_reward_label.position = Vector2(10, 248)
	gold_reward_label.size = Vector2(418, 22)
	gold_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_reward_label.add_theme_font_size_override("font_size", 14)
	gold_reward_label.add_theme_color_override("font_color", GOLD_COLOR)
	gold_reward_label.visible = false
	panel.add_child(gold_reward_label)


func _create_ingredient_buttons() -> void:
	var btn_w = 120.0
	var btn_h = 36.0
	var gap_x = 10.0
	var gap_y = 8.0
	var start_x = 35.0
	var start_y = 115.0

	# Row 1: 3 buttons
	for i in range(3):
		var btn = _make_ingredient_button()
		btn.position = Vector2(start_x + i * (btn_w + gap_x), start_y)
		btn.size = Vector2(btn_w, btn_h)
		panel.add_child(btn)
		ingredient_buttons.append(btn)

	# Row 2: 2 buttons (centered)
	var row2_x = start_x + (btn_w + gap_x) / 2.0
	for i in range(2):
		var btn = _make_ingredient_button()
		btn.position = Vector2(row2_x + i * (btn_w + gap_x), start_y + btn_h + gap_y)
		btn.size = Vector2(btn_w, btn_h)
		panel.add_child(btn)
		ingredient_buttons.append(btn)


func _make_ingredient_button() -> Button:
	var btn = Button.new()
	btn.text = ""
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = true

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = BTN_NORMAL
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	btn_style.content_margin_left = 8
	btn_style.content_margin_right = 8
	btn_style.content_margin_top = 4
	btn_style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = BTN_HOVER
	btn.add_theme_stylebox_override("hover", btn_hover)

	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.pressed.connect(_on_ingredient_pressed.bind(btn))
	return btn


func _play_intro() -> void:
	# Overlay fade in
	var tween_overlay = create_tween()
	tween_overlay.tween_property(overlay, "modulate:a", 1.0, 0.25)

	# Panel slide up from below
	var target_y = panel.position.y
	panel.position.y = target_y + 300
	panel.modulate.a = 0.0

	# Hide all content
	title_bar.visible = false
	recipe_label.visible = false
	status_label.visible = false
	selected_label.visible = false

	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CIRC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position:y", target_y, 0.35)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	await tween.finished

	# === TITLE MOMENT ===
	title_bar.visible = true
	title_bar.modulate.a = 0.0
	var title_tween = create_tween()
	title_tween.tween_property(title_bar, "modulate:a", 1.0, 0.2)

	await get_tree().create_timer(0.8).timeout

	# Content fade in
	recipe_label.visible = true
	recipe_label.modulate.a = 0.0
	status_label.visible = true
	status_label.modulate.a = 0.0
	selected_label.visible = true
	selected_label.modulate.a = 0.0

	var content_tween = create_tween().set_parallel(true)
	content_tween.tween_property(recipe_label, "modulate:a", 1.0, 0.3)
	content_tween.tween_property(status_label, "modulate:a", 1.0, 0.3)
	content_tween.tween_property(selected_label, "modulate:a", 1.0, 0.3)
	await content_tween.finished


func _start_game() -> void:
	player_picks.clear()
	is_picking = false
	gold_reward_label.visible = false

	# Hide all buttons first
	for btn in ingredient_buttons:
		btn.visible = false
		btn.disabled = true
		btn.text = ""

	# Pick random recipe
	current_recipe = DRINK_POOL[randi() % DRINK_POOL.size()]
	correct_ingredients = current_recipe.get("recipe", [])

	# Show recipe
	var recipe_text = " → ".join(correct_ingredients)
	recipe_label.text = "Recipe: " + recipe_text
	status_label.text = "Memorize the recipe! (5 ingredients)"
	status_label.add_theme_color_override("font_color", TEXT_COLOR)
	selected_label.text = ""

	# Pick decoy ingredients (enough to fill 5 buttons)
	var decoys: Array = []
	var available = ALL_INGREDIENTS.duplicate()
	for ing in correct_ingredients:
		available.erase(ing)
	available.shuffle()
	var decoy_count = BUTTON_COUNT - correct_ingredients.size()
	for i in range(mini(decoy_count, available.size())):
		decoys.append(available[i])

	# Build button labels: correct + decoys, then shuffle
	var btn_labels: Array = []
	for ing in correct_ingredients:
		btn_labels.append(ing)
	for decoy in decoys:
		btn_labels.append(decoy)
	btn_labels.shuffle()

	# Set button labels & keep disabled during memorize
	for i in range(ingredient_buttons.size()):
		if i < btn_labels.size():
			ingredient_buttons[i].text = btn_labels[i]
			ingredient_buttons[i].disabled = true
			ingredient_buttons[i].visible = false
			_reset_button_style(ingredient_buttons[i])
		else:
			ingredient_buttons[i].text = ""
			ingredient_buttons[i].disabled = true
			ingredient_buttons[i].visible = false

	await get_tree().create_timer(REVEAL_TIME).timeout

	# Hide recipe
	recipe_label.text = "Recipe: ???"
	status_label.text = "Mix the drink in order! (1-5)"
	status_label.add_theme_color_override("font_color", STATUS_COLOR)
	selected_label.text = "Your mix: " + _get_empty_mix_display()

	# Fade in buttons, THEN enable
	for btn in ingredient_buttons:
		if btn.text != "":
			btn.visible = true
			btn.modulate.a = 0.0

	var btn_tween = create_tween().set_parallel(true)
	for btn in ingredient_buttons:
		if btn.text != "":
			btn_tween.tween_property(btn, "modulate:a", 1.0, 0.25)
	await btn_tween.finished

	# NOW enable buttons
	for btn in ingredient_buttons:
		if btn.text != "":
			btn.disabled = false

	is_picking = true


func _get_empty_mix_display() -> String:
	var parts: Array = []
	for i in range(correct_ingredients.size()):
		parts.append("[ ? ]")
	return " ".join(parts)


func _get_mix_display() -> String:
	var parts: Array = []
	for i in range(correct_ingredients.size()):
		if i < player_picks.size():
			parts.append("[" + player_picks[i] + "]")
		else:
			parts.append("[ ? ]")
	return " ".join(parts)


func _on_ingredient_pressed(btn: Button) -> void:
	if not is_picking:
		return
	if btn.text == "":
		return

	var pick_index = player_picks.size()

	# Check immediately — if wrong, auto lose
	if btn.text != correct_ingredients[pick_index]:
		is_picking = false
		player_picks.append(btn.text)
		btn.disabled = true
		_set_button_wrong(btn)
		selected_label.text = "Your mix: " + _get_mix_display()
		await get_tree().create_timer(0.3).timeout
		_show_result(false)
		return

	# Correct pick
	player_picks.append(btn.text)
	btn.disabled = true
	_set_button_picked(btn)
	selected_label.text = "Your mix: " + _get_mix_display()

	# Check if all done
	if player_picks.size() >= correct_ingredients.size():
		is_picking = false
		await get_tree().create_timer(0.3).timeout
		_show_result(true)


func _show_result(is_correct: bool) -> void:
	if is_correct:
		status_label.text = "Perfect brew!"
		status_label.add_theme_color_override("font_color", Color(0.3, 1, 0.4))
		gold_reward_label.text = "+" + str(GOLD_REWARD) + " Gold"
		gold_reward_label.visible = true
		PlayerDataManager.add_gold(GOLD_REWARD)
		_spawn_particles()
		game_won.emit()
	else:
		status_label.text = "Wrong! It was: " + " → ".join(correct_ingredients)
		status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
		gold_reward_label.text = "Robert is not impressed..."
		gold_reward_label.visible = true
		_highlight_correct()

	await get_tree().create_timer(2.5).timeout
	_show_play_again(is_correct)


func _highlight_correct() -> void:
	for btn in ingredient_buttons:
		for i in range(correct_ingredients.size()):
			if btn.text == correct_ingredients[i]:
				var s = StyleBoxFlat.new()
				s.bg_color = BTN_CORRECT
				s.corner_radius_top_left = 4
				s.corner_radius_top_right = 4
				s.corner_radius_bottom_left = 4
				s.corner_radius_bottom_right = 4
				s.content_margin_left = 8
				s.content_margin_right = 8
				s.content_margin_top = 4
				s.content_margin_bottom = 4
				btn.add_theme_stylebox_override("normal", s)
				break


func _reset_button_style(btn: Button) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = BTN_NORMAL
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", s)


func _set_button_picked(btn: Button) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = BTN_PICKED
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", s)


func _set_button_wrong(btn: Button) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = BTN_WRONG
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", s)


func _spawn_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.position = Vector2(370, 130)
	particles.z_index = 100
	particles.amount = 12
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 0.9
	particles.direction = Vector2(0, -1)
	particles.spread = 60.0
	particles.gravity = Vector2(0, 200)
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 150.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1.0, 0.85, 0.2, 0.9)
	add_child(particles)
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	if is_instance_valid(particles):
		particles.queue_free()


func _show_play_again(was_win: bool) -> void:
	var popup_overlay := Control.new()
	popup_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var popup_panel := PanelContainer.new()
	popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.3, 0.3, 0.3, 1.0)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left = 20.0
	panel_style.content_margin_right = 20.0
	panel_style.content_margin_top = 14.0
	panel_style.content_margin_bottom = 14.0
	popup_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)

	var popup_title := Label.new()
	popup_title.text = "Play Again?"
	popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_title.add_theme_font_size_override("font_size", 18)
	popup_title.add_theme_color_override("font_color", TITLE_COLOR)
	vbox.add_child(popup_title)

	var result_label := Label.new()
	if was_win:
		result_label.text = "You Won! +" + str(GOLD_REWARD) + " Gold"
		result_label.add_theme_color_override("font_color", Color(0.3, 1, 0.4))
	else:
		result_label.text = "You Lost!"
		result_label.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(result_label)

	var gold_label := Label.new()
	gold_label.text = "Gold: " + str(PlayerDataManager.get_gold()) + " G"
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_font_size_override("font_size", 13)
	gold_label.add_theme_color_override("font_color", GOLD_COLOR)
	vbox.add_child(gold_label)

	var hbox_btns := HBoxContainer.new()
	hbox_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_btns.add_theme_constant_override("separation", 16)

	var yes_btn := Button.new()
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(80, 30)
	yes_btn.focus_mode = Control.FOCUS_NONE

	var yes_style := StyleBoxFlat.new()
	yes_style.bg_color = Color(0.11, 0.35, 0.08, 0.85)
	yes_style.corner_radius_top_left = 4
	yes_style.corner_radius_top_right = 4
	yes_style.corner_radius_bottom_left = 4
	yes_style.corner_radius_bottom_right = 4
	yes_btn.add_theme_stylebox_override("normal", yes_style)

	var yes_hover := yes_style.duplicate()
	yes_hover.bg_color = Color(0.15, 0.45, 0.1, 1.0)
	yes_btn.add_theme_stylebox_override("hover", yes_hover)

	yes_btn.add_theme_font_size_override("font_size", 13)
	yes_btn.add_theme_color_override("font_color", TEXT_COLOR)

	var no_btn := Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(80, 30)
	no_btn.focus_mode = Control.FOCUS_NONE

	var no_style := StyleBoxFlat.new()
	no_style.bg_color = Color(0.317, 0.097, 0.125, 0.6)
	no_style.corner_radius_top_left = 4
	no_style.corner_radius_top_right = 4
	no_style.corner_radius_bottom_left = 4
	no_style.corner_radius_bottom_right = 4
	no_btn.add_theme_stylebox_override("normal", no_style)

	var no_hover := no_style.duplicate()
	no_hover.bg_color = Color(0.4, 0.15, 0.18, 0.8)
	no_btn.add_theme_stylebox_override("hover", no_hover)

	no_btn.add_theme_font_size_override("font_size", 13)
	no_btn.add_theme_color_override("font_color", TEXT_COLOR)

	hbox_btns.add_child(yes_btn)
	hbox_btns.add_child(no_btn)
	vbox.add_child(hbox_btns)

	popup_panel.add_child(vbox)
	popup_overlay.add_child(popup_panel)
	add_child(popup_overlay)

	# Posisi center
	popup_panel.reset_size()
	var target_pos := Vector2(370.0, 130.0)
	popup_panel.pivot_offset = popup_panel.size / 2.0
	popup_panel.position = target_pos - (popup_panel.size / 2.0)

	popup_panel.scale = Vector2(0.2, 0.2)
	popup_panel.modulate.a = 0.0

	var tween := popup_panel.create_tween().set_parallel(true)
	tween.tween_property(popup_panel, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup_panel, "modulate:a", 1.0, 0.15)

	yes_btn.pressed.connect(_on_play_again.bind(popup_overlay))
	no_btn.pressed.connect(_on_no_play_again.bind(popup_overlay))


func _on_play_again(overlay_node: Node) -> void:
	overlay_node.queue_free()
	_start_game()


func _on_no_play_again(overlay_node: Node) -> void:
	overlay_node.queue_free()
	back_to_menu.emit()
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
