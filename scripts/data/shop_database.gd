extends RefCounted
class_name ShopDatabase


# ============================================================
# SHOP DATABASE
# Static data untuk item yang dijual Robert di Tavern.
# ============================================================

const SHOP_DATABASE: Array[Dictionary] = [
	{
		"id": "health_potion",
		"name": "Health Potion",
		"description": "Instantly restores 100 HP.",
		"icon_path": "res://assets/art/items/consumable/potion/Icon31.png",
		"price": 100,
		"item_path": "res://data/items/consumable/health_potion.tres",
	},
	{
		"id": "attack_potion",
		"name": "Attack Potion",
		"description": "Temporarily increases Attack Power by 15 for 3 turns.",
		"icon_path": "res://assets/art/items/consumable/potion/Icon20.png",
		"price": 250,
		"item_path": "res://data/items/consumable/attack_potion.tres",
	},
]


static func get_all_shop_items() -> Array[Dictionary]:
	return SHOP_DATABASE.duplicate(true)


static func get_shop_item_by_id(item_id: String) -> Dictionary:
	for item in SHOP_DATABASE:
		if item.get("id", "") == item_id:
			return item.duplicate(true)
	return {}


static func get_item_price(item_id: String) -> int:
	var item = get_shop_item_by_id(item_id)
	return item.get("price", 0)


static func get_item_icon_path(item_id: String) -> String:
	var item = get_shop_item_by_id(item_id)
	return item.get("icon_path", "")


static func get_item_data_path(item_id: String) -> String:
	var item = get_shop_item_by_id(item_id)
	return item.get("item_path", "")
