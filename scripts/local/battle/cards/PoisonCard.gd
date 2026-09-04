extends ActionCardData
class_name PoisonCard


# ============================================================
# POISON PROPERTIES
# ============================================================

@export_group("Poison")

## Damage per turn
@export var poison_damage: float = 10.0

## Durasi poison (dalam turns)
@export var poison_duration: int = 3


# ============================================================
# EXECUTE
# ============================================================

func execute(target: Node, battle_manager: Node) -> void:
	if target == null:
		return

	# Cek apakah target udah kena poison → reset duration
	var existing_poison: Dictionary = {}
	for buff in target.buff_manager.active_buffs:
		if buff.get("type") == "poison":
			existing_poison = buff
			break

	if not existing_poison.is_empty():
		# Reset duration
		existing_poison["duration"] = poison_duration
		existing_poison["is_new"] = true
	else:
		# Apply poison baru
		target.buff_manager.active_buffs.append({
			"name": card_name,
			"type": "poison",
			"duration": poison_duration,
			"attack_bonus": 0.0,
			"defense_bonus": 0.0,
			"damage_reduction": 0.0,
			"poison_damage": poison_damage,
			"effect_icon": preload("res://assets/ui/icons/statusEffect/poison.png"),
			"is_new": true
		})

	# Visual feedback
	target._update_status_effects()
	target.show_reaction_text("Poisoned!", Color(0.3, 0.8, 0.2), true)
