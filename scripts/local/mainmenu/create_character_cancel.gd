extends TextureButton

@onready var popup = $"../../../../createCharacterPopup"

func _pressed() -> void:
	popup.popupIntro = false
	popup.visible = false
	
