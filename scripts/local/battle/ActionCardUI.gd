extends Control
class_name ActionCardUI


# ============================================================
# SIGNALS
# ============================================================

signal card_selected(index: int)
signal card_closed()
signal attack_indicator_ready()


# ============================================================
# CONSTANTS
# ============================================================

const CARD_WIDTH: float = 110.0
const CARD_HEIGHT: float = 160.0
const CARD_GAP: float = 18.0
const CARD_SPACING: float = CARD_WIDTH + CARD_GAP
const CARD_Y: float = 168.0

const HOVER_LIFT: float = -18.0
const HOVER_SCALE: float = 1.1
const SELECT_SCALE: float = 1.25

const FAN_ANGLE: float = 4.0
const FLOAT_AMPLITUDE: float = 4.0
const FLOAT_SPEED: float = 2.5

const REJECT_SFX_PATH: String = "uid://dl4yf4hktppo5"


# ============================================================
# PRELOADS
# ============================================================

const CARD_SCENE: PackedScene = preload("res://scenes/battle/action_card.tscn")
const ATTACK_CARD_SCENE: PackedScene = preload("res://scenes/battle/attack_card.tscn")
const CARD_FLAME_SHADER: Shader = preload("res://shaders/CardFlameLite.gdshader")


# ============================================================
# STATE
# ============================================================

var cards_data: Array[ActionCardData] = []
var card_nodes: Array[Control] = []
var card_glow_panels: Array[Panel] = []

var card_cooldowns: Array[int] = []
var current_stamina: float = 0.0

var is_open: bool = false
var is_selecting: bool = false
var selected_index: int = -1

var canvas_layer: CanvasLayer
var bg_overlay: ColorRect
var float_tweens: Array[Tween] = []
var hover_tweens: Dictionary = {}
var spawn_tween: Tween  # Track spawn tween to kill on early select
var _reject_tween: Tween = null  # shake kartu ditolak
var _deny_label: Label = null

# Attack mode
enum CardMode { SKILL, ATTACK }
var card_mode: CardMode = CardMode.SKILL
var attack_indicator: Control = null
var waiting_for_mechanic: bool = false


# ============================================================
# SETUP
# ============================================================

func setup(cards: Array[ActionCardData], cooldowns: Array[int], stamina: float) -> void:
	cards_data = cards
	card_cooldowns = cooldowns
	current_stamina = stamina


func setup_attack_mode(cards: Array[ActionCardData], stamina: float) -> void:
	cards_data = cards
	card_cooldowns = []
	current_stamina = stamina
	card_mode = CardMode.ATTACK


# ============================================================
# OPEN
# ============================================================

func open() -> void:
	if is_open:
		return
	is_open = true
	_build_ui()
	_animate_spawn()


func _build_ui() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 165
	add_child(canvas_layer)

	bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0, 0, 0, 0.5)
	bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	bg_overlay.gui_input.connect(_on_bg_input)
	canvas_layer.add_child(bg_overlay)

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var total_width: float = (cards_data.size() * CARD_WIDTH) + ((cards_data.size() - 1) * CARD_GAP)
	var start_x: float = (viewport_size.x - total_width) / 2.0

	for i in range(cards_data.size()):
		var data: ActionCardData = cards_data[i]
		var cd: int = card_cooldowns[i] if i < card_cooldowns.size() else 0
		var has_stamina: bool = current_stamina >= data.stamina_cost
		var is_on_cooldown: bool = cd > 0

		var card: Control = _create_card(data, i, has_stamina, is_on_cooldown, cd)
		card.position = Vector2(start_x + i * CARD_SPACING, CARD_Y + 300.0)
		card.name = "Card_" + str(i)
		canvas_layer.add_child(card)
		card_nodes.append(card)


# Api rarity di frame kartu (CardFlameLite, versi ringan FlameShader).
# Warna = rarity color, intensitas = RARITY_FLAME. Material unik per kartu
# (uniform beda), Shader-nya share. Dipanggil pas spawn dua mode.
func _apply_card_flame(card: Control, frame_node_name: String, data: ActionCardData) -> void:
	if CARD_FLAME_SHADER == null or data == null:
		return
	var frame: TextureRect = card.get_node_or_null(frame_node_name) as TextureRect
	if frame == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = CARD_FLAME_SHADER
	var rc: Color = data.get_rarity_color()
	mat.set_shader_parameter("flame_color", rc)
	mat.set_shader_parameter("outline_color", rc.darkened(0.65))
	var fp: Dictionary = data.get_flame_params()
	mat.set_shader_parameter("intensity", float(fp.get("intensity", 0.3)))
	mat.set_shader_parameter("flame_size", float(fp.get("flame_size", 0.05)))
	mat.set_shader_parameter("speed", float(fp.get("speed", 2.5)))
	mat.set_shader_parameter("transition", 1.0)
	frame.material = mat


func _create_card(data: ActionCardData, index: int, has_stamina: bool, is_on_cooldown: bool, cooldown_remaining: int) -> Control:
	var card: Control

	# Pilih scene berdasarkan mode
	if card_mode == CardMode.ATTACK:
		card = ATTACK_CARD_SCENE.instantiate()
		# Override ukuran kayak action card (110x160)
		card.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		card.pivot_offset = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT / 2.0)
	else:
		card = CARD_SCENE.instantiate()

	# Fan rotation
	var fan_count: int = cards_data.size()
	var center_index: float = (fan_count - 1) / 2.0
	var fan_offset: float = index - center_index
	card.rotation = fan_offset * deg_to_rad(FAN_ANGLE)

	if card_mode == CardMode.ATTACK:
		# === ATTACK CARD SCENE MAPPING ===
		# art → CardArt (kosong kalau gak ada art)
		var art: TextureRect = card.get_node("art")
		if data.card_art:
			art.texture = data.card_art
		else:
			art.texture = null

		# placeholder → CardFrame (sudah ada default)
		_apply_card_flame(card, "placeholder", data)

		# title → NameLabel
		var title_label: Label = card.get_node("title")
		title_label.text = data.card_name

		# staminaCost → CostLabel
		var cost_label: Label = card.get_node("staminaCost")
		cost_label.text = str(int(data.stamina_cost))

		# Label → DescLabel
		var desc_label: Label = card.get_node("Label")
		desc_label.text = data.description

		# Greyed overlay
		var greyed: ColorRect = card.get_node("GreyedOverlay")
		greyed.visible = not has_stamina

		# Tambah dummy ke array supaya index gak geser
		card_glow_panels.append(null)
	else:
		# === SKILL CARD SCENE MAPPING ===
		# Card Art (card_art property)
		var card_art: TextureRect = card.get_node("CardArt")
		card_art.texture = data.card_art

		# Card Frame (cardPlaceholder.png) — already set in tscn
		_apply_card_flame(card, "CardFrame", data)

		# Glow Panel
		var glow: Panel = card.get_node("Glow")
		var glow_style: StyleBoxFlat = glow.get_theme_stylebox("panel").duplicate()
		glow_style.bg_color = Color(data.accent_color.r, data.accent_color.g, data.accent_color.b, 0.15)
		glow_style.border_color = data.accent_color
		glow_style.set_shadow_color(Color(data.accent_color.r, data.accent_color.g, data.accent_color.b, 0.5))
		glow.add_theme_stylebox_override("panel", glow_style)
		glow.modulate.a = 0.0
		card_glow_panels.append(glow)

		# Level (top-left)
		var level_label: Label = card.get_node("LevelContainer/LevelLabel")
		level_label.text = str(data.level)

		# Cost (top-right)
		var cost_label: Label = card.get_node("CostContainer/CostLabel")
		cost_label.text = str(int(data.stamina_cost))

		# Name
		var name_label: Label = card.get_node("NameLabel")
		name_label.text = data.card_name
		name_label.add_theme_color_override("font_color", data.accent_color)

		# Rarity
		var rarity_label: Label = card.get_node("RarityLabel")
		rarity_label.text = data.rarity
		rarity_label.add_theme_color_override("font_color", data.get_rarity_color())

		# Description
		var desc_label: Label = card.get_node("DescLabel")
		desc_label.text = data.description

		# Cooldown overlay
		var cd_overlay: Control = card.get_node("CooldownOverlay")
		cd_overlay.visible = is_on_cooldown
		if is_on_cooldown:
			var cd_number: Label = cd_overlay.get_node("CDNumber")
			cd_number.text = str(cooldown_remaining)

		# Greyed overlay
		var greyed: ColorRect = card.get_node("GreyedOverlay")
		greyed.visible = not has_stamina or is_on_cooldown

		# Kalo kurang stamina: cost jadi merah + gembok biar keliatan
		# "ini belum kebeli" tanpa harus nekat dipencet.
		if not has_stamina:
			cost_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
			var lock := Label.new()
			lock.text = "\u2715"  # ✕-simple, tanpa emoji (gak ada font emoji di HP)
			lock.add_theme_font_size_override("font_size", 16)
			lock.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35, 0.9))
			lock.add_theme_constant_override("outline_size", 4)
			lock.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lock.size = Vector2(18.0, 18.0)
			lock.position = Vector2(CARD_WIDTH * 0.5 - 9.0, CARD_HEIGHT * 0.5 - 9.0)
			card.add_child(lock)

	# Connect input
	card.gui_input.connect(_on_card_input.bind(index))
	card.mouse_entered.connect(_on_card_hover.bind(index))
	card.mouse_exited.connect(_on_card_unhover.bind(index))

	return card


# ============================================================
# ANIMATIONS
# ============================================================

func _animate_spawn() -> void:
	var tw := create_tween().set_parallel(true)

	for i in range(card_nodes.size()):
		var card: Control = card_nodes[i]
		var target_y: float = CARD_Y
		var delay: float = i * 0.1

		tw.tween_property(card, "position:y", target_y, 0.5)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

		card.scale = Vector2(0.3, 0.3)
		tw.tween_property(card, "scale", Vector2.ONE, 0.45)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

	spawn_tween = tw
	tw.chain().tween_callback(_start_idle_float)


func _start_idle_float() -> void:
	for i in range(card_nodes.size()):
		var card: Control = card_nodes[i]
		var delay: float = i * 0.3

		var float_tw := create_tween().set_loops()
		float_tw.tween_property(card, "position:y", CARD_Y - FLOAT_AMPLITUDE, FLOAT_SPEED / 2.0)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		float_tw.tween_property(card, "position:y", CARD_Y, FLOAT_SPEED / 2.0)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		float_tweens.append(float_tw)


func _stop_idle_float() -> void:
	for ft in float_tweens:
		if ft and ft.is_valid():
			ft.kill()
	float_tweens.clear()


func _kill_hover_tween(index: int) -> void:
	if hover_tweens.has(index):
		var ht = hover_tweens[index]
		if ht and ht.is_valid():
			ht.kill()
		hover_tweens.erase(index)


func _kill_all_hover_tweens() -> void:
	for key in hover_tweens.keys():
		var ht = hover_tweens[key]
		if ht and ht.is_valid():
			ht.kill()
	hover_tweens.clear()


func _disable_card_input(card: Control) -> void:
	# IGNORE se-subtree: anak STOP tetep makan klik walau parent IGNORE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disable_input_recursive(card)


func _disable_input_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disable_input_recursive(child)


func _on_card_hover(index: int) -> void:
	if is_selecting:
		return
	if index < 0 or index >= card_nodes.size():
		return

	# Skip hover kalau card cooldown atau stamina kurang
	var data: ActionCardData = cards_data[index]
	var cd: int = card_cooldowns[index] if index < card_cooldowns.size() else 0
	if cd > 0 or current_stamina < data.stamina_cost:
		return

	var card: Control = card_nodes[index]

	if index < float_tweens.size() and float_tweens[index] and float_tweens[index].is_valid():
		float_tweens[index].kill()

	_kill_hover_tween(index)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "position:y", CARD_Y + HOVER_LIFT, 0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), 0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	hover_tweens[index] = tw

	if index < card_glow_panels.size() and card_glow_panels[index]:
		tw.tween_property(card_glow_panels[index], "modulate:a", 1.0, 0.2)


func _on_card_unhover(index: int) -> void:
	if is_selecting:
		return
	if index < 0 or index >= card_nodes.size():
		return

	# Skip unhover kalau card cooldown atau stamina kurang
	var data: ActionCardData = cards_data[index]
	var cd: int = card_cooldowns[index] if index < card_cooldowns.size() else 0
	if cd > 0 or current_stamina < data.stamina_cost:
		return

	var card: Control = card_nodes[index]

	_kill_hover_tween(index)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "position:y", CARD_Y, 0.25)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	hover_tweens[index] = tw

	if index < card_glow_panels.size() and card_glow_panels[index]:
		tw.tween_property(card_glow_panels[index], "modulate:a", 0.0, 0.2)

	# Float baru jalan abis tween balik kelar biar gak tarik-tarikan
	tw.chain().tween_callback(_restart_float.bind(index))


func _restart_float(index: int) -> void:
	if index < 0 or index >= card_nodes.size():
		return
	_kill_hover_tween(index)
	if index < float_tweens.size() and float_tweens[index] and float_tweens[index].is_valid():
		float_tweens[index].kill()
	var card: Control = card_nodes[index]
	var delay: float = index * 0.3

	var float_tw := create_tween().set_loops()
	float_tw.tween_property(card, "position:y", CARD_Y - FLOAT_AMPLITUDE, FLOAT_SPEED / 2.0)\
		.set_delay(delay)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	float_tw.tween_property(card, "position:y", CARD_Y, FLOAT_SPEED / 2.0)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	if index < float_tweens.size():
		float_tweens[index] = float_tw
	else:
		float_tweens.append(float_tw)


# ============================================================
# CARD INPUT
# ============================================================

func _on_card_input(event: InputEvent, index: int) -> void:
	if is_selecting:
		return
	if not event is InputEventMouseButton:
		return
	if not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	# Cek cooldown dan stamina
	var data: ActionCardData = cards_data[index]
	var cd: int = card_cooldowns[index] if index < card_cooldowns.size() else 0
	if cd > 0:
		_reject_card(index, false)
		return
	if current_stamina < data.stamina_cost:
		_reject_card(index, true)
		return

	_select_card(index)


func _reject_card(index: int, is_stamina: bool) -> void:
	# Ditolak? Bilang alasannya, jangan diem-diem (dulu responsnya NOL,
	# bikin player kira bug). Murni visual/sfx, logic gak berubah.
	if index < 0 or index >= card_nodes.size():
		return
	var card: Control = card_nodes[index]
	if not is_instance_valid(card):
		return
	if _reject_tween and _reject_tween.is_valid():
		_reject_tween.kill()
	var base_x: float = card.position.x
	_reject_tween = create_tween()
	_reject_tween.tween_property(card, "position:x", base_x - 6.0, 0.05)\
		.set_trans(Tween.TRANS_SINE)
	_reject_tween.tween_property(card, "position:x", base_x + 6.0, 0.07)\
		.set_trans(Tween.TRANS_SINE)
	_reject_tween.tween_property(card, "position:x", base_x, 0.05)\
		.set_trans(Tween.TRANS_SINE)
	if is_stamina:
		_play_reject_sfx()
		_show_deny_label(card, "Not enough Stamina")


func _play_reject_sfx() -> void:
	# "Tuk" pendek: pitch rendah dari click jadi walau gak ada asset khusus.
	var sfx: AudioStream = null
	if ResourceLoader.exists(REJECT_SFX_PATH):
		sfx = load(REJECT_SFX_PATH)
	if sfx == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = sfx
	p.pitch_scale = 0.7
	p.volume_db = -4.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _show_deny_label(card: Control, msg: String) -> void:
	# Tulisan nongol di atas kartu yang dipencet, lalu naik + fade.
	if _deny_label and is_instance_valid(_deny_label):
		_deny_label.queue_free()
	_deny_label = Label.new()
	_deny_label.text = msg
	_deny_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deny_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_deny_label.add_theme_font_size_override("font_size", 15)
	_deny_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_deny_label.add_theme_constant_override("outline_size", 5)
	_deny_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_deny_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deny_label.size = Vector2(CARD_WIDTH, 20.0)
	_deny_label.position = card.position + Vector2(0.0, -22.0)
	_deny_label.modulate.a = 0.0
	canvas_layer.add_child(_deny_label)
	var tw := create_tween()
	tw.tween_property(_deny_label, "modulate:a", 1.0, 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_deny_label, "position:y", _deny_label.position.y - 14.0, 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_deny_label, "modulate:a", 0.0, 0.3).set_delay(0.35)
	tw.tween_callback(func() -> void:
		if is_instance_valid(_deny_label):
			_deny_label.queue_free()
		_deny_label = null
	)


func _select_card(index: int) -> void:
	is_selecting = true
	selected_index = index
	_stop_idle_float()
	_kill_all_hover_tweens()

	# Kill spawn tween if still running to prevent position:y conflict
	if spawn_tween and spawn_tween.is_running():
		spawn_tween.kill()

	var card: Control = card_nodes[index]

	# Snap card to final spawn position to avoid jump from partial spawn anim
	card.position.y = CARD_Y
	card.scale = Vector2.ONE
	card.rotation = 0.0
	# Matikan klik semua kartu: yang fade-out (modulate 0) tetep STOP dan
	# makan klik mechanic di bawahnya (charge button!) kalau dibiarkan.
	# IGNORE harus se-subtree: TextureRect anak (art/placeholder full-rect)
	# tetep makan klik walau root-nya IGNORE.
	_disable_card_input(card)

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var center_pos: Vector2 = Vector2(
		(viewport_size.x - CARD_WIDTH * SELECT_SCALE) / 2.0,
		(viewport_size.y - CARD_HEIGHT * SELECT_SCALE) / 2.0
	)

	var tw := create_tween()

	# Move to center
	tw.tween_property(card, "position", center_pos, 0.4)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	# Punch scale
	tw.parallel().tween_property(card, "scale", Vector2(1.3, 1.3), 0.1)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2(0.95, 0.95), 0.08)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	tw.tween_property(card, "scale", Vector2(SELECT_SCALE, SELECT_SCALE), 0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	# Full glow
	if index < card_glow_panels.size() and card_glow_panels[index]:
		tw.parallel().tween_property(card_glow_panels[index], "modulate:a", 1.0, 0.15)

	# Reset rotation
	tw.parallel().tween_property(card, "rotation", 0.0, 0.3)\
		.set_trans(Tween.TRANS_CUBIC)

	# Other cards cascade fade out (klik dimatikan biar gak makan input)
	for i in range(card_nodes.size()):
		if i == index:
			continue
		var other: Control = card_nodes[i]
		_disable_card_input(other)
		var delay: float = (i * 0.08)
		var other_tw := create_tween()
		other_tw.tween_property(other, "modulate:a", 0.0, 0.15).set_delay(delay)
		other_tw.parallel().tween_property(other, "position:y", other.position.y + 50, 0.2)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN)
		other_tw.parallel().tween_property(other, "scale", Vector2(0.7, 0.7), 0.2).set_delay(delay)

	# ATTACK MODE: pindah ke pojok kiri atas sebagai indicator
	if card_mode == CardMode.ATTACK:
		tw.tween_interval(0.3)
		tw.tween_callback(func() -> void:
			_move_to_indicator(card)
		)
	else:
		# SKILL MODE: hold, then close (sama kayak sekarang)
		tw.tween_interval(0.6)
		tw.tween_callback(func() -> void:
			card_selected.emit(selected_index)
			var close_tw := create_tween()
			close_tw.tween_property(card, "modulate:a", 0.0, 0.2)
			close_tw.parallel().tween_property(card, "scale", Vector2(0.5, 0.5), 0.25)\
				.set_trans(Tween.TRANS_CUBIC)\
				.set_ease(Tween.EASE_IN)
			close_tw.tween_callback(func() -> void:
				_cleanup()
				card_closed.emit()
			)
		)


# ============================================================
# ATTACK INDICATOR
# ============================================================

func _move_to_indicator(card: Control) -> void:
	"""Pindah card ke pojok kiri atas sebagai indikator selected"""
	attack_indicator = card
	waiting_for_mechanic = true

	# Hide bg overlay
	if bg_overlay:
		bg_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg_tw := create_tween()
		bg_tw.tween_property(bg_overlay, "modulate:a", 0.0, 0.2)

	# Pindah ke pojok kiri atas (scale kecil)
	var indicator_pos: Vector2 = Vector2(10, 10)
	var indicator_scale: Vector2 = Vector2(0.95, 0.95)

	var tw := create_tween().set_parallel(true)
	tw.set_ignore_time_scale(true)
	tw.tween_property(card, "position", indicator_pos, 0.3)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", indicator_scale, 0.3)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "rotation", 0.0, 0.2)

	# Emit selected
	card_selected.emit(selected_index)
	attack_indicator_ready.emit()


func finish_attack_indicator() -> void:
	"""Fade out indicator card setelah mechanic selesai"""
	if attack_indicator and is_instance_valid(attack_indicator):
		var tw := create_tween()
		tw.tween_property(attack_indicator, "modulate:a", 0.0, 0.3)
		tw.parallel().tween_property(attack_indicator, "scale", Vector2(0.3, 0.3), 0.3)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			_cleanup()
			card_closed.emit()
		)
	else:
		_cleanup()
		card_closed.emit()


# ============================================================
# CLOSE
# ============================================================

func _on_bg_input(event: InputEvent) -> void:
	if is_selecting:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func close() -> void:
	if is_selecting:
		return
	_cleanup()
	card_closed.emit()


func _cleanup() -> void:
	is_open = false
	is_selecting = false
	selected_index = -1
	_stop_idle_float()
	_kill_all_hover_tweens()
	if _reject_tween and _reject_tween.is_valid():
		_reject_tween.kill()
	_reject_tween = null
	if _deny_label and is_instance_valid(_deny_label):
		_deny_label.queue_free()
	_deny_label = null

	if canvas_layer and is_instance_valid(canvas_layer):
		canvas_layer.queue_free()
		canvas_layer = null

	card_nodes.clear()
	card_glow_panels.clear()
