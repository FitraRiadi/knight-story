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

var enemy_scene: PackedScene
@export_dir var enemy_resources_folder: String = "res://data/enemies/"

# --- STATISTIK PLAYER ---
var max_hp: float = 500.0
var current_hp: float = 500.0

var max_stamina: float = 200.0
var current_stamina: float = 200.0
var attack_stamina_cost: float = 15.0

var max_morale: float = 200.0
var current_morale: float = 100.0

var player_damage: float = 80.0
var player_crit_damage: float = 50.0
var player_critical_chance: float = 50.0
var player_hit_rate: float = 100.0
var defense_flat_reduction: float = 20.0 
var parry_flat_reduction: float = 10.0 

var is_defending: bool = false

var max_hp_bar_width: float = 0.0
var max_stamina_bar_width: float = 0.0
var max_morale_bar_width: float = 0.0
var max_enemy_hp_bar_width: float = 0.0

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
var player_hp_overlay_visual_hp: float = 500.0

var player_hp_overlay_tween: Tween
var player_hp_overlay_show_tween: Tween
var player_hp_overlay_hide_tween: Tween
var player_hp_overlay_visible: bool = false

# BATTLE INVENTORY SYSTEM
var battle_inventory_scene: PackedScene = preload("res://scenes/battle/battle_inventory.tscn")
var battle_inventory_instance: Control = null
var inventory_canvas_layer: CanvasLayer
var is_inventory_open: bool = false


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
	
	if camera: default_camera_pos = camera.global_position
	if hp_bar: max_hp_bar_width = hp_bar.size.x
	if stamina_bar: max_stamina_bar_width = stamina_bar.size.x
	if morale_bar: max_morale_bar_width = morale_bar.size.x
		
	_setup_blood_vignette()
	_setup_player_hp_camera_overlay()
	_update_player_ui_instant()
	
	if atk_btn: atk_btn.pressed.connect(_on_attack_pressed)
	if defend_btn: defend_btn.pressed.connect(_on_defend_pressed)
	if backpack_btn: backpack_btn.pressed.connect(_on_backpack_pressed)
	if reset_target_btn and not reset_target_btn.pressed.is_connected(_on_reset_target_pressed):
		reset_target_btn.pressed.connect(_on_reset_target_pressed)
		
	_auto_detect_enemy_pool()
	spawn_random_enemies(1, 3, 1, 5)


# ============================================================
# SETUP BATTLE INVENTORY
# ============================================================
func _setup_battle_inventory_layer() -> void:
	inventory_canvas_layer = CanvasLayer.new()
	inventory_canvas_layer.layer = 160
	add_child(inventory_canvas_layer)


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

	# Terapkan Efek Item
	if item:
		if "heal_value" in item and item.heal_value > 0.0:
			current_hp = min(max_hp, current_hp + item.heal_value)
			_animate_hp_change()
		
		if "attack_bonus" in item and item.attack_bonus > 0.0:
			current_stamina = min(max_stamina, current_stamina + item.attack_bonus)
			_animate_stamina_change()

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
	
	var container_width = attack_bar_container.size.x
	
	if attack_bar_low:
		var low_max_x = max(0.0, container_width - attack_bar_low.size.x)
		attack_bar_low.position.x = randf_range(0.0, low_max_x)
		
	if attack_bar_mid:
		var mid_max_x = max(0.0, container_width - attack_bar_mid.size.x)
		if attack_bar_low:
			var center_low = attack_bar_low.position.x + (attack_bar_low.size.x * 0.5)
			attack_bar_mid.position.x = clampf(center_low - (attack_bar_mid.size.x * 0.5), 0.0, mid_max_x)
		else:
			attack_bar_mid.position.x = randf_range(0.0, mid_max_x)
			
	if attack_bar_success:
		var success_max_x = max(0.0, container_width - attack_bar_success.size.x)
		if attack_bar_mid:
			var center_mid = attack_bar_mid.position.x + (attack_bar_mid.size.x * 0.5)
			attack_bar_success.position.x = clampf(center_mid - (attack_bar_success.size.x * 0.5), 0.0, success_max_x)
		else:
			attack_bar_success.position.x = randf_range(0.0, success_max_x)
	
	var running_width = attack_bar_running.size.x
	var run_min_x = 0.0
	var run_max_x = max(0.0, container_width - running_width)
	
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
	
	if camera:
		var cam_reset_tw = create_tween().set_parallel(true)
		cam_reset_tw.tween_property(camera, "zoom", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN_OUT)
		cam_reset_tw.tween_property(camera, "global_position", default_camera_pos, 0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN_OUT)
		cam_reset_tw.set_ignore_time_scale(true)
	
	var qte_result: AttackResult = AttackResult.MISS
	
	if _check_is_overlapping(attack_bar_running, attack_bar_success):
		qte_result = AttackResult.CRITICAL
	elif _check_is_overlapping(attack_bar_running, attack_bar_mid):
		qte_result = AttackResult.MID
	elif _check_is_overlapping(attack_bar_running, attack_bar_low):
		qte_result = AttackResult.LOW
	
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
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	
	if attack_qte_canvas_layer:
		attack_qte_canvas_layer.add_child(label)
	else:
		add_child(label)
		
	var viewport_size = get_viewport().get_visible_rect().size
	label.reset_size()
	var actual_size = label.get_combined_minimum_size()
	label.pivot_offset = actual_size * 0.5
	
	var top_y = 40.0
	var center_x = (viewport_size.x * 0.5) - (actual_size.x * 0.5)
	
	label.position = Vector2(center_x, top_y)
	label.scale = Vector2(0.2, 0.2)
	label.modulate.a = 0.0
	
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "scale", Vector2(1.15, 1.15), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 1.0, 0.12)
	
	tw.chain().set_parallel(false)
	tw.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(3.5)
	
	tw.chain().set_parallel(true)
	tw.tween_property(label, "position:y", top_y - 20.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	tw.chain().tween_callback(label.queue_free)


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
	
	match result:
		AttackResult.MISS:
			target_enemy.receive_damage(0.0, false, true)
		AttackResult.LOW:
			var low_damage = player_damage * 0.4
			target_enemy.receive_damage(low_damage, false, false)
		AttackResult.MID:
			var mid_damage = player_damage
			target_enemy.receive_damage(mid_damage, false, false)
		AttackResult.CRITICAL:
			var crit_damage = player_damage + player_crit_damage
			target_enemy.receive_damage(crit_damage, true, false)
	
	await get_tree().create_timer(0.8).timeout
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
	player_hp_overlay_label.text = "500 / 500"
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
		
		enemies.append(enemy_instance)
		
		enemy_instance.clicked.connect(_on_enemy_clicked)
		enemy_instance.attack_hit.connect(player_receive_damage_custom)
		enemy_instance.attack_preparing.connect(_on_enemy_attack_preparing)
		enemy_instance.enemy_defeated.connect(_on_enemy_defeated)
		
	_position_enemies(total_enemies)
	_update_target_selection()


func spawn_custom_enemies(enemy_ids: Array[String], levels: Array[int] = []) -> void:
	_spawn_enemies(enemy_ids, levels)


func spawn_random_enemies(min_count: int = 1, max_count: int = 3, min_level: int = 1, max_level: int = 5) -> void:
	if available_enemy_pool.is_empty():
		return
	
	var count: int = randi_range(clampi(min_count, 1, 3), clampi(max_count, 1, 3))
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


func player_receive_damage_custom(amount: float) -> void:
	_hide_parry_window()
	
	var final_damage = amount
	if parry_success_this_turn and is_defending:
		final_damage = max(0.0, amount - (parry_flat_reduction + parry_extra_reduction + (defense_flat_reduction * 0.9)))
	elif parry_success_this_turn:
		final_damage = max(0.0, amount - (parry_flat_reduction + parry_extra_reduction))
	elif is_defending:
		final_damage = max(0.0, amount - defense_flat_reduction)
	
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


func _on_enemy_defeated(_exp_amount: int, _gold_amount: int, _dropped_items: Array[String]) -> void:
	await get_tree().create_timer(1.0).timeout
	_update_target_selection()
	
	if enemies.is_empty():
		await get_tree().create_timer(0.5).timeout
		respawn_test_enemies()


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
	
	for enemy in enemies:
		if enemy.current_hp > 0:
			_pull_hand_to_corner(0.4)
			
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


func _set_buttons_active(show_buttons: bool) -> void:
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
	
	var trans_type = (Tween.TRANS_BACK if show_buttons else Tween.TRANS_CUBIC)
	var ease_type = (Tween.EASE_OUT if show_buttons else Tween.EASE_IN)
	
	var tw = create_tween().set_parallel(true)
	if atk_btn: tw.tween_property(atk_btn, "position:y", target_atk_y, 0.4).set_trans(trans_type).set_ease(ease_type)
	if defend_btn: tw.tween_property(defend_btn, "position:y", target_def_y, 0.4).set_trans(trans_type).set_ease(ease_type)
	if backpack_btn: tw.tween_property(backpack_btn, "position:y", target_backpack_y, 0.4).set_trans(trans_type).set_ease(ease_type)
	if run_btn: tw.tween_property(run_btn, "position:y", target_run_y, 0.4).set_trans(trans_type).set_ease(ease_type)
	if skill_btn: tw.tween_property(skill_btn, "position:y", target_skill_y, 0.4).set_trans(trans_type).set_ease(ease_type)
	
func _set_player_turn_true() -> void:
	is_player_turn = true
