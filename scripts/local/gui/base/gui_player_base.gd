extends Control

@onready var base_title: Label = $"base-title"
@onready var bar_features: Control = $"bar-features"

# Ambil referensi tombol di dalam bar-features
@onready var map_btn: TextureButton = $"bar-features/mapBtn"
@onready var inventory_btn: TextureButton = $"bar-features/inventoryBtn"
@onready var inventory_btn_2: TextureButton = $"bar-features/inventoryBtn2"

# Bar Top Information
@onready var profile: TextureRect = $"bar-information/profile"
@onready var information: TextureRect = $"bar-information/information"

# Referensi Node Level & Badge (sesuai Scene Tree)
@onready var level: TextureRect = $"bar-information/level"
@onready var badge: TextureRect = $"bar-information/badge"

# Referensi Node Status Bar
@onready var hp_status: TextureRect = $"bar-information/HPstatus"
@onready var stamina_status: TextureRect = $"bar-information/STAMINAstatus"
@onready var moral_status: TextureRect = $"bar-information/MORALstatus"

# Referensi EXP Progress sebagai Panel
@onready var exp_progress: Panel = $"bar-information/information/exp-bar/exp-progress"

# Variabel Sistem EXP
var max_exp_width: float = 0.0  # Lebar pixel saat bar 100% (diambil dari editor)
var max_exp: float = 300.0      # Batas angka EXP maksimal
var current_exp: float = 300.0  # Angka EXP pemain saat ini

func _ready() -> void:
	inventory_btn.pressed.connect(_open_chest_inventory)
	if exp_progress:
		# 1. Simpan batas visual full (100%) dari lebar Panel di Editor
		max_exp_width = exp_progress.size.x
		
		# 2. Set awal panjang bar ke 0 px
		exp_progress.size.x = 0.0

	# --- ATUR POSISI AWAL & ALPHA (OFFSETS) ---
	base_title.position.y -= 100
	base_title.modulate.a = 0
	
	profile.position.x -= 100
	information.position.x -= 300
	information.modulate.a = 0
	
	# Level & Badge: Tarik ke KIRI (x-) dan buat transparan
	level.position.x -= 50
	level.modulate.a = 0
	
	badge.position.x -= 50
	badge.modulate.a = 0
	
	# Status bar: Tarik ke ATAS (y-) dan buat transparan
	hp_status.position.y -= 40
	hp_status.modulate.a = 0
	
	stamina_status.position.y -= 40
	stamina_status.modulate.a = 0
	
	moral_status.position.y -= 40
	moral_status.modulate.a = 0
	
	map_btn.position.y += 50
	map_btn.modulate.a = 0
	
	inventory_btn.position.y += 50
	inventory_btn.modulate.a = 0
	
	inventory_btn_2.position.y += 50
	inventory_btn_2.modulate.a = 0
	
	# --- ANIMASI INTRO ---
	var tween = create_tween()
	tween.set_parallel(true)

	# 1. Title, Profile, & Information Slide In (Durasi 0.8s)
	tween.tween_property(base_title, "position:y", base_title.position.y + 100, 0.8).set_trans(Tween.TRANS_CIRC)
	tween.tween_property(base_title, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_CIRC)
	
	tween.tween_property(profile, "position:x", profile.position.x + 100, 0.8).set_trans(Tween.TRANS_CIRC)
	
	tween.tween_property(information, "position:x", information.position.x + 300, 0.8).set_trans(Tween.TRANS_CIRC)
	tween.tween_property(information, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_CIRC)
	
	# 2. LEVEL & BADGE: KIRI -> KANAN (Level dulu, baru Badge)
	# PERTAMA: Level (delay 0.5s)
	tween.tween_property(level, "position:x", level.position.x + 50, 0.5).set_delay(0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(level, "modulate:a", 1.0, 0.5).set_delay(0.5)
	
	# KEDUA: Badge (delay 0.65s)
	tween.tween_property(badge, "position:x", badge.position.x + 50, 0.5).set_delay(0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(badge, "modulate:a", 1.0, 0.5).set_delay(0.65)
	
	# 3. Status Bars Animation: Meluncur dari ATAS (y-) ke BAWAH (y+)
	# Urutan: HP -> STAMINA -> MORAL
	tween.tween_property(hp_status, "position:y", hp_status.position.y + 40, 0.4).set_delay(0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(hp_status, "modulate:a", 1.0, 0.4).set_delay(0.8)
	
	tween.tween_property(stamina_status, "position:y", stamina_status.position.y + 40, 0.4).set_delay(0.95).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(stamina_status, "modulate:a", 1.0, 0.4).set_delay(0.95)
	
	tween.tween_property(moral_status, "position:y", moral_status.position.y + 40, 0.4).set_delay(1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(moral_status, "modulate:a", 1.0, 0.4).set_delay(1.1)
	
	# 4. EXP Bar Filling Animation
	if exp_progress:
		var target_intro_width: float = (clamp(current_exp, 0.0, max_exp) / max_exp) * max_exp_width
		tween.tween_property(exp_progress, "size:x", target_intro_width, 1.8)\
			.set_delay(0.8)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)

	# 5. Tombol Bar Features Slide Up
	tween.tween_property(map_btn, "position:y", map_btn.position.y - 50, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.3)
	tween.tween_property(map_btn, "modulate:a", 1.0, 0.5).set_delay(0.3)
	
	tween.tween_property(inventory_btn, "position:y", inventory_btn.position.y - 50, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.45)
	tween.tween_property(inventory_btn, "modulate:a", 1.0, 0.5).set_delay(0.45)
	
	tween.tween_property(inventory_btn_2, "position:y", inventory_btn_2.position.y - 50, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.45)
	tween.tween_property(inventory_btn_2, "modulate:a", 1.0, 0.5).set_delay(0.45)

# Fungsi umum untuk update EXP selanjutnya sewaktu gameplay berlangsung
func set_exp(new_exp: float, new_max_exp: float = -1.0) -> void:
	if new_max_exp > 0:
		max_exp = new_max_exp
		
	current_exp = clamp(new_exp, 0.0, max_exp)
	var target_width: float = (current_exp / max_exp) * max_exp_width
	
	if exp_progress:
		var exp_tween = create_tween()
		exp_tween.tween_property(exp_progress, "size:x", target_width, 1.2)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)


# ============================================================
# CHEST INVENTORY
# ============================================================

func _open_chest_inventory() -> void:
	var chest := ChestInventory.new()
	chest.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(chest)
