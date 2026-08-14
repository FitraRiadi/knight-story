extends Label

@onready var dialogContainer: Control = $".."
@onready var feature: Control = $"../../feature"

func _ready():
	dialogContainer.position.y += 100
	feature.position.x -= 800
	
	# 1. Simpan tween ke variabel
	var intro_tween = create_tween()
	intro_tween.tween_property(dialogContainer, "position:y", dialogContainer.position.y - 100, 1.0).set_trans(Tween.TRANS_CIRC)
	
	var dialogs = [
		["Welcome Friend.", 3.0],
		["I Can help you with some weapon and armor here.", 3.0]
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
	
	# 2. Tunggu sampai animasi intro selesai
	await intro_tween.finished
	
	# 3. Baru jalankan dialog
	tw.play()
	tw.finished.connect(_on_done)

func _on_done(_label):
	var closing = create_tween()
	closing.tween_property(dialogContainer, "position:y", dialogContainer.position.y + 100, 1.0).set_trans(Tween.TRANS_CIRC)
	await closing.finished
	print("Popup Weapon Muncul")
	create_tween().tween_property(feature,"position:x",feature.position.x + 800,0.5).set_trans(Tween.TRANS_CIRC)
	
