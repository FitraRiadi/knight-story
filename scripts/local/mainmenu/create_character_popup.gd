extends Control

@onready var select_perk_popup = $"../selectPerkPopup"
@onready var confirm_popup = $"../confirmPopup"
@onready var perk_label = $bgPopup/perkColumn/perkLabel
@onready var information = $bgPopup/information
@onready var name_input = $bgPopup/nameColumn/input

var popup_hide := false
var popup_intro := false
var perk_current := "NONE"

func _ready() -> void:
	information.text = ""
	$bgPopup/perkColumn/TextureButton.pressed.connect(_open_perk_popup)
	$bgPopup/confirm/click.pressed.connect(_on_confirm_pressed)
	$bgPopup/cancel/click.pressed.connect(_on_cancel_pressed)

func _process(_delta: float) -> void:
	if visible and not popup_intro and not popup_hide:
		_popup_intro()

	if select_perk_popup.visible and not popup_hide:
		popup_hide = true
		create_tween().tween_property(self, "position:x", position.x - 500, 0.5).set_trans(Tween.TRANS_CIRC)

	perk_label.text = perk_current
	if perk_current != "NONE":
		perk_label.modulate = Color.GREEN_YELLOW
		perk_label.modulate.a = 1
	else:
		perk_label.modulate.a = 0.5

func set_perk(perk_name: String) -> void:
	perk_current = perk_name

func show_information(text_info: String) -> void:
	information.text = text_info
	information.modulate.a = 0
	create_tween().tween_property(information, "modulate:a", 1.0, 0.5)

func _popup_intro() -> void:
	modulate.a = 0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC)
	popup_intro = true

func _popup_restore() -> void:
	create_tween().tween_property(self, "position:x", position.x + 500, 0.5).set_trans(Tween.TRANS_CIRC)

func _open_perk_popup() -> void:
	print('PERK')
	select_perk_popup.visible = true

func _on_cancel_pressed() -> void:
	popup_intro = false
	visible = false

func _on_confirm_pressed() -> void:
	print(perk_current)
	print(name_input.text)
	if perk_current == "NONE":
		show_information("Perk Must choice")
		return
	if len(name_input.text) < 3:
		show_information("Name to short!")
		return
	if len(name_input.text) > 12:
		show_information("Name to long!")
		return
	show_information("")
	confirm_popup.visible = true
	confirm_popup.intro()
