extends Area2D

@onready var hint_canvas: CanvasLayer = $hint
@onready var close_button: Button = $hint/Control/book_close

@onready var hint_textures: Array[TextureRect] = [
	$hint/hint1,
	$hint/hint2,
	$hint/hint3,
	$hint/hint4,
	$hint/hint5,
	$hint/hint6,
	$hint/hint7
]


var is_open: bool = false


func _ready() -> void:
	close_book()
	if close_button:
		if not close_button.pressed.is_connected(close_book):
			close_button.pressed.connect(close_book)


func open_book() -> void:
	is_open = true
	if Phasemanager:
		Phasemanager.pause_search_timer()

	var day: int = 1
	if Daymanager:
		day = clampi(Daymanager.current_day, 1, 7)

	for i in range(hint_textures.size()):
		if hint_textures[i]:
			hint_textures[i].visible = (i + 1 == day)

	var main_scene = get_tree().current_scene if get_tree() else null
	if main_scene and "player" in main_scene and main_scene.player:
		var p = main_scene.player
		if "is_moving" in p:
			p.is_moving = false
		if "velocity" in p:
			p.velocity = Vector2.ZERO
		if p.has_method("stop_walk_sound"):
			p.stop_walk_sound()

	if hint_canvas:
		hint_canvas.show()
		Global.play_bgm_by_path("res://sound/本めくり.mp3")
	print("[HintBook] ヒント本を開きました (Day: %d)" % day)


func close_book() -> void:
	is_open = false
	if Phasemanager:
		Phasemanager.resume_search_timer()
	if hint_canvas:
		hint_canvas.hide()
		#Global.play_bgm_by_path("res://sound/本めくり.mp3")
	print("[HintBook] ヒント本を閉じました")
