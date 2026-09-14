extends RefCounted
class_name BerserkAbility

# ============================================================
# BERSERK
# Serangan bertubi-tubi yang tidak bisa diparry.
# Semakin tinggi level, semakin banyak hit + damage per hit.
#
# Level 1: 30% chance, 2 hit, 0.35x per hit = 0.70x total
# Level 2: 50% chance, 3 hit, 0.35x per hit = 1.05x total
# Level 3: 100% chance, 4 hit, 0.40x per hit = 1.60x total
# ============================================================

const CHANCE_BY_LEVEL: Array[float] = [0.30, 0.50, 1.0]
const HIT_COUNT_BY_LEVEL: Array[int] = [2, 3, 4]
const DAMAGE_PER_HIT_BY_LEVEL: Array[float] = [0.35, 0.35, 0.40]

static func should_trigger(ability_level: int) -> bool:
	var idx := clampi(ability_level - 1, 0, 2)
	var chance: float = CHANCE_BY_LEVEL[idx]
	return randf() < chance


static func get_hit_count(ability_level: int) -> int:
	var idx := clampi(ability_level - 1, 0, 2)
	return HIT_COUNT_BY_LEVEL[idx]


static func get_damage_per_hit(ability_level: int) -> float:
	var idx := clampi(ability_level - 1, 0, 2)
	return DAMAGE_PER_HIT_BY_LEVEL[idx]


static func get_berserk_text(ability_level: int) -> String:
	match ability_level:
		1: return "Berserk!"
		2: return "BERSERK!"
		3: return "BERSERK!!!"
	return "Berserk!"


static func get_berserk_text_color(ability_level: int) -> Color:
	match ability_level:
		1: return Color(1.0, 0.9, 0.8)
		2: return Color(1.0, 0.6, 0.2)
		3: return Color(1.0, 0.15, 0.05)
	return Color.WHITE
