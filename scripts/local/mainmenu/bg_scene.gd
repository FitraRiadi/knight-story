extends Node2D

var last_screen_size: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	var current_screen_size = get_viewport_rect().size
	
	if current_screen_size != last_screen_size:
		last_screen_size = current_screen_size
		
		# SAMAKAN dengan resolusi Viewport baru kamu
		var base_resolution = Vector2(2400, 1080) 
		
		# Rumus pemenuh layar tanpa gepeng
		var scale_factor = max(current_screen_size.x / base_resolution.x, current_screen_size.y / base_resolution.y)
		scale = Vector2(scale_factor, scale_factor)
		
		# Posisikan tepat di tengah layar HP
		position = current_screen_size / 2
