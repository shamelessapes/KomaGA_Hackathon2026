extends CharacterBody2D

@export var move_speed: float = 200.0

@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var target_position: Vector2
var is_moving := false

func _ready():
	target_position = global_position

	agent.path_desired_distance = 4.0
	agent.target_desired_distance = 8.0

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			target_position = get_global_mouse_position()
			agent.target_position = target_position
			is_moving = true

func _physics_process(_delta):

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
				
				
func update_idle_animation():
	sprite.stop()
