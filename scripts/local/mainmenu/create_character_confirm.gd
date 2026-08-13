extends TextureButton


@onready var popup = $"../../../../confirmPopup"


# Information handle
@onready var information = $"../../information"


# Get Input 
@onready var characterName = $"../../nameColumn/input"
@onready var perkChoice = $"../../perkColumn/perkLabel"
var createCharacter = {}

func _pressed() -> void:	
	# Check Form
	
	print(perkChoice.text)
	print(characterName.text)
	if perkChoice.text == "NONE":
		information.showInformation("Perk Must choice")
		return
	
	if len(characterName.text) < 3:
		information.showInformation("Name to short!")
		return
		
	if len(characterName.text) > 12:
		information.showInformation("Name to long!")
		return
	
	information.showInformation("")
		
	popup.visible = true
	popup.intro()
	
		
	
	
	
