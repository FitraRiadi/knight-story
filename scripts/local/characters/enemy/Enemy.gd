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
signal battle_cry_activated(ability_level: int)

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
	"stun": preload("res://assets/ui/icons/statusEffect/stun.png"),
	"bleed": preload("res://assets/ui/icons/statusEffect/attackUp.png")
}


# ============================================================
# BASIC DATA
# ============================================================

@export var enemy_id: String = ""
@export var level: int = 1
@export var stats: EnemyData

var enemy_ai: EnemyAI

var enemy_abilities: Array[AbilityData] = []


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
# MORALE SYSTEM
# ============================================================
var current_morale: float = 100.0
var scaled_max_morale: float = 100.0
var is_stunned: bool = false
var stun_turns_remaining: int = 0
var stun_interrupted: bool = false
var force_attack_finish: bool = false

# Morale config
const MORALE_INCREASE_ON_HIT: float = 0.25
const MORALE_DECREASE_ON_PARRY: float = 0.25
const MORALE_RECOVER_ON_STUN_END: float = 0.50

# Crack overlay & smoke particle
var crack_overlay: Node2D = null
var smoke_particles: CPUParticles2D = null

# Buff & heal particles
var buff_particles: CPUParticles2D = null
var heal_particles: CPUParticles2D = null
var current_buff_particle_type: String = ""


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
	_setup_smoke_particles()
	_setup_buff_particles()
	_setup_heal_particles()
	_setup_crack_overlay()

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
		if not is_stunned:
			_play_idle_if_allowed()
		# Jika stunned, frame terakhir sudah di-lock di _execute_stun_turn


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

		scaled_max_morale = stats.max_morale
		current_morale = scaled_max_morale
		is_stunned = false
		stun_turns_remaining = 0

		current_hp = scaled_max_hp
		enemy_inventory = stats.starting_inventory.duplicate()

		# Load abilities dari EnemyData
		enemy_abilities.clear()
		for ab: AbilityData in stats.abilities:
			if ab != null:
				enemy_abilities.append(ab)

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
		scaled_max_morale = 100.0
		current_morale = 100.0

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
	# === POISON DOT: -10 HP per turn ===
	for buff in buff_manager.active_buffs:
		if buff.get("type") == "poison":
			var poison_dmg: float = buff.get("poison_damage", 10.0)
			receive_damage(poison_dmg, false, false)
			show_reaction_text("-" + str(int(poison_dmg)), Color(0.3, 0.8, 0.2), false)

	# === BLEED: MORALE DRAIN -10% per turn ===
	for buff in buff_manager.active_buffs:
		if buff.get("type") == "bleed":
			var drain: float = buff.get("morale_drain", 0.0)
			if drain > 0.0 and scaled_max_morale > 0.0:
				var drain_amount: float = scaled_max_morale * drain
				current_morale = maxf(0.0, current_morale - drain_amount)
				show_reaction_text("-Morale", Color(0.8, 0.0, 0.2), false)
				_check_morale_stun()
				_update_crack_overlay()
				_update_smoke_intensity()
			break

	var expired_buff_names: Array[String] = buff_manager.process_turn_start()

	for buff_name in expired_buff_names:
		show_reaction_text(buff_name + " Expired!", Color(0.8, 0.8, 0.8), false)
		# Cleanup repeat particles for this buff
		_cleanup_card_particles(buff_name)

	# Cek apakah masih ada buff attack/defense aktif (skip poison/bleed - handled by card particles)
	if current_buff_particle_type != "":
		var active_types: Array[String] = buff_manager.get_active_buff_types()
		var still_has_buff: bool = false
		for t in active_types:
			if t == "attack_up" or t == "defense_up" or t == "generic":
				still_has_buff = true
				if t != current_buff_particle_type:
					_play_enemy_buff_visual(t)
				break
		if not still_has_buff:
			_stop_buff_particles()

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

	var icon_width: float = 20.0
	var shown_paths: Array[String] = []

	# 2. Iterate over active_buffs langsung — pakai effect_icon per buff
	for buff in buff_manager.active_buffs:
		var icon_tex: Texture2D = buff.get("effect_icon")
		var buff_type: String = buff.get("type", "")

		# Fallback ke type-based icon kalau effect_icon gak ada
		if icon_tex == null and STATUS_ICONS.has(buff_type):
			icon_tex = STATUS_ICONS[buff_type]

		if icon_tex == null:
			continue

		# Dedup by resource path
		var tex_path: String = icon_tex.resource_path if icon_tex else ""
		if tex_path != "" and shown_paths.has(tex_path):
			continue
		if tex_path != "":
			shown_paths.append(tex_path)

		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(icon_width, icon_width)
		icon_rect.size = Vector2(icon_width, icon_width)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy_effect_container.add_child(icon_rect)

	# 3. Special cases: overheal, poison, stun
	if current_hp > scaled_max_hp:
		var heal_tex: Texture2D = STATUS_ICONS.get("health_up")
		if heal_tex:
			var tex_path: String = heal_tex.resource_path
			if not shown_paths.has(tex_path):
				shown_paths.append(tex_path)
				var icon_rect: TextureRect = TextureRect.new()
				icon_rect.texture = heal_tex
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.custom_minimum_size = Vector2(icon_width, icon_width)
				icon_rect.size = Vector2(icon_width, icon_width)
				icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				enemy_effect_container.add_child(icon_rect)

	var status_to_check = ["poison", "stun"]
	for status in status_to_check:
		if _check_has_buff(status):
			var status_tex: Texture2D = STATUS_ICONS.get(status)
			if status_tex:
				var tex_path: String = status_tex.resource_path
				if not shown_paths.has(tex_path):
					shown_paths.append(tex_path)
					var icon_rect: TextureRect = TextureRect.new()
					icon_rect.texture = status_tex
					icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					icon_rect.custom_minimum_size = Vector2(icon_width, icon_width)
					icon_rect.size = Vector2(icon_width, icon_width)
					icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
					enemy_effect_container.add_child(icon_rect)

	if is_stunned:
		var stun_tex: Texture2D = STATUS_ICONS.get("stun")
		if stun_tex:
			var tex_path: String = stun_tex.resource_path
			if not shown_paths.has(tex_path):
				shown_paths.append(tex_path)
				var icon_rect: TextureRect = TextureRect.new()
				icon_rect.texture = stun_tex
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.custom_minimum_size = Vector2(icon_width, icon_width)
				icon_rect.size = Vector2(icon_width, icon_width)
				icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				enemy_effect_container.add_child(icon_rect)

	# 4. Rapihkan semua ikon
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

	# Cek apakah mati karena poison DoT
	if current_hp <= 0.0:
		is_taking_turn = false
		z_index = original_z_index
		action_finished.emit()
		return

	is_defending = false
	is_defense_animation_locked = false

	if enemy_target:
		enemy_target.hide()

	if enemy_collision:
		enemy_collision.disabled = true

	# STUN CHECK: Skip turn if stunned
	if is_stunned and stun_turns_remaining > 0:
		await _execute_stun_turn(camera, default_camera_pos)
		if current_hp > 0.0 and enemy_collision:
			enemy_collision.disabled = false
		is_taking_turn = false
		z_index = original_z_index
		action_finished.emit()
		return

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

	# BLEED: -attack reduction
	for buff in buff_manager.active_buffs:
		if buff.get("type") == "bleed":
			var atk_reduc: float = buff.get("attack_reduction", 0.0)
			if atk_reduc > 0.0:
				total_damage *= (1.0 - atk_reduc)
			break

	attack_preparing.emit()

	_focus_camera_to_me(camera, true)

	var is_power_attack: bool = damage_multiplier > 1.15
	show_reaction_text(
		text_override,
		_get_emotion_color(emotion),
		is_power_attack
	)

	# Tunggu animasi attack selesai, tapi kalau force_attack_finish aktif, langsung loncat ke frame terakhir
	var attack_frame_count: int = get_sprite_frames().get_frame_count(&"attack") if get_sprite_frames().has_animation(&"attack") else 1
	force_attack_finish = false
	stun_interrupted = false
	frame = 0
	play("attack")
	var was_force_finished: bool = false
	var frame_check_time: float = 0.0
	while frame_check_time < 2.0:
		await get_tree().process_frame
		frame_check_time += get_process_delta_time()
		if force_attack_finish:
			stop()
			if attack_frame_count > 1:
				set_frame_and_progress(attack_frame_count - 1, 0.0)
			was_force_finished = true
			break
		if not is_playing():
			break
	force_attack_finish = false

	# STUN INTERRUPT: Parry menyebabkan stun mid-attack, skip damage langsung stun
	if stun_interrupted:
		stun_interrupted = false
		_focus_camera_to_me(camera, true)
		await _play_stun_visuals()
		await get_tree().create_timer(1.5).timeout
		_reset_camera_focus(camera, default_camera_pos)
		return

	if not was_force_finished:
		_play_sound("attack")
	attack_hit.emit(total_damage)
	_shake_camera(camera, 12.0 * damage_multiplier, 0.25)

	await get_tree().create_timer(0.6).timeout

	# BATTLE CRY: Check double attack setelah serangan pertama
	if not stun_interrupted and should_double_attack():
		var ab := get_battle_cry_ability()
		var cry_level: int = ab.get_level()
		var bonus_mult: float = BattleCryAbility.get_bonus_damage_multiplier(cry_level)
		var cry_text: String = BattleCryAbility.get_battle_cry_text(cry_level)
		var cry_color: Color = BattleCryAbility.get_battle_cry_text_color(cry_level)

		show_reaction_text(cry_text, cry_color, true)
		battle_cry_activated.emit(cry_level)
		await get_tree().create_timer(0.4).timeout

		# Serangan kedua dengan bonus damage
		var second_damage: float = (scaled_damage + buff_manager.get_total_attack_bonus()) * bonus_mult
		force_attack_finish = false
		stun_interrupted = false
		frame = 0
		play("attack")
		var second_frame_count: int = get_sprite_frames().get_frame_count(&"attack") if get_sprite_frames().has_animation(&"attack") else 1
		var second_was_force: bool = false
		var second_check_time: float = 0.0
		while second_check_time < 2.0:
			await get_tree().process_frame
			second_check_time += get_process_delta_time()
			if force_attack_finish:
				stop()
				if second_frame_count > 1:
					set_frame_and_progress(second_frame_count - 1, 0.0)
				second_was_force = true
				break
			if not is_playing():
				break
		force_attack_finish = false

		if stun_interrupted:
			stun_interrupted = false
			_focus_camera_to_me(camera, true)
			await _play_stun_visuals()
			await get_tree().create_timer(1.5).timeout
			_reset_camera_focus(camera, default_camera_pos)
			return

		if not second_was_force:
			_play_sound("attack")
		attack_hit.emit(second_damage)
		_shake_camera(camera, 10.0 * bonus_mult, 0.2)
		await get_tree().create_timer(0.5).timeout

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
		_play_enemy_heal_visual()
		show_reaction_text(
			result["item_name"] + " (+" + str(int(result["healed"])) + ")",
			Color(0.2, 1.0, 0.3),
			true
		)
		if STATUS_ICONS.has("health_up"):
			var heal_icon: Texture2D = item.effect_icon if item.effect_icon else STATUS_ICONS["health_up"]
			_show_temporary_status_icon(heal_icon, 3.5)

	if result["buff_applied"]:
		used_any_effect = true
		# Tentuin buff type berdasarkan item stats
		var atk_bonus: float = item.attack_bonus + item.damage_bonus
		var def_bonus: float = item.defense_bonus
		var buff_type: String = "generic"
		if atk_bonus > 0.0:
			buff_type = "attack_up"
		elif def_bonus > 0.0:
			buff_type = "defense_up"
		_play_enemy_buff_visual(buff_type)

	if result["shield_added"] > 0.0:
		used_any_effect = true

	if item.has_method("has_status_effect") and item.has_status_effect():
		used_any_effect = true

	_show_item_pop_icon(item)
	_update_status_effects()

	if not used_any_effect:
		show_reaction_text(result["item_name"], Color(0.8, 0.8, 1.0), false)
	elif result["healed"] <= 0.0:
		show_reaction_text(result["item_name"], Color(0.4, 1.0, 0.4), true)

	# Flash sudah di-handle di _play_enemy_buff_visual / _play_enemy_heal_visual
	# Kalau gak ada buff/heal, flash hijau generic
	if not result["buff_applied"] and result["healed"] <= 0.0:
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

	_stop_buff_particles()
	_stop_all_effects_on_death()
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

	# BLEED: +damage taken amplification
	for buff in buff_manager.active_buffs:
		if buff.get("type") == "bleed":
			var amp: float = buff.get("damage_amplification", 0.0)
			if amp > 0.0:
				final_damage *= (1.0 + amp)
			break

	if was_defending:
		final_damage *= (1.0 - DEFEND_DAMAGE_REDUCTION)
		_play_sound("block")
		show_reaction_text("BLOCK!", Color(0.3, 0.8, 1.0), false)
		is_defending = false
		is_defense_animation_locked = false

	var reduction: float = buff_manager.get_total_damage_reduction()
	if reduction > 0.0:
		final_damage = max(0.0, final_damage - reduction)

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

	# Red flash pas kena hit
	var hit_flash := create_tween()
	hit_flash.tween_property(self, "modulate", Color(1.5, 0.3, 0.3, 1.0), 0.08)
	hit_flash.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)

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


# ============================================================
# MORALE SYSTEM
# ============================================================

func decrease_morale_by_parry() -> void:
	"""Dipanggil saat player berhasil parry serangan enemy"""
	var reduction: float = scaled_max_morale * MORALE_DECREASE_ON_PARRY
	current_morale = maxf(0.0, current_morale - reduction)
	_check_morale_stun()
	_update_crack_overlay()
	_update_smoke_intensity()


func increase_morale_on_hit() -> void:
	"""Dipanggil saat enemy berhasil attack player (tidak di-parry)"""
	var bonus: float = scaled_max_morale * MORALE_INCREASE_ON_HIT
	current_morale = minf(scaled_max_morale, current_morale + bonus)
	_update_crack_overlay()
	_update_smoke_intensity()


func _check_morale_stun() -> void:
	"""Cek apakah morale habis -> trigger stun 1 turn"""
	if current_morale <= 0.0 and not is_stunned:
		is_stunned = true
		stun_turns_remaining = 1
	_update_status_effects()


func _cleanup_card_particles(buff_name: String) -> void:
	"""Cleanup repeat particles saat buff expired"""
	if not has_meta("card_particles"):
		return
	var particles: Array = get_meta("card_particles")
	var to_remove: Array = []
	for p in particles:
		if is_instance_valid(p):
			# Stop semua particle di dalamnya
			for child in p.get_children():
				if child is GPUParticles2D:
					child.emitting = false
				elif child is CPUParticles2D:
					child.emitting = false
			# Free node dari scene tree
			p.queue_free()
			to_remove.append(p)
		else:
			to_remove.append(p)
	# Spawn end particle
	_spawn_end_particle(buff_name)
	# Remove from meta
	for p in to_remove:
		particles.erase(p)
	if particles.is_empty():
		remove_meta("card_particles")


func _stop_all_effects_on_death() -> void:
	"""Matikan semua effect (card particles, potion, buff) saat enemy mati — fade out"""
	# 1. Clear active buffs supaya gak diproses lagi
	if buff_manager:
		buff_manager.active_buffs.clear()

	# 2. Fade out + stop card particles (poison, bleed, dll)
	if has_meta("card_particles"):
		var particles: Array = get_meta("card_particles")
		for p in particles:
			if is_instance_valid(p):
				# Stop semua emitting
				for child in p.get_children():
					if child is GPUParticles2D:
						child.emitting = false
					elif child is CPUParticles2D:
						child.emitting = false
				# Fade out the Node2D itself
				var tween: Tween = create_tween()
				tween.tween_property(p, "modulate:a", 0.0, 0.5)
				tween.tween_callback(p.queue_free)
		particles.clear()
		remove_meta("card_particles")

	# 3. Fade out buff_particles (heal, attack potion, dll)
	if buff_particles and buff_particles.emitting:
		buff_particles.emitting = false
		var tween: Tween = create_tween()
		tween.tween_property(buff_particles, "modulate:a", 0.0, 0.5)
		tween.tween_callback(buff_particles.set.bind("emitting", false))

	# 4. Fade out heal_particles
	if heal_particles and heal_particles.emitting:
		heal_particles.emitting = false
		var tween: Tween = create_tween()
		tween.tween_property(heal_particles, "modulate:a", 0.0, 0.5)


func _spawn_end_particle(buff_name: String) -> void:
	"""Spawn end particle saat effect expired"""
	# Find card by buff name
	var card_paths: Array[String] = [
		"res://data/action_cards/poison.tres",
		"res://data/action_cards/stun.tres",
		"res://data/action_cards/bleed.tres",
	]
	for path in card_paths:
		var card: ActionCardData = load(path) as ActionCardData
		if card and card.card_name == buff_name and card.end_scene:
			var instance: Node2D = card.end_scene.instantiate() as Node2D
			if instance:
				add_child(instance)
				# Position at enemy center
				if enemy_collision:
					instance.position = enemy_collision.position + enemy_collision.size / 2.0
				else:
					instance.position = Vector2.ZERO
				# Set one_shot + auto-free
				if card.end_duration > 0.0:
					for child in instance.get_children():
						if child is GPUParticles2D:
							child.one_shot = true
						elif child is CPUParticles2D:
							child.one_shot = true
					await get_tree().create_timer(card.end_duration).timeout
					if is_instance_valid(instance):
						instance.queue_free()
			break



func _play_stun_visuals() -> void:
	"""Mainkan animasi hurt + lock frame saat morale habis (tanpa skip turn)"""
	show_reaction_text("STUNNED!", Color(1.0, 0.8, 0.0), true)
	_play_sound("hit")

	# Dark tint saat stun
	modulate = Color(0.45, 0.45, 0.55, 1.0)

	# Mainkan animasi hurt dan tunggu selesai
	play("hurt")
	await animation_finished

	# Lock di frame terakhir animasi hurt
	_lock_hurt_frame()


func _lock_hurt_frame() -> void:
	"""Lock animasi hurt di frame terakhir (untuk multi-turn stun)"""
	modulate = Color(0.45, 0.45, 0.55, 1.0)
	var hurt_frame_count: int = get_sprite_frames().get_frame_count(&"hurt") if get_sprite_frames().has_animation(&"hurt") else 1
	if hurt_frame_count > 1:
		frame = hurt_frame_count - 1
		set_frame_and_progress(hurt_frame_count - 1, 0.0)


func _execute_stun_turn(camera: Camera2D, default_camera_pos: Vector2) -> void:
	"""Eksekusi giliran saat enemy stun: skip turn, kurangi stun, recover"""
	_focus_camera_to_me(camera, true)

	show_reaction_text("Stunned!", Color(1.0, 0.8, 0.0), true)

	# Tunggu 1 turn (1.5 detik) saat stun
	await get_tree().create_timer(1.5).timeout

	# Kurangi stun turns
	stun_turns_remaining -= 1
	if stun_turns_remaining <= 0:
		# Stun selesai → reset semua visual
		is_stunned = false
		_recover_morale_after_stun()
		_play_idle_if_allowed()
	else:
		# Masih stunned → jaga animasi hurt + dark tint
		_lock_hurt_frame()

	_reset_camera_focus(camera, default_camera_pos)
	_update_status_effects()


func _recover_morale_after_stun() -> void:
	"""Recover 50% morale setelah stun berakhir"""
	# Reset warna normal
	modulate = Color(1.0, 1.0, 1.0, 1.0)

	var recovery: float = scaled_max_morale * MORALE_RECOVER_ON_STUN_END
	current_morale = minf(scaled_max_morale, recovery)
	show_reaction_text("Morale Recovered!", Color(0.3, 0.8, 1.0), false)
	_update_crack_overlay()
	_update_smoke_intensity()
	_update_status_effects()


func get_morale_ratio() -> float:
	"""Return morale sebagai ratio 0.0 - 1.0"""
	if scaled_max_morale <= 0.0:
		return 1.0
	return clampf(current_morale / scaled_max_morale, 0.0, 1.0)


# ============================================================
# ABILITIES
# ============================================================

func get_tactical_attack_ability() -> AbilityData:
	for ab: AbilityData in enemy_abilities:
		if ab.is_tactical_attack():
			return ab
	return null


func get_battle_cry_ability() -> AbilityData:
	for ab: AbilityData in enemy_abilities:
		if ab.is_battle_cry():
			return ab
	return null


func has_tactical_attack() -> bool:
	return get_tactical_attack_ability() != null


func has_battle_cry() -> bool:
	return get_battle_cry_ability() != null


func should_counter_attack() -> bool:
	var ab := get_tactical_attack_ability()
	if ab == null:
		return false
	return TacticalAttackAbility.should_counter(ab.get_level())


func should_double_attack() -> bool:
	var ab := get_battle_cry_ability()
	if ab == null:
		return false
	return BattleCryAbility.should_double_attack(ab.get_level())
	return clampf(current_morale / scaled_max_morale, 0.0, 1.0)


# ============================================================
# LIFE STEAL ABILITY
# ============================================================

func get_life_steal_ability() -> AbilityData:
	for ab: AbilityData in enemy_abilities:
		if ab.is_life_steal():
			return ab
	return null


func has_life_steal() -> bool:
	return get_life_steal_ability() != null


func _apply_life_steal(damage_dealt: float) -> void:
	var ab := get_life_steal_ability()
	if ab == null:
		return
	if not LifeStealAbility.should_life_steal(ab.get_level()):
		return

	var heal_percent: float = LifeStealAbility.get_heal_percent(ab.get_level())
	var heal_amount: float = damage_dealt * heal_percent
	var old_hp: float = current_hp
	current_hp = minf(scaled_max_hp, current_hp + heal_amount)
	var actual_heal: float = current_hp - old_hp

	if actual_heal <= 0.0:
		return

	# Update HP bar
	_update_hp_bar()

	# Show floating text
	var ls_text: String = LifeStealAbility.get_life_steal_text(ab.get_level())
	var ls_color: Color = LifeStealAbility.get_life_steal_text_color(ab.get_level())
	show_reaction_text(ls_text + " +" + str(int(actual_heal)), ls_color, true)

	# Green flash tween
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.5, 1.5, 0.5, 1.0), 0.15)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)


# ============================================================
# SMOKE PARTICLE (Morale)
# ============================================================

func _setup_smoke_particles() -> void:
	smoke_particles = CPUParticles2D.new()
	add_child(smoke_particles)
	smoke_particles.z_index = 45
	smoke_particles.amount = 15
	smoke_particles.lifetime = 2.0
	smoke_particles.one_shot = false
	smoke_particles.emitting = false
	smoke_particles.direction = Vector2(0, -1)
	smoke_particles.spread = 30.0
	smoke_particles.gravity = Vector2(0, -40)
	smoke_particles.initial_velocity_min = 15.0
	smoke_particles.initial_velocity_max = 35.0
	smoke_particles.scale_amount_min = 3.0
	smoke_particles.scale_amount_max = 7.0
	smoke_particles.color = Color(0.3, 0.3, 0.3, 0.5)
	smoke_particles.position = Vector2(0, -20)

	# Posisikan particle di area profile (atas-tengah enemy)
	if enemy_profile_img and is_instance_valid(enemy_profile_img):
		var profile_global_pos: Vector2 = enemy_profile_img.global_position
		smoke_particles.position = to_local(profile_global_pos) + Vector2(enemy_profile_img.size.x / 2.0, enemy_profile_img.size.y / 2.0)
	_update_smoke_intensity()


func _update_smoke_intensity() -> void:
	"""Update intensitas smoke berdasarkan morale"""
	if not is_instance_valid(smoke_particles):
		return

	var morale_ratio: float = get_morale_ratio()
	# Smoke muncul saat morale <= 50%
	if morale_ratio <= 0.5:
		smoke_particles.emitting = true
		# Makin rendah morale, makin banyak & cepat particle
		var intensity: float = 1.0 - (morale_ratio / 0.5)  # 0.0 - 1.0
		smoke_particles.amount = int(lerp(5.0, 20.0, intensity))
		smoke_particles.initial_velocity_min = lerp(10.0, 30.0, intensity)
		smoke_particles.initial_velocity_max = lerp(25.0, 60.0, intensity)
		smoke_particles.scale_amount_min = lerp(2.0, 5.0, intensity)
		smoke_particles.scale_amount_max = lerp(5.0, 10.0, intensity)
		smoke_particles.modulate.a = lerp(0.3, 0.8, intensity)
	else:
		smoke_particles.emitting = false


# ============================================================
# BUFF PARTICLES (Attack Up, Defense Up, Generic)
# ============================================================

func _setup_buff_particles() -> void:
	buff_particles = CPUParticles2D.new()
	add_child(buff_particles)
	buff_particles.z_index = 50
	buff_particles.amount = 12
	buff_particles.lifetime = 1.5
	buff_particles.one_shot = false
	buff_particles.emitting = false
	buff_particles.direction = Vector2(0, -1)
	buff_particles.spread = 35.0
	buff_particles.gravity = Vector2(0, -60)
	buff_particles.initial_velocity_min = 20.0
	buff_particles.initial_velocity_max = 50.0
	buff_particles.scale_amount_min = 2.0
	buff_particles.scale_amount_max = 5.0
	buff_particles.color = Color(1.0, 0.4, 0.15, 0.8)

	if enemy_collision and is_instance_valid(enemy_collision):
		buff_particles.position = enemy_collision.position + enemy_collision.size / 2.0


func _play_enemy_buff_visual(buff_type: String) -> void:
	if not buff_particles:
		return

	var lower_type := buff_type.to_lower()

	# Anti-duplicate: kalau type sama, restart aja
	if lower_type == current_buff_particle_type and buff_particles.emitting:
		buff_particles.restart()
		return

	# Update warna sesuai type
	match lower_type:
		"attack_up":
			buff_particles.color = Color(1.0, 0.4, 0.15, 0.8)
		"defense_up":
			buff_particles.color = Color(0.3, 0.6, 1.0, 0.8)
		"poison":
			buff_particles.color = Color(0.3, 0.8, 0.2, 0.8)
		"bleed":
			buff_particles.color = Color(0.8, 0.0, 0.2, 0.8)
		_:
			buff_particles.color = Color(1.0, 0.85, 0.2, 0.8)

	current_buff_particle_type = lower_type
	buff_particles.emitting = true
	buff_particles.restart()

	# Flash warna sesuai buff
	var flash_color: Color = buff_particles.color
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(flash_color.r, flash_color.g, flash_color.b, 1.0), 0.1)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)


func _stop_buff_particles() -> void:
	if buff_particles:
		buff_particles.emitting = false
	current_buff_particle_type = ""


# ============================================================
# HEAL PARTICLES (One-shot burst)
# ============================================================

func _setup_heal_particles() -> void:
	heal_particles = CPUParticles2D.new()
	add_child(heal_particles)
	heal_particles.z_index = 50
	heal_particles.amount = 10
	heal_particles.lifetime = 0.6
	heal_particles.one_shot = true
	heal_particles.explosiveness = 0.9
	heal_particles.emitting = false
	heal_particles.direction = Vector2(0, -1)
	heal_particles.spread = 60.0
	heal_particles.gravity = Vector2(0, -200)
	heal_particles.initial_velocity_min = 60.0
	heal_particles.initial_velocity_max = 120.0
	heal_particles.scale_amount_min = 2.0
	heal_particles.scale_amount_max = 5.0
	heal_particles.color = Color(0.2, 1.0, 0.3, 0.9)

	if enemy_collision and is_instance_valid(enemy_collision):
		heal_particles.position = enemy_collision.position + enemy_collision.size / 2.0


func _play_enemy_heal_visual() -> void:
	if not heal_particles:
		return
	heal_particles.restart()

	# Flash hijau
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.5, 1.5, 0.5, 1.0), 0.15)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)


# ============================================================
# CRACK OVERLAY (Morale - Profile)
# ============================================================

func _setup_crack_overlay() -> void:
	"""Buat crack overlay di atas profile image"""
	if not is_instance_valid(enemy_profile_img):
		return

	# Buat crack overlay sebagai child dari profile (ikut rotation/scale)
	var crack_script: GDScript = preload("res://scripts/local/characters/enemy/CrackOverlay.gd")
	crack_overlay = Node2D.new()
	crack_overlay.name = "CrackOverlay"
	crack_overlay.z_index = 10
	crack_overlay.set_script(crack_script)
	crack_overlay.enemy_ref = self
	enemy_profile_img.get_parent().add_child(crack_overlay)

	# Posisikan di tengah profile
	var profile_panel: Control = enemy_profile_img.get_parent()
	crack_overlay.position = profile_panel.size / 2.0
	# Scale biar crack pas di area profile (CrackOverlay pakai 100x100 base)
	crack_overlay.scale = profile_panel.size / Vector2(100.0, 100.0)
	crack_overlay.modulate.a = 0.0

	_update_crack_overlay()


func _update_crack_overlay() -> void:
	"""Update crack visual berdasarkan morale"""
	if not is_instance_valid(crack_overlay):
		return

	var morale_ratio: float = get_morale_ratio()
	# Crack mulai muncul saat morale <= 50%
	if morale_ratio > 0.5:
		crack_overlay.modulate.a = 0.0
		return

	# Hitung intensitas crack: 0.0 (50% morale) - 1.0 (0% morale)
	var crack_intensity: float = 1.0 - (morale_ratio / 0.5)
	crack_overlay.modulate.a = clampf(crack_intensity, 0.0, 1.0)
	crack_overlay.queue_redraw()


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
