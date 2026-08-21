extends Node

const ENEMY_DIR: String = "res://data/enemies/"
var _enemies_cache: Dictionary = {}

func _ready() -> void:
	_load_all_enemies()

func _load_all_enemies() -> void:
	_enemies_cache.clear()
	
	var dir = DirAccess.open(ENEMY_DIR)
	if not dir:
		push_error("[EnemyDatabase] Gagal membuka folder: " + ENEMY_DIR)
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			var clean_name = file_name.trim_suffix(".remap")
			if clean_name.ends_with(".tres"):
				var resource_path = ENEMY_DIR + clean_name
				var enemy_data = load(resource_path) as EnemyData
				
				if enemy_data:
					if enemy_data.enemy_id != "":
						if _enemies_cache.has(enemy_data.enemy_id):
							push_warning("[EnemyDatabase] PERINGATAN: ID '%s' pada file '%s' sudah ada! Ditimpa oleh file '%s'." % [enemy_data.enemy_id, _enemies_cache[enemy_data.enemy_id].resource_path, clean_name])
						
						_enemies_cache[enemy_data.enemy_id] = enemy_data
						print("[EnemyDatabase] Sukses -> ID: '%s' | File: %s" % [enemy_data.enemy_id, clean_name])
					else:
						push_warning("[EnemyDatabase] File '%s' memiliki 'Enemy Id' yang masih KOSONG!" % clean_name)
				else:
					push_warning("[EnemyDatabase] Gagal me-load resource di path: " + resource_path)
					
		file_name = dir.get_next()
		
	dir.list_dir_end()
	print("[EnemyDatabase] Total musuh berhasil dimuat: ", _enemies_cache.keys())

func get_enemy_data(id: String) -> EnemyData:
	if _enemies_cache.has(id):
		return _enemies_cache[id]
		
	push_warning("[EnemyDatabase] Musuh dengan ID '" + id + "' tidak ditemukan di cache!")
	return null
