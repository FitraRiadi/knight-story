extends Control

@onready var camera: Camera2D = $Camera2D
@onready var hand_right: TextureRect = $"Camera2D/hand-right"
@onready var hand_left: TextureRect = $"Camera2D/hand-left"

@onready var atk_btn: Button = $interaction/atkBtn
@onready var defend_btn: Button = $interaction/defendBtn
@onready var backpack_btn: Button = $interaction/backpackBtn
@onready var run_btn: Button = $interaction/runBtn
@onready var skill_btn: Button = $interaction/skillBtn
@onready var parry_btn: Button = $parryBtn

# DIUBAH: Menjadi TextureProgressBar agar bisa melakukan efek radial/melingkar
@onready var parry_timing_bar: TextureProgressBar = $parryBtn/timing

# --- NODE UI QTE ATTACK ---
@onready var attack_qte_node: Control = $attackQte
@onready var attack_qte_bg: TextureRect = $"attackQte/bg"
@onready var attack_bar_container: Panel = $"attackQte/bg/bar-container"
@onready var attack_bar_low: Panel = $"attackQte/bg/bar-container/bar-low"
@onready var attack_bar_mid: Panel = $"attackQte/bg/bar-container/bar-mid"
@onready var attack_bar_success: Panel = $"attackQte/bg/bar-container/bar-success"
@onready var attack_bar_running: Panel = $"attackQte/bg/bar-container/bar-running"
@onready var reset_target_btn: Button = $"attackQte/resetTarget"

# --- NODE UI STATUS PLAYER ---
@onready var hp_bar: Panel = $"player-information/HPstatus/bar"
@onready var hp_label: Label = $"player-information/HPstatus/number"

@onready var stamina_bar: Panel = $"player-information/STAMINAstatus/bar"
@onready var stamina_label: Label = $"player-information/STAMINAstatus/number"

@onready var morale_bar: Panel = $"player-information/MORALstatus/bar"
@onready var morale_label: Label = $"player-information/MORALstatus/number"

# --- NODE UI PLAYER INFO ---
@onready var player_name_label: Label = $"player-information/information/name"
@onready var player_level_label: Label = $"player-information/level/level"
@onready var player_badge_label: Label = $"player-information/badge/Label"
@onready var player_profile_img: TextureRect = $"player-information/profile/Panel/img"
@onready var exp_bar_progress: Panel = $"player-information/information/exp-bar/exp-progress"

var enemy_scene: PackedScene
@export_dir var enemy_resources_folder: String = "res://data/enemies/"

# --- STATISTIK PLAYER (dari PlayerData) ---
var max_hp: float
var current_hp: float

var max_stamina: float
var current_stamina: float
var attack_stamina_cost: float

var max_morale: float
var current_morale: float

var player_damage: float
var player_crit_damage: float
var player_critical_chance: float
var player_hit_rate: float
var player_speed: float
var defense_flat_reduction: float
var parry_flat_reduction: float
var player_durability: float

var is_defending: bool = false

var max_hp_bar_width: float = 0.0
var max_stamina_bar_width: float = 0.0
var max_morale_bar_width: float = 0.0
var max_exp_bar_width: float = 0.0
var max_enemy_hp_bar_width: float = 0.0

# Player buff & heal particles
var player_buff_particles: CPUParticles2D = null
var player_heal_particles: CPUParticles2D = null
var current_player_buff_type: String = ""

var enemies: Array[BattleEnemy] = []
var selected_enemy_index: int = 0
var is_player_turn: bool = true

var original_atk_pos: Vector2
var original_def_pos: Vector2
var original_backpack_pos: Vector2
var original_run_post: Vector2
var original_skill_post: Vector2
var default_camera_pos: Vector2 = Vector2.ZERO

@export var center_spawn_position: Vector2 = Vector2(380, 180)
var available_enemy_pool: Array[String] = []

var blood_vignette_rect: TextureRect
var blood_vignette_tween: Tween

var attack_shadow_rect: TextureRect
var attack_shadow_tween: Tween

var attack_success_glow: Panel
var attack_success_glow_tween: Tween

var original_enemy_info_pos: Vector2
var enemy_info_tween: Tween
var is_enemy_info_visible: bool = true

var hand_layer: CanvasLayer
var hand_breath_tween: Tween
var hand_move_tween: Tween
var original_hand_pos: Vector2

@export var hand_corner_offset: Vector2 = Vector2(120, 200)

var hand_left_breath_tween: Tween
var hand_left_move_tween: Tween
var original_hand_left_pos: Vector2

@export var hand_left_corner_offset: Vector2 = Vector2(-120, 200)

# BGM SYSTEM
var bgm_player: AudioStreamPlayer

# COMBO SYSTEM
var current_combo: int = 0
var combo_canvas_layer: CanvasLayer
var combo_popup_label: Label
var combo_tween: Tween

# INTERACTIVE PARRY QTE SYSTEM
var parry_timer: SceneTreeTimer
var is_parry_window_active: bool = false
var parry_success_this_turn: bool = false
var parry_canvas_layer: CanvasLayer
var parry_timing_tween: Tween
var parry_extra_reduction: float = 0.0
var current_enemy_attacking: BattleEnemy = null

# INTERACTIVE ATTACK QTE SYSTEM
enum AttackResult { MISS, LOW, MID, CRITICAL }

var is_attack_qte_active: bool = false
var can_input_attack_qte: bool = false 
var attack_qte_canvas_layer: CanvasLayer
var attack_running_tween: Tween
var target_attack_qte_pos: Vector2

# PLAYER HP CAMERA OVERLAY
var player_hp_overlay_layer: CanvasLayer
var player_hp_overlay_root: Control
var player_hp_overlay_background: ColorRect
var player_hp_overlay_bar: ColorRect
var player_hp_overlay_label: Label
var player_hp_overlay_damage_label: Label

var player_hp_overlay_max_width: float = 360.0
var player_hp_overlay_bar_height: float = 18.0
var player_hp_overlay_visual_hp: float

var player_hp_overlay_tween: Tween
var player_hp_overlay_show_tween: Tween
var player_hp_overlay_hide_tween: Tween
var player_hp_overlay_visible: bool = false

# BATTLE INVENTORY SYSTEM
var battle_inventory_scene: PackedScene = preload("res://scenes/battle/battle_inventory.tscn")
var battle_inventory_instance: Control = null
var inventory_canvas_layer: CanvasLayer
var is_inventory_open: bool = false

# ITEM DROP SYSTEM
var drop_layer: CanvasLayer
var item_cache: Dictionary = {}  # item_id -> ItemData
const ITEMS_FOLDER: String = "res://data/items/"

# EXP DROP SYSTEM
var level_up_label: Label

# PLAYER BUFF & EFFECT SYSTEM
var player_buff_manager: BuffManager
var player_effect_container: Control
var player_effect_center_position: Vector2 = Vector2.ZERO

# SCOREBOARD SYSTEM
var total_attacks: int = 0
var total_hits: int = 0
var total_parries: int = 0
var enemies_killed: int = 0

@onready var scoreBoard: Control = $scoreBoard
@onready var score_card_enemy: Control = $scoreBoard/cardScore
@onready var score_card_accuracy: Control = $scoreBoard/cardScore2
@onready var score_card_parry: Control = $scoreBoard/cardScore3
@onready var score_label_enemy: Label = $scoreBoard/cardScore/score
@onready var score_label_accuracy: Label = $scoreBoard/cardScore2/score
@onready var score_label_parry: Label = $scoreBoard/cardScore3/score
@onready var score_continue_btn: Button = $scoreBoard/continueBtn
@onready var score_container: Panel = $scoreBoard/container
@onready var score_container2: Panel = $scoreBoard/container2
@onready var score_container3: Panel = $scoreBoard/container3
@onready var score_title: Label = $scoreBoard/title

# BATTLE INTRO
@onready var map_title: Label = $bg/mapTitle
@onready var player_info: Control = $"player-information"

const PLAYER_STATUS_ICONS: Dictionary = {
	"attack_up": preload("res://assets/ui/icons/statusEffect/attackUp.png"),
	"health_up": preload("res://assets/ui/icons/statusEffect/healthUp.png"),
	"poison": preload("res://assets/ui/icons/statusEffect/poison.png"),
	"stun": preload("res://assets/ui/icons/statusEffect/stun.png")
}


func _ready() -> void:
	if atk_btn: original_atk_pos = atk_btn.position
	if defend_btn: original_def_pos = defend_btn.position
	if backpack_btn: original_backpack_pos = backpack_btn.position
	if run_btn: original_run_post = run_btn.position
	if skill_btn: original_skill_post = skill_btn.position
	
	_setup_bgm()
	_setup_hand_layer()
	_setup_parry_qte_ui()
	_setup_attack_qte_ui()
	_setup_combo_ui()
	_setup_battle_inventory_layer()
	_setup_drop_layer()
	_setup_player_buff_and_effect()
	_setup_player_buff_particles()
	_setup_player_heal_particles()
	
	if camera: default_camera_pos = camera.global_position
	if hp_bar: max_hp_bar_width = hp_bar.size.x
	if stamina_bar: max_stamina_bar_width = stamina_bar.size.x
	if morale_bar: max_morale_bar_width = morale_bar.size.x
	if exp_bar_progress: max_exp_bar_width = exp_bar_progress.size.x
		
	_setup_blood_vignette()
	_setup_player_hp_camera_overlay()
	_load_player_data()
	_update_player_ui_instant()
	_setup_scoreboard()
	
	if atk_btn: atk_btn.pressed.connect(_on_attack_pressed)
	if defend_btn: defend_btn.pressed.connect(_on_defend_pressed)
	if backpack_btn: backpack_btn.pressed.connect(_on_backpack_pressed)
	if run_btn: run_btn.pressed.connect(_on_run_pressed)
	if reset_target_btn and not reset_target_btn.pressed.is_connected(_on_reset_target_pressed):
		reset_target_btn.pressed.connect(_on_reset_target_pressed)

	_setup_button_hover_scale(atk_btn)
	_setup_button_hover_scale(defend_btn)
	_setup_button_hover_scale(backpack_btn)
	_setup_button_hover_scale(run_btn)
	_setup_button_hover_scale(skill_btn)

	_auto_detect_enemy_pool()
	# Hide buttons dulu, nanti muncul setelah intro
	_set_buttons_active(false, true)
	# Intro: map title fade + player info slide (barengan)
	_play_battle_intro()
	_animate_player_info_intro()
	await _animate_hands_intro()
	spawn_random_enemies(1, 3, 1, 5)


# ============================================================
# LOAD PLAYER DATA
# ============================================================
func _load_player_data() -> void:
	var pd = PlayerDataManager.data
	if pd == null:
		push_error("[BattleManager] PlayerData tidak ditemukan!")
		return

	max_hp = pd.max_hp
	current_hp = pd.max_hp

	max_stamina = pd.max_stamina
	current_stamina = pd.max_stamina
	attack_stamina_cost = pd.attack_stamina_cost

	max_morale = pd.max_morale
	current_morale = pd.max_morale * 0.5

	player_damage = pd.player_damage
	player_crit_damage = pd.player_crit_damage
	player_critical_chance = pd.player_critical_chance
	player_hit_rate = pd.player_hit_rate
	player_speed = pd.player_speed
	defense_flat_reduction = pd.defense_flat_reduction
	parry_flat_reduction = pd.parry_flat_reduction
	player_durability = pd.durability

	if player_name_label: player_name_label.text = pd.player_name
	if player_level_label: player_level_label.text = str(pd.player_level)
	if player_profile_img and pd.player_profile:
		player_profile_img.texture = pd.player_profile

	player_hp_overlay_visual_hp = pd.max_hp

	_animate_exp_bar()


func _animate_exp_bar() -> void:
	var pd = PlayerDataManager.data
	if pd == null or not exp_bar_progress:
		return

	var exp_ratio: float = 0.0
	if pd.player_max_exp > 0:
		exp_ratio = clampf(float(pd.player_exp) / float(pd.player_max_exp), 0.0, 1.0)

	var target_width: float = exp_ratio * max_exp_bar_width
	var tw = create_tween()
	tw.tween_property(exp_bar_progress, "size:x", target_width, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ============================================================
# SETUP BATTLE INVENTORY
# ============================================================
func _setup_battle_inventory_layer() -> void:
	inventory_canvas_layer = CanvasLayer.new()
	inventory_canvas_layer.layer = 160
	add_child(inventory_canvas_layer)


# ============================================================
# SETUP DROP LAYER
# ============================================================
func _setup_drop_layer() -> void:
	drop_layer = CanvasLayer.new()
	drop_layer.name = "DropLayer"
	drop_layer.layer = 150
	add_child(drop_layer)


# ============================================================
# SETUP PLAYER BUFF & EFFECT SYSTEM
# ============================================================
func _setup_player_buff_and_effect() -> void:
	player_buff_manager = BuffManager.new()
	
	# Setup player effect container (node "playerEffect" under player-information)
	var pi_node := get_node_or_null("player-information")
	if pi_node:
		player_effect_container = pi_node.get_node_or_null("playerEffect") as Control
	
	if player_effect_container:
		# Hitung center position dari child "effect"
		var effect_node := player_effect_container.get_node_or_null("effect") as TextureRect
		if effect_node:
			player_effect_center_position = effect_node.position + (effect_node.size / 2.0)
			effect_node.texture = null  # Reset texture default
			effect_node.hide()
		# Bersihkan child temporary saat awal
		for child in player_effect_container.get_children():
			if child.name != "effect":
				child.queue_free()


func _update_player_status_effects() -> void:
	if not player_effect_container:
		return
	
	# 1. Bersihkan efek lama (kecuali yang temporary)
	for child in player_effect_container.get_children():
		if child.name != "effect" and not child.has_meta("is_temporary"):
			child.queue_free()
	
	var active_types: Array[String] = []
	
	if player_buff_manager and player_buff_manager.has_method("get_active_buff_types"):
		active_types = player_buff_manager.get_active_buff_types()
	
	# Cek attack bonus dari buff aktif
	if player_buff_manager and player_buff_manager.get_total_attack_bonus() > 0.0:
		if not active_types.has("attack_up"):
			active_types.append("attack_up")
	
	# Cek HP di atas max (overheal) — sama kayak enemy
	if current_hp > max_hp and not active_types.has("health_up"):
		active_types.append("health_up")
	
	var icon_width: float = 20.0
	
	# 2. Tambahkan efek baru ke dalam container
	for type in active_types:
		if PLAYER_STATUS_ICONS.has(type):
			var icon_rect: TextureRect = TextureRect.new()
			icon_rect.texture = PLAYER_STATUS_ICONS[type]
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.custom_minimum_size = Vector2(icon_width, icon_width)
			icon_rect.size = Vector2(icon_width, icon_width)
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			player_effect_container.add_child(icon_rect)
	
	# 3. Rapihkan semua ikon
	_rearrange_player_status_icons()


func _show_player_temporary_status_icon(icon_texture: Texture2D, duration: float = 1.5) -> void:
	if not player_effect_container:
		return
	
	var icon_width: float = 20.0
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.set_meta("is_temporary", true)
	icon_rect.texture = icon_texture
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(icon_width, icon_width)
	icon_rect.size = Vector2(icon_width, icon_width)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	player_effect_container.add_child(icon_rect)
	_rearrange_player_status_icons()
	
	var tween: Tween = create_tween()
	tween.tween_interval(duration)
	tween.tween_property(icon_rect, "modulate:a", 0.0, 0.4)
	tween.finished.connect(func() -> void:
		if is_instance_valid(icon_rect):
			icon_rect.queue_free()
			_rearrange_player_status_icons()
	)


func _rearrange_player_status_icons() -> void:
	if not is_instance_valid(player_effect_container):
		return
	
	var valid_icons: Array[Control] = []
	for child in player_effect_container.get_children():
		if child.name != "effect" and not child.is_queued_for_deletion():
			valid_icons.append(child as Control)
	
	var count: int = valid_icons.size()
	if count == 0:
		return
	
	var icon_width: float = 20.0
	var spacing: float = 4.0
	var step: float = icon_width + spacing
	var total_width: float = (count * icon_width) + ((count - 1) * spacing)
	
	for i in range(count):
		var offset_x: float = -(total_width / 2.0) + (i * step)
		valid_icons[i].position = player_effect_center_position + Vector2(offset_x, -(icon_width / 2.0) + 5.0)


func _get_player_attack_bonus() -> float:
	if player_buff_manager:
		return player_buff_manager.get_total_attack_bonus()
	return 0.0


# ============================================================
# LOAD ITEM BY ID
# ============================================================
func _load_item_by_id(item_id: String) -> ItemData:
	# Cek cache dulu
	if item_cache.has(item_id):
		return item_cache[item_id]
	
	# Scan folder items
	var dir := DirAccess.open(ITEMS_FOLDER)
	if not dir:
		push_error("[BattleManager] Tidak bisa buka folder: " + ITEMS_FOLDER)
		return null
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource_path := ITEMS_FOLDER + file_name
			var item := load(resource_path) as ItemData
			if item and item.item_id == item_id:
				item_cache[item_id] = item
				return item
		file_name = dir.get_next()
	
	dir.list_dir_end()
	push_warning("[BattleManager] Item tidak ditemukan: " + item_id)
	return null


# ============================================================
# SPAWN DROP ITEM
# ============================================================
func _spawn_drop_item(item_id: String, enemy_pos: Vector2) -> void:
	var item := _load_item_by_id(item_id)
	if not item:
		return
	
	# Buat ItemDropVisual
	var drop_visual := ItemDropVisual.new()
	drop_visual.item_clicked.connect(_on_drop_item_clicked)
	drop_layer.add_child(drop_visual)
	drop_visual.setup(item, enemy_pos)


# ============================================================
# ON DROP ITEM CLICKED
# ============================================================
func _on_drop_item_clicked(item: ItemData) -> void:
	if not item:
		return
	
	# Cek apakah inventory penuh (tidak ada slot null)
	var battle_inv := PlayerDataManager.data.battle_inventory
	if not battle_inv:
		return
	
	# Cari slot pertama yang null
	var slot_index := -1
	for i in range(battle_inv.items.size()):
		if battle_inv.items[i] == null:
			slot_index = i
			break
	
	# Kalau semua slot terisi, cari slot kosong di akhir
	if slot_index == -1:
		if battle_inv.items.size() < 9:
			slot_index = battle_inv.items.size()
		else:
			print("[BattleManager] Inventory penuh! Tidak bisa ambil item.")
			return
	
	# Masukkan item ke slot
	if slot_index < battle_inv.items.size():
		battle_inv.items[slot_index] = item
	else:
		battle_inv.items.append(item)
	
	PlayerDataManager.save()
	print("[BattleManager] Item ditambahkan: ", item.item_name, " di slot ", slot_index)


# ============================================================
# EXP DROP SYSTEM
# ============================================================
func _spawn_exp_orbs(exp_amount: int, from_pos: Vector2) -> void:
	# Hitung target posisi EXP bar (global posisi dari exp_bar_progress)
	var exp_bar_global := Vector2.ZERO
	if exp_bar_progress:
		exp_bar_global = exp_bar_progress.global_position + Vector2(exp_bar_progress.size.x, exp_bar_progress.size.y / 2.0)
	
	# Spawn beberapa orbs (max 5, atau lebih kecil kalau exp sedikit)
	var orb_count := mini(5, maxi(1, exp_amount / 5))
	var exp_per_orb := ceili(float(exp_amount) / float(orb_count))
	
	for i in range(orb_count):
		# Offset spawn position di sekitar enemy
		var spawn_pos := from_pos + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		
		# Offset target di sekitar exp bar
		var target := exp_bar_global + Vector2(randf_range(-8, 8), randf_range(-4, 4))
		
		var orb: ExpOrb = ExpOrb.new()
		orb.setup(exp_per_orb, spawn_pos, target)
		drop_layer.add_child(orb)
		
		# Delay antar orb (stagger)
		if i > 0:
			await get_tree().create_timer(0.1).timeout
	
	# Tunggu sebentar lalu update EXP + level up
	await get_tree().create_timer(0.3).timeout
	_add_exp_and_check_level_up(exp_amount)


func _add_exp_and_check_level_up(exp_amount: int) -> void:
	var pd = PlayerDataManager.data
	if pd == null:
		return
	
	pd.player_exp += exp_amount
	print("[BattleManager] EXP gained: +", exp_amount, " | Total: ", pd.player_exp, "/", pd.player_max_exp)
	
	# Level up loop (kalau exp cukup untuk naik beberapa level)
	var leveled_up := false
	while pd.player_exp >= pd.player_max_exp:
		pd.player_exp -= pd.player_max_exp
		pd.player_level += 1
		pd.player_max_exp = _calc_max_exp(pd.player_level)
		leveled_up = true
		print("[BattleManager] LEVEL UP! Level ", pd.player_level, " | Max EXP: ", pd.player_max_exp)
	
	# Update UI
	_animate_exp_bar()
	if player_level_label:
		player_level_label.text = str(pd.player_level)
	
	# Save
	PlayerDataManager.save()
	
	# Tampilkan notifikasi level up
	if leveled_up:
		_show_level_up_notification(pd.player_level)


func _calc_max_exp(level: int) -> int:
	# Setiap 5 level, max_exp naik +250
	# Lv 1-5: 100, Lv 6-10: 350, Lv 11-15: 600, dst.
	var tier: int = (level - 1) / 5
	return 100 + (tier * 250)


func _show_level_up_notification(new_level: int) -> void:
	# Buat label "LEVEL UP!" di tengah layar
	var lbl := Label.new()
	lbl.text = "LEVEL UP! Lv." + str(new_level)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(300, 50)
	lbl.position = Vector2(
		(size.x - 300) / 2.0,
		(size.y - 50) / 2.0
	)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.modulate.a = 0.0
	lbl.z_index = 200
	add_child(lbl)
	
	# Animasi muncul
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", lbl.position.y - 20, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Tahan sebentar
	await tw.finished
	await get_tree().create_timer(1.0).timeout
	
	# Animasi hilang
	var tw_out := create_tween()
	tw_out.tween_property(lbl, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw_out.finished
	lbl.queue_free()


func _on_backpack_pressed() -> void:
	if not is_player_turn or is_inventory_open:
		return
	open_battle_inventory()


func open_battle_inventory() -> void:
	if not battle_inventory_scene or is_inventory_open:
		return
		
	is_inventory_open = true
	is_player_turn = false
	
	_set_buttons_active(false)
	_pull_hand_to_corner(0.4)
	
	battle_inventory_instance = battle_inventory_scene.instantiate() as Control
	battle_inventory_instance.inventory_data = PlayerDataManager.data.battle_inventory
	inventory_canvas_layer.add_child(battle_inventory_instance)

	if battle_inventory_instance.has_signal("closed"):
		battle_inventory_instance.connect("closed", Callable(self, "_on_battle_inventory_closed"))
	if battle_inventory_instance.has_signal("inventory_closed"):
		battle_inventory_instance.connect("inventory_closed", Callable(self, "_on_battle_inventory_closed"))
	if battle_inventory_instance.has_signal("item_used"):
		battle_inventory_instance.connect("item_used", Callable(self, "_on_item_used_in_battle"))
	
	battle_inventory_instance.show()
	battle_inventory_instance.modulate.a = 0.0
	battle_inventory_instance.scale = Vector2(0.8, 0.8)
	
	var viewport_size = get_viewport().get_visible_rect().size
	battle_inventory_instance.pivot_offset = battle_inventory_instance.size * 0.5
	battle_inventory_instance.position = (viewport_size - battle_inventory_instance.size) * 0.5
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(battle_inventory_instance, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(battle_inventory_instance, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close_battle_inventory() -> void:
	if not is_inventory_open:
		return
		
	is_inventory_open = false
	
	if is_instance_valid(battle_inventory_instance):
		battle_inventory_instance.queue_free()
		battle_inventory_instance = null
	
	is_player_turn = true
	_reset_hand_to_original(0.4)
	_set_buttons_active(true)


func _on_battle_inventory_closed() -> void:
	close_battle_inventory()


func _on_item_used_in_battle(item: ItemData) -> void:
	is_inventory_open = false
	
	var old_inventory = battle_inventory_instance
	battle_inventory_instance = null
	
	if is_instance_valid(old_inventory):
		var tw = create_tween()
		tw.tween_interval(0.2)
		tw.tween_callback(old_inventory.queue_free)
	
	# Terapkan Efek Item pakai BuffManager
	if item and player_buff_manager:
		# Suara minum potion
		var potion_sfx: AudioStream = load("res://assets/audio/effects/battle/items/use_potion_base.mp3")
		if potion_sfx:
			var sfx_player := AudioStreamPlayer.new()
			sfx_player.stream = potion_sfx
			sfx_player.volume_db = -5.0
			add_child(sfx_player)
			sfx_player.play()
			sfx_player.finished.connect(sfx_player.queue_free)

		var result: Dictionary = player_buff_manager.apply_item_simple(item, self)
		
		# Heal — tampilkan temporary icon + visual
		if result.get("healed", 0.0) > 0.0:
			_animate_hp_change()
			_play_heal_visual(result["healed"])
			if PLAYER_STATUS_ICONS.has("health_up"):
				_show_player_temporary_status_icon(PLAYER_STATUS_ICONS["health_up"], 2.0)
		
		# Buff (attack/defense) — tampilkan persistent icon + visual
		if result.get("buff_applied", false):
			_update_player_status_effects()
			var effect_str: String = item.get_effect_type_string() if item.has_method("get_effect_type_string") else ""
			_play_buff_visual(effect_str)
	
	_reset_hand_to_original(0.3)
	
	await get_tree().create_timer(1.0).timeout
	_start_enemies_turn()


# ============================================================
# SETUP BGM SYSTEM
# ============================================================
func _setup_bgm() -> void:
	var bgm_stream: AudioStream = load("uid://c42peweo18yvn")
	if bgm_stream:
		bgm_player = AudioStreamPlayer.new()
		bgm_player.stream = bgm_stream
		bgm_player.volume_db = -20.0
		bgm_player.autoplay = true
		add_child(bgm_player)
		bgm_player.play()


# ============================================================
# COMBO SYSTEM UI & LOGIC
# ============================================================
func _setup_combo_ui() -> void:
	combo_canvas_layer = CanvasLayer.new()
	combo_canvas_layer.layer = 180
	add_child(combo_canvas_layer)
	
	combo_popup_label = Label.new()
	combo_popup_label.text = ""
	combo_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_popup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_popup_label.add_theme_font_size_override("font_size", 24)
	combo_popup_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	
	combo_canvas_layer.add_child(combo_popup_label)
	combo_popup_label.hide()


func _add_combo(amount: int = 1) -> void:
	current_combo += amount
	if current_combo >= 3:
		_show_combo_popup()


func _reset_combo() -> void:
	current_combo = 0
	if combo_popup_label and combo_popup_label.visible:
		var hide_tw = create_tween().set_parallel(true)
		hide_tw.tween_property(combo_popup_label, "modulate:a", 0.0, 0.4)
		hide_tw.tween_property(combo_popup_label, "scale", Vector2(0.8, 0.8), 0.4)
		hide_tw.chain().tween_callback(combo_popup_label.hide)


func _show_combo_popup() -> void:
	if not combo_popup_label:
		return
		
	if combo_tween and combo_tween.is_running():
		combo_tween.kill()
		
	combo_popup_label.text = str(current_combo) + "x Combo!"
	combo_popup_label.show()
	
	var combo_sfx: AudioStream = load("res://assets/audio/effects/battle/ui/comboLabel-pop.mp3")
	if combo_sfx:
		var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(sfx_player)
		sfx_player.stream = combo_sfx
		sfx_player.play()
		sfx_player.finished.connect(sfx_player.queue_free)
	
	var viewport_size = get_viewport().get_visible_rect().size
	combo_popup_label.reset_size()
	var actual_size = combo_popup_label.get_combined_minimum_size()
	combo_popup_label.pivot_offset = actual_size * 0.5
	
	var right_x = viewport_size.x - actual_size.x - 550.0
	var bottom_y = viewport_size.y - actual_size.y - 250.0
	
	combo_popup_label.position = Vector2(right_x, bottom_y)
	combo_popup_label.scale = Vector2(0.3, 0.3)
	combo_popup_label.modulate.a = 0.0
	
	combo_tween = create_tween()
	combo_tween.set_parallel(true)
	combo_tween.tween_property(combo_popup_label, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	combo_tween.tween_property(combo_popup_label, "modulate:a", 1.0, 0.15)
	
	combo_tween.chain().set_parallel(false)
	combo_tween.tween_property(combo_popup_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	combo_tween.tween_interval(4.5)
	
	combo_tween.chain().set_parallel(true)
	combo_tween.tween_property(combo_popup_label, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	combo_tween.chain().tween_callback(combo_popup_label.hide)


func _setup_attack_qte_ui() -> void:
	if attack_qte_node:
		attack_qte_canvas_layer = CanvasLayer.new()
		attack_qte_canvas_layer.layer = 155
		add_child(attack_qte_canvas_layer)
		
		var current_parent = attack_qte_node.get_parent()
		if current_parent:
			current_parent.remove_child(attack_qte_node)
		attack_qte_canvas_layer.add_child(attack_qte_node)
		
		attack_qte_node.hide()
		attack_qte_node.modulate.a = 0.0

	_setup_attack_shadow()
	_setup_success_glow()


func _setup_attack_shadow() -> void:
	var shadow_canvas_layer = CanvasLayer.new()
	shadow_canvas_layer.layer = 154
	add_child(shadow_canvas_layer)

	attack_shadow_rect = TextureRect.new()
	attack_shadow_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	attack_shadow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attack_shadow_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	attack_shadow_rect.stretch_mode = TextureRect.STRETCH_SCALE

	var grad_tex = GradientTexture2D.new()
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.8, 0.8)

	var grad = Gradient.new()
	grad.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	grad.set_color(1, Color(0.0, 0.0, 0.0, 0.45))
	grad_tex.gradient = grad

	attack_shadow_rect.texture = grad_tex
	attack_shadow_rect.modulate.a = 0.0
	shadow_canvas_layer.add_child(attack_shadow_rect)


func _show_attack_shadow() -> void:
	if not attack_shadow_rect:
		return
	if attack_shadow_tween and attack_shadow_tween.is_running():
		attack_shadow_tween.kill()
	attack_shadow_tween = create_tween()
	attack_shadow_tween.tween_property(attack_shadow_rect, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _hide_attack_shadow() -> void:
	if not attack_shadow_rect:
		return
	if attack_shadow_tween and attack_shadow_tween.is_running():
		attack_shadow_tween.kill()
	attack_shadow_tween = create_tween()
	attack_shadow_tween.tween_property(attack_shadow_rect, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _setup_success_glow() -> void:
	if not attack_bar_success:
		return
	attack_success_glow = Panel.new()
	attack_success_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	attack_success_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var glow_style = StyleBoxFlat.new()
	glow_style.bg_color = Color(1.0, 0.9, 0.3)
	glow_style.corner_radius_top_left = 10
	glow_style.corner_radius_top_right = 10
	glow_style.corner_radius_bottom_right = 10
	glow_style.corner_radius_bottom_left = 10
	attack_success_glow.add_theme_stylebox_override("panel", glow_style)

	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	attack_success_glow.material = mat

	attack_success_glow.modulate.a = 0.0
	attack_success_glow.visible = false
	attack_bar_success.add_child(attack_success_glow)


func _start_success_glow() -> void:
	if not attack_success_glow:
		return
	attack_success_glow.visible = true
	if attack_success_glow_tween and attack_success_glow_tween.is_running():
		attack_success_glow_tween.kill()
	attack_success_glow_tween = create_tween().set_loops()
	attack_success_glow_tween.tween_property(attack_success_glow, "modulate:a", 0.6, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	attack_success_glow_tween.tween_property(attack_success_glow, "modulate:a", 0.15, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_success_glow() -> void:
	if not attack_success_glow:
		return
	if attack_success_glow_tween and attack_success_glow_tween.is_running():
		attack_success_glow_tween.kill()
	attack_success_glow.modulate.a = 0.0
	attack_success_glow.visible = false


func _start_attack_qte() -> void:
	if not attack_qte_node or not attack_bar_container or not attack_bar_success or not attack_bar_running:
		_execute_actual_attack(AttackResult.MID)
		return
	
	is_attack_qte_active = true
	can_input_attack_qte = false
	attack_qte_node.show()
	
	var qte_open_sfx: AudioStream = load("res://assets/audio/effects/battle/ui/attackQte-open.mp3")
	if qte_open_sfx:
		var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(sfx_player)
		sfx_player.stream = qte_open_sfx
		sfx_player.play()
		sfx_player.finished.connect(sfx_player.queue_free)
	
	var viewport_size = get_viewport().get_visible_rect().size
	target_attack_qte_pos = (viewport_size - attack_qte_node.size) * 0.5
	
	attack_qte_node.position = target_attack_qte_pos
	attack_qte_node.modulate.a = 0.0
	attack_qte_node.scale = Vector2(0.5, 0.5)
	
	var pop_tw = create_tween().set_parallel(true)
	pop_tw.tween_property(attack_qte_node, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pop_tw.tween_property(attack_qte_node, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if camera:
		var target_focus_pos = default_camera_pos
		var target_zoom = Vector2(1.25, 1.25)
		
		if enemies.size() > 0 and selected_enemy_index < enemies.size():
			var active_enemy = enemies[selected_enemy_index]
			if is_instance_valid(active_enemy):
				var half_width: float = viewport_size.x / target_zoom.x * 0.5
				var half_height: float = viewport_size.y / target_zoom.y * 0.5
				
				var clamped_x: float = clampf(active_enemy.global_position.x, half_width, viewport_size.x - half_width)
				var clamped_y: float = clampf(active_enemy.global_position.y, half_height, viewport_size.y - half_height)
				
				target_focus_pos = Vector2(clamped_x, clamped_y)

		var cam_zoom_tw = create_tween().set_parallel(true)
		cam_zoom_tw.tween_property(camera, "global_position", target_focus_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		cam_zoom_tw.tween_property(camera, "zoom", target_zoom, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		cam_zoom_tw.set_ignore_time_scale(true)

	_show_attack_shadow()

	var container_width: float = attack_bar_container.size.x
	var container_height: float = attack_bar_container.size.y

	# hit_rate (1-100) = overall difficulty, semakin kecil semakin susah
	var hit_rate: float = clampf(player_hit_rate, 1.0, 100.0)
	var effective_width: float = container_width * (hit_rate / 100.0)

	# critical_chance (1-100) = lebar bar-success di dalam effective area
	var crit_chance: float = clampf(player_critical_chance, 1.0, 100.0)

	# Lebar bar: success proporsional ke crit_chance, mid sebagai pemisah, low = keseluruhan hit zone
	var success_width: float = max(8.0, effective_width * (crit_chance / 100.0) * 0.5)
	var mid_width: float = max(12.0, effective_width * 0.6)
	var low_width: float = max(16.0, effective_width * 0.9)

	# Clamp biar ga overlap satu sama lain
	success_width = min(success_width, mid_width)
	mid_width = min(mid_width, low_width)

	# Center semua bar di dalam effective area
	var effective_center: float = container_width * 0.5

	if attack_bar_low:
		attack_bar_low.size.x = low_width
		attack_bar_low.position.x = effective_center - (low_width * 0.5)
		attack_bar_low.position.y = 0.0
		attack_bar_low.size.y = container_height

	if attack_bar_mid:
		attack_bar_mid.size.x = mid_width
		attack_bar_mid.position.x = effective_center - (mid_width * 0.5)
		attack_bar_mid.position.y = 0.0
		attack_bar_mid.size.y = container_height

	if attack_bar_success:
		attack_bar_success.size.x = success_width
		attack_bar_success.position.x = effective_center - (success_width * 0.5)
		attack_bar_success.position.y = 0.0
		attack_bar_success.size.y = container_height

	_start_success_glow()

	# Running bar tetap loop full container width
	var running_width: float = attack_bar_running.size.x
	var run_min_x: float = 0.0
	var run_max_x: float = max(0.0, container_width - running_width)

	attack_bar_running.position.x = run_min_x

	if attack_running_tween and attack_running_tween.is_running():
		attack_running_tween.kill()

	attack_running_tween = create_tween().set_loops()
	attack_running_tween.tween_property(attack_bar_running, "position:x", run_max_x, 0.6).set_trans(Tween.TRANS_LINEAR)
	attack_running_tween.tween_property(attack_bar_running, "position:x", run_min_x, 0.6).set_trans(Tween.TRANS_LINEAR)
	
	await get_tree().create_timer(0.2).timeout
	if is_attack_qte_active:
		can_input_attack_qte = true


func _on_reset_target_pressed() -> void:
	const ATTACK_QTE_CLOSE = preload("uid://cvo7g7uksf6dc")
	if ATTACK_QTE_CLOSE:
		var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(sfx_player)
		sfx_player.stream = ATTACK_QTE_CLOSE
		sfx_player.play()
		sfx_player.finished.connect(sfx_player.queue_free)
	if not is_attack_qte_active:
		return
		
	is_attack_qte_active = false
	can_input_attack_qte = false
	
	if attack_running_tween and attack_running_tween.is_running():
		attack_running_tween.kill()

	_stop_success_glow()
	_hide_attack_shadow()

	if camera:
		var cam_reset_tw = create_tween().set_parallel(true)
		cam_reset_tw.tween_property(camera, "zoom", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN_OUT)
		cam_reset_tw.tween_property(camera, "global_position", default_camera_pos, 0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN_OUT)
		cam_reset_tw.set_ignore_time_scale(true)
		
	var hide_tw = create_tween().set_parallel(true)
	hide_tw.tween_property(attack_qte_node, "scale", Vector2(0.5, 0.5), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	hide_tw.tween_property(attack_qte_node, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	hide_tw.chain().tween_callback(attack_qte_node.hide)
	
	is_player_turn = true
	_set_buttons_active(true)


func _check_is_overlapping(runner: Panel, target: Panel) -> bool:
	if not runner or not target:
		return false
	var r_x = runner.position.x
	var r_right = r_x + runner.size.x
	var t_x = target.position.x
	var t_right = t_x + target.size.x
	return (r_x <= t_right) and (r_right >= t_x)


func _check_attack_qte_result() -> void:
	if not is_attack_qte_active:
		return
	
	is_attack_qte_active = false
	can_input_attack_qte = false
	
	if attack_running_tween and attack_running_tween.is_running():
		attack_running_tween.kill()

	_stop_success_glow()
	_hide_attack_shadow()
	
	if camera:
		var cam_reset_tw = create_tween().set_parallel(true)
		cam_reset_tw.tween_property(camera, "zoom", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN_OUT)
		cam_reset_tw.tween_property(camera, "global_position", default_camera_pos, 0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN_OUT)
		cam_reset_tw.set_ignore_time_scale(true)
	
	var qte_result: AttackResult = AttackResult.MISS
	
	# SCOREBOARD: Hitung total serangan
	total_attacks += 1
	
	if _check_is_overlapping(attack_bar_running, attack_bar_success):
		qte_result = AttackResult.CRITICAL
	elif _check_is_overlapping(attack_bar_running, attack_bar_mid):
		qte_result = AttackResult.MID
	elif _check_is_overlapping(attack_bar_running, attack_bar_low):
		qte_result = AttackResult.LOW
	
	# SCOREBOARD: Hitung hit (bukan miss)
	if qte_result != AttackResult.MISS:
		total_hits += 1
	
	if qte_result != AttackResult.MISS:
		_add_combo(1)
	else:
		_reset_combo()
	
	_spawn_attack_qte_particles()
	_spawn_qte_popup_text(qte_result)
	
	var hide_tw = create_tween().set_parallel(true)
	hide_tw.tween_property(attack_qte_node, "scale", Vector2(0.5, 0.5), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	hide_tw.tween_property(attack_qte_node, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	hide_tw.chain().tween_callback(attack_qte_node.hide)
	
	_execute_actual_attack(qte_result)


func _spawn_attack_qte_particles() -> void:
	var particles = CPUParticles2D.new()
	attack_bar_container.add_child(particles)
	
	particles.position = attack_bar_container.size * 0.5
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 24
	particles.lifetime = 0.4
	particles.speed_scale = 1.5
	
	particles.direction = Vector2(1, 0)
	particles.spread = 180.0
	particles.initial_velocity_min = 220.0
	particles.initial_velocity_max = 380.0
	particles.gravity = Vector2.ZERO
	
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color(1.0, 1.0, 1.0, 1.0)
		
	particles.emitting = true
	
	var cleanup_tween = create_tween()
	cleanup_tween.tween_interval(0.6)
	cleanup_tween.tween_callback(particles.queue_free)


func _spawn_qte_popup_text(result: AttackResult) -> void:
	var text_msg: String = ""
	match result:
		AttackResult.CRITICAL: text_msg = "Perfect Timing!"
		AttackResult.MID: text_msg = "Nice Timing!"
		AttackResult.LOW: text_msg = "Weak Hit!"
		AttackResult.MISS: text_msg = "Try Again.."

	var label = Label.new()
	label.text = text_msg
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)

	# Warna teks berdasarkan result
	match result:
		AttackResult.CRITICAL: label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		AttackResult.MID: label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		AttackResult.LOW: label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
		AttackResult.MISS: label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))

	# Backdrop gelap rounded
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color(0.0, 0.0, 0.0, 0.692)
	backdrop.set_corner_radius_all(10)
	backdrop.set_content_margin_all(12)
	label.add_theme_stylebox_override("normal", backdrop)

	var container := CenterContainer.new()
	container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	container.offset_top = 30.0
	container.offset_bottom = 70.0
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if attack_qte_canvas_layer:
		attack_qte_canvas_layer.add_child(container)
	else:
		add_child(container)

	container.add_child(label)
	label.pivot_offset = label.get_combined_minimum_size() * 0.5

	# Mulai dari bawah + transparan + scale kecil
	container.modulate.a = 0.0
	container.position.y = 40.0

	var tw = create_tween()
	# Stagger muncul: naik + fade in + scale bounce
	tw.tween_property(container, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(container, "position:y", 30.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(2.5)

	# Fade out + naik
	tw.chain().set_parallel(true)
	tw.tween_property(container, "position:y", 10.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(container, "modulate:a", 0.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(container.queue_free)


func _apply_hit_stop(duration: float) -> void:
	Engine.time_scale = 0.0
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func _execute_actual_attack(result: AttackResult) -> void:
	_play_juicy_hand_attack_animation()
	
	current_stamina = max(0.0, current_stamina - attack_stamina_cost)
	_animate_stamina_change()
	
	for enemy in enemies:
		if enemy.enemy_collision:
			enemy.enemy_collision.disabled = true
	
	var target_enemy = enemies[selected_enemy_index]
	
	# Hitung damage dengan buff bonus
	var total_damage: float = player_damage + _get_player_attack_bonus()
	
	match result:
		AttackResult.MISS:
			target_enemy.receive_damage(0.0, false, true)
		AttackResult.LOW:
			var low_damage = total_damage * 0.4
			target_enemy.receive_damage(low_damage, false, false)
		AttackResult.MID:
			target_enemy.receive_damage(total_damage, false, false)
		AttackResult.CRITICAL:
			var crit_damage = total_damage + player_crit_damage
			target_enemy.receive_damage(crit_damage, true, false)
	
	await get_tree().create_timer(0.8).timeout

	# TACTICAL ATTACK: Enemy bisa counter-attack setelah player nyerang
	if result != AttackResult.MISS and target_enemy.current_hp > 0 and not target_enemy.is_stunned and target_enemy.has_tactical_attack() and target_enemy.should_counter_attack():
		var ab := target_enemy.get_tactical_attack_ability()
		var counter_mult: float = TacticalAttackAbility.get_counter_damage_multiplier(ab.get_level())
		var counter_text: String = TacticalAttackAbility.get_counter_text(ab.get_level())
		var counter_color: Color = TacticalAttackAbility.get_counter_text_color(ab.get_level())

		target_enemy.show_reaction_text(counter_text, counter_color, true)
		await get_tree().create_timer(0.15).timeout

		# Play animasi attack dulu
		target_enemy.play("attack")
		await target_enemy.animation_finished

		var counter_damage: float = (target_enemy.scaled_damage + target_enemy.buff_manager.get_total_attack_bonus()) * counter_mult
		target_enemy._play_sound("attack")
		player_receive_damage_custom(counter_damage)
		trigger_camera_shake_and_blood(10.0, 0.2, 0.6)
		await get_tree().create_timer(0.3).timeout

		# Pastikan animasi balik idle setelah counter
		target_enemy.play("idle")

	_start_enemies_turn()


func _setup_parry_qte_ui() -> void:
	if parry_btn:
		parry_canvas_layer = CanvasLayer.new()
		parry_canvas_layer.layer = 150
		add_child(parry_canvas_layer)
		
		var current_parent = parry_btn.get_parent()
		if current_parent:
			current_parent.remove_child(parry_btn)
		parry_canvas_layer.add_child(parry_btn)
		
		parry_btn.hide()
		if not parry_btn.pressed.is_connected(_on_parry_button_clicked):
			parry_btn.pressed.connect(_on_parry_button_clicked)


func _show_parry_window(duration: float = 1.0) -> void:
	if not parry_btn:
		return
		
	parry_success_this_turn = false
	is_parry_window_active = true
	parry_extra_reduction = 0.0
	
	var viewport_size = get_viewport().get_visible_rect().size
	var min_x = 120.0
	var max_x = viewport_size.x - 220.0
	var min_y = 150.0
	var max_y = viewport_size.y - 250.0
	
	var random_x = randf_range(min_x, max_x)
	var random_y = randf_range(min_y, max_y)
	
	parry_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	parry_btn.position = Vector2(random_x, random_y)
	
	parry_btn.modulate = Color(1, 1, 1, 0)
	parry_btn.scale = Vector2(0.01, 0.01)
	parry_btn.show()
	
	# DIUBAH: Melakukan animasi radial value (100 -> 0)
	if parry_timing_bar:
		parry_timing_bar.value = parry_timing_bar.max_value
		if parry_timing_tween and parry_timing_tween.is_running():
			parry_timing_tween.kill()
		parry_timing_tween = create_tween()
		parry_timing_tween.tween_property(parry_timing_bar, "value", 0.0, duration).set_trans(Tween.TRANS_LINEAR)
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(parry_btn, "modulate:a", 1.0, 0.15)
	tw.tween_property(parry_btn, "scale", Vector2(0.100, 0.095), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if parry_timer != null:
		parry_timer = null
		
	parry_timer = get_tree().create_timer(duration)
	await parry_timer.timeout
	
	if parry_btn.visible and not parry_success_this_turn:
		var visual_center = parry_btn.position + Vector2(40, 40)
		_spawn_missed_popup_text(visual_center)
		_hide_parry_window()


func _hide_parry_window() -> void:
	is_parry_window_active = false
	if parry_timing_tween and parry_timing_tween.is_running():
		parry_timing_tween.kill()
		
	if parry_btn and parry_btn.visible:
		var tw = create_tween().set_parallel(true)
		tw.tween_property(parry_btn, "modulate:a", 0.0, 0.25)
		tw.tween_property(parry_btn, "scale", Vector2(0.01, 0.01), 0.25).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
		
		await tw.finished
		parry_btn.hide()


func _spawn_parry_particles(spawn_pos: Vector2) -> void:
	for dir in [-1, 1]:
		var particles = CPUParticles2D.new()
		if parry_canvas_layer:
			parry_canvas_layer.add_child(particles)
		else:
			add_child(particles)
			
		particles.position = spawn_pos
		particles.emitting = false
		particles.one_shot = true
		particles.explosiveness = 0.95
		particles.amount = 25
		particles.lifetime = 0.4
		particles.speed_scale = 1.8
		
		particles.direction = Vector2(dir, 0)
		particles.spread = 25.0
		particles.initial_velocity_min = 350.0
		particles.initial_velocity_max = 600.0
		
		particles.gravity = Vector2.ZERO
		particles.damping_min = 400.0
		particles.damping_max = 600.0
		
		particles.scale_amount_min = 4.0
		particles.scale_amount_max = 9.0
		particles.color = Color(1.0, 1.0, 1.0, 1.0)
		
		particles.emitting = true
		
		var cleanup_tween = create_tween()
		cleanup_tween.tween_interval(1.0)
		cleanup_tween.tween_callback(particles.queue_free)


func _spawn_parry_popup_text(spawn_pos: Vector2, text_msg: String = "Parry!") -> void:
	var popup_label = Label.new()
	popup_label.text = text_msg
	popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	popup_label.add_theme_font_size_override("font_size", 22)
	popup_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	
	if parry_canvas_layer:
		parry_canvas_layer.add_child(popup_label)
	else:
		add_child(popup_label)
	
	popup_label.position = spawn_pos - Vector2(100, 35)
	popup_label.custom_minimum_size = Vector2(200, 60)
	
	popup_label.scale = Vector2(0.1, 0.1)
	popup_label.modulate.a = 0.0
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(popup_label, "scale", Vector2(1.25, 1.25), 0.15).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tw.tween_property(popup_label, "modulate:a", 1.0, 0.08)
	
	tw.chain().tween_property(popup_label, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN_OUT)
	
	var fade_tw = create_tween()
	fade_tw.tween_interval(1.5)
	fade_tw.tween_property(popup_label, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade_tw.tween_callback(popup_label.queue_free)


func _spawn_missed_popup_text(spawn_pos: Vector2) -> void:
	_reset_combo()
	
	var missed_label = Label.new()
	missed_label.text = ""
	missed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	missed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	missed_label.add_theme_font_size_override("font_size", 22)
	missed_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	
	if parry_canvas_layer:
		parry_canvas_layer.add_child(missed_label)
	else:
		add_child(missed_label)
	
	missed_label.position = spawn_pos - Vector2(100, 35)
	missed_label.custom_minimum_size = Vector2(200, 60)
	
	missed_label.scale = Vector2(0.1, 0.1)
	missed_label.modulate.a = 0.0
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(missed_label, "scale", Vector2(1.25, 1.25), 0.15).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tw.tween_property(missed_label, "modulate:a", 1.0, 0.08)
	
	tw.chain().tween_property(missed_label, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN_OUT)
	
	var fade_tw = create_tween()
	fade_tw.tween_interval(1.5)
	fade_tw.tween_property(missed_label, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade_tw.tween_callback(missed_label.queue_free)


func _on_parry_button_clicked() -> void:
	if not is_parry_window_active:
		return
	
	parry_success_this_turn = true
	is_parry_window_active = false
	
	var remaining_ratio: float = 0.0
	# DIUBAH: Menghitung persentase dari value progress bar yang tersisa
	if parry_timing_bar and parry_timing_bar.max_value > 0.0:
		remaining_ratio = clampf(parry_timing_bar.value / parry_timing_bar.max_value, 0.0, 1.0)
	
	var stamina_bonus: float = 0.0
	var popup_msg: String = "Parry!"
	
	if remaining_ratio >= 0.75:
		stamina_bonus = 30.0
		parry_extra_reduction = 30.0
		popup_msg = "Perfect Parry!"
		current_morale = min(max_morale, current_morale + 10.0)
	elif remaining_ratio >= 0.30:
		stamina_bonus = 10.0
		parry_extra_reduction = 15.0
		popup_msg = "Great Parry!"
		current_morale = min(max_morale, current_morale + 5.0)
	else:
		stamina_bonus = 5.0
		parry_extra_reduction = 0.0
		popup_msg = "Parry!"
		
	var parry_sfx: AudioStream = preload("res://assets/audio/effects/battle/parry/parry-base.mp3")
	if parry_sfx:
		var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(sfx_player)
		sfx_player.stream = parry_sfx
		sfx_player.play()
		sfx_player.finished.connect(sfx_player.queue_free)
	
	_add_combo(1)
	
	# SCOREBOARD: Hitung parry
	total_parries += 1

	# MORALE: Parry berhasil -> kurangi morale enemy -25%
	if current_enemy_attacking and is_instance_valid(current_enemy_attacking):
		current_enemy_attacking.decrease_morale_by_parry()
		# Paksa animasi attack ke frame terakhir
		current_enemy_attacking.force_attack_finish = true
		# Kalau parry bikin morale habis, interrupt attack langsung
		if current_enemy_attacking.is_stunned:
			current_enemy_attacking.stun_interrupted = true

	var visual_center: Vector2 = parry_btn.position + Vector2(40, 40)
	_spawn_parry_particles(visual_center)
	_spawn_parry_popup_text(visual_center, popup_msg)
	
	if hand_left:
		if hand_left_move_tween and hand_left_move_tween.is_running():
			hand_left_move_tween.kill()
		
		var base_x: float = (original_hand_left_pos.x + 150.0) if is_defending else original_hand_left_pos.x
		var base_y: float = original_hand_left_pos.y
		
		var parry_shield_tw: Tween = create_tween()
		parry_shield_tw.tween_property(hand_left, "position", Vector2(base_x + 30.0, base_y - 45.0), 0.08)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		parry_shield_tw.tween_property(hand_left, "position", Vector2(base_x + 25.0, base_y - 35.0), 0.06)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		parry_shield_tw.tween_property(hand_left, "position", Vector2(base_x, base_y), 0.22)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var break_tw: Tween = create_tween().set_parallel(true)
	break_tw.tween_property(parry_btn, "scale", Vector2(0.07, 0.07), 0.1).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	break_tw.tween_property(parry_btn, "modulate:a", 0.0, 0.1)
	break_tw.chain().tween_callback(parry_btn.hide)
	
	current_stamina = min(max_stamina, current_stamina + stamina_bonus)
	_animate_stamina_change()
	_animate_hp_change()


func _setup_hand_layer() -> void:
	if not hand_right and not hand_left:
		return
		
	hand_layer = CanvasLayer.new()
	hand_layer.layer = 120
	add_child(hand_layer)
	
	if hand_right:
		var global_pos_right = hand_right.global_position
		hand_right.get_parent().remove_child(hand_right)
		hand_layer.add_child(hand_right)
		hand_right.global_position = global_pos_right
		original_hand_pos = hand_right.position
	
	if hand_left:
		var global_pos_left = hand_left.global_position
		hand_left.get_parent().remove_child(hand_left)
		hand_layer.add_child(hand_left)
		hand_left.global_position = global_pos_left
		original_hand_left_pos = hand_left.position
		
	# Mulai dari samping layar (off-screen)
	if hand_right:
		hand_right.position.x = get_viewport().get_visible_rect().size.x + 80.0
		hand_right.modulate.a = 0.0
	if hand_left:
		hand_left.position.x = -80.0
		hand_left.modulate.a = 0.0

func _animate_hands_intro() -> void:
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if hand_right:
		tw.tween_property(hand_right, "position", original_hand_pos, 0.5)
		tw.tween_property(hand_right, "modulate:a", 1.0, 0.4)
	if hand_left:
		tw.tween_property(hand_left, "position", original_hand_left_pos, 0.5)
		tw.tween_property(hand_left, "modulate:a", 1.0, 0.4)
	await tw.finished
	_start_hand_breathing()


func _start_hand_breathing() -> void:
	if is_defending:
		if hand_right:
			hand_breath_tween = create_tween().set_loops()
			hand_breath_tween.tween_property(hand_right, "position:y", original_hand_pos.y + 6.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			hand_breath_tween.tween_property(hand_right, "position:y", original_hand_pos.y, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return

	_stop_hand_breathing()
	
	if hand_right:
		hand_breath_tween = create_tween().set_loops()
		hand_breath_tween.tween_property(hand_right, "position:y", original_hand_pos.y + 6.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		hand_breath_tween.tween_property(hand_right, "position:y", original_hand_pos.y, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if hand_left:
		hand_left_breath_tween = create_tween().set_loops()
		hand_left_breath_tween.tween_property(hand_left, "position:y", original_hand_left_pos.y + 5.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		hand_left_breath_tween.tween_property(hand_left, "position:y", original_hand_left_pos.y, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_hand_breathing() -> void:
	if hand_breath_tween and hand_breath_tween.is_running():
		hand_breath_tween.kill()
	if hand_left_breath_tween and hand_left_breath_tween.is_running():
		hand_left_breath_tween.kill()


func _play_juicy_hand_attack_animation() -> void:
	_stop_hand_breathing()
	
	var attack_sfx_player = AudioStreamPlayer.new()
	attack_sfx_player.stream = load("res://assets/audio/effects/battle/sword/sword-attack.mp3")
	add_child(attack_sfx_player)
	attack_sfx_player.play()
	attack_sfx_player.finished.connect(attack_sfx_player.queue_free)
	
	if hand_right:
		var right_tween = create_tween()
		
		right_tween.tween_property(hand_right, "position", original_hand_pos + Vector2(25.0, -10.0), 0.07)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			
		right_tween.tween_property(hand_right, "position", original_hand_pos + Vector2(-160.0, 15.0), 0.08)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			
		right_tween.tween_callback(func():
			trigger_camera_shake_and_blood(14.0, 0.3, 0.8)
			_apply_hit_stop(0.06)
		)
		
		right_tween.tween_interval(0.04)
		
		right_tween.tween_property(hand_right, "position", original_hand_pos, 0.28)\
			.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

	if hand_left and not is_defending:
		var left_tween = create_tween().set_parallel(true)
		left_tween.tween_property(hand_left, "position:y", original_hand_left_pos.y + 25.0, 0.15)\
			.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		left_tween.chain().tween_property(hand_left, "position:y", original_hand_left_pos.y, 0.22)\
			.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN_OUT)
	
	var callback_node = create_tween()
	callback_node.tween_interval(0.45)
	callback_node.tween_callback(_start_hand_breathing)


func _pull_hand_to_corner(duration: float = 0.4) -> void:
	_stop_hand_breathing()
	
	if hand_move_tween and hand_move_tween.is_running():
		hand_move_tween.kill()
	if hand_left_move_tween and hand_left_move_tween.is_running():
		hand_left_move_tween.kill()
		
	var target_pos_right = original_hand_pos + hand_corner_offset
	var target_pos_left = original_hand_left_pos + hand_left_corner_offset
	if is_defending:
		target_pos_left = original_hand_left_pos + Vector2(150.0, 0.0)
	
	if hand_right:
		hand_move_tween = create_tween()
		hand_move_tween.tween_property(hand_right, "position", target_pos_right, duration)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			
	if hand_left and not is_defending:
		hand_left_move_tween = create_tween()
		hand_left_move_tween.tween_property(hand_left, "position", target_pos_left, duration)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _reset_hand_to_original(duration: float = 0.4) -> void:
	if hand_move_tween and hand_move_tween.is_running():
		hand_move_tween.kill()
	if hand_left_move_tween and hand_left_move_tween.is_running():
		hand_left_move_tween.kill()
		
	if hand_right:
		hand_move_tween = create_tween()
		hand_move_tween.tween_property(hand_right, "position", original_hand_pos, duration)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	if hand_left:
		hand_left_move_tween = create_tween()
		var target_reset_pos = original_hand_left_pos
		if is_defending:
			target_reset_pos = original_hand_left_pos + Vector2(150.0, 0.0)
		
		hand_left_move_tween.tween_property(hand_left, "position", target_reset_pos, duration)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	var callback_node = create_tween()
	callback_node.tween_interval(duration)
	callback_node.tween_callback(_start_hand_breathing)


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
	player_hp_overlay_label.text = ""
	player_hp_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_hp_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player_hp_overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_hp_overlay_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
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
	_pull_hand_to_corner(0.35)
	player_hp_overlay_visual_hp = current_hp
	_update_player_hp_overlay_visual(player_hp_overlay_visual_hp)
	_show_player_hp_camera_overlay()
	_show_parry_window(0.9)


func _on_battle_cry_activated(ability_level: int) -> void:
	var parry_count: int = BattleCryAbility.get_parry_count(ability_level)
	# Parry window pertama sudah muncul dari attack_preparing
	# Tambah parry window lagi jika level >= 2
	if parry_count >= 2:
		await get_tree().create_timer(0.1).timeout
		_show_parry_window(0.7)


func _auto_detect_enemy_pool() -> void:
	available_enemy_pool.clear()
	if Engine.has_singleton("EnemyDatabase") or has_node("/root/EnemyDatabase"):
		var db = get_node_or_null("/root/EnemyDatabase")
		if db and "enemy_dict" in db and db.enemy_dict is Dictionary:
			for enemy_id in db.enemy_dict.keys():
				available_enemy_pool.append(str(enemy_id))
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


func trigger_camera_shake_and_blood(intensity: float = 6.0, duration: float = 0.3, alpha_intensity: float = 0.6) -> void:
	intensity = min(intensity, 6.0) 
	
	if camera:
		var original_offset = camera.offset
		var shake_tween = create_tween()
		shake_tween.set_ignore_time_scale(true)
		
		var steps = 8
		for i in range(steps):
			var offset = Vector2(
				randf_range(-intensity * 0.3, intensity * 0.1), 
				randf_range(-intensity * 0.1, intensity * 0.3)
			)
			shake_tween.tween_property(camera, "offset", original_offset + offset, duration / float(steps))
		
		shake_tween.tween_property(camera, "offset", original_offset, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	if blood_vignette_rect:
		if blood_vignette_tween and blood_vignette_tween.is_running():
			blood_vignette_tween.kill()
		
		blood_vignette_tween = create_tween()
		blood_vignette_tween.set_ignore_time_scale(true)
		blood_vignette_tween.tween_property(blood_vignette_rect, "modulate:a", alpha_intensity, duration * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		blood_vignette_tween.tween_property(blood_vignette_rect, "modulate:a", 0.0, duration * 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _spawn_enemies(enemy_ids: Array[String], custom_levels: Array[int] = []) -> void:
	if enemy_scene == null:
		enemy_scene = load("res://scenes/characters/enemy/enemy.tscn") as PackedScene
	
	if enemy_scene == null:
		push_error("[ERROR] Gagal memuat scene musuh!")
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
			raw_instance.queue_free()
			return
		
		add_child(enemy_instance)
		if enemy_instance.has_method("setup_enemy"):
			enemy_instance.setup_enemy(enemy_id_to_spawn, target_level)
		
		# Set posisi awal (bawah) + scale kecil + transparan
		enemy_instance.global_position = _get_spawn_position(i, total_enemies) + Vector2(0, 80)
		enemy_instance.scale = Vector2(0.3, 0.3)
		enemy_instance.modulate.a = 0.0
		
		enemies.append(enemy_instance)
		
		enemy_instance.clicked.connect(_on_enemy_clicked)
		enemy_instance.attack_hit.connect(player_receive_damage_custom)
		enemy_instance.attack_preparing.connect(_on_enemy_attack_preparing)
		enemy_instance.enemy_defeated.connect(_on_enemy_defeated)
		enemy_instance.battle_cry_activated.connect(_on_battle_cry_activated)
		
	_animate_enemies_spawn()


func spawn_custom_enemies(enemy_ids: Array[String], levels: Array[int] = []) -> void:
	_spawn_enemies(enemy_ids, levels)


func spawn_random_enemies(min_count: int = 1, max_count: int = 3, min_level: int = 1, max_level: int = 5) -> void:
	if available_enemy_pool.is_empty():
		return
	
	var count: int = randi_range(clampi(min_count, 1, 2), clampi(max_count, 1, 2))
	var random_ids: Array[String] = []
	var random_levels: Array[int] = []
	
	for i in range(count):
		random_ids.append(available_enemy_pool.pick_random())
		random_levels.append(randi_range(min_level, max_level))
	
	_spawn_enemies(random_ids, random_levels)


func respawn_test_enemies() -> void:
	selected_enemy_index = 0
	is_player_turn = true
	spawn_random_enemies(1, 3, 1, 5)
	_set_buttons_active(true)


func _get_spawn_position(index: int, total: int) -> Vector2:
	if total == 1:
		return center_spawn_position
	elif total == 2:
		if index == 0:
			return center_spawn_position + Vector2(50, 0)
		else:
			return center_spawn_position + Vector2(-70, 0)
	else:
		if index == 0:
			return center_spawn_position + Vector2(80, 0)
		elif index == 1:
			return center_spawn_position + Vector2(-80, 0)
		else:
			return center_spawn_position + Vector2(0, 20)
	return center_spawn_position


func _animate_enemies_spawn() -> void:
	is_player_turn = false

	# Spawn pertama lebih lambat biar dramatic + skip button tween
	var first_spawn: bool = (enemies_killed == 0)
	var spawn_duration: float = 0.45 if first_spawn else 0.3
	var stagger: float = 0.2 if first_spawn else 0.15

	# Kalau first spawn, button muncul stagger smooth
	if first_spawn:
		_set_buttons_active_staggered()
	else:
		_set_buttons_active(false)

	for i in range(enemies.size()):
		var enemy = enemies[i]
		var target_pos: Vector2 = _get_spawn_position(i, enemies.size())
		var delay: float = i * stagger

		var tw := create_tween()
		tw.tween_interval(delay)
		tw.parallel().tween_property(enemy, "global_position", target_pos, spawn_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(enemy, "scale", Vector2(1.0, 1.0), spawn_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(enemy, "modulate:a", 1.0, spawn_duration * 0.8).set_trans(Tween.TRANS_SINE)

		# Dust particle lebih cepet (0.15s setelah mulai)
		tw.tween_callback(_spawn_dust_particle.bind(target_pos + Vector2(0, 102))).set_delay(0.15)

	# Tunggu semua selesai
	var total_time: float = (enemies.size() - 1) * stagger + spawn_duration
	await get_tree().create_timer(total_time).timeout

	_update_target_selection()
	is_player_turn = true
	_set_buttons_active(true, first_spawn)


func _spawn_dust_particle(pos: Vector2) -> void:
	var dust := CPUParticles2D.new()
	dust.emitting = true
	dust.one_shot = true
	dust.amount = 8
	dust.lifetime = 0.5
	dust.explosiveness = 0.9
	dust.direction = Vector2(0, -1)
	dust.spread = 60.0
	dust.initial_velocity_min = 30.0
	dust.initial_velocity_max = 60.0
	dust.gravity = Vector2(0, 120)
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 4.0
	dust.color = Color(0.7, 0.6, 0.4, 0.6)
	dust.position = pos
	add_child(dust)
	dust.finished.connect(dust.queue_free)


func _update_player_ui_instant() -> void:
	if hp_bar: hp_bar.size.x = (current_hp / max_hp) * max_hp_bar_width
	if hp_label: hp_label.text = str(int(current_hp)) + " / " + str(int(max_hp))
	if stamina_bar: stamina_bar.size.x = (current_stamina / max_stamina) * max_stamina_bar_width
	if stamina_label: stamina_label.text = str(int(current_stamina)) + " / " + str(int(max_stamina))
	if morale_bar: morale_bar.size.x = (current_morale / max_morale) * max_morale_bar_width
	if morale_label: morale_label.text = str(int(current_morale)) + " / " + str(int(max_morale))


func _animate_hp_change() -> void:
	if hp_label: hp_label.text = str(int(current_hp)) + " / " + str(int(max_hp))
	if hp_bar:
		var target_w = (current_hp / max_hp) * max_hp_bar_width
		var tw = create_tween()
		tw.tween_property(hp_bar, "size:x", target_w, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _animate_stamina_change() -> void:
	if stamina_label: stamina_label.text = str(int(current_stamina)) + " / " + str(int(max_stamina))
	if stamina_bar:
		var target_w = (current_stamina / max_stamina) * max_stamina_bar_width
		var tw = create_tween()
		tw.tween_property(stamina_bar, "size:x", target_w, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ============================================================
# CONSUMABLE VISUAL EFFECTS
# ============================================================

func _play_heal_visual(heal_amount: float) -> void:
	# 1. Green flash di player-info
	if player_info:
		var flash_tw := create_tween()
		flash_tw.tween_property(player_info, "modulate", Color(0.5, 1.6, 0.5, 1.0), 0.1)
		flash_tw.tween_property(player_info, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)

	# 2. Floating heal text
	if player_profile_img:
		_spawn_floating_text("+" + str(int(heal_amount)), Color(0.3, 1.0, 0.5), player_profile_img.global_position)

	# 3. Heal particles (CPUParticles2D looping)
	_play_player_heal_visual()

	# 4. Legacy one-shot particles
	if player_profile_img:
		_spawn_item_particles(player_profile_img.global_position, Color(0.3, 1.0, 0.5), 12)


func _play_buff_visual(buff_type: String) -> void:
	var particle_color: Color
	var lower_type := buff_type.to_lower()
	if lower_type.begins_with("attack") or lower_type.begins_with("damage") or lower_type.begins_with("crit"):
		particle_color = Color(1.0, 0.4, 0.2)
	elif lower_type.begins_with("defense") or lower_type.begins_with("shield"):
		particle_color = Color(0.3, 0.6, 1.0)
	else:
		particle_color = Color(1.0, 1.0, 0.3)

	# CPUParticles2D looping buff aura
	_play_player_buff_visual(buff_type)

	# Legacy one-shot particles
	if player_profile_img:
		_spawn_item_particles(player_profile_img.global_position, particle_color, 10)

	# Flash warna sesuai buff
	if player_info:
		var flash_tw := create_tween()
		flash_tw.tween_property(player_info, "modulate", Color(particle_color.r, particle_color.g, particle_color.b, 1.0), 0.1)
		flash_tw.tween_property(player_info, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)


func _spawn_floating_text(msg: String, text_color: Color, pos: Vector2) -> void:
	var label := Label.new()
	label.text = msg
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.z_index = 200
	label.position = pos + Vector2(-20, -10)
	label.modulate.a = 0.0
	add_child(label)

	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(label, "position:y", pos.y - 35.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.2)
	tw.tween_callback(label.queue_free)


func _spawn_item_particles(pos: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		var p := ColorRect.new()
		p.color = color
		p.size = Vector2(randf_range(3, 6), randf_range(3, 6))
		p.position = pos + Vector2(randf_range(-15, 15), randf_range(-5, 10))
		p.modulate.a = 0.9
		p.z_index = 190
		add_child(p)

		var offset_x: float = randf_range(-20, 20)
		var offset_y: float = randf_range(-45, -20)
		var dur: float = randf_range(0.5, 0.8)
		var delay: float = i * 0.04

		var tw := create_tween()
		tw.tween_property(p, "position", p.position + Vector2(offset_x, offset_y), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(delay)
		tw.parallel().tween_property(p, "modulate:a", 0.0, dur * 0.7).set_delay(delay)
		tw.parallel().tween_property(p, "scale", Vector2(0.3, 0.3), dur * 0.6).set_delay(delay + dur * 0.4)
		tw.tween_callback(p.queue_free).set_delay(dur + 0.1)


# ============================================================
# PLAYER BUFF & HEAL PARTICLES (CPUParticles2D)
# ============================================================

func _setup_player_buff_particles() -> void:
	if not player_profile_img:
		return
	player_buff_particles = CPUParticles2D.new()
	add_child(player_buff_particles)
	player_buff_particles.z_index = 100
	player_buff_particles.amount = 12
	player_buff_particles.lifetime = 1.5
	player_buff_particles.one_shot = false
	player_buff_particles.emitting = false
	player_buff_particles.direction = Vector2(0, -1)
	player_buff_particles.spread = 35.0
	player_buff_particles.gravity = Vector2(0, -60)
	player_buff_particles.initial_velocity_min = 20.0
	player_buff_particles.initial_velocity_max = 50.0
	player_buff_particles.scale_amount_min = 2.0
	player_buff_particles.scale_amount_max = 5.0
	player_buff_particles.color = Color(1.0, 0.4, 0.15, 0.8)
	player_buff_particles.position = player_profile_img.position + player_profile_img.size / 2.0


func _setup_player_heal_particles() -> void:
	if not player_profile_img:
		return
	player_heal_particles = CPUParticles2D.new()
	add_child(player_heal_particles)
	player_heal_particles.z_index = 100
	player_heal_particles.amount = 10
	player_heal_particles.lifetime = 0.6
	player_heal_particles.one_shot = true
	player_heal_particles.explosiveness = 0.9
	player_heal_particles.emitting = false
	player_heal_particles.direction = Vector2(0, -1)
	player_heal_particles.spread = 60.0
	player_heal_particles.gravity = Vector2(0, -200)
	player_heal_particles.initial_velocity_min = 60.0
	player_heal_particles.initial_velocity_max = 120.0
	player_heal_particles.scale_amount_min = 2.0
	player_heal_particles.scale_amount_max = 5.0
	player_heal_particles.color = Color(0.2, 1.0, 0.3, 0.9)
	player_heal_particles.position = player_profile_img.position + player_profile_img.size / 2.0


func _play_player_buff_visual(buff_type: String) -> void:
	if not player_buff_particles:
		return
	var lower_type := buff_type.to_lower()

	# Anti-duplicate: kalau type sama, restart aja
	if lower_type == current_player_buff_type and player_buff_particles.emitting:
		player_buff_particles.restart()
		return

	# Update warna sesuai type
	match lower_type:
		"attack_up":
			player_buff_particles.color = Color(1.0, 0.4, 0.15, 0.8)
		"defense_up":
			player_buff_particles.color = Color(0.3, 0.6, 1.0, 0.8)
		_:
			player_buff_particles.color = Color(1.0, 0.85, 0.2, 0.8)

	current_player_buff_type = lower_type
	player_buff_particles.emitting = true
	player_buff_particles.restart()


func _play_player_heal_visual() -> void:
	if not player_heal_particles:
		return
	player_heal_particles.restart()


func _stop_player_buff_particles() -> void:
	if player_buff_particles:
		player_buff_particles.emitting = false
	current_player_buff_type = ""


func player_receive_damage_custom(amount: float) -> void:
	_hide_parry_window()
	
	var final_damage = amount
	if parry_success_this_turn and is_defending:
		final_damage = max(0.0, amount - player_durability - (parry_flat_reduction + parry_extra_reduction + (defense_flat_reduction * 0.9)))
	elif parry_success_this_turn:
		final_damage = max(0.0, amount - player_durability - (parry_flat_reduction + parry_extra_reduction))
	elif is_defending:
		final_damage = max(0.0, amount - player_durability - defense_flat_reduction)
	else:
		final_damage = max(0.0, amount - player_durability)
	
	if is_defending:
		var shield_sfx: AudioStream = load("res://assets/audio/effects/battle/shield/shield-base.mp3")
		if shield_sfx:
			var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
			add_child(sfx_player)
			sfx_player.stream = shield_sfx
			sfx_player.play()
			sfx_player.finished.connect(sfx_player.queue_free)
	
	current_hp = max(0.0, current_hp - final_damage)
	_animate_hp_change()
	_animate_player_hp_overlay_damage(final_damage)
	trigger_camera_shake_and_blood(14.0, 0.4, 0.85)

	# MORALE: Enemy attack berhasil (tidak di-parry) -> naikkan morale +25%
	if not parry_success_this_turn and current_enemy_attacking and is_instance_valid(current_enemy_attacking):
		current_enemy_attacking.increase_morale_on_hit()

	# LIFE STEAL: Cek apakah enemy punya life steal ability
	if current_enemy_attacking and is_instance_valid(current_enemy_attacking) and current_enemy_attacking.current_hp > 0:
		current_enemy_attacking._apply_life_steal(amount)


func _on_enemy_defeated(_exp_amount: int, _gold_amount: int, _dropped_items: Array[String], enemy: BattleEnemy) -> void:
	# SCOREBOARD: Hitung enemy defeated
	enemies_killed += 1
	
	# Spawn item drops jika ada
	if not _dropped_items.is_empty() and is_instance_valid(enemy):
		var enemy_pos := enemy.global_position
		for item_id in _dropped_items:
			_spawn_drop_item(item_id, enemy_pos)
			# Offset sedikit biar item gak tumpuk
			enemy_pos.x += randf_range(-30.0, 30.0)
			enemy_pos.y += randf_range(-20.0, 20.0)
	
	# Spawn EXP orbs terbang ke UI
	if _exp_amount > 0 and is_instance_valid(enemy):
		_spawn_exp_orbs(_exp_amount, enemy.global_position)
		await get_tree().create_timer(1.2).timeout  # Tunggu orbs sampai
	else:
		await get_tree().create_timer(1.0).timeout
	
	_update_target_selection()
	
	if enemies.is_empty():
		await get_tree().create_timer(0.5).timeout
		_show_scoreboard()


func _on_enemy_clicked(clicked_enemy: BattleEnemy) -> void:
	if not is_player_turn:
		return
	var index = enemies.find(clicked_enemy)
	if index != -1:
		selected_enemy_index = index
		_update_target_selection()


func _input(event: InputEvent) -> void:
	if is_attack_qte_active and can_input_attack_qte:
		var is_mouse_click = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		var is_screen_touch = (event is InputEventScreenTouch and event.pressed)
		var is_action_key = (event is InputEventKey and event.pressed and (event.is_action("ui_accept") or event.is_action("ui_select")))
		
		if is_mouse_click or is_screen_touch:
			if reset_target_btn and reset_target_btn.is_visible_in_tree() and reset_target_btn.get_global_rect().has_point(event.position):
				return
		
		if is_mouse_click or is_screen_touch or is_action_key:
			_check_attack_qte_result()
			get_viewport().set_input_as_handled()
			return

	if not is_player_turn:
		return
		
	if is_parry_window_active and event.is_action_pressed("ui_accept"):
		_on_parry_button_clicked()
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


func _update_target_selection() -> void:
	enemies = enemies.filter(func(e): return is_instance_valid(e) and e.current_hp > 0)
	if enemies.size() == 0:
		return
	if selected_enemy_index >= enemies.size():
		selected_enemy_index = max(0, enemies.size() - 1)
	
	for i in range(enemies.size()):
		enemies[i].set_highlight(i == selected_enemy_index)


func _on_attack_pressed() -> void:
	if not is_player_turn or enemies.size() == 0:
		return
	if current_stamina < attack_stamina_cost:
		return
	
	is_player_turn = false
	_set_buttons_active(false)
	get_viewport().set_input_as_handled()
	_start_attack_qte()


func _on_defend_pressed() -> void:
	if not is_player_turn:
		return
	
	var shield_open_sfx: AudioStream = load("res://assets/audio/effects/battle/shield/shield_open.mp3")
	if shield_open_sfx:
		var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(sfx_player)
		sfx_player.stream = shield_open_sfx
		sfx_player.play()
		sfx_player.finished.connect(sfx_player.queue_free)
	
	is_player_turn = false
	_set_buttons_active(false)
	current_stamina = min(max_stamina, current_stamina + 20.0)
	_animate_stamina_change()
	
	is_defending = true
	_stop_hand_breathing()
	
	if hand_left_move_tween and hand_left_move_tween.is_running():
		hand_left_move_tween.kill()
		
	if hand_left:
		hand_left_move_tween = create_tween()
		hand_left_move_tween.tween_property(hand_left, "position:x", original_hand_left_pos.x + 150.0, 0.3)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	for enemy in enemies:
		if enemy.enemy_collision:
			enemy.enemy_collision.disabled = true
	
	await get_tree().create_timer(1.0).timeout
	_start_enemies_turn()


func _start_enemies_turn() -> void:
	_update_target_selection()
	
	# Process player buff durations
	if player_buff_manager:
		var expired := player_buff_manager.process_turn_start()
		if not expired.is_empty():
			_update_player_status_effects()
		# Cek apakah masih ada buff attack/defense aktif
		if current_player_buff_type != "":
			var active_types: Array[String] = player_buff_manager.get_active_buff_types()
			var still_has_buff: bool = false
			for t in active_types:
				if t == "attack_up" or t == "defense_up" or t == "generic":
					still_has_buff = true
					if t != current_player_buff_type:
						_play_player_buff_visual(t)
					break
			if not still_has_buff:
				_stop_player_buff_particles()
	
	for enemy in enemies:
		if enemy.current_hp > 0:
			_pull_hand_to_corner(0.4)
			current_enemy_attacking = enemy
			
			await enemy.take_turn(camera, default_camera_pos)
			_hide_player_hp_camera_overlay()
			
			_reset_hand_to_original(0.4)
			
			await get_tree().create_timer(0.4).timeout
			await get_tree().create_timer(0.2).timeout
	
	for enemy in enemies:
		if enemy.current_hp > 0 and enemy.enemy_collision:
			enemy.enemy_collision.disabled = false
			
	if is_defending:
		is_defending = false
		if hand_left:
			var reset_tw = create_tween()
			reset_tw.tween_property(hand_left, "position:x", original_hand_left_pos.x, 0.4)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	_update_target_selection()
	
	if enemies.size() > 0:
		is_player_turn = true
		_set_buttons_active(true)


func _set_buttons_active(show_buttons: bool, instant: bool = false) -> void:
	if atk_btn: atk_btn.disabled = (not show_buttons or current_stamina < attack_stamina_cost)
	if defend_btn: defend_btn.disabled = not show_buttons
	if backpack_btn: backpack_btn.disabled = not show_buttons
	if run_btn: run_btn.disabled = not show_buttons
	if skill_btn: skill_btn.disabled = not show_buttons
	
	var hide_offset_y: float = 200.0
	var target_atk_y: float = (original_atk_pos.y if show_buttons else original_atk_pos.y + hide_offset_y)
	var target_def_y: float = (original_def_pos.y if show_buttons else original_def_pos.y + hide_offset_y)
	var target_backpack_y: float = (original_backpack_pos.y if show_buttons else original_backpack_pos.y + hide_offset_y)
	var target_run_y: float = (original_run_post.y if show_buttons else original_run_post.y + hide_offset_y)
	var target_skill_y: float =  (original_skill_post.y if show_buttons else original_skill_post.y + hide_offset_y)
	
	if instant:
		if atk_btn: atk_btn.position.y = target_atk_y
		if defend_btn: defend_btn.position.y = target_def_y
		if backpack_btn: backpack_btn.position.y = target_backpack_y
		if run_btn: run_btn.position.y = target_run_y
		if skill_btn: skill_btn.position.y = target_skill_y
		return
	
	var trans_type = (Tween.TRANS_BACK if show_buttons else Tween.TRANS_CUBIC)
	var ease_type = (Tween.EASE_OUT if show_buttons else Tween.EASE_IN)
	
	var tw = create_tween().set_parallel(true)
	if atk_btn: tw.tween_property(atk_btn, "position:y", target_atk_y, 0.4).set_trans(trans_type).set_ease(ease_type)
	if defend_btn: tw.tween_property(defend_btn, "position:y", target_def_y, 0.4).set_trans(trans_type).set_ease(ease_type)
	if backpack_btn: tw.tween_property(backpack_btn, "position:y", target_backpack_y, 0.4).set_trans(trans_type).set_ease(ease_type)
	if run_btn: tw.tween_property(run_btn, "position:y", target_run_y, 0.4).set_trans(trans_type).set_ease(ease_type)
	if skill_btn: tw.tween_property(skill_btn, "position:y", target_skill_y, 0.4).set_trans(trans_type).set_ease(ease_type)
	
func _set_buttons_active_staggered() -> void:
	# Semua button mulai dari bawah (hidden)
	var hide_offset_y: float = 200.0
	if atk_btn: atk_btn.position.y = original_atk_pos.y + hide_offset_y
	if defend_btn: defend_btn.position.y = original_def_pos.y + hide_offset_y
	if backpack_btn: backpack_btn.position.y = original_backpack_pos.y + hide_offset_y
	if run_btn: run_btn.position.y = original_run_post.y + hide_offset_y
	if skill_btn: skill_btn.position.y = original_skill_post.y + hide_offset_y

	# Disable dulu
	if atk_btn: atk_btn.disabled = true
	if defend_btn: defend_btn.disabled = true
	if backpack_btn: backpack_btn.disabled = true
	if run_btn: run_btn.disabled = true
	if skill_btn: skill_btn.disabled = true

	# Stagger muncul satu-satu
	var btns: Array = []
	if atk_btn: btns.append(atk_btn)
	if skill_btn: btns.append(skill_btn)
	if defend_btn: btns.append(defend_btn)
	if backpack_btn: btns.append(backpack_btn)
	if run_btn: btns.append(run_btn)

	var tw := create_tween()
	for i in range(btns.size()):
		var btn = btns[i]
		var target_y: float = original_atk_pos.y if btn == atk_btn else \
			(original_def_pos.y if btn == defend_btn else \
			(original_backpack_pos.y if btn == backpack_btn else \
			(original_run_post.y if btn == run_btn else original_skill_post.y)))
		tw.parallel().tween_property(btn, "position:y", target_y, 0.35).set_delay(i * 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tw.chain().tween_callback(func():
		if atk_btn: atk_btn.disabled = (current_stamina < attack_stamina_cost)
		if defend_btn: defend_btn.disabled = false
		if backpack_btn: backpack_btn.disabled = false
		if run_btn: run_btn.disabled = false
		if skill_btn: skill_btn.disabled = false
	)

func _set_player_turn_true() -> void:
	is_player_turn = true


# ============================================================
# BATTLE INTRO — MAP TITLE ANIMATION
# ============================================================

func _play_battle_intro() -> void:
	if not map_title:
		return

	map_title.modulate.a = 0.0

	var tw := create_tween()
	tw.tween_property(map_title, "modulate:a", 1.0, 3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _animate_player_info_intro() -> void:
	if not player_info:
		return

	var orig_pos: Vector2 = player_info.position
	player_info.position.x = -player_info.size.x - 10.0

	var tw := create_tween()
	tw.tween_property(player_info, "position:x", orig_pos.x, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ============================================================
# BUTTON HOVER SCALE
# ============================================================

func _setup_button_hover_scale(btn: Button) -> void:
	if not btn:
		return
	var orig_scale: Vector2 = btn.scale
	btn.mouse_entered.connect(func():
		if btn.disabled:
			return
		var tw := create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", orig_scale * 1.06, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		var tw := create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", orig_scale, 0.15).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	)


# ============================================================
# SCOREBOARD SYSTEM
# ============================================================

func _setup_scoreboard() -> void:
	# Mulai hidden
	if scoreBoard:
		scoreBoard.visible = false
		scoreBoard.modulate.a = 0.0
	
	# Pastikan card awalnya kecil & transparan
	for card in [score_card_enemy, score_card_accuracy, score_card_parry]:
		if card:
			card.scale = Vector2(0.3, 0.3)
			card.modulate.a = 0.0
	
	# Container transparan
	for c in [score_container, score_container2, score_container3]:
		if c:
			c.modulate.a = 0.0
	
	if score_title:
		score_title.modulate.a = 0.0
	if score_continue_btn:
		score_continue_btn.modulate.a = 0.0
		score_continue_btn.pressed.connect(_on_scoreboard_continue_pressed)


func _show_scoreboard() -> void:
	if not scoreBoard:
		return
	
	# Update score text
	_update_scoreboard_values()
	
	# Disable input player
	is_player_turn = false
	_set_buttons_active(false)
	
	# Hide battle UI
	_hide_battle_ui_for_scoreboard()
	
	# Tampilkan scoreboard
	scoreBoard.visible = true
	
	var tw := create_tween()
	tw.tween_property(scoreBoard, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Container fade in
	tw.parallel().tween_property(score_container, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(score_container2, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(score_container3, "modulate:a", 1.0, 0.3)
	
	# Title fade in
	tw.parallel().tween_property(score_title, "modulate:a", 1.0, 0.35)
	
	# Cards muncul satu-satu (staggered)
	for card in [score_card_enemy, score_card_accuracy, score_card_parry]:
		if card:
			tw.tween_property(card, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(card, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.12)
	
	# Continue button muncul terakhir
	tw.tween_property(score_continue_btn, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)


func _on_scoreboard_continue_pressed() -> void:
	_hide_scoreboard()


func _hide_scoreboard() -> void:
	if not scoreBoard:
		return
	
	var tw := create_tween()
	
	# Continue button fade out dulu
	if score_continue_btn:
		tw.tween_property(score_continue_btn, "modulate:a", 0.0, 0.15)
	
	# Cards fade out
	for card in [score_card_parry, score_card_accuracy, score_card_enemy]:
		if card:
			tw.parallel().tween_property(card, "modulate:a", 0.0, 0.2)
			tw.parallel().tween_property(card, "scale", Vector2(0.5, 0.5), 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	
	# Container & title fade out
	tw.parallel().tween_property(score_container, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(score_container2, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(score_container3, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(score_title, "modulate:a", 0.0, 0.25)
	
	# Full fade out
	tw.tween_property(scoreBoard, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		scoreBoard.visible = false
		_reset_scoreboard_values()
		_show_battle_ui_after_scoreboard()
		respawn_test_enemies()
	)


func _update_scoreboard_values() -> void:
	if score_label_enemy:
		score_label_enemy.text = str(enemies_killed)
	if score_label_accuracy:
		var accuracy: int = 0
		if total_attacks > 0:
			accuracy = int(float(total_hits) / float(total_attacks) * 100.0)
		score_label_accuracy.text = str(accuracy) + "%"
	if score_label_parry:
		score_label_parry.text = str(total_parries)


func _reset_scoreboard_values() -> void:
	total_attacks = 0
	total_hits = 0
	total_parries = 0
	enemies_killed = 0


func _hide_battle_ui_for_scoreboard() -> void:
	# Hide player info
	var player_info: Control = get_node_or_null("player-information")
	if player_info:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(player_info, "modulate:a", 0.0, 0.3)
	
	# Hide interaction buttons
	var interaction: Control = get_node_or_null("interaction")
	if interaction:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(interaction, "modulate:a", 0.0, 0.3)
	
	# Hide hands
	if hand_right:
		if not has_meta("_hand_right_orig_pos"):
			set_meta("_hand_right_orig_pos", hand_right.position)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(hand_right, "modulate:a", 0.0, 0.3)
	if hand_left:
		if not has_meta("_hand_left_orig_pos"):
			set_meta("_hand_left_orig_pos", hand_left.position)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(hand_left, "modulate:a", 0.0, 0.3)


func _show_battle_ui_after_scoreboard() -> void:
	# Show player info
	var player_info: Control = get_node_or_null("player-information")
	if player_info:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(player_info, "modulate:a", 1.0, 0.3)
	
	# Show interaction
	var interaction: Control = get_node_or_null("interaction")
	if interaction:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(interaction, "modulate:a", 1.0, 0.3)
	
	# Show hands
	if hand_right:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(hand_right, "modulate:a", 1.0, 0.3)
	if hand_left:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(hand_left, "modulate:a", 1.0, 0.3)


# ============================================================
# FLEE SYSTEM — MEMORY CARD
# ============================================================

var flee_qte_layer: CanvasLayer
var flee_qte_root: Control
var flee_cards: Array = []
var flee_card_fronts: Array = []
var flee_card_backs: Array = []
var flee_card_labels: Array = []
var flee_card_is_escape: Array = []
var flee_current_chance: float = 30.0
var flee_is_choosing: bool = false
var flee_result_label: Label
var flee_chance_label: Label
var flee_title_label: Label

const FLEE_CARD_COUNT: int = 6
const FLEE_BASE_CHANCE: float = 30.0


func _on_run_pressed() -> void:
	if not is_player_turn:
		return
	if enemies.is_empty():
		return

	is_player_turn = false
	_set_buttons_active(false)
	_calculate_flee_chance()
	_show_flee_qte()


func _calculate_flee_chance() -> float:
	var base: float = FLEE_BASE_CHANCE
	var speed_bonus: float = (player_speed - 50.0) * 0.4

	var enemy_level: int = 1
	if enemies.size() > 0 and selected_enemy_index < enemies.size():
		enemy_level = enemies[selected_enemy_index].level

	var level_bonus: float = 0.0
	if PlayerDataManager.data:
		level_bonus = (PlayerDataManager.data.player_level - enemy_level) * 5.0
	flee_current_chance = clampf(base + speed_bonus + level_bonus, 10.0, 90.0)
	return flee_current_chance


func _show_flee_qte() -> void:
	# Buat CanvasLayer
	flee_qte_layer = CanvasLayer.new()
	flee_qte_layer.layer = 160
	add_child(flee_qte_layer)

	# Root
	flee_qte_root = Control.new()
	flee_qte_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	flee_qte_layer.add_child(flee_qte_root)

	# Dark overlay
	var bg_dim := ColorRect.new()
	bg_dim.color = Color(0.0, 0.0, 0.0, 0.6)
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	flee_qte_root.add_child(bg_dim)

	# Title
	flee_title_label = Label.new()
	flee_title_label.text = "ESCAPE BATTLE"
	flee_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flee_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flee_title_label.add_theme_font_size_override("font_size", 24)
	flee_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	flee_title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	flee_title_label.offset_top = 12.0
	flee_title_label.offset_bottom = 42.0
	flee_title_label.offset_left = 0.0
	flee_title_label.offset_right = 0.0
	flee_title_label.modulate.a = 0.0
	flee_qte_root.add_child(flee_title_label)

	# Flee chance label
	flee_chance_label = Label.new()
	flee_chance_label.text = "Escape Chance: " + str(int(flee_current_chance)) + "%"
	flee_chance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flee_chance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flee_chance_label.add_theme_font_size_override("font_size", 11)
	flee_chance_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	flee_chance_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	flee_chance_label.offset_top = 42.0
	flee_chance_label.offset_bottom = 60.0
	flee_chance_label.offset_left = 0.0
	flee_chance_label.offset_right = 0.0
	flee_chance_label.modulate.a = 0.0
	flee_qte_root.add_child(flee_chance_label)

	# Result label — di tengah, backdrop gelap
	flee_result_label = Label.new()
	flee_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flee_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flee_result_label.add_theme_font_size_override("font_size", 28)
	flee_result_label.z_index = 10

	var result_bg := StyleBoxFlat.new()
	result_bg.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	result_bg.set_corner_radius_all(5)
	result_bg.set_content_margin_all(16)
	flee_result_label.add_theme_stylebox_override("normal", result_bg)

	flee_result_label.set_anchors_preset(Control.PRESET_CENTER)
	flee_result_label.offset_top = -30.0
	flee_result_label.offset_bottom = 30.0
	flee_result_label.offset_left = -120.0
	flee_result_label.offset_right = 120.0
	flee_result_label.modulate.a = 0.0
	flee_qte_root.add_child(flee_result_label)

	# Card grid container (3x2, center-bawah title)
	var card_grid := GridContainer.new()
	card_grid.columns = 3
	card_grid.add_theme_constant_override("h_separation", 12)
	card_grid.add_theme_constant_override("v_separation", 12)
	card_grid.set_anchors_preset(Control.PRESET_CENTER)
	card_grid.offset_left = -140.0
	card_grid.offset_right = 140.0
	card_grid.offset_top = -90.0
	card_grid.offset_bottom = 120.0
	card_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flee_qte_root.add_child(card_grid)

	# Hitung berapa escape cards
	var escape_count: int = maxi(1, roundi(flee_current_chance / 100.0 * FLEE_CARD_COUNT))
	escape_count = mini(escape_count, FLEE_CARD_COUNT - 1) # minimal 1 card buat gagal

	# Buat array index, shuffle buat tentuin mana escape
	var card_indices: Array[int] = []
	for i in range(FLEE_CARD_COUNT):
		card_indices.append(i)
	card_indices.shuffle()

	flee_card_is_escape.clear()
	flee_card_is_escape.resize(FLEE_CARD_COUNT)
	for i in range(FLEE_CARD_COUNT):
		flee_card_is_escape[i] = false
	for i in range(escape_count):
		flee_card_is_escape[card_indices[i]] = true

	# Buat cards
	flee_cards.clear()
	flee_card_fronts.clear()
	flee_card_backs.clear()
	flee_card_labels.clear()

	for i in range(FLEE_CARD_COUNT):
		var card := _create_flee_card(i)
		card_grid.add_child(card)
		flee_cards.append(card)

	# Animasi opening
	_animate_flee_opening()

	# Cancel button di bawah card area
	var cancel_btn := Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.custom_minimum_size = Vector2(100, 28)
	cancel_btn.set_anchors_preset(Control.PRESET_CENTER)
	cancel_btn.offset_left = -50.0
	cancel_btn.offset_right = 50.0
	cancel_btn.offset_top = 135.0
	cancel_btn.offset_bottom = 163.0
	cancel_btn.add_theme_font_size_override("font_size", 11)

	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	cancel_style.set_corner_radius_all(4)
	cancel_style.set_content_margin_all(6)
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)

	var cancel_hover := StyleBoxFlat.new()
	cancel_hover.bg_color = Color(0.35, 0.35, 0.35, 0.9)
	cancel_hover.set_corner_radius_all(4)
	cancel_hover.set_content_margin_all(6)
	cancel_btn.add_theme_stylebox_override("hover", cancel_hover)

	cancel_btn.pressed.connect(_on_flee_cancel_pressed)
	flee_qte_root.add_child(cancel_btn)

	var cancel_tw := create_tween()
	cancel_tw.tween_property(cancel_btn, "modulate:a", 0.0, 0.0)
	cancel_tw.tween_property(cancel_btn, "modulate:a", 1.0, 0.3).set_delay(0.6)


func _create_flee_card(index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(85, 100)
	card.size = Vector2(85, 100)

	# Card background style
	var style_back := StyleBoxFlat.new()
	style_back.bg_color = Color(0.15, 0.1, 0.35, 1.0)
	style_back.border_color = Color(0.4, 0.3, 0.8)
	style_back.set_border_width_all(2)
	style_back.set_corner_radius_all(10)
	style_back.set_content_margin_all(0)
	card.add_theme_stylebox_override("panel", style_back)

	# Card back content (question mark)
	var back_content := VBoxContainer.new()
	back_content.alignment = BoxContainer.ALIGNMENT_CENTER
	back_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(back_content)

	var q_mark := Label.new()
	q_mark.text = "?"
	q_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q_mark.add_theme_font_size_override("font_size", 36)
	q_mark.add_theme_color_override("font_color", Color(0.6, 0.5, 1.0))
	q_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_content.add_child(q_mark)

	var sub_label := Label.new()
	sub_label.text = str(index + 1)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", 9)
	sub_label.add_theme_color_override("font_color", Color(0.4, 0.35, 0.6))
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_content.add_child(sub_label)

	flee_card_backs.append(back_content)

	# Card front content (hidden) — hijau/merah solid
	var front_panel := Panel.new()
	var is_escape: bool = flee_card_is_escape[index]

	var style_front := StyleBoxFlat.new()
	style_front.set_corner_radius_all(10)
	style_front.set_border_width_all(0)
	style_front.set_content_margin_all(0)
	if is_escape:
		style_front.bg_color = Color(0.15, 0.7, 0.3, 1.0)
	else:
		style_front.bg_color = Color(0.8, 0.15, 0.15, 1.0)
	front_panel.add_theme_stylebox_override("panel", style_front)
	front_panel.visible = false

	card.add_child(front_panel)
	flee_card_fronts.append(front_panel)
	flee_card_labels.append(q_mark)

	# Click detection
	var btn_overlay := Button.new()
	btn_overlay.flat = true
	btn_overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var transparent_style := StyleBoxFlat.new()
	transparent_style.bg_color = Color(0, 0, 0, 0)
	btn_overlay.add_theme_stylebox_override("normal", transparent_style)
	btn_overlay.add_theme_stylebox_override("hover", transparent_style)
	btn_overlay.add_theme_stylebox_override("pressed", transparent_style)
	btn_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn_overlay.pressed.connect(_on_flee_card_pressed.bind(index))
	card.add_child(btn_overlay)

	# Hover effect
	btn_overlay.mouse_entered.connect(func():
		if flee_is_choosing:
			var tw := create_tween().set_parallel(true)
			tw.tween_property(card, "scale", Vector2(1.08, 1.08), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	btn_overlay.mouse_exited.connect(func():
		if flee_is_choosing:
			var tw := create_tween().set_parallel(true)
			tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	)

	return card


func _animate_flee_opening() -> void:
	var tw := create_tween()

	# Title fade in
	tw.tween_property(flee_title_label, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(flee_chance_label, "modulate:a", 1.0, 0.25)

	# Cards muncul satu-satu dengan bounce (cepet)
	for card in flee_cards:
		card.scale = Vector2(0.0, 0.0)
		card.modulate.a = 0.0
		card.pivot_offset = card.custom_minimum_size / 2.0

	for card in flee_cards:
		tw.parallel().tween_property(card, "modulate:a", 1.0, 0.12)
		tw.parallel().tween_property(card, "scale", Vector2(1.12, 1.12), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_interval(0.04)

	# Setelah semua cards muncul, aktifkan choosing
	tw.tween_callback(func():
		flee_is_choosing = true
	)


func _on_flee_cancel_pressed() -> void:
	flee_is_choosing = false
	# Fade out lalu cleanup
	if flee_qte_root:
		var tw := create_tween()
		tw.tween_property(flee_qte_root, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(_cleanup_flee_qte)
		tw.tween_callback(func():
			is_player_turn = true
			_set_buttons_active(true)
		)

func _on_flee_card_pressed(index: int) -> void:
	if not flee_is_choosing:
		return
	flee_is_choosing = false

	var is_escape: bool = flee_card_is_escape[index]
	var chosen_card: PanelContainer = flee_cards[index]

	# FLIP ANIMATION
	var tw := create_tween()

	# 1. Card dipilih squeeze horizontal
	tw.tween_property(chosen_card, "scale", Vector2(0.05, 1.1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	# 2. Swap front/back
	tw.tween_callback(func():
		flee_card_backs[index].visible = false
		flee_card_fronts[index].visible = true
	)

	# 3. Card kembalikan scale
	tw.tween_property(chosen_card, "scale", Vector2(1.05, 1.05), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(chosen_card, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 4. Card lain fade out + scale down
	var other_delay: float = 0.0
	for i in range(FLEE_CARD_COUNT):
		if i != index:
			var other_card: PanelContainer = flee_cards[i]
			tw.parallel().tween_property(other_card, "modulate:a", 0.0, 0.15 + other_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(other_card, "scale", Vector2(0.6, 0.6), 0.15 + other_delay).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
			other_delay += 0.03

	# 5. Tampilkan result
	if is_escape:
		# Glow effect hijau
		tw.tween_callback(func():
			chosen_card.get_theme_stylebox("panel").border_color = Color(0.5, 1.0, 0.7)
		)
		tw.tween_property(chosen_card, "scale", Vector2(1.15, 1.15), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(chosen_card, "scale", Vector2(1.0, 1.0), 0.15)
		tw.tween_interval(0.4)
		tw.tween_callback(_on_flee_success)
	else:
		# Shake effect merah
		tw.tween_callback(func():
			chosen_card.get_theme_stylebox("panel").border_color = Color(1.0, 0.5, 0.3)
		)
		var orig_x: float = chosen_card.position.x
		for s in range(3):
			tw.tween_property(chosen_card, "position:x", orig_x + 8.0, 0.04)
			tw.tween_property(chosen_card, "position:x", orig_x - 8.0, 0.04)
		tw.tween_property(chosen_card, "position:x", orig_x, 0.04)
		tw.tween_interval(0.3)
		tw.tween_callback(_on_flee_failure)


func _on_flee_success() -> void:
	# Tampilkan "You Escaped!"
	flee_result_label.text = "You Escaped!"
	flee_result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))

	# Screen shake velocity
	if camera:
		var shake_tw := create_tween()
		shake_tw.tween_property(camera, "offset", Vector2(4, 3), 0.04)
		shake_tw.tween_property(camera, "offset", Vector2(-3, -4), 0.04)
		shake_tw.tween_property(camera, "offset", Vector2(3, 2), 0.04)
		shake_tw.tween_property(camera, "offset", Vector2(-2, -3), 0.04)
		shake_tw.tween_property(camera, "offset", Vector2.ZERO, 0.04)

	var tw := create_tween()
	# Muncul dengan velocity
	flee_result_label.modulate.a = 0.0
	flee_result_label.scale = Vector2(1.5, 1.5)
	tw.tween_property(flee_result_label, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(flee_result_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)

	# Fade out semua
	tw.tween_property(flee_qte_root, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(_cleanup_flee_qte)
	tw.tween_callback(func():
		respawn_test_enemies()
	)


func _on_flee_failure() -> void:
	# Tampilkan "Caught!" dengan velocity
	flee_result_label.text = "Caught!"
	flee_result_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

	# Screen shake velocity
	if camera:
		var shake_tw := create_tween()
		shake_tw.tween_property(camera, "offset", Vector2(4, 3), 0.04)
		shake_tw.tween_property(camera, "offset", Vector2(-3, -4), 0.04)
		shake_tw.tween_property(camera, "offset", Vector2(3, 2), 0.04)
		shake_tw.tween_property(camera, "offset", Vector2(-2, -3), 0.04)
		shake_tw.tween_property(camera, "offset", Vector2.ZERO, 0.04)

	var tw := create_tween()
	# Muncul dengan velocity
	flee_result_label.modulate.a = 0.0
	flee_result_label.scale = Vector2(1.5, 1.5)
	tw.tween_property(flee_result_label, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(flee_result_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.8)

	# Fade out semua
	tw.tween_property(flee_qte_root, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(_cleanup_flee_qte)
	tw.tween_callback(func():
		# Langsung enemy turn (player turn skipped)
		_start_enemies_turn()
	)


func _cleanup_flee_qte() -> void:
	if flee_qte_layer and is_instance_valid(flee_qte_layer):
		flee_qte_layer.queue_free()
	flee_qte_layer = null
	flee_qte_root = null
	flee_cards.clear()
	flee_card_fronts.clear()
	flee_card_backs.clear()
	flee_card_labels.clear()
	flee_card_is_escape.clear()
