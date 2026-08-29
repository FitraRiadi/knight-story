extends Control
class_name QuestPanel


# ============================================================
# QUEST BOARD
# Papan quest di tavern. Pilih 1 quest, kerjain, claim reward.
# Bounds: (35, 21, 438, 280)
# ============================================================

signal closed

var panel: Panel
var title_bar: Panel
var scroll: ScrollContainer
var quest_container: VBoxContainer
var gold_label: Label
var overlay: ColorRect

const PANEL_BG := Color(0, 0, 0, 0.56)
const TITLE_COLOR := Color(1, 1, 0.2)
const TEXT_COLOR := Color(1, 0.95, 0.8)
const DESC_COLOR := Color(0.7, 0.65, 0.55)
const GOLD_COLOR := Color(1, 0.85, 0.2)
const PROGRESS_COLOR := Color(0.6, 0.8, 1.0)
const ACCEPT_NORMAL := Color(0.11, 0.35, 0.08, 0.85)
const ACCEPT_HOVER := Color(0.15, 0.45, 0.1, 1.0)
const CLAIM_NORMAL := Color(0.35, 0.25, 0.05, 0.85)
const CLAIM_HOVER := Color(0.45, 0.35, 0.08, 1.0)
const LOCKED_COLOR := Color(0.4, 0.4, 0.4, 0.5)


func _ready() -> void:
	_build_ui()
	_populate_quests()
	_play_intro()


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
	title_bar_style.bg_color = Color(0.1098, 0.0667, 0.0157, 0.85)
	title_bar.add_theme_stylebox_override("panel", title_bar_style)
	panel.add_child(title_bar)

	var title = Label.new()
	title.text = "Quest Board"
	title.position = Vector2(0, 3)
	title.size = Vector2(438, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title_bar.add_child(title)

	# Gold display
	gold_label = Label.new()
	gold_label.text = str(PlayerDataManager.get_gold()) + " G"
	gold_label.position = Vector2(340, 5)
	gold_label.size = Vector2(90, 20)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_label.add_theme_font_size_override("font_size", 13)
	gold_label.add_theme_color_override("font_color", GOLD_COLOR)
	title_bar.add_child(gold_label)

	# Scroll container
	scroll = ScrollContainer.new()
	scroll.position = Vector2(10, 38)
	scroll.size = Vector2(418, 200)
	scroll.follow_focus = true
	var scrollbar_v = scroll.get_v_scroll_bar()
	scrollbar_v.custom_minimum_size.x = 4
	scrollbar_v.modulate.a = 0.4
	panel.add_child(scroll)

	# Quest container
	quest_container = VBoxContainer.new()
	quest_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_container.add_theme_constant_override("separation", 6)
	scroll.add_child(quest_container)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(405, 258)
	close_btn.size = Vector2(28, 18)
	close_btn.focus_mode = Control.FOCUS_NONE

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
	close_btn.add_theme_color_override("font_color", TEXT_COLOR)
	close_btn.pressed.connect(_on_close_pressed)
	panel.add_child(close_btn)


func _populate_quests() -> void:
	# Clear existing
	for child in quest_container.get_children():
		child.queue_free()

	var all_quests = QuestDatabase.get_all_quests()
	var active_id = PlayerDataManager.active_quest_id

	# Build display list: active quest first, then random 2 from pool
	var display: Array = []
	var active_quest = null
	var pool: Array = []

	for quest in all_quests:
		if quest.quest_id == active_id:
			active_quest = quest
		else:
			pool.append(quest)

	# Active quest always first
	if active_quest:
		display.append(active_quest)

	# Fill remaining slots with random quests (max 3 total)
	pool.shuffle()
	var slots_left = 3 - display.size()
	for i in range(mini(slots_left, pool.size())):
		display.append(pool[i])

	for quest in display:
		var row = _create_quest_row(quest, active_id)
		quest_container.add_child(row)


func _create_quest_row(quest: QuestData, active_id: String) -> PanelContainer:
	var row = PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 72)

	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.11, 0.067, 0.016, 0.5)
	row_style.corner_radius_top_left = 4
	row_style.corner_radius_top_right = 4
	row_style.corner_radius_bottom_left = 4
	row_style.corner_radius_bottom_right = 4
	row_style.content_margin_left = 10
	row_style.content_margin_right = 10
	row_style.content_margin_top = 6
	row_style.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", row_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	# Left side (info)
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	# Quest name
	var name_label = Label.new()
	name_label.text = quest.quest_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", TITLE_COLOR)
	info_vbox.add_child(name_label)

	# Quest type + objective
	var type_label = Label.new()
	type_label.text = quest.get_type_display() + " — " + quest.get_target_display()
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", DESC_COLOR)
	info_vbox.add_child(type_label)

	# Progress + reward
	var progress = PlayerDataManager.get_quest_progress(quest.quest_id)
	var progress_text = "Progress: " + str(progress) + "/" + str(quest.target_count)
	var reward_text = "Reward: " + quest.get_reward_text()

	var info_label = Label.new()
	info_label.text = progress_text + "  |  " + reward_text
	info_label.add_theme_font_size_override("font_size", 10)
	info_label.add_theme_color_override("font_color", PROGRESS_COLOR)
	info_vbox.add_child(info_label)

	# Right side (button)
	var btn_vbox = VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(btn_vbox)

	var action_btn = Button.new()
	action_btn.custom_minimum_size = Vector2(70, 26)
	action_btn.focus_mode = Control.FOCUS_NONE

	if active_id == quest.quest_id:
		# Active quest — show progress or claim
		if progress >= quest.target_count:
			action_btn.text = "Claim"
			var claim_style = StyleBoxFlat.new()
			claim_style.bg_color = CLAIM_NORMAL
			claim_style.corner_radius_top_left = 4
			claim_style.corner_radius_top_right = 4
			claim_style.corner_radius_bottom_left = 4
			claim_style.corner_radius_bottom_right = 4
			action_btn.add_theme_stylebox_override("normal", claim_style)
			var claim_hover = claim_style.duplicate()
			claim_hover.bg_color = CLAIM_HOVER
			action_btn.add_theme_stylebox_override("hover", claim_hover)
			action_btn.pressed.connect(_on_claim_pressed.bind(quest))
		else:
			action_btn.text = "Active"
			action_btn.disabled = true
			var active_style = StyleBoxFlat.new()
			active_style.bg_color = Color(0.2, 0.2, 0.2, 0.6)
			active_style.corner_radius_top_left = 4
			active_style.corner_radius_top_right = 4
			active_style.corner_radius_bottom_left = 4
			active_style.corner_radius_bottom_right = 4
			action_btn.add_theme_stylebox_override("normal", active_style)
	elif active_id == "":
		# No active quest — show accept
		action_btn.text = "Accept"
		var accept_style = StyleBoxFlat.new()
		accept_style.bg_color = ACCEPT_NORMAL
		accept_style.corner_radius_top_left = 4
		accept_style.corner_radius_top_right = 4
		accept_style.corner_radius_bottom_left = 4
		accept_style.corner_radius_bottom_right = 4
		action_btn.add_theme_stylebox_override("normal", accept_style)
		var accept_hover = accept_style.duplicate()
		accept_hover.bg_color = ACCEPT_HOVER
		action_btn.add_theme_stylebox_override("hover", accept_hover)
		action_btn.pressed.connect(_on_accept_pressed.bind(quest))
	else:
		# Another quest is active — locked
		action_btn.text = "Locked"
		action_btn.disabled = true
		var locked_style = StyleBoxFlat.new()
		locked_style.bg_color = Color(0.2, 0.2, 0.2, 0.4)
		locked_style.corner_radius_top_left = 4
		locked_style.corner_radius_top_right = 4
		locked_style.corner_radius_bottom_left = 4
		locked_style.corner_radius_bottom_right = 4
		action_btn.add_theme_stylebox_override("normal", locked_style)

	action_btn.add_theme_font_size_override("font_size", 11)
	action_btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn_vbox.add_child(action_btn)

	return row


func _on_accept_pressed(quest: QuestData) -> void:
	PlayerDataManager.set_active_quest(quest.quest_id)

	# For collect_items, check current inventory count
	if quest.quest_type == QuestData.QuestType.COLLECT_ITEMS:
		var count = PlayerDataManager.count_item_in_inventory(quest.get_target())
		PlayerDataManager.set_quest_progress(quest.quest_id, count)

	_populate_quests()
	_update_gold()


func _on_claim_pressed(quest: QuestData) -> void:
	# Give rewards
	if quest.reward_gold > 0:
		PlayerDataManager.add_gold(quest.reward_gold)
	if quest.reward_exp > 0:
		var leveled_up = PlayerDataManager.add_exp(quest.reward_exp)
		if leveled_up:
			_show_level_up()

	# Clear active quest
	PlayerDataManager.clear_active_quest()

	_populate_quests()
	_update_gold()


func _show_level_up() -> void:
	var label = Label.new()
	label.text = "LEVEL UP! Lv." + str(PlayerDataManager.get_level())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 0.2))

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.75)
	bg_style.set_corner_radius_all(10)
	bg_style.content_margin_left = 20
	bg_style.content_margin_right = 20
	bg_style.content_margin_top = 12
	bg_style.content_margin_bottom = 12
	label.add_theme_stylebox_override("normal", bg_style)

	add_child(label)
	label.reset_size()
	label.position = Vector2(370.0 - label.size.x / 2.0, 130.0 - label.size.y / 2.0)
	label.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)


func _update_gold() -> void:
	if gold_label:
		gold_label.text = str(PlayerDataManager.get_gold()) + " G"


func _on_close_pressed() -> void:
	_play_outro()


func _play_intro() -> void:
	var tween_overlay = create_tween()
	tween_overlay.tween_property(overlay, "modulate:a", 1.0, 0.25)

	var target_y = panel.position.y
	panel.position.y = target_y + 300
	panel.modulate.a = 0.0

	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CIRC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position:y", target_y, 0.35)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)


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
