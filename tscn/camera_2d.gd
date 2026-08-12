extends Camera2D

@onready var player = $"../player"

func _process(delta):
	global_position = player.global_position
