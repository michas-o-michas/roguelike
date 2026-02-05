extends Label

func _process(delta):
	# Atualiza o texto do Label com o FPS atual
	text = "FPS: " + str(Engine.get_frames_per_second())
