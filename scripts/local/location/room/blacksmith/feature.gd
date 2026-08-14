extends Control

@onready var tabs: Dictionary = {
	$mainTab/weaponBtn: get_node_or_null("weaponTab"),
	$mainTab/armorBtn: get_node_or_null("armorTab"),
	$mainTab/toolBtn: get_node_or_null("toolTab"),
	$mainTab/ringBtn: get_node_or_null("ringTab"),
	$mainTab/questBtn: get_node_or_null("questTab")
}

var current_active_btn: Button = null

# Variabel Statis Data Senjata
var weaponTitleActive: String = "Iron Sword"
var weaponDescActive: String = "A sturdy sword forged from refined iron. Reliable and effective for close combat."

# Reference Node dari Scene Tree
@onready var weapon_selection: Control = get_node_or_null("weaponTab/weaponSelection")
@onready var weapon_title_label: Label = get_node_or_null("weaponTab/weaponTitle")
@onready var weapon_desc_label: Label = get_node_or_null("weaponTab/weaponDesc")

var weapon_selection_origin_y: float = 0.0

func _ready() -> void:
	# Catat posisi asli Y weaponSelection
	if weapon_selection:
		weapon_selection_origin_y = weapon_selection.position.y

	# Set teks awal dari variabel statis
	_update_weapon_info()

	for btn in tabs.keys():
		if btn:
			btn.pressed.connect(func(): _switch_tab(btn))
	
	# Set tab default saat start
	_switch_tab($mainTab/weaponBtn)

func _update_weapon_info() -> void:
	if weapon_title_label:
		weapon_title_label.text = weaponTitleActive
	if weapon_desc_label:
		weapon_desc_label.text = weaponDescActive

func _switch_tab(active_btn: Button) -> void:
	if active_btn == null:
		return
	
	current_active_btn = active_btn
	
	for btn in tabs:
		var is_active: bool = (btn == active_btn)
		
		# 1. Atur visibilitas tab
		if tabs[btn] != null:
			tabs[btn].visible = is_active
			
			# LOG: Print info tab mana yang baru saja diaktifkan/dimunculkan
			if is_active:
				print_rich("[color=green][TAB ACTIVE][/color] Tab yang muncul: [b]" + tabs[btn].name + "[/b] (Tombol: " + btn.name + ")")
				
				if tabs[btn].name == "weaponTab":
					_play_weapon_selection_intro()
					
		else:
			# LOG PERINGATAN: Jika ternyata node tab-nya null
			if is_active:
				print_rich("[color=red][ERROR][/color] Tombol [b]" + btn.name + "[/b] ditekan, tapi Node Tab-nya NULL!")
		
		# 2. Bikin tombol yang aktif jadi 'disabled'
		if btn != null:
			btn.disabled = is_active

# Animasi pergerakan/slide weaponSelection
func _play_weapon_selection_intro() -> void:
	if weapon_selection == null:
		print_rich("[color=red][ERROR][/color] Node 'weaponSelection' tidak ditemukan di dalam 'weaponTab'!")
		return

	var offset_y: float = 100.0
	weapon_selection.position.y = weapon_selection_origin_y + offset_y
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CIRC)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(
		weapon_selection,
		"position:y",
		weapon_selection_origin_y,
		0.4
	)
