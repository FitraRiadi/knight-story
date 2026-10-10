extends Control

@onready var bg: TextureRect = $bg
@onready var dialog_label: Label = $dialog

func _ready() -> void:
	# 0. FADE IN — mulus dari prologue 1 (yang fade out)
	modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_CIRC)

	# 1. WALK — bg zoom pelan (kesan jalan, first-person)
	bg.pivot_offset = bg.size / 2
	var walk := create_tween()
	walk.tween_property(bg, "scale", Vector2(1.08, 1.08), 10.0).set_trans(Tween.TRANS_SINE)

	# 2. DIALOG — kontrak sama kayak prolugue_dialog.gd
	var dialogs = [
		["The nearest village... it has to be close.", 3.0],
		["These woods swallow every sound.", 3.0],
		["Then something moved behind the trees.", 2.5],
	]
	var tw = TypewriterPlayers.new()
	add_child(tw)
	tw.setup(dialog_label, dialogs, 0.03, 0.5, false, "|", false)
	tw.finished.connect(_on_dialog_done)
	tw.play()

func _on_dialog_done(_label) -> void:
	# 3. AMBUSH — via komponen reusable, lalu masuk battle tutorial.
	# Layar sudah full hitam pas finished (leave_dark) -> cut invisible
	# via change_scene, tanpa curtain. Tutorial fade-in dari hitam.
	var ambush := AmbushPlayer.new()
	add_child(ambush)
	ambush.play({
		"root": self,
		"bg": bg,
		"warning_text": "Something moved behind the trees.",
		"leave_dark": true,
	})
	await ambush.finished
	ambush.queue_free()
	get_tree().change_scene_to_file("res://scenes/battle/battle_gameplay_tutorial.tscn")
