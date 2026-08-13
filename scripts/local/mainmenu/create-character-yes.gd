extends Button
@onready var popupCreateCharacter = $"../../../createCharacterPopup"
@onready var menuUI = $"../../../menu/bg_scene/MenuOption"
@onready var onCreate = false
func _pressed() -> void:
	get_parent().get_parent().visible = false
	print('Letsgo')
	onCreate = true
	popupCreateCharacter.visible = false
	create_tween().tween_property(menuUI,"modulate:a",0,0.3).set_trans(Tween.TRANS_CIRC)
	create_tween().tween_property(menuUI,"position:y",menuUI.position.y - 500,0.5).set_trans(Tween.TRANS_CIRC)

func _process(_delta: float) -> void:
	if onCreate and menuUI.modulate.a == 0:
		get_tree().change_scene_to_file("res://scenes/cutscene/scene_prologue.tscn")
	
	
	
