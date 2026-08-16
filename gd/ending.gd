extends Control

@onready var end_label: Label = $endtext

const ENDING_TEXTS: Array[String] = [
	"……………………。 ▼",
	"………………。 ▼",
	"……目が覚めると、僕はあたたかな陽光が差し込む病室にいた。 ▼",
	"「あれ？ぼく……。」 ▼",
	"「そうだった、内緒でお外に出て…裏山で遊んでたら崖から落ちゃって……。」 ▼",
	"「あの暗い病室も化け物も、みんな夢だったのかな…。」 ▼",
	"「…………。本当に…帰れてよかった……。」▼",
	"その後、ぼくは無事退院することになった。▼",
	"あの七日間にわたる悪夢と、怪物の正体はいったい何だったのか。▼",
	"いまのぼくにはもう、それを知る由はない……。▼"
]

var _current_index: int = 0
var _is_fading_out: bool = false


func _ready() -> void:
	Global.fade_in(Color.BLACK, 1.0)
	$AudioStreamPlayer.play()
	_current_index = 0
	_is_fading_out = false
	if end_label:
		end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_update_text()


func _input(event: InputEvent) -> void:
	if _is_fading_out:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_text()
		get_viewport().set_input_as_handled()


func _advance_text() -> void:
	_current_index += 1
	if _current_index < ENDING_TEXTS.size():
		_update_text()
	else:
		_finish_ending()


func _update_text() -> void:
	if end_label and _current_index < ENDING_TEXTS.size():
		end_label.text = ENDING_TEXTS[_current_index]


func _finish_ending() -> void:
	_is_fading_out = true
	Global.change_scene_with_fade("res://tscn/title.tscn", Color.BLACK, 5.0)
