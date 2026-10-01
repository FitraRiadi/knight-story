extends Resource
class_name SettingsData


# ============================================================
# PLAYER SETTINGS (disimpan di user://.knight/sys/settings.res)
# ============================================================

## Grafik: "high" / "low". Default low (aman di semua HP).
@export_enum("high", "low") var graphics: String = "low":
	set(v):
		graphics = v if v == "high" or v == "low" else "low"

## Volume musik 0.0 - 1.0. Default 0.18 == -15dB (volume sekarang, biar gak kaget).
@export_range(0.0, 1.0) var music_volume: float = 0.18:
	set(v):
		music_volume = clampf(v, 0.0, 1.0)
