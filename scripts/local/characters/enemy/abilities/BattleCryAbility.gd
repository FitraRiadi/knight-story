extends RefCounted
class_name BattleCryAbility

# ============================================================
# BATTLE CRY
# Saat enemy menyerang, ada chance untuk menyerang lagi.
# Semakin tinggi level, semakin tinggi chance + parry muncul 2x.
#
# Level 1: 25% chance double attack, parry 1x
# Level 2: 45% chance double attack, parry 2x
# Level 3: 65% chance double attack, parry 2x, 1.2x bonus damage
# ============================================================

const CHANCE_BY_LEVEL: Array[float] = [0.25, 0.45, 0.65]
const BONUS_DAMAGE_MULT_BY_LEVEL: Array[float] = [1.0, 1.0, 1.2]
const PARRY_COUNT_BY_LEVEL: Array[int] = [1, 2, 2]

static func should_double_attack(ability_level: int) -> bool:
	var idx := clampi(ability_level - 1, 0, 2)
	var chance: float = CHANCE_BY_LEVEL[idx]
	return randf() < chance


static func get_bonus_damage_multiplier(ability_level: int) -> float:
	var idx := clampi(ability_level - 1, 0, 2)
	return BONUS_DAMAGE_MULT_BY_LEVEL[idx]


static func get_parry_count(ability_level: int) -> int:
	var idx := clampi(ability_level - 1, 0, 2)
	return PARRY_COUNT_BY_LEVEL[idx]


static func get_battle_cry_text(ability_level: int) -> String:
	match ability_level:
		1: return "Battle Cry!"
		2: return "BATTLE CRY!"
		3: return "WARRIOR'S FURY!"
	return "Battle Cry!"


static func get_battle_cry_text_color(ability_level: int) -> Color:
	match ability_level:
		1: return Color(1.0, 0.7, 0.3)
		2: return Color(1.0, 0.5, 0.2)
		3: return Color(1.0, 0.3, 0.1)
	return Color.WHITE
