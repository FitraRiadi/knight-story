extends Label

@onready var dialogContainer: Control = $".."

func _ready():
	dialogContainer.position.y += 100

	# Animasi slide up dialog container
	var intro_tween = create_tween()
	intro_tween.tween_property(dialogContainer, "position:y", dialogContainer.position.y - 100, 1.0).set_trans(Tween.TRANS_CIRC)

	var dialogs = [
		["Welcome to my tavern, Knight!", 2.5],
		["I've got potions for sale, and games to test your luck.", 3.0],
		["Take a look around, won't you?", 2.5]
	]

	var tw = TypewriterPlayers.new()
	add_child(tw)

	tw.setup(
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
	tw.play()
	tw.finished.connect(_on_done)

func _on_done(_label):
	# Animasi slide down tutup dialog
	var closing = create_tween()
	closing.tween_property(dialogContainer, "position:y", dialogContainer.position.y + 100, 1.0).set_trans(Tween.TRANS_CIRC)
