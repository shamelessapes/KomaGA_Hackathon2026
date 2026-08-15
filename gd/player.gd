extends CharacterBody2D

@export var move_speed: float = 200.0

@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var target_position: Vector2
var is_moving := false
var is_hidden := false
var footstep_player: AudioStreamPlayer

func _ready():
	sprite.play("default_stop")
	add_to_group("player")
	target_position = global_position

	_init_footstep_sound()

	agent.path_desired_distance = 4.0
	agent.target_desired_distance = 8.0


func _init_footstep_sound() -> void:
	footstep_player = AudioStreamPlayer.new()
	add_child(footstep_player)
	var stream = load("res://sound/歩行.wav") as AudioStream
	if stream:
		footstep_player.stream = stream


func _update_footstep_sound(should_play: bool) -> void:
	if not is_inside_tree() or footstep_player == null:
		return

	var main_scene = get_tree().current_scene if get_tree() else null
	var is_captured = main_scene and "is_captured" in main_scene and main_scene.is_captured

	if should_play and is_moving and visible and not is_hidden and not is_captured and velocity != Vector2.ZERO:
		if not footstep_player.playing:
			footstep_player.play()
	else:
		if footstep_player.playing:
			footstep_player.stop()


func stop_walk_sound() -> void:
	if footstep_player and footstep_player.playing:
		footstep_player.stop()


func _exit_tree() -> void:
	stop_walk_sound()


#　ーーーーー　マウスで移動　ーーーーー
func _unhandled_input(event):
	if is_hidden:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			target_position = get_global_mouse_position()
			agent.target_position = target_position
			is_moving = true

#　ーーーーー　移動について　ーーーーー
func _physics_process(_delta):
	if is_hidden:
		velocity = Vector2.ZERO
		_update_footstep_sound(false)
		return

	if not is_moving:
		velocity = Vector2.ZERO
		update_idle_animation()
		move_and_slide()
		_update_footstep_sound(false)
		return

	if agent.is_navigation_finished():
		is_moving = false
		velocity = Vector2.ZERO
		update_idle_animation()
		move_and_slide()
		_update_footstep_sound(false)
		return

	var next_path_position = agent.get_next_path_position()

	var direction = global_position.direction_to(next_path_position)

	velocity = direction * move_speed

	update_animation(direction)

	move_and_slide()

	_update_footstep_sound(true)
	
	
#　ーーーーー　アニメーション制御　ーーーーー
func update_animation(direction: Vector2):

	if abs(direction.x) > abs(direction.y):

		if direction.x > 0:
			if sprite.animation != "right":
				sprite.play("right")
		else:
			if sprite.animation != "left":
				sprite.play("left")

	else:

		if direction.y > 0:
			if sprite.animation != "default":
				sprite.play("default")
		else:
			if sprite.animation != "back":
				sprite.play("back")
				
				
#　ーーーーー　停止時のアニメーション制御　ーーーーー
func update_idle_animation():
	sprite.stop()

#　ーーーーー　隠れる状態の設定　ーーーーー
func set_hidden_state(hidden: bool, hide_position: Vector2 = Vector2.ZERO) -> void:
	is_hidden = hidden
	if hidden:
		is_moving = false
		velocity = Vector2.ZERO
		global_position = hide_position
		visible = false
		_update_footstep_sound(false)
	else:
		is_moving = false
		target_position = global_position
		visible = true
		_update_footstep_sound(false)
