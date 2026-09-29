extends Resource
class_name AbilityData

enum AbilityType {
	TACTICAL_ATTACK,
	BATTLE_CRY,
	LIFE_STEAL,
	BERSERK,
	THORNS,
	ENRAGE
}

enum ActivationType {
	PASSIVE,
	ACTIVE
}

@export var ability_id: String = ""
@export var ability_name: String = ""
@export var ability_type: AbilityType = AbilityType.TACTICAL_ATTACK

## Klasifikasi: Active (makan aksi/giliran: counter, double, flurry)
## vs Passive (selalu nyala: life steal, thorns, enrage).
@export var activation: ActivationType = ActivationType.PASSIVE

## Icon ability (drag & drop Texture2D, boleh kosong).
@export var icon: Texture2D

## Deskripsi jelas buat UI/inspector.
@export_multiline var information: String = ""
@export var max_level: int = 3
@export var level: int = 1

func get_level() -> int:
	return clampi(level, 1, max_level)

func is_tactical_attack() -> bool:
	return ability_type == AbilityType.TACTICAL_ATTACK

func is_battle_cry() -> bool:
	return ability_type == AbilityType.BATTLE_CRY


func is_life_steal() -> bool:
	return ability_type == AbilityType.LIFE_STEAL


func is_berserk() -> bool:
	return ability_type == AbilityType.BERSERK


func is_thorns() -> bool:
	return ability_type == AbilityType.THORNS


func is_enrage() -> bool:
	return ability_type == AbilityType.ENRAGE
