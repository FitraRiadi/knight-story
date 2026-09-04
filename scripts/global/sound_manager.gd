extends Node

# Path file audio klik Anda (Sesuaikan dengan folder aset .wav atau .mp3 Anda)
const CLICK_SOUND_PATH: String = "uid://dl4yf4hktppo5"

var audio_player: AudioStreamPlayer

func _ready() -> void:
	# 1. Siapkan komponen pemutar audio
	audio_player = AudioStreamPlayer.new()
	if ResourceLoader.exists(CLICK_SOUND_PATH):
		audio_player.stream = load(CLICK_SOUND_PATH)
	else:
		print_rich("[color=red][SOUND ERROR][/color] File suara klik tidak ditemukan di: " + CLICK_SOUND_PATH)
	add_child(audio_player)
	
	# 2. Amankan tombol yang SUDAH ADA di layar saat awal game dimulai
	pindai_dan_koneksikan_tombol(get_tree().root)
	
	# 3. Pantau tombol BARU yang akan muncul di masa mendatang (hasil duplikat/pindah scene)
	get_tree().node_added.connect(_on_node_added)

# Fungsi pemantau untuk node baru yang lahir di tengah permainan
func _on_node_added(node: Node) -> void:
	_cek_dan_hubungkan(node)

# Fungsi rekursif untuk menyisir semua tombol yang sudah ada di dalam scene tree
func pindai_dan_koneksikan_tombol(node_induk: Node) -> void:
	_cek_dan_hubungkan(node_induk)
	for anak in node_induk.get_children():
		pindai_dan_koneksikan_tombol(anak) # Cari terus sampai ke anak cucu node paling dalam

# Logika pengecekan, penyuntikan sinyal suara, dan pembentukan kursor pointer
func _cek_dan_hubungkan(node: Node) -> void:
	if node is Button or node is TextureButton:
		# PENTING: Pastikan tombol bisa menerima klik mouse (tidak Ignore)
		if node.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			node.mouse_filter = Control.MOUSE_FILTER_STOP 
			
		# BARU: Mengubah bentuk ikon kursor mouse menjadi jari/telunjuk saat diarahkan ke tombol
		node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			
		# Putus koneksi lama jika ada (mencegah double suara)
		if node.pressed.is_connected(putar_suara_klik):
			node.pressed.disconnect(putar_suara_klik)
			
		# Hubungkan sinyal klik tombol ke fungsi suara
		node.pressed.connect(putar_suara_klik)

# Fungsi untuk memutar audio klik
func putar_suara_klik() -> void:
	if audio_player and audio_player.stream:
		# Jika suara sedang berbunyi, hentikan dulu lalu mainkan dari awal agar tidak telat merespons
		if audio_player.playing:
			audio_player.stop()
		audio_player.play()
