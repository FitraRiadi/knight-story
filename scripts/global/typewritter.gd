extends Node

signal dialogue_finished

# =========================
# 🔥 CORE STATE
# =========================
var label = null
var dialogs = []
var use_click = true
var active = false

# =========================
# 🎬 EFFECT PARAM
# =========================
var fade_in_time = 0.3
var fade_out_time = 0.3
var ease_type = Tween.EASE_IN_OUT
var trans_type = Tween.TRANS_CUBIC

# =========================
# ✨ CURSOR PARAM
# =========================
var use_cursor = true
var cursor_char = "|"
var cursor_blink_speed = 0.4

# =========================
# ⚙️ STATE
# =========================
var index = 0
var typing = false
var skip = false

# =========================
# 🔊 AUDIO
# =========================
var audio_player

# =========================
# ✨ CURSOR STATE
# =========================
var cursor_visible = true
var cursor_timer
var current_full_text = ""

# =========================
# 🆕 LAST DIALOG CONTROL
# =========================
var keep_last_visible = false

# =========================
# 🚀 READY
# =========================
func _ready():
	# 🔊 audio
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)

	audio_player.stream = preload("res://assets/audio/effects/writter/writter.mp3")
	audio_player.volume_db = -10

	if audio_player.stream:
		audio_player.stream.loop = true

	# ✨ cursor
	cursor_timer = Timer.new()
	cursor_timer.wait_time = cursor_blink_speed
	cursor_timer.autostart = false
	cursor_timer.one_shot = false
	add_child(cursor_timer)
	cursor_timer.timeout.connect(_on_cursor_blink)

# =========================
# 🚀 PLAY
# =========================
func play(
	_label,
	_dialogs,
	_use_click := true,
	fade_in_duration := 0.3,
	fade_out_duration := 0.3,
	_trans := Tween.TRANS_CUBIC,
	_ease := Tween.EASE_IN_OUT,
	_use_cursor := true,
	_cursor_char := "|",
	_keep_last_visible := false
):
	if _label == null:
		push_error("Typewritter butuh Label!")
		return

	label = _label
	dialogs = _dialogs
	use_click = _use_click

	fade_in_time = fade_in_duration
	fade_out_time = fade_out_duration
	trans_type = _trans
	ease_type = _ease

	use_cursor = _use_cursor
	cursor_char = _cursor_char
	keep_last_visible = _keep_last_visible

	index = 0
	active = true

	cursor_timer.start()
	_next_dialog()

# =========================
# 🛑 STOP
# =========================
func stop():
	if not active:
		return

	active = false
	label = null
	cursor_timer.stop()

	emit_signal("dialogue_finished")

# =========================
# ✨ CURSOR
# =========================
func _on_cursor_blink():
	if not active or not use_cursor or label == null:
		return

	cursor_visible = !cursor_visible
	label.text = _get_display_text(current_full_text)

func _get_display_text(base_text):
	if not use_cursor:
		return base_text

	return base_text + (cursor_char if cursor_visible else "")

# =========================
# 🎬 FADE
# =========================
func _fade_in():
	if not active or label == null:
		return

	label.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, fade_in_time)\
		.set_trans(trans_type)\
		.set_ease(ease_type)

	await tween.finished

func _fade_out():
	if not active or label == null:
		return

	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, fade_out_time)\
		.set_trans(trans_type)\
		.set_ease(ease_type)

	await tween.finished

# =========================
# ✍️ TYPE EFFECT
# =========================
func _type_text(text):
	if not active or label == null:
		return

	typing = true
	skip = false
	current_full_text = ""
	label.text = ""

	await _fade_in()

	if audio_player and not audio_player.playing:
		audio_player.play()

	for i in text.length():
		if not active:
			return

		if skip:
			current_full_text = text
			label.text = _get_display_text(text)
			break

		current_full_text = text.substr(0, i + 1)
		label.text = _get_display_text(current_full_text)

		await get_tree().create_timer(0.03).timeout

	typing = false
	current_full_text = text
	label.text = _get_display_text(text)

	if audio_player.playing:
		audio_player.stop()

# =========================
# 📜 NEXT DIALOG (🔥 FIX FINAL)
# =========================
func _next_dialog():
	if not active:
		return

	if index >= dialogs.size():
		stop()
		return

	var text = dialogs[index][0]
	var delay = dialogs[index][1]

	await _type_text(text)

	if not active:
		return

	var is_last = index == dialogs.size() - 1

	if use_click:
		await _wait_for_click()
	else:
		await get_tree().create_timer(delay).timeout

		# 🔥 FIX UTAMA DI SINI
		if is_last and keep_last_visible:
			active = false
			cursor_timer.stop()
			emit_signal("dialogue_finished")
			return

		await _fade_out()
		index += 1
		_next_dialog()

func _wait_for_click():
	var current = index
	while current == index and active:
		await get_tree().process_frame

# =========================
# 🖱️ INPUT
# =========================
func handle_click():
	if not active or not use_click or label == null:
		return

	if typing:
		skip = true
	else:
		var is_last = index == dialogs.size() - 1

		if is_last and keep_last_visible:
			active = false
			cursor_timer.stop()
			emit_signal("dialogue_finished")
			return

		await _fade_out()
		index += 1
		_next_dialog()

func _input(event):
	if not active or not use_click:
		return

	if event is InputEventMouseButton and event.pressed:
		handle_click()

	elif event is InputEventScreenTouch and event.pressed:
		handle_click()

	elif event.is_action_pressed("ui_accept"):
		handle_click()
