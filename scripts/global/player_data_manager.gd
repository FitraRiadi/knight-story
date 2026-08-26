extends Node

# ============================================================
# PLAYER DATA MANAGER (Autoload)
#
# Load player_data.tres saat game mulai.
# Provide save() buat overwrite .tres setelah perubahan.
# ============================================================

var data: PlayerData

const PATH := "res://data/player/player_data.tres"


func _ready() -> void:
	data = load(PATH) as PlayerData

	if data == null:
		push_error("[PlayerDataManager] Gagal load PlayerData di: " + PATH)
		data = PlayerData.new()


func save() -> void:
	if data == null:
		return

	var err = ResourceSaver.save(data, PATH)

	if err != OK:
		push_error("[PlayerDataManager] Gagal save PlayerData! Error code: " + str(err))


func remove_item(index: int) -> void:
	if data == null or data.battle_inventory == null:
		return

	if index < 0 or index >= data.battle_inventory.items.size():
		return

	data.battle_inventory.items[index] = null
	save()
