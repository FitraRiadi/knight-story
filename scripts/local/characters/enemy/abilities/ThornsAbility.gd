extends RefCounted
class_name ThornsAbility

# ============================================================
# THORNS
# Pasif: tiap kena hit yang survived, pantulkan % final damage ke player.
# Bypass defend/parry (duri, bukan serangan). Mati = gak mantul.
#
# Level 1: 30% chance, reflect 20%
# Level 2: 50% chance, reflect 30%
# Level 3: 100% chance, reflect 40%
# ============================================================

const CHANCE_BY_LEVEL: Array[float] = [0.30, 0.50, 1.0]
const REFLECT_PERCENT_BY_LEVEL: Array[float] = [0.20, 0.30, 0.40]

static func should_thorns(ability_level: int) -> bool:
	var idx := clampi(ability_level - 1, 0, 2)
	var chance: float = CHANCE_BY_LEVEL[idx]
	return randf() < chance


static func get_reflect_percent(ability_level: int) -> float:
	var idx := clampi(ability_level - 1, 0, 2)
	return REFLECT_PERCENT_BY_LEVEL[idx]
