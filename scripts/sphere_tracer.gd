extends Node2D

@export var collision_mask: int = 1
@export var max_steps: int = 1000
@export var max_distance: float = 1000.0
@export var epsilon: float = 1.0
@export var search_iterations: int = 32

@export var circle_color: Color = Color.WHITE
@export var line_color: Color = Color.WHITE

var trace_positions: Array[Vector2] = []
var trace_radii: Array[float] = []
var ray_end: Vector2

var circle := CircleShape2D.new()
var query := PhysicsShapeQueryParameters2D.new()

func _ready() -> void:
	circle.radius = 1.0
	query.shape = circle
	query.collision_mask = collision_mask
	query.collide_with_areas = false

	var parent := get_parent()
	if parent is CollisionObject2D:
		query.exclude = [parent.get_rid()]

func _physics_process(_delta: float) -> void:
	var direction := (
		get_global_mouse_position() - global_position
	).normalized()

	sphere_trace(global_position, direction)
	queue_redraw()

func sphere_trace(start: Vector2, direction: Vector2) -> void:
	trace_positions.clear()
	trace_radii.clear()

	var space := get_world_2d().direct_space_state
	var ray_position := start
	var travelled := 0.0

	for i in range(max_steps):
		var remaining := max_distance - travelled
		if remaining <= 0.0:
			break
	
		var clearance := get_clearance(space, ray_position, remaining)
	
		trace_positions.append(ray_position)
		trace_radii.append(clearance)
	
		if clearance <= epsilon:
			break
	
		var step := minf(clearance, remaining)
		ray_position += direction * step
		travelled += step

	ray_end = ray_position

func get_clearance(
	space: PhysicsDirectSpaceState2D,
	pos: Vector2,
	max_radius: float
) -> float:
	if overlaps(space, pos, epsilon):
		return 0.0

	if not overlaps(space, pos, max_radius):
		return max_radius

	var low := epsilon
	var high := max_radius

	for i in range(search_iterations):
		var middle := (low + high) * 0.5

		if overlaps(space, pos, middle):
			high = middle
		else:
			low = middle

	return low

func overlaps(
	space: PhysicsDirectSpaceState2D,
	pos: Vector2,
	radius: float
) -> bool:
	circle.radius = radius
	query.transform = Transform2D(0.0, pos)

	return not space.intersect_shape(query, 1).is_empty()


func _draw() -> void:
	for i in range(trace_positions.size()):
		var center := to_local(trace_positions[i])
		var radius := trace_radii[i]

		if radius > 2.0:
			draw_circle(center, radius, Color(circle_color, 0.05))
			draw_arc(
				center, radius, 0.0, TAU,
				64, circle_color, 2.0
			)

	draw_line(Vector2.ZERO, to_local(ray_end), line_color, 3.0)
	draw_circle(Vector2.ZERO, 6.0, Color.WHITE)
