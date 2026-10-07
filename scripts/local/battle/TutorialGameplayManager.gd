extends "res://scripts/local/battle/BattleManager.gd"
class_name TutorialGameplayManager

# ============================================================
# TUTORIAL GAMEPLAY MANAGER
#extends BattleManager. Override HANYA yang perlu dibedain —
# BattleManager.gd sendiri 100% utuh.
#
# Aturan main:
#  - 3 wave: Skeleton -> Skeleton -> Grimward
#  - Setiap interaksi: PAUSE TOTAL -> spotlight + teks -> tap -> unpause
#  - Gagal step: retry sampai sukses
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

# --- Step ---
enum Step {
	IDLE,
	INTRO_TARGET,        # 1 tap skeleton
	INTRO_ATTACK_BTN,    # 2 tap atkBtn
	SELECT_BASIC_CARD,   # 3 pilih basic card
	ATTACK_QTE,          # 4 QTE
	ATTACK_QTE_RESULT,   # 4b penjelasan hasil
	PARRY,               # 5 tap parry
	PARRY_RESULT,        # 5b penjelasan hasil
	DEFEND,              # 6 tap defend
	SKILL,               # 7 pilih skill card
	CHARGE,              # 8 charge
	RAPID,               # 9 rapid
	LOOT_APPEARED,       # 10 drop muncul
	LOOT_COLLECT,        # 11 tap item
	LOOT_STORED,         # 12 penjelasan
	OPEN_BACKPACK,       # 13 buka backpack
	WAVE2_INTRO,         # 14a skeleton ke-2
	HURT_HP,             # 14 HP lo 25%
	OPEN_BACKPACK_HURT,  # 15 buka backpack
	USE_POTION,          # 16 tap USE
	HEALED,              # 16b penjelasan
	WAVE3_INTRO,         # 17 grimward
	WAVE3_OBSERVE,       # 18 observe HP drop
	COMPLETE,            # 19 tombol Continue
}

# --- State runtime ---
var _tutorial_active := false
var _step: Step = Step.IDLE
var _target_selected_once := false
var _tutorial_ui: TutorialUI = null
var _tutorial_layer: CanvasLayer = null
var _wave_index := 0
var _was_paused_by_tutorial := false
var _pending_scripted_damage := false
var _charge_completed := false
var _used_potion_this_step := false
var _hp_was_drained := false
var _drop_node: Node = null
var _tutorial_inv_before: int = 0
var _tutorial_heal_before: float = 0.0
var _pary_result_ready: bool = false
var _pending_wave_spawn: int = 0  # 0 = ga ada, 2 = skeleton, 3 = grimward
var _hurt_step_done: bool = false
var _wave2_spawned: bool = false
var _wave3_spawned: bool = false
var _locked_nodes: Array[Control] = []
var _saved_mouse_filters: Dictionary = {}

# Guard: HP floor HANYA buat damage dari enemy (bukan drain script)


func _ready() -> void:
	_wave_index = 0
	_tutorial_active = true
	super._ready()
	_setup_tutorial_layer()
	# Step 1: pause total + spotlight skeleton. Beri jeda biar
	# intro battle parent (hand, map title) selesai dulu.
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(self):
		_begin_step(Step.INTRO_TARGET)


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


# Player tap layar pas step BACA: panel ilang, lanjut ke step aksi.
func _on_tutorial_tapped() -> void:
	if not _tutorial_active or _step == Step.IDLE:
		return
	match _step:
		Step.ATTACK_QTE_RESULT:
			_advance_to(Step.PARRY)
		Step.PARRY_RESULT:
			if _pary_result_ready:
				_pary_result_ready = false
				_advance_to(Step.DEFEND)
		Step.LOOT_APPEARED:
			_advance_to(Step.LOOT_COLLECT)
		Step.LOOT_STORED:
			_advance_to(Step.OPEN_BACKPACK)
		Step.OPEN_BACKPACK_HURT:
			_used_potion_this_step = false
			_advance_to(Step.USE_POTION)
		Step.HEALED:
			_unlock_all()
			_pause_game(false)
			_spawn_wave3()
			_advance_to(Step.WAVE3_INTRO)
		Step.WAVE2_INTRO:
			# Spawn skeleton ke-2, skripтед hurt jalan di _process.
			_spawn_wave2()
			_advance_to(Step.HURT_HP)
		Step.WAVE3_INTRO:
			_advance_to(Step.WAVE3_OBSERVE)
		Step.WAVE3_OBSERVE:
			_advance_to(Step.COMPLETE)
		_:
			pass


func _spawn_wave2() -> void:
	if _wave2_spawned:
		return
	_wave2_spawned = true
	_pending_wave_spawn = 2
	_unlock_all()
	_pause_game(false)
	spawn_wave2_skeleton()


func _spawn_wave3() -> void:
	if _wave3_spawned:
		return
	_wave3_spawned = true
	_pending_wave_spawn = 3
	_unlock_all()
	_pause_game(false)
	spawn_wave3_grimward()


# ============================================================
# OVERRIDE: SPAWN — skeleton -> skeleton -> grimward
# ============================================================

func _spawn_enemies(_enemy_ids: Array[String], _custom_levels: Array[int] = []) -> void:
	if not _tutorial_active:
		super._spawn_enemies(_enemy_ids, _custom_levels)
		return
	# Parent _ready() manggil spawn_random_enemies(1, n, 1, 5) yg
	#随机 n enemy. Tutorial mau PAKAI 1 skeleton aja di wave 1,
	# jadi kita emergency-cancel hasil random itu: queue_free semua
	# enemy yg ke-spawn, baru spawn 1 skeleton.
	if _wave_index == 0:
		_wave_index = 1
		for e in enemies:
			if is_instance_valid(e):
				e.queue_free()
		enemies.clear()
		selected_enemy_index = 0
		super._spawn_enemies(["skeleton"] as Array[String], [1] as Array[int])


func _tutorial_spawn(ids: Array[String], levels: Array[int]) -> void:
	super._spawn_enemies(ids, levels)


# ============================================================
# OVERRIDE: PARRY WINDOW — pause-aware timer
# create_timer() default process_always=true -> tetep jalan
# walau tree paused -> parry btn auto-hide di tengah baca.
# Pakai process_always=false biar ikut beku.
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

	var viewport_size = get_viewport().get_visible_rect().size
	var min_x = 120.0
	var max_x = viewport_size.x - 220.0
	var min_y = 150.0
	var max_y = viewport_size.y - 250.0

	parry_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	parry_btn.position = Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
	parry_btn.modulate = Color(1, 1, 1, 0)
	parry_btn.scale = Vector2(0.01, 0.01)
	parry_btn.show()

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
	# process_always = false -> timer beneran freeze pas tutorial pause
	parry_timer = get_tree().create_timer(duration, false)
	await parry_timer.timeout

	if parry_btn.visible and not parry_success_this_turn:
		var visual_center = parry_btn.position + Vector2(40, 40)
		_spawn_missed_popup_text(visual_center)
		_hide_parry_window()


# ============================================================
# OVERRIDE: DEATH — paksa drop item
# ============================================================

func _process_enemy_death(_exp_amount: int, _gold_amount: int, _dropped_items: Array[String], enemy: BattleEnemy) -> void:
	super._process_enemy_death(_exp_amount, _gold_amount, _dropped_items, enemy)
	if not _tutorial_active or enemy == null or not is_instance_valid(enemy):
		return
	# Paksa drop Health Potion (skeleton drop_chance cuma 0.1).
	# Delay biar selesai animasi kematian dulu.
	_tutorial_force_drop(enemy)


func _tutorial_force_drop(enemy: BattleEnemy) -> void:
	var pos := enemy.global_position
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(self):
		return
	# Freeze despawn drop biar gak ilang 8 detik (step collect)
	var drop = _spawn_drop_item_keep(TUTORIAL_DROP_ID, pos, 0.0)
	if drop:
		_drop_node = drop
		# Step 10 (LOOT_APPEARED) dipicu di _process()


func _spawn_drop_item_keep(item_id: String, enemy_pos: Vector2, spawn_delay: float = 0.0) -> Node:
	# Mirip _spawn_drop_item parent, tapi freeze DESPAWN_TIME.
	# ItemDropVisual punya Timer (line 111) + tween; kita set
	# process_mode ALWAYS + timer stop biar gak ke-despawn.
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
	# Freeze despawn 8 detik. ItemDropVisual bikin Timer-nya sendiri
	# (line 110-115) dan tween timing bar (line 73-74). Stop keduanya
	# + pause _process biar idle float & glow tetap jalan tapi item
	# gak pernah keburu ilang sebelum player sempet klik.
	drop_visual.set_process(false)
	var timer := _find_timer_recursive(drop_visual)
	if timer:
		timer.paused = true
	var timing := drop_visual.get_node_or_null("timing") as TextureProgressBar
	if timing:
		timing.value = timing.max_value
	return drop_visual


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
	# Step 14: script "big damage" biar HP mendarat PAS di 25%.
	# Musuh skeleton damage cuma 3, jadi kita karang base_damage.
	# Tambah ajek biar hasil akhir = floor, bukan floor + durability,
	# karena apply_damage() parent memotong player_durability (5).
	if _pending_scripted_damage:
		_pending_scripted_damage = false
		var target_hp: float = max_hp * HP_FLOOR_PCT
		var needed: float = max(0.0, current_hp - target_hp) + player_durability
		event.base_damage = needed
	# Override apply_damage, tapi panggil parent biar animasi/UI normal.
	super.apply_damage(event)
	# HP floor: jangan pernah di bawah 25%.
	if current_hp < max_hp * HP_FLOOR_PCT:
		current_hp = max_hp * HP_FLOOR_PCT
		if hp_bar:
			_update_player_ui_instant()


# ============================================================
# FLOW UTAMA
# ============================================================

func _process(_delta: float) -> void:
	super._process(_delta)
	if not _tutorial_active:
		return
	# Wave 1 clear -> skeleton ke-2 nyerang -> scripted hurt (HP ke 25%).
	# Dipicu di frame yg sama pas skeleton mulai take_turn.
	if _pending_wave_spawn == 2:
		_pending_wave_spawn = 0
		_hp_was_drained = false
	# Scripted hurt dipicu di sini karena ini satu-satunya _process yg
	# jalan: tree di-unpause pas step HURT_HP (tutorial nunggu player
	# buka backpack), jadi manager aktif lagi.
	if _hurt_step_done or not _wave2_spawned:
		return
	if _step != Step.HURT_HP or enemies.is_empty():
		return
	var live: int = enemies.filter(func(e): return is_instance_valid(e) and e.current_hp > 0).size()
	if live <= 0:
		return
	_hurt_step_done = true
	trigger_scripted_hurt()
	# CATATAN: step BACA (tap panel buat lanjut) ditangani di
	# _on_tutorial_tapped() via signal TutorialUI.tapped.
	# JANGAN pakai try_dismiss_on_tap() di sini — tree paused, _process()
	# manager = pausable jadi malah GAK PERNAH jalan.
	match _step:
		Step.LOOT_COLLECT:
			# Selesai pas item benar-benar masuk inventory player.
			if _tutorial_inventory_count() > _tutorial_inv_before:
				_advance_to(Step.LOOT_STORED)
		Step.HURT_HP:
			# Tunggu player buka backpack (tutorial yg trigger setelah
			# backpack berisi potion -> langsung ke USE_POTION step)
			if is_inventory_open:
				_unlock_all()
				_pause_game(false)
				_advance_to(Step.USE_POTION)
		Step.USE_POTION:
			# Selesai pas HP naik (potion dipakai).
			if _tutorial_heal_before >= 0.0 and current_hp > _tutorial_heal_before + 1.0:
				_tutorial_heal_before = -1.0
				_unlock_all()
				_pause_game(false)
				_advance_to(Step.HEALED)
		Step.PARRY:
			if total_parries > 0:
				_advance_to(Step.PARRY_RESULT)
		Step.INTRO_TARGET:
			if selected_enemy_index >= 0 and not enemies.is_empty():
				if enemies[selected_enemy_index] and _target_selected_once:
					_advance_to(Step.INTRO_ATTACK_BTN)


func _tutorial_inventory_count() -> int:
	var pd = PlayerDataManager.data
	if pd == null or pd.battle_inventory == null or pd.battle_inventory.items == null:
		return 0
	return pd.battle_inventory.items.size()


func _on_enemy_clicked(clicked_enemy: BattleEnemy) -> void:
	super._on_enemy_clicked(clicked_enemy)
	_target_selected_once = true
	if _step == Step.INTRO_TARGET:
		# Tap area spotlight = aksi. Panel ilang, unpause.
		_ui_hide()
		_unlock_all()
		_pause_game(false)
		_advance_to(Step.INTRO_ATTACK_BTN)


func _on_attack_pressed() -> void:
	super._on_attack_pressed()
	if _step == Step.INTRO_ATTACK_BTN:
		# Deck kebuka -> lanjut ke step pilih kartu
		_ui_hide()
		_unlock_all()
		_pause_game(false)
		_advance_to(Step.SELECT_BASIC_CARD)


func _on_attack_card_selected(index: int) -> void:
	super._on_attack_card_selected(index)
	if _step == Step.SELECT_BASIC_CARD:
		var card: AttackCardData = attack_hand[index] if index < attack_hand.size() else null
		if card and card.attack_type == "Basic":
			_advance_to(Step.ATTACK_QTE)


func _on_defend_pressed() -> void:
	super._on_defend_pressed()
	if _step == Step.DEFEND:
		_advance_to(Step.PARRY_RESULT)  # placeholder, diganti flow beneran di bawah


func _on_charge_complete(multiplier: float) -> void:
	super._on_charge_complete(multiplier)
	if _step == Step.CHARGE:
		_charge_completed = true


func _on_raptive_btn_pressed() -> void:
	super._on_raptive_btn_pressed()
	if _step == Step.RAPID and _rapid_hits > 0:
		_advance_to(Step.LOOT_APPEARED)


func _on_enemy_attack_preparing() -> void:
	super._on_enemy_attack_preparing()
	if _step == Step.PARRY:
		# Parry window kebuka -> pause total + spotlight parry btn.
		#_tf_step parry window jalan frozen, player punya waktu tak terbatas.
		_pause_game(true)
		_lock_all_except([parry_btn])
		_ui_show("A **shield icon** appeared! Tap it to **PARRY**!", TutorialUI.Zone.BOTTOM_LEFT, parry_btn)


func _on_parry_button_clicked() -> void:
	# Parry successful -> explanation, still paused.
	super._on_parry_button_clicked()
	if _step == Step.PARRY:
		_advance_to(Step.PARRY_RESULT)


func _on_backpack_pressed() -> void:
	super._on_backpack_pressed()
	if _step == Step.OPEN_BACKPACK:
		_ui_hide()
		_unlock_all()
		_pause_game(false)
		# Tutup inventory otomatis + lanjut
		await get_tree().create_timer(0.5).timeout
		close_battle_inventory()
		_begin_step(Step.WAVE2_INTRO)


func _on_item_used_in_battle(item: ItemData) -> void:
	super._on_item_used_in_battle(item)
	if _step == Step.USE_POTION:
		_used_potion_this_step = true


# ============================================================
# STEP MACHINE
# ============================================================

func _begin_step(step: Step) -> void:
	_step = step
	_unlock_all()
	match step:
		Step.INTRO_TARGET:
			_act_step("This is a **Skeleton**. Tap it to select your target.",
				TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.INTRO_ATTACK_BTN:
			_act_step("**ATTACK** opens your attack cards.",
				TutorialUI.Zone.BOTTOM_LEFT, atk_btn)
		Step.SELECT_BASIC_CARD:
			_pause_game(false)  # deck udah kebuka dari step sebelumnya
			_ui_hide()
		Step.ATTACK_QTE:
			_pause_game(false)
			_ui_hide()
		Step.ATTACK_QTE_RESULT:
			_read_step(_last_attack_result_text(), TutorialUI.Zone.TOP_RIGHT)
		Step.PARRY:
			# Dijagli trigger dari _on_enemy_attack_preparing override
			pass
		Step.PARRY_RESULT:
			# Explanation after parry. Player tap to continue -> DEFEND step.
			_read_step("**Parried!** It blocked most damage and gave you stamina.",
				TutorialUI.Zone.BOTTOM_LEFT)
			_pary_result_ready = true
		Step.DEFEND:
			_act_step("**DEFEND** restores stamina — but you skip your attack.",
				TutorialUI.Zone.BOTTOM_LEFT, defend_btn)
		Step.SKILL:
			_act_step("**SKILL** cards cost more stamina, but hit harder.",
				TutorialUI.Zone.BOTTOM_LEFT, skill_btn)
		Step.CHARGE:
			_charge_completed = false
			_pause_game(false)
			_ui_hide()
		Step.RAPID:
			_pause_game(false)
			_ui_hide()
		Step.LOOT_APPEARED:
			_read_step("The Skeleton dropped something!", TutorialUI.Zone.BOTTOM_LEFT, _drop_node)
		Step.LOOT_COLLECT:
			_tutorial_inv_before = _tutorial_inventory_count()
			_act_step("Tap the item to **collect** it.", TutorialUI.Zone.BOTTOM_LEFT, _drop_node)
		Step.LOOT_STORED:
			_read_step("Collected! It's in your **BACKPACK**.", TutorialUI.Zone.BOTTOM_LEFT)
		Step.OPEN_BACKPACK:
			_act_step("Open your **Backpack** to check your items.",
				TutorialUI.Zone.BOTTOM_LEFT, backpack_btn)
		Step.WAVE2_INTRO:
			_read_step("Another **Skeleton**! Watch its attack closely.",
				TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.HURT_HP:
			_act_step("You're **hurt!** HP is low. Open your **BACKPACK**.",
				TutorialUI.Zone.BOTTOM_LEFT, backpack_btn)
			_ui_set_hp_note(true)
		Step.OPEN_BACKPACK_HURT:
			_read_step("Use the **Health Potion** to heal.", TutorialUI.Zone.TOP_CENTER)
		Step.USE_POTION:
			_used_potion_this_step = false
			_tutorial_heal_before = current_hp
			_pause_game(false)
			_ui_hide()
		Step.HEALED:
			_read_step("Healed! Always keep potions ready for a tough fight.",
				TutorialUI.Zone.TOP_CENTER)
		Step.WAVE3_INTRO:
			_read_step("A **GRIMWARD** — tougher, and it can **counter-attack**.",
				TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.WAVE3_OBSERVE:
			_read_step("Watch its HP! Enemies fight harder when low.",
				TutorialUI.Zone.BOTTOM_LEFT, _enemy_ref())
		Step.COMPLETE:
			_pause_game(true)
			_lock_all_except([])
			_ui_show_final("That's everything! You're ready for the real fight.")


# Step BACA: tree di-pause, panel muncul, player tap panel buat lanjut.
func _read_step(text: String, zone: TutorialUI.Zone, spot: Node = null) -> void:
	_pause_game(true)
	_lock_all_except([])
	_tutorial_ui.set_spotlight_target(spot)
	_tutorial_ui.show_text(text, zone, true)


# Step AKSI: tree JANGAN di-pause, player tap target yg di-highlight.
# Kunci semua input lain, tapi target itself dibikin ALWAYS + unclickable
# lock, soalnya kalau tree paused target jadi can't-receive-input.
func _act_step(text: String, zone: TutorialUI.Zone, target: Node) -> void:
	_pause_game(false)
	_lock_all_except([target])
	_allow_interaction(target)
	_tutorial_ui.set_spotlight_target(target)
	# dismissable=false: tap harus jatuh ke target, bukan ke panel.
	_tutorial_ui.show_text(text, zone, true, false)


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
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	n.process_mode = Node.PROCESS_MODE_ALWAYS


func _advance_to(step: Step) -> void:
	if step == Step.IDLE:
		return
	_begin_step(step)


func _enemy_ref() -> Node:
	if not enemies.is_empty():
		return enemies[selected_enemy_index] if selected_enemy_index < enemies.size() else enemies[0]
	return null


# ============================================================
# PAUSE
# ============================================================

func _pause_game(paused: bool) -> void:
	# Pause tree total. Node tutorial (PROCESS_MODE_ALWAYS) tetap jalan.
	get_tree().paused = paused
	_was_paused_by_tutorial = paused


# ============================================================
# INPUT LOCKING
# Input battle punya 3 jalur: _input(), Button.pressed, gui_input.
# Cuma _input() bisa di-swallow, sisanya butuh disabled/mouse_filter.
# ============================================================

func _lock_all_except(allowed: Array) -> void:
	_unlock_all()
	var all_buttons := [atk_btn, defend_btn, backpack_btn, run_btn, skill_btn]
	for b in all_buttons:
		if b and not (b in allowed):
			_disable_node(b)
	# Kunci juga SEMUA kartu + drop + tombol charge/rapid, bukan cuma
	# 5 tombol interaction. Kalau kartu masih bisa diklik, player bisa
	# skip step tutorial tanpa sengaja.
	for n in _interactive_nodes():
		if n and not (n in allowed) and not _is_core_button(n):
			_disable_node(n)


func _is_core_button(n: Node) -> bool:
	return n in [atk_btn, defend_btn, backpack_btn, run_btn, skill_btn]


func _interactive_nodes() -> Array:
	# Tutorial UI sendiri JANGAN dikunci — tombol Continue-nya harus
	# tetap bisa dipencet di step terakhir.
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


func _disable_node(node: Node) -> void:
	if node is Control:
		var c := node as Control
		_saved_mouse_filters[c.get_instance_id()] = c.mouse_filter
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_locked_nodes.append(c)
	if node is Button:
		(node as Button).disabled = true


func _unlock_all() -> void:
	for c in _locked_nodes:
		if is_instance_valid(c):
			if c is Button:
				(c as Button).disabled = false
			if _saved_mouse_filters.has(c.get_instance_id()):
				c.mouse_filter = _saved_mouse_filters[c.get_instance_id()]
	_saved_mouse_filters.clear()
	_locked_nodes.clear()
	# Unlock semua interaction button
	for b in [atk_btn, defend_btn, backpack_btn, run_btn, skill_btn]:
		if b:
			b.disabled = false


# ============================================================
# UI HELPERS
# ============================================================

func _ui_show(text: String, zone: TutorialUI.Zone, target: Node) -> void:
	if _tutorial_ui:
		# URUTAN PENTING: spotlight DULU, baru panel. show_text()
		# mem relocating panel berdasarkan rect spotlight, jadi kalau
		# panel dulu, dia masih pake rect step LALU.
		_tutorial_ui.set_spotlight_target(target)
		_tutorial_ui.show_text(text, zone, true)


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
	return "Weak hit — less damage, but still connected."


# ============================================================
# WAVE FLOW
# ============================================================

func _on_enemy_defeated(_exp_amount: int, _gold_amount: int, _dropped_items: Array[String], enemy: BattleEnemy) -> void:
	super._on_enemy_defeated(_exp_amount, _gold_amount, _dropped_items, enemy)
	# Wave 1 & 2 punya script drop sendiri, handled di _process_enemy_death.
	if _tutorial_active and _step == Step.WAVE2_INTRO:
		pass


func tutorial_next_wave() -> void:
	# Dipanggil dari flow (misal setelah wave 1 clear)
	_unlock_all()
	_unlock_all()  # ensure enemy turn buttons back


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
	# (=100% counter, tiap Inbound). Beginner gak siap ngadep itu,
	# jadi turunin ke Lv1. Damage mult ikut turun 1.3x -> 0.8x.
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var ab := e.get_tactical_attack_ability()
		if ab:
			ab.level = 1


func trigger_scripted_hurt() -> void:
	# Script "big damage" -> HP mendarat di floor 25%.
	_pending_scripted_damage = true
	apply_damage_raw(999.0)
