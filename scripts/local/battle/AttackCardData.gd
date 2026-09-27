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

## Bobot spawn 0-100 buat random deck (ProbabilityGenerator).
## Bebas, gak harus total 100. Gede = sering muncul.
## Contoh valid: basic 100, charge 90, rapid 100.
@export_range(0.0, 100.0) var spawn_probability: float = 100.0


# ============================================================
# EXECUTE — gak dipake, attack langsung trigger mechanic
# ============================================================

func execute(target: Node, battle_manager: Node) -> void:
	pass
