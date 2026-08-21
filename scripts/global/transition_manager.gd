extends Node

func pindah_scene(target_scene_path: String) -> void:
	var ukuran_layar = get_viewport().get_visible_rect().size
	
	# 1. Membuat Container Utama (CanvasLayer)
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	
	# 2. Membuat Tirai Latar Belakang Hitam (ColorRect)
	var tirai = ColorRect.new()
	tirai.color = Color.BLACK
	tirai.size = ukuran_layar
	tirai.position = Vector2(ukuran_layar.x, 0) # Mulai dari luar layar kanan
	tirai.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 3. Ekstrak Nama File untuk Teks Tujuan Secara Otomatis
	# Mengambil nama file dari path (contoh: "blacksmith.tscn")
	var nama_file = target_scene_path.get_file() 
	# Menghilangkan ekstensi ".tscn" dan mengubah huruf pertama menjadi kapital (contoh: "Blacksmith")
	var nama_tujuan = nama_file.replace(".tscn", "").capitalize() 
	
	# 4. Menambahkan Teks Dinamis di Tengah Tirai
	var teks_tujuan = Label.new()
	teks_tujuan.text = nama_tujuan
	teks_tujuan.add_theme_font_size_override("font_size", 32) # Ukuran font teks
	
	# Mengunci teks tepat di titik tengah (Center) tirai hitam
	teks_tujuan.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	teks_tujuan.grow_horizontal = Control.GROW_DIRECTION_BOTH
	teks_tujuan.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Masukkan teks ke dalam tirai, lalu masukkan tirai ke layar utama
	tirai.add_child(teks_tujuan)
	canvas_layer.add_child(tirai)
	get_tree().root.add_child(canvas_layer)
	
	# 5. Animasi Tutup Tirai (Kanan ke Kiri)
	var tween_tutup = create_tween()
	tween_tutup.tween_property(tirai, "position:x", 0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween_tutup.finished
	
	# 6. Ganti Scene saat layar tertutup penuh
	get_tree().change_scene_to_file(target_scene_path)
	await get_tree().process_frame
	
	# 7. Animasi Buka Tirai (Geser Keluar ke Kiri)
	var tween_buka = create_tween()
	tween_buka.tween_property(tirai, "position:x", -ukuran_layar.x, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween_buka.finished
	
	# 8. Hapus objek transisi dari memori setelah selesai
	canvas_layer.queue_free()
