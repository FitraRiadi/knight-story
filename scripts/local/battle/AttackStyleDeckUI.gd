extends Node2D
class_name AttackStyleDeckUI

# ============================================================
# ATTACK STYLE DECK
# Spawn via code (pola skill deck): BattleManager panggil
# spawn_into() → CanvasLayer layer 250 (TOP layer battle — di atas
# hands 120 / inventory 160 / skill deck 165 / combo 180, di bawah
# tutorial 300). CanvasLayer screen-space = deck selalu nempel di
# layar, gak tenggelam pas kamera zoom/pan ke enemy.
# Ada bg overlay gelap di layer sama (z_index -1): klik di luar
# deck → deck_dismissed → BattleManager cancel.
# Alur: klik style (clickArea) → informationPanel muncul dengan
# animasi stagger (JUICY) → tombol "USE STYLE" → use_style_requested.
# Panel SENGAJA hidden pas open — baru nongol saat style di-click.
# Style TIDAK dibuang habis dipakai. Setelah USE, deck masuk mode
# indicator: slot terpilih ditarik ke pojok kiri atas selama
# mechanic, close() mereset semuanya.
# ============================================================

signal style_selected(style: AttackStyleData)
signal use_style_requested(style: AttackStyleData)
signal deck_dismissed

# Layer paling tinggi battle UI (combo 180 max sebelumnya)
const DECK_LAYER := 250
# Alpha bg gelap di belakang deck
const BG_ALPHA := 0.55

# Slot style: node di attack_style_deck.tscn + data .tres + nama tampil di panel
const STYLE_SLOTS: Array = [
	{"slot": "attack1", "data": "res://data/attack_styles/execute_attack.tres", "display": "Execute Attack"},
	{"slot": "attack2", "data": "res://data/attack_styles/rapid_attack.tres", "display": "Rapid Attack"},
	{"slot": "attack3", "data": "res://data/attack_styles/charge_attack.tres", "display": "Charge Attack"},
]

# Label tipe target per attack_type
const TYPE_LABELS := {
	"Execute": "Single Target",
	"Charge": "Single Target",
	"Rapid": "Multi Hit",
}

# Posisi indicator style terpilih (koordinat parent) — pola lama card (10,10)
const INDICATOR_POS := Vector2(10, 10)

# Urutan & jenis animasi stagger informationPanel per elemen
const PANEL_ORDER := ["bg", "nameStyle", "info", "rarity", "type", "cost", "btnUse"]
const PANEL_KIND := {
	"bg": "pop",
	"nameStyle": "slide_left",
	"info": "slide_up",
	"rarity": "pop",
	"type": "pop",
	"cost": "pop",
	"btnUse": "btn",
}

var is_open := false
var selected_index := -1

var _stamina := 999.0
var _styles: Array = []
var _slot_base: Dictionary = {}
var _slot_tweens: Array = []
var _panel_parts: Array = []
var _tween: Tween
var _panel_tween: Tween
var _bg_tween: Tween
var _indicator := false
var _deck_pos := Vector2.ZERO
var _art_tween: Tween
var _art_base_scale := Vector2.ONE
var _art_base_pos := Vector2.ZERO

var _layer: CanvasLayer = null
var _bg: ColorRect = null

@onready var _art: TextureRect = $attackStyle/art
@onready var _panel: Control = $attackStyle/informationPanel
@onready var _name_style: Label = $attackStyle/informationPanel/nameStyle
@onready var _rarity: Label = $attackStyle/informationPanel/rarity
@onready var _type: Label = $attackStyle/informationPanel/type
@onready var _cost: Label = $attackStyle/informationPanel/cost
@onready var _info: Label = $attackStyle/informationPanel/info
@onready var _btn_use: Button = $attackStyle/informationPanel/btnUse


# Spawn sekali dari BattleManager: bikin CanvasLayer top-layer +
# deck instance di dalamnya. Dipanggil lazily pas atkBtn pertama.
static func spawn_into(parent: Node) -> AttackStyleDeckUI:
	var deck: AttackStyleDeckUI = (load("res://scenes/battle/attack_style_deck.tscn") as PackedScene).instantiate()
	deck._attach_to_layer(parent)
	return deck


func _attach_to_layer(parent: Node) -> void:
	_layer = CanvasLayer.new()
	_layer.name = "attackDeckLayer"
	_layer.layer = DECK_LAYER
	parent.add_child(_layer)
	# BG overlay DULU (child 0) → deck (child 1) di atasnya utk draw & input.
	# Pola sama persis ActionCardUI: bg ditambah sebelum konten biar input
	# gak jatuh ke bg waktu klik kartu. z_index -1 extra insurance.
	_bg = ColorRect.new()
	_bg.name = "deckBg"
	_bg.color = Color(0, 0, 0, BG_ALPHA)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg.z_index = -1
	_bg.gui_input.connect(_on_bg_input)
	_layer.add_child(_bg)
	_layer.add_child(self)


func _ready() -> void:
	visible = false
	_deck_pos = position
	for slot in STYLE_SLOTS:
		var rect: TextureRect = get_node(slot["slot"])
		rect.mouse_filter = Control.MOUSE_FILTER_STOP
		_styles.append({
			"data": load(slot["data"]),
			"rect": rect,
			"click": rect.get_node("clickArea"),
			"label": rect.get_node("name"),
		})
		_slot_base[rect] = {"pos": rect.position, "scale": rect.scale}
		_slot_tweens.append(null)
	for i in _styles.size():
		_styles[i]["click"].pressed.connect(_on_style_pressed.bind(i))
	_btn_use.pressed.connect(_on_use_pressed)

	# Simpan base state tiap elemen panel (buat stagger + reset)
	var panel_map := {
		"bg": $attackStyle/informationPanel/bg,
		"nameStyle": _name_style,
		"info": _info,
		"rarity": _rarity,
		"type": _type,
		"cost": _cost,
		"btnUse": _btn_use,
	}
	for key in PANEL_ORDER:
		var n: Control = panel_map[key]
		n.pivot_offset = n.size * 0.5
		_panel_parts.append({"key": key, "node": n, "pos": n.position, "scale": n.scale})
	_panel.visible = false

	# Art (ilustrasi sebelah informationPanel) disembunyiin dulu —
	# baru pop juicy pas style di-click, sama kayak panel.
	_art_base_scale = _art.scale
	_art.pivot_offset = _art.size * 0.5
	# Kompensasi posisi biar pivot pindah ke center tapi hasil render
	# tetap sama: pos' = pos - (1 - scale) * center.
	_art_base_pos = _art.position - (Vector2.ONE - _art_base_scale) * _art.pivot_offset
	_art.position = _art_base_pos
	_art.visible = false


# ============================================================
# BUKA / TUTUP
# ============================================================

func open(stamina: float) -> void:
	if is_open:
		return
	is_open = true
	_indicator = false
	position = _deck_pos
	visible = true
	set_stamina(stamina)
	# Panel SENGAJA disembunyiin — baru muncul saat style di-click
	_reset_panel()
	_select_style(0, false)

	# BG overlay fade in
	if _bg:
		_bg.mouse_filter = Control.MOUSE_FILTER_STOP
		if _bg_tween:
			_bg_tween.kill()
		_bg.modulate.a = 0.0
		_bg_tween = create_tween()
		_bg_tween.tween_property(_bg, "modulate:a", 1.0, 0.25)

	# Deck root: pop scale + fade
	if _tween:
		_tween.kill()
	scale = Vector2(0.88, 0.88)
	modulate = Color(1, 1, 1, 0)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.26)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate", Color.WHITE, 0.16)

	# Slot stagger: muncul satu-satu dari bawah
	for i in _styles.size():
		_animate_slot_in(i)


func close() -> void:
	if not is_open:
		return
	is_open = false
	if _bg:
		# Matiin input pas fade biar gak ke-trigger dismiss dobel
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _bg_tween:
			_bg_tween.kill()
		_bg_tween = create_tween()
		_bg_tween.tween_property(_bg, "modulate:a", 0.0, 0.15)
	if _tween:
		_tween.kill()
	if _indicator:
		# MODE INDICATOR: art corner (slot terpilih) dianimasikan dulu,
		# baru _finish_close. chain() = callback jalan SETELAH kelompok
		# parallel kelar (dulu callback-nya ke-trigger di t=0 → ujug-ujug).
		_animate_indicator_out()
	else:
		# NORMAL: fade dulu, baru _finish_close (sequential default —
		# pola sama kayak ActionCardUI close_tw, BUKAN set_parallel(true)).
		_tween = create_tween()
		_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.15)
		_tween.tween_callback(_finish_close)


# ============================================================
# KELUAR INDIKATOR — ART POJOK KIRI ATAS: POP → MENCIUT (STAGGER)
# Dipanggil close() pas mode indicator: art style yang nempel di
# pojok kiri atas gak ilang ujug-ujug — nge-pop dikit dulu (meletus),
# terus menciut + pudar. Label nama ilang lebih awal = stagger.
# 2 fase pake tween TERPISAH biar gak ada 2 tween nembak properti
# yang sama di satu kelompok parallel (bakal berebut/nge-jitter).
# ============================================================

func _animate_indicator_out() -> void:
	var sel := selected_index
	if sel < 0 or sel >= _styles.size():
		_finish_close()
		return
	var r: TextureRect = _styles[sel]["rect"]
	if _slot_tweens[sel] and _slot_tweens[sel].is_valid():
		_slot_tweens[sel].kill()
		_slot_tweens[sel] = null
	var base: Vector2 = (_slot_base[r]["scale"] as Vector2)
	var lbl: Label = _styles[sel]["label"]
	r.visible = true
	r.modulate = Color.WHITE
	lbl.modulate = Color.WHITE
	# FASE 1 — POP: art ngegede dikit (meletus), label pudar duluan (stagger)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(r, "scale", base * 1.16, 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(lbl, "modulate:a", 0.0, 0.12)
	_tween.chain().tween_callback(_indicator_shrink)


func _indicator_shrink() -> void:
	# FASE 2 — MENCIUT + FADE (abis pop), terus _finish_close
	var sel := selected_index
	if sel < 0 or sel >= _styles.size():
		_finish_close()
		return
	var r: TextureRect = _styles[sel]["rect"]
	var base: Vector2 = (_slot_base[r]["scale"] as Vector2)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(r, "scale", base * 0.08, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(r, "modulate:a", 0.0, 0.18).set_delay(0.03)
	_tween.chain().tween_callback(_finish_close)


func _finish_close() -> void:
	visible = false
	modulate = Color.WHITE
	scale = Vector2.ONE
	position = _deck_pos
	_indicator = false
	$attackStyle.visible = true
	for s in _styles:
		var r: TextureRect = s["rect"]
		r.visible = true
		r.modulate = Color.WHITE
		# Label nama ikut di-reset — animasi exit indicator nge-fade dia
		(s["label"] as Label).modulate = Color.WHITE
	_kill_slot_tweens()
	_reset_panel()


func _reset_panel() -> void:
	if _panel_tween:
		_panel_tween.kill()
	_panel.visible = false
	# enter_indicator nge-fade alpha _panel ke 0 → WAJIB di-reset balik,
	# kalau gak panel gak bakal keliatan lagi walau visible=true.
	_panel.modulate = Color.WHITE
	for part in _panel_parts:
		var n: Control = part["node"]
		n.position = part["pos"]
		n.scale = part["scale"]
		n.modulate = Color.WHITE
	# Art ikut di-reset: hilang lagi sampai style berikutnya di-click
	if _art_tween and _art_tween.is_valid():
		_art_tween.kill()
	_art.visible = false
	_art.scale = _art_base_scale
	_art.position = _art_base_pos
	_art.modulate = Color.WHITE


# ============================================================
# ANIMASI SLOT MASUK (stagger pas deck dibuka)
# ============================================================

func _animate_slot_in(i: int) -> void:
	var r: TextureRect = _styles[i]["rect"]
	var base: Dictionary = _slot_base[r]
	var delay := 0.08 + i * 0.06
	r.position = base["pos"] + Vector2(0, 40)
	r.modulate.a = 0.0
	if _slot_tweens[i]:
		_slot_tweens[i].kill()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(r, "position", base["pos"], 0.34)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	tw.tween_property(r, "modulate:a", 1.0, 0.2).set_delay(delay)
	_slot_tweens[i] = tw


func _kill_slot_tweens() -> void:
	for tw in _slot_tweens:
		if tw and tw.is_valid():
			tw.kill()
	for i in _slot_tweens.size():
		_slot_tweens[i] = null


# ============================================================
# MODE INDICATOR — style terpilih nongol di pojok kiri atas
# selama mechanic (pola lama card → Vector2(10,10)).
# Layer 250 = screen space → indicator selalu top-left layar,
# gak ikut kamera zoom ke enemy.
# is_open sengaja tetep true biar open()/toggle gak nabrak.
# Keluarnya lewat close() → _animate_indicator_out() (pop → menciut).
# ============================================================

func enter_indicator() -> void:
	if not is_open or _indicator:
		return
	_indicator = true
	if _tween:
		_tween.kill()
	_kill_slot_tweens()
	scale = Vector2.ONE
	modulate = Color.WHITE
	# BG overlay + panel lenyap — mechanic mode
	if _bg:
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _bg_tween:
			_bg_tween.kill()
		_bg_tween = create_tween()
		_bg_tween.tween_property(_bg, "modulate:a", 0.0, 0.18)
	if _panel_tween:
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.tween_property(_panel, "modulate:a", 0.0, 0.12)
	$attackStyle.visible = false
	var sel := selected_index if selected_index >= 0 else 0
	for j in _styles.size():
		var r: TextureRect = _styles[j]["rect"]
		r.visible = j == sel
		r.modulate = Color.WHITE
		if j == sel:
			var base: Dictionary = _slot_base[r]
			r.scale = base["scale"]
	var target := INDICATOR_POS - (_styles[sel]["rect"] as TextureRect).position
	_tween = create_tween()
	_tween.tween_property(self, "position", target, 0.22)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ============================================================
# CEK MODE INDICATOR
# ============================================================

func is_indicator() -> bool:
	return _indicator


# ============================================================
# PILIH STYLE + UPDATE PANEL
# ============================================================

func _on_bg_input(event: InputEvent) -> void:
	if _indicator or not is_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Guard: klik di area kartu style gak boleh close (biar gak "malah ke-close")
		for s in _styles:
			if (s["rect"] as TextureRect).get_global_rect().has_point(event.position):
				return
		deck_dismissed.emit()


func _on_style_pressed(i: int) -> void:
	if _indicator:
		return
	_select_style(i)
	style_selected.emit(_styles[i]["data"])


func _select_style(i: int, animate: bool = true) -> void:
	if i < 0 or i >= _styles.size():
		return
	selected_index = i
	var style: AttackStyleData = _styles[i]["data"]
	_art.texture = _styles[i]["rect"].texture
	_name_style.text = STYLE_SLOTS[i]["display"]
	_rarity.text = style.rarity
	_type.text = TYPE_LABELS.get(style.attack_type, "Single Target")
	_cost.text = "STA %d" % int(style.stamina_cost)
	_info.text = style.description
	_apply_highlight(i, animate)
	_refresh_use_button()
	# Panel + art muncul dengan intro juicy SETIAP style di-click
	if animate:
		_animate_art_in()
		_animate_panel_in()


func _apply_highlight(i: int, animate: bool) -> void:
	for j in _styles.size():
		var r: TextureRect = _styles[j]["rect"]
		var base: Vector2 = (_slot_base[r]["scale"] as Vector2)
		var target_scale: Vector2 = base * (1.12 if j == i else 0.92)
		var col := Color.WHITE if j == i else Color(0.6, 0.6, 0.6, 1)
		# Safety: animasi exit indicator nge-fade alpha label → dipulungin
		# tiap open/select biar label gak ketahan transparan.
		(_styles[j]["label"] as Label).modulate = Color.WHITE
		var idx := j
		if _slot_tweens[idx]:
			_slot_tweens[idx].kill()
			_slot_tweens[idx] = null
		if animate:
			var tw := create_tween().set_parallel(true)
			tw.tween_property(r, "scale", target_scale, 0.2)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(r, "modulate", col, 0.15)
			_slot_tweens[idx] = tw
		else:
			r.scale = target_scale
			r.modulate = col


# ============================================================
# ANIMASI ART — POP JUICY
# Ilustrasi sebelah informationPanel: nge-pop dari kecil + fade +
# slide dari bawah, TRANS_BACK overshoot biar berasa "meletus".
# Pivot center (posisi dikompensasi) biar pop-nya dari tengah art.
# Re-trigger tiap kali style di-click.
# ============================================================

func _animate_art_in() -> void:
	if _art_tween and _art_tween.is_valid():
		_art_tween.kill()
	_art.visible = true
	# Mulai kecil + fade + geser dari bawah → nge-pop (TRANS_BACK overshoot)
	_art.scale = _art_base_scale * 0.2
	_art.position = _art_base_pos + Vector2(0, 16)
	_art.modulate = Color(1, 1, 1, 0)
	_art_tween = create_tween().set_parallel(true)
	_art_tween.tween_property(_art, "scale", _art_base_scale, 0.36)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_art_tween.tween_property(_art, "position", _art_base_pos, 0.32)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_art_tween.tween_property(_art, "modulate:a", 1.0, 0.14)


# ============================================================
# ANIMASI INFORMATION PANEL — STAGGER JUICY
# Tiap elemen muncul berurutan: bg pop → name slide dari kiri →
# info slide dari bawah → rarity/type/cost pop → USE bounce.
# Re-trigger tiap kali style di-click.
# ============================================================

func _animate_panel_in() -> void:
	if _panel_tween:
		_panel_tween.kill()
	_panel.visible = true
	# Pastiin alpha container = 1 (jaga-jaga kalau ke-fade 0 sama indicator)
	_panel.modulate = Color.WHITE
	_panel_tween = create_tween().set_parallel(true)
	for part in _panel_parts:
		var key: String = part["key"]
		var n: Control = part["node"]
		var base_pos: Vector2 = part["pos"]
		var base_scale: Vector2 = part["scale"]
		var delay := PANEL_ORDER.find(key) * 0.045
		match PANEL_KIND[key]:
			"pop":
				n.position = base_pos
				n.scale = base_scale * 0.55
				n.modulate = Color(1, 1, 1, 0)
				_panel_tween.tween_property(n, "scale", base_scale, 0.24)\
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
				_panel_tween.tween_property(n, "modulate:a", 1.0, 0.16).set_delay(delay)
			"slide_left":
				n.position = base_pos + Vector2(-30, 0)
				n.scale = base_scale
				n.modulate = Color(1, 1, 1, 0)
				_panel_tween.tween_property(n, "position", base_pos, 0.3)\
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
				_panel_tween.tween_property(n, "modulate:a", 1.0, 0.18).set_delay(delay)
			"slide_up":
				n.position = base_pos + Vector2(0, 18)
				n.scale = base_scale
				n.modulate = Color(1, 1, 1, 0)
				_panel_tween.tween_property(n, "position", base_pos, 0.3)\
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
				_panel_tween.tween_property(n, "modulate:a", 1.0, 0.18).set_delay(delay)
			"btn":
				n.position = base_pos
				n.scale = base_scale * 0.3
				n.modulate = Color(1, 1, 1, 0)
				_panel_tween.tween_property(n, "scale", base_scale, 0.32)\
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
				_panel_tween.tween_property(n, "modulate:a", 1.0, 0.2).set_delay(delay)


func _on_use_pressed() -> void:
	if selected_index < 0 or _indicator:
		return
	var style: AttackStyleData = _styles[selected_index]["data"]
	if _stamina < style.stamina_cost:
		return
	use_style_requested.emit(style)


func set_stamina(v: float) -> void:
	_stamina = v
	_refresh_use_button()


func _refresh_use_button() -> void:
	if selected_index < 0:
		return
	var style: AttackStyleData = _styles[selected_index]["data"]
	var cukup: bool = _stamina >= style.stamina_cost
	_btn_use.disabled = not cukup
	_cost.add_theme_color_override("font_color", Color.BLACK if cukup else Color(0.8, 0.1, 0.1))


# ============================================================
# API UNTUK TUTORIAL / BATTLEMANAGER
# ============================================================

func get_selected_style() -> AttackStyleData:
	if selected_index < 0:
		return null
	return _styles[selected_index]["data"]


func get_style_data(i: int) -> AttackStyleData:
	if i < 0 or i >= _styles.size():
		return null
	return _styles[i]["data"]


func get_style_rect(i: int) -> TextureRect:
	if i < 0 or i >= _styles.size():
		return null
	return _styles[i]["rect"]


func get_use_button() -> Button:
	return _btn_use


func get_click_area(i: int) -> TextureButton:
	if i < 0 or i >= _styles.size():
		return null
	return _styles[i]["click"]


func index_of_type(attack_type: String) -> int:
	for i in _styles.size():
		if _styles[i]["data"].attack_type == attack_type:
			return i
	return -1


func style_count() -> int:
	return _styles.size()
