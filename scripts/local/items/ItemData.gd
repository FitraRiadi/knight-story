extends Resource
class_name ItemData

@export_group("Item Info")
@export var item_id: String = ""
@export var item_name: String = ""
@export var description: String = ""
@export var icon: Texture2D

@export_group("Consumable Effects")
@export var heal_value: float = 50.0
# Nanti kalau mau nambah status lain (misal: buff attack, mana, dll) bisa ditaruh di sini
