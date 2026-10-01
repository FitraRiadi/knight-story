extends Control

@onready var bgm = $mainBgm
@onready var menu_option = $bg_scene/MenuOption
@onready var play_button = $bg_scene/MenuOption/PlayButton
@onready var achievment_button = $bg_scene/MenuOption/AchievmentButton
@onready var title = $bg_scene/MenuOption/Title
@onready var create_character_popup = $"../createCharacterPopup"

func _ready() -> void:
	GameSettings.load_settings()
	MusicManager.set_master_volume_linear(GameSettings.get_data().music_volume)
	bgm.play()
	_add_settings_button()
	_play_intro()
	play_button.pressed.connect(_on_play_pressed)


func _add_settings_button() -> void:
	# Duplikat achievement biar style gratis, taruh di bawahnya
	var b := achievment_button.duplicate() as Button
	b.name = "SettingsButton"
	b.text = "Settings"
	b.position = achievment_button.position + Vector2(0, 61)
	menu_option.add_child(b)
	b.pressed.connect(_on_settings_pressed)


func _on_settings_pressed() -> void:
	SettingsPopup.open(self)

func _play_intro() -> void:
	title.modulate.a = 0
	play_button.position.x -= 100
	achievment_button.position.x += 100

	var tween = create_tween().set_parallel(true)
	tween.tween_property(title, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_CIRC)
	tween.tween_property(play_button, "position:x", play_button.position.x + 100, 0.5).set_trans(Tween.TRANS_CIRC)
	tween.tween_property(achievment_button, "position:x", achievment_button.position.x - 100, 0.5).set_trans(Tween.TRANS_CIRC)

func _on_play_pressed() -> void:
	print('Play game')
	create_character_popup.visible = true
