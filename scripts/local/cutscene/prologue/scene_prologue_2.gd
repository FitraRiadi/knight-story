extends Control

@onready var bg: TextureRect = $bg
@onready var dialog_label: Label = $dialog
@onready var flash: ColorRect = $flash

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
	# 3. AMBUSH — flash + shake, lalu masuk battle tutorial
	flash.visible = true
	var ambush := create_tween().set_parallel(true)
	ambush.tween_property(flash, "color:a", 1.0, 0.15)
	ambush.tween_property(bg, "position:x", bg.position.x + 12.0, 0.08)
	ambush.tween_property(bg, "position:x", bg.position.x - 12.0, 0.08).set_delay(0.08)
	await ambush.finished
	TransitionManager.pindah_scene(
		"res://scenes/battle/battle_gameplay_tutorial.tscn", "Ambush")
