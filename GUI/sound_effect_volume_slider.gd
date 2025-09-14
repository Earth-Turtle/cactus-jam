extends HSlider

func _value_changed(new_value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Sounds"), new_value)
