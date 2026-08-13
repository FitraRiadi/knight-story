extends Button

@onready var chapterText = $"../../chapterInit"
@onready var choosePath = $"../../choosePath"
var press = false
func _pressed() -> void:
	if press != true:
		press = true
		create_tween().tween_property(chapterText,"modulate:a",0,1).set_trans(Tween.TRANS_CIRC)
		choosePath.visible = true
		choosePath.modulate.a = 0
		create_tween().tween_property(choosePath,"modulate:a",1,1).set_trans(Tween.TRANS_CIRC)
		
