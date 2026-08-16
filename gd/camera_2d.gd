extends Camera2D

@onready var player = $"../player"

var target_node: Node2D = null
var is_focusing: bool = false
var _tween: Tween = null


func _process(_delta: float) -> void:
	if not is_focusing and player:
		global_position = player.global_position


func focus_target(target: Node2D, duration: float = 1.0) -> void:
	if target == null:
		return
	is_focusing = true
	target_node = target
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "global_position", target.global_position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished


func focus_player(duration: float = 1.0) -> void:
	if player == null:
		is_focusing = false
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "global_position", player.global_position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished
	is_focusing = false
	target_node = null
