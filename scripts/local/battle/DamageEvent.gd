extends RefCounted
class_name DamageEvent

# ============================================================
# DAMAGE EVENT
# Setiap damage instance punya metadata sendiri.
# Gak ada shared mutable state → gak ada race condition.
# ============================================================

enum Source { NORMAL, BERSERK, BATTLE_CRY, COUNTER, RAPID }

var base_damage: float = 0.0
var final_damage: float = 0.0
var source: Source = Source.NORMAL
var can_be_parried: bool = true
var can_trigger_life_steal: bool = true
var damage_multiplier: float = 1.0
var hit_index: int = 0
var total_hits: int = 1

func get_calculated_damage() -> float:
	return base_damage * damage_multiplier
