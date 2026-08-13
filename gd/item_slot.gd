extends PanelContainer

## インベントリの1スロットを担当する独立UIクラス

signal slot_right_clicked(slot_index: int)
signal slot_hovered(item_id: String)
signal slot_unhovered

@export var slot_index: int = -1

@onready var texture_rect: TextureRect = $TextureRect
@onready var count_label: Label = $Label

var current_item_id: String = ""
var current_count: int = 0


func _ready() -> void:
	# シグナル接続
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	
	clear_slot()


## スロットの表示内容を更新
func update_slot(item_id: String, count: int) -> void:
	current_item_id = item_id
	current_count = count

	if current_item_id == "" or current_count <= 0:
		clear_slot()
		return

	var item_data = ItemDatabase.get_item(current_item_id)
	if item_data:
		texture_rect.texture = item_data.icon
		texture_rect.show()
		
		if item_data.stackable and count > 1:
			count_label.text = str(count)
			count_label.show()
		else:
			count_label.hide()
	else:
		clear_slot()


## スロットを空状態にする
func clear_slot() -> void:
	current_item_id = ""
	current_count = 0
	texture_rect.texture = null
	texture_rect.hide()
	count_label.hide()


## GUI入力イベント（右クリックで使用）
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if current_item_id != "":
				slot_right_clicked.emit(slot_index)


## マウスホバー開始
func _on_mouse_entered() -> void:
	if current_item_id != "":
		slot_hovered.emit(current_item_id)


## マウスホバー終了
func _on_mouse_exited() -> void:
	slot_unhovered.emit()


# ----------------------------------------------------
# 将来のドラッグ＆ドロップ機能用拡張ポイント
# ----------------------------------------------------
func _get_drag_data(_at_position: Vector2) -> Variant:
	if current_item_id == "":
		return null
	
	# ドラッグ中のプレビュー表示などを生成
	var preview = TextureRect.new()
	preview.texture = texture_rect.texture
	preview.custom_minimum_size = Vector2(40, 40)
	set_drag_preview(preview)
	
	return { "from_slot_index": slot_index, "item_id": current_item_id, "count": current_count }


func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	# 将来のアイテム合成機能などの拡張用にスロット同士の入れ替えドロップは無効化
	return false


func _drop_data(_at_position: Vector2, _data: Variant) -> void:
	pass
