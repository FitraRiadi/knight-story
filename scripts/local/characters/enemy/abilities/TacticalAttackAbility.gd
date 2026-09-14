extends RefCounted
class_name TacticalAttackAbility

# ============================================================
# TACTICAL ATTACK
# Counter-attack saat player menyerang enemy.
# Semakin tinggi level, semakin tinggi chance counter.
#
# Level 1: 25% chance, 0.8x damage
# Level 2: 40% chance, 1.0x damage
# Level 3: 60% chance, 1.3x damage + bonus text
# ============================================================

const CHANCE_BY_LEVEL: Array[float] = [0.25, 0.40, 0.60]
const DAMAGE_MULT_BY_LEVEL: Array[float] = [0.8, 1.0, 1.3]

static func should_counter(ability_level: int) -> bool:
	var idx := clampi(ability_level - 1, 0, 2)
	var chance: float = CHANCE_BY_LEVEL[idx]
	return randf() < chance


static func get_counter_damage_multiplier(ability_level: int) -> float:
	var idx := clampi(ability_level - 1, 0, 2)
	return DAMAGE_MULT_BY_LEVEL[idx]


static func get_counter_text(ability_level: int) -> String:
	match ability_level:
		1: return "Tactical Counter!"
		2: return "Tactical Strike!"
		3: return "TACTICAL RETALIATION!"
	return "Counter!"


static func get_counter_text_color(ability_level: int) -> Color:
	match ability_level:
		1: return Color(0.8, 0.9, 1.0)
		2: return Color(0.5, 0.8, 1.0)
		3: return Color(0.3, 0.6, 1.0)
	return Color.WHITE
