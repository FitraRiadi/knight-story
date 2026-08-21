extends Control

@onready var camera: Camera2D = $Camera2D
@onready var atk_btn: Button = $atkBtn
@onready var defend_btn: Button = $defendBtn

# --- NODE UI STATUS PLAYER ---
@onready var hp_bar: Panel = $"player-information/HPstatus/bar"
@onready var hp_label: Label = $"player-information/HPstatus/number"

@onready var stamina_bar: Panel = $"player-information/STAMINAstatus/bar"
@onready var stamina_label: Label = $"player-information/STAMINAstatus/number"

@onready var morale_bar: Panel = $"player-information/MORALstatus/bar"
@onready var morale_label: Label = $"player-information/MORALstatus/number"

# --- NODE UI STATUS ENEMY (SELECTED TARGET) ---
@onready var enemy_info_container: Control = $"enemy-information"
@onready var enemy_hp_bar: Panel = $"enemy-information/HPstatus/bar"
@onready var enemy_hp_label: Label = $"enemy-information/HPstatus/number"
@onready var enemy_level_label: Label = $"enemy-information/level/level"
@onready var enemy_profile_img: TextureRect = $"enemy-information/profile/Panel/img"
@onready var enemy_name_label: Label = $"enemy-information/enemyName"

# Memuat scene musuh secara dinamis untuk mencegah Cyclic Dependency
var enemy_scene: PackedScene

# --- PATH FOLDER RESOURCE MUSUH (.tres) ---
@export_dir var enemy_resources_folder: String = "res://data/enemies/"

# --- STATISTIK PLAYER ---
var max_hp: float = 500.0
var current_hp: float = 500.0

var max_stamina: float = 200.0
var current_stamina: float = 200.0
var attack_stamina_cost: float = 15.0

var max_morale: float = 200.0
var current_morale: float = 100.0

# Stat Bertarung
var player_damage: float = 20.0
var player_crit_damage: float = 50.0
var player_critical_chance: float = 50.0
var player_hit_rate: float = 100.0

var max_hp_bar_width: float = 0.0
var max_stamina_bar_width: float = 0.0
var max_morale_bar_width: float = 0.0
var max_enemy_hp_bar_width: float = 0.0

var enemies: Array[BattleEnemy] = []
var selected_enemy_index: int = 0
var is_player_turn: bool = true

var original_atk_pos: Vector2
var original_def_pos: Vector2
var default_camera_pos: Vector2 = Vector2.ZERO

@export var center_spawn_position: Vector2 = Vector2(380, 180)

# Array ini akan terisi otomatis dengan mendeteksi file .tres
var available_enemy_pool: Array[String] = []

# --- NODE VFX DARAH MERAH SISI KAMERA ---
var blood_vignette_rect: TextureRect
var blood_vignette_tween: Tween

# --- ENEMY UI ANIMATION STATE ---
var original_enemy_info_pos: Vector2
var enemy_info_tween: Tween
var is_enemy_info_visible: bool = true

# ============================================================
# PLAYER HP CAMERA OVERLAY
# ============================================================
var player_hp_overlay_layer: CanvasLayer
var player_hp_overlay_root: Control
var player_hp_overlay_background: ColorRect
var player_hp_overlay_bar: ColorRect
var player_hp_overlay_label: Label
var player_hp_overlay_damage_label: Label

var player_hp_overlay_max_width: float = 360.0
var player_hp_overlay_bar_height: float = 18.0
var player_hp_overlay_visual_hp: float = 500.0

var player_hp_overlay_tween: Tween
var player_hp_overlay_show_tween: Tween
var player_hp_overlay_hide_tween: Tween
var player_hp_overlay_visible: bool = false


func _ready() -> void:
	original_atk_pos = atk_btn.position
	original_def_pos = defend_btn.position
	
	if enemy_info_container:
		original_enemy_info_pos = enemy_info_container.position
	
	if camera:
		default_camera_pos = camera.global_position
	
	if hp_bar:
		max_hp_bar_width = hp_bar.size.x
	
	if stamina_bar:
		max_stamina_bar_width = stamina_bar.size.x
	
	if morale_bar:
		max_morale_bar_width = morale_bar.size.x
		
	if enemy_hp_bar:
		max_enemy_hp_bar_width = enemy_hp_bar.size.x
	
	_setup_blood_vignette()
	_setup_player_hp_camera_overlay()
	_update_player_ui_instant()
	
	atk_btn.pressed.connect(_on_attack_pressed)
	defend_btn.pressed.connect(_on_defend_pressed)
	
	# Deteksi otomatis semua file musuh .tres di folder
	_auto_detect_enemy_pool()
	
	# Spawn awal
	spawn_random_enemies(1, 3, 1, 5)


# ============================================================
# PLAYER HP CAMERA OVERLAY SETUP
# ============================================================

func _setup_player_hp_camera_overlay() -> void:
	player_hp_overlay_layer = CanvasLayer.new()
	player_hp_overlay_layer.layer = 110
	add_child(player_hp_overlay_layer)
	
	player_hp_overlay_root = Control.new()
	player_hp_overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player_hp_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_hp_overlay_layer.add_child(player_hp_overlay_root)
	
	player_hp_overlay_background = ColorRect.new()
	player_hp_overlay_background.position = Vector2(190.0, 275.0)
	player_hp_overlay_background.size = Vector2(player_hp_overlay_max_width, player_hp_overlay_bar_height)
	player_hp_overlay_background.color = Color(0.12, 0.12, 0.12, 0.95)
	player_hp_overlay_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_hp_overlay_root.add_child(player_hp_overlay_background)
	
	player_hp_overlay_bar = ColorRect.new()
	player_hp_overlay_bar.position = Vector2.ZERO
	player_hp_overlay_bar.size = Vector2(player_hp_overlay_max_width, player_hp_overlay_bar_height)
	player_hp_overlay_bar.color = Color(0.82, 0.04, 0.04, 1.0)
	player_hp_overlay_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_hp_overlay_background.add_child(player_hp_overlay_bar)
	
	player_hp_overlay_label = Label.new()
	player_hp_overlay_label.position = Vector2.ZERO
	player_hp_overlay_label.size = Vector2(player_hp_overlay_max_width, player_hp_overlay_bar_height)
	player_hp_overlay_label.text = "500 / 500"
	player_hp_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_hp_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player_hp_overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_hp_overlay_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	player_hp_overlay_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	player_hp_overlay_label.add_theme_constant_override("shadow_offset_x", 1)
	player_hp_overlay_label.add_theme_constant_override("shadow_offset_y", 1)
	player_hp_overlay_background.add_child(player_hp_overlay_label)
	
	player_hp_overlay_damage_label = Label.new()
	player_hp_overlay_damage_label.position = Vector2(player_hp_overlay_max_width - 100.0, -20.0)
	player_hp_overlay_damage_label.size = Vector2(100.0, 40.0)
	player_hp_overlay_damage_label.text = ""
	player_hp_overlay_damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_hp_overlay_damage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player_hp_overlay_damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_hp_overlay_damage_label.modulate.a = 0.0
	player_hp_overlay_damage_label.add_theme_color_override("font_color", Color(1.0, 0.846, 0.819, 1.0))
	player_hp_overlay_damage_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	player_hp_overlay_damage_label.add_theme_constant_override("shadow_offset_x", 1)
	player_hp_overlay_damage_label.add_theme_constant_override("shadow_offset_y", 1)
	player_hp_overlay_damage_label.add_theme_font_size_override("font_size", 22)
	player_hp_overlay_background.add_child(player_hp_overlay_damage_label)
	
	player_hp_overlay_background.modulate.a = 0.0
	player_hp_overlay_background.position.y += 70.0
	player_hp_overlay_visual_hp = current_hp


func _show_player_hp_camera_overlay() -> void:
	if not player_hp_overlay_background:
		return
	if player_hp_overlay_show_tween and player_hp_overlay_show_tween.is_running():
		player_hp_overlay_show_tween.kill()
	if player_hp_overlay_hide_tween and player_hp_overlay_hide_tween.is_running():
		player_hp_overlay_hide_tween.kill()
	
	player_hp_overlay_visible = true
	var target_y = 275.0
	
	player_hp_overlay_show_tween = create_tween().set_parallel(true)
	player_hp_overlay_show_tween.tween_property(player_hp_overlay_background, "position:y", target_y, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	player_hp_overlay_show_tween.tween_property(player_hp_overlay_background, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_update_player_hp_overlay_visual(player_hp_overlay_visual_hp)


func _hide_player_hp_camera_overlay() -> void:
	if not player_hp_overlay_background:
		return
	if player_hp_overlay_hide_tween and player_hp_overlay_hide_tween.is_running():
		player_hp_overlay_hide_tween.kill()
	if player_hp_overlay_show_tween and player_hp_overlay_show_tween.is_running():
		player_hp_overlay_show_tween.kill()
	if not player_hp_overlay_visible:
		return
	
	player_hp_overlay_visible = false
	var target_y = 345.0
	
	player_hp_overlay_hide_tween = create_tween().set_parallel(true)
	player_hp_overlay_hide_tween.tween_property(player_hp_overlay_background, "position:y", target_y, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	player_hp_overlay_hide_tween.tween_property(player_hp_overlay_background, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _update_player_hp_overlay_visual(hp_value: float) -> void:
	if not player_hp_overlay_bar:
		return
	var hp_ratio = clampf(hp_value / max_hp, 0.0, 1.0)
	player_hp_overlay_bar.size.x = (hp_ratio * player_hp_overlay_max_width)
	if player_hp_overlay_label:
		player_hp_overlay_label.text = (str(int(hp_value)) + " / " + str(int(max_hp)))


func _animate_player_hp_overlay_damage(damage_amount: float) -> void:
	if not player_hp_overlay_background:
		return
	
	_show_player_hp_camera_overlay()
	if player_hp_overlay_tween and player_hp_overlay_tween.is_running():
		player_hp_overlay_tween.kill()
	
	var starting_hp = player_hp_overlay_visual_hp
	var target_hp = current_hp
	if starting_hp < target_hp:
		starting_hp = target_hp
	
	player_hp_overlay_visual_hp = starting_hp
	
	if player_hp_overlay_damage_label:
		player_hp_overlay_damage_label.text = ("-" + str(int(damage_amount)))
		player_hp_overlay_damage_label.modulate.a = 1.0
		player_hp_overlay_damage_label.position = Vector2(player_hp_overlay_max_width - 100.0, -20.0)
		player_hp_overlay_damage_label.scale = Vector2(0.7, 0.7)
		
		var damage_tween = create_tween().set_parallel(true)
		damage_tween.tween_property(player_hp_overlay_damage_label, "position:y", -55.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		damage_tween.tween_property(player_hp_overlay_damage_label, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		damage_tween.chain().tween_property(player_hp_overlay_damage_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		damage_tween.tween_property(player_hp_overlay_damage_label, "modulate:a", 0.0, 0.35).set_delay(0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	var hp_difference = starting_hp - target_hp
	var damage_duration = clampf(0.45 + (hp_difference / max_hp) * 0.8, 0.45, 1.15)
	
	player_hp_overlay_tween = create_tween()
	player_hp_overlay_tween.tween_method(
		func(value: float):
			player_hp_overlay_visual_hp = value
			_update_player_hp_overlay_visual(value),
		starting_hp,
		target_hp,
		damage_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_enemy_attack_preparing() -> void:
	player_hp_overlay_visual_hp = current_hp
	_update_player_hp_overlay_visual(player_hp_overlay_visual_hp)
	_show_player_hp_camera_overlay()


func _auto_detect_enemy_pool() -> void:
	available_enemy_pool.clear()
	if Engine.has_singleton("EnemyDatabase") or has_node("/root/EnemyDatabase"):
		var db = get_node_or_null("/root/EnemyDatabase")
		if db and "enemy_dict" in db and db.enemy_dict is Dictionary:
			for enemy_id in db.enemy_dict.keys():
				available_enemy_pool.append(str(enemy_id))
			print_rich("[color=green][POOL AUTO-DETECT][/color] Terdeteksi dari EnemyDatabase: ", available_enemy_pool)
			return
	
	var dir = DirAccess.open(enemy_resources_folder)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
					var clean_id = file_name.replace(".tres.remap", "").replace(".tres", "").to_lower()
					if not available_enemy_pool.has(clean_id):
						available_enemy_pool.append(clean_id)
			file_name = dir.get_next()
		dir.list_dir_end()
		print_rich("[color=green][POOL AUTO-DETECT][/color] Terdeteksi dari Folder '%s': %s" % [enemy_resources_folder, str(available_enemy_pool)])
	else:
		push_error("[ERROR] Gagal membuka folder musuh: " + enemy_resources_folder)


func _setup_blood_vignette() -> void:
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)
	
	blood_vignette_rect = TextureRect.new()
	blood_vignette_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blood_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blood_vignette_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blood_vignette_rect.stretch_mode = TextureRect.STRETCH_SCALE
	
	var grad_tex = GradientTexture2D.new()
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(1.0, 1.0)
	
	var grad = Gradient.new()
	grad.set_color(0, Color(0.8, 0.0, 0.0, 0.0))
	grad.set_color(1, Color(0.7, 0.0, 0.0, 0.85))
	grad_tex.gradient = grad
	
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	
	blood_vignette_rect.material = mat
	blood_vignette_rect.texture = grad_tex
	blood_vignette_rect.modulate.a = 0.0
	canvas_layer.add_child(blood_vignette_rect)


func trigger_camera_shake_and_blood(intensity: float = 12.0, duration: float = 0.35, alpha_intensity: float = 0.8) -> void:
	if camera:
		var original_offset = camera.offset
		var shake_tween = create_tween()
		var steps = 8
		for i in range(steps):
			var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
			shake_tween.tween_property(camera, "offset", offset, duration / float(steps))
		shake_tween.tween_property(camera, "offset", original_offset, 0.05)
	
	if blood_vignette_rect:
		if blood_vignette_tween and blood_vignette_tween.is_running():
			blood_vignette_tween.kill()
		
		blood_vignette_tween = create_tween()
		blood_vignette_tween.tween_property(blood_vignette_rect, "modulate:a", alpha_intensity, duration * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		blood_vignette_tween.tween_property(blood_vignette_rect, "modulate:a", 0.0, duration * 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _spawn_enemies(enemy_ids: Array[String], custom_levels: Array[int] = []) -> void:
	if enemy_scene == null:
		enemy_scene = load("res://scenes/characters/enemy/enemy.tscn") as PackedScene
	
	if enemy_scene == null:
		push_error("[ERROR] Gagal memuat scene musuh! Periksa path 'res://scenes/characters/enemy/enemy.tscn'")
		return
	
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	
	enemies.clear()
	var total_enemies = min(enemy_ids.size(), 3)
	
	for i in range(total_enemies):
		var enemy_id_to_spawn = enemy_ids[i]
		var target_level: int = 1
		if i < custom_levels.size():
			target_level = custom_levels[i]
		
		var raw_instance = enemy_scene.instantiate()
		var enemy_instance = raw_instance as BattleEnemy
		if enemy_instance == null:
			push_error("[ERROR] Root node 'enemy.tscn' tidak menggunakan script BattleEnemy!")
			raw_instance.queue_free()
			return
		
		add_child(enemy_instance)
		if enemy_instance.has_method("setup_enemy"):
			enemy_instance.setup_enemy(enemy_id_to_spawn, target_level)
		
		enemies.append(enemy_instance)
		
		# Hubungkan Signal
		enemy_instance.clicked.connect(_on_enemy_clicked)
		enemy_instance.attack_hit.connect(player_receive_damage)
		enemy_instance.attack_preparing.connect(_on_enemy_attack_preparing)
		enemy_instance.enemy_defeated.connect(_on_enemy_defeated)
		
		# Signal opsional jika musuh menerima damage/heal, langsung sync UI
		if enemy_instance.has_signal("hp_changed"):
			enemy_instance.hp_changed.connect(_on_selected_enemy_hp_changed)
	
	_position_enemies(total_enemies)
	_update_target_selection()


func spawn_custom_enemies(enemy_ids: Array[String], levels: Array[int] = []) -> void:
	_spawn_enemies(enemy_ids, levels)


func spawn_random_enemies(min_count: int = 1, max_count: int = 3, min_level: int = 1, max_level: int = 5) -> void:
	if available_enemy_pool.is_empty():
		push_error("[ERROR] Pool musuh kosong! Pastikan folder resource musuh terisi file .tres atau terdaftar di EnemyDatabase.")
		return
	
	var count: int = randi_range(clampi(min_count, 1, 3), clampi(max_count, 1, 3))
	var random_ids: Array[String] = []
	var random_levels: Array[int] = []
	
	for i in range(count):
		var random_id = available_enemy_pool.pick_random()
		var random_lvl = randi_range(min_level, max_level)
		random_ids.append(random_id)
		random_levels.append(random_lvl)
	
	_spawn_enemies(random_ids, random_levels)


func respawn_test_enemies() -> void:
	print("[TEST] Semua enemy mati. Spawn enemy baru...")
	selected_enemy_index = 0
	is_player_turn = true
	spawn_random_enemies(1, 3, 1, 5)
	_set_buttons_active(true)


func _position_enemies(count: int) -> void:
	if count == 1:
		enemies[0].global_position = center_spawn_position
	elif count == 2:
		enemies[0].global_position = center_spawn_position + Vector2(50, 0)
		enemies[1].global_position = center_spawn_position + Vector2(-70, 0)
	elif count == 3:
		enemies[0].global_position = center_spawn_position + Vector2(80, 0)
		enemies[1].global_position = center_spawn_position + Vector2(-80, 0)
		enemies[2].global_position = center_spawn_position + Vector2(0, 20)


func _update_player_ui_instant() -> void:
	if hp_bar:
		hp_bar.size.x = (current_hp / max_hp) * max_hp_bar_width
	if hp_label:
		hp_label.text = str(int(current_hp)) + " / " + str(int(max_hp))
	if stamina_bar:
		stamina_bar.size.x = (current_stamina / max_stamina) * max_stamina_bar_width
	if stamina_label:
		stamina_label.text = str(int(current_stamina)) + " / " + str(int(max_stamina))
	if morale_bar:
		morale_bar.size.x = (current_morale / max_morale) * max_morale_bar_width
	if morale_label:
		morale_label.text = str(int(current_morale)) + " / " + str(int(max_morale))


func _animate_hp_change() -> void:
	if hp_label:
		hp_label.text = str(int(current_hp)) + " / " + str(int(max_hp))
	if hp_bar:
		var target_w = (current_hp / max_hp) * max_hp_bar_width
		var tw = create_tween()
		tw.tween_property(hp_bar, "size:x", target_w, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _animate_stamina_change() -> void:
	if stamina_label:
		stamina_label.text = str(int(current_stamina)) + " / " + str(int(max_stamina))
	if stamina_bar:
		var target_w = (current_stamina / max_stamina) * max_stamina_bar_width
		var tw = create_tween()
		tw.tween_property(stamina_bar, "size:x", target_w, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func player_receive_damage(amount: float) -> void:
	current_hp = max(0.0, current_hp - amount)
	_animate_hp_change()
	_animate_player_hp_overlay_damage(amount)
	trigger_camera_shake_and_blood(14.0, 0.4, 0.85)
	if current_hp <= 0:
		print("Player Kalah!")


func _on_enemy_defeated(exp_amount: int, gold_amount: int, _dropped_items: Array[String]) -> void:
	print("Musuh dikalahkan! EXP: ", exp_amount, " | Gold: ", gold_amount)
	await get_tree().create_timer(1.0).timeout
	_update_target_selection()
	
	if enemies.is_empty():
		print("[TEST] SEMUA ENEMY MATI!")
		await get_tree().create_timer(0.5).timeout
		respawn_test_enemies()


func _on_enemy_clicked(clicked_enemy: BattleEnemy) -> void:
	if not is_player_turn:
		return
	var index = enemies.find(clicked_enemy)
	if index != -1:
		selected_enemy_index = index
		_update_target_selection()


func _unhandled_input(event: InputEvent) -> void:
	if not is_player_turn:
		return
	if enemies.size() > 1:
		if event.is_action_pressed("ui_right"):
			_change_target(1)
		elif event.is_action_pressed("ui_left"):
			_change_target(-1)


func _change_target(dir: int) -> void:
	if enemies.size() == 0:
		return
	selected_enemy_index = wrapi(selected_enemy_index + dir, 0, enemies.size())
	_update_target_selection()


# ============================================================
# ANIMASI UI ENEMY INFORMATION (CIRC PULL-UP & SHOW)
# ============================================================

func _hide_enemy_info_animated() -> void:
	if not enemy_info_container or not is_enemy_info_visible:
		return
	
	is_enemy_info_visible = false
	if enemy_info_tween and enemy_info_tween.is_running():
		enemy_info_tween.kill()
	
	var hide_target_y = original_enemy_info_pos.y - 200.0
	
	enemy_info_tween = create_tween().set_parallel(true)
	enemy_info_tween.tween_property(enemy_info_container, "position:y", hide_target_y, 0.45).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	enemy_info_tween.tween_property(enemy_info_container, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	enemy_info_tween.chain().tween_callback(enemy_info_container.hide)


func _show_enemy_info_animated() -> void:
	if not enemy_info_container:
		return
	
	if not is_enemy_info_visible:
		is_enemy_info_visible = true
		if enemy_info_tween and enemy_info_tween.is_running():
			enemy_info_tween.kill()
		
		enemy_info_container.show()
		enemy_info_container.position.y = original_enemy_info_pos.y - 200.0
		enemy_info_container.modulate.a = 0.0
		
		enemy_info_tween = create_tween().set_parallel(true)
		enemy_info_tween.tween_property(enemy_info_container, "position:y", original_enemy_info_pos.y, 0.4).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		enemy_info_tween.tween_property(enemy_info_container, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ============================================================
# UPDATE TARGET & MEMPERBARUI UI ENEMY-INFORMATION
# ============================================================

func _update_target_selection() -> void:
	enemies = enemies.filter(func(e): return is_instance_valid(e) and e.current_hp > 0)
	
	if enemies.size() == 0:
		_hide_enemy_info_animated()
		return
	
	_show_enemy_info_animated()
	
	if selected_enemy_index >= enemies.size():
		selected_enemy_index = max(0, enemies.size() - 1)
	
	for i in range(enemies.size()):
		enemies[i].set_highlight(i == selected_enemy_index)
	
	# Update UI enemy-information dengan musuh yang aktif terpilih
	_update_selected_enemy_ui()


func _update_selected_enemy_ui() -> void:
	if enemies.is_empty() or selected_enemy_index >= enemies.size():
		return
	
	var active_enemy: BattleEnemy = enemies[selected_enemy_index]
	if not is_instance_valid(active_enemy):
		return
	
	# Nama
	if enemy_name_label:
		if active_enemy.stats and active_enemy.stats.enemy_name != "":
			enemy_name_label.text = active_enemy.stats.enemy_name
		else:
			enemy_name_label.text = active_enemy.enemy_id.capitalize()
	
	# Level
	if enemy_level_label:
		enemy_level_label.text = str(active_enemy.level)
	
	# HP Text & Bar
	_update_selected_enemy_hp_bar(active_enemy)
	
	# Profile Image / Portrait
	if enemy_profile_img and active_enemy.stats:
		var profile_tex: Texture2D = null
		
		# Prioritas 1: Panggil method helper get_profile_icon() jika ada di EnemyData
		if active_enemy.stats.has_method("get_profile_icon"):
			profile_tex = active_enemy.stats.get_profile_icon()
		# Prioritas 2: Cek langsung variabel icon_enemy / profile_texture
		elif "icon_enemy" in active_enemy.stats and active_enemy.stats.icon_enemy != null:
			profile_tex = active_enemy.stats.icon_enemy
		elif "profile_texture" in active_enemy.stats and active_enemy.stats.profile_texture != null:
			profile_tex = active_enemy.stats.profile_texture
		
		# Fallback 1: Ambil dari SpriteFrames milik enemy instance
		if profile_tex == null and active_enemy.sprite_frames and active_enemy.sprite_frames.has_animation("idle"):
			profile_tex = active_enemy.sprite_frames.get_frame_texture("idle", 0)
			
		# Fallback 2: Ambil dari SpriteFrames milik stats (Resource)
		if profile_tex == null and active_enemy.stats.sprite_frames and active_enemy.stats.sprite_frames.has_animation("idle"):
			profile_tex = active_enemy.stats.sprite_frames.get_frame_texture("idle", 0)
			
		enemy_profile_img.texture = profile_tex


func _update_selected_enemy_hp_bar(active_enemy: BattleEnemy) -> void:
	if not active_enemy:
		return
		
	if enemy_hp_label:
		enemy_hp_label.text = str(int(active_enemy.current_hp)) + " / " + str(int(active_enemy.scaled_max_hp))
	
	if enemy_hp_bar:
		var ratio = clampf(active_enemy.current_hp / active_enemy.scaled_max_hp, 0.0, 1.0)
		var target_w = ratio * max_enemy_hp_bar_width
		
		var tw = create_tween()
		tw.tween_property(enemy_hp_bar, "size:x", target_w, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_selected_enemy_hp_changed() -> void:
	if enemies.size() > 0 and selected_enemy_index < enemies.size():
		var active_enemy = enemies[selected_enemy_index]
		if is_instance_valid(active_enemy):
			_update_selected_enemy_hp_bar(active_enemy)


# ============================================================
# AKSI PLAYER - ATTACK
# ============================================================

func _on_attack_pressed() -> void:
	if not is_player_turn or enemies.size() == 0:
		return
	if current_stamina < attack_stamina_cost:
		return
	
	is_player_turn = false
	_set_buttons_active(false)
	
	current_stamina = max(0.0, current_stamina - attack_stamina_cost)
	_animate_stamina_change()
	
	for enemy in enemies:
		if enemy.enemy_collision:
			enemy.enemy_collision.disabled = true
	
	var target_enemy = enemies[selected_enemy_index]
	var hit_roll = randf_range(0.0, 100.0)
	var is_hit = (hit_roll <= player_hit_rate)
	
	if not is_hit:
		target_enemy.receive_damage(0.0, false, true)
	else:
		var crit_roll = randf_range(0.0, 100.0)
		var is_crit = (crit_roll <= player_critical_chance)
		var final_damage = player_damage + (player_crit_damage if is_crit else 0.0)
		target_enemy.receive_damage(final_damage, is_crit, false)
	
	# Update UI Enemy langsung jika diserang
	_update_selected_enemy_hp_bar(target_enemy)
	
	await get_tree().create_timer(0.6).timeout
	_start_enemies_turn()


func _on_defend_pressed() -> void:
	if not is_player_turn:
		return
	
	is_player_turn = false
	_set_buttons_active(false)
	current_stamina = min(max_stamina, current_stamina + 20.0)
	_animate_stamina_change()
	
	for enemy in enemies:
		if enemy.enemy_collision:
			enemy.enemy_collision.disabled = true
	
	await get_tree().create_timer(1.0).timeout
	_start_enemies_turn()


func _start_enemies_turn() -> void:
	_update_target_selection()
	
	for enemy in enemies:
		if enemy.current_hp > 0:
			await enemy.take_turn(camera, default_camera_pos)
			_hide_player_hp_camera_overlay()
			await get_tree().create_timer(0.4).timeout
			await get_tree().create_timer(0.2).timeout
	
	for enemy in enemies:
		if enemy.current_hp > 0 and enemy.enemy_collision:
			enemy.enemy_collision.disabled = false
	
	_update_target_selection()
	
	if enemies.size() > 0:
		_set_buttons_active(true)


func _set_buttons_active(show_buttons: bool) -> void:
	atk_btn.disabled = (not show_buttons or current_stamina < attack_stamina_cost)
	defend_btn.disabled = not show_buttons
	
	var hide_offset_y: float = 200.0
	var target_atk_y: float = (original_atk_pos.y if show_buttons else original_atk_pos.y + hide_offset_y)
	var target_def_y: float = (original_def_pos.y if show_buttons else original_def_pos.y + hide_offset_y)
	
	var tween = create_tween().set_parallel(true)
	var trans_type = (Tween.TRANS_BACK if show_buttons else Tween.TRANS_CUBIC)
	var ease_type = (Tween.EASE_OUT if show_buttons else Tween.EASE_IN)
	
	tween.tween_property(atk_btn, "position:y", target_atk_y, 0.4).set_trans(trans_type).set_ease(ease_type)
	tween.tween_property(defend_btn, "position:y", target_def_y, 0.4).set_trans(trans_type).set_ease(ease_type)
	
	if show_buttons:
		tween.chain().tween_callback(_set_player_turn_true)


func _set_player_turn_true() -> void:
	is_player_turn = true
