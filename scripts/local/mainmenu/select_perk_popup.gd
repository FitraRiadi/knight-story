extends Control

const PERKS := [
	{"button": "perk1/click", "name": "Arcane Master"},
	{"button": "perk2/click", "name": "Blade Mastery"},
	{"button": "perk3/click", "name": "Stone Skin"},
]

@onready var create_character_popup = $"../createCharacterPopup"

var popup_intro := false

func _ready() -> void:
	for i in PERKS.size():
		var perk = PERKS[i]
		get_node(perk.button).pressed.connect(_select_perk.bind(perk.name))

func _process(_delta: float) -> void:
	if visible and not popup_intro:
		_popup_intro()

func _popup_intro() -> void:
	modulate.a = 0
	position.y -= 50
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "position:y", position.y + 50, 1.0).set_trans(Tween.TRANS_CIRC)
	popup_intro = true

func _select_perk(perk_name: String) -> void:
	print('PERK SELECTED: ', perk_name)
	create_character_popup.set_perk(perk_name)
	create_character_popup._popup_restore()
	create_character_popup.popup_hide = false
	visible = false
	popup_intro = false