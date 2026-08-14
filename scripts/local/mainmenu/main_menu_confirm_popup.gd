extends Control

@onready var create_character_popup = $"../createCharacterPopup"
@onready var menu_ui = $"../menu/bg_scene/MenuOption"

var on_create := false

func _ready() -> void:
	$bg/yes.pressed.connect(_on_yes_pressed)
	$bg/no.pressed.connect(_on_no_pressed)

func _process(_delta: float) -> void:
	if on_create and menu_ui.modulate.a == 0:
		get_tree().change_scene_to_file("res://scenes/cutscene/scene_prologue.tscn")

func intro() -> void:
	modulate.a = 0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CIRC)

func _on_yes_pressed() -> void:
	visible = false
	print('Letsgo')
	on_create = true
	create_character_popup.visible = false
	create_tween().tween_property(menu_ui, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_CIRC)
	create_tween().tween_property(menu_ui, "position:y", menu_ui.position.y - 500, 0.5).set_trans(Tween.TRANS_CIRC)

func _on_no_pressed() -> void:
	visible = false