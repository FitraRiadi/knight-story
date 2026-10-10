extends Control

@onready var bgm = $mainBgm
@onready var menu_option = $bg_scene/MenuOption
@onready var play_button = $bg_scene/MenuOption/PlayButton
@onready var achievment_button = $bg_scene/MenuOption/AchievmentButton
@onready var title = $bg_scene/MenuOption/Title
@onready var info_label = $bg_scene/information
@onready var campfire = $bg_scene/AnimatedSprite2D
@onready var prologue_ui = $bg_scene/prologueUI
@onready var prologue_dialog = $bg_scene/prologueUI/dialog
@onready var create_character_popup = $"../createCharacterPopup"

func _ready() -> void:
	# Load + apply volume udah diurus MusicManager._ready sendiri.
	# Routing play_music tetep di sini biar jelas scene apa muter apa.
	var music_path := ""
	if bgm and bgm.stream:
		music_path = bgm.stream.resource_path
		bgm.stop()
		bgm.queue_free()
	if music_path != "":
		MusicManager.play_music(music_path)
	_play_intro()
	play_button.pressed.connect(_on_play_pressed)


func _play_intro() -> void:
	title.modulate.a = 0
	play_button.position.x -= 100
	achievment_button.position.x += 100

	var tween = create_tween().set_parallel(true)
	tween.tween_property(title, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_CIRC)
	tween.tween_property(play_button, "position:x", play_button.position.x + 100, 0.5).set_trans(Tween.TRANS_CIRC)
	tween.tween_property(achievment_button, "position:x", achievment_button.position.x - 100, 0.5).set_trans(Tween.TRANS_CIRC)

func _on_play_pressed() -> void:
	# New Game = start fresh (reset save biar arrival/flag ngulang dari nol).
	PlayerDataManager.reset_data()
	create_character_popup.visible = true

func start_prologue_phase() -> void:
	menu_option.visible = false
	# Sinematik (dulu di Play, pindah ke sini biar confirm path ikut):
	# fade info + zoom campfire pelan, jalan bareng prologue fade-in.
	var cin := create_tween().set_parallel(true)
	cin.tween_property(info_label, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_CIRC)
	if campfire != null:
		cin.tween_property(campfire, "scale", campfire.scale * 1.08, 2.5).set_trans(Tween.TRANS_SINE)
	# Fase PROLOGUE mulai (kosongin dialog dulu biar placeholder nggak kecolongan)
	prologue_dialog.text = ""
	prologue_ui.visible = true
	prologue_ui.modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(prologue_ui, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CIRC)
	await fade_in.finished
	prologue_dialog.start_prologue()
