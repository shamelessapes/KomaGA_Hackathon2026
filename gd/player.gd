extends CharacterBody2D

@export var move_speed: float = 200.0

@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var target_position: Vector2
var is_moving := false
var is_hidden := false

func _ready():
	print("Hello World")
	target_position = global_position

	agent.path_desired_distance = 4.0
	agent.target_desired_distance = 8.0


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
		return

	if not is_moving:
		velocity = Vector2.ZERO
		update_idle_animation()
		move_and_slide()
		return

	if agent.is_navigation_finished():
		is_moving = false
		velocity = Vector2.ZERO
		update_idle_animation()
		move_and_slide()
		return

	var next_path_position = agent.get_next_path_position()

	var direction = global_position.direction_to(next_path_position)

	velocity = direction * move_speed

	update_animation(direction)

	move_and_slide()
	
	
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
	else:
		is_moving = false
		target_position = global_position
		visible = true
