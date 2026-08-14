extends CanvasLayer

var _color_rect: ColorRect
@export var fade_duration: float = 0.5

func _ready() -> void:
	_color_rect = ColorRect.new()
	_color_rect.color = Color(0, 0, 0, 0)  # 黒、透明状態からスタート
	_color_rect.anchor_right = 1.0
	_color_rect.anchor_bottom = 1.0
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_color_rect)
	layer = 100  # 他のUIより手前に表示されるよう最前面に設定

func fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(_color_rect, "color:a", 1.0, fade_duration)
	await tween.finished
	print("[SceneTransition] フェードアウト完了")

func fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(_color_rect, "color:a", 0.0, fade_duration)
	await tween.finished
	print("[SceneTransition] フェードイン完了")

## 鬼が退出した時に呼び出す想定の関数（フェードアウト→日付変更→フェードイン）
func change_day() -> void:
	await fade_out()
	Daymanager.advance_day()
	await fade_in()
