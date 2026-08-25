extends Label

@onready var dialogContainer: Control = $".."

func _ready():
	dialogContainer.position.y += 100
	
	# 1. Simpan tween ke variabel
	var intro_tween = create_tween()
	intro_tween.tween_property(dialogContainer, "position:y", dialogContainer.position.y - 100, 1.0).set_trans(Tween.TRANS_CIRC)
	
	var dialogs = [
		["Ho Hi Ho.", 3.0],
		["What Do You Want Knight??.", 3.0]
	]

	var tw23 = TypewriterPlayers.new()
	add_child(tw23)

	tw23.setup(
		self,
		dialogs,
		0.03,
		0.5,
		true,   
		"|",
		false
	)
	
	# 2. Tunggu sampai animasi intro selesai
	await intro_tween.finished
	
	# 3. Baru jalankan dialog
	tw23.play()
	tw23.finished.connect(_on_done)

func _on_done(_label):
	var closing = create_tween()
	closing.tween_property(dialogContainer, "position:y", dialogContainer.position.y + 100, 1.0).set_trans(Tween.TRANS_CIRC)
	print("Popup Weapon Muncul")
	
