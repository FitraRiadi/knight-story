extends Node

# ============================================================
# PLAYER DATA MANAGER (Autoload)
#
# Load dari res:// sebagai default.
# Save/load ke user://.knight/sys/cache/ (binary, hidden).
# ============================================================

var data: PlayerData

const DEFAULT_PATH := "res://data/player/player_data.tres"
const SAVE_DIR := "user://.knight/sys/cache/"
const SAVE_PATH := SAVE_DIR + "data.res"


func _ready() -> void:
	print("[PlayerDataManager] Save path: ", ProjectSettings.globalize_path(SAVE_PATH))
	_init_save()


func _init_save() -> void:
	# Pastikan folder ada
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))

	# Kalau save belum ada, copy dari res://
	if not FileAccess.file_exists(SAVE_PATH):
		var default_data = load(DEFAULT_PATH) as PlayerData
		if default_data:
			data = default_data.duplicate(true) as PlayerData
			if data.battle_inventory:
				data.battle_inventory = data.battle_inventory.duplicate(true) as InventoryBattleData
			if data.chest_inventory:
				data.chest_inventory = data.chest_inventory.duplicate(true) as InventoryBattleData
			save()
			return
		else:
			push_error("[PlayerDataManager] Gagal load default data dari: " + DEFAULT_PATH)
			data = PlayerData.new()
			return

	# Load dari user://
	var loaded = load(SAVE_PATH) as PlayerData
	if loaded:
		data = loaded
	else:
		push_error("[PlayerDataManager] Gagal load save data dari: " + SAVE_PATH)
		data = PlayerData.new()


func save() -> void:
	if data == null:
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	# Gunakan path .res untuk format binary
	var err = ResourceSaver.save(data, SAVE_PATH)
	if err != OK:
		push_error("[PlayerDataManager] Gagal save! Error code: " + str(err))


func add_gold(amount: int) -> void:
	if data == null:
		return
	data.gold += amount
	save()


func spend_gold(amount: int) -> bool:
	if data == null:
		return false
	if data.gold < amount:
		return false
	data.gold -= amount
	save()
	return true


func get_gold() -> int:
	if data == null:
		return 0
	return data.gold


func add_item_to_inventory(item: ItemData) -> bool:
	if data == null or data.battle_inventory == null:
		return false

	# Cari null slot dulu (slot yang sudah dipake tapi di-set null)
	for i in range(data.battle_inventory.items.size()):
		if data.battle_inventory.items[i] == null:
			data.battle_inventory.items[i] = item
			save()
			return true

	# Kalau gak ada null slot, append kalau belum max 9
	if data.battle_inventory.items.size() < 9:
		data.battle_inventory.items.append(item)
		save()
		return true

	return false


func remove_item(index: int) -> void:
	if data == null or data.battle_inventory == null:
		return

	if index < 0 or index >= data.battle_inventory.items.size():
		return

	data.battle_inventory.items[index] = null
	save()


func remove_chest_item(index: int) -> void:
	if data == null or data.chest_inventory == null:
		return

	if index < 0 or index >= data.chest_inventory.items.size():
		return

	data.chest_inventory.items[index] = null
	save()


func reset_data() -> void:
	# Hapus seluruh folder .knight
	var knight_dir = ProjectSettings.globalize_path("user://.knight/")
	var dir = DirAccess.open(ProjectSettings.globalize_path("user://"))
	if dir:
		dir.remove_recursive(knight_dir)
	_init_save()
