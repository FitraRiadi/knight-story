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
	
	# Visual feedback
	target._play_stun_visuals()
	target._update_status_effects()
	target.show_reaction_text("Stunned!", Color(1.0, 0.8, 0.0), true)
