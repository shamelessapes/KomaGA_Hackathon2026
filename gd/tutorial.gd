extends CanvasLayer

@onready var tuto_img1: TextureRect = $tutorial_image1
@onready var tuto_img2: TextureRect = $tutorial_image2
@onready var text_bg: TextureRect = $text_background
@onready var text_label: Label = $text

const TEXTS: Array[String] = [
	"「うーん、目が覚めちゃった……。」 ▼",
	"「……あれ？ここはどこ？いつもの病室と違うような……。」 ▼",
	"「…………！」 ▼",
	"「あの本、なんだか気になるな。読んでみよう。」 ▼",
	"本を右クリックで調べてみましょう。 ▼",
	"本は拾うことが出来ませんが、ほとんどのアイテムは右クリックで拾うことができます。 ▼",
	"「七夜参り？化け物……？よく分からないけど、ぼくを襲いに来るってこと……！？」 ▼",
	"「とりあえず化け物に見つからないように、隠れないと……！」 ▼",
	"ベッドやロッカーを右クリックすることで隠れることが出来ます。 ▼",
	"しかし、低確率で隠れていても見つかってしまうことがあります。 ▼",
	"見つかることがないように、祈りましょう。 ▼"
]

var current_text_index: int = 0
var is_dialogue_active: bool = false
var is_waiting_hintbook: bool = false
var is_sequence_finished: bool = false
var _was_book_opened: bool = false

var camera_node: Camera2D = null
var hintbook_node: Area2D = null
var main_scene: Node2D = null


func _ready() -> void:
	layer = 30
	tuto_img1.hide()
	tuto_img2.hide()
	_show_dialogue_ui()
	if text_label:
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	current_text_index = 0
	is_dialogue_active = true
	is_waiting_hintbook = false
	is_sequence_finished = false
	_was_book_opened = false

	_update_text()


func _show_dialogue_ui() -> void:
	if text_bg:
		text_bg.show()
	if text_label:
		text_label.show()


func _hide_dialogue_ui() -> void:
	if text_bg:
		text_bg.hide()
	if text_label:
		text_label.hide()


func setup_references(p_main: Node2D, p_camera: Camera2D, p_hintbook: Area2D) -> void:
	main_scene = p_main
	camera_node = p_camera
	hintbook_node = p_hintbook


func _input(event: InputEvent) -> void:
	if not is_dialogue_active or is_waiting_hintbook or is_sequence_finished:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_left_click()
		get_viewport().set_input_as_handled()


func _on_left_click() -> void:
	if current_text_index == 2:
		# 3文目終了時: camera で hintbook に視点を移す
		current_text_index += 1
		_update_text()
		_focus_hintbook()
	elif current_text_index == 5:
		# 6文目終了時: カメラ戻す、テキスト・背景非表示、ヒント本閲覧待機
		_focus_player()
		_start_hintbook_wait()
	elif current_text_index == 10:
		# 11文目終了時: テキスト・背景非表示、探索フェーズ開始、画像演出へ
		is_dialogue_active = false
		_hide_dialogue_ui()
		_start_search_phase()
		_run_images_sequence()
	else:
		current_text_index += 1
		if current_text_index < TEXTS.size():
			_update_text()


func _update_text() -> void:
	if text_label and current_text_index < TEXTS.size():
		text_label.text = TEXTS[current_text_index]


func _focus_hintbook() -> void:
	if camera_node and hintbook_node and camera_node.has_method("focus_target"):
		camera_node.focus_target(hintbook_node, 1.0)


func _focus_player() -> void:
	if camera_node and camera_node.has_method("focus_player"):
		camera_node.focus_player(1.0)


func _start_hintbook_wait() -> void:
	is_dialogue_active = false
	is_waiting_hintbook = true
	_hide_dialogue_ui()
	_was_book_opened = false
	print("[Tutorial] ヒント本の閲覧待機状態に入ります")


func _process(_delta: float) -> void:
	if is_waiting_hintbook and hintbook_node:
		if "is_open" in hintbook_node:
			if hintbook_node.is_open:
				_was_book_opened = true
			elif _was_book_opened and not hintbook_node.is_open:
				# ヒント本を開いて「本を閉じる」が押された
				_on_hintbook_closed()


func _on_hintbook_closed() -> void:
	is_waiting_hintbook = false
	_was_book_opened = false
	current_text_index = 6 # 7文目へ
	is_dialogue_active = true
	_show_dialogue_ui()
	_update_text()
	print("[Tutorial] ヒント本が閉じられました。後半テキストを再開します")


func _start_search_phase() -> void:
	if Phasemanager:
		Phasemanager.start_search_phase()
	if main_scene and main_scene.has_node("tansaku"):
		var tansaku = main_scene.get_node("tansaku") as AudioStreamPlayer
		if tansaku:
			tansaku.play()
	print("[Tutorial] 探索フェーズが開始されました")


func _run_images_sequence() -> void:
	is_sequence_finished = true

	# 1. tutorial_image1 (5秒表示 -> 1秒フェード消去)
	if tuto_img1:
		tuto_img1.modulate.a = 1.0
		tuto_img1.show()
		await get_tree().create_timer(7.5).timeout
		var tween1 = create_tween()
		tween1.tween_property(tuto_img1, "modulate:a", 0.0, 1.0)
		await tween1.finished
		tuto_img1.hide()

	# 2. tutorial_image2 (5秒表示 -> 1秒フェード消去)
	if tuto_img2:
		tuto_img2.modulate.a = 1.0
		tuto_img2.show()
		await get_tree().create_timer(7.5).timeout
		var tween2 = create_tween()
		tween2.tween_property(tuto_img2, "modulate:a", 0.0, 1.0)
		await tween2.finished
		tuto_img2.hide()

	print("[Tutorial] チュートリアル終了。tutorial.tscn を queue_free します")
	queue_free()
