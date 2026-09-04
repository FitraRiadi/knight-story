extends ActionCardData
class_name BleedCard


# ============================================================
# PROPERTIES
# ============================================================

## Durasi bleed (dalam turn)
@export var bleed_duration: int = 3

## Damage amplification (enemy takes +20% damage)
@export var damage_amplification: float = 0.20

## Attack reduction (enemy attack -30%)
@export var attack_reduction: float = 0.30

## Morale drain per turn (enemy loses -10% morale/turn)
@export var morale_drain: float = 0.10


# ============================================================
# EXECUTE
# ============================================================

func execute(target, battle_manager: Node) -> void:
	if not is_instance_valid(target):
		return

	# Cek apakah udah kena bleed → reset duration
	var existing_bleed: Dictionary = {}
	for buff in target.buff_manager.active_buffs:
		if buff.get("type") == "bleed":
			existing_bleed = buff
			break

	if not existing_bleed.is_empty():
		# Reset duration
		existing_bleed["duration"] = bleed_duration
		existing_bleed["is_new"] = true
	else:
		# Apply bleed baru
		target.buff_manager.active_buffs.append({
			"name": card_name,
			"type": "bleed",
			"duration": bleed_duration,
			"attack_bonus": 0.0,
			"defense_bonus": 0.0,
			"damage_reduction": 0.0,
			"damage_amplification": damage_amplification,
			"attack_reduction": attack_reduction,
			"morale_drain": morale_drain,
			"effect_icon": preload("res://assets/ui/icons/statusEffect/attackUp.png"),
			"is_new": true
		})

	# Visual feedback
	target._play_enemy_buff_visual("bleed")
	target._update_status_effects()
	target.show_reaction_text("Bleeding!", Color(0.8, 0.0, 0.2), true)
