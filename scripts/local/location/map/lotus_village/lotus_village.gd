extends Control

# Path ke file scene quest menu
const QUEST_MENU_SCENE: PackedScene = preload("res://scenes/gui/popup/quest/quest_menu.tscn")

# Ambil referensi node dari scene tree lotus_village
@onready var go_black_smith: Button = $bg/goBlackSmith
@onready var go_quest_board: Button = $bg/goQuestBoard
@onready var go_tavern: Button = $bg/goTavern

var active_quest_popup: Node = null

const LOTUS_VILLAGE_BGM = "res://assets/audio/bgm/lotusVillage/lotus_village_bgm.mp3"

func _ready() -> void:
	if go_black_smith:
		go_black_smith.pressed.connect(_on_go_black_smith_pressed)
		
	if go_quest_board:
		go_quest_board.pressed.connect(show_quest_popup)
	
	if go_tavern:
		go_tavern.pressed.connect(_on_go_tavern_pressed)
	
	MusicManager.play_music(LOTUS_VILLAGE_BGM)

# Fungsi untuk memunculkan pop-up Quest Menu (sejajar dengan gui-player-base)
func show_quest_popup() -> void:
	# Cegah pembuatan instansi ganda jika pop-up sudah terbuka
	if active_quest_popup != null and is_instance_valid(active_quest_popup):
		return
		
	# Instantiate scene quest menu
	active_quest_popup = QUEST_MENU_SCENE.instantiate()
	
	# Tambahkan sebagai child dari lotus_village (sejajar dengan gui-player-base & bg)
	add_child(active_quest_popup)

# Fungsi untuk menutup/menghapus pop-up Quest Menu
func hide_quest_popup() -> void:
	if active_quest_popup != null and is_instance_valid(active_quest_popup):
		active_quest_popup.queue_free()
		active_quest_popup = null

# Fungsi yang berjalan otomatis saat tombol goBlackSmith ditekan
func _on_go_black_smith_pressed() -> void:
	TransitionManager.pindah_scene_with_zoom("res://scenes/locations/room/blacksmith/blacksmith.tscn", go_black_smith)

func _on_go_tavern_pressed() -> void:
	TransitionManager.pindah_scene_with_zoom("res://scenes/locations/room/tavern/tavern.tscn", go_tavern)
