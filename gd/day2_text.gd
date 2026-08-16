extends CanvasLayer

@onready var text_bg: TextureRect = $text_background
@onready var text_label: Label = $text

const TEXTS: Array[String] = [
	"「さ、さっきのが本に書かれていた化け物……？」 ▼",
	"「あ、あんなのに捕まったら、絶対死んじゃうよ……！」 ▼",
	"「捕まらないように、あと六夜をなんとか乗り越えよう……！」 ▼"
]

var current_text_index: int = 0
var is_finished: bool = false
var main_scene: Node2D = null


func _ready() -> void:
	layer = 30
	current_text_index = 0
	is_finished = false
	if text_bg:
		text_bg.show()
	if text_label:
		text_label.show()
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_text()


func setup_references(p_main: Node2D) -> void:
	main_scene = p_main


func _input(event: InputEvent) -> void:
	if is_finished:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_text()
		get_viewport().set_input_as_handled()


func _advance_text() -> void:
	current_text_index += 1
	if current_text_index < TEXTS.size():
		_update_text()
	else:
		_finish_sequence()


func _update_text() -> void:
	if text_label and current_text_index < TEXTS.size():
		text_label.text = TEXTS[current_text_index]


func _finish_sequence() -> void:
	is_finished = true
	if text_bg:
		text_bg.hide()
	if text_label:
		text_label.hide()

	# 探索フェーズ開始
	if Phasemanager:
		Phasemanager.start_search_phase()
	if main_scene and main_scene.has_node("tansaku"):
		var tansaku = main_scene.get_node("tansaku") as AudioStreamPlayer
		if tansaku:
			tansaku.play()

	print("[Day2Text] 2日目会話演出終了。探索フェーズを開始し queue_free します")
	queue_free()
