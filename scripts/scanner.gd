extends Node2D

@export var scan_arc: float = 45 
@export var ray_count: int = 64
@export var max_distance: float = 600.0
@export var line_fade_time: float = 5.0
@export var fire_cooldown: float = 0.5

@export var wave_speed: float = 250.0
@export var traveling_alpha: float = 0.1
@export var impact_alpha: float = 1.0
@export var traveling_radius: float = 1.0
@export var impact_radius: float = 2.0

var cooldown_timer: float = 0.0

func _process(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer -= delta

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if cooldown_timer <= 0:
			fire_pulse()
			cooldown_timer = fire_cooldown

func fire_pulse() -> void:
	look_at(get_global_mouse_position())
	
	var start_angle = -scan_arc / 2.0
	var angle_step = scan_arc / (ray_count - 1)
	
	for i in range(ray_count):
		var current_angle = deg_to_rad(start_angle + (i * angle_step))
		var target_vector = Vector2(cos(current_angle), sin(current_angle)) * max_distance
		
		$RayCast2D.target_position = target_vector
		$RayCast2D.force_raycast_update() 
		
		var hit_point: Vector2
		var did_collide: bool = false
		
		if $RayCast2D.is_colliding():
			hit_point = $RayCast2D.get_collision_point()
			did_collide = true
		else:
			hit_point = global_position + target_vector.rotated(global_rotation)
			did_collide = false
			
		launch_radar_dot(global_position, hit_point, did_collide)

func launch_radar_dot(start_pos: Vector2, end_pos: Vector2, stick_on_wall: bool) -> void:
	var total_distance = start_pos.distance_to(end_pos)
	var travel_duration = total_distance / wave_speed
	
	var dot = Dot.new()
	get_tree().current_scene.add_child(dot)
	
	dot.global_position = start_pos
	dot.radius = traveling_radius
	dot.color = Color(0.0, 1.0, 0.4, traveling_alpha)
	
	var tween = create_tween()
	
	tween.tween_property(dot, "global_position", end_pos, travel_duration)
	
	if stick_on_wall:
		tween.tween_callback(func():
			dot.radius = impact_radius
			dot.color = Color(0.0, 1.0, 0.4, impact_alpha)
		)
		tween.tween_property(dot, "modulate:a", 0.0, line_fade_time)
		tween.tween_callback(dot.queue_free)
	else:
		tween.tween_callback(dot.queue_free)

class Dot extends Node2D:
	var radius: float = 1.0:
		set(value):
			radius = value
			queue_redraw()
	var color: Color = Color.GREEN:
		set(value):
			color = value
			queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, color)
