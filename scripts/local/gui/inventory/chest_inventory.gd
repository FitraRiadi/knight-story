extends Control
class_name ChestInventory


# ============================================================
# CHEST INVENTORY
# Full programmatic UI — 16 slot (4×4), item info di kanan.
# Style mengikuti blacksmith slot.
# ============================================================

signal closed

# --- Node refs ---
var overlay: ColorRect
var panel: Panel
var grid: GridContainer
var slots: Array[Button] = []
var slot_icons: Array[TextureRect] = []

var item_info_panel: Panel
var info_icon: TextureRect
var info_name: Label
var info_desc: Label
var info_rarity: Label
var info_type: Label

# --- State ---
var active_slot_index: int = -1
var chest_items: Array = []
var item_count: int = 16


# ============================================================
# CONSTANTS — style blacksmith
# ============================================================

const PANEL_SIZE := Vector2(400, 320)
const PANEL_BG := Color(0.0, 0.0, 0.0, 0.66)

const TITLE_BAR_COLOR := Color(0.317, 0.097, 0.125, 0.6)
const TITLE_COLOR := Color(1, 1, 0.25)
const TEXT_COLOR := Color(1, 0.95, 0.8)
const DESC_COLOR := Color(0.7, 0.65, 0.55)

const SLOT_SIZE := Vector2(48, 48)
const SLOT_GAP := 40.0
const COLUMNS := 4

const SLOT_NORMAL_BG := Color(0.056, 0.056, 0.056, 0.69)
const SLOT_SHADOW_COLOR := Color(0.924, 0.896, 0.985, 0.6)
const SLOT_ACTIVE_BORDER := Color(0.189, 0.813, 0.930, 0.62)

const CLOSE_BG := Color(0.317, 0.097, 0.125, 0.6)
const CLOSE_HOVER := Color(0.4, 0.15, 0.18, 0.8)


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	# Pastikan chest_inventory ada
	if not PlayerDataManager.data.get("chest_inventory"):
		PlayerDataManager.data.chest_inventory = InventoryBattleData.new()

	# DEBUG: isi test items
	if PlayerDataManager.data.chest_inventory.items.is_empty():
		var test_items: Array[ItemData] = [
			load("res://data/items/health_potion.tres"),
			load("res://data/items/attack_potion.tres"),
			load("res://data/items/protection_potion.tres"),
			load("res://data/items/health_potion.tres"),
		]
		PlayerDataManager.data.chest_inventory.items = test_items

	chest_items.resize(item_count)
	for i in item_count:
		if i < PlayerDataManager.data.chest_inventory.items.size():
			chest_items[i] = PlayerDataManager.data.chest_inventory.items[i]
		else:
			chest_items[i] = null

	_build_ui()
	_populate_slots()
	_play_intro()


# ============================================================
# BUILD UI
# ============================================================

func _build_ui() -> void:
	# --- Overlay ---
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.4)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.modulate.a = 0.0
	add_child(overlay)

	# --- Panel utama ---
	panel = Panel.new()
	var pw: float = PANEL_SIZE.x
	var ph: float = PANEL_SIZE.y
	var viewport_size := get_viewport_rect().size
	panel.position = Vector2(
		(viewport_size.x - pw) / 2.0,
		(viewport_size.y - ph) / 2.0
	)
	panel.size = Vector2(pw, ph)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	# --- Title bar ---
	_build_title_bar(pw)

	# --- Close button ---
	_build_close_button(pw)

	# --- Grid slots (kiri) ---
	_build_grid()

	# --- Item info panel (kanan) ---
	_build_item_info(pw, ph)


func _build_title_bar(pw: float) -> void:
	var title_bar := Panel.new()
	title_bar.position = Vector2(0, 0)
	title_bar.size = Vector2(pw, 30)

	var title_style := StyleBoxFlat.new()
	title_style.bg_color = TITLE_BAR_COLOR
	title_bar.add_theme_stylebox_override("panel", title_style)
	panel.add_child(title_bar)

	var title := Label.new()
	title.text = "Chest Inventory"
	title.position = Vector2(0, 4)
	title.size = Vector2(pw, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title_bar.add_child(title)


func _build_close_button(pw: float) -> void:
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(pw - 32, 5)
	close_btn.size = Vector2(26, 20)

	var close_style := StyleBoxFlat.new()
	close_style.bg_color = CLOSE_BG
	close_style.corner_radius_top_left = 4
	close_style.corner_radius_top_right = 4
	close_style.corner_radius_bottom_left = 4
	close_style.corner_radius_bottom_right = 4
	close_btn.add_theme_stylebox_override("normal", close_style)

	var close_hover := close_style.duplicate()
	close_hover.bg_color = CLOSE_HOVER
	close_btn.add_theme_stylebox_override("hover", close_hover)

	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_color_override("font_color", TEXT_COLOR)
	close_btn.pressed.connect(_on_close_pressed)
	panel.add_child(close_btn)


func _build_grid() -> void:
	grid = GridContainer.new()
	grid.columns = COLUMNS
	grid.position = Vector2(16, 40)
	grid.size = Vector2(208, 208)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = SLOT_NORMAL_BG
	normal_style.shadow_color = SLOT_SHADOW_COLOR
	normal_style.shadow_size = 2

	for i in item_count:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.custom_minimum_size = SLOT_SIZE
		btn.size = SLOT_SIZE
		btn.text = ""
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover", normal_style)

		var pressed_style := StyleBoxFlat.new()
		pressed_style.bg_color = SLOT_NORMAL_BG
		pressed_style.border_width_left = 2
		pressed_style.border_width_top = 2
		pressed_style.border_width_right = 2
		pressed_style.border_width_bottom = 2
		pressed_style.border_color = SLOT_ACTIVE_BORDER
		btn.add_theme_stylebox_override("pressed", pressed_style)
		btn.add_theme_stylebox_override("hover_pressed", pressed_style)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(36, 36)
		icon.size = Vector2(36, 36)
		icon.position = Vector2(6, 6)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)

		var idx := i
		btn.pressed.connect(func(): _on_slot_clicked(idx))

		slots.append(btn)
		slot_icons.append(icon)
		grid.add_child(btn)

	panel.add_child(grid)


func _build_item_info(pw: float, ph: float) -> void:
	item_info_panel = Panel.new()
	item_info_panel.position = Vector2(228, 40)
	item_info_panel.size = Vector2(pw - 244, ph - 56)

	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0, 0, 0, 0.3)
	info_style.corner_radius_top_left = 4
	info_style.corner_radius_top_right = 4
	info_style.corner_radius_bottom_left = 4
	info_style.corner_radius_bottom_right = 4
	item_info_panel.add_theme_stylebox_override("panel", info_style)
	panel.add_child(item_info_panel)

	# --- Item icon ---
	info_icon = TextureRect.new()
	info_icon.custom_minimum_size = Vector2(64, 64)
	info_icon.position = Vector2(46, 16)
	info_icon.size = Vector2(64, 64)
	info_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	info_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	item_info_panel.add_child(info_icon)

	# --- Item name ---
	info_name = Label.new()
	info_name.position = Vector2(12, 90)
	info_name.size = Vector2(140, 20)
	info_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_name.add_theme_font_size_override("font_size", 12)
	info_name.add_theme_color_override("font_color", TITLE_COLOR)
	item_info_panel.add_child(info_name)

	# --- Item desc ---
	info_desc = Label.new()
	info_desc.position = Vector2(12, 114)
	info_desc.size = Vector2(140, 60)
	info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_desc.add_theme_font_size_override("font_size", 10)
	info_desc.add_theme_color_override("font_color", DESC_COLOR)
	item_info_panel.add_child(info_desc)

	# --- Rarity badge ---
	info_rarity = Label.new()
	info_rarity.position = Vector2(12, 180)
	info_rarity.size = Vector2(140, 18)
	info_rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_rarity.add_theme_font_size_override("font_size", 10)
	info_rarity.add_theme_color_override("font_color", TEXT_COLOR)
	item_info_panel.add_child(info_rarity)

	# --- Type badge ---
	info_type = Label.new()
	info_type.position = Vector2(12, 200)
	info_type.size = Vector2(140, 18)
	info_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_type.add_theme_font_size_override("font_size", 10)
	info_type.add_theme_color_override("font_color", TEXT_COLOR)
	item_info_panel.add_child(info_type)

	# --- Default: kosong ---
	_set_info_empty()


# ============================================================
# POPULATE SLOTS
# ============================================================

func _populate_slots() -> void:
	for i in item_count:
		var item = chest_items[i]
		if item and item is ItemData:
			if item.icon:
				slot_icons[i].texture = item.icon
		else:
			slot_icons[i].texture = null


# ============================================================
# SLOT CLICK
# ============================================================

func _on_slot_clicked(index: int) -> void:
	if index < 0 or index >= item_count:
		return

	# Toggle: kalau klik slot yang sama lagi, deselect
	if active_slot_index == index:
		slots[index].button_pressed = true
		active_slot_index = -1
		_highlight_slot(-1)
		_set_info_empty()
		return

	# Deactivate previous
	if active_slot_index >= 0 and active_slot_index < slots.size():
		slots[active_slot_index].button_pressed = false

	active_slot_index = index
	slots[index].button_pressed = true
	_highlight_slot(index)
	_update_info_panel(chest_items[index])


func _highlight_slot(index: int) -> void:
	for i in slots.size():
		if i == index:
			slots[i].button_pressed = true
		else:
			slots[i].button_pressed = false


# ============================================================
# ITEM INFO PANEL
# ============================================================

func _update_info_item(item: ItemData) -> void:
	if not item:
		_set_info_empty()
		return

	if item.icon:
		info_icon.texture = item.icon
	else:
		info_icon.texture = null

	info_name.text = item.item_name if item.item_name != "" else "---"
	info_desc.text = item.description if item.description != "" else ""

	# Rarity badge color
	var rarity_color := TEXT_COLOR
	match item.rarity:
		"Common": rarity_color = Color(0.7, 0.7, 0.7)
		"Uncommon": rarity_color = Color(0.2, 0.8, 0.2)
		"Rare": rarity_color = Color(0.3, 0.5, 1.0)
		"Epic": rarity_color = Color(0.6, 0.2, 0.9)
		"Legendary": rarity_color = Color(1.0, 0.6, 0.1)

	info_rarity.text = "[%s]" % item.rarity
	info_rarity.add_theme_color_override("font_color", rarity_color)
	info_type.text = "[%s]" % item.get_type_string()


func _update_info_empty() -> void:
	info_icon.texture = null
	info_name.text = "---"
	info_desc.text = ""
	info_rarity.text = ""
	info_type.text = ""


func _set_info_empty() -> void:
	_update_info_empty()


func _update_info_panel(item) -> void:
	if item and item is ItemData:
		_update_info_item(item)
	else:
		_set_info_empty()


# ============================================================
# ANIMATIONS — sama kayak ShopPanel
# ============================================================

func _play_intro() -> void:
	# Overlay fade in
	var tween_overlay := create_tween()
	tween_overlay.tween_property(overlay, "modulate:a", 1.0, 0.25)

	# Panel slide up from below
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
