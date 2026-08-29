extends Control
class_name TavernWordChain


# ============================================================
# TAVERN WORD CHAIN GAME
# Mini-game: Robert kasih 3 kata, tebak kalimat favoritnya.
# Match feature panel layout: (35, 21, 438, 280)
# ============================================================

signal closed
signal back_to_menu
signal game_won

var panel: Panel
var title_bar: Panel
var words_label: Label
var option_buttons: Array[Button] = []
var status_label: Label
var gold_reward_label: Label

var current_set: Dictionary = {}
var is_guessing: bool = false
var overlay: ColorRect

# Style constants (match existing tavern)
const PANEL_BG := Color(0, 0, 0, 0.56)
const TITLE_COLOR := Color(1, 1, 0.2)
const TEXT_COLOR := Color(1, 0.95, 0.8)
const STATUS_COLOR := Color(0.7, 0.65, 0.55)
const GOLD_COLOR := Color(1, 0.85, 0.2)
const WORDS_COLOR := Color(1, 0.9, 0.2)
const OPTION_NORMAL := Color(0.11, 0.067, 0.016, 0.6)
const OPTION_HOVER := Color(0.18, 0.12, 0.03, 0.8)
const OPTION_CORRECT := Color(0.1, 0.35, 0.1, 1.0)
const OPTION_WRONG := Color(0.35, 0.08, 0.08, 1.0)
const OPTION_REVEAL := Color(0.15, 0.4, 0.15, 1.0)

const GOLD_REWARD: int = 5

# Word chain pool
const WORD_CHAIN_POOL: Array[Dictionary] = [
	{
		"words": ["sword", "dark", "chicken"],
		"options": [
			"A dark chicken wielding a sword.",
			"The sword was darker than a chicken.",
			"A chicken brought darkness with its sword.",
			"Darkness fell as the sword missed the chicken."
		],
		"roberts_pick": 3
	},
	{
		"words": ["potion", "dragon", "sleep"],
		"options": [
			"The dragon drank a potion and fell asleep.",
			"A sleeping potion for dragon-sized problems.",
			"Dragons fear potions more than sleep.",
			"Sleep came easy after the dragon's potion."
		],
		"roberts_pick": 0
	},
	{
		"words": ["gold", "mud", "knight"],
		"options": [
			"The knight found gold in the mud.",
			"Muddy gold is still gold, said the knight.",
			"A knight's worth is measured in mud, not gold.",
			"Gold sinks, but a knight rises from mud."
		],
		"roberts_pick": 3
	},
	{
		"words": ["axe", "forest", "singing"],
		"options": [
			"The axe sang as it cut through the forest.",
			"A singing axe in a quiet forest.",
			"Forests grow where axes stop singing.",
			"The singing axe lost its way in the forest."
		],
		"roberts_pick": 2
	},
	{
		"words": ["shield", "rain", "fire"],
		"options": [
			"The shield held against rain and fire.",
			"Fire or rain, a shield endures all.",
			"A shield of fire kept the rain away.",
			"Rain extinguished fire, but not the shield."
		],
		"roberts_pick": 3
	},
	{
		"words": ["tavern", "moon", "thief"],
		"options": [
			"A thief entered the tavern under moonlight.",
			"The moon shone on the tavern thief.",
			"Thieves love moonlit tavern visits.",
			"The tavern's moon saw nothing, said the thief."
		],
		"roberts_pick": 3
	},
	{
		"words": ["crown", "pig", "castle"],
		"options": [
			"A pig wore a crown in the castle.",
			"The castle belonged to a crowned pig.",
			"Better a pig with a crown than none in the castle.",
			"The crown fit the castle pig perfectly."
		],
		"roberts_pick": 2
	},
	{
		"words": ["magic", "boots", "road"],
		"options": [
			"Magic boots carried him down the road.",
			"The road was long, but magic boots were faster.",
			"Boots with magic walked every road twice.",
			"A road ends, but magic boots don't."
		],
		"roberts_pick": 2
	},
	{
		"words": ["arrow", "ghost", "bridge"],
		"options": [
			"The ghost caught the arrow mid-air on the bridge.",
			"An arrow flew through a ghost on the bridge.",
			"Ghosts guard bridges against arrows.",
			"The arrow haunted the bridge like a ghost."
		],
		"roberts_pick": 0
	},
	{
		"words": ["king", "fish", "sword"],
		"options": [
			"The king traded his sword for a fish.",
			"A fish is mightier than a king's sword.",
			"The sword-fishing king ruled the seas.",
			"Kings eat fish, not wield swords."
		],
		"roberts_pick": 2
	},
	{
		"words": ["gem", "rat", "dungeon"],
		"options": [
			"A rat guarded a gem in the dungeon.",
			"The dungeon gem glowed near the rat.",
			"Rats love gems more than dungeon cheese.",
			"The gem was the rat's dungeon treasure."
		],
		"roberts_pick": 0
	},
	{
		"words": ["hammer", "sun", "mountain"],
		"options": [
			"The hammer struck like the sun on a mountain.",
			"A mountain fell when the sun met the hammer.",
			"Hammer the mountain, embrace the sun.",
			"The sun set on the hammer and mountain."
		],
		"roberts_pick": 1
	},
	{
		"words": ["ring", "wolf", "village"],
		"options": [
			"The wolf wore a ring from the village.",
			"A ring protected the village from the wolf.",
			"Villages fear wolves more than missing rings.",
			"The wolf found a ring in the village."
		],
		"roberts_pick": 1
	},
	{
		"words": ["book", "flame", "wizard"],
		"options": [
			"The wizard read the book by flame.",
			"A flame danced on the wizard's book.",
			"The book burned, but the wizard survived.",
			"Flames write better books than wizards."
		],
		"roberts_pick": 3
	},
	{
		"words": ["armor", "mushroom", "quest"],
		"options": [
			"The knight wore armor made of mushroom.",
			"A mushroom dented during the quest for armor.",
			"The quest for mushroom armor was worth it.",
			"Armor protects, but mushrooms heal on a quest."
		],
		"roberts_pick": 2
	}
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
	title.text = "Word Chain"
	title.position = Vector2(0, 3)
	title.size = Vector2(438, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title_bar.add_child(title)

	# Words display (3 kata di atas)
	words_label = Label.new()
	words_label.position = Vector2(10, 35)
	words_label.size = Vector2(418, 24)
	words_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words_label.add_theme_font_size_override("font_size", 16)
	words_label.add_theme_color_override("font_color", WORDS_COLOR)
	words_label.text = "..."
	panel.add_child(words_label)

	# Status label
	status_label = Label.new()
	status_label.position = Vector2(10, 55)
	status_label.size = Vector2(418, 20)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", STATUS_COLOR)
	status_label.text = "Pick the sentence Robert would like!"
	panel.add_child(status_label)

	# Option buttons (4 kalimat pilihan)
	var btn_y = 80.0
	var btn_h = 40.0
	var btn_gap = 6.0

	for i in range(4):
		var btn = Button.new()
		btn.position = Vector2(20, btn_y + i * (btn_h + btn_gap))
		btn.size = Vector2(398, btn_h)
		btn.focus_mode = Control.FOCUS_NONE

		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = OPTION_NORMAL
		btn_style.corner_radius_top_left = 4
		btn_style.corner_radius_top_right = 4
		btn_style.corner_radius_bottom_left = 4
		btn_style.corner_radius_bottom_right = 4
		btn_style.content_margin_left = 10
		btn_style.content_margin_right = 10
		btn_style.content_margin_top = 6
		btn_style.content_margin_bottom = 6
		btn.add_theme_stylebox_override("normal", btn_style)

		var btn_hover = btn_style.duplicate()
		btn_hover.bg_color = OPTION_HOVER
		btn.add_theme_stylebox_override("hover", btn_hover)

		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", TEXT_COLOR)
		btn.text = ""
		btn.pressed.connect(_on_option_pressed.bind(i))
		panel.add_child(btn)
		option_buttons.append(btn)

	# Gold reward label (bottom)
	gold_reward_label = Label.new()
	gold_reward_label.position = Vector2(10, 252)
	gold_reward_label.size = Vector2(418, 22)
	gold_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_reward_label.add_theme_font_size_override("font_size", 14)
	gold_reward_label.add_theme_color_override("font_color", GOLD_COLOR)
	gold_reward_label.visible = false
	panel.add_child(gold_reward_label)


func _play_intro() -> void:
	var tween_overlay = create_tween()
	tween_overlay.tween_property(overlay, "modulate:a", 1.0, 0.25)

	var target_y = panel.position.y
	panel.position.y = target_y + 300
	panel.modulate.a = 0.0

	# Sembunyikan semua content children (termasuk title_bar)
	title_bar.visible = false
	words_label.visible = false
	status_label.visible = false
	gold_reward_label.visible = false
	for btn in option_buttons:
		btn.visible = false

	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CIRC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position:y", target_y, 0.35)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	await tween.finished

	# === TITLE MOMENT ===
	# Title bar fade in
	title_bar.visible = true
	title_bar.modulate.a = 0.0
	var title_tween = create_tween()
	title_tween.tween_property(title_bar, "modulate:a", 1.0, 0.2)

	# Tunggu sebentar — TITLE VISIBLE
	await get_tree().create_timer(0.8).timeout

	# Content children fade in
	words_label.visible = true
	words_label.modulate.a = 0.0
	status_label.visible = true
	status_label.modulate.a = 0.0
	for btn in option_buttons:
		btn.visible = true
		btn.modulate.a = 0.0

	var content_tween = create_tween().set_parallel(true)
	content_tween.tween_property(words_label, "modulate:a", 1.0, 0.3)
	content_tween.tween_property(status_label, "modulate:a", 1.0, 0.3)
	for btn in option_buttons:
		content_tween.tween_property(btn, "modulate:a", 1.0, 0.3)
	await content_tween.finished


func _start_game() -> void:
	is_guessing = false

	# Pick random word set
	current_set = WORD_CHAIN_POOL[randi() % WORD_CHAIN_POOL.size()]

	# Display words
	var words: Array = current_set.get("words", [])
	words_label.text = "\"" + " ".join(words) + "\""

	# Display options
	var options: Array = current_set.get("options", [])
	for i in range(option_buttons.size()):
		if i < options.size():
			option_buttons[i].text = options[i]
			# Reset style
			var s = StyleBoxFlat.new()
			s.bg_color = OPTION_NORMAL
			s.corner_radius_top_left = 4
			s.corner_radius_top_right = 4
			s.corner_radius_bottom_left = 4
			s.corner_radius_bottom_right = 4
			s.content_margin_left = 10
			s.content_margin_right = 10
			s.content_margin_top = 6
			s.content_margin_bottom = 6
			option_buttons[i].add_theme_stylebox_override("normal", s)
			option_buttons[i].disabled = false

	status_label.text = "Pick the sentence Robert would like!"
	status_label.add_theme_color_override("font_color", STATUS_COLOR)
	gold_reward_label.visible = false
	is_guessing = true


func _on_option_pressed(index: int) -> void:
	if not is_guessing:
		return

	is_guessing = false
	var roberts_pick: int = current_set.get("roberts_pick", 0)
	var is_correct = (index == roberts_pick)

	# Disable all buttons
	for btn in option_buttons:
		btn.disabled = true

	# Reveal Robert's pick (always highlight it)
	var reveal_style = StyleBoxFlat.new()
	reveal_style.bg_color = OPTION_REVEAL
	reveal_style.corner_radius_top_left = 4
	reveal_style.corner_radius_top_right = 4
	reveal_style.corner_radius_bottom_left = 4
	reveal_style.corner_radius_bottom_right = 4
	reveal_style.content_margin_left = 10
	reveal_style.content_margin_right = 10
	reveal_style.content_margin_top = 6
	reveal_style.content_margin_bottom = 6
	option_buttons[roberts_pick].add_theme_stylebox_override("normal", reveal_style)

	# Style chosen button
	if is_correct:
		status_label.text = "Correct! Robert loves it!"
		status_label.add_theme_color_override("font_color", Color(0.3, 1, 0.4))
		gold_reward_label.text = "+" + str(GOLD_REWARD) + " Gold"
		gold_reward_label.visible = true
		PlayerDataManager.add_gold(GOLD_REWARD)
		_spawn_particles()
		game_won.emit()
	else:
		# Show wrong style on chosen
		var wrong_style = StyleBoxFlat.new()
		wrong_style.bg_color = OPTION_WRONG
		wrong_style.corner_radius_top_left = 4
		wrong_style.corner_radius_top_right = 4
		wrong_style.corner_radius_bottom_left = 4
		wrong_style.corner_radius_bottom_right = 4
		wrong_style.content_margin_left = 10
		wrong_style.content_margin_right = 10
		wrong_style.content_margin_top = 6
		wrong_style.content_margin_bottom = 6
		option_buttons[index].add_theme_stylebox_override("normal", wrong_style)

		status_label.text = "Wrong! Robert picks differently."
		status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
		gold_reward_label.text = "Robert's pick is highlighted"
		gold_reward_label.visible = true

	# Pop animation on chosen
	option_buttons[index].pivot_offset = option_buttons[index].size / 2.0
	var tween = create_tween()
	tween.tween_property(option_buttons[index], "scale", Vector2(1.03, 1.03), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(option_buttons[index], "scale", Vector2.ONE, 0.1)

	await get_tree().create_timer(2.0).timeout
	_show_play_again(is_correct)


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

	var title_label := Label.new()
	title_label.text = "Play Again?"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", TITLE_COLOR)
	vbox.add_child(title_label)

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
