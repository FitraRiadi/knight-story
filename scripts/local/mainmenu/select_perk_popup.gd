extends Control

var popupIntro = false

func _process(_delta: float) -> void:
	if self.visible and popupIntro == false:
		_popupIntro()
	
	
		
func _popupIntro():
	modulate.a = 0
	position.y -= 50
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self,"modulate:a",1,0.5).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self,"position:y",position.y + 50, 1).set_trans(Tween.TRANS_CIRC)
	popupIntro = true
	
