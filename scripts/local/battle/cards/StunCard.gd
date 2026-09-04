extends ActionCardData
class_name StunCard


# ============================================================
# PROPERTIES
# ============================================================

## Durasi stun (dalam turn)
@export var stun_duration: int = 1


# ============================================================
# EXECUTE
# ============================================================

func execute(target, battle_manager: Node) -> void:
	if not is_instance_valid(target):
		return
	
	# Apply stun ke enemy
	target.is_stunned = true
	target.stun_turns_remaining = stun_duration

	# Add buff ke buff_manager supaya cleanup system jalan
	target.buff_manager.active_buffs.append({
		"name": card_name,
		"type": "stun",
		"duration": stun_duration,
		"attack_bonus": 0.0,
		"defense_bonus": 0.0,
		"damage_reduction": 0.0,
		"is_new": true
	})
	
	# Visual feedback
	target._play_stun_visuals()
	target._update_status_effects()
	target.show_reaction_text("Stunned!", Color(1.0, 0.8, 0.0), true)
