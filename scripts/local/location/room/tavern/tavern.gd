extends Control
@onready var exit: Button = $feature/exit


func _ready() -> void:
	exit.pressed.connect(_on_exit_tavern)
	

func _on_exit_tavern():
	TransitionManager.pindah_scene("res://scenes/locations/maps/lotus_village/lotus_village.tscn")
