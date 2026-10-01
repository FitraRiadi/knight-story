extends RefCounted
class_name GameSettings

# ============================================================
# GAME SETTINGS (static, bukan autoload)
# Save: user://.knight/sys/settings.res (terpisah dari save player,
# jadi hapus save game gak ngereset setting).
# ============================================================

const SAVE_PATH := "user://.knight/sys/settings.res"
const DEFAULT_PATH := "res://data/settings/default_settings.tres"

# Keyword nama GPU kentang (lowercase, substring match).
const LOW_GPU_KEYWORDS: Array[String] = [
	"mali-4", "mali-t6", "mali-t7", "mali-t8",
	"adreno 3", "adreno 4",
	"powervr sgx", "powervr",
	"vivante", "videocore",
	"swiftshader", "llvmpipe", "softpipe",
]

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


## "high" / "low". "auto" = deteksi GPU.
static func get_effective_tier() -> String:
	var g := get_data().graphics
	if g == "high":
		return "high"
	if g == "low":
		return "low"
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	for kw in LOW_GPU_KEYWORDS:
		if kw in adapter:
			print("[GameSettings] GPU kentang kedetek (", RenderingServer.get_video_adapter_name(), ") -> tier LOW")
			return "low"
	print("[GameSettings] GPU (", RenderingServer.get_video_adapter_name(), ") -> tier HIGH")
	return "high"
