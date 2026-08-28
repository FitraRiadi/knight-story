extends Resource
class_name AbilityData

enum AbilityType {
	TACTICAL_ATTACK,
	BATTLE_CRY,
	LIFE_STEAL
}

@export var ability_id: String = ""
@export var ability_name: String = ""
@export var ability_type: AbilityType = AbilityType.TACTICAL_ATTACK
@export var level: int = 1  # 1-3

func get_level() -> int:
	return clampi(level, 1, 3)

func is_tactical_attack() -> bool:
	return ability_type == AbilityType.TACTICAL_ATTACK

func is_battle_cry() -> bool:
	return ability_type == AbilityType.BATTLE_CRY


func is_life_steal() -> bool:
	return ability_type == AbilityType.LIFE_STEAL
