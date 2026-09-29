extends RefCounted
class_name EnrageAbility

# ============================================================
# ENRAGE
# Pasif kondisional: sekali HP <= threshold, damage semua serangan
# naik permanen sampai mati. Satu arah, gak bisa turun lagi.
#
# Threshold: 30% (flat semua level)
# Level 1: +25% damage
# Level 2: +40% damage
# Level 3: +60% damage
# ============================================================

const HP_THRESHOLD := 0.30
const DAMAGE_BONUS_BY_LEVEL: Array[float] = [0.25, 0.40, 0.60]

static func get_damage_bonus(ability_level: int) -> float:
	var idx := clampi(ability_level - 1, 0, 2)
	return DAMAGE_BONUS_BY_LEVEL[idx]
