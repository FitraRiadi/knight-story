extends Node2D
class_name CardParticle


# ============================================================
# SIGNALS
# ============================================================

signal particle_finished


# ============================================================
# PROPERTIES
# ============================================================

## Tipe particle: "intro" (one-shot), "repeat" (loop), "end" (one-shot)
@export var particle_type: String = "intro"

## Auto-queue_free setelah particle selesai (untuk intro/end)
@export var auto_free: bool = true

## Durasi sebelum auto_free (0 = tunggu particle selesai)
@export var duration: float = 0.0


# ============================================================
# STATE
# ============================================================

var particle_emitters: Array[GPUParticles2D] = []
var cpu_emitters: Array[CPUParticles2D] = []


# ============================================================
# BUILT-IN
# ============================================================

func _ready() -> void:
	_collect_emitters()
	_start_particles()
	
	if auto_free and particle_type != "repeat":
		if duration > 0.0:
			await get_tree().create_timer(duration).timeout
		else:
			# Tunggu semua particle selesai
			for emitter in particle_emitters:
				if emitter.emitting:
					await emitter.finished
			for emitter in cpu_emitters:
				if emitter.emitting:
					await get_tree().create_timer(emitter.lifetime).timeout
		
		particle_finished.emit()
		queue_free()


# ============================================================
# SETUP
# ============================================================

func _collect_emitters() -> void:
	# Collect GPUParticles2D
	for child in get_children():
		if child is GPUParticles2D:
			particle_emitters.append(child)
		elif child is CPUParticles2D:
			cpu_emitters.append(child)
		
		# Recursive check
		for sub_child in child.get_children():
			if sub_child is GPUParticles2D:
				particle_emitters.append(sub_child)
			elif sub_child is CPUParticles2D:
				cpu_emitters.append(sub_child)


func _start_particles() -> void:
	for emitter in particle_emitters:
		emitter.emitting = true
	for emitter in cpu_emitters:
		emitter.emitting = true


# ============================================================
# PUBLIC API
# ============================================================

func stop() -> void:
	for emitter in particle_emitters:
		emitter.emitting = false
		emitter.restart()
	for emitter in cpu_emitters:
		emitter.emitting = false
		emitter.restart()


func restart() -> void:
	for emitter in particle_emitters:
		emitter.restart()
		emitter.emitting = true
	for emitter in cpu_emitters:
		emitter.restart()
		emitter.emitting = true
