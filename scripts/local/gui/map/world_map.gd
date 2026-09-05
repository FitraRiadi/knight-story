extends TextureRect

@onready var camera: Camera2D = $playerCamera
@onready var location_label: Label = $LocationUI/locationSellectName

# Location Info Panel
@onready var location_info_panel: Panel = $LocationUI/locationInfoPanel
@onready var info_label: Label = $LocationUI/locationInfoPanel/Label
@onready var info_panel_1: Panel = $LocationUI/locationInfoPanel/Panel
@onready var info_panel_2: Panel = $LocationUI/locationInfoPanel/Panel2
@onready var info_panel_3: Panel = $LocationUI/locationInfoPanel/Panel3

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

# Label hidden position (di bawah viewport)
var label_hidden_top: float = 10.0
var label_hidden_bottom: float = 50.0
# Label visible position (lebih ke bawah)
var label_visible_top: float = -50.0
var label_visible_bottom: float = 10.0

# Location names
var location_names: Dictionary = {
	"lotusVillage": "Lotus Village",
	"colloseum": "Colosseum",
	"deathLand": "Death Land",
	"forestOfShadows": "Forest of Shadows",
	"shadowMountain": "Shadow Mountain",
	"haskalVillage": "Hascal Village",
	"darkRuin": "Dark Ruin"
}

func _ready():
	camera.make_current()
	
	# Setup label awal (hidden)
	location_label.offset_top = label_hidden_top
	location_label.offset_bottom = label_hidden_bottom
	
	# Setup panel awal (hidden)
	_setup_panel_hidden()
	
	# Connect click signals untuk semua button
	_connect_location_buttons()
	
	if texture:
		var map_size = texture.get_size()
		
		# Set TextureRect size ke ukuran texture asli
		size = map_size
		
		# Set camera limits berdasarkan ukuran map
		camera.limit_left = 0
		camera.limit_right = int(map_size.x)
		camera.limit_top = 0
		camera.limit_bottom = int(map_size.y)
		
		# Zoom out biar map keliatan lebih lebar
		camera.zoom = Vector2(0.5, 0.5)

func _setup_panel_hidden():
	location_info_panel.visible = false
	info_panel_1.modulate.a = 0.0
	info_panel_2.modulate.a = 0.0
	info_panel_3.modulate.a = 0.0
	info_label.modulate.a = 0.0

func _connect_location_buttons():
	btn_lotus_village.pressed.connect(_on_location_pressed.bind("lotusVillage"))
	btn_colloseum.pressed.connect(_on_location_pressed.bind("colloseum"))
	btn_death_land.pressed.connect(_on_location_pressed.bind("deathLand"))
	btn_forest_of_shadows.pressed.connect(_on_location_pressed.bind("forestOfShadows"))
	btn_shadow_mountain.pressed.connect(_on_location_pressed.bind("shadowMountain"))
	btn_haskal_village.pressed.connect(_on_location_pressed.bind("haskalVillage"))
	btn_dark_ruin.pressed.connect(_on_location_pressed.bind("darkRuin"))

func _on_location_pressed(location_id: String):
	if location_names.has(location_id):
		_show_label(location_names[location_id])
		_show_info_panel(location_names[location_id])

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

func _show_info_panel(location_name: String):
	if panel_tween:
		panel_tween.kill()
	
	# Setup awal
	location_info_panel.visible = true
	info_label.text = location_name
	info_panel_1.modulate.a = 0.0
	info_panel_2.modulate.a = 0.0
	info_panel_3.modulate.a = 0.0
	info_label.modulate.a = 0.0
	
	# Stagger animation: muncul satu per satu dengan delay
	panel_tween = create_tween()
	panel_tween.set_parallel(true)
	
	# Panel 1 muncul duluan
	panel_tween.tween_property(info_panel_1, "modulate:a", 1.0, 0.3).set_delay(0.0).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	# Panel 2 muncul setelah 0.1 detik
	panel_tween.tween_property(info_panel_2, "modulate:a", 1.0, 0.3).set_delay(0.1).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	# Panel 3 muncul setelah 0.2 detik
	panel_tween.tween_property(info_panel_3, "modulate:a", 1.0, 0.3).set_delay(0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	# Label muncul paling akhir
	panel_tween.tween_property(info_label, "modulate:a", 1.0, 0.3).set_delay(0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)

func _hide_info_panel():
	if panel_tween:
		panel_tween.kill()
	
	panel_tween = create_tween()
	panel_tween.set_parallel(true)
	
	# Semua elemen hilang barengan (atau bisa stagger juga)
	panel_tween.tween_property(info_panel_1, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	panel_tween.tween_property(info_panel_2, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	panel_tween.tween_property(info_panel_3, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	panel_tween.tween_property(info_label, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	
	await panel_tween.finished
	location_info_panel.visible = false

func _input(event):
	# Mouse drag
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			if is_dragging:
				last_mouse_position = event.position
				_hide_label()
				_hide_info_panel()
	
	if event is InputEventMouseMotion and is_dragging:
		var delta = event.position - last_mouse_position
		camera.position -= delta
		last_mouse_position = event.position
		camera.position.x = clampf(camera.position.x, camera.limit_left, camera.limit_right)
		camera.position.y = clampf(camera.position.y, camera.limit_top, camera.limit_bottom)
	
	# Touch drag
	if event is InputEventScreenTouch:
		is_dragging = event.pressed
		if is_dragging:
			last_mouse_position = event.position
			_hide_label()
			_hide_info_panel()
	
	if event is InputEventScreenDrag and is_dragging:
		var delta = event.position - last_mouse_position
		camera.position -= delta
		last_mouse_position = event.position
		camera.position.x = clampf(camera.position.x, camera.limit_left, camera.limit_right)
		camera.position.y = clampf(camera.position.y, camera.limit_top, camera.limit_bottom)
