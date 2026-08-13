extends Node2D


func _ready() -> void:
	zoom_in_smooth()
	
func zoom_in_smooth():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
