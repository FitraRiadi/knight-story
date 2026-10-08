extends Button

@onready var chapter_text := $"../../chapterInit"
var press := false

func _pressed() -> void:
	if press:
		return
	press = true
	var tw := create_tween()
	tw.tween_property(chapter_text, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_CIRC)
	await tw.finished
	TransitionManager.pindah_scene("res://scenes/cutscene/scene_prologue_2.tscn", "Chapter 1")
