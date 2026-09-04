extends Label

@onready var dialogContainer: Control = $".."
@onready var tavern: Control = $"../../../"

var _tw_instance = null
var _original_y: float = 0.0


func _ready():
	_original_y = dialogContainer.position.y
	dialogContainer.visible = false


func start() -> void:
	# Reset posisi ke awal
	dialogContainer.position.y = _original_y + 100
	dialogContainer.visible = true

	# Animasi slide up dialog container
	var intro_tween = create_tween()
	intro_tween.tween_property(dialogContainer, "position:y", _original_y, 1.0).set_trans(Tween.TRANS_CIRC)

	# Bersihkan typewriter lama
	if _tw_instance and is_instance_valid(_tw_instance):
		_tw_instance.queue_free()

	var dialogs = [
		["Welcome to my tavern, Knight!", 2.5],
		["I've got potions for sale, and games to test your luck.", 3.0],
		["Take a look around, won't you?", 2.5]
	]

	_tw_instance = TypewriterPlayers.new()
	add_child(_tw_instance)

	_tw_instance.setup(
		self,
		dialogs,
		0.03,
		0.5,
		true,
		"|",
		false
	)

	# Tunggu animasi intro selesai
	await intro_tween.finished

	# Jalankan dialog
	_tw_instance.play()
	_tw_instance.finished.connect(_on_done)


func _on_done(_label):
	# Animasi slide down tutup dialog
	var closing = create_tween()
	closing.tween_property(dialogContainer, "position:y", _original_y + 100, 1.0).set_trans(Tween.TRANS_CIRC)
	await closing.finished

	dialogContainer.visible = false

	# Munculkan feature panel dari kiri
	tavern._show_feature_slide_in()
