extends Control

@onready var bgm = $mainBgm
@onready var menu_option = $bg_scene/MenuOption
@onready var play_button = $bg_scene/MenuOption/PlayButton
@onready var achievment_button = $bg_scene/MenuOption/AchievmentButton
@onready var title = $bg_scene/MenuOption/Title
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
	# Fade out UI menu (bg sama kayak prologue 1, jadi mulus tanpa curtain)
	play_button.disabled = true
	achievment_button.disabled = true
	var fade := create_tween()
	fade.tween_property(menu_option, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_CIRC)
	await fade.finished
	get_tree().change_scene_to_file("res://scenes/cutscene/scene_prologue.tscn")
