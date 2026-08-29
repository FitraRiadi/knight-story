extends Button
class_name SlotButton


# ============================================================
# SLOT BUTTON
# Emits signal on mouse down only.
# Release handled by parent via global _input().
# ============================================================

signal slot_mouse_down(button: SlotButton)

var inv_type: String = ""
var slot_index: int = -1
var item_ref: ItemData = null


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			slot_mouse_down.emit(self)
