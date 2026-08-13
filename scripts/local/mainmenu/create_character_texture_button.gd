extends TextureButton

# get Popup
@onready var popup = $"../../../../selectPerkPopup"

func _pressed():
	popup.visible = true
	print('PERK')
