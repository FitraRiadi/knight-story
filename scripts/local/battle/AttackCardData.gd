extends ActionCardData
class_name AttackCardData


# ============================================================
# ATTACK CARD PROPERTIES
# ============================================================

@export_group("Attack Type")

## Tipe attack: Basic (QTE), Charge (hold), Rapid (tap)
@export_enum("Basic", "Charge", "Rapid") var attack_type: String = "Basic"

## Jumlah hit (untuk rapid tap nanti)
@export var hit_count: int = 1


# ============================================================
# EXECUTE — gak dipake, attack langsung trigger mechanic
# ============================================================

func execute(target: Node, battle_manager: Node) -> void:
	pass
