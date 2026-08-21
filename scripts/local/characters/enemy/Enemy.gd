extends AnimatedSprite2D
class_name BattleEnemy

# ============================================================
# SIGNAL
# ============================================================
signal action_finished
signal clicked(enemy: BattleEnemy)
signal attack_preparing
signal attack_hit(damage_amount: float)
signal hp_changed

signal enemy_defeated(
	exp_amount: int,
	gold_amount: int,
	dropped_items: Array[String]
)

# ============================================================
# BASIC DATA
# ============================================================
@export var enemy_id: String = ""
@export var level: int = 1
@export var stats: EnemyData

var enemy_ai: EnemyAI

# ============================================================
# HP & SCALED STATS
# ============================================================
var current_hp: float = 100.0
var max_hp_bar_width: float = 0.0

var scaled_max_hp: float = 100.0
var scaled_damage: float = 15.0
var scaled_defense: float = 0.0
var scaled_exp: int = 20
var scaled_gold: int = 10

var enemy_inventory: Array[ItemData] = []

# ============================================================
# NODES & PARTICLES
# ============================================================
@onready var enemy_name_label: Label = $"enemyStats/name"
@onready var enemy_level_label: Label = $"enemyStats/level"
@onready var bar_hp_progress: Panel = $"enemyStats/bar-hp/bar-hp-progress"
@onready var enemy_target: TextureRect = $enemyTarget
@onready var enemy_collision: TextureButton = $enemyCollision
@onready var enemy_hit_icon: TextureRect = $enemyHitIcon
@onready var label_template: Label = $Label

var blood_particles: CPUParticles2D
var soul_particles: CPUParticles2D

var is_selected: bool = false
var base_target_y: float = 0.0
var original_z_index: int = 0
var is_taking_turn: bool = false
var base_hit_icon_y: float = 0.0
var last_spawn_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	enemy_ai = EnemyAI.new()

	if enemy_id != "" and stats == null:
		setup_enemy(enemy_id)
	elif stats == null:
		current_hp = 100.0

	original_z_index = z_index

	if bar_hp_progress:
		max_hp_bar_width = bar_hp_progress.size.x
		_update_hp_bar()

	_setup_blood_particles()
	_setup_soul_particles()

	if enemy_hit_icon:
		enemy_hit_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		base_hit_icon_y = enemy_hit_icon.position.y
		enemy_hit_icon.hide()
		enemy_hit_icon.modulate.a = 0.0

	if enemy_target:
		enemy_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
		base_target_y = enemy_target.position.y
		enemy_target.hide()

	if has_node("enemyStats"):
		$enemyStats.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if label_template:
		label_template.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label_template.hide()

	if enemy_collision:
		enemy_collision.disabled = false
		enemy_collision.mouse_filter = Control.MOUSE_FILTER_STOP
		if not enemy_collision.pressed.is_connected(_on_enemy_button_pressed):
			enemy_collision.pressed.connect(_on_enemy_button_pressed)
		if not enemy_collision.gui_input.is_connected(_on_enemy_collision_gui_input):
			enemy_collision.gui_input.connect(_on_enemy_collision_gui_input)

	play("idle")


func setup_enemy(new_id: String, custom_level: int = 0) -> void:
	enemy_id = new_id
	stats = EnemyDatabase.get_enemy_data(enemy_id)

	if stats != null:
		level = custom_level if custom_level > 0 else stats.min_level
		var scaled: Dictionary = stats.get_scaled_stats(level)

		scaled_max_hp = float(scaled.get("max_hp", 100.0))
		scaled_damage = float(scaled.get("damage", 15.0))
		scaled_defense = float(scaled.get("defense", 0.0))
		scaled_exp = int(scaled.get("exp", 20))
		scaled_gold = int(scaled.get("gold", 10))

		current_hp = scaled_max_hp
		enemy_inventory = stats.starting_inventory.duplicate()

		if enemy_name_label:
			enemy_name_label.text = stats.enemy_name
		if enemy_level_label:
			enemy_level_label.text = "Lv. " + str(level)
		if stats.sprite_frames:
			sprite_frames = stats.sprite_frames
		scale = stats.sprite_scale
	else:
		current_hp = 100.0
		scaled_max_hp = 100.0
		scaled_damage = 15.0
		scaled_defense = 0.0
		scaled_exp = 20
		scaled_gold = 10

	if enemy_ai:
		enemy_ai.reset_memory()

	if bar_hp_progress:
		max_hp_bar_width = bar_hp_progress.size.x
		_update_hp_bar()

	play("idle")


func take_turn(camera: Camera2D, default_camera_pos: Vector2) -> void:
	if current_hp <= 0.0:
		action_finished.emit()
		return

	is_taking_turn = true
	z_index = 100

	if enemy_target:
		enemy_target.hide()
	if enemy_collision:
		enemy_collision.disabled = true

	var chosen_action: EnemyAI.Action = enemy_ai.decide_action(
		stats, current_hp, scaled_max_hp, enemy_inventory
	)

	match chosen_action:
		EnemyAI.Action.ATTACK:
			await _execute_attack(camera, default_camera_pos, 1.0)
		EnemyAI.Action.HEAVY_ATTACK:
			await _execute_attack(camera, default_camera_pos, 1.5, "Crit Attack!")
		EnemyAI.Action.DEFEND:
			await _execute_defend(camera, default_camera_pos)
		EnemyAI.Action.HEAL:
			await _execute_heal(camera, default_camera_pos)

	if current_hp > 0.0 and enemy_collision:
		enemy_collision.disabled = false

	is_taking_turn = false
	z_index = original_z_index
	action_finished.emit()


func _execute_attack(camera: Camera2D, default_camera_pos: Vector2, damage_multiplier: float = 1.0, text_override: String = "Attacking!") -> void:
	var dmg: float = scaled_damage * damage_multiplier
	attack_preparing.emit()

	if camera:
		_focus_camera_to_me(camera, true)

	show_reaction_text(text_override, Color(1.0, 0.0, 0.0), damage_multiplier > 1.0)
	play("attack")
	await animation_finished

	attack_hit.emit(dmg)

	if camera:
		_shake_camera(camera, 12.0 * damage_multiplier, 0.25)

	await get_tree().create_timer(0.6).timeout

	if camera:
		_reset_camera_focus(camera, default_camera_pos)

	if current_hp > 0.0:
		play("idle")


func _execute_defend(camera: Camera2D, default_camera_pos: Vector2) -> void:
	if camera:
		_focus_camera_to_me(camera, true)

	show_reaction_text("Defending!", Color(0.3, 0.8, 1.0))
	play("defend")

	await get_tree().create_timer(1.2).timeout

	if camera:
		_reset_camera_focus(camera, default_camera_pos)

	if current_hp > 0.0:
		play("idle")


func _execute_heal(camera: Camera2D, default_camera_pos: Vector2) -> void:
	var potion_to_use: ItemData = null
	var potion_index: int = -1

	for i: int in range(enemy_inventory.size()):
		var item: ItemData = enemy_inventory[i]
		if item != null and item.item_id.to_lower().contains("potion"):
			potion_to_use = item
			potion_index = i
			break

	if potion_to_use == null:
		await _execute_attack(camera, default_camera_pos, 1.0, "Out of Potions!")
		return

	if camera:
		_focus_camera_to_me(camera, true)

	enemy_inventory.remove_at(potion_index)
	_show_item_pop_icon(potion_to_use)

	var heal_val: float = float(potion_to_use.heal_value)
	current_hp = minf(scaled_max_hp, current_hp + heal_val)
	
	_update_hp_bar()
	hp_changed.emit()

	show_reaction_text("Used " + potion_to_use.item_name + " (+" + str(int(heal_val)) + ")", Color(0.2, 1.0, 0.3), true)

	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.5, 1.5, 0.5, 1.0), 0.3)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)

	await get_tree().create_timer(1.6).timeout

	if camera:
		_reset_camera_focus(camera, default_camera_pos)

	if current_hp > 0.0:
		play("idle")


func _get_inventory_names() -> Array[String]:
	var names: Array[String] = []
	for item: ItemData in enemy_inventory:
		if item != null:
			names.append(item.item_name)
	return names


func _on_death() -> void:
	if enemy_target:
		enemy_target.hide()
	if enemy_hit_icon:
		enemy_hit_icon.hide()
	if enemy_collision:
		enemy_collision.disabled = true

	play("death")

	if soul_particles:
		soul_particles.emitting = true

	var dropped_items: Array[String] = []
	var exp_gained: int = scaled_exp
	var gold_gained: int = scaled_gold

	if stats != null and randf() <= stats.drop_chance and stats.drop_table.size() > 0:
		var random_item: String = str(stats.drop_table.pick_random())
		dropped_items.append(random_item)

	enemy_defeated.emit(exp_gained, gold_gained, dropped_items)

	await get_tree().create_timer(0.8).timeout
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)


func receive_damage(amount: float, is_critical: bool = false, is_dodge: bool = false) -> void:
	if is_dodge:
		show_reaction_text("DODGE", Color(0.7, 0.7, 0.7), false)
		return

	var final_damage: float = maxf(1.0, amount - scaled_defense)
	current_hp = maxf(0.0, current_hp - final_damage)

	_update_hp_bar()
	hp_changed.emit()

	_trigger_blood_splash()

	if is_critical:
		show_reaction_text("Crit " + str(int(final_damage)), Color(1.0, 1.0, 0.0), true)
	else:
		show_reaction_text(str(int(final_damage)), Color(1.0, 1.0, 1.0), false)

	if enemy_hit_icon:
		enemy_hit_icon.show()
		enemy_hit_icon.modulate.a = 1.0
		enemy_hit_icon.pivot_offset = Vector2(enemy_hit_icon.size.x / 2.0, enemy_hit_icon.size.y)
		enemy_hit_icon.position.y = base_hit_icon_y
		enemy_hit_icon.rotation = deg_to_rad(-35.0)

		var hit_tween: Tween = create_tween()
		hit_tween.tween_property(enemy_hit_icon, "rotation", deg_to_rad(15.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		hit_tween.tween_interval(0.15)
		hit_tween.tween_property(enemy_hit_icon, "rotation", deg_to_rad(-15.0), 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		hit_tween.tween_property(enemy_hit_icon, "rotation", deg_to_rad(20.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		hit_tween.tween_interval(0.15)
		hit_tween.tween_property(enemy_hit_icon, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if current_hp <= 0.0:
		_on_death()
	else:
		play("hurt")


func _update_hp_bar() -> void:
	if not bar_hp_progress or scaled_max_hp <= 0.0:
		return

	var hp_ratio: float = clampf(current_hp / scaled_max_hp, 0.0, 1.0)
	var target_width: float = hp_ratio * max_hp_bar_width

	var tween: Tween = create_tween()
	tween.tween_property(bar_hp_progress, "size:x", target_width, 0.4)


func _on_enemy_collision_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_select_enemy()


func _on_enemy_button_pressed() -> void:
	_try_select_enemy()


func _try_select_enemy() -> void:
	if is_taking_turn:
		return
	if current_hp > 0.0:
		clicked.emit(self)


func show_reaction_text(text: String, text_color: Color = Color.WHITE, is_crit: bool = false) -> void:
	if not label_template:
		return

	var duplicated_node: Node = label_template.duplicate()
	var new_label: Label = duplicated_node as Label
	if new_label == null:
		return

	add_child(new_label)
	new_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	new_label.text = text
	new_label.modulate = text_color
	new_label.show()
	new_label.pivot_offset = (new_label.size / 2.0)

	var random_offset: Vector2 = Vector2(randf_range(-35.0, 35.0), randf_range(-15.0, 15.0))
	if random_offset.distance_to(last_spawn_offset) < 20.0:
		random_offset.x += 25.0 * (1.0 if random_offset.x >= 0.0 else -1.0)

	last_spawn_offset = random_offset
	var start_pos: Vector2 = -(new_label.size / 2.0) + random_offset
	new_label.position = start_pos

	var target_scale: Vector2 = Vector2(1.15, 1.15) if is_crit else Vector2.ONE
	new_label.scale = Vector2(0.2, 0.2)

	var tween: Tween = create_tween().set_parallel(true)
	var pop_tween: Tween = create_tween()

	pop_tween.tween_property(new_label, "scale", target_scale * 1.2, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(new_label, "scale", target_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(new_label, "position:y", start_pos.y - 45.0, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(new_label, "modulate:a", 0.0, 0.45).set_delay(0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.finished.connect(func() -> void:
		if is_instance_valid(new_label):
			new_label.queue_free()
	)


func set_highlight(active: bool) -> void:
	is_selected = active
	var target_alpha: float = 1.0 if active else 0.4
	var target_color: Color = Color(1.3, 1.3, 1.3, 1.0) if active else Color.WHITE

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", target_alpha, 0.2)
	tween.tween_property(self, "modulate", target_color, 0.2)

	if enemy_target:
		enemy_target.visible = active
		if active:
			_animate_target_icon()


func _animate_target_icon() -> void:
	if not enemy_target or not is_selected:
		return

	var tween: Tween = create_tween().set_loops()
	tween.tween_property(enemy_target, "position:y", base_target_y - 8.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(enemy_target, "position:y", base_target_y, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _focus_camera_to_me(camera: Camera2D, zoom_in: bool) -> void:
	var target_zoom: Vector2 = Vector2(1.45, 1.45) if zoom_in else Vector2.ONE
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_width: float = viewport_size.x / target_zoom.x * 0.5
	var half_height: float = viewport_size.y / target_zoom.y * 0.5

	var clamped_x: float = clampf(global_position.x, half_width, viewport_size.x - half_width)
	var clamped_y: float = clampf(global_position.y, half_height, viewport_size.y - half_height)
	var target_pos: Vector2 = Vector2(clamped_x, clamped_y)

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(camera, "global_position", target_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "zoom", target_zoom, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _reset_camera_focus(camera: Camera2D, default_pos: Vector2) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(camera, "global_position", default_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "zoom", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _show_item_pop_icon(item_data: ItemData) -> void:
	if item_data == null:
		return

	var texture_to_show: Texture2D = null
	if item_data.icon != null:
		texture_to_show = item_data.icon
	elif item_data.item_texture != null:
		texture_to_show = item_data.item_texture
	elif item_data.icon_texture != null:
		texture_to_show = item_data.icon_texture

	if texture_to_show == null:
		return

	var icon_rect: TextureRect = TextureRect.new()
	add_child(icon_rect)
	icon_rect.texture = texture_to_show
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(36.0, 36.0)
	icon_rect.size = Vector2(36.0, 36.0)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.pivot_offset = icon_rect.size / 2.0

	var start_pos: Vector2 = Vector2(-icon_rect.size.x / 2.0, -65.0)
	icon_rect.position = start_pos
	icon_rect.scale = Vector2(0.1, 0.1)
	icon_rect.modulate.a = 1.0

	var sway_tween: Tween = create_tween().set_loops(6)
	sway_tween.tween_property(icon_rect, "rotation", deg_to_rad(18.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway_tween.tween_property(icon_rect, "rotation", deg_to_rad(-18.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var main_tween: Tween = create_tween().set_parallel(true)
	main_tween.tween_property(icon_rect, "scale", Vector2(1.3, 1.3), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	main_tween.chain().tween_property(icon_rect, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	main_tween.tween_property(icon_rect, "position:y", start_pos.y - 55.0, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	main_tween.tween_property(icon_rect, "modulate:a", 0.0, 0.8).set_delay(1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	main_tween.finished.connect(func() -> void:
		if is_instance_valid(sway_tween):
			sway_tween.kill()
		if is_instance_valid(icon_rect):
			icon_rect.queue_free()
	)


func _setup_blood_particles() -> void:
	blood_particles = CPUParticles2D.new()
	add_child(blood_particles)
	blood_particles.z_index = 50
	blood_particles.amount = 25
	blood_particles.lifetime = 0.35
	blood_particles.one_shot = true
	blood_particles.explosiveness = 1.0
	blood_particles.emitting = false
	blood_particles.direction = Vector2(0, -1)
	blood_particles.spread = 90.0
	blood_particles.gravity = Vector2(0, 800)
	blood_particles.initial_velocity_min = 120.0
	blood_particles.initial_velocity_max = 240.0
	blood_particles.scale_amount_min = 2.0
	blood_particles.scale_amount_max = 4.5
	blood_particles.color = Color(0.9, 0.0, 0.0, 1.0)


func _setup_soul_particles() -> void:
	soul_particles = CPUParticles2D.new()
	add_child(soul_particles)
	soul_particles.z_index = 50
	soul_particles.amount = 35
	soul_particles.lifetime = 1.2
	soul_particles.one_shot = false
	soul_particles.emitting = false
	soul_particles.direction = Vector2(0, -1)
	soul_particles.spread = 45.0
	soul_particles.gravity = Vector2(0, -150)
	soul_particles.initial_velocity_min = 40.0
	soul_particles.initial_velocity_max = 90.0
	soul_particles.scale_amount_min = 2.0
	soul_particles.scale_amount_max = 5.0
	soul_particles.color = Color(0.4, 0.8, 1.0, 0.8)


func _trigger_blood_splash() -> void:
	if blood_particles:
		blood_particles.restart()


func _shake_camera(camera: Camera2D, intensity: float, duration: float) -> void:
	var parent_control: Node = get_parent()
	if parent_control and parent_control.has_method("trigger_camera_shake_and_blood"):
		parent_control.trigger_camera_shake_and_blood(intensity, duration, 0.8)
	else:
		var original_offset: Vector2 = camera.offset
		var tween: Tween = create_tween()
		for i: int in range(6):
			var offset: Vector2 = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
			tween.tween_property(camera, "offset", offset, duration / 6.0)
		tween.tween_property(camera, "offset", original_offset, 0.05)
