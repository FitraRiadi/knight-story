extends Panel

func _ready() -> void:
	size.x = 0.0
	create_tween().tween_property(self,'size:x',470.0,1)
