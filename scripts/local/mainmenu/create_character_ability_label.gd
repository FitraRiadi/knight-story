extends Label

@onready var perkCurrent = "NONE"

func _process(_delta: float) -> void:
	text = perkCurrent
	if perkCurrent != "NONE": 
		modulate = Color.GREEN_YELLOW
		modulate.a = 1
	else:
		modulate.a = 0.5
		
	#print(text)
