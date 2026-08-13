extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	text = ""
	#showInformation("Name must 8 character!")

func showInformation(textInfo):
	text = textInfo
	modulate.a = 0
	create_tween().tween_property(self,"modulate:a",1,0.5)
