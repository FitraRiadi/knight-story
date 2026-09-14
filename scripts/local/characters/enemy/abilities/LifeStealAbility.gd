extends RefCounted
class_name LifeStealAbility

# ============================================================
# LIFE STEAL
# Saat enemy menyerang, ada chance untuk heal dari damage dealt.
# Semakin tinggi level, semakin tinggi chance + heal %.
#
# Level 1: 20% chance, 25% heal dari damage
# Level 2: 35% chance, 40% heal dari damage
# Level 3: 50% chance, 60% heal dari damage
# ============================================================

const CHANCE_BY_LEVEL: Array[float] = [0.20, 0.35, 0.50]
const HEAL_PERCENT_BY_LEVEL: Array[float] = [0.25, 0.40, 0.60]


static func should_life_steal(ability_level: int) -> bool:
	var idx := clampi(ability_level - 1, 0, 2)
	var chance: float = CHANCE_BY_LEVEL[idx]
	return randf() < chance


static func get_heal_percent(ability_level: int) -> float:
	var idx := clampi(ability_level - 1, 0, 2)
	return HEAL_PERCENT_BY_LEVEL[idx]


static func get_life_steal_text(ability_level: int) -> String:
	match ability_level:
		1: return "Life Steal"
		2: return "Life Steal!"
		3: return "VAMPIRIC DRAIN!"
	return "Life Steal"


static func get_life_steal_text_color(ability_level: int) -> Color:
	match ability_level:
		1: return Color(0.3, 1.0, 0.4)
		2: return Color(0.2, 1.0, 0.3)
		3: return Color(0.0, 1.0, 0.2)
	return Color.WHITE
