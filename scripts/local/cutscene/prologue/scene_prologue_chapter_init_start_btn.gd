extends Button

@onready var fade_root := $"../../.."
var press := false

func _pressed() -> void:
	if press:
		return
	press = true
	disabled = true
	# Fade out seluruh scene (campfire + UI), tanpa curtain
	var tw := create_tween()
	tw.tween_property(fade_root, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_CIRC)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/cutscene/scene_prologue_2.tscn")
