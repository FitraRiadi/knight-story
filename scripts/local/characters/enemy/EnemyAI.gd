extends RefCounted
class_name EnemyAI

# ============================================================
# ENEMY AI BRAIN
#
# AI hanya BERPIKIR.
#
# Tidak mengurus:
# - Animasi
# - Camera
# - Damage
# - Node
# - Signal
# - UI
#
# OUTPUT:
# - Action
# - Emotion
# - Attack multiplier
# - Item yang dipilih
# ============================================================


# ============================================================
# HIGH LEVEL ACTION
# ============================================================

enum Action {
	ATTACK,
	DEFEND,
	USE_ITEM
}


# ============================================================
# EMOTION
# ============================================================

enum Emotion {
	CALM,
	CONFIDENT,
	ANGRY,
	FEARFUL,
	DESPERATE,
	ENRAGED
}


# ============================================================
# NEED
# ============================================================

enum Need {
	GENERAL,
	SURVIVE,
	DEAL_DAMAGE,
	REMOVE_THREAT
}


# ============================================================
# DECISION RESULT
# ============================================================

class Decision:

	var action: Action = Action.ATTACK
	var emotion: Emotion = Emotion.CALM

	# Digunakan ketika ATTACK
	var attack_multiplier: float = 1.0

	# Digunakan ketika USE_ITEM
	var item: ItemData = null

	# AI reasoning
	var need: Need = Need.GENERAL

	# Score
	var action_score: float = 0.0
	var item_score: float = 0.0

	func _init(
		p_action: Action = Action.ATTACK,
		p_emotion: Emotion = Emotion.CALM
	) -> void:

		action = p_action
		emotion = p_emotion


# ============================================================
# AI MEMORY
# ============================================================

var last_action: Action = Action.ATTACK
var action_history: Array[Action] = []

var consecutive_action_count: int = 0


# ============================================================
# DEBUG
# ============================================================

@export var enable_debug_logs: bool = true


# ============================================================
# MAIN THINK
# ============================================================

func decide(
	stats: EnemyData,
	current_hp: float,
	max_hp: float,
	enemy_inventory: Array[ItemData]
) -> Decision:

	var decision := Decision.new()

	# --------------------------------------------------------
	# SAFETY
	# --------------------------------------------------------

	if stats == null:

		_debug(
			"[AI] EnemyData NULL -> ATTACK"
		)

		decision.action = Action.ATTACK
		decision.emotion = Emotion.CALM
		decision.attack_multiplier = 1.0

		return _remember_decision(decision)


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
	# EMOTION
	# --------------------------------------------------------

	var emotion: Emotion = _determine_emotion(
		stats,
		hp_ratio
	)

	decision.emotion = emotion


	# --------------------------------------------------------
	# NEED
	# --------------------------------------------------------

	var need: Need = _determine_need(
		stats,
		hp_ratio,
		enemy_inventory
	)

	decision.need = need


	# --------------------------------------------------------
	# DEBUG
	# --------------------------------------------------------

	var enemy_name: String = (
		stats.enemy_name
		if stats.enemy_name != ""
		else "Enemy"
	)

	_debug(
		"\n\n\n================== %s ====================\n[AI THINKING] | HP: %d/%d (%.1f%%) | Type: %s | Emotion: %s | Need: %s"
		% [
			enemy_name,
			current_hp,
			max_hp,
			hp_ratio * 100.0,
			_get_ai_type_name(stats.ai_type),
			get_emotion_name(emotion),
			get_need_name(need)
		]
	)


	# ========================================================
	# SCORE ACTIONS
	# ========================================================

	var attack_score: float = _score_attack(
		stats,
		hp_ratio,
		emotion
	)

	var defend_score: float = _score_defend(
		stats,
		hp_ratio,
		emotion
	)

	var item_result: Dictionary = _find_best_item(
		stats,
		current_hp,
		max_hp,
		hp_ratio,
		need,
		enemy_inventory
	)

	var use_item_score: float = float(
		item_result.get("score", -1.0)
	)

	var best_item: ItemData = item_result.get(
		"item",
		null
	)


	_debug(
		"[AI SCORES] ATTACK=%.2f | DEFEND=%.2f | USE_ITEM=%.2f"
		% [
			attack_score,
			defend_score,
			use_item_score
		]
	)


	# ========================================================
	# SELECT BEST ACTION
	# ========================================================

	var chosen_action: Action = Action.ATTACK
	var highest_score: float = attack_score


	if defend_score > highest_score:

		chosen_action = Action.DEFEND
		highest_score = defend_score


	if (
		best_item != null
		and use_item_score > highest_score
	):

		chosen_action = Action.USE_ITEM
		highest_score = use_item_score


	# ========================================================
	# FINAL DECISION
	# ========================================================

	decision.action = _validate_action(
		chosen_action
	)

	decision.action_score = highest_score


	# --------------------------------------------------------
	# ATTACK
	# --------------------------------------------------------

	if decision.action == Action.ATTACK:

		decision.attack_multiplier = (
			_get_attack_multiplier(emotion)
		)


	# --------------------------------------------------------
	# USE ITEM
	# --------------------------------------------------------

	elif decision.action == Action.USE_ITEM:

		decision.item = best_item
		decision.item_score = use_item_score

		# Safety fallback
		if decision.item == null:

			decision.action = _fallback_action(
				attack_score,
				defend_score
			)

			if decision.action == Action.ATTACK:

				decision.attack_multiplier = (
					_get_attack_multiplier(emotion)
				)


	_debug(
		"[AI DECISION] %s | Emotion=%s | Multiplier=%.2fx | Item=%s"
		% [
			get_action_name(decision.action),
			get_emotion_name(decision.emotion),
			decision.attack_multiplier,
			(
				_get_item_display_name(decision.item)
				if decision.item != null
				else "-"
			)
		]
	)

	return _remember_decision(decision)


# ============================================================
# LEGACY
# ============================================================

func decide_action(
	stats: EnemyData,
	current_hp: float,
	max_hp: float,
	enemy_inventory: Array[ItemData]
) -> Action:

	var decision := decide(
		stats,
		current_hp,
		max_hp,
		enemy_inventory
	)

	return decision.action


# ============================================================
# DETERMINE EMOTION
# ============================================================

func _determine_emotion(
	stats: EnemyData,
	hp_ratio: float
) -> Emotion:

	if stats.ai_type == EnemyData.AIType.BOSS:

		if hp_ratio <= 0.20:
			return Emotion.ENRAGED

		if hp_ratio <= 0.40:
			return Emotion.DESPERATE

		if hp_ratio <= 0.70:
			return Emotion.ANGRY

		return Emotion.CONFIDENT


	if stats.ai_type == EnemyData.AIType.AGGRESSIVE:

		if hp_ratio <= 0.20:
			return Emotion.DESPERATE

		if hp_ratio <= 0.50:
			return Emotion.ANGRY

		return Emotion.CONFIDENT


	if stats.ai_type == EnemyData.AIType.TACTICAL:

		if hp_ratio <= 0.20:
			return Emotion.FEARFUL

		if hp_ratio <= 0.40:
			return Emotion.DESPERATE

		if hp_ratio >= 0.75:
			return Emotion.CONFIDENT

		return Emotion.CALM


	if hp_ratio <= 0.20:
		return Emotion.FEARFUL

	return Emotion.CALM


# ============================================================
# DETERMINE NEED
# ============================================================

func _determine_need(
	stats: EnemyData,
	hp_ratio: float,
	_enemy_inventory: Array[ItemData]
) -> Need:

	if hp_ratio <= 0.25:
		return Need.SURVIVE


	if hp_ratio <= 0.45:

		if (
			stats.ai_type == EnemyData.AIType.TACTICAL
			or stats.ai_type == EnemyData.AIType.BOSS
		):

			return Need.SURVIVE


	if (
		stats.ai_type == EnemyData.AIType.AGGRESSIVE
		or stats.ai_type == EnemyData.AIType.BOSS
	):

		return Need.DEAL_DAMAGE


	return Need.GENERAL


# ============================================================
# SCORE ATTACK
# ============================================================

func _score_attack(
	stats: EnemyData,
	hp_ratio: float,
	emotion: Emotion
) -> float:

	var score: float = 50.0


	match stats.ai_type:

		EnemyData.AIType.BASIC:
			score += 15.0

		EnemyData.AIType.AGGRESSIVE:
			score += 30.0

		EnemyData.AIType.TACTICAL:
			score += 10.0

		EnemyData.AIType.BOSS:
			score += 25.0


	match emotion:

		Emotion.CALM:
			score += 0.0

		Emotion.CONFIDENT:
			score += 10.0

		Emotion.ANGRY:
			score += 20.0

		Emotion.DESPERATE:
			score += 12.0

		Emotion.ENRAGED:
			score += 35.0

		Emotion.FEARFUL:
			score -= 15.0


	if hp_ratio <= 0.20:
		score -= 10.0


	return maxf(
		score,
		0.0
	)


# ============================================================
# SCORE DEFEND
# ============================================================

func _score_defend(
	stats: EnemyData,
	hp_ratio: float,
	emotion: Emotion
) -> float:

	var score: float = 20.0


	match stats.ai_type:

		EnemyData.AIType.BASIC:
			score += 5.0

		EnemyData.AIType.AGGRESSIVE:
			score -= 5.0

		EnemyData.AIType.TACTICAL:
			score += 20.0

		EnemyData.AIType.BOSS:
			score += 10.0


	if hp_ratio <= 0.60:
		score += 10.0

	if hp_ratio <= 0.35:
		score += 20.0

	if hp_ratio <= 0.20:
		score += 25.0


	if emotion == Emotion.FEARFUL:
		score += 20.0

	if emotion == Emotion.DESPERATE:
		score += 5.0

	if emotion == Emotion.ENRAGED:
		score -= 15.0


	# Anti defend spam
	if (
		last_action == Action.DEFEND
		and consecutive_action_count >= 2
	):

		score -= 40.0


	return maxf(
		score,
		0.0
	)


# ============================================================
# FIND BEST ITEM
# ============================================================

func _find_best_item(
	stats: EnemyData,
	current_hp: float,
	max_hp: float,
	hp_ratio: float,
	need: Need,
	enemy_inventory: Array[ItemData]
) -> Dictionary:

	var best_item: ItemData = null
	var best_score: float = -1.0


	for item: ItemData in enemy_inventory:

		if item == null:
			continue

		if not item.has_any_effect():
			continue


		var score: float = _evaluate_item(
			stats,
			item,
			current_hp,
			max_hp,
			hp_ratio,
			need
		)


		if score <= 0.0:
			continue


		score *= item.ai_priority_multiplier


		_debug(
			"[AI ITEM] %s | Need=%s | Effects=%s | Score=%.2f"
			% [
				_get_item_display_name(item),
				get_need_name(need),
				item.get_effect_summary(),
				score
			]
		)


		if score > best_score:

			best_score = score
			best_item = item


	return {
		"item": best_item,
		"score": best_score
	}


# ============================================================
# EVALUATE ITEM
# ============================================================

func _evaluate_item(
	stats: EnemyData,
	item: ItemData,
	current_hp: float,
	max_hp: float,
	hp_ratio: float,
	need: Need
) -> float:

	if item == null:
		return -1.0


	var score: float = 0.0


	match need:

		Need.SURVIVE:

			score += _get_item_survival_score(
				item,
				current_hp,
				max_hp,
				hp_ratio
			)


		Need.DEAL_DAMAGE:

			score += _get_item_damage_score(
				item
			)


		Need.REMOVE_THREAT:

			score += _get_item_threat_removal_score(
				item
			)


		Need.GENERAL:

			score += _get_item_general_score(
				item
			)


	# --------------------------------------------------------
	# AI TYPE
	# --------------------------------------------------------

	match stats.ai_type:

		EnemyData.AIType.AGGRESSIVE:

			score *= _get_aggressive_item_modifier(
				item
			)


		EnemyData.AIType.TACTICAL:

			score *= 1.10


		EnemyData.AIType.BOSS:

			score *= 1.05


	return score


# ============================================================
# SURVIVAL ITEM SCORE
# ============================================================

func _get_item_survival_score(
	item: ItemData,
	current_hp: float,
	max_hp: float,
	hp_ratio: float
) -> float:

	var score: float = 0.0


	# HEAL

	var heal_value: float = item.get_ai_stat("hp")

	if heal_value > 0.0:

		var missing_hp: float = maxf(
			max_hp - current_hp,
			0.0
		)

		var effective_heal: float = minf(
			heal_value,
			missing_hp
		)

		if effective_heal > 0.0:

			var heal_ratio: float = (
				effective_heal / max_hp
				if max_hp > 0.0
				else 0.0
			)

			score += heal_ratio * 120.0


	# OTHER SURVIVAL EFFECTS

	score += item.get_ai_stat("max_hp") * 0.35
	score += item.get_ai_stat("defense") * 0.45
	score += item.get_ai_stat("shield") * 0.65
	score += item.get_ai_stat("damage_reduction") * 0.75
	score += item.get_ai_stat("hp_regen") * 0.60


	if hp_ratio <= 0.20:

		score *= 1.35

	elif hp_ratio <= 0.35:

		score *= 1.20


	return score


# ============================================================
# DAMAGE ITEM SCORE
# ============================================================

func _get_item_damage_score(
	item: ItemData
) -> float:

	if item == null:
		return 0.0


	var score: float = 0.0

	score += item.get_ai_stat("attack") * 1.0
	score += item.get_ai_stat("damage") * 1.0
	score += item.get_ai_stat("attack_power") * 1.0

	score += item.get_ai_stat("critical_chance") * 0.75
	score += item.get_ai_stat("critical_damage") * 0.55
	score += item.get_ai_stat("attack_speed") * 0.45
	score += item.get_ai_stat("elemental_damage") * 0.75


	return score


# ============================================================
# THREAT REMOVAL
# ============================================================

func _get_item_threat_removal_score(
	item: ItemData
) -> float:

	var score: float = 0.0

	score += item.get_ai_stat("remove_debuff") * 100.0
	score += item.get_ai_stat("remove_poison") * 100.0
	score += item.get_ai_stat("remove_burn") * 100.0
	score += item.get_ai_stat("remove_bleed") * 100.0
	score += item.get_ai_stat("remove_stun") * 100.0


	return score


# ============================================================
# GENERAL ITEM
# ============================================================

func _get_item_general_score(
	item: ItemData
) -> float:

	var score: float = 0.0

	score += item.get_ai_stat("attack") * 0.25
	score += item.get_ai_stat("defense") * 0.25
	score += item.get_ai_stat("hp") * 0.25
	score += item.get_ai_stat("shield") * 0.25
	score += item.get_ai_stat("speed") * 0.20

	return score


# ============================================================
# AGGRESSIVE ITEM MODIFIER
# ============================================================

func _get_aggressive_item_modifier(
	item: ItemData
) -> float:

	var attack_value: float = (
		item.get_ai_stat("attack")
		+ item.get_ai_stat("damage")
		+ item.get_ai_stat("attack_power")
	)

	var defense_value: float = (
		item.get_ai_stat("defense")
		+ item.get_ai_stat("shield")
	)

	if attack_value > defense_value:
		return 1.15

	if defense_value > attack_value:
		return 0.85

	return 1.0


# ============================================================
# ATTACK MULTIPLIER
# ============================================================

func _get_attack_multiplier(
	emotion: Emotion
) -> float:

	match emotion:

		Emotion.CALM:
			return 1.00

		Emotion.CONFIDENT:
			return 1.10

		Emotion.ANGRY:
			return 1.25

		Emotion.DESPERATE:
			return 1.30

		Emotion.FEARFUL:
			return 0.85

		Emotion.ENRAGED:
			return 1.50


	return 1.0


# ============================================================
# ACTION VALIDATION
# ============================================================

func _validate_action(
	action: Action
) -> Action:

	if action == Action.DEFEND:

		if (
			last_action == Action.DEFEND
			and consecutive_action_count >= 2
		):

			_debug(
				"[AI VALIDATION] DEFEND terlalu lama -> ATTACK"
			)

			return Action.ATTACK


	return action


# ============================================================
# FALLBACK
# ============================================================

func _fallback_action(
	attack_score: float,
	defend_score: float
) -> Action:

	if defend_score > attack_score:
		return Action.DEFEND

	return Action.ATTACK


# ============================================================
# MEMORY
# ============================================================

func _remember_decision(
	decision: Decision
) -> Decision:

	var action: Action = decision.action


	if action == last_action:

		consecutive_action_count += 1

	else:

		consecutive_action_count = 1


	last_action = action

	action_history.append(action)


	if action_history.size() > 10:
		action_history.pop_front()


	return decision


# ============================================================
# RESET
# ============================================================

func reset_memory() -> void:

	last_action = Action.ATTACK

	action_history.clear()

	consecutive_action_count = 0


# ============================================================
# NAME HELPERS
# ============================================================

func get_action_name(
	action: Action
) -> String:

	match action:

		Action.ATTACK:
			return "ATTACK"

		Action.DEFEND:
			return "DEFEND"

		Action.USE_ITEM:
			return "USE_ITEM"


	return "UNKNOWN"


func get_emotion_name(
	emotion: Emotion
) -> String:

	match emotion:

		Emotion.CALM:
			return "CALM"

		Emotion.CONFIDENT:
			return "CONFIDENT"

		Emotion.ANGRY:
			return "ANGRY"

		Emotion.FEARFUL:
			return "FEARFUL"

		Emotion.DESPERATE:
			return "DESPERATE"

		Emotion.ENRAGED:
			return "ENRAGED"


	return "UNKNOWN"


func get_need_name(
	need: Need
) -> String:

	match need:

		Need.GENERAL:
			return "GENERAL"

		Need.SURVIVE:
			return "SURVIVE"

		Need.DEAL_DAMAGE:
			return "DEAL_DAMAGE"

		Need.REMOVE_THREAT:
			return "REMOVE_THREAT"


	return "UNKNOWN"


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


func _get_item_display_name(
	item: ItemData
) -> String:

	if item == null:
		return "NULL ITEM"

	if item.item_name != "":
		return item.item_name

	if item.item_id != "":
		return item.item_id

	return "Unknown Item"


# ============================================================
# DEBUG
# ============================================================

func _debug(
	message: String
) -> void:

	if enable_debug_logs:

		print_rich(
			"[color=cyan]" +
			message +
			"[/color]"
		)
