class_name EnchantDatabase
extends RefCounted

# Enum untuk tipe enchant
enum EnchantType { BUFF, DEBUFF, UTILITY }

const ENCHANT_DATABASE: Array[Dictionary] = [
	{
		"id": "sharpness-1",
		"name": "Sharpness I",
		"type": EnchantType.BUFF,
		"description": "Increases base physical attack power slightly.",
		"icon": "res://assets/art/items/enchants/sharpness.png",
		"bonus_stats": {
			"damage": 5,
			"critical": 0,
			"hit_rate": 0
		}
	},
	{
		"id": "sharpness-3",
		"name": "Sharpness III",
		"type": EnchantType.BUFF,
		"description": "Significantly increases base physical attack power.",
		"icon": "res://assets/art/items/enchants/sharpness.png",
		"bonus_stats": {
			"damage": 15,
			"critical": 0,
			"hit_rate": 0
		}
	},
	{
		"id": "knockback-2",
		"name": "Knockback II",
		"type": EnchantType.UTILITY,
		"description": "Pushes hit enemies backward moderate distance.",
		"icon": "res://assets/art/items/enchants/knockback.png",
		"bonus_stats": {
			"damage": 2,
			"critical": 0,
			"hit_rate": 0
		}
	},
	{
		"id": "knockback-3",
		"name": "Knockback III",
		"type": EnchantType.UTILITY,
		"description": "Pushes hit enemies backward great distance with heavy impact.",
		"icon": "res://assets/art/items/enchants/knockback.png",
		"bonus_stats": {
			"damage": 5,
			"critical": 0,
			"hit_rate": -5
		}
	},
	{
		"id": "poison-1",
		"name": "Poison I",
		"type": EnchantType.DEBUFF,
		"description": "Inflicts damage over time on hit targets.",
		"icon": "res://assets/art/items/enchants/poison.png",
		"bonus_stats": {
			"damage": 3,
			"critical": 2,
			"hit_rate": 0
		}
	},
	{
		"id": "lifesteal-1",
		"name": "Lifesteal I",
		"type": EnchantType.BUFF,
		"description": "Restores a small amount of health upon striking enemies.",
		"icon": "res://assets/art/items/enchants/lifesteal.png",
		"bonus_stats": {
			"damage": 0,
			"critical": 5,
			"hit_rate": 0
		}
	},
	{
		"id": "lifesteal-2",
		"name": "Lifesteal II",
		"type": EnchantType.BUFF,
		"description": "Restores a moderate amount of health upon striking enemies.",
		"icon": "res://assets/art/items/enchants/lifesteal.png",
		"bonus_stats": {
			"damage": 4,
			"critical": 8,
			"hit_rate": 0
		}
	},
	{
		"id": "fire-1",
		"name": "Fire I",
		"type": EnchantType.DEBUFF,
		"description": "Ignites enemies, dealing additional elemental fire damage.",
		"icon": "res://assets/art/items/enchants/fire.png",
		"bonus_stats": {
			"damage": 8,
			"critical": 3,
			"hit_rate": 0
		}
	},
	{
		"id": "holy-3",
		"name": "Holy III",
		"type": EnchantType.BUFF,
		"description": "Imbues attacks with divine energy, devastating undead and dark monsters.",
		"icon": "res://assets/art/items/enchants/holy.png",
		"bonus_stats": {
			"damage": 20,
			"critical": 10,
			"hit_rate": 5
		}
	}
]

# ==========================================
# GETTER FUNCTIONS
# ==========================================

# Get a single enchant data by ID
static func get_enchant_by_id(id: String) -> Dictionary:
	for enchant in ENCHANT_DATABASE:
		if enchant.get("id") == id:
			return enchant.duplicate(true)
	return {}

# Get full database array
static func get_all_enchants() -> Array[Dictionary]:
	return ENCHANT_DATABASE.duplicate(true)

# Check if an enchant ID exists
static func has_enchant(id: String) -> bool:
	for enchant in ENCHANT_DATABASE:
		if enchant.get("id") == id:
			return true
	return false

# Get bonus stats for a specific enchant ID
static func get_enchant_bonus_stats(id: String) -> Dictionary:
	for enchant in ENCHANT_DATABASE:
		if enchant.get("id") == id:
			return enchant.get("bonus_stats", {}).duplicate(true)
	return {}

# Calculate total combined bonus stats from an array of enchant IDs
static func get_total_enchant_stats(enchant_ids: Array) -> Dictionary:
	var total_stats: Dictionary = {
		"damage": 0,
		"critical": 0,
		"hit_rate": 0
	}
	
	for enc_id in enchant_ids:
		var enc_data: Dictionary = get_enchant_by_id(str(enc_id))
		var bonus: Dictionary = enc_data.get("bonus_stats", {})
		total_stats["damage"] += bonus.get("damage", 0)
		total_stats["critical"] += bonus.get("critical", 0)
		total_stats["hit_rate"] += bonus.get("hit_rate", 0)
		
	return total_stats

# ==========================================
# FILTERING & SEARCHING
# ==========================================

# Get enchants filtered by EnchantType (BUFF, DEBUFF, UTILITY)
static func get_enchants_by_type(type: EnchantType) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for enchant in ENCHANT_DATABASE:
		if enchant.get("type") == type:
			results.append(enchant.duplicate(true))
	return results
