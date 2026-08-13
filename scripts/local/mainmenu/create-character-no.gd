extends Button

func _pressed() -> void:
	get_parent().get_parent().visible = false
