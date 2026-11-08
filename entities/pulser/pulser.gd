extends Node3D

@onready var pulse_manager = get_node("/root/Main/PulseManager")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pulse_manager.fire_pulse(Pulse.new(global_position, 30.0, 3.0, 0.015, Color.WHITE))
