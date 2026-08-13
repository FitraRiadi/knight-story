extends Label

func _ready():
	var dialogs = [
		["Long time ago...", 3.0],
		["A lone knight sits by a quiet flame.", 3.0],
		["His armor worn... his eyes lost in thought.", 3.5],
		["The night listens... but he says nothing.", 3.5],
	]

	var tw = TypewriterPlayers.new()
	add_child(tw)

	tw.setup(
		self,
		dialogs,
		0.03,
		0.5,
		false,   
		"|",
		false
	)

	tw.finished.connect(_on_done)
	tw.play()


@onready var chapterInit = $"../chapterInit/title"
@onready var chapterBtn = $"../chapterInit/startBtn"
func _on_done(_label):
	print("SELESAI 🔥")
	chapterInit.visible = true
	
	var dialogs2 = [
		["Knight Story Chapter 1",1.0]
	]

	var tw2 = TypewriterPlayers.new()
	add_child(tw2)

	tw2.setup(
		chapterInit,
		dialogs2,
		0.03,
		0.5,
		false,   
		"|",
		true
	)

	tw2.finished.connect(_on_done2)
	tw2.play()
	
	
	
func _on_done2(_label):
	print('DONE 2')
	chapterBtn.visible = true
	chapterBtn.modulate.a = 0
	create_tween().tween_property(chapterBtn, "modulate:a",1,1)
	

	
