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
const QUEST_SAVE_PATH := SAVE_DIR + "quests.json"

# Quest state
var active_quest_id: String = ""
var quest_progress: Dictionary = {}  # { quest_id: current_count }
var displayed_quest_ids: Array = []  # ID quest yang sedang tampil di board
var completed_quest_ids: Array = []  # ID quest yang udah selesai (claimed)


func _ready() -> void:
	print("[PlayerDataManager] Save path: ", ProjectSettings.globalize_path(SAVE_PATH))
	_init_save()
	load_quest_state()


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


func transfer_to_battle(chest_index: int) -> bool:
	if data == null or data.chest_inventory == null or data.battle_inventory == null:
		return false

	if chest_index < 0 or chest_index >= data.chest_inventory.items.size():
		return false

	var item = data.chest_inventory.items[chest_index]
	if not item:
		return false

	# Cari slot kosong di battle_inventory
	var battle_items := data.battle_inventory.items
	var target_index := -1
	for i in range(battle_items.size()):
		if battle_items[i] == null:
			target_index = i
			break

	# Kalau gak ada null slot, append kalau belum max 9
	if target_index == -1 and battle_items.size() < 9:
		target_index = battle_items.size()

	if target_index == -1:
		return false

	# Pastikan array cukup besar
	while battle_items.size() <= target_index:
		battle_items.append(null)

	battle_items[target_index] = item
	data.chest_inventory.items[chest_index] = null
	save()
	return true


func transfer_to_chest(battle_index: int) -> bool:
	if data == null or data.chest_inventory == null or data.battle_inventory == null:
		return false

	if battle_index < 0 or battle_index >= data.battle_inventory.items.size():
		return false

	var item = data.battle_inventory.items[battle_index]
	if not item:
		return false

	# Cari slot kosong di chest_inventory
	var chest_items := data.chest_inventory.items
	var target_index := -1
	for i in range(chest_items.size()):
		if chest_items[i] == null:
			target_index = i
			break

	# Kalau gak ada null slot, append kalau belum max 18
	if target_index == -1 and chest_items.size() < 18:
		target_index = chest_items.size()

	if target_index == -1:
		return false

	# Pastikan array cukup besar
	while chest_items.size() <= target_index:
		chest_items.append(null)

	chest_items[target_index] = item
	data.battle_inventory.items[battle_index] = null
	save()
	return true


func swap_battle_slots(a: int, b: int) -> void:
	if data == null or data.battle_inventory == null:
		return
	var items := data.battle_inventory.items
	if a < 0 or b < 0:
		return
	while items.size() <= a:
		items.append(null)
	while items.size() <= b:
		items.append(null)
	var temp = items[a]
	items[a] = items[b]
	items[b] = temp
	save()


func swap_chest_slots(a: int, b: int) -> void:
	if data == null or data.chest_inventory == null:
		return
	var items := data.chest_inventory.items
	if a < 0 or b < 0:
		return
	while items.size() <= a:
		items.append(null)
	while items.size() <= b:
		items.append(null)
	var temp = items[a]
	items[a] = items[b]
	items[b] = temp
	save()


func swap_between_inventories(
	src_type: String, src_idx: int,
	tgt_type: String, tgt_idx: int
) -> void:
	if data == null:
		return

	var src_items: Array
	var tgt_items: Array
	if src_type == "battle":
		src_items = data.battle_inventory.items
	else:
		src_items = data.chest_inventory.items

	if tgt_type == "battle":
		tgt_items = data.battle_inventory.items
	else:
		tgt_items = data.chest_inventory.items

	if src_idx < 0 or tgt_idx < 0:
		return

	# Pastikan array cukup besar
	while src_items.size() <= src_idx:
		src_items.append(null)
	while tgt_items.size() <= tgt_idx:
		tgt_items.append(null)

	var src_item = src_items[src_idx]
	var tgt_item = tgt_items[tgt_idx]

	tgt_items[tgt_idx] = src_item
	src_items[src_idx] = tgt_item
	save()


func reset_data() -> void:
	# Hapus seluruh folder .knight
	var knight_dir = ProjectSettings.globalize_path("user://.knight/")
	var dir = DirAccess.open(ProjectSettings.globalize_path("user://"))
	if dir:
		dir.remove_recursive(knight_dir)
	_init_save()


# ============================================================
# EXP & LEVEL
# ============================================================

func add_exp(amount: int) -> bool:
	if data == null:
		return false
	data.player_exp += amount
	var leveled_up = false
	while data.player_exp >= data.player_max_exp:
		data.player_exp -= data.player_max_exp
		data.player_level += 1
		data.player_max_exp = _calc_max_exp(data.player_level)
		leveled_up = true
	save()
	return leveled_up


func _calc_max_exp(level: int) -> int:
	var tier = (level - 1) / 5
	return 100 + (tier * 250)


func get_level() -> int:
	if data == null:
		return 1
	return data.player_level


func get_exp() -> int:
	if data == null:
		return 0
	return data.player_exp


func get_max_exp() -> int:
	if data == null:
		return 100
	return data.player_max_exp


# ============================================================
# QUEST STATE
# ============================================================

func save_quest_state() -> void:
	var save_data = {
		"active_quest_id": active_quest_id,
		"quest_progress": quest_progress,
		"displayed_quest_ids": displayed_quest_ids,
		"completed_quest_ids": completed_quest_ids,
	}
	var file = FileAccess.open(QUEST_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()


func load_quest_state() -> void:
	if not FileAccess.file_exists(QUEST_SAVE_PATH):
		return
	var file = FileAccess.open(QUEST_SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return
	var save_data = json.data
	if save_data is Dictionary:
		active_quest_id = save_data.get("active_quest_id", "")
		quest_progress = save_data.get("quest_progress", {})
		displayed_quest_ids = save_data.get("displayed_quest_ids", [])
		completed_quest_ids = save_data.get("completed_quest_ids", [])


func set_active_quest(quest_id: String) -> void:
	active_quest_id = quest_id
	if quest_id != "" and quest_id not in quest_progress:
		quest_progress[quest_id] = 0
	save_quest_state()


func clear_active_quest() -> void:
	active_quest_id = ""
	save_quest_state()


func set_displayed_quests(ids: Array) -> void:
	displayed_quest_ids = ids
	save_quest_state()


func remove_displayed_quest(quest_id: String) -> void:
	displayed_quest_ids.erase(quest_id)
	save_quest_state()


func add_displayed_quest(quest_id: String) -> void:
	if quest_id not in displayed_quest_ids:
		displayed_quest_ids.append(quest_id)
		save_quest_state()


func mark_quest_completed(quest_id: String) -> void:
	if quest_id not in completed_quest_ids:
		completed_quest_ids.append(quest_id)
		save_quest_state()


func is_quest_completed(quest_id: String) -> bool:
	return quest_id in completed_quest_ids


func get_quest_progress(quest_id: String) -> int:
	return quest_progress.get(quest_id, 0)


func set_quest_progress(quest_id: String, count: int) -> void:
	quest_progress[quest_id] = count
	save_quest_state()


func increment_quest_progress(quest_id: String) -> int:
	if quest_id not in quest_progress:
		quest_progress[quest_id] = 0
	quest_progress[quest_id] += 1
	save_quest_state()
	return quest_progress[quest_id]


func count_item_in_inventory(item_id: String) -> int:
	if data == null or data.battle_inventory == null:
		return 0
	var count = 0
	for item in data.battle_inventory.items:
		if item != null and item.item_id == item_id:
			count += 1
	return count


func has_quest_reward_item(quest_id: String) -> bool:
	var quest = QuestDatabase.get_quest(quest_id)
	if quest and quest.reward_item_id != "":
		return true
	return false
