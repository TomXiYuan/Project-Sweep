extends RigidBody2D

@export var speed: float = 200.0
@export var min_spawn_radius: float = 600.0
@export var max_spawn_radius: float = 800.0

@export var player: CharacterBody2D

func _ready() -> void:
	call_deferred("_position_around_player")

func _position_around_player() -> void:
	if not player:
		return
		
	var random_angle: float = randf_range(0, 2 * PI)
	var random_distance: float = randf_range(min_spawn_radius, max_spawn_radius)
	
	var spawn_offset: Vector2 = Vector2(cos(random_angle), sin(random_angle)) * random_distance
	
	global_position = player.global_position + spawn_offset

func _physics_process(delta: float) -> void:
	if not player:
		linear_velocity = Vector2.ZERO
		return

	var is_player_moving: bool = player.velocity.length() > 0
	
	if is_player_moving:
		var direction: Vector2 = (player.global_position - global_position).normalized()
		
		linear_velocity = direction * speed
	else:
		linear_velocity = Vector2.ZERO
