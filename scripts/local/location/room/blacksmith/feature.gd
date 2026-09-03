extends Control

@onready var tabs: Dictionary = {
	$mainTab/weaponBtn: get_node_or_null("weaponTab"),
	$mainTab/armorBtn: get_node_or_null("armorTab"),
	$mainTab/toolBtn: get_node_or_null("toolTab"),
	$mainTab/ringBtn: get_node_or_null("ringTab"),
	$mainTab/questBtn: get_node_or_null("questTab"),
}

# Close btn
@onready var close_btn: Button = $mainTab/closeBtn

var current_active_btn: Button = null

# Path file scene Lotus Village
const LOTUS_VILLAGE_SCENE: String = "res://scenes/locations/maps/lotus_village/lotus_village.tscn"

# Variabel Statis Pendukung Visual
var weaponTitleActive: String = ""
var weaponDescActive: String = ""
var weaponIconActive: String = ""
var weaponStatsActive: Dictionary = {}
var weaponMaterialsActive: Array = []

# Reference Node dari Scene Tree
@onready var weapon_selection: Control = get_node_or_null("weaponTab/weaponSelection")
@onready var weapon_title_label: Label = get_node_or_null("weaponTab/weaponTitle")
@onready var weapon_desc_label: Label = get_node_or_null("weaponTab/weaponDesc")

# Reference node TextureRect di dalam weaponDisplay
@onready var weapon_display_texture: TextureRect = get_node_or_null("weaponTab/weaponDisplay/texture")

# Reference Node Status di dalam weaponDisplay/weaponStatus
@onready var weapon_status: Control = get_node_or_null("weaponTab/weaponDisplay/weaponStatus")
@onready var damage_label: Label = get_node_or_null("weaponTab/weaponDisplay/weaponStatus/damage")
@onready var critical_label: Label = get_node_or_null("weaponTab/weaponDisplay/weaponStatus/critical")
@onready var hitrate_label: Label = get_node_or_null("weaponTab/weaponDisplay/weaponStatus/hitrate")

# Reference Node Materials di dalam weaponTab/weaponMaterials
@onready var materials_container: Control = get_node_or_null("weaponTab/weaponMaterials/materials")

var weapon_selection_origin_y: float = 0.0
var weapon_status_origin_y: float = 0.0
var status_tween: Tween = null
var count_tween: Tween = null
var icon_tween: Tween = null

# Menyimpan nilai stat sebelumnya agar angka menghitung mulus dari nilai lama ke nilai baru
var last_damage: float = 0.0
var last_critical: float = 0.0
var last_hitrate: float = 0.0

# Menyimpan referensi slot senjata yang saat ini sedang aktif ditekan
var current_active_weapon_slot: BaseButton = null

func _ready() -> void:
	# --- KONEKSI SINYAL TOMBOL CLOSE ---
	if close_btn:
		close_btn.pressed.connect(_on_close_btn_pressed)

	# Catat posisi asli Y weaponSelection
	if weapon_selection:
		weapon_selection_origin_y = weapon_selection.position.y

	# Catat posisi asli Y weaponStatus & atur pivot point ke tengah bawah
	if weapon_status:
		weapon_status_origin_y = weapon_status.position.y
		weapon_status.pivot_offset = Vector2(weapon_status.size.x / 2.0, weapon_status.size.y)

	# Set data awal game menggunakan senjata indeks ke-0 dari WeaponDatabase
	var all_weapons: Array[Dictionary] = WeaponDatabase.get_all_weapons()
	if all_weapons.size() > 0:
		weaponTitleActive = all_weapons[0].get("name", "")
		weaponDescActive = all_weapons[0].get("description", "")
		weaponIconActive = all_weapons[0].get("icon", "")
		weaponStatsActive = all_weapons[0].get("stats", {})
		weaponMaterialsActive = all_weapons[0].get("materials", [])
	_update_weapon_info()

	for btn in tabs.keys():
		if btn:
			btn.pressed.connect(func(): _switch_tab(btn))
		
	# Set tab default saat start
	_switch_tab($mainTab/weaponBtn)

# Fungsi yang dipanggil saat closeBtn ditekan
func _on_close_btn_pressed() -> void:
	TransitionManager.pindah_scene_with_zoom(LOTUS_VILLAGE_SCENE, close_btn)

func _update_weapon_info() -> void:
	if weapon_title_label:
		weapon_title_label.text = weaponTitleActive
	if weapon_desc_label:
		weapon_desc_label.text = weaponDescActive
		
	# Mengganti gambar pratinjau besar pada weaponDisplay saat info di-update
	if weapon_display_texture and ResourceLoader.exists(weaponIconActive):
		weapon_display_texture.texture = load(weaponIconActive)
		_play_weapon_icon_pop_anim()

	# Animasikan pertambahan angka status secara smooth tiap frame
	_animate_status_values()
	
	# Update tampilan material kebutuhan crafting
	_update_weapon_materials()

func _update_weapon_materials() -> void:
	if materials_container == null:
		return

	for i in range(1, 7):
		var mat_node = materials_container.get_node_or_null("material" + str(i))
		if mat_node == null:
			continue

		var icon_node = mat_node.get_node_or_null("icon")
		var label1_node = mat_node.get_node_or_null("Label") as Label
		var label2_node = mat_node.get_node_or_null("Label2") as Label

		var index = i - 1
		if index < weaponMaterialsActive.size():
			var mat_data: Dictionary = weaponMaterialsActive[index]
			var mat_id: String = mat_data.get("id", "")
			var req_amount: int = mat_data.get("amount", 0)
			
			# Nilai kepunyaan player sementara di-set statis ke 0 (karena belum ada sistem inventory)
			var owned_amount: int = 0

			# Format Nama Material (mengubah format "iron_ingot" menjadi "Iron Ingot")
			var mat_name: String = mat_id.replace("_", " ").capitalize()

			if label1_node:
				label1_node.text = mat_name
			if label2_node:
				label2_node.text = str(owned_amount) + " / " + str(req_amount)

			# Atur ikon material jika path icon ada di database/resource
			var icon_path: String = "res://assets/art/items/materials/" + mat_id + ".png"
			if icon_node:
				if ResourceLoader.exists(icon_path):
					_apply_icon_to_button(icon_node, icon_path)
				else:
					_clear_icon_button(icon_node)
		else:
			# Kosongkan elemen jika slot material tidak digunakan
			if label1_node:
				label1_node.text = ""
			if label2_node:
				label2_node.text = ""
			if icon_node:
				_clear_icon_button(icon_node)

func _clear_icon_button(icon_node: Node) -> void:
	if icon_node is TextureButton:
		icon_node.texture_normal = null
	elif icon_node is Button:
		icon_node.icon = null

func _switch_tab(active_btn: Button) -> void:
	if active_btn == null:
		return
	
	current_active_btn = active_btn
	
	for btn in tabs:
		var is_active: bool = (btn == active_btn)
		
		# 1. Atur visibilitas tab
		if tabs[btn] != null:
			tabs[btn].visible = is_active
			
			if is_active:
				print_rich("[color=green][TAB ACTIVE][/color] Tab yang muncul: [b]" + tabs[btn].name + "[/b]")
				
				if tabs[btn].name == "weaponTab":
					_play_weapon_selection_intro()
					_play_weapon_status_anim()
					
					# --- LOGIKA WEAPON GRID OTOMATIS (4 KOLOM) ---
					var weapon_grid: Control = $weaponTab/weaponSelection/weaponGrid
					
					if weapon_grid and weapon_grid.get_child_count() > 0:
						var master_weapon = weapon_grid.get_child(0) as BaseButton
						
						# Mengambil daftar senjata langsung dari kelas database static
						var database_senjata: Array[Dictionary] = WeaponDatabase.get_all_weapons()
						var weapon_count = database_senjata.size()
						
						if weapon_count == 0:
							return

						var base_x = master_weapon.position.x
						var base_y = master_weapon.position.y
						
						var jarak_x = 50.0
						var jarak_y = 50.0
						
						current_active_weapon_slot = null
						
						master_weapon.toggle_mode = true
						master_weapon.button_pressed = true
						current_active_weapon_slot = master_weapon
						
						# Menyimpan ID unik senjata ke metadata slot
						master_weapon.set_meta("weapon_id", database_senjata[0].get("id", ""))
						
						master_weapon.custom_minimum_size = Vector2(64, 64)
						master_weapon.size = Vector2(64, 64)
						
						_apply_icon_to_button(master_weapon, database_senjata[0].get("icon", ""))
						
						if master_weapon.pressed.is_connected(_on_weapon_slot_clicked):
							master_weapon.pressed.disconnect(_on_weapon_slot_clicked)
						master_weapon.pressed.connect(func(): _on_weapon_slot_clicked(master_weapon))
						
						for i in range(weapon_grid.get_child_count() - 1, 0, -1):
							weapon_grid.get_child(i).queue_free()
						
						master_weapon.position = Vector2(base_x, base_y)
						
						for i in range(1, weapon_count):
							var new_weapon = master_weapon.duplicate() as BaseButton
							weapon_grid.add_child(new_weapon)
							
							var weapon_data = database_senjata[i]
							new_weapon.name = "WeaponSlot_" + str(i)
							new_weapon.set_meta("weapon_id", weapon_data.get("id", ""))
							
							new_weapon.custom_minimum_size = Vector2(64, 64)
							new_weapon.size = Vector2(64, 64)
							new_weapon.button_pressed = false
							
							_apply_icon_to_button(new_weapon, weapon_data.get("icon", ""))
							new_weapon.pressed.connect(func(): _on_weapon_slot_clicked(new_weapon))
							
							var kolom = i % 4
							var baris = i / 4
							
							var posisi_baru_x = base_x + (kolom * jarak_x)
							var posisi_baru_y = base_y + (baris * jarak_y)
							
							new_weapon.position = Vector2(posisi_baru_x, posisi_baru_y)
							
						if database_senjata.size() > 0:
							weaponTitleActive = database_senjata[0].get("name", "")
							weaponDescActive = database_senjata[0].get("description", "")
							weaponIconActive = database_senjata[0].get("icon", "")
							weaponStatsActive = database_senjata[0].get("stats", {})
							weaponMaterialsActive = database_senjata[0].get("materials", [])
							_update_weapon_info()
							
						print_rich("[color=blue][GRID BUILDER][/color] Berhasil menyusun " + str(weapon_count) + " slot senjata.")
					
		else:
			if is_active:
				print_rich("[color=red][ERROR][/color] Tombol [b]" + btn.name + "[/b] ditekan, tapi Node Tab-nya NULL!")
		
		if btn != null:
			btn.disabled = is_active

# --- LOGIKA KETIKA SLOT SENJATA DIKLIK ---
func _on_weapon_slot_clicked(clicked_weapon: BaseButton) -> void:
	if clicked_weapon == current_active_weapon_slot:
		clicked_weapon.button_pressed = true
		return
		
	if current_active_weapon_slot != null:
		current_active_weapon_slot.button_pressed = false
		
	current_active_weapon_slot = clicked_weapon
	current_active_weapon_slot.button_pressed = true
	
	if clicked_weapon.has_meta("weapon_id"):
		var weapon_id: String = clicked_weapon.get_meta("weapon_id")
		
		# Mengambil data senjata secara spesifik via ID dari WeaponDatabase
		var weapon_data: Dictionary = WeaponDatabase.get_weapon_by_id(weapon_id)
		if not weapon_data.is_empty():
			weaponTitleActive = weapon_data.get("name", "")
			weaponDescActive = weapon_data.get("description", "")
			weaponIconActive = weapon_data.get("icon", "")
			weaponStatsActive = weapon_data.get("stats", {})
			weaponMaterialsActive = weapon_data.get("materials", [])
			
			# Picu pembaruan data teks, stats, materials, beserta tekstur gambar display di layar
			_update_weapon_info()
			
			# Picu animasi melebar murni dari bawah ke atas
			_play_weapon_status_anim()
			
			print_rich("[color=yellow][WEAPON SELECTED][/color] Berpindah ke: [b]" + weaponTitleActive + "[/b] (ID: " + weapon_id + ")")

# --- FUNGSI BANTUAN UNTUK MEMASANG IKON SECARA DINAMIS ---
func _apply_icon_to_button(button_node: Node, path_icon: String) -> void:
	if not ResourceLoader.exists(path_icon):
		print_rich("[color=red][ICON ERROR][/color] Gambar tidak ditemukan di path: " + path_icon)
		_clear_icon_button(button_node)
		return
		
	var gambar_texture = load(path_icon)
	
	if button_node is TextureButton:
		button_node.texture_normal = gambar_texture
	elif button_node is Button:
		button_node.icon = gambar_texture

# Animasi pergerakan/slide weaponSelection
func _play_weapon_selection_intro() -> void:
	if weapon_selection == null:
		return

	var offset_y: float = 100.0
	weapon_selection.position.y = weapon_selection_origin_y + offset_y
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CIRC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(weapon_selection, "position:y", weapon_selection_origin_y, 0.4)

# Animasi weaponStatus (Melebar murni dari bawah ke atas)
func _play_weapon_status_anim() -> void:
	if weapon_status == null:
		return

	if status_tween and status_tween.is_running():
		status_tween.kill()

	# 1. Pastikan posisi Y tetap mengunci di posisi aslinya
	weapon_status.position.y = weapon_status_origin_y
	
	# 2. Update ulang pivot offset ke bagian tengah bawah node
	weapon_status.pivot_offset = Vector2(weapon_status.size.x / 2.0, weapon_status.size.y)

	# 3. Set skala awal Y ke 0 (kuncup/kempes di bawah)
	weapon_status.scale = Vector2(1.0, 0.0)

	# 4. Animasikan skala Y tumbuh dari 0 ke 1 dengan efek bounce
	status_tween = create_tween()
	status_tween.tween_property(weapon_status, "scale", Vector2(1.0, 1.0), 0.3)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

# Animasi Pop-Up Smooth pada Ikon Display Senjata
func _play_weapon_icon_pop_anim() -> void:
	if weapon_display_texture == null:
		return

	if icon_tween and icon_tween.is_running():
		icon_tween.kill()

	# Set pivot di titik tengah ikon agar membesar tepat di pusatnya
	weapon_display_texture.pivot_offset = weapon_display_texture.size / 2.0

	# Skala awal (dimulai dari mengecil)
	weapon_display_texture.scale = Vector2(0.3, 0.3)

	# Tween pop up dengan efek kenyal/bounce halus
	icon_tween = create_tween()
	icon_tween.tween_property(weapon_display_texture, "scale", Vector2.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

# Animasi Counting Angka Menggunakan tween_method (Smooth per-Frame)
func _animate_status_values() -> void:
	if count_tween and count_tween.is_running():
		count_tween.kill()

	var target_damage: float = float(weaponStatsActive.get("damage", 0))
	var target_critical: float = float(weaponStatsActive.get("critical", 0))
	var target_hitrate: float = float(weaponStatsActive.get("hit_rate", 0))

	var start_damage: float = last_damage
	var start_critical: float = last_critical
	var start_hitrate: float = last_hitrate

	count_tween = create_tween().set_parallel(true)
	count_tween.set_trans(Tween.TRANS_CUBIC)
	count_tween.set_ease(Tween.EASE_OUT)

	# 1. Animasikan Damage Label per-frame
	if damage_label:
		count_tween.tween_method(
			func(val: float):
				damage_label.text = str(roundi(val)),
			start_damage,
			target_damage,
			0.45
		)

	# 2. Animasikan Critical Label per-frame
	if critical_label:
		count_tween.tween_method(
			func(val: float):
				critical_label.text = str(roundi(val)),
			start_critical,
			target_critical,
			0.45
		)

	# 3. Animasikan Hit Rate Label per-frame
	if hitrate_label:
		count_tween.tween_method(
			func(val: float):
				hitrate_label.text = str(roundi(val)),
			start_hitrate,
			target_hitrate,
			0.45
		)

	# Simpan stat terakhir sebagai titik start untuk pergantian senjata berikutnya
	last_damage = target_damage
	last_critical = target_critical
	last_hitrate = target_hitrate
