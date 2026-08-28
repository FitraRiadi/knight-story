extends Control
class_name SellPanel


# ============================================================
# SELL PANEL
# UI jual item di Tavern. Match style feature panel.
# Bounds: feature = (35, 21, 438, 280)
# ============================================================

signal closed

var panel: Panel
var gold_label: Label
var item_container: VBoxContainer
var empty_label: Label

var overlay: ColorRect

# Style constants (match existing tavern)
const PANEL_BG := Color(0, 0, 0, 0.56)
const TITLE_COLOR := Color(1, 1, 0.2)
const GOLD_COLOR := Color(1, 0.85, 0.2)
const TEXT_COLOR := Color(1, 0.95, 0.8)
const DESC_COLOR := Color(0.7, 0.65, 0.55)
const SELL_NORMAL := Color(0.35, 0.25, 0.05, 0.85)
const SELL_HOVER := Color(0.45, 0.35, 0.08, 1.0)


func _ready() -> void:
	_build_ui()
	_populate_items()
	_update_gold_display()
	_play_intro()


func _build_ui() -> void:
	# Full screen overlay (blocks input behind)
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
	title_bar_style.bg_color = Color(0.317, 0.097, 0.125, 0.6)
	title_bar.add_theme_stylebox_override("panel", title_bar_style)
	panel.add_child(title_bar)

	var title = Label.new()
	title.text = "Sell Your Items"
	title.position = Vector2(0, 3)
	title.size = Vector2(438, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title_bar.add_child(title)

	# Gold display (top-right, inside title bar)
	gold_label = Label.new()
	gold_label.position = Vector2(330, 5)
	gold_label.size = Vector2(100, 20)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_label.add_theme_font_size_override("font_size", 13)
	gold_label.add_theme_color_override("font_color", GOLD_COLOR)
	title_bar.add_child(gold_label)

	# Scrollable item list area (below title bar)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(10, 38)
	scroll.size = Vector2(418, 195)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true

	var scrollbar_v = scroll.get_v_scroll_bar()
	scrollbar_v.custom_minimum_size.x = 4
	scrollbar_v.modulate.a = 0.4

	item_container = VBoxContainer.new()
	item_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_container.add_theme_constant_override("separation", 6)
	scroll.add_child(item_container)
	panel.add_child(scroll)

	# Empty label (shown when inventory is empty)
	empty_label = Label.new()
	empty_label.text = "Your inventory is empty!"
	empty_label.position = Vector2(10, 100)
	empty_label.size = Vector2(418, 30)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 13)
	empty_label.add_theme_color_override("font_color", DESC_COLOR)
	empty_label.visible = false
	panel.add_child(empty_label)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(405, 258)
	close_btn.size = Vector2(28, 18)

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


func _populate_items() -> void:
	var inv_items = PlayerDataManager.data.battle_inventory.items
	var has_items = false

	for i in range(inv_items.size()):
		if inv_items[i] != null:
			var item_res: ItemData = inv_items[i]
			var row = _create_item_row(item_res, i)
			item_container.add_child(row)
			has_items = true

	empty_label.visible = not has_items


func _create_item_row(item_res: ItemData, inventory_index: int) -> PanelContainer:
	var row = PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 55)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.11, 0.067, 0.016, 0.5)
	row_style.corner_radius_top_left = 4
	row_style.corner_radius_top_right = 4
	row_style.corner_radius_bottom_left = 4
	row_style.corner_radius_bottom_right = 4
	row_style.content_margin_top = 6
	row_style.content_margin_bottom = 6
	row_style.content_margin_left = 10
	row_style.content_margin_right = 10
	row.add_theme_stylebox_override("panel", row_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	# Item icon
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(36, 36)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if item_res.icon:
		icon_rect.texture = item_res.icon
	hbox.add_child(icon_rect)

	# Item info (name + desc stacked)
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 1)
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = item_res.item_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", TEXT_COLOR)
	info_vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = item_res.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", DESC_COLOR)
	info_vbox.add_child(desc_label)

	# Sell price
	var price_label = Label.new()
	price_label.text = str(item_res.sell_value) + " G"
	price_label.custom_minimum_size = Vector2(60, 0)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 14)
	price_label.add_theme_color_override("font_color", GOLD_COLOR)
	hbox.add_child(price_label)

	# Sell button
	var sell_btn = Button.new()
	sell_btn.text = "Sell"
	sell_btn.custom_minimum_size = Vector2(50, 28)

	var sell_style = StyleBoxFlat.new()
	sell_style.bg_color = SELL_NORMAL
	sell_style.corner_radius_top_left = 4
	sell_style.corner_radius_top_right = 4
	sell_style.corner_radius_bottom_left = 4
	sell_style.corner_radius_bottom_right = 4
	sell_btn.add_theme_stylebox_override("normal", sell_style)

	var sell_hover = sell_style.duplicate()
	sell_hover.bg_color = SELL_HOVER
	sell_btn.add_theme_stylebox_override("hover", sell_hover)

	sell_btn.add_theme_font_size_override("font_size", 12)
	sell_btn.add_theme_color_override("font_color", TEXT_COLOR)
	sell_btn.pressed.connect(_on_sell_pressed.bind(item_res, inventory_index))
	hbox.add_child(sell_btn)

	return row


func _on_sell_pressed(item_res: ItemData, inventory_index: int) -> void:
	if item_res.sell_value <= 0:
		_show_floating_text("Cannot sell this item!", Color(1, 0.4, 0.3))
		return

	_show_sell_confirmation_popup(item_res, inventory_index)


# ============================================================
# SELL CONFIRMATION POPUP
# ============================================================

func _show_sell_confirmation_popup(item_res: ItemData, inventory_index: int) -> void:
	var sell_price: int = item_res.sell_value
	var item_name: String = item_res.item_name

	# 1. Overlay
	var popup_overlay := Control.new()
	popup_overlay.name = "SellPopupOverlay"
	popup_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# 2. Panel
	var popup_panel := PanelContainer.new()
	popup_panel.name = "ConfirmSellPanel"
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
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_top = 14.0
	panel_style.content_margin_bottom = 14.0
	popup_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)

	# 3. Item Icon
	var popup_icon := TextureRect.new()
	popup_icon.texture = item_res.icon if item_res else null
	popup_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	popup_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	popup_icon.custom_minimum_size = Vector2(64, 64)

	# Style background untuk label
	var label_bg_style := StyleBoxFlat.new()
	label_bg_style.bg_color = Color(0.05, 0.05, 0.07, 0.65)
	label_bg_style.corner_radius_top_left = 4
	label_bg_style.corner_radius_top_right = 4
	label_bg_style.corner_radius_bottom_left = 4
	label_bg_style.corner_radius_bottom_right = 4
	label_bg_style.content_margin_left = 10.0
	label_bg_style.content_margin_right = 10.0
	label_bg_style.content_margin_top = 4.0
	label_bg_style.content_margin_bottom = 4.0

	# 4. Item Name
	var popup_name_label := Label.new()
	popup_name_label.text = item_name
	popup_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup_name_label.add_theme_stylebox_override("normal", label_bg_style)

	# 4b. Item Description (autowrap)
	var popup_desc_label := Label.new()
	popup_desc_label.text = item_res.description
	popup_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup_desc_label.custom_minimum_size = Vector2(200, 0)
	popup_desc_label.add_theme_font_size_override("font_size", 11)
	popup_desc_label.add_theme_color_override("font_color", DESC_COLOR)

	# 5. Confirm text + price + player gold
	var confirm_info_style := StyleBoxFlat.new()
	confirm_info_style.bg_color = Color(0.08, 0.06, 0.02, 0.7)
	confirm_info_style.corner_radius_top_left = 4
	confirm_info_style.corner_radius_top_right = 4
	confirm_info_style.corner_radius_bottom_left = 4
	confirm_info_style.corner_radius_bottom_right = 4
	confirm_info_style.content_margin_left = 10.0
	confirm_info_style.content_margin_right = 10.0
	confirm_info_style.content_margin_top = 6.0
	confirm_info_style.content_margin_bottom = 6.0

	var confirm_vbox := VBoxContainer.new()
	confirm_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_vbox.add_theme_constant_override("separation", 4)
	confirm_vbox.add_theme_stylebox_override("panel", confirm_info_style)

	var confirm_text := Label.new()
	confirm_text.text = "Sell This Item?"
	confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	confirm_text.add_theme_color_override("font_color", GOLD_COLOR)
	confirm_text.add_theme_font_size_override("font_size", 14)
	confirm_vbox.add_child(confirm_text)

	var price_text := Label.new()
	price_text.text = str(sell_price) + " G"
	price_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_text.add_theme_color_override("font_color", GOLD_COLOR)
	price_text.add_theme_font_size_override("font_size", 16)
	confirm_vbox.add_child(price_text)

	var gold_text := Label.new()
	gold_text.text = "Your Gold: " + str(PlayerDataManager.get_gold()) + " G"
	gold_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_text.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	gold_text.add_theme_font_size_override("font_size", 11)
	confirm_vbox.add_child(gold_text)

	# 6. YES / NO Buttons
	var hbox_btns := HBoxContainer.new()
	hbox_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_btns.add_theme_constant_override("separation", 16)

	var yes_btn := Button.new()
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(64, 28)
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

	yes_btn.add_theme_font_size_override("font_size", 12)
	yes_btn.add_theme_color_override("font_color", TEXT_COLOR)

	var no_btn := Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(64, 28)
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

	no_btn.add_theme_font_size_override("font_size", 12)
	no_btn.add_theme_color_override("font_color", TEXT_COLOR)

	hbox_btns.add_child(yes_btn)
	hbox_btns.add_child(no_btn)

	# Susun hierarchy
	vbox.add_child(popup_icon)
	vbox.add_child(popup_name_label)
	vbox.add_child(popup_desc_label)
	vbox.add_child(confirm_vbox)
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

	# Animasi muncul
	var tween := popup_panel.create_tween().set_parallel(true)
	tween.tween_property(popup_panel, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup_panel, "modulate:a", 1.0, 0.15)

	# Signal tombol
	yes_btn.pressed.connect(_confirm_sell_item.bind(item_res, inventory_index, popup_overlay, popup_panel))
	no_btn.pressed.connect(_close_sell_popup.bind(popup_overlay, popup_panel))


func _confirm_sell_item(item_res: ItemData, inventory_index: int, overlay_node: Node, popup_panel: Node) -> void:
	var sell_price: int = item_res.sell_value
	var item_name: String = item_res.item_name

	_close_sell_popup(overlay_node, popup_panel)

	# Proses jual
	PlayerDataManager.add_gold(sell_price)
	PlayerDataManager.remove_item(inventory_index)
	_update_gold_display()
	_show_floating_text("Sold " + item_name + "!", Color(0.4, 1, 0.4))
	_spawn_sell_particles()

	# Refresh list
	_refresh_item_list()


func _close_sell_popup(overlay_node: Node, popup_panel: Node) -> void:
	if not is_instance_valid(overlay_node) or not is_instance_valid(popup_panel):
		return

	var tween := popup_panel.create_tween().set_parallel(true)
	tween.tween_property(popup_panel, "scale", Vector2(0.8, 0.8), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(popup_panel, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(overlay_node.queue_free)


func _refresh_item_list() -> void:
	# Clear existing rows
	for child in item_container.get_children():
		child.queue_free()

	await get_tree().process_frame

	# Re-populate
	_populate_items()


func _update_gold_display() -> void:
	if gold_label:
		gold_label.text = str(PlayerDataManager.get_gold()) + " G"


func _show_floating_text(text: String, color: Color) -> void:
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

	add_child(float_label)

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


func _spawn_sell_particles() -> void:
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
