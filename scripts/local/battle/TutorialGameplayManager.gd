extends "res://scripts/local/battle/BattleManager.gd"
class_name TutorialGameplayManager

# ============================================================
# TUTORIAL GAMEPLAY MANAGER
# extends BattleManager. Override HANYA yang perlu dibedain —
# BattleManager.gd sendiri 100% utuh.
#
# Aturan main:
#  - 3 wave: Skeleton (latihan) -> Skeleton (potion) -> Grimward
#  - Tiap gerakan ada tutorialnya; panel selalu bilang STEP k/N
#    + JUDUL + isi, spotlight gelap ke target, yang lain dikunci
#  - Tombol action MUNCUL SATU-SATU sesuai kebutuhan (reveal
#    bertahap), bukan sekaligus di awal
#  - Deck attack tutorial itu FIX: [Basic, Charge, Rapid]
#  - Skeleton wave-1 pakai "training armor" (damage ~1) biar gak
#    mati sebelum semua gerakan kelar diajarin
#  - Wave 2: HP ke 25% lewat serangan skeleton BENERAN (damage
#    serangannya di-script), bukan damage dadakan
#  - Drill parry LIVE & bisa diulang: jendela 6 dtk, miss -> "TRY
#    AGAIN" -> forced attack lagi. Tanpa pause, tanpa swallow.
#    KECUALI musik yang jalan terus
#  - Transisi step nunggu: giliran beneran balik + kamera settle
#    + dwell min 1.2 detik (gak kecepetan, gak kebanyakan stop)
#  - HP floor 25% (player gak bisa mati di tutorial)
#  - Gak ada tombol skip
# ============================================================

signal tutorial_finished
signal tutorial_complete

# --- Konstanta flow ---
const HP_FLOOR_PCT := 0.25
const TUTORIAL_DROP_ID := "health_potion"
const TRAINING_DEFENSE := 9999.0
const IDLE_DWELL_MS := 1200
const IDLE_FALLBACK_MS := 4000
const BASIC_PATH := "res://data/action_cards/attack_cards/basic_attack.tres"
const CHARGE_PATH := "res://data/action_cards/attack_cards/charge_attack.tres"
const RAPID_PATH := "res://data/action_cards/attack_cards/rapid_attack.tres"

# --- Step (URUT = urutan main; nomor STEP di panel dari sini) ---
enum Step {
	IDLE,
	WELCOME,
	TARGET_ACT,
	ATTACK_ACT,
	BASIC_PICK,
	QTE_DO,
	QTE_RESULT,
	QTE_MISS,
	PARRY_WAIT,
	PARRY_DRILL,
	PARRY_MISS,
	PARRY_RESULT,
	PARRY_WHY,
	DEFEND_ACT,
	SKILL_ACT,
	SKILL_PICK,
	CHARGE_PICK_WAIT,
	CHARGE_PICK,
	CHARGE_DO,
	RAPID_PICK_WAIT,
	RAPID_PICK,
	RAPID_DO,
	FINISH_INTRO,
	FINISH_ACT,
	FINISH_PICK,
	FINISH_QTE,
	FINISH_MISS,
	FINISH_AFTER,
	LOOT_ACT,
	LOOT_DONE,
	PACK_ACT,
	PACK_VIEW,
	PACK_CLOSE,
	WAVE2_INTRO,
	HURT_WAIT,
	HURT_INFO,
	PACK2_ACT,
	POTION_SLOT,
	POTION_INFO,
	POTION_USE,
	HEALED,
	WAVE2_FIGHT,
	WAVE2_PICK,
	WAVE2_QTE,
	WAVE2_AFTER,
	WAVE3_INTRO,
	WAVE3_FIGHT,
	WAVE3_PICK,
	WAVE3_QTE,
	WAVE3_AFTER,
	WAVE3_DONE,
	COMPLETE,
}

# --- State runtime ---
var _tutorial_active := false
var _step: Step = Step.IDLE
var _tutorial_ui: TutorialUI = null
var _tutorial_layer: CanvasLayer = null
var _wave_index := 0
var _pending_scripted_damage := false
var _drop_node: Node = null
var _tutorial_inv_before := 0
var _tutorial_heal_before := -1.0
var _tut_revealed: Array = []
var _tut_enabled: Array = []
var _locked_nodes: Array[Control] = []
var _saved_disabled: Dictionary = {}
var _saved_mouse_filters: Dictionary = {}
var _saved_process_mode: Dictionary = {}
var _always_nodes: Array = []
var _pending_idle_step: Step = Step.IDLE
var _pending_idle_since: int = 0
var _force_parry_turn := false
var _force_hurt_turn := false
var _hurt_turn_active := false
# Drill parry lagi kebuka (window 6 dtk, boleh miss -> retry).
var _drill_armed := false
# Tahan enemy turn pasca-QTE (jangan auto-start), mulai manual
# habis beat PARRY_WAIT. Cegah balapan: drill dadakan pas baca hasil.
var _hold_enemy_turn := false
# Timestamp mulai beat PARRY_WAIT (msec) + turn udah distart manual?
var _parry_wait_since := 0
var _turn_started := false
const PARRY_BEAT_MS := 1500
var _rapid_taught := false
var _w3_baseline_attacks := 0
var _w3_baseline_miss := 0
var _potion_index := -1
var _loot_collected := false
# Kapan skeleton wave-2 terpantau mati (msec). Beat jeda sebelum
# grimward spawn biar gak nempel: cleared panel dulu 2.5 dtk.
var _wave2_cleared_at: int = -1
const WAVE_CLEAR_BEAT_MS := 2500
var _pick_expected := ""
var _pick_is_skill := false
var _skill_ui_ref: ActionCardUI = null


func _ready() -> void:
	_wave_index = 0
	_tutorial_active = true
	super._ready()
	_setup_tutorial_layer()
	_tut_revealed.clear()
	_tut_enabled.clear()
	_apply_button_gating(false)
	_set_enemy_clickable_all(false)
	total_waves = 3
	current_wave = 1
	if wave_progress:
		wave_progress.set_wave(1, 3)
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(self):
		_begin_step(Step.WELCOME)


func _setup_tutorial_layer() -> void:
	if _tutorial_layer and is_instance_valid(_tutorial_layer):
		return
	_tutorial_layer = CanvasLayer.new()
	_tutorial_layer.name = "tutorialLayer"
	_tutorial_layer.layer = 300
	_tutorial_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_tutorial_layer)
	_tutorial_ui = TutorialUI.new()
	_tutorial_ui.setup(_tutorial_layer, get_node_or_null("tutorialPanel") as Panel)
	if not _tutorial_ui.tapped.is_connected(_on_tutorial_tapped):
		_tutorial_ui.tapped.connect(_on_tutorial_tapped)
	if not _tutorial_ui.finished.is_connected(_on_tutorial_finished):
		_tutorial_ui.finished.connect(_on_tutorial_finished)


# ============================================================
# TAP PANEL (step BACA dismissable -> "lanjut")
# ============================================================

func _on_tutorial_tapped() -> void:
	if not _tutorial_active or _step == Step.IDLE:
		return
	match _step:
		Step.WELCOME:
			_begin_step(Step.TARGET_ACT)
		Step.QTE_RESULT:
			_begin_step(Step.PARRY_WAIT)
		Step.PARRY_WHY:
			_begin_step(Step.DEFEND_ACT)
		Step.QTE_MISS:
			_begin_step(Step.ATTACK_ACT)
		Step.PARRY_MISS:
			# Retry drill: panel tutup, tunggu idle beneran, balik
			# ke PARRY_WAIT (beat + manual start di sana).
			_ui_hide()
			_wait_for_idle_then(Step.PARRY_WAIT)
		Step.FINISH_INTRO:
			_set_training_armor_all(false)
			_refill_stamina()
			set_meta("_tut_fin_miss", total_miss)
			_begin_step(Step.FINISH_ACT)
		Step.FINISH_MISS:
			set_meta("_tut_fin_miss", total_miss)
			_begin_step(Step.FINISH_ACT)
		Step.LOOT_DONE:
			_begin_step(Step.PACK_ACT)
		Step.PACK_VIEW:
			_begin_step(Step.PACK_CLOSE)
		Step.POTION_INFO:
			_begin_step(Step.POTION_USE)
		Step.WAVE2_INTRO:
			_begin_step(Step.HURT_WAIT)
		Step.HURT_INFO:
			_begin_step(Step.PACK2_ACT)
		Step.HEALED:
			# Potion dimimun = giliran kemakan (enemy turn jalan).
			# FIGHT baru nongol pas idle beneran, bukan di tengah turn.
			_wait_for_idle_then(Step.WAVE2_FIGHT)
		Step.WAVE3_INTRO:
			_begin_step(Step.WAVE3_FIGHT)
		Step.WAVE3_DONE:
			_begin_step(Step.COMPLETE)
		_:
			pass


func _on_tutorial_finished() -> void:
	if not _tutorial_active:
		return
	_tutorial_active = false
	_pending_idle_step = Step.IDLE
	_unlock_all()
	# Battle balik normal: lepas semua armor latihan.
	_set_training_armor_all(false)
	_tut_revealed = [atk_btn, defend_btn, backpack_btn, run_btn, skill_btn]
	_tut_enabled = [atk_btn, defend_btn, backpack_btn, run_btn, skill_btn]
	_apply_button_gating(true)
	_set_enemy_clickable_all(true)
	tutorial_finished.emit()
	tutorial_complete.emit()


# ============================================================
# OVERRIDE: DECK — tutorial pakai deck FIX
# ============================================================

func _load_attack_cards() -> void:
	if not _tutorial_active:
		super._load_attack_cards()
		return
	attack_hand.clear()
	attack_discard.clear()
	for path in [BASIC_PATH, CHARGE_PATH, RAPID_PATH]:
		var data: AttackCardData = load(path) as AttackCardData
		if data:
			attack_hand.append(data.duplicate())


func _attack_index_of(attack_type: String) -> int:
	for i in range(attack_hand.size()):
		var c: AttackCardData = attack_hand[i]
		if c and c.attack_type == attack_type:
			return i
	return -1


# Deck W3 dipaksa BASIC only biar mekaniknya pasti QTE.
func _force_basic_hand() -> void:
	attack_hand.clear()
	attack_discard.clear()
	var data: AttackCardData = load(BASIC_PATH) as AttackCardData
	if data:
		attack_hand.append(data.duplicate())


# ============================================================
# OVERRIDE: TOMBOL — reveal bertahap
# ============================================================

func _set_buttons_active(show_buttons: bool, instant: bool = false) -> void:
	if not _tutorial_active:
		super._set_buttons_active(show_buttons, instant)
		return
	_apply_button_gating(show_buttons)


func _set_buttons_active_staggered() -> void:
	if not _tutorial_active:
		super._set_buttons_active_staggered()
		return
	_apply_button_gating(false)


func _apply_button_gating(show_buttons: bool) -> void:
	var pairs: Array = [
		[atk_btn, original_atk_pos],
		[defend_btn, original_def_pos],
		[backpack_btn, original_backpack_pos],
		[run_btn, original_run_post],
		[skill_btn, original_skill_post],
	]
	for pair in pairs:
		var b: Button = pair[0]
		var orig: Vector2 = pair[1]
		if b == null:
			continue
		var vis: bool = show_buttons and (b in _tut_revealed)
		# Instant: gating jalan juga pas tree paused.
		b.position.y = orig.y if vis else orig.y + 200.0
		b.disabled = not (vis and (b in _tut_enabled))


# Tiap step deklarasi TOMBOL APA YANG BOLEH NONGOL (visible) dan
# mana yang boleh dipencet (enabled). Selain itu = ngumpet di bawah
# layar + disabled. Gak ada akumulasi: tiap step mulai dari nol.
func _show_only(vis: Array, en: Array = []) -> void:
	_tut_revealed.clear()
	_tut_enabled.clear()
	for b in vis:
		if b and not (b in _tut_revealed):
			_tut_revealed.append(b)
	for b in en:
		if b and (b in _tut_revealed) and not (b in _tut_enabled):
			_tut_enabled.append(b)
	_apply_button_gating(true)


# ============================================================
# OVERRIDE: SPAWN — skeleton -> skeleton -> grimward
# ============================================================

func _spawn_enemies(_enemy_ids: Array[String], _custom_levels: Array[int] = []) -> void:
	if not _tutorial_active:
		super._spawn_enemies(_enemy_ids, _custom_levels)
		return
	if _wave_index == 0:
		_wave_index = 1
		for e in enemies:
			if is_instance_valid(e):
				e.queue_free()
		enemies.clear()
		selected_enemy_index = 0
		super._spawn_enemies(["skeleton"] as Array[String], [1] as Array[int])
		await get_tree().process_frame
		if is_instance_valid(self) and not enemies.is_empty():
			_set_training_armor(enemies[0], true)


func _tutorial_spawn(ids: Array[String], levels: Array[int]) -> void:
	super._spawn_enemies(ids, levels)


func _set_training_armor(enemy: BattleEnemy, on: bool) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if on:
		if not enemy.has_meta("_tut_base_def"):
			enemy.set_meta("_tut_base_def", enemy.scaled_defense)
		enemy.scaled_defense = TRAINING_DEFENSE
	else:
		if enemy.has_meta("_tut_base_def"):
			enemy.scaled_defense = float(enemy.get_meta("_tut_base_def"))
			enemy.remove_meta("_tut_base_def")


func _set_training_armor_all(on: bool) -> void:
	for e in enemies:
		if is_instance_valid(e):
			_set_training_armor(e, on)


# Bersihin SEMUA musuh sisa (corpse yang belum ke-free / musuh hidup
# wave lama) sebelum spawn wave baru — anti bertubrukan/overlap.
func _cleanup_battlefield() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	selected_enemy_index = 0


# ============================================================
# OVERRIDE: PARRY WINDOW — pause-aware + instant (tanpa tween)
# ============================================================

func _show_parry_window(duration: float = 1.0) -> void:
	if not _tutorial_active:
		super._show_parry_window(duration)
		return
	if not parry_btn:
		return
	# Wave-2 hurt: parry window DI-SKIP sepenuhnya. Kalau kebuka,
	# player bisa parry dan HP gak mendarat di 25% (script bocor).
	if _step == Step.HURT_WAIT:
		return
	parry_success_this_turn = false
	is_parry_window_active = true
	parry_extra_reduction = 0.0
	total_parry_attempts += 1
	parry_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	parry_btn.disabled = false
	parry_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var viewport_size = get_viewport().get_visible_rect().size
	parry_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	parry_btn.position = Vector2(
		randf_range(120.0, viewport_size.x - 220.0),
		randf_range(150.0, viewport_size.y - 250.0)
	)
	parry_btn.modulate = Color(1, 1, 1, 1)
	parry_btn.scale = Vector2(0.100, 0.095)
	parry_btn.show()
	if parry_timing_bar:
		parry_timing_bar.value = parry_timing_bar.max_value
	if parry_timer != null:
		parry_timer = null
	# Drill parry: jendela PANJANG (6 dtk) biar sempat baca prompt.
	# Window natural (di luar drill): durasi parent apa adanya.
	var real_duration := 6.0 if _drill_armed else duration
	parry_timer = get_tree().create_timer(real_duration, false)
	await parry_timer.timeout
	if not is_instance_valid(self):
		return
	if parry_btn.visible and not parry_success_this_turn:
		if _tutorial_active and _drill_armed and _step == Step.PARRY_DRILL:
			# MISS pas drill -> sembunyiin window, kasih rute retry.
			_drill_armed = false
			_hide_parry_window()
			_begin_step(Step.PARRY_MISS)
			return
		var visual_center = parry_btn.position + Vector2(40, 40)
		_spawn_missed_popup_text(visual_center)
		_hide_parry_window()


# ============================================================
# OVERRIDE: RAPID START — pastikan tombol enabled
# ============================================================

func _start_attack_raptive() -> void:
	super._start_attack_raptive()
	if _tutorial_active and rapid_btn:
		rapid_btn.disabled = false
		rapid_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		rapid_btn.process_mode = Node.PROCESS_MODE_ALWAYS


# ============================================================
# OVERRIDE: ENEMY TURN PAKSA
# - parry lesson: skeleton pasti ATTACK (AI bisa defend/skip)
# - hurt lesson wave-2: damage serangannya di-script ke 25%
# ============================================================

func _start_enemies_turn() -> void:
	if not _tutorial_active or (not _force_parry_turn and not _force_hurt_turn):
		super._start_enemies_turn()
		return
	var is_hurt := _force_hurt_turn
	_force_parry_turn = false
	_force_hurt_turn = false
	if is_hurt:
		_hurt_turn_active = true
	_update_target_selection()
	var live: Array = enemies.filter(func(e): return is_instance_valid(e) and e.current_hp > 0)
	if live.is_empty():
		_finish_forced_turn()
		return
	var enemy: BattleEnemy = live[0]
	current_enemy_attacking = enemy
	_pull_hand_to_corner(0.4)
	if enemy.enemy_collision:
		enemy.enemy_collision.disabled = true
	if is_hurt:
		# Damage serangan ini di-script mendarat PAS di 25%.
		_pending_scripted_damage = true
	await enemy._execute_attack(camera, default_camera_pos, 1.0, "Attacking!", EnemyAI.Emotion.CALM)
	if not is_instance_valid(self):
		return
	_finish_forced_turn()


func _finish_forced_turn() -> void:
	if not is_instance_valid(self) or not _tutorial_active:
		return
	_pull_hand_to_corner(0.4)
	for e in enemies:
		if is_instance_valid(e) and e.current_hp > 0 and e.enemy_collision:
			e.enemy_collision.disabled = false
	_reset_hand_to_original(0.4)
	_update_target_selection()
	if enemies.size() > 0:
		is_player_turn = true
		# Tombol tetap ngumpet sampai step berikutnya deklarasi
		# via _show_only() — jangan nampilin sisa step lama.
		_apply_button_gating(false)
		_process_action_card_cooldowns()
	if _hurt_turn_active:
		_hurt_turn_active = false
		_wait_for_idle_then(Step.HURT_INFO)


# ============================================================
# OVERRIDE: DEATH — wave logic parent dimatiin (tutorial ngatur)
# ============================================================

func _process_enemy_death(_exp_amount: int, _gold_amount: int, _dropped_items: Array[String], enemy: BattleEnemy) -> void:
	if not _tutorial_active:
		super._process_enemy_death(_exp_amount, _gold_amount, _dropped_items, enemy)
		return
	enemies_killed += 1
	if is_instance_valid(enemy):
		EventBus.enemy_killed.emit(enemy.enemy_id)
	# Drop potion cuma wave-1 (pelajaran loot). Wave-2 mati -> langsung
	# wave-3, gak ada loot keenam.
	if _wave_index == 1:
		_tutorial_force_drop(enemy)
	_update_target_selection()


func _tutorial_force_drop(enemy: BattleEnemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var pos := enemy.global_position
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(self):
		return
	var drop = _spawn_drop_item_keep(TUTORIAL_DROP_ID, pos, 0.0)
	if drop:
		_drop_node = drop


func _spawn_drop_item_keep(item_id: String, enemy_pos: Vector2, spawn_delay: float = 0.0) -> Node:
	var item := _load_item_by_id(item_id)
	if not item or not item_drop_template or not drop_layer:
		return null
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * enemy_pos
	var ground_pos := screen_pos + Vector2(randf_range(-50.0, 50.0), randf_range(65.0, 85.0))
	var drop_visual := item_drop_template.duplicate() as ItemDropVisual
	if not drop_visual:
		return null
	drop_visual.item_clicked.connect(_on_drop_item_clicked)
	drop_visual.collect_finished.connect(_on_drop_collect_finished)
	drop_layer.add_child(drop_visual)
	drop_visual.setup(item, screen_pos, ground_pos, spawn_delay)
	drop_visual.set_process(false)
	var timer := _find_timer_recursive(drop_visual)
	if timer:
		timer.paused = true
	var timing := drop_visual.get_node_or_null("timing") as TextureProgressBar
	if timing:
		timing.value = timing.max_value
	return drop_visual


func _on_drop_collect_finished(_item: ItemData) -> void:
	super._on_drop_collect_finished(_item)
	_loot_collected = true


func _find_timer_recursive(node: Node) -> Timer:
	for c in node.get_children():
		if c is Timer:
			return c as Timer
		var found := _find_timer_recursive(c)
		if found:
			return found
	return null


# ============================================================
# OVERRIDE: DAMAGE — HP floor + hurt script wave-2
# (Tanpa pause = mekanik real semua; gak ada yang perlu di-swallow.)
# ============================================================

func apply_damage(event: DamageEvent) -> void:
	if not _tutorial_active:
		super.apply_damage(event)
		return
	# Drill miss: hit musuh mendarat TANPA parry (window ditutup parent
	# pas damage masuk, ~1 dtk — jadi timeout gak pernah kepanggil;
	# miss dideteksi dari sini, bukan dari timer). Super tetap jalan
	# biar HP/suara/visual natural, terus rute retry.
	if _step == Step.PARRY_DRILL and event.source == DamageEvent.Source.NORMAL:
		super.apply_damage(event)
		if current_hp < max_hp * HP_FLOOR_PCT:
			current_hp = max_hp * HP_FLOOR_PCT
			if hp_bar:
				_update_player_ui_instant()
		_drill_armed = false
		_begin_step(Step.PARRY_MISS)
		return
	# Hurt wave-2: damage serangan di-script mendarat PAS di 25%.
	if _pending_scripted_damage:
		_pending_scripted_damage = false
		var target_hp: float = max_hp * HP_FLOOR_PCT
		var needed: float = max(0.0, current_hp - target_hp) + player_durability
		event.base_damage = needed
	super.apply_damage(event)
	# HP floor: jangan pernah di bawah 25%.
	if current_hp < max_hp * HP_FLOOR_PCT:
		current_hp = max_hp * HP_FLOOR_PCT
		if hp_bar:
			_update_player_ui_instant()


# ============================================================
# FLOW UTAMA (watcher — jalan pas tree live)
# ============================================================

func _process(_delta: float) -> void:
	super._process(_delta)
	if not _tutorial_active:
		return
	# Step berikutnya cuma nongol kalau: giliran beneran balik,
	# kamera udah settle, DAN dwell minimum lewat (gak kecepetan).
	if _pending_idle_step != Step.IDLE:
		var elapsed: int = Time.get_ticks_msec() - _pending_idle_since
		var ready: bool = elapsed >= IDLE_DWELL_MS and _is_player_idle() and _is_camera_settled()
		var fallback: bool = is_player_turn and elapsed >= IDLE_FALLBACK_MS
		if ready or fallback:
			var s := _pending_idle_step
			_pending_idle_step = Step.IDLE
			_begin_step(s)
			return
	match _step:
		Step.PARRY_WAIT:
			# Beat 1.5 dtk, baru turn dimulai manual. Deterministik:
			# gak peduli tap cepat/lambat, drill selalu mulai sama.
			if not _turn_started and Time.get_ticks_msec() - _parry_wait_since >= PARRY_BEAT_MS:
				_turn_started = true
				_hold_enemy_turn = false
				_force_parry_turn = true
				is_player_turn = false
				_apply_button_gating(false)
				_start_enemies_turn()
		Step.POTION_SLOT:
			if _potion_ready_to_use():
				_begin_step(Step.POTION_INFO)
		Step.POTION_USE:
			if _tutorial_heal_before >= 0.0 and current_hp > _tutorial_heal_before + 1.0:
				_tutorial_heal_before = -1.0
				_begin_step(Step.HEALED)
		Step.LOOT_ACT:
			if _loot_collected or _tutorial_inventory_count() > _tutorial_inv_before:
				_loot_collected = false
				_begin_step(Step.LOOT_DONE)
		Step.RAPID_DO:
			if _rapid_taught and not _is_rapid_active:
				_rapid_taught = false
				_live("RAPID COMPLETE", "That's rapid attack! Enemy turn...", TutorialUI.Zone.BOTTOM_LEFT, null)
				_wait_for_idle_then(Step.FINISH_INTRO)
		Step.FINISH_AFTER:
			if enemies.is_empty() and _drop_node and is_instance_valid(_drop_node) and _is_camera_settled():
				_begin_step(Step.LOOT_ACT)
			elif _is_player_idle() and _is_camera_settled():
				# LOW hit (32 dmg) gak bunuh skeleton 50HP -> serang lagi.
				_begin_step(Step.FINISH_ACT)
		Step.WAVE2_AFTER:
			# Mati -> kasih NAPAS dulu (panel cleared + beat 2.5 dtk),
			# baru grimward. Jangan langsung spawn, kecepetan.
			# Miss (masih hidup) -> giliran balik, serang lagi via FIGHT.
			if enemies.is_empty():
				if _wave2_cleared_at < 0:
					_wave2_cleared_at = Time.get_ticks_msec()
					_apply_button_gating(false)
					_live("WAVE 2 CLEARED!", "The Skeleton crumbles. Catch your breath...", TutorialUI.Zone.TOP_CENTER, null)
				elif Time.get_ticks_msec() - _wave2_cleared_at >= WAVE_CLEAR_BEAT_MS and _is_camera_settled():
					_wave2_cleared_at = -1
					_goto_wave3()
			elif _is_player_idle() and _is_camera_settled():
				_wave2_cleared_at = -1
				_begin_step(Step.WAVE2_FIGHT)
		Step.PACK_VIEW:
			pass  # read, tap -> PACK_CLOSE (di tapped-match)
		Step.PACK_CLOSE:
			if not is_inventory_open:
				_goto_wave2()
		Step.WAVE3_AFTER:
			if _is_player_idle() and _is_camera_settled() and total_attacks > _w3_baseline_attacks:
				_begin_step(Step.WAVE3_DONE)


func _is_player_idle() -> bool:
	if not is_player_turn:
		return false
	if is_card_ui_open or is_inventory_open or _is_rapid_active:
		return false
	for e in enemies:
		if is_instance_valid(e) and e.is_taking_turn:
			return false
	return true


func _is_camera_settled() -> bool:
	if camera == null:
		return true
	if camera.zoom.distance_to(Vector2.ONE) > 0.08:
		return false
	if camera.global_position.distance_to(default_camera_pos) > 12.0:
		return false
	return true


func _wait_for_idle_then(step: Step) -> void:
	_pending_idle_step = step
	_pending_idle_since = Time.get_ticks_msec()


func _tutorial_inventory_count() -> int:
	var pd = PlayerDataManager.data
	if pd == null or pd.battle_inventory == null or pd.battle_inventory.items == null:
		return 0
	return pd.battle_inventory.items.size()


func _ensure_loot_space() -> void:
	# Tutorial run yang ditinggal bisa ninggalin potion numpuk sampe
	# inventory 9/9 -> collect FAIL -> softlock. Buang 1 potion.
	var pd = PlayerDataManager.data
	if pd == null or pd.battle_inventory == null or pd.battle_inventory.items == null:
		return
	var items: Array = pd.battle_inventory.items
	for it in items:
		if it == null:
			return
	if items.size() < 9:
		return
	for i in range(items.size()):
		var it: ItemData = items[i]
		if it and it.item_id == TUTORIAL_DROP_ID:
			PlayerDataManager.remove_item(i)
			return


func _refill_stamina() -> void:
	current_stamina = max_stamina
	_animate_stamina_change()


# ============================================================
# HANDLER OVERRIDES
# ============================================================

func _on_enemy_clicked(clicked_enemy: BattleEnemy) -> void:
	super._on_enemy_clicked(clicked_enemy)
	if not _tutorial_active or _step != Step.TARGET_ACT:
		return
	if not is_player_turn:
		return  # bukan giliran — tap lagi nanti
	_begin_step(Step.ATTACK_ACT)


func _on_attack_pressed() -> void:
	if not _tutorial_active:
		super._on_attack_pressed()
		return
	if _step == Step.ATTACK_ACT:
		_try_open_attack_deck(Step.BASIC_PICK)
	elif _step == Step.CHARGE_PICK_WAIT:
		_try_open_attack_deck(Step.CHARGE_PICK)
	elif _step == Step.RAPID_PICK_WAIT:
		_try_open_attack_deck(Step.RAPID_PICK)
	elif _step == Step.FINISH_ACT:
		# Retry MISS menghabiskan Basic (hand sisa [Charge, Rapid]) ->
		# reload trio biar finisher selalu ada. Tanpa ini PICK stuck
		# tanpa kartu Basic dan player gak bisa lanjut.
		if _attack_index_of("Basic") == -1:
			_load_attack_cards()
		_try_open_attack_deck(Step.FINISH_PICK)
	elif _step == Step.WAVE2_FIGHT:
		if _attack_index_of("Basic") == -1:
			_load_attack_cards()
		_try_open_attack_deck(Step.WAVE2_PICK)
	elif _step == Step.WAVE3_FIGHT:
		_try_open_attack_deck(Step.WAVE3_PICK)


# Buka deck attack + pindah step HANYA kalau deck beneran kebuka.
# Dua arah dijaga: jangan buka selagi deck lama masih nutup (callback
# close basi ngebunuh referensi deck baru), dan jangan pindah step kalau
# super diem-diem return (mis. tap pas bukan giliran).
func _try_open_attack_deck(next: Step) -> void:
	if is_card_ui_open:
		return
	super._on_attack_pressed()
	if not is_card_ui_open:
		return
	_begin_step(next)


func _on_attack_card_selected(index: int) -> void:
	if not _tutorial_active:
		super._on_attack_card_selected(index)
		return
	var expected := ""
	match _step:
		Step.BASIC_PICK:
			expected = "Basic"
		Step.CHARGE_PICK:
			expected = "Charge"
		Step.RAPID_PICK:
			expected = "Rapid"
		Step.FINISH_PICK:
			expected = "Basic"
		Step.WAVE2_PICK:
			expected = "Basic"
		Step.WAVE3_PICK:
			expected = "Basic"
		_:
			return
	var card: AttackCardData = attack_hand[index] if index >= 0 and index < attack_hand.size() else null
	if card == null:
		return
	if expected != "" and card.attack_type != expected:
		return
	if current_stamina < card.stamina_cost:
		_refill_stamina()
	# Parry lesson: enemy turn MULAI otomatis habis deck ditutup
	# (parent chain). Flag forced harus ke-set SEBELUM itu.
	if _step == Step.BASIC_PICK:
		_force_parry_turn = true
	super._on_attack_card_selected(index)
	match _step:
		Step.BASIC_PICK:
			_begin_step(Step.QTE_DO)
		Step.CHARGE_PICK:
			_begin_step(Step.CHARGE_DO)
		Step.RAPID_PICK:
			_rapid_taught = true
			_begin_step(Step.RAPID_DO)
		Step.FINISH_PICK:
			_begin_step(Step.FINISH_QTE)
		Step.WAVE2_PICK:
			_begin_step(Step.WAVE2_QTE)
		Step.WAVE3_PICK:
			_w3_baseline_attacks = total_attacks
			_w3_baseline_miss = total_miss
			_begin_step(Step.WAVE3_QTE)


func _check_attack_qte_result() -> void:
	var was_active := is_attack_qte_active
	var miss_before := total_miss
	super._check_attack_qte_result()
	if not _tutorial_active:
		return
	if not was_active:
		return  # resolve basi (QTE udah gak aktif) — jangan pindah step
	match _step:
		Step.QTE_DO:
			# Miss = total_miss nambah. Miss -> kartu basic dibalikin,
			# flag parry + used dimatiin (JANGAN enemy turn dulu),
			# retry sampai QTE-nya berhasil.
			if total_miss > miss_before:
				_force_parry_turn = false
				attack_card_used_this_session = false
				var basic: AttackCardData = load(BASIC_PATH) as AttackCardData
				if basic:
					attack_hand.append(basic.duplicate())
				_step = Step.QTE_MISS
				_read("MISSED!", "Watch the runner — TAP TO TRY AGAIN.", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
			else:
				# Hit: TAHAN enemy turn (jangan auto-start), mulai manual
				# habis beat PARRY_WAIT. Biar drill gak dadakan.
				_hold_enemy_turn = true
				_turn_started = false
				_begin_step(Step.QTE_RESULT)
		Step.FINISH_QTE:
			if total_miss > int(get_meta("_tut_fin_miss", total_miss)):
				_step = Step.FINISH_MISS
				_read("MISSED!", "No damage. Tap to try the finishing blow again.", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
			else:
				_step = Step.FINISH_AFTER
				_live("DIRECT HIT!", "Finishing blow landed!", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.WAVE2_QTE:
			_step = Step.WAVE2_AFTER
			_live("STRIKE!", "Did it go down?", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.WAVE3_QTE:
			# Miss -> serang lagi (counter cuma keluar pas hit kena).
			if total_miss > _w3_baseline_miss:
				_begin_step(Step.WAVE3_FIGHT)
			else:
				_step = Step.WAVE3_AFTER
				_live("ATTACK LANDED", "Watch out — Grimward can counter!", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())


func _on_enemy_attack_preparing() -> void:
	super._on_enemy_attack_preparing()
	if not _tutorial_active:
		return
	# Pelajaran parry wave-1: super di atas udah buka window (durasi
	# drill karena _drill_armed). Fade-out spotlight dulu (~0.35 dtk,
	# live) biar menciut smooth, BARU spot muncul di tombol parry.
	if _step == Step.PARRY_WAIT or _step == Step.QTE_RESULT:
		_fade_then_drill()


# Fade-then-spot: gelap lama menciut dulu, baru lubang muncul di
# tombol parry. Guard berlapis biar gak nyasar kalau step pindah.
func _fade_then_drill() -> void:
	_tutorial_ui.clear_spotlight()
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(self) or not _tutorial_active:
		return
	if _step != Step.PARRY_WAIT and _step != Step.QTE_RESULT:
		return
	var live: Array = enemies.filter(func(e): return is_instance_valid(e) and e.current_hp > 0)
	if live.is_empty():
		return
	_begin_step(Step.PARRY_DRILL)


func _on_parry_button_clicked() -> void:
	if not _tutorial_active:
		super._on_parry_button_clicked()
		return
	if _step == Step.PARRY_DRILL:
		if not is_parry_window_active:
			return  # window udah tutup — tap basi, abaikan
		# Sukses — drill selesai, musuh selesaikan serangan live.
		_drill_armed = false
		super._on_parry_button_clicked()
		_begin_step(Step.PARRY_RESULT)
		return
	# Window parry di luar drill (mis. cry wave-3): efeknya aja.
	super._on_parry_button_clicked()


func _on_defend_pressed() -> void:
	if not _tutorial_active:
		super._on_defend_pressed()
		return
	if _step != Step.DEFEND_ACT:
		return
	if not is_player_turn:
		return  # bukan giliran — tap lagi nanti
	_live("GUARD UP!", "Stamina +20. Enemy turn — watch what happens.", TutorialUI.Zone.BOTTOM_LEFT, null)
	super._on_defend_pressed()
	_wait_for_idle_then(Step.SKILL_ACT)


func _on_skill_pressed() -> void:
	if not _tutorial_active:
		super._on_skill_pressed()
		return
	if _step != Step.SKILL_ACT:
		return
	super._on_skill_pressed()
	if not is_card_ui_open:
		return  # deck gagal kebuka — tap lagi nanti
	_skill_ui_ref = null
	_begin_step(Step.SKILL_PICK)


func _on_action_card_selected(index: int) -> void:
	if not _tutorial_active:
		super._on_action_card_selected(index)
		return
	if _step != Step.SKILL_PICK:
		return
	if index != 0:
		return
	if index < 0 or index >= action_cards.size():
		return
	_refill_stamina()
	super._on_action_card_selected(index)
	_live("SKILL USED!", "Effect applied. Enemy turn...", TutorialUI.Zone.BOTTOM_LEFT, null)
	_wait_for_idle_then(Step.CHARGE_PICK_WAIT)


func _on_action_card_closed() -> void:
	super._on_action_card_closed()
	_skill_ui_ref = null


func _on_attack_card_closed() -> void:
	if not _tutorial_active:
		super._on_attack_card_closed()
		return
	if _hold_enemy_turn and _step == Step.QTE_RESULT:
		# TAHAN: cleanup doang (deck tutup, kamera balik, tombol
		# ngumpet), turn DISTART MANUAL dari PARRY_WAIT. Tanpa ini,
		# enemy turn auto-start ~1 dtk dan drill dadakan pas baca hasil.
		attack_card_used_this_session = false
		is_card_ui_open = false
		attack_card_ui = null
		_reset_hand_to_original(0.4)
		_reset_camera_to_default()
		is_player_turn = false
		_apply_button_gating(false)
		return
	super._on_attack_card_closed()
	_skill_ui_ref = null


func _on_charge_complete(multiplier: float) -> void:
	if not _tutorial_active:
		super._on_charge_complete(multiplier)
		return
	if _step != Step.CHARGE_DO:
		return
	super._on_charge_complete(multiplier)
	_live("CHARGE COMPLETE!", "Big damage! Enemy turn...", TutorialUI.Zone.BOTTOM_LEFT, null)
	_wait_for_idle_then(Step.RAPID_PICK_WAIT)


func _on_raptive_btn_pressed() -> void:
	super._on_raptive_btn_pressed()
	if _tutorial_active and _step == Step.RAPID_DO and _rapid_hits == 1:
		_live("RAPID ATTACK", "Good! Keep tapping the buttons — fast!", TutorialUI.Zone.BOTTOM_LEFT, rapid_btn)


func _on_backpack_pressed() -> void:
	if not _tutorial_active:
		super._on_backpack_pressed()
		return
	if _step == Step.PACK_ACT:
		super._on_backpack_pressed()
		if not is_inventory_open:
			return  # inventory gagal kebuka — tap lagi nanti
		_begin_step(Step.PACK_VIEW)
	elif _step == Step.PACK2_ACT:
		super._on_backpack_pressed()
		if not is_inventory_open:
			return
		_potion_index = _find_potion_slot()
		_begin_step(Step.POTION_SLOT)


func _on_item_used_in_battle(item: ItemData) -> void:
	super._on_item_used_in_battle(item)


func _find_potion_slot() -> int:
	var pd = PlayerDataManager.data
	if pd == null or pd.battle_inventory == null or pd.battle_inventory.items == null:
		return -1
	for i in range(pd.battle_inventory.items.size()):
		var it: ItemData = pd.battle_inventory.items[i]
		if it and it.item_id == TUTORIAL_DROP_ID:
			return i
	return -1


func _potion_ready_to_use() -> bool:
	if not is_instance_valid(battle_inventory_instance):
		return false
	if _potion_index < 0:
		return false
	var idx: int = battle_inventory_instance.get("_current_selected_index")
	if idx != _potion_index:
		return false
	var ub: Button = _inventory_use_button()
	return ub and ub.visible


func _inventory_use_button() -> Button:
	if not is_instance_valid(battle_inventory_instance):
		return null
	return battle_inventory_instance.get("use_item_btn") as Button


func _inventory_close_button() -> Button:
	if not is_instance_valid(battle_inventory_instance):
		return null
	return battle_inventory_instance.get("close_btn") as Button


func _inventory_info_panel() -> Control:
	if not is_instance_valid(battle_inventory_instance):
		return null
	var p := battle_inventory_instance.get("item_info") as Control
	if p and p.visible:
		return p
	return null


func _inventory_slot_button(idx: int) -> Button:
	if not is_instance_valid(battle_inventory_instance):
		return null
	var slots: Array = battle_inventory_instance.get("_slots")
	if slots == null or idx < 0 or idx >= slots.size():
		return null
	var slot: Node = slots[idx]
	for c in slot.get_children():
		if c is BaseButton:
			return c as BaseButton
	return null


# ============================================================
# STEP MACHINE
# ============================================================

func _begin_step(step: Step) -> void:
	_step = step
	_unlock_all()
	# Default: gak ada tombol yang nongol. Tiap case deklarasi sendiri
	# via _show_only() kalau butuh tombol.
	_tut_revealed.clear()
	_tut_enabled.clear()
	match step:
		Step.WELCOME:
			_read("WELCOME, KNIGHT!", "You In The First Battle training. Tap anywhere to start.", TutorialUI.Zone.BOTTOM_LEFT, null)
		Step.TARGET_ACT:
			_act("SELECT TARGET", "Tap the Skeleton to lock it as your target.", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.ATTACK_ACT:
			_show_only([atk_btn], [atk_btn])
			_act("TAP ATTACK", "This button opens your attack cards. Tap it.", TutorialUI.Zone.BOTTOM_LEFT, atk_btn)
		Step.BASIC_PICK:
			_pick_setup(false, "Basic", "BASIC CARD", "Tap the glowing BASIC card.")
		Step.QTE_DO:
			_lock_all_except([attack_qte_node, reset_target_btn])
			_live("TIMING BAR", "Tap ANYWHERE when the runner hits GOLD!", TutorialUI.Zone.BOTTOM_LEFT, attack_qte_node)
		Step.QTE_RESULT:
			_read(_qte_title(), _last_attack_result_text() + " Tap to continue.", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.PARRY_WAIT:
			_lock_all_except([])
			_turn_started = false
			_parry_wait_since = Time.get_ticks_msec()
			_live("SKELETON ATTACKING!", "Anticipate it — you must parry!", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
			_drill_armed = true
		Step.PARRY_DRILL:
			_lock_all_except([parry_btn])
			_allow_interaction(parry_btn)
			_live("NOW! TAP THE SHIELD!", "Tap it before the hit lands!", TutorialUI.Zone.BOTTOM_LEFT, parry_btn)
		Step.PARRY_MISS:
			_lock_all_except([])
			_show("TOO SLOW!", "The hit landed. Watch the wind-up — TAP TO TRY AGAIN.", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref(), true)
		Step.PARRY_RESULT:
			_live("PARRIED!", "Blocked most damage + bonus stamina. Watch!", TutorialUI.Zone.BOTTOM_LEFT, player_info)
			_wait_for_idle_then(Step.PARRY_WHY)
		Step.PARRY_WHY:
			_read("WHY PARRY?", "Parrying cuts damage and restores stamina. Against heavy hits, it is survival. Tap to continue.", TutorialUI.Zone.BOTTOM_LEFT, player_info)
		Step.DEFEND_ACT:
			_show_only([defend_btn], [defend_btn])
			_act("TAP DEFEND", "DEFEND restores 20 stamina, but skips your attack.", TutorialUI.Zone.BOTTOM_LEFT, defend_btn)
		Step.SKILL_ACT:
			_show_only([skill_btn], [skill_btn])
			_act("TAP SKILL", "SKILL opens special cards: poison, stun, bleed.", TutorialUI.Zone.BOTTOM_LEFT, skill_btn)
		Step.SKILL_PICK:
			_pick_setup(true, "", "SKILL CARD", "Tap the glowing SKILL card.")
		Step.CHARGE_PICK_WAIT:
			_show_only([atk_btn], [atk_btn])
			_lock_all_except([atk_btn])
			_allow_interaction(atk_btn)
			_live("ATTACK AGAIN", "New card type: CHARGE. Tap ATTACK.", TutorialUI.Zone.BOTTOM_LEFT, atk_btn)
		Step.CHARGE_PICK:
			_pick_setup(false, "Charge", "CHARGE CARD", "Tap the glowing CHARGE card.")
		Step.CHARGE_DO:
			var cb := _charge_button()
			_lock_all_except([cb] if cb else [])
			if cb:
				_allow_interaction(cb)
			# SENGAJA tanpa spotlight: charge itu minigame timing yang
			# harus keliatan UTUH (bar + zona gold). Kalau cuma tombolnya
			# yang dilubangin, sisanya gelap dan gak bisa ngeker timing.
			_live("HOLD & RELEASE", "Hold the button, release inside GOLD for max damage!", TutorialUI.Zone.BOTTOM_LEFT, null)
		Step.RAPID_PICK_WAIT:
			_show_only([atk_btn], [atk_btn])
			_lock_all_except([atk_btn])
			_allow_interaction(atk_btn)
			_live("ONE MORE TYPE", "Last one: RAPID. Tap ATTACK.", TutorialUI.Zone.BOTTOM_LEFT, atk_btn)
		Step.RAPID_PICK:
			_pick_setup(false, "Rapid", "RAPID CARD", "Tap the glowing RAPID card.")
		Step.RAPID_DO:
			_lock_all_except([rapid_btn])
			_allow_interaction(rapid_btn)
			_live("TAP FAST!", "Tap every button before time runs out!", TutorialUI.Zone.BOTTOM_LEFT, rapid_btn)
		Step.FINISH_INTRO:
			_read("ARMOR OFF!", "Training wheels off — real damage now. Finish it!", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.FINISH_ACT:
			_show_only([atk_btn], [atk_btn])
			_act("FINISH IT", "Tap ATTACK for the final blow.", TutorialUI.Zone.BOTTOM_LEFT, atk_btn)
		Step.FINISH_PICK:
			_pick_setup(false, "Basic", "FINAL BLOW", "Tap BASIC to finish the Skeleton.")
		Step.FINISH_QTE:
			_lock_all_except([attack_qte_node, reset_target_btn])
			_live("FINISH!", "Tap when the runner hits GOLD!", TutorialUI.Zone.BOTTOM_LEFT, attack_qte_node)
		Step.FINISH_MISS:
			_read("MISSED!", "No damage. Tap to try the finishing blow again.", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.FINISH_AFTER:
			pass  # dijaga _process (musuh mati + drop + kamera siap)
		Step.LOOT_ACT:
			_tutorial_inv_before = _tutorial_inventory_count()
			_loot_collected = false
			_ensure_loot_space()
			# Balikin giliran di sini: chain tutup deck pasca-kill bisa
			# telat dan nimpa restore yang duluan.
			is_player_turn = true
			_lock_all_except([_drop_node])
			_allow_interaction(_drop_node)
			_live("COLLECT LOOT", "The Skeleton dropped something! Tap the glowing item.", TutorialUI.Zone.BOTTOM_LEFT, _drop_node)
		Step.LOOT_DONE:
			_read("LOOT SECURED!", "Saved to your BACKPACK permanently. Tap to continue.", TutorialUI.Zone.BOTTOM_LEFT, backpack_btn)
		Step.PACK_ACT:
			_show_only([backpack_btn], [backpack_btn])
			_repair_turn_if_no_live_enemies()
			is_player_turn = true
			_act("OPEN BACKPACK", "Tap BACKPACK to look inside.", TutorialUI.Zone.BOTTOM_LEFT, backpack_btn)
		Step.PACK_VIEW:
			# Beat 1: spotlight SELURUH inventory + penjelasan dulu.
			var inv: Control = battle_inventory_instance if is_instance_valid(battle_inventory_instance) else null
			_lock_all_except([])
			_show("YOUR BACKPACK", "Items live in slots — potions, materials, loot. Tap to continue.", TutorialUI.Zone.TOP_CENTER, inv, true)
		Step.PACK_CLOSE:
			# Beat 2: baru spotlight tombol CLOSE-nya.
			var close_b: Button = _inventory_close_button()
			_lock_all_except([close_b] if close_b else [])
			if close_b:
				_allow_interaction(close_b)
			_live("CLOSE IT", "Tap CLOSE when done looking.", TutorialUI.Zone.TOP_CENTER, close_b)
		Step.WAVE2_INTRO:
			_read("WAVE 2", "Another Skeleton! But something feels wrong...", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.HURT_WAIT:
			# Skeleton nyerang BENERAN (forced turn, live). Damage
			# serangannya di-script mendarat pas di 25%.
			# SENGAJA tanpa spotlight: momen kena hit harus keliatan
			# UTUH (animasi + shake + HP bar), jangan digelapin.
			_lock_all_except([])
			is_player_turn = false
			_apply_button_gating(false)
			_live("WATCH OUT!", "The Skeleton is charging a heavy blow!", TutorialUI.Zone.BOTTOM_LEFT, null)
			_force_hurt_turn = true
			_start_enemies_turn()
		Step.HURT_INFO:
			_ui_set_hp_note(true)
			_read("YOU'RE HURT!", "HP dropped to 25%! You need that potion. Tap to continue.", TutorialUI.Zone.BOTTOM_LEFT, player_info)
		Step.PACK2_ACT:
			_show_only([backpack_btn], [backpack_btn])
			_repair_turn_if_no_live_enemies()
			_act("GRAB THE POTION", "Open BACKPACK and use your Health Potion.", TutorialUI.Zone.BOTTOM_LEFT, backpack_btn)
		Step.POTION_INFO:
			# Beat 1: spotlight SELURUH popup info item + penjelasan.
			var info_p: Control = _inventory_info_panel()
			_lock_all_except([])
			_read("ITEM INFO", "Name, effect and power. Read it, then tap to continue.", TutorialUI.Zone.TOP_CENTER, info_p)
		Step.POTION_SLOT:
			var slot_b: Button = _inventory_slot_button(_potion_index)
			_lock_all_except([slot_b] if slot_b else [])
			if slot_b:
				_allow_interaction(slot_b)
			_live("FIND THE POTION", "Tap the glowing Health Potion slot.", TutorialUI.Zone.TOP_CENTER, slot_b)
		Step.POTION_USE:
			_tutorial_heal_before = current_hp
			var use_b: Button = _inventory_use_button()
			_lock_all_except([use_b] if use_b else [])
			if use_b:
				_allow_interaction(use_b)
			_live("DRINK IT!", "Tap USE to drink the Health Potion.", TutorialUI.Zone.TOP_CENTER, use_b)
		Step.HEALED:
			_ui_set_hp_note(false)
			# Tanpa spotlight: momen heal (partikel + HP naik) biar
			# keliatan utuh.
			_read("HEALED!", "Now finish the weakened Skeleton!", TutorialUI.Zone.TOP_CENTER, null)
		Step.WAVE2_FIGHT:
			_force_basic_hand()
			_show_only([atk_btn], [atk_btn])
			_live("YOUR MOVE", "Finish the Skeleton — tap ATTACK!", TutorialUI.Zone.BOTTOM_LEFT, atk_btn)
		Step.WAVE2_PICK:
			_pick_setup(false, "Basic", "PICK A CARD", "Tap the glowing BASIC card.")
		Step.WAVE2_QTE:
			_lock_all_except([attack_qte_node, reset_target_btn])
			_live("TIMING!", "Tap when the runner hits GOLD!", TutorialUI.Zone.BOTTOM_LEFT, attack_qte_node)
		Step.WAVE2_AFTER:
			pass  # dijaga _process (mati -> wave3, miss -> serang lagi)
		Step.WAVE3_INTRO:
			_read("WAVE 3: GRIMWARD", "Tougher. It COUNTERS when struck — watch closely!", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.WAVE3_FIGHT:
			_force_basic_hand()
			_show_only([atk_btn], [atk_btn])
			# Chain tutup-deck pasca-kill wave-2 bisa telat nimpa turn.
			# Restore di sini (user-paced, chain udah kelar) biar aman.
			is_player_turn = true
			_live("YOUR MOVE", "Attack the Grimward — watch for counters!", TutorialUI.Zone.BOTTOM_LEFT, atk_btn)
		Step.WAVE3_PICK:
			_pick_setup(false, "Basic", "PICK A CARD", "Tap the glowing BASIC card.")
		Step.WAVE3_QTE:
			_lock_all_except([attack_qte_node, reset_target_btn])
			_live("TIMING!", "Tap when the runner hits GOLD!", TutorialUI.Zone.BOTTOM_LEFT, attack_qte_node)
		Step.WAVE3_AFTER:
			pass  # dijaga _process (giliran balik + kamera siap)
		Step.WAVE3_DONE:
			_read("WELL FOUGHT!", "You survived a counter-attacker. Tap to finish.", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.COMPLETE:
			_lock_all_except([])
			_ui_show_final("TRAINING COMPLETE\nYou know: target, attack, cards, timing, parry, defend, skills, charge, rapid, loot, backpack, potions. Good luck, Knight!")


# Step BACA: panel muncul, player tap panel buat lanjut.
# (Tanpa pause: pas idle gak ada yang gerak sendiri.)
func _read(title: String, body: String, zone: TutorialUI.Zone, spot: Node) -> void:
	_lock_all_except([])
	_show(title, body, zone, spot, true)


# Step AKSI (target tunggal): target dibuka + spotlight, sisanya kunci.
func _act(title: String, body: String, zone: TutorialUI.Zone, target: Node) -> void:
	_lock_all_except([target] if target else [])
	if target:
		_allow_interaction(target)
	_show(title, body, zone, target, false)


# Step LIVE (kartu, QTE, charge, rapid, inventory, wait).
func _live(title: String, body: String, zone: TutorialUI.Zone, spot: Node) -> void:
	_show(title, body, zone, spot, false)


func _step_no() -> int:
	return int(_step)


func _step_total() -> int:
	return int(Step.COMPLETE)


func _show(title: String, body: String, zone: TutorialUI.Zone, spot: Node, dismissable: bool) -> void:
	if _tutorial_ui:
		_tutorial_ui.set_spotlight_target(spot)
		_tutorial_ui.show_step(_step_no(), _step_total(), title, body, zone, true, dismissable)


func _qte_title() -> String:
	if total_critical > 0:
		return "PERFECT!"
	return "HIT!"


func _last_attack_result_text() -> String:
	if total_critical > 0:
		return "**Perfect!** Great timing = bonus damage."
	return "Attack connected. Timing decides the damage."


# Pengaman: kalau flag giliran nyangkut false padahal gak ada musuh
# hidup (=> gak ada turn valid yang jalan), balikin manual. Dipakai
# sebelum step yang butuh tap tombol (tap ditolak pas bukan giliran).
func _repair_turn_if_no_live_enemies() -> void:
	if is_player_turn:
		return
	for e in enemies:
		if is_instance_valid(e) and e.current_hp > 0:
			return
	is_player_turn = true


func _enemy_ref() -> Node:
	if not enemies.is_empty():
		return enemies[selected_enemy_index] if selected_enemy_index < enemies.size() else enemies[0]
	return null


func _charge_button() -> Button:
	if charge_attack_ui:
		return charge_attack_ui.get("button_charge") as Button
	return null


func _attack_card_node(i: int) -> Control:
	if attack_card_ui and i >= 0 and i < attack_card_ui.card_nodes.size():
		return attack_card_ui.card_nodes[i]
	return null


func _find_skill_ui() -> ActionCardUI:
	if _skill_ui_ref and is_instance_valid(_skill_ui_ref) and _skill_ui_ref.is_open:
		return _skill_ui_ref
	for c in get_children():
		if c is ActionCardUI and c != attack_card_ui:
			var ui := c as ActionCardUI
			if ui.is_open and ui.card_nodes.size() > 0:
				_skill_ui_ref = ui
				return ui
	return null


func _skill_card_node(i: int) -> Control:
	var ui := _find_skill_ui()
	if ui and i >= 0 and i < ui.card_nodes.size():
		return ui.card_nodes[i]
	return null


# Setup pick kartu: kunci semua dulu (deck lagi spawn animation),
# habis 0.8 dtk baru spotlight + panel ke kartu target.
func _pick_setup(is_skill: bool, expected: String, title: String, body: String) -> void:
	_pick_expected = expected
	_pick_is_skill = is_skill
	_refill_stamina()
	_lock_all_except([])
	_ui_hide()
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(self) or not _tutorial_active:
		return
	var card: Control = null
	if is_skill:
		card = _skill_card_node(0)
	else:
		var idx := _attack_index_of(expected) if expected != "" else 0
		card = _attack_card_node(idx)
		if card == null and expected == "":
			for i in range(attack_card_ui.card_nodes.size() if attack_card_ui else 0):
				card = _attack_card_node(i)
				if card:
					break
	if card == null:
		return
	_lock_all_except([card])
	_allow_interaction(card)
	_lock_card_bg()
	_show(title, body, TutorialUI.Zone.BOTTOM_LEFT, card, false)


func _lock_card_bg() -> void:
	for ui in [attack_card_ui, _find_skill_ui()]:
		if ui and is_instance_valid(ui):
			var bg = ui.get("bg_overlay")
			if bg is Control:
				(bg as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


# (Pause dihapus total dari tutorial: semua step jalan live.
# Idle giliran player itu quiescent — gak ada yang gerak sendiri,
# jadi gak ada yang perlu di-freeze. Musik & SFX jalan natural.)


# ============================================================
# INPUT LOCKING — kunci SEMUA, kecuali target step ini
# ============================================================


# ============================================================
# INPUT LOCKING — kunci SEMUA, kecuali target step ini
# ============================================================

func _lock_all_except(allowed: Array) -> void:
	_unlock_all()
	for n in _descendants(self):
		if n == self:
			continue
		if _tutorial_layer and (_tutorial_layer == n or _tutorial_layer.is_ancestor_of(n)):
			continue
		if n in allowed:
			continue
		if n is Node2D:
			continue
		if n is Control:
			_disable_node(n)
	for e in enemies:
		if is_instance_valid(e):
			_set_enemy_clickable(e, e in allowed)
	for t in allowed:
		_allow_interaction(t)


func _set_enemy_clickable(enemy: BattleEnemy, allow: bool) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	for btn in [enemy.enemy_collision, enemy.get("enemy_profile_btn")]:
		if btn is Control:
			if allow:
				(btn as Control).mouse_filter = Control.MOUSE_FILTER_STOP
				if btn is BaseButton:
					(btn as BaseButton).disabled = false
			else:
				(btn as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
				if btn is BaseButton:
					(btn as BaseButton).disabled = true


func _set_enemy_clickable_all(allow: bool) -> void:
	for e in enemies:
		_set_enemy_clickable(e, allow)


# Marka target jadi bisa diklik: mouse_filter STOP + process_mode ALWAYS
# (kalau tree paused, node pausable default-nya GAK bisa terima GUI input).
func _allow_interaction(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var n := node
	if n is BattleEnemy:
		n = (n as BattleEnemy).enemy_collision
	if n == null or not is_instance_valid(n):
		return
	_save_state_if_needed(n)
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_STOP
		if n is BaseButton:
			(n as BaseButton).disabled = false
	n.process_mode = Node.PROCESS_MODE_ALWAYS
	if not (n in _always_nodes):
		_always_nodes.append(n)
	var y := _original_y_for(n)
	if y != INF and n is Control:
		(n as Control).position.y = y


func _original_y_for(n: Node) -> float:
	if n == atk_btn:
		return original_atk_pos.y
	if n == defend_btn:
		return original_def_pos.y
	if n == backpack_btn:
		return original_backpack_pos.y
	if n == run_btn:
		return original_run_post.y
	if n == skill_btn:
		return original_skill_post.y
	return INF


func _is_core_button(n: Node) -> bool:
	return n in [atk_btn, defend_btn, backpack_btn, run_btn, skill_btn]


func _descendants(root_node: Node) -> Array:
	var out: Array = []
	for c in root_node.get_children():
		out.append(c)
		out.append_array(_descendants(c))
	return out


func _save_state_if_needed(node: Node) -> void:
	if node is Control:
		var c := node as Control
		var id := c.get_instance_id()
		if not _saved_mouse_filters.has(id):
			_saved_mouse_filters[id] = c.mouse_filter
		if node is BaseButton:
			var b := node as BaseButton
			if not _saved_disabled.has(id):
				_saved_disabled[id] = b.disabled
	if not _saved_process_mode.has(node.get_instance_id()):
		_saved_process_mode[node.get_instance_id()] = node.process_mode


func _disable_node(node: Node) -> void:
	_save_state_if_needed(node)
	if node is Control:
		var c := node as Control
		_locked_nodes.append(c)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if node is BaseButton:
		(node as BaseButton).disabled = true


func _unlock_all() -> void:
	for c in _locked_nodes:
		if is_instance_valid(c):
			if c is BaseButton:
				var b := c as BaseButton
				var id := b.get_instance_id()
				if _saved_disabled.has(id):
					b.disabled = _saved_disabled[id]
			if _saved_mouse_filters.has(c.get_instance_id()):
				c.mouse_filter = _saved_mouse_filters[c.get_instance_id()]
	_saved_mouse_filters.clear()
	_saved_disabled.clear()
	_locked_nodes.clear()
	for n in _always_nodes:
		if is_instance_valid(n):
			var id := (n as Node).get_instance_id()
			if _saved_process_mode.has(id):
				(n as Node).process_mode = _saved_process_mode[id]
	_saved_process_mode.clear()
	_always_nodes.clear()


# ============================================================
# UI HELPERS
# ============================================================

func _ui_hide() -> void:
	if _tutorial_ui:
		_tutorial_ui.hide_panel()


func _ui_show_final(text: String) -> void:
	if _tutorial_ui:
		_tutorial_ui.show_final(text)


func _ui_set_hp_note(shown: bool) -> void:
	if _tutorial_ui:
		_tutorial_ui.set_hp_note(shown)


# ============================================================
# WAVE FLOW
# ============================================================

func spawn_wave2_skeleton() -> void:
	_wave_index = 2
	total_waves = 3
	current_wave = 2
	wave_progress.set_wave(2, 3)
	_tutorial_spawn(["skeleton"] as Array[String], [1] as Array[int])


func spawn_wave3_grimward() -> void:
	_wave_index = 3
	total_waves = 3
	current_wave = 3
	wave_progress.set_wave(3, 3)
	_tutorial_spawn(["grimward"] as Array[String], [3] as Array[int])
	# Pelajaran counter = DETERMINISTIK: armor ON (damage ~1, gak bisa
	# mati duluan — crit 130 > HP 125!) + counter level 3 = 100% pasti
	# keluar pas diserang. Mati cuma kalau tutorial yang nyuruh.
	for e in enemies:
		if not is_instance_valid(e):
			continue
		_set_training_armor(e, true)
		var ab := e.get_tactical_attack_ability()
		if ab:
			ab.level = 3


func _goto_wave2() -> void:
	if _wave2_spawned():
		return
	set_meta("_tut_w2", true)
	_step = Step.IDLE
	_ui_hide()
	_unlock_all()
	# Bersihin corpse wave-1 + reset kamera biar gak overlap/ancur.
	_cleanup_battlefield()
	_reset_camera_to_default()
	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(self) or not _tutorial_active:
		return
	spawn_wave2_skeleton()
	await get_tree().create_timer(1.4).timeout
	if not is_instance_valid(self) or not _tutorial_active:
		return
	_begin_step(Step.WAVE2_INTRO)


func _goto_wave3() -> void:
	if _wave3_spawned():
		return
	set_meta("_tut_w3", true)
	_step = Step.IDLE
	_ui_hide()
	_unlock_all()
	# Skeleton wave-2 MASIH HIDUP — bersihin dulu biar gak bertubrukan
	# sama grimward di titik spawn yang sama.
	_cleanup_battlefield()
	_reset_camera_to_default()
	# Musuh terakhir mati -> parent TIDAK balikin is_player_turn.
	# Balikin manual, kalau gak semua tap habis ini ditolak.
	is_player_turn = true
	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(self) or not _tutorial_active:
		return
	spawn_wave3_grimward()
	await get_tree().create_timer(1.4).timeout
	if not is_instance_valid(self) or not _tutorial_active:
		return
	_begin_step(Step.WAVE3_INTRO)


func _wave2_spawned() -> bool:
	return bool(get_meta("_tut_w2", false))


func _wave3_spawned() -> bool:
	return bool(get_meta("_tut_w3", false))
