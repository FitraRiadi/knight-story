extends SceneTree
# Full-flow tutorial test (headless). Drives handlers directly
# (real taps can't run headless); asserts steps, texts, spots, game facts.

var bm = null
var tui = null
var fails := 0
var total := 0
var finished_flag := false


func _init() -> void:
	_run()


func ck(cond: bool, nm: String) -> void:
	total += 1
	if cond:
		print("PASS " + nm)
	else:
		fails += 1
		print("FAIL " + nm)


func wstep(n: int, budget_ms: int) -> bool:
	var waited := 0
	while waited < budget_ms:
		if int(bm.get("_step")) == n:
			ck(true, "step=" + str(n))
			return true
		await create_timer(0.1).timeout
		waited += 100
	ck(false, "wait step=" + str(n) + " mau=" + str(n) + " dapat=" + str(int(bm.get("_step"))))
	return false


func ptext() -> String:
	var t: String = str(tui.get("_title").text)
	var i: String = str(tui.get("_info").text)
	var b: String = str(tui.get("_step_badge").text)
	return "[" + b + "] " + t + " | " + i


func spot() -> String:
	var ts = bm.find_child("TutorialSpotlight", true, true)
	if ts == null:
		return "?nospotnode"
	var t = ts.get("_target_node")
	if t == null or not is_instance_valid(t):
		return ""
	return str((t as Node).name)


func foe():
	if bm.enemies.is_empty():
		return null
	var i: int = bm.selected_enemy_index
	if i < 0 or i >= bm.enemies.size():
		i = 0
	return bm.enemies[i]


func enemy_busy() -> bool:
	for e in bm.enemies:
		if is_instance_valid(e) and e.get("is_taking_turn"):
			return true
	return false


func tapc() -> void:
	bm._on_tutorial_tapped()


func qte_crit() -> void:
	var run = bm.attack_bar_running
	var gold = bm.attack_bar_success
	if run.get_parent() == gold.get_parent():
		run.position = gold.position
	else:
		run.global_position = gold.global_position
	bm._check_attack_qte_result()


func qte_miss() -> void:
	var run = bm.attack_bar_running
	run.position = Vector2(-9000, -9000)
	bm._check_attack_qte_result()


func press_down_up(ctrl: Control) -> void:
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	d.position = ctrl.size * 0.5
	ctrl.emit_signal("gui_input", d)
	await create_timer(0.6).timeout
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = ctrl.size * 0.5
	ctrl.emit_signal("gui_input", u)


func _run() -> void:
	await process_frame
	await process_frame
	var ps: PackedScene = load("res://scenes/battle/battle_gameplay_tutorial.tscn")
	var inst = ps.instantiate()
	root.add_child(inst)
	bm = inst
	await create_timer(2.5).timeout
	tui = bm.get("_tutorial_ui")
	bm.tutorial_finished.connect(func() -> void: finished_flag = true)
	ck(tui != null, "tui ada")

	# 1 WELCOME
	wstep(1, 10000)
	ck(ptext().find("STEP 1/") >= 0, "badge STEP 1/68, dapat=" + ptext())
	tapc()
	# 2 TARGET
	wstep(2, 8000)
	ck(spot() != "", "TARGET spot on, spot=" + spot())
	bm._on_enemy_clicked(foe())
	# 3 ATTACK_ACT
	wstep(3, 8000)
	ck(spot() != "", "ATTACK spot on")
	bm._on_attack_pressed()
	# 4 DECK_INTRO (no spot dulu)
	wstep(4, 12000)
	await create_timer(0.8).timeout
	ck(ptext().find("ATTACK DECK") >= 0, "DECK text, dapat=" + ptext())
	ck(spot() == "", "DECK no spot")
	tapc()
	# 5 CARD_INTRO (spot kartu utuh)
	wstep(5, 8000)
	await create_timer(1.5).timeout
	ck(ptext().find("BASIC ATTACK") >= 0, "CARD text, dapat=" + ptext())
	ck(spot() != "" and spot() != "?nospotnode", "CARD spot kartu, spot=" + spot())
	tapc()
	# 6 COST (smooth glide kartu->cost)
	wstep(6, 8000)
	await create_timer(1.0).timeout
	ck(ptext().find("CARD COST") >= 0, "COST text, dapat=" + ptext())
	ck(spot().find("staminaCost") >= 0, "COST spot=cost, spot=" + spot())
	tapc()
	# 7 INFO (smooth glide cost->desc)
	wstep(7, 8000)
	await create_timer(1.0).timeout
	ck(ptext().find("CARD INFO") >= 0, "INFO text, dapat=" + ptext())
	ck(spot() == "Label", "INFO spot=desc, spot=" + spot())
	tapc()
	# 8 PICK
	wstep(8, 8000)
	await create_timer(1.5).timeout
	ck(spot() != "", "PICK spot on, spot=" + spot())
	bm._on_attack_card_selected(0)
	# 9 QTE
	wstep(9, 10000)
	await create_timer(1.0).timeout
	ck(ptext().find("TIMING") >= 0, "QTE text, dapat=" + ptext())
	qte_crit()
	# 10 RESULT
	wstep(10, 12000)
	ck(ptext().find("HIT") >= 0 or ptext().find("PERFECT") >= 0, "RESULT text, dapat=" + ptext())
	tapc()
	# 11 HIT_FOE
	wstep(11, 8000)
	ck(spot() != "", "HIT_FOE spot on")
	tapc()
	# 12 HIT_COST
	wstep(12, 8000)
	ck(ptext().find("STAMINA") >= 0, "HIT_COST text, dapat=" + ptext())
	tapc()
	# 13 TURN_EXPLAIN
	wstep(13, 8000)
	ck(spot() == "", "TURN no spot")
	tapc()
	# 14 PARRY_HINT
	wstep(14, 8000)
	tapc()
	# 16 WAIT
	wstep(16, 8000)
	ck(ptext().find("SKELETON ATTACKING") >= 0, "WAIT text, dapat=" + ptext())
	ck(spot() == "", "WAIT no spot")
	# 17 DRILL (auto) -> tekan SHIELD beneran = sukses
	wstep(17, 10000)
	await create_timer(1.0).timeout
	ck(ptext().find("NOW! TAP THE SHIELD") >= 0, "DRILL text, dapat=" + ptext())
	bm.parry_btn.emit_signal("pressed")
	# 19 RESULT (sukses) -> auto 20 WHY (idle+dwell)
	wstep(19, 10000)
	ck(ptext().find("PARRIED") >= 0, "PRES text, dapat=" + ptext())
	wstep(20, 20000)
	ck(ptext().find("WHY PARRY") >= 0, "WHY text, dapat=" + ptext())
	tapc()
	# 21 DEFEND_NEXT
	wstep(21, 8000)
	tapc()
	# 22 DEFEND_ACT
	wstep(22, 8000)
	bm.defend_btn.emit_signal("pressed")
	# 23 STAMINA_BACK
	wstep(23, 10000)
	ck(ptext().find("STAMINA BACK") >= 0, "STAM text, dapat=" + ptext())
	tapc()
	# 24 SKILL_ACT
	wstep(24, 8000)
	bm.skill_btn.emit_signal("pressed")
	# 25 SKILL_DECK (no spot dulu)
	wstep(25, 10000)
	await create_timer(0.8).timeout
	ck(ptext().find("SKILL DECK") >= 0, "SDECK text, dapat=" + ptext())
	ck(spot() == "", "SDECK no spot")
	tapc()
	# 26 SKILL_CARD (spot kartu utuh)
	wstep(26, 8000)
	await create_timer(1.5).timeout
	ck(ptext().find("SKILL CARD") >= 0, "SCARD text, dapat=" + ptext())
	ck(spot() != "" and spot() != "?nospotnode", "SCARD spot kartu, spot=" + spot())
	tapc()
	# 27 SKILL_COST (smooth)
	wstep(27, 8000)
	await create_timer(1.0).timeout
	ck(ptext().find("SKILL COST") >= 0, "SCOST text, dapat=" + ptext())
	ck(spot().find("Cost") >= 0, "SCOST spot=cost, spot=" + spot())
	tapc()
	# 28 SKILL_INFO (smooth glide cost->desc)
	wstep(28, 8000)
	await create_timer(1.0).timeout
	ck(ptext().find("SKILL INFO") >= 0, "SINFO text, dapat=" + ptext())
	ck(spot().find("Desc") >= 0, "SINFO spot=desc, spot=" + spot())
	tapc()
	# 29 SKILL_PICK
	wstep(29, 8000)
	await create_timer(1.5).timeout
	bm._on_action_card_selected(0)
	# 30 SKILL_EFFECT (poison, turn DITAHAN)
	wstep(30, 10000)
	await create_timer(1.5).timeout
	ck(ptext().find("POISONED") >= 0, "SEFF text, dapat=" + ptext())
	ck(spot() != "" and spot() != "?nospotnode", "SEFF spot effect, spot=" + spot())
	ck(not bm.is_player_turn, "SEFF turn musuh ketahan (bukan giliran player)")
	ck(not enemy_busy(), "SEFF musuh belum gerak")
	await create_timer(2.5).timeout
	ck(int(bm.get("_step")) == 30, "SEFF masih nunggu tap")
	tapc()
	# 31 CHARGE_WAIT (turn musuh jalan dulu, baru idle)
	wstep(31, 25000)
	bm._on_attack_pressed()
	# 32 CHARGE_PICK
	wstep(32, 12000)
	await create_timer(1.5).timeout
	bm._on_attack_card_selected(1)
	# 33 CHARGE_DO
	wstep(33, 10000)
	var cb: Button = bm._charge_button()
	ck(cb != null, "charge btn ada")
	await press_down_up(cb)
	# 34 RAPID_WAIT (auto via idle)
	wstep(34, 25000)
	bm._on_attack_pressed()
	# 35 RAPID_PICK
	wstep(35, 12000)
	await create_timer(1.5).timeout
	bm._on_attack_card_selected(2)
	# 36 RAPID_DO
	wstep(36, 10000)
	for k in range(14):
		if int(bm.get("_step")) != 36:
			break
		bm.rapid_btn.emit_signal("pressed")
		await create_timer(0.15).timeout
	# 37 FINISH_INTRO (auto via idle)
	wstep(37, 25000)
	ck(ptext().find("ARMOR OFF") >= 0, "FININTRO text, dapat=" + ptext())
	tapc()
	# 38 FINISH_ACT
	wstep(38, 8000)
	bm._on_attack_pressed()
	# 39 FINISH_PICK
	wstep(39, 12000)
	await create_timer(1.5).timeout
	bm._on_attack_card_selected(0)
	# 40 FINISH_QTE -> fail dulu (cover FINISH_MISS)
	wstep(40, 10000)
	qte_miss()
	# 41 FINISH_MISS
	wstep(41, 12000)
	tapc()
	# 37 lagi -> 38 -> 39 -> 40 -> crit kill
	wstep(37, 10000)
	tapc()
	wstep(38, 8000)
	bm._on_attack_pressed()
	wstep(39, 12000)
	await create_timer(1.5).timeout
	bm._on_attack_card_selected(0)
	wstep(40, 10000)
	qte_crit()
	# 42 FINISH_AFTER -> 43 LOOT (enemy mati + drop + kamera settle)
	wstep(42, 15000)
	wstep(43, 25000)
	ck(ptext().find("COLLECT") >= 0, "LOOT text, dapat=" + ptext())
	var inv_before: int = bm._tutorial_inventory_count()
	var d = bm.get("_drop_node")
	ck(d != null and is_instance_valid(d), "drop ada")
	bm._on_drop_item_clicked(d.get("item_data"), d)
	# 44 LOOT_DONE
	wstep(44, 15000)
	ck(bm._tutorial_inventory_count() == inv_before + 1, "loot +1")
	tapc()
	# 45 PACK_ACT
	wstep(45, 8000)
	bm.backpack_btn.emit_signal("pressed")
	# 46 PACK_VIEW
	wstep(46, 8000)
	tapc()
	# 47 PACK_CLOSE
	wstep(47, 8000)
	var close_b: Button = bm._inventory_close_button()
	ck(close_b != null, "close btn ada")
	close_b.emit_signal("pressed")
	# 48 WAVE2_INTRO (auto via _goto_wave2)
	wstep(48, 15000)
	tapc()
	# 49 HURT_WAIT (enemy nyerang beneran)
	wstep(49, 8000)
	# 50 HURT_INFO (scripted ke 25%)
	wstep(50, 25000)
	ck(ptext().find("25%") >= 0, "HURT text 25%, dapat=" + ptext())
	ck(spot() == "", "HURT no spot")
	ck(absf(bm.current_hp - bm.max_hp * 0.25) < 1.0, "HP==25%")
	tapc()
	# 51 PACK2_ACT
	wstep(51, 8000)
	bm.backpack_btn.emit_signal("pressed")
	# 52 POTION_SLOT
	wstep(52, 10000)
	await create_timer(1.0).timeout
	var slot_b: Button = bm._inventory_slot_button(bm.get("_potion_index"))
	ck(slot_b != null, "potion slot ada")
	slot_b.emit_signal("pressed")
	# 53 POTION_INFO
	wstep(53, 10000)
	tapc()
	# 54 POTION_USE
	wstep(54, 8000)
	var hp_before: float = bm.current_hp
	var use_b: Button = bm._inventory_use_button()
	ck(use_b != null, "use btn ada")
	use_b.emit_signal("pressed")
	# 55 HEALED
	wstep(55, 15000)
	ck(bm.current_hp > hp_before, "HP naik habis potion")
	tapc()
	# 56 WAVE2_FIGHT (auto idle)
	wstep(56, 20000)
	bm._on_attack_pressed()
	# 57 WAVE2_PICK
	wstep(57, 12000)
	await create_timer(1.5).timeout
	bm._on_attack_card_selected(0)
	# 58 WAVE2_QTE
	wstep(58, 10000)
	qte_crit()
	# 59 WAVE2_AFTER -> 60 WAVE3_INTRO (cleared beat 2.5s)
	wstep(59, 15000)
	wstep(60, 30000)
	ck(ptext().find("GRIMWARD") >= 0, "W3INTRO text, dapat=" + ptext())
	tapc()
	# 61 WAVE3_FIGHT
	wstep(61, 8000)
	bm._on_attack_pressed()
	# 62 WAVE3_PICK
	wstep(62, 12000)
	await create_timer(1.5).timeout
	bm._on_attack_card_selected(0)
	# 63 WAVE3_QTE
	wstep(63, 10000)
	qte_crit()
	# 64 WAVE3_AFTER -> 65 WAVE3_DONE (counter + turn balik)
	wstep(64, 15000)
	wstep(65, 30000)
	tapc()
	# 66 COMPLETE
	wstep(66, 15000)
	await create_timer(1.0).timeout
	ck(ptext().find("TRAINING COMPLETE") >= 0, "COMPLETE text, dapat=" + ptext())
	ck(ptext().find("Grimward") >= 0, "COMPLETE suruh finish grimward")
	tui.get("_continue_btn").emit_signal("pressed")
	# 67 FINALE_FIGHT (bebas total, RUN gak nongol)
	wstep(67, 10000)
	await create_timer(3.0).timeout
	var rev: Array = bm.get("_tut_revealed")
	ck(not (bm.run_btn in rev), "RUN gak direveal finale")
	ck(bm.run_btn.disabled, "RUN disabled")
	ck(ptext() == "" or tui.get("_panel").visible == false, "panel auto-hide duel lega")
	# Serangan beneran sekali (deck parent kebuka?)
	bm._on_attack_pressed()
	await create_timer(1.0).timeout
	ck(bool(bm.is_card_ui_open), "deck finale kebuka")
	bm._on_attack_card_selected(0)
	await create_timer(1.5).timeout
	# Paksa kill grimward (termasuk cover death hook)
	var g = foe()
	ck(g != null, "grimward ada")
	g.receive_damage(99999.0, true, false)
	# 68 OUTRO (scoreboard parent JANGAN nongol)
	wstep(68, 20000)
	await create_timer(1.0).timeout
	ck(bm.scoreBoard.visible == false, "scoreboard disuppress")
	# Tunggu pindah ke lotus_village (outro ~4s + curtain)
	var dest := ""
	var sw := 0.0
	while sw < 25.0:
		var cs = root.current_scene
		if cs and str(cs.scene_file_path).find("lotus_village") >= 0:
			dest = str(cs.scene_file_path)
			break
		await create_timer(0.5).timeout
		sw += 0.5
	ck(dest.find("lotus_village") >= 0, "pindah lotus, dapat=" + dest)

	print("=== DONE total=" + str(total) + " fails=" + str(fails) + " ===")
	quit(fails)
