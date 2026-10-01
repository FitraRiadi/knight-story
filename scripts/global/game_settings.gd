extends RefCounted
class_name GameSettings

# ============================================================
# GAME SETTINGS (static, bukan autoload)
# Save: user://.knight/sys/settings.res (terpisah dari save player,
# jadi hapus save game gak ngereset setting).
# ============================================================

const SAVE_PATH := "user://.knight/sys/settings.res"
const DEFAULT_PATH := "res://data/settings/default_settings.tres"

static var _data: SettingsData = null


static func get_data() -> SettingsData:
	if _data == null:
		load_settings()
	return _data


static func load_settings() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var loaded := load(SAVE_PATH) as SettingsData
		if loaded:
			_data = loaded
			return
	var d := load(DEFAULT_PATH) as SettingsData
	if d:
		_data = d.duplicate(true) as SettingsData
	else:
		_data = SettingsData.new()


static func save_settings() -> void:
	if _data == null:
		return
	var dir_path := ProjectSettings.globalize_path(SAVE_PATH.get_base_dir())
	var mk_err := DirAccess.make_dir_recursive_absolute(dir_path)
	if mk_err != OK:
		push_warning("[GameSettings] Gagal bikin folder: " + dir_path)
		return
	var err := ResourceSaver.save(_data, SAVE_PATH)
	if err != OK:
		push_warning("[GameSettings] Gagal save! Error: " + str(err))


static func set_graphics(v: String) -> void:
	get_data().graphics = v
	save_settings()


static func set_music_volume(v: float) -> void:
	get_data().music_volume = v
	save_settings()


## "high" / "low". Gak ada auto (default low, aman di semua HP).
static func get_effective_tier() -> String:
	if get_data().graphics == "high":
		return "high"
	return "low"
