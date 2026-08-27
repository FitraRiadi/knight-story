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
signal sound_requested(sound_name: String)

signal enemy_defeated(
	exp_amount: int,
	gold_amount: int,
	dropped_items: Array[String],
	enemy: BattleEnemy
)


# ============================================================
# SOUND EFFECT DEFAULT (FALLBACK)
# ============================================================

const DEFAULT_SFX_DEATH = preload("res://assets/audio/effects/enemies/death-base.mp3")
const DEFAULT_ATTACK = preload("res://assets/audio/effects/enemies/attack-base.mp3")
const DEFAULT_SFX_HIT = preload("res://assets/audio/effects/enemies/hit-base.mp3")
const SFX_USE_ITEM = preload("uid://d3jo784jvhvnu")


# ============================================================
# STATUS EFFECT ICONS DICTIONARY
# ============================================================

const STATUS_ICONS: Dictionary = {
	"attack_up": preload("res://assets/ui/icons/statusEffect/attackUp.png"),
	"health_up": preload("res://assets/ui/icons/statusEffect/healthUp.png"),
	"poison": preload("res://assets/ui/icons/statusEffect/poison.png"),
	"stun": preload("res://assets/ui/icons/statusEffect/stun.png")
}


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


# ============================================================
# ITEM INVENTORY & BUFF MANAGER
# ============================================================

var enemy_inventory: Array[ItemData] = []
var buff_manager: BuffManager = BuffManager.new()
const BuffManagerConst = preload("uid://bwa4caym3ruqt") 


# ============================================================
# COMBAT MODIFIERS
# ============================================================

var shield_value: float = 0.0


# ============================================================
# DEFEND STATE
# ============================================================

var is_defending: bool = false
var is_defense_animation_locked: bool = false

const DEFEND_DAMAGE_REDUCTION: float = 0.40


# ============================================================
# NODES & AUDIO
# ============================================================

@onready var enemy_name_label: Label = $"enemyStats/name"
@onready var enemy_level_label: Label = $"enemyStats/level"

@onready var bar_hp_progress: Panel = (
	$"enemyStats/bar-hp/bar-hp-progress"
)
@onready var enemy_hp_label: Label = $"enemyStats/bar-hp/hp-label"
@onready var enemy_effect_container: Control = $"enemyStats/enemyEffect"

# Node TextureRect Profile Enemy
@onready var enemy_profile_img: TextureRect = $"enemyStats/profile/img"

@onready var enemy_target: TextureRect = $enemyTarget
@onready var enemy_collision: TextureButton = $enemyCollision
@onready var enemy_hit_icon: TextureRect = $enemyHitIcon
@onready var label_template: Label = $Label

var audio_player: AudioStreamPlayer = null
var effect_center_position: Vector2 = Vector2.ZERO


# ============================================================
# PARTICLES
# ============================================================

var blood_particles: CPUParticles2D
var soul_particles: CPUParticles2D


# ============================================================
# STATE
# ============================================================

var is_selected: bool = false
var base_target_y: float = 0.0
var original_z_index: int = 0
var is_taking_turn: bool = false
var base_hit_icon_y: float = 0.0
var last_spawn_offset: Vector2 = Vector2.ZERO


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	enemy_ai = EnemyAI.new()

	if not is_instance_valid(audio_player):
		audio_player = AudioStreamPlayer.new()
		add_child(audio_player)

	if enemy_id != "" and stats == null:
		setup_enemy(enemy_id)
	elif stats == null:
		current_hp = 100.0
		_update_profile_icon()

	original_z_index = z_index

	if bar_hp_progress:
		max_hp_bar_width = bar_hp_progress.size.x
		_update_hp_bar()

	if enemy_effect_container and enemy_effect_container.has_node("effect"):
		var effect_node: Control = enemy_effect_container.get_node("effect") as Control
		if effect_node:
			effect_center_position = effect_node.position + (effect_node.size / 2.0)
			effect_node.hide()

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

	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)

	_update_status_effects()
	_play_idle_if_allowed()


func _on_animation_finished() -> void:
	if animation == &"hurt":
		_play_idle_if_allowed()


# ============================================================
# HELPER SOUND WITH FALLBACK LOGIC
# ============================================================

func _play_sound(sound_type: String) -> void:
	if not is_instance_valid(audio_player):
		audio_player = AudioStreamPlayer.new()
		add_child(audio_player)

	var stream: AudioStream = null

	match sound_type:
		"use_item":
			stream = SFX_USE_ITEM

		"attack":
			if stats and stats.get("sfx_attack") != null:
				stream = stats.get("sfx_attack")
			else:
				stream = DEFAULT_ATTACK

		"hit", "hurt", "hurt_crit":
			if stats and stats.get("sfx_hit") != null:
				stream = stats.get("sfx_hit")
			else:
				stream = DEFAULT_SFX_HIT

		"death":
			if stats and stats.get("sfx_death") != null:
				stream = stats.get("sfx_death")
			else:
				stream = DEFAULT_SFX_DEATH

	if stream:
		audio_player.stream = stream
		audio_player.play()

	sound_requested.emit(sound_type)


# ============================================================
# SETUP ENEMY
# ============================================================

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

	_update_profile_icon()
	_reset_combat_modifiers()

	if enemy_ai:
		enemy_ai.reset_memory()

	if bar_hp_progress:
		max_hp_bar_width = bar_hp_progress.size.x
		_update_hp_bar()

	is_defending = false
	is_defense_animation_locked = false

	_update_status_effects()
	_play_idle_if_allowed()


# ============================================================
# UPDATE PROFILE ICON
# ============================================================

func _update_profile_icon() -> void:
	if not enemy_profile_img:
		return

	if stats != null and stats.has_method("get_profile_icon"):
		enemy_profile_img.texture = stats.get_profile_icon()
	else:
		enemy_profile_img.texture = null


# ============================================================
# RESET COMBAT MODIFIERS
# ============================================================

func _reset_combat_modifiers() -> void:
	shield_value = 0.0
	buff_manager.clear()

	is_defending = false
	is_defense_animation_locked = false

	_update_status_effects()


# ============================================================
# BUFF DURATION MANAGER
# ============================================================

func _process_buff_durations() -> void:
	var expired_buff_names: Array[String] = buff_manager.process_turn_start()

	for buff_name in expired_buff_names:
		show_reaction_text(buff_name + " Expired!", Color(0.8, 0.8, 0.8), false)

	_update_status_effects()


# ============================================================
# STATUS EFFECT HELPER & DISPLAY MANAGER
# ============================================================

func _check_has_buff(buff_type: String) -> bool:
	if buff_manager.has_method("has_buff"):
		return buff_manager.call("has_buff", buff_type)
	elif buff_manager.has_method("has_status"):
		return buff_manager.call("has_status", buff_type)
	elif "active_buffs" in buff_manager:
		for buff in buff_manager.active_buffs:
			if buff.get("name", "").to_lower() == buff_type.to_lower():
				return true
	return false


func _update_status_effects() -> void:
	if not enemy_effect_container:
		return

	# 1. Bersihkan efek lama (kecuali yang temporary)
	for child in enemy_effect_container.get_children():
		if child.name != "effect" and not child.has_meta("is_temporary"):
			child.queue_free()

	var active_types: Array[String] = []

	if buff_manager.has_method("get_active_buff_types"):
		active_types = buff_manager.get_active_buff_types()
	
	if current_hp > scaled_max_hp and not active_types.has("health_up"):
		active_types.append("health_up")
	if buff_manager.get_total_attack_bonus() > 0.0 and not active_types.has("attack_up"):
		active_types.append("attack_up")
	
	var status_to_check = ["poison", "stun"]
	for status in status_to_check:
		if _check_has_buff(status) and not active_types.has(status):
			active_types.append(status)

	var icon_width: float = 20.0

	# 2. Tambahkan efek baru ke dalam container
	for type in active_types:
		if STATUS_ICONS.has(type):
			var icon_rect: TextureRect = TextureRect.new()
			icon_rect.texture = STATUS_ICONS[type]
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.custom_minimum_size = Vector2(icon_width, icon_width)
			icon_rect.size = Vector2(icon_width, icon_width)
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			enemy_effect_container.add_child(icon_rect)
			
	# 3. Rapihkan semua ikon yang ada di container
	_rearrange_status_icons()


func _show_temporary_status_icon(icon_texture: Texture2D, duration: float = 1.5) -> void:
	if not enemy_effect_container:
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

	enemy_effect_container.add_child(icon_rect)
	
	_rearrange_status_icons()

	var tween: Tween = create_tween()
	tween.tween_interval(duration)
	tween.tween_property(icon_rect, "modulate:a", 0.0, 0.4)
	tween.finished.connect(func() -> void:
		if is_instance_valid(icon_rect):
			icon_rect.queue_free()
			_rearrange_status_icons()
	)


func _rearrange_status_icons() -> void:
	if not is_instance_valid(enemy_effect_container): return

	var valid_icons: Array[Control] = []
	for child in enemy_effect_container.get_children():
		if child.name != "effect" and not child.is_queued_for_deletion():
			valid_icons.append(child as Control)

	var count: int = valid_icons.size()
	if count == 0: return

	var icon_width: float = 20.0
	var spacing: float = 4.0
	var step: float = icon_width + spacing
	var total_width: float = (count * icon_width) + ((count - 1) * spacing)
	var y_offset_down: float = 5.0

	for i in range(count):
		var offset_x: float = - (total_width / 2.0) + (i * step)
		valid_icons[i].position = effect_center_position + Vector2(offset_x, -(icon_width / 2.0) + y_offset_down)


# ============================================================
# SAFE IDLE
# ============================================================

func _play_idle_if_allowed() -> void:
	if current_hp <= 0.0:
		return
	if is_defending or is_defense_animation_locked:
		return

	play("idle")


# ============================================================
# AI TURN
# ============================================================

func take_turn(camera: Camera2D, default_camera_pos: Vector2) -> void:
	if current_hp <= 0.0:
		action_finished.emit()
		return

	is_taking_turn = true
	z_index = 100

	_process_buff_durations()

	is_defending = false
	is_defense_animation_locked = false

	if enemy_target:
		enemy_target.hide()

	if enemy_collision:
		enemy_collision.disabled = true

	var decision: EnemyAI.Decision = enemy_ai.decide(
		stats,
		current_hp,
		scaled_max_hp,
		enemy_inventory
	)

	match decision.action:
		EnemyAI.Action.ATTACK:
			await _execute_attack(
				camera,
				default_camera_pos,
				decision.attack_multiplier,
				_get_attack_reaction_text(decision.emotion),
				decision.emotion
			)
		EnemyAI.Action.DEFEND:
			await _execute_defend(camera, default_camera_pos)
		EnemyAI.Action.USE_ITEM:
			if decision.item != null:
				await _execute_item(camera, default_camera_pos, decision.item)
			else:
				await _execute_attack(
					camera,
					default_camera_pos,
					1.0,
					"Attacking!",
					EnemyAI.Emotion.CALM
				)

	if current_hp > 0.0 and enemy_collision:
		enemy_collision.disabled = false

	is_taking_turn = false
	z_index = original_z_index

	action_finished.emit()


# ============================================================
# ATTACK
# ============================================================

func _execute_attack(
	camera: Camera2D,
	default_camera_pos: Vector2,
	damage_multiplier: float = 1.0,
	text_override: String = "Attacking!",
	emotion: EnemyAI.Emotion = EnemyAI.Emotion.CALM
) -> void:

	if is_defense_animation_locked:
		_reset_camera_focus(camera, default_camera_pos)
		return

	var total_damage: float = (scaled_damage + buff_manager.get_total_attack_bonus()) * damage_multiplier
	attack_preparing.emit()

	_focus_camera_to_me(camera, true)

	var is_power_attack: bool = damage_multiplier > 1.15
	show_reaction_text(
		text_override,
		_get_emotion_color(emotion),
		is_power_attack
	)

	play("attack")
	await animation_finished

	_play_sound("attack")
	attack_hit.emit(total_damage)
	_shake_camera(camera, 12.0 * damage_multiplier, 0.25)

	await get_tree().create_timer(0.6).timeout
	_reset_camera_focus(camera, default_camera_pos)

	_play_idle_if_allowed()


# ============================================================
# ATTACK TEXT & EMOTION
# ============================================================

func _get_attack_reaction_text(emotion: EnemyAI.Emotion) -> String:
	match emotion:
		EnemyAI.Emotion.CALM: return "Attacking!"
		EnemyAI.Emotion.CONFIDENT: return "Confident Strike!"
		EnemyAI.Emotion.ANGRY: return "Angry Attack!"
		EnemyAI.Emotion.DESPERATE: return "Desperate Attack!"
		EnemyAI.Emotion.FEARFUL: return "Desperate Strike!"
		EnemyAI.Emotion.ENRAGED: return "ENRAGED ATTACK!"
	return "Attacking!"


func _get_emotion_color(emotion: EnemyAI.Emotion) -> Color:
	match emotion:
		EnemyAI.Emotion.CALM: return Color(1.0, 0.3, 0.3)
		EnemyAI.Emotion.CONFIDENT: return Color(1.0, 0.55, 0.2)
		EnemyAI.Emotion.ANGRY: return Color(1.0, 0.15, 0.05)
		EnemyAI.Emotion.DESPERATE: return Color(1.0, 0.25, 0.1)
		EnemyAI.Emotion.FEARFUL: return Color(0.7, 0.7, 1.0)
		EnemyAI.Emotion.ENRAGED: return Color(1.0, 0.0, 0.0)
	return Color.WHITE


# ============================================================
# DEFEND
# ============================================================

func _execute_defend(camera: Camera2D, default_camera_pos: Vector2) -> void:
	is_defending = true
	is_defense_animation_locked = true

	play("defend")
	_play_sound("defend")
	_focus_camera_to_me(camera, true)

	show_reaction_text("Defending!", Color(0.3, 0.8, 1.0), true)

	await get_tree().create_timer(0.8).timeout
	_reset_camera_focus(camera, default_camera_pos)

	if current_hp > 0.0 and is_defending:
		is_defense_animation_locked = true
		if animation != &"defend":
			play("defend")


# ============================================================
# USE ITEM
# ============================================================

func _execute_item(
	camera: Camera2D,
	default_camera_pos: Vector2,
	item: ItemData
) -> void:

	if item == null:
		return

	if is_defense_animation_locked:
		_reset_camera_focus(camera, default_camera_pos)
		return

	_focus_camera_to_me(camera, true)

	var item_index: int = enemy_inventory.find(item)
	if item_index == -1:
		_reset_camera_focus(camera, default_camera_pos)
		return

	enemy_inventory.remove_at(item_index)
	_play_sound("use_item")

	var result: Dictionary = buff_manager.apply_item(item, self)
	var used_any_effect: bool = false

	if result["healed"] > 0.0:
		used_any_effect = true
		_update_hp_bar()
		hp_changed.emit()
		show_reaction_text(
			result["item_name"] + " (+" + str(int(result["healed"])) + ")",
			Color(0.2, 1.0, 0.3),
			true
		)
		if STATUS_ICONS.has("health_up"):
			_show_temporary_status_icon(STATUS_ICONS["health_up"], 3.5)

	if result["shield_added"] > 0.0 or result["buff_applied"]:
		used_any_effect = true

	if item.has_method("has_status_effect") and item.has_status_effect():
		used_any_effect = true

	_show_item_pop_icon(item)
	_update_status_effects()

	if not used_any_effect:
		show_reaction_text(result["item_name"], Color(0.8, 0.8, 1.0), false)
	elif result["healed"] <= 0.0:
		show_reaction_text(result["item_name"], Color(0.4, 1.0, 0.4), true)

	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.5, 1.5, 0.5, 1.0), 0.3)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)

	await get_tree().create_timer(1.6).timeout
	_reset_camera_focus(camera, default_camera_pos)

	_play_idle_if_allowed()


# ============================================================
# GET ITEM NAME & INVENTORY
# ============================================================

func _get_item_name(item: ItemData) -> String:
	if item == null: return "Unknown Item"
	if item.item_name != "": return item.item_name
	if item.item_id != "": return item.item_id
	return "Unknown Item"


func _get_inventory_names() -> Array[String]:
	var names: Array[String] = []
	for item: ItemData in enemy_inventory:
		if item != null:
			names.append(_get_item_name(item))
	return names


# ============================================================
# DEATH
# ============================================================

func _on_death() -> void:
	is_defending = false
	is_defense_animation_locked = false

	if enemy_target: enemy_target.hide()
	if enemy_hit_icon: enemy_hit_icon.hide()
	if enemy_collision: enemy_collision.disabled = true

	play("death")
	_play_sound("death")

	if soul_particles:
		soul_particles.emitting = true

	var dropped_items: Array[String] = []
	var exp_gained: int = scaled_exp
	var gold_gained: int = scaled_gold

	if stats != null and randf() <= stats.drop_chance and stats.drop_table.size() > 0:
		dropped_items.append(str(stats.drop_table.pick_random()))

	enemy_defeated.emit(exp_gained, gold_gained, dropped_items, self)

	await get_tree().create_timer(0.8).timeout
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)


# ============================================================
# RECEIVE DAMAGE (HURT STATE & SOUND)
# ============================================================

func receive_damage(
	amount: float,
	is_critical: bool = false,
	is_dodge: bool = false
) -> void:

	if is_dodge:
		_play_sound("dodge")
		show_reaction_text("DODGE", Color(0.7, 0.7, 0.7), false)
		return

	var was_defending: bool = is_defending
	var total_defense: float = scaled_defense + buff_manager.get_total_defense_bonus()
	var final_damage: float = maxf(1.0, amount - total_defense)

	if was_defending:
		final_damage *= (1.0 - DEFEND_DAMAGE_REDUCTION)
		_play_sound("block")
		show_reaction_text("BLOCK!", Color(0.3, 0.8, 1.0), false)
		is_defending = false
		is_defense_animation_locked = false

	var reduction: float = buff_manager.get_total_damage_reduction()
	if reduction > 0.0:
		final_damage *= (1.0 - reduction)

	if shield_value > 0.0:
		var absorbed: float = minf(shield_value, final_damage)
		shield_value -= absorbed
		final_damage -= absorbed

		if absorbed > 0.0:
			show_reaction_text("SHIELD -" + str(int(absorbed)), Color(0.4, 0.8, 1.0), false)

	final_damage = maxf(1.0, final_damage)
	current_hp = maxf(0.0, current_hp - final_damage)

	_update_hp_bar()
	_update_status_effects()
	hp_changed.emit()
	_trigger_blood_splash()

	if is_critical:
		_play_sound("hurt_crit")
		show_reaction_text("Crit " + str(int(final_damage)), Color(1.0, 1.0, 0.0), true)
	else:
		_play_sound("hit")
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


# ============================================================
# HP BAR & LABEL UPDATE
# ============================================================

func _update_hp_bar() -> void:
	if scaled_max_hp <= 0.0:
		return

	if bar_hp_progress:
		var hp_ratio: float = clampf(current_hp / scaled_max_hp, 0.0, 1.0)
		var target_width: float = hp_ratio * max_hp_bar_width

		var tween: Tween = create_tween()
		tween.tween_property(bar_hp_progress, "size:x", target_width, 0.4)

	if enemy_hp_label:
		enemy_hp_label.text = str(int(current_hp)) + " / " + str(int(scaled_max_hp))


# ============================================================
# INPUT & SELECTION
# ============================================================

func _on_enemy_collision_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_select_enemy()


func _on_enemy_button_pressed() -> void:
	_try_select_enemy()


func _try_select_enemy() -> void:
	if is_taking_turn: return
	if current_hp > 0.0: clicked.emit(self)


# ============================================================
# REACTION TEXT
# ============================================================

func show_reaction_text(text: String, text_color: Color = Color.WHITE, is_crit: bool = false) -> void:
	if not label_template: return

	var duplicated_node: Node = label_template.duplicate()
	var new_label: Label = duplicated_node as Label
	if new_label == null: return

	add_child(new_label)
	new_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	new_label.text = text
	new_label.modulate = text_color
	new_label.show()

	new_label.pivot_offset = new_label.size / 2.0

	var random_offset: Vector2 = Vector2(
		randf_range(-35.0, 35.0),
		randf_range(-15.0, 15.0)
	)

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


# ============================================================
# HIGHLIGHT & TARGET
# ============================================================

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
	if not enemy_target or not is_selected: return

	var tween: Tween = create_tween().set_loops()
	tween.tween_property(enemy_target, "position:y", base_target_y - 8.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(enemy_target, "position:y", base_target_y, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ============================================================
# CAMERA CONTROL (SAFE NULL CHECK)
# ============================================================

func _focus_camera_to_me(camera: Camera2D, zoom_in: bool) -> void:
	if camera == null: return
	
	const zoomIntoEnemy = preload("uid://cctpp2ov3hiof")
	if zoomIntoEnemy:
		var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(sfx_player)
		sfx_player.stream = zoomIntoEnemy
		sfx_player.play()
		sfx_player.finished.connect(sfx_player.queue_free)

	var target_zoom: Vector2 = Vector2(1.45, 1.45) if zoom_in else Vector2.ONE
	var viewport_size: Vector2 = get_viewport_rect().size

	var half_width: float = viewport_size.x / target_zoom.x * 0.5
	var half_height: float = viewport_size.y / target_zoom.y * 0.5

	var clamped_x: float = clampf(global_position.x, half_width, viewport_size.x - half_width)
	var clamped_y: float = clampf(global_position.y, half_height, viewport_size.y - half_height)

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(camera, "global_position", Vector2(clamped_x, clamped_y), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "zoom", target_zoom, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _reset_camera_focus(camera: Camera2D, default_pos: Vector2) -> void:
	if camera == null: return

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(camera, "global_position", default_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "zoom", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ============================================================
# ITEM POP ICON & PARTICLES
# ============================================================

func _show_item_pop_icon(item_data: ItemData) -> void:
	if item_data == null or item_data.icon == null: return

	var icon_rect: TextureRect = TextureRect.new()
	add_child(icon_rect)
	icon_rect.texture = item_data.icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(36.0, 36.0)
	icon_rect.size = Vector2(36.0, 36.0)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.pivot_offset = icon_rect.size / 2.0

	var start_pos: Vector2 = Vector2(-icon_rect.size.x / 2.0, -65.0)
	icon_rect.position = start_pos
	icon_rect.scale = Vector2(0.1, 0.1)

	var sway_tween: Tween = create_tween().set_loops(6)
	sway_tween.tween_property(icon_rect, "rotation", deg_to_rad(18.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway_tween.tween_property(icon_rect, "rotation", deg_to_rad(-18.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var main_tween: Tween = create_tween().set_parallel(true)
	main_tween.tween_property(icon_rect, "scale", Vector2(1.3, 1.3), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	main_tween.chain().tween_property(icon_rect, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	main_tween.tween_property(icon_rect, "position:y", start_pos.y - 55.0, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	main_tween.tween_property(icon_rect, "modulate:a", 0.0, 0.8).set_delay(1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	main_tween.finished.connect(func() -> void:
		if is_instance_valid(sway_tween): sway_tween.kill()
		if is_instance_valid(icon_rect): icon_rect.queue_free()
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
	if blood_particles: blood_particles.restart()


func _shake_camera(camera: Camera2D, intensity: float, duration: float) -> void:
	var parent_control: Node = get_parent()
	if parent_control and parent_control.has_method("trigger_camera_shake_and_blood"):
		parent_control.trigger_camera_shake_and_blood(intensity, duration, 0.8)
	elif camera != null:
		var original_offset: Vector2 = camera.offset
		var tween: Tween = create_tween()

		for i: int in range(6):
			var offset: Vector2 = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
			tween.tween_property(camera, "offset", offset, duration / 6.0)

		tween.tween_property(camera, "offset", original_offset, 0.05)
