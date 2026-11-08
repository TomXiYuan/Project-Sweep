class_name Pulse
extends RefCounted

var origin: Vector3
var max_radius: float
var duration: float
var speed: float

var width: float
var color: Color

var radius := 0.0


func _init(p_origin: Vector3, p_max_radius: float, p_duration : float, p_width: float,p_color: Color) -> void:
	origin = p_origin
	max_radius = maxf(p_max_radius, 0.001)
	duration = maxf(p_duration, 0.001)
	speed = max_radius / duration
	
	width = maxf(p_width, 0.001)
	color = p_color


func update(delta: float) -> void:
	radius += speed * delta


func is_finished() -> bool:
	return radius >= max_radius
