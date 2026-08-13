extends Node
class_name TypewriterPlayers

signal finished(label)

# ========================
# CONFIG
# ========================
var label: Label
var dialogs: Array

var char_delay := 0.03
var dialog_delay := 0.5
var use_click := true
var cursor_char := "|"
var keep_last_dialog := true

# ========================
# STATE
# ========================
var _clicked := false
var _typing := false
var _skip := false
var _current_text := ""
var _cursor_visible := true

var _audio: AudioStreamPlayer
var _cursor_timer: Timer

# ========================
# SETUP
# ========================
func setup(
	_target_label: Label,
	_dialogs: Array,
	_char_delay := 0.03,
	_dialog_delay := 0.5,
	_use_click := true,
	_cursor_char := "|",
	_keep_last_dialog := true
):
	label = _target_label
	dialogs = _dialogs
	char_delay = _char_delay
	dialog_delay = _dialog_delay
	use_click = _use_click
	cursor_char = _cursor_char
	keep_last_dialog = _keep_last_dialog

	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.gui_input.connect(_on_gui_input)

	# 🔊 AUDIO
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	_audio.stream = preload("res://assets/audio/effects/writter/writter.mp3")
	_audio.volume_db = -10

	# ✨ CURSOR
	_cursor_timer = Timer.new()
	_cursor_timer.wait_time = 0.4
	_cursor_timer.timeout.connect(_blink_cursor)
	add_child(_cursor_timer)

# ========================
# PLAY
# ========================
func play():
	for i in range(dialogs.size()):
		var text = dialogs[i][0]
		var delay = dialogs[i][1]

		await _type(text)

		if use_click:
			await _wait_input()
		else:
			await get_tree().create_timer(delay).timeout

	# ========================
	# FINISH
	# ========================
	if not keep_last_dialog:
		await _fade_out()
		_cursor_timer.stop() # ❌ stop kalau hilang
	else:
		# ✅ paksa cursor tetap nyala & blinking
		_cursor_timer.start()
		_cursor_visible = true
		label.text = _get_text()

	emit_signal("finished", label)

# ========================
# TYPE EFFECT
# ========================
func _type(text):
	_typing = true
	_skip = false
	_current_text = ""
	label.text = ""

	_cursor_timer.start()

	for i in range(text.length()):
		if _skip:
			_current_text = text
			label.text = _get_text()
			break

		_current_text = text.substr(0, i + 1)
		label.text = _get_text()

		if _audio and text[i] != " ":
			if not _audio.playing:
				_audio.play()

		await get_tree().create_timer(char_delay).timeout

	_typing = false
	_audio.stop()

	# ✅ penting: refresh text biar cursor ikut
	label.text = _get_text()

# ========================
# INPUT WAIT
# ========================
func _wait_input():
	_clicked = false
	while not _clicked:
		await get_tree().process_frame

# ========================
# INPUT
# ========================
func _on_gui_input(event):
	if not use_click:
		return

	if event is InputEventMouseButton and event.pressed:
		_handle_click()

	elif event is InputEventScreenTouch and event.pressed:
		_handle_click()

func _handle_click():
	if _typing:
		_skip = true
	else:
		_clicked = true

# ========================
# CURSOR
# ========================
func _blink_cursor():
	_cursor_visible = !_cursor_visible
	label.text = _get_text()

func _get_text():
	if _cursor_visible:
		return _current_text + cursor_char
	else:
		return _current_text

# ========================
# FADE OUT
# ========================
func _fade_out():
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	await tween.finished
	label.text = ""
	label.modulate.a = 1.0
