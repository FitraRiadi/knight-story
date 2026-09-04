extends Node


# ============================================================
# MUSIC MANAGER
# Autoload singleton — musik persist lintas scene.
# Panggil MusicManager.play_music(path) dari scene mana aja.
# ============================================================

var _current_player: AudioStreamPlayer
var _current_path: String = ""
var _fade_tween: Tween


func _ready() -> void:
	_current_player = AudioStreamPlayer.new()
	_current_player.bus = "Master"
	add_child(_current_player)


## Play music dari path. Kalau path sama, gak diulang.
## fade_time: detik untuk crossfade (0 = instant).
func play_music(path: String, fade_time: float = 0.5) -> void:
	if path == _current_path and _current_player.playing:
		return

	if not ResourceLoader.exists(path):
		push_warning("MusicManager: file not found — " + path)
		return

	var new_stream = load(path)
	if new_stream == null:
		push_warning("MusicManager: failed to load — " + path)
		return

	_current_path = path

	# Kalau ada musik lagi playing, fade out dulu
	if _current_player.playing and fade_time > 0:
		_fade_out_and_swap(new_stream, fade_time)
	else:
		_current_player.stream = new_stream
		_current_player.play()


## Stop musik dengan optional fade out.
func stop_music(fade_time: float = 0.5) -> void:
	if not _current_player.playing:
		return

	_current_path = ""

	if fade_time > 0:
		_fade_out_and_free(fade_time)
	else:
		_current_player.stop()


## Pause / unpause musik.
func pause_music() -> void:
	_current_player.stream_paused = true


func resume_music() -> void:
	_current_player.stream_paused = false


## Apakah lagi play?
func is_playing() -> bool:
	return _current_player.playing


## Dapat path sekarang.
func get_current_path() -> String:
	return _current_path


# ============================================================
# INTERNAL: Crossfade
# ============================================================

func _fade_out_and_swap(new_stream: AudioStream, fade_time: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_kill_tween(_fade_tween)

	_fade_tween = create_tween()
	_fade_tween.tween_property(_current_player, "volume_db", -40.0, fade_time * 0.5)

	await _fade_tween.finished

	_current_player.stop()
	_current_player.stream = new_stream
	_current_player.volume_db = 0.0
	_current_player.play()

	# Fade in
	_current_player.volume_db = -40.0
	var fade_in = create_tween()
	fade_in.tween_property(_current_player, "volume_db", 0.0, fade_time * 0.5)


func _fade_out_and_free(fade_time: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_kill_tween(_fade_tween)

	_fade_tween = create_tween()
	_fade_tween.tween_property(_current_player, "volume_db", -40.0, fade_time * 0.5)

	await _fade_tween.finished
	_current_player.stop()
	_current_player.volume_db = 0.0


func _kill_tween(t: Tween) -> void:
	if t and t.is_valid():
		t.kill()
