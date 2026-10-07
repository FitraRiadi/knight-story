extends "res://scripts/local/battle/BattleManager.gd"
class_name TutorialGameplayManager

# ============================================================
# TUTORIAL GAMEPLAY MANAGER
# extends BattleManager. Override HANYA yang perlu dibedain —
# BattleManager.gd sendiri 100% utuh.
#
# Aturan main:
#  - 3 wave: Skeleton (latihan) -> Skeleton (potion) -> Grimward
#  - Tiap gerakan ada tutorialnya: baca (pause, tap panel) atau
#    aksi (target di-spotlight, yang lain dikunci/disembunyiin)
#  - Tombol action MUNCUL SATU-SATU sesuai kebutuhan (reveal
#    bertahap), bukan sekaligus di awal
#  - Deck attack tutorial itu FIX: [Basic, Charge, Rapid]
#  - Skeleton wave-1 pakai "training armor" (damage ~1) biar gak
#    mati sebelum semua gerakan kelar diajarin
#  - HP floor 25% (player gak bisa mati di tutorial)
#  - Gak ada tombol skip
#  - Selesai: panel + tombol Continue, emit tutorial_finished
# ============================================================

signal tutorial_finished
signal tutorial_complete

# --- Konstanta flow ---
const HP_FLOOR_PCT := 0.25
const TUTORIAL_DROP_ID := "health_potion"
const OUT_SCENE := "res://scenes/menu/mainmenu.tscn"  # fallback, tinggal diubah
const TRAINING_DEFENSE := 9999.0
const BASIC_PATH := "res://data/action_cards/attack_cards/basic_attack.tres"
const CHARGE_PATH := "res://data/action_cards/attack_cards/charge_attack.tres"
const RAPID_PATH := "res://data/action_cards/attack_cards/rapid_attack.tres"

# --- Step (URUT = urutan main; nomor STEP di panel diambil dari sini) ---
enum Step {
	IDLE,
	WELCOME,
	TARGET_INTRO,
	TARGET_ACT,
	ATTACK_INTRO,
	ATTACK_ACT,
	BASIC_PICK,
	QTE_DO,
	QTE_RESULT,
	PARRY_WAIT,
	PARRY_ACT,
	PARRY_RESULT,
	DEFEND_INTRO,
	DEFEND_ACT,
	SKILL_INTRO,
	SKILL_ACT,
	SKILL_PICK,
	ATTACK2_INTRO,
	ATTACK2_ACT,
	CHARGE_PICK,
	CHARGE_DO,
	ATTACK3_INTRO,
	ATTACK3_ACT,
	RAPID_PICK,
	RAPID_DO,
	FINISH_INTRO,
	FINISH_ACT,
	FINISH_PICK,
	FINISH_QTE,
	FINISH_AFTER,
	FINISH_MISS,
	LOOT_INTRO,
	LOOT_ACT,
	LOOT_DONE,
	PACK_INTRO,
	PACK_ACT,
	PACK_VIEW,
	RUN_INTRO,
	WAVE2_INTRO,
	HURT_ANIM,
	HURT_INFO,
	PACK2_ACT,
	POTION_SLOT,
	POTION_USE,
	HEALED,
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
# Reveal bertahap: tombol yang SUDAH dikenalin (boleh keliatan)
var _tut_revealed: Array = []
# ...dan yang lagi BOLEH dipencet
var _tut_enabled: Array = []
var _locked_nodes: Array[Control] = []
var _saved_disabled: Dictionary = {}
var _saved_mouse_filters: Dictionary = {}
var _saved_process_mode: Dictionary = {}
# Step yang nunggu giliran player balik (habis enemy turn)
var _pending_idle_step: Step = Step.IDLE
# Kapan pending dipasang (msec). Pengaman: kalau kamera macet,
# pending tetap jalan max 4 dtk ASAL giliran udah bener balik.
var _pending_idle_since: int = 0
# Enemy turn paksa (sekali) buat pelajaran parry
var _force_parry_turn := false
var _rapid_taught := false
var _w3_baseline_attacks := 0
var _potion_index := -1
var _hurt_step_done := false
var _wave2_spawned := false
var _wave3_spawned := false
# Jendela parry pelajaran lagi kebuka (beat live 0.35 dtk + freeze).
# Beda dari step: tap kilat pas beat harus tetap dihitung.
var _lesson_parry_open := false
# Redundansi: loot kelar kalau count naik ATAU signal collect masuk
# (keduanya; jangan gambling satu jalur).
var _loot_collected := false
var _pick_expected := ""
var _pick_is_skill := false
# Ref deck skill yang LAGI kebuka. Parent gak free node ActionCardUI
# lama pas deck ditutup (cuma canvas_layer-nya), jadi cari via
# get_children() bisa nemu deck BASI yang card_nodes-nya kosong.
var _skill_ui_ref: ActionCardUI = null
# Target yang dibikin ALWAYS (balikin mode-nya pas unlock; jangan
# pakai instance_from_id membabi-buta — id bisa ke-recycle).
var _always_nodes: Array = []


func _ready() -> void:
	_wave_index = 0
	_tutorial_active = true
	super._ready()
	_setup_tutorial_layer()
	# Awal: SEMUA tombol action disembunyiin. Muncul satu-satu
	# pas dikenalin di step-nya masing-masing.
	_tut_revealed.clear()
	_tut_enabled.clear()
	_apply_button_gating(false)
	_set_enemy_clickable_all(false)
	# WaveProgress jujur dari awal: tutorial itu 3 wave.
	total_waves = 3
	current_wave = 1
	if wave_progress:
		wave_progress.set_wave(1, 3)
	# Beri jeda biar intro battle parent (hand, map title) selesai dulu.
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(self):
		_begin_step(Step.WELCOME)


func _setup_tutorial_layer() -> void:
	if _tutorial_layer and is_instance_valid(_tutorial_layer):
		return
	_tutorial_layer = CanvasLayer.new()
	_tutorial_layer.name = "tutorialLayer"
	_tutorial_layer.layer = 300
	# ALWAYS biar panel + step machine tetap jalan saat tree paused
	_tutorial_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_tutorial_layer)
	_tutorial_ui = TutorialUI.new()
	_tutorial_ui.setup(_tutorial_layer)
	if not _tutorial_ui.tapped.is_connected(_on_tutorial_tapped):
		_tutorial_ui.tapped.connect(_on_tutorial_tapped)
	if not _tutorial_ui.finished.is_connected(_on_tutorial_finished):
		_tutorial_ui.finished.connect(_on_tutorial_finished)


# ============================================================
# TAP PANEL (step BACA) — cuma step BACA yang dismissable,
# jadi signal ini = "lanjut".
# ============================================================

func _on_tutorial_tapped() -> void:
	if not _tutorial_active or _step == Step.IDLE:
		return
	match _step:
		Step.WELCOME:
			_begin_step(Step.TARGET_INTRO)
		Step.TARGET_INTRO:
			_begin_step(Step.TARGET_ACT)
		Step.ATTACK_INTRO:
			_begin_step(Step.ATTACK_ACT)
		Step.QTE_RESULT:
			# Lanjut: musuh giliran nyerang (dipaksa sekali).
			_force_parry_turn = true
			_begin_step(Step.PARRY_WAIT)
		Step.DEFEND_INTRO:
			_begin_step(Step.DEFEND_ACT)
		Step.SKILL_INTRO:
			_begin_step(Step.SKILL_ACT)
		Step.ATTACK2_INTRO:
			_begin_step(Step.ATTACK2_ACT)
		Step.ATTACK3_INTRO:
			_begin_step(Step.ATTACK3_ACT)
		Step.FINISH_INTRO:
			# Armor latihan dilepas — sekarang damage beneran.
			_set_training_armor_all(false)
			_refill_stamina()
			set_meta("_tut_fin_miss", total_miss)
			_begin_step(Step.FINISH_ACT)
		Step.FINISH_MISS:
			set_meta("_tut_fin_miss", total_miss)
			_begin_step(Step.FINISH_ACT)
		Step.LOOT_INTRO:
			_begin_step(Step.LOOT_ACT)
		Step.LOOT_DONE:
			_begin_step(Step.PACK_INTRO)
		Step.PACK_INTRO:
			_begin_step(Step.PACK_ACT)
		Step.RUN_INTRO:
			_goto_wave2()
		Step.WAVE2_INTRO:
			_do_scripted_hurt()
		Step.HURT_INFO:
			_begin_step(Step.PACK2_ACT)
		Step.HEALED:
			_goto_wave3()
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
	_pause_game(false)
	_unlock_all()
	# Balikin battle ke kondisi main normal: semua tombol muncul.
	_tut_revealed = [atk_btn, defend_btn, backpack_btn, run_btn, skill_btn]
	_tut_enabled = [atk_btn, defend_btn, backpack_btn, run_btn, skill_btn]
	_apply_button_gating(true)
	_set_enemy_clickable_all(true)
	tutorial_finished.emit()
	tutorial_complete.emit()


# ============================================================
# OVERRIDE: DECK — tutorial pakai deck FIX, bukan acak
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


# ============================================================
# OVERRIDE: TOMBOL — reveal bertahap, bukan sekaligus
# ============================================================

func _set_buttons_active(show_buttons: bool, instant: bool = false) -> void:
	if not _tutorial_active:
		super._set_buttons_active(show_buttons, instant)
		return
	_apply_button_gating(show_buttons)


# Parent spawn pertama manggil ini (slide SEMUA tombol masuk).
# Di tutorial itu persis yang dilarang: tombol muncul satu-satu.
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
		# Instant (tanpa tween): gating jalan juga pas tree paused,
		# tween tombol pausable bakal beku di tengah jalan.
		b.position.y = orig.y if vis else orig.y + 200.0
		b.disabled = not (vis and (b in _tut_enabled))


func _reveal(btn: Button, enabled_now: bool = false) -> void:
	if btn and not (btn in _tut_revealed):
		_tut_revealed.append(btn)
	_tut_enabled.clear()
	if enabled_now and btn:
		_tut_enabled.append(btn)
	_apply_button_gating(true)


func _enable_only(btns: Array) -> void:
	_tut_enabled.clear()
	for b in btns:
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
	# Parent _ready() manggil spawn_random_enemies yg acak. Tutorial mau
	# 1 skeleton aja di wave 1: batalkan hasil random, spawn manual.
	if _wave_index == 0:
		_wave_index = 1
		for e in enemies:
			if is_instance_valid(e):
				e.queue_free()
		enemies.clear()
		selected_enemy_index = 0
		super._spawn_enemies(["skeleton"] as Array[String], [1] as Array[int])
		# Training armor: damage player jadi ~1 biar musuh gak mati
		# sebelum semua gerakan kelar diajarin. Dilepas di FINISH_INTRO.
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


# ============================================================
# OVERRIDE: PARRY WINDOW — pause-aware + instant (tanpa tween)
# ============================================================

func _show_parry_window(duration: float = 1.0) -> void:
	if not _tutorial_active:
		super._show_parry_window(duration)
		return
	if not parry_btn:
		return
	parry_success_this_turn = false
	is_parry_window_active = true
	parry_extra_reduction = 0.0
	total_parry_attempts += 1
	# Biar parry btn bisa diklik pas tree paused
	parry_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	parry_btn.disabled = false
	parry_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	# Posisi acak kayak parent, tapi INSTANT (tween bakal beku
	# kalau tutorial pause pas window kebuka).
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
	# NOTE: timing bar sengaja TIDAK di-tween di sini. Kalau tree lagi
	# jalan, _process parry toh jalan normal; kalau paused, bar freeze
	# penuh = player punya waktu tak terbatas (baik buat tutorial).
	if parry_timer != null:
		parry_timer = null
	# process_always = false -> timer beneran freeze pas tutorial pause
	parry_timer = get_tree().create_timer(duration, false)
	await parry_timer.timeout
	if not is_instance_valid(self):
		return
	if parry_btn.visible and not parry_success_this_turn:
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
# OVERRIDE: ENEMY TURN PAKSA (sekali, buat pelajaran parry)
# AI skeleton bisa DEFEND/skip — parry gak boleh gambling.
# ============================================================

func _start_enemies_turn() -> void:
	if not _tutorial_active or not _force_parry_turn:
		super._start_enemies_turn()
		return
	_force_parry_turn = false
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
	await enemy._execute_attack(camera, default_camera_pos, 1.0, "Attacking!", EnemyAI.Emotion.CALM)
	if not is_instance_valid(self):
		return
	_finish_forced_turn()


func _finish_forced_turn() -> void:
	# JANGAN set giliran balik selagi tree paused. Coroutine musuh bisa
	# kelar sendiri di tengah freeze (timer default gak kenal pause);
	# kalau tail langsung jalan, is_player_turn=true mendarat pas pause
	# dan step DEFEND langsung ke-trigger habis tap parry — padahal
	# serangan musuh belum kelar dimainin. Tunggu live dulu.
	while get_tree().paused:
		await get_tree().process_frame
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
		_apply_button_gating(true)
		_process_action_card_cooldowns()


# ============================================================
# OVERRIDE: DEATH — JANGAN wave logic parent (random spawn /
# scoreboard). Tutorial yang ngatur spawn manual.
# ============================================================

func _process_enemy_death(_exp_amount: int, _gold_amount: int, _dropped_items: Array[String], enemy: BattleEnemy) -> void:
	if not _tutorial_active:
		super._process_enemy_death(_exp_amount, _gold_amount, _dropped_items, enemy)
		return
	enemies_killed += 1
	if is_instance_valid(enemy):
		EventBus.enemy_killed.emit(enemy.enemy_id)
	# Paksa drop Health Potion (skeleton drop_chance cuma 0.1).
	_tutorial_force_drop(enemy)
	_update_target_selection()
	# SENGAJA gak ada: exp orbs, wave advance, scoreboard.


func _tutorial_force_drop(enemy: BattleEnemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var pos := enemy.global_position
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(self):
		return
	# Freeze despawn drop biar gak ilang 8 detik (step collect)
	var drop = _spawn_drop_item_keep(TUTORIAL_DROP_ID, pos, 0.0)
	if drop:
		_drop_node = drop


func _spawn_drop_item_keep(item_id: String, enemy_pos: Vector2, spawn_delay: float = 0.0) -> Node:
	# Mirip _spawn_drop_item parent, tapi freeze DESPAWN_TIME.
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
# OVERRIDE: DAMAGE — HP floor + scripted hurt
# ============================================================

func apply_damage(event: DamageEvent) -> void:
	if not _tutorial_active:
		super.apply_damage(event)
		return
	# Pelajaran parry = freeze-frame: musuh dibekuin di tengah ayunan,
	# TAPI coroutine-nya jalan terus (loop anim nunggu process_frame
	# yang tetap kepanggil pas pause + SceneTreeTimer default yang
	# gak kenal pause). Tanpa swallow, damage + suara + shake mendarat
	# di tengah freeze dan enemy turn kelar sendiri -> step DEFEND
	# nongol duluan. Jadi: selama PARRY_ACT, semua damage ke player
	# DIBUANG. Tap parry = berhasil tepat waktu = no damage. Fair.
	if _step == Step.PARRY_ACT:
		return
	# Script "big damage" biar HP mendarat PAS di 25%.
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
	# Balik ke idle (giliran player, gak ada yang jalan, kamera udah
	# balik) -> lanjut step. Timeout 4 dtk asal giliran bener balik,
	# biar gak softlock kalau kamera macet di tengah tween.
	if _pending_idle_step != Step.IDLE:
		var elapsed: int = Time.get_ticks_msec() - _pending_idle_since
		var ready: bool = _is_player_idle() and _is_camera_settled()
		var fallback: bool = is_player_turn and elapsed > 4000
		if ready or fallback:
			var s := _pending_idle_step
			_pending_idle_step = Step.IDLE
			_begin_step(s)
			return
	match _step:
		Step.POTION_SLOT:
			# Player milih slot potion -> arahin ke tombol USE.
			if _potion_ready_to_use():
				_begin_step(Step.POTION_USE)
		Step.POTION_USE:
			# Selesai pas HP naik (potion dipakai).
			if _tutorial_heal_before >= 0.0 and current_hp > _tutorial_heal_before + 1.0:
				_tutorial_heal_before = -1.0
				_begin_step(Step.HEALED)
		Step.LOOT_ACT:
			# Selesai pas item benar-benar masuk inventory player.
			if _loot_collected or _tutorial_inventory_count() > _tutorial_inv_before:
				_loot_collected = false
				_begin_step(Step.LOOT_DONE)
		Step.RAPID_DO:
			# Rapid kelar (timer habis) -> lanjut habis enemy turn.
			if _rapid_taught and not _is_rapid_active:
				_rapid_taught = false
				_live("RAPID COMPLETE", "That's rapid attack! Enemy turn...", TutorialUI.Zone.BOTTOM_LEFT, null)
				_wait_for_idle_then(Step.FINISH_INTRO)
		Step.FINISH_AFTER:
			# Musuh mati + drop nongol + kamera siap -> lanjut loot.
			if enemies.is_empty() and _drop_node and is_instance_valid(_drop_node) and _is_camera_settled():
				_begin_step(Step.LOOT_INTRO)
		Step.PACK_VIEW:
			# Inventory ditutup -> lanjut.
			if not is_inventory_open:
				_begin_step(Step.RUN_INTRO)
		Step.WAVE3_AFTER:
			# Serangan kelar + giliran balik + kamera siap -> hasil.
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


func _enemy_busy() -> bool:
	for e in enemies:
		if is_instance_valid(e) and e.is_taking_turn:
			return true
	return false


func _tutorial_inventory_count() -> int:
	var pd = PlayerDataManager.data
	if pd == null or pd.battle_inventory == null or pd.battle_inventory.items == null:
		return 0
	return pd.battle_inventory.items.size()


# Tutorial run yang ditinggal di tengah jalan bisa ninggalin potion
# numpuk sampe inventory 9/9 penuh — collect berikutnya FAIL
# ("Inventory Full!") dan tutorial softlock. Beresin sampah sendiri:
# kalau penuh, buang 1 health potion biar ada slot buat pelajaran.
func _ensure_loot_space() -> void:
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
	_begin_step(Step.ATTACK_INTRO)


func _on_attack_pressed() -> void:
	if not _tutorial_active:
		super._on_attack_pressed()
		return
	if _step == Step.ATTACK_ACT:
		_pause_game(false)
		super._on_attack_pressed()
		_begin_step(Step.BASIC_PICK)
	elif _step == Step.ATTACK2_ACT:
		_pause_game(false)
		super._on_attack_pressed()
		_begin_step(Step.CHARGE_PICK)
	elif _step == Step.ATTACK3_ACT:
		_pause_game(false)
		super._on_attack_pressed()
		_begin_step(Step.RAPID_PICK)
	elif _step == Step.FINISH_ACT:
		_pause_game(false)
		super._on_attack_pressed()
		_begin_step(Step.FINISH_PICK)
	elif _step == Step.WAVE3_FIGHT:
		_pause_game(false)
		super._on_attack_pressed()
		_begin_step(Step.WAVE3_PICK)
	# Step lain: terkunci (tombol disabled), handler gak kepanggil.


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
		Step.WAVE3_PICK:
			expected = "Basic"
		_:
			return
	var card: AttackCardData = attack_hand[index] if index >= 0 and index < attack_hand.size() else null
	if card == null:
		return
	if expected != "" and card.attack_type != expected:
		return  # bukan kartu yang lagi diajarin — abaikan
	if current_stamina < card.stamina_cost:
		_refill_stamina()
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
		Step.WAVE3_PICK:
			_w3_baseline_attacks = total_attacks
			_begin_step(Step.WAVE3_QTE)


func _check_attack_qte_result() -> void:
	super._check_attack_qte_result()
	if not _tutorial_active:
		return
	match _step:
		Step.QTE_DO:
			# Enemy turn (paksa) bakal jalan habis ini; parry lesson
			# nyusul otomatis pas attack_preparing.
			_begin_step(Step.QTE_RESULT)
		Step.FINISH_QTE:
			if total_miss > _fin_miss_before():
				_step = Step.FINISH_MISS
				_read("MISSED!", "No damage. Tap to try the finishing blow again.", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
			else:
				_step = Step.FINISH_AFTER
				_live("DIRECT HIT!", "Finishing blow landed!", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.WAVE3_QTE:
			_step = Step.WAVE3_AFTER
			_live("ATTACK LANDED", "Watch out — Grimward can counter!", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())


func _fin_miss_before() -> int:
	return int(get_meta("_tut_fin_miss", total_miss))


# Freeze-frame parry = tanpa shake/blood. Shake parent dipicu dari
# coroutine musuh yang jalan terus pas pause; kalau lolos, layar goyang
# + vignette darah padahal damage-nya di-swallow (lihat apply_damage).
func trigger_camera_shake_and_blood(intensity: float = 6.0, duration: float = 0.3, alpha_intensity: float = 0.6) -> void:
	if _tutorial_active and _step == Step.PARRY_ACT:
		return
	super.trigger_camera_shake_and_blood(intensity, duration, alpha_intensity)


func _on_enemy_attack_preparing() -> void:
	super._on_enemy_attack_preparing()
	if not _tutorial_active:
		return
	# Cuma pelajaran parry wave-1 yang diurus; serangan lain biarin natural.
	if _step == Step.QTE_RESULT or _step == Step.PARRY_WAIT:
		var live: Array = enemies.filter(func(e): return is_instance_valid(e) and e.current_hp > 0)
		if live.is_empty():
			return
		# Kasih napas 0.35 dtk LIVE dulu (skeleton jalan ~2 frame,
		# kamera + teks reaksi kebaca), BARU freeze. Langsung pause di
		# frame 0 keliatan kayak nge-hang, bukan kayak di-stop.
		_lesson_parry_open = true
		_delay_parry_freeze()


# Beat dramatis sebelum freeze: biarin serangan jalan bentar live,
# terus pause tepat di tengah ayunan. Guard berlapis biar gak freeze
# kalau step udah pindah (mis. player tap parry duluan).
func _delay_parry_freeze() -> void:
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(self) or not _tutorial_active:
		return
	if not _lesson_parry_open:
		return
	if _step != Step.QTE_RESULT and _step != Step.PARRY_WAIT:
		return
	var live: Array = enemies.filter(func(e): return is_instance_valid(e) and e.current_hp > 0)
	if live.is_empty():
		return
	_begin_step(Step.PARRY_ACT)


func _on_parry_button_clicked() -> void:
	if not _tutorial_active:
		super._on_parry_button_clicked()
		return
	if _step == Step.PARRY_ACT or (_step == Step.PARRY_WAIT and _lesson_parry_open):
		# Tap pas beat 0.35 dtk (sebelum freeze) juga sah.
		_lesson_parry_open = false
		# Resume DULU baru efek: biar sfx parry kedengeran (solo-mute
		# mati pas unpause), terus musuh selesaikan serangan live.
		_pause_game(false)
		super._on_parry_button_clicked()
		_begin_step(Step.PARRY_RESULT)
		return
	# Window parry di luar pelajaran (musuh normal nyerang pas wait):
	# kasih efeknya aja, flow tutorial gak diganggu.
	super._on_parry_button_clicked()


func _on_defend_pressed() -> void:
	if not _tutorial_active:
		super._on_defend_pressed()
		return
	if _step != Step.DEFEND_ACT:
		return
	_live("GUARD UP!", "Stamina +20. Enemy turn — watch what happens.", TutorialUI.Zone.BOTTOM_LEFT, null)
	super._on_defend_pressed()
	_wait_for_idle_then(Step.SKILL_INTRO)


func _on_skill_pressed() -> void:
	if not _tutorial_active:
		super._on_skill_pressed()
		return
	if _step != Step.SKILL_ACT:
		return
	super._on_skill_pressed()
	_skill_ui_ref = null
	_begin_step(Step.SKILL_PICK)


func _on_action_card_closed() -> void:
	super._on_action_card_closed()
	# Deck skill ditutup — ref dibuang biar gak nemu deck basi.
	_skill_ui_ref = null


func _on_action_card_selected(index: int) -> void:
	if not _tutorial_active:
		super._on_action_card_selected(index)
		return
	if _step != Step.SKILL_PICK:
		return
	if index != 0:
		return  # bukan kartu yang di-highlight — abaikan
	if index < 0 or index >= action_cards.size():
		return
	_refill_stamina()
	super._on_action_card_selected(index)
	_live("SKILL USED!", "Effect applied. Enemy turn...", TutorialUI.Zone.BOTTOM_LEFT, null)
	_wait_for_idle_then(Step.ATTACK2_INTRO)


func _on_charge_complete(multiplier: float) -> void:
	if not _tutorial_active:
		super._on_charge_complete(multiplier)
		return
	if _step != Step.CHARGE_DO:
		return
	super._on_charge_complete(multiplier)
	_live("CHARGE COMPLETE!", "Big damage! Enemy turn...", TutorialUI.Zone.BOTTOM_LEFT, null)
	_wait_for_idle_then(Step.ATTACK3_INTRO)


func _on_raptive_btn_pressed() -> void:
	super._on_raptive_btn_pressed()
	if _tutorial_active and _step == Step.RAPID_DO and _rapid_hits == 1:
		_live("RAPID ATTACK", "Good! Keep tapping the buttons — fast!", TutorialUI.Zone.BOTTOM_LEFT, rapid_btn)


func _on_backpack_pressed() -> void:
	if not _tutorial_active:
		super._on_backpack_pressed()
		return
	if _step == Step.PACK_ACT:
		_pause_game(false)
		super._on_backpack_pressed()
		_begin_step(Step.PACK_VIEW)
	elif _step == Step.PACK2_ACT:
		_pause_game(false)
		super._on_backpack_pressed()
		_potion_index = _find_potion_slot()
		_begin_step(Step.POTION_SLOT)


func _on_item_used_in_battle(item: ItemData) -> void:
	super._on_item_used_in_battle(item)
	# Heal kedetek di _process (POTION_USE -> HEALED).


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


func _inventory_slot_button(idx: int) -> Button:
	if not is_instance_valid(battle_inventory_instance):
		return null
	var slots: Array = battle_inventory_instance.get("_slots")
	if slots == null or idx < 0 or idx >= slots.size():
		return null
	var slot: Node = slots[idx]
	for c in slot.get_children():
		if c is Button:
			return c as Button
	return null


# ============================================================
# STEP MACHINE
# ============================================================

func _begin_step(step: Step) -> void:
	_step = step
	_unlock_all()
	_pending_idle_step = Step.IDLE
	match step:
		Step.WELCOME:
			_read("WELCOME, KNIGHT", "Battle training, step by step. Tap anywhere to start.", TutorialUI.Zone.TOP_CENTER, null)
		Step.TARGET_INTRO:
			_read("MEET THE ENEMY", "This is a Skeleton. Tap to continue.", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.TARGET_ACT:
			_act("SELECT TARGET", "Tap the Skeleton to lock it as your target.", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.ATTACK_INTRO:
			_reveal(atk_btn)
			_read("BUTTON: ATTACK", "This opens your attack cards. Tap to continue.", TutorialUI.Zone.BOTTOM_LEFT, atk_btn)
		Step.ATTACK_ACT:
			_reveal(atk_btn, true)
			_act("TAP ATTACK", "Tap the ATTACK button now.", TutorialUI.Zone.BOTTOM_LEFT, atk_btn)
		Step.BASIC_PICK:
			_pick_setup(false, "Basic", "BASIC CARD", "Tap the glowing BASIC card.")
		Step.QTE_DO:
			_lock_all_except([attack_qte_node, reset_target_btn])
			_live("TIMING BAR", "Tap ANYWHERE when the runner hits GOLD!", TutorialUI.Zone.BOTTOM_LEFT, attack_qte_node)
		Step.QTE_RESULT:
			_read(_qte_title(), _last_attack_result_text() + " Tap to continue.", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.PARRY_WAIT:
			_pause_game(false)
			_lock_all_except([])
			_live("ENEMY TURN", "Skeleton's turn. Watch for a SHIELD button!", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.PARRY_ACT:
			_act("PARRY!", "A shield appeared! Tap it NOW to parry!", TutorialUI.Zone.BOTTOM_LEFT, parry_btn)
		Step.PARRY_RESULT:
			# Hasil parry = info LIVE, bukan read-pause. Tap parry =
			# langsung resume semua (jangan kebanyakan stop): musuh
			# selesaikan serangannya live, DEFEND_INTRO nunggu giliran
			# balik beneran via _pending_idle_step.
			_pause_game(false)
			_lock_all_except([])
			_live("PARRIED!", "Blocked most damage + bonus stamina. Watch!", TutorialUI.Zone.BOTTOM_LEFT, player_info)
			_wait_for_idle_then(Step.DEFEND_INTRO)
		Step.DEFEND_INTRO:
			_reveal(defend_btn)
			_read("BUTTON: DEFEND", "Restores 20 stamina, but skips your attack. Tap to continue.", TutorialUI.Zone.BOTTOM_LEFT, defend_btn)
		Step.DEFEND_ACT:
			_reveal(defend_btn, true)
			_act("TAP DEFEND", "Tap DEFEND and watch your stamina.", TutorialUI.Zone.BOTTOM_LEFT, defend_btn)
		Step.SKILL_INTRO:
			_reveal(skill_btn)
			_read("BUTTON: SKILL", "Special cards: poison, stun, bleed. Tap to continue.", TutorialUI.Zone.BOTTOM_LEFT, skill_btn)
		Step.SKILL_ACT:
			_reveal(skill_btn, true)
			_act("TAP SKILL", "Tap SKILL to open the skill deck.", TutorialUI.Zone.BOTTOM_LEFT, skill_btn)
		Step.SKILL_PICK:
			_pick_setup(true, "", "SKILL CARD", "Tap the glowing SKILL card.")
		Step.ATTACK2_INTRO:
			_read("ATTACK AGAIN", "New card type: CHARGE. Tap to continue.", TutorialUI.Zone.BOTTOM_LEFT, atk_btn)
		Step.ATTACK2_ACT:
			_enable_only([atk_btn])
			_act("TAP ATTACK", "Open your attack cards again.", TutorialUI.Zone.BOTTOM_LEFT, atk_btn)
		Step.CHARGE_PICK:
			_pick_setup(false, "Charge", "CHARGE CARD", "Tap the glowing CHARGE card.")
		Step.CHARGE_DO:
			_pause_game(false)
			var cb := _charge_button()
			_lock_all_except([cb] if cb else [])
			if cb:
				_allow_interaction(cb)
			_live("HOLD & RELEASE", "Hold the button, release inside GOLD for max damage!", TutorialUI.Zone.BOTTOM_LEFT, cb)
		Step.ATTACK3_INTRO:
			_read("ONE MORE TYPE", "Last one: RAPID. Tap to continue.", TutorialUI.Zone.BOTTOM_LEFT, atk_btn)
		Step.ATTACK3_ACT:
			_enable_only([atk_btn])
			_act("TAP ATTACK", "Open your attack cards.", TutorialUI.Zone.BOTTOM_LEFT, atk_btn)
		Step.RAPID_PICK:
			_pick_setup(false, "Rapid", "RAPID CARD", "Tap the glowing RAPID card.")
		Step.RAPID_DO:
			_pause_game(false)
			_lock_all_except([rapid_btn])
			_allow_interaction(rapid_btn)
			_live("TAP FAST!", "Tap every button before time runs out!", TutorialUI.Zone.BOTTOM_LEFT, rapid_btn)
		Step.FINISH_INTRO:
			_read("ARMOR OFF!", "Training wheels off — real damage now. Finish it!", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.FINISH_ACT:
			_enable_only([atk_btn])
			_act("FINISH IT", "Tap ATTACK for the final blow.", TutorialUI.Zone.BOTTOM_LEFT, atk_btn)
		Step.FINISH_PICK:
			_pick_setup(false, "Basic", "FINAL BLOW", "Tap BASIC to finish the Skeleton.")
		Step.FINISH_QTE:
			_lock_all_except([attack_qte_node, reset_target_btn])
			_live("FINISH!", "Tap when the runner hits GOLD!", TutorialUI.Zone.BOTTOM_LEFT, attack_qte_node)
		Step.FINISH_AFTER:
			pass  # dijaga _process (musuh mati + drop)
		Step.FINISH_MISS:
			_read("MISSED!", "No damage. Tap to try the finishing blow again.", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.FINISH_MISS:
			_read("MISSED!", "No damage. Tap to try the finishing blow again.", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.LOOT_INTRO:
			_tutorial_inv_before = _tutorial_inventory_count()
			_loot_collected = false
			_ensure_loot_space()
			# Musuh terakhir mati -> parent _start_enemies_turn TIDAK
			# balikin is_player_turn (cuma kalau musuh sisa). Tutorial
			# yang balikin manual, kalau bukan semua tombol dikira
			# "bukan giliran player" dan backpack gak bisa dibuka.
			is_player_turn = true
			_apply_button_gating(false)
			_read("LOOT DROPPED!", "The Skeleton dropped something. Tap to continue.", TutorialUI.Zone.BOTTOM_LEFT, _drop_node)
		Step.LOOT_ACT:
			_pause_game(false)
			_lock_all_except([_drop_node])
			_allow_interaction(_drop_node)
			_live("COLLECT LOOT", "Tap the glowing item to collect it.", TutorialUI.Zone.BOTTOM_LEFT, _drop_node)
		Step.LOOT_DONE:
			_reveal(backpack_btn)
			_read("LOOT SECURED!", "Saved to your BACKPACK permanently. Tap to continue.", TutorialUI.Zone.BOTTOM_LEFT, backpack_btn)
		Step.PACK_INTRO:
			_read("BUTTON: BACKPACK", "All your items live here. Tap to continue.", TutorialUI.Zone.BOTTOM_LEFT, backpack_btn)
		Step.PACK_ACT:
			_reveal(backpack_btn, true)
			_act("OPEN BACKPACK", "Tap BACKPACK to look inside.", TutorialUI.Zone.BOTTOM_LEFT, backpack_btn)
		Step.PACK_VIEW:
			_pause_game(false)
			var close_b: Button = _inventory_close_button()
			_lock_all_except([close_b] if close_b else [])
			if close_b:
				_allow_interaction(close_b)
			_live("YOUR BACKPACK", "Potion is in a slot. Tap CLOSE when done.", TutorialUI.Zone.TOP_CENTER, close_b)
		Step.RUN_INTRO:
			_reveal(run_btn)
			_read("BUTTON: RUN", "RUN flees battle — locked during training. Tap to continue.", TutorialUI.Zone.BOTTOM_LEFT, run_btn)
		Step.WAVE2_INTRO:
			_read("WAVE 2", "Another Skeleton! But something feels wrong...", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.HURT_ANIM:
			pass  # dijaga _do_scripted_hurt (async)
		Step.HURT_INFO:
			_ui_set_hp_note(true)
			_read("YOU'RE HURT!", "HP dropped to 25%! You need that potion. Tap to continue.", TutorialUI.Zone.BOTTOM_LEFT, player_info)
		Step.PACK2_ACT:
			_reveal(backpack_btn, true)
			_act("GRAB THE POTION", "Open BACKPACK and use your Health Potion.", TutorialUI.Zone.BOTTOM_LEFT, backpack_btn)
		Step.POTION_SLOT:
			_pause_game(false)
			var slot_b: Button = _inventory_slot_button(_potion_index)
			_lock_all_except([slot_b] if slot_b else [])
			if slot_b:
				_allow_interaction(slot_b)
			_live("FIND THE POTION", "Tap the glowing Health Potion slot.", TutorialUI.Zone.TOP_CENTER, slot_b)
		Step.POTION_USE:
			_pause_game(false)
			_tutorial_heal_before = current_hp
			var use_b: Button = _inventory_use_button()
			_lock_all_except([use_b] if use_b else [])
			if use_b:
				_allow_interaction(use_b)
			_live("DRINK IT!", "Tap USE to drink the Health Potion.", TutorialUI.Zone.TOP_CENTER, use_b)
		Step.HEALED:
			_ui_set_hp_note(false)
			_read("HEALED!", "Always keep potions ready. Tap to continue.", TutorialUI.Zone.TOP_CENTER, player_info)
		Step.WAVE3_INTRO:
			_read("WAVE 3: GRIMWARD", "Tougher. It can COUNTER your attacks (30%). Tap to continue.", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.WAVE3_FIGHT:
			_pause_game(false)
			_force_basic_hand()
			_enable_only([atk_btn])
			_live("YOUR MOVE", "Attack the Grimward — watch for counters!", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.WAVE3_PICK:
			_pick_setup(false, "Basic", "PICK A CARD", "Tap the glowing BASIC card.")
		Step.WAVE3_QTE:
			_lock_all_except([attack_qte_node, reset_target_btn])
			_live("TIMING!", "Tap when the runner hits GOLD!", TutorialUI.Zone.BOTTOM_LEFT, attack_qte_node)
		Step.WAVE3_AFTER:
			pass  # dijaga _process (giliran balik)
		Step.WAVE3_DONE:
			_read("WELL FOUGHT!", "You survived a counter-attacker. Tap to finish.", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.COMPLETE:
			_pause_game(true)
			_lock_all_except([])
			_ui_show_final("TRAINING COMPLETE\nYou know: target, attack, cards, timing, parry, defend, skills, charge, rapid, loot, backpack, potions. Good luck, Knight!")


# Pasang tunggu-giliran. Dipakai habis tiap aksi yang mancing enemy
# turn (parry/defend/skill/charge/rapid).
func _wait_for_idle_then(step: Step) -> void:
	_pending_idle_step = step
	_pending_idle_since = Time.get_ticks_msec()


# Kamera siap = balik ke default (zoom 1 + posisi awal). Tutorial
# suka zoom ke musuh; step berikutnya JANGAN nongol selagi kamera
# masih di jalan — tombol keliatan belum siap, gak nyambung.
func _is_camera_settled() -> bool:
	if camera == null:
		return true
	if camera.zoom.distance_to(Vector2.ONE) > 0.08:
		return false
	if camera.global_position.distance_to(default_camera_pos) > 12.0:
		return false
	return true


# Step BACA: tree di-pause, panel muncul, player tap panel buat lanjut.
func _read(title: String, body: String, zone: TutorialUI.Zone, spot: Node) -> void:
	_pause_game(true)
	_lock_all_except([])
	_show(title, body, zone, spot, true)


# Step AKSI (target tunggal, tree paused): target dibikin ALWAYS.
func _act(title: String, body: String, zone: TutorialUI.Zone, target: Node) -> void:
	_pause_game(true)
	_lock_all_except([target] if target else [])
	if target:
		_allow_interaction(target)
	_show(title, body, zone, target, false)


# Step LIVE (tree jalan: kartu, QTE, charge, rapid, inventory, wait).
func _live(title: String, body: String, zone: TutorialUI.Zone, spot: Node) -> void:
	_pause_game(false)
	_show(title, body, zone, spot, false)


func _step_no() -> int:
	return int(_step)


func _step_total() -> int:
	return int(Step.COMPLETE)


func _show(title: String, body: String, zone: TutorialUI.Zone, spot: Node, dismissable: bool) -> void:
	if _tutorial_ui:
		_tutorial_ui.set_spotlight_target(spot)
		_tutorial_ui.show_text("STEP %d/%d — %s\n%s" % [_step_no(), _step_total(), title, body], zone, true, dismissable)


func _qte_title() -> String:
	if total_critical > 0:
		return "PERFECT!"
	return "HIT!"


func _enemy_ref() -> Node:
	if not enemies.is_empty():
		return enemies[selected_enemy_index] if selected_enemy_index < enemies.size() else enemies[0]
	return null


func _charge_button() -> Button:
	if charge_attack_ui:
		return charge_attack_ui.get("button_charge") as Button
	return null


# Deck W3 dipaksa BASIC only biar mekaniknya pasti QTE
# (charge/rapid butuh step panel sendiri-sendiri).
func _force_basic_hand() -> void:
	attack_hand.clear()
	attack_discard.clear()
	var data: AttackCardData = load(BASIC_PATH) as AttackCardData
	if data:
		attack_hand.append(data.duplicate())


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
	_pause_game(false)
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
	# Tutup jalan kabur: klik background = close deck. Dikunci.
	_lock_card_bg()
	_show(title, body, TutorialUI.Zone.BOTTOM_LEFT, card, false)


func _lock_card_bg() -> void:
	for ui in [attack_card_ui, _find_skill_ui()]:
		if ui and is_instance_valid(ui):
			var bg = ui.get("bg_overlay")
			if bg is Control:
				(bg as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


# ============================================================
# PAUSE
# ============================================================

func _pause_game(paused: bool) -> void:
	# Pause tree total. Node tutorial (PROCESS_MODE_ALWAYS) tetap jalan.
	get_tree().paused = paused
	# Audio ikut: pause = senyap total kecuali musik, resume = balik.
	_set_freeze_audio(paused)


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
			continue  # musuh & efek visual jangan disentuh
		if n is Control:
			_disable_node(n)
	# Klik musuh: collision + profile, kecuali musuh target.
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
				if btn is Button:
					(btn as Button).disabled = false
			else:
				(btn as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
				if btn is Button:
					(btn as Button).disabled = true


func _set_enemy_clickable_all(allow: bool) -> void:
	for e in enemies:
		_set_enemy_clickable(e, allow)


# Marka target jadi bisa diklik: mouse_filter STOP + process_mode ALWAYS
# (kalau tree paused, node pausable default-nya GAK bisa terima GUI input).
func _allow_interaction(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var n := node
	# Kalau target-nya Enemy (Node2D), yang perlu diklik TextureButton
	# di dalamnya, bukan si Node2D-nya.
	if n is BattleEnemy:
		n = (n as BattleEnemy).enemy_collision
	if n == null or not is_instance_valid(n):
		return
	_save_state_if_needed(n)
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_STOP
		if n is Button:
			(n as Button).disabled = false
	n.process_mode = Node.PROCESS_MODE_ALWAYS
	if not (n in _always_nodes):
		_always_nodes.append(n)
	# Parent sembunyiin tombol interaction dgn menggeser y +200px.
	# Kalau target step ini salah satunya, taruh balik ke posisi asli.
	var y := _original_y_for(n)
	if y != INF and n is Control:
		(n as Control).position.y = y


# Bus musik khusus tutorial. Semua audio game (musik + SFX) default di
# bus Master, jadi mute Master ikut bunuh musik. Solusinya: pindahin
# player musik ke bus sendiri SEKALI, terus pakai bus SOLO pas freeze —
# solo = cuma bus itu yang bunyi, sisanya senyap total. Musik jalan terus.
var _music_bus_idx := -1


func _ensure_music_bus() -> int:
	if _music_bus_idx >= 0:
		return _music_bus_idx
	var idx := AudioServer.get_bus_index("TutMusic")
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "TutMusic")
	var mm = get_node_or_null("/root/MusicManager")
	if mm:
		var p = mm.get("_current_player")
		if p is AudioStreamPlayer:
			(p as AudioStreamPlayer).bus = "TutMusic"
			# WAJIB: player musik default pausable -> tree pause ikut
			# matiin musiknya (playing=false). ALWAYS biar musik JALAN
			# TERUS walau lagi freeze. Solo bus gak guna kalau playernya
			# mati sendiri.
			(p as AudioStreamPlayer).process_mode = Node.PROCESS_MODE_ALWAYS
	_music_bus_idx = idx
	return idx


# Freeze audio: true = senyap total KECUALI musik. Dipanggil sentral
# dari _pause_game() — setiap pause tutorial = Minden berhenti kecuali
# musik, setiap resume = balik normal. Gak ada jalur yang bocor.
func _set_freeze_audio(frozen: bool) -> void:
	if frozen:
		var idx := _ensure_music_bus()
		if idx >= 0:
			AudioServer.set_bus_solo(idx, true)
	else:
		if _music_bus_idx >= 0:
			AudioServer.set_bus_solo(_music_bus_idx, false)
# Posisi Y asli tombol interaction, dicatat parent di _ready().
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


func _interactive_nodes() -> Array:
	# Tutorial UI sendiri JANGAN dikunci.
	var guard: Array = []
	if _tutorial_layer:
		guard = _descendants(_tutorial_layer)
	var out: Array = []
	for n in _descendants(self):
		if n is Button and not (n in guard):
			out.append(n)
	return out


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
		if node is Button:
			var b := node as Button
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
	if node is Button:
		(node as Button).disabled = true


func _unlock_all() -> void:
	# Balikin SEMUA yang pernah kita sentuh ke state aslinya.
	for c in _locked_nodes:
		if is_instance_valid(c):
			if c is Button:
				var b := c as Button
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


func _last_attack_result_text() -> String:
	if total_critical > 0:
		return "**Perfect!** Great timing = bonus damage."
	return "Attack connected. Timing decides the damage."


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
	# Counter di-nerf ke 30%: data grimward punya tactical_attack:3
	# (=100% counter). Beginner gak siap ngadep itu.
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var ab := e.get_tactical_attack_ability()
		if ab:
			ab.level = 1


func _goto_wave2() -> void:
	if _wave2_spawned:
		return
	_wave2_spawned = true
	_step = Step.IDLE
	_ui_hide()
	_pause_game(false)
	_unlock_all()
	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(self) or not _tutorial_active:
		return
	spawn_wave2_skeleton()
	await get_tree().create_timer(1.4).timeout
	if not is_instance_valid(self) or not _tutorial_active:
		return
	_begin_step(Step.WAVE2_INTRO)


func _goto_wave3() -> void:
	if _wave3_spawned:
		return
	_wave3_spawned = true
	_step = Step.IDLE
	_ui_hide()
	_pause_game(false)
	_unlock_all()
	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(self) or not _tutorial_active:
		return
	spawn_wave3_grimward()
	await get_tree().create_timer(1.4).timeout
	if not is_instance_valid(self) or not _tutorial_active:
		return
	_begin_step(Step.WAVE3_INTRO)


func _do_scripted_hurt() -> void:
	if _hurt_step_done:
		return
	_hurt_step_done = true
	_begin_step(Step.HURT_ANIM)
	_pause_game(false)
	_lock_all_except([])
	_live("WATCH OUT!", "The Skeleton strikes with a heavy blow!", TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
	trigger_scripted_hurt()
	await get_tree().create_timer(1.2).timeout
	if not is_instance_valid(self) or not _tutorial_active:
		return
	_begin_step(Step.HURT_INFO)


func trigger_scripted_hurt() -> void:
	# Script "big damage" -> HP mendarat di floor 25%.
	_pending_scripted_damage = true
	apply_damage_raw(999.0)
