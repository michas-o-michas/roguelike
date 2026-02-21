extends GPUParticles3D

## Partículas de impacto ao bater em recurso (árvore, pedra).
## Emite uma vez e se remove sozinho ao terminar.

func _ready() -> void:
	emitting = true
	finished.connect(_on_finished)

func _on_finished() -> void:
	queue_free()
