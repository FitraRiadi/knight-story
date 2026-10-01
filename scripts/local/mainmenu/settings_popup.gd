extends Control
class_name SettingsPopup

# Popup settings code-built (menu gak punya tscn khusus settings).
# Dipanggil dari main_menu: SettingsPopup.open(self).

const PANEL_RECT := Rect2(170, 45, 400, 250)

var _gfx_buttons: Dictionary = {}
var _music_slider: HSlider
var _music_value: Label


static func open(parent: Control) -> SettingsPopup:
	for child in parent.get_children():
		if child is SettingsPopup:
			child.open_popup()
			return child
	var pop := SettingsPopup.new()
	parent.add_child(pop)
	pop._build()
	pop.open_popup()
	return pop


func open_popup() -> void:
	visible = true
	refresh()


func close_popup() -> void:
	visible = false


func refresh() -> void:
	var g := GameSettings.get_data().graphics
	for key in _gfx_buttons.keys():
		var b: Button = _gfx_buttons[key]
		if key == g:
			b.modulate = Color(1.0, 0.85, 0.3)
		else:
			b.modulate = Color(0.55, 0.55, 0.55)
	if _music_slider:
		_music_slider.set_value_no_signal(GameSettings.get_data().music_volume * 100.0)
	if _music_value:
		_music_value.text = str(int(GameSettings.get_data().music_volume * 100.0)) + "%"


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := Panel.new()
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.10, 0.97)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.7, 0.2, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 12)
	title.size = Vector2(400, 36)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title)

	var gfx_label := Label.new()
	gfx_label.text = "Graphics"
	gfx_label.position = Vector2(20, 62)
	gfx_label.size = Vector2(120, 28)
	gfx_label.add_theme_font_size_override("font_size", 20)
	panel.add_child(gfx_label)

	var names: Array[String] = ["auto", "high", "low"]
	for i in range(names.size()):
		var b := Button.new()
		b.text = names[i].capitalize()
		b.position = Vector2(140 + i * 85, 60)
		b.size = Vector2(78, 34)
		panel.add_child(b)
		_gfx_buttons[names[i]] = b
		var key := names[i]
		b.pressed.connect(func() -> void:
			GameSettings.set_graphics(key)
			refresh()
		)

	var mus_label := Label.new()
	mus_label.text = "Music"
	mus_label.position = Vector2(20, 112)
	mus_label.size = Vector2(120, 28)
	mus_label.add_theme_font_size_override("font_size", 20)
	panel.add_child(mus_label)

	_music_slider = HSlider.new()
	_music_slider.min_value = 0.0
	_music_slider.max_value = 100.0
	_music_slider.step = 1.0
	_music_slider.position = Vector2(140, 112)
	_music_slider.size = Vector2(180, 28)
	panel.add_child(_music_slider)
	_music_slider.value_changed.connect(func(v: float) -> void:
		GameSettings.set_music_volume(v / 100.0)
		MusicManager.set_master_volume_linear(v / 100.0)
		refresh()
	)

	_music_value = Label.new()
	_music_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_music_value.position = Vector2(326, 112)
	_music_value.size = Vector2(54, 28)
	_music_value.add_theme_font_size_override("font_size", 18)
	panel.add_child(_music_value)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.position = Vector2(140, 196)
	close_btn.size = Vector2(120, 36)
	panel.add_child(close_btn)
	close_btn.pressed.connect(close_popup)

	refresh()
