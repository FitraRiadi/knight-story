extends Control

# Path ke file scene quest menu
const QUEST_MENU_SCENE: PackedScene = preload("res://scenes/gui/popup/quest/quest_menu.tscn")

# Ambil referensi node dari scene tree lotus_village
@onready var go_black_smith: Button = $bg/goBlackSmith
@onready var go_quest_board: Button = $bg/goQuestBoard
@onready var go_tavern: Button = $bg/goTavern
@onready var go_home: Button = $bg/goHome
@onready var go_colloseum: Button = $bg/goColloseum
@onready var hud: Control = $"gui-player-base"

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

	# Home + Colloseum selalu hidden sampai di-wire (tombol mati).
	if go_home:
		go_home.visible = false
	if go_colloseum:
		go_colloseum.visible = false

	# Reveal building bertahap: pengenalan (tavern) dulu, sisanya
	# kebuka habis masuk tavern sekali.
	var first_visit := not PlayerDataManager.has_visited("lotus_village")
	var tavern_done := PlayerDataManager.has_visited("lotus_village_tavern")
	print("[Lotus] ready — first_visit=", first_visit, " tavern_done=", tavern_done)
	if first_visit:
		_hide_building(go_black_smith)
		_hide_building(go_quest_board)
		_hide_building(go_tavern)
		# HUD (map, journey, dll) juga sembunyi selama arrival.
		if hud:
			hud.visible = false
		# Arrival sinematik (cuma kunjungan pertama)
		_play_arrival()
	else:
		_show_building_instant(go_tavern)
		if tavern_done:
			print("[Lotus] return + tavern done — reveal rest")
			_reveal_rest()

# ============================================================
# REVEAL BUILDING (stagger pop: fade + slide-up)
# ============================================================

func _hide_building(btn: Button) -> void:
	if btn == null:
		return
	btn.visible = false
	btn.modulate.a = 0.0

func _show_building_instant(btn: Button) -> void:
	if btn == null:
		return
	btn.visible = true
	btn.modulate.a = 1.0

func _pop_building(btn: Button, delay: float = 0.0) -> void:
	if btn == null:
		return
	btn.visible = true
	btn.modulate.a = 0.0
	var base_y: float = btn.position.y
	btn.position.y = base_y + 20.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(btn, "modulate:a", 1.0, 0.4).set_delay(delay).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "position:y", base_y, 0.4).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _reveal_tavern() -> void:
	_pop_building(go_tavern)

func _reveal_rest() -> void:
	_pop_building(go_black_smith, 0.0)
	_pop_building(go_quest_board, 0.3)

# ============================================================
# ARRIVAL (kunjungan pertama): walk-in + teks, lalu bebas explore
# ============================================================

const ARRIVAL_FONT := "res://assets/ui/fonts/Jersey15-Regular.ttf"

func _play_arrival() -> void:
	print("[Lotus] arrival start")
	# Blocker input selama sinematik (tombol lokasi jangan bisa diklik).
	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)
	# Dialog di atas blocker.
	var dialog_label := Label.new()
	dialog_label.position = Vector2(40, 240)
	dialog_label.size = Vector2(660, 80)
	dialog_label.add_theme_font_size_override("font_size", 18)
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if ResourceLoader.exists(ARRIVAL_FONT):
		dialog_label.add_theme_font_override("font", load(ARRIVAL_FONT) as Font)
	add_child(dialog_label)

	# Walk-in: bg zoom pelan (first-person masuk desa).
	var bg_node := $bg as TextureRect
	if bg_node != null:
		bg_node.pivot_offset = bg_node.size / 2
		var walk := create_tween()
		walk.tween_property(bg_node, "scale", bg_node.scale * 1.08, 10.0).set_trans(Tween.TRANS_SINE)

	var dialogs = [
		["The village he sought.", 3.0],
		["Lotus Village.", 3.0],
		["Smoke rose from chimneys. Behind him, the forest kept its silence.", 3.5],
	]
	var tw = TypewriterPlayers.new()
	add_child(tw)
	tw.setup(dialog_label, dialogs, 0.03, 0.5, false, "|", false)
	tw.finished.connect(_on_arrival_done.bind(blocker, dialog_label))
	tw.play()

func _on_arrival_done(_label, blocker: Control, dialog_label: Label) -> void:
	print("[Lotus] arrival done — reveal tavern + HUD")
	PlayerDataManager.mark_visited("lotus_village")
	if is_instance_valid(blocker):
		blocker.queue_free()
	if is_instance_valid(dialog_label):
		dialog_label.queue_free()
	# Reveal batch pengenalan: tavern dulu.
	_reveal_tavern()
	# HUD (map, journey, dll) fade-in bareng.
	if hud:
		hud.visible = true
		hud.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(hud, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)

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
	# Flag visit: buka reveal batch berikutnya pas balik ke lotus.
	PlayerDataManager.mark_visited("lotus_village_tavern")
	TransitionManager.pindah_scene_with_zoom("res://scenes/locations/room/tavern/tavern.tscn", go_tavern)
