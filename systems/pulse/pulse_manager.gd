extends Node

const MAX_PULSES := 64

var pulses := []
var pulse_image: Image
var pulse_texture: ImageTexture


func _ready() -> void:
	pulse_image = Image.create(MAX_PULSES, 3, false, Image.FORMAT_RGBAF)
	pulse_texture = ImageTexture.create_from_image(pulse_image)

	RenderingServer.global_shader_parameter_set("pulse_data", pulse_texture)


func fire_pulse(pulse : Pulse) -> void:
	if pulses.size() >= MAX_PULSES:
		pulses.pop_front()
	pulses.append(pulse)


func _process(delta: float) -> void:
	for i in range(pulses.size() - 1, -1, -1):
		pulses[i].update(delta)
		
		if pulses[i].is_finished():
			pulses.remove_at(i)
			
	for i in range(pulses.size()):
		var p: Pulse = pulses[i]
		pulse_image.set_pixel(i, 0, Color(p.origin.x, p.origin.y, p.origin.z, p.radius))
		pulse_image.set_pixel(i, 1, Color(p.color.r, p.color.g, p.color.b, p.width))
		pulse_image.set_pixel(i, 2, Color(p.max_radius, p.speed, 0.0, 0.0))
		
	pulse_texture.update(pulse_image)
	
	RenderingServer.global_shader_parameter_set("pulse_count", pulses.size())
