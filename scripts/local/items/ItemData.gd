extends Resource
class_name ItemData


# ============================================================
# ENUMS
# ============================================================

enum ItemType {
	CONSUMABLE,
	LOOT,
	DROP,
	EQUIPMENT
}

enum ItemEffectType {
	NONE, # Opsi default jika tidak ada efek spesifik
	HEAL,
	MAX_HP,
	HP_REGEN,

	ATTACK,
	DAMAGE,
	ATTACK_SPEED,
	CRITICAL_CHANCE,
	CRITICAL_DAMAGE,
	ELEMENTAL_DAMAGE,

	DEFENSE,
	SHIELD,
	DAMAGE_REDUCTION,

	REMOVE_DEBUFF,
	REMOVE_POISON,
	REMOVE_BURN,
	REMOVE_BLEED,
	REMOVE_STUN
}


# ============================================================
# ITEM INFO
# ============================================================

@export_group("Item Info")

@export var item_id: String = ""
@export var item_name: String = ""

@export_multiline var description: String = ""

@export var icon: Texture2D

@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity: String = "Common"
@export var item_type: ItemType = ItemType.CONSUMABLE
@export var item_effect_type: ItemEffectType = ItemEffectType.NONE


# ============================================================
# CONSUMABLE / USAGE
# ============================================================

@export_group("Item Settings")

@export var use_count: int = 1
@export var sell_value: int = 0


# ============================================================
# ITEM EFFECTS
# ============================================================

@export_group("Item Effects")


# ============================================================
# HEALTH
# ============================================================

@export_subgroup("Health")

@export var heal_value: float = 0.0
@export var max_hp_bonus: float = 0.0
@export var hp_regen: float = 0.0


# ============================================================
# OFFENSE
# ============================================================

@export_subgroup("Offense")

@export var attack_bonus: float = 0.0
@export var damage_bonus: float = 0.0

@export var attack_speed_bonus: float = 0.0

@export var critical_chance_bonus: float = 0.0
@export var critical_damage_bonus: float = 0.0

@export var elemental_damage_bonus: float = 0.0


# ============================================================
# DEFENSE
# ============================================================

@export_subgroup("Defense")

@export var defense_bonus: float = 0.0
@export var shield_value: float = 0.0

@export_range(
	0.0,
	90.0,
	0.5
)
var damage_reduction: float = 0.0


# ============================================================
# STATUS EFFECT
# ============================================================

@export_group("Status Effects")

@export var remove_debuff: bool = false
@export var remove_poison: bool = false
@export var remove_burn: bool = false
@export var remove_bleed: bool = false
@export var remove_stun: bool = false


# ============================================================
# DURATION
# ============================================================

@export_group("Effect Duration")

@export var duration: int = 0


# ============================================================
# AI
# ============================================================

@export_group("AI")

@export_range(
	0.1,
	3.0,
	0.05
)
var ai_priority_multiplier: float = 1.0


# ============================================================
# HELPER FUNCTIONS
# ============================================================

func is_consumable() -> bool:
	return item_type == ItemType.CONSUMABLE


func get_type_string() -> String:
	match item_type:
		ItemType.CONSUMABLE:
			return "Consumable"
		ItemType.LOOT:
			return "Loot"
		ItemType.DROP:
			return "Drop"
		ItemType.EQUIPMENT:
			return "Equipment"
	return "Item"


func get_effect_type_string() -> String:
	match item_effect_type:
		ItemEffectType.HEAL: return "Heal"
		ItemEffectType.MAX_HP: return "Max HP"
		ItemEffectType.HP_REGEN: return "HP Regen"
		ItemEffectType.ATTACK: return "Attack"
		ItemEffectType.DAMAGE: return "Damage"
		ItemEffectType.ATTACK_SPEED: return "Atk Speed"
		ItemEffectType.CRITICAL_CHANCE: return "Crit Chance"
		ItemEffectType.CRITICAL_DAMAGE: return "Crit Damage"
		ItemEffectType.ELEMENTAL_DAMAGE: return "Elemental"
		ItemEffectType.DEFENSE: return "Defense"
		ItemEffectType.SHIELD: return "Shield"
		ItemEffectType.DAMAGE_REDUCTION: return "Dmg Reduction"
		ItemEffectType.REMOVE_DEBUFF: return "Cleanse"
		ItemEffectType.REMOVE_POISON: return "Antidote"
		ItemEffectType.REMOVE_BURN: return "Cure Burn"
		ItemEffectType.REMOVE_BLEED: return "Cure Bleed"
		ItemEffectType.REMOVE_STUN: return "Cure Stun"
	return ""


# ============================================================
# GET EFFECT VALUE
# ============================================================

func get_effect_value(
	effect_name: String
) -> float:

	match effect_name.to_lower():

		"hp", "heal":
			return heal_value

		"max_hp":
			return max_hp_bonus

		"hp_regen":
			return hp_regen

		"attack":
			return attack_bonus

		"damage":
			return damage_bonus

		"attack_power":
			return (
				attack_bonus +
				damage_bonus
			)

		"attack_speed":
			return attack_speed_bonus

		"critical_chance":
			return critical_chance_bonus

		"critical_damage":
			return critical_damage_bonus

		"elemental_damage":
			return elemental_damage_bonus

		"defense":
			return defense_bonus

		"shield":
			return shield_value

		"damage_reduction":
			return damage_reduction

	return 0.0


# ============================================================
# HAS EFFECT
# ============================================================

func has_effect(
	effect_name: String
) -> bool:

	match effect_name.to_lower():

		"hp", "heal":
			return heal_value > 0.0

		"max_hp":
			return max_hp_bonus != 0.0

		"hp_regen":
			return hp_regen != 0.0

		"attack":
			return attack_bonus != 0.0

		"damage":
			return damage_bonus != 0.0

		"attack_power":
			return (
				attack_bonus != 0.0
				or damage_bonus != 0.0
			)

		"attack_speed":
			return attack_speed_bonus != 0.0

		"critical_chance":
			return critical_chance_bonus != 0.0

		"critical_damage":
			return critical_damage_bonus != 0.0

		"elemental_damage":
			return elemental_damage_bonus != 0.0

		"defense":
			return defense_bonus != 0.0

		"shield":
			return shield_value > 0.0

		"damage_reduction":
			return damage_reduction > 0.0

		"remove_debuff":
			return remove_debuff

		"remove_poison":
			return remove_poison

		"remove_burn":
			return remove_burn

		"remove_bleed":
			return remove_bleed

		"remove_stun":
			return remove_stun

	return false


# ============================================================
# STATUS EFFECT CHECK
# ============================================================

func has_status_effect() -> bool:

	return (
		remove_debuff
		or remove_poison
		or remove_burn
		or remove_bleed
		or remove_stun
	)


# ============================================================
# ANY EFFECT
# ============================================================

func has_any_effect() -> bool:

	return (
		heal_value > 0.0
		or max_hp_bonus != 0.0
		or hp_regen != 0.0

		or attack_bonus != 0.0
		or damage_bonus != 0.0
		or attack_speed_bonus != 0.0
		or critical_chance_bonus != 0.0
		or critical_damage_bonus != 0.0
		or elemental_damage_bonus != 0.0

		or defense_bonus != 0.0
		or shield_value > 0.0
		or damage_reduction > 0.0

		or has_status_effect()
	)


# ============================================================
# AI STAT MODIFIERS
# ============================================================

func get_ai_stat_modifiers() -> Dictionary:

	return {
		"hp": heal_value,
		"max_hp": max_hp_bonus,
		"hp_regen": hp_regen,
		"defense": defense_bonus,
		"shield": shield_value,
		"damage_reduction": damage_reduction,
		"attack": attack_bonus,
		"damage": damage_bonus,
		"attack_power": (attack_bonus + damage_bonus),
		"attack_speed": attack_speed_bonus,
		"critical_chance": critical_chance_bonus,
		"critical_damage": critical_damage_bonus,
		"elemental_damage": elemental_damage_bonus,
		"remove_debuff": 1.0 if remove_debuff else 0.0,
		"remove_poison": 1.0 if remove_poison else 0.0,
		"remove_burn": 1.0 if remove_burn else 0.0,
		"remove_bleed": 1.0 if remove_bleed else 0.0,
		"remove_stun": 1.0 if remove_stun else 0.0
	}


# ============================================================
# GET AI STAT
# ============================================================

func get_ai_stat(
	stat_name: String
) -> float:

	var modifiers: Dictionary = get_ai_stat_modifiers()

	return float(
		modifiers.get(
			stat_name.to_lower(),
			0.0
		)
	)


# ============================================================
# EFFECT SUMMARY
# ============================================================

func get_effect_summary() -> String:

	var effects: Array[String] = []

	if heal_value > 0.0:
		effects.append("HP +%d" % int(heal_value))

	if max_hp_bonus != 0.0:
		effects.append("MAX HP %+d" % int(max_hp_bonus))

	if hp_regen != 0.0:
		effects.append("HP Regen %+d" % int(hp_regen))

	if attack_bonus != 0.0:
		effects.append("Attack %+d" % int(attack_bonus))

	if damage_bonus != 0.0:
		effects.append("Damage %+d" % int(damage_bonus))

	if attack_speed_bonus != 0.0:
		effects.append("Attack Speed +%.1f%%" % attack_speed_bonus)

	if critical_chance_bonus != 0.0:
		effects.append("Crit Chance +%.1f%%" % critical_chance_bonus)

	if critical_damage_bonus != 0.0:
		effects.append("Crit Damage +%.1f%%" % critical_damage_bonus)

	if elemental_damage_bonus != 0.0:
		effects.append("Elemental Damage +%.1f%%" % elemental_damage_bonus)

	if defense_bonus != 0.0:
		effects.append("Defense %+d" % int(defense_bonus))

	if shield_value > 0.0:
		effects.append("Shield +%d" % int(shield_value))

	if damage_reduction > 0.0:
		effects.append("Damage Reduction +%.1f%%" % damage_reduction)

	if remove_debuff:
		effects.append("Remove Debuff")

	if remove_poison:
		effects.append("Remove Poison")

	if remove_burn:
		effects.append("Remove Burn")

	if remove_bleed:
		effects.append("Remove Bleed")

	if remove_stun:
		effects.append("Remove Stun")

	if effects.is_empty():
		return "No Effect"

	return ", ".join(effects)
