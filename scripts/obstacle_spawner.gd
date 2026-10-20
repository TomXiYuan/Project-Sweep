extends Node2D

@export var obstacle_scenes: Array[PackedScene] = []
@export var min_radius: float = 300.0
@export var max_radius: float = 600.0

@export var spawn_count: int = 10

func _ready() -> void:
	if obstacle_scenes.is_empty():
		return
		
	for i in range(spawn_count):
		spawn_random_obstacle()

func spawn_random_obstacle() -> void:
	var random_index: int = randi() % obstacle_scenes.size()
	var obstacle: Node2D = obstacle_scenes[random_index].instantiate()
	
	var random_angle: float = randf_range(0, 2 * PI)
	var random_distance: float = randf_range(min_radius, max_radius)
	var spawn_offset: Vector2 = Vector2(cos(random_angle), sin(random_angle)) * random_distance
	
	obstacle.global_position = global_position + spawn_offset
	obstacle.rotation = random_angle + PI 
	
	get_tree().current_scene.call_deferred("add_child", obstacle)
