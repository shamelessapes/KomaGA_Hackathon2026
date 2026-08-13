extends Path2D

@onready var path_follow = $PathFollow2D

var speed = 60.0
var curve_length: float

func _ready():
	curve_length = curve.get_baked_length()

func _physics_process(delta):
	if path_follow.progress < curve_length:
		path_follow.progress += speed * delta
	else:
		path_follow.progress = curve_length

	print("progress: ", path_follow.progress)  # デバッグ用、これだけでOK
