extends Control


func _ready() -> void:
	
	
	# Animate Fade-in 
	$Title.modulate.a = 0 
	$PlayButton.position.x -= 100
	$AchievmentButton.position.x += 100
	
	# Transform
	var tween = create_tween().set_parallel(true)
	tween.tween_property($Title,"modulate:a",1,1)
	tween.tween_property($PlayButton,"position:x",$PlayButton.position.x + 100,0.5).set_trans(Tween.TRANS_CIRC)
	tween.tween_property($AchievmentButton,"position:x",$AchievmentButton.position.x - 100,0.5).set_trans(Tween.TRANS_CIRC)
