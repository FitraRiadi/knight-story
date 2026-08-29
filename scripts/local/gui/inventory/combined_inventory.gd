extends Control
class_name CombinedInventory


# ============================================================
# COMBINED INVENTORY
# Battle inventory (3×3) + Chest inventory (4×4)
# View only + Drop item.
# Style mengikuti blacksmith slot.
# ============================================================

signal closed


# --- Node refs ---
var overlay: ColorRect
var panel: Panel

# Battle grid
var battle_grid: GridContainer
var battle_slots: Array[Button] = []
var battle_slot_icons: Array[TextureRect] = []

# Chest grid
var chest_grid: GridContainer
var chest_slots: Array[Button] = []
var chest_slot_icons: Array[TextureRect] = []

# Item info
var info_icon: TextureRect
var info_name: Label
var info_desc: Label
var info_rarity: Label
var info_type: Label
var info_effect: Label
var drop_btn: Button

# --- State ---
var active_inv_type: String = ""  # "battle" atau "chest"
var active_slot_index: int = -1


# ============================================================
# CONSTANTS
# ============================================================

const PANEL_SIZE := Vector2(520, 340)
const PANEL_BG := Color(0.0, 0.0, 0.0, 0.66)

const TITLE_BAR_COLOR := Color(0.317, 0.097, 0.125, 0.6)
const TITLE_COLOR := Color(1, 1, 0.25)
const TEXT_COLOR := Color(1, 0.95, 0.8)
const DESC_COLOR := Color(0.7, 0.65, 0.55)
const LABEL_COLOR := Color(0.6, 0.55, 0.5)

const SLOT_SIZE := Vector2(48, 48)
const SLOT_GAP := 4

const SLOT_NORMAL_BG := Color(0.056, 0.056, 0.056, 0.69)
const SLOT_SHADOW_COLOR := Color(0.924, 0.896, 0.985, 0.6)
const SLOT_ACTIVE_BORDER := Color(0.189, 0.813, 0.930, 0.62)

const CLOSE_BG := Color(0.317, 0.097, 0.125, 0.6)
const CLOSE_HOVER := Color(0.4, 0.15, 0.18, 0.8)

const DROP_BG := Color(0.6, 0.15, 0.1, 0.85)
const DROP_HOVER := Color(0.75, 0.2, 0.12, 1.0)


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	_build_ui()
	_populate_all_slots()
	_play_intro()


# ============================================================
# BUILD UI
# ============================================================

func _build_ui() -> void:
	_build_overlay()
	_build_panel()
	_build_title_bar()
	_build_close_button()
	_build_section_labels()
	_build_battle_grid()
	_build_chest_grid()
	_build_divider()
	_build_item_info()


func _build_overlay() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.4)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.modulate.a = 0.0
	add_child(overlay)


func _build_panel() -> void:
	panel = Panel.new()
	var viewport_size := get_viewport_rect().size
	panel.position = Vector2(
		(viewport_size.x - PANEL_SIZE.x) / 2.0,
		(viewport_size.y - PANEL_SIZE.y) / 2.0
	)
	panel.size = PANEL_SIZE

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)


func _build_title_bar() -> void:
	var title_bar := Panel.new()
	title_bar.position = Vector2(0, 0)
	title_bar.size = Vector2(PANEL_SIZE.x, 30)

	var title_style := StyleBoxFlat.new()
	title_style.bg_color = TITLE_BAR_COLOR
	title_bar.add_theme_stylebox_override("panel", title_style)
	panel.add_child(title_bar)

	var title := Label.new()
	title.text = "Inventory"
	title.position = Vector2(0, 4)
	title.size = Vector2(PANEL_SIZE.x, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title_bar.add_child(title)


func _build_close_button() -> void:
	var btn := Button.new()
	btn.text = "X"
	btn.position = Vector2(PANEL_SIZE.x - 32, 5)
	btn.size = Vector2(26, 20)

	var style := StyleBoxFlat.new()
	style.bg_color = CLOSE_BG
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = CLOSE_HOVER
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.pressed.connect(_on_close_pressed)
	panel.add_child(btn)


func _build_section_labels() -> void:
	# Battle label
	var battle_label := Label.new()
	battle_label.text = "BATTLE"
	battle_label.position = Vector2(16, 36)
	battle_label.size = Vector2(152, 14)
	battle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_label.add_theme_font_size_override("font_size", 9)
	battle_label.add_theme_color_override("font_color", LABEL_COLOR)
	panel.add_child(battle_label)

	# Chest label
	var chest_label := Label.new()
	chest_label.text = "CHEST"
	chest_label.position = Vector2(200, 36)
	chest_label.size = Vector2(204, 14)
	chest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chest_label.add_theme_font_size_override("font_size", 9)
	chest_label.add_theme_color_override("font_color", LABEL_COLOR)
	panel.add_child(chest_label)


# ============================================================
# BATTLE GRID (3×3)
# ============================================================

func _build_battle_grid() -> void:
	battle_grid = GridContainer.new()
	battle_grid.columns = 3
	battle_grid.position = Vector2(24, 52)
	battle_grid.size = Vector2(148, 148)
	battle_grid.add_theme_constant_override("h_separation", SLOT_GAP)
	battle_grid.add_theme_constant_override("v_separation", SLOT_GAP)

	var normal_style := _create_slot_normal()
	var pressed_style := _create_slot_pressed()

	for i in 9:
		var btn := _create_slot_button(i, normal_style, pressed_style)
		battle_slots.append(btn)
		battle_slot_icons.append(btn.get_child(0) as TextureRect)
		battle_grid.add_child(btn)

	panel.add_child(battle_grid)


# ============================================================
# CHEST GRID (4×4)
# ============================================================

func _build_chest_grid() -> void:
	chest_grid = GridContainer.new()
	chest_grid.columns = 4
	chest_grid.position = Vector2(200, 52)
	chest_grid.size = Vector2(204, 204)
	chest_grid.add_theme_constant_override("h_separation", SLOT_GAP)
	chest_grid.add_theme_constant_override("v_separation", SLOT_GAP)

	var normal_style := _create_slot_normal()
	var pressed_style := _create_slot_pressed()

	for i in 16:
		var btn := _create_slot_button(i, normal_style, pressed_style)
		chest_slots.append(btn)
		chest_slot_icons.append(btn.get_child(0) as TextureRect)
		chest_grid.add_child(btn)

	panel.add_child(chest_grid)


# ============================================================
# SHARED SLOT CREATION
# ============================================================

func _create_slot_normal() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SLOT_NORMAL_BG
	style.shadow_color = SLOT_SHADOW_COLOR
	style.shadow_size = 2
	return style


func _create_slot_pressed() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SLOT_NORMAL_BG
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = SLOT_ACTIVE_BORDER
	return style


func _create_slot_button(index: int, normal: StyleBoxFlat, pressed: StyleBoxFlat) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = SLOT_SIZE
	btn.size = SLOT_SIZE
	btn.text = ""
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", normal.duplicate())
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.size = Vector2(36, 36)
	icon.position = Vector2(6, 6)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)

	return btn


func _setup_slot_callbacks() -> void:
	for i in battle_slots.size():
		var idx := i
		battle_slots[i].pressed.connect(func(): _on_slot_clicked("battle", idx))

	for i in chest_slots.size():
		var idx := i
		chest_slots[i].pressed.connect(func(): _on_slot_clicked("chest", idx))


# ============================================================
# DIVIDER
# ============================================================

func _build_divider() -> void:
	var divider := Panel.new()
	divider.position = Vector2(184, 52)
	divider.size = Vector2(2, 204)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.12)
	divider.add_theme_stylebox_override("panel", style)
	panel.add_child(divider)


# ============================================================
# ITEM INFO (bawah)
# ============================================================

func _build_item_info() -> void:
	var info_y := 264.0
	var info_h := PANEL_SIZE.y - info_y - 8.0

	# Background panel
	var bg := Panel.new()
	bg.position = Vector2(8, info_y)
	bg.size = Vector2(PANEL_SIZE.x - 16, info_h)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.3)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	bg.add_theme_stylebox_override("panel", bg_style)
	panel.add_child(bg)

	# Icon
	info_icon = TextureRect.new()
	info_icon.custom_minimum_size = Vector2(48, 48)
	info_icon.position = Vector2(16, info_y + 10)
	info_icon.size = Vector2(48, 48)
	info_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	info_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(info_icon)

	# Name
	info_name = Label.new()
	info_name.position = Vector2(72, info_y + 6)
	info_name.size = Vector2(200, 16)
	info_name.add_theme_font_size_override("font_size", 11)
	info_name.add_theme_color_override("font_color", TITLE_COLOR)
	panel.add_child(info_name)

	# Desc
	info_desc = Label.new()
	info_desc.position = Vector2(72, info_y + 22)
	info_desc.size = Vector2(200, 32)
	info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_desc.add_theme_font_size_override("font_size", 9)
	info_desc.add_theme_color_override("font_color", DESC_COLOR)
	panel.add_child(info_desc)

	# Rarity badge
	info_rarity = Label.new()
	info_rarity.position = Vector2(72, info_y + 54)
	info_rarity.size = Vector2(60, 14)
	info_rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_rarity.add_theme_font_size_override("font_size", 8)
	info_rarity.add_theme_color_override("font_color", TEXT_COLOR)
	_apply_badge_style(info_rarity, Color(0.35, 0.35, 0.35))
	panel.add_child(info_rarity)

	# Type badge
	info_type = Label.new()
	info_type.position = Vector2(136, info_y + 54)
	info_type.size = Vector2(70, 14)
	info_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_type.add_theme_font_size_override("font_size", 8)
	info_type.add_theme_color_override("font_color", TEXT_COLOR)
	_apply_badge_style(info_type, Color(0.3, 0.3, 0.3))
	panel.add_child(info_type)

	# Effect badge
	info_effect = Label.new()
	info_effect.position = Vector2(210, info_y + 54)
	info_effect.size = Vector2(70, 14)
	info_effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_effect.add_theme_font_size_override("font_size", 8)
	info_effect.add_theme_color_override("font_color", TEXT_COLOR)
	_apply_badge_style(info_effect, Color(0.3, 0.3, 0.3))
	panel.add_child(info_effect)

	# Drop button
	drop_btn = Button.new()
	drop_btn.text = "Drop"
	drop_btn.position = Vector2(PANEL_SIZE.x - 80, info_y + 10)
	drop_btn.size = Vector2(56, 22)
	drop_btn.visible = false

	var drop_style := StyleBoxFlat.new()
	drop_style.bg_color = DROP_BG
	drop_style.corner_radius_top_left = 4
	drop_style.corner_radius_top_right = 4
	drop_style.corner_radius_bottom_left = 4
	drop_style.corner_radius_bottom_right = 4
	drop_btn.add_theme_stylebox_override("normal", drop_style)

	var drop_hover := drop_style.duplicate()
	drop_hover.bg_color = DROP_HOVER
	drop_btn.add_theme_stylebox_override("hover", drop_hover)

	drop_btn.add_theme_font_size_override("font_size", 10)
	drop_btn.add_theme_color_override("font_color", TEXT_COLOR)
	drop_btn.pressed.connect(_on_drop_pressed)
	panel.add_child(drop_btn)

	# Set info kosong
	_set_info_empty()


func _apply_badge_style(label: Label, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.78)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	label.add_theme_stylebox_override("normal", style)


# ============================================================
# POPULATE SLOTS
# ============================================================

func _populate_all_slots() -> void:
	_populate_battle_slots()
	_populate_chest_slots()
	_setup_slot_callbacks()


func _populate_battle_slots() -> void:
	var items := PlayerDataManager.data.battle_inventory.items
	for i in battle_slots.size():
		if i < items.size() and items[i] and items[i] is ItemData:
			var item: ItemData = items[i]
			battle_slot_icons[i].texture = item.icon
		else:
			battle_slot_icons[i].texture = null


func _populate_chest_slots() -> void:
	var items := PlayerDataManager.data.chest_inventory.items
	for i in chest_slots.size():
		if i < items.size() and items[i] and items[i] is ItemData:
			var item: ItemData = items[i]
			chest_slot_icons[i].texture = item.icon
		else:
			chest_slot_icons[i].texture = null


# ============================================================
# SLOT CLICK
# ============================================================

func _on_slot_clicked(inv_type: String, index: int) -> void:
	# Deselect previous
	_deselect_all()

	active_inv_type = inv_type
	active_slot_index = index

	# Highlight selected
	if inv_type == "battle":
		battle_slots[index].button_pressed = true
	else:
		chest_slots[index].button_pressed = true

	# Get item
	var item := _get_item_at(inv_type, index)
	if item and item is ItemData:
		_update_info_panel(item)
		drop_btn.visible = true
	else:
		_set_info_empty()
		drop_btn.visible = false


func _deselect_all() -> void:
	for slot in battle_slots:
		slot.button_pressed = false
	for slot in chest_slots:
		slot.button_pressed = false


func _get_item_at(inv_type: String, index: int) -> ItemData:
	if inv_type == "battle":
		var items := PlayerDataManager.data.battle_inventory.items
		if index < items.size() and items[index] and items[index] is ItemData:
			return items[index]
	else:
		var items := PlayerDataManager.data.chest_inventory.items
		if index < items.size() and items[index] and items[index] is ItemData:
			return items[index]
	return null


# ============================================================
# INFO PANEL
# ============================================================

func _update_info_panel(item: ItemData) -> void:
	if not item:
		_set_info_empty()
		return

	if item.icon:
		info_icon.texture = item.icon
	else:
		info_icon.texture = null

	info_name.text = item.item_name if item.item_name != "" else "---"
	info_desc.text = item.description if item.description != "" else ""

	# Rarity badge
	var rarity_color := Color(0.35, 0.35, 0.35)
	match item.rarity:
		"Common": rarity_color = Color(0.349, 0.349, 0.349)
		"Uncommon": rarity_color = Color(0.486, 0.38, 0.316)
		"Rare": rarity_color = Color(0.118, 0.38, 0.68)
		"Epic": rarity_color = Color(0.45, 0.179, 0.58)
		"Legendary": rarity_color = Color(0.75, 0.42, 0.078)
	info_rarity.text = item.rarity
	_apply_badge_style(info_rarity, rarity_color)

	# Type badge
	var type_color := Color(0.3, 0.3, 0.3)
	match item.item_type:
		ItemData.ItemType.CONSUMABLE: type_color = Color(0.15, 0.48, 0.22)
		ItemData.ItemType.EQUIPMENT: type_color = Color(0.12, 0.38, 0.68)
		ItemData.ItemType.LOOT: type_color = Color(0.72, 0.52, 0.1)
		ItemData.ItemType.DROP: type_color = Color(0.5, 0.2, 0.5)
	info_type.text = item.get_type_string()
	_apply_badge_style(info_type, type_color)

	# Effect badge
	if item.item_effect_type != ItemData.ItemEffectType.NONE:
		info_effect.text = item.get_effect_type_string()
		info_effect.visible = true
		var effect_color := Color(0.3, 0.3, 0.3)
		match item.item_effect_type:
			ItemData.ItemEffectType.HEAL, ItemData.ItemEffectType.MAX_HP, ItemData.ItemEffectType.HP_REGEN:
				effect_color = Color(0.18, 0.54, 0.34)
			ItemData.ItemEffectType.ATTACK, ItemData.ItemEffectType.DAMAGE, ItemData.ItemEffectType.ATTACK_SPEED, ItemData.ItemEffectType.CRITICAL_CHANCE, ItemData.ItemEffectType.CRITICAL_DAMAGE, ItemData.ItemEffectType.ELEMENTAL_DAMAGE:
				effect_color = Color(0.75, 0.22, 0.17)
			ItemData.ItemEffectType.DEFENSE, ItemData.ItemEffectType.SHIELD, ItemData.ItemEffectType.DAMAGE_REDUCTION:
				effect_color = Color(0.16, 0.44, 0.72)
			ItemData.ItemEffectType.REMOVE_DEBUFF, ItemData.ItemEffectType.REMOVE_POISON, ItemData.ItemEffectType.REMOVE_BURN, ItemData.ItemEffectType.REMOVE_BLEED, ItemData.ItemEffectType.REMOVE_STUN:
				effect_color = Color(0.55, 0.23, 0.65)
		_apply_badge_style(info_effect, effect_color)
	else:
		info_effect.visible = false


func _set_info_empty() -> void:
	info_icon.texture = null
	info_name.text = "---"
	info_desc.text = ""
	info_rarity.text = ""
	info_type.text = ""
	info_effect.text = ""
	info_effect.visible = false
	drop_btn.visible = false


# ============================================================
# DROP ITEM
# ============================================================

func _on_drop_pressed() -> void:
	if active_inv_type == "" or active_slot_index < 0:
		return

	var item := _get_item_at(active_inv_type, active_slot_index)
	if not item:
		return

	_show_drop_confirmation(item)


func _show_drop_confirmation(item: ItemData) -> void:
	var drop_overlay := Control.new()
	drop_overlay.name = "DropOverlay"
	drop_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	drop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var popup := PanelContainer.new()
	popup.name = "DropPopup"

	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	popup_style.border_width_left = 2
	popup_style.border_width_top = 2
	popup_style.border_width_right = 2
	popup_style.border_width_bottom = 2
	popup_style.border_color = Color(0.3, 0.3, 0.3, 1.0)
	popup_style.corner_radius_top_left = 6
	popup_style.corner_radius_top_right = 6
	popup_style.corner_radius_bottom_left = 6
	popup_style.corner_radius_bottom_right = 6
	popup_style.content_margin_left = 16.0
	popup_style.content_margin_right = 16.0
	popup_style.content_margin_top = 14.0
	popup_style.content_margin_bottom = 14.0
	popup.add_theme_stylebox_override("panel", popup_style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)

	# Icon
	var popup_icon := TextureRect.new()
	popup_icon.texture = item.icon
	popup_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	popup_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	popup_icon.custom_minimum_size = Vector2(48, 48)
	vbox.add_child(popup_icon)

	# Name
	var name_style := StyleBoxFlat.new()
	name_style.bg_color = Color(0.05, 0.05, 0.07, 0.65)
	name_style.corner_radius_top_left = 4
	name_style.corner_radius_top_right = 4
	name_style.corner_radius_bottom_left = 4
	name_style.corner_radius_bottom_right = 4
	name_style.content_margin_left = 10.0
	name_style.content_margin_right = 10.0
	name_style.content_margin_top = 4.0
	name_style.content_margin_bottom = 4.0

	var popup_name := Label.new()
	popup_name.text = item.item_name
	popup_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_name.add_theme_stylebox_override("normal", name_style)
	vbox.add_child(popup_name)

	# Confirm text
	var confirm_label := Label.new()
	confirm_label.text = "Drop this item?"
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	confirm_label.add_theme_stylebox_override("normal", name_style.duplicate())
	vbox.add_child(confirm_label)

	# Buttons
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)

	var yes_btn := Button.new()
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(64, 28)
	yes_btn.focus_mode = Control.FOCUS_NONE

	var no_btn := Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(64, 28)
	no_btn.focus_mode = Control.FOCUS_NONE

	hbox.add_child(yes_btn)
	hbox.add_child(no_btn)
	vbox.add_child(hbox)

	popup.add_child(vbox)
	drop_overlay.add_child(popup)
	add_child(drop_overlay)

	# Position popup center
	var viewport_size := get_viewport_rect().size
	popup.reset_size()
	popup.pivot_offset = popup.size / 2.0
	popup.position = (viewport_size / 2.0) - (popup.size / 2.0)

	# Animate in
	popup.scale = Vector2(0.2, 0.2)
	popup.modulate.a = 0.0

	var tween := popup.create_tween().set_parallel(true)
	tween.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 1.0, 0.15)

	# Connect buttons
	var inv_type_copy := active_inv_type
	var slot_index_copy := active_slot_index

	yes_btn.pressed.connect(func():
		_confirm_drop(inv_type_copy, slot_index_copy)
		_close_drop_popup(drop_overlay, popup)
	)
	no_btn.pressed.connect(func():
		_close_drop_popup(drop_overlay, popup)
	)


func _confirm_drop(inv_type: String, index: int) -> void:
	if inv_type == "battle":
		PlayerDataManager.remove_item(index)
		_populate_battle_slots()
	else:
		PlayerDataManager.remove_chest_item(index)
		_populate_chest_slots()

	# Reset selection
	_deselect_all()
	active_inv_type = ""
	active_slot_index = -1
	_set_info_empty()


func _close_drop_popup(overlay_node: Node, popup_node: Node) -> void:
	if not is_instance_valid(overlay_node) or not is_instance_valid(popup_node):
		return

	var tween := popup_node.create_tween().set_parallel(true)
	tween.tween_property(popup_node, "scale", Vector2(0.8, 0.8), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(popup_node, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(overlay_node.queue_free)


# ============================================================
# ANIMATIONS
# ============================================================

func _play_intro() -> void:
	var tween_overlay := create_tween()
	tween_overlay.tween_property(overlay, "modulate:a", 1.0, 0.25)

	var target_y := panel.position.y
	panel.position.y = target_y + 300
	panel.modulate.a = 0.0

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CIRC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position:y", target_y, 0.35)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)


func _play_outro() -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CIRC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "position:y", panel.position.y + 300, 0.3)
	tween.tween_property(panel, "modulate:a", 0.0, 0.25)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.25)
	tween.tween_callback(_emit_closed)


func _emit_closed() -> void:
	closed.emit()
	queue_free()


func _on_close_pressed() -> void:
	_play_outro()
