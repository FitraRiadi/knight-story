extends Control

# Signal untuk komunikasi dengan BattleManager
signal closed
signal item_used(item: ItemData)

# ============================================================
# NODE REFERENCES
# ============================================================

@onready var inventory_slot: TextureRect = $inventorySlot
@onready var label_inventory: TextureRect = $LabelInventory
@onready var item_info: Panel = $itemInfo
@onready var close_btn: Button = $LabelInventory/closeBtn

@onready var slot_1: TextureRect = $inventorySlot/slot1
@onready var slot_2: TextureRect = $inventorySlot/slot2
@onready var slot_3: TextureRect = $inventorySlot/slot3
@onready var slot_4: TextureRect = $inventorySlot/slot4
@onready var slot_5: TextureRect = $inventorySlot/slot5
@onready var slot_6: TextureRect = $inventorySlot/slot6
@onready var slot_7: TextureRect = $inventorySlot/slot7
@onready var slot_8: TextureRect = $inventorySlot/slot8
@onready var slot_9: TextureRect = $inventorySlot/slot9

# ============================================================
# ITEM INFO & BADGES
# ============================================================

@onready var item_name_label: Label = $itemInfo/container/infoItem/Label
@onready var item_desc_label: Label = $itemInfo/container/infoItem/Label2
@onready var item_icon: TextureRect = $itemInfo/container/itemIcon/img

@onready var item_rarity_label: Label = $itemInfo/container/itemBadge/rarity
@onready var item_type_label: Label = $itemInfo/container/itemBadge/type
@onready var item_effect_label: Label = $itemInfo/container/itemBadge/ItemEffectType

@onready var use_item_btn: Button = $itemInfo/useItemBtn
@onready var drop_item_btn: Button = $itemInfo/dropItemBtn

# ============================================================
# INVENTORY DATA
# ============================================================

@export var inventory_data: InventoryBattleData

# ============================================================
# POSITION DATA
# ============================================================

var _original_slot_offset_top: float
var _original_label_offset_top: float
var _original_item_info_offset_top: float

# ============================================================
# SLOT DATA
# ============================================================

var _slots: Array[TextureRect] = []
var _current_selected_index: int = -1

# ============================================================
# ACTIVE SLOT PANEL
# ============================================================

var slot_active: Panel

# ============================================================
# READY
# ============================================================

func _ready() -> void:
	_slots = [
		slot_1, slot_2, slot_3,
		slot_4, slot_5, slot_6,
		slot_7, slot_8, slot_9
	]

	if not inventory_data:
		inventory_data = PlayerDataManager.data.battle_inventory

	_create_active_slot()
	_setup_slot_signals()
	_populate_slots_from_data()
	_setup_initial_positions()
	_play_intro_animation()

	use_item_btn.pressed.connect(_on_use_item_pressed)
	drop_item_btn.pressed.connect(_on_drop_item_pressed)
	close_btn.pressed.connect(_on_close_pressed)

	item_info.visible = false

# ============================================================
# CREATE ACTIVE SLOT
# ============================================================

func _create_active_slot() -> void:
	slot_active = Panel.new()
	slot_active.name = "SlotActive"
	slot_active.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_active.size = slot_1.size

	inventory_slot.add_child(slot_active)
	inventory_slot.move_child(slot_active, 0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(1.0, 1.0, 1.0, 0.0)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(1.0, 0.85, 0.25, 1.0)
	panel_style.corner_radius_top_left = 3
	panel_style.corner_radius_top_right = 3
	panel_style.corner_radius_bottom_left = 3
	panel_style.corner_radius_bottom_right = 3

	slot_active.add_theme_stylebox_override("panel", panel_style)
	slot_active.visible = false
	_move_active_slot(0, false)

# ============================================================
# SETUP SLOT SIGNALS
# ============================================================

func _setup_slot_signals() -> void:
	for i in range(_slots.size()):
		var slot := _slots[i]
		slot.mouse_filter = Control.MOUSE_FILTER_STOP

		var btn := Button.new()
		btn.name = "SlotBtn_%d" % i
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.custom_minimum_size = slot.size
		btn.anchors_preset = Control.PRESET_FULL_RECT
		btn.offset_left = 0
		btn.offset_top = 0
		btn.offset_right = 0
		btn.offset_bottom = 0
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.modulate.a = 0.0

		slot.add_child(btn)
		btn.gui_input.connect(_on_slot_gui_input.bind(i))

# ============================================================
# POPULATE SLOTS
# ============================================================

func _populate_slots_from_data() -> void:
	if not inventory_data:
		return

	var items := inventory_data.items
	for i in range(9):
		var slot := _slots[i]
		if i < items.size() and items[i]:
			var item: ItemData = items[i]
			slot.texture = item.icon
		else:
			slot.texture = null

# ============================================================
# SLOT INPUT
# ============================================================

func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_slot(index)

# ============================================================
# SELECT SLOT
# ============================================================

func _select_slot(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return

	if slot_active and not slot_active.visible:
		slot_active.visible = true

	_current_selected_index = index
	_move_active_slot(index, true)

	if not inventory_data or index >= inventory_data.items.size():
		_hide_item_info()
		return

	var item: ItemData = inventory_data.items[index]
	if not item:
		_hide_item_info()
		return

	_show_item_info(item)

# ============================================================
# MOVE ACTIVE SLOT
# ============================================================

func _move_active_slot(index: int, animate: bool = true) -> void:
	if not slot_active or index < 0 or index >= _slots.size():
		return

	var target_slot := _slots[index]
	var target_position := target_slot.position

	slot_active.size = target_slot.size

	if animate:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		tween.tween_property(slot_active, "position", target_position, 0.12)
	else:
		slot_active.position = target_position

# ============================================================
# HELPER: BADGE STYLE
# ============================================================

func _set_label_badge_style(label_node: Label, base_color: Color) -> void:
	var existing_style := label_node.get_theme_stylebox("normal")
	var style: StyleBoxFlat

	if existing_style is StyleBoxFlat:
		style = existing_style.duplicate() as StyleBoxFlat
	else:
		style = StyleBoxFlat.new()
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.content_margin_left = 8.0
		style.content_margin_right = 8.0
		style.content_margin_top = 3.0
		style.content_margin_bottom = 3.0

	style.bg_color = Color(base_color.r, base_color.g, base_color.b, 0.78)
	label_node.add_theme_stylebox_override("normal", style)

# ============================================================
# HELPER: EFFECT POPUP TEXT
# ============================================================

func _get_effect_popup_text(item: ItemData) -> String:
	if not item or item.item_effect_type == ItemData.ItemEffectType.NONE:
		return ""

	match item.item_effect_type:
		ItemData.ItemEffectType.HEAL, ItemData.ItemEffectType.HP_REGEN:
			return "HP Restored"
		ItemData.ItemEffectType.MAX_HP:
			return "Max HP Increased"
		ItemData.ItemEffectType.ATTACK, ItemData.ItemEffectType.DAMAGE:
			return "Damage Increased"
		ItemData.ItemEffectType.ATTACK_SPEED:
			return "Attack Speed Increased"
		ItemData.ItemEffectType.CRITICAL_CHANCE:
			return "Crit Chance Increased"
		ItemData.ItemEffectType.CRITICAL_DAMAGE:
			return "Crit Damage Increased"
		ItemData.ItemEffectType.ELEMENTAL_DAMAGE:
			return "Elemental Damage Boosted"
		ItemData.ItemEffectType.DEFENSE, ItemData.ItemEffectType.DAMAGE_REDUCTION:
			return "Defense Increased"
		ItemData.ItemEffectType.SHIELD:
			return "Shield Added"
		ItemData.ItemEffectType.REMOVE_DEBUFF, ItemData.ItemEffectType.REMOVE_POISON, \
		ItemData.ItemEffectType.REMOVE_BURN, ItemData.ItemEffectType.REMOVE_BLEED, \
		ItemData.ItemEffectType.REMOVE_STUN:
			return "Debuff Cleared"
		_:
			return item.get_effect_type_string()

# ============================================================
# SHOW ITEM INFO
# ============================================================

func _show_item_info(item: ItemData) -> void:
	if not item:
		return

	item_name_label.text = item.item_name
	item_desc_label.text = item.description
	item_icon.texture = item.icon

	item_rarity_label.modulate = Color.WHITE
	item_type_label.modulate = Color.WHITE

	item_rarity_label.text = item.rarity
	var rarity_color: Color = Color(0.35, 0.35, 0.35)
	match item.rarity:
		"Common": rarity_color = Color(0.349, 0.349, 0.349)
		"Uncommon": rarity_color = Color(0.486, 0.38, 0.316)
		"Rare": rarity_color = Color(0.118, 0.38, 0.68)
		"Epic": rarity_color = Color(0.45, 0.179, 0.58)
		"Legendary": rarity_color = Color(0.75, 0.42, 0.078)

	_set_label_badge_style(item_rarity_label, rarity_color)

	item_type_label.text = item.get_type_string()
	var type_color: Color = Color(0.3, 0.3, 0.3)
	match item.item_type:
		ItemData.ItemType.CONSUMABLE: type_color = Color(0.15, 0.48, 0.22)
		ItemData.ItemType.EQUIPMENT: type_color = Color(0.12, 0.38, 0.68)
		ItemData.ItemType.LOOT: type_color = Color(0.72, 0.52, 0.1)
		ItemData.ItemType.DROP: type_color = Color(0.5, 0.2, 0.5)

	_set_label_badge_style(item_type_label, type_color)

	if item_effect_label:
		if item.item_effect_type != ItemData.ItemEffectType.NONE:
			item_effect_label.text = item.get_effect_type_string()
			item_effect_label.modulate = Color.WHITE
			var effect_badge_color: Color = Color(0.3, 0.3, 0.3)

			match item.item_effect_type:
				ItemData.ItemEffectType.HEAL, ItemData.ItemEffectType.MAX_HP, ItemData.ItemEffectType.HP_REGEN:
					effect_badge_color = Color(0.18, 0.54, 0.34)
				ItemData.ItemEffectType.ATTACK, ItemData.ItemEffectType.DAMAGE, ItemData.ItemEffectType.ATTACK_SPEED, ItemData.ItemEffectType.CRITICAL_CHANCE, ItemData.ItemEffectType.CRITICAL_DAMAGE, ItemData.ItemEffectType.ELEMENTAL_DAMAGE:
					effect_badge_color = Color(0.75, 0.22, 0.17)
				ItemData.ItemEffectType.DEFENSE, ItemData.ItemEffectType.SHIELD, ItemData.ItemEffectType.DAMAGE_REDUCTION:
					effect_badge_color = Color(0.16, 0.44, 0.72)
				ItemData.ItemEffectType.REMOVE_DEBUFF, ItemData.ItemEffectType.REMOVE_POISON, ItemData.ItemEffectType.REMOVE_BURN, ItemData.ItemEffectType.REMOVE_BLEED, ItemData.ItemEffectType.REMOVE_STUN:
					effect_badge_color = Color(0.55, 0.23, 0.65)

			_set_label_badge_style(item_effect_label, effect_badge_color)
			item_effect_label.visible = true
		else:
			item_effect_label.visible = false

	use_item_btn.visible = item.is_consumable()
	item_info.visible = true
	item_info.scale = Vector2(0.8, 0.8)
	item_info.modulate.a = 0.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(item_info, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_property(item_info, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# ============================================================
# HIDE ITEM INFO
# ============================================================

func _hide_item_info() -> void:
	item_info.visible = false

# ============================================================
# USE ITEM
# ============================================================

func _on_use_item_pressed() -> void:
	if _current_selected_index < 0 or not inventory_data:
		return
	if _current_selected_index >= inventory_data.items.size():
		return

	var item := inventory_data.items[_current_selected_index]
	if not item or not item.is_consumable():
		return

	PlayerDataManager.remove_item(_current_selected_index)
	_populate_slots_from_data()

	_show_item_use_popup(item)
	
	_close_inventory_ui(false)
	item_used.emit(item)

# ============================================================
# DROP ITEM (POPUP ANARK DARI CONTROL FULL RECT)
# ============================================================

func _on_drop_item_pressed() -> void:
	if _current_selected_index < 0 or not inventory_data:
		return
	if _current_selected_index >= inventory_data.items.size():
		return

	var item := inventory_data.items[_current_selected_index]
	if not item:
		return

	_show_drop_confirmation_popup(item)

func _show_drop_confirmation_popup(item: ItemData) -> void:
	# 1. Overlay Node (Control Full Rect) untuk memblokir klik di luar
	var overlay := Control.new()
	overlay.name = "DropPopupOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# 2. Panel Confirm Drop (Dibuat sebagai ANAK dari Node Control Full Rect)
	var popup_panel := PanelContainer.new()
	popup_panel.name = "ConfirmDropPanel"
	popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Menyamakan StyleBox panel dengan container di itemInfo
	var container_node := get_node_or_null("itemInfo/container")
	if container_node and container_node.has_theme_stylebox_override("panel"):
		popup_panel.add_theme_stylebox_override("panel", container_node.get_theme_stylebox("panel").duplicate())
	else:
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

	# 1. Logo Item
	var popup_icon := TextureRect.new()
	popup_icon.texture = item.icon
	popup_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	popup_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	popup_icon.custom_minimum_size = Vector2(64, 64)

	# Style Background khusus untuk Nama Item & Teks Validasi
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

	# 2. Nama Item (dengan background)
	var popup_name_label := Label.new()
	popup_name_label.text = item.item_name
	popup_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup_name_label.add_theme_stylebox_override("normal", label_bg_style)

	# 3. Teks Validasi "Drop this item?" (dengan background)
	var popup_confirm_label := Label.new()
	popup_confirm_label.text = "Drop this item?"
	popup_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_confirm_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup_confirm_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	popup_confirm_label.add_theme_stylebox_override("normal", label_bg_style)

	# 4. Tombol YES & NO
	var hbox_btns := HBoxContainer.new()
	hbox_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_btns.add_theme_constant_override("separation", 16)

	var yes_btn := Button.new()
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(64, 28)
	yes_btn.focus_mode = Control.FOCUS_NONE

	var no_btn := Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(64, 28)
	no_btn.focus_mode = Control.FOCUS_NONE

	hbox_btns.add_child(yes_btn)
	hbox_btns.add_child(no_btn)

	# Menyusun hierarki elemen
	vbox.add_child(popup_icon)
	vbox.add_child(popup_name_label)
	vbox.add_child(popup_confirm_label)
	vbox.add_child(hbox_btns)

	# MASUKKAN PANEL KE DALAM OVERLAY (ANAK DARI CONTROL FULL RECT)
	popup_panel.add_child(vbox)
	overlay.add_child(popup_panel)

	# MASUKKAN OVERLAY KE CANVAS/PARENT UTAMA
	var parent_target = get_parent()
	if not parent_target:
		parent_target = get_tree().root

	parent_target.add_child(overlay)

	# Mengatur Posisi Popup tepat di Vector2(375.0, 131.0)
	popup_panel.reset_size()
	var target_pos := Vector2(375.0, 131.0)
	popup_panel.pivot_offset = popup_panel.size / 2.0
	popup_panel.position = target_pos - (popup_panel.size / 2.0)

	popup_panel.scale = Vector2(0.2, 0.2)
	popup_panel.modulate.a = 0.0

	# Animasi Muncul
	var tween := popup_panel.create_tween().set_parallel(true)
	tween.tween_property(popup_panel, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup_panel, "modulate:a", 1.0, 0.15)

	# Signal Tombol
	yes_btn.pressed.connect(_confirm_drop_item.bind(_current_selected_index, overlay, popup_panel))
	no_btn.pressed.connect(_close_drop_popup.bind(overlay, popup_panel))

func _confirm_drop_item(index: int, overlay_node: Node, popup_panel: Node) -> void:
	if index >= 0 and inventory_data and index < inventory_data.items.size():
		PlayerDataManager.remove_item(index)
		_populate_slots_from_data()
		_move_active_slot(index, false)
		_hide_item_info()
	
	_close_drop_popup(overlay_node, popup_panel)

func _close_drop_popup(overlay_node: Node, popup_panel: Node) -> void:
	if not is_instance_valid(overlay_node) or not is_instance_valid(popup_panel):
		return

	var tween := popup_panel.create_tween().set_parallel(true)
	tween.tween_property(popup_panel, "scale", Vector2(0.8, 0.8), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(popup_panel, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(overlay_node.queue_free)

# ============================================================
# CLOSE ACTION
# ============================================================

func _on_close_pressed() -> void:
	_close_inventory_ui(false)
	closed.emit()

func _close_inventory_ui(should_free: bool = false) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var target_y := viewport_size.y + 100.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(inventory_slot, "offset_top", target_y, 0.25).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	tween.tween_property(label_inventory, "offset_top", target_y, 0.25).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	tween.tween_property(item_info, "offset_top", target_y, 0.25).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)

	if should_free:
		tween.chain().tween_callback(queue_free)

# ============================================================
# POPUP ITEM ANIMATION AT FIXED POSITION 
# ============================================================

func _show_item_use_popup(item: ItemData) -> void:
	var popup_container := VBoxContainer.new()
	popup_container.alignment = BoxContainer.ALIGNMENT_CENTER
	popup_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var popup_icon := TextureRect.new()
	popup_icon.texture = item.icon
	popup_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	popup_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	popup_icon.custom_minimum_size = Vector2(64, 64)
	popup_icon.pivot_offset = Vector2(32, 32)

	var popup_label := Label.new()
	popup_label.text = item.item_name
	popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	popup_container.add_child(popup_icon)
	popup_container.add_child(popup_label)

	# LABEL KUNING EFEK ITEM
	var effect_text := _get_effect_popup_text(item)
	if effect_text != "":
		var effect_label := Label.new()
		effect_label.text = effect_text
		effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		effect_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
		effect_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		effect_label.add_theme_constant_override("outline_size", 4)
		popup_container.add_child(effect_label)

	var parent_target = get_parent()
	if not parent_target:
		parent_target = get_tree().root

	parent_target.add_child(popup_container)

	popup_container.reset_size()
	var target_pos := Vector2(375.0, 131.0)
	popup_container.pivot_offset = popup_container.size / 2.0
	popup_container.position = target_pos - (popup_container.size / 2.0)

	popup_container.scale = Vector2(0.2, 0.2)
	popup_container.modulate.a = 0.0

	var tween := popup_container.create_tween()

	# 1. Scale Up
	tween.set_parallel(true)
	tween.tween_property(popup_container, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup_container, "modulate:a", 1.0, 0.2)

	# 2. Wiggle
	tween.chain().tween_property(popup_icon, "rotation_degrees", 15.0, 0.1).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_property(popup_icon, "rotation_degrees", -15.0, 0.12).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_property(popup_icon, "rotation_degrees", 10.0, 0.1).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_property(popup_icon, "rotation_degrees", -10.0, 0.1).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_property(popup_icon, "rotation_degrees", 0.0, 0.08).set_trans(Tween.TRANS_SINE)

	tween.chain().tween_interval(0.2)

	# 3. Fade Out & Free
	var final_y := popup_container.position.y - 25.0
	tween.chain().set_parallel(true)
	tween.tween_property(popup_container, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(popup_container, "position:y", final_y, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.chain().tween_callback(popup_container.queue_free)

# ============================================================
# INITIAL POSITIONS & INTRO
# ============================================================

func _setup_initial_positions() -> void:
	var viewport_size := get_viewport().get_visible_rect().size

	_original_slot_offset_top = inventory_slot.offset_top
	_original_label_offset_top = label_inventory.offset_top
	_original_item_info_offset_top = item_info.offset_top

	inventory_slot.offset_top = viewport_size.y + 100.0
	label_inventory.offset_top = viewport_size.y + 100.0
	item_info.offset_top = viewport_size.y + 100.0

func _play_intro_animation() -> void:
	var tween := create_tween()
	tween.tween_property(inventory_slot, "offset_top", _original_slot_offset_top, 0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label_inventory, "offset_top", _original_label_offset_top, 0.1).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label_inventory, "offset_top", _original_label_offset_top, 0.1).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(item_info, "offset_top", _original_item_info_offset_top, 0.2).set_trans(Tween.TRANS_CIRC)
