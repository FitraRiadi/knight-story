extends Control


@onready var perkPopup = $"../selectPerkPopup"

func _process(_delta: float) -> void:

	# Intro 
	if self.visible and popupIntro == false and popupHide == false:
		_popupIntro()
		
	# Hide
	if perkPopup.visible and popupHide == false:
		popupHide = true
		create_tween().tween_property(self,'position:x',position.x - 500, 0.5).set_trans(Tween.TRANS_CIRC)
	

		
var popupHide = false 
var popupIntro = false
func _popupIntro():
	modulate.a = 0
	create_tween().tween_property(self,"modulate:a",1,0.5).set_trans(Tween.TRANS_CUBIC)
	popupIntro = true
	

func _popupRestore():
	create_tween().tween_property(self,'position:x',position.x + 500, 0.5).set_trans(Tween.TRANS_CIRC)
	
