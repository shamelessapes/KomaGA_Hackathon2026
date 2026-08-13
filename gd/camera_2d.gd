extends Camera2D

@onready var player = $"../player"

# ＝＝＝＝＝　カメラ追尾　＝＝＝＝＝
func _process(_delta):
	global_position = player.global_position
