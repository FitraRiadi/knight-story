extends Button

# Get Popup 
@onready var popupCreateCharacter = $"../../../../createCharacterPopup"


func _pressed():
	print('Play game')
	popupCreateCharacter.visible = true 
	
	
