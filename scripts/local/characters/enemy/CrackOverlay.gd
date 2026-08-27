extends Node2D
## Crack overlay untuk profile enemy berdasarkan morale.
## Dipanggil dari BattleEnemy._update_crack_overlay() via queue_redraw().

var enemy_ref: Node = null


func _draw() -> void:
	if enemy_ref == null or not enemy_ref.has_method("get_morale_ratio"):
		return

	var morale_ratio: float = enemy_ref.get_morale_ratio()
	if morale_ratio > 0.5:
		return

	var crack_intensity: float = 1.0 - (morale_ratio / 0.5)
	var crack_count: int = int(lerp(3.0, 12.0, crack_intensity))

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	# Seed berdasarkan morale biar crack pattern stabil (tidak berubah tiap redraw)
	rng.seed = int(morale_ratio * 1000.0)

	var half_size: Vector2 = Vector2(50.0, 50.0)
	var crack_color: Color = Color(0.0, 0.0, 0.0, lerp(0.4, 0.9, crack_intensity))
	var line_width: float = lerp(0.5, 1.5, crack_intensity)

	for i in range(crack_count):
		var start_point: Vector2 = Vector2(
			rng.randf_range(-half_size.x * 0.7, half_size.x * 0.7),
			rng.randf_range(-half_size.y * 0.7, half_size.y * 0.7)
		)

		# Tiap crack punya 2-4 segmen
		var segments: int = rng.randi_range(2, 4)
		var current_point: Vector2 = start_point

		for j in range(segments):
			var seg_length: float = rng.randf_range(8.0, 20.0)
			var angle: float = rng.randf_range(0.0, TAU)
			var end_point: Vector2 = current_point + Vector2(cos(angle), sin(angle)) * seg_length

			# Clamp ke area profile
			end_point.x = clampf(end_point.x, -half_size.x, half_size.x)
			end_point.y = clampf(end_point.y, -half_size.y, half_size.y)

			draw_line(current_point, end_point, crack_color, line_width)
			current_point = end_point
