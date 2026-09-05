extends Node

const LOCATION_DIR: String = "res://data/locations/"
var _locations_cache: Dictionary = {}

func _ready() -> void:
	_load_all_locations()

func _load_all_locations() -> void:
	_locations_cache.clear()
	
	var dir = DirAccess.open(LOCATION_DIR)
	if not dir:
		push_error("[LocationDatabase] Gagal membuka folder: " + LOCATION_DIR)
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			var clean_name = file_name.trim_suffix(".remap")
			if clean_name.ends_with(".tres"):
				var resource_path = LOCATION_DIR + clean_name
				var location_data = load(resource_path) as LocationData
				
				if location_data:
					if location_data.location_id != "":
						if _locations_cache.has(location_data.location_id):
							push_warning("[LocationDatabase] PERINGATAN: ID '%s' pada file '%s' sudah ada! Ditimpa oleh file '%s'." % [location_data.location_id, _locations_cache[location_data.location_id].resource_path, clean_name])
						
						_locations_cache[location_data.location_id] = location_data
						print("[LocationDatabase] Sukses -> ID: '%s' | File: %s" % [location_data.location_id, clean_name])
					else:
						push_warning("[LocationDatabase] File '%s' memiliki 'location_id' yang masih KOSONG!" % clean_name)
				else:
					push_warning("[LocationDatabase] Gagal me-load resource di path: " + resource_path)
					
		file_name = dir.get_next()
		
	dir.list_dir_end()
	print("[LocationDatabase] Total lokasi berhasil dimuat: ", _locations_cache.keys())

func get_location(id: String) -> LocationData:
	if _locations_cache.has(id):
		return _locations_cache[id]
		
	push_warning("[LocationDatabase] Lokasi dengan ID '" + id + "' tidak ditemukan di cache!")
	return null

func get_all_locations() -> Array:
	return _locations_cache.values()

func get_all_location_ids() -> Array:
	return _locations_cache.keys()
