extends TextureRect

@onready var camera: Camera2D = $playerCamera
@onready var location_label: Label = $LocationUI/locationSellectName

# Location Info Panel
@onready var location_info_panel: Panel = $LocationUI/locationInfoPanel
@onready var info_name_label: Label = $LocationUI/locationInfoPanel/nameLocation
@onready var info_lore_label: Label = $LocationUI/locationInfoPanel/loreInfo
@onready var info_panel_1: Panel = $LocationUI/locationInfoPanel/Panel
@onready var info_panel_2: Panel = $LocationUI/locationInfoPanel/Panel2
@onready var info_panel_3: Panel = $LocationUI/locationInfoPanel/Panel3
@onready var btn_more_info: Button = $LocationUI/locationInfoPanel/moreInfo

# Popup All Events
@onready var popup_all_events: Control = $LocationUI/popupInfoAllEvent
@onready var popup_bg: TextureRect = $LocationUI/popupInfoAllEvent/infoAllEvent
@onready var popup_title: Label = $LocationUI/popupInfoAllEvent/infoAllEvent/nameLocation
@onready var btn_close_popup: Button = $LocationUI/popupInfoAllEvent/infoAllEvent/ButtonClose

# Event panels (locationInfoPanel - 3 panels)
@onready var event_icon_1: Panel = $LocationUI/locationInfoPanel/Panel
@onready var event_icon_2: Panel = $LocationUI/locationInfoPanel/Panel2
@onready var event_icon_3: Panel = $LocationUI/locationInfoPanel/Panel3

# Event panels (popupInfoAllEvent - 6 panels)
@onready var event_slot_1: Panel = $LocationUI/popupInfoAllEvent/infoAllEvent/event
@onready var event_slot_2: Panel = $LocationUI/popupInfoAllEvent/infoAllEvent/event2
@onready var event_slot_3: Panel = $LocationUI/popupInfoAllEvent/infoAllEvent/event3
@onready var event_slot_4: Panel = $LocationUI/popupInfoAllEvent/infoAllEvent/event4
@onready var event_slot_5: Panel = $LocationUI/popupInfoAllEvent/infoAllEvent/event5
@onready var event_slot_6: Panel = $LocationUI/popupInfoAllEvent/infoAllEvent/event6

# Event name labels (popup)
@onready var event_name_1: Label = $LocationUI/popupInfoAllEvent/infoAllEvent/event/nameEvent
@onready var event_name_2: Label = $LocationUI/popupInfoAllEvent/infoAllEvent/event2/nameEvent
@onready var event_name_3: Label = $LocationUI/popupInfoAllEvent/infoAllEvent/event3/nameEvent
@onready var event_name_4: Label = $LocationUI/popupInfoAllEvent/infoAllEvent/event4/nameEvent
@onready var event_name_5: Label = $LocationUI/popupInfoAllEvent/infoAllEvent/event5/nameEvent
@onready var event_name_6: Label = $LocationUI/popupInfoAllEvent/infoAllEvent/event6/nameEvent

# Event description labels (popup)
@onready var event_desc_1: Label = $LocationUI/popupInfoAllEvent/infoAllEvent/event/nameEvent2
@onready var event_desc_2: Label = $LocationUI/popupInfoAllEvent/infoAllEvent/event2/nameEvent2
@onready var event_desc_3: Label = $LocationUI/popupInfoAllEvent/infoAllEvent/event3/nameEvent2
@onready var event_desc_4: Label = $LocationUI/popupInfoAllEvent/infoAllEvent/event4/nameEvent2
@onready var event_desc_5: Label = $LocationUI/popupInfoAllEvent/infoAllEvent/event5/nameEvent2
@onready var event_desc_6: Label = $LocationUI/popupInfoAllEvent/infoAllEvent/event6/nameEvent2

# Location buttons
@onready var btn_lotus_village: Button = $lotusVillage
@onready var btn_colloseum: Button = $colloseum
@onready var btn_death_land: Button = $deathLand
@onready var btn_forest_of_shadows: Button = $forestOfShadows
@onready var btn_shadow_mountain: Button = $shadowMountain
@onready var btn_haskal_village: Button = $haskalVillage
@onready var btn_dark_ruin: Button = $darkRuin

var is_dragging: bool = false
var last_mouse_position: Vector2 = Vector2.ZERO

# Animation
var label_tween: Tween
var panel_tween: Tween
var popup_tween: Tween

# Active button style
var active_style: StyleBoxFlat
var original_styles: Dictionary = {}
var original_hover_styles: Dictionary = {}
var active_button: Button = null
var current_location_id: String = ""

# Event icon original styles (for hiding/showing)
var event_icon_original_styles: Dictionary = {}

# Label hidden position
var label_hidden_top: float = 10.0
var label_hidden_bottom: float = 50.0
var label_visible_top: float = -30.0
var label_visible_bottom: float = 10.0

# All event slots for iteration
var event_slots: Array[Panel] = []
var event_names: Array[Label] = []
var event_descs: Array[Label] = []

func _ready():
	camera.make_current()
	
	_setup_active_style()
	_setup_event_arrays()
	_save_event_icon_styles()
	
	location_label.offset_top = label_hidden_top
	location_label.offset_bottom = label_hidden_bottom
	
	_setup_panel_hidden()
	_setup_popup_hidden()
	_connect_location_buttons()
	_connect_ui_buttons()
	
	if texture:
		var map_size = texture.get_size()
		size = map_size
		camera.limit_left = 0
		camera.limit_right = int(map_size.x)
		camera.limit_top = 0
		camera.limit_bottom = int(map_size.y)
		camera.zoom = Vector2(0.1, 0.1)
		_play_intro_zoom()

func _play_intro_zoom():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CIRC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "zoom", Vector2(0.8, 0.8), 1.0)

func _setup_active_style():
	active_style = StyleBoxFlat.new()
	active_style.bg_color = Color(0, 0, 0, 0.7)
	active_style.corner_radius_top_left = 20
	active_style.corner_radius_top_right = 20
	active_style.corner_radius_bottom_left = 20
	active_style.corner_radius_bottom_right = 20
	
	var all_buttons: Array[Button] = [
		btn_lotus_village, btn_colloseum, btn_death_land,
		btn_forest_of_shadows, btn_shadow_mountain,
		btn_haskal_village, btn_dark_ruin
	]
	for btn in all_buttons:
		original_styles[btn] = btn.get_theme_stylebox("normal")
		original_hover_styles[btn] = btn.get_theme_stylebox("hover")

func _setup_event_arrays():
	event_slots = [event_slot_1, event_slot_2, event_slot_3, event_slot_4, event_slot_5, event_slot_6]
	event_names = [event_name_1, event_name_2, event_name_3, event_name_4, event_name_5, event_name_6]
	event_descs = [event_desc_1, event_desc_2, event_desc_3, event_desc_4, event_desc_5, event_desc_6]

func _save_event_icon_styles():
	# Simpan style asli dari locationInfoPanel event icons
	event_icon_original_styles[event_icon_1] = event_icon_1.get_theme_stylebox("panel")
	event_icon_original_styles[event_icon_2] = event_icon_2.get_theme_stylebox("panel")
	event_icon_original_styles[event_icon_3] = event_icon_3.get_theme_stylebox("panel")

func _apply_active_style(button: Button):
	_remove_all_active_styles()
	button.add_theme_stylebox_override("normal", active_style)
	button.add_theme_stylebox_override("hover", active_style)
	button.add_theme_stylebox_override("hover_pressed", active_style)
	active_button = button

func _remove_all_active_styles():
	for btn in original_styles:
		btn.add_theme_stylebox_override("normal", original_styles[btn])
		btn.add_theme_stylebox_override("hover", original_hover_styles[btn])
		btn.add_theme_stylebox_override("hover_pressed", original_hover_styles[btn])
	active_button = null

func _setup_panel_hidden():
	location_info_panel.visible = false
	location_info_panel.scale = Vector2(0.5, 0.5)
	location_info_panel.pivot_offset = location_info_panel.size / 2
	info_panel_1.modulate.a = 0.0
	info_panel_2.modulate.a = 0.0
	info_panel_3.modulate.a = 0.0
	info_name_label.modulate.a = 0.0
	info_lore_label.modulate.a = 0.0
	btn_more_info.modulate.a = 0.0

func _setup_popup_hidden():
	popup_all_events.visible = false
	popup_bg.modulate.a = 0.0
	popup_title.modulate.a = 0.0
	btn_close_popup.modulate.a = 0.0
	for slot in event_slots:
		slot.modulate.a = 0.0

func _connect_location_buttons():
	btn_lotus_village.pressed.connect(_on_location_pressed.bind("lotusVillage"))
	btn_colloseum.pressed.connect(_on_location_pressed.bind("colloseum"))
	btn_death_land.pressed.connect(_on_location_pressed.bind("deathLand"))
	btn_forest_of_shadows.pressed.connect(_on_location_pressed.bind("forestOfShadows"))
	btn_shadow_mountain.pressed.connect(_on_location_pressed.bind("shadowMountain"))
	btn_haskal_village.pressed.connect(_on_location_pressed.bind("haskalVillage"))
	btn_dark_ruin.pressed.connect(_on_location_pressed.bind("darkRuin"))

func _connect_ui_buttons():
	btn_more_info.pressed.connect(_on_more_info_pressed)
	btn_close_popup.pressed.connect(_on_close_popup_pressed)

func _on_location_pressed(location_id: String):
	var loc_data = LocationDatabase.get_location(location_id)
	if not loc_data:
		return
	
	current_location_id = location_id
	
	match location_id:
		"lotusVillage": _apply_active_style(btn_lotus_village)
		"colloseum": _apply_active_style(btn_colloseum)
		"deathLand": _apply_active_style(btn_death_land)
		"forestOfShadows": _apply_active_style(btn_forest_of_shadows)
		"shadowMountain": _apply_active_style(btn_shadow_mountain)
		"haskalVillage": _apply_active_style(btn_haskal_village)
		"darkRuin": _apply_active_style(btn_dark_ruin)
	
	_show_label(loc_data.location_name)
	_show_info_panel(loc_data)

func _on_more_info_pressed():
	_hide_info_panel()
	await panel_tween.finished
	
	var loc_data = LocationDatabase.get_location(current_location_id)
	if loc_data:
		_show_popup(loc_data.events)

func _on_close_popup_pressed():
	_hide_popup()

func _get_active_location_id() -> String:
	if active_button == btn_lotus_village: return "lotusVillage"
	if active_button == btn_colloseum: return "colloseum"
	if active_button == btn_death_land: return "deathLand"
	if active_button == btn_forest_of_shadows: return "forestOfShadows"
	if active_button == btn_shadow_mountain: return "shadowMountain"
	if active_button == btn_haskal_village: return "haskalVillage"
	if active_button == btn_dark_ruin: return "darkRuin"
	return ""

func _show_label(location_name: String):
	location_label.text = location_name
	
	if label_tween:
		label_tween.kill()
	
	location_label.offset_top = label_hidden_top
	location_label.offset_bottom = label_hidden_bottom
	
	label_tween = create_tween()
	label_tween.set_trans(Tween.TRANS_CIRC)
	label_tween.set_ease(Tween.EASE_OUT)
	label_tween.tween_property(location_label, "offset_top", label_visible_top, 0.3)
	label_tween.parallel().tween_property(location_label, "offset_bottom", label_visible_bottom, 0.3)

func _hide_label():
	if label_tween:
		label_tween.kill()
	
	label_tween = create_tween()
	label_tween.set_trans(Tween.TRANS_CIRC)
	label_tween.set_ease(Tween.EASE_IN)
	label_tween.tween_property(location_label, "offset_top", label_hidden_top, 0.3)
	label_tween.parallel().tween_property(location_label, "offset_bottom", label_hidden_bottom, 0.3)

func _show_info_panel(loc_data: LocationData):
	if panel_tween:
		panel_tween.kill()
	
	location_info_panel.visible = true
	location_info_panel.pivot_offset = location_info_panel.size / 2
	location_info_panel.scale = Vector2(0.5, 0.5)
	location_info_panel.modulate.a = 1.0
	info_name_label.text = loc_data.location_name
	info_lore_label.text = loc_data.lore
	
	# Reset semua event icon ke style asli (kosongkan jika tidak ada event)
	info_panel_1.visible = false
	info_panel_2.visible = false
	info_panel_3.visible = false
	
	# Tampilkan event icon jika ada (max 3)
	var events = loc_data.events
	if events.size() > 0:
		info_panel_1.visible = true
		info_panel_1.add_theme_stylebox_override("panel", _get_event_icon_style(events[0]))
	if events.size() > 1:
		info_panel_2.visible = true
		info_panel_2.add_theme_stylebox_override("panel", _get_event_icon_style(events[1]))
	if events.size() > 2:
		info_panel_3.visible = true
		info_panel_3.add_theme_stylebox_override("panel", _get_event_icon_style(events[2]))
	
	info_name_label.modulate.a = 0.0
	info_lore_label.modulate.a = 0.0
	btn_more_info.modulate.a = 0.0
	
	panel_tween = create_tween()
	panel_tween.set_parallel(true)
	panel_tween.tween_property(location_info_panel, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(info_name_label, "modulate:a", 1.0, 0.3).set_delay(0.1).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(info_lore_label, "modulate:a", 1.0, 0.3).set_delay(0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(btn_more_info, "modulate:a", 1.0, 0.3).set_delay(0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	if info_panel_1.visible:
		panel_tween.tween_property(info_panel_1, "modulate:a", 1.0, 0.3).set_delay(0.15).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	if info_panel_2.visible:
		panel_tween.tween_property(info_panel_2, "modulate:a", 1.0, 0.3).set_delay(0.25).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	if info_panel_3.visible:
		panel_tween.tween_property(info_panel_3, "modulate:a", 1.0, 0.3).set_delay(0.35).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)

func _get_event_icon_style(event: EventData) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = event.icon
	return style

func _hide_info_panel():
	if panel_tween:
		panel_tween.kill()
	
	panel_tween = create_tween()
	panel_tween.set_parallel(true)
	panel_tween.tween_property(location_info_panel, "scale", Vector2(0.5, 0.5), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	panel_tween.tween_property(info_panel_1, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	panel_tween.tween_property(info_panel_2, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	panel_tween.tween_property(info_panel_3, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	panel_tween.tween_property(info_name_label, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	panel_tween.tween_property(info_lore_label, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	panel_tween.tween_property(btn_more_info, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	
	await panel_tween.finished
	location_info_panel.visible = false

func _show_popup(events: Array[EventData]):
	if popup_tween:
		popup_tween.kill()
	
	popup_all_events.visible = true
	popup_bg.modulate.a = 0.0
	popup_title.modulate.a = 0.0
	btn_close_popup.modulate.a = 0.0
	
	# Setup semua event slots
	for i in range(6):
		if i < events.size():
			# Ada event - tampilkan
			event_slots[i].visible = true
			event_slots[i].modulate.a = 0.0
			event_names[i].text = events[i].event_name
			event_descs[i].text = events[i].description
			event_slots[i].add_theme_stylebox_override("panel", _get_event_icon_style(events[i]))
		else:
			# Slot kosong - tampilkan tapi kosong
			event_slots[i].visible = true
			event_slots[i].modulate.a = 0.0
			event_names[i].text = ""
			event_descs[i].text = ""
			event_slots[i].add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	
	popup_tween = create_tween()
	popup_tween.set_parallel(true)
	popup_tween.tween_property(popup_bg, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	popup_tween.tween_property(popup_title, "modulate:a", 1.0, 0.3).set_delay(0.1).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	popup_tween.tween_property(btn_close_popup, "modulate:a", 1.0, 0.3).set_delay(0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	for i in range(6):
		popup_tween.tween_property(event_slots[i], "modulate:a", 1.0, 0.3).set_delay(0.1 + i * 0.1).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)

func _hide_popup():
	if popup_tween:
		popup_tween.kill()
	
	popup_tween = create_tween()
	popup_tween.set_parallel(true)
	popup_tween.tween_property(popup_bg, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	popup_tween.tween_property(popup_title, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	popup_tween.tween_property(btn_close_popup, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	for slot in event_slots:
		popup_tween.tween_property(slot, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	
	await popup_tween.finished
	popup_all_events.visible = false

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Jangan proses drag kalau klik di atas button/interaktif UI
			var hovered = get_viewport().gui_get_hovered_control()
			if hovered and hovered is BaseButton:
				return
			is_dragging = event.pressed
			if is_dragging:
				last_mouse_position = event.position
				_hide_label()
				_hide_info_panel()
				_remove_all_active_styles()
	
	if event is InputEventMouseMotion and is_dragging:
		var delta = event.position - last_mouse_position
		camera.position -= delta
		last_mouse_position = event.position
		camera.position.x = clampf(camera.position.x, camera.limit_left, camera.limit_right)
		camera.position.y = clampf(camera.position.y, camera.limit_top, camera.limit_bottom)
	
	if event is InputEventScreenTouch:
		var hovered = get_viewport().gui_get_hovered_control()
		if hovered and hovered is BaseButton:
			return
		is_dragging = event.pressed
		if is_dragging:
			last_mouse_position = event.position
			_hide_label()
			_hide_info_panel()
			_remove_all_active_styles()
	
	if event is InputEventScreenDrag and is_dragging:
		var delta = event.position - last_mouse_position
		camera.position -= delta
		last_mouse_position = event.position
		camera.position.x = clampf(camera.position.x, camera.limit_left, camera.limit_right)
		camera.position.y = clampf(camera.position.y, camera.limit_top, camera.limit_bottom)
