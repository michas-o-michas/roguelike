extends StaticBody3D
class_name ResourceNode

signal depleted

const HIT_PARTICLES_SCENE := preload("res://Scenes/Particles/ResourceHitParticles.tscn")
const FLOATING_HEALTH_BAR_SCENE := preload("res://Componentes/FloatingHealthBar.tscn")

@export var max_health := 5
@export var resource_id := "wood"
@export var drop_amount := 1
## Nome exibido na label ao mirar no recurso (ex.: "Madeira", "Pedra"). Se vazio, usa resource_id.
@export var display_name: String = ""
## Ferramenta necessária para coleta (árvore = AXE, pedra = PICKAXE)
@export var required_tool: Weapon.ToolSlot = Weapon.ToolSlot.AXE

var health
## Posição em mundo onde a barra de vida aparece (ex.: ponto onde o raycast acerta). Se for INF, usa global_position.
var raycast_position: Vector3 = Vector3.INF


## Intensidade do tremor ao levar hit (0 = desligado).
@export var hit_shake_strength := 0.01
## Duração do tremor em segundos.
@export var hit_shake_duration := 0.2

var _base_position: Vector3
var _shake_timer := 0.0
var _health_component: HealthComponent = null
var _health_bar: Node = null  # CanvasLayer ou Control da barra flutuante

func _ready() -> void:
	health = max_health
	_base_position = position
	_health_component = get_node_or_null("HealthComponent") as HealthComponent

func _process(delta: float) -> void:
	if _shake_timer > 0:
		_shake_timer -= delta
		if _shake_timer <= 0:
			position = _base_position
		else:
			position = _base_position + Vector3(
				randf_range(-hit_shake_strength, hit_shake_strength),
				randf_range(-hit_shake_strength, hit_shake_strength),
				randf_range(-hit_shake_strength, hit_shake_strength)
			)

func take_hit(damage):
	SoundManager.play("working")
	_spawn_hit_particles()
	_shake_timer = hit_shake_duration
	if _health_component:
		_health_component.take_damage(float(damage), 0.0, null)
		health = int(_health_component.current_health)
	else:
		health -= damage
		if health <= 0:
			die()

func _spawn_hit_particles() -> void:
	var particles: Node3D = HIT_PARTICLES_SCENE.instantiate()
	var tree := get_tree()
	if not tree:
		return
	var parent: Node = tree.current_scene if tree.current_scene else self
	parent.add_child(particles)
	particles.global_position = global_position + Vector3(0, 0.3, 0)

func die() -> void:
	remove_health_bar()
	SoundManager.play(&"harvest_complete")
	emit_signal("depleted")
	InventoryManager.add_item_by_id(resource_id, drop_amount)
	queue_free()

## Posição em mundo usada pela barra de HP flutuante. Se raycast_position foi definido, usa ela; senão usa global_position.
func get_bar_world_position() -> Vector3:
	if raycast_position != Vector3.INF:
		return raycast_position
	return global_position + Vector3(0, 0.5, 0)

## Nome para exibir na UI quando o jogador está mirando neste recurso (label do raycast).
func get_display_name() -> String:
	if display_name.is_empty():
		return resource_id.capitalize()
	return display_name

## Nome da ferramenta necessária em português (para o prompt de interação). Vazio se NONE.
func get_required_tool_label() -> String:
	match required_tool:
		Weapon.ToolSlot.AXE: return "Machado"
		Weapon.ToolSlot.PICKAXE: return "Picareta"
		Weapon.ToolSlot.NONE: return "Mãos"
		_: return ""

## Chamado quando o jogador pressiona E neste recurso. Auto-seleciona machado/picareta (ou nada se NONE), adiciona HealthComponent se não houver e inicia coleta.
func try_start_harvest(interactor: Node) -> void:
	if ToolSelectionManager == null or InventoryManager == null:
		return
	if required_tool != Weapon.ToolSlot.NONE:
		var w: Weapon = InventoryManager.get_equipped_weapon(required_tool)
		if w == null:
			return  # Jogador não tem a ferramenta
		ToolSelectionManager.set_active_tool(required_tool)
	_ensure_health_component()
	var wh = interactor.get_node_or_null("WeaponHandler") if interactor else null
	if wh and wh.has_method("start_harvesting"):
		wh.start_harvesting(self)

## Garante que o recurso tem um HealthComponent (criado ao iniciar interação com E). Atualiza vida do componente.
func _ensure_health_component() -> void:
	if health <= 0:
		return
	if _health_component and is_instance_valid(_health_component):
		_health_component.max_health = max_health
		_health_component.current_health = clampf(health, 0, max_health)
		_show_health_bar()
		return
	_health_component = get_node_or_null("HealthComponent") as HealthComponent
	if _health_component:
		_health_component.max_health = max_health
		_health_component.current_health = clampf(health, 0, max_health)
		if not _health_component.died.is_connected(_on_health_died):
			_health_component.died.connect(_on_health_died)
		_show_health_bar()
		return
	var hc := HealthComponent.new()
	hc.name = "HealthComponent"
	hc.max_health = max_health
	hc.current_health = clampf(health, 0, max_health)
	hc.start_with_max = false
	hc.auto_destroy_on_death = false
	hc.died.connect(_on_health_died)
	add_child(hc)
	_health_component = hc
	_show_health_bar()

func _on_health_died() -> void:
	if _health_component and _health_component.died.is_connected(_on_health_died):
		_health_component.died.disconnect(_on_health_died)
	die()

func _show_health_bar() -> void:
	if _health_bar != null and is_instance_valid(_health_bar):
		return
	var tree := get_tree()
	if not tree:
		return
	var layer: Node = FLOATING_HEALTH_BAR_SCENE.instantiate()
	var control: Node = layer.get_node_or_null("Control")
	if not control or not control.has_method("set_target"):
		layer.queue_free()
		return
	tree.current_scene.add_child(layer)
	control.set_target(self)
	_health_bar = layer

## Remove a barra de vida flutuante (chamado ao sair do foco ou ao morrer).
func remove_health_bar() -> void:
	if _health_bar != null and is_instance_valid(_health_bar):
		_health_bar.queue_free()
		_health_bar = null
