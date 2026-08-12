extends Node2D


#＝＝＝＝＝　汎用フェードイン・アウト　＝＝＝＝＝
# --- フェード用変数
var fade_layer := CanvasLayer.new()
var color_rect := ColorRect.new()

func _ready():
	# フェード用ノードの構築
	fade_layer.layer = 100  # レイヤー順（UIより上に）
	add_child(fade_layer)

	color_rect.name = "FadeOverlay"
	color_rect.color = Color.WHITE
	color_rect.anchor_left = 0.0
	color_rect.anchor_top = 0.0
	color_rect.anchor_right = 1.0
	color_rect.anchor_bottom = 1.0
	color_rect.modulate.a = 0.0  # 最初は透明
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # マウスイベント無視（クリック透過）
	color_rect.z_index = 1  # UIより前面に来るようにする（念のため）
	color_rect.z_as_relative = false  # グローバルなz_indexとして扱う
	color_rect.size_flags_horizontal = Control.SIZE_FILL
	color_rect.size_flags_vertical = Control.SIZE_FILL
	color_rect.size = get_viewport().get_visible_rect().size

	fade_layer.add_child(color_rect)

	call_deferred("_resize_color_rect")

func _resize_color_rect():
	await get_tree().process_frame
	color_rect.size = get_viewport().get_visible_rect().size

# --- フェードアウトしてシーン遷移
func change_scene_with_fade(path: String, color: Color = Color.BLACK, duration: float = 1.5) -> void:
	color.a = 0.0  # 最初は透明から始める
	color_rect.modulate = color
	color_rect.show()
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(path)


# --- フェードイン（画面表示開始時用）
func fade_in(color: Color = Color.WHITE, _duration: float = 1.0) -> void:
	color.a = 1.0
	color_rect.modulate = color
	color_rect.show()
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 0.0, _duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	color_rect.hide()

# --- フェードアウト（画面を暗くする）
func fade_out(color: Color = Color.BLACK, _duration: float = 1.0) -> void:
	color.a = 0.0  # 最初は透明な状態で開始
	color_rect.modulate = color
	color_rect.show()
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, _duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	# フェードアウト後はあえて表示を残す（シーン遷移などの直前用）
	
#＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝
