@tool
extends GPUParticles2D

@export_enum("Debu Sore", "Daun Gugur", "Kunang-Kunang", "Daun Bertebangan Angin") var tipe_atmosfer: int = 3:
	set(value):
		tipe_atmosfer = value
		_update_particles()

func _ready() -> void:
	_update_particles()

func _update_particles() -> void:
	# --- PERUBAHAN: Jumlah partikel dinaikkan drastis agar lebih ramai ---
	amount = 500
	lifetime = 8.0
	preprocess = 6.0 # Mengisi layar lebih cepat sejak awal scene dimuat
	
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1200, 600, 1) 
	
	# Membuat tekstur bulat halus dasar
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = Gradient.new()
	grad_tex.gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)]) 
	grad_tex.fill = GradientTexture2D.FILL_RADIAL 
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.width = 16
	grad_tex.height = 16
	texture = grad_tex
	
	match tipe_atmosfer:
		0: # Debu Sore
			pm.gravity = Vector3(10, -5, 0)
			pm.initial_velocity_min = 5.0
			pm.initial_velocity_max = 15.0
			modulate = Color(0.95, 0.85, 0.6, 0.2) 
			
		1: # Daun Gugur Lambat (Jatuh ke bawah)
			pm.gravity = Vector3(-30, 50, 0)
			pm.initial_velocity_min = 15.0
			pm.initial_velocity_max = 35.0
			pm.scale_min = 1.0
			pm.scale_max = 2.5
			pm.angle_min = -180.0
			pm.angle_max = 180.0
			pm.angular_velocity_min = 30.0
			pm.angular_velocity_max = 90.0
			modulate = Color(0.4, 0.55, 0.2, 0.7)
			
		2: # Kunang-Kunang Malam
			pm.gravity = Vector3(0, -8, 0)
			pm.initial_velocity_min = 10.0
			pm.initial_velocity_max = 25.0
			pm.spread = 180.0
			modulate = Color(0.6, 1.0, 0.2, 0.9) 

		3: # Daun Kecil Bertebangan Angin Kencang (Melayang Horisontal)
			pm.direction = Vector3(1, -0.2, 0) 
			pm.spread = 18.0 # Sedikit dilebarkan sebarannya agar variatif karena jumlahnya banyak
			pm.gravity = Vector3(0, 10, 0) 
			pm.initial_velocity_min = 90.0  # Sedikit dipercepat agar tidak menumpuk
			pm.initial_velocity_max = 200.0
			
			pm.scale_min = 0.4
			pm.scale_max = 1.3
			pm.angle_min = -45.0
			pm.angle_max = 45.0
			pm.angular_velocity_min = 40.0
			pm.angular_velocity_max = 140.0
			
			modulate = Color(0.35, 0.52, 0.15, 0.85)

	process_material = pm
