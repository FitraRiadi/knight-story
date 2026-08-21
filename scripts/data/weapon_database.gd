@warning_ignore("shadowed_global_identifier")
class_name WeaponDatabase extends RefCounted

# Enum untuk menjaga konsistensi tipe dan rarity di seluruh project
enum WeaponType { SWORD, DAGGER, AXE, POLEARM }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const WEAPON_DATABASE: Array[Dictionary] = [
	{
		"id": "iron_sword",
		"name": "Iron Sword",
		"type": WeaponType.SWORD,
		"rarity": Rarity.COMMON,
		"description": "A sturdy sword forged from refined iron. Reliable and effective for close combat.",
		"icon": "res://assets/art/items/weapons/short_sword_01.png",
		"enchantment": ["sharpness-1"],
		"stats": {
			"damage": 20,
			"critical": 5,
			"hit_rate": 90
		},
		"materials": [
			{"id": "iron_ingot", "amount": 3},
			{"id": "wood_plank", "amount": 1}
		]
	},
	{
		"id": "wooden_training_sword",
		"name": "Wooden Training Sword",
		"type": WeaponType.SWORD,
		"rarity": Rarity.COMMON,
		"description": "A harmless sword made of oak wood. Perfect for beginners to practice basic swings.",
		"icon": "res://assets/art/items/weapons/axe_wood_splitting_01.png",
		"enchantment": [],
		"stats": {
			"damage": 5,
			"critical": 0,
			"hit_rate": 100
		},
		"materials": [
			{"id": "wood_plank", "amount": 2}
		]
	},
	{
		"id": "steel_longsword",
		"name": "Steel Longsword",
		"type": WeaponType.SWORD,
		"rarity": Rarity.UNCOMMON,
		"description": "An upgraded steel blade with increased sharpness and extended reach for knights.",
		"icon": "res://assets/art/items/weapons/katana_01.png",
		"enchantment": ["sharpness-1", "knockback-2"],
		"stats": {
			"damage": 45,
			"critical": 8,
			"hit_rate": 85
		},
		"materials": [
			{"id": "steel_ingot", "amount": 4},
			{"id": "leather_strip", "amount": 2}
		]
	},
	{
		"id": "assassin_dagger",
		"name": "Assassin Dagger",
		"type": WeaponType.DAGGER,
		"rarity": Rarity.RARE,
		"description": "A lightweight concealed dagger. Grants high critical damage when striking from behind.",
		"icon": "res://assets/art/items/weapons/dagger_01.png",
		"enchantment": ["poison-1", "lifesteal-1"],
		"stats": {
			"damage": 15,
			"critical": 35,
			"hit_rate": 98
		},
		"materials": [
			{"id": "steel_ingot", "amount": 2},
			{"id": "shadow_essence", "amount": 1},
			{"id": "poison_gland", "amount": 1}
		]
	},
	{
		"id": "heroic_claymore",
		"name": "Heroic Claymore",
		"type": WeaponType.SWORD,
		"rarity": Rarity.RARE,
		"description": "A massive two-handed sword that deals heavy damage but slows down the user's attack speed.",
		"icon": "res://assets/art/items/weapons/kanabo_01.png",
		"enchantment": ["knockback-3"],
		"stats": {
			"damage": 65,
			"critical": 10,
			"hit_rate": 75
		},
		"materials": [
			{"id": "heavy_iron_ingot", "amount": 6},
			{"id": "leather_strip", "amount": 3}
		]
	},
	{
		"id": "fire_brand",
		"name": "Fire Brand",
		"type": WeaponType.SWORD,
		"rarity": Rarity.RARE,
		"description": "A magical blade enchanted with volcanic embers. Scorches enemies upon contact.",
		"icon": "res://assets/art/items/weapons/tanto_01.png",
		"enchantment": ["fire-1", "knockback-2"],
		"stats": {
			"damage": 35,
			"critical": 12,
			"hit_rate": 95
		},
		"materials": [
			{"id": "steel_ingot", "amount": 3},
			{"id": "fire_crystal", "amount": 2}
		]
	},
	{
		"id": "rusty_cutlass",
		"name": "Rusty Cutlass",
		"type": WeaponType.SWORD,
		"rarity": Rarity.COMMON,
		"description": "An old, worn-out sword found near the seashore. Inflicts minor damage but looks historic.",
		"icon": "res://assets/art/items/weapons/mace_01.png",
		"enchantment": [],
		"stats": {
			"damage": 12,
			"critical": 3,
			"hit_rate": 80
		},
		"materials": [
			{"id": "scrap_metal", "amount": 2}
		]
	},
	{
		"id": "shadow_baselard",
		"name": "Shadow Baselard",
		"type": WeaponType.DAGGER,
		"rarity": Rarity.EPIC,
		"description": "A cursed dagger forged in the abyss. Absorbs a small amount of enemy life points.",
		"icon": "res://assets/art/items/weapons/naginata_01.png",
		"enchantment": ["lifesteal-1", "fire-1"],
		"stats": {
			"damage": 28,
			"critical": 15,
			"hit_rate": 92
		},
		"materials": [
			{"id": "dark_steel_ingot", "amount": 3},
			{"id": "abyssal_shard", "amount": 2},
			{"id": "vampiric_blood", "amount": 1}
		]
	},
	{
		"id": "excalibur",
		"name": "Excalibur",
		"type": WeaponType.SWORD,
		"rarity": Rarity.LEGENDARY,
		"description": "The legendary blade of kings. Radiates a holy light that vanquishes dark monsters instantly.",
		"icon": "res://assets/art/items/weapons/pike_weapon_01.png",
		"enchantment": ["holy-3", "sharpness-3", "lifesteal-2"],
		"stats": {
			"damage": 90,
			"critical": 25,
			"hit_rate": 100
		},
		"materials": [
			{"id": "mithril_ingot", "amount": 5},
			{"id": "holy_orb", "amount": 1},
			{"id": "dragon_scale", "amount": 2}
		]
	}
]

# ==========================================
# GETTER: DATA UTUH
# ==========================================

# Ambil 1 data senjata utuh berdasarkan ID
static func get_weapon_by_id(id: String) -> Dictionary:
	for weapon in WEAPON_DATABASE:
		if weapon.get("id") == id:
			return weapon.duplicate(true)
	return {}

# Ambil seluruh database senjata
static func get_all_weapons() -> Array[Dictionary]:
	return WEAPON_DATABASE.duplicate(true)

# Cek apakah ID senjata valid/ada
static func has_weapon(id: String) -> bool:
	for weapon in WEAPON_DATABASE:
		if weapon.get("id") == id:
			return true
	return false

# ==========================================
# GETTER: PROPERTI SPESIFIK
# ==========================================

# Ambil atribut spesifik senjata (misal: "name", "description", "icon")
static func get_weapon_property(id: String, property: String, default = null) -> Variant:
	for weapon in WEAPON_DATABASE:
		if weapon.get("id") == id:
			var val = weapon.get(property, default)
			return val.duplicate(true) if val is Dictionary or val is Array else val
	return default

# Ambil statistik senjata (damage, critical, hit_rate)
static func get_weapon_stats(id: String) -> Dictionary:
	for weapon in WEAPON_DATABASE:
		if weapon.get("id") == id:
			return weapon.get("stats", {}).duplicate(true)
	return {}

# Ambil array enchantment
static func get_weapon_enchantments(id: String) -> Array:
	for weapon in WEAPON_DATABASE:
		if weapon.get("id") == id:
			return weapon.get("enchantment", []).duplicate(true)
	return []

# Ambil array bahan/materials crafting
static func get_weapon_materials(id: String) -> Array[Dictionary]:
	for weapon in WEAPON_DATABASE:
		if weapon.get("id") == id:
			var raw_mats: Array = weapon.get("materials", [])
			var results: Array[Dictionary] = []
			for mat in raw_mats:
				if mat is Dictionary:
					results.append(mat.duplicate(true))
			return results
	return []

# ==========================================
# GETTER: FILTERING & SEARCHING
# ==========================================

# Filter senjata berdasarkan Rarity
static func get_weapons_by_rarity(rarity: Rarity) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for weapon in WEAPON_DATABASE:
		if weapon.get("rarity") == rarity:
			results.append(weapon.duplicate(true))
	return results

# Filter senjata berdasarkan Type
static func get_weapons_by_type(type: WeaponType) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for weapon in WEAPON_DATABASE:
		if weapon.get("type") == type:
			results.append(weapon.duplicate(true))
	return results

# Filter senjata gabungan (Type & Rarity)
static func get_weapons_by_type_and_rarity(type: WeaponType, rarity: Rarity) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for weapon in WEAPON_DATABASE:
		if weapon.get("type") == type and weapon.get("rarity") == rarity:
			results.append(weapon.duplicate(true))
	return results

# Ambil semua daftar ID senjata
static func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for weapon in WEAPON_DATABASE:
		ids.append(weapon.get("id", ""))
	return ids
