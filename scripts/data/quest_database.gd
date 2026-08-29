extends Node


# ============================================================
# QUEST DATABASE (Autoload)	
# Scan res://data/quests/ untuk load semua quest .tres files.
# ============================================================

const QUEST_DIR: String = "res://data/quests/"
var _quests_cache: Dictionary = {}


func _ready() -> void:
	_load_all_quests()


func _load_all_quests() -> void:
	_quests_cache.clear()

	var dir = DirAccess.open(QUEST_DIR)
	if not dir:
		push_error("[QuestDatabase] Gagal membuka folder: " + QUEST_DIR)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			var clean_name = file_name.trim_suffix(".remap")
			if clean_name.ends_with(".tres"):
				var resource_path = QUEST_DIR + clean_name
				var quest_data = load(resource_path) as QuestData

				if quest_data:
					if quest_data.quest_id != "":
						if _quests_cache.has(quest_data.quest_id):
							push_warning(
								"[QuestDatabase] ID '%s' pada '%s' sudah ada! Ditimpa." % [
									quest_data.quest_id, clean_name
								]
							)

						_quests_cache[quest_data.quest_id] = quest_data
						print("[QuestDatabase] Loaded -> ID: '%s' | %s" % [
							quest_data.quest_id, clean_name
						])
					else:
						push_warning(
							"[QuestDatabase] File '%s' memiliki quest_id KOSONG!" % clean_name
						)
				else:
					push_warning(
						"[QuestDatabase] Gagal load resource: " + resource_path
					)

		file_name = dir.get_next()

	dir.list_dir_end()
	print("[QuestDatabase] Total quest dimuat: ", _quests_cache.keys())


func get_quest(id: String) -> QuestData:
	if _quests_cache.has(id):
		return _quests_cache[id]
	push_warning("[QuestDatabase] Quest '%s' tidak ditemukan!" % id)
	return null


func get_all_quests() -> Array:
	return _quests_cache.values()


func get_quests_by_type(quest_type: String) -> Array:
	var result: Array = []
	for quest in _quests_cache.values():
		if quest.quest_type == quest_type:
			result.append(quest)
	return result
