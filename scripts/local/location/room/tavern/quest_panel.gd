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

# Button colors
const ACCEPT_BG := Color(0.11, 0.35, 0.08, 0.9)
const ACCEPT_HOVER := Color(0.15, 0.45, 0.1, 1.0)
const ACCEPT_BORDER := Color(0.2, 0.6, 0.15, 0.8)

const ACTIVE_BG := Color(0.08, 0.12, 0.22, 0.85)
const ACTIVE_BORDER := Color(0.2, 0.4, 0.7, 0.7)

const LOCKED_BG := Color(0.08, 0.08, 0.08, 0.35)
const LOCKED_BORDER := Color(0.13, 0.13, 0.13, 0.25)

const DONE_BG := Color(0.08, 0.22, 0.12, 0.7)
const DONE_BORDER := Color(0.15, 0.45, 0.2, 0.6)

const CLAIM_BG := Color(0.35, 0.25, 0.05, 0.9)
const CLAIM_HOVER := Color(0.45, 0.35, 0.08, 1.0)
const CLAIM_BORDER := Color(0.7, 0.55, 0.1, 0.8)


func _ready() -> void:
	QuestTracker.check_collect_quest_progress()
	_build_ui()
	_populate_quests()
	_play_intro()


func _build_ui() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.4)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.modulate.a = 0.0
	add_child(overlay)

	panel = Panel.new()
	panel.position = Vector2(35, 21)
	panel.size = Vector2(438, 280)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

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

	gold_label = Label.new()
	gold_label.text = str(PlayerDataManager.get_gold()) + " G"
	gold_label.position = Vector2(340, 5)
	gold_label.size = Vector2(90, 20)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_label.add_theme_font_size_override("font_size", 13)
	gold_label.add_theme_color_override("font_color", GOLD_COLOR)
	title_bar.add_child(gold_label)

	scroll = ScrollContainer.new()
	scroll.position = Vector2(10, 38)
	scroll.size = Vector2(418, 200)
	scroll.follow_focus = true
	var scrollbar_v = scroll.get_v_scroll_bar()
	scrollbar_v.custom_minimum_size.x = 4
	scrollbar_v.modulate.a = 0.4
	panel.add_child(scroll)

	quest_container = VBoxContainer.new()
	quest_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_container.add_theme_constant_override("separation", 6)
	scroll.add_child(quest_container)

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


# ============================================================
# QUEST LIST
# ============================================================

func _populate_quests() -> void:
	for child in quest_container.get_children():
		child.queue_free()

	var active_id = PlayerDataManager.active_quest_id
	var displayed_ids: Array = PlayerDataManager.displayed_quest_ids

	# Kalau belum ada displayed quests, shuffle baru
	if displayed_ids.is_empty():
		_fill_new_quests()
		displayed_ids = PlayerDataManager.displayed_quest_ids

	# Cek apakah SEMUA displayed quests sudah completed
	var all_done = true
	for qid in displayed_ids:
		if not PlayerDataManager.is_quest_completed(qid):
			all_done = false
			break

	# Kalau semua done, shuffle ulang
	if all_done and displayed_ids.size() > 0:
		PlayerDataManager.set_displayed_quests([])
		_fill_new_quests()
		displayed_ids = PlayerDataManager.displayed_quest_ids

	# Tampilkan
	for qid in displayed_ids:
		var quest = QuestDatabase.get_quest(qid)
		if quest:
			var row = _create_quest_row(quest, active_id)
			quest_container.add_child(row)


func _fill_new_quests() -> void:
	var active_id = PlayerDataManager.active_quest_id
	var all_quests = QuestDatabase.get_all_quests()

	var pool: Array = []
	for q in all_quests:
		if q.quest_id != active_id and not PlayerDataManager.is_quest_completed(q.quest_id):
			pool.append(q)

	pool.shuffle()

	var max_display = 2 if active_id != "" else 3
	var new_ids: Array = []
	for i in range(mini(max_display, pool.size())):
		new_ids.append(pool[i].quest_id)

	PlayerDataManager.set_displayed_quests(new_ids)


# ============================================================
# QUEST ROW
# ============================================================

func _create_quest_row(quest: QuestData, active_id: String) -> PanelContainer:
	var row = PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 72)

	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.08, 0.12, 0.22, 0.55) if active_id == quest.quest_id else Color(0.11, 0.067, 0.016, 0.5)
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

	var is_completed = PlayerDataManager.is_quest_completed(quest.quest_id)
	var is_active = active_id == quest.quest_id
	var no_active = active_id == ""

	# Strikethrough + dim untuk quest yang selesai
	if is_completed:
		row.modulate.a = 0.45

	# Quest name
	var name_label = Label.new()
	name_label.text = quest.quest_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", TITLE_COLOR if not is_completed else Color(0.5, 0.5, 0.5))
	info_vbox.add_child(name_label)

	# Quest type + objective
	var type_label = Label.new()
	type_label.text = quest.get_type_display() + " — " + quest.get_target_display()
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", DESC_COLOR if not is_completed else Color(0.45, 0.42, 0.38))
	info_vbox.add_child(type_label)

	# Progress + reward — cap progress di target_count
	var progress = PlayerDataManager.get_quest_progress(quest.quest_id)
	var display_progress = mini(progress, quest.target_count)
	var progress_text = "Progress: " + str(display_progress) + "/" + str(quest.target_count)
	var reward_text = "Reward: " + quest.get_reward_text()

	var info_label = Label.new()
	info_label.text = progress_text + "  |  " + reward_text
	info_label.add_theme_font_size_override("font_size", 10)
	info_label.add_theme_color_override("font_color", PROGRESS_COLOR if not is_completed else Color(0.4, 0.5, 0.6))
	info_vbox.add_child(info_label)

	# Right side (button)
	var btn_vbox = VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(btn_vbox)

	var action_btn = Button.new()
	action_btn.custom_minimum_size = Vector2(70, 26)
	action_btn.focus_mode = Control.FOCUS_NONE

	if is_completed:
		# DONE
		action_btn.text = "Done"
		action_btn.disabled = true
		action_btn.add_theme_stylebox_override("normal", _make_btn_style(DONE_BG, DONE_BORDER))
		action_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 0.55))
	elif is_active and progress >= quest.target_count:
		# CLAIM — ready to complete
		action_btn.text = "Claim"
		action_btn.add_theme_stylebox_override("normal", _make_btn_style(CLAIM_BG, CLAIM_BORDER))
		action_btn.add_theme_stylebox_override("hover", _make_btn_style(CLAIM_HOVER, CLAIM_BORDER))
		action_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		action_btn.pressed.connect(_on_claim_pressed.bind(quest))
	elif is_active:
		# ONGOING — in progress
		action_btn.text = "Ongoing"
		action_btn.disabled = true
		action_btn.add_theme_stylebox_override("normal", _make_btn_style(ACTIVE_BG, ACTIVE_BORDER))
		action_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	elif no_active:
		# ACCEPT
		action_btn.text = "Accept"
		action_btn.add_theme_stylebox_override("normal", _make_btn_style(ACCEPT_BG, ACCEPT_BORDER))
		action_btn.add_theme_stylebox_override("hover", _make_btn_style(ACCEPT_HOVER, ACCEPT_BORDER))
		action_btn.add_theme_color_override("font_color", Color(0.7, 1.0, 0.6))
		action_btn.pressed.connect(_on_accept_pressed.bind(quest))
	else:
		# LOCKED
		action_btn.text = "Locked"
		action_btn.disabled = true
		action_btn.add_theme_stylebox_override("normal", _make_btn_style(LOCKED_BG, LOCKED_BORDER))
		action_btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))

	action_btn.add_theme_font_size_override("font_size", 11)
	btn_vbox.add_child(action_btn)

	return row


func _make_btn_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg_color
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = border_color
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	return s


# ============================================================
# ACCEPT / CLAIM
# ============================================================

func _on_accept_pressed(quest: QuestData) -> void:
	_show_accept_popup(quest)


func _on_claim_pressed(quest: QuestData) -> void:
	_show_claim_popup(quest)


func _do_accept(quest: QuestData) -> void:
	PlayerDataManager.set_active_quest(quest.quest_id)
	QuestTracker.check_collect_quest_progress()
	_spawn_accept_particles()
	_populate_quests()
	_update_gold()


func _do_claim(quest: QuestData) -> void:
	if quest.reward_gold > 0:
		PlayerDataManager.add_gold(quest.reward_gold)
	if quest.reward_exp > 0:
		var leveled_up = PlayerDataManager.add_exp(quest.reward_exp)
		if leveled_up:
			_show_level_up()

	_spawn_quest_complete_particles()
	PlayerDataManager.mark_quest_completed(quest.quest_id)
	PlayerDataManager.clear_active_quest()
	_populate_quests()
	_update_gold()


# ============================================================
# ACCEPT POPUP
# ============================================================

func _show_accept_popup(quest: QuestData) -> void:
	var popup_overlay := Control.new()
	popup_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var popup_panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	ps.set_border_width_all(2)
	ps.border_color = Color(0.2, 0.5, 0.15, 0.8)
	ps.set_corner_radius_all(6)
	ps.content_margin_left = 16.0
	ps.content_margin_right = 16.0
	ps.content_margin_top = 14.0
	ps.content_margin_bottom = 14.0
	popup_panel.add_theme_stylebox_override("panel", ps)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)

	# Title
	var title_lbl := Label.new()
	title_lbl.text = "Accept This Quest?"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(0.7, 1.0, 0.6))
	vbox.add_child(title_lbl)

	# Quest name
	var name_lbl := Label.new()
	name_lbl.text = quest.quest_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", TITLE_COLOR)
	vbox.add_child(name_lbl)

	# Objective
	var obj_lbl := Label.new()
	obj_lbl.text = quest.get_target_display()
	obj_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obj_lbl.add_theme_font_size_override("font_size", 11)
	obj_lbl.add_theme_color_override("font_color", DESC_COLOR)
	vbox.add_child(obj_lbl)

	# Reward info
	var reward_info_style := StyleBoxFlat.new()
	reward_info_style.bg_color = Color(0.08, 0.06, 0.02, 0.7)
	reward_info_style.set_corner_radius_all(4)
	reward_info_style.content_margin_left = 10.0
	reward_info_style.content_margin_right = 10.0
	reward_info_style.content_margin_top = 6.0
	reward_info_style.content_margin_bottom = 6.0

	var reward_vbox := VBoxContainer.new()
	reward_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_vbox.add_theme_constant_override("separation", 2)
	reward_vbox.add_theme_stylebox_override("panel", reward_info_style)

	var reward_lbl := Label.new()
	reward_lbl.text = "Reward: " + quest.get_reward_text()
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_lbl.add_theme_font_size_override("font_size", 12)
	reward_lbl.add_theme_color_override("font_color", GOLD_COLOR)
	reward_vbox.add_child(reward_lbl)

	vbox.add_child(reward_vbox)

	# Buttons
	var hbox_btns := HBoxContainer.new()
	hbox_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_btns.add_theme_constant_override("separation", 16)

	var yes_btn := Button.new()
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(64, 28)
	yes_btn.focus_mode = Control.FOCUS_NONE
	yes_btn.add_theme_stylebox_override("normal", _make_btn_style(ACCEPT_BG, ACCEPT_BORDER))
	yes_btn.add_theme_stylebox_override("hover", _make_btn_style(ACCEPT_HOVER, ACCEPT_BORDER))
	yes_btn.add_theme_font_size_override("font_size", 12)
	yes_btn.add_theme_color_override("font_color", TEXT_COLOR)

	var no_btn := Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(64, 28)
	no_btn.focus_mode = Control.FOCUS_NONE
	no_btn.add_theme_stylebox_override("normal", _make_btn_style(Color(0.317, 0.097, 0.125, 0.6), Color(0.5, 0.15, 0.18, 0.6)))
	no_btn.add_theme_stylebox_override("hover", _make_btn_style(Color(0.4, 0.15, 0.18, 0.8), Color(0.5, 0.15, 0.18, 0.8)))
	no_btn.add_theme_font_size_override("font_size", 12)
	no_btn.add_theme_color_override("font_color", TEXT_COLOR)

	hbox_btns.add_child(yes_btn)
	hbox_btns.add_child(no_btn)
	vbox.add_child(hbox_btns)

	popup_panel.add_child(vbox)
	popup_overlay.add_child(popup_panel)
	add_child(popup_overlay)

	popup_panel.reset_size()
	var target_pos := Vector2(370.0, 170.0)
	popup_panel.pivot_offset = popup_panel.size / 2.0
	popup_panel.position = target_pos - (popup_panel.size / 2.0)
	popup_panel.scale = Vector2(0.2, 0.2)
	popup_panel.modulate.a = 0.0

	var tween := popup_panel.create_tween().set_parallel(true)
	tween.tween_property(popup_panel, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup_panel, "modulate:a", 1.0, 0.15)

	yes_btn.pressed.connect(func():
		_close_popup(popup_overlay)
		_do_accept(quest)
	)
	no_btn.pressed.connect(func():
		_close_popup(popup_overlay)
	)


# ============================================================
# CLAIM POPUP
# ============================================================

func _show_claim_popup(quest: QuestData) -> void:
	var popup_overlay := Control.new()
	popup_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var popup_panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	ps.set_border_width_all(2)
	ps.border_color = Color(0.7, 0.55, 0.1, 0.8)
	ps.set_corner_radius_all(6)
	ps.content_margin_left = 16.0
	ps.content_margin_right = 16.0
	ps.content_margin_top = 14.0
	ps.content_margin_bottom = 14.0
	popup_panel.add_theme_stylebox_override("panel", ps)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)

	# Title
	var title_lbl := Label.new()
	title_lbl.text = "Complete This Quest?"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", GOLD_COLOR)
	vbox.add_child(title_lbl)

	# Quest name
	var name_lbl := Label.new()
	name_lbl.text = quest.quest_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", TITLE_COLOR)
	vbox.add_child(name_lbl)

	# Reward
	var reward_info_style := StyleBoxFlat.new()
	reward_info_style.bg_color = Color(0.08, 0.06, 0.02, 0.7)
	reward_info_style.set_corner_radius_all(4)
	reward_info_style.content_margin_left = 10.0
	reward_info_style.content_margin_right = 10.0
	reward_info_style.content_margin_top = 6.0
	reward_info_style.content_margin_bottom = 6.0

	var reward_vbox := VBoxContainer.new()
	reward_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_vbox.add_theme_constant_override("separation", 2)
	reward_vbox.add_theme_stylebox_override("panel", reward_info_style)

	var gold_lbl := Label.new()
	if quest.reward_gold > 0:
		gold_lbl.text = "+" + str(quest.reward_gold) + " Gold"
	else:
		gold_lbl.text = ""
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_lbl.add_theme_font_size_override("font_size", 13)
	gold_lbl.add_theme_color_override("font_color", GOLD_COLOR)
	reward_vbox.add_child(gold_lbl)

	var exp_lbl := Label.new()
	if quest.reward_exp > 0:
		exp_lbl.text = "+" + str(quest.reward_exp) + " EXP"
	else:
		exp_lbl.text = ""
	exp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_lbl.add_theme_font_size_override("font_size", 13)
	exp_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	reward_vbox.add_child(exp_lbl)

	vbox.add_child(reward_vbox)

	# Buttons
	var hbox_btns := HBoxContainer.new()
	hbox_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_btns.add_theme_constant_override("separation", 16)

	var yes_btn := Button.new()
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(64, 28)
	yes_btn.focus_mode = Control.FOCUS_NONE
	yes_btn.add_theme_stylebox_override("normal", _make_btn_style(CLAIM_BG, CLAIM_BORDER))
	yes_btn.add_theme_stylebox_override("hover", _make_btn_style(CLAIM_HOVER, CLAIM_BORDER))
	yes_btn.add_theme_font_size_override("font_size", 12)
	yes_btn.add_theme_color_override("font_color", GOLD_COLOR)

	var no_btn := Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(64, 28)
	no_btn.focus_mode = Control.FOCUS_NONE
	no_btn.add_theme_stylebox_override("normal", _make_btn_style(Color(0.317, 0.097, 0.125, 0.6), Color(0.5, 0.15, 0.18, 0.6)))
	no_btn.add_theme_stylebox_override("hover", _make_btn_style(Color(0.4, 0.15, 0.18, 0.8), Color(0.5, 0.15, 0.18, 0.8)))
	no_btn.add_theme_font_size_override("font_size", 12)
	no_btn.add_theme_color_override("font_color", TEXT_COLOR)

	hbox_btns.add_child(yes_btn)
	hbox_btns.add_child(no_btn)
	vbox.add_child(hbox_btns)

	popup_panel.add_child(vbox)
	popup_overlay.add_child(popup_panel)
	add_child(popup_overlay)

	popup_panel.reset_size()
	var target_pos := Vector2(370.0, 170.0)
	popup_panel.pivot_offset = popup_panel.size / 2.0
	popup_panel.position = target_pos - (popup_panel.size / 2.0)
	popup_panel.scale = Vector2(0.2, 0.2)
	popup_panel.modulate.a = 0.0

	var tween := popup_panel.create_tween().set_parallel(true)
	tween.tween_property(popup_panel, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup_panel, "modulate:a", 1.0, 0.15)

	yes_btn.pressed.connect(func():
		_close_popup(popup_overlay)
		_do_claim(quest)
	)
	no_btn.pressed.connect(func():
		_close_popup(popup_overlay)
	)


func _close_popup(overlay: Control) -> void:
	if not is_instance_valid(overlay):
		return
	var tw := overlay.create_tween().set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.15)
	tw.tween_callback(overlay.queue_free)


# ============================================================
# LEVEL UP
# ============================================================

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


# ============================================================
# PARTICLES
# ============================================================

func _spawn_quest_complete_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.position = Vector2(220, 150)
	particles.z_index = 100
	particles.amount = 16
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 0.9
	particles.direction = Vector2(0, -1)
	particles.spread = 70.0
	particles.gravity = Vector2(0, 150)
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 120.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1.0, 0.85, 0.2, 0.9)
	particles.color_ramp = _make_gold_ramp()
	add_child(particles)
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	if is_instance_valid(particles):
		particles.queue_free()


func _spawn_accept_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.position = Vector2(220, 150)
	particles.z_index = 100
	particles.amount = 10
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 0.85
	particles.direction = Vector2(0, -1)
	particles.spread = 50.0
	particles.gravity = Vector2(0, 100)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 80.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	particles.color = Color(0.4, 0.9, 0.3, 0.85)
	particles.color_ramp = _make_green_ramp()
	add_child(particles)
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	if is_instance_valid(particles):
		particles.queue_free()


func _make_gold_ramp() -> Gradient:
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.2, 1.0))
	g.set_color(1, Color(0.8, 0.4, 0.1, 0.0))
	return g


func _make_green_ramp() -> Gradient:
	var g = Gradient.new()
	g.set_color(0, Color(0.4, 0.9, 0.3, 1.0))
	g.set_color(1, Color(0.1, 0.5, 0.05, 0.0))
	return g


# ============================================================
# MISC
# ============================================================

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
