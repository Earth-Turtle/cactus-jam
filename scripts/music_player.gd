extends Node

func adjust_volume(new_volume: float):
	$AudioStreamPlayer.volume_linear = new_volume


# Because the "loop" properties aren't actually looping?
func _on_audio_stream_player_finished() -> void:
	$AudioStreamPlayer.play()
