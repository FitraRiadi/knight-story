extends RefCounted
class_name EnemyAI


# ============================================================
# ENEMY AI
#
# Tugas class ini HANYA berpikir.
#
# Tidak mengurus:
# - Animasi
# - Camera
# - Damage
# - Node
# - Signal
# - UI
#
# Input:
# - EnemyData
# - HP enemy
# - Inventory enemy
#
# Output:
# - Action yang harus dilakukan enemy
# ============================================================


enum Action {
	ATTACK,
	HEAVY_ATTACK,
	DEFEND,
	HEAL
}


# ============================================================
# AI MEMORY
# ============================================================

var last_action: Action = Action.ATTACK
var action_history: Array[Action] = []

# Berapa kali action yang sama dilakukan berturut-turut.
var consecutive_action_count: int = 0


# ============================================================
# DEBUG
# ============================================================

@export var enable_debug_logs: bool = true


# ============================================================
# MAIN THINK FUNCTION
# ============================================================

func decide_action(
	stats: EnemyData,
	current_hp: float,
	max_hp: float,
	enemy_inventory: Array[ItemData]
) -> Action:

	if stats == null:
		_debug(
			"[AI] Tidak memiliki EnemyData. Default -> ATTACK"
		)

		return _remember_action(Action.ATTACK)


	# --------------------------------------------------------
	# HP RATIO
	# --------------------------------------------------------

	var hp_ratio: float = 1.0

	if max_hp > 0.0:
		hp_ratio = clampf(
			current_hp / max_hp,
			0.0,
			1.0
		)


	# --------------------------------------------------------
	# INVENTORY
	# --------------------------------------------------------

	var has_potion: bool = _has_potion(
		enemy_inventory
	)


	var enemy_name: String = (
		stats.enemy_name
		if stats.enemy_name != ""
		else "Enemy"
	)


	_debug(
		"[AI THINKING] %s | HP: %d/%d (%.1f%%) | Potion: %s | AI Type: %s"
		% [
			enemy_name,
			current_hp,
			max_hp,
			hp_ratio * 100.0,
			str(has_potion),
			_get_ai_type_name(stats.ai_type)
		]
	)


	# ========================================================
	# BASIC
	# ========================================================

	if stats.ai_type == EnemyData.AIType.BASIC:

		return _think_basic()


	# ========================================================
	# AGGRESSIVE
	# ========================================================

	if stats.ai_type == EnemyData.AIType.AGGRESSIVE:

		return _think_aggressive()


	# ========================================================
	# TACTICAL
	# ========================================================

	if stats.ai_type == EnemyData.AIType.TACTICAL:

		return _think_tactical(
			hp_ratio,
			has_potion
		)


	# ========================================================
	# BOSS
	# ========================================================

	if stats.ai_type == EnemyData.AIType.BOSS:

		return _think_boss(
			hp_ratio,
			has_potion
		)


	# ========================================================
	# FALLBACK
	# ========================================================

	return _remember_action(
		Action.ATTACK
	)


# ============================================================
# BASIC AI
# ============================================================

func _think_basic() -> Action:

	var roll := randf()


	var chosen_action: Action


	# 70% attack
	# 30% defend

	if roll < 0.70:
		chosen_action = Action.ATTACK
	else:
		chosen_action = Action.DEFEND


	return _finalize_decision(
		chosen_action,
		roll
	)


# ============================================================
# AGGRESSIVE AI
# ============================================================

func _think_aggressive() -> Action:

	var roll := randf()


	var chosen_action: Action


	if roll < 0.65:

		chosen_action = Action.ATTACK

	elif roll < 0.85:

		chosen_action = Action.HEAVY_ATTACK

	else:

		chosen_action = Action.DEFEND


	return _finalize_decision(
		chosen_action,
		roll
	)


# ============================================================
# TACTICAL AI
# ============================================================

func _think_tactical(
	hp_ratio: float,
	has_potion: bool
) -> Action:

	var roll := randf()

	var chosen_action: Action


	# ========================================================
	# PHASE 1
	# HP > 80%
	# ========================================================

	if hp_ratio > 0.80:

		_debug(
			"[AI LOGIC] Tactical Phase 1 -> HP > 80%"
		)


		if roll < 0.80:

			chosen_action = Action.ATTACK

		elif roll < 0.90:

			chosen_action = Action.HEAVY_ATTACK

		else:

			chosen_action = Action.DEFEND


	# ========================================================
	# PHASE 2
	# HP 50% - 80%
	# ========================================================

	elif hp_ratio > 0.50:

		_debug(
			"[AI LOGIC] Tactical Phase 2 -> HP 50%-80%"
		)


		if has_potion and roll < 0.15:

			chosen_action = Action.HEAL

		elif roll < 0.70:

			chosen_action = Action.ATTACK

		elif roll < 0.85:

			chosen_action = Action.HEAVY_ATTACK

		else:

			chosen_action = Action.DEFEND


	# ========================================================
	# PHASE 3
	# HP 25% - 50%
	# ========================================================

	elif hp_ratio > 0.25:

		_debug(
			"[AI LOGIC] Tactical Phase 3 -> HP 25%-50%"
		)


		if has_potion and roll < 0.40:

			chosen_action = Action.HEAL

		elif roll < 0.70:

			chosen_action = Action.ATTACK

		elif roll < 0.85:

			chosen_action = Action.DEFEND

		else:

			chosen_action = Action.HEAVY_ATTACK


	# ========================================================
	# PHASE 4
	# HP < 25%
	# ========================================================

	else:

		_debug(
			"[AI LOGIC] Tactical Phase 4 -> CRITICAL HP"
		)


		if has_potion:

			if roll < 0.75:

				chosen_action = Action.HEAL

			else:

				chosen_action = Action.DEFEND

		else:

			_debug(
				"[AI LOGIC] Potion habis -> Desperate Mode"
			)


			if roll < 0.50:

				chosen_action = Action.ATTACK

			elif roll < 0.80:

				chosen_action = Action.HEAVY_ATTACK

			else:

				chosen_action = Action.DEFEND


	return _finalize_decision(
		chosen_action,
		roll
	)


# ============================================================
# BOSS AI
# ============================================================

func _think_boss(
	hp_ratio: float,
	has_potion: bool
) -> Action:

	var roll := randf()

	var chosen_action: Action


	# ========================================================
	# BOSS PHASE 1
	# HP > 50%
	# ========================================================

	if hp_ratio > 0.50:

		_debug(
			"[AI LOGIC] Boss Phase 1 -> HP > 50%"
		)


		if (
			has_potion
			and hp_ratio <= 0.75
			and roll < 0.20
		):

			chosen_action = Action.HEAL

		elif roll < 0.60:

			chosen_action = Action.ATTACK

		elif roll < 0.85:

			chosen_action = Action.HEAVY_ATTACK

		else:

			chosen_action = Action.DEFEND


	# ========================================================
	# BOSS PHASE 2
	# ENRAGE
	# ========================================================

	else:

		_debug(
			"[AI LOGIC] Boss Phase 2 -> ENRAGE"
		)


		if (
			has_potion
			and hp_ratio <= 0.35
			and roll < 0.50
		):

			chosen_action = Action.HEAL

		elif roll < 0.50:

			chosen_action = Action.HEAVY_ATTACK

		elif roll < 0.80:

			chosen_action = Action.ATTACK

		else:

			chosen_action = Action.DEFEND


	return _finalize_decision(
		chosen_action,
		roll
	)


# ============================================================
# DECISION FINALIZER
# ============================================================

func _finalize_decision(
	chosen_action: Action,
	roll: float
) -> Action:

	var final_action := _validate_action(
		chosen_action
	)


	var action_name := get_action_name(
		final_action
	)


	_debug(
		"[AI DECISION] %s | Roll: %.2f | Previous: %s"
		% [
			action_name,
			roll,
			get_action_name(last_action)
		]
	)


	return _remember_action(
		final_action
	)


# ============================================================
# ACTION VALIDATION
#
# Di sini nanti kita bisa membuat AI lebih pintar.
#
# Contoh:
# - Jangan DEFEND 5 kali berturut-turut
# - Jangan HEAL kalau HP penuh
# - Jangan spam HEAVY_ATTACK
#
# Untuk sekarang kita hanya mencegah DEFEND terus-menerus.
# ============================================================

func _validate_action(
	action: Action
) -> Action:

	# Jangan defend terus menerus.
	if action == Action.DEFEND:

		if (
			last_action == Action.DEFEND
			and consecutive_action_count >= 2
		):

			_debug(
				"[AI VALIDATION] DEFEND terlalu lama -> ATTACK"
			)

			return Action.ATTACK


	# Jangan heal terus menerus.
	if action == Action.HEAL:

		if (
			last_action == Action.HEAL
			and consecutive_action_count >= 1
		):

			_debug(
				"[AI VALIDATION] HEAL berturut-turut -> ATTACK"
			)

			return Action.ATTACK


	return action


# ============================================================
# MEMORY
# ============================================================

func _remember_action(
	action: Action
) -> Action:

	if action == last_action:

		consecutive_action_count += 1

	else:

		consecutive_action_count = 1


	last_action = action


	action_history.append(
		action
	)


	# Simpan maksimal 10 action terakhir.
	if action_history.size() > 10:

		action_history.pop_front()


	return action


# ============================================================
# RESET MEMORY
#
# Dipanggil ketika enemy baru spawn / battle baru.
# ============================================================

func reset_memory() -> void:

	last_action = Action.ATTACK

	action_history.clear()

	consecutive_action_count = 0


# ============================================================
# POTION CHECK
# ============================================================

func _has_potion(
	enemy_inventory: Array[ItemData]
) -> bool:

	for item in enemy_inventory:

		if item == null:
			continue


		if "potion" in item.item_id.to_lower():

			return true


	return false


# ============================================================
# ACTION NAME
# ============================================================

func get_action_name(
	action: Action
) -> String:

	match action:

		Action.ATTACK:
			return "ATTACK"

		Action.HEAVY_ATTACK:
			return "HEAVY_ATTACK"

		Action.DEFEND:
			return "DEFEND"

		Action.HEAL:
			return "HEAL"


	return "UNKNOWN"


# ============================================================
# AI TYPE NAME
# ============================================================

func _get_ai_type_name(
	ai_type: EnemyData.AIType
) -> String:

	match ai_type:

		EnemyData.AIType.BASIC:
			return "BASIC"

		EnemyData.AIType.AGGRESSIVE:
			return "AGGRESSIVE"

		EnemyData.AIType.TACTICAL:
			return "TACTICAL"

		EnemyData.AIType.BOSS:
			return "BOSS"


	return "UNKNOWN"


# ============================================================
# DEBUG
# ============================================================

func _debug(message: String) -> void:

	if enable_debug_logs:

		print_rich(
			"[color=cyan]" + message + "[/color]"
		)
