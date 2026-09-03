extends Node

func pindah_scene(target_scene_path: String) -> void:
	var ukuran_layar = get_viewport().get_visible_rect().size

	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100

	var tirai = ColorRect.new()
	tirai.color = Color.BLACK
	tirai.size = ukuran_layar
	tirai.position = Vector2(ukuran_layar.x, 0)
	tirai.mouse_filter = Control.MOUSE_FILTER_STOP

	var nama_file = target_scene_path.get_file()
	var nama_tujuan = nama_file.replace(".tscn", "").capitalize()

	var teks_tujuan = Label.new()
	teks_tujuan.text = nama_tujuan
	teks_tujuan.add_theme_font_size_override("font_size", 32)
	teks_tujuan.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	teks_tujuan.grow_horizontal = Control.GROW_DIRECTION_BOTH
	teks_tujuan.grow_vertical = Control.GROW_DIRECTION_BOTH

	tirai.add_child(teks_tujuan)
	canvas_layer.add_child(tirai)
	get_tree().root.add_child(canvas_layer)

	var tween_tutup = create_tween()
	tween_tutup.tween_property(tirai, "position:x", 0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween_tutup.finished

	get_tree().change_scene_to_file(target_scene_path)
	await get_tree().process_frame

	var tween_buka = create_tween()
	tween_buka.tween_property(tirai, "position:x", -ukuran_layar.x, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween_buka.finished

	canvas_layer.queue_free()


func pindah_scene_with_zoom(target_scene_path: String, _button_node: Control) -> void:
	var ukuran_layar = get_viewport().get_visible_rect().size
	var center: Vector2 = ukuran_layar / 2.0

	var camera := Camera2D.new()
	camera.position = center
	camera.zoom = Vector2.ONE
	get_tree().root.add_child(camera)
	camera.make_current()

	var target_zoom := Vector2(1.25, 1.25)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(camera, "zoom", target_zoom, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished

	camera.queue_free()
	await pindah_scene(target_scene_path)
