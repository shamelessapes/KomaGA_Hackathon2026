# ========================================================
# ５．ばけもの（ねつかんち）
# ========================================================


extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D
@onready var path_follow = get_parent()

var speed = 60.0
var last_position: Vector2

#下にあるやつで出した座標を入れる
var checkpoints = [
{"ratio": 0.1008, "check": true}, 
{"ratio": 0.2237, "check": true},
 {"ratio": 0.3918, "check": true},
 {"ratio": 0.4620, "check": true}, 
{"ratio": 0.5960, "check": true}, 
{"ratio": 0.7545, "check": true},
 {"ratio": 0.9747, "check": true},
 {"ratio": 1.00, "check": true},
]

func _ready():
	# Keep the monster outside the room during the search phase.
	visible = false
	while Phasemanager.current_phase != Phasemanager.Phase.HIDE:
		await Phasemanager.phase_changed
	visible = true
	last_position = global_position
	var path2d = path_follow.get_parent()
	var curve_length = path2d.curve.get_baked_length()

	for i in range(checkpoints.size()):
		var point = checkpoints[i]
		await _move_to_ratio(point["ratio"], curve_length)

		if i == checkpoints.size() - 1:
			queue_free()
		elif point["check"]:
			await play_check()

func _move_to_ratio(target_ratio: float, curve_length: float):
	while path_follow.progress_ratio < target_ratio:
		path_follow.progress_ratio += (speed * get_physics_process_delta_time()) / curve_length

		# 進行方向を計算してアニメーション切り替え
		var direction = global_position - last_position
		if direction.x < -0.01:
			sprite.play("left")
		elif direction.x > 0.01:
			sprite.play("right")
		last_position = global_position

		await get_tree().process_frame
	path_follow.progress_ratio = target_ratio

func play_check():
	sprite.play("check")
	await sprite.animation_finished

#ここで数値を計測してcheckpointの座標をあぶる
func _physics_process(delta):
	pass
	#print(path_follow.progress_ratio)
