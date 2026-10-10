extends Control

@onready var create_character_popup = $"../createCharacterPopup"
@onready var menu_ui = $"../menu/bg_scene/MenuOption"
@onready var menu_node = $"../menu"

var on_create := false

func _ready() -> void:
	$bg/yes.pressed.connect(_on_yes_pressed)
	$bg/no.pressed.connect(_on_no_pressed)

func _process(_delta: float) -> void:
	if on_create and menu_ui.modulate.a == 0:
		on_create = false
		visible = false
		# Menu + prologue 1 sudah satu scene — mulai fase prologue di tempat
		menu_node.start_prologue_phase()

func intro() -> void:
	modulate.a = 0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CIRC)

func _on_yes_pressed() -> void:
	visible = false
	print('Letsgo')
	on_create = true
	# Titik commit New Game: WIPE dulu, BARU tulis identitas
	# (kebalik = nama kehapus balik default).
	PlayerDataManager.reset_data()
	if PlayerDataManager.data != null:
		PlayerDataManager.data.player_name = create_character_popup.name_input.text
		PlayerDataManager.data.player_perk = create_character_popup.perk_current
		PlayerDataManager.save()
	create_character_popup.visible = false
	create_tween().tween_property(menu_ui, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_CIRC)
	create_tween().tween_property(menu_ui, "position:y", menu_ui.position.y - 500, 0.5).set_trans(Tween.TRANS_CIRC)

func _on_no_pressed() -> void:
	visible = false
