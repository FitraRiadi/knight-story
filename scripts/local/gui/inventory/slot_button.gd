extends Button
class_name SlotButton


# ============================================================
# SLOT BUTTON
# Custom Button dengan drag & drop support.
# ============================================================

signal item_dropped(source_type: String, source_index: int, target_type: String, target_index: int)

var inv_type: String = ""
var slot_index: int = -1
var item_ref: ItemData = null


func _get_drag_data(position: Vector2) -> Variant:
	if not item_ref:
		return null

	var preview := TextureRect.new()
	preview.texture = item_ref.icon
	preview.custom_minimum_size = Vector2(36, 36)
	preview.size = Vector2(36, 36)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.modulate.a = 0.8
	set_drag_preview(preview)

	return {
		"source_type": inv_type,
		"source_index": slot_index,
		"item": item_ref
	}


func _can_drop_data(position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if not data.has("source_type"):
		return false
	# Gak bisa drop ke slot yang sama
	if data["source_type"] == inv_type and data["source_index"] == slot_index:
		return false
	return true


func _drop_data(position: Vector2, data: Variant) -> void:
	item_dropped.emit(
		data["source_type"],
		data["source_index"],
		inv_type,
		slot_index
	)
