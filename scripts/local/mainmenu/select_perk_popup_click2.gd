extends TextureButton

# Send to label
@onready var perkLabel = $"../../../createCharacterPopup/bgPopup/perkColumn/perkLabel"

@onready var popup = $"../../../createCharacterPopup"

func _pressed() -> void:
	print('PERK 2')
	perkLabel.perkCurrent = "Blade Mastery"
	popup._popupRestore()
	popup.popupHide = false
	var parent = get_parent().get_parent()
	parent.visible = false
	parent.popupIntro = false
