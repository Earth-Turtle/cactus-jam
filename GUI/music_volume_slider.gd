extends HSlider

func _value_changed(new_value: float) -> void:
	MusicPlayer.adjust_volume(new_value)
