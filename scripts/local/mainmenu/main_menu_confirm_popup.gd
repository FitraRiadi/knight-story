extends Control


func intro():
	modulate.a = 0
	create_tween().tween_property(self,"modulate:a",1,0.5).set_trans(Tween.TRANS_CIRC)
