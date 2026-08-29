extends Control


# ============================================================
# TAVERN CONTROLLER
# Mengelola fitur tavern: Shop, Games, Dialog.
# Handle panel switching dengan animasi.
# ============================================================

@onready var exit: Button = $feature/exit
@onready var buy_item_btn: Button = $feature/BuyItemBtn
@onready var tavern_btn: Button = $feature/TavernBtn
@onready var selling_btn: Button = $feature/SellingItemBtn
@onready var quest_btn: Button = $feature/container4
@onready var announcement_btn: Button = $feature/container7
@onready var feature: Control = $feature

var gold_label: Label
var gold_display: Panel
var active_panel: Control = null
var is_switching: bool = false
var is_returning_to_menu: bool = false


func _ready() -> void:
	# Sembunyikan feature panel di awal (seperti blacksmith)
	feature.position.x -= 800
	feature.visible = true

	if exit:
		exit.pressed.connect(_on_exit_tavern)
	if buy_item_btn:
		buy_item_btn.pressed.connect(_on_buy_item_pressed)
	if tavern_btn:
		tavern_btn.pressed.connect(_on_tavern_games_pressed)
	if selling_btn:
		selling_btn.pressed.connect(_on_selling_pressed)
	if quest_btn:
		quest_btn.pressed.connect(_on_quest_pressed)
	if announcement_btn:
		announcement_btn.pressed.connect(_on_announcement_pressed)

	_create_gold_display()
	gold_display.visible = false


# ============================================================
# GOLD DISPLAY
# ============================================================

func _create_gold_display() -> void:
	gold_display = Panel.new()
	gold_display.name = "GoldDisplay"
	gold_display.position = Vector2(585, 5)
	gold_display.size = Vector2(140, 25)

	var gold_bg_style = StyleBoxFlat.new()
	gold_bg_style.bg_color = Color(0.1, 0.07, 0.03, 0.85)
	gold_bg_style.border_width_top = 1
	gold_bg_style.border_width_bottom = 1
	gold_bg_style.border_width_left = 1
	gold_bg_style.border_width_right = 1
	gold_bg_style.border_color = Color(0.5, 0.35, 0.15, 0.7)
	gold_bg_style.corner_radius_top_left = 6
	gold_bg_style.corner_radius_top_right = 6
	gold_bg_style.corner_radius_bottom_left = 6
	gold_bg_style.corner_radius_bottom_right = 6
	gold_bg_style.content_margin_left = 10
	gold_bg_style.content_margin_right = 10
	gold_display.add_theme_stylebox_override("panel", gold_bg_style)
	add_child(gold_display)

	gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_label.add_theme_font_size_override("font_size", 14)
	gold_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	gold_label.text = str(PlayerDataManager.get_gold()) + " G"
	gold_display.add_child(gold_label)


func _update_gold_display() -> void:
	if gold_label:
		gold_label.text = str(PlayerDataManager.get_gold()) + " G"


# ============================================================
# FEATURE PANEL SHOW / HIDE
# ============================================================

func _hide_feature() -> void:
	feature.visible = false
	gold_display.visible = false


func _show_feature() -> void:
	feature.visible = true
	gold_display.visible = true


func _show_feature_slide_in() -> void:
	# Slide feature dari kiri ke kanan (seperti blacksmith intro)
	gold_display.visible = true
	var tween = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_property(feature, "position:x", feature.position.x + 800, 0.5)


# ============================================================
# PANEL MANAGEMENT
# ============================================================

func _close_active_panel() -> void:
	if active_panel and is_instance_valid(active_panel):
		var panel_to_close = active_panel
		active_panel = null
		# Call outro if it exists, otherwise just free
		if panel_to_close.has_method("_play_outro"):
			panel_to_close._play_outro()
		else:
			panel_to_close.queue_free()


func _close_active_panel_and_wait() -> void:
	if active_panel and is_instance_valid(active_panel):
		var panel_to_close = active_panel
		active_panel = null
		if panel_to_close.has_method("_play_outro"):
			panel_to_close._play_outro()
			await panel_to_close.tree_exited
		else:
			panel_to_close.queue_free()
			await get_tree().process_frame


func _open_panel(panel: Control) -> void:
	active_panel = panel
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.closed.connect(_on_panel_closed)
	add_child(panel)


# ============================================================
# SHOP
# ============================================================

func _on_buy_item_pressed() -> void:
	if is_switching:
		return
	is_switching = true

	# Close current panel if any
	await _close_active_panel_and_wait()

	_hide_feature()

	var shop = ShopPanel.new()
	_open_panel(shop)
	is_switching = false


# ============================================================
# TAVERN GAMES (Game Selection Menu)
# ============================================================

func _on_tavern_games_pressed() -> void:
	if is_switching:
		return
	is_switching = true

	await _close_active_panel_and_wait()

	_hide_feature()

	var menu = _create_game_selection_menu()
	active_panel = menu
	add_child(menu)
	is_switching = false


func _create_game_selection_menu() -> Control:
	var menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.4)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.modulate.a = 0.0
	menu.add_child(overlay)

	# Panel - same bounds as feature panel
	var sel_panel = Panel.new()
	sel_panel.position = Vector2(35, 21)
	sel_panel.size = Vector2(438, 280)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.56)
	sel_panel.add_theme_stylebox_override("panel", panel_style)
	menu.add_child(sel_panel)

	# Title bar
	var title_bar = Panel.new()
	title_bar.position = Vector2(0, 0)
	title_bar.size = Vector2(438, 30)
	var title_bar_style = StyleBoxFlat.new()
	title_bar_style.bg_color = Color(0.245, 0.169, 0.321, 0.5)
	title_bar.add_theme_stylebox_override("panel", title_bar_style)
	sel_panel.add_child(title_bar)

	var title = Label.new()
	title.text = "Tavern Games"
	title.position = Vector2(0, 3)
	title.size = Vector2(438, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1, 1, 0.2))
	title_bar.add_child(title)

	# Game cards
	var card_w = 205.0
	var card_h = 130.0
	var gap = 8.0

	# Find The Card
	var card1 = _create_game_card(
		"Find The Card",
		"Choose The Right Card!",
		"res://assets/art/items/weapons/iron_sword.png",
		3, 5,
		Color(0.317, 0.097, 0.125, 0.6)
	)
	card1.position = Vector2(10, 40)
	card1.size = Vector2(card_w, card_h)
	card1.pressed.connect(_on_card_game_selected.bind(menu))
	sel_panel.add_child(card1)

	# Word Chain
	var card2 = _create_game_card(
		"Word Chain",
		"Pick Robert's Favorite!",
		"res://assets/art/items/materials/tome_01.png",
		3, 5,
		Color(0.245, 0.169, 0.321, 0.6)
	)
	card2.position = Vector2(10 + card_w + gap, 40)
	card2.size = Vector2(card_w, card_h)
	card2.pressed.connect(_on_word_chain_selected.bind(menu))
	sel_panel.add_child(card2)

	# Brew Challenge (wide card, bottom)
	var card3 = _create_game_card_wide(
		"Brew Challenge",
		"Mix Robert's favorite drink!",
		"res://assets/art/items/consumable/potion/Icon9.png",
		3, 5,
		Color(0.15, 0.25, 0.15, 0.6)
	)
	card3.position = Vector2(10, 40 + card_h + gap)
	card3.size = Vector2(418, 65)
	card3.pressed.connect(_on_drink_mix_selected.bind(menu))
	sel_panel.add_child(card3)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Back"
	close_btn.position = Vector2(370, 248)
	close_btn.size = Vector2(58, 20)

	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0.317, 0.097, 0.125, 0.6)
	close_style.corner_radius_top_left = 4
	close_style.corner_radius_top_right = 4
	close_style.corner_radius_bottom_left = 4
	close_style.corner_radius_bottom_right = 4
	close_btn.add_theme_stylebox_override("normal", close_style)

	var close_hover = close_style.duplicate()
	close_hover.bg_color = Color(0.4, 0.15, 0.18, 0.8)
	close_btn.add_theme_stylebox_override("hover", close_hover)

	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	close_btn.pressed.connect(_on_game_menu_close.bind(menu))
	sel_panel.add_child(close_btn)

	# Intro animation
	_play_panel_intro(menu, overlay, sel_panel)

	return menu


func _create_game_card(game_title: String, subtitle: String, icon_path: String, cost: int, reward: int, bg_color: Color) -> Button:
	var btn = Button.new()
	btn.text = ""

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = bg_color
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	btn_style.content_margin_left = 10
	btn_style.content_margin_top = 8
	btn_style.content_margin_right = 10
	btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = bg_color.lightened(0.12)
	btn.add_theme_stylebox_override("hover", btn_hover)

	# Icon (top center)
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(50, 50)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = Vector2(77.5, 8)
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	btn.add_child(icon)

	# Game title (below icon, center)
	var title_label = Label.new()
	title_label.text = game_title
	title_label.position = Vector2(0, 62)
	title_label.size = Vector2(205, 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	btn.add_child(title_label)

	# Cost label
	var cost_label = Label.new()
	cost_label.text = "Cost: " + str(cost) + "G"
	cost_label.position = Vector2(0, 82)
	cost_label.size = Vector2(205, 16)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 11)
	cost_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	btn.add_child(cost_label)

	# Reward label
	var reward_label = Label.new()
	reward_label.text = "Reward: " + str(reward) + "G"
	reward_label.position = Vector2(0, 100)
	reward_label.size = Vector2(205, 16)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_font_size_override("font_size", 11)
	reward_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
	btn.add_child(reward_label)

	# Subtitle (bottom)
	var sub_label = Label.new()
	sub_label.text = subtitle
	sub_label.position = Vector2(0, 116)
	sub_label.size = Vector2(205, 16)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", 9)
	sub_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8, 0.6))
	btn.add_child(sub_label)

	return btn


func _create_game_card_wide(game_title: String, subtitle: String, icon_path: String, cost: int, reward: int, bg_color: Color) -> Button:
	var btn = Button.new()
	btn.text = ""

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = bg_color
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	btn_style.content_margin_left = 10
	btn_style.content_margin_top = 8
	btn_style.content_margin_right = 10
	btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = bg_color.lightened(0.12)
	btn.add_theme_stylebox_override("hover", btn_hover)

	# Icon (left)
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(50, 50)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = Vector2(8, 8)
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	btn.add_child(icon)

	# Game title (right of icon)
	var title_label = Label.new()
	title_label.text = game_title
	title_label.position = Vector2(70, 6)
	title_label.size = Vector2(300, 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	btn.add_child(title_label)

	# Subtitle
	var sub_label = Label.new()
	sub_label.text = subtitle
	sub_label.position = Vector2(70, 24)
	sub_label.size = Vector2(300, 16)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sub_label.add_theme_font_size_override("font_size", 10)
	sub_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8, 0.6))
	btn.add_child(sub_label)

	# Cost label (right side)
	var cost_label = Label.new()
	cost_label.text = "Cost: " + str(cost) + "G"
	cost_label.position = Vector2(340, 6)
	cost_label.size = Vector2(70, 14)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_label.add_theme_font_size_override("font_size", 11)
	cost_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	btn.add_child(cost_label)

	# Reward label (right side)
	var reward_label = Label.new()
	reward_label.text = "Reward: " + str(reward) + "G"
	reward_label.position = Vector2(330, 22)
	reward_label.size = Vector2(80, 14)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward_label.add_theme_font_size_override("font_size", 11)
	reward_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
	btn.add_child(reward_label)

	return btn


# ============================================================
# CARD GAME (dari game selection)
# ============================================================

func _on_card_game_selected(game_menu: Control) -> void:
	if is_switching:
		return
	is_switching = true

	# Cek gold
	if PlayerDataManager.get_gold() < 3:
		_show_floating_text(game_menu, "Not enough gold!", Color(1, 0.4, 0.3))
		is_switching = false
		return

	# Deduct fee
	PlayerDataManager.spend_gold(3)
	_update_gold_display()

	# Close game selection dengan animasi
	if game_menu and is_instance_valid(game_menu):
		_play_panel_outro(game_menu)
		await game_menu.tree_exited

	# Buka card game
	var game = TavernCardGame.new()
	game.back_to_menu.connect(_on_game_back_to_menu)
	game.game_won.connect(_on_game_won.bind("Find The Card"))
	_open_panel(game)
	is_switching = false


func _on_word_chain_selected(game_menu: Control) -> void:
	if is_switching:
		return
	is_switching = true

	# Cek gold
	if PlayerDataManager.get_gold() < 3:
		_show_floating_text(game_menu, "Not enough gold!", Color(1, 0.4, 0.3))
		is_switching = false
		return

	# Deduct fee
	PlayerDataManager.spend_gold(3)
	_update_gold_display()

	# Close game selection dengan animasi
	if game_menu and is_instance_valid(game_menu):
		_play_panel_outro(game_menu)
		await game_menu.tree_exited

	# Buka word chain game
	var game = TavernWordChain.new()
	game.back_to_menu.connect(_on_game_back_to_menu)
	game.game_won.connect(_on_game_won.bind("Word Chain"))
	_open_panel(game)
	is_switching = false


func _on_drink_mix_selected(game_menu: Control) -> void:
	if is_switching:
		return
	is_switching = true

	# Cek gold
	if PlayerDataManager.get_gold() < 3:
		_show_floating_text(game_menu, "Not enough gold!", Color(1, 0.4, 0.3))
		is_switching = false
		return

	# Deduct fee
	PlayerDataManager.spend_gold(3)
	_update_gold_display()

	# Close game selection dengan animasi
	if game_menu and is_instance_valid(game_menu):
		_play_panel_outro(game_menu)
		await game_menu.tree_exited

	# Buka drink mix game
	var game = TavernDrinkMix.new()
	game.back_to_menu.connect(_on_game_back_to_menu)
	game.game_won.connect(_on_game_won.bind("Brew Challenge"))
	_open_panel(game)
	is_switching = false


func _on_game_back_to_menu() -> void:
	if is_switching:
		return
	is_switching = true
	is_returning_to_menu = true

	# Tunggu game selesai outro
	if active_panel and is_instance_valid(active_panel):
		await active_panel.tree_exited

	active_panel = null

	# Buka game selection menu lagi
	var menu = _create_game_selection_menu()
	active_panel = menu
	add_child(menu)
	is_switching = false


func _on_game_won(game_name: String) -> void:
	var active_id = PlayerDataManager.active_quest_id
	if active_id == "":
		return
	var all_quests = QuestDatabase.get_all_quests()
	for q in all_quests:
		if q.quest_id == active_id and q.quest_type == QuestData.QuestType.PLAY_GAMES and q.get_target() == game_name:
			PlayerDataManager.increment_quest_progress(active_id)
			break


func _show_floating_text(parent: Control, text: String, color: Color) -> void:
	var float_label := Label.new()
	float_label.text = text
	float_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	float_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	float_label.add_theme_font_size_override("font_size", 14)
	float_label.add_theme_color_override("font_color", color)

	var float_bg := StyleBoxFlat.new()
	float_bg.bg_color = Color(0, 0, 0, 0.75)
	float_bg.set_corner_radius_all(10)
	float_bg.content_margin_left = 16.0
	float_bg.content_margin_right = 16.0
	float_bg.content_margin_top = 10.0
	float_bg.content_margin_bottom = 10.0
	float_label.add_theme_stylebox_override("normal", float_bg)

	parent.add_child(float_label)

	float_label.reset_size()
	var target_pos := Vector2(370.0, 130.0)
	float_label.pivot_offset = float_label.size / 2.0
	float_label.position = target_pos - (float_label.size / 2.0)

	float_label.scale = Vector2(0.5, 0.5)
	float_label.modulate.a = 0.0

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CIRC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(float_label, "scale", Vector2(1.0, 1.0), 0.25)
	tween.tween_property(float_label, "modulate:a", 1.0, 0.2)

	tween.chain()
	tween.tween_interval(2.0)

	tween.chain().set_parallel(true)
	tween.set_trans(Tween.TRANS_CIRC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(float_label, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(float_label.queue_free)


func _on_game_menu_close(menu: Control) -> void:
	if is_switching:
		return
	is_switching = true

	_play_panel_outro(menu)
	await menu.tree_exited

	_show_feature()
	is_switching = false


# ============================================================
# SHARED PANEL ANIMATION
# ============================================================

func _play_panel_intro(menu: Control, overlay: Control, panel: Panel) -> void:
	# Overlay fade in
	var tween_overlay = create_tween()
	tween_overlay.tween_property(overlay, "modulate:a", 1.0, 0.25)

	# Panel slide up dari bawah
	var target_y = panel.position.y
	panel.position.y = target_y + 300
	panel.modulate.a = 0.0

	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CIRC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position:y", target_y, 0.35)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)


func _play_panel_outro(menu: Control) -> void:
	if not is_instance_valid(menu):
		return

	# Cari panel child (index 1 = overlay + panel)
	if menu.get_child_count() < 2:
		menu.queue_free()
		return

	var overlay = menu.get_child(0)
	var panel = menu.get_child(1)

	# Panel slide down + fade
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CIRC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "position:y", panel.position.y + 300, 0.3)
	tween.tween_property(panel, "modulate:a", 0.0, 0.25)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.25)
	tween.tween_callback(menu.queue_free)


# ============================================================
# PANEL CLOSED (dari shop/card game)
# ============================================================

func _on_panel_closed() -> void:
	active_panel = null
	if not is_returning_to_menu:
		_show_feature()
	is_returning_to_menu = false
	_update_gold_display()


# ============================================================
# PLACEHOLDER BUTTONS
# ============================================================

func _on_selling_pressed() -> void:
	if is_switching:
		return
	is_switching = true

	await _close_active_panel_and_wait()

	_hide_feature()

	var sell_panel = SellPanel.new()
	_open_panel(sell_panel)
	is_switching = false

func _on_quest_pressed() -> void:
	if is_switching:
		return
	is_switching = true

	await _close_active_panel_and_wait()

	_hide_feature()

	var quest_panel = QuestPanel.new()
	_open_panel(quest_panel)
	is_switching = false

func _on_announcement_pressed() -> void:
	pass


# ============================================================
# EXIT
# ============================================================

func _on_exit_tavern():
	TransitionManager.pindah_scene("res://scenes/locations/maps/lotus_village/lotus_village.tscn")
